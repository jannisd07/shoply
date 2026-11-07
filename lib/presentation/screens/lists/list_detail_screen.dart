import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/diet_checker.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/app_review_service.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/presentation/screens/lists/category_order_screen.dart';
import 'package:shoply/presentation/screens/lists/list_settings_screen.dart';
import 'package:shoply/presentation/screens/lists/shopping_trip_completion.dart';
import 'package:shoply/presentation/screens/lists/widgets/add_item_composer.dart';
import 'package:shoply/presentation/screens/lists/widgets/attachment_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/import_review_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_form_dialog.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_category_section.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_menu.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_parts.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_price_summary_bar.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_list_dialog.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/common/empty_state.dart';
import 'package:shoply/presentation/widgets/common/loading_indicator.dart';
import 'package:shoply/presentation/widgets/recommendations/ml_recommendations_section.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  final String listId;
  final String listName;

  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final _dragController = ListDragController(_scrollController);

  /// Name from the route, replaced after a local rename. The lists
  /// provider's copy wins once loaded, so collaborator renames show too.
  late String _listName;

  // Debounced copy of the add-bar text used for live offer search, so a
  // fast typer doesn't fire a network request per keystroke.
  final ValueNotifier<String> _offerQuery = ValueNotifier<String>('');
  Timer? _offerQueryDebounce;

  // Custom categories and saved order (device-local).
  List<CustomCategory> _customCategories = [];
  List<String> _categoryOrder = [];

  // Grouping cache: regrouped only when items, categories or locale change.
  List<ListCategoryGroup> _groups = const [];
  List<ShoppingItemModel>? _groupsItems;
  String? _groupsLanguage;
  bool _groupsDirty = true;

  // True once the push transition has fully settled. Heavy work (refresh
  // fetches, the ML recommendations section) waits for this so the
  // Cupertino push renders its frames without competing rebuilds — the
  // first frame comes from the ItemsNotifier's cached/streamed state.
  bool _routeTransitionDone = false;
  Animation<double>? _routeAnimation;

  // Morph origin for the attachment sheet ("+" button in the composer).
  final GlobalKey _plusButtonKey = GlobalKey();

  /// Measured height of the floating bottom bar (price summary / offer
  /// suggestions + composer), used as the list's bottom inset so nothing
  /// hides behind it. Seeded with a sensible value so the first frame is
  /// already close; [_syncBottomBarHeight] corrects it after layout.
  final GlobalKey _bottomBarKey = GlobalKey();
  double _bottomBarHeight = 110;

  // Review prompt state — ensures we only fire rating prompt once per session
  // when the user completes an entire list (all items checked off).
  bool _listCompletionReviewFired = false;
  int? _lastCheckedCount;

  @override
  void initState() {
    super.initState();
    _listName = widget.listName;
    _searchController.addListener(_onSearchChangedForOffers);
    // Cheap SharedPreferences read; done right away so items filed under a
    // custom category don't jump sections once it arrives.
    _loadCustomCategories();
    // Defer all non-critical work until the push transition has settled:
    // the ItemsNotifier already loads (and realtime-streams) on first
    // watch, so the first frame renders from that state and nothing below
    // competes with the transition for frame time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _onRouteTransitionSettled();
      } else {
        _routeAnimation = animation;
        animation.addStatusListener(_routeAnimationStatusListener);
      }
    });
  }

  void _routeAnimationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_routeAnimationStatusListener);
      _routeAnimation = null;
      _onRouteTransitionSettled();
    }
  }

  /// Runs once the screen is fully on screen (push transition settled).
  void _onRouteTransitionSettled() {
    if (!mounted || _routeTransitionDone) return;
    setState(() => _routeTransitionDone = true);
    _markAsRead();
    DynamicTutorialService.instance.onListOpened();
  }

  void _syncBottomBarHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      // Bar height plus the gap it floats above the safe area.
      final h = box.size.height + 14;
      if ((h - _bottomBarHeight).abs() > 1) {
        setState(() => _bottomBarHeight = h);
      }
    });
  }

  /// Debounces the add-bar text into [_offerQuery] (300ms) so live offer
  /// search only fires once the user pauses typing. Clearing the field
  /// updates instantly so the suggestion card disappears without delay.
  void _onSearchChangedForOffers() {
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      _setOfferQuery('');
      return;
    }
    _offerQueryDebounce?.cancel();
    _offerQueryDebounce = Timer(const Duration(milliseconds: 300), () {
      _setOfferQuery(text);
    });
  }

  void _setOfferQuery(String value) {
    _offerQueryDebounce?.cancel();
    if (_offerQuery.value != value) _offerQuery.value = value;
  }

  Future<void> _loadCustomCategories() async {
    final service = CategoryOrderService();
    final categories = await service.getCustomCategories(widget.listId);
    final order = await service.getCategoryOrder(widget.listId);
    if (!mounted) return;
    setState(() {
      _customCategories = categories;
      _categoryOrder = order;
      _groupsDirty = true;
    });
  }

  Future<void> _markAsRead() async {
    await UnreadService().markAsRead(widget.listId);

    try {
      if (await FlutterAppBadger.isAppBadgeSupported()) {
        FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      debugPrint('⚠️ [LIST_DETAIL] Failed to remove badge: $e');
    }

    await _clearThisListsNotifications();
  }

  /// Removes delivered notifications about this list from the Notification
  /// Center. Scheduled reminders and other lists' notifications stay.
  Future<void> _clearThisListsNotifications() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final active =
          await FlutterLocalNotificationsPlugin().getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        final payload = notification.payload;
        if (id != null && payload != null && payload.contains(widget.listId)) {
          await NotificationService.instance.cancel(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LIST_DETAIL] Failed to clear notifications: $e');
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeAnimationStatusListener);
    _dragController.dispose();
    _offerQueryDebounce?.cancel();
    _searchController.removeListener(_onSearchChangedForOffers);
    _searchController.dispose();
    _offerQuery.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ShoppingListModel? _listFromProvider() {
    final lists = ref.read(listsNotifierProvider).valueOrNull;
    return lists?.where((l) => l.id == widget.listId).firstOrNull;
  }

  String get _currentListName => _listFromProvider()?.name ?? _listName;

  List<ListCategoryGroup> _groupedItems(
    List<ShoppingItemModel> items,
    String languageCode,
  ) {
    if (_groupsDirty ||
        !identical(items, _groupsItems) ||
        languageCode != _groupsLanguage) {
      _groups = groupItemsByCategory(
        items,
        customCategories: _customCategories,
        categoryOrder: _categoryOrder,
        languageCode: languageCode,
      );
      _groupsItems = items;
      _groupsLanguage = languageCode;
      _groupsDirty = false;
    }
    return _groups;
  }

  void _onItemsChanged(
    AsyncValue<List<ShoppingItemModel>>? previous,
    AsyncValue<List<ShoppingItemModel>> next,
  ) {
    // Detect when the user completes an entire shopping list (all items
    // checked) — the perfect moment to ask for a rating.
    final items = next.asData?.value;
    if (items == null || items.isEmpty) return;
    final checked = items.where((i) => i.isChecked).length;
    final prevCount = _lastCheckedCount;
    _lastCheckedCount = checked;

    if (checked == items.length &&
        prevCount != null &&
        prevCount < items.length &&
        !_listCompletionReviewFired) {
      _listCompletionReviewFired = true;
      // Fire and forget — respects AppReviewService throttling internally.
      AppReviewService.instance.trackPositiveAction('completed_list');
      Future.delayed(const Duration(milliseconds: 800), () {
        AppReviewService.instance.maybeRequestReview(reason: 'completed_list');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsNotifierProvider(widget.listId));
    ref.listen(itemsNotifierProvider(widget.listId), _onItemsChanged);
    // Rebuild on renames (also by collaborators).
    final listName = ref.watch(
          listsNotifierProvider.select(
            (lists) => lists.valueOrNull
                ?.where((l) => l.id == widget.listId)
                .firstOrNull
                ?.name,
          ),
        ) ??
        _listName;

    final items = itemsAsync.valueOrNull;
    final openCount = items?.where((i) => !i.isChecked).length ?? 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        // Stated here because AppBar otherwise derives it from
        // backgroundColor — and `transparent` estimates as *dark*, which put
        // white clock and Wi-Fi/battery icons on this light screen. Setting
        // it on the widget takes precedence over theme and estimation alike.
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PaperTextStyles.serif(
                24,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (items != null && items.isNotEmpty)
              Text(
                '$openCount ${context.tr('items_open_suffix')} · ${items.length} ${context.tr('items')}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
          ],
        ),
        leadingWidth: 60,
        leading: ListDetailBackButton(onPressed: _goBack),
        actions: [
          ListDetailMenuButton(onSelected: _onMenuSelected),
          ListDetailShareButton(
            onPressed: () => showShareListDialog(
              context,
              ref,
              listId: widget.listId,
              listName: _currentListName,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Paper progress hairline under the header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenHorizontalPadding,
                  4,
                  AppDimensions.screenHorizontalPadding,
                  6,
                ),
                child: ListProgressHairline(
                  total: items?.length ?? 0,
                  done: (items?.length ?? 0) - openCount,
                ),
              ),
              Expanded(
                key: DynamicTutorialService.instance.listItemsAreaKey,
                child: itemsAsync.when(
                  data: _buildItemsList,
                  loading: () =>
                      LoadingIndicator(message: context.tr('loading_items')),
                  error: (error, stack) =>
                      Center(child: Text(context.tr('loading_error'))),
                ),
              ),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<ShoppingItemModel> items) {
    DynamicTutorialService.instance.updateListItemsData(
      hasItems: items.isNotEmpty,
    );
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart,
        title: AppLocalizations.of(context).emptyList,
        subtitle: context.tr('empty_list_hint'),
        actionText: AppLocalizations.of(context).addItem,
        onActionPressed: _showAddItemDialog,
      );
    }

    final groups = _groupedItems(
      items,
      Localizations.localeOf(context).languageCode,
    );

    // Only the padding depends on the keyboard inset — scoped via a Builder
    // so keyboard frames re-layout the list's visible rows without
    // rebuilding the whole screen. Dismissal is handled by
    // keyboardDismissBehavior.onDrag alone.
    return Builder(
      builder: (context) => ListView.builder(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: AppDimensions.screenHorizontalPadding,
          right: AppDimensions.screenHorizontalPadding,
          // Safe area / keyboard + the floating bar's *measured* height, so
          // the last rows never hide behind the composer.
          bottom: MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              _bottomBarHeight,
        ),
        // +1 for recommendations, +1 for the complete button
        itemCount: groups.length + 2,
        itemBuilder: (context, index) {
          // ML recommendations at the top — deferred until the push
          // transition settled so its provider work never competes with
          // transition frames.
          if (index == 0) {
            if (!_routeTransitionDone) return const SizedBox.shrink();
            return MLRecommendationsSection(
              listId: widget.listId,
              onAddItem: _addItemFromRecommendation,
            );
          }

          if (index == groups.length + 1) {
            return CompleteShoppingButton(
              onPressed: () => completeShoppingTrip(
                this.context,
                ref,
                listId: widget.listId,
                listName: _currentListName,
                items: items,
              ),
            );
          }

          final group = groups[index - 1];
          return ListCategorySection(
            key: ValueKey(group.id),
            group: group,
            listId: widget.listId,
            dragController: _dragController,
            onEditItem: _showEditItemDialog,
          );
        },
      ),
    );
  }

  /// Messages-style composer riding the keyboard. Wrapped in its own Builder
  /// so ONLY this subtree depends on the per-frame keyboard inset — the
  /// engine animates viewInsets in lockstep with the iOS keyboard, so
  /// positioning the bar at viewInsets.bottom directly moves it on the exact
  /// same curve/frames. The max() keeps the crossover between "resting above
  /// the home indicator" and "riding the keyboard" continuous.
  Widget _buildBottomBar() {
    return Builder(
      builder: (barContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(barContext).bottom;
        final safeBottom = MediaQuery.paddingOf(barContext).bottom;
        final restingBottom = safeBottom > 20 ? safeBottom - 8 : 12.0;
        final riding = keyboardInset + 8;
        return Positioned(
          left: 10,
          right: 10,
          bottom: riding > restingBottom ? riding : restingBottom,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              final isSearching = value.text.trim().length >= 2;
              // Re-measure whenever the bar's composition changes
              // (suggestions appear, composer wraps, …).
              _syncBottomBarHeight();
              return Column(
                key: _bottomBarKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // While searching, show live offer suggestions (debounced
                  // query); otherwise the basket price-comparison summary.
                  // Never both stacked.
                  if (isSearching)
                    ValueListenableBuilder<String>(
                      valueListenable: _offerQuery,
                      builder: (context, query, _) {
                        if (query.length < 2) return const SizedBox.shrink();
                        return OfferSuggestionsBar(
                          query: query,
                          onSelect: _addItemFromOffer,
                        );
                      },
                    )
                  else if (keyboardInset == 0)
                    Consumer(
                      builder: (context, ref, _) => ListPriceSummaryBar(
                        listId: widget.listId,
                        items: ref
                                .watch(itemsNotifierProvider(widget.listId))
                                .valueOrNull ??
                            const <ShoppingItemModel>[],
                      ),
                    ),
                  const SizedBox(height: 6),
                  KeyedSubtree(
                    key: DynamicTutorialService.instance.addItemInputKey,
                    child: AddItemComposer(
                      controller: _searchController,
                      focusNode: _focusNode,
                      plusButtonKey: _plusButtonKey,
                      onSubmit: _quickAddItem,
                      onPlusTap: _openAttachmentSheet,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  void _onMenuSelected(ListDetailMenuAction action) {
    switch (action) {
      case ListDetailMenuAction.rename:
        _showRenameListDialog();
      case ListDetailMenuAction.categoryOrder:
        _showCategoryOrderScreen();
      case ListDetailMenuAction.settings:
        _showListSettingsScreen();
    }
  }

  /// "+" button → attachment sheet → AI extraction → review → import.
  /// Sheets are presented strictly sequentially (each awaited to full
  /// dismissal before the next appears) so nothing ever stacks or flickers.
  Future<void> _openAttachmentSheet() async {
    _focusNode.unfocus();
    final result = await showAttachmentSheet(
      context,
      plusButtonKey: _plusButtonKey,
    );
    if (result == null || !mounted) return;

    final reviewed = await showImportReviewSheet(context, result: result);
    if (reviewed == null || reviewed.isEmpty || !mounted) return;

    await _importReviewedItems(reviewed);
  }

  Future<void> _importReviewedItems(List<ExtractedListItem> reviewed) async {
    final toImport = [
      for (final item in reviewed)
        (name: item.name, quantity: item.quantity ?? 1.0, unit: item.unit),
    ];
    try {
      await ref
          .read(itemsNotifierProvider(widget.listId).notifier)
          .importItems(toImport);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'import_success',
              params: {'count': '${toImport.length}'},
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // Optimistic insert already rolled back — offer a retry.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('import_failed')),
          action: SnackBarAction(
            label: context.tr('import_retry'),
            onPressed: () => _importReviewedItems(reviewed),
          ),
        ),
      );
    }
  }

  bool _dietWarningFor(String name) {
    final user = ref.read(currentUserProvider).value;
    return user != null &&
        DietChecker.checkDietWarning(name, user.dietPreferences);
  }

  void _showAddError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('error_adding', params: {'error': e.toString()}),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _quickAddItem(String name) async {
    try {
      // category: null lets Gemini categorize the item.
      await ref.read(itemsNotifierProvider(widget.listId).notifier).addItem(
            name: name,
            category: null,
            isDietWarning: _dietWarningFor(name),
          );
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Failed to add item "$name": $e');
      _showAddError(e);
    }
  }

  /// Adds a real product from a live retailer offer (see [OfferSuggestionsBar])
  /// to the list, carrying its price/retailer/unit along with it.
  Future<void> _addItemFromOffer(StoreOffer offer) async {
    HapticFeedback.mediumImpact();
    _searchController.clear();
    _focusNode.unfocus();

    try {
      await ref.read(itemsNotifierProvider(widget.listId).notifier).addItem(
            name: offer.productName,
            category: null,
            isDietWarning: _dietWarningFor(offer.productName),
            price: offer.price,
            priceCurrency: 'EUR',
            priceRetailer: offer.retailerName,
            priceUnit: offer.unitSizeLabel ?? offer.unitShortName,
            priceOldValue: offer.regularPrice,
            // The offer already carries the real product name/unit — skip
            // the Gemini ingredient-parse pass so it isn't rewritten.
            autoParse: false,
          );
    } catch (e) {
      _showAddError(e);
    }
  }

  Future<void> _addItemFromRecommendation(
    String? itemName,
    String? category,
    double? quantity,
  ) async {
    if (itemName == null || itemName.isEmpty) return;

    try {
      await ref.read(itemsNotifierProvider(widget.listId).notifier).addItem(
            name: itemName,
            quantity: quantity ?? 1.0,
            category: category,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('item_added_named', params: {'name': itemName}),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showAddError(e);
    }
  }

  void _showAddItemDialog() {
    showItemFormDialog(context, listId: widget.listId);
  }

  void _showEditItemDialog(ShoppingItemModel item) {
    showItemFormDialog(context, listId: widget.listId, item: item);
  }

  Future<void> _showRenameListDialog() async {
    final currentName = _currentListName;
    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => RenameListDialog(initialName: currentName),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;
    try {
      await ref
          .read(listsNotifierProvider.notifier)
          .updateList(widget.listId, {'name': newName});
      if (mounted) setState(() => _listName = newName);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Failed to rename list: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('action_failed'))),
      );
    }
  }

  Future<void> _showCategoryOrderScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CategoryOrderScreen(
          listId: widget.listId,
          listName: _currentListName,
        ),
      ),
    );

    // Order or custom categories changed: regroup, and reload items in case
    // a deleted custom category moved some of them to 'other'.
    if (result == true && mounted) {
      await _loadCustomCategories();
      unawaited(
        ref.read(itemsNotifierProvider(widget.listId).notifier).loadItems(),
      );
    }
  }

  void _showListSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListSettingsScreen(
          listId: widget.listId,
          listName: _currentListName,
          // Null until the lists have loaded; the settings screen then
          // looks the owner up itself.
          ownerId: _listFromProvider()?.ownerId,
        ),
      ),
    );
  }
}
