import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/data/services/language_detection_service.dart';

/// Gemini-powered item categorization, ingredient parsing and list
/// recommendations. Uses gemini-2.0-flash-lite (the cheapest model) with a
/// SharedPreferences cache and a serialized 1100 ms gap between API calls.
class GeminiCategorizationService {
  static final GeminiCategorizationService _instance = GeminiCategorizationService._internal();
  static GeminiCategorizationService get instance => _instance;
  factory GeminiCategorizationService() => _instance;
  GeminiCategorizationService._internal();

  static const _modelName = 'gemini-2.0-flash-lite';

  /// Minimum gap between Gemini requests (project rule: never below 1100 ms).
  static const _rateLimitMs = 1100;

  GenerativeModel? _model;
  final Map<String, String> _categoryCache = {};
  DateTime? _lastApiCall;

  /// Tail of the rate-limit queue; each caller waits for the previous one.
  Future<void> _rateLimitGate = Future.value();

  /// Initialize Gemini model
  Future<void> initialize(String apiKey) async {
    try {
      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
      );

      await _loadCache();

      debugPrint('✅ [GEMINI] Categorization service initialized ($_modelName)');
    } catch (e) {
      debugPrint('❌ [GEMINI] Error initializing Gemini: $e');
    }
  }

  /// Load cached categorizations from local storage
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString('category_cache');
      if (cacheJson != null) {
        final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
        _categoryCache.addAll(cache.cast<String, String>());
        debugPrint('✅ [GEMINI] Loaded ${_categoryCache.length} cached entries');
      }
    } catch (e) {
      debugPrint('⚠️ [GEMINI] Error loading category cache: $e');
    }
  }

  /// Save category cache to local storage
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('category_cache', jsonEncode(_categoryCache));
    } catch (e) {
      debugPrint('⚠️ [GEMINI] Error saving category cache: $e');
    }
  }

  /// Waits until at least [_rateLimitMs] have passed since the previous API
  /// call. Calls are queued, so concurrent callers are spaced out one after
  /// another instead of all waking up at the same time.
  Future<void> _rateLimit() {
    final previous = _rateLimitGate;
    final done = Completer<void>();
    _rateLimitGate = done.future;
    return () async {
      try {
        await previous;
        final last = _lastApiCall;
        if (last != null) {
          final waitMs = _rateLimitMs - DateTime.now().difference(last).inMilliseconds;
          if (waitMs > 0) {
            await Future.delayed(Duration(milliseconds: waitMs));
          }
        }
        _lastApiCall = DateTime.now();
      } finally {
        done.complete();
      }
    }();
  }

  /// Categorize a shopping item using Gemini AI (bilingual: English & German)
  /// Returns category ID (language-agnostic)
  /// Falls back to keyword matching if API fails
  Future<String> categorizeItem(String itemName, [String? languageCode]) async {
    final normalizedName = itemName.trim().toLowerCase();
    final language = languageCode ?? LanguageDetectionService.detectLanguage(itemName);

    // Check cache first (language-specific cache key)
    final cacheKey = '${language}_$normalizedName';
    final cached = _categoryCache[cacheKey];
    if (cached != null) {
      debugPrint('✅ [GEMINI] Cache hit: "$itemName" → $cached');
      return cached;
    }

    try {
      await _rateLimit();
      final categoryId = await _categorizeWithGemini(itemName, language);

      // Cache the result (use category ID, not translated name)
      _categoryCache[cacheKey] = categoryId;
      await _saveCache();
      debugPrint('✅ [GEMINI] "$itemName" → $categoryId');
      return categoryId;
    } catch (e) {
      final fallbackCategoryId = _fallbackCategorization(itemName, language);
      debugPrint('⚠️ [GEMINI] API failed ($e), keyword fallback: "$itemName" → $fallbackCategoryId');
      return fallbackCategoryId;
    }
  }

  /// Categorize using Gemini AI (bilingual support)
  /// Returns category ID (not translated name)
  Future<String> _categorizeWithGemini(String itemName, String language) async {
    if (_model == null) {
      throw Exception('Gemini model not initialized');
    }

    // Get category names in the detected language
    final categoryNames = Categories.getNamesInLanguage(language);

    // Use language-specific prompt
    final prompt = language == 'de'
        ? _getGermanPrompt(itemName, categoryNames)
        : _getEnglishPrompt(itemName, categoryNames);

    final response = await _model!.generateContent([Content.text(prompt)]);
    final categoryName = response.text?.trim() ?? '';
    if (categoryName.isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    // Convert category name back to ID
    final categoryId = Categories.getIdByName(categoryName, language);
    if (categoryId == null) {
      debugPrint('⚠️ [GEMINI] Unknown category "$categoryName", using keyword fallback');
      return _fallbackCategorization(itemName, language);
    }
    return categoryId;
  }

  /// German prompt for Gemini
  String _getGermanPrompt(String itemName, List<String> categories) {
    return '''
Kategorisiere diesen Einkaufsartikel in EINE dieser Kategorien:
${categories.join(', ')}

Artikel: "$itemName"

Regeln:
- Gib NUR den Kategorienamen zurück, sonst nichts
- Orientiere dich an deutschen Supermarkt-Konventionen
- Bei Unklarheit: "Sonstiges"

Kategorie:''';
  }

  /// English prompt for Gemini
  String _getEnglishPrompt(String itemName, List<String> categories) {
    return '''
Categorize this grocery item into ONE of these categories:
${categories.join(', ')}

Item: "$itemName"

Rules:
- Return ONLY the category name, nothing else
- Follow typical supermarket organization
- If unclear, use "Other"

Category:''';
  }

  /// Fallback categorization using keyword matching (bilingual).
  /// Tries the detected language's keywords first, then the other language's,
  /// since short item names are often detected in the wrong language.
  /// Returns category ID (not translated name)
  String _fallbackCategorization(String itemName, String language) {
    final name = itemName.toLowerCase().trim();
    final languages = [language, language == 'de' ? 'en' : 'de'];

    for (final lang in languages) {
      final id = _matchKeywords(name, lang);
      if (id != null) return id;
    }
    return 'other';
  }

  String? _matchKeywords(String name, String language) {
    // FIRST PASS: exact match (highest priority)
    for (final category in Categories.all) {
      for (final keyword in category.getKeywords(language)) {
        if (name == keyword.toLowerCase()) return category.id;
      }
    }

    // SECOND PASS: word boundary match (e.g., "butter" matches "peanut butter")
    for (final category in Categories.all) {
      for (final keyword in category.getKeywords(language)) {
        final pattern = RegExp(r'\b' + RegExp.escape(keyword.toLowerCase()) + r'\b');
        if (pattern.hasMatch(name)) return category.id;
      }
    }

    // THIRD PASS: partial/substring match (lowest priority, only for compounds)
    for (final category in Categories.all) {
      for (final keyword in category.getKeywords(language)) {
        if (keyword.length > 4 && name.contains(keyword.toLowerCase())) {
          return category.id;
        }
      }
    }
    return null;
  }

  /// Get smart recommendations based on current shopping list
  /// Suggests commonly bought items that complement the current list
  /// Uses Gemini to understand meal planning and complementary items
  Future<List<String>> getSmartRecommendations(
    List<String> currentItems, {
    List<String>? frequentItems,
  }) async {
    if (_model == null || currentItems.isEmpty) {
      return [];
    }

    try {
      await _rateLimit();

      // Include all current items (not just first 10) for better context
      final allItems = currentItems.join(', ');

      // Build frequency context if available
      final frequencyContext = frequentItems != null && frequentItems.isNotEmpty
          ? '\n\nHäufig gekaufte Artikel dieses Nutzers: ${frequentItems.take(15).join(', ')}'
          : '';

      final prompt = '''
Analysiere diese Einkaufsliste und schlage 3-5 häufig vergessene Artikel vor, die diese Produkte ergänzen.

Aktuelle Liste: $allItems$frequencyContext

Regeln:
- Berücksichtige typische Mahlzeitenplanung und deutsche/europäische Einkaufsmuster
- Schlage komplementäre Artikel vor (z.B. Pasta → Tomatensauce, Parmesan; Brot → Butter, Aufschnitt)
- Fokussiere auf praktische Basics, die die meisten Leute nützlich finden würden
- Schlage KEINE Artikel vor, die bereits auf der Liste stehen
- Antworte NUR mit Artikelnamen auf Deutsch, ein Artikel pro Zeile
- Keine Erklärungen, keine Nummern, keine Aufzählungszeichen

Vorschläge:''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      if (response.text == null || response.text!.trim().isEmpty) {
        return [];
      }

      // Clean up response: remove bullets, numbers, dashes, and empty lines
      final suggestions = response.text!
          .split('\n')
          .map((s) => s.trim())
          .map((s) => s.replaceFirst(RegExp(r'^[-•*\d.)\s]+'), '').trim())
          .where((s) => s.isNotEmpty && s.length < 50)
          .where((s) => !currentItems.any(
              (item) => item.toLowerCase() == s.toLowerCase()))
          .take(5)
          .toList();

      debugPrint('✅ [GEMINI] Generated ${suggestions.length} smart recommendations');

      return suggestions;
    } catch (e) {
      debugPrint('❌ [GEMINI] Error getting recommendations: $e');
      return [];
    }
  }

  /// Clear category cache
  Future<void> clearCache() async {
    _categoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('category_cache');
    debugPrint('🗑️ [GEMINI] Category cache cleared');
  }

  /// Parse an ingredient string and extract structured data (name, amount, unit)
  /// Example: "2 cups flour" -> {name: "flour", amount: 2.0, unit: "cups"}
  /// Example: "Tomaten" -> {name: "Tomaten", amount: 1.0, unit: "stück"}
  Future<Map<String, dynamic>> parseIngredient(String input) async {
    final inputLower = input.trim().toLowerCase();

    // Check cache first. Entries hold the sanitized result; the v2 prefix
    // drops older entries that cached the raw (unsanitized) model output.
    final cacheKey = 'ingredient_v2_$inputLower';
    final cached = _categoryCache[cacheKey];
    if (cached != null) {
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (_model == null) {
      return _fallbackParseIngredient(input);
    }

    try {
      await _rateLimit();

      final prompt = '''Parse this shopping list item and extract the ingredient name, amount (as a number), and unit.
Return ONLY a JSON object with these exact keys: name, amount, unit
If no amount is specified, use 1. If no unit is specified, use "pcs" (pieces).

Examples:
- "2 cups flour" -> {"name": "flour", "amount": 2, "unit": "cups"}
- "500g chicken" -> {"name": "chicken", "amount": 500, "unit": "g"}
- "Tomatoes" -> {"name": "Tomatoes", "amount": 1, "unit": "pcs"}
- "3 Eier" -> {"name": "Eier", "amount": 3, "unit": "pcs"}
- "1kg Kartoffeln" -> {"name": "Kartoffeln", "amount": 1, "unit": "kg"}

Item to parse: "$input"

Return ONLY the JSON object, no other text:''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(responseText);
      if (jsonMatch != null) {
        final result = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final parsed = <String, dynamic>{
          'name': sanitizeParsedName(input, result['name'] as String?),
          'amount': (result['amount'] as num?)?.toDouble() ?? 1.0,
          'unit': result['unit'] ?? 'pcs',
        };

        _categoryCache[cacheKey] = jsonEncode(parsed);
        await _saveCache();
        return parsed;
      }
    } catch (e) {
      debugPrint('❌ [GEMINI] Error parsing ingredient: $e');
    }

    return _fallbackParseIngredient(input);
  }

  /// Guard against the model *inventing* words while parsing.
  ///
  /// Parsing an item is an extraction task: strip the quantity and unit,
  /// keep the product. The model is not asked to expand or rephrase, but it
  /// sometimes does — a real list here ended up with "Tiefkühlerbsen erbsen"
  /// stored in the database, and that name then travels into price lookups
  /// and purchase statistics.
  ///
  /// The invariant is therefore that the result must be a *shortening* of
  /// what the user typed: with punctuation, spaces and case removed, it has
  /// to appear inside the input. Word-level checks are not enough — "erbsen"
  /// is a substring of "Tiefkühlerbsen", so the duplicate slipped through a
  /// per-word test. Comparing the whole squashed string catches it.
  ///
  /// Anything else falls back to the typed name: an unparsed but honest name
  /// is always better than a confident wrong one.
  @visibleForTesting
  static String sanitizeParsedName(String input, String? parsed) {
    final candidate = parsed?.trim() ?? '';
    if (candidate.isEmpty) return input;

    String squash(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');

    final squashedInput = squash(input);
    final squashedCandidate = squash(candidate);
    if (squashedCandidate.isEmpty) return input;

    return squashedInput.contains(squashedCandidate) ? candidate : input;
  }

  /// Fallback ingredient parsing using regex patterns
  Map<String, dynamic> _fallbackParseIngredient(String input) {
    final patterns = [
      // "2 cups flour", "3 tbsp sugar"
      RegExp(r'^(\d+(?:\.\d+)?)\s*(cups?|tbsp|tsp|oz|lb|g|kg|ml|l|pcs?|stück|stk|packung|dose|glas)\s+(.+)$', caseSensitive: false),
      // "500g chicken", "1kg potatoes"
      RegExp(r'^(\d+(?:\.\d+)?)(g|kg|ml|l)\s*(.+)$', caseSensitive: false),
      // "2 eggs", "3 tomatoes"
      RegExp(r'^(\d+(?:\.\d+)?)\s+(.+)$', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input.trim());
      if (match != null) {
        if (match.groupCount == 3) {
          return {
            'name': match.group(3)?.trim() ?? input,
            'amount': double.tryParse(match.group(1) ?? '1') ?? 1.0,
            'unit': match.group(2)?.toLowerCase() ?? 'pcs',
          };
        } else if (match.groupCount == 2) {
          return {
            'name': match.group(2)?.trim() ?? input,
            'amount': double.tryParse(match.group(1) ?? '1') ?? 1.0,
            'unit': 'pcs',
          };
        }
      }
    }
    
    // No pattern matched, return as-is
    return {
      'name': input.trim(),
      'amount': 1.0,
      'unit': 'pcs',
    };
  }
}
