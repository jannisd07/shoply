import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';

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
      Center(
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.screen),
          child: child,
        ),
      ),
    ),
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

const _sort = [
  SegmentItem(value: 'category', label: 'Kategorie'),
  SegmentItem(value: 'store', label: 'Laden'),
];

const _filter = [
  SegmentItem(value: 'all', label: 'Alle'),
  SegmentItem(value: 'open', label: 'Offen'),
  SegmentItem(value: 'done', label: 'Erledigt'),
];

Widget _stateful({
  List<SegmentItem<String>> segments = _sort,
  String? initial,
  bool compact = false,
  List<String>? log,
}) {
  var selected = initial ?? segments.first.value;
  return StatefulBuilder(
    builder: (context, setState) => AppSegmentedControl<String>(
      segments: segments,
      selected: selected,
      compact: compact,
      semanticLabel: 'Sortieren nach',
      onChanged: (v) {
        log?.add(v);
        setState(() => selected = v);
      },
    ),
  );
}

Finder get _control => find.byType(AppSegmentedControl<String>);

/// The thumb's left edge (the only Positioned with a width).
double _thumbLeft(WidgetTester tester) => tester
    .widgetList<Positioned>(
      find.descendant(of: _control, matching: find.byType(Positioned)),
    )
    .firstWhere((p) => p.width != null)
    .left!;

double _segmentWidth(WidgetTester tester) => tester
    .widgetList<Positioned>(
      find.descendant(of: _control, matching: find.byType(Positioned)),
    )
    .firstWhere((p) => p.width != null)
    .width!;

