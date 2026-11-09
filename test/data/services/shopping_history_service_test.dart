import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/trip_checkout.dart';
import 'package:shoply/data/services/shopping_history_service.dart';

/// A history backend without a server. [rpcMissing] answers like a database
/// without the migration `b_trip_checkout`.
class FakeTripBackend implements TripHistoryBackend {
  FakeTripBackend({this.rpcMissing = false, this.answer});

  bool rpcMissing;
  Map<String, dynamic>? answer;
  Object? rpcError;
  bool listThere = true;
  String undoStatus = 'undone';

  final rpcCalls = <Map<String, Object?>>[];
  final insertedTrips = <Map<String, dynamic>>[];
  final insertedItems = <Map<String, dynamic>>[];
  final removed = <String>[];
  final restored = <String>[];
  final deleted = <String>[];
  final undoCalls = <(String, String)>[];
  List<ShoppingHistory> trips = [];
  final pages = <DateTime?>[];

  static const _missing = PostgrestException(
    message: 'Could not find the function public.complete_shopping_trip',
    code: 'PGRST202',
  );

  @override
  String? get currentUserId => 'me';

  @override
  Future<Map<String, dynamic>> completeTripRpc({
    required String listId,
    required List<String> itemIds,
    String? chainId,
    String? storeSource,
    double? totalCost,
    required bool splitPlanned,
  }) async {
    rpcCalls.add({
      'list': listId,
      'items': itemIds,
      'chain': chainId,
      'source': storeSource,
      'cost': totalCost,
      'split': splitPlanned,
    });
    if (rpcMissing) throw _missing;
    if (rpcError != null) throw rpcError!;
    return answer ??
        {
          'status': 'saved',
          'trip_id': 'trip-1',
          'undo_token': 'tok',
          'total_items': itemIds.length,
          'completed_at': '2026-11-09T10:00:00Z',
          'completed_by_name': 'Jannis',
        };
  }

  @override
  Future<String> undoTripRpc(String tripId, String token) async {
    undoCalls.add((tripId, token));
    if (rpcMissing) throw _missing;
    return undoStatus;
  }

  @override
  Future<String?> currentUserName() async => 'Jannis';

  @override
  Future<bool> listExists(String listId) async => listThere;

  @override
  Future<String> insertTrip(Map<String, dynamic> row) async {
    insertedTrips.add(row);
    return 'legacy-1';
  }

  @override
  Future<void> insertTripItems(List<Map<String, dynamic>> rows) async =>
      insertedItems.addAll(rows);

  /// Ids a member unchecked meanwhile (server state).
  final uncheckedOnServer = <String>{};

  @override
  Future<Set<String>> checkedItemIds(String listId, List<String> itemIds) async =>
      {for (final id in itemIds) if (!uncheckedOnServer.contains(id)) id};

  @override
  Future<void> removeListItems(String listId, List<String> itemIds) async =>
      removed.addAll(itemIds);

  @override
  Future<void> restoreListItems(
    String listId,
    List<ShoppingItemModel> items,
  ) async => restored.addAll([for (final i in items) i.name]);

  @override
  Future<bool> deleteTrip(String tripId) async {
    deleted.add(tripId);
    return tripId != 'not-mine';
  }

  @override
  Future<ShoppingHistory?> fetchTrip(String tripId) async =>
      trips.where((t) => t.id == tripId).firstOrNull;

  @override
  Future<List<ShoppingHistory>> fetchTrips({
    int? limit,
    DateTime? before,
  }) async {
    pages.add(before);
    final older = [
      for (final t in trips)
        if (before == null || t.completedAt.isBefore(before)) t,
    ];
    return limit == null ? older : older.take(limit).toList();
  }

  @override
  Future<List<ShoppingHistory>> fetchTripsForList(String listId) async => [
    for (final t in trips)
      if (t.listId == listId) t,
  ];

  @override
  Future<void> deleteOwnTrips() async => trips.clear();

  final tracked = <String>[];

  @override
  Future<void> trackPurchases(List<ShoppingItemModel> items) async =>
      tracked.addAll([for (final i in items) i.id]);
}

ShoppingItemModel item(
  String id, {
  bool checked = true,
  double? price,
  double? old,
  String? retailer,
}) => ShoppingItemModel(
  id: id,
  listId: 'l1',
  name: 'Item $id',
  isChecked: checked,
  createdAt: DateTime(2026, 11, 9),
  updatedAt: DateTime(2026, 11, 9),
  price: price,
  priceOldValue: old,
  priceRetailer: retailer,
);

CheckoutRequest request({
  List<ShoppingItemModel>? items,
  String? chainId = 'lidl',
  int? cents,
}) => CheckoutRequest(
  listId: 'l1',
  listName: 'Wocheneinkauf',
  checkedItems: items ?? [item('a'), item('b'), item('c', checked: false)],
  chainId: chainId,
  storeSource: TripStoreSource.list,
  totalCostCents: cents,
);

