import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Whether the camera may be used for a photo to Avo (Kap. 7.4).
enum AvoCameraAccess {
  /// Allowed.
  granted,

  /// Not asked yet: the app explains first (dialog 11.3), then the system
  /// asks.
  notAsked,

  /// Turned off in Settings: "Kamera ist aus. In Einstellungen erlauben".
  denied,
}

/// Where photos to Avo come from: the system camera and the system photo
/// picker (one photo, no access to the whole library). Tests put a fake in
/// [avoPhotoSourceProvider].
abstract interface class AvoPhotoSource {
  Future<AvoCameraAccess> cameraAccess();

  /// Opens the app's page in the iOS Settings.
  Future<void> openSettings();

  /// A photo from the camera; null when the person cancelled.
  Future<Uint8List?> take();

  /// A photo from the photo picker; null when the person cancelled.
  Future<Uint8List?> choose();
}

final avoPhotoSourceProvider = Provider<AvoPhotoSource>(
  (ref) => const DeviceAvoPhotoSource(),
);

/// Long edge of a photo for Avo; the services scale it again for Claude.
const double _maxEdge = 2000;
const int _quality = 85;

/// [AvoPhotoSource] on `image_picker` and `permission_handler`.
class DeviceAvoPhotoSource implements AvoPhotoSource {
  const DeviceAvoPhotoSource();

  @override
  Future<AvoCameraAccess> cameraAccess() async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) return AvoCameraAccess.granted;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return AvoCameraAccess.denied;
      }
      return AvoCameraAccess.notAsked;
    } catch (e) {
      debugPrint('⚠️ [AVO_PHOTO] Camera state not read: $e');
      return AvoCameraAccess.notAsked;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('⚠️ [AVO_PHOTO] Settings not opened: $e');
    }
  }

  @override
  Future<Uint8List?> take() => _pick(ImageSource.camera);

  @override
  Future<Uint8List?> choose() => _pick(ImageSource.gallery);

  Future<Uint8List?> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _quality,
      );
      return file == null ? null : await file.readAsBytes();
    } catch (e) {
      debugPrint('❌ [AVO_PHOTO] No photo: $e');
      return null;
    }
  }
}
