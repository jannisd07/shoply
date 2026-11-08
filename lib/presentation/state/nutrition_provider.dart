import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/calorie_day_store.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/health_sync_service.dart';
import 'package:shoply/data/services/native/health_channel.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/data/services/user_food_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/data/services/workout_log_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

// ── Services ────────────────────────────────────────────────────────────

final nutritionGoalServiceProvider = Provider<NutritionGoalService>((ref) {
  return NutritionGoalService.instance;
});

final foodLogServiceProvider = Provider<FoodLogService>((ref) {
  return FoodLogService.instance;
});

final weightLogServiceProvider = Provider<WeightLogService>((ref) {
  return WeightLogService.instance;
});

final waterLogServiceProvider = Provider<WaterLogService>((ref) {
  return WaterLogService.instance;
});

final workoutLogServiceProvider = Provider<WorkoutLogService>((ref) {
  return WorkoutLogService.instance;
});

final userFoodServiceProvider = Provider<UserFoodService>((ref) {
  return UserFoodService.instance;
});

final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>((ref) {
  return OpenFoodFactsService.instance;
});

// ── Local-first day state (concept 15 2.1) ─────────────────────────────

/// Clock for day keys; override in tests.
final calorieClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final calorieRemoteProvider = Provider<CalorieRemote>((ref) => const SupabaseCalorieRemote());

/// SharedPreferences for the day store and the write queue. Override with an
/// already loaded instance (app start) so the diary has numbers in frame 1.
final calorieSharedPreferencesProvider = sharedPreferencesProvider;

/// Fires `true` when the connection is back; the queue then retries.
final calorieOnlineStreamProvider =
    Provider<Stream<bool>>((ref) => ConnectivityService.instance.onStatusChanged);

/// Store + queue of the signed-in account.
class CalorieBackend {
  final String userId;
  final CalorieDayStore store;
  final CalorieWriteQueue queue;
  final CalorieRemote remote;
  final DateTime Function() now;
  final SharedPreferences prefs;

  const CalorieBackend({
    required this.userId,
    required this.store,
    required this.queue,
    required this.remote,
    required this.now,
    required this.prefs,
  });

  String get todayKey => calorieDayKey(now());
}

final calorieBackendProvider = FutureProvider<CalorieBackend?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;
  final prefs = await ref.watch(calorieSharedPreferencesProvider.future);
  final remote = ref.watch(calorieRemoteProvider);
  final now = ref.watch(calorieClockProvider);
  final store = CalorieDayStore(prefs: prefs, userId: userId, now: now);
  final queue = CalorieWriteQueue(
    prefs: prefs,
    executor: remote.execute,
    storageKey: 'cal_write_queue_v1_$userId',
  );
  final online = ref.watch(calorieOnlineStreamProvider).listen((isOnline) {
    if (isOnline) unawaited(queue.retryAll());
  });
  ref.onDispose(() {
    online.cancel();
    queue.dispose();
  });
  unawaited(store.prune());
  return CalorieBackend(
    userId: userId,
    store: store,
    queue: queue,
    remote: remote,
    now: now,
    prefs: prefs,
  );
});

/// One day as the diary shows it. [day] null = this device knows nothing
/// about the day yet (unknown, never "nothing eaten"); [error] is the last
/// failed refresh, shown as a status row while [day] stays visible.
class CalorieDayState {
  final String dateKey;
  final CalorieDay? day;
  final bool refreshing;
  final CalorieDataException? error;

  const CalorieDayState({
    required this.dateKey,
    this.day,
    this.refreshing = false,
    this.error,
  });

  bool get isUnknown => day == null;

  /// For widgets that render loading/error/data: local data always wins.
  AsyncValue<CalorieDay> get asAsync {
    if (day != null) return AsyncData(day!);
    if (error != null) return AsyncError(error!, StackTrace.empty);
    return const AsyncLoading();
  }

