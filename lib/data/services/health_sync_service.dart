import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/native/health_channel.dart';

/// A body-mass sample read from Apple Health.
class HealthWeightSample {
  final String uuid;
  final DateTime date;
  final double kg;

  /// Writing app or device ("Withings", "Avo").
  final String sourceName;

  /// Written by this app (bundle id matches): skipped on read, the app
  /// already has the value (concept 15 2.4 "nicht doppelt").
  final bool isOwnSource;

  const HealthWeightSample({
    required this.uuid,
    required this.date,
    required this.kg,
    required this.sourceName,
    required this.isOwnSource,
  });
}

/// A workout read from Apple Health. [type] is a [WorkoutType] name
/// (`running`, `strength`, …); the bridge maps `HKWorkoutActivityType`.
class HealthWorkoutSample {
  final String uuid;
  final DateTime start;
  final int durationMin;
  final String type;
  final int? kcal;
  final String sourceName;
  final bool isOwnSource;

  const HealthWorkoutSample({
    required this.uuid,
    required this.start,
    required this.durationMin,
    required this.type,
    required this.kcal,
    required this.sourceName,
    required this.isOwnSource,
  });
}

/// Native HealthKit access (implemented by `native/health_channel.dart` over
/// the `shoply/health` channel; no third-party package, owner 07.11.).
///
/// Contract for the implementation:
/// - `entryId` is the sync identifier, written as
///   `HKMetadataKeySyncIdentifier`; `version` goes into
///   `HKMetadataKeySyncVersion`, so writing again with a higher version
///   replaces the sample (edit = replace). Ids look like `food:<uuid>`
///   ([HealthSyncIds]); the prefix names the HealthKit type to delete.
/// - Food is one `HKCorrelationType.food` with energy, protein, carbs, fat.
/// - Errors are thrown; [HealthSyncService] catches and logs them.
/// - Reads never include `dietaryEnergyConsumed` of other apps (F-K4) and
///   their values stay on the device (F-K5).
abstract class HealthBridge {
  Future<void> writeFood({
    required String entryId,
    required int version,
    required int kcal,
    double? protein,
    double? carbs,
    double? fat,
    required DateTime date,
    String? name,
  });

  Future<void> deleteBySyncId(String id);

  Future<void> writeWater({
    required String entryId,
    required int version,
    required int ml,
    required DateTime date,
  });

  Future<void> writeWeight({
    required String entryId,
    required int version,
    required double kg,
    required DateTime date,
  });

  Future<void> writeWorkout({
    required String entryId,
    required int version,
    required String type,
    required DateTime start,
    required int durationMin,
    int? kcal,
  });

  Future<List<HealthWeightSample>> readWeights(DateTime since);

  Future<List<HealthWorkoutSample>> readWorkouts(DateTime since);
}

