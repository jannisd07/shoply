import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/reorderable_section.dart';

import '../../../layout/layout_matrix.dart';

const _names = ['Lidl', 'Rewe', 'Edeka'];

Key _key(String name) => ValueKey<String>(name);

Widget _row(BuildContext context, String name) => ConstrainedBox(
  key: _key(name),
  constraints: const BoxConstraints(minHeight: 60),
  child: Align(
    alignment: AlignmentDirectional.centerStart,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
      child: Text(name, style: context.text(AvoTextStyle.body)),
    ),
  ),
);

/// A section that applies the reorder, like a screen does.
class _Host extends StatefulWidget {
  const _Host({this.log, this.header});

  final List<(int, int)>? log;
  final String? header;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final names = [..._names];

  @override
  Widget build(BuildContext context) => ReorderableInsetSection(
    header: widget.header,
    labels: names,
    children: [for (final n in names) _row(context, n)],
    onReorder: (from, to) => setState(() {
      widget.log?.add((from, to));
      names.insert(to, names.removeAt(from));
    }),
  );
}

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
    layoutHarness(layout, Align(alignment: Alignment.topCenter, child: child)),
  );
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

Finder _handle(int index) => find.byType(AvoIcon).at(index);

double _top(WidgetTester tester, String name) =>
    tester.getTopLeft(find.byKey(_key(name))).dy;

List<String> _order(WidgetTester tester) {
  final names = [..._names]
    ..sort((a, b) => _top(tester, a).compareTo(_top(tester, b)));
  return names;
}

