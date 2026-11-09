import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/history/history_actions.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/widgets/month_review.dart';
import 'package:shoply/presentation/screens/history/widgets/trip_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/state/history_view_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// After this long without any answer the first load shows its error.
const Duration historyFirstLoadTimeout = Duration(seconds: 10);

/// Start loading the next page this far before the end (V4 7).
const double _kLoadAhead = 600;

/// "Tipp: Gib beim Abschluss den Betrag ein …" was closed (per account).
String historyAmountTipKey(String? uid) => 'hist_tip_amount_closed_v1_${uid ?? ''}';

/// V4 "Verlauf" (`/history?list=`): the month as one number with its six
/// months, then every trip like a Wallet transaction, grouped by month.
/// Local first: the cached history shows in the first frame; a skeleton
/// only on the very first open without one.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.listId, this.tripGone = false});

  /// `?list=`: only this list's trips.
  final String? listId;

  /// Opened for an unknown trip: "Dieser Einkauf wurde gelöscht." once.
  final bool tripGone;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _listId;
  int? _selected;
  MonthSeries? _series;
  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _listId = widget.listId;
    _timer = Timer(historyFirstLoadTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
    if (widget.tripGone) _sayTripGone();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // V4 was already below the gone trip: same state, new `?gone=1`.
    if (widget.tripGone && !oldWidget.tripGone) _sayTripGone();
  }

  void _sayTripGone() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AvoToast.show(context, message: context.tr('hist_trip_gone'));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(tripHistoryProvider.notifier).refresh(),
      ref.read(openSharesProvider.notifier).refresh(),
    ]);
  }

  void _setFilter(String? listId) => setState(() {
    _listId = listId;
    _selected = null;
  });

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < _kLoadAhead) {
      unawaited(ref.read(tripHistoryProvider.notifier).loadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripHistoryProvider);
    final now = ref.watch(historyClockProvider)();
    final offline = ref.watch(isOfflineProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final all = state.trips;
    final listId = _listId;
    final trips = tripsOfList(all, listId);
    final listName = listId == null
        ? null
        : (all.where((t) => t.listId == listId).firstOrNull?.listName ??
              ref
                  .watch(listsNotifierProvider)
                  .valueOrNull
                  ?.where((l) => l.id == listId)
                  .firstOrNull
                  ?.name ??
              '');

    final title = context.tr('hist_title');
    final filterButton = all.isEmpty
        ? null
        : Builder(
            builder: (context) => GlassIconButton(
              icon: AvoIcon(
                listId == null ? AvoIcons.filterCircle : AvoIcons.filterCircleFill,
              ),
              semanticLabel: context.tr('hist_filter_a11y'),
              onPressed: () => unawaited(_openFilter(context, all)),
            ),
          );

    Widget page(List<Widget> children) => NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: OffersPage(
        title: title,
        trailing: [?filterButton],
        onRefresh: _refresh,
        children: children,
      ),
    );

    // First open without any local state.
    if (all.isEmpty && !state.synced) {
      if (offline) {
        return page([_Lead(context.tr('hist_offline_empty'))]);
      }
      if (state.error != null || _timedOut) {
        return page([
          _ErrorState(onRetry: () => unawaited(_refresh())),
        ]);
      }
      return page(const [_LoadingState()]);
    }
    if (all.isEmpty) {
      return page([
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.xxl),
          child: EmptyState(
            pose: AvoPose.waving,
            title: context.tr('hist_empty_title'),
            message: context.tr('hist_empty_body'),
            actionLabel: context.tr('hist_to_lists'),
            onAction: () => context.go(RoutePaths.lists),
          ),
        ),
      ]);
    }

    final months = sixMonths(trips, now);
    final series =
        _series ??= chartShowsSpending(sixMonths(all, now))
            ? MonthSeries.spending
            : MonthSeries.trips;
    final selected = (_selected ?? months.length - 1).clamp(0, months.length - 1);
    final selectedMonth = months[selected].month;
    final monthTrips = tripsInMonth(
      trips,
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
    final savings = savingsOfTrips(
      ref.watch(historySavingsVisibleProvider(listId ?? '')),
      monthTrips,
    );
    final weekday = usualWeekday(trips, now);

    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    final uid = ref.read(tripHistoryProvider.notifier).userId;
    final tipClosed =
        prefs == null || (prefs.getBool(historyAmountTipKey(uid)) ?? false);
    final showTip =
        !tipClosed &&
        all.length >= 2 &&
        !all.any((t) => (t.totalCostCents ?? 0) > 0);

    final children = <Widget>[
      if (listName != null) _FilterLine(name: listName, onAll: () => _setFilter(null)),
      if (offline)
        _Padded(StatusRow(
          kind: StatusKind.offline,
          text: context.tr('hist_status_offline'),
        ))
      else if (state.error != null)
        _Padded(StatusRow(
          kind: StatusKind.failed,
          text: context.tr('hist_refresh_failed'),
          actionLabel: context.tr('common_try_again'),
          onAction: () => unawaited(_refresh()),
        )),
      const SizedBox(height: AvoSpacing.m),
      MonthReview(
        months: months,
        selected: selected,
        onSelected: (i) => setState(() => _selected = i),
        series: series,
        now: now,
        savingsCents: savings,
        weekday: weekday,
      ),
      if (showTip)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            AvoSpacing.l,
            AvoSpacing.screen,
            0,
          ),
          child: HintRow(
            text: context.tr('hist_tip_amount'),
            leading: AvoIcon(
              AvoIcons.lightbulb,
              color: context.colors.secondaryLabel,
            ),
            onDismiss: () {
              unawaited(prefs.setBool(historyAmountTipKey(uid), true));
              setState(() {});
            },
          ),
        ),
      if (trips.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AvoSpacing.l,
                  AvoSpacing.l,
                  AvoSpacing.l,
                  0,
                ),
                child: Text(
                  context.tr(
                    'hist_filter_empty',
                    params: {'list': listName ?? ''},
                  ),
                  style: context.text(AvoTextStyle.body),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.plain(
                  label: context.tr('hist_filter_all'),
                  onPressed: () => _setFilter(null),
                ),
              ),
            ],
          ),
        )
      else
        ..._monthSections(context, trips, lang, now),
      if (trips.isNotEmpty && !state.hasMore)
        OffersFootnote(context.tr('hist_list_end'), top: AvoSpacing.l),
    ];
    return page(children);
  }

  List<Widget> _monthSections(
    BuildContext context,
    List<ShoppingHistory> trips,
    String lang,
    DateTime now,
  ) {
    final groups = <DateTime, List<ShoppingHistory>>{};
    for (final t in trips) {
      groups
          .putIfAbsent(
            DateTime(t.completedAt.year, t.completedAt.month),
            () => [],
          )
          .add(t);
    }
    return [
      for (final entry in groups.entries)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                label: context.tr(
                  entry.value.length == 1
                      ? 'hist_month_head_a11y_one'
                      : 'hist_month_head_a11y',
                  params: {
                    'month': monthName(entry.key, lang, now: now),
                    'n': '${entry.value.length}',
                  },
                ),
                excludeSemantics: true,
                child: SectionCaps(
                  monthName(entry.key, lang, now: now),
                  trailing: Text(
                    '${entry.value.length}',
                    style: context.text(
                      AvoTextStyle.footnote,
                      color: context.colors.secondaryLabel,
                      tabular: true,
                    ),
                  ),
                ),
              ),
              InsetSection(
                separatorIndent: 68, // D2 trenner ab 68 pt
                children: [
                  for (final t in entry.value) _HistoryTripRow(trip: t),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _openFilter(BuildContext anchor, List<ShoppingHistory> all) async {
    final names = <String, String>{};
    for (final t in all) {
      final id = t.listId;
      if (id != null) names.putIfAbsent(id, () => t.listName);
    }
    await showAvoMenu(
      anchor,
      items: [
        AvoMenuItem(
          label: context.tr('hist_filter_all'),
          checked: _listId == null,
          onSelected: () => _setFilter(null),
        ),
        const AvoMenuDivider(),
        for (final e in names.entries)
          AvoMenuItem(
            label: e.value,
            checked: _listId == e.key,
            onSelected: () => _setFilter(e.key),
          ),
      ],
    );
  }
}

/// One row of V4 with swipe (own trips: "Löschen") and the long-press menu.
class _HistoryTripRow extends ConsumerWidget {
  const _HistoryTripRow({required this.trip});

  final ShoppingHistory trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(tripOpenSharesProvider(trip.id));
    final hasSplit = shares.isNotEmpty;
    final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
    final list = lists.where((l) => l.id == trip.listId).firstOrNull;
    final shared = list?.isShared ?? false;
    final own = isOwnTrip(ref, trip);
    void delete() => unawaited(
      confirmAndDeleteTrip(context, ref, trip, shared: shared, hasSplit: hasSplit),
    );
    return TripRow(
      trip: trip,
      onTap: () => unawaited(context.push<Object?>(historyTripLocation(trip.id))),
      onRetry: () => unawaited(ref.read(tripHistoryProvider.notifier).retry(trip.id)),
      swipeActions: [
        if (own)
          SwipeAction(
            label: context.tr('hist_menu_delete'),
            icon: AvoIcons.trash,
            destructive: true,
            onPressed: delete,
          ),
      ],
      menuItems: tripMenu(
        context,
        ref,
        trip,
        hasSplit: hasSplit,
        shared: shared,
        onReadd: list == null
            ? null
            : () => unawaited(
                readdTrip(context, ref, trip: trip, listId: list.id, listName: list.name),
              ),
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AvoSpacing.screen,
      AvoSpacing.m,
      AvoSpacing.screen,
      0,
    ),
    child: child,
  );
}

/// "Nur Wocheneinkauf" with "Alle" (V4 3).
class _FilterLine extends StatelessWidget {
  const _FilterLine({required this.name, required this.onAll});

  final String name;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AvoSpacing.s,
      children: [
        Text(
          context.tr('hist_filter_active', params: {'list': name}),
          style: context.text(
            AvoTextStyle.subhead,
            color: context.colors.secondaryLabel,
          ),
        ),
        AppButton.plain(label: context.tr('common_all'), onPressed: onAll),
      ],
    ),
  );
}

class _Lead extends StatelessWidget {
  const _Lead(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => OffersLead(text, top: AvoSpacing.l);
}

/// The first load: the card as a quiet tone, then five rows.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AvoSpacing.m),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonSection(
          rows: 3,
          withImage: false,
          loadingLabel: context.tr('hist_loading'),
        ),
        const SizedBox(height: AvoSpacing.section),
        const ExcludeSemantics(child: SkeletonSection(rows: 5)),
      ],
    ),
  );
}

/// "Deine Einkäufe konnten nicht geladen werden." without a figure.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AvoSpacing.xxl),
    child: EmptyState(
      icon: AvoIcon(
        AvoIcons.exclamationmarkCircle,
        size: 48, // D2 48 Light
        color: context.colors.secondaryLabel,
      ),
      title: context.tr('hist_load_failed'),
      actionLabel: context.tr('common_try_again'),
      onAction: onRetry,
    ),
  );
}
