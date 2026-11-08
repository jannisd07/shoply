import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

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

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      calls.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

/// A stepper that keeps its own value, reporting every change.
Widget _stateful({
  int initial = 3,
  int min = 0,
  int max = 999,
  bool compact = false,
  String? unit = 'St.',
  List<int>? log,
}) {
  var value = initial;
  return StatefulBuilder(
    builder: (context, setState) => ValueStepper(
      value: value,
      min: min,
      max: max,
      compact: compact,
      unit: unit,
      semanticLabel: 'Menge',
      onChanged: (v) {
        log?.add(v);
        setState(() => value = v);
      },
    ),
  );
}

Finder get _minus => find.bySemanticsLabel('Decrease');
Finder get _plus => find.bySemanticsLabel('Increase');

void main() {
  testWidgets('shows the value with its unit', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _stateful(initial: 12, unit: 'Pck.'));
    // One Text per digit (they roll separately).
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Pck.'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ValueStepper)),
      isSemantics(value: '12 Pck.'),
    );
    semantics.dispose();
  });

  testWidgets('plus and minus step by one with the selection haptic', (
    tester,
  ) async {
    final haptics = _haptics(tester);
    final log = <int>[];
    await _pump(tester, _stateful(log: log));
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(_minus);
    await tester.pumpAndSettle();
    await tester.tap(_minus);
    await tester.pumpAndSettle();
    expect(log, [4, 3, 2]);
    expect(haptics, List.filled(3, 'HapticFeedbackType.selectionClick'));
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('minus is disabled at the minimum, plus at the maximum', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final haptics = _haptics(tester);
    final log = <int>[];
    await _pump(tester, _stateful(initial: 1, min: 1, max: 2, log: log));
    expect(
      tester.getSemantics(_minus),
      isSemantics(isEnabled: false, hasTapAction: false),
    );
    await tester.tap(_minus, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(haptics, isEmpty);

    await tester.tap(_plus);
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(
      tester.getSemantics(_plus),
      isSemantics(isEnabled: false, hasTapAction: false),
    );
    expect(
      tester.getSemantics(_minus),
      isSemantics(isEnabled: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('holding repeats, faster the longer it is held', (tester) async {
    _haptics(tester);
    final log = <int>[];
    final times = <int>[];
    var clock = 0;
    await _pump(tester, _stateful(initial: 0, log: log));
    final gesture = await tester.startGesture(tester.getCenter(_plus));
    // Record when each step lands.
    var seen = 0;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      clock += 10;
      while (seen < log.length) {
        times.add(clock);
        seen++;
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final countAtRelease = log.length;
    expect(countAtRelease, greaterThan(10));
    expect(log, List.generate(log.length, (i) => i + 1));
    final firstGap = times[2] - times[1];
    final lastGap = times.last - times[times.length - 2];
    expect(lastGap, lessThan(firstGap));

    await tester.pump(const Duration(seconds: 1));
    expect(log.length, countAtRelease, reason: 'stops on release');
  });

  testWidgets('holding stops at the bound', (tester) async {
    _haptics(tester);
    final log = <int>[];
    await _pump(tester, _stateful(initial: 7, max: 9, log: log));
    final gesture = await tester.startGesture(tester.getCenter(_plus));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(log, [8, 9]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('VoiceOver: one adjustable element plus labelled buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    _haptics(tester);
    final log = <int>[];
    await _pump(tester, _stateful(log: log));
    final group = tester.getSemantics(find.byType(ValueStepper));
    expect(
      group,
      isSemantics(
        label: 'Menge',
        value: '3 St.',
        increasedValue: '4 St.',
        decreasedValue: '2 St.',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    expect(
      tester.getSemantics(_minus),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(_plus),
      isSemantics(isButton: true, hasTapAction: true),
    );

    group.owner!.performAction(group.id, SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(log, [4]);
    final updated = tester.getSemantics(find.byType(ValueStepper));
    updated.owner!.performAction(updated.id, SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(log, [4, 3]);
    semantics.dispose();
  });

  testWidgets('buttons are 44 x 44 pt, regular and compact', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final compact in [false, true]) {
      await _pump(tester, _stateful(compact: compact));
      for (final button in [_minus, _plus]) {
        final size = tester.getSemantics(button).rect.size;
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }
    semantics.dispose();
  });

  testWidgets('visible capsule: 44 pt regular, 34 pt compact', (tester) async {
    Size capsule() => tester.getSize(
      find
          .descendant(
            of: find.byType(ValueStepper),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    await _pump(tester, _stateful());
    expect(capsule().height, 44);
    expect(tester.getSize(find.byType(ValueStepper)).height, 44);
    await _pump(tester, _stateful(compact: true));
    expect(capsule().height, 34);
    expect(tester.getSize(find.byType(ValueStepper)).height, 44);
  });

  testWidgets('grows in height with large text and stays on one line', (
    tester,
  ) async {
    await _pump(
      tester,
      _stateful(initial: 12, unit: 'Pck.'),
      layout: const LayoutCase(width: 320, scale: 3.1),
    );
    final size = tester.getSize(find.byType(ValueStepper));
    expect(size.height, greaterThan(44));
    final value = tester.getRect(find.byType(RollingNumber));
    expect(tester.getRect(_minus).center.dy, closeTo(value.center.dy, 1));
    expect(tester.getRect(_plus).center.dy, closeTo(value.center.dy, 1));
  });

  testWidgets('pressed: the glyph scales down while held', (tester) async {
    _haptics(tester);
    await _pump(tester, _stateful());
    final gesture = await tester.startGesture(tester.getCenter(_plus));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    final scaled = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(ValueStepper),
        matching: find.byType(Transform),
      ),
    );
    expect(scaled, isNotEmpty);
    expect(
      scaled.first.transform.storage[0],
      closeTo(AvoMotion.pressedScale, 0.005),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  layoutMatrix(
    'ValueStepper',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Laktosefreie Bio-Vollmilch',
            style: context.text(AvoTextStyle.body),
          ),
          ValueStepper(
            value: 12,
            unit: 'Pck.',
            semanticLabel: 'Menge',
            onChanged: (_) {},
          ),
          const SizedBox(height: AvoSpacing.s),
          ValueStepper(
            value: 0,
            compact: true,
            semanticLabel: 'Portionen',
            onChanged: (_) {},
          ),
          const SizedBox(height: AvoSpacing.s),
          // Long unit (gallery finding): wraps or scales, never overflows.
          ValueStepper(
            value: 4,
            unit: 'Portionen',
            semanticLabel: 'Portionen',
            onChanged: (_) {},
          ),
        ],
      ),
    ),
    checkTapTargets: true,
  );
}
