import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart'
    show isMissingServerFeature;
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_split_math.dart';

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

/// The server calls of Kosten teilen that have a newer server function
/// (migration `b_trip_checkout`) and an older fallback, behind an interface
/// so the fallback paths can be tested with a fake.
abstract interface class SplitBackend {
  String? get currentUserId;

  /// `save_trip_split`; the saved rows in "Wer teilt?" order.
  Future<List<Map<String, dynamic>>> saveSplitRpc({
    required String historyId,
    required double totalCost,
    required String? paidByUserId,
    required String? paidByName,
    required String splitMode,
    required List<Map<String, dynamic>> shares,
  });

  /// Fallback: ids of the current split rows of a trip.
  Future<List<String>> splitIds(String historyId);

  /// Fallback: inserts rows, returns them.
  Future<List<Map<String, dynamic>>> insertSplits(
    List<Map<String, dynamic>> rows,
  );

  /// Fallback: writes amount and payer on the trip.
  Future<void> updateTripPayment(String historyId, Map<String, dynamic> values);

  /// Fallback: deletes split rows by id.
  Future<void> deleteSplits(List<String> ids);

  /// Sets the paid state of one row and returns it.
  Future<Map<String, dynamic>> updatePaid(String splitId, bool isPaid);

  /// `open_split_shares` (L8).
  Future<List<Map<String, dynamic>>> openSharesRpc();
}

/// Splits a completed shopping trip's cost between people and tracks who
/// has paid. Backed by the `expense_splits` table (per-share rows) plus
/// `shopping_history.total_cost` / `paid_by_user_id` / `paid_by_name`
/// (who fronted the money for the trip).
///
/// Saving uses the server function `save_trip_split` (L5: replaces the
/// shares in one transaction and keeps the paid state of a share whose
/// amount did not change); while it is missing it falls back to inserting
/// the new rows before deleting the old ones.
class ExpenseSplitService {
  ExpenseSplitService._(this._backend);
  static final ExpenseSplitService instance = ExpenseSplitService._(
    SupabaseSplitBackend(),
  );

  /// A service on [backend], for tests.
  @visibleForTesting
  factory ExpenseSplitService.withBackend(SplitBackend backend) =
      ExpenseSplitService._;

  final SplitBackend _backend;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Splits [historyId]'s cost among [shares] (in "Wer teilt?" order).
  /// [paidByUserId]/[paidByName] record who actually paid at checkout — a
  /// name-only payer (someone without an app account) has [paidByName] set
  /// and [paidByUserId] null; when neither is given the current user is
  /// assumed to have paid. The payer's own share is saved as paid, since
  /// they settled it at the register. [splitMode] is `equal` or `custom`.
  /// Replaces any existing splits for this trip.
  Future<List<ExpenseSplit>> createSplits({
    required String historyId,
    required double totalCost,
    required List<SplitShare> shares,
    String? paidByUserId,
    String? paidByName,
    String splitMode = 'custom',
  }) async {
    final currentUserId = _backend.currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    final effectivePaidByUserId = (paidByUserId == null && paidByName == null)
        ? currentUserId
        : paidByUserId;

    try {
      final rows = await _backend.saveSplitRpc(
        historyId: historyId,
        totalCost: totalCost,
        paidByUserId: paidByUserId,
        paidByName: paidByName,
        splitMode: splitMode,
        shares: [
          for (final s in shares)
            {
              'user_id': s.userId,
              'participant_name': s.participantName,
              'amount': s.amount,
            },
        ],
      );
      return rows.map(ExpenseSplit.fromJson).toList();
    } catch (e) {
      if (!isMissingServerFeature(e)) rethrow;
      debugPrint('⚠️ [SPLIT] Split function missing, using inserts');
    }

    final oldIds = await _backend.splitIds(historyId);

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
        ? const <Map<String, dynamic>>[]
        : await _backend.insertSplits(rows);

    await _backend.updateTripPayment(historyId, {
      'total_cost': totalCost,
      'paid_by_user_id': effectivePaidByUserId,
      'paid_by_name': paidByName,
    });

    if (oldIds.isNotEmpty) await _backend.deleteSplits(oldIds);

    return inserted.map(ExpenseSplit.fromJson).toList();
  }

