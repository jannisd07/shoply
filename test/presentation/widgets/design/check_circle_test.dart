import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';

import '../../../layout/layout_matrix.dart';

const _name = 'Laktosefreie Bio-Vollmilch';

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

/// Fill progress of the circle (0 = ring, 1 = filled with check mark).
double _fill(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(CheckCircle),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  // ignore: avoid_dynamic_calls
  return ((paint.painter as dynamic).progress as Animation<double>).value;
}

bool _failedPaint(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(CheckCircle),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  // ignore: avoid_dynamic_calls
  return (paint.painter as dynamic).failed as bool;
}

Widget _toggling({
  bool initial = false,
  CheckCircleSize size = CheckCircleSize.regular,
  void Function(bool)? onChanged,
}) {
  var checked = initial;
  return StatefulBuilder(
    builder: (context, setState) => CheckCircle(
      checked: checked,
      itemName: _name,
      size: size,
      onChanged: (value) {
        onChanged?.call(value);
        setState(() => checked = value);
      },
    ),
  );
}

void main() {
  group('CheckCircle states', () {
    testWidgets('open: ring only, VoiceOver offers to check it off', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        CheckCircle(checked: false, itemName: _name, onChanged: (_) {}),
      );
      expect(_fill(tester), 0);
      expect(
        tester.getSemantics(find.byType(CheckCircle)),
        isSemantics(
          label: 'Check off $_name',
          value: '',
          isButton: true,
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('done: filled, checked, value "done"', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        CheckCircle(checked: true, itemName: _name, onChanged: (_) {}),
      );
      expect(_fill(tester), 1);
      expect(
        tester.getSemantics(find.byType(CheckCircle)),
        isSemantics(
          label: 'Uncheck $_name',
          value: 'done',
          hasCheckedState: true,
          isChecked: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('tap reports !checked and plays the light haptic', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      final changes = <bool>[];
      await _pump(tester, _toggling(onChanged: changes.add));
      await tester.tap(find.byType(CheckCircle));
      await tester.pump();
      expect(changes, [true]);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await tester.pumpAndSettle();
      expect(_fill(tester), 1);

      await tester.tap(find.byType(CheckCircle));
      await tester.pumpAndSettle();
      expect(changes, [true, false]);
      expect(haptics, hasLength(2));
      expect(_fill(tester), 0);
    });

    testWidgets('fills on the spring from the centre', (tester) async {
      _haptics(tester);
      await _pump(tester, _toggling());
      await tester.tap(find.byType(CheckCircle));
      await tester.pump();
      final samples = <double>[];
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(_fill(tester));
      }
      expect(samples.first, greaterThan(0));
      expect(samples.last, lessThan(1));
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }
      await tester.pumpAndSettle();
      expect(_fill(tester), 1);
    });

    testWidgets('tapping during the fill reverses from the current position', (
      tester,
    ) async {
      _haptics(tester);
      await _pump(tester, _toggling());
      await tester.tap(find.byType(CheckCircle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _fill(tester);
      expect(mid, inExclusiveRange(0.0, 1.0));

      await tester.tap(find.byType(CheckCircle));
      await tester.pump();
      final atReverse = _fill(tester);
      expect(atReverse, inExclusiveRange(0.0, 1.0));
      expect((atReverse - mid).abs(), lessThan(0.05), reason: 'no jump');

      // Frame by frame: no step larger than a normal spring frame.
      var previous = atReverse;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final v = _fill(tester);
        expect((v - previous).abs(), lessThan(0.2));
        previous = v;
      }
      await tester.pumpAndSettle();
      expect(_fill(tester), 0);
    });

    testWidgets('Reduce Motion switches at once', (tester) async {
      _haptics(tester);
      await _pump(
        tester,
        _toggling(),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      await tester.tap(find.byType(CheckCircle));
      await tester.pump();
      expect(_fill(tester), 1);
    });

    testWidgets('disabled: no tap, VoiceOver reads it as disabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final haptics = _haptics(tester);
      await _pump(tester, const CheckCircle(checked: false, itemName: _name));
      await tester.tap(find.byType(CheckCircle), warnIfMissed: false);
      await tester.pump();
      expect(haptics, isEmpty);
      expect(
        tester.getSemantics(find.byType(CheckCircle)),
        isSemantics(
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('pending shows the sync mark', (tester) async {
      await _pump(
        tester,
        CheckCircle(
          checked: true,
          itemName: _name,
          state: CheckState.pending,
          statusLabel: 'wartet auf Verbindung',
          onChanged: (_) {},
        ),
      );
      expect(find.byIcon(CupertinoIcons.arrow_2_circlepath), findsOneWidget);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(CheckCircle)),
        isSemantics(value: 'done, wartet auf Verbindung'),
      );
      semantics.dispose();
    });

    testWidgets('failed: red ring with exclamation, "Not saved"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        CheckCircle(
          checked: true,
          itemName: _name,
          state: CheckState.failed,
          onChanged: (_) {},
        ),
      );
      expect(_failedPaint(tester), isTrue);
      expect(
        tester.getSemantics(find.byType(CheckCircle)),
        isSemantics(value: 'Not saved'),
      );
      semantics.dispose();
    });

    testWidgets('done by someone else shows their initial for 2 s', (
      tester,
    ) async {
      await _pump(
        tester,
        CheckCircle(checked: false, itemName: _name, onChanged: (_) {}),
      );
      expect(find.text('L'), findsNothing);
      await _pump(
        tester,
        CheckCircle(
          checked: true,
          itemName: _name,
          state: CheckState.doneByOther,
          byName: 'Lena',
          onChanged: (_) {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('L'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('L'), findsNothing);
      expect(_fill(tester), 1);
    });

    testWidgets('pressed: scales down while the finger is down', (
      tester,
    ) async {
      _haptics(tester);
      await _pump(tester, _toggling());
      Iterable<Transform> scales() => tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(CheckCircle),
          matching: find.byType(Transform),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CheckCircle)),
      );
      // Tap-down fires after the press timeout; the spring runs from the
      // next frame on.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      expect(scales(), isNotEmpty);
      expect(
        scales().first.transform.storage[0],
        closeTo(AvoMotion.pressedScale, 0.005),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scales(), isEmpty);
    });
  });

  group('CheckCircle touch targets', () {
    testWidgets('regular: 26 pt circle in a 44 pt target', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        CheckCircle(checked: false, itemName: _name, onChanged: (_) {}),
      );
      expect(tester.getSize(find.byType(CheckCircle)), const Size(44, 44));
      expect(
        tester.getSemantics(find.byType(CheckCircle)).rect.size,
        const Size(44, 44),
      );
      final circle = find.descendant(
        of: find.byType(CheckCircle),
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(circle.first), const Size(26, 26));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('large: 36 pt circle in a 56 pt target', (tester) async {
      await _pump(tester, _toggling(size: CheckCircleSize.large));
      expect(tester.getSize(find.byType(CheckCircle)), const Size(56, 56));
      final circle = find.descendant(
        of: find.byType(CheckCircle),
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(circle.first), const Size(36, 36));
    });
  });

  layoutMatrix(
    'CheckCircle',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        children: [
          for (final (checked, state, size) in const [
            (false, CheckState.open, CheckCircleSize.regular),
            (true, CheckState.done, CheckCircleSize.regular),
            (true, CheckState.doneByOther, CheckCircleSize.regular),
            (false, CheckState.pending, CheckCircleSize.regular),
            (true, CheckState.failed, CheckCircleSize.regular),
            (false, CheckState.open, CheckCircleSize.large),
          ])
            Row(
              children: [
                CheckCircle(
                  checked: checked,
                  itemName: _name,
                  state: state,
                  size: size,
                  byName: 'Lena',
                  onChanged: (_) {},
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Text(
                    '$_name · 1,5 l',
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
