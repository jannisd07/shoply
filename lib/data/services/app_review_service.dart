import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for requesting App Store/Play Store reviews using native APIs.
/// Uses SKStoreReviewController on iOS (Apple's official API).
/// 
/// **AI: Critical Constraints**:
/// - ⚠️ Apple limits review prompts to 3 per 365 days per user per app version
/// - ⚠️ Never show after negative experiences (errors, crashes, deleted items)
/// - ⚠️ Only show after positive actions (completing lists, saving recipes)
/// 
/// **Psychology-based timing strategy**:
/// 1. Wait for user to have several positive sessions
/// 2. Trigger after positive moments (completing shopping, saving recipe)
/// 3. Never interrupt user flow - wait for natural pauses
/// 4. Track actions to ensure user is engaged and happy
class AppReviewService {
  static final AppReviewService instance = AppReviewService._();
  AppReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  // Storage keys
  static const String _keyAppOpenCount = 'app_review_open_count';
  static const String _keyPositiveActions = 'app_review_positive_actions';
  static const String _keyLastReviewPrompt = 'app_review_last_prompt';
  static const String _keyReviewPromptCount = 'app_review_prompt_count';
  static const String _keyFirstOpenDate = 'app_review_first_open';
  static const String _keyHasRated = 'app_review_has_rated';

  // Thresholds for showing review prompt
  static const int _minAppOpens = 5;  // User must open app at least 5 times
  static const int _minPositiveActions = 3;  // At least 3 positive actions
  static const int _minDaysInstalled = 3;  // At least 3 days since first open
  static const int _daysBetweenPrompts = 90;  // 90 days between prompts (Apple allows 3/year)
  
  /// Track app open - call on app start
  Future<void> trackAppOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Track first open date
      if (!prefs.containsKey(_keyFirstOpenDate)) {
        await prefs.setString(_keyFirstOpenDate, DateTime.now().toIso8601String());
      }
      
      // Increment open count
      final currentCount = prefs.getInt(_keyAppOpenCount) ?? 0;
      await prefs.setInt(_keyAppOpenCount, currentCount + 1);
      
