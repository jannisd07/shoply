import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One participant's share in a trip-cost split, as entered in the UI
/// before it has an id/timestamps assigned by the database.
class SplitShare {
  final String? userId;
  final String participantName;
  final double amount;

  const SplitShare({
    this.userId,
    required this.participantName,
    required this.amount,
  });
}

/// A completed, shared-list trip with nobody assigned to split it yet —
/// candidate for the home-screen "split this trip?" nudge.
class UnsplitTripCandidate {
  final String historyId;
  final String listId;
  final String listName;
  final DateTime completedAt;
  final double? totalCost;
  final int totalItems;

  const UnsplitTripCandidate({
    required this.historyId,
    required this.listId,
    required this.listName,
    required this.completedAt,
    this.totalCost,
    required this.totalItems,
  });
}

/// Splits a completed shopping trip's cost between people and tracks who
/// has paid. Backed by the `expense_splits` table (per-share rows) plus
/// `shopping_history.total_cost` / `paid_by_user_id` / `paid_by_name`
/// (who fronted the money for the trip).
class ExpenseSplitService {
  ExpenseSplitService._();
  static final ExpenseSplitService instance = ExpenseSplitService._();

  final _supabase = Supabase.instance.client;

  /// Splits [historyId]'s cost among [shares]. [paidByUserId]/[paidByName]
  /// record who actually paid at checkout — a name-only payer (someone
  /// without an app account) has [paidByName] set and [paidByUserId] null;
  /// when neither is given the current user is assumed to have paid.
  /// The payer's own share (if they have one) is created already marked as
  /// paid, since they settled it at the register.
  /// Replaces any existing splits for this trip (re-splitting overwrites).
  Future<List<ExpenseSplit>> createSplits({
    required String historyId,
    required double totalCost,
    required List<SplitShare> shares,
    String? paidByUserId,
    String? paidByName,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');

    final effectivePaidByUserId = (paidByUserId == null && paidByName == null)
        ? currentUserId
        : paidByUserId;

    await _supabase.from('expense_splits').delete().eq('history_id', historyId);

    bool isPayersOwnShare(SplitShare s) => s.userId != null
        ? s.userId == effectivePaidByUserId
        : effectivePaidByUserId == null && s.participantName == paidByName;

    final now = DateTime.now();
    final rows = shares
        .map((s) => ExpenseSplit(
              id: '',
              historyId: historyId,
              userId: s.userId,
              participantName: s.participantName,
              amount: s.amount,
              isPaid: isPayersOwnShare(s),
              createdAt: now,
              updatedAt: now,
            ).toInsertJson())
        .toList();

    final inserted = rows.isEmpty
        ? <dynamic>[]
        : await _supabase.from('expense_splits').insert(rows).select();

    await _supabase.from('shopping_history').update({
      'total_cost': totalCost,
      'paid_by_user_id': effectivePaidByUserId,
      'paid_by_name': paidByName,
    }).eq('id', historyId);

    return (inserted as List)
        .map((j) => ExpenseSplit.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseSplit>> getSplitsForHistory(String historyId) async {
    final response = await _supabase
        .from('expense_splits')
        .select()
        .eq('history_id', historyId)
        .order('created_at');

    return (response as List)
        .map((j) => ExpenseSplit.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseSplit> setPaid(String splitId, bool isPaid) async {
    final response = await _supabase
        .from('expense_splits')
        .update({
          'is_paid': isPaid,
          'paid_at': isPaid ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', splitId)
        .select()
        .single();
    final split = ExpenseSplit.fromJson(response);
    // Fire-and-forget: a failed push must never fail the paid toggle.
    unawaited(_notifySplitStatusChanged(split, isPaid));
    return split;
  }

  /// Notifies "the other side" of a share's paid status changing: the payer
  /// when a participant settles their own share, or the participant when the
  /// payer marks it settled/reopened. Skips name-only people (no account)
  /// and never notifies the person who tapped the toggle.
  Future<void> _notifySplitStatusChanged(ExpenseSplit split, bool isPaid) async {
    try {
      final actorId = _supabase.auth.currentUser?.id;
      if (actorId == null) return;

      final trip = await _supabase
          .from('shopping_history')
          .select('list_name, paid_by_user_id')
          .eq('id', split.historyId)
          .maybeSingle();
      if (trip == null) return;

      final payerId = trip['paid_by_user_id'] as String?;
      final listName = trip['list_name'] as String? ?? '';
      final recipients = {split.userId, payerId}
          .whereType<String>()
          .where((id) => id != actorId)
          .toList();
      if (recipients.isEmpty) return;

      String actorName = 'Someone';
      try {
        final profile = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', actorId)
            .maybeSingle();
        actorName = (profile?['display_name'] as String?) ?? actorName;
      } catch (_) {}

      final amount = split.amount.toStringAsFixed(2);
      final title = isPaid ? '💶 Share settled' : '💶 Share reopened';
      final body = actorId == payerId
          ? (isPaid
              ? '$actorName marked your $amount € share for "$listName" as paid'
              : '$actorName marked your $amount € share for "$listName" as unpaid')
          : (isPaid
              ? '$actorName paid their $amount € share for "$listName"'
              : '$actorName reopened their $amount € share for "$listName"');

      await PushNotificationService.instance.sendToUsers(
        userIds: recipients,
        title: title,
        body: body,
        data: {
          'type': 'expense_split',
          'history_id': split.historyId,
          'is_paid': isPaid,
        },
      );
      debugPrint('✅ [SPLIT] Notified ${recipients.length} user(s) of paid change');
    } catch (e) {
      debugPrint('⚠️ [SPLIT] Could not send paid-status notification: $e');
    }
  }

  /// Trips the current user paid for that still have unpaid participants —
  /// "X still owes you" — for the home-screen status banner.
  Future<List<TripSplitSummary>> getTripsAwaitingPaymentToMe() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final response = await _supabase
        .from('shopping_history')
        .select('id, list_name, completed_at, total_cost, paid_by_user_id, '
            'paid_by_name, splits:expense_splits(*)')
        .eq('paid_by_user_id', userId)
        .not('total_cost', 'is', null)
        .order('completed_at', ascending: false);

    return _summariesWithUnpaid(response as List);
  }

  /// Splits assigned to the current user (by account) on trips paid by
  /// someone else, still unpaid — "you owe" — for the home-screen banner.
  Future<List<TripSplitSummary>> getTripsIOwe() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final splitsResponse = await _supabase
        .from('expense_splits')
        .select('*, trip:shopping_history(id, list_name, completed_at, '
            'total_cost, paid_by_user_id, paid_by_name)')
        .eq('user_id', userId)
        .eq('is_paid', false);

    final result = <TripSplitSummary>[];
    for (final row in splitsResponse as List) {
      final map = row as Map<String, dynamic>;
      final trip = map['trip'] as Map<String, dynamic>?;
      if (trip == null) continue;
      if (trip['paid_by_user_id'] == userId) continue; // you paid, not owed
      final split = ExpenseSplit.fromJson(map);
      result.add(TripSplitSummary(
        historyId: trip['id'] as String,
        listName: trip['list_name'] as String,
        completedAt: DateTime.parse(trip['completed_at'] as String),
        totalCost: (trip['total_cost'] as num?)?.toDouble() ?? 0,
        paidByUserId: trip['paid_by_user_id'] as String?,
        paidByName: trip['paid_by_name'] as String?,
        splits: [split],
      ));
    }
    return result;
  }

  /// The most recent completed shared-list trip that has nobody assigned to
  /// split it yet — for the home-screen "split this trip?" nudge. Returns
  /// null when there's no such trip within the last week, the most recent
  /// eligible trip is a solo list (nothing to split), or it's already been
  /// split. Scans at most [scanLimit] recent trips, stopping as soon as one
  /// candidate older than a week is hit (trips are returned newest-first, so
  /// everything after that point is stale too). Disqualification checks
  /// (already split / solo list) are batched across the scanned trips rather
  /// than queried one row at a time.
  Future<UnsplitTripCandidate?> getUnsplitTripNudgeCandidate({
    int scanLimit = 5,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('shopping_history')
        .select('id, list_id, list_name, completed_at, total_cost, total_items')
        .eq('user_id', userId)
        .not('list_id', 'is', null)
        .order('completed_at', ascending: false)
        .limit(scanLimit);

    final rows = <Map<String, dynamic>>[];
    for (final row in response as List) {
      final map = row as Map<String, dynamic>;
      final completedAt = DateTime.parse(map['completed_at'] as String);
      if (DateTime.now().difference(completedAt) > const Duration(days: 7)) {
        break;
      }
      rows.add(map);
    }
    if (rows.isEmpty) return null;

    final historyIds = rows.map((m) => m['id'] as String).toList();
    final listIds = rows.map((m) => m['list_id'] as String).toSet().toList();

    final existingSplits = await _supabase
        .from('expense_splits')
        .select('history_id')
        .inFilter('history_id', historyIds);
    final alreadySplit = (existingSplits as List)
        .map((r) => (r as Map<String, dynamic>)['history_id'] as String)
        .toSet();

    final memberRows = await _supabase
        .from('list_members')
        .select('list_id')
        .inFilter('list_id', listIds);
    final memberCounts = <String, int>{};
    for (final r in memberRows as List) {
      final listId = (r as Map<String, dynamic>)['list_id'] as String;
      memberCounts[listId] = (memberCounts[listId] ?? 0) + 1;
    }

    for (final map in rows) {
      final historyId = map['id'] as String;
      final listId = map['list_id'] as String;
      if (alreadySplit.contains(historyId)) continue;
      if ((memberCounts[listId] ?? 0) < 2) continue;

      return UnsplitTripCandidate(
        historyId: historyId,
        listId: listId,
        listName: map['list_name'] as String,
        completedAt: DateTime.parse(map['completed_at'] as String),
        totalCost: (map['total_cost'] as num?)?.toDouble(),
        totalItems: map['total_items'] as int? ?? 0,
      );
    }
    return null;
  }

  List<TripSplitSummary> _summariesWithUnpaid(List response) {
    final summaries = <TripSplitSummary>[];
    for (final row in response) {
      final map = row as Map<String, dynamic>;
      final splits = ((map['splits'] as List?) ?? [])
          .map((j) => ExpenseSplit.fromJson(j as Map<String, dynamic>))
          .toList();
      if (splits.isEmpty || splits.every((s) => s.isPaid)) continue;
      summaries.add(TripSplitSummary(
        historyId: map['id'] as String,
        listName: map['list_name'] as String,
        completedAt: DateTime.parse(map['completed_at'] as String),
        totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0,
        paidByUserId: map['paid_by_user_id'] as String?,
        paidByName: map['paid_by_name'] as String?,
        splits: splits,
      ));
    }
    return summaries;
  }
}
