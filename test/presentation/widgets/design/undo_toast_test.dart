import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

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

/// Pumps a screen with (or without) a host and returns a context below it.
Future<BuildContext> _pump(
  WidgetTester tester, {
  bool host = true,
  bool voiceOver = false,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  late BuildContext below;
  final screen = Builder(
    builder: (context) {
      below = context;
      return const SizedBox.expand();
    },
  );
  await tester.pumpWidget(
    layoutHarness(
      layout,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(accessibleNavigation: voiceOver),
          child: SizedBox.expand(
            child: host ? AvoToastHost(child: screen) : screen,
          ),
        ),
      ),
    ),
  );
  return below;
}

const _deleted = 'Milch gelöscht';

/// The capsule: the decorated box painted in the glass fallback colour.
Finder _capsule() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == AvoColors.light.glassFallback,
);

void main() {
  testWidgets('shows the message and the tinted action', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(
      context,
      message: _deleted,
      actionLabel: 'Widerrufen',
      onAction: () {},
    );
    await tester.pumpAndSettle();
    expect(find.text(_deleted), findsOneWidget);
    final message = tester.widget<Text>(find.text(_deleted)).style!;
    expect(message.fontSize, 15);
    expect(message.fontWeight, FontWeight.w600);
    final action = tester.widget<Text>(find.text('Widerrufen')).style!;
    expect(action.color, AvoColors.light.tint);
  });

  testWidgets('glass capsule: opaque fallback, hairline, at least 44 pt', (
    tester,
  ) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: 'Liste geteilt');
    await tester.pumpAndSettle();
    expect(_capsule(), findsOneWidget);
    final box = tester.widget<DecoratedBox>(_capsule());
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
    expect(tester.getSize(_capsule()).height, greaterThanOrEqualTo(44));
    expect(
      find.descendant(of: _capsule(), matching: find.text('Liste geteilt')),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('rests above the tab bar', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pumpAndSettle();
    final capsule = _capsule();
    // Harness: 34 pt home indicator -> tab bar 20 pt from the bottom,
    // 64 pt tall, 12 pt gap: the toast ends 96 pt above the bottom.
    expect(tester.getRect(capsule).bottom, closeTo(kLayoutHeight - 96, 0.5));
  });

  testWidgets('a second toast replaces the first', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: 'Milch gelöscht');
    await tester.pump(const Duration(milliseconds: 100));
    AvoToast.show(context, message: 'Eier gelöscht');
    await tester.pumpAndSettle();
    expect(find.text('Milch gelöscht'), findsNothing);
    expect(find.text('Eier gelöscht'), findsOneWidget);
  });

  testWidgets('gone after 4 s, still there just before', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text(_deleted), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text(_deleted), findsNothing);
  });

  testWidgets('a replacing toast starts its own 4 s', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: 'Milch gelöscht');
    await tester.pump(const Duration(seconds: 3));
    AvoToast.show(context, message: 'Eier gelöscht');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Eier gelöscht'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Eier gelöscht'), findsNothing);
  });

  testWidgets('custom duration', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(
      context,
      message: _deleted,
      duration: const Duration(seconds: 1),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text(_deleted), findsNothing);
  });

  testWidgets('VoiceOver: 10 s and an announcement', (tester) async {
    final context = await _pump(tester, voiceOver: true);
    AvoToast.show(
      context,
      message: _deleted,
      actionLabel: 'Widerrufen',
      onAction: () {},
    );
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements().map((a) => a.message), [
      '$_deleted, Widerrufen',
    ]);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(_deleted), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(_deleted), findsNothing);
  });

  testWidgets('no announcement without VoiceOver', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('the action runs and hides the toast', (tester) async {
    var undone = 0;
    final context = await _pump(tester);
    AvoToast.show(
      context,
      message: _deleted,
      actionLabel: 'Widerrufen',
      onAction: () => undone++,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Widerrufen'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text(_deleted), findsNothing);
  });

  testWidgets('a swipe down dismisses', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pumpAndSettle();
    await tester.drag(find.text(_deleted), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(find.text(_deleted), findsNothing);
  });

  testWidgets('a short pull springs back and stays', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pumpAndSettle();
    final rest = tester.getRect(find.text(_deleted));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(_deleted)),
    );
    await gesture.moveBy(const Offset(0, 10));
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    expect(tester.getRect(find.text(_deleted)).top, greaterThan(rest.top));
    // Hold still, then release without velocity.
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text(_deleted), findsOneWidget);
    expect(tester.getRect(find.text(_deleted)).top, closeTo(rest.top, 0.5));
  });

  testWidgets('pulling up resists like a rubber band', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pumpAndSettle();
    final rest = tester.getRect(find.text(_deleted));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(_deleted)),
    );
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    final moved = rest.top - tester.getRect(find.text(_deleted)).top;
    expect(moved, greaterThan(0));
    expect(moved, lessThan(80));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion: no rise, only a fade', (tester) async {
    final context = await _pump(
      tester,
      layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
    );
    AvoToast.show(context, message: _deleted);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final translate = tester.widget<Transform>(
      find
          .ancestor(of: find.text(_deleted), matching: find.byType(Transform))
          .first,
    );
    expect(translate.transform.getTranslation().y, 0);
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text(_deleted), matching: find.byType(Opacity))
          .first,
    );
    expect(opacity.opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('spring: rises from below into place', (tester) async {
    final context = await _pump(tester);
    AvoToast.show(context, message: _deleted);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final early = tester.getRect(find.text(_deleted)).top;
    await tester.pumpAndSettle();
    final rest = tester.getRect(find.text(_deleted)).top;
    expect(early, greaterThan(rest));
  });

  testWidgets('touches outside the toast reach the screen', (tester) async {
    var taps = 0;
    tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late BuildContext below;
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        SizedBox.expand(
          child: AvoToastHost(
            child: Builder(
              builder: (context) {
                below = context;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    );
    AvoToast.show(below, message: _deleted);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 200));
    expect(taps, 1);
  });

  testWidgets('without a host it uses the root overlay', (tester) async {
    final context = await _pump(tester, host: false);
    AvoToast.show(context, message: 'Milch gelöscht');
    await tester.pumpAndSettle();
    expect(find.text('Milch gelöscht'), findsOneWidget);
    AvoToast.show(context, message: 'Eier gelöscht');
    await tester.pumpAndSettle();
    expect(find.text('Milch gelöscht'), findsNothing);
    expect(find.text('Eier gelöscht'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Eier gelöscht'), findsNothing);
    // A later toast gets a fresh overlay entry.
    AvoToast.show(context, message: 'Brot gelöscht');
    await tester.pumpAndSettle();
    expect(find.text('Brot gelöscht'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('VoiceOver: action is a labelled 44 pt button', (tester) async {
    final handle = tester.ensureSemantics();
    final context = await _pump(tester);
    AvoToast.show(
      context,
      message: _deleted,
      actionLabel: 'Widerrufen',
      onAction: () {},
    );
    await tester.pumpAndSettle();
    final action = find.bySemanticsLabel('Widerrufen');
    expect(
      tester.getSemantics(action),
      isSemantics(isButton: true, hasTapAction: true),
    );
    final size = tester.getSize(action);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel(_deleted), findsOneWidget);
    handle.dispose();
  });

  testWidgets('from AX1 the action moves below the message', (tester) async {
    final context = await _pump(
      tester,
      layout: const LayoutCase(width: 390, scale: 2),
    );
    AvoToast.show(
      context,
      message: _deleted,
      actionLabel: 'Widerrufen',
      onAction: () {},
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Widerrufen')).top,
      greaterThanOrEqualTo(tester.getRect(find.text(_deleted)).bottom),
    );
  });

  layoutMatrix(
    'AvoToast in its host',
    (context) => SizedBox.expand(
      child: AvoToastHost(
        child: _AutoOpen(
          (context) => AvoToast.show(
            context,
            message:
                '„Laktosefreie Bio-Vollmilch“ und 3 weitere Artikel '
                'für 12,49 € gelöscht',
            actionLabel: 'Widerrufen',
            onAction: () {},
          ),
        ),
      ),
    ),
    checkTapTargets: true,
    afterPump: (tester) async {
      await tester.pumpAndSettle();
      expect(find.text('Widerrufen'), findsOneWidget);
    },
  );
}
