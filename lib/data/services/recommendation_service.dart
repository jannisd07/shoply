import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/recommendation_item.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/product_matching_service.dart';

class RecommendationService {
  final PurchaseTrackingService _trackingService = PurchaseTrackingService();

  /// Get smart recommendations for a shopping list
  Future<List<RecommendationItem>> getRecommendations({
    required List<ShoppingItemModel> currentListItems,
    int limit = 8,
  }) async {
    try {
      // Get all purchase stats
      final allStats = await _trackingService.getAllStats();
      
      // Get current item names (lowercase for comparison)
      final currentItemNames = currentListItems
          .map((item) => item.name.trim().toLowerCase())
          .toSet();

      // If no stats yet, return common starter items
      if (allStats.isEmpty) {
        return _getStarterRecommendations(currentItemNames);
      }

      // Filter out items already in the list
      final availableStats = allStats
          .where((stats) => !currentItemNames.contains(stats.itemName.toLowerCase()))
          .toList();

      // If all items are already in list, suggest complementary items
      if (availableStats.isEmpty) {
        return _getComplementaryRecommendations(currentListItems);
      }

      // Calculate scores for each item
      final recommendationsWithScores = <RecommendationItem>[];
      
      for (final stats in availableStats) {
        final baseScore = _calculateRecommendationScore(stats, currentListItems);
        
        // Check for active deals
        final deal = await ProductMatchingService.findBestDealForProduct(stats.itemName);
        final dealBonus = deal != null ? 20.0 : 0.0;
        
        final finalScore = baseScore + dealBonus;
        final reason = _generateReason(stats, hasDeal: deal != null, deal: deal);

        recommendationsWithScores.add(RecommendationItem(
          itemName: stats.itemName,
          score: finalScore,
          reason: reason,
          stats: stats,
          category: stats.preferredCategory,
          quantity: stats.preferredQuantity,
        ));
      }

      // Sort by score (highest first) and take top N
      recommendationsWithScores.sort((a, b) => b.score.compareTo(a.score));
      return recommendationsWithScores.take(limit).toList();
    } catch (e) {
      return _getStarterRecommendations({});
    }
  }

  /// Get starter recommendations when no purchase history exists
  List<RecommendationItem> _getStarterRecommendations(Set<String> excludeNames) {
    final commonItems = [
      {'name': 'Milch', 'category': 'Milchprodukte', 'quantity': 1.0},
      {'name': 'Brot', 'category': 'Backwaren', 'quantity': 1.0},
      {'name': 'Eier', 'category': 'Eier & Milchprodukte', 'quantity': 6.0},
      {'name': 'Butter', 'category': 'Milchprodukte', 'quantity': 1.0},
      {'name': 'Käse', 'category': 'Milchprodukte', 'quantity': 200.0},
      {'name': 'Äpfel', 'category': 'Obst', 'quantity': 1.0},
      {'name': 'Bananen', 'category': 'Obst', 'quantity': 1.0},
      {'name': 'Tomaten', 'category': 'Gemüse', 'quantity': 500.0},
    ];

    return commonItems
        .where((item) => !excludeNames.contains((item['name'] as String).toLowerCase()))
        .map((item) => RecommendationItem(
              itemName: item['name'] as String,
              score: 50.0,
              reason: 'Beliebtes Produkt',
              category: item['category'] as String?,
              quantity: item['quantity'] as double?,
            ))
        .toList();
  }

  /// Get complementary recommendations based on current list
  List<RecommendationItem> _getComplementaryRecommendations(List<ShoppingItemModel> currentItems) {
    final complementary = <String, Map<String, dynamic>>{
      'Nudeln': {'complement': 'Tomatensoße', 'category': 'Konserven'},
      'Reis': {'complement': 'Sojasoße', 'category': 'Gewürze'},
      'Brot': {'complement': 'Butter', 'category': 'Milchprodukte'},
      'Kaffee': {'complement': 'Milch', 'category': 'Milchprodukte'},
      'Müsli': {'complement': 'Milch', 'category': 'Milchprodukte'},
      'Chips': {'complement': 'Salsa', 'category': 'Snacks'},
    };

    final recommendations = <RecommendationItem>[];
    for (final item in currentItems) {
      if (complementary.containsKey(item.name)) {
        final comp = complementary[item.name]!;
        recommendations.add(RecommendationItem(
          itemName: comp['complement'] as String,
          score: 60.0,
          reason: 'Passt zu ${item.name}',
          category: comp['category'] as String?,
          quantity: 1.0,
        ));
      }
    }

    return recommendations;
  }

  /// Calculate recommendation score for an item
  double _calculateRecommendationScore(ItemPurchaseStats stats, List<ShoppingItemModel> currentItems) {
    double score = 0.0;

    // Frequency Score (0-40 points)
    score += _calculateFrequencyScore(stats.purchaseCount);

    // Recency Score (0-30 points)
    score += _calculateRecencyScore(stats);

    // Preference Score (0-20 points)
    score += _calculatePreferenceScore(stats);

    // Timing Score (0-10 points)
    score += _calculateTimingScore(stats);

    // Context bonus: if similar category items in list
    score += _calculateContextBonus(stats, currentItems);

    // NEW: Deal Bonus (0-20 points) - Boost items that are on sale!
    score += _calculateDealBonus(stats.itemName);

    return score.clamp(0.0, 120.0); // Erhöht von 100 auf 120 wegen Deal-Bonus
  }

