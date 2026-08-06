import 'dart:math';

import 'package:dm_table/domain/rules/name_generator.dart';
import 'package:dm_table/domain/rules/random_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RandomTableRow row(int min, int max, String text) =>
      (min: min, max: max, text: text);

  group('rowFor', () {
    final rows = [row(1, 5, 'A'), row(6, 10, 'B'), row(11, 20, 'C')];

    test('sinir degerleri DAHIL', () {
      expect(rowFor(1, rows)!.text, 'A');
      expect(rowFor(5, rows)!.text, 'A');
      expect(rowFor(6, rows)!.text, 'B');
      expect(rowFor(10, rows)!.text, 'B');
      expect(rowFor(11, rows)!.text, 'C');
      expect(rowFor(20, rows)!.text, 'C');
    });

    test('kapsanmayan sayi null doner', () {
      expect(rowFor(21, rows), isNull);
      expect(rowFor(0, rows), isNull);
    });

    test('bos tablo firlatmaz', () {
      expect(rowFor(5, const []), isNull);
    });
  });

  group('rollOn', () {
    test('atis 1..sides araliginda', () {
      final rows = distributeEvenly(['A', 'B'], 6);
      final rng = Random(42);
      for (var i = 0; i < 200; i++) {
        final result = rollOn(rows, 6, rng);
        expect(result.roll, inInclusiveRange(1, 6));
        expect(
          result.row,
          isNotNull,
          reason: 'tam kapsanan tabloda satır bulunmalı',
        );
      }
    });

    test('gecersiz zar yuzu d20 varsayilir', () {
      final rng = Random(1);
      for (var i = 0; i < 50; i++) {
        expect(rollOn(const [], 7, rng).roll, inInclusiveRange(1, 20));
      }
    });
  });

  group('validateRows', () {
    test('tam kapsayan tablo temiz', () {
      expect(validateRows(distributeEvenly(['A', 'B', 'C'], 6), 6), isEmpty);
    });

    test('bosluk yakalanir', () {
      expect(validateRows([row(1, 5, 'A')], 20), contains('gap'));
    });

    test('cakisma yakalanir', () {
      final rows = [row(1, 10, 'A'), row(5, 20, 'B')];
      expect(validateRows(rows, 20), contains('overlap'));
    });

    test('zar disi aralik yakalanir', () {
      expect(validateRows([row(1, 30, 'A')], 20), contains('outOfRange'));
    });

    test('ters aralik yakalanir', () {
      expect(validateRows([row(10, 3, 'A')], 20), contains('emptyRange'));
    });

    test('bos tablo uyari vermez', () {
      expect(validateRows(const [], 20), isEmpty);
    });
  });

  group('distributeEvenly', () {
    test('tum yuzleri kapsar, artik kalmaz', () {
      for (final sides in kDiceSides) {
        final rows = distributeEvenly(['A', 'B', 'C'], sides);
        expect(rows.first.min, 1);
        expect(rows.last.max, sides, reason: 'd$sides tam kapanmalı');
        expect(
          validateRows(rows, sides),
          isEmpty,
          reason: 'd$sides temiz olmalı',
        );
      }
    });

    test('bolunmeyen sayida artik bastan dagitilir', () {
      // 20 / 3 = 6 kalan 2 -> 7, 7, 6
      final rows = distributeEvenly(['A', 'B', 'C'], 20);
      expect(rows.map((r) => r.max - r.min + 1).toList(), [7, 7, 6]);
    });

    test('satir sayisi zar yuzune esitse her satir bir yuz', () {
      final rows = distributeEvenly(['A', 'B', 'C', 'D'], 4);
      expect(rows.map((r) => r.min).toList(), [1, 2, 3, 4]);
      expect(rows.map((r) => r.max).toList(), [1, 2, 3, 4]);
    });

    test('yuzden fazla satir kirpilir (sigmayan atilir)', () {
      final rows = distributeEvenly(['A', 'B', 'C', 'D', 'E', 'F'], 4);
      expect(rows, hasLength(4));
      expect(validateRows(rows, 4), isEmpty);
    });

    test('bos liste bos doner', () {
      expect(distributeEvenly(const [], 20), isEmpty);
    });
  });

  group('isim ureteci', () {
    test('her kultur istenen sayida bos olmayan isim uretir', () {
      for (final culture in NameCulture.values) {
        final names = generateNames(culture, count: 10, rng: Random(7));
        expect(names, hasLength(10), reason: '$culture');
        expect(
          names.every((n) => n.trim().isNotEmpty),
          isTrue,
          reason: '$culture boş isim üretti',
        );
      }
    });

    test('ayni tohum ayni sonucu verir (deterministik)', () {
      final a = generateNames(NameCulture.elf, count: 8, rng: Random(99));
      final b = generateNames(NameCulture.elf, count: 8, rng: Random(99));
      expect(a, b);
    });

    test('uretilen isimler tekrar etmez', () {
      final names = generateNames(NameCulture.human, count: 15, rng: Random(3));
      expect(names.toSet().length, names.length);
    });

    test('meyhane adlari dile gore degisir', () {
      final en = generateNames(NameCulture.tavern, count: 5, rng: Random(5));
      final tr = generateNames(
        NameCulture.tavern,
        count: 5,
        turkish: true,
        rng: Random(5),
      );
      expect(en.every((n) => n.startsWith('The ')), isTrue);
      expect(tr.every((n) => !n.startsWith('The ')), isTrue);
    });

    test('count 1 altina dusmez', () {
      expect(generateNames(NameCulture.dwarf, count: 0), hasLength(1));
    });

    test('her kultur bir kategoriye ait ve her kategoride tur var', () {
      for (final category in NameCategory.values) {
        expect(
          NameCulture.values.where((c) => c.category == category),
          isNotEmpty,
          reason: '$category bos',
        );
      }
      // Arayuz kisi adlarina ozel secenekleri kategoriye gore gosteriyor.
      expect(NameCulture.dwarf.isPerson, isTrue);
      expect(NameCulture.tavern.isPerson, isFalse);
    });

    test('kalip adlar sablon isaretcisi sizdirmaz', () {
      for (final culture in NameCulture.values) {
        for (final turkish in [false, true]) {
          final names = generateNames(
            culture,
            count: 12,
            turkish: turkish,
            rng: Random(11),
          );
          for (final name in names) {
            expect(
              name.contains('{'),
              isFalse,
              reason: '$culture ($turkish) ham sablon dondurdu: $name',
            );
            // Bosluksuz yapistirma ("BrokenHalls") ve bas/son bosluk hatasi.
            expect(name, name.trim(), reason: '$culture: "$name"');
          }
        }
      }
    });

    test('cinsiyet secimi sonucu degistirir', () {
      final male = generateNames(
        NameCulture.elf,
        count: 12,
        gender: NameGender.male,
        rng: Random(4),
      );
      final female = generateNames(
        NameCulture.elf,
        count: 12,
        gender: NameGender.female,
        rng: Random(4),
      );
      expect(male.toSet().intersection(female.toSet()), isEmpty);
    });

    test('cinsiyetsiz kulturde kadin secimi de isim uretir', () {
      expect(NameCulture.goblin.hasGender, isFalse);
      final names = generateNames(
        NameCulture.goblin,
        count: 6,
        gender: NameGender.female,
        rng: Random(8),
      );
      expect(names, hasLength(6));
      expect(names.every((n) => n.isNotEmpty), isTrue);
    });

    test('soyad iki kelimeli isim verir, kapaliyken tek kelime', () {
      final withSurname = generateNames(
        NameCulture.dwarf,
        count: 8,
        surname: true,
        rng: Random(12),
      );
      expect(withSurname.every((n) => n.split(' ').length == 2), isTrue);

      final without = generateNames(
        NameCulture.dwarf,
        count: 8,
        rng: Random(12),
      );
      expect(without.every((n) => !n.contains(' ')), isTrue);
    });

    test('soyadi olmayan kulturde bayrak isimleri bozmaz', () {
      expect(NameCulture.tabaxi.hasSurname, isFalse);
      final names = generateNames(
        NameCulture.tabaxi,
        count: 6,
        surname: true,
        rng: Random(2),
      );
      expect(names.every((n) => n.trim().isNotEmpty), isTrue);
    });

    test('yer/kalip kulturlerinde cinsiyet ve soyad yok sayilir', () {
      final plain = generateNames(NameCulture.city, count: 6, rng: Random(6));
      final fancy = generateNames(
        NameCulture.city,
        count: 6,
        gender: NameGender.female,
        surname: true,
        rng: Random(6),
      );
      expect(plain, fancy);
    });

    test('30 isim istenince havuz tukenmiyor', () {
      for (final culture in NameCulture.values) {
        final names = generateNames(culture, count: 30, rng: Random(21));
        expect(names, hasLength(30), reason: '$culture');
      }
    });
  });
}
