# -*- coding: utf-8 -*-
"""assets/data/tr/magicitems_tr.json'a en kalipli esya ailelerini ekler.

Depo kokunden calistir:  python tools/tr/build_magicitems_tr.py
Var olan cevirilerin uzerine yazmaz; yeni aile sablonu eklendikce tekrar
calistirilabilir.

SRD sihirli esyalari silah/zirh turu basina tekrarliyor (Battleaxe (+1),
Blowgun (+1), ... hepsi ayni metin). Bu yuzden ceviri aile sablonlariyla
yapiliyor: sayilar Ingilizce metinden cikarilir, cumle kalibi Turkce yazilir.

Terim kurali (bkz. lib/data/content_tr.dart): oyun terimleri Ingilizce kalir.
"""
import gzip
import json
import re
import sys

RULES = []


def rule(pattern):
    def deco(fn):
        RULES.append((re.compile(pattern, re.DOTALL), fn))
        return fn

    return deco


BONUS_LINE = (
    r'You gain a \+(\d+) bonus to attack rolls and damage rolls made with this '
    r'magic weapon\.'
)


def bonus_tr(n):
    return (
        f'Bu büyülü silahla yaptığın saldırı zarlarına ve hasar zarlarına +{n} '
        f'bonus alırsın.'
    )


@rule(
    r'^You have a bonus to attack rolls and damage rolls made with this magic '
    r"weapon\. The bonus is determined by the weapon's rarity\.$"
)
def _plus_weapon(m):
    return (
        'Bu büyülü silahla yaptığın saldırı zarlarına ve hasar zarlarına bonus '
        'alırsın. Bonusun büyüklüğü silahın nadirliğine göre belirlenir.'
    )


@rule(
    r'^You have a bonus to Armor Class while wearing this armor\. The bonus is '
    r'determined by its rarity\.$'
)
def _plus_armor(m):
    return (
        "Bu zırhı giydiğin sürece Armor Class'ına bonus alırsın. Bonusun "
        'büyüklüğü zırhın nadirliğine göre belirlenir.'
    )


@rule(
    r'^' + BONUS_LINE + r'\n\nThe first time you attack with the weapon on each of '
    r"your turns, you can transfer some or all of the weapon's bonus to your Armor "
    r'Class\. For example, you could reduce the bonus to your attack rolls and damage '
    r'rolls to \+(\d+) and gain a \+(\d+) bonus to Armor Class\. The adjusted bonuses '
    r'remain in effect until the start of your next turn, although you must hold the '
    r'weapon to gain a bonus to AC from it\.$'
)
def _defender(m):
    return (
        f'{bonus_tr(m.group(1))}\n\n'
        'Her turunda silahla ilk kez saldırdığında, silahın bonusunun bir kısmını ya '
        "da tamamını Armor Class'ına aktarabilirsin. Örneğin saldırı ve hasar "
        f"zarlarındaki bonusu +{m.group(2)}'e düşürüp Armor Class'ına +{m.group(3)} "
        'bonus alabilirsin. Ayarlanan bonuslar sıradaki turunun başına kadar geçerli '
        'kalır; ancak silahtan AC bonusu almak için onu elinde tutman gerekir.'
    )


@rule(
    r'^' + BONUS_LINE + r'\n\nWhen you hit a Giant with this weapon, the Giant takes '
    r"an extra (\d+d\d+) damage of the weapon's type and must succeed on a DC (\d+) "
    r'Strength saving throw or have the Prone condition\.$'
)
def _giant_slayer(m):
    return (
        f'{bonus_tr(m.group(1))}\n\n'
        f"Bu silahla bir Giant'a vurduğunda, Giant silahın türünde fazladan "
        f"{m.group(2)} hasar alır ve DC {m.group(3)} Strength saving throw'da "
        'başarılı olmalıdır; başaramazsa Prone durumuna girer.'
    )


@rule(
    r'^' + BONUS_LINE + r' When you hit a Fiend or an Undead with it, that creature '
    r'takes an extra (\d+d\d+) Radiant damage\.\n\nWhile you hold the drawn weapon, '
    r'it creates a (\d+)-foot Emanation originating from you\. You and all creatures '
    r'Friendly to you in the Emanation have Advantage on saving throws against spells '
    r'and other magical effects\. If you have (\d+) or more levels in the Paladin '
    r'class, the size of the Emanation increases to (\d+) feet\.$'
)
def _holy_avenger(m):
    return (
        f'{bonus_tr(m.group(1))} Onunla bir Fiend ya da Undead\'e vurduğunda, o '
        f'yaratık fazladan {m.group(2)} Radiant hasarı alır.\n\n'
        f'Silahı çekili tuttuğun sürece senden çıkan {m.group(3)}-foot bir Emanation '
        'oluşturur. Emanation içindeki sen ve sana Friendly olan tüm yaratıklar, '
        "büyülere ve diğer büyülü etkilere karşı yaptığınız saving throw'larda "
        f"Advantage'lı olursunuz. Paladin sınıfında {m.group(4)} ya da daha fazla "
        f"seviyen varsa Emanation'ın boyu {m.group(5)} feet'e çıkar."
    )


