import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';

/// The account's local copy of the history (verlauf-kosten.md §3.1, L3):
/// the trips of the last 3 months, at least the newest 50, plus the open
/// shares, so the history, the Home sections and "Offene Beträge" show
/// their last state in the first frame. One key per account; nothing is
/// shared between accounts on the device.
class TripHistoryCache {
  const TripHistoryCache(this._prefs);

  final SharedPreferences _prefs;

  /// How far back the cache keeps every trip.
  static const Duration window = Duration(days: 92);

  /// The newest trips kept even when older than [window].
  static const int minTrips = 50;

  static String tripsKey(String userId) => 'hist_trips_v1_$userId';
  static String sharesKey(String userId) => 'hist_open_shares_v1_$userId';

  /// The cached trips of [userId], newest first; empty when none or
  /// unreadable.
  List<ShoppingHistory> readTrips(String userId) {
    try {
      final raw = _prefs.getString(tripsKey(userId));
      if (raw == null) return const [];
      return [
        for (final entry in jsonDecode(raw) as List)
          ShoppingHistory.fromJson(Map<String, dynamic>.from(entry as Map)),
      ];
    } catch (e) {
      debugPrint('⚠️ [HISTORY] Cache unreadable: ${e.runtimeType}');
      return const [];
    }
  }

  /// Keeps what [trimToWindow] leaves of [trips].
  Future<void> writeTrips(
    String userId,
    List<ShoppingHistory> trips, {
    DateTime? now,
  }) async {
    final kept = trimToWindow(trips, now: now ?? DateTime.now());
    await _prefs.setString(
      tripsKey(userId),
      jsonEncode([for (final trip in kept) trip.toCacheJson()]),
    );
  }

  /// The cached open shares of [userId].
  List<OpenShare> readShares(String userId) {
    try {
      final raw = _prefs.getString(sharesKey(userId));
      if (raw == null) return const [];
      return [
        for (final entry in jsonDecode(raw) as List)
          OpenShare.fromRpc(Map<String, dynamic>.from(entry as Map)),
      ];
    } catch (e) {
      debugPrint('⚠️ [SPLIT] Cache unreadable: ${e.runtimeType}');
      return const [];
    }
  }

  Future<void> writeShares(String userId, List<OpenShare> shares) =>
      _prefs.setString(
        sharesKey(userId),
        jsonEncode([for (final share in shares) share.toJson()]),
      );

  /// Every trip of the last [window], and at least the newest [minTrips]
  /// (sorted newest first).
  static List<ShoppingHistory> trimToWindow(
    List<ShoppingHistory> trips, {
    required DateTime now,
  }) {
    final sorted = [...trips]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final since = now.subtract(window);
    return [
      for (var i = 0; i < sorted.length; i++)
        if (i < minTrips || sorted[i].completedAt.isAfter(since)) sorted[i],
    ];
  }
}
