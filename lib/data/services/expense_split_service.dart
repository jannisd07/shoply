import 'package:shoply/data/models/expense_split.dart';
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

/// Splits a completed shopping trip's cost between people and tracks who
/// has paid. Backed by the `expense_splits` table (per-share rows) plus
/// `shopping_history.total_cost` / `paid_by_user_id` / `paid_by_name`
/// (who fronted the money for the trip).
class ExpenseSplitService {
  ExpenseSplitService._();
  static final ExpenseSplitService instance = ExpenseSplitService._();

  final _supabase = Supabase.instance.client;

  /// Splits [historyId]'s cost among [shares]. [paidByUserId]/[paidByName]
  /// record who actually paid at checkout (defaults to the current user).
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

    await _supabase.from('expense_splits').delete().eq('history_id', historyId);

    final rows = shares
        .map((s) => ExpenseSplit(
              id: '',
              historyId: historyId,
              userId: s.userId,
              participantName: s.participantName,
              amount: s.amount,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ).toInsertJson())
        .toList();

    final inserted = rows.isEmpty
        ? <dynamic>[]
        : await _supabase.from('expense_splits').insert(rows).select();

    await _supabase.from('shopping_history').update({
      'total_cost': totalCost,
      'paid_by_user_id': paidByUserId ?? currentUserId,
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

  Future<void> deleteSplitsForHistory(String historyId) async {
    await _supabase.from('expense_splits').delete().eq('history_id', historyId);
    await _supabase.from('shopping_history').update({
      'total_cost': null,
      'paid_by_user_id': null,
      'paid_by_name': null,
    }).eq('id', historyId);
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
    return ExpenseSplit.fromJson(response);
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
