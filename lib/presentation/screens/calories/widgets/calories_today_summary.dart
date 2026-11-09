import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_colors.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_macros.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_ring.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';

/// Minimum height of the number-and-ring line in the diary (D2: 152).
const double _kDiaryLineMin = 152; // D2
const double _kOverGlyph = 12; // D2 warning symbol
const double _kSyncGlyph = 13; // D2 sync mark behind the line

/// The numbers of one day against the goal, as the summaries show them.
class CalorieDayNumbers {
  CalorieDayNumbers({
    required CalorieDay? day,
    required this.goal,
    required this.isToday,
  })  : totals = day?.totals ?? const DailyNutritionTotals(),
        hasEntries = day?.hasFoodEntries ?? false,
        syncing = day?.hasUnsyncedRows ?? false;

  final DailyNutritionTotals totals;

  /// The goal with a calorie target; null without one.
  final NutritionGoal? goal;
  final bool isToday;
  final bool hasEntries;

  /// Some row of the day still waits for the server.
  final bool syncing;

  int get eaten => totals.calories;
  int? get goalKcal => goal?.dailyCalorieTarget;
  int? get remaining => goalKcal == null ? null : goalKcal! - eaten;
  bool get isOver => (remaining ?? 0) < 0;

  /// Ring fill: eaten ÷ goal, full when over.
  double get progress {
    final g = goalKcal;
    if (g == null || g <= 0) return 0;
    return (eaten / g).clamp(0.0, 1.0);
  }

  /// Today with a goal: the remaining kcal (or how far over); otherwise
  /// what was eaten.
  int get headline {
    final left = remaining;
    if (!isToday || left == null) return eaten;
    return left.abs();
  }

  /// "kcal übrig", "kcal drüber" or "kcal gegessen".
  String unitKey() {
    if (!isToday || goalKcal == null) return 'cal_unit_eaten';
    return isOver ? 'cal_unit_over' : 'cal_unit_left';
  }

  bool get showsOver => isToday && isOver;

  /// "1.360 gegessen · Ziel 2.000", "Noch nichts gegessen · Ziel 2.000" or,
  /// for a past day, "Ziel 2.000 · 50 unter Ziel". Null without a goal.
  String? subline(BuildContext context) {
    final g = goalKcal;
    if (g == null) return null;
    final goalText = context.kcal(g);
    if (!hasEntries) {
      return context.tr('cal_nothing_eaten_goal', params: {'goal': goalText});
    }
    if (isToday) {
      return context.tr('cal_eaten_goal', params: {'eaten': context.kcal(eaten), 'goal': goalText});
    }
    final diff = g - eaten;
    return context.tr(
      diff >= 0 ? 'cal_past_goal_under' : 'cal_past_goal_over',
      params: {'goal': goalText, 'diff': context.kcal(diff.abs())},
    );
  }

  /// The day as one sentence for VoiceOver ("Kalorien heute: 640 von 2.000
  /// übrig, 1.360 gegessen."), followed by the macros.
  String spoken(BuildContext context, {required String title, bool withMacros = true}) {
    final g = goalKcal;
    final String head;
    if (isToday && g != null) {
      head = isOver
          ? context.tr('cal_summary_a11y_over', params: {
              'title': title,
              'over': context.kcal(-remaining!),
              'goal': context.kcal(g),
              'eaten': context.kcal(eaten),
            })
          : context.tr('cal_summary_a11y_left', params: {
              'title': title,
              'left': context.kcal(remaining!),
              'goal': context.kcal(g),
              'eaten': context.kcal(eaten),
            });
    } else {
      head = context.tr('cal_summary_a11y_eaten', params: {'title': title, 'eaten': context.kcal(eaten)});
    }
    if (!withMacros) return head;
    return '$head ${calorieMacrosSpoken(context, totals, goal)}.';
  }
}

/// "kcal drüber" with the warning symbol, or the plain unit.
class _UnitLine extends StatelessWidget {
  const _UnitLine({required this.numbers, required this.style, this.secondary = false});

  final CalorieDayNumbers numbers;
  final AvoTextStyle style;

  /// Plain units in the secondary colour (Home ring).
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final warning = CalorieColors.of(context).warning;
    final over = numbers.showsOver;
    final color = over ? warning : (secondary ? context.colors.secondaryLabel : context.colors.label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (over) ...[
          Icon(CupertinoIcons.exclamationmark_triangle_fill, size: _kOverGlyph, color: warning),
          const SizedBox(width: AvoSpacing.xs),
        ],
        Flexible(child: Text(context.tr(numbers.unitKey()), style: context.text(style, color: color))),
      ],
    );
  }
}

/// The secondary line with the sync mark while rows wait.
class _Subline extends StatelessWidget {
  const _Subline({required this.text, required this.syncing, this.style = AvoTextStyle.subhead});

  final String text;
  final bool syncing;
  final AvoTextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text),
        if (syncing) ...[
          const TextSpan(text: ' '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AvoIcon(AvoIcons.sync, size: _kSyncGlyph, color: colors.secondaryLabel),
          ),
        ],
      ]),
      style: context.text(style, color: colors.secondaryLabel),
    );
  }
}

