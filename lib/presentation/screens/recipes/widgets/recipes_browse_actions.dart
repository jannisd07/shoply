import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/routes/route_paths.dart';

/// Query parameter that asks the recipe detail to start "Zutaten auf die
/// Liste" (`/recipes/<id>?action=to-list`); the detail reads it.
const String kRecipeActionParam = 'action';
const String kRecipeActionToList = 'to-list';

/// Opens a recipe (inside the Rezepte tab).
void openBrowseRecipe(BuildContext context, Recipe recipe) =>
    context.push(RoutePaths.recipe(recipe.id), extra: recipe);

/// "Zutaten auf die Liste": opens the detail, which starts that action.
void openRecipeToList(BuildContext context, Recipe recipe) => context.push(
  Uri(
    path: RoutePaths.recipe(recipe.id),
    queryParameters: {kRecipeActionParam: kRecipeActionToList},
  ).toString(),
  extra: recipe,
);

/// The recipe editor (`/recipes/add`).
void openRecipeEditor(BuildContext context) =>
    context.push('${RoutePaths.recipes}/add');

/// A category page; [filter] and [sort] preset its chips and order.
void openRecipeCategory(
  BuildContext context,
  String categoryId, {
  RecipeListFilter? filter,
  RecipeSort? sort,
}) => context.push(
  Uri(
    path: '${RoutePaths.recipes}/category/$categoryId',
    queryParameters: _query(filter, sort),
  ).toString(),
);

/// "Alle Rezepte"; [filter] and [sort] preset its chips and order.
void openAllRecipes(
  BuildContext context, {
  RecipeListFilter? filter,
  RecipeSort? sort,
}) => context.push(
  Uri(
    path: '${RoutePaths.recipes}/all',
    queryParameters: _query(filter, sort),
  ).toString(),
);

Map<String, String>? _query(RecipeListFilter? filter, RecipeSort? sort) {
  final q = {'filter': ?filter?.id, 'sort': ?sort?.id};
  return q.isEmpty ? null : q;
}

/// The long-press menu of a recipe card (Konzept 13 §3.4): save or unsave
/// (no toast: the bookmark state is the feedback), "Zutaten auf die Liste".
void showRecipeCardMenu(BuildContext anchor, WidgetRef ref, Recipe recipe) {
  final saved = ref.read(isRecipeSavedProvider(recipe.id));
  showAvoMenu(
    anchor,
    semanticLabel: recipe.name,
    items: [
      AvoMenuItem(
        label: anchor.tr(saved ? 'recipe_browse_unsave' : 'recipe_browse_save'),
        icon: AvoIcons.bookmark,
        onSelected: () =>
            ref.read(savedRecipesProvider.notifier).toggleSave(recipe.id),
      ),
      AvoMenuItem(
        label: anchor.tr('recipe_browse_to_list'),
        icon: AvoIcons.plus,
        onSelected: () => openRecipeToList(anchor, recipe),
      ),
    ],
  );
}
