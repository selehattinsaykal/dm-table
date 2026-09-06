# -*- coding: utf-8 -*-
"""Esya ve buyulu esya ADLARININ Turkcesi.

`build_names_tr.py` bunu okuyup `names_tr.json` icindeki `items` ve
`magicItems` bolumlerini uretir. Ayri dosyada, cunku sozluk buyuk: siradan
esyalarin tamami elle yazildi, buyulu esyalar ise kalipla ("Ring of
Protection" -> "Koruma Yuzugu") uretiliyor.

CEVRILMEYENLER
  * Ozel adlar (Lolth, Vecna, Quaal, Heward, Zhentarim) oldugu gibi kalir.
  * Kalibi tutmayan buyulu esya adlari Ingilizce gorunur; eksik ceviri hata
    degil, [audit] bunlari sayar.
  * Para birimi kisaltmalari (GP, SP, CP) masada oyle konusuluyor.

Kalip ceviri "belirtisiz isim tamlamasi" kuruyor: govde 3. tekil iyelik ekini
[suffix.build] ile aliyor ("Yuzuk" -> "Yuzugu"), bu yuzden ek uyumu elle
yazilmiyor.
"""
import gzip
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import suffix  # noqa: E402

# --- Siradan esyalar --------------------------------------------------------

#: Paketteki 460 esyanin tamami. Anahtar bundle'daki INGILIZCE ad.
ITEMS = {
    # silahlar
    'Battleaxe': 'Savaş Baltası',
    'Blowgun': 'Üfleme Borusu',
    'Club': 'Sopa',
    'Dagger': 'Hançer',
    'Dart': 'Dart',
    'Flail': 'Zincirli Topuz',
    'Glaive': 'Glaive',
    'Greataxe': 'Büyük Balta',
    'Greatclub': 'Büyük Sopa',
    'Greatsword': 'Büyük Kılıç',
    'Halberd': 'Teber',
    'Hand Crossbow': 'El Arbaleti',
    'Handaxe': 'El Baltası',
    'Heavy Crossbow': 'Ağır Arbalet',
    'Javelin': 'Cirit',
    'Lance': 'Süvari Mızrağı',
    'Light Crossbow': 'Hafif Arbalet',
    'Light Hammer': 'Hafif Çekiç',
    'Longbow': 'Uzun Yay',
    'Longsword': 'Uzun Kılıç',
    'Mace': 'Topuz',
    'Maul': 'Balyoz',
    'Morningstar': 'Dikenli Topuz',
    'Net': 'Ağ',
    'Pike': 'Uzun Mızrak',
    'Psychic Blade': 'Zihinsel Bıçak',
    'Quarterstaff': 'Savaş Sopası',
    'Rapier': 'Meç',
    'Scimitar': 'Pala',
    'Shortbow': 'Kısa Yay',
    'Shortsword': 'Kısa Kılıç',
    'Sickle': 'Orak',
    'Sling': 'Sapan',
    'Spear': 'Mızrak',
    'Trident': 'Üç Dişli Mızrak',
    'War Pick': 'Savaş Kazması',
    'Warhammer': 'Savaş Çekici',
    'Whip': 'Kırbaç',
    # atilan / patlayan
    'Acid': 'Asit',
    'Alchemist\'s Fire': 'Simyacı Ateşi',
    'Holy Water': 'Kutsal Su',
    'Oil': 'Yağ',
    'Torch': 'Meşale',
    'Bomb': 'Bomba',
    'Dynamite Stick': 'Dinamit Lokumu',
    'Fragmentation Grenade': 'Parça Tesirli El Bombası',
    'Smoke Grenade': 'Sis Bombası',
    'Gunpowder (keg)': 'Barut (fıçı)',
    'Gunpowder (powder horn)': 'Barut (barutluk)',
    # ates ve enerji silahlari
    'Antimatter Rifle': 'Antimadde Tüfeği',
    'Automatic Rifle': 'Otomatik Tüfek',
    'Grenade Launcher': 'Bombaatar',
    'Hunting Rifle': 'Av Tüfeği',
    'Laser Pistol': 'Lazer Tabanca',
    'Laser Rifle': 'Lazer Tüfek',
    'Musket': 'Misket Tüfeği',
    'Pistol': 'Tabanca',
    'Revolver': 'Toplu Tabanca',
    'Semiautomatic Pistol': 'Yarı Otomatik Tabanca',
    'Shotgun': 'Pompalı Tüfek',
    'Energy Cell': 'Enerji Hücresi',
    # cephane
    'Ammunition': 'Cephane',
    'Arrow': 'Ok',
    'Arrows (20)': 'Ok (20)',
    'Bolt': 'Arbalet Oku',
    'Bolts (20)': 'Arbalet Oku (20)',
    'Bullets, Firearm (10)': 'Mermi, Ateşli Silah (10)',
    'Bullets, Sling (20)': 'Mermi, Sapan (20)',
    'Firearm Bullet': 'Ateşli Silah Mermisi',
    'Firearm Bullets (10)': 'Ateşli Silah Mermisi (10)',
    'Needle': 'İğne',
    'Needles (50)': 'İğne (50)',
    'Sling Bullet': 'Sapan Taşı',
    'Sling Bullets (20)': 'Sapan Taşı (20)',
    'Quiver': 'Sadak',
    # zirh
    'Breastplate': 'Göğüslük',
    'Chain Mail': 'Zincir Zırh',
    'Chain Shirt': 'Zincir Gömlek',
    'Half Plate Armor': 'Yarım Plaka Zırh',
    'Hide Armor': 'Post Zırh',
    'Leather Armor': 'Deri Zırh',
    'Padded Armor': 'Kapitone Zırh',
    'Plate Armor': 'Plaka Zırh',
    'Ring Mail': 'Halkalı Zırh',
    'Scale Mail': 'Pullu Zırh',
    'Shield': 'Kalkan',
    'Splint Armor': 'Şeritli Zırh',
    'Studded Leather Armor': 'Perçinli Deri Zırh',
    # macera gereci
    'Antitoxin': 'Panzehir',
    'Backpack': 'Sırt Çantası',
    'Ball Bearings': 'Bilye',
    'Barrel': 'Fıçı',
    'Basket': 'Sepet',
    'Bedroll': 'Yatak Rulosu',
    'Bell': 'Çıngırak',
    'Blanket': 'Battaniye',
    'Block and Tackle': 'Palanga',
    'Book': 'Kitap',
    'Bottle, Glass': 'Şişe, Cam',
    'Bucket': 'Kova',
    'Bullseye Lantern': 'Mercekli Fener',
    'Caltrops': 'Demir Dikeni',
    'Candle': 'Mum',
    'Canvas (1 sq. yd.)': 'Yelken Bezi (1 yarda kare)',
    'Case, Crossbow Bolt': 'Kılıf, Arbalet Oku',
    'Case, Map or Scroll': 'Kılıf, Harita veya Parşömen',
    'Chain': 'Zincir',
    'Chest': 'Sandık',
    'Climber\'s Kit': 'Tırmanış Takımı',
    'Clothes, Fine': 'Kıyafet, Şık',
    'Clothes, Traveler\'s': 'Kıyafet, Yolcu',
    'Component Pouch': 'Bileşen Kesesi',
    'Costume': 'Kostüm',
    'Cotton Cloth (1 sq. yd.)': 'Pamuklu Kumaş (1 yarda kare)',
    'Crossbow Bolt Case': 'Arbalet Oku Kılıfı',
    'Crowbar': 'Levye',
    'Desert Clothing': 'Çöl Kıyafeti',
    'Disguise Kit': 'Kılık Değiştirme Takımı',
    'Emblem': 'Amblem',
    'Fine Clothes': 'Şık Kıyafet',
    'Flask': 'Matara',
    'Forgery Kit': 'Sahtecilik Takımı',
    'Garb of Light and Shadow': 'Işık ve Gölge Kisvesi',
    'Glass Bottle': 'Cam Şişe',
    'Grappling Hook': 'Kanca',
    'Healer\'s Kit': 'Şifacı Takımı',
    'Herbalism Kit': 'Şifalı Ot Takımı',
    'Holy Symbol, Amulet': 'Kutsal Sembol, Muska',
    'Holy Symbol, Emblem': 'Kutsal Sembol, Amblem',
    'Holy Symbol, Reliquary': 'Kutsal Sembol, Emanetlik',
    'Hooded Lantern': 'Kapaklı Fener',
    'Hunting Trap': 'Av Kapanı',
    'Ink': 'Mürekkep',
    'Ink Pen': 'Mürekkepli Kalem',
    'Iron Pot': 'Demir Tencere',
    'Iron Spike': 'Demir Kazık',
    'Iron Spikes': 'Demir Kazık',
    'Jug': 'Testi',
    'Ladder': 'Merdiven',
    'Lamp': 'Kandil',
    'Lantern, Bullseye': 'Fener, Mercekli',
    'Lantern, Hooded': 'Fener, Kapaklı',
    'Linen (1 sq. yd.)': 'Keten (1 yarda kare)',
    'Lock': 'Kilit',
    'Locking Spellbook': 'Kilitli Büyü Kitabı',
    'Magnifying Glass': 'Büyüteç',
    'Manacles': 'Kelepçe',
    'Map': 'Harita',
    'Map or Scroll Case': 'Harita veya Parşömen Kılıfı',
    'Mirror': 'Ayna',
    'Monster Camouflage': 'Canavar Kamuflajı',
    'Orb': 'Küre',
    'Paper': 'Kâğıt',
    'Parchment': 'Parşömen',
    'Perfume': 'Parfüm',
    'Poisoner\'s Kit': 'Zehirci Takımı',
    'Pole': 'Sırık',
    'Portable Ram': 'Taşınabilir Koçbaşı',
    'Pot, Iron': 'Tencere, Demir',
    'Pouch': 'Kese',
    'Prosthetic Limb': 'Protez Uzuv',
    'Ram, Portable': 'Koçbaşı, Taşınabilir',
    'Reliquary': 'Emanetlik',
    'Robe': 'Kaftan',
    'Rod': 'Çubuk',
    'Rope': 'Halat',
    'Sack': 'Çuval',
    'Signal Whistle': 'İşaret Düdüğü',
    'Shovel': 'Kürek',
    'Spikes, Iron': 'Kazık, Demir',
    'Spell Scroll': 'Büyü Parşömeni',
    'Spyglass': 'Dürbün',
    'Staff': 'Asa',
    'String': 'Sicim',
    'Tent': 'Çadır',
    'Thieves\' Tools': 'Hırsız Aletleri',
    'Tinderbox': 'Çakmaklık',
    'Traveler\'s Clothes': 'Yolcu Kıyafeti',
    'Trinket': 'Ufak Eşya',
    'Vial': 'Küçük Şişe',
    'Warm Fungal Clothing': 'Sıcak Mantar Kıyafeti',
    'Waterskin': 'Su Tulumu',
    'Winter Camouflage': 'Kış Kamuflajı',
    'Wooden Staff': 'Ahşap Asa',
    'Yew Wand': 'Porsuk Değneği',
    'Sprig of Mistletoe': 'Ökseotu Dalı',
    'Wand': 'Değnek',
    'Amulet': 'Muska',
    'Bright Fungal Cloak': 'Parlak Mantar Pelerini',
    'Genie Robe': 'Cin Kaftanı',
    'Devil Mask': 'Şeytan Maskesi',
    'Ioun Stone': 'Ioun Taşı',
    'Horn': 'Boru',
    'Eye Agate': 'Gözlü Akik',
    # buyu odaklari
    'Druidic Focus, Sprig of Mistletoe': 'Druid Odağı, Ökseotu Dalı',
    'Druidic Focus, Wooden Staff': 'Druid Odağı, Ahşap Asa',
    'Druidic Focus, Yew Wand': 'Druid Odağı, Porsuk Değneği',
    # yiyecek icecek
    'Ale (mug)': 'Bira (maşrapa)',
    'Bread (loaf)': 'Ekmek (somun)',
    'Cheese (wedge)': 'Peynir (dilim)',
    'Common Wine (bottle)': 'Sıradan Şarap (şişe)',
    'Fine Wine (bottle)': 'Kaliteli Şarap (şişe)',
    'Rations': 'Kumanya',
    'Feed (per day)': 'Yem (günlük)',
    'Flour': 'Un',
    'Salt': 'Tuz',
    'Wheat': 'Buğday',
    'Cinnamon': 'Tarçın',
    'Cloves': 'Karanfil',
    'Ginger': 'Zencefil',
    'Pepper': 'Karabiber',
    'Saffron': 'Safran',
    'Silk': 'İpek',
    # aletler
    'Alchemist\'s Supplies': 'Simyacı Malzemeleri',
    'Brewer\'s Supplies': 'Biracı Malzemeleri',
    'Calligrapher\'s Supplies': 'Hattat Malzemeleri',
    'Carpenter\'s Tools': 'Marangoz Aletleri',
    'Cartographer\'s Tools': 'Haritacı Aletleri',
    'Cobbler\'s Tools': 'Ayakkabıcı Aletleri',
    'Cook\'s Utensils': 'Aşçı Gereçleri',
    'Glassblower\'s Tools': 'Cam Üfleyici Aletleri',
    'Jeweler\'s Tools': 'Kuyumcu Aletleri',
    'Leatherworker\'s Tools': 'Sarac Aletleri',
    'Mason\'s Tools': 'Duvarcı Aletleri',
    'Navigator\'s Tools': 'Seyir Aletleri',
    'Painter\'s Supplies': 'Ressam Malzemeleri',
    'Potter\'s Tools': 'Çömlekçi Aletleri',
    'Smith\'s Tools': 'Demirci Aletleri',
    'Tinker\'s Tools': 'Tamirci Aletleri',
    'Weaver\'s Tools': 'Dokumacı Aletleri',
    'Woodcarver\'s Tools': 'Ahşap Oymacı Aletleri',
    # oyun ve muzik takimlari
    'Dice Set': 'Zar Takımı',
    'Dragonchess Set': 'Ejderha Satrancı Takımı',
    'Playing Cards': 'Oyun Kâğıtları',
    'Three-Dragon Ante Set': 'Üç Ejderha Bahsi Takımı',
    'Gaming Set, Dice': 'Oyun Takımı, Zar',
    'Gaming Set, Dragonchess': 'Oyun Takımı, Ejderha Satrancı',
    'Gaming Set, Playing Cards': 'Oyun Takımı, Oyun Kâğıtları',
    'Gaming Set, Three-Dragon Ante': 'Oyun Takımı, Üç Ejderha Bahsi',
    'Bagpipes': 'Gayda',
    'Bandore': 'Bandore',
    'Cittern': 'Cittern',
    'Drum': 'Davul',
    'Dulcimer': 'Kanun',
    'Flute': 'Flüt',
    'Lute': 'Lut',
    'Lyre': 'Lir',
    'Pan Flute': 'Pan Flüt',
    'Shawm': 'Zurna',
    'Viol': 'Viyol',
    'Yarting': 'Yarting',
    'Musical Instrument, Bagpipes': 'Çalgı, Gayda',
    'Musical Instrument, Drum': 'Çalgı, Davul',
    'Musical Instrument, Dulcimer': 'Çalgı, Kanun',
    'Musical Instrument, Flute': 'Çalgı, Flüt',
    'Musical Instrument, Horn': 'Çalgı, Boru',
    'Musical Instrument, Lute': 'Çalgı, Lut',
    'Musical Instrument, Lyre': 'Çalgı, Lir',
    'Musical Instrument, Pan Flute': 'Çalgı, Pan Flüt',
    'Musical Instrument, Shawm': 'Çalgı, Zurna',
    'Musical Instrument, Viol': 'Çalgı, Viyol',
    # paketler
    'Burglar\'s Pack': 'Hırsız Paketi',
    'Diplomat\'s Pack': 'Diplomat Paketi',
    'Dungeoneer\'s Pack': 'Zindancı Paketi',
    'Entertainer\'s Pack': 'Hokkabaz Paketi',
    'Explorer\'s Pack': 'Kâşif Paketi',
    'Priest\'s Pack': 'Rahip Paketi',
    'Scholar\'s Pack': 'Âlim Paketi',
    # zehirler ve iksirler
    'Assassin\'s Blood': 'Suikastçı Kanı',
    'Basic Poison': 'Basit Zehir',
    'Poison, Basic': 'Zehir, Basit',
    'Burnt Othur Fumes': 'Yanık Othur Dumanı',
    'Carrion Crawler Mucus': 'Carrion Crawler Salyası',
    'Essence of Ether': 'Eter Özü',
    'Lolth\'s Sting': 'Lolth\'un İğnesi',
    'Malice': 'Garez',
    'Midnight Tears': 'Gece Yarısı Gözyaşları',
    'Oil of Taggit': 'Taggit Yağı',
    'Pale Tincture': 'Soluk Tentür',
    'Purple Worm Poison': 'Purple Worm Zehiri',
    'Serpent Venom': 'Yılan Zehiri',
    'Torpor': 'Uyuşukluk',
    'Truth Serum': 'Doğruluk Serumu',
    'Wyvern Poison': 'Wyvern Zehiri',
    'Potion of Healing': 'Şifa İksiri',
    'Potions of Healing': 'Şifa İksirleri',
    'Potion of Giant Strength': 'Dev Gücü İksiri',
    # binekler, hayvanlar, araclar
    'Axe Beak': 'Balta Gaga',
    'Camel': 'Deve',
    'Chicken': 'Tavuk',
    'Cow': 'İnek',
    'Draft Horse': 'Yük Atı',
    'Elephant': 'Fil',
    'Flying Snake': 'Uçan Yılan',
    'Goat': 'Keçi',
    'Horse (Draft)': 'At (Yük)',
    'Horse (Riding)': 'At (Binek)',
    'Mastiff': 'Mastif',
    'Mule': 'Katır',
    'Ox': 'Öküz',
    'Pig': 'Domuz',
    'Pony': 'Midilli',
    'Riding Horse': 'Binek Atı',
    'Sheep': 'Koyun',
    'Sled Dog': 'Kızak Köpeği',
    'Warhorse': 'Savaş Atı',
    'Stabling (per day)': 'Ahır (günlük)',
    'Exotic Saddle': 'Egzotik Eyer',
    'Military Saddle': 'Askerî Eyer',
    'Riding Saddle': 'Binek Eyeri',
    'Saddle (Exotic)': 'Eyer (Egzotik)',
    'Saddle (Military)': 'Eyer (Askerî)',
    'Saddle (Riding)': 'Eyer (Binek)',
    'Carriage': 'Fayton',
    'Cart': 'Araba',
    'Chariot': 'Savaş Arabası',
    'Covered Wagon': 'Üstü Kapalı Yük Arabası',
    'Sled': 'Kızak',
    'Wagon': 'Yük Arabası',
    'Airship': 'Hava Gemisi',
    'Galley': 'Kadırga',
    'Keelboat': 'Salapurya',
    'Longship': 'Uzun Gemi',
    'Rowboat': 'Sandal',
    'Sailing Ship': 'Yelkenli',
    'Warship': 'Savaş Gemisi',
    # madenler ve degerli taslar
    'Copper': 'Bakır',
    'Silver': 'Gümüş',
    'Gold': 'Altın',
    'Platinum': 'Platin',
    'Iron': 'Demir',
    'Gold Bar (5-pound)': 'Altın Külçe (5 libre)',
    'Silver Bar (2-pound)': 'Gümüş Külçe (2 libre)',
    'Silver Bar (5-pound)': 'Gümüş Külçe (5 libre)',
    'Alexandrite': 'Aleksandrit',
    'Amber': 'Kehribar',
    'Amethyst': 'Ametist',
    'Aquamarine': 'Akuamarin',
    'Azurite': 'Azurit',
    'Banded Agate': 'Damarlı Akik',
    'Black Opal': 'Siyah Opal',
    'Black Pearl': 'Siyah İnci',
    'Black Sapphire': 'Siyah Safir',
    'Bloodstone': 'Kan Taşı',
    'Blue Quartz': 'Mavi Kuvars',
    'Blue Sapphire': 'Mavi Safir',
    'Blue Spinel': 'Mavi Spinel',
    'Carnelian': 'Karnelyan',
    'Chalcedony': 'Kalsedon',
    'Chrysoberyl': 'Krizoberil',
    'Chrysoprase': 'Krizopraz',
    'Citrine': 'Sitrin',
    'Coral': 'Mercan',
    'Crystal': 'Kristal',
    'Diamond': 'Elmas',
    'Emerald': 'Zümrüt',
    'Fire Opal': 'Ateş Opali',
    'Garnet': 'Granat',
    'Hematite': 'Hematit',
    'Jacinth': 'Jasint',
    'Jade': 'Yeşim',
    'Jasper': 'Jasp',
    'Jet': 'Oltu Taşı',
    'Lapis Lazuli': 'Lapis Lazuli',
    'Malachite': 'Malakit',
    'Moonstone': 'Ay Taşı',
    'Moss Agate': 'Yosun Akiği',
    'Obsidian': 'Obsidyen',
    'Onyx': 'Oniks',
    'Opal': 'Opal',
    'Pearl': 'İnci',
    'Peridot': 'Peridot',
    'Quartz': 'Kuvars',
    'Rhodochrosite': 'Rodokrozit',
    'Ruby': 'Yakut',
    'Sardonyx': 'Sardoniks',
    'Spinel': 'Spinel',
    'Star Ruby': 'Yıldız Yakut',
    'Star Sapphire': 'Yıldız Safir',
    'Star rose quartz': 'Yıldız pembe kuvars',
    'Tiger Eye': 'Kaplan Gözü',
    'Topaz': 'Topaz',
    'Tourmaline': 'Turmalin',
    'Turquoise': 'Turkuaz',
    'Yellow Sapphire': 'Sarı Safir',
    'Zircon': 'Zirkon',
    # locaların hatira esyalari
    'Cult of the Dragon Trinket': 'Cult of the Dragon Hatırası',
    'Emerald Enclave Trinket': 'Emerald Enclave Hatırası',
    'Harper Trinket': 'Harper Hatırası',
    'Lords\' Alliance Trinket': 'Lords\' Alliance Hatırası',
    'Order of the Gauntlet Trinket': 'Order of the Gauntlet Hatırası',
    'Purple Dragon Knight Trinket': 'Purple Dragon Knight Hatırası',
    'Red Wizard Trinket': 'Red Wizard Hatırası',
    'Zhentarim Trinket': 'Zhentarim Hatırası',
    # hazine tanimlari (uzun serbest metinler)
    'Bejeweled gold bracelet': 'Mücevherli altın bilezik',
    'Bejeweled ivory drinking horn with gold filigree': (
        'Altın telkârili, mücevherli fildişi içki boynuzu'
    ),
    'Black velvet mask stitched with silver thread': (
        'Gümüş iplikle işlenmiş siyah kadife maske'
    ),
    'Bottle stopper cork embossed with gold leaf and set with amethysts': (
        'Altın varakla kabartılmış, ametist kakmalı şişe mantarı'
    ),
    'Box of turquoise animal figurines': 'Turkuaz hayvan figürleri kutusu',
    'Brass mug with jade inlay': 'Yeşim kakmalı pirinç maşrapa',
    'Bronze crown': 'Bronz taç',
    'Bundle of sheet music representing the lost dirges of a famous composer': (
        'Ünlü bir bestecinin kayıp ağıtlarını taşıyan nota destesi'
    ),
    'Carved bone statuette': 'Oymalı kemik heykelcik',
    'Carved ivory statuette': 'Oymalı fildişi heykelcik',
    'Carved wooden harp with ivory inlay and zircon gems': (
        'Fildişi kakmalı ve zirkon taşlı oymalı ahşap arp'
    ),
    'Ceremonial gold armor with black pearls': (
        'Siyah incili tören altını zırh'
    ),
    'Cloth-of-gold vestments': 'Sırma dokuma cüppe',
    'Copper chalice with silver filigree': 'Gümüş telkârili bakır kadeh',
    'Detailed, life-sized dragonborn skull cast in electrum': (
        'Elektrumdan dökülmüş, gerçek boyutta ayrıntılı dragonborn kafatası'
    ),
    'Embroidered glove set with jewel chips': (
        'Mücevher kırıklarıyla işlenmiş eldiven'
    ),
    'Embroidered silk and velvet mantle set with numerous moonstones': (
        'Sayısız ay taşıyla bezenmiş, işlemeli ipek ve kadife harmani'
    ),
    'Embroidered silk handkerchief': 'İşlemeli ipek mendil',
    'Eye patch decorated with tiny blue sapphires and moonstones': (
        'Ufak mavi safir ve ay taşlarıyla bezenmiş göz bandı'
    ),
    'Fine gold chain set with a fire opal': (
        'Ateş opali kakmalı ince altın zincir'
    ),
    'Gilded royal coach or funeral barge': (
        'Yaldızlı kraliyet arabası ya da cenaze mavnası'
    ),
    'Gold birdcage with electrum filigree': (
        'Elektrum telkârili altın kuş kafesi'
    ),
    'Gold bracelet': 'Altın bilezik',
    'Gold circlet set with four aquamarines': (
        'Dört akuamarin kakmalı altın taç'
    ),
    'Gold comb shaped like a dragon with red garnets as eyes': (
        'Gözleri kırmızı granat olan, ejderha biçimli altın tarak'
    ),
    'Gold cup set with emeralds': 'Zümrüt kakmalı altın kupa',
    'Gold idol': 'Altın put',
    'Gold jewelry box with platinum filigree': (
        'Platin telkârili altın mücevher kutusu'
    ),
    'Gold locket with a painted portrait inside': (
        'İçinde portre bulunan altın madalyon'
    ),
    'Gold music box': 'Altın müzik kutusu',
    'Gold ring set with bloodstones': 'Kan taşı kakmalı altın yüzük',
    'Gold statuette set with rubies': 'Yakut kakmalı altın heykelcik',
    'Handheld mirror set in a painted wooden frame': (
        'Boyalı ahşap çerçeveli el aynası'
    ),
    'Jade game board with gold playing pieces': (
        'Altın taşlarıyla yeşim oyun tahtası'
    ),
    'Jeweled anklet': 'Mücevherli halhal',
    'Jeweled gold crown': 'Mücevherli altın taç',
    'Jeweled platinum ring': 'Mücevherli platin yüzük',
    'Necklace string of small pink pearls': 'Ufak pembe incilerden kolye',
    'Obsidian statuette with gold fittings and inlay': (
        'Altın kakma ve tutturmalı obsidyen heykelcik'
    ),
    'Old masterpiece painting': 'Eski bir usta işi tablo',
    'Painted gold war mask': 'Boyalı altın savaş maskesi',
    'Pair of engraved bone dice': 'Kazıma işli bir çift kemik zar',
    'Platinum bracelet set with an emerald': 'Zümrüt kakmalı platin bilezik',
    'Set of gold nesting dolls': 'İç içe geçen altın bebek takımı',
    'Silver and gold brooch': 'Gümüş ve altın broş',
    'Silver chalice set with moonstones': 'Ay taşı kakmalı gümüş kadeh',
    'Silver ewer': 'Gümüş ibrik',
    'Silver necklace with a gemstone pendant': (
        'Değerli taş uçlu gümüş kolye'
    ),
    'Silk vestments with gold embroidery': 'Altın işlemeli ipek cüppe',
    'Well-made tapestry that is 10 feet by 10 feet': (
        '10 fit x 10 fit boyutunda özenli bir duvar halısı'
    ),
}

