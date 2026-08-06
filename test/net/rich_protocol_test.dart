import 'package:dm_table/net/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zengin karakter alanlari JSON'dan gecince (WS uzerinden) korunmali.
void main() {
  test('PlayerCharacterView + spells + attuned round-trip', () {
    const view = PlayerCharacterView(
      id: 'c1',
      name: 'Rohan',
      hitPointsCurrent: 8,
      hitPointsMax: 10,
      speciesName: 'Human',
      backgroundName: 'Soldier',
      alignment: 'Neutral Good',
      weaponProficiencies: ['Simple Weapons'],
      armorProficiencies: ['Light Armor'],
      toolProficiencies: ["Thieves' Tools"],
      languages: ['Common', 'Elvish'],
      notes: 'Geçmiş',
      appearance: 'Uzun',
      personality: 'Cesur',
      ideal: 'Özgürlük',
      bond: 'Köy',
      flaw: 'Aceleci',
      portraitUrl: '/media/foto.jpg',
      inventory: [
        InventoryLine(
          id: 'i1',
          name: 'Ring of Protection',
          equipped: true,
          attuned: true,
          magic: true,
        ),
      ],
      spells: [
        PlayerSpellView(
          name: 'Fireball',
          level: 3,
          school: 'Evocation',
          prepared: true,
        ),
      ],
    );

    final back = PlayerCharacterView.fromJson(view.toJson());

    expect(back.speciesName, 'Human');
    expect(back.backgroundName, 'Soldier');
    expect(back.alignment, 'Neutral Good');
    expect(back.weaponProficiencies, ['Simple Weapons']);
    expect(back.languages, ['Common', 'Elvish']);
    expect(back.personality, 'Cesur');
    expect(back.ideal, 'Özgürlük');
    expect(back.portraitUrl, '/media/foto.jpg');
    expect(back.inventory.single.attuned, isTrue);
    expect(back.inventory.single.magic, isTrue);
    expect(back.spells.single.name, 'Fireball');
    expect(back.spells.single.level, 3);
    expect(back.spells.single.prepared, isTrue);
  });

  test('eski JSON (yeni alanlar yok) varsayilana duser', () {
    final back = PlayerCharacterView.fromJson({
      'id': 'c1',
      'name': 'Eski',
      'hp': 5,
      'hpMax': 5,
    });
    expect(back.speciesName, isNull);
    expect(back.weaponProficiencies, isEmpty);
    expect(back.languages, isEmpty);
    expect(back.notes, '');
    expect(back.spells, isEmpty);
    expect(back.portraitUrl, isNull);
  });
}
