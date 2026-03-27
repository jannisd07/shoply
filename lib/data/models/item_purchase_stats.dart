import 'package:equatable/equatable.dart';

class ItemPurchaseStats extends Equatable {
  final String id;
  final String userId;
  final String itemName;
  final int purchaseCount;
  final DateTime firstPurchase;
  final DateTime lastPurchase;
  final List<DateTime> purchaseDates;
  final double? averageDaysBetween;
  final String? preferredCategory;
  final double? preferredQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemPurchaseStats({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.purchaseCount,
    required this.firstPurchase,
    required this.lastPurchase,
    required this.purchaseDates,
    this.averageDaysBetween,
    this.preferredCategory,
    this.preferredQuantity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemPurchaseStats.fromJson(Map<String, dynamic> json) {
    // Parse purchase dates array
    List<DateTime> dates = [];
    if (json['purchase_dates'] != null) {
      final datesData = json['purchase_dates'] as List;
      dates = datesData
          .map((d) => DateTime.parse(d as String))
          .toList();
    }

    return ItemPurchaseStats(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      itemName: json['item_name'] as String,
      purchaseCount: json['purchase_count'] as int,
      firstPurchase: DateTime.parse(json['first_purchase'] as String),
      lastPurchase: DateTime.parse(json['last_purchase'] as String),
      purchaseDates: dates,
      averageDaysBetween: (json['average_days_between'] as num?)?.toDouble(),
      preferredCategory: json['preferred_category'] as String?,
      preferredQuantity: (json['preferred_quantity'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_name': itemName,
      'purchase_count': purchaseCount,
      'first_purchase': firstPurchase.toIso8601String(),
      'last_purchase': lastPurchase.toIso8601String(),
      'purchase_dates': purchaseDates.map((d) => d.toIso8601String()).toList(),
      'average_days_between': averageDaysBetween,
      'preferred_category': preferredCategory,
      'preferred_quantity': preferredQuantity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ItemPurchaseStats copyWith({
    String? id,
    String? userId,
    String? itemName,
    int? purchaseCount,
    DateTime? firstPurchase,
    DateTime? lastPurchase,
    List<DateTime>? purchaseDates,
    double? averageDaysBetween,
    String? preferredCategory,
    double? preferredQuantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemPurchaseStats(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemName: itemName ?? this.itemName,
      purchaseCount: purchaseCount ?? this.purchaseCount,
      firstPurchase: firstPurchase ?? this.firstPurchase,
      lastPurchase: lastPurchase ?? this.lastPurchase,
      purchaseDates: purchaseDates ?? this.purchaseDates,
      averageDaysBetween: averageDaysBetween ?? this.averageDaysBetween,
      preferredCategory: preferredCategory ?? this.preferredCategory,
      preferredQuantity: preferredQuantity ?? this.preferredQuantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate days since last purchase
  int get daysSinceLastPurchase {
    return DateTime.now().difference(lastPurchase).inDays;
  }

  /// Check if item is overdue based on average interval
  bool get isOverdue {
    if (averageDaysBetween == null || averageDaysBetween! <= 0) return false;
    return daysSinceLastPurchase > (averageDaysBetween! * 1.2);
  }

  /// Check if item is due soon
  bool get isDueSoon {
    if (averageDaysBetween == null || averageDaysBetween! <= 0) return false;
    final ratio = daysSinceLastPurchase / averageDaysBetween!;
    return ratio >= 0.8 && ratio <= 1.2;
  }

  /// Check if item was recently bought
  bool get isRecentlyBought {
    if (averageDaysBetween == null || averageDaysBetween! <= 0) {
      return daysSinceLastPurchase < 7; // Default to 7 days
    }
    return daysSinceLastPurchase < (averageDaysBetween! * 0.5);
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        itemName,
        purchaseCount,
        firstPurchase,
        lastPurchase,
        purchaseDates,
        averageDaysBetween,
        preferredCategory,
        preferredQuantity,
        createdAt,
        updatedAt,
      ];
}
