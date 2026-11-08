import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';

/// Pumps a two-route app (`/` and `/pro`) and returns the WidgetRef of `/`.
Future<({WidgetRef ref, GoRouter router, BuildContext context})> _pump(
  WidgetTester tester, {
  required bool subscribed,
}) async {
  late WidgetRef homeRef;
  late BuildContext homeContext;
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Consumer(builder: (context, ref, _) {
        homeRef = ref;
        homeContext = context;
        return const Text('home', textDirection: TextDirection.ltr);
      }),
    ),
    GoRoute(
      path: '/pro',
      builder: (context, state) => Text(
        'paywall ${state.uri.queryParameters['feature']}',
        textDirection: TextDirection.ltr,
      ),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [isSubscribedProvider.overrideWithValue(subscribed)],
    child: WidgetsApp.router(
      routerConfig: router,
      color: const Color(0xFF000000),
    ),
  ));
  return (ref: homeRef, router: router, context: homeContext);
}

void main() {
  tearDown(() => ProFeatures.debugGatedOverride = null);

  test('nothing is Pro until A9 is decided', () {
    expect(ProFeatures.gated, isEmpty);
    expect(ProFeatures.isGated('cook_mode'), isFalse);
  });

  testWidgets('a free feature runs without a paywall', (tester) async {
    final app = await _pump(tester, subscribed: false);
    var ran = 0;
    final result = await ProGate.run(app.context, app.ref,
        feature: 'cook_mode', action: () => ran++);
    expect(result, isTrue);
    expect(ran, 1);
    await tester.pumpAndSettle();
    expect(find.textContaining('paywall'), findsNothing);
  });

  testWidgets('a Pro feature runs for subscribers', (tester) async {
    ProFeatures.debugGatedOverride = {'cook_mode'};
    final app = await _pump(tester, subscribed: true);
    var ran = 0;
    expect(
      await ProGate.run(app.context, app.ref,
          feature: 'cook_mode', action: () => ran++),
      isTrue,
    );
    expect(ran, 1);
    expect(ProGate.isLocked(app.ref, 'cook_mode'), isFalse);
  });

  testWidgets('a Pro feature opens the paywall for others', (tester) async {
    ProFeatures.debugGatedOverride = {'cook_mode'};
    final app = await _pump(tester, subscribed: false);
    expect(ProGate.isLocked(app.ref, 'cook_mode'), isTrue);
    var ran = 0;
    final pending = ProGate.run(app.context, app.ref,
        feature: 'cook_mode', action: () => ran++);
    await tester.pumpAndSettle();
    expect(find.text('paywall cook_mode'), findsOneWidget);

    // Closing the paywall without subscribing: the action does not run.
    app.router.pop();
    await tester.pumpAndSettle();
    expect(await pending, isFalse);
    expect(ran, 0);
  });
}
