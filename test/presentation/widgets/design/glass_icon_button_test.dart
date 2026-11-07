import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

import '../../../layout/layout_matrix.dart';

Widget _harness(Widget child, {bool reduceTransparency = false}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AvoDesignScope(
        reduceTransparencyOverride: reduceTransparency,
        child: Builder(
          builder: (context) => ColoredBox(
            color: context.colors.background,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

double _scaleIn(WidgetTester tester, Finder of) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.descendant(of: of, matching: find.byType(PressableScale)),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[0]; // x scale

IconThemeData _iconTheme(WidgetTester tester, Finder icon) =>
    IconTheme.of(tester.element(icon));

void main() {
  group('GlassIconButton', () {
    testWidgets('44 pt glass circle with a 22 pt label-coloured icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          GlassIconButton(
            icon: const Icon(CupertinoIcons.chevron_back),
            semanticLabel: 'Zurück',
            onPressed: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(GlassIconButton)), const Size(44, 44));
      final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(surface.shape, GlassShape.circle);
      expect(surface.tinted, isFalse);
      final theme = _iconTheme(tester, find.byType(Icon));
      expect(theme.size, 22);
      expect(theme.color, AvoColors.light.label);
    });

    testWidgets('tinted: glass-tint circle, white icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          GlassIconButton(
            icon: const Icon(CupertinoIcons.add),
            semanticLabel: 'Neue Liste',
            tinted: true,
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).tinted,
        isTrue,
      );
      expect(
        _iconTheme(tester, find.byType(Icon)).color,
        AvoColors.light.onTint,
      );
    });

    testWidgets('not floating: pseudo glass, a circle of radius 22', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          GlassIconButton(
            icon: const Icon(CupertinoIcons.heart),
            semanticLabel: 'Merken',
            floating: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(GlassSurface), findsNothing);
      expect(tester.widget<ContentGlass>(find.byType(ContentGlass)).radius, 22);
    });

    testWidgets(
      'on iOS: native glass when floating, none in content',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconButton(
                  icon: const Icon(CupertinoIcons.chevron_back),
                  semanticLabel: 'Zurück',
                  onPressed: () {},
                ),
                GlassIconButton(
                  icon: const Icon(CupertinoIcons.heart),
                  semanticLabel: 'Merken',
                  floating: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidGlassContainer), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('tap, pressed scale on touch down', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          GlassIconButton(
            icon: const Icon(CupertinoIcons.chevron_back),
            semanticLabel: 'Zurück',
            onPressed: () => taps++,
          ),
        ),
      );
      final button = find.byType(GlassIconButton);

      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_scaleIn(tester, button), closeTo(AvoMotion.pressedScale, 0.002));
      expect(taps, 0, reason: 'commits on release, not on touch down');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(_scaleIn(tester, button), 1);
    });

    testWidgets('semantics: labelled button; disabled is dimmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassIconButton(
                icon: const Icon(CupertinoIcons.chevron_back),
                semanticLabel: 'Zurück zu Wocheneinkauf',
                onPressed: () {},
              ),
              const GlassIconButton(
                icon: Icon(CupertinoIcons.trash),
                semanticLabel: 'Löschen',
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(GlassIconButton).first),
        isSemantics(
          label: 'Zurück zu Wocheneinkauf',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      final disabled = find.byType(GlassIconButton).last;
      expect(
        tester.getSemantics(disabled),
        isSemantics(
          label: 'Löschen',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      expect(
        find.descendant(
          of: disabled,
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == 0.4,
          ),
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  group('GlassButtonGroup', () {
    testWidgets('one capsule, 44 × 44 hit area per button', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _harness(
          GlassButtonGroup(
            items: [
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.share),
                semanticLabel: 'Teilen',
                onPressed: () => tapped.add('share'),
              ),
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                semanticLabel: 'Mehr',
                onPressed: () => tapped.add('more'),
              ),
            ],
          ),
        ),
      );

      // D2: 4 + 40 + 40 + 4 = 88 wide, 44 high.
      expect(tester.getSize(find.byType(GlassButtonGroup)), const Size(88, 44));
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).shape,
        GlassShape.capsule,
      );
      final buttons = find.byType(PressableScale);
      expect(buttons, findsNWidgets(2));
      for (final element in buttons.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)),
          const Size(44, 44),
        );
      }
      expect(_iconTheme(tester, find.byType(Icon).first).size, 22);

      await tester.tap(find.bySemanticsLabel('Mehr'));
      await tester.tap(find.bySemanticsLabel('Teilen'));
      expect(tapped, ['more', 'share']);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('each item is its own button; disabled item is dimmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          GlassButtonGroup(
            items: [
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.bookmark),
                semanticLabel: 'Gespeichert',
                onPressed: () {},
              ),
              const GlassGroupItem(
                icon: Icon(CupertinoIcons.ellipsis),
                semanticLabel: 'Mehr',
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Gespeichert')),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mehr')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
    });

    testWidgets('a single item keeps the D2 padding (48 wide)', (tester) async {
      await tester.pumpWidget(
        _harness(
          GlassButtonGroup(
            items: [
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                semanticLabel: 'Mehr',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(tester.getSize(find.byType(GlassButtonGroup)), const Size(48, 44));
    });

    testWidgets('pressing one item scales only that item', (tester) async {
      await tester.pumpWidget(
        _harness(
          GlassButtonGroup(
            items: [
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.share),
                semanticLabel: 'Teilen',
                onPressed: () {},
              ),
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                semanticLabel: 'Mehr',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final first = find.byType(PressableScale).first;
      final gesture = await tester.startGesture(tester.getCenter(first));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      double scaleOf(Finder f) => tester
          .widget<Transform>(
            find.descendant(of: f, matching: find.byType(Transform)).first,
          )
          .transform
          .storage[0];
      expect(scaleOf(first), closeTo(AvoMotion.pressedScale, 0.002));
      expect(scaleOf(find.byType(PressableScale).last), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'on iOS the capsule is native glass',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            GlassButtonGroup(
              items: [
                GlassGroupItem(
                  icon: const Icon(CupertinoIcons.share),
                  semanticLabel: 'Teilen',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidGlassContainer), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  layoutMatrix(
    'GlassIconButton + GlassButtonGroup',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Row(
        children: [
          GlassIconButton(
            icon: const Icon(CupertinoIcons.chevron_back),
            semanticLabel: 'Zurück zu Laktosefreie Bio-Vollmilch',
            onPressed: () {},
          ),
          const Spacer(),
          GlassButtonGroup(
            items: [
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.share),
                semanticLabel: 'Teilen',
                onPressed: () {},
              ),
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                semanticLabel: 'Mehr',
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(width: AvoSpacing.s),
          GlassIconButton(
            icon: const Icon(CupertinoIcons.add),
            semanticLabel: 'Neue Liste',
            tinted: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
    checkTapTargets: true,
  );
}