#: "(50 GP)" gibi fiyat ekli varyantlar: govdenin cevirisi + ayni parantez.
_PRICE_SUFFIX = re.compile(r'^(?P<head>.+?) \((?P<price>\d+ [A-Z]{2})\)$')


def item_names():
    """Paketteki esya adlari icin ceviri haritasi."""
    bundle = json.load(
        gzip.open('assets/data/items.json.gz', 'rt', encoding='utf-8')
    )
    out = {}
    for row in bundle:
        name = row['name']
        if name in ITEMS:
            out[name] = ITEMS[name]
            continue
        # "Smith's Tools (20 GP)": govde zaten sozlukte, fiyat oldugu gibi.
        match = _PRICE_SUFFIX.match(name)
        if match and match.group('head') in ITEMS:
            out[name] = f'{ITEMS[match.group("head")]} ({match.group("price")})'
    return dict(sorted(out.items()))


# --- Buyulu esyalar ---------------------------------------------------------

#: Kalibin GOVDESI: "X of Y" icindeki X. Ceviriye 3. tekil iyelik eklenir.
MAGIC_HEADS = {
    'Amulet': 'Muska',
    'Ammunition': 'Cephane',
    'Apparatus': 'Düzenek',
    'Armor': 'Zırh',
    'Arrow': 'Ok',
    'Bag': 'Çanta',
    'Bead': 'Boncuk',
    'Belt': 'Kemer',
    'Boots': 'Çizme',
    'Bowl': 'Kâse',
    'Bracers': 'Kolluk',
    'Brazier': 'Mangal',
    'Broom': 'Süpürge',
    'Candle': 'Mum',
    'Cap': 'Başlık',
    'Cape': 'Pelerin',
    'Carpet': 'Halı',
    'Cauldron': 'Kazan',
    'Censer': 'Buhurdan',
    'Chime': 'Çan',
    'Circlet': 'Taç',
    'Cloak': 'Pelerin',
    'Clothes': 'Kıyafet',
    'Crystal Ball': 'Kristal Küre',
    'Cube': 'Küp',
    'Decanter': 'Sürahi',
    'Deck': 'Deste',
    'Dust': 'Toz',
    'Eyes': 'Gözlük',
    'Feather Token': 'Tüy Nişanı',
    'Figurine': 'Figür',
    'Gauntlets': 'Zırh Eldiveni',
    'Gem': 'Taş',
    'Gloves': 'Eldiven',
    'Hammer': 'Çekiç',
    'Goggles': 'Gözlük',
    'Hat': 'Şapka',
    'Headband': 'Alın Bandı',
    'Helm': 'Miğfer',
    'Horn': 'Boru',
    'Horseshoes': 'Nal',
    'Instrument': 'Çalgı',
    'Ioun Stone': 'Ioun Taşı',
    'Lantern': 'Fener',
    'Mantle': 'Harmani',
    'Manual': 'Kılavuz',
    'Medallion': 'Madalyon',
    'Mirror': 'Ayna',
    'Necklace': 'Kolye',
    'Oil': 'Yağ',
    'Orb': 'Küre',
    'Pearl': 'İnci',
    'Periapt': 'Muska',
    'Pipes': 'Kaval',
    'Pole': 'Sırık',
    'Potion': 'İksir',
    'Ring': 'Yüzük',
    'Robe': 'Kaftan',
    'Rod': 'Çubuk',
    'Rope': 'Halat',
    'Saddle': 'Eyer',
    'Scarab': 'Bokböceği',
    'Scroll': 'Parşömen',
    'Shield': 'Kalkan',
    'Slippers': 'Terlik',
    'Sphere': 'Küre',
    'Staff': 'Asa',
    'Stone': 'Taş',
    'Sword': 'Kılıç',
    'Talisman': 'Tılsım',
    'Tome': 'Tomar',
    'Wand': 'Değnek',
    'Weapon': 'Silah',
    'Wings': 'Kanat',
}

