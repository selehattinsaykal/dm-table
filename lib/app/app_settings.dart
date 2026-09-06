import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama dili. Kod (`tr`/`en`) hem `Locale` hem kalicilik anahtari olur.
enum AppLang {
  tr('tr', 'Türkçe'),
  en('en', 'English');

  const AppLang(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLang fromCode(String? code) => AppLang.values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLang.en,
  );
}

/// Arayuzun ne kadar sikisik cizilecegi.
///
/// Masada asil bakilan sey haritalar, kagitlar ve listeler; cerceve ne kadar
/// az yer kaplarsa o kadar iyi. Bu yuzden VARSAYILAN [compact]: onceki ferah
/// yerlesim buyuk ekranda bile bir listeye yarim ekran harciyordu. Gozu
/// yorulan ya da dokunmatikle calisan kullanici [comfortable]'a gecebilir.
enum AppDensity {
  compact(-2, 0.94),
  normal(0, 1),
  comfortable(1, 1.05);

  const AppDensity(this.step, this.textScale);

  /// `VisualDensity` birimi (-4..4). Material'in dokunma hedefi hesabina
  /// giriyor: liste satirlari, dugmeler, alanlar hep buna gore kisaliyor.
  final double step;

  /// Metin olcegi; yalnizca yogunlukla birlikte hafifce oynatiliyor ki
  /// okunabilirlik kaybolmasin.
  final double textScale;

  VisualDensity get visualDensity =>
      VisualDensity(horizontal: step, vertical: step);

  static AppDensity fromName(String? name) => AppDensity.values.firstWhere(
    (d) => d.name == name,
    orElse: () => AppDensity.compact,
  );
}

/// Kullanicinin sectigi arayuz tercihleri. Cihaza yereldir; kampanya
/// dosyasina degil `shared_preferences`'a yazilir.
class AppSettings {
  const AppSettings({
    this.lang = AppLang.en,
    this.themeMode = ThemeMode.dark,
    this.density = AppDensity.compact,
    this.highContrast = false,
    this.colorBlindSafe = false,
    this.touchLayout = false,
    this.syncFolder,
  });

  final AppLang lang;
  final ThemeMode themeMode;
  final AppDensity density;

  /// Yuksek kontrast: kenarliklar belirginlesir, yuzey tonlari ayrisir.
  final bool highContrast;

  /// Renk korlugu uyumu.
  ///
  /// Jeton takimlari, hareket bantlari ve duvar turleri su an YALNIZCA
  /// renkle ayrisiyor; acikken renge ek olarak SEKIL/DESEN de tasiyorlar.
  /// Renk paletini degistirmek yerine ikinci bir isaret eklemek secildi:
  /// palet degistirmek "kirmizi dusman" gibi ogrenilmis eslesmeleri bozuyor.
  final bool colorBlindSafe;

  /// Dokunmatik duzen.
  ///
  /// Masada en dogal cihaz tablet ama harita ekrani orta tus (kaydirma) ve
  /// sag tik (menu) varsayiyor. Acikken bu islerin ekranda dugmesi olur ve
  /// dokunma hedefleri buyur.
  final bool touchLayout;

  /// Gunluk otomatik yedegin yazilacagi klasor; null = yalnizca uygulama
  /// klasoru.
  final String? syncFolder;

  AppSettings copyWith({
    AppLang? lang,
    ThemeMode? themeMode,
    AppDensity? density,
    bool? highContrast,
    bool? colorBlindSafe,
    bool? touchLayout,
    String? syncFolder,
    bool clearSyncFolder = false,
  }) => AppSettings(
    lang: lang ?? this.lang,
    themeMode: themeMode ?? this.themeMode,
    density: density ?? this.density,
    highContrast: highContrast ?? this.highContrast,
    colorBlindSafe: colorBlindSafe ?? this.colorBlindSafe,
    touchLayout: touchLayout ?? this.touchLayout,
    syncFolder: clearSyncFolder ? null : (syncFolder ?? this.syncFolder),
  );
}

/// Ayarlari `shared_preferences` ile okur/yazar. Ilk build senkron varsayilan
/// doner (koyu tema, Turkce -- mevcut davranis), ardindan kayitlari asenkron
/// yukleyip durumu gunceller.
class AppSettingsController extends Notifier<AppSettings> {
  static const _kLang = 'settings.lang';
  static const _kTheme = 'settings.themeMode';
  static const _kDensity = 'settings.density';
  static const _kHighContrast = 'settings.highContrast';
  static const _kColorBlind = 'settings.colorBlindSafe';
  static const _kTouch = 'settings.touchLayout';
  static const _kSyncFolder = 'settings.syncFolder';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      lang: AppLang.fromCode(prefs.getString(_kLang)),
      themeMode: _themeFromName(prefs.getString(_kTheme)),
      density: AppDensity.fromName(prefs.getString(_kDensity)),
      highContrast: prefs.getBool(_kHighContrast) ?? false,
      colorBlindSafe: prefs.getBool(_kColorBlind) ?? false,
      touchLayout: prefs.getBool(_kTouch) ?? false,
      syncFolder: prefs.getString(_kSyncFolder),
    );
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrast, value);
  }

  Future<void> setColorBlindSafe(bool value) async {
    state = state.copyWith(colorBlindSafe: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kColorBlind, value);
  }

  Future<void> setTouchLayout(bool value) async {
    state = state.copyWith(touchLayout: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTouch, value);
  }

  /// Yedek klasoru; null gecmek secimi kaldirir.
  Future<void> setSyncFolder(String? path) async {
    state = state.copyWith(syncFolder: path, clearSyncFolder: path == null);
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_kSyncFolder);
    } else {
      await prefs.setString(_kSyncFolder, path);
    }
  }

  Future<void> setDensity(AppDensity density) async {
    state = state.copyWith(density: density);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDensity, density.name);
  }

  Future<void> setLang(AppLang lang) async {
    state = state.copyWith(lang: lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, lang.code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode.name);
  }

  static ThemeMode _themeFromName(String? name) => ThemeMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => ThemeMode.dark,
  );
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
