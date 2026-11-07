import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/data/services/analytics_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_screen.dart'
    show hasCompletedOnboarding;
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/areas/auth_routes.dart';
import 'package:shoply/routes/areas/avo_routes.dart';
import 'package:shoply/routes/areas/calories_routes.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/areas/home_routes.dart';
import 'package:shoply/routes/areas/lists_routes.dart';
import 'package:shoply/routes/areas/offers_routes.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/areas/recipes_routes.dart';
import 'package:shoply/routes/route_paths.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Forwards navigation events to the Firebase Analytics observer.
///
/// The router is built on the first frame, but [AnalyticsService.initialize]
/// (which creates the real observer) runs later in the background init. Reading
/// the observer lazily on every event means screen views are tracked as soon
/// as Firebase is ready instead of never.
class _LazyAnalyticsObserver extends NavigatorObserver {
  NavigatorObserver? get _target => AnalyticsService.instance.observer;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _target?.didPush(route, previousRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _target?.didPop(route, previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _target?.didRemove(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _target?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
}

/// Onboarding completion, memoized once it is true (the flag is never reset),
/// so the redirect stops hitting SharedPreferences on every navigation.
bool _onboardingDone = false;

/// A shared-list link opened while logged out. It is resumed the first time
/// the user reaches /home after signing in.
String? _pendingListLink;

/// Helper class to refresh GoRouter when auth state changes. Only events
/// that change whether a user is signed in re-run the redirect; the hourly
/// tokenRefreshed and userUpdated events do not.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((AuthState state) {
      if (_routingEvents.contains(state.event)) notifyListeners();
    });
  }

  static const _routingEvents = {
    AuthChangeEvent.initialSession,
    AuthChangeEvent.signedIn,
    AuthChangeEvent.signedOut,
    AuthChangeEvent.passwordRecovery,
  };

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = SupabaseService.instance;

  // Analytics screen tracking (iOS/Android only)
  final observers = <NavigatorObserver>[
    if (Platform.isIOS || Platform.isAndroid) _LazyAnalyticsObserver(),
  ];

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: supabase.currentUser != null ? '/home' : '/onboarding',
    refreshListenable: GoRouterRefreshStream(supabase.authStateChanges),
    observers: observers,
    routes: buildAppRoutes(),
    redirect: (context, state) async {
      final isLoggedIn = SupabaseService.instance.currentUser != null;
      final uri = state.uri;

      // Convert shoply:// deep links to proper paths
      if (uri.scheme == 'shoply') {
        final host = uri.host; // e.g. 'recipe', 'list'
        final segments = uri.pathSegments;
        const hosts = {'recipe', 'list', 'invite', 'author'};
        if (hosts.contains(host) && segments.isNotEmpty) {
          return '/$host/${segments[0]}';
        }
        return '/home';
      }

      final location = state.matchedLocation;
      final isSharedListLink =
          location.startsWith('/list/') || location.startsWith('/invite/');

      // Public routes that don't require authentication
      final isPublicRoute =
          location == '/onboarding' ||
          location == '/welcome' ||
          location == '/login' ||
          location == '/signup' ||
          location == '/reset-password' ||
          location.startsWith('/recipe/');

      final isNamePrompt = location == '/name-prompt';
      final isNewNamePrompt = isNamePrompt && uri.queryParameters['new'] == '1';
      final isOnboarding = location == '/onboarding';

      // A shared list needs an account (RLS returns nothing otherwise):
      // remember the link and resume it after sign-in.
      if (!isLoggedIn && isSharedListLink) {
        _pendingListLink = sharedListTarget(state);
      }

      if (!_onboardingDone) _onboardingDone = await hasCompletedOnboarding();
      final onboardingDone = _onboardingDone;

      // First-time user: show onboarding unless on a public deep link
      if (!onboardingDone && !isOnboarding && !isLoggedIn) {
        // Allow deep links and auth sub-routes through
        if (location.startsWith('/recipe/') ||
            location == '/login' ||
            location == '/signup' ||
            location == '/reset-password') {
          return null;
        }
        return '/onboarding';
      }

      // Onboarding done but not logged in: show welcome (not onboarding again)
      if (onboardingDone && isOnboarding && !isLoggedIn) {
        return '/welcome';
      }

      // Not logged in - redirect to welcome screen only if trying to access private route
      if (!isLoggedIn && !isPublicRoute) {
        return '/welcome';
      }

      // Allow access to reset password page
      if (location == '/reset-password') {
        return null;
      }

      if (isNamePrompt && !isNewNamePrompt) {
        return isLoggedIn ? '/home' : '/welcome';
      }

      if (isLoggedIn) {
        // Resume a shared-list link that was opened while logged out.
        final pending = _pendingListLink;
        if (pending != null && location == '/home') {
          _pendingListLink = null;
          return pending;
        }
        // Bounce off the passive entry screens. Login/signup complete their
        // own async success routing, so forcing them here can race OTP
        // verification and show a false error.
        if (location == '/welcome' || isOnboarding) {
          return '/home';
        }
      }

      return null;
    },
  );
});

