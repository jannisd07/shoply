import 'package:flutter/services.dart';

import 'package:shoply/data/services/native/native_channel_errors.dart';

enum MealPhotoStatus {
  /// Taken with the camera; [MealPhotoResult.bytes] holds the JPEG.
  captured,

  /// Chosen in the photo picker; [MealPhotoResult.bytes] holds the JPEG.
  picked,

  /// Closed without a photo.
  cancelled,

  /// No camera here (other platforms, a device without a back camera).
  unavailable,
}

class MealPhotoResult {
  const MealPhotoResult(this.status, {this.bytes});

  final MealPhotoStatus status;

  /// JPEG, long edge at most 1024 px, 80 % quality. Only in memory.
  final Uint8List? bytes;

  bool get hasPhoto => bytes != null && bytes!.isNotEmpty;
}

/// Texts of the native camera screen, in the app language.
class MealCameraLabels {
  const MealCameraLabels({
    required this.hint,
    required this.hintShort,
    required this.back,
    required this.flash,
    required this.flashOn,
    required this.flashOff,
    required this.shutter,
    required this.library,
  });

  /// "Den Teller von oben und ganz ins Bild nehmen. …"
  final String hint;

  /// From AX3 on: "Teller von oben fotografieren."
  final String hintShort;
  final String back;

  /// VoiceOver label of the flash button with [flashOn] / [flashOff] as
  /// its value.
  final String flash;
  final String flashOn;
  final String flashOff;

  /// "Foto aufnehmen"
  final String shutter;

  /// "Aus Fotos"
  final String library;

  Map<String, Object?> toArgs() => {
    'hint': hint,
    'hintShort': hintShort,
    'back': back,
    'flash': flash,
    'flashOn': flashOn,
    'flashOff': flashOff,
    'shutter': shutter,
    'library': library,
  };
}

/// The meal photo camera and the system photo picker over `shoply/camera`
/// (`MealCameraChannel.swift`). Both open full screen with a cross-fade.
/// The camera permission is asked through `BarcodeScannerChannel`
/// (`requestCameraAccess`) after the "Kamera für Essensfotos" alert.
class MealCameraChannel {
  MealCameraChannel({
    MethodChannel channel = const MethodChannel('shoply/camera'),
    bool Function()? isSupported,
  }) : _channel = channel,
       _isSupported = isSupported ?? isIOSPlatform;

  static final MealCameraChannel instance = MealCameraChannel();

  static const _tag = 'CAMERA';

  final MethodChannel _channel;
  final bool Function() _isSupported;

  /// False without a back camera and on other platforms.
  Future<bool> isAvailable() => guardNativeCall(
    supported: _isSupported(),
    fallback: false,
    tag: _tag,
    call: () async => await _channel.invokeMethod<bool>('isAvailable') ?? false,
  );

  /// Opens the camera. Throws [NativeChannelException] with
  /// `permissionDenied` when the camera is not allowed and `busy` when a
  /// camera is already open.
  Future<MealPhotoResult> takePhoto({required MealCameraLabels labels}) =>
      _photo('takePhoto', labels.toArgs());

  /// Opens the system photo picker (no permission needed).
  Future<MealPhotoResult> pickPhoto() => _photo('pickPhoto', null);

  Future<MealPhotoResult> _photo(String method, Object? args) async {
    const unavailable = MealPhotoResult(MealPhotoStatus.unavailable);
    final map = nativeMap(
      await guardNativeCall<Object?>(
        supported: _isSupported(),
        fallback: unavailable,
        tag: _tag,
        call: () => _channel.invokeMethod<Object?>(method, args),
      ),
    );
    if (map == null) return unavailable;
    final bytes = map['bytes'];
    final data = bytes is Uint8List && bytes.isNotEmpty ? bytes : null;
    return switch (map['status']) {
      'captured' when data != null => MealPhotoResult(MealPhotoStatus.captured, bytes: data),
      'picked' when data != null => MealPhotoResult(MealPhotoStatus.picked, bytes: data),
      _ => const MealPhotoResult(MealPhotoStatus.cancelled),
    };
  }
}