  CalorieDayState copyWith({
    CalorieDay? day,
    bool? refreshing,
    CalorieDataException? error,
    bool clearError = false,
  }) =>
      CalorieDayState(
        dateKey: dateKey,
        day: day ?? this.day,
        refreshing: refreshing ?? this.refreshing,
        error: clearError ? null : (error ?? this.error),
      );
}

class CalorieDayNotifier extends StateNotifier<CalorieDayState> {
  CalorieDayNotifier(
    this.dateKey,
    Future<CalorieBackend?> backend, {
    void Function()? onLocalChange,
    CalorieDay? initial,
  })  : _onLocalChange = onLocalChange,
        super(CalorieDayState(dateKey: dateKey, day: initial, refreshing: true)) {
    _init(backend);
  }

  final String dateKey;
  final void Function()? _onLocalChange;
  final Completer<void> _ready = Completer<void>();
  CalorieBackend? _backend;
  StreamSubscription<List<QueuedWrite>>? _queueSub;

  Future<void> _init(Future<CalorieBackend?> backendFuture) async {
    final CalorieBackend? backend;
    try {
      backend = await backendFuture;
    } catch (e) {
      _ready.complete();
      if (mounted) state = state.copyWith(refreshing: false, error: CalorieDataException.from(e));
      return;
    }
    if (!mounted || backend == null) {
      _ready.complete();
      if (mounted) {
        state = state.copyWith(
          refreshing: false,
          error: const CalorieDataException(CalorieErrorCode.notSignedIn),
        );
      }
      return;
    }
    _backend = backend;
    final local = backend.store.read(dateKey);
    if (local != null) {
      state = state.copyWith(day: local.copyWith(syncStates: backend.queue.syncStatesFor(dateKey)));
    }
    _queueSub = backend.queue.changes.listen((_) => _syncStatesChanged());
    _ready.complete();
    await refresh();
  }

  /// Merges the server's day with the waiting writes. Errors keep the local
  /// state and land in [CalorieDayState.error].
  Future<void> refresh() async {
    final backend = _backend;
    if (backend == null || !mounted) return;
    state = state.copyWith(refreshing: true);
    try {
      final server = await backend.remote.fetchDay(dateKey);
      if (!mounted) return;
      final merged = mergeServerDay(
        server: server,
        writes: backend.queue.writes,
        local: state.day,
        syncedAt: DateTime.now().toUtc(),
      );
      state = CalorieDayState(dateKey: dateKey, day: merged);
      await backend.store.save(merged);
      _onLocalChange?.call();
    } catch (e) {
      if (!mounted) return;
      final error = CalorieDataException.from(e);
      debugPrint('⚠️ [CalorieDay] Refresh $dateKey failed: ${error.code.name}');
      state = state.copyWith(refreshing: false, error: error);
    }
  }

  /// Applies a local change (optimistic), stores it and tells the week.
  Future<CalorieDay> apply(CalorieDay Function(CalorieDay current) change) async {
    await _ready.future;
    final current = state.day ?? CalorieDay(dateKey: dateKey);
    var next = change(current);
    final backend = _backend;
    if (backend != null) next = next.copyWith(syncStates: backend.queue.syncStatesFor(dateKey));
    if (mounted) state = state.copyWith(day: next);
    await backend?.store.save(next);
    _onLocalChange?.call();
    return next;
  }

  /// Health workouts of this day (device only, never uploaded).
  Future<void> setHealthWorkouts(List<Workout> workouts) => apply(
        (d) => d.copyWith(workouts: [
          ...d.workouts.where((w) => !w.isReadOnly),
          ...workouts.where((w) => calorieDayKey(w.startedAt) == dateKey),
        ]),
      );

  void _syncStatesChanged() {
    final backend = _backend;
    final day = state.day;
    if (backend == null || day == null || !mounted) return;
    final states = backend.queue.syncStatesFor(dateKey);
    if (mapEquals(states, day.syncStates)) return;
    final next = day.copyWith(syncStates: states);
    state = state.copyWith(day: next);
    unawaited(backend.store.save(next));
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    super.dispose();
  }
}

