import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/trip_checkout.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/trip_split_math.dart';

/// Whether [error] says a server function or column of a newer migration
/// is missing (`PGRST202` function not in the schema cache, `42883`
/// undefined function, `PGRST204` / `42703` unknown column). Then the
/// services fall back to today's writes, so saving never blocks on a
/// migration the owner has not applied yet.
bool isMissingServerFeature(Object error) {
  if (error is! PostgrestException) return false;
  const codes = {'PGRST202', '42883', 'PGRST204', '42703'};
  if (codes.contains(error.code)) return true;
  final message = error.message.toLowerCase();
  return message.contains('could not find the function') ||
      (message.contains('column') && message.contains('does not exist'));
}

/// The server calls of the history, behind an interface so the fallback
/// paths can be tested with a fake.
abstract interface class TripHistoryBackend {
  String? get currentUserId;

  /// `complete_shopping_trip` (migration `b_trip_checkout`); its jsonb.
  Future<Map<String, dynamic>> completeTripRpc({
    required String listId,
    required List<String> itemIds,
    String? chainId,
    String? storeSource,
    double? totalCost,
    required bool splitPlanned,
  });

  /// `undo_shopping_trip`; its `status`.
  Future<String> undoTripRpc(String tripId, String token);

  /// Display name of the signed-in person, or null.
  Future<String?> currentUserName();

  Future<bool> listExists(String listId);

  /// Fallback: inserts a `shopping_history` row, returns its id.
  Future<String> insertTrip(Map<String, dynamic> row);

  /// Fallback: inserts `shopping_history_items` rows.
  Future<void> insertTripItems(List<Map<String, dynamic>> rows);

  /// Fallback: removes the finished items from the list.
  Future<void> removeListItems(String listId, List<String> itemIds);

  /// Fallback undo: puts [items] back on [listId], checked.
  Future<void> restoreListItems(String listId, List<ShoppingItemModel> items);

  /// Deletes a trip; false when no row was deleted (not one's own, Bug 4).
  Future<bool> deleteTrip(String tripId);

  /// One trip with its items, or null when it is gone or not visible.
  Future<ShoppingHistory?> fetchTrip(String tripId);

  /// Trips of the person and of every list they are a member of, newest
  /// first, at most [limit], completed before [before] when given.
  Future<List<ShoppingHistory>> fetchTrips({int? limit, DateTime? before});

  /// Trips of one list, newest first.
  Future<List<ShoppingHistory>> fetchTripsForList(String listId);

  /// Deletes every trip the person finished.
  Future<void> deleteOwnTrips();

  /// Purchase stats for recommendations ("du kaufst X alle N Tage").
  Future<void> trackPurchases(List<ShoppingItemModel> items);
}

/// Shopping history: finishing a trip ("Einkauf abschließen", V1), undoing
/// it (V3) and reading the history page by page (L3).
///
/// Finishing calls the atomic server function `complete_shopping_trip`
/// (L1). While that migration is not applied it falls back to today's
/// separate inserts, so trips keep saving on the current schema. The amount
/// is only ever what the person typed (Bug 7) and the market is a chain id
/// from `StoreChainDirectory` (L2).
class ShoppingHistoryService {
  ShoppingHistoryService({TripHistoryBackend? backend})
    : _backend = backend ?? SupabaseTripHistoryBackend();

  final TripHistoryBackend _backend;

  /// Trips per page of the history (L3).
  static const int pageSize = 30;

