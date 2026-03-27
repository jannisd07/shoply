import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for tracking user behavior and app usage
/// Uses Firebase Analytics (Google Analytics 4 for mobile)
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;
  
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  bool _isEnabled = true;

  /// Initialize Firebase Analytics
  Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      
      // Set analytics collection enabled
      await _analytics!.setAnalyticsCollectionEnabled(_isEnabled);
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver? get observer => _observer;

  /// Enable or disable analytics collection
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _analytics?.setAnalyticsCollectionEnabled(enabled);
  }

  /// Check if analytics is enabled
  bool get isEnabled => _isEnabled;

  // ============================================================
  // USER PROPERTIES
  // ============================================================

  /// Set user ID (typically Supabase user UUID)
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics?.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) print('Error setting user ID: $e');
    }
  }

  /// Set user properties
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      if (kDebugMode) print('Error setting user property: $e');
    }
  }

  /// Set theme preference
  Future<void> setThemePreference(String theme) async {
    await setUserProperty(name: 'theme_preference', value: theme);
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    await setUserProperty(name: 'language', value: language);
  }

  // ============================================================
  // SCREEN TRACKING (Auto-tracked by observer, but can be manual too)
  // ============================================================

  /// Manually log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      if (kDebugMode) print('Error logging screen view: $e');
    }
  }

  // ============================================================
  // RECIPE EVENTS
  // ============================================================

  /// Log recipe viewed
  Future<void> logRecipeViewed({
    required String recipeId,
    required String recipeName,
    List<String>? labels,
  }) async {
    await _logEvent(
      name: 'recipe_viewed',
      parameters: {
        'recipe_id': recipeId,
        'recipe_name': recipeName,
        if (labels != null) 'labels': labels.join(','),
      },
    );
  }

  /// Log recipe created
  Future<void> logRecipeCreated({
    required String recipeId,
    required String recipeName,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
  }) async {
    await _logEvent(
      name: 'recipe_created',
      parameters: {
        'recipe_id': recipeId,
        'recipe_name': recipeName,
        if (prepTimeMinutes != null) 'prep_time': prepTimeMinutes,
        if (cookTimeMinutes != null) 'cook_time': cookTimeMinutes,
      },
    );
  }

  /// Log recipe shared
  Future<void> logRecipeShared({
    required String recipeId,
    required String recipeName,
    required String method, // 'link', 'whatsapp', 'email', etc.
  }) async {
    await _logEvent(
      name: 'recipe_shared',
      parameters: {
        'recipe_id': recipeId,
        'recipe_name': recipeName,
        'share_method': method,
      },
    );
  }

  /// Log recipe liked
  Future<void> logRecipeLiked({
    required String recipeId,
    required String recipeName,
  }) async {
    await _logEvent(
      name: 'recipe_liked',
      parameters: {
        'recipe_id': recipeId,
        'recipe_name': recipeName,
      },
    );
  }

  /// Log recipe filter applied
  Future<void> logRecipeFilterApplied({
    required List<String> filters,
    int? resultCount,
  }) async {
    await _logEvent(
      name: 'recipe_filter_applied',
      parameters: {
        'filters': filters.join(','),
        'filter_count': filters.length,
        if (resultCount != null) 'result_count': resultCount,
      },
    );
  }

  /// Log recipe search
  Future<void> logRecipeSearch({
    required String query,
    int? resultCount,
  }) async {
    await _logEvent(
      name: 'recipe_search',
      parameters: {
        'search_query': query,
        if (resultCount != null) 'result_count': resultCount,
      },
    );
  }

  // ============================================================
  // SHOPPING LIST EVENTS
  // ============================================================

  /// Log shopping list created
  Future<void> logShoppingListCreated({
    required String listId,
    required String listName,
    int? itemCount,
  }) async {
    await _logEvent(
      name: 'shopping_list_created',
      parameters: {
        'list_id': listId,
        'list_name': listName,
        if (itemCount != null) 'item_count': itemCount,
      },
    );
  }

  /// Log shopping list shared
  Future<void> logShoppingListShared({
    required String listId,
    required String method, // 'link', 'qr', 'whatsapp', etc.
  }) async {
    await _logEvent(
      name: 'shopping_list_shared',
      parameters: {
        'list_id': listId,
        'share_method': method,
      },
    );
  }

  /// Log item added to shopping list
  Future<void> logShoppingItemAdded({
    required String listId,
    required String itemName,
    String? category,
  }) async {
    await _logEvent(
      name: 'shopping_item_added',
      parameters: {
        'list_id': listId,
        'item_name': itemName,
        if (category != null) 'category': category,
      },
    );
  }

  /// Log item checked off
  Future<void> logShoppingItemChecked({
    required String listId,
    required String itemName,
    required bool isChecked,
  }) async {
    await _logEvent(
      name: 'shopping_item_checked',
      parameters: {
        'list_id': listId,
        'item_name': itemName,
        'is_checked': isChecked,
      },
    );
  }

  // ============================================================
  // AI FEATURES EVENTS
  // ============================================================

  /// Log AI dashboard viewed
  Future<void> logAIDashboardViewed() async {
    await _logEvent(name: 'ai_dashboard_viewed');
  }

  /// Log nutrition score viewed
  Future<void> logNutritionScoreViewed({
    required int score,
  }) async {
    await _logEvent(
      name: 'nutrition_score_viewed',
      parameters: {'score': score},
    );
  }

  /// Log meal planning feature used
  Future<void> logMealPlanningUsed() async {
    await _logEvent(name: 'meal_planning_used');
  }

  /// Log ML recommendations viewed
  Future<void> logMLRecommendationsViewed({
    required int count,
  }) async {
    await _logEvent(
      name: 'ml_recommendations_viewed',
      parameters: {'recommendation_count': count},
    );
  }

  /// Log ML recommendation clicked
  Future<void> logMLRecommendationClicked({
    required String itemName,
  }) async {
    await _logEvent(
      name: 'ml_recommendation_clicked',
      parameters: {'item_name': itemName},
    );
  }

  // ============================================================
  // ADMIN/DEVELOPER EVENTS
  // ============================================================

  /// Log developer tools accessed
  Future<void> logDeveloperToolsAccessed() async {
    await _logEvent(name: 'developer_tools_accessed');
  }

  /// Log batch labeling run
  Future<void> logBatchLabelingRun({
    required int totalRecipes,
    required int processed,
    required int skipped,
    required int errors,
    required bool dryRun,
    required bool forceRelabel,
  }) async {
    await _logEvent(
      name: 'batch_labeling_run',
      parameters: {
        'total_recipes': totalRecipes,
        'processed': processed,
        'skipped': skipped,
        'errors': errors,
        'dry_run': dryRun,
        'force_relabel': forceRelabel,
      },
    );
  }

  // ============================================================
  // AUTHENTICATION EVENTS
  // ============================================================

  /// Log user sign up
  Future<void> logSignUp({required String method}) async {
    await _analytics?.logSignUp(signUpMethod: method);
  }

  /// Log user login
  Future<void> logLogin({required String method}) async {
    await _analytics?.logLogin(loginMethod: method);
  }

  /// Log user logout
  Future<void> logLogout() async {
    await _logEvent(name: 'logout');
  }

  // ============================================================
  // ERROR TRACKING
  // ============================================================

  /// Log app error
  Future<void> logError({
    required String errorMessage,
    String? stackTrace,
    String? context,
  }) async {
    await _logEvent(
      name: 'app_error',
      parameters: {
        'error_message': errorMessage,
        if (stackTrace != null) 'stack_trace': stackTrace,
        if (context != null) 'context': context,
      },
    );
  }

  // ============================================================
  // GENERIC EVENT LOGGING
  // ============================================================

  /// Log custom event
  Future<void> _logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isEnabled) return;
    
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }
}
