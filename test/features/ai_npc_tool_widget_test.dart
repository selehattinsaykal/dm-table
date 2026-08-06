import 'package:dm_table/app/ai_settings_provider.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/domain/ai/ai_settings.dart';
import 'package:dm_table/features/ai/ai_tools_page.dart';
import 'package:dm_table/features/world/world_providers.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI NPC araci arayuzu: konum secici, iliski satirlari ve portre anahtari
/// gercek dunya verisiyle kurulur. Saglayici gorsel uretmiyorsa anahtar
/// KAPALI olmali -- sessizce calismayan bir toggle en kotu sonuc olurdu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  /// Repoyu tek seferlik okuyup saglayicilari sabitler.
  Future<({List<Location> locs, List<Npc> npcs, List<BondType> bonds})>
  snapshot() async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(worldRepositoryProvider);
    return (
      locs: await db.select(db.locations).get(),
      npcs: await repo.allNpcs(),
      bonds: await db.select(db.bondTypes).get(),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required AiProvider provider,
    List<Location> locations = const [],
    List<Npc> npcs = const [],
    List<BondType> bonds = const [],
  }) async {
    tester.view.physicalSize = const Size(1100, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Drift'in canli .watch() akisi yerine tek degerli akis (yukariya bak).
          allLocationsProvider.overrideWith((ref) => Stream.value(locations)),
          npcsProvider.overrideWith((ref) => Stream.value(npcs)),
          bondTypesProvider.overrideWith((ref) => Stream.value(bonds)),
          aiSettingsProvider.overrideWith(
            () => _FixedAiSettings(AiSettings(provider: provider, apiKey: 'K')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('tr'), Locale('en')],
          home: AiToolsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('konum ve iliski bolumleri dunya verisiyle dolar', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final world = container.read(worldRepositoryProvider);
    await world.createLocation(name: 'Karga Geçidi');
    await world.createNpc(name: 'Sera');
    await world.ensureDefaultBondTypes(const [
      (code: 'friendship', name: 'Dostluk', color: 0xFF66BB6A, sort: 0),
      (code: 'enmity', name: 'Düşmanlık', color: 0xFFEF5350, sort: 1),
    ]);
    final data = await snapshot();

    await pump(
      tester,
      provider: AiProvider.gemini,
      locations: data.locs,
      npcs: data.npcs,
      bonds: data.bonds,
    );

    final l10n = await L10n.delegate.load(const Locale('tr'));
    expect(find.text(l10n.npcBoundLocation.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.npcRelations.toUpperCase()), findsOneWidget);
    // "Yer yok" uyarisi CIKMAMALI: yer var.
    expect(find.text(l10n.npcNoLocations), findsNothing);
    expect(find.text(l10n.npcNoOtherNpcs), findsNothing);
  });

  testWidgets('yer/NPC yokken yonlendirici not gosterilir', (tester) async {
    await pump(tester, provider: AiProvider.gemini);
    final l10n = await L10n.delegate.load(const Locale('tr'));
    expect(find.text(l10n.npcNoLocations), findsOneWidget);
    expect(find.text(l10n.npcNoOtherNpcs), findsOneWidget);
  });

  testWidgets('Gemini secilliyken portre anahtari acilabilir', (tester) async {
    await pump(tester, provider: AiProvider.gemini);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged, isNotNull);
    expect(toggle.value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('Claude secilliyken portre anahtari KAPALI ve nedeni yazili', (
    tester,
  ) async {
    await pump(tester, provider: AiProvider.anthropic);
    final l10n = await L10n.delegate.load(const Locale('tr'));

    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged, isNull, reason: 'anahtar devre disi olmali');
    expect(toggle.value, isFalse);
    expect(
      find.text(l10n.npcPortraitUnsupported(AiProvider.anthropic.label)),
      findsOneWidget,
    );
  });

  testWidgets('iliski ekle bir satir acar, kaldir siler', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final world = container.read(worldRepositoryProvider);
    await world.createNpc(name: 'Sera');
    await world.ensureDefaultBondTypes(const [
      (code: 'friendship', name: 'Dostluk', color: 0xFF66BB6A, sort: 0),
    ]);
    final data = await snapshot();

    await pump(
      tester,
      provider: AiProvider.gemini,
      npcs: data.npcs,
      bonds: data.bonds,
    );
    final l10n = await L10n.delegate.load(const Locale('tr'));

    expect(find.text(l10n.npcRelationPickNpc), findsNothing);
    await tester.tap(find.text(l10n.npcAddRelation));
    await tester.pumpAndSettle();
    expect(find.text(l10n.npcRelationPickNpc), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.npcRemoveRelation));
    await tester.pumpAndSettle();
    expect(find.text(l10n.npcRelationPickNpc), findsNothing);
  });
}

/// Testte sabit AI ayari veren notifier (prefs'e gitmez).
class _FixedAiSettings extends AiSettingsController {
  _FixedAiSettings(this._value);
  final AiSettings _value;

  @override
  AiSettings build() => _value;
}
