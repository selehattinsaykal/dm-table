import 'package:dm_table/data/encounter_briefing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncounterBriefing serilestirme', () {
    test('gidip gelince alanlar korunur', () {
      const b = (
        summary: 'Taslar yuvarlaniyor',
        objective: 'Bogazdan sag cik',
        tactics: 'Yuksekten tas atarlar',
        terrain: 'Dar bogaz',
        reinforcements: 'Iki tur sonra iki goblin',
        scaling: 'Zorlanirlarsa kacarlar',
        dmNotes: 'Reis en arkada',
      );
      final back = encounterBriefingFromJson(encounterBriefingToJson(b));
      expect(back, b);
    });

    test('null/bos/bozuk kayit bos brifinge duser', () {
      expect(encounterBriefingFromJson(null), emptyEncounterBriefing);
      expect(encounterBriefingFromJson('   '), emptyEncounterBriefing);
      expect(
        encounterBriefingFromJson('bu json degil'),
        emptyEncounterBriefing,
      );
      // Dizi geldiyse de cokmemeli.
      expect(encounterBriefingFromJson('[1,2]'), emptyEncounterBriefing);
    });

    test('eksik alanlar bos gelir', () {
      final b = encounterBriefingFromJson('{"objective":"Sag cik"}');
      expect(b.objective, 'Sag cik');
      expect(b.tactics, isEmpty);
      expect(briefingIsEmpty(b), isFalse);
    });

    test('briefingIsEmpty yalniz hepsi bosken dogru', () {
      expect(briefingIsEmpty(emptyEncounterBriefing), isTrue);
      expect(
        briefingIsEmpty((
          summary: '',
          objective: '',
          tactics: '',
          terrain: '',
          reinforcements: '',
          scaling: '',
          dmNotes: 'x',
        )),
        isFalse,
      );
    });
  });

  group('EncounterLoot serilestirme', () {
    test('gidip gelince para ve esyalar korunur', () {
      const loot = (
        coinsCp: 1250,
        items: <EncounterLootItem>[
          (
            id: 'a',
            name: 'Ates Kilici',
            magic: true,
            itemKey: null,
            magicItemKey: 'flame-tongue',
          ),
          (
            id: 'b',
            name: 'Halat',
            magic: false,
            itemKey: 'rope-hempen',
            magicItemKey: null,
          ),
        ],
      );
      final back = encounterLootFromJson(encounterLootToJson(loot));
      expect(back.coinsCp, 1250);
      expect(back.items.length, 2);
      expect(back.items.first.magicItemKey, 'flame-tongue');
      expect(back.items.last.itemKey, 'rope-hempen');
    });

    test('anahtarsiz esya cozulmemis sayilir', () {
      const item = (
        id: 'x',
        name: 'Uydurma Asa',
        magic: true,
        itemKey: null,
        magicItemKey: null,
      );
      expect(lootItemResolved(item), isFalse);
      expect(
        lootItemResolved((
          id: 'y',
          name: 'Halat',
          magic: false,
          itemKey: 'rope',
          magicItemKey: null,
        )),
        isTrue,
      );
    });

    test('adsiz esyalar atilir, bos anahtar null olur', () {
      final loot = encounterLootFromJson(
        '{"coinsCp":10,"items":['
        '{"name":"  ","itemKey":"x"},'
        '{"name":"Halat","itemKey":"","magicItemKey":null}]}',
      );
      expect(loot.items.length, 1);
      expect(loot.items.single.name, 'Halat');
      expect(loot.items.single.itemKey, isNull);
    });

    test('null/bozuk kayit bos ganimete duser', () {
      expect(encounterLootFromJson(null), emptyEncounterLoot);
      expect(encounterLootFromJson('bozuk'), emptyEncounterLoot);
      expect(lootIsEmpty(emptyEncounterLoot), isTrue);
    });

    test('yalniz para olan ganimet bos degildir', () {
      final loot = encounterLootFromJson('{"coinsCp":500,"items":[]}');
      expect(lootIsEmpty(loot), isFalse);
      expect(loot.coinsCp, 500);
    });
  });
}
