import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/auth/welcome_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_screen.dart';
import 'package:shoply/presentation/screens/home/home_screen.dart';
import 'package:shoply/presentation/screens/ai/avo_chat_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_detail_screen.dart';
import 'package:shoply/presentation/screens/recipes/multi_step_recipe_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_author_page.dart';
import 'package:shoply/presentation/screens/recipes/saved_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/my_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/category_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/creators_screen.dart';
import 'package:shoply/presentation/screens/recipes/all_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_drafts_screen.dart';
import 'package:shoply/presentation/screens/profile/profile_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_preferences_screen.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/list_background_picker_screen.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_screen.dart'
    show OnboardingScreen, hasCompletedOnboarding;
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import 'package:shoply/presentation/screens/auth/login_screen.dart';
import 'package:shoply/presentation/screens/auth/signup_screen.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/name_prompt_screen.dart';

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
    initialLocation: supabase.currentUser != null ? '/home' : '/onboarding',
    refreshListenable: GoRouterRefreshStream(supabase.authStateChanges),
    observers: observers,
    routes: [
      // Onboarding (first-time users)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Welcome / Auth Entry (returning users who completed onboarding)
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // Name prompt route (after login if no display name)
      GoRoute(
        path: '/name-prompt',
        name: 'name-prompt',
        builder: (context, state) => const NamePromptScreen(),
      ),

      // Main app with bottom navigation – StatefulShellRoute keeps each tab's
      // state alive (no rebuilds when switching tabs) and lets us render a
      // smooth horizontal slide transition between branches.
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
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),

          // Branch 1: Recipes + nested routes
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recipes',
                name: 'recipes',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: RecipesScreen(
                    initialQuery: state.uri.queryParameters['q'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'add-recipe',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final draftId = extra?['draftId'] as String?;
                      final recipeId = extra?['recipeId'] as String?;
                      return MultiStepRecipeScreen(
                        draftId: draftId,
                        recipeId: recipeId,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'drafts',
                    name: 'recipe-drafts',
                    builder: (context, state) => const RecipeDraftsScreen(),
                  ),
                  GoRoute(
                    path: 'saved',
                    name: 'saved-recipes',
                    builder: (context, state) => const SavedRecipesScreen(),
                  ),
                  GoRoute(
                    path: 'my',
                    name: 'my-recipes',
                    builder: (context, state) => const MyRecipesScreen(),
                  ),
                  GoRoute(
                    path: 'creators',
                    name: 'creators',
                    builder: (context, state) => const CreatorsScreen(),
                  ),
                  GoRoute(
                    path: 'popular',
                    name: 'popular-recipes',
                    builder: (context, state) =>
                        const AllRecipesScreen(popularOnly: true),
                  ),
                  GoRoute(
                    path: 'all',
                    name: 'all-recipes',
                    builder: (context, state) => const AllRecipesScreen(),
                  ),
                  GoRoute(
                    path: 'category/:categoryId',
                    name: 'category-recipes',
                    builder: (context, state) {
                      final categoryId = state.pathParameters['categoryId']!;
                      return CategoryRecipesScreen(categoryId: categoryId);
                    },
                  ),
                  GoRoute(
                    path: ':recipeId',
                    name: 'recipe-detail',
                    builder: (context, state) {
                      final recipeId = state.pathParameters['recipeId']!;
                      return RecipeDetailScreen(recipeId: recipeId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Calories (tab only shown when the user opted in;
          // the branch always exists so the index mapping stays stable)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calories',
                name: 'calories',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const CaloriesScreen(),
                ),
              ),
            ],
          ),

          // Branch 3: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Separate routes outside ShellRoute (no bottom nav)
      GoRoute(
        path: '/avo',
        name: 'avo-chat',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const AvoChatScreen(),
        ),
      ),
      GoRoute(
        path: '/lists/:listId',
        name: 'list-detail',
        pageBuilder: (context, state) {
          final listId = state.pathParameters['listId']!;
          final listName =
              state.uri.queryParameters['name'] ?? 'Shopping List';
          return CupertinoPage(
            key: state.pageKey,
            child: ListDetailScreen(listId: listId, listName: listName),
          );
        },
        routes: [
          GoRoute(
            path: 'activities',
            name: 'list-activities',
            builder: (context, state) {
              final listId = state.pathParameters['listId']!;
              final listName =
                  state.uri.queryParameters['name'] ?? 'Shopping List';
              return ListActivitiesScreen(
                listId: listId,
                listName: listName,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/author/:authorId',
        name: 'author-profile',
        builder: (context, state) {
          final authorId = state.pathParameters['authorId']!;
          final authorName = state.extra != null && state.extra is Map
              ? (state.extra as Map)['authorName'] as String?
              : null;
          return RecipeAuthorPage(authorId: authorId, authorName: authorName);
        },
      ),
      GoRoute(
        path: '/background-picker/:listId',
        name: 'background-picker',
        builder: (context, state) {
          final listId = state.pathParameters['listId']!;
          return ListBackgroundPickerScreen(listId: listId);
        },
      ),
      GoRoute(
        path: '/diet-preferences',
        name: 'diet-preferences',
        builder: (context, state) => const DietPreferencesScreen(),
      ),
      // Deep link route for shared recipes (accessible without auth context)
      GoRoute(
        path: '/recipe/:recipeId',
        name: 'shared-recipe',
        builder: (context, state) {
          final recipeId = state.pathParameters['recipeId']!;
          return RecipeDetailScreen(recipeId: recipeId);
        },
      ),
      // Shared-list and invite deep links are aliases of /lists/:listId.
      // Logged-out users are sent to sign in first (top-level redirect).
      GoRoute(
        path: '/list/:listId',
        name: 'shared-list',
        redirect: (context, state) => _sharedListTarget(state),
      ),
      GoRoute(
        path: '/invite/:listId',
        name: 'list-invite',
        redirect: (context, state) => _sharedListTarget(state),
      ),
    ],
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
        _pendingListLink = _sharedListTarget(state);
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

/// Maps `/list/:id` and `/invite/:id` onto the canonical `/lists/:id` route.
String _sharedListTarget(GoRouterState state) {
  final listId = state.pathParameters['listId'] ??
      state.uri.pathSegments.last;
  final listName = state.uri.queryParameters['name'] ?? 'Shared List';
  return Uri(path: '/lists/$listId', queryParameters: {'name': listName})
      .toString();
}
