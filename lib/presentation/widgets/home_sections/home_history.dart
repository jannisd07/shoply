import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/history_actions.dart'
    show openWithCostSplit;
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/widgets/month_review.dart';
import 'package:shoply/presentation/screens/history/widgets/trip_row.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/history_view_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// Home sections of the history (verlauf-kosten.md V9–V12, D2-FuerDich §3,
// §4, §9). Synchronous from the local snapshot; no figure (money).

const double _kCardPadV = AvoSpacing.xl; // D2 20
const double _kCardPadH = AvoSpacing.l; // D2 16
const double _kShadowAlpha = 0.04; // D2 0 1px 2px rgba(0,0,0,.04)
const double _kShadowBlur = 2; // D2
const Offset _kShadowOffset = Offset(0, 1); // D2
const double _kTagIcon = 18; // D2

/// V9 "Dein November": true once the current month has a trip.
final homeMonthHasContentProvider = Provider<bool>(
  (ref) => ref.watch(homeHistorySnapshotProvider.select((s) => s.thisMonth.trips > 0)),
);

/// V10 "Ausgaben im Vergleich": true when at least 3 of the last 6 months
/// have amounts.
final homeSpendingHasContentProvider = Provider<bool>(
  (ref) => ref.watch(
    homeHistorySnapshotProvider.select((s) => chartShowsSpending(s.months)),
  ),
);

/// V11 "Letzte Einkäufe": true from one saved trip on.
final homeRecentTripsHasContentProvider = Provider<bool>(
  (ref) => ref.watch(homeHistorySnapshotProvider.select((s) => s.recent.isNotEmpty)),
);

/// V12: one hint about Kosten teilen (module on, something to say).
final homeSplitHintHasContentProvider = Provider<bool>(
  (ref) => ref.watch(homeSplitHintProvider) != null,
);

void _openHistory(BuildContext context) =>
    unawaited(context.push<Object?>(historyLocation()));

