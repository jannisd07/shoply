import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';

// D2-FuerDich §4 month card: radius 26, padding 16, 16 between the parts.
const double _kCardPad = AvoSpacing.l; // D2
const double _kPartGap = AvoSpacing.l; // D2
const double _kStatDivider = AvoSizes.hairline; // D2 0.5
const double _kTagIcon = 20; // D2
// The bar geometry of AvoBarChart (48 wide, gaps at least 8), to find the
// month under the finger.
const double _kBarWidth = 48; // D2
const double _kMinBarGap = AvoSpacing.s;

/// What the chart shows (K12-05).
enum MonthSeries { spending, trips }

/// The six bars of V4 and V10 on A's [AvoBarChart], with a selected month.
/// Tapping or dragging across the bars picks a month (selection haptic per
/// new month); VoiceOver adjusts it with swipes up and down (an adjustable
/// element, never a slider). Months without a value have no bar and cannot
/// be picked.
class SpendingBars extends StatelessWidget {
  const SpendingBars({
    super.key,
    required this.months,
    required this.series,
    required this.selected,
    this.onSelected,
    this.wholeEuros = false,
  });

  final List<MonthSummary> months;
  final MonthSeries series;
  final int selected;

  /// Null: no selection (Home V10 highlights the current month).
  final ValueChanged<int>? onSelected;

  /// "212 €" instead of "212,40 €" (Home, D2).
  final bool wholeEuros;

  double? _value(MonthSummary m) => switch (series) {
    MonthSeries.spending => m.hasAmounts ? m.spendCents / 100 : null,
    MonthSeries.trips => m.trips > 0 ? m.trips.toDouble() : null,
  };

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    String format(double v) => switch (series) {
      MonthSeries.spending =>
        wholeEuros
            ? formatEuroCents((v.round()) * 100, lang).replaceAll(
                RegExp(r'[,.]00'),
                '',
              )
            : formatEuroCents((v * 100).round(), lang),
      MonthSeries.trips => '${v.round()}',
    };
    String spokenValue(MonthSummary m) {
      final v = _value(m);
      if (v == null) return context.tr('hist_bar_no_amount');
      return switch (series) {
        MonthSeries.spending => spokenEuroCents(
          wholeEuros ? v.round() * 100 : (v * 100).round(),
          lang,
        ),
        MonthSeries.trips => context.tr(
          'hist_bar_trips',
          params: {'n': '${v.round()}'},
        ),
      };
    }

    String spokenMonth(int i) {
      final m = months[i];
      final name = monthName(m.month, lang);
      return i == months.length - 1
          ? context.tr('hist_month_running', params: {'month': name})
          : name;
    }

    final entries = [
      for (var i = 0; i < months.length; i++)
        AvoBarEntry(
          label: monthAxis(months[i].month, lang),
          value: _value(months[i]),
          semanticLabel: spokenMonth(i),
          semanticValue: spokenValue(months[i]),
        ),
    ];
    final summary = [
      context.tr(
        series == MonthSeries.spending
            ? 'hist_month_spend_label'
            : 'hist_month_trips_label',
      ),
      for (var i = 0; i < months.length; i++)
        '${spokenMonth(i)} ${spokenValue(months[i])}',
    ].join('. ');
    final chart = AvoBarChart(
      entries: entries,
      formatValue: format,
      semanticSummary: summary,
      highlightIndex: selected,
      missingText: '',
    );
    final pick = onSelected;
    if (pick == null) return chart;

    void choose(int i) {
      if (i == selected || i < 0 || i >= months.length) return;
      if (_value(months[i]) == null) return;
      unawaited(AvoHaptics.selection());
      pick(i);
    }

    int next(int step) {
      var i = selected + step;
      while (i >= 0 && i < months.length && _value(months[i]) == null) {
        i += step;
      }
      return i;
    }

