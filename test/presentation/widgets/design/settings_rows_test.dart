import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

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
        child: SizedBox(width: layout.width, child: child),
      ),
    ),
  );
}

/// The D2 icon tile (30 pt, radius 8).
class _Tile extends StatelessWidget {
  const _Tile();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.tintFill,
      borderRadius: BorderRadius.circular(AvoSpacing.s),
    ),
    child: const SizedBox.square(dimension: 30),
  );
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

/// The highlight fill of the row under [row] (null alpha = none).
double _highlightAlpha(WidgetTester tester, Finder row) {
  final boxes = tester.widgetList<ColoredBox>(
    find.descendant(of: row, matching: find.byType(ColoredBox)),
  );
  return boxes.isEmpty ? 0 : boxes.first.color.a;
}

void main() {
  group('NavRow', () {
    testWidgets('valueLeading sits before the value, not in the label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        NavRow(
          title: 'Mitteilungen',
          value: 'In iOS aus',
          valueLeading: const AvoIcon(
            AvoIcons.exclamationmarkTriangleFill,
            size: 15,
            key: Key('warn'),
          ),
          onTap: () {},
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('warn'))).dx,
        lessThan(tester.getTopLeft(find.text('In iOS aus')).dx),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Mitteilungen'));
      expect(node.value, 'In iOS aus');
      semantics.dispose();
    });

    testWidgets('tapping runs onTap; height at least 52', (tester) async {
      var taps = 0;
      await _pump(tester, NavRow(title: 'Mitteilungen', onTap: () => taps++));
      expect(tester.getSize(find.byType(NavRow)).height, 52);
      await tester.tap(find.byType(NavRow));
      expect(taps, 1);
    });

    testWidgets('highlights the moment it is touched, fades after', (
      tester,
    ) async {
      await _pump(tester, NavRow(title: 'Darstellung', onTap: () {}));
      final row = find.byType(NavRow);
      expect(_highlightAlpha(tester, row), 0);
      final gesture = await tester.startGesture(tester.getCenter(row));
      await tester.pump();
      expect(_highlightAlpha(tester, row), AvoColors.light.fillStrong.a);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_highlightAlpha(tester, row), closeTo(0, 0.01));
    });

    testWidgets('shows value, subtitle and chevron', (tester) async {
      // Short words: the test font is wider than SF Pro.
      await _pump(
        tester,
        NavRow(
          title: 'Markt',
          subtitle: 'Aktiv',
          value: 'Lidl',
          leading: const _Tile(),
          onTap: () {},
        ),
      );
      expect(find.text('Lidl'), findsOneWidget);
      expect(_textColor(tester, 'Lidl'), AvoColors.light.secondaryLabel);
      expect(_textColor(tester, 'Aktiv'), AvoColors.light.secondaryLabel);
      expect(_textColor(tester, 'Markt'), AvoColors.light.label);
      final chevron = find.descendant(
        of: find.byType(NavRow),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.size == const Size(8, 14),
        ),
      );
      expect(chevron, findsOneWidget);
      final value = tester.getRect(find.text('Lidl'));
      final title = tester.getRect(find.text('Markt'));
      expect(value.left, greaterThan(title.right));
      expect(tester.getRect(chevron).left, greaterThan(value.right));
    });

    testWidgets('a value that does not fit wraps below the title', (
      tester,
    ) async {
      await _pump(
        tester,
        NavRow(
          title: 'Preise und Angebote',
          value: 'Lidl, REWE, Kaufland, Edeka',
          onTap: () {},
        ),
      );
      final title = tester.getRect(find.text('Preise und Angebote'));
      final value = tester.getRect(find.text('Lidl, REWE, Kaufland, Edeka'));
      expect(value.top, greaterThanOrEqualTo(title.bottom));
    });

    testWidgets('one VoiceOver button with title, Pro and value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        NavRow(title: 'Wochenplan', value: 'Aus', pro: true, onTap: () {}),
      );
      expect(find.byType(ProBadge), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(NavRow)),
        isSemantics(
          label: 'Wochenplan, Pro feature',
          value: 'Aus',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled without onTap', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const NavRow(title: 'Apple Health'));
      expect(
        _textColor(tester, 'Apple Health'),
        AvoColors.light.secondaryLabel,
      );
      expect(
        tester.getSemantics(find.byType(NavRow)),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(NavRow)),
      );
      await tester.pump();
      expect(_highlightAlpha(tester, find.byType(NavRow)), 0);
      await gesture.up();
      handle.dispose();
    });

    testWidgets('destructive title colour', (tester) async {
      await _pump(
        tester,
        NavRow(title: 'Konto löschen', destructive: true, onTap: () {}),
      );
      expect(_textColor(tester, 'Konto löschen'), AvoColors.light.destructive);
    });

    testWidgets('from AX1 the value moves below the title', (tester) async {
      await _pump(
        tester,
        NavRow(title: 'Darstellung', value: 'Automatisch', onTap: () {}),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      final title = tester.getRect(find.text('Darstellung'));
      final value = tester.getRect(find.text('Automatisch'));
      expect(value.top, greaterThanOrEqualTo(title.bottom));
      expect(value.left, title.left);
    });
  });

  group('ToggleRow', () {
    testWidgets('the whole row toggles', (tester) async {
      final values = <bool>[];
      await _pump(
        tester,
        ToggleRow(title: 'Angebote', value: false, onChanged: values.add),
      );
      await tester.tap(find.text('Angebote'));
      await tester.tap(find.byType(CupertinoSwitch));
      expect(values, [true, true]);
    });

    testWidgets('switch shows the value with the accent track', (tester) async {
      await _pump(
        tester,
        ToggleRow(title: 'Wochenplan', value: true, onChanged: (_) {}),
      );
      final toggle = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(toggle.value, isTrue);
      expect(toggle.activeTrackColor, AvoColors.light.tintFill);
      expect(toggle.onChanged, isNotNull);
    });

    testWidgets('VoiceOver: one toggle element', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ToggleRow(
          title: 'Kalorien',
          subtitle: 'Mit Apple Health',
          value: true,
          onChanged: (_) {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(ToggleRow)),
        isSemantics(
          label: 'Kalorien, Mit Apple Health',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled: no toggling, dimmed', (tester) async {
      final values = <bool>[];
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ToggleRow(
          title: 'Kosten teilen',
          value: false,
          enabled: false,
          onChanged: values.add,
        ),
      );
      await tester.tap(find.byType(ToggleRow));
      expect(values, isEmpty);
      expect(
        _textColor(tester, 'Kosten teilen'),
        AvoColors.light.secondaryLabel,
      );
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
        isNull,
      );
      expect(
        tester.getSemantics(find.byType(ToggleRow)),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('no haptic on iOS (switches are not in the table)', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var value = false;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ToggleRow(
            title: 'Angebote',
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('from AX1 the switch moves below the title', (tester) async {
      await _pump(
        tester,
        ToggleRow(title: 'Angebote', value: true, onChanged: (_) {}),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      final title = tester.getRect(find.text('Angebote'));
      final toggle = tester.getRect(find.byType(CupertinoSwitch));
      expect(toggle.top, greaterThan(title.bottom));
    });
  });

  group('ValueRow', () {
    testWidgets('title and value, read as label and value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const ValueRow(title: 'Version', value: '4.2.0'));
      expect(_textColor(tester, '4.2.0'), AvoColors.light.secondaryLabel);
      expect(
        tester.getSemantics(find.byType(ValueRow)),
        isSemantics(label: 'Version', value: '4.2.0', isButton: false),
      );
      expect(tester.getSize(find.byType(ValueRow)).height, 52);
      handle.dispose();
    });

    testWidgets('optional subtitle under the title, read with the label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const ValueRow(
          title: 'Bezahlt von',
          subtitle: 'Lena hat bezahlt',
          value: 'Lena',
        ),
      );
      expect(
        _textColor(tester, 'Lena hat bezahlt'),
        AvoColors.light.secondaryLabel,
      );
      expect(
        tester.getRect(find.text('Lena hat bezahlt')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Bezahlt von')).bottom),
      );
      expect(
        tester.getSemantics(find.byType(ValueRow)),
        isSemantics(
          label: 'Bezahlt von, Lena hat bezahlt',
          value: 'Lena',
          isButton: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('MenuValueRow comes with the settings rows import', (
      tester,
    ) async {
      var chosen = '';
      await _pump(
        tester,
        MenuValueRow(
          title: 'Bezahlt von',
          value: 'Du',
          items: [
            AvoMenuItem(label: 'Du', checked: true, onSelected: () {}),
            AvoMenuItem(label: 'Lena', onSelected: () => chosen = 'Lena'),
          ],
        ),
      );
      expect(find.byType(AvoIcon), findsOneWidget);
      await tester.tap(find.text('Bezahlt von'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lena').last);
      await tester.pumpAndSettle();
      expect(chosen, 'Lena');
    });

    testWidgets('from AX1 the value moves below', (tester) async {
      await _pump(
        tester,
        const ValueRow(title: 'Gespart', value: '18,60 €'),
        layout: const LayoutCase(width: 390, scale: 3.1),
      );
      expect(
        tester.getRect(find.text('18,60 €')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Gespart')).bottom),
      );
    });
  });

  group('DestructiveRow', () {
    testWidgets('centred, destructive colour, runs onTap', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DestructiveRow(title: 'Abmelden', onTap: () => taps++),
      );
      expect(_textColor(tester, 'Abmelden'), AvoColors.light.destructive);
      expect(tester.getCenter(find.text('Abmelden')).dx, closeTo(390 / 2, 0.5));
      await tester.tap(find.byType(DestructiveRow));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(DestructiveRow)),
        isSemantics(label: 'Abmelden', isButton: true, hasTapAction: true),
      );
      expect(tester.getSize(find.byType(DestructiveRow)).height, 52);
      handle.dispose();
    });

    testWidgets('without onTap: dimmed, disabled, subtitle read', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const DestructiveRow(
          title: 'Gespräch löschen',
          subtitle: 'Noch kein Gespräch',
          onTap: null,
        ),
      );
      expect(
        _textColor(tester, 'Gespräch löschen'),
        AvoColors.light.secondaryLabel,
      );
      expect(find.text('Noch kein Gespräch'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(DestructiveRow)),
        isSemantics(
          label: 'Gespräch löschen, Noch kein Gespräch',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });
  });

  layoutMatrix(
    'NavRow',
    (context) => InsetSection(
      header: 'Einstellungen',
      separatorIndent: 58,
      children: [
        NavRow(
          title: 'Preise & Angebote',
          value: 'Lidl, REWE, Kaufland',
          leading: const _Tile(),
          onTap: () {},
        ),
        NavRow(
          title: 'Wochenplan mit Laktosefreie Bio-Vollmilch',
          subtitle: '14 Tage gratis testen, danach 29,99 € im Jahr',
          leading: const _Tile(),
          pro: true,
          onTap: () {},
        ),
        NavRow(
          title: 'Mitteilungen von Laktosefreie Bio-Vollmilch',
          value: 'In iOS aus',
          valueLeading: const AvoIcon(
            AvoIcons.exclamationmarkTriangleFill,
            size: 15,
          ),
          onTap: () {},
        ),
        NavRow(title: 'Konto löschen', destructive: true, onTap: () {}),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'ToggleRow',
    (context) => InsetSection(
      header: 'Module',
      separatorIndent: 58,
      children: [
        ToggleRow(
          title: 'Angebote',
          value: true,
          leading: const _Tile(),
          onChanged: (_) {},
        ),
        ToggleRow(
          title: 'Laktosefreie Bio-Vollmilch automatisch nachkaufen',
          subtitle: 'Wenn weniger als 1,5 l im Kühlschrank sind',
          value: false,
          leading: const _Tile(),
          onChanged: (_) {},
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'ValueRow',
    (context) => const InsetSection(
      children: [
        ValueRow(title: 'Gespart diese Woche', value: '18,60 €'),
        ValueRow(
          title: 'Lieblingsmarkt',
          value: 'Laktosefreie-Bio-Vollmilch-Großhandel',
        ),
        ValueRow(
          title: 'Bezahlt von',
          subtitle: 'Lena hat am Samstag bei Rewe Center Hamburg bezahlt',
          value: 'Lena',
        ),
      ],
    ),
    scrollable: true,
  );

  layoutMatrix(
    'DestructiveRow',
    (context) => InsetSection(
      children: [
        DestructiveRow(
          title: 'Liste „Laktosefreie Bio-Vollmilch“ löschen',
          onTap: () {},
        ),
        const DestructiveRow(
          title: 'Gespräch löschen',
          subtitle: 'Noch kein Gespräch',
          onTap: null,
        ),
      ],
    ),
    checkTapTargets: true,
  );
}
