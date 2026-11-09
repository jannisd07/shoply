import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/presentation/screens/history/checkout/checkout_screen.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/shopping_history_screen.dart';
import 'package:shoply/routes/app_branch.dart';

// Verlauf, Ersparnis, Kosten teilen (Teil B). Same contract as
// avo_routes.dart.

/// The screen at RoutePaths.history (full screen until S2, then in the
/// Listen tab).
Widget buildHistoryRoot(BuildContext context, GoRouterState state) =>
    const ShoppingHistoryScreen();

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> historyChildRoutes = [];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> historyBranchRoutes = {};

/// Full-screen roots above the tab bar, with absolute paths.
final List<RouteBase> historyRootRoutes = [
  // V1 "Einkauf abschließen" (opened through `openCheckoutFlow`).
  GoRoute(
    path: checkoutPattern,
    builder: (context, state) => CheckoutScreen(
      listId: state.pathParameters['listId']!,
      splitStepAvailable: historyChildRouteRegistered(historySplitChildPath),
      tripDetailAvailable: historyChildRouteRegistered(':tripId'),
    ),
  ),
];

/// Whether a child route with [path] is registered below `/history`
/// ("Kosten teilen" and "Einkauf-Detail" come with slice W11; V1 offers
/// them once they exist).
bool historyChildRouteRegistered(String path) =>
    historyChildRoutes.any((r) => r is GoRoute && r.path == path);

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'history').
/// They open in the Profil tab.
final List<RouteBase> historySettingsRoutes = [];
