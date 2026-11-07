/// The home screen's proactive nudge cards, in their original fixed order.
/// Each card already renders nothing when it has no relevant data, so
/// reordering them is always safe — this never hides or gates a card, it
/// only decides which one a user sees first.
enum HomeNudgeCardKind {
  split,
  avoRestock,
  personalFlyer,
  calorieRecipe,
  priceComparison,
}

const List<HomeNudgeCardKind> kDefaultHomeNudgeCardOrder = [
  HomeNudgeCardKind.split,
  HomeNudgeCardKind.avoRestock,
  HomeNudgeCardKind.personalFlyer,
  HomeNudgeCardKind.calorieRecipe,
  HomeNudgeCardKind.priceComparison,
];

/// Maps an onboarding "what matters to you" priority id (see
/// `kAppPriorities`) to the home nudge card it's most related to.
/// `discover_recipes` has no mapping — there's no recipe nudge card on the
/// home screen today, so it's stored for future use without affecting
/// order.
/// A priority can map to several cards: "save money" is served both by the
/// basket comparison and by the personal flyer, and picking that priority
/// should surface both rather than arbitrarily one.
const Map<String, List<HomeNudgeCardKind>> kPriorityToHomeNudgeCard = {
  'share_lists': [HomeNudgeCardKind.split],
  'stay_organized': [HomeNudgeCardKind.avoRestock],
  'eat_healthier': [HomeNudgeCardKind.calorieRecipe],
  'save_money': [
    HomeNudgeCardKind.personalFlyer,
    HomeNudgeCardKind.priceComparison,
  ],
};

/// Returns the home nudge cards in display order, given the user's
/// selected priorities. Cards matching a selected priority float to the
/// front, keeping their relative order among themselves and among the
/// rest unchanged — so a user with no priorities selected (skipped
/// onboarding, or onboarded before this existed) sees exactly the
/// original fixed order, byte-for-byte.
List<HomeNudgeCardKind> orderedHomeNudgeCards(Set<String> priorities) {
  if (priorities.isEmpty) return kDefaultHomeNudgeCardOrder;

  final matchedCards = <HomeNudgeCardKind>{
    for (final priority in priorities)
      ...?kPriorityToHomeNudgeCard[priority],
  };
  if (matchedCards.isEmpty) return kDefaultHomeNudgeCardOrder;

  final prioritized = <HomeNudgeCardKind>[];
  final rest = <HomeNudgeCardKind>[];
  for (final card in kDefaultHomeNudgeCardOrder) {
    (matchedCards.contains(card) ? prioritized : rest).add(card);
  }
  return [...prioritized, ...rest];
}
