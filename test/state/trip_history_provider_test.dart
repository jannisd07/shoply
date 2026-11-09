import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/trip_checkout.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/trip_history_cache.dart';
import 'package:shoply/data/services/trip_push_queue.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';

import '../data/services/expense_split_service_test.dart'
    show FakeSplitBackend;
import '../data/services/shopping_history_service_test.dart'
    show FakeTripBackend, item, request;

ShoppingHistory trip(String id, DateTime at, {String? list}) => ShoppingHistory(
  id: id,
  userId: 'me',
  listId: list ?? 'l1',
  listName: 'Wocheneinkauf',
  totalItems: 3,
  completedAt: at,
);

/// The backend answers only when [gate] completes (slow network).
class SlowBackend extends FakeTripBackend {
  final gate = Completer<void>();

  @override
  Future<Map<String, dynamic>> completeTripRpc({
    required String listId,
    required List<String> itemIds,
    String? chainId,
    String? storeSource,
    double? totalCost,
    required bool splitPlanned,
  }) async {
    await gate.future;
    return super.completeTripRpc(
      listId: listId,
      itemIds: itemIds,
      chainId: chainId,
      storeSource: storeSource,
      totalCost: totalCost,
      splitPlanned: splitPlanned,
    );
  }
}

void main() {
  late SharedPreferences prefs;
  late TripHistoryCache cache;
  final now = DateTime(2026, 11, 9, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = TripHistoryCache(prefs);
  });

  TripHistoryController controller(FakeTripBackend backend) =>
      TripHistoryController(
        service: ShoppingHistoryService(backend: backend),
        userId: 'me',
        cache: cache,
        now: () => now,
      );

  test('shows the cached trips in the first frame, then the server page', () async {
    await cache.writeTrips('me', [trip('cached', now)], now: now);
    final backend = FakeTripBackend()..trips = [trip('server', now)];

    final c = controller(backend);
    expect(c.state.trips.map((t) => t.id), ['cached'], reason: 'sync');
    expect(c.state.isFirstLoad, isFalse);

    await pumpEventQueue();
    expect(c.state.trips.map((t) => t.id), ['server']);
    expect(c.state.synced, isTrue);
    expect(cache.readTrips('me').map((t) => t.id), ['server']);
  });

  test('a failed refresh keeps the last state and says so', () async {
    await cache.writeTrips('me', [trip('cached', now)], now: now);
    final c = TripHistoryController(
      service: ShoppingHistoryService(backend: _FailingBackend()),
      userId: 'me',
      cache: cache,
    );
    await pumpEventQueue();
    expect(c.state.trips.map((t) => t.id), ['cached']);
    expect(c.state.error, isNotNull);
  });

  test('checkout appends the trip at once and replaces it when saved', () async {
    final backend = SlowBackend();
    final c = controller(backend);
    await pumpEventQueue();

    final future = c.checkout(request(cents: 4280));
    final local = c.state.trips.first;
    expect(isLocalTripId(local.id), isTrue);
    expect(c.state.sending, {local.id});
    expect(local.totalCost, 42.8);

    backend.gate.complete();
    final result = await future;
    expect(result, isA<CheckoutSaved>());
    expect(c.state.trips.first.id, 'trip-1');
    expect(c.state.sending, isEmpty);
    expect(c.savedCheckout('trip-1'), isNotNull);
    expect(backend.pages, [null], reason: 'appended, not reloaded (Bug 3)');
  });

  test('a network error marks the trip "Nicht gespeichert"; retry saves it', () async {
    final backend = FakeTripBackend()..rpcError = Exception('offline');
    final c = controller(backend);
    await pumpEventQueue();

    final result = await c.checkout(request());
    expect(result, isA<CheckoutPending>());
    final localId = (result as CheckoutPending).localTripId;
    expect(result.failed, isTrue);
    expect(c.state.failed, {localId});
    expect(c.state.trips.single.id, localId);

    backend.rpcError = null;
    final again = await c.retry(localId);
    expect(again, isA<CheckoutSaved>());
    expect(c.state.failed, isEmpty);
    expect(c.state.trips.single.id, 'trip-1');
  });

  test('a rejection removes the local entry again', () async {
    final backend = FakeTripBackend(
      answer: {'status': 'already_completed', 'completed_by_name': 'Lena'},
    );
    final c = controller(backend);
    await pumpEventQueue();
    expect(await c.checkout(request()), isA<CheckoutAlreadyCompleted>());
    expect(c.state.trips, isEmpty);
  });

  test('undo takes the saved trip back', () async {
    final backend = FakeTripBackend();
    final c = controller(backend);
    await pumpEventQueue();
    await c.checkout(request());

    expect(await c.undo('trip-1'), UndoTripResult.undone);
    expect(c.state.trips, isEmpty);
    expect(backend.undoCalls.single, ('trip-1', 'tok'));
  });

  test('undo before the server answered cancels and takes it back', () async {
    final backend = SlowBackend();
    final c = controller(backend);
    await pumpEventQueue();
    final future = c.checkout(request());
    final localId = c.state.trips.first.id;

    expect(await c.undo(localId), UndoTripResult.undone);
    expect(c.state.trips, isEmpty);
    backend.gate.complete();
    await future;
    await pumpEventQueue();
    expect(c.state.trips, isEmpty);
    expect(backend.undoCalls, hasLength(1), reason: 'the late save is undone');
  });

  test('undo with the local id after a late save undoes the server trip (C1)', () async {
    final backend = SlowBackend();
    final c = controller(backend);
    await pumpEventQueue();
    // V1 closed after its 2 s wait: the toast holds the local id.
    final future = c.checkout(request());
    final localId = c.state.trips.first.id;
    backend.gate.complete();
    expect(await future, isA<CheckoutSaved>());
    expect(c.state.trips.single.id, 'trip-1');

    expect(await c.undo(localId), UndoTripResult.undone);
    expect(backend.undoCalls.single, ('trip-1', 'tok'));
    expect(c.state.trips, isEmpty);
  });

  test('a toast gone before the save releases the push once saved', () async {
    final backend = SlowBackend();
    final sent = <String>[];
    final c = TripHistoryController(
      service: ShoppingHistoryService(backend: backend),
      userId: 'me',
      cache: cache,
      pushes: _queue(prefs, sent),
    );
    await pumpEventQueue();
    final future = c.checkout(
      CheckoutRequest(
        listId: 'l1',
        listName: 'WG',
        checkedItems: [item('a')],
        notifyUserIds: const ['lena'],
      ),
    );
    final localId = c.state.trips.first.id;
    c.release(localId);
    backend.gate.complete();
    await future;
    await pumpEventQueue();
    expect(sent, hasLength(1));
    expect(c.savedCheckout('trip-1'), isNotNull, reason: 'undo stays possible');
  });

  test('a refused undo keeps the trip', () async {
    final backend = FakeTripBackend()..undoStatus = 'split_by_other';
    final c = controller(backend);
    await pumpEventQueue();
    await c.checkout(request());
    expect(await c.undo('trip-1'), UndoTripResult.refused);
    expect(c.state.trips.single.id, 'trip-1');
  });

  test('deleteTrip restores the row when the server refuses', () async {
    final backend = FakeTripBackend()..trips = [trip('not-mine', now)];
    final c = controller(backend);
    await pumpEventQueue();
    await expectLater(c.deleteTrip('not-mine'), throwsStateError);
    expect(c.state.trips.single.id, 'not-mine');
  });

  test('the cache keeps 3 months and at least 50 trips', () {
    final trips = [
      for (var i = 0; i < 60; i++)
        trip('t$i', now.subtract(Duration(days: 10 * i))),
    ];
    final kept = TripHistoryCache.trimToWindow(trips, now: now);
    expect(kept, hasLength(50));
    final recent = [
      for (var i = 0; i < 60; i++) trip('r$i', now.subtract(Duration(hours: i))),
    ];
    expect(TripHistoryCache.trimToWindow(recent, now: now), hasLength(60));
  });

  group('summaries for Teil A (A-V12)', () {
    test('historyEntrySummaryProvider counts this month, synchronously', () async {
      final backend = FakeTripBackend()
        ..trips = [
          trip('a', DateTime(2026, 11, 2)),
          trip('b', DateTime(2026, 11, 8)),
          trip('c', DateTime(2026, 10, 30)),
        ];
      final container = ProviderContainer(
        overrides: [
          authUserIdProvider.overrideWithValue('me'),
          tripHistoryCacheProvider.overrideWithValue(cache),
          historyClockProvider.overrideWithValue(() => now),
          tripHistoryProvider.overrideWith(
            (ref) => controller(backend),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(historyEntrySummaryProvider).hasTrips, isFalse);
      await pumpEventQueue();
      final summary = container.read(historyEntrySummaryProvider);
      expect(summary.tripsThisMonth, 2);
      expect(summary.month, DateTime(2026, 11));
      expect(summary.hasTrips, isTrue);
    });

    test('openBalancesSummaryProvider sums both directions, null when off', () async {
      OpenShare share(String id, {String? user, String? payer, int cents = 500, bool paid = false}) =>
          OpenShare(
            splitId: id,
            historyId: 'trip',
            userId: user,
            participantName: user ?? 'Tom',
            amountCents: cents,
            isPaid: paid,
            listName: 'WG',
            completedAt: now,
            paidByUserId: payer,
          );
      await cache.writeShares('me', [
        share('1', user: 'lena', payer: 'me', cents: 1230),
        share('2', payer: 'me', cents: 500), // Tom, name only
        share('3', user: 'me', payer: 'lena', cents: 1730),
        share('4', user: 'lena', payer: 'me', paid: true),
      ]);
      ProviderContainer make({required bool module}) => ProviderContainer(
        overrides: [
          authUserIdProvider.overrideWithValue('me'),
          tripHistoryCacheProvider.overrideWithValue(cache),
          moduleEnabledProvider.overrideWith((ref, m) => module),
          openSharesProvider.overrideWith(
            (ref) => OpenSharesController(
              service: _noServerSplits(),
              userId: 'me',
              cache: cache,
            ),
          ),
        ],
      );
      final on = make(module: true);
      addTearDown(on.dispose);
      final summary = on.read(openBalancesSummaryProvider)!;
      expect(summary.openCount, 3);
      expect(summary.owedToMeCents, 1730);
      expect(summary.iOweCents, 1730);
      expect(summary.totalOpenCents, 3460);
      expect(summary.people, 2, reason: 'Lena and Tom');

      final off = make(module: false);
      addTearDown(off.dispose);
      expect(off.read(openBalancesSummaryProvider), isNull);
    });
  });

  test('a saved trip queues the member push behind the undo window', () async {
    final backend = FakeTripBackend();
    final sent = <String>[];
    final c = TripHistoryController(
      service: ShoppingHistoryService(backend: backend),
      userId: 'me',
      cache: cache,
      pushes: _queue(prefs, sent),
    );
    await pumpEventQueue();
    await c.checkout(
      CheckoutRequest(
        listId: 'l1',
        listName: 'WG',
        checkedItems: [item('a'), item('b')],
        chainId: 'lidl',
        notifyUserIds: const ['me', 'lena'],
        actorName: 'Jannis',
      ),
    );
    await pumpEventQueue();
    expect(sent, isEmpty, reason: 'held until the toast is gone');
    c.release('trip-1');
    await pumpEventQueue();
    expect(sent.single, contains('Lidl'));
  });
}

class _FailingBackend extends FakeTripBackend {
  @override
  Future<List<ShoppingHistory>> fetchTrips({int? limit, DateTime? before}) =>
      Future.error(Exception('offline'));
}

/// Open shares come from the cache only in these tests.
class _OfflineSplits extends FakeSplitBackend {
  @override
  Future<List<Map<String, dynamic>>> openSharesRpc() =>
      Future.error(Exception('offline'));
}

ExpenseSplitService _noServerSplits() =>
    ExpenseSplitService.withBackend(_OfflineSplits());

TripPushQueue _queue(SharedPreferences prefs, List<String> sent) =>
    TripPushQueue(
      send:
          ({
            required List<String> userIds,
            required String title,
            required String body,
            Map<String, dynamic>? data,
          }) async => sent.add(body),
      prefs: () async => prefs,
    );