/// Bumped whenever a day of the week changed locally; the week recomputes
/// from local days without asking the server again.
final calorieWeekRevisionProvider = StateProvider.family<int, String>((ref, weekStartKey) => 0);

/// The state of one local day (`YYYY-MM-DD`). Stays alive once opened so
/// switching days never waits. Starts with the day stored on this device,
/// so a screen has its numbers in the first frame (§3.1).
final calorieDayProvider =
    StateNotifierProvider.family<CalorieDayNotifier, CalorieDayState, String>((ref, dateKey) {
  final backend = ref.watch(calorieBackendProvider.future);
  final week = calorieWeekStartKey(dateKey);
  return CalorieDayNotifier(
    dateKey,
    backend,
    initial: _storedDay(ref, dateKey),
    onLocalChange: () => ref.read(calorieWeekRevisionProvider(week).notifier).state++,
  );
});

CalorieDay? _storedDay(Ref ref, String dateKey) {
  final userId = ref.read(authUserIdProvider);
  final prefs = ref.read(calorieSharedPreferencesProvider).valueOrNull;
  if (userId == null || prefs == null) return null;
  return CalorieDayStore.readFrom(prefs, userId, dateKey);
}

/// What the diary screen watches: [dateKey] with the day before and (up to
/// today) the day after already loading, so swiping never waits.
final calorieDiaryDayProvider =
    Provider.autoDispose.family<CalorieDayState, String>((ref, dateKey) {
  final today = calorieDayKey(ref.watch(calorieClockProvider)());
  ref.listen(calorieDayProvider(shiftCalorieDayKey(dateKey, -1)), (_, __) {});
  final next = shiftCalorieDayKey(dateKey, 1);
  if (next.compareTo(today) <= 0) ref.listen(calorieDayProvider(next), (_, __) {});
  return ref.watch(calorieDayProvider(dateKey));
});

/// Server sums of a calendar week (one query each for food and water).
final calorieWeekServerProvider = FutureProvider.autoDispose
    .family<({Map<String, DailyNutritionTotals> food, Map<String, int> water}), String>(
        (ref, weekStartKey) async {
  final remote = ref.watch(calorieRemoteProvider);
  final end = shiftCalorieDayKey(weekStartKey, 6);
  final food = remote.fetchFoodTotals(weekStartKey, end);
  final water = remote.fetchWaterTotals(weekStartKey, end);
  return (food: await food, water: await water);
});

/// Monday-to-Sunday week starting at [weekStartKey]: server sums with local
/// days on top (they contain waiting writes).
final calorieWeekProvider =
    Provider.autoDispose.family<AsyncValue<CalorieWeek>, String>((ref, weekStartKey) {
  ref.watch(calorieWeekRevisionProvider(weekStartKey));
  final backend = ref.watch(calorieBackendProvider).valueOrNull;
  final server = ref.watch(calorieWeekServerProvider(weekStartKey));
  final todayKey = calorieDayKey(ref.watch(calorieClockProvider)());
  final local = <String, CalorieDay>{};
  if (backend != null) {
    for (var i = 0; i < 7; i++) {
      final key = shiftCalorieDayKey(weekStartKey, i);
      final day = backend.store.read(key);
      if (day != null) local[key] = day;
    }
  }
  CalorieWeek build(Map<String, DailyNutritionTotals> food, Map<String, int> water) =>
      buildCalorieWeek(
        weekStartKey: weekStartKey,
        todayKey: todayKey,
        serverFood: food,
        serverWater: water,
        localDays: local,
      );
  return server.when(
    data: (s) => AsyncData(build(s.food, s.water)),
    loading: () => local.isEmpty ? const AsyncLoading() : AsyncData(build(const {}, const {})),
    error: (e, st) => local.isEmpty ? AsyncError(e, st) : AsyncData(build(const {}, const {})),
  );
});

// ── Writes (optimistic, queued, written to Health) ─────────────────────

/// Calories module on and Health connected on this device (set by the
/// "Apple Health verbinden" screen through [setHealthConnected]).
const _healthConnectedKey = 'cal_health_connected_v1';

