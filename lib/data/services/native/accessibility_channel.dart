import 'package:flutter/services.dart';

import 'package:shoply/data/services/native/native_channel_errors.dart';

/// System accessibility settings Flutter does not expose, read from
/// `AccessibilityChannel.swift`.
///
/// Today: "Reduce Transparency" (Settings > Accessibility > Display & Text
/// Size). Glass fallbacks drawn in Flutter use it to switch to opaque
/// surfaces; native `UIGlassEffect` views react on their own.
class AccessibilityChannel {
  AccessibilityChannel({
    MethodChannel channel = const MethodChannel('shoply/accessibility'),
    EventChannel events = const EventChannel('shoply/accessibility/events'),
    bool Function()? isSupported,
  }) : _channel = channel,
       _events = events,
       _isSupported = isSupported ?? isIOSPlatform;

  static final AccessibilityChannel instance = AccessibilityChannel();

  static const _tag = 'A11Y';

  final MethodChannel _channel;
  final EventChannel _events;
  final bool Function() _isSupported;

  /// Current "Reduce Transparency" setting; false when it cannot be read.
  Future<bool> isReduceTransparencyEnabled() async {
    try {
      return await guardNativeCall(
        supported: _isSupported(),
        fallback: false,
        tag: _tag,
        call: () async =>
            await _channel.invokeMethod<bool>('isReduceTransparencyEnabled') ??
            false,
      );
    } on NativeChannelException {
      return false;
    }
  }

  /// The current value, then every change. Repeats are dropped. On other
  /// platforms it emits false once and ends.
  Stream<bool> watchReduceTransparency() async* {
    var last = await isReduceTransparencyEnabled();
    yield last;
    if (!_isSupported()) return;
    await for (final event in _events.receiveBroadcastStream().handleError(
      (Object _) {},
    )) {
      final value = nativeMap(event)?['reduceTransparency'];
      if (value is! bool || value == last) continue;
      last = value;
      yield value;
    }
  }
}
