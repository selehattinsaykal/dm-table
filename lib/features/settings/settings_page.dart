import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ai_settings_provider.dart';
import '../../app/app_settings.dart';
import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../domain/ai/ai_settings.dart';
import '../../l10n/app_localizations.dart';
import '../session/backup_page.dart';

/// DM uygulamasinin ayarlar ekrani: dil ve tema secimi.
///
/// Dil secimi su an yalnizca L10n ile cevrilmis metinleri (gezinme, kutuphane,
/// filtreler, ortak dugmeler) etkiler; uygulamanin cok sayida ekrani hala
/// sabit Turkce oldugu icin bir bilgi notu gosterilir. Tema tam calisir.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    Widget section(String title, Widget child) => Card(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              label: title,
              padding: EdgeInsets.only(bottom: context.spacing.sm),
            ),
            child,
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(
            l10n.settingsLanguage,
            SegmentedButton<AppLang>(
              segments: [
                for (final lang in AppLang.values)
                  ButtonSegment(value: lang, label: Text(lang.label)),
              ],
              selected: {settings.lang},
              showSelectedIcon: false,
              onSelectionChanged: (s) => controller.setLang(s.first),
            ),
          ),
          const SizedBox(height: 12),
          section(
            l10n.settingsTheme,
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                ),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 12),
          section(l10n.settingsAiTitle, const _AiSection()),
          const SizedBox(height: 12),
          // Yedekleme yalnizca Oturum sayfasinin ust cubugundaki ikondan
          // acilabiliyordu; kimsenin bakmadigi bir yerde durmasi icin sebep
          // yok, Ayarlar bu tur islerin alisildik yeri.
          section(
            l10n.sessionBackup,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.backupExportHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push(MaterialPageRoute(builder: (_) => const BackupPage())),
                  icon: const Icon(Icons.backup_outlined),
                  label: Text(l10n.sessionBackup),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // İçerik atfı: SRD 5.2 CC-BY 4.0 ile geliyor, atıf ZORUNLU. Metin
          // ARB'de hazır duruyordu ama hiçbir ekrana bağlanmamıştı.
          section(
            l10n.licenseTitle,
            Text(l10n.licenseBody, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.settingsPartialTranslation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI (opt-in, kendi anahtarını getir) yapılandırması. Anahtar yalnızca cihazda.
class _AiSection extends ConsumerStatefulWidget {
  const _AiSection();
  @override
  ConsumerState<_AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends ConsumerState<_AiSection> {
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _imageModel;
  final _keyFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _imageModelFocus = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final ai = ref.read(aiSettingsProvider);
    _key = TextEditingController(text: ai.apiKey);
    _model = TextEditingController(text: ai.model);
    _imageModel = TextEditingController(text: ai.imageModel);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _imageModel.dispose();
    _keyFocus.dispose();
    _modelFocus.dispose();
    _imageModelFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Metinleri geri-yazma yarışına girmeden ÖNCE oku ve tek atomik kayıtla
    // yaz; yoksa anahtar yazıldıktan sonraki ara-durum model alanını eskiye
    // döndürüyordu.
    final key = _key.text.trim();
    final model = _model.text.trim();
    final imageModel = _imageModel.text.trim();
    await ref
        .read(aiSettingsProvider.notifier)
        .save(apiKey: key, model: model, imageModel: imageModel);
    if (!mounted) return;
    _keyFocus.unfocus();
    _modelFocus.unfocus();
    _imageModelFocus.unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L10n.of(context).settingsAiSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final ai = ref.watch(aiSettingsProvider);
    final controller = ref.read(aiSettingsProvider.notifier);

    // Kalıcı (shared_preferences) değer asenkron yüklenince alanları doldur:
    // provider ilk build'de varsayılan döner, _load sonra state'i günceller.
    // Alan odakta değilse (kullanıcı yazmıyorsa) kayıtlı değeri yansıt.
    ref.listen<AiSettings>(aiSettingsProvider, (prev, next) {
      if (!_keyFocus.hasFocus && _key.text != next.apiKey) {
        _key.text = next.apiKey;
      }
      if (!_modelFocus.hasFocus && _model.text != next.model) {
        _model.text = next.model;
      }
      if (!_imageModelFocus.hasFocus && _imageModel.text != next.imageModel) {
        _imageModel.text = next.imageModel;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AiProvider>(
          initialValue: ai.provider,
          decoration: InputDecoration(
            labelText: l10n.settingsAiProvider,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final p in AiProvider.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (p) {
            if (p != null) controller.setProvider(p);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          focusNode: _keyFocus,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: l10n.settingsAiKey,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          focusNode: _modelFocus,
          decoration: InputDecoration(
            labelText: l10n.settingsAiModel,
            hintText: ai.provider.defaultModel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        // Gorsel modeli metin modelinden ayri: NPC portresi ureten model
        // farkli ve daha sik degisiyor. Saglayici gorsel uretmiyorsa alan
        // kapali + nedeni yazili.
        TextField(
          controller: _imageModel,
          focusNode: _imageModelFocus,
          enabled: ai.provider.supportsImages,
          decoration: InputDecoration(
            labelText: l10n.aiImageModel,
            hintText: ai.provider.defaultImageModel ?? '',
            helperText: ai.provider.supportsImages
                ? l10n.aiImageModelHint
                : l10n.aiImageUnsupportedNote,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(l10n.save),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // "Aktif" durumu marka kirmizisi yerine altin rozet rengiyle
            // vurgulanir (basari/statu hissi); context.fantasyColors.gold.
            Icon(
              ai.enabled ? Icons.check_circle_outline : Icons.key_off_outlined,
              size: 15,
              color: ai.enabled
                  ? context.fantasyColors.gold
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              ai.enabled ? l10n.settingsAiActive : l10n.settingsAiInactive,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ai.enabled
                    ? context.fantasyColors.gold
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settingsAiNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
