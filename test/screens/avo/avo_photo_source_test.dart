// The device photo source (W1b review I4): denial comes from image_picker's
// own error codes, not from permission_handler (its camera check is not
// compiled in on iOS); the camera note is remembered per install.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/screens/avo/avo_photo_source.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  DeviceAvoPhotoSource throwing(String code) => DeviceAvoPhotoSource(
    pick: (_) async => throw PlatformException(code: code, message: 'test'),
  );

  test('camera_access_denied and camera_access_restricted mean "Kamera ist '
      'aus"', () async {
    for (final code in ['camera_access_denied', 'camera_access_restricted']) {
      expect(
        (await throwing(code).take()).outcome,
        AvoPickOutcome.denied,
        reason: code,
      );
    }
  });

  test('other errors and a closed picker are no photo, not a denial', () async {
    expect(
      (await throwing('multiple_request').take()).outcome,
      AvoPickOutcome.cancelled,
    );
    expect(
      (await DeviceAvoPhotoSource(pick: (_) async => null).choose()).outcome,
      AvoPickOutcome.cancelled,
    );
  });

  test(
    'a picked photo comes back as bytes, from the source asked for',
    () async {
      final asked = <ImageSource>[];
      final source = DeviceAvoPhotoSource(
        pick: (s) async {
          asked.add(s);
          return XFile.fromData(Uint8List.fromList([1, 2, 3]));
        },
      );
      final pick = await source.take();
      expect(pick.outcome, AvoPickOutcome.photo);
      expect(pick.photo, [1, 2, 3]);
      await source.choose();
      expect(asked, [ImageSource.camera, ImageSource.gallery]);
    },
  );

  test('the camera note is shown once per install', () async {
    final source = DeviceAvoPhotoSource(pick: (_) async => null);
    expect(await source.cameraExplained(), isFalse);
    await source.markCameraExplained();
    expect(await DeviceAvoPhotoSource().cameraExplained(), isTrue);
  });
}