/// The native HealthKit bridge (`shoply/health`); null where Health does not
/// exist. Override in tests.
final healthBridgeProvider =
    Provider<HealthBridge?>((ref) => HealthChannelBridge(HealthChannel.instance));

final healthSyncServiceProvider = Provider<HealthSyncService?>((ref) {
  final bridge = ref.watch(healthBridgeProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  if (bridge == null || prefs == null) return null;
  final service = HealthSyncService(
    bridge: bridge,
    prefs: prefs,
    isActive: () =>
        (prefs.getBool(_healthConnectedKey) ?? false) &&
        ref.read(moduleEnabledProvider(AppModule.calories)),
  );
  unawaited(service.resumePendingDeletes());
  ref.onDispose(service.dispose);
  return service;
});

Future<void> setHealthConnected(WidgetRef ref, bool connected) async {
  final prefs = await ref.read(calorieSharedPreferencesProvider.future);
  await prefs.setBool(_healthConnectedKey, connected);
}

/// The one place that changes diary data: updates the local day at once,
/// queues the server write and mirrors it to Apple Health. Deletes return
/// the removed row for "Widerrufen"; Health deletes wait for the undo
/// window.
class CalorieDiary {
  CalorieDiary(this._ref);

  final Ref _ref;

  Future<CalorieBackend> _backend() async {
    final backend = await _ref.read(calorieBackendProvider.future);
    if (backend == null) throw const CalorieDataException(CalorieErrorCode.notSignedIn);
    return backend;
  }

  HealthSyncService? get _health => _ref.read(healthSyncServiceProvider);

  CalorieDayNotifier _day(String dateKey) => _ref.read(calorieDayProvider(dateKey).notifier);

  void _enqueue(CalorieBackend b, QueuedWrite w) => unawaited(b.queue.enqueue(w));

  // Food

  Future<FoodLogEntry> addFood(FoodLogEntry entry) async {
    final b = await _backend();
    final now = DateTime.now().toUtc();
    final saved = FoodLogEntry.fromJson({
      ...entry.toJson(),
      'id': entry.id.isEmpty ? const Uuid().v4() : entry.id,
      'user_id': entry.userId.isEmpty ? b.userId : entry.userId,
      'logged_time': (entry.loggedTime ?? FoodLogTime.of(b.now())).toString(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.food,
      entityId: saved.id,
      dateKey: saved.dateKey,
      payload: saved.toJson(),
      isCreate: true,
    ));
    await _day(saved.dateKey).apply((d) => d.copyWith(entries: [...d.entries, saved]));
    unawaited(_health?.foodLogged(saved));
    return saved;
  }

  /// Saves an edit; moving to another day moves the row between days.
  Future<FoodLogEntry> updateFood(FoodLogEntry previous, FoodLogEntry changed) async {
    final b = await _backend();
    final saved = changed.copyWith(updatedAt: DateTime.now().toUtc());
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.food,
      entityId: saved.id,
      dateKey: saved.dateKey,
      payload: saved.toJson(),
    ));
    if (previous.dateKey != saved.dateKey) {
      await _day(previous.dateKey).apply(
        (d) => d.copyWith(entries: d.entries.where((e) => e.id != saved.id).toList()),
      );
      await _day(saved.dateKey).apply((d) => d.copyWith(entries: [...d.entries, saved]));
    } else {
      await _day(saved.dateKey).apply((d) => d.copyWith(
            entries: [for (final e in d.entries) e.id == saved.id ? saved : e],
          ));
    }
    unawaited(_health?.foodLogged(saved));
    return saved;
  }

  Future<FoodLogEntry> deleteFood(FoodLogEntry entry) async {
    final b = await _backend();
    _enqueue(b, QueuedWrite.delete(kind: CalorieWriteKinds.food, entityId: entry.id, dateKey: entry.dateKey));
    await _day(entry.dateKey).apply(
      (d) => d.copyWith(entries: d.entries.where((e) => e.id != entry.id).toList()),
    );
    unawaited(_health?.scheduleDelete(HealthSyncIds.food(entry.id)));
    return entry;
  }

  /// "Widerrufen" after [deleteFood].
  Future<void> restoreFood(FoodLogEntry entry) async {
    final b = await _backend();
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.food,
      entityId: entry.id,
      dateKey: entry.dateKey,
      payload: entry.toJson(),
    ));
    await _day(entry.dateKey).apply((d) => d.copyWith(
          entries: [...d.entries.where((e) => e.id != entry.id), entry],
        ));
    unawaited(_health?.foodRestored(entry));
  }

  // Water

  Future<WaterLogEntry> addWater(int ml, {required String dateKey}) async {
    final b = await _backend();
    final entry = WaterLogEntry(
      id: const Uuid().v4(),
      userId: b.userId,
      loggedDate: parseCalorieDayKey(dateKey),
      amountMl: ml,
      createdAt: DateTime.now().toUtc(),
    );
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.water,
      entityId: entry.id,
      dateKey: dateKey,
      payload: waterEntryToJson(entry),
      isCreate: true,
    ));
    await _day(dateKey).apply((d) => d.copyWith(water: [...d.water, entry]));
    unawaited(_health?.waterLogged(entry));
    return entry;
  }

  Future<WaterLogEntry> deleteWater(WaterLogEntry entry) async {
    final b = await _backend();
    final key = calorieDayKey(entry.loggedDate);
    _enqueue(b, QueuedWrite.delete(kind: CalorieWriteKinds.water, entityId: entry.id, dateKey: key));
    await _day(key).apply((d) => d.copyWith(water: d.water.where((w) => w.id != entry.id).toList()));
    unawaited(_health?.scheduleDelete(HealthSyncIds.water(entry.id)));
    return entry;
  }

  Future<void> restoreWater(WaterLogEntry entry) async {
    final b = await _backend();
    final key = calorieDayKey(entry.loggedDate);
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.water,
      entityId: entry.id,
      dateKey: key,
      payload: waterEntryToJson(entry),
    ));
    await _day(key).apply((d) => d.copyWith(water: [...d.water.where((w) => w.id != entry.id), entry]));
    await _health?.cancelDelete(HealthSyncIds.water(entry.id));
  }

  // Workouts

  Future<Workout> saveWorkout(Workout workout, {Workout? previous}) async {
    final b = await _backend();
    final now = DateTime.now().toUtc();
    final saved = Workout.fromJson({
      ...workout.toJson(),
      'id': workout.id.isEmpty ? const Uuid().v4() : workout.id,
      'user_id': workout.userId.isEmpty ? b.userId : workout.userId,
      'created_at': (previous?.createdAt ?? now).toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    final key = calorieDayKey(saved.startedAt);
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.workout,
      entityId: saved.id,
      dateKey: key,
      payload: saved.toJson(),
      isCreate: previous == null,
    ));
    final oldKey = previous == null ? null : calorieDayKey(previous.startedAt);
    if (oldKey != null && oldKey != key) {
      await _day(oldKey).apply((d) => d.copyWith(workouts: d.workouts.where((w) => w.id != saved.id).toList()));
    }
    await _day(key).apply((d) => d.copyWith(workouts: [...d.workouts.where((w) => w.id != saved.id), saved]));
    unawaited(_health?.workoutLogged(saved));
    return saved;
  }

  Future<Workout> deleteWorkout(Workout workout) async {
    final b = await _backend();
    final key = calorieDayKey(workout.startedAt);
    _enqueue(b, QueuedWrite.delete(kind: CalorieWriteKinds.workout, entityId: workout.id, dateKey: key));
    await _day(key).apply((d) => d.copyWith(workouts: d.workouts.where((w) => w.id != workout.id).toList()));
    unawaited(_health?.scheduleDelete(HealthSyncIds.workout(workout.id)));
    return workout;
  }

  Future<void> restoreWorkout(Workout workout) async {
    await saveWorkout(workout, previous: workout);
    await _health?.cancelDelete(HealthSyncIds.workout(workout.id));
  }

  // Weight, goal, challenges, own foods (queued; their screens keep their
  // own optimistic list)

  Future<void> logWeight(double kg, {required DateTime date, String? note}) async {
    final b = await _backend();
    final key = calorieDayKey(date);
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.weight,
      entityId: key,
      dateKey: key,
      payload: {'weight_kg': kg, 'logged_date': key, 'note': note},
    ));
    unawaited(_health?.weightLogged(WeightLogEntry(
      id: key,
      userId: b.userId,
      loggedDate: date,
      weightKg: kg,
      createdAt: DateTime.now().toUtc(),
    )));
  }

  Future<void> deleteWeight(DateTime date) async {
    final b = await _backend();
    final key = calorieDayKey(date);
    _enqueue(b, QueuedWrite.delete(kind: CalorieWriteKinds.weight, entityId: key, dateKey: key));
    unawaited(_health?.scheduleDelete(HealthSyncIds.weight(key)));
  }

  /// Saves the goal locally (offline "Ziel einrichten" works) and queues it.
  Future<NutritionGoal> saveGoal(NutritionGoal goal) async {
    final b = await _backend();
    final json = {
      ...goal.toUpsertJson(schemaV2: true),
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await b.prefs.setString(_goalCacheKey(b.userId), jsonEncode(json));
    _enqueue(b, QueuedWrite.upsert(kind: CalorieWriteKinds.goal, entityId: b.userId, dateKey: null, payload: json));
    _ref.invalidate(nutritionGoalProvider);
    return NutritionGoal.fromJson(json);
  }

  /// `kept` null clears the day ("Ändern").
  Future<void> setChallengeCheckIn(String challengeId, String dateKey, bool? kept) async {
    final b = await _backend();
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.checkin,
      entityId: '$challengeId|$dateKey',
      dateKey: null,
      payload: {'challenge_id': challengeId, 'date': dateKey, 'kept': kept},
    ));
  }

  Future<UserFood> saveUserFood(UserFood food) async {
    final b = await _backend();
    final saved = food.id.isEmpty
        ? UserFood.fromJson({...food.toJson(), 'id': const Uuid().v4(), 'user_id': b.userId})
        : food;
    _enqueue(b, QueuedWrite.upsert(
      kind: CalorieWriteKinds.userFood,
      entityId: saved.id,
      dateKey: null,
      payload: saved.toJson(),
      isCreate: food.id.isEmpty,
    ));
    return saved;
  }

  /// Tap on a "Nicht gespeichert" row.
  Future<void> retry(String entityId) async {
    final b = await _backend();
    for (final w in b.queue.writes.where((w) => w.entityId == entityId)) {
      await b.queue.retry(w.id);
    }
  }
}

