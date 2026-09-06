# -*- coding: utf-8 -*-
"""`assets/data/tr/*.json` metinlerindeki oyun terimlerini Turkcelestirir.

  python tools/tr/retermize.py            # kuru calisma: ne degisecek, ozet
  python tools/tr/retermize.py --write    # dosyalari yaz

Terimler `glossary.py`de. Ozel adlar (buyu, canavar, sinif, alt sinif, sihirli
esya adlari) once maskelenir; maskeler cozulmeden hicbir degistirme onlara
dokunmaz -- yoksa "Fire Shield" buyusu "ates Shield" olurdu.

Kesme isaretiyle gelen Turkce ekler yeniden kurulur (`suffix.py`):
`Advantage'li` -> `avantajli`, `Speed'i` -> `hizi`, `Undead'e` -> `olumsuze`.
"""
import glob
import gzip
import json
import re
import sys

sys.path.insert(0, 'tools/tr')

import glossary  # noqa: E402
import suffix  # noqa: E402

# Cok kisa ya da cok genel oldugu icin maskelenmeyen ozel adlar: bunlar zaten
# sozlukte yer almadigindan degistirme onlara dokunmaz, ama maskelenirlerse
# ICLERINDEKI gercek terimleri de dondururlar ("Giant" canavari gibi).
MASK_MIN_WORDS = 1


def proper_names():
    """Korunacak ozel adlar: buyu / canavar / sihirli esya / sinif adlari."""
    names = set()
    for kind in (
        'spells',
        'creatures',
        'magicitems',
        'classes',
        'items',
        'feats',
        'species',
        'backgrounds',
    ):
        rows = json.load(
            gzip.open(f'assets/data/{kind}.json.gz', 'rt', encoding='utf-8')
        )
        for row in rows:
            name = row.get('name')
            if isinstance(name, str) and name.strip():
                names.add(name.strip())
    # Sozlukteki bir terimle BIREBIR ayni olan ad maskelenmez: "Giant" hem dev
    # dili/turu hem canavar adi; terim olarak cevrilmesi dogru.
    return {
        n
        for n in names
        if n not in glossary.ALL and len(n.split()) >= MASK_MIN_WORDS
    }


def build_mask(names):
    """Uzun ad once eslessin diye uzunluga gore sirali desen."""
    ordered = sorted(names, key=len, reverse=True)
    return re.compile(
        r'\b(?:' + '|'.join(re.escape(n) for n in ordered) + r')\b'
    )


def creature_names():
    """Canavar ozellik/eylem adlari -- metin ICINDE de ayni karsilik gecsin.

    Stat blokta baslik "Isirik" olup govdede "Bite saldirisi yapar" kalmasin
    diye adlar da terim sozlugune giriyor. Bir buyu adiyla cakisanlar (Sleep,
    Web, Fog Cloud) metinde cevrilmez -- orada buyu kastediliyor ve maskeleme
    onlari zaten dokunulmaz kiliyor; stat blok BASLIGINDA ise `content_tr`
    ayni dosyadan Turkcesini alir.
    """
    data = json.load(
        open('assets/data/tr/creature_names_tr.json', encoding='utf-8')
    )
    return {k: v for k, v in data.items() if not k.startswith('_')}


def build_table(extra=None):
    """Ozel adlari ve terimleri TEK bir desende birlestirir.

    Ayri iki gecis ise yaramiyordu: once maskeleyince `Light` buyusu
    "Bright Light" teriminin ortasini dondurup terimi bolüyordu; once
    cevirince de "Fire Shield" buyusu "ates Shield" oluyordu. Tek desende
    en UZUN eslesme kazanir, boylece "Bright Light" terim olarak, "Fire
    Shield" ozel ad olarak dogru tarafta kalir.

    Doner: (desen, {eslesen metin -> karsilik ya da None}). None = ozel ad,
    dokunma.
    """
    table = {}
    for name in proper_names():
        table[name] = None
    merged = dict(glossary.ALL)
    for src, dst in (extra or {}).items():
        merged.setdefault(src, dst)
    # Terim, ayni yazilisa sahip ozel adin onune gecer: "Giant" hem dev
    # turudur hem canavar adi, terim olarak cevrilmesi dogru.
    table.update(merged)

    ordered = sorted(table, key=len, reverse=True)
    parts = []
    for src in ordered:
        # Sozcuk siniri yalnizca harf/rakamda tutar; "Legendary Resistance
        # (3/Day)" gibi parantezle biten adlarda sondaki sinir eslesmez.
        head = chr(92) + 'b' if src[:1].isalnum() else ''
        tail = chr(92) + 'b' if src[-1:].isalnum() else ''
        # Terimin ardindan kesme + Turkce ek gelebilir; ek yeniden kurulur.
        parts.append(
            head + re.escape(src) + '(?:' + suffix.SUFFIX_PATTERN + '|' + tail + ')'
        )
    return re.compile('|'.join(parts)), table


PATTERN, TABLE = build_table(creature_names())


def _capitalize(word):
    return word[:1].upper() + word[1:] if word else word


#: Cumle basi sayilan karakterler -- terimin Turkce karsiligi buyuk yazilir.
_SENTENCE_END = '.!?:\n'


