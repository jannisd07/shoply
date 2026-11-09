import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/routes/route_paths.dart';

/// One entry of the Avo Pro catalogue: what the paywall lists and what
/// [ProGate] guards (Konzept 18 §9.6, `pro_features`).
@immutable
class ProFeatureInfo {
  /// Creates an entry.
  const ProFeatureInfo({
    required this.id,
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    this.continueKey,
  });

  /// The id that `/pro?feature=` and [ProGate.run] use.
  final String id;

  /// Symbol of the benefit row (22 pt, `tint`).
  final AvoIconData icon;

  /// Text keys of the benefit row.
  final String titleKey;
  final String bodyKey;

  /// "Danach …": what happens right after the purchase when the paywall was
  /// opened for this feature; null when nothing continues.
  final String? continueKey;
}

/// Which features are part of Avo Pro.
///
/// Owner decision A9 (09.11.2026), variant B "KI + Komfort": Pro raises the
/// daily AI limits (server, `app_flags.ai_limits`) and unlocks the cooking
/// mode after step 1, Avo's suggestions for the week plan and the history
/// statistics. Lists, sharing, recipes, offers and the history itself stay
/// free; offers are never Pro (Plan 8).
abstract final class ProFeatures {
  /// More Avo questions, meal photos and imports a day (the server limit).
  static const avoQuestions = 'avo_questions';

  /// The cooking mode after step 1 (`kCookModeFeature`).
  static const cookMode = 'cook_mode';

  /// Avo fills the week plan with suggestions (Teil B, Wochenplan). Planning
  /// by hand and "auf die Liste" stay free.
  static const planSuggestions = 'plan_suggestions';

  /// Statistics in the history: earlier months, spending (Teil B, Verlauf).
  static const stats = 'stats';

  /// The features that need Avo Pro. [avoQuestions] is not among them: the
  /// questions are free up to the daily limit, which the server enforces.
  static const Set<String> gated = {cookMode, planSuggestions, stats};

  /// Every benefit the paywall lists, in this order.
  static const List<ProFeatureInfo> all = [
    ProFeatureInfo(
      id: avoQuestions,
      icon: AvoIcons.sparkle,
      titleKey: 'pro_feat_ai_title',
      bodyKey: 'pro_feat_ai_body',
      continueKey: 'pro_feat_ai_continue',
    ),
    ProFeatureInfo(
      id: planSuggestions,
      icon: AvoIcons.calendar,
      titleKey: 'pro_feat_plan_title',
      bodyKey: 'pro_feat_plan_body',
      continueKey: 'pro_feat_plan_continue',
    ),
    ProFeatureInfo(
      id: cookMode,
      icon: AvoIcons.forkKnife,
      titleKey: 'pro_feat_cook_title',
      bodyKey: 'pro_feat_cook_body',
      continueKey: 'pro_feat_cook_continue',
    ),
    ProFeatureInfo(
      id: stats,
      icon: AvoIcons.chartBar,
      titleKey: 'pro_feat_stats_title',
      bodyKey: 'pro_feat_stats_body',
      continueKey: 'pro_feat_stats_continue',
    ),
  ];

  /// The catalogue entry of [feature]; null for an unknown id.
  static ProFeatureInfo? info(String? feature) {
    for (final f in all) {
      if (f.id == feature) return f;
    }
    return null;
  }

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

  /// [isLocked] for callbacks (reads, does not watch).
  static bool isLockedNow(WidgetRef ref, String feature) =>
      ProFeatures.isGated(feature) && !ref.read(isSubscribedProvider);
}
