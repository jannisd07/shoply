import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/screens/history/shopping_history_screen.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/core/services/siri_service.dart';
import 'package:shoply/core/utils/category_detector.dart';
import 'package:shoply/presentation/screens/home/widgets/list_card_with_animation.dart';
import 'package:shoply/presentation/screens/home/widgets/greeting_header.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/core/utils/display_name_helper.dart';
import 'package:shoply/presentation/widgets/common/success_alert.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasAutoOpened = false;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _lastUserId = SupabaseService.instance.currentUser?.id;
    
    // Lade Listen sofort beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listsNotifierProvider.notifier).loadLists();
      _autoOpenLastList();
      _checkSiriPendingItems();
    });
    
    // Auth-Listener für User-Wechsel
    SupabaseService.instance.client.auth.onAuthStateChange.listen((data) {
      final newUserId = data.session?.user.id;
      if (_lastUserId != newUserId && mounted) {
        setState(() {
          _lastUserId = newUserId;
        });
        
        // Lade Listen neu
        ref.read(listsNotifierProvider.notifier).loadLists();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Prüfe bei jeder Navigation ob sich der User geändert hat
    final currentUserId = SupabaseService.instance.currentUser?.id;
    if (_lastUserId != currentUserId) {
      _lastUserId = currentUserId;
      
      // Lade Listen IMMER neu (auch bei null)
      Future.microtask(() {
        ref.read(listsNotifierProvider.notifier).loadLists();
        // Also refresh shopping history
        ref.invalidate(recentHistoryProvider);
      });
    }
  }

  @override
  void activate() {
    super.activate();
    // Wird aufgerufen wenn der Screen wieder aktiv wird (z.B. nach Tab-Wechsel)
    // Nur neu laden wenn bereits initialisiert
    if (_lastUserId != null) {
      Future.microtask(() {
        ref.read(listsNotifierProvider.notifier).loadLists();
        // Also refresh shopping history
        ref.invalidate(recentHistoryProvider);
      });
    }
  }

  Future<void> _checkSiriPendingItems() async {
    try {
      final siriService = SiriService();
      final pendingItems = await siriService.getPendingItems();
      
      if (pendingItems.isEmpty) return;
      
      String? targetListId;
      String? targetListName;
      
      for (final item in pendingItems) {
        final itemName = item['itemName'] as String;
        final listName = item['listName'] as String;
        final quantity = item['quantity'] as double? ?? 1.0;
        
        // Find or create the list
        final listsAsync = ref.read(listsNotifierProvider);
        await listsAsync.whenData((lists) async {
          var targetList = lists.cast<dynamic>().firstWhere(
            (l) => l.name.toLowerCase() == listName.toLowerCase(),
            orElse: () => null,
          );
          
          // Create list if it doesn't exist
          if (targetList == null) {
            await ref.read(listsNotifierProvider.notifier).createList(listName);
            
            // Wait a moment for the list to be created
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Refresh and get the new list
            ref.invalidate(listsNotifierProvider);
            await Future.delayed(const Duration(milliseconds: 300));
            
            final newLists = ref.read(listsNotifierProvider).value;
            if (newLists != null) {
              targetList = newLists.cast<dynamic>().firstWhere(
                (l) => l.name.toLowerCase() == listName.toLowerCase(),
                orElse: () => null,
              );
            }
          }
          
          if (targetList != null) {
            targetListId = targetList.id;
            targetListName = targetList.name;
            
            // Detect category
            final category = await CategoryDetector.detectCategory(itemName);
            
            // Add item to list
            await ref.read(itemsNotifierProvider(targetList.id).notifier).addItem(
              name: itemName,
              quantity: quantity,
              category: category,
            );
          }
        });
      }
      
      // Refresh the lists view
      if (mounted) {
        ref.invalidate(listsNotifierProvider);
        
        // Navigate to the list after a short delay
        if (targetListId != null && targetListName != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            final listId = targetListId!;
            final listName = targetListName!;
            context.push('/lists/$listId?name=${Uri.encodeComponent(listName)}');
          }
        }
      }
    } catch (e) {
      // Silently handle Siri errors
    }
  }

  Future<void> _autoOpenLastList() async {
    if (_hasAutoOpened) return;
    _hasAutoOpened = true;

    final lastListAsync = ref.read(lastAccessedListProvider);
    final listsAsync = ref.read(listsNotifierProvider);

    lastListAsync.whenData((lastListId) {
      if (lastListId != null && mounted) {
        listsAsync.whenData((lists) {
          final list = lists.cast<dynamic>().firstWhere(
            (l) => l.id == lastListId,
            orElse: () => null,
          );
          if (list != null && mounted) {
            context.push('/lists/$lastListId?name=${Uri.encodeComponent(list.name)}');
          }
        });
      }
    });
  }

  // Native iOS-style refresh indicator with smooth animation
  Widget _buildRefreshIndicator(
    BuildContext context,
    RefreshIndicatorMode refreshState,
    double percentageComplete,
    double pulledExtent,
  ) {
    const Curve opacityCurve = Interval(0.4, 1.0, curve: Curves.easeInOut);
    
    return Opacity(
      opacity: opacityCurve.transform(percentageComplete),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: () {
          switch (refreshState) {
            case RefreshIndicatorMode.drag:
              // Beim Ziehen: Zeige Fortschritt
              return CupertinoActivityIndicator.partiallyRevealed(
                progress: percentageComplete,
              );
            case RefreshIndicatorMode.armed:
            case RefreshIndicatorMode.refresh:
              // Beim Laden: Voller Spinner
              return const CupertinoActivityIndicator();
            case RefreshIndicatorMode.done:
              // Fertig: Spinner mit Fade-out
              return const CupertinoActivityIndicator();
            default:
              return const SizedBox.shrink();
          }
        }(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsNotifierProvider);
    final userData = ref.watch(currentUserProvider).value;
    final displayName = DisplayNameHelper.getDisplayName(userData?.displayName);
    final avatarUrl = userData?.avatarUrl;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            FocusScope.of(context).unfocus();
          }
          return false;
        },
        child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Native iOS Pull-to-Refresh - MUSS erstes Sliver sein!
          CupertinoSliverRefreshControl(
            refreshTriggerPullDistance: 100.0,
            refreshIndicatorExtent: 60.0,
            builder: (
              BuildContext context,
              RefreshIndicatorMode refreshState,
              double pulledExtent,
              double refreshTriggerPullDistance,
              double refreshIndicatorExtent,
            ) {
              final double percentageComplete = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
              
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: pulledExtent > 0 ? pulledExtent - 40 : 0,
                    child: Center(
                      child: _buildRefreshIndicator(
                        context,
                        refreshState,
                        percentageComplete,
                        pulledExtent,
                      ),
                    ),
                  ),
                ],
              );
            },
            onRefresh: () async {
              ref.invalidate(listsNotifierProvider);
              await Future.delayed(const Duration(milliseconds: 800));
            },
          ),
          // Safe Area nach dem Refresh Control
          SliverSafeArea(
            top: true,
            bottom: false,
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // Collapsing Header (Hallo + Avatar)
          SliverPersistentHeader(
              delegate: GreetingHeader(
                displayName: displayName,
                avatarUrl: avatarUrl,
                onAvatarTap: () => context.go('/profile'),
              ),
              pinned: false,
              floating: false,
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingMedium),
            ),

            // Listen-Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('your_lists'),
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                    AdaptivePopupMenuButton.text<String>(
                      label: '+ ${context.tr('new')}',
                      buttonStyle: PopupButtonStyle.glass,
                      shrinkWrap: true,
                      items: [
                        AdaptivePopupMenuItem(
                          label: context.tr('create_new_list'),
                          icon: PlatformInfo.isIOS26OrHigher() ? 'plus.circle.fill' : Icons.add_circle,
                          value: 'new',
                        ),
                        AdaptivePopupMenuItem(
                          label: context.tr('join_list'),
                          icon: PlatformInfo.isIOS26OrHigher() ? 'person.2.fill' : Icons.group_add,
                          value: 'join',
                        ),
                      ],
                      onSelected: (index, item) {
                        if (item.value == 'new') {
                          _showCreateListDialog(context, ref);
                        } else if (item.value == 'join') {
                          _showJoinListDialog(context, ref);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingMedium),
            ),

            // Horizontale Listen
            SliverToBoxAdapter(
              child: listsAsync.when(
                data: (lists) {
                  final tutorial = DynamicTutorialService.instance;
                  
                  if (lists.isEmpty) {
                    // If tutorial is active and no lists, auto-create one
                    if (tutorial.isActive && tutorial.currentStepId == TutorialStepId.openShoppingList) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        try {
                          await ref.read(listsNotifierProvider.notifier).createList('Meine erste Liste');
                        } catch (e) {
                          debugPrint('Error creating tutorial list: $e');
                        }
                      });
                    }
                    
                    // Update tutorial that there are no lists
                    tutorial.updateListsData(hasLists: false, firstListId: null);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.screenHorizontalPadding,
                      ),
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
                        ),
                        child: Center(
                          child: Text(
                            'Noch keine Listen erstellt',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final sortedLists = [...lists]..sort((a, b) =>
                      b.updatedAt.compareTo(a.updatedAt));

                  return SizedBox(
                    height: 140 * 1.75,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.screenHorizontalPadding,
                      ),
                      itemCount: sortedLists.length,
                      itemBuilder: (context, index) {
                        final list = sortedLists[index];
                        final tutorial = DynamicTutorialService.instance;
                        final isFirstList = index == 0;
                        
                        // Update tutorial with user data
                        if (isFirstList) {
                          tutorial.updateListsData(hasLists: true, firstListId: list.id);
                        }
                        
                        return _buildListCard(
                          context,
                          ref,
                          list.id,
                          list.name,
                          list.itemCount ?? 0,
                          list.getBackgroundType(),
                          list.getBackgroundValue(),
                          list.backgroundImageUrl,
                          list.updatedAt,
                          () {
                            context.push('/lists/${list.id}?name=${Uri.encodeComponent(list.name)}');
                            // Complete tutorial step if this is the first list
                            if (isFirstList && tutorial.isActive && 
                                tutorial.currentStepId == TutorialStepId.openShoppingList) {
                              tutorial.completeCurrentStep();
                            }
                          },
                          tutorialKey: isFirstList ? tutorial.firstListCardKey : null,
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 140,
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.screenHorizontalPadding,
                  ),
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
                    ),
                    child: const Center(child: Text('Fehler beim Laden')),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingLarge),
            ),

            // Einkaufshistorie - Matching full page design
            SliverToBoxAdapter(
              child: const _ShoppingHistorySection(),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingXLarge),
            ),

            // Extra Bottom Padding für Navigation Bar + Safe Area
            // Safe Area am Ende
            SliverSafeArea(
              top: false,
              bottom: true,
              sliver: SliverPadding(
                padding: const EdgeInsets.only(bottom: 200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateListDialog(BuildContext context, WidgetRef ref) async {
    final result = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: context.tr('create_new_list'),
      message: context.tr('enter_list_name_prompt'),
      icon: PlatformInfo.isIOS26OrHigher() ? 'list.bullet.circle.fill' : Icons.list_alt,
      input: AdaptiveAlertDialogInput(
        placeholder: context.tr('enter_list_name'),
        initialValue: '',
        keyboardType: TextInputType.text,
      ),
      actions: [
        AlertAction(
          title: context.tr('cancel'),
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: context.tr('create'),
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await ref
            .read(listsNotifierProvider.notifier)
            .createList(result.trim());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('list_created'))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('error')}: $e')),
          );
        }
      }
    }
  }

  void _showJoinListDialog(BuildContext context, WidgetRef ref) async {
    final result = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: context.tr('join_list'),
      message: context.tr('enter_share_code'),
      icon: PlatformInfo.isIOS26OrHigher() ? 'person.2.fill' : Icons.group,
      input: AdaptiveAlertDialogInput(
        placeholder: context.tr('share_code'),
        initialValue: '',
        keyboardType: TextInputType.text,
      ),
      actions: [
        AlertAction(
          title: context.tr('cancel'),
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: context.tr('join'),
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );

    if (result != null && result.trim().isNotEmpty) {
      final shareCode = result.trim().toUpperCase();
      
      try {
        final list = await ref
            .read(listsNotifierProvider.notifier)
            .joinListWithCode(shareCode);
        
        if (!context.mounted) return;
        
        if (list != null) {
          AdaptiveAlertDialog.show(
            context: context,
            title: context.tr('joined_successfully'),
            message: context.tr('joined_list_message', params: {'listName': list.name}),
            icon: PlatformInfo.isIOS26OrHigher() ? 'checkmark.circle.fill' : Icons.check_circle,
            iconColor: Colors.green,
            actions: [
              AlertAction(
                title: context.tr('ok'),
                style: AlertActionStyle.primary,
                onPressed: () {},
              ),
            ],
          );
        } else {
          AdaptiveAlertDialog.show(
            context: context,
            title: context.tr('error'),
            message: context.tr('invalid_share_code'),
            icon: PlatformInfo.isIOS26OrHigher() ? 'xmark.circle.fill' : Icons.error,
            iconColor: Colors.red,
            actions: [
              AlertAction(
                title: context.tr('ok'),
                style: AlertActionStyle.cancel,
                onPressed: () {},
              ),
            ],
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        
        AdaptiveAlertDialog.show(
          context: context,
          title: context.tr('error'),
          message: '${context.tr('join_error')}: $e',
          icon: PlatformInfo.isIOS26OrHigher() ? 'exclamationmark.triangle.fill' : Icons.warning,
          iconColor: Colors.orange,
          actions: [
            AlertAction(
              title: context.tr('ok'),
              style: AlertActionStyle.cancel,
              onPressed: () {},
            ),
          ],
        );
      }
    }
  }

  // removed custom glass dialog helper in favor of AdaptiveAlertDialog.inputShow

  Future<bool?> _showDeleteConfirmation(BuildContext context, String listName, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final completer = Completer<bool?>();
    
    AdaptiveAlertDialog.show(
      context: context,
      title: localizations.deleteListTitle,
      message: localizations.deleteListMessage(listName),
      icon: PlatformInfo.isIOS26OrHigher() ? 'trash.fill' : Icons.delete,
      iconSize: 48,
      iconColor: Colors.red,
      actions: [
        AlertAction(
          title: localizations.cancel,
          onPressed: () {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
          style: AlertActionStyle.cancel,
        ),
        AlertAction(
          title: localizations.deleteConfirm,
          onPressed: () {
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
          style: AlertActionStyle.destructive,
        ),
      ],
    );
    
    return completer.future;
  }

  Widget _buildListCard(
    BuildContext context,
    WidgetRef ref,
    String listId,
    String name,
    int itemCount,
    String backgroundType,
    String? backgroundValue,
    String? backgroundImageUrl,
    DateTime? updatedAt,
    VoidCallback onTap, {
    GlobalKey? tutorialKey,
  }) {
    return ListCardWithAnimation(
      tutorialKey: tutorialKey,
      listId: listId,
      name: name,
      itemCount: itemCount,
      backgroundType: backgroundType,
      backgroundValue: backgroundValue,
      backgroundImageUrl: backgroundImageUrl,
      updatedAt: updatedAt,
      onTap: onTap,
      onLongPress: () async {
        // 🎯 Haptisches Feedback
        HapticFeedback.mediumImpact();
        
        // Zeige AdaptiveAlertDialog
        final shouldDelete = await _showDeleteConfirmation(context, name, ref);
        
        if (shouldDelete == true) {
          ref.read(listsNotifierProvider.notifier).deleteList(listId);
        }
      },
    );
  }
}

/// Shopping history section - minimalist design matching .windsurfrules
class _ShoppingHistorySection extends ConsumerStatefulWidget {
  const _ShoppingHistorySection();

  @override
  ConsumerState<_ShoppingHistorySection> createState() => _ShoppingHistorySectionState();
}

class _ShoppingHistorySectionState extends ConsumerState<_ShoppingHistorySection> {
  final Set<String> _expandedEntries = {};

  /// Format date: Today, Yesterday, or d. MMM (e.g. 20. Nov)
  String _formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);
    final locale = Localizations.localeOf(context).languageCode;
    
    if (entryDate == today) {
      return context.tr('today');
    } else if (entryDate == yesterday) {
      return context.tr('yesterday');
    } else {
      return DateFormat('d. MMM', locale).format(date);
    }
  }

  Future<void> _addAllItemsToList(List<ShoppingHistoryItem> items, String listId, String listName) async {
    HapticFeedback.mediumImpact();

    try {
      await Future.wait(
        items.map((item) => ref.read(itemsNotifierProvider(listId).notifier).addItem(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          category: item.category,
        )),
      );

      if (mounted) {
        SuccessAlert.showItemsAdded(
          context,
          count: items.length,
          listName: listName,
        );
      }
    } catch (e) {
      debugPrint('Add all items failed: $e');
      if (mounted) {
        SuccessAlert.show(
          context,
          title: context.tr('error_adding_items'),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(recentHistoryProvider);
    final listsAsync = ref.watch(listsNotifierProvider);
    final lists = listsAsync.hasValue ? listsAsync.value! : [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenHorizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - minimalist
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('shopping_history'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShoppingHistoryScreen(),
                      ),
                    );
                  },
                  child: Text(
                    context.tr('see_all'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          historyAsync.when(
            loading: () => SizedBox(
              height: 80,
              child: Center(
                child: CupertinoActivityIndicator(color: isDark ? Colors.white38 : Colors.black26, radius: 10),
              ),
            ),
            error: (_, __) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('loading_error'),
                    style: TextStyle(
                      color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            data: (history) {
              if (history.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.05) 
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('no_shopping_history'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('completed_trips_appear_here'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Vertical list - limited to 3 entries
              final limitedHistory = history.take(3).toList();
              return Column(
                children: limitedHistory.map((entry) => 
                  _buildHistoryCard(entry, lists, isDark)
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ShoppingHistory entry, List<dynamic> lists, bool isDark) {
    final isExpanded = _expandedEntries.contains(entry.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main card content
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedEntries.remove(entry.id);
                } else {
                  _expandedEntries.add(entry.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Content - no icon, just text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List name
                        Text(
                          entry.listName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Date and person - properly laid out to prevent cutoff
                        Row(
                          children: [
                            // Date
                            Text(
                              _formatDate(entry.completedAt, context),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                              ),
                            ),
                            // Person name (if available)
                            if (entry.completedByName != null) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  entry.completedByName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Item count - minimal badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.08) 
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.totalItems}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded items section
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _HomeExpandedItemsContent(
              entry: entry,
              lists: lists,
              onAddAllItems: _addAllItemsToList,
              isDark: isDark,
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Expanded items content for homepage history cards - minimalist design
class _HomeExpandedItemsContent extends ConsumerStatefulWidget {
  final ShoppingHistory entry;
  final List<dynamic> lists;
  final Future<void> Function(List<ShoppingHistoryItem> items, String listId, String listName) onAddAllItems;
  final bool isDark;

  const _HomeExpandedItemsContent({
    required this.entry,
    required this.lists,
    required this.onAddAllItems,
    required this.isDark,
  });

  @override
  ConsumerState<_HomeExpandedItemsContent> createState() => _HomeExpandedItemsContentState();
}

class _HomeExpandedItemsContentState extends ConsumerState<_HomeExpandedItemsContent> {
  String? _selectedListId;
  final Set<String> _addedItemIds = {};
  bool _isAddingAll = false;

  @override
  void initState() {
    super.initState();
    if (widget.lists.isNotEmpty) {
      _selectedListId = widget.lists.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant _HomeExpandedItemsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fix: when lists load after initial build, set selectedListId
    if (_selectedListId == null && widget.lists.isNotEmpty) {
      setState(() {
        _selectedListId = widget.lists.first.id;
      });
    }
    // Also fix: if previously selected list was removed, reset selection
    if (_selectedListId != null && widget.lists.isNotEmpty) {
      final stillExists = widget.lists.any((l) => l.id == _selectedListId);
      if (!stillExists) {
        setState(() {
          _selectedListId = widget.lists.first.id;
        });
      }
    }
  }

  Future<void> _addSingleItem(ShoppingHistoryItem item) async {
    if (_selectedListId == null) {
      debugPrint('⚠️ [History] _selectedListId is null, cannot add item');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _addedItemIds.add(item.id);
    });

    try {
      await ref.read(itemsNotifierProvider(_selectedListId!).notifier).addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
      );
      debugPrint('✅ [History] Added "${item.name}" to list $_selectedListId');

      if (mounted) {
        final selectedList = widget.lists.firstWhere((l) => l.id == _selectedListId);
        SuccessAlert.showItemAdded(
          context,
          listName: selectedList.name,
        );
      }
    } catch (e) {
      debugPrint('❌ [History] Add single item failed: $e');
      if (mounted) {
        setState(() {
          _addedItemIds.remove(item.id);
        });
        SuccessAlert.show(
          context,
          title: context.tr('error_adding_items'),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
        );
      }
    }
  }

  Future<void> _addAllItems() async {
    if (_selectedListId == null) {
      debugPrint('⚠️ [History] _selectedListId is null, cannot add all items');
      return;
    }

    setState(() {
      _isAddingAll = true;
      for (final item in widget.entry.items) {
        _addedItemIds.add(item.id);
      }
    });

    try {
      final selectedList = widget.lists.firstWhere((l) => l.id == _selectedListId);
      await widget.onAddAllItems(widget.entry.items, _selectedListId!, selectedList.name);
    } catch (e) {
      debugPrint('❌ [History] Add all items failed: $e');
      if (mounted) {
        // Roll back added state on error
        setState(() {
          for (final item in widget.entry.items) {
            _addedItemIds.remove(item.id);
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        _isAddingAll = false;
      });
    }
  }

  Widget _buildListCard(dynamic list, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedListId = list.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
              : (widget.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                list.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Subtle divider
        Container(
          height: 0.5,
          color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
        ),
        
        // Horizontal scroll list selector
        if (widget.lists.isNotEmpty && widget.entry.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('add_to_list').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                // Horizontal scrolling list cards
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.lists.length,
                    itemBuilder: (context, index) {
                      final list = widget.lists[index];
                      final isSelected = list.id == _selectedListId;
                      return _buildListCard(list, isSelected);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Add all button - minimal style
                GestureDetector(
                  onTap: _selectedListId == null || _isAddingAll ? null : _addAllItems,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedListId == null 
                          ? (widget.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02))
                          : (widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isAddingAll)
                          CupertinoActivityIndicator(radius: 10, color: widget.isDark ? Colors.white70 : const Color(0xFF6B7280),
                          )
                        else
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _selectedListId == null 
                                ? (widget.isDark ? const Color(0xFF4B4B4B) : const Color(0xFFD1D5DB))
                                : (widget.isDark ? Colors.white70 : const Color(0xFF6B7280)),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '${context.tr('add_all')} (${widget.entry.items.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedListId == null 
                                ? (widget.isDark ? const Color(0xFF4B4B4B) : const Color(0xFFD1D5DB))
                                : (widget.isDark ? Colors.white70 : const Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Items list
        if (widget.entry.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              children: widget.entry.items.take(10).map((item) {
                final isAdded = _addedItemIds.contains(item.id);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isAdded 
                          ? (widget.isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FDF4))
                          : (widget.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Item name and quantity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                              if (item.quantity > 1 || item.unit != null)
                                Text(
                                  '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}${item.unit != null ? ' ${item.unit}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Add button
                        if (widget.lists.isNotEmpty && _selectedListId != null)
                          GestureDetector(
                            onTap: isAdded ? null : () => _addSingleItem(item),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isAdded
                                    ? const Color(0xFF22C55E)
                                    : (widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isAdded ? Icons.check_rounded : Icons.add_rounded,
                                size: 16,
                                color: isAdded 
                                    ? Colors.white 
                                    : (widget.isDark ? Colors.white70 : const Color(0xFF6B7280)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        
        // Show more items indicator
        if (widget.entry.items.length > 10)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              '+${widget.entry.items.length - 10} ${context.tr('more_items')}',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        
        // Empty state
        if (widget.entry.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              context.tr('no_items'),
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF),
              ),
            ),
          ),
      ],
    );
  }
}
