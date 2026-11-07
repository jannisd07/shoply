import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';

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
  await tester.pumpWidget(layoutHarness(layout, Center(child: child)));
}

Finder get _moving => find.descendant(
  of: find.byType(RollingNumber),
  matching: find.byType(FractionalTranslation),
);

/// Vertical offset (in glyph heights) of the rolling glyph showing [char].
double _offsetOf(WidgetTester tester, String char) {
  final glyph = find.descendant(of: _moving, matching: find.text(char));
  // The nearest one; further up are the page route's own transitions.
  final translation = tester.widget<FractionalTranslation>(
    find
        .ancestor(of: glyph, matching: find.byType(FractionalTranslation))
        .first,
  );
  return translation.translation.dy;
}

/// The frame after a change starts the ticker; the next one moves.
Future<void> _twoFrames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('formats with the locale and fraction digits', (tester) async {
    late String de;
    late String en;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          de = RollingNumber.format(
            context,
            1234.5,
            fractionDigits: 2,
            locale: 'de',
          );
          en = RollingNumber.format(context, 1234.5, fractionDigits: 1);
          return const SizedBox();
        },
      ),
    );
    expect(de, '1.234,50');
    expect(en, '1,234.5');
  });

  testWidgets('VoiceOver reads only the final value', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const RollingNumber(value: 23.8, fractionDigits: 2, locale: 'de'),
    );
    final node = tester.getSemantics(find.byType(RollingNumber));
    expect(node, isSemantics(label: '23,80'));
    var children = 0;
    node.visitChildren((_) {
      children++;
      return true;
    });
    expect(children, 0);

    await _pump(
      tester,
      const RollingNumber(value: 24.1, fractionDigits: 2, locale: 'de'),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.getSemantics(find.byType(RollingNumber)),
      isSemantics(label: '24,10'),
      reason: 'the end value, even mid-roll',
    );
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('only the changed digit rolls, upwards when growing', (
    tester,
  ) async {
    await _pump(tester, const RollingNumber(value: 120));
    expect(_moving, findsNothing);
    await _pump(tester, const RollingNumber(value: 125));
    await _twoFrames(tester);
    // One column with its outgoing and incoming glyph.
    expect(_moving, findsNWidgets(2));
    expect(_offsetOf(tester, '0'), lessThan(0), reason: 'leaves upwards');
    expect(_offsetOf(tester, '5'), greaterThan(0), reason: 'comes from below');
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_moving, findsNothing);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('rolls downwards when shrinking', (tester) async {
    await _pump(tester, const RollingNumber(value: 125));
    await _pump(tester, const RollingNumber(value: 120));
    await _twoFrames(tester);
    expect(_offsetOf(tester, '0'), lessThan(0), reason: 'comes from above');
    expect(_offsetOf(tester, '5'), greaterThan(0), reason: 'leaves downwards');
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('an interrupted roll continues from where it is', (tester) async {
    await _pump(tester, const RollingNumber(value: 120));
    await _pump(tester, const RollingNumber(value: 125));
    await _twoFrames(tester);
    final before = _offsetOf(tester, '5');
    expect(before, inExclusiveRange(0.0, 1.0));

    await _pump(tester, const RollingNumber(value: 126));
    expect(_offsetOf(tester, '5'), closeTo(before, 0.001), reason: 'no jump');
    var previous = before;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find
          .descendant(of: _moving, matching: find.text('5'))
          .evaluate()
          .isEmpty) {
        break;
      }
      final now = _offsetOf(tester, '5');
      expect(now, lessThan(previous), reason: 'keeps moving up');
      expect(previous - now, lessThan(0.5), reason: 'no jump');
      previous = now;
    }
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(_moving, findsNothing);
  });

  testWidgets('a new digit rolls in when the number grows longer', (
    tester,
  ) async {
    await _pump(tester, const RollingNumber(value: 999, locale: 'de'));
    await _pump(tester, const RollingNumber(value: 1000, locale: 'de'));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(RollingNumber)),
      isSemantics(label: '1.000'),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('.'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    semantics.dispose();
  });

  testWidgets('Reduce Motion cross-fades instead of rolling', (tester) async {
    const layout = LayoutCase(width: 390, scale: 1, reduceMotion: true);
    await _pump(tester, const RollingNumber(value: 120), layout: layout);
    await _pump(tester, const RollingNumber(value: 125), layout: layout);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_moving, findsNothing);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('125'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('120'), findsNothing);
    expect(find.text('125'), findsOneWidget);
  });

  testWidgets('uses tabular figures, also with a custom style', (tester) async {
    late TextStyle plain;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          plain = context.text(AvoTextStyle.title2);
          return RollingNumber(value: 7, style: plain);
        },
      ),
    );
    final text = tester.widget<Text>(find.text('7'));
    expect(
      text.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(plain.fontFeatures, isNull);
  });

  layoutMatrix(
    'RollingNumber',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Laktosefreie Bio-Vollmilch',
            style: context.text(AvoTextStyle.subhead),
          ),
          RollingNumber(
            value: 1234.56,
            fractionDigits: 2,
            locale: 'de',
            style: context.text(AvoTextStyle.largeTitle, tabular: true),
          ),
          const RollingNumber(value: 23.8, fractionDigits: 2, locale: 'de'),
        ],
      ),
    ),
  );
}
