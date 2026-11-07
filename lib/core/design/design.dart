/// The Avo design system (D2 "Glas"). Import this one file in screens and
/// components:
///
/// ```dart
/// import 'package:shoply/core/design/design.dart';
///
/// Text('Listen', style: context.text(AvoTextStyle.largeTitle));
/// ColoredBox(color: context.colors.background);
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/avo_colors.dart';
import 'package:shoply/core/design/avo_design_scope.dart';
import 'package:shoply/core/design/avo_motion.dart';
import 'package:shoply/core/design/avo_typography.dart';

export 'avo_colors.dart';
export 'avo_design_scope.dart';
export 'avo_haptics.dart';
export 'avo_metrics.dart';
export 'avo_motion.dart';
export 'avo_typography.dart';

extension AvoDesignContext on BuildContext {
  /// Colour tokens for the current brightness and contrast.
  AvoColors get colors => AvoColors.of(this);

  /// Typography for the current Dynamic Type size.
  AvoTypography get typography => AvoTypography.of(this);

  /// A text style from the type scale, coloured [AvoColors.label] unless
  /// [color] is given.
  TextStyle text(
    AvoTextStyle style, {
    Color? color,
    FontWeight? weight,
    bool tabular = false,
  }) => typography.style(
    style,
    color: color ?? colors.label,
    weight: weight,
    tabular: tabular,
  );

  /// Reduce Motion is on: replace movement with short fades.
  bool get reduceMotion => AvoMotion.reduced(this);

  /// Reduce Transparency or Increase Contrast is on: no glass.
  bool get reduceTransparency => AvoDesignScope.reduceTransparencyOf(this);

  /// The device is in an accessibility text size (AX1 and up).
  bool get isAccessibilityText => typography.category.isAccessibility;
}