  /// Finishes a trip. Throws only for network or server errors; a list that
  /// is gone, nothing checked or a member who was faster come back as
  /// [CheckoutResult]s.
  Future<CheckoutResult> completeTrip(CheckoutRequest request) async {
    final userId = _backend.currentUserId;
    if (userId == null) throw StateError('User not authenticated');
    final items = [
      for (final item in request.checkedItems)
        if (item.isChecked) item,
    ];
    if (items.isEmpty) return const CheckoutNothingChecked();
    final chainId = request.chainId != null &&
            StoreChainDirectory.byId(request.chainId!) != null
        ? request.chainId
        : null;
    final totalCost = request.totalCostCents == null
        ? null
        : centsToEuros(request.totalCostCents!);

    Map<String, dynamic> answer;
    try {
      answer = await _backend.completeTripRpc(
        listId: request.listId,
        itemIds: [for (final item in items) item.id],
        chainId: chainId,
        storeSource: chainId == null ? null : request.storeSource?.name,
        totalCost: totalCost,
        splitPlanned: request.splitPlanned,
      );
    } catch (e) {
      if (!isMissingServerFeature(e)) rethrow;
      debugPrint('⚠️ [HISTORY] Checkout function missing, using inserts');
      return _completeLegacy(request, items, chainId, totalCost, userId);
    }

    final status = answer['status'] as String?;
    switch (status) {
      case 'saved':
        final tripId = answer['trip_id'] as String;
        _trackPurchases(items);
        return CheckoutSaved(
          trip: _localTrip(
            id: tripId,
            userId: userId,
            request: request,
            items: items,
            chainId: chainId,
            totalCost: totalCost,
            completedAt:
                DateTime.tryParse('${answer['completed_at']}')?.toLocal() ??
                DateTime.now(),
            completedByName: answer['completed_by_name'] as String?,
            count: (answer['total_items'] as num?)?.toInt(),
          ),
          undoToken: answer['undo_token'] as String?,
        );
      case 'already_completed':
        return CheckoutAlreadyCompleted(
          tripId: answer['trip_id'] as String?,
          byName: answer['completed_by_name'] as String?,
        );
      case 'list_gone':
        return const CheckoutListGone();
      default:
        return const CheckoutNothingChecked();
    }
  }

  Future<CheckoutResult> _completeLegacy(
    CheckoutRequest request,
    List<ShoppingItemModel> items,
    String? chainId,
    double? totalCost,
    String userId,
  ) async {
    if (!await _backend.listExists(request.listId)) {
      return const CheckoutListGone();
    }
    final name = await _backend.currentUserName();
    final completedAt = DateTime.now();
    // Today's schema has no store column: the market goes into the items'
    // retailer (as before), where reading normalises it again.
    final storeName = chainId == null
        ? null
        : StoreChainDirectory.byId(chainId)?.displayName;
    final tripId = await _backend.insertTrip({
      'user_id': userId,
      'list_id': request.listId,
      'list_name': request.listName,
      'total_items': items.length,
      'completed_at': completedAt.toUtc().toIso8601String(),
      'completed_by_name': name,
      'total_cost': ?totalCost,
    });
    await _backend.insertTripItems([
      for (final item in items)
        {
          'history_id': tripId,
          'name': item.name,
          'quantity': item.quantity,
          'unit': item.unit,
          'category': item.categoryId ?? item.category,
          'price': item.price,
          'price_retailer':
              (item.priceRetailer == null || item.priceRetailer!.isEmpty)
              ? storeName
              : item.priceRetailer,
          'price_old_value': item.priceOldValue,
        },
    ]);
    await _backend.removeListItems(request.listId, [
      for (final item in items) item.id,
    ]);
    _trackPurchases(items);
    return CheckoutSaved(
      trip: _localTrip(
        id: tripId,
        userId: userId,
        request: request,
        items: items,
        chainId: chainId,
        totalCost: totalCost,
        completedAt: completedAt,
        completedByName: name,
      ),
      legacy: true,
      restoreItems: items,
    );
  }

  ShoppingHistory _localTrip({
    required String id,
    required String userId,
    required CheckoutRequest request,
    required List<ShoppingItemModel> items,
    required String? chainId,
    required double? totalCost,
    required DateTime completedAt,
    String? completedByName,
    int? count,
  }) => ShoppingHistory(
    id: id,
    userId: userId,
    listId: request.listId,
    listName: request.listName,
    totalItems: count ?? items.length,
    completedAt: completedAt,
    completedByName: completedByName,
    totalCost: totalCost,
    storeChainId: chainId,
    storeSource: chainId == null ? null : request.storeSource?.name,
    totalCostSource: totalCost == null ? null : 'user',
    completedBy: userId,
    items: [
      for (final item in items)
        ShoppingHistoryItem(
          id: item.id,
          historyId: id,
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          category: item.categoryId ?? item.category,
          price: item.price,
          priceRetailer: item.priceRetailer,
          priceOldValue: item.priceOldValue,
        ),
    ],
  );

