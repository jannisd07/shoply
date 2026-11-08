import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

import '../../../layout/layout_matrix.dart';

const _rename = 'Liste umbenennen';
const _hideDone =
    'Erledigte Artikel ausblenden und ans Ende der Liste schieben';
const _delete = 'Liste löschen';

List<AvoMenuEntry> _items({
  List<String>? log,
  bool renameEnabled = true,
  bool withCheck = false,
}) => [
  AvoMenuItem(
    label: _rename,
    icon: AvoIcons.share,
    enabled: renameEnabled,
    onSelected: () => log?.add('rename'),
  ),
  AvoMenuItem(
    label: _hideDone,
    subtitle: 'Für alle 4 Mitglieder',
    checked: withCheck,
    onSelected: () => log?.add('hide'),
  ),
  const AvoMenuDivider(),
  AvoMenuItem(
    label: _delete,
    icon: AvoIcons.trash,
    destructive: true,
    onSelected: () => log?.add('delete'),
  ),
];

/// A screen with a "more" button at [at] (toolbar position by default).
Widget _screen(List<AvoMenuEntry> items, {Alignment at = Alignment.topRight}) =>
    SizedBox.expand(
      child: Align(
        alignment: at,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 54, 16, 96),
          child: AvoMenuButton(items: items),
        ),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(layoutHarness(layout, child));
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(AvoMenuButton));
  await tester.pumpAndSettle();
}

/// The menu surface (clip around the rows).
Rect _menuRect(WidgetTester tester, [String label = _rename]) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(ClipRRect)).first,
);

SemanticsNode _ancestorWith(SemanticsNode node, SemanticsAction action) {
  SemanticsNode? n = node;
  while (n != null && !n.getSemanticsData().hasAction(action)) {
    n = n.parent;
  }
  return n!;
}

