import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/trip_checkout.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/trip_history_cache.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_push_queue.dart';
import 'package:shoply/data/services/trip_split_math.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';

/// Prefix of trips that only exist on this device so far.
const String localTripPrefix = 'local-';

/// Whether [tripId] is a trip that has not reached the server yet.
bool isLocalTripId(String tripId) => tripId.startsWith(localTripPrefix);

/// How long trip pushes wait at most for "Widerrufen" (the chain V1 → V3 →
/// V7 can take a while; the toast releases them earlier). With VoiceOver the
/// toast can stay as long as its focus rests on it, so only this hold ends
/// the wait there (A-V24 asks for a dismissal callback).
const Duration tripPushHold = Duration(minutes: 2);

/// How long V1 waits online for a synchronous "no" (list gone, a member was
/// faster) before it closes and the save continues behind the history row.
const Duration checkoutRejectWait = Duration(seconds: 2);

/// When the undo toast is surely gone without VoiceOver (A's toast stays 4 s
/// and pauses only for VoiceOver focus): then the pushes may go.
const Duration checkoutToastGone = Duration(seconds: 5);

/// The server accepts "Widerrufen" this long (`undo_expires_at`, 15 min),
/// longer than any client window, so a late tap never fails for time.
const Duration tripUndoServerWindow = Duration(minutes: 15);

// ------------------------------------------------------------------ trips

