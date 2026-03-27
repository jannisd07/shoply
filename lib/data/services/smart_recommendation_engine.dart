import 'package:shoply/data/services/supabase_service.dart';

class SmartRecommendationEngine {
  final _supabase = SupabaseService.instance;

  /// Get smart recommendations based on purchase history
  Future<List<RecommendedItem>> getRecommendations({
    required String userId,
    int count = 8,
  }) async {
    try {
      // Call the database function we created
      final response = await _supabase.client
          .rpc('get_recommended_items', params: {
        'p_user_id': userId,
        'p_limit': count,
      });

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => RecommendedItem.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Calculate recommendation score for an item (client-side fallback)
  double calculateScore({
    required String itemName,
    required int purchaseCount,
    required DateTime lastPurchase,
    double? averageDaysBetween,
  }) {
    final frequencyScore = _calculateFrequencyScore(purchaseCount);
    final recencyScore = _calculateRecencyScore(lastPurchase, averageDaysBetween);
    
    // Weighted algorithm
    return (frequencyScore * 0.4) + (recencyScore * 0.6);
  }

  double _calculateFrequencyScore(int purchaseCount) {
    // Normalize purchase count (diminishing returns after 10 purchases)
    if (purchaseCount >= 10) return 1.0;
    return purchaseCount / 10.0;
  }

  double _calculateRecencyScore(DateTime lastPurchase, double? averageDaysBetween) {
    final daysSince = DateTime.now().difference(lastPurchase).inDays;
    
    if (averageDaysBetween == null || averageDaysBetween == 0) {
      // No pattern established, use simple recency
      if (daysSince <= 7) return 0.8;
      if (daysSince <= 14) return 0.6;
      if (daysSince <= 30) return 0.4;
      return 0.2;
    }

    // Item is overdue for repurchase
    if (daysSince >= averageDaysBetween * 0.8) {
      final overdueRatio = daysSince / averageDaysBetween;
      if (overdueRatio >= 1.2) return 1.0; // Very overdue
      if (overdueRatio >= 1.0) return 0.9; // Due now
      return 0.7; // Almost due
    }

    // Too soon to repurchase
    return 0.3;
  }

  /// Get reason text for recommendation
  String getRecommendationReason({
    required int purchaseCount,
    required DateTime lastPurchase,
    double? averageDaysBetween,
  }) {
    final daysSince = DateTime.now().difference(lastPurchase).inDays;

    if (averageDaysBetween != null && daysSince >= averageDaysBetween * 1.2) {
      return 'Overdue';
    }

    if (averageDaysBetween != null && daysSince >= averageDaysBetween * 0.8) {
      return 'Usually buy every ${averageDaysBetween.round()} days';
    }

    if (purchaseCount >= 5) {
      return 'You buy this often';
    }

    return 'Frequently purchased';
  }
}

class RecommendedItem {
  final String itemName;
  final double score;
  final String reason;
  final String? category;
  final double? quantity;

  RecommendedItem({
    required this.itemName,
    required this.score,
    required this.reason,
    this.category,
    this.quantity,
  });

  factory RecommendedItem.fromJson(Map<String, dynamic> json) {
    return RecommendedItem(
      itemName: json['item_name'] as String,
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String,
      category: json['category'] as String?,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'score': score,
      'reason': reason,
      'category': category,
      'quantity': quantity,
    };
  }
}
