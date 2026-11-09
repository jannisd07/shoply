import 'package:equatable/equatable.dart';

import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/data/services/store_chain_directory.dart';

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

  /// `StoreChainDirectory` id of the trip's market (`lidl`), or null. Read
  /// from `store_chain`; older trips only kept OSM names in the items'
  /// `price_retailer`, which are normalised through the chain directory
  /// ([dominantChain]) when read.
  final String? storeChainId;

  /// Where [storeChainId] came from: `list`, `learned`, `location`, `user`.
  final String? storeSource;

  /// `user` when a person typed [totalCost]; null for older trips (whose
  /// amount may stem from offer prices, Bug 7).
  final String? totalCostSource;

  /// Account id of the person who finished the trip (older trips: null,
  /// [userId] is the same person).
  final String? completedBy;

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
    this.storeChainId,
    this.storeSource,
    this.totalCostSource,
    this.completedBy,
  });

  /// The trip's amount in whole cents; null without one.
  int? get totalCostCents =>
      totalCost == null ? null : (totalCost! * 100).round();

  factory ShoppingHistory.fromJson(Map<String, dynamic> json) {
    final items = json['items'] != null
        ? (json['items'] as List)
              .map(
                (i) => ShoppingHistoryItem.fromJson(i as Map<String, dynamic>),
              )
              .toList()
        : const <ShoppingHistoryItem>[];
    final storedChain = json['store_chain'] as String?;
    final chain = storedChain != null && StoreChainDirectory.byId(storedChain) != null
        ? storedChain
        : dominantChain([
            for (final item in items)
              if (item.priceRetailer case final r? when r.trim().isNotEmpty) r,
          ]);
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
      items: items,
      storeChainId: chain,
      storeSource: json['store_source'] as String?,
      totalCostSource: json['total_cost_source'] as String?,
      completedBy: json['completed_by'] as String?,
    );
  }

  /// [toJson] plus the items, for the account's local history cache.
  Map<String, dynamic> toCacheJson() => {
    ...toJson(),
    'items': [for (final item in items) item.toJson()],
  };

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
      'store_chain': storeChainId,
      'store_source': storeSource,
      'total_cost_source': totalCostSource,
      'completed_by': completedBy,
    };
  }

  ShoppingHistory copyWith({
    double? totalCost,
    String? paidByUserId,
    String? paidByName,
    List<ShoppingHistoryItem>? items,
    String? storeChainId,
    String? totalCostSource,
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
      storeChainId: storeChainId ?? this.storeChainId,
      storeSource: storeSource,
      totalCostSource: totalCostSource ?? this.totalCostSource,
      completedBy: completedBy,
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
        storeChainId,
        storeSource,
        totalCostSource,
        completedBy,
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
  /// The offer's regular (pre-discount) price when [price] came from a live
  /// offer — carried over from the item at the moment a trip is completed.
  /// Used to compute "you've saved €X" totals across shopping history.
  final double? priceOldValue;

  const ShoppingHistoryItem({
    required this.id,
    required this.historyId,
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.category,
    this.price,
    this.priceRetailer,
    this.priceOldValue,
  });

  /// Savings vs. the offer's regular price, per unit — null unless both
  /// [price] and [priceOldValue] are known and genuinely lower.
  double? get savingsPerUnit {
    if (price == null || priceOldValue == null) return null;
    final diff = priceOldValue! - price!;
    return diff > 0 ? diff : null;
  }

  /// How many packs [price] and [priceOldValue] were paid for: pieces
  /// multiply, a measured quantity ("500 g") is one pack (the history keeps
  /// no pack size to count in base units).
  double get pricingQuantity => packCount(quantity, unit);

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
      priceOldValue: (json['price_old_value'] as num?)?.toDouble(),
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
      'price_old_value': priceOldValue,
    };
  }

  @override
  List<Object?> get props => [
        id,
        historyId,
        name,
        quantity,
        unit,
        category,
        price,
        priceRetailer,
        priceOldValue,
      ];
}

/// Sums [ShoppingHistoryItem.savingsPerUnit] × [ShoppingHistoryItem.pricingQuantity]
/// across every item in every trip in [trips], in euros and unrounded; the
/// screen rounds with `roundedSavingsCents` ("ca. 3,20 € gespart, laut
/// Händler"). Used for both the lifetime total and any narrower window.
///
/// Only offers of the trip's market count (L4, Kap. 12 rule 5): when a trip
/// has a [ShoppingHistory.storeChainId], an item whose `priceRetailer` names
/// another chain saves nothing there.
double totalSavingsOf(Iterable<ShoppingHistory> trips) {
  var total = 0.0;
  for (final trip in trips) {
    final chain = trip.storeChainId;
    for (final item in trip.items) {
      if (chain != null && !_offerOfChain(item.priceRetailer, chain)) continue;
      final perUnit = item.savingsPerUnit;
      if (perUnit != null) total += perUnit * item.pricingQuantity;
    }
  }
  return total;
}

bool _offerOfChain(String? retailer, String chainId) {
  if (retailer == null || retailer.trim().isEmpty) return true;
  final named = StoreChainDirectory.byId(retailer.trim()) != null
      ? retailer.trim()
      : matchChain(retailer);
  return named == null || named == chainId;
}

/// Trips completed in the given [year]/[month] (1-indexed).
Iterable<ShoppingHistory> tripsInMonth(
  Iterable<ShoppingHistory> trips, {
  required int year,
  required int month,
}) {
  return trips.where(
    (t) => t.completedAt.year == year && t.completedAt.month == month,
  );
}
