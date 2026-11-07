import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';

import '../../../layout/layout_matrix.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(layout, Align(alignment: Alignment.topCenter, child: child)),
  );
}

ShapeDecoration _decoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(ProBadge),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as ShapeDecoration;
}

void main() {
  testWidgets('shows "Pro" in tint on tintSoft', (tester) async {
    await _pump(tester, const ProBadge());
    expect(find.text('Pro'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Pro'));
    expect(text.style?.color, AvoColors.light.tint);
    expect(text.style?.fontWeight, FontWeight.w600);
    final decoration = _decoration(tester);
    expect(decoration.color, AvoColors.light.tintSoft);
    expect((decoration.shape as StadiumBorder).side, BorderSide.none);
  });

  testWidgets('on tint: white text, transparent, outlined', (tester) async {
    await _pump(tester, const ProBadge(onTint: true));
    final text = tester.widget<Text>(find.text('Pro'));
    expect(text.style?.color, AvoColors.light.onTint);
    final decoration = _decoration(tester);
    expect(decoration.color, isNull);
    final side = (decoration.shape as StadiumBorder).side;
    expect(side.color, AvoColors.light.onTint);
    expect(side.width, greaterThan(0));
  });

  testWidgets('dark mode uses the dark tokens', (tester) async {
    await _pump(
      tester,
      const ProBadge(),
      layout: const LayoutCase(
        width: 390,
        scale: 1,
        brightness: Brightness.dark,
      ),
    );
    final text = tester.widget<Text>(find.text('Pro'));
    expect(text.style?.color, AvoColors.dark.tint);
    expect(_decoration(tester).color, AvoColors.dark.tintSoft);
  });

  testWidgets('VoiceOver reads "Pro feature" instead of "Pro"', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const ProBadge());
    expect(find.bySemanticsLabel('Pro feature'), findsOneWidget);
    expect(find.bySemanticsLabel('Pro'), findsNothing);
    handle.dispose();
  });

  testWidgets('appends "Pro feature" to a merged feature name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Builder(
        builder: (context) => MergeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Wochenplan', style: context.text(AvoTextStyle.body)),
              const ProBadge(),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Wochenplan\nPro feature'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('grows with Dynamic Type only up to AX2', (tester) async {
    Future<double> heightAt(double scale) async {
      await _pump(
        tester,
        const ProBadge(),
        layout: LayoutCase(width: 390, scale: scale),
      );
      return tester.getSize(find.byType(ProBadge)).height;
    }

    final large = await heightAt(1);
    final ax2 = await heightAt(2);
    final ax5 = await heightAt(3.1);
    expect(ax2, greaterThan(large));
    expect(ax5, ax2);
  });

  layoutMatrix(
    'ProBadge after a long feature name',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Wrap(
        spacing: AvoSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Wochenplan mit Laktosefreie Bio-Vollmilch für 12,49 €',
            style: context.text(AvoTextStyle.body),
          ),
          const ProBadge(),
        ],
      ),
    ),
  );

  layoutMatrix(
    'ProBadge on a tinted fill',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: ColoredBox(
        color: context.colors.tintFill,
        child: const Padding(
          padding: EdgeInsets.all(AvoSpacing.m),
          child: ProBadge(onTint: true),
        ),
      ),
    ),
  );
}
