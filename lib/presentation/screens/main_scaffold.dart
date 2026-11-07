import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/widgets/design/app_tab_bar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/app_branch.dart';

/// The app shell (D2): tab content plus the floating glass tab bar with
/// Home, Listen, Avo, Rezepte, Profil.
///
/// - Switching tabs is instant (no slide) and keeps each tab's state.
/// - Tapping the active tab again returns to its root.
/// - The bar hides while the keyboard is up.
/// - The Avo tab disappears while the Avo module is off.
/// - Screens built before S2 keep their bottom controls above the bar: the
///   shell raises `MediaQuery.padding.bottom` by the bar's height. New screens
///   use [ShellInsets] (based on `viewPadding`), which is not raised.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.navigationShell, this.location});

  final StatefulNavigationShell navigationShell;

  /// The current route pattern (for example `/lists/:listId`).
  final String? location;

  /// Bottom padding a screen needs to clear the tab bar.
  static double getNavbarClearance(BuildContext context) =>
      ShellInsets.bottom(context);

  /// Distance from the screen bottom to the top edge of the tab bar.
  static double getNavbarTopOffset(BuildContext context) =>
      ShellInsets.tabBarBottom(context) + AvoSizes.tabBarHeight;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int get _currentBranch => widget.navigationShell.currentIndex;

  List<AppBranch> _visibleBranches(bool avoOn) => [
    AppBranch.home,
    AppBranch.lists,
    if (avoOn) AppBranch.avo,
    AppBranch.recipes,
    AppBranch.profile,
  ];

  void _goBranch(AppBranch branch) {
    final index = branch.index;
    if (index == _currentBranch) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    widget.navigationShell.goBranch(index);
    final tutorial = DynamicTutorialService.instance;
    if (branch == AppBranch.home) tutorial.onRouteChanged('/home');
    if (branch == AppBranch.recipes) tutorial.onRouteChanged('/recipes');
  }

  AppTabItem _item(BuildContext context, AppBranch branch) => switch (branch) {
    AppBranch.home => AppTabItem(
      icon: AvoIcons.home,
      label: context.tr('common_tab_home'),
    ),
    AppBranch.lists => AppTabItem(
      icon: AvoIcons.cart,
      label: context.tr('common_tab_lists'),
    ),
    AppBranch.avo => AppTabItem(
      icon: AvoIcons.sparkle,
      label: context.tr('common_tab_avo'),
    ),
    AppBranch.recipes => AppTabItem(
      icon: AvoIcons.forkKnife,
      label: context.tr('common_tab_recipes'),
    ),
    AppBranch.profile => AppTabItem(
      icon: AvoIcons.person,
      label: context.tr('common_tab_profile'),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final avoOn = ref.watch(moduleEnabledProvider(AppModule.avo));
    final branches = _visibleBranches(avoOn);

    // Avo switched off while its tab is showing: go Home.
    if (!avoOn && _currentBranch == AppBranch.avo.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(moduleEnabledProvider(AppModule.avo))) {
          widget.navigationShell.goBranch(AppBranch.home.index);
        }
      });
    }

    final mq = MediaQuery.of(context);
    final keyboardUp = mq.viewInsets.bottom > 0;
    final barBottom = ShellInsets.tabBarBottom(context);
    final clearance = barBottom + AvoSizes.tabBarHeight + AvoSpacing.s;
    final selected = branches.indexWhere((b) => b.index == _currentBranch);

    return ColoredBox(
      color: context.colors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: keyboardUp
                  ? mq
                  : mq.copyWith(
                      padding: mq.padding.copyWith(
                        bottom: math.max(mq.padding.bottom, clearance),
                      ),
                    ),
              child: widget.navigationShell,
            ),
          ),
          if (!keyboardUp)
            Positioned(
              left: AvoSizes.tabBarSide,
              right: AvoSizes.tabBarSide,
              bottom: barBottom,
              child: AppTabBar(
                items: [for (final b in branches) _item(context, b)],
                selectedIndex: selected < 0 ? 0 : selected,
                onSelect: (i) => _goBranch(branches[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Holds the tab navigators. Only the current one is painted and ticks;
/// the others keep their state offstage. A tab is built the first time it
/// is shown. Switching is instant (Konzept 00 §10: no tab transition).
class ShellBranchContainer extends StatefulWidget {
  const ShellBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<ShellBranchContainer> createState() => _ShellBranchContainerState();
}

class _ShellBranchContainerState extends State<ShellBranchContainer> {
  final Set<int> _built = {};

  @override
  Widget build(BuildContext context) {
    _built.add(widget.currentIndex);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_built.contains(i))
            Offstage(
              offstage: i != widget.currentIndex,
              child: TickerMode(
                enabled: i == widget.currentIndex,
                child: widget.children[i],
              ),
            ),
      ],
    );
  }
}
