import 'dart:async';
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
    _router!.push(uri.toString());
    debugPrint('✅ [NAVIGATION] Navigated to list activities: $listId');
  }

  /// Navigate to list detail screen
  void navigateToList(String listId, {String? listName}) {
    if (_router == null) {
      debugPrint('⚠️ [NAVIGATION] Router not set');
      return;
    }

    final name = listName ?? 'Shopping List';
    final uri = Uri(path: '/lists/$listId', queryParameters: {'name': name});
    _router!.push(uri.toString());
    debugPrint('✅ [NAVIGATION] Navigated to list: $listId');
  }

  /// Navigate to recipe detail screen
  void navigateToRecipe(String recipeId) {
    if (_router == null) {
      debugPrint('⚠️ [NAVIGATION] Router not set');
      return;
    }

    unawaited(_router!.push('/recipes/$recipeId'));
    debugPrint('✅ [NAVIGATION] Navigated to recipe: $recipeId');
  }

  /// Route a tapped notification (local or FCM) by its data payload.
  void handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final listId = data['listId'] as String?;
    final listName = data['listName'] as String?;
    // 'recipe_id' is what older app versions sent for rating pushes.
    final recipeId = (data['recipeId'] ?? data['recipe_id']) as String?;

    debugPrint('🔔 [NAVIGATION] Notification tapped: $type');

    switch (type) {
      case 'list_activity':
      case 'category_change':
        if (listId != null) {
          navigateToListActivities(listId, listName: listName);
        }
      case 'list_update':
      case 'list_invitation':
        if (listId != null) navigateToList(listId, listName: listName);
      case 'recipe_rating':
      case 'recipe_like':
      case 'recipe_comment':
        if (recipeId != null) navigateToRecipe(recipeId);
      case 'avo_restock':
        // Opening the app is enough — the home screen shows the restock
        // card with add/dismiss actions.
        break;
      default:
        debugPrint('⚠️ [NAVIGATION] Unknown notification type: $type');
        if (listId != null) navigateToList(listId, listName: listName);
    }
  }

  /// Navigate to diet preferences.
  void navigateToDietPreferences() {
    if (_router == null) {
      debugPrint('⚠️ [NAVIGATION] Router not set');
      return;
    }

    unawaited(_router!.push('/diet-preferences'));
    debugPrint('✅ [NAVIGATION] Navigated to diet preferences');
  }
}
