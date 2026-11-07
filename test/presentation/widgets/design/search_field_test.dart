import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';

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

Finder get _cancel => find.bySemanticsLabel('Cancel');
Finder get _clear => find.bySemanticsLabel('Clear');

Size _visibleField(WidgetTester tester) => tester.getSize(
  find
      .descendant(
        of: find.byType(AvoSearchField),
        matching: find.byType(DecoratedBox),
      )
      .first,
);

void main() {
  testWidgets('placeholder defaults to "Search"', (tester) async {
    await _pump(tester, const AvoSearchField());
    expect(find.text('Search'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
    await _pump(tester, const AvoSearchField(hint: 'Rezepte suchen'));
    expect(find.text('Rezepte suchen'), findsOneWidget);
  });

  testWidgets('clear button appears with text and empties the field', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <String>[];
    await _pump(tester, AvoSearchField(onChanged: changes.add));
    expect(_clear, findsNothing);
    await tester.enterText(find.byType(CupertinoTextField), 'Hafermilch');
    await tester.pump();
    expect(changes.last, 'Hafermilch');
    expect(_clear, findsOneWidget);
    final size = tester.getSemantics(_clear).rect.size;
    expect(size, const Size(44, 44));

    await tester.tap(_clear);
    await tester.pump();
    expect(changes.last, '');
    expect(find.text('Hafermilch'), findsNothing);
    expect(_clear, findsNothing);
    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.focusNode!.hasFocus, isTrue, reason: 'keeps the keyboard');
    semantics.dispose();
  });

  testWidgets('focus shows Cancel; Cancel clears and drops focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <String>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      AvoSearchField(focusNode: focus, onChanged: changes.add),
    );
    expect(_cancel, findsNothing);
    final fieldWidth = tester.getSize(find.byType(CupertinoTextField)).width;

    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 32));
    final midWidth = tester.getSize(find.byType(CupertinoTextField)).width;
    expect(midWidth, lessThan(fieldWidth), reason: 'Cancel slides in');
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(_cancel, findsOneWidget);
    expect(
      tester.getSemantics(_cancel),
      isSemantics(isButton: true, hasTapAction: true),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'Feta');
    await tester.pump();
    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(changes.last, '');
    expect(find.text('Feta'), findsNothing);
    expect(_cancel, findsNothing);
    expect(
      tester.getSize(find.byType(CupertinoTextField)).width,
      closeTo(fieldWidth, 0.01),
    );
    semantics.dispose();
  });

  testWidgets('custom cancel label', (tester) async {
    await _pump(
      tester,
      const AvoSearchField(autofocus: true, cancelLabel: 'Fertig'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fertig'), findsOneWidget);
  });

  testWidgets('Reduce Motion: Cancel appears without sliding', (tester) async {
    await _pump(
      tester,
      const AvoSearchField(),
      layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
    );
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    await tester.pump();
    final align = tester.widget<Align>(
      find
          .ancestor(of: find.text('Cancel'), matching: find.byType(Align))
          .at(1),
    );
    expect(align.widthFactor, 1);
  });

  testWidgets('submits with the search key', (tester) async {
    final submitted = <String>[];
    await _pump(tester, AvoSearchField(onSubmitted: submitted.add));
    await tester.enterText(find.byType(CupertinoTextField), 'Avocado');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submitted, ['Avocado']);
  });

  testWidgets('uses an external controller', (tester) async {
    final controller = TextEditingController(
      text: 'Laktosefreie Bio-Vollmilch',
    );
    addTearDown(controller.dispose);
    await _pump(tester, AvoSearchField(controller: controller));
    expect(_clear, findsOneWidget);
    expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsOneWidget);
    controller.clear();
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsNothing);
  });

  testWidgets('36 pt visible inside a 44 pt target; labelled field', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const AvoSearchField(autofocus: true));
    await tester.pumpAndSettle();
    expect(_visibleField(tester).height, 36);
    expect(tester.getSize(find.byType(AvoSearchField)).height, 44);
    expect(
      tester.getSemantics(find.byType(CupertinoTextField)),
      isSemantics(label: 'Search', isTextField: true),
    );
    final cancel = tester.getSemantics(_cancel).rect.size;
    expect(cancel.height, greaterThanOrEqualTo(44));
    expect(cancel.width, greaterThanOrEqualTo(44));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('grows with Dynamic Type', (tester) async {
    await _pump(
      tester,
      const AvoSearchField(),
      layout: const LayoutCase(width: 390, scale: 3.1),
    );
    expect(_visibleField(tester).height, greaterThan(36));
    expectNoClippedText(tester);
  });

  layoutMatrix(
    'AvoSearchField',
    (context) => const Padding(
      padding: EdgeInsets.all(AvoSpacing.screen),
      child: AvoSearchField(hint: 'Rezepte, Zutaten, Listen'),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'AvoSearchField focused with text',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: AvoSearchField(
        autofocus: true,
        controller: TextEditingController(text: 'Laktosefreie Bio-Vollmilch'),
      ),
    ),
    checkTapTargets: true,
  );
}
