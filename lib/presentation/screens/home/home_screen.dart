import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/utils/display_name_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/data/services/widget_service.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/home/home_layout.dart';
import 'package:shoply/presentation/screens/home/widgets/home_avo_card.dart';
import 'package:shoply/presentation/screens/home/widgets/home_for_you.dart';
import 'package:shoply/presentation/screens/home/widgets/home_header.dart';
import 'package:shoply/presentation/screens/home/widgets/home_pro_hint.dart';
import 'package:shoply/presentation/screens/home/widgets/home_top_lists.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/pro_hint_counter.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/presentation/widgets/tips/home_tips.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

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
  /// The one-time tip of this visit (Konzept 17 §6.1), fixed at its first
  /// frame.
  final _tip = TipVisit(TipPlace.home);

  /// The Pro offer of this visit (Konzept 18 §9.3), fixed like the tip.
  final _proHint = ProHintVisit(ProHintCounter.trialOffer);

  // No auth listener of its own: the lists and the history rebuild per
  // account (`authUserIdProvider`), and main.dart pushes the widget
  // credentials on every sign-in and token refresh. A listener here only
  // loaded both a second time after an account switch.
  @override
  void initState() {
    super.initState();
    // The lists notifier loads itself on creation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(WidgetService.syncCredentialsFromSession());
    });
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
        user?.displayName ?? ref.watch(cachedUserProfileProvider)?.displayName;
    final firstName = rawName == null || rawName.trim().isEmpty
        ? null
        : DisplayNameHelper.getDisplayName(
            rawName,
            fallback: '',
          ).split(' ').first;

    final offersOn = ref.watch(offersAvailableProvider);
    final continueList = continueShoppingList(lists);
    final tipFacts = homeTipFacts(ref.watch(listsNotifierProvider).valueOrNull);
    final tip = _tip.resolve(
      context,
      ref.watch(tipServiceProvider),
      tipFacts,
      allowed: homeTipAllowed(
        savingsHint: offersOn && ref.watch(homeSavingsHintHasContentProvider),
        cookToday:
            ref.watch(moduleEnabledProvider(AppModule.mealPlan)) &&
            ref.watch(homeCookTodayHasContentProvider),
      ),
    );
    final savingsRow = offersOn && ref.watch(homeSavingsHintHasContentProvider);
    final cookRow =
        ref.watch(moduleEnabledProvider(AppModule.mealPlan)) &&
        ref.watch(homeCookTodayHasContentProvider);
    final proHint = _showProHint(
      hintRows:
          (savingsRow ? 1 : 0) + (cookRow ? 1 : 0) + (tip != null ? 1 : 0),
    );
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
      tip: tip != null,
      proHint: proHint,
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
            tipFacts: tipFacts,
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

  /// Whether this visit shows the Pro offer: only with a known Pro status,
  /// without Pro, with the trial still open, room for one more hint row
  /// (K-38) and the counter's pacing (first trip done, once a day).
  bool _showProHint({required int hintRows}) {
    final status = ref.watch(subscriptionStatusProvider);
    final details = ref.watch(proSubscriptionDetailsProvider);
    final ready = status.hasValue && details.hasValue;
    final subscribed = ref.watch(isSubscribedProvider);
    return _proHint.resolve(
      context,
      ref.watch(proHintCounterProvider),
      ready: ready,
      allowed:
          !subscribed &&
          details.valueOrNull?.trialEligible == true &&
          hintRows < kHomeMaxHintRows,
    );
  }

  void _hideProHint() {
    ref.read(proHintCounterProvider)?.hide(ProHintCounter.trialOffer);
    setState(_proHint.dismiss);
  }

  Widget _section(
    HomeSection section, {
    required HomeLayoutInput input,
    required String? firstName,
    required List<ShoppingListModel> lists,
    required ShoppingListModel? continueList,
    required TipFacts tipFacts,
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
        return HomeTipSection(visit: _tip, facts: tipFacts);
      case HomeSection.proHint:
        return inset(HomeProHint(onNever: _hideProHint));
    }
  }
}
