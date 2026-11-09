import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

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
    layoutHarness(
      layout,
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.screen),
          child: child,
        ),
      ),
    ),
  );
}

/// The scale of the press transform inside [of].
double _scale(WidgetTester tester, Finder of) {
  final transform = tester.widget<Transform>(
    find.descendant(of: of, matching: find.byType(Transform)).first,
  );
  return transform.transform.storage[0];
}

double _opacity(WidgetTester tester, Finder of) => tester
    .widget<Opacity>(
      find.descendant(of: of, matching: find.byType(Opacity)).first,
    )
    .opacity;

const _text = 'Deine Avocados werden reif. Diese Woche verbrauchen?';

void main() {
  testWidgets('D2 card: white, radius 20, 15/20 text', (tester) async {
    await _pump(tester, const HintRow(text: _text));
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(HintRow),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AvoColors.light.surface);
    expect(decoration.borderRadius, BorderRadius.circular(AvoRadii.card));
    final style = tester.widget<Text>(find.text(_text)).style!;
    expect(style.fontSize, 15);
    expect(style.color, AvoColors.light.label);
    expect(
      tester.getSize(find.byType(HintRow)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('tapping the card runs onTap; action shown as tinted link', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      HintRow(
        text: _text,
        actionLabel: 'Rezepte mit Avocado',
        onTap: () => taps++,
      ),
    );
    final action = tester.widget<Text>(find.text('Rezepte mit Avocado'));
    expect(action.style?.color, AvoColors.light.tint);
    expect(action.style?.fontWeight, FontWeight.w600);
    await tester.tap(find.text(_text));
    await tester.tap(find.text('Rezepte mit Avocado'));
    expect(taps, 2);
  });

  testWidgets('without onTap the action label is not shown', (tester) async {
    await _pump(
      tester,
      const HintRow(text: _text, actionLabel: 'Rezepte mit Avocado'),
    );
    expect(find.text('Rezepte mit Avocado'), findsNothing);
  });

  testWidgets('shrinks the moment it is pressed, springs back', (tester) async {
    await _pump(tester, HintRow(text: _text, onTap: () {}));
    final card = find.byType(HintRow);
    expect(_scale(tester, card), 1);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pumpAndSettle();
    expect(_scale(tester, card), closeTo(AvoMotion.pressedScale, 0.002));
    expect(_opacity(tester, card), closeTo(0.9, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scale(tester, card), closeTo(1, 0.002));
    expect(_opacity(tester, card), closeTo(1, 0.01));
  });

  testWidgets('Reduce Motion: dims but does not scale', (tester) async {
    await _pump(
      tester,
      HintRow(text: _text, onTap: () {}),
      layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
    );
    final card = find.byType(HintRow);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    expect(_scale(tester, card), 1);
    expect(_opacity(tester, card), closeTo(0.9, 0.01));
    await gesture.up();
    await tester.pump();
    expect(_opacity(tester, card), 1);
  });

  testWidgets('close button: 44 pt target, labelled, runs onDismiss', (
    tester,
  ) async {
    var dismissed = 0;
    var taps = 0;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      HintRow(text: _text, onTap: () => taps++, onDismiss: () => dismissed++),
    );
    final close = find.bySemanticsLabel('Close');
    expect(close, findsOneWidget);
    expect(tester.getSize(close), const Size(44, 44));
    final card = tester.getRect(find.byType(HintRow));
    final closeRect = tester.getRect(close);
    expect(closeRect.topRight, card.topRight);
    await tester.tap(close);
    expect(dismissed, 1);
    expect(taps, 0);
    expect(
      tester.getRect(find.text(_text)).right,
      lessThanOrEqualTo(closeRect.left),
    );
    handle.dispose();
  });

  testWidgets('custom dismiss label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      HintRow(text: _text, onDismiss: () {}, dismissLabel: 'Ausblenden'),
    );
    expect(find.bySemanticsLabel('Ausblenden'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('VoiceOver: one button with text and action', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      HintRow(text: _text, actionLabel: 'Öffnen', onTap: () {}),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('$_text, Öffnen')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('a plain hint is text, not a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const HintRow(text: _text));
    expect(
      tester.getSemantics(find.bySemanticsLabel(_text)),
      isSemantics(isButton: false, hasTapAction: false),
    );
    handle.dispose();
  });

  testWidgets('leading beside the text, above it from AX1', (tester) async {
    Widget hint() => const HintRow(
      text: _text,
      leading: AvoFigure(pose: AvoPose.thinking, size: 44),
    );
    await _pump(tester, hint());
    var figure = tester.getRect(find.byType(AvoFigure));
    var text = tester.getRect(find.text(_text));
    expect(text.left, greaterThan(figure.right));

    await _pump(tester, hint(), layout: const LayoutCase(width: 390, scale: 2));
    figure = tester.getRect(find.byType(AvoFigure));
    text = tester.getRect(find.text(_text));
    expect(text.top, greaterThan(figure.bottom));
  });

  group('title, swipe and menu (A-C3)', () {
    testWidgets('bold title above the secondary text; the label has both', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const HintRow(title: 'Du sparst 3,20 €', text: _text),
      );
      final title = tester.widget<Text>(find.text('Du sparst 3,20 €')).style!;
      expect(title.fontSize, 15);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.color, AvoColors.light.label);
      final body = tester.widget<Text>(find.text(_text)).style!;
      expect(body.color, AvoColors.light.secondaryLabel);
      expect(
        tester.getRect(find.text('Du sparst 3,20 €')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text(_text)).top),
      );
      expect(find.bySemanticsLabel('Du sparst 3,20 €, $_text'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without a title nothing changes', (tester) async {
      await _pump(tester, const HintRow(text: _text));
      expect(
        tester.widget<Text>(find.text(_text)).style!.color,
        AvoColors.light.label,
      );
    });

    testWidgets('swipe shows the action, a full swipe runs it', (tester) async {
      var hidden = 0;
      await _pump(
        tester,
        HintRow(
          text: _text,
          onDismiss: () {},
          swipeActions: [
            SwipeAction(
              label: 'Ausblenden',
              icon: AvoIcons.eyeSlash,
              onPressed: () => hidden++,
            ),
          ],
        ),
      );
      await tester.drag(find.text(_text), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text('Ausblenden'), findsOneWidget);
      await tester.tap(find.text('Ausblenden'));
      await tester.pumpAndSettle();
      expect(hidden, 1);

      await tester.drag(find.text(_text), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(hidden, 2);
    });

    testWidgets('the swipe surface has the card radius', (tester) async {
      await _pump(
        tester,
        HintRow(
          text: _text,
          swipeActions: [SwipeAction(label: 'Ausblenden', onPressed: () {})],
        ),
      );
      await tester.drag(find.text(_text), const Offset(-120, 0));
      await tester.pumpAndSettle();
      final clip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.text('Ausblenden'),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(AvoRadii.card));
    });

    testWidgets('long press opens the menu, entries are custom actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var chosen = 0;
      var taps = 0;
      await _pump(
        tester,
        HintRow(
          text: _text,
          onTap: () => taps++,
          contextMenuItems: [
            AvoMenuItem(label: 'Ausblenden', onSelected: () => chosen++),
          ],
          swipeActions: [SwipeAction(label: 'Später', onPressed: () {})],
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(_text)),
        isSemantics(
          isButton: true,
          customActions: const [
            CustomSemanticsAction(label: 'Ausblenden'),
            CustomSemanticsAction(label: 'Später'),
          ],
        ),
      );
      await tester.longPress(find.text(_text));
      await tester.pumpAndSettle();
      expect(taps, 0);
      await tester.tap(find.text('Ausblenden'));
      await tester.pumpAndSettle();
      expect(chosen, 1);
      handle.dispose();
    });
  });

  layoutMatrix(
    'HintRow with figure, action and close',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: HintRow(
        text:
            '4 von 11 Artikeln diese Woche bei Lidl im Angebot, '
            'Laktosefreie Bio-Vollmilch für 1,29 €, ca. 3,20 € gespart.',
        leading: const AvoFigure(pose: AvoPose.thinking, size: 44),
        actionLabel: 'Angebote ansehen',
        onTap: () {},
        onDismiss: () {},
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'HintRow plain text',
    (context) => const Padding(
      padding: EdgeInsets.all(AvoSpacing.screen),
      child: HintRow(text: 'Tipp: Schreib „2 Laktosefreie Bio-Vollmilch“.'),
    ),
  );

  layoutMatrix(
    'HintRow savings card: title, swipe action, close',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: HintRow(
        title: 'Du sparst 3,20 € bei Lidl',
        text: '4 von 11 Artikeln diese Woche im Angebot, Vollmilch für 1,29 €.',
        leading: const AvoFigure(pose: AvoPose.thinking, size: 44),
        onTap: () {},
        onDismiss: () {},
        swipeActions: [SwipeAction(label: 'Ausblenden', onPressed: () {})],
        contextMenuItems: [AvoMenuItem(label: 'Ausblenden', onSelected: () {})],
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
