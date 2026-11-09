import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/widgets/store_badge.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/history_view_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

// D2-FuerDich `.row`: min 64, padding 10 × 16, gap 12, chevron 8 × 14.
const double _kRowMin = 64; // D2
const double _kPadV = 10; // D2
const double _kGap = AvoSpacing.m; // D2 12
const double _kSyncIcon = 10; // D2 sync mark behind the amount
const double _kFailIcon = 15; // D2

/// Which [TripRow] (verlauf-kosten.md V4, V11).
enum TripRowVariant {
  /// The history: list · date · items, debt line, actions.
  full,

  /// Home "Letzte Einkäufe": the date only, no actions.
  compact,
}

/// "Wocheneinkauf · Heute, 18:40" and the VoiceOver date ("heute, 18:40").
({String shown, String spoken}) tripDateTexts(
  BuildContext context,
  DateTime date,
  DateTime now,
) {
  final lang = Localizations.localeOf(context).languageCode;
  final shown = tripDate(
    date,
    lang,
    now,
    today: context.tr('hist_date_today'),
    yesterday: context.tr('hist_date_yesterday'),
  );
  final day = DateTime(date.year, date.month, date.day);
  final recent = DateTime(now.year, now.month, now.day).difference(day).inDays <= 1;
  return (shown: shown, spoken: recent ? shown : spokenDate(date, lang));
}

/// "9 Artikel" / "1 Artikel".
String itemCount(BuildContext context, int n) => n == 1
    ? context.tr('hist_items_one')
    : context.tr('hist_items', params: {'n': '$n'});

/// One trip like a Wallet transaction (V4 `TripRow`): market as title,
/// list · date · items below, the amount right (or nothing), "ca. … gespart"
/// under it with offers. From AX1 on the tile goes and the amount moves
/// under the text.
class TripRow extends ConsumerWidget {
  const TripRow({
    super.key,
    required this.trip,
    required this.onTap,
    this.variant = TripRowVariant.full,
    this.showList = true,
    this.swipeActions = const [],
    this.menuItems = const [],
    this.onRetry,
  });

  final ShoppingHistory trip;
  final VoidCallback onTap;
  final TripRowVariant variant;

  /// Compact rows name the list only when trips come from several lists.
  final bool showList;
  final List<SwipeAction> swipeActions;

  /// Long press menu (and VoiceOver actions).
  final List<AvoMenuEntry> menuItems;

  /// Tap on a "Nicht gespeichert" row.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final now = ref.watch(historyClockProvider)();
    final me = ref.watch(authUserIdProvider);
    final status = ref.watch(
      tripHistoryProvider.select(
        (s) => s.failed.contains(trip.id)
            ? 1
            : (s.sending.contains(trip.id) ? 2 : 0),
      ),
    );
    final failed = status == 1;
    final sending = status == 2;
    final savings = ref.watch(tripSavingsCentsProvider(trip.id));
    final debt = variant == TripRowVariant.full
        ? ref.watch(tripDebtProvider(trip.id))
        : null;

    final store = tripStoreName(trip);
    final title = store ?? trip.listName;
    final date = tripDateTexts(context, trip.completedAt, now);
    final count = itemCount(context, trip.totalItems);
    final byOther = trip.completedBy != null && me != null && trip.completedBy != me;
    final otherName = trip.completedByName?.trim();
    final byLine = byOther
        ? context.tr(
            'hist_trip_by',
            params: {
              'name': otherName == null || otherName.isEmpty
                  ? context.tr('hist_member_unknown')
                  : otherName,
            },
          )
        : null;
    final String sub;
    final String spokenSub;
    if (variant == TripRowVariant.compact) {
      sub = showList ? '${date.shown} · ${trip.listName}' : date.shown;
      spokenSub = showList ? '${date.spoken}, ${trip.listName}' : date.spoken;
    } else {
      final parts = [if (store != null) trip.listName, date.shown, count, ?byLine];
      sub = parts.join(' · ');
      spokenSub = [
        if (store != null) trip.listName,
        date.spoken,
        count,
        ?byLine,
      ].join(', ');
    }
    final cents = trip.totalCostCents;
    final amount = cents == null || cents <= 0 ? null : formatEuroCents(cents, lang);
    final savingsText = savings == null
        ? null
        : context.tr(
            'hist_trip_savings',
            params: {'amount': formatEuroCents(savings, lang)},
          );
    final debtText = debt == null ? null : debtLine(context, debt);