@rule(
    r'^' + BONUS_LINE + r'\n\n\*\*Life Stealing\.\*\* The weapon has (\d+d\d+ \+ \d+) '
    r'charges\. When you attack a creature that has fewer than (\d+) Hit Points with '
    r'this weapon and roll a 20 on the d20 for the attack roll, the creature must '
    r'succeed on a DC (\d+) Constitution saving throw or be slain instantly as the '
    r'sword tears its life force from its body\. Constructs and Undead succeed on the '
    r'save automatically\. The weapon loses 1 charge if the creature is slain\. When '
    r'the weapon has no charges remaining, it loses this property\.$'
)
def _nine_lives(m):
    return (
        f'{bonus_tr(m.group(1))}\n\n'
        f'**Life Stealing.** Silahın {m.group(2)} charge\'ı vardır. Bu silahla '
        f"{m.group(3)} Hit Point'ten azı olan bir yaratığa saldırıp saldırı zarında "
        f"d20'de 20 atarsan, yaratık DC {m.group(4)} Constitution saving throw'da "
        'başarılı olmalıdır; başaramazsa kılıç yaşam gücünü bedeninden söküp alırken '
        'anında ölür. Construct ve Undead yaratıklar bu saving throw\'da otomatik '
        'olarak başarılı olur. Yaratık ölürse silah 1 charge kaybeder. Silahın hiç '
        "charge'ı kalmadığında bu özelliğini yitirir."
    )


@rule(
    r'^This magic weapon deals an extra (\d+d\d+) damage to any creature it hits\. '
    r"This extra damage is of the same type as the weapon's normal damage\.$"
)
def _vicious(m):
    return (
        f'Bu büyülü silah vurduğu her yaratığa fazladan {m.group(1)} hasar verir. Bu '
        'fazladan hasar, silahın normal hasarıyla aynı türdendir.'
    )


@rule(
    r'^As long as this weapon is within your reach and you are attuned to it, you and '
    r'allies within (\d+) feet of you gain the following benefits\.\n\n'
    r'\*\*Alarm\.\*\* The weapon magically awakens each subject who is sleeping '
    r"naturally when combat begins\. This benefit doesn't wake a subject from "
    r'magically induced sleep\.\n\n'
    r'\*\*Supernatural Readiness\.\*\* Each subject has Advantage on its Initiative '
    r'rolls\.$'
)
def _weapon_of_warning(m):
    return (
        'Bu silah erişimindeyken ve ona attuned olduğun sürece sen ve sana '
        f'{m.group(1)} feet içindeki müttefiklerin şu faydaları kazanır.\n\n'
        '**Alarm.** Savaş başladığında silah, doğal uykuda olan her kişiyi büyülü '
        'biçimde uyandırır. Bu fayda, büyüyle uyutulmuş birini uyandırmaz.\n\n'
        "**Supernatural Readiness.** Herkes Initiative zarlarında Advantage'lı olur."
    )


@rule(
    r'^While holding this magic weapon, you can take a Bonus Action and use a command '
    r'word to cause flames to engulf the damage-dealing part of the weapon\. These '
    r'flames shed Bright Light in a (\d+) foot radius and Dim Light for an additional '
    r'(\d+) feet\. While the weapon is ablaze, it deals an extra (\d+d\d+) Fire damage '
    r'on a hit\. The flames last until you take a Bonus Action to issue the command '
    r'again or until you drop, stow, or sheathe the weapon\.$'
)
def _flame_tongue(m):
    return (
        'Bu büyülü silahı elinde tutarken bir Bonus Action harcayıp bir komut sözcüğü '
        'kullanarak silahın hasar veren kısmını alevlerle sarabilirsin. Bu alevler '
        f'{m.group(1)} feet yarıçapında Bright Light, ek olarak {m.group(2)} feet '
        'boyunca da Dim Light yayar. Silah alevliyken vuruşta fazladan '
        f'{m.group(3)} Fire hasarı verir. Alevler, komutu yinelemek için bir Bonus '
        'Action harcayana ya da silahı düşürene, kaldırana veya kınına sokana kadar '
        'sürer.'
    )


@rule(
    r'^This magic ammunition is meant to slay creatures of a particular type, which '
    r'the GM chooses or determines randomly by rolling on the table below\. If a '
    r'creature of that type takes damage from the ammunition, the creature makes a DC '
    r'(\d+) Constitution saving throw, taking an extra (\d+d\d+) Force damage on a '
    r'failed save or half as much extra damage on a successful one\.\n\nAfter dealing '
    r'its extra damage to a creature, the ammunition becomes nonmagical\.\n\n'
    r'(\| 1d100 \| Creature Type \|\n.+)$'
)
def _slaying_ammunition(m):
    table = m.group(3).replace('| Creature Type |', '| Yaratık Türü |', 1)
    return (
        'Bu büyülü mühimmat belirli bir türden yaratıkları öldürmek için yapılmıştır; '
        'türü GM seçer ya da aşağıdaki tabloda zar atarak rastgele belirler. O türden '
        f'bir yaratık mühimmattan hasar alırsa DC {m.group(1)} Constitution saving '
        f'throw yapar; başarısız olursa fazladan {m.group(2)} Force hasarı, başarılı '
        'olursa bunun yarısı kadar fazladan hasar alır.\n\n'
        'Bir yaratığa fazladan hasarını verdikten sonra mühimmat büyüsünü yitirir.'
        f'\n\n{table}'
    )


# --- ikinci parti: zirh / silah / degnek aileleri --------------------------


@rule(
    r'^You have Resistance to one type of damage while you wear this armor\. The GM '
    r'chooses the type or determines it randomly by rolling on the following table\.'
    r'\n\n(\| 1d10 \| Damage Type \|\n.+)$'
)
def _armor_of_resistance(m):
    return (
        'Bu zırhı giydiğin sürece bir hasar türüne karşı Resistance kazanırsın. Türü '
        'GM seçer ya da aşağıdaki tabloda zar atarak rastgele belirler.\n\n'
        + m.group(1).replace('| Damage Type |', '| Hasar Türü |', 1)
    )


