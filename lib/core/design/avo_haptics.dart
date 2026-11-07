import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The only way the app triggers haptics (Konzept 00 §11). Fire it in the
/// same frame as the visual change it belongs to. Never on tab switches,
/// back navigation, scrolling, plain buttons, chips or text fields.
abstract final class AvoHaptics {
  static const _channel = MethodChannel('shoply/haptics');

  /// Checking off an item, a swipe crossing its threshold, voice mode start.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Snapping into place: reorder, stepper, segment swipe, picker.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Last item checked, trip saved, purchase, challenge reached.
  static Future<void> success() =>
      _notification('success', HapticFeedback.mediumImpact);

  /// An allergen or another warning the user must notice.
  static Future<void> warning() =>
      _notification('warning', HapticFeedback.mediumImpact);

  /// Something failed.
  static Future<void> error() =>
      _notification('error', HapticFeedback.heavyImpact);

  /// Uses `UINotificationFeedbackGenerator` on iOS (native channel in
  /// LiquidGlassViewFactory.swift); falls back to an impact elsewhere or
  /// until the channel is registered.
  static Future<void> _notification(
    String type,
    Future<void> Function() fallback,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return fallback();
    try {
      await _channel.invokeMethod<void>('notification', type);
    } on MissingPluginException {
      await fallback();
    } on PlatformException {
      await fallback();
    }
  }
}
