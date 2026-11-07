import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Real iOS 26 Liquid Glass (`UIGlassEffect`) via a native platform view, with
/// a `BackdropFilter` frosted-glass fallback on Android.
///
/// Do not wrap the native path in a `ClipRRect`: the effect renders its
/// specular rim and edge lensing from the shape it is *given*, so clipping a
/// square glass into a rounded frame cuts those cues off and the result reads
/// as a flat blur. The shape is passed to the native side instead, where it
/// becomes a `cornerConfiguration`.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double cornerRadius;

  /// Capsule / circle: corners follow the shorter side. Overrides
  /// [cornerRadius].
  final bool isCircle;

  /// Glass expands and highlights under the finger, like system controls.
  final bool interactive;

  /// Optional stained-glass tint; the system derives a vibrant version.
  final Color? tint;

  /// `true` selects `UIGlassEffect.Style.clear` over `.regular`.
  final bool clearStyle;

  final double fallbackBlurSigma;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.cornerRadius = 0,
    this.isCircle = false,
    this.interactive = true,
    this.tint,
    this.clearStyle = false,
    this.fallbackBlurSigma = 25.0,
  });

  static bool get _nativeGlassAvailable => Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    if (_nativeGlassAvailable) {
      return _buildNative(context);
    }
    return _buildFallback(context);
  }

  Widget _buildNative(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: UiKitView(
            viewType: 'shoply/liquid_glass',
            creationParams: <String, dynamic>{
              'cornerRadius': cornerRadius,
              'isCircle': isCircle,
              'isCapsule': isCircle,
              'interactive': interactive,
              'style': clearStyle ? 'clear' : 'regular',
              if (tint != null) 'tint': tint!.toARGB32(),
            },
            creationParamsCodec: const StandardMessageCodec(),
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = isCircle
        ? BorderRadius.circular(999)
        : BorderRadius.circular(cornerRadius);
    final sigma = fallbackBlurSigma.clamp(0.0, 80.0);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.75),
                      Colors.white.withValues(alpha: 0.55),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.8),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Liquid Glass with the accessibility fallback already handled.
///
/// Every glass surface in the app needs the same two guards: real
/// `UIGlassEffect` only on iOS, and an opaque surface when the user has
/// switched on Increase Contrast / Reduce Transparency — otherwise the
/// content behind shows through text that then becomes unreadable. Wrapping
/// that once keeps the rule in a single place instead of being re-derived at
/// every call site.
class AdaptiveGlass extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final bool isCircle;
  final bool interactive;

  /// Surface used when glass is unavailable or unwanted. Defaults to the
  /// app's card colour with a hairline border.
  final Color? opaqueColor;

  const AdaptiveGlass({
    super.key,
    required this.child,
    this.cornerRadius = 0,
    this.isCircle = false,
    this.interactive = true,
    this.opaqueColor,
  });

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = MediaQuery.highContrastOf(context);

    if (!reduceTransparency && Platform.isIOS) {
      return LiquidGlassContainer(
        cornerRadius: cornerRadius,
        isCircle: isCircle,
        interactive: interactive,
        child: child,
      );
    }

    final radius = isCircle
        ? BorderRadius.circular(999)
        : BorderRadius.circular(cornerRadius);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: opaqueColor ?? theme.colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

/// One glass shape inside a [LiquidGlassGroup], positioned in the group's own
/// coordinate space (logical pixels, origin top-left).
class LiquidGlassShape {
  final Rect rect;
  final double cornerRadius;
  final bool isCapsule;

  const LiquidGlassShape({
    required this.rect,
    this.cornerRadius = 0,
    this.isCapsule = false,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'cornerRadius': cornerRadius,
        'isCapsule': isCapsule,
      };
}

/// Several glass shapes sharing one `UIGlassContainerEffect`, so they bulge
/// toward each other and fuse once they are within [spacing] — the behaviour
/// the Messages composer's "+" button and text capsule have.
///
/// Two separate platform views can never do this; merging only happens between
/// siblings of a single container effect. So this renders the *backgrounds*
/// only, and the caller stacks the actual controls on top at matching offsets.
class LiquidGlassGroup extends StatelessWidget {
  final List<LiquidGlassShape> shapes;

  /// Distance at which neighbouring shapes begin to merge.
  final double spacing;
  final bool interactive;
  final Color? tint;
  final bool clearStyle;

  const LiquidGlassGroup({
    super.key,
    required this.shapes,
    this.spacing = 20,
    this.interactive = true,
    this.tint,
    this.clearStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return const SizedBox.shrink();
    return UiKitView(
      viewType: 'shoply/liquid_glass_group',
      creationParams: <String, dynamic>{
        'shapes': [for (final s in shapes) s.toMap()],
        'spacing': spacing,
        'interactive': interactive,
        'style': clearStyle ? 'clear' : 'regular',
        if (tint != null) 'tint': tint!.toARGB32(),
      },
      creationParamsCodec: const StandardMessageCodec(),
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}
