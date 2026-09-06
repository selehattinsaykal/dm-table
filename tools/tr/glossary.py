# -*- coding: utf-8 -*-
"""Oyun terimlerinin Turkce karsiliklari -- TEK KAYNAK.

Hem `retermize.py` (asset metinlerini toplu ceviren tek seferlik gecis) hem de
`export_glossary.py` (Dart'in stat blok alanlarinda kullandigi
`assets/data/tr/glossary_tr.json`) bu dosyayi okur.

Ingilizce birakilanlar:
  * AC, DC, CR, XP, HP -- masada kisaltmasiyla konusuluyor;
  * buyu ve canavar adlari (Fireball, Beholder) -- ozel ad.
"""

# --- yetenekler ---------------------------------------------------------
ABILITIES = {
    'Strength': 'Güç',
    'Dexterity': 'Çeviklik',
    'Constitution': 'Dayanıklılık',
    'Intelligence': 'Zekâ',
    'Wisdom': 'Bilgelik',
    'Charisma': 'Karizma',
}

ABILITY_ABBR = {
    'STR': 'GÜÇ',
    'DEX': 'ÇEV',
    'CON': 'DAY',
    'INT': 'ZEK',
    'WIS': 'BİL',
    'CHA': 'KAR',
}

# --- hasar turleri ------------------------------------------------------
DAMAGE_TYPES = {
    'Acid': 'asit',
    'Bludgeoning': 'ezici',
    'Cold': 'soğuk',
    'Fire': 'ateş',
    'Force': 'kuvvet',
    'Lightning': 'yıldırım',
    'Necrotic': 'nekrotik',
    'Piercing': 'delici',
    'Poison': 'zehir',
    'Psychic': 'zihinsel',
    'Radiant': 'ışıma',
    'Slashing': 'kesici',
    'Thunder': 'gürleme',
}

# --- durumlar -----------------------------------------------------------
CONDITIONS = {
    'Blinded': 'kör',
    'Charmed': 'büyülenmiş',
    'Deafened': 'sağır',
    'Exhaustion': 'bitkinlik',
    'Frightened': 'korkmuş',
    'Grappled': 'kavranmış',
    'Incapacitated': 'aciz',
    'Invisible': 'görünmez',
    'Paralyzed': 'felçli',
    'Petrified': 'taşlaşmış',
    'Poisoned': 'zehirlenmiş',
    'Prone': 'yere serilmiş',
    'Restrained': 'kısıtlanmış',
    'Stunned': 'sersemlemiş',
    'Unconscious': 'baygın',
}

# --- yaratik turleri ----------------------------------------------------
CREATURE_TYPES = {
    'Aberration': 'sapkınlık',
    'Beast': 'hayvan',
    'Celestial': 'semavi',
    'Construct': 'yapıntı',
    'Dragon': 'ejderha',
    'Elemental': 'elemental',
    'Fey': 'peri',
    'Fiend': 'şeytani',
    'Giant': 'dev',
    'Humanoid': 'insansı',
    'Monstrosity': 'canavarımsı',
    'Ooze': 'balçık',
    'Plant': 'bitki',
    'Undead': 'ölümsüz',
    'Object': 'nesne',
}

# --- boyutlar -----------------------------------------------------------
SIZES = {
    'Tiny': 'Ufak',
    'Small': 'Küçük',
    'Medium': 'Orta',
    'Large': 'Büyük',
    'Huge': 'Kocaman',
    'Gargantuan': 'Devasa',
}

# --- beceriler ----------------------------------------------------------
SKILLS = {
    'Acrobatics': 'Akrobasi',
    'Animal Handling': 'Hayvan Terbiyesi',
    'Arcana': 'Gizemli Bilgi',
    'Athletics': 'Atletizm',
    'Deception': 'Aldatma',
    'History': 'Tarih',
    'Insight': 'Sezgi',
    'Intimidation': 'Yıldırma',
    'Investigation': 'Araştırma',
    'Medicine': 'Tıp',
    'Nature': 'Doğa',
    'Perception': 'Algı',
    'Performance': 'Sahne Sanatları',
    'Persuasion': 'İkna',
    'Religion': 'Din',
    'Sleight of Hand': 'El Çabukluğu',
    'Stealth': 'Gizlilik',
    'Survival': 'Hayatta Kalma',
}