/// Holds the handle of [index] until the long press fires.
Future<TestGesture> _lift(WidgetTester tester, int index) async {
  final gesture = await tester.startGesture(tester.getCenter(_handle(index)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  return gesture;
}

void main() {
  group('look', () {
    testWidgets('InsetSection group: heading, radius 26, 44 pt handles', (
      tester,
    ) async {
      await _pump(tester, const _Host(header: 'Märkte'));
      expect(find.text('MÄRKTE'), findsOneWidget);
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(ReorderableInsetSection),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(AvoRadii.group));
      expect(find.byType(AvoIcon), findsNWidgets(3));
      final icon = tester.widget<AvoIcon>(_handle(0));
      expect(icon.icon, same(AvoIcons.line3Horizontal));
      expect(icon.size, 18);
      final rect = tester.getRect(
        find.ancestor(
          of: _handle(0),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 44 && w.height == 44,
          ),
        ),
      );
      expect(rect.size, const Size(44, 44));
      // Rows have 0.5 pt hairlines between them, none after the last.
      expect(_top(tester, 'Rewe') - _top(tester, 'Lidl'), 60.5);
      expect(_top(tester, 'Edeka') - _top(tester, 'Rewe'), 60.5);
    });

    testWidgets('no children renders nothing', (tester) async {
      await _pump(
        tester,
        ReorderableInsetSection(
          labels: const [],
          onReorder: (_, _) {},
          children: const [],
        ),
      );
      expect(tester.getSize(find.byType(ReorderableInsetSection)).height, 0);
    });
  });

  group('dragging', () {
    testWidgets('hold the handle, move down one row: reorders (0 to 1)', (
      tester,
    ) async {
      final log = <(int, int)>[];
      final haptics = _haptics(tester);
      await _pump(tester, _Host(log: log));
      final gesture = await _lift(tester, 0);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pumpAndSettle();
      expect(log, isEmpty, reason: 'nothing happens before the drop');
      // Lidl follows the finger; Rewe moved up into its slot.
      expect(_top(tester, 'Lidl'), closeTo(70, 1));
      expect(_top(tester, 'Rewe'), closeTo(0, 1));
      expect(haptics, hasLength(2), reason: 'lift, then the new slot');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log, [(0, 1)]);
      expect(_order(tester), ['Rewe', 'Lidl', 'Edeka']);
      expect(_top(tester, 'Rewe'), 0);
      expect(_top(tester, 'Lidl'), 60.5);
    });

    testWidgets('the last row up two slots: 2 to 0', (tester) async {
      final log = <(int, int)>[];
      await _pump(tester, _Host(log: log));
      final gesture = await _lift(tester, 2);
      await gesture.moveBy(const Offset(0, -80));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log, [(2, 0)]);
      expect(_order(tester), ['Edeka', 'Lidl', 'Rewe']);
    });

    testWidgets('dropping where it started does not reorder', (tester) async {
      final log = <(int, int)>[];
      await _pump(tester, _Host(log: log));
      final gesture = await _lift(tester, 1);
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(_order(tester), _names);
    });

    testWidgets('the lifted row grows a little and casts a shadow', (
      tester,
    ) async {
      await _pump(tester, const _Host());
      final before = tester.getRect(find.byKey(_key('Lidl'))).width;
      final gesture = await _lift(tester, 0);
      await tester.pumpAndSettle();
      final lifted = tester.getRect(find.byKey(_key('Lidl'))).width;
      expect(lifted, closeTo(before * 1.02, 0.1));
      expect(
        find.descendant(
          of: find.byType(ReorderableInsetSection),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
          ),
        ),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(_key('Lidl'))).width,
        closeTo(before, 0.01),
      );
    });

    testWidgets('the dragged row stays inside the group', (tester) async {
      await _pump(tester, const _Host());
      final gesture = await _lift(tester, 0);
      await gesture.moveBy(const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(_top(tester, 'Lidl'), lessThanOrEqualTo(121 + 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_order(tester), ['Rewe', 'Edeka', 'Lidl']);
    });

    testWidgets('a quick tap or a plain swipe on the handle does nothing', (
      tester,
    ) async {
      final log = <(int, int)>[];
      await _pump(tester, _Host(log: log));
      await tester.tap(_handle(0));
      await tester.drag(_handle(0), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('Reduce Motion: rows jump, no springs needed', (tester) async {
      final log = <(int, int)>[];
      await _pump(
        tester,
        _Host(log: log),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      final gesture = await _lift(tester, 0);
      await gesture.moveBy(const Offset(0, 70));
      await tester.pump();
      expect(_top(tester, 'Rewe'), closeTo(0, 0.01));
      expect(
        tester.getRect(find.byKey(_key('Lidl'))).size.width,
        closeTo(310, 0.01),
        reason: 'no growing under Reduce Motion',
      );
      await gesture.up();
      await tester.pump();
      expect(log, [(0, 1)]);
    });
  });

  group('VoiceOver', () {
    testWidgets('the handle: label, position and move actions', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const _Host());
      final first = tester.getSemantics(find.bySemanticsLabel('Reorder Lidl'));
      expect(first.value, 'Position 1 of 3');
      expect(
        first,
        isSemantics(
          customActions: const [CustomSemanticsAction(label: 'Move down')],
        ),
      );
      final middle = tester.getSemantics(find.bySemanticsLabel('Reorder Rewe'));
      expect(
        middle,
        isSemantics(
          customActions: const [
            CustomSemanticsAction(label: 'Move up'),
            CustomSemanticsAction(label: 'Move down'),
          ],
        ),
      );
      final last = tester.getSemantics(find.bySemanticsLabel('Reorder Edeka'));
      expect(
        last,
        isSemantics(
          customActions: const [CustomSemanticsAction(label: 'Move up')],
        ),
      );
      handle.dispose();
    });

    testWidgets('Move down reorders and announces the new position', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <(int, int)>[];
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<dynamic, dynamic>;
            if (map['type'] == 'announce') {
              announced.add((map['data'] as Map)['message'] as String);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await _pump(tester, _Host(log: log));
      tester.semantics.performAction(
        find.semantics.byLabel('Reorder Lidl'),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move down'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(log, [(0, 1)]);
      expect(_order(tester), ['Rewe', 'Lidl', 'Edeka']);
      expect(announced, ['Lidl, position 2 of 3']);
      handle.dispose();
    });
  });

  layoutMatrix(
    'ReorderableInsetSection: long names, heading',
    (context) => ReorderableInsetSection(
      header: 'Deine Märkte',
      footer: 'Halte den Griff und zieh eine Zeile an ihren Platz.',
      labels: const ['A', 'B', 'C'],
      onReorder: (_, _) {},
      children: [
        for (final n in const [
          'Lidl Berlin-Mitte, Alexanderplatz',
          'Rewe City, Friedrichstraße 100',
          'Edeka',
        ])
          _row(context, n),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
