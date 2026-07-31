import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/screens/history/shopping_history_screen.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/presentation/screens/home/widgets/greeting_header.dart';
import 'package:shoply/presentation/screens/home/home_nudge_card_order.dart';
import 'package:shoply/presentation/screens/home/widgets/avo_nudge_card.dart';
import 'package:shoply/presentation/screens/home/widgets/personal_flyer_card.dart';
import 'package:shoply/presentation/screens/home/widgets/calorie_recipe_nudge_card.dart';
import 'package:shoply/presentation/screens/home/widgets/pending_splits_banner.dart';
import 'package:shoply/presentation/screens/home/widgets/price_comparison_nudge_card.dart';
import 'package:shoply/presentation/screens/home/widgets/split_trip_nudge_card.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/core/utils/display_name_helper.dart';
import 'package:shoply/data/services/widget_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasAutoOpened = false;
  bool _isCreatingTutorialList = false;
  String? _lastUserId;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _lastUserId = SupabaseService.instance.currentUser?.id;

    // Lade Listen sofort beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listsNotifierProvider.notifier).loadLists();
      _autoOpenLastList();
      _syncWidgetCredentials();
      unawaited(_ensureTutorialListExists());
    });

    DynamicTutorialService.instance.addListener(_handleTutorialChange);

    // Auth-Listener für User-Wechsel
    _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange
        .listen((data) {
      final newUserId = data.session?.user.id;
      if (_lastUserId != newUserId && mounted) {
        setState(() {
          _lastUserId = newUserId;
        });

        // Lade Listen neu
        ref.read(listsNotifierProvider.notifier).loadLists();
        _syncWidgetCredentials();
      }
    });
  }

  @override
  void dispose() {
    DynamicTutorialService.instance.removeListener(_handleTutorialChange);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleTutorialChange() {
    unawaited(_ensureTutorialListExists());
  }

  Future<void> _ensureTutorialListExists() async {
    if (_isCreatingTutorialList || !mounted) return;

    final tutorial = DynamicTutorialService.instance;
    if (!tutorial.isActive ||
        tutorial.currentStepId != TutorialStepId.openShoppingList) {
      return;
    }

    var lists = ref.read(listsNotifierProvider).value;
    if (lists == null) {
      await ref.read(listsNotifierProvider.notifier).loadLists();
      if (!mounted) return;
      lists = ref.read(listsNotifierProvider).value;
    }

    if (lists == null) return;

    if (lists.isNotEmpty) {
      final sortedLists = [...lists]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      tutorial.updateListsData(
        hasLists: true,
        firstListId: sortedLists.first.id,
      );
      return;
    }

    _isCreatingTutorialList = true;
    try {
      final list = await ref
          .read(listsNotifierProvider.notifier)
          .createList('Meine erste Liste');
      tutorial.updateListsData(hasLists: true, firstListId: list.id);
    } catch (e) {
      debugPrint('Error creating tutorial list: $e');
    } finally {
      _isCreatingTutorialList = false;
    }
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

  void _syncWidgetCredentials() {
    unawaited(WidgetService.syncCredentialsFromSession());
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
            context.push(
              '/lists/$lastListId?name=${Uri.encodeComponent(list.name)}',
            );
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
              builder:
                  (
                    BuildContext context,
                    RefreshIndicatorMode refreshState,
                    double pulledExtent,
                    double refreshTriggerPullDistance,
                    double refreshIndicatorExtent,
                  ) {
                    final double percentageComplete =
                        (pulledExtent / refreshTriggerPullDistance).clamp(
                          0.0,
                          1.0,
                        );

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

            // Avo hint strip (paper cream box)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenHorizontalPadding,
                  8,
                  AppDimensions.screenHorizontalPadding,
                  0,
                ),
                child: GestureDetector(
                  onTap: () => context.push('/avo'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFE8DA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.eco_outlined,
                          size: 16,
                          color: PaperColors.sageInk,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('avo_hint_home'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5A5346),
                            ),
                          ),
                        ),
                        Text(
                          context.tr('show_label'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: PaperColors.terracotta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: PendingSplitsBanner()),

            // Proactive nudge cards: "Split [list]'s trip?", Avo's restock
            // reminder, "N kcal left — dinner ideas", and "this list is €X
            // cheaper at [store]". Each renders nothing when it has no
            // relevant data, so reordering them by what the user said
            // matters to them during onboarding (Feature 7's "what kind of
            // user are they" priorities) is always safe — nothing is ever
            // hidden, only reordered. Users with no priorities set (skipped
            // onboarding, or onboarded before this existed) see the
            // original fixed order unchanged.
            ...orderedHomeNudgeCards(userData?.appPriorities.toSet() ?? {})
                .map((kind) => SliverToBoxAdapter(child: _homeNudgeCard(kind))),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingLarge),
            ),

            // Listen-Header: kicker + terracotta text action
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      context.tr('your_lists').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    // Tap: create list. Long-press: join a shared list.
                    GestureDetector(
                      onTap: () => _showCreateListDialog(context, ref),
                      onLongPress: () => _showJoinListDialog(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        context.tr('new_list_plus'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentColor(context),
                        ),
                      ),
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
                    if (tutorial.isActive &&
                        tutorial.currentStepId ==
                            TutorialStepId.openShoppingList) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        unawaited(_ensureTutorialListExists());
                      });
                    }

                    // Update tutorial that there are no lists
                    tutorial.updateListsData(
                      hasLists: false,
                      firstListId: null,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.screenHorizontalPadding,
                      ),
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.cardBorderRadius,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            context.tr('no_lists_yet'),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final sortedLists = [...lists]
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                  // Paper editorial index: numbered vertical rows with
                  // hairline progress instead of horizontal cards.
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.screenHorizontalPadding,
                    ),
                    child: Column(
                      children: [
                        for (
                          int index = 0;
                          index < sortedLists.length;
                          index++
                        )
                          Builder(
                            builder: (context) {
                              final list = sortedLists[index];
                              final isFirstList = index == 0;

                              // Update tutorial with user data
                              if (isFirstList) {
                                tutorial.updateListsData(
                                  hasLists: true,
                                  firstListId: list.id,
                                );
                              }

                              return _PaperListRow(
                                key: ValueKey(list.id),
                                index: index,
                                name: list.name,
                                itemCount: list.itemCount ?? 0,
                                uncheckedCount: list.uncheckedCount,
                                isShared: list.isShared,
                                tutorialKey: isFirstList
                                    ? tutorial.firstListCardKey
                                    : null,
                                onTap: () {
                                  context.push(
                                    '/lists/${list.id}?name=${Uri.encodeComponent(list.name)}',
                                  );
                                  // Complete tutorial step if this is the first list
                                  if (isFirstList &&
                                      tutorial.isActive &&
                                      tutorial.currentStepId ==
                                          TutorialStepId.openShoppingList) {
                                    tutorial.completeCurrentStep();
                                  }
                                },
                                onLongPress: () async {
                                  HapticFeedback.mediumImpact();
                                  final shouldDelete =
                                      await _showDeleteConfirmation(
                                    context,
                                    list.name,
                                    ref,
                                  );
                                  if (shouldDelete == true) {
                                    ref
                                        .read(listsNotifierProvider.notifier)
                                        .deleteList(list.id);
                                  }
                                },
                              );
                            },
                          ),
                      ],
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
                      borderRadius: BorderRadius.circular(
                        AppDimensions.cardBorderRadius,
                      ),
                    ),
                    child: Center(child: Text(context.tr('loading_error'))),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingLarge),
            ),

            // Angebote strip (paper cream block)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: PaperColors.cream,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('deals_kicker').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                                color: PaperColors.creamInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('deals_teaser'),
                              style: PaperTextStyles.serif(
                                14,
                                color: const Color(0xFF4A4232),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: PaperColors.creamInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingLarge),
            ),

            // Aktivitätszeile -> Einkaufsverlauf
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShoppingHistoryScreen(),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.divider(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 15,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LatestActivityLine(),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textTertiary(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'list.bullet.circle.fill'
          : Icons.list_alt,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.tr('list_created'))));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${context.tr('error')}: $e')));
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
            message: context.tr(
              'joined_list_message',
              params: {'listName': list.name},
            ),
            icon: PlatformInfo.isIOS26OrHigher()
                ? 'checkmark.circle.fill'
                : Icons.check_circle,
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
            icon: PlatformInfo.isIOS26OrHigher()
                ? 'xmark.circle.fill'
                : Icons.error,
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
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'exclamationmark.triangle.fill'
              : Icons.warning,
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

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    String listName,
    WidgetRef ref,
  ) async {
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

  Widget _homeNudgeCard(HomeNudgeCardKind kind) {
    switch (kind) {
      case HomeNudgeCardKind.split:
        return const SplitTripNudgeCard();
      case HomeNudgeCardKind.avoRestock:
        return const AvoNudgeCard();
      case HomeNudgeCardKind.personalFlyer:
        return const PersonalFlyerCard();
      case HomeNudgeCardKind.calorieRecipe:
        return const CalorieRecipeNudgeCard();
      case HomeNudgeCardKind.priceComparison:
        return const PriceComparisonNudgeCard();
    }
  }
}

