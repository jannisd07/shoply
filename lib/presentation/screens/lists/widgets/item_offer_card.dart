import 'package:flutter/widgets.dart';

import 'package:shoply/data/models/shopping_item_model.dart';

/// Green offer card on the full-screen item editor (D2-Artikel, contract
/// `b_slots.dart`).
///
/// Shell until S4: renders nothing. With content it shows the current offer
/// of the list's market "laut Händler" and stays empty while offers are
/// unavailable, hidden on [listId] or there is none.
class ItemOfferCard extends StatelessWidget {
  const ItemOfferCard({super.key, required this.listId, required this.item});

  final String listId;
  final ShoppingItemModel item;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
