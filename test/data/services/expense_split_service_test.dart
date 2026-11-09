import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/services/expense_split_service.dart';

/// A split backend without a server; [rpcMissing] answers like a database
/// without the migration `b_trip_checkout`.
class FakeSplitBackend implements SplitBackend {
  FakeSplitBackend({this.rpcMissing = false});

  bool rpcMissing;
  bool failPaid = false;
  final log = <String>[];
  final rpcShares = <List<Map<String, dynamic>>>[];
  String? rpcMode;
  List<Map<String, dynamic>> openRows = [];

  static const _missing = PostgrestException(
    message: 'Could not find the function public.save_trip_split',
    code: 'PGRST202',
  );

  Map<String, dynamic> _row(Map<String, dynamic> s, int i) => {
    'id': 'n$i',
    'history_id': 'trip',
    'user_id': s['user_id'],
    'participant_name': s['participant_name'],
    'amount': s['amount'],
    'is_paid': s['is_paid'] ?? false,
    'created_at': '2026-11-09T10:00:00Z',
    'updated_at': '2026-11-09T10:00:00Z',
    'position': i,
    'split_mode': rpcMode ?? 'custom',
  };

  @override
  String? get currentUserId => 'me';

  @override
  Future<List<Map<String, dynamic>>> saveSplitRpc({
    required String historyId,
    required double totalCost,
    required String? paidByUserId,
    required String? paidByName,
    required String splitMode,
    required List<Map<String, dynamic>> shares,
  }) async {
    log.add('rpc');
    if (rpcMissing) throw _missing;
    rpcMode = splitMode;
    rpcShares.add(shares);
    return [for (var i = 0; i < shares.length; i++) _row(shares[i], i)];
  }

  @override
  Future<List<String>> splitIds(String historyId) async {
    log.add('select');
    return ['old1', 'old2'];
  }

  @override
  Future<List<Map<String, dynamic>>> insertSplits(
    List<Map<String, dynamic>> rows,
  ) async {
    log.add('insert');
    return [for (var i = 0; i < rows.length; i++) _row(rows[i], i)];
  }

  @override
  Future<void> updateTripPayment(
    String historyId,
    Map<String, dynamic> values,
  ) async => log.add('trip');

  @override
  Future<void> deleteSplits(List<String> ids) async =>
      log.add('delete ${ids.join(',')}');

  @override
  Future<Map<String, dynamic>> updatePaid(String splitId, bool isPaid) async {
    if (failPaid) throw Exception('offline');
    return _row({
      'user_id': 'lena',
      'participant_name': 'Lena',
      'amount': 3.33,
      'is_paid': isPaid,
    }, 0);
  }

  @override
  Future<List<Map<String, dynamic>>> openSharesRpc() async => openRows;
}

void main() {
  const participants = [
    SplitShare(userId: 'me', participantName: 'Jannis', amount: 0),
    SplitShare(userId: 'lena', participantName: 'Lena', amount: 0),
    SplitShare(participantName: 'Tom', amount: 0),
  ];

  test('saves through save_trip_split with the mode and cents', () async {
    final backend = FakeSplitBackend();
    final service = ExpenseSplitService.withBackend(backend);

    final splits = await service.saveSplit(
      historyId: 'trip',
      totalCents: 1000,
      participants: participants,
      shareCents: const [334, 333, 333],
      equal: true,
    );

    expect(backend.log, ['rpc'], reason: 'no insert-then-delete');
    expect(backend.rpcMode, 'equal');
    expect([for (final s in backend.rpcShares.single) s['amount']], [
      3.34,
      3.33,
      3.33,
    ]);
    expect(splits.map((s) => s.position), [0, 1, 2]);
    expect(splits.first.splitMode, 'equal');
  });

  test('refuses shares that do not add up', () {
    final service = ExpenseSplitService.withBackend(FakeSplitBackend());
    expect(
      () => service.saveSplit(
        historyId: 'trip',
        totalCents: 1000,
        participants: participants,
        shareCents: const [333, 333, 333],
        equal: true,
      ),
      throwsArgumentError,
    );
  });

  test('without the migration: inserts first, deletes the old rows last', () async {
    final backend = FakeSplitBackend(rpcMissing: true);
    final splits = await ExpenseSplitService.withBackend(backend).saveSplit(
      historyId: 'trip',
      totalCents: 1000,
      participants: participants,
      shareCents: const [334, 333, 333],
      equal: true,
    );

    expect(backend.log, ['rpc', 'select', 'insert', 'trip', 'delete old1,old2']);
    expect(splits, hasLength(3));
    expect(splits.first.isPaid, isTrue, reason: "the payer's own share");
    expect(splits[1].isPaid, isFalse);
  });

  test('setPaid never throws: null when it was not saved', () async {
    final backend = FakeSplitBackend()..failPaid = true;
    final service = ExpenseSplitService.withBackend(backend);
    expect(await service.setPaid('s1', true), isNull);

    backend.failPaid = false;
    final saved = await service.setPaid('s1', true);
    expect(saved?.isPaid, isTrue);
  });

  test('open shares come from open_split_shares in cents', () async {
    final backend = FakeSplitBackend()
      ..openRows = [
        {
          'split_id': 's1',
          'history_id': 'trip',
          'user_id': 'lena',
          'participant_name': 'Lena',
          'amount': 3.33,
          'is_paid': false,
          'paid_at': null,
          'split_position': 1,
          'list_id': 'l1',
          'list_name': 'WG',
          'completed_at': '2026-11-09T10:00:00Z',
          'total_cost': 10.0,
          'paid_by_user_id': 'me',
          'paid_by_name': null,
          'store_chain': 'lidl',
        },
      ];
    final shares = await ExpenseSplitService.withBackend(backend).getOpenShares();
    expect(shares.single.amountCents, 333);
    expect(shares.single.totalCostCents, 1000);
    expect(shares.single.isOwedTo('me'), isTrue);
    expect(shares.single.isOwedBy('me'), isFalse);
  });
}
