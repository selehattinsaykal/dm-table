# -*- coding: utf-8 -*-
"""assets/data/tr/creatures_tr.json icin ejderha stat bloklarini uretir.

Depo kokunden calistir:  python tools/tr/build_creatures_tr.py
Eslesmeyen bir metin kalirsa hata verir; boylece yeni bir kalip sessizce
Ingilizce kalmaz.

2024 stat bloklari kaliplidir; bu yuzden ceviri aile sablonlariyla yapiliyor:
sayilar Ingilizce metinden cikarilir, cumle kalibi Turkce yazilir. Boylece
40 ejderhanin 180 benzersiz metni tutarli cikiyor.

Terim kurali (bkz. lib/data/content_tr.dart): oyun terimleri Ingilizce kalir.
"""
import gzip
import json
import re
import sys

AGES = ('Adult ', 'Ancient ', 'Young ')


def is_dragon(m):
    n = m['name']
    return m.get('document') == 'srd-2024' and (
        n.endswith('Dragon Wyrmling') or (n.startswith(AGES) and n.endswith('Dragon'))
    )


NUM_TR = {'one': 'bir', 'two': 'iki', 'three': 'üç', 'four': 'dört'}

# --- yardimcilar ---------------------------------------------------------


def dmg(n, dice, kind):
    return f'{n} ({dice}) {kind} hasarı'


def cast(spell):
    """"Spellcasting to cast X (level N version)" -> Turkce."""
    m = re.fullmatch(r'(.+?) \(level (\d+) version\)', spell)
    if m:
        return f"{m.group(1)} (seviye {m.group(2)} sürümü)"
    return spell


def area(text):
    """Etki alani ifadesini cevirir."""
    m = re.fullmatch(r'a (\d+)-foot-long, (\d+)-foot-wide Line', text)
    if m:
        return f'{m.group(1)}-foot uzunluğunda, {m.group(2)}-foot genişliğinde bir Line'
    m = re.fullmatch(r'a (\d+)-foot Cone', text)
    if m:
        return f'{m.group(1)}-foot Cone'
    m = re.fullmatch(
        r'a (\d+)-foot-radius Sphere centered on a point the dragon can see '
        r'within (\d+) feet',
        text,
    )
    if m:
        return (
            f"dragon'ın {m.group(2)} feet içinde görebildiği bir noktada merkezlenen "
            f'{m.group(1)}-foot yarıçaplı Sphere'
        )
    return None


# --- aile sablonlari -----------------------------------------------------
# Her biri (regex, islev). Islev eslesmeden Turkce metni uretir.

RULES = []


def rule(pattern):
    def deco(fn):
        RULES.append((re.compile(pattern, re.DOTALL), fn))
        return fn

    return deco


@rule(r'^The dragon can breathe air and water\.$')
def _amphibious(m):
    return 'Dragon hem havada hem suda nefes alabilir.'


@rule(r'^If the dragon fails a saving throw, it can choose to succeed instead\.$')
def _legendary_resistance(m):
    return "Dragon bir saving throw'da başarısız olursa, bunun yerine başarılı olmayı seçebilir."


@rule(
    r'^The dragon can move across and climb icy surfaces without needing to make '
    r"an ability check\. Additionally, Difficult Terrain composed of ice or snow "
    r"doesn't cost it extra movement\.$"
)
def _ice_walk(m):
    return (
        'Dragon buzlu yüzeylerde yetenek kontrolü yapmaya gerek kalmadan hareket '
        'edebilir ve tırmanabilir. Ayrıca buz ya da kardan oluşan Difficult Terrain '
        'ona fazladan hareket harcatmaz.'
    )


@rule(r'^The dragon (can move|moves) up to half its Speed, and it makes one Rend attack\.$')
def _pounce(m):
    verb = 'hareket edebilir' if m.group(1) == 'can move' else 'hareket eder'
    return f"Dragon Speed'inin yarısına kadar {verb} ve bir Rend saldırısı yapar."


@rule(r'^The dragon makes (one|two|three) Rend attacks?\.$')
def _multiattack(m):
    return f'Dragon {NUM_TR[m.group(1)]} Rend saldırısı yapar.'


@rule(
    r'^The dragon makes (two|three) Rend attacks\. It can replace (one|two) attacks? '
    r'with a use of ([^.]+)\.$'
)
def _multiattack_replace(m):
    return (
        f'Dragon {NUM_TR[m.group(1)]} Rend saldırısı yapar. Saldırılardan '
        f'{NUM_TR[m.group(2)]}ini {_option(m.group(3))} kullanımıyla değiştirebilir.'
    )


