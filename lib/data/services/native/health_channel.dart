import 'package:flutter/services.dart';

import 'package:shoply/data/services/native/native_channel_errors.dart';

/// What Avo writes to Apple Health. Each maps to the HealthKit types in
/// `HealthKitChannel.swift`.
enum HealthWriteType {
  /// Food correlation with energy, protein, carbohydrates and fat.
  food,
  water,
  bodyMass,
  workout,
}

/// Write permission per type. Read permission cannot be queried on iOS:
/// a refused read simply returns no samples.
enum HealthWriteStatus { notDetermined, denied, authorized }

/// Workout kinds of the workout editor (concept 15, S18).
enum HealthWorkoutActivity {
  running,
  walking,
  cycling,
  swimming,
  strength,
  yoga,
  hiit,
  hiking,
  dance,
  other,
}

/// Every sample Avo writes carries the entry id as sync identifier and a
/// version (`HKMetadataKeySyncIdentifier` / `HKMetadataKeySyncVersion`):
/// writing a higher version replaces the old sample, deleting by the id
/// removes it.
abstract class HealthSyncedEntry {
  const HealthSyncedEntry({required this.syncId, required this.syncVersion});

  /// The app's entry id (e.g. `food_log_entries.id`).
  final String syncId;

  /// Grows with every change, e.g. `updated_at` in milliseconds.
  final int syncVersion;

  Map<String, Object?> toArgs();

  Map<String, Object?> get _syncArgs => {
    'syncId': syncId,
    'syncVersion': syncVersion,
  };

  void _validate() {
    if (syncId.trim().isEmpty) {
      throw ArgumentError.value(syncId, 'syncId', 'must not be empty');
    }
    if (syncVersion < 1) {
      throw ArgumentError.value(syncVersion, 'syncVersion', 'must be >= 1');
    }
  }
}

class HealthFoodEntry extends HealthSyncedEntry {
  const HealthFoodEntry({
    required super.syncId,
    required super.syncVersion,
    required this.date,
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.name,
  });

  final DateTime date;
  final double kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  /// Shown in Health as the food name (`HKMetadataKeyFoodType`).
  final String? name;

  @override
  Map<String, Object?> toArgs() => {
    ..._syncArgs,
    'date': date.millisecondsSinceEpoch,
    'kcal': kcal.toDouble(),
    if (proteinG != null) 'proteinG': proteinG!.toDouble(),
    if (carbsG != null) 'carbsG': carbsG!.toDouble(),
    if (fatG != null) 'fatG': fatG!.toDouble(),
    if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
  };
}

class HealthWaterEntry extends HealthSyncedEntry {
  const HealthWaterEntry({
    required super.syncId,
    required super.syncVersion,
    required this.date,
    required this.ml,
  });

  final DateTime date;
  final double ml;

  @override
  Map<String, Object?> toArgs() => {
    ..._syncArgs,
    'date': date.millisecondsSinceEpoch,
    'ml': ml.toDouble(),
  };
}

class HealthBodyMassEntry extends HealthSyncedEntry {
  const HealthBodyMassEntry({
    required super.syncId,
    required super.syncVersion,
    required this.date,
    required this.kg,
  });

  final DateTime date;
  final double kg;

  @override
  Map<String, Object?> toArgs() => {
    ..._syncArgs,
    'date': date.millisecondsSinceEpoch,
    'kg': kg.toDouble(),
  };
}

class HealthWorkoutEntry extends HealthSyncedEntry {
  const HealthWorkoutEntry({
    required super.syncId,
    required super.syncVersion,
    required this.activity,
    required this.start,
    required this.end,
    this.kcal,
  });

  final HealthWorkoutActivity activity;
  final DateTime start;
  final DateTime end;

  /// Active energy; written as an `activeEnergyBurned` sample of the workout.
  final double? kcal;

  @override
  Map<String, Object?> toArgs() => {
    ..._syncArgs,
    'activity': activity.name,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    if (kcal != null) 'kcal': kcal!.toDouble(),
  };

  @override
  void _validate() {
    super._validate();
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
  }
}

