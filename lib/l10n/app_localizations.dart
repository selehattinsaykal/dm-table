import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'DM Table'**
  String get appTitle;

  /// No description provided for @navCampaigns.
  ///
  /// In tr, this message translates to:
  /// **'Kampanyalar'**
  String get navCampaigns;

  /// No description provided for @navCompendium.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphane'**
  String get navCompendium;

  /// No description provided for @navCharacters.
  ///
  /// In tr, this message translates to:
  /// **'Karakterler'**
  String get navCharacters;

  /// No description provided for @navCompendiumShort.
  ///
  /// In tr, this message translates to:
  /// **'Kitaplık'**
  String get navCompendiumShort;

  /// No description provided for @navCharactersShort.
  ///
  /// In tr, this message translates to:
  /// **'Karakter'**
  String get navCharactersShort;

  /// No description provided for @navShopsShort.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza'**
  String get navShopsShort;

  /// No description provided for @navCombat.
  ///
  /// In tr, this message translates to:
  /// **'Savaş'**
  String get navCombat;

  /// No description provided for @navWorld.
  ///
  /// In tr, this message translates to:
  /// **'Dünya'**
  String get navWorld;

  /// No description provided for @navShops.
  ///
  /// In tr, this message translates to:
  /// **'Mağazalar'**
  String get navShops;

  /// No description provided for @navSession.
  ///
  /// In tr, this message translates to:
  /// **'Oturum'**
  String get navSession;

  /// No description provided for @navSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @navLoot.
  ///
  /// In tr, this message translates to:
  /// **'Ganimet'**
  String get navLoot;

  /// No description provided for @navCodex.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar'**
  String get navCodex;

  /// No description provided for @navMusic.
  ///
  /// In tr, this message translates to:
  /// **'Müzik'**
  String get navMusic;

  /// No description provided for @musicImport.
  ///
  /// In tr, this message translates to:
  /// **'Dosya ekle'**
  String get musicImport;

  /// No description provided for @musicNewPlaylist.
  ///
  /// In tr, this message translates to:
  /// **'Yeni liste'**
  String get musicNewPlaylist;

  /// No description provided for @musicRenamePlaylist.
  ///
  /// In tr, this message translates to:
  /// **'Listeyi yeniden adlandır'**
  String get musicRenamePlaylist;

  /// No description provided for @musicDeletePlaylistConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Liste silinsin mi? Parçalar silinmez, listesiz duruma düşer.'**
  String get musicDeletePlaylistConfirm;

  /// No description provided for @musicRenameTrack.
  ///
  /// In tr, this message translates to:
  /// **'Parçayı yeniden adlandır'**
  String get musicRenameTrack;

  /// No description provided for @musicMoveTo.
  ///
  /// In tr, this message translates to:
  /// **'Listeye taşı'**
  String get musicMoveTo;

  /// No description provided for @musicUnfiled.
  ///
  /// In tr, this message translates to:
  /// **'Listesiz'**
  String get musicUnfiled;

  /// No description provided for @musicEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu listede parça yok. Sağ alttaki düğmeyle ses dosyası ekle; dosyalar kampanya klasörüne kopyalanır ve yedeğe dahil olur.'**
  String get musicEmpty;

  /// No description provided for @musicPlay.
  ///
  /// In tr, this message translates to:
  /// **'Çal'**
  String get musicPlay;

  /// No description provided for @musicPause.
  ///
  /// In tr, this message translates to:
  /// **'Duraklat'**
  String get musicPause;

  /// No description provided for @musicStop.
  ///
  /// In tr, this message translates to:
  /// **'Durdur'**
  String get musicStop;

  /// No description provided for @musicNext.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki'**
  String get musicNext;

  /// No description provided for @musicPrevious.
  ///
  /// In tr, this message translates to:
  /// **'Önceki'**
  String get musicPrevious;

  /// No description provided for @musicLoopOff.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar kapalı'**
  String get musicLoopOff;

  /// No description provided for @musicLoopAll.
  ///
  /// In tr, this message translates to:
  /// **'Listeyi tekrarla'**
  String get musicLoopAll;

  /// No description provided for @musicLoopOne.
  ///
  /// In tr, this message translates to:
  /// **'Tek parçayı tekrarla'**
  String get musicLoopOne;

  /// No description provided for @musicMissingFile.
  ///
  /// In tr, this message translates to:
  /// **'{title} — dosya bulunamadı'**
  String musicMissingFile(String title);

  /// No description provided for @settingsLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @themeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @settingsPartialTranslation.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamanın bazı bölümleri henüz yalnızca Türkçedir.'**
  String get settingsPartialTranslation;

  /// No description provided for @settingsAiTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yapay Zekâ (opt-in)'**
  String get settingsAiTitle;

  /// No description provided for @settingsAiProvider.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcı'**
  String get settingsAiProvider;

  /// No description provided for @settingsAiKey.
  ///
  /// In tr, this message translates to:
  /// **'API anahtarı'**
  String get settingsAiKey;

  /// No description provided for @settingsAiModel.
  ///
  /// In tr, this message translates to:
  /// **'Model (isteğe bağlı)'**
  String get settingsAiModel;

  /// No description provided for @settingsAiNote.
  ///
  /// In tr, this message translates to:
  /// **'Anahtarın yalnızca bu cihazda saklanır. Oyunculara/LAN\'a gitmez; kullanım kendi API kotandan düşer.'**
  String get settingsAiNote;

  /// No description provided for @settingsAiSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi (bu cihazda)'**
  String get settingsAiSaved;

  /// No description provided for @settingsAiActive.
  ///
  /// In tr, this message translates to:
  /// **'Anahtar kayıtlı — AI araçları aktif'**
  String get settingsAiActive;

  /// No description provided for @settingsAiInactive.
  ///
  /// In tr, this message translates to:
  /// **'Anahtar girilmedi — AI araçları kapalı'**
  String get settingsAiInactive;

  /// No description provided for @codexAiSetting.
  ///
  /// In tr, this message translates to:
  /// **'Han / tema (isteğe bağlı)'**
  String get codexAiSetting;

  /// No description provided for @codexAiGenerate.
  ///
  /// In tr, this message translates to:
  /// **'Üret'**
  String get codexAiGenerate;

  /// No description provided for @codexAiInsert.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar\'a ekle'**
  String get codexAiInsert;

  /// No description provided for @codexAiCopy.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get codexAiCopy;

  /// No description provided for @codexAiCopied.
  ///
  /// In tr, this message translates to:
  /// **'Panoya kopyalandı'**
  String get codexAiCopied;

  /// No description provided for @codexAiInserted.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar\'a eklendi'**
  String get codexAiInserted;

  /// No description provided for @codexAiNotConfigured.
  ///
  /// In tr, this message translates to:
  /// **'AI ayarlanmadı. Ayarlar\'dan API anahtarı gir.'**
  String get codexAiNotConfigured;

  /// No description provided for @codexAiErrAuth.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz API anahtarı.'**
  String get codexAiErrAuth;

  /// No description provided for @codexAiErrRate.
  ///
  /// In tr, this message translates to:
  /// **'İstek sınırına ulaşıldı ya da bu model hesabının planında kullanılamıyor. Aşağıdaki ayrıntı hangisi olduğunu söyler.'**
  String get codexAiErrRate;

  /// No description provided for @codexAiErrNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Ağ hatası. Bağlantını kontrol et.'**
  String get codexAiErrNetwork;

  /// No description provided for @codexAiErrRefused.
  ///
  /// In tr, this message translates to:
  /// **'Model bu isteği reddetti.'**
  String get codexAiErrRefused;

  /// No description provided for @codexAiErrEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Model metin döndürmedi.'**
  String get codexAiErrEmpty;

  /// No description provided for @codexAiErrGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Üretilemedi. Tekrar dene.'**
  String get codexAiErrGeneric;

  /// No description provided for @navAiTools.
  ///
  /// In tr, this message translates to:
  /// **'AI Araçları'**
  String get navAiTools;

  /// No description provided for @aiToolQuest.
  ///
  /// In tr, this message translates to:
  /// **'Görev Üretici'**
  String get aiToolQuest;

  /// No description provided for @aiOpenSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar\'ı aç'**
  String get aiOpenSettings;

  /// No description provided for @aiRegenerate.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden üret'**
  String get aiRegenerate;

  /// No description provided for @aiPickPage.
  ///
  /// In tr, this message translates to:
  /// **'Hangi sayfaya eklensin?'**
  String get aiPickPage;

  /// No description provided for @aiNoPages.
  ///
  /// In tr, this message translates to:
  /// **'Önce bir Kayıtlar sayfası oluştur.'**
  String get aiNoPages;

  /// No description provided for @aiQuestHeading.
  ///
  /// In tr, this message translates to:
  /// **'Görev'**
  String get aiQuestHeading;

  /// No description provided for @questPartySize.
  ///
  /// In tr, this message translates to:
  /// **'Ekip kişi sayısı'**
  String get questPartySize;

  /// No description provided for @questPartyLevel.
  ///
  /// In tr, this message translates to:
  /// **'Ekip seviyesi'**
  String get questPartyLevel;

  /// No description provided for @questDifficulty.
  ///
  /// In tr, this message translates to:
  /// **'Zorluk'**
  String get questDifficulty;

  /// No description provided for @questDiffVeryEasy.
  ///
  /// In tr, this message translates to:
  /// **'Çok Kolay'**
  String get questDiffVeryEasy;

  /// No description provided for @questDiffEasy.
  ///
  /// In tr, this message translates to:
  /// **'Kolay'**
  String get questDiffEasy;

  /// No description provided for @questDiffMedium.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get questDiffMedium;

  /// No description provided for @questDiffHard.
  ///
  /// In tr, this message translates to:
  /// **'Zor'**
  String get questDiffHard;

  /// No description provided for @questDiffVeryHard.
  ///
  /// In tr, this message translates to:
  /// **'Çok Zor'**
  String get questDiffVeryHard;

  /// No description provided for @questGiverNpc.
  ///
  /// In tr, this message translates to:
  /// **'Görevi veren NPC'**
  String get questGiverNpc;

  /// No description provided for @questGiverNone.
  ///
  /// In tr, this message translates to:
  /// **'Yok (serbest)'**
  String get questGiverNone;

  /// No description provided for @questGiverHint.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı — seçersen görev bu NPC\'ye bağlanır.'**
  String get questGiverHint;

  /// No description provided for @questTargetLocation.
  ///
  /// In tr, this message translates to:
  /// **'Hedef lokasyon'**
  String get questTargetLocation;

  /// No description provided for @questTargetNone.
  ///
  /// In tr, this message translates to:
  /// **'Yok (serbest)'**
  String get questTargetNone;

  /// No description provided for @questTargetHint.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı — seçersen görev bu lokasyona götürür.'**
  String get questTargetHint;

  /// No description provided for @questSectionQuest.
  ///
  /// In tr, this message translates to:
  /// **'Görev metni'**
  String get questSectionQuest;

  /// No description provided for @questSectionReward.
  ///
  /// In tr, this message translates to:
  /// **'Ödül'**
  String get questSectionReward;

  /// No description provided for @questSectionDm.
  ///
  /// In tr, this message translates to:
  /// **'Bilmem gereken açıklamalar'**
  String get questSectionDm;

  /// No description provided for @questDmOnly.
  ///
  /// In tr, this message translates to:
  /// **'Sadece sen görüyorsun — oyunculara gitmez'**
  String get questDmOnly;

  /// No description provided for @questCopyPlayer.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncu metnini kopyala'**
  String get questCopyPlayer;

  /// No description provided for @questCopyAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü kopyala'**
  String get questCopyAll;

  /// No description provided for @questSendPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara gönder'**
  String get questSendPlayers;

  /// No description provided for @questSentPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara gönderildi'**
  String get questSentPlayers;

  /// No description provided for @questNeedSession.
  ///
  /// In tr, this message translates to:
  /// **'Önce Oturum sekmesinden masayı aç.'**
  String get questNeedSession;

  /// No description provided for @navQuests.
  ///
  /// In tr, this message translates to:
  /// **'Görevler'**
  String get navQuests;

  /// No description provided for @questsNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni görev'**
  String get questsNew;

  /// No description provided for @questsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz görev yok. Sağ alttan ekle ya da AI Araçları\'ndan gönder.'**
  String get questsEmpty;

  /// No description provided for @questUntitled.
  ///
  /// In tr, this message translates to:
  /// **'(başlıksız görev)'**
  String get questUntitled;

  /// No description provided for @questAcceptedBy.
  ///
  /// In tr, this message translates to:
  /// **'Kabul'**
  String get questAcceptedBy;

  /// No description provided for @questRejectedBy.
  ///
  /// In tr, this message translates to:
  /// **'Ret'**
  String get questRejectedBy;

  /// No description provided for @questPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen'**
  String get questPending;

  /// No description provided for @campaignDefaultName.
  ///
  /// In tr, this message translates to:
  /// **'Ana Kampanya'**
  String get campaignDefaultName;

  /// No description provided for @campaignExplainer.
  ///
  /// In tr, this message translates to:
  /// **'Her kampanya kendi veritabanı dosyasıdır: karakterler, dünya, görevler, kayıtlar ve takvim kampanyaya özeldir. Aynı anda tek kampanya açıktır.'**
  String get campaignExplainer;

  /// No description provided for @campaignNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kampanya'**
  String get campaignNew;

  /// No description provided for @campaignNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya adı'**
  String get campaignNameLabel;

  /// No description provided for @campaignOpen.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get campaignOpen;

  /// No description provided for @campaignRename.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden adlandır'**
  String get campaignRename;

  /// No description provided for @campaignActive.
  ///
  /// In tr, this message translates to:
  /// **'Açık kampanya'**
  String get campaignActive;

  /// No description provided for @campaignInactive.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get campaignInactive;

  /// No description provided for @campaignDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} silinsin mi?'**
  String campaignDeleteTitle(String name);

  /// No description provided for @campaignDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu kampanyanın karakterleri, dünyası, görevleri, kayıtları ve tüm görselleri kalıcı olarak silinir. Bu işlem geri alınamaz.'**
  String get campaignDeleteBody;

  /// No description provided for @campaignDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya silindi'**
  String get campaignDeleted;

  /// No description provided for @campaignDeleteLater.
  ///
  /// In tr, this message translates to:
  /// **'Dosya şu an kullanımda; kampanya bir sonraki açılışta silinecek.'**
  String get campaignDeleteLater;

  /// No description provided for @campaignSwitchTitle.
  ///
  /// In tr, this message translates to:
  /// **'Oturum açık'**
  String get campaignSwitchTitle;

  /// No description provided for @campaignSwitchBody.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya değiştirilirse masa kapanır, bağlı oyuncuların bağlantısı kesilir ve yeni bir katılım adresi üretilir.'**
  String get campaignSwitchBody;

  /// No description provided for @campaignSwitchPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Bağlı oyuncular: {names}'**
  String campaignSwitchPlayers(String names);

  /// No description provided for @campaignSwitchConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get campaignSwitchConfirm;

  /// No description provided for @navCalendar.
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get navCalendar;

  /// No description provided for @calendarTabCalendar.
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get calendarTabCalendar;

  /// No description provided for @calendarTabChronicle.
  ///
  /// In tr, this message translates to:
  /// **'Tarihçe'**
  String get calendarTabChronicle;

  /// No description provided for @calendarTabReminders.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatıcılar'**
  String get calendarTabReminders;

  /// No description provided for @reminderNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni hatırlatıcı'**
  String get reminderNew;

  /// No description provided for @reminderEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hatırlatıcı yok. İleriye dönük olayları buraya yaz; gün ilerledikçe sana hatırlatılır.'**
  String get reminderEmpty;

  /// No description provided for @reminderTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In tr, this message translates to:
  /// **'Not (isteğe bağlı)'**
  String get reminderBody;

  /// No description provided for @reminderStart.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get reminderStart;

  /// No description provided for @reminderRepeat.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar'**
  String get reminderRepeat;

  /// No description provided for @reminderRepeatOnce.
  ///
  /// In tr, this message translates to:
  /// **'Tek seferlik'**
  String get reminderRepeatOnce;

  /// No description provided for @reminderRepeatMonthly.
  ///
  /// In tr, this message translates to:
  /// **'Her ay'**
  String get reminderRepeatMonthly;

  /// No description provided for @reminderRepeatYearly.
  ///
  /// In tr, this message translates to:
  /// **'Her yıl'**
  String get reminderRepeatYearly;

  /// No description provided for @reminderRepeatEveryNDays.
  ///
  /// In tr, this message translates to:
  /// **'Her {n} günde bir'**
  String reminderRepeatEveryNDays(int n);

  /// No description provided for @reminderRepeatEveryNDaysShort.
  ///
  /// In tr, this message translates to:
  /// **'Her N günde'**
  String get reminderRepeatEveryNDaysShort;

  /// No description provided for @reminderEveryNDaysLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kaç günde bir'**
  String get reminderEveryNDaysLabel;

  /// No description provided for @reminderMonthlyHint.
  ///
  /// In tr, this message translates to:
  /// **'Ay o güne kadar sürmüyorsa hatırlatıcı ayın son gününe çekilir; atlanmaz.'**
  String get reminderMonthlyHint;

  /// No description provided for @reminderNext.
  ///
  /// In tr, this message translates to:
  /// **'sıradaki: {date}'**
  String reminderNext(String date);

  /// No description provided for @reminderNoNext.
  ///
  /// In tr, this message translates to:
  /// **'sırada yok'**
  String get reminderNoNext;

  /// No description provided for @reminderClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get reminderClose;

  /// No description provided for @reminderReopen.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden aç'**
  String get reminderReopen;

  /// No description provided for @reminderFired.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatıcı: {titles}'**
  String reminderFired(String titles);

  /// No description provided for @calendarTabSettings.
  ///
  /// In tr, this message translates to:
  /// **'Takvim yapısı'**
  String get calendarTabSettings;

  /// No description provided for @calendarDefaultMonths.
  ///
  /// In tr, this message translates to:
  /// **'Karakış,Buzçözen,Tohumay,Yeşerme,Çiçekay,Günortası,Sıcakay,Harmanay,Bereket,Yaprakdökümü,Sisay,Uzunkaranlık'**
  String get calendarDefaultMonths;

  /// No description provided for @calendarDefaultWeekdays.
  ///
  /// In tr, this message translates to:
  /// **'Örsgün,Ocakgün,Sugün,Pazargün,Yolgün,Andgün,Dinlence'**
  String get calendarDefaultWeekdays;

  /// No description provided for @calendarDefaultSeasons.
  ///
  /// In tr, this message translates to:
  /// **'İlkbahar,Yaz,Sonbahar,Kış'**
  String get calendarDefaultSeasons;

  /// No description provided for @calendarNoSeason.
  ///
  /// In tr, this message translates to:
  /// **'Mevsimsiz'**
  String get calendarNoSeason;

  /// No description provided for @calendarSetToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugünü ayarla'**
  String get calendarSetToday;

  /// No description provided for @calendarAdvanceDay.
  ///
  /// In tr, this message translates to:
  /// **'+1 gün'**
  String get calendarAdvanceDay;

  /// No description provided for @calendarAdvanceWeek.
  ///
  /// In tr, this message translates to:
  /// **'+1 hafta'**
  String get calendarAdvanceWeek;

  /// No description provided for @calendarBackDay.
  ///
  /// In tr, this message translates to:
  /// **'-1 gün'**
  String get calendarBackDay;

  /// No description provided for @calendarGoToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugüne dön'**
  String get calendarGoToday;

  /// No description provided for @calendarYear.
  ///
  /// In tr, this message translates to:
  /// **'Yıl'**
  String get calendarYear;

  /// No description provided for @calendarMonth.
  ///
  /// In tr, this message translates to:
  /// **'Ay'**
  String get calendarMonth;

  /// No description provided for @calendarDay.
  ///
  /// In tr, this message translates to:
  /// **'Gün'**
  String get calendarDay;

  /// No description provided for @calendarNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Takvimin adı'**
  String get calendarNameLabel;

  /// No description provided for @calendarEraLabel.
  ///
  /// In tr, this message translates to:
  /// **'Çağ etiketi'**
  String get calendarEraLabel;

  /// No description provided for @calendarEraHint.
  ///
  /// In tr, this message translates to:
  /// **'Yılın yanına yazılır, ör. \"Üçüncü Çağ\".'**
  String get calendarEraHint;

  /// No description provided for @calendarYearSuffix.
  ///
  /// In tr, this message translates to:
  /// **'Yıl kısaltması (Milat sonrası)'**
  String get calendarYearSuffix;

  /// No description provided for @calendarYearSuffixHint.
  ///
  /// In tr, this message translates to:
  /// **'Ör. \"MS\" — 1492 MS. Yıl 0 ve sonrasında kullanılır.'**
  String get calendarYearSuffixHint;

  /// No description provided for @calendarYearSuffixBefore.
  ///
  /// In tr, this message translates to:
  /// **'Yıl kısaltması (Milat öncesi)'**
  String get calendarYearSuffixBefore;

  /// No description provided for @calendarYearSuffixBeforeHint.
  ///
  /// In tr, this message translates to:
  /// **'Ör. \"MÖ\" — 50 MÖ. Negatif yıllarda kullanılır.'**
  String get calendarYearSuffixBeforeHint;

  /// No description provided for @calendarYearEraAfter.
  ///
  /// In tr, this message translates to:
  /// **'Sonrası'**
  String get calendarYearEraAfter;

  /// No description provided for @calendarYearEraBefore.
  ///
  /// In tr, this message translates to:
  /// **'Öncesi'**
  String get calendarYearEraBefore;

  /// No description provided for @calendarMonths.
  ///
  /// In tr, this message translates to:
  /// **'Aylar'**
  String get calendarMonths;

  /// No description provided for @calendarAddMonth.
  ///
  /// In tr, this message translates to:
  /// **'Ay ekle'**
  String get calendarAddMonth;

  /// No description provided for @calendarMonthDays.
  ///
  /// In tr, this message translates to:
  /// **'gün'**
  String get calendarMonthDays;

  /// No description provided for @calendarWeekdays.
  ///
  /// In tr, this message translates to:
  /// **'Gün adları'**
  String get calendarWeekdays;

  /// No description provided for @calendarAddWeekday.
  ///
  /// In tr, this message translates to:
  /// **'Gün adı ekle'**
  String get calendarAddWeekday;

  /// No description provided for @calendarWeekdaysHint.
  ///
  /// In tr, this message translates to:
  /// **'Haftanın kaç gün olduğunu bu liste belirler.'**
  String get calendarWeekdaysHint;

  /// No description provided for @calendarSeasons.
  ///
  /// In tr, this message translates to:
  /// **'Mevsimler'**
  String get calendarSeasons;

  /// No description provided for @calendarAddSeason.
  ///
  /// In tr, this message translates to:
  /// **'Mevsim ekle'**
  String get calendarAddSeason;

  /// No description provided for @calendarSeasonRange.
  ///
  /// In tr, this message translates to:
  /// **'{start} — {end}'**
  String calendarSeasonRange(String start, String end);

  /// No description provided for @calendarSeasonStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get calendarSeasonStart;

  /// No description provided for @calendarSeasonEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get calendarSeasonEnd;

  /// No description provided for @calendarSeasonWrapHint.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş başlangıçtan önceyse mevsim yıl sonunu sarar (kış gibi).'**
  String get calendarSeasonWrapHint;

  /// No description provided for @calendarNoMonths.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ay yok. Aşağıdan ekle ya da varsayılan takvimi yükle.'**
  String get calendarNoMonths;

  /// No description provided for @calendarSeedDefaults.
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan takvimi yükle'**
  String get calendarSeedDefaults;

  /// No description provided for @chronicleEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tarihçe kaydı yok. Dünyanın geçmişini buradan yaz.'**
  String get chronicleEmpty;

  /// No description provided for @chronicleNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni olay'**
  String get chronicleNew;

  /// No description provided for @chronicleEventTitle.
  ///
  /// In tr, this message translates to:
  /// **'Olay başlığı'**
  String get chronicleEventTitle;

  /// No description provided for @chronicleBody.
  ///
  /// In tr, this message translates to:
  /// **'Ne oldu?'**
  String get chronicleBody;

  /// No description provided for @chronicleBodyHint.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar\'daki gibi yazabilirsin: **kalın**, [[sayfa]], /r 2d6, /monster(...)'**
  String get chronicleBodyHint;

  /// No description provided for @chronicleCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get chronicleCategory;

  /// No description provided for @chronicleCategoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Serbest, ör. savaş / antlaşma / felaket'**
  String get chronicleCategoryHint;

  /// No description provided for @chronicleSecret.
  ///
  /// In tr, this message translates to:
  /// **'Gizli (yalnız sen bilirsin)'**
  String get chronicleSecret;

  /// No description provided for @chronicleHasEnd.
  ///
  /// In tr, this message translates to:
  /// **'Süren olay (bitiş tarihi var)'**
  String get chronicleHasEnd;

  /// No description provided for @chronicleEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get chronicleEnd;

  /// No description provided for @chronicleKnownYearOnly.
  ///
  /// In tr, this message translates to:
  /// **'Yalnız yıl biliniyor'**
  String get chronicleKnownYearOnly;

  /// No description provided for @chronicleEras.
  ///
  /// In tr, this message translates to:
  /// **'Çağlar'**
  String get chronicleEras;

  /// No description provided for @chronicleNewEra.
  ///
  /// In tr, this message translates to:
  /// **'Yeni çağ'**
  String get chronicleNewEra;

  /// No description provided for @chronicleEraName.
  ///
  /// In tr, this message translates to:
  /// **'Çağın adı'**
  String get chronicleEraName;

  /// No description provided for @chronicleEraStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç yılı'**
  String get chronicleEraStart;

  /// No description provided for @chronicleEraEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş yılı (boşsa sürüyor)'**
  String get chronicleEraEnd;

  /// No description provided for @chronicleOngoing.
  ///
  /// In tr, this message translates to:
  /// **'sürüyor'**
  String get chronicleOngoing;

  /// No description provided for @chronicleNoEra.
  ///
  /// In tr, this message translates to:
  /// **'Çağsız'**
  String get chronicleNoEra;

  /// No description provided for @chronicleSearch.
  ///
  /// In tr, this message translates to:
  /// **'Tarihçede ara'**
  String get chronicleSearch;

  /// No description provided for @chronicleDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Bu olay kalıcı olarak silinsin mi?'**
  String get chronicleDeleteConfirm;

  /// No description provided for @chronicleEventsOnDay.
  ///
  /// In tr, this message translates to:
  /// **'{date} günü'**
  String chronicleEventsOnDay(String date);

  /// No description provided for @chronicleNoEventsOnDay.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için kayıt yok.'**
  String get chronicleNoEventsOnDay;

  /// No description provided for @chronicleAddHere.
  ///
  /// In tr, this message translates to:
  /// **'Bu güne olay ekle'**
  String get chronicleAddHere;

  /// No description provided for @chronicleOnlySecret.
  ///
  /// In tr, this message translates to:
  /// **'Yalnız gizli olaylar'**
  String get chronicleOnlySecret;

  /// No description provided for @restPartyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Parti molası'**
  String get restPartyTitle;

  /// No description provided for @restPartyHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçili karakterlere aynı anda mola verir; savaş listesindeki canlar da güncellenir.'**
  String get restPartyHint;

  /// No description provided for @restEveryone.
  ///
  /// In tr, this message translates to:
  /// **'Herkes'**
  String get restEveryone;

  /// No description provided for @restShortOpenHint.
  ///
  /// In tr, this message translates to:
  /// **'Dinlenme oyunculara açıldı. Herkes kendi panelinden istediği kadar hit die harcar; sen yalnızca izliyorsun.'**
  String get restShortOpenHint;

  /// No description provided for @restShortFinish.
  ///
  /// In tr, this message translates to:
  /// **'Dinlenmeyi bitir'**
  String get restShortFinish;

  /// No description provided for @restNeedSession.
  ///
  /// In tr, this message translates to:
  /// **'Önce Oturum sekmesinden masayı aç.'**
  String get restNeedSession;

  /// No description provided for @restShort.
  ///
  /// In tr, this message translates to:
  /// **'Kısa mola'**
  String get restShort;

  /// No description provided for @restLong.
  ///
  /// In tr, this message translates to:
  /// **'Uzun mola'**
  String get restLong;

  /// No description provided for @restHitDiceLeft.
  ///
  /// In tr, this message translates to:
  /// **'{left} / {total} hit dice'**
  String restHitDiceLeft(int left, int total);

  /// No description provided for @restLongConfirm.
  ///
  /// In tr, this message translates to:
  /// **'{count} karakter uzun molaya çekilecek: can dolar, büyü yuvaları ve hit dice\'ın yarısı geri gelir, tükenmişlik 1 azalır.'**
  String restLongConfirm(int count);

  /// No description provided for @restAdvanceDay.
  ///
  /// In tr, this message translates to:
  /// **'Takvimde 1 gün ilerlet'**
  String get restAdvanceDay;

  /// No description provided for @restLoggedLong.
  ///
  /// In tr, this message translates to:
  /// **'Uzun mola ({count} karakter)'**
  String restLoggedLong(int count);

  /// No description provided for @restAnnounceLong.
  ///
  /// In tr, this message translates to:
  /// **'Ekip uzun molaya çekildi.'**
  String get restAnnounceLong;

  /// No description provided for @aiToolEncounter.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma Üretici'**
  String get aiToolEncounter;

  /// No description provided for @encounterEnvironment.
  ///
  /// In tr, this message translates to:
  /// **'Ortam / tema (isteğe bağlı)'**
  String get encounterEnvironment;

  /// No description provided for @encounterEnvironmentHint.
  ///
  /// In tr, this message translates to:
  /// **'Ör. bataklık harabesi, buzul geçidi, liman deposu.'**
  String get encounterEnvironmentHint;

  /// No description provided for @encounterBudgetHint.
  ///
  /// In tr, this message translates to:
  /// **'Hedef canavar XP\'si: {xp}'**
  String encounterBudgetHint(int xp);

  /// No description provided for @encounterSummary.
  ///
  /// In tr, this message translates to:
  /// **'Sahne'**
  String get encounterSummary;

  /// No description provided for @encounterMonsters.
  ///
  /// In tr, this message translates to:
  /// **'Canavarlar'**
  String get encounterMonsters;

  /// No description provided for @encounterTerrain.
  ///
  /// In tr, this message translates to:
  /// **'Arazi'**
  String get encounterTerrain;

  /// No description provided for @encounterTactics.
  ///
  /// In tr, this message translates to:
  /// **'Taktikler'**
  String get encounterTactics;

  /// No description provided for @encounterCreate.
  ///
  /// In tr, this message translates to:
  /// **'Savaşa dönüştür'**
  String get encounterCreate;

  /// No description provided for @encounterFallbackName.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma'**
  String get encounterFallbackName;

  /// No description provided for @encounterCreated.
  ///
  /// In tr, this message translates to:
  /// **'{name} savaş olarak oluşturuldu'**
  String encounterCreated(String name);

  /// No description provided for @encounterCreatedPartial.
  ///
  /// In tr, this message translates to:
  /// **'{name} oluşturuldu — kütüphanede bulunamayanlar: {missing}'**
  String encounterCreatedPartial(String name, String missing);

  /// No description provided for @encounterNoCandidates.
  ///
  /// In tr, this message translates to:
  /// **'Bu seviye için kütüphanede uygun canavar bulunamadı.'**
  String get encounterNoCandidates;

  /// No description provided for @navChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get navChat;

  /// No description provided for @chatGeneral.
  ///
  /// In tr, this message translates to:
  /// **'Genel'**
  String get chatGeneral;

  /// No description provided for @chatWhisper.
  ///
  /// In tr, this message translates to:
  /// **'Fısıltı'**
  String get chatWhisper;

  /// No description provided for @chatPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Mesajınızı yazın...'**
  String get chatPlaceholder;

  /// No description provided for @chatTo.
  ///
  /// In tr, this message translates to:
  /// **'Kime:'**
  String get chatTo;

  /// No description provided for @chatDm.
  ///
  /// In tr, this message translates to:
  /// **'DM'**
  String get chatDm;

  /// No description provided for @chatEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mesaj yok. Masaya bir şey söyle.'**
  String get chatEmpty;

  /// No description provided for @chatNeedSession.
  ///
  /// In tr, this message translates to:
  /// **'Önce Oturum sekmesinden masayı aç.'**
  String get chatNeedSession;

  /// No description provided for @presenceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncular'**
  String get presenceTitle;

  /// No description provided for @presenceDragHint.
  ///
  /// In tr, this message translates to:
  /// **'Taşımak için basılı tutup sürükle'**
  String get presenceDragHint;

  /// No description provided for @presenceNoPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bağlı oyuncu yok.'**
  String get presenceNoPlayers;

  /// No description provided for @presenceActive.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get presenceActive;

  /// No description provided for @presenceAway.
  ///
  /// In tr, this message translates to:
  /// **'Uzakta'**
  String get presenceAway;

  /// No description provided for @presenceOffline.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı'**
  String get presenceOffline;

  /// No description provided for @lastSeenSeconds.
  ///
  /// In tr, this message translates to:
  /// **'son görülme {n}sn önce'**
  String lastSeenSeconds(int n);

  /// No description provided for @lastSeenMinutes.
  ///
  /// In tr, this message translates to:
  /// **'son görülme {n}dk önce'**
  String lastSeenMinutes(int n);

  /// No description provided for @lastSeenHours.
  ///
  /// In tr, this message translates to:
  /// **'son görülme {n}sa önce'**
  String lastSeenHours(int n);

  /// No description provided for @questNoTargets.
  ///
  /// In tr, this message translates to:
  /// **'Hiç oyuncu seçilmedi'**
  String get questNoTargets;

  /// No description provided for @questHide.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşımı kaldır'**
  String get questHide;

  /// No description provided for @questComplete.
  ///
  /// In tr, this message translates to:
  /// **'Tamamla'**
  String get questComplete;

  /// No description provided for @questReopen.
  ///
  /// In tr, this message translates to:
  /// **'Geri aç'**
  String get questReopen;

  /// No description provided for @questSharePick.
  ///
  /// In tr, this message translates to:
  /// **'Hangi oyunculara gösterilsin?'**
  String get questSharePick;

  /// No description provided for @questShow.
  ///
  /// In tr, this message translates to:
  /// **'Göster'**
  String get questShow;

  /// No description provided for @questShared.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara gösterildi'**
  String get questShared;

  /// No description provided for @questNoCharacters.
  ///
  /// In tr, this message translates to:
  /// **'Önce karakter oluştur.'**
  String get questNoCharacters;

  /// No description provided for @questDelete.
  ///
  /// In tr, this message translates to:
  /// **'Görevi sil'**
  String get questDelete;

  /// No description provided for @questDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Bu görev kalıcı olarak silinsin mi?'**
  String get questDeleteConfirm;

  /// No description provided for @questEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Görev'**
  String get questEditTitle;

  /// No description provided for @questTitleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get questTitleLabel;

  /// No description provided for @questTextLabel.
  ///
  /// In tr, this message translates to:
  /// **'Görev metni (oyunculara)'**
  String get questTextLabel;

  /// No description provided for @questTextHelper.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara gösterilen metin.'**
  String get questTextHelper;

  /// No description provided for @questRewardLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ödül'**
  String get questRewardLabel;

  /// No description provided for @questDmLabel.
  ///
  /// In tr, this message translates to:
  /// **'DM notu (yalnız sen)'**
  String get questDmLabel;

  /// No description provided for @questDmHelper.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara gitmez.'**
  String get questDmHelper;

  /// No description provided for @questSendToQuests.
  ///
  /// In tr, this message translates to:
  /// **'Görevlere gönder'**
  String get questSendToQuests;

  /// No description provided for @questSavedToQuests.
  ///
  /// In tr, this message translates to:
  /// **'Görevler\'e eklendi'**
  String get questSavedToQuests;

  /// No description provided for @aiQuestRewardAuto.
  ///
  /// In tr, this message translates to:
  /// **'Görevlere gönderince bu para ve eşyalar görevin gerçek ödülü olur; görev tamamlanınca oyunculara ortak ganimet olarak açılır.'**
  String get aiQuestRewardAuto;

  /// No description provided for @questRealReward.
  ///
  /// In tr, this message translates to:
  /// **'Gerçek ödül (eşya + para)'**
  String get questRealReward;

  /// No description provided for @questRealRewardHint.
  ///
  /// In tr, this message translates to:
  /// **'Görevi tamamlayınca kabul eden oyunculara ortak ganimet olarak açılır. Bir eşyayı ilk kim alırsa onun olur; havuz boşalınca görev kapanır.'**
  String get questRealRewardHint;

  /// No description provided for @questRewardPending.
  ///
  /// In tr, this message translates to:
  /// **'Ödül dağıtımda'**
  String get questRewardPending;

  /// No description provided for @questRewardItemCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} eşya'**
  String questRewardItemCount(int count);

  /// No description provided for @questShareSection.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara gösterim'**
  String get questShareSection;

  /// No description provided for @questModeIndividual.
  ///
  /// In tr, this message translates to:
  /// **'Tek tek kabul'**
  String get questModeIndividual;

  /// No description provided for @questModeVote.
  ///
  /// In tr, this message translates to:
  /// **'Oylama'**
  String get questModeVote;

  /// No description provided for @questModeIndividualHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğin oyuncuların her biri görevi ayrı ayrı kabul eder ya da reddeder.'**
  String get questModeIndividualHint;

  /// No description provided for @questModeVoteHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğin oyuncular oylar. Kabul oyu %50 ve üzerindeyse görev hepsine verilir; altında kalırsa kimse alamaz.'**
  String get questModeVoteHint;

  /// No description provided for @questStartVote.
  ///
  /// In tr, this message translates to:
  /// **'Oylamayı başlat'**
  String get questStartVote;

  /// No description provided for @questVoteStarted.
  ///
  /// In tr, this message translates to:
  /// **'Oylama başlatıldı'**
  String get questVoteStarted;

  /// No description provided for @questVoteOngoing.
  ///
  /// In tr, this message translates to:
  /// **'Oylama sürüyor'**
  String get questVoteOngoing;

  /// No description provided for @questVotePassed.
  ///
  /// In tr, this message translates to:
  /// **'Oylama geçti — görev ekipte'**
  String get questVotePassed;

  /// No description provided for @questVoteFailed.
  ///
  /// In tr, this message translates to:
  /// **'Oylama düştü — kimse almadı'**
  String get questVoteFailed;

  /// No description provided for @compendiumMonsters.
  ///
  /// In tr, this message translates to:
  /// **'Canavarlar'**
  String get compendiumMonsters;

  /// No description provided for @compendiumSpells.
  ///
  /// In tr, this message translates to:
  /// **'Büyüler'**
  String get compendiumSpells;

  /// No description provided for @compendiumItems.
  ///
  /// In tr, this message translates to:
  /// **'Eşyalar'**
  String get compendiumItems;

  /// No description provided for @compendiumMagicItems.
  ///
  /// In tr, this message translates to:
  /// **'Büyülü Eşyalar'**
  String get compendiumMagicItems;

  /// No description provided for @compendiumFeats.
  ///
  /// In tr, this message translates to:
  /// **'Feat\'ler'**
  String get compendiumFeats;

  /// No description provided for @compendiumSpecies.
  ///
  /// In tr, this message translates to:
  /// **'Irklar'**
  String get compendiumSpecies;

  /// No description provided for @compendiumBackgrounds.
  ///
  /// In tr, this message translates to:
  /// **'Geçmişler'**
  String get compendiumBackgrounds;

  /// No description provided for @searchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ara...'**
  String get searchHint;

  /// No description provided for @filters.
  ///
  /// In tr, this message translates to:
  /// **'Filtreler'**
  String get filters;

  /// No description provided for @clearFilters.
  ///
  /// In tr, this message translates to:
  /// **'Filtreleri temizle'**
  String get clearFilters;

  /// No description provided for @noResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı'**
  String get noResults;

  /// No description provided for @filterSchool.
  ///
  /// In tr, this message translates to:
  /// **'Okul'**
  String get filterSchool;

  /// No description provided for @filterRarity.
  ///
  /// In tr, this message translates to:
  /// **'Nadirlik'**
  String get filterRarity;

  /// No description provided for @importTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerik hazırlanıyor'**
  String get importTitle;

  /// No description provided for @importSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Kural kitaplığı ilk kez kuruluyor, bu bir kez yapılır.'**
  String get importSubtitle;

  /// No description provided for @importStepWriting.
  ///
  /// In tr, this message translates to:
  /// **'Veritabanına yazılıyor: {table}'**
  String importStepWriting(String table);

  /// No description provided for @importFailed.
  ///
  /// In tr, this message translates to:
  /// **'İçerik kurulumu başarısız oldu'**
  String get importFailed;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get add;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get ok;

  /// No description provided for @create.
  ///
  /// In tr, this message translates to:
  /// **'Oluştur'**
  String get create;

  /// No description provided for @remove.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get remove;

  /// No description provided for @licenseTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerik lisansları'**
  String get licenseTitle;

  /// No description provided for @licenseBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu uygulamadaki kural içeriği System Reference Document 5.2 (CC-BY 4.0) ve Open5e üzerinden dağıtılan açık lisanslı setlerden alınmıştır. Kişisel kitaplığınızdan içe aktardığınız içerik yalnızca bu cihazda saklanır.'**
  String get licenseBody;

  /// No description provided for @sheetTitleFallback.
  ///
  /// In tr, this message translates to:
  /// **'Karakter'**
  String get sheetTitleFallback;

  /// No description provided for @sheetRollDice.
  ///
  /// In tr, this message translates to:
  /// **'Zar at'**
  String get sheetRollDice;

  /// No description provided for @sheetLevelUp.
  ///
  /// In tr, this message translates to:
  /// **'Seviye atla'**
  String get sheetLevelUp;

  /// No description provided for @sheetClassCounters.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf sayaçları'**
  String get sheetClassCounters;

  /// No description provided for @sheetFeatures.
  ///
  /// In tr, this message translates to:
  /// **'Yetenekler'**
  String get sheetFeatures;

  /// No description provided for @sheetAddFeature.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek ekle'**
  String get sheetAddFeature;

  /// No description provided for @sheetEditFeature.
  ///
  /// In tr, this message translates to:
  /// **'Yeteneği düzenle'**
  String get sheetEditFeature;

  /// No description provided for @sheetFeatureName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get sheetFeatureName;

  /// No description provided for @sheetFeatureDesc.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get sheetFeatureDesc;

  /// No description provided for @sheetFeatureUses.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım sınırı'**
  String get sheetFeatureUses;

  /// No description provided for @sheetFeatureUsesHint.
  ///
  /// In tr, this message translates to:
  /// **'Boş bırakılırsa sınırsız, ör. dinlenme başına 1 kullanım için \"1\".'**
  String get sheetFeatureUsesHint;

  /// No description provided for @sheetFeatureCustom.
  ///
  /// In tr, this message translates to:
  /// **'Özel'**
  String get sheetFeatureCustom;

  /// No description provided for @sheetDeleteFeatureConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Bu yetenek silinsin mi?'**
  String get sheetDeleteFeatureConfirm;

  /// No description provided for @sheetDamage.
  ///
  /// In tr, this message translates to:
  /// **'Hasar'**
  String get sheetDamage;

  /// No description provided for @sheetHeal.
  ///
  /// In tr, this message translates to:
  /// **'İyileş'**
  String get sheetHeal;

  /// No description provided for @sheetGrantTempHp.
  ///
  /// In tr, this message translates to:
  /// **'Geçici can ver'**
  String get sheetGrantTempHp;

  /// No description provided for @sheetDeathSaves.
  ///
  /// In tr, this message translates to:
  /// **'Ölüm kurtarma atışları'**
  String get sheetDeathSaves;

  /// No description provided for @sheetSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Başarılı'**
  String get sheetSuccess;

  /// No description provided for @sheetFailure.
  ///
  /// In tr, this message translates to:
  /// **'Başarısız'**
  String get sheetFailure;

  /// No description provided for @sheetInitiative.
  ///
  /// In tr, this message translates to:
  /// **'İnisiyatif'**
  String get sheetInitiative;

  /// No description provided for @sheetSpeed.
  ///
  /// In tr, this message translates to:
  /// **'Hız'**
  String get sheetSpeed;

  /// No description provided for @sheetProficiency.
  ///
  /// In tr, this message translates to:
  /// **'Yeterlilik'**
  String get sheetProficiency;

  /// No description provided for @sheetPassivePerception.
  ///
  /// In tr, this message translates to:
  /// **'Pasif Algı'**
  String get sheetPassivePerception;

  /// No description provided for @sheetCarry.
  ///
  /// In tr, this message translates to:
  /// **'Taşıma'**
  String get sheetCarry;

  /// No description provided for @sheetSavingThrows.
  ///
  /// In tr, this message translates to:
  /// **'Kurtarma atışları'**
  String get sheetSavingThrows;

  /// No description provided for @sheetSkills.
  ///
  /// In tr, this message translates to:
  /// **'Beceriler'**
  String get sheetSkills;

  /// No description provided for @sheetSpellSlots.
  ///
  /// In tr, this message translates to:
  /// **'Büyü yuvaları'**
  String get sheetSpellSlots;

  /// No description provided for @sheetStatus.
  ///
  /// In tr, this message translates to:
  /// **'Durum'**
  String get sheetStatus;

  /// No description provided for @sheetInspiration.
  ///
  /// In tr, this message translates to:
  /// **'İlham (Inspiration)'**
  String get sheetInspiration;

  /// No description provided for @sheetExhaustion.
  ///
  /// In tr, this message translates to:
  /// **'Tükenmişlik'**
  String get sheetExhaustion;

  /// No description provided for @sheetExperience.
  ///
  /// In tr, this message translates to:
  /// **'Deneyim (XP)'**
  String get sheetExperience;

  /// No description provided for @sheetXpToNext.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki seviye (Sv {nextLevel}) için {xpNeeded} XP'**
  String sheetXpToNext(int nextLevel, int xpNeeded);

  /// No description provided for @sheetXpMaxLevel.
  ///
  /// In tr, this message translates to:
  /// **'Azami seviye (Sv {level})'**
  String sheetXpMaxLevel(int level);

  /// No description provided for @sheetInventory.
  ///
  /// In tr, this message translates to:
  /// **'Envanter'**
  String get sheetInventory;

  /// No description provided for @sheetBagEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Çanta boş.'**
  String get sheetBagEmpty;

  /// No description provided for @sheetAddItem.
  ///
  /// In tr, this message translates to:
  /// **'Eşya ekle'**
  String get sheetAddItem;

  /// No description provided for @sheetEquip.
  ///
  /// In tr, this message translates to:
  /// **'Giy/kuşan'**
  String get sheetEquip;

  /// No description provided for @sheetUnequip.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get sheetUnequip;

  /// No description provided for @sheetItemTab.
  ///
  /// In tr, this message translates to:
  /// **'Eşya'**
  String get sheetItemTab;

  /// No description provided for @sheetMagicTab.
  ///
  /// In tr, this message translates to:
  /// **'Büyülü'**
  String get sheetMagicTab;

  /// No description provided for @sheetCustomTab.
  ///
  /// In tr, this message translates to:
  /// **'Serbest'**
  String get sheetCustomTab;

  /// No description provided for @sheetItemName.
  ///
  /// In tr, this message translates to:
  /// **'Eşya adı'**
  String get sheetItemName;

  /// No description provided for @sheetPurse.
  ///
  /// In tr, this message translates to:
  /// **'Kese'**
  String get sheetPurse;

  /// No description provided for @sheetRest.
  ///
  /// In tr, this message translates to:
  /// **'Dinlen'**
  String get sheetRest;

  /// No description provided for @sheetShortRest.
  ///
  /// In tr, this message translates to:
  /// **'Kısa dinlen (hit die)'**
  String get sheetShortRest;

  /// No description provided for @sheetLongRest.
  ///
  /// In tr, this message translates to:
  /// **'Uzun dinlen (tam yenile)'**
  String get sheetLongRest;

  /// No description provided for @sheetLongRestDone.
  ///
  /// In tr, this message translates to:
  /// **'Uzun dinlenildi: HP, yuvalar, hit dice yenilendi.'**
  String get sheetLongRestDone;

  /// No description provided for @sheetNoHitDice.
  ///
  /// In tr, this message translates to:
  /// **'Harcanacak hit dice kalmadı.'**
  String get sheetNoHitDice;

  /// No description provided for @sheetPortrait.
  ///
  /// In tr, this message translates to:
  /// **'Portre'**
  String get sheetPortrait;

  /// No description provided for @sheetPortraitHint.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncular karakter sekmesinde görür.'**
  String get sheetPortraitHint;

  /// No description provided for @sheetUploadPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yükle'**
  String get sheetUploadPhoto;

  /// No description provided for @sheetChange.
  ///
  /// In tr, this message translates to:
  /// **'Değiştir'**
  String get sheetChange;

  /// No description provided for @sheetRemove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get sheetRemove;

  /// No description provided for @sheetSpells.
  ///
  /// In tr, this message translates to:
  /// **'Büyüler'**
  String get sheetSpells;

  /// No description provided for @sheetAddSpell.
  ///
  /// In tr, this message translates to:
  /// **'Büyü ekle'**
  String get sheetAddSpell;

  /// No description provided for @sheetNoSpellsAdded.
  ///
  /// In tr, this message translates to:
  /// **'Henüz büyü eklenmedi.'**
  String get sheetNoSpellsAdded;

  /// No description provided for @sheetAlways.
  ///
  /// In tr, this message translates to:
  /// **'her zaman'**
  String get sheetAlways;

  /// No description provided for @sheetPrepared.
  ///
  /// In tr, this message translates to:
  /// **'Hazır'**
  String get sheetPrepared;

  /// No description provided for @sheetPrepare.
  ///
  /// In tr, this message translates to:
  /// **'Hazırla'**
  String get sheetPrepare;

  /// No description provided for @sheetSearchSpell.
  ///
  /// In tr, this message translates to:
  /// **'Büyü ara'**
  String get sheetSearchSpell;

  /// No description provided for @sheetOnlyClassSpells.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca sınıfına uygun'**
  String get sheetOnlyClassSpells;

  /// No description provided for @sheetStory.
  ///
  /// In tr, this message translates to:
  /// **'Hikaye'**
  String get sheetStory;

  /// No description provided for @sheetBackstory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş / hikaye'**
  String get sheetBackstory;

  /// No description provided for @sheetAppearance.
  ///
  /// In tr, this message translates to:
  /// **'Görünüş'**
  String get sheetAppearance;

  /// No description provided for @sheetPersonality.
  ///
  /// In tr, this message translates to:
  /// **'Kişilik'**
  String get sheetPersonality;

  /// No description provided for @sheetIdeal.
  ///
  /// In tr, this message translates to:
  /// **'İdeal'**
  String get sheetIdeal;

  /// No description provided for @sheetBond.
  ///
  /// In tr, this message translates to:
  /// **'Bağ'**
  String get sheetBond;

  /// No description provided for @sheetFlaw.
  ///
  /// In tr, this message translates to:
  /// **'Kusur'**
  String get sheetFlaw;

  /// No description provided for @combatNewEncounter.
  ///
  /// In tr, this message translates to:
  /// **'Yeni karşılaşma'**
  String get combatNewEncounter;

  /// No description provided for @combatPreparing.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanıyor'**
  String get combatPreparing;

  /// No description provided for @combatEncounterName.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma'**
  String get combatEncounterName;

  /// No description provided for @combatNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get combatNameLabel;

  /// No description provided for @combatCreate.
  ///
  /// In tr, this message translates to:
  /// **'Oluştur'**
  String get combatCreate;

  /// No description provided for @combatEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma yok'**
  String get combatEmpty;

  /// No description provided for @combatEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Yeni bir karşılaşma kurup canavar ve oyuncuları ekle.'**
  String get combatEmptyHint;

  /// No description provided for @combatAddMonster.
  ///
  /// In tr, this message translates to:
  /// **'Canavar ekle'**
  String get combatAddMonster;

  /// No description provided for @combatAddParty.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncuları ekle'**
  String get combatAddParty;

  /// No description provided for @combatAddHint.
  ///
  /// In tr, this message translates to:
  /// **'Üstteki butonlardan canavar ve oyuncu ekle.'**
  String get combatAddHint;

  /// No description provided for @combatNeedCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Önce karakter oluştur.'**
  String get combatNeedCharacter;

  /// No description provided for @combatEditInitiative.
  ///
  /// In tr, this message translates to:
  /// **'İnisiyatifleri düzenle, sonra başlat'**
  String get combatEditInitiative;

  /// No description provided for @combatEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitir'**
  String get combatEnd;

  /// No description provided for @combatNext.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki'**
  String get combatNext;

  /// No description provided for @combatStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlat'**
  String get combatStart;

  /// No description provided for @combatConcentration.
  ///
  /// In tr, this message translates to:
  /// **'Konsantrasyon'**
  String get combatConcentration;

  /// No description provided for @combatStatBlock.
  ///
  /// In tr, this message translates to:
  /// **'Stat bloğu'**
  String get combatStatBlock;

  /// No description provided for @combatEditConditions.
  ///
  /// In tr, this message translates to:
  /// **'Durum ekle/çıkar'**
  String get combatEditConditions;

  /// No description provided for @combatStartConcentration.
  ///
  /// In tr, this message translates to:
  /// **'Konsantrasyon başlat'**
  String get combatStartConcentration;

  /// No description provided for @combatEndConcentration.
  ///
  /// In tr, this message translates to:
  /// **'Konsantrasyonu bitir'**
  String get combatEndConcentration;

  /// No description provided for @combatMarkDefeated.
  ///
  /// In tr, this message translates to:
  /// **'Yenildi işaretle'**
  String get combatMarkDefeated;

  /// No description provided for @combatRevive.
  ///
  /// In tr, this message translates to:
  /// **'Geri getir'**
  String get combatRevive;

  /// No description provided for @combatRemove.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get combatRemove;

  /// No description provided for @combatDamage.
  ///
  /// In tr, this message translates to:
  /// **'Hasar'**
  String get combatDamage;

  /// No description provided for @combatHeal.
  ///
  /// In tr, this message translates to:
  /// **'İyileştir'**
  String get combatHeal;

  /// No description provided for @combatSearchMonster.
  ///
  /// In tr, this message translates to:
  /// **'Canavar ara...'**
  String get combatSearchMonster;

  /// No description provided for @combatCount.
  ///
  /// In tr, this message translates to:
  /// **'Adet'**
  String get combatCount;

  /// No description provided for @combatRollHp.
  ///
  /// In tr, this message translates to:
  /// **'HP zar at'**
  String get combatRollHp;

  /// No description provided for @combatRoundN.
  ///
  /// In tr, this message translates to:
  /// **'{n}. tur'**
  String combatRoundN(int n);

  /// No description provided for @combatInitiativeTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} — inisiyatif'**
  String combatInitiativeTitle(String name);

  /// No description provided for @combatConditionsTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} — durumlar'**
  String combatConditionsTitle(String name);

  /// No description provided for @combatConditionsExpired.
  ///
  /// In tr, this message translates to:
  /// **'{name}: {conditions} sona erdi'**
  String combatConditionsExpired(String name, String conditions);

  /// No description provided for @combatDurationRounds.
  ///
  /// In tr, this message translates to:
  /// **'Süre (tur)'**
  String get combatDurationRounds;

  /// No description provided for @combatDurationUnlimited.
  ///
  /// In tr, this message translates to:
  /// **'Süresiz'**
  String get combatDurationUnlimited;

  /// No description provided for @combatAttackRoll.
  ///
  /// In tr, this message translates to:
  /// **'Saldır'**
  String get combatAttackRoll;

  /// No description provided for @combatToHit.
  ///
  /// In tr, this message translates to:
  /// **'İsabet'**
  String get combatToHit;

  /// No description provided for @combatCritical.
  ///
  /// In tr, this message translates to:
  /// **'Kritik'**
  String get combatCritical;

  /// No description provided for @combatCriticalHit.
  ///
  /// In tr, this message translates to:
  /// **'Kritik!'**
  String get combatCriticalHit;

  /// No description provided for @combatAdvantage.
  ///
  /// In tr, this message translates to:
  /// **'Avantaj'**
  String get combatAdvantage;

  /// No description provided for @combatDisadvantage.
  ///
  /// In tr, this message translates to:
  /// **'Dezavantaj'**
  String get combatDisadvantage;

  /// No description provided for @combatNormalRoll.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get combatNormalRoll;

  /// No description provided for @combatDifficulty.
  ///
  /// In tr, this message translates to:
  /// **'Zorluk'**
  String get combatDifficulty;

  /// No description provided for @combatDiffTrivial.
  ///
  /// In tr, this message translates to:
  /// **'Önemsiz'**
  String get combatDiffTrivial;

  /// No description provided for @combatDiffLow.
  ///
  /// In tr, this message translates to:
  /// **'Kolay'**
  String get combatDiffLow;

  /// No description provided for @combatDiffModerate.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get combatDiffModerate;

  /// No description provided for @combatDiffHigh.
  ///
  /// In tr, this message translates to:
  /// **'Zor'**
  String get combatDiffHigh;

  /// No description provided for @combatDiffDeadly.
  ///
  /// In tr, this message translates to:
  /// **'Çok Zor'**
  String get combatDiffDeadly;

  /// No description provided for @combatLegendaryActions.
  ///
  /// In tr, this message translates to:
  /// **'Efsanevi eylemler'**
  String get combatLegendaryActions;

  /// No description provided for @combatLegendaryShort.
  ///
  /// In tr, this message translates to:
  /// **'Efsanevi'**
  String get combatLegendaryShort;

  /// No description provided for @combatLegendaryResistShort.
  ///
  /// In tr, this message translates to:
  /// **'Direnç'**
  String get combatLegendaryResistShort;

  /// No description provided for @combatLegendaryPerRound.
  ///
  /// In tr, this message translates to:
  /// **'Tur başına hak'**
  String get combatLegendaryPerRound;

  /// No description provided for @combatLegendaryResetHint.
  ///
  /// In tr, this message translates to:
  /// **'Dokun = harca, uzun bas = sıfırla. Efsanevi eylemler canavarın turu başlayınca kendiliğinden tazelenir; direnç günlüktür.'**
  String get combatLegendaryResetHint;

  /// No description provided for @combatLegendaryNone.
  ///
  /// In tr, this message translates to:
  /// **'Bu canavarın efsanevi eylemi yok.'**
  String get combatLegendaryNone;

  /// No description provided for @combatLegendaryCost.
  ///
  /// In tr, this message translates to:
  /// **'{n} hak'**
  String combatLegendaryCost(Object n);

  /// No description provided for @combatLegendaryTooltip.
  ///
  /// In tr, this message translates to:
  /// **'{remaining}/{max} kaldı'**
  String combatLegendaryTooltip(Object max, Object remaining);

  /// No description provided for @combatConditionLongPressHint.
  ///
  /// In tr, this message translates to:
  /// **'Dokun: süre · Uzun bas: kural metni'**
  String get combatConditionLongPressHint;

  /// No description provided for @compendiumConditions.
  ///
  /// In tr, this message translates to:
  /// **'Durumlar'**
  String get compendiumConditions;

  /// No description provided for @compendiumConditionsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Durum efektleri yüklenmedi.'**
  String get compendiumConditionsEmpty;

  /// No description provided for @combatBudgetSummary.
  ///
  /// In tr, this message translates to:
  /// **'{xp} XP · bütçe D{low} / O{moderate} / Y{high}'**
  String combatBudgetSummary(int xp, int low, int moderate, int high);

  /// No description provided for @combatUncounted.
  ///
  /// In tr, this message translates to:
  /// **'{count} katılımcı XP’siz, hesaba katılmadı.'**
  String combatUncounted(int count);

  /// No description provided for @combatAwardXp.
  ///
  /// In tr, this message translates to:
  /// **'XP ver'**
  String get combatAwardXp;

  /// No description provided for @combatAwardXpNone.
  ///
  /// In tr, this message translates to:
  /// **'Verilecek canavar XP’si ya da oyuncu yok.'**
  String get combatAwardXpNone;

  /// No description provided for @combatAwardXpConfirm.
  ///
  /// In tr, this message translates to:
  /// **'{total} XP, {players} oyuncuya ({each}’er) verilsin mi?'**
  String combatAwardXpConfirm(int total, int players, int each);

  /// No description provided for @combatAwardXpDone.
  ///
  /// In tr, this message translates to:
  /// **'XP verildi ({each}’er).'**
  String combatAwardXpDone(int each);

  /// No description provided for @logXpAwarded.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma XP’si: {total} → {players} oyuncu ({each}’er)'**
  String logXpAwarded(int total, int players, int each);

  /// No description provided for @worldNpcs.
  ///
  /// In tr, this message translates to:
  /// **'NPC’ler'**
  String get worldNpcs;

  /// No description provided for @worldNewLocation.
  ///
  /// In tr, this message translates to:
  /// **'Yeni yer'**
  String get worldNewLocation;

  /// No description provided for @worldShowToPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara göster'**
  String get worldShowToPlayers;

  /// No description provided for @worldAddChild.
  ///
  /// In tr, this message translates to:
  /// **'Alt yer ekle'**
  String get worldAddChild;

  /// No description provided for @worldRename.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden adlandır'**
  String get worldRename;

  /// No description provided for @worldDeleteConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu yer, altındaki tüm yerler, pinleri ve haritaları kalıcı olarak silinecek.'**
  String get worldDeleteConfirmBody;

  /// No description provided for @worldEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Dünya boş'**
  String get worldEmpty;

  /// No description provided for @worldEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir kıta ya da bölge ekleyip haritasını yükle. Harita üstüne koyduğun pinlerden alt yerlere girebilirsin.'**
  String get worldEmptyHint;

  /// No description provided for @worldNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get worldNameLabel;

  /// No description provided for @worldParentLocation.
  ///
  /// In tr, this message translates to:
  /// **'Üst yer'**
  String get worldParentLocation;

  /// No description provided for @worldBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get worldBack;

  /// No description provided for @worldAddPin.
  ///
  /// In tr, this message translates to:
  /// **'Pin ekle'**
  String get worldAddPin;

  /// No description provided for @worldStopAddingPin.
  ///
  /// In tr, this message translates to:
  /// **'Pin eklemeyi bırak'**
  String get worldStopAddingPin;

  /// No description provided for @worldUploadMap.
  ///
  /// In tr, this message translates to:
  /// **'Harita yükle'**
  String get worldUploadMap;

  /// No description provided for @worldChangeMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritayı değiştir'**
  String get worldChangeMap;

  /// No description provided for @worldRemoveMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritayı kaldır'**
  String get worldRemoveMap;

  /// No description provided for @worldDeleteLocation.
  ///
  /// In tr, this message translates to:
  /// **'Bu yeri sil'**
  String get worldDeleteLocation;

  /// No description provided for @worldTapToPlacePin.
  ///
  /// In tr, this message translates to:
  /// **'Pin koymak için haritaya dokun.'**
  String get worldTapToPlacePin;

  /// No description provided for @worldPinDragHint.
  ///
  /// In tr, this message translates to:
  /// **'Pinleri sürükleyerek taşıyabilirsin. Dokununca düzenlenir.'**
  String get worldPinDragHint;

  /// No description provided for @worldNoMap.
  ///
  /// In tr, this message translates to:
  /// **'Harita yok'**
  String get worldNoMap;

  /// No description provided for @worldNoMapHint.
  ///
  /// In tr, this message translates to:
  /// **'Haritayı yükledikten sonra üstüne pin koyabilir, pinlerden alt yerlere girebilirsin.'**
  String get worldNoMapHint;

  /// No description provided for @worldMapNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Harita dosyası bulunamadı.'**
  String get worldMapNotFound;

  /// No description provided for @travelTitle.
  ///
  /// In tr, this message translates to:
  /// **'Seyahat'**
  String get travelTitle;

  /// No description provided for @travelScaleTitle.
  ///
  /// In tr, this message translates to:
  /// **'Harita ölçeği'**
  String get travelScaleTitle;

  /// No description provided for @travelScaleHint.
  ///
  /// In tr, this message translates to:
  /// **'Haritanın gerçek dünyada kaç mil olduğunu gir. Pinler arası mesafe buradan hesaplanır.'**
  String get travelScaleHint;

  /// No description provided for @travelWidthMiles.
  ///
  /// In tr, this message translates to:
  /// **'Genişlik (mil)'**
  String get travelWidthMiles;

  /// No description provided for @travelHeightMiles.
  ///
  /// In tr, this message translates to:
  /// **'Yükseklik (mil)'**
  String get travelHeightMiles;

  /// No description provided for @travelHeightAuto.
  ///
  /// In tr, this message translates to:
  /// **'Boş bırakılırsa haritanın en-boy oranından hesaplanır.'**
  String get travelHeightAuto;

  /// No description provided for @travelScaleMissing.
  ///
  /// In tr, this message translates to:
  /// **'Bu haritanın ölçeği girilmemiş. Mesafe hesaplamak için önce genişliği mil cinsinden gir.'**
  String get travelScaleMissing;

  /// No description provided for @travelScaleSet.
  ///
  /// In tr, this message translates to:
  /// **'Ölçeği gir'**
  String get travelScaleSet;

  /// No description provided for @travelScaleClear.
  ///
  /// In tr, this message translates to:
  /// **'Ölçeği temizle'**
  String get travelScaleClear;

  /// No description provided for @travelNoPins.
  ///
  /// In tr, this message translates to:
  /// **'Bu haritada pin yok. Rota kurmak için en az iki pin gerekli.'**
  String get travelNoPins;

  /// No description provided for @travelRoute.
  ///
  /// In tr, this message translates to:
  /// **'Rota'**
  String get travelRoute;

  /// No description provided for @travelAddStop.
  ///
  /// In tr, this message translates to:
  /// **'Durak ekle'**
  String get travelAddStop;

  /// No description provided for @travelPickTwoStops.
  ///
  /// In tr, this message translates to:
  /// **'En az iki durak seç.'**
  String get travelPickTwoStops;

  /// No description provided for @travelSpeed.
  ///
  /// In tr, this message translates to:
  /// **'Hız'**
  String get travelSpeed;

  /// No description provided for @travelGroupPaces.
  ///
  /// In tr, this message translates to:
  /// **'Yaya tempoları'**
  String get travelGroupPaces;

  /// No description provided for @travelGroupMounts.
  ///
  /// In tr, this message translates to:
  /// **'Binekler'**
  String get travelGroupMounts;

  /// No description provided for @travelGroupVehicles.
  ///
  /// In tr, this message translates to:
  /// **'Su araçları'**
  String get travelGroupVehicles;

  /// No description provided for @travelCustomSpeed.
  ///
  /// In tr, this message translates to:
  /// **'Özel hız'**
  String get travelCustomSpeed;

  /// No description provided for @travelMilesPerHour.
  ///
  /// In tr, this message translates to:
  /// **'Mil/saat'**
  String get travelMilesPerHour;

  /// No description provided for @travelHoursPerDay.
  ///
  /// In tr, this message translates to:
  /// **'Günde kaç saat yol'**
  String get travelHoursPerDay;

  /// No description provided for @travelExtraMiles.
  ///
  /// In tr, this message translates to:
  /// **'Ek mesafe (mil)'**
  String get travelExtraMiles;

  /// No description provided for @travelExtraMilesHint.
  ///
  /// In tr, this message translates to:
  /// **'Haritada karşılığı olmayan mesafe (ör. başka bir haritaya geçiş).'**
  String get travelExtraMilesHint;

  /// No description provided for @travelTotalMiles.
  ///
  /// In tr, this message translates to:
  /// **'Toplam {miles} mil'**
  String travelTotalMiles(Object miles);

  /// No description provided for @travelDuration.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün {hours} saat'**
  String travelDuration(Object days, Object hours);

  /// No description provided for @travelDurationDaysOnly.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün'**
  String travelDurationDaysOnly(Object days);

  /// No description provided for @travelAdvancesDays.
  ///
  /// In tr, this message translates to:
  /// **'Takvim {days} gün ilerler'**
  String travelAdvancesDays(Object days);

  /// No description provided for @travelConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuğu uygula'**
  String get travelConfirmTitle;

  /// No description provided for @travelConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'{route}\n\n{miles} mil — {duration}'**
  String travelConfirmBody(Object duration, Object miles, Object route);

  /// No description provided for @travelAdvanceCalendar.
  ///
  /// In tr, this message translates to:
  /// **'Takvimi {days} gün ilerlet'**
  String travelAdvanceCalendar(Object days);

  /// No description provided for @travelAnnounce.
  ///
  /// In tr, this message translates to:
  /// **'Parti {days} gün yol aldı.'**
  String travelAnnounce(Object days);

  /// No description provided for @travelDrawRoute.
  ///
  /// In tr, this message translates to:
  /// **'Haritada rota çiz'**
  String get travelDrawRoute;

  /// No description provided for @travelDrawRouteHint.
  ///
  /// In tr, this message translates to:
  /// **'Haritaya dokunarak durak ekle; bir pine dokunmak onu durak yapar. En az iki durak gerekir.'**
  String get travelDrawRouteHint;

  /// No description provided for @travelDrawRouteStops.
  ///
  /// In tr, this message translates to:
  /// **'{count} durak seçildi. “Planla” ile mesafe ve süreyi hesapla.'**
  String travelDrawRouteStops(int count);

  /// No description provided for @travelRouteUndo.
  ///
  /// In tr, this message translates to:
  /// **'Son durağı sil'**
  String get travelRouteUndo;

  /// No description provided for @travelRoutePlan.
  ///
  /// In tr, this message translates to:
  /// **'Planla'**
  String get travelRoutePlan;

  /// No description provided for @travelWaypoint.
  ///
  /// In tr, this message translates to:
  /// **'Ara nokta {index}'**
  String travelWaypoint(int index);

  /// No description provided for @journeyStart.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuğa başla'**
  String get journeyStart;

  /// No description provided for @journeyStarted.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuk başladı: {route} ({miles} mil)'**
  String journeyStarted(String route, String miles);

  /// No description provided for @journeyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuk'**
  String get journeyTitle;

  /// No description provided for @journeyNone.
  ///
  /// In tr, this message translates to:
  /// **'Süren bir yolculuk yok.'**
  String get journeyNone;

  /// No description provided for @journeyOpen.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuğu aç'**
  String get journeyOpen;

  /// No description provided for @journeyTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam yol'**
  String get journeyTotal;

  /// No description provided for @journeyTravelled.
  ///
  /// In tr, this message translates to:
  /// **'Gidilen'**
  String get journeyTravelled;

  /// No description provided for @journeyRemaining.
  ///
  /// In tr, this message translates to:
  /// **'Kalan'**
  String get journeyRemaining;

  /// No description provided for @journeyContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get journeyContinue;

  /// No description provided for @journeyPause.
  ///
  /// In tr, this message translates to:
  /// **'İlerlemeyi durdur'**
  String get journeyPause;

  /// No description provided for @journeyAbandon.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuğu bitir'**
  String get journeyAbandon;

  /// No description provided for @journeyAbandonConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuk kapatılır. Şimdiye kadar gidilen yol ve takvimde geçen günler geri alınmaz.'**
  String get journeyAbandonConfirm;

  /// No description provided for @journeyArrived.
  ///
  /// In tr, this message translates to:
  /// **'Hedefe varıldı.'**
  String get journeyArrived;

  /// No description provided for @journeyArrivedLog.
  ///
  /// In tr, this message translates to:
  /// **'Varış: {route} ({miles} mil)'**
  String journeyArrivedLog(String route, String miles);

  /// No description provided for @journeyEncounterTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yolda bir şey oldu — parti durdu'**
  String get journeyEncounterTitle;

  /// No description provided for @journeyDaysPassed.
  ///
  /// In tr, this message translates to:
  /// **'Bu adımda {days} gün geçti.'**
  String journeyDaysPassed(int days);

  /// No description provided for @journeyBannerProgress.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuk sürüyor — {travelled} / {total} mil'**
  String journeyBannerProgress(String travelled, String total);

  /// No description provided for @journeySpeedLine.
  ///
  /// In tr, this message translates to:
  /// **'{mph} mil/saat · günde {hours} saat'**
  String journeySpeedLine(String mph, String hours);

  /// No description provided for @travelEncounters.
  ///
  /// In tr, this message translates to:
  /// **'Rastgele karşılaşma'**
  String get travelEncounters;

  /// No description provided for @travelEncountersHint.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuğun her diliminde d20 atılır; eşiği tutturan atış için seçili tablodan bir satır çekilir. Sonuç yalnızca sana gösterilir.'**
  String get travelEncountersHint;

  /// No description provided for @travelEncounterTable.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma tablosu'**
  String get travelEncounterTable;

  /// No description provided for @travelEncounterNoTables.
  ///
  /// In tr, this message translates to:
  /// **'Henüz rastgele tablo yok. Tablolar sekmesinden bir tane ekle.'**
  String get travelEncounterNoTables;

  /// No description provided for @travelEncounterChance.
  ///
  /// In tr, this message translates to:
  /// **'Eşik: d20 ≥ {threshold}  (%{percent})'**
  String travelEncounterChance(int threshold, int percent);

  /// No description provided for @travelEncounterChecks.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kontrol sayısı'**
  String get travelEncounterChecks;

  /// No description provided for @travelEncounterWhen.
  ///
  /// In tr, this message translates to:
  /// **'{day}. gün · {check}. kontrol'**
  String travelEncounterWhen(int day, int check);

  /// No description provided for @travelEncounterMissingRow.
  ///
  /// In tr, this message translates to:
  /// **'Tabloda {roll} atışına karşılık gelen satır yok.'**
  String travelEncounterMissingRow(int roll);

  /// No description provided for @travelEncounterLogged.
  ///
  /// In tr, this message translates to:
  /// **'{day}. gün — karşılaşma: {text}'**
  String travelEncounterLogged(int day, String text);

  /// No description provided for @travelPaceFast.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı'**
  String get travelPaceFast;

  /// No description provided for @travelPaceNormal.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get travelPaceNormal;

  /// No description provided for @travelPaceSlow.
  ///
  /// In tr, this message translates to:
  /// **'Yavaş'**
  String get travelPaceSlow;

  /// No description provided for @travelMountPony.
  ///
  /// In tr, this message translates to:
  /// **'Midilli'**
  String get travelMountPony;

  /// No description provided for @travelMountDraftHorse.
  ///
  /// In tr, this message translates to:
  /// **'Yük atı'**
  String get travelMountDraftHorse;

  /// No description provided for @travelMountMastiff.
  ///
  /// In tr, this message translates to:
  /// **'Mastiff'**
  String get travelMountMastiff;

  /// No description provided for @travelMountElephant.
  ///
  /// In tr, this message translates to:
  /// **'Fil'**
  String get travelMountElephant;

  /// No description provided for @travelMountCamel.
  ///
  /// In tr, this message translates to:
  /// **'Deve'**
  String get travelMountCamel;

  /// No description provided for @travelMountRidingHorse.
  ///
  /// In tr, this message translates to:
  /// **'Koşu atı'**
  String get travelMountRidingHorse;

  /// No description provided for @travelMountWarhorse.
  ///
  /// In tr, this message translates to:
  /// **'Savaş atı'**
  String get travelMountWarhorse;

  /// No description provided for @travelVehicleRowboat.
  ///
  /// In tr, this message translates to:
  /// **'Kayık'**
  String get travelVehicleRowboat;

  /// No description provided for @travelVehicleKeelboat.
  ///
  /// In tr, this message translates to:
  /// **'Nehir teknesi'**
  String get travelVehicleKeelboat;

  /// No description provided for @travelVehicleSailingShip.
  ///
  /// In tr, this message translates to:
  /// **'Yelkenli'**
  String get travelVehicleSailingShip;

  /// No description provided for @travelVehicleWarship.
  ///
  /// In tr, this message translates to:
  /// **'Savaş gemisi'**
  String get travelVehicleWarship;

  /// No description provided for @travelVehicleLongship.
  ///
  /// In tr, this message translates to:
  /// **'Uzungemi'**
  String get travelVehicleLongship;

  /// No description provided for @travelVehicleGalley.
  ///
  /// In tr, this message translates to:
  /// **'Kadırga'**
  String get travelVehicleGalley;

  /// No description provided for @worldNpcAdd.
  ///
  /// In tr, this message translates to:
  /// **'NPC ekle'**
  String get worldNpcAdd;

  /// No description provided for @worldNpcEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz NPC yok. Ekledikten sonra harita pinlerine bağlayabilirsin.'**
  String get worldNpcEmpty;

  /// No description provided for @worldNpcNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Adı'**
  String get worldNpcNameLabel;

  /// No description provided for @worldNpcRoleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Rolü'**
  String get worldNpcRoleLabel;

  /// No description provided for @worldNpcNoLinks.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir haritaya bağlı değil. Bir yerin haritasında NPC pini ekleyerek bağlayabilirsin.'**
  String get worldNpcNoLinks;

  /// No description provided for @worldNpcAppearsIn.
  ///
  /// In tr, this message translates to:
  /// **'Geçtiği yerler'**
  String get worldNpcAppearsIn;

  /// No description provided for @worldPinEdit.
  ///
  /// In tr, this message translates to:
  /// **'Pini düzenle'**
  String get worldPinEdit;

  /// No description provided for @worldPinLabel.
  ///
  /// In tr, this message translates to:
  /// **'Etiket'**
  String get worldPinLabel;

  /// No description provided for @worldPinLabelHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Yıkık kule'**
  String get worldPinLabelHint;

  /// No description provided for @worldPinType.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get worldPinType;

  /// No description provided for @worldPinNote.
  ///
  /// In tr, this message translates to:
  /// **'Not'**
  String get worldPinNote;

  /// No description provided for @worldPinNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'Sadece sen görürsün; pini açarsan oyuncular da.'**
  String get worldPinNoteHint;

  /// No description provided for @worldPinRevealLocationHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıyken pin yalnızca sende görünür. Açıkken oyuncular pine dokunup o yerin haritasına girebilir (haritası varsa).'**
  String get worldPinRevealLocationHint;

  /// No description provided for @worldPinRevealHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıyken pin yalnızca sende görünür.'**
  String get worldPinRevealHint;

  /// No description provided for @worldKindLocation.
  ///
  /// In tr, this message translates to:
  /// **'Alt yer'**
  String get worldKindLocation;

  /// No description provided for @worldKindNpc.
  ///
  /// In tr, this message translates to:
  /// **'NPC'**
  String get worldKindNpc;

  /// No description provided for @worldKindShop.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza'**
  String get worldKindShop;

  /// No description provided for @worldKindEncounter.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma'**
  String get worldKindEncounter;

  /// No description provided for @worldKindTreasure.
  ///
  /// In tr, this message translates to:
  /// **'Hazine'**
  String get worldKindTreasure;

  /// No description provided for @worldKindTreasureLoot.
  ///
  /// In tr, this message translates to:
  /// **'Ganimet seti'**
  String get worldKindTreasureLoot;

  /// No description provided for @worldKindTreasureLootHint.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncular pine dokununca bu setten eşya/para alır. Set sonradan değiştirilemez.'**
  String get worldKindTreasureLootHint;

  /// No description provided for @worldKindTreasureLootNone.
  ///
  /// In tr, this message translates to:
  /// **'Serbest not (set yok)'**
  String get worldKindTreasureLootNone;

  /// No description provided for @worldTreasureNoLootSets.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ganimet seti yok. Önce Loot sekmesinden oluştur.'**
  String get worldTreasureNoLootSets;

  /// No description provided for @worldTreasureRemainingDetail.
  ///
  /// In tr, this message translates to:
  /// **'Kalan ganimet: {items} eşya, {coins} cp'**
  String worldTreasureRemainingDetail(Object coins, Object items);

  /// No description provided for @worldTargetNoLocations.
  ///
  /// In tr, this message translates to:
  /// **'Bu yerin altında henüz başka bir yer yok. Menüden “Alt yer ekle” diyerek oluşturabilirsin.'**
  String get worldTargetNoLocations;

  /// No description provided for @worldTargetNoNpcs.
  ///
  /// In tr, this message translates to:
  /// **'Henüz NPC yok. Dünya ekranındaki NPC listesinden ekleyebilirsin.'**
  String get worldTargetNoNpcs;

  /// No description provided for @worldTargetNoShops.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mağaza yok. Mağazalar sekmesinden kur.'**
  String get worldTargetNoShops;

  /// No description provided for @worldTargetNoEncounters.
  ///
  /// In tr, this message translates to:
  /// **'Henüz karşılaşma yok. Savaş sekmesinden oluştur.'**
  String get worldTargetNoEncounters;

  /// No description provided for @worldTargetLink.
  ///
  /// In tr, this message translates to:
  /// **'Bağlanacak kayıt'**
  String get worldTargetLink;

  /// No description provided for @worldDeleteConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} silinsin mi?'**
  String worldDeleteConfirmTitle(String name);

  /// No description provided for @sessionBackup.
  ///
  /// In tr, this message translates to:
  /// **'Yedekleme'**
  String get sessionBackup;

  /// No description provided for @sessionCloseTable.
  ///
  /// In tr, this message translates to:
  /// **'Oturumu kapat'**
  String get sessionCloseTable;

  /// No description provided for @sessionLogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Oturum günlüğü'**
  String get sessionLogTitle;

  /// No description provided for @sessionLogAdd.
  ///
  /// In tr, this message translates to:
  /// **'Not ekle'**
  String get sessionLogAdd;

  /// No description provided for @sessionLogClear.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get sessionLogClear;

  /// No description provided for @sessionLogClearConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Tüm günlük kalıcı olarak silinsin mi?'**
  String get sessionLogClearConfirm;

  /// No description provided for @sessionLogEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kayıt yok. XP verildikçe ve not ekledikçe burada birikir.'**
  String get sessionLogEmpty;

  /// No description provided for @sessionHandoutCaption.
  ///
  /// In tr, this message translates to:
  /// **'Görsel başlığı (isteğe bağlı)'**
  String get sessionHandoutCaption;

  /// No description provided for @sessionHandoutShow.
  ///
  /// In tr, this message translates to:
  /// **'Görsel göster'**
  String get sessionHandoutShow;

  /// No description provided for @sessionHandoutClear.
  ///
  /// In tr, this message translates to:
  /// **'Görseli kaldır'**
  String get sessionHandoutClear;

  /// No description provided for @sessionHandoutShared.
  ///
  /// In tr, this message translates to:
  /// **'Görsel oyunculara gösterildi.'**
  String get sessionHandoutShared;

  /// No description provided for @sessionHandoutCleared.
  ///
  /// In tr, this message translates to:
  /// **'Görsel kaldırıldı.'**
  String get sessionHandoutCleared;

  /// No description provided for @codexNewPage.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sayfa'**
  String get codexNewPage;

  /// No description provided for @codexUntitled.
  ///
  /// In tr, this message translates to:
  /// **'Başlıksız'**
  String get codexUntitled;

  /// No description provided for @codexAddSubpage.
  ///
  /// In tr, this message translates to:
  /// **'Alt sayfa ekle'**
  String get codexAddSubpage;

  /// No description provided for @codexRename.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden adlandır'**
  String get codexRename;

  /// No description provided for @codexSetIcon.
  ///
  /// In tr, this message translates to:
  /// **'Simge (emoji)'**
  String get codexSetIcon;

  /// No description provided for @codexDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'“{title}” ve tüm alt sayfaları silinsin mi?'**
  String codexDeleteConfirm(String title);

  /// No description provided for @codexEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz sayfa yok'**
  String get codexEmpty;

  /// No description provided for @codexEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'İlk sayfanı oluştur; içine metin, liste, görsel, tablo, zar ve bağlantı blokları ekleyebilirsin.'**
  String get codexEmptyHint;

  /// No description provided for @codexDone.
  ///
  /// In tr, this message translates to:
  /// **'Bitti'**
  String get codexDone;

  /// No description provided for @codexAddBlock.
  ///
  /// In tr, this message translates to:
  /// **'Blok ekle'**
  String get codexAddBlock;

  /// No description provided for @codexAddBlockHint.
  ///
  /// In tr, this message translates to:
  /// **'Aşağıdaki düğmeden blok ekle.'**
  String get codexAddBlockHint;

  /// No description provided for @codexPageTitleEdit.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa başlığı'**
  String get codexPageTitleEdit;

  /// No description provided for @codexPageEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu sayfa boş.'**
  String get codexPageEmpty;

  /// No description provided for @codexAddItem.
  ///
  /// In tr, this message translates to:
  /// **'Madde ekle'**
  String get codexAddItem;

  /// No description provided for @codexBlockText.
  ///
  /// In tr, this message translates to:
  /// **'Metin'**
  String get codexBlockText;

  /// No description provided for @codexBlockHeading.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get codexBlockHeading;

  /// No description provided for @codexBlockBulleted.
  ///
  /// In tr, this message translates to:
  /// **'Madde listesi'**
  String get codexBlockBulleted;

  /// No description provided for @codexBlockChecklist.
  ///
  /// In tr, this message translates to:
  /// **'Onay listesi'**
  String get codexBlockChecklist;

  /// No description provided for @codexBlockCallout.
  ///
  /// In tr, this message translates to:
  /// **'Vurgu kutusu'**
  String get codexBlockCallout;

  /// No description provided for @codexBlockTable.
  ///
  /// In tr, this message translates to:
  /// **'Tablo'**
  String get codexBlockTable;

  /// No description provided for @codexBlockChart.
  ///
  /// In tr, this message translates to:
  /// **'Grafik'**
  String get codexBlockChart;

  /// No description provided for @codexBlockImage.
  ///
  /// In tr, this message translates to:
  /// **'Görsel'**
  String get codexBlockImage;

  /// No description provided for @codexBlockVideo.
  ///
  /// In tr, this message translates to:
  /// **'Video'**
  String get codexBlockVideo;

  /// No description provided for @codexBlockLink.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı'**
  String get codexBlockLink;

  /// No description provided for @codexVideoUpload.
  ///
  /// In tr, this message translates to:
  /// **'Video yükle'**
  String get codexVideoUpload;

  /// No description provided for @codexVideoSelected.
  ///
  /// In tr, this message translates to:
  /// **'Video seçildi'**
  String get codexVideoSelected;

  /// No description provided for @codexVideoMissing.
  ///
  /// In tr, this message translates to:
  /// **'Video dosyası bulunamadı'**
  String get codexVideoMissing;

  /// No description provided for @codexLinkUrl.
  ///
  /// In tr, this message translates to:
  /// **'Adres (URL)'**
  String get codexLinkUrl;

  /// No description provided for @codexLinkFailed.
  ///
  /// In tr, this message translates to:
  /// **'{url} açılamadı'**
  String codexLinkFailed(Object url);

  /// No description provided for @codexChartTitle.
  ///
  /// In tr, this message translates to:
  /// **'Grafik başlığı'**
  String get codexChartTitle;

  /// No description provided for @codexChartLabel.
  ///
  /// In tr, this message translates to:
  /// **'Etiket'**
  String get codexChartLabel;

  /// No description provided for @codexChartValue.
  ///
  /// In tr, this message translates to:
  /// **'Değer'**
  String get codexChartValue;

  /// No description provided for @codexSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlarda ara...'**
  String get codexSearchHint;

  /// No description provided for @codexBlockCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Karakter kartı'**
  String get codexBlockCharacter;

  /// No description provided for @codexCharacterMissing.
  ///
  /// In tr, this message translates to:
  /// **'Karakter bulunamadı'**
  String get codexCharacterMissing;

  /// No description provided for @codexCharacterLevel.
  ///
  /// In tr, this message translates to:
  /// **'Seviye {level}'**
  String codexCharacterLevel(int level);

  /// No description provided for @codexWikiMissingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa yok'**
  String get codexWikiMissingTitle;

  /// No description provided for @codexWikiMissingBody.
  ///
  /// In tr, this message translates to:
  /// **'“{title}” adlı sayfa yok. Oluşturulsun mu?'**
  String codexWikiMissingBody(String title);

  /// No description provided for @codexWikiCreate.
  ///
  /// In tr, this message translates to:
  /// **'Oluştur'**
  String get codexWikiCreate;

  /// No description provided for @codexRefNotFound.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” bulunamadı.'**
  String codexRefNotFound(String name);

  /// No description provided for @codexTextHint.
  ///
  /// In tr, this message translates to:
  /// **'**kalın** · *italik* · `kod` · [[Sayfa]] · /r1d20 · /character(Ad) · /monster(Ad) · /spell(Ad) · /item(Ad) · /link(url)(kelime) · /page(Başlık)(kelime)'**
  String get codexTextHint;

  /// No description provided for @codexBlockDivider.
  ///
  /// In tr, this message translates to:
  /// **'Ayraç'**
  String get codexBlockDivider;

  /// No description provided for @codexBlockDice.
  ///
  /// In tr, this message translates to:
  /// **'Zar'**
  String get codexBlockDice;

  /// No description provided for @codexBlockPageLink.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa bağlantısı'**
  String get codexBlockPageLink;

  /// No description provided for @codexBlockEntityLink.
  ///
  /// In tr, this message translates to:
  /// **'Öge bağlantısı'**
  String get codexBlockEntityLink;

  /// No description provided for @codexBadExpression.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz zar ifadesi (ör. 2d6+3).'**
  String get codexBadExpression;

  /// No description provided for @codexDiceLabel.
  ///
  /// In tr, this message translates to:
  /// **'Etiket'**
  String get codexDiceLabel;

  /// No description provided for @codexDiceExpression.
  ///
  /// In tr, this message translates to:
  /// **'Zar ifadesi'**
  String get codexDiceExpression;

  /// No description provided for @codexTableHeader.
  ///
  /// In tr, this message translates to:
  /// **'Başlık satırı'**
  String get codexTableHeader;

  /// No description provided for @codexTableAddRow.
  ///
  /// In tr, this message translates to:
  /// **'Satır'**
  String get codexTableAddRow;

  /// No description provided for @codexTableAddColumn.
  ///
  /// In tr, this message translates to:
  /// **'Sütun'**
  String get codexTableAddColumn;

  /// No description provided for @codexTableRemoveColumn.
  ///
  /// In tr, this message translates to:
  /// **'Sütun sil'**
  String get codexTableRemoveColumn;

  /// No description provided for @codexImageCaption.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama (isteğe bağlı)'**
  String get codexImageCaption;

  /// No description provided for @codexLinkTargetPage.
  ///
  /// In tr, this message translates to:
  /// **'Hedef sayfa'**
  String get codexLinkTargetPage;

  /// No description provided for @codexLinkLabel.
  ///
  /// In tr, this message translates to:
  /// **'Etiket (isteğe bağlı)'**
  String get codexLinkLabel;

  /// No description provided for @sessionOpenTable.
  ///
  /// In tr, this message translates to:
  /// **'Masayı aç'**
  String get sessionOpenTable;

  /// No description provided for @sessionStartHint.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncular aynı Wi-Fi ağındayken telefonlarının kamerasıyla QR kodu okutup tarayıcıdan bağlanır. Uygulama kurmalarına, hesap açmalarına ya da internete gerek yok.'**
  String get sessionStartHint;

  /// No description provided for @sessionStartServer.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuyu başlat'**
  String get sessionStartServer;

  /// No description provided for @sessionAddressCopied.
  ///
  /// In tr, this message translates to:
  /// **'Adres kopyalandı'**
  String get sessionAddressCopied;

  /// No description provided for @sessionCopyAddress.
  ///
  /// In tr, this message translates to:
  /// **'Adresi kopyala'**
  String get sessionCopyAddress;

  /// No description provided for @sessionReject.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get sessionReject;

  /// No description provided for @sessionApprove.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get sessionApprove;

  /// No description provided for @sessionDmTools.
  ///
  /// In tr, this message translates to:
  /// **'DM araçları'**
  String get sessionDmTools;

  /// No description provided for @sessionTarget.
  ///
  /// In tr, this message translates to:
  /// **'Hedef'**
  String get sessionTarget;

  /// No description provided for @sessionEveryone.
  ///
  /// In tr, this message translates to:
  /// **'Herkes'**
  String get sessionEveryone;

  /// No description provided for @sessionAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru / mesaj'**
  String get sessionAnnouncement;

  /// No description provided for @sessionSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get sessionSend;

  /// No description provided for @sessionAnnouncementSent.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru gönderildi.'**
  String get sessionAnnouncementSent;

  /// No description provided for @sessionAbility.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek'**
  String get sessionAbility;

  /// No description provided for @sessionRequestSave.
  ///
  /// In tr, this message translates to:
  /// **'Kurtarma iste'**
  String get sessionRequestSave;

  /// No description provided for @sessionSaveRequested.
  ///
  /// In tr, this message translates to:
  /// **'Kurtarma atışı istendi.'**
  String get sessionSaveRequested;

  /// No description provided for @sessionGold.
  ///
  /// In tr, this message translates to:
  /// **'Altın'**
  String get sessionGold;

  /// No description provided for @sessionItemsCsv.
  ///
  /// In tr, this message translates to:
  /// **'Eşyalar (virgülle)'**
  String get sessionItemsCsv;

  /// No description provided for @sessionGiveLoot.
  ///
  /// In tr, this message translates to:
  /// **'Ganimet ver'**
  String get sessionGiveLoot;

  /// No description provided for @sessionLootOffered.
  ///
  /// In tr, this message translates to:
  /// **'Ganimet sunuldu.'**
  String get sessionLootOffered;

  /// No description provided for @sessionNobodyConnected.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kimse bağlanmadı.'**
  String get sessionNobodyConnected;

  /// No description provided for @sessionNoCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Karakter seçmedi'**
  String get sessionNoCharacter;

  /// No description provided for @sessionHasCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Karakteri sahiplendi'**
  String get sessionHasCharacter;

  /// No description provided for @sessionPurchaseRequests.
  ///
  /// In tr, this message translates to:
  /// **'Satın alma isteği ({count})'**
  String sessionPurchaseRequests(int count);

  /// No description provided for @sessionConnectedPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Bağlı oyuncular ({count})'**
  String sessionConnectedPlayers(int count);

  /// No description provided for @charactersTabParty.
  ///
  /// In tr, this message translates to:
  /// **'Parti'**
  String get charactersTabParty;

  /// No description provided for @charactersTabSharedInventory.
  ///
  /// In tr, this message translates to:
  /// **'Ortak envanter'**
  String get charactersTabSharedInventory;

  /// No description provided for @charactersNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni karakter'**
  String get charactersNew;

  /// No description provided for @charactersDelete.
  ///
  /// In tr, this message translates to:
  /// **'Karakteri sil'**
  String get charactersDelete;

  /// No description provided for @charactersEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz karakter yok'**
  String get charactersEmpty;

  /// No description provided for @charactersEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Sağ alttaki butondan ilk karakteri oluştur.'**
  String get charactersEmptyHint;

  /// No description provided for @charactersDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” kalıcı olarak silinecek. Emin misin?'**
  String charactersDeleteConfirm(String name);

  /// No description provided for @compendiumCreateMonster.
  ///
  /// In tr, this message translates to:
  /// **'Canavar yarat'**
  String get compendiumCreateMonster;

  /// No description provided for @compendiumImportImages.
  ///
  /// In tr, this message translates to:
  /// **'Görsel içe aktar'**
  String get compendiumImportImages;

  /// No description provided for @compendiumImportHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir klasör seç; dosya adları canavar adıyla eşleşen görseller (ör. Goblin.png) otomatik atanır. Yalnızca kendi görsellerin.'**
  String get compendiumImportHint;

  /// No description provided for @compendiumChooseFolder.
  ///
  /// In tr, this message translates to:
  /// **'Klasör seç'**
  String get compendiumChooseFolder;

  /// No description provided for @compendiumNoImagesFound.
  ///
  /// In tr, this message translates to:
  /// **'Klasörde görsel bulunamadı.'**
  String get compendiumNoImagesFound;

  /// No description provided for @compendiumImportResult.
  ///
  /// In tr, this message translates to:
  /// **'{assigned} canavara görsel atandı, {unmatched} dosya eşleşmedi.'**
  String compendiumImportResult(int assigned, int unmatched);

  /// No description provided for @compendiumCreateSpell.
  ///
  /// In tr, this message translates to:
  /// **'Büyü yarat'**
  String get compendiumCreateSpell;

  /// No description provided for @compendiumCreateItem.
  ///
  /// In tr, this message translates to:
  /// **'Eşya yarat'**
  String get compendiumCreateItem;

  /// No description provided for @compendiumCreateMagicItem.
  ///
  /// In tr, this message translates to:
  /// **'Büyülü eşya yarat'**
  String get compendiumCreateMagicItem;

  /// No description provided for @compendiumCrRange.
  ///
  /// In tr, this message translates to:
  /// **'Zorluk aralığı'**
  String get compendiumCrRange;

  /// No description provided for @compendiumPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get compendiumPrice;

  /// No description provided for @compendiumWeight.
  ///
  /// In tr, this message translates to:
  /// **'Ağırlık'**
  String get compendiumWeight;

  /// No description provided for @compendiumDamage.
  ///
  /// In tr, this message translates to:
  /// **'Hasar'**
  String get compendiumDamage;

  /// No description provided for @compendiumProperties.
  ///
  /// In tr, this message translates to:
  /// **'Özellikler'**
  String get compendiumProperties;

  /// No description provided for @compendiumStrengthReq.
  ///
  /// In tr, this message translates to:
  /// **'Güç şartı'**
  String get compendiumStrengthReq;

  /// No description provided for @compendiumStealth.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik'**
  String get compendiumStealth;

  /// No description provided for @compendiumDisadvantage.
  ///
  /// In tr, this message translates to:
  /// **'Dezavantaj'**
  String get compendiumDisadvantage;

  /// No description provided for @compendiumSuggested.
  ///
  /// In tr, this message translates to:
  /// **'önerilen'**
  String get compendiumSuggested;

  /// No description provided for @compendiumMagicPriceHint.
  ///
  /// In tr, this message translates to:
  /// **'SRD büyülü eşyalar için fiyat yayınlamaz; bu değer nadirliğe göre önerilmiştir ve mağaza kurarken değiştirilebilir.'**
  String get compendiumMagicPriceHint;

  /// No description provided for @levelUpNoClass.
  ///
  /// In tr, this message translates to:
  /// **'Karakterin sınıfı yok.'**
  String get levelUpNoClass;

  /// No description provided for @levelUpNewClass.
  ///
  /// In tr, this message translates to:
  /// **'yeni sınıf'**
  String get levelUpNewClass;

  /// No description provided for @levelUpFeaturesGained.
  ///
  /// In tr, this message translates to:
  /// **'Kazanılan yetenekler'**
  String get levelUpFeaturesGained;

  /// No description provided for @levelUpWhichClass.
  ///
  /// In tr, this message translates to:
  /// **'Hangi sınıfta ilerliyorsun?'**
  String get levelUpWhichClass;

  /// No description provided for @levelUpHitPoints.
  ///
  /// In tr, this message translates to:
  /// **'Can puanı'**
  String get levelUpHitPoints;

  /// No description provided for @levelUpSubclass.
  ///
  /// In tr, this message translates to:
  /// **'Alt sınıf'**
  String get levelUpSubclass;

  /// No description provided for @levelUpAddCustom.
  ///
  /// In tr, this message translates to:
  /// **'Kendim ekle'**
  String get levelUpAddCustom;

  /// No description provided for @levelUpAbilityIncrease.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek artışı'**
  String get levelUpAbilityIncrease;

  /// No description provided for @levelUpRoll.
  ///
  /// In tr, this message translates to:
  /// **'Zar at'**
  String get levelUpRoll;

  /// No description provided for @levelUpSaveAs.
  ///
  /// In tr, this message translates to:
  /// **'{className} {level} olarak kaydet'**
  String levelUpSaveAs(String className, int level);

  /// No description provided for @levelUpHpHint.
  ///
  /// In tr, this message translates to:
  /// **'d{sides} at ya da sabit {avg} al. Bu değere ayrıca CON modifiern eklenir.'**
  String levelUpHpHint(int sides, int avg);

  /// No description provided for @levelUpFixed.
  ///
  /// In tr, this message translates to:
  /// **'Sabit {avg}'**
  String levelUpFixed(int avg);

  /// No description provided for @levelUpRolled.
  ///
  /// In tr, this message translates to:
  /// **'Zar: {n}'**
  String levelUpRolled(int n);

  /// No description provided for @levelUpAbilityHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir yeteneğe +2 ya da iki yeteneğe +1. Kalan: {remaining}'**
  String levelUpAbilityHint(int remaining);

  /// No description provided for @lootNewSet.
  ///
  /// In tr, this message translates to:
  /// **'Yeni set'**
  String get lootNewSet;

  /// No description provided for @lootEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ganimet seti yok. Eşya ve para içeren bir set hazırla, sonra masada tek dokunuşla oyunculara sun.'**
  String get lootEmpty;

  /// No description provided for @lootEmptyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get lootEmptyLabel;

  /// No description provided for @lootShow.
  ///
  /// In tr, this message translates to:
  /// **'Göster'**
  String get lootShow;

  /// No description provided for @lootSetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ganimet seti'**
  String get lootSetTitle;

  /// No description provided for @lootSetName.
  ///
  /// In tr, this message translates to:
  /// **'Set adı'**
  String get lootSetName;

  /// No description provided for @lootMoney.
  ///
  /// In tr, this message translates to:
  /// **'Para'**
  String get lootMoney;

  /// No description provided for @lootItems.
  ///
  /// In tr, this message translates to:
  /// **'Eşyalar'**
  String get lootItems;

  /// No description provided for @lootNoItems.
  ///
  /// In tr, this message translates to:
  /// **'Henüz eşya yok.'**
  String get lootNoItems;

  /// No description provided for @lootAddItem.
  ///
  /// In tr, this message translates to:
  /// **'Eşya ekle'**
  String get lootAddItem;

  /// No description provided for @lootMagic.
  ///
  /// In tr, this message translates to:
  /// **'Sihirli'**
  String get lootMagic;

  /// No description provided for @lootAddFromCompendium.
  ///
  /// In tr, this message translates to:
  /// **'Katalogdan ekle'**
  String get lootAddFromCompendium;

  /// No description provided for @lootItemCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} eşya'**
  String lootItemCount(int count);

  /// No description provided for @lootUnknownItem.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen eşya'**
  String get lootUnknownItem;

  /// No description provided for @navTables.
  ///
  /// In tr, this message translates to:
  /// **'Tablolar'**
  String get navTables;

  /// No description provided for @navTablesShort.
  ///
  /// In tr, this message translates to:
  /// **'Tablo'**
  String get navTablesShort;

  /// No description provided for @tablesTabTables.
  ///
  /// In tr, this message translates to:
  /// **'Tablolar'**
  String get tablesTabTables;

  /// No description provided for @tablesTabNames.
  ///
  /// In tr, this message translates to:
  /// **'İsim Üreteci'**
  String get tablesTabNames;

  /// No description provided for @tablesNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni tablo'**
  String get tablesNew;

  /// No description provided for @tablesEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tablo yok. Kendi tablonu kur (d4–d100), satırları gir, masada tek dokunuşla zar at.'**
  String get tablesEmpty;

  /// No description provided for @tablesEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tabloyu düzenle'**
  String get tablesEditTitle;

  /// No description provided for @tablesName.
  ///
  /// In tr, this message translates to:
  /// **'Tablo adı'**
  String get tablesName;

  /// No description provided for @tablesCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get tablesCategory;

  /// No description provided for @tablesCategoryHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. şehir, yol, ganimet'**
  String get tablesCategoryHint;

  /// No description provided for @tablesDice.
  ///
  /// In tr, this message translates to:
  /// **'Zar'**
  String get tablesDice;

  /// No description provided for @tablesRows.
  ///
  /// In tr, this message translates to:
  /// **'Satırlar'**
  String get tablesRows;

  /// No description provided for @tablesAddRow.
  ///
  /// In tr, this message translates to:
  /// **'Satır ekle'**
  String get tablesAddRow;

  /// No description provided for @tablesRowCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} satır'**
  String tablesRowCount(Object count);

  /// No description provided for @tablesRoll.
  ///
  /// In tr, this message translates to:
  /// **'At'**
  String get tablesRoll;

  /// No description provided for @tablesRollAgain.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar at'**
  String get tablesRollAgain;

  /// No description provided for @tablesNoRowForRoll.
  ///
  /// In tr, this message translates to:
  /// **'Bu sayıya denk gelen satır yok (tabloda boşluk var).'**
  String get tablesNoRowForRoll;

  /// No description provided for @tablesRedistribute.
  ///
  /// In tr, this message translates to:
  /// **'Aralıkları dağıt'**
  String get tablesRedistribute;

  /// No description provided for @tablesDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” tablosu silinsin mi?'**
  String tablesDeleteConfirm(Object name);

  /// No description provided for @tablesIssueGap.
  ///
  /// In tr, this message translates to:
  /// **'Zar yüzlerinin bir kısmı hiçbir satıra denk gelmiyor.'**
  String get tablesIssueGap;

  /// No description provided for @tablesIssueOverlap.
  ///
  /// In tr, this message translates to:
  /// **'Bazı sayılar birden fazla satır tarafından kapsanıyor.'**
  String get tablesIssueOverlap;

  /// No description provided for @tablesIssueOutOfRange.
  ///
  /// In tr, this message translates to:
  /// **'Bazı satırlar zar yüzünün dışına taşıyor.'**
  String get tablesIssueOutOfRange;

  /// No description provided for @tablesIssueEmptyRange.
  ///
  /// In tr, this message translates to:
  /// **'Bir satırın başlangıcı bitişinden büyük.'**
  String get tablesIssueEmptyRange;

  /// No description provided for @nameGeneratorHint.
  ///
  /// In tr, this message translates to:
  /// **'Tamamen çevrimdışı çalışır; hece ve kelimeleri birleştirir, aynı isim iki kez çıkmaz.'**
  String get nameGeneratorHint;

  /// No description provided for @nameCount.
  ///
  /// In tr, this message translates to:
  /// **'Adet'**
  String get nameCount;

  /// No description provided for @nameGenerate.
  ///
  /// In tr, this message translates to:
  /// **'Üret'**
  String get nameGenerate;

  /// No description provided for @nameCopy.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get nameCopy;

  /// No description provided for @nameCopied.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” kopyalandı.'**
  String nameCopied(Object name);

  /// No description provided for @nameSaveAsNpc.
  ///
  /// In tr, this message translates to:
  /// **'NPC olarak kaydet'**
  String get nameSaveAsNpc;

  /// No description provided for @nameSavedAsNpc.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” NPC olarak kaydedildi.'**
  String nameSavedAsNpc(Object name);

  /// No description provided for @nameSaveAsLocation.
  ///
  /// In tr, this message translates to:
  /// **'Yer olarak kaydet'**
  String get nameSaveAsLocation;

  /// No description provided for @nameSavedAsLocation.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” yerlere eklendi.'**
  String nameSavedAsLocation(String name);

  /// No description provided for @nameGender.
  ///
  /// In tr, this message translates to:
  /// **'Cinsiyet'**
  String get nameGender;

  /// No description provided for @nameGenderAny.
  ///
  /// In tr, this message translates to:
  /// **'Farketmez'**
  String get nameGenderAny;

  /// No description provided for @nameGenderMale.
  ///
  /// In tr, this message translates to:
  /// **'Erkek'**
  String get nameGenderMale;

  /// No description provided for @nameGenderFemale.
  ///
  /// In tr, this message translates to:
  /// **'Kadın'**
  String get nameGenderFemale;

  /// No description provided for @nameSurname.
  ///
  /// In tr, this message translates to:
  /// **'Soyad / lakap ekle'**
  String get nameSurname;

  /// No description provided for @nameCategoryPerson.
  ///
  /// In tr, this message translates to:
  /// **'Kişi'**
  String get nameCategoryPerson;

  /// No description provided for @nameCategoryPlace.
  ///
  /// In tr, this message translates to:
  /// **'Yer'**
  String get nameCategoryPlace;

  /// No description provided for @nameCategoryEstablishment.
  ///
  /// In tr, this message translates to:
  /// **'İşletme'**
  String get nameCategoryEstablishment;

  /// No description provided for @nameCategoryGroup.
  ///
  /// In tr, this message translates to:
  /// **'Topluluk'**
  String get nameCategoryGroup;

  /// No description provided for @nameCategoryThing.
  ///
  /// In tr, this message translates to:
  /// **'Nesne'**
  String get nameCategoryThing;

  /// No description provided for @nameCultureHuman.
  ///
  /// In tr, this message translates to:
  /// **'İnsan'**
  String get nameCultureHuman;

  /// No description provided for @nameCultureHumanNorth.
  ///
  /// In tr, this message translates to:
  /// **'İnsan (kuzeyli)'**
  String get nameCultureHumanNorth;

  /// No description provided for @nameCultureHumanDesert.
  ///
  /// In tr, this message translates to:
  /// **'İnsan (çöl)'**
  String get nameCultureHumanDesert;

  /// No description provided for @nameCultureHumanEast.
  ///
  /// In tr, this message translates to:
  /// **'İnsan (doğulu)'**
  String get nameCultureHumanEast;

  /// No description provided for @nameCultureElf.
  ///
  /// In tr, this message translates to:
  /// **'Elf'**
  String get nameCultureElf;

  /// No description provided for @nameCultureDrow.
  ///
  /// In tr, this message translates to:
  /// **'Kara elf'**
  String get nameCultureDrow;

  /// No description provided for @nameCultureDwarf.
  ///
  /// In tr, this message translates to:
  /// **'Cüce'**
  String get nameCultureDwarf;

  /// No description provided for @nameCultureHalfling.
  ///
  /// In tr, this message translates to:
  /// **'Half-ling'**
  String get nameCultureHalfling;

  /// No description provided for @nameCultureGnome.
  ///
  /// In tr, this message translates to:
  /// **'Gnom'**
  String get nameCultureGnome;

  /// No description provided for @nameCultureOrc.
  ///
  /// In tr, this message translates to:
  /// **'Ork'**
  String get nameCultureOrc;

  /// No description provided for @nameCultureGoblin.
  ///
  /// In tr, this message translates to:
  /// **'Goblin'**
  String get nameCultureGoblin;

  /// No description provided for @nameCultureTiefling.
  ///
  /// In tr, this message translates to:
  /// **'Tiefling'**
  String get nameCultureTiefling;

  /// No description provided for @nameCultureDragonborn.
  ///
  /// In tr, this message translates to:
  /// **'Ejderdoğan'**
  String get nameCultureDragonborn;

  /// No description provided for @nameCultureGoliath.
  ///
  /// In tr, this message translates to:
  /// **'Goliath'**
  String get nameCultureGoliath;

  /// No description provided for @nameCultureLizardfolk.
  ///
  /// In tr, this message translates to:
  /// **'Kertenkele halkı'**
  String get nameCultureLizardfolk;

  /// No description provided for @nameCultureTabaxi.
  ///
  /// In tr, this message translates to:
  /// **'Tabaxi'**
  String get nameCultureTabaxi;

  /// No description provided for @nameCultureCelestial.
  ///
  /// In tr, this message translates to:
  /// **'Semavi'**
  String get nameCultureCelestial;

  /// No description provided for @nameCultureUndead.
  ///
  /// In tr, this message translates to:
  /// **'Hortlak'**
  String get nameCultureUndead;

  /// No description provided for @nameCulturePlace.
  ///
  /// In tr, this message translates to:
  /// **'Kasaba / köy'**
  String get nameCulturePlace;

  /// No description provided for @nameCultureCity.
  ///
  /// In tr, this message translates to:
  /// **'Şehir'**
  String get nameCultureCity;

  /// No description provided for @nameCultureFortress.
  ///
  /// In tr, this message translates to:
  /// **'Kale'**
  String get nameCultureFortress;

  /// No description provided for @nameCultureRuin.
  ///
  /// In tr, this message translates to:
  /// **'Harabe'**
  String get nameCultureRuin;

  /// No description provided for @nameCultureForest.
  ///
  /// In tr, this message translates to:
  /// **'Orman'**
  String get nameCultureForest;

  /// No description provided for @nameCultureMountain.
  ///
  /// In tr, this message translates to:
  /// **'Dağ'**
  String get nameCultureMountain;

  /// No description provided for @nameCultureWater.
  ///
  /// In tr, this message translates to:
  /// **'Nehir / göl'**
  String get nameCultureWater;

  /// No description provided for @nameCultureIsland.
  ///
  /// In tr, this message translates to:
  /// **'Ada'**
  String get nameCultureIsland;

  /// No description provided for @nameCultureRegion.
  ///
  /// In tr, this message translates to:
  /// **'Bölge'**
  String get nameCultureRegion;

  /// No description provided for @nameCultureTavern.
  ///
  /// In tr, this message translates to:
  /// **'Meyhane'**
  String get nameCultureTavern;

  /// No description provided for @nameCultureShop.
  ///
  /// In tr, this message translates to:
  /// **'Dükkân'**
  String get nameCultureShop;

  /// No description provided for @nameCultureTemple.
  ///
  /// In tr, this message translates to:
  /// **'Tapınak'**
  String get nameCultureTemple;

  /// No description provided for @nameCultureGuild.
  ///
  /// In tr, this message translates to:
  /// **'Lonca'**
  String get nameCultureGuild;

  /// No description provided for @nameCultureNobleHouse.
  ///
  /// In tr, this message translates to:
  /// **'Soylu hanedan'**
  String get nameCultureNobleHouse;

  /// No description provided for @nameCultureMercenary.
  ///
  /// In tr, this message translates to:
  /// **'Paralı asker bölüğü'**
  String get nameCultureMercenary;

  /// No description provided for @nameCultureCult.
  ///
  /// In tr, this message translates to:
  /// **'Tarikat'**
  String get nameCultureCult;

  /// No description provided for @nameCultureShip.
  ///
  /// In tr, this message translates to:
  /// **'Gemi'**
  String get nameCultureShip;

  /// No description provided for @nameCultureMagicItem.
  ///
  /// In tr, this message translates to:
  /// **'Büyülü eşya'**
  String get nameCultureMagicItem;

  /// No description provided for @nameCultureTome.
  ///
  /// In tr, this message translates to:
  /// **'Kitap / eser'**
  String get nameCultureTome;

  /// No description provided for @nameCultureFestival.
  ///
  /// In tr, this message translates to:
  /// **'Bayram / şenlik'**
  String get nameCultureFestival;

  /// No description provided for @nameCultureEpithet.
  ///
  /// In tr, this message translates to:
  /// **'Unvan / lakap'**
  String get nameCultureEpithet;

  /// No description provided for @aiToolTable.
  ///
  /// In tr, this message translates to:
  /// **'Tablo'**
  String get aiToolTable;

  /// No description provided for @aiTableTopic.
  ///
  /// In tr, this message translates to:
  /// **'Konu / tema'**
  String get aiTableTopic;

  /// No description provided for @aiTableTopicHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. bataklıkta rastgele olaylar, liman şehri söylentileri'**
  String get aiTableTopicHint;

  /// No description provided for @aiTableRowCount.
  ///
  /// In tr, this message translates to:
  /// **'Madde sayısı'**
  String get aiTableRowCount;

  /// No description provided for @aiTableTone.
  ///
  /// In tr, this message translates to:
  /// **'Ton'**
  String get aiTableTone;

  /// No description provided for @aiTableToneGritty.
  ///
  /// In tr, this message translates to:
  /// **'Karanlık'**
  String get aiTableToneGritty;

  /// No description provided for @aiTableToneHumorous.
  ///
  /// In tr, this message translates to:
  /// **'Mizahi'**
  String get aiTableToneHumorous;

  /// No description provided for @aiTableToneEpic.
  ///
  /// In tr, this message translates to:
  /// **'Destansı'**
  String get aiTableToneEpic;

  /// No description provided for @aiTableToneMundane.
  ///
  /// In tr, this message translates to:
  /// **'Gündelik'**
  String get aiTableToneMundane;

  /// No description provided for @aiTableContext.
  ///
  /// In tr, this message translates to:
  /// **'Ek bağlam (isteğe bağlı)'**
  String get aiTableContext;

  /// No description provided for @aiTableContextHint.
  ///
  /// In tr, this message translates to:
  /// **'Kampanyana özel ayrıntılar; maddeler buna göre kurgulanır.'**
  String get aiTableContextHint;

  /// No description provided for @aiTableSave.
  ///
  /// In tr, this message translates to:
  /// **'Tablolara kaydet'**
  String get aiTableSave;

  /// No description provided for @aiTableSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi'**
  String get aiTableSaved;

  /// No description provided for @aiTableSavedTo.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” Tablolar\'a kaydedildi.'**
  String aiTableSavedTo(Object name);

  /// No description provided for @partyInventoryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ortak kese'**
  String get partyInventoryTitle;

  /// No description provided for @partyInventoryNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kese'**
  String get partyInventoryNew;

  /// No description provided for @partyInventoryEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ortak kese yok. Bir kese oluşturup üye oyuncuları seç; onlar da kendi panellerinden serbestçe eşya ve para alıp koyabilir.'**
  String get partyInventoryEmpty;

  /// No description provided for @partyInventoryName.
  ///
  /// In tr, this message translates to:
  /// **'Kese adı'**
  String get partyInventoryName;

  /// No description provided for @partyInventoryMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler'**
  String get partyInventoryMembers;

  /// No description provided for @partyInventoryMembersHint.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca seçtiğin oyuncular bu keseyi görür ve kullanabilir.'**
  String get partyInventoryMembersHint;

  /// No description provided for @partyInventoryNoCharacters.
  ///
  /// In tr, this message translates to:
  /// **'Henüz karakter yok.'**
  String get partyInventoryNoCharacters;

  /// No description provided for @partyInventoryMembersCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String partyInventoryMembersCount(Object count);

  /// No description provided for @partyInventoryNoMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üye yok'**
  String get partyInventoryNoMembers;

  /// No description provided for @partyInventoryCoins.
  ///
  /// In tr, this message translates to:
  /// **'Para'**
  String get partyInventoryCoins;

  /// No description provided for @partyInventoryItems.
  ///
  /// In tr, this message translates to:
  /// **'Eşyalar'**
  String get partyInventoryItems;

  /// No description provided for @partyInventoryDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” kesesi silinsin mi? İçindekiler de gider.'**
  String partyInventoryDeleteConfirm(Object name);

  /// No description provided for @lootOffered.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” oyunculara sunuldu.'**
  String lootOffered(String name);

  /// No description provided for @shopsNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni mağaza'**
  String get shopsNew;

  /// No description provided for @shopsOpen.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara açık'**
  String get shopsOpen;

  /// No description provided for @shopsClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get shopsClosed;

  /// No description provided for @shopsName.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza adı'**
  String get shopsName;

  /// No description provided for @shopsNameHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Demirci'**
  String get shopsNameHint;

  /// No description provided for @shopsOwner.
  ///
  /// In tr, this message translates to:
  /// **'İşleten (isteğe bağlı)'**
  String get shopsOwner;

  /// No description provided for @shopsOwnerHint.
  ///
  /// In tr, this message translates to:
  /// **'Serbest metin — ya da yukarıdan var olan bir NPC seç.'**
  String get shopsOwnerHint;

  /// No description provided for @shopsOwnerNpc.
  ///
  /// In tr, this message translates to:
  /// **'İşleten NPC'**
  String get shopsOwnerNpc;

  /// No description provided for @shopsOwnerNpcNone.
  ///
  /// In tr, this message translates to:
  /// **'Yok (serbest ad)'**
  String get shopsOwnerNpcNone;

  /// No description provided for @shopsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza yok'**
  String get shopsEmpty;

  /// No description provided for @shopsEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphaneden eşya seçerek bir dükkân kur, sonra oyunculara aç.'**
  String get shopsEmptyHint;

  /// No description provided for @formName.
  ///
  /// In tr, this message translates to:
  /// **'Adı'**
  String get formName;

  /// No description provided for @formDescription.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get formDescription;

  /// No description provided for @formLevel.
  ///
  /// In tr, this message translates to:
  /// **'Seviye'**
  String get formLevel;

  /// No description provided for @formRange.
  ///
  /// In tr, this message translates to:
  /// **'Menzil'**
  String get formRange;

  /// No description provided for @formDuration.
  ///
  /// In tr, this message translates to:
  /// **'Süre'**
  String get formDuration;

  /// No description provided for @formMaterial.
  ///
  /// In tr, this message translates to:
  /// **'Malzeme (M)'**
  String get formMaterial;

  /// No description provided for @formClasses.
  ///
  /// In tr, this message translates to:
  /// **'Sınıflar'**
  String get formClasses;

  /// No description provided for @formClassesFailed.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf listesi yüklenemedi.'**
  String get formClassesFailed;

  /// No description provided for @formHigherLevel.
  ///
  /// In tr, this message translates to:
  /// **'Üst seviyede (opsiyonel)'**
  String get formHigherLevel;

  /// No description provided for @formCastingTimeHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. 1 action'**
  String get formCastingTimeHint;

  /// No description provided for @formRangeHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. 60 feet'**
  String get formRangeHint;

  /// No description provided for @formDurationHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Instantaneous'**
  String get formDurationHint;

  /// No description provided for @formMaterialHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. bir tutam kükürt'**
  String get formMaterialHint;

  /// No description provided for @ccAddSpecies.
  ///
  /// In tr, this message translates to:
  /// **'Tür ekle'**
  String get ccAddSpecies;

  /// No description provided for @ccSpeciesName.
  ///
  /// In tr, this message translates to:
  /// **'Tür adı'**
  String get ccSpeciesName;

  /// No description provided for @ccSize.
  ///
  /// In tr, this message translates to:
  /// **'Boyut'**
  String get ccSize;

  /// No description provided for @ccSpeed.
  ///
  /// In tr, this message translates to:
  /// **'Hız (feet)'**
  String get ccSpeed;

  /// No description provided for @ccTraits.
  ///
  /// In tr, this message translates to:
  /// **'Özellikler (serbest metin)'**
  String get ccTraits;

  /// No description provided for @ccSubclassName.
  ///
  /// In tr, this message translates to:
  /// **'Alt sınıf adı'**
  String get ccSubclassName;

  /// No description provided for @ccSubclassNameHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Battle Master'**
  String get ccSubclassNameHint;

  /// No description provided for @ccSubclassTraitsHint.
  ///
  /// In tr, this message translates to:
  /// **'Seviye seviye kazanılan yetenekleri buraya yazabilirsin.'**
  String get ccSubclassTraitsHint;

  /// No description provided for @ccAddBackground.
  ///
  /// In tr, this message translates to:
  /// **'Köken ekle'**
  String get ccAddBackground;

  /// No description provided for @ccBackgroundName.
  ///
  /// In tr, this message translates to:
  /// **'Köken adı'**
  String get ccBackgroundName;

  /// No description provided for @ccToolProf.
  ///
  /// In tr, this message translates to:
  /// **'Alet yeterliliği (isteğe bağlı)'**
  String get ccToolProf;

  /// No description provided for @ccBackgroundFeat.
  ///
  /// In tr, this message translates to:
  /// **'Köken feat’i (isteğe bağlı)'**
  String get ccBackgroundFeat;

  /// No description provided for @ccAddSubclass.
  ///
  /// In tr, this message translates to:
  /// **'{className} alt sınıfı ekle'**
  String ccAddSubclass(String className);

  /// No description provided for @ccAbilities3.
  ///
  /// In tr, this message translates to:
  /// **'Yetenekler — tam 3 tane ({count}/3)'**
  String ccAbilities3(int count);

  /// No description provided for @ccSkills2.
  ///
  /// In tr, this message translates to:
  /// **'Beceriler — tam 2 tane ({count}/2)'**
  String ccSkills2(int count);

  /// No description provided for @ciMagicPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat (boş bırakılırsa nadirlikten önerilir)'**
  String get ciMagicPrice;

  /// No description provided for @ciAttunement.
  ///
  /// In tr, this message translates to:
  /// **'Attunement gerekir'**
  String get ciAttunement;

  /// No description provided for @ciFreeStock.
  ///
  /// In tr, this message translates to:
  /// **'Serbest satır'**
  String get ciFreeStock;

  /// No description provided for @ciFreeStockHint.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bu mağazada görünür, kütüphaneye kaydedilmez.'**
  String get ciFreeStockHint;

  /// No description provided for @ciQuantity.
  ///
  /// In tr, this message translates to:
  /// **'Adet (-1 sınırsız)'**
  String get ciQuantity;

  /// No description provided for @mcType.
  ///
  /// In tr, this message translates to:
  /// **'Tip'**
  String get mcType;

  /// No description provided for @mcArmorClass.
  ///
  /// In tr, this message translates to:
  /// **'Zırh sınıfı'**
  String get mcArmorClass;

  /// No description provided for @mcSpeedFt.
  ///
  /// In tr, this message translates to:
  /// **'Hız (ft)'**
  String get mcSpeedFt;

  /// No description provided for @mcAbilityScores.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek puanları'**
  String get mcAbilityScores;

  /// No description provided for @mcAttackPower.
  ///
  /// In tr, this message translates to:
  /// **'Saldırı gücü'**
  String get mcAttackPower;

  /// No description provided for @mcAttackHint.
  ///
  /// In tr, this message translates to:
  /// **'CR tahmini için: bir turda ortalama kaç hasar verir ve isabet bonusu kaçtır?'**
  String get mcAttackHint;

  /// No description provided for @mcDamagePerRound.
  ///
  /// In tr, this message translates to:
  /// **'Tur başına hasar'**
  String get mcDamagePerRound;

  /// No description provided for @mcAttackBonus.
  ///
  /// In tr, this message translates to:
  /// **'İsabet bonusu'**
  String get mcAttackBonus;

  /// No description provided for @mcSaveToLibrary.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphaneye kaydet'**
  String get mcSaveToLibrary;

  /// No description provided for @mcEstimatedCr.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini zorluk'**
  String get mcEstimatedCr;

  /// No description provided for @mcBenchmarkNote.
  ///
  /// In tr, this message translates to:
  /// **'Ölçütler SRD 5.2’deki 331 canavarın gerçek istatistiklerinden türetildi. Bu bir başlangıç noktası — özel yetenekler ve karşılaşma düzeni gerçek zorluğu değiştirir.'**
  String get mcBenchmarkNote;

  /// No description provided for @mcActions.
  ///
  /// In tr, this message translates to:
  /// **'Aksiyonlar'**
  String get mcActions;

  /// No description provided for @mcNoActions.
  ///
  /// In tr, this message translates to:
  /// **'Henüz aksiyon yok. Stat bloğunda görünecek saldırı ve yetenekleri buradan ekle.'**
  String get mcNoActions;

  /// No description provided for @mcAddAction.
  ///
  /// In tr, this message translates to:
  /// **'Aksiyon ekle'**
  String get mcAddAction;

  /// No description provided for @mcActionNameHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Bite'**
  String get mcActionNameHint;

  /// No description provided for @mcCrBreakdown.
  ///
  /// In tr, this message translates to:
  /// **'Savunma CR {defensive} · Saldırı CR {offensive}'**
  String mcCrBreakdown(String defensive, String offensive);

  /// No description provided for @seShortDesc.
  ///
  /// In tr, this message translates to:
  /// **'Kısa tanım (isteğe bağlı)'**
  String get seShortDesc;

  /// No description provided for @seFeaturesHint.
  ///
  /// In tr, this message translates to:
  /// **'Hangi seviyede ne kazanılıyor. Level atlarken bunlar kendiliğinden gelir ve karakter kâğıdında görünür.'**
  String get seFeaturesHint;

  /// No description provided for @seNoFeatures.
  ///
  /// In tr, this message translates to:
  /// **'Henüz yetenek eklenmedi.'**
  String get seNoFeatures;

  /// No description provided for @seResources.
  ///
  /// In tr, this message translates to:
  /// **'Sayaçlar'**
  String get seResources;

  /// No description provided for @seResourcesHint.
  ///
  /// In tr, this message translates to:
  /// **'Seviyeye göre büyüyen değerler: üstünlük zarı, ki puanı, kullanım hakkı… Karakter kâğıdında sayaç olarak görünür.'**
  String get seResourcesHint;

  /// No description provided for @seNoResources.
  ///
  /// In tr, this message translates to:
  /// **'Sayaç yok. Çoğu alt sınıfta gerekmez.'**
  String get seNoResources;

  /// No description provided for @seAddFeature.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek ekle'**
  String get seAddFeature;

  /// No description provided for @seFeatureName.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek adı'**
  String get seFeatureName;

  /// No description provided for @seFeatureNameHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Combat Superiority'**
  String get seFeatureNameHint;

  /// No description provided for @seFeatureDesc.
  ///
  /// In tr, this message translates to:
  /// **'Ne yapar?'**
  String get seFeatureDesc;

  /// No description provided for @seAddResource.
  ///
  /// In tr, this message translates to:
  /// **'Sayaç ekle'**
  String get seAddResource;

  /// No description provided for @seResourceName.
  ///
  /// In tr, this message translates to:
  /// **'Sayaç adı'**
  String get seResourceName;

  /// No description provided for @seResourceNameHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. Üstünlük Zarı'**
  String get seResourceNameHint;

  /// No description provided for @seResourceHint.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca değiştiği seviyeleri gir; aradakiler otomatik doldurulur.'**
  String get seResourceHint;

  /// No description provided for @seAddThreshold.
  ///
  /// In tr, this message translates to:
  /// **'Değişim noktası ekle'**
  String get seAddThreshold;

  /// No description provided for @seThreshold.
  ///
  /// In tr, this message translates to:
  /// **'Değişim noktası'**
  String get seThreshold;

  /// No description provided for @seValue.
  ///
  /// In tr, this message translates to:
  /// **'Değer'**
  String get seValue;

  /// No description provided for @seValueHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. 4  ya da  1d8'**
  String get seValueHint;

  /// No description provided for @seSubclassOf.
  ///
  /// In tr, this message translates to:
  /// **'{className} alt sınıfı'**
  String seSubclassOf(String className);

  /// No description provided for @seLevelArrow.
  ///
  /// In tr, this message translates to:
  /// **'{level}. sv → {value}'**
  String seLevelArrow(int level, String value);

  /// No description provided for @sdAddFromLibrary.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphaneden ekle'**
  String get sdAddFromLibrary;

  /// No description provided for @sdCreateOwnItem.
  ///
  /// In tr, this message translates to:
  /// **'Kendi eşyanı yarat'**
  String get sdCreateOwnItem;

  /// No description provided for @sdCreateOwnMagic.
  ///
  /// In tr, this message translates to:
  /// **'Kendi büyülü eşyanı yarat'**
  String get sdCreateOwnMagic;

  /// No description provided for @sdAddFreeLine.
  ///
  /// In tr, this message translates to:
  /// **'Serbest satır ekle'**
  String get sdAddFreeLine;

  /// No description provided for @sdStockEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Stok boş. Sağ üstteki butonlardan eşya ekle.'**
  String get sdStockEmpty;

  /// No description provided for @sdPriceMultiplier.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat çarpanı'**
  String get sdPriceMultiplier;

  /// No description provided for @sdPriceMultiplierHint.
  ///
  /// In tr, this message translates to:
  /// **'Liste fiyatlarına uygulanır. Pazarlıkta düşür, ıssız kasabada yükselt.'**
  String get sdPriceMultiplierHint;

  /// No description provided for @sdOpenToPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara aç'**
  String get sdOpenToPlayers;

  /// No description provided for @sdOpenHint.
  ///
  /// In tr, this message translates to:
  /// **'Açıkken oyuncuların panelinde bu mağaza görünür. Aynı anda tek mağaza açık olabilir.'**
  String get sdOpenHint;

  /// No description provided for @sdMapAccessible.
  ///
  /// In tr, this message translates to:
  /// **'Haritadan erişilebilir'**
  String get sdMapAccessible;

  /// No description provided for @sdMapAccessibleHint.
  ///
  /// In tr, this message translates to:
  /// **'Açıkken oyuncular, görünür bir haritadaki bu mağazanın pinine dokunarak dükkânı açabilir. Birden fazla mağaza aynı anda erişilebilir olabilir.'**
  String get sdMapAccessibleHint;

  /// No description provided for @sdClosed.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza kapalı'**
  String get sdClosed;

  /// No description provided for @sdClosedHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıyken oyuncular mağazaya tıklayınca “mağaza kapalı” görür; eşyalar listelenmez ve satın alınamaz.'**
  String get sdClosedHint;

  /// No description provided for @sdRequireApproval.
  ///
  /// In tr, this message translates to:
  /// **'Satın alma onayı iste'**
  String get sdRequireApproval;

  /// No description provided for @sdRequireApprovalHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıysa oyuncular doğrudan satın alır; altınları ve stok anında düşer.'**
  String get sdRequireApprovalHint;

  /// No description provided for @sdUnlimited.
  ///
  /// In tr, this message translates to:
  /// **'sınırsız'**
  String get sdUnlimited;

  /// No description provided for @sdEditPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyatı değiştir'**
  String get sdEditPrice;

  /// No description provided for @sdEditQuantity.
  ///
  /// In tr, this message translates to:
  /// **'Adedi değiştir'**
  String get sdEditQuantity;

  /// No description provided for @sdMakeUnlimited.
  ///
  /// In tr, this message translates to:
  /// **'Sınırsız yap'**
  String get sdMakeUnlimited;

  /// No description provided for @sdRestock.
  ///
  /// In tr, this message translates to:
  /// **'Stok yenilemesi'**
  String get sdRestock;

  /// No description provided for @sdRestockHint.
  ///
  /// In tr, this message translates to:
  /// **'Kaç oyun-içi günde bir stok tazelensin? Takvim ilerledikçe süresi dolan mağazalar kendiliğinden yenilenir.'**
  String get sdRestockHint;

  /// No description provided for @sdRestockOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get sdRestockOff;

  /// No description provided for @sdRestockEvery.
  ///
  /// In tr, this message translates to:
  /// **'{days} günde bir'**
  String sdRestockEvery(int days);

  /// No description provided for @sdRestockQty.
  ///
  /// In tr, this message translates to:
  /// **'Yenileme adedi'**
  String get sdRestockQty;

  /// No description provided for @sdRestockQtyTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} — yenilemede kaç adet'**
  String sdRestockQtyTitle(String name);

  /// No description provided for @sdRestockQtyHint.
  ///
  /// In tr, this message translates to:
  /// **'Yenilemede adet bu değere döner. Ayarlamazsan bu satır hiç yenilenmez — tükenince biter.'**
  String get sdRestockQtyHint;

  /// No description provided for @sdRestockQtyClear.
  ///
  /// In tr, this message translates to:
  /// **'Bu satırı yenileme'**
  String get sdRestockQtyClear;

  /// No description provided for @sdRestockQtyBadge.
  ///
  /// In tr, this message translates to:
  /// **'yenileme: {count}'**
  String sdRestockQtyBadge(int count);

  /// No description provided for @shopRestocked.
  ///
  /// In tr, this message translates to:
  /// **'Stok yenilendi: {shops}'**
  String shopRestocked(String shops);

  /// No description provided for @sdOperator.
  ///
  /// In tr, this message translates to:
  /// **'İşleten: {name}'**
  String sdOperator(String name);

  /// No description provided for @sdOperatorNone.
  ///
  /// In tr, this message translates to:
  /// **'İşleten belirtilmedi'**
  String get sdOperatorNone;

  /// No description provided for @sdOpenOwnerNpc.
  ///
  /// In tr, this message translates to:
  /// **'NPC kartını aç'**
  String get sdOpenOwnerNpc;

  /// No description provided for @sdPieces.
  ///
  /// In tr, this message translates to:
  /// **'{count} adet'**
  String sdPieces(int count);

  /// No description provided for @sdPriceTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} — fiyat'**
  String sdPriceTitle(String name);

  /// No description provided for @sdQtyTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} — adet'**
  String sdQtyTitle(String name);

  /// No description provided for @cwStepIdentity.
  ///
  /// In tr, this message translates to:
  /// **'Kimlik ve tür'**
  String get cwStepIdentity;

  /// No description provided for @cwStepBackground.
  ///
  /// In tr, this message translates to:
  /// **'Köken (background)'**
  String get cwStepBackground;

  /// No description provided for @cwStepClass.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf'**
  String get cwStepClass;

  /// No description provided for @cwStepEquipment.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç eşyaları'**
  String get cwStepEquipment;

  /// No description provided for @cwStepSummary.
  ///
  /// In tr, this message translates to:
  /// **'Özet'**
  String get cwStepSummary;

  /// No description provided for @cwNext.
  ///
  /// In tr, this message translates to:
  /// **'İleri'**
  String get cwNext;

  /// No description provided for @cwCreateCharacter.
  ///
  /// In tr, this message translates to:
  /// **'Karakteri oluştur'**
  String get cwCreateCharacter;

  /// No description provided for @cwCharacterName.
  ///
  /// In tr, this message translates to:
  /// **'Karakter adı'**
  String get cwCharacterName;

  /// No description provided for @cwPlayerName.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncu adı (isteğe bağlı)'**
  String get cwPlayerName;

  /// No description provided for @cwAddPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf ekle'**
  String get cwAddPhoto;

  /// No description provided for @cwSpecies.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get cwSpecies;

  /// No description provided for @cwChooseSize.
  ///
  /// In tr, this message translates to:
  /// **'Boyut seç'**
  String get cwChooseSize;

  /// No description provided for @cwBackground.
  ///
  /// In tr, this message translates to:
  /// **'Köken'**
  String get cwBackground;

  /// No description provided for @cwTool.
  ///
  /// In tr, this message translates to:
  /// **'Alet'**
  String get cwTool;

  /// No description provided for @cwBackgroundFeat.
  ///
  /// In tr, this message translates to:
  /// **'Köken feat’i'**
  String get cwBackgroundFeat;

  /// No description provided for @cwAbilityIncrease3.
  ///
  /// In tr, this message translates to:
  /// **'Yetenek artışı (3 puan)'**
  String get cwAbilityIncrease3;

  /// No description provided for @cwOriginPointsHint.
  ///
  /// In tr, this message translates to:
  /// **'2024 kurallarında köken 3 puan verir: ya bir yeteneğe +2 ve diğerine +1, ya da üçüne birer +1.'**
  String get cwOriginPointsHint;

  /// No description provided for @cwHitDie.
  ///
  /// In tr, this message translates to:
  /// **'Can zarı'**
  String get cwHitDie;

  /// No description provided for @cwWeapons.
  ///
  /// In tr, this message translates to:
  /// **'Silahlar'**
  String get cwWeapons;

  /// No description provided for @cwArmor.
  ///
  /// In tr, this message translates to:
  /// **'Zırh'**
  String get cwArmor;

  /// No description provided for @cwTools.
  ///
  /// In tr, this message translates to:
  /// **'Aletler'**
  String get cwTools;

  /// No description provided for @cwSubclassLater.
  ///
  /// In tr, this message translates to:
  /// **'Alt sınıf 3. seviyede seçilir — seviye atlama akışında gelecek.'**
  String get cwSubclassLater;

  /// No description provided for @cwSelectionDone.
  ///
  /// In tr, this message translates to:
  /// **'Seçim tamam'**
  String get cwSelectionDone;

  /// No description provided for @cwChooseClassFirst.
  ///
  /// In tr, this message translates to:
  /// **'Önce sınıf seçin.'**
  String get cwChooseClassFirst;

  /// No description provided for @cwEquipmentHint.
  ///
  /// In tr, this message translates to:
  /// **'Sınıfın ve kökenin aynı harfli seçeneği birlikte alınır.'**
  String get cwEquipmentHint;

  /// No description provided for @cwEquipmentNote.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğin eşyalar ve altın envantere otomatik eklenir; sonra karakter kağıdının envanter bölümünden düzenleyebilirsin.'**
  String get cwEquipmentNote;

  /// No description provided for @cwUnnamed.
  ///
  /// In tr, this message translates to:
  /// **'İsimsiz'**
  String get cwUnnamed;

  /// No description provided for @cwPointBuy.
  ///
  /// In tr, this message translates to:
  /// **'Puan dağıtımı'**
  String get cwPointBuy;

  /// No description provided for @cwStandardArray.
  ///
  /// In tr, this message translates to:
  /// **'Standart dizi'**
  String get cwStandardArray;

  /// No description provided for @cwManual.
  ///
  /// In tr, this message translates to:
  /// **'Elle gir'**
  String get cwManual;

  /// No description provided for @sheetUnknownItem.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen eşya'**
  String get sheetUnknownItem;

  /// No description provided for @pfInvalidQuantity.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz adet.'**
  String get pfInvalidQuantity;

  /// No description provided for @pfItemNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Eşya bulunamadı.'**
  String get pfItemNotFound;

  /// No description provided for @pfShopNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza bulunamadı.'**
  String get pfShopNotFound;

  /// No description provided for @pfShopClosed.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza şu anda kapalı.'**
  String get pfShopClosed;

  /// No description provided for @pfSoldOut.
  ///
  /// In tr, this message translates to:
  /// **'Bu eşya tükendi.'**
  String get pfSoldOut;

  /// No description provided for @pfCharacterNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Karakter bulunamadı.'**
  String get pfCharacterNotFound;

  /// No description provided for @pfRequestNotFound.
  ///
  /// In tr, this message translates to:
  /// **'İstek bulunamadı.'**
  String get pfRequestNotFound;

  /// No description provided for @pfOnlyNLeft.
  ///
  /// In tr, this message translates to:
  /// **'Stokta yalnızca {n} adet var.'**
  String pfOnlyNLeft(String n);

  /// No description provided for @pfNotEnoughGold.
  ///
  /// In tr, this message translates to:
  /// **'Paran yetmiyor: {need} gerekiyor, {have} var.'**
  String pfNotEnoughGold(String need, String have);

  /// No description provided for @cwPointsRemaining.
  ///
  /// In tr, this message translates to:
  /// **'Kalan puan: {n}'**
  String cwPointsRemaining(int n);

  /// No description provided for @cwChooseMoreSkills.
  ///
  /// In tr, this message translates to:
  /// **'Sınıfından {n} beceri daha seç'**
  String cwChooseMoreSkills(int n);

  /// No description provided for @cwFromBackground.
  ///
  /// In tr, this message translates to:
  /// **'Kökeninden zaten geliyor: {skills}'**
  String cwFromBackground(String skills);

  /// No description provided for @cwOption.
  ///
  /// In tr, this message translates to:
  /// **'Seçenek {label}'**
  String cwOption(String label);

  /// No description provided for @cwBackgroundPrefix.
  ///
  /// In tr, this message translates to:
  /// **'Köken: {desc}'**
  String cwBackgroundPrefix(String desc);

  /// No description provided for @backupExport.
  ///
  /// In tr, this message translates to:
  /// **'Yedek al'**
  String get backupExport;

  /// No description provided for @backupExportHint.
  ///
  /// In tr, this message translates to:
  /// **'Karakterler, NPC\'ler, dünya, Kayıtlar, oyuncu notları, envanterler, görevler, oturum günlüğü ve kendi eklediğin içerik tek dosyaya yazılır. Görseller yol olarak değil, dosyanın kendisi olarak gömülür. Kural kütüphanesi (SRD) yedeğe girmez — uygulama onu zaten kendi içinde taşıyor.'**
  String get backupExportHint;

  /// No description provided for @backupCreateFile.
  ///
  /// In tr, this message translates to:
  /// **'Yedek dosyası oluştur'**
  String get backupCreateFile;

  /// No description provided for @backupExportedHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu dosyayı bilgisayara kopyala ya da buluta yükle; uygulamayı silersen cihazdaki kopya da gider.'**
  String get backupExportedHint;

  /// No description provided for @backupRestore.
  ///
  /// In tr, this message translates to:
  /// **'Yedekten dön'**
  String get backupRestore;

  /// No description provided for @backupRestoreHint.
  ///
  /// In tr, this message translates to:
  /// **'Şu anki karakterlerin, savaşların, mağazaların ve haritaların yedektekilerle DEĞİŞTİRİLİR. Yedekte olmayan kayıtlar silinir.'**
  String get backupRestoreHint;

  /// No description provided for @backupPickFile.
  ///
  /// In tr, this message translates to:
  /// **'Yedek dosyası seç'**
  String get backupPickFile;

  /// No description provided for @backupWillReplace.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut verilerin bunlarla değiştirilecek.'**
  String get backupWillReplace;

  /// No description provided for @backupRestoreButton.
  ///
  /// In tr, this message translates to:
  /// **'Geri yükle'**
  String get backupRestoreButton;

  /// No description provided for @backupRestored.
  ///
  /// In tr, this message translates to:
  /// **'Yedek geri yüklendi.'**
  String get backupRestored;

  /// No description provided for @backupFileType.
  ///
  /// In tr, this message translates to:
  /// **'Yedek'**
  String get backupFileType;

  /// No description provided for @backupLabelCharacters.
  ///
  /// In tr, this message translates to:
  /// **'Karakter'**
  String get backupLabelCharacters;

  /// No description provided for @backupLabelEncounters.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaşma'**
  String get backupLabelEncounters;

  /// No description provided for @backupLabelCombatants.
  ///
  /// In tr, this message translates to:
  /// **'Savaşçı'**
  String get backupLabelCombatants;

  /// No description provided for @backupLabelShops.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza'**
  String get backupLabelShops;

  /// No description provided for @backupLabelShopStock.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza satırı'**
  String get backupLabelShopStock;

  /// No description provided for @backupLabelLocations.
  ///
  /// In tr, this message translates to:
  /// **'Yer'**
  String get backupLabelLocations;

  /// No description provided for @backupLabelMapPins.
  ///
  /// In tr, this message translates to:
  /// **'Harita pini'**
  String get backupLabelMapPins;

  /// No description provided for @backupLabelNpcs.
  ///
  /// In tr, this message translates to:
  /// **'NPC'**
  String get backupLabelNpcs;

  /// No description provided for @backupLabelMonsters.
  ///
  /// In tr, this message translates to:
  /// **'Kendi canavarın'**
  String get backupLabelMonsters;

  /// No description provided for @backupLabelItems.
  ///
  /// In tr, this message translates to:
  /// **'Kendi eşyan'**
  String get backupLabelItems;

  /// No description provided for @backupLabelMagicItems.
  ///
  /// In tr, this message translates to:
  /// **'Kendi büyülü eşyan'**
  String get backupLabelMagicItems;

  /// No description provided for @backupLabelClasses.
  ///
  /// In tr, this message translates to:
  /// **'Kendi sınıf/alt sınıfın'**
  String get backupLabelClasses;

  /// No description provided for @backupLabelSpecies.
  ///
  /// In tr, this message translates to:
  /// **'Kendi türün'**
  String get backupLabelSpecies;

  /// No description provided for @backupLabelBackgrounds.
  ///
  /// In tr, this message translates to:
  /// **'Kendi kökenin'**
  String get backupLabelBackgrounds;

  /// No description provided for @backupLabelCodexPages.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar sayfaları'**
  String get backupLabelCodexPages;

  /// No description provided for @backupLabelCodexBlocks.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar blokları'**
  String get backupLabelCodexBlocks;

  /// No description provided for @backupLabelClassLevels.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf seviyeleri'**
  String get backupLabelClassLevels;

  /// No description provided for @backupLabelProficiencies.
  ///
  /// In tr, this message translates to:
  /// **'Yeterlilikler'**
  String get backupLabelProficiencies;

  /// No description provided for @backupLabelInventory.
  ///
  /// In tr, this message translates to:
  /// **'Envanter'**
  String get backupLabelInventory;

  /// No description provided for @backupLabelCharacterSpells.
  ///
  /// In tr, this message translates to:
  /// **'Büyüler'**
  String get backupLabelCharacterSpells;

  /// No description provided for @backupLabelCharacterFeatures.
  ///
  /// In tr, this message translates to:
  /// **'Yetenekler'**
  String get backupLabelCharacterFeatures;

  /// No description provided for @backupLabelPlayerNotes.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncu notları'**
  String get backupLabelPlayerNotes;

  /// No description provided for @backupLabelLootSets.
  ///
  /// In tr, this message translates to:
  /// **'Ganimet setleri'**
  String get backupLabelLootSets;

  /// No description provided for @backupLabelQuests.
  ///
  /// In tr, this message translates to:
  /// **'Görevler'**
  String get backupLabelQuests;

  /// No description provided for @backupLabelWorldLinks.
  ///
  /// In tr, this message translates to:
  /// **'Dünya bağları'**
  String get backupLabelWorldLinks;

  /// No description provided for @backupLabelBondTypes.
  ///
  /// In tr, this message translates to:
  /// **'Bağ türleri'**
  String get backupLabelBondTypes;

  /// No description provided for @backupLabelFeats.
  ///
  /// In tr, this message translates to:
  /// **'Feat\'ler'**
  String get backupLabelFeats;

  /// No description provided for @backupLabelSessionLog.
  ///
  /// In tr, this message translates to:
  /// **'Oturum günlüğü'**
  String get backupLabelSessionLog;

  /// No description provided for @backupExportedKb.
  ///
  /// In tr, this message translates to:
  /// **'Yedek alındı: {kb} KB'**
  String backupExportedKb(int kb);

  /// No description provided for @backupExportFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yedek alınamadı: {error}'**
  String backupExportFailed(String error);

  /// No description provided for @backupReadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bu dosya okunamadı: {error}'**
  String backupReadFailed(String error);

  /// No description provided for @backupDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih: {date}'**
  String backupDate(String date);

  /// No description provided for @backupMapFiles.
  ///
  /// In tr, this message translates to:
  /// **'Harita dosyası: {count}'**
  String backupMapFiles(int count);

  /// No description provided for @backupPortraitFiles.
  ///
  /// In tr, this message translates to:
  /// **'Portre dosyası: {count}'**
  String backupPortraitFiles(int count);

  /// No description provided for @backupMediaFiles.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar videosu: {count}'**
  String backupMediaFiles(Object count);

  /// No description provided for @backupMusicFiles.
  ///
  /// In tr, this message translates to:
  /// **'Müzik dosyası: {count}'**
  String backupMusicFiles(int count);

  /// No description provided for @backupImportAsCampaign.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kampanya olarak içe aktar'**
  String get backupImportAsCampaign;

  /// No description provided for @backupImportAsCampaignHint.
  ///
  /// In tr, this message translates to:
  /// **'Yedeği ayrı bir kampanya olarak kurar; açık kampanyaya dokunmaz. Başkasının masasını yanına almak ya da eski bir kaydı saklamak için.'**
  String get backupImportAsCampaignHint;

  /// No description provided for @backupImportButton.
  ///
  /// In tr, this message translates to:
  /// **'İçe aktar'**
  String get backupImportButton;

  /// No description provided for @backupImportedAsCampaign.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” kampanyası yedekten kuruldu.'**
  String backupImportedAsCampaign(String name);

  /// No description provided for @backupOpenImportedCampaign.
  ///
  /// In tr, this message translates to:
  /// **'Bu kampanyaya şimdi geçilsin mi? Açık masa kapanır ve oyunculara yeni bir katılma adresi gerekir.'**
  String get backupOpenImportedCampaign;

  /// No description provided for @backupLabelPartyInventories.
  ///
  /// In tr, this message translates to:
  /// **'Ortak keseler'**
  String get backupLabelPartyInventories;

  /// No description provided for @backupLabelRandomTables.
  ///
  /// In tr, this message translates to:
  /// **'Rastgele tablolar'**
  String get backupLabelRandomTables;

  /// No description provided for @backupLabelJourneys.
  ///
  /// In tr, this message translates to:
  /// **'Yolculuklar'**
  String get backupLabelJourneys;

  /// No description provided for @backupLabelCalendar.
  ///
  /// In tr, this message translates to:
  /// **'Takvim yapısı'**
  String get backupLabelCalendar;

  /// No description provided for @backupLabelEras.
  ///
  /// In tr, this message translates to:
  /// **'Çağlar'**
  String get backupLabelEras;

  /// No description provided for @backupLabelChronicle.
  ///
  /// In tr, this message translates to:
  /// **'Tarihçe olayları'**
  String get backupLabelChronicle;

  /// No description provided for @backupLabelReminders.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatıcılar'**
  String get backupLabelReminders;

  /// No description provided for @backupLabelMusicPlaylists.
  ///
  /// In tr, this message translates to:
  /// **'Müzik listeleri'**
  String get backupLabelMusicPlaylists;

  /// No description provided for @backupLabelMusicTracks.
  ///
  /// In tr, this message translates to:
  /// **'Müzik parçaları'**
  String get backupLabelMusicTracks;

  /// No description provided for @backupLabelSpells.
  ///
  /// In tr, this message translates to:
  /// **'Büyüler'**
  String get backupLabelSpells;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In tr, this message translates to:
  /// **'Geri yükleme başarısız: {error}'**
  String backupRestoreFailed(String error);

  /// No description provided for @sheetOrdinalLevel.
  ///
  /// In tr, this message translates to:
  /// **'{n}. seviye'**
  String sheetOrdinalLevel(int n);

  /// No description provided for @sheetAbilityCheck.
  ///
  /// In tr, this message translates to:
  /// **'{ability} kontrolü'**
  String sheetAbilityCheck(String ability);

  /// No description provided for @sheetAbilitySave.
  ///
  /// In tr, this message translates to:
  /// **'{ability} kurtarma'**
  String sheetAbilitySave(String ability);

  /// No description provided for @sheetTempHp.
  ///
  /// In tr, this message translates to:
  /// **'+{n} geçici'**
  String sheetTempHp(int n);

  /// No description provided for @sheetPactMagic.
  ///
  /// In tr, this message translates to:
  /// **'Pact Magic ({n}. sv)'**
  String sheetPactMagic(int n);

  /// No description provided for @sheetExhaustionPenalty.
  ///
  /// In tr, this message translates to:
  /// **'Tüm d20 testlerine {n} ceza uygulanıyor.'**
  String sheetExhaustionPenalty(int n);

  /// No description provided for @sheetHitDieHealed.
  ///
  /// In tr, this message translates to:
  /// **'{n} HP iyileşti (1 hit die).'**
  String sheetHitDieHealed(int n);

  /// No description provided for @diceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Zar'**
  String get diceTitle;

  /// No description provided for @diceCritical.
  ///
  /// In tr, this message translates to:
  /// **'Kritik!'**
  String get diceCritical;

  /// No description provided for @diceFumble.
  ///
  /// In tr, this message translates to:
  /// **'Başarısızlık!'**
  String get diceFumble;

  /// No description provided for @navNpcs.
  ///
  /// In tr, this message translates to:
  /// **'NPC\'ler'**
  String get navNpcs;

  /// No description provided for @aiToolNpcTab.
  ///
  /// In tr, this message translates to:
  /// **'NPC'**
  String get aiToolNpcTab;

  /// No description provided for @npcProfession.
  ///
  /// In tr, this message translates to:
  /// **'Meslek'**
  String get npcProfession;

  /// No description provided for @npcProfessionHint.
  ///
  /// In tr, this message translates to:
  /// **'demirci, meyhaneci, muhafız...'**
  String get npcProfessionHint;

  /// No description provided for @npcGender.
  ///
  /// In tr, this message translates to:
  /// **'Cinsiyet'**
  String get npcGender;

  /// No description provided for @npcGenderMale.
  ///
  /// In tr, this message translates to:
  /// **'Erkek'**
  String get npcGenderMale;

  /// No description provided for @npcGenderFemale.
  ///
  /// In tr, this message translates to:
  /// **'Kadın'**
  String get npcGenderFemale;

  /// No description provided for @npcGenderOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get npcGenderOther;

  /// No description provided for @npcGenderRandom.
  ///
  /// In tr, this message translates to:
  /// **'Rastgele'**
  String get npcGenderRandom;

  /// No description provided for @npcRace.
  ///
  /// In tr, this message translates to:
  /// **'Tür / ırk'**
  String get npcRace;

  /// No description provided for @npcRaceHint.
  ///
  /// In tr, this message translates to:
  /// **'insan, cüce, elf... (boş = serbest)'**
  String get npcRaceHint;

  /// No description provided for @npcName.
  ///
  /// In tr, this message translates to:
  /// **'İsim (opsiyonel)'**
  String get npcName;

  /// No description provided for @npcNameHint.
  ///
  /// In tr, this message translates to:
  /// **'boş bırakılırsa AI üretir'**
  String get npcNameHint;

  /// No description provided for @npcExtra.
  ///
  /// In tr, this message translates to:
  /// **'Ek bilgiler'**
  String get npcExtra;

  /// No description provided for @npcExtraHint.
  ///
  /// In tr, this message translates to:
  /// **'kişilik, konum, olay örgüsüyle bağ, ton...'**
  String get npcExtraHint;

  /// No description provided for @npcHeading.
  ///
  /// In tr, this message translates to:
  /// **'NPC'**
  String get npcHeading;

  /// No description provided for @npcSectionAppearance.
  ///
  /// In tr, this message translates to:
  /// **'Görünüş'**
  String get npcSectionAppearance;

  /// No description provided for @npcSectionPersonality.
  ///
  /// In tr, this message translates to:
  /// **'Kişilik'**
  String get npcSectionPersonality;

  /// No description provided for @npcTraitIdeal.
  ///
  /// In tr, this message translates to:
  /// **'İdeal'**
  String get npcTraitIdeal;

  /// No description provided for @npcTraitBond.
  ///
  /// In tr, this message translates to:
  /// **'Bağ'**
  String get npcTraitBond;

  /// No description provided for @npcTraitFlaw.
  ///
  /// In tr, this message translates to:
  /// **'Kusur'**
  String get npcTraitFlaw;

  /// No description provided for @npcSectionHook.
  ///
  /// In tr, this message translates to:
  /// **'Rol yapma kancası'**
  String get npcSectionHook;

  /// No description provided for @npcSectionSecret.
  ///
  /// In tr, this message translates to:
  /// **'Sır (yalnızca DM)'**
  String get npcSectionSecret;

  /// No description provided for @npcSaveToNpcs.
  ///
  /// In tr, this message translates to:
  /// **'NPC\'lere kaydet'**
  String get npcSaveToNpcs;

  /// No description provided for @npcSavedToNpcs.
  ///
  /// In tr, this message translates to:
  /// **'NPC\'lere kaydedildi'**
  String get npcSavedToNpcs;

  /// No description provided for @worldGraphConnect.
  ///
  /// In tr, this message translates to:
  /// **'Bağla'**
  String get worldGraphConnect;

  /// No description provided for @worldGraphConnectHint.
  ///
  /// In tr, this message translates to:
  /// **'İki düğüme dokun → bağla · kenara dokun → menü'**
  String get worldGraphConnectHint;

  /// No description provided for @worldGraphChangeType.
  ///
  /// In tr, this message translates to:
  /// **'Tür değiştir'**
  String get worldGraphChangeType;

  /// No description provided for @worldGraphDeleteLink.
  ///
  /// In tr, this message translates to:
  /// **'Bağı sil'**
  String get worldGraphDeleteLink;

  /// No description provided for @worldGraphOpenLocation.
  ///
  /// In tr, this message translates to:
  /// **'Yeri aç'**
  String get worldGraphOpenLocation;

  /// No description provided for @worldGraphShowToPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculara göster'**
  String get worldGraphShowToPlayers;

  /// No description provided for @worldGraphHideFromPlayers.
  ///
  /// In tr, this message translates to:
  /// **'Oyunculardan gizle'**
  String get worldGraphHideFromPlayers;

  /// No description provided for @worldGraphShownNotice.
  ///
  /// In tr, this message translates to:
  /// **'{name} artık oyunculara açık.'**
  String worldGraphShownNotice(String name);

  /// No description provided for @worldGraphHiddenNotice.
  ///
  /// In tr, this message translates to:
  /// **'{name} oyunculardan gizlendi.'**
  String worldGraphHiddenNotice(String name);

  /// No description provided for @worldGraphSetSize.
  ///
  /// In tr, this message translates to:
  /// **'Küre boyutu'**
  String get worldGraphSetSize;

  /// No description provided for @worldGraphSizeHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçili kürenin görsel yarıçapını girin'**
  String get worldGraphSizeHint;

  /// No description provided for @worldGraphNodeRadiusLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yarıçap'**
  String get worldGraphNodeRadiusLabel;

  /// No description provided for @worldDeleteNpc.
  ///
  /// In tr, this message translates to:
  /// **'Bu NPC\'yi sil'**
  String get worldDeleteNpc;

  /// No description provided for @bondRoad.
  ///
  /// In tr, this message translates to:
  /// **'Yol / Nötr'**
  String get bondRoad;

  /// No description provided for @bondFriendship.
  ///
  /// In tr, this message translates to:
  /// **'Dostluk'**
  String get bondFriendship;

  /// No description provided for @bondEnmity.
  ///
  /// In tr, this message translates to:
  /// **'Düşmanlık'**
  String get bondEnmity;

  /// No description provided for @bondTrade.
  ///
  /// In tr, this message translates to:
  /// **'Ticaret'**
  String get bondTrade;

  /// No description provided for @bondFamily.
  ///
  /// In tr, this message translates to:
  /// **'Aile'**
  String get bondFamily;

  /// No description provided for @bondAlliance.
  ///
  /// In tr, this message translates to:
  /// **'Müttefik'**
  String get bondAlliance;

  /// No description provided for @bondRivalry.
  ///
  /// In tr, this message translates to:
  /// **'Rakip'**
  String get bondRivalry;

  /// No description provided for @bondLove.
  ///
  /// In tr, this message translates to:
  /// **'Aşk'**
  String get bondLove;

  /// No description provided for @bondVassalage.
  ///
  /// In tr, this message translates to:
  /// **'Tabiiyet'**
  String get bondVassalage;

  /// No description provided for @npcAge.
  ///
  /// In tr, this message translates to:
  /// **'Yaş'**
  String get npcAge;

  /// No description provided for @npcAlignment.
  ///
  /// In tr, this message translates to:
  /// **'Hizalama'**
  String get npcAlignment;

  /// No description provided for @npcAddPortrait.
  ///
  /// In tr, this message translates to:
  /// **'Portre ekle'**
  String get npcAddPortrait;

  /// No description provided for @npcChangePortrait.
  ///
  /// In tr, this message translates to:
  /// **'Portreyi değiştir'**
  String get npcChangePortrait;

  /// No description provided for @npcNotes.
  ///
  /// In tr, this message translates to:
  /// **'Notlar'**
  String get npcNotes;

  /// No description provided for @npcSecretLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sır (yalnızca DM)'**
  String get npcSecretLabel;

  /// No description provided for @bondSettingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bağ türleri'**
  String get bondSettingsTitle;

  /// No description provided for @bondNewType.
  ///
  /// In tr, this message translates to:
  /// **'Yeni tür'**
  String get bondNewType;

  /// No description provided for @bondColorLabel.
  ///
  /// In tr, this message translates to:
  /// **'Renk'**
  String get bondColorLabel;

  /// No description provided for @bondHexLabel.
  ///
  /// In tr, this message translates to:
  /// **'Hex'**
  String get bondHexLabel;

  /// No description provided for @bondBrightness.
  ///
  /// In tr, this message translates to:
  /// **'Parlaklık'**
  String get bondBrightness;

  /// No description provided for @navMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla'**
  String get navMore;

  /// No description provided for @navMoreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm bölümler'**
  String get navMoreTitle;

  /// No description provided for @navGroupTable.
  ///
  /// In tr, this message translates to:
  /// **'Masada'**
  String get navGroupTable;

  /// No description provided for @navGroupWorld.
  ///
  /// In tr, this message translates to:
  /// **'Dünya & öykü'**
  String get navGroupWorld;

  /// No description provided for @navGroupTools.
  ///
  /// In tr, this message translates to:
  /// **'Araçlar'**
  String get navGroupTools;

  /// No description provided for @stateErrorTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti'**
  String get stateErrorTitle;

  /// No description provided for @stateErrorMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu bölüm yüklenemedi. Tekrar dene; sorun sürerse aşağıdaki teknik ayrıntı izini sürmeye yarar.'**
  String get stateErrorMessage;

  /// No description provided for @stateErrorDetail.
  ///
  /// In tr, this message translates to:
  /// **'Teknik ayrıntı'**
  String get stateErrorDetail;

  /// No description provided for @stateRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get stateRetry;

  /// No description provided for @stateLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor…'**
  String get stateLoading;

  /// No description provided for @npcBoundLocation.
  ///
  /// In tr, this message translates to:
  /// **'Bağlı olduğu yer'**
  String get npcBoundLocation;

  /// No description provided for @npcBoundLocationNone.
  ///
  /// In tr, this message translates to:
  /// **'Yer seçilmedi'**
  String get npcBoundLocationNone;

  /// No description provided for @npcBoundLocationHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçersen NPC bu yere haritada bağlanır ve metni de buraya göre üretilir.'**
  String get npcBoundLocationHint;

  /// No description provided for @npcNoLocations.
  ///
  /// In tr, this message translates to:
  /// **'Henüz yer yok. Dünya sekmesinden ekleyebilirsin.'**
  String get npcNoLocations;

  /// No description provided for @npcRelations.
  ///
  /// In tr, this message translates to:
  /// **'İlişkiler'**
  String get npcRelations;

  /// No description provided for @npcRelationsHint.
  ///
  /// In tr, this message translates to:
  /// **'İstediğin kadar NPC ile bağ kurabilirsin; bağ türleri harita grafiğindekilerle aynı.'**
  String get npcRelationsHint;

  /// No description provided for @npcAddRelation.
  ///
  /// In tr, this message translates to:
  /// **'İlişki ekle'**
  String get npcAddRelation;

  /// No description provided for @npcRemoveRelation.
  ///
  /// In tr, this message translates to:
  /// **'İlişkiyi kaldır'**
  String get npcRemoveRelation;

  /// No description provided for @npcRelationPickNpc.
  ///
  /// In tr, this message translates to:
  /// **'NPC seç'**
  String get npcRelationPickNpc;

  /// No description provided for @npcNoOtherNpcs.
  ///
  /// In tr, this message translates to:
  /// **'Bağ kuracak başka NPC yok. Önce NPC\'ler sekmesinden ekle.'**
  String get npcNoOtherNpcs;

  /// No description provided for @npcPortraitToggle.
  ///
  /// In tr, this message translates to:
  /// **'Portre üret'**
  String get npcPortraitToggle;

  /// No description provided for @npcPortraitToggleHint.
  ///
  /// In tr, this message translates to:
  /// **'Açıkken üretilen karakterin görünüşüne, ırkına, yaşına ve mizacına göre portre çizilir.'**
  String get npcPortraitToggleHint;

  /// No description provided for @npcPortraitUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'{provider} görsel üretmiyor. Portre için Ayarlar\'dan Gemini ya da OpenAI seç.'**
  String npcPortraitUnsupported(Object provider);

  /// No description provided for @npcPortraitGenerating.
  ///
  /// In tr, this message translates to:
  /// **'Portre çiziliyor…'**
  String get npcPortraitGenerating;

  /// No description provided for @npcPortraitFailed.
  ///
  /// In tr, this message translates to:
  /// **'Portre üretilemedi: {reason}'**
  String npcPortraitFailed(Object reason);

  /// No description provided for @npcPortraitRegenerate.
  ///
  /// In tr, this message translates to:
  /// **'Portreyi yeniden üret'**
  String get npcPortraitRegenerate;

  /// No description provided for @npcPortraitTitle.
  ///
  /// In tr, this message translates to:
  /// **'Portre'**
  String get npcPortraitTitle;

  /// No description provided for @npcSavedWithLinks.
  ///
  /// In tr, this message translates to:
  /// **'NPC kaydedildi ({count} bağ kuruldu).'**
  String npcSavedWithLinks(Object count);

  /// No description provided for @aiImageModel.
  ///
  /// In tr, this message translates to:
  /// **'Görsel modeli'**
  String get aiImageModel;

  /// No description provided for @aiImageModelHint.
  ///
  /// In tr, this message translates to:
  /// **'Portre üretimi için. Boş bırakırsan varsayılan kullanılır.'**
  String get aiImageModelHint;

  /// No description provided for @aiImageUnsupportedNote.
  ///
  /// In tr, this message translates to:
  /// **'Seçili sağlayıcı görsel üretmiyor; portre üretimi kapalı.'**
  String get aiImageUnsupportedNote;

  /// No description provided for @aiErrorDetail.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcının yanıtı'**
  String get aiErrorDetail;

  /// No description provided for @codexAiErrNoImage.
  ///
  /// In tr, this message translates to:
  /// **'Bu sağlayıcı görsel üretmiyor.'**
  String get codexAiErrNoImage;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'tr':
      return L10nTr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
