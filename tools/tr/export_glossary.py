# -*- coding: utf-8 -*-
"""`glossary.py` -> `assets/data/tr/glossary_tr.json`.

Dart tarafi stat blogun VERI alanlarini (boyut, tur, yonelim, hiz, beceri,
duyu, dil, hasar turu, durum) bu dosyadan cevirir. Kural METINLERI zaten
`retermize.py` ile bir kez cevrilip `*_tr.json` icine yazildi; bu dosya
yalnizca calisma aninda cevrilen kisa alan degerleri icin.

  python tools/tr/export_glossary.py
"""
import json
import sys

sys.path.insert(0, 'tools/tr')

import glossary  # noqa: E402

OUT = 'assets/data/tr/glossary_tr.json'


def lower_keys(mapping):
    """Veri alanlari kucuk harfli anahtarla geliyor (`fire`, `prone`)."""
    return {k.lower(): v for k, v in mapping.items()}


def main():
    data = {
        '_comment': (
            'Stat blok alan degerlerinin Turkcesi. Anahtarlar KUCUK HARF; '
            'ceviri gosterim aninda uygulanir, veritabani Ingilizce kalir. '
            'AC/DC/CR/XP/HP kisaltmalari ve ozel adlar ceviri disidir.'
        ),
        'damage': lower_keys(glossary.DAMAGE_TYPES),
        'conditions': lower_keys(glossary.CONDITIONS),
        'creatureTypes': lower_keys(glossary.CREATURE_TYPES),
        'sizes': lower_keys(glossary.SIZES),
        'skills': lower_keys(glossary.SKILLS),
        'abilities': lower_keys(glossary.ABILITIES),
        'abilityAbbr': lower_keys(glossary.ABILITY_ABBR),
        'speeds': lower_keys(glossary.SPEEDS),
        'senses': lower_keys(glossary.SENSES),
        'alignments': lower_keys(glossary.ALIGNMENTS),
        'languages': lower_keys(glossary.LANGUAGES),
        'schools': lower_keys(glossary.SCHOOLS),
        'itemRarities': lower_keys(glossary.ITEM_RARITIES),
        'armorDetails': lower_keys(glossary.ARMOR_DETAILS),
        'armorTraining': lower_keys(glossary.ARMOR_TRAINING),
        'weaponProficiencies': lower_keys(glossary.WEAPON_PROFICIENCIES),
        'tools': lower_keys(glossary.TOOLS),
        'toolGroups': lower_keys(glossary.TOOL_GROUPS),
        'proficiencySources': lower_keys(glossary.PROFICIENCY_SOURCES),
        'itemCategories': lower_keys(glossary.ITEM_CATEGORIES),
        'castingTimes': lower_keys(glossary.CASTING_TIMES),
        'spellRanges': lower_keys(glossary.SPELL_RANGES),
        'spellDurations': lower_keys(glossary.SPELL_DURATIONS),
        'weaponProperties': lower_keys(glossary.WEAPON_PROPERTIES),
        'featTypes': lower_keys(glossary.FEAT_TYPES),
        'classOptionTypes': lower_keys(glossary.CLASS_OPTION_TYPES),
        'classOptionPrerequisites':
            lower_keys(glossary.CLASS_OPTION_PREREQUISITES),
        'featPrerequisites': lower_keys(glossary.FEAT_PREREQUISITES),
    }
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    total = sum(len(v) for v in data.values() if isinstance(v, dict))
    print(f'{OUT}: {total} terim')


if __name__ == '__main__':
    main()
