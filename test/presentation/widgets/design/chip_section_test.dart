import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/widgets/design/chip_section.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';

import '../../../layout/layout_matrix.dart';

const _allergies = [
  'Gluten',
  'Milch',
  'Laktose',
  'Eier',
  'Erdnüsse',
  'Schalenfrüchte (Nüsse)',
  'Soja',
  'Fisch',
  'Krebstiere',
  'Weichtiere',
  'Sellerie',
  'Senf',
  'Sesam',
  'Sulfite',
  'Lupinen',
];

Widget _section({VoidCallback? onMore, String? highlightId}) => ChipSection(
  header: 'Allergien und Unverträglichkeiten',
  footer:
      'Hinweise auf Allergene helfen, ersetzen aber nicht den Blick auf die Zutatenliste.',
  moreLabel: 'Weitere anzeigen',
  onMore: onMore,
  highlightId: highlightId,
  chips: [
    for (final a in _allergies)
      AppFilterChip(label: a, selected: a == 'Erdnüsse', onSelected: (_) {}),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      const LayoutCase(width: 390, scale: 1),
      SingleChildScrollView(child: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  layoutMatrix(
    'ChipSection with 15 allergies',
    (_) => _section(onMore: () {}),
    scrollable: true,
  );

  testWidgets('shows heading, chips, footer and "Weitere anzeigen"', (
    tester,
  ) async {
    var more = 0;
    await _pump(tester, _section(onMore: () => more++));
    expect(find.text('ALLERGIEN UND UNVERTRÄGLICHKEITEN'), findsOneWidget);
    expect(find.byType(AppFilterChip), findsNWidgets(15));
    expect(find.textContaining('Zutatenliste'), findsOneWidget);
    await tester.tap(find.text('Weitere anzeigen'));
    expect(more, 1);
  });

  testWidgets('chips wrap into lines and never scroll sideways', (
    tester,
  ) async {
    await _pump(tester, _section());
    expect(find.text('Weitere anzeigen'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ChipSection),
        matching: find.byType(Wrap),
      ),
      findsOneWidget,
    );
    final first = tester.getTopLeft(find.text('Gluten'));
    final last = tester.getTopLeft(find.text('Lupinen'));
    expect(last.dy, greaterThan(first.dy));
    for (final a in _allergies) {
      final rect = tester.getRect(find.text(a));
      expect(rect.right, lessThanOrEqualTo(390));
    }
  });

  testWidgets('no chips render nothing', (tester) async {
    await _pump(tester, const ChipSection(header: 'Leer', chips: []));
    expect(find.text('LEER'), findsNothing);
  });

  testWidgets('the searched section lights up once', (tester) async {
    await _pump(
      tester,
      RowHighlightScope(
        rowId: 'diet.allergies',
        child: _section(highlightId: 'diet.allergies'),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is HighlightableRow && w.id == 'diet.allergies',
      ),
      findsOneWidget,
    );
    int fills() => find
        .descendant(
          of: find.byType(HighlightableRow),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is BoxDecoration,
          ),
        )
        .evaluate()
        .length;
    final lit = fills();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(fills(), lit - 1);
  });
}
