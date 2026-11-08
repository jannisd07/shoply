import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/health_sync_service.dart';
import 'package:shoply/data/services/native/health_channel.dart';

class _FakeBridge implements HealthBridge {
  final List<String> calls = [];
  List<HealthWorkoutSample> workouts = [];
  List<HealthWeightSample> weights = [];
  bool failWrites = false;

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
  }) async {
    if (failWrites) throw Exception('HealthKit denied');
    calls.add('food $entryId v$version $kcal');
  }

  @override
  Future<void> deleteBySyncId(String id) async => calls.add('delete $id');

  @override
  Future<void> writeWater({
    required String entryId,
    required int version,
    required int ml,
    required DateTime date,
  }) async =>
      calls.add('water $entryId $ml');

  @override
  Future<void> writeWeight({
    required String entryId,
    required int version,
    required double kg,
    required DateTime date,
  }) async =>
      calls.add('weight $entryId $kg');

  @override
  Future<void> writeWorkout({
    required String entryId,
    required int version,
    required String type,
    required DateTime start,
    required int durationMin,
    int? kcal,
  }) async =>
      calls.add('workout $entryId $type');

  @override
  Future<List<HealthWeightSample>> readWeights(DateTime since) async => weights;

  @override
  Future<List<HealthWorkoutSample>> readWorkouts(DateTime since) async => workouts;
}

/// Timers that only fire when the test says so.
class _Timers {
  final List<_FakeTimer> all = [];
  Timer call(Duration d, void Function() cb) {
    final t = _FakeTimer(d, cb);
    all.add(t);
    return t;
  }

