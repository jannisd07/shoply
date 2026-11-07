import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

import '../../../layout/layout_matrix.dart';

Widget _harness(
  Widget child, {
  double textScale = 1,
  bool disableAnimations = false,
  double width = 390,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, 844),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AvoDesignScope(
        reduceTransparencyOverride: false,
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

Finder get _button => find.byType(AppButton);

double _scale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(PressableScale),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[0]; // x scale

double _pressOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byType(PressableScale),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  group('variants', () {
    testWidgets('primary: opaque tint capsule with white label in content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AppButton.primary(label: 'Zutaten auf die Liste', onPressed: () {}),
        ),
      );

      final glass = tester.widget<ContentGlass>(find.byType(ContentGlass));
      expect(glass.tinted, isTrue);
      expect(glass.radius, 22);
      expect(find.byType(GlassSurface), findsNothing);
      expect(
        _labelColor(tester, 'Zutaten auf die Liste'),
        AvoColors.light.onTint,
      );
      final style = tester
          .widget<Text>(find.text('Zutaten auf die Liste'))
          .style!;
      expect(style.fontWeight, FontWeight.w600);
      // 15/20 subhead at the default size.
      expect(style.fontSize, 15);
    });

    testWidgets('primary floating uses tinted glass', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton.primary(label: 'Fertig', floating: true, onPressed: () {}),
        ),
      );

      final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(surface.tinted, isTrue);
      expect(surface.shape, GlassShape.rounded);
      expect(surface.radius, 22);
      expect(find.byType(ContentGlass), findsNothing);
    });

    testWidgets(
      'primary floating on iOS uses the native glass, in content not',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton.primary(
                  label: 'Fertig',
                  floating: true,
                  onPressed: () {},
                ),
                AppButton.primary(label: 'Speichern', onPressed: () {}),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidGlassContainer), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(AppButton, 'Speichern'),
            matching: find.byType(LiquidGlassContainer),
          ),
          findsNothing,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('secondary: glass capsule with label colour', (tester) async {
      await tester.pumpWidget(
        _harness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.secondary(label: 'Teilen', onPressed: () {}),
              AppButton.secondary(
                label: 'Mehr',
                floating: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final content = tester.widget<ContentGlass>(find.byType(ContentGlass));
      expect(content.tinted, isFalse);
      final floating = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(floating.tinted, isFalse);
      expect(_labelColor(tester, 'Teilen'), AvoColors.light.label);
    });

    testWidgets('plain and destructive are text buttons, 17 pt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.plain(label: 'Alle anzeigen', onPressed: () {}),
              AppButton.destructive(label: 'Liste löschen', onPressed: () {}),
            ],
          ),
        ),
      );

      expect(find.byType(ContentGlass), findsNothing);
      expect(find.byType(GlassSurface), findsNothing);
      expect(_labelColor(tester, 'Alle anzeigen'), AvoColors.light.tint);
      expect(_labelColor(tester, 'Liste löschen'), AvoColors.light.destructive);
      final style = tester.widget<Text>(find.text('Alle anzeigen')).style!;
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w400);
    });

    testWidgets('icon is 18 pt in the label colour and scales with text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AppButton.primary(
            label: 'Zutaten auf die Liste',
            icon: const Icon(CupertinoIcons.add),
            onPressed: () {},
          ),
        ),
      );
      var theme = IconTheme.of(tester.element(find.byType(Icon)));
      expect(theme.size, 18);
      expect(theme.color, AvoColors.light.onTint);

      await tester.pumpWidget(
        _harness(
          AppButton.primary(
            label: 'Zutaten auf die Liste',
            icon: const Icon(CupertinoIcons.add),
            onPressed: () {},
          ),
          textScale: 1.35,
        ),
      );
      theme = IconTheme.of(tester.element(find.byType(Icon)));
      expect(theme.size, greaterThan(18));
    });
  });

  group('states', () {
    testWidgets('tap calls onPressed, without haptics', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          AppButton.primary(label: 'Speichern', onPressed: () => taps++),
        ),
      );

      await tester.tap(_button);
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
    });

    testWidgets('pressed: shrinks on touch down, before release', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(AppButton.primary(label: 'Speichern', onPressed: () {})),
      );
      expect(_scale(tester), 1);

      final gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_scale(tester), closeTo(AvoMotion.pressedScale, 0.002));
      expect(_pressOpacity(tester), closeTo(0.9, 0.002));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
      expect(_pressOpacity(tester), 1);
    });

    testWidgets('pressed: release mid-way continues from the current value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(AppButton.secondary(label: 'Teilen', onPressed: () {})),
      );

      final gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final midway = _scale(tester);
      expect(midway, lessThan(1));
      expect(midway, greaterThan(AvoMotion.pressedScale));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final after = _scale(tester);
      // No jump back to 1 and no jump to the pressed end: it springs on.
      expect(after, lessThan(1));
      expect(after, greaterThan(AvoMotion.pressedScale - 0.001));
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
    });

    testWidgets('reduce motion: no scale, only the fade', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton.primary(label: 'Speichern', onPressed: () {}),
          disableAnimations: true,
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      await tester.pump(AvoMotion.fadeReduced);

      expect(_scale(tester), 1);
      expect(_pressOpacity(tester), closeTo(0.9, 0.002));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_pressOpacity(tester), 1);
    });

    testWidgets('disabled: 40 % opacity, no tap, VoiceOver dimmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const AppButton.primary(label: 'Speichern')),
      );

      expect(
        find.descendant(
          of: _button,
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == 0.4,
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_button),
        isSemantics(
          label: 'Speichern',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_scale(tester), 1);
      await gesture.up();
    });

    testWidgets('working: indicator replaces the icon, width stays, no taps', (
      tester,
    ) async {
      var taps = 0;
      Widget build({required bool working}) => _harness(
        AppButton.primary(
          label: 'Einkauf abschließen',
          icon: const Icon(CupertinoIcons.cart),
          working: working,
          workingLabel: 'In Bearbeitung',
          onPressed: () => taps++,
        ),
      );

      await tester.pumpWidget(build(working: false));
      final idle = tester.getSize(_button);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      await tester.pumpWidget(build(working: true));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Einkauf abschließen'), findsOneWidget);
      expect(tester.getSize(_button), idle);

      await tester.tap(_button);
      await tester.pump();
      expect(taps, 0);
      expect(_scale(tester), 1);
      expect(
        tester.getSemantics(_button),
        isSemantics(
          label: 'Einkauf abschließen',
          value: 'In Bearbeitung',
          isButton: true,
          isLiveRegion: true,
          isEnabled: true,
          hasTapAction: false,
        ),
      );
    });

    testWidgets('working without an icon keeps the width', (tester) async {
      Widget build({required bool working}) => _harness(
        AppButton.secondary(
          label: 'Teilen',
          working: working,
          onPressed: () {},
        ),
      );

      await tester.pumpWidget(build(working: false));
      final idle = tester.getSize(_button);
      await tester.pumpWidget(build(working: true));
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(tester.getSize(_button), idle);
    });
  });

  group('accessibility', () {
    testWidgets('semantics: button with label and tap action', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton.primary(
            label: 'Zutaten auf die Liste',
            icon: const Icon(CupertinoIcons.add),
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(_button),
        isSemantics(
          label: 'Zutaten auf die Liste',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isLiveRegion: false,
        ),
      );
    });

    testWidgets('every variant is at least 44 × 44 pt', (tester) async {
      await tester.pumpWidget(
        _harness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.plain(label: 'OK', onPressed: () {}),
              AppButton.destructive(label: 'Aus', onPressed: () {}),
              AppButton.primary(label: 'Ja', onPressed: () {}),
              AppButton.secondary(label: 'Teilen', onPressed: () {}),
            ],
          ),
        ),
      );

      for (final element in find.byType(AppButton).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('large is 54 pt high and a 27 pt capsule', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton.primary(
            label: 'Einkauf abschließen',
            size: AppButtonSize.large,
            onPressed: () {},
          ),
        ),
      );

      expect(tester.getSize(_button).height, 54);
      expect(tester.widget<ContentGlass>(find.byType(ContentGlass)).radius, 27);
      expect(
        tester.widget<Text>(find.text('Einkauf abschließen')).style!.fontSize,
        17,
      );
    });

    testWidgets('expand fills the width', (tester) async {
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 300,
            child: AppButton.primary(
              label: 'Einkauf abschließen',
              expand: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(tester.getSize(_button).width, 300);
    });

    testWidgets('AX5: label wraps, never clipped, radius drops to 22', (
      tester,
    ) async {
      await loadLayoutFonts();
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 288,
            child: AppButton.primary(
              label: 'Laktosefreie Bio-Vollmilch hinzufügen',
              size: AppButtonSize.large,
              expand: true,
              icon: const Icon(CupertinoIcons.add),
              onPressed: () {},
            ),
          ),
          textScale: 3.1,
          width: 320,
        ),
      );

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      final text = find.text('Laktosefreie Bio-Vollmilch hinzufügen');
      final lineHeight = tester.getSize(text).height;
      expect(lineHeight, greaterThan(100), reason: 'wraps to several lines');
      expect(tester.getSize(_button).height, greaterThan(54));
      expect(tester.widget<ContentGlass>(find.byType(ContentGlass)).radius, 22);
    });
  });

  layoutMatrix(
    'AppButton',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppButton.primary(
            label: 'Zutaten auf die Liste',
            icon: const Icon(CupertinoIcons.add),
            onPressed: () {},
          ),
          const SizedBox(height: AvoSpacing.s),
          AppButton.secondary(
            label: 'Teilen',
            icon: const Icon(CupertinoIcons.share),
            floating: true,
            onPressed: () {},
          ),
          const SizedBox(height: AvoSpacing.s),
          AppButton.primary(
            label: 'Laktosefreie Bio-Vollmilch hinzufügen',
            working: true,
            workingLabel: 'In Bearbeitung',
            onPressed: () {},
          ),
          AppButton.plain(label: 'Alle anzeigen', onPressed: () {}),
          AppButton.destructive(label: 'Liste löschen', onPressed: () {}),
          const AppButton.secondary(label: 'Vollkornbrot (nicht verfügbar)'),
          const SizedBox(height: AvoSpacing.s),
          AppButton.primary(
            label: 'Einkauf abschließen · 23,80 €',
            size: AppButtonSize.large,
            expand: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
