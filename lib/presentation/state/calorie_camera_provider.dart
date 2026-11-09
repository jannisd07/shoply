import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';

// The device camera for S4 and S6 (`kalorien.md`): native screens behind
// [CalorieCamera], a fake in tests.

// ── Camera ──────────────────────────────────────────────────────────────

/// What the photo (S4) and barcode (S6) screens need from the device. The
/// native screens cannot run in tests; a fake stands in.
abstract class CalorieCamera {
  /// The VisionKit barcode scanner exists (iOS 16+, A12 or newer).
  Future<bool> scannerSupported();

  /// A back camera exists.
  Future<bool> cameraAvailable();
  Future<CameraPermission> permission();

  /// Shows the system camera question (only after the app's own alert).
  Future<bool> requestAccess();
  Future<BarcodeScanResult> scan(BarcodeScannerLabels labels);
  Future<MealPhotoResult> takePhoto(MealCameraLabels labels);
  Future<MealPhotoResult> pickPhoto();
}

class NativeCalorieCamera implements CalorieCamera {
  NativeCalorieCamera({BarcodeScannerChannel? scanner, MealCameraChannel? camera})
      : _scanner = scanner ?? BarcodeScannerChannel.instance,
        _camera = camera ?? MealCameraChannel.instance;

  final BarcodeScannerChannel _scanner;
  final MealCameraChannel _camera;

  @override
  Future<bool> scannerSupported() => _scanner.isSupported();
  @override
  Future<bool> cameraAvailable() => _camera.isAvailable();
  @override
  Future<CameraPermission> permission() => _scanner.cameraPermission();
  @override
  Future<bool> requestAccess() => _scanner.requestCameraAccess();
  @override
  Future<BarcodeScanResult> scan(BarcodeScannerLabels labels) => _scanner.scan(labels: labels);
  @override
  Future<MealPhotoResult> takePhoto(MealCameraLabels labels) => _camera.takePhoto(labels: labels);
  @override
  Future<MealPhotoResult> pickPhoto() => _camera.pickPhoto();
}

final calorieCameraProvider = Provider<CalorieCamera>((ref) => NativeCalorieCamera());

/// The camera reads barcodes here (S3 "Kamera öffnen"); false on iOS 15,
/// devices before A12 and other platforms.
final calorieScannerSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(calorieCameraProvider).scannerSupported(),
);
