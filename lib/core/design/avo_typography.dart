import 'package:flutter/widgets.dart';

/// The iOS text styles used by D2 (SF Pro), plus three D2-specific ones.
enum AvoTextStyle {
  largeTitle,
  title1,
  title2,
  title3,
  headline,
  body,
  callout,
  subhead,
  footnote,
  caption1,
  caption2,

  /// Section and aisle headings: 13/18 semibold, upper case, +0.3 tracking.
  sectionCaps,

  /// Tab bar labels: 11/13, 500 (600 when selected).
  tabLabel,

  /// The one big figure of a screen (an amount, a month total): 34/41 bold
  /// with tabular figures. Grows like a large title but stops at 51 pt, so a
  /// long amount still fits a 320 pt screen at the largest text sizes.
  numberXL,
}

/// iOS Dynamic Type content size categories, smallest to largest.
enum ContentSizeCategory {
  xSmall,
  small,
  medium,
  large,
  xLarge,
  xxLarge,
  xxxLarge,
  ax1,
  ax2,
  ax3,
  ax4,
  ax5;

  bool get isAccessibility => index >= ax1.index;
}

/// Sizes, line heights, weights and tracking per style, following Apple's
/// Dynamic Type tables, so large titles grow less than body text the way they
/// do on iOS.
///
/// Flutter scales every font linearly by the system text scale factor. To get
/// the iOS sizes anyway without switching scaling off for the whole app (old
/// screens still rely on it), [AvoTypography.style] divides the table size by
/// that factor; Flutter multiplies it back, and the text ends up exactly at the
/// table size. Bold Text is applied by Flutter's `Text` widget itself.
class AvoTypography {
  const AvoTypography._(this.category, this._factor);

  /// The category the device is set to.
  final ContentSizeCategory category;

  /// The linear factor Flutter applies (`textScaler.scale(17) / 17`).
  final double _factor;

  /// Typography for [context] (reads `MediaQuery.textScalerOf`).
  static AvoTypography of(BuildContext context) {
    final factor = MediaQuery.textScalerOf(context).scale(17) / 17;
    return AvoTypography._(categoryForFactor(factor), factor);
  }

  /// For tests and the gallery.
  static AvoTypography forFactor(double factor) =>
      AvoTypography._(categoryForFactor(factor), factor);

  /// Body sizes per category (xS … AX5); the factor maps onto the nearest.
  static const List<double> _bodySizes = [
    14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53, //
  ];

  static ContentSizeCategory categoryForFactor(double factor) {
    final body = 17 * factor;
    var best = 0;
    for (var i = 1; i < _bodySizes.length; i++) {
      if ((_bodySizes[i] - body).abs() < (_bodySizes[best] - body).abs()) {
        best = i;
      }
    }
    return ContentSizeCategory.values[best];
  }

  /// Point sizes per style and category (Apple HIG, iOS).
  static const Map<AvoTextStyle, List<double>> _sizes = {
    AvoTextStyle.largeTitle: [31, 32, 33, 34, 36, 38, 40, 44, 48, 52, 56, 60],
    AvoTextStyle.title1: [25, 26, 27, 28, 30, 32, 34, 38, 43, 48, 53, 58],
    AvoTextStyle.title2: [19, 20, 21, 22, 24, 26, 28, 34, 39, 44, 50, 56],
    AvoTextStyle.title3: [17, 18, 19, 20, 22, 24, 26, 31, 37, 43, 49, 55],
    AvoTextStyle.headline: [14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53],
    AvoTextStyle.body: [14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53],
    AvoTextStyle.callout: [13, 14, 15, 16, 18, 20, 22, 26, 32, 38, 44, 51],
    AvoTextStyle.subhead: [12, 13, 14, 15, 17, 19, 21, 25, 30, 36, 42, 49],
    AvoTextStyle.footnote: [12, 12, 12, 13, 15, 17, 19, 23, 27, 33, 38, 44],
    AvoTextStyle.caption1: [11, 11, 11, 12, 14, 16, 18, 22, 26, 32, 37, 43],
    AvoTextStyle.caption2: [11, 11, 11, 11, 13, 15, 17, 20, 24, 29, 34, 40],
    AvoTextStyle.sectionCaps: [12, 12, 12, 13, 15, 17, 19, 23, 27, 33, 38, 44],
    AvoTextStyle.tabLabel: [11, 11, 11, 11, 12, 13, 14, 14, 14, 14, 14, 14],
    AvoTextStyle.numberXL: [31, 32, 33, 34, 36, 38, 40, 44, 48, 51, 51, 51],
  };

