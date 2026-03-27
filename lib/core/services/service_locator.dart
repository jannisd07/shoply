import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
// import 'package:shoply/data/services/recipe_rating_service.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/data/services/ai_ingredient_analyzer.dart';
import 'package:shoply/data/services/gemini_categorization_service.dart';
import 'package:shoply/data/services/analytics_service.dart';

/// Central service registry for the entire application.
/// 
/// This provides a single source of truth for accessing all services,
/// making it easier to manage dependencies and improve testability.
/// 
/// Usage:
/// ```dart
/// // Instead of:
/// final _supabase = Supabase.instance.client;
/// 
/// // Use:
/// Services.supabase.client;
/// Services.recipes.createRecipe(...);
/// ```
class Services {
  // Singleton instance
  static final Services _instance = Services._internal();
  factory Services() => _instance;
  Services._internal();
  
  // Core Services
  static SupabaseService get supabase => SupabaseService.instance;
  
  // Recipe Services
  static RecipeService get recipes => RecipeService.instance;
  // static RecipeRatingService get recipeRatings => RecipeRatingService.instance;
  
  // Shopping List Services
  static ListRepository get lists => ListRepository.instance;
  static ItemRepository get items => ItemRepository.instance;
  
  // User & Auth Services
  static UserService get users => UserService.instance;
  
  // AI Services
  static AIIngredientAnalyzer get aiIngredients => AIIngredientAnalyzer.instance;
  static GeminiCategorizationService get aiCategorization => GeminiCategorizationService.instance;
  
  // Utility Services
  static AnalyticsService get analytics => AnalyticsService.instance;
  
  /// Initialize all services that require setup
  static Future<void> initialize() async {
    // Initialize services that need async setup
    await SupabaseService.initialize();
  }
  
  /// Reset all services (useful for testing or logout)
  static void reset() {
    // Reset singleton instances if needed
  }
}
