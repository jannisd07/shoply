import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/lists/widgets/add_item_composer.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';

/// A3: on iOS the composer clipped its text (owner's mother, iPhone 13 Pro,
/// display zoom "Larger Text" = 320 pt, and larger text sizes at 390 pt).
/// The field must always be at least as tall as its text needs.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double scale,
  String text = '',
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final controller = TextEditingController(text: text);
  final focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 844),
        textScaler: TextScaler.linear(scale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // Same insets as list_detail_screen.dart (left/right 10).
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AddItemComposer(
                controller: controller,
                focusNode: focus,
                onSubmit: (_) {},
                onPlusTap: () {},
                plusButtonKey: GlobalKey(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Let post-frame measurement (if any) settle.
  await tester.pumpAndSettle();
}

void _expectFieldNotClipped(WidgetTester tester, String label) {
  final box = tester.renderObject<RenderBox>(find.byType(TextField));
  final needed = box.getMinIntrinsicHeight(box.size.width);
  expect(
    box.size.height,
    greaterThanOrEqualTo(needed - 0.5),
    reason: '$label: field is ${box.size.height.toStringAsFixed(1)} pt tall '
        'but its text needs ${needed.toStringAsFixed(1)} pt',
  );
}

void main() {
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

  for (final width in [320.0, 375.0, 390.0, 402.0, 440.0]) {
    for (final scale in [1.0, 1.35, 2.0, 3.1]) {
      testWidgets('placeholder fits at $width pt, text x$scale',
          (tester) async {
        await _pump(tester, width: width, scale: scale);
        expect(find.byType(LiquidGlassGroup), findsOneWidget,
            reason: 'the iOS glass path must be the one under test');
        _expectFieldNotClipped(tester, 'empty');
      }, variant: iOS);

      testWidgets('long entry wraps instead of clipping at $width pt, '
          'text x$scale', (tester) async {
        await _pump(
          tester,
          width: width,
          scale: scale,
          text: 'Laktosefreie Bio-Vollmilch 3,8 % für den Kaffee am Morgen',
        );
        _expectFieldNotClipped(tester, 'long text');
      }, variant: iOS);
    }
  }
}
