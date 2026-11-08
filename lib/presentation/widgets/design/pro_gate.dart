import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/routes/route_paths.dart';

/// Which features are part of Avo Pro, by the id that `/pro?feature=` and
/// [ProGate.run] use.
///
/// Empty until the owner decides Free against Pro (A9): until then every
/// feature runs for everyone. Offers are never Pro (Plan 8).
abstract final class ProFeatures {
  static const Set<String> gated = {};

  /// Replaces [gated] in tests.
  @visibleForTesting
  static Set<String>? debugGatedOverride;

  /// Whether [feature] needs Avo Pro.
  static bool isGated(String feature) =>
      (debugGatedOverride ?? gated).contains(feature);
}

/// The one place that guards a Pro action (Teil A, used by both parts).
abstract final class ProGate {
  /// Runs [action] if [feature] is free or the person has Avo Pro. Otherwise
  /// opens the paywall for [feature] above everything and runs [action] once
  /// the person comes back subscribed.
  ///
  /// Returns whether [action] ran.
  static Future<bool> run(
    BuildContext context,
    WidgetRef ref, {
    required String feature,
    required FutureOr<void> Function() action,
  }) async {
    if (!ProFeatures.isGated(feature) || ref.read(isSubscribedProvider)) {
      await action();
      return true;
    }
    await context.push<void>(RoutePaths.proFor(feature));
    if (!context.mounted || !ref.read(isSubscribedProvider)) return false;
    await action();
    return true;
  }

  /// Whether [feature] is locked for the person right now (for a lock or
  /// [ProBadge] next to an entry). Rebuilds when the subscription changes.
  static bool isLocked(WidgetRef ref, String feature) =>
      ProFeatures.isGated(feature) && !ref.watch(isSubscribedProvider);
}
