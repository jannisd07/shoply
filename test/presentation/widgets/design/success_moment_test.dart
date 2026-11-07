import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/success_moment.dart';

import '../../../layout/layout_matrix.dart';

/// Calls [open] once after the first frame.
class _AutoOpen extends StatefulWidget {
  const _AutoOpen(this.open);

  final void Function(BuildContext context) open;

  @override
  State<_AutoOpen> createState() => _AutoOpenState();
}

class _AutoOpenState extends State<_AutoOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Records platform calls (haptics end up there).
List<MethodCall> _recordPlatform(WidgetTester tester) {
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
  return calls;
}

class _Run {
  bool done = false;
}

Future<_Run> _open(
  WidgetTester tester, {
  String title = 'Einkauf gespeichert.',
  String? subtitle = '3,20 € gespart',
  AvoPose pose = AvoPose.celebrating,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  final run = _Run();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      layout,
      _AutoOpen((context) {
        showSuccessMoment(
          context,
          title: title,
          subtitle: subtitle,
          pose: pose,
        ).then((_) => run.done = true);
      }),
    ),
  );
  await tester.pump();
  return run;
}

double _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

void main() {
  testWidgets('shows figure, title and subtitle centred', (tester) async {
    _recordPlatform(tester);
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Einkauf gespeichert.'), findsOneWidget);
    expect(find.text('3,20 € gespart'), findsOneWidget);
    final figure = tester.widget<AvoFigure>(find.byType(AvoFigure));
    expect(figure.pose, AvoPose.celebrating);
    final title = tester.getCenter(find.text('Einkauf gespeichert.'));
    expect(title.dx, closeTo(390 / 2, 1));
    expect(
      tester.widget<Text>(find.text('Einkauf gespeichert.')).style?.fontSize,
      20,
    );
  });

  testWidgets('pops in from 0.9 with the success haptic in the same frame', (
    tester,
  ) async {
    final calls = _recordPlatform(tester);
    await _open(tester);
    expect(_scale(tester), closeTo(0.9, 0.001));
    expect(
      calls.where((c) => c.method == 'HapticFeedback.vibrate'),
      isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(_scale(tester), closeTo(1, 0.02));
  });

  testWidgets('announces the title for VoiceOver', (tester) async {
    _recordPlatform(tester);
    await _open(tester);
    expect(tester.takeAnnouncements().map((a) => a.message), [
      'Einkauf gespeichert., 3,20 € gespart',
    ]);
  });

  testWidgets('gone after 1.5 s; the future completes', (tester) async {
    _recordPlatform(tester);
    final run = await _open(tester, subtitle: null);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('Einkauf gespeichert.'), findsOneWidget);
    expect(run.done, isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Einkauf gespeichert.'), findsNothing);
    expect(run.done, isTrue);
  });

  testWidgets('a tap closes it early', (tester) async {
    _recordPlatform(tester);
    final run = await _open(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(find.text('Einkauf gespeichert.'), findsNothing);
    expect(run.done, isTrue);
  });

  testWidgets('Reduce Motion: no scaling, only a fade in', (tester) async {
    _recordPlatform(tester);
    await _open(
      tester,
      layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
    );
    expect(_scale(tester), 1);
    await tester.pump(const Duration(milliseconds: 100));
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(Overlay),
            matching: find.byType(FadeTransition),
          )
          .last,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(_scale(tester), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('VoiceOver: one element that closes on double tap', (
    tester,
  ) async {
    _recordPlatform(tester);
    final handle = tester.ensureSemantics();
    final run = await _open(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final label = find.semantics.byLabel(
      'Einkauf gespeichert., 3,20 € gespart',
    );
    expect(label, findsOne);
    tester.semantics.tap(label);
    await tester.pumpAndSettle();
    expect(run.done, isTrue);
    handle.dispose();
  });

  testWidgets('smaller figure from AX1', (tester) async {
    _recordPlatform(tester);
    await _open(tester, layout: const LayoutCase(width: 390, scale: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      tester.widget<AvoFigure>(find.byType(AvoFigure)).size,
      lessThan(120),
    );
  });

  testWidgets('other poses are passed through', (tester) async {
    _recordPlatform(tester);
    await _open(tester, title: 'Avo Pro ist aktiv.', pose: AvoPose.excited);
    expect(
      tester.widget<AvoFigure>(find.byType(AvoFigure)).pose,
      AvoPose.excited,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  layoutMatrix(
    'showSuccessMoment',
    (context) => _AutoOpen(
      (context) => showSuccessMoment(
        context,
        title: 'Einkauf „Laktosefreie Bio-Vollmilch“ gespeichert.',
        subtitle: 'Du hast diese Woche 6,40 € gespart.',
      ),
    ),
    checkTapTargets: true,
    afterPump: (tester) async {
      expect(find.byType(AvoFigure), findsOneWidget);
    },
  );
}
