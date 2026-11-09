// Layout matrix (widths 320-440 pt, text 1.0-3.1, bold, dark, contrast) for
// W11's screens V4–V8 and the Home sections V9–V12 (verlauf-kosten.md 3.9),
// in German, where the texts are longest. Plus the honesty pass (3.14):
// with offers hidden no "gespart", with Kosten teilen off no "schuldet".
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/presentation/screens/history/history_screen.dart';
import 'package:shoply/presentation/screens/history/open_balances_screen.dart';
import 'package:shoply/presentation/screens/history/split_editor_screen.dart';
import 'package:shoply/presentation/screens/history/trip_amount_screen.dart';
import 'package:shoply/presentation/screens/history/trip_detail_screen.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart' show SplitMember;
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../../screens/history/history_test_harness.dart';
import '../../layout_matrix.dart';

Widget _de(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: Builder(
    builder: (context) => Localizations.override(
      context: context,
      locale: const Locale('de'),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: child,
    ),
  ),
);

Future<void> Function(WidgetTester) _shows(String text) => (tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  expect(find.textContaining(text, skipOffstage: false), findsWidgets);
};

// Long names, a trip from someone else, savings, a split and open shares.
final _trips = [
  histTrip(
    't1',
    histNow.subtract(const Duration(hours: 2)),
    cost: 1234.56,
    chain: 'netto-marken-discount',
    listName: 'Wocheneinkauf für die ganze Familie',
    items: 27,
    lines: const [
      ShoppingHistoryItem(
        id: 'i1',
        historyId: 't1',
        name: 'Gouda in Scheiben, mittelalt, laktosefrei',
        quantity: 2,
        price: 1.49,
        priceOldValue: 2.49,
        priceRetailer: 'netto-marken-discount',
      ),
      ShoppingHistoryItem(id: 'i2', historyId: 't1', name: 'Brokkoli', unit: 'kg'),
    ],
  ),
  for (var m = 1; m <= 5; m++)
    histTrip('p$m', DateTime(2026, 11 - m, 6), cost: 180.0 + 10 * m, chain: 'rewe'),
  histTrip('o1', DateTime(2026, 11, 3), user: 'lena', byName: 'Magdalena-Sophie', chain: null),
];

void main() {
  late List<Override> full;
  late List<Override> plain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    full = await HistoryWorld(
      prefs: prefs,
      trips: _trips,
      savings: true,
      lists: [histList('l1', 'Wocheneinkauf für die ganze Familie'), histList('l2', 'Grillabend')],
      shares: [
        histShare('s1', name: 'Magdalena-Sophie'),
        histShare('s2', user: null, name: 'Tom', cents: 1320),
        histShare('s3', user: 'me', name: 'Jannis', payer: 'lena', payerName: 'Magdalena-Sophie', cents: 1158),
        histShare('s4', paid: true),
      ],
      splits: {
        't1': [
          histSplit('a', user: 'me', name: 'Jannis', cents: 61728, paid: true),
          histSplit('b', user: 'lena', name: 'Magdalena-Sophie', cents: 61728, position: 1),
        ],
      },
      membersOfList: const [
        SplitMember(userId: 'me', name: 'Jannis'),
        SplitMember(userId: 'lena', name: 'Magdalena-Sophie'),
        SplitMember(userId: 'tom', name: 'Tom'),
        SplitMember(userId: 'ali', name: 'Ali'),
      ],
    ).overrides();
    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    plain = await HistoryWorld(
      prefs: prefs2,
      trips: _trips,
      shares: [histShare('s1')],
      splitModule: false,
    ).overrides();
  });

  layoutMatrix(
    'V4 Verlauf',
    (context) => _de(const HistoryScreen(), full),
    
    afterPump: _shows('Ausgaben pro Monat'),
  );
  layoutMatrix(
    'V5 Einkauf-Detail',
    (context) => _de(const TripDetailScreen(tripId: 't1'), full),
    
    afterPump: _shows('Alle wieder auf die Liste'),
  );
  layoutMatrix(
    'V6 Betrag',
    (context) => _de(const TripAmountScreen(tripId: 't1'), full),
    afterPump: _shows('Gesamtbetrag'),
  );
  layoutMatrix(
    'V7 Kosten teilen',
    (context) => _de(const SplitEditorScreen(tripId: 't1'), full),
    
    afterPump: _shows('WER TEILT'),
  );
  layoutMatrix(
    'V8 Offene Beträge',
    (context) => _de(const OpenBalancesScreen(), full),
    
    afterPump: _shows('SCHULDET DIR'),
  );
  layoutMatrix(
    'Home V9–V12',
    (context) => _de(
      const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              HomeSplitHint(),
              HomeMonthCard(),
              HomeSpendingComparison(),
              HomeRecentTrips(),
            ],
          ),
        ),
      ),
      full,
    ),
    scrollable: true,
    afterPump: _shows('Letzte Einkäufe'),
  );

  group('honesty (3.14)', () {
    testWidgets('offers hidden: no "gespart"; Kosten teilen off: no debts', (tester) async {
      for (final screen in const <Widget>[
        HistoryScreen(),
        TripDetailScreen(tripId: 't1'),
        SingleChildScrollView(
          child: Column(
            children: [HomeSplitHint(), HomeMonthCard(), HomeRecentTrips()],
          ),
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: _de(screen, plain)),
        );
        await tester.pump(const Duration(milliseconds: 600));
        for (final word in ['gespart', 'laut Händler', 'Angebot', 'schuldet', 'Anteil', 'Kosten teilen', 'bezahlt']) {
          expect(find.textContaining(word, skipOffstage: false), findsNothing, reason: '$screen: $word');
        }
      }
    });
  });
}