/// The history as the app shows it: newest first, local first (L3).
@immutable
class TripHistoryState {
  const TripHistoryState({
    this.trips = const [],
    this.sending = const {},
    this.failed = const {},
    this.synced = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  /// Every known trip, newest first, including local ones not yet saved.
  final List<ShoppingHistory> trips;

  /// Trips on their way to the server (sync mark).
  final Set<String> sending;

  /// Trips that failed to save ("Nicht gespeichert", tap retries).
  final Set<String> failed;

  /// Whether the server answered at least once since the start.
  final bool synced;

  /// A further page is loading.
  final bool loadingMore;

  /// The server may have older trips than [trips].
  final bool hasMore;

  /// The last refresh failed (offline, server); [trips] stays the last state.
  final Object? error;

  /// Nothing to show yet: no cache and no server answer (skeleton).
  bool get isFirstLoad => trips.isEmpty && !synced && error == null;

  TripHistoryState copyWith({
    List<ShoppingHistory>? trips,
    Set<String>? sending,
    Set<String>? failed,
    bool? synced,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) => TripHistoryState(
    trips: trips ?? this.trips,
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    synced: synced ?? this.synced,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Reads, extends and changes the history (L3) and runs "Einkauf speichern"
/// optimistically (V1): the trip is in the list at once, the server call
/// runs behind it, a failure marks it "Nicht gespeichert".
class TripHistoryController extends StateNotifier<TripHistoryState> {
  TripHistoryController({
    required ShoppingHistoryService service,
    required this.userId,
    TripHistoryCache? cache,
    TripPushQueue? pushes,
    DateTime Function()? now,
  }) : _service = service,
       _cache = cache,
       _pushes = pushes,
       _now = now ?? DateTime.now,
       super(
         TripHistoryState(
           trips: userId == null || cache == null
               ? const []
               : cache.readTrips(userId),
           synced: userId == null,
           hasMore: userId != null,
         ),
       ) {
    if (userId != null) {
      unawaited(refresh());
      unawaited(_pushes?.flushDue());
    }
  }

  final ShoppingHistoryService _service;
  final TripHistoryCache? _cache;
  final TripPushQueue? _pushes;
  final DateTime Function() _now;

  /// Whose history this is; null signed out.
  final String? userId;

  final Map<String, CheckoutRequest> _requests = {};
  final Map<String, CheckoutSaved> _saved = {};
  final Set<String> _cancelled = {};

  /// Local id → server id once a late answer saved the trip, so the toast
  /// bound to the local id still undoes and releases the right trip.
  final Map<String, String> _localToServer = {};

  /// Trips whose toast is gone before they were saved: release at once.
  final Set<String> _releasedEarly = {};
  int _localSeq = 0;

  /// The saved checkout of [tripId] while its undo is possible.
  CheckoutSaved? savedCheckout(String tripId) => _saved[tripId];

  /// The newest page from the server; keeps older cached trips and local
  /// ones. Never throws: a failure stays in [TripHistoryState.error].
  Future<void> refresh() async {
    if (userId == null) return;
    try {
      final page = await _service.getHistoryPage();
      if (!mounted) return;
      final ids = {for (final t in page) t.id};
      final oldest = page.isEmpty ? null : page.last.completedAt;
      final local = [
        for (final t in state.trips)
          if (isLocalTripId(t.id)) t,
      ];
      // Cached trips inside the page's time range that the server no longer
      // has were deleted elsewhere; older ones stay until the next page.
      final older = [
        for (final t in state.trips)
          if (!isLocalTripId(t.id) &&
              !ids.contains(t.id) &&
              oldest != null &&
              page.length >= ShoppingHistoryService.pageSize &&
              t.completedAt.isBefore(oldest))
            t,
      ];
      state = state.copyWith(
        trips: _sorted([...local, ...page, ...older]),
        synced: true,
        hasMore: page.length >= ShoppingHistoryService.pageSize,
        clearError: true,
      );
      _persist();
    } catch (e) {
      debugPrint('⚠️ [HISTORY] Refresh failed: ${e.runtimeType}');
      if (mounted) state = state.copyWith(error: e);
    }
  }

  /// The next [ShoppingHistoryService.pageSize] older trips.
  Future<void> loadMore() async {
    if (userId == null || state.loadingMore || !state.hasMore) return;
    final saved = [
      for (final t in state.trips)
        if (!isLocalTripId(t.id)) t,
    ];
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _service.getHistoryPage(
        before: saved.isEmpty ? null : saved.last.completedAt,
      );
      if (!mounted) return;
      final known = {for (final t in state.trips) t.id};
      state = state.copyWith(
        trips: _sorted([
          ...state.trips,
          for (final t in page)
            if (!known.contains(t.id)) t,
        ]),
        loadingMore: false,
        hasMore: page.length >= ShoppingHistoryService.pageSize,
      );
    } catch (e) {
      debugPrint('⚠️ [HISTORY] Next page failed: ${e.runtimeType}');
      if (mounted) state = state.copyWith(loadingMore: false, error: e);
    }
  }

  /// "Einkauf speichern" (V1). The trip appears at once with the sync
  /// mark; the future ends when the server answered: [CheckoutSaved],
  /// a rejection (the entry disappears again) or [CheckoutPending] with
  /// `failed` after a network or server error.
  Future<CheckoutResult> checkout(CheckoutRequest request) {
    final uid = userId;
    if (uid == null) throw StateError('User not authenticated');
    final localId =
        '$localTripPrefix${_now().microsecondsSinceEpoch}-${_localSeq++}';
    _requests[localId] = request;
    state = state.copyWith(
      trips: _sorted([_preview(localId, uid, request), ...state.trips]),
      sending: {...state.sending, localId},
    );
    return _send(localId, request);
  }

  /// The local id of the trip [checkout] is saving for [request], for
  /// "Widerrufen" before the server answered.
  String? localIdOf(CheckoutRequest request) => _requests.entries
      .where((e) => identical(e.value, request))
      .map((e) => e.key)
      .firstOrNull;

  /// Saves a trip that failed again ("Nicht gespeichert", tap).
  Future<CheckoutResult> retry(String localTripId) {
    final request = _requests[localTripId];
    if (request == null || !state.failed.contains(localTripId)) {
      return Future.value(CheckoutPending(localTripId: localTripId));
    }
    state = state.copyWith(
      sending: {...state.sending, localTripId},
      failed: {...state.failed}..remove(localTripId),
    );
    return _send(localTripId, request);
  }

  Future<CheckoutResult> _send(String localId, CheckoutRequest request) async {
    try {
      final result = await _service.completeTrip(request);
      if (!mounted) return result;
      if (_cancelled.remove(localId)) {
        // Undone before the server answered: take the saved trip back too.
        if (result is CheckoutSaved) {
          unawaited(_service.undoTrip(result));
        }
        _drop(localId);
        return result;
      }
      if (result is CheckoutSaved) {
        _requests.remove(localId);
        _saved[result.trip.id] = result;
        _localToServer[localId] = result.trip.id;
        final releaseNow = _releasedEarly.remove(localId);
        if (request.notifyUserIds.isNotEmpty) {
          unawaited(
            holdTripPush(
                  trip: result.trip,
                  recipients: request.notifyUserIds,
                  actorName: request.actorName,
                  languageCode: pushLanguageCode(),
                )
                .then((_) {
                  if (releaseNow) release(result.trip.id);
                })
                .catchError((Object e) {
                  debugPrint(
                    '⚠️ [HISTORY] Trip push not queued: ${e.runtimeType}',
                  );
                }),
          );
        }
        state = state.copyWith(
          trips: _sorted([
            result.trip,
            for (final t in state.trips)
              if (t.id != localId && t.id != result.trip.id) t,
          ]),
          sending: {...state.sending}..remove(localId),
        );
        _persist();
      } else {
        _drop(localId);
      }
      return result;
    } catch (e) {
      debugPrint('❌ [HISTORY] Trip not saved: ${e.runtimeType}');
      if (!mounted) return CheckoutPending(localTripId: localId, failed: true);
      if (_cancelled.remove(localId)) {
        _drop(localId);
        return CheckoutPending(localTripId: localId, failed: true);
      }
      state = state.copyWith(
        sending: {...state.sending}..remove(localId),
        failed: {...state.failed, localId},
      );
      return CheckoutPending(localTripId: localId, failed: true);
    }
  }

  /// "Widerrufen" (V3): takes the trip back, with a split saved in the same
  /// chain, and drops its pushes. A trip still on its way is cancelled.
  Future<UndoTripResult> undo(String requestedId) async {
    // A late server answer replaced the local entry: undo the saved trip.
    final tripId = _localToServer[requestedId] ?? requestedId;
    if (isLocalTripId(tripId)) {
      if (state.sending.contains(tripId)) _cancelled.add(tripId);
      _drop(tripId);
      return UndoTripResult.undone;
    }
    final saved = _saved[tripId];
    if (saved == null) return UndoTripResult.refused;
    final result = await _service.undoTrip(saved);
    if (result == UndoTripResult.undone) {
      // Only now: a refused undo keeps the trip, and its push still goes.
      unawaited(_pushes?.cancel(tripId));
      _saved.remove(tripId);
      _localToServer.remove(requestedId);
      if (mounted) remove(tripId);
    }
    return result;
  }

  /// Puts [trip] in the history or replaces it (amount, market, split
  /// changed in V5 to V7).
  void upsert(ShoppingHistory trip) {
    state = state.copyWith(
      trips: _sorted([
        trip,
        for (final t in state.trips)
          if (t.id != trip.id) t,
      ]),
    );
    _persist();
  }

  /// Takes [tripId] out of the history (deleted, undone).
  void remove(String tripId) {
    if (!state.trips.any((t) => t.id == tripId)) return;
    state = state.copyWith(
      trips: [
        for (final t in state.trips)
          if (t.id != tripId) t,
      ],
    );
    _persist();
  }

  /// "Einkauf löschen" (V13): out of the list at once, back on failure (the
  /// error is rethrown for "Löschen hat nicht geklappt.").
  Future<void> deleteTrip(String tripId) async {
    final before = state.trips;
    remove(tripId);
    if (isLocalTripId(tripId)) return;
    try {
      await _service.deleteHistory(tripId);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(trips: before);
        _persist();
      }
      rethrow;
    }
  }

  /// Queues the "{name} hat bei {store} eingekauft" push to [recipients]
  /// (V14) behind the undo window; [release] sends it earlier.
  Future<void> holdTripPush({
    required ShoppingHistory trip,
    required List<String> recipients,
    required String? actorName,
    required String languageCode,
  }) async {
    final queue = _pushes;
    final to = [
      for (final id in recipients)
        if (id != userId) id,
    ];
    if (queue == null || to.isEmpty) return;
    final name = (actorName == null || actorName.trim().isEmpty)
        ? AppTranslations.get('hist_member_unknown', languageCode)
        : actorName.trim();
    final store = trip.storeChainId == null
        ? null
        : StoreChainDirectory.byId(trip.storeChainId!)?.displayName;
    final n = trip.totalItems;
    final key = store == null ? 'notif_trip_done_no_store' : 'notif_trip_done';
    await queue.enqueue(
      DeferredTripPush(
        tripId: trip.id,
        userIds: to,
        title: trip.listName,
        body: AppTranslations.get(
          n == 1 ? '${key}_one' : key,
          languageCode,
          params: {'name': name, 'store': ?store, 'n': '$n'},
        ),
        data: {
          'type': 'shopping_complete',
          'listId': trip.listId,
          'history_id': trip.id,
        },
        notBefore: _now().add(tripPushHold),
      ),
    );
  }

  /// The undo toast of [tripId] is gone: its pushes go out now. A trip
  /// still on its way releases them as soon as it is saved. "Widerrufen"
  /// stays possible on the server ([tripUndoServerWindow]).
  void release(String requestedId) {
    final tripId = _localToServer[requestedId] ?? requestedId;
    if (isLocalTripId(tripId)) {
      _releasedEarly.add(tripId);
      return;
    }
    unawaited(_pushes?.release(tripId));
  }

  void _drop(String localId) {
    _requests.remove(localId);
    state = state.copyWith(
      trips: [
        for (final t in state.trips)
          if (t.id != localId) t,
      ],
      sending: {...state.sending}..remove(localId),
      failed: {...state.failed}..remove(localId),
    );
  }

  ShoppingHistory _preview(String id, String uid, CheckoutRequest r) =>
      ShoppingHistory(
        id: id,
        userId: uid,
        listId: r.listId,
        listName: r.listName,
        totalItems: r.checkedItems.length,
        completedAt: _now(),
        totalCost: r.totalCostCents == null
            ? null
            : centsToEuros(r.totalCostCents!),
        storeChainId: r.chainId,
        storeSource: r.chainId == null ? null : r.storeSource?.name,
        totalCostSource: r.totalCostCents == null ? null : 'user',
        completedBy: uid,
        items: [
          for (final item in r.checkedItems)
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

  void _persist() {
    final uid = userId;
    final cache = _cache;
    if (uid == null || cache == null) return;
    unawaited(
      cache
          .writeTrips(uid, [
            for (final t in state.trips)
              if (!isLocalTripId(t.id)) t,
          ], now: _now())
          .catchError((Object e) {
            debugPrint('⚠️ [HISTORY] Cache not written: ${e.runtimeType}');
          }),
    );
  }

  static List<ShoppingHistory> _sorted(List<ShoppingHistory> trips) =>
      [...trips]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
}

/// The local history cache of the signed-in account; null until the
/// preferences are loaded (they are preloaded in `main`).
final tripHistoryCacheProvider = Provider<TripHistoryCache?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return prefs == null ? null : TripHistoryCache(prefs);
});

/// Trip pushes held behind the undo window.
final tripPushQueueProvider = Provider<TripPushQueue>((ref) {
  final queue = TripPushQueue(
    // Lazily: the push service reads Supabase when it is created.
    send: ({
      required List<String> userIds,
      required String title,
      required String body,
      Map<String, dynamic>? data,
    }) => PushNotificationService.instance.sendToUsers(
      userIds: userIds,
      title: title,
      body: body,
      data: data,
    ),
  );
  ref.onDispose(queue.dispose);
  return queue;
});

/// The history (L3): the cache in the first frame, then the newest page
/// from the server; appended on checkout instead of reloaded (Bug 3).
/// Synchronous for W11's screens, Home and Teil A.
final tripHistoryProvider =
    StateNotifierProvider<TripHistoryController, TripHistoryState>((ref) {
      return TripHistoryController(
        service: ref.watch(shoppingHistoryServiceProvider),
        userId: ref.watch(authUserIdProvider),
        cache: ref.watch(tripHistoryCacheProvider),
        pushes: ref.watch(tripPushQueueProvider),
      );
    });

/// One trip from [tripHistoryProvider], or null when it is not known here.
final historyTripProvider = Provider.family<ShoppingHistory?, String>(
  (ref, tripId) => ref.watch(
    tripHistoryProvider.select(
      (s) => s.trips.where((t) => t.id == tripId).firstOrNull,
    ),
  ),
);

// ------------------------------------------------------------------ summaries

/// What the list overview row "Einkäufe" shows (A-V12): "November · 6".
@immutable
class HistoryEntrySummary {
  const HistoryEntrySummary({
    required this.month,
    required this.tripsThisMonth,
    required this.hasTrips,
  });

  /// The current month (day 1).
  final DateTime month;

  /// Trips completed in [month] (local ones included).
  final int tripsThisMonth;

  /// Whether there is any trip at all (else the row can say nothing).
  final bool hasTrips;

  @override
  bool operator ==(Object other) =>
      other is HistoryEntrySummary &&
      other.month == month &&
      other.tripsThisMonth == tripsThisMonth &&
      other.hasTrips == hasTrips;

  @override
  int get hashCode => Object.hash(month, tripsThisMonth, hasTrips);
}

/// The clock of the summaries; override in tests.
final historyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Synchronous summary for the row "Einkäufe" (A-V12), from the history in
/// the first frame.
final historyEntrySummaryProvider = Provider<HistoryEntrySummary>((ref) {
  final now = ref.watch(historyClockProvider)();
  final trips = ref.watch(tripHistoryProvider.select((s) => s.trips));
  final month = DateTime(now.year, now.month);
  return HistoryEntrySummary(
    month: month,
    tripsThisMonth: tripsInMonth(
      trips,
      year: now.year,
      month: now.month,
    ).length,
    hasTrips: trips.isNotEmpty,
  );
});

// ------------------------------------------------------------------ open shares

/// Open shares of Kosten teilen (V8, L8): the cache first, then the server.
@immutable
class OpenSharesState {
  const OpenSharesState({
    this.shares = const [],
    this.synced = false,
    this.failed = const {},
    this.error,
  });

  /// Open shares that involve the person, plus those settled in the last
  /// 30 days, newest trip first.
  final List<OpenShare> shares;
  final bool synced;

  /// Shares whose paid change was not saved ("Nicht gespeichert").
  final Set<String> failed;
  final Object? error;

  OpenSharesState copyWith({
    List<OpenShare>? shares,
    bool? synced,
    Set<String>? failed,
    Object? error,
    bool clearError = false,
  }) => OpenSharesState(
    shares: shares ?? this.shares,
    synced: synced ?? this.synced,
    failed: failed ?? this.failed,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Reads the open shares and marks them paid optimistically.
class OpenSharesController extends StateNotifier<OpenSharesState> {
  OpenSharesController({
    required ExpenseSplitService service,
    required this.userId,
    TripHistoryCache? cache,
  }) : _service = service,
       _cache = cache,
       super(
         OpenSharesState(
           shares: userId == null || cache == null
               ? const []
               : cache.readShares(userId),
           synced: userId == null,
         ),
       ) {
    if (userId != null) unawaited(refresh());
  }

  final ExpenseSplitService _service;
  final TripHistoryCache? _cache;
  final String? userId;

  /// Reads the shares again. Never throws.
  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;
    try {
      final shares = await _service.getOpenShares();
      if (!mounted) return;
      state = state.copyWith(shares: shares, synced: true, clearError: true);
      unawaited(_cache?.writeShares(uid, shares));
    } catch (e) {
      debugPrint('⚠️ [SPLIT] Open shares not read: ${e.runtimeType}');
      if (mounted) state = state.copyWith(error: e);
    }
  }

  /// "Bezahlt" / "Wieder offen": at once, back with "Nicht gespeichert"
  /// when the server refuses. True when saved.
  Future<bool> setPaid(String splitId, bool isPaid) async {
    final before = state.shares;
    state = state.copyWith(
      shares: [
        for (final s in state.shares)
          s.splitId == splitId
              ? s.copyWith(isPaid: isPaid, paidAt: DateTime.now())
              : s,
      ],
      failed: {...state.failed}..remove(splitId),
    );
    final saved = await _service.setPaid(splitId, isPaid);
    if (!mounted) return saved != null;
    if (saved == null) {
      state = state.copyWith(
        shares: before,
        failed: {...state.failed, splitId},
      );
      return false;
    }
    final uid = userId;
    if (uid != null) unawaited(_cache?.writeShares(uid, state.shares));
    return true;
  }
}

/// Open shares of the signed-in person (V8, Home hints).
final openSharesProvider =
    StateNotifierProvider<OpenSharesController, OpenSharesState>((ref) {
      return OpenSharesController(
        service: ref.watch(expenseSplitServiceProvider),
        userId: ref.watch(authUserIdProvider),
        cache: ref.watch(tripHistoryCacheProvider),
      );
    });

/// What the list overview row "Offene Beträge" shows (A-V12, A-V13).
@immutable
class OpenBalancesSummary {
  const OpenBalancesSummary({
    required this.openCount,
    required this.owedToMeCents,
    required this.iOweCents,
    required this.people,
  });

  /// Unpaid shares that involve the person.
  final int openCount;

  /// What others still owe the person.
  final int owedToMeCents;

  /// What the person still owes others.
  final int iOweCents;

  /// How many different people are involved (names, for "mehrere").
  final int people;

  /// Both directions together, for the row value ("34,60 €").
  int get totalOpenCents => owedToMeCents + iOweCents;

  @override
  bool operator ==(Object other) =>
      other is OpenBalancesSummary &&
      other.openCount == openCount &&
      other.owedToMeCents == owedToMeCents &&
      other.iOweCents == iOweCents &&
      other.people == people;

  @override
  int get hashCode => Object.hash(openCount, owedToMeCents, iOweCents, people);
}

/// Synchronous open amounts for the row "Offene Beträge" (A-V12); null
/// while the module Kosten teilen is off, signed out or nothing is open.
final openBalancesSummaryProvider = Provider<OpenBalancesSummary?>((ref) {
  final me = ref.watch(authUserIdProvider);
  if (me == null) return null;
  if (!ref.watch(moduleEnabledProvider(AppModule.costSplit))) return null;
  final shares = ref.watch(openSharesProvider.select((s) => s.shares));
  var owed = 0;
  var owe = 0;
  var count = 0;
  final people = <String>{};
  for (final share in shares) {
    if (share.isPaid) continue;
    if (share.isOwedTo(me)) {
      owed += share.amountCents;
      people.add(share.userId ?? 'name:${share.participantName}');
    } else if (share.isOwedBy(me)) {
      owe += share.amountCents;
      people.add(share.paidByUserId ?? 'name:${share.paidByName}');
    } else {
      continue;
    }
    count++;
  }
  if (count == 0) return null;
  return OpenBalancesSummary(
    openCount: count,
    owedToMeCents: owed,
    iOweCents: owe,
    people: people.length,
  );
});

/// Members of a list for "Kosten teilen" (V1, V7): account ids and names,
/// the person first. Empty while loading or failing.
@immutable
class SplitMember {
  const SplitMember({required this.userId, required this.name});

  final String userId;

  /// Display name; empty when unknown.
  final String name;
}

/// [splitCandidateMembersProvider] as [SplitMember]s; null while loading.
final splitMembersProvider =
    Provider.autoDispose.family<List<SplitMember>?, String>((ref, listId) {
      final me = ref.watch(authUserIdProvider);
      final raw = ref.watch(splitCandidateMembersProvider(listId));
      final rows = raw.valueOrNull;
      if (rows == null) return raw.hasError ? const [] : null;
      final members = <SplitMember>[];
      for (final row in rows) {
        final id = row['user_id'] as String?;
        if (id == null || members.any((m) => m.userId == id)) continue;
        final user = row['user'] as Map<String, dynamic>?;
        members.add(
          SplitMember(
            userId: id,
            name: (user?['display_name'] as String?)?.trim() ?? '',
          ),
        );
      }
      members.sort((a, b) {
        if (a.userId == me) return -1;
        if (b.userId == me) return 1;
        return 0;
      });
      return members;
    });
