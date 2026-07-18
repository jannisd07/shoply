import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which "split this trip?" home-screen nudge the user last
/// dismissed, so it doesn't reappear for that exact trip. A genuinely
/// different trip (a new completed shopping run) always surfaces normally —
/// mirrors `HomePriceComparisonCacheService`'s single-last-dismissed-value
/// shape, since only one nudge is ever shown at a time.
class SplitNudgeCacheService {
  static SplitNudgeCacheService? _instance;
  static SplitNudgeCacheService get instance {
    _instance ??= SplitNudgeCacheService._();
    return _instance!;
  }

  SplitNudgeCacheService._();

  static const _dismissedHistoryIdKey = 'split_trip_nudge_dismissed_id_v1';

  Future<bool> isDismissed(String historyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dismissedHistoryIdKey) == historyId;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismiss(String historyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedHistoryIdKey, historyId);
    } catch (e) {
      debugPrint('💶 [SPLIT_NUDGE] Failed to store dismissal: $e');
    }
  }
}