@rule(
    r'^While wearing this armor, you gain a \+(\d+) bonus to Armor Class, and you know '
    r"Abyssal\. In addition, the armor's clawed gauntlets allow your Unarmed Strikes to "
    r'deal (\d+d\d+) Slashing damage instead of the usual Bludgeoning damage, and you '
    r'gain a \+(\d+) bonus to the attack and damage rolls of your Unarmed Strikes\.'
    r"\n\n\*\*Curse\.\*\* Once you don this cursed armor, you can't doff it unless you "
    r'are targeted by a Remove Curse spell or similar magic\. While wearing the armor, '
    r'you have Disadvantage on attack rolls against demons and on saving throws against '
    r'their spells and special abilities\.$'
)
def _demon_armor(m):
    return (
        f"Bu zırhı giydiğin sürece Armor Class'ına +{m.group(1)} bonus alırsın ve "
        'Abyssal dilini bilirsin. Ayrıca zırhın pençeli eldivenleri sayesinde Unarmed '
        f'Strike\'ların normal Bludgeoning yerine {m.group(2)} Slashing hasarı verir ve '
        f"Unarmed Strike'larının saldırı ve hasar zarlarına +{m.group(3)} bonus "
        'alırsın.\n\n'
        '**Curse.** Bu lanetli zırhı bir kez giydiğinde, Remove Curse büyüsü ya da '
        'benzeri bir sihir seni hedef almadıkça çıkaramazsın. Zırhı giydiğin sürece '
        "demon'lara karşı yaptığın saldırı zarlarında ve onların büyülerine ve özel "
        "yeteneklerine karşı yaptığın saving throw'larda Disadvantage'lı olursun."
    )


@rule(
    r'^While wearing this armor, you have Resistance to one of the following damage '
    r'types: Bludgeoning, Piercing, or Slashing\. The GM chooses the type or determines '
    r'it randomly\. Curse\. This armor is cursed, a fact that is revealed only when the '
    r'Identify spell is cast on the armor or you attune to it\. Attuning to the armor '
    r'curses you until you are targeted by a Remove Curse spell or similar magic; '
    r'removing the armor fails to end the curse\. While cursed, you have Vulnerability '
    r'to two of the three damage types associated with the armor \(not the one to which '
    r'it grants Resistance\)\.$'
)
def _armor_of_vulnerability(m):
    return (
        'Bu zırhı giydiğin sürece şu hasar türlerinden birine karşı Resistance '
        'kazanırsın: Bludgeoning, Piercing ya da Slashing. Türü GM seçer ya da rastgele '
        'belirler. Curse. Bu zırh lanetlidir; lanet ancak zırha Identify büyüsü '
        'çıkarıldığında ya da ona attuned olduğunda ortaya çıkar. Zırha attuned olmak, '
        'Remove Curse büyüsü ya da benzeri bir sihir seni hedef alana kadar seni '
        'lanetler; zırhı çıkarmak laneti sona erdirmez. Lanetliyken, zırhın ilişkili '
        'olduğu üç hasar türünden ikisine karşı Vulnerability kazanırsın (Resistance '
        'verdiği tür hariç).'
    )


@rule(
    r'^A Spell Scroll bears the words of a single spell, written in a mystical cipher\. '
    r'If the spell is on your spell list, you can read the scroll and cast its spell '
    r'without Material components\. Otherwise, the scroll is unintelligible\. Casting '
    r"the spell by reading the scroll requires the spell's normal casting time\. Once "
    r"the spell is cast, the scroll crumbles to dust\. If the casting is interrupted, "
    r"the scroll isn't lost\. If the spell is on your spell list but of a higher level "
    r'than you can normally cast, you make a (\d+) ability check using your spellcasting '
    r'ability to determine whether you cast the spell\. On a failed check, the spell '
    r'disappears from the scroll with no other effect\. If the spell requires a saving '
    r'throw or an attack roll, the spell save DC is (\d+), and the attack bonus is '
    r'(\d+)\. A Wizard spell on a Spell Scroll can be copied into a spellbook\. When a '
    r'level (\d+) spell is copied in this way, the copier must succeed on a (\d+) '
    r'Intelligence \(Arcana\)\. On a successful check, the spell is copied\. Whether the '
    r'check succeeds or fails, the Spell Scroll is destroyed\.$'
)
def _spell_scroll(m):
    return (
        'Bir Spell Scroll, gizemli bir şifreyle yazılmış tek bir büyünün sözlerini '
        'taşır. Büyü senin büyü listendeyse parşömeni okuyup büyüyü Material bileşen '
        'olmadan çıkarabilirsin; değilse parşömen sana anlaşılmaz gelir. Parşömeni '
        'okuyarak büyü çıkarmak, büyünün normal kullanım süresini gerektirir. Büyü '
        'çıkarıldığında parşömen toz olup dağılır. Çıkarma yarıda kesilirse parşömen '
        'kaybolmaz. Büyü senin listendeyse ama normalde çıkarabileceğinden yüksek '
        f'seviyedeyse, büyüyü çıkarıp çıkaramadığını belirlemek için büyü yeteneğinle '
        f'DC {m.group(1)} bir yetenek kontrolü yaparsın. Kontrol başarısız olursa büyü '
        'başka bir etki bırakmadan parşömenden kaybolur. Büyü bir saving throw ya da '
        f'saldırı zarı gerektiriyorsa spell save DC {m.group(2)}, saldırı bonusu ise '
        f'+{m.group(3)}\'tir. Spell Scroll üzerindeki bir Wizard büyüsü bir büyü '
        f'kitabına kopyalanabilir. Seviye {m.group(4)} bir büyü bu şekilde '
        f'kopyalanırken kopyalayan kişi DC {m.group(5)} Intelligence (Arcana) '
        'kontrolünde başarılı olmalıdır. Başarılı olursa büyü kopyalanır. Kontrol '
        'başarılı da olsa başarısız da olsa Spell Scroll yok olur.'
    )


