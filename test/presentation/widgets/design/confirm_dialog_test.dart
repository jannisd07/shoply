import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';

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

/// Opens the confirmation and stores its result.
Future<List<bool>> _open(
  WidgetTester tester, {
  String title = '„Party“ löschen?',
  String? message = 'Die Liste und 14 Artikel werden für alle gelöscht.',
  String confirmLabel = 'Löschen',
  String? cancelLabel,
  bool destructive = true,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  final results = <bool>[];
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      layout,
      _AutoOpen((context) async {
        results.add(
          await showAvoConfirm(
            context,
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            destructive: destructive,
          ),
        );
      }),
    ),
  );
  await tester.pumpAndSettle();
  return results;
}

CupertinoDialogAction _action(WidgetTester tester, String label) =>
    tester.widget<CupertinoDialogAction>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(CupertinoDialogAction),
      ),
    );

void main() {
  testWidgets('centred alert with title, message and two actions', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('„Party“ löschen?'), findsOneWidget);
    expect(
      find.text('Die Liste und 14 Artikel werden für alle gelöscht.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    final center = tester.getCenter(find.byType(CupertinoAlertDialog));
    expect(center.dx, closeTo(390 / 2, 1));
    expect(center.dy, closeTo(kLayoutHeight / 2, 40));
  });

  testWidgets('confirm resolves to true', (tester) async {
    final results = await _open(tester);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('cancel resolves to false', (tester) async {
    final results = await _open(tester, cancelLabel: 'Behalten');
    await tester.tap(find.text('Behalten'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('cancel is the bold default; destructive confirm is red', (
    tester,
  ) async {
    await _open(tester);
    final cancel = _action(tester, 'Cancel');
    expect(cancel.isDefaultAction, isTrue);
    expect(cancel.isDestructiveAction, isFalse);
    final confirm = _action(tester, 'Löschen');
    expect(confirm.isDestructiveAction, isTrue);
    expect(confirm.textStyle?.color, AvoColors.light.destructive);
    expect(
      tester.getCenter(find.text('Cancel')).dx,
      lessThan(tester.getCenter(find.text('Löschen')).dx),
    );
  });

  testWidgets('non-destructive confirm uses the tint', (tester) async {
    await _open(
      tester,
      title: 'Beitreten?',
      confirmLabel: 'Beitreten',
      destructive: false,
    );
    final confirm = _action(tester, 'Beitreten');
    expect(confirm.isDestructiveAction, isFalse);
    final theme = CupertinoTheme.of(tester.element(find.text('Beitreten')));
    expect(theme.primaryColor, AvoColors.light.tint);
  });

  testWidgets('a tap outside does not dismiss', (tester) async {
    final results = await _open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('without a message only the title shows', (tester) async {
    await _open(tester, message: null);
    expect(find.text('„Party“ löschen?'), findsOneWidget);
    expect(
      find.text('Die Liste und 14 Artikel werden für alle gelöscht.'),
      findsNothing,
    );
  });

  testWidgets('VoiceOver: both actions are labelled buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(
      tester.getSemantics(find.text('Löschen')),
      isSemantics(label: 'Löschen', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.text('Cancel')),
      isSemantics(label: 'Cancel', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  layoutMatrix(
    'showAvoConfirm',
    (context) => _AutoOpen(
      (context) => showAvoConfirm(
        context,
        title: '„Laktosefreie Bio-Vollmilch-Liste“ löschen?',
        message:
            'Die Liste und 14 Artikel im Wert von 23,80 € werden für alle '
            'Mitglieder gelöscht. Das lässt sich nicht rückgängig machen.',
        confirmLabel: 'Löschen',
      ),
    ),
    checkTapTargets: true,
    afterPump: (tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    },
  );
}
