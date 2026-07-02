import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

// Branch indices: 0=home, 1=recipes, 2=profile.
// Avo chat lives outside the shell (full-screen push, no navbar).
const int _kBranchHome = 0;
const int _kBranchRecipes = 1;
const int _kBranchProfile = 2;

/// Container rendered by [StatefulShellRoute.navigatorContainerBuilder] that
/// keeps every branch's navigator alive in the widget tree and slides
/// horizontally between them on tab change. Because all children remain
/// mounted, switching tabs is instant – there is no rebuild work.
class SlidingTabsContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const SlidingTabsContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  State<SlidingTabsContainer> createState() => _SlidingTabsContainerState();
}

class _SlidingTabsContainerState extends State<SlidingTabsContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    _from = widget.currentIndex;
    _to = widget.currentIndex;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant SlidingTabsContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _to) {
      _from = _to;
      _to = widget.currentIndex;
      _ctrl
        ..stop()
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_ctrl.value);
              final progress = _from + (_to - _from) * t;
              final offset = progress * width;
              return Stack(
                children: [
                  for (int i = 0; i < widget.children.length; i++)
                    Positioned(
                      left: i * width - offset,
                      top: 0,
                      width: width,
                      height: constraints.maxHeight,
                      child: TickerMode(
                        // Pause animations in offscreen branches to save CPU.
                        enabled: i == _to || _ctrl.isAnimating,
                        child: widget.children[i],
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
}

/// Main scaffold with the Paper floating ink pill navigation.
///
/// Layout: [ list · book · (+) · chat · user ] — one dark pill, the
/// terracotta plus in the center creates a new list.
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  static const double _pillHeight = 62.0;
  static const double _plusSize = 38.0;

  /// Bottom padding child screens need to clear the floating navbar.
  static double getNavbarClearance(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return safeBottom + _pillHeight + 16.0;
  }

  /// Y offset (from the bottom of the screen) of the top edge of the pill
  /// navbar. Use this when a widget needs to sit flush with the navbar.
  static double getNavbarTopOffset(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    final navBottom = safeBot > 20 ? safeBot - 4 : 12.0;
    return navBottom + _pillHeight;
  }

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int get _currentBranch => widget.navigationShell.currentIndex;

  void _goBranch(int branch) {
    if (branch == _currentBranch) {
      widget.navigationShell.goBranch(branch, initialLocation: true);
      return;
    }
    HapticFeedback.lightImpact();
    widget.navigationShell.goBranch(branch);
    final t = DynamicTutorialService.instance;
    switch (branch) {
      case _kBranchHome:
        t.onRouteChanged('/home');
        break;
      case _kBranchRecipes:
        t.onRouteChanged('/recipes');
        break;
    }
  }

  Future<void> _onCreateList() async {
    HapticFeedback.mediumImpact();
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
        if (mounted) {
          _goBranch(_kBranchHome);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('error')}: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kbd = MediaQuery.of(context).viewInsets.bottom > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final safeTop = MediaQuery.of(context).padding.top;
    final navBottom = safeBot > 20 ? safeBot - 4 : 12.0;
    final tut = DynamicTutorialService.instance;
    final isOffline = ref.watch(isOfflineProvider);

    final pillColor = isDark ? const Color(0xFF16181D) : PaperColors.ink;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : PaperColors.paper,
      body: Stack(
        children: [
          widget.navigationShell,

          // Floating offline banner.
          Positioned(
            top: safeTop + 8,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: _OfflineBanner(visible: isOffline, isDark: isDark),
            ),
          ),

          if (!kbd)
            Positioned(
              left: 0,
              right: 0,
              bottom: navBottom,
              child: Center(
                child: Container(
                  height: MainScaffold._pillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(
                      MainScaffold._pillHeight / 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavIcon(
                        icon: LucideIcons.list,
                        label: 'Listen',
                        active: _currentBranch == _kBranchHome,
                        onTap: () => _goBranch(_kBranchHome),
                        itemKey: tut.homeTabKey,
                      ),
                      _NavIcon(
                        icon: LucideIcons.book,
                        label: 'Rezepte',
                        active: _currentBranch == _kBranchRecipes,
                        onTap: () => _goBranch(_kBranchRecipes),
                        itemKey: tut.recipesTabKey,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: GestureDetector(
                          onTap: _onCreateList,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: MainScaffold._plusSize,
                            height: MainScaffold._plusSize,
                            decoration: const BoxDecoration(
                              color: PaperColors.terracotta,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: PaperColors.paper,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                      _NavIcon(
                        icon: LucideIcons.messageCircle,
                        label: 'Avo',
                        active: false,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/avo');
                        },
                      ),
                      _NavIcon(
                        icon: LucideIcons.user,
                        label: 'Profil',
                        active: _currentBranch == _kBranchProfile,
                        onTap: () => _goBranch(_kBranchProfile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Key? itemKey;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        key: itemKey,
        width: 56,
        height: MainScaffold._pillHeight,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: active ? 1.0 : 0.42,
            child: Icon(
              icon,
              size: 21,
              color: PaperColors.paper,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Offline banner ──
class _OfflineBanner extends StatelessWidget {
  final bool visible;
  final bool isDark;

  const _OfflineBanner({required this.visible, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, -1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1.0 : 0.0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF111827).withValues(alpha: 0.92)
                  : PaperColors.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : PaperColors.hairline,
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.82)
                      : PaperColors.ink.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.92)
                        : PaperColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
