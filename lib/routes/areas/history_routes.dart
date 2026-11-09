import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_screen.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/history_screen.dart';
import 'package:shoply/presentation/screens/history/open_balances_screen.dart';
import 'package:shoply/presentation/screens/history/split_editor_screen.dart';
import 'package:shoply/presentation/screens/history/trip_amount_screen.dart';
import 'package:shoply/presentation/screens/history/trip_detail_screen.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/module_gate.dart';
import 'package:shoply/routes/route_paths.dart';

// Verlauf, Ersparnis, Kosten teilen (Teil B). Same contract as
// avo_routes.dart; paths in docs/redesign/b-screens/verlauf-kosten.md §1.

/// V4 "Verlauf" at RoutePaths.history, a push in the Listen tab; `?list=`
/// sets the filter, `?gone=1` says the opened trip was deleted.
Widget buildHistoryRoot(BuildContext context, GoRouterState state) =>
    HistoryScreen(
      listId: state.uri.queryParameters['list'],
      tripGone: state.uri.queryParameters['gone'] == '1',
    );

/// A full-screen page above the tab bar (V6, V7): pushed from the right,
/// a cross-fade with Reduce Motion.
Page<void> _fullScreenPage(BuildContext context, GoRouterState state, Widget child) {
  if (!context.reduceMotion) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AvoMotion.fadeReduced,
    reverseTransitionDuration: AvoMotion.fadeReduced,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    child: child,
  );
}

/// Children of `/history`: V5 in the Listen tab, V6 and V7 full screen.
/// "Kosten teilen" asks to switch the module on first when it is off.
final List<RouteBase> historyChildRoutes = [
  GoRoute(
    path: historyTripChildPath,
    builder: (context, state) =>
        TripDetailScreen(tripId: state.pathParameters['tripId']!),
    routes: [
      GoRoute(
        path: 'amount',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _fullScreenPage(
          context,
          state,
          TripAmountScreen(tripId: state.pathParameters['tripId']!),
        ),
      ),
      GoRoute(
        path: 'split',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return _fullScreenPage(
            context,
            state,
            ModuleGate(
              module: AppModule.costSplit,
              child: SplitEditorScreen(
                tripId: state.pathParameters['tripId']!,
                amountCents: int.tryParse(q['amount'] ?? ''),
                fromCheckout: q['from'] == 'checkout',
              ),
            ),
          );
        },
      ),
    ],
  ),
];

/// Further roots inside a tab, with absolute paths. V8 "Offene Beträge"
/// in the Listen tab, behind the Kosten-teilen module.
final Map<AppBranch, List<RouteBase>> historyBranchRoutes = {
  AppBranch.lists: [
    GoRoute(
      path: RoutePaths.splits,
      builder: (context, state) => ModuleGate(
        module: AppModule.costSplit,
        child: OpenBalancesScreen(
          showDone: state.uri.queryParameters['done'] == '1',
        ),
      ),
    ),
  ],
};

/// Full-screen roots above the tab bar, with absolute paths.
final List<RouteBase> historyRootRoutes = [
  // V1 "Einkauf abschließen" (opened through `openCheckoutFlow`).
  GoRoute(
    path: checkoutPattern,
    builder: (context, state) => CheckoutScreen(
      listId: state.pathParameters['listId']!,
      splitStepAvailable: historyChildRouteRegistered(historySplitChildPath),
      tripDetailAvailable: historyChildRouteRegistered(historyTripChildPath),
    ),
  ),
];

/// Whether a route below `/history` with [path] (relative, e.g.
/// `':tripId/split'`) is registered; V1 offers "Kosten teilen" and the
/// trip detail once they exist.
bool historyChildRouteRegistered(String path) {
  bool walk(List<RouteBase> routes, String prefix) {
    for (final r in routes) {
      if (r is! GoRoute) continue;
      final full = prefix.isEmpty ? r.path : '$prefix/${r.path}';
      if (full == path || walk(r.routes, full)) return true;
    }
    return false;
  }

  return walk(historyChildRoutes, '');
}

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'history').
/// They open in the Profil tab.
final List<RouteBase> historySettingsRoutes = [];
