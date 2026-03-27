import 'package:equatable/equatable.dart';
import 'package:shoply/data/models/item_purchase_stats.dart';

class RecommendationItem extends Equatable {
  final String itemName;
  final double score;
  final String reason;
  final ItemPurchaseStats? stats;
  final String? category;
  final double? quantity;

  const RecommendationItem({
    required this.itemName,
    required this.score,
    required this.reason,
    this.stats,
    this.category,
    this.quantity,
  });

  @override
  List<Object?> get props => [
        itemName,
        score,
        reason,
        stats,
        category,
        quantity,
      ];
}
