import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

import '../../../layout/layout_matrix.dart';

const _long = 'Bio-Vollmilch 3,8 % Fett aus der Region, laktosefrei';
const _pillText = '0,99 € · Lidl';

/// Stand-in for Teil B's offer pill (D2: 11/13 semibold tint on tintSoft,
/// padding 3 8). Labelled like the real one, so the row's label shows it.
class _OfferPill extends StatelessWidget {
  const _OfferPill([this.text = _pillText]);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'im Angebot $text',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.tintSoft,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              text,
              style: context.text(
                AvoTextStyle.caption2,
                weight: FontWeight.w600,
                color: colors.tint,
                tabular: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
  TextDirection? direction,
  bool scroll = false,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Widget content = scroll
      ? SingleChildScrollView(child: child)
      : Align(alignment: Alignment.topCenter, child: child);
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

Widget _thumb() => const ItemThumb();

void main() {
  group('D2 measurements', () {
    testWidgets('regular: 60 pt, circle at 16, image at 54, text at 110', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Hafermilch',
          subtitle: '2 L',
          thumb: _thumb(),
          onToggle: (_) {},
          onTap: () {},
        ),
      );
      final row = tester.getRect(find.byType(ItemRow));
      expect(row.height, 60);
      final circle = tester.getRect(find.byType(CheckCircle));
      expect(circle.size, const Size(44, 44));
      // Visible 26 pt circle starts at the 16 pt row inset (D2 margin -9).
      expect(circle.left + (44 - 26) / 2, 16);
      expect(circle.center.dy, row.center.dy);
      final thumb = tester.getRect(find.byType(ItemThumb));
      expect(thumb.size, const Size(44, 44));
      expect(thumb.left, 54);
      final title = tester.getRect(find.text('Hafermilch'));
      expect(title.left, 110);
      expect(title.left, ItemRow.separatorIndent);

      final titleStyle = tester.widget<Text>(find.text('Hafermilch')).style!;
      expect(titleStyle.fontSize, 17);
      expect(titleStyle.fontWeight, FontWeight.w400);
      expect(titleStyle.color, AvoColors.light.label);
      expect(titleStyle.decoration, TextDecoration.none);
      final sub = tester.widget<Text>(find.text('2 L')).style!;
      expect(sub.fontSize, 15);
      expect(sub.height! * 15, closeTo(20, 0.01));
      expect(sub.color, AvoColors.light.secondaryLabel);
      expect(sub.fontFeatures, contains(const FontFeature.tabularFigures()));

      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byType(ItemThumb),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(AvoRadii.imageSmall));
    });

