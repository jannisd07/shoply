import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/text_field_row.dart';

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
        child: InsetSection(children: [child]),
      ),
    ),
  );
}

Finder get _field => find.byType(CupertinoTextField);

void main() {
  testWidgets('label left, field right-aligned, at least 52 pt', (
    tester,
  ) async {
    await _pump(
      tester,
      const TextFieldRow(label: 'Postleitzahl', placeholder: '20095'),
    );
    expect(tester.getSize(find.byType(TextFieldRow)).height, 52);
    expect(
      tester.getTopLeft(find.text('Postleitzahl')).dx,
      lessThan(tester.getTopLeft(_field).dx),
    );
    expect(tester.widget<CupertinoTextField>(_field).textAlign, TextAlign.end);
    expect(find.text('20095'), findsOneWidget);
  });

  testWidgets('controller, onChanged, onSubmitted and keyboard settings', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    final submits = <String>[];
    await _pump(
      tester,
      TextFieldRow(
        label: 'Postleitzahl',
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.postalCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 5,
        onChanged: changes.add,
        onSubmitted: submits.add,
      ),
    );
    final field = tester.widget<CupertinoTextField>(_field);
    expect(field.keyboardType, TextInputType.number);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.autofillHints, [AutofillHints.postalCode]);

    await tester.enterText(_field, '20a095999');
    await tester.pump();
    expect(controller.text, '20095');
    expect(changes.last, '20095');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submits, ['20095']);
  });

  testWidgets('tapping the row focuses the field', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(tester, TextFieldRow(label: 'Straße', focusNode: focus));
    await tester.tapAt(tester.getTopLeft(find.text('Straße')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('error in destructive colour, read as the field hint', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    late AvoColors colors;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          colors = context.colors;
          return const TextFieldRow(
            label: 'Postleitzahl',
            errorText: 'Bitte fünf Ziffern',
            hintText: 'Wird nur für Angebote genutzt',
          );
        },
      ),
    );
    expect(find.text('Wird nur für Angebote genutzt'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Bitte fünf Ziffern')).style!.color,
      colors.destructive,
    );
    final node = tester.getSemantics(find.byType(CupertinoTextField));
    expect(node.label, contains('Postleitzahl'));
    expect(node.hint, 'Error: Bitte fünf Ziffern');
    expect(find.bySemanticsLabel('Bitte fünf Ziffern'), findsNothing);
    handle.dispose();
  });

  testWidgets('hint line in the secondary colour', (tester) async {
    late AvoColors colors;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          colors = context.colors;
          return const TextFieldRow(
            label: 'Postleitzahl',
            hintText: 'Wird nur für Angebote genutzt',
          );
        },
      ),
    );
    expect(
      tester
          .widget<Text>(find.text('Wird nur für Angebote genutzt'))
          .style!
          .color,
      colors.secondaryLabel,
    );
  });

  testWidgets('from AX1 the label stacks above the field', (tester) async {
    await _pump(
      tester,
      const TextFieldRow(label: 'Postleitzahl', placeholder: '20095'),
      layout: const LayoutCase(width: 390, scale: 2),
    );
    expect(
      tester.getBottomLeft(find.text('Postleitzahl')).dy,
      lessThanOrEqualTo(tester.getTopLeft(_field).dy),
    );
    expect(
      tester.widget<CupertinoTextField>(_field).textAlign,
      TextAlign.start,
    );
  });

  testWidgets('disabled: no focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      TextFieldRow(label: 'Straße', focusNode: focus, enabled: false),
    );
    await tester.tapAt(tester.getTopLeft(find.text('Straße')));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(tester.widget<CupertinoTextField>(_field).enabled, isFalse);
  });

  layoutMatrix(
    'TextFieldRow',
    (context) => InsetSection(
      header: 'Standort',
      children: [
        const TextFieldRow(
          label: 'Postleitzahl',
          placeholder: '20095',
          hintText: 'Wird nur für Angebote in deiner Nähe genutzt',
        ),
        TextFieldRow(
          label: 'Laktosefreie Bio-Vollmilch Sorte',
          controller: TextEditingController(text: 'Hamburg Altstadt Nord'),
          errorText: 'Diese Postleitzahl kennt Avo nicht',
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
