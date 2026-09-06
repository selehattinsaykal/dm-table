import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

/// Kutuphane metinlerinin Turkcesi: `assets/data/tr/{kind}_tr.json`.
///
/// Kural metni ICERIK oldugu icin ARB'de degil asset'te -- SRD verisiyle ayni
/// yerde, `conditions_tr.json` ile ayni desen. Ceviri **yalnizca gosterim
/// katmaninda** uygulaniyor: veritabanindaki kayit Ingilizce kaliyor, cunku
/// `parseClassCoreTraits`, `parseSpeciesTraits`, `parseGrantedSpellTable` gibi
/// kural ayristiricilari o metnin Ingilizce kalibina bagli.
///
/// Ingilizce kalanlar yalnizca AC, DC, CR, XP, HP kisaltmalari ile buyu ve
/// canavar OZEL adlari (Fireball, Beholder): masada oyle konusuluyor ve kural
/// aramasini kolay tutuyor. Kalan her sey -- kural metni, canavar ozellik ve
/// eylem adlari, SINIF YETENEK adlari, hasar turleri, durumlar, diller --
/// Turkce; adlar icin bkz. [contentNamesTrProvider].
///
/// Dosya semasi duz bir `entryKey -> {yol: metin}` haritasi:
///
/// ```json
/// {
///   "srd-2024_dragonborn": {
///     "traits/Breath Weapon": "Sirandaki Attack eylemini aldiginda..."
///   }
/// }
/// ```
///
/// Yol ya `desc` (kaydin kendi aciklamasi) ya da `bolum/AltKayitAdi`
/// (`traits/…`, `actions/…`, `benefits/…`, `features/…`). Alt kayit adi
/// INGILIZCE ad -- veri yeniden uretildiginde eslesme bozulmasin diye.
///
/// Cevirisi olmayan her kayit Ingilizce gorunur; eksik ceviri hata degil.
class ContentTr {
  const ContentTr(this._byKey);

  static const empty = ContentTr({});

  final Map<String, Map<String, String>> _byKey;

  /// [path] altindaki metin; cevirisi yoksa [fallback].
  String field(String entryKey, String path, String fallback) =>
      _byKey[entryKey]?[path] ?? fallback;

  /// Kaydin kendi `desc` alani; cevirisi yoksa [fallback].
  String desc(String entryKey, String fallback) =>
      field(entryKey, 'desc', fallback);

  /// `bolum/ad` altindaki aciklama; cevirisi yoksa [fallback].
  String part(String entryKey, String section, String name, String fallback) =>
      field(entryKey, '$section/$name', fallback);

  /// [entryKeys] icinde ilk eslesen `bolum/ad` metni; hicbiri yoksa [fallback].
  ///
  /// Bir yetenek sinifa da alt sinifa da ait olabiliyor (karakter kagidinda
  /// ikisi de `source: <sinif anahtari>` ile kaydediliyor), bu yuzden arama
  /// birden fazla kayit anahtari uzerinde deneniyor. Sirasi onemli: cagiran
  /// taraf en ozel anahtari basa koyar.
  String partAmong(
    Iterable<String> entryKeys,
    String section,
    String name,
    String fallback,
  ) {
    for (final key in entryKeys) {
      final hit = _byKey[key]?['$section/$name'];
      if (hit != null) return hit;
    }
    return fallback;
  }

  bool get isEmpty => _byKey.isEmpty;
}

/// `creatures`, `items`, `magicitems`, `feats`, `species`, `backgrounds`,
/// `classes` -- her biri kendi dosyasindan bir kez okunur ve onbelleklenir.
final contentTrProvider = FutureProvider.family<ContentTr, String>((
  ref,
  kind,
) async {
  final raw = await rootBundle.loadString('assets/data/tr/${kind}_tr.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return ContentTr({
    for (final entry in data.entries)
      // `_comment` gibi meta anahtarlar veri degil.
      if (!entry.key.startsWith('_') && entry.value is Map)
        entry.key: {
          for (final field in (entry.value as Map).entries)
            '${field.key}': '${field.value}',
        },
  });
});

/// Canavar ozellik/eylem ADLARININ Turkcesi -- kayittan bagimsiz, global.
///
/// Ayni ad ("Multiattack", "Bite") yuzlerce canavarda gectigi icin kayit
/// basina degil TEK bir sozlukte tutuluyor:
/// `assets/data/tr/creature_names_tr.json`.
class NameTr {
  const NameTr(this._byName);

  static const empty = NameTr({});

  final Map<String, String> _byName;

  /// [name]'in Turkcesi; yoksa [name]'in kendisi.
  String of(String name) => _byName[name] ?? name;
}

final creatureNamesTrProvider = FutureProvider<NameTr>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/data/tr/creature_names_tr.json',
  );
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return NameTr({
    for (final e in data.entries)
      if (!e.key.startsWith('_')) e.key: '${e.value}',
  });
});

/// Turkce arayuzde canavar ozellik/eylem adlari, Ingilizcede bos sozluk.
NameTr creatureNamesTrOf(BuildContext context, WidgetRef ref) {
  if (L10n.of(context).localeName != 'tr') return NameTr.empty;
  return ref.watch(creatureNamesTrProvider).value ?? NameTr.empty;
}