# --- hiz turleri --------------------------------------------------------
SPEEDS = {
    'walk': 'yürüyüş',
    'fly': 'uçuş',
    'swim': 'yüzme',
    'climb': 'tırmanma',
    'burrow': 'kazma',
    'crawl': 'sürünme',
    'hover': 'havada durma',
}

# --- duyular ------------------------------------------------------------
SENSES = {
    'Darkvision': 'karanlık görüşü',
    'Blindsight': 'kör görüş',
    'Tremorsense': 'titreşim duyusu',
    'Truesight': 'gerçek görüş',
    'Passive Perception': 'pasif algı',
}

# --- yonelim ------------------------------------------------------------
ALIGNMENTS = {
    'lawful good': 'düzenli iyi',
    'lawful neutral': 'düzenli tarafsız',
    'lawful evil': 'düzenli kötü',
    'neutral good': 'tarafsız iyi',
    'neutral': 'tarafsız',
    'neutral evil': 'tarafsız kötü',
    'chaotic good': 'kaotik iyi',
    'chaotic neutral': 'kaotik tarafsız',
    'chaotic evil': 'kaotik kötü',
    'unaligned': 'yönelimsiz',
    'any alignment': 'herhangi bir yönelim',
}

# --- diller -------------------------------------------------------------
LANGUAGES = {
    'Common': 'Ortak Dil',
    'Common Sign Language': 'Ortak İşaret Dili',
    'Abyssal': 'Uçurum Dili',
    'Aquan': 'Su Dili',
    'Auran': 'Hava Dili',
    'Celestial': 'Semavi Dil',
    'Deep Speech': 'Derin Konuşma',
    'Draconic': 'Ejderha Dili',
    'Druidic': 'Druid Dili',
    'Dwarvish': 'Cüce Dili',
    'Elvish': 'Elf Dili',
    'Giant': 'Dev Dili',
    'Gnomish': 'Gnom Dili',
    'Goblin': 'Goblin Dili',
    'Halfling': 'Buçukluk Dili',
    'Ignan': 'Ateş Dili',
    'Infernal': 'Cehennem Dili',
    'Orc': 'Ork Dili',
    'Primordial': 'İlksel Dil',
    'Sylvan': 'Orman Dili',
    'Terran': 'Toprak Dili',
    'Undercommon': 'Yeraltı Dili',
    "Thieves' cant": 'Hırsız Argosu',
    'telepathy': 'telepati',
}

# --- ders/okul ----------------------------------------------------------
SCHOOLS = {
    'Abjuration': 'Koruma',
    'Conjuration': 'Çağırma',
    'Divination': 'Kehanet',
    'Enchantment': 'Büyüleme',
    'Evocation': 'Yakarış',
    'Illusion': 'Yanılsama',
    'Necromancy': 'Ölü Büyüsü',
    'Transmutation': 'Dönüşüm',
}

# --- esya nadirligi ve kategorisi --------------------------------------
#: Veri hem 'very-rare' hem 'very_rare' hem 'Very Rare' gonderiyor; sozluk
#: gosterim aninda kucuk harfle aranir, ucu de burada.
ITEM_RARITIES = {
    'Common': 'Sıradan',
    'Uncommon': 'Az Bulunur',
    'Rare': 'Nadir',
    'Very Rare': 'Çok Nadir',
    'very-rare': 'Çok Nadir',
    'very_rare': 'Çok Nadir',
    'Legendary': 'Efsanevi',
    'Artifact': 'Kalıntı',
    'Varies': 'Değişken',
}

ITEM_CATEGORIES = {
    'Weapon': 'Silah',
    'Armor': 'Zırh',
    'Shield': 'Kalkan',
    'Adventuring Gear': 'Macera Teçhizatı',
    'Wondrous Item': 'Harikulade Eşya',
    'Potion': 'İksir',
    'Ring': 'Yüzük',
    'Rod': 'Asa',
    'Staff': 'Değnek',
    'Wand': 'Çubuk',
    'Scroll': 'Parşömen',
    'Spellcasting Focus': 'Büyü Odağı',
    'Tools': 'Aletler',
    'Mounts and Vehicles': 'Binekler ve Araçlar',
    'Trade Goods': 'Ticaret Malları',
    'Ammunition': 'Mühimmat',
    "Artisan's Tools": 'Zanaatkâr Aletleri',
    'Gaming Set': 'Oyun Takımı',
    'Instrument': 'Çalgı',
    'Equipment Pack': 'Teçhizat Paketi',
    'Food and Drink': 'Yiyecek ve İçecek',
    'Mount': 'Binek',
    'Tack and Harness': 'Koşum Takımı',
    'Vehicle': 'Araç',
    'Land Vehicle': 'Kara Aracı',
    'Waterborne Vehicle': 'Deniz Aracı',
}