/// V9 "Dein November": spending, trips and items of this month, savings as
/// a sentence; the whole card opens the history.
class HomeMonthCard extends ConsumerWidget {
  const HomeMonthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeMonthHasContentProvider)) return const SizedBox.shrink();
    final snap = ref.watch(homeHistorySnapshotProvider);
    final m = snap.thisMonth;
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final month = monthName(m.month, lang);
    final title = context.tr('hist_home_month_title', params: {'month': month});
    final sub = context.tr(
      'hist_home_month_sub',
      params: {'date': shortDate(snap.now, lang, snap.now)},
    );
    final spendLabel = m.fullyCovered
        ? context.tr('hist_stat_spend')
        : context.tr(
            'hist_stat_spend_partial',
            params: {'n': '${m.tripsWithAmount}', 'm': '${m.trips}'},
          );
    final stats = [
      if (m.hasAmounts)
        (value: formatEuroCents(m.spendCents, lang), label: spendLabel),
      (value: '${m.trips}', label: context.tr('hist_stat_trips')),
      (value: '${m.items}', label: context.tr('hist_stat_items')),
    ];
    final icons = [
      if (m.hasAmounts) AvoIcons.cart,
      AvoIcons.bag,
      AvoIcons.listBullet,
    ];
    final savings = snap.monthSavingsCents;
    final spoken = [
      context.tr('hist_home_month_a11y', params: {'month': month}),
      if (m.hasAmounts)
        m.fullyCovered
            ? '${context.tr('hist_stat_spend')} ${spokenEuroCents(m.spendCents, lang)}'
            : context.tr(
                'hist_home_spend_partial_a11y',
                params: {
                  'amount': spokenEuroCents(m.spendCents, lang),
                  'n': '${m.tripsWithAmount}',
                  'm': '${m.trips}',
                },
              ),
      '${m.trips} ${context.tr('hist_stat_trips')}',
      '${m.items} ${context.tr('hist_stat_items')}',
      if (savings != null)
        context.tr(
          'hist_savings_sentence_a11y',
          params: {'amount': spokenEuroCents(savings, lang)},
        ),
    ].join(', ');
    return Semantics(
      button: true,
      label: spoken,
      hint: context.tr('hist_opens_history'),
      excludeSemantics: true,
      onTap: () => _openHistory(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openHistory(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // D2 gradient #EEF7EF → #FFFFFF (A-V4 asks for a token); the
            // tinted surface stands in, opaque with Reduce Transparency.
            color: colors.surface,
            gradient: context.reduceTransparency
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, 0.7],
                    colors: [
                      Color.alphaBlend(colors.tintSoft.withValues(alpha: 0.6), colors.surface),
                      colors.surface,
                    ],
                  ),
            borderRadius: BorderRadius.circular(AvoRadii.group),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: _kShadowAlpha),
                blurRadius: _kShadowBlur,
                offset: _kShadowOffset,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kCardPadH, vertical: _kCardPadV),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text(AvoTextStyle.title2, weight: FontWeight.w700)),
                Text(sub, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                const SizedBox(height: AvoSpacing.l),
                StatStrip(stats: stats, icons: icons),
                if (savings != null) ...[
                  const SizedBox(height: AvoSpacing.m),
                  SavingsSentence(cents: savings, iconSize: _kTagIcon),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// V10 "Ausgaben im Vergleich": six months, the current one highlighted
/// with "bisher"; a comparison only for the last finished month when both
/// it and the month before are well covered, in euros.
class HomeSpendingComparison extends ConsumerWidget {
  const HomeSpendingComparison({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeSpendingHasContentProvider)) return const SizedBox.shrink();
    final snap = ref.watch(homeHistorySnapshotProvider);
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final months = snap.months;
    final last = months[months.length - 2];
    final prev = months[months.length - 3];
    final diff = monthDifference(last, prev);
    String? line;
    if (diff != null) {
      final params = {
        'month': monthName(last.month, lang),
        'prev': monthName(prev.month, lang),
        'amount': formatEuroCents(diff.abs(), lang),
      };
      line = diff.abs() < 100
          ? context.tr('hist_home_spend_same', params: params)
          : context.tr(diff < 0 ? 'hist_home_spend_less' : 'hist_home_spend_more', params: params);
    }
    final title = context.tr('hist_home_spend_title');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AvoRadii.group),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AvoSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              header: true,
              label: title,
              hint: context.tr('hist_opens_history'),
              excludeSemantics: true,
              onTap: () => _openHistory(context),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openHistory(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: context.text(AvoTextStyle.headline)),
                      ),
                      AvoIcon(AvoIcons.chevronRight, size: AvoSpacing.l, color: colors.tertiaryLabel),
                    ],
                  ),
                ),
              ),
            ),
            if (line != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (diff! < -99) ...[
                    ExcludeSemantics(
                      child: AvoIcon(AvoIcons.arrowDown, size: 14, color: colors.tint), // D2
                    ),
                    const SizedBox(width: AvoSpacing.xxs),
                  ],
                  Expanded(
                    child: Text(
                      line,
                      style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AvoSpacing.l),
            SpendingBars(
              months: months,
              series: MonthSeries.spending,
              selected: months.length - 1,
              wholeEuros: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// V11 "Letzte Einkäufe": the newest three trips; "Alle anzeigen" opens the
/// history, a row its detail.
class HomeRecentTrips extends ConsumerWidget {
  const HomeRecentTrips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeRecentTripsHasContentProvider)) return const SizedBox.shrink();
    final snap = ref.watch(homeHistorySnapshotProvider);
    final colors = context.colors;
    final anySavings = snap.recent.any((t) => ref.watch(tripSavingsCentsProvider(t.id)) != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.tr('hist_home_recent_title'),
                style: context.text(AvoTextStyle.title3, weight: FontWeight.w600),
              ),
            ),
            AppButton.plain(
              label: context.tr('hist_home_recent_all'),
              onPressed: () => _openHistory(context),
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.s),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AvoRadii.group),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AvoRadii.group),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < snap.recent.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: context.isAccessibilityText ? AvoSpacing.l : 68, // D2
                      ),
                      child: Container(height: AvoSizes.hairline, color: colors.separator),
                    ),
                  TripRow(
                    trip: snap.recent[i],
                    variant: TripRowVariant.compact,
                    showList: snap.multipleLists,
                    onTap: () => unawaited(
                      context.push<Object?>(historyTripLocation(snap.recent[i].id)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (anySavings)
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.l, AvoSpacing.s, AvoSpacing.l, 0),
            child: Text(
              context.tr('hist_home_recent_note'),
              style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
            ),
          ),
      ],
    );
  }
}