def _option(text):
    """Multiattack icindeki "(A) X or (B) Y" / "Spellcasting to cast Z" secenegi."""
    m = re.fullmatch(r'\(A\) (.+?) or \(B\) (.+)', text)
    if m:
        return f'(A) {_option(m.group(1))} ya da (B) {_option(m.group(2))}'
    m = re.fullmatch(r'Spellcasting to cast (.+)', text)
    if m:
        return f'{cast(m.group(1))} büyüsü için Spellcasting'
    return text


@rule(r'^The dragon uses Spellcasting to cast ([^.]+)\.$')
def _uses_spellcasting(m):
    return f'Dragon, {cast(m.group(1))} büyüsünü çıkarmak için Spellcasting kullanır.'


@rule(
    r'^The dragon uses Spellcasting to cast ([^.]+)\. The dragon can\'t take this '
    r'action again until the start of its next turn\.$'
)
def _uses_spellcasting_once(m):
    return (
        f'Dragon, {cast(m.group(1))} büyüsünü çıkarmak için Spellcasting kullanır. '
        f'Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^The dragon uses Spellcasting to cast Invisibility on itself, and it can fly '
    r"up to half its Fly Speed\. The dragon can't take this action again until the "
    r'start of its next turn\.$'
)
def _cloaked_flight(m):
    return (
        'Dragon, kendi üzerine Invisibility büyüsünü çıkarmak için Spellcasting '
        "kullanır ve Fly Speed'inin yarısına kadar uçabilir. Dragon bu eylemi "
        'sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^The dragon casts Fear, requiring no Material components and using Charisma '
    r"as the spellcasting ability \(spell save DC (\d+)\)\. The dragon can't take "
    r'this action again until the start of its next turn\.$'
)
def _frightful_presence_direct(m):
    return (
        'Dragon, Material bileşen gerektirmeden ve büyü yeteneği olarak Charisma '
        f'kullanarak Fear büyüsünü çıkarır (spell save DC {m.group(1)}). Dragon bu '
        'eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^The dragon casts one of the following spells, requiring no Material components '
    r'and using Charisma as the spellcasting ability \(spell save DC (\d+)'
    r'(, \+(\d+) to hit with spell attacks)?\):\n(\n?)(.+)$'
)
def _spellcasting_block(m):
    dc, plus, blank, lists = m.group(1), m.group(3), m.group(4), m.group(5)
    head = f'spell save DC {dc}'
    if plus:
        head += f', büyü saldırılarında +{plus}'
    # "At Will" / "1/Day Each" stat blok terimi; buyu adlari gibi Ingilizce kalir.
    return (
        'Dragon aşağıdaki büyülerden birini çıkarır; Material bileşen gerekmez ve '
        f'büyü yeteneği olarak Charisma kullanılır ({head}):\n{blank}{lists}'
    )


@rule(
    r'^Melee Attack Roll: \+(\d+)(?: to hit)?, reach (\d+) ft\. (\d+) \(([^)]+)\) '
    r'(\w+) damage(?: plus (\d+) \(([^)]+)\) (\w+) damage)?\.$'
)
def _rend(m):
    out = (
        f'Melee Attack Roll: +{m.group(1)}, erişim {m.group(2)} ft. '
        f'{dmg(m.group(3), m.group(4), m.group(5))}'
    )
    if m.group(6):
        out += f' artı {dmg(m.group(6), m.group(7), m.group(8))}'
    return out + '.'


@rule(
    r'^(\w+) Saving Throw: DC (\d+), each creature in (a[n]? .+?)\. '
    r'Failure: (\d+) \(([^)]+)\) (\w+) damage\. Success: Half damage\.$'
)
def _breath_damage(m):
    zone = area(re.sub(r'^an ', 'a ', m.group(3)))
    if zone is None:
        return None
    return (
        f'{m.group(1)} Saving Throw: DC {m.group(2)}, {zone} içindeki her yaratık. '
        f'Başarısız: {dmg(m.group(4), m.group(5), m.group(6))}. Başarılı: Yarı hasar.'
    )