# --- genel kural terimleri ---------------------------------------------
# SIRA ONEMLI: uzun obekler once uygulanmali ("Melee Attack Roll" ->
# "Attack Roll" -> "Attack"). `retermize` bu sozlugu uzunluga gore siralar,
# ama anlamli catismalar burada acikca cozuluyor.
RULES = {
    # saldiri / zar
    'Melee or Ranged Attack Roll': 'Yakın ya da Menzilli Saldırı Zarı',
    'Melee Attack Roll': 'Yakın Saldırı Zarı',
    'Ranged Attack Roll': 'Menzilli Saldırı Zarı',
    'Melee Weapon Attack': 'Yakın Silah Saldırısı',
    'Ranged Weapon Attack': 'Menzilli Silah Saldırısı',
    'Melee Spell Attack': 'Yakın Büyü Saldırısı',
    'Ranged Spell Attack': 'Menzilli Büyü Saldırısı',
    'Attack Roll': 'Saldırı Zarı',
    'attack roll': 'saldırı zarı',
    'Saving Throw': 'Kurtarma Zarı',
    'saving throw': 'kurtarma zarı',
    'Ability Check': 'Yetenek Kontrolü',
    'ability check': 'yetenek kontrolü',
    'D20 Test': 'D20 Testi',
    'Critical Hit': 'Kritik Vuruş',
    'Opportunity Attack': 'Fırsat Saldırısı',
    'Unarmed Strike': 'Silahsız Vuruş',
    'Initiative': 'İnisiyatif',
    'Proficiency Bonus': 'Yeterlilik Bonusu',
    # can / dayaniklilik
    'Temporary Hit Point': 'geçici can',
    'Hit Point': 'can',
    'Hit Dice': 'Can Zarı',
    'Hit Die': 'Can Zarı',
    'Death Saving Throw': 'Ölüm Kurtarma Zarı',
    'Bloodied': 'yaralı',
    # avantaj
    'Advantage': 'avantaj',
    'Disadvantage': 'dezavantaj',
    # eylemler
    'Bonus Action': 'Bonus Eylem',
    'Legendary Action': 'Efsanevi Eylem',
    'Reaction': 'Tepki',
    'Magic action': 'Büyü eylemi',
    'Utilize action': 'Kullanma eylemi',
    'Dash action': 'Koşma eylemi',
    'Disengage action': 'Çekilme eylemi',
    'Dodge action': 'Sakınma eylemi',
    'Hide action': 'Saklanma eylemi',
    'Attack action': 'Saldırı eylemi',
    'Study action': 'İnceleme eylemi',
    'Search action': 'Arama eylemi',
    'Ready action': 'Hazırlanma eylemi',
    'Influence action': 'Etkileme eylemi',
    # dinlenme
    'Long Rest': 'Uzun Dinlenme',
    'Short Rest': 'Kısa Dinlenme',
    # hiz
    'Fly Speed': 'uçuş hızı',
    'Swim Speed': 'yüzme hızı',
    'Climb Speed': 'tırmanma hızı',
    'Burrow Speed': 'kazma hızı',
    'Walking Speed': 'yürüyüş hızı',
    'Speed': 'hız',
    # savunma
    'Resistance': 'direnç',
    'Immunity': 'bağışıklık',
    'Vulnerability': 'zafiyet',
    # alan / arazi / isik
    'Difficult Terrain': 'zorlu arazi',
    'Bright Light': 'parlak ışık',
    'Dim Light': 'loş ışık',
    'Total Cover': 'tam siper',
    'Three-Quarters Cover': 'dörtte üç siper',
    'Half Cover': 'yarım siper',
    'Emanation': 'Yayılım',
    'Cone': 'Koni',
    'Line': 'Hat',
    'Sphere': 'Küre',
    'Cylinder': 'Silindir',
    'Cube': 'Küp',
    # buyu
    'Spellcasting Focus': 'Büyü Odağı',
    'Spellcasting': 'Büyücülük',
    'spell save DC': 'büyü kurtarma DC',
    'Concentration': 'Konsantrasyon',
    'Material component': 'Materyal bileşeni',
    'Material': 'Materyal',
    'Somatic': 'Somatik',
    'Verbal': 'Sözel',
    'Attunement': 'Uyum',
    'attuned': 'uyumlanmış',
    'attune': 'uyumlanmak',
    'Cantrip': 'Ufak Büyü',
    'Spell Slot': 'Büyü Yuvası',
    # nadirlik
    'Very Rare': 'Çok Nadir',
    'Legendary': 'Efsanevi',
    'Artifact': 'Kalıntı',
    'Uncommon': 'Az Bulunur',
    'Rare': 'Nadir',
    # sik gecen kalip
    'Condition': 'durum',
    'At Will': 'İstediği Kadar',
    'At will': 'İstediği Kadar',
    'Recharge': 'Yenilenme',
    # AC tam adiyla da geciyor; kisaltma masada zaten kullanilan bicim.
    'Armor Class': 'AC',
    'Armor Class (AC)': 'AC',
    # tutum (Influence eyleminin sonucu)
    'Friendly': 'Dostane',
    'Hostile': 'Düşmanca',
    'Indifferent': 'Kayıtsız',
    # kullanim sikligi
    '1/Day Each': 'Her Biri 1/Gün',
    '2/Day Each': 'Her Biri 2/Gün',
    '3/Day Each': 'Her Biri 3/Gün',
    '1/Day': '1/Gün',
    '2/Day': '2/Gün',
    '3/Day': '3/Gün',
    '4/Day': '4/Gün',
    '5/Day': '5/Gün',
    '6/Day': '6/Gün',
    # tablo basliklari ve genel sozcukler
    'Prepared Spells': 'Hazır Büyüler',
    'Spells Known': 'Bilinen Büyüler',
    'Spell Slots per Spell Level': 'Büyü Seviyesi Başına Büyü Yuvası',
    'Spells': 'Büyüler',
    'Spell': 'Büyü',
    'Features': 'Özellikler',
    'Feature': 'Özellik',
    'Level': 'Seviye',
    'modifier': 'modifiyer',
    'Weapon Mastery': 'Silah Ustalığı',
    'Weapon Masteries': 'Silah Ustalıkları',
    'Magic item': 'büyülü eşya',
    'Magic Item': 'Büyülü Eşya',
    'Magic weapon': 'büyülü silah',
    'Magic Weapon': 'Büyülü Silah',
    'Magic armor': 'büyülü zırh',
    'Short or Long Rest': 'Kısa ya da Uzun Dinlenme',
}