/// [HealthBridge] over [HealthChannel] (`shoply/health`). Splits the
/// `kind:id` sync ids of [HealthSyncIds] into the channel's type and the raw
/// entry id.
class HealthChannelBridge implements HealthBridge {
  HealthChannelBridge(this._channel, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final HealthChannel _channel;
  final DateTime Function() _now;

  static (HealthWriteType?, String) _split(String syncId) {
    final i = syncId.indexOf(':');
    if (i < 0) return (null, syncId);
    final type = switch (syncId.substring(0, i)) {
      'food' => HealthWriteType.food,
      'water' => HealthWriteType.water,
      'weight' => HealthWriteType.bodyMass,
      'workout' => HealthWriteType.workout,
      _ => null,
    };
    return (type, syncId.substring(i + 1));
  }

  static String _raw(String syncId) => _split(syncId).$2;

  @override
  Future<void> writeFood({
    required String entryId,
    required int version,
    required int kcal,
    double? protein,
    double? carbs,
    double? fat,
    required DateTime date,
    String? name,
  }) =>
      _channel.writeFood(HealthFoodEntry(
        syncId: _raw(entryId),
        syncVersion: version,
        date: date,
        kcal: kcal.toDouble(),
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        name: name,
      ));

  @override
  Future<void> writeWater({
    required String entryId,
    required int version,
    required int ml,
    required DateTime date,
  }) =>
      _channel.writeWater(HealthWaterEntry(
        syncId: _raw(entryId),
        syncVersion: version,
        date: date,
        ml: ml.toDouble(),
      ));

  @override
  Future<void> writeWeight({
    required String entryId,
    required int version,
    required double kg,
    required DateTime date,
  }) =>
      _channel.writeBodyMass(HealthBodyMassEntry(
        syncId: _raw(entryId),
        syncVersion: version,
        date: date,
        kg: kg,
      ));

  @override
  Future<void> writeWorkout({
    required String entryId,
    required int version,
    required String type,
    required DateTime start,
    required int durationMin,
    int? kcal,
  }) =>
      _channel.writeWorkout(HealthWorkoutEntry(
        syncId: _raw(entryId),
        syncVersion: version,
        activity: HealthWorkoutActivity.values.firstWhere(
          (a) => a.name == type,
          orElse: () => HealthWorkoutActivity.other,
        ),
        start: start,
        end: start.add(Duration(minutes: durationMin)),
        kcal: kcal?.toDouble(),
      ));

  @override
  Future<void> deleteBySyncId(String id) async {
    final (type, raw) = _split(id);
    for (final t in type == null ? HealthWriteType.values : [type]) {
      await _channel.delete(t, raw);
    }
  }

  @override
  Future<List<HealthWeightSample>> readWeights(DateTime since) async {
    final samples = await _channel.readBodyMass(from: since, to: _now());
    return [
      for (final s in samples)
        HealthWeightSample(
          uuid: s.uuid,
          date: s.date,
          kg: s.value,
          sourceName: s.deviceName ?? s.sourceName,
          isOwnSource: s.isOwn,
        ),
    ];
  }

  @override
  Future<List<HealthWorkoutSample>> readWorkouts(DateTime since) async {
    final workouts = await _channel.readWorkouts(from: since, to: _now());
    return [
      for (final w in workouts)
        HealthWorkoutSample(
          uuid: w.uuid,
          start: w.start,
          durationMin: w.duration.inMinutes,
          type: w.activity.name,
          kcal: w.kcal?.round(),
          sourceName: w.deviceName ?? w.sourceName,
          isOwnSource: w.isOwn,
        ),
    ];
  }
}

/// Sync identifiers shared by the app and the bridge.
abstract final class HealthSyncIds {
  static String food(String entryId) => 'food:$entryId';
  static String water(String entryId) => 'water:$entryId';
  static String weight(String entryId) => 'weight:$entryId';
  static String workout(String entryId) => 'workout:$entryId';
}

/// Thrown by the read methods so callers can tell "no Health data" from a
/// failure.
class HealthSyncException implements Exception {
  final Object cause;
  const HealthSyncException(this.cause);

  @override
  String toString() => 'HealthSyncException($cause)';
}

typedef HealthTimerFactory = Timer Function(Duration delay, void Function() callback);

/// Writes the diary to Apple Health and reads weights and workouts of other
/// apps. Never blocks a save: write errors are logged, not thrown.
/// Deletions wait for the undo window (concept 15 5.5): a delete only
/// reaches Health when nobody tapped "Widerrufen" within 10 s, and survives
/// an app restart in SharedPreferences.
class HealthSyncService {
  HealthSyncService({
    required HealthBridge bridge,
    required bool Function() isActive,
    required SharedPreferences prefs,
    this.undoWindow = const Duration(seconds: 10),
    DateTime Function()? now,
    HealthTimerFactory? timerFactory,
  })  : _bridge = bridge,
        _isActive = isActive,
        _prefs = prefs,
        _now = now ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new {
    _load();
  }

  static const _pendingKey = 'cal_health_pending_deletes_v1';

  final HealthBridge _bridge;

  /// Calories module on and Health connected on this device.
  final bool Function() _isActive;
  final SharedPreferences _prefs;
  final Duration undoWindow;
  final DateTime Function() _now;
  final HealthTimerFactory _timerFactory;

  final Map<String, DateTime> _pending = {};
  final Map<String, Timer> _timers = {};
  bool _disposed = false;

  /// Sync ids waiting for their undo window.
  Set<String> get pendingDeletes => Set.unmodifiable(_pending.keys);

  // ── Writes ────────────────────────────────────────────────────────────

  Future<void> foodLogged(FoodLogEntry entry) => _write('food', () async {
        final time = entry.loggedTime;
        final d = entry.loggedDate;
        await _bridge.writeFood(
          entryId: HealthSyncIds.food(entry.id),
          version: _version(entry.updatedAt ?? entry.createdAt),
          kcal: entry.calories,
          protein: entry.proteinG,
          carbs: entry.carbsG,
          fat: entry.fatG,
          name: entry.foodName,
          date: time == null
              ? entry.createdAt.toLocal()
              : DateTime(d.year, d.month, d.day, time.hour, time.minute),
        );
      });

  /// Undo of a delete: keep the Health sample and write the current state.
  Future<void> foodRestored(FoodLogEntry entry) async {
    await cancelDelete(HealthSyncIds.food(entry.id));
    await foodLogged(entry);
  }

  Future<void> waterLogged(WaterLogEntry entry) => _write('water', () async {
        await _bridge.writeWater(
          entryId: HealthSyncIds.water(entry.id),
          version: _version(entry.createdAt),
          ml: entry.amountMl,
          date: entry.createdAt.toLocal(),
        );
      });