  void _trackPurchases(List<ShoppingItemModel> items) {
    // Purchase stats only feed recommendations; never make the person wait.
    unawaited(() async {
      try {
        await _backend.trackPurchases(items);
      } catch (e) {
        debugPrint('⚠️ [HISTORY] Purchase tracking failed: ${e.runtimeType}');
      }
    }());
  }

  /// Takes [saved] back ("Widerrufen" in V3): the items are checked on the
  /// list again and the trip with a split from the same chain is gone.
  Future<UndoTripResult> undoTrip(CheckoutSaved saved) async {
    try {
      final token = saved.undoToken;
      if (token != null && !saved.legacy) {
        final status = await _backend.undoTripRpc(saved.trip.id, token);
        return status == 'undone'
            ? UndoTripResult.undone
            : UndoTripResult.refused;
      }
      final listId = saved.trip.listId;
      if (listId != null && saved.restoreItems.isNotEmpty) {
        await _backend.restoreListItems(listId, saved.restoreItems);
      }
      await _backend.deleteTrip(saved.trip.id);
      return UndoTripResult.undone;
    } catch (e) {
      debugPrint('❌ [HISTORY] Undo failed: ${e.runtimeType}');
      return UndoTripResult.failed;
    }
  }

  /// Older entry point (`shopping_trip_completion.dart` of Teil A): finishes
  /// [items] without market or amount through [completeTrip].
  Future<ShoppingHistory> completeShoppingTrip({
    required String listId,
    required String listName,
    required List<ShoppingItemModel> items,
    String? completedByName,
  }) async {
    final result = await completeTrip(
      CheckoutRequest(
        listId: listId,
        listName: listName,
        checkedItems: [
          for (final item in items) item.isChecked ? item : item.copyWith(isChecked: true),
        ],
      ),
    );
    if (result is CheckoutSaved) return result.trip;
    throw StateError('Trip not saved: ${result.runtimeType}');
  }

  /// One page of the history (L3): trips of the person and of every list
  /// they are a member of, newest first, completed before [before].
  Future<List<ShoppingHistory>> getHistoryPage({DateTime? before}) =>
      _backend.fetchTrips(limit: pageSize, before: before);

  /// The whole history (Avo tools, account deletion summary).
  Future<List<ShoppingHistory>> getShoppingHistory() => _backend.fetchTrips();

  /// The [limit] most recent entries of [getShoppingHistory].
  Future<List<ShoppingHistory>> getRecentHistory({int limit = 5}) =>
      _backend.fetchTrips(limit: limit);

  /// One trip, or null when it is gone or the person is no member any more.
  Future<ShoppingHistory?> getTrip(String tripId) => _backend.fetchTrip(tripId);

  /// Shopping history of one list.
  Future<List<ShoppingHistory>> getHistoryForList(String listId) =>
      _backend.fetchTripsForList(listId);

  /// Deletes a trip the person finished. Throws when nothing was deleted
  /// (someone else's trip: RLS lets the delete match no row, Bug 4).
  Future<void> deleteHistory(String historyId) async {
    if (!await _backend.deleteTrip(historyId)) {
      throw StateError('Trip not deleted');
    }
  }

  /// Deletes every trip the person finished.
  Future<void> clearAllHistory() => _backend.deleteOwnTrips();
}

/// [TripHistoryBackend] on Supabase.
class SupabaseTripHistoryBackend implements TripHistoryBackend {
  SupabaseTripHistoryBackend({ItemRepository? items})
    : _items = items ?? ItemRepository.instance;

  final ItemRepository _items;

  SupabaseClient get _db => Supabase.instance.client;

  static const String _select = '*, items:shopping_history_items(*)';

  @override
  String? get currentUserId => _db.auth.currentUser?.id;

