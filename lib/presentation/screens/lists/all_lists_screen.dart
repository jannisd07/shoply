import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/history_format.dart'
    show monthName;
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/lists/list_settings_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_body.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_new_list.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_join_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_list_dialog.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

/// Space between the toolbar row and the large title (D2-Home: toolbar ends
/// at 98, the title starts at 109).
const double _kTitleGap = 11; // D2

/// Root of the "Listen" tab (D2-Home, Konzept 11 §7): large title "Listen"
/// with "3 Listen · 11 offen", the toolbar with "Mehr" (Liste beitreten) and
/// the tinted "Neue Liste", "Schnell wieder hinzufügen", the big card of the
/// pinned or last used list, "Andere Listen" and "Geteilt mit mir".
///
/// Everything comes from the local state at once; pull to refresh reloads.
/// The rows are sorted when the page opens and never jump while realtime
/// changes arrive. Sets Avo's screen context to `lists` whenever the tab is
/// visible.
class AllListsScreen extends ConsumerStatefulWidget {
  const AllListsScreen({super.key});

  @override
  ConsumerState<AllListsScreen> createState() => _AllListsScreenState();
}

class _AllListsScreenState extends ConsumerState<AllListsScreen> {
  /// "Last changed" per list when the page was opened (sort order).
  Map<String, DateTime>? _snapshot;
  bool _visible = false;
  String _query = '';

