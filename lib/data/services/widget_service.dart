import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing home screen widgets
class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.shoply.widget');
  static const String _shoppingListKey = 'widget_shopping_list';
  static const String _savedRecipesKey = 'widget_saved_recipes';

  // ============================================
  // SHOPPING LIST WIDGET
  // ============================================

  /// Update shopping list widget with items (per-list + legacy key)
  static Future<void> updateShoppingListWidget({
    required String listId,
    required String listName,
    required List<WidgetItem> items,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      final data = {
        'listId': listId,
        'listName': listName,
        'items': items.map((item) => item.toJson()).toList(),
        'itemCount': items.length,
        'checkedCount': items.where((i) => i.isChecked).length,
        'uncheckedCount': items.where((i) => !i.isChecked).length,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Notify native side — it saves both per-list key and legacy key
      await _channel.invokeMethod('updateShoppingListWidget', data);
      debugPrint('✅ [Widget] Updated shopping list widget with ${items.length} items for list $listId');
    } catch (e) {
      debugPrint('⚠️ [Widget] Shopping list update failed: $e');
    }
  }

  /// Save available lists to App Group so widget can offer list selection
  static Future<void> updateAvailableLists(List<Map<String, String>> lists) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('updateAvailableLists', {'lists': lists});
      debugPrint('✅ [Widget] Updated available lists: ${lists.length}');
    } catch (e) {
      debugPrint('⚠️ [Widget] Update available lists failed: $e');
    }
  }

  /// Save the user's most frequently bought items so the Quick-Add widget
  /// can offer one-tap "add to list" suggestions without opening the app.
  static Future<void> updateRecentItems(List<WidgetRecentItem> items) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('updateRecentItems', {
        'items': items.map((item) => item.toJson()).toList(),
      });
      debugPrint('✅ [Widget] Updated recent items: ${items.length}');
    } catch (e) {
      debugPrint('⚠️ [Widget] Update recent items failed: $e');
    }
  }

  /// Save Supabase credentials to App Group so widget can sync toggles directly
  /// and insert quick-added items directly (userId is required for the
  /// `added_by` column on a direct insert from the widget process).
  static Future<void> updateSupabaseCredentials({
    required String url,
    required String anonKey,
    required String accessToken,
    String? userId,
  }) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('updateSupabaseCredentials', {
        'url': url,
        'anonKey': anonKey,
        'accessToken': accessToken,
        if (userId != null) 'userId': userId,
      });
      debugPrint('✅ [Widget] Updated Supabase credentials');
    } catch (e) {
      debugPrint('⚠️ [Widget] Update Supabase credentials failed: $e');
    }
  }

  /// Get current shopping list widget data
  static Future<Map<String, dynamic>?> getShoppingListWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_shoppingListKey);
      if (data != null) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [Widget] Failed to get shopping list data: $e');
    }
    return null;
  }

  // ============================================
  // SAVED RECIPES WIDGET
  // ============================================

  /// Update saved recipes widget
  static Future<void> updateSavedRecipesWidget({
    required List<WidgetRecipe> recipes,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'recipes': recipes.map((r) => r.toJson()).toList(),
        'recipeCount': recipes.length,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_savedRecipesKey, jsonEncode(data));

      // Notify native widget to refresh
      await _channel.invokeMethod('updateSavedRecipesWidget', data);
      debugPrint('✅ [Widget] Updated saved recipes widget with ${recipes.length} recipes');
    } catch (e) {
      debugPrint('⚠️ [Widget] Saved recipes update failed: $e');
    }
  }

  // ============================================
  // LEGACY METHODS (backward compatibility)
  // ============================================

  /// Update widget with shopping list data (legacy)
  static Future<void> updateWidget({
    required String listName,
    required List<WidgetItem> items,
  }) async {
    await updateShoppingListWidget(
      listId: 'default',
      listName: listName,
      items: items,
    );
  }

  /// Clear all widget data
  static Future<void> clearWidget() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shoppingListKey);
      await prefs.remove(_savedRecipesKey);

      await _channel.invokeMethod('clearWidget');
      debugPrint('✅ [Widget] Cleared all widget data');
    } catch (e) {
      debugPrint('⚠️ [Widget] Clear failed: $e');
    }
  }

  /// Check if widgets are supported
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// Force refresh all widgets
  static Future<void> refreshAllWidgets() async {
    try {
      await _channel.invokeMethod('refreshAllWidgets');
      debugPrint('✅ [Widget] Refreshed all widgets');
    } catch (e) {
      debugPrint('⚠️ [Widget] Refresh failed: $e');
    }
  }
}

class WidgetItem {
  final String id;
  final String name;
  final int quantity;
  final bool isChecked;

  WidgetItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isChecked,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'isChecked': isChecked,
  };

  factory WidgetItem.fromJson(Map<String, dynamic> json) => WidgetItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as int,
    isChecked: json['isChecked'] as bool,
  );
}

/// A frequently-bought item offered as a one-tap suggestion in the
/// Quick-Add widget. `name` is display-ready (title-cased), `category` is
/// the language-agnostic category id (e.g. `'dairy'`) used elsewhere in the
/// app, so a quick-added item categorizes the same way a manually typed one
/// would.
class WidgetRecentItem {
  final String name;
  final String? category;
  final double quantity;

  WidgetRecentItem({
    required this.name,
    this.category,
    this.quantity = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'quantity': quantity,
  };
}

/// Recipe data for widget display
class WidgetRecipe {
  final String id;
  final String name;
  final String? imageUrl;
  final int? cookTime;
  final double? rating;

  WidgetRecipe({
    required this.id,
    required this.name,
    this.imageUrl,
    this.cookTime,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'cookTime': cookTime,
    'rating': rating,
  };

  factory WidgetRecipe.fromJson(Map<String, dynamic> json) => WidgetRecipe(
    id: json['id'] as String,
    name: json['name'] as String,
    imageUrl: json['imageUrl'] as String?,
    cookTime: json['cookTime'] as int?,
    rating: (json['rating'] as num?)?.toDouble(),
  );
}