def convert(text):
    """Metindeki terimleri cevirir; ozel adlara dokunmaz."""

    def repl(m):
        whole = m.group(0)
        raw_suffix = next((g for g in m.groups() if g), None)
        src = whole[: len(whole) - len(raw_suffix) - 1] if raw_suffix else whole
        dst = TABLE.get(src, ...)
        if dst is None or dst is ...:
            return whole  # ozel ad ya da beklenmedik eslesme: oldugu gibi
        before = text[: m.start()].rstrip()
        if not before or before[-1] in _SENTENCE_END or before.endswith('- '):
            dst = _capitalize(dst)
        if raw_suffix:
            return suffix.attach(
                dst, raw_suffix, compound=dst in glossary.COMPOUND
            )
        return dst

    return polish(PATTERN.sub(repl, text))


# Terim degistirmenin ardindan kalan bozuk tamlamalar. Sozcuk sozcuk ceviri
# "Hit Point azamisi" -> "can azamisi" uretiyor; Turkcesi "azami can".
POLISH = [
    (r'\bcan azamisi\b', 'azami canı'),
    (r'\bcan azami\b', 'azami can'),
    (r'\bgeçici can azamisi\b', 'azami geçici canı'),
    (r'\bcan geri kazanamaz\b', 'can geri kazanamaz'),
    # "0 can'e dusen" -> ek zaten cozuldu, kalan yazim: "0 cana"
    (r'\b0 can\b(?! )', '0 can'),
    # Ingilizcede sifat olan hasar turu Turkcede de sifat: "12 kesici hasari"
    # degil "12 kesici hasar".
    (
        r'\b(asit|ezici|soğuk|ateş|kuvvet|yıldırım|nekrotik|delici|zehir|'
        r'zihinsel|ışıma|kesici|gürleme) hasarı\b',
        r'\1 hasar',
    ),
    # "avantajli olur" zaten dogru; "Advantage'a sahip" kaliplari:
    (r'\bavantaja sahip\b', 'avantajlı'),
    (r'\bdezavantaja sahip\b', 'dezavantajlı'),
    # Onceki cevirilerde "a Magic action" -> "Bir Magic eylemi" gibi yariya
    # kalmis kaliplar var; eylem adi burada tamamlaniyor.
    (r'\bMagic eylemi\b', 'Büyü eylemi'),
    (r'\bUtilize eylemi\b', 'Kullanma eylemi'),
    (r'\bDash eylemi\b', 'Koşma eylemi'),
    (r'\bDisengage eylemi\b', 'Çekilme eylemi'),
    (r'\bDodge eylemi\b', 'Sakınma eylemi'),
    (r'\bHide eylemi\b', 'Saklanma eylemi'),
    (r'\bAttack eylemi\b', 'Saldırı eylemi'),
    (r'\bStudy eylemi\b', 'İnceleme eylemi'),
    (r'\bSearch eylemi\b', 'Arama eylemi'),
    (r'\bReady eylemi\b', 'Hazırlanma eylemi'),
    (r'\bInfluence eylemi\b', 'Etkileme eylemi'),
]

#: "Poison Immunity" -> "zehir bağışıklık" degil "zehir bağışıklığı":
#: savunma sozcukleri hasar turu/durum ardindan tamlama kurar.
_DEFENSE = {'direnç': 'direnci', 'bağışıklık': 'bağışıklığı', 'zafiyet': 'zafiyeti'}
_MODIFIER = (
    'asit|ezici|soğuk|ateş|kuvvet|yıldırım|nekrotik|delici|zehir|zihinsel|'
    'ışıma|kesici|gürleme|durum|hasar'
)
POLISH += [
    (
        re.compile(rf'\b({_MODIFIER}) {word}\b(?![a-zçğıöşü])'),
        rf'\1 {form}',
    )
    for word, form in _DEFENSE.items()
]
POLISH = [
    (re.compile(p) if isinstance(p, str) else p, r) for p, r in POLISH
]


def polish(text):
    for pattern, repl in POLISH:
        text = pattern.sub(repl, text)
    return text


def main():
    write = '--write' in sys.argv
    # Sozluk dosyalarinin KENDISI cevrilmez: anahtarlari Ingilizce kalmali
    # (esleme onlarla yapiliyor), degerleri zaten Turkce.
    skip = {'creature_names_tr.json', 'glossary_tr.json'}

    total = 0
    for path in sorted(glob.glob('assets/data/tr/*_tr.json')):
        if path.replace('\\', '/').rsplit('/', 1)[-1] in skip:
            continue
        data = json.load(open(path, encoding='utf-8'))
        changed = 0
        for key, entry in data.items():
            if key.startswith('_') or not isinstance(entry, dict):
                continue
            for field, text in entry.items():
                new = convert(text)
                if new != text:
                    entry[field] = new
                    changed += 1
        total += changed
        print(f'{path}: {changed} alan')
        if write and changed:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
                f.write('\n')
    print(f'toplam {total} alan' + ('' if write else ' (kuru calisma)'))
    if suffix.unresolved:
        print('COZULEMEYEN EK:', sorted(suffix.unresolved))


if __name__ == '__main__':
    main()