#: Belirtisiz isim tamlamasi olan karsiliklar: govde ZATEN 3. tekil iyelik
#: tasir. Ek alirken araya `n` girer ("kurtarma zarına") ve cogulda iyelik
#: sokulup geri gelir ("kurtarma zarları") -- bkz. `suffix.build`.
COMPOUND = {
    'Kurtarma Zarı',
    'kurtarma zarı',
    'Ölüm Kurtarma Zarı',
    'Saldırı Zarı',
    'saldırı zarı',
    'Yakın Saldırı Zarı',
    'Menzilli Saldırı Zarı',
    'Yakın ya da Menzilli Saldırı Zarı',
    'Yakın Silah Saldırısı',
    'Menzilli Silah Saldırısı',
    'Yakın Büyü Saldırısı',
    'Menzilli Büyü Saldırısı',
    'Fırsat Saldırısı',
    'Yetenek Kontrolü',
    'yetenek kontrolü',
    'D20 Testi',
    'Yeterlilik Bonusu',
    'Can Zarı',
    'uçuş hızı',
    'yüzme hızı',
    'tırmanma hızı',
    'kazma hızı',
    'yürüyüş hızı',
    'Büyü Odağı',
    'Büyü Yuvası',
    'Materyal bileşeni',
    'karanlık görüşü',
    'titreşim duyusu',
    'Hayvan Terbiyesi',
    'Sahne Sanatları',
    'El Çabukluğu',
    'Ölü Büyüsü',
    'Büyü eylemi',
    'Kullanma eylemi',
    'Koşma eylemi',
    'Çekilme eylemi',
    'Sakınma eylemi',
    'Saklanma eylemi',
    'Saldırı eylemi',
    'İnceleme eylemi',
    'Arama eylemi',
    'Hazırlanma eylemi',
    'Etkileme eylemi',
}

