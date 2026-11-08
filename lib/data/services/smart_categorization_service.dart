import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/services/language_detection_service.dart';
import 'package:shoply/data/services/product_classifier_service.dart';
import 'package:shoply/data/services/product_knowledge_base.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Where a local category came from.
enum LocalCategorySource {
  /// The user moved this product into the category by hand.
  learned,

  /// The whole name is a category keyword.
  keywordExact,

  /// A keyword matched part of the name.
  keywordPartial,

  /// Exact entry in [ProductKnowledgeBase] (old category model).
  knowledgeBase,

  /// Close to a knowledge-base entry (typos such as "Tomatn").
  similarity,

  /// Nothing matched: 'other'.
  none,
}

class LocalCategoryResult {
  const LocalCategoryResult(this.categoryId, this.source);

  final String categoryId;
  final LocalCategorySource source;

  /// True for a mere guess that Claude may improve: a partial keyword, the
  /// knowledge base, a fuzzy match or nothing at all. Only a learned choice
  /// or an exact keyword is final.
  bool get isGuess =>
      source != LocalCategorySource.learned &&
      source != LocalCategorySource.keywordExact;
}

/// Categorises a product on the device, synchronously and offline:
/// 1. the user's own earlier choice (learned, per account),
/// 2. category keywords of `categories.dart` (exact, then partial),
/// 3. the product knowledge base (exact names),
/// 4. similarity to a knowledge-base name,
/// 5. 'other'.
///
/// The keywords come before the knowledge base because they are the same
/// rules the server's `categorize` prompt follows; the knowledge base still
/// files some products under its old 31 categories (spinach as frozen,
/// flour as staples), so its answers only count as guesses.
class SmartCategorizationService {
  SmartCategorizationService._({String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? _supabaseUserId;

  static final SmartCategorizationService _instance = SmartCategorizationService._();
  static SmartCategorizationService get instance => _instance;

  @visibleForTesting
  factory SmartCategorizationService.forTesting({
    required String? Function() currentUserId,
  }) =>
      SmartCategorizationService._(currentUserId: currentUserId);

  static const String _learnedKeyPrefix = 'category_learned_v2_';

  /// Written by the old `UserCategoryPreferences` (shown category names
  /// instead of ids); read once per account and converted.
  static const String _legacyLearnedKeyPrefix = 'user_category_prefs_v1_';
  static const int _maxLearned = 2000;
  static const double _minSimilarity = 0.8;

  /// [ProductKnowledgeBase] stores the names of the old 31-category model;
  /// these are the ids of today's 10 categories they belong to.
  static const Map<String, String> _knowledgeBaseIds = {
    'Obst und Gemüse': 'fruits_vegetables',
    'Fleisch und Wurst': 'meat_fish',
    'Backwaren': 'bakery',
    'Kühlprodukte': 'dairy',
    'Tiefkühlprodukte': 'frozen',
    'Grundnahrungsmittel': 'staples',
    'Gewürze': 'staples',
    'Würzmittel': 'staples',
    'Frühstücksprodukte': 'staples',
    'Süßigkeiten': 'snacks',
    'Snacks': 'snacks',
    'Getränke': 'beverages',
    'Reinigungsmittel': 'household',
    'Papierwaren': 'household',
    'Körperpflege': 'household',
    'Hygieneartikel': 'household',
    'Babyartikel': 'household',
    'Tierbedarf': 'household', // pet food and litter, as in the keywords
  };

  final String? Function() _currentUserId;
  final ProductKnowledgeBase _knowledgeBase = ProductKnowledgeBase.instance;
  final ProductClassifierService _keywords = ProductClassifierService.instance;

  /// Normalized product name → category id, for [_learnedFor] only.
  final LinkedHashMap<String, String> _learned = LinkedHashMap();
  String? _learnedFor;
  String? _loadingFor;
  Future<void>? _loading;

  /// The best local category for [productName]. Never waits: learned
  /// choices count once they are loaded (see [ensureLearnedLoaded]).
  LocalCategoryResult classify(String productName, {String? preferredLanguage}) {
    final key = normalizeProductName(productName);
    if (key.isEmpty) return const LocalCategoryResult('other', LocalCategorySource.none);

    final learned = learnedCategory(productName);
    if (learned != null) {
      return LocalCategoryResult(learned, LocalCategorySource.learned);
    }

    final keyword = _keywords.match(
      productName,
      preferredLanguage:
          preferredLanguage ?? LanguageDetectionService.detectLanguage(productName),
    );
    if (keyword != null) {
      return LocalCategoryResult(
        keyword.categoryId,
        keyword.kind == KeywordMatchKind.exact
            ? LocalCategorySource.keywordExact
            : LocalCategorySource.keywordPartial,
      );
    }

    final known = _knowledgeBaseIds[_knowledgeBase.getExactCategory(productName)];
    if (known != null) {
      return LocalCategoryResult(known, LocalCategorySource.knowledgeBase);
    }

    final similar = _mostSimilarKnownProduct(key);
    if (similar != null) {
      return LocalCategoryResult(similar, LocalCategorySource.similarity);
    }
    return const LocalCategoryResult('other', LocalCategorySource.none);
  }

  /// The category the signed-in user chose for [productName], or null.
  /// Starts loading the user's choices in the background when needed.
  String? learnedCategory(String productName) {
    final userId = _currentUserId();
    if (userId == null) return null;
    if (_learnedFor != userId) {
      unawaited(ensureLearnedLoaded());
      return null;
    }
    return _learned[normalizeProductName(productName)];
  }

  /// Loads the signed-in user's learned choices (once per account).
  Future<void> ensureLearnedLoaded() {
    final userId = _currentUserId();
    if (userId == null || _learnedFor == userId) return Future.value();
    if (_loadingFor == userId && _loading != null) return _loading!;
    _loadingFor = userId;
    return _loading = _loadLearned(userId);
  }

  Future<void> _loadLearned(String userId) async {
    final loaded = <String, String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = _decodeMap(prefs.getString('$_legacyLearnedKeyPrefix$userId'));
      legacy.forEach((name, shown) {
        final id = resolveCategoryId(shown);
        if (id != null) loaded[name] = id;
      });
      _decodeMap(prefs.getString('$_learnedKeyPrefix$userId')).forEach((name, id) {
        if (_isCategoryId(id)) loaded[name] = id;
      });
    } catch (e) {
      debugPrint('⚠️ [CATEGORY] Could not load learned categories: $e');
    }
    if (_loadingFor != userId) return; // another account signed in meanwhile
    _learned
      ..clear()
      ..addAll(loaded);
    _learnedFor = userId;
  }

  /// Remembers that the user moved [productName] into [category] (an id or
  /// the shown name of a built-in category). Unknown names are ignored.
  Future<void> recordUserCategoryChange(String productName, String category) async {
    final userId = _currentUserId();
    final key = normalizeProductName(productName);
    final id = resolveCategoryId(category);
    if (userId == null || key.isEmpty) return;
    if (id == null) {
      debugPrint('⚠️ [CATEGORY] Not learned: "$category" is no category');
      return;
    }

    await ensureLearnedLoaded();
    if (_learnedFor != userId) return;
    _learned
      ..remove(key)
      ..[key] = id;
    while (_learned.length > _maxLearned) {
      _learned.remove(_learned.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_learnedKeyPrefix$userId', jsonEncode(_learned));
    } catch (e) {
      debugPrint('⚠️ [CATEGORY] Could not save learned category: $e');
    }
  }

  /// The id for [value]: a category id as is, or the German or English name
  /// of a built-in category. Null for anything else (e.g. a custom section
  /// referred to by its name).
  @visibleForTesting
  static String? resolveCategoryId(String value) {
    final trimmed = value.trim();
    if (_isCategoryId(trimmed)) return trimmed;
    final lower = trimmed.toLowerCase();
    for (final category in Categories.all) {
      if (category.names.values.any((n) => n.toLowerCase() == lower)) {
        return category.id;
      }
    }
    return null;
  }

  static bool _isCategoryId(String value) =>
      Categories.allIds.contains(value) || CustomCategory.isCustomId(value);

  static Map<String, String> _decodeMap(String? raw) {
    if (raw == null) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  static String? _supabaseUserId() {
    try {
      return SupabaseService.instance.currentUser?.id;
    } catch (_) {
      return null; // Supabase not initialized (tests, very early start)
    }
  }

  /// Category id of the knowledge-base product closest to [normalized], if
  /// it is at least [_minSimilarity] alike.
  String? _mostSimilarKnownProduct(String normalized) {
    var bestSimilarity = 0.0;
    String? bestCategory;
    for (final entry in _knowledgeBase.entries) {
      final similarity = _similarity(normalized, entry.key);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestCategory = entry.value;
      }
    }
    if (bestSimilarity < _minSimilarity) return null;
    return _knowledgeBaseIds[bestCategory];
  }

  /// 0.0–1.0; containment of a word of 4+ letters counts high, otherwise a
  /// blend of Levenshtein and Jaro-Winkler (the latter is kinder to typos).
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;
    if (shorter.length >= 4 && longer.contains(shorter)) {
      return 0.8 + 0.2 * shorter.length / longer.length;
    }
    return _levenshteinSimilarity(a, b) * 0.4 + _jaroWinkler(a, b) * 0.6;
  }

  static double _levenshteinSimilarity(String a, String b) {
    final maxLength = a.length > b.length ? a.length : b.length;
    if (maxLength == 0) return 1.0;
    var previous = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      previous = current;
    }
    return 1.0 - previous[b.length] / maxLength;
  }

  static double _jaroWinkler(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final window = (a.length > b.length ? a.length : b.length) ~/ 2 - 1;
    final aMatched = List<bool>.filled(a.length, false);
    final bMatched = List<bool>.filled(b.length, false);

    var matches = 0;
    for (var i = 0; i < a.length; i++) {
      final start = i - window > 0 ? i - window : 0;
      final end = i + window + 1 < b.length ? i + window + 1 : b.length;
      for (var j = start; j < end; j++) {
        if (bMatched[j] || a[i] != b[j]) continue;
        aMatched[i] = true;
        bMatched[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0.0;

    var transpositions = 0;
    var k = 0;
    for (var i = 0; i < a.length; i++) {
      if (!aMatched[i]) continue;
      while (!bMatched[k]) {
        k++;
      }
      if (a[i] != b[k]) transpositions++;
      k++;
    }

    final jaro = (matches / a.length +
            matches / b.length +
            (matches - transpositions / 2) / matches) /
        3;
    var prefix = 0;
    final limit = a.length < b.length ? a.length : b.length;
    while (prefix < limit && prefix < 4 && a[prefix] == b[prefix]) {
      prefix++;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }
}