#: Kalibin TAMLAYANI: "X of Y" icindeki Y. Bastaki "the" atilir.
MAGIC_TAILS = {
    'Adaptation': 'Uyum',
    'Animal Influence': 'Hayvan Etkisi',
    'Annihilation': 'Yok Ediş',
    'Arachnida': 'Örümcek',
    'Archery': 'Okçuluk',
    'Awakening': 'Uyanış',
    'Beans': 'Fasulye',
    'Bewitching': 'Büyüleme',
    'Billowing': 'Dalgalanma',
    'Blasting': 'Patlama',
    'Brightness': 'Parlaklık',
    'Charming': 'Cazibe',
    'Climbing': 'Tırmanma',
    'Clear Thought': 'Berrak Düşünce',
    'Cold Resistance': 'Soğuğa Direnç',
    'Acid Resistance': 'Asite Direnç',
    'Fire Resistance': 'Ateşe Direnç',
    'Force Resistance': 'Güce Direnç',
    'Lightning Resistance': 'Yıldırıma Direnç',
    'Necrotic Resistance': 'Nekrotiğe Direnç',
    'Poison Resistance': 'Zehire Direnç',
    'Psychic Resistance': 'Zihinsele Direnç',
    'Radiant Resistance': 'Işımaya Direnç',
    'Thunder Resistance': 'Gök Gürültüsüne Direnç',
    'Comprehending Languages': 'Dilleri Anlama',
    'Defense': 'Savunma',
    'Devouring': 'Yutma',
    'Direction': 'Yön',
    'Disappearance': 'Kayboluş',
    'Disguise': 'Kılık Değiştirme',
    'Displacement': 'Yer Değiştirme',
    'Djinni Summoning': 'Djinni Çağırma',
    'Dragonkind': 'Ejderha Soyu',
    'Dryness': 'Kuruluk',
    'Elemental Command': 'Element Hâkimiyeti',
    'Elvenkind': 'Elf',
    'Endless Water': 'Sonsuz Su',
    'Entanglement': 'Dolanma',
    'Evasion': 'Sıyrılma',
    'Expression': 'İfade',
    'False Tracks': 'Sahte İz',
    'Feather Falling': 'Tüy Gibi Düşme',
    'Fireballs': 'Ateş Topu',
    'Flying': 'Uçan',
    'Force': 'Güç',
    'Free Action': 'Serbest Hareket',
    'Gainful Exercise': 'Verimli Antrenman',
    'Giant Strength': 'Dev Gücü',
    'Golems': 'Golem',
    'Good Luck': 'Uğur',
    'Haunting': 'Musallat',
    'Health': 'Sağlık',
    'Healing': 'Şifa',
    'Greater Healing': 'Büyük Şifa',
    'Superior Healing': 'Üstün Şifa',
    'Supreme Healing': 'Kusursuz Şifa',
    'Illusions': 'Yanılsama',
    'Intellect': 'Zekâ',
    'Invisibility': 'Görünmezlik',
    'Invocation': 'Yakarış',
    'Jumping': 'Sıçrama',
    'Leadership and Influence': 'Liderlik ve Nüfuz',
    'Levitation': 'Havalanma',
    'Life Trapping': 'Can Hapsi',
    'Many Fashions': 'Bin Bir Kılık',
    'Mending': 'Onarım',
    'Mind Reading': 'Zihin Okuma',
    'Mind Shielding': 'Zihin Kalkanı',
    'Minute Seeing': 'İnce Görü',
    'Missile Attraction': 'Mermi Çekimi',
    'Missile Snaring': 'Mermi Kapma',
    'Night': 'Gece',
    'Nourishment': 'Besin',
    'Ogre Power': 'Ogre Gücü',
    'Opening': 'Açılış',
    'Pure Good': 'Saf İyilik',
    'Power': 'Güç',
    'Prayer Beads': 'Dua Boncukları',
    'Protection': 'Koruma',
    'Quickness of Action': 'Hızlı Eylem',
    'Refreshment': 'Ferahlık',
    'Regeneration': 'Yenilenme',
    'Revealing': 'Açığa Çıkarma',
    'Scintillating Colors': 'Parıldayan Renkler',
    'Scribing': 'Yazım',
    'Seeing': 'Görü',
    'Shielding': 'Kalkan',
    'Shooting Stars': 'Kayan Yıldızlar',
    'Silent Alarm': 'Sessiz Alarm',
    'Smoke Monsters': 'Duman Canavarları',
    'Sobriety': 'Ayıklık',
    'Speed': 'Hız',
    'Spell Resistance': 'Büyü Direnci',
    'Spell Storing': 'Büyü Depolama',
    'Spell Turning': 'Büyü Çevirme',
    'Spider Climbing': 'Örümcek Tırmanışı',
    'Stars': 'Yıldız',
    'Striding and Springing': 'Adım ve Sıçrayış',
    'Sustenance': 'İdame',
    'Swimming': 'Yüzme',
    'Swimming and Climbing': 'Yüzme ve Tırmanma',
    'Telekinesis': 'Telekinezi',
    'Telepathy': 'Telepati',
    'Teleportation': 'Işınlanma',
    'the Archmagi': 'Başbüyücü',
    'the Bards': 'Ozan',
    'the Bat': 'Yarasa',
    'the Cavalier': 'Süvari',
    'the Deep': 'Derinlik',
    'the Eagle': 'Kartal',
    'the Manta Ray': 'Vatoz',
    'the Mountebank': 'Şarlatan',
    'the Planes': 'Diyarlar',
    'the Ram': 'Koç',
    'the Sewers': 'Lağım',
    'the Sphere': 'Küre',
    'the Winding Path': 'Dolambaçlı Yol',
    'the Winterlands': 'Kış Diyarı',
    'Thievery': 'Hırsızlık',
    'Thoughts': 'Düşünce',
    'Three Wishes': 'Üç Dilek',
    'Time': 'Zaman',
    'Tricks': 'Numara',
    'True Seeing': 'Gerçek Görü',
    'Ultimate Evil': 'Nihai Kötülük',
    'Understanding': 'Kavrayış',
    'Unarmed Power': 'Silahsız Güç',
    'Useful Items': 'İşe Yarar Eşyalar',
    'Valhalla': 'Valhalla',
    'Vermin': 'Haşere',
    'Warmth': 'Sıcaklık',
    'Water Breathing': 'Su Solunumu',
    'Water Walking': 'Su Üstünde Yürüme',
    'Wizardry': 'Büyücülük',
    'Wound Closure': 'Yara Kapama',
    'X-ray Vision': 'Röntgen Görüşü',
    'Bodily Health': 'Beden Sağlığı',
    'Many Spells': 'Bin Bir Büyü',
    'Wondrous Power': 'Şaşırtıcı Güç',
    # zirh ve silah varyantlari
    'Invulnerability': 'Yenilmezlik',
    'Resistance': 'Direnç',
    'Vulnerability': 'Zafiyet',
    'Sharpness': 'Keskinlik',
    'Wounding': 'Yaralama',
    'Slipperiness': 'Kayganlık',
    'Etherealness': 'Eterlik',
    'Lightning': 'Yıldırım',
    # dev gucu kusaklari
    'Cloud Giant Strength': 'Bulut Devi Gücü',
    'Fire Giant Strength': 'Ateş Devi Gücü',
    'Frost Giant Strength': 'Ayaz Devi Gücü',
    'Hill Giant Strength': 'Tepe Devi Gücü',
    'Stone Giant Strength': 'Taş Devi Gücü',
    'Storm Giant Strength': 'Fırtına Devi Gücü',
    'Dwarvenkind': 'Cüce',
    # element cagirma
    'Commanding Air Elementals': 'Hava Elementali Buyruğu',
    'Commanding Earth Elementals': 'Toprak Elementali Buyruğu',
    'Commanding Fire Elementals': 'Ateş Elementali Buyruğu',
    'Commanding Water Elementals': 'Su Elementali Buyruğu',
    'Controlling Air Elementals': 'Hava Elementali Denetimi',
    'Controlling Earth Elementals': 'Toprak Elementali Denetimi',
    'Controlling Fire Elementals': 'Ateş Elementali Denetimi',
    'Controlling Water Elementals': 'Su Elementali Denetimi',
    'Summoning': 'Çağırma',
    'Rebirth': 'Yeniden Doğuş',
    # golem kilavuzlari
    'Clay Golems': 'Kil Golem',
    'Flesh Golems': 'Et Golem',
    'Iron Golems': 'Demir Golem',
    'Stone Golems': 'Taş Golem',
    # cephane
    'Aberration Slaying': 'Aberration Avı',
    'Beast Slaying': 'Beast Avı',
    'Celestial Slaying': 'Celestial Avı',
    'Construct Slaying': 'Construct Avı',
    'Dragon Slaying': 'Ejderha Avı',
    'Elemental Slaying': 'Elemental Avı',
    'Fey Slaying': 'Fey Avı',
    'Fiend Slaying': 'Fiend Avı',
    'Giant Slaying': 'Dev Avı',
    'Humanoid Slaying': 'Humanoid Avı',
    'Monstrosity Slaying': 'Monstrosity Avı',
    'Ooze Slaying': 'Ooze Avı',
    'Plant Slaying': 'Plant Avı',
    'Undead Slaying': 'Undead Avı',
    # kalanlar
    'Proof against Detection and Location': 'Tespit ve Konuma Karşı Koruma',
    'Proof against Poison': 'Zehire Karşı Koruma',
    'Many Things': 'Bin Bir Şey',
    'Sneezing and Choking': 'Hapşırma ve Boğulma',
    'Awareness': 'Farkındalık',
    'Brilliance': 'Parıltı',
    'a Zephyr': 'Meltem',
    'Angling': 'Olta',
    'Collapsing': 'Katlanma',
    'Animal Friendship': 'Hayvan Dostluğu',
    'Clairvoyance': 'Uzağı Görü',
    'Comprehension': 'Kavrayış',
    'Diminution': 'Küçülme',
    'Fire Breath': 'Ateş Nefesi',
    'Gaseous Form': 'Gaz Hâli',
    'Growth': 'Büyüme',
    'Heroism': 'Kahramanlık',
    'Flying': 'Uçuş',
    'Longevity': 'Uzun Ömür',
    'Mind Control': 'Zihin Denetimi',
    'Poison': 'Zehir',
    'Speak with Animals': 'Hayvanlarla Konuşma',
    'Vitality': 'Dinçlik',
    'Water Breathing': 'Su Solunumu',
    'the Pact Keeper': 'Antlaşma Koruyucusu',
    'the War Mage': 'Savaş Büyücüsü',
    'the Crab': 'Yengeç',
    'the Magi': 'Büyücü',
    'the Woodlands': 'Orman',
    'the Python': 'Piton',
    'the Adder': 'Engerek',
    'Absorption': 'Emiş',
    'Fortitude': 'Metanet',
    'Greater Absorption': 'Büyük Emiş',
    'Insight': 'Sezgi',
    'Leadership': 'Liderlik',
    'Mastery': 'Ustalık',
    'Reserve': 'Yedek',
    'Strength': 'Güç',
    'Alertness': 'Teyakkuz',
    'Frost Brand': 'Ayaz Kılıcı',
    'Security': 'Güvenlik',
    'Rulership': 'Hükümdarlık',
    'Terror': 'Dehşet',
    'the Stilled Tongue': 'Susturulmuş Dil',
    'Exalted Deeds': 'Yüce İşler',
    'Vile Darkness': 'Aşağılık Karanlık',
    'Venom': 'Zehir',
    'Life Stealing': 'Can Çalma',
    'Thunderbolts': 'Yıldırım',
    'Thunderous Thumping': 'Gürleyen Tıngırtı',
    'Disruption': 'Parçalama',
    'Smiting': 'Kahretme',
    'Greater Invisibility': 'Büyük Görünmezlik',
    'Pugilism': 'Yumruk Dövüşü',
    'the Acrobat': 'Akrobat',
    'Ehlonna': 'Ehlonna',
    'Eyes': 'Göz',
    'Lordly Might': 'Lort Kudreti',
    'Resurrection': 'Diriliş',
    'Titan Summoning': 'Titan Çağırma',
    'Adornment': 'Süs',
    'Birdcalls': 'Kuş Sesi',
    'Fire': 'Ateş',
    'Flowers': 'Çiçek',
    'Frost': 'Ayaz',
    'Striking': 'Vuruş',
    'Swarming Insects': 'Böcek Sürüsü',
    'Thunder and Lightning': 'Gök Gürültüsü ve Yıldırım',
    'Withering': 'Kuruma',
    'Answering': 'Karşılık',
    'Kas': 'Kas',
    'Fish Command': 'Balık Buyruğu',
    'Binding': 'Bağlama',
    'Conducting': 'Şeflik',
    'Enemy Detection': 'Düşman Tespiti',
    'Fear': 'Korku',
    'Lightning Bolts': 'Yıldırım',
    'Magic Detection': 'Büyü Tespiti',
    'Magic Missiles': 'Sihirli Mermi',
    'Orcus': 'Orcus',
    'Paralysis': 'Felç',
    'Polymorph': 'Biçim Değiştirme',
    'Pyrotechnics': 'Ateş Oyunu',
    'Secrets': 'Sır',
    'Web': 'Ağ',
    'Wonder': 'Mucize',
    'Warning': 'Uyarı',
}