@rule(
    r'^This suit of armor is reinforced with adamantine, one of the hardest substances '
    r"in existence\. While you're wearing it, any Critical Hit against you becomes a "
    r'normal hit\.$'
)
def _adamantine_armor(m):
    return (
        'Bu zırh, var olan en sert maddelerden biri olan adamantine ile '
        'güçlendirilmiştir. Onu giydiğin sürece sana karşı yapılan her Critical Hit '
        'normal vuruşa döner.'
    )


@rule(
    r'^Mithral is a light, flexible metal\. Armor made of this substance can be worn '
    r'under normal clothes\. If the armor normally imposes Disadvantage on Dexterity '
    r"\(Stealth\) checks or has a Strength requirement, the mithral version of the "
    r"armor doesn't\.$"
)
def _mithral_armor(m):
    return (
        'Mithral hafif ve esnek bir metaldir. Bu maddeden yapılan zırh normal '
        'kıyafetlerin altına giyilebilir. Zırh normalde Dexterity (Stealth) '
        "kontrollerinde Disadvantage getiriyor ya da Strength koşulu taşıyorsa, mithral "
        'sürümü bunları getirmez.'
    )


@rule(
    r'^Bound into this staff is a level (\d+) spell\. The spell is determined when the '
    r'staff is created and can be of any school of magic\. The staff has (\d+) charges '
    r'and regains (\d+d\d+) expended charges daily at dawn\. While holding the staff, '
    r"you can expend 1 charge to cast its spell\. If you expend the staff's last "
    r'charge, roll 1d20\. On a 1, the staff loses its properties and becomes a '
    r"nonmagical Quarterstaff\. The spell's saving throw DC is (\d+), and its attack "
    r'bonus is (\d+)\.$'
)
def _enspelled_staff(m):
    return (
        f'Bu asaya seviye {m.group(1)} bir büyü bağlanmıştır. Büyü, asa yaratılırken '
        f'belirlenir ve herhangi bir büyü okulundan olabilir. Asanın {m.group(2)} '
        f"charge'ı vardır ve her şafakta harcanan {m.group(3)} charge'ını geri kazanır. "
        "Asayı elinde tutarken 1 charge harcayıp büyüsünü çıkarabilirsin. Asanın son "
        "charge'ını harcarsan 1d20 at. 1 gelirse asa özelliklerini yitirir ve sıradan "
        f'bir Quarterstaff olur. Büyünün saving throw DC\'si {m.group(4)}, saldırı '
        f'bonusu ise +{m.group(5)}\'tir.'
    )


@rule(
    r'^You gain a \+(\d+) bonus to attack rolls and damage rolls made with this magic '
    r'weapon\. While the weapon is on your person, you also gain a \+(\d+) bonus to '
    r'saving throws\. Luck\. If the weapon is on your person, you can call on its luck '
    r"\(no action required\) to reroll one failed D20 Test if you don't have the "
    r"Incapacitated condition\. You must use the second roll\. Once used, this property "
    r"can't be used again until the next dawn\. Wish\. The weapon has (\d+d\d+) "
    r'charges\. While holding it, you can expend 1 charge and cast Wish from it\. Once '
    r"used, this property can't be used again until the next dawn\. The weapon loses "
    r'this property if it has no charges\.$'
)
def _luck_blade(m):
    return (
        f'{bonus_tr(m.group(1))} Silah üzerindeyken ayrıca saving throw\'larına '
        f'+{m.group(2)} bonus alırsın. Luck. Silah üzerindeyken, Incapacitated '
        'durumunda değilsen şansına başvurup (eylem gerekmez) başarısız bir D20 '
        "Test'ini yeniden atabilirsin. İkinci sonucu kullanmak zorundasın. Bir kez "
        'kullanıldıktan sonra bu özellik ertesi şafağa kadar tekrar kullanılamaz. Wish. '
        f'Silahın {m.group(3)} charge\'ı vardır. Onu elinde tutarken 1 charge harcayıp '
        'ondan Wish büyüsünü çıkarabilirsin. Bir kez kullanıldıktan sonra bu özellik '
        "ertesi şafağa kadar tekrar kullanılamaz. Silahın hiç charge'ı kalmazsa bu "
        'özelliğini yitirir.'
    )


@rule(
    r'^While wearing this belt, your Strength score changes to (\d+)\. The item has no '
    r"effect on you if your Strength without the belt is equal to or greater than the "
    r"belt's score\.$"
)
def _belt_of_giant_strength(m):
    return (
        f"Bu kemeri taktığın sürece Strength puanın {m.group(1)} olur. Kemersiz "
        "Strength'in kemerin verdiği puana eşit ya da ondan yüksekse eşyanın sana etkisi "
        'olmaz.'
    )


@rule(
    r'^While wearing this belt, your Strength changes to a score granted by the belt\. '
    r'The type of giant determines the score \(see the table below\)\. The item has no '
    r"effect on you if your Strength without the belt is equal to or greater than the "
    r"belt's score\.\n\n(\| Belt .+)$"
)
def _belt_of_giant_strength_table(m):
    table = m.group(1).replace('| Str. | Rarity    |', '| Str. | Nadirlik  |', 1)
    return (
        "Bu kemeri taktığın sürece Strength'in kemerin verdiği bir puana döner. Puanı "
        'giant türü belirler (aşağıdaki tabloya bak). Kemersiz '
        "Strength'in kemerin verdiği puana eşit ya da ondan yüksekse eşyanın sana etkisi "
        f'olmaz.\n\n{table}'
    )


