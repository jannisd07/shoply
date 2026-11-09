import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/row_actions.dart';

import '../../../layout/layout_matrix.dart';

const _rowKey = Key('row');

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(layout, Align(alignment: Alignment.topCenter, child: child)),
  );
}

Widget _row({VoidCallback? onTap, String title = 'Wocheneinkauf'}) =>
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
          key: _rowKey,
          constraints: const BoxConstraints(minHeight: 60),
          width: double.infinity,
          color: context.colors.surface,
          padding: const EdgeInsets.all(AvoSpacing.screen),
          child: Text(title, style: context.text(AvoTextStyle.body)),
        ),
      ),
    );

double _left(WidgetTester tester) => tester.getTopLeft(find.byKey(_rowKey)).dx;

void main() {
  testWidgets('a long press opens the menu, a tap still opens the row', (
    tester,
  ) async {
    var opened = 0;
    final chosen = <String>[];
    await _pump(
      tester,
      RowActions(
        menuItems: [
          AvoMenuItem(
            label: 'Alle wieder auf die Liste',
            icon: AvoIcons.cartBadgePlus,
            onSelected: () => chosen.add('again'),
          ),
          const AvoMenuDivider(),
          AvoMenuItem(
            label: 'Löschen',
            destructive: true,
            onSelected: () => chosen.add('delete'),
          ),
        ],
        child: _row(onTap: () => opened++),
      ),
    );

    await tester.tap(find.byKey(_rowKey));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Löschen'), findsNothing);

    await tester.longPress(find.byKey(_rowKey));
    await tester.pumpAndSettle();
    expect(opened, 1, reason: 'a long press is not a tap');
    expect(find.text('Alle wieder auf die Liste'), findsOneWidget);
    await tester.tap(find.text('Alle wieder auf die Liste'));
    await tester.pumpAndSettle();
    expect(chosen, ['again']);
    expect(find.text('Löschen'), findsNothing);
  });

  testWidgets('swipe and menu share one row', (tester) async {
    final ran = <String>[];
    await _pump(
      tester,
      RowActions(
        trailingActions: [
          SwipeAction(
            label: 'Löschen',
            destructive: true,
            onPressed: () => ran.add('swipe-delete'),
          ),
        ],
        menuItems: [
          AvoMenuItem(
            label: 'Kosten teilen',
            onSelected: () => ran.add('split'),
          ),
        ],
        child: _row(),
      ),
    );
    await tester.drag(find.byKey(_rowKey), const Offset(-70, 0));
    await tester.pumpAndSettle();
    expect(_left(tester), closeTo(-80, 0.5));
    expect(find.text('Löschen'), findsOneWidget);

    // An open row takes no long press; the touch closes it.
    await tester.longPress(find.byKey(_rowKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Kosten teilen'), findsNothing);
    expect(_left(tester), closeTo(0, 0.5));

    await tester.longPress(find.byKey(_rowKey));
    await tester.pumpAndSettle();
    expect(find.text('Kosten teilen'), findsOneWidget);
    await tester.tap(find.text('Kosten teilen'));
    await tester.pumpAndSettle();
    expect(ran, ['split']);
  });

  testWidgets('without a row to choose a long press does nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      RowActions(
        menuItems: [
          const AvoMenuTitle('Einkauf'),
          AvoMenuItem(label: 'Gesperrt', enabled: false, onSelected: () {}),
        ],
        child: _row(),
      ),
    );
    await tester.longPress(find.byKey(_rowKey));
    await tester.pumpAndSettle();
    expect(find.text('Gesperrt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabled false returns the row unchanged', (tester) async {
    await _pump(
      tester,
      RowActions(
        enabled: false,
        trailingActions: [SwipeAction(label: 'Löschen', onPressed: () {})],
        menuItems: [AvoMenuItem(label: 'Teilen', onSelected: () {})],
        child: _row(),
      ),
    );
    await tester.drag(find.byKey(_rowKey), const Offset(-70, 0));
    await tester.pumpAndSettle();
    expect(_left(tester), 0);
    await tester.longPress(find.byKey(_rowKey));
    await tester.pumpAndSettle();
    expect(find.text('Teilen'), findsNothing);
  });

  testWidgets('VoiceOver: menu rows and swipe actions as custom actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final ran = <String>[];
    await _pump(
      tester,
      RowActions(
        trailingActions: [
          SwipeAction(label: 'Löschen', onPressed: () => ran.add('swipe')),
        ],
        leadingActions: [
          SwipeAction(label: 'Bezahlt', onPressed: () => ran.add('paid')),
        ],
        menuItems: [
          AvoMenuItem(
            label: 'Kosten teilen',
            onSelected: () => ran.add('split'),
          ),
          AvoMenuItem(label: 'Gesperrt', enabled: false, onSelected: () {}),
          const AvoMenuDivider(),
          AvoMenuItem(label: 'Löschen', onSelected: () => ran.add('menu')),
        ],
        child: _row(),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wocheneinkauf')),
      isSemantics(
        customActions: const [
          CustomSemanticsAction(label: 'Kosten teilen'),
          CustomSemanticsAction(label: 'Löschen'),
          CustomSemanticsAction(label: 'Bezahlt'),
        ],
      ),
    );
    // The same label counts once and runs the swipe action.
    final actions = RowActions.semanticActionsOf(
      trailingActions: [
        SwipeAction(label: 'Löschen', onPressed: () => ran.add('swipe')),
      ],
      menuItems: [
        AvoMenuItem(label: 'Löschen', onSelected: () => ran.add('menu')),
      ],
    );
    expect(actions, hasLength(1));
    actions.values.single();
    expect(ran, ['swipe']);
    handle.dispose();
  });

  testWidgets('exposeSemantics false adds no node of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      RowActions(
        exposeSemantics: false,
        menuItems: [AvoMenuItem(label: 'Teilen', onSelected: () {})],
        child: _row(),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wocheneinkauf')),
      isNot(
        isSemantics(
          customActions: const [CustomSemanticsAction(label: 'Teilen')],
        ),
      ),
    );
    handle.dispose();
  });

  Widget matrixRow(BuildContext context) => RowActions(
    trailingActions: [
      SwipeAction(
        label: 'Löschen',
        icon: AvoIcons.trash,
        destructive: true,
        onPressed: () {},
      ),
      SwipeAction(label: 'Kosten teilen', onPressed: () {}),
    ],
    menuItems: [
      AvoMenuItem(label: 'Alle wieder auf die Liste', onSelected: () {}),
    ],
    child: _row(title: 'Wocheneinkauf bei Lidl am Samstag, 7. November'),
  );

  layoutMatrix('RowActions closed', matrixRow);
  layoutMatrix(
    'RowActions swiped open',
    matrixRow,
    afterPump: (tester) async {
      await tester.drag(find.byKey(_rowKey), const Offset(-70, 0));
      await tester.pumpAndSettle();
    },
  );
}
