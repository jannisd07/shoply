import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/calories/calories_screen.dart';
import 'package:shoply/routes/app_branch.dart';

// Kalorien (Teil B). Same contract as avo_routes.dart.

/// The screen at RoutePaths.calories (a tab until S2, then a push screen in
/// the Home tab).
Widget buildCaloriesRoot(BuildContext context, GoRouterState state) =>
    const CaloriesScreen();

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> caloriesChildRoutes = [];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> caloriesBranchRoutes = {};

/// Full-screen roots above the tab bar, with absolute paths.
final List<RouteBase> caloriesRootRoutes = [];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'health').
/// They open in the Profil tab.
final List<RouteBase> caloriesSettingsRoutes = [];
