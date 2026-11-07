import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';

import '../../../layout/layout_matrix.dart';

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
      Center(
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.screen),
          child: child,
        ),
      ),
    ),
  );
}

CustomPainter _painter(WidgetTester tester, Type type) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(type),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

// ignore: avoid_dynamic_calls
double _progress(WidgetTester tester, Type type) =>
    ((_painter(tester, type) as dynamic).progress as Animation<double>).value;

void main() {
  group('ProgressLine', () {
    testWidgets('4 pt high, full width, D2 colours', (tester) async {
      late AvoColors colors;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            colors = context.colors;
            return const ProgressLine(value: 8 / 12);
          },
        ),
      );
      expect(tester.getSize(find.byType(ProgressLine)), const Size(358, 4));
      final painter = _painter(tester, ProgressLine) as dynamic;
      // ignore: avoid_dynamic_calls
      expect(painter.track, colors.separator);
      // ignore: avoid_dynamic_calls
      expect(painter.fill, colors.tint);
      expect(_progress(tester, ProgressLine), closeTo(0.667, 0.001));
    });

    testWidgets('value changes follow the spring', (tester) async {
      await _pump(tester, const ProgressLine(value: 0.25));
      await _pump(tester, const ProgressLine(value: 0.75));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 32));
      expect(_progress(tester, ProgressLine), inExclusiveRange(0.25, 0.75));
      await tester.pumpAndSettle();
      expect(_progress(tester, ProgressLine), 0.75);
    });

    testWidgets('clamps to 0..1', (tester) async {
      await _pump(tester, const ProgressLine(value: 1.4));
      expect(_progress(tester, ProgressLine), 1);
    });

    testWidgets('Reduce Motion jumps', (tester) async {
      const layout = LayoutCase(width: 390, scale: 1, reduceMotion: true);
      await _pump(tester, const ProgressLine(value: 0.25), layout: layout);
      await _pump(tester, const ProgressLine(value: 0.75), layout: layout);
      await tester.pump();
      expect(_progress(tester, ProgressLine), 0.75);
    });

    testWidgets('VoiceOver: label and value like a progress indicator', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, const ProgressLine(value: 8 / 12));
      expect(
        tester.getSemantics(find.byType(ProgressLine)),
        isSemantics(value: '67%'),
      );
      await _pump(
        tester,
        const ProgressLine(
          value: 8 / 12,
          semanticLabel: 'Fortschritt',
          semanticValue: '8 von 12',
        ),
      );
      expect(
        tester.getSemantics(find.byType(ProgressLine)),
        isSemantics(label: 'Fortschritt', value: '8 von 12'),
      );
      semantics.dispose();
    });
  });

  group('ProgressRing', () {
    testWidgets('44 pt by default with a proportional stroke', (tester) async {
      await _pump(tester, const ProgressRing(value: 0.4));
      expect(tester.getSize(find.byType(ProgressRing)), const Size(44, 44));
      final painter = _painter(tester, ProgressRing) as dynamic;
      // ignore: avoid_dynamic_calls
      expect(painter.stroke, closeTo(3.96, 0.01));
      await _pump(tester, const ProgressRing(value: 0.4, size: 160));
      final large = _painter(tester, ProgressRing) as dynamic;
      // ignore: avoid_dynamic_calls
      expect(large.stroke, 12);
    });

    testWidgets('accent colour, red when over the goal', (tester) async {
      late AvoColors colors;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            colors = context.colors;
            return const ProgressRing(value: 0.8);
          },
        ),
      );
      // ignore: avoid_dynamic_calls
      expect((_painter(tester, ProgressRing) as dynamic).fill, colors.tint);
      await _pump(tester, const ProgressRing(value: 1.2, over: true));
      // ignore: avoid_dynamic_calls
      expect((_painter(tester, ProgressRing) as dynamic).fill, colors.red);
    });

    testWidgets('follows value changes on the spring', (tester) async {
      await _pump(tester, const ProgressRing(value: 0.2));
      await _pump(tester, const ProgressRing(value: 0.9));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 32));
      expect(_progress(tester, ProgressRing), inExclusiveRange(0.2, 0.9));
      await tester.pumpAndSettle();
      expect(_progress(tester, ProgressRing), 0.9);
    });

    testWidgets('shows the centre and reads the percentage', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const ProgressRing(
          value: 1.2,
          over: true,
          size: 120,
          semanticLabel: 'Kalorien',
          center: Text('120 kcal drüber'),
        ),
      );
      expect(find.text('120 kcal drüber'), findsOneWidget);
      final node = tester.getSemantics(find.byType(ProgressRing));
      expect(node, isSemantics(label: 'Kalorien\n120 kcal drüber'));
      expect(node, isSemantics(value: '120%'));
      semantics.dispose();
    });
  });

  layoutMatrix(
    'Progress',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '8 von 12 · ≈ 23,80 €',
            style: context.text(AvoTextStyle.subhead),
          ),
          const SizedBox(height: AvoSpacing.m),
          const ProgressLine(
            value: 8 / 12,
            semanticLabel: 'Fortschritt',
            semanticValue: '8 von 12',
          ),
          const SizedBox(height: AvoSpacing.xl),
          Wrap(
            spacing: AvoSpacing.l,
            runSpacing: AvoSpacing.l,
            children: [
              ProgressRing(
                value: 0.62,
                size: 120,
                semanticLabel: 'Kalorien',
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '1.240',
                      style: context.text(AvoTextStyle.title2, tabular: true),
                    ),
                    Text(
                      'kcal übrig',
                      style: context.text(AvoTextStyle.footnote),
                    ),
                  ],
                ),
              ),
              const ProgressRing(value: 1.15, over: true),
              const ProgressRing(value: 0.4, size: 24),
            ],
          ),
        ],
      ),
    ),
  );
}
