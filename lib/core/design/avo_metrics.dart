import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Spacing scale (D2). Screens use these, never raw numbers.
abstract final class AvoSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Left and right margin of screen content and inset groups.
  static const double screen = 16;

  /// Inner padding of a component group (D2 `section`, p20).
  static const double group = 20;

  /// Gap between sections on a screen.
  static const double section = 24;
}

/// Corner radii (D2).
abstract final class AvoRadii {
  /// Inset groups, list cards, recipe hero.
  static const double group = 26;

  /// Recipe cards, quick-add tiles, info glass panels.
  static const double card = 20;

  /// Medium images (quick-add, shopping mode rows).
  static const double imageMedium = 12;

  /// Small images and article thumbnails (44 pt).
  static const double imageSmall = 10;

  /// Large article image (88 pt).
  static const double imageLarge = 20;

  /// Capsule: half the height.
  static double capsule(double height) => height / 2;
}

/// Fixed control sizes (D2). Text never sits in a fixed height: these are
/// minimums, content may grow.
abstract final class AvoSizes {
  /// Minimum touch target (Apple HIG, Konzept 00 §14).
  static const double hitTarget = 44;

  /// Toolbar buttons and glass circles.
  static const double toolbarButton = 44;

  /// Tab bar capsule height, item height, side and bottom inset.
  static const double tabBarHeight = 64;
  static const double tabItemHeight = 56;
  static const double tabBarSide = 12;
  static const double tabBarBottomMin = 12;

  /// Add-item accessory minimum height and gap above the tab bar.
  static const double accessoryHeight = 52;
  static const double accessoryGap = 12;

  /// Check circle diameter in lists and in shopping mode.
  static const double checkCircle = 26;
  static const double checkCircleLarge = 36;

  /// Article thumbnails.
  static const double thumbSmall = 44;
  static const double thumbMedium = 52;
  static const double thumbLarge = 88;

  /// Hairline width.
  static const double hairline = 0.5;

  /// Height of the fade under the top toolbar (D2 scroll edge).
  static const double scrollEdge = 110;
}

/// Where floating chrome sits, from one source, so screens never measure the
/// tab bar or the accessory after the frame.
abstract final class ShellInsets {
  /// Distance of the tab bar's bottom edge from the screen bottom: the home
  /// indicator area minus 14 pt (20 pt on a 34 pt safe area, as in D2).
  static double tabBarBottom(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return math.max(AvoSizes.tabBarBottomMin, safe - 14);
  }

  /// Space content needs at the bottom so the tab bar never covers it.
  static double bottom(BuildContext context, {bool withAccessory = false}) {
    var h = tabBarBottom(context) + AvoSizes.tabBarHeight + AvoSpacing.l;
    if (withAccessory) {
      h += AvoSizes.accessoryHeight + AvoSizes.accessoryGap;
    }
    return h;
  }

  /// Bottom of a floating element (accessory, undo toast) above the tab bar.
  static double aboveTabBar(BuildContext context) =>
      tabBarBottom(context) + AvoSizes.tabBarHeight + AvoSizes.accessoryGap;
}
