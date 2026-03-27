import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/recipe_labeling_service.dart';
import 'package:shoply/data/services/ai_recipe_labeling_service.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Utility for batch labeling existing recipes in the database
/// Run this once after deploying the recipe labeling system
/// NOW WITH REAL AI LABELING! 🤖
class RecipeBatchLabelingUtility {
  final RecipeService _recipeService = RecipeService();
  final RecipeLabelingService _labelingService = RecipeLabelingService.instance;
  final AIRecipeLabelingService _aiLabelingService = AIRecipeLabelingService();

  /// Batch label all recipes in the database WITH AI
  Future<BatchLabelingResult> labelAllRecipes({
    bool dryRun = false,
    bool forceRelabel = false,
    bool useAI = true, // NEU: Toggle für KI-Labeling
    Function(String)? onProgress,
  }) async {
    onProgress?.call('🏷️ Starting batch labeling process...');
    onProgress?.call('🔧 Configuration: dryRun=$dryRun, forceRelabel=$forceRelabel, useAI=$useAI');
    
    if (useAI) {
      onProgress?.call('🤖 AI-MODUS AKTIVIERT: Verwendet echte KI (Gemini AI) für intelligentes Labeling');
    } else {
      onProgress?.call('📋 Regel-basiertes Labeling (alte Methode)');
    }
    
    final result = BatchLabelingResult();
    
    try {
      // Fetch all recipes FROM DATABASE ONLY (no sample recipes)
      onProgress?.call('📥 Fetching recipes from database...');
      onProgress?.call('⏳ This may take a moment...');
      
      final recipes = await _recipeService.getDatabaseRecipesOnly();
      result.totalRecipes = recipes.length;
      
      onProgress?.call('✅ Fetch complete!');
      onProgress?.call('📊 Found ${recipes.length} recipes in database');
      
      if (recipes.isEmpty) {
        onProgress?.call('');
        onProgress?.call('⚠️ No recipes found in database!');
        onProgress?.call('💡 Tip: Create some recipes first in the Recipes tab');
        onProgress?.call('💡 Sample recipes are NOT in the database');
        onProgress?.call('');
        onProgress?.call('🔍 To verify: Check Supabase → recipes table');
        return result;
      }
      
      onProgress?.call('');
      onProgress?.call('🔄 Starting to process ${recipes.length} recipes...');

      // Process each recipe
      for (int i = 0; i < recipes.length; i++) {
        final recipe = recipes[i];
        final progress = ((i + 1) / recipes.length * 100).toStringAsFixed(1);
        
        try {
          // Check if recipe already has labels
          if (recipe.labels.isNotEmpty && !forceRelabel) {
            onProgress?.call('[$progress%] ⏭️  Skipping "${recipe.name}" (has ${recipe.labels.length} labels, force=$forceRelabel)');
            result.skipped++;
            continue;
          }

          // Generate labels
          onProgress?.call('[$progress%] 🔍 Analyzing "${recipe.name}"...');
          
          List<String> labels;
          if (useAI) {
            // KI-MODUS: Echte KI-Analyse mit Gemini AI
            onProgress?.call('[$progress%] 🤖 KI analysiert Rezept...');
            labels = await _aiLabelingService.labelRecipeWithAI(recipe);
            
            if (labels.isEmpty) {
              onProgress?.call('[$progress%] ⚠️  KI lieferte keine Labels, verwende Fallback');
              labels = _labelingService.labelRecipe(recipe);
            }
          } else {
            // REGEL-MODUS: Alte regelbasierte Methode
            labels = _labelingService.labelRecipe(recipe);
          }
          
          onProgress?.call('[$progress%] 🏷️  Generated ${labels.length} labels: ${labels.join(", ")}');
          
          if (dryRun) {
            onProgress?.call('[$progress%] 🔸 DRY RUN - Would save to database');
            result.processed++;
          } else {
            // Update in database
            onProgress?.call('[$progress%] 💾 Saving to database...');
            await _updateRecipeLabels(recipe.id, labels);
            onProgress?.call('[$progress%] ✅ Saved "${recipe.name}"');
            result.processed++;
          }
        } catch (e) {
          onProgress?.call('[$progress%] ❌ Error with "${recipe.name}": $e');
          result.errors++;
          result.errorDetails.add('${recipe.name}: $e');
        }
      }

      onProgress?.call('');
      onProgress?.call('✅ Batch labeling complete!');
      onProgress?.call('📊 Results:');
      onProgress?.call('   Total: ${result.totalRecipes}');
      onProgress?.call('   Processed: ${result.processed}');
      onProgress?.call('   Skipped: ${result.skipped}');
      onProgress?.call('   Errors: ${result.errors}');
      
      if (dryRun) {
        onProgress?.call('');
        onProgress?.call('⚠️ This was a DRY RUN - no changes were made');
        onProgress?.call('Run with dryRun: false to apply changes');
      }

      return result;
    } catch (e) {
      onProgress?.call('❌ Fatal error during batch labeling: $e');
      result.errors++;
      result.errorDetails.add('Fatal error: $e');
      return result;
    }
  }

