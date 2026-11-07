import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/profile/profile_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_preferences_screen.dart';
import 'package:shoply/routes/areas/avo_routes.dart';
import 'package:shoply/routes/areas/calories_routes.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/areas/offers_routes.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/route_paths.dart';

/// Routes of the Profil tab branch (Teil A).
final List<RouteBase> profileBranchRoutes = [
  GoRoute(
    path: RoutePaths.profile,
    name: 'profile',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const ProfileScreen()),
  ),
  // Settings pages. `/settings` itself shows the Profil tab, so going back
  // from a settings page lands there. Teil B's pages are mounted here too.
  GoRoute(
    path: RoutePaths.settings,
    name: 'settings',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const ProfileScreen()),
    routes: [
      ...offersSettingsRoutes,
      ...avoSettingsRoutes,
      ...planSettingsRoutes,
      ...caloriesSettingsRoutes,
      ...historySettingsRoutes,
    ],
  ),
];

/// Profile and settings routes outside the tab bar (Teil A).
final List<RouteBase> profileRoutes = [
  GoRoute(
    path: RoutePaths.dietPreferences,
    name: 'diet-preferences',
    builder: (context, state) => const DietPreferencesScreen(),
  ),
];
