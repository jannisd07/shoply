import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/utils/display_name_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/widget_service.dart';
import 'package:shoply/presentation/screens/home/home_layout.dart';
import 'package:shoply/presentation/screens/home/widgets/home_avo_card.dart';
import 'package:shoply/presentation/screens/home/widgets/home_for_you.dart';
import 'package:shoply/presentation/screens/home/widgets/home_header.dart';
import 'package:shoply/presentation/screens/home/widgets/home_top_lists.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Content starts 52 pt below the safe area (D2: 106 on a 54 pt status bar).
const double _kTopInset = 52; // D2

/// The list "Weiter einkaufen" points at: the one with open items that was
/// used last, or null.
ShoppingListModel? continueShoppingList(List<ShoppingListModel> lists) {
  final open = lists.where((l) => (l.uncheckedCount ?? 0) > 0).toList()
    ..sort(
      (a, b) => (b.lastAccessedAt ?? b.updatedAt).compareTo(
        a.lastAccessedAt ?? a.updatedAt,
      ),
    );
  return open.isEmpty ? null : open.first;
}

/// Home tab (D2 "Für dich", owner decision 07.11.2026): greeting, the Avo
/// card, Teil B's money, calorie and cooking sections, the tile grid, the
/// top lists. Every section comes from the local state at once and is left
/// out when its module is off or it has nothing to show (`home_layout.dart`).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCreatingTutorialList = false;
  String? _lastUserId;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _lastUserId = SupabaseService.instance.currentUser?.id;

    // The lists notifier loads itself on creation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWidgetCredentials();
      unawaited(_ensureTutorialListExists());
    });

    DynamicTutorialService.instance.addListener(_handleTutorialChange);

    // Keep the tutorial pointed at the most recently updated list.
    ref.listenManual<AsyncValue<List<ShoppingListModel>>>(
      listsNotifierProvider,
      (_, next) => _updateTutorialListsData(next.valueOrNull),
      fireImmediately: true,
    );

    // Reload account-scoped data when the signed-in user changes.
    _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange
        .listen((data) {
          final newUserId = data.session?.user.id;
          if (_lastUserId != newUserId && mounted) {
            _lastUserId = newUserId;
            ref.read(listsNotifierProvider.notifier).loadLists();
            ref.invalidate(recentHistoryProvider);
            _syncWidgetCredentials();
          }
        });
  }

  void _updateTutorialListsData(List<ShoppingListModel>? lists) {
    if (lists == null) return;
    final tutorial = DynamicTutorialService.instance;
    if (lists.isEmpty) {
      tutorial.updateListsData(hasLists: false, firstListId: null);
      if (tutorial.isActive &&
          tutorial.currentStepId == TutorialStepId.openShoppingList) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_ensureTutorialListExists()),
        );
      }
      return;
    }
    final newest = lists.reduce(
      (a, b) => b.updatedAt.isAfter(a.updatedAt) ? b : a,
    );
    tutorial.updateListsData(hasLists: true, firstListId: newest.id);
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
          .createList(context.tr('my_first_list'));
      tutorial.updateListsData(hasLists: true, firstListId: list.id);
    } catch (e) {
      debugPrint('[HOME] Error creating tutorial list: $e');
    } finally {
      _isCreatingTutorialList = false;
    }
  }

  void _syncWidgetCredentials() {
    unawaited(WidgetService.syncCredentialsFromSession());
  }

  Future<void> _refresh() async {
    ref.invalidate(recentHistoryProvider);
    await ref.read(listsNotifierProvider.notifier).loadLists();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
    final user = ref.watch(currentUserProvider).valueOrNull;
    // Until the server answers, the name saved on this device.
    final rawName =
        user?.displayName ??
        ref.watch(cachedUserProfileProvider).valueOrNull?.displayName;
    final firstName = rawName == null || rawName.trim().isEmpty
        ? null
        : DisplayNameHelper.getDisplayName(
            rawName,
            fallback: '',
          ).split(' ').first;

    final offersOn = ref.watch(offersAvailableProvider);
    final continueList = continueShoppingList(lists);
    final input = HomeLayoutInput(
      avo: ref.watch(moduleEnabledProvider(AppModule.avo)),
      offers: offersOn,
      calories: ref.watch(moduleEnabledProvider(AppModule.calories)),
      mealPlan: ref.watch(moduleEnabledProvider(AppModule.mealPlan)),
      savingsHint: ref.watch(homeSavingsHintHasContentProvider),
      month: ref.watch(homeMonthHasContentProvider),
      spending: ref.watch(homeSpendingHasContentProvider),
      savingsGoal: ref.watch(homeSavingsGoalHasContentProvider),
      caloriesToday: ref.watch(homeCaloriesHasContentProvider),
      continueShopping: continueList != null,
      restock: ref.watch(homeRestockHasContentProvider),
      offersTile: ref.watch(homeOffersTileHasContentProvider),
      water: ref.watch(homeWaterHasContentProvider),
      lists: lists.isNotEmpty,
      recentTrips: ref.watch(homeRecentTripsHasContentProvider),
      cookToday: ref.watch(homeCookTodayHasContentProvider),
    );

    final sections = homeSections(input);
    final children = <Widget>[HomeHeader(firstName: firstName)];
    HomeSection? previous;
    for (final section in sections) {
      children
        ..add(SizedBox(height: homeSectionGap(previous, section)))
        ..add(
          _section(
            section,
            input: input,
            firstName: firstName,
            lists: lists,
            continueList: continueList,
          ),
        );
      previous = section;
    }

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
                  top: MediaQuery.paddingOf(context).top + _kTopInset,
                  bottom: ShellInsets.bottom(context),
                ),
                sliver: SliverList.list(children: children),
              ),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: ScrollEdgeFade()),
          ),
        ],
      ),
    );
  }

  Widget _section(
    HomeSection section, {
    required HomeLayoutInput input,
    required String? firstName,
    required List<ShoppingListModel> lists,
    required ShoppingListModel? continueList,
  }) {
    Widget inset(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: child,
    );

    switch (section) {
      case HomeSection.avoCard:
        return inset(
          HomeAvoCard(
            firstName: firstName,
            offersOn: input.offers,
            hasSavingsHint: input.savingsHint,
          ),
        );
      case HomeSection.savingsHint:
        return inset(const AvoCard(child: HomeSavingsHint()));
      case HomeSection.month:
        return inset(const HomeMonthCard());
      case HomeSection.spending:
        return inset(const HomeSpendingComparison());
      case HomeSection.savingsGoal:
        return inset(const HomeSavingsGoal());
      case HomeSection.calories:
        return inset(const HomeCaloriesToday());
      case HomeSection.forYou:
        return HomeForYou(tiles: homeTiles(input), continueList: continueList);
      case HomeSection.topLists:
        return HomeTopLists(lists: lists);
      case HomeSection.recentTrips:
        return inset(const HomeRecentTrips());
      case HomeSection.cookToday:
        return inset(const HomeCookToday());
      case HomeSection.tip:
        // One-time tips arrive with A5 (Konzept 10.3.3, rank 9).
        return const SizedBox.shrink();
    }
  }
}
