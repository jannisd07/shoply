import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';

/// Shortest and longest display name (Konzept 18 §4.3).
const int kNameMinLength = 2;
const int kNameMaxLength = 40;

/// Side of the stored profile photo (Konzept 18 §4.3: 512 px).
const int kProfilePhotoSide = 512;

/// JPEG quality of the stored photo.
const int _kPhotoQuality = 85;

/// Whether [raw] is a valid display name once trimmed (2 to 40 characters).
bool isValidDisplayName(String raw) {
  final length = raw.trim().characters.length;
  return length >= kNameMinLength && length <= kNameMaxLength;
}

/// Where a new profile photo comes from.
enum PhotoSource { library, camera }

/// A picked photo, already square and at most [kProfilePhotoSide] px.
@immutable
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.path});

  final Uint8List bytes;

  /// A file with [bytes], for the upload.
  final String path;
}

/// The camera permission before "Foto aufnehmen" (Konzept 18 §10.3).
enum CameraAccess { notAsked, granted, denied }

/// Opens the system photo picker (no permission needed) or the camera.
/// Null when the person cancelled. Throws a `PlatformException` with code
/// `camera_access_denied` when the camera is not allowed. Overridden in
/// tests.
final photoPickerProvider =
    Provider<Future<PickedPhoto?> Function(PhotoSource source)>(
      (ref) => pickSquareProfilePhoto,
    );

/// The camera permission state. Overridden in tests.
final cameraAccessProvider = Provider<Future<CameraAccess> Function()>(
  (ref) => () async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) return CameraAccess.granted;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return CameraAccess.denied;
      }
    } catch (e) {
      debugPrint('[ACCOUNT] camera status unknown: ${e.runtimeType}');
    }
    return CameraAccess.notAsked;
  },
);

/// Opens the iOS settings of the app ("In Einstellungen erlauben").
final openAppSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('[ACCOUNT] settings not opened: ${e.runtimeType}');
    }
  },
);

/// Picks a photo and crops it to a centred square of 512 px (the system
/// picker has no square crop; Konzept 18 §4.3 deviation in the A8 report).
Future<PickedPhoto?> pickSquareProfilePhoto(PhotoSource source) async {
  final file = await ImagePicker().pickImage(
    source: source == PhotoSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 2048,
    maxHeight: 2048,
  );
  if (file == null) return null;
  final raw = await file.readAsBytes();
  final square = await compute(squareProfileJpeg, raw);
  final path =
      '${Directory.systemTemp.path}/avo_profile_'
      '${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(path).writeAsBytes(square, flush: true);
  return PickedPhoto(bytes: square, path: path);
}

/// Decodes [raw], applies the EXIF orientation and returns a centred square
/// JPEG of [kProfilePhotoSide] px. Runs in an isolate.
Uint8List squareProfileJpeg(Uint8List raw) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } catch (_) {
    // Some decoders throw on garbage instead of returning null.
    decoded = null;
  }
  if (decoded == null) throw const FormatException('Not an image');
  final square = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: kProfilePhotoSide,
    interpolation: img.Interpolation.average,
    antialias: true,
  );
  return Uint8List.fromList(img.encodeJpg(square, quality: _kPhotoQuality));
}

/// What Profil bearbeiten changed in this session, kept while the person
/// moves around (an upload or a pending removal goes on after leaving).
@immutable
class ProfileEditState {
  const ProfileEditState({
    this.savedName,
    this.nameWaiting = false,
    this.localPhoto,
    this.localPhotoPath,
    this.uploading = false,
    this.uploadFailed = false,
    this.removed = false,
    this.removeFailed = false,
    this.cameraDenied = false,
  });

  /// The name taken over in this session; shown until the profile has it.
  final String? savedName;

  /// [savedName] is kept on the device and not on the server yet.
  final bool nameWaiting;

  /// The new photo, shown at once (Konzept 18 §4.3).
  final Uint8List? localPhoto;
  final String? localPhotoPath;

  /// The upload of [localPhoto] runs or waits for a connection.
  final bool uploading;
  final bool uploadFailed;

  /// The photo was removed (initials show); within the undo window the file
  /// is still stored.
  final bool removed;
  final bool removeFailed;

  /// "Foto aufnehmen" found the camera switched off.
  final bool cameraDenied;

  ProfileEditState copyWith({
    String? savedName,
    bool? nameWaiting,
    Uint8List? localPhoto,
    String? localPhotoPath,
    bool clearLocalPhoto = false,
    bool? uploading,
    bool? uploadFailed,
    bool? removed,
    bool? removeFailed,
    bool? cameraDenied,
  }) => ProfileEditState(
    savedName: savedName ?? this.savedName,
    nameWaiting: nameWaiting ?? this.nameWaiting,
    localPhoto: clearLocalPhoto ? null : localPhoto ?? this.localPhoto,
    localPhotoPath: clearLocalPhoto
        ? null
        : localPhotoPath ?? this.localPhotoPath,
    uploading: uploading ?? this.uploading,
    uploadFailed: uploadFailed ?? this.uploadFailed,
    removed: removed ?? this.removed,
    removeFailed: removeFailed ?? this.removeFailed,
    cameraDenied: cameraDenied ?? this.cameraDenied,
  );
}

