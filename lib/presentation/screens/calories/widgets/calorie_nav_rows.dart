import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/routes/route_paths.dart';

const double _kGlyph = 17; // D2 row symbols, free (no tile)

/// The diary's last group (S1 #10): Gewicht, Challenges and Ziele with their
/// current value; a missing value is a dash. "Workouts" joins once its
/// screen (S17) exists.
class CalorieNavRows extends ConsumerWidget {
  const CalorieNavRows({super.key, required this.goalKcal});

  final int? goalKcal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = context.colors.secondaryLabel;
    Widget glyph(IconData icon) => Icon(icon, size: _kGlyph, color: secondary);

    final weights = ref.watch(weightHistoryProvider).valueOrNull;
    final latest = weights == null || weights.isEmpty
        ? null
        : weights.reduce((a, b) => b.loggedDate.isAfter(a.loggedDate) ? b : a);
    final challenges = ref.watch(activeChallengesProvider).valueOrNull;
    final goal = goalKcal;

    return InsetSection(
      separatorIndent: AvoSpacing.l + _kGlyph + AvoSpacing.m,
      children: [
        NavRow(
          title: context.tr('cal_nav_weight'),
          value: weights == null ? null : (latest == null ? '–' : '${context.amount(latest.weightKg)} kg'),
          leading: glyph(CupertinoIcons.gauge),
          onTap: () => context.push('${RoutePaths.calories}/weight'),
        ),
        NavRow(
          title: context.tr('cal_nav_challenges'),
          value: challenges == null ? null : _challengeValue(context, challenges),
          leading: glyph(CupertinoIcons.flag),
          onTap: () => context.push('${RoutePaths.calories}/challenges'),
        ),
        NavRow(
          title: context.tr('cal_nav_goals'),
          value: goal == null ? '–' : context.tr('cal_meal_sum', params: {'kcal': context.kcal(goal)}),
          leading: glyph(CupertinoIcons.scope),
          onTap: () => context.push('${RoutePaths.calories}/goals'),
        ),
      ],
    );
  }

  String _challengeValue(BuildContext context, List<DietChallenge> active) {
    if (active.isEmpty) return context.tr('cal_challenges_none');
    final c = active.first;
    final name = switch (c.type) {
      ChallengeType.fasting16_8 => context.tr('cal_challenge_short_fasting'),
      ChallengeType.noSugar30 => context.tr('cal_challenge_short_no_sugar'),
      ChallengeType.custom => c.title ?? context.tr('challenge_type_custom'),
    };
    return context.tr('cal_challenge_day', params: {'name': name, 'n': '${c.daysElapsed}'});
  }
}
