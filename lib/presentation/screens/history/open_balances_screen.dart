import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/widgets/trip_row.dart'
    show tripDateTexts;
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

const double _kRowMin = 64; // D2
const double _kPadV = 10; // D2
const String _kDoneOpenKey = 'hist_balances_done_open_v1';

/// V8 "Offene Beträge" (`/splits`): who owes whom, one row per share (trip
/// × person), never netted. "Bezahlt" moves a row to "Erledigt" at once,
/// with undo.
class OpenBalancesScreen extends ConsumerStatefulWidget {
  const OpenBalancesScreen({super.key, this.showDone = false});

  /// `?done=1`: "Erledigt" unfolded.
  final bool showDone;

  @override
  ConsumerState<OpenBalancesScreen> createState() => _OpenBalancesScreenState();
}

class _OpenBalancesScreenState extends ConsumerState<OpenBalancesScreen> {
  bool? _doneOpen;

  Future<void> _refresh() => ref.read(openSharesProvider.notifier).refresh();

  Future<void> _setPaid(OpenShare share, bool paid, {bool toast = true}) async {
    final me = ref.read(authUserIdProvider);
    final owedToMe = me != null && share.isOwedTo(me);
    final name = _person(context, share, owedToMe: owedToMe);
    final ok = await ref.read(openSharesProvider.notifier).setPaid(share.splitId, paid);
    if (!mounted) return;
    if (!ok) {
      unawaited(AvoHaptics.error());
      return;
    }
    if (!toast) return;
    final message = !paid
        ? context.tr('hist_split_reopened_toast', params: {'name': name})
        : (owedToMe
              ? context.tr('hist_split_paid_toast', params: {'name': name})
              : context.tr('hist_split_repaid_toast', params: {'name': name}));
    AvoToast.show(
      context,
      message: message,
      actionLabel: context.tr('common_undo'),
      onAction: () => unawaited(_setPaid(share, !paid, toast: false)),
    );
    final view = View.maybeOf(context);
    if (view != null) {
      unawaited(
        SemanticsService.sendAnnouncement(view, message, Directionality.of(context)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(openSharesProvider);
    final me = ref.watch(authUserIdProvider);
    final offline = ref.watch(isOfflineProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    final doneOpen = _doneOpen ?? (widget.showDone || (prefs?.getBool(_kDoneOpenKey) ?? false));
    final title = context.tr('hist_balances_title');

    Widget page(List<Widget> children) => OffersPage(
      title: title,
      onRefresh: _refresh,
      children: children,
    );

    final shares = state.shares;
    if (shares.isEmpty && !state.synced) {
      if (state.error != null) {
        return page([
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xxl),
            child: EmptyState(
              icon: AvoIcon(
                AvoIcons.exclamationmarkCircle,
                size: 48, // D2 48 Light
                color: context.colors.secondaryLabel,
              ),
              title: context.tr('hist_balances_load_failed'),
              actionLabel: context.tr('common_try_again'),
              onAction: () => unawaited(_refresh()),
            ),
          ),
        ]);
      }
      return page([
        const SizedBox(height: AvoSpacing.m),
        SkeletonSection(rows: 3, loadingLabel: context.tr('hist_loading')),
      ]);
    }

    final owed = [
      for (final s in shares)
        if (me != null && !s.isPaid && s.isOwedTo(me)) s,
    ];
    final owe = [
      for (final s in shares)
        if (me != null && !s.isPaid && s.isOwedBy(me)) s,
    ];
    final done = [
      for (final s in shares)
        if (me != null && s.isPaid && (s.isOwedTo(me) || s.isOwedBy(me))) s,
    ];
    if (owed.isEmpty && owe.isEmpty && done.isEmpty) {
      return page([
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.xxl),
          child: EmptyState(
            icon: AvoIcon(
              AvoIcons.checkmarkCircle,
              size: 48, // D2 48 Light
              color: context.colors.secondaryLabel,
            ),
            title: context.tr('hist_balances_all_settled'),
            message: context.tr('hist_balances_empty_body'),
            actionLabel: context.tr('hist_to_history'),
            onAction: () => unawaited(context.push<Object?>(historyLocation())),
          ),
        ),
      ]);
    }

    int sum(List<OpenShare> l) => l.fold(0, (a, s) => a + s.amountCents);
    Widget section(String header, List<OpenShare> rows, {required bool owedToMe}) {
      final total = sum(rows);
      return Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              label: '$header, ${spokenEuroCents(total, lang)}',
              excludeSemantics: true,
              child: SectionCaps(
                header,
                trailing: Text(
                  formatEuroCents(total, lang),
                  style: context.text(
                    AvoTextStyle.footnote,
                    color: context.colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ),
            ),
            InsetSection(
              separatorIndent: context.isAccessibilityText ? AvoSpacing.l : 68, // D2
              children: [
                for (final s in rows)
                  _BalanceRow(
                    share: s,
                    owedToMe: owedToMe,
                    failed: state.failed.contains(s.splitId),
                    onPaid: (p) => unawaited(_setPaid(s, p)),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final children = <Widget>[
      if (offline)
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.m, AvoSpacing.screen, 0),
          child: StatusRow(kind: StatusKind.offline, text: context.tr('common_offline')),
        )
      else if (state.error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.m, AvoSpacing.screen, 0),
          child: StatusRow(
            kind: StatusKind.failed,
            text: context.tr('hist_balances_refresh_failed'),
            actionLabel: context.tr('common_try_again'),
            onAction: () => unawaited(_refresh()),
          ),
        ),
      if (owed.isEmpty && owe.isEmpty)
        OffersLead(context.tr('hist_balances_all_settled'), style: AvoTextStyle.body, top: AvoSpacing.l),
      if (owed.isNotEmpty) section(context.tr('hist_balances_owed_to_you'), owed, owedToMe: true),
      if (owe.isNotEmpty) section(context.tr('hist_balances_you_owe'), owe, owedToMe: false),
      if (done.isNotEmpty) ...[
        const SizedBox(height: AvoSpacing.section),
        Semantics(
          button: true,
          expanded: doneOpen,
          label: context.tr(
            done.length == 1 ? 'hist_balances_done_a11y_one' : 'hist_balances_done_a11y',
            params: {'n': '${done.length}'},
          ),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _doneOpen = !doneOpen);
              unawaited(prefs?.setBool(_kDoneOpenKey, !doneOpen));
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.xxxl),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('hist_balances_done', params: {'n': '${done.length}'}),
                        style: context.text(AvoTextStyle.body),
                      ),
                    ),
                    AnimatedRotation(
                      turns: doneOpen ? 0.5 : 0,
                      duration: context.reduceMotion ? Duration.zero : AvoMotion.fadeReduced,
                      child: AvoIcon(AvoIcons.chevronDown, color: context.colors.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (doneOpen)
          InsetSection(
            separatorIndent: context.isAccessibilityText ? AvoSpacing.l : 68, // D2
            children: [
              for (final s in done)
                _BalanceRow(
                  share: s,
                  owedToMe: me != null && s.isOwedTo(me),
                  failed: state.failed.contains(s.splitId),
                  onPaid: (p) => unawaited(_setPaid(s, p)),
                ),
            ],
          ),
      ],
    ];
    return page(children);
  }
}

/// The other person of a share: who owes me, or whom I owe.
String _person(BuildContext context, OpenShare s, {required bool owedToMe}) {
  final n = (owedToMe ? s.participantName : s.paidByName ?? '').trim();
  return n.isEmpty ? context.tr('hist_member_unknown') : n;
}

/// One share (V8 `BalanceRow`).
class _BalanceRow extends ConsumerWidget {
  const _BalanceRow({
    required this.share,
    required this.owedToMe,
    required this.failed,
    required this.onPaid,
  });

