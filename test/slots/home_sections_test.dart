// Stufe 2 (prompt-b-vorrang.md): the Home sections of Teil B. Shells render
// nothing and report no content, so Teil A's Home lays out in the first
// frame without anything jumping in later; each passes the layout matrix.
// The calorie sections have content: test/slots/home_calories_test.dart.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../layout/layout_matrix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sections = <Widget>[
    HomeSavingsHint(),
    HomeMonthCard(),
    HomeSpendingComparison(),
    HomeSplitHint(),
    HomeSavingsGoal(),
    HomeRestockTile(),
    HomeOffersTile(),
    HomeRecentTrips(),
    HomeCookToday(),
  ];

  final hasContent = <ProviderListenable<bool>>[
    homeSavingsHintHasContentProvider,
    homeMonthHasContentProvider,
    homeSpendingHasContentProvider,
    homeSplitHintHasContentProvider,
    homeSavingsGoalHasContentProvider,
    homeRestockHasContentProvider,
    homeOffersTileHasContentProvider,
    homeRecentTripsHasContentProvider,
    homeCookTodayHasContentProvider,
  ];

  // Signed out: no history, no shares (the history sections have content
  // tests in test/slots/home_history_test.dart).
  final signedOut = [
    authUserIdProvider.overrideWithValue(null),
    moduleEnabledProvider.overrideWith((ref, m) => true),
  ];

  test('every section reports no content synchronously', () {
    final container = ProviderContainer(overrides: signedOut);
    addTearDown(container.dispose);
    for (final provider in hasContent) {
      expect(container.read(provider), isFalse);
    }
  });

  testWidgets('every section renders nothing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: signedOut,
        child: const Directionality(
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
    (context) => ProviderScope(
      overrides: signedOut,
      child: const Column(children: sections),
    ),
  );
}
