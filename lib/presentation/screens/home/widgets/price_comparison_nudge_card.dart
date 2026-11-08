import 'package:flutter/widgets.dart';

/// Former home card "This list is €X cheaper at [store] than [store]". A
/// market comparison is not allowed (Kap. 12, Plan 8), so it renders
/// nothing. Home (A4) uses `HomeSavingsHint` from `b_slots.dart` instead;
/// then this file goes away.
@Deprecated('Market comparisons are not allowed; use HomeSavingsHint')
class PriceComparisonNudgeCard extends StatelessWidget {
  const PriceComparisonNudgeCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
