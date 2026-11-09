import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

/// A price attached to an item (a picked offer or a manual entry): the
/// columns `price`, `price_currency`, `price_retailer`, `price_unit`,
/// `price_old_value` and `price_updated_at` of `shopping_items`.
@immutable
class ItemPrice {
  const ItemPrice({
    required this.price,
    this.currency = 'EUR',
    this.retailer,
    this.unit,
    this.oldValue,
    this.updatedAt,
  });

  /// The price of one product, in [currency].
  final double price;

  /// ISO 4217 code; Avo prices are in euros.
  final String currency;

  /// Retailer chain id (`lidl`, `rewe` …), null for a manual price.
  final String? retailer;

  /// What the price is for ("1 l", "500 g"); null for one piece.
  final String? unit;

  /// The regular price before the discount (the comparison price); null when
  /// there is none. Only a live offer sets it.
  final double? oldValue;

  /// When the price was set; null means "now" at the moment of writing.
  final DateTime? updatedAt;

  /// The price columns of an item row. [now] stands in for a missing
  /// [updatedAt].
  Map<String, dynamic> toColumns({DateTime? now}) => {
    'price': price,
    'price_currency': currency,
    'price_retailer': retailer,
    'price_unit': unit,
    'price_updated_at': (updatedAt ?? now ?? DateTime.now())
        .toUtc()
        .toIso8601String(),
    'price_old_value': oldValue,
  };

  /// The price columns of an item row without a price: all null.
  static const Map<String, dynamic> clearedColumns = {
    'price': null,
    'price_currency': null,
    'price_retailer': null,
    'price_unit': null,
    'price_updated_at': null,
    'price_old_value': null,
  };

  /// The price columns as [item] has them now, to restore them on undo; all
  /// null when the item has no price.
  static Map<String, dynamic> columnsOf(ShoppingItemModel item) => {
    'price': item.price,
    'price_currency': item.priceCurrency,
    'price_retailer': item.priceRetailer,
    'price_unit': item.priceUnit,
    'price_updated_at': item.priceUpdatedAt?.toUtc().toIso8601String(),
    'price_old_value': item.priceOldValue,
  };

  @override
  bool operator ==(Object other) =>
      other is ItemPrice &&
      other.price == price &&
      other.currency == currency &&
      other.retailer == retailer &&
      other.unit == unit &&
      other.oldValue == oldValue &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(price, currency, retailer, unit, oldValue, updatedAt);
}

/// What [ItemRepository.setItemPrice] and [ItemRepository.clearItemPrice]
/// return.
class PriceChangeResult {
  const PriceChangeResult({required this.token, required this.item});

  /// Pass to [ItemRepository.undoPriceChange] to restore the old price.
  final String token;

  /// The item after the change.
  final ShoppingItemModel item;
}

/// One item to put on a list in a batch (Wochenplan "Zutaten der Woche",
/// recipe "Zutaten auf die Liste", photo import).
class NewItem {
  const NewItem({
    required this.name,
    this.quantity = 1,
    this.unit,
    this.category,
    this.notes,
    this.price,
  });

  final String name;
  final double quantity;

  /// Unit id; null means pieces.
  final String? unit;

  /// Language-agnostic category id; null sets it in the background.
  final String? category;
  final String? notes;

  /// An offer or manual price to store with the item; null adds none. On a
  /// merge into an existing item it replaces that item's price.
  final ItemPrice? price;
}

/// What [ItemRepository.addItems] returns.
class AddItemsResult {
  const AddItemsResult({required this.token, required this.items});

  /// Pass to [ItemRepository.undoAddItems] to take the batch back.
  final String token;

  /// The affected rows after the batch: new ones and merged ones.
  final List<ShoppingItemModel> items;
}

/// How a batch lands on a list: what is inserted, what is merged into an
/// existing unchecked item (Konzept 11: same name ignoring case, same unit
/// with "no unit" equal to pieces).
class AddItemsPlan {
  const AddItemsPlan({
    required this.inserts,
    required this.merges,
    this.mergePrices = const {},
  });

  /// New rows, already combined when the batch names an item twice.
  final List<NewItem> inserts;

  /// Existing item id → quantity to add.
  final Map<String, double> merges;

  /// Existing item id → price that replaces its price (only for merges whose
  /// batch item carries one).
  final Map<String, ItemPrice> mergePrices;

  /// Plans [items] against the list's [existingUnchecked] items.
  static AddItemsPlan of(
    List<ShoppingItemModel> existingUnchecked,
    List<NewItem> items,
  ) {
    String key(String name, String? unit) {
      final u = (unit ?? '').trim().toLowerCase();
      return '${name.trim().toLowerCase()}|${u == 'pcs' ? '' : u}';
    }

    final existing = <String, ShoppingItemModel>{
      for (final i in existingUnchecked) key(i.name, i.unit): i,
    };
    final merges = <String, double>{};
    final mergePrices = <String, ItemPrice>{};
    final inserts = <String, NewItem>{};
    for (final item in items) {
      final name = item.name.trim();
      if (name.isEmpty || item.quantity <= 0) continue;
      final k = key(name, item.unit);
      final hit = existing[k];
      if (hit != null) {
        merges[hit.id] = (merges[hit.id] ?? 0) + item.quantity;
        final price = item.price;
        if (price != null) mergePrices.putIfAbsent(hit.id, () => price);
        continue;
      }
      final prev = inserts[k];
      inserts[k] = prev == null
          ? NewItem(
              name: name,
              quantity: item.quantity,
              unit: item.unit,
              category: item.category,
              notes: item.notes,
              price: item.price,
            )
          : NewItem(
              name: prev.name,
              quantity: prev.quantity + item.quantity,
              unit: prev.unit,
              category: prev.category ?? item.category,
              notes: prev.notes ?? item.notes,
              price: prev.price ?? item.price,
            );
    }
    return AddItemsPlan(
      inserts: inserts.values.toList(),
      merges: merges,
      mergePrices: mergePrices,
    );
  }
}
