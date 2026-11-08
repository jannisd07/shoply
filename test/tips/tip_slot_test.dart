import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/tips/home_tips.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

import '../layout/layout_matrix.dart';

String _en(String key) => AppTranslations.get(key, 'en');

final _today = DateTime(2026, 11, 8, 10);

Future<TipService> _attached({Map<String, Object> stored = const {}}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return TipService(clock: () => _today)..attach(prefs);
}

Future<void> _pump(
  WidgetTester tester,
  TipService service,
  Widget child,
) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tipServiceProvider.overrideWithValue(service)],
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );
}

Widget _listSlot(TipFacts facts) => TipSlot(
  place: TipPlace.list,
  facts: facts,
  wrap: (context, row) =>
      InsetSection(header: _en('tip_section_today'), children: [row]),
);

const _threeOpen = TipFacts(openItems: 3, hasCheckedItem: false, shared: false);

/// Rebuilds [build] with new facts from outside.
class _Host extends StatefulWidget {
  const _Host({required this.facts, required this.build, this.ticker});

  final ValueNotifier<TipFacts> facts;
  final ValueNotifier<bool>? ticker;
  final Widget Function(TipFacts facts) build;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.facts, ?widget.ticker]),
    builder: (context, _) => TickerMode(
      enabled: widget.ticker?.value ?? true,
      child: widget.build(widget.facts.value),
    ),
  );
}

