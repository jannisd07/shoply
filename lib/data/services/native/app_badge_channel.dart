import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:shoply/data/services/native/native_channel_errors.dart';

/// The app icon badge, through `AppBadgeChannel.swift`.
///
/// Never asks for the notification permission: without it there is no badge
/// to clear. Asking is `NotificationPermissionService`'s job alone.
class AppBadge {
  AppBadge({
    MethodChannel channel = const MethodChannel('shoply/app'),
    bool Function()? isSupported,
  }) : _channel = channel,
       _isSupported = isSupported ?? isIOSPlatform;

  static final AppBadge instance = AppBadge();

  static const _tag = 'BADGE';

  final MethodChannel _channel;
  final bool Function() _isSupported;

  /// Sets the badge to 0. Never throws; does nothing off iOS.
  static Future<void> clear() => instance.clearBadge();

  Future<void> clearBadge() async {
    try {
      await guardNativeCall<void>(
        supported: _isSupported(),
        fallback: null,
        tag: _tag,
        call: () => _channel.invokeMethod<void>('clearBadge'),
      );
    } on NativeChannelException catch (e) {
      debugPrint('⚠️ [$_tag] Clearing the badge failed: ${e.code.name}');
    }
  }
}