    final up = next(1);
    final down = next(-1);
    return Semantics(
      container: true,
      label: summary,
      value: '${spokenMonth(selected)}, ${spokenValue(months[selected])}',
      increasedValue: up < months.length
          ? '${spokenMonth(up)}, ${spokenValue(months[up])}'
          : null,
      decreasedValue: down >= 0
          ? '${spokenMonth(down)}, ${spokenValue(months[down])}'
          : null,
      onIncrease: up < months.length ? () => choose(up) : null,
      onDecrease: down >= 0 ? () => choose(down) : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final n = months.length;
            final bar = math.max(
              0.0,
              math.min(_kBarWidth, (width - (n - 1) * _kMinBarGap) / n),
            );
            final gap = n > 1 ? (width - n * bar) / (n - 1) : 0.0;
            int indexAt(double x) =>
                ((x + gap / 2) / (bar + gap)).floor().clamp(0, n - 1);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => choose(indexAt(d.localPosition.dx)),
              onHorizontalDragUpdate: (d) => choose(indexAt(d.localPosition.dx)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                child: chart,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Two or three numbers side by side (D2-FuerDich §3 `StatStrip`), as rows
/// from xxLarge on (label left, value right).
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats, this.icons});

  /// (value, label) pairs.
  final List<({String value, String label})> stats;

  /// Optional symbols above the values (V9).
  final List<AvoIconData>? icons;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows =
        context.typography.category.index >= ContentSizeCategory.xxLarge.index;
    final valueStyle = context.text(
      AvoTextStyle.title3,
      weight: FontWeight.w700,
      tabular: true,
    );
    final labelStyle = context.text(
      AvoTextStyle.footnote,
      color: colors.secondaryLabel,
    );
    final spoken = [for (final s in stats) '${s.label} ${s.value}'].join('. ');
    if (rows) {
      return Semantics(
        container: true,
        label: spoken,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in stats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AvoSpacing.xxs),
                child: context.isAccessibilityText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label, style: labelStyle),
                          Text(s.value, style: valueStyle),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(s.label, style: labelStyle)),
                          const SizedBox(width: AvoSpacing.s),
                          Text(s.value, style: valueStyle),
                        ],
                      ),
              ),
          ],
        ),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: _kStatDivider,
            margin: const EdgeInsets.symmetric(horizontal: AvoSpacing.s),
            color: colors.separator,
          ),
        );
      }
      final icon = icons == null || i >= icons!.length ? null : icons![i];
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AvoIcon(icon, color: colors.secondaryLabel),
                const SizedBox(height: AvoSpacing.s),
              ],
              Text(stats[i].value, style: valueStyle),
              Text(stats[i].label, style: labelStyle),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// "Ca. 9,80 € durch Angebote gespart, laut Händler" inside a card: `tag`
/// in `tint` and the sentence (§5 row 3).
class SavingsSentence extends StatelessWidget {
  const SavingsSentence({super.key, required this.cents, this.iconSize = _kTagIcon});

  final int cents;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final text = context.tr(
      'hist_savings_sentence',
      params: {'amount': formatEuroCents(cents, lang)},
    );
    final spoken = context.tr(
      'hist_savings_sentence_a11y',
      params: {'amount': spokenEuroCents(cents, lang)},
    );
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvoIcon(AvoIcons.tag, size: iconSize, color: context.colors.tint),
          const SizedBox(width: AvoSpacing.s),
          Expanded(
            child: Text(text, style: context.text(AvoTextStyle.subhead)),
          ),
        ],
      ),
    );
  }
}

/// V4's month card: the selected month as one number, its coverage and
/// comparison, the bars, the strip, savings and the usual weekday.
class MonthReview extends StatelessWidget {
  const MonthReview({
    super.key,
    required this.months,
    required this.selected,
    required this.onSelected,
    required this.series,
    required this.now,
    this.savingsCents,
    this.weekday,
  });

  final List<MonthSummary> months;
  final int selected;
  final ValueChanged<int> onSelected;
  final MonthSeries series;
  final DateTime now;

  /// Rounded savings of the selected month, or null.
  final int? savingsCents;

