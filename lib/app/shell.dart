import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/campaign/campaign_manager.dart';
import '../features/campaigns/campaigns_page.dart' show campaignLabel;
import '../features/session/player_presence_panel.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'ui/ui.dart';

/// Kabuktaki bir hedef. [branch] router'daki `StatefulShellBranch` sirasidir;
/// [group] yalnizca genis ekran rayindaki gruplama icin kullanilir.
typedef _Destination = ({
  int branch,
  IconData icon,
  IconData selected,
  String label,
  String short,
  _Group group,
});

enum _Group { table, world, tools }

/// Uygulamanin ana cercevesi.
///
/// Genis ekranda TUM bolumleri gosteren gruplu bir yan ray; telefonda ise
/// bes birincil sekme + "Daha fazla" cekmecesi.
///
/// Neden bes: alt navigasyonda on iki hedef vardi. Etiketler okunamayacak
/// kadar sikisiyor, dokunma hedefleri 44px'in altina duyuyor ve hicbir sey
/// oncelikli gorunmuyordu (UX kurali: alt bar <= 5 hedef). Masada en sik
/// kullanilan besi one alindi, gerisi cekmeceye tasindi — hicbir bolum
/// kaybolmadi, rota yapisi da aynen korundu.
///
/// **Sira DM'in is akisina gore**, router dal numarasina gore DEGIL (dallar
/// tarihsel ekleme sirasinda, anlamli bir duzenleri yok):
///  1. `table`  — masa basinda, oyun SIRASINDA acilan bolumler. Oturum en
///     basta, cunku her seans oradan baslar (sunucuyu ac, QR goster).
///  2. `world`  — seans ARASINDA hazirlanan kampanya malzemesi.
///  3. `tools`  — basvuru ve yapilandirma; en seyrek dokunulanlar (Ayarlar
///     en altta, alisilmis yer).
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Yan ray esigi; tum duyarli esikler [Breakpoints]'ta toplanir.
  static const _breakpoint = Breakpoints.rail;

  /// Telefonda alt barda duran bolumler (router dal numaralari).
  ///
  /// Masada elde telefonla en sik dokunulan besi: oturumu ac, savas yonet,
  /// karaktere bak, haritayi ac, kurala bak.
  static const _primaryBranches = <int>[7, 2, 1, 3, 0];

  /// Ray/cekmece sirasi. Grup icindeki sira da bilincli: her grupta once
  /// "kokten" bolum, sonra ona baglananlar.
  List<_Destination> _destinations(L10n l10n) => [
    // --- Masada ---
    (
      branch: 7,
      icon: Icons.wifi_tethering_outlined,
      selected: Icons.wifi_tethering,
      label: l10n.navSession,
      short: l10n.navSession,
      group: _Group.table,
    ),
    (
      branch: 2,
      icon: Icons.shield_outlined,
      selected: Icons.shield,
      label: l10n.navCombat,
      short: l10n.navCombat,
      group: _Group.table,
    ),
    (
      branch: 1,
      icon: Icons.people_outline,
      selected: Icons.people,
      label: l10n.navCharacters,
      short: l10n.navCharactersShort,
      group: _Group.table,
    ),
    (
      branch: 12,
      icon: Icons.chat_bubble_outline,
      selected: Icons.chat_bubble,
      label: l10n.navChat,
      short: l10n.navChat,
      group: _Group.table,
    ),
    (
      branch: 6,
      icon: Icons.card_giftcard_outlined,
      selected: Icons.card_giftcard,
      label: l10n.navLoot,
      short: l10n.navLoot,
      group: _Group.table,
    ),
    (
      branch: 16,
      icon: Icons.library_music_outlined,
      selected: Icons.library_music,
      label: l10n.navMusic,
      short: l10n.navMusic,
      group: _Group.table,
    ),
    // --- Dünya & öykü ---
    (
      branch: 3,
      icon: Icons.map_outlined,
      selected: Icons.map,
      label: l10n.navWorld,
      short: l10n.navWorld,
      group: _Group.world,
    ),
    (
      branch: 4,
      icon: Icons.groups_outlined,
      selected: Icons.groups,
      label: l10n.navNpcs,
      short: l10n.navNpcs,
      group: _Group.world,
    ),
    (
      branch: 10,
      icon: Icons.assignment_outlined,
      selected: Icons.assignment,
      label: l10n.navQuests,
      short: l10n.navQuests,
      group: _Group.world,
    ),
    (
      branch: 5,
      icon: Icons.storefront_outlined,
      selected: Icons.storefront,
      label: l10n.navShops,
      short: l10n.navShopsShort,
      group: _Group.world,
    ),
    (
      branch: 14,
      icon: Icons.calendar_month_outlined,
      selected: Icons.calendar_month,
      label: l10n.navCalendar,
      short: l10n.navCalendar,
      group: _Group.world,
    ),
    (
      branch: 8,
      icon: Icons.auto_stories_outlined,
      selected: Icons.auto_stories,
      label: l10n.navCodex,
      short: l10n.navCodex,
      group: _Group.world,
    ),
    // --- Araçlar ---
    (
      branch: 0,
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
      label: l10n.navCompendium,
      short: l10n.navCompendiumShort,
      group: _Group.tools,
    ),
    (
      branch: 15,
      icon: Icons.casino_outlined,
      selected: Icons.casino,
      label: l10n.navTables,
      short: l10n.navTablesShort,
      group: _Group.tools,
    ),
    (
      branch: 9,
      icon: Icons.auto_awesome_outlined,
      selected: Icons.auto_awesome,
      label: l10n.navAiTools,
      short: l10n.navAiTools,
      group: _Group.tools,
    ),
    (
      branch: 13,
      icon: Icons.bookmarks_outlined,
      selected: Icons.bookmarks,
      label: l10n.navCampaigns,
      short: l10n.navCampaigns,
      group: _Group.tools,
    ),
    (
      branch: 11,
      icon: Icons.settings_outlined,
      selected: Icons.settings,
      label: l10n.navSettings,
      short: l10n.navSettings,
      group: _Group.tools,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final destinations = _destinations(l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shell = constraints.maxWidth >= _breakpoint
            ? _WideShell(
                navigationShell: navigationShell,
                destinations: destinations,
                l10n: l10n,
                onSelect: _go,
              )
            : _CompactShell(
                navigationShell: navigationShell,
                destinations: destinations,
                primaryBranches: _primaryBranches,
                l10n: l10n,
                onSelect: _go,
              );

        // Oyuncu varlik paneli her sayfada durur (acilir/kapanir). Kendi
        // `Positioned`'ini dondurur — surukleyerek tasinabildigi icin konumu
        // burada degil panelin kendi state'inde.
        return Stack(children: [shell, const PlayerPresencePanel()]);
      },
    );
  }

  void _go(int branch) => navigationShell.goBranch(
    branch,
    // Zaten acik olan sekmeye tekrar basmak o dalin kokune doner.
    initialLocation: branch == navigationShell.currentIndex,
  );
}

