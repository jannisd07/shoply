import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_recipe_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';
import 'package:shoply/routes/app_destinations.dart';

// Kap. 5.6 calories and health, Kap. 7.2 the estimate card. Values are
// "geschätzt" and "ca.", goals "Richtwert, kein ärztlicher Rat".
const double _ring = 44; // D2 ProgressRing instead of the object image
const double _warnGlyph = 15; // D2 symbol before a warning line
const double _rowMinHeight = 44; // D2 value rows of the estimate

void _calories(BuildContext context) =>
    openAppDestination(context, AppDestinations.calories);

/// `get_nutrition_status`: "640 kcal übrig / 1.360 von 2.000 kcal heute"
/// with the ring; over the goal the warning symbol and "drüber" (never
/// colour alone).
AvoResultSection avoNutritionStatusSection(
  BuildContext context,
  AvoNutritionStatusCard card,
) {
  final goal = card.goalKcal;
  final consumed = avoInt(context, card.consumedKcal);
  final view = AvoCardAction(
    label: context.tr('avo_view'),
    onPressed: () => _calories(context),
  );
  if (goal == null || goal <= 0) {
    return AvoResultSection(
      title: context.tr('avo_kcal_today', params: {'n': consumed}),
      leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.flame)),
      onOpen: () => _calories(context),
      actions: [view],
    );
  }
  final left = goal - card.consumedKcal;
  final over = left < 0;
  final title = over
      ? context.tr('avo_kcal_over', params: {'n': avoInt(context, -left)})
      : context.tr('avo_kcal_left', params: {'n': avoInt(context, left)});
  final sub = context.tr(
    'avo_kcal_of_today',
    params: {'n': consumed, 'goal': avoInt(context, goal)},
  );
  return AvoResultSection(
    title: title,
    subtitle: sub,
    semanticLabel: '$title, $sub',
    trailingTitle: over
        ? ExcludeSemantics(
            child: Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: _warnGlyph,
              color: context.colors.warning,
            ),
          )
        : null,
    leading: ExcludeSemantics(
      child: ProgressRing(
        value: card.consumedKcal / goal,
        size: _ring,
        over: over,
      ),
    ),
    onOpen: () => _calories(context),
    actions: [view],
  );
}

/// `get_weekly_nutrition_summary`: one row of bars with the dashed goal,
/// the sentence above (Kap. 5.6).
AvoResultSection avoWeekSection(BuildContext context, AvoWeekCard card) {
  final goal = card.goalKcal;
  final logged = card.kcalByDay.values.any((v) => v > 0);
  final sentence = !logged
      ? context.tr('avo_week_empty')
      : goal == null
      ? context.tr(
          'avo_week_avg_nogoal',
          params: {'avg': avoInt(context, card.averageKcal)},
        )
      : context.tr(
          'avo_week_avg',
          params: {
            'avg': avoInt(context, card.averageKcal),
            'goal': avoInt(context, goal),
          },
        );
  final today = DateTime.now();
  return AvoResultSection(
    title: sentence,
    leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.chart_bar)),
    details: [
      if (logged)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
          child: AvoBarChart(
            entries: [
              for (final d in card.days)
                AvoBarEntry(
                  label: avoDay(context, d).split(',').first,
                  value: (card.kcalByDay[d] ?? 0) > 0
                      ? card.kcalByDay[d]!.toDouble()
                      : null,
                ),
            ],
            formatValue: (v) => avoInt(context, v),
            semanticSummary: sentence,
            goal: goal?.toDouble(),
            showValues: false,
            highlightIndex: () {
              final i = card.days.indexWhere((d) => avoIsToday(d, today));
              return i < 0 ? null : i;
            }(),
          ),
        ),
    ],
    onOpen: () => _calories(context),
    actions: [
      AvoCardAction(
        label: context.tr('avo_view'),
        onPressed: () => _calories(context),
      ),
    ],
  );
}

/// `get_challenge_status`: "Wasser-Woche / 4 von 7 Tagen".
List<Widget> avoChallengeSections(
  BuildContext context,
  AvoChallengesCard card,
) {
  if (card.challenges.isEmpty) {
    return [
      AvoResultSection(
        title: context.tr('avo_chal_empty'),
        leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.flag)),
        onOpen: () => _calories(context),
      ),
    ];
  }
  return [
    for (final c in card.challenges)
      AvoResultSection(
        title: switch (c.type) {
          ChallengeType.fasting16_8 => context.tr('avo_chal_fasting'),
          ChallengeType.noSugar30 => context.tr('avo_chal_sugar'),
          ChallengeType.custom =>
            c.title?.trim().isNotEmpty ?? false
                ? c.title!.trim()
                : context.tr('avo_chal_custom'),
        },
        subtitle: [
          c.totalDays == null
              ? context.tr('avo_chal_day', params: {'day': '${c.day}'})
              : context.tr(
                  'avo_chal_day_of',
                  params: {'day': '${c.day}', 'total': '${c.totalDays}'},
                ),
          if (c.checkedInToday) context.tr('avo_chal_checked'),
        ].join(' · '),
        leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.flag)),
        onOpen: () => _calories(context),
        actions: [
          AvoCardAction(
            label: context.tr('avo_view'),
            onPressed: () => _calories(context),
          ),
        ],
      ),
  ];
}

