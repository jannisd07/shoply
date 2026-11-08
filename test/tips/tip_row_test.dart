import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';

import '../layout/layout_matrix.dart';

String _de(String key) => AppTranslations.get(key, 'de');

Widget _section(Widget row) => SizedBox(
  width: double.infinity,
  child: InsetSection(header: _de('tip_section_today'), children: [row]),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      const LayoutCase(width: 390, scale: 1),
      Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}

void main() {
  layoutMatrix(
    'TipRow',
    (context) => _section(
      TipRow(text: _de('tip_t2'), hideLabel: _de('tip_hide'), onHide: () {}),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'TipRow with action (T7)',
    (context) => _section(
      TipRow(
        text: _de('tip_t7'),
        hideLabel: _de('tip_hide'),
        onHide: () {},
        actionLabel: _de('tip_t7_action'),
        onAction: () {},
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'TipRow half swiped',
    (context) => _section(
      TipRow(text: _de('tip_t3'), hideLabel: _de('tip_hide'), onHide: () {}),
    ),
    // In the app the row sits in a scrolling list; at AX5 on 320 pt it is
    // taller than the screen.
    scrollable: true,
    afterPump: (tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TipRow)),
      );
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      // The layout while the background shows is what is checked; let go
      // slowly so the row only springs back.
      await gesture.up(timeStamp: const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 16));
    },
  );

  testWidgets('light bulb in secondaryLabel, text with "Tipp:"', (
    tester,
  ) async {
    await _pump(
      tester,
      _section(
        TipRow(text: _de('tip_t1'), hideLabel: _de('tip_hide'), onHide: () {}),
      ),
    );
    expect(find.text(_de('tip_t1')), findsOneWidget);
    final bulb = tester.widget<AvoIcon>(
      find.byWidgetPredicate(
        (w) => w is AvoIcon && identical(w.icon, AvoIcons.lightbulb),
      ),
    );
    expect(bulb.size, 16);
    // No action without T7.
    expect(find.text(_de('tip_t7_action')), findsNothing);
  });

  testWidgets('a long swipe to the left hides it', (tester) async {
    var hidden = 0;
    await _pump(
      tester,
      _section(
        TipRow(
          text: _de('tip_t2'),
          hideLabel: _de('tip_hide'),
          onHide: () => hidden++,
        ),
      ),
    );
    await tester.drag(find.byType(TipRow), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(hidden, 1);
  });

  testWidgets('a short swipe springs back and shows "Ausblenden" meanwhile', (
    tester,
  ) async {
    var hidden = 0;
    await _pump(
      tester,
      _section(
        TipRow(
          text: _de('tip_t2'),
          hideLabel: _de('tip_hide'),
          onHide: () => hidden++,
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TipRow)),
    );
    // Slow, so no fling.
    await gesture.moveBy(
      const Offset(-30, 0),
      timeStamp: const Duration(milliseconds: 100),
    );
    await gesture.moveBy(
      const Offset(-50, 0),
      timeStamp: const Duration(milliseconds: 600),
    );
    await tester.pump();
    expect(find.text(_de('tip_hide')), findsOneWidget);
    await gesture.up(timeStamp: const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(hidden, 0);
    expect(find.text(_de('tip_hide')), findsNothing);
  });

  testWidgets('a swipe to the right does nothing', (tester) async {
    var hidden = 0;
    await _pump(
      tester,
      _section(
        TipRow(
          text: _de('tip_t2'),
          hideLabel: _de('tip_hide'),
          onHide: () => hidden++,
        ),
      ),
    );
    await tester.drag(find.byType(TipRow), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(hidden, 0);
  });

  testWidgets('right to left: the swipe goes the other way', (tester) async {
    var hidden = 0;
    await _pump(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: _section(
          TipRow(
            text: _de('tip_t2'),
            hideLabel: _de('tip_hide'),
            onHide: () => hidden++,
          ),
        ),
      ),
    );
    await tester.drag(find.byType(TipRow), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(hidden, 0);
    await tester.drag(find.byType(TipRow), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(hidden, 1);
  });

  testWidgets('T7: the action runs; at AX sizes it sits below the text', (
    tester,
  ) async {
    var acted = 0;
    Widget row() => _section(
      TipRow(
        text: _de('tip_t7'),
        hideLabel: _de('tip_hide'),
        onHide: () {},
        actionLabel: _de('tip_t7_action'),
        onAction: () => acted++,
      ),
    );
    await _pump(tester, row());
    await tester.tap(find.text(_de('tip_t7_action')));
    expect(acted, 1);
    final text = tester.getRect(find.text(_de('tip_t7')));
    final action = tester.getRect(find.text(_de('tip_t7_action')));
    expect(action.left, greaterThan(text.right - 1));

    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 2),
        Align(alignment: Alignment.topCenter, child: row()),
      ),
    );
    final stackedText = tester.getRect(find.text(_de('tip_t7')));
    final stackedAction = tester.getRect(find.text(_de('tip_t7_action')));
    expect(stackedAction.top, greaterThanOrEqualTo(stackedText.bottom));
  });

  testWidgets('VoiceOver: one element, action as tap, "Ausblenden" as action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var hidden = 0;
    var acted = 0;
    await _pump(
      tester,
      _section(
        TipRow(
          text: _de('tip_t7'),
          hideLabel: _de('tip_hide'),
          onHide: () => hidden++,
          actionLabel: _de('tip_t7_action'),
          onAction: () => acted++,
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(TipRow));
    expect(node.label, _de('tip_t7'));
    expect(node.hint, _de('tip_t7_action'));
    final data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.customSemanticsActionIds, isNotEmpty);

    final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
    owner.performAction(node.id, SemanticsAction.tap);
    expect(acted, 1);
    final hideId = data.customSemanticsActionIds!.single;
    owner.performAction(node.id, SemanticsAction.customAction, hideId);
    await tester.pumpAndSettle();
    expect(hidden, 1);
    handle.dispose();
  });

  testWidgets('Reduce Motion: hidden without flying out', (tester) async {
    var hidden = 0;
    await loadLayoutFonts();
    tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1, reduceMotion: true),
        Align(
          alignment: Alignment.topCenter,
          child: _section(
            TipRow(
              text: _de('tip_t2'),
              hideLabel: _de('tip_hide'),
              onHide: () => hidden++,
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(TipRow), const Offset(-250, 0));
    await tester.pump();
    expect(hidden, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
