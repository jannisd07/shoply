import 'package:flutter/widgets.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_summary.dart';

/// Former "known total + cheapest store" bar of the list screen. There is
/// no basket comparison any more (Kap. 12, Plan 8): it shows
/// [ListOfferSummary] and ignores [items]. Teil A switches to
/// `ListOfferSummary(listId:)` from `b_slots.dart`; then this file goes away.
@Deprecated('Use ListOfferSummary(listId:)')
class ListPriceSummaryBar extends StatelessWidget {
  const ListPriceSummaryBar({
    super.key,
    required this.listId,
    required this.items,
  });

  final String listId;
  final List<ShoppingItemModel> items;

  @override
  Widget build(BuildContext context) => ListOfferSummary(listId: listId);
}
