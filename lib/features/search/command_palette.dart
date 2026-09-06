// `Column` hem drift'te hem Flutter'da tanimli; drift'inki gizleniyor.
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../compendium/detail_sheets.dart';

/// Bulunan bir kayit.
///
/// Kaynak tablolarin hepsi farkli; palet tek bir sade bicime indiriyor.
///
/// [open] secilince NE OLACAGINI tasiyor ve kaynagina gore degisiyor:
///  * Kampanya kayitlari (karakter, NPC, yer, gorev, dukkan, sayfa,
///    karsilasma) kendi rotasina gider -- `/npcs/<id>` gibi. Eskiden palet
///    yalnizca SEKMEYE goturuyordu ("Gundren" arayip NPC listesinde
///    kaybolmak), cunku o rotalar yoktu; artik var (bkz. `app/router.dart`).
///  * Kutuphane kayitlari (canavar, buyu, esya) hicbir yere GITMEZ, stat
///    blogunu yerinde bir sheet olarak acar. Masada istenen sey zaten bu:
///    savas ekranindan cikmadan "goblinin AC'si kacti?".
typedef SearchHit = ({
  String title,
  String subtitle,
  IconData icon,
  void Function(BuildContext context) open,
});

/// Genel arama / komut paleti.
///
/// **Neden var:** uygulama artik on alti dala yayilmis durumda (kutuphane,
/// karakterler, yerler, gorevler, kayitlar, muzik, savas haritalari...).
/// Aradigin seye ulasmak icin once hangi sekmede oldugunu hatirlaman
/// gerekiyordu; masada bu en cok zaman yiyen sey.
///
/// Kayitlar TEK sorguda degil, kaynak basina sinirli sayida cekiliyor: amac
/// eksiksiz bir sonuc listesi degil, "yaz ve git".
Future<void> showCommandPalette(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _CommandPalette(),
);