@rule(
    r'^Constitution Saving Throw: DC (\d+), each creature in a (\d+)-foot Cone\. '
    r'Failure: The target has the Incapacitated condition until the end of its next '
    r'turn, at which point it repeats the save\. Second Failure The target has the '
    r'Unconscious condition for (\d+ (?:minute|minutes)?)\. This effect ends for the '
    r'target if it takes damage or a creature within 5 feet of it takes an action to '
    r'wake it\.$'
)
def _sleep_breath(m):
    dur = {'1 minute': '1 dakika', '10 minutes': '10 dakika'}[m.group(3)]
    return (
        f'Constitution Saving Throw: DC {m.group(1)}, {m.group(2)}-foot Cone içindeki '
        'her yaratık. Başarısız: Hedef sıradaki turunun sonuna kadar Incapacitated '
        'durumuna girer; o anda saving throw\'u tekrarlar. İkinci Başarısızlık: Hedef '
        f'{dur} boyunca Unconscious durumuna girer. Hedef hasar alırsa ya da 5 feet '
        'yakınındaki bir yaratık onu uyandırmak için bir eylem harcarsa bu etki sona erer.'
    )


@rule(
    r'^Constitution Saving Throw: DC (\d+), each creature in a (\d+)-foot Cone\. '
    r'First Failure The target has the Incapacitated condition until the end of its '
    r'next turn, when it repeats the save\. Second Failure The target has the '
    r'Paralyzed condition, and it repeats the save at the end of each of its turns, '
    r'ending the effect on itself on a success\. After 1 minute, it succeeds '
    r'automatically\.$'
)
def _paralyzing_breath(m):
    return (
        f'Constitution Saving Throw: DC {m.group(1)}, {m.group(2)}-foot Cone içindeki '
        'her yaratık. İlk Başarısızlık: Hedef sıradaki turunun sonuna kadar '
        "Incapacitated durumuna girer; o anda saving throw'u tekrarlar. İkinci "
        'Başarısızlık: Hedef Paralyzed durumuna girer ve her turunun sonunda '
        "saving throw'u tekrarlar; başarırsa etki kendi üzerinden kalkar. 1 dakika "
        'sonra otomatik olarak başarılı olur.'
    )


@rule(
    r'^Constitution Saving Throw: DC (\d+), each creature in a (\d+)-foot Cone\. '
    r"Failure: The target can't take Reactions; its Speed is halved; and it can take "
    r'either an action or a Bonus Action on its turn, not both\. This effect lasts '
    r'until the end of its next turn\.$'
)
def _slowing_breath(m):
    return (
        f'Constitution Saving Throw: DC {m.group(1)}, {m.group(2)}-foot Cone içindeki '
        'her yaratık. Başarısız: Hedef Reaction kullanamaz; Speed\'i yarıya iner; ve '
        'turunda bir eylem ya da bir Bonus Action kullanabilir, ikisini birden değil. '
        'Bu etki sıradaki turunun sonuna kadar sürer.'
    )


@rule(
    r'^Strength Saving Throw: DC (\d+), each creature in a (\d+)-foot Cone\. '
    r'Failure: The target is pushed up to (\d+) feet straight away from the dragon '
    r'and has the Prone condition\.$'
)
def _repulsion_breath(m):
    return (
        f'Strength Saving Throw: DC {m.group(1)}, {m.group(2)}-foot Cone içindeki her '
        f"yaratık. Başarısız: Hedef dragon'dan dosdoğru uzağa {m.group(3)} feet kadar "
        'itilir ve Prone durumuna girer.'
    )


@rule(
    r"^Strength Saving Throw: DC (\d+), each creature that isn't currently affected "
    r'by this breath in a (\d+)-foot Cone\. Failure: The target has Disadvantage on '
    r'Strength-based D20 Test and subtracts (\d+) \(([^)]+)\) from its damage rolls\. '
    r'It repeats the save at the end of each of its turns, ending the effect on itself '
    r'on a success\. After 1 minute, it succeeds automatically\.$'
)
def _weakening_breath(m):
    return (
        f'Strength Saving Throw: DC {m.group(1)}, {m.group(2)}-foot Cone içindeki, şu an '
        'bu nefesten etkilenmeyen her yaratık. Başarısız: Hedef Strength temelli D20 '
        f"Test'lerde Disadvantage'lı olur ve hasar zarlarından {m.group(3)} "
        f"({m.group(4)}) çıkarır. Her turunun sonunda saving throw'u tekrarlar; "
        'başarırsa etki kendi üzerinden kalkar. 1 dakika sonra otomatik olarak '
        'başarılı olur.'
    )


