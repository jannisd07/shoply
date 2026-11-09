import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/core/utils/diet_checker.dart';
import 'package:shoply/core/utils/item_input_parser.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/native/app_badge_channel.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_category_section.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_composer.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_menu.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_parts.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_item_tile.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_maybe_also.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/presentation/widgets/design/success_moment.dart';
import 'package:shoply/presentation/widgets/design/pro_hint_counter.dart';
import 'package:shoply/presentation/widgets/tips/list_tips.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

/// A row just checked off stays in its aisle this long before it moves to
/// "Erledigt"; tapping it again in that time takes it back (Konzept 11
/// §1.1: "Nach 0,6 s wandert die Zeile").
const Duration _linger = Duration(milliseconds: 600);

/// How long "Widerrufen" is offered: the toast's 4 s, 10 s with VoiceOver
/// (Konzept 00 §12.28).
const Duration _undoWindow = Duration(seconds: 4);
const Duration _undoWindowVoiceOver = Duration(seconds: 10);

/// A deleted row is removed for good this long after its toast has gone.
const Duration _deleteGrace = Duration(milliseconds: 300);

/// Space between the toolbar and the large title (D2: content starts at
/// 106 = toolbar top 54 + 44 + 8).
const double _titleTop = AvoSpacing.s; // D2

/// Text inset above and below one line of the add field (D2 Bottom
/// Accessory: (52 - 22) / 2), to reserve room for a taller field.
const double _accessoryTextInset = 15; // D2

/// SharedPreferences key prefix for "Erledigt" expanded, per list.
const String _doneExpandedKey = 'list_done_expanded_';

/// One list (D2-Liste, Konzept 11 §1, §2, §11.1): glass toolbar with back,
/// "Teilen" + "Mehr" and the tinted cart for shopping mode; large title,
/// members, progress and Teil B's market chip; the aisles of open items;
/// "Erledigt" collapsed at the end; the add field above the tab bar.
///
/// - Checking off shows "Abgehakt: Milch · Widerrufen"; deleting (full swipe
///   or menu) hides the row at once and removes it for good only when the
///   undo time is over, so "Widerrufen" brings it back unchanged.
/// - The add field reads "2 Milch", "500 g Mehl" and "Milch, Eier, Butter"
///   locally: one item goes through the items provider, several in one
///   batch with "Widerrufen".
/// - `?focus=add` (deep link `list:<id>:add`) focuses the add field.
/// - `?arrival=` after the onboarding (Konzept 17 §3.12): `new` focuses the
///   add field with tip T1, `joined` shows tip T5, `existing` a one-time
///   status; the tip sits in "Für heute" ([ListTipSection]).
/// - Sets the Avo context to this list while it is the current screen.
/// - Opening still marks the list read and clears its badge and delivered
///   notifications.
class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.focusAdd = false,
    this.arrival,
  });

  final String listId;

  /// Name from the route until the lists are loaded.
  final String listName;

  /// Focus the add field on open (also read from `?focus=add`).
  final bool focusAdd;

  /// `?arrival=` when the onboarding opened this list.
  final OnboardingArrival? arrival;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

/// A deletion waiting for its undo time to pass.
class _PendingDelete {
  _PendingDelete(this.itemId, this.notifier);

  final String itemId;
  final ItemsNotifier notifier;
  Timer? timer;
  bool finished = false;

  void finish() {
    finished = true;
    timer?.cancel();
  }
}

/// What the list shows, derived from the items once per change.
class _ListView {
  const _ListView({
    required this.items,
    required this.aisles,
    required this.done,
    required this.openCount,
  });

  /// Visible items (without rows waiting to be deleted).
  final List<ShoppingItemModel> items;

  /// Aisles of open rows (and rows just checked, still lingering).
  final List<ListCategoryGroup> aisles;

  /// Checked rows, newest first.
  final List<ShoppingItemModel> done;
  final int openCount;
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final _drag = ListDragController(_scroll, this);
  final _moreKey = GlobalKey(debugLabel: 'listMore');
  final _inlineTitle = ValueNotifier<bool>(false);