/// Routes Teil B wants inside [branch], from all B area files.
List<RouteBase> _bBranch(AppBranch branch) => [
  ...?avoBranchRoutes[branch],
  ...?caloriesBranchRoutes[branch],
  ...?planBranchRoutes[branch],
  ...?offersBranchRoutes[branch],
  ...?historyBranchRoutes[branch],
];

/// All routes of the app, assembled from the area files in `routes/areas/`.
///
/// Tabs (StatefulShellRoute keeps each tab's state alive and lets us render a
/// smooth horizontal slide between branches): Home, Rezepte, Kalorien (only
/// shown when the user opted in; the branch always exists so the index
/// mapping stays stable), Profil. Everything else opens full screen without
/// the tab bar. From S2 on the tabs follow D2 (see [AppBranch]); until then
/// routes for the Listen and Avo tabs open full screen.
List<RouteBase> buildAppRoutes() => [
  ...authRoutes,
  StatefulShellRoute(
    builder: (context, state, navigationShell) =>
        MainScaffold(navigationShell: navigationShell),
    navigatorContainerBuilder: (context, navigationShell, children) =>
        SlidingTabsContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        ),
    branches: [
      // Branch 0: Home
      StatefulShellBranch(
        routes: [...homeBranchRoutes, ..._bBranch(AppBranch.home)],
      ),
      // Branch 1: Recipes + nested routes
      StatefulShellBranch(
        routes: [...recipesBranchRoutes, ..._bBranch(AppBranch.recipes)],
      ),
      // Branch 2: Calories (Teil B screen)
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: RoutePaths.calories,
            name: 'calories',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: buildCaloriesRoot(context, state),
            ),
            routes: caloriesChildRoutes,
          ),
        ],
      ),
      // Branch 3: Profile
      StatefulShellBranch(
        routes: [...profileBranchRoutes, ..._bBranch(AppBranch.profile)],
      ),
    ],
  ),
  // Separate routes outside the shell (no bottom nav)
  GoRoute(
    path: RoutePaths.avo,
    name: 'avo-chat',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: buildAvoRoot(context, state)),
    routes: avoChildRoutes,
  ),
  ...listsRoutes,
  ...recipesRoutes,
  ...profileRoutes,
  GoRoute(
    path: RoutePaths.offers,
    name: 'offers',
    builder: buildOffersRoot,
    routes: offersChildRoutes,
  ),
  GoRoute(
    path: RoutePaths.history,
    name: 'history',
    builder: buildHistoryRoot,
    routes: historyChildRoutes,
  ),
  // No Listen and Avo tabs yet: their routes open full screen.
  ..._bBranch(AppBranch.lists),
  ..._bBranch(AppBranch.avo),
  ...avoRootRoutes,
  ...caloriesRootRoutes,
  ...planRootRoutes,
  ...offersRootRoutes,
  ...historyRootRoutes,
];
