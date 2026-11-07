import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's language selection.
///
/// Supports 'system' mode (auto-detect) plus manual English/German.
/// Persists manual language selection to SharedPreferences.
class LanguageNotifier extends StateNotifier<String> {
  static const supportedLanguages = ['en', 'de'];

  /// Starts on the device language — what the default 'system' setting
  /// resolves to — so most users see no language switch (and no app
  /// remount) once the saved setting has loaded.
  LanguageNotifier() : super(_resolveSystemLanguage()) {
    _loadLanguage();
  }

  String _savedSetting = 'system'; // 'system', 'en', or 'de'

  String get savedSetting => _savedSetting;

  static String _resolveSystemLanguage() {
    final systemLocale = PlatformDispatcher.instance.locale.languageCode;
    return supportedLanguages.contains(systemLocale) ? systemLocale : 'en';
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language');

    if (savedLanguage != null && supportedLanguages.contains(savedLanguage)) {
      _savedSetting = savedLanguage;
      state = savedLanguage;
    } else {
      _savedSetting = 'system';
      state = _resolveSystemLanguage();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();

    if (languageCode == 'system') {
      _savedSetting = 'system';
      await prefs.setString('language', 'system');
      state = _resolveSystemLanguage();
    } else if (supportedLanguages.contains(languageCode)) {
      _savedSetting = languageCode;
      await prefs.setString('language', languageCode);
      state = languageCode;
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});
