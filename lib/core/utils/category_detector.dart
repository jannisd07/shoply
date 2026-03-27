import 'package:flutter/material.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/data/models/product_category.dart';
import 'package:shoply/data/services/smart_categorization_service.dart';

class CategoryDetector {
  /// Detects the category of an item based on its name
  /// Uses smart multi-step classification:
  /// 1. User's learned preferences
  /// 2. Product knowledge base (2000+ items)
  /// 3. Similarity matching
  /// 4. Keyword-based fallback
  static Future<String> detectCategory(String itemName) async {
    if (itemName.isEmpty) return 'Grundnahrungsmittel';
    
    // Use the new smart categorization service
    final result = await SmartCategorizationService.instance.classify(itemName);
    
    // Return the display name of the detected category
    return result.category.displayName;
  }
  
  /// Detects category with confidence score and method info
  static Future<ProductClassificationResult> detectCategoryWithConfidence(String itemName) async {
    if (itemName.isEmpty) {
      return ProductClassificationResult(
        category: ProductCategory.staples,
        confidence: 0.3,
        method: ClassificationMethod.fallback,
      );
    }
    
    return await SmartCategorizationService.instance.classify(itemName);
  }
  
  /// Record when user manually changes a category
  /// This helps the system learn user preferences
  static Future<void> recordUserCategoryChange(String itemName, String category) async {
    await SmartCategorizationService.instance.recordUserCategoryChange(itemName, category);
  }
  
  /// Calculate similarity between two strings (0.0 to 1.0)
  static double _calculateSimilarity(String s1, String s2) {
    // Exact match
    if (s1 == s2) return 1.0;
    
    // Contains match
    if (s1.contains(s2) || s2.contains(s1)) {
      final longer = s1.length > s2.length ? s1 : s2;
      final shorter = s1.length <= s2.length ? s1 : s2;
      return shorter.length / longer.length;
    }
    
    // Levenshtein similarity
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    final levenScore = 1.0 - (distance / maxLen);
    
    // Phonetic similarity (Soundex-like)
    final phoneticScore = _phoneticSimilarity(s1, s2);
    
    // Jaro-Winkler similarity
    final jaroScore = _jaroWinklerSimilarity(s1, s2);
    
    // Weighted combination
    return (levenScore * 0.4) + (phoneticScore * 0.3) + (jaroScore * 0.3);
  }
  
  /// Phonetic similarity (how similar do they sound?)
  static double _phoneticSimilarity(String s1, String s2) {
    final p1 = _toPhonetic(s1);
    final p2 = _toPhonetic(s2);
    
    if (p1 == p2) return 1.0;
    
    final distance = _levenshteinDistance(p1, p2);
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    return maxLen > 0 ? 1.0 - (distance / maxLen) : 0.0;
  }
  
  /// Convert to phonetic representation
  static String _toPhonetic(String text) {
    return text
        // Vowel normalization
        .replaceAll(RegExp(r'[aeiou]+'), 'a')
        // Common German sound patterns
        .replaceAll('ch', 'k')
        .replaceAll('sch', 's')
        .replaceAll('ph', 'f')
        .replaceAll('th', 't')
        .replaceAll('dt', 't')
        .replaceAll('ck', 'k')
        // Double consonants
        .replaceAll(RegExp(r'([bcdfghjklmnpqrstvwxyz])\1+'), r'\1')
        // Remove remaining vowels except first
        .replaceAllMapped(RegExp(r'^([bcdfghjklmnpqrstvwxyz]*)([aeiou])(.*)'), 
            (m) => '${m[1]}${m[2]}${m[3]!.replaceAll(RegExp(r'[aeiou]'), '')}');
  }
  
  /// Jaro-Winkler similarity
  static double _jaroWinklerSimilarity(String s1, String s2) {
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
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    
    final jaro = (matches / len1 + matches / len2 + 
                  (matches - transpositions / 2) / matches) / 3;
    
    // Winkler modification
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
  
  /// Normalize text: lowercase, remove umlauts, remove special chars
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
  
  /// Check if two strings are similar (for typo tolerance)
  static bool _isSimilar(String s1, String s2) {
    // Only check similarity if strings are reasonably close in length
    if ((s1.length - s2.length).abs() > 2) return false;
    
    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);
    
    // Allow 1-2 character differences depending on length
    final maxDistance = s2.length <= 4 ? 1 : 2;
    return distance <= maxDistance;
  }
  
  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));
    
    for (var i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }
    
    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[len1][len2];
  }
  
  /// Gets the icon for a category (by category ID)
  static IconData getCategoryIcon(String categoryId) {
    return Categories.getIcon(categoryId);
  }
  
  /// Gets the color for a category (by category ID)
  static Color getCategoryColor(String categoryId) {
    return Categories.getColor(categoryId);
  }
  
  /// Gets all category IDs
  static List<String> getAllCategories() {
    return Categories.allIds;
  }
}