void main() {
  group('showAvoMenu', () {
    testWidgets('opens from the button; a tap outside closes it', (
      tester,
    ) async {
      await _pump(tester, _screen(_items()));
      expect(find.text(_rename), findsNothing);
      await _open(tester);
      expect(find.text(_rename), findsOneWidget);
      expect(find.text(_delete), findsOneWidget);
      await tester.tapAt(const Offset(40, 700));
      await tester.pumpAndSettle();
      expect(find.text(_rename), findsNothing);
    });

    testWidgets('choosing a row closes the menu and calls onSelected', (
      tester,
    ) async {
      final log = <String>[];
      await _pump(tester, _screen(_items(log: log)));
      await _open(tester);
      await tester.tap(find.text(_hideDone));
      expect(log, ['hide']);
      await tester.pumpAndSettle();
      expect(find.text(_hideDone), findsNothing);
    });

    testWidgets('a disabled row is dimmed and ignores taps', (tester) async {
      final log = <String>[];
      await _pump(tester, _screen(_items(log: log, renameEnabled: false)));
      await _open(tester);
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text(_rename), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, 0.4);
      await tester.tap(find.text(_rename), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.text(_rename), findsOneWidget, reason: 'menu stays open');
    });

    testWidgets('destructive row: label and icon in the destructive colour', (
      tester,
    ) async {
      await _pump(tester, _screen(_items()));
      await _open(tester);
      final text = tester.widget<Text>(find.text(_delete));
      expect(text.style!.color, AvoColors.light.destructive);
      final icon = tester.widget<AvoIcon>(
        find.byWidgetPredicate((w) => w is AvoIcon && w.icon == AvoIcons.trash),
      );
      expect(icon.color, AvoColors.light.destructive);
      final normal = tester.widget<Text>(find.text(_rename));
      expect(normal.style!.color, AvoColors.light.label);
      expect(normal.style!.fontSize, 17);
    });

    testWidgets('checked row shows a checkmark; labels stay aligned', (
      tester,
    ) async {
      await _pump(tester, _screen(_items(withCheck: true)));
      await _open(tester);
      final check = find.byWidgetPredicate(
        (w) => w is AvoIcon && w.icon == AvoIcons.check,
      );
      expect(check, findsOneWidget);
      expect(
        tester.getRect(check).right,
        lessThan(tester.getRect(find.text(_hideDone)).left),
      );
      expect(
        tester.getRect(find.text(_rename)).left,
        tester.getRect(find.text(_hideDone)).left,
      );
    });

    testWidgets('subtitle in 15/20 secondary text, read with the label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _screen(_items()));
      await _open(tester);
      final subtitle = tester.widget<Text>(find.text('Für alle 4 Mitglieder'));
      expect(subtitle.style!.fontSize, 15);
      expect(subtitle.style!.color, AvoColors.light.secondaryLabel);
      expect(
        find.bySemanticsLabel('$_hideDone, Für alle 4 Mitglieder'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('rows at least 44 pt; 250 pt wide under a right trigger', (
      tester,
    ) async {
      await _pump(tester, _screen(_items()));
      final button = tester.getRect(find.byType(AvoMenuButton));
      await _open(tester);
      final menu = _menuRect(tester);
      expect(menu.width, 250);
      expect(menu.right, closeTo(button.right, 0.01));
      expect(menu.top, closeTo(button.bottom + 8, 0.01));
      final row = tester.getSize(
        find
            .ancestor(
              of: find.text(_rename),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(row.height, greaterThanOrEqualTo(44));
    });

    testWidgets('a trigger at the bottom left opens above, leading-aligned', (
      tester,
    ) async {
      await _pump(tester, _screen(_items(), at: Alignment.bottomLeft));
      final button = tester.getRect(find.byType(AvoMenuButton));
      await _open(tester);
      final menu = _menuRect(tester);
      expect(menu.left, closeTo(button.left, 0.01));
      expect(menu.bottom, closeTo(button.top - 8, 0.01));
    });

    testWidgets('a centred trigger centres the menu', (tester) async {
      await _pump(tester, _screen(_items(), at: Alignment.topCenter));
      final button = tester.getRect(find.byType(AvoMenuButton));
      await _open(tester);
      expect(_menuRect(tester).center.dx, closeTo(button.center.dx, 0.01));
    });

    testWidgets('many rows: stays inside the safe area and scrolls', (
      tester,
    ) async {
      final items = [
        for (var i = 0; i < 24; i++)
          AvoMenuItem(label: 'Wocheneinkauf $i', onSelected: () {}),
      ];
      await _pump(tester, _screen(items));
      await _open(tester);
      final menu = _menuRect(tester, 'Wocheneinkauf 0');
      expect(menu.bottom, lessThanOrEqualTo(844 - 34 - 8 + 0.01));
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('from AX1 the menu takes the width minus 16 pt margins', (
      tester,
    ) async {
      await _pump(
        tester,
        _screen(_items()),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      await _open(tester);
      final menu = _menuRect(tester);
      expect(menu.width, 390 - 32);
      expect(menu.left, 16);
    });

    testWidgets('anchorRect places the menu at that rectangle', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAvoMenu(
                context,
                anchorRect: const Rect.fromLTWH(20, 100, 44, 44),
                items: _items(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final menu = _menuRect(tester);
      expect(menu.left, 20);
      expect(menu.top, 152);
    });

    testWidgets('anchorKey opens from that widget', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              const SizedBox(height: 300),
              SizedBox(key: key, width: 44, height: 44),
              TextButton(
                onPressed: () =>
                    showAvoMenu(context, anchorKey: key, items: _items()),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      );
      final anchor = tester.getRect(find.byKey(key));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_menuRect(tester).top, closeTo(anchor.bottom + 8, 0.01));
    });

    testWidgets('only dividers: nothing opens', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAvoMenu(
                context,
                items: const [AvoMenuDivider(), AvoMenuDivider()],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('dividers: leading, trailing and repeated ones are dropped', (
      tester,
    ) async {
      await _pump(
        tester,
        _screen([
          const AvoMenuDivider(),
          AvoMenuItem(label: _rename, onSelected: () {}),
          const AvoMenuDivider(),
          const AvoMenuDivider(),
          AvoMenuItem(label: _delete, destructive: true, onSelected: () {}),
          const AvoMenuDivider(),
        ]),
      );
      await _open(tester);
      final hairlines = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AvoColors.light.separator,
      );
      expect(hairlines, findsOneWidget);
      expect(
        tester.getRect(hairlines).center.dy,
        allOf(
          greaterThan(tester.getRect(find.text(_rename)).bottom),
          lessThan(tester.getRect(find.text(_delete)).top),
        ),
      );
    });

    testWidgets('grows from 0.6 at the trigger on the menu spring', (
      tester,
    ) async {
      await _pump(tester, _screen(_items()));
      await tester.tap(find.byType(AvoMenuButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      Transform transform() => tester.widget<Transform>(
        find
            .ancestor(of: find.text(_rename), matching: find.byType(Transform))
            .first,
      );
      final mid = transform().transform.storage[0];
      expect(mid, greaterThan(0.6));
      expect(mid, lessThan(1));
      // Origin at the trigger: its centre, on the menu's top edge.
      final origin = transform().alignment! as Alignment;
      expect(origin.y, -1);
      expect(origin.x, closeTo((352 - 124) / 250 * 2 - 1, 0.01));
      await tester.pumpAndSettle();
      expect(transform().transform.storage[0], 1);
    });

    testWidgets('Reduce Motion: fades without scaling', (tester) async {
      await _pump(
        tester,
        _screen(_items()),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      await tester.tap(find.byType(AvoMenuButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.ancestor(of: find.text(_rename), matching: find.byType(Transform)),
        findsNothing,
      );
      final fade = tester.widget<Opacity>(
        find
            .ancestor(of: find.text(_rename), matching: find.byType(Opacity))
            .last,
      );
      expect(fade.opacity, greaterThan(0));
      expect(fade.opacity, lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('the background dims only slightly', (tester) async {
      await _pump(tester, _screen(_items()));
      await _open(tester);
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, AvoColors.light.shadow.withValues(alpha: 0.08));
    });

    testWidgets('opaque raised surface off iOS', (tester) async {
      await _pump(tester, _screen(_items()));
      await _open(tester);
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(_rename),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      final decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, AvoColors.light.surfaceRaised);
      expect(
        (decoration.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AvoRadii.card),
      );
    });

    testWidgets('native glass on iOS', (tester) async {
      await _pump(tester, _screen(_items()));
      await _open(tester);
      expect(
        find.ancestor(
          of: find.text(_rename),
          matching: find.byType(GlassSurface),
        ),
        findsOneWidget,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('dark mode uses the raised dark surface', (tester) async {
      await _pump(
        tester,
        _screen(_items()),
        layout: const LayoutCase(
          width: 390,
          scale: 1,
          brightness: Brightness.dark,
        ),
      );
      await _open(tester);
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(_rename),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect(
        (box.decoration as ShapeDecoration).color,
        AvoColors.dark.surfaceRaised,
      );
      expect(
        tester.widget<Text>(find.text(_delete)).style!.color,
        AvoColors.dark.destructive,
      );
    });

    testWidgets('VoiceOver: a menu of items; escape closes; no barrier node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _screen(_items(withCheck: true)));
      await _open(tester);
      final row = tester.getSemantics(find.bySemanticsLabel(_rename));
      expect(
        row,
        isSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      expect(row.getSemanticsData().role, SemanticsRole.menuItem);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('$_hideDone, Für alle 4 Mitglieder'),
        ),
        isSemantics(isSelected: true, hasSelectedState: true),
      );
      // The underlying screen is hidden, the barrier is not an element.
      expect(find.semantics.byLabel('More'), findsNothing);
      expect(find.semantics.byLabel('Close'), findsNothing);

      final menu = _ancestorWith(row, SemanticsAction.dismiss);
      expect(menu.getSemanticsData().role, SemanticsRole.menu);
      expect(menu.getSemanticsData().flagsCollection.scopesRoute, isTrue);
      menu.owner!.performAction(menu.id, SemanticsAction.dismiss);
      await tester.pumpAndSettle();
      expect(find.text(_rename), findsNothing);
      handle.dispose();
    });

    testWidgets('keyboard: first row focused, Escape closes', (tester) async {
      await _pump(tester, _screen(_items()));
      await _open(tester);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);
      expect(
        tester.getRect(find.text(_rename)).overlaps(focused!.rect),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(_rename), findsNothing);
    });

    testWidgets('keyboard: Enter chooses the focused row', (tester) async {
      final log = <String>[];
      await _pump(tester, _screen(_items(log: log)));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['rename']);
      expect(find.text(_rename), findsNothing);
    });
  });

  group('AvoMenuButton', () {
    testWidgets('a 44 pt glass "More" button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _screen(_items()));
      final button = find.bySemanticsLabel('More');
      expect(button, findsOneWidget);
      expect(tester.getSize(find.byType(AvoMenuButton)), const Size(44, 44));
      expect(
        find.descendant(
          of: find.byType(AvoMenuButton),
          matching: find.byType(GlassIconButton),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('disabled without rows or when enabled is false', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _screen(const [AvoMenuDivider()]));
      expect(
        tester.getSemantics(find.bySemanticsLabel('More')),
        isSemantics(isEnabled: false, hasEnabledState: true, isButton: true),
      );
      await _pump(
        tester,
        SizedBox.expand(
          child: Align(
            alignment: Alignment.topRight,
            child: AvoMenuButton(items: _items(), enabled: false),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('More')),
        isSemantics(isEnabled: false, hasEnabledState: true, isButton: true),
      );
      handle.dispose();
    });

    testWidgets('custom label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AvoMenuButton(items: _items(), semanticLabel: 'Listen-Optionen'),
      );
      expect(find.bySemanticsLabel('Listen-Optionen'), findsOneWidget);
      handle.dispose();
    });
  });

  layoutMatrix(
    'AvoMenu open with long rows',
    (context) => _screen(_items(withCheck: true)),
    afterPump: _open,
    checkTapTargets: true,
  );

  layoutMatrix(
    'AvoMenu open from the bottom with many rows',
    (context) => _screen([
      for (var i = 0; i < 14; i++)
        AvoMenuItem(
          label: 'Bio-Vollmilch 3,8 % Fett aus der Region, laktosefrei $i',
          icon: AvoIcons.cart,
          onSelected: () {},
        ),
    ], at: Alignment.bottomRight),
    afterPump: _open,
    checkTapTargets: true,
  );
}