/// `CaloriesTodaySummary`, large (diary group "Heute", S1 #6): the big
/// number in the large-title size, "kcal übrig" and the goal line on the
/// left, the 120 pt ring on the right (below the text from xxxL on), then
/// the three macro rows. Without a goal: "kcal gegessen", no ring, plain
/// macros.
class CaloriesDiarySummary extends StatelessWidget {
  const CaloriesDiarySummary({super.key, required this.numbers, this.wrapLine});

  final CalorieDayNumbers numbers;

  /// Wraps the number-and-ring line (hidden from VoiceOver itself), for
  /// example in the diary's adjustable day element. The macro rows below
  /// stay their own VoiceOver elements.
  final Widget Function(Widget line)? wrapLine;

  @override
  Widget build(BuildContext context) {
    final warning = CalorieColors.of(context).warning;
    final subline = numbers.subline(context);
    final hasGoal = numbers.goalKcal != null;
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RollingNumber(
          value: numbers.headline,
          style: context.text(
            AvoTextStyle.largeTitle,
            color: numbers.showsOver ? warning : null,
            tabular: true,
          ),
        ),
        _UnitLine(numbers: numbers, style: AvoTextStyle.headline),
        if (subline != null) ...[
          const SizedBox(height: AvoSpacing.xxs),
          _Subline(text: subline, syncing: numbers.syncing),
        ],
      ],
    );
    final category = context.typography.category;
    final stacked = category.index >= ContentSizeCategory.xxxLarge.index;
    final ring = CalorieRing(progress: numbers.progress, size: kCalorieRingDiary);

    final Widget line;
    if (!hasGoal) {
      line = Align(alignment: AlignmentDirectional.centerStart, child: textBlock);
    } else if (stacked) {
      line = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [textBlock, const SizedBox(height: AvoSpacing.m), ring],
      );
    } else {
      line = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kDiaryLineMin),
        child: Row(
          children: [
            Expanded(child: textBlock),
            const SizedBox(width: AvoSpacing.l),
            ring,
          ],
        ),
      );
    }

    final hidden = ExcludeSemantics(child: line);
    return Padding(
      padding: const EdgeInsets.all(AvoSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          wrapLine?.call(hidden) ?? hidden,
          const SizedBox(height: AvoSpacing.l),
          CalorieMacroRows(totals: numbers.totals, goal: numbers.goal),
        ],
      ),
    );
  }
}

/// `CaloriesTodaySummary` as the Home card head (D2-FuerDich §6): kicker
/// "KALORIEN", "Heute", the goal line, then the 112 pt ring with "640 kcal
/// übrig" inside and the macros beside it. From xxxL on the macros go under
/// the ring and the number leaves the ring ("640 kcal übrig" on one line).
/// Decorative for VoiceOver: the card reads one sentence for it.
class CaloriesCardSummary extends StatelessWidget {
  const CaloriesCardSummary({super.key, required this.numbers});

  final CalorieDayNumbers numbers;

  @override
  Widget build(BuildContext context) {
    final warning = CalorieColors.of(context).warning;
    final subline = numbers.subline(context);
    final category = context.typography.category;
    final stacked = category.index >= ContentSizeCategory.xxxLarge.index;
    final numberStyle = context.text(
      stacked ? AvoTextStyle.title3 : AvoTextStyle.title2,
      color: numbers.showsOver ? warning : null,
      weight: FontWeight.w700,
      tabular: true,
    );
    final number = RollingNumber(value: numbers.headline, style: numberStyle);

    final Widget ringAndMacros;
    final macros = CalorieMacroRows(totals: numbers.totals, goal: numbers.goal, gap: _kCardMacroGap);
    if (stacked) {
      ringAndMacros = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CalorieRing(progress: numbers.progress, size: kCalorieRingHome),
          const SizedBox(height: AvoSpacing.m),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AvoSpacing.xs,
            children: [number, _UnitLine(numbers: numbers, style: AvoTextStyle.title3)],
          ),
          const SizedBox(height: AvoSpacing.m),
          macros,
        ],
      );
    } else {
      ringAndMacros = Row(
        children: [
          CalorieRing(
            progress: numbers.progress,
            size: kCalorieRingHome,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                number,
                _UnitLine(numbers: numbers, style: AvoTextStyle.caption1, secondary: true),
              ],
            ),
          ),
          const SizedBox(width: AvoSpacing.l),
          Expanded(child: macros),
        ],
      );
    }

    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const CalorieKicker(),
          Text(context.tr('cal_today'), style: context.text(AvoTextStyle.title3)),
          if (subline != null) _Subline(text: subline, syncing: numbers.syncing, style: AvoTextStyle.footnote),
          const SizedBox(height: AvoSpacing.l),
          ringAndMacros,
        ],
      ),
    );
  }
}

const double _kCardMacroGap = 11; // D2 `.mrow` gap
const double _kKickerTracking = 0.5; // D2 +0.5

/// "KALORIEN" (D2 kicker: 11/13 bold, +0.5 tracking, warning orange).
/// Upper case for display only.
class CalorieKicker extends StatelessWidget {
  const CalorieKicker({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.tr('cal_home_kicker');
    final style = context.text(
      AvoTextStyle.caption2,
      color: CalorieColors.of(context).warning,
      weight: FontWeight.w700,
    );
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Text(
        text.toUpperCase().replaceAll('ß', 'SS'),
        style: style.copyWith(
          letterSpacing: (style.letterSpacing ?? 0) + _kKickerTracking, // D2
        ),
      ),
    );
  }
}