void main() {
  group('completeTrip with the server function (L1)', () {
    test('sends only checked items, the chain and the typed amount', () async {
      final backend = FakeTripBackend();
      final service = ShoppingHistoryService(backend: backend);

      final result = await service.completeTrip(request(cents: 4280));

      expect(result, isA<CheckoutSaved>());
      final call = backend.rpcCalls.single;
      expect(call['items'], ['a', 'b']);
      expect(call['chain'], 'lidl');
      expect(call['source'], 'list');
      expect(call['cost'], 42.8);
      final saved = result as CheckoutSaved;
      expect(saved.trip.id, 'trip-1');
      expect(saved.trip.storeChainId, 'lidl');
      expect(saved.trip.totalCost, 42.8);
      expect(saved.trip.totalCostSource, 'user');
      expect(saved.trip.totalItems, 2);
      expect(saved.undoToken, 'tok');
      expect(saved.legacy, isFalse);
      expect(backend.insertedTrips, isEmpty, reason: 'no separate inserts');
    });

    test('never takes the amount from offer prices (Bug 7)', () async {
      final backend = FakeTripBackend();
      final service = ShoppingHistoryService(backend: backend);
      final result = await service.completeTrip(
        request(items: [item('a', price: 1.99, old: 2.49)]),
      );
      expect(backend.rpcCalls.single['cost'], isNull);
      expect((result as CheckoutSaved).trip.totalCost, isNull);
    });

    test('an unknown chain id is not stored', () async {
      final backend = FakeTripBackend();
      await ShoppingHistoryService(
        backend: backend,
      ).completeTrip(request(chainId: 'Lidl Freiburg Hbf'));
      expect(backend.rpcCalls.single['chain'], isNull);
      expect(backend.rpcCalls.single['source'], isNull);
    });

    test('a member who was faster comes back as already completed', () async {
      final backend = FakeTripBackend(
        answer: {
          'status': 'already_completed',
          'trip_id': 'lena-trip',
          'completed_by_name': 'Lena',
        },
      );
      final result = await ShoppingHistoryService(
        backend: backend,
      ).completeTrip(request());
      expect(result, isA<CheckoutAlreadyCompleted>());
      expect((result as CheckoutAlreadyCompleted).byName, 'Lena');
      expect(result.tripId, 'lena-trip');
    });

    test('a deleted list comes back as list gone', () async {
      final backend = FakeTripBackend(answer: {'status': 'list_gone'});
      expect(
        await ShoppingHistoryService(backend: backend).completeTrip(request()),
        isA<CheckoutListGone>(),
      );
    });

    test('nothing checked never calls the server', () async {
      final backend = FakeTripBackend();
      final result = await ShoppingHistoryService(
        backend: backend,
      ).completeTrip(request(items: [item('a', checked: false)]));
      expect(result, isA<CheckoutNothingChecked>());
      expect(backend.rpcCalls, isEmpty);
    });

    test('a network error is thrown, not hidden', () async {
      final backend = FakeTripBackend()..rpcError = Exception('offline');
      expect(
        ShoppingHistoryService(backend: backend).completeTrip(request()),
        throwsException,
      );
    });
  });

  group('completeTrip without the migration (fallback)', () {
    test('saves with today\'s inserts and removes the items', () async {
      final backend = FakeTripBackend(rpcMissing: true);
      final result = await ShoppingHistoryService(
        backend: backend,
      ).completeTrip(request(cents: 1000));

      final saved = result as CheckoutSaved;
      expect(saved.legacy, isTrue);
      expect(saved.trip.id, 'legacy-1');
      expect(saved.restoreItems.map((i) => i.id), ['a', 'b']);
      final row = backend.insertedTrips.single;
      expect(row.containsKey('store_chain'), isFalse, reason: 'old schema');
      expect(row['total_cost'], 10.0);
      expect(row['total_items'], 2);
      expect(backend.insertedItems, hasLength(2));
      expect(
        backend.insertedItems.first['price_retailer'],
        'Lidl',
        reason: 'the market goes into the retailer as before',
      );
      expect(backend.removed, ['a', 'b']);
    });

    test('keeps an item\'s own offer retailer', () async {
      final backend = FakeTripBackend(rpcMissing: true);
      await ShoppingHistoryService(backend: backend).completeTrip(
        request(items: [item('a', price: 1, old: 2, retailer: 'REWE')]),
      );
      expect(backend.insertedItems.single['price_retailer'], 'REWE');
    });

    test('an item a member unchecked meanwhile stays on the list (I1)', () async {
      final backend = FakeTripBackend(rpcMissing: true)..uncheckedOnServer.add('b');
      final saved = await ShoppingHistoryService(
        backend: backend,
      ).completeTrip(request()) as CheckoutSaved;
      expect(backend.removed, ['a']);
      expect(backend.insertedItems.map((r) => r['name']), ['Item a']);
      expect(backend.insertedTrips.single['total_items'], 1);
      expect(saved.restoreItems.map((i) => i.id), ['a']);
    });

    test('everything taken back meanwhile: nothing saved', () async {
      final backend = FakeTripBackend(rpcMissing: true)
        ..uncheckedOnServer.addAll(['a', 'b']);
      expect(
        await ShoppingHistoryService(backend: backend).completeTrip(request()),
        isA<CheckoutNothingChecked>(),
      );
      expect(backend.insertedTrips, isEmpty);
      expect(backend.removed, isEmpty);
    });

    test('a list that is gone saves nothing', () async {
      final backend = FakeTripBackend(rpcMissing: true)..listThere = false;
      final result = await ShoppingHistoryService(
        backend: backend,
      ).completeTrip(request());
      expect(result, isA<CheckoutListGone>());
      expect(backend.insertedTrips, isEmpty);
    });
  });

  group('undoTrip', () {
    test('uses the token with the server function', () async {
      final backend = FakeTripBackend();
      final service = ShoppingHistoryService(backend: backend);
      final saved = await service.completeTrip(request()) as CheckoutSaved;

      expect(await service.undoTrip(saved), UndoTripResult.undone);
      expect(backend.undoCalls.single, ('trip-1', 'tok'));
    });

    test('a refusal (split by a member) is reported', () async {
      final backend = FakeTripBackend()..undoStatus = 'split_by_other';
      final service = ShoppingHistoryService(backend: backend);
      final saved = await service.completeTrip(request()) as CheckoutSaved;
      expect(await service.undoTrip(saved), UndoTripResult.refused);
    });

    test('fallback: deletes the trip and puts the items back', () async {
      final backend = FakeTripBackend(rpcMissing: true);
      final service = ShoppingHistoryService(backend: backend);
      final saved = await service.completeTrip(request()) as CheckoutSaved;

      expect(await service.undoTrip(saved), UndoTripResult.undone);
      expect(backend.restored, ['Item a', 'Item b']);
      expect(backend.deleted, ['legacy-1']);
      expect(backend.undoCalls, isEmpty);
    });
  });

  test('isMissingServerFeature knows the PostgREST codes only', () {
    expect(
      isMissingServerFeature(
        const PostgrestException(message: 'x', code: 'PGRST202'),
      ),
      isTrue,
    );
    expect(
      isMissingServerFeature(
        const PostgrestException(
          message: 'column "store_chain" does not exist',
          code: '42703',
        ),
      ),
      isTrue,
    );
    expect(
      isMissingServerFeature(
        const PostgrestException(message: 'not a member', code: '42501'),
      ),
      isFalse,
    );
    expect(isMissingServerFeature(Exception('offline')), isFalse);
  });

  test('deleteHistory throws when no row was deleted (Bug 4)', () async {
    final service = ShoppingHistoryService(backend: FakeTripBackend());
    await service.deleteHistory('mine');
    expect(service.deleteHistory('not-mine'), throwsStateError);
  });

  group('ShoppingHistory.fromJson (L2)', () {
    Map<String, dynamic> row({String? chain, List<String?> retailers = const []}) => {
      'id': 't',
      'user_id': 'me',
      'list_name': 'L',
      'total_items': retailers.length,
      'completed_at': '2026-11-09T10:00:00Z',
      'store_chain': chain,
      'items': [
        for (var i = 0; i < retailers.length; i++)
          {
            'id': 'i$i',
            'history_id': 't',
            'name': 'n$i',
            'price_retailer': retailers[i],
          },
      ],
    };

    test('reads the stored chain id', () {
      expect(ShoppingHistory.fromJson(row(chain: 'rewe')).storeChainId, 'rewe');
    });

    test('normalises old OSM names through the chain directory', () {
      final trip = ShoppingHistory.fromJson(
        row(retailers: ['Lidl Freiburg-Haslach', 'LIDL', 'REWE']),
      );
      expect(trip.storeChainId, 'lidl');
    });

    test('round-trips through the cache json', () {
      final trip = ShoppingHistory.fromJson(row(chain: 'lidl', retailers: ['Lidl']));
      final again = ShoppingHistory.fromJson(trip.toCacheJson());
      expect(again, trip);
    });
  });

  group('totalSavingsOf counts only offers of the trip\'s market (L4)', () {
    ShoppingHistory trip(String? chain, List<(String?, double, double)> items) =>
        ShoppingHistory(
          id: 't',
          userId: 'me',
          listName: 'L',
          totalItems: items.length,
          completedAt: DateTime(2026, 11, 9),
          storeChainId: chain,
          items: [
            for (final (retailer, price, old) in items)
              ShoppingHistoryItem(
                id: '$retailer$price',
                historyId: 't',
                name: 'x',
                price: price,
                priceOldValue: old,
                priceRetailer: retailer,
              ),
          ],
        );

    test('another chain\'s offer saves nothing at this market', () {
      final t = trip('lidl', [('Lidl', 1.0, 2.0), ('REWE', 1.0, 3.0)]);
      expect(totalSavingsOf([t]), closeTo(1.0, 0.001));
    });

    test('without a market every offer counts as before', () {
      final t = trip(null, [('Lidl', 1.0, 2.0), ('REWE', 1.0, 3.0)]);
      expect(totalSavingsOf([t]), closeTo(3.0, 0.001));
    });
  });
}
