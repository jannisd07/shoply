import 'package:flutter/widgets.dart';

import 'package:shoply/data/models/shopping_item_model.dart';

/// Offer pill at one item of a list, right side of the row (contract
/// `b_slots.dart`). [compact] shows only the price (shopping mode).
///
/// Shell until S4: there is no offer data per item yet, so it renders
/// nothing. With content it stays empty while `offersVisibleForListProvider`
/// is false or the item has no current offer of the list's market.
class ItemOfferBadge extends StatelessWidget {
  const ItemOfferBadge({
    super.key,
    required this.listId,
    required this.item,
    this.compact = false,
  });

  final String listId;
  final ShoppingItemModel item;
  final bool compact;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