/// V12: exactly one hint about Kosten teilen (open balances first, then
/// "Einkauf teilen"). Never a list of debts, never a figure.
class HomeSplitHint extends ConsumerWidget {
  const HomeSplitHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = ref.watch(homeSplitHintProvider);
    if (hint == null) return const SizedBox.shrink();
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(authUserIdProvider);
    final leading = AvoIcon(AvoIcons.eurosignCircle, size: 20, color: colors.secondaryLabel); // D2
    void dismiss() => unawaited(dismissSplitHint(ref, hint));
    switch (hint) {
      case OneBalanceHint(:final share, :final owedToMe):
        final name = (owedToMe ? share.participantName : share.paidByName ?? '').trim();
        final who = name.isEmpty ? context.tr('hist_member_unknown') : name;
        final amount = formatEuroCents(share.amountCents, lang);
        Future<void> pay() async {
          final ok = await ref.read(openSharesProvider.notifier).setPaid(share.splitId, true);
          if (!context.mounted) return;
          if (!ok) {
            unawaited(AvoHaptics.error());
            AvoToast.show(context, message: context.tr('hist_row_not_saved'));
            return;
          }
          AvoToast.show(
            context,
            message: owedToMe
                ? context.tr('hist_split_paid_toast', params: {'name': who})
                : context.tr('hist_split_repaid_toast', params: {'name': who}),
            actionLabel: context.tr('common_undo'),
            onAction: () => unawaited(
              ref.read(openSharesProvider.notifier).setPaid(share.splitId, false),
            ),
          );
        }

        return HintRow(
          leading: leading,
          text: context.tr(
            owedToMe ? 'hist_hint_owes_you' : 'hist_hint_you_owe',
            params: {'name': who, 'amount': amount, 'list': share.listName},
          ),
          actionLabel: context.tr(owedToMe ? 'hist_hint_mark_paid' : 'hist_hint_mark_repaid'),
          onTap: () => unawaited(pay()),
          onDismiss: dismiss,
          dismissLabel: context.tr('hist_hint_dismiss'),
        );
      case ManyBalancesHint(:final summary):
        final params = {
          'n': '${summary.openCount}',
          'in': formatEuroCents(summary.owedToMeCents, lang),
          'out': formatEuroCents(summary.iOweCents, lang),
        };
        final key = summary.owedToMeCents > 0 && summary.iOweCents > 0
            ? 'hist_hint_balances'
            : (summary.owedToMeCents > 0 ? 'hist_hint_balances_in' : 'hist_hint_balances_out');
        return HintRow(
          leading: leading,
          text: context.tr(key, params: params),
          actionLabel: context.tr('hist_hint_view'),
          onTap: () => unawaited(context.push<Object?>(splitsLocation())),
          onDismiss: dismiss,
          dismissLabel: context.tr('hist_hint_dismiss'),
        );
      case ShareTripHint(:final trip):
        final members = trip.listId == null ? null : ref.watch(splitMembersProvider(trip.listId!));
        final others = [
          for (final m in members ?? const <SplitMember>[])
            if (m.userId != me) m.name.isEmpty ? context.tr('hist_member_unknown') : m.name,
        ];
        if (others.isEmpty) return const SizedBox.shrink();
        final names = others.join(', ');
        final cents = trip.totalCostCents;
        final now = ref.watch(historyClockProvider)();
        final day = relativeDay(
          trip.completedAt,
          lang,
          now,
          today: context.tr('hist_day_today'),
          yesterday: context.tr('hist_day_yesterday'),
        );
        return HintRow(
          leading: leading,
          text: cents == null || cents <= 0
              ? context.tr(
                  'hist_hint_share_no_amount',
                  params: {'list': trip.listName, 'day': day, 'names': names},
                )
              : context.tr(
                  'hist_hint_share',
                  params: {
                    'list': trip.listName,
                    'names': names,
                    'amount': formatEuroCents(cents, lang),
                  },
                ),
          actionLabel: context.tr('hist_hint_share_action'),
          onTap: () => unawaited(
            openWithCostSplit(context, ref, historySplitLocation(trip.id)),
          ),
          onDismiss: dismiss,
          dismissLabel: context.tr('hist_hint_dismiss'),
        );
    }
  }
}