# --- buyu kartinin alan degerleri -------------------------------------
# Bu uc alan SRD'de kapali bir sozcuk dagarcigindan geliyor (20/36/25 farkli
# deger), ama serbest metin olarak saklaniyor. Tam deger eslesmesiyle
# ceviriliyorlar; ayristirma yapilmiyor. Veri kimi kayitta kucuk harfli ya da
# bozuk geliyor ('1minute', 'bonus'), onlar da burada.
CASTING_TIMES = {
    'Action': 'Eylem',
    'action': 'Eylem',
    'Action (Ritual)': 'Eylem (Ritüel)',
    'Action or 8 hours': 'Eylem ya da 8 saat',
    'Bonus Action': 'Bonus Eylem',
    'bonus': 'Bonus Eylem',
    'bonus-action': 'Bonus Eylem',
    'Reaction': 'Tepki',
    'reaction, which you take in response to taking damage':
        'Tepki (hasar aldığında kullanılır)',
    '1 minute': '1 dakika',
    '1minute': '1 dakika',
    '1 minute (Ritual)': '1 dakika (Ritüel)',
    '10 minutes': '10 dakika',
    '10 minutes (Ritual)': '10 dakika (Ritüel)',
    '1 hour': '1 saat',
    'hour': '1 saat',
    '1 hour (Ritual)': '1 saat (Ritüel)',
    '8 hours': '8 saat',
    '12 hours': '12 saat',
    '24 hours': '24 saat',
}

SPELL_RANGES = {
    'Self': 'Kendin',
    'Touch': 'Dokunuş',
    'Unlimited': 'Sınırsız',
    '5 feet': '5 feet',
    '10 feet': '10 feet',
    '10 feet (Touch)': '10 feet (Dokunuş)',
    '30 feet': '30 feet',
    '30 feet (30-foot line)': '30 feet (30-foot hat)',
    '60 feet': '60 feet',
    '90 feet': '90 feet',
    '100 feet': '100 feet',
    '120 feet': '120 feet',
    '150 feet': '150 feet',
    '300 feet': '300 feet',
    '500 feet': '500 feet',
    '1,000 feet': '1.000 feet',
    '1 mile': '1 mil',
    '1 mile (see below)': '1 mil (aşağıya bakınız)',
    '500 miles': '500 mil',
    'Self (5-foot radius)': 'Kendin (5-foot yarıçap)',
    'Self (5-foot reach)': 'Kendin (5-foot erişim)',
    'Self (10-foot radius)': 'Kendin (10-foot yarıçap)',
    'Self (10-foot Emanation)': 'Kendin (10-foot Yayılım)',
    'Self (10-foot-radius hemisphere)': 'Kendin (10-foot yarıçaplı yarım küre)',
    'Self (15-foot radius)': 'Kendin (15-foot yarıçap)',
    'Self (15-foot Cone)': 'Kendin (15-foot Koni)',
    'Self (15-foot Cube)': 'Kendin (15-foot Küp)',
    'Self (20-foot Emanation)': 'Kendin (20-foot Yayılım)',
    'Self (30-foot radius)': 'Kendin (30-foot yarıçap)',
    'Self (30-foot Cone)': 'Kendin (30-foot Koni)',
    'Self (60-foot Cone)': 'Kendin (60-foot Koni)',
    'Self (60-foot Emanation)': 'Kendin (60-foot Yayılım)',
    'Self (60-foot Line)': 'Kendin (60-foot Hat)',
    'Self (100-foot Line)': 'Kendin (100-foot Hat)',
    'Self (120-foot Line)': 'Kendin (120-foot Hat)',
    'Self (5-mile radius)': 'Kendin (5 mil yarıçap)',
}