@rule(
    r'^When you attack a creature with this magic weapon and roll a 20 on the d20 for '
    r"the attack roll, that target takes an extra (\d+) Necrotic damage if it isn't a "
    r'Construct or an Undead, and you gain Temporary Hit Points equal to the amount of '
    r'Necrotic damage taken\.$'
)
def _life_stealing_weapon(m):
    return (
        "Bu büyülü silahla bir yaratığa saldırıp saldırı zarında d20'de 20 atarsan, "
        f'hedef Construct ya da Undead değilse fazladan {m.group(1)} Necrotic hasarı '
        'alır ve sen alınan Necrotic hasarı kadar Temporary Hit Point kazanırsın.'
    )


@rule(
    r'^When you hit a creature with an attack using this magic weapon, the target takes '
    r'an extra (\d+d\d+) Necrotic damage and must succeed on a DC (\d+) Constitution '
    r'saving throw or be unable to regain Hit Points for 1 hour\. The target repeats '
    r'the save at the end of each of its turns, ending the effect on itself on a '
    r'success\.$'
)
def _weapon_of_wounding(m):
    return (
        'Bu büyülü silahla bir yaratığa vurduğunda, hedef fazladan '
        f'{m.group(1)} Necrotic hasarı alır ve DC {m.group(2)} Constitution saving '
        "throw'da başarılı olmalıdır; başaramazsa 1 saat boyunca Hit Point geri "
        "kazanamaz. Hedef her turunun sonunda saving throw'u tekrarlar; başarırsa etki "
        'kendi üzerinden kalkar.'
    )


@rule(
    r'^When you hit with an attack roll using this magic weapon, the target takes an '
    r'extra (\d+d\d+) Cold damage\. In addition, while you hold the weapon, you have '
    r'Resistance to Fire damage\. In freezing temperatures, the weapon sheds Bright '
    r'Light in a (\d+)-foot radius and Dim Light for an additional (\d+) feet\. When '
    r'you draw this weapon, you can extinguish all nonmagical flames within (\d+) feet '
    r"of yourself\. Once used, this property can't be used again for 1 hour\.$"
)
def _frost_brand(m):
    return (
        'Bu büyülü silahla yaptığın bir saldırı zarı tutarsa hedef fazladan '
        f'{m.group(1)} Cold hasarı alır. Ayrıca silahı elinde tuttuğun sürece Fire '
        f'hasarına karşı Resistance kazanırsın. Dondurucu havada silah {m.group(2)} '
        f'feet yarıçapında Bright Light, ek olarak {m.group(3)} feet boyunca da Dim '
        f'Light yayar. Bu silahı çektiğinde çevrendeki {m.group(4)} feet içindeki tüm '
        'sıradan alevleri söndürebilirsin. Bir kez kullanıldıktan sonra bu özellik 1 '
        'saat boyunca tekrar kullanılamaz.'
    )


@rule(
    r'^You can take a Bonus Action to toss this magic weapon into the air\. When you do '
    r'so, the weapon begins to hover, flies up to (\d+) feet, and attacks one creature '
    r'of your choice within (\d+) feet of itself\. The weapon uses your attack roll and '
    r'adds your ability modifier to damage rolls\. While the weapon hovers, you can '
    r'take a Bonus Action to cause it to fly up to (\d+) feet to another spot within '
    r'(\d+) feet of you\. As part of the same Bonus Action, you can cause the weapon to '
    r'attack one creature within (\d+) feet of the weapon\. After the hovering weapon '
    r'attacks for the fourth time, it flies back to you and tries to return to your '
    r'hand\. If you have no hand free, the weapon falls to the ground in your space\. '
    r'If the weapon has no unobstructed path to you, it moves as close to you as it can '
    r'and then falls to the ground\. It also ceases to hover if you grasp it or are '
    r'more than (\d+) feet away from it\.$'
)
def _dancing_weapon(m):
    return (
        'Bir Bonus Action harcayarak bu büyülü silahı havaya fırlatabilirsin. Bunu '
        f'yaptığında silah havada asılı kalmaya başlar, {m.group(1)} feet kadar uçar ve '
        f'kendisine {m.group(2)} feet içindeki, senin seçtiğin bir yaratığa saldırır. '
        'Silah senin saldırı zarını kullanır ve hasar zarlarına senin yetenek '
        'modifiyerini ekler. Silah havada asılıyken bir Bonus Action harcayarak onu '
        f'{m.group(3)} feet kadar uçurup sana {m.group(4)} feet içindeki başka bir '
        'noktaya gönderebilirsin. Aynı Bonus Action kapsamında silahın, kendisine '
        f'{m.group(5)} feet içindeki bir yaratığa saldırmasını sağlayabilirsin. Havada '
        'asılı silah dördüncü kez saldırdıktan sonra sana geri uçar ve eline dönmeye '
        'çalışır. Boş elin yoksa silah bulunduğun alanda yere düşer. Silahın sana '
        'engelsiz bir yolu yoksa sana olabildiğince yaklaşır ve yere düşer. Onu '
        f'kavrarsan ya da ondan {m.group(6)} feet\'ten uzaklaşırsan da havada asılı '
        'kalmayı bırakır.'
    )


