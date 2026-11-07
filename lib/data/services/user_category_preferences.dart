import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Remembers the category a user picked by hand for a product, so the next
/// time the same product is classified their choice wins.
///
/// Stored per user in SharedPreferences (`user_category_prefs_v1_<userId>`),
/// so choices survive restarts and never leak between accounts on one device.
class UserCategoryPreferences {
  static final UserCategoryPreferences _instance = UserCategoryPreferences._();
  static UserCategoryPreferences get instance => _instance;

  UserCategoryPreferences._();

  static const String _prefsKeyPrefix = 'user_category_prefs_v1_';

  final SupabaseService _supabase = SupabaseService.instance;

  // In-memory mirror of the current user's stored preferences.
  final Map<String, String> _cache = {};
  String? _loadedForUserId;

  /// Learn a user's category preference for a product.
  /// Called when the user manually changes an item's category.
  Future<void> learnPreference(String productName, String category) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return;

    await _ensureLoaded(userId);
    _cache[normalizeProductName(productName)] = category;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsKeyPrefix$userId', jsonEncode(_cache));
    } catch (e) {
      debugPrint('⚠️ [CATEGORY_PREFS] Could not persist preference: $e');
    }
  }

  /// Get the user's preferred category for a product, or null if none.
  Future<String?> getPreference(String productName) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return null;

    await _ensureLoaded(userId);
    return _cache[normalizeProductName(productName)];
  }

  Future<void> _ensureLoaded(String userId) async {
    if (_loadedForUserId == userId) return;
    _cache.clear();
    _loadedForUserId = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsKeyPrefix$userId');
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        if (value is String) _cache[key] = value;
      });
    } catch (e) {
      debugPrint('⚠️ [CATEGORY_PREFS] Could not load preferences: $e');
    }
  }

  /// Drop the in-memory copy (call on sign-out).
  void clearCache() {
    _cache.clear();
    _loadedForUserId = null;
  }

  /// Get statistics about learned preferences
  Map<String, dynamic> getStatistics() {
    return {
      'total_preferences': _cache.length,
      'cache_loaded': _loadedForUserId != null,
    };
  }
}
