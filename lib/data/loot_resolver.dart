import 'package:uuid/uuid.dart';

import 'compendium_repository.dart';
import 'encounter_briefing.dart';

const _uuid = Uuid();

/// AI'nin ya da DM'in yazdigi bir esya ADINI kutuphanedeki gercek kayda
/// baglar.
///
/// Neden gerekli: uretecler esyalari serbest metin olarak veriyor ("Ateş
/// Kılıcı +1"). O ad kutuphanede varsa esya keseye TAM kaydiyla (fiyat,
/// aciklama, nadirlik) gitmeli; yoksa DM bunu bilmeli — uydurma bir esyayi
/// gercek sanip oyunculara vermesin. Bu yuzden cozulemeyen adlar SILINMEZ,
/// yalnizca anahtarsiz (bkz. [lootItemResolved]) kaydedilir.
///
/// Eslestirme once buyulu esya kataloğunda, sonra normal esyalarda aranir:
/// "magic" isaretli bir ad normal katalogda kazara eslesip sihirli ozelligini
/// kaybetmesin.
class LootResolver {
  const LootResolver(this.compendium);

  final CompendiumRepository compendium;

  /// Tek bir adi cozer.
  Future<EncounterLootItem> resolve({
    required String name,
    required bool magic,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return (
        id: _uuid.v4(),
        name: name,
        magic: magic,
        itemKey: null,
        magicItemKey: null,
      );
    }

    if (magic) {
      final magicMatch = await _bestMagic(trimmed);
      if (magicMatch != null) {
        return (
          id: _uuid.v4(),
          name: magicMatch.name,
          magic: true,
          itemKey: null,
          magicItemKey: magicMatch.key,
        );
      }
    }

    final plain = await _bestItem(trimmed);
    if (plain != null) {
      return (
        id: _uuid.v4(),
        name: plain.name,
        magic: magic,
        itemKey: plain.key,
        magicItemKey: null,
      );
    }

    // Sihirli isaretlenmemis ama aslinda buyulu olabilir: son bir deneme.
    if (!magic) {
      final magicMatch = await _bestMagic(trimmed);
      if (magicMatch != null) {
        return (
          id: _uuid.v4(),
          name: magicMatch.name,
          magic: true,
          itemKey: null,
          magicItemKey: magicMatch.key,
        );
      }
    }

    return (
      id: _uuid.v4(),
      name: trimmed,
      magic: magic,
      itemKey: null,
      magicItemKey: null,
    );
  }

  /// Bir liste adi topluca cozer (uretec ciktisi icin).
  Future<List<EncounterLootItem>> resolveAll(
    List<({String name, bool magic})> raw,
  ) async => [
    for (final item in raw) await resolve(name: item.name, magic: item.magic),
  ];

  /// Arama sonuclarindan EN IYI eslesme: tam ad esitligi varsa o, yoksa ilk
  /// sonuc. `like '%ad%'` kismi eslesme dondurdugu icin ("kılıç" -> "Kısa
  /// kılıç") tam esitlik oncelikli.
  Future<({String key, String name})?> _bestItem(String query) async {
    final rows = await compendium.searchItems(query: query, limit: 8);
    if (rows.isEmpty) return null;
    final lower = query.toLowerCase();
    for (final r in rows) {
      if (r.name.toLowerCase() == lower) return (key: r.key, name: r.name);
    }
    return (key: rows.first.key, name: rows.first.name);
  }

  Future<({String key, String name})?> _bestMagic(String query) async {
    final rows = await compendium.searchMagicItems(query: query, limit: 8);
    if (rows.isEmpty) return null;
    final lower = query.toLowerCase();
    for (final r in rows) {
      if (r.name.toLowerCase() == lower) return (key: r.key, name: r.name);
    }
    return (key: rows.first.key, name: rows.first.name);
  }
}