  void fireAll() {
    for (final t in List.of(all)) {
      t.fire();
    }
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);
  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

FoodLogEntry _entry() => FoodLogEntry(
      id: 'e1',
      userId: 'u1',
      loggedDate: DateTime(2026, 11, 7),
      mealType: MealType.dinner,
      foodName: 'Studentenfutter',
      calories: 132,
      proteinG: 4,
      createdAt: DateTime.utc(2026, 11, 7, 16),
      updatedAt: DateTime.utc(2026, 11, 7, 16, 5),
    );

void main() {
  late _FakeBridge bridge;
  late _Timers timers;
  late SharedPreferences prefs;
  late DateTime now;
  var active = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    bridge = _FakeBridge();
    timers = _Timers();
    now = DateTime.utc(2026, 11, 7, 16, 10);
    active = true;
  });

  HealthSyncService service() => HealthSyncService(
        bridge: bridge,
        isActive: () => active,
        prefs: prefs,
        now: () => now,
        timerFactory: timers.call,
      );

  test('deletes reach Health only after the 10 s undo window', () async {
    final s = service();
    await s.scheduleDelete(HealthSyncIds.food('e1'));
    expect(bridge.calls, isEmpty);
    expect(timers.all.single.duration, const Duration(seconds: 10));
    timers.fireAll();
    await pumpEventQueue();
    expect(bridge.calls, ['delete food:e1']);
  });

  test('undo inside the window cancels the delete', () async {
    final s = service();
    await s.scheduleDelete(HealthSyncIds.food('e1'));
    expect(await s.cancelDelete(HealthSyncIds.food('e1')), isTrue);
    timers.fireAll();
    await pumpEventQueue();
    expect(bridge.calls, isEmpty);
    expect(await s.cancelDelete(HealthSyncIds.food('e1')), isFalse);
  });

  test('a delete still due after a restart runs then', () async {
    final first = service();
    await first.scheduleDelete(HealthSyncIds.water('w1'));
    first.dispose();
    expect(bridge.calls, isEmpty);

    now = now.add(const Duration(seconds: 30));
    final second = service();
    await second.resumePendingDeletes();
    expect(bridge.calls, ['delete water:w1']);
  });

  test('a delete not yet due after a restart waits for the rest', () async {
    final first = service();
    await first.scheduleDelete(HealthSyncIds.weight('g1'));
    first.dispose();
    now = now.add(const Duration(seconds: 4));
    final second = service();
    await second.resumePendingDeletes();
    expect(bridge.calls, isEmpty);
    expect(timers.all.last.duration, const Duration(seconds: 6));
  });

  test('writes food with sync id and a version from updated_at', () async {
    await service().foodLogged(_entry());
    expect(bridge.calls.single, startsWith('food food:e1 v'));
    expect(bridge.calls.single, endsWith(' 132'));
  });

  test('nothing is written while the module is off or Health is not connected', () async {
    active = false;
    final s = service();
    await s.foodLogged(_entry());
    await s.scheduleDelete(HealthSyncIds.food('e1'));
    timers.fireAll();
    await pumpEventQueue();
    expect(bridge.calls, isEmpty);
  });

  test('a Health error never reaches the caller', () async {
    bridge.failWrites = true;
    await expectLater(service().foodLogged(_entry()), completes);
  });

  test('reads only workouts and weights written by other apps', () async {
    bridge.workouts = [
      HealthWorkoutSample(
        uuid: 'hk1',
        start: DateTime.utc(2026, 11, 7, 17, 5),
        durationMin: 32,
        type: 'running',
        kcal: 280,
        sourceName: 'Apple Watch',
        isOwnSource: false,
      ),
      HealthWorkoutSample(
        uuid: 'hk2',
        start: DateTime.utc(2026, 11, 6, 17),
        durationMin: 45,
        type: 'strength',
        kcal: 260,
        sourceName: 'Avo',
        isOwnSource: true,
      ),
    ];
    bridge.weights = [
      HealthWeightSample(uuid: 'w1', date: DateTime.utc(2026, 10, 31), kg: 73, sourceName: 'Withings', isOwnSource: false),
      HealthWeightSample(uuid: 'w2', date: DateTime.utc(2026, 11, 7), kg: 72.4, sourceName: 'Avo', isOwnSource: true),
    ];
    final s = service();
    final workouts = await s.foreignWorkouts(DateTime.utc(2026, 11, 1), userId: 'u1');
    expect(workouts.single.id, 'health:hk1');
    expect(workouts.single.source, WorkoutSource.health);
    expect(workouts.single.type, WorkoutType.running);
    expect(workouts.single.sourceName, 'Apple Watch');
    final weights = await s.foreignWeights(DateTime.utc(2026, 10, 1));
    expect(weights.single.sourceName, 'Withings');
  });

  test('sync ids carry the kind so the bridge knows the Health type', () {
    expect(HealthSyncIds.food('a'), 'food:a');
    expect(HealthSyncIds.workout('b'), 'workout:b');
  });

  group('HealthChannelBridge', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/health');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'delete' => true,
          'readWorkouts' => [
              {
                'uuid': 'hk1',
                'activity': 'running',
                'start': DateTime.utc(2026, 11, 7, 17).millisecondsSinceEpoch,
                'end': DateTime.utc(2026, 11, 7, 17, 32).millisecondsSinceEpoch,
                'sourceName': 'Apple Watch',
                'isOwn': false,
                'kcal': 280.4,
              },
            ],
          _ => 'uuid-1',
        };
      });
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    HealthChannelBridge bridge() => HealthChannelBridge(
          HealthChannel(channel: channel, isSupported: () => true),
          now: () => DateTime.utc(2026, 11, 8),
        );

    test('a delete goes to the type named by the sync id prefix', () async {
      await bridge().deleteBySyncId(HealthSyncIds.weight('2026-11-07'));
      expect(calls.single.method, 'delete');
      expect(calls.single.arguments, {'type': 'bodyMass', 'syncId': '2026-11-07'});
    });

    test('food is written with the raw entry id and its version', () async {
      await bridge().writeFood(
        entryId: HealthSyncIds.food('e1'),
        version: 5,
        kcal: 132,
        protein: 4,
        date: DateTime.utc(2026, 11, 7, 16),
        name: 'Studentenfutter',
      );
      final args = calls.single.arguments as Map;
      expect(calls.single.method, 'writeFood');
      expect(args['syncId'], 'e1');
      expect(args['syncVersion'], 5);
      expect(args['kcal'], 132.0);
      expect(args['name'], 'Studentenfutter');
    });

    test('a workout gets its end from the duration', () async {
      final start = DateTime.utc(2026, 11, 7, 18);
      await bridge().writeWorkout(
        entryId: HealthSyncIds.workout('w1'),
        version: 1,
        type: 'strength',
        start: start,
        durationMin: 45,
        kcal: 260,
      );
      final args = calls.single.arguments as Map;
      expect(args['activity'], 'strength');
      expect(args['end'], start.add(const Duration(minutes: 45)).millisecondsSinceEpoch);
    });

    test('workouts read back as samples', () async {
      final list = await bridge().readWorkouts(DateTime.utc(2026, 11, 1));
      expect(list.single.durationMin, 32);
      expect(list.single.kcal, 280);
      expect(list.single.isOwnSource, isFalse);
      expect(list.single.type, 'running');
    });
  });
}