SPELL_DURATIONS = {
    'Instantaneous': 'Anlık',
    'instantaneous': 'Anlık',
    'Special': 'Özel',
    'Until dispelled': 'Dağıtılana kadar',
    'until dispelled': 'Dağıtılana kadar',
    'Until dispelled or triggered': 'Dağıtılana ya da tetiklenene kadar',
    '1 round': '1 raunt',
    '1 minute': '1 dakika',
    '10 minutes': '10 dakika',
    '1 hour': '1 saat',
    '8 hours': '8 saat',
    'Up to 8 hours': '8 saate kadar',
    '24 hours': '24 saat',
    '1 day': '1 gün',
    '7 days': '7 gün',
    '10 days': '10 gün',
    '30 days': '30 gün',
    'Concentration, up to 1 round': 'Konsantrasyon, 1 raunta kadar',
    'Concentration, up to 6 rounds': 'Konsantrasyon, 6 raunta kadar',
    'Concentration, up to 1 minute': 'Konsantrasyon, 1 dakikaya kadar',
    'Concentration, up to 10 minutes': 'Konsantrasyon, 10 dakikaya kadar',
    'Concentration, up to 1 hour': 'Konsantrasyon, 1 saate kadar',
    'Concentration, up to 2 hours': 'Konsantrasyon, 2 saate kadar',
    'Concentration, up to 8 hours': 'Konsantrasyon, 8 saate kadar',
    'Concentration, up to 24 hours': 'Konsantrasyon, 24 saate kadar',
}

# --- silah ozellikleri --------------------------------------------------
#: 2024 silah ozellikleri. Kural metinlerinde de gectikleri icin bir kismi
#: zaten `RULES` icinde; burasi silah satirindaki ETIKET icin.
WEAPON_PROPERTIES = {
    'Ammunition': 'Mühimmat',
    'Cleave': 'Yarma',
    'Finesse': 'Ustalık',
    'Graze': 'Sıyırma',
    'Heavy': 'Ağır',
    'Light': 'Hafif',
    'Loading': 'Doldurmalı',
    'Nick': 'Çentik',
    'Push': 'İtme',
    'Reach': 'Erişim',
    'Sap': 'Sersemletme',
    'Slow': 'Yavaşlatma',
    'Thrown': 'Fırlatma',
    'Topple': 'Devirme',
    'Two-Handed': 'Çift Elli',
    'Versatile': 'Çok Yönlü',
    'Vex': 'Bezdirme',
}

# --- yeterlilikler ------------------------------------------------------
#: Zirh egitimi kategorileri. Kanonik degerler
#: `lib/domain/rules/proficiency_parsing.dart` icinde.
ARMOR_TRAINING = {
    'light': 'Hafif zırh',
    'medium': 'Orta zırh',
    'heavy': 'Ağır zırh',
    'shield': 'Kalkan',
}

#: Silah yeterliligi degerleri. Kosullu olanlar ("Martial weapons that have
#: the Light property") tek bir deger olarak saklaniyor.
WEAPON_PROFICIENCIES = {
    'simple': 'Simple silahlar',
    'martial': 'Martial silahlar',
    'martial-light': 'Light özellikli Martial silahlar',
    'martial-finesse-or-light': 'Finesse ya da Light özellikli Martial silahlar',
    'improvised': 'Doğaçlama silahlar',
}

