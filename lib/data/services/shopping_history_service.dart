import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingHistoryService {
  final _supabase = Supabase.instance.client;
  final _trackingService = PurchaseTrackingService();

  static const String _historySelect = '*, items:shopping_history_items(*)';

  /// Complete a shopping trip and move items to history. Returns the created
  /// history entry so callers can offer an immediate follow-up action (e.g.
  /// splitting the cost) without a redundant re-fetch.
  Future<ShoppingHistory> completeShoppingTrip({
    required String listId,
    required String listName,
    required List<ShoppingItemModel> items,
    String? completedByName,
  }) async {
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
        // A missing name is fine.
      }
    }

    // Seed the trip's total from known item prices so the cost-split sheet
    // has a starting figure (the user can still edit it).
    final pricedTotal = items
        .where((i) => i.price != null)
        .fold<double>(0, (sum, i) => sum + i.price! * i.quantity);
    final completedAt = DateTime.now();

    // list_id is always set so list members see the trip too.
    final historyResponse = await _supabase
        .from('shopping_history')
        .insert({
          'user_id': userId,
          'list_id': listId,
          'list_name': listName,
          'total_items': items.length,
          'completed_at': completedAt.toIso8601String(),
          'completed_by_name': userName,
          if (pricedTotal > 0) 'total_cost': pricedTotal,
        })
        .select('id')
        .single();

    final historyId = historyResponse['id'] as String;

    // Add items to history (carrying known offer prices along, if any)
    await _supabase.from('shopping_history_items').insert([
      for (final item in items)
        {
          'history_id': historyId,
          'name': item.name,
          'quantity': item.quantity,
          'unit': item.unit,
          'category': item.category,
          'price': item.price,
          'price_retailer': item.priceRetailer,
          'price_old_value': item.priceOldValue,
        },
    ]);

    // Purchase stats only feed recommendations — don't make the user wait.
    unawaited(_trackingService.trackPurchases(items).catchError((Object e) {
      debugPrint('⚠️ [HISTORY] Purchase tracking failed: $e');
    }));

    return ShoppingHistory(
      id: historyId,
      userId: userId,
      listId: listId,
      listName: listName,
      totalItems: items.length,
      completedAt: completedAt,
      completedByName: userName,
      totalCost: pricedTotal > 0 ? pricedTotal : null,
    );
  }

  /// Shopping history of the user's own trips plus trips on every list they
  /// are a member of, newest first.
  Future<List<ShoppingHistory>> getShoppingHistory() => _fetchHistory();

  /// The [limit] most recent entries of [getShoppingHistory].
  Future<List<ShoppingHistory>> getRecentHistory({int limit = 5}) =>
      _fetchHistory(limit: limit);

  Future<List<ShoppingHistory>> _fetchHistory({int? limit}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final memberships = await _supabase
        .from('list_members')
        .select('list_id')
        .eq('user_id', userId);
    final listIds = [for (final m in memberships) m['list_id'] as String];

    final query = _supabase.from('shopping_history').select(_historySelect);
    final filtered = listIds.isEmpty
        ? query.eq('user_id', userId)
        : query.or('user_id.eq.$userId,list_id.in.(${listIds.join(',')})');
    final ordered = filtered.order('completed_at', ascending: false);
    final response = limit != null ? await ordered.limit(limit) : await ordered;

    return [for (final json in response) ShoppingHistory.fromJson(json)];
  }

  /// Get shopping history for a specific list
  Future<List<ShoppingHistory>> getHistoryForList(String listId) async {
    final response = await _supabase
        .from('shopping_history')
        .select(_historySelect)
        .eq('list_id', listId)
        .order('completed_at', ascending: false);

    return [for (final json in response) ShoppingHistory.fromJson(json)];
  }

  /// Delete a shopping history entry
  Future<void> deleteHistory(String historyId) async {
    await _supabase.from('shopping_history').delete().eq('id', historyId);
  }

  /// Clear all history for current user
  Future<void> clearAllHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from('shopping_history').delete().eq('user_id', userId);
  }
}