void main() {
  testWidgets('VoiceOver: buttons with a selected state in one group', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _stateful());
    expect(
      tester.getSemantics(find.bySemanticsLabel('Kategorie')),
      isSemantics(
        isButton: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Laden')),
      isSemantics(
        isButton: true,
        isSelected: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(find.bySemanticsLabel('Sortieren nach'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tap selects; the thumb springs over without a haptic', (
    tester,
  ) async {
    final haptics = _haptics(tester);
    final log = <String>[];
    await _pump(tester, _stateful(log: log));
    final start = _thumbLeft(tester);
    final width = _segmentWidth(tester);
    await tester.tap(find.text('Laden'));
    await tester.pump();
    expect(log, ['store']);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 32));
    final mid = _thumbLeft(tester);
    expect(mid, greaterThan(start));
    expect(mid, lessThan(start + width));
    await tester.pumpAndSettle();
    expect(_thumbLeft(tester), closeTo(start + width, 0.01));
    expect(haptics, isEmpty);

    await tester.tap(find.text('Laden'));
    await tester.pumpAndSettle();
    expect(log, ['store'], reason: 'tapping the selected segment is a no-op');
  });

  testWidgets('labels: selected semibold, others medium', (tester) async {
    await _pump(tester, _stateful());
    expect(
      tester.widget<Text>(find.text('Kategorie')).style!.fontWeight,
      FontWeight.w600,
    );
    expect(
      tester.widget<Text>(find.text('Laden')).style!.fontWeight,
      FontWeight.w500,
    );
  });

  testWidgets('dragging the thumb follows the finger and snaps with haptics', (
    tester,
  ) async {
    final haptics = _haptics(tester);
    final log = <String>[];
    await _pump(tester, _stateful(segments: _filter, log: log));
    final start = _thumbLeft(tester);
    final width = _segmentWidth(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Alle')),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    final afterSlop = _thumbLeft(tester);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(_thumbLeft(tester) - afterSlop, closeTo(30, 0.5), reason: '1:1');
    expect(haptics, isEmpty);

    // Across the next two segments, one snap each.
    await gesture.moveBy(Offset(width - 50, 0));
    await tester.pump();
    expect(haptics, hasLength(1));
    await gesture.moveBy(Offset(width, 0));
    await tester.pump();
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(log, isEmpty, reason: 'chosen on release');
    expect(
      tester.widget<Text>(find.text('Erledigt')).style!.fontWeight,
      FontWeight.w600,
      reason: 'the label under the thumb is highlighted while dragging',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(log, ['done']);
    expect(_thumbLeft(tester), closeTo(start + 2 * width, 0.01));
  });

  testWidgets('a drag that starts off the thumb selects where it ends', (
    tester,
  ) async {
    final haptics = _haptics(tester);
    final log = <String>[];
    await _pump(tester, _stateful(segments: _filter, log: log));
    final start = _thumbLeft(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Offen')),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(_thumbLeft(tester), start, reason: 'the thumb stays put');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(log, ['open']);
    expect(haptics, isEmpty);
  });

  testWidgets('pressed: the thumb scales while the finger is on it', (
    tester,
  ) async {
    await _pump(tester, _stateful());
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Kategorie')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    final scaled = tester.widgetList<Transform>(
      find.descendant(of: _control, matching: find.byType(Transform)),
    );
    expect(scaled, isNotEmpty);
    expect(
      scaled.first.transform.storage[0],
      closeTo(AvoMotion.pressedScale, 0.005),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion: the thumb jumps', (tester) async {
    await _pump(
      tester,
      _stateful(),
      layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
    );
    final start = _thumbLeft(tester);
    final width = _segmentWidth(tester);
    await tester.tap(find.text('Laden'));
    await tester.pump();
    await tester.pump();
    expect(_thumbLeft(tester), closeTo(start + width, 0.01));
  });

  testWidgets('segments are at least 44 x 44 pt', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final compact in [false, true]) {
      await _pump(tester, _stateful(segments: _filter, compact: compact));
      for (final label in ['Alle', 'Offen', 'Erledigt']) {
        final size = tester.getSemantics(find.bySemanticsLabel(label)).rect;
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }
    semantics.dispose();
  });

  testWidgets('track: 44 pt regular, 34 pt visible when compact', (
    tester,
  ) async {
    Size track() => tester.getSize(
      find.descendant(of: _control, matching: find.byType(DecoratedBox)).first,
    );
    await _pump(tester, _stateful());
    expect(track().height, 44);
    await _pump(tester, Row(children: [_stateful(compact: true)]));
    expect(track().height, 34);
    expect(tester.getSize(_control).height, 44);
    expect(
      _segmentWidth(tester),
      greaterThanOrEqualTo(52),
      reason: 'unbounded compact segments are at least 52 wide (D2)',
    );
  });

  group('fallback when labels do not fit', () {
    const long = [
      SegmentItem(value: 'category', label: 'Kategorie'),
      SegmentItem(value: 'store', label: 'Reihenfolge im Markt'),
      SegmentItem(value: 'added', label: 'Zuletzt hinzugefügt'),
    ];

    testWidgets('narrow: a pull-down button opens a centred dialog', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final log = <String>[];
      await _pump(
        tester,
        SizedBox(
          width: 240,
          child: _stateful(segments: long, log: log),
        ),
      );
      expect(
        find.byIcon(CupertinoIcons.chevron_up_chevron_down),
        findsOneWidget,
      );
      expect(find.text('Reihenfolge im Markt'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sortieren nach')),
        isSemantics(isButton: true, value: 'Kategorie', hasTapAction: true),
      );

      await tester.tap(find.text('Kategorie'));
      await tester.pumpAndSettle();
      expect(find.text('Reihenfolge im Markt'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Kategorie').last),
        isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
      );
      final dialog = tester.getRect(find.text('Zuletzt hinzugefügt'));
      expect(dialog.center.dx, closeTo(390 / 2, 60), reason: 'centred');
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.tap(find.text('Zuletzt hinzugefügt'));
      await tester.pumpAndSettle();
      expect(log, ['added']);
      expect(find.text('Zuletzt hinzugefügt'), findsOneWidget);

      await tester.tap(find.text('Zuletzt hinzugefügt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(log, ['added'], reason: 'cancel changes nothing');
      expect(find.text('Cancel'), findsNothing);
      semantics.dispose();
    });

    testWidgets('large text: two short labels also fall back', (tester) async {
      await _pump(
        tester,
        _stateful(),
        layout: const LayoutCase(width: 390, scale: 3.1),
      );
      expect(
        find.byIcon(CupertinoIcons.chevron_up_chevron_down),
        findsOneWidget,
      );
      expect(find.text('Laden'), findsNothing);
    });
  });

  layoutMatrix(
    'AppSegmentedControl',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSegmentedControl<String>(
            segments: _sort,
            selected: 'category',
            semanticLabel: 'Sortieren nach',
            onChanged: (_) {},
          ),
          const SizedBox(height: AvoSpacing.m),
          AppSegmentedControl<String>(
            segments: const [
              SegmentItem(value: 'all', label: 'Alle'),
              SegmentItem(value: 'open', label: 'Offen'),
              SegmentItem(value: 'mine', label: 'Laktosefrei'),
              SegmentItem(value: 'done', label: 'Erledigt'),
            ],
            selected: 'open',
            semanticLabel: 'Filter',
            onChanged: (_) {},
          ),
          const SizedBox(height: AvoSpacing.m),
          Row(
            children: [
              AppSegmentedControl<String>(
                segments: const [
                  SegmentItem(value: 'pc', label: 'St.'),
                  SegmentItem(value: 'g', label: 'g'),
                  SegmentItem(value: 'kg', label: 'kg'),
                ],
                selected: 'pc',
                compact: true,
                semanticLabel: 'Einheit',
                onChanged: (_) {},
              ),
            ],
          ),
        ],
      ),
    ),
    checkTapTargets: true,
  );
}
