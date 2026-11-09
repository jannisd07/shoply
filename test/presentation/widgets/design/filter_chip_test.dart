import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';

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

ShapeDecoration _capsule(WidgetTester tester, String label) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

Size _capsuleSize(WidgetTester tester, String label) => tester.getSize(
  find
      .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
      .first,
);

const _labels = [
  'Für dich',
  'Schnell',
  'Vegetarisch',
  'Laktosefrei',
  'Unter 30 Minuten',
  'Zurücksetzen',
];

void main() {
  group('leading and secondaryLabel', () {
    testWidgets('leading sits before the label; secondary text is quiet', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      late AvoColors colors;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            colors = context.colors;
            return AppFilterChip(
              label: 'Lidl',
              secondaryLabel: '400 m',
              leading: const SizedBox.square(key: Key('dot'), dimension: 8),
              selected: false,
              onSelected: (_) {},
            );
          },
        ),
      );
      expect(find.byKey(const Key('dot')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('dot'))).dx,
        lessThan(tester.getTopLeft(find.textContaining('Lidl')).dx),
      );
      final rich = tester.widget<Text>(find.textContaining('Lidl'));
      final span = rich.textSpan! as TextSpan;
      expect(span.children!.single.toPlainText(), ' · 400 m');
      expect(
        (span.children!.single as TextSpan).style!.color,
        colors.secondaryLabel,
      );
      expect(find.bySemanticsLabel('Lidl, 400 m'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the leading slot grows with the text', (tester) async {
      Future<double> slot(double scale) async {
        await _pump(
          tester,
          AppFilterChip(
            label: 'Lidl',
            leading: const SizedBox.square(key: Key('dot'), dimension: 8),
            selected: false,
            onSelected: (_) {},
          ),
          layout: LayoutCase(width: 390, scale: scale),
        );
        return tester
            .getSize(
              find.ancestor(
                of: find.byKey(const Key('dot')),
                matching: find.byType(FittedBox),
              ),
            )
            .width;
      }

      final small = await slot(1);
      final large = await slot(2);
      expect(large, greaterThan(small));
    });
  });

  group('SingleChoiceChipRow', () {
    testWidgets('one choice, radio semantics, deselect only when allowed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      String? chosen = 'b';
      Widget row({required bool allowDeselect}) => StatefulBuilder(
        builder: (context, setState) => SingleChoiceChipRow<String>(
          allowDeselect: allowDeselect,
          value: chosen,
          onChanged: (v) => setState(() => chosen = v),
          choices: const [
            ChipChoice(value: 'a', label: 'Alle'),
            ChipChoice(value: 'b', label: 'Lidl', secondaryLabel: '400 m'),
            ChipChoice(value: 'c', label: 'Rewe'),
          ],
        ),
      );
      await _pump(tester, row(allowDeselect: false));
      final node = tester.getSemantics(find.bySemanticsLabel('Lidl, 400 m'));
      expect(node.value, '2 of 3');
      expect(node.flagsCollection.isSelected, isNotNull);

      await tester.tap(find.textContaining('Rewe'));
      await tester.pumpAndSettle();
      expect(chosen, 'c');
      await tester.tap(find.textContaining('Rewe'));
      await tester.pumpAndSettle();
      expect(chosen, 'c');

      await _pump(tester, row(allowDeselect: true));
      await tester.tap(find.textContaining('Rewe'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      semantics.dispose();
    });

    testWidgets('ChipRow(wrap: true) wraps instead of scrolling', (
      tester,
    ) async {
      await _pump(
        tester,
        ChipRow(
          wrap: true,
          chips: [
            for (final l in _labels)
              AppFilterChip(label: l, selected: false, onSelected: (_) {}),
          ],
        ),
      );
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('AppFilterChip', () {
    testWidgets('selected: dark capsule, light text; inactive: neutral fill', (
      tester,
    ) async {
      late AvoColors colors;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            colors = context.colors;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFilterChip(
                  label: 'Für dich',
                  selected: true,
                  onSelected: (_) {},
                ),
                AppFilterChip(
                  label: 'Schnell',
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            );
          },
        ),
      );
      expect(_capsule(tester, 'Für dich').color, colors.chipSelected);
      expect(_capsule(tester, 'Schnell').color, colors.fill);
      final on = tester.widget<Text>(find.text('Für dich')).style!;
      final off = tester.widget<Text>(find.text('Schnell')).style!;
      expect(on.color, colors.onChipSelected);
      expect(off.color, colors.label);
      expect(on.fontWeight, FontWeight.w500);
      expect(_capsule(tester, 'Für dich').shape, isA<StadiumBorder>());
    });

    testWidgets('tap toggles without a haptic', (tester) async {
      final haptics = _haptics(tester);
      var selected = false;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => AppFilterChip(
            label: 'Vegetarisch',
            selected: selected,
            onSelected: (v) => setState(() => selected = v),
          ),
        ),
      );
      await tester.tap(find.text('Vegetarisch'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      await tester.tap(find.text('Vegetarisch'));
      await tester.pumpAndSettle();
      expect(selected, isFalse);
      expect(haptics, isEmpty);
    });

    testWidgets('VoiceOver: button with selected state', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        AppFilterChip(label: 'Laktosefrei', selected: true, onSelected: (_) {}),
      );
      expect(
        tester.getSemantics(find.byType(AppFilterChip)),
        isSemantics(
          label: 'Laktosefrei',
          isButton: true,
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('disabled without onSelected', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const AppFilterChip(label: 'Laktosefrei', selected: false),
      );
      expect(
        tester.getSemantics(find.byType(AppFilterChip)),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      expect(
        find.ancestor(
          of: find.text('Laktosefrei'),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('34 pt visible inside a 44 pt target', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        AppFilterChip(label: 'Schnell', selected: false, onSelected: (_) {}),
      );
      expect(_capsuleSize(tester, 'Schnell').height, 34);
      final target = tester.getSemantics(find.byType(AppFilterChip)).rect;
      expect(target.height, 44);
      expect(target.width, greaterThanOrEqualTo(44));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('grows with Dynamic Type', (tester) async {
      await _pump(
        tester,
        AppFilterChip(label: 'Schnell', selected: false, onSelected: (_) {}),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      expect(_capsuleSize(tester, 'Schnell').height, greaterThan(34));
    });

    testWidgets('pressed: scales while the finger is down', (tester) async {
      await _pump(
        tester,
        AppFilterChip(label: 'Schnell', selected: false, onSelected: (_) {}),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Schnell')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 200));
      final scaled = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(AppFilterChip),
          matching: find.byType(Transform),
        ),
      );
      expect(
        scaled.first.transform.storage[0],
        closeTo(AvoMotion.pressedScale, 0.005),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('ChipRow', () {
    Widget row() => ChipRow(
      chips: [
        for (final label in _labels)
          AppFilterChip(
            label: label,
            selected: label == 'Für dich',
            onSelected: (_) {},
          ),
      ],
    );

    testWidgets('scrolls horizontally with 8 pt gaps up to xxLarge', (
      tester,
    ) async {
      await _pump(tester, row());
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
      final first = tester.getRect(find.byType(AppFilterChip).at(0));
      final second = tester.getRect(find.byType(AppFilterChip).at(1));
      expect(second.left - first.right, 8);
      expect(first.left, AvoSpacing.screen);
    });

    testWidgets('wraps from xxxLarge on', (tester) async {
      await _pump(
        tester,
        row(),
        layout: const LayoutCase(width: 390, scale: 1.35),
      );
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      final last = tester.getRect(find.text('Zurücksetzen'));
      expect(last.right, lessThanOrEqualTo(390), reason: 'nothing off-screen');
    });
  });

  layoutMatrix(
    'ChipRow',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AvoSpacing.l),
      child: ChipRow(
        chips: [
          for (final label in _labels)
            AppFilterChip(
              label: label,
              selected: label == 'Für dich',
              onSelected: (_) {},
            ),
        ],
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'SingleChoiceChipRow with leading and secondary',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AvoSpacing.l),
      child: SingleChoiceChipRow<String>(
        wrap: true,
        value: 'lidl',
        allowDeselect: true,
        onChanged: (_) {},
        choices: const [
          ChipChoice(
            value: 'lidl',
            label: 'Lidl',
            secondaryLabel: '400 m',
            leading: SizedBox.square(dimension: 8),
          ),
          ChipChoice(
            value: 'rewe',
            label: 'Rewe Center Hamburg Mitte',
            secondaryLabel: '1,2 km',
            leading: SizedBox.square(dimension: 8),
          ),
          ChipChoice(value: 'all', label: 'Alle Märkte'),
        ],
      ),
    ),
    checkTapTargets: true,
  );
}
