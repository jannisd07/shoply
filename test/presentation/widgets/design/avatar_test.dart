import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';

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

/// Decoration of the circle that draws [text].
ShapeDecoration _circleWith(WidgetTester tester, String text) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.text(text),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

ShapeDecoration _circleOf(WidgetTester tester, Finder of) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: of, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as ShapeDecoration;

/// Halo progress of the presence dot (0 = not started, 1 = over).
double _halo(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(PresenceDot),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  // ignore: avoid_dynamic_calls
  return ((paint.painter as dynamic).halo as Animation<double>).value;
}

void main() {
  group('Avatar', () {
    testWidgets('D2 sizes 20 / 24 / 32, initial in tint on tintSoft', (
      tester,
    ) async {
      await _pump(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(key: Key('s'), name: 'lena', size: AvatarSize.small),
            Avatar(key: Key('m'), name: 'Lena'),
            Avatar(key: Key('l'), name: 'Lena', size: AvatarSize.large),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const Key('s'))), const Size(20, 20));
      expect(tester.getSize(find.byKey(const Key('m'))), const Size(24, 24));
      expect(tester.getSize(find.byKey(const Key('l'))), const Size(32, 32));
      final d = _circleOf(tester, find.byKey(const Key('m')));
      expect(d.color, AvoColors.light.tintSoft);
      expect(d.shape, isA<CircleBorder>());
      final texts = tester.widgetList<Text>(find.text('L')).toList();
      expect(texts, hasLength(3));
      expect(texts[0].style!.fontSize, 11);
      expect(texts[0].style!.fontWeight, FontWeight.w700);
      expect(texts[1].style!.fontSize, 11);
      expect(texts[1].style!.fontWeight, FontWeight.w600);
      expect(texts[0].style!.color, AvoColors.light.tint);
    });

    testWidgets('neutral: label on an opaque grey', (tester) async {
      await _pump(tester, const Avatar(name: 'Jannis', neutral: true));
      final d = _circleOf(tester, find.byType(Avatar));
      expect(d.color!.a, 1);
      expect(
        d.color,
        Color.alphaBlend(AvoColors.light.fill, AvoColors.light.surface),
      );
      expect(
        tester.widget<Text>(find.text('J')).style!.color,
        AvoColors.light.label,
      );
    });

    testWidgets('the glyph keeps its size at AX5', (tester) async {
      await _pump(
        tester,
        const Avatar(name: 'Lena'),
        layout: const LayoutCase(width: 390, scale: 3.1, bold: true),
      );
      expect(tester.getSize(find.byType(Avatar)), const Size(24, 24));
      expect(tester.getSize(find.text('L')).height, lessThanOrEqualTo(24));
      expectNoClippedText(tester);
    });

    testWidgets('VoiceOver reads the name, or that the person shops', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: 'Lena'),
            Avatar(name: 'Max', presence: true),
          ],
        ),
      );
      expect(find.bySemanticsLabel('Lena'), findsOneWidget);
      expect(find.bySemanticsLabel('L'), findsNothing);
      expect(
        find.bySemanticsLabel('Max is shopping right now'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('presence: dot at the bottom corner, -2 / -2', (tester) async {
      await _pump(tester, const Avatar(name: 'Lena', presence: true));
      final avatar = tester.getRect(find.byType(Avatar));
      final dot = tester.getRect(find.byType(PresenceDot));
      expect(dot.size, const Size(9, 9));
      expect(dot.right, avatar.right + 2);
      expect(dot.bottom, avatar.bottom + 2);
    });

    testWidgets('ring: 2 pt outside in the given colour', (tester) async {
      await _pump(
        tester,
        const Avatar(name: 'Lena', ringColor: Color(0xFFF2F2F7)),
      );
      final side =
          (_circleOf(tester, find.byType(Avatar)).shape as CircleBorder).side;
      expect(side.width, 2);
      expect(side.color, const Color(0xFFF2F2F7));
      expect(side.strokeAlign, BorderSide.strokeAlignOutside);
      expect(tester.getSize(find.byType(Avatar)), const Size(24, 24));
    });

    testWidgets('dark mode tokens', (tester) async {
      await _pump(
        tester,
        const Avatar(name: 'Lena'),
        layout: const LayoutCase(
          width: 390,
          scale: 1,
          brightness: Brightness.dark,
        ),
      );
      expect(
        _circleOf(tester, find.byType(Avatar)).color,
        AvoColors.dark.tintSoft,
      );
      expect(
        tester.widget<Text>(find.text('L')).style!.color,
        AvoColors.dark.tint,
      );
    });
  });

  group('AvatarStack', () {
    testWidgets('overlaps 6 pt at 24 pt, first on top, ring in surface', (
      tester,
    ) async {
      await _pump(tester, const AvatarStack(names: ['Jannis', 'Lena', 'Mia']));
      expect(tester.getSize(find.byType(AvatarStack)), const Size(60, 24));
      final j = tester.getRect(find.text('J'));
      final l = tester.getRect(find.text('L'));
      final m = tester.getRect(find.text('M'));
      expect(l.center.dx - j.center.dx, 18);
      expect(m.center.dx - l.center.dx, 18);
      // Painted last to first: "J" is the last child of the stack.
      final stack = tester.widget<Stack>(
        find.descendant(
          of: find.byType(AvatarStack),
          matching: find.byType(Stack),
        ),
      );
      final last = stack.children.last;
      expect(
        find.descendant(of: find.byWidget(last), matching: find.text('J')),
        findsOneWidget,
      );
      final side =
          (_circleOf(tester, find.byWidget(last)).shape as CircleBorder).side;
      expect(side.color, AvoColors.light.surface);
      expect(side.width, 2);
    });

    testWidgets('more than three: three circles and "+2"', (tester) async {
      await _pump(
        tester,
        const AvatarStack(names: ['Jannis', 'Lena', 'Mia', 'Tom', 'Max']),
      );
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('T'), findsNothing);
      final plus = _circleWith(tester, '+2');
      expect(plus.shape, isA<StadiumBorder>());
      expect(tester.getSize(find.byType(AvatarStack)).height, 24);
    });

    testWidgets('one label for the group', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarStack(names: ['Jannis', 'Lena']),
            AvatarStack(
              names: ['Jannis', 'Lena', 'Mia'],
              semanticLabel: 'Geteilt mit Jannis, Lena und Mia',
            ),
          ],
        ),
      );
      expect(find.bySemanticsLabel('Jannis, Lena'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Geteilt mit Jannis, Lena und Mia'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('J'), findsNothing);
      handle.dispose();
    });

    testWidgets('neutral first (the current user) and an empty list', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarStack(names: ['Jannis', 'Lena'], neutralFirst: true),
            AvatarStack(key: Key('empty'), names: []),
          ],
        ),
      );
      final j = _circleWith(tester, 'J');
      expect(
        j.color,
        Color.alphaBlend(AvoColors.light.fill, AvoColors.light.surface),
      );
      expect(tester.getSize(find.byKey(const Key('empty'))), Size.zero);
    });
  });

  group('PresenceDot', () {
    testWidgets('green dot with a ring in the background colour', (
      tester,
    ) async {
      await _pump(tester, const PresenceDot());
      expect(tester.getSize(find.byType(PresenceDot)), const Size(9, 9));
      await tester.pumpAndSettle();
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(PresenceDot),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(
        paint.painter,
        isA<CustomPainter>()
            .having(
              // ignore: avoid_dynamic_calls
              (p) => (p as dynamic).color,
              'color',
              AvoColors.light.presence,
            )
            .having(
              // ignore: avoid_dynamic_calls
              (p) => (p as dynamic).ring,
              'ring',
              AvoColors.light.background,
            ),
      );
    });

    testWidgets('pulses once when it appears, then rests', (tester) async {
      await _pump(tester, const PresenceDot());
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _halo(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pumpAndSettle();
      expect(_halo(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Reduce Motion: static', (tester) async {
      await _pump(
        tester,
        const PresenceDot(),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      expect(_halo(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('pulse off: static', (tester) async {
      await _pump(tester, const PresenceDot(pulse: false));
      expect(_halo(tester), 1);
    });

    testWidgets('VoiceOver: "{name} is shopping right now" or decoration', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PresenceDot(name: 'Lena'),
            PresenceDot(semanticLabel: 'Lena und Max kaufen gerade ein'),
            PresenceDot(),
          ],
        ),
      );
      expect(
        find.bySemanticsLabel('Lena is shopping right now'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Lena und Max kaufen gerade ein'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  layoutMatrix(
    'Presence line and avatar stack (D2 X-Einkaufsmodus, D2-Liste)',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(
                name: 'Lena',
                presence: true,
                ringColor: context.colors.background,
              ),
              const SizedBox(width: AvoSpacing.s),
              Expanded(
                child: Text(
                  'Lena kauft gerade bei Lidl in der Innenstadt ein',
                  style: context.text(AvoTextStyle.subhead),
                ),
              ),
            ],
          ),
          const SizedBox(height: AvoSpacing.m),
          Row(
            children: [
              AvatarStack(
                names: const ['Jannis', 'Lena', 'Mia', 'Tom', 'Max'],
                neutralFirst: true,
                ringColor: context.colors.background,
              ),
              const SizedBox(width: AvoSpacing.s),
              Expanded(
                child: Text(
                  '8 von 12 · ≈ 23,80 €',
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: context.colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AvoSpacing.m),
          const Wrap(
            spacing: AvoSpacing.s,
            children: [
              Avatar(name: 'Lena', size: AvatarSize.small),
              Avatar(name: 'Lena'),
              Avatar(name: 'Lena', size: AvatarSize.large),
            ],
          ),
        ],
      ),
    ),
  );
}