  late String _listName = widget.listName;
  List<CustomCategory> _customCategories = const [];
  List<String> _categoryOrder = const [];

  final Set<String> _hidden = {};
  final Map<String, Timer> _lingering = {};
  _PendingDelete? _pendingDelete;
  bool? _doneExpanded;

  // Memo of the derived view.
  _ListView? _view;
  List<ShoppingItemModel>? _viewSource;
  String? _viewLanguage;
  bool _viewDirty = true;

  bool _settled = false;
  bool _disposed = false;
  bool _focusChecked = false;

  /// When the person closed the keyboard on purpose (tap in the list, an
  /// item, the menu); the add field then stays closed after a route.
  DateTime? _dismissedAt;
  Animation<double>? _routeAnimation;
  double _titleHeight = 0;

  late final StateController<AvoScreenContext?> _avo;
  AvoScreenContext? _avoContext;

  String get _listId => widget.listId;

  ItemsNotifier get _items => ref.read(itemsNotifierProvider(_listId).notifier);

  ListDetailActions get _actions => ref.read(listDetailActionsProvider);

  @override
  void initState() {
    super.initState();
    _avo = ref.read(avoScreenContextProvider.notifier);
    applyListArrival(ref, context, listId: _listId, arrival: widget.arrival);
    _scroll.addListener(_onScroll);
    unawaited(_loadCustomCategories());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _onSettled();
      } else {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteStatus);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusChecked) return;
    _focusChecked = true;
    if (widget.focusAdd ||
        _routeAsksForFocus() ||
        widget.arrival == OnboardingArrival.created) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  /// `?focus=add` on the route (deep link "list with the add field").
  bool _routeAsksForFocus() {
    try {
      return GoRouterState.of(context).uri.queryParameters['focus'] == 'add';
    } catch (_) {
      // Not opened through the router (tests, a plain push).
      return false;
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _onSettled();
  }

  /// Side effects once the push has settled, so they never compete with the
  /// transition's frames.
  void _onSettled() {
    if (!mounted || _settled) return;
    _settled = true;
    unawaited(_markAsRead());
  }

  Future<void> _markAsRead() async {
    try {
      await UnreadService().markAsRead(_listId);
    } catch (e) {
      debugPrint('⚠️ [LIST_DETAIL] Mark as read failed: $e');
    }
    await AppBadge.clear();
    await _clearThisListsNotifications();
  }

  /// Removes delivered notifications about this list from the Notification
  /// Center. Scheduled reminders and other lists' notifications stay.
  Future<void> _clearThisListsNotifications() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final active = await FlutterLocalNotificationsPlugin()
          .getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        final payload = notification.payload;
        if (id != null && payload != null && payload.contains(_listId)) {
          await NotificationService.instance.cancel(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LIST_DETAIL] Failed to clear notifications: $e');
    }
  }

  Future<void> _loadCustomCategories() async {
    try {
      final service = CategoryOrderService();
      final categories = await service.getCustomCategories(_listId);
      final order = await service.getCategoryOrder(_listId);
      if (!_alive) return;
      setState(() {
        _customCategories = categories;
        _categoryOrder = order;
        _viewDirty = true;
      });
    } catch (e) {
      debugPrint('⚠️ [LIST_DETAIL] Category order not loaded: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    // A deletion still waiting for its undo time happens now.
    // Deferred: the row's provider must not notify this element while it
    // is being unmounted.
    final pending = _pendingDelete;
    if (pending != null) Future.microtask(() => _commitDelete(pending));
    for (final timer in _lingering.values) {
      timer.cancel();
    }
    _resetAvoContext();
    _drag.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    _focus.dispose();
    _inlineTitle.dispose();
    super.dispose();
  }

  bool get _alive => mounted && !_disposed;

  // ---------------------------------------------------------------- Avo

  /// Tells Avo that the person is on this list (Kap. 16, Tabelle 5.2).
  void _syncAvoContext(String name, {required bool current}) {
    if (!current) {
      _avoContext = null;
      return;
    }
    final next = AvoScreenContext(
      screen: 'list',
      listId: _listId,
      listName: name,
    );
    if (next == _avoContext) return;
    _avoContext = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alive && _avoContext == next) _avo.state = next;
    });
  }

  /// Leaving the list clears the context, unless another screen already set
  /// its own.
  void _resetAvoContext() {
    final avo = _avo;
    final mine = AvoScreenContext(
      screen: 'list',
      listId: _listId,
      listName: _avoContext?.listName,
    );
    Future.microtask(() {
      try {
        final state = avo.state;
        if (state?.screen == mine.screen && state?.listId == mine.listId) {
          avo.state = null;
        }
      } catch (_) {
        // The provider scope is gone (app or test shut down).
      }
    });
  }

  // ---------------------------------------------------------------- scroll

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > _titleHeight;
    if (_inlineTitle.value != show) _inlineTitle.value = show;
  }

  void _dismissKeyboard() {
    if (!_focus.hasFocus) return;
    _dismissedAt = DateTime.now();
    _focus.unfocus();
  }

  /// The add field may take the focus back after a route (A-C4) unless the
  /// keyboard was closed on purpose just before.
  bool _refocusAllowed() {
    final at = _dismissedAt;
    return at == null ||
        DateTime.now().difference(at) > const Duration(seconds: 1);
  }

  Future<void> _refresh() async {
    await Future.wait([
      _items.loadItems(),
      _actions.refreshLists(ref).catchError((Object e) {
        debugPrint('⚠️ [LIST_DETAIL] Lists not refreshed: $e');
      }),
    ]);
  }

  // ---------------------------------------------------------------- view

  _ListView _derive(List<ShoppingItemModel> all, String language) {
    if (!_viewDirty &&
        identical(all, _viewSource) &&
        language == _viewLanguage &&
        _view != null) {
      return _view!;
    }
    final items = [
      for (final item in all)
        if (!_hidden.contains(item.id)) item,
    ];
    final inAisles = [
      for (final item in items)
        if (!item.isChecked || _lingering.containsKey(item.id)) item,
    ];
    final aisles = [
      for (final group in groupItemsByCategory(
        inAisles,
        customCategories: _customCategories,
        categoryOrder: _categoryOrder,
        languageCode: language,
      ))
        if (group.items.isNotEmpty) group,
    ];
    final done = [
      for (final item in items)
        if (item.isChecked && !_lingering.containsKey(item.id)) item,
    ]..sort(_newestCheckedFirst);
    final view = _ListView(
      items: items,
      aisles: aisles,
      done: done,
      openCount: items.where((i) => !i.isChecked).length,
    );
    _view = view;
    _viewSource = all;
    _viewLanguage = language;
    _viewDirty = false;
    return view;
  }

  static int _newestCheckedFirst(ShoppingItemModel a, ShoppingItemModel b) {
    final at = a.checkedAt ?? a.updatedAt;
    final bt = b.checkedAt ?? b.updatedAt;
    return bt.compareTo(at);
  }

  void _changeView(VoidCallback change) {
    if (!_alive) return;
    setState(() {
      change();
      _viewDirty = true;
    });
  }

  Duration _undoTime() => MediaQuery.accessibleNavigationOf(context)
      ? _undoWindowVoiceOver
      : _undoWindow;

  bool get _doneOpen {
    final known = _doneExpanded;
    if (known != null) return known;
    final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
    return _doneExpanded = prefs?.getBool('$_doneExpandedKey$_listId') ?? false;
  }

  void _setDoneOpen(bool open) {
    setState(() => _doneExpanded = open);
    final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
    unawaited(
      prefs?.setBool('$_doneExpandedKey$_listId', open).catchError((_) {
        return false;
      }),
    );
  }

  // ---------------------------------------------------------------- items

  void _toggle(ShoppingItemModel item, bool checked) {
    final wasLingering = _lingering.remove(item.id);
    wasLingering?.cancel();
    if (checked) {
      final visible = _view?.items ?? const <ShoppingItemModel>[];
      final lastOpen = !visible.any((i) => !i.isChecked && i.id != item.id);
      _changeView(() {
        _lingering[item.id] = Timer(_linger, () {
          _changeView(() => _lingering.remove(item.id));
        });
      });
      if (lastOpen) unawaited(AvoHaptics.success());
      AvoToast.show(
        context,
        message: context.tr('list_detail_checked', params: {'name': item.name}),
        actionLabel: context.tr('common_undo'),
        onAction: () => _toggle(item, false),
      );
    } else if (wasLingering != null) {
      _changeView(() {});
    }
    final notifier = _items;
    unawaited(
      notifier.toggleItemChecked(item.id, checked).catchError((Object e) {
        debugPrint('❌ [LIST_DETAIL] Check off failed: $e');
        _changeView(() => _lingering.remove(item.id)?.cancel());
        _failed();
      }),
    );
  }

  Future<void> _openItem(ShoppingItemModel item) async {
    _dismissKeyboard();
    await _actions.openItem(context, listId: _listId, item: item);
  }

  void _delete(ShoppingItemModel item) {
    final previous = _pendingDelete;
    if (previous != null) unawaited(_commitDelete(previous));
    final pending = _PendingDelete(item.id, _items);
    final window = _undoTime();
    pending.timer = Timer(window + _deleteGrace, () => _commitDelete(pending));
    _pendingDelete = pending;
    _changeView(() {
      _hidden.add(item.id);
      _lingering.remove(item.id)?.cancel();
    });
    AvoToast.show(
      context,
      message: context.tr('list_detail_deleted', params: {'name': item.name}),
      actionLabel: context.tr('common_undo'),
      duration: window,
      onAction: () => _undoDelete(pending),
    );
  }

  void _undoDelete(_PendingDelete pending) {
    if (pending.finished) return;
    pending.finish();
    if (_pendingDelete == pending) _pendingDelete = null;
    _changeView(() => _hidden.remove(pending.itemId));
  }

  Future<void> _commitDelete(_PendingDelete pending) async {
    if (pending.finished) return;
    pending.finish();
    if (_pendingDelete == pending) _pendingDelete = null;
    try {
      await pending.notifier.deleteItem(pending.itemId);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Delete failed: $e');
      _changeView(() => _hidden.remove(pending.itemId));
      _failed();
      return;
    }
    _changeView(() => _hidden.remove(pending.itemId));
  }

  void _failed() {
    if (!_alive) return;
    AvoToast.show(context, message: context.tr('list_detail_action_failed'));
  }

  bool _dietWarningFor(String name) {
    final user = ref.read(currentUserProvider).valueOrNull;
    return user != null &&
        DietChecker.checkDietWarning(name, user.dietPreferences);
  }

  /// Return in the add field: "2 Milch" is one item with quantity 2,
  /// "Milch, Eier" two items in one batch with "Widerrufen".
  Future<void> _submit(String text) async {
    final language = Localizations.localeOf(context).languageCode;
    final parsed = parseItemInput(text, lang: language);
    if (parsed.isEmpty) return;
    _controller.clear();
    try {
      if (parsed.length == 1) {
        final item = parsed.single;
        await _items.addItem(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          notes: item.note,
          isDietWarning: _dietWarningFor(item.name),
          // Parsed here already; never rewrite the name in the background.
          autoParse: false,
        );
      } else {
        await _addBatch([
          for (final item in parsed)
            NewItem(
              name: item.name,
              quantity: item.quantity,
              unit: item.unit,
              notes: item.note,
            ),
        ]);
      }
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Add "$text" failed: $e');
      if (!mounted || _disposed) return;
      // Nothing typed is lost.
      if (_controller.text.isEmpty) _controller.text = text;
      AvoToast.show(context, message: context.tr('list_detail_add_failed'));
    }
  }

  /// Several typed items at once ("Milch, Eier") with "Widerrufen".
  Future<void> _addBatch(List<NewItem> items) async {
    final repository = ref.read(itemRepositoryProvider);
    final notifier = _items;
    final result = await repository.addItems(_listId, items);
    unawaited(notifier.loadItems());
    if (!mounted || _disposed) return;
    AvoToast.show(
      context,
      message: context.tr(
        'list_detail_added_many',
        params: {'count': '${items.length}'},
      ),
      actionLabel: context.tr('common_undo'),
      onAction: () async {
        try {
          await repository.undoAddItems(result.token);
        } catch (e) {
          debugPrint('❌ [LIST_DETAIL] Undo add failed: $e');
          _failed();
        }
        unawaited(notifier.loadItems());
      },
    );
  }

  /// A row of "Vielleicht auch": on the list with "Widerrufen".
  Future<void> _addMaybeAlso(MaybeAlsoSuggestion suggestion) async {
    final repository = ref.read(itemRepositoryProvider);
    final notifier = _items;
    try {
      final result = await repository.addItems(_listId, [
        NewItem(
          name: suggestion.name,
          quantity: suggestion.quantity,
          category: suggestion.categoryId,
        ),
      ]);
      unawaited(notifier.loadItems());
      if (!mounted || _disposed) return;
      AvoToast.show(
        context,
        message: context.tr(
          'list_detail_added_one',
          params: {'name': suggestion.name},
        ),
        actionLabel: context.tr('common_undo'),
        onAction: () async {
          try {
            await repository.undoAddItems(result.token);
          } catch (e) {
            debugPrint('❌ [LIST_DETAIL] Undo add failed: $e');
            _failed();
          }
          unawaited(notifier.loadItems());
        },
      );
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Add suggestion failed: $e');
      _failed();
    }
  }

  // ---------------------------------------------------------------- menu

  void _openMenu(_ListView? view) {
    _dismissKeyboard();
    final hidden = ref.read(offersHiddenForListProvider(_listId));
    showAvoMenu(
      context,
      anchorKey: _moreKey,
      items: listDetailMenuEntries(
        context,
        hasOpen: (view?.openCount ?? 0) > 0,
        hasDone: view?.items.any((i) => i.isChecked) ?? false,
        offersAvailable: ref.read(offersAvailableProvider),
        offersHidden: hidden,
        isOwner: ref.read(listDetailIsOwnerProvider(_listId)),
        onSelected: (action) => _onMenu(action, offersHidden: hidden),
      ),
    );
  }

  Future<void> _onMenu(
    ListDetailMenuAction action, {
    required bool offersHidden,
  }) async {
    final name = _currentName;
    switch (action) {
      case ListDetailMenuAction.shop:
        await _openShopping();
      case ListDetailMenuAction.checkout:
        await _checkout();
      case ListDetailMenuAction.share:
        await _share();
      case ListDetailMenuAction.info:
        await _actions.openInfo(
          context,
          listId: _listId,
          listName: name,
          ownerId: ref.read(listDetailListProvider(_listId))?.ownerId,
        );
      case ListDetailMenuAction.rename:
        await _rename();
      case ListDetailMenuAction.storeOrder:
        final changed = await _actions.openStoreOrder(
          context,
          listId: _listId,
          listName: name,
        );
        if (changed && _alive) {
          await _loadCustomCategories();
          unawaited(_items.loadItems());
        }
      case ListDetailMenuAction.offers:
        await _actions.openListOffers(context, _listId);
      case ListDetailMenuAction.toggleOffers:
        await setOffersHiddenForList(ref, _listId, !offersHidden);
      case ListDetailMenuAction.importNote:
        await _importNote();
      case ListDetailMenuAction.delete:
        await _deleteList();
      case ListDetailMenuAction.leave:
        await _leaveList();
    }
  }

  /// Shopping mode; the tips T2 and T4 count it (Konzept 17 §6.1). The
  /// shopping mode reports itself too, for entries that skip the list.
  Future<void> _openShopping() {
    ref.read(tipServiceProvider).note(TipEvent.shoppingStarted);
    return _actions.openShopping(context, _listId);
  }

  String get _currentName =>
      ref.read(listDetailListProvider(_listId))?.name ?? _listName;

  /// "Einkauf abschließen": Teil B saves the trip and returns `true`; the
  /// confirmation is ours, the same success moment as in shopping mode.
  Future<void> _checkout() async {
    final items =
        ref.read(itemsNotifierProvider(_listId)).valueOrNull ??
        const <ShoppingItemModel>[];
    final count = items.where((i) => i.isChecked).length;
    final saved = await _actions.checkout(context, _listId);
    if (!saved || !mounted) return;
    ref.read(tipServiceProvider).note(TipEvent.tripCompleted);
    // The first finished trip is the aha moment for the Pro offer (§11.11).
    ref.read(proHintCounterProvider)?.noteAha();
    unawaited(
      showSuccessMoment(
        context,
        title: context.tr('list_shop_saved_title'),
        subtitle: count == 1
            ? context.tr('list_shop_saved_one')
            : context.tr('list_shop_saved_many', params: {'count': '$count'}),
      ),
    );
  }

  Future<void> _share() async {
    _dismissKeyboard();
    await _actions.share(context, ref, listId: _listId, listName: _currentName);
  }

  Future<void> _rename() async {
    final current = _currentName;
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => RenameListDialog(initialName: current),
    );
    if (name == null || name.isEmpty || name == current || !_alive) return;
    try {
      await _actions.renameList(ref, _listId, name);
      if (_alive) setState(() => _listName = name);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Rename failed: $e');
      _failed();
    }
  }

  Future<void> _importNote() async {
    _dismissKeyboard();
    final notifier = _items;
    try {
      await _actions.importNote(context, listId: _listId, anchorKey: _moreKey);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Import failed: $e');
      _failed();
    }
    // The import wrote through the repository; show its rows at once.
    unawaited(notifier.loadItems());
  }

  Future<void> _deleteList() async {
    final name = _currentName;
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_detail_delete_title', params: {'name': name}),
      message: context.tr('list_detail_delete_message'),
      confirmLabel: context.tr('list_detail_delete_confirm'),
    );
    if (!confirmed || !_alive) return;
    try {
      await _actions.deleteList(ref, _listId);
      if (mounted && !_disposed) _actions.openAllLists(context);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Delete list failed: $e');
      _failed();
    }
  }

  Future<void> _leaveList() async {
    final name = _currentName;
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_detail_leave_title', params: {'name': name}),
      message: context.tr('list_detail_leave_message'),
      confirmLabel: context.tr('list_detail_leave_confirm'),
    );
    if (!confirmed || !_alive) return;
    try {
      await _actions.leaveList(ref, _listId);
      if (mounted && !_disposed) _actions.openAllLists(context);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Leave list failed: $e');
      _failed();
    }
  }

  // ---------------------------------------------------------------- build

  Widget _row(ShoppingItemModel item, ListCategoryGroup? aisle) {
    return ListItemTile(
      key: ValueKey<String>(item.id),
      item: item,
      listId: _listId,
      categoryId: aisle?.id ?? item.categoryId ?? item.category ?? 'other',
      categoryName: aisle?.name ?? '',
      // Done rows (and rows just checked) are not reordered.
      dragController: item.isChecked ? null : _drag,
      onToggle: (checked) => _toggle(item, checked),
      onOpen: () => _openItem(item),
      onDelete: () => _delete(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemsAsync = ref.watch(itemsNotifierProvider(_listId));
    final list = ref.watch(listDetailListProvider(_listId));
    final name = list?.name ?? _listName;
    final offline = ref.watch(isOfflineProvider);
    final offers = ref.watch(offersAvailableProvider);
    final images = listImagesShown(context, ref);
    final members = list?.isShared ?? false
        ? ref.watch(listDetailMembersProvider(_listId)).valueOrNull ??
              const <String>[]
        : const <String>[];
    final language = Localizations.localeOf(context).languageCode;
    _syncAvoContext(name, current: ModalRoute.isCurrentOf(context) ?? true);
    _titleHeight = context.typography.lineHeightOf(AvoTextStyle.largeTitle);

    final all = itemsAsync.valueOrNull;
    final view = all == null ? null : _derive(all, language);
    final total = view?.items.length ?? 0;
    final done = total - (view?.openCount ?? 0);
    final sum = offers && view != null ? listOpenPriceTotal(view.items) : null;
    final background = context.isAccessibilityText
        ? colors.backgroundPlain
        : colors.background;

    final slivers = <Widget>[
      CupertinoSliverRefreshControl(onRefresh: _refresh),
      SliverPadding(
        padding: EdgeInsets.only(
          top:
              GlassToolbar.topOffset(context) +
              AvoSizes.toolbarButton +
              _titleTop,
        ),
        sliver: SliverToBoxAdapter(
          child: ListDetailHeader(
            listId: _listId,
            title: name,
            total: total,
            done: done,
            members: members,
            onMembersTap: _share,
          ),
        ),
      ),
      if (offline)
        SliverPadding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          sliver: SliverToBoxAdapter(
            child: StatusRow(
              kind: StatusKind.offline,
              text: context.tr('common_offline'),
            ),
          ),
        ),
      // "Für heute" with the one tip (Konzept 11 §1.1 item 6, 17 §6.1).
      SliverToBoxAdapter(
        child: ListTipSection(
          items: view?.items,
          shared: list?.isShared,
          arrival: widget.arrival,
        ),
      ),
      ..._content(itemsAsync, view, images),
      const SliverToBoxAdapter(child: _BottomInset()),
    ];

    return ColoredBox(
      color: background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _dismissKeyboard(),
              child: CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: slivers,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollEdgeFade(color: background),
          ),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _inlineTitle,
              builder: (context, showTitle, _) => ListDetailToolbar(
                title: showTitle ? name : null,
                moreKey: _moreKey,
                onBack: () => _actions.back(context),
                onShare: _share,
                onMore: () => _openMenu(view),
                onShop: (view?.openCount ?? 0) > 0 ? _openShopping : null,
              ),
            ),
          ),
          AccessoryDock(
            child: ListDetailComposer(
              listId: _listId,
              controller: _controller,
              focusNode: _focus,
              onSubmitted: _submit,
              refocusAllowed: _refocusAllowed,
              totalText: sum == null ? null : formatListTotal(sum, language),
            ),
          ),
        ],
      ),
    );
  }

  /// The part below the header: loading, error, empty, all done, or the
  /// aisles with "Erledigt".
  List<Widget> _content(
    AsyncValue<List<ShoppingItemModel>> itemsAsync,
    _ListView? view,
    bool images,
  ) {
    if (view == null) {
      if (itemsAsync.hasError) {
        return [
          SliverPadding(
            padding: const EdgeInsets.only(top: AvoSpacing.m),
            sliver: SliverToBoxAdapter(
              child: StatusRow(
                kind: StatusKind.sectionError,
                text: context.tr('list_detail_load_error'),
                actionLabel: context.tr('common_try_again'),
                onAction: () => unawaited(_items.loadItems()),
              ),
            ),
          ),
        ];
      }
      // First load without any local data: calm placeholders, no spinner.
      return [
        SliverPadding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          sliver: SliverList.list(
            children: const [
              SkeletonSection(),
              SizedBox(height: AvoSpacing.section),
              SkeletonSection(),
            ],
          ),
        ),
      ];
    }

    final maybeAlso = _GapWhenFilled(
      gap: AvoSpacing.section,
      child: ListMaybeAlsoSection(listId: _listId, onAdd: _addMaybeAlso),
    );

    if (view.items.isEmpty) {
      // Right after the onboarding the tip T1 already says what to type,
      // and the room belongs to the suggestion panel (Konzept 17 §3.12).
      if (widget.arrival == OnboardingArrival.created) return const [];
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: const AvoIcon(AvoIcons.listBullet),
            title: context.tr('list_detail_empty_title'),
            message: context.tr('list_detail_empty_message'),
            actionLabel: context.tr('list_detail_menu_import'),
            onAction: _importNote,
          ),
        ),
        SliverToBoxAdapter(child: maybeAlso),
      ];
    }

    final doneSection = ListDoneSection(
      items: view.done,
      expanded: _doneOpen,
      onExpandedChanged: _setDoneOpen,
      withThumbs: images,
      rowBuilder: (item) => _row(item, null),
    );

    if (view.aisles.isEmpty) {
      final count = view.done.length;
      return [
        SliverList.list(
          children: [
            EmptyState(
              pose: AvoPose.excited,
              title: context.tr('list_detail_all_done_title'),
              message: count == 1
                  ? context.tr('list_detail_all_done_message_one')
                  : context.tr(
                      'list_detail_all_done_message',
                      params: {'count': '$count'},
                    ),
              actionLabel: context.tr('list_detail_menu_checkout'),
              onAction: _checkout,
            ),
            doneSection,
          ],
        ),
      ];
    }

    final blocks = <Widget>[
      for (final aisle in view.aisles)
        ListAisleSection(
          key: ValueKey<String>('aisle-${aisle.id}'),
          group: aisle,
          listId: _listId,
          dragController: _drag,
          rowBuilder: (item) => _row(item, aisle),
        ),
      // Teil B: "4 von 11 Artikeln diese Woche bei Lidl im Angebot …" in a
      // section of its own; without content neither it nor its gap shows.
      _GapWhenFilled(
        gap: AvoSpacing.section,
        child: ListOfferSummary(listId: _listId),
      ),
      maybeAlso,
      doneSection,
    ];
    return [
      SliverList.builder(
        itemCount: blocks.length,
        itemBuilder: (context, index) => blocks[index],
      ),
    ];
  }
}

