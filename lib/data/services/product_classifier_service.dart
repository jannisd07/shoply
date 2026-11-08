import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';

/// How a keyword matched a product name.
enum KeywordMatchKind {
  /// The whole name is a keyword ("Milch").
  exact,

  /// A keyword is one or more whole words of the name ("Bio Vollmilch").
  word,

  /// A keyword sits inside a compound ("Erdbeerjoghurt").
  substring,
}

class KeywordMatch {
  const KeywordMatch(this.categoryId, this.kind);

  final String categoryId;
  final KeywordMatchKind kind;
}

/// Offline keyword classifier over the bilingual keyword lists of
/// [Categories]. It returns the language-agnostic category ids stored in
/// `shopping_items.category_id` and works without any network.
class ProductClassifierService {
  static final ProductClassifierService _instance = ProductClassifierService._();
  static ProductClassifierService get instance => _instance;

  ProductClassifierService._();

  /// Shorter keywords match too much inside compounds ("reis" in "Preis").
  static const int _minSubstringLength = 5;

  /// Per language: normalized keyword → category id. A keyword listed in
  /// two categories belongs to the first in [Categories.all] (walking order).
  late final Map<String, Map<String, String>> _keywords = {
    for (final language in const ['de', 'en'])
      language: {
        for (final category in Categories.all.reversed)
          for (final keyword in category.getKeywords(language))
            if (_normalize(keyword).isNotEmpty) _normalize(keyword): category.id,
      },
  };

  /// Matches [productName] against the keywords, [preferredLanguage] first
  /// (short names are often detected in the wrong language), then the other.
  /// Exact beats word beats substring; among words the longest keyword wins,
  /// in compounds the ending wins (German puts the head last), then length.
  KeywordMatch? match(String productName, {String preferredLanguage = 'de'}) {
    final name = _normalize(productName);
    if (name.isEmpty) return null;
    final languages =
        preferredLanguage == 'en' ? const ['en', 'de'] : const ['de', 'en'];

    for (final language in languages) {
      final id = _keywords[language]![name];
      if (id != null) return KeywordMatch(id, KeywordMatchKind.exact);
    }

    final padded = ' $name ';
    for (final language in languages) {
      String? best;
      for (final keyword in _keywords[language]!.keys) {
        if (padded.contains(' $keyword ') &&
            (best == null || keyword.length > best.length)) {
          best = keyword;
        }
      }
      if (best != null) {
        return KeywordMatch(_keywords[language]![best]!, KeywordMatchKind.word);
      }
    }

    for (final language in languages) {
      String? best;
      var bestScore = 0;
      for (final keyword in _keywords[language]!.keys) {
        if (keyword.length < _minSubstringLength || !name.contains(keyword)) {
          continue;
        }
        final score = keyword.length + (name.endsWith(keyword) ? 100 : 0);
        if (score > bestScore) {
          best = keyword;
          bestScore = score;
        }
      }
      if (best != null) {
        return KeywordMatch(
          _keywords[language]![best]!,
          KeywordMatchKind.substring,
        );
      }
    }
    return null;
  }

  /// [normalizeProductName] plus common misspellings and the English
  /// spellings of "Joghurt".
  static String _normalize(String name) => normalizeProductName(name)
      .replaceAll('gauda', 'gouda')
      .replaceAll('jogurt', 'joghurt')
      .replaceAll('yoghurt', 'joghurt')
      .replaceAll('yogurt', 'joghurt');
}