  /// Tiles tapped and not undone yet; hidden until the source catches up.
  final Set<String> _added = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab root stays mounted: TickerMode is off while another tab is
    // shown, and the route is not current while a list is pushed on top.
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _becameVisible());
    }
    _visible = visible;
  }

  void _becameVisible() {
    if (!mounted) return;
    ref.read(avoScreenContextProvider.notifier).state = const AvoScreenContext(
      screen: 'lists',
    );
    final lists = ref.read(allListsSourceProvider).valueOrNull;
    if (lists != null) setState(() => _snapshot = listOrderSnapshot(lists));
  }

  Future<void> _refresh() async {
    setState(_added.clear);
    refreshAllListsQuickAdd(ref);
    final lists = ref.read(allListsSourceProvider).valueOrNull ?? const [];
    for (final l in lists) {
      if (l.isShared) ref.invalidate(listMembersProvider(l.id));
    }
    try {
      await ref.read(listActionsProvider).refreshLists();
    } catch (e) {
      debugPrint('⚠️ [ALL_LISTS] Refresh failed: $e');
    }
    if (!mounted) return;
    final fresh = ref.read(allListsSourceProvider).valueOrNull;
    if (fresh != null) setState(() => _snapshot = listOrderSnapshot(fresh));
  }

  void _open(ShoppingListModel list) {
    context.push(RoutePaths.list(list.id, name: list.name));
  }

  Future<void> _create() async {
    final list = await openNewListEditor(context);
    if (list == null || !mounted) return;
    final path = Uri(
      path: '${RoutePaths.lists}/${list.id}',
      queryParameters: {'name': list.name, 'focus': 'add'},
    ).toString();
    context.push(path);
  }

  Future<void> _join() async {
    final list = await openJoinListScreen(context);
    if (list == null || !mounted) return;
    AvoToast.show(
      context,
      message: context.tr('list_ov_joined', params: {'name': list.name}),
    );
    _open(list);
  }

  Future<void> _openInfo(ShoppingListModel list, {bool focusName = false}) =>
      pushFullScreenEditor<void>(
        context,
        (_) => ListSettingsScreen(
          listId: list.id,
          listName: list.name,
          ownerId: list.ownerId,
          focusName: focusName,
        ),
        cover: false,
      );

  Future<void> _delete(ShoppingListModel list) async {
    final total = list.itemCount ?? 0;
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_ov_delete_title', params: {'name': list.name}),
      message: total > 0
          ? context.tr('list_ov_delete_message_items', params: {'n': '$total'})
          : context.tr('list_ov_delete_message'),
      confirmLabel: context.tr('list_ov_delete'),
    );
    if (!confirmed || !mounted) return;
    final toastContext = context;
    final message = context.tr('list_ov_deleted', params: {'name': list.name});
    try {
      await ref.read(listActionsProvider).deleteList(list.id);
      if (ref.read(pinnedListProvider).listId == list.id) {
        unawaited(ref.read(pinnedListProvider.notifier).pin(null));
      }
      if (toastContext.mounted) {
        AvoToast.show(toastContext, message: message);
      }
    } catch (e) {
      debugPrint('❌ [ALL_LISTS] Failed to delete list: $e');
      _failed();
    }
  }

  Future<void> _leave(ShoppingListModel list) async {
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_ov_leave_title', params: {'name': list.name}),
      message: context.tr('list_ov_leave_message'),
      confirmLabel: context.tr('list_ov_leave'),
    );
    if (!confirmed || !mounted) return;
    final toastContext = context;
    final message = context.tr('list_ov_left', params: {'name': list.name});
    try {
      await ref.read(listActionsProvider).leaveList(list.id);
      if (ref.read(pinnedListProvider).listId == list.id) {
        unawaited(ref.read(pinnedListProvider.notifier).pin(null));
      }
      if (toastContext.mounted) {
        AvoToast.show(toastContext, message: message);
      }
    } catch (e) {
      debugPrint('❌ [ALL_LISTS] Failed to leave list: $e');
      _failed();
    }
  }

  void _failed() {
    AvoHaptics.error();
    if (!mounted) return;
    AvoToast.show(context, message: context.tr('action_failed'));
  }

  void _menu(BuildContext anchor, ShoppingListModel list) {
    final userId = ref.read(authUserIdProvider);
    final offline = ref.read(isOfflineProvider);
    final pinned = ref.read(pinnedListProvider).listId == list.id;
    final owner = userId != null && list.ownerId == userId;
    final needsConnection = offline
        ? context.tr('common_needs_connection')
        : null;
    showAvoMenu(
      anchor,
      semanticLabel: list.name,
      items: [
        AvoMenuItem(
          label: context.tr(pinned ? 'list_ov_unpin' : 'list_ov_pin'),
          onSelected: () => ref
              .read(pinnedListProvider.notifier)
              .pin(pinned ? null : list.id),
        ),
        AvoMenuItem(
          label: context.tr('list_ov_rename'),
          onSelected: () => _openInfo(list, focusName: true),
        ),
        AvoMenuItem(
          label: context.tr('list_ov_share'),
          icon: AvoIcons.share,
          onSelected: () => showShareListDialog(
            context,
            ref,
            listId: list.id,
            listName: list.name,
          ),
        ),
        AvoMenuItem(
          label: context.tr('list_ov_color'),
          onSelected: () => _openInfo(list),
        ),
        const AvoMenuDivider(),
        if (owner)
          AvoMenuItem(
            label: context.tr('list_ov_delete'),
            icon: AvoIcons.trash,
            destructive: true,
            enabled: !offline,
            subtitle: needsConnection,
            onSelected: () => _delete(list),
          )
        else
          AvoMenuItem(
            label: context.tr('list_ov_leave'),
            destructive: true,
            enabled: !offline,
            subtitle: needsConnection,
            onSelected: () => _leave(list),
          ),
      ],
    );
  }

  Future<void> _quickAdd(ShoppingListModel hero, QuickAddSuggestion s) async {
    final key = s.name.toLowerCase();
    setState(() => _added.add(key));
    final actions = ref.read(listActionsProvider);
    final toastContext = context;
    final message = context.tr(
      'list_ov_added_to',
      params: {'name': s.name, 'list': hero.name},
    );
    final undoLabel = context.tr('common_undo');
    try {
      final token = await actions.addItem(hero.id, s);
      // The source drops items that are on a list now.
      if (mounted) refreshAllListsQuickAdd(ref);
      if (!toastContext.mounted) return;
      AvoToast.show(
        toastContext,
        message: message,
        actionLabel: undoLabel,
        onAction: () async {
          if (mounted) setState(() => _added.remove(key));
          try {
            await actions.undoAdd(token);
            if (mounted) refreshAllListsQuickAdd(ref);
          } catch (e) {
            debugPrint('❌ [ALL_LISTS] Undo failed: $e');
            _failed();
          }
        },
      );
    } catch (e) {
      debugPrint('❌ [ALL_LISTS] Quick add failed: $e');
      if (mounted) setState(() => _added.remove(key));
      _failed();
    }
  }

  /// The group "Verlauf" (A-V12) from Teil B's synchronous summaries.
  AllListsHistoryEntry _historyEntry() {
    final language = Localizations.localeOf(context).languageCode;
    final trips = ref.watch(historyEntrySummaryProvider);
    final balances = ref.watch(openBalancesSummaryProvider);
    return AllListsHistoryEntry(
      onTrips: () => unawaited(context.push<void>(historyLocation())),
      tripsValue: trips.hasTrips
          ? context.tr(
              'list_ov_trips_value',
              params: {
                'month': monthName(trips.month, language),
                'n': '${trips.tripsThisMonth}',
              },
            )
          : null,
      onBalances: balances == null
          ? null
          : () => unawaited(context.push<void>(splitsLocation())),
      balancesValue: balances == null
          ? null
          : formatEuroCents(balances.totalOpenCents, language),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(allListsSourceProvider);
    final userId = ref.watch(authUserIdProvider);
    final pinned = ref.watch(pinnedListProvider);
    final lastOpened = ref.watch(lastAccessedListProvider).valueOrNull;
    final offline = ref.watch(isOfflineProvider);
    final lists = source.valueOrNull;

    final AllListsPhase phase;
    if (lists != null) {
      phase = AllListsPhase.ready;
    } else if (source.hasError) {
      phase = AllListsPhase.error;
    } else {
      phase = AllListsPhase.loading;
    }

    final all = lists ?? const <ShoppingListModel>[];
    // Sorted once per visit: the first known lists fix the order.
    if (lists != null) _snapshot ??= listOrderSnapshot(lists);
    final snapshot = _snapshot ?? const <String, DateTime>{};
    final hero = pickHeroList(
      all,
      pinnedId: pinned.listId,
      lastOpenedId: lastOpened,
    );
    final rest = sortBySnapshot([
      for (final l in all)
        if (l.id != hero?.id) l,
    ], snapshot);
    final mine = [
      for (final l in rest)
        if (userId == null || l.ownerId == userId) l,
    ];
    final sharedWithMe = [
      for (final l in rest)
        if (userId != null && l.ownerId != userId) l,
    ];

    final members = <String, List<ListMember>>{};
    for (final l in all) {
      if (!l.isShared && (userId == null || l.ownerId == userId)) continue;
      final known = ref.watch(listMembersProvider(l.id)).valueOrNull;
      if (known != null) members[l.id] = known;
    }

    final quick = hero == null
        ? const <QuickAddSuggestion>[]
        : [
            for (final s in ref.watch(allListsQuickAddProvider))
              if (!_added.contains(s.name.toLowerCase())) s,
          ];

    final content = AllListsContent(
      phase: phase,
      lists: all,
      hero: hero,
      mine: mine,
      sharedWithMe: sharedWithMe,
      currentUserId: userId,
      now: DateTime.now(),
      members: members,
      quickAdd: quick,
      offline: offline,
      query: _query,
      onQueryChanged: (q) => setState(() => _query = q),
      onOpen: _open,
      onMenu: _menu,
      onCreate: _create,
      onJoin: _join,
      onQuickAdd: (s) {
        if (hero != null) _quickAdd(hero, s);
      },
      onRetry: _refresh,
      onWeeklyOffers: ref.watch(offersAvailableProvider)
          ? () => unawaited(context.push<void>(weeklyOffersLocation()))
          : null,
      history: phase == AllListsPhase.ready ? _historyEntry() : null,
    );

    return ColoredBox(
      color: context.colors.background,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              SliverPadding(
                padding: EdgeInsets.only(
                  top:
                      GlassToolbar.topOffset(context) +
                      AvoSizes.toolbarButton +
                      _kTitleGap,
                  bottom: ShellInsets.bottom(context),
                ),
                sliver: SliverToBoxAdapter(child: content),
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: GlassToolbar(
              trailing: [
                AvoMenuButton(
                  items: [
                    AvoMenuItem(
                      label: context.tr('list_ov_join_list'),
                      icon: AvoIcons.people,
                      enabled: !offline,
                      subtitle: offline
                          ? context.tr('common_needs_connection')
                          : null,
                      onSelected: _join,
                    ),
                  ],
                ),
                GlassIconButton(
                  icon: const AvoIcon(AvoIcons.plus),
                  semanticLabel: context.tr('list_ov_new_list'),
                  tinted: true,
                  onPressed: _create,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
