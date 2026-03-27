import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/app_review_service.dart';

/// State for saved recipes
class SavedRecipesState {
  final Set<String> savedIds;
  final List<Recipe> savedRecipes;
  final bool isLoading;

  const SavedRecipesState({
    this.savedIds = const {},
    this.savedRecipes = const [],
    this.isLoading = false,
  });

  SavedRecipesState copyWith({
    Set<String>? savedIds,
    List<Recipe>? savedRecipes,
    bool? isLoading,
  }) {
    return SavedRecipesState(
      savedIds: savedIds ?? this.savedIds,
      savedRecipes: savedRecipes ?? this.savedRecipes,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isSaved(String recipeId) => savedIds.contains(recipeId);
}

/// Notifier for managing saved recipes state
class SavedRecipesNotifier extends StateNotifier<SavedRecipesState> {
  final RecipeService _recipeService;

  SavedRecipesNotifier(this._recipeService) : super(const SavedRecipesState()) {
    loadSavedRecipes();
  }

  /// Load saved recipe IDs and full recipes
  Future<void> loadSavedRecipes() async {
    print('🔄 [SAVED_RECIPES_PROVIDER] loadSavedRecipes called');
    state = state.copyWith(isLoading: true);
    
    try {
      final ids = await _recipeService.getSavedRecipeIds();
      print('📋 [SAVED_RECIPES_PROVIDER] Got ${ids.length} saved IDs: $ids');
      
      final recipes = await _recipeService.getSavedRecipes();
      print('📚 [SAVED_RECIPES_PROVIDER] Got ${recipes.length} saved recipes');
      
      state = state.copyWith(
        savedIds: ids,
        savedRecipes: recipes,
        isLoading: false,
      );
      print('✅ [SAVED_RECIPES_PROVIDER] State updated - savedIds: ${state.savedIds.length}, savedRecipes: ${state.savedRecipes.length}');
    } catch (e, stackTrace) {
      print('❌ [SAVED_RECIPES_PROVIDER] Error loading saved recipes: $e');
      print('❌ [SAVED_RECIPES_PROVIDER] Stack: $stackTrace');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle save status for a recipe
  Future<bool> toggleSave(String recipeId) async {
    final isSaved = state.savedIds.contains(recipeId);
    
    // Optimistic update
    final newIds = Set<String>.from(state.savedIds);
    if (isSaved) {
      newIds.remove(recipeId);
    } else {
      newIds.add(recipeId);
    }
    state = state.copyWith(savedIds: newIds);

    try {
      bool success;
      if (isSaved) {
        success = await _recipeService.unsaveRecipe(recipeId);
      } else {
        success = await _recipeService.saveRecipe(recipeId);
      }

      if (!success) {
        // Revert on failure
        final revertIds = Set<String>.from(state.savedIds);
        if (isSaved) {
          revertIds.add(recipeId);
        } else {
          revertIds.remove(recipeId);
        }
        state = state.copyWith(savedIds: revertIds);
      } else {
        // Reload full list to update recipes
        await loadSavedRecipes();
        
        // Track positive action for app review (saving a recipe)
        if (!isSaved) {
          // Only track when saving, not when unsaving
          await AppReviewService.instance.trackPositiveAction('saved_recipe');
          // Maybe request review after positive moment
          await AppReviewService.instance.maybeRequestReview(reason: 'saved_recipe');
        }
      }

      return success;
    } catch (e) {
      // Revert on error
      final revertIds = Set<String>.from(state.savedIds);
      if (isSaved) {
        revertIds.add(recipeId);
      } else {
        revertIds.remove(recipeId);
      }
      state = state.copyWith(savedIds: revertIds);
      return false;
    }
  }

  /// Check if a recipe is saved
  bool isSaved(String recipeId) => state.savedIds.contains(recipeId);
}

/// Provider for saved recipes
final savedRecipesProvider = 
    StateNotifierProvider<SavedRecipesNotifier, SavedRecipesState>((ref) {
  return SavedRecipesNotifier(RecipeService());
});

/// Simple provider to check if a specific recipe is saved
final isRecipeSavedProvider = Provider.family<bool, String>((ref, recipeId) {
  return ref.watch(savedRecipesProvider).isSaved(recipeId);
});