void main() {
  group('layout', () {
    late TipService service;
    setUpAll(() async {
      service = await _attached();
      service.startArrivalTip(TipId.quantity);
    });

    layoutMatrix(
      'TipSlot "Für heute" with T1',
      (context) => ProviderScope(
        overrides: [tipServiceProvider.overrideWithValue(service)],
        child: SizedBox(
          width: double.infinity,
          child: _listSlot(const TipFacts(openItems: 0)),
        ),
      ),
    );
  });

  testWidgets('without a tip the slot takes no space', (tester) async {
    final service = await _attached();
    await _pump(tester, service, _listSlot(const TipFacts(openItems: 0)));
    expect(find.byType(TipRow), findsNothing);
    expect(find.text(_en('tip_section_today').toUpperCase()), findsNothing);
    expect(tester.getSize(find.byType(TipSlot)).height, 0);
  });

  testWidgets('an unattached service shows nothing', (tester) async {
    await _pump(tester, TipService(), _listSlot(_threeOpen));
    expect(find.byType(TipRow), findsNothing);
  });

  testWidgets(
    'T1 in "Für heute"; the first item with a quantity collapses it',
    (tester) async {
      final service = await _attached();
      service.startArrivalTip(TipId.quantity);
      final facts = ValueNotifier(const TipFacts(openItems: 0));
      await _pump(tester, service, _Host(facts: facts, build: _listSlot));
      expect(find.text(_en('tip_t1')), findsOneWidget);
      expect(find.text('FOR TODAY'), findsOneWidget);

      facts.value = const TipFacts(openItems: 1, hasItemWithQuantity: true);
      await tester.pump();
      await tester.pump();
      // Still there while it collapses.
      expect(find.text(_en('tip_t1')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(_en('tip_t1')), findsNothing);
      expect(find.text('FOR TODAY'), findsNothing);
      expect(service.isFinished(TipId.quantity), isTrue);
    },
  );

  testWidgets('what shows is fixed at the first frame', (tester) async {
    final service = await _attached();
    final facts = ValueNotifier(
      const TipFacts(openItems: 2, hasCheckedItem: false, shared: false),
    );
    await _pump(tester, service, _Host(facts: facts, build: _listSlot));
    expect(find.byType(TipRow), findsNothing);
    // A third item while the list is open: T2 waits for the next visit.
    facts.value = _threeOpen;
    await tester.pump();
    expect(find.byType(TipRow), findsNothing);
    expect(service.active, isNull);
  });

  testWidgets('coming back to the screen is a new visit', (tester) async {
    final service = await _attached();
    final facts = ValueNotifier(
      const TipFacts(openItems: 2, hasCheckedItem: false, shared: false),
    );
    final ticker = ValueNotifier(true);
    await _pump(
      tester,
      service,
      _Host(facts: facts, ticker: ticker, build: _listSlot),
    );
    expect(find.byType(TipRow), findsNothing);
    facts.value = _threeOpen;
    ticker.value = false; // another tab, a pushed screen
    await tester.pump();
    ticker.value = true;
    await tester.pump();
    expect(find.text(_en('tip_t2')), findsOneWidget);
  });

  testWidgets('swiping it away finishes the tip and collapses the row', (
    tester,
  ) async {
    final service = await _attached();
    await _pump(tester, service, _listSlot(_threeOpen));
    expect(find.text(_en('tip_t2')), findsOneWidget);
    await tester.drag(find.byType(TipRow), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(TipRow), findsNothing);
    expect(service.isFinished(TipId.shoppingMode), isTrue);
  });

  testWidgets('a done event from elsewhere (Teil B) removes the row', (
    tester,
  ) async {
    final service = await _attached();
    await _pump(
      tester,
      service,
      TipSlot(place: TipPlace.plan, facts: const TipFacts()),
    );
    expect(find.text(_en('tip_t9')), findsOneWidget);
    service.markDone(TipId.mealPlan);
    await tester.pumpAndSettle();
    expect(find.byType(TipRow), findsNothing);
  });

  testWidgets('Reduce Motion: the row fades instead of collapsing', (
    tester,
  ) async {
    final service = await _attached();
    await loadLayoutFonts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tipServiceProvider.overrideWithValue(service)],
        child: layoutHarness(
          const LayoutCase(width: 390, scale: 1, reduceMotion: true),
          Align(
            alignment: Alignment.topCenter,
            child: TipSlot(place: TipPlace.plan, facts: const TipFacts()),
          ),
        ),
      ),
    );
    expect(find.byType(SizeTransition), findsNothing);
    service.markDone(TipId.mealPlan);
    await tester.pumpAndSettle();
    expect(find.byType(TipRow), findsNothing);
  });

  testWidgets('T7 shows "Set up" and runs the action', (tester) async {
    final service = await _attached();
    service
      ..visit(TipPlace.recipes)
      ..visit(TipPlace.recipes);
    final acted = <TipId>[];
    await _pump(
      tester,
      service,
      TipSlot(
        place: TipPlace.recipes,
        only: const {TipId.diet},
        facts: const TipFacts(dietSet: false),
        onAction: (context, tip) => acted.add(tip),
      ),
    );
    expect(find.text(_en('tip_t7')), findsOneWidget);
    await tester.tap(find.text(_en('tip_t7_action')));
    expect(acted, [TipId.diet]);
  });

  testWidgets('builder: gets the tip and a way to hide it', (tester) async {
    final service = await _attached();
    await _pump(
      tester,
      service,
      TipSlot.builder(
        place: TipPlace.recipes,
        facts: const TipFacts(),
        builder: (context, tip, hide) => tip == null
            ? const Text('none')
            : GestureDetector(onTap: hide, child: Text('tip ${tip.id}')),
      ),
    );
    expect(find.text('tip t6'), findsOneWidget);
    await tester.tap(find.text('tip t6'));
    await tester.pump();
    await tester.pump();
    expect(find.text('none'), findsOneWidget);
    expect(service.isFinished(TipId.recipeToList), isTrue);
  });

  group('Home', () {
    test('room for a tip next to at most one other hint row (K-38)', () {
      expect(homeTipAllowed(savingsHint: false, cookToday: false), isTrue);
      expect(homeTipAllowed(savingsHint: true, cookToday: false), isTrue);
      expect(homeTipAllowed(savingsHint: false, cookToday: true), isTrue);
      expect(homeTipAllowed(savingsHint: true, cookToday: true), isFalse);
    });

    test('facts from the lists: fullest list, any shared', () {
      ShoppingListModel list(String id, int open, {bool shared = false}) =>
          ShoppingListModel(
            id: id,
            name: id,
            ownerId: 'u1',
            isShared: shared,
            uncheckedCount: open,
            createdAt: _today,
            updatedAt: _today,
          );
      expect(homeTipFacts(null).ready, isFalse);
      final facts = homeTipFacts([list('a', 2), list('b', 5, shared: true)]);
      expect(facts.ready, isTrue);
      expect(facts.openItems, 5);
      expect(facts.shared, isTrue);
    });

    testWidgets('the host decides once; the section draws the same tip', (
      tester,
    ) async {
      final service = await _attached();
      final visit = TipVisit(TipPlace.home);
      TipId? decided;
      await _pump(
        tester,
        service,
        Builder(
          builder: (context) {
            decided = visit.resolve(context, service, _threeOpen);
            return decided == null
                ? const SizedBox.shrink()
                : HomeTipSection(visit: visit, facts: _threeOpen);
          },
        ),
      );
      expect(decided, TipId.shoppingMode);
      expect(find.text(_en('tip_t2')), findsOneWidget);
    });

    testWidgets('no room (two hint rows): no tip, and none used up', (
      tester,
    ) async {
      final service = await _attached();
      final visit = TipVisit(TipPlace.home);
      await _pump(
        tester,
        service,
        Builder(
          builder: (context) {
            final tip = visit.resolve(
              context,
              service,
              _threeOpen,
              allowed: false,
            );
            return Text(tip?.id ?? 'none');
          },
        ),
      );
      expect(find.text('none'), findsOneWidget);
      expect(service.active, isNull);
      expect(service.isFinished(TipId.shoppingMode), isFalse);
    });
  });
}
