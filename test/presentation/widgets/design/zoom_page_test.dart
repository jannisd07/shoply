import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/widgets/design/zoom_page.dart';

/// `/` with a small button and `/zoom` as a [ZoomPage] from its origin.
Future<GoRouter> _pump(WidgetTester tester, {bool reduceMotion = false}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Center(
          child: Builder(
            builder: (button) => GestureDetector(
              key: const Key('button'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ZoomOrigin.capture(button);
                button.push('/zoom');
              },
              child: const SizedBox(width: 80, height: 44),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/zoom',
        pageBuilder: (context, state) => ZoomPage<Object?>(
          key: state.pageKey,
          origin: ZoomOrigin.take(),
          child: const ColoredBox(
            color: Color(0xFFFFFFFF),
            child: Center(
              child: Text('page', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(402, 874),
        disableAnimations: reduceMotion,
      ),
      child: WidgetsApp.router(
        routerConfig: router,
        color: const Color(0xFF000000),
      ),
    ),
  );
  return router;
}

void main() {
  setUp(ZoomOrigin.debugReset);

  testWidgets('the page grows out of the tapped element and settles full',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await tester.tap(find.byKey(const Key('button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Early in the spring the page is a small frame around the button.
    final early = tester.getRect(find.byType(ClipRRect).first);
    expect(early.width, lessThan(402));
    expect(early.contains(const Offset(201, 437)), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(ClipRRect), findsNothing);
    expect(tester.getRect(find.byType(ColoredBox).last).size,
        const Size(402, 874));
  });

  testWidgets('a full screen is no origin; without one the page scales from '
      'the middle', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await _pump(tester);
    router.push('/zoom');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(ClipRRect), findsNothing);
    final early = tester.getRect(find.text('page'));
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.text('page'));
    expect(early.width, lessThan(settled.width));
    expect(early.center.dx, closeTo(settled.center.dx, 0.5));
  });

  testWidgets('swiping from the left edge past 30 % closes, less returns',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await tester.tap(find.byKey(const Key('button')));
    await tester.pumpAndSettle();

    // A short, slow drag springs back.
    final short = await tester.startGesture(const Offset(5, 400));
    await short.moveBy(const Offset(20, 0));
    await short.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await short.up();
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);

    // A long drag closes.
    final long = await tester.startGesture(const Offset(5, 400));
    await long.moveBy(const Offset(20, 0));
    await long.moveBy(const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await long.up();
    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);
  });

  testWidgets('Reduce Motion cross-fades instead of zooming', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, reduceMotion: true);
    await tester.tap(find.byKey(const Key('button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(ClipRRect), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
  });

  test('take() is consumed once', () {
    expect(ZoomOrigin.take(), isNull);
  });
}
