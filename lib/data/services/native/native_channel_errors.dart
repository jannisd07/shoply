import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Error codes shared by the Swift channels in `ios/Runner/NativeChannels/`
/// (`NativeErrorCode` in `NativeChannelSupport.swift`).
enum NativeErrorCode {
  /// Not on this device or OS (iOS 15 scanner, iPad without Health, no
  /// speech model). Wrappers turn this into false / null / an empty list.
  unavailable,

  /// The person refused or never granted the permission.
  permissionDenied,

  /// The native side rejected the arguments.
  invalidArguments,

  /// Another call of the same kind is still running (e.g. a second scan).
  busy,

  /// The person or the system ended the operation.
  cancelled,

  /// Anything else; [NativeChannelException.message] has the details.
  failed,
}

/// Maps the string code a Swift channel sends to [NativeErrorCode].
NativeErrorCode nativeErrorCodeFrom(String code) => switch (code) {
  'unavailable' => NativeErrorCode.unavailable,
  'permission_denied' => NativeErrorCode.permissionDenied,
  'invalid_args' => NativeErrorCode.invalidArguments,
  'busy' => NativeErrorCode.busy,
  'cancelled' => NativeErrorCode.cancelled,
  _ => NativeErrorCode.failed,
};

/// A native channel call that failed for a reason the caller should handle.
class NativeChannelException implements Exception {
  const NativeChannelException(this.code, [this.message]);

  factory NativeChannelException.fromPlatform(PlatformException error) =>
      NativeChannelException(nativeErrorCodeFrom(error.code), error.message);

  final NativeErrorCode code;
  final String? message;

  @override
  String toString() => 'NativeChannelException(${code.name}, $message)';
}

/// True on iOS, where the Swift channels exist. Web and other platforms
/// never call them.
bool isIOSPlatform() => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Runs [call] against a native channel.
///
/// Returns [fallback] on other platforms, when the plugin is missing (tests,
/// simulators without the registration) and when the native side answers
/// `unavailable`. Every other [PlatformException] is rethrown as
/// [NativeChannelException].
Future<T> guardNativeCall<T>({
  required bool supported,
  required T fallback,
  required String tag,
  required Future<T> Function() call,
}) async {
  if (!supported) return fallback;
  try {
    return await call();
  } on MissingPluginException {
    debugPrint('⚠️ [$tag] native channel missing');
    return fallback;
  } on PlatformException catch (error) {
    final exception = NativeChannelException.fromPlatform(error);
    if (exception.code == NativeErrorCode.unavailable) return fallback;
    debugPrint('❌ [$tag] ${exception.code.name}');
    throw exception;
  }
}

/// Reads a string-keyed map from a channel answer; anything else is null.
Map<String, Object?>? nativeMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

/// Milliseconds since epoch from a channel answer as a local [DateTime].
DateTime? nativeDate(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;
