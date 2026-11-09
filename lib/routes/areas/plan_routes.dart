import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/routes/app_branch.dart';

// Wochenplan (Teil B). Same contract as avo_routes.dart. The plan overview is
// the segment "Wochenplan" in the Rezepte tab: Teil A builds the segment
// control and shows [buildPlanSegment] below it, at RoutePaths.plan and
// RoutePaths.recipesPlanSegment.

/// Content of the Wochenplan segment in the Rezepte tab, as slivers (one
/// `SliverMainAxisGroup`). Teil A puts it into the tab's `CustomScrollView`
/// below the segment control, only while "Wochenplan" is chosen, so the
/// large title "Rezepte" scrolls with it (A-P1). Teil B fills it with B7.
Widget buildPlanSegment(BuildContext context) => const SliverToBoxAdapter();

/// The plan's main action and its undo hint, outside the scroll view. Teil A
/// lays it over the content of the Rezepte tab, at the bottom just above the
/// tab bar, only while "Wochenplan" is chosen (A-P2). Null shows nothing.
/// Teil B fills it with B7.
Widget? buildPlanFloatingBar(BuildContext context) => null;

/// Toolbar buttons of the plan (previous week, next week, Mehr). Teil A shows
/// them on the right of the Rezepte tab's `GlassToolbar` instead of
/// "Gespeichert" and "Mehr", only while "Wochenplan" is chosen (A-P3).
/// Teil B fills it with B7.
List<Widget> buildPlanToolbarActions(BuildContext context) => const [];

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