@rule(
    r'^When you attack an object with this magic weapon and hit, maximize your weapon '
    r'damage dice against the target\.\n\nWhen you attack a creature with this weapon '
    r'and roll a 20 on the d20 for the attack roll, that target takes an extra (\d+) '
    r'(\w+) damage and gains 1 Exhaustion level\.$'
)
def _weapon_of_sharpness(m):
    return (
        'Bu büyülü silahla bir nesneye saldırıp vurduğunda, hedefe karşı silah hasar '
        'zarlarını azami değerde say.\n\n'
        "Bu silahla bir yaratığa saldırıp saldırı zarında d20'de 20 atarsan, hedef "
        f'fazladan {m.group(1)} {m.group(2)} hasarı alır ve 1 Exhaustion seviyesi '
        'kazanır.'
    )


@rule(
    r'^You can make this carpet hover and fly by taking a Magic action and using the '
    r"carpet's command word\. It moves according to your directions if you are within "
    r'(\d+) feet of it\. A (.+?) carpet can carry up to (.+?) at a fly speed of (\d+) '
    r'feet\. A carpet can carry up to twice the weight shown on the table, but its Fly '
    r'Speed is halved if it carries more than its normal capacity\.$'
)
def _carpet_of_flying(m):
    return (
        'Bir Magic eylemi harcayıp halının komut sözcüğünü kullanarak bu halıyı havada '
        f'süzdürüp uçurabilirsin. Ona {m.group(1)} feet içindeysen yönergelerine göre '
        f'hareket eder. {m.group(2)} bir halı, {m.group(4)} feet Fly Speed ile '
        f'{m.group(3)} ağırlığa kadar taşıyabilir. Bir halı tabloda gösterilen '
        'ağırlığın iki katına kadar taşıyabilir; ancak normal kapasitesinden fazlasını '
        "taşırsa Fly Speed'i yarıya iner."
    )


@rule(
    r'^You gain a \+(\d+) bonus to attack rolls and damage rolls made with this magic '
    r'weapon\. In addition, the weapon ignores Resistance to (\w+) damage\.\n\nWhen you '
    r'use this weapon to attack a creature that has at least one head and roll a 20 on '
    r"the d20 for the attack roll, you cut off one of the creature's heads\. The "
    r"creature dies if it can't survive without the lost head\. A creature is immune to "
    r"this effect if it has Immunity to (\w+) damage, if it doesn't have or need a "
    r'head, or if the GM decides that the creature is too big for its head to be cut '
    r'off with this weapon\. Such a creature instead takes an extra (\d+) (\w+) damage '
    r'from the hit\. If the creature has Legendary Resistance, it can expend one daily '
    r'use of that trait to avoid losing its head, taking the extra damage instead\.$'
)
def _vorpal_weapon(m):
    return (
        f'{bonus_tr(m.group(1))} Ayrıca silah, {m.group(2)} hasarına karşı '
        "Resistance'ı yok sayar.\n\n"
        'Bu silahla en az bir başı olan bir yaratığa saldırıp saldırı zarında '
        "d20'de 20 atarsan, yaratığın başlarından birini koparırsın. Yaratık kopan baş "
        f'olmadan yaşayamıyorsa ölür. Bir yaratık {m.group(3)} hasarına karşı Immunity '
        'taşıyorsa, başı yoksa ya da başa ihtiyacı yoksa, veya GM yaratığın bu silahla '
        'başı kopmayacak kadar büyük olduğuna karar verirse bu etkiye bağışıktır. Böyle '
        f'bir yaratık bunun yerine vuruştan fazladan {m.group(4)} {m.group(5)} hasarı '
        'alır. Yaratıkta Legendary Resistance varsa, başını kaybetmemek için o '
        'özelliğin günlük kullanımlarından birini harcayıp fazladan hasarı alabilir.'
    )


@rule(
    r'^You regain (\d+d\d+ \+ \d+) Hit Points when you drink this potion\. The '
    r"potion's red liquid glimmers when agitated\.$"
)
def _potion_of_healing(m):
    return (
        f'Bu iksiri içtiğinde {m.group(1)} Hit Point geri kazanırsın. İksirin kırmızı '
        'sıvısı çalkalandığında parıldar.'
    )


@rule(
    r'^While holding this wand, you gain a \+(\d+) bonus to spell attack rolls\. In '
    r'addition, you ignore Cover when making a spell attack roll\.$'
)
def _wand_of_war_mage_flat(m):
    return (
        f"Bu değneği elinde tuttuğun sürece büyü saldırı zarlarına +{m.group(1)} bonus "
        'alırsın. Ayrıca büyü saldırı zarı atarken Cover\'ı yok sayarsın.'
    )


@rule(
    r'^While holding this wand, you gain a bonus to spell attack rolls determined by '
    r"the wand's rarity \(Uncommon \+1, Rare \+2, Very Rare \+3\)\. In addition, you "
    r'ignore Half Cover when making a spell attack roll\.$'
)
def _wand_of_war_mage_rarity(m):
    return (
        'Bu değneği elinde tuttuğun sürece büyü saldırı zarlarına, değneğin nadirliğine '
        'göre belirlenen bir bonus alırsın (Uncommon +1, Rare +2, Very Rare +3). Ayrıca '
        "büyü saldırı zarı atarken Half Cover'ı yok sayarsın."
    )


@rule(
    r'^While holding this Shield, you have a bonus to Armor Class determined by the '
    r"Shield's rarity, in addition to the Shield's normal bonus to AC\.$"
)
def _plus_shield(m):
    return (
        "Bu Shield'ı elinde tuttuğun sürece, Shield'ın normal AC bonusuna ek olarak "
        "Armor Class'ına Shield'ın nadirliğine göre belirlenen bir bonus alırsın."
    )


