import 'dart:math';

/// ML-based shopping recommendation service
/// Uses collaborative filtering and association rules to provide smart recommendations
/// Caches model parameters locally for fast inference
class ShoppingRecommenderService {
  static final ShoppingRecommenderService instance = ShoppingRecommenderService._();
  ShoppingRecommenderService._();

  // Cached association rules (item -> related items with confidence scores)
  final Map<String, Map<String, double>> _associations = {};
  
  // Item frequency tracking (item -> purchase count)
  final Map<String, int> _itemFrequency = {};
  
  // Item purchase intervals (item -> list of days between purchases)
  final Map<String, List<int>> _purchaseIntervals = {};
  
  // Last purchase dates (item -> timestamp)
  final Map<String, DateTime> _lastPurchased = {};

  /// Initialize the recommendation engine with historical data
  void initialize(List<PurchaseHistory> history) {
    _buildItemFrequency(history);
    _buildAssociations(history);
    _buildPurchaseIntervals(history);
  }

  /// Generate smart recommendations based on current list and purchase history
  List<RecommendationItem> recommend({
    required List<String> currentListItems,
    required List<PurchaseHistory> userHistory,
    int maxRecommendations = 8,
  }) {
    final scores = <String, double>{};

    // 1. Frequency-based recommendations (60% weight)
    _addFrequencyScores(scores, userHistory, weight: 0.6);

    // 2. Association-based recommendations (25% weight)
    _addAssociationScores(scores, currentListItems, weight: 0.25);

    // 3. Time-based recommendations (15% weight)
    _addTimeBasedScores(scores, weight: 0.15);

    // Filter out items already in the list
    final currentItemsLower = currentListItems.map((i) => i.toLowerCase()).toList();
    scores.removeWhere((item, _) => currentItemsLower.contains(item.toLowerCase()));

    // Sort by score and return top N
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(maxRecommendations).map((entry) {
      return RecommendationItem(
        name: entry.key,
        confidence: entry.value,
        reason: _generateReason(entry.key, entry.value, currentListItems),
      );
    }).toList();
  }

  /// Build frequency map from purchase history
  void _buildItemFrequency(List<PurchaseHistory> history) {
    _itemFrequency.clear();
    for (final purchase in history) {
      for (final item in purchase.items) {
        _itemFrequency[item] = (_itemFrequency[item] ?? 0) + 1;
      }
    }
  }

  /// Build association rules using Apriori-like algorithm
  void _buildAssociations(List<PurchaseHistory> history) {
    _associations.clear();
    
    // Count co-occurrences
    final coOccurrences = <String, Map<String, int>>{};
    
    for (final purchase in history) {
      final items = purchase.items;
      for (int i = 0; i < items.length; i++) {
        for (int j = 0; j < items.length; j++) {
          if (i != j) {
            final item1 = items[i];
            final item2 = items[j];
            
            coOccurrences.putIfAbsent(item1, () => {});
            coOccurrences[item1]![item2] = (coOccurrences[item1]![item2] ?? 0) + 1;
          }
        }
      }
    }

    // Calculate confidence scores
    for (final entry in coOccurrences.entries) {
      final item1 = entry.key;
      final item1Count = _itemFrequency[item1] ?? 1;
      
      _associations[item1] = {};
      for (final subEntry in entry.value.entries) {
        final item2 = subEntry.key;
        final coCount = subEntry.value;
        
        // Confidence = P(item2 | item1) = count(item1, item2) / count(item1)
        final confidence = coCount / item1Count;
        _associations[item1]![item2] = confidence;
      }
    }
  }

  /// Build purchase interval patterns
  void _buildPurchaseIntervals(List<PurchaseHistory> history) {
    _purchaseIntervals.clear();
    _lastPurchased.clear();

    // Sort history by date
    final sortedHistory = List<PurchaseHistory>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final itemLastSeen = <String, DateTime>{};

    for (final purchase in sortedHistory) {
      for (final item in purchase.items) {
        if (itemLastSeen.containsKey(item)) {
          final daysSince = purchase.date.difference(itemLastSeen[item]!).inDays;
          _purchaseIntervals.putIfAbsent(item, () => []);
          _purchaseIntervals[item]!.add(daysSince);
        }
        itemLastSeen[item] = purchase.date;
        _lastPurchased[item] = purchase.date;
      }
    }
  }

  /// Add frequency-based scores
  void _addFrequencyScores(Map<String, double> scores, List<PurchaseHistory> history, {required double weight}) {
    final now = DateTime.now();
    
    for (final entry in _itemFrequency.entries) {
      final item = entry.key;
      final frequency = entry.value;
      
      // Calculate average purchase interval
      final intervals = _purchaseIntervals[item];
      if (intervals == null || intervals.isEmpty) continue;
      
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      
      // Check if it's time to buy again
      final lastPurchase = _lastPurchased[item];
      if (lastPurchase == null) continue;
      
      final daysSinceLastPurchase = now.difference(lastPurchase).inDays;
      
      // Score based on how overdue the item is
      final intervalRatio = daysSinceLastPurchase / avgInterval;
      
      if (intervalRatio >= 0.8) {
        // Item is due or overdue
        final score = min(1.0, intervalRatio) * (frequency / 10.0);
        scores[item] = (scores[item] ?? 0.0) + (score * weight);
      }
    }
  }