  /// Saves a split in cents (V7): [shareCents] in the order of
  /// [participants]; they must add up to [totalCents].
  Future<List<ExpenseSplit>> saveSplit({
    required String historyId,
    required int totalCents,
    required List<SplitShare> participants,
    required List<int> shareCents,
    required bool equal,
    String? paidByUserId,
    String? paidByName,
  }) {
    if (participants.length != shareCents.length ||
        !sharesAddUp(totalCents, shareCents)) {
      throw ArgumentError('Shares do not add up to the amount');
    }
    return createSplits(
      historyId: historyId,
      totalCost: centsToEuros(totalCents),
      shares: [
        for (var i = 0; i < participants.length; i++)
          SplitShare(
            userId: participants[i].userId,
            participantName: participants[i].participantName,
            amount: centsToEuros(shareCents[i]),
          ),
      ],
      paidByUserId: paidByUserId,
      paidByName: paidByName,
      splitMode: equal ? 'equal' : 'custom',
    );
  }

  Future<List<ExpenseSplit>> getSplitsForHistory(String historyId) async {
    final response = await _supabase
        .from('expense_splits')
        .select()
        .eq('history_id', historyId)
        .order('created_at');

    final splits = (response as List)
        .map((j) => ExpenseSplit.fromJson(j as Map<String, dynamic>))
        .toList();
    splits.sort((a, b) => a.position.compareTo(b.position));
    return splits;
  }

  /// Marks a share paid or open again. Never throws: null when it could not
  /// be saved (offline, not allowed), so the caller restores the row and
  /// shows "Nicht gespeichert". The other side gets a push in the
  /// background; a failed push never fails the toggle.
  Future<ExpenseSplit?> setPaid(String splitId, bool isPaid) async {
    try {
      final split = ExpenseSplit.fromJson(
        await _backend.updatePaid(splitId, isPaid),
      );
      unawaited(_notifySplitStatusChanged(split, isPaid));
      return split;
    } catch (e) {
      debugPrint('❌ [SPLIT] Paid state not saved: ${e.runtimeType}');
      return null;
    }
  }

  /// Open shares that involve the signed-in person plus those settled in
  /// the last 30 days (V8, L8): `open_split_shares` on the server, else the
  /// two older queries.
  Future<List<OpenShare>> getOpenShares() async {
    final me = _backend.currentUserId;
    if (me == null) return const [];
    try {
      final rows = await _backend.openSharesRpc();
      return [for (final row in rows) OpenShare.fromRpc(row)];
    } catch (e) {
      if (!isMissingServerFeature(e)) rethrow;
    }
    final owedToMe = await getTripsAwaitingPaymentToMe();
    final iOwe = await getTripsIOwe();
    return [
      for (final trip in [...owedToMe, ...iOwe])
        for (final split in trip.splits)
          if (!split.isPaid &&
              (trip.paidByUserId == me) != (split.userId == me))
            OpenShare(
              splitId: split.id,
              historyId: trip.historyId,
              userId: split.userId,
              participantName: split.participantName,
              amountCents: split.amountCents,
              isPaid: split.isPaid,
              paidAt: split.paidAt,
              position: split.position,
              listName: trip.listName,
              completedAt: trip.completedAt,
              totalCostCents: eurosToCents(trip.totalCost),
              paidByUserId: trip.paidByUserId,
              paidByName: trip.paidByName,
            ),
    ];
  }

