import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_settings.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'app/ui/ui.dart';
import 'data/campaign/campaign.dart';
import 'data/campaign/campaign_manager.dart';
import 'data/campaign/campaign_paths.dart';
import 'data/campaign/campaign_registry.dart';
import 'data/media_root.dart';
import 'data/providers.dart';
import 'features/session/session_page.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kayitlar (Codex) video blogu icin; native oynaticiyi hazirlar.
  MediaKit.ensureInitialized();

  // Kampanya kaydi runApp'ten ONCE okunur: hangi veritabani dosyasinin
  // acilacagini bilmeden hicbir provider kurulamaz. Asenkron yuklenseydi
  // uygulama once varsayilan dosyayi acip sonra digerine atlardi.
  final prefs = await SharedPreferences.getInstance();
  var registry = await CampaignRegistry.load(prefs);
  // Onceki oturumda kilitli oldugu icin silinemeyen kampanyalari, henuz
  // hicbir dosya acilmamisken temizle.
  registry = await CampaignManager.purgePending(prefs, registry);

  // Medya (harita/portre/video) koku de acilistan once cozulur; store'lar
  // goreli yol yazdigi icin kok yanlissa dosyalar baska kampanyaya duser.
  final active = registry.active;
  final mediaRoot = active.isDefault
      ? null
      : await CampaignPaths.mediaRoot(active);

  runApp(
    CampaignRoot(prefs: prefs, registry: registry, initialMediaRoot: mediaRoot),
  );
}

/// `ProviderScope`'un ÜSTÜNDE duran kök.
///
/// Kampanya değiştirmek = veritabanını değiştirmek. Bunu `databaseProvider`'ı
/// yerinde invalidate ederek yapmak YANLIŞ olurdu: Riverpod `invalidateSelf`'te
/// provider'ın kendi `onDispose`'unu senkron çalıştırır, bağımlılarını yalnızca
/// "değişmiş olabilir" diye işaretler — yani `db.close()`, ona bağlı LAN
/// sunucusunun `stop()`'undan ÖNCE çalışır ve canlı sunucu kapalı bir
/// veritabanına sorgu atar.
///
/// Bunun yerine kabın (`ProviderContainer`) tamamı yenilenir:
/// `dispose()` yapraktan köke doğru çalıştığı için `SessionService` → `AppDatabase`
/// sırası garanti olur. Yeni `GoRouter` de kurulur — kampanya A'da açılmış bir
/// karakter sayfası kampanya B'de var olmayan bir kimliğe bakardı.
class CampaignRoot extends StatefulWidget {
  const CampaignRoot({
    required this.prefs,
    required this.registry,
    this.initialMediaRoot,
    super.key,
  });

  final SharedPreferences prefs;
  final CampaignRegistry registry;

  /// Açık kampanyanın medya kökü; varsayılan kampanyada `null` (uygulama
  /// klasörünün kendisi kullanılır).
  final Directory? initialMediaRoot;

  @override
  State<CampaignRoot> createState() => _CampaignRootState();
}

class _CampaignRootState extends State<CampaignRoot> {
  late CampaignManager _manager;
  late Campaign _campaign;
  late ProviderContainer _container;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _campaign = widget.registry.active;
    _manager = CampaignManager(
      prefs: widget.prefs,
      registry: widget.registry,
      onOpen: _switchTo,
    );
    _container = _createContainer(_campaign, widget.initialMediaRoot);
  }

  ProviderContainer _createContainer(Campaign campaign, Directory? mediaRoot) {
    // Medya kokunu kap kurulmadan once ayarla.
    MediaRoot.current = mediaRoot;
    return ProviderContainer(
      overrides: [
        activeCampaignProvider.overrideWithValue(campaign),
        campaignManagerProvider.overrideWithValue(_manager),
      ],
    );
  }

  Future<void> _switchTo(Campaign next) async {
    if (!mounted) return;
    setState(() => _switching = true);

    // Sunucuyu ONCE ve await ederek kapat: soketler temiz kapansin, bagli
    // oyuncular yarim mesajla kalmasin.
    await _container.read(sessionControllerProvider.notifier).stop();

    final mediaRoot = next.isDefault
        ? null
        : await CampaignPaths.mediaRoot(next);

    final previous = _container;
    if (!mounted) return;
    setState(() {
      _campaign = next;
      _container = _createContainer(next, mediaRoot);
      _switching = false;
    });
    // Eski kap yalniz yeni agac cizildikten sonra atilir; boylece hicbir
    // widget kapanmakta olan veritabanini gozlemleyemez.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  @override
  void dispose() {
    _container.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UncontrolledProviderScope(
          key: ValueKey(_campaign.id),
          container: _container,
          child: DmApp(key: ValueKey(_campaign.id)),
        ),
        if (_switching)
          const ColoredBox(
            color: Color(0xCC120D09),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// DM uygulamasi (Android + Windows).
///
/// Oyuncu paneli ayri bir entrypoint'tir: `lib/main_player.dart`, web'e
/// derlenip bu uygulamanin icinden LAN uzerinden servis edilir.
class DmApp extends ConsumerStatefulWidget {
  const DmApp({super.key});

  @override
  ConsumerState<DmApp> createState() => _DmAppState();
}

class _DmAppState extends ConsumerState<DmApp> {
  // Router her build'de yeniden kurulursa navigasyon yigini sifirlanir.
  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => L10n.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.lang.locale,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      // Kagit taneciği tum arayuzun uzerinde tek katman olarak durur
      // (Navigator'in ustunde: sayfalar, dialoglar, sheet'ler dahil).
      builder: (context, child) => ParchmentOverlay(child: child!),
    );
  }
}