/// Stat blogun VERI alanlarinin (hasar turu, durum, dil, beceri, boyut...)
/// Turkcesi: `assets/data/tr/glossary_tr.json`.
///
/// Metinler ceviri zamaninda bir kez cevrildi; burasi yalnizca veritabanindan
/// Ingilizce gelen kisa alan degerleri icin -- veri Ingilizce kalmali, cunku
/// kural ayristiricilari ona bagli.
class GlossaryTr {
  const GlossaryTr(this._sections);

  static const empty = GlossaryTr({});

  final Map<String, Map<String, String>> _sections;

  /// [section] icinde [value]'nun Turkcesi; yoksa [value]'nun kendisi.
  ///
  /// Arama kucuk harfe indirgenerek yapilir: veri kimi yerde `Fire`, kimi
  /// yerde `fire` gonderiyor.
  String term(String section, String value) =>
      _sections[section]?[value.trim().toLowerCase()] ?? value;

  /// [section] icindeki butun anahtarlar. Bir secim listesini sozlugun
  /// kendisinden kurmak icin (diller gibi, veride yapisal karsiligi olmayan
  /// kumeler).
  Iterable<String> keysOf(String section) =>
      _sections[section]?.keys ?? const [];

  /// Virgulle ayrilmis bir listenin ("fire, poison") her ogesini cevirir.
  String list(String section, String value) =>
      value.split(',').map((part) => term(section, part)).join(', ');

  bool get isEmpty => _sections.isEmpty;
}

final glossaryTrProvider = FutureProvider<GlossaryTr>((ref) async {
  final raw = await rootBundle.loadString('assets/data/tr/glossary_tr.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return GlossaryTr({
    for (final e in data.entries)
      if (e.value is Map)
        e.key: {
          for (final t in (e.value as Map).entries) '${t.key}': '${t.value}',
        },
  });
});

/// Turkce arayuzde terim sozlugu, Ingilizce arayuzde bos sozluk.
GlossaryTr glossaryTrOf(BuildContext context, WidgetRef ref) {
  if (L10n.of(context).localeName != 'tr') return GlossaryTr.empty;
  return ref.watch(glossaryTrProvider).value ?? GlossaryTr.empty;
}

/// Kutuphane kayitlarinin ADLARININ Turkcesi: `assets/data/tr/names_tr.json`.
///
/// [GlossaryTr] ile ayni sema (`bolum -> {kucuk harf ad: Turkce}`) cunku is
/// ayni: veritabanindan Ingilizce gelen kisa bir degeri gosterim aninda
/// cevirmek. Ayri dosyada tutuluyor, cunku glossary stat blogun VERI alanlari
/// icin; burasi kayit adlari icin ve cok daha kalabalik.
///
/// Bolumler: `classFeatures`, `classOptions`, `feats`, `speciesTraits`,
/// `backgroundBenefits`, `items`, `magicItems`. Uretimi
/// `tools/tr/build_names_tr.py`.
///
/// Ad ayni zamanda `classes_tr.json` icindeki `features/<Ingilizce ad>` yolunun
/// anahtari oldugu icin ceviri YALNIZCA gosterimde uygulanir; arama ve kural
/// ayristirmasi Ingilizce ada bakmaya devam eder.
final contentNamesTrProvider = FutureProvider<GlossaryTr>((ref) async {
  final raw = await rootBundle.loadString('assets/data/tr/names_tr.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return GlossaryTr({
    for (final e in data.entries)
      if (e.value is Map)
        e.key: {
          for (final t in (e.value as Map).entries)
            '${t.key}'.toLowerCase(): '${t.value}',
        },
  });
});

/// Turkce arayuzde kayit adi sozlugu, Ingilizce arayuzde bos sozluk.
GlossaryTr contentNamesTrOf(BuildContext context, WidgetRef ref) {
  if (L10n.of(context).localeName != 'tr') return GlossaryTr.empty;
  return ref.watch(contentNamesTrProvider).value ?? GlossaryTr.empty;
}

/// Bir esya adinin gorunen hali: once buyulu esya, sonra siradan esya
/// bolumunde aranir.
///
/// Cagiran taraf cogu yerde satirin hangi tablodan geldigini bilmiyor
/// (envanter satiri, ganimet listesi, magaza rafi ayni metni tasiyor); iki
/// bolumu de denemek tek satirlik bir cozum ve ad cakismasi zararsiz --
/// "Spell Scroll" iki tabloda da ayni Turkceye ceviriliyor.
String itemNameTr(GlossaryTr names, String english) {
  final magic = names.term('magicItems', english);
  if (magic != english) return magic;
  return names.term('items', english);
}

/// Turkce arayuzde [kind] cevirileri, Ingilizce arayuzde bos harita.
///
/// Asset henuz yuklenmediyse de bos doner -- ilk kare Ingilizce cizilir,
/// yukleme bitince widget yeniden kurulur.
ContentTr contentTrOf(BuildContext context, WidgetRef ref, String kind) {
  if (L10n.of(context).localeName != 'tr') return ContentTr.empty;
  return ref.watch(contentTrProvider(kind)).value ?? ContentTr.empty;
}
