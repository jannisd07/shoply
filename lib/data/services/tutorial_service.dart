import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage tutorial state persistence
class TutorialService {
  static const String _tutorialCompletedKey = 'tutorial_completed';
  static const String _tutorialSkippedKey = 'tutorial_skipped';
  
  static TutorialService? _instance;
  static TutorialService get instance => _instance ??= TutorialService._();
  
  TutorialService._();
  
  /// Check if the tutorial has been completed or skipped
  Future<bool> shouldShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_tutorialCompletedKey) ?? false;
      final skipped = prefs.getBool(_tutorialSkippedKey) ?? false;
      return !completed && !skipped;
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error checking tutorial status: $e');
      return false;
    }
  }
  
  /// Mark the tutorial as completed
  Future<void> markTutorialCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tutorialCompletedKey, true);
      debugPrint('✅ [TUTORIAL] Tutorial marked as completed');
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error marking tutorial completed: $e');
    }
  }
  
  /// Mark the tutorial as skipped
  Future<void> markTutorialSkipped() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tutorialSkippedKey, true);
      debugPrint('✅ [TUTORIAL] Tutorial marked as skipped');
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error marking tutorial skipped: $e');
    }
  }
  
  /// Reset tutorial state (for testing)
  Future<void> resetTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tutorialCompletedKey);
      await prefs.remove(_tutorialSkippedKey);
      debugPrint('✅ [TUTORIAL] Tutorial state reset');
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error resetting tutorial: $e');
    }
  }
}
