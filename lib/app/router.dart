import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/ai_tools_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/campaigns/campaigns_page.dart';
import '../features/characters/character_sheet_page.dart';
import '../features/characters/characters_page.dart';
import '../features/codex/codex_document_page.dart';
import '../features/codex/codex_page.dart';
import '../features/combat/combat_page.dart';
import '../features/combat/encounter_page.dart';
import '../features/compendium/compendium_page.dart';
import '../features/loot/loot_page.dart';
import '../features/music/music_page.dart';
import '../features/quests/quests_page.dart';
import '../features/session/session_page.dart';
import '../features/tables/tables_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shops/shop_detail_page.dart';
import '../features/shops/shops_page.dart';
import '../features/world/location_page.dart';
import '../features/world/faction_detail_page.dart';
import '../features/world/npc_detail_page.dart';
import '../features/world/npc_list_page.dart';
import '../features/search/command_palette.dart';
import '../features/world/world_page.dart';
import 'content_gate.dart';
import 'undo.dart';
import 'shell.dart';

/// Sekmelerin her biri kendi navigasyon yiginini korur; savas ekranindan bir
/// canavarin stat blokuna girip geri donunce savas listesi bozulmasin diye.
/// [initialLocation] yalnizca testler icin disari acildi: uygulama her zaman
/// Oturum'da acilir, ama tek bir bolumu suren widget testi o dalda baslamali.
/// [navigatorKey] rota agacinin DISINDAN tam ekran bir sayfa acabilmek icin
/// disari alindi (sure sayaci uyarisindaki "Aç" eylemi gibi). Her uygulama
/// ornegi kendi anahtarini verir; global tek bir anahtar kampanya
/// degistirirken iki router kisa sure yan yana yasadigi icin cakisirdi.
///
/// **Kayit rotalari** (`/npcs/:id` gibi) uygulama ICINDEKI gezinmeyi
/// degistirmez — listeler kayitlari eskisi gibi `Navigator.push` ile aciyor.
/// Bunlar tek bir kayda DISARIDAN gitmek icin var: komut paleti bir NPC
/// bulunca artik "/npcs" sekmesini degil, o NPC'yi aciyor
/// (bkz. `features/search/command_palette.dart`). Kayit dalin KENDI
/// navigator'inda acildigi icin yan gezinti rayi da yerinde kalir.
GoRouter buildRouter({
  String initialLocation = '/session',
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final branchKeys = List.generate(
    16,
    (i) => GlobalKey<NavigatorState>(debugLabel: 'branch$i'),
  );

  StatefulShellBranch branch(
    int index,
    String path,
    Widget Function(BuildContext, GoRouterState) builder, {
    List<RouteBase> routes = const [],
  }) => StatefulShellBranch(
    navigatorKey: branchKeys[index],
    routes: [GoRoute(path: path, builder: builder, routes: routes)],
  );

  /// Dalin altinda tek kimlikli bir kayit rotasi. Yol GORELI (bas eğik
  /// çizgisiz) olmali; go_router alt rotalari boyle bekliyor.
  GoRoute record(Widget Function(String id) build) => GoRoute(
    path: ':id',
    builder: (context, state) => build(state.pathParameters['id']!),
  );

  return GoRouter(
    navigatorKey: navigatorKey,
    // Acilista Oturum: her seans oradan basliyor (gunluk, zar kaydi, parti
    // dinlenmesi), ilk ekranin kutuphane olmasi icin bir sebep yoktu (dal 0
    // oldugu icin oyleydi).
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ContentGate(
          // Komut paleti kabugun ETRAFINDA: kisayol her sekmede gecerli
          // olsun, her sayfa kendi bagini kurmak zorunda kalmasin.
          // Geri alma ve komut paleti kabugun ETRAFINDA: ikisi de her
          // sekmede gecerli olsun, her sayfa kendi bagini kurmasin.
          child: UndoShortcut(
            child: CommandPaletteShortcut(
              child: AppShell(navigationShell: navigationShell),
            ),
          ),
        ),
        branches: [
          branch(0, '/compendium', (_, _) => const CompendiumPage()),
          branch(
            1,
            '/characters',
            (_, _) => const CharactersPage(),
            routes: [record((id) => CharacterSheetPage(characterId: id))],
          ),
          branch(
            2,
            '/combat',
            (_, _) => const CombatPage(),
            routes: [record((id) => EncounterPage(encounterId: id))],
          ),
          branch(
            3,
            '/world',
            (_, _) => const WorldPage(),
            routes: [record((id) => LocationPage(locationId: id))],
          ),
          branch(
            4,
            '/npcs',
            (_, _) => const NpcListPage(),
            routes: [
              // Statik parca `:id`den ONCE: go_router rotalari bildirim
              // sirasina gore esliyor, tersi olsaydi "faction" bir NPC
              // kimligi sanilirdi. Fraksiyonun kendi ust sekmesi yok --
              // kisiler ve orgutler ayni dalda, iki alt sekmede yasiyor.
              GoRoute(
                path: 'faction/:id',
                builder: (context, state) =>
                    FactionDetailPage(factionId: state.pathParameters['id']!),
              ),
              record((id) => NpcDetailPage(npcId: id)),
            ],
          ),
          branch(
            5,
            '/shops',
            (_, _) => const ShopsPage(),
            routes: [record((id) => ShopDetailPage(shopId: id))],
          ),
          branch(6, '/loot', (_, _) => const LootPage()),
          branch(7, '/session', (_, _) => const SessionPage()),
          branch(
            8,
            '/codex',
            (_, _) => const CodexHomePage(),
            routes: [record((id) => CodexDocumentPage(pageId: id))],
          ),
          branch(9, '/ai-tools', (_, _) => const AiToolsPage()),
          branch(
            10,
            '/quests',
            (_, _) => const QuestsPage(),
            routes: [record((id) => QuestEditPage(questId: id))],
          ),
          branch(11, '/settings', (_, _) => const SettingsPage()),
          branch(12, '/campaigns', (_, _) => const CampaignsPage()),
          branch(13, '/calendar', (_, _) => const CalendarPage()),
          branch(14, '/tables', (_, _) => const TablesPage()),
          branch(15, '/music', (_, _) => const MusicPage()),
        ],
      ),
    ],
  );
}
