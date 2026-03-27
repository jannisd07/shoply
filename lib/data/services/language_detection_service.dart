import 'package:flutter/foundation.dart';

/// Service for detecting language of user-generated content
/// 
/// **AI: Usage Pattern**:
/// ```dart
/// final language = LanguageDetectionService.detectLanguage('Hähnchenbrust');
/// // Returns: 'de'
/// 
/// final language = LanguageDetectionService.detectLanguage('Chicken breast');
/// // Returns: 'en'
/// ```
/// 
/// **AI: Critical Constraints**:
/// - ⚠️ Simple heuristic-based detection (no ML)
/// - ⚠️ Defaults to 'de' (German) if ambiguous
/// - ⚠️ Only supports 'en' and 'de' currently
class LanguageDetectionService {
  /// Detect language from text using character and word patterns
  /// 
  /// Detection logic:
  /// 1. Check for German-specific characters (ä, ö, ü, ß)
  /// 2. Check for common German words
  /// 3. Default to German if ambiguous
  /// 
  /// Returns: 'de' or 'en'
  static String detectLanguage(String text) {
    if (text.isEmpty) return 'de';

    final lowerText = text.toLowerCase();

    // Strong indicator: German-specific characters
    if (lowerText.contains(RegExp(r'[äöüß]'))) {
      if (kDebugMode) {
        print('🔍 [LANG_DETECT] Detected German via umlauts: "$text"');
      }
      return 'de';
    }

    // Check for common German words
    final germanWords = [
      'und', 'mit', 'ohne', 'der', 'die', 'das', 'für',
      'oder', 'auf', 'von', 'zu', 'im', 'am', 'beim',
      'nach', 'vor', 'über', 'unter', 'zwischen',
      'frisch', 'bio', 'gehackt', 'geschnitten',
    ];

    final words = lowerText.split(RegExp(r'\s+'));
    for (final word in words) {
      if (germanWords.contains(word)) {
        if (kDebugMode) {
          print('🔍 [LANG_DETECT] Detected German via keyword "$word": "$text"');
        }
        return 'de';
      }
    }

    // Check for common English words (weaker indicator)
    final englishWords = [
      'and', 'with', 'without', 'the', 'for', 'or',
      'fresh', 'organic', 'chopped', 'sliced', 'minced',
    ];

    int englishScore = 0;
    for (final word in words) {
      if (englishWords.contains(word)) {
        englishScore++;
      }
    }

    if (englishScore >= 2) {
      if (kDebugMode) {
        print('🔍 [LANG_DETECT] Detected English via keywords: "$text"');
      }
      return 'en';
    }

    // Default to German (majority of users)
    if (kDebugMode) {
      print('🔍 [LANG_DETECT] No clear language markers, defaulting to German: "$text"');
    }
    return 'de';
  }

  /// Detect language from recipe by analyzing title, description, and ingredients
  /// 
  /// Uses weighted scoring:
  /// - Title: 40%
  /// - Description: 30%
  /// - Ingredients: 30%
  /// 
  /// Returns: 'de' or 'en'
  static String detectRecipeLanguage({
    required String title,
    String? description,
    List<String>? ingredientNames,
  }) {
    int deScore = 0;
    int enScore = 0;

    // Title (40% weight)
    final titleLang = detectLanguage(title);
    if (titleLang == 'de') {
      deScore += 40;
    } else {
      enScore += 40;
    }

    // Description (30% weight)
    if (description != null && description.isNotEmpty) {
      final descLang = detectLanguage(description);
      if (descLang == 'de') {
        deScore += 30;
      } else {
        enScore += 30;
      }
    }

    // Ingredients (30% weight)
    if (ingredientNames != null && ingredientNames.isNotEmpty) {
      int ingredientDe = 0;
      int ingredientEn = 0;
      
      for (final ingredient in ingredientNames) {
        final lang = detectLanguage(ingredient);
        if (lang == 'de') {
          ingredientDe++;
        } else {
          ingredientEn++;
        }
      }

      // Weight by proportion
      if (ingredientDe > ingredientEn) {
        deScore += 30;
      } else if (ingredientEn > ingredientDe) {
        enScore += 30;
      } else {
        // Tie - use title language
        if (titleLang == 'de') {
          deScore += 30;
        } else {
          enScore += 30;
        }
      }
    }

    final result = deScore >= enScore ? 'de' : 'en';
    
    if (kDebugMode) {
      print('🔍 [LANG_DETECT] Recipe language: $result (DE: $deScore, EN: $enScore)');
      print('  Title: "$title" → $titleLang');
      if (description != null) {
        print('  Description: "${description.substring(0, description.length > 50 ? 50 : description.length)}..." → ${detectLanguage(description)}');
      }
    }

    return result;
  }

  /// Check if text is definitely in a specific language
  /// 
  /// More strict than detectLanguage - only returns true if confident
  static bool isLanguage(String text, String languageCode) {
    final detected = detectLanguage(text);
    
    // Only return true if we have strong indicators
    if (languageCode == 'de') {
      return detected == 'de' && text.toLowerCase().contains(RegExp(r'[äöüß]|und|mit|der|die|das'));
    } else if (languageCode == 'en') {
      return detected == 'en' && text.toLowerCase().contains(RegExp(r'\band\b|\bwith\b|\bthe\b'));
    }
    
    return false;
  }
}