/// `Ctrl+K` / `Cmd+K` ile paleti acan sarmalayici.
///
/// Kabugun etrafina bir kez saruluyor; her sayfanin kendi kisayolunu
/// tanimlamasi gerekmiyor.
class CommandPaletteShortcut extends StatelessWidget {
  const CommandPaletteShortcut({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          showCommandPalette(context),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
          showCommandPalette(context),
    },
    child: Focus(autofocus: true, child: child),
  );
}

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  final _controller = TextEditingController();
  List<SearchHit> _hits = const [];
  bool _busy = false;

  /// Son yazilan metin; asenkron sonuclar GECIKMIS bir sorguya aitse
  /// atiliyor (kullanici hizli yazarken eski sonuc ekrana dusmesin).
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    _query = query;
    if (query.length < 2) {
      setState(() {
        _hits = const [];
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    final hits = await _lookup(ref.read(databaseProvider), query);
    if (!mounted || _query != query) return;
    setState(() {
      _hits = hits;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _search,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _hits.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _controller.text.trim().length < 2
                            ? l10n.searchEmpty
                            : l10n.noResults,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _hits.length,
                      itemBuilder: (context, i) {
                        final hit = _hits[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(hit.icon, size: 18),
                          title: Text(hit.title),
                          subtitle: Text(hit.subtitle),
                          onTap: () {
                            // Once palet kapaniyor: acilacak sheet ya da
                            // sayfa paletin ustune degil, uygulamanin
                            // uzerine gelmeli.
                            Navigator.pop(context);
                            hit.open(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kaynak basina en fazla bu kadar sonuc; palet bir liste ekrani degil.
const _perSource = 5;

/// Butun kaynaklarda arar.
///
/// Ham SQL yerine drift sorgulari: her tablonun kendi "ad" kolonu farkli ve
/// `name_lower` gibi indeksli alanlar yalnizca kutuphane tablolarinda var.
/// Digerlerinde dogrudan ada bakiliyor; SQLite'in `LIKE`i ASCII icin zaten
/// buyuk/kucuk harf ayirmiyor.
Future<List<SearchHit>> _lookup(AppDatabase db, String query) async {
  final like = '%${query.toLowerCase()}%';
  final out = <SearchHit>[];

  Future<void> add<T>({
    required Future<List<T>> Function() fetch,
    required SearchHit Function(T row) map,
  }) async {
    for (final row in await fetch()) {
      out.add(map(row));
    }
  }

  // --- Kutuphane: yerinde sheet acar, sekme degistirmez -------------------

  await add<Monster>(
    fetch: () =>
        (db.select(db.monsters)
              ..where((t) => t.nameLower.like(like))
              ..limit(_perSource))
            .get(),
    map: (m) => (
      title: m.name,
      subtitle: 'CR ${m.challengeRating}',
      icon: Icons.pest_control,
      open: (context) => showDetailSheet(context, MonsterDetail(monster: m)),
    ),
  );
  await add<Spell>(
    fetch: () =>
        (db.select(db.spells)
              ..where((t) => t.nameLower.like(like))
              ..limit(_perSource))
            .get(),
    map: (s) => (
      title: s.name,
      subtitle: 'L${s.level}',
      icon: Icons.auto_awesome,
      open: (context) => showDetailSheet(context, SpellDetail(spell: s)),
    ),
  );
  await add<Item>(
    fetch: () =>
        (db.select(db.items)
              ..where((t) => t.nameLower.like(like))
              ..limit(_perSource))
            .get(),
    map: (i) => (
      title: i.name,
      subtitle: i.category ?? '',
      icon: Icons.inventory_2_outlined,
      open: (context) => showDetailSheet(context, ItemDetail(item: i)),
    ),
  );
  await add<MagicItem>(
    fetch: () =>
        (db.select(db.magicItems)
              ..where((t) => t.nameLower.like(like))
              ..limit(_perSource))
            .get(),
    map: (i) => (
      title: i.name,
      subtitle: i.rarity ?? '',
      icon: Icons.auto_fix_high,
      open: (context) => showDetailSheet(context, MagicItemDetail(item: i)),
    ),
  );

  // --- Kampanya kayitlari: dogrudan kaydin rotasina gider -----------------

  await add<Character>(
    fetch: () =>
        (db.select(db.characters)
              ..where((t) => t.name.like(like))
              ..limit(_perSource))
            .get(),
    map: (c) => (
      title: c.name,
      subtitle: c.playerName ?? c.backgroundKey ?? '',
      icon: Icons.person,
      open: (context) => context.go('/characters/${c.id}'),
    ),
  );
  await add<Location>(
    fetch: () =>
        (db.select(db.locations)
              ..where((t) => t.name.like(like))
              ..limit(_perSource))
            .get(),
    map: (l) => (
      title: l.name,
      subtitle: l.description,
      icon: Icons.place_outlined,
      open: (context) => context.go('/world/${l.id}'),
    ),
  );
  await add<Npc>(
    fetch: () =>
        (db.select(db.npcs)
              ..where((t) => t.name.like(like))
              ..limit(_perSource))
            .get(),
    map: (n) => (
      title: n.name,
      subtitle: n.role.isNotEmpty ? n.role : n.race,
      icon: Icons.face,
      open: (context) => context.go('/npcs/${n.id}'),
    ),
  );
  await add<Faction>(
    fetch: () =>
        (db.select(db.factions)
              ..where((t) => t.name.like(like))
              ..limit(_perSource))
            .get(),
    map: (f) => (
      title: f.name,
      subtitle: f.kind.isNotEmpty ? f.kind : f.goal,
      icon: Icons.groups_2_outlined,
      open: (context) => context.go('/npcs/faction/${f.id}'),
    ),
  );
  await add<Encounter>(
    fetch: () =>
        (db.select(db.encounters)
              ..where((t) => t.name.like(like))
              ..limit(_perSource))
            .get(),
    map: (e) => (
      title: e.name,
      subtitle: '',
      icon: Icons.shield_outlined,
      open: (context) => context.go('/combat/${e.id}'),
    ),
  );
  await add<Quest>(
    fetch: () =>
        (db.select(db.quests)
              ..where((t) => t.title.like(like) | t.questText.like(like))
              ..limit(_perSource))
            .get(),
    map: (q) => (
      title: q.title,
      subtitle: q.questText,
      icon: Icons.flag_outlined,
      open: (context) => context.go('/quests/${q.id}'),
    ),
  );
  await add<CodexPage>(
    fetch: () =>
        (db.select(db.codexPages)
              ..where((t) => t.title.like(like))
              ..limit(_perSource))
            .get(),
    map: (p) => (
      title: p.title,
      subtitle: '',
      icon: Icons.menu_book_outlined,
      open: (context) => context.go('/codex/${p.id}'),
    ),
  );
  await add<Shop>(
    fetch: () =>
        (db.select(db.shops)
              ..where((t) => t.name.like(like))
              ..limit(_perSource))
            .get(),
    map: (s) => (
      title: s.name,
      subtitle: s.ownerName ?? '',
      icon: Icons.storefront_outlined,
      open: (context) => context.go('/shops/${s.id}'),
    ),
  );

  // Parcanin kendi sayfasi yok; muzik sekmesi acilir.
  await add<MusicTrack>(
    fetch: () =>
        (db.select(db.musicTracks)
              ..where((t) => t.title.like(like))
              ..limit(_perSource))
            .get(),
    map: (t) => (
      title: t.title,
      subtitle: '',
      icon: Icons.music_note_outlined,
      open: (context) => context.go('/music'),
    ),
  );

  return out;
}
