import 'package:shoply/data/models/product_category.dart';
import 'package:shoply/data/services/product_knowledge_base.dart';
import 'package:shoply/data/services/user_category_preferences.dart';
import 'package:shoply/data/services/product_classifier_service.dart';

/// Smart categorization service using multi-step approach:
/// 1. Check user's learned preferences (highest priority)
/// 2. Check product knowledge base (2000+ exact matches)
/// 3. Use similarity matching with existing keywords
/// 4. Fall back to keyword-based classification
class SmartCategorizationService {
  static final SmartCategorizationService _instance = SmartCategorizationService._();
  static SmartCategorizationService get instance => _instance;
  
  SmartCategorizationService._();

  final _knowledgeBase = ProductKnowledgeBase.instance;
  final _userPreferences = UserCategoryPreferences.instance;
  final _keywordClassifier = ProductClassifierService.instance;

  /// Classify a product using the smart multi-step approach
  Future<ProductClassificationResult> classify(String productName) async {
    if (productName.isEmpty) {
      return ProductClassificationResult(
        category: ProductCategory.staples,
        confidence: 0.3,
        method: ClassificationMethod.fallback,
      );
    }

    // Step 1: Check user's learned preferences (HIGHEST PRIORITY)
    final userPreference = await _userPreferences.getPreference(productName);
    if (userPreference != null) {
      final category = _categoryFromDisplayName(userPreference);
      if (category != null) {
        return ProductClassificationResult(
          category: category,
          confidence: 1.0, // User's choice is always 100% confident
          method: ClassificationMethod.userLearned,
        );
      }
    }

    // Step 2: Check product knowledge base (EXACT MATCHES)
    final knownCategory = _knowledgeBase.getExactCategory(productName);
    if (knownCategory != null) {
      final category = _categoryFromDisplayName(knownCategory);
      if (category != null) {
        return ProductClassificationResult(
          category: category,
          confidence: 0.95, // Very high confidence for known products
          method: ClassificationMethod.knowledgeBase,
        );
      }
    }

    // Step 3: Try similarity matching against knowledge base
    final similarMatch = _findSimilarProduct(productName);
    if (similarMatch != null && similarMatch.confidence >= 0.75) {
      return similarMatch;
    }

    // Step 4: Fall back to keyword-based classification
    final keywordResult = _keywordClassifier.classify(productName);
    
    // Convert to our extended result type
    final convertedResult = ProductClassificationResult(
      category: keywordResult.category,
      confidence: keywordResult.confidence,
      method: ClassificationMethod.keywordMatching,
      alternativeCategories: keywordResult.alternativeCategories,
    );
    
    // If keyword classification has low confidence, try similarity again with lower threshold
    if (keywordResult.confidence < 0.5 && similarMatch != null) {
      return similarMatch;
    }

    return convertedResult;
  }

  /// Find similar product in knowledge base using string similarity
  ProductClassificationResult? _findSimilarProduct(String productName) {
    final normalized = _normalizeProductName(productName);
    
    double bestSimilarity = 0.0;
    String? bestCategory;
    String? bestMatch;

    // Get all products from knowledge base
    final allCategories = _knowledgeBase.getStatistics();
    
    // Check against all known products by iterating through categories
    for (final categoryEntry in allCategories.entries) {
      final category = categoryEntry.key;
      final products = _knowledgeBase.getProductsForCategory(category);
      
      for (final knownProduct in products) {
        final similarity = _calculateSimilarity(normalized, knownProduct);
        
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestCategory = category;
          bestMatch = knownProduct;
        }
      }
    }

    // Only return if similarity is reasonably high
    if (bestSimilarity >= 0.75 && bestCategory != null) {
      final category = _categoryFromDisplayName(bestCategory);
      if (category != null) {
        return ProductClassificationResult(
          category: category,
          confidence: bestSimilarity,
          method: ClassificationMethod.similarityMatching,
          matchedProduct: bestMatch,
        );
      }
    }

