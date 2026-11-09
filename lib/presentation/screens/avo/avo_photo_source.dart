import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a camera or photo picker call brought back.
enum AvoPickOutcome {
  /// A photo ([AvoPick.photo]).
  photo,

  /// The person closed the camera or the picker.
  cancelled,

  /// The camera is not allowed (`camera_access_denied` or
  /// `camera_access_restricted` from image_picker): "Kamera ist aus".
  denied,
}

/// One pick: the outcome and, for [AvoPickOutcome.photo], the bytes.
typedef AvoPick = ({AvoPickOutcome outcome, Uint8List? photo});

/// Where photos to Avo come from: the system camera and the system photo
/// picker (one photo, no access to the whole library). Tests put a fake in
/// [avoPhotoSourceProvider].
///
/// Denial comes from image_picker itself (its `camera_access_denied`
/// error), not from permission_handler: the Podfile does not compile in
/// permission_handler's camera check (no `PERMISSION_CAMERA=1`), so its
/// camera status is meaningless on iOS.
abstract interface class AvoPhotoSource {
  /// Whether Avo explained the camera once already (dialog 11.3, shown only
  /// before the first system prompt; remembered per install).
  Future<bool> cameraExplained();
  Future<void> markCameraExplained();

  /// Opens the app's page in the iOS Settings.
  Future<void> openSettings();

  /// A photo from the camera (the system asks for access the first time).
  Future<AvoPick> take();

  /// A photo from the photo picker.
  Future<AvoPick> choose();
}

final avoPhotoSourceProvider = Provider<AvoPhotoSource>(
  (ref) => DeviceAvoPhotoSource(),
);

/// Long edge of a photo for Avo; the services scale it again for Claude.
const double _maxEdge = 2000;
const int _quality = 85;
const String _explainedKey = 'avo_camera_explained_v1';

/// The image_picker error codes that mean the camera is not allowed.
const Set<String> avoCameraDeniedCodes = {
  'camera_access_denied',
  'camera_access_restricted',
};

/// The image picker call; tests pass one that throws the real
/// [PlatformException] codes.
typedef AvoImagePick = Future<XFile?> Function(ImageSource source);

Future<XFile?> _systemPick(ImageSource source) => ImagePicker().pickImage(
  source: source,
  maxWidth: _maxEdge,
  maxHeight: _maxEdge,
  imageQuality: _quality,
);

/// [AvoPhotoSource] on `image_picker`.
class DeviceAvoPhotoSource implements AvoPhotoSource {
  DeviceAvoPhotoSource({AvoImagePick? pick}) : _pick = pick ?? _systemPick;

  final AvoImagePick _pick;

  @override
  Future<bool> cameraExplained() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_explainedKey) ?? false;
    } catch (e) {
      debugPrint('⚠️ [AVO_PHOTO] Camera note not read: $e');
      return false;
    }
  }

  @override
  Future<void> markCameraExplained() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_explainedKey, true);
    } catch (e) {
      debugPrint('⚠️ [AVO_PHOTO] Camera note not saved: $e');
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      // Only opens the Settings page; needs no permission macro.
      await openAppSettings();
    } catch (e) {
      debugPrint('⚠️ [AVO_PHOTO] Settings not opened: $e');
    }
  }

  @override
  Future<AvoPick> take() => _read(ImageSource.camera);

  @override
  Future<AvoPick> choose() => _read(ImageSource.gallery);

  Future<AvoPick> _read(ImageSource source) async {
    try {
      final file = await _pick(source);
      if (file == null) return (outcome: AvoPickOutcome.cancelled, photo: null);
      return (outcome: AvoPickOutcome.photo, photo: await file.readAsBytes());
    } on PlatformException catch (e) {
      if (avoCameraDeniedCodes.contains(e.code)) {
        return (outcome: AvoPickOutcome.denied, photo: null);
      }
      debugPrint('❌ [AVO_PHOTO] No photo: ${e.code}');
      return (outcome: AvoPickOutcome.cancelled, photo: null);
    } catch (e) {
      debugPrint('❌ [AVO_PHOTO] No photo: $e');
      return (outcome: AvoPickOutcome.cancelled, photo: null);
    }
  }
}
