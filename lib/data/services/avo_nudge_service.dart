import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One "you're probably running low on X" suggestion, derived from the
/// user's real purchase rhythm in `item_purchase_stats`.
class RestockSuggestion {
  /// Normalized (lowercase) name as stored in the stats table.
  final String itemName;

  /// Name with the first letter capitalized, for display.
  final String displayName;

  /// Rounded average days between purchases (the user's buying rhythm).
  final int averageDays;

  /// Days since the item was last purchased.
  final int daysSince;

  /// daysSince / averageDays — how overdue the item is (>= 1.0 here).
  final double overdueRatio;

  final String? preferredCategory;
  final double? preferredQuantity;

  const RestockSuggestion({
    required this.itemName,
    required this.displayName,
    required this.averageDays,
    required this.daysSince,
    required this.overdueRatio,
    this.preferredCategory,
    this.preferredQuantity,
  });
}

/// Computes Avo's restock nudges from data the app already tracks:
/// [PurchaseTrackingService] updates `item_purchase_stats.average_days_between`
/// after every completed shopping trip. An item is suggested when it is
/// overdue by its own average rhythm, not currently on any open list, and
/// not snoozed by the user.
class AvoNudgeService {
  static AvoNudgeService? _instance;
  static AvoNudgeService get instance {
    _instance ??= AvoNudgeService._();
    return _instance!;
  }

  AvoNudgeService._();

  static const String _snoozeKey = 'avo_nudge_snoozed_until';

  /// Minimum purchases before a rhythm is trusted.
  static const int _minPurchases = 3;

  /// Rhythms outside this window are ignored (daily-ish to ~2 months).
  static const double _minAvgDays = 2;
  static const double _maxAvgDays = 60;

  /// If an item is overdue by more than this factor, the habit has probably
  /// changed (bought elsewhere, stopped using it) — stop suggesting it.
  static const double _maxOverdueRatio = 4;

  final PurchaseTrackingService _trackingService = PurchaseTrackingService();

  /// Top [limit] restock suggestions, most overdue first.
  Future<List<RestockSuggestion>> getRestockSuggestions({int limit = 3}) async {
    try {
      final stats = await _trackingService.getAllStats();
      if (stats.isEmpty) return [];

      final snoozed = await _loadSnoozes();
      final candidates = <ItemPurchaseStats>[];
      for (final s in stats) {
        final avg = s.averageDaysBetween;
        if (s.purchaseCount < _minPurchases) continue;
        if (avg == null || avg < _minAvgDays || avg > _maxAvgDays) continue;
        final ratio = s.daysSinceLastPurchase / avg;
        if (ratio < 1.0 || ratio > _maxOverdueRatio) continue;
        if (_isSnoozed(snoozed, s.itemName)) continue;
        candidates.add(s);
      }
      if (candidates.isEmpty) return [];

      // Exclude items already sitting unchecked on one of the user's lists.
      final openItemNames = await _getOpenItemNames();
      candidates.removeWhere(
          (s) => openItemNames.contains(s.itemName.trim().toLowerCase()));
      if (candidates.isEmpty) return [];

      candidates.sort((a, b) {
        final ra = a.daysSinceLastPurchase / a.averageDaysBetween!;
        final rb = b.daysSinceLastPurchase / b.averageDaysBetween!;
        return rb.compareTo(ra);
      });

      return candidates.take(limit).map((s) {
        final avg = s.averageDaysBetween!;
        return RestockSuggestion(
          itemName: s.itemName,
          displayName: _capitalize(s.itemName),
          averageDays: avg.round().clamp(1, 999),
          daysSince: s.daysSinceLastPurchase,
          overdueRatio: s.daysSinceLastPurchase / avg,
          preferredCategory: s.preferredCategory,
          preferredQuantity: s.preferredQuantity,
        );
      }).toList();
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to compute suggestions: $e');
      return [];
    }
  }

  /// Snooze a suggestion for one of its own purchase cycles (at least 2 days),
  /// so a dismissal isn't forever — the nudge comes back when it is plausibly
  /// due again.
  Future<void> snooze(RestockSuggestion suggestion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozed = await _loadSnoozes();
      final days = suggestion.averageDays < 2 ? 2 : suggestion.averageDays;
      snoozed[suggestion.itemName] =
          DateTime.now().add(Duration(days: days)).toIso8601String();
      await prefs.setString(_snoozeKey, jsonEncode(snoozed));
      debugPrint(
          '🥑 [AVO_NUDGE] Snoozed "${suggestion.itemName}" for $days days');
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to snooze: $e');
    }
  }

  /// Names (normalized) of all unchecked items on lists the user can see.
  /// RLS scopes the query to the user's own/shared lists.
  Future<Set<String>> _getOpenItemNames() async {
    try {
      final rows = await Supabase.instance.client
          .from('shopping_items')
          .select('name')
          .eq('is_checked', false);
      return (rows as List)
          .map((r) => (r['name'] as String? ?? '').trim().toLowerCase())
          .where((n) => n.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to load open items: $e');
      // Fail closed: if we can't check, suggest nothing rather than
      // suggesting an item that is already on a list.
      rethrow;
    }
  }

  Future<Map<String, String>> _loadSnoozes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_snoozeKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      final result = <String, String>{};
      // Prune expired snoozes while loading.
      decoded.forEach((name, until) {
        final ts = DateTime.tryParse('$until');
        if (ts != null && ts.isAfter(now)) result[name] = '$until';
      });
      if (result.length != decoded.length) {
        await prefs.setString(_snoozeKey, jsonEncode(result));
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  bool _isSnoozed(Map<String, String> snoozed, String itemName) {
    return snoozed.containsKey(itemName);
  }

  String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}
