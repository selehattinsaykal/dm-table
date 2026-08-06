import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/ai_tools_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/campaigns/campaigns_page.dart';
import '../features/chat/chat_page.dart';
import '../features/characters/characters_page.dart';
import '../features/codex/codex_page.dart';
import '../features/combat/combat_page.dart';
import '../features/compendium/compendium_page.dart';
import '../features/loot/loot_page.dart';
import '../features/music/music_page.dart';
import '../features/quests/quests_page.dart';
import '../features/session/session_page.dart';
import '../features/tables/tables_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shops/shops_page.dart';
import '../features/world/npc_list_page.dart';
import '../features/world/world_page.dart';
import 'content_gate.dart';
import 'shell.dart';

/// Sekmelerin her biri kendi navigasyon yiginini korur; savas ekranindan bir
/// canavarin stat blokuna girip geri donunce savas listesi bozulmasin diye.
/// [initialLocation] yalnizca testler icin disari acildi: uygulama her zaman
/// Oturum'da acilir, ama tek bir bolumu suren widget testi o dalda baslamali.
GoRouter buildRouter({String initialLocation = '/session'}) {
  final branchKeys = List.generate(
    17,
    (i) => GlobalKey<NavigatorState>(debugLabel: 'branch$i'),
  );

  StatefulShellBranch branch(
    int index,
    String path,
    Widget Function(BuildContext, GoRouterState) builder,
  ) => StatefulShellBranch(
    navigatorKey: branchKeys[index],
    routes: [GoRoute(path: path, builder: builder)],
  );

  return GoRouter(
    // Acilista Oturum: her seans "masayi ac / QR goster" ile basliyor, ilk
    // ekranin kutuphane olmasi icin bir sebep yoktu (dal 0 oldugu icin
    // oyleydi). Dal SIRASI degistirilmedi — dal numaralari kalici kimlik.
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ContentGate(child: AppShell(navigationShell: navigationShell)),
        branches: [
          branch(0, '/compendium', (_, _) => const CompendiumPage()),
          branch(1, '/characters', (_, _) => const CharactersPage()),
          branch(2, '/combat', (_, _) => const CombatPage()),
          branch(3, '/world', (_, _) => const WorldPage()),
          branch(4, '/npcs', (_, _) => const NpcListPage()),
          branch(5, '/shops', (_, _) => const ShopsPage()),
          branch(6, '/loot', (_, _) => const LootPage()),
          branch(7, '/session', (_, _) => const SessionPage()),
          branch(8, '/codex', (_, _) => const CodexHomePage()),
          branch(9, '/ai-tools', (_, _) => const AiToolsPage()),
          branch(10, '/quests', (_, _) => const QuestsPage()),
          branch(11, '/settings', (_, _) => const SettingsPage()),
          branch(12, '/chat', (_, _) => const ChatPage()),
          branch(13, '/campaigns', (_, _) => const CampaignsPage()),
          branch(14, '/calendar', (_, _) => const CalendarPage()),
          branch(15, '/tables', (_, _) => const TablesPage()),
          branch(16, '/music', (_, _) => const MusicPage()),
        ],
      ),
    ],
  );
}