    return null;
  }

  /// Calculate similarity between two strings (0.0 to 1.0)
  /// Uses multiple algorithms for best results
  double _calculateSimilarity(String s1, String s2) {
    // Exact match
    if (s1 == s2) return 1.0;
    
    // One contains the other
    if (s1.contains(s2) || s2.contains(s1)) {
      final longer = s1.length > s2.length ? s1 : s2;
      final shorter = s1.length <= s2.length ? s1 : s2;
      return 0.8 + (0.2 * shorter.length / longer.length);
    }
    
    // Levenshtein distance
    final levenScore = _levenshteinSimilarity(s1, s2);
    
    // Jaro-Winkler similarity
    final jaroScore = _jaroWinklerSimilarity(s1, s2);
    
    // Weighted combination (favor Jaro-Winkler for typos)
    return (levenScore * 0.4) + (jaroScore * 0.6);
  }

  /// Levenshtein similarity (0.0 to 1.0)
  double _levenshteinSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  /// Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));
    
    for (var i = 0; i <= len1; i++) matrix[i][0] = i;
    for (var j = 0; j <= len2; j++) matrix[0][j] = j;
    
    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[len1][len2];
  }

  /// Jaro-Winkler similarity (0.0 to 1.0)
  double _jaroWinklerSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    
    final len1 = s1.length;
    final len2 = s2.length;
    
    if (len1 == 0 || len2 == 0) return 0.0;
    
    final matchDistance = (len1 > len2 ? len1 : len2) ~/ 2 - 1;
    final s1Matches = List.filled(len1, false);
    final s2Matches = List.filled(len2, false);
    
    var matches = 0;
    var transpositions = 0;
    
    // Find matches
    for (var i = 0; i < len1; i++) {
      final start = i - matchDistance > 0 ? i - matchDistance : 0;
      final end = i + matchDistance < len2 - 1 ? i + matchDistance + 1 : len2;
      
      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }
    
    if (matches == 0) return 0.0;
    
    // Find transpositions
    var k = 0;
    for (var i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) k++;
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    
    final jaro = (matches / len1 + matches / len2 + 
                  (matches - transpositions / 2) / matches) / 3;
    
    // Winkler modification (boost for common prefix)
    var prefix = 0;
    for (var i = 0; i < (len1 < len2 ? len1 : len2); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
      if (prefix >= 4) break;
    }
    
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  /// Normalize product name
  String _normalizeProductName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Convert category display name to ProductCategory enum
  ProductCategory? _categoryFromDisplayName(String displayName) {
    for (final category in ProductCategory.values) {
      if (category.displayName == displayName) {
        return category;
      }
    }
    return null;
  }

  /// Record that user manually changed a category
  /// This helps the system learn user preferences
  Future<void> recordUserCategoryChange(String productName, String category) async {
    await _userPreferences.learnPreference(productName, category);
  }

  /// Get statistics about classification accuracy
  Map<String, dynamic> getStatistics() {
    return {
      'knowledge_base_products': _knowledgeBase.totalProducts,
      'user_preferences': _userPreferences.getStatistics(),
      'knowledge_base_stats': _knowledgeBase.getStatistics(),
    };
  }
}

/// Extended classification result with additional info
class ProductClassificationResult {
  final ProductCategory category;
  final double confidence;
  final ClassificationMethod method;
  final List<ProductCategory> alternativeCategories;
  final String? matchedProduct; // For similarity matching

  ProductClassificationResult({
    required this.category,
    required this.confidence,
    required this.method,
    this.alternativeCategories = const [],
    this.matchedProduct,
  });

  bool get isHighConfidence => confidence >= 0.7;
  bool get isMediumConfidence => confidence >= 0.4 && confidence < 0.7;
  bool get isLowConfidence => confidence < 0.4;
  
  String get methodDescription {
    switch (method) {
      case ClassificationMethod.userLearned:
        return 'Learned from your choices';
      case ClassificationMethod.knowledgeBase:
        return 'Exact match in database';
      case ClassificationMethod.similarityMatching:
        return 'Similar to: $matchedProduct';
      case ClassificationMethod.keywordMatching:
        return 'Keyword analysis';
      case ClassificationMethod.machineLearning:
        return 'ML prediction';
      case ClassificationMethod.fallback:
        return 'Default category';
    }
  }
}

enum ClassificationMethod {
  userLearned,        // User's previous choices (highest priority)
  knowledgeBase,      // Exact match in product database
  similarityMatching, // Similar to known product
  keywordMatching,    // Keyword-based classification
  machineLearning,    // ML model (future)
  fallback,          // Default fallback
}