  /// Line height at the default size (D2), scaled with the size.
  static const Map<AvoTextStyle, double> _defaultLeading = {
    AvoTextStyle.largeTitle: 41 / 34,
    AvoTextStyle.title1: 34 / 28,
    AvoTextStyle.title2: 28 / 22,
    AvoTextStyle.title3: 25 / 20,
    AvoTextStyle.headline: 22 / 17,
    AvoTextStyle.body: 22 / 17,
    AvoTextStyle.callout: 21 / 16,
    AvoTextStyle.subhead: 20 / 15,
    AvoTextStyle.footnote: 18 / 13,
    AvoTextStyle.caption1: 16 / 12,
    AvoTextStyle.caption2: 13 / 11,
    AvoTextStyle.sectionCaps: 18 / 13,
    AvoTextStyle.tabLabel: 13 / 11,
    AvoTextStyle.numberXL: 41 / 34,
  };

  static const Map<AvoTextStyle, FontWeight> _weights = {
    AvoTextStyle.largeTitle: FontWeight.w700,
    AvoTextStyle.title1: FontWeight.w700,
    AvoTextStyle.title2: FontWeight.w700,
    AvoTextStyle.title3: FontWeight.w600,
    AvoTextStyle.headline: FontWeight.w600,
    AvoTextStyle.body: FontWeight.w400,
    AvoTextStyle.callout: FontWeight.w400,
    AvoTextStyle.subhead: FontWeight.w400,
    AvoTextStyle.footnote: FontWeight.w400,
    AvoTextStyle.caption1: FontWeight.w400,
    AvoTextStyle.caption2: FontWeight.w500,
    AvoTextStyle.sectionCaps: FontWeight.w600,
    AvoTextStyle.tabLabel: FontWeight.w500,
    AvoTextStyle.numberXL: FontWeight.w700,
  };

  /// Size in points for [style] at this category (what the user sees).
  double sizeOf(AvoTextStyle style) => _sizes[style]![category.index];

  /// Line height in points.
  double lineHeightOf(AvoTextStyle style) =>
      (sizeOf(style) * _defaultLeading[style]!).roundToDouble();

  /// The text style. [tabular] switches to tabular figures (prices, counts);
  /// [AvoTextStyle.numberXL] always has them.
  TextStyle style(
    AvoTextStyle style, {
    Color? color,
    FontWeight? weight,
    bool tabular = false,
  }) {
    final size = sizeOf(style);
    var tracking = trackingFor(size);
    if (style == AvoTextStyle.sectionCaps) tracking += 0.3;
    // D2 sets large titles 0.2 pt tighter than the SF table (+0.2 at 34 pt).
    if (style == AvoTextStyle.largeTitle || style == AvoTextStyle.numberXL) {
      tracking -= 0.2;
    }
    final tabularFigures = tabular || style == AvoTextStyle.numberXL;
    return TextStyle(
      inherit: false,
      // CupertinoSystemText/Display make the iOS engine pick SF Pro Text below
      // 20 pt and SF Pro Display from 20 pt, like UIKit does.
      fontFamily: size >= 20 ? 'CupertinoSystemDisplay' : 'CupertinoSystemText',
      fontSize: size / _factor,
      height: lineHeightOf(style) / size,
      fontWeight: weight ?? _weights[style],
      // Flutter's TextScaler scales only fontSize, so tracking stays in points.
      letterSpacing: tracking,
      color: color,
      textBaseline: TextBaseline.alphabetic,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: tabularFigures
          ? const [FontFeature.tabularFigures()]
          : null,
      decoration: TextDecoration.none,
    );
  }

  /// SF Pro tracking in points for a point size (Apple's tracking table,
  /// linearly interpolated between the listed sizes).
  static double trackingFor(double size) {
    const table = <List<double>>[
      [6, 0.24],
      [9, 0.17],
      [10, 0.12],
      [11, 0.06],
      [12, 0.0],
      [13, -0.08],
      [14, -0.15],
      [15, -0.23],
      [16, -0.31],
      [17, -0.43],
      [20, -0.45],
      [22, -0.26],
      [24, 0.07],
      [28, 0.38],
      [34, 0.40],
      [40, 0.37],
      [48, 0.35],
      [56, 0.32],
      [60, 0.29],
      [80, 0.0],
    ];
    if (size <= table.first[0]) return table.first[1];
    for (var i = 1; i < table.length; i++) {
      final hi = table[i];
      if (size <= hi[0]) {
        final lo = table[i - 1];
        final t = (size - lo[0]) / (hi[0] - lo[0]);
        return lo[1] + (hi[1] - lo[1]) * t;
      }
    }
    return table.last[1];
  }
}