    testWidgets('large: 76 pt, 36 pt circle in 56, image 52, 20/25 semibold', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Avocados',
          subtitle: '3 St.',
          thumb: _thumb(),
          size: ItemRowSize.large,
          onToggle: (_) {},
        ),
      );
      expect(tester.getSize(find.byType(ItemRow)).height, 76);
      final check = tester.widget<CheckCircle>(find.byType(CheckCircle));
      expect(check.size, CheckCircleSize.large);
      final circle = tester.getRect(find.byType(CheckCircle));
      expect(circle.size, const Size(56, 56));
      expect(circle.left + (56 - 36) / 2, 16);
      final thumb = tester.getRect(find.byType(ItemThumb));
      expect(thumb.size, const Size(52, 52));
      expect(thumb.left, 16 + 36 + 14);
      final title = tester.getRect(find.text('Avocados'));
      expect(title.left, ItemRow.separatorIndentLarge);
      final style = tester.widget<Text>(find.text('Avocados')).style!;
      expect(style.fontSize, 20);
      expect(style.height! * 20, closeTo(25, 0.01));
      expect(style.fontWeight, FontWeight.w600);
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byType(ItemThumb),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(AvoRadii.imageMedium));
    });

    testWidgets('done: secondary, struck through, image at half opacity', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Eier',
          subtitle: '10 St.',
          thumb: _thumb(),
          checked: true,
          onToggle: (_) {},
        ),
      );
      final style = tester.widget<Text>(find.text('Eier')).style!;
      expect(style.color, AvoColors.light.secondaryLabel);
      expect(style.decoration, TextDecoration.lineThrough);
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(ItemThumb),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
      expect(
        tester.widget<CheckCircle>(find.byType(CheckCircle)).checked,
        true,
      );
    });

    testWidgets('grows with a long name instead of cutting it', (tester) async {
      await _pump(
        tester,
        ItemRow(
          title: _long,
          subtitle: '1 L · für den Kaffee am Morgen',
          thumb: _thumb(),
          trailing: const _OfferPill(),
          onToggle: (_) {},
        ),
        layout: const LayoutCase(width: 320, scale: 1),
      );
      expect(tester.getSize(find.byType(ItemRow)).height, greaterThan(60));
      expectNoClippedText(tester);
    });

    testWidgets('dark mode uses the dark tokens', (tester) async {
      await _pump(
        tester,
        ItemRow(title: 'Feta', subtitle: '200 g', onToggle: (_) {}),
        layout: const LayoutCase(
          width: 390,
          scale: 1,
          brightness: Brightness.dark,
        ),
      );
      expect(
        tester.widget<Text>(find.text('Feta')).style!.color,
        AvoColors.dark.label,
      );
      expect(
        tester.widget<Text>(find.text('200 g')).style!.color,
        AvoColors.dark.secondaryLabel,
      );
    });
  });

  group('taps', () {
    testWidgets('circle and the leading zone check off with the light haptic', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      final values = <bool>[];
      var opened = 0;
      await _pump(
        tester,
        ItemRow(
          title: 'Hafermilch',
          subtitle: '2 L',
          thumb: _thumb(),
          onToggle: values.add,
          onTap: () => opened++,
        ),
      );
      await tester.tap(find.byType(CheckCircle));
      // The zone outside the 44 pt circle target, at the very edge.
      final row = tester.getRect(find.byType(ItemRow));
      await tester.tapAt(Offset(row.left + 3, row.top + 3));
      await tester.tapAt(Offset(row.left + 52, row.center.dy));
      expect(values, [true, true, true]);
      expect(haptics, List.filled(3, 'HapticFeedbackType.lightImpact'));
      expect(opened, 0);
    });

    testWidgets('the rest of the row opens the item, no haptic', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      final values = <bool>[];
      var opened = 0;
      await _pump(
        tester,
        ItemRow(
          title: 'Hafermilch',
          subtitle: '2 L',
          thumb: _thumb(),
          trailing: const _OfferPill(),
          onToggle: values.add,
          onTap: () => opened++,
        ),
      );
      await tester.tap(find.text('Hafermilch'));
      await tester.tap(find.byType(ItemThumb));
      await tester.tap(find.byType(_OfferPill));
      expect(opened, 3);
      expect(values, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('without onTap the whole row checks off (shopping mode)', (
      tester,
    ) async {
      final values = <bool>[];
      await _pump(
        tester,
        ItemRow(
          title: 'Avocados',
          checked: true,
          size: ItemRowSize.large,
          onToggle: values.add,
        ),
      );
      await tester.tap(find.text('Avocados'));
      expect(values, [false]);
    });

    testWidgets('highlights while pressed, never scales', (tester) async {
      await _pump(
        tester,
        ItemRow(title: 'Hafermilch', onToggle: (_) {}, onTap: () {}),
      );
      Color? highlight() {
        final boxes = tester.widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(ItemRow),
            matching: find.byType(ColoredBox),
          ),
        );
        for (final b in boxes) {
          if (b.color.toARGB32() != AvoColors.light.fill.toARGB32() &&
              b.color.a > 0) {
            return b.color;
          }
        }
        return null;
      }

      expect(highlight(), isNull);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hafermilch')),
      );
      await tester.pump();
      expect(highlight(), AvoColors.light.fillStrong);
      expect(
        find.descendant(
          of: find.byType(ItemRow),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(highlight(), isNull);
    });

    testWidgets('no callbacks: circle disabled, nothing happens', (
      tester,
    ) async {
      await _pump(tester, const ItemRow(title: 'Hafermilch'));
      expect(
        tester.widget<CheckCircle>(find.byType(CheckCircle)).onChanged,
        isNull,
      );
      await tester.tap(find.text('Hafermilch'));
      await tester.tap(find.byType(CheckCircle));
    });

    testWidgets('Reduce Motion: the circle switches at once', (tester) async {
      var checked = false;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ItemRow(
            title: 'Hafermilch',
            checked: checked,
            onToggle: (v) => setState(() => checked = v),
          ),
        ),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      await tester.tap(find.byType(CheckCircle));
      await tester.pump();
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(CheckCircle),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // ignore: avoid_dynamic_calls
      final fill = (paint.painter as dynamic).progress as Animation<double>;
      expect(fill.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('states', () {
    testWidgets('pending, done by other: passed to the circle', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            ItemRow(
              key: const Key('pending'),
              title: 'Bananen',
              checked: true,
              checkState: CheckState.pending,
              onToggle: (_) {},
            ),
            ItemRow(
              key: const Key('other'),
              title: 'Feta',
              subtitle: 'gerade von Lena',
              checked: true,
              checkState: CheckState.doneByOther,
              checkedBy: 'Lena',
              statusLabel: 'von Lena',
              onToggle: (_) {},
            ),
          ],
        ),
      );
      CheckCircle circleOf(String key) => tester.widget<CheckCircle>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(CheckCircle),
        ),
      );
      expect(circleOf('pending').state, CheckState.pending);
      final other = circleOf('other');
      expect(other.state, CheckState.doneByOther);
      expect(other.byName, 'Lena');
      expect(other.statusLabel, 'von Lena');
      expect(find.text('gerade von Lena'), findsOneWidget);
    });

    testWidgets('failed: "Not saved" below the name in destructive', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ItemRow(
          title: 'Backpapier',
          subtitle: '1 Rolle',
          checked: true,
          checkState: CheckState.failed,
          onToggle: (_) {},
        ),
      );
      final status = tester.widget<Text>(find.text('Not saved'));
      expect(status.style!.color, AvoColors.light.destructive);
      // Not struck through: the change did not happen.
      expect(
        tester.widget<Text>(find.text('Backpapier')).style!.decoration,
        TextDecoration.none,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Backpapier, 1 Rolle')),
        isSemantics(value: 'Not saved'),
      );
      handle.dispose();
    });
  });

  group('VoiceOver', () {
    testWidgets('one element: name, quantity and the pill; double tap checks', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final values = <bool>[];
      var opened = 0;
      await _pump(
        tester,
        ItemRow(
          title: 'Avocados',
          subtitle: '3 St.',
          thumb: _thumb(),
          trailing: const _OfferPill(),
          onToggle: values.add,
          onTap: () => opened++,
          openLabel: 'Bearbeiten',
          semanticActions: {'Löschen': () => opened += 10},
        ),
      );
      final finder = find.bySemanticsLabel(RegExp(r'^Avocados, 3 St\.'));
      expect(finder, findsOneWidget);
      final node = tester.getSemantics(finder);
      expect(node.label, 'Avocados, 3 St.\nim Angebot $_pillText');
      expect(
        node,
        isSemantics(
          isButton: true,
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          customActions: const [
            CustomSemanticsAction(label: 'Bearbeiten'),
            CustomSemanticsAction(label: 'Löschen'),
          ],
        ),
      );
      // Nothing else of the row is its own element.
      expect(find.bySemanticsLabel(RegExp('abhaken|Check off')), findsNothing);
      expect(find.bySemanticsLabel('3 St.'), findsNothing);

      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Avocados')));
      expect(values, [true]);
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp(r'^Avocados')),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Bearbeiten'),
        ),
      );
      expect(opened, 1);
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp(r'^Avocados')),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Löschen'),
        ),
      );
      expect(opened, 11);
      handle.dispose();
    });

    testWidgets('done: checked with the value "done"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ItemRow(
          title: 'Eier',
          subtitle: '10 St.',
          checked: true,
          onToggle: (_) {},
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Eier, 10 St.')),
        isSemantics(hasCheckedState: true, isChecked: true, value: 'done'),
      );
      handle.dispose();
    });

    testWidgets('only onTap: double tap opens', (tester) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await _pump(tester, ItemRow(title: 'Eier', onTap: () => opened++));
      tester.semantics.tap(find.semantics.byLabel('Eier'));
      expect(opened, 1);
      handle.dispose();
    });
  });

  group('layout', () {
    testWidgets('pill beside the text when there is room', (tester) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Avocados',
          subtitle: '3 St.',
          thumb: _thumb(),
          trailing: const _OfferPill(),
          onToggle: (_) {},
        ),
      );
      final pill = tester.getRect(find.byType(_OfferPill));
      final row = tester.getRect(find.byType(ItemRow));
      expect(pill.right, row.right - 16);
      expect(pill.center.dy, closeTo(row.center.dy, 0.5));
      expect(row.height, 60);
    });

    testWidgets('pill below the text on a narrow row with large text', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Avocados',
          subtitle: '3 St.',
          thumb: _thumb(),
          trailing: const _OfferPill(),
          onToggle: (_) {},
        ),
        layout: const LayoutCase(width: 320, scale: 1.35),
      );
      final pill = tester.getRect(find.byType(_OfferPill));
      final sub = tester.getRect(find.text('3 St.'));
      expect(pill.top, greaterThanOrEqualTo(sub.bottom));
      expect(pill.left, sub.left);
    });

    testWidgets('an empty trailing slot adds no space', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            ItemRow(
              key: const Key('a'),
              title: _long,
              thumb: _thumb(),
              onToggle: (_) {},
            ),
            ItemRow(
              key: const Key('b'),
              title: _long,
              thumb: _thumb(),
              trailing: const SizedBox.shrink(),
              onToggle: (_) {},
            ),
          ],
        ),
        layout: const LayoutCase(width: 320, scale: 1),
      );
      expect(
        tester.getSize(find.byKey(const Key('b'))),
        tester.getSize(find.byKey(const Key('a'))),
      );
    });

    testWidgets('from AX1: no image, pill under the name beside the quantity', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: _long,
          subtitle: '1 L',
          thumb: _thumb(),
          trailing: const _OfferPill(),
          onToggle: (_) {},
        ),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      expect(find.byType(ItemThumb), findsNothing);
      final title = tester.getRect(find.text(_long));
      final sub = tester.getRect(find.text('1 L'));
      final pill = tester.getRect(find.byType(_OfferPill));
      expect(pill.top, greaterThanOrEqualTo(title.bottom));
      expect(pill.left, greaterThan(sub.right), reason: 'beside the quantity');
      expect(pill.center.dy, closeTo(sub.center.dy, 1));
      final circle = tester.getRect(find.byType(CheckCircle));
      final context = tester.element(find.byType(ItemRow));
      final line = context.typography.lineHeightOf(AvoTextStyle.body);
      expect(circle.center.dy, closeTo(title.top + line / 2, 0.5));
      expect(
        title.left,
        ItemRow.separatorIndentOf(context),
        reason: 'text starts after the check zone',
      );
    });

    testWidgets('AX5 at 320 pt with bold text: nothing overlaps or clips', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: _long,
          subtitle: '2 Packungen · für das Frühstück',
          thumb: _thumb(),
          trailing: const _OfferPill('1,29 € statt 1,79 € · Rewe'),
          onToggle: (_) {},
          onTap: () {},
        ),
        layout: const LayoutCase(width: 320, scale: 3.1, bold: true),
        scroll: true,
      );
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      final row = tester.getRect(find.byType(ItemRow));
      final rects = {
        'circle': tester.getRect(find.byType(CheckCircle)),
        'title': tester.getRect(find.text(_long)),
        'subtitle': tester.getRect(
          find.text('2 Packungen · für das Frühstück'),
        ),
        'pill': tester.getRect(find.byType(_OfferPill)),
      };
      for (final entry in rects.entries) {
        expect(
          row.contains(entry.value.topLeft) &&
              row.contains(entry.value.bottomRight - const Offset(0.01, 0.01)),
          isTrue,
          reason: '${entry.key} inside the row',
        );
      }
      final names = rects.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final overlap = rects[names[i]]!.intersect(rects[names[j]]!);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason: '${names[i]} overlaps ${names[j]}',
          );
        }
      }
    });

    testWidgets('right to left: circle at the right edge', (tester) async {
      await _pump(
        tester,
        ItemRow(title: 'Avocados', thumb: _thumb(), onToggle: (_) {}),
        direction: TextDirection.rtl,
      );
      final row = tester.getRect(find.byType(ItemRow));
      final circle = tester.getRect(find.byType(CheckCircle));
      expect(row.right - (circle.right - (44 - 26) / 2), 16);
      final title = tester.getRect(find.text('Avocados'));
      expect(row.right - title.right, ItemRow.separatorIndent);
    });

    testWidgets('separatorIndentOf', (tester) async {
      await _pump(tester, const SizedBox());
      var context = tester.element(find.byType(SizedBox).last);
      expect(ItemRow.separatorIndentOf(context), 110);
      expect(ItemRow.separatorIndentOf(context, size: ItemRowSize.large), 132);
      expect(ItemRow.separatorIndentOf(context, size: ItemRowSize.compact), 88);
      expect(
        ItemRow.separatorIndentOf(
          context,
          size: ItemRowSize.compact,
          withThumb: false,
        ),
        49,
      );
      expect(ItemRow.separatorIndentOf(context, withThumb: false), 54);
      await _pump(
        tester,
        const SizedBox(),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      context = tester.element(find.byType(SizedBox).last);
      expect(ItemRow.separatorIndentOf(context), 54);
    });
  });

  group('compact (avo.md 15, D2 X-Avo)', () {
    testWidgets('56 pt, 22 pt circle in 44, image 36 radius 9, hairline 88', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Hafermilch',
          subtitle: '2 L',
          thumb: const ItemThumb(),
          size: ItemRowSize.compact,
          onToggle: (_) {},
          onTap: () {},
        ),
      );
      final row = tester.getRect(find.byType(ItemRow));
      expect(row.height, 56);
      final circle = tester.getRect(find.byType(CheckCircle));
      expect(circle.size, const Size(44, 44));
      expect(circle.left + (44 - 22) / 2, 16);
      expect(circle.center.dy, row.center.dy);
      final thumb = tester.getRect(find.byType(ItemThumb));
      expect(thumb.size, const Size(36, 36));
      expect(thumb.left, 49, reason: 'after the 44 pt check target');
      final clip = tester.widget<ClipRRect>(
        find
            .descendant(
              of: find.byType(ItemRow),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect((clip.borderRadius as BorderRadius).topLeft.x, 9);
      final title = tester.getRect(find.text('Hafermilch'));
      expect(title.left, 95);
      expect(ItemRow.separatorIndentCompact, 88);
      expect(title.left - ItemRow.separatorIndentCompact, 7);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(CheckCircle),
            matching: find.byType(CustomPaint),
          ),
        ),
        const Size(22, 22),
      );
    });

    testWidgets('checks off and opens like the regular row', (tester) async {
      final values = <bool>[];
      var opened = 0;
      await _pump(
        tester,
        ItemRow(
          title: 'Hafermilch',
          size: ItemRowSize.compact,
          onToggle: values.add,
          onTap: () => opened++,
        ),
      );
      await tester.tap(find.byType(CheckCircle));
      await tester.tap(find.text('Hafermilch'));
      expect(values, [true]);
      expect(opened, 1);
    });
  });

  group('trailing slot', () {
    testWidgets('a tap on the slot reaches the slot, not the row', (
      tester,
    ) async {
      var slot = 0;
      var opened = 0;
      var toggled = 0;
      await _pump(
        tester,
        ItemRow(
          title: 'Milch',
          subtitle: '2 L',
          thumb: _thumb(),
          trailing: GestureDetector(
            key: const Key('slot'),
            behavior: HitTestBehavior.opaque,
            onTap: () => slot++,
            child: const _OfferPill(),
          ),
          onToggle: (_) => toggled++,
          onTap: () => opened++,
        ),
      );
      await tester.tap(find.byKey(const Key('slot')));
      expect((slot, opened, toggled), (1, 0, 0));
      await tester.tap(find.text('Milch'));
      expect((slot, opened, toggled), (1, 1, 0));
    });

    testWidgets('trailingSemanticsLabel joins the label, actions are custom', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var offer = 0;
      await _pump(
        tester,
        ItemRow(
          title: 'Milch',
          subtitle: '2 Liter',
          thumb: _thumb(),
          trailing: const _OfferPill('1,29 €'),
          trailingSemanticsLabel: 'Angebot 1,29 € bei Lidl',
          trailingActions: {'Angebot ansehen': () => offer++},
          onToggle: (_) {},
          onTap: () {},
          openLabel: 'Bearbeiten',
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^Milch')));
      expect(node.label, 'Milch, 2 Liter, Angebot 1,29 € bei Lidl');
      expect(
        node,
        isSemantics(
          customActions: const [
            CustomSemanticsAction(label: 'Bearbeiten'),
            CustomSemanticsAction(label: 'Angebot ansehen'),
          ],
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('im Angebot')),
        findsNothing,
        reason: "the pill's own semantics are hidden",
      );
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Milch')),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Angebot ansehen'),
        ),
      );
      expect(offer, 1);
      handle.dispose();
    });

    testWidgets('from AX1 the slot wraps below a long quantity', (
      tester,
    ) async {
      await _pump(
        tester,
        ItemRow(
          title: 'Milch',
          subtitle: '2 Packungen · für das Frühstück am Sonntag',
          thumb: _thumb(),
          trailing: const _OfferPill('1,29 € statt 1,79 € · Rewe'),
          onToggle: (_) {},
        ),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      final sub = tester.getRect(
        find.text('2 Packungen · für das Frühstück am Sonntag'),
      );
      final pill = tester.getRect(find.byType(_OfferPill));
      expect(pill.top, greaterThanOrEqualTo(sub.bottom));
      expect(pill.left, sub.left);
    });
  });

  group('context menu', () {
    for (final size in [ItemRowSize.regular, ItemRowSize.large]) {
      testWidgets('long press opens the menu at the finger ($size)', (
        tester,
      ) async {
        var chosen = 0;
        var opened = 0;
        await _pump(
          tester,
          ItemRow(
            title: 'Milch',
            subtitle: '2 L',
            size: size,
            trailing: const _OfferPill(),
            contextMenuItems: [
              AvoMenuItem(
                label: 'Angebot ansehen',
                icon: AvoIcons.tag,
                onSelected: () => chosen++,
              ),
              const AvoMenuDivider(),
              AvoMenuItem(
                label: 'Löschen',
                destructive: true,
                onSelected: () => chosen += 10,
              ),
            ],
            onToggle: (_) {},
            onTap: () => opened++,
          ),
        );
        await tester.longPress(find.byType(_OfferPill));
        await tester.pumpAndSettle();
        expect(find.text('Angebot ansehen'), findsOneWidget);
        expect(opened, 0, reason: 'a long press is not a tap');
        await tester.tap(find.text('Angebot ansehen'));
        await tester.pumpAndSettle();
        expect(chosen, 1);
        expect(find.text('Angebot ansehen'), findsNothing);
      });
    }

    testWidgets('without entries a long press does nothing', (tester) async {
      await _pump(
        tester,
        ItemRow(title: 'Milch', onToggle: (_) {}, onTap: () {}),
      );
      await tester.longPress(find.text('Milch'));
      await tester.pumpAndSettle();
      expect(find.byType(Overlay), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled entries are also custom actions', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ItemRow(
          title: 'Milch',
          contextMenuItems: [
            AvoMenuItem(label: 'Verschieben', onSelected: () {}),
            AvoMenuItem(label: 'Gesperrt', enabled: false, onSelected: () {}),
            const AvoMenuDivider(),
          ],
          onToggle: (_) {},
          onTap: () {},
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Milch'))),
        isSemantics(
          customActions: const [CustomSemanticsAction(label: 'Verschieben')],
        ),
      );
      handle.dispose();
    });
  });

  group('swipe actions', () {
    testWidgets('swipe reveals the actions, they are custom actions too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var deleted = 0;
      await _pump(
        tester,
        InsetSection(
          children: [
            ItemRow(
              title: 'Milch',
              subtitle: '2 L',
              swipeActions: [
                SwipeAction(
                  label: 'Löschen',
                  destructive: true,
                  onPressed: () => deleted++,
                ),
              ],
              onToggle: (_) {},
              onTap: () {},
            ),
          ],
        ),
      );
      await tester.drag(find.text('Milch'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text('Löschen'), findsOneWidget);
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Milch'))),
        isSemantics(
          customActions: const [CustomSemanticsAction(label: 'Löschen')],
        ),
      );
      handle.dispose();
    });
  });

  group('ItemThumb', () {
    testWidgets('neutral square with the D2 radius for its size', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            ItemThumb(key: Key('s')),
            SizedBox.square(dimension: 36, child: ItemThumb(key: Key('c'))),
            SizedBox.square(dimension: 52, child: ItemThumb(key: Key('m'))),
            ItemThumb(key: Key('l'), size: 88),
          ],
        ),
      );
      double radius(String key) {
        final clip = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(ClipRRect),
          ),
        );
        return (clip.borderRadius as BorderRadius).topLeft.x;
      }

      expect(tester.getSize(find.byKey(const Key('s'))), const Size(44, 44));
      expect(radius('s'), 10);
      expect(radius('c'), 10, reason: 'unchanged for existing callers');
      expect(tester.getSize(find.byKey(const Key('m'))), const Size(52, 52));
      expect(radius('m'), 12);
      expect(tester.getSize(find.byKey(const Key('l'))), const Size(88, 88));
      expect(radius('l'), 20);
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const Key('s')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, AvoColors.light.fill);
    });

    testWidgets('decorative unless labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          children: [
            ItemThumb(),
            ItemThumb(semanticLabel: 'Foto von Hafermilch'),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Foto von Hafermilch')),
        isSemantics(isImage: true),
      );
      handle.dispose();
    });
  });

  group('AdaptiveTrailing', () {
    testWidgets('zero-size trailing takes no gap, wide one moves below', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 300,
          child: Column(
            children: [
              AdaptiveTrailing(
                key: const Key('empty'),
                trailing: const SizedBox.shrink(),
                child: const SizedBox(height: 20, width: 300),
              ),
              AdaptiveTrailing(
                key: const Key('side'),
                trailing: const SizedBox(width: 100, height: 10),
                child: const SizedBox(height: 20, width: 50),
              ),
              AdaptiveTrailing(
                key: const Key('below'),
                trailing: const SizedBox(width: 200, height: 10),
                child: const SizedBox(height: 20, width: 50),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('empty'))),
        const Size(300, 20),
      );
      expect(
        tester.getSize(find.byKey(const Key('side'))),
        const Size(300, 20),
      );
      expect(
        tester.getSize(find.byKey(const Key('below'))),
        const Size(300, 20 + AvoSpacing.xs + 10),
      );
    });
  });

  layoutMatrix(
    'ItemRow regular: image, long name, offer pill',
    (context) => InsetSection(
      header: 'Milchprodukte',
      separatorIndent: ItemRow.separatorIndentOf(context),
      children: [
        ItemRow(
          title: _long,
          subtitle: '2 Packungen · für das Frühstück',
          thumb: const ItemThumb(),
          trailing: const _OfferPill('1,29 € statt 1,79 € · Rewe'),
          onToggle: (_) {},
          onTap: () {},
          openLabel: 'Bearbeiten',
        ),
        ItemRow(
          title: 'Avocados',
          subtitle: '3 St.',
          thumb: const ItemThumb(),
          trailing: const _OfferPill(),
          onToggle: (_) {},
          onTap: () {},
        ),
        ItemRow(
          title: 'Eier',
          subtitle: '10 St.',
          thumb: const ItemThumb(),
          checked: true,
          onToggle: (_) {},
          onTap: () {},
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'ItemRow states: pending, failed, done by other',
    (context) => InsetSection(
      separatorIndent: ItemRow.separatorIndentOf(context),
      children: [
        ItemRow(
          title: 'Backpapier, ungebleicht, 38 cm breit',
          subtitle: '1 Rolle',
          thumb: const ItemThumb(),
          checked: true,
          checkState: CheckState.pending,
          onToggle: (_) {},
        ),
        ItemRow(
          title: 'Laktosefreie Bio-Vollmilch',
          subtitle: '2 L',
          thumb: const ItemThumb(),
          checkState: CheckState.failed,
          onToggle: (_) {},
        ),
        ItemRow(
          title: 'Griechischer Feta aus Schafsmilch',
          subtitle: 'gerade von Lena',
          thumb: const ItemThumb(),
          checked: true,
          checkState: CheckState.doneByOther,
          checkedBy: 'Lena',
          onToggle: (_) {},
        ),
      ],
    ),
    scrollable: true,
  );

  layoutMatrix(
    'ItemRow large (shopping mode): long name and pill',
    (context) => InsetSection(
      plain: true,
      separatorIndent: ItemRow.separatorIndentOf(
        context,
        size: ItemRowSize.large,
      ),
      children: [
        ItemRow(
          title: _long,
          subtitle: '2 Packungen',
          thumb: const ItemThumb(),
          trailing: const _OfferPill('1,29 €'),
          size: ItemRowSize.large,
          onToggle: (_) {},
        ),
        ItemRow(
          title: 'Hähnchenbrustfilet',
          subtitle: '400 g',
          thumb: const ItemThumb(),
          size: ItemRowSize.large,
          checked: true,
          onToggle: (_) {},
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'ItemRow compact: image, long name, pill, long-press menu',
    (context) => InsetSection(
      separatorIndent: ItemRow.separatorIndentOf(
        context,
        size: ItemRowSize.compact,
      ),
      children: [
        ItemRow(
          title: _long,
          subtitle: '2 Packungen · für das Frühstück',
          thumb: const ItemThumb(),
          trailing: const _OfferPill('1,29 € statt 1,79 € · Rewe'),
          trailingSemanticsLabel: 'Angebot 1,29 € bei Rewe',
          size: ItemRowSize.compact,
          contextMenuItems: [
            AvoMenuItem(label: 'Angebot ansehen', onSelected: () {}),
          ],
          onToggle: (_) {},
          onTap: () {},
        ),
        ItemRow(
          title: 'Eier',
          subtitle: '10 St.',
          thumb: const ItemThumb(),
          checked: true,
          size: ItemRowSize.compact,
          onToggle: (_) {},
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
