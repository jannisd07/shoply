import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

/// Service for caching recipes offline
class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._();
  OfflineCacheService._();

  static const String _cachedRecipesKey = 'cached_recipes';
  static const String _cachedSavedRecipeIdsKey = 'cached_saved_recipe_ids';
  static const String _lastSyncKey = 'last_cache_sync';
  static const Duration _cacheExpiry = Duration(hours: 24);

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // =============================================
  // RECIPE CACHING
  // =============================================

  /// Cache a list of recipes
  Future<void> cacheRecipes(List<Recipe> recipes) async {
    try {
      final prefs = await _preferences;
      final recipesJson = recipes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_cachedRecipesKey, recipesJson);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      print('✅ [OFFLINE] Cached ${recipes.length} recipes');
    } catch (e) {
      print('❌ [OFFLINE] Error caching recipes: $e');
    }
  }

  /// Get cached recipes
  Future<List<Recipe>> getCachedRecipes() async {
    try {
      final prefs = await _preferences;
      final recipesJson = prefs.getStringList(_cachedRecipesKey);
      
      if (recipesJson == null || recipesJson.isEmpty) {
        return [];
      }

      final recipes = recipesJson.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return Recipe.fromJson(map);
      }).toList();

      print('📦 [OFFLINE] Loaded ${recipes.length} cached recipes');
      return recipes;
    } catch (e) {
      print('❌ [OFFLINE] Error loading cached recipes: $e');
      return [];
    }
  }

  /// Cache a single recipe (for viewed recipes)
  Future<void> cacheRecipe(Recipe recipe) async {
    try {
      final prefs = await _preferences;
      final key = 'recipe_${recipe.id}';
      await prefs.setString(key, jsonEncode(recipe.toJson()));
      print('✅ [OFFLINE] Cached recipe: ${recipe.name}');
    } catch (e) {
      print('❌ [OFFLINE] Error caching recipe: $e');
    }
  }

  /// Get a single cached recipe by ID
  Future<Recipe?> getCachedRecipe(String recipeId) async {
    try {
      final prefs = await _preferences;
      final key = 'recipe_$recipeId';
      final json = prefs.getString(key);
      
      if (json == null) return null;

      final map = jsonDecode(json) as Map<String, dynamic>;
      return Recipe.fromJson(map);
    } catch (e) {
      print('❌ [OFFLINE] Error loading cached recipe: $e');
      return null;
    }
  }

  // =============================================
  // SAVED RECIPES CACHING
  // =============================================

  /// Cache saved recipe IDs
  Future<void> cacheSavedRecipeIds(Set<String> ids) async {
    try {
      final prefs = await _preferences;
      await prefs.setStringList(_cachedSavedRecipeIdsKey, ids.toList());
      print('✅ [OFFLINE] Cached ${ids.length} saved recipe IDs');
    } catch (e) {
      print('❌ [OFFLINE] Error caching saved recipe IDs: $e');
    }
  }

  /// Get cached saved recipe IDs
  Future<Set<String>> getCachedSavedRecipeIds() async {
    try {
      final prefs = await _preferences;
      final ids = prefs.getStringList(_cachedSavedRecipeIdsKey);
      return ids?.toSet() ?? {};
    } catch (e) {
      return {};
    }
  }

  // =============================================
  // SHOPPING LISTS CACHING
  // =============================================

  static const String _cachedListsKey = 'cached_lists';
  static const String _cachedListItemsPrefix = 'cached_list_items_';

  /// Cache a list of shopping lists
  Future<void> cacheLists(List<ShoppingListModel> lists) async {
    try {
      final prefs = await _preferences;
      final listsJson = lists.map((l) => jsonEncode(l.toJson())).toList();
      await prefs.setStringList(_cachedListsKey, listsJson);
      print('✅ [OFFLINE] Cached ${lists.length} shopping lists');
    } catch (e) {
      print('❌ [OFFLINE] Error caching shopping lists: $e');
    }
  }

  /// Get cached shopping lists
  Future<List<ShoppingListModel>?> getCachedLists() async {
    try {
      final prefs = await _preferences;
      final listsJson = prefs.getStringList(_cachedListsKey);

      if (listsJson == null || listsJson.isEmpty) {
        return null;
      }

      final lists = listsJson.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return ShoppingListModel.fromJson(map);
      }).toList();

      print('📦 [OFFLINE] Loaded ${lists.length} cached shopping lists');
      return lists;
    } catch (e) {
      print('❌ [OFFLINE] Error loading cached shopping lists: $e');
      return null;
    }
  }

  /// Cache items for a specific shopping list
  Future<void> cacheListItems(String listId, List<ShoppingItemModel> items) async {
    try {
      final prefs = await _preferences;
      final itemsJson = items.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList('$_cachedListItemsPrefix$listId', itemsJson);
      print('✅ [OFFLINE] Cached ${items.length} items for list $listId');
    } catch (e) {
      print('❌ [OFFLINE] Error caching list items: $e');
    }
  }

  /// Get cached items for a specific shopping list
  Future<List<ShoppingItemModel>?> getCachedListItems(String listId) async {
    try {
      final prefs = await _preferences;
      final itemsJson = prefs.getStringList('$_cachedListItemsPrefix$listId');

      if (itemsJson == null || itemsJson.isEmpty) {
        return null;
      }

      final items = itemsJson.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return ShoppingItemModel.fromJson(map);
      }).toList();

      print('📦 [OFFLINE] Loaded ${items.length} cached items for list $listId');
      return items;
    } catch (e) {
      print('❌ [OFFLINE] Error loading cached list items: $e');
      return null;
    }
  }

  // =============================================
  // USER PROFILE CACHING (for offline app start)
  // =============================================

  static const String _cachedProfileKey = 'cached_user_profile';

  /// Cache the current user's profile fields needed for the router redirect.
  /// Keyed by user id so a device with account switching stays consistent.
  Future<void> cacheUserProfile({
    required String userId,
    String? displayName,
    bool? onboardingCompleted,
  }) async {
    try {
      final prefs = await _preferences;
      final payload = jsonEncode({
        'user_id': userId,
        'display_name': displayName,
        'onboarding_completed': onboardingCompleted,
        'cached_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_cachedProfileKey, payload);
    } catch (e) {
      print('❌ [OFFLINE] Error caching user profile: $e');
    }
  }

  /// Read the cached profile for the given user. Returns null if nothing is
  /// cached or the cache is for a different user.
  Future<CachedUserProfile?> getCachedUserProfile(String userId) async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(_cachedProfileKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['user_id'] != userId) return null;
      return CachedUserProfile(
        userId: userId,
        displayName: map['display_name'] as String?,
        onboardingCompleted: map['onboarding_completed'] as bool?,
      );
    } catch (e) {
      return null;
    }
  }

  // =============================================
  // CACHE MANAGEMENT
  // =============================================

  /// Check if cache is expired
  Future<bool> isCacheExpired() async {
    try {
      final prefs = await _preferences;
      final lastSyncStr = prefs.getString(_lastSyncKey);
      
      if (lastSyncStr == null) return true;

      final lastSync = DateTime.parse(lastSyncStr);
      return DateTime.now().difference(lastSync) > _cacheExpiry;
    } catch (e) {
      return true;
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await _preferences;
      final lastSyncStr = prefs.getString(_lastSyncKey);
      if (lastSyncStr == null) return null;
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys().where((k) =>
        k.startsWith('cached_') ||
        k.startsWith('recipe_') ||
        k.startsWith(_cachedListItemsPrefix) ||
        k == _lastSyncKey
      ).toList();
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      print('✅ [OFFLINE] Cache cleared');
    } catch (e) {
      print('❌ [OFFLINE] Error clearing cache: $e');
    }
  }

  /// Get cache size info
  Future<CacheInfo> getCacheInfo() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys().where((k) => 
        k.startsWith('cached_') || 
        k.startsWith('recipe_')
      ).toList();
      
      int totalSize = 0;
      int recipeCount = 0;
      
      for (final key in keys) {
        if (key.startsWith('recipe_')) {
          recipeCount++;
        }
        final value = prefs.getString(key) ?? prefs.getStringList(key)?.join() ?? '';
        totalSize += value.length;
      }

      return CacheInfo(
        recipeCount: recipeCount,
        sizeBytes: totalSize,
        lastSync: await getLastSyncTime(),
        isExpired: await isCacheExpired(),
      );
    } catch (e) {
      return CacheInfo(recipeCount: 0, sizeBytes: 0, lastSync: null, isExpired: true);
    }
  }
}

/// Minimal user profile snapshot used by the router redirect when offline,
/// so app entry never depends on a live Supabase query.
class CachedUserProfile {
  final String userId;
  final String? displayName;
  final bool? onboardingCompleted;

  const CachedUserProfile({
    required this.userId,
    required this.displayName,
    required this.onboardingCompleted,
  });
}

/// Information about the cache
class CacheInfo {
  final int recipeCount;
  final int sizeBytes;
  final DateTime? lastSync;
  final bool isExpired;

  const CacheInfo({
    required this.recipeCount,
    required this.sizeBytes,
    required this.lastSync,
    required this.isExpired,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
