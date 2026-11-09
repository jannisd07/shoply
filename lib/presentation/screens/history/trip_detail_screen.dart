import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/history_actions.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/widgets/savings_line.dart';
import 'package:shoply/presentation/screens/history/widgets/store_badge.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';
import 'package:shoply/presentation/state/history_view_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// D2 detail head: white card radius 26, padding 20 × 16.
const double _kHeadPadV = AvoSpacing.xl; // D2 20
const double _kItemRowMin = 60; // D2 article row
const double _kShareRowMin = 60; // D2
const double _kPillPadV = 3; // D2 offer pill 3 × 8
const double _kPillPadH = AvoSpacing.s; // D2

/// V5 "Einkauf-Detail" (`/history/:tripId`): what was in the trip, and is
/// everything settled (money, buying again)?
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId, this.notYours});

  final String tripId;

  /// Opened from V6 for someone else's trip: "Nur Lena kann den Betrag
  /// ändern." once.
  final String? notYours;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  String? _targetListId;
  final Map<String, bool> _paid = {};
  final Set<String> _failed = {};
  bool _left = false;

  @override
  void initState() {
    super.initState();
    final name = widget.notYours;
    if (name != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AvoToast.show(
          context,
          message: context.tr('hist_amount_not_yours', params: {'name': name}),
        );
      });
    }
  }

  void _leaveGone() {
    if (_left) return;
    _left = true;
    leaveGoneTrip(context);
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
    final local = ref.watch(historyTripProvider(tripId));
    ShoppingHistory? trip = local;
    if (trip == null) {
      final lookup = ref.watch(tripLookupProvider(tripId));
      if (lookup.isLoading) {
        return OffersPage(
          title: context.tr('hist_detail_untitled'),
          largeTitle: false,
          children: const [
            SkeletonSection(rows: 2, withImage: false),
            SizedBox(height: AvoSpacing.section),
            SkeletonSection(rows: 5),
          ],
        );
      }
      trip = lookup.valueOrNull;
      if (trip == null) {
        _leaveGone();
        return ColoredBox(color: context.colors.background);
      }
    }
    return _content(context, trip);
  }

  Widget _content(BuildContext context, ShoppingHistory trip) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final now = ref.watch(historyClockProvider)();
    final me = ref.watch(authUserIdProvider);
    final own = me != null && (trip.completedBy ?? trip.userId) == me;
    final splitOn = ref.watch(moduleEnabledProvider(AppModule.costSplit));
    final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
    final tripList = lists.where((l) => l.id == trip.listId).firstOrNull;
    final target =
        lists.where((l) => l.id == _targetListId).firstOrNull ??
        tripList ??
        lists.firstOrNull;
    final open = target == null
        ? const <ShoppingItemModel>[]
        : (ref.watch(itemsNotifierProvider(target.id)).valueOrNull ??
              const <ShoppingItemModel>[]);
    final openNames = {
      for (final i in open)
        if (!i.isChecked) i.name.trim().toLowerCase(),
    };
    final toAdd = itemsToReadd(trip, open);
    final already = trip.items.length - toAdd.length;
    final savings = ref.watch(tripSavingsCentsProvider(trip.id));
    final offers = ref.watch(historySavingsVisibleProvider(trip.listId ?? ''));
    final splits = splitOn && !isLocalTripId(trip.id)
        ? ref.watch(tripSplitsProvider(trip.id))
        : null;
    final hasSplit = splits?.valueOrNull?.isNotEmpty ?? false;
    final store = tripStoreName(trip);
    final title = trip.listId == null && trip.listName.trim().isEmpty
        ? context.tr('hist_detail_untitled')
        : trip.listName;

    final menu = tripMenu(
      context,
      ref,
      trip,
      hasSplit: hasSplit,
      shared: tripList?.isShared ?? false,
      afterDelete: () {
        if (mounted) Navigator.of(context).maybePop();
      },
    );

    final children = <Widget>[
      _Head(trip: trip, own: own, now: now),
      const SizedBox(height: AvoSpacing.l),
      if (target != null && trip.items.isNotEmpty)
        _ReaddAction(
          listName: target.name,
          lists: [for (final l in lists) (id: l.id, name: l.name)],
          targetId: target.id,
          already: already,
          allOpen: toAdd.isEmpty,
          onPick: (id) => setState(() => _targetListId = id),
          onAdd: () => unawaited(
            readdTrip(
              context,
              ref,
              trip: trip,
              listId: target.id,
              listName: target.name,
            ),
          ),
        ),
      if (splits != null)
        _SplitSection(
          trip: trip,
          splits: splits,
          paid: _paid,
          failed: _failed,
          onPaid: (split, paid) => unawaited(_setPaid(trip, split, paid)),
        ),
      if (savings != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: SectionCaps(context.tr('hist_saved_section')),
        ),
        SavingsLine(cents: savings),
        if (store != null)
          OffersFootnote(
            _offerCount(context, trip, store),
          ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.section),
        child: InsetSection(
          header: context.tr('hist_items_section'),
          headerTrailing: Text(
            '${trip.items.length}',
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          ),
          children: [
            for (final item in trip.items)
              _HistoryItemRow(
                item: item,
                lang: lang,
                offers: offers,
                onList: target != null &&
                        openNames.contains(item.name.trim().toLowerCase())
                    ? target.name
                    : null,
                onReadd: target == null
                    ? null
                    : () => unawaited(
                        readdTrip(
                          context,
                          ref,
                          trip: trip,
                          listId: target.id,
                          listName: target.name,
                          only: [item],
                        ),
                      ),
                otherLists: [
                  for (final l in lists)
                    if (l.id != target?.id) (id: l.id, name: l.name),
                ],
                onReaddTo: (id, name) => unawaited(
                  readdTrip(
                    context,
                    ref,
                    trip: trip,
                    listId: id,
                    listName: name,
                    only: [item],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];

    return OffersPage(
      title: title,
      largeTitle: false,
      onRefresh: () async {
        ref.invalidate(tripSplitsProvider(trip.id));
        await ref.read(tripHistoryProvider.notifier).refresh();
      },
      trailing: [
        if (menu.isNotEmpty)
          AvoMenuButton(items: menu, semanticLabel: context.tr('common_more')),
      ],
      children: children,
    );
  }

  String _offerCount(BuildContext context, ShoppingHistory trip, String store) {
    final n = trip.items.where((i) => i.savingsPerUnit != null).length;
    return n == 1
        ? context.tr('hist_detail_savings_count_one', params: {'store': store})
        : context.tr(
            'hist_detail_savings_count',
            params: {'n': '$n', 'store': store},
          );
  }

  Future<void> _setPaid(
    ShoppingHistory trip,
    ExpenseSplit split,
    bool paid,
  ) async {
    final me = ref.read(authUserIdProvider);
    final name = split.participantName.trim().isEmpty
        ? context.tr('hist_member_unknown')
        : split.participantName;
    final payer = (trip.paidByName ?? '').trim().isEmpty
        ? context.tr('hist_member_unknown')
        : trip.paidByName!;
    setState(() {
      _paid[split.id] = paid;
      _failed.remove(split.id);
    });
    final saved = await ref
        .read(expenseSplitServiceProvider)
        .setPaid(split.id, paid);
    if (!mounted) return;
    if (saved == null) {
      unawaited(AvoHaptics.error());
      setState(() {
        _paid.remove(split.id);
        _failed.add(split.id);
      });
      return;
    }
    ref.invalidate(tripSplitsProvider(trip.id));
    unawaited(ref.read(openSharesProvider.notifier).refresh());
    final mine = split.userId == me;
    AvoToast.show(
      context,
      message: !paid
          ? context.tr('hist_split_reopened_toast', params: {'name': name})
          : (mine
                ? context.tr('hist_split_repaid_toast', params: {'name': payer})
                : context.tr('hist_split_paid_toast', params: {'name': name})),
      actionLabel: context.tr('common_undo'),
      onAction: () => unawaited(_setPaid(trip, split.copyWith(isPaid: paid), !paid)),
    );
  }
}

/// The head card: market, date, who shopped, the amount (V5 2).
class _Head extends ConsumerWidget {
  const _Head({required this.trip, required this.own, required this.now});

  final ShoppingHistory trip;
  final bool own;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final store = tripStoreName(trip);
    final date = '${shortDate(trip.completedAt, lang, now)}, '
        '${clockTime(trip.completedAt, lang)}';
    final other = (trip.completedByName ?? '').trim();
    final by = own
        ? context.tr('hist_detail_by_you')
        : context.tr(
            'hist_detail_by',
            params: {
              'name': other.isEmpty ? context.tr('hist_member_unknown') : other,
            },
          );
    final cents = trip.totalCostCents;
    final hasAmount = cents != null && cents > 0;
    final spoken = [
      store ?? context.tr('hist_store_none'),
      '${spokenDate(trip.completedAt, lang)}, ${clockTime(trip.completedAt, lang)}',
      by,
      if (hasAmount) spokenEuroCents(cents, lang),
    ].join(', ');

    final big = context.text(
      AvoTextStyle.largeTitle,
      weight: FontWeight.w700,
      tabular: true,
    );
    final amount = hasAmount
        ? Text(
            formatEuroCents(cents, lang),
            style: big.copyWith(
              fontSize: (big.fontSize ?? 34).clamp(0, 51).toDouble(), // D2 cap
            ),
          )
        : null;
    final addAmount = !hasAmount && own && !isLocalTripId(trip.id)
        ? AppButton.plain(
            label: context.tr('hist_detail_add_amount'),
            onPressed: () =>
                unawaited(context.push<Object?>(historyAmountLocation(trip.id))),
          )
        : null;
    final stacked =
        context.typography.category.index >= ContentSizeCategory.xxxLarge.index;
    final info = Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!context.isAccessibilityText) ...[
                StoreBadge(chainId: trip.storeChainId),
                const SizedBox(width: AvoSpacing.m),
              ],
              Flexible(
                child: Text(
                  store ?? context.tr('hist_store_none'),
                  style: context.text(
                    AvoTextStyle.title3,
                    weight: FontWeight.w600,
                    color: store == null ? colors.secondaryLabel : colors.label,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AvoSpacing.xs),
          Text(
            date,
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
          const SizedBox(height: AvoSpacing.xxs),
          Row(
            children: [
              ExcludeSemantics(
                child: Avatar(
                  name: own ? '' : other,
                  size: AvatarSize.small,
                  neutral: own,
                ),
              ),
              const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
              Flexible(
                child: Text(
                  by,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final right = amount ?? addAmount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AvoRadii.group),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: _kHeadPadV,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Side by side while both fit (measured), else stacked.
              final fits =
                  !stacked &&
                  right != null &&
                  _amountWidth(context, trip, lang, big) <
                      constraints.maxWidth * 0.45;
              if (right == null) return info;
              if (!fits) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [info, const SizedBox(height: AvoSpacing.s), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: AvoSpacing.s),
                  right,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static double _amountWidth(
    BuildContext context,
    ShoppingHistory trip,
    String lang,
    TextStyle style,
  ) {
    final cents = trip.totalCostCents;
    if (cents == null || cents <= 0) return 120;
    final painter = TextPainter(
      text: TextSpan(text: formatEuroCents(cents, lang), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }
}

/// "Alle wieder auf die Liste" with the target picker and its footnote.
class _ReaddAction extends StatelessWidget {
  const _ReaddAction({
    required this.listName,
    required this.lists,
    required this.targetId,
    required this.already,
    required this.allOpen,
    required this.onPick,
    required this.onAdd,
  });

  final String listName;
  final List<({String id, String name})> lists;
  final String targetId;
  final int already;
  final bool allOpen;
  final ValueChanged<String> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = allOpen
        ? context.tr('hist_readd_all_open', params: {'list': listName})
        : already == 0
        ? context.tr('hist_readd_target', params: {'list': listName})
        : context.tr(
            already == 1 ? 'hist_readd_some_open_one' : 'hist_readd_some_open',
            params: {'list': listName, 'n': '$already'},
          );
    final wide =
        context.typography.category.index >= ContentSizeCategory.xxLarge.index;
    final button = Semantics(
      hint: note,
      child: AppButton.primary(
        label: context.tr('hist_readd'),
        icon: AvoIcon(AvoIcons.cartBadgePlus, color: colors.onTint),
        expand: true,
        onPressed: allOpen ? null : onAdd,
      ),
    );
    final picker = lists.length < 2
        ? null
        : Builder(
            builder: (anchor) => Semantics(
              button: true,
              label: context.tr('hist_readd_pick'),
              value: context.tr('hist_readd_target_a11y', params: {'list': listName}),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(
                  showAvoMenu(
                    anchor,
                    items: [
                      for (final l in lists)
                        AvoMenuItem(
                          label: l.name,
                          checked: l.id == targetId,
                          onSelected: () => onPick(l.id),
                        ),
                    ],
                  ),
                ),
                child: wide
                    ? AppButton.secondary(
                        label: context.tr('hist_readd_pick'),
                        expand: true,
                        onPressed: () {},
                      )
                    : SizedBox.square(
                        dimension: AvoSizes.hitTarget,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.fill,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: AvoIcon(AvoIcons.chevronDown)),
                        ),
                      ),
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wide) ...[
            button,
            if (picker != null) ...[
              const SizedBox(height: AvoSpacing.s),
              picker,
            ],
          ] else
            Row(
              children: [
                Expanded(child: button),
                if (picker != null) ...[
                  const SizedBox(width: AvoSpacing.s),
                  picker,
                ],
              ],
            ),
          OffersFootnote(note, side: AvoSpacing.l),
        ],
      ),
    );
  }
}

/// "KOSTEN TEILEN": one row per share except the payer's, or the start row.
class _SplitSection extends ConsumerWidget {
  const _SplitSection({
    required this.trip,
    required this.splits,
    required this.paid,
    required this.failed,
    required this.onPaid,
  });

  final ShoppingHistory trip;
  final AsyncValue<List<ExpenseSplit>> splits;
  final Map<String, bool> paid;
  final Set<String> failed;
  final void Function(ExpenseSplit split, bool paid) onPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final now = ref.watch(historyClockProvider)();
    final me = ref.watch(authUserIdProvider);
    void openEditor() => unawaited(
      openWithCostSplit(context, ref, historySplitLocation(trip.id)),
    );
    final header = context.tr('hist_split_section');

    final value = splits.valueOrNull;
    final Widget body;
    if (value == null && splits.hasError) {
      body = InsetSection(
        header: header,
        children: [
          Padding(
            padding: const EdgeInsets.all(AvoSpacing.m),
            child: StatusRow(
              kind: StatusKind.failed,
              text: context.tr('hist_split_load_failed'),
              actionLabel: context.tr('common_try_again'),
              onAction: () => ref.invalidate(tripSplitsProvider(trip.id)),
            ),
          ),
        ],
      );
    } else if (value == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCaps(header),
          const SkeletonSection(rows: 2, withImage: false),
        ],
      );
    } else if (value.isEmpty) {
      final members = trip.listId == null
          ? const <SplitMember>[]
          : (ref.watch(splitMembersProvider(trip.listId!)) ?? const []);
      final others = [
        for (final m in members)
          if (m.userId != me)
            m.name.isEmpty ? context.tr('hist_member_unknown') : m.name,
      ];
      final sub = others.isEmpty
          ? context.tr('hist_split_start_names_only')
          : context.tr(
              'hist_split_start_with',
              params: {'names': others.join(', ')},
            );
      body = InsetSection(
        children: [
          Semantics(
            button: true,
            label: '${context.tr('hist_split_section')}, $sub',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openEditor,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kShareRowMin),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvoSpacing.l,
                    vertical: AvoSpacing.m - AvoSpacing.xxs,
                  ),
                  child: Row(
                    children: [
                      AvoIcon(AvoIcons.eurosignCircle, color: colors.tint),
                      const SizedBox(width: AvoSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('hist_split_section'),
                              style: context.text(
                                AvoTextStyle.body,
                                color: colors.tint,
                              ),
                            ),
                            Text(
                              sub,
                              style: context.text(
                                AvoTextStyle.subhead,
                                color: colors.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      final payerId = trip.paidByUserId ?? trip.completedBy ?? trip.userId;
      final iPaid = payerId == me;
      final rows = [
        for (final s in value)
          if (s.userId == null || s.userId != payerId) s,
      ];
      final total = trip.totalCostCents ?? value.fold<int>(0, (a, s) => a + s.amountCents);
      final payer = iPaid
          ? context.tr('hist_payer_you')
          : ((trip.paidByName ?? '').trim().isEmpty
                ? context.tr('hist_member_unknown')
                : trip.paidByName!);
      final equal = value.every((s) => s.splitMode == 'equal');
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InsetSection(
            header: header,
            headerTrailing: AppButton.plain(
              label: context.tr('hist_split_edit'),
              onPressed: openEditor,
            ),
            separatorIndent: context.isAccessibilityText ? AvoSpacing.l : 60,
            footer: context.tr(
              equal ? 'hist_split_footer_equal' : 'hist_split_footer_custom',
              params: {'payer': payer, 'amount': formatEuroCents(total, lang)},
            ),
            children: [
              for (final s in rows)
                _ShareRow(
                  split: s,
                  isPaid: paid[s.id] ?? s.isPaid,
                  failed: failed.contains(s.id),
                  // You mark others' shares paid; your own as paid back.
                  action: (paid[s.id] ?? s.isPaid)
                      ? null
                      : (iPaid
                            ? context.tr('hist_split_mark_paid')
                            : (s.userId == me
                                  ? context.tr('hist_split_mark_repaid')
                                  : null)),
                  remindText: iPaid && !(paid[s.id] ?? s.isPaid)
                      ? _remindText(context, trip, s, lang, now)
                      : null,
                  now: now,
                  onPaid: (p) => onPaid(s, p),
                ),
            ],
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AvoSpacing.section),
      child: body,
    );
  }

  static String _remindText(
    BuildContext context,
    ShoppingHistory trip,
    ExpenseSplit s,
    String lang,
    DateTime now,
  ) {
    final store = tripStoreName(trip);
    final params = {
      'amount': formatEuroCents(s.amountCents, lang),
      'list': trip.listName,
      'date': dayMonth(trip.completedAt, lang, now),
      'store': ?store,
    };
    return context.tr(
      store == null ? 'hist_remind_text_no_store' : 'hist_remind_text',
      params: params,
    );
  }
}

/// A share in V5: avatar, name, "offen" / "bezahlt am 8. Nov.", amount and
/// "Bezahlt" / "Zurückgezahlt"; swipe "Erinnern" on open shares owed to you.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.split,
    required this.isPaid,
    required this.failed,
    required this.action,
    required this.remindText,
    required this.now,
    required this.onPaid,
  });

  final ExpenseSplit split;
  final bool isPaid;
  final bool failed;
  final String? action;
  final String? remindText;
  final DateTime now;
  final ValueChanged<bool> onPaid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final name = split.participantName.trim().isEmpty
        ? context.tr('hist_member_unknown')
        : split.participantName;
    final paidAt = split.paidAt;
    final status = isPaid
        ? (paidAt == null
              ? context.tr('hist_split_paid_plain')
              : context.tr(
                  'hist_split_paid_on',
                  params: {'date': dayMonth(paidAt, lang, now)},
                ))
        : context.tr('hist_split_open');
    final sub = [
      status,
      if (split.userId == null) context.tr('hist_split_no_account'),
    ].join(' · ');
    final amount = formatEuroCents(split.amountCents, lang);
    final remind = remindText;
    final actions = <CustomSemanticsActionEntry>[
      if (action != null) (label: action!, run: () => onPaid(true)),
      if (remind != null)
        (label: context.tr('hist_remind'), run: () => unawaited(Share.share(remind))),
      if (isPaid)
        (label: context.tr('hist_split_reopen'), run: () => onPaid(false)),
    ];
    final stacked = context.isAccessibilityText;
    final trailing = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AvoSpacing.xs,
      children: [
        Text(amount, style: context.text(AvoTextStyle.body, tabular: true)),
        if (action != null)
          AppButton.plain(label: action!, onPressed: () => onPaid(true)),
      ],
    );
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kShareRowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.xs + AvoSpacing.xxs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (!stacked) ...[
                  ExcludeSemantics(
                    child: Avatar(name: name, size: AvatarSize.size28),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Semantics(
                    container: true,
                    label: '$name, ${spokenEuroCents(split.amountCents, lang)}, $sub',
                    customSemanticsActions: {
                      for (final a in actions)
                        CustomSemanticsAction(label: a.label): a.run,
                    },
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name, style: context.text(AvoTextStyle.body)),
                        Text(
                          sub,
                          style: context.text(
                            AvoTextStyle.subhead,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!stacked) trailing,
              ],
            ),
            if (stacked) Align(alignment: AlignmentDirectional.centerStart, child: trailing),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: AvoSpacing.xs),
                child: StatusRow(
                  kind: StatusKind.failed,
                  text: context.tr('hist_row_not_saved'),
                  actionLabel: context.tr('common_try_again'),
                  onAction: () => onPaid(!isPaid),
                ),
              ),
          ],
        ),
      ),
    );
    row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: isPaid
          ? () => unawaited(
              showAvoMenu(
                context,
                items: [
                  AvoMenuItem(
                    label: context.tr('hist_split_reopen'),
                    onSelected: () => onPaid(false),
                  ),
                ],
              ),
            )
          : null,
      child: row,
    );
    if (remind != null) {
      row = SwipeActions(
        exposeSemantics: false,
        trailingActions: [
          SwipeAction(
            label: context.tr('hist_remind'),
            icon: AvoIcons.share,
            onPressed: () => unawaited(Share.share(remind)),
          ),
        ],
        child: row,
      );
    }
    return row;
  }
}

