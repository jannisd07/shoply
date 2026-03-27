/// Manages the app's language selection.
/// 
/// Uses system language if supported (English or German).
/// Falls back to English for unsupported languages.
/// Persists manual language selection to SharedPreferences.

import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageNotifier extends StateNotifier<String> {
  static const supportedLanguages = ['en', 'de'];
  
  LanguageNotifier() : super('en') {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language');
    
    if (savedLanguage != null && supportedLanguages.contains(savedLanguage)) {
      // Use saved preference if valid
      state = savedLanguage;
    } else {
      // Use system language if supported, otherwise default to English
      final systemLocale = PlatformDispatcher.instance.locale.languageCode;
      state = supportedLanguages.contains(systemLocale) ? systemLocale : 'en';
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.contains(languageCode)) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    state = languageCode;
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});