  final OpenShare share;
  final bool owedToMe;
  final bool failed;
  final ValueChanged<bool> onPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final now = ref.watch(historyClockProvider)();
    final name = _person(context, share, owedToMe: owedToMe);
    final store = share.storeChainId == null
        ? null
        : StoreChainDirectory.byId(share.storeChainId!)?.displayName;
    final date = tripDateTexts(context, share.completedAt, now);
    final nameOnly = owedToMe ? share.userId == null : share.paidByUserId == null;
    final paidAt = share.paidAt;
    final sub = [
      share.listName,
      ?store,
      if (share.isPaid && paidAt != null)
        context.tr('hist_split_paid_on', params: {'date': dayMonth(paidAt, lang, now)})
      else
        date.shown,
      if (nameOnly) context.tr('hist_split_no_account'),
    ].join(' · ');
    final amount = formatEuroCents(share.amountCents, lang);
    final spokenAmount = spokenEuroCents(share.amountCents, lang);
    final sentence = owedToMe
        ? context.tr('hist_trip_owes_you', params: {'name': name, 'amount': spokenAmount})
        : context.tr('hist_trip_you_owe', params: {'name': name, 'amount': spokenAmount});
    final spoken = [sentence, share.listName, ?store, date.spoken].join(', ');
    final action = share.isPaid
        ? null
        : context.tr(owedToMe ? 'hist_split_mark_paid' : 'hist_split_mark_repaid');
    void view() => unawaited(context.push<Object?>(historyTripLocation(share.historyId)));
    final remind = owedToMe && !share.isPaid
        ? context.tr(
            store == null ? 'hist_remind_text_no_store' : 'hist_remind_text',
            params: {
              'amount': amount,
              'list': share.listName,
              'date': dayMonth(share.completedAt, lang, now),
              'store': ?store,
            },
          )
        : null;
    final menu = <AvoMenuEntry>[
      if (action != null)
        AvoMenuItem(
          label: context.tr(owedToMe ? 'hist_split_mark_paid_long' : 'hist_split_mark_repaid'),
          onSelected: () => onPaid(true),
        ),
      if (share.isPaid)
        AvoMenuItem(label: context.tr('hist_split_reopen'), onSelected: () => onPaid(false)),
      if (remind != null)
        AvoMenuItem(
          label: context.tr('hist_remind'),
          icon: AvoIcons.share,
          onSelected: () => unawaited(Share.share(remind)),
        ),
      AvoMenuItem(label: context.tr('hist_balance_view_trip'), onSelected: view),
    ];
    final stacked = context.isAccessibilityText;
    final trailing = Column(
      crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(amount, style: context.text(AvoTextStyle.headline, tabular: true)),
        if (action != null)
          AppButton.plain(label: action, onPressed: () => onPaid(true)),
      ],
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: context.text(AvoTextStyle.headline)),
        Text(sub, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
      ],
    );
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kPadV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!stacked) ...[
                  ExcludeSemantics(child: Avatar(name: name, size: AvatarSize.size40)),
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    label: spoken,
                    onTap: view,
                    customSemanticsActions: {
                      for (final m in menu.whereType<AvoMenuItem>())
                        CustomSemanticsAction(label: m.label): m.onSelected,
                    },
                    excludeSemantics: true,
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [texts, trailing],
                          )
                        : texts,
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: AvoSpacing.s), trailing],
              ],
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: AvoSpacing.xs),
                child: StatusRow(
                  kind: StatusKind.failed,
                  text: context.tr('hist_row_not_saved'),
                  actionLabel: context.tr('common_try_again'),
                  onAction: () => onPaid(!share.isPaid),
                ),
              ),
          ],
        ),
      ),
    );
    row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: view,
      onLongPress: () => unawaited(showAvoMenu(context, items: menu)),
      child: row,
    );
    if (action != null) {
      row = SwipeActions(
        exposeSemantics: false,
        trailingActions: [SwipeAction(label: action, icon: AvoIcons.check, onPressed: () => onPaid(true))],
        child: row,
      );
    }
    return row;
  }
}
