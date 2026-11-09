import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/picker_row.dart';

import '../../../layout/layout_matrix.dart';

/// A page-like host that keeps the open state, like the settings pages.
class _Host extends StatefulWidget {
  const _Host({this.initialOpen = false, this.onAge});

  final bool initialOpen;
  final ValueChanged<int>? onAge;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool _open = widget.initialOpen;
  int? _age = 34;
  String _gender = 'Männlich';

  @override
  Widget build(BuildContext context) {
    return InsetSection(
      children: [
        PickerRow(
          title: 'Alter',
          value: _age == null ? 'Nicht angegeben' : '$_age Jahre',
          expanded: _open,
          onExpandedChanged: (o) => setState(() => _open = o),
          picker: NumberPicker(
            value: _age,
            min: 13,
            max: 100,
            initial: 30,
            unit: 'Jahre',
            semanticLabel: 'Alter',
            onChanged: (v) {
              setState(() => _age = v);
              widget.onAge?.call(v);
            },
          ),
        ),
        MenuValueRow(
          title: 'Geschlecht',
          value: _gender,
          items: [
            for (final g in ['Weiblich', 'Männlich', 'Divers', 'Keine Angabe'])
              AvoMenuItem(
                label: g,
                checked: g == _gender,
                onSelected: () => setState(() => _gender = g),
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      LayoutCase(width: 390, scale: scale),
      SingleChildScrollView(child: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  layoutMatrix('PickerRow closed and MenuValueRow', (_) => const _Host());
  layoutMatrix('PickerRow open', (_) => const _Host(initialOpen: true));
  layoutMatrix(
    'TimeOfDayPicker in a PickerRow',
    (_) => InsetSection(
      children: [
        PickerRow(
          title: 'Uhrzeit',
          value: '9:00',
          expanded: true,
          onExpandedChanged: (_) {},
          picker: TimeOfDayPicker(hour: 9, minute: 0, onChanged: (_, _) {}),
        ),
        PickerRow(
          title: 'Time',
          value: '6:00 PM',
          expanded: true,
          onExpandedChanged: (_) {},
          picker: TimeOfDayPicker(
            hour: 18,
            minute: 0,
            use24Hour: false,
            onChanged: (_, _) {},
          ),
        ),
      ],
    ),
    scrollable: true,
  );

  testWidgets('tapping the row unfolds the wheel and folds it again', (
    tester,
  ) async {
    await _pump(tester, const _Host());
    expect(find.byType(CupertinoPicker), findsNothing);

    await tester.tap(find.text('Alter'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsOneWidget);

    await tester.tap(find.text('Alter'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNothing);
  });

  testWidgets('turning the wheel reports the number', (tester) async {
    final values = <int>[];
    await _pump(tester, _Host(initialOpen: true, onAge: values.add));
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.last, greaterThan(34));
    expect(find.text('${values.last} Jahre'), findsOneWidget);
  });

  testWidgets('VoiceOver reads one button with value and expanded state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const _Host());
    final node = tester.getSemantics(find.bySemanticsLabel('Alter').first);
    expect(node.value, '34 Jahre');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isExpanded, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('from AX3 on a number field replaces the wheel', (tester) async {
    final values = <int>[];
    await _pump(
      tester,
      _Host(initialOpen: true, onAge: values.add),
      scale: 3.1,
    );
    expect(find.byType(CupertinoPicker), findsNothing);
    final field = find.byType(CupertinoTextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, '41');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(values, [41]);

    await tester.enterText(field, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(values, [41]);
    expect(find.text('Between 13 and 100.'), findsOneWidget);
  });

  testWidgets('the menu row opens its choices and takes one', (tester) async {
    await _pump(tester, const _Host());
    await tester.tap(find.text('Geschlecht'));
    await tester.pumpAndSettle();
    expect(find.text('Divers'), findsOneWidget);
    await tester.tap(find.text('Divers'));
    await tester.pumpAndSettle();
    expect(find.text('Divers'), findsOneWidget);
    expect(find.text('Männlich'), findsNothing);
  });

  testWidgets('a menu row without choices is disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const InsetSection(
        children: [MenuValueRow(title: 'Liste', value: 'Keine', items: [])],
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('Liste'));
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  test('time text is parsed in the usual forms', () {
    expect(parsePickerTime('9:00'), (hour: 9, minute: 0));
    expect(parsePickerTime('09.30'), (hour: 9, minute: 30));
    expect(parsePickerTime('930'), (hour: 9, minute: 30));
    expect(parsePickerTime('18'), (hour: 18, minute: 0));
    expect(parsePickerTime('24:00'), isNull);
    expect(parsePickerTime('9:75'), isNull);
    expect(parsePickerTime(''), isNull);
  });
}
