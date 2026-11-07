import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

import '../../../layout/layout_matrix.dart';

Widget _harness(
  Widget child, {
  bool reduceTransparency = false,
  bool highContrast = false,
  Brightness brightness = Brightness.light,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      highContrast: highContrast,
      platformBrightness: brightness,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
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

ShapeDecoration _decorationIn(WidgetTester tester, Type type) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byType(type), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as ShapeDecoration;
}

const _chip = SizedBox(width: 120, height: 32);

void main() {
  group('GlassSurface', () {
    testWidgets('fallback off iOS: translucent glass, hairline, D2 shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const GlassSurface(child: _chip)));

      expect(find.byType(LiquidGlassContainer), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      final decoration = _decorationIn(tester, GlassSurface);
      expect(decoration.color, AvoColors.light.glassFill);
      final shape = decoration.shape as StadiumBorder;
      expect(shape.side.color, AvoColors.light.glassBorder);
      expect(shape.side.width, AvoSizes.hairline);
      expect(decoration.shadows, hasLength(2));
      expect(decoration.shadows!.last.offset, const Offset(0, 6));
      expect(decoration.shadows!.last.blurRadius, 20);
    });

    testWidgets('fallback tinted uses glass-tint fill and tint shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const GlassSurface(tinted: true, child: _chip)),
      );

      final decoration = _decorationIn(tester, GlassSurface);
      expect(decoration.color, AvoColors.light.glassTintFill);
      expect(
        (decoration.shape as StadiumBorder).side.color,
        AvoColors.light.glassTintBorder,
      );
      expect(decoration.shadows, hasLength(1));
      expect(decoration.shadows!.single.blurRadius, 18);
      expect(decoration.shadows!.single.color.a, closeTo(0.30, 0.01));
    });

    testWidgets('reduce transparency shows an opaque surface', (tester) async {
      await tester.pumpWidget(
        _harness(const GlassSurface(child: _chip), reduceTransparency: true),
      );

      final decoration = _decorationIn(tester, GlassSurface);
      expect(decoration.color, AvoColors.light.glassFallback);
      expect(decoration.color!.a, 1.0);
      expect(
        (decoration.shape as StadiumBorder).side.color,
        AvoColors.light.separator,
      );
    });

    testWidgets('reduce transparency tinted is the opaque tint fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const GlassSurface(tinted: true, child: _chip),
          reduceTransparency: true,
        ),
      );

      final decoration = _decorationIn(tester, GlassSurface);
      expect(decoration.color, AvoColors.light.tintFill);
      expect(decoration.color!.a, 1.0);
    });

    testWidgets('increase contrast: opaque with the strong outline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const GlassSurface(child: _chip), highContrast: true),
      );

      final decoration = _decorationIn(tester, GlassSurface);
      expect(decoration.color, AvoColors.lightHighContrast.glassFallback);
      expect(decoration.color!.a, 1.0);
      expect(
        (decoration.shape as StadiumBorder).side.color,
        AvoColors.lightHighContrast.glassBorder,
      );
    });

    testWidgets('dark mode uses the dark glass tokens', (tester) async {
      await tester.pumpWidget(
        _harness(const GlassSurface(child: _chip), brightness: Brightness.dark),
      );

      expect(
        _decorationIn(tester, GlassSurface).color,
        AvoColors.dark.glassFill,
      );
    });

    testWidgets('rounded shape uses the given radius', (tester) async {
      await tester.pumpWidget(
        _harness(
          const GlassSurface(
            shape: GlassShape.rounded,
            radius: AvoRadii.card,
            child: _chip,
          ),
        ),
      );

      final shape =
          _decorationIn(tester, GlassSurface).shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AvoRadii.card));
    });

    testWidgets('takes its size from the child plus padding', (tester) async {
      await tester.pumpWidget(
        _harness(
          const GlassSurface(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: _chip,
          ),
        ),
      );

      expect(tester.getSize(find.byType(GlassSurface)), const Size(144, 40));
    });

    testWidgets(
      'on iOS draws the native glass behind the child',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const GlassSurface(
              tinted: true,
              interactive: true,
              child: Text('mit Lena'),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final glass = tester.widget<LiquidGlassContainer>(
          find.byType(LiquidGlassContainer),
        );
        expect(glass.isCircle, isTrue);
        expect(glass.interactive, isTrue);
        expect(glass.tint, AvoColors.light.glassTintFill);
        // The glass is decoration: VoiceOver reads only the child.
        expect(find.bySemanticsLabel('mit Lena'), findsOneWidget);
        // Size comes from the child, the glass fills it.
        expect(
          tester.getSize(find.byType(LiquidGlassContainer)),
          tester.getSize(find.byType(GlassSurface)),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'on iOS a rounded surface passes its radius',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const GlassSurface(
              shape: GlassShape.rounded,
              radius: AvoRadii.card,
              child: _chip,
            ),
          ),
        );

        final glass = tester.widget<LiquidGlassContainer>(
          find.byType(LiquidGlassContainer),
        );
        expect(glass.isCircle, isFalse);
        expect(glass.cornerRadius, AvoRadii.card);
        expect(glass.tint, isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'on iOS reduce transparency replaces the native glass',
      (tester) async {
        await tester.pumpWidget(
          _harness(const GlassSurface(child: _chip), reduceTransparency: true),
        );

        expect(find.byType(LiquidGlassContainer), findsNothing);
        final decoration = _decorationIn(tester, GlassSurface);
        expect(decoration.color, AvoColors.light.glassFallback);
        expect(decoration.color!.a, 1.0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('ContentGlass', () {
    testWidgets('light: white at 78 % with a hairline and soft shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const ContentGlass(child: _chip)));

      final decoration = _decorationIn(tester, ContentGlass);
      expect(decoration.color, AvoColors.light.surface.withValues(alpha: .78));
      final shape = decoration.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AvoRadii.card));
      expect(shape.side.width, AvoSizes.hairline);
      expect(decoration.shadows, isNotEmpty);
    });

    testWidgets('dark: glass fallback at 85 %', (tester) async {
      await tester.pumpWidget(
        _harness(const ContentGlass(child: _chip), brightness: Brightness.dark),
      );

      expect(
        _decorationIn(tester, ContentGlass).color,
        AvoColors.dark.glassFallback.withValues(alpha: .85),
      );
    });

    testWidgets('reduce transparency: opaque', (tester) async {
      await tester.pumpWidget(
        _harness(const ContentGlass(child: _chip), reduceTransparency: true),
      );

      final decoration = _decorationIn(tester, ContentGlass);
      expect(decoration.color, AvoColors.light.glassFallback);
      expect(decoration.color!.a, 1.0);
    });

    testWidgets('tinted: opaque tint fill', (tester) async {
      await tester.pumpWidget(
        _harness(const ContentGlass(tinted: true, child: _chip)),
      );

      final decoration = _decorationIn(tester, ContentGlass);
      expect(decoration.color, AvoColors.light.tintFill);
      expect(decoration.color!.a, 1.0);
    });

    testWidgets(
      'never creates a platform view, also on iOS',
      (tester) async {
        await tester.pumpWidget(_harness(const ContentGlass(child: _chip)));

        expect(find.byType(LiquidGlassContainer), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.getSize(find.byType(ContentGlass)), const Size(120, 32));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  layoutMatrix(
    'GlassSurface',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassSurface(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.m),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  '4 von 6 Zutaten da',
                  style: context.text(
                    AvoTextStyle.footnote,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AvoSpacing.m),
          GlassSurface(
            shape: GlassShape.rounded,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Laktosefreie Bio-Vollmilch',
                  style: context.text(AvoTextStyle.title2),
                ),
                Text(
                  '1,49 € · 0,99 € im Angebot · 2 L',
                  style: context.text(
                    AvoTextStyle.footnote,
                    color: context.colors.tertiaryLabel,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  layoutMatrix(
    'ContentGlass',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: ContentGlass(
        radius: AvoRadii.capsule(28),
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(dimension: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'mit Lena und Maximilian-Alexander',
                style: context.text(
                  AvoTextStyle.caption1,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
