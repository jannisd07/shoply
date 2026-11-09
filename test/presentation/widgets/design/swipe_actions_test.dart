import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

import '../../../layout/layout_matrix.dart';

const _rowKey = Key('row');

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
  TextDirection? direction,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Widget content = Align(alignment: Alignment.topCenter, child: child);
  if (direction != null) {
    content = Directionality(textDirection: direction, child: content);
  }
  await tester.pumpWidget(layoutHarness(layout, content));
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

Widget _row({VoidCallback? onTap}) => GestureDetector(
  onTap: onTap,
  child: Container(
    key: _rowKey,
    height: 60,
    width: double.infinity,
    color: const Color(0xFFFFFFFF),
    alignment: Alignment.centerLeft,
    child: const Text('Hafermilch'),
  ),
);

double _left(WidgetTester tester) => tester.getTopLeft(find.byKey(_rowKey)).dx;

void main() {
  group('swiping', () {
    testWidgets('past half of the surfaces: settles open, 80 pt per action', (
      tester,
    ) async {
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [
            SwipeAction(label: 'Löschen', onPressed: () {}, destructive: true),
            SwipeAction(label: 'Menge', onPressed: () {}),
          ],
          child: _row(),
        ),
      );
      expect(_left(tester), 0);
      await tester.drag(find.byKey(_rowKey), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(_left(tester), -160);
      expect(find.text('Löschen'), findsOneWidget);
      expect(find.text('Menge'), findsOneWidget);
      // The first action is the outermost one.
      expect(
        tester.getCenter(find.text('Löschen')).dx,
        greaterThan(tester.getCenter(find.text('Menge')).dx),
      );
    });

    testWidgets('a short pull springs back', (tester) async {
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(-20, 0));
      await tester.pumpAndSettle();
      expect(_left(tester), 0);
    });

    testWidgets('destructive surfaces use destructiveFill with white text', (
      tester,
    ) async {
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [
            SwipeAction(
              label: 'Löschen',
              icon: AvoIcons.trash,
              onPressed: () {},
              destructive: true,
            ),
          ],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(-120, 0));
      await tester.pumpAndSettle();
      final fill = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.text('Löschen'),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(fill.color, AvoColors.light.destructiveFill);
      expect(
        tester.widget<Text>(find.text('Löschen')).style!.color,
        AvoColors.light.onTint,
      );
      expect(find.byType(AvoIcon), findsOneWidget);
    });

    testWidgets('a full swipe runs the first action and closes the row', (
      tester,
    ) async {
      final ran = <String>[];
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [
            SwipeAction(label: 'Löschen', onPressed: () => ran.add('delete')),
            SwipeAction(label: 'Menge', onPressed: () => ran.add('qty')),
          ],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(ran, ['delete']);
      expect(_left(tester), 0);
    });

    testWidgets('fullSwipe false: a long pull only opens', (tester) async {
      final ran = <String>[];
      await _pump(
        tester,
        SwipeActions(
          fullSwipe: false,
          trailingActions: [
            SwipeAction(label: 'Löschen', onPressed: () => ran.add('delete')),
          ],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(ran, isEmpty);
      expect(_left(tester), -80);
    });

    testWidgets('the threshold ticks the light haptic once per crossing', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_rowKey)),
      );
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.moveBy(const Offset(-100, 0));
      expect(haptics, isEmpty, reason: '160 pt of 390 is below 60 %');
      await gesture.moveBy(const Offset(-120, 0));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await gesture.moveBy(const Offset(-20, 0));
      expect(haptics, hasLength(1), reason: 'still armed, no second tick');
      await gesture.moveBy(const Offset(160, 0));
      expect(haptics, hasLength(2), reason: 'leaving the threshold ticks too');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping a surface runs it and closes', (tester) async {
      var ran = 0;
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [
            SwipeAction(label: 'Löschen', onPressed: () => ran++),
          ],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(ran, 1);
      expect(_left(tester), 0);
    });

    testWidgets('an open row takes no taps: a tap closes it', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(onTap: () => taps++),
        ),
      );
      await tester.tap(find.byKey(_rowKey));
      expect(taps, 1);
      await tester.drag(find.byKey(_rowKey), const Offset(-120, 0));
      await tester.pumpAndSettle();
      // Tap on the part of the row that is still visible.
      await tester.tapAt(const Offset(10, 30));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the row did not get the tap');
      expect(_left(tester), 0);
    });

    testWidgets('leading actions open towards the end edge', (tester) async {
      await _pump(
        tester,
        SwipeActions(
          leadingActions: [SwipeAction(label: 'Fertig', onPressed: () {})],
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(_left(tester), 80);
      expect(find.text('Fertig'), findsOneWidget);
      expect(find.text('Löschen'), findsNothing);
    });

    testWidgets('a side without actions only rubber-bands', (tester) async {
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_rowKey)),
      );
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(_left(tester), greaterThan(0));
      expect(_left(tester), lessThan(100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_left(tester), 0);
    });

    testWidgets('right to left: surfaces open at the left edge', (
      tester,
    ) async {
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
        direction: TextDirection.rtl,
      );
      await tester.drag(find.byKey(_rowKey), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(_left(tester), 80);
      expect(tester.getCenter(find.text('Löschen')).dx, lessThan(80));
    });

    testWidgets('Reduce Motion: the row jumps without a spring', (
      tester,
    ) async {
      await _pump(
        tester,
        SwipeActions(
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_rowKey)),
      );
      await gesture.moveBy(const Offset(-120, 0));
      await gesture.up();
      await tester.pump();
      expect(_left(tester), -80, reason: 'no animation frames needed');
    });

    testWidgets('disabled or empty: the child is returned as it is', (
      tester,
    ) async {
      await _pump(
        tester,
        SwipeActions(
          enabled: false,
          trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
          child: _row(),
        ),
      );
      await tester.drag(find.byKey(_rowKey), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(_left(tester), 0);
      await _pump(tester, SwipeActions(child: _row()));
      expect(find.byKey(_rowKey), findsOneWidget);
    });
  });

  group('VoiceOver', () {
    testWidgets('every action is a custom action of the row', (tester) async {
      final handle = tester.ensureSemantics();
      final ran = <String>[];
      await _pump(
        tester,
        Semantics(
          container: true,
          label: 'Zeile',
          child: SwipeActions(
            trailingActions: [
              SwipeAction(label: 'Löschen', onPressed: () => ran.add('del')),
            ],
            leadingActions: [
              SwipeAction(label: 'Fertig', onPressed: () => ran.add('done')),
            ],
            child: _row(),
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^Zeile')));
      final labels = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map((id) => CustomSemanticsAction.getAction(id)!.label)
          .toList();
      expect(labels, containsAll(['Löschen', 'Fertig']));
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Zeile')),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Löschen'),
        ),
      );
      expect(ran, ['del']);
      handle.dispose();
    });

    testWidgets('semanticActionsOf maps labels to callbacks', (tester) async {
      var called = 0;
      final map = SwipeActions.semanticActionsOf([
        SwipeAction(label: 'A', onPressed: () => called++),
      ]);
      expect(map.keys.single.label, 'A');
      map.values.single();
      expect(called, 1);
    });
  });

  layoutMatrix(
    'SwipeActions: open row with icon and long labels',
    (context) => SwipeActions(
      trailingActions: [
        SwipeAction(
          label: 'Löschen',
          icon: AvoIcons.trash,
          destructive: true,
          onPressed: () {},
        ),
        SwipeAction(label: 'Menge ändern', onPressed: () {}),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        color: context.colors.surface,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
        child: Text(
          'Laktosefreie Bio-Vollmilch',
          style: context.text(AvoTextStyle.body),
        ),
      ),
    ),
    afterPump: (tester) async {
      await tester.drag(
        find.text('Laktosefreie Bio-Vollmilch'),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
    },
  );
}