#: Alet adlari. Anahtarlar `items.json.gz` icindeki adlarla birebir; SRD
#: metinleri ve yeterlilik satirlari bu adlari kullaniyor.
TOOLS = {
    "Alchemist's Supplies": 'Simyacı Malzemeleri',
    "Brewer's Supplies": 'Biracı Malzemeleri',
    "Calligrapher's Supplies": 'Hattat Malzemeleri',
    "Carpenter's Tools": 'Marangoz Aletleri',
    "Cartographer's Tools": 'Haritacı Aletleri',
    'Climber\'s Kit': 'Tırmanış Takımı',
    "Cobbler's Tools": 'Ayakkabıcı Aletleri',
    "Cook's Utensils": 'Aşçı Gereçleri',
    'Disguise Kit': 'Kılık Değiştirme Takımı',
    'Forgery Kit': 'Sahtecilik Takımı',
    "Glassblower's Tools": 'Camcı Aletleri',
    "Healer's Kit": 'Şifacı Takımı',
    'Herbalism Kit': 'Şifalı Ot Takımı',
    "Jeweler's Tools": 'Kuyumcu Aletleri',
    "Leatherworker's Tools": 'Sarac Aletleri',
    "Mason's Tools": 'Duvarcı Aletleri',
    "Navigator's Tools": 'Seyir Aletleri',
    "Painter's Supplies": 'Ressam Malzemeleri',
    "Poisoner's Kit": 'Zehirci Takımı',
    "Potter's Tools": 'Çömlekçi Aletleri',
    "Smith's Tools": 'Demirci Aletleri',
    "Thieves' Tools": 'Hırsız Aletleri',
    "Tinker's Tools": 'Tamirci Aletleri',
    "Weaver's Tools": 'Dokumacı Aletleri',
    "Woodcarver's Tools": 'Ahşap Oymacı Aletleri',
    # Oyun takimlari
    'Dice Set': 'Zar Takımı',
    # `items` bazi takimlari "Gaming Set, Dice" bicimiyle tasiyor; ikinci
    # parcasi da aranabilsin.
    'Dice': 'Zar Takımı',
    'Dragonchess': 'Dragonchess Takımı',
    'Three-Dragon Ante': 'Three-Dragon Ante Takımı',
    'Dragonchess Set': 'Dragonchess Takımı',
    'Playing Cards': 'Oyun Kâğıdı',
    'Three-Dragon Ante Set': 'Three-Dragon Ante Takımı',
    # Calgilar
    'Bagpipes': 'Gayda',
    'Bandore': 'Bandora',
    'Cittern': 'Sitern',
    'Drum': 'Davul',
    'Dulcimer': 'Santur',
    'Flute': 'Flüt',
    'Horn': 'Boru',
    'Lute': 'Ut',
    'Lyre': 'Lir',
    'Pan Flute': 'Pan Flütü',
    'Shawm': 'Zurna',
    'Viol': 'Viyol',
    'Yarting': 'Yarting',
}

#: Alet kumeleri (`ToolGroup`).
TOOL_GROUPS = {
    'artisansTools': 'Zanaatkâr Aletleri',
    'gamingSet': 'Oyun Takımı',
    'musicalInstrument': 'Çalgı',
    'any': 'Herhangi bir alet',
}

#: Yeterliligin nereden geldigi (`ProficiencySource`).
PROFICIENCY_SOURCES = {
    'species': 'tür',
    'background': 'geçmiş',
    'characterClass': 'sınıf',
    'feat': 'feat',
    'manual': 'elle',
}

# --- stat blogun AC aciklamasi ------------------------------------------
#: `armor_detail` alani, AC'nin yanindaki parantez ("natural armor"). 11 farkli
#: deger var ve "natural armor" 331 canavarda geciyor.
ARMOR_DETAILS = {
    'natural armor': 'doğal zırh',
    'chain mail': 'zincir zırh',
    "11 + the spell's level": "11 + büyünün seviyesi",
    "12 + the spell's level": "12 + büyünün seviyesi",
    "13 + the spell's level": "13 + büyünün seviyesi",
    "14 + the spell's level": "14 + büyünün seviyesi",
    "11 + the spell's level + 2 (Defender only)":
        "11 + büyünün seviyesi + 2 (yalnızca Defender)",
    '10 + 1 per spell level': '10 + büyü seviyesi başına 1',
    '13 plus your Wisdom modifier': '13 artı Bilgelik modifiyen',
    '12 + your Intelligence modifier': '12 + Zekâ modifiyen',
    '10 plus your Intelligence modifier': '10 artı Zekâ modifiyen',
}

# --- sinif secenekleri --------------------------------------------------
CLASS_OPTION_TYPES = {
    'Eldritch Invocation': 'Kadim Yakarış',
    'Maneuver': 'Manevra',
    'Metamagic': 'Üstbüyü',
    'Rune': 'Rün',
}

