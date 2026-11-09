import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

import '../../../layout/layout_matrix.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: direction,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

RenderCustomPaint _paintOf(WidgetTester tester, [Finder? icon]) =>
    tester.renderObject<RenderCustomPaint>(
      find.descendant(
        of: icon ?? find.byType(AvoIcon),
        matching: find.byType(CustomPaint),
      ),
    );

Rect _bounds(String data) => AvoIconPath(data).toPath().getBounds();

/// Paint stores stroke widths as 32-bit floats.
double _f32(double value) => (Float32List(1)..[0] = value)[0];

void main() {
  group('SVG path parser', () {
    test('absolute commands and implicit lineto after M', () {
      expect(debugDescribeSvgPath('M3.5 10.6 12 3.4 L 20 4'), [
        'M 3.5 10.6',
        'L 12 3.4',
        'L 20 4',
      ]);
    });

    test('relative commands follow the current point', () {
      expect(debugDescribeSvgPath('m10 10l5 0h5v5c1 1 2 2 3 3q1 0 2 2z'), [
        'M 10 10',
        'L 15 10',
        'L 20 10',
        'L 20 15',
        'C 21 16 22 17 23 18',
        'Q 24 18 25 20',
        'Z',
      ]);
    });

    test('H and V, absolute and relative', () {
      expect(debugDescribeSvgPath('M1 1H5V7h-2v-3'), [
        'M 1 1',
        'L 5 1',
        'L 5 7',
        'L 3 7',
        'L 3 4',
      ]);
    });

    test('after Z the current point is the subpath start', () {
      expect(debugDescribeSvgPath('M10 10h5zm2 2h1zl1 1'), [
        'M 10 10',
        'L 15 10',
        'Z',
        'M 12 12',
        'L 13 12',
        'Z',
        'L 13 13',
      ]);
    });

    test('implicit repetition of every command', () {
      expect(debugDescribeSvgPath('m1 1 2 2 3 3'), ['M 1 1', 'L 3 3', 'L 6 6']);
      expect(debugDescribeSvgPath('M0 0l1 1 1 1h1 1v2 2'), [
        'M 0 0',
        'L 1 1',
        'L 2 2',
        'L 3 2',
        'L 4 2',
        'L 4 4',
        'L 4 6',
      ]);
      expect(debugDescribeSvgPath('M0 0c1 0 1 1 1 1 1 0 1 1 1 1'), [
        'M 0 0',
        'C 1 0 1 1 1 1',
        'C 2 1 2 2 2 2',
      ]);
      expect(debugDescribeSvgPath('M0 0a1 1 0 0 1 2 0 1 1 0 0 1 2 0'), [
        'M 0 0',
        'A 1 1 0 0 1 2 0',
        'A 1 1 0 0 1 4 0',
      ]);
    });

    test('compact number notation', () {
      expect(debugDescribeSvgPath('M1.5.5L-.7-.6'), [
        'M 1.5 0.5',
        'L -0.7 -0.6',
      ]);
      expect(debugDescribeSvgPath('M.5.5.5.5'), ['M 0.5 0.5', 'L 0.5 0.5']);
      expect(debugDescribeSvgPath('M0,0L1,2,3,4'), ['M 0 0', 'L 1 2', 'L 3 4']);
      expect(debugDescribeSvgPath('M1e1 2E-1l.5e1-1'), [
        'M 10 0.2',
        'L 15 -0.8',
      ]);
      expect(debugDescribeSvgPath('  M 1 2\n\tL+3 4  '), ['M 1 2', 'L 3 4']);
      expect(debugDescribeSvgPath(''), isEmpty);
    });

    test('S reflects the previous cubic control point', () {
      expect(debugDescribeSvgPath('M0 0C1 1 2 2 3 3S5 5 6 6'), [
        'M 0 0',
        'C 1 1 2 2 3 3',
        'C 4 4 5 5 6 6',
      ]);
      expect(debugDescribeSvgPath('M0 0c1 1 2 2 3 3s2 2 3 3'), [
        'M 0 0',
        'C 1 1 2 2 3 3',
        'C 4 4 5 5 6 6',
      ]);
      // Without a preceding curve the control point is the current point
      // (D2 heart: "M12 20s-7-4.4-7-10").
      expect(debugDescribeSvgPath('M12 20s-7-4.4-7-10'), [
        'M 12 20',
        'C 12 20 5 15.6 5 10',
      ]);
      // A line in between breaks the reflection.
      expect(debugDescribeSvgPath('M0 0C1 1 2 2 3 3L4 4S5 5 6 6'), [
        'M 0 0',
        'C 1 1 2 2 3 3',
        'L 4 4',
        'C 4 4 5 5 6 6',
      ]);
    });

    test('T reflects the previous quadratic control point', () {
      expect(debugDescribeSvgPath('M0 0Q1 1 2 0T4 0'), [
        'M 0 0',
        'Q 1 1 2 0',
        'Q 3 -1 4 0',
      ]);
      expect(debugDescribeSvgPath('M0 0q1 1 2 0t2 0'), [
        'M 0 0',
        'Q 1 1 2 0',
        'Q 3 -1 4 0',
      ]);
      expect(debugDescribeSvgPath('M0 0T4 0'), ['M 0 0', 'Q 0 0 4 0']);
    });

    test('arcs, absolute and relative, with compact flags', () {
      expect(debugDescribeSvgPath('M3 4.5A1.5 1.5 0 0 1 4.5 3'), [
        'M 3 4.5',
        'A 1.5 1.5 0 0 1 4.5 3',
      ]);
      // D2 bookmark: "a.6.6 0 0 1-.95.5".
      expect(debugDescribeSvgPath('M10 10a.6.6 0 0 1-.95.5'), [
        'M 10 10',
        'A 0.6 0.6 0 0 1 9.05 10.5',
      ]);
      // Flags need no separator.
      expect(debugDescribeSvgPath('M0 0a1 1 0 011 1'), [
        'M 0 0',
        'A 1 1 0 0 1 1 1',
      ]);
      expect(debugDescribeSvgPath('M0 0a2 1 30 1 0 4 0'), [
        'M 0 0',
        'A 2 1 30 1 0 4 0',
      ]);
      // Negative radii count as positive; a zero radius is a line; an arc
      // to the current point is dropped.
      expect(
        debugDescribeSvgPath(
          'M0 0A-2 -2 0 0 1 4 0A0 3 0 0 1 6 0A1 1 0 0 1 6 0',
        ),
        ['M 0 0', 'A 2 2 0 0 1 4 0', 'L 6 0'],
      );
    });

    test('sweep flag 1 runs clockwise on screen', () {
      // From the left to the right end of a circle of radius 10.
      final clockwise = _bounds('M0 10A10 10 0 0 1 20 10');
      expect(clockwise.top, moreOrLessEquals(0, epsilon: 0.01));
      expect(clockwise.bottom, moreOrLessEquals(10, epsilon: 0.01));

      final counterClockwise = _bounds('M0 10A10 10 0 0 0 20 10');
      expect(counterClockwise.top, moreOrLessEquals(10, epsilon: 0.01));
      expect(counterClockwise.bottom, moreOrLessEquals(20, epsilon: 0.01));
    });

    test('two arcs make the full clock face', () {
      final path = AvoIcons.clock.shapes.single.toPath();
      final bounds = path.getBounds();
      expect(bounds.left, moreOrLessEquals(2, epsilon: 0.01));
      expect(bounds.top, moreOrLessEquals(2, epsilon: 0.01));
      expect(bounds.right, moreOrLessEquals(22, epsilon: 0.01));
      expect(bounds.bottom, moreOrLessEquals(22, epsilon: 0.01));
      // Circle plus the two hands: two contours.
      expect(path.computeMetrics().length, 2);
    });

    test('radii too small for the end point are scaled up', () {
      final bounds = _bounds('M0 0A1 1 0 0 1 10 0');
      expect(bounds.width, moreOrLessEquals(10, epsilon: 0.01));
      expect(bounds.top, moreOrLessEquals(-5, epsilon: 0.01));
    });

    test('even-odd fill cuts the hole of the tag', () {
      final tag = AvoIcons.tag.shapes.single.toPath();
      expect(tag.fillType, PathFillType.evenOdd);
      expect(tag.contains(const Offset(12, 12)), isTrue);
      expect(tag.contains(const Offset(7.5, 7.5)), isFalse);
    });

    test('the D2 home path parses to the expected segments', () {
      expect(
        debugDescribeSvgPath(
          'M3.5 10.6 12 3.4l8.5 7.2v9.1c0 .7-.6 1.3-1.3 1.3H15v-6.2H9V21H4.8'
          'c-.7 0-1.3-.6-1.3-1.3z',
        ),
        [
          'M 3.5 10.6',
          'L 12 3.4',
          'L 20.5 10.6',
          'L 20.5 19.7',
          'C 20.5 20.4 19.9 21 19.2 21',
          'L 15 21',
          'L 15 14.8',
          'L 9 14.8',
          'L 9 21',
          'L 4.8 21',
          'C 4.1 21 3.5 20.4 3.5 19.7',
          'Z',
        ],
      );
    });

    test('malformed data throws a FormatException', () {
      expect(() => debugDescribeSvgPath('L1 1'), throwsFormatException);
      expect(() => debugDescribeSvgPath('M0'), throwsFormatException);
      expect(() => debugDescribeSvgPath('M0 0 X1'), throwsFormatException);
      expect(() => debugDescribeSvgPath('M0 0z 1 1'), throwsFormatException);
      expect(
        () => debugDescribeSvgPath('M0 0A1 1 0 2 0 1 1'),
        throwsFormatException,
      );
      expect(() => debugDescribeSvgPath('M0 0L.'), throwsFormatException);
    });

    test('toPath returns a copy that callers may change', () {
      final shape = AvoIcons.home.shapes.single;
      final copy = shape.toPath()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      expect(copy.getBounds().right, 100);
      expect(shape.toPath().getBounds().right, lessThan(24));
    });
  });

  group('icon set', () {
    test('contains every icon the components need', () {
      expect(
        AvoIcons.all.keys,
        containsAll(<String>[
          'home', 'cart', 'sparkle', 'forkKnife', 'person', 'chevronBack',
          'chevronRight', 'chevronDown', 'share', 'more', 'plus', 'minus',
          'mic', 'check', 'tag', 'trash', 'clock', 'search', 'xmark',
          'calendar', 'keyboard', 'people', //
        ]),
      );
      expect(AvoIcons.all['home'], same(AvoIcons.home));
      expect(AvoIcons.all['people'], same(AvoIcons.people));
    });

    test('every shape parses and stays on the 24 grid', () {
      for (final MapEntry(:key, :value) in AvoIcons.all.entries) {
        expect(value.viewBox, 24, reason: key);
        for (final shape in value.shapes) {
          final path = shape.toPath();
          final bounds = path.getBounds();
          final length = path.computeMetrics().fold<double>(
            0,
            (sum, m) => sum + m.length,
          );
          expect(length, greaterThan(0), reason: key);
          expect(bounds.left, greaterThanOrEqualTo(0), reason: key);
          expect(bounds.top, greaterThanOrEqualTo(0), reason: key);
          expect(bounds.right, lessThanOrEqualTo(24), reason: key);
          expect(bounds.bottom, lessThanOrEqualTo(24), reason: key);
        }
      }
    });

    test('filled variants exist where D2 shows them', () {
      for (final icon in [
        AvoIcons.home,
        AvoIcons.cart,
        AvoIcons.sparkle,
        AvoIcons.forkKnife,
        AvoIcons.person,
        AvoIcons.heart,
        AvoIcons.bookmark,
      ]) {
        expect(icon.hasFilledVariant, isTrue);
      }
      for (final icon in [
        AvoIcons.more,
        AvoIcons.tag,
        AvoIcons.trash,
        AvoIcons.people,
        AvoIcons.check,
        AvoIcons.plus,
        AvoIcons.mic,
        AvoIcons.chevronBack,
      ]) {
        expect(icon.hasFilledVariant, isFalse);
      }
      // D2 Rezepte tab: the fork stays a line, only the knife fills.
      final fork = AvoIcons.forkKnife.shapes.first;
      expect(fork.styleFor(filled: true), AvoIconStyle.stroke);
    });

    test('the AB1 glyphs exist and drawing is non-trivial', () {
      const names = [
        'plusBubble', 'leaf', 'switch2', 'eurosignCircle', 'filter', //
        'filterCircle', 'filterCircleFill', 'checkmarkCircle',
        'cartBadgePlus', 'bag', 'chartBar', 'listBullet', 'arrowDown',
        'chevronUpChevronDown',
      ];
      expect(AvoIcons.all.keys, containsAll(names));
      for (final name in names) {
        final bounds = AvoIcons.all[name]!.shapes
            .map((s) => s.toPath().getBounds())
            .reduce((a, b) => a.expandToInclude(b));
        // Fills most of the 24 grid, within the 2 pt margin of the set.
        expect(bounds.width, greaterThan(8), reason: name);
        expect(bounds.height, greaterThan(8), reason: name);
        expect(bounds.left, greaterThanOrEqualTo(1.5), reason: name);
        expect(bounds.top, greaterThanOrEqualTo(1.5), reason: name);
        expect(bounds.right, lessThanOrEqualTo(22.5), reason: name);
        expect(bounds.bottom, lessThanOrEqualTo(22.5), reason: name);
      }
    });

    test('only chevrons mirror in right-to-left text', () {
      final mirrored = AvoIcons.all.entries
          .where((e) => e.value.matchTextDirection)
          .map((e) => e.key);
      expect(mirrored, unorderedEquals(['chevronBack', 'chevronRight']));
    });

    test('custom data on another view box is allowed', () {
      const icon = AvoIconData([AvoIconPath('M5 1v8M1 5h8')], viewBox: 10);
      expect(icon.viewBox, 10);
      expect(icon.hasFilledVariant, isFalse);
    });
  });

  group('AvoIcon', () {
    testWidgets('every icon paints in both variants without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Wrap(
            children: [
              for (final icon in AvoIcons.all.values) ...[
                AvoIcon(icon),
                AvoIcon(icon, size: 26, filled: true),
                AvoIcon(icon, size: 10, strokeWidth: 3.8),
              ],
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AvoIcon), findsNWidgets(AvoIcons.all.length * 3));
      for (final element in find.byType(AvoIcon).evaluate()) {
        expect(_paintOf(tester, find.byWidget(element.widget)), paints..path());
      }
    });

    testWidgets('default size is 22 and ignores Dynamic Type', (tester) async {
      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.home), textScale: 3.1),
      );
      expect(tester.getSize(find.byType(AvoIcon)), const Size(22, 22));
    });

    testWidgets('default colour is the label token in light and dark', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AvoIcon(AvoIcons.home)));
      expect(
        _paintOf(tester),
        paints..path(color: AvoColors.light.label, style: PaintingStyle.stroke),
      );

      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.home), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle(); // the theme cross-fades
      expect(
        _paintOf(tester),
        paints..path(color: AvoColors.dark.label, style: PaintingStyle.stroke),
      );
    });

    testWidgets('stroke width is in view-box units and scales with size', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AvoIcon(AvoIcons.cart, size: 26)));
      expect(
        _paintOf(tester),
        paints
          ..scale(x: 26 / 24, y: 26 / 24)
          ..path(style: PaintingStyle.stroke, strokeWidth: _f32(1.8)),
      );

      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.plus, size: 16, strokeWidth: 2.8)),
      );
      expect(
        _paintOf(tester),
        paints
          ..scale(x: 16 / 24, y: 16 / 24)
          ..path(style: PaintingStyle.stroke, strokeWidth: _f32(2.8)),
      );

      await tester.pumpWidget(_host(const AvoIcon(AvoIcons.chevronBack)));
      expect(
        _paintOf(tester),
        paints..path(style: PaintingStyle.stroke, strokeWidth: _f32(2.2)),
      );
    });

    testWidgets('outline variant strokes, filled variant fills and strokes', (
      tester,
    ) async {
      const green = Color(0xFF2E8B47);
      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.home, color: green)),
      );
      expect(_paintOf(tester), paintsExactlyCountTimes(#drawPath, 1));
      expect(
        _paintOf(tester),
        paints..path(style: PaintingStyle.stroke, color: green),
      );

      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.home, color: green, filled: true)),
      );
      expect(_paintOf(tester), paintsExactlyCountTimes(#drawPath, 2));
      expect(
        _paintOf(tester),
        paints
          ..path(style: PaintingStyle.fill, color: green)
          ..path(
            style: PaintingStyle.stroke,
            color: green,
            strokeWidth: _f32(1.8),
          ),
      );
    });

    testWidgets('filled fork and knife fills only the knife', (tester) async {
      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.forkKnife, filled: true)),
      );
      expect(
        _paintOf(tester),
        paints
          ..path(style: PaintingStyle.stroke)
          ..path(style: PaintingStyle.fill)
          ..path(style: PaintingStyle.stroke),
      );
      expect(_paintOf(tester), paintsExactlyCountTimes(#drawPath, 3));
    });

    testWidgets('icons without a filled variant ignore filled', (tester) async {
      await tester.pumpWidget(_host(const AvoIcon(AvoIcons.more)));
      expect(_paintOf(tester), paintsExactlyCountTimes(#drawPath, 3));
      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.more, filled: true)),
      );
      expect(_paintOf(tester), paintsExactlyCountTimes(#drawPath, 3));
      expect(_paintOf(tester), paints..path(style: PaintingStyle.fill));
    });

    testWidgets('chevrons mirror in right-to-left text, other icons do not', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AvoIcon(AvoIcons.chevronBack)));
      expect(_paintOf(tester), paints..scale(x: 22 / 24, y: 22 / 24));

      await tester.pumpWidget(
        _host(
          const AvoIcon(AvoIcons.chevronBack),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        _paintOf(tester),
        paints
          ..translate(x: 22, y: 0)
          ..scale(x: -22 / 24, y: 22 / 24),
      );

      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.plus), direction: TextDirection.rtl),
      );
      expect(_paintOf(tester), paints..scale(x: 22 / 24, y: 22 / 24));
    });

    testWidgets('non-square constraints keep the glyph square and centred', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 40, height: 20, child: AvoIcon(AvoIcons.plus)),
        ),
      );
      expect(
        _paintOf(tester),
        paints
          ..translate(x: 10, y: 0)
          ..scale(x: 20 / 24, y: 20 / 24),
      );
    });

    testWidgets('repaints only when something visible changes', (tester) async {
      Future<CustomPainter> painterFor(AvoIcon icon) async {
        await tester.pumpWidget(_host(icon));
        return _paintOf(tester).painter!;
      }

      final base = await painterFor(const AvoIcon(AvoIcons.home));
      final same = await painterFor(const AvoIcon(AvoIcons.home));
      expect(same.shouldRepaint(base), isFalse);

      for (final changed in const [
        AvoIcon(AvoIcons.cart),
        AvoIcon(AvoIcons.home, color: Color(0xFF2E8B47)),
        AvoIcon(AvoIcons.home, filled: true),
        AvoIcon(AvoIcons.home, strokeWidth: 2.4),
      ]) {
        final other = await painterFor(changed);
        expect(other.shouldRepaint(base), isTrue, reason: '$changed');
      }

      // A size change relayouts; the painter itself stays equal.
      final bigger = await painterFor(const AvoIcon(AvoIcons.home, size: 26));
      expect(bigger.shouldRepaint(base), isFalse);
    });

    testWidgets('with a label VoiceOver reads it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const AvoIcon(AvoIcons.share, semanticLabel: 'Teilen')),
      );
      expect(find.bySemanticsLabel('Teilen'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AvoIcon)),
        matchesSemantics(label: 'Teilen'),
      );
      handle.dispose();
    });

    testWidgets('without a label the icon adds nothing for VoiceOver', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Semantics(
            container: true,
            button: true,
            label: 'Liste teilen',
            child: const AvoIcon(AvoIcons.share),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AvoIcon));
      expect(node, matchesSemantics(label: 'Liste teilen', isButton: true));
      expect(node.hasChildren, isFalse);
      handle.dispose();
    });
  });

  // Icons next to real text: a tag before a long article name, the clock
  // before a time, the people glyph before members, a tab item and the full
  // set in a wrap. The icons stay fixed, the text wraps.
  layoutMatrix('AvoIcon', scrollable: true, (context) {
    final colors = context.colors;
    Widget row(AvoIconData icon, String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: AvoSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvoIcon(icon, size: 20, color: color),
          const SizedBox(width: AvoSpacing.s),
          Expanded(child: Text(text, style: context.text(AvoTextStyle.body))),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            AvoIcons.tag,
            'Laktosefreie Bio-Vollmilch 1,5 % · 0,99 € · Lidl',
            color: colors.tint,
          ),
          row(AvoIcons.clock, 'Zuletzt geändert vor 12 Minuten'),
          row(AvoIcons.people, 'Wocheneinkauf mit Lena und Max'),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvoIcon(
                  AvoIcons.forkKnife,
                  size: 26,
                  filled: true,
                  color: colors.tintIcon,
                ),
                Text(
                  'Rezepte',
                  style: context.text(
                    AvoTextStyle.tabLabel,
                    color: colors.tint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AvoSpacing.m),
          Wrap(
            spacing: AvoSpacing.s,
            runSpacing: AvoSpacing.s,
            children: [
              for (final icon in AvoIcons.all.values) AvoIcon(icon),
              for (final icon in AvoIcons.all.values)
                AvoIcon(icon, filled: true, color: colors.tintIcon),
            ],
          ),
        ],
      ),
    );
  });

  testWidgets('icons take colour and size from IconStyleScope', (tester) async {
    const red = Color(0xFFFF0000);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconStyleScope(
          color: red,
          size: 30,
          child: Row(
            children: [
              AvoIcon(AvoIcons.cart, key: Key('scoped')),
              AvoIcon(AvoIcons.cart, key: Key('own'), size: 12),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('scoped'))), const Size(30, 30));
    expect(tester.getSize(find.byKey(const Key('own'))), const Size(12, 12));
    final theme = tester.widget<AvoIconTheme>(find.byType(AvoIconTheme));
    expect(theme.color, red);
    expect(
      IconTheme.of(tester.element(find.byKey(const Key('scoped')))).size,
      30,
    );
  });

  testWidgets('without a scope icons keep the default size', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: AvoIcon(AvoIcons.cart)),
      ),
    );
    expect(
      tester.getSize(find.byType(AvoIcon)),
      const Size.square(AvoIcon.defaultSize),
    );
  });
}