@rule(
    r'^While wearing these wraps, you have a \+(\d+) bonus to attack rolls and damage '
    r'rolls made with your Unarmed Strikes\. Those strikes deal your choice of Force '
    r'damage or their normal damage type\.$'
)
def _wraps_of_unarmed_power(m):
    return (
        'Bu sargıları taktığın sürece Unarmed Strike\'larınla yaptığın saldırı '
        f"zarlarına ve hasar zarlarına +{m.group(1)} bonus alırsın. Bu vuruşlar, senin "
        'seçimine göre Force hasarı ya da normal hasar türünde hasar verir.'
    )


@rule(
    r'^While holding this rod, you gain a \+(\d+) bonus to spell attack rolls and to '
    r'the saving throw DCs of your Warlock spells\. In addition, you can regain one '
    r"spell slot as a Magic action while holding the rod\. You can't use this property "
    r'again until you finish a Long Rest\.$'
)
def _rod_of_the_pact_keeper(m):
    return (
        f'Bu asayı elinde tuttuğun sürece büyü saldırı zarlarına ve Warlock '
        f"büyülerinin saving throw DC'lerine +{m.group(1)} bonus alırsın. Ayrıca asayı "
        'elinde tutarken bir Magic eylemiyle bir büyü yuvasını geri kazanabilirsin. Bu '
        'özelliği bir Long Rest tamamlayana kadar tekrar kullanamazsın.'
    )


@rule(
    r'^You have a bonus to attack rolls and damage rolls made with this piece of magic '
    r'ammunition\. The bonus is determined by the rarity of the ammunition\. Once it '
    r'hits a target, the ammunition is no longer magical\. This ammunition is typically '
    r'found or sold in quantities of ten or twenty pieces\. Ten pieces of this '
    r'ammunition are equivalent in value to a potion of the same rarity\.$'
)
def _plus_ammunition(m):
    return (
        'Bu büyülü mühimmatla yaptığın saldırı zarlarına ve hasar zarlarına bonus '
        'alırsın. Bonusun büyüklüğü mühimmatın nadirliğine göre belirlenir. Bir hedefe '
        'isabet ettikten sonra mühimmat büyüsünü yitirir. Bu mühimmat genellikle onlu '
        'ya da yirmili demetler hâlinde bulunur veya satılır. Bu mühimmattan on tane, '
        'aynı nadirlikteki bir iksirle aynı değerdedir.'
    )


@rule(
    r'^' + BONUS_LINE + r' In addition, while you are attuned to this weapon, your Hit '
    r'Point maximum increases by 1 for each level you have attained\. Curse\. This '
    r'weapon is cursed, and becoming attuned to it extends the curse to you\. As long '
    r'as you remain cursed, you are unwilling to part with the weapon, keeping it '
    r'within reach at all times\. You also have Disadvantage on attack rolls with '
    r'weapons other than this one\. Whenever another creature damages you while the '
    r'weapon is in your possession, you must succeed on a DC (\d+) Wisdom saving throw '
    r'or go berserk\. This berserk state ends when you start your turn and there are no '
    r'creatures within (\d+) feet of you that you can see or hear\. While berserk, you '
    r'regard the creature nearest to you that you can see or hear as your enemy\. If '
    r'there are multiple possible creatures, choose one at random\. On each of your '
    r'turns, you must move as close to the creature as possible and take the Attack '
    r"action, targeting the creature\. If you're unable to get close enough to the "
    r"creature to attack it with the weapon, your turn ends after you've used up all "
    r'your available movement\. If the creature dies or can no longer be seen or heard '
    r'by you, the next nearest creature that you can see or hear becomes your new '
    r'target\.$'
)
def _berserker_weapon(m):
    return (
        f'{bonus_tr(m.group(1))} Ayrıca bu silaha attuned olduğun sürece, ulaştığın her '
        'seviye için Hit Point azamin 1 artar. Curse. Bu silah lanetlidir ve ona '
        'attuned olmak laneti sana da bulaştırır. Lanetli kaldığın sürece silahtan '
        'ayrılmaya yanaşmaz, onu her an erişebileceğin yerde tutarsın. Ayrıca bundan '
        "başka silahlarla yaptığın saldırı zarlarında Disadvantage'lı olursun. Silah "
        f'sendeyken başka bir yaratık sana hasar verdiğinde DC {m.group(2)} Wisdom '
        "saving throw'da başarılı olmalısın; başaramazsan cinnete kapılırsın. Bu cinnet "
        f'hâli, turuna başladığında {m.group(3)} feet içinde görebildiğin ya da '
        'duyabildiğin hiçbir yaratık kalmadığında sona erer. Cinnetteyken, görebildiğin '
        'ya da duyabildiğin en yakın yaratığı düşmanın sayarsın. Birden fazla aday '
        'varsa birini rastgele seç. Her turunda yaratığa olabildiğince yaklaşmalı ve '
        'onu hedef alarak Attack eylemini kullanmalısın. Silahla saldıracak kadar '
        'yaklaşamazsan, tüm hareketini harcadıktan sonra turun biter. Yaratık ölür ya '
        'da onu artık göremez veya duyamaz hâle gelirsen, görebildiğin ya da '
        'duyabildiğin bir sonraki en yakın yaratık yeni hedefin olur.'
    )


