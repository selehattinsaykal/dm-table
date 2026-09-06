# -*- coding: utf-8 -*-
"""Turkce ek cozumleme ve yeniden uretme.

Ceviri oncesi metinde oyun terimleri ozel ad gibi kesme isaretiyle ek aliyordu
(`Advantage'li`, `Speed'inden`, `Undead'lerinde`). Terim Turkcelesince kesme
kalkar ve ek, YENI sozcugun unlusune gore yeniden kurulmali.

Ek tek bir parca degil, bir MORFEM ZINCIRI: `'larindan` = cogul + iyelik +
ayrilma. Bu yuzden once kaynak ek zinciri morfemlere ayristirilir ([parse]),
sonra ayni zincir hedef sozcuk uzerinde yeniden uretilir ([build]).
"""

BACK = 'aıou'  # kalin unluler
FRONT = 'eiöü'  # ince unluler
VOWELS = BACK + FRONT
HARD = 'pçtkfhsş'  # sert unsuzler: -DA/-DAn/-DIr sertlesir

#: Cozulemeyen ek zincirleri -- cagiran taraf raporlasin diye biriktirilir.
unresolved = set()


#: Kalin unluyle bitse de INCE ek alan alintilar (kontrol -> kontroller).
_FRONT_L = {'kontrol', 'hal', 'sual', 'usul', 'saat', 'harf', 'rol'}


def _last_vowel(word):
    if word.rsplit(' ', 1)[-1].lower().rstrip('ıiuü') in _FRONT_L:
        return 'e'
    for ch in reversed(word.lower()):
        if ch in VOWELS:
            return ch
    return 'a'


def _A(word):
    """2'li uyum: a / e"""
    return 'a' if _last_vowel(word) in BACK else 'e'


def _I(word):
    """4'lu uyum: ı / i / u / ü"""
    v = _last_vowel(word)
    return {'a': 'ı', 'ı': 'ı', 'e': 'i', 'i': 'i', 'o': 'u', 'u': 'u'}.get(
        v, 'ü'
    )


def _D(word):
    return 't' if word and word[-1].lower() in HARD else 'd'


def _vowel_end(word):
    return bool(word) and word[-1].lower() in VOWELS


#: Unsuz yumusamasi: unluyle baslayan ek alinca sondaki sert unsuz yumusar
#: (direnc + i -> direnci, bagisiklik + i -> bagisikligi).
_SOFTEN = {'p': 'b', 'ç': 'c', 't': 'd', 'k': 'ğ'}

#: Yumusamayan govdeler -- tek heceliler ve alintilarin cogu sert kalir.
_NO_SOFTEN = {
    'ateş',
    'ışık',
    'at',
    'ok',
    'üst',
    'süt',
    'saç',
    'kurt',
    'kat',
    'suç',
    'ilk',
    'zehir',
    'top',
    'çok',
    'ak',
    'ip',
}


def soften(word):
    """Unluyle baslayan bir ek almadan once govdenin son unsuzunu yumusatir."""
    if not word:
        return word
    head = word.rsplit(' ', 1)[-1].lower()
    if head in _NO_SOFTEN:
        return word
    # Tek heceli govdeler genelde yumusamaz ("can" -> "canı" zaten sorunsuz;
    # "ok" -> "oku" degil "okı" degil). Hece sayisi = unlu sayisi.
    if sum(1 for ch in head if ch in VOWELS) < 2:
        return word
    new = _SOFTEN.get(word[-1].lower())
    if new is None:
        return word
    return word[:-1] + (new.upper() if word[-1].isupper() else new)


# --- morfemler ----------------------------------------------------------
# Her morfem: (ad, yuzey bicimleri, uretici).
# Yuzey bicimleri cozumleme icin; uretici hedef sozcuge gore yazar.
_MORPHEMES = [
    ('PLURAL', ('lar', 'ler'), lambda w, p: 'l' + _A(w) + 'r'),
    ('ADJ', ('lı', 'li', 'lu', 'lü'), lambda w, p: 'l' + _I(w)),
    (
        'POSS1P',
        ('ımız', 'imiz', 'umuz', 'ümüz', 'mız', 'miz', 'muz', 'müz'),
        lambda w, p: ('' if _vowel_end(w) else _I(w)) + 'm' + _I(w) + 'z',
    ),
    (
        'POSS2P',
        ('ınız', 'iniz', 'unuz', 'ünüz', 'nız', 'niz', 'nuz', 'nüz'),
        lambda w, p: ('' if _vowel_end(w) else _I(w)) + 'n' + _I(w) + 'z',
    ),
    (
        'POSS3',
        ('sı', 'si', 'su', 'sü', 'ı', 'i', 'u', 'ü'),
        lambda w, p: ('s' if _vowel_end(w) else '') + _I(w),
    ),
    (
        'POSS2',
        ('ın', 'in', 'un', 'ün'),
        lambda w, p: ('' if _vowel_end(w) else _I(w)) + 'n',
    ),
    (
        'GEN',
        ('nın', 'nin', 'nun', 'nün', 'ın', 'in', 'un', 'ün'),
        lambda w, p: ('n' if p or _vowel_end(w) else '') + _I(w) + 'n',
    ),
    (
        'ACC',
        ('yı', 'yi', 'yu', 'yü', 'nı', 'ni', 'nu', 'nü', 'ı', 'i', 'u', 'ü'),
        lambda w, p: ('n' if p else 'y' if _vowel_end(w) else '') + _I(w),
    ),
    (
        'DAT',
        ('ya', 'ye', 'na', 'ne', 'a', 'e'),
        lambda w, p: ('n' if p else 'y' if _vowel_end(w) else '') + _A(w),
    ),
    (
        'LOC',
        ('nda', 'nde', 'da', 'de', 'ta', 'te'),
        lambda w, p: ('n' if p else '') + _D(w) + _A(w),
    ),
    (
        'ABL',
        ('ndan', 'nden', 'dan', 'den', 'tan', 'ten'),
        lambda w, p: ('n' if p else '') + _D(w) + _A(w) + 'n',
    ),
    (
        'INS',
        ('yla', 'yle', 'la', 'le'),
        lambda w, p: ('y' if _vowel_end(w) else '') + 'l' + _A(w),
    ),
    ('KI', ('ki',), lambda w, p: 'ki'),
    (
        'COP',
        ('dır', 'dir', 'dur', 'dür', 'tır', 'tir', 'tur', 'tür'),
        lambda w, p: _D(w) + _I(w) + 'r',
    ),
    (
        'PERS2P',
        ('sınız', 'siniz', 'sunuz', 'sünüz'),
        lambda w, p: 's' + _I(w) + 'n' + _I(w) + 'z',
    ),
    ('PERS2', ('sın', 'sin', 'sun', 'sün'), lambda w, p: 's' + _I(w) + 'n'),
    ('PERS2SG', ('n',), lambda w, p: 'n'),
    ('PERF', ('mış', 'miş', 'muş', 'müş'), lambda w, p: 'm' + _I(w) + 'ş'),
    (
        'COND',
        ('ysa', 'yse', 'sa', 'se'),
        lambda w, p: ('y' if _vowel_end(w) else '') + 's' + _A(w),
    ),
    (
        'WHILE',
        ('yken', 'ken'),
        lambda w, p: ('y' if _vowel_end(w) else '') + 'ken',
    ),
]