final calorieDiaryProvider = Provider<CalorieDiary>((ref) => CalorieDiary(ref));

// ── Goal ────────────────────────────────────────────────────────────────

String _goalCacheKey(String userId) => 'cal_goal_v1_$userId';

/// The current user's goal, or null if there really is none. Falls back to
/// the last known goal on this device when the server cannot be reached,
/// and throws (AsyncError) only without one — never "no goal" on error.
final nutritionGoalProvider = FutureProvider.autoDispose<NutritionGoal?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;
  final service = ref.watch(nutritionGoalServiceProvider);
  final prefs = await ref.watch(calorieSharedPreferencesProvider.future);
  final backend = ref.watch(calorieBackendProvider).valueOrNull;
  final pendingGoal = backend?.queue.writes
      .where((w) => w.kind == CalorieWriteKinds.goal)
      .lastOrNull;
  if (pendingGoal != null) return NutritionGoal.fromJson(pendingGoal.payload);
  try {
    final goal = await service.getGoal();
    if (goal == null) {
      await prefs.remove(_goalCacheKey(userId));
    } else {
      await prefs.setString(_goalCacheKey(userId), jsonEncode({
        ...goal.toUpsertJson(schemaV2: true),
        'created_at': goal.createdAt.toIso8601String(),
        'updated_at': goal.updatedAt.toIso8601String(),
      }));
    }
    return goal;
  } catch (e) {
    final cached = prefs.getString(_goalCacheKey(userId));
    if (cached == null) rethrow;
    return NutritionGoal.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }
});