/// `setup_nutrition_goal` with a goal in place: the new goal and
/// "Übernehmen"; afterwards its result with "Widerrufen".
class AvoGoalPreviewSection extends StatelessWidget {
  const AvoGoalPreviewSection({
    super.key,
    required this.payload,
    required this.scope,
    required this.card,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoGoalPreviewCard card;

  @override
  Widget build(BuildContext context) {
    final chat = scope.chat;
    if (chat.recordOf(payload) != null) {
      return AvoRecordSection(payload: payload, scope: scope);
    }
    final kcal = card.goal.dailyCalorieTarget ?? 0;
    final was = card.previous?.dailyCalorieTarget;
    final working = chat.isCardWorking(payload);
    final changes = avoGoalChanges(context, card);
    return AvoResultSection(
      title: context.tr('avo_goal_new', params: {'kcal': avoInt(context, kcal)}),
      subtitle: [
        if (was != null)
          context.tr('avo_goal_was', params: {'kcal': avoInt(context, was)}),
        context.tr('avo_guide_value'),
      ].join(' · '),
      leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.flag)),
      // Every field "Übernehmen" changes, the weight entry too (N3).
      maxCollapsed: changes.length,
      details: [
        for (final c in changes)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.xxs,
            ),
            child: Text(
              c,
              style: context.text(
                AvoTextStyle.subhead,
                color: context.colors.secondaryLabel,
              ),
            ),
          ),
      ],
      actions: [
        AvoCardAction(
          label: context.tr('avo_goal_use'),
          working: working,
          onPressed: working || scope.offline
              ? null
              : () => chat.applyGoal(payload),
        ),
      ],
    );
  }
}

/// The lines of a goal preview: each field that differs from the goal in
/// place (all set ones for a first goal), and the weight entry for today.
List<String> avoGoalChanges(BuildContext context, AvoGoalPreviewCard card) {
  final g = card.goal;
  final b = card.previous;
  String field(String label, String value) => context.tr(
    'avo_field',
    params: {'label': context.tr(label), 'value': value},
  );
  String kg(double v) => '${avoDecimal(context, v)} kg';
  return [
    if (b == null || b.goalType != g.goalType)
      field('avo_goal_field_type', context.tr('avo_goal_type_${g.goalType.dbValue}')),
    if (b == null || b.activityLevel != g.activityLevel)
      field(
        'avo_goal_field_activity',
        context.tr('avo_activity_${g.activityLevel.dbValue}'),
      ),
    if (g.heightCm != null && b?.heightCm != g.heightCm)
      field('avo_goal_field_height', '${avoInt(context, g.heightCm!)} cm'),
    if (g.currentWeightKg != null && b?.currentWeightKg != g.currentWeightKg)
      field('avo_goal_field_weight', kg(g.currentWeightKg!)),
    if (b?.targetWeightKg != g.targetWeightKg)
      field(
        'avo_goal_field_target',
        g.targetWeightKg == null ? context.tr('avo_val_none') : kg(g.targetWeightKg!),
      ),
    if (b?.timelineWeeks != g.timelineWeeks && g.timelineWeeks != null)
      field(
        'avo_goal_field_weeks',
        context.tr('avo_goal_weeks', params: {'n': '${g.timelineWeeks}'}),
      ),
    if (b == null ||
        b.proteinTargetG != g.proteinTargetG ||
        b.carbsTargetG != g.carbsTargetG ||
        b.fatTargetG != g.fatTargetG)
      field(
        'avo_goal_field_macros',
        context.tr(
          'avo_goal_macros',
          params: {
            'p': '${g.proteinTargetG ?? '–'}',
            'c': '${g.carbsTargetG ?? '–'}',
            'f': '${g.fatTargetG ?? '–'}',
          },
        ),
      ),
    if (card.writesWeight && g.currentWeightKg != null)
      context.tr(
        'avo_goal_weight_today',
        params: {'kg': avoDecimal(context, g.currentWeightKg!)},
      ),
  ];
}