  /// Add association-based scores
  void _addAssociationScores(Map<String, double> scores, List<String> currentItems, {required double weight}) {
    for (final currentItem in currentItems) {
      final associations = _associations[currentItem];
      if (associations == null) continue;

      for (final entry in associations.entries) {
        final relatedItem = entry.key;
        final confidence = entry.value;
        
        scores[relatedItem] = (scores[relatedItem] ?? 0.0) + (confidence * weight);
      }
    }
  }

  /// Add time-based scores (seasonal, day of week patterns)
  void _addTimeBasedScores(Map<String, double> scores, {required double weight}) {
    final now = DateTime.now();
    
    // Boost scores for items frequently bought on this day of week
    // (Simplified - in a real ML model, this would use temporal patterns)
    final dayOfWeek = now.weekday;
    
    for (final entry in _itemFrequency.entries) {
      final item = entry.key;
      final frequency = entry.value;
      
      // Higher frequency items get a small boost
      if (frequency >= 3) {
        scores[item] = (scores[item] ?? 0.0) + (0.1 * weight);
      }
      
      // Weekend boost for certain categories
      if (dayOfWeek >= 6) {
        if (_isWeekendItem(item)) {
          scores[item] = (scores[item] ?? 0.0) + (0.2 * weight);
        }
      }
    }
  }

  /// Check if item is typically bought on weekends
  bool _isWeekendItem(String item) {
    final itemLower = item.toLowerCase();
    final weekendKeywords = [
      'beer', 'wine', 'snack', 'chip', 'ice cream', 'cake', 'grill',
      'bier', 'wein', 'chips', 'eis', 'kuchen',
      'cerveza', 'vino', 'helado',
      'bière', 'vin', 'glace',
      'birra', 'vino', 'gelato',
    ];
    
    return weekendKeywords.any((keyword) => itemLower.contains(keyword));
  }

  /// Generate human-readable reason for recommendation
  String _generateReason(String item, double confidence, List<String> currentItems) {
    if (confidence > 0.7) {
      return 'Frequently bought together';
    } else if (confidence > 0.5) {
      return 'You buy this regularly';
    } else if (confidence > 0.3) {
      return 'Goes well with your list';
    } else {
      return 'Suggested for you';
    }
  }

  /// Train the model with new purchase data (incremental learning)
  void trainIncremental(PurchaseHistory newPurchase) {
    // Update frequency
    for (final item in newPurchase.items) {
      _itemFrequency[item] = (_itemFrequency[item] ?? 0) + 1;
      
      // Update last purchased
      _lastPurchased[item] = newPurchase.date;
      
      // Update intervals
      if (_lastPurchased.containsKey(item) && _lastPurchased[item] != newPurchase.date) {
        final daysSince = newPurchase.date.difference(_lastPurchased[item]!).inDays;
        _purchaseIntervals.putIfAbsent(item, () => []);
        _purchaseIntervals[item]!.add(daysSince);
        
        // Keep only last 10 intervals to avoid memory growth
        if (_purchaseIntervals[item]!.length > 10) {
          _purchaseIntervals[item]!.removeAt(0);
        }
      }
    }

    // Update associations
    for (int i = 0; i < newPurchase.items.length; i++) {
      for (int j = 0; j < newPurchase.items.length; j++) {
        if (i != j) {
          final item1 = newPurchase.items[i];
          final item2 = newPurchase.items[j];
          
          _associations.putIfAbsent(item1, () => {});
          final currentConfidence = _associations[item1]![item2] ?? 0.0;
          
          // Exponential moving average for incremental update
          _associations[item1]![item2] = currentConfidence * 0.9 + 0.1;
        }
      }
    }
  }

  /// Save model parameters (for persistence)
  Map<String, dynamic> exportModel() {
    return {
      'associations': _associations,
      'item_frequency': _itemFrequency,
      'purchase_intervals': _purchaseIntervals,
      'last_purchased': _lastPurchased.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }

  /// Load model parameters (from persistence)
  void importModel(Map<String, dynamic> data) {
    _associations.clear();
    _associations.addAll((data['associations'] as Map).cast<String, Map<String, double>>());
    
    _itemFrequency.clear();
    _itemFrequency.addAll((data['item_frequency'] as Map).cast<String, int>());
    
    _purchaseIntervals.clear();
    _purchaseIntervals.addAll((data['purchase_intervals'] as Map).cast<String, List<int>>());
    
    _lastPurchased.clear();
    for (final entry in (data['last_purchased'] as Map).entries) {
      _lastPurchased[entry.key as String] = DateTime.parse(entry.value as String);
    }
  }
}

/// Model for purchase history
class PurchaseHistory {
  final List<String> items;
  final DateTime date;

  const PurchaseHistory({
    required this.items,
    required this.date,
  });
}

/// Model for recommended item with confidence score
class RecommendationItem {
  final String name;
  final double confidence;
  final String reason;

  const RecommendationItem({
    required this.name,
    required this.confidence,
    required this.reason,
  });
}
