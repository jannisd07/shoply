import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/module_off_alert.dart';

import '../../../layout/layout_matrix.dart';

/// Calls [open] once after the first frame (to open a dialog in a test).
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

class _Run {
  final results = <bool>[];
  var enabled = 0;
}

Future<_Run> _open(
  WidgetTester tester, {
  String module = 'Calories',
  String? body,
}) async {
  final run = _Run();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      const LayoutCase(width: 390, scale: 1),
      _AutoOpen((context) async {
        run.results.add(
          await showModuleOffAlert(
            context,
            moduleName: module,
            body: body,
            onEnable: () async => run.enabled++,
          ),
        );
      }),
    ),
  );
  await tester.pumpAndSettle();
  return run;
}

void main() {
  testWidgets('names the module and explains', (tester) async {
    await _open(tester, module: 'Weekly plan');
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Weekly plan is turned off'), findsOneWidget);
    expect(
      find.text(
        'Turn it on to open this. You can switch it off again in your '
        'profile at any time.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('body replaces the standard sentence', (tester) async {
    await _open(tester, body: 'Shows what your shopping costs.');
    expect(find.text('Shows what your shopping costs.'), findsOneWidget);
    expect(find.textContaining('You can switch it off again'), findsNothing);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('an empty body falls back to the standard sentence', (
    tester,
  ) async {
    await _open(tester, body: '  ');
    expect(find.textContaining('You can switch it off again'), findsOneWidget);
  });

  testWidgets('"Turn on" enables the module and resolves to true', (
    tester,
  ) async {
    final run = await _open(tester);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(run.enabled, 1);
    expect(run.results, [true]);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('"Not now" resolves to false without enabling', (tester) async {
    final run = await _open(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(run.enabled, 0);
    expect(run.results, [false]);
  });

  testWidgets('"Turn on" is the bold default, on the right, in tint', (
    tester,
  ) async {
    await _open(tester);
    final turnOn = tester.widget<CupertinoDialogAction>(
      find.ancestor(
        of: find.text('Turn on'),
        matching: find.byType(CupertinoDialogAction),
      ),
    );
    expect(turnOn.isDefaultAction, isTrue);
    expect(turnOn.isDestructiveAction, isFalse);
    expect(
      tester.getCenter(find.text('Turn on')).dx,
      greaterThan(tester.getCenter(find.text('Not now')).dx),
    );
    expect(
      CupertinoTheme.of(tester.element(find.text('Turn on'))).primaryColor,
      AvoColors.light.tint,
    );
  });

  testWidgets('a tap outside does not dismiss', (tester) async {
    final run = await _open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(run.results, isEmpty);
  });

  testWidgets('VoiceOver: both buttons labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(
      tester.getSemantics(find.text('Turn on')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.text('Not now')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  layoutMatrix(
    'showModuleOffAlert with its own body',
    (context) => _AutoOpen(
      (context) => showModuleOffAlert(
        context,
        moduleName: 'Laktosefreie Bio-Vollmilch-Kalorien',
        body:
            'Zeigt dir, was dein Wocheneinkauf in den Märkten in deiner '
            'Nähe kostet, und wo du sparst.',
        onEnable: () async {},
      ),
    ),
    checkTapTargets: true,
    afterPump: (tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    },
  );

  layoutMatrix(
    'showModuleOffAlert',
    (context) => _AutoOpen(
      (context) => showModuleOffAlert(
        context,
        moduleName: 'Laktosefreie Bio-Vollmilch-Kalorien',
        onEnable: () async {},
      ),
    ),
    checkTapTargets: true,
    afterPump: (tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    },
  );
}
