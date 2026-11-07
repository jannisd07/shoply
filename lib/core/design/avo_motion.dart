import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Springs instead of fixed durations (Konzept 00 §10.1, apple-design).
///
/// Every spring is given as Apple's response (seconds) and damping ratio and
/// converted for a mass of 1: stiffness = (2π / response)², damping =
/// 4π · ratio / response. Animate with `controller.animateWith(
/// SpringSimulation(spring, controller.value, target, velocity))` so a motion
/// always starts from the current value and velocity and can be interrupted.
abstract final class AvoMotion {
  static SpringDescription spring(double response, double dampingRatio) {
    final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
    final damping = 4 * math.pi * dampingRatio / response;
    return SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
  }

  /// Default for UI changes (0.35 s, no overshoot).
  static final standard = spring(0.35, 1.0);

  /// Presses, check circle, segment thumb (0.25 s).
  static final quick = spring(0.25, 1.0);

  /// Menus growing out of their button (0.30 s).
  static final menu = spring(0.30, 1.0);

  /// Rolling digits and progress rings (0.30 s).
  static final digits = spring(0.30, 1.0);

  /// Rows moving, card to detail morph (0.40 s).
  static final move = spring(0.40, 1.0);
  static final morph = spring(0.40, 1.0);

  /// After a flick only: slight overshoot (0.35 s, 0.8).
  static final fling = spring(0.35, 0.8);

  /// Success moment (0.40 s, 0.8).
  static final celebrate = spring(0.40, 0.8);

  /// Reduce Motion replacement: a short cross-fade.
  static const fadeReduced = Duration(milliseconds: 200);

  /// Pressed scale of buttons and toolbar items.
  static const pressedScale = 0.97;

  /// Whether motion should be replaced by fades.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Apple's momentum projection (deceleration 0.998): where a flick with
  /// [velocity] (points per second) comes to rest, relative to its start.
  static double project(double velocity, {double deceleration = 0.998}) =>
      (velocity / 1000) * deceleration / (1 - deceleration);

  /// Rubber band past an edge.
  static double rubberBand(
    double overshoot,
    double dimension, {
    double constant = 0.55,
  }) =>
      (overshoot * dimension * constant) /
      (dimension + constant * overshoot.abs());
}
