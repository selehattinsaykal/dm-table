import 'package:flutter/widgets.dart';

import '../app/app_settings.dart';
import '../net/protocol.dart' show decodeServerMsg;

/// Oyuncu panelinin metinleri (TR/EN). Panel ayri bir entrypoint oldugu ve
/// gen-l10n kullanmadigi icin metinler burada tutulur; secili dile gore
/// getter'lar iki dilden birini doner. Oyun terimleri (AC, DM, pp/gp/sp/cp,
/// buyu seviyeleri) iki dilde de ayni kalir.
///
/// Erisim: `PlayerL10n.of(context)` -- [PlayerL10nScope] agacin tepesinde
/// [PlayerApp] tarafindan saglanir ve dil degisince bagimlilar yeniden kurulur.
class PlayerL10n {
  const PlayerL10n(this.lang);

  final AppLang lang;
  bool get _en => lang == AppLang.en;

  static PlayerL10n of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlayerL10nScope>();
    return scope?.l10n ?? const PlayerL10n(AppLang.en);
  }

  // Marka / ortak.
  String get appTitle => 'DM Table';
  String get ok => _en ? 'OK' : 'Tamam';
  String get cancel => _en ? 'Cancel' : 'İptal';
  String get close => _en ? 'Close' : 'Kapat';
  String get save => _en ? 'Save' : 'Kaydet';
  String get delete => _en ? 'Delete' : 'Sil';
  String get rename => _en ? 'Rename' : 'Yeniden adlandır';
  String get back => _en ? 'Back' : 'Geri';
  String get send => _en ? 'Send' : 'Gönder';
  String get take => _en ? 'Take' : 'Al';
  String get accept => _en ? 'Accept' : 'Kabul et';
  String get decline => _en ? 'Decline' : 'Reddet';

  // Katilim / karakter secimi.
  String get yourName => _en ? 'Your name' : 'Adın';
  String get joinTable => _en ? 'Join the table' : 'Masaya katıl';
  String get join => _en ? 'Join' : 'Katıl';
  String get joinTagline => _en
      ? 'Your name is what the rest of the table will see.'
      : 'Adın masadaki herkese böyle görünecek.';
  String get nameRequired =>
      _en ? 'Enter a name to join.' : 'Katılmak için bir ad yaz.';
  String get noCharactersHint => _en
      ? 'Once the DM creates one, it will appear here.'
      : 'DM bir karakter oluşturunca burada görünecek.';
  String get noCharactersYet => _en
      ? "The DM hasn't created a character yet."
      : 'DM henüz karakter oluşturmamış.';
  String get chooseCharacter =>
      _en ? 'Choose your character' : 'Karakterini seç';

  // Karakter olusturma (oyuncu tarafi).
  String get createCharacter =>
      _en ? 'Create your character' : 'Kendi karakterini oluştur';
  String get characterName => _en ? 'Character name' : 'Karakter adı';
  String get species => _en ? 'Species' : 'Tür';
  String get background => _en ? 'Background' : 'Geçmiş';
  String get characterClass => _en ? 'Class' : 'Sınıf';
  String get abilityScores => _en ? 'Ability scores' : 'Yetenek puanları';
  String get methodPointBuy => _en ? 'Point buy' : 'Puan dağıtımı';
  String get methodStandardArray => _en ? 'Standard array' : 'Standart dizi';
  String get methodManual => _en ? 'Manual' : 'Elle gir';
  String pointsLeft(int n) => _en ? '$n points left' : 'Kalan puan: $n';
  String get originBonus =>
      _en ? 'Background bonus (3 points)' : 'Geçmiş bonusu (3 puan)';
  String get spreadTwoOne => _en ? '+2 / +1' : '+2 / +1';
  String get spreadOneOneOne => _en ? '+1 / +1 / +1' : '+1 / +1 / +1';
  String originRemaining(int n) =>
      _en ? 'Points left: $n' : 'Dağıtılacak puan: $n';
  String chooseSkills(int n) => _en ? 'Choose $n skills' : '$n beceri seç';
  String get startingGear => _en ? 'Starting equipment' : 'Başlangıç ekipmanı';
  String get addPortrait => _en ? 'Add portrait' : 'Portre ekle';
  String get changePortrait => _en ? 'Change portrait' : 'Portreyi değiştir';
  String get removePortrait => _en ? 'Remove' : 'Kaldır';

  // Ana sekmeler.
  String get tabCharacter => _en ? 'Character' : 'Karakter';
  String get tabCombat => _en ? 'Combat' : 'Savaş';
  String get tabMap => _en ? 'Map' : 'Harita';
  String get tabNotes => _en ? 'Notes' : 'Notlar';
  String get tabQuests => _en ? 'Quests' : 'Görevler';
  String get tabSettings => _en ? 'Settings' : 'Ayarlar';
  String get tabChat => _en ? 'Chat' : 'Sohbet';
  String get chatGeneral => _en ? 'General' : 'Genel';
  String get chatWhisper => _en ? 'Whisper' : 'Fısıltı';
  String get chatPlaceholder =>
      _en ? 'Type a message...' : 'Mesajınızı yazın...';
  String get chatTo => _en ? 'To:' : 'Kime:';
  String get chatDm => _en ? 'DM' : 'DM';

  /// Hedef seciciideki DM secenegi (yalnizca DM gorur).
  String get chatToDm => _en ? 'DM (private)' : 'DM (özel)';
  String get chatEmpty => _en
      ? 'No messages yet. Say something to the table.'
      : 'Henüz mesaj yok. Masaya bir şey söyle.';

  // Gorevler sekmesi.
  String get noQuests =>
      _en ? 'No quests right now.' : 'Şu an sana verilmiş görev yok.';
  String get questFallbackTitle => _en ? 'Quest' : 'Görev';
  String get questReward => _en ? 'Reward' : 'Ödül';
  String get questAccept => _en ? 'Accept' : 'Kabul et';
  String get questReject => _en ? 'Decline' : 'Reddet';
  String get questYouAccepted => _en ? 'You accepted' : 'Kabul ettin';
  String get questYouRejected => _en ? 'You declined' : 'Reddettin';
  String get questChangeAccept => _en ? 'Accept instead' : 'Kabul et';
  String get questChangeReject => _en ? 'Decline instead' : 'Reddet';

  // Oylamali gorev paylasimi.
  String get questVoteBanner => _en
      ? 'The party is voting on this quest.'
      : 'Bu görev için ekip oylaması yapılıyor.';
  String get questVoteYes => _en ? 'Vote yes' : 'Kabul oyu';
  String get questVoteNo => _en ? 'Vote no' : 'Ret oyu';
  String get questVotedYes => _en ? 'You voted yes' : 'Kabul oyu verdin';
  String get questVotedNo => _en ? 'You voted no' : 'Ret oyu verdin';
  String get questVoteWaiting =>
      _en ? 'waiting for the others' : 'diğerleri bekleniyor';
  String get questVotePassed => _en
      ? 'The vote passed — the party took the quest'
      : 'Oylama geçti — görev ekibe verildi';

  // Gorev bildirimi.
  String get questNewOffer => _en ? 'New quest' : 'Yeni görev';
  String get questOpenTab => _en ? 'Open' : 'Aç';

  // Gorev odul havuzu.
  String get questRewardReady => _en ? 'Reward ready' : 'Ödül hazır';
  String get questRewardShareHint => _en
      ? 'Shared pool — whoever takes an item first gets it.'
      : 'Ortak havuz — bir eşyayı ilk kim alırsa onun olur.';

  // Alt sekmeler.
  String get subGeneral => _en ? 'General' : 'Genel';
  String get subInventory => _en ? 'Inventory' : 'Envanter';

  // Bos durumlar.
  String get noCombat => _en ? 'No combat right now.' : 'Şu an bir savaş yok.';
  String get noMap => _en
      ? "The DM isn't showing a map right now."
      : 'DM şu an harita göstermiyor.';

  // Dinlenme.
  String get shortRestOpen =>
      _en ? 'Short rest — spend hit dice' : 'Kısa dinlenme — hit dice harca';
  String hitDiceLeft(int left, int total) => _en
      ? 'Hit dice: $left / $total left'
      : 'Hit dice: $total zarın $left tanesi duruyor';
  String get spendHitDie => _en ? 'Spend a hit die' : 'Bir hit die harca';
  String get hitPointsFull =>
      _en ? 'Your hit points are already full.' : 'Canın zaten dolu.';

  // Kurtarma istegi.
  String get savingThrow => _en ? 'Saving throw' : 'Kurtarma atışı';
  String get savingThrows => _en ? 'Saving throws' : 'Kurtarma atışları';
  String rollWithMod(String mod) => _en ? 'Roll ($mod)' : 'At ($mod)';

  // Ganimet.
  String get loot => _en ? 'Loot' : 'Ganimet';
  String get allTaken => _en ? 'All taken.' : 'Hepsi alındı.';

  // Harita hazinesi.
  String get treasure => _en ? 'Treasure' : 'Hazine';
  String get takeAll => _en ? 'Take all' : 'Tümünü al';
  String get treasureEmpty =>
      _en ? 'This treasure is empty.' : 'Bu hazine boş.';

  // Duyuru.
  String get dm => 'DM';
  String get handout => _en ? 'Handout' : 'Paylaşılan görsel';

  // Kimlik / hikaye.
  String levelN(int n) => _en ? 'Level $n' : 'Seviye $n';
  String get appearance => _en ? 'Appearance' : 'Görünüş';
  String get personality => _en ? 'Personality' : 'Kişilik';
  String get ideal => _en ? 'Ideal' : 'İdeal';
  String get bond => _en ? 'Bond' : 'Bağ';
  String get flaw => _en ? 'Flaw' : 'Kusur';
  String get storyLabel => _en ? 'Story' : 'Hikaye';
  String get noCharacterInfo => _en
      ? "The DM hasn't added character details yet."
      : 'DM henüz karakter bilgisi eklemedi.';
  String get languagesLabel => _en ? 'Languages: ' : 'Diller: ';

  // Buyuler.
  String get spells => _en ? 'Spells' : 'Büyüler';
  String get noSpellsYet =>
      _en ? "The DM hasn't added spells yet." : 'DM henüz büyü eklemedi.';
  String get spellSlots => _en ? 'Spell slots' : 'Büyü yuvaları';
  String slotLevel(int n) => _en ? 'Level $n' : '$n. seviye';

  // Harita.
  String get subLocations => _en ? 'Sub-locations' : 'Alt yerler';
  String get fullscreen => _en ? 'Fullscreen' : 'Tam ekran';
  String get noMapForPlace =>
      _en ? 'This place has no map.' : 'Bu yerin haritası yok.';
  String get mapLoading => _en ? 'Loading map…' : 'Harita yükleniyor…';
  String get mapFailed => _en ? 'Map failed to load' : 'Harita yüklenemedi';

  // Magaza.
  String get shelvesEmpty =>
      _en ? 'Nothing on the shelves.' : 'Rafta bir şey yok.';
  String get purchasesNeedApproval => _en
      ? 'Purchases require DM approval.'
      : 'Satın alımlar DM onayından geçer.';
  String get shopClosedMsg =>
      _en ? 'This shop is closed.' : 'Bu mağaza kapalı.';
  String pieces(int n) => _en ? '$n pcs' : '$n adet';

  // Envanter.
  String get inventory => _en ? 'Inventory' : 'Envanter';
  String get sendMoney => _en ? 'Send money' : 'Para gönder';
  String get cantSendMoney => _en ? "Can't send money" : 'Para gönderilemez';
  String get bagEmpty => _en ? 'Your bag is empty.' : 'Çantan boş.';
  String get equip => _en ? 'Equip' : 'Kuşan';
  String get unequip => _en ? 'Unequip' : 'Çıkar';
  String get drop => _en ? 'Drop' : 'Bırak';
  String get noPlayerToSend =>
      _en ? 'No player to send to' : 'Gönderilecek oyuncu yok';

  // Ortak parti kesesi.
  String get partyPurses => _en ? 'Shared purses' : 'Ortak keseler';
  String get partyPurseEmpty => _en ? 'This purse is empty.' : 'Bu kese boş.';
  String get partyTake => _en ? 'Take' : 'Al';
  String get partyDeposit => _en ? 'Deposit' : 'Koy';
  String get partyDepositItem => _en ? 'Deposit item' : 'Eşya koy';
  String get partyDepositMoney => _en ? 'Deposit money' : 'Para koy';
  String get partyTakeMoney => _en ? 'Take money' : 'Para al';
  String get partyNothingToDeposit =>
      _en ? 'Nothing in your bag to deposit.' : 'Çantanda koyacak bir şey yok.';
  String get partyQuantity => _en ? 'Quantity' : 'Adet';

  // Uzmanliklar.
  String get weapons => _en ? 'Weapons' : 'Silahlar';
  String get armorProf => _en ? 'Armor' : 'Zırhlar';
  String get tools => _en ? 'Tools' : 'Aletler';
  String get proficiencies => _en ? 'Proficiencies' : 'Uzmanlıklar';

  // Statlar.
  String get initiative => _en ? 'Initiative' : 'İnisiyatif';
  String get proficiencyBonus => _en ? 'Proficiency' : 'Yeterlilik';
  String get passivePerception => _en ? 'Passive Perception' : 'Pasif Algı';
  String get damage => _en ? 'Damage' : 'Hasar';
  String get heal => _en ? 'Heal' : 'İyileş';

  // Olum kurtarma atislari (0 HP).
  String get deathSaves => _en ? 'Death saves' : 'Ölüm kurtarmaları';
  String get deathSaveRoll => _en ? 'Roll death save' : 'Ölüm kurtarması at';
  String get deathSaveSuccesses => _en ? 'Successes' : 'Başarılar';
  String get deathSaveFailures => _en ? 'Failures' : 'Başarısızlıklar';
  String get deathSaveStabilized => _en ? 'Stabilized' : 'Dengelendi';
  String get deathSaveDead => _en ? 'Dead' : 'Öldü';
  String get deathSaveLabel => _en ? 'Death save' : 'Ölüm kurtarması';
  String get skills => _en ? 'Skills' : 'Beceriler';
  String get statHint => _en
      ? 'Tap a stat: check • long-press: save'
      : 'Stat’a dokun: kontrol • uzun bas: kurtarma';
  String abilityCheck(String ability) =>
      _en ? '$ability check' : '$ability kontrolü';
  String abilitySave(String ability) =>
      _en ? '$ability save' : '$ability kurtarma';

  // Zar.
  String get diceLog => _en ? 'Dice log' : 'Zar günlüğü';
  String get rollDice => _en ? 'Roll dice' : 'Zar at';
  String get diceCount => _en ? 'Count' : 'Adet';
  String get diceMod => _en ? 'Mod' : 'Ek';
  String get dice => _en ? 'Dice' : 'Zar';
  String get critical => _en ? 'Critical!' : 'Kritik!';
  String get fumble => _en ? 'Failure!' : 'Başarısızlık!';

  // Savas.
  String get combatTitle => _en ? 'Combat' : 'Savaş';
  String roundN(int n) => _en ? 'Round $n' : '$n. tur';
  String get yourTurn => _en ? "It's your turn!" : 'Sıra sende!';
  String get yourInitiativeRoll =>
      _en ? 'Your initiative roll' : 'İnisiyatif atışın';
  String get rollInitiative => _en ? 'Roll initiative' : 'İnisiyatif at';

  // Kurtarma istegi ayrintilari.
  String saveRequestSubtitle(int dc, String ability) =>
      _en ? 'DC $dc · $ability save' : 'DC $dc · $ability kurtarması';
  String saveRequestLabel(String ability, int dc) =>
      _en ? '$ability save (DC $dc)' : '$ability kurtarma (DC $dc)';

  // Notlar.
  String get noNotesYet => _en ? 'No notes yet.' : 'Henüz not yok.';
  String get startByAddingHeading =>
      _en ? 'Start by adding a heading.' : 'Başlık ekleyerek başla.';
  String get newHeading => _en ? 'New heading' : 'Yeni başlık';
  String get untitled => _en ? 'Untitled' : 'Başlıksız';
  String get headingActions => _en ? 'Heading actions' : 'Başlık işlemleri';
  String get renameHeading =>
      _en ? 'Rename heading' : 'Başlığı yeniden adlandır';
  String get deleteHeading => _en ? 'Delete heading' : 'Başlığı sil';
  String deleteHeadingConfirm(String title) => _en
      ? 'Delete “$title” and its notes?'
      : '“$title” ve altındaki notlar silinsin mi?';
  String get noNotes => _en ? 'No notes.' : 'Not yok.';
  String get newNote => _en ? 'New note' : 'Yeni not';
  String get emptyNote => _en ? 'Empty note' : 'Boş not';
  String get editNote => _en ? 'Edit note' : 'Notu düzenle';

  // Notlar = kitaplar.
  String get newBook => _en ? 'New book' : 'Yeni kitap';
  String get renameBook => _en ? 'Rename book' : 'Kitabı yeniden adlandır';
  String get deleteBook => _en ? 'Delete book' : 'Kitabı sil';
  String deleteBookConfirm(String title) => _en
      ? 'Delete “$title” and all its pages?'
      : '“$title” ve tüm sayfaları silinsin mi?';
  String get bookActions => _en ? 'Book actions' : 'Kitap işlemleri';
  String get untitledBook => _en ? 'Untitled book' : 'Adsız kitap';
  String get emptyBookshelf => _en ? 'No books yet.' : 'Henüz kitap yok.';
  String get startByAddingBook =>
      _en ? 'Create your first book of notes.' : 'İlk not kitabını oluştur.';
  String get bookNameLabel => _en ? 'Book name' : 'Kitap adı';
  String pageCount(int n) => _en ? '$n page(s)' : '$n sayfa';
  String pageOf(int page, int total) =>
      _en ? 'Page $page / $total' : 'Sayfa $page / $total';
  String get addPage => _en ? 'Add page' : 'Sayfa ekle';
  String get deletePage => _en ? 'Delete page' : 'Sayfayı sil';
  String get writeHere => _en ? 'Write here…' : 'Buraya yaz…';
  String get pageFullHint =>
      _en ? 'Page full — press → to continue' : 'Sayfa doldu — → ile devam et';
  String get titleLabel => _en ? 'Title' : 'Başlık';
  String get noteBodyLabel => _en ? 'Note' : 'Not';

  // Gonderme / takas.
  String get transferTitle => _en ? 'Transfer' : 'Gönderi';
  String wantsToSend(String from, String what) => _en
      ? '$from wants to send you $what.'
      : '$from sana $what göndermek istiyor.';
  String sendTitle(String item) => _en ? 'Send: $item' : 'Gönder: $item';
  String get toWhom => _en ? 'To' : 'Kime';
  String get amount => _en ? 'Amount' : 'Miktar';
  String inPurse(String coins) => _en ? 'In purse: $coins' : 'Kesende: $coins';
  String get enterValidAmount =>
      _en ? 'Enter a valid amount.' : 'Geçerli bir miktar gir.';
  String get notEnoughMoney =>
      _en ? "You don't have enough money." : 'Yeterli paran yok.';
  String get sentAwaitingApproval =>
      _en ? 'Sent; awaiting approval.' : 'Gönderildi; onay bekleniyor.';

  // --- Sunucu mesajlari (kod -> cevrilmis metin) --------------------------
  // Sunucu hazir cumle yerine kod gonderir; burada secili dile cevrilir. DM'in
  // elle yazdigi serbest metin kodlu degildir ve oldugu gibi doner.

  String serverText(String s) {
    final decoded = decodeServerMsg(s);
    if (decoded == null) return s;
    return _serverMsg(decoded.code, decoded.args);
  }

  String _arg(List<String> a, int i) => i < a.length ? a[i] : '';

  String _serverMsg(String code, List<String> a) {
    switch (code) {
      // Genel istek hatalari.
      case 'needCharacter':
        return _en ? 'Choose a character first.' : 'Önce bir karakter seç.';
      case 'noShortRest':
        return _en
            ? 'There is no short rest right now.'
            : 'Şu an açık bir kısa dinlenme yok.';
      case 'claimedBy':
        return _en
            ? '${_arg(a, 0)} has already claimed this character.'
            : 'Bu karakteri ${_arg(a, 0)} almış.';
      case 'noActiveCombat':
        return _en ? 'There is no active combat.' : 'Aktif bir savaş yok.';
      case 'notInCombat':
        return _en
            ? "Your character isn't in this combat."
            : 'Karakterin bu savaşta değil.';
      case 'notDying':
        return _en
            ? "You're not down — no death save needed."
            : 'Serilmiş değilsin — ölüm kurtarması gerekmez.';
      case 'needName':
        return _en ? 'Give your character a name.' : 'Karakterine bir ad ver.';
      case 'needClass':
        return _en ? 'Choose a class.' : 'Bir sınıf seç.';
      case 'characterCreated':
        return _en
            ? '${_arg(a, 0)} created ${_arg(a, 1)}.'
            : '${_arg(a, 0)}, ${_arg(a, 1)} karakterini oluşturdu.';
      case 'itemNotSpecified':
        return _en ? 'No item specified.' : 'Eşya belirtilmedi.';
      case 'itemNotYours':
        return _en ? "This item isn't yours." : 'Bu eşya senin değil.';
      case 'noHitDiceLeft':
        return _en
            ? 'No hit dice left to spend.'
            : 'Harcanacak hit dice kalmadı.';
      case 'lootNotYours':
        return _en ? "This loot isn't for you." : 'Bu ganimet sana değil.';
      case 'itemGone':
        return _en ? 'This item is no longer here.' : 'Bu eşya artık yok.';
      case 'noMoneyLeft':
        return _en ? 'No money left.' : 'Para kalmadı.';
      case 'noInventory':
        return _en ? 'This purse no longer exists.' : 'Bu kese artık yok.';
      case 'noPin':
        return _en ? 'This treasure is already gone.' : 'Bu hazine artık yok.';
      case 'noLoot':
        return _en ? "There's no loot here." : 'Burada ganimet yok.';
      case 'pickSomethingToSend':
        return _en ? 'Choose something to send.' : 'Gönderilecek bir şey seç.';
      case 'recipientNotSpecified':
        return _en ? 'No recipient specified.' : 'Alıcı belirtilmedi.';
      case 'cantSendToSelf':
        return _en ? "You can't send to yourself." : 'Kendine gönderemezsin.';
      case 'recipientNotAtTable':
        return _en
            ? "The recipient isn't at the table."
            : 'Alıcı oyuncu masada değil.';
      case 'characterNotFound':
        return _en ? 'Character not found.' : 'Karakter bulunamadı.';
      case 'notEnoughMoney':
        return _en ? "You don't have enough money." : 'Yeterli paran yok.';
      case 'offerNotForYou':
        return _en ? "This offer isn't for you." : 'Bu teklif sana değil.';
      case 'noShopOpen':
        return _en
            ? 'No shop is open right now.'
            : 'Şu anda açık bir mağaza yok.';
      case 'itemNotFound':
        return _en ? 'Item not found.' : 'Eşya bulunamadı.';
      case 'alreadyPending':
        return _en
            ? 'This request is already awaiting DM approval.'
            : 'Bu istek zaten DM onayında.';
      case 'mustJoinFirst':
        return _en
            ? 'You must join the session first.'
            : 'Önce oturuma katılmalısın.';
      // Satin alma hatalari.
      case 'invalidQuantity':
        return _en ? 'Invalid quantity.' : 'Geçersiz adet.';
      case 'shopNotFound':
        return _en ? 'Shop not found.' : 'Mağaza bulunamadı.';
      case 'shopClosed':
        return _en ? 'The shop is currently closed.' : 'Mağaza şu anda kapalı.';
      case 'soldOut':
        return _en ? 'This item is sold out.' : 'Bu eşya tükendi.';
      case 'onlyNLeft':
        return _en
            ? 'Only ${_arg(a, 0)} left in stock.'
            : 'Stokta yalnızca ${_arg(a, 0)} adet var.';
      case 'notEnoughGold':
        return _en
            ? 'Not enough gold: ${_arg(a, 0)} needed, you have ${_arg(a, 1)}.'
            : 'Paran yetmiyor: ${_arg(a, 0)} gerekiyor, ${_arg(a, 1)} var.';
      // Bildirimler (satin alma).
      case 'purchasePending':
        return _en
            ? 'Your request for ${_arg(a, 0)} is awaiting DM approval.'
            : '${_arg(a, 0)} isteğin DM onayında.';
      case 'purchaseBought':
        return _en
            ? '${_arg(a, 0)} bought ${_arg(a, 1)}.'
            : '${_arg(a, 0)} ${_arg(a, 1)} aldı.';
      case 'purchaseRejected':
        return _en
            ? 'Your request for ${_arg(a, 0)} was rejected.'
            : '${_arg(a, 0)} isteğin reddedildi.';
      // Gonderme/takas duyurulari.
      case 'transferAccepted':
        return _en
            ? '${_arg(a, 0)} accepted: ${_arg(a, 1)}'
            : '${_arg(a, 0)} kabul etti: ${_arg(a, 1)}';
      case 'transferDeclined':
        return _en
            ? '${_arg(a, 0)} declined your gift (${_arg(a, 1)}).'
            : '${_arg(a, 0)} gönderini geri çevirdi (${_arg(a, 1)}).';
      case 'transferUnavailable':
        return _en
            ? 'Transfer failed: ${_arg(a, 0)} is no longer available.'
            : 'Gönderim tamamlanamadı: ${_arg(a, 0)} artık uygun değil.';
      default:
        return code;
    }
  }

  /// Savasta canavarin kaba sagligi (sunucu kod gonderir).
  String healthLabel(String code) => switch (code) {
    'healthy' => _en ? 'Healthy' : 'Sağlam',
    'scratched' => _en ? 'Scratched' : 'Çizilmiş',
    'wounded' => _en ? 'Wounded' : 'Yaralı',
    'bloodied' => _en ? 'Bloodied' : 'Ağır yaralı',
    'defeated' => _en ? 'Defeated' : 'Yenildi',
    _ => code,
  };

  String get unknownItem => _en ? 'Unknown item' : 'Bilinmeyen eşya';

  // Ayarlar sekmesi.
  String get settingsLanguage => _en ? 'Language' : 'Dil';
  String get settingsTheme => _en ? 'Theme' : 'Tema';
  String get themeDark => _en ? 'Dark' : 'Koyu';
  String get themeLight => _en ? 'Light' : 'Açık';
  String get themeSystem => _en ? 'System' : 'Sistem';
}

/// [PlayerL10n]'i agaca yayan InheritedWidget. Dil degisince bagimlilar
/// yeniden kurulur.
class PlayerL10nScope extends InheritedWidget {
  const PlayerL10nScope({required this.l10n, required super.child, super.key});

  final PlayerL10n l10n;

  @override
  bool updateShouldNotify(PlayerL10nScope oldWidget) =>
      oldWidget.l10n.lang != l10n.lang;
}
