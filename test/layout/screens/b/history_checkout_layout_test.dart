// Layout matrix (widths 320-440 pt, text 1.0-3.1, bold, dark, contrast) for
// V1 "Einkauf abschließen" and its B building blocks (verlauf-kosten.md
// 3.9), in German, where the texts are longest: no overflow, no clipped
// text, 44-pt targets. Each case also checks that the content rendered.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/screens/history/checkout/checkout_data.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_screen.dart';
import 'package:shoply/presentation/screens/history/widgets/amount_field.dart';
import 'package:shoply/presentation/screens/history/widgets/savings_line.dart';
import 'package:shoply/presentation/screens/history/widgets/store_choice_chips.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart' show SplitMember;
import 'package:shoply/presentation/widgets/design/inset_section.dart';

import '../../../data/services/shopping_history_service_test.dart'
    show FakeTripBackend;
import '../../../screens/history/checkout_test_harness.dart';
import '../../../screens/offers/offer_test_harness.dart' show testItem, testListId;
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

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> o({
    bool empty = false,
    CheckoutLocationAccess hint = CheckoutLocationAccess.none,
    String? preselected = 'netto-marken-discount',
    String? here = 'rewe',
  }) => checkoutOverrides(
    backend: FakeTripBackend(),
    prefs: prefs,
    items: empty
        ? checkoutItems(checked: 0)
        : [
            ...checkoutItems(checked: 9),
            testItem('o2', 'Gouda in Scheiben, mittelalt, laktosefrei'),
            testItem('o3', 'Brokkoli'),
            testItem('o4', 'Vollkorntoast'),
          ],
    preselected: preselected,
    here: here,
    hint: hint,
    members: const [
      SplitMember(userId: 'me', name: 'Jannis'),
      SplitMember(userId: 'lena', name: 'Magdalena-Sophie'),
      SplitMember(userId: 'tom', name: 'Tom'),
      SplitMember(userId: 'ali', name: 'Ali'),
    ],
  );

  layoutMatrix(
    'V1 Einkauf abschließen, voll',
    (context) => _de(
      const CheckoutScreen(listId: testListId, splitStepAvailable: true),
      o(),
    ),
    checkTapTargets: true,
    afterPump: _shows('Einkauf speichern'),
  );

  layoutMatrix(
    'V1 ohne Vorauswahl, Standort-Hinweis',
    (context) => _de(
      const CheckoutScreen(listId: testListId),
      o(preselected: null, here: null, hint: CheckoutLocationAccess.notAsked),
    ),
    afterPump: _shows('Standort verwenden'),
  );

  layoutMatrix(
    'V1 nichts im Wagen',
    (context) => _de(const CheckoutScreen(listId: testListId), o(empty: true)),
    checkTapTargets: true,
    afterPump: _shows('Noch nichts im Wagen.'),
  );

  layoutMatrix(
    'StoreChoiceChips',
    (context) => _de(
      InsetSection(
        children: [
          StoreChoiceChips(
            entries: const [
              StoreChoiceEntry('netto-marken-discount'),
              StoreChoiceEntry('aldi-sued'),
              StoreChoiceEntry('kaufland'),
              StoreChoiceEntry('rewe', here: true),
            ],
            selected: 'aldi-sued',
            onChanged: (_) {},
            onOther: () {},
          ),
        ],
      ),
      const [],
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'HistoryAmountField and notes',
    (context) => _de(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InsetSection(
            children: [
              HistoryAmountField(
                title: 'Betrag',
                placeholder: 'optional',
                languageCode: 'de',
                initialCents: 142800,
                onChanged: (_) {},
              ),
            ],
          ),
          const AmountNote(
            text: 'Gib den Betrag als Zahl ein, zum Beispiel 42,80.',
            error: true,
          ),
          const SizedBox(height: 16),
          const SavingsLine(cents: 1860),
        ],
      ),
      const [],
    ),
    scrollable: true,
    checkTapTargets: true,
    afterPump: _shows('durch Angebote gespart'),
  );
}
