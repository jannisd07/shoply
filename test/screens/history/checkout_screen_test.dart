// V1 "Einkauf abschließen" and V3 (verlauf-kosten.md): states, the save
// chain with the success moment and "Widerrufen", and semantics.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/screens/history/checkout/checkout_data.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_screen.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../data/services/shopping_history_service_test.dart'
    show FakeTripBackend;
import '../../state/trip_history_provider_test.dart' show SlowBackend;
import '../offers/offer_test_harness.dart' show testListId;
import 'checkout_test_harness.dart';

const _members = [
  SplitMember(userId: 'me', name: 'Jannis'),
  SplitMember(userId: 'lena', name: 'Lena'),
];

/// Frames for [seconds], so springs and timers both run.
Future<void> pumpFor(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 10).round(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows the cart, the preselected market and the savings', (
    tester,
  ) async {
    final backend = FakeTripBackend();
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: backend, prefs: prefs),
    );
    await openV1(tester);

    expect(find.text('Einkauf abschließen'), findsOneWidget);
    expect(find.text('2 Artikel im Wagen'), findsOneWidget);
    expect(find.text('1 bleibt auf Wocheneinkauf: Gurken'), findsOneWidget);
    expect(find.text('Lidl'), findsOneWidget);
    expect(find.text('REWE'), findsOneWidget, reason: 'a favourite market');
    expect(find.text('Anderer Markt …'), findsOneWidget);
    expect(find.text('Markt dieser Liste'), findsOneWidget);
    expect(
      find.text('Ca. 3,20 € durch Angebote gespart, laut Händler'),
      findsOneWidget,
    );
    expect(find.text('Einkauf speichern'), findsOneWidget);
    expect(find.text('Kosten teilen'), findsNothing, reason: 'only me');

    // Another market: the offers did not count there.
    await tester.tap(find.text('REWE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('durch Angebote gespart'), findsNothing);
  });

  testWidgets('saving closes V1, shows V3 and offers "Widerrufen"', (
    tester,
  ) async {
    final backend = FakeTripBackend();
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: backend, prefs: prefs),
    );
    await openV1(tester);

    await tester.enterText(find.byType(EditableText), '42,8');
    await tester.tap(find.text('Einkauf speichern'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Einkauf gespeichert.'), findsOneWidget);
    expect(
      find.text(
        '2 Artikel bei Lidl · ca. 3,20 € durch Angebote gespart, laut Händler',
      ),
      findsOneWidget,
    );
    final call = backend.rpcCalls.single;
    expect(call['items'], ['c0', 'c1']);
    expect(call['chain'], 'lidl');
    expect(call['cost'], 42.8);

    await pumpFor(tester, 2.5); // the moment ends
    expect(CheckoutLaunch.result, isTrue);
    expect(find.text('Einkauf gespeichert'), findsOneWidget);

    await tester.tap(find.text('Widerrufen'));
    await pumpFor(tester, 0.5);
    expect(backend.undoCalls.single, ('trip-1', 'tok'));
    expect(
      find.text('Einkauf widerrufen. Die Artikel sind wieder abgehakt.'),
      findsOneWidget,
    );
    await pumpFor(tester, 12);
  });

  testWidgets('closing without changes returns false at once', (tester) async {
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: FakeTripBackend(), prefs: prefs),
    );
    await openV1(tester);
    await tester.tap(find.bySemanticsLabel('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(CheckoutLaunch.result, isFalse);
  });

  testWidgets('a typed amount asks before closing', (tester) async {
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: FakeTripBackend(), prefs: prefs),
    );
    await openV1(tester);
    await tester.enterText(find.byType(EditableText), '12');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
  });

  testWidgets('an invalid amount says why and dims the capsule', (
    tester,
  ) async {
    final backend = FakeTripBackend();
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: backend, prefs: prefs),
    );
    await openV1(tester);
    await tester.enterText(find.byType(EditableText), '4,567');
    await tester.pump();
    expect(
      find.text('Gib den Betrag als Zahl ein, zum Beispiel 42,80.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Einkauf speichern'));
    await tester.pumpAndSettle();
    expect(backend.rpcCalls, isEmpty);

    await tester.enterText(find.byType(EditableText), '1428');
    await tester.pump();
    expect(find.text('Stimmt der Betrag? 1.428,00 €'), findsOneWidget);
  });

  testWidgets('nothing checked: no trip, back to the list', (tester) async {
    final backend = FakeTripBackend();
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(
        backend: backend,
        prefs: prefs,
        items: checkoutItems(checked: 0),
      ),
    );
    await openV1(tester);
    expect(find.text('Noch nichts im Wagen.'), findsOneWidget);
    await tester.tap(find.text('Zurück zur Liste'));
    await tester.pumpAndSettle();
    expect(CheckoutLaunch.result, isFalse);
    expect(backend.rpcCalls, isEmpty);
  });

  testWidgets('a member who was faster: V1 stays open and says so', (
    tester,
  ) async {
    final backend = FakeTripBackend(
      answer: {
        'status': 'already_completed',
        'trip_id': 'lena-trip',
        'completed_by_name': 'Lena',
      },
    );
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: backend, prefs: prefs),
    );
    await openV1(tester);
    await tester.tap(find.text('Einkauf speichern'));
    await tester.pumpAndSettle();
    expect(
      find.text('Lena hat diesen Einkauf gerade abgeschlossen.'),
      findsOneWidget,
    );
    expect(find.text('Zurück zur Liste'), findsOneWidget);
    await tester.tap(find.text('Zum Verlauf'));
    await tester.pumpAndSettle();
    expect(find.text('Verlauf'), findsOneWidget);
  });

  testWidgets('the list was deleted meanwhile', (tester) async {
    final backend = FakeTripBackend(answer: {'status': 'list_gone'});
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: backend, prefs: prefs),
    );
    await openV1(tester);
    await tester.tap(find.text('Einkauf speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Diese Liste gibt es nicht mehr.'), findsOneWidget);
    await tester.tap(find.text('Zu den Listen'));
    await tester.pumpAndSettle();
    expect(find.text('Listen'), findsOneWidget);
  });

  testWidgets('offline it closes at once; the trip waits with the sync mark', (
    tester,
  ) async {
    final backend = SlowBackend();
    late ProviderContainer container;
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(
        backend: backend,
        prefs: prefs,
        offline: true,
      ),
    );
    await openV1(tester);
    container = ProviderScope.containerOf(
      tester.element(find.text('Einkauf abschließen')),
    );
    await tester.tap(find.text('Einkauf speichern'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Einkauf gespeichert.'), findsOneWidget);
    final state = container.read(tripHistoryProvider);
    expect(state.sending, hasLength(1));
    expect(isLocalTripId(state.trips.first.id), isTrue);
    backend.gate.complete();
    await pumpFor(tester, 15);
    expect(container.read(tripHistoryProvider).trips.first.id, 'trip-1');
  });

  testWidgets('a server error keeps V1 open with "Nicht gespeichert"', (
    tester,
  ) async {
    final backend = FakeTripBackend()..rpcError = Exception('500');
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: backend, prefs: prefs),
    );
    await openV1(tester);
    await tester.tap(find.text('Einkauf speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Nicht gespeichert'), findsOneWidget);
    expect(find.text('Einkauf abschließen'), findsOneWidget);
  });

  group('Kosten teilen (V1 group 5)', () {
    Widget screen(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('de'),
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) => AvoToastHost(child: child!),
        home: const CheckoutScreen(
          listId: testListId,
          splitStepAvailable: true,
        ),
      ),
    );

    testWidgets('with a member: the switch names them', (tester) async {
      await tester.pumpWidget(
        screen(
          checkoutOverrides(
            backend: FakeTripBackend(),
            prefs: prefs,
            members: _members,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kosten teilen'), findsOneWidget);
      expect(
        find.text('Mit Lena. Danach legst du die Anteile fest.'),
        findsOneWidget,
      );
      expect(
        find.text('Für deinen Monatsrückblick und zum Teilen.'),
        findsOneWidget,
      );
    });

    testWidgets('module off: no switch, no gap, the plain note', (
      tester,
    ) async {
      await tester.pumpWidget(
        screen(
          checkoutOverrides(
            backend: FakeTripBackend(),
            prefs: prefs,
            members: _members,
            splitModule: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kosten teilen'), findsNothing);
      expect(find.text('Für deinen Monatsrückblick.'), findsOneWidget);
    });

    testWidgets('starts on when the last trip of this list was split', (
      tester,
    ) async {
      await prefs.setBool('hist_split_last_v1_$testListId', true);
      await tester.pumpWidget(
        screen(
          checkoutOverrides(
            backend: FakeTripBackend(),
            prefs: prefs,
            members: _members,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Kosten teilen')).first),
        isSemantics(isToggled: true),
      );
      handle.dispose();
    });
  });

  testWidgets('without a preselection the store "here" is chosen', (
    tester,
  ) async {
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(
        backend: FakeTripBackend(),
        prefs: prefs,
        preselected: null,
        here: 'rewe',
      ),
    );
    await openV1(tester);
    expect(find.text('REWE (hier)'), findsOneWidget);
    expect(find.text('Erkannt über deinen Standort'), findsOneWidget);
  });

  testWidgets('the location hint shows once and never asks on open', (
    tester,
  ) async {
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(
        backend: FakeTripBackend(),
        prefs: prefs,
        preselected: null,
        hint: CheckoutLocationAccess.notAsked,
      ),
    );
    await openV1(tester);
    expect(find.text('Standort verwenden'), findsOneWidget);
    expect(prefs.getBool('hist_checkout_location_hint_v1'), isTrue);
    await tester.tap(find.text('Standort verwenden'));
    await tester.pumpAndSettle();
    expect(find.text('Markt per Standort erkennen?'), findsOneWidget);
    await tester.tap(find.text('Nicht jetzt'));
    await tester.pumpAndSettle();
  });

  testWidgets('semantics: summary sentence and the chip group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCheckout(
      tester,
      overrides: checkoutOverrides(backend: FakeTripBackend(), prefs: prefs),
    );
    await openV1(tester);
    expect(
      find.bySemanticsLabel(
        '2 Artikel im Wagen. 1 bleibt auf Wocheneinkauf: Gurken.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Wo warst du?'), findsWidgets);
    expect(
      find.bySemanticsLabel(
        'Circa 3,20 Euro durch Angebote gespart, laut Händler',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
