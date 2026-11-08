import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Bar height of the week chart (Konzept calories week: 120).
const double _kChartHeight = 120;
const double _kHeaderMin = 52; // D2 row
const double _kChevron = 14; // D2

/// The diary's group "Diese Woche" (S1 #9): a heading button to the week
/// screen, "Ø 1.925 kcal · 4 von 4 Tagen im Ziel", and seven bars Monday to
/// Sunday with the goal as a dashed line. Unlogged and future days have no
/// bar. The chart turns into a list from AX1 on (A's chart does that).
class CalorieWeekSection extends ConsumerWidget {
  const CalorieWeekSection({
    super.key,
    required this.dateKey,
    required this.todayKey,
    required this.goalKcal,
    required this.onOpenWeek,
  });

  /// A day of the week to show (the diary's day).
  final String dateKey;
  final String todayKey;
  final int? goalKcal;
  final VoidCallback onOpenWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = calorieWeekStartKey(dateKey);
    final async = ref.watch(calorieWeekProvider(weekStart));
    final header = _WeekHeader(onTap: onOpenWeek);

    final Widget body = async.when(
      loading: () => const SizedBox(height: _kChartHeight),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
        child: StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_week_error'),
          actionLabel: context.tr('retry'),
          onAction: () => ref.invalidate(calorieWeekServerProvider(weekStart)),
        ),
      ),
      data: (week) => _WeekBody(week: week, goalKcal: goalKcal),
    );

    return InsetSection(children: [header, body]);
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = context.tr('cal_week_this');
    return Semantics(
      container: true,
      button: true,
      header: true,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kHeaderMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
            child: Row(
              children: [
                Expanded(child: Text(title, style: context.text(AvoTextStyle.headline))),
                const SizedBox(width: AvoSpacing.s),
                AvoIcon(AvoIcons.chevronRight, size: _kChevron, color: context.colors.secondaryLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekBody extends StatelessWidget {
  const _WeekBody({required this.week, required this.goalKcal});

  final CalorieWeek week;
  final int? goalKcal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avg = week.averageKcal;
    final goal = goalKcal;
    final logged = week.completedLoggedDays;
    final hasAny = week.days.any((d) => d.kcal != null);

    final String? line = avg == null
        ? null
        : goal == null
            ? context.tr('cal_week_line_no_goal', params: {'avg': context.kcal(avg)})
            : context.tr('cal_week_line', params: {
                'avg': context.kcal(avg),
                'n': '${week.daysInGoal(goal)}',
                'm': '$logged',
              });
    final summary = avg == null
        ? context.tr('cal_week_empty')
        : goal == null
            ? context.tr('cal_week_a11y_no_goal', params: {'avg': context.kcal(avg), 'n': '$logged'})
            : context.tr('cal_week_a11y', params: {
                'avg': context.kcal(avg),
                'n': '$logged',
                'goal': context.kcal(goal),
              });
    final tag = Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
    final dayName = DateFormat.EEEE(
      Intl.verifiedLocale(tag, DateFormat.localeExists, onFailure: (_) => 'en'),
    );
    final todayIndex = week.days.indexWhere((d) => d.isToday);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AvoSpacing.l, 0, AvoSpacing.l, AvoSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (line != null) ...[
            Text(line, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
            const SizedBox(height: AvoSpacing.m),
          ],
          AvoBarChart(
            entries: [
              for (final d in week.days)
                AvoBarEntry(
                  label: context.weekdayShort(parseCalorieDayKey(d.dateKey)),
                  value: d.kcal?.toDouble(),
                  semanticLabel: dayName.format(parseCalorieDayKey(d.dateKey)),
                  semanticValue: d.kcal == null
                      ? context.tr('cal_week_not_logged')
                      : context.tr('cal_kcal_value', params: {'kcal': context.kcal(d.kcal!)}),
                ),
            ],
            formatValue: (v) => context.kcal(v),
            semanticSummary: summary,
            highlightIndex: todayIndex < 0 ? null : todayIndex,
            tintAllBars: true,
            goal: goal?.toDouble(),
            showValues: false,
            maxBarHeight: _kChartHeight,
            emptyText: hasAny ? null : context.tr('cal_week_empty'),
          ),
        ],
      ),
    );
  }
}
