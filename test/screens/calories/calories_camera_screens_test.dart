// S4 "Foto aufnehmen" and S6 "Barcode-Kamera" of
// docs/redesign/b-screens/kalorien.md. The cameras are native (shoply/camera,
// shoply/scanner); a fake camera stands in. Checked here: the camera
// question first, refusals, no scanner, lookups after a scan, and that the
// next screen replaces the camera page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/presentation/screens/calories/calories_amount_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_estimate_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_manual_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_photo_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_scan_screen.dart';

import 'calorie_fakes.dart';

const _code = '4056489123453';

Future<GoRouter> _open(WidgetTester tester, String location, List<dynamic> overrides) async {
  final router = await pumpCaloriesFlow(tester, overrides: overrides.cast());
  router.push(location);
  await settleFrames(tester);
  return router;
}

void main() {
  group('S6 Barcode', () {
    testWidgets('no scanner: straight to the number field; a known number replaces the page with S7', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(supported: false);
      await _open(tester, '/calories/scan?meal=lunch', env.overrides(
        camera: camera,
        offProducts: {_code: offProduct(_code, 'Skyr Natur', brand: 'Milbona')},
      ));

      expect(find.text('This iPhone can\'t read barcodes with the camera. Enter the number instead.'), findsOneWidget);
      expect(camera.scans, 0);
      await tester.enterText(find.byKey(const ValueKey('cal-barcode-field')), _code);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleFrames(tester);
      expect(find.byType(CaloriesAmountScreen), findsOneWidget);
      expect(find.byType(CaloriesScanScreen), findsNothing);

      // Back from S7 does not land in an empty camera.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settleFrames(tester);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('never asked: "Camera for barcodes" first; "Not now" leaves without asking the system', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(permissionValue: CameraPermission.notDetermined);
      await _open(tester, '/calories/scan', env.overrides(camera: camera));

      expect(find.text('Camera for barcodes'), findsOneWidget);
      expect(find.text('The camera only reads the barcode. No images are saved.'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await settleFrames(tester);
      expect(camera.requests, 0);
      expect(camera.scans, 0);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('"Continue" asks the system, then scans; a hit opens S7 in place of the camera', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(
        permissionValue: CameraPermission.notDetermined,
        scanResult: const BarcodeScanResult(BarcodeScanStatus.scanned, code: _code, symbology: 'ean13'),
      );
      await _open(tester, '/calories/scan', env.overrides(
        camera: camera,
        offProducts: {_code: offProduct(_code, 'Skyr Natur')},
      ));

      await tester.tap(find.text('Continue'));
      await settleFrames(tester);
      expect(camera.requests, 1);
      expect(camera.scans, 1);
      expect(find.byType(CaloriesAmountScreen), findsOneWidget);
      expect(find.byType(CaloriesScanScreen), findsNothing);
    });

    testWidgets('camera refused: the status line and the number field', (tester) async {
      final env = await CalorieTestEnv.create();
      await _open(tester, '/calories/scan', env.overrides(
        camera: FakeCalorieCamera(permissionValue: CameraPermission.denied),
      ));

      expect(find.text('Camera access is off. Allow in Settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-barcode-field')), findsOneWidget);
      expect(find.text('Scan again'), findsNothing);
    });

    testWidgets('an unknown code: "Enter manually" with the barcode, or scan again', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(
        scanResult: const BarcodeScanResult(BarcodeScanStatus.scanned, code: '4000000000099'),
      );
      await _open(tester, '/calories/scan?meal=dinner', env.overrides(camera: camera));

      expect(find.text('Nothing is known about this barcode.'), findsOneWidget);
      expect(find.text('4 000000 000099'), findsOneWidget);
      await tester.tap(find.text('Scan again'));
      await settleFrames(tester);
      expect(camera.scans, 2);

      await tester.tap(find.text('Enter manually'));
      await settleFrames(tester);
      final manual = tester.widget<CaloriesManualScreen>(find.byType(CaloriesManualScreen));
      expect(manual.barcode, '4000000000099');
      expect(find.byType(CaloriesScanScreen), findsNothing);
    });

    testWidgets('offline and not on this device: says only scanned products are known', (tester) async {
      final env = await CalorieTestEnv.create();
      await _open(tester, '/calories/scan', env.overrides(
        offline: true,
        camera: FakeCalorieCamera(scanResult: const BarcodeScanResult(BarcodeScanStatus.scanned, code: _code)),
      ));

      expect(find.text('You\'re offline. Only products you\'ve scanned before are recognised.'), findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);
    });

    testWidgets('Open Food Facts fails: retry', (tester) async {
      final env = await CalorieTestEnv.create();
      await _open(tester, '/calories/scan', env.overrides(
        offBarcodeError: kOffFailed,
        camera: FakeCalorieCamera(scanResult: const BarcodeScanResult(BarcodeScanStatus.scanned, code: _code)),
      ));

      expect(find.text('Online search didn\'t work.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('closed in the camera: back where it came from; "Nummer eingeben": the field', (tester) async {
      final env = await CalorieTestEnv.create();
      await _open(tester, '/calories/scan', env.overrides(camera: FakeCalorieCamera()));
      expect(find.text('Start'), findsOneWidget);

      final env2 = await CalorieTestEnv.create();
      await _open(tester, '/calories/scan', env2.overrides(
        camera: FakeCalorieCamera(scanResult: const BarcodeScanResult(BarcodeScanStatus.manualEntry)),
      ));
      expect(find.byKey(const ValueKey('cal-barcode-field')), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
    });
  });

  group('S4 Photo', () {
    testWidgets('allowed: the camera opens; the photo replaces the page with S5', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(photoResult: MealPhotoResult(MealPhotoStatus.captured, bytes: kJpeg));
      await _open(tester, '/calories/add/photo?meal=lunch', env.overrides(camera: camera));

      expect(camera.photos, 1);
      expect(find.byType(CaloriesEstimateScreen), findsOneWidget);
      expect(find.byType(CaloriesPhotoScreen), findsNothing);
      expect(find.text('Estimating…'), findsOneWidget);
    });

    testWidgets('never asked: "Camera for meal photos" first; "Not now" goes back', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(permissionValue: CameraPermission.notDetermined);
      await _open(tester, '/calories/add/photo', env.overrides(camera: camera));

      expect(find.text('Camera for meal photos'), findsOneWidget);
      expect(find.text('The photo is only used for the estimate and stored privately.'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await settleFrames(tester);
      expect(camera.photos, 0);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('camera refused: the status line and "Choose from Photos" into S5', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera(
        permissionValue: CameraPermission.denied,
        pickResult: MealPhotoResult(MealPhotoStatus.picked, bytes: kJpeg),
      );
      await _open(tester, '/calories/add/photo', env.overrides(camera: camera));

      expect(find.text('Camera access is off. Allow in Settings'), findsOneWidget);
      await tester.tap(find.text('Choose from Photos'));
      await settleFrames(tester);
      expect(camera.picks, 1);
      expect(find.byType(CaloriesEstimateScreen), findsOneWidget);
    });

    testWidgets('closed in the camera: back', (tester) async {
      final env = await CalorieTestEnv.create();
      await _open(tester, '/calories/add/photo', env.overrides(camera: FakeCalorieCamera()));
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('S5 without a photo (deep link) goes to the camera', (tester) async {
      final env = await CalorieTestEnv.create();
      final camera = FakeCalorieCamera();
      await _open(tester, '/calories/add/estimate?meal=lunch', env.overrides(camera: camera));
      expect(camera.photos, 1);
    });
  });
}
