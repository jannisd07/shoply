/// Which sections Home shows, in D2 "Für dich" order (owner decision
/// 07.11.2026, `docs/redesign/status-A.md`). Pure, so the order and the
/// module rules are tested without widgets.
library;

/// A section of Home, top to bottom.
enum HomeSection {
  /// Greeting card with Avo, the savings hint, "Frag Avo …" and chips.
  avoCard,

  /// The savings hint on its own when the Avo module is off.
  savingsHint,

  /// "Dein November" (Teil B).
  month,

  /// "Ausgaben im Vergleich" (Teil B).
  spending,

  /// "Sparziel mit Avo" (Teil B, offers).
  savingsGoal,

  /// "Kalorien heute" (Teil B, calories).
  calories,

  /// The tile grid "Für dich".
  forYou,

  /// "Top-Listen".
  topLists,

  /// "Letzte Einkäufe" (Teil B).
  recentTrips,

  /// "Heute kochen" (Teil B, Wochenplan).
  cookToday,

  /// "Tipp von Avo".
  tip,

  /// "14 Tage Avo Pro gratis testen" (Konzept 18 §11.11).
  proHint,
}

/// A tile of the "Für dich" grid.
enum HomeTile {
  /// "Weiter einkaufen": the list with open items used last (Teil A).
  continueShopping,

  /// "Nochmal kaufen" (Teil B).
  restock,

  /// "Angebote …" (Teil B, offers).
  offers,

  /// "Wasser heute" (Teil B, calories).
  water,
}

/// Everything the order depends on: modules and whether each part has
/// content right now (the synchronous `…HasContentProvider`s of Teil B).
class HomeLayoutInput {
  const HomeLayoutInput({
    this.avo = true,
    this.offers = true,
    this.calories = false,
    this.mealPlan = false,
    this.savingsHint = false,
    this.month = false,
    this.spending = false,
    this.savingsGoal = false,
    this.caloriesToday = false,
    this.continueShopping = false,
    this.restock = false,
    this.offersTile = false,
    this.water = false,
    this.lists = false,
    this.recentTrips = false,
    this.cookToday = false,
    this.tip = false,
    this.proHint = false,
  });

  /// Modules (offers: module on and kill switch off).
  final bool avo;
  final bool offers;
  final bool calories;
  final bool mealPlan;

  /// Content flags.
  final bool savingsHint;
  final bool month;
  final bool spending;
  final bool savingsGoal;
  final bool caloriesToday;
  final bool continueShopping;
  final bool restock;
  final bool offersTile;
  final bool water;
  final bool lists;
  final bool recentTrips;
  final bool cookToday;
  final bool tip;
  final bool proHint;
}

/// The tiles of "Für dich", in D2 order. Empty hides the section.
List<HomeTile> homeTiles(HomeLayoutInput i) => [
  if (i.continueShopping) HomeTile.continueShopping,
  if (i.restock) HomeTile.restock,
  if (i.offers && i.offersTile) HomeTile.offers,
  if (i.calories && i.water) HomeTile.water,
];

/// The sections of Home, in D2 order. A section without content or with its
/// module off is left out entirely, so nothing leaves a gap.
List<HomeSection> homeSections(HomeLayoutInput i) => [
  if (i.avo) HomeSection.avoCard,
  if (!i.avo && i.offers && i.savingsHint) HomeSection.savingsHint,
  if (i.month) HomeSection.month,
  if (i.spending) HomeSection.spending,
  if (i.offers && i.savingsGoal) HomeSection.savingsGoal,
  if (i.calories && i.caloriesToday) HomeSection.calories,
  if (homeTiles(i).isNotEmpty) HomeSection.forYou,
  if (i.lists) HomeSection.topLists,
  if (i.recentTrips) HomeSection.recentTrips,
  if (i.mealPlan && i.cookToday) HomeSection.cookToday,
  if (i.tip) HomeSection.tip,
  if (i.proHint) HomeSection.proHint,
];

/// Space above [section] when it follows [previous] (D2: 24 between
/// sections, 12 inside the money group and between "Heute kochen" and the
/// tip, 40 above the Avo card for the figure that sticks out).
double homeSectionGap(HomeSection? previous, HomeSection section) {
  if (previous == null) {
    return section == HomeSection.avoCard ? 40 : 24;
  }
  const money = {
    HomeSection.month,
    HomeSection.spending,
    HomeSection.savingsGoal,
  };
  if (money.contains(previous) && money.contains(section)) return 12;
  const hints = {HomeSection.cookToday, HomeSection.tip};
  if (hints.contains(previous) &&
      (section == HomeSection.tip || section == HomeSection.proHint)) {
    return 12;
  }
  return 24;
}
