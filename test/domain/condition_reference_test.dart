import 'dart:convert';

import 'package:dm_table/domain/rules/condition_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String payload(List<({String gs, String desc})> descriptions) => jsonEncode({
    'key': 'x',
    'descriptions': [
      for (final d in descriptions) {'gamesystem': d.gs, 'desc': d.desc},
    ],
  });

  group('conditionFrom', () {
    test('2024 metni 2014\'e TERCIH edilir', () {
      final entry = conditionFrom(
        'blinded',
        'Blinded',
        payload([
          (gs: 'a5e', desc: 'a5e metni'),
          (gs: '5e-2014', desc: 'eski metin'),
          (gs: '5e-2024', desc: 'yeni metin'),
        ]),
      );
      expect(entry, isNotNull);
      expect(entry!.desc, 'yeni metin');
      expect(entry.key, 'blinded');
      expect(entry.name, 'Blinded');
    });

    test('yalniz 2014 varsa ona duser', () {
      final entry = conditionFrom(
        'x',
        'X',
        payload([(gs: '5e-2014', desc: 'eski metin')]),
      );
      expect(entry!.desc, 'eski metin');
    });

    test('yalniz A5e metni olan kayit ELENIR', () {
      // Veri setinde 6 tane boyle kayit var (Bloodied, Confused, ...);
      // uygulamada hic gosterilmemeli.
      final entry = conditionFrom(
        'a5e-ag_bloodied',
        'Bloodied',
        payload([(gs: 'a5e', desc: 'yalnizca a5e')]),
      );
      expect(entry, isNull);
    });

    test('bos metin yok sayilir', () {
      final entry = conditionFrom(
        'x',
        'X',
        payload([
          (gs: '5e-2024', desc: '   '),
          (gs: '5e-2014', desc: 'gecerli'),
        ]),
      );
      expect(entry!.desc, 'gecerli');
    });

    test('bozuk/eksik veri firlatmaz', () {
      expect(conditionFrom('x', 'X', 'bu json degil'), isNull);
      expect(conditionFrom('x', 'X', '{}'), isNull);
      expect(conditionFrom('x', 'X', '{"descriptions": 42}'), isNull);
      expect(conditionFrom('x', 'X', '{"descriptions": []}'), isNull);
    });
  });

  group('conditionBullets', () {
    test('SRD 2024 bicimini (\\n * ) boler', () {
      const desc =
          'While you have the Blinded condition, you experience the following '
          'effects.\n * Can’t See. You can’t see.\n * Attacks '
          'Affected. Attack rolls against you have Advantage.';
      final parts = conditionBullets(desc);
      expect(parts, hasLength(3));
      expect(parts.first, startsWith('While you have'));
      expect(parts[1], startsWith('Can'));
      expect(parts[2], startsWith('Attacks Affected.'));
    });

    test('SRD 2014 bicimini (\\r\\n*) boler', () {
      const desc = 'Giris.\r\n* Birinci madde.\r\n* Ikinci madde.';
      expect(conditionBullets(desc), hasLength(3));
    });

    test('satir sonu tirelemesi birlestirilir', () {
      // Kaynak veride "move- ment" gibi kirilmalar var.
      const desc = 'Giris.\n* Spend move- ment equal to half your Speed.';
      final parts = conditionBullets(desc);
      expect(parts[1], contains('movement'));
      expect(parts[1], isNot(contains('move- ment')));
    });

    test('maddesiz metin tek parca doner', () {
      expect(conditionBullets('Tek cumlelik kural.'), ['Tek cumlelik kural.']);
    });

    test('bos metin bos liste', () {
      expect(conditionBullets(''), isEmpty);
      expect(conditionBullets('   \n  '), isEmpty);
    });
  });
}