/// Room at the end of the list so the last rows clear the add field and the
/// tab bar, or the add field on the keyboard. Only this box reads the
/// keyboard inset, so typing does not rebuild the list.
class _BottomInset extends StatelessWidget {
  const _BottomInset();

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    // The add field grows with the text size; reserve its real height.
    final field =
        typography.lineHeightOf(AvoTextStyle.body) + 2 * _accessoryTextInset;
    final grow = field > AvoSizes.accessoryHeight
        ? field - AvoSizes.accessoryHeight
        : 0.0;
    final resting = ShellInsets.bottom(context, withAccessory: true) + grow;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final typing = keyboard > 0
        ? keyboard + AvoSizes.accessoryGap + field + AvoSpacing.l
        : 0.0;
    return SizedBox(height: resting > typing ? resting : typing);
  }
}

/// [gap] above [child], only while the child has a height: a slot that
/// renders nothing leaves no space (Teil B's `ListOfferSummary`).
class _GapWhenFilled extends SingleChildRenderObjectWidget {
  const _GapWhenFilled({required this.gap, required super.child});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGapWhenFilled(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGapWhenFilled renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class _RenderGapWhenFilled extends RenderShiftedBox {
  _RenderGapWhenFilled(this._gap) : super(null);

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _withGap(double height) => height > 0 ? height + _gap : 0;

  BoxConstraints _childConstraints(BoxConstraints c) => c.copyWith(
    minHeight: 0,
    maxHeight: c.maxHeight.isFinite
        ? (c.maxHeight - _gap).clamp(0.0, double.infinity)
        : c.maxHeight,
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _withGap(child?.getMinIntrinsicHeight(width) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _withGap(child?.getMaxIntrinsicHeight(width) ?? 0);

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final box = child;
    if (box == null) return constraints.smallest;
    final size = box.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(Size(size.width, _withGap(size.height)));
  }

  @override
  void performLayout() {
    final box = child;
    if (box == null) {
      size = constraints.smallest;
      return;
    }
    box.layout(_childConstraints(constraints), parentUsesSize: true);
    final filled = box.size.height > 0;
    (box.parentData! as BoxParentData).offset = Offset(0, filled ? _gap : 0);
    size = constraints.constrain(
      Size(box.size.width, _withGap(box.size.height)),
    );
  }
}