  /// Update recipe labels in database
  Future<void> _updateRecipeLabels(String recipeId, List<String> labels) async {
    await SupabaseService.instance
        .from('recipes')
        .update({'labels': labels})
        .eq('id', recipeId);
  }

  /// Label recipes that match specific criteria
  Future<BatchLabelingResult> labelRecipesWhere({
    String? authorId,
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool forceRelabel = false,
    bool dryRun = false,
    Function(String)? onProgress,
  }) async {
    onProgress?.call('🏷️ Starting selective batch labeling...');
    
    final result = BatchLabelingResult();
    
    try {
      // Build query
      var query = SupabaseService.instance.from('recipes').select();
      
      if (authorId != null) {
        query = query.eq('author_id', authorId);
      }
      if (createdAfter != null) {
        query = query.gte('created_at', createdAfter.toIso8601String());
      }
      if (createdBefore != null) {
        query = query.lte('created_at', createdBefore.toIso8601String());
      }

      final data = await query;
      final recipes = (data as List).map((json) => Recipe.fromJson(json)).toList();
      
      result.totalRecipes = recipes.length;
      onProgress?.call('Found ${recipes.length} recipes matching criteria');

      // Process each recipe
      for (int i = 0; i < recipes.length; i++) {
        final recipe = recipes[i];
        final progress = ((i + 1) / recipes.length * 100).toStringAsFixed(1);
        
        try {
          // Check if should skip
          if (recipe.labels.isNotEmpty && !forceRelabel) {
            onProgress?.call('[$progress%] Skipping "${recipe.name}" (already labeled)');
            result.skipped++;
            continue;
          }

          // Generate labels
          final labels = _labelingService.labelRecipe(recipe);
          
          if (dryRun) {
            onProgress?.call('[$progress%] DRY RUN - Would label "${recipe.name}": ${labels.join(", ")}');
            result.processed++;
          } else {
            await _updateRecipeLabels(recipe.id, labels);
            onProgress?.call('[$progress%] ✅ Labeled "${recipe.name}": ${labels.join(", ")}');
            result.processed++;
          }
        } catch (e) {
          onProgress?.call('[$progress%] ❌ Error: $e');
          result.errors++;
          result.errorDetails.add('${recipe.name}: $e');
        }
      }

      onProgress?.call('');
      onProgress?.call('✅ Selective labeling complete!');
      onProgress?.call('📊 Results:');
      onProgress?.call('   Total: ${result.totalRecipes}');
      onProgress?.call('   Processed: ${result.processed}');
      onProgress?.call('   Skipped: ${result.skipped}');
      onProgress?.call('   Errors: ${result.errors}');

      return result;
    } catch (e) {
      onProgress?.call('❌ Error: $e');
      result.errors++;
      result.errorDetails.add('Fatal error: $e');
      return result;
    }
  }

  /// Re-label a single recipe (useful for testing)
  Future<void> labelSingleRecipe(String recipeId) async {
    try {
      // Fetch recipe
      final data = await SupabaseService.instance
          .from('recipes')
          .select()
          .eq('id', recipeId)
          .single();
      
      final recipe = Recipe.fromJson(data);
      
      // Generate labels
      final labels = _labelingService.labelRecipe(recipe);
      
      // Update
      await _updateRecipeLabels(recipeId, labels);
      
    } catch (e) {
      rethrow;
    }
  }

  /// Get statistics about current labeling state
  Future<LabelingStats> getStats() async {
    try {
      final recipes = await _recipeService.getRecipes();
      final stats = LabelingStats();
      
      stats.totalRecipes = recipes.length;
      stats.labeledRecipes = recipes.where((r) => r.labels.isNotEmpty).length;
      stats.unlabeledRecipes = recipes.where((r) => r.labels.isEmpty).length;
      
      // Count label frequencies
      for (final recipe in recipes) {
        for (final label in recipe.labels) {
          stats.labelCounts[label] = (stats.labelCounts[label] ?? 0) + 1;
        }
      }
      
      return stats;
    } catch (e) {
      rethrow;
    }
  }
}

/// Result of batch labeling operation
class BatchLabelingResult {
  int totalRecipes = 0;
  int processed = 0;
  int skipped = 0;
  int errors = 0;
  List<String> errorDetails = [];

  bool get hasErrors => errors > 0;
  bool get isComplete => processed + skipped + errors == totalRecipes;
  double get successRate => totalRecipes > 0 ? (processed / totalRecipes) * 100 : 0;
}

/// Statistics about recipe labeling
class LabelingStats {
  int totalRecipes = 0;
  int labeledRecipes = 0;
  int unlabeledRecipes = 0;
  Map<String, int> labelCounts = {};

  double get labeledPercentage => totalRecipes > 0 ? (labeledRecipes / totalRecipes) * 100 : 0;
  
  List<MapEntry<String, int>> get topLabels {
    final entries = labelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList();
  }
}