  Future<void> weightLogged(WeightLogEntry entry, {DateTime? changedAt}) =>
      _write('weight', () async {
        final d = entry.loggedDate;
        await _bridge.writeWeight(
          entryId: HealthSyncIds.weight(entry.id),
          version: _version(changedAt ?? _now()),
          kg: entry.weightKg,
          date: DateTime(d.year, d.month, d.day, 8),
        );
      });

  Future<void> workoutLogged(Workout workout) async {
    if (workout.isReadOnly) return;
    await _write('workout', () async {
      await _bridge.writeWorkout(
        entryId: HealthSyncIds.workout(workout.id),
        version: _version(workout.updatedAt ?? workout.createdAt),
        type: workout.type.dbValue,
        start: workout.startedAt,
        durationMin: workout.durationMin,
        kcal: workout.calories,
      );
    });
  }

  Future<void> _write(String kind, Future<void> Function() run) async {
    if (!_isActive()) return;
    try {
      await run();
      debugPrint('✅ [HealthSync] $kind written');
    } catch (e) {
      debugPrint('⚠️ [HealthSync] Writing $kind failed: $e');
    }
  }

  static int _version(DateTime changedAt) => changedAt.millisecondsSinceEpoch;

  // ── Deferred deletes ──────────────────────────────────────────────────

  /// Deletes [syncId] from Health once the undo window has passed.
  Future<void> scheduleDelete(String syncId) async {
    final due = _now().add(undoWindow);
    _pending[syncId] = due;
    await _save();
    _arm(syncId, undoWindow);
  }

  /// "Widerrufen": true when a delete was still waiting.
  Future<bool> cancelDelete(String syncId) async {
    _timers.remove(syncId)?.cancel();
    final existed = _pending.remove(syncId) != null;
    if (existed) await _save();
    return existed;
  }

  /// Call at start: runs deletes whose window passed while the app was
  /// closed and re-arms the rest.
  Future<void> resumePendingDeletes() async {
    final now = _now();
    for (final entry in Map.of(_pending).entries) {
      final left = entry.value.difference(now);
      if (left <= Duration.zero) {
        await _runDelete(entry.key);
      } else {
        _arm(entry.key, left);
      }
    }
  }

  void _arm(String syncId, Duration delay) {
    _timers.remove(syncId)?.cancel();
    _timers[syncId] = _timerFactory(delay, () => unawaited(_runDelete(syncId)));
  }

  Future<void> _runDelete(String syncId) async {
    _timers.remove(syncId);
    if (_disposed || !_pending.containsKey(syncId)) return;
    // Module off or Health disconnected: keep it for later (sync paused).
    if (!_isActive()) return;
    _pending.remove(syncId);
    await _save();
    try {
      await _bridge.deleteBySyncId(syncId);
      debugPrint('✅ [HealthSync] Deleted $syncId');
    } catch (e) {
      debugPrint('⚠️ [HealthSync] Deleting $syncId failed: $e');
    }
  }

  void _load() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, String>();
      _pending.addAll(map.map((k, v) => MapEntry(k, DateTime.parse(v))));
    } catch (e) {
      debugPrint('❌ [HealthSync] Pending deletes unreadable: $e');
    }
  }

  Future<void> _save() => _prefs.setString(
        _pendingKey,
        jsonEncode(_pending.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );

  // ── Reads (stay on the device) ────────────────────────────────────────

  /// Workouts of other apps (Apple Watch …) since [since], read-only.
  Future<List<Workout>> foreignWorkouts(DateTime since, {required String userId}) async {
    if (!_isActive()) return const [];
    final List<HealthWorkoutSample> samples;
    try {
      samples = await _bridge.readWorkouts(since);
    } catch (e) {
      throw HealthSyncException(e);
    }
    return [
      for (final s in samples)
        if (!s.isOwnSource)
          Workout(
            id: 'health:${s.uuid}',
            userId: userId,
            startedAt: s.start,
            durationMin: s.durationMin,
            type: WorkoutTypeX.fromDb(s.type),
            calories: s.kcal,
            healthUuid: s.uuid,
            source: WorkoutSource.health,
            sourceName: s.sourceName,
            createdAt: s.start,
          ),
    ];
  }

  /// Weigh-ins of other apps (scales) since [since], read-only.
  Future<List<HealthWeightSample>> foreignWeights(DateTime since) async {
    if (!_isActive()) return const [];
    try {
      final samples = await _bridge.readWeights(since);
      return samples.where((s) => !s.isOwnSource).toList(growable: false);
    } catch (e) {
      throw HealthSyncException(e);
    }
  }

  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