  /// Tells the participant that the payer marked their share paid or open
  /// again (`notif_split_paid`, `notif_split_reopened`, V14). Skips
  /// name-only people and never notifies the person who tapped. Texts are in
  /// the sender's app language until the server sends localized pushes
  /// (OPEN-ISSUES).
  Future<void> _notifySplitStatusChanged(ExpenseSplit split, bool isPaid) async {
    try {
      final actorId = _backend.currentUserId;
      if (actorId == null) return;

      final trip = await _supabase
          .from('shopping_history')
          .select('list_name, paid_by_user_id')
          .eq('id', split.historyId)
          .maybeSingle();
      if (trip == null) return;

      final payerId = trip['paid_by_user_id'] as String?;
      final listName = trip['list_name'] as String? ?? '';
      final recipient = split.userId;
      if (actorId != payerId || recipient == null || recipient == actorId) {
        return;
      }

      final lang = pushLanguageCode();
      String? actorName;
      try {
        final profile = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', actorId)
            .maybeSingle();
        actorName = profile?['display_name'] as String?;
      } catch (_) {}
      final name = (actorName == null || actorName.trim().isEmpty)
          ? AppTranslations.get('hist_member_unknown', lang)
          : actorName;

      await PushNotificationService.instance.sendToUsers(
        userIds: [recipient],
        title: listName,
        body: AppTranslations.get(
          isPaid ? 'notif_split_paid' : 'notif_split_reopened',
          lang,
          params: {
            'name': name,
            'amount': formatEuroCents(split.amountCents, lang),
          },
        ),
        data: {
          'type': 'expense_split',
          'history_id': split.historyId,
          'is_paid': isPaid,
        },
      );
      debugPrint('✅ [SPLIT] Notified the participant of the paid change');
    } catch (e) {
      debugPrint('⚠️ [SPLIT] Could not send paid-status notification: $e');
    }
  }

  /// Trips the current user paid for that still have unpaid participants —
  /// "X still owes you" — for the home-screen status banner.
  Future<List<TripSplitSummary>> getTripsAwaitingPaymentToMe() async {
    final userId = _backend.currentUserId;
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
    final userId = _backend.currentUserId;
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
    final userId = _backend.currentUserId;
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

/// [SplitBackend] on Supabase.
class SupabaseSplitBackend implements SplitBackend {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  String? get currentUserId => _db.auth.currentUser?.id;

  @override
  Future<List<Map<String, dynamic>>> saveSplitRpc({
    required String historyId,
    required double totalCost,
    required String? paidByUserId,
    required String? paidByName,
    required String splitMode,
    required List<Map<String, dynamic>> shares,
  }) async {
    final rows = await _db.rpc<dynamic>(
      'save_trip_split',
      params: {
        'p_trip_id': historyId,
        'p_total_cost': totalCost,
        'p_paid_by_user_id': paidByUserId,
        'p_paid_by_name': paidByName,
        'p_split_mode': splitMode,
        'p_shares': shares,
      },
    );
    return [
      for (final row in rows as List) Map<String, dynamic>.from(row as Map),
    ];
  }

  @override
  Future<List<String>> splitIds(String historyId) async {
    final rows = await _db
        .from('expense_splits')
        .select('id')
        .eq('history_id', historyId);
    return [for (final r in rows) r['id'] as String];
  }

  @override
  Future<List<Map<String, dynamic>>> insertSplits(
    List<Map<String, dynamic>> rows,
  ) => _db.from('expense_splits').insert(rows).select();

  @override
  Future<void> updateTripPayment(
    String historyId,
    Map<String, dynamic> values,
  ) => _db.from('shopping_history').update(values).eq('id', historyId);

  @override
  Future<void> deleteSplits(List<String> ids) =>
      _db.from('expense_splits').delete().inFilter('id', ids);

  @override
  Future<Map<String, dynamic>> updatePaid(String splitId, bool isPaid) => _db
      .from('expense_splits')
      .update({
        'is_paid': isPaid,
        'paid_at': isPaid ? DateTime.now().toUtc().toIso8601String() : null,
      })
      .eq('id', splitId)
      .select()
      .single();

  @override
  Future<List<Map<String, dynamic>>> openSharesRpc() async {
    final rows = await _db.rpc<dynamic>('open_split_shares');
    return [
      for (final row in rows as List) Map<String, dynamic>.from(row as Map),
    ];
  }
}