#: Kalibi hic tutmayan, elle yazilan adlar.
MAGIC_EXACT = {
    'Adamantine Armor': 'Adamantin Zırh',
    'Alchemy Jug': 'Simya Testisi',
    'Animated Shield': 'Canlandırılmış Kalkan',
    'Arrow-Catching Shield': 'Ok Yakalayan Kalkan',
    'Bag of Holding': 'Sığdıran Çanta',
    'Berserker Axe': 'Berserker Baltası',
    'Cloak of Invisibility': 'Görünmezlik Pelerini',
    'Cube of Force': 'Güç Küpü',
    'Cubic Gate': 'Küp Geçit',
    'Dancing Sword': 'Dans Eden Kılıç',
    'Defender': 'Muhafız',
    'Demon Armor': 'İblis Zırhı',
    'Dimensional Shackles': 'Boyutsal Pranga',
    'Dragon Scale Mail': 'Ejderha Pullu Zırh',
    'Dragon Slayer': 'Ejderha Katili',
    'Dread Helm': 'Dehşet Miğferi',
    'Driftglobe': 'Süzülen Küre',
    'Dwarven Plate': 'Cüce Plakası',
    'Dwarven Thrower': 'Cüce Fırlatıcı',
    'Efficient Quiver': 'Verimli Sadak',
    'Efreeti Bottle': 'Efreeti Şişesi',
    'Elemental Gem': 'Element Taşı',
    'Elven Chain': 'Elf Zinciri',
    'Enduring Spellbook': 'Dayanıklı Büyü Kitabı',
    'Ersatz Eye': 'Takma Göz',
    'Eversmoking Bottle': 'Hiç Sönmeyen Duman Şişesi',
    'Flame Tongue': 'Alev Dili',
    'Folding Boat': 'Katlanır Kayık',
    'Frost Brand': 'Ayaz Kılıcı',
    'Giant Slayer': 'Dev Katili',
    'Handy Haversack': 'Kullanışlı Heybe',
    'Immovable Rod': 'Kımıldamaz Çubuk',
    'Instant Fortress': 'Anlık Kale',
    'Iron Bands': 'Demir Kuşak',
    'Iron Flask': 'Demir Matara',
    'Javelin of Lightning': 'Yıldırım Ciriti',
    'Luck Blade': 'Şans Kılıcı',
    'Lock of Trickery': 'Oyunbaz Kilit',
    'Marvelous Pigments': 'Olağanüstü Boyalar',
    'Mind Sharpener': 'Zihin Bileyici',
    'Moon-Touched Sword': 'Ay Dokunuşlu Kılıç',
    'Mystery Key': 'Gizem Anahtarı',
    'Mysterious Deck': 'Gizemli Deste',
    'Nine Lives Stealer': 'Dokuz Can Hırsızı',
    'Oathbow': 'Yemin Yayı',
    'Perfume of Bewitching': 'Büyüleyici Parfüm',
    'Philter of Love': 'Aşk İksiri',
    'Portable Hole': 'Taşınabilir Delik',
    'Prosthetic Limb': 'Protez Uzuv',
    'Repulsion Shield': 'İtiş Kalkanı',
    'Rival Coin': 'Rakip Madeni',
    'Rope of Climbing': 'Tırmanan Halat',
    'Ruby of the War Mage': 'Savaş Büyücüsü Yakutu',
    'Sending Stones': 'Haber Taşları',
    'Sentinel Shield': 'Nöbetçi Kalkan',
    'Spell Scroll': 'Büyü Parşömeni',
    'Spellguard Shield': 'Büyü Siperi Kalkan',
    'Spirit Board': 'Ruh Tahtası',
    'Sovereign Glue': 'Mutlak Tutkal',
    'Sun Blade': 'Güneş Kılıcı',
    'Sword of Sharpness': 'Keskinlik Kılıcı',
    'Sword of Wounding': 'Yaralama Kılıcı',
    'Talking Doll': 'Konuşan Bebek',
    'Tankard of Sobriety': 'Ayıklık Maşrapası',
    'Universal Solvent': 'Evrensel Çözücü',
    'Veteran\'s Cane': 'Kıdemli Bastonu',
    'Vicious Weapon': 'Gaddar Silah',
    'Vorpal Sword': 'Vorpal Kılıç',
    'Winged Boots': 'Kanatlı Çizme',
    'Wraps of Unarmed Power': 'Silahsız Güç Sargıları',
    # ozel adli efsanevi silahlar -- ad ozel, niteleme cevrilmiyor
    'Blackrazor': 'Blackrazor',
    'Ebonbane': 'Ebonbane',
    'Wave': 'Wave',
    'Whelm': 'Whelm',
    'Holy Avenger': 'Kutsal İntikamcı',
    'Dragon Orb': 'Ejderha Küresi',
    'Dragon Scale Mail': 'Ejderha Pullu Zırh',
    'Hag Eye': 'Cadı Gözü',
    'Manifold Tool': 'Çok Amaçlı Alet',
    'Nature\'s Mantle': 'Doğa Harmanisi',
    'Thayan Spell Tattoo': 'Thay Büyü Dövmesi',
    'Wind Fan': 'Rüzgâr Yelpazesi',
    'Tentacle Rod': 'Dokunaçlı Çubuk',
    'Spell-Refueling Ring': 'Büyü Tazeleyen Yüzük',
    'Clockwork Amulet': 'Saat Düzeneği Muskası',
    'Dark Shard Amulet': 'Kara Kıymık Muskası',
    'Adventurer\'s Ring': 'Maceracı Yüzüğü',
    'Glamoured Studded Leather': 'Yanıltıcı Perçinli Deri Zırh',
    'Dwarven Half Plate': 'Cüce Yarım Plakası',
    'Half Plate': 'Yarım Plaka Zırh',
    'Padded': 'Kapitone Zırh',
    'Plate': 'Plaka Zırh',
    'Splint': 'Şeritli Zırh',
    'Studded Leather': 'Perçinli Deri Zırh',
    'Enspelled Staff': 'Büyü Yüklü Asa',
    'Enspelled Armor': 'Büyü Yüklü Zırh',
    'Enspelled Weapon': 'Büyü Yüklü Silah',
    'Mithral Armor': 'Mithral Zırh',
    'Elven Chain Mail': 'Elf Zincir Zırhı',
    'Elven Chain Shirt': 'Elf Zincir Gömleği',
    'Cantrip': 'Cantrip',
    # sahip adli esyalar: ozel ad Ingilizce, gerisi Turkce
    'Baba Yaga\'s Dancing Broom': 'Baba Yaga\'nın Dans Eden Süpürgesi',
    'Charlatan\'s Die': 'Şarlatan Zarı',
    'Daern\'s Instant Fortress': 'Daern\'in Anlık Kalesi',
    'Demonomicon of Iggwilv': 'Iggwilv\'in Demonomicon\'u',
    'Harkon\'s Bite': 'Harkon\'un Isırığı',
    'Heward\'s Handy Haversack': 'Heward\'ın Kullanışlı Heybesi',
    'Heward\'s Handy Spice Pouch': 'Heward\'ın Kullanışlı Baharat Kesesi',
    'Keoghtom\'s Ointment': 'Keoghtom\'un Merhemi',
    'Nolzur\'s Marvelous Pigments': 'Nolzur\'un Olağanüstü Boyaları',
    'Quaal\'s Feather Token': 'Quaal\'ın Tüy Nişanı',
    'Apparatus of Kwalish': 'Kwalish\'in Düzeneği',
    'Ear Horn of Hearing': 'İşitme Borusu',
    'Elixir of Health': 'Sağlık İksiri',
    'Eye of Vecna': 'Vecna\'nın Gözü',
    'Hand of Vecna': 'Vecna\'nın Eli',
    'Iron Bands of Bilarro': 'Bilarro\'nun Demir Kuşakları',
    'Well of Many Worlds': 'Bin Bir Dünya Kuyusu',
    'Pipe of Smoke Monsters': 'Duman Canavarları Piposu',
    'Pot of Awakening': 'Uyanış Saksısı',
    'Book of Exalted Deeds': 'Yüce İşler Kitabı',
    'Book of Vile Darkness': 'Aşağılık Karanlık Kitabı',
    'Lute of Illusions': 'Yanılsama Lutu',
    'Axe of the Dwarvish Lords': 'Cüce Lordlarının Baltası',
    'Brooch of Shielding': 'Kalkan Broşu',
}

