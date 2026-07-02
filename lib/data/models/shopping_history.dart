import 'package:equatable/equatable.dart';

class ShoppingHistory extends Equatable {
  final String id;
  final String userId;
  final String? listId;
  final String listName;
  final int totalItems;
  final DateTime completedAt;
  final String? completedByName;
  final double? totalCost;
  final String? paidByUserId;
  final String? paidByName;
  final List<ShoppingHistoryItem> items;

  const ShoppingHistory({
    required this.id,
    required this.userId,
    this.listId,
    required this.listName,
    required this.totalItems,
    required this.completedAt,
    this.completedByName,
    this.totalCost,
    this.paidByUserId,
    this.paidByName,
    this.items = const [],
  });

  factory ShoppingHistory.fromJson(Map<String, dynamic> json) {
    return ShoppingHistory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      listId: json['list_id'] as String?,
      listName: json['list_name'] as String,
      totalItems: json['total_items'] as int,
      completedAt: DateTime.parse(json['completed_at'] as String),
      completedByName: json['completed_by_name'] as String?,
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      paidByUserId: json['paid_by_user_id'] as String?,
      paidByName: json['paid_by_name'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) => ShoppingHistoryItem.fromJson(i as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'list_id': listId,
      'list_name': listName,
      'total_items': totalItems,
      'completed_at': completedAt.toIso8601String(),
      'completed_by_name': completedByName,
      'total_cost': totalCost,
      'paid_by_user_id': paidByUserId,
      'paid_by_name': paidByName,
    };
  }

  ShoppingHistory copyWith({
    double? totalCost,
    String? paidByUserId,
    String? paidByName,
    List<ShoppingHistoryItem>? items,
  }) {
    return ShoppingHistory(
      id: id,
      userId: userId,
      listId: listId,
      listName: listName,
      totalItems: totalItems,
      completedAt: completedAt,
      completedByName: completedByName,
      totalCost: totalCost ?? this.totalCost,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      paidByName: paidByName ?? this.paidByName,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        listId,
        listName,
        totalItems,
        completedAt,
        completedByName,
        totalCost,
        paidByUserId,
        paidByName,
        items,
      ];
}

class ShoppingHistoryItem extends Equatable {
  final String id;
  final String historyId;
  final String name;
  final double quantity;
  final String? unit;
  final String? category;
  final double? price;
  final String? priceRetailer;

  const ShoppingHistoryItem({
    required this.id,
    required this.historyId,
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.category,
    this.price,
    this.priceRetailer,
  });

  factory ShoppingHistoryItem.fromJson(Map<String, dynamic> json) {
    return ShoppingHistoryItem(
      id: json['id'] as String,
      historyId: json['history_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String?,
      category: json['category'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      priceRetailer: json['price_retailer'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'history_id': historyId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'price': price,
      'price_retailer': priceRetailer,
    };
  }

  @override
  List<Object?> get props =>
      [id, historyId, name, quantity, unit, category, price, priceRetailer];
}
