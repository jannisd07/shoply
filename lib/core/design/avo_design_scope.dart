import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Device settings Flutter does not expose, for the whole app. Today: iOS
/// "Reduce Transparency" (Settings > Accessibility > Display & Text Size),
/// read over the `shoply/accessibility` channel (LiquidGlassViewFactory.swift).
///
/// Place it once in the app `builder`. Without it (tests, gallery) every
/// value falls back to "off".
class AvoDesignScope extends StatefulWidget {
  const AvoDesignScope({
    super.key,
    required this.child,
    this.reduceTransparencyOverride,
  });

  final Widget child;

  /// Forces the value (tests, the component gallery).
  final bool? reduceTransparencyOverride;

  /// Reduce Transparency, or Increase Contrast: both replace glass with an
  /// opaque surface.
  static bool reduceTransparencyOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AvoDesignData>();
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    return (scope?.reduceTransparency ?? false) || highContrast;
  }

  @override
  State<AvoDesignScope> createState() => _AvoDesignScopeState();
}

class _AvoDesignScopeState extends State<AvoDesignScope> {
  static const _channel = MethodChannel('shoply/accessibility');
  bool _reduceTransparency = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        widget.reduceTransparencyOverride == null) {
      _channel.setMethodCallHandler(_onCall);
      _read();
    }
  }

  Future<void> _read() async {
    try {
      final value = await _channel.invokeMethod<bool>(
        'isReduceTransparencyEnabled',
      );
      if (mounted && value != null) {
        setState(() => _reduceTransparency = value);
      }
    } on MissingPluginException {
      // Channel not registered yet (AppDelegate is Teil B's): stay off.
    } on PlatformException {
      // Same.
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'reduceTransparencyChanged' && call.arguments is bool) {
      if (mounted) setState(() => _reduceTransparency = call.arguments as bool);
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AvoDesignData(
    reduceTransparency:
        widget.reduceTransparencyOverride ?? _reduceTransparency,
    child: widget.child,
  );
}

class _AvoDesignData extends InheritedWidget {
  const _AvoDesignData({
    required this.reduceTransparency,
    required super.child,
  });

  final bool reduceTransparency;

  @override
  bool updateShouldNotify(_AvoDesignData old) =>
      old.reduceTransparency != reduceTransparency;
}
