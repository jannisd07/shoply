import 'dart:ui' show PlatformDispatcher;

/// Heuristic language detection ('de' or 'en') for user-typed item names.
///
/// ```dart
/// LanguageDetectionService.detectLanguage('Hähnchenbrust'); // 'de'
/// LanguageDetectionService.detectLanguage('Chicken and rice'); // 'en'
/// ```
///
/// Simple heuristics (no ML). Ambiguous text such as a single word ("Milk",
/// "Tomaten") falls back to [fallback], or to the device language when none
/// is given.
class LanguageDetectionService {
  static const _germanWords = {
    'und', 'mit', 'ohne', 'der', 'die', 'das', 'für',
    'oder', 'auf', 'von', 'zu', 'im', 'am', 'beim',
    'nach', 'vor', 'über', 'unter', 'zwischen',
    'frisch', 'bio', 'gehackt', 'geschnitten',
  };

  static const _englishWords = {
    'and', 'with', 'without', 'the', 'for', 'or',
    'fresh', 'organic', 'chopped', 'sliced', 'minced',
  };

  /// Detect language from text using character and word patterns:
  /// 1. German-specific characters (ä, ö, ü, ß) → 'de'
  /// 2. Common German words → 'de'
  /// 3. Common English words → 'en'
  /// 4. Otherwise [fallback] (default: device language, 'de' or 'en')
  static String detectLanguage(String text, {String? fallback}) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains(RegExp(r'[äöüß]'))) return 'de';

    final words = lowerText.split(RegExp(r'\s+'));
    if (words.any(_germanWords.contains)) return 'de';
    if (words.any(_englishWords.contains)) return 'en';

    return fallback ?? _deviceLanguage();
  }

  static String _deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return code == 'de' ? 'de' : 'en';
  }
}