/// A body mass (kg), water (ml) or height (cm) sample read from Health.
class HealthQuantityReading {
  const HealthQuantityReading({
    required this.uuid,
    required this.date,
    required this.value,
    required this.sourceName,
    required this.isOwn,
    this.deviceName,
    this.syncId,
  });

  final String uuid;
  final DateTime date;
  final double value;

  /// App or device that wrote it ("Withings", "Health").
  final String sourceName;

  /// Written by Avo itself; the screen shows the app's own row instead.
  final bool isOwn;
  final String? deviceName;
  final String? syncId;

  static HealthQuantityReading? fromNative(Object? raw) {
    final map = nativeMap(raw);
    if (map == null) return null;
    final uuid = map['uuid'];
    final date = nativeDate(map['date']);
    final value = map['value'];
    if (uuid is! String || date == null || value is! num) return null;
    return HealthQuantityReading(
      uuid: uuid,
      date: date,
      value: value.toDouble(),
      sourceName: map['sourceName'] as String? ?? '',
      isOwn: map['isOwn'] == true,
      deviceName: map['deviceName'] as String?,
      syncId: map['syncId'] as String?,
    );
  }
}

/// A workout read from Health (own or from Apple Watch and other apps).
class HealthWorkoutReading {
  const HealthWorkoutReading({
    required this.uuid,
    required this.activity,
    required this.start,
    required this.end,
    required this.sourceName,
    required this.isOwn,
    this.kcal,
    this.deviceName,
    this.syncId,
  });

  final String uuid;
  final HealthWorkoutActivity activity;
  final DateTime start;
  final DateTime end;
  final String sourceName;
  final bool isOwn;
  final double? kcal;
  final String? deviceName;
  final String? syncId;

  Duration get duration => end.difference(start);

  static HealthWorkoutReading? fromNative(Object? raw) {
    final map = nativeMap(raw);
    if (map == null) return null;
    final uuid = map['uuid'];
    final start = nativeDate(map['start']);
    final end = nativeDate(map['end']);
    if (uuid is! String || start == null || end == null) return null;
    final kcal = map['kcal'];
    return HealthWorkoutReading(
      uuid: uuid,
      activity: HealthWorkoutActivity.values.firstWhere(
        (a) => a.name == map['activity'],
        orElse: () => HealthWorkoutActivity.other,
      ),
      start: start,
      end: end,
      sourceName: map['sourceName'] as String? ?? '',
      isOwn: map['isOwn'] == true,
      kcal: kcal is num ? kcal.toDouble() : null,
      deviceName: map['deviceName'] as String?,
      syncId: map['syncId'] as String?,
    );
  }
}

/// Apple Health over `shoply/health` (`HealthKitChannel.swift`).
///
/// Never asks for permission by itself: only [requestAuthorization] shows the
/// system dialog, and only after the "Apple Health verbinden" screen. Avo
/// never reads nutrition other apps wrote (double counting), and what it
/// reads stays on the device.
///
/// Unavailable (other platforms, iPad without Health, plugin missing) gives
/// false / null / an empty list. Other failures throw
/// [NativeChannelException].
class HealthChannel {
  HealthChannel({
    MethodChannel channel = const MethodChannel('shoply/health'),
    bool Function()? isSupported,
  }) : _channel = channel,
       _isSupported = isSupported ?? isIOSPlatform;

  static final HealthChannel instance = HealthChannel();

  static const _tag = 'HEALTH';

  final MethodChannel _channel;
  final bool Function() _isSupported;

  Future<T> _guard<T>(T fallback, Future<T> Function() call) =>
      guardNativeCall(
        supported: _isSupported(),
        fallback: fallback,
        tag: _tag,
        call: call,
      );

  /// Whether this device has Health at all (false on most iPads).
  Future<bool> isAvailable() => _guard(
    false,
    () async => await _channel.invokeMethod<bool>('isAvailable') ?? false,
  );

  /// Shows the system dialog for every type Avo writes and reads. True means
  /// the dialog finished, not that anything was allowed.
  Future<bool> requestAuthorization() => _guard(
    false,
    () async =>
        await _channel.invokeMethod<bool>('requestAuthorization') ?? false,
  );