      debugPrint('⭐ [APP_REVIEW] App opened ${currentCount + 1} times');
    } catch (e) {
      debugPrint('❌ [APP_REVIEW] Error tracking app open: $e');
    }
  }

  /// Track positive user action
  /// Call after: completing a shopping list, saving a recipe, adding to favorites
  Future<void> trackPositiveAction(String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_keyPositiveActions) ?? 0;
      await prefs.setInt(_keyPositiveActions, currentCount + 1);
      debugPrint('✅ [APP_REVIEW] Positive action: $action (total: ${currentCount + 1})');
    } catch (e) {
      debugPrint('❌ [APP_REVIEW] Error tracking positive action: $e');
    }
  }

  /// Request a review after a positive moment
  /// Call after positive actions like completing shopping or saving recipes
  Future<void> maybeRequestReview({String? reason}) async {
    try {
      // Only on mobile platforms (iOS/Android)
      if (!Platform.isIOS && !Platform.isAndroid) {
        debugPrint('⏭️ [APP_REVIEW] Not mobile platform, skipping');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Check if user indicated they've rated
      if (prefs.getBool(_keyHasRated) == true) {
        debugPrint('⏭️ [APP_REVIEW] User already indicated they rated');
        return;
      }

      // Check all conditions
      final conditions = await _checkConditions(prefs);
      if (!conditions.shouldShow) {
        debugPrint('⏭️ [APP_REVIEW] Conditions not met: ${conditions.reason}');
        return;
      }

      // Check if in-app review is available
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        debugPrint('⏭️ [APP_REVIEW] In-app review not available');
        return;
      }

      // Show the native review prompt
      debugPrint('⭐ [APP_REVIEW] Requesting review! Reason: ${reason ?? 'positive moment'}');
      await _inAppReview.requestReview();

      // Update tracking
      await prefs.setString(_keyLastReviewPrompt, DateTime.now().toIso8601String());
      final promptCount = prefs.getInt(_keyReviewPromptCount) ?? 0;
      await prefs.setInt(_keyReviewPromptCount, promptCount + 1);
      
      debugPrint('✅ [APP_REVIEW] Review requested successfully (prompt #${promptCount + 1})');
    } catch (e) {
      debugPrint('❌ [APP_REVIEW] Error requesting review: $e');
    }
  }

  /// Check all conditions for showing review prompt
  Future<_ReviewConditions> _checkConditions(SharedPreferences prefs) async {
    // 1. Check app open count
    final openCount = prefs.getInt(_keyAppOpenCount) ?? 0;
    if (openCount < _minAppOpens) {
      return _ReviewConditions(
        shouldShow: false,
        reason: 'App opened only $openCount times (need $_minAppOpens)',
      );
    }

    // 2. Check positive actions
    final positiveActions = prefs.getInt(_keyPositiveActions) ?? 0;
    if (positiveActions < _minPositiveActions) {
      return _ReviewConditions(
        shouldShow: false,
        reason: 'Only $positiveActions positive actions (need $_minPositiveActions)',
      );
    }

    // 3. Check days since first open
    final firstOpenStr = prefs.getString(_keyFirstOpenDate);
    if (firstOpenStr != null) {
      final firstOpen = DateTime.parse(firstOpenStr);
      final daysSinceInstall = DateTime.now().difference(firstOpen).inDays;
      if (daysSinceInstall < _minDaysInstalled) {
        return _ReviewConditions(
          shouldShow: false,
          reason: 'Installed only $daysSinceInstall days ago (need $_minDaysInstalled)',
        );
      }
    }

    // 4. Check time since last prompt
    final lastPromptStr = prefs.getString(_keyLastReviewPrompt);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.parse(lastPromptStr);
      final daysSincePrompt = DateTime.now().difference(lastPrompt).inDays;
      if (daysSincePrompt < _daysBetweenPrompts) {
        return _ReviewConditions(
          shouldShow: false,
          reason: 'Last prompt was $daysSincePrompt days ago (need $_daysBetweenPrompts)',
        );
      }
    }

    // 5. Check total prompt count (Apple allows 3 per year per version)
    final promptCount = prefs.getInt(_keyReviewPromptCount) ?? 0;
    if (promptCount >= 3) {
      return _ReviewConditions(
        shouldShow: false,
        reason: 'Already prompted $promptCount times this version',
      );
    }

    return _ReviewConditions(shouldShow: true, reason: 'All conditions met!');
  }

  /// Mark that user indicated they rated (e.g., via "Don't show again" button)
  Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
    debugPrint('✅ [APP_REVIEW] User marked as having rated');
  }

  /// Reset review tracking (for debugging)
  Future<void> resetTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAppOpenCount);
    await prefs.remove(_keyPositiveActions);
    await prefs.remove(_keyLastReviewPrompt);
    await prefs.remove(_keyReviewPromptCount);
    await prefs.remove(_keyFirstOpenDate);
    await prefs.remove(_keyHasRated);
    debugPrint('🔄 [APP_REVIEW] Tracking reset');
  }

  /// Get current review status (for debugging)
  Future<Map<String, dynamic>> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'appOpens': prefs.getInt(_keyAppOpenCount) ?? 0,
      'positiveActions': prefs.getInt(_keyPositiveActions) ?? 0,
      'promptCount': prefs.getInt(_keyReviewPromptCount) ?? 0,
      'hasRated': prefs.getBool(_keyHasRated) ?? false,
      'firstOpen': prefs.getString(_keyFirstOpenDate),
      'lastPrompt': prefs.getString(_keyLastReviewPrompt),
      'isAvailable': await _inAppReview.isAvailable(),
    };
  }
}

class _ReviewConditions {
  final bool shouldShow;
  final String reason;

  _ReviewConditions({required this.shouldShow, required this.reason});
}
