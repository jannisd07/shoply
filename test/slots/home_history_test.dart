// W11 V9–V12: the Home sections of the history know their content in the
// first frame (from the local snapshot) and say only honest numbers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/presentation/state/history_view_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../screens/history/history_test_harness.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> make(HistoryWorld world) async {
    final container = ProviderContainer(overrides: await world.overrides());
    addTearDown(container.dispose);
    // Load the preferences, as `main` does before the first frame.
    await container.read(sharedPreferencesProvider.future);
    return container;
  }

  test('no trips: every history section is empty', () async {
    final c = await make(HistoryWorld(prefs: prefs));
    expect(c.read(homeMonthHasContentProvider), isFalse);
    expect(c.read(homeSpendingHasContentProvider), isFalse);
    expect(c.read(homeRecentTripsHasContentProvider), isFalse);
    expect(c.read(homeSplitHintHasContentProvider), isFalse);
  });

  test('a trip this month: the month card and recent trips, synchronously', () async {
    final c = await make(
      HistoryWorld(prefs: prefs, trips: [histTrip('t1', histNow, cost: 12)]),
    );
    expect(c.read(homeMonthHasContentProvider), isTrue);
    expect(c.read(homeRecentTripsHasContentProvider), isTrue);
    // One month with an amount is no honest series.
    expect(c.read(homeSpendingHasContentProvider), isFalse);
    expect(c.read(homeHistorySnapshotProvider).thisMonth.spendCents, 1200);
  });

  test('spending compared needs amounts in 3 of the last 6 months', () async {
    final c = await make(
      HistoryWorld(
        prefs: prefs,
        trips: [
          histTrip('a', histNow, cost: 10),
          histTrip('b', DateTime(2026, 10, 2), cost: 10),
          histTrip('c', DateTime(2026, 9, 2), cost: 10),
        ],
      ),
    );
    expect(c.read(homeSpendingHasContentProvider), isTrue);
  });

  test('V12: one open share wins over sharing a trip; module off hides it', () async {
    final world = HistoryWorld(
      prefs: prefs,
      trips: [histTrip('t2', histNow)],
      lists: [histList('l1', 'Wocheneinkauf')],
      shares: [histShare('s1')],
    );
    final c = await make(world);
    expect(c.read(homeSplitHintProvider), isA<OneBalanceHint>());
    SharedPreferences.setMockInitialValues({});
    final off = await make(
      HistoryWorld(
        prefs: await SharedPreferences.getInstance(),
        trips: [histTrip('t2', histNow)],
        shares: [histShare('s1')],
        splitModule: false,
      ),
    );
    expect(off.read(homeSplitHintHasContentProvider), isFalse);
  });

  test('V12: an unsplit trip on a shared list asks to share; dismissed per trip', () async {
    final c = await make(
      HistoryWorld(
        prefs: prefs,
        trips: [histTrip('t2', histNow)],
        lists: [histList('l1', 'Wocheneinkauf')],
      ),
    );
    final hint = c.read(homeSplitHintProvider);
    expect(hint, isA<ShareTripHint>());
    await c.read(splitHintDismissalsProvider)!.dismissTrip('t2');
    c.read(splitHintRevisionProvider.notifier).state++;
    expect(c.read(homeSplitHintProvider), isNull);
  });
}