#: Ad ONUNE gelen nitelemeler: "Vicious Longsword", "Black Dragon Scale Mail".
MAGIC_PREFIXES = {
    'Adamantine': 'Adamantin',
    'Berserker': 'Berserker',
    'Black': 'Siyah',
    'Blue': 'Mavi',
    'Brass': 'Pirinç',
    'Bronze': 'Bronz',
    'Copper': 'Bakır',
    'Dancing': 'Dans Eden',
    'Demon': 'İblis',
    'Dwarven': 'Cüce',
    'Elven': 'Elf',
    'Flame Tongue': 'Alev Dili',
    'Glamoured': 'Yanıltıcı',
    'Gold': 'Altın',
    'Green': 'Yeşil',
    'Mithral': 'Mithral',
    'Red': 'Kırmızı',
    'Silver': 'Gümüş',
    'Thunderous': 'Gürleyen',
    'Vicious': 'Gaddar',
    'Vorpal': 'Vorpal',
    'White': 'Beyaz',
}

#: Uzun onek kisa onekten once denensin ("Flame Tongue" < "Flame").
_PREFIXES_BY_LENGTH = sorted(MAGIC_PREFIXES, key=len, reverse=True)

#: "Potion of Healing (Greater)" gibi parantezli nitelemeler.
_PAREN = re.compile(r'^(?P<head>.+?) \((?P<note>[^()]+)\)$')

