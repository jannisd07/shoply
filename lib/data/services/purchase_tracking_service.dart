import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseTrackingService {
  final _supabase = Supabase.instance.client;

  /// Track purchases from a completed shopping trip
  Future<void> trackPurchases(List<ShoppingItemModel> items) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();

      for (final item in items) {
        await _trackSingleItem(
          userId: userId,
          itemName: item.name.trim().toLowerCase(),
          category: item.category,
          quantity: item.quantity,
          purchaseDate: now,
          retailer: item.priceRetailer?.trim(),
        );
      }

    } catch (e) {
      rethrow;
    }
  }

  /// Track a single item purchase
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

  Future<void> _trackSingleItem({
    required String userId,
    required String itemName,
    String? category,
    double? quantity,
    required DateTime purchaseDate,
    String? retailer,
  }) async {
    try {
      // Check if stats exist for this item
      final existing = await _supabase
          .from('item_purchase_stats')
          .select()
          .eq('user_id', userId)
          .eq('item_name', itemName)
          .maybeSingle();

      if (existing == null) {
        final merged = mergeRetailer(const {}, retailer);
        // Create new stats
        await _supabase.from('item_purchase_stats').insert({
          'user_id': userId,
          'item_name': itemName,
          'purchase_count': 1,
          'first_purchase': purchaseDate.toIso8601String(),
          'last_purchase': purchaseDate.toIso8601String(),
          'purchase_dates': [purchaseDate.toIso8601String()],
          'preferred_category': category,
          'preferred_quantity': quantity,
          if (merged.preferred != null) ...{
            'preferred_retailer': merged.preferred,
            'retailer_counts': merged.counts,
          },
        });
      } else {
        // Update existing stats
        final stats = ItemPurchaseStats.fromJson(existing);
        final updatedDates = [...stats.purchaseDates, purchaseDate];
        final newCount = stats.purchaseCount + 1;

        // Calculate average days between purchases
        double? avgDays;
        if (updatedDates.length >= 2) {
          final sortedDates = [...updatedDates]..sort();
          int totalDays = 0;
          for (int i = 1; i < sortedDates.length; i++) {
            totalDays += sortedDates[i].difference(sortedDates[i - 1]).inDays;
          }
          avgDays = totalDays / (sortedDates.length - 1);
        }

        final merged = mergeRetailer(_readCounts(existing), retailer);

        await _supabase.from('item_purchase_stats').update({
          'purchase_count': newCount,
          'last_purchase': purchaseDate.toIso8601String(),
          'purchase_dates': updatedDates.map((d) => d.toIso8601String()).toList(),
          'average_days_between': avgDays,
          'preferred_category': category ?? stats.preferredCategory,
          'preferred_quantity': quantity ?? stats.preferredQuantity,
          'updated_at': DateTime.now().toIso8601String(),
          // Only sent when there is something to record, so the write still
          // succeeds on databases where the migration has not been run yet.
          if (merged.preferred != null) ...{
            'preferred_retailer': merged.preferred,
            'retailer_counts': merged.counts,
          },
        }).eq('id', stats.id);
      }
    } catch (e) {
      // Don't rethrow - continue tracking other items
    }
  }

  /// Get purchase stats for a specific item
  Future<ItemPurchaseStats?> getItemStats(String itemName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('item_purchase_stats')
          .select()
          .eq('user_id', userId)
          .eq('item_name', itemName.trim().toLowerCase())
          .maybeSingle();

      if (response == null) return null;
      return ItemPurchaseStats.fromJson(response);
    } catch (e) {
      return null;
    }
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

  /// Delete stats for a specific item
  Future<void> deleteItemStats(String itemName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('item_purchase_stats')
          .delete()
          .eq('user_id', userId)
          .eq('item_name', itemName.trim().toLowerCase());

    } catch (e) {
      rethrow;
    }
  }

  /// Clear all purchase stats for user
  Future<void> clearAllStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('item_purchase_stats')
          .delete()
          .eq('user_id', userId);

    } catch (e) {
      rethrow;
    }
  }
}
