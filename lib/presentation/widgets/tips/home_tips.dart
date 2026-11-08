import 'package:flutter/widgets.dart';

import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

/// Hint rows Home shows at most (K-38); tips come after the savings hint and
/// the meal plan.
const int kHomeMaxHintRows = 2;

/// Whether Home still has room for a tip next to the savings hint and the
/// meal plan of today.
bool homeTipAllowed({required bool savingsHint, required bool cookToday}) =>
    (savingsHint ? 1 : 0) + (cookToday ? 1 : 0) < kHomeMaxHintRows;

/// Home's facts from the lists (null while they load): the fullest list's
/// open items and whether any list is shared.
TipFacts homeTipFacts(List<ShoppingListModel>? lists) {
  if (lists == null) return const TipFacts(ready: false);
  var open = 0;
  for (final list in lists) {
    final count = list.uncheckedCount ?? 0;
    if (count > open) open = count;
  }
  return TipFacts(openItems: open, shared: lists.any((l) => l.isShared));
}

/// Home's tip as one row in a group of its own (T2, T4). Home decides with
/// [visit] whether the section exists and passes the same visit here.
class HomeTipSection extends StatelessWidget {
  const HomeTipSection({super.key, required this.visit, required this.facts});

  final TipVisit visit;
  final TipFacts facts;

  @override
  Widget build(BuildContext context) => TipSlot(
    place: TipPlace.home,
    facts: facts,
    visit: visit,
    wrap: (context, row) => InsetSection(children: [row]),
  );
}
