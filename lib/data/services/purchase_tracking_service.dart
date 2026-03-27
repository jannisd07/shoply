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
        );
      }

    } catch (e) {
      rethrow;
    }
  }

  /// Track a single item purchase
  Future<void> _trackSingleItem({
    required String userId,
    required String itemName,
    String? category,
    double? quantity,
    required DateTime purchaseDate,
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

        await _supabase.from('item_purchase_stats').update({
          'purchase_count': newCount,
          'last_purchase': purchaseDate.toIso8601String(),
          'purchase_dates': updatedDates.map((d) => d.toIso8601String()).toList(),
          'average_days_between': avgDays,
          'preferred_category': category ?? stats.preferredCategory,
          'preferred_quantity': quantity ?? stats.preferredQuantity,
          'updated_at': DateTime.now().toIso8601String(),
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
