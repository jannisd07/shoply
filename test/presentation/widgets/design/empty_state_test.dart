import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';

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

const _title = 'Noch nichts auf der Liste.';
const _message = 'Schreib unten, was du brauchst.';

void main() {
  testWidgets('title 20/25 semibold, message 15/20 secondary, centred', (
    tester,
  ) async {
    await _pump(tester, const EmptyState(title: _title, message: _message));
    final title = tester.widget<Text>(find.text(_title));
    expect(title.style?.fontSize, 20);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.textAlign, TextAlign.center);
    final message = tester.widget<Text>(find.text(_message));
    expect(message.style?.fontSize, 15);
    expect(message.style?.color, AvoColors.light.secondaryLabel);
    expect(
      tester.getCenter(find.text(_title)).dx,
      closeTo(tester.getCenter(find.byType(EmptyState)).dx, 0.5),
    );
  });

  testWidgets('one plain action: 17/22 tint, 44 pt target, runs onAction', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      EmptyState(
        title: _title,
        actionLabel: 'Zettel importieren',
        onAction: () => taps++,
      ),
    );
    final label = tester.widget<Text>(find.text('Zettel importieren'));
    expect(label.style?.color, AvoColors.light.tint);
    expect(label.style?.fontSize, 17);
    final target = find.ancestor(
      of: find.text('Zettel importieren'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(target.first).height, greaterThanOrEqualTo(44));
    await tester.tap(find.text('Zettel importieren'));
    expect(taps, 1);
  });

  testWidgets('the action shrinks while pressed (not with Reduce Motion)', (
    tester,
  ) async {
    Future<double> pressedScale(LayoutCase layout) async {
      await _pump(
        tester,
        EmptyState(title: _title, actionLabel: 'Neue Liste', onAction: () {}),
        layout: layout,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Neue Liste')),
      );
      await tester.pumpAndSettle();
      final scale = tester
          .widget<Transform>(
            find.ancestor(
              of: find.text('Neue Liste'),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .storage[0];
      await gesture.up();
      await tester.pumpAndSettle();
      return scale;
    }

    expect(
      await pressedScale(const LayoutCase(width: 390, scale: 1)),
      closeTo(AvoMotion.pressedScale, 0.002),
    );
    expect(
      await pressedScale(
        const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      ),
      1,
    );
  });

  testWidgets('no action without onAction', (tester) async {
    await _pump(
      tester,
      const EmptyState(title: _title, actionLabel: 'Zettel importieren'),
    );
    expect(find.text('Zettel importieren'), findsNothing);
  });

  testWidgets('figure 96 pt below AX1, gone from AX1', (tester) async {
    const state = EmptyState(title: _title, pose: AvoPose.waving);
    await _pump(tester, state);
    expect(find.byType(AvoFigure), findsOneWidget);
    expect(tester.getSize(find.byType(AvoFigure)), const Size(96, 96));

    await _pump(tester, state, layout: const LayoutCase(width: 390, scale: 2));
    expect(find.byType(AvoFigure), findsNothing);
  });

  testWidgets('icon: 48 pt secondaryLabel, kept from AX1', (tester) async {
    const state = EmptyState(
      title: 'Alles erledigt. Schön.',
      icon: Icon(CupertinoIcons.checkmark_circle),
    );
    await _pump(tester, state);
    final theme = IconTheme.of(tester.element(find.byType(Icon)));
    expect(theme.size, 48);
    expect(theme.color, AvoColors.light.secondaryLabel);

    await _pump(
      tester,
      state,
      layout: const LayoutCase(width: 390, scale: 3.1),
    );
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('from AX1 the icon replaces the figure', (tester) async {
    await _pump(
      tester,
      const EmptyState(
        title: _title,
        pose: AvoPose.thinking,
        icon: Icon(CupertinoIcons.search),
      ),
      layout: const LayoutCase(width: 390, scale: 2),
    );
    expect(find.byType(AvoFigure), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('VoiceOver: title is a heading, action a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      EmptyState(
        title: _title,
        message: _message,
        actionLabel: 'Zettel importieren',
        onAction: () {},
        pose: AvoPose.waving,
        icon: const Icon(CupertinoIcons.doc_text),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(_title)),
      isSemantics(isHeader: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Zettel importieren')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel(_message), findsOneWidget);
    handle.dispose();
  });

  layoutMatrix(
    'EmptyState with figure and action',
    (context) => EmptyState(
      title: 'Noch keine gespeicherten Rezepte.',
      message:
          'Tippe auf das Lesezeichen bei einem Rezept, zum Beispiel bei '
          '„Laktosefreie Bio-Vollmilch-Pfannkuchen“ für 2,49 €.',
      actionLabel: 'Rezepte entdecken',
      onAction: () {},
      pose: AvoPose.thinking,
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'EmptyState with icon',
    (context) => EmptyState(
      title: 'Die Liste lässt sich gerade nicht laden.',
      actionLabel: 'Erneut versuchen',
      onAction: () {},
      icon: const Icon(CupertinoIcons.exclamationmark_circle),
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
