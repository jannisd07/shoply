import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Home sections from Teil B for D2 "Für dich" (prompt-b-vorrang.md, Stufe 2).
// Teil A builds the frame, the order, the 16-pt side margin and the spacing,
// and hides a section when its module is off; B draws the content.
//
// Every section has a synchronous `…HasContentProvider` read from the
// account's local cache, so Home decides its layout in the first frame and
// nothing jumps in later. Shells until the content lands: every widget
// renders `SizedBox.shrink()`, every provider is false.

/// Text in the Avo card at the top plus "Angebote ansehen" (offers module).
/// Wording per Plan 8: "4 von 11 Artikeln diese Woche bei Lidl im Angebot,
/// ca. 3,20 € gespart, in deiner Region", never "lohnt sich" or a market
/// comparison; false without a real region.
final homeSavingsHintHasContentProvider = Provider<bool>((ref) => false);

class HomeSavingsHint extends StatelessWidget {
  const HomeSavingsHint({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Dein November": spending, purchases, and "Gespart" only with the offers
/// module and real savings data.
final homeMonthHasContentProvider = Provider<bool>((ref) => false);

class HomeMonthCard extends StatelessWidget {
  const HomeMonthCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Ausgaben im Vergleich": six monthly bars, a list from AX1. Only months
/// with entered amounts count.
final homeSpendingHasContentProvider = Provider<bool>((ref) => false);

class HomeSpendingComparison extends StatelessWidget {
  const HomeSpendingComparison({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Sparziel mit Avo" (offers module).
final homeSavingsGoalHasContentProvider = Provider<bool>((ref) => false);

class HomeSavingsGoal extends StatelessWidget {
  const HomeSavingsGoal({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Kalorien heute" with "Mahlzeit hinzufügen" (calories module).
final homeCaloriesHasContentProvider = Provider<bool>((ref) => false);

class HomeCaloriesToday extends StatelessWidget {
  const HomeCaloriesToday({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Tile "Nochmal kaufen"; its plus adds through `ItemRepository.addItems`
/// with undo.
final homeRestockHasContentProvider = Provider<bool>((ref) => false);

class HomeRestockTile extends StatelessWidget {
  const HomeRestockTile({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Tile "Angebote …" (offers module); never "in der Nähe" without a
/// location.
final homeOffersTileHasContentProvider = Provider<bool>((ref) => false);

class HomeOffersTile extends StatelessWidget {
  const HomeOffersTile({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Tile "Wasser heute" (calories module).
final homeWaterHasContentProvider = Provider<bool>((ref) => false);

class HomeWaterTile extends StatelessWidget {
  const HomeWaterTile({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Letzte Einkäufe": at most three, "Alle anzeigen" opens `/history`.
final homeRecentTripsHasContentProvider = Provider<bool>((ref) => false);

class HomeRecentTrips extends StatelessWidget {
  const HomeRecentTrips({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Heute kochen" from the meal plan (mealPlan module); "Fehlende n auf die
/// Liste" adds through `ItemRepository.addItems`.
final homeCookTodayHasContentProvider = Provider<bool>((ref) => false);

class HomeCookToday extends StatelessWidget {
  const HomeCookToday({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