/// Latest shopping activity as a single paper line.
class _LatestActivityLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recentHistoryProvider);
    final textSecondary = AppColors.textSecondary(context);
    final style = TextStyle(fontSize: 12, color: textSecondary);

    return historyAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Text(context.tr('shopping_history'), style: style);
        }
        final latest = entries.first;
        final locale = Localizations.localeOf(context).toString();
        final date = DateFormat('d. MMM', locale).format(latest.completedAt);
        return Text(
          '${context.tr('last_shopped_prefix')} ${latest.listName} · $date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
      loading: () => Text(context.tr('shopping_history'), style: style),
      error: (_, __) => Text(context.tr('shopping_history'), style: style),
    );
  }
}

/// Paper-style editorial list row: serif number, name, hairline progress.
class _PaperListRow extends StatelessWidget {
  final int index;
  final String name;
  final int itemCount;
  final int? uncheckedCount;
  final bool isShared;
  final GlobalKey? tutorialKey;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PaperListRow({
    super.key,
    required this.index,
    required this.name,
    required this.itemCount,
    required this.uncheckedCount,
    this.isShared = false,
    required this.onTap,
    required this.onLongPress,
    this.tutorialKey,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final baseline = AppColors.divider(context);

    final unchecked = (uncheckedCount ?? itemCount).clamp(0, itemCount);
    final done = itemCount - unchecked;
    final progress = itemCount > 0 ? done / itemCount : 0.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        key: tutorialKey,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: PaperTextStyles.serif(14, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PaperTextStyles.serif(18, color: textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (itemCount == 0
                                ? context.tr('list_empty_label')
                                : unchecked == 0
                                    ? context.tr('all_done_label')
                                    : context.tr(
                                        'items_left',
                                        params: {'n': '$unchecked'},
                                      )) +
                            (isShared
                                ? ' · ${context.tr('shared_label')}'
                                : ''),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isShared)
                  Icon(Icons.people_outline, size: 17, color: textSecondary),
              ],
            ),
          ),
          Container(
            height: 2.5,
            color: baseline,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

