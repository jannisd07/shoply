import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_diary_screen.dart';
import 'package:shoply/presentation/screens/calories/challenges_screen.dart';
import 'package:shoply/presentation/screens/calories/goal_setup_screen.dart';
import 'package:shoply/presentation/screens/calories/weekly_summary_screen.dart';
import 'package:shoply/presentation/screens/calories/weight_tracking_screen.dart';
import 'package:shoply/presentation/screens/calories/what_can_i_eat_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/module_gate.dart';
import 'package:shoply/routes/route_paths.dart';

// Kalorien (Teil B). Same contract as avo_routes.dart; paths in
// docs/redesign/b-screens/kalorien.md §1.

/// The diary at RoutePaths.calories, a push screen in the Home tab:
/// `?date=YYYY-MM-DD` opens another day (never one after today),
/// `?focus=water` scrolls to the water row.
Widget buildCaloriesRoot(BuildContext context, GoRouterState state) {
  final q = state.uri.queryParameters;
  return CaloriesDiaryScreen(
    initialDateKey: dateKeyFromQuery(q['date'], calorieDayKey(DateTime.now())),
    focusWater: q['focus'] == 'water',
  );
}

/// Children of the diary in the Home tab (tab bar visible). The week,
/// weight, challenges, goals and ideas screens are the existing ones until
/// their slices rebuild them (S13–S21).
final List<RouteBase> caloriesChildRoutes = [
  GoRoute(path: 'week', builder: (_, __) => const WeeklySummaryScreen()),
  GoRoute(path: 'weight', builder: (_, __) => const WeightTrackingScreen()),
  GoRoute(path: 'challenges', builder: (_, __) => const ChallengesScreen()),
  GoRoute(path: 'goals', builder: (_, __) => const GoalSetupScreen()),
  GoRoute(path: 'ideas', builder: (_, __) => const WhatCanIEatScreen()),
  // `shoply://calories/water?ml=250` inside the app: the widget and Siri log
  // the water themselves (B9); the app opens the diary at the water row.
  GoRoute(
    path: 'water',
    redirect: (_, __) => '${RoutePaths.calories}?focus=water',
  ),
];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> caloriesBranchRoutes = {};

/// Full-screen roots above the tab bar (V-routes, §1.1): they open over the
/// tab they come from and close back to it. Pushed from the right; Reduce
/// Motion cross-fades. Each asks to switch the module on when it is off.
final List<RouteBase> caloriesRootRoutes = [
  GoRoute(
    path: '${RoutePaths.calories}/add',
    pageBuilder: (context, state) {
      final q = state.uri.queryParameters;
      return _fullScreenPage(
        context,
        state,
        CaloriesAddScreen(
          meal: mealFromQuery(q['meal']),
          dateKey: dateKeyFromQuery(q['date'], calorieDayKey(DateTime.now())),
        ),
      );
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/goals/setup',
    pageBuilder: (context, state) => _fullScreenPage(context, state, const GoalSetupScreen()),
  ),
];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'health').
/// They open in the Profil tab.
final List<RouteBase> caloriesSettingsRoutes = [];

Page<void> _fullScreenPage(BuildContext context, GoRouterState state, Widget screen) {
  final child = ModuleGate(module: AppModule.calories, child: screen);
  if (!context.reduceMotion) return CupertinoPage<void>(key: state.pageKey, child: child);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AvoMotion.fadeReduced,
    reverseTransitionDuration: AvoMotion.fadeReduced,
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
    child: child,
  );
}