/// What the diary and the Home card know about the goal in this frame.
enum CalorieGoalStatus {
  /// First start without a stored goal, the server has not answered yet.
  loading,

  /// There really is no goal (or no calorie target in it).
  none,

  /// A goal with a calorie target ([CalorieGoalState.goal]).
  set,

  /// Loading failed and this device has no goal stored. Never shown as
  /// "no goal" (concept 15 2.1).
  error,
}

class CalorieGoalState {
  const CalorieGoalState(this.status, [this.goal]);

  final CalorieGoalStatus status;

  /// Set only for [CalorieGoalStatus.set].
  final NutritionGoal? goal;

  int? get kcal => goal?.dailyCalorieTarget;
}

CalorieGoalState _goalStateOf(NutritionGoal? goal) => goal != null && goal.isConfigured
    ? CalorieGoalState(CalorieGoalStatus.set, goal)
    : const CalorieGoalState(CalorieGoalStatus.none);

/// [nutritionGoalProvider] for the first frame: while the server answers,
/// the goal stored on this device stands in, so nothing jumps.
final calorieGoalStateProvider = Provider.autoDispose<CalorieGoalState>((ref) {
  final async = ref.watch(nutritionGoalProvider);
  CalorieGoalState? stored() {
    final userId = ref.watch(authUserIdProvider);
    final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
    final raw = userId == null ? null : prefs?.getString(_goalCacheKey(userId));
    if (raw == null) return null;
    try {
      return _goalStateOf(NutritionGoal.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (_) {
      return null;
    }
  }

  return async.when(
    data: _goalStateOf,
    loading: () => stored() ?? const CalorieGoalState(CalorieGoalStatus.loading),
    error: (_, __) => stored() ?? const CalorieGoalState(CalorieGoalStatus.error),
  );
});

// ── Old screens still in use (week, weight; until their slices) ───────

/// The assembled weekly look-back, or null while no goal is configured.
/// Fetches its inputs in one go, so one change invalidates one provider.
final weeklyNutritionSummaryProvider =
    FutureProvider.autoDispose<WeeklyNutritionSummary?>((ref) async {
  final goal = await ref.watch(nutritionGoalProvider.future);
  if (goal == null || !goal.isConfigured) return null;
  final food = ref.watch(foodLogServiceProvider);
  final water = ref.watch(waterLogServiceProvider);
  final weight = ref.watch(weightLogServiceProvider);

  // Started together, awaited after: concurrent round trips.
  final dailyTotals = food.getWeeklyTotals();
  final waterTotals = water.getWeeklyTotals();
  final weightHistory = weight.getHistory();
  final loggedDates = food.getRecentLoggedDates();
  final recipeSourced = food.getWeeklyRecipeSourcedEntries();

  return WeeklyNutritionSummary.compute(
    dailyTotals: await dailyTotals,
    waterTotals: await waterTotals,
    weightHistory: await weightHistory,
    loggedDates: await loggedDates,
    goal: goal,
    today: ref.read(calorieClockProvider)(),
    recipeSourcedEntries: await recipeSourced,
  );
});

/// Weight history for the progress chart (last 90 days).
final weightHistoryProvider = FutureProvider.autoDispose<List<WeightLogEntry>>((ref) async {
  final service = ref.watch(weightLogServiceProvider);
  return service.getHistory();
});

/// For callers that wrote directly through a service (Avo, old sheets):
/// reloads today and the weekly views. New code writes
/// through [calorieDiaryProvider] and never needs this.
void invalidateNutritionLog(WidgetRef ref) {
  final today = calorieDayKey(ref.read(calorieClockProvider)());
  unawaited(ref.read(calorieDayProvider(today).notifier).refresh());
  ref.invalidate(calorieWeekServerProvider(calorieWeekStartKey(today)));
  ref.invalidate(weeklyNutritionSummaryProvider);
  ref.invalidate(weightHistoryProvider);
}