#: "+1 Longsword" / "Longsword, +1" gibi bonuslu varyantlar.
_PLUS_PREFIX = re.compile(r'^\+(?P<bonus>\d) (?P<rest>.+)$')

#: "Wand of the War Mage +1" gibi sondan bonuslu varyantlar.
_PLUS_SUFFIX = re.compile(r'^(?P<rest>.+) \+(?P<bonus>\d)$')

#: "Bag of Tricks, Gray" gibi virgullu varyantlar.
_COMMA = re.compile(r'^(?P<head>.+?), (?P<rest>.+)$')


#: [suffix] kurallarinin tutmadigi govdeler.
#:
#: Iki ayri durum var: (1) alintilarda ve tek heceli govdelerde yumusama
#: kurali sasiyor ("halat" -> "haladı", "taç" -> "taçı"); (2) govde ZATEN
#: belirtisiz tamlama ("Savaş Sopası") -- ikinci bir iyelik eki sozcugu bozar,
#: dogrusu ada hic dokunmamak.
_POSSESSIVE_OVERRIDES = {
    'Alın Bandı': 'Alın Bandı',
    'Bokböceği': 'Bokböceği',
    'Halat': 'Halatı',
    'Ioun Taşı': 'Ioun Taşı',
    'Kıyafet': 'Kıyafeti',
    'Savaş Sopası': 'Savaş Sopası',
    'Taç': 'Tacı',
    'Tüy Nişanı': 'Tüy Nişanı',
    'Zırh Eldiveni': 'Zırh Eldiveni',
}


