import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/recipe_auto_labeler.dart';
import 'package:shoply/data/services/recipe_draft_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/recipe_draft_images.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Everything the recipe editor needs from the server, in one place so
/// tests can replace it.
abstract interface class RecipeEditorBackend {
  /// The published recipe to edit.
  Future<Recipe> load(String recipeId);

  /// Uploads a photo; returns its public URL.
  Future<String> uploadPhoto(File file);

  /// Publishes a new recipe; returns its id.
  Future<String> create(Recipe recipe, {required String difficulty});

  /// Saves changes to a published recipe.
  Future<void> update(Recipe recipe);
}

/// [RecipeEditorBackend] through [RecipeService] (Supabase).
class ServiceRecipeEditorBackend implements RecipeEditorBackend {
  const ServiceRecipeEditorBackend();

  @override
  Future<Recipe> load(String recipeId) =>
      RecipeService().getRecipeById(recipeId);

  @override
  Future<String> uploadPhoto(File file) => RecipeService().uploadRecipeImage(
    file.path,
    'recipe_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );

  @override
  Future<String> create(Recipe recipe, {required String difficulty}) async {
    // `createRecipe` only labels automatically without labels of its own;
    // keep the automatic ones and add the chosen difficulty.
    final labels = {
      ...autoLabelRecipe(
        name: recipe.name,
        description: recipe.description,
        ingredients: recipe.ingredients.map((i) => i.toJson()).toList(),
        prepTime: recipe.prepTimeMinutes,
        cookTime: recipe.cookTimeMinutes,
      ),
      difficulty,
    }.toList();
    final created = await RecipeService().createRecipe(
      recipe.copyWith(labels: labels),
    );
    return created.id;
  }

  @override
  Future<void> update(Recipe recipe) => RecipeService().updateRecipe(
    recipe.id,
    name: recipe.name,
    description: recipe.description,
    imageUrl: recipe.imageUrl,
    prepTimeMinutes: recipe.prepTimeMinutes,
    cookTimeMinutes: recipe.cookTimeMinutes,
    defaultServings: recipe.defaultServings,
    ingredients: recipe.ingredients,
    instructions: recipe.instructions,
  );
}

/// How the editor talks to the server; overridden in tests.
final recipeEditorBackendProvider = Provider<RecipeEditorBackend>(
  (ref) => const ServiceRecipeEditorBackend(),
);

/// Drafts on this device and their photos.
abstract interface class RecipeEditorDrafts {
  Future<RecipeDraft?> get(String id);
  Future<void> save(RecipeDraft draft);
  Future<void> delete(String id);

  /// Copies [file] into the drafts folder; returns the stored path.
  Future<String> keepPhoto(String draftId, File file);

  /// The stored photo, or null when it is gone.
  Future<File?> photo(String? path);
  Future<void> deletePhoto(String? path);
}

/// [RecipeEditorDrafts] through [RecipeDraftService] and
/// [RecipeDraftImages] (the existing draft storage).
class LocalRecipeEditorDrafts implements RecipeEditorDrafts {
  LocalRecipeEditorDrafts();

  final _service = RecipeDraftService();

  @override
  Future<RecipeDraft?> get(String id) => _service.getDraft(id);

  @override
  Future<void> save(RecipeDraft draft) async {
    await _service.saveDraft(draft);
  }

  @override
  Future<void> delete(String id) => _service.deleteDraft(id);

  @override
  Future<String> keepPhoto(String draftId, File file) =>
      RecipeDraftImages.persist(draftId, file);

  @override
  Future<File?> photo(String? path) => RecipeDraftImages.resolve(path);

  @override
  Future<void> deletePhoto(String? path) => RecipeDraftImages.delete(path);
}

/// The draft storage of the editor; overridden in tests.
final recipeEditorDraftsProvider = Provider<RecipeEditorDrafts>(
  (ref) => LocalRecipeEditorDrafts(),
);

/// Where a photo comes from.
enum RecipePhotoSource { camera, library }

/// Picks a photo (up to 2,400 px, Konzept 13 §17.3); overridden in tests.
final recipeEditorPhotoPickerProvider =
    Provider<Future<File?> Function(RecipePhotoSource source)>(
      (ref) => (source) async {
        final picked = await ImagePicker().pickImage(
          source: source == RecipePhotoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 85,
        );
        return picked == null ? null : File(picked.path);
      },
    );

/// The name a published recipe shows ("Jannis D."), or null when the
/// account has none: then the editor asks for one instead of publishing
/// the email address.
final recipeEditorAuthorNameProvider = Provider<String?>((ref) {
  String? clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  final cached = clean(ref.watch(cachedUserProfileProvider)?.displayName);
  if (cached != null) return cached;
  final user = ref.watch(currentUserProvider);
  if (user.hasError) debugPrint('⚠️ [RECIPE_EDITOR] Profile not loaded');
  return clean(user.valueOrNull?.displayName);
});