_BY_NAME = {name: gen for name, _, gen in _MORPHEMES}

#: Turkcede eklerin gelis sirasi; cozumleme bu sirayi izler.
_ORDER = (
    'PLURAL',
    'ADJ',
    'POSS1P',
    'POSS2P',
    'POSS3',
    'POSS2',
    'GEN',
    'ACC',
    'DAT',
    'LOC',
    'ABL',
    'INS',
    'KI',
    'PERF',
    'COND',
    'WHILE',
    'COP',
    'PERS2P',
    'PERS2',
    'PERS2SG',
)

_SURFACES = {name: forms for name, forms, _ in _MORPHEMES}

#: Unluyle baslayan ek alan morfemler -- govde yumusamasini tetiklerler.
_VOWEL_INITIAL = {'POSS3', 'POSS2', 'POSS1P', 'POSS2P', 'GEN', 'ACC', 'DAT'}


def parse(raw):
    """Ek zincirini morfemlere ayirir; EN AZ morfemli cozum secilir.

    En kisa cozum dogru olani: `'inden` ayrisimi POSS3+ABL (iki morfem),
    POSS3+POSS2+LOC gibi daha uzun bir zincir degil.
    """
    best = None
    for chain in _solutions(raw, 0):
        if best is None or len(chain) < len(best):
            best = chain
    return best


def _solutions(raw, index):
    """[raw] ekinin [index]'ten itibaren tum ayrisimlarini uretir."""
    if not raw:
        yield []
        return
    for start in range(index, len(_ORDER)):
        name = _ORDER[start]
        for form in sorted(_SURFACES[name], key=len, reverse=True):
            if not raw.startswith(form):
                continue
            for tail in _solutions(raw[len(form) :], start + 1):
                yield [name] + tail


def build(word, chain, compound=False):
    """[chain] morfemlerini [word] uzerinde uretir.

    [compound] belirtisiz isim tamlamasi demektir ("kurtarma zarı"): govde
    ZATEN 3. tekil iyelik tasir, bu yuzden hal ekleri araya `n` alir ve cogul
    iyeligi soker ("kurtarma zarları").
    """
    poss = compound
    if compound and 'PLURAL' in chain:
        word = _strip_poss3(word)
        poss = False
    for name in chain:
        # Govde zaten iyelik tasiyorsa ("kurtarma zarı") zincirdeki iyelik
        # tekrari sozcugu bozar: "kurtarma zarısı".
        if name == 'POSS3' and poss:
            continue
        piece = _BY_NAME[name](word, poss)
        if name in _VOWEL_INITIAL and piece and piece[0] in VOWELS:
            word = soften(word)
            piece = _BY_NAME[name](word, poss)
        word += piece
        if name == 'PLURAL' and compound:
            # "kurtarma zar" + "lar" -> iyelik geri gelir: "kurtarma zarları"
            word += _BY_NAME['POSS3'](word, False)
            poss = True
        elif name in ('POSS3', 'POSS1P', 'POSS2P', 'POSS2'):
            poss = True
        elif name in ('ACC', 'DAT', 'LOC', 'ABL', 'GEN', 'INS'):
            poss = False
    return word


def _strip_poss3(word):
    """Tamlamanin sonundaki 3. tekil iyelik ekini soker."""
    if len(word) > 1 and word[-1] in 'ıiuü':
        return word[:-2] if word[-2] == 's' else word[:-1]
    return word


#: Kesme isaretinden sonraki Turkce ek. Genis yakalanir, [attach] dogrular.
SUFFIX_PATTERN = "['’]([a-zçğıöşü]+)\\b"


def attach(word, raw_suffix, compound=False):
    """[word]'e, kaynaktaki [raw_suffix] ekinin Turkce karsiligini ekler.

    Ek zinciri cozumlenemezse sozcuk kesme isaretiyle oldugu gibi birakilir --
    bozuk bir ek uretmektense Ingilizce yazim korunur.
    """
    chain = parse(raw_suffix.lower())
    if chain is None:
        unresolved.add(raw_suffix.lower())
        return f"{word}'{raw_suffix}"
    return build(word, chain, compound=compound)
