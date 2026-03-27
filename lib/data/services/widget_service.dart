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
  
  /// Update shopping list widget with items
  static Future<void> updateShoppingListWidget({
    required String listId,
    required String listName,
    required List<WidgetItem> items,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    
    try {
      // Save to SharedPreferences for widget to read
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'listId': listId,
        'listName': listName,
        'items': items.map((item) => item.toJson()).toList(),
        'itemCount': items.length,
        'checkedCount': items.where((i) => i.isChecked).length,
        'uncheckedCount': items.where((i) => !i.isChecked).length,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_shoppingListKey, jsonEncode(data));
      
      // Notify native widget to refresh
      await _channel.invokeMethod('updateShoppingListWidget', data);
      debugPrint('✅ [Widget] Updated shopping list widget with ${items.length} items');
    } catch (e) {
      debugPrint('⚠️ [Widget] Shopping list update failed: $e');
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
