import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider() {
    _locale = _resolveInitialLocale();
    _activeLanguageCode = _locale.languageCode;
    _restoreSettings();
  }

  static const String _localePrefKey = 'app_locale';
  static const String _themePrefKey = 'app_theme_mode';
  static String _activeLanguageCode = 'ar';
  static final RegExp _mojibakeHint = RegExp(r'[ØÙÃÂ]');
  static final RegExp _brokenArabicHint = RegExp(
    r'�|ا�"|�S|�f|�\^|�,|�\?|�\.|�"',
  );

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  String tr(String ar, String fr) => isArabic ? _repairArabic(ar) : fr;
  static String trGlobal(String ar, String fr) =>
      _activeLanguageCode == 'fr' ? fr : _repairArabic(ar);

  static String _repairArabic(String text) {
    var repaired = text;

    if (_mojibakeHint.hasMatch(repaired)) {
      try {
        repaired = utf8.decode(latin1.encode(repaired));
      } catch (_) {
        // Keep original value if decoding fails.
      }
    }

    if (_brokenArabicHint.hasMatch(repaired)) {
      repaired = repaired
          .replaceAll('ا�"', 'ال')
          .replaceAll('�S', 'ي')
          .replaceAll('�f', 'ك')
          .replaceAll('�^', 'و')
          .replaceAll('�,', 'ق')
          .replaceAll('�?', 'ن')
          .replaceAll('�.', 'م')
          .replaceAll('�"', 'ل')
          .replaceAll('�', '');
    }

    return repaired;
  }

  Locale _resolveInitialLocale() {
    final deviceCode = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .languageCode
        .toLowerCase();
    if (deviceCode == 'fr') {
      return const Locale('fr');
    }
    return const Locale('ar');
  }

  Future<void> _restoreSettings() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on MissingPluginException {
      // Can happen in headless/background engines.
      return;
    }

    final localeCode = prefs.getString(_localePrefKey);
    if (localeCode == 'ar' || localeCode == 'fr') {
      _locale = Locale(localeCode!);
      _activeLanguageCode = _locale.languageCode;
    }

    final themeName = prefs.getString(_themePrefKey);
    if (themeName == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeName == 'system') {
      _themeMode = ThemeMode.system;
    } else if (themeName == 'light') {
      _themeMode = ThemeMode.light;
    }

    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) {
          final value = switch (mode) {
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
            ThemeMode.light => 'light',
          };
          prefs.setString(_themePrefKey, value);
        })
        .catchError((_) {
          // Ignore persistence errors.
        });
  }

  void setLocale(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    if (code != 'ar' && code != 'fr') {
      return;
    }
    if (_locale.languageCode == code) {
      return;
    }
    _locale = Locale(code);
    _activeLanguageCode = code;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setString(_localePrefKey, code);
        })
        .catchError((_) {
          // Ignore persistence errors.
        });
  }
}
