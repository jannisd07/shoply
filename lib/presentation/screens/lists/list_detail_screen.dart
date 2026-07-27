import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:shoply/core/constants/paper_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_config.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/category_detector.dart';
import 'package:shoply/core/utils/diet_checker.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/data/services/contextual_prompt_service.dart';
import 'package:shoply/data/services/app_review_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/widgets/common/empty_state.dart';
import 'package:shoply/presentation/widgets/common/loading_indicator.dart';
import 'package:shoply/presentation/widgets/recommendations/ml_recommendations_section.dart';
import 'package:shoply/presentation/screens/lists/widgets/background_selection_sheet.dart';
import 'package:shoply/presentation/screens/lists/category_order_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoply/data/services/unread_service.dart'; // Neu
import 'package:flutter_app_badger/flutter_app_badger.dart'; // Neu
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/screens/lists/list_settings_screen.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_price_summary_bar.dart';
import 'package:shoply/presentation/screens/history/widgets/split_cost_sheet.dart';

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
  late String _listName;

  // Debounced copy of the add-bar text used for live offer search, so a
  // fast typer doesn't fire a network request per keystroke.
  final ValueNotifier<String> _offerQuery = ValueNotifier<String>('');
  Timer? _offerQueryDebounce;

  // Drag and drop state
  ShoppingItemModel? _draggedItem;
  String? _draggedFromCategory;
  bool _isDragging = false;

  // Auto-scroll state
  Timer? _autoScrollTimer;
  int _scrollDirection = 0; // -1 = up, 0 = none, 1 = down
  double _scrollSpeed = 0.0;

  // Custom categories cache
  List<CustomCategory> _customCategories = [];
  bool _customCategoriesLoaded = false;

  // Category order cache
  List<String> _categoryOrder = [];

  // List owner info
  String? _ownerId;

  // Key counter for forcing popup menu rebuild after navigation
  int _popupMenuKeyCounter = 0;

  // Review prompt state — ensures we only fire rating prompt once per session
  // when the user completes an entire list (all items checked off).
  bool _listCompletionReviewFired = false;
  int? _lastCheckedCount;

  /// Start the auto-scroll timer
  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _performAutoScroll();
    });
  }

  /// Stop the auto-scroll timer
  void _stopAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollDirection = 0;
    _scrollSpeed = 0.0;
  }

  /// Perform the actual scrolling based on current direction and speed
  void _performAutoScroll() {
    if (!_scrollController.hasClients || _scrollDirection == 0) {
      return;
    }

    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    if (_scrollDirection < 0) {
      // Scrolling up
      if (currentOffset <= 0) return;
      final newOffset = (currentOffset - _scrollSpeed).clamp(0.0, maxOffset);
      _scrollController.jumpTo(newOffset);
    } else if (_scrollDirection > 0) {
      // Scrolling down
      if (currentOffset >= maxOffset) return;
      final newOffset = (currentOffset + _scrollSpeed).clamp(0.0, maxOffset);
      _scrollController.jumpTo(newOffset);
    }
  }

  /// Auto-scroll the list when dragging near edges
  /// This enables users to drag items between categories that are far apart
  void _handleAutoScroll(double globalY) {
    // Always check scroll controller first
    if (!_scrollController.hasClients) {
      debugPrint('🔴 [AUTOSCROLL] No scroll clients!');
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Define scroll zones - larger zones for easier activation
    // Top zone starts right below status bar (not app bar, so we have more area)
    final topEdge = topPadding + 60; // Just below status bar + some margin
    // Bottom zone: above the bottom safe area
    final bottomEdge = screenHeight - bottomPadding - 100;

    // Scroll zone threshold - how close to edge to start scrolling
    const scrollEdgeThreshold = 180.0; // Even larger zone
    // Maximum scroll speed - pixels per frame (at 60fps this is ~1500px/sec)
    const maxScrollSpeed = 25.0;
    // Minimum scroll speed for smooth start
    const minScrollSpeed = 8.0;

    // Calculate distance from edges
    final distanceFromTop = globalY - topEdge;
    final distanceFromBottom = bottomEdge - globalY;

    debugPrint(
      '🔵 [AUTOSCROLL] globalY=$globalY, topEdge=$topEdge, bottomEdge=$bottomEdge, distTop=$distanceFromTop, distBottom=$distanceFromBottom',
    );

    // Top edge detection - scroll up when finger is near top
    if (distanceFromTop < scrollEdgeThreshold) {
      // Calculate speed based on proximity (closer = faster)
      // Use exponential curve for smoother acceleration
      final normalizedDistance = (distanceFromTop / scrollEdgeThreshold).clamp(
        0.0,
        1.0,
      );
      final proximity = 1.0 - normalizedDistance;
      _scrollSpeed =
          minScrollSpeed +
          (maxScrollSpeed - minScrollSpeed) * proximity * proximity;

      if (_scrollDirection != -1) {
        _scrollDirection = -1;
        debugPrint('🔼 [AUTOSCROLL] Starting UP scroll, speed=$_scrollSpeed');
        HapticFeedback.selectionClick();
      }
      if (_autoScrollTimer == null) {
        _startAutoScrollTimer();
      }
    }
    // Bottom edge detection - scroll down when finger is near bottom
    else if (distanceFromBottom < scrollEdgeThreshold) {
      // Calculate speed based on proximity (closer = faster)
      final normalizedDistance = (distanceFromBottom / scrollEdgeThreshold)
          .clamp(0.0, 1.0);
      final proximity = 1.0 - normalizedDistance;
      _scrollSpeed =
          minScrollSpeed +
          (maxScrollSpeed - minScrollSpeed) * proximity * proximity;

      if (_scrollDirection != 1) {
        _scrollDirection = 1;
        debugPrint('🔽 [AUTOSCROLL] Starting DOWN scroll, speed=$_scrollSpeed');
        HapticFeedback.selectionClick();
      }
      if (_autoScrollTimer == null) {
        _startAutoScrollTimer();
      }
    }
    // Not near edges - stop auto-scrolling
    else {
      if (_scrollDirection != 0) {
        debugPrint('⏹️ [AUTOSCROLL] Stopping scroll');
        _scrollDirection = 0;
        _scrollSpeed = 0.0;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _listName = widget.listName;
    _searchController.addListener(_onSearchChangedForOffers);
    // Reload items when entering the list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itemsNotifierProvider(widget.listId).notifier).loadItems();
      // Track this list as last accessed
      ref
          .read(lastAccessedListProvider.notifier)
          .setLastAccessedList(widget.listId);
      _markAsRead(); // Mark as read & clear badge

      // Notify tutorial that list was opened
      DynamicTutorialService.instance.onListOpened();

      // Load custom categories
      _loadCustomCategories();

      // Load list owner info
      _loadListOwner();
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

  Future<void> _loadListOwner() async {
    try {
      final list = await ListRepository.instance.getListById(widget.listId);
      if (mounted && list != null) {
        setState(() => _ownerId = list.ownerId);
      }
    } catch (e) {
      debugPrint('❌ Failed to load list owner: $e');
    }
  }

  Future<void> _loadCustomCategories() async {
    final service = CategoryOrderService();
    final categories = await service.getCustomCategories(widget.listId);
    final order = await service.getCategoryOrder(widget.listId);
    if (mounted) {
      setState(() {
        _customCategories = categories;
        _categoryOrder = order;
        _customCategoriesLoaded = true;
      });
    }
  }

  Future<void> _markAsRead() async {
    // 1. Internen Status (roter Punkt) löschen
    await UnreadService().markAsRead(widget.listId);

    // 2. App Icon Badge löschen
    try {
      if (await FlutterAppBadger.isAppBadgeSupported()) {
        FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      debugPrint('Failed to remove badge: $e');
    }

    // 3. Notifications löschen (für sauberes Notification Center)
    await NotificationService.instance.cancelAll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _offerQueryDebounce?.cancel();
    _searchController.removeListener(_onSearchChangedForOffers);
    _searchController.dispose();
    _offerQuery.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsNotifierProvider(widget.listId));

    // Detect when the user completes an entire shopping list (all items checked).
    // This is a genuine positive moment — the perfect time to ask for a rating.
    ref.listen<AsyncValue<List<ShoppingItemModel>>>(
      itemsNotifierProvider(widget.listId),
      (previous, next) {
        final items = next.asData?.value;
        if (items == null || items.isEmpty) return;
        final checked = items.where((i) => i.isChecked).length;
        final allChecked = checked == items.length;
        final prevCount = _lastCheckedCount;
        _lastCheckedCount = checked;

        if (allChecked &&
            prevCount != null &&
            prevCount < items.length &&
            !_listCompletionReviewFired) {
          _listCompletionReviewFired = true;
          // Fire and forget — respects AppReviewService throttling internally.
          AppReviewService.instance.trackPositiveAction('completed_list');
          Future.delayed(const Duration(milliseconds: 800), () {
            AppReviewService.instance.maybeRequestReview(
              reason: 'completed_list',
            );
          });
        }
      },
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _listName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PaperTextStyles.serif(
                24,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (itemsAsync.valueOrNull != null &&
                itemsAsync.valueOrNull!.isNotEmpty)
              Text(
                '${itemsAsync.valueOrNull!.where((i) => !i.isChecked).length} ${context.tr('items_open_suffix')} · ${itemsAsync.valueOrNull!.length} ${context.tr('items')}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
          ],
        ),
        leading: PlatformInfo.isIOS26OrHigher()
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: AdaptiveButton.icon(
                      icon: Icons.chevron_left,
                      style: AdaptiveButtonStyle.glass,
                      size: AdaptiveButtonSize.small,
                      minSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      useSmoothRectangleBorder: false,
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
        actions: [
          // Settings button
          if (PlatformInfo.isIOS26OrHigher())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AdaptivePopupMenuButton.icon<int>(
                key: ValueKey('settings_popup_$_popupMenuKeyCounter'),
                icon: 'ellipsis.circle',
                size: 36,
                buttonStyle: PopupButtonStyle.glass,
                items: [
                  AdaptivePopupMenuItem<int>(
                    label: context.tr('rename_list'),
                    icon: 'pencil',
                    value: 0,
                  ),
                  AdaptivePopupMenuItem<int>(
                    label: context.tr('change_background'),
                    icon: 'photo',
                    value: 1,
                  ),
                  AdaptivePopupMenuItem<int>(
                    label: context.tr('category_order'),
                    icon: 'arrow.up.arrow.down',
                    value: 2,
                  ),
                  AdaptivePopupMenuItem<int>(
                    label: context.tr('list_settings'),
                    icon: 'gearshape',
                    value: 3,
                  ),
                ],
                onSelected: (index, entry) async {
                  setState(() {
                    _popupMenuKeyCounter++;
                  });

                  final selected = entry.value;
                  if (selected == null) return;

                  if (selected == 0) {
                    _showRenameListDialog();
                  } else if (selected == 1) {
                    _showBackgroundSelectionDialog();
                  } else if (selected == 2) {
                    _showCategoryOrderScreen();
                  } else if (selected == 3) {
                    _showListSettingsScreen();
                  }
                },
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                showCupertinoModalPopup<void>(
                  context: context,
                  builder: (ctx) => CupertinoActionSheet(
                    actions: [
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRenameListDialog();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.pencil, size: 20),
                            const SizedBox(width: 10),
                            Text(context.tr('rename_list')),
                          ],
                        ),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showBackgroundSelectionDialog();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.photo, size: 20),
                            const SizedBox(width: 10),
                            Text(context.tr('change_background')),
                          ],
                        ),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCategoryOrderScreen();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.arrow_up_arrow_down,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(context.tr('category_order')),
                          ],
                        ),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showListSettingsScreen();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.gear, size: 20),
                            const SizedBox(width: 10),
                            Text(context.tr('list_settings')),
                          ],
                        ),
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      isDefaultAction: true,
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('cancel')),
                    ),
                  ),
                );
              },
            ),
          // Share button
          if (PlatformInfo.isIOS26OrHigher())
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 36,
                height: 36,
                child: AdaptiveButton.icon(
                  icon: Icons.ios_share,
                  style: AdaptiveButtonStyle.glass,
                  size: AdaptiveButtonSize.small,
                  minSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  useSmoothRectangleBorder: false,
                  onPressed: _showShareDialog,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.ios_share,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _showShareDialog,
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
                child: Builder(
                  builder: (context) {
                    final items = itemsAsync.valueOrNull ?? [];
                    final total = items.length;
                    final done = items.where((i) => i.isChecked).length;
                    final progress = total > 0 ? done / total : 0.0;
                    return Container(
                      height: 3,
                      color: AppColors.divider(context),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(
                          color: AppColors.accentColor(context),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Items List
              Expanded(
            key: DynamicTutorialService.instance.listItemsAreaKey,
            child: itemsAsync.when(
              data: (items) {
                // Update tutorial with list items data
                DynamicTutorialService.instance.updateListItemsData(
                  hasItems: items.isNotEmpty,
                );
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.shopping_cart,
                    title: AppLocalizations.of(context).emptyList,
                    subtitle:
                        'Füge Produkte hinzu, um mit dem Einkaufen zu beginnen',
                    actionText: AppLocalizations.of(context).addItem,
                    onActionPressed: () => _showAddItemDialog(context),
                  );
                }

                // Group items by category
                final groupedItems = _groupItemsByCategory(items);

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Keyboard schließen beim Scrollen
                    if (notification is ScrollStartNotification) {
                      FocusScope.of(context).unfocus();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: AppDimensions.screenHorizontalPadding,
                      right: AppDimensions.screenHorizontalPadding,
                      // Safe area + floating add bar height
                      bottom: MediaQuery.of(context).padding.bottom + 96,
                    ),
                    itemCount:
                        groupedItems.length +
                        2, // +1 for recommendations, +1 for Complete Button
                    itemBuilder: (context, index) {
                      // ML-powered AI Recommendations Section at the top
                      if (index == 0) {
                        return MLRecommendationsSection(
                          listId: widget.listId,
                          onAddItem: (itemName, category, quantity) {
                            _addItemFromRecommendation(
                              itemName,
                              category,
                              quantity,
                            );
                          },
                        );
                      }

                      // Complete Shopping Button am Ende — Paper ink pill
                      if (index == groupedItems.length + 1) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 24),
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _completeShoppingTrip(context, ref, items),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? PaperColors.paper
                                    : PaperColors.ink,
                                foregroundColor: isDark
                                    ? PaperColors.ink
                                    : PaperColors.paper,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).completeShopping,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final entry =
                          groupedItems[index -
                              1]; // -1 because recommendations is at index 0
                      final category = entry['category'] as String;
                      final categoryId = entry['category_id'] as String;
                      final categoryItems =
                          entry['items'] as List<ShoppingItemModel>;
                      final categoryColor = entry['category_color'] as Color;
                      final categoryIcon = entry['category_icon'] as IconData;
                      final isCustomCategory = entry['is_custom'] as bool;

                      return _buildCategorySection(
                        category: category,
                        categoryId: categoryId,
                        categoryItems: categoryItems,
                        categoryColor: categoryColor,
                        categoryIcon: categoryIcon,
                        isCustomCategory: isCustomCategory,
                      );
                    },
                  ),
                );
              },
                  loading: () =>
                      LoadingIndicator(message: context.tr('loading_items')),
                  error: (error, stack) =>
                      Center(child: Text('Error: $error')),
                ),
              ),
            ],
          ),

          // Floating paper add bar hugging the bottom edge (no navbar).
          Positioned(
            left: 10,
            right: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? 8
                : (MediaQuery.of(context).padding.bottom > 20
                      ? MediaQuery.of(context).padding.bottom - 8
                      : 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                final liveQuery = value.text.trim();
                final isSearching = liveQuery.length >= 2;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // While searching, show live offer suggestions (debounced
                    // query so fast typing doesn't fire an API call per
                    // keystroke); otherwise the basket price-comparison
                    // summary. Never both stacked.
                    if (isSearching)
                      ValueListenableBuilder<String>(
                        valueListenable: _offerQuery,
                        builder: (context, query, _) {
                          if (query.length < 2) {
                            return const SizedBox.shrink();
                          }
                          return OfferSuggestionsBar(
                            query: query,
                            onSelect: _addItemFromOffer,
                          );
                        },
                      )
                    else if (MediaQuery.of(context).viewInsets.bottom == 0)
                      Consumer(
                        builder: (context, ref, _) {
                          final items = ref
                                  .watch(itemsNotifierProvider(widget.listId))
                                  .valueOrNull ??
                              const <ShoppingItemModel>[];
                          return ListPriceSummaryBar(
                            listId: widget.listId,
                            items: items,
                          );
                        },
                      ),
                    _buildPaperAddBar(context),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Paper-style floating add bar: plus, text field, AI-sort hint, action.
  Widget _buildPaperAddBar(BuildContext context) {
    return Container(
      key: DynamicTutorialService.instance.addItemInputKey,
      height: 54,
      padding: const EdgeInsets.only(left: 18, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.add, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: false,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).addItem,
                hintStyle: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  final itemName = value.trim();
                  _searchController
                      .clear(); // Clear FIRST to prevent re-triggering
                  _quickAddItem(itemName);
                  // Keep focus in text field after adding
                  _focusNode.requestFocus();
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: AppColors.accentColor(context),
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr('ai_sorts_label'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.accentColor(context),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final prefill = _searchController.text.trim();
              _searchController.clear();
              _focusNode.unfocus();
              _showAddItemDialog(context, prefill: prefill);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Icon(
                Icons.mic_none,
                size: 18,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Build a category section with drag target for receiving items
  Widget _buildCategorySection({
    required String category,
    required String categoryId,
    required List<ShoppingItemModel> categoryItems,
    required Color categoryColor,
    required IconData categoryIcon,
    required bool isCustomCategory,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DragTarget<ShoppingItemModel>(
      onWillAcceptWithDetails: (details) {
        // Accept if dragged from a different category
        return _draggedFromCategory != categoryId;
      },
      onAcceptWithDetails: (details) async {
        final item = details.data;
        // Update item's category
        await ref
            .read(itemsNotifierProvider(widget.listId).notifier)
            .updateItem(item.id, {'category_id': categoryId});
        // Record preference so AI learns the user's category choice
        CategoryDetector.recordUserCategoryChange(item.name, category);
        HapticFeedback.mediumImpact();
        setState(() {
          _isDragging = false;
          _draggedItem = null;
          _draggedFromCategory = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: isHovering
              ? BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                )
              : null,
          padding: isHovering ? const EdgeInsets.all(8) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header - paper kicker style
              if (category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppDimensions.spacingLarge,
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              // Items List or empty state for custom categories
              if (categoryItems.isEmpty && isCustomCategory)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : PaperColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : PaperColors.hairline,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.grey.shade600
                            : PaperColors.faint,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('drag_items_here'),
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : PaperColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoryItems.length,
                      itemBuilder: (context, index) {
                        return _buildDraggableItemTile(
                          categoryItems[index],
                          index,
                          categoryId,
                        );
                      },
                    ),
                    // Drop zone AFTER the last item so users can move
                    // items to the very end of a category.
                    DragTarget<ShoppingItemModel>(
                      onWillAcceptWithDetails: (details) {
                        if (categoryItems.isEmpty) return true;
                        // Accept if the dragged item isn't already last in this category
                        return details.data.id != categoryItems.last.id;
                      },
                      onAcceptWithDetails: (details) async {
                        final draggedItem = details.data;
                        final fromCat = _draggedFromCategory;
                        final notifier = ref.read(
                          itemsNotifierProvider(widget.listId).notifier,
                        );

                        if (fromCat != categoryId) {
                          // Cross-category: change category first
                          await notifier.updateItem(draggedItem.id, {
                            'category_id': categoryId,
                          });
                        }
                        // Place after the last item in this category.
                        if (categoryItems.isNotEmpty) {
                          await notifier.reorderItemAfter(
                            draggedItem.id,
                            categoryItems.last.id,
                          );
                        }
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isDragging = false;
                          _draggedItem = null;
                          _draggedFromCategory = null;
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovering = candidateData.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: isHovering ? 40 : 20,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: isHovering
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.accentColor(
                                      context,
                                    ).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                )
                              : null,
                          child: isHovering
                              ? Center(
                                  child: Container(
                                    width: 40,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.accentColor(
                                        context,
                                      ).withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _groupItemsByCategory(
    List<ShoppingItemModel> items,
  ) {
    // Get user's language
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;

    // Group items by category ID (including custom categories)
    final Map<String, List<ShoppingItemModel>> categoryMap = {};

    // First, add all custom categories (even empty ones) so they're always visible
    for (final customCat in _customCategories) {
      categoryMap[customCat.id] = [];
    }

    for (final item in items) {
      // Prefer new category_id field, fallback to legacy category field
      String categoryId = item.categoryId ?? item.category ?? 'other';

      // If it's not a valid built-in ID and not a custom ID, try to convert name → ID
      if (!Categories.allIds.contains(categoryId) &&
          !categoryId.startsWith('custom_')) {
        categoryId =
            Categories.getIdByName(categoryId, languageCode) ?? 'other';
      }

      if (!categoryMap.containsKey(categoryId)) {
        categoryMap[categoryId] = [];
      }
      categoryMap[categoryId]!.add(item);
    }

    // Build sorted list using saved category order
    final sortedCategories = <String>[];

    // If we have a saved category order, use it
    if (_categoryOrder.isNotEmpty) {
      // Add categories in saved order (only if they have items or are custom)
      for (final categoryId in _categoryOrder) {
        final hasItems =
            categoryMap.containsKey(categoryId) &&
            categoryMap[categoryId]!.isNotEmpty;
        final isCustom = categoryId.startsWith('custom_');
        if (hasItems || isCustom) {
          sortedCategories.add(categoryId);
        }
      }

      // Add any categories with items that weren't in the saved order (new categories)
      for (final categoryId in categoryMap.keys) {
        if (!sortedCategories.contains(categoryId) &&
            categoryMap[categoryId]!.isNotEmpty) {
          sortedCategories.add(categoryId);
        }
      }
    } else {
      // Fallback: custom categories first, then built-in categories
      for (final customCat in _customCategories) {
        if (!sortedCategories.contains(customCat.id)) {
          sortedCategories.add(customCat.id);
        }
      }

      // Then add built-in categories that have items
      for (final category in Categories.all) {
        if (categoryMap.containsKey(category.id) &&
            categoryMap[category.id]!.isNotEmpty) {
          sortedCategories.add(category.id);
        }
      }
    }

    // Convert to list of maps for ListView
    return sortedCategories.map((categoryId) {
      // Sort items by order_index within each category
      final categoryItems = categoryMap[categoryId] ?? [];
      final sortedItems = List<ShoppingItemModel>.from(categoryItems);
      sortedItems.sort((a, b) {
        final aIndex = a.orderIndex ?? a.sortOrder ?? 999;
        final bIndex = b.orderIndex ?? b.sortOrder ?? 999;
        return aIndex.compareTo(bIndex);
      });

      // Get category display info
      String categoryName;
      Color categoryColor;
      IconData categoryIcon;
      bool isCustom = false;

      if (categoryId.startsWith('custom_')) {
        // Find the custom category
        final customCat = _customCategories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => CustomCategory(
            id: categoryId,
            name: 'Unknown',
            color: Colors.grey,
          ),
        );
        categoryName = customCat.name;
        categoryColor = customCat.color;
        categoryIcon = Icons.label_rounded;
        isCustom = true;
      } else {
        final categoryData = Categories.getById(categoryId);
        categoryName = categoryData.getName(languageCode);
        categoryColor = categoryData.color;
        categoryIcon = categoryData.icon;
      }

      return {
        'category': categoryName,
        'category_id': categoryId,
        'category_color': categoryColor,
        'category_icon': categoryIcon,
        'is_custom': isCustom,
        'items': sortedItems,
      };
    }).toList();
  }

  void _quickAddItem(String name) async {
    print('🚀🚀🚀 [LIST_DETAIL] _quickAddItem CALLED for "$name"');
    print('🚀 [LIST_DETAIL] listId: ${widget.listId}');

    try {
      final user = ref.read(currentUserProvider).value;

      // Let Gemini handle categorization automatically (category: null)
      // ItemRepository will call GeminiCategorizationService if category is null

      final isDietWarning = user != null
          ? DietChecker.checkDietWarning(name, user.dietPreferences)
          : false;

      print('🚀 [LIST_DETAIL] Calling itemsNotifierProvider.addItem...');
      await ref
          .read(itemsNotifierProvider(widget.listId).notifier)
          .addItem(
            name: name,
            category: null, // Let Gemini categorize automatically
            isDietWarning: isDietWarning,
          );

      print('✅ [LIST_DETAIL] Successfully added item: $name');
    } catch (e) {
      print('❌ [LIST_DETAIL] Failed to add item "$name": $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_adding', params: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Note: No need to invalidate listsNotifierProvider - the itemsNotifierProvider
    // already handles state updates and the list count will update automatically
  }

  /// Adds a real product from a live retailer offer (see [OfferSuggestionsBar])
  /// to the list, carrying its price/retailer/unit along with it.
  void _addItemFromOffer(StoreOffer offer) async {
    HapticFeedback.mediumImpact();
    _searchController.clear();
    _focusNode.unfocus();

    try {
      final user = ref.read(currentUserProvider).value;
      final isDietWarning = user != null
          ? DietChecker.checkDietWarning(offer.productName, user.dietPreferences)
          : false;

      await ref.read(itemsNotifierProvider(widget.listId).notifier).addItem(
            name: offer.productName,
            category: null,
            isDietWarning: isDietWarning,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_adding', params: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddItemDialog(BuildContext context, {String prefill = ''}) {
    // Dismiss keyboard from the search bar before opening the sheet
    FocusManager.instance.primaryFocus?.unfocus();

    final nameController = TextEditingController(text: prefill);
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    String? selectedUnit;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : PaperColors.surface;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : PaperColors.paper;
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
              ),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header row with title and X button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context).addItem,
                                style: PaperTextStyles.serif(22, color: fg),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: muted.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          TextField(
                            controller: nameController,
                            style: TextStyle(color: fg, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).itemName,
                              hintStyle: TextStyle(
                                color: muted.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            autofocus: prefill.isEmpty,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 12),

                          // Quantity field
                          TextField(
                            controller: quantityController,
                            style: TextStyle(color: fg, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).quantity,
                              hintStyle: TextStyle(
                                color: muted.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 12),

                          // Unit pill selector
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['pcs', 'kg', 'g', 'l', 'ml', 'pack'].map(
                              (unit) {
                                final isSelected = selectedUnit == unit;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedUnit = isSelected ? null : unit;
                                    });
                                    HapticFeedback.selectionClick();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black)
                                          : fillColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unit,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDark
                                                  ? Colors.black
                                                  : Colors.white)
                                            : muted,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            controller: notesController,
                            style: TextStyle(color: fg, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).notes,
                              hintStyle: TextStyle(
                                color: muted.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 24),

                          // Monochrome CTA
                          GestureDetector(
                            onTap: () async {
                              if (nameController.text.trim().isEmpty) return;

                              final name = nameController.text.trim();

                              try {
                                final user = ref
                                    .read(currentUserProvider)
                                    .value;

                                final isDietWarning = user != null
                                    ? DietChecker.checkDietWarning(
                                        name,
                                        user.dietPreferences,
                                      )
                                    : false;

                                await ref
                                    .read(
                                      itemsNotifierProvider(
                                        widget.listId,
                                      ).notifier,
                                    )
                                    .addItem(
                                      name: name,
                                      quantity:
                                          double.tryParse(
                                            quantityController.text,
                                          ) ??
                                          1.0,
                                      unit: selectedUnit,
                                      category: null,
                                      notes: notesController.text.trim().isEmpty
                                          ? null
                                          : notesController.text.trim(),
                                      isDietWarning: isDietWarning,
                                    );

                                Navigator.pop(context);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.tr(
                                        'error_adding',
                                        params: {'error': e.toString()},
                                      ),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context).addItem,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.black : Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchUserInfo(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final response = await SupabaseService.instance.client
          .from('users')
          .select('display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('❌ Failed to fetch user info: $e');
      return null;
    }
  }

  void _showEditItemDialog(BuildContext context, ShoppingItemModel item) {
    final nameController = TextEditingController(text: item.name);
    final quantityText = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    final quantityController = TextEditingController(text: quantityText);
    final notesController = TextEditingController(text: item.notes ?? '');
    String selectedUnit = item.unit ?? 'pcs';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : PaperColors.surface;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : PaperColors.paper;
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
              ),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context).editItem,
                                style: PaperTextStyles.serif(22, color: fg),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: muted.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Added By Section
                          if (item.addedBy != null && item.addedBy!.isNotEmpty)
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _fetchUserInfo(item.addedBy),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 10,
                                        color: muted,
                                      ),
                                    ),
                                  );
                                }

                                final userInfo = snapshot.data;
                                final displayName =
                                    userInfo?['display_name'] as String? ??
                                    context.tr('unknown_user');
                                final avatarUrl =
                                    userInfo?['avatar_url'] as String?;
                                final userId = item.addedBy!;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push(
                                      '/author/$userId',
                                      extra: {'authorName': displayName},
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fillColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: muted.withValues(
                                            alpha: 0.15,
                                          ),
                                          backgroundImage:
                                              avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child:
                                              avatarUrl == null ||
                                                  avatarUrl.isEmpty
                                              ? Text(
                                                  displayName.isNotEmpty
                                                      ? displayName[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: fg,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.tr('added_by'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: muted,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                displayName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: fg,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: muted,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Name Field
                          TextField(
                            controller: nameController,
                            style: TextStyle(color: fg, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).itemName,
                              hintStyle: TextStyle(
                                color: muted.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 12),

                          // Quantity field
                          TextField(
                            controller: quantityController,
                            style: TextStyle(color: fg, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).quantity,
                              hintStyle: TextStyle(
                                color: muted.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Unit pill selector
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: Categories.units.map((unit) {
                              final isSelected = selectedUnit == unit;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedUnit = isSelected ? 'pcs' : unit;
                                  });
                                  HapticFeedback.selectionClick();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : fillColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unit,
                                    style: TextStyle(
                                      color: isSelected
                                          ? (isDark
                                                ? Colors.black
                                                : Colors.white)
                                          : muted,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 12),

                          // Notes Field
                          TextField(
                            controller: notesController,
                            style: TextStyle(color: fg, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).notes,
                              hintStyle: TextStyle(
                                color: muted.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              // Delete Button
                              GestureDetector(
                                onTap: () async {
                                  await ref
                                      .read(
                                        itemsNotifierProvider(
                                          widget.listId,
                                        ).notifier,
                                      )
                                      .deleteItem(item.id);
                                  ref.invalidate(listsNotifierProvider);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade400,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Save Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final quantity =
                                        double.tryParse(
                                          quantityController.text,
                                        ) ??
                                        1.0;
                                    ref
                                        .read(
                                          itemsNotifierProvider(
                                            widget.listId,
                                          ).notifier,
                                        )
                                        .updateItem(item.id, {
                                          'name': nameController.text.trim(),
                                          'quantity': quantity,
                                          'unit': selectedUnit,
                                          'notes':
                                              notesController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : notesController.text.trim(),
                                        });
                                    ref.invalidate(listsNotifierProvider);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.of(context).save,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShareDialog() async {
    try {
      final code = await ref
          .read(listsNotifierProvider.notifier)
          .generateShareCode(widget.listId);

      if (!mounted) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final fg = AppColors.textPrimary(context);
      final muted = AppColors.textSecondary(context);
      final dim = AppColors.textTertiary(context);

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).shareCodeTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  AppLocalizations.of(context).shareCodeMessage,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Code display
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('code_copied')),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.copy_rounded, size: 18, color: dim),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  context.tr('tap_to_copy'),
                  style: TextStyle(color: dim, fontSize: 12),
                ),
                const SizedBox(height: 24),

                // Share buttons row
                Row(
                  children: [
                    // Share Code button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _shareListViaSystem(code);
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.numbers_rounded,
                                  size: 18,
                                  color: fg,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Share Link button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _shareListViaLink();
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Link',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.black : Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_generic', params: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showShareCodeDialog() async {
    try {
      final code = await ref
          .read(listsNotifierProvider.notifier)
          .generateShareCode(widget.listId);

      AdaptiveAlertDialog.show(
        context: context,
        title: AppLocalizations.of(context).shareCodeTitle,
        message: '${AppLocalizations.of(context).shareCodeMessage}\n\n$code',
        icon: PlatformInfo.isIOS26OrHigher() ? 'qrcode' : Icons.qr_code,
        actions: [
          AlertAction(
            title: AppLocalizations.of(context).cancel,
            style: AlertActionStyle.cancel,
            onPressed: () {},
          ),
          AlertAction(
            title: AppLocalizations.of(context).copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
            },
          ),
          AlertAction(
            title: AppLocalizations.of(context).share,
            style: AlertActionStyle.primary,
            onPressed: () {
              _shareListViaSystem(code);
            },
          ),
        ],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_generic', params: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onShareSelected() async {
    try {
      // Ask for notification permission the first time a list is shared.
      // Users want to know when collaborators update the list.
      if (await ContextualPromptService.instance.shouldShowNotifPrompt()) {
        if (!mounted) return;
        await ContextualPromptService.instance.showNotifPrompt(context);
        if (!mounted) return;
      }

      final code = await ref
          .read(listsNotifierProvider.notifier)
          .generateShareCode(widget.listId);

      AdaptiveAlertDialog.show(
        context: context,
        title: AppLocalizations.of(context).shareDialogTitle,
        message: AppLocalizations.of(context).shareDialogMessage(code),
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'square.and.arrow.up'
            : Icons.ios_share,
        actions: [
          AlertAction(
            title: AppLocalizations.of(context).cancel,
            style: AlertActionStyle.cancel,
            onPressed: () {},
          ),
          AlertAction(
            title: AppLocalizations.of(context).share,
            onPressed: () {
              _shareListViaSystem(code);
            },
          ),
          AlertAction(
            title: AppLocalizations.of(context).copyAndContinue,
            style: AlertActionStyle.primary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              _shareListViaSystem(code);
            },
          ),
        ],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_generic', params: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _addItemFromRecommendation(
    String? itemName,
    String? category,
    double? quantity,
  ) async {
    if (itemName == null || itemName.isEmpty) return;

    try {
      await ref
          .read(itemsNotifierProvider(widget.listId).notifier)
          .addItem(
            name: itemName,
            quantity: quantity ?? 1.0,
            category: category,
          );

      if (mounted) {
        // Note: No need to invalidate - the itemsNotifierProvider handles state updates

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$itemName zur Liste hinzugefügt'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _completeShoppingTrip(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingItemModel> items,
  ) async {
    // Filter only checked items
    final checkedItems = items.where((item) => item.isChecked).toList();

    if (checkedItems.isEmpty) {
      AdaptiveAlertDialog.show(
        context: context,
        title: context.tr('no_checked_items'),
        message: context.tr('no_checked_items_message'),
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'exclamationmark.circle.fill'
            : Icons.info_outline,
        iconColor: Colors.orange,
        actions: [
          AlertAction(
            title: context.tr('ok'),
            style: AlertActionStyle.primary,
            onPressed: () {},
          ),
        ],
      );
      return;
    }

    // Show confirmation dialog
    bool confirmed = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: context.tr('complete_shopping_question'),
      message: context.tr(
        'complete_shopping_checked_message',
        params: {'count': checkedItems.length.toString()},
      ),
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'checkmark.circle.fill'
          : Icons.check_circle_outline,
      iconColor: AppColors.success,
      actions: [
        AlertAction(
          title: AppLocalizations.of(context).cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: context.tr('complete_btn'),
          style: AlertActionStyle.primary,
          onPressed: () {
            confirmed = true;
          },
        ),
      ],
    );

    if (!confirmed) return;

    try {
      // Save only checked items to history. Purchase tracking (for the
      // "you usually buy X every N days" nudges) happens inside this call —
      // it used to also be called again right here, silently double-counting
      // every completed trip's items in item_purchase_stats.
      final historyService = ShoppingHistoryService();
      final historyEntry = await historyService.completeShoppingTrip(
        listId: widget.listId,
        listName: widget.listName,
        items: checkedItems,
      );

      // Delete only checked items from the list
      final itemIds = checkedItems.map((item) => item.id).toList();
      await SupabaseService.instance
          .from('shopping_items')
          .delete()
          .inFilter('id', itemIds);

      // 🔔 Send notification to all list members about shopping completion
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          final userId = SupabaseService.instance.currentUser?.id;
          if (userId != null) {
            await _sendShoppingCompleteNotifications(
              widget.listId,
              widget.listName,
              checkedItems.length,
              userId,
            );
          }
        } catch (e) {
          debugPrint('⚠️ Failed to send shopping complete notifications: $e');
        }
      }

      // Refresh the items list and home screen
      ref.invalidate(itemsNotifierProvider(widget.listId));
      ref.invalidate(listsNotifierProvider);

      // On a trip-count milestone (10th, 25th, … trip), the confirmation
      // becomes a small celebration instead of the generic line.
      String? milestone;
      try {
        milestone = await MascotNotificationService.instance
            .milestoneMessageForCompletedTrip();
      } catch (_) {}

      // Offer an immediate "split this trip" shortcut when the list has
      // someone else to split with — the home-screen SplitTripNudgeCard
      // covers the same case for anyone who doesn't act on it right now.
      var canSplit = false;
      try {
        final members =
            await ref.read(listRepositoryProvider).getListMembers(widget.listId);
        canSplit = members.length >= 2;
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              milestone ??
                  '✅ ${checkedItems.length} Artikel erfolgreich abgeschlossen!',
            ),
            backgroundColor: AppColors.success,
            duration: canSplit
                ? const Duration(seconds: 6)
                : (milestone != null
                    ? const Duration(seconds: 5)
                    : const Duration(seconds: 4)),
            action: canSplit
                ? SnackBarAction(
                    label: context.tr('split_trip_cost'),
                    textColor: Colors.white,
                    onPressed: () =>
                        showSplitCostSheet(context, ref, entry: historyEntry),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_completing', params: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRenameListDialog() {
    final nameController = TextEditingController(
      text: _listName ?? widget.listName,
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.tr('rename_list_title')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: nameController,
            autofocus: true,
            placeholder: context.tr('list_name'),
            textCapitalization: TextCapitalization.sentences,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != widget.listName) {
                try {
                  await ref.read(listsNotifierProvider.notifier).updateList(
                    widget.listId,
                    {'name': newName},
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {
                      _listName = newName;
                    });
                    ref.invalidate(listsNotifierProvider);
                  }
                } catch (e) {
                  if (mounted) Navigator.pop(ctx);
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_list_question')),
        content: Text(
          context.tr(
            'delete_list_message',
            params: {'listName': widget.listName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(context);

              try {
                print(
                  '🗑️ Deleting list: ${widget.listName} (${widget.listId})',
                );

                // Delete the list
                await ref
                    .read(listsNotifierProvider.notifier)
                    .deleteList(widget.listId);

                print('✅ List deleted successfully');

                if (mounted) {
                  // Refresh the lists
                  ref.invalidate(listsNotifierProvider);

                  // Navigate to home page
                  context.go('/home');

                  print('✅ Navigated to home page');

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr(
                          'list_deleted',
                          params: {'name': widget.listName},
                        ),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                print('❌ Failed to delete list: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr(
                          'error_deleting',
                          params: {'error': e.toString()},
                        ),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }

  /// Send shopping complete notifications to all list members
  Future<void> _sendShoppingCompleteNotifications(
    String listId,
    String listName,
    int itemCount,
    String completedByUserId,
  ) async {
    try {
      debugPrint('🔔 [LIST_DETAIL] Sending shopping complete notifications...');

      // Get all list members except the person who completed the shopping
      final membersResponse = await SupabaseService.instance
          .from('list_members')
          .select('user_id')
          .eq('list_id', listId)
          .neq('user_id', completedByUserId);

      debugPrint(
        '🔔 [LIST_DETAIL] Found ${(membersResponse as List).length} members to notify',
      );

      // Get the name of the person who completed the shopping
      final completerResponse = await SupabaseService.instance
          .from('users')
          .select('display_name')
          .eq('id', completedByUserId)
          .single();

      final completerName =
          completerResponse['display_name'] as String? ?? 'Someone';

      // Send FCM push notification to each member
      for (final member in membersResponse) {
        final memberId = member['user_id'] as String;

        try {
          // Get user's FCM token and display name
          final userResponse = await SupabaseService.instance
              .from('users')
              .select('fcm_token, display_name')
              .eq('id', memberId)
              .single();

          final fcmToken = userResponse['fcm_token'] as String?;

          if (fcmToken != null && fcmToken.isNotEmpty) {
            // Send via Supabase Edge Function
            await SupabaseService.instance.client.functions.invoke(
              'send-push-notification',
              body: {
                'token': fcmToken,
                'notification': {
                  'title': 'Shopping Complete!',
                  'body': '$completerName completed shopping for "$listName"',
                },
                'data': {'type': 'shopping_complete', 'listId': listId},
              },
            );

            debugPrint('✅ [LIST_DETAIL] Sent push notification to member');
          }
        } catch (e) {
          debugPrint('⚠️ [LIST_DETAIL] Failed to send push to member: $e');
        }
      }

      debugPrint(
        '✅ Sent shopping complete notifications to ${membersResponse.length} members',
      );
    } catch (e) {
      debugPrint('❌ Failed to send shopping complete notifications: $e');
    }
  }

  /// Build a draggable item tile with tap zones:
  /// - Left 2/3: tap to toggle check
  /// - Right 1/3: tap to edit (with pencil icon in quantity box)
  /// - Long press: start drag to move to different category OR reorder
  ///   within the same category (drop onto another item)
  Widget _buildDraggableItemTile(
    ShoppingItemModel item,
    int index,
    String categoryId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Each item is also a DragTarget so we can reorder within a category
    // AND accept cross-category drops directly onto an item position.
    return DragTarget<ShoppingItemModel>(
      onWillAcceptWithDetails: (details) => details.data.id != item.id,
      onAcceptWithDetails: (details) async {
        final draggedItem = details.data;
        final fromCat = _draggedFromCategory;
        if (fromCat == categoryId) {
          // ── Same category → reorder ──
          await ref
              .read(itemsNotifierProvider(widget.listId).notifier)
              .reorderItemToPosition(draggedItem.id, item.id);
          HapticFeedback.lightImpact();
        } else {
          // ── Different category → move to this category at this position ──
          await ref
              .read(itemsNotifierProvider(widget.listId).notifier)
              .updateItem(draggedItem.id, {'category_id': categoryId});
          // Then reorder so it lands at this item's position
          await ref
              .read(itemsNotifierProvider(widget.listId).notifier)
              .reorderItemToPosition(draggedItem.id, item.id);
          HapticFeedback.mediumImpact();
        }
        setState(() {
          _isDragging = false;
          _draggedItem = null;
          _draggedFromCategory = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Insertion indicator line when another item hovers here
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: isHovering ? 3 : 0,
              margin: isHovering
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isHovering
                    ? AppColors.accentColor(context).withValues(alpha: 0.7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Listener(
              onPointerMove: (event) {
                if (_isDragging) _handleAutoScroll(event.position.dy);
              },
              child: LongPressDraggable<ShoppingItemModel>(
                data: item,
                delay: const Duration(milliseconds: 300),
                onDragStarted: () {
                  debugPrint('🎯 [DRAG] Started dragging item: ${item.name}');
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isDragging = true;
                    _draggedItem = item;
                    _draggedFromCategory = categoryId;
                  });
                },
                onDragUpdate: (details) {
                  _handleAutoScroll(details.globalPosition.dy);
                },
                onDragEnd: (details) {
                  debugPrint('🎯 [DRAG] Drag ended');
                  _stopAutoScrollTimer();
                  setState(() {
                    _isDragging = false;
                    _draggedItem = null;
                    _draggedFromCategory = null;
                  });
                },
                onDraggableCanceled: (_, __) {
                  debugPrint('🎯 [DRAG] Drag cancelled');
                  _stopAutoScrollTimer();
                  setState(() {
                    _isDragging = false;
                    _draggedItem = null;
                    _draggedFromCategory = null;
                  });
                },
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 64,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentColor(
                        context,
                      ).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit ?? ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildItemTileContent(item, isDark),
                ),
                child: Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    HapticFeedback.heavyImpact();
                    return true;
                  },
                  onDismissed: (direction) async {
                    await ref
                        .read(itemsNotifierProvider(widget.listId).notifier)
                        .deleteItem(item.id);
                    ref.invalidate(listsNotifierProvider);
                    if (context.mounted) {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${item.name} ${context.tr('deleted')}',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                  child: _buildItemTileContent(item, isDark),
                ),
              ), // LongPressDraggable
            ), // Listener
          ],
        );
      },
    ); // DragTarget
  }

  /// The actual content of an item tile with 2/3 check zone and 1/3 edit zone
  Widget _buildItemTileContent(ShoppingItemModel item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider(context), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            // LEFT 2/3 ZONE: Tap to check/uncheck
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(itemsNotifierProvider(widget.listId).notifier)
                      .toggleItemChecked(item.id, !item.isChecked);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 13, 8, 13),
                  child: Row(
                    children: [
                      // Checkbox - paper circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: item.isChecked
                              ? AppColors.accentColor(context)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.isChecked
                                ? AppColors.accentColor(context)
                                : AppColors.textTertiary(context),
                            width: 1.5,
                          ),
                        ),
                        child: item.isChecked
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      // Item name and notes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textTertiary(
                                  context,
                                ),
                                color: item.isChecked
                                    ? AppColors.textTertiary(context)
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.notes!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : PaperColors.muted,
                                ),
                              ),
                            ],
                            if (item.hasPrice) ...[
                              const SizedBox(height: 3),
                              Text(
                                [
                                  '${item.price!.toStringAsFixed(2)} €',
                                  if (item.priceUnit != null) item.priceUnit!,
                                  if (item.priceRetailer != null)
                                    item.priceRetailer!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accentColor(context),
                                ),
                              ),
                            ],
                            if (!item.isChecked)
                              Consumer(
                                builder: (context, chipRef, _) {
                                  final comparison = chipRef
                                      .watch(basketComparisonProvider(
                                          widget.listId))
                                      .valueOrNull;
                                  final offer = comparison
                                      ?.cheapestOfferFor(item.name.trim());
                                  if (offer == null ||
                                      !ItemOfferChip.isWorthShowing(
                                          item, offer)) {
                                    return const SizedBox.shrink();
                                  }
                                  return ItemOfferChip(
                                    item: item,
                                    offer: offer,
                                    onTap: () => showItemOfferSheet(
                                      context,
                                      ref: ref,
                                      listId: widget.listId,
                                      item: item,
                                      offer: offer,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // RIGHT ZONE: Tap to edit item
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _showEditItemDialog(context, item);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}${item.unit != null && item.unit!.isNotEmpty ? ' ${item.unit}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: item.isChecked
                            ? AppColors.textTertiary(context)
                            : AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: AppColors.textTertiary(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickEditPopup(BuildContext context, ShoppingItemModel item) {
    double quantity = item.quantity;
    final notesController = TextEditingController(text: item.notes ?? '');

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: Text(item.name),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                // Quantity stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 36,
                      onPressed: quantity > 1
                          ? () {
                              setDialogState(() => quantity--);
                              HapticFeedback.selectionClick();
                            }
                          : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.minus, size: 18),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '${quantity % 1 == 0 ? quantity.toInt() : quantity}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 36,
                      onPressed: () {
                        setDialogState(() => quantity++);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.plus, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Notes field
                CupertinoTextField(
                  controller: notesController,
                  placeholder: 'Notiz hinzufügen',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(itemsNotifierProvider(widget.listId).notifier)
                    .updateItem(item.id, {
                      'quantity': quantity,
                      'notes': notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    });
                HapticFeedback.mediumImpact();
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  /// Old method kept for compatibility but should not be used
  Widget _buildItemTile(ShoppingItemModel item, int index) {
    return _buildDraggableItemTile(item, index, 'other');
  }

  void _showBackgroundSelectionDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BackgroundSelectionSheet(listId: widget.listId),
      ),
    );
  }

  void _showCategoryOrderScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            CategoryOrderScreen(listId: widget.listId, listName: _listName),
      ),
    );

    // If categories were reordered, refresh the items list and reload custom categories
    if (result == true) {
      await _loadCustomCategories();
      ref.invalidate(itemsNotifierProvider(widget.listId));
      setState(() {});
    }
  }

  void _showListSettingsScreen() {
    if (_ownerId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListSettingsScreen(
          listId: widget.listId,
          listName: _listName,
          ownerId: _ownerId!,
        ),
      ),
    );
  }

  void _shareListViaSystem([String? code]) {
    final base = 'Schau dir meine Einkaufsliste "${widget.listName}" an!';
    final withCode = code != null && code.isNotEmpty
        ? '\n\nTrete mit diesem Code bei: $code\nÖffne Avo und tippe auf "Liste beitreten".'
        : '\n\nLade Avo herunter und trete meiner Liste bei.';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      '$base$withCode',
      subject: 'Meine Avo Einkaufsliste',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100),
    );
  }

  void _shareListViaLink() {
    final webLink = 'https://shoplyai.app/list/${widget.listId}';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      '🛒 ${widget.listName}\n\n$webLink',
      subject: widget.listName,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100),
    );
  }
}