def _possessive(head_tr):
    """"Yüzük" -> "Yüzüğü": belirtisiz isim tamlamasinin ikinci ogesi."""
    if head_tr in _POSSESSIVE_OVERRIDES:
        return _POSSESSIVE_OVERRIDES[head_tr]
    return suffix.build(head_tr, ['POSS3'])


#: Parantez ve virgul icindeki nitelemeler. Canavar ve renk ozel adlari
#: burada degil, cevrilmeden gecer.
NOTES = {
    'Cantrip': 'Cantrip',
    'Gray': 'Gri',
    'Rust': 'Pas',
    'Tan': 'Kum',
    'Greater': 'Büyük',
    'Lesser': 'Küçük',
    'Superior': 'Üstün',
    'Supreme': 'Kusursuz',
    'Air': 'Hava',
    'Earth': 'Toprak',
    'Fire': 'Ateş',
    'Water': 'Su',
    'Cloud': 'Bulut',
    'Frost': 'Ayaz',
    'Hill': 'Tepe',
    'Stone': 'Taş',
    'Storm': 'Fırtına',
    'Frost or Stone': 'Ayaz veya Taş',
    # tuy nisani cesitleri
    'Anchor': 'Çapa',
    'Bird': 'Kuş',
    'Fan': 'Yelpaze',
    'Swan Boat': 'Kuğu Kayığı',
    'Tree': 'Ağaç',
}

