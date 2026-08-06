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

/// Kullanicinin sectigi arayuz tercihleri (dil + tema). Cihaza yereldir
/// (oyuncu panelinde tarayici localStorage'i, DM'de yerel dosya).
class AppSettings {
  const AppSettings({this.lang = AppLang.en, this.themeMode = ThemeMode.dark});

  final AppLang lang;
  final ThemeMode themeMode;

  AppSettings copyWith({AppLang? lang, ThemeMode? themeMode}) => AppSettings(
    lang: lang ?? this.lang,
    themeMode: themeMode ?? this.themeMode,
  );
}

/// Ayarlari `shared_preferences` ile okur/yazar. Ilk build senkron varsayilan
/// doner (koyu tema, Turkce -- mevcut davranis), ardindan kayitlari asenkron
/// yukleyip durumu gunceller.
class AppSettingsController extends Notifier<AppSettings> {
  static const _kLang = 'settings.lang';
  static const _kTheme = 'settings.themeMode';

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
    );
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
