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
import 'package:shoply/presentation/screens/recipes/add_recipe_screen.dart';
import 'package:shoply/presentation/screens/recipes/multi_step_recipe_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_author_page.dart';
import 'package:shoply/presentation/screens/recipes/saved_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/my_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/category_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/creators_screen.dart';
import 'package:shoply/presentation/screens/recipes/all_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_drafts_screen.dart';
import 'package:shoply/presentation/screens/profile/profile_screen.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/list_background_selection_screen.dart';
import 'package:shoply/presentation/screens/lists/list_background_picker_screen.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/screens/onboarding/unified_setup_screen.dart';
import 'package:shoply/presentation/screens/legal/privacy_policy_screen.dart';
import 'package:shoply/presentation/screens/legal/terms_of_service_screen.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import 'package:shoply/presentation/screens/auth/login_screen.dart';
import 'package:shoply/presentation/screens/auth/signup_screen.dart'; 
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/name_prompt_screen.dart';
import 'package:shoply/core/utils/display_name_helper.dart';

/// Helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (AuthState _) {
        notifyListeners();
      },
    );
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
    initialLocation: '/welcome',
    refreshListenable: GoRouterRefreshStream(supabase.authStateChanges),
    observers: observers,
    routes: [
      // Welcome / Auth Entry (new ChatGPT-style)
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
      
      // Main app with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
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
              final listName = state.uri.queryParameters['name'] ?? 'Shopping List';
              return CupertinoPage(
                key: state.pageKey,
                child: ListDetailScreen(
                  listId: listId,
                  listName: listName,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'activities',
                name: 'list-activities',
                builder: (context, state) {
                  final listId = state.pathParameters['listId']!;
                  final listName = state.uri.queryParameters['name'] ?? 'Shopping List';
                  return ListActivitiesScreen(
                    listId: listId,
                    listName: listName,
                  );
                },
              ),
            ],
          ),
          // Avo AI Chat
          GoRoute(
            path: '/avo',
            name: 'avo-chat',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AvoChatScreen(),
            ),
          ),
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
                  return MultiStepRecipeScreen(draftId: draftId, recipeId: recipeId);
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
                builder: (context, state) => const AllRecipesScreen(popularOnly: true),
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
      // Separate routes outside ShellRoute (no bottom nav)
      GoRoute(
        path: '/author/:authorId',
        name: 'author-profile',
        builder: (context, state) {
          final authorId = state.pathParameters['authorId']!;
          final authorName = state.extra != null && state.extra is Map
              ? (state.extra as Map)['authorName'] as String?
              : null;
          return RecipeAuthorPage(
            authorId: authorId,
            authorName: authorName,
          );
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
      final location = state.matchedLocation;
      
      // Public routes that don't require authentication
      final isPublicRoute = location == '/welcome' || 
                           location == '/login' ||
                           location == '/signup' ||
                           location == '/reset-password' ||
                           location == '/privacy-policy' ||
                           location == '/terms-of-service' ||
                           location.startsWith('/recipe/') ||
                           location.startsWith('/list/') ||
                           location.startsWith('/invite/');
      
      final isSetup = location == '/setup';
      final isNamePrompt = location == '/name-prompt';
      
      // Not logged in - redirect to welcome screen only if trying to access private route
      if (!isLoggedIn && !isPublicRoute) {
        return '/welcome';
      }

      // Allow access to reset password page if we are there (e.g. via deep link + listener)
      if (location == '/reset-password') {
        return null;
      }
      
      // Logged in - check if name prompt or setup is needed
      if (isLoggedIn) {
        try {
          final user = SupabaseService.instance.currentUser;
          if (user != null) {
            final response = await SupabaseService.instance
                .from('users')
                .select('display_name, onboarding_completed')
                .eq('id', user.id)
                .maybeSingle();
            
            final displayName = response?['display_name'] as String?;
            final needsName = DisplayNameHelper.needsNamePrompt(displayName);
            
            // If user needs to set their name, redirect to name prompt
            if (needsName && !isNamePrompt && !isSetup) {
              return '/name-prompt';
            }
            
            // If name is set and trying to access auth routes, go to home
            if (!needsName && 
               (location == '/welcome' || location == '/login' || location == '/signup' || isNamePrompt)) {
              return '/home';
            }
          }
        } catch (e) {
          // On error, allow navigation to continue
        }
      }
      
      return null;
    },
  );
});
