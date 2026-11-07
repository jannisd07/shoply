import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/routes/app_branch.dart';

// Wochenplan (Teil B). Same contract as avo_routes.dart. The plan overview is
// the segment "Wochenplan" in the Rezepte tab: Teil A builds the segment
// control and shows [buildPlanSegment] below it, at RoutePaths.plan and
// RoutePaths.recipesPlanSegment.

/// Content of the Wochenplan segment in the Rezepte tab.
Widget buildPlanSegment(BuildContext context) => const SizedBox.shrink();

/// Children of a recipe, relative to `/recipes/:recipeId` (e.g. 'to-plan').
final List<RouteBase> planRecipeRoutes = [];

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> planChildRoutes = [];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> planBranchRoutes = {};

/// Full-screen roots above the tab bar, with absolute paths.
final List<RouteBase> planRootRoutes = [];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'plan').
/// They open in the Profil tab.
final List<RouteBase> planSettingsRoutes = [];
