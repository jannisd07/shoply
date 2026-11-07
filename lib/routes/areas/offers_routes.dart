import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/home/weekly_deals_screen.dart';
import 'package:shoply/routes/app_branch.dart';

// Angebote (Teil B). Same contract as avo_routes.dart.

/// The screen at RoutePaths.offers ("Angebote der Woche"; full screen until
/// S2, then in the Listen tab).
Widget buildOffersRoot(BuildContext context, GoRouterState state) =>
    const WeeklyDealsScreen();

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> offersChildRoutes = [];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> offersBranchRoutes = {};

/// Full-screen roots above the tab bar, with absolute paths.
final List<RouteBase> offersRootRoutes = [];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'offers').
/// They open in the Profil tab.
final List<RouteBase> offersSettingsRoutes = [];
