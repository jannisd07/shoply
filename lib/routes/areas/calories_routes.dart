import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_amount_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_diary_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_entry_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_estimate_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_goal_setup_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_goals_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_manual_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_photo_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_recipe_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_scan_screen.dart';
import 'package:shoply/presentation/screens/calories/challenges_screen.dart';
import 'package:shoply/presentation/screens/calories/weekly_summary_screen.dart';
import 'package:shoply/presentation/screens/calories/weight_tracking_screen.dart';
import 'package:shoply/presentation/screens/calories/what_can_i_eat_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
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
/// weight, challenges and ideas screens are the existing ones until their
/// slices rebuild them (S15–S21).
final List<RouteBase> caloriesChildRoutes = [
  GoRoute(path: 'week', builder: (_, __) => const WeeklySummaryScreen()),
  GoRoute(path: 'weight', builder: (_, __) => const WeightTrackingScreen()),
  GoRoute(path: 'challenges', builder: (_, __) => const ChallengesScreen()),
  GoRoute(path: 'goals', builder: (_, __) => const CaloriesGoalsScreen()),
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

/// `?meal=` and `?date=` of a logging route (a date after today is today).
({MealType? meal, String? dateKey}) _mealAndDate(GoRouterState state) {
  final q = state.uri.queryParameters;
  return (meal: mealFromQuery(q['meal']), dateKey: dateKeyFromQuery(q['date'], calorieDayKey(DateTime.now())));
}

/// Full-screen roots above the tab bar (V-routes, §1.1): they open over the
/// tab they come from and close back to it. Pushed from the right; Reduce
/// Motion cross-fades. Each asks to switch the module on when it is off.
/// The logging flow (S3 to S8) is marked, so "Eintragen" closes all of it.
final List<RouteBase> caloriesRootRoutes = [
  GoRoute(
    path: '${RoutePaths.calories}/add',
    pageBuilder: (context, state) {
      final m = _mealAndDate(state);
      return _fullScreenPage(context, state, CaloriesAddScreen(meal: m.meal, dateKey: m.dateKey), flow: true);
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/add/photo',
    pageBuilder: (context, state) {
      final m = _mealAndDate(state);
      return _fullScreenPage(context, state, CaloriesPhotoScreen(meal: m.meal, dateKey: m.dateKey), flow: true);
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/add/estimate',
    // The photo lives only in memory: without it (deep link, restored
    // route) back to the camera.
    redirect: (context, state) => state.extra is Uint8List
        ? null
        : Uri(path: '${RoutePaths.calories}/add/photo', queryParameters: state.uri.queryParameters.isEmpty ? null : state.uri.queryParameters).toString(),
    pageBuilder: (context, state) {
      final m = _mealAndDate(state);
      return _fullScreenPage(
        context,
        state,
        CaloriesEstimateScreen(photo: state.extra! as Uint8List, meal: m.meal, dateKey: m.dateKey),
        flow: true,
      );
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/scan',
    pageBuilder: (context, state) {
      final m = _mealAndDate(state);
      return _fullScreenPage(context, state, CaloriesScanScreen(meal: m.meal, dateKey: m.dateKey), flow: true);
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/add/food/:foodId',
    pageBuilder: (context, state) {
      final m = _mealAndDate(state);
      final extra = state.extra;
      return _fullScreenPage(
        context,
        state,
        CaloriesAmountScreen(
          foodId: state.pathParameters['foodId']!,
          food: extra is CalorieAmountFood ? extra : null,
          meal: m.meal,
          dateKey: m.dateKey,
        ),
        flow: true,
      );
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/add/manual',
    pageBuilder: (context, state) {
      final m = _mealAndDate(state);
      final q = state.uri.queryParameters;
      return _fullScreenPage(
        context,
        state,
        CaloriesManualScreen(name: q['name'], barcode: q['barcode'], meal: m.meal, dateKey: m.dateKey),
        flow: true,
      );
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/add/recipe/:recipeId',
    pageBuilder: (context, state) {
      final q = state.uri.queryParameters;
      final extra = state.extra;
      final date = q['date'];
      return _fullScreenPage(
        context,
        state,
        CaloriesRecipeScreen(
          recipeId: state.pathParameters['recipeId']!,
          recipe: extra is Recipe ? extra : null,
          servings: double.tryParse(q['servings'] ?? ''),
          // The plan day may lie ahead; the screen logs today then.
          planDateKey: date != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? date : null,
          meal: mealFromQuery(q['meal']),
        ),
      );
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/entry/:entryId',
    pageBuilder: (context, state) {
      final extra = state.extra;
      final entry = extra is FoodLogEntry ? extra : null;
      final today = calorieDayKey(DateTime.now());
      return _fullScreenPage(
        context,
        state,
        CaloriesEntryScreen(
          entryId: state.pathParameters['entryId']!,
          dateKey: entry?.dateKey ?? dateKeyFromQuery(state.uri.queryParameters['date'], today) ?? today,
          entry: entry,
        ),
      );
    },
  ),
  GoRoute(
    path: '${RoutePaths.calories}/goals/setup',
    pageBuilder: (context, state) => _fullScreenPage(
      context,
      state,
      CaloriesGoalSetupScreen(from: state.uri.queryParameters['from']),
    ),
  ),
];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'health').
/// They open in the Profil tab. "Ziele" is the same screen as
/// `/calories/goals`, so the person stays in the Profil tab.
final List<RouteBase> caloriesSettingsRoutes = [
  GoRoute(
    path: 'health/goals',
    builder: (context, state) => const ModuleGate(module: AppModule.calories, child: CaloriesGoalsScreen()),
  ),
];

Page<void> _fullScreenPage(BuildContext context, GoRouterState state, Widget screen, {bool flow = false}) {
  final child = ModuleGate(module: AppModule.calories, child: screen);
  final name = flow ? kCalorieFlowPageName : null;
  if (!context.reduceMotion) return CupertinoPage<void>(key: state.pageKey, name: name, child: child);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: name,
    transitionDuration: AvoMotion.fadeReduced,
    reverseTransitionDuration: AvoMotion.fadeReduced,
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
    child: child,
  );
}
