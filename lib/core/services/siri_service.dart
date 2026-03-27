import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SiriService {
  static const _channel = MethodChannel('com.shoply.app/siri');
  static SiriService? _instance;
  
  factory SiriService() {
    _instance ??= SiriService._internal();
    return _instance!;
  }
  
  SiriService._internal();
  
  /// Initialize Siri integration
  Future<void> initialize() async {
    try {
      // Set up method call handler for Siri callbacks
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Sync current lists with iOS
      await syncListsWithSiri();
      
    } catch (e) {
    }
  }
  
  /// Handle method calls from iOS
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'addItemToList':
        return await _handleAddItem(call.arguments);
      case 'createList':
        return await _handleCreateList(call.arguments);
      case 'getLists':
        return await _getLists();
      case 'searchRecipes':
        return await _handleSearchRecipes(call.arguments);
      case 'showSavedRecipes':
        return await _handleShowSavedRecipes();
      case 'openSection':
        return await _handleOpenSection(call.arguments);
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }
  
  /// Handle add item from Siri
  Future<Map<String, dynamic>> _handleAddItem(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments as Map);
      
      final itemName = data['itemName'] as String;
      final listName = data['listName'] as String?;
      final quantity = data['quantity'] as double? ?? 1.0;
      final category = data['category'] as String?;
      
      
      // Store in shared preferences for the app to pick up
      final prefs = await SharedPreferences.getInstance();
      final pendingItems = prefs.getStringList('siri_pending_items') ?? [];
      
      final item = jsonEncode({
        'itemName': itemName,
        'listName': listName ?? 'Einkaufsliste',
        'quantity': quantity,
        'category': category,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      pendingItems.add(item);
      await prefs.setStringList('siri_pending_items', pendingItems);
      
      return {
        'success': true,
        'message': '$itemName wurde hinzugefügt',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Handle create list from Siri
  Future<Map<String, dynamic>> _handleCreateList(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments as Map);
      final listName = data['name'] as String;
      
      
      final prefs = await SharedPreferences.getInstance();
      final pendingLists = prefs.getStringList('siri_pending_lists') ?? [];
      
      final list = jsonEncode({
        'name': listName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      pendingLists.add(list);
      await prefs.setStringList('siri_pending_lists', pendingLists);
      
      return {
        'success': true,
        'message': 'Liste "$listName" wurde erstellt',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get all lists
  Future<List<String>> _getLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('user_lists') ?? ['Einkaufsliste', 'Wocheneinkauf'];
    } catch (e) {
      return ['Einkaufsliste'];
    }
  }
  
  /// Sync lists with Siri (for autocomplete)
  Future<void> syncListsWithSiri() async {
    try {
      final lists = await _getLists();
      await _channel.invokeMethod('syncLists', {'lists': lists});
    } catch (e) {
    }
  }
  
  /// Update user lists in shared preferences
  Future<void> updateUserLists(List<String> lists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_lists', lists);
      await syncListsWithSiri();
    } catch (e) {
    }
  }
  
  /// Get pending items from Siri
  Future<List<Map<String, dynamic>>> getPendingItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingItems = prefs.getStringList('siri_pending_items') ?? [];
      
      final items = pendingItems.map((item) {
        return Map<String, dynamic>.from(jsonDecode(item) as Map);
      }).toList();
      
      // Clear pending items
      await prefs.remove('siri_pending_items');
      
      return items;
    } catch (e) {
      return [];
    }
  }
  
  /// Get pending lists from Siri
  Future<List<Map<String, dynamic>>> getPendingLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingLists = prefs.getStringList('siri_pending_lists') ?? [];
      
      final lists = pendingLists.map((list) {
        return Map<String, dynamic>.from(jsonDecode(list) as Map);
      }).toList();
      
      // Clear pending lists
      await prefs.remove('siri_pending_lists');
      
      return lists;
    } catch (e) {
      return [];
    }
  }
  
  /// Donate interaction to Siri (for better predictions)
  Future<void> donateAddItemInteraction({
    required String itemName,
    required String listName,
  }) async {
    try {
      await _channel.invokeMethod('donateInteraction', {
        'type': 'addItem',
        'itemName': itemName,
        'listName': listName,
      });
    } catch (e) {
    }
  }
  
  /// Handle search recipes from Siri
  Future<Map<String, dynamic>> _handleSearchRecipes(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments as Map);
      final query = data['query'] as String? ?? '';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('siri_search_query', query);
      await prefs.setString('siri_action', 'searchRecipes');
      await prefs.setInt('siri_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      return {
        'success': true,
        'message': 'Searching recipes for "$query"',
        'action': 'searchRecipes',
        'query': query,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Handle show saved recipes from Siri
  Future<Map<String, dynamic>> _handleShowSavedRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('siri_action', 'showSavedRecipes');
      await prefs.setInt('siri_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      return {
        'success': true,
        'message': 'Opening saved recipes',
        'action': 'showSavedRecipes',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Handle open section from Siri
  Future<Map<String, dynamic>> _handleOpenSection(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments as Map);
      final section = data['section'] as String? ?? 'home';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('siri_action', 'openSection');
      await prefs.setString('siri_section', section);
      await prefs.setInt('siri_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      String message;
      switch (section.toLowerCase()) {
        case 'recipes':
        case 'rezepte':
          message = 'Opening recipes';
          break;
        case 'lists':
        case 'listen':
          message = 'Opening shopping lists';
          break;
        case 'saved':
        case 'gespeichert':
          message = 'Opening saved recipes';
          break;
        default:
          message = 'Opening Shoply';
      }
      
      return {
        'success': true,
        'message': message,
        'action': 'openSection',
        'section': section,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get pending Siri action (for app to process when opened)
  Future<Map<String, dynamic>?> getPendingSiriAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final action = prefs.getString('siri_action');
      final timestamp = prefs.getInt('siri_timestamp') ?? 0;
      
      // Only return action if it's recent (within 30 seconds)
      if (action == null || 
          DateTime.now().millisecondsSinceEpoch - timestamp > 30000) {
        return null;
      }
      
      final result = <String, dynamic>{
        'action': action,
      };
      
      switch (action) {
        case 'searchRecipes':
          result['query'] = prefs.getString('siri_search_query') ?? '';
          break;
        case 'openSection':
          result['section'] = prefs.getString('siri_section') ?? 'home';
          break;
      }
      
      // Clear the action after reading
      await prefs.remove('siri_action');
      await prefs.remove('siri_timestamp');
      await prefs.remove('siri_search_query');
      await prefs.remove('siri_section');
      
      return result;
    } catch (e) {
      return null;
    }
  }
  
  /// Donate recipe search interaction
  Future<void> donateRecipeSearchInteraction(String query) async {
    try {
      await _channel.invokeMethod('donateInteraction', {
        'type': 'searchRecipes',
        'query': query,
      });
    } catch (e) {
    }
  }
  
  /// Donate view saved recipes interaction
  Future<void> donateSavedRecipesInteraction() async {
    try {
      await _channel.invokeMethod('donateInteraction', {
        'type': 'showSavedRecipes',
      });
    } catch (e) {
    }
  }
}
