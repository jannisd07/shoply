// Stufe 2 (prompt-b-vorrang.md): the Home sections of Teil B. Shells render
// nothing and report no content, so Teil A's Home lays out in the first
// frame without anything jumping in later; each passes the layout matrix.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../layout/layout_matrix.dart';

void main() {
  const sections = <Widget>[
    HomeSavingsHint(),
    HomeMonthCard(),
    HomeSpendingComparison(),
    HomeSavingsGoal(),
    HomeCaloriesToday(),
    HomeRestockTile(),
    HomeOffersTile(),
    HomeWaterTile(),
    HomeRecentTrips(),
    HomeCookToday(),
  ];

  final hasContent = <ProviderListenable<bool>>[
    homeSavingsHintHasContentProvider,
    homeMonthHasContentProvider,
    homeSpendingHasContentProvider,
    homeSavingsGoalHasContentProvider,
    homeCaloriesHasContentProvider,
    homeRestockHasContentProvider,
    homeOffersTileHasContentProvider,
    homeWaterHasContentProvider,
    homeRecentTripsHasContentProvider,
    homeCookTodayHasContentProvider,
  ];

  test('every section reports no content synchronously', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (final provider in hasContent) {
      expect(container.read(provider), isFalse);
    }
  });

  testWidgets('every section renders nothing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: sections),
        ),
      ),
    );
    for (final section in sections) {
      expect(tester.getSize(find.byWidget(section)), Size.zero);
    }
  });

  layoutMatrix(
    'Home sections (Teil B)',
    (context) => const ProviderScope(child: Column(children: sections)),
  );
}