/// Avo's estimate of a meal (Kap. 7.2): never saved until "Eintragen".
/// The meal and the portions can be changed in place; only the newest open
/// estimate has the filled button. After "Eintragen" it is the result row
/// with "Widerrufen".
class AvoEstimateSection extends StatelessWidget {
  const AvoEstimateSection({
    super.key,
    required this.payload,
    required this.scope,
    required this.card,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoEstimateCard card;

  String _sureness(BuildContext context) => switch (card.confidence) {
    'high' => context.tr('avo_est_sure'),
    'medium' => context.tr('avo_est_unsure'),
    'low' => context.tr('avo_est_rough'),
    _ => context.tr('avo_estimated'),
  };

  void _mealMenu(BuildContext anchor) {
    final chat = scope.chat;
    final current = chat.mealOf(payload);
    showAvoMenu(
      anchor,
      items: [
        for (final m in MealType.values)
          AvoMenuItem(
            label: avoMealName(anchor, m),
            checked: m == current,
            onSelected: () => chat.setMeal(payload, m),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = scope.chat;
    if (chat.recordOf(payload) != null) {
      return AvoRecordSection(payload: payload, scope: scope);
    }
    final colors = context.colors;
    final portions = chat.portionOf(payload);
    final kcal = card.kcal * portions;
    double? times(double? g) => g == null ? null : g * portions;
    final meal = chat.mealOf(payload);
    final working = chat.isCardWorking(payload);
    final newest = chat.isNewestOpenEstimate(payload);
    final kcalText = context.tr(
      card.estimated ? 'avo_est_about' : 'avo_est_kcal',
      params: {'kcal': avoInt(context, kcal)},
    );
    final sub = card.estimated ? '$kcalText · ${_sureness(context)}' : kcalText;
    final secondary = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
    );
    final grams = card.grams;
    final amount = grams != null
        ? context.tr('avo_est_grams', params: {'g': avoInt(context, grams * portions)})
        : card.portion;

    Widget valueRow({
      required String label,
      required Widget value,
      String? semantics,
    }) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AvoSpacing.m,
          runSpacing: AvoSpacing.xs,
          children: [
            Text(label, style: context.text(AvoTextStyle.body)),
            value,
          ],
        ),
      ),
    );

    final log = context.tr('avo_est_log');
    final button = newest
        ? AppButton.primary(
            label: log,
            working: working,
            onPressed: working || scope.offline
                ? null
                : () => chat.logEstimate(payload),
          )
        : AppButton.plain(
            label: log,
            working: working,
            onPressed: working || scope.offline
                ? null
                : () => chat.logEstimate(payload),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          header: true,
          label: '${card.name}, $sub',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.l,
              AvoSpacing.m,
              AvoSpacing.l,
              AvoSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.name, style: context.text(AvoTextStyle.headline)),
                Text(sub, style: secondary),
              ],
            ),
          ),
        ),
        // "Mahlzeit: Mittagessen" is one button for VoiceOver.
        Builder(
          builder: (anchor) => Semantics(
            container: true,
            button: true,
            label:
                '${context.tr('avo_est_meal')}: ${avoMealName(context, meal)}',
            onTap: () => _mealMenu(anchor),
            excludeSemantics: true,
            child: valueRow(
              label: context.tr('avo_est_meal'),
              value: AppButton.plain(
                label: avoMealName(context, meal),
                onPressed: () => _mealMenu(anchor),
              ),
            ),
          ),
        ),
        const AvoHairline(indent: AvoSpacing.l),
        valueRow(
          label: amount == null
              ? context.tr('avo_est_amount')
              : '${context.tr('avo_est_amount')} · $amount',
          value: ValueStepper(
            value: portions,
            min: 1,
            max: avoMaxPortions,
            unit: portions == 1
                ? context.tr('avo_est_portion_one')
                : context.tr('avo_est_portions'),
            semanticLabel: context.tr('avo_est_amount'),
            compact: true,
            onChanged: (v) => chat.setPortion(payload, v),
          ),
        ),
        const AvoHairline(indent: AvoSpacing.l),
        const SizedBox(height: AvoSpacing.s),
        Semantics(
          label: avoNutritionSentence(
            context,
            kcal: kcal,
            protein: times(card.proteinG),
            carbs: times(card.carbsG),
            fat: times(card.fatG),
          ),
          child: AvoNutritionRow(
            kcal: kcal,
            protein: times(card.proteinG),
            carbs: times(card.carbsG),
            fat: times(card.fatG),
          ),
        ),
        for (final allergen in card.allergens)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.l,
              AvoSpacing.s,
              AvoSpacing.l,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                  child: ExcludeSemantics(
                    child: AvoIcon(
                      AvoIcons.exclamationmarkTriangleFill,
                      size: _warnGlyph,
                      color: colors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: AvoSpacing.s),
                Expanded(
                  child: Text(
                    context.tr(
                      'avo_photo_allergen',
                      params: {'allergen': allergen},
                    ),
                    style: context.text(AvoTextStyle.subhead, color: colors.label),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.l,
            AvoSpacing.s,
            AvoSpacing.l,
            0,
          ),
          child: Text(
            context.tr('avo_est_footnote'),
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.l,
            AvoSpacing.s,
            AvoSpacing.l,
            AvoSpacing.m,
          ),
          child: Align(alignment: AlignmentDirectional.centerStart, child: button),
        ),
      ],
    );
  }
}