#: Sinif secenegi onkosullari; feat onkosullariyla ayni kalipta ama ayri bir
#: kume (Renown / Dragonmarked House satirlari yalnizca burada geciyor).
CLASS_OPTION_PREREQUISITES = {
    'Level 2+': 'Seviye 2+',
    'Level 5+': 'Seviye 5+',
    'Level 7+': 'Seviye 7+',
    'Level 9+': 'Seviye 9+',
    'Level 12+': 'Seviye 12+',
    'Level 15+': 'Seviye 15+',
    'Renown 3+ with a Dragonmarked House':
        'Ejderha Nişanlı bir Hanede İtibar 3+',
    'Renown 10+ with a Dragonmarked House':
        'Ejderha Nişanlı bir Hanede İtibar 10+',
    'Renown 25+ with a Dragonmarked House':
        'Ejderha Nişanlı bir Hanede İtibar 25+',
    'Renown 50+ with a Dragonmarked House':
        'Ejderha Nişanlı bir Hanede İtibar 50+',
}

# --- feat kategorisi ve onkosulu ---------------------------------------
FEAT_TYPES = {
    'General': 'Genel',
    'Origin': 'Köken',
    'Epic Boon': 'Destansı Lütuf',
    'Fighting Style': 'Dövüş Tarzı',
    'Dragonmark': 'Ejderha Nişanı',
    'Dark Gift': 'Karanlık Armağan',
}

#: Onkosullar serbest metin ama kapali bir kume; tam deger eslesmesiyle.
FEAT_PREREQUISITES = {
    'None': 'Yok',
    'Level 4+': 'Seviye 4+',
    'Level 19+': 'Seviye 19+',
    'Eberron campaign': 'Eberron kampanyası',
    'Ravenloft campaign': 'Ravenloft kampanyası',
    'Fighting Style Feature': 'Dövüş Tarzı özelliği',
    'Level 19+, Eberron campaign': 'Seviye 19+, Eberron kampanyası',
    'Level 19+, Spellcasting Feature': 'Seviye 19+, Büyücülük özelliği',
    'Level 19+, Spellcasting feature': 'Seviye 19+, Büyücülük özelliği',
    'Level 4+, Spellcasting Feature': 'Seviye 4+, Büyücülük özelliği',
    'Level 4+, Charisma 13+': 'Seviye 4+, Karizma 13+',
    'Level 4+, Dexterity 13+': 'Seviye 4+, Çeviklik 13+',
    'Level 4+, Intelligence 13+': 'Seviye 4+, Zekâ 13+',
    'Level 4+, Strength 13+': 'Seviye 4+, Güç 13+',
    'Level 4+, Strength or Dexterity 13+': 'Seviye 4+, Güç ya da Çeviklik 13+',
    'Level 4+, Dexterity or Constitution 13+':
        'Seviye 4+, Çeviklik ya da Dayanıklılık 13+',
    'Level 4+, Intelligence or Wisdom 13+':
        'Seviye 4+, Zekâ ya da Bilgelik 13+',
    'Level 4+, Wisdom or Charisma 13+':
        'Seviye 4+, Bilgelik ya da Karizma 13+',
    'Level 4+, Intelligence, Wisdom, or Charisma 13+':
        'Seviye 4+, Zekâ, Bilgelik ya da Karizma 13+',
    'Level 4+, Heavy Armor Training': 'Seviye 4+, Ağır Zırh Talimi',
    'Level 4+, Medium Armor Training': 'Seviye 4+, Orta Zırh Talimi',
    'Level 4+, Light Armor Training': 'Seviye 4+, Hafif Zırh Talimi',
    'Level 4+, Shield Training': 'Seviye 4+, Kalkan Talimi',
    'Level 4+, Martial proficiency': 'Seviye 4+, Martial yeterliliği',
    'When Gaining the Level 2 Paladin "Fighting Style" Feature':
        'Seviye 2 Paladin "Fighting Style" özelliğini kazanırken',
    'When Gaining the Level 2 Ranger "Fighting Style" Feature':
        'Seviye 2 Ranger "Fighting Style" özelliğini kazanırken',
}

# Tek harfli/cok kisa olmayan, guvenle degistirilebilen tum sozlukler.
ALL = {}
for _d in (
    RULES,
    DAMAGE_TYPES,
    CONDITIONS,
    ABILITIES,
    SKILLS,
    SENSES,
    SCHOOLS,
    SIZES,
    CREATURE_TYPES,
):
    for _k, _v in _d.items():
        ALL.setdefault(_k, _v)
