import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

// The person and their recipes (S5, S10, S14): profile, allergies, the
// profile writer, the recipe loader.

// ── The person ──────────────────────────────────────────────────────────

/// The signed-in person's profile (allergies, age, sex, height); override in
/// tests.
final calorieUserProfileProvider = FutureProvider.autoDispose<UserModel?>(
  (ref) => ref.watch(currentUserProvider.future),
);

/// The person's allergies as the matcher reads them (S5).
final calorieAllergiesProvider = Provider.autoDispose<AllergenMatcher>((ref) {
  final user = ref.watch(calorieUserProfileProvider).valueOrNull;
  return AllergenMatcher(user?.allergies ?? const []);
});

typedef CalorieProfileWriter = Future<void> Function({required int age, required double heightCm, required String gender});

/// Keeps age, height and sex in the profile after "Übernehmen" (S14). Best
/// effort: the goal itself goes through the write queue.
final calorieProfileWriterProvider = Provider<CalorieProfileWriter>((ref) {
  return ({required int age, required double heightCm, required String gender}) async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null) return;
    // Only these four columns: a full row from a cached profile would write
    // back stale values (push token, allergies, language).
    await SupabaseService.instance.client.from('users').update({
      'age': age,
      'height': heightCm,
      'height_unit': 'cm',
      'gender': gender,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    ref.invalidate(currentUserProvider);
  };
});

// ── Recipes (S10) ───────────────────────────────────────────────────────

/// Loads a recipe for `/calories/add/recipe/:recipeId` without an `extra`
/// (deep link); override in tests.
final calorieRecipeLoaderProvider = Provider<Future<Recipe> Function(String id)>(
  (ref) => RecipeService.instance.getRecipeById,
);

/// Allergies of [allergies] that [estimate] likely contains: the types the
/// server named plus the keywords of the dish and its parts (compounds
/// too), each once.
List<AllergenMatch> estimateAllergyMatches(
  AllergenMatcher allergies, {
  required String dish,
  required Iterable<String> components,
  required Iterable<AllergyType> named,
}) {
  final found = <AllergenMatch>[
    ...allergies.matchesAll([dish, ...components]),
  ];
  for (final raw in allergies.allergies) {
    final type = AllergenMatcher.resolve(raw);
    if (type == null || !named.contains(type)) continue;
    if (found.any((m) => m.type == type || m.allergy == raw)) continue;
    found.add(AllergenMatch(allergy: raw, type: type, matchedText: type.name));
  }
  final seen = <String>{};
  return [for (final m in found) if (seen.add(m.type?.name ?? m.allergy)) m];
}
