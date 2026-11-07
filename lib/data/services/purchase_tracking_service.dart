import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseTrackingService {
  final _supabase = Supabase.instance.client;

  /// Track purchases from a completed shopping trip.
  ///
  /// Reads all affected stats rows in one query and writes them concurrently
  /// (bulk insert for new items, parallel updates for known ones) instead of
  /// a select + write per item in sequence. A failed write for one item does
  /// not stop the others.
  Future<void> trackPurchases(List<ShoppingItemModel> items) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    if (items.isEmpty) return;

    final now = DateTime.now();
    final byName = <String, List<ShoppingItemModel>>{};
    for (final item in items) {
      byName.putIfAbsent(item.name.trim().toLowerCase(), () => []).add(item);
    }

    final existingRows = await _supabase
        .from('item_purchase_stats')
        .select()
        .eq('user_id', userId)
        .inFilter('item_name', byName.keys.toList());
    final existingByName = {
      for (final row in existingRows) row['item_name'] as String: row,
    };

    // Inserts are grouped by key set: PostgREST bulk inserts need identical
    // keys, and the retailer columns are only sent when there is a value.
    final insertsWithRetailer = <Map<String, dynamic>>[];
    final insertsWithoutRetailer = <Map<String, dynamic>>[];
    final writes = <Future<void>>[];

    for (final entry in byName.entries) {
      final existing = existingByName[entry.key];
      var state = _StatsState.fromRow(existing);
      for (final item in entry.value) {
        state = state.addPurchase(
          purchaseDate: now,
          category: item.category,
          quantity: item.quantity,
          retailer: item.priceRetailer?.trim(),
        );
      }

      if (existing == null) {
        final row = {
          'user_id': userId,
          'item_name': entry.key,
          ...state.toInsertRow(),
        };
        (state.preferredRetailer != null
                ? insertsWithRetailer
                : insertsWithoutRetailer)
            .add(row);
      } else {
        writes.add(_supabase
            .from('item_purchase_stats')
            .update(state.toUpdateRow())
            .eq('id', existing['id'])
            .then((_) {}));
      }
    }

    for (final rows in [insertsWithRetailer, insertsWithoutRetailer]) {
      if (rows.isNotEmpty) {
        writes.add(
            _supabase.from('item_purchase_stats').insert(rows).then((_) {}));
      }
    }

    await Future.wait(writes.map((write) => write.catchError((Object e) {
          debugPrint('⚠️ [PURCHASE_STATS] Failed to write stats: $e');
        })));
  }

  /// Merge one more purchase at [retailer] into an existing tally.
  ///
  /// Kept as a pure function so the "where do I usually buy this" logic can
  /// be tested without a database. A tie is broken alphabetically so the
  /// answer is stable between runs instead of flipping with row order.
  @visibleForTesting
  static ({Map<String, int> counts, String? preferred}) mergeRetailer(
    Map<String, int> existing,
    String? retailer,
  ) {
    final counts = Map<String, int>.from(existing);
    final name = retailer?.trim();
    if (name != null && name.isNotEmpty) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    if (counts.isEmpty) return (counts: counts, preferred: null);

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return (counts: counts, preferred: entries.first.key);
  }

  /// Read a `retailer_counts` payload defensively — the column may not exist
  /// yet on databases where the migration has not been run.
  static Map<String, int> _readCounts(Map<String, dynamic> row) {
    final raw = row['retailer_counts'];
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
    };
  }

  /// Get all purchase stats for user
  Future<List<ItemPurchaseStats>> getAllStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('item_purchase_stats')
          .select()
          .eq('user_id', userId)
          .order('purchase_count', ascending: false);

      return (response as List)
          .map((json) => ItemPurchaseStats.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get frequently purchased items (top N)
  Future<List<ItemPurchaseStats>> getFrequentItems({int limit = 20}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('item_purchase_stats')
          .select()
          .eq('user_id', userId)
          .gte('purchase_count', 2) // At least 2 purchases
          .order('purchase_count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ItemPurchaseStats.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

/// Running purchase stats for one item while a trip's purchases are folded in.
class _StatsState {
  const _StatsState({
    required this.purchaseCount,
    required this.purchaseDates,
    required this.retailerCounts,
    this.firstPurchase,
    this.preferredCategory,
    this.preferredQuantity,
    this.preferredRetailer,
  });

  factory _StatsState.fromRow(Map<String, dynamic>? row) {
    if (row == null) {
      return const _StatsState(
        purchaseCount: 0,
        purchaseDates: [],
        retailerCounts: {},
      );
    }
    final stats = ItemPurchaseStats.fromJson(row);
    return _StatsState(
      purchaseCount: stats.purchaseCount,
      purchaseDates: stats.purchaseDates,
      retailerCounts: PurchaseTrackingService._readCounts(row),
      firstPurchase: stats.firstPurchase,
      preferredCategory: stats.preferredCategory,
      preferredQuantity: stats.preferredQuantity,
      preferredRetailer: stats.preferredRetailer,
    );
  }

  final int purchaseCount;
  final List<DateTime> purchaseDates;
  final Map<String, int> retailerCounts;
  final DateTime? firstPurchase;
  final String? preferredCategory;
  final double? preferredQuantity;
  final String? preferredRetailer;

  _StatsState addPurchase({
    required DateTime purchaseDate,
    String? category,
    double? quantity,
    String? retailer,
  }) {
    final merged =
        PurchaseTrackingService.mergeRetailer(retailerCounts, retailer);
    return _StatsState(
      purchaseCount: purchaseCount + 1,
      purchaseDates: [...purchaseDates, purchaseDate],
      retailerCounts: merged.counts,
      firstPurchase: firstPurchase ?? purchaseDate,
      preferredCategory: category ?? preferredCategory,
      preferredQuantity: quantity ?? preferredQuantity,
      preferredRetailer: merged.preferred ?? preferredRetailer,
    );
  }

  /// Average whole days between consecutive purchases, null below two.
  double? get averageDaysBetween {
    if (purchaseDates.length < 2) return null;
    final sorted = [...purchaseDates]..sort();
    var totalDays = 0;
    for (var i = 1; i < sorted.length; i++) {
      totalDays += sorted[i].difference(sorted[i - 1]).inDays;
    }
    return totalDays / (sorted.length - 1);
  }

  Map<String, dynamic> _commonFields() => {
        'purchase_count': purchaseCount,
        'last_purchase': purchaseDates.last.toIso8601String(),
        'purchase_dates': [for (final d in purchaseDates) d.toIso8601String()],
        'average_days_between': averageDaysBetween,
        'preferred_category': preferredCategory,
        'preferred_quantity': preferredQuantity,
        // Only sent when there is something to record, so the write still
        // succeeds on databases where the retailer migration has not run.
        if (preferredRetailer != null) ...{
          'preferred_retailer': preferredRetailer,
          'retailer_counts': retailerCounts,
        },
      };

  Map<String, dynamic> toInsertRow() => {
        ..._commonFields(),
        'first_purchase': firstPurchase!.toIso8601String(),
      };

  Map<String, dynamic> toUpdateRow() => {
        ..._commonFields(),
        'updated_at': DateTime.now().toIso8601String(),
      };
}
