# -*- coding: utf-8 -*-
"""`assets/data/tr/*.json` icinde kalan Ingilizce obekleri raporlar.

  python tools/tr/audit_english.py

Ozel adlar (buyu, canavar, esya, sinif adlari) elenir; geriye kalanlar ya
bilerek Ingilizce birakilmis kategorilerdir (sinif ozellik adlari: Rage,
Bardic Inspiration) ya da sozluge eklenmesi gereken terimlerdir.
"""
import collections
import glob
import json
import os
import re
import sys

sys.path.insert(0, 'tools/tr')

import retermize  # noqa: E402

TR = 'çğıöşüÇĞİÖŞÜâîû'
WORD = 'A-Za-z' + TR

#: Turkce sozcuklerin ASCII govdesi buyuk harfli yakalanabiliyor; bunlar
#: Ingilizce degil, raporun gurultusu.
TURKISH = {
    'Bir', 'Hedef', 'Her', 'Onu', 'Sen', 'Kadar', 'Bunu', 'Onunla', 'Seviye',
    'Tablo', 'Silah', 'Yetenek', 'Okul', 'Nadir', 'Orta', 'Koni', 'Koruma',
    'Kehanet', 'Tepki', 'Materyal', 'Ejderha', 'Bilgelik', 'Karizma',
    'Menzilli', 'Kurtarma', 'Bonusun', 'Seviyesi', 'Sezgi', 'Atletizm',
    'Ufak', 'Dostane', 'Elemental', 'Bulunur', 'Jeton', 'Tetik', 'Ayarlanan',
    'Bonus Eylem', 'Uzun Dinlenme', 'Her Biri', 'Yeterlilik Bonusun',
    'Bilgelik Kurtarma', 'Hedef Orta', 'Sava', 'Yay', 'Din', 'Tarih', 'Doga',
    'Yakin', 'Vurus', 'Zar', 'Saldiri', 'Can', 'Hat', 'Kup', 'Kure',
}


def main():
    proper = retermize.proper_names()
    mask = re.compile(
        r'\b(?:'
        + '|'.join(re.escape(n) for n in sorted(proper, key=len, reverse=True))
        + r')\b'
    )
    phrase = re.compile(
        rf'(?<![{WORD}])[A-Z][a-z]{{2,}}(?:[ -][A-Z][a-z]+)*(?![{WORD}])'
    )

    grand = collections.Counter()
    for path in sorted(glob.glob('assets/data/tr/*_tr.json')):
        name = os.path.basename(path)
        if name in ('creature_names_tr.json', 'glossary_tr.json'):
            continue
        data = json.load(open(path, encoding='utf-8'))
        counter = collections.Counter()
        for key, entry in data.items():
            if key.startswith('_') or not isinstance(entry, dict):
                continue
            for text in entry.values():
                for m in phrase.finditer(mask.sub(' ', text)):
                    if m.group(0) not in TURKISH:
                        counter[m.group(0)] += 1
        grand.update(counter)
        top = ', '.join(f'{w}({n})' for w, n in counter.most_common(12))
        print(f'{name}: {sum(counter.values())} eslesme')
        print(f'   {top}')

    print(f'\nTOPLAM {sum(grand.values())} eslesme, {len(grand)} benzersiz')


if __name__ == '__main__':
    main()