@rule(
    r'^Dexterity Saving Throw: DC (\d+), one creature the dragon can see within '
    r'(\d+) feet\. Failure: (\d+) \(([^)]+)\) Poison damage, and the target has '
    r'Disadvantage on saving throws to maintain Concentration until the end of its '
    r"next turn\. Failure or Success: The dragon can't take this action again until "
    r'the start of its next turn\.$'
)
def _cloud_of_insects(m):
    return (
        f"Dexterity Saving Throw: DC {m.group(1)}, dragon'ın {m.group(2)} feet içinde "
        f'görebildiği bir yaratık. Başarısız: {dmg(m.group(3), m.group(4), "Poison")} '
        "ve hedef, sıradaki turunun sonuna kadar Concentration'ı sürdürmek için "
        "yaptığı saving throw'larda Disadvantage'lı olur. Başarısız ya da Başarılı: "
        'Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^Dexterity Saving Throw: DC (\d+), one creature the dragon can see within '
    r"(\d+) feet\. Failure: (\d+) \(([^)]+)\) Fire damage, and the target's Speed is "
    r'halved until the end of its next turn\. Failure or Success: The dragon can\'t '
    r'take this action again until the start of its next turn\.$'
)
def _scorching_sands(m):
    return (
        f"Dexterity Saving Throw: DC {m.group(1)}, dragon'ın {m.group(2)} feet içinde "
        f'görebildiği bir yaratık. Başarısız: {dmg(m.group(3), m.group(4), "Fire")} ve '
        "hedefin Speed'i sıradaki turunun sonuna kadar yarıya iner. Başarısız ya da "
        'Başarılı: Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^Constitution Saving Throw: DC (\d+), each creature in a (\d+)-foot-radius '
    r'Sphere centered on a point the dragon can see within (\d+) feet\. Failure: '
    r'(\d+) \(([^)]+)\) Thunder damage, and the target has the Deafened condition '
    r'until the end of its next turn\.$'
)
def _thunderclap(m):
    return (
        f"Constitution Saving Throw: DC {m.group(1)}, dragon'ın {m.group(3)} feet içinde "
        f'görebildiği bir noktada merkezlenen {m.group(2)}-foot yarıçaplı Sphere '
        f'içindeki her yaratık. Başarısız: {dmg(m.group(4), m.group(5), "Thunder")} ve '
        'hedef sıradaki turunun sonuna kadar Deafened durumuna girer.'
    )


