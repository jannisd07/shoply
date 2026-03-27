import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// A widget that renders real iOS 26 Liquid Glass via native UIGlassEffect,
/// or a BackdropFilter frosted-glass fallback on iOS < 26 and Android.
///
/// Usage:
/// ```dart
/// LiquidGlassContainer(
///   cornerRadius: 28,
///   child: Row(children: [...]),
/// )
/// ```
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final bool isCircle;
  final double glassOpacity;
  final double fallbackBlurSigma;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.cornerRadius = 0,
    this.isCircle = false,
    this.glassOpacity = 1.0,
    this.fallbackBlurSigma = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildNative(context);
    }
    return _buildFallback(context);
  }

  /// iOS: native UIGlassEffect via UiKitView
  Widget _buildNative(BuildContext context) {
    final borderRadius = isCircle
        ? BorderRadius.circular(999)
        : BorderRadius.circular(cornerRadius);
    final opacity = glassOpacity.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          // Native glass view as background
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: UiKitView(
                viewType: 'shoply/liquid_glass',
                creationParams: <String, dynamic>{
                  'cornerRadius': cornerRadius,
                  'isCircle': isCircle,
                },
                creationParamsCodec: const StandardMessageCodec(),
                hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              ),
            ),
          ),
          // Flutter content on top
          child,
        ],
      ),
    );
  }

  /// Android / fallback: BackdropFilter frosted glass
  Widget _buildFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = isCircle
        ? BorderRadius.circular(999)
        : BorderRadius.circular(cornerRadius);
    final opacity = glassOpacity.clamp(0.0, 1.0);
    final sigma = fallbackBlurSigma.clamp(0.0, 80.0);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.12 * opacity),
                      Colors.white.withValues(alpha: 0.06 * opacity),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.75 * opacity),
                      Colors.white.withValues(alpha: 0.55 * opacity),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18 * opacity)
                  : Colors.white.withValues(alpha: 0.8 * opacity),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