  @override
  Future<Map<String, dynamic>> completeTripRpc({
    required String listId,
    required List<String> itemIds,
    String? chainId,
    String? storeSource,
    double? totalCost,
    required bool splitPlanned,
  }) async {
    final answer = await _db.rpc<dynamic>(
      'complete_shopping_trip',
      params: {
        'p_list_id': listId,
        'p_checked_item_ids': itemIds,
        'p_chain_id': chainId,
        'p_store_source': storeSource,
        'p_total_cost': totalCost,
        'p_split_planned': splitPlanned,
      },
    );
    return Map<String, dynamic>.from(answer as Map);
  }

  @override
  Future<String> undoTripRpc(String tripId, String token) async {
    final answer = await _db.rpc<dynamic>(
      'undo_shopping_trip',
      params: {'p_trip_id': tripId, 'p_token': token},
    );
    return (answer as Map)['status'] as String? ?? 'failed';
  }

  @override
  Future<String?> currentUserName() async {
    final id = currentUserId;
    if (id == null) return null;
    try {
      final row = await _db
          .from('users')
          .select('display_name')
          .eq('id', id)
          .maybeSingle();
      return row?['display_name'] as String?;
    } catch (_) {
      return null; // A missing name is fine.
    }
  }

  @override
  Future<bool> listExists(String listId) async =>
      (await _items.getListName(listId)) != null;

  @override
  Future<String> insertTrip(Map<String, dynamic> row) async {
    final inserted = await _db
        .from('shopping_history')
        .insert(row)
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  @override
  Future<void> insertTripItems(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _db.from('shopping_history_items').insert(rows);
  }

  @override
  Future<void> removeListItems(String listId, List<String> itemIds) async {
    // Only until `complete_shopping_trip` is applied (it removes them in its
    // transaction). ItemRepository has no batch delete without a push per
    // item yet (request to Teil A), so this is today's single delete.
    await SupabaseService.instance
        .from('shopping_items')
        .delete()
        .eq('list_id', listId)
        .inFilter('id', itemIds);
  }

  @override
  Future<void> restoreListItems(
    String listId,
    List<ShoppingItemModel> items,
  ) async {
    final added = await _items.addItems(listId, [
      for (final item in items)
        NewItem(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          category: item.categoryId ?? item.category,
          notes: item.notes,
        ),
    ]);
    final now = DateTime.now().toIso8601String();
    await Future.wait([
      for (final item in added.items)
        _items.updateItem(item.id, {'is_checked': true, 'checked_at': now}),
    ]);
  }

  @override
  Future<bool> deleteTrip(String tripId) async {
    final rows = await _db
        .from('shopping_history')
        .delete()
        .eq('id', tripId)
        .select('id');
    return (rows as List).isNotEmpty;
  }

  @override
  Future<ShoppingHistory?> fetchTrip(String tripId) async {
    final row = await _db
        .from('shopping_history')
        .select(_select)
        .eq('id', tripId)
        .maybeSingle();
    return row == null ? null : ShoppingHistory.fromJson(row);
  }

  @override
  Future<List<ShoppingHistory>> fetchTrips({
    int? limit,
    DateTime? before,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('User not authenticated');

    final memberships = await _db
        .from('list_members')
        .select('list_id')
        .eq('user_id', userId);
    final listIds = [for (final m in memberships) m['list_id'] as String];

    var query = _db.from('shopping_history').select(_select);
    query = listIds.isEmpty
        ? query.eq('user_id', userId)
        : query.or('user_id.eq.$userId,list_id.in.(${listIds.join(',')})');
    if (before != null) {
      query = query.lt('completed_at', before.toUtc().toIso8601String());
    }
    final ordered = query.order('completed_at', ascending: false);
    final response = limit != null ? await ordered.limit(limit) : await ordered;
    return [for (final json in response) ShoppingHistory.fromJson(json)];
  }

  @override
  Future<List<ShoppingHistory>> fetchTripsForList(String listId) async {
    final response = await _db
        .from('shopping_history')
        .select(_select)
        .eq('list_id', listId)
        .order('completed_at', ascending: false);
    return [for (final json in response) ShoppingHistory.fromJson(json)];
  }

  @override
  Future<void> trackPurchases(List<ShoppingItemModel> items) =>
      PurchaseTrackingService().trackPurchases(items);

  @override
  Future<void> deleteOwnTrips() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('User not authenticated');
    await _db.from('shopping_history').delete().eq('user_id', userId);
  }
}
