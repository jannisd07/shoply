import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/data/services/language_detection_service.dart';

/// Gemini-powered smart categorization and recommendations service
/// Uses gemini-1.5-flash for cost-effective categorization
/// Cost: ~$0.075 per 1M input tokens, ~$0.30 per 1M output tokens
class GeminiCategorizationService {
  static final GeminiCategorizationService _instance = GeminiCategorizationService._internal();
  static GeminiCategorizationService get instance => _instance;
  factory GeminiCategorizationService() => _instance;
  GeminiCategorizationService._internal();

  GenerativeModel? _model;
  final Map<String, String> _categoryCache = {};
  DateTime? _lastApiCall;
  static const _rateLimitMs = 1000; // 1 second between API calls

  /// Initialize Gemini model
  Future<void> initialize(String apiKey) async {
    try {
      // Use gemini-2.0-flash-lite - the CHEAPEST Gemini model available
      // This is the most cost-effective model for simple categorization tasks
      _model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
      );
      
      // Load cached categorizations
      await _loadCache();
      
      print('✅ [GEMINI] Categorization service initialized with model: gemini-2.0-flash-lite');
    } catch (e) {
      print('❌ [GEMINI] Error initializing Gemini: $e');
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
        if (kDebugMode) {
          print('✅ Loaded ${_categoryCache.length} cached categorizations');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading category cache: $e');
      }
    }
  }

  /// Save category cache to local storage
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('category_cache', jsonEncode(_categoryCache));
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error saving category cache: $e');
      }
    }
  }

  /// Rate limit API calls
  Future<void> _rateLimit() async {
    if (_lastApiCall != null) {
      final elapsed = DateTime.now().difference(_lastApiCall!).inMilliseconds;
      if (elapsed < _rateLimitMs) {
        final waitTime = _rateLimitMs - elapsed;
        if (kDebugMode) {
          print('⏱️ [GEMINI] Rate limiting: waiting ${waitTime}ms');
        }
        await Future.delayed(Duration(milliseconds: waitTime));
      }
    }
    _lastApiCall = DateTime.now();
  }

  /// Categorize a shopping item using Gemini AI (bilingual: English & German)
  /// Returns category ID (language-agnostic)
  /// Falls back to keyword matching if API fails
  Future<String> categorizeItem(String itemName, [String? languageCode]) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🤖 [GEMINI] categorizeItem() CALLED');
    print('🤖 [GEMINI] - itemName: "$itemName"');
    print('🤖 [GEMINI] - languageCode: $languageCode');
    print('🤖 [GEMINI] - _model initialized: ${_model != null}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // Normalize item name
    final normalizedName = itemName.trim().toLowerCase();
    print('🤖 [GEMINI] - normalizedName: "$normalizedName"');
    
    // Detect language if not provided (using shared service)
    final language = languageCode ?? LanguageDetectionService.detectLanguage(itemName);
    print('🤖 [GEMINI] - detected language: $language');
    
    // Check cache first (language-specific cache key)
    final cacheKey = '${language}_$normalizedName';
    print('🤖 [GEMINI] - cacheKey: "$cacheKey"');
    print('🤖 [GEMINI] - cache size: ${_categoryCache.length} entries');
    
    if (_categoryCache.containsKey(cacheKey)) {
      final cachedResult = _categoryCache[cacheKey]!;
      print('✅ [GEMINI] CACHE HIT! "$itemName" → "$cachedResult"');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return cachedResult;
    }

    print('❌ [GEMINI] CACHE MISS - will call API');

    // Try Gemini API
    try {
      print('⏱️ [GEMINI] Starting rate limit check...');
      await _rateLimit();
      print('✅ [GEMINI] Rate limit passed, calling API...');
      
      final categoryId = await _categorizeWithGemini(itemName, language);
      print('✅ [GEMINI] API returned category ID: "$categoryId"');
      
      // Cache the result (use category ID, not translated name)
      _categoryCache[cacheKey] = categoryId;
      await _saveCache();
      print('✅ [GEMINI] Cached result for future use');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return categoryId;
    } catch (e, stackTrace) {
      print('❌❌❌ [GEMINI] API FAILED! ❌❌❌');
      print('❌ [GEMINI] Error: $e');
      print('❌ [GEMINI] StackTrace: $stackTrace');
      print('📝 [GEMINI] Falling back to keyword matching...');
      
      // Fallback to keyword matching
      final fallbackCategoryId = _fallbackCategorization(itemName, language);
      print('✅ [GEMINI] Fallback result: "$itemName" → "$fallbackCategoryId"');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return fallbackCategoryId;
    }
  }

  /// Categorize using Gemini AI (bilingual support)
  /// Returns category ID (not translated name)
  Future<String> _categorizeWithGemini(String itemName, String language) async {
    print('🔵 [GEMINI] _categorizeWithGemini() START');
    print('🔵 [GEMINI] - itemName: "$itemName"');
    print('🔵 [GEMINI] - language: $language');
    
    if (_model == null) {
      print('❌ [GEMINI] ERROR: Model is NULL! Gemini not initialized!');
      throw Exception('Gemini model not initialized');
    }
    print('✅ [GEMINI] Model is initialized');

    // Get category names in the detected language
    final categoryNames = Categories.getNamesInLanguage(language);
    print('🔵 [GEMINI] Available categories (${categoryNames.length}): ${categoryNames.join(", ")}');
    
    // Use language-specific prompt
    final prompt = language == 'de'
        ? _getGermanPrompt(itemName, categoryNames)
        : _getEnglishPrompt(itemName, categoryNames);

    print('🔵 [GEMINI] Prompt prepared (${language == 'de' ? 'German' : 'English'})');
    print('🔵 [GEMINI] Sending request to Gemini API...');

    final content = [Content.text(prompt)];
    final response = await _model!.generateContent(content);
    
    print('✅ [GEMINI] Received response from API');
    
    if (response.text == null || response.text!.trim().isEmpty) {
      print('❌ [GEMINI] ERROR: Empty response from Gemini!');
      throw Exception('Empty response from Gemini');
    }

    final categoryName = response.text!.trim();
    print('🔵 [GEMINI] Raw response: "$categoryName"');
    
    // Convert category name back to ID
    final categoryId = Categories.getIdByName(categoryName, language);
    print('🔵 [GEMINI] Converting "$categoryName" to ID...');
    
    if (categoryId == null) {
      print('❌ [GEMINI] ERROR: Invalid category name from Gemini!');
      print('❌ [GEMINI] Received: "$categoryName"');
      print('❌ [GEMINI] Expected one of: ${categoryNames.join(", ")}');
      print('❌ [GEMINI] Falling back to keyword matching...');
      return _fallbackCategorization(itemName, language);
    }

    print('✅ [GEMINI] SUCCESS: "$itemName" → "$categoryName" → ID:"$categoryId"');
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

  /// Fallback categorization using keyword matching (bilingual)
  /// Returns category ID (not translated name)
  String _fallbackCategorization(String itemName, String language) {
    final name = itemName.toLowerCase().trim();

    // FIRST PASS: Try exact match (highest priority)
    for (final category in Categories.all) {
      final keywords = category.getKeywords(language);
      for (final keyword in keywords) {
        if (name == keyword.toLowerCase()) {
          if (kDebugMode) {
            print('🔍 [FALLBACK] EXACT match "$keyword" in category ${category.id}');
          }
          return category.id;
        }
      }
    }

    // SECOND PASS: Try word boundary match (e.g., "butter" matches "peanut butter")
    for (final category in Categories.all) {
      final keywords = category.getKeywords(language);
      for (final keyword in keywords) {
        final keywordLower = keyword.toLowerCase();
        // Match if the name IS the keyword or contains it as a complete word
        final pattern = RegExp(r'\b' + RegExp.escape(keywordLower) + r'\b');
        if (pattern.hasMatch(name)) {
          if (kDebugMode) {
            print('🔍 [FALLBACK] WORD match "$keyword" in category ${category.id}');
          }
          return category.id;
        }
      }
    }

    // THIRD PASS: Try partial/substring match (lowest priority, only for compounds)
    for (final category in Categories.all) {
      final keywords = category.getKeywords(language);
      for (final keyword in keywords) {
        if (keyword.length > 4 && name.contains(keyword.toLowerCase())) {
          if (kDebugMode) {
            print('🔍 [FALLBACK] PARTIAL match "$keyword" in category ${category.id}');
          }
          return category.id;
        }
      }
    }

    // Default to 'other' if no match
    if (kDebugMode) {
      print('🔍 [FALLBACK] No keyword match, using "other"');
    }
    return 'other';
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

      if (kDebugMode) {
        print('✅ [GEMINI] Generated ${suggestions.length} smart recommendations: $suggestions');
      }

      return suggestions;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting recommendations: $e');
      }
      return [];
    }
  }

  /// Batch categorize multiple items (more efficient)
  Future<Map<String, String>> batchCategorize(List<String> items) async {
    final Map<String, String> results = {};
    
    for (final item in items) {
      results[item] = await categorizeItem(item);
    }
    
    return results;
  }

  /// Clear category cache
  Future<void> clearCache() async {
    _categoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('category_cache');
    if (kDebugMode) {
      print('🗑️ Category cache cleared');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_items': _categoryCache.length,
      'model': 'gemini-2.0-flash-lite',
      'rate_limit_ms': _rateLimitMs,
    };
  }

  /// Parse an ingredient string and extract structured data (name, amount, unit)
  /// Example: "2 cups flour" -> {name: "flour", amount: 2.0, unit: "cups"}
  /// Example: "Tomaten" -> {name: "Tomaten", amount: 1.0, unit: "stück"}
  Future<Map<String, dynamic>> parseIngredient(String input) async {
    final inputLower = input.trim().toLowerCase();
    
    // Check cache first
    final cacheKey = 'ingredient_$inputLower';
    if (_categoryCache.containsKey(cacheKey)) {
      try {
        return jsonDecode(_categoryCache[cacheKey]!) as Map<String, dynamic>;
      } catch (_) {}
    }
    
    // Try Gemini API
    try {
      await _rateLimit();
      
      if (_model == null) {
        return _fallbackParseIngredient(input);
      }
      
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
        
        // Cache the result
        _categoryCache[cacheKey] = jsonEncode(result);
        await _saveCache();
        
        return {
          'name': sanitizeParsedName(input, result['name'] as String?),
          'amount': (result['amount'] as num?)?.toDouble() ?? 1.0,
          'unit': result['unit'] ?? 'pcs',
        };
      }
    } catch (e) {
      print('❌ [GEMINI] Error parsing ingredient: $e');
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

  /// Generate tags for a recipe based on its content
  /// Returns a list of relevant tags for categorization and search
  Future<List<String>> generateRecipeTags({
    required String name,
    required String description,
    required List<String> ingredients,
    required int prepTimeMinutes,
    required int cookTimeMinutes,
  }) async {
    final cacheKey = 'tags_${name.toLowerCase().replaceAll(' ', '_')}';
    
    // Check cache
    if (_categoryCache.containsKey(cacheKey)) {
      try {
        return List<String>.from(jsonDecode(_categoryCache[cacheKey]!) as List);
      } catch (_) {}
    }
    
    // Try Gemini API
    try {
      await _rateLimit();
      
      if (_model == null) {
        return _fallbackGenerateTags(name, description, ingredients, prepTimeMinutes, cookTimeMinutes);
      }
      
      final totalTime = prepTimeMinutes + cookTimeMinutes;
      final ingredientsList = ingredients.take(10).join(', ');
      
      final prompt = '''Generate relevant tags for this recipe. Tags should help with search and categorization.

Recipe: $name
Description: $description
Key ingredients: $ingredientsList
Total time: $totalTime minutes

Generate 5-8 tags from these categories:
- Cuisine type (italian, asian, mexican, mediterranean, etc.)
- Diet type (vegetarian, vegan, gluten-free, dairy-free, etc.)
- Meal type (breakfast, lunch, dinner, snack, dessert)
- Cooking style (quick, easy, comfort-food, healthy, light)
- Time-based (under-30-min, quick, weeknight, meal-prep)
- Main ingredient category (pasta, chicken, beef, seafood, vegetables)

Return ONLY a JSON array of lowercase tags, no other text:''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';
      
      // Extract JSON array from response
      final jsonMatch = RegExp(r'\[([^\]]+)\]').firstMatch(responseText);
      if (jsonMatch != null) {
        final tags = List<String>.from(
          (jsonDecode(jsonMatch.group(0)!) as List).map((t) => t.toString().toLowerCase())
        );
        
        // Add time-based tags
        if (totalTime <= 15) tags.add('super-quick');
        if (totalTime <= 30) tags.add('quick');
        if (totalTime <= 45) tags.add('under-45-min');
        
        // Deduplicate
        final uniqueTags = tags.toSet().toList();
        
        // Cache the result
        _categoryCache[cacheKey] = jsonEncode(uniqueTags);
        await _saveCache();
        
        return uniqueTags;
      }
    } catch (e) {
      print('❌ [GEMINI] Error generating tags: $e');
    }
    
    return _fallbackGenerateTags(name, description, ingredients, prepTimeMinutes, cookTimeMinutes);
  }
  
  /// Fallback tag generation using keyword matching
  List<String> _fallbackGenerateTags(
    String name,
    String description,
    List<String> ingredients,
    int prepTime,
    int cookTime,
  ) {
    final tags = <String>{};
    final text = '$name $description ${ingredients.join(' ')}'.toLowerCase();
    
    // Cuisine detection
    final cuisineKeywords = {
      'italian': ['pasta', 'pizza', 'risotto', 'italian', 'parmesan', 'mozzarella'],
      'asian': ['soy', 'rice', 'noodle', 'ginger', 'sesame', 'asian', 'chinese', 'japanese', 'thai'],
      'mexican': ['taco', 'burrito', 'salsa', 'mexican', 'tortilla', 'avocado'],
      'mediterranean': ['olive', 'feta', 'greek', 'hummus', 'mediterranean'],
      'indian': ['curry', 'masala', 'indian', 'tikka', 'naan'],
    };
    
    for (final entry in cuisineKeywords.entries) {
      if (entry.value.any((k) => text.contains(k))) {
        tags.add(entry.key);
      }
    }
    
    // Diet detection
    final meatKeywords = ['chicken', 'beef', 'pork', 'lamb', 'fish', 'meat', 'bacon', 'sausage'];
    final dairyKeywords = ['milk', 'cheese', 'cream', 'butter', 'yogurt'];
    
    final hasMeat = meatKeywords.any((k) => text.contains(k));
    final hasDairy = dairyKeywords.any((k) => text.contains(k));
    
    if (!hasMeat && !hasDairy) tags.add('vegan');
    if (!hasMeat) tags.add('vegetarian');
    
    // Time-based tags
    final totalTime = prepTime + cookTime;
    if (totalTime <= 15) tags.add('super-quick');
    if (totalTime <= 30) tags.add('quick');
    if (totalTime <= 45) tags.add('under-45-min');
    
    // Meal type detection
    if (text.contains('breakfast') || text.contains('pancake') || text.contains('egg') && text.contains('morning')) {
      tags.add('breakfast');
    }
    if (text.contains('dessert') || text.contains('cake') || text.contains('cookie') || text.contains('sweet')) {
      tags.add('dessert');
    }
    if (text.contains('salad') || text.contains('healthy') || text.contains('light')) {
      tags.add('healthy');
    }
    
    return tags.toList();
  }
}