#: "Level 3" gibi seviye notlari.
_LEVEL_NOTE = re.compile(r'^Level (?P<level>\d+)$')


def _note(note, depth):
    """Parantez/virgul icindeki nitelemenin Turkcesi; cozulemezse aynen."""
    if note in NOTES:
        return NOTES[note]
    match = _LEVEL_NOTE.match(note)
    if match:
        return f'Seviye {match.group("level")}'
    return (
        MAGIC_TAILS.get(note)
        or ITEMS.get(note)
        or translate_magic(note, depth + 1)
        or note
    )


def _of_pattern(name):
    """"Ring of Protection" -> "Koruma Yüzüğü"; cozulemezse None.

    Govde siradan esya sozlugune de dusuyor: "Scimitar of Speed" gibi adlarda
    govde zaten [ITEMS] icinde.
    """
    if ' of ' not in name:
        return None
    head, _, tail = name.partition(' of ')
    head_tr = MAGIC_HEADS.get(head) or ITEMS.get(head)
    tail_tr = MAGIC_TAILS.get(tail)
    if head_tr is None or tail_tr is None:
        return None
    return f'{tail_tr} {_possessive(head_tr)}'


def _prefix_pattern(name, depth):
    """"Flame Tongue Longsword" -> "Alev Dili Uzun Kılıç".

    Onek sozlukte OLMALI ve kalan kisim kendi basina cevrilebilmeli; ikisi de
    tutmazsa kalip uygulanmaz (yarim cevrilmis ad uretmektense Ingilizce
    kalsin).
    """
    for prefix in _PREFIXES_BY_LENGTH:
        if not name.startswith(f'{prefix} '):
            continue
        rest = translate_magic(name[len(prefix) + 1 :], depth + 1)
        if rest:
            return f'{MAGIC_PREFIXES[prefix]} {rest}'
    return None


def translate_magic(name, depth=0):
    """Bir buyulu esya adinin Turkcesi; cozulemezse None.

    Sirasiyla: birebir sozluk, "+N" oneki, parantezli niteleme, virgullu
    varyant, "X of Y" kalibi, duz govde. Ozyineleme [depth] ile sinirli --
    "Bag of Tricks, Gray" once virgulu, sonra kalibi cozer.
    """
    if depth > 3:
        return None
    if name in MAGIC_EXACT:
        return MAGIC_EXACT[name]
    if name in MAGIC_HEADS:
        return MAGIC_HEADS[name]
    if name in ITEMS:
        return ITEMS[name]

    match = _PLUS_PREFIX.match(name)
    if match:
        rest = translate_magic(match.group('rest'), depth + 1)
        return f'+{match.group("bonus")} {rest}' if rest else None

    match = _PLUS_SUFFIX.match(name)
    if match:
        rest = translate_magic(match.group('rest'), depth + 1)
        return f'{rest} +{match.group("bonus")}' if rest else None

    match = _PAREN.match(name)
    if match:
        head = translate_magic(match.group('head'), depth + 1)
        if head:
            note = match.group('note')
            # "+1" gibi sayisal notlar ve canavar ozel adlari ("Kraken")
            # oldugu gibi; cozulebilen sozcukler cevriliyor.
            note_tr = _note(note, depth)
            return f'{head} ({note_tr})'
        return None

    match = _COMMA.match(name)
    if match:
        head = translate_magic(match.group('head'), depth + 1)
        if head:
            return f'{head}, {_note(match.group("rest"), depth)}'
        return None

    return _of_pattern(name) or _prefix_pattern(name, depth)


def magic_item_names():
    """Paketteki buyulu esya adlari icin ceviri haritasi."""
    bundle = json.load(
        gzip.open('assets/data/magicitems.json.gz', 'rt', encoding='utf-8')
    )
    out = {}
    for row in bundle:
        translated = translate_magic(row['name'])
        if translated:
            out[row['name']] = translated
    return dict(sorted(out.items()))


def audit():
    """Cevirisi olmayan adlari sayar (elle gozden gecirmek icin)."""
    items = json.load(
        gzip.open('assets/data/items.json.gz', 'rt', encoding='utf-8')
    )
    magic = json.load(
        gzip.open('assets/data/magicitems.json.gz', 'rt', encoding='utf-8')
    )
    translated_items = item_names()
    translated_magic = magic_item_names()

    missing_items = sorted(
        row['name'] for row in items if row['name'] not in translated_items
    )
    missing_magic = sorted(
        row['name'] for row in magic if row['name'] not in translated_magic
    )
    unknown_keys = sorted(
        key
        for key in ITEMS
        if key not in {row['name'] for row in items}
        and key not in {row['name'] for row in magic}
    )
    return missing_items, missing_magic, unknown_keys


if __name__ == '__main__':
    missing_items, missing_magic, unknown = audit()
    print(f'esya: {len(missing_items)} eksik')
    for name in missing_items:
        print('  ', name)
    print(f'buyulu esya: {len(missing_magic)} eksik')
    for name in missing_magic[:40]:
        print('  ', name)
    print(f'pakette olmayan sozluk anahtari: {len(unknown)}')
    for name in unknown:
        print('  ', name)