/// Name and photo changes of Profil bearbeiten (Konzept 18 §4.3): local
/// first, the server in the background, retried when the connection is
/// back. Reset per account.
class ProfileEditController extends Notifier<ProfileEditState> {
  Timer? _removal;
  bool _uploadWaitsForNetwork = false;

  @override
  ProfileEditState build() {
    ref.watch(accountIdentityProvider.select((i) => i?.userId));
    ref.listen<bool>(isOfflineProvider, (wasOffline, offline) {
      if (offline) return;
      final name = state.savedName;
      if (state.nameWaiting && name != null) unawaited(_sendName(name));
      final path = state.localPhotoPath;
      if (_uploadWaitsForNetwork && path != null) unawaited(_upload(path));
    });
    ref.onDispose(() => _removal?.cancel());
    return const ProfileEditState();
  }

  /// The name to show: the one taken over here, else the profile's.
  String? displayName(AccountProfile profile) =>
      state.savedName ?? profile.displayName;

  /// Takes over [raw] when it is valid and differs from the current name.
  /// Returns false for an invalid name (nothing changes then).
  bool commitName(String raw) {
    if (!isValidDisplayName(raw)) return false;
    final name = raw.trim();
    final current = displayName(ref.read(accountProfileProvider))?.trim();
    if (name == current) return true;
    state = state.copyWith(savedName: name, nameWaiting: false);
    unawaited(_sendName(name));
    return true;
  }

  Future<void> _sendName(String name) async {
    try {
      await ref.read(profileEditorProvider).saveName(name);
      if (state.savedName == name) state = state.copyWith(nameWaiting: false);
    } catch (e) {
      debugPrint('[ACCOUNT] name not saved yet: ${e.runtimeType}');
      if (state.savedName == name) state = state.copyWith(nameWaiting: true);
    }
  }

  /// Shows [photo] at once and uploads it in the background.
  Future<void> setPhoto(PickedPhoto photo) {
    _removal?.cancel();
    _removal = null;
    state = state.copyWith(
      localPhoto: photo.bytes,
      localPhotoPath: photo.path,
      removed: false,
      removeFailed: false,
      cameraDenied: false,
    );
    return _upload(photo.path);
  }

  /// "Erneut versuchen" after a failed upload.
  Future<void> retryUpload() async {
    final path = state.localPhotoPath;
    if (path != null) await _upload(path);
  }

  Future<void> _upload(String path) async {
    state = state.copyWith(uploading: true, uploadFailed: false);
    if (ref.read(isOfflineProvider)) {
      // Waits in the queue until the connection is back (§4.4).
      _uploadWaitsForNetwork = true;
      return;
    }
    _uploadWaitsForNetwork = false;
    try {
      await ref.read(profileEditorProvider).uploadPhoto(path);
      if (state.localPhotoPath == path) {
        state = state.copyWith(uploading: false);
      }
    } catch (e) {
      debugPrint('[ACCOUNT] photo upload failed: ${e.runtimeType}');
      if (state.localPhotoPath == path) {
        state = state.copyWith(uploading: false, uploadFailed: true);
      }
    }
  }

  /// Shows the initials at once; the stored file is deleted only when
  /// [undoWindow] passes without [undoRemove] (Konzept 18 §4.3, §11.5).
  void removePhoto(Duration undoWindow) {
    _removal?.cancel();
    state = state.copyWith(
      removed: true,
      removeFailed: false,
      uploadFailed: false,
    );
    _removal = Timer(undoWindow, () => unawaited(_commitRemoval()));
  }

  /// "Widerrufen": the photo is back, without a new upload.
  void undoRemove() {
    _removal?.cancel();
    _removal = null;
    state = state.copyWith(removed: false);
  }

  Future<void> _commitRemoval() async {
    _removal = null;
    try {
      await ref.read(profileEditorProvider).removePhoto();
      state = state.copyWith(clearLocalPhoto: true, uploading: false);
      _uploadWaitsForNetwork = false;
    } catch (e) {
      debugPrint('[ACCOUNT] photo not removed: ${e.runtimeType}');
      state = state.copyWith(removed: false, removeFailed: true);
    }
  }

  /// "Foto aufnehmen" found the camera off, or the person allowed it.
  void setCameraDenied(bool denied) {
    if (state.cameraDenied != denied) {
      state = state.copyWith(cameraDenied: denied);
    }
  }

  /// Hides the line of a failed removal.
  void dismissRemoveFailure() {
    if (state.removeFailed) state = state.copyWith(removeFailed: false);
  }

  /// Changes that are not on the server yet (counted by Abmelden).
  int get unsentChanges =>
      (state.nameWaiting ? 1 : 0) + (_uploadWaitsForNetwork ? 1 : 0);
}

final profileEditControllerProvider =
    NotifierProvider<ProfileEditController, ProfileEditState>(
      ProfileEditController.new,
    );

/// The display name to show everywhere (the profile root too): a name taken
/// over in Profil bearbeiten counts at once, also while it waits offline.
final accountDisplayNameProvider = Provider<String?>((ref) {
  final saved = ref.watch(
    profileEditControllerProvider.select((s) => s.savedName),
  );
  return saved ?? ref.watch(accountProfileProvider).displayName;
});