@rule(
    r'^Constitution Saving Throw: DC (\d+), each creature in a (\d+)-foot-radius '
    r'Sphere centered on a point the dragon can see within (\d+) feet\. Failure: '
    r'(\d+) \(([^)]+)\) Poison damage, and the target takes a -2 penalty to AC until '
    r"the end of its next turn\. Failure or Success: The dragon can't take this "
    r'action again until the start of its next turn\.$'
)
def _noxious_miasma(m):
    return (
        f"Constitution Saving Throw: DC {m.group(1)}, dragon'ın {m.group(3)} feet içinde "
        f'görebildiği bir noktada merkezlenen {m.group(2)}-foot yarıçaplı Sphere '
        f'içindeki her yaratık. Başarısız: {dmg(m.group(4), m.group(5), "Poison")} ve '
        "hedef sıradaki turunun sonuna kadar AC'sine -2 ceza alır. Başarısız ya da "
        'Başarılı: Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^Constitution Saving Throw: DC (\d+), each creature in a (\d+)-foot-radius '
    r'Sphere centered on a point the dragon can see within (\d+) feet\. Failure: '
    r"(\d+) \(([^)]+)\) Cold damage, and the target's Speed is 0 until the end of the "
    r"target's next turn\. Failure or Success: The dragon can't take this action "
    r'again until the start of its next turn\.$'
)
def _freezing_burst(m):
    return (
        f"Constitution Saving Throw: DC {m.group(1)}, dragon'ın {m.group(3)} feet içinde "
        f'görebildiği bir noktada merkezlenen {m.group(2)}-foot yarıçaplı Sphere '
        f'içindeki her yaratık. Başarısız: {dmg(m.group(4), m.group(5), "Cold")} ve '
        "hedefin Speed'i sıradaki turunun sonuna kadar 0 olur. Başarısız ya da "
        'Başarılı: Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^Dexterity Saving Throw: DC (\d+), each creature in a (\d+)-foot-long, '
    r'(\d+)-foot-wide Line\. Failure: (\d+) \(([^)]+)\) Cold damage, and the target is '
    r'pushed up to (\d+) feet straight away from the dragon\. Success: Half damage '
    r"only\. Failure or Success: The dragon can't take this action again until the "
    r'start of its next turn\.$'
)
def _cold_gale(m):
    return (
        f'Dexterity Saving Throw: DC {m.group(1)}, {m.group(2)}-foot uzunluğunda, '
        f'{m.group(3)}-foot genişliğinde bir Line içindeki her yaratık. Başarısız: '
        f'{dmg(m.group(4), m.group(5), "Cold")} ve hedef dragon\'dan dosdoğru uzağa '
        f'{m.group(6)} feet kadar itilir. Başarılı: Yalnızca yarı hasar. Başarısız ya '
        'da Başarılı: Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


@rule(
    r'^Charisma Saving Throw: DC (\d+), one creature the dragon can see within (\d+) '
    r'feet\. Failure: (\d+) \(([^)]+)\) Psychic damage\. Until the end of its next '
    r'turn, the target rolls (1d\d+) whenever it makes an ability check or attack roll '
    r"and subtracts the number rolled from the D20 Test\. Failure or Success: The "
    r"dragon can't take this action again until the start of its next turn\.$"
)
def _giggling_magic(m):
    return (
        f"Charisma Saving Throw: DC {m.group(1)}, dragon'ın {m.group(2)} feet içinde "
        f'görebildiği bir yaratık. Başarısız: {dmg(m.group(3), m.group(4), "Psychic")}. '
        f'Sıradaki turunun sonuna kadar hedef, yaptığı her yetenek kontrolünde ya da '
        f"saldırı zarında {m.group(5)} atar ve çıkan sayıyı D20 Test'inden çıkarır. "
        'Başarısız ya da Başarılı: Dragon bu eylemi sıradaki turunun başına kadar '
        'tekrar kullanamaz.'
    )


@rule(
    r'^Charisma Saving Throw: DC (\d+), one creature the dragon can see within (\d+) '
    r'feet\. Failure: (\d+) \(([^)]+)\) Force damage, and the target has the '
    r'Incapacitated condition and is transported to a harmless demiplane until the '
    r'start of the dragon\'s next turn, at which point it reappears in an unoccupied '
    r'space of the dragon\'s choice within (\d+) feet of the dragon\. Failure or '
    r"Success: The dragon can't take this action again until the start of its next "
    r'turn\.$'
)
def _banish(m):
    return (
        f"Charisma Saving Throw: DC {m.group(1)}, dragon'ın {m.group(2)} feet içinde "
        f'görebildiği bir yaratık. Başarısız: {dmg(m.group(3), m.group(4), "Force")} ve '
        "hedef Incapacitated durumuna girip dragon'ın sıradaki turunun başına kadar "
        'zararsız bir yarı-düzleme taşınır; o anda dragon\'ın seçtiği, dragon\'ın '
        f'{m.group(5)} feet içindeki boş bir alanda yeniden belirir. Başarısız ya da '
        'Başarılı: Dragon bu eylemi sıradaki turunun başına kadar tekrar kullanamaz.'
    )


def translate(desc):
    for pat, fn in RULES:
        m = pat.fullmatch(desc)
        if m:
            out = fn(m)
            if out is not None:
                return out
    return None


# =========================================================================
# Genel kurallar: turden bagimsiz, butun canavarlarda gecen kalip metinler.
#
# Ozne, metindeki "the <ad>" ifadesinden okunur ve Turkce'ye YALIN halde
# ("Devil", "Shambling Mound") gecer. Turkce'de ek gerektiren yerlerde
# ("...in turu") ozne yerine "bu yaratik" kullaniliyor: Ingilizce adlara
# unlu uyumuyla ek getirmek guvenilir degil.
# =========================================================================

GENERIC = []
SUBJ = r'([a-z][a-z]*(?: [a-z]+)*)'


def grule(pattern):
    def deco(fn):
        GENERIC.append((re.compile(pattern, re.DOTALL), fn))
        return fn

    return deco


def subj(word):
    return ' '.join(w.capitalize() for w in word.split())


def attack_tail(kind, extra_n=None, extra_dice=None, extra_kind=None):
    out = f'{kind} hasarı'
    if extra_n:
        out += f' artı {extra_n} ({extra_dice}) {extra_kind} hasarı'
    return out


@grule(
    r'^(Melee|Ranged|Melee or Ranged) Attack Roll: \+(\d+)(?: to hit)?, '
    r'(reach \d+ ft\.|range \d+/\d+ ft\.|range \d+ ft\.|'
    r'reach \d+ ft\. or range \d+/\d+ ft\.|reach \d+ ft\. or range \d+ ft\.) '
    r'(?:Hit: )?(\d+)(?: \((\d+d\d+(?: [+-] \d+)?)\))? (\w+) damage'
    r'(?: plus (\d+) \((\d+d\d+(?: [+-] \d+)?)\) (\w+) damage)?\.'
    r'(?: If the target is an? (Huge|Large|Medium|Small) or smaller creature, it has '
    r'the Prone condition\.)?$'
)
def _g_attack(m):
    reach = m.group(3)
    reach = reach.replace('reach', 'erişim').replace('range', 'menzil')
    reach = reach.replace(' or ', ' ya da ')
    dice = f' ({m.group(5)})' if m.group(5) else ''
    out = (
        f'{m.group(1)} Attack Roll: +{m.group(2)}, {reach} {m.group(4)}{dice} '
        f'{m.group(6)} hasarı'
    )
    if m.group(7):
        out += f' artı {m.group(7)} ({m.group(8)}) {m.group(9)} hasarı'
    out += '.'
    if m.group(10):
        out += (
            f' Hedef {m.group(10)} ya da daha küçük bir yaratıksa Prone durumuna girer.'
        )
    return out


@grule(
    r'^(\w+) Saving Throw: DC (\d+), each creature in a (\d+)-foot (Cone|Line|Emanation)'
    r'(?: originating from the ' + SUBJ + r')?\. Failure: (\d+) \((\d+d\d+)\) (\w+) '
    r'damage\. Success: Half damage\.$'
)
def _g_save_area(m):
    where = f'{m.group(3)}-foot {m.group(4)}'
    if m.group(5):
        where = f'bu yaratıktan çıkan {where}'
    return (
        f'{m.group(1)} Saving Throw: DC {m.group(2)}, {where} içindeki her yaratık. '
        f'Başarısız: {m.group(6)} ({m.group(7)}) {m.group(8)} hasarı. '
        f'Başarılı: Yarı hasar.'
    )


@grule(r'^The ' + SUBJ + r' makes (one|two|three|four) ([A-Z][\w -]*?) attacks?\.$')
def _g_multiattack(m):
    return f'{subj(m.group(1))} {NUM_TR[m.group(2)]} {m.group(3)} saldırısı yapar.'


@grule(
    r'^The ' + SUBJ + r' has Advantage on saving throws against spells and other '
    r'magical effects\.$'
)
def _g_magic_resistance(m):
    return (
        f'{subj(m.group(1))}, büyülere ve diğer büyülü etkilere karşı yaptığı saving '
        "throw'larda Advantage'lı olur."
    )


@grule(r'^If the ' + SUBJ + r' fails a saving throw, it can choose to succeed instead\.$')
def _g_legendary_resistance(m):
    return (
        f"{subj(m.group(1))} bir saving throw'da başarısız olursa, bunun yerine "
        'başarılı olmayı seçebilir.'
    )


@grule(r'^The ' + SUBJ + r' can breathe air and water\.$')
def _g_amphibious(m):
    return f'{subj(m.group(1))} hem havada hem suda nefes alabilir.'


@grule(r'^The ' + SUBJ + r' can breathe only underwater\.$')
def _g_water_breathing(m):
    return f'{subj(m.group(1))} yalnızca su altında nefes alabilir.'


@grule(
    r'^The ' + SUBJ + r' has Advantage on an attack roll against a creature if at '
    r"least one of the " + SUBJ + r"'s allies is within (\d+) feet of the creature and "
    r"the " + SUBJ + r" doesn't have the Incapacitated condition\.$"
)
def _g_pack_tactics(m):
    return (
        f'{subj(m.group(1))}, bir yaratığa karşı yaptığı saldırı zarında, '
        f'müttefiklerinden en az biri o yaratığa {m.group(3)} feet içindeyse ve kendisi '
        "Incapacitated durumunda değilse Advantage'lı olur."
    )


@grule(
    r'^The ' + SUBJ + r' can climb difficult surfaces, including along ceilings, '
    r'without needing to make an ability check\.$'
)
def _g_spider_climb(m):
    return (
        f'{subj(m.group(1))}, tavanlar dâhil zor yüzeylerde yetenek kontrolü yapmaya '
        'gerek kalmadan tırmanabilir.'
    )


@grule(
    r'^While in sunlight, the ' + SUBJ + r' has Disadvantage on ability checks and '
    r'attack rolls\.$'
)
def _g_sunlight_sensitivity(m):
    return (
        f'Güneş ışığındayken {subj(m.group(1))}, yetenek kontrollerinde ve saldırı '
        "zarlarında Disadvantage'lı olur."
    )


@grule(
    r'^The ' + SUBJ + r" doesn't provoke an Opportunity Attack when it flies out of an "
    r"enemy's reach\.$"
)
def _g_flyby(m):
    return (
        f'{subj(m.group(1))} bir düşmanın erişiminden uçarak çıktığında Opportunity '
        'Attack tetiklemez.'
    )


@grule(
    r'^The ' + SUBJ + r' sheds Bright Light in a (\d+)-foot radius and Dim Light for '
    r'an additional (\d+) feet\.$'
)
def _g_illumination(m):
    return (
        f'{subj(m.group(1))}, {m.group(2)} feet yarıçapında Bright Light, ek olarak '
        f'{m.group(3)} feet boyunca da Dim Light yayar.'
    )


@grule(
    r'^The ' + SUBJ + r' can move through a space as narrow as (\d+) inch(?:es)? '
    r'without expending extra movement to do so\.$'
)
def _g_amorphous(m):
    return (
        f'{subj(m.group(1))}, {m.group(2)} inç kadar dar bir boşluktan fazladan hareket '
        'harcamadan geçebilir.'
    )


@grule(
    r'^If the ' + SUBJ + r' dies outside the (Abyss|Nine Hells), its body '
    r'(?:dissolves into ichor|disappears in sulfurous smoke), and it gains a new body '
    r'instantly, reviving with all its Hit Points somewhere in the (?:Abyss|Nine '
    r'Hells)\.$'
)
def _g_fiendish_restoration(m):
    place = m.group(2)
    how = (
        "ichor'a dönüşüp dağılır" if place == 'Abyss' else 'kükürtlü bir dumana karışıp kaybolur'
    )
    return (
        f'{subj(m.group(1))} {place} dışında ölürse bedeni {how} ve anında yeni bir '
        f"beden kazanır; {place} içinde bir yerde tüm Hit Point'leriyle dirilir."
    )


@grule(r'^The ' + SUBJ + r' deals double damage to objects and structures\.$')
def _g_siege_monster(m):
    return f'{subj(m.group(1))}, nesnelere ve yapılara iki kat hasar verir.'


@grule(
    r'^The ' + SUBJ + r' can move through other creatures and objects as if they were '
    r'Difficult Terrain\. It takes (\d+) \((\d+d\d+)\) Force damage if it ends its turn '
    r'inside an object\.$'
)
def _g_incorporeal(m):
    return (
        f"{subj(m.group(1))}, diğer yaratıkların ve nesnelerin içinden Difficult "
        f"Terrain'miş gibi geçebilir. Turunu bir nesnenin içinde bitirirse "
        f'{m.group(2)} ({m.group(3)}) Force hasarı alır.'
    )


@grule(r'^The ' + SUBJ + r' takes the Disengage or Hide action\.$')
def _g_disengage_or_hide(m):
    return f'{subj(m.group(1))}, Disengage ya da Hide eylemini kullanır.'


@grule(r'^The ' + SUBJ + r" can't shape-shift\.$")
def _g_no_shapeshift(m):
    return f'{subj(m.group(1))} biçim değiştiremez.'


@grule(
    r'^The ' + SUBJ + r' jumps up to (\d+) feet by spending (\d+) feet of movement\.$'
)
def _g_standing_leap(m):
    return (
        f'{subj(m.group(1))}, {m.group(3)} feet hareket harcayarak {m.group(2)} feet '
        'kadar zıplar.'
    )


@grule(
    r'^_Trigger:_ The ' + SUBJ + r' is hit by a melee attack roll while holding a '
    r'weapon\. _Response:_ The ' + SUBJ + r' adds (\d+) to its AC against that attack, '
    r'possibly causing it to miss\.$'
)
def _g_parry(m):
    return (
        f'_Tetik:_ {subj(m.group(1))} bir silah tutarken yakın mesafe saldırı zarıyla '
        f"vurulur. _Yanıt:_ O saldırıya karşı AC'sine {m.group(3)} ekler; bu, saldırının "
        'ıskalamasına yol açabilir.'
    )


@grule(
    r'^The ' + SUBJ + r" has Advantage on attack rolls against any creature that "
    r"doesn't have all its Hit Points\.$"
)
def _g_bloodied_advantage(m):
    return (
        f"{subj(m.group(1))}, tüm Hit Point'leri dolu olmayan herhangi bir yaratığa "
        "karşı yaptığı saldırı zarlarında Advantage'lı olur."
    )


@grule(
    r'^The ' + SUBJ + r' regains (\d+) Hit Points at the start of each of its turns if '
    r'it has at least (\d+) Hit Points?\.$'
)
def _g_regeneration(m):
    return (
        f"{subj(m.group(1))}, en az {m.group(3)} Hit Point'i varsa her turunun başında "
        f'{m.group(2)} Hit Point geri kazanır.'
    )


@grule(
    r'^If the ' + SUBJ + r' dies, it disintegrates into dust, leaving behind anything '
    r'it was wearing or carrying\.$'
)
def _g_disintegrates(m):
    return (
        f'{subj(m.group(1))} ölürse toza dönüşür; giydiği ya da taşıdığı her şey geride '
        'kalır.'
    )


@grule(
    r'^The ' + SUBJ + r" needn't spend extra movement to move a creature it is "
    r'grappling\.$'
)
def _g_drag(m):
    return (
        f'{subj(m.group(1))}, Grappled ettiği bir yaratığı sürüklemek için fazladan '
        'hareket harcamak zorunda değildir.'
    )


@grule(r'^The ' + SUBJ + r' can hold its breath for (\d+) (hour|hours|minutes)\.$')
def _g_hold_breath(m):
    unit = 'saat' if m.group(3).startswith('hour') else 'dakika'
    return f'{subj(m.group(1))} nefesini {m.group(2)} {unit} tutabilir.'


@grule(
    r'^Add your Proficiency Bonus to any ability check or saving throw the ' + SUBJ
    + r' makes\.$'
)
def _g_add_pb(m):
    return (
        'Bu yaratığın yaptığı her yetenek kontrolüne ve saving throw\'a Proficiency '
        "Bonus'unu ekle."
    )


def translate_generic(desc):
    for pat, fn in GENERIC:
        m = pat.fullmatch(desc)
        if m:
            out = fn(m)
            if out is not None:
                return out
    return None


def main():
    creatures = json.load(gzip.open('assets/data/creatures.json.gz', 'rt', encoding='utf-8'))
    dragons = [m for m in creatures if is_dragon(m)]

    path = 'assets/data/tr/creatures_tr.json'
    existing = json.load(open(path, encoding='utf-8'))

    misses = []
    added = 0
    for m in dragons:
        entry = existing.setdefault(m['key'], {})
        for section in ('traits', 'actions', 'legendary_actions', 'bonus_actions', 'reactions'):
            for e in (m.get(section) or []):
                if not isinstance(e, dict) or not e.get('desc'):
                    continue
                sec = 'actions' if section != 'traits' else 'traits'
                turkish = translate(e['desc'])
                if turkish is None:
                    misses.append((m['name'], e.get('name'), e['desc']))
                    continue
                entry[f"{sec}/{e.get('name') or ''}"] = turkish
                added += 1
        if not entry:
            del existing[m['key']]

    if misses:
        print(f'{len(misses)} metin eslesmedi:', file=sys.stderr)
        for name, ent, desc in misses[:20]:
            print(f'  {name} / {ent}: {desc[:120]}', file=sys.stderr)
        sys.exit(1)

    # Ikinci gecis: genel kaliplar. Bir canavar ancak BUTUN metinleri
    # kapsaniyorsa yaziliyor -- yarim ceviri, blogun yarisini Ingilizce
    # birakip karisik bir stat blok uretirdi.
    generic_creatures = 0
    for m in creatures:
        if m['key'] in existing:
            continue
        rows = [
            (('actions' if section != 'traits' else 'traits'), e)
            for section in ('traits', 'actions', 'legendary_actions', 'bonus_actions', 'reactions')
            for e in (m.get(section) or [])
            if isinstance(e, dict) and e.get('desc')
        ]
        if not rows:
            continue
        entry = {}
        for sec, e in rows:
            turkish = translate_generic(e['desc'])
            if turkish is None:
                entry = None
                break
            entry[f"{sec}/{e.get('name') or ''}"] = turkish
        if entry:
            existing[m['key']] = entry
            added += len(entry)
            generic_creatures += 1

    # _comment basta kalsin, geri kalani kaynak sirasinda.
    ordered = {'_comment': existing['_comment']}
    for m in creatures:
        if m['key'] in existing and m['key'] != '_comment':
            ordered[m['key']] = existing[m['key']]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(
        f'{len(dragons)} ejderha + {generic_creatures} genel canavar, '
        f'{added} metin yazildi.'
    )


if __name__ == '__main__':
    main()