/// Genis ekran: gruplu, kaydirilabilir yan ray.
class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.navigationShell,
    required this.destinations,
    required this.l10n,
    required this.onSelect,
  });

  final StatefulNavigationShell navigationShell;
  final List<_Destination> destinations;
  final L10n l10n;
  final ValueChanged<int> onSelect;

  /// Grup sirasi rayda gorunen sira: once masa, sonra dunya, sonra araclar.
  static const _order = [_Group.table, _Group.world, _Group.tools];

  /// Rayin genisligi (NavigationRail varsayilani 72; grup basliklari icin
  /// biraz daha genis).
  static const _railWidth = 88.0;

  String _groupLabel(_Group g) => switch (g) {
    _Group.table => l10n.navGroupTable,
    _Group.world => l10n.navGroupWorld,
    _Group.tools => l10n.navGroupTools,
  };

  @override
  Widget build(BuildContext context) {
    // Her grup KENDI NavigationRail'i olarak ciziliyor; tek ray icine baslik
    // konulamiyor (destinations yalnizca secilebilir hedef kabul eder) ve on
    // alti hedef basliksiz tek kolonda hangi bolumun nerede oldugunu
    // okunaksiz kiliyordu. Secili olmayan gruplarin selectedIndex'i null.
    final current = navigationShell.currentIndex;

    return Scaffold(
      body: Row(
        children: [
          // Ray kendi basina kaydirilamaz; on alti hedef kisa bir masaustu
          // penceresinde tasiyordu. Bu sarmalayici rayi en az pencere
          // yuksekliginde tutar ama gerekince kaydirir.
          //
          // Genislik BURADA veriliyor: Row'da esnek olmayan cocuk sinirsiz
          // genislik constraint'i alir, tek basina bir Column bunu cozemez
          // (NavigationRail kendi genisligini kendisi belirledigi icin eski
          // tek-ray surumunde gerekmiyordu).
          SizedBox(
            width: _railWidth,
            child: ColoredBox(
              color:
                  Theme.of(context).navigationRailTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _RailCrest(),
                        for (final group in _order) ...[
                          _GroupLabel(text: _groupLabel(group)),
                          _RailGroup(
                            destinations: destinations
                                .where((d) => d.group == group)
                                .toList(),
                            currentBranch: current,
                            onSelect: onSelect,
                          ),
                        ],
                        SizedBox(height: context.spacing.md),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Rayda tek bir grubun hedefleri.
class _RailGroup extends StatelessWidget {
  const _RailGroup({
    required this.destinations,
    required this.currentBranch,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int currentBranch;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final index = destinations.indexWhere((d) => d.branch == currentBranch);
    // NavigationRail ici Expanded kullaniyor: dikey sinirsiz alanda (kaydirma
    // gorunumu) layout hatasi verir, bu yuzden IntrinsicHeight sart.
    return IntrinsicHeight(
      child: NavigationRail(
        selectedIndex: index >= 0 ? index : null,
        onDestinationSelected: (i) => onSelect(destinations[i].branch),
        labelType: NavigationRailLabelType.all,
        // Gruplar alt alta duruyor; arka plan sarmalayicida bir kez veriliyor.
        backgroundColor: Colors.transparent,
        destinations: [
          for (final d in destinations)
            NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: Text(d.label),
            ),
        ],
      ),
    );
  }
}

/// Ray gruplarinin ustundeki kucuk baslik.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(space.sm, space.md, space.sm, space.xs),
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: context.fantasyColors.brass,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Rayin tepesindeki kucuk arma: uygulamaya masaustunde kimlik verir.
///
/// Altinda acik kampanyanin adi durur -- birden fazla masa yuruten bir DM
/// hangi kampanyaya yazdigini her an gormeli.
class _RailCrest extends ConsumerWidget {
  const _RailCrest();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.spacing;
    final theme = Theme.of(context);
    final manager = ref.watch(campaignManagerProvider);

    return Padding(
      padding: EdgeInsets.only(top: space.md, bottom: space.sm),
      child: Column(
        children: [
          ExcludeSemantics(child: WaxSeal(letter: 'D', size: 34)),
          if (manager != null) ...[
            SizedBox(height: space.xs),
            ListenableBuilder(
              listenable: manager,
              builder: (context, _) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Text(
                  campaignLabel(L10n.of(context), manager.active),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.fantasyColors.brass,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Telefon: bes birincil sekme + "Daha fazla".
class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.navigationShell,
    required this.destinations,
    required this.primaryBranches,
    required this.l10n,
    required this.onSelect,
  });

  final StatefulNavigationShell navigationShell;
  final List<_Destination> destinations;
  final List<int> primaryBranches;
  final L10n l10n;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = [
      for (final b in primaryBranches)
        destinations.firstWhere((d) => d.branch == b),
    ];
    final current = navigationShell.currentIndex;
    final primaryIndex = primaryBranches.indexOf(current);
    // Acik bolum cekmecedeyse "Daha fazla" isikli kalir: kullanici nerede
    // oldugunu her zaman gorur (UX kurali: aktif durum gorunur olmali).
    final selectedIndex = primaryIndex >= 0 ? primaryIndex : primary.length;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          if (i == primary.length) {
            _openMoreSheet(context);
            return;
          }
          onSelect(primary[i].branch);
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.short,
              tooltip: d.label,
            ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: const Icon(Icons.more_horiz),
            label: l10n.navMore,
            tooltip: l10n.navMoreTitle,
          ),
        ],
      ),
    );
  }

  Future<void> _openMoreSheet(BuildContext context) async {
    final rest = destinations
        .where((d) => !primaryBranches.contains(d.branch))
        .toList();

    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      // Yedi satir + baslik ekranin yarisini asabiliyor; kaydirilabilir
      // olmasi icin buyuk sheet.
      isScrollControlled: true,
      builder: (sheetContext) => _MoreSheet(
        destinations: rest,
        currentBranch: navigationShell.currentIndex,
        title: l10n.navMoreTitle,
      ),
    );
    if (picked != null) onSelect(picked);
  }
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.destinations,
    required this.currentBranch,
    required this.title,
  });

  final List<_Destination> destinations;
  final int currentBranch;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.spacing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(space.md, 0, space.md, space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              label: title,
              padding: EdgeInsets.only(bottom: space.sm),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in destinations)
                    ListTile(
                      leading: Icon(
                        d.branch == currentBranch ? d.selected : d.icon,
                        color: d.branch == currentBranch
                            ? theme.colorScheme.primary
                            : context.fantasyColors.brass,
                      ),
                      title: Text(
                        d.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: d.branch == currentBranch
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: d.branch == currentBranch
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      selected: d.branch == currentBranch,
                      selectedTileColor: theme.colorScheme.primary.withValues(
                        alpha: 0.10,
                      ),
                      // Liste satirlari 44px dokunma hedefini asmali.
                      minVerticalPadding: 14,
                      onTap: () => Navigator.of(context).pop(d.branch),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