  /// Calculate deal bonus - items on sale get priority! 
  double _calculateDealBonus(String itemName) {
    // This runs synchronously - we check if deals exist
    // In practice, deals are cached in memory for fast access
    return 0.0; // Will be implemented with async wrapper
  }

  /// Calculate context bonus based on items already in list
  double _calculateContextBonus(ItemPurchaseStats stats, List<ShoppingItemModel> currentItems) {
    if (stats.preferredCategory == null) return 0.0;

    final hasSameCategoryItem = currentItems.any(
      (item) => item.category == stats.preferredCategory
    );

    return hasSameCategoryItem ? 5.0 : 0.0;
  }

  /// Calculate frequency score based on purchase count
  double _calculateFrequencyScore(int purchaseCount) {
    if (purchaseCount >= 10) return 40.0;
    if (purchaseCount >= 7) return 30.0;
    if (purchaseCount >= 4) return 20.0;
    if (purchaseCount >= 2) return 10.0;
    return 5.0;
  }

  /// Calculate recency score based on time since last purchase
  double _calculateRecencyScore(ItemPurchaseStats stats) {
    final daysSince = stats.daysSinceLastPurchase;
    final avgDays = stats.averageDaysBetween;

    // If no average (only 1 purchase), use simple recency
    if (avgDays == null || avgDays <= 0) {
      if (daysSince > 30) return 25.0;
      if (daysSince > 14) return 20.0;
      if (daysSince > 7) return 15.0;
      return 5.0;
    }

    // Calculate ratio of days since last purchase to average interval
    final ratio = daysSince / avgDays;

    if (ratio > 1.2) return 30.0;  // Overdue - highest priority
    if (ratio >= 0.8) return 25.0;  // Due soon
    if (ratio >= 0.5) return 15.0;  // Approaching due date
    return 5.0;  // Recently bought
  }

  /// Calculate preference score
  double _calculatePreferenceScore(ItemPurchaseStats stats) {
    double score = 0.0;

    // High purchase count indicates preference
    if (stats.purchaseCount >= 5) {
      score += 10.0;
    }

    // Consistent category indicates preference
    if (stats.preferredCategory != null) {
      score += 5.0;
    }

    // Consistent quantity indicates preference
    if (stats.preferredQuantity != null) {
      score += 5.0;
    }

    return score;
  }

  /// Calculate timing score based on purchase patterns
  double _calculateTimingScore(ItemPurchaseStats stats) {
    if (stats.purchaseDates.length < 3) return 0.0;

    // Check for cyclical pattern (consistent intervals)
    final intervals = <int>[];
    final sortedDates = [...stats.purchaseDates]..sort();

    for (int i = 1; i < sortedDates.length; i++) {
      intervals.add(sortedDates[i].difference(sortedDates[i - 1]).inDays);
    }

    if (intervals.isEmpty) return 0.0;

    // Calculate standard deviation of intervals
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals
        .map((interval) => (interval - mean) * (interval - mean))
        .reduce((a, b) => a + b) / intervals.length;
    final stdDev = variance.isFinite ? variance : 0.0;

    // Low standard deviation = consistent pattern
    if (stdDev < mean * 0.3) return 10.0;  // Very consistent
    if (stdDev < mean * 0.5) return 7.0;   // Somewhat consistent
    return 0.0;
  }

  /// Generate human-readable reason for recommendation
  String _generateReason(ItemPurchaseStats stats, {bool hasDeal = false, dynamic deal}) {
    // Priority: Show deal info first!
    if (hasDeal && deal != null) {
      final discount = deal.discountPercentage ?? 0;
      final supermarket = deal.supermarket ?? '';
      return '🏷️ ${discount.toStringAsFixed(0)}% Rabatt bei $supermarket!';
    }

    // Check if overdue
    if (stats.isOverdue) {
      final daysOverdue = stats.daysSinceLastPurchase - (stats.averageDaysBetween ?? 0).round();
      return 'Overdue by $daysOverdue days';
    }

    // Check if due soon
    if (stats.isDueSoon) {
      return 'Usually buy every ${stats.averageDaysBetween?.round() ?? 0} days';
    }

    // High frequency
    if (stats.purchaseCount >= 10) {
      return 'You buy this often (${stats.purchaseCount}x)';
    }

    // Regular purchase
    if (stats.purchaseCount >= 5) {
      return 'Regular purchase';
    }

    // Recent but not too recent
    if (stats.daysSinceLastPurchase > 7) {
      return 'Last bought ${stats.daysSinceLastPurchase} days ago';
    }

    // Default
    return 'Frequently purchased';
  }

  /// Get recommendations by category
  Future<Map<String, List<RecommendationItem>>> getRecommendationsByCategory({
    required List<ShoppingItemModel> currentListItems,
  }) async {
    final recommendations = await getRecommendations(
      currentListItems: currentListItems,
      limit: 20,
    );

    final Map<String, List<RecommendationItem>> byCategory = {};

    for (final rec in recommendations) {
      final category = rec.category ?? 'Other';
      byCategory.putIfAbsent(category, () => []).add(rec);
    }

    return byCategory;
  }
}
