import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';

import '../../../layout/layout_matrix.dart';

/// Pumps [child] inside a 16 pt screen margin; at 390 pt the chart is 358
/// wide, like D2 (card padding left out on purpose).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      layout,
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.screen),
          child: child,
        ),
      ),
    ),
  );
}

String _euro(double v) => '${v.round()} €';

// D2-FuerDich "Ausgaben im Vergleich".
const _months = [
  AvoBarEntry(label: 'Jun', value: 212, semanticLabel: 'Juni'),
  AvoBarEntry(label: 'Jul', value: 198, semanticLabel: 'Juli'),
  AvoBarEntry(label: 'Aug', value: 201, semanticLabel: 'August'),
  AvoBarEntry(label: 'Sep', value: 236, semanticLabel: 'September'),
  AvoBarEntry(label: 'Okt', value: 208, semanticLabel: 'Oktober'),
  AvoBarEntry(
    label: 'Nov',
    value: 183,
    semanticLabel: 'November',
    semanticValue: 'bisher 183 €',
  ),
];

const _summary =
    'Ausgaben pro Monat, November bisher 183 €, 12 % weniger als im Oktober';

AvoBarChart _chart({
  List<AvoBarEntry> entries = _months,
  int? highlight = 5,
  bool tintAll = false,
  double? goal,
  String? emptyText,
}) => AvoBarChart(
  entries: entries,
  formatValue: _euro,
  semanticSummary: _summary,
  highlightIndex: highlight,
  tintAllBars: tintAll,
  goal: goal,
  emptyText: emptyText,
);

