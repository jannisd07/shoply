import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Global navigation service for handling notification taps.
/// 
/// Since notifications can be tapped when the app is in background or terminated,
/// we need a way to navigate without direct access to BuildContext.
class NavigationService {
  static NavigationService? _instance;
  static NavigationService get instance {
    _instance ??= NavigationService._();
    return _instance!;
  }
  
  NavigationService._();
  
  GoRouter? _router;
  
  /// Set the router instance (call this in app.dart after router is created)
  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('🔵 [NAVIGATION] Router set');
  }
  
  /// Navigate to list activities screen
  void navigateToListActivities(String listId, {String? listName}) {
    if (_router == null) {
      debugPrint('⚠️ [NAVIGATION] Router not set');
      return;
    }
    
    final name = listName ?? 'Shopping List';
    final uri = Uri(
      path: '/lists/$listId/activities',
      queryParameters: {'name': name},
    );
    _router!.go(uri.toString());
    debugPrint('✅ [NAVIGATION] Navigated to list activities: $listId');
  }
  
  /// Navigate to list detail screen
  void navigateToList(String listId, {String? listName}) {
    if (_router == null) {
      debugPrint('⚠️ [NAVIGATION] Router not set');
      return;
    }
    
    final name = listName ?? 'Shopping List';
    final uri = Uri(
      path: '/lists/$listId',
      queryParameters: {'name': name},
    );
    _router!.go(uri.toString());
    debugPrint('✅ [NAVIGATION] Navigated to list: $listId');
  }
  
  /// Navigate to recipe detail screen
  void navigateToRecipe(String recipeId) {
    if (_router == null) {
      debugPrint('⚠️ [NAVIGATION] Router not set');
      return;
    }
    
    _router!.go('/recipes/$recipeId');
    debugPrint('✅ [NAVIGATION] Navigated to recipe: $recipeId');
  }
}