@rule(
    r'^This object looks like a feather\. Different types of feather tokens exist, '
    r'each with a different single-use effect\. The GM chooses the kind of token or '
    r'determines it randomly by rolling on the Feather Tokens table\. The type of token '
    r'determines its rarity\.\n\n'
    r'\*\*Anchor \(Uncommon\)\.\*\*.+?\n\n'
    r'\*\*Fan \(Uncommon\)\.\*\*.+?\n\n'
    r'\*\*Swan Boat \(Rare\)\.\*\*.+?\n\n'
    r'\*\*Tree \(Uncommon\)\.\*\*.+?\n\n'
    r'\*\*Whip \(Rare\)\.\*\*.+?\n\n'
    r'As a Bonus Action, you can direct the whip.+?\n\n'
    r'(\|1d100\|Token\|Rarity\|\n.+)$'
)
def _feather_token(m):
    # Metin altti butun jeton turlerini birden sayiyor; alti varyantta ayni.
    table = m.group(1).replace('|Token|Rarity|', '|Jeton|Nadirlik|', 1)
    return (
        'Bu nesne bir tüye benzer. Farklı türde tüy jetonları vardır ve her birinin '
        'tek kullanımlık farklı bir etkisi olur. Jetonun türünü GM seçer ya da Feather '
        'Tokens tablosunda zar atarak rastgele belirler. Jetonun türü nadirliğini de '
        'belirler.\n\n'
        '**Anchor (Uncommon).** Bir Magic eylemi harcayıp jetonu bir kayığa ya da '
        'gemiye değdirebilirsin. Sonraki 24 saat boyunca tekne hiçbir şekilde '
        'hareket ettirilemez. Jetonu tekneye yeniden değdirmek etkiyi bitirir. Etki '
        'bittiğinde jeton kaybolur. Bird (Rare). Bir Magic eylemi harcayıp jetonu 5 '
        'feet havaya atabilirsin. Jeton kaybolur ve yerine devasa, rengârenk bir kuş '
        "belirir. Kuşun istatistikleri Roc'unkiyle aynıdır ama saldıramaz. Basit "
        'komutlarına uyar ve azami hızıyla uçarken 500 pound\'a kadar (saatte 16 mil, '
        'günde en fazla 144 mil; her 3 saat uçuşta 1 saat dinlenmeyle) ya da bu hızın '
        "yarısıyla 1.000 pound'a kadar taşıyabilir. Kuş, bir gün için azami mesafesini "
        'uçtuktan sonra ya da 0 Hit Point\'e düştüğünde kaybolur. Kuşu bir Magic '
        'eylemiyle gönderebilirsin.\n\n'
        '**Fan (Uncommon).** Bir kayık ya da gemideysen bir Magic eylemi harcayıp '
        'jetonu 10 feet kadar havaya atabilirsin. Jeton kaybolur ve yerine çırpınan dev '
        'bir yelpaze belirir. Yelpaze havada durur ve güçlü bir rüzgâr yaratır. Bu '
        'rüzgâr bir geminin yelkenlerini doldurup 8 saat boyunca hızını saatte 5 mil '
        'artırabilir. Yelpazeyi bir Magic eylemiyle gönderebilirsin.\n\n'
        '**Swan Boat (Rare).** Bir Magic eylemi harcayıp jetonu, çapı en az 60 feet '
        'olan bir su kütlesine değdirebilirsin. Jeton kaybolur ve yerine kuğu biçiminde, '
        '50 feet uzunluğunda, 20 feet genişliğinde bir tekne belirir. Tekne kendi '
        'kendine hareket eder ve suda saatte 6 mil hızla ilerler. Teknedeyken bir Magic '
        'eylemi harcayıp ona hareket etmesini ya da 90 dereceye kadar dönmesini '
        'buyurabilirsin. Tekne 24 saat kalır, sonra kaybolur. Tekneyi bir Magic '
        'eylemiyle gönderebilirsin.\n\n'
        '**Tree (Uncommon).** Bu jetonu kullanmak için açık havada olmalısın. Bir Magic '
        'eylemi harcayıp onu yerdeki boş bir alana değdirebilirsin. Jeton kaybolur ve '
        'yerinde sıradan bir meşe ağacı biter. Ağaç 60 feet boyundadır, gövdesinin çapı '
        '5 feet\'tir ve tepesindeki dallar 20 feet yarıçapa yayılır.\n\n'
        '**Whip (Rare).** Bir Magic eylemi harcayıp jetonu kendine 10 feet içindeki bir '
        'noktaya atabilirsin. Jeton kaybolur ve yerine havada duran bir kırbaç belirir. '
        'Ardından bir Bonus Action harcayıp kırbaca 10 feet içindeki bir yaratığa +9 '
        'saldırı bonusuyla yakın mesafe büyü saldırısı yaptırabilirsin. Vuruşta hedef '
        '1d6 + 5 Force hasarı alır.\n\n'
        'Bir Bonus Action harcayarak kırbacı 20 feet kadar uçurup kırbaca 10 feet '
        'içindeki bir yaratığa saldırıyı yineletebilirsin. Kırbaç 1 saat sonra, onu '
        'göndermek için bir Magic eylemi harcadığında ya da sen öldüğünde veya '
        'Incapacitated durumuna girdiğinde kaybolur.\n\n'
        f'{table}'
    )


def translate(desc):
    for pat, fn in RULES:
        m = pat.fullmatch(desc)
        if m:
            out = fn(m)
            if out is not None:
                return out
    return None


def main():
    items = json.load(gzip.open('assets/data/magicitems.json.gz', 'rt', encoding='utf-8'))
    path = 'assets/data/tr/magicitems_tr.json'
    existing = json.load(open(path, encoding='utf-8'))

    added = 0
    for m in items:
        if m['key'] in existing:
            continue
        desc = (m.get('desc') or '').strip()
        if not desc:
            continue
        turkish = translate(desc)
        if turkish is None:
            continue
        existing[m['key']] = {'desc': turkish}
        added += 1

    ordered = {'_comment': existing['_comment']}
    for m in items:
        if m['key'] in existing:
            ordered[m['key']] = existing[m['key']]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'{added} yeni esya cevirisi; toplam {len(ordered) - 1}.')


if __name__ == '__main__':
    main()
