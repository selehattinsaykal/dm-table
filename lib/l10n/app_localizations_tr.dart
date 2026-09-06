// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class L10nTr extends L10n {
  L10nTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'DM Table';

  @override
  String get navCampaigns => 'Kampanyalar';

  @override
  String get navCompendium => 'Kütüphane';

  @override
  String get navCharacters => 'Karakterler';

  @override
  String get navCompendiumShort => 'Kitaplık';

  @override
  String get navCharactersShort => 'Karakter';

  @override
  String get navShopsShort => 'Mağaza';

  @override
  String get navCombat => 'Savaş';

  @override
  String get navWorld => 'Dünya';

  @override
  String get navShops => 'Mağazalar';

  @override
  String get navSession => 'Oturum';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get navLoot => 'Ganimet';

  @override
  String get navCodex => 'Kayıtlar';

  @override
  String get navMusic => 'Müzik';

  @override
  String get musicImport => 'Dosya ekle';

  @override
  String get fileTypeAudio => 'Ses';

  @override
  String get fileTypeImage => 'Görsel';

  @override
  String get fileTypeVideo => 'Video';

  @override
  String get musicNewPlaylist => 'Yeni liste';

  @override
  String get musicNewSubList => 'Yeni alt liste';

  @override
  String get musicRenamePlaylist => 'Listeyi yeniden adlandır';

  @override
  String get musicDeletePlaylistConfirm =>
      'Liste silinsin mi? Parçalar silinmez, listesiz duruma düşer.';

  @override
  String get musicRenameTrack => 'Parçayı yeniden adlandır';

  @override
  String get musicMoveTo => 'Listeye taşı';

  @override
  String get musicUnfiled => 'Listesiz';

  @override
  String get musicEmpty =>
      'Bu listede parça yok. Sağ alttaki düğmeyle ses dosyası ekle; dosyalar kampanya klasörüne kopyalanır ve yedeğe dahil olur.';

  @override
  String get musicPlay => 'Çal';

  @override
  String get musicPause => 'Duraklat';

  @override
  String get musicStop => 'Durdur';

  @override
  String get musicNext => 'Sonraki';

  @override
  String get musicPrevious => 'Önceki';

  @override
  String get musicLoopOff => 'Tekrar kapalı';

  @override
  String get musicLoopAll => 'Listeyi tekrarla';

  @override
  String get musicLoopOne => 'Tek parçayı tekrarla';

  @override
  String musicMissingFile(String title) {
    return '$title — dosya bulunamadı';
  }

  @override
  String get musicAddLink => 'Bağlantıdan ekle';

  @override
  String get musicLinkTitle => 'Bağlantıdan müzik ekle';

  @override
  String get musicLinkHint =>
      'YouTube bağlantısı yapıştır (veya yt-dlp\'nin desteklediği herhangi bir bağlantı)';

  @override
  String get musicLinkDownload => 'İndir';

  @override
  String get musicLinkNotice =>
      'YouTube bağlantısı yapıştırıp sesi kütüphanene indirebilirsin. yt-dlp\'nin desteklediği diğer siteler de çalışır.';

  @override
  String get musicSettings => 'Müzik ayarları';

  @override
  String get musicToolPurpose =>
      'YouTube ve yt-dlp\'nin desteklediği diğer sitelerden indirmek için gereklidir.';

  @override
  String get musicToolRecheck => 'Yeniden kontrol et';

  @override
  String get musicToolInstallAction => 'Kur';

  @override
  String get musicToolInstalled => 'Kurulu';

  @override
  String get musicToolNotInstalled => 'Kurulu değil';

  @override
  String get musicToolChecking => 'Kontrol ediliyor…';

  @override
  String musicToolDownloading(String percent) {
    return 'İndiriliyor: %$percent';
  }

  @override
  String get musicToolExtracting => 'Çıkarılıyor…';

  @override
  String get musicToolInstalling => 'Kuruluyor…';

  @override
  String musicToolError(String message) {
    return 'Hata: $message';
  }

  @override
  String get musicToolMissingHint =>
      'yt-dlp henüz kurulu değil, bağlantı indirilemez. Müzik ayarlarından kurabilirsin.';

  @override
  String get musicOpenSettings => 'Ayarları aç';

  @override
  String get musicLinkBad => 'Bu geçerli bir web bağlantısı değil.';

  @override
  String get musicToolMissing => 'İndirme araçları bulunamadı';

  @override
  String get musicToolInstall => 'Kurulum yönergeleri';

  @override
  String get musicDownloads => 'İndirmeler';

  @override
  String get musicDownloadClear => 'Bitenleri temizle';

  @override
  String get musicDownloadFailed => 'İndirme başarısız';

  @override
  String get musicForbidden =>
      'Erişim reddedildi (403). Bu genellikle korumalı ya da lisanslı içerik demektir; değilse araçların güncel olduğundan emin ol.';

  @override
  String get musicDownloadDone => 'Kütüphaneye eklendi';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get settingsPartialTranslation =>
      'Uygulamanın bazı bölümleri henüz yalnızca Türkçedir.';

  @override
  String get settingsAiTitle => 'Yapay Zekâ (opt-in)';

  @override
  String get settingsAiProvider => 'Sağlayıcı';

  @override
  String get settingsAiKey => 'API anahtarı';

  @override
  String get settingsAiModel => 'Model (isteğe bağlı)';

  @override
  String get settingsAiNote =>
      'Anahtarın yalnızca bu cihazda saklanır. Oyunculara/LAN\'a gitmez; kullanım kendi API kotandan düşer.';

  @override
  String get settingsAiSaved => 'Kaydedildi (bu cihazda)';

  @override
  String get settingsAiActive => 'Anahtar kayıtlı — AI araçları aktif';

  @override
  String get settingsAiInactive => 'Anahtar girilmedi — AI araçları kapalı';

  @override
  String get codexAiSetting => 'Han / tema (isteğe bağlı)';

  @override
  String get codexAiGenerate => 'Üret';

  @override
  String get codexAiInsert => 'Kayıtlar\'a ekle';

  @override
  String get codexAiCopy => 'Kopyala';

  @override
  String get codexAiCopied => 'Panoya kopyalandı';

  @override
  String get codexAiInserted => 'Kayıtlar\'a eklendi';

  @override
  String get codexAiNotConfigured =>
      'AI ayarlanmadı. Ayarlar\'dan API anahtarı gir.';

  @override
  String get codexAiErrAuth => 'Geçersiz API anahtarı.';

  @override
  String get codexAiErrRate =>
      'İstek sınırına ulaşıldı ya da bu model hesabının planında kullanılamıyor. Aşağıdaki ayrıntı hangisi olduğunu söyler.';

  @override
  String get codexAiErrNetwork => 'Ağ hatası. Bağlantını kontrol et.';

  @override
  String get codexAiErrRefused => 'Model bu isteği reddetti.';

  @override
  String get codexAiErrEmpty => 'Model metin döndürmedi.';

  @override
  String get codexAiErrGeneric => 'Üretilemedi. Tekrar dene.';

  @override
  String get navAiTools => 'AI Araçları';

  @override
  String get aiToolQuest => 'Görev Üretici';

  @override
  String get aiOpenSettings => 'Ayarlar\'ı aç';

  @override
  String get aiRegenerate => 'Yeniden üret';

  @override
  String get aiPickPage => 'Hangi sayfaya eklensin?';

  @override
  String get aiNoPages => 'Önce bir Kayıtlar sayfası oluştur.';

  @override
  String get aiQuestHeading => 'Görev';

  @override
  String get questPartySize => 'Ekip kişi sayısı';

  @override
  String get questPartyLevel => 'Ekip seviyesi';

  @override
  String get questDifficulty => 'Zorluk';

  @override
  String get questDiffVeryEasy => 'Çok Kolay';

  @override
  String get questDiffEasy => 'Kolay';

  @override
  String get questDiffMedium => 'Orta';

  @override
  String get questDiffHard => 'Zor';

  @override
  String get questDiffVeryHard => 'Çok Zor';

  @override
  String get questGiverNpc => 'Görevi veren NPC';

  @override
  String get questGiverNone => 'Yok (serbest)';

  @override
  String get questGiverHint =>
      'İsteğe bağlı — seçersen görev bu NPC\'ye bağlanır.';

  @override
  String get questTargetLocation => 'Hedef lokasyon';

  @override
  String get questTargetNone => 'Yok (serbest)';

  @override
  String get questTargetHint =>
      'İsteğe bağlı — seçersen görev bu lokasyona götürür.';

  @override
  String get npcDisposition => 'Partiye tutumu';

  @override
  String get npcDispAny => 'Serbest';

  @override
  String get npcDispFriendly => 'Dostane';

  @override
  String get npcDispNeutral => 'Kayıtsız';

  @override
  String get npcDispWary => 'Temkinli';

  @override
  String get npcDispHostile => 'Düşmanca';

  @override
  String get npcDispDeceptive => 'İkiyüzlü';

  @override
  String get npcImportance => 'Ağırlığı';

  @override
  String get npcImpWalkOn => 'Tek sahnelik';

  @override
  String get npcImpRecurring => 'Tekrar eden';

  @override
  String get npcImpMajor => 'Başrol';

  @override
  String get npcSectionVoice => 'Sesi ve tavrı';

  @override
  String get npcSectionMannerism => 'Tavrı';

  @override
  String get npcSectionWants => 'Şu an istediği';

  @override
  String get npcSectionFirstLine => 'Açılış repliği';

  @override
  String get npcFirstLineNote => 'Masada olduğu gibi okuyabilirsin';

  @override
  String get npcParseFailed =>
      'Model geçerli bir NPC döndürmedi — yanıt büyük olasılıkla yarıda kesildi. Yeniden dene.';

  @override
  String get encPanelBriefing => 'Brifing';

  @override
  String get encPanelBriefingEmpty =>
      'Bu karşılaşmanın brifingi boş. Kalem düğmesinden doldurabilir ya da AI karşılaşma üretecinden oluşturabilirsin.';

  @override
  String get encPanelLoot => 'Ganimet';

  @override
  String get encPanelLootEmpty =>
      'Bu savaştan ganimet tanımlı değil. + ile ekle.';

  @override
  String get encLootAdd => 'Eşya ekle';

  @override
  String get encLootAddHint =>
      'Adı kütüphanede aranır; bulunursa eşya tam kaydıyla eklenir.';

  @override
  String get encLootCoins => 'Para';

  @override
  String get encLootNoCoins => 'Para yok — eklemek için dokun';

  @override
  String get encLootInLibrary => 'Kütüphanede var';

  @override
  String get encLootNotInLibrary => 'Kütüphanede yok — yalnızca isim';

  @override
  String encLootUnresolvedHint(int count) {
    return '$count eşya kütüphanede bulunamadı; keseye yalnızca isim olarak gider.';
  }

  @override
  String get encLootGrant => 'Ganimeti partiye ver';

  @override
  String get encLootGranted => 'Ganimet keseye aktarıldı';

  @override
  String get encLootNoInventory =>
      'Önce Ganimet sekmesinden bir parti kesesi oluştur.';

  @override
  String get encLootPickInventory => 'Hangi keseye?';

  @override
  String get encounterObjective => 'Kazanma koşulu';

  @override
  String get encObjAny => 'Serbest';

  @override
  String get encObjDefeat => 'Hepsini yen';

  @override
  String get encObjSurvive => 'Hayatta kal';

  @override
  String get encObjProtect => 'Koru';

  @override
  String get encObjRetrieve => 'Kap ve kaç';

  @override
  String get encObjEscape => 'Kaç';

  @override
  String get encObjStop => 'Durdur';

  @override
  String get encounterSetup => 'Kuruluş';

  @override
  String get encSetupAny => 'Serbest';

  @override
  String get encSetupAmbush => 'Pusuya düşerler';

  @override
  String get encSetupAmbushed => 'Pusu kurabilirler';

  @override
  String get encSetupPatrol => 'Devriye';

  @override
  String get encSetupLair => 'İn';

  @override
  String get encSetupGuard => 'Geçit tutan';

  @override
  String get encSetupNegotiable => 'Konuşmayla çözülebilir';

  @override
  String get encounterLocation => 'Geçtiği yer';

  @override
  String get encounterLocationHint => 'İsteğe bağlı — sahne bu yere oturtulur.';

  @override
  String get encounterObjectiveSection => 'Kazanma koşulu';

  @override
  String get encounterReinforcements => 'Takviye';

  @override
  String get encounterScaling => 'Zorluk ayarı';

  @override
  String get encounterTreasure => 'Ganimet';

  @override
  String get encounterParseFailed =>
      'Model geçerli bir karşılaşma döndürmedi — yanıt büyük olasılıkla yarıda kesildi. Yeniden dene.';

  @override
  String get questLinksSection => 'Bağlantılar';

  @override
  String get questGiverLocation => 'Görevin alındığı yer';

  @override
  String get questGiverLocationHint =>
      'İsteğe bağlı — görev burada teklif edilir (hedeften ayrı).';

  @override
  String get questAntagonist => 'Karşı taraf';

  @override
  String get questAntagonistHint => 'İsteğe bağlı — görevin karşısındaki NPC.';

  @override
  String get questFollowsUp => 'Devamı olduğu görev';

  @override
  String get questFollowsUpHint =>
      'İsteğe bağlı — seçersen bunun devamı yazılır.';

  @override
  String get questKind => 'Görev türü';

  @override
  String get questKindAny => 'Serbest';

  @override
  String get questKindRetrieve => 'Getir';

  @override
  String get questKindEliminate => 'Yok et';

  @override
  String get questKindEscort => 'Koru';

  @override
  String get questKindRescue => 'Kurtar';

  @override
  String get questKindInvestigate => 'Araştır';

  @override
  String get questKindDelivery => 'Ulaştır';

  @override
  String get questKindDefend => 'Savun';

  @override
  String get questKindExplore => 'Keşfet';

  @override
  String get questKindDiplomacy => 'Diplomasi';

  @override
  String get questKindHeist => 'Soygun';

  @override
  String get questScope => 'Kapsam';

  @override
  String get questScopeOneShot => 'Tek oturum';

  @override
  String get questScopeShortArc => 'Birkaç oturumluk';

  @override
  String get questScopeCampaign => 'Kampanya boyu süren';

  @override
  String get questTone => 'Ton';

  @override
  String get questToneAny => 'Serbest';

  @override
  String get questToneHeroic => 'Kahramanca';

  @override
  String get questToneMysterious => 'Gizemli';

  @override
  String get questToneGrim => 'Karanlık';

  @override
  String get questToneComedic => 'Mizahi';

  @override
  String get questToneGrey => 'Ahlaki gri';

  @override
  String get questUrgency => 'Süre baskısı';

  @override
  String get questUrgencyNone => 'Yok';

  @override
  String get questUrgencySoft => 'Gecikince kötüleşir';

  @override
  String get questUrgencyHard => 'Kesin süre';

  @override
  String get questDeadline => 'Süre';

  @override
  String get questUnitHours => 'saat';

  @override
  String get questUnitDays => 'gün';

  @override
  String get questUnitWeeks => 'hafta';

  @override
  String get questUnitMonths => 'ay';

  @override
  String get questParseFailed =>
      'Model geçerli bir görev döndürmedi — yanıt büyük olasılıkla yarıda kesildi. Kapsamı küçültüp yeniden dene.';

  @override
  String get questSectionQuest => 'Görev metni';

  @override
  String get questSectionReward => 'Ödül';

  @override
  String get questSectionHooks => 'Kancalar';

  @override
  String get questHooksNote => 'Parti ilkini yutmazsa diğerini kullan';

  @override
  String get questSectionStages => 'Aşamalar';

  @override
  String get questSectionComplications => 'Komplikasyonlar';

  @override
  String get questSectionFailure => 'Başarısız olurlarsa';

  @override
  String get questSectionKeyNpcs => 'Geçen karakterler';

  @override
  String get questSectionDm => 'Bilmem gereken açıklamalar';

  @override
  String get questDmOnly => 'Sadece sen görüyorsun — oyunculara gitmez';

  @override
  String get questCopyPlayer => 'Oyuncu metnini kopyala';

  @override
  String get questCopyAll => 'Tümünü kopyala';

  @override
  String get navQuests => 'Görevler';

  @override
  String get questsNew => 'Yeni görev';

  @override
  String get questsEmpty =>
      'Henüz görev yok. Sağ alttan ekle ya da AI Araçları\'ndan gönder.';

  @override
  String get questUntitled => '(başlıksız görev)';

  @override
  String get campaignDefaultName => 'Ana Kampanya';

  @override
  String get campaignExplainer =>
      'Her kampanya kendi veritabanı dosyasıdır: karakterler, dünya, görevler, kayıtlar ve takvim kampanyaya özeldir. Aynı anda tek kampanya açıktır.';

  @override
  String get campaignNew => 'Yeni kampanya';

  @override
  String get campaignNameLabel => 'Kampanya adı';

  @override
  String get campaignOpen => 'Aç';

  @override
  String get campaignRename => 'Yeniden adlandır';

  @override
  String get campaignActive => 'Açık kampanya';

  @override
  String get campaignInactive => 'Kapalı';

  @override
  String campaignDeleteTitle(String name) {
    return '$name silinsin mi?';
  }

  @override
  String get campaignDeleteBody =>
      'Bu kampanyanın karakterleri, dünyası, görevleri, kayıtları ve tüm görselleri kalıcı olarak silinir. Bu işlem geri alınamaz.';

  @override
  String get campaignDeleted => 'Kampanya silindi';

  @override
  String get campaignDeleteLater =>
      'Dosya şu an kullanımda; kampanya bir sonraki açılışta silinecek.';

  @override
  String get navCalendar => 'Takvim';

  @override
  String get calendarTabCalendar => 'Takvim';

  @override
  String get calendarTabChronicle => 'Tarihçe';

  @override
  String get calendarTabReminders => 'Hatırlatıcılar';

  @override
  String get reminderNew => 'Yeni hatırlatıcı';

  @override
  String get reminderEmpty =>
      'Henüz hatırlatıcı yok. İleriye dönük olayları buraya yaz; gün ilerledikçe sana hatırlatılır.';

  @override
  String get reminderTitle => 'Başlık';

  @override
  String get reminderBody => 'Not (isteğe bağlı)';

  @override
  String get reminderStart => 'Tarih';

  @override
  String get reminderRepeat => 'Tekrar';

  @override
  String get reminderRepeatOnce => 'Tek seferlik';

  @override
  String get reminderRepeatMonthly => 'Her ay';

  @override
  String get reminderRepeatYearly => 'Her yıl';

  @override
  String reminderRepeatEveryNDays(int n) {
    return 'Her $n günde bir';
  }

  @override
  String get reminderRepeatEveryNDaysShort => 'Her N günde';

  @override
  String get reminderEveryNDaysLabel => 'Kaç günde bir';

  @override
  String get reminderMonthlyHint =>
      'Ay o güne kadar sürmüyorsa hatırlatıcı ayın son gününe çekilir; atlanmaz.';

  @override
  String reminderNext(String date) {
    return 'sıradaki: $date';
  }

  @override
  String get reminderNoNext => 'sırada yok';

  @override
  String get reminderClose => 'Kapat';

  @override
  String get reminderReopen => 'Yeniden aç';

  @override
  String reminderFired(String titles) {
    return 'Hatırlatıcı: $titles';
  }

  @override
  String get calendarTabSettings => 'Takvim yapısı';

  @override
  String get calendarDefaultMonths =>
      'Karakış,Buzçözen,Tohumay,Yeşerme,Çiçekay,Günortası,Sıcakay,Harmanay,Bereket,Yaprakdökümü,Sisay,Uzunkaranlık';

  @override
  String get calendarDefaultWeekdays =>
      'Örsgün,Ocakgün,Sugün,Pazargün,Yolgün,Andgün,Dinlence';

  @override
  String get calendarDefaultSeasons => 'İlkbahar,Yaz,Sonbahar,Kış';

  @override
  String get calendarNoSeason => 'Mevsimsiz';

  @override
  String get calendarSetToday => 'Bugünü ayarla';

  @override
  String get calendarAdvanceDay => '+1 gün';

  @override
  String get calendarAdvanceWeek => '+1 hafta';

  @override
  String get calendarBackDay => '-1 gün';

  @override
  String get calendarGoToday => 'Bugüne dön';

  @override
  String get calendarYear => 'Yıl';

  @override
  String get calendarMonth => 'Ay';

  @override
  String get calendarDay => 'Gün';

  @override
  String get calendarNameLabel => 'Takvimin adı';

  @override
  String get calendarEraLabel => 'Çağ etiketi';

  @override
  String get calendarEraHint => 'Yılın yanına yazılır, ör. \"Üçüncü Çağ\".';

  @override
  String get calendarYearSuffix => 'Yıl kısaltması (Milat sonrası)';

  @override
  String get calendarYearSuffixHint =>
      'Ör. \"MS\" — 1492 MS. Yıl 0 ve sonrasında kullanılır.';

  @override
  String get calendarYearSuffixBefore => 'Yıl kısaltması (Milat öncesi)';

  @override
  String get calendarYearSuffixBeforeHint =>
      'Ör. \"MÖ\" — 50 MÖ. Negatif yıllarda kullanılır.';

  @override
  String get calendarYearEraAfter => 'Sonrası';

  @override
  String get calendarYearEraBefore => 'Öncesi';

  @override
  String get calendarMonths => 'Aylar';

  @override
  String get calendarAddMonth => 'Ay ekle';

  @override
  String get calendarMonthDays => 'gün';

  @override
  String get calendarWeekdays => 'Gün adları';

  @override
  String get calendarAddWeekday => 'Gün adı ekle';

  @override
  String get calendarWeekdaysHint =>
      'Haftanın kaç gün olduğunu bu liste belirler.';

  @override
  String get calendarSeasons => 'Mevsimler';

  @override
  String get calendarAddSeason => 'Mevsim ekle';

  @override
  String calendarSeasonRange(String start, String end) {
    return '$start — $end';
  }

  @override
  String get calendarSeasonStart => 'Başlangıç';

  @override
  String get calendarSeasonEnd => 'Bitiş';

  @override
  String get calendarSeasonWrapHint =>
      'Bitiş başlangıçtan önceyse mevsim yıl sonunu sarar (kış gibi).';

  @override
  String get calendarNoMonths =>
      'Henüz ay yok. Aşağıdan ekle ya da varsayılan takvimi yükle.';

  @override
  String get calendarSeedDefaults => 'Varsayılan takvimi yükle';

  @override
  String get chronicleEmpty =>
      'Henüz tarihçe kaydı yok. Dünyanın geçmişini buradan yaz.';

  @override
  String get chronicleNew => 'Yeni olay';

  @override
  String get chronicleEventTitle => 'Olay başlığı';

  @override
  String get chronicleBody => 'Ne oldu?';

  @override
  String get chronicleBodyHint =>
      'Kayıtlar\'daki gibi yazabilirsin: **kalın**, [[sayfa]], /r 2d6, /monster(...)';

  @override
  String get chronicleCategory => 'Kategori';

  @override
  String get chronicleCategoryHint => 'Serbest, ör. savaş / antlaşma / felaket';

  @override
  String get chronicleSecret => 'Gizli (yalnız sen bilirsin)';

  @override
  String get chronicleHasEnd => 'Süren olay (bitiş tarihi var)';

  @override
  String get chronicleEnd => 'Bitiş';

  @override
  String get chronicleKnownYearOnly => 'Yalnız yıl biliniyor';

  @override
  String get chronicleEras => 'Çağlar';

  @override
  String get chronicleNewEra => 'Yeni çağ';

  @override
  String get chronicleEraName => 'Çağın adı';

  @override
  String get chronicleEraStart => 'Başlangıç yılı';

  @override
  String get chronicleEraEnd => 'Bitiş yılı (boşsa sürüyor)';

  @override
  String get chronicleOngoing => 'sürüyor';

  @override
  String get chronicleNoEra => 'Çağsız';

  @override
  String get chronicleSearch => 'Tarihçede ara';

  @override
  String get chronicleDeleteConfirm => 'Bu olay kalıcı olarak silinsin mi?';

  @override
  String chronicleEventsOnDay(String date) {
    return '$date günü';
  }

  @override
  String get chronicleNoEventsOnDay => 'Bu gün için kayıt yok.';

  @override
  String get chronicleAddHere => 'Bu güne olay ekle';

  @override
  String get chronicleOnlySecret => 'Yalnız gizli olaylar';

  @override
  String get restPartyTitle => 'Parti molası';

  @override
  String get restPartyHint =>
      'Seçili karakterlere aynı anda mola verir; savaş listesindeki canlar da güncellenir.';

  @override
  String get restEveryone => 'Herkes';

  @override
  String get restShortOpenHint =>
      'Dinlenme oyunculara açıldı. Herkes kendi panelinden istediği kadar hit die harcar; sen yalnızca izliyorsun.';

  @override
  String get restShortFinish => 'Dinlenmeyi bitir';

  @override
  String get restShort => 'Kısa mola';

  @override
  String get restLong => 'Uzun mola';

  @override
  String restHitDiceLeft(int left, int total) {
    return '$left / $total hit dice';
  }

  @override
  String restLongConfirm(int count) {
    return '$count karakter uzun molaya çekilecek: can dolar, büyü yuvaları ve hit dice\'ın yarısı geri gelir, tükenmişlik 1 azalır.';
  }

  @override
  String get restAdvanceDay => 'Takvimde 1 gün ilerlet';

  @override
  String restLoggedLong(int count) {
    return 'Uzun mola ($count karakter)';
  }

  @override
  String get aiToolEncounter => 'Karşılaşma Üretici';

  @override
  String get encounterEnvironment => 'Ortam / tema (isteğe bağlı)';

  @override
  String get encounterEnvironmentHint =>
      'Ör. bataklık harabesi, buzul geçidi, liman deposu.';

  @override
  String encounterBudgetHint(int xp) {
    return 'Hedef canavar XP\'si: $xp';
  }

  @override
  String get encounterSummary => 'Sahne';

  @override
  String get encounterMonsters => 'Canavarlar';

  @override
  String get encounterTerrain => 'Arazi';

  @override
  String get encounterTactics => 'Taktikler';

  @override
  String get encounterCreate => 'Savaşa dönüştür';

  @override
  String get encounterFallbackName => 'Karşılaşma';

  @override
  String encounterCreated(String name) {
    return '$name savaş olarak oluşturuldu';
  }

  @override
  String encounterCreatedPartial(String name, String missing) {
    return '$name oluşturuldu — kütüphanede bulunamayanlar: $missing';
  }

  @override
  String get encounterNoCandidates =>
      'Bu seviye için kütüphanede uygun canavar bulunamadı.';

  @override
  String get questComplete => 'Tamamla';

  @override
  String get questReopen => 'Geri aç';

  @override
  String get questNoCharacters => 'Önce karakter oluştur.';

  @override
  String get questDelete => 'Görevi sil';

  @override
  String get questDeleteConfirm => 'Bu görev kalıcı olarak silinsin mi?';

  @override
  String get questEditTitle => 'Görev';

  @override
  String get questTitleLabel => 'Başlık';

  @override
  String get questTextLabel => 'Görev metni (oyunculara)';

  @override
  String get questTextHelper => 'Oyunculara gösterilen metin.';

  @override
  String get questRewardLabel => 'Ödül';

  @override
  String get questDmLabel => 'DM notu (yalnız sen)';

  @override
  String get questDmHelper => 'Oyunculara gitmez.';

  @override
  String get questSendToQuests => 'Görevlere gönder';

  @override
  String get questSavedToQuests => 'Görevler\'e eklendi';

  @override
  String get aiQuestRewardAuto =>
      'Görevlere gönderince bu para ve eşyalar görevin gerçek ödülü olur; görev tamamlanınca oyunculara ortak ganimet olarak açılır.';

  @override
  String get questRealReward => 'Gerçek ödül (eşya + para)';

  @override
  String get questRealRewardHint =>
      'Görevi tamamlayınca kabul eden oyunculara ortak ganimet olarak açılır. Bir eşyayı ilk kim alırsa onun olur; havuz boşalınca görev kapanır.';

  @override
  String get compendiumMonsters => 'Canavarlar';

  @override
  String get compendiumSpells => 'Büyüler';

  @override
  String get compendiumItems => 'Eşyalar';

  @override
  String get compendiumMagicItems => 'Büyülü Eşyalar';

  @override
  String get compendiumFeats => 'Feat\'ler';

  @override
  String get compendiumSpecies => 'Irklar';

  @override
  String get compendiumBackgrounds => 'Geçmişler';

  @override
  String get searchHint =>
      'Canavar, büyü, eşya, karakter, yer, görev, kayıt, parça…';

  @override
  String get filters => 'Filtreler';

  @override
  String get clearFilters => 'Filtreleri temizle';

  @override
  String get noResults => 'Sonuç bulunamadı';

  @override
  String get filterSchool => 'Okul';

  @override
  String get filterRarity => 'Nadirlik';

  @override
  String get filterConcentration => 'Konsantrasyon';

  @override
  String get filterRitual => 'Ritüel';

  @override
  String get filterAttunement => 'Uyum';

  @override
  String get sourcebookSrd => 'SRD 5.2';

  @override
  String get sourcebookPhb => 'Oyunculuk Elkitabı 2024';

  @override
  String get sourcebookMm => 'Canavarlar Elkitabı 2024';

  @override
  String get sourcebookEberron => 'Eberron: Forge of the Artificer';

  @override
  String get sourcebookRavenloft => 'Ravenloft: The Horrors Within';

  @override
  String get sourcebookFaerun => 'Forgotten Realms: Heroes of Faerûn';

  @override
  String get importTitle => 'İçerik hazırlanıyor';

  @override
  String get importSubtitle =>
      'Kural kitaplığı ilk kez kuruluyor, bu bir kez yapılır.';

  @override
  String importStepWriting(String table) {
    return 'Veritabanına yazılıyor: $table';
  }

  @override
  String get importFailed => 'İçerik kurulumu başarısız oldu';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get save => 'Kaydet';

  @override
  String get delete => 'Sil';

  @override
  String get edit => 'Düzenle';

  @override
  String get add => 'Ekle';

  @override
  String get close => 'Kapat';

  @override
  String get ok => 'Tamam';

  @override
  String get create => 'Oluştur';

  @override
  String get remove => 'Çıkar';

  @override
  String get licenseTitle => 'İçerik lisansları';

  @override
  String get licenseBody =>
      'Bu uygulamadaki kural içeriği System Reference Document 5.2 (CC-BY 4.0) ve Open5e üzerinden dağıtılan açık lisanslı setlerden alınmıştır. Kişisel kitaplığınızdan içe aktardığınız içerik yalnızca bu cihazda saklanır.';

  @override
  String get sheetTitleFallback => 'Karakter';

  @override
  String get sheetRollDice => 'Zar at';

  @override
  String get sheetLevelUp => 'Seviye atla';

  @override
  String get sheetClassCounters => 'Sınıf sayaçları';

  @override
  String get sheetFeatures => 'Yetenekler';

  @override
  String get sheetAddFeature => 'Yetenek ekle';

  @override
  String get sheetEditFeature => 'Yeteneği düzenle';

  @override
  String get sheetFeatureName => 'Ad';

  @override
  String get sheetFeatureDesc => 'Açıklama';

  @override
  String get sheetFeatureUses => 'Kullanım sınırı';

  @override
  String get sheetFeatureUsesHint =>
      'Boş bırakılırsa sınırsız, ör. dinlenme başına 1 kullanım için \"1\".';

  @override
  String get sheetFeatureCustom => 'Özel';

  @override
  String get sheetDeleteFeatureConfirm => 'Bu yetenek silinsin mi?';

  @override
  String get sheetDamage => 'Hasar';

  @override
  String get sheetHeal => 'İyileş';

  @override
  String get sheetGrantTempHp => 'Geçici can ver';

  @override
  String get sheetDeathSaves => 'Ölüm kurtarma atışları';

  @override
  String get sheetSuccess => 'Başarılı';

  @override
  String get sheetFailure => 'Başarısız';

  @override
  String get sheetInitiative => 'İnisiyatif';

  @override
  String get sheetSpeed => 'Hız';

  @override
  String get sheetProficiency => 'Yeterlilik';

  @override
  String get sheetPassivePerception => 'Pasif Algı';

  @override
  String get sheetCarry => 'Taşıma';

  @override
  String get sheetSavingThrows => 'Kurtarma atışları';

  @override
  String get sheetProficiencies => 'Yeterlilikler';

  @override
  String get sheetArmorTraining => 'Zırh eğitimi';

  @override
  String get sheetWeaponProficiencies => 'Silah yeterlilikleri';

  @override
  String get sheetToolProficiencies => 'Uzman olunan aletler';

  @override
  String get sheetLanguages => 'Bilinen diller';

  @override
  String get sheetWeaponMastery => 'Silah ustalıkları';

  @override
  String get sheetNoProficiencies => 'Yok';

  @override
  String get sheetAddProficiency => 'Ekle';

  @override
  String sheetProficiencyPending(int count) {
    return '$count seçim bekliyor';
  }

  @override
  String get sheetProficiencySourceHint =>
      'Sınıf, geçmiş ve feat\'lerden gelenler otomatik; elle eklediklerin korunur.';

  @override
  String get sheetPickTool => 'Alet seç';

  @override
  String get sheetPickLanguage => 'Dil seç';

  @override
  String get sheetPickWeapon => 'Silah seç';

  @override
  String get sheetArmorPenalty =>
      'Yeterliliğin olmayan zırh: Güç ve Çeviklik kontrolleriyle kurtarmalarında dezavantaj, büyü yapamazsın.';

  @override
  String get sheetShieldPenalty =>
      'Yeterliliğin olmayan kalkan: aynı ceza geçerli.';

  @override
  String get sheetSkills => 'Beceriler';

  @override
  String get sheetSpellSlots => 'Büyü yuvaları';

  @override
  String get sheetStatus => 'Durum';

  @override
  String get sheetInspiration => 'İlham (Inspiration)';

  @override
  String get sheetExhaustion => 'Tükenmişlik';

  @override
  String get sheetExperience => 'Deneyim (XP)';

  @override
  String sheetXpToNext(int nextLevel, int xpNeeded) {
    return 'Sonraki seviye (Sv $nextLevel) için $xpNeeded XP';
  }

  @override
  String sheetXpMaxLevel(int level) {
    return 'Azami seviye (Sv $level)';
  }

  @override
  String get sheetInventory => 'Envanter';

  @override
  String get sheetBagEmpty => 'Çanta boş.';

  @override
  String get sheetAddItem => 'Eşya ekle';

  @override
  String get sheetEquip => 'Giy/kuşan';

  @override
  String get sheetUnequip => 'Çıkar';

  @override
  String get sheetGear => 'Ekipman';

  @override
  String get sheetGearTab => 'Kuşanılan';

  @override
  String get sheetBagTab => 'Çanta';

  @override
  String get sheetSlotEmpty => 'Boş';

  @override
  String get sheetBagAllEquipped => 'Çantadaki her şey kuşanılmış.';

  @override
  String sheetSlotFull(String slot, int limit) {
    return '$slot yuvası dolu ($limit). Önce bir şey çıkar ya da sınırı artır.';
  }

  @override
  String sheetSlotLimit(String limit) {
    return 'Sınır: $limit';
  }

  @override
  String get sheetSlotUnlimited => 'Sınırsız';

  @override
  String get sheetSlotEditLimit => 'Yuva sınırını düzenle';

  @override
  String sheetSlotLimitTitle(String slot) {
    return '$slot sınırı';
  }

  @override
  String get sheetSlotLimitHint =>
      'Kaç tane kuşanılabilir? Sınırsız için sınırsızı seç.';

  @override
  String get sheetSlotDefault => 'Varsayılana dön';

  @override
  String get sheetSlotChange => 'Yuvayı değiştir';

  @override
  String get sheetSlotHead => 'Baş';

  @override
  String get sheetSlotArmor => 'Zırh';

  @override
  String get sheetSlotCloak => 'Pelerin';

  @override
  String get sheetSlotGloves => 'Eldiven';

  @override
  String get sheetSlotBoots => 'Ayakkabı';

  @override
  String get sheetSlotBelt => 'Kemer';

  @override
  String get sheetSlotAmulet => 'Kolye';

  @override
  String get sheetSlotRing => 'Yüzük';

  @override
  String get sheetSlotMainHand => 'Ana el';

  @override
  String get sheetSlotOffHand => 'Diğer el';

  @override
  String get sheetSlotOther => 'Diğer';

  @override
  String get sheetItemTab => 'Eşya';

  @override
  String get sheetMagicTab => 'Büyülü';

  @override
  String get sheetCustomTab => 'Serbest';

  @override
  String get sheetItemName => 'Eşya adı';

  @override
  String get sheetItemType => 'Eşya türü';

  @override
  String get sheetItemTypeAuto => 'Otomatik (addan tahmin et)';

  @override
  String get sheetPurse => 'Kese';

  @override
  String get sheetRest => 'Dinlen';

  @override
  String get sheetShortRest => 'Kısa dinlen (hit die)';

  @override
  String get sheetLongRest => 'Uzun dinlen (tam yenile)';

  @override
  String get sheetLongRestDone =>
      'Uzun dinlenildi: HP, yuvalar, hit dice yenilendi.';

  @override
  String get sheetNoHitDice => 'Harcanacak hit dice kalmadı.';

  @override
  String get sheetPortrait => 'Portre';

  @override
  String get sheetPortraitHint => 'Oyuncular karakter sekmesinde görür.';

  @override
  String get sheetUploadPhoto => 'Fotoğraf yükle';

  @override
  String get sheetChange => 'Değiştir';

  @override
  String get sheetRemove => 'Kaldır';

  @override
  String get sheetSpells => 'Büyüler';

  @override
  String get sheetAddSpell => 'Büyü ekle';

  @override
  String get sheetNoSpellsAdded => 'Henüz büyü eklenmedi.';

  @override
  String get sheetAlways => 'her zaman';

  @override
  String get sheetPrepared => 'Hazır';

  @override
  String get sheetPrepare => 'Hazırla';

  @override
  String get sheetSearchSpell => 'Büyü ara';

  @override
  String get sheetOnlyClassSpells => 'Yalnızca sınıfına uygun';

  @override
  String get sheetStory => 'Hikaye';

  @override
  String get sheetBackstory => 'Geçmiş / hikaye';

  @override
  String get sheetAppearance => 'Görünüş';

  @override
  String get sheetPersonality => 'Kişilik';

  @override
  String get sheetIdeal => 'İdeal';

  @override
  String get sheetBond => 'Bağ';

  @override
  String get sheetFlaw => 'Kusur';

  @override
  String get combatNewEncounter => 'Yeni karşılaşma';

  @override
  String get combatPreparing => 'Hazırlanıyor';

  @override
  String get combatEncounterName => 'Karşılaşma';

  @override
  String get combatNameLabel => 'Ad';

  @override
  String get combatCreate => 'Oluştur';

  @override
  String get combatEmpty => 'Karşılaşma yok';

  @override
  String get combatEmptyHint =>
      'Yeni bir karşılaşma kurup canavar ve oyuncuları ekle.';

  @override
  String get combatAddMonster => 'Canavar ekle';

  @override
  String get combatAddParty => 'Oyuncuları ekle';

  @override
  String get combatAddHint => 'Üstteki butonlardan canavar ve oyuncu ekle.';

  @override
  String get combatNeedCharacter => 'Önce karakter oluştur.';

  @override
  String get combatEditInitiative => 'İnisiyatifleri düzenle, sonra başlat';

  @override
  String get combatEnd => 'Bitir';

  @override
  String get combatNext => 'Sıradaki';

  @override
  String get combatStart => 'Başlat';

  @override
  String get combatConcentration => 'Konsantrasyon';

  @override
  String get combatStatBlock => 'Stat bloğu';

  @override
  String get combatEditConditions => 'Durum ekle/çıkar';

  @override
  String get combatStartConcentration => 'Konsantrasyon başlat';

  @override
  String get combatEndConcentration => 'Konsantrasyonu bitir';

  @override
  String get combatMarkDefeated => 'Yenildi işaretle';

  @override
  String get combatRevive => 'Geri getir';

  @override
  String get combatRemove => 'Çıkar';

  @override
  String get combatDamage => 'Hasar';

  @override
  String get combatHeal => 'İyileştir';

  @override
  String get combatSearchMonster => 'Canavar ara...';

  @override
  String get combatCount => 'Adet';

  @override
  String get combatRollHp => 'HP zar at';

  @override
  String combatRoundN(int n) {
    return '$n. tur';
  }

  @override
  String combatInitiativeTitle(String name) {
    return '$name — inisiyatif';
  }

  @override
  String combatConditionsTitle(String name) {
    return '$name — durumlar';
  }

  @override
  String combatConditionsExpired(String name, String conditions) {
    return '$name: $conditions sona erdi';
  }

  @override
  String get combatDurationRounds => 'Süre (tur)';

  @override
  String get combatDurationUnlimited => 'Süresiz';

  @override
  String get combatAttackRoll => 'Saldır';

  @override
  String get combatToHit => 'İsabet';

  @override
  String get combatCritical => 'Kritik';

  @override
  String get combatCriticalHit => 'Kritik!';

  @override
  String get combatAdvantage => 'Avantaj';

  @override
  String get combatDisadvantage => 'Dezavantaj';

  @override
  String get combatNormalRoll => 'Normal';

  @override
  String get combatDifficulty => 'Zorluk';

  @override
  String get combatDiffTrivial => 'Önemsiz';

  @override
  String get combatDiffLow => 'Kolay';

  @override
  String get combatDiffModerate => 'Orta';

  @override
  String get combatDiffHigh => 'Zor';

  @override
  String get combatDiffDeadly => 'Çok Zor';

  @override
  String get combatLegendaryActions => 'Efsanevi eylemler';

  @override
  String get combatLegendaryShort => 'Efsanevi';

  @override
  String get combatLegendaryResistShort => 'Direnç';

  @override
  String get combatLegendaryPerRound => 'Tur başına hak';

  @override
  String get combatLegendaryResetHint =>
      'Dokun = harca, uzun bas = sıfırla. Efsanevi eylemler canavarın turu başlayınca kendiliğinden tazelenir; direnç günlüktür.';

  @override
  String get combatLegendaryNone => 'Bu canavarın efsanevi eylemi yok.';

  @override
  String combatLegendaryCost(Object n) {
    return '$n hak';
  }

  @override
  String combatLegendaryTooltip(Object max, Object remaining) {
    return '$remaining/$max kaldı';
  }

  @override
  String get combatConditionLongPressHint =>
      'Dokun: süre · Uzun bas: kural metni';

  @override
  String get compendiumConditions => 'Durumlar';

  @override
  String get compendiumConditionsEmpty => 'Durum efektleri yüklenmedi.';

  @override
  String combatBudgetSummary(int xp, int low, int moderate, int high) {
    return '$xp XP · bütçe D$low / O$moderate / Y$high';
  }

  @override
  String combatUncounted(int count) {
    return '$count katılımcı XP’siz, hesaba katılmadı.';
  }

  @override
  String get combatAwardXp => 'XP ver';

  @override
  String get combatAwardXpNone => 'Verilecek canavar XP’si ya da oyuncu yok.';

  @override
  String combatAwardXpConfirm(int total, int players, int each) {
    return '$total XP, $players oyuncuya ($each’er) verilsin mi?';
  }

  @override
  String combatAwardXpDone(int each) {
    return 'XP verildi ($each’er).';
  }

  @override
  String logXpAwarded(int total, int players, int each) {
    return 'Karşılaşma XP’si: $total → $players oyuncu ($each’er)';
  }

  @override
  String get worldNpcs => 'NPC’ler';

  @override
  String get worldNewLocation => 'Yeni yer';

  @override
  String get worldAddChild => 'Alt yer ekle';

  @override
  String get worldRename => 'Yeniden adlandır';

  @override
  String get worldDeleteConfirmBody =>
      'Bu yer, altındaki tüm yerler, pinleri ve haritaları kalıcı olarak silinecek.';

  @override
  String get worldEmpty => 'Dünya boş';

  @override
  String get worldEmptyHint =>
      'Bir kıta ya da bölge ekleyip haritasını yükle. Harita üstüne koyduğun pinlerden alt yerlere girebilirsin.';

  @override
  String get worldNameLabel => 'Ad';

  @override
  String get worldParentLocation => 'Üst yer';

  @override
  String get worldBack => 'Geri';

  @override
  String get worldAddPin => 'Pin ekle';

  @override
  String get worldStopAddingPin => 'Pin eklemeyi bırak';

  @override
  String get worldUploadMap => 'Harita yükle';

  @override
  String get worldChangeMap => 'Haritayı değiştir';

  @override
  String get worldRemoveMap => 'Haritayı kaldır';

  @override
  String get worldDeleteLocation => 'Bu yeri sil';

  @override
  String get worldTapToPlacePin => 'Pin koymak için haritaya dokun.';

  @override
  String get worldPinDragHint =>
      'Düzenleme modu açık: pinleri sürükleyerek taşı, ayarları için uzun bas.';

  @override
  String get editModeOn => 'Düzenleme modu açık — kapatmak için dokun';

  @override
  String get editModeOff => 'Görüntüleme modu — düzenlemek için dokun';

  @override
  String get editModeEmptyRecord =>
      'Bu kayıt henüz boş. Doldurmak için düzenleme modunu aç.';

  @override
  String get editModeDiscard => 'Vazgeç';

  @override
  String get worldNoMap => 'Harita yok';

  @override
  String get worldNoMapHint =>
      'Haritayı yükledikten sonra üstüne pin koyabilir, pinlerden alt yerlere girebilirsin.';

  @override
  String get worldNoMapViewModeHint =>
      'Harita yüklemek için düzenleme modunu aç.';

  @override
  String get worldMapNotFound => 'Harita dosyası bulunamadı.';

  @override
  String get travelTitle => 'Seyahat';

  @override
  String get travelScaleTitle => 'Harita ölçeği';

  @override
  String get travelScaleHint =>
      'Haritanın gerçek dünyada kaç mil olduğunu gir. Pinler arası mesafe buradan hesaplanır.';

  @override
  String get travelWidthMiles => 'Genişlik (mil)';

  @override
  String get travelHeightMiles => 'Yükseklik (mil)';

  @override
  String get travelHeightAuto =>
      'Boş bırakılırsa haritanın en-boy oranından hesaplanır.';

  @override
  String get travelScaleMissing =>
      'Bu haritanın ölçeği girilmemiş. Mesafe hesaplamak için önce genişliği mil cinsinden gir.';

  @override
  String get travelScaleSet => 'Ölçeği gir';

  @override
  String get travelScaleClear => 'Ölçeği temizle';

  @override
  String get travelNoPins =>
      'Bu haritada pin yok. Rota kurmak için en az iki pin gerekli.';

  @override
  String get travelRoute => 'Rota';

  @override
  String get travelAddStop => 'Durak ekle';

  @override
  String get travelPickTwoStops => 'En az iki durak seç.';

  @override
  String get travelSpeed => 'Hız';

  @override
  String get travelGroupPaces => 'Yaya tempoları';

  @override
  String get travelGroupMounts => 'Binekler';

  @override
  String get travelGroupVehicles => 'Su araçları';

  @override
  String get travelCustomSpeed => 'Özel hız';

  @override
  String get travelMilesPerHour => 'Mil/saat';

  @override
  String get travelHoursPerDay => 'Günde kaç saat yol';

  @override
  String get travelExtraMiles => 'Ek mesafe (mil)';

  @override
  String get travelExtraMilesHint =>
      'Haritada karşılığı olmayan mesafe (ör. başka bir haritaya geçiş).';

  @override
  String travelTotalMiles(Object miles) {
    return 'Toplam $miles mil';
  }

  @override
  String travelDuration(Object days, Object hours) {
    return '$days gün $hours saat';
  }

  @override
  String travelDurationDaysOnly(Object days) {
    return '$days gün';
  }

  @override
  String travelAdvancesDays(Object days) {
    return 'Takvim $days gün ilerler';
  }

  @override
  String get travelConfirmTitle => 'Yolculuğu uygula';

  @override
  String travelConfirmBody(Object duration, Object miles, Object route) {
    return '$route\n\n$miles mil — $duration';
  }

  @override
  String travelAdvanceCalendar(Object days) {
    return 'Takvimi $days gün ilerlet';
  }

  @override
  String get travelPlanAction => 'Seyahat planla';

  @override
  String get travelDrawRoute => 'Haritada rota çiz';

  @override
  String get travelDrawRouteHint =>
      'Haritaya dokunarak durak ekle; bir pine dokunmak onu durak yapar. En az iki durak gerekir.';

  @override
  String travelDrawRouteStops(int count) {
    return '$count durak seçildi. “Planla” ile mesafe ve süreyi hesapla.';
  }

  @override
  String get travelRouteUndo => 'Son durağı sil';

  @override
  String get travelRoutePlan => 'Planla';

  @override
  String travelWaypoint(int index) {
    return 'Ara nokta $index';
  }

  @override
  String get journeyStart => 'Yolculuğa başla';

  @override
  String journeyStarted(String route, String miles) {
    return 'Yolculuk başladı: $route ($miles mil)';
  }

  @override
  String get journeyTitle => 'Yolculuk';

  @override
  String get journeyNone => 'Süren bir yolculuk yok.';

  @override
  String get journeyOpen => 'Yolculuğu aç';

  @override
  String get journeyTotal => 'Toplam yol';

  @override
  String get journeyTravelled => 'Gidilen';

  @override
  String get journeyRemaining => 'Kalan';

  @override
  String get journeyContinue => 'Devam et';

  @override
  String get journeyPause => 'İlerlemeyi durdur';

  @override
  String get journeyAbandon => 'Yolculuğu bitir';

  @override
  String get journeyAbandonConfirm =>
      'Yolculuk kapatılır. Şimdiye kadar gidilen yol ve takvimde geçen günler geri alınmaz.';

  @override
  String get journeyArrived => 'Hedefe varıldı.';

  @override
  String journeyArrivedLog(String route, String miles) {
    return 'Varış: $route ($miles mil)';
  }

  @override
  String get journeyEncounterTitle => 'Yolda bir şey oldu — parti durdu';

  @override
  String journeyDaysPassed(int days) {
    return 'Bu adımda $days gün geçti.';
  }

  @override
  String journeyBannerProgress(String travelled, String total) {
    return 'Yolculuk sürüyor — $travelled / $total mil';
  }

  @override
  String journeySpeedLine(String mph, String hours) {
    return '$mph mil/saat · günde $hours saat';
  }

  @override
  String get travelEncounters => 'Rastgele karşılaşma';

  @override
  String get travelEncountersHint =>
      'Yolculuğun her diliminde d20 atılır; eşiği tutturan atış için seçili tablodan bir satır çekilir. Sonuç yalnızca sana gösterilir.';

  @override
  String get travelEncounterTable => 'Karşılaşma tablosu';

  @override
  String get travelEncounterNoTables =>
      'Henüz rastgele tablo yok. Tablolar sekmesinden bir tane ekle.';

  @override
  String travelEncounterChance(int threshold, int percent) {
    return 'Eşik: d20 ≥ $threshold  (%$percent)';
  }

  @override
  String get travelEncounterChecks => 'Günlük kontrol sayısı';

  @override
  String travelEncounterWhen(int day, int check) {
    return '$day. gün · $check. kontrol';
  }

  @override
  String travelEncounterMissingRow(int roll) {
    return 'Tabloda $roll atışına karşılık gelen satır yok.';
  }

  @override
  String travelEncounterLogged(int day, String text) {
    return '$day. gün — karşılaşma: $text';
  }

  @override
  String get travelPaceFast => 'Hızlı';

  @override
  String get travelPaceNormal => 'Normal';

  @override
  String get travelPaceSlow => 'Yavaş';

  @override
  String get travelMountPony => 'Midilli';

  @override
  String get travelMountDraftHorse => 'Yük atı';

  @override
  String get travelMountMastiff => 'Mastiff';

  @override
  String get travelMountElephant => 'Fil';

  @override
  String get travelMountCamel => 'Deve';

  @override
  String get travelMountRidingHorse => 'Koşu atı';

  @override
  String get travelMountWarhorse => 'Savaş atı';

  @override
  String get travelVehicleRowboat => 'Kayık';

  @override
  String get travelVehicleKeelboat => 'Nehir teknesi';

  @override
  String get travelVehicleSailingShip => 'Yelkenli';

  @override
  String get travelVehicleWarship => 'Savaş gemisi';

  @override
  String get travelVehicleLongship => 'Uzungemi';

  @override
  String get travelVehicleGalley => 'Kadırga';

  @override
  String get worldNpcAdd => 'NPC ekle';

  @override
  String get worldNpcEmpty =>
      'Henüz NPC yok. Ekledikten sonra harita pinlerine bağlayabilirsin.';

  @override
  String get worldNpcNameLabel => 'Adı';

  @override
  String get worldNpcRoleLabel => 'Rolü';

  @override
  String get worldNpcNoLinks =>
      'Henüz bir haritaya bağlı değil. Bir yerin haritasında NPC pini ekleyerek bağlayabilirsin.';

  @override
  String get worldNpcAppearsIn => 'Geçtiği yerler';

  @override
  String get worldPinEdit => 'Pini düzenle';

  @override
  String get worldPinLabel => 'Etiket';

  @override
  String get worldPinLabelHint => 'ör. Yıkık kule';

  @override
  String get worldPinType => 'Tür';

  @override
  String get worldPinNote => 'Not';

  @override
  String get worldPinNoteHint =>
      'Sadece sen görürsün; pini açarsan oyuncular da.';

  @override
  String get worldKindLocation => 'Alt yer';

  @override
  String get worldKindPlace => 'Lokasyon';

  @override
  String get worldPinPlaceHint =>
      'Kendi haritası olmayan bir yer: içine girilmez ama lokasyon olarak kaydedilir ve görevlerde, seyahatte ve yer seçicilerinde görünür. Oyuncuların buradan öğreneceklerini aşağıya yaz.';

  @override
  String get worldKindNpc => 'NPC';

  @override
  String get worldKindShop => 'Mağaza';

  @override
  String get worldKindEncounter => 'Karşılaşma';

  @override
  String get worldKindTreasure => 'Hazine';

  @override
  String get worldKindTreasureLoot => 'Ganimet seti';

  @override
  String get worldKindTreasureLootHint =>
      'Oyuncular pine dokununca bu setten eşya/para alır. Set sonradan değiştirilemez.';

  @override
  String get worldKindTreasureLootNone => 'Serbest not (set yok)';

  @override
  String get worldTreasureNoLootSets =>
      'Henüz ganimet seti yok. Önce Loot sekmesinden oluştur.';

  @override
  String worldTreasureRemainingDetail(Object coins, Object items) {
    return 'Kalan ganimet: $items eşya, $coins cp';
  }

  @override
  String get worldTargetNoLocations =>
      'Bu yerin altında henüz başka bir yer yok. Menüden “Alt yer ekle” diyerek oluşturabilirsin.';

  @override
  String get worldTargetNoNpcs =>
      'Henüz NPC yok. Dünya ekranındaki NPC listesinden ekleyebilirsin.';

  @override
  String get worldTargetNoShops =>
      'Henüz mağaza yok. Mağazalar sekmesinden kur.';

  @override
  String get worldTargetNoEncounters =>
      'Henüz karşılaşma yok. Savaş sekmesinden oluştur.';

  @override
  String get worldTargetLink => 'Bağlanacak kayıt';

  @override
  String worldDeleteConfirmTitle(String name) {
    return '$name silinsin mi?';
  }

  @override
  String get sessionBackup => 'Yedekleme';

  @override
  String get sessionLogTitle => 'Oturum günlüğü';

  @override
  String get sessionLogAdd => 'Not ekle';

  @override
  String get sessionLogClear => 'Temizle';

  @override
  String get sessionLogClearConfirm => 'Tüm günlük kalıcı olarak silinsin mi?';

  @override
  String get sessionLogEmpty =>
      'Henüz kayıt yok. XP verildikçe ve not ekledikçe burada birikir.';

  @override
  String get codexNewPage => 'Yeni sayfa';

  @override
  String get codexUntitled => 'Başlıksız';

  @override
  String get codexAddSubpage => 'Alt sayfa ekle';

  @override
  String get codexRename => 'Yeniden adlandır';

  @override
  String get codexSetIcon => 'Simge (emoji)';

  @override
  String codexDeleteConfirm(String title) {
    return '“$title” ve tüm alt sayfaları silinsin mi?';
  }

  @override
  String get codexEmpty => 'Henüz sayfa yok';

  @override
  String get codexEmptyHint =>
      'İlk sayfanı oluştur; içine metin, liste, görsel, tablo, zar ve bağlantı blokları ekleyebilirsin.';

  @override
  String get codexDone => 'Bitti';

  @override
  String get codexAddBlock => 'Blok ekle';

  @override
  String get codexAddBlockHint => 'Aşağıdaki düğmeden blok ekle.';

  @override
  String get codexPageTitleEdit => 'Sayfa başlığı';

  @override
  String get codexPageEmpty => 'Bu sayfa boş.';

  @override
  String get codexAddItem => 'Madde ekle';

  @override
  String get codexBlockText => 'Metin';

  @override
  String get codexBlockHeading => 'Başlık';

  @override
  String get codexBlockBulleted => 'Madde listesi';

  @override
  String get codexBlockChecklist => 'Onay listesi';

  @override
  String get codexBlockCallout => 'Vurgu kutusu';

  @override
  String get codexBlockTable => 'Tablo';

  @override
  String get codexBlockChart => 'Grafik';

  @override
  String get codexBlockImage => 'Görsel';

  @override
  String get codexBlockVideo => 'Video';

  @override
  String get codexBlockLink => 'Bağlantı';

  @override
  String get codexVideoUpload => 'Video yükle';

  @override
  String get codexVideoSelected => 'Video seçildi';

  @override
  String get codexVideoMissing => 'Video dosyası bulunamadı';

  @override
  String get codexLinkUrl => 'Adres (URL)';

  @override
  String codexLinkFailed(Object url) {
    return '$url açılamadı';
  }

  @override
  String get codexChartTitle => 'Grafik başlığı';

  @override
  String get codexChartLabel => 'Etiket';

  @override
  String get codexChartValue => 'Değer';

  @override
  String get codexSearchHint => 'Kayıtlarda ara...';

  @override
  String get codexBlockCharacter => 'Karakter kartı';

  @override
  String get codexCharacterMissing => 'Karakter bulunamadı';

  @override
  String codexCharacterLevel(int level) {
    return 'Seviye $level';
  }

  @override
  String get codexWikiMissingTitle => 'Sayfa yok';

  @override
  String codexWikiMissingBody(String title) {
    return '“$title” adlı sayfa yok. Oluşturulsun mu?';
  }

  @override
  String get codexWikiCreate => 'Oluştur';

  @override
  String codexRefNotFound(String name) {
    return '“$name” bulunamadı.';
  }

  @override
  String get codexTextHint =>
      '**kalın** · *italik* · `kod` · [[Sayfa]] · /r1d20 · /character(Ad) · /monster(Ad) · /spell(Ad) · /item(Ad) · /link(url)(kelime) · /page(Başlık)(kelime)';

  @override
  String get codexBlockDivider => 'Ayraç';

  @override
  String get codexBlockDice => 'Zar';

  @override
  String get codexBlockPageLink => 'Sayfa bağlantısı';

  @override
  String get codexBlockEntityLink => 'Öge bağlantısı';

  @override
  String get codexBadExpression => 'Geçersiz zar ifadesi (ör. 2d6+3).';

  @override
  String get codexDiceLabel => 'Etiket';

  @override
  String get codexDiceExpression => 'Zar ifadesi';

  @override
  String get codexTableHeader => 'Başlık satırı';

  @override
  String get codexTableAddRow => 'Satır';

  @override
  String get codexTableAddColumn => 'Sütun';

  @override
  String get codexTableRemoveColumn => 'Sütun sil';

  @override
  String get codexImageCaption => 'Açıklama (isteğe bağlı)';

  @override
  String get codexLinkTargetPage => 'Hedef sayfa';

  @override
  String get codexAppearance => 'Görünüm';

  @override
  String get codexWidth => 'Genişlik';

  @override
  String get codexAlign => 'Hizalama';

  @override
  String get codexAlignLeft => 'Sol';

  @override
  String get codexAlignCenter => 'Orta';

  @override
  String get codexAlignRight => 'Sağ';

  @override
  String get codexHeight => 'Yükseklik';

  @override
  String get codexHeightAuto => 'Otomatik';

  @override
  String get codexResizeHint =>
      'İpucu: düzenleme modunda blokların kenarlarından sürükleyerek boyutlandırabilirsin.';

  @override
  String get codexResetSize => 'Boyutu sıfırla';

  @override
  String get codexDuplicate => 'Çoğalt';

  @override
  String get codexMoveUp => 'Yukarı taşı';

  @override
  String get codexMoveDown => 'Aşağı taşı';

  @override
  String get codexBlockSearch => 'Blok ara';

  @override
  String get codexGroupText => 'Metin';

  @override
  String get codexGroupData => 'Veri';

  @override
  String get codexGroupMedia => 'Medya';

  @override
  String get codexGroupLinks => 'Bağlantılar';

  @override
  String get codexTextSize => 'Yazı boyutu';

  @override
  String get codexDropCap => 'Süslü ilk harf';

  @override
  String get codexTone => 'Ton';

  @override
  String get codexToneNeutral => 'Yalın';

  @override
  String get codexToneInfo => 'Bilgi';

  @override
  String get codexToneSuccess => 'Olumlu';

  @override
  String get codexToneWarning => 'Uyarı';

  @override
  String get codexToneDanger => 'Tehlike';

  @override
  String get codexToneArcane => 'Büyülü';

  @override
  String get codexToneGold => 'Altın';

  @override
  String get codexHeadingRule => 'Altına çizgi';

  @override
  String get codexListOrdered => 'Numaralı';

  @override
  String get codexListMarker => 'Madde işareti';

  @override
  String get codexListDense => 'Sık aralık';

  @override
  String get codexChecklistProgress => 'İlerleme çubuğu';

  @override
  String get codexChecklistStrike => 'Yapılanın üstünü çiz';

  @override
  String codexChecklistDone(int done, int total) {
    return '$done/$total tamam';
  }

  @override
  String get codexCalloutBorder => 'Kenarlık';

  @override
  String get codexDividerStyle => 'Ayraç biçimi';

  @override
  String get codexDividerOrnament => 'Süslü';

  @override
  String get codexDividerLine => 'Çizgi';

  @override
  String get codexDividerDashed => 'Kesik';

  @override
  String get codexDividerThick => 'Kalın';

  @override
  String get codexDividerDots => 'Noktalar';

  @override
  String get codexDividerSpace => 'Boşluk';

  @override
  String get codexMediaFit => 'Doldurma';

  @override
  String get codexFitContain => 'Sığdır';

  @override
  String get codexFitCover => 'Kapla';

  @override
  String get codexFitFill => 'Ger';

  @override
  String get codexCornerRadius => 'Köşe yuvarlaklığı';

  @override
  String get codexMediaFrame => 'Çerçeve';

  @override
  String get codexImageFullscreen => 'Tam ekran';

  @override
  String get codexImageMissing => 'Görsel dosyası bulunamadı';

  @override
  String get codexVideoLoop => 'Döngü';

  @override
  String get codexVideoMuted => 'Sessiz';

  @override
  String get codexTableZebra => 'Şeritli satırlar';

  @override
  String get codexTableDense => 'Sık';

  @override
  String get codexTableBorders => 'Kenarlıklar';

  @override
  String get codexChartType => 'Grafik türü';

  @override
  String get codexChartBar => 'Yatay çubuk';

  @override
  String get codexChartColumn => 'Dikey sütun';

  @override
  String get codexChartLine => 'Çizgi';

  @override
  String get codexChartArea => 'Alan';

  @override
  String get codexChartPie => 'Pasta';

  @override
  String get codexChartDonut => 'Halka';

  @override
  String get codexChartRadar => 'Radar';

  @override
  String get codexChartStacked => 'Yığılmış';

  @override
  String get codexChartPalette => 'Renk paleti';

  @override
  String get codexPaletteTheme => 'Tema';

  @override
  String get codexPaletteBrass => 'Pirinç';

  @override
  String get codexPaletteJewel => 'Mücevher';

  @override
  String get codexPaletteEmber => 'Kor';

  @override
  String get codexPaletteForest => 'Orman';

  @override
  String get codexPaletteMono => 'Tek renk';

  @override
  String get codexChartShowValues => 'Değerler';

  @override
  String get codexChartShowGrid => 'Izgara';

  @override
  String get codexChartShowLegend => 'Açıklama';

  @override
  String get codexChartSort => 'Büyükten küçüğe sırala';

  @override
  String get codexChartEmpty => 'Henüz veri yok.';

  @override
  String get codexChartRadarHint => 'Radar en az üç öge ister.';

  @override
  String get codexBlockCounter => 'Sayaç';

  @override
  String get codexCounterEmpty => 'Sayaç yok.';

  @override
  String get codexCounterAdd => 'Sayaç ekle';

  @override
  String get codexCounterValue => 'Değer';

  @override
  String get codexCounterMin => 'En az';

  @override
  String get codexCounterMax => 'En çok';

  @override
  String get codexCounterStep => 'Adım';

  @override
  String get codexCounterStyle => 'Biçim';

  @override
  String get codexCounterStyleRow => 'Satır';

  @override
  String get codexCounterStyleTile => 'Kart';

  @override
  String get codexCounterStyleChip => 'Çip';

  @override
  String get codexCounterHint => 'Dokun: değer gir · Uzun bas: sıfırla';

  @override
  String get codexBlockTimer => 'Süre sayacı';

  @override
  String get codexTimerMode => 'Sayma yönü';

  @override
  String get codexTimerCountdown => 'Geri sayım';

  @override
  String get codexTimerStopwatch => 'Kronometre';

  @override
  String get codexTimerDuration => 'Süre';

  @override
  String get codexTimerMinutes => 'Dakika';

  @override
  String get codexTimerSeconds => 'Saniye';

  @override
  String get codexTimerStart => 'Başlat';

  @override
  String get codexTimerPause => 'Duraklat';

  @override
  String get codexTimerReset => 'Sıfırla';

  @override
  String get codexTimerAddMinute => 'Bir dakika ekle';

  @override
  String get codexTimerDone => 'Süre doldu.';

  @override
  String codexTimerFinished(String title) {
    return '“$title” süresi doldu.';
  }

  @override
  String get codexTimerOpen => 'Aç';

  @override
  String get codexTimerAlarm => 'Bitince uyar';

  @override
  String get codexTimerLoop => 'Bitince yeniden başlat';

  @override
  String get codexTimerStyleDigits => 'Rakam';

  @override
  String get codexTimerStyleBar => 'Çubuk';

  @override
  String get codexTimerStyleRing => 'Halka';

  @override
  String get codexTimerRunningHint =>
      'Sayaç sayfadan çıkınca da işlemeye devam eder.';

  @override
  String get codexChipStyle => 'Görünüm';

  @override
  String get codexChipStyleChip => 'Çip';

  @override
  String get codexChipStyleButton => 'Düğme';

  @override
  String get codexChipStyleCard => 'Kart';

  @override
  String get codexEmbedCompact => 'Kompakt';

  @override
  String get codexTitleOptional => 'Başlık (isteğe bağlı)';

  @override
  String get codexLinkLabel => 'Etiket (isteğe bağlı)';

  @override
  String get charactersTabParty => 'Parti';

  @override
  String get charactersTabSharedInventory => 'Ortak envanter';

  @override
  String get charactersNew => 'Yeni karakter';

  @override
  String get charactersDelete => 'Karakteri sil';

  @override
  String get charactersEmpty => 'Henüz karakter yok';

  @override
  String get charactersEmptyHint =>
      'Sağ alttaki butondan ilk karakteri oluştur.';

  @override
  String charactersDeleteConfirm(String name) {
    return '“$name” kalıcı olarak silinecek. Emin misin?';
  }

  @override
  String get compendiumCreateMonster => 'Canavar yarat';

  @override
  String get compendiumImportImages => 'Görsel içe aktar';

  @override
  String get compendiumImportHint =>
      'Bir klasör seç; dosya adları canavar adıyla eşleşen görseller (ör. Goblin.png) otomatik atanır. Yalnızca kendi görsellerin.';

  @override
  String get compendiumChooseFolder => 'Klasör seç';

  @override
  String get compendiumNoImagesFound => 'Klasörde görsel bulunamadı.';

  @override
  String compendiumImportResult(int assigned, int unmatched) {
    return '$assigned canavara görsel atandı, $unmatched dosya eşleşmedi.';
  }

  @override
  String get compendiumCreateSpell => 'Büyü yarat';

  @override
  String get compendiumCreateItem => 'Eşya yarat';

  @override
  String get compendiumCreateMagicItem => 'Büyülü eşya yarat';

  @override
  String get compendiumCrRange => 'Zorluk aralığı';

  @override
  String get compendiumPrice => 'Fiyat';

  @override
  String get compendiumWeight => 'Ağırlık';

  @override
  String get compendiumDamage => 'Hasar';

  @override
  String get compendiumProperties => 'Özellikler';

  @override
  String get compendiumStrengthReq => 'Güç şartı';

  @override
  String get compendiumStealth => 'Gizlilik';

  @override
  String get compendiumDisadvantage => 'Dezavantaj';

  @override
  String get compendiumAcPlusDex => ' + Çeviklik';

  @override
  String compendiumAcMaxDex(int max) {
    return ' (en fazla $max)';
  }

  @override
  String get compendiumSuggested => 'önerilen';

  @override
  String get compendiumMagicPriceHint =>
      'SRD büyülü eşyalar için fiyat yayınlamaz; bu değer nadirliğe göre önerilmiştir ve mağaza kurarken değiştirilebilir.';

  @override
  String get levelUpNoClass => 'Karakterin sınıfı yok.';

  @override
  String get levelUpNewClass => 'yeni sınıf';

  @override
  String get levelUpFeaturesGained => 'Kazanılan yetenekler';

  @override
  String get levelUpWhichClass => 'Hangi sınıfta ilerliyorsun?';

  @override
  String get levelUpHitPoints => 'Can puanı';

  @override
  String get levelUpSubclass => 'Alt sınıf';

  @override
  String get levelUpAddCustom => 'Kendim ekle';

  @override
  String get levelUpAbilityIncrease => 'Yetenek artışı';

  @override
  String get levelUpRoll => 'Zar at';

  @override
  String levelUpSaveAs(String className, int level) {
    return '$className $level olarak kaydet';
  }

  @override
  String levelUpHpHint(int sides, int avg) {
    return 'd$sides at ya da sabit $avg al. Bu değere ayrıca CON modifiern eklenir.';
  }

  @override
  String levelUpFixed(int avg) {
    return 'Sabit $avg';
  }

  @override
  String levelUpRolled(int n) {
    return 'Zar: $n';
  }

  @override
  String levelUpAbilityHint(int remaining) {
    return 'Bir yeteneğe +2 ya da iki yeteneğe +1. Kalan: $remaining';
  }

  @override
  String get lootNewSet => 'Yeni set';

  @override
  String get lootEmpty =>
      'Henüz ganimet seti yok. Eşya ve para içeren bir set hazırla, sonra masada tek dokunuşla oyunculara sun.';

  @override
  String get lootEmptyLabel => 'Boş';

  @override
  String get lootSetTitle => 'Ganimet seti';

  @override
  String get lootSetName => 'Set adı';

  @override
  String get lootMoney => 'Para';

  @override
  String get lootItems => 'Eşyalar';

  @override
  String get lootNoItems => 'Henüz eşya yok.';

  @override
  String get lootAddItem => 'Eşya ekle';

  @override
  String get lootMagic => 'Sihirli';

  @override
  String get lootAddFromCompendium => 'Katalogdan ekle';

  @override
  String lootItemCount(int count) {
    return '$count eşya';
  }

  @override
  String get lootUnknownItem => 'Bilinmeyen eşya';

  @override
  String get navTables => 'Tablolar';

  @override
  String get navTablesShort => 'Tablo';

  @override
  String get tablesTabTables => 'Tablolar';

  @override
  String get tablesTabNames => 'İsim Üreteci';

  @override
  String get tablesNew => 'Yeni tablo';

  @override
  String get tablesEmpty =>
      'Henüz tablo yok. Kendi tablonu kur (d4–d100), satırları gir, masada tek dokunuşla zar at.';

  @override
  String get tablesEditTitle => 'Tabloyu düzenle';

  @override
  String get tablesName => 'Tablo adı';

  @override
  String get tablesCategory => 'Kategori';

  @override
  String get tablesCategoryHint => 'ör. şehir, yol, ganimet';

  @override
  String get tablesDice => 'Zar';

  @override
  String get tablesRows => 'Satırlar';

  @override
  String get tablesAddRow => 'Satır ekle';

  @override
  String tablesRowCount(Object count) {
    return '$count satır';
  }

  @override
  String get tablesRoll => 'At';

  @override
  String get tablesRollAgain => 'Tekrar at';

  @override
  String get tablesNoRowForRoll =>
      'Bu sayıya denk gelen satır yok (tabloda boşluk var).';

  @override
  String get tablesRedistribute => 'Aralıkları dağıt';

  @override
  String tablesDeleteConfirm(Object name) {
    return '“$name” tablosu silinsin mi?';
  }

  @override
  String get tablesIssueGap =>
      'Zar yüzlerinin bir kısmı hiçbir satıra denk gelmiyor.';

  @override
  String get tablesIssueOverlap =>
      'Bazı sayılar birden fazla satır tarafından kapsanıyor.';

  @override
  String get tablesIssueOutOfRange =>
      'Bazı satırlar zar yüzünün dışına taşıyor.';

  @override
  String get tablesIssueEmptyRange =>
      'Bir satırın başlangıcı bitişinden büyük.';

  @override
  String get nameGeneratorHint =>
      'Tamamen çevrimdışı çalışır; hece ve kelimeleri birleştirir, aynı isim iki kez çıkmaz.';

  @override
  String get nameCount => 'Adet';

  @override
  String get nameGenerate => 'Üret';

  @override
  String get nameCopy => 'Kopyala';

  @override
  String nameCopied(Object name) {
    return '“$name” kopyalandı.';
  }

  @override
  String get nameSaveAsNpc => 'NPC olarak kaydet';

  @override
  String nameSavedAsNpc(Object name) {
    return '“$name” NPC olarak kaydedildi.';
  }

  @override
  String get nameSaveAsLocation => 'Yer olarak kaydet';

  @override
  String nameSavedAsLocation(String name) {
    return '“$name” yerlere eklendi.';
  }

  @override
  String get nameGender => 'Cinsiyet';

  @override
  String get nameGenderAny => 'Farketmez';

  @override
  String get nameGenderMale => 'Erkek';

  @override
  String get nameGenderFemale => 'Kadın';

  @override
  String get nameSurname => 'Soyad / lakap ekle';

  @override
  String get nameCategoryPerson => 'Kişi';

  @override
  String get nameCategoryPlace => 'Yer';

  @override
  String get nameCategoryEstablishment => 'İşletme';

  @override
  String get nameCategoryGroup => 'Topluluk';

  @override
  String get nameCategoryThing => 'Nesne';

  @override
  String get nameCultureHuman => 'İnsan';

  @override
  String get nameCultureHumanNorth => 'İnsan (kuzeyli)';

  @override
  String get nameCultureHumanDesert => 'İnsan (çöl)';

  @override
  String get nameCultureHumanEast => 'İnsan (doğulu)';

  @override
  String get nameCultureElf => 'Elf';

  @override
  String get nameCultureDrow => 'Kara elf';

  @override
  String get nameCultureDwarf => 'Cüce';

  @override
  String get nameCultureHalfling => 'Half-ling';

  @override
  String get nameCultureGnome => 'Gnom';

  @override
  String get nameCultureOrc => 'Ork';

  @override
  String get nameCultureGoblin => 'Goblin';

  @override
  String get nameCultureTiefling => 'Tiefling';

  @override
  String get nameCultureDragonborn => 'Ejderdoğan';

  @override
  String get nameCultureGoliath => 'Goliath';

  @override
  String get nameCultureLizardfolk => 'Kertenkele halkı';

  @override
  String get nameCultureTabaxi => 'Tabaxi';

  @override
  String get nameCultureCelestial => 'Semavi';

  @override
  String get nameCultureUndead => 'Hortlak';

  @override
  String get nameCulturePlace => 'Kasaba / köy';

  @override
  String get nameCultureCity => 'Şehir';

  @override
  String get nameCultureFortress => 'Kale';

  @override
  String get nameCultureRuin => 'Harabe';

  @override
  String get nameCultureForest => 'Orman';

  @override
  String get nameCultureMountain => 'Dağ';

  @override
  String get nameCultureWater => 'Nehir / göl';

  @override
  String get nameCultureIsland => 'Ada';

  @override
  String get nameCultureRegion => 'Bölge';

  @override
  String get nameCultureTavern => 'Meyhane';

  @override
  String get nameCultureShop => 'Dükkân';

  @override
  String get nameCultureTemple => 'Tapınak';

  @override
  String get nameCultureGuild => 'Lonca';

  @override
  String get nameCultureNobleHouse => 'Soylu hanedan';

  @override
  String get nameCultureMercenary => 'Paralı asker bölüğü';

  @override
  String get nameCultureCult => 'Tarikat';

  @override
  String get nameCultureShip => 'Gemi';

  @override
  String get nameCultureMagicItem => 'Büyülü eşya';

  @override
  String get nameCultureTome => 'Kitap / eser';

  @override
  String get nameCultureFestival => 'Bayram / şenlik';

  @override
  String get nameCultureEpithet => 'Unvan / lakap';

  @override
  String get aiToolTable => 'Tablo';

  @override
  String get aiTableTopic => 'Konu / tema';

  @override
  String get aiTableTopicHint =>
      'ör. bataklıkta rastgele olaylar, liman şehri söylentileri';

  @override
  String get aiTableRowCount => 'Madde sayısı';

  @override
  String get aiTableTone => 'Ton';

  @override
  String get aiTableToneGritty => 'Karanlık';

  @override
  String get aiTableToneHumorous => 'Mizahi';

  @override
  String get aiTableToneEpic => 'Destansı';

  @override
  String get aiTableToneMundane => 'Gündelik';

  @override
  String get aiTableContext => 'Ek bağlam (isteğe bağlı)';

  @override
  String get aiTableContextHint =>
      'Kampanyana özel ayrıntılar; maddeler buna göre kurgulanır.';

  @override
  String get aiTableSave => 'Tablolara kaydet';

  @override
  String get aiTableSaved => 'Kaydedildi';

  @override
  String aiTableSavedTo(Object name) {
    return '“$name” Tablolar\'a kaydedildi.';
  }

  @override
  String get partyInventoryTitle => 'Ortak kese';

  @override
  String get partyInventoryNew => 'Yeni kese';

  @override
  String get partyInventoryEmpty =>
      'Henüz ortak kese yok. Bir kese oluşturup üye oyuncuları seç; onlar da kendi panellerinden serbestçe eşya ve para alıp koyabilir.';

  @override
  String get partyInventoryName => 'Kese adı';

  @override
  String get partyInventoryMembers => 'Üyeler';

  @override
  String get partyInventoryMembersHint =>
      'Yalnızca seçtiğin oyuncular bu keseyi görür ve kullanabilir.';

  @override
  String get partyInventoryNoCharacters => 'Henüz karakter yok.';

  @override
  String partyInventoryMembersCount(Object count) {
    return '$count üye';
  }

  @override
  String get partyInventoryNoMembers => 'Üye yok';

  @override
  String get partyInventoryCoins => 'Para';

  @override
  String get partyInventoryItems => 'Eşyalar';

  @override
  String partyInventoryDeleteConfirm(Object name) {
    return '“$name” kesesi silinsin mi? İçindekiler de gider.';
  }

  @override
  String get shopsNew => 'Yeni mağaza';

  @override
  String get shopsOpen => 'Oyunculara açık';

  @override
  String get shopsClosed => 'Kapalı';

  @override
  String get shopsName => 'Mağaza adı';

  @override
  String get shopsNameHint => 'ör. Demirci';

  @override
  String get shopsOwner => 'İşleten (isteğe bağlı)';

  @override
  String get shopsOwnerHint =>
      'Serbest metin — ya da yukarıdan var olan bir NPC seç.';

  @override
  String get shopsOwnerNpc => 'İşleten NPC';

  @override
  String get shopsOwnerNpcNone => 'Yok (serbest ad)';

  @override
  String get shopsEmpty => 'Mağaza yok';

  @override
  String get shopsEmptyHint =>
      'Kütüphaneden eşya seçerek bir dükkân kur, sonra oyunculara aç.';

  @override
  String get formName => 'Adı';

  @override
  String get formDescription => 'Açıklama';

  @override
  String get formLevel => 'Seviye';

  @override
  String get formRange => 'Menzil';

  @override
  String get formDuration => 'Süre';

  @override
  String get formMaterial => 'Malzeme (M)';

  @override
  String get formClasses => 'Sınıflar';

  @override
  String get formClassesFailed => 'Sınıf listesi yüklenemedi.';

  @override
  String get formHigherLevel => 'Üst seviyede (opsiyonel)';

  @override
  String get spellHigherLevelSlot => 'Üst Seviye Büyü Yuvasıyla Kullanım. ';

  @override
  String get formCastingTime => 'Kullanım süresi';

  @override
  String get formCantrip => 'Ufak Büyü';

  @override
  String get formActionDescHint =>
      'Yakın Saldırı Zarı: +5, erişim 5 ft. 8 (1d10 + 3) delici hasar.';

  @override
  String get formCastingTimeHint => 'ör. 1 action';

  @override
  String get formRangeHint => 'ör. 60 feet';

  @override
  String get formDurationHint => 'ör. Instantaneous';

  @override
  String get formMaterialHint => 'ör. bir tutam kükürt';

  @override
  String get ccAddSpecies => 'Tür ekle';

  @override
  String get ccSpeciesName => 'Tür adı';

  @override
  String get ccSize => 'Boyut';

  @override
  String get ccSizeSmall => 'Küçük';

  @override
  String get ccSizeMedium => 'Orta';

  @override
  String get ccSizeLarge => 'Büyük';

  @override
  String get ccSpeed => 'Hız (feet)';

  @override
  String get ccTraits => 'Özellikler (serbest metin)';

  @override
  String get ccSubclassName => 'Alt sınıf adı';

  @override
  String get ccSubclassNameHint => 'ör. Battle Master';

  @override
  String get ccSubclassTraitsHint =>
      'Seviye seviye kazanılan yetenekleri buraya yazabilirsin.';

  @override
  String get ccAddBackground => 'Köken ekle';

  @override
  String get ccBackgroundName => 'Köken adı';

  @override
  String get ccToolProf => 'Alet yeterliliği (isteğe bağlı)';

  @override
  String get ccBackgroundFeat => 'Köken feat’i (isteğe bağlı)';

  @override
  String ccAddSubclass(String className) {
    return '$className alt sınıfı ekle';
  }

  @override
  String ccAbilities3(int count) {
    return 'Yetenekler — tam 3 tane ($count/3)';
  }

  @override
  String ccSkills2(int count) {
    return 'Beceriler — tam 2 tane ($count/2)';
  }

  @override
  String get ciMagicPrice => 'Fiyat (boş bırakılırsa nadirlikten önerilir)';

  @override
  String get ciAttunement => 'Attunement gerekir';

  @override
  String get ciFreeStock => 'Serbest satır';

  @override
  String get ciFreeStockHint =>
      'Yalnızca bu mağazada görünür, kütüphaneye kaydedilmez.';

  @override
  String get ciQuantity => 'Adet (-1 sınırsız)';

  @override
  String get mcType => 'Tip';

  @override
  String get mcArmorClass => 'Zırh sınıfı';

  @override
  String get mcSpeedFt => 'Hız (ft)';

  @override
  String get mcAbilityScores => 'Yetenek puanları';

  @override
  String get mcAttackPower => 'Saldırı gücü';

  @override
  String get mcAttackHint =>
      'CR tahmini için: bir turda ortalama kaç hasar verir ve isabet bonusu kaçtır?';

  @override
  String get mcDamagePerRound => 'Tur başına hasar';

  @override
  String get mcAttackBonus => 'İsabet bonusu';

  @override
  String get mcSaveToLibrary => 'Kütüphaneye kaydet';

  @override
  String get mcEstimatedCr => 'Tahmini zorluk';

  @override
  String get mcBenchmarkNote =>
      'Ölçütler SRD 5.2’deki 331 canavarın gerçek istatistiklerinden türetildi. Bu bir başlangıç noktası — özel yetenekler ve karşılaşma düzeni gerçek zorluğu değiştirir.';

  @override
  String get mcActions => 'Aksiyonlar';

  @override
  String get mcNoActions =>
      'Henüz aksiyon yok. Stat bloğunda görünecek saldırı ve yetenekleri buradan ekle.';

  @override
  String get mcAddAction => 'Aksiyon ekle';

  @override
  String get mcActionNameHint => 'ör. Bite';

  @override
  String mcCrBreakdown(String defensive, String offensive) {
    return 'Savunma CR $defensive · Saldırı CR $offensive';
  }

  @override
  String get seShortDesc => 'Kısa tanım (isteğe bağlı)';

  @override
  String get seFeaturesHint =>
      'Hangi seviyede ne kazanılıyor. Level atlarken bunlar kendiliğinden gelir ve karakter kâğıdında görünür.';

  @override
  String get seNoFeatures => 'Henüz yetenek eklenmedi.';

  @override
  String get seResources => 'Sayaçlar';

  @override
  String get seResourcesHint =>
      'Seviyeye göre büyüyen değerler: üstünlük zarı, ki puanı, kullanım hakkı… Karakter kâğıdında sayaç olarak görünür.';

  @override
  String get seNoResources => 'Sayaç yok. Çoğu alt sınıfta gerekmez.';

  @override
  String get seAddFeature => 'Yetenek ekle';

  @override
  String get seFeatureName => 'Yetenek adı';

  @override
  String get seFeatureNameHint => 'ör. Combat Superiority';

  @override
  String get seFeatureDesc => 'Ne yapar?';

  @override
  String get seAddResource => 'Sayaç ekle';

  @override
  String get seResourceName => 'Sayaç adı';

  @override
  String get seResourceNameHint => 'ör. Üstünlük Zarı';

  @override
  String get seResourceHint =>
      'Yalnızca değiştiği seviyeleri gir; aradakiler otomatik doldurulur.';

  @override
  String get seAddThreshold => 'Değişim noktası ekle';

  @override
  String get seThreshold => 'Değişim noktası';

  @override
  String get seValue => 'Değer';

  @override
  String get seValueHint => 'ör. 4  ya da  1d8';

  @override
  String seSubclassOf(String className) {
    return '$className alt sınıfı';
  }

  @override
  String seLevelArrow(int level, String value) {
    return '$level. sv → $value';
  }

  @override
  String get sdAddFromLibrary => 'Kütüphaneden ekle';

  @override
  String get sdCreateOwnItem => 'Kendi eşyanı yarat';

  @override
  String get sdCreateOwnMagic => 'Kendi büyülü eşyanı yarat';

  @override
  String get sdAddFreeLine => 'Serbest satır ekle';

  @override
  String get sdStockEmpty => 'Stok boş. Sağ üstteki butonlardan eşya ekle.';

  @override
  String get sdPriceMultiplier => 'Fiyat çarpanı';

  @override
  String get sdPriceMultiplierHint =>
      'Liste fiyatlarına uygulanır. Pazarlıkta düşür, ıssız kasabada yükselt.';

  @override
  String get sdClosed => 'Mağaza kapalı';

  @override
  String get sdClosedHint =>
      'Kapalıyken oyuncular mağazaya tıklayınca “mağaza kapalı” görür; eşyalar listelenmez ve satın alınamaz.';

  @override
  String get sdUnlimited => 'sınırsız';

  @override
  String get sdEditPrice => 'Fiyatı değiştir';

  @override
  String get sdEditQuantity => 'Adedi değiştir';

  @override
  String get sdMakeUnlimited => 'Sınırsız yap';

  @override
  String get sdRestock => 'Stok yenilemesi';

  @override
  String get sdRestockHint =>
      'Kaç oyun-içi günde bir stok tazelensin? Takvim ilerledikçe süresi dolan mağazalar kendiliğinden yenilenir.';

  @override
  String get sdRestockOff => 'Kapalı';

  @override
  String sdRestockEvery(int days) {
    return '$days günde bir';
  }

  @override
  String get sdRestockQty => 'Yenileme adedi';

  @override
  String sdRestockQtyTitle(String name) {
    return '$name — yenilemede kaç adet';
  }

  @override
  String get sdRestockQtyHint =>
      'Yenilemede adet bu değere döner. Ayarlamazsan bu satır hiç yenilenmez — tükenince biter.';

  @override
  String get sdRestockQtyClear => 'Bu satırı yenileme';

  @override
  String sdRestockQtyBadge(int count) {
    return 'yenileme: $count';
  }

  @override
  String shopRestocked(String shops) {
    return 'Stok yenilendi: $shops';
  }

  @override
  String sdOperator(String name) {
    return 'İşleten: $name';
  }

  @override
  String get sdOperatorNone => 'İşleten belirtilmedi';

  @override
  String get sdOpenOwnerNpc => 'NPC kartını aç';

  @override
  String sdPieces(int count) {
    return '$count adet';
  }

  @override
  String sdPriceTitle(String name) {
    return '$name — fiyat';
  }

  @override
  String sdQtyTitle(String name) {
    return '$name — adet';
  }

  @override
  String get cwStepIdentity => 'Kimlik ve tür';

  @override
  String get cwStepBackground => 'Köken (background)';

  @override
  String get cwStepClass => 'Sınıf';

  @override
  String get cwStepEquipment => 'Başlangıç eşyaları';

  @override
  String get cwStepSummary => 'Özet';

  @override
  String get cwNext => 'İleri';

  @override
  String get cwCreateCharacter => 'Karakteri oluştur';

  @override
  String get cwCharacterName => 'Karakter adı';

  @override
  String get cwPlayerName => 'Oyuncu adı (isteğe bağlı)';

  @override
  String get cwAddPhoto => 'Fotoğraf ekle';

  @override
  String get cwSpecies => 'Tür';

  @override
  String get cwChooseSize => 'Boyut seç';

  @override
  String get cwBackground => 'Köken';

  @override
  String get cwTool => 'Alet';

  @override
  String get cwBackgroundFeat => 'Köken feat’i';

  @override
  String get cwAbilityIncrease3 => 'Yetenek artışı (3 puan)';

  @override
  String get cwOriginPointsHint =>
      '2024 kurallarında köken 3 puan verir: ya bir yeteneğe +2 ve diğerine +1, ya da üçüne birer +1.';

  @override
  String get cwHitDie => 'Can zarı';

  @override
  String get cwWeapons => 'Silahlar';

  @override
  String get cwArmor => 'Zırh';

  @override
  String get cwTools => 'Aletler';

  @override
  String get cwSubclassLater =>
      'Alt sınıf 3. seviyede seçilir — seviye atlama akışında gelecek.';

  @override
  String get cwSelectionDone => 'Seçim tamam';

  @override
  String get cwChooseClassFirst => 'Önce sınıf seçin.';

  @override
  String get cwEquipmentHint =>
      'Sınıfın ve kökenin aynı harfli seçeneği birlikte alınır.';

  @override
  String get cwEquipmentNote =>
      'Seçtiğin eşyalar ve altın envantere otomatik eklenir; sonra karakter kağıdının envanter bölümünden düzenleyebilirsin.';

  @override
  String get cwUnnamed => 'İsimsiz';

  @override
  String get cwPointBuy => 'Puan dağıtımı';

  @override
  String get cwStandardArray => 'Standart dizi';

  @override
  String get cwManual => 'Elle gir';

  @override
  String get sheetUnknownItem => 'Bilinmeyen eşya';

  @override
  String cwPointsRemaining(int n) {
    return 'Kalan puan: $n';
  }

  @override
  String cwChooseMoreSkills(int n) {
    return 'Sınıfından $n beceri daha seç';
  }

  @override
  String cwFromBackground(String skills) {
    return 'Kökeninden zaten geliyor: $skills';
  }

  @override
  String cwOption(String label) {
    return 'Seçenek $label';
  }

  @override
  String cwBackgroundPrefix(String desc) {
    return 'Köken: $desc';
  }

  @override
  String get backupExport => 'Yedek al';

  @override
  String get backupExportHint =>
      'Karakterler, NPC\'ler, dünya, Kayıtlar, oyuncu notları, envanterler, görevler, oturum günlüğü ve kendi eklediğin içerik tek dosyaya yazılır. Görseller yol olarak değil, dosyanın kendisi olarak gömülür. Kural kütüphanesi (SRD) yedeğe girmez — uygulama onu zaten kendi içinde taşıyor.';

  @override
  String get backupCreateFile => 'Yedek dosyası oluştur';

  @override
  String get backupExportedHint =>
      'Bu dosyayı bilgisayara kopyala ya da buluta yükle; uygulamayı silersen cihazdaki kopya da gider.';

  @override
  String get backupRestore => 'Yedekten dön';

  @override
  String get backupRestoreHint =>
      'Şu anki karakterlerin, savaşların, mağazaların ve haritaların yedektekilerle DEĞİŞTİRİLİR. Yedekte olmayan kayıtlar silinir.';

  @override
  String get backupPickFile => 'Yedek dosyası seç';

  @override
  String get backupWillReplace => 'Mevcut verilerin bunlarla değiştirilecek.';

  @override
  String get backupRestoreButton => 'Geri yükle';

  @override
  String get backupRestored => 'Yedek geri yüklendi.';

  @override
  String get backupFileType => 'Yedek';

  @override
  String get backupLabelCharacters => 'Karakter';

  @override
  String get backupLabelEncounters => 'Karşılaşma';

  @override
  String get backupLabelCombatants => 'Savaşçı';

  @override
  String get backupLabelShops => 'Mağaza';

  @override
  String get backupLabelShopStock => 'Mağaza satırı';

  @override
  String get backupLabelLocations => 'Yer';

  @override
  String get backupLabelMapPins => 'Harita pini';

  @override
  String get backupLabelNpcs => 'NPC';

  @override
  String get backupLabelMonsters => 'Kendi canavarın';

  @override
  String get backupLabelItems => 'Kendi eşyan';

  @override
  String get backupLabelMagicItems => 'Kendi büyülü eşyan';

  @override
  String get backupLabelClasses => 'Kendi sınıf/alt sınıfın';

  @override
  String get backupLabelSpecies => 'Kendi türün';

  @override
  String get backupLabelBackgrounds => 'Kendi kökenin';

  @override
  String get backupLabelCodexPages => 'Kayıtlar sayfaları';

  @override
  String get backupLabelCodexBlocks => 'Kayıtlar blokları';

  @override
  String get backupLabelClassLevels => 'Sınıf seviyeleri';

  @override
  String get backupLabelProficiencies => 'Yeterlilikler';

  @override
  String get backupLabelInventory => 'Envanter';

  @override
  String get backupLabelCharacterSpells => 'Büyüler';

  @override
  String get backupLabelCharacterFeatures => 'Yetenekler';

  @override
  String get backupLabelPlayerNotes => 'Oyuncu notları';

  @override
  String get backupLabelLootSets => 'Ganimet setleri';

  @override
  String get backupLabelQuests => 'Görevler';

  @override
  String get backupLabelWorldLinks => 'Dünya bağları';

  @override
  String get backupLabelBondTypes => 'Bağ türleri';

  @override
  String get backupLabelFeats => 'Feat\'ler';

  @override
  String get backupLabelSessionLog => 'Oturum günlüğü';

  @override
  String backupExportedKb(int kb) {
    return 'Yedek alındı: $kb KB';
  }

  @override
  String backupExportFailed(String error) {
    return 'Yedek alınamadı: $error';
  }

  @override
  String backupReadFailed(String error) {
    return 'Bu dosya okunamadı: $error';
  }

  @override
  String backupDate(String date) {
    return 'Tarih: $date';
  }

  @override
  String backupMapFiles(int count) {
    return 'Harita dosyası: $count';
  }

  @override
  String backupPortraitFiles(int count) {
    return 'Portre dosyası: $count';
  }

  @override
  String backupMediaFiles(Object count) {
    return 'Kayıtlar videosu: $count';
  }

  @override
  String backupMusicFiles(int count) {
    return 'Müzik dosyası: $count';
  }

  @override
  String get backupImportAsCampaign => 'Yeni kampanya olarak içe aktar';

  @override
  String get backupImportAsCampaignHint =>
      'Yedeği ayrı bir kampanya olarak kurar; açık kampanyaya dokunmaz. Başkasının masasını yanına almak ya da eski bir kaydı saklamak için.';

  @override
  String get backupImportButton => 'İçe aktar';

  @override
  String backupImportedAsCampaign(String name) {
    return '“$name” kampanyası yedekten kuruldu.';
  }

  @override
  String get backupOpenImportedCampaign =>
      'Bu kampanyaya şimdi geçilsin mi? Açık masa kapanır ve oyunculara yeni bir katılma adresi gerekir.';

  @override
  String get backupLabelPartyInventories => 'Ortak keseler';

  @override
  String get backupLabelRandomTables => 'Rastgele tablolar';

  @override
  String get backupLabelJourneys => 'Yolculuklar';

  @override
  String get backupLabelCalendar => 'Takvim yapısı';

  @override
  String get backupLabelEras => 'Çağlar';

  @override
  String get backupLabelChronicle => 'Tarihçe olayları';

  @override
  String get backupLabelReminders => 'Hatırlatıcılar';

  @override
  String get backupLabelMusicPlaylists => 'Müzik listeleri';

  @override
  String get backupLabelMusicTracks => 'Müzik parçaları';

  @override
  String get backupLabelSpells => 'Büyüler';

  @override
  String backupRestoreFailed(String error) {
    return 'Geri yükleme başarısız: $error';
  }

  @override
  String sheetOrdinalLevel(int n) {
    return '$n. seviye';
  }

  @override
  String sheetAbilityCheck(String ability) {
    return '$ability kontrolü';
  }

  @override
  String sheetAbilitySave(String ability) {
    return '$ability kurtarma';
  }

  @override
  String get sheetHpLabel => 'HP';

  @override
  String sheetTempHp(int n) {
    return '+$n geçici';
  }

  @override
  String sheetPactMagic(int n) {
    return 'Pact Magic ($n. sv)';
  }

  @override
  String sheetExhaustionPenalty(int n) {
    return 'Tüm d20 testlerine $n ceza uygulanıyor.';
  }

  @override
  String sheetHitDieHealed(int n) {
    return '$n HP iyileşti (1 hit die).';
  }

  @override
  String get diceTitle => 'Zar';

  @override
  String get diceRollTitle => 'Zar at';

  @override
  String get diceCount => 'Adet';

  @override
  String get diceModifier => 'Ek';

  @override
  String get diceCritical => 'Kritik!';

  @override
  String get diceFumble => 'Başarısızlık!';

  @override
  String get navNpcs => 'NPC\'ler';

  @override
  String get aiToolNpcTab => 'NPC';

  @override
  String get npcProfession => 'Meslek';

  @override
  String get npcProfessionHint => 'demirci, meyhaneci, muhafız...';

  @override
  String get npcGender => 'Cinsiyet';

  @override
  String get npcGenderMale => 'Erkek';

  @override
  String get npcGenderFemale => 'Kadın';

  @override
  String get npcGenderOther => 'Diğer';

  @override
  String get npcGenderRandom => 'Rastgele';

  @override
  String get npcRace => 'Tür / ırk';

  @override
  String get npcRaceHint => 'insan, cüce, elf... (boş = serbest)';

  @override
  String get npcName => 'İsim (opsiyonel)';

  @override
  String get npcNameHint => 'boş bırakılırsa AI üretir';

  @override
  String get npcExtra => 'Ek bilgiler';

  @override
  String get npcExtraHint => 'kişilik, konum, olay örgüsüyle bağ, ton...';

  @override
  String get npcHeading => 'NPC';

  @override
  String get npcSectionAppearance => 'Görünüş';

  @override
  String get npcSectionPersonality => 'Kişilik';

  @override
  String get npcTraitIdeal => 'İdeal';

  @override
  String get npcTraitBond => 'Bağ';

  @override
  String get npcTraitFlaw => 'Kusur';

  @override
  String get npcSectionHook => 'Rol yapma kancası';

  @override
  String get npcSectionSecret => 'Sır (yalnızca DM)';

  @override
  String get npcSaveToNpcs => 'NPC\'lere kaydet';

  @override
  String get npcSavedToNpcs => 'NPC\'lere kaydedildi';

  @override
  String get worldGraphConnect => 'Bağla';

  @override
  String get worldGraphConnectHint =>
      'İki düğüme dokun → bağla · kenara dokun → menü';

  @override
  String get worldGraphChangeType => 'Tür değiştir';

  @override
  String get worldGraphDeleteLink => 'Bağı sil';

  @override
  String get worldGraphOpenLocation => 'Yeri aç';

  @override
  String get worldGraphSetSize => 'Küre boyutu';

  @override
  String get worldGraphSizeHint => 'Seçili kürenin görsel yarıçapını girin';

  @override
  String get worldGraphNodeRadiusLabel => 'Yarıçap';

  @override
  String get worldDeleteNpc => 'Bu NPC\'yi sil';

  @override
  String get bondRoad => 'Yol / Nötr';

  @override
  String get bondFriendship => 'Dostluk';

  @override
  String get bondEnmity => 'Düşmanlık';

  @override
  String get bondTrade => 'Ticaret';

  @override
  String get bondFamily => 'Aile';

  @override
  String get bondAlliance => 'Müttefik';

  @override
  String get bondRivalry => 'Rakip';

  @override
  String get bondLove => 'Aşk';

  @override
  String get bondVassalage => 'Tabiiyet';

  @override
  String get npcAge => 'Yaş';

  @override
  String get npcAlignment => 'Hizalama';

  @override
  String get npcAddPortrait => 'Portre ekle';

  @override
  String get npcChangePortrait => 'Portreyi değiştir';

  @override
  String get npcNotes => 'Notlar';

  @override
  String get npcSecretLabel => 'Sır (yalnızca DM)';

  @override
  String get bondSettingsTitle => 'Bağ türleri';

  @override
  String get bondNewType => 'Yeni tür';

  @override
  String get bondColorLabel => 'Renk';

  @override
  String get bondHexLabel => 'Hex';

  @override
  String get bondBrightness => 'Parlaklık';

  @override
  String get navMore => 'Daha fazla';

  @override
  String get navMoreTitle => 'Tüm bölümler';

  @override
  String get navGroupTable => 'Masada';

  @override
  String get navGroupWorld => 'Dünya & öykü';

  @override
  String get navGroupTools => 'Araçlar';

  @override
  String get stateErrorTitle => 'Bir şeyler ters gitti';

  @override
  String get stateErrorMessage =>
      'Bu bölüm yüklenemedi. Tekrar dene; sorun sürerse aşağıdaki teknik ayrıntı izini sürmeye yarar.';

  @override
  String get stateErrorDetail => 'Teknik ayrıntı';

  @override
  String get stateRetry => 'Tekrar dene';

  @override
  String get stateLoading => 'Yükleniyor…';

  @override
  String get npcBoundLocation => 'Bağlı olduğu yer';

  @override
  String get npcBoundLocationNone => 'Yer seçilmedi';

  @override
  String get npcBoundLocationHint =>
      'Seçersen NPC bu yere haritada bağlanır ve metni de buraya göre üretilir.';

  @override
  String get npcNoLocations =>
      'Henüz yer yok. Dünya sekmesinden ekleyebilirsin.';

  @override
  String get npcRelations => 'İlişkiler';

  @override
  String get npcRelationsHint =>
      'İstediğin kadar NPC ile bağ kurabilirsin; bağ türleri harita grafiğindekilerle aynı.';

  @override
  String get npcAddRelation => 'İlişki ekle';

  @override
  String get npcRemoveRelation => 'İlişkiyi kaldır';

  @override
  String get npcRelationPickNpc => 'NPC seç';

  @override
  String get npcNoOtherNpcs =>
      'Bağ kuracak başka NPC yok. Önce NPC\'ler sekmesinden ekle.';

  @override
  String get npcPortraitToggle => 'Portre üret';

  @override
  String get npcPortraitToggleHint =>
      'Açıkken üretilen karakterin görünüşüne, ırkına, yaşına ve mizacına göre portre çizilir.';

  @override
  String npcPortraitUnsupported(Object provider) {
    return '$provider görsel üretmiyor. Portre için Ayarlar\'dan Gemini ya da OpenAI seç.';
  }

  @override
  String get npcPortraitGenerating => 'Portre çiziliyor…';

  @override
  String npcPortraitFailed(Object reason) {
    return 'Portre üretilemedi: $reason';
  }

  @override
  String get npcPortraitRegenerate => 'Portreyi yeniden üret';

  @override
  String get npcPortraitTitle => 'Portre';

  @override
  String npcSavedWithLinks(Object count) {
    return 'NPC kaydedildi ($count bağ kuruldu).';
  }

  @override
  String get aiImageModel => 'Görsel modeli';

  @override
  String get aiImageModelHint =>
      'Portre üretimi için. Boş bırakırsan varsayılan kullanılır.';

  @override
  String get aiImageUnsupportedNote =>
      'Seçili sağlayıcı görsel üretmiyor; portre üretimi kapalı.';

  @override
  String get aiErrorDetail => 'Sağlayıcının yanıtı';

  @override
  String get codexAiErrNoImage => 'Bu sağlayıcı görsel üretmiyor.';

  @override
  String get sheetEdit => 'Düzenle';

  @override
  String get sheetProficiencyToggle => 'Yeterliliği değiştir';

  @override
  String get editCharacterTitle => 'Karakteri düzenle';

  @override
  String get editSave => 'Kaydet';

  @override
  String get editCancel => 'Vazgeç';

  @override
  String get editNone => 'Yok';

  @override
  String get editNameRequired => 'Ad boş olamaz';

  @override
  String get editSectionIdentity => 'Kimlik';

  @override
  String get editName => 'Ad';

  @override
  String get editPlayerName => 'Oyuncu';

  @override
  String get editAlignment => 'Hizalama';

  @override
  String get editSectionOrigin => 'Köken';

  @override
  String get editSpecies => 'Tür';

  @override
  String get editBackground => 'Geçmiş';

  @override
  String get editBackgroundHint =>
      'Geçmiş değişirse eski geçmişin verdiği beceriler kalkar, yenisininkiler eklenir.';

  @override
  String get editSectionAbilities => 'Yetenek puanları';

  @override
  String get editAbilityHint =>
      'Kağıttaki nihai puanlar. CON değişirse azami can her seviye için birlikte kayar.';

  @override
  String get editSectionVitals => 'Can ve değerler';

  @override
  String get editHitPointsMax => 'Azami can';

  @override
  String get editArmorClassOverride => 'AC';

  @override
  String get editSpeedOverride => 'Hız';

  @override
  String get editOverrideHint =>
      'AC ve hız boş bırakılırsa hesaplanan değer kullanılır.';

  @override
  String get editSectionClasses => 'Sınıflar';

  @override
  String get editClass => 'Sınıf';

  @override
  String get editSubclass => 'Alt sınıf';

  @override
  String get editLevel => 'Seviye';

  @override
  String get editClassChangeTitle => 'Sınıf değiştirilsin mi?';

  @override
  String editClassChangeBody(String from, String to) {
    return '$from yerine $to yazılacak. Seviye ve atılmış can zarları korunur; eski sınıfın ve alt sınıfın yetenekleri kağıttan silinip yeni sınıfınkiler işlenir.';
  }

  @override
  String get editClassChangeConfirm => 'Değiştir';

  @override
  String get editSaved => 'Karakter güncellendi';

  @override
  String sheetPreparedCount(int used, int limit) {
    return 'Hazır $used/$limit';
  }

  @override
  String sheetCantripCount(int used, int limit) {
    return 'Ufak Büyü $used/$limit';
  }

  @override
  String sheetSpellChangesLeft(int n) {
    return '$n değiştirme hakkı';
  }

  @override
  String get compendiumClasses => 'Sınıflar';

  @override
  String get compendiumClassTable => 'Sınıf tablosu';

  @override
  String get compendiumSubclasses => 'Alt sınıflar';

  @override
  String get compendiumFeatures => 'Yetenekler';

  @override
  String get compendiumLevel => 'Sv';

  @override
  String get compendiumFullCaster => 'Tam büyücü';

  @override
  String get compendiumHalfCaster => 'Yarı büyücü';

  @override
  String get compendiumThirdCaster => 'Üçte bir büyücü';

  @override
  String get compendiumPactCaster => 'Ahit Büyüsü';

  @override
  String compendiumSubclassOf(String className) {
    return '$className alt sınıfı';
  }

  @override
  String get sheetCastSpell => 'Büyüyü kullan';

  @override
  String get sheetCastAtLevel => 'Hangi yuvayla?';

  @override
  String get sheetNoSlotLeft => 'Uygun boş büyü yuvası yok.';

  @override
  String get sheetSpellAttack => 'Saldırı';

  @override
  String get sheetSpellDamage => 'Hasar';

  @override
  String get sheetSaveDc => 'kurtarma DC';

  @override
  String get sheetConcentrationNote => 'Konsantrasyon gerektirir';

  @override
  String get sheetSpellCastNoRoll => 'Yuva harcandı';

  @override
  String get levelUpAbilityOption => 'Yetenek puanı';

  @override
  String get levelUpFeatOption => 'Feat';

  @override
  String get levelUpFeatSearch => 'Feat ara';

  @override
  String get sheetAttune => 'Bağlan / bağı çöz';

  @override
  String sheetAttunedCount(int used, int limit) {
    return 'Bağlı eşya $used/$limit';
  }

  @override
  String sheetAttunementFull(int limit) {
    return 'En fazla $limit eşyaya bağlanabilirsin.';
  }

  @override
  String levelUpMulticlassBlocked(String requirements) {
    return 'Bu sınıfa geçmek için: $requirements';
  }

  @override
  String sheetConcentratingOn(String spell) {
    return 'Konsantrasyon: $spell';
  }

  @override
  String get sheetConcentrationHint =>
      'Hasar alınca CON kurtarması: DC 10 ya da hasarın yarısı (hangisi yüksekse).';

  @override
  String get sheetConcentrationEnd => 'Bitir';

  @override
  String get sheetAddClassOption => 'Sınıf seçeneği ekle';

  @override
  String get sheetAddClassOptionAction => 'Ekle';

  @override
  String get sheetNoClassOptions => 'Bu sınıfın seçilebilir bir özelliği yok.';

  @override
  String get statAc => 'AC';

  @override
  String get statHp => 'Can';

  @override
  String get statSpeed => 'Hız';

  @override
  String get statInitiative => 'İnisiyatif';

  @override
  String get statSavingThrows => 'Kurtarma Zarları';

  @override
  String get statSkills => 'Beceriler';

  @override
  String get statSenses => 'Duyular';

  @override
  String get statLanguages => 'Diller';

  @override
  String get statCr => 'CR';

  @override
  String get statDamageResistances => 'Hasar Dirençleri';

  @override
  String get statDamageImmunities => 'Hasar Bağışıklıkları';

  @override
  String get statDamageVulnerabilities => 'Hasar Zafiyetleri';

  @override
  String get statConditionImmunities => 'Durum Bağışıklıkları';

  @override
  String get statPassivePerception => 'Pasif Algı';

  @override
  String get statActions => 'Eylemler';

  @override
  String get statBonusActions => 'Bonus Eylemler';

  @override
  String get statReactions => 'Tepkiler';

  @override
  String get statLegendaryActions => 'Efsanevi Eylemler';

  @override
  String get statNoLanguages => '—';

  @override
  String get abilityStrength => 'Güç';

  @override
  String get abilityDexterity => 'Çeviklik';

  @override
  String get abilityConstitution => 'Dayanıklılık';

  @override
  String get abilityIntelligence => 'Zekâ';

  @override
  String get abilityWisdom => 'Bilgelik';

  @override
  String get abilityCharisma => 'Karizma';

  @override
  String get abilityShortStrength => 'GÜÇ';

  @override
  String get abilityShortDexterity => 'ÇEV';

  @override
  String get abilityShortConstitution => 'DAY';

  @override
  String get abilityShortIntelligence => 'ZEK';

  @override
  String get abilityShortWisdom => 'BİL';

  @override
  String get abilityShortCharisma => 'KAR';

  @override
  String get skillAcrobatics => 'Akrobasi';

  @override
  String get skillAnimalHandling => 'Hayvan Terbiyesi';

  @override
  String get skillArcana => 'Gizemli Bilgi';

  @override
  String get skillAthletics => 'Atletizm';

  @override
  String get skillDeception => 'Aldatma';

  @override
  String get skillHistory => 'Tarih';

  @override
  String get skillInsight => 'Sezgi';

  @override
  String get skillIntimidation => 'Yıldırma';

  @override
  String get skillInvestigation => 'Araştırma';

  @override
  String get skillMedicine => 'Tıp';

  @override
  String get skillNature => 'Doğa';

  @override
  String get skillPerception => 'Algı';

  @override
  String get skillPerformance => 'Sahne Sanatları';

  @override
  String get skillPersuasion => 'İkna';

  @override
  String get skillReligion => 'Din';

  @override
  String get skillSleightOfHand => 'El Çabukluğu';

  @override
  String get skillStealth => 'Gizlilik';

  @override
  String get skillSurvival => 'Hayatta Kalma';

  @override
  String get spellCantrip => 'Ufak Büyü';

  @override
  String get spellCantripAbbr => 'U';

  @override
  String spellLevelN(int level) {
    return '$level. Seviye';
  }

  @override
  String spellSchoolCantrip(String school) {
    return '$school ufak büyüsü';
  }

  @override
  String spellSchoolLevel(int level, String school) {
    return '$level. seviye $school';
  }

  @override
  String get spellRitualSuffix => ' (ritüel)';

  @override
  String get spellConcentrationPrefix => 'Konsantrasyon, ';

  @override
  String get spellConcentrationShort => 'Kons.';

  @override
  String get spellComponents => 'Bileşenler';

  @override
  String get spellClasses => 'Sınıflar';

  @override
  String get itemAttunementDetail => 'Uyum';

  @override
  String get settingsDensity => 'Arayüz yoğunluğu';

  @override
  String get settingsDensityCompact => 'Sıkı';

  @override
  String get settingsDensityNormal => 'Normal';

  @override
  String get settingsDensityComfortable => 'Ferah';

  @override
  String get settingsDensityHint => 'Sıkı: masada daha çok bilgi ekrana sığar.';

  @override
  String get worldCollapseChildren => 'Alt yerleri gizle';

  @override
  String get worldExpandChildren => 'Alt yerleri göster';

  @override
  String get musicAmbience => 'Ortam sesi';

  @override
  String get musicAmbienceStop => 'Ortam sesini durdur';

  @override
  String get journeySkipTime => 'Zamanı ilerlet';

  @override
  String combatConcentrationCheck(String name, int dc) {
    return '$name konsantrasyonu için DC $dc Constitution kurtarması atmalı.';
  }

  @override
  String get combatGroupInitiative => 'Aynı türe tek atış';

  @override
  String get combatNoArmorClass => 'AC bilinmiyor';

  @override
  String combatHits(int ac) {
    return 'İsabet (AC $ac)';
  }

  @override
  String combatMisses(int ac) {
    return 'Iskaladı (AC $ac)';
  }

  @override
  String combatApplyDamage(int damage) {
    return '$damage hasar uygula';
  }

  @override
  String get combatApplied => 'Uygulandı';

  @override
  String get searchEmpty => 'Aramak için yazmaya başla.';

  @override
  String get searchOpen => 'Genel arama';

  @override
  String get sessionRolls => 'Zar günlüğü';

  @override
  String get sessionRollsEmpty => 'Henüz zar atılmadı.';

  @override
  String get contentSourcesTitle => 'İçerik kaynakları';

  @override
  String get contentSourcesHint =>
      '5etools biçiminde JSON sunan bir adres ekle; uygulama orada hangi dosyalar olduğunu keşfeder. Uygulama hazır bir adresle gelmez — hangi kaynağı kullanacağına sen karar verirsin.';

  @override
  String get contentSourceAdd => 'Kaynak ekle';

  @override
  String get contentSourceName => 'Ad';

  @override
  String get contentSourceUrl => 'Kök adres';

  @override
  String get contentSourceUrlHint =>
      'Veri klasörünün kökü, ör. https://ornek/data';

  @override
  String get contentSourceDiscover => 'Keşfet';

  @override
  String get contentSourceEmpty => 'Henüz kaynak yok.';

  @override
  String get contentSourceNothingFound =>
      'Bu adreste tanınan bir dosya bulunamadı.';

  @override
  String contentSourceLastImport(String date) {
    return 'Son aktarma: $date';
  }

  @override
  String get contentSourceNeverImported => 'Hiç aktarılmadı';

  @override
  String get contentSourceImportSelected => 'Seçilenleri aktar';

  @override
  String contentSourceImporting(String file) {
    return 'Aktarılıyor: $file';
  }

  @override
  String contentSourceDone(int monsters, int spells, int items, int others) {
    return '$monsters canavar, $spells büyü, $items eşya, $others diğer aktarıldı.';
  }

  @override
  String get contentSourceLocalFiles => 'Dosyadan aktar';

  @override
  String get contentSourceDeleteImported => 'Aktarılan içeriği sil';

  @override
  String get contentSourceDeleteImportedBody =>
      'Bu adreslerden aktarılmış tüm kayıtlar silinecek. Uygulama içinde oluşturduğun içerik ve paketlenmiş SRD etkilenmez.';

  @override
  String contentSourceDeleted(int count) {
    return '$count kayıt silindi.';
  }

  @override
  String get contentSourceKindMonster => 'Canavarlar';

  @override
  String get contentSourceKindSpell => 'Büyüler';

  @override
  String get contentSourceKindItem => 'Eşyalar';

  @override
  String get contentSourceKindRace => 'Türler';

  @override
  String get contentSourceKindBackground => 'Geçmişler';

  @override
  String get contentSourceKindFeat => 'Yetenekler';

  @override
  String get contentSourceSelectAll => 'Tümünü seç';

  @override
  String get contentSourceLegal =>
      'Yalnızca kullanma hakkına sahip olduğun içeriği aktar. Aktarılan kayıtlar cihazında kalır; yedekleme paketlerine girmez.';

  @override
  String get contentSourceProblemNetwork =>
      'Adrese bağlanılamadı. Bağlantını ve adresi kontrol et.';

  @override
  String contentSourceProblemBlocked(String status) {
    return 'Sunucu isteği reddetti ($status). Bu adres tarayıcı dışı istemcileri bot koruması ile engelliyor; uygulama bu korumayı aşmaz. Verileri tarayıcından indirip “Dosyadan aktar” ile ekleyebilirsin.';
  }

  @override
  String contentSourceProblemNotFound(String status) {
    return 'Bu adreste 5etools biçiminde dosya bulunamadı ($status). Kök adresin veri klasörünü gösterdiğinden emin ol.';
  }

  @override
  String get contentSourceProblemNotJson =>
      'Adres JSON değil, sayfa döndürdü. Kök adres veri klasörünü göstermiyor olabilir.';

  @override
  String contentSourceResolved(String url) {
    return 'Bulunan kök: $url';
  }

  @override
  String undoDone(String label) {
    return '$label geri alındı';
  }

  @override
  String get undoNothing => 'Geri alınacak bir şey yok';

  @override
  String get undoTitle => 'Geri al';

  @override
  String get undoHistory => 'Geri alma geçmişi';

  @override
  String get turnTimer => 'Tur süresi';

  @override
  String get turnTimerOff => 'Kapalı';

  @override
  String turnTimerSeconds(int seconds) {
    return '$seconds sn';
  }

  @override
  String get turnTimerUp => 'Süre doldu';

  @override
  String get partyBoard => 'Parti panosu';

  @override
  String get partyBoardPassive => 'Pasif algı';

  @override
  String get partyBoardSaves => 'Kurtarmalar';

  @override
  String get partyBoardDefenses => 'Direnç / bağışıklık';

  @override
  String get partyBoardLanguages => 'Diller';

  @override
  String get partyBoardEmpty => 'Partide karakter yok.';

  @override
  String get encounterTemplates => 'Karşılaşma kalıpları';

  @override
  String get encounterTemplateSave => 'Kalıp olarak kaydet';

  @override
  String get encounterTemplateUse => 'Bu kalıptan kur';

  @override
  String get encounterTemplateEmpty => 'Kayıtlı kalıp yok.';

  @override
  String encounterTemplateMissing(String names) {
    return 'Kütüphanede bulunamayan: $names';
  }

  @override
  String encounterTemplateCreated(String name) {
    return '$name kuruldu.';
  }

  @override
  String get reaction => 'Reaksiyon';

  @override
  String get reactionUsed => 'Reaksiyon kullanıldı';

  @override
  String get reactionAvailable => 'Reaksiyon hazır';

  @override
  String get lairAction => 'İn eylemi';

  @override
  String lairActionHint(int value) {
    return 'İnisiyatif $value geldiğinde hatırlatılır.';
  }

  @override
  String get lairActionNone => 'Bu karşılaşmada in eylemi yok.';

  @override
  String get damageType => 'Hasar türü';

  @override
  String get damageTypeAny => 'Tür yok';

  @override
  String damageResisted(int amount) {
    return 'Direnç: $amount';
  }

  @override
  String get damageImmune => 'Bağışık — hasar yok';

  @override
  String damageVulnerable(int amount) {
    return 'Zayıflık: $amount';
  }

  @override
  String get defensesTitle => 'Savunmalar';

  @override
  String get defenseResist => 'Direnç';

  @override
  String get defenseImmune => 'Bağışıklık';

  @override
  String get defenseVulnerable => 'Zayıflık';

  @override
  String get deathSaves => 'Ölüm kurtarması';

  @override
  String get deathSaveRoll => 'Kurtarma at';

  @override
  String get deathSaveStable => 'Stabil';

  @override
  String get deathSaveDead => 'Öldü';

  @override
  String get deathSaveRevived => 'Ayağa kalktı (1 can)';

  @override
  String get downtime => 'Boş zaman';

  @override
  String get downtimeAdd => 'Faaliyet ekle';

  @override
  String get downtimeDays => 'Gün';

  @override
  String downtimeRemaining(int days) {
    return '$days gün kaldı';
  }

  @override
  String get downtimeComplete => 'Tamamla';

  @override
  String get downtimeOutcome => 'Sonuç';

  @override
  String get downtimeEmpty => 'Kayıtlı faaliyet yok.';

  @override
  String get downtimeKindCraft => 'Zanaat';

  @override
  String get downtimeKindResearch => 'Araştırma';

  @override
  String get downtimeKindWork => 'İş bulma';

  @override
  String get downtimeKindTrain => 'Eğitim';

  @override
  String get downtimeKindRecuperate => 'İyileşme';

  @override
  String get downtimeKindCarouse => 'Âlem';

  @override
  String get downtimeKindCustom => 'Serbest';

  @override
  String get sessionRecap => 'Oturum özeti';

  @override
  String get sessionRecapGenerate => 'Özet üret';

  @override
  String get sessionRecapEmpty => 'Özetlenecek günlük kaydı yok.';

  @override
  String get exportPdf => 'PDF olarak kaydet';

  @override
  String exportPdfDone(String path) {
    return 'Kaydedildi: $path';
  }

  @override
  String get macros => 'Makrolar';

  @override
  String get macroAdd => 'Makro ekle';

  @override
  String get macroExpression => 'Zar ifadesi';

  @override
  String get macroInvalid => 'İfade çözülemedi (örn. 2d6+3).';

  @override
  String get macroEmpty => 'Makro yok.';

  @override
  String get macroScopeDm => 'Yalnızca DM';

  @override
  String get macroScopePlayer => 'Oyuncular';

  @override
  String get macroScopeBoth => 'Herkes';

  @override
  String get settingsAccessibility => 'Erişilebilirlik';

  @override
  String get settingsHighContrast => 'Yüksek kontrast';

  @override
  String get settingsColorBlind => 'Renk körlüğü uyumu';

  @override
  String get settingsColorBlindHint =>
      'Jeton takımları ve duvar türleri renge ek olarak desen/şekille de ayrışır.';

  @override
  String get settingsTouchLayout => 'Dokunmatik düzen';

  @override
  String get settingsTouchLayoutHint =>
      'Orta tuş ve sağ tık yerine ekrandaki düğmeler kullanılır; hedefler büyür.';

  @override
  String get syncFolder => 'Yedek klasörü';

  @override
  String get syncFolderHint =>
      'Seçilen klasöre her gün otomatik yedek yazılır. Bulut klasörü (OneDrive, Drive, Dropbox) seçersen yedek cihazlar arasında taşınır.';

  @override
  String get syncFolderPick => 'Klasör seç';

  @override
  String get syncFolderNone => 'Seçilmedi';

  @override
  String get syncFolderCleared => 'Kaldırıldı';

  @override
  String get campaignMerge => 'Başka kampanyadan al';

  @override
  String get campaignMergeHint =>
      'Seçtiğin kampanyadan canavar, NPC, harita ve rastgele tabloları kopyalar. Mevcut kayıtlarının üzerine yazılmaz.';

  @override
  String campaignMergeDone(int count) {
    return '$count kayıt alındı.';
  }

  @override
  String get campaignMergeWhat => 'Ne alınsın?';

  @override
  String contentSourceImages(int done, int total) {
    return 'Görseller indiriliyor: $done/$total';
  }

  @override
  String get questOwners => 'Üstlenen';

  @override
  String get questOwnersSection => 'Görevi kim üstlendi?';

  @override
  String get questOwnersHint => 'İşi üstlenen karakterleri işaretle.';

  @override
  String get restSpendHitDie => 'Zar harca';

  @override
  String restHitDieSpent(String name, int healed) {
    return '$name bir hit die harcadı: +$healed can';
  }

  @override
  String get lootGrant => 'Aktar';

  @override
  String lootGranted(Object name) {
    return '“$name” ortak keseye aktarıldı.';
  }

  @override
  String get lootNoPartyBag =>
      'Önce bir ortak kese oluştur (Karakterler sekmesi).';

  @override
  String get encLocation => 'Geçtiği yer';

  @override
  String get encLocationNone => 'Bir yere bağlanmadı';

  @override
  String get encLocationMissing => 'Bağlı yer silinmiş';

  @override
  String get encLocationPick => 'Yer seç';

  @override
  String get encLocationClear => 'Bağı kaldır';

  @override
  String get encLocationNoLocations =>
      'Henüz yer yok — önce Dünya sekmesinden bir yer oluştur.';

  @override
  String get worldEncountersHere => 'Buradaki karşılaşmalar';

  @override
  String get factionTitle => 'Fraksiyon';

  @override
  String get factionsTab => 'Fraksiyonlar';

  @override
  String get factionAdd => 'Yeni fraksiyon';

  @override
  String get factionEmpty =>
      'Henüz fraksiyon yok. Loncalar, tarikatlar, hanedanlar ve çeteler buraya.';

  @override
  String get factionName => 'Ad';

  @override
  String get factionKind => 'Tür';

  @override
  String get factionKindHint => 'lonca, tarikat, hanedan, çete…';

  @override
  String get factionGoal => 'Amaç';

  @override
  String get factionDescription => 'Açıklama';

  @override
  String get factionSecretNotes => 'DM notu';

  @override
  String get factionSecretHint => 'Yalnızca sen görürsün.';

  @override
  String get factionEmblemClear => 'Armayı kaldır';

  @override
  String get factionBonds => 'Bağlar';

  @override
  String get factionBondsEmpty =>
      'Henüz bağ yok — dünya grafiğinden düğümleri bağla.';

  @override
  String get factionBondBroken => '(silinmiş)';

  @override
  String get factionDelete => 'Fraksiyonu sil';

  @override
  String get factionDeleteConfirm => 'Fraksiyon ve bağları kaldırılacak.';

  @override
  String get worldFactions => 'Fraksiyonlar';

  @override
  String get bondMembership => 'Üyelik';

  @override
  String get clocksTitle => 'Saatler';

  @override
  String get clocksEmpty =>
      'Saat yok. Bir kuşatmayı, bir ayini ya da yayılan bir söylentiyi izle.';

  @override
  String get clockAdd => 'Yeni saat';

  @override
  String get clockName => 'Ne işliyor?';

  @override
  String get clockNameHint => 'Kuşatma geliyor';

  @override
  String get clockOutcome => 'Dolunca';

  @override
  String get clockOutcomeHint => 'Son dilim dolduğunda masada ne olacak.';

  @override
  String get clockAdvance => 'Bir dilim ilerlet';

  @override
  String get clockClose => 'Saati kapat';

  @override
  String get clockReopen => 'Saati yeniden aç';

  @override
  String get exportTitle => 'Açık biçimler';

  @override
  String get exportHint =>
      'Her yerde okunur ama geri YÜKLENMEZ. Medya dosyaları dahil değildir.';

  @override
  String get exportMarkdown => 'Kayıtlar → Markdown';

  @override
  String get exportJson => 'Kampanya → JSON';

  @override
  String get exportMarkdownType => 'Markdown';

  @override
  String get exportJsonType => 'JSON';

  @override
  String get exportDone => 'Dışa aktarıldı.';
}
