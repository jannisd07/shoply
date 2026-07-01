import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/auth/welcome_screen.dart';
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
import 'package:shoply/presentation/screens/lists/list_background_selection_screen.dart';
import 'package:shoply/presentation/screens/lists/list_background_picker_screen.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/screens/onboarding/unified_setup_screen.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_screen.dart'
    show OnboardingScreen, hasCompletedOnboarding;
import 'package:shoply/presentation/screens/legal/privacy_policy_screen.dart';
import 'package:shoply/presentation/screens/legal/terms_of_service_screen.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/analytics_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import 'package:shoply/presentation/screens/auth/login_screen.dart';
import 'package:shoply/presentation/screens/auth/signup_screen.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/name_prompt_screen.dart';

/// Helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((AuthState _) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = SupabaseService.instance;

  // Get analytics observer if available (iOS/Android only)
  final observers = <NavigatorObserver>[];
  if (Platform.isIOS || Platform.isAndroid) {
    final analyticsObserver = AnalyticsService.instance.observer;
    if (analyticsObserver != null) {
      observers.add(analyticsObserver);
    }
  }

  return GoRouter(
    initialLocation: '/onboarding',
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

      // Setup route (mandatory after signup)
      GoRoute(
        path: '/setup',
        name: 'setup',
        builder: (context, state) => const UnifiedSetupScreen(),
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
          // Branch 0: Home + list detail (sibling routes share the home branch)
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
                  child: const RecipesScreen(),
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

          // Branch 2: Avo AI Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/avo',
                name: 'avo-chat',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const AvoChatScreen(),
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
        path: '/background-selection',
        name: 'background-selection',
        builder: (context, state) => const ListBackgroundSelectionScreen(),
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
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms-of-service',
        name: 'terms-of-service',
        builder: (context, state) => const TermsOfServiceScreen(),
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
      // Deep link route for shared lists (accessible without auth context)
      GoRoute(
        path: '/list/:listId',
        name: 'shared-list',
        builder: (context, state) {
          final listId = state.pathParameters['listId']!;
          final listName = state.uri.queryParameters['name'] ?? 'Shared List';
          return ListDetailScreen(listId: listId, listName: listName);
        },
      ),
      // Deep link route for list invites
      GoRoute(
        path: '/invite/:listId',
        name: 'list-invite',
        builder: (context, state) {
          final listId = state.pathParameters['listId']!;
          return ListDetailScreen(listId: listId, listName: 'Shared List');
        },
      ),
    ],
    redirect: (context, state) async {
      final isLoggedIn = SupabaseService.instance.currentUser != null;
      final uri = state.uri;

      // Convert shoply:// deep links to proper paths
      if (uri.scheme == 'shoply') {
        final host = uri.host; // e.g. 'recipe', 'list'
        final segments = uri.pathSegments;
        if (host == 'recipe' && segments.isNotEmpty)
          return '/recipe/${segments[0]}';
        if (host == 'list' && segments.isNotEmpty)
          return '/list/${segments[0]}';
        if (host == 'invite' && segments.isNotEmpty)
          return '/invite/${segments[0]}';
        if (host == 'author' && segments.isNotEmpty)
          return '/author/${segments[0]}';
        return '/home';
      }

      final location = state.matchedLocation;

      // Public routes that don't require authentication
      final isPublicRoute =
          location == '/onboarding' ||
          location == '/welcome' ||
          location == '/login' ||
          location == '/signup' ||
          location == '/reset-password' ||
          location == '/privacy-policy' ||
          location == '/terms-of-service' ||
          location.startsWith('/recipe/') ||
          location.startsWith('/list/') ||
          location.startsWith('/invite/');

      final isNamePrompt = location == '/name-prompt';
      final isNewNamePrompt = isNamePrompt && uri.queryParameters['new'] == '1';
      final isOnboarding = location == '/onboarding';

      // Check if onboarding has been completed (cached after first check)
      final onboardingDone = await hasCompletedOnboarding();

      // First-time user: show onboarding unless on a public deep link
      if (!onboardingDone && !isOnboarding && !isLoggedIn) {
        // Allow deep links and auth sub-routes through
        if (location.startsWith('/recipe/') ||
            location.startsWith('/list/') ||
            location.startsWith('/invite/') ||
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

      // Logged in - check if name prompt or setup is needed.
      // IMPORTANT: this must never block app entry when offline. We first try
      // a cached profile snapshot, then – only if online – a short-timeout
      // network query. If both fail we fall through and let the user into the
      // app (they will land on /home as if fully set up).
      if (isLoggedIn) {
        final user = SupabaseService.instance.currentUser;
        if (user != null) {
          bool gotProfile = false;

          // 1. Offline-safe cached profile
          final cached = await OfflineCacheService.instance
              .getCachedUserProfile(user.id);
          if (cached != null) {
            gotProfile = true;
          }

          // 2. Live refresh only when online – bounded so a flaky network
          //    can't hang the redirect.
          if (ConnectivityService.instance.isOnline) {
            try {
              final response = await SupabaseService.instance
                  .from('users')
                  .select('display_name, onboarding_completed')
                  .eq('id', user.id)
                  .maybeSingle()
                  .timeout(const Duration(milliseconds: 1500));

              if (response != null) {
                final liveDisplayName = response['display_name'] as String?;
                gotProfile = true;
                unawaited(
                  OfflineCacheService.instance.cacheUserProfile(
                    userId: user.id,
                    displayName: liveDisplayName,
                    onboardingCompleted:
                        response['onboarding_completed'] as bool?,
                  ),
                );
              }
            } catch (_) {
              // Network/timeout error – keep whatever we have from cache.
            }
          }

          if (gotProfile) {
            if (location == '/welcome' || isOnboarding) {
              return '/home';
            }
          } else {
            // No profile info at all: still bounce off passive entry screens.
            // Login/signup complete their own async success routing, so forcing
            // them here can race OTP verification and show a false error.
            if (location == '/welcome' || isOnboarding) {
              return '/home';
            }
          }
        }
      }

      return null;
    },
  );
});
