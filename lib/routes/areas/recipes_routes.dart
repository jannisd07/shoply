import 'package:go_router/go_router.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/all_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/category_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/creators_screen.dart';
import 'package:shoply/presentation/screens/recipes/multi_step_recipe_screen.dart';
import 'package:shoply/presentation/screens/recipes/my_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_author_page.dart';
import 'package:shoply/presentation/screens/recipes/recipe_detail_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_drafts_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/saved_recipes_screen.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/route_paths.dart';

/// Routes of the Rezepte tab branch (Teil A).
final List<RouteBase> recipesBranchRoutes = [
  GoRoute(
    path: RoutePaths.recipes,
    name: 'recipes',
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: RecipesScreen(initialQuery: state.uri.queryParameters['q']),
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
          final extra = state.extra;
          return RecipeDetailScreen(
            recipeId: recipeId,
            initialRecipe: extra is Recipe ? extra : null,
          );
        },
        // Teil B: e.g. 'to-plan' ("Anderes Datum …" for the Wochenplan).
        routes: planRecipeRoutes,
      ),
    ],
  ),
  // Wochenplan segment of the Rezepte tab. Its push screens (Teil B) are
  // children of this route.
  GoRoute(
    path: RoutePaths.plan,
    name: 'plan',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const RecipesScreen()),
    routes: planChildRoutes,
  ),
];

/// Recipe routes outside the tab bar (Teil A): creator pages and the shared
/// recipe deep link.
final List<RouteBase> recipesRoutes = [
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
  // Deep link route for shared recipes (accessible without auth context)
  GoRoute(
    path: '/recipe/:recipeId',
    name: 'shared-recipe',
    builder: (context, state) {
      final recipeId = state.pathParameters['recipeId']!;
      final extra = state.extra;
      return RecipeDetailScreen(
        recipeId: recipeId,
        initialRecipe: extra is Recipe ? extra : null,
      );
    },
  ),
];
