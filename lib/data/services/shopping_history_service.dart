import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingHistoryService {
  final _supabase = Supabase.instance.client;
  final _trackingService = PurchaseTrackingService();

  /// Complete a shopping trip and move items to history. Returns the created
  /// history entry so callers can offer an immediate follow-up action (e.g.
  /// splitting the cost) without a redundant re-fetch.
  Future<ShoppingHistory> completeShoppingTrip({
    required String listId,
    required String listName,
    required List<ShoppingItemModel> items,
    String? completedByName,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get user's display name if not provided
      String? userName = completedByName;
      if (userName == null) {
        try {
          final userResponse = await _supabase
              .from('users')
              .select('display_name')
              .eq('id', userId)
              .maybeSingle();
          userName = userResponse?['display_name'] as String?;
        } catch (_) {
          // Ignore if users table doesn't have display_name
        }
      }

      // Create history entry with list_id always included for shared visibility
      final historyData = {
        'user_id': userId,
        'list_id': listId,
        'list_name': listName,
        'total_items': items.length,
        'completed_at': DateTime.now().toIso8601String(),
        'completed_by_name': userName,
      };

      final historyResponse = await _supabase
          .from('shopping_history')
          .insert(historyData)
          .select()
          .single();

      final historyId = historyResponse['id'] as String;

      // Add items to history (carrying known offer prices along, if any)
      final historyItems = items.map((item) => {
        'history_id': historyId,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'category': item.category,
        'price': item.price,
        'price_retailer': item.priceRetailer,
        'price_old_value': item.priceOldValue,
      }).toList();

      await _supabase.from('shopping_history_items').insert(historyItems);

      // Seed the trip's total from known item prices so the cost-split
      // sheet has a starting figure (the user can still edit it).
      final pricedTotal = items
          .where((i) => i.price != null)
          .fold<double>(0, (sum, i) => sum + i.price! * i.quantity);
      if (pricedTotal > 0) {
        await _supabase
            .from('shopping_history')
            .update({'total_cost': pricedTotal})
            .eq('id', historyId);
      }

      // Track purchases for recommendations
      try {
        await _trackingService.trackPurchases(items);
      } catch (_) {
        // Ignore tracking errors
      }

      return ShoppingHistory(
        id: historyId,
        userId: userId,
        listId: listId,
        listName: listName,
        totalItems: items.length,
        completedAt: DateTime.parse(historyData['completed_at'] as String),
        completedByName: userName,
        totalCost: pricedTotal > 0 ? pricedTotal : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get shopping history for all lists the user is a member of
  /// Also includes legacy history entries without list_id (user's own history)
  Future<List<ShoppingHistory>> getShoppingHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Always get user's own history first
      final userHistoryResponse = await _supabase
          .from('shopping_history')
          .select('*, items:shopping_history_items(*)')
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      final userHistory = (userHistoryResponse as List)
          .map((json) => ShoppingHistory.fromJson(json as Map<String, dynamic>))
          .toList();

      // Try to get shared history (may fail if list_id column doesn't exist)
      try {
        final memberResponse = await _supabase
            .from('list_members')
            .select('list_id')
            .eq('user_id', userId);

        final listIds = (memberResponse as List)
            .map((m) => m['list_id'] as String)
            .toList();

        if (listIds.isNotEmpty) {
          final sharedHistoryResponse = await _supabase
              .from('shopping_history')
              .select('*, items:shopping_history_items(*)')
              .inFilter('list_id', listIds)
              .neq('user_id', userId)
              .order('completed_at', ascending: false);

          final sharedHistory = (sharedHistoryResponse as List)
              .map((json) => ShoppingHistory.fromJson(json as Map<String, dynamic>))
              .toList();

          // Combine and sort by date
          final allHistory = [...userHistory, ...sharedHistory];
          allHistory.sort((a, b) => b.completedAt.compareTo(a.completedAt));
          return allHistory;
        }
      } catch (_) {
        // list_id column may not exist, just return user's own history
      }

      return userHistory;
    } catch (e) {
      rethrow;
    }
  }

  /// Get recent shopping history for all lists user is member of
  /// Also includes legacy history entries without list_id
  Future<List<ShoppingHistory>> getRecentHistory({int limit = 5}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Always get user's own recent history
      final userHistoryResponse = await _supabase
          .from('shopping_history')
          .select('*, items:shopping_history_items(*)')
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(limit);

      final userHistory = (userHistoryResponse as List)
          .map((json) => ShoppingHistory.fromJson(json as Map<String, dynamic>))
          .toList();

      // Try to get shared history (may fail if list_id column doesn't exist)
      try {
        final memberResponse = await _supabase
            .from('list_members')
            .select('list_id')
            .eq('user_id', userId);

        final listIds = (memberResponse as List)
            .map((m) => m['list_id'] as String)
            .toList();

        if (listIds.isNotEmpty) {
          final sharedHistoryResponse = await _supabase
              .from('shopping_history')
              .select('*, items:shopping_history_items(*)')
              .inFilter('list_id', listIds)
              .neq('user_id', userId)
              .order('completed_at', ascending: false)
              .limit(limit);

          final sharedHistory = (sharedHistoryResponse as List)
              .map((json) => ShoppingHistory.fromJson(json as Map<String, dynamic>))
              .toList();

          // Combine, sort by date, and limit
          final allHistory = [...userHistory, ...sharedHistory];
          allHistory.sort((a, b) => b.completedAt.compareTo(a.completedAt));
          return allHistory.take(limit).toList();
        }
      } catch (_) {
        // list_id column may not exist, just return user's own history
      }

      return userHistory;
    } catch (e) {
      rethrow;
    }
  }

  /// Get shopping history for a specific list
  Future<List<ShoppingHistory>> getHistoryForList(String listId) async {
    try {
      final response = await _supabase
          .from('shopping_history')
          .select('*, items:shopping_history_items(*)')
          .eq('list_id', listId)
          .order('completed_at', ascending: false);

      return (response as List)
          .map((json) => ShoppingHistory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a shopping history entry
  Future<void> deleteHistory(String historyId) async {
    try {
      await _supabase.from('shopping_history').delete().eq('id', historyId);
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all history for current user
  Future<void> clearAllHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('shopping_history')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }
}