typedef CustomSemanticsActionEntry = ({String label, VoidCallback run});

/// An article of the trip (D2 article row without a check circle).
class _HistoryItemRow extends StatelessWidget {
  const _HistoryItemRow({
    required this.item,
    required this.lang,
    required this.offers,
    required this.onList,
    required this.onReadd,
    required this.otherLists,
    required this.onReaddTo,
  });

  final ShoppingHistoryItem item;
  final String lang;
  final bool offers;

  /// The target list's name when the item is open there now.
  final String? onList;
  final VoidCallback? onReadd;
  final List<({String id, String name})> otherLists;
  final void Function(String id, String name) onReaddTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final q = item.quantity;
    final qty = [
      q == q.roundToDouble() ? q.round().toString() : q.toString().replaceAll('.', lang == 'de' ? ',' : '.'),
      ?item.unit,
    ].join(' ');
    final price = item.price;
    final old = item.priceOldValue;
    final pill = offers && price != null && item.savingsPerUnit != null
        ? formatEuroCents((price * 100).round(), lang)
        : null;
    final was = offers && old != null && item.savingsPerUnit != null
        ? context.tr(
            'hist_item_was',
            params: {'old': formatEuroCents((old * 100).round(), lang)},
          )
        : null;
    final on = onList == null
        ? null
        : context.tr('hist_item_on_list', params: {'list': onList!});
    final spoken = [
      item.name,
      qty,
      if (pill != null)
        context.tr(
          'hist_item_bought_offer_a11y',
          params: {'amount': spokenEuroCents((price! * 100).round(), lang)},
        ),
      ?was,
      ?on,
    ].join(', ');
    final secondary = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
    );
    final menu = <AvoMenuEntry>[
      if (onReadd != null)
        AvoMenuItem(label: context.tr('hist_item_readd'), onSelected: onReadd!),
      for (final l in otherLists)
        AvoMenuItem(
          label: context.tr('hist_item_readd_to', params: {'list': l.name}),
          onSelected: () => onReaddTo(l.id, l.name),
        ),
    ];
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kItemRowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.s,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.name, style: context.text(AvoTextStyle.body)),
                  Text(qty, style: secondary),
                  if (was != null) Text(was, style: secondary),
                  if (on != null) Text(on, style: secondary),
                ],
              ),
            ),
            if (pill != null) ...[
              const SizedBox(width: AvoSpacing.s),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tintSoft,
                  borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kPillPadH,
                    vertical: _kPillPadV,
                  ),
                  child: Text(
                    pill,
                    style: context.text(
                      AvoTextStyle.caption2,
                      color: colors.tint,
                      weight: FontWeight.w600,
                      tabular: true,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    row = Semantics(
      container: true,
      label: spoken,
      customSemanticsActions: {
        for (final m in menu.whereType<AvoMenuItem>())
          CustomSemanticsAction(label: m.label): m.onSelected,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: menu.isEmpty
            ? null
            : () => unawaited(showAvoMenu(context, items: menu)),
        child: row,
      ),
    );
    if (onReadd == null) return row;
    return SwipeActions(
      exposeSemantics: false,
      leadingActions: [
        SwipeAction(
          label: context.tr('hist_item_readd'),
          icon: AvoIcons.cartBadgePlus,
          onPressed: onReadd!,
        ),
      ],
      child: row,
    );
  }
}
