// W11 (B8b): V4 Verlauf, V5 Einkauf-Detail, V6 Betrag, V7 Kosten teilen,
// V8 Offene Beträge, with their states (verlauf-kosten.md V4–V8, V13).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart' show SplitMember;
import 'package:shoply/routes/areas/history_routes.dart';

import '../offers/offer_test_harness.dart' show testItem;
import 'history_test_harness.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final trips = [
    histTrip('t1', histNow.subtract(const Duration(hours: 2)), cost: 42.80),
    histTrip('t2', DateTime(2026, 11, 4, 18), cost: 23.10, chain: 'rewe'),
    histTrip(
      't3',
      DateTime(2026, 10, 20, 10),
      user: 'lena',
      byName: 'Lena',
      list: 'l2',
      listName: 'Grillabend',
      chain: null,
    ),
  ];

  group('routes', () {
    test('V5, V6 and V7 are registered, so V1 offers the split step', () {
      expect(historyChildRouteRegistered(historyTripChildPath), isTrue);
      expect(historyChildRouteRegistered(historySplitChildPath), isTrue);
      expect(historyChildRouteRegistered(historyAmountChildPath), isTrue);
      expect(historyLocation(listId: 'l1'), '/history?list=l1');
      expect(splitsLocation(done: true), '/splits?done=1');
      expect(historyLocation(tripGone: true), '/history?gone=1');
    });
  });

  group('V4 Verlauf', () {
    testWidgets('month card, months as sections, rows with market first', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final world = HistoryWorld(prefs: prefs, trips: trips, lists: [histList('l1', 'Wocheneinkauf')]);
      await pumpHistory(tester, '/history', await world.overrides());
      expect(find.text('Verlauf'), findsWidgets);
      expect(find.text('November, bisher'), findsOneWidget);
      // Only typed amounts count: 42,80 + 23,10.
      expect(find.text('NOVEMBER'), findsOneWidget);
      expect(find.text('OKTOBER'), findsOneWidget);
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.text('42,80\u00a0€'), findsOneWidget);
      expect(
        find.text('Wocheneinkauf · Heute, 10:00 · 3 Artikel'),
        findsOneWidget,
      );
      // Someone else's trip says who.
      expect(find.textContaining('von Lena'), findsOneWidget);
      // No savings anywhere with offers hidden.
      expect(find.textContaining('gespart'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'^Lidl, Wocheneinkauf, heute')),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Lidl, Wocheneinkauf, Heute, 10:00, 3 Artikel, 42,80 Euro')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a debt line only with the module and an open share', (tester) async {
      Future<void> pump({required bool module}) async {
        final world = HistoryWorld(
          prefs: prefs,
          trips: trips,
          shares: [histShare('s1')],
          splitModule: module,
        );
        await pumpHistory(tester, '/history', await world.overrides());
      }

      await pump(module: true);
      expect(find.text('Lena schuldet dir 21,40\u00a0€'), findsOneWidget);
      await pump(module: false);
      expect(find.textContaining('schuldet'), findsNothing);
    });

    testWidgets('savings show as "ca. … gespart" with offers on', (tester) async {
      final saved = histTrip(
        't1',
        histNow,
        cost: 20,
        lines: const [
          ShoppingHistoryItem(
            id: 'i',
            historyId: 't1',
            name: 'Butter',
            price: 1.49,
            priceOldValue: 2.49,
            priceRetailer: 'lidl',
          ),
        ],
      );
      final world = HistoryWorld(prefs: prefs, trips: [saved], savings: true);
      await pumpHistory(tester, '/history', await world.overrides());
      expect(find.text('ca. 1,00\u00a0€ gespart'), findsOneWidget);
      expect(
        find.text('Ca. 1,00\u00a0€ durch Angebote gespart, laut Händler'),
        findsOneWidget,
      );
    });

    testWidgets('empty: the waving figure and "Zu den Listen"', (tester) async {
      final world = HistoryWorld(prefs: prefs);
      await pumpHistory(tester, '/history', await world.overrides());
      expect(find.text('Noch keine Einkäufe.'), findsOneWidget);
      await tester.tap(find.text('Zu den Listen'));
      await tester.pumpAndSettle();
      expect(find.text('Listen'), findsOneWidget);
    });

    testWidgets('first load without state: a skeleton, then the error', (tester) async {
      final handle = tester.ensureSemantics();
      final world = HistoryWorld(prefs: prefs, synced: false);
      await pumpHistory(tester, '/history', await world.overrides());
      expect(find.bySemanticsLabel('Wird geladen'), findsWidgets);
      await tester.pump(historyFirstLoadTimeoutForTest);
      await tester.pumpAndSettle();
      expect(find.text('Deine Einkäufe konnten nicht geladen werden.'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a failed refresh keeps the rows and says so', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips, failRefresh: true);
      await pumpHistory(tester, '/history', await world.overrides());
      expect(find.text('Der Verlauf konnte nicht aktualisiert werden.'), findsOneWidget);
      expect(find.text('Lidl'), findsOneWidget);
    });

    testWidgets('offline with state', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips, offline: true);
      await pumpHistory(tester, '/history', await world.overrides());
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Offline. Neue Einkäufe erscheinen, sobald du wieder online bist.'),
        findsOneWidget,
      );
    });

    testWidgets('filter by list: meta line, only that list, "Alle"', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      await pumpHistory(tester, '/history?list=l2', await world.overrides());
      expect(find.text('Nur Grillabend'), findsOneWidget);
      expect(find.text('Grillabend'), findsOneWidget); // t3 without market
      expect(find.text('REWE'), findsNothing);
      await tester.tap(find.text('Alle'));
      await tester.pumpAndSettle();
      expect(find.text('REWE'), findsOneWidget);
    });

    testWidgets('delete asks with the case text and removes the row', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: trips,
        lists: [histList('l1', 'Wocheneinkauf', shared: false)],
      );
      await pumpHistory(tester, '/history', await world.overrides());
      await tester.longPress(find.text('42,80\u00a0€'));
      await tester.pumpAndSettle();
      expect(find.text('Alle wieder auf die Liste'), findsOneWidget);
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Einkauf vom 9. Nov. löschen?'), findsOneWidget);
      expect(
        find.text(
          'Der Einkauf verschwindet aus deinem Verlauf und dem Monatsrückblick. '
          'Das lässt sich nicht rückgängig machen.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Einkauf löschen'));
      await tester.pumpAndSettle();
      expect(world.tripBackend.deleted, ['t1']);
      expect(find.text('42,80\u00a0€'), findsNothing);
    });

    testWidgets('someone else\'s trip has no delete', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: [trips[2]]);
      await pumpHistory(tester, '/history', await world.overrides());
      await tester.longPress(find.text('Grillabend'));
      await tester.pumpAndSettle();
      expect(find.text('Löschen'), findsNothing);
      expect(find.text('Betrag eintragen'), findsNothing);
    });
  });

  group('V5 Einkauf-Detail', () {
    testWidgets('head, re-add with the target, items', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: trips,
        lists: [histList('l1', 'Wocheneinkauf')],
        open: [testItem('o', 'Milch')],
      );
      await pumpHistory(tester, '/history/t1', await world.overrides());
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.text('Eingekauft von dir'), findsOneWidget);
      expect(find.text('42,80\u00a0€'), findsOneWidget);
      expect(find.text('Auf Wocheneinkauf. 1 Artikel steht dort schon.'), findsOneWidget);
      expect(find.text('Steht auf Wocheneinkauf'), findsOneWidget);
      await tester.tap(find.text('Alle wieder auf die Liste'));
      await tester.pumpAndSettle();
      // Milch is open there already: only Brot is added, without merging.
      expect(world.repo.added.single.$1, 'l1');
      expect([for (final i in world.repo.added.single.$2) i.name], ['Brot']);
      expect(find.text('1 Artikel auf Wocheneinkauf'), findsOneWidget);
    });

    testWidgets('split section: rows, "Bezahlt" and the footer', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: trips,
        splits: {
          't1': [
            histSplit('a', user: 'me', name: 'Jannis', cents: 2140, paid: true),
            histSplit('b', user: 'lena', name: 'Lena', cents: 2140, position: 1),
          ],
        },
      );
      await pumpHistory(tester, '/history/t1', await world.overrides());
      expect(find.text('KOSTEN TEILEN'), findsOneWidget);
      expect(find.text('Lena'), findsOneWidget);
      expect(find.text('offen'), findsOneWidget);
      expect(find.text('Bezahlt von dir · 42,80\u00a0€ · gleich aufgeteilt'), findsOneWidget);
      await tester.tap(find.text('Bezahlt'));
      await tester.pumpAndSettle();
      expect(find.text('Lena: bezahlt'), findsOneWidget);
    });

    testWidgets('without a split: "Kosten teilen · Mit Lena"; module off: nothing', (tester) async {
      var world = HistoryWorld(prefs: prefs, trips: trips);
      await pumpHistory(tester, '/history/t1', await world.overrides());
      expect(find.text('Mit Lena'), findsOneWidget);
      world = HistoryWorld(prefs: prefs, trips: trips, splitModule: false);
      await pumpHistory(tester, '/history/t1', await world.overrides());
      expect(find.text('Kosten teilen'), findsNothing);
      expect(find.text('Mit Lena'), findsNothing);
    });

    testWidgets('someone else\'s trip: "Eingekauft von Lena", no amount button', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      await pumpHistory(tester, '/history/t3', await world.overrides());
      expect(find.text('Eingekauft von Lena'), findsOneWidget);
      expect(find.text('Betrag eintragen'), findsNothing);
    });

    testWidgets('an unknown trip goes to the history with a toast', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      await pumpHistory(tester, '/history/gone', await world.overrides());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dieser Einkauf wurde gelöscht.'), findsOneWidget);
      expect(find.text('NOVEMBER'), findsOneWidget);
    });
  });

  group('I4 unknown trip', () {
    for (final path in ['/history/gone/amount', '/history/gone/split']) {
      testWidgets('$path: to the history with the toast', (tester) async {
        final world = HistoryWorld(prefs: prefs, trips: trips);
        final router = await pumpHistory(tester, path, await world.overrides());
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Dieser Einkauf wurde gelöscht.'), findsOneWidget);
        expect(find.text('NOVEMBER'), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.toString(), '/history?gone=1');
      });
    }

    testWidgets('opened from V4: back on V4 (not a blank page), toast once', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      final router = await pumpHistory(tester, '/history', await world.overrides());
      unawaited(router.push('/history/gone'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dieser Einkauf wurde gelöscht.'), findsOneWidget);
      expect(find.text('NOVEMBER'), findsOneWidget);
    });
  });

  group('V6 Betrag', () {
    testWidgets('saves the typed amount and closes with undo', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historyAmountLocation('t1'));
      await tester.pumpAndSettle();
      expect(find.text('Gesamtbetrag'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '50,5');
      await tester.pump();
      await tester.tap(find.text('Betrag speichern'));
      await tester.pumpAndSettle();
      expect(world.tripBackend.amountCalls.single, ('t1', 50.5));
      expect(find.text('50,50\u00a0€'), findsOneWidget);
      expect(find.text('Betrag gespeichert'), findsOneWidget);
    });

    testWidgets('an invalid amount says so and keeps save off', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historyAmountLocation('t1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '4,2,1');
      await tester.pump();
      expect(find.text('Gib den Betrag als Zahl ein, zum Beispiel 42,80.'), findsOneWidget);
      await tester.tap(find.text('Betrag speichern'));
      await tester.pumpAndSettle();
      expect(world.tripBackend.amountCalls, isEmpty);
    });
  });

  group('V7 Kosten teilen', () {
    testWidgets('equal: the rest cent goes to the first person', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: [histTrip('t1', histNow, cost: 10)],
        membersOfList: const [
          SplitMember(userId: 'me', name: 'Jannis'),
          SplitMember(userId: 'lena', name: 'Lena'),
          SplitMember(userId: 'tom', name: 'Tom'),
        ],
      );
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historySplitLocation('t1'));
      await tester.pumpAndSettle();
      expect(find.text('WER TEILT?'), findsOneWidget);
      expect(find.text('3,34\u00a0€'), findsOneWidget);
      expect(find.text('3,33\u00a0€'), findsNWidgets(2));
      expect(
        find.text('3,34\u00a0€ und 2 × 3,33\u00a0€. Der Restcent geht an die erste Person.'),
        findsOneWidget,
      );
      expect(find.text('hat bezahlt'), findsOneWidget);
    });

    testWidgets('fewer than two people: save off with the reason', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: [histTrip('t1', histNow, cost: 10)],
      );
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historySplitLocation('t1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lena'));
      await tester.pump();
      expect(find.text('Wähl mindestens zwei Personen aus.'), findsOneWidget);
    });

    testWidgets('custom: "Noch … zu verteilen" until it adds up', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: [histTrip('t1', histNow, cost: 10)],
      );
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historySplitLocation('t1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Individuell'));
      await tester.pumpAndSettle();
      expect(find.text('Verteilt: 10,00\u00a0€ von 10,00\u00a0€'), findsOneWidget);
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      expect(find.text('Noch 3,00\u00a0€ zu verteilen'), findsOneWidget);
    });

    testWidgets('a name-only person is added; a duplicate is refused', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: [histTrip('t1', histNow, cost: 10)],
      );
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historySplitLocation('t1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Person hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Lena');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Lena ist schon dabei.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'Tom');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('ohne Konto'), findsOneWidget);
      expect(find.text('3,34\u00a0€'), findsOneWidget);
    });

    testWidgets('I3: undo of a first split restores the amount; a refusal says so', (tester) async {
      for (final refuse in [false, true]) {
        SharedPreferences.setMockInitialValues({});
        final world = HistoryWorld(
          prefs: await SharedPreferences.getInstance(),
          trips: [histTrip('t1', histNow, cost: 10)],
        );
        if (refuse) {
          world.splitBackend.clearError = Exception('42501');
        }
        final router = await pumpHistory(tester, '/history/t1', await world.overrides());
        router.push(historySplitLocation('t1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aufteilung speichern'));
        await tester.pumpAndSettle();
        expect(find.text('Aufteilung gespeichert'), findsOneWidget);
        await tester.tap(find.text('Widerrufen'));
        await tester.pumpAndSettle();
        expect(world.splitBackend.log, contains('clear 10.0'));
        expect(
          find.text('Widerrufen hat nicht geklappt.'),
          refuse ? findsOneWidget : findsNothing,
        );
        if (refuse) expect(find.text('Erneut versuchen'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('module off: the alert comes first', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: [histTrip('t1', histNow, cost: 10)],
        splitModule: false,
      );
      final router = await pumpHistory(tester, '/history/t1', await world.overrides());
      router.push(historySplitLocation('t1'));
      await tester.pumpAndSettle();
      expect(find.text('Nicht jetzt'), findsOneWidget);
    });
  });

  group('V8 Offene Beträge', () {
    testWidgets('both directions with sums, "Erledigt" folded', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: trips,
        shares: [
          histShare('s1'),
          histShare('s2', user: null, name: 'Tom', cents: 1320),
          histShare('s3', user: 'me', name: 'Jannis', payer: 'lena', payerName: 'Lena', cents: 1158),
          histShare('s4', paid: true),
        ],
      );
      await pumpHistory(tester, '/splits', await world.overrides());
      expect(find.text('Offene Beträge'), findsWidgets);
      expect(find.text('SCHULDET DIR'), findsOneWidget);
      expect(find.text('34,60\u00a0€'), findsOneWidget);
      expect(find.text('DU SCHULDEST'), findsOneWidget);
      expect(find.text('Zurückgezahlt'), findsOneWidget);
      expect(find.textContaining('ohne Konto'), findsOneWidget);
      expect(find.text('Erledigt (1)'), findsOneWidget);
      await tester.tap(find.text('Bezahlt').first);
      await tester.pumpAndSettle();
      expect(find.text('Erledigt (2)'), findsOneWidget);
      expect(find.text('Lena: bezahlt'), findsOneWidget);
    });

    testWidgets('empty: settled, no figure, "Zum Verlauf"', (tester) async {
      final world = HistoryWorld(prefs: prefs, trips: trips);
      await pumpHistory(tester, '/splits', await world.overrides());
      expect(find.text('Alles beglichen.'), findsOneWidget);
      expect(find.text('Zum Verlauf'), findsOneWidget);
    });

    testWidgets('a missing name reads "Ein Mitglied"', (tester) async {
      final world = HistoryWorld(
        prefs: prefs,
        trips: trips,
        shares: [histShare('s1', name: '')],
      );
      await pumpHistory(tester, '/splits', await world.overrides());
      expect(find.text('Ein Mitglied'), findsOneWidget);
    });
  });

  group('history_format', () {
    test('dates: today, yesterday, a weekday, the year only when another', () {
      String d(DateTime t) => tripDate(
        t,
        'de',
        histNow,
        today: 'Heute, {time}',
        yesterday: 'Gestern, {time}',
      );
      expect(d(DateTime(2026, 11, 9, 18, 40)), 'Heute, 18:40');
      expect(d(DateTime(2026, 11, 8, 19, 5)), 'Gestern, 19:05');
      expect(d(DateTime(2026, 11, 4)), 'Mi., 4. Nov.');
      expect(d(DateTime(2025, 11, 3)), 'Mo., 3. Nov. 2025');
      expect(shortDate(DateTime(2026, 11, 4), 'en', histNow), 'Wed, Nov 4');
    });

    test('a month sums only typed amounts; comparison needs 80 %', () {
      final list = [
        histTrip('a', DateTime(2026, 10, 2), cost: 100),
        histTrip('b', DateTime(2026, 10, 3), cost: 50),
        histTrip('c', DateTime(2026, 9, 3), cost: 160.80),
        histTrip('d', DateTime(2026, 9, 9)),
      ];
      final oct = summarizeMonth(list, DateTime(2026, 10));
      final sep = summarizeMonth(list, DateTime(2026, 9));
      expect(oct.spendCents, 15000);
      expect(oct.fullyCovered, isTrue);
      expect(sep.tripsWithAmount, 1);
      expect(sep.wellCovered, isFalse);
      expect(monthDifference(oct, sep), isNull);
      expect(chartShowsSpending(sixMonths(list, histNow)), isFalse);
    });

    test('the usual weekday needs 6 trips and a clear lead', () {
      final sat = [
        for (var i = 0; i < 6; i++)
          histTrip('s$i', DateTime(2026, 10, 3 + 7 * i)),
      ];
      expect(usualWeekday(sat, histNow), DateTime.saturday);
      expect(usualWeekday(sat.take(5), histNow), isNull);
    });
  });
}

/// A bit more than the 10 s of [historyFirstLoadTimeout].
const Duration historyFirstLoadTimeoutForTest = Duration(seconds: 11);
