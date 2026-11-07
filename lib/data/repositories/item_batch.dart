import 'package:shoply/data/models/shopping_item_model.dart';

/// One item to put on a list in a batch (Wochenplan "Zutaten der Woche",
/// recipe "Zutaten auf die Liste", photo import).
class NewItem {
  const NewItem({
    required this.name,
    this.quantity = 1,
    this.unit,
    this.category,
    this.notes,
  });

  final String name;
  final double quantity;

  /// Unit id; null means pieces.
  final String? unit;

  /// Language-agnostic category id; null sets it in the background.
  final String? category;
  final String? notes;
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
  const AddItemsPlan({required this.inserts, required this.merges});

  /// New rows, already combined when the batch names an item twice.
  final List<NewItem> inserts;

  /// Existing item id → quantity to add.
  final Map<String, double> merges;

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
    final inserts = <String, NewItem>{};
    for (final item in items) {
      final name = item.name.trim();
      if (name.isEmpty || item.quantity <= 0) continue;
      final k = key(name, item.unit);
      final hit = existing[k];
      if (hit != null) {
        merges[hit.id] = (merges[hit.id] ?? 0) + item.quantity;
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
            )
          : NewItem(
              name: prev.name,
              quantity: prev.quantity + item.quantity,
              unit: prev.unit,
              category: prev.category ?? item.category,
              notes: prev.notes ?? item.notes,
            );
    }
    return AddItemsPlan(inserts: inserts.values.toList(), merges: merges);
  }
}
