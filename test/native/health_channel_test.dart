import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/native/health_channel.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('shoply/health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(method, null));

  HealthChannel ios() => HealthChannel(isSupported: () => true);

  final noon = DateTime.utc(2026, 11, 7, 12);
  final evening = DateTime.utc(2026, 11, 7, 18, 30);

  group('availability', () {
    test('asks the native side', () async {
      answer((_) => true);

      expect(await ios().isAvailable(), isTrue);
      expect(calls.single.method, 'isAvailable');
    });

    test('is false without a channel call on other platforms', () async {
      answer((_) => true);

      expect(await HealthChannel(isSupported: () => false).isAvailable(), isFalse);
      expect(calls, isEmpty);
    });

    test('is false when the native side is missing', () async {
      expect(await ios().isAvailable(), isFalse);
    });
  });

  group('requestAuthorization', () {
    test('reports that the system dialog finished', () async {
      answer((_) => true);

      expect(await ios().requestAuthorization(), isTrue);
      expect(calls.single.method, 'requestAuthorization');
    });

    test('is false when Health is unavailable', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await ios().requestAuthorization(), isFalse);
    });

    test('maps other failures to NativeChannelException', () async {
      answer((_) => throw PlatformException(code: 'failed', message: 'boom'));

      await expectLater(
        ios().requestAuthorization(),
        throwsA(
          isA<NativeChannelException>()
              .having((e) => e.code, 'code', NativeErrorCode.failed)
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });
  });

  test('writeStatus parses every write type and defaults unknown values', () async {
    answer(
      (_) => {
        'food': 'authorized',
        'water': 'denied',
        'bodyMass': 'notDetermined',
        'workout': 'something new',
      },
    );

    final status = await ios().writeStatus();

    expect(status, {
      HealthWriteType.food: HealthWriteStatus.authorized,
      HealthWriteType.water: HealthWriteStatus.denied,
      HealthWriteType.bodyMass: HealthWriteStatus.notDetermined,
      HealthWriteType.workout: HealthWriteStatus.notDetermined,
    });
  });

  test('writeStatus is notDetermined everywhere on other platforms', () async {
    final status = await HealthChannel(isSupported: () => false).writeStatus();

    expect(status.values.toSet(), {HealthWriteStatus.notDetermined});
    expect(status.keys.toSet(), HealthWriteType.values.toSet());
  });

  group('writes', () {
    test('writeFood sends the sync identity, time and nutrients', () async {
      answer((_) => 'uuid-food');

      final uuid = await ios().writeFood(
        HealthFoodEntry(
          syncId: 'entry-1',
          syncVersion: 3,
          date: noon,
          kcal: 512,
          proteinG: 20.5,
          fatG: 11,
          name: 'Müsli mit Joghurt',
        ),
      );

      expect(uuid, 'uuid-food');
      expect(calls.single.method, 'writeFood');
      expect(calls.single.arguments, {
        'syncId': 'entry-1',
        'syncVersion': 3,
        'date': noon.millisecondsSinceEpoch,
        'kcal': 512.0,
        'proteinG': 20.5,
        'fatG': 11.0,
        'name': 'Müsli mit Joghurt',
      });
    });

    test('writeWater sends millilitres', () async {
      answer((_) => 'uuid-water');

      final uuid = await ios().writeWater(
        HealthWaterEntry(syncId: 'w-1', syncVersion: 1, date: noon, ml: 250),
      );

      expect(uuid, 'uuid-water');
      expect(calls.single.method, 'writeWater');
      expect(calls.single.arguments, {
        'syncId': 'w-1',
        'syncVersion': 1,
        'date': noon.millisecondsSinceEpoch,
        'ml': 250.0,
      });
    });

    test('writeBodyMass sends kilograms', () async {
      answer((_) => 'uuid-mass');

      await ios().writeBodyMass(
        HealthBodyMassEntry(
          syncId: 'm-1',
          syncVersion: 2,
          date: noon,
          kg: 72.4,
        ),
      );

      expect(calls.single.method, 'writeBodyMass');
      expect(calls.single.arguments, {
        'syncId': 'm-1',
        'syncVersion': 2,
        'date': noon.millisecondsSinceEpoch,
        'kg': 72.4,
      });
    });

    test('writeWorkout sends activity, start, end and energy', () async {
      answer((_) => 'uuid-workout');

      await ios().writeWorkout(
        HealthWorkoutEntry(
          syncId: 'wo-1',
          syncVersion: 1,
          activity: HealthWorkoutActivity.strength,
          start: noon,
          end: evening,
          kcal: 280,
        ),
      );

      expect(calls.single.method, 'writeWorkout');
      expect(calls.single.arguments, {
        'syncId': 'wo-1',
        'syncVersion': 1,
        'activity': 'strength',
        'start': noon.millisecondsSinceEpoch,
        'end': evening.millisecondsSinceEpoch,
        'kcal': 280.0,
      });
    });

    test('a write is null when Health is unavailable', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      final uuid = await ios().writeWater(
        HealthWaterEntry(syncId: 'w-1', syncVersion: 1, date: noon, ml: 250),
      );

      expect(uuid, isNull);
    });

    test('a write is null without a channel call on other platforms', () async {
      answer((_) => 'uuid');

      final uuid = await HealthChannel(isSupported: () => false).writeWater(
        HealthWaterEntry(syncId: 'w-1', syncVersion: 1, date: noon, ml: 250),
      );

      expect(uuid, isNull);
      expect(calls, isEmpty);
    });

    test('a refused write throws permissionDenied', () async {
      answer((_) => throw PlatformException(code: 'permission_denied'));

      await expectLater(
        ios().writeBodyMass(
          HealthBodyMassEntry(syncId: 'm', syncVersion: 1, date: noon, kg: 70),
        ),
        throwsA(
          isA<NativeChannelException>().having(
            (e) => e.code,
            'code',
            NativeErrorCode.permissionDenied,
          ),
        ),
      );
    });

    test('rejects an entry without sync identity before calling native', () async {
      answer((_) => 'uuid');

      expect(
        () => ios().writeWater(
          HealthWaterEntry(syncId: '', syncVersion: 1, date: noon, ml: 250),
        ),
        throwsArgumentError,
      );
      expect(
        () => ios().writeWater(
          HealthWaterEntry(syncId: 'w', syncVersion: 0, date: noon, ml: 250),
        ),
        throwsArgumentError,
      );
      expect(
        () => ios().writeWorkout(
          HealthWorkoutEntry(
            syncId: 'wo',
            syncVersion: 1,
            activity: HealthWorkoutActivity.running,
            start: evening,
            end: noon,
          ),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });
  });

  group('delete', () {
    test('sends type and sync identifier', () async {
      answer((_) => true);

      final deleted = await ios().delete(HealthWriteType.food, 'entry-1');

      expect(deleted, isTrue);
      expect(calls.single.method, 'delete');
      expect(calls.single.arguments, {'type': 'food', 'syncId': 'entry-1'});
    });

    test('is false when Health is unavailable', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await ios().delete(HealthWriteType.water, 'w-1'), isFalse);
    });
  });

  group('reads', () {
    test('readBodyMass sends the range and parses samples', () async {
      answer(
        (_) => [
          {
            'uuid': 'a',
            'date': noon.millisecondsSinceEpoch,
            'value': 72.4,
            'sourceName': 'Withings',
            'isOwn': false,
            'deviceName': 'Body+',
          },
          {
            'uuid': 'b',
            'date': evening.millisecondsSinceEpoch,
            'value': 72,
            'sourceName': 'Avo',
            'isOwn': true,
            'syncId': 'm-1',
          },
          {'uuid': 'broken'},
        ],
      );

      final samples = await ios().readBodyMass(from: noon, to: evening);

      expect(calls.single.method, 'readBodyMass');
      expect(calls.single.arguments, {
        'from': noon.millisecondsSinceEpoch,
        'to': evening.millisecondsSinceEpoch,
      });
      expect(samples, hasLength(2));
      expect(samples.first.uuid, 'a');
      expect(samples.first.date, noon.toLocal());
      expect(samples.first.value, 72.4);
      expect(samples.first.sourceName, 'Withings');
      expect(samples.first.deviceName, 'Body+');
      expect(samples.first.isOwn, isFalse);
      expect(samples.first.syncId, isNull);
      expect(samples.last.isOwn, isTrue);
      expect(samples.last.syncId, 'm-1');
      expect(samples.last.value, 72.0);
    });

    test('readWater uses its own method', () async {
      answer((_) => <Object?>[]);

      final samples = await ios().readWater(from: noon, to: evening);

      expect(samples, isEmpty);
      expect(calls.single.method, 'readWater');
    });

    test('reads are empty on other platforms and when unavailable', () async {
      expect(
        await HealthChannel(
          isSupported: () => false,
        ).readBodyMass(from: noon, to: evening),
        isEmpty,
      );

      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await ios().readWorkouts(from: noon, to: evening), isEmpty);
      expect(await ios().readLatestHeight(), isNull);
      expect(await ios().readDateOfBirth(), isNull);
    });

    test('readLatestHeight parses one sample or null', () async {
      answer(
        (_) => {
          'uuid': 'h',
          'date': noon.millisecondsSinceEpoch,
          'value': 181.5,
          'sourceName': 'Health',
          'isOwn': false,
        },
      );

      final height = await ios().readLatestHeight();

      expect(height?.value, 181.5);
      expect(calls.single.method, 'readLatestHeight');

      answer((_) => null);

      expect(await ios().readLatestHeight(), isNull);
    });

    test('readWorkouts parses activity, time and optional energy', () async {
      answer(
        (_) => [
          {
            'uuid': 'w1',
            'activity': 'running',
            'start': noon.millisecondsSinceEpoch,
            'end': evening.millisecondsSinceEpoch,
            'kcal': 280.5,
            'sourceName': 'Apple Watch von Jannis',
            'isOwn': false,
          },
          {
            'uuid': 'w2',
            'activity': 'paragliding',
            'start': noon.millisecondsSinceEpoch,
            'end': evening.millisecondsSinceEpoch,
            'sourceName': 'Avo',
            'isOwn': true,
            'syncId': 'wo-1',
          },
        ],
      );

      final workouts = await ios().readWorkouts(from: noon, to: evening);

      expect(calls.single.method, 'readWorkouts');
      expect(workouts, hasLength(2));
      expect(workouts.first.activity, HealthWorkoutActivity.running);
      expect(workouts.first.kcal, 280.5);
      expect(workouts.first.duration, evening.difference(noon));
      expect(workouts.last.activity, HealthWorkoutActivity.other);
      expect(workouts.last.kcal, isNull);
      expect(workouts.last.syncId, 'wo-1');
    });

    test('readDateOfBirth builds a calendar date', () async {
      answer((_) => {'year': 1990, 'month': 5, 'day': 17});

      expect(await ios().readDateOfBirth(), DateTime(1990, 5, 17));
      expect(calls.single.method, 'readDateOfBirth');

      answer((_) => null);

      expect(await ios().readDateOfBirth(), isNull);
    });
  });

  group('error codes', () {
    test('every native code maps to one Dart code', () {
      expect(nativeErrorCodeFrom('unavailable'), NativeErrorCode.unavailable);
      expect(
        nativeErrorCodeFrom('permission_denied'),
        NativeErrorCode.permissionDenied,
      );
      expect(
        nativeErrorCodeFrom('invalid_args'),
        NativeErrorCode.invalidArguments,
      );
      expect(nativeErrorCodeFrom('busy'), NativeErrorCode.busy);
      expect(nativeErrorCodeFrom('cancelled'), NativeErrorCode.cancelled);
      expect(nativeErrorCodeFrom('failed'), NativeErrorCode.failed);
      expect(nativeErrorCodeFrom('whatever'), NativeErrorCode.failed);
    });

    test('invalid arguments reach the caller as invalidArguments', () async {
      answer((_) => throw PlatformException(code: 'invalid_args'));

      await expectLater(
        ios().delete(HealthWriteType.workout, 'x'),
        throwsA(
          isA<NativeChannelException>().having(
            (e) => e.code,
            'code',
            NativeErrorCode.invalidArguments,
          ),
        ),
      );
    });
  });
}