    // VoiceOver: one sentence (§3.10).
    final spoken = [
      title,
      spokenSub,
      if (cents != null && cents > 0) spokenEuroCents(cents, lang),
      if (savings != null)
        context.tr(
          'hist_trip_savings_a11y',
          params: {'amount': spokenEuroCents(savings, lang)},
        ),
      if (debt != null) debtLine(context, debt, spoken: true),
      if (sending) context.tr('hist_row_sending_a11y'),
      if (failed) context.tr('hist_row_not_saved_a11y'),
    ].join(', ');

    final stacked = context.isAccessibilityText;
    final secondary = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text(AvoTextStyle.headline)),
        Text(sub, style: secondary),
        if (debtText != null)
          Text(debtText, style: context.text(AvoTextStyle.subhead)),
      ],
    );
    Widget trailingFor(bool below) => Column(
      crossAxisAlignment: below ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) ...[
          AvoIcon(
            AvoIcons.exclamationmarkCircle,
            size: _kFailIcon,
            color: colors.destructive,
          ),
          Text(
            context.tr('common_not_saved'),
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.destructive,
            ),
          ),
        ] else if (amount != null || sending)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (amount != null)
                Text(
                  amount,
                  style: context.text(AvoTextStyle.headline, tabular: true),
                ),
              if (sending) ...[
                const SizedBox(width: AvoSpacing.xs),
                AvoIcon(
                  AvoIcons.sync,
                  size: _kSyncIcon,
                  color: colors.secondaryLabel,
                ),
              ],
            ],
          ),
        if (savingsText != null && !failed)
          Text(
            savingsText,
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.tint,
              weight: FontWeight.w600,
            ),
          ),
      ],
    );
    final hasTrailing = failed || amount != null || sending || savingsText != null;

    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _kPadV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!stacked) ...[
              StoreBadge(chainId: trip.storeChainId),
              const SizedBox(width: _kGap),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The amount moves under the text when it would take
                  // more than 45 % of the row (measured; large text, 320 pt).
                  final style = context.text(AvoTextStyle.headline, tabular: true);
                  final wide = [?amount, ?savingsText].any((t) {
                    final painter = TextPainter(
                      text: TextSpan(text: t, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout();
                    final w = painter.width;
                    painter.dispose();
                    return w > constraints.maxWidth * 0.45;
                  });
                  final below = stacked || wide;
                  if (below) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        texts,
                        if (hasTrailing) ...[
                          const SizedBox(height: AvoSpacing.xxs),
                          trailingFor(true),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: texts),
                      if (hasTrailing) ...[
                        const SizedBox(width: AvoSpacing.s),
                        trailingFor(false),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: AvoSpacing.s),
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.xs),
              child: AvoIcon(
                AvoIcons.chevronRight,
                size: AvoSpacing.l,
                color: colors.tertiaryLabel,
              ),
            ),
          ],
        ),
      ),
    );

    final tap = failed && onRetry != null ? onRetry! : onTap;
    final actions = <CustomSemanticsAction, VoidCallback>{
      for (final item in menuItems.whereType<AvoMenuItem>())
        CustomSemanticsAction(label: item.label): item.onSelected,
    };
    Widget row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      onLongPress: menuItems.isEmpty
          ? null
          : () => showAvoMenu(context, items: menuItems),
      child: ExcludeSemantics(child: body),
    );
    if (swipeActions.isNotEmpty) {
      row = SwipeActions(
        trailingActions: swipeActions,
        exposeSemantics: false,
        child: row,
      );
    }
    return Semantics(
      container: true,
      button: true,
      label: spoken,
      hint: variant == TripRowVariant.compact
          ? context.tr('hist_open_trip_hint')
          : null,
      onTap: tap,
      customSemanticsActions: actions.isEmpty ? null : actions,
      child: row,
    );
  }
}

/// "Lena schuldet dir 21,40 €", "Du schuldest Lena 11,58 €", "2 schulden dir
/// 34,60 €"; [spoken] reads the amount as words.
String debtLine(BuildContext context, TripDebt debt, {bool spoken = false}) {
  final lang = Localizations.localeOf(context).languageCode;
  final amount = spoken
      ? spokenEuroCents(debt.cents, lang)
      : formatEuroCents(debt.cents, lang);
  final name = (debt.name ?? '').trim().isEmpty
      ? context.tr('hist_member_unknown')
      : debt.name!.trim();
  if (debt.owedToMe && debt.people > 1) {
    return context.tr(
      'hist_trip_owe_you_many',
      params: {'n': '${debt.people}', 'amount': amount},
    );
  }
  return context.tr(
    debt.owedToMe ? 'hist_trip_owes_you' : 'hist_trip_you_owe',
    params: {'name': name, 'amount': amount},
  );
}