  /// Write permission per type.
  Future<Map<HealthWriteType, HealthWriteStatus>> writeStatus() async {
    final undetermined = {
      for (final type in HealthWriteType.values)
        type: HealthWriteStatus.notDetermined,
    };
    final raw = await _guard<Object?>(
      null,
      () => _channel.invokeMethod<Object?>('writeStatus'),
    );
    final map = nativeMap(raw);
    if (map == null) return undetermined;
    return {
      for (final type in HealthWriteType.values)
        type: HealthWriteStatus.values.firstWhere(
          (s) => s.name == map[type.name],
          orElse: () => HealthWriteStatus.notDetermined,
        ),
    };
  }

  /// Each write returns the UUID of the saved Health object (store it as
  /// `health_uuid`) or null when Health is unavailable.
  Future<String?> writeFood(HealthFoodEntry entry) => _write('writeFood', entry);

  Future<String?> writeWater(HealthWaterEntry entry) =>
      _write('writeWater', entry);

  Future<String?> writeBodyMass(HealthBodyMassEntry entry) =>
      _write('writeBodyMass', entry);

  Future<String?> writeWorkout(HealthWorkoutEntry entry) =>
      _write('writeWorkout', entry);

  Future<String?> _write(String method, HealthSyncedEntry entry) {
    entry._validate();
    return _guard(
      null,
      () => _channel.invokeMethod<String>(method, entry.toArgs()),
    );
  }

  /// Deletes everything Avo wrote for [syncId] (for food: the correlation
  /// and its nutrient samples). Call it after the undo window has passed.
  Future<bool> delete(HealthWriteType type, String syncId) => _guard(
    false,
    () async =>
        await _channel.invokeMethod<bool>('delete', {
          'type': type.name,
          'syncId': syncId,
        }) ??
        false,
  );

  /// Body mass in kg, newest first.
  Future<List<HealthQuantityReading>> readBodyMass({
    required DateTime from,
    required DateTime to,
  }) => _readQuantities('readBodyMass', from, to);

  /// Water in ml, newest first (includes other apps' water).
  Future<List<HealthQuantityReading>> readWater({
    required DateTime from,
    required DateTime to,
  }) => _readQuantities('readWater', from, to);

  Future<List<HealthQuantityReading>> _readQuantities(
    String method,
    DateTime from,
    DateTime to,
  ) async {
    final raw = await _guard<List<Object?>?>(
      null,
      () => _channel.invokeMethod<List<Object?>>(method, _range(from, to)),
    );
    return [
      for (final sample in raw ?? const <Object?>[])
        ?HealthQuantityReading.fromNative(sample),
    ];
  }

  /// The newest height sample in cm.
  Future<HealthQuantityReading?> readLatestHeight() async {
    final raw = await _guard<Object?>(
      null,
      () => _channel.invokeMethod<Object?>('readLatestHeight'),
    );
    return HealthQuantityReading.fromNative(raw);
  }

  /// Workouts in the range, newest first.
  Future<List<HealthWorkoutReading>> readWorkouts({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _guard<List<Object?>?>(
      null,
      () => _channel.invokeMethod<List<Object?>>(
        'readWorkouts',
        _range(from, to),
      ),
    );
    return [
      for (final workout in raw ?? const <Object?>[])
        ?HealthWorkoutReading.fromNative(workout),
    ];
  }

  /// Date of birth as a calendar date, read once for "Aus Apple Health
  /// übernehmen".
  Future<DateTime?> readDateOfBirth() async {
    final raw = await _guard<Object?>(
      null,
      () => _channel.invokeMethod<Object?>('readDateOfBirth'),
    );
    final map = nativeMap(raw);
    final year = map?['year'];
    final month = map?['month'];
    final day = map?['day'];
    if (year is! int || month is! int || day is! int) return null;
    return DateTime(year, month, day);
  }

  Map<String, Object?> _range(DateTime from, DateTime to) => {
    'from': from.millisecondsSinceEpoch,
    'to': to.millisecondsSinceEpoch,
  };
}
