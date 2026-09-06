import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Iki ARB dosyasinin ESLIGINI korur.
///
/// **Bu dosya neden var:** ceviriler elle yaziliyor ve `flutter gen-l10n`
/// eksik bir anahtari HATA saymiyor -- sablon dosyada (`app_tr.arb`) olup
/// digerinde olmayan bir anahtar icin sessizce sablondaki metni uretiyor.
/// Sonuc: uygulama derleniyor, testler geciyor ve Ingilizce arayuzde
/// Turkce bir cumle beliriyor. 1600'u askin anahtarda bunu gozle yakalamak
/// mumkun degil.
///
/// Ayni sekilde yer tutucular (`{count}`, `{name}`) iki dilde AYNI olmali:
/// birinde `{left}` digerinde `{kalan}` yazarsa uretilen imzalar catisir.
void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> tr;

  setUpAll(() {
    en = _read('lib/l10n/app_en.arb');
    tr = _read('lib/l10n/app_tr.arb');
  });

  test('iki dilde de ayni anahtar kumesi var', () {
    final enKeys = _messageKeys(en);
    final trKeys = _messageKeys(tr);

    expect(
      enKeys.difference(trKeys).toList()..sort(),
      isEmpty,
      reason: 'app_en.arb icinde olup app_tr.arb icinde OLMAYAN anahtarlar',
    );
    expect(
      trKeys.difference(enKeys).toList()..sort(),
      isEmpty,
      reason: 'app_tr.arb icinde olup app_en.arb icinde OLMAYAN anahtarlar',
    );
  });

  test('yer tutucular iki dilde ayni', () {
    final mismatched = <String>[];
    for (final key in _messageKeys(en).intersection(_messageKeys(tr))) {
      final a = _placeholders('${en[key]}');
      final b = _placeholders('${tr[key]}');
      if (a.length != b.length || !a.containsAll(b)) {
        mismatched.add('$key: en=$a tr=$b');
      }
    }
    expect(mismatched..sort(), isEmpty);
  });

  test('hicbir mesaj bos degil', () {
    final empty = <String>[];
    for (final (locale, arb) in [('en', en), ('tr', tr)]) {
      for (final key in _messageKeys(arb)) {
        if ('${arb[key]}'.trim().isEmpty) empty.add('$locale/$key');
      }
    }
    expect(empty..sort(), isEmpty);
  });

  test('oksuz @metadata yok', () {
    // `@@locale` arac ayari, `@_bolum` ise ARB'nin bolum basligi kalibi
    // (gen-l10n ikisini de yok sayar); yalnizca gercek `@anahtar` metadatasi
    // bir mesaja isaret etmek zorunda.
    final orphans = <String>[];
    for (final (locale, arb) in [('en', en), ('tr', tr)]) {
      for (final key in arb.keys) {
        if (!key.startsWith('@') ||
            key.startsWith('@@') ||
            key.startsWith('@_')) {
          continue;
        }
        final base = key.substring(1);
        if (!arb.containsKey(base)) orphans.add('$locale/$key');
      }
    }
    expect(orphans..sort(), isEmpty);
  });
}

Map<String, dynamic> _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path bulunamadi');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
}

/// `@`/`@@` ile baslamayan gercek mesaj anahtarlari.
Set<String> _messageKeys(Map<String, dynamic> arb) => {
  for (final key in arb.keys)
    if (!key.startsWith('@')) key,
};

/// Mesajdaki `{ad}` yer tutucularinin adlari.
///
/// ICU cogul/secim sozdizimindeki (`{count, plural, ...}`) ilk parcayi da
/// yakalar: virgulden onceki ad yer tutucudur.
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)').allMatches(message)) match.group(1)!,
};
