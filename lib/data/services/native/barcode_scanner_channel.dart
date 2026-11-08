import 'package:flutter/services.dart';

import 'package:shoply/data/services/native/native_channel_errors.dart';

/// Camera permission as `AVCaptureDevice.authorizationStatus` reports it.
enum CameraPermission { notDetermined, authorized, denied, restricted }

enum BarcodeScanStatus {
  /// [BarcodeScanResult.code] holds a checked EAN-13 / EAN-8 code.
  scanned,

  /// The person tapped "Nummer eingeben": show the digit field.
  manualEntry,

  /// Closed without a code.
  cancelled,

  /// No camera scanner here (iOS 15, older devices, other platforms): show
  /// the digit field right away.
  unavailable,
}

class BarcodeScanResult {
  const BarcodeScanResult(this.status, {this.code, this.symbology});

  final BarcodeScanStatus status;

  /// Digits only: EAN-13 (UPC-A and UPC-E are expanded to 13 digits) or EAN-8.
  final String? code;

  /// `ean13`, `ean8` or `upce` as the camera saw it.
  final String? symbology;
}

/// Texts of the native scanner screen, in the app language.
class BarcodeScannerLabels {
  const BarcodeScannerLabels({
    required this.hint,
    required this.manualEntry,
    required this.close,
    required this.torch,
    required this.torchOn,
    required this.torchOff,
  });

  /// "Strichcode in den Rahmen halten"
  final String hint;

  /// "Nummer eingeben"
  final String manualEntry;

  /// VoiceOver label of the back button.
  final String close;

  /// VoiceOver label of the flashlight button, with [torchOn] / [torchOff]
  /// as its value.
  final String torch;
  final String torchOn;
  final String torchOff;

  Map<String, Object?> toArgs() => {
    'hint': hint,
    'manualEntry': manualEntry,
    'close': close,
    'torch': torch,
    'torchOn': torchOn,
    'torchOff': torchOff,
  };
}

/// Barcode camera over `shoply/scanner` (`BarcodeScannerChannel.swift`,
/// VisionKit `DataScannerViewController`, iOS 16+). The native screen opens
/// full screen; it never asks for the camera itself: call
/// [requestCameraAccess] after the "Kamera für Strichcodes" alert.
class BarcodeScannerChannel {
  BarcodeScannerChannel({
    MethodChannel channel = const MethodChannel('shoply/scanner'),
    bool Function()? isSupported,
  }) : _channel = channel,
       _isSupported = isSupported ?? isIOSPlatform;

  static final BarcodeScannerChannel instance = BarcodeScannerChannel();

  static const _tag = 'SCANNER';

  final MethodChannel _channel;
  final bool Function() _isSupported;

  Future<T> _guard<T>(T fallback, Future<T> Function() call) =>
      guardNativeCall(
        supported: _isSupported(),
        fallback: fallback,
        tag: _tag,
        call: call,
      );

  /// False on iOS 15 and on devices without the scanner (before A12).
  Future<bool> isSupported() => _guard(
    false,
    () async => await _channel.invokeMethod<bool>('isSupported') ?? false,
  );

  Future<CameraPermission> cameraPermission() async {
    final raw = await _guard<String?>(
      'denied',
      () => _channel.invokeMethod<String>('cameraPermission'),
    );
    return CameraPermission.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => CameraPermission.denied,
    );
  }

  /// Shows the system camera dialog if it was never shown; otherwise answers
  /// the stored decision.
  Future<bool> requestCameraAccess() => _guard(
    false,
    () async =>
        await _channel.invokeMethod<bool>('requestCameraAccess') ?? false,
  );

  /// Opens the scanner. Throws [NativeChannelException] with
  /// `permissionDenied` when the camera is not allowed and `busy` when a
  /// scanner is already open.
  Future<BarcodeScanResult> scan({required BarcodeScannerLabels labels}) async {
    const unavailable = BarcodeScanResult(BarcodeScanStatus.unavailable);
    final map = nativeMap(
      await _guard<Object?>(
        unavailable,
        () => _channel.invokeMethod<Object?>('scan', labels.toArgs()),
      ),
    );
    if (map == null) return unavailable;
    switch (map['status']) {
      case 'scanned':
        final raw = map['code'];
        final code = raw is String ? normalizeGtin(raw) : null;
        if (code == null) {
          return const BarcodeScanResult(BarcodeScanStatus.cancelled);
        }
        return BarcodeScanResult(
          BarcodeScanStatus.scanned,
          code: code,
          symbology: map['symbology'] as String?,
        );
      case 'manual':
        return const BarcodeScanResult(BarcodeScanStatus.manualEntry);
      default:
        return const BarcodeScanResult(BarcodeScanStatus.cancelled);
    }
  }

  /// Checks a typed or scanned number: spaces and dashes are ignored,
  /// EAN-13, EAN-8 and UPC-A (padded to 13 digits) with a correct check
  /// digit pass. Returns the digits or null.
  static String? normalizeGtin(String input) {
    final digits = input.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
    final code = switch (digits.length) {
      8 || 13 => digits,
      12 => '0$digits',
      _ => null,
    };
    if (code == null || !_hasValidCheckDigit(code)) return null;
    return code;
  }

  static bool _hasValidCheckDigit(String code) {
    var sum = 0;
    for (var i = 0; i < code.length - 1; i++) {
      final digit = code.codeUnitAt(code.length - 2 - i) - 48;
      sum += i.isEven ? digit * 3 : digit;
    }
    return (10 - sum % 10) % 10 == code.codeUnitAt(code.length - 1) - 48;
  }
}
