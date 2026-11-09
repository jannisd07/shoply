// `shoply/camera` (S4 camera, S3 photo picker): the Dart side of
// MealCameraChannel.swift. The native screens cannot run in tests; this checks
// what the wrapper sends and how it reads every answer.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('shoply/camera');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(method, null));

  MealCameraChannel ios() => MealCameraChannel(isSupported: () => true);

  const labels = MealCameraLabels(
    hint: 'Den Teller von oben …',
    hintShort: 'Teller von oben fotografieren.',
    back: 'Zurück',
    flash: 'Blitz',
    flashOn: 'An',
    flashOff: 'Aus',
    shutter: 'Foto aufnehmen',
    library: 'Aus Fotos',
  );
  final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);

  test('takePhoto sends the labels and returns the captured JPEG', () async {
    answer((_) => {'status': 'captured', 'bytes': jpeg});
    final result = await ios().takePhoto(labels: labels);
    expect(calls.single.method, 'takePhoto');
    expect((calls.single.arguments as Map)['shutter'], 'Foto aufnehmen');
    expect((calls.single.arguments as Map)['hintShort'], 'Teller von oben fotografieren.');
    expect(result.status, MealPhotoStatus.captured);
    expect(result.bytes, jpeg);
    expect(result.hasPhoto, isTrue);
  });

  test('pickPhoto returns the picked JPEG; closing is "cancelled"', () async {
    answer((_) => {'status': 'picked', 'bytes': jpeg});
    expect((await ios().pickPhoto()).status, MealPhotoStatus.picked);

    answer((_) => {'status': 'cancelled'});
    final closed = await ios().pickPhoto();
    expect(closed.status, MealPhotoStatus.cancelled);
    expect(closed.hasPhoto, isFalse);
  });

  test('a photo without bytes is no photo', () async {
    answer((_) => {'status': 'captured'});
    expect((await ios().takePhoto(labels: labels)).status, MealPhotoStatus.cancelled);
  });

  test('camera not allowed: permissionDenied; busy: busy', () async {
    answer((_) => throw PlatformException(code: 'permission_denied'));
    await expectLater(
      ios().takePhoto(labels: labels),
      throwsA(isA<NativeChannelException>().having((e) => e.code, 'code', NativeErrorCode.permissionDenied)),
    );
    answer((_) => throw PlatformException(code: 'busy'));
    await expectLater(
      ios().pickPhoto(),
      throwsA(isA<NativeChannelException>().having((e) => e.code, 'code', NativeErrorCode.busy)),
    );
  });

  test('no camera, other platforms or no plugin: "unavailable", never a crash', () async {
    answer((_) => throw PlatformException(code: 'unavailable'));
    expect((await ios().takePhoto(labels: labels)).status, MealPhotoStatus.unavailable);

    calls.clear();
    final android = MealCameraChannel(isSupported: () => false);
    expect((await android.takePhoto(labels: labels)).status, MealPhotoStatus.unavailable);
    expect(await android.isAvailable(), isFalse);
    expect(calls, isEmpty);

    messenger.setMockMethodCallHandler(method, null);
    expect((await ios().pickPhoto()).status, MealPhotoStatus.unavailable);
  });

  test('isAvailable asks the native side', () async {
    answer((_) => true);
    expect(await ios().isAvailable(), isTrue);
    expect(calls.single.method, 'isAvailable');
  });
}
