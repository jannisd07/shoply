import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/select_circle.dart';

import '../../../layout/layout_matrix.dart';

const _label = 'Spaghetti Bolognese';

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

void main() {
  testWidgets('22 pt glyph in a 44 pt target', (tester) async {
    await _pump(
      tester,
      SelectCircle(selected: false, onChanged: (_) {}, semanticLabel: _label),
    );
    expect(tester.getSize(find.byType(SelectCircle)), const Size(44, 44));
    // The ring is 22 pt wide: the only 22 pt square inside the target.
    final ring = find.descendant(
      of: find.byType(SelectCircle),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 22 && w.height == 22,
      ),
    );
    expect(ring, findsOneWidget);
    expect(CheckCircle.smallDiameter, 22);
    final decoration = tester.widget<DecoratedBox>(
      find.descendant(of: ring, matching: find.byType(DecoratedBox)),
    );
    final shape = (decoration.decoration as ShapeDecoration).shape;
    expect((shape as CircleBorder).side.color, AvoColors.light.uncheckedRing);
  });

  testWidgets('selected: checkmark circle in tint', (tester) async {
    await _pump(
      tester,
      SelectCircle(selected: true, onChanged: (_) {}, semanticLabel: _label),
    );
    final icon = tester.widget<AvoIcon>(find.byType(AvoIcon));
    expect(icon.icon, same(AvoIcons.checkmarkCircleFill));
    expect(icon.size, 22);
    expect(icon.color, AvoColors.light.tint);
  });

  testWidgets('a tap reports the opposite, without any haptic', (tester) async {
    final haptics = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final values = <bool>[];
    await _pump(
      tester,
      SelectCircle(
        selected: false,
        onChanged: values.add,
        semanticLabel: _label,
      ),
    );
    await tester.tap(find.byType(SelectCircle));
    // The corner of the 44 pt target outside the glyph still counts.
    final rect = tester.getRect(find.byType(SelectCircle));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    expect(values, [true, true]);
    expect(haptics, isEmpty);
  });

  testWidgets('null onChanged: dimmed, no tap', (tester) async {
    await _pump(
      tester,
      const SelectCircle(
        selected: true,
        onChanged: null,
        semanticLabel: _label,
      ),
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(SelectCircle),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      lessThan(1),
    );
    await tester.tap(find.byType(SelectCircle));
  });

  testWidgets('VoiceOver: a switch with the label, no check-off wording', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final values = <bool>[];
    await _pump(
      tester,
      SelectCircle(
        selected: true,
        onChanged: values.add,
        semanticLabel: _label,
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel(_label));
    expect(
      node,
      isSemantics(
        label: _label,
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp('abhaken|Check off')), findsNothing);
    tester.semantics.tap(find.semantics.byLabel(_label));
    expect(values, [false]);
    handle.dispose();
  });

  layoutMatrix(
    'SelectCircle: selected and open next to long text',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        children: [
          for (final selected in const [false, true])
            Row(
              children: [
                SelectCircle(
                  selected: selected,
                  onChanged: (_) {},
                  semanticLabel: _label,
                ),
                Expanded(
                  child: Text(
                    'Spaghetti Bolognese mit Rinderhack und Tomaten',
                    style: context.text(AvoTextStyle.body),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