bool _isBar(Widget w) =>
    w is DecoratedBox &&
    w.decoration is BoxDecoration &&
    (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(10);

Iterable<Element> _barElements() => find
    .descendant(
      of: find.byType(AvoBarChart),
      matching: find.byWidgetPredicate(_isBar),
    )
    .evaluate();

/// The bar boxes, leading to trailing, in global coordinates.
List<Rect> _bars(WidgetTester tester) => [
  for (final e in _barElements())
    (e.renderObject! as RenderBox).localToGlobal(Offset.zero) &
        (e.renderObject! as RenderBox).size,
];

List<BoxDecoration> _barDecorations(WidgetTester tester) => [
  for (final e in _barElements())
    (e.widget as DecoratedBox).decoration as BoxDecoration,
];

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('AvoBarChart', () {
    testWidgets('D2: 48 pt bars, radius 10, tallest 84, space-between', (
      tester,
    ) async {
      await _pump(tester, _chart());
      await tester.pumpAndSettle();
      final chart = tester.getRect(find.byType(AvoBarChart));
      expect(chart.width, 358);
      final bars = _bars(tester);
      expect(bars, hasLength(6));
      for (final b in bars) {
        expect(b.width, 48);
      }
      expect(bars[3].height, closeTo(84, 0.01)); // Sep, the largest
      expect(bars[0].height, closeTo(212 / 236 * 84, 0.01));
      expect(bars.first.left, chart.left);
      expect(bars.last.right, chart.right);
      // Shared baseline.
      for (final b in bars) {
        expect(b.bottom, closeTo(bars.first.bottom, 0.01));
      }
      // Value 4 above its bar, label 6 below.
      expect(tester.getRect(find.text('212 €')).bottom + 4, bars[0].top);
      expect(tester.getRect(find.text('Jun')).top, bars[0].bottom + 6);
    });

    testWidgets('D2 colours and type: highlighted bar tinted', (tester) async {
      await _pump(tester, _chart());
      await tester.pumpAndSettle();
      final colors = AvoColors.light;
      final decorations = _barDecorations(tester);
      for (var i = 0; i < 5; i++) {
        expect(decorations[i].color, colors.fill);
      }
      expect(decorations[5].color, colors.tint);

      final value = _style(tester, '212 €');
      expect(value.fontSize, 12);
      expect(value.color, colors.tertiaryLabel);
      expect(value.fontFeatures, contains(const FontFeature.tabularFigures()));
      final now = _style(tester, '183 €');
      expect(now.color, colors.tint);
      expect(now.fontWeight, FontWeight.w600);

      final label = _style(tester, 'Jun');
      expect(label.fontSize, 13);
      expect(label.color, colors.secondaryLabel);
      final current = _style(tester, 'Nov');
      expect(current.color, colors.label);
      expect(current.fontWeight, FontWeight.w600);
    });

    testWidgets('tintAllBars: every bar tinted, the label marks today', (
      tester,
    ) async {
      await _pump(tester, _chart(tintAll: true));
      await tester.pumpAndSettle();
      for (final d in _barDecorations(tester)) {
        expect(d.color, AvoColors.light.tint);
      }
      expect(_style(tester, 'Nov').fontWeight, FontWeight.w600);
      expect(_style(tester, 'Jun').fontWeight, isNot(FontWeight.w600));
    });

    testWidgets('bars grow from zero on the spring', (tester) async {
      await _pump(tester, _chart());
      expect(_bars(tester)[3].height, 0);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_bars(tester)[3].height, inExclusiveRange(0, 84));
      await tester.pumpAndSettle();
      expect(_bars(tester)[3].height, closeTo(84, 0.01));
    });

    testWidgets('Reduce Motion: bars are there at once', (tester) async {
      await _pump(
        tester,
        _chart(),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      expect(_bars(tester)[3].height, closeTo(84, 0.01));
      // Changes jump as well.
      await _pump(
        tester,
        _chart(
          entries: [
            for (final e in _months)
              AvoBarEntry(label: e.label, value: (e.value ?? 0) / 2),
          ]..[0] = const AvoBarEntry(label: 'Jun', value: 236),
        ),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      await tester.pump();
      expect(_bars(tester)[0].height, closeTo(84, 0.01));
      expect(_bars(tester)[3].height, closeTo(42, 0.01));
    });

    testWidgets('value changes start from the bar on screen', (tester) async {
      await _pump(tester, _chart());
      await tester.pumpAndSettle();
      final changed = [
        const AvoBarEntry(label: 'Jun', value: 472),
        for (final e in _months.skip(1)) e,
      ];
      await _pump(tester, _chart(entries: changed));
      // First frame after the change: still where it was.
      expect(_bars(tester)[3].height, closeTo(84, 0.01));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = _bars(tester)[3].height;
      expect(mid, inExclusiveRange(42, 84));
      await tester.pumpAndSettle();
      expect(_bars(tester)[0].height, closeTo(84, 0.01));
      expect(_bars(tester)[3].height, closeTo(42, 0.01));
    });

    testWidgets('narrow: bars get thinner, gaps stay at least 8', (
      tester,
    ) async {
      const days = [
        AvoBarEntry(label: 'Mo', value: 1910),
        AvoBarEntry(label: 'Di', value: 2080),
        AvoBarEntry(label: 'Mi'),
        AvoBarEntry(label: 'Do', value: 1760),
        AvoBarEntry(label: 'Fr', value: 2010),
        AvoBarEntry(label: 'Sa', value: 1640),
        AvoBarEntry(label: 'So'),
      ];
      await _pump(
        tester,
        _chart(entries: days, highlight: 5),
        layout: const LayoutCase(width: 288, scale: 1),
      );
      await tester.pumpAndSettle();
      final bars = _bars(tester);
      expect(bars, hasLength(5)); // Mi and So have no data
      final width = (256 - 6 * 8) / 7;
      for (final b in bars) {
        expect(b.width, closeTo(width, 0.01));
      }
      expect(bars[1].left - bars[0].right, closeTo(8, 0.01));
    });

    testWidgets('missing values: no bar, a dash, spoken as given', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _chart(
          entries: const [
            AvoBarEntry(label: 'Mo', value: 1910),
            AvoBarEntry(
              label: 'Mi',
              semanticLabel: 'Mittwoch',
              semanticValue: 'nicht erfasst',
            ),
          ],
          highlight: null,
        ),
      );
      await tester.pumpAndSettle();
      expect(_bars(tester), hasLength(1));
      expect(find.text('–'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mittwoch')),
        isSemantics(label: 'Mittwoch', value: 'nicht erfasst'),
      );
      handle.dispose();
    });

    testWidgets('no data: one sentence instead of zeros', (tester) async {
      await _pump(
        tester,
        _chart(
          entries: const [
            AvoBarEntry(label: 'Mo'),
            AvoBarEntry(label: 'Di'),
          ],
          emptyText: 'Noch keine Woche erfasst.',
        ),
      );
      expect(find.text('Noch keine Woche erfasst.'), findsOneWidget);
      expect(find.text('Mo'), findsNothing);
      expect(
        _style(tester, 'Noch keine Woche erfasst.').color,
        AvoColors.light.secondaryLabel,
      );
    });

    testWidgets('goal: dashed line at the goal height', (tester) async {
      await _pump(tester, _chart(goal: 250));
      await tester.pumpAndSettle();
      final bars = _bars(tester);
      // The goal is the top of the scale now.
      expect(bars[3].height, closeTo(236 / 250 * 84, 0.01));
      final line = tester.getRect(
        find
            .descendant(
              of: find.byType(AvoBarChart),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(line.height, 1);
      expect(line.width, 358);
      expect(line.center.dy, closeTo(bars[3].bottom - 84, 0.01));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: find.byType(AvoBarChart),
                          matching: find.byType(CustomPaint),
                        )
                        .first,
                  )
                  .painter
              as dynamic;
      // ignore: avoid_dynamic_calls
      expect(painter.color, AvoColors.light.secondaryLabel);
    });

    testWidgets('VoiceOver: a summary, then one element per bar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _chart());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(_summary), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Juni')),
        isSemantics(label: 'Juni', value: '212 €'),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('November')),
        isSemantics(label: 'November', value: 'bisher 183 €'),
      );
      // The visible abbreviations are not read on their own.
      expect(find.bySemanticsLabel('Jun'), findsNothing);
      handle.dispose();
    });

    testWidgets('AX1 and up: a list with label, value and a bar per row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _chart(),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      await tester.pumpAndSettle();
      // No vertical bars any more.
      expect(_bars(tester), isEmpty);
      final jun = tester.getRect(find.text('Jun'));
      final jul = tester.getRect(find.text('Jul'));
      expect(jul.top, greaterThan(jun.bottom));
      final value = tester.getRect(find.text('212 €'));
      expect(value.right, closeTo(358 + 16, 0.01)); // end of the row
      // Horizontal bars: radius 3, 6 high, as long as the value.
      final rowBars = find.descendant(
        of: find.byType(AvoBarChart),
        matching: find.byType(FractionallySizedBox),
      );
      expect(rowBars, findsNWidgets(6));
      final sep = tester.getRect(rowBars.at(3));
      final june = tester.getRect(rowBars.at(0));
      expect(sep.height, 6);
      expect(sep.width, closeTo(358, 0.01));
      expect(june.width, closeTo(212 / 236 * 358, 0.01));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Juni')),
        isSemantics(label: 'Juni', value: '212 €'),
      );
      expect(find.bySemanticsLabel(_summary), findsOneWidget);
      handle.dispose();
    });

    testWidgets('labels that do not fit shrink instead of wrapping', (
      tester,
    ) async {
      await _pump(
        tester,
        _chart(
          entries: const [
            AvoBarEntry(label: 'September', value: 1),
            AvoBarEntry(label: 'Oktober', value: 2),
            AvoBarEntry(label: 'November', value: 3),
            AvoBarEntry(label: 'Dezember', value: 4),
            AvoBarEntry(label: 'Januar', value: 5),
            AvoBarEntry(label: 'Februar', value: 6),
            AvoBarEntry(label: 'März', value: 7),
          ],
        ),
        layout: const LayoutCase(width: 320, scale: 1.35),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      final slot = (288 - 6 * 8) / 7 + 8;
      final label = tester.getRect(find.text('September'));
      expect(label.width, lessThanOrEqualTo(slot + 0.01));
      expect(tester.widget<Text>(find.text('September')).maxLines, 1);
    });
  });

  group('AvoHorizontalBar', () {
    testWidgets('D2 macro row: 13/18 texts, 6 pt bar on a fill track', (
      tester,
    ) async {
      await _pump(
        tester,
        const AvoHorizontalBar(
          label: 'Protein',
          value: '62 / 110 g',
          fraction: 62 / 110,
        ),
      );
      final colors = AvoColors.light;
      expect(_style(tester, 'Protein').fontSize, 13);
      expect(_style(tester, 'Protein').color, colors.label);
      final value = _style(tester, '62 / 110 g');
      expect(value.color, colors.secondaryLabel);
      expect(value.fontFeatures, contains(const FontFeature.tabularFigures()));
      final track = find.descendant(
        of: find.byType(AvoHorizontalBar),
        matching: find.byType(DecoratedBox),
      );
      final trackDecoration =
          tester.widget<DecoratedBox>(track.first).decoration as BoxDecoration;
      expect(trackDecoration.color, colors.fill);
      expect(trackDecoration.borderRadius, BorderRadius.circular(3));
      final trackRect = tester.getRect(track.first);
      expect(trackRect.size, const Size(358, 6));
      expect(trackRect.top, tester.getRect(find.text('Protein')).bottom + 6);
      final fill = tester.getRect(track.last);
      expect(fill.width, closeTo(358 * 62 / 110, 0.01));
      expect(
        (tester.widget<DecoratedBox>(track.last).decoration as BoxDecoration)
            .color,
        colors.tint,
      );
    });

    testWidgets('follows changes on the spring; Reduce Motion jumps', (
      tester,
    ) async {
      double fill() => tester
          .getRect(
            find
                .descendant(
                  of: find.byType(AvoHorizontalBar),
                  matching: find.byType(DecoratedBox),
                )
                .last,
          )
          .width;
      Widget bar(double f) =>
          AvoHorizontalBar(label: 'Fett', value: '41 / 70 g', fraction: f);
      await _pump(tester, bar(0.25));
      expect(fill(), closeTo(358 * 0.25, 0.01));
      await _pump(tester, bar(0.75));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      expect(fill(), inExclusiveRange(358 * 0.25, 358 * 0.75));
      await tester.pumpAndSettle();
      expect(fill(), closeTo(358 * 0.75, 0.01));

      const reduce = LayoutCase(width: 390, scale: 1, reduceMotion: true);
      await _pump(tester, bar(0.25), layout: reduce);
      await _pump(tester, bar(0.5), layout: reduce);
      await tester.pump();
      expect(fill(), closeTo(358 * 0.5, 0.01));
    });

    testWidgets('VoiceOver: one element with label and value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const AvoHorizontalBar(
          label: 'Protein',
          value: '62 / 110 g',
          fraction: 0.56,
          semanticValue: '62 von 110 Gramm',
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Protein')),
        isSemantics(label: 'Protein', value: '62 von 110 Gramm'),
      );
      handle.dispose();
    });

    testWidgets('value moves below a label that fills the line', (
      tester,
    ) async {
      await _pump(
        tester,
        const AvoHorizontalBar(
          label: 'Kohlenhydrate, davon Zucker aus Obst und Milch',
          value: '148 / 230 g',
          fraction: 0.64,
        ),
        layout: const LayoutCase(width: 320, scale: 3.1),
      );
      expect(tester.takeException(), isNull);
      final label = tester.getRect(
        find.text('Kohlenhydrate, davon Zucker aus Obst und Milch'),
      );
      final value = tester.getRect(find.text('148 / 230 g'));
      expect(value.top, greaterThanOrEqualTo(label.bottom));
    });
  });

  // ------------------------------------------------------------- layout

  layoutMatrix(
    'AvoBarChart six months in a card',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.xxxl),
      child: _chart(),
    ),
    scrollable: true,
  );

  layoutMatrix(
    'AvoBarChart seven days with goal and missing days',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.xxxl),
      child: AvoBarChart(
        entries: const [
          AvoBarEntry(label: 'Mo', value: 1910, semanticLabel: 'Montag'),
          AvoBarEntry(label: 'Di', value: 2080, semanticLabel: 'Dienstag'),
          AvoBarEntry(label: 'Mi', semanticLabel: 'Mittwoch'),
          AvoBarEntry(label: 'Do', value: 1760, semanticLabel: 'Donnerstag'),
          AvoBarEntry(label: 'Fr', value: 2010, semanticLabel: 'Freitag'),
          AvoBarEntry(label: 'Sa', value: 1640, semanticLabel: 'Samstag'),
          AvoBarEntry(label: 'So', semanticLabel: 'Sonntag'),
        ],
        formatValue: (v) => '${v.round()} kcal',
        semanticSummary:
            'Diese Woche im Schnitt 1.880 Kilokalorien an 5 Tagen, Ziel 2.000',
        highlightIndex: 5,
        tintAllBars: true,
        goal: 2000,
        maxBarHeight: 120,
      ),
    ),
    scrollable: true,
  );

  layoutMatrix(
    'AvoBarChart long month names',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.xxxl),
      child: AvoBarChart(
        entries: const [
          AvoBarEntry(label: 'September', value: 1212.5),
          AvoBarEntry(label: 'Oktober', value: 998),
          AvoBarEntry(label: 'November', value: 1236),
          AvoBarEntry(label: 'Dezember', value: 1408),
        ],
        formatValue: (v) => '${v.toStringAsFixed(2)} €',
        semanticSummary: 'Ausgaben pro Monat',
        highlightIndex: 3,
      ),
    ),
    scrollable: true,
  );

  layoutMatrix(
    'AvoHorizontalBar long label',
    (context) => const Padding(
      padding: EdgeInsets.all(AvoSpacing.xxxl),
      child: AvoHorizontalBar(
        label: 'Kohlenhydrate, davon Zucker aus Obst und Milch',
        value: '148 / 230 g',
        fraction: 0.64,
      ),
    ),
    scrollable: true,
  );
}
