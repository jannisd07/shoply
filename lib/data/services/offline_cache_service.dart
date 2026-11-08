import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

/// Offline cache (recipes, shopping lists + items, user profile) in
/// SharedPreferences with in-memory mirrors for first-frame reads.
class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._();
  OfflineCacheService._();

  /// Every key this service writes starts with this prefix, so [clearCache]
  /// can wipe exactly its own entries and nothing else (recipe drafts,
  /// migration flags, ...). Not user-scoped: the cache is cleared on sign-out.
  static const String _prefix = 'offline_cache_v2_';
  static const String _cachedRecipesKey = '${_prefix}recipes';

  /// Keys written by older app versions before the prefix existed.
  static const List<String> _legacyKeys = [
    'cached_recipes',
    'cached_saved_recipe_ids',
    'last_cache_sync',
    'cached_lists',
  ];
  static const String _legacyListItemsPrefix = 'cached_list_items_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // =============================================
  // RECIPE CACHING
  // =============================================

  /// In-memory mirror of the recipe cache — see [_memoryItems] for why a
  /// synchronously readable copy is needed to avoid an empty first frame.
  List<Recipe>? _memoryRecipes;

  /// Cached recipes without awaiting, or null if not warmed yet.
  List<Recipe>? getCachedRecipesSync() => _memoryRecipes;

  /// Load the recipe cache into memory so [getCachedRecipesSync] succeeds.
  Future<void> warmRecipes() async {
    if (_memoryRecipes != null) return;
    final recipes = await getCachedRecipes();
    if (recipes.isNotEmpty) _memoryRecipes = recipes;
  }

  /// Cache a list of recipes
  Future<void> cacheRecipes(List<Recipe> recipes) async {
    _memoryRecipes = List.unmodifiable(recipes);
    try {
      final prefs = await _preferences;
      final recipesJson = recipes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_cachedRecipesKey, recipesJson);
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error caching recipes: $e');
    }
  }

  /// Get cached recipes
  Future<List<Recipe>> getCachedRecipes() async {
    final inMemory = _memoryRecipes;
    if (inMemory != null) return inMemory;
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

      _memoryRecipes = recipes;
      return recipes;
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error loading cached recipes: $e');
      return [];
    }
  }

  // =============================================
  // SHOPPING LISTS CACHING
  // =============================================

  static const String _cachedListsKey = '${_prefix}lists';

  /// The account the cached lists belong to.
  static const String _cachedListsUserKey = '${_prefix}lists_user';
  static const String _cachedListItemsPrefix = '${_prefix}list_items_';

  /// Cache a list of shopping lists, for [userId]'s account when given.
  Future<void> cacheLists(
    List<ShoppingListModel> lists, {
    String? userId,
  }) async {
    try {
      final prefs = await _preferences;
      final listsJson = lists.map((l) => jsonEncode(l.toJson())).toList();
      await prefs.setStringList(_cachedListsKey, listsJson);
      if (userId != null) {
        await prefs.setString(_cachedListsUserKey, userId);
      } else {
        await prefs.remove(_cachedListsUserKey);
      }
      debugPrint('✅ [OFFLINE] Cached ${lists.length} shopping lists');
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error caching shopping lists: $e');
    }
  }

  /// Get cached shopping lists. With [userId] only lists cached for that
  /// account (a cold start shows them at once, never another account's).
  Future<List<ShoppingListModel>?> getCachedLists({String? userId}) async {
    try {
      final prefs = await _preferences;
      if (userId != null && prefs.getString(_cachedListsUserKey) != userId) {
        return null;
      }
      final listsJson = prefs.getStringList(_cachedListsKey);

      if (listsJson == null || listsJson.isEmpty) {
        return null;
      }

      final lists = listsJson.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return ShoppingListModel.fromJson(map);
      }).toList();

      debugPrint('📦 [OFFLINE] Loaded ${lists.length} cached shopping lists');
      return lists;
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error loading cached shopping lists: $e');
      return null;
    }
  }

  /// In-memory mirror of the on-disk item cache.
  ///
  /// SharedPreferences is async, so a screen that only reads it can never
  /// paint data in its *first* frame — there is always at least one empty
  /// frame while the read completes, and that is exactly the hitch you see
  /// when opening a list. Holding the decoded items in memory as well lets
  /// [getCachedListItemsSync] answer during `build`, so the list renders
  /// populated immediately and the network result just reconciles afterwards.
  final Map<String, List<ShoppingItemModel>> _memoryItems = {};

  /// Cached items for [listId] without awaiting, or null if this list has
  /// not been warmed yet. Call [warmListItems] to populate.
  List<ShoppingItemModel>? getCachedListItemsSync(String listId) =>
      _memoryItems[listId];

  /// Load the on-disk cache for [listIds] into memory so subsequent
  /// [getCachedListItemsSync] calls succeed. Cheap and safe to call again.
  Future<void> warmListItems(Iterable<String> listIds) async {
    for (final id in listIds) {
      if (_memoryItems.containsKey(id)) continue;
      final items = await getCachedListItems(id);
      if (items != null) _memoryItems[id] = items;
    }
  }

  /// Cache items for a specific shopping list
  Future<void> cacheListItems(
    String listId,
    List<ShoppingItemModel> items,
  ) async {
    // Memory first and synchronously, so a navigation happening in the same
    // frame as a write already sees the new data.
    _memoryItems[listId] = List.unmodifiable(items);
    try {
      final prefs = await _preferences;
      final itemsJson = items.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList('$_cachedListItemsPrefix$listId', itemsJson);
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error caching list items: $e');
    }
  }

  /// Get cached items for a specific shopping list
  Future<List<ShoppingItemModel>?> getCachedListItems(String listId) async {
    final inMemory = _memoryItems[listId];
    if (inMemory != null) return inMemory;
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

      _memoryItems[listId] = items;
      return items;
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error loading cached list items: $e');
      return null;
    }
  }

  // =============================================
  // USER PROFILE CACHING (for offline app start)
  // =============================================

  // Kept on its pre-prefix key so the offline app start keeps working right
  // after an update; it is checked against the user id on read anyway.
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
      debugPrint('❌ [OFFLINE] Error caching user profile: $e');
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

  /// Clear all cached data. Must run on sign-out: the cache is not keyed by
  /// user, so otherwise the next account would see the previous one's lists.
  Future<void> clearCache() async {
    // Drop the in-memory mirrors too — nothing of the previous account may
    // survive in RAM either.
    _memoryItems.clear();
    _memoryRecipes = null;
    try {
      final prefs = await _preferences;
      final keys = prefs
          .getKeys()
          .where(
            (k) =>
                k.startsWith(_prefix) ||
                k.startsWith(_legacyListItemsPrefix) ||
                k == _cachedProfileKey ||
                _legacyKeys.contains(k),
          )
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      debugPrint('✅ [OFFLINE] Cache cleared');
    } catch (e) {
      debugPrint('❌ [OFFLINE] Error clearing cache: $e');
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
