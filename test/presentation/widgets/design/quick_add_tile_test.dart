import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/quick_add_tile.dart';

import '../../../layout/layout_matrix.dart';

/// D2 grid cell: (390 - 2 × 16 - 2 × 20 - 3 × 12) / 4.
const double _cell = 70.5;

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

/// The scale of the press transform inside [of].
double _scale(WidgetTester tester, Finder of) {
  final transform = tester.widget<Transform>(
    find.descendant(of: of, matching: find.byType(Transform)).first,
  );
  return transform.transform.storage[0];
}

ShapeDecoration _tileDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(QuickAddTile),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

/// The D2 section: 4 columns, 12 pt apart, on a white group.
Widget _grid(BuildContext context, List<Widget> tiles) => Padding(
  padding: const EdgeInsets.all(AvoSpacing.screen),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AvoRadii.group),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AvoSpacing.group),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AvoSpacing.m),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('D2: 82 high, radius 20, neutral fill, image 44 at 8', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Eier', onTap: () {}),
      ),
    );
    final tile = tester.getRect(find.byType(QuickAddTile));
    expect(tile.size, const Size(_cell, 82));
    final d = _tileDecoration(tester);
    expect(d.color, AvoColors.light.fill);
    expect(
      (d.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AvoRadii.card),
    );
    final image = tester.getRect(find.byType(ItemThumb));
    expect(image.size, const Size(44, 44));
    expect(image.top, tile.top + 8);
    expect(image.center.dx, closeTo(tile.center.dx, 0.01));
    final clip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byType(ItemThumb),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, BorderRadius.circular(AvoRadii.imageSmall));
    final label = tester.getRect(find.text('Eier'));
    expect(label.top, image.bottom + 6);
    expect(label.center.dx, closeTo(tile.center.dx, 0.5));
    final style = tester.widget<Text>(find.text('Eier')).style!;
    expect(style.fontSize, 12);
    expect(style.height! * 12, closeTo(16, 0.01));
    expect(style.fontWeight, FontWeight.w500);
  });

  testWidgets('plus disc: 20 pt tint at 6 / 6 with a white cross', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Eier', onTap: () {}),
      ),
    );
    final icon = find.byType(AvoIcon);
    final glyph = tester.widget<AvoIcon>(icon);
    expect(glyph.icon, AvoIcons.plus);
    expect(glyph.color, AvoColors.light.onTint);
    final disc = find
        .ancestor(of: icon, matching: find.byType(DecoratedBox))
        .first;
    final shape =
        tester.widget<DecoratedBox>(disc).decoration as ShapeDecoration;
    expect(shape.color, AvoColors.light.tintFill);
    expect(shape.shape, isA<CircleBorder>());
    final tile = tester.getRect(find.byType(QuickAddTile));
    final rect = tester.getRect(disc);
    expect(rect.size, const Size(20, 20));
    expect(rect.top, tile.top + 6);
    expect(rect.right, tile.right - 6);
  });

  testWidgets('a given image is used, laid out at 44', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(
          name: 'Eier',
          thumb: const ColoredBox(key: Key('photo'), color: Color(0xFFEEDDCC)),
          onTap: () {},
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('photo'))), const Size(44, 44));
    expect(find.byType(ItemThumb), findsNothing);
  });

  testWidgets('tap re-adds; shrinks while pressed', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Eier', onTap: () => taps++),
      ),
    );
    final tile = find.byType(QuickAddTile);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pumpAndSettle();
    expect(_scale(tester, tile), closeTo(AvoMotion.pressedScale, 0.002));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('Reduce Motion: no scaling', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Eier', onTap: () {}),
      ),
      layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
    );
    final tile = find.byType(QuickAddTile);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pumpAndSettle();
    expect(_scale(tester, tile), 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('VoiceOver: one button "Add {name} again" with the full name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(
          name: 'Vollkornbrot',
          label: 'Brot',
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('Brot'), findsOneWidget);
    final finder = find.bySemanticsLabel('Add Vollkornbrot again');
    expect(
      tester.getSemantics(finder),
      isSemantics(isButton: true, hasTapAction: true, isEnabled: true),
    );
    expect(find.bySemanticsLabel('Brot'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('Add Vollkornbrot again'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('disabled: dimmed, VoiceOver reads it as disabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Eier'),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(QuickAddTile),
        matching: find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == 0.4,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Add Eier again')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('a long label wraps and the tile grows', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Hafermilch Barista Edition', onTap: () {}),
      ),
      layout: const LayoutCase(width: 390, scale: 1.35),
    );
    expect(tester.getSize(find.byType(QuickAddTile)).height, greaterThan(82));
    expectNoClippedText(tester);
  });

  testWidgets('dark mode: fill and tint from the dark tokens', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: _cell,
        child: QuickAddTile(name: 'Eier', onTap: () {}),
      ),
      layout: const LayoutCase(
        width: 390,
        scale: 1,
        brightness: Brightness.dark,
      ),
    );
    expect(_tileDecoration(tester).color, AvoColors.dark.fill);
    expect(
      tester.widget<Text>(find.text('Eier')).style!.color,
      AvoColors.dark.label,
    );
  });

  layoutMatrix(
    'QuickAddTile grid of four (D2 section)',
    (context) => _grid(context, [
      QuickAddTile(name: 'Eier', onTap: () {}),
      QuickAddTile(name: 'Olivenöl', onTap: () {}),
      QuickAddTile(name: 'Vollkornbrot', label: 'Brot', onTap: () {}),
      QuickAddTile(name: 'Bio-Bananen aus Ecuador', onTap: () {}),
    ]),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'QuickAddTile grid of two with long names',
    (context) => _grid(context, [
      QuickAddTile(name: 'Laktosefreie Bio-Vollmilch', onTap: () {}),
      QuickAddTile(name: 'Griechischer Joghurt 10 %', onTap: () {}),
    ]),
    scrollable: true,
  );
}