  /// 1 = Monday; the "meist samstags" line.
  final int? weekday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final m = months[selected];
    final running = selected == months.length - 1;
    final name = monthName(m.month, lang, now: now);
    final spend = series == MonthSeries.spending;
    final monthLine = running
        ? context.tr('hist_month_running', params: {'month': name})
        : name;
    final coverage = spend && m.trips > 0 && !m.fullyCovered
        ? context.tr(
            'hist_month_coverage',
            params: {'n': '${m.tripsWithAmount}', 'm': '${m.trips}'},
          )
        : null;
    String? comparison;
    int? diff;
    if (spend && !running && selected > 0) {
      diff = monthDifference(m, months[selected - 1]);
      final prev = monthName(months[selected - 1].month, lang);
      if (diff != null) {
        final amount = formatEuroCents(diff.abs(), lang);
        comparison = diff.abs() < 100
            ? context.tr('hist_month_same', params: {'prev': prev})
            : context.tr(
                diff < 0 ? 'hist_month_less' : 'hist_month_more',
                params: {'amount': amount, 'prev': prev},
              );
      }
    }
    final twoMonths = months.where((x) => x.trips > 0).length >= 2;
    final stats = <({String value, String label})>[
      if (spend) ...[
        (value: '${m.trips}', label: context.tr('hist_stat_trips')),
        (value: '${m.items}', label: context.tr('hist_stat_items')),
      ] else ...[
        if (m.hasAmounts)
          (
            value: formatEuroCents(m.spendCents, lang),
            label: context.tr(
              'hist_stat_spend_partial',
              params: {'n': '${m.tripsWithAmount}', 'm': '${m.trips}'},
            ),
          ),
        (value: '${m.items}', label: context.tr('hist_stat_items')),
      ],
    ];
    final spokenNumber = spend
        ? spokenEuroCents(m.spendCents, lang)
        : '${m.trips}';
    final headline = context.tr(
      spend ? 'hist_month_spend_label' : 'hist_month_trips_label',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AvoRadii.group),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_kCardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                label: [
                  headline,
                  '$monthLine: $spokenNumber',
                  ?coverage,
                ].join('. '),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      style: context.text(
                        AvoTextStyle.subhead,
                        color: colors.secondaryLabel,
                      ),
                    ),
                    _BigNumber(
                      cents: spend ? m.spendCents : null,
                      count: spend ? null : m.trips,
                    ),
                    Text(monthLine, style: context.text(AvoTextStyle.subhead)),
                    if (coverage != null)
                      Text(
                        coverage,
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: colors.secondaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
              if (comparison != null)
                Text.rich(
                  _comparisonSpan(context, comparison, diff!, lang),
                  style: context.text(
                    AvoTextStyle.footnote,
                    color: colors.secondaryLabel,
                  ),
                ),
              const SizedBox(height: _kPartGap),
              if (twoMonths)
                SpendingBars(
                  months: months,
                  series: series,
                  selected: selected,
                  onSelected: onSelected,
                )
              else
                Text(
                  context.tr('hist_chart_first'),
                  style: context.text(AvoTextStyle.subhead),
                ),
              const SizedBox(height: _kPartGap),
              StatStrip(stats: stats),
              if (savingsCents != null) ...[
                const SizedBox(height: AvoSpacing.m),
                SavingsSentence(cents: savingsCents!),
              ],
              if (weekday != null) ...[
                const SizedBox(height: AvoSpacing.m),
                Text(
                  context.tr(
                    'hist_weekday_line',
                    params: {'weekday': context.tr('hist_weekday_$weekday')},
                  ),
                  style: context.text(AvoTextStyle.subhead),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The amount in the comparison is 600, in `tint` when less (never red).
  static InlineSpan _comparisonSpan(
    BuildContext context,
    String text,
    int diff,
    String lang,
  ) {
    final amount = formatEuroCents(diff.abs(), lang);
    final at = diff.abs() < 100 ? -1 : text.indexOf(amount);
    if (at < 0) return TextSpan(text: text);
    final colors = context.colors;
    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, at)),
        TextSpan(
          text: amount,
          style: TextStyle(
            color: diff < 0 ? colors.tint : colors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: text.substring(at + amount.length)),
      ],
    );
  }
}

/// `numberXL` (34/41 bold tabular, at most 51 pt) that rolls.
class _BigNumber extends StatelessWidget {
  const _BigNumber({this.cents, this.count});

  final int? cents;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final style = context.text(
      AvoTextStyle.largeTitle,
      weight: FontWeight.w700,
      tabular: true,
    );
    final capped = style.copyWith(
      fontSize: math.min(style.fontSize ?? 34, 51), // D2 numberXL cap
    );
    final c = cents;
    if (c == null) {
      return RollingNumber(value: count ?? 0, style: capped);
    }
    // RollingNumber rolls the digits; the currency sign stays put. One
    // line that scales down instead of wrapping (V4 numberXL, at most 51).
    final text = formatEuroCents(c, lang);
    final de = lang == 'de';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!de) Text('€', style: capped),
          RollingNumber(
            value: c / 100,
            fractionDigits: 2,
            locale: de ? 'de_DE' : 'en_IE',
            style: capped,
          ),
          if (de) Text(text.substring(text.length - 2), style: capped),
        ],
      ),
    );
  }
}
