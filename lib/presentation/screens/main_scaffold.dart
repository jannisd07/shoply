import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';

// Branch index <-> visual pill tab index mapping.
// Branches: 0=home, 1=recipes, 2=avo, 3=profile.
// Pill tabs: 0=home, 1=recipes, 2=profile (avo is the floating circle).
const int _kBranchHome = 0;
const int _kBranchRecipes = 1;
const int _kBranchAvo = 2;
const int _kBranchProfile = 3;

int _branchToPillIndex(int branch) {
  switch (branch) {
    case _kBranchHome:
      return 0;
    case _kBranchRecipes:
      return 1;
    case _kBranchProfile:
      return 2;
    default:
      return 0;
  }
}

int _pillToBranchIndex(int pill) {
  switch (pill) {
    case 0:
      return _kBranchHome;
    case 1:
      return _kBranchRecipes;
    case 2:
      return _kBranchProfile;
    default:
      return _kBranchHome;
  }
}

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

/// Main scaffold with floating Liquid Glass navigation islands (iOS 26 style).
///
/// Layout: [ glass pill (Home · Recipes · Profile) ]  [ glass circle (Avo) ]
/// The pill indicator is draggable – swipe horizontally to slide between tabs.
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  static const double _pillHeight = 66.0;
  static const double _indicatorPad = 5.0;
  static const double _avoSize = 66.0;
  static const double _avoImgSize = 39.0;
  static const double _gap = 14.0;
  static const double _iconSize = 24.0;
  static const int _tabCount = 3;

  static double _horizontalPad(double screenW) {
    // Tuned to match iPhone corner curvature with the larger nav geometry.
    return (screenW * 0.045).clamp(16.0, 22.0);
  }

  /// Bottom padding child screens need to clear the floating navbar.
  static double getNavbarClearance(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return safeBottom + _pillHeight + 16.0;
  }

  /// Y offset (from the bottom of the screen) of the top edge of the pill navbar,
  /// mirroring the positioning math in _MainScaffoldState.build.
  /// Use this when a widget needs to sit flush with (or just above) the navbar.
  static double getNavbarTopOffset(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeBot = mq.padding.bottom;
    final screenW = mq.size.width;
    final onePercent = screenW * 0.02;
    final baseBottom = safeBot > 20 ? safeBot - 5 : 10.0;
    final navBottom = (baseBottom - onePercent).clamp(0.0, double.infinity);
    return navBottom + _pillHeight;
  }

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with SingleTickerProviderStateMixin {
  // Unbounded controller so value can be set directly during drag (0.0 … tabCount-1).
  AnimationController? _slideController;
  AnimationController get _slide => _slideController ??=
      AnimationController.unbounded(vsync: this, value: _currentIndex.toDouble());
  late int _currentIndex;
  int? _pressedIndex;
  double _pillWidth = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = _branchToPillIndex(widget.navigationShell.currentIndex);
    // Warm-up to guarantee availability before first frame.
    _slide;
  }

  @override
  void dispose() {
    _slideController?.dispose();
    super.dispose();
  }

  // ── Route helpers ──

  int _selectedPillIndex() =>
      _branchToPillIndex(widget.navigationShell.currentIndex);

  bool _isAvoActive() =>
      widget.navigationShell.currentIndex == _kBranchAvo;

  // ── Navigation ──

  void _springTo(int index) {
    final spring = SpringDescription(mass: 1.0, stiffness: 500, damping: 30);
    _slide.animateWith(
      SpringSimulation(spring, _slide.value, index.toDouble(), 0),
    );
  }

  void _goBranch(int branch) {
    widget.navigationShell.goBranch(
      branch,
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
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

  void _onTab(int pillIndex) {
    final wasAvo = _isAvoActive();
    if (pillIndex == _currentIndex && !wasAvo) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = pillIndex);
    _springTo(pillIndex);
    _goBranch(_pillToBranchIndex(pillIndex));
  }

  void _onTabPressStart(int index) {
    if (_pressedIndex == index) return;
    setState(() => _pressedIndex = index);
  }

  void _onTabPressEnd() {
    if (_pressedIndex == null) return;
    setState(() => _pressedIndex = null);
  }

  void _onAvo() {
    HapticFeedback.mediumImpact();
    widget.navigationShell.goBranch(
      _kBranchAvo,
      initialLocation: widget.navigationShell.currentIndex == _kBranchAvo,
    );
  }

  // ── Drag gesture (slide between tabs) ──

  void _onDragStart(DragStartDetails _) => _slide.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    if (_pillWidth <= 0) return;
    final tabWidth = _pillWidth / MainScaffold._tabCount;
    _slide.value = (_slide.value + details.delta.dx / tabWidth)
        .clamp(0.0, (MainScaffold._tabCount - 1).toDouble());
  }

  void _onDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final int nearest;
    if (v.abs() > 300) {
      // Fling – advance one tab in swipe direction.
      nearest = v > 0
          ? (_slide.value.floor() + 1).clamp(0, MainScaffold._tabCount - 1)
          : (_slide.value.ceil() - 1).clamp(0, MainScaffold._tabCount - 1);
    } else {
      nearest = _slide.value.round().clamp(0, MainScaffold._tabCount - 1);
    }
    _springTo(nearest);
    if (nearest != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = nearest);
      _goBranch(_pillToBranchIndex(nearest));
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final kbd = MediaQuery.of(context).viewInsets.bottom > 0;
    final pillIndex = _selectedPillIndex();
    final avo = _isAvoActive();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final safeTop = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = MainScaffold._horizontalPad(screenW);
    final onePercent = screenW * 0.02;
    final navGap = (MainScaffold._gap - onePercent).clamp(0.0, MainScaffold._gap);
    final baseBottom = safeBot > 20 ? safeBot - 5 : 10.0;
    final navBottom = (baseBottom - onePercent).clamp(0.0, double.infinity);
    final tut = DynamicTutorialService.instance;
    final isOffline = ref.watch(isOfflineProvider);

    // Sync indicator when route changes externally (e.g. deep link, back).
    if (!avo && pillIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pillIndex != _currentIndex) {
          _springTo(pillIndex);
          setState(() => _currentIndex = pillIndex);
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          widget.navigationShell,

          // Floating offline banner – appears when the device loses
          // connectivity and disappears as soon as it comes back online.
          Positioned(
            top: safeTop + 8,
            left: hPad,
            right: hPad,
            child: IgnorePointer(
              child: _OfflineBanner(
                visible: isOffline,
                isDark: isDark,
              ),
            ),
          ),

          if (!kbd)
            Positioned(
              left: hPad,
              right: hPad,
              bottom: navBottom,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Liquid Glass Navigation Pill ──
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(MainScaffold._pillHeight / 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.06),
                            blurRadius: isDark ? 20 : 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: MainScaffold._pillHeight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _pillWidth = constraints.maxWidth;
                            return AnimatedBuilder(
                              animation: _slide,
                              // child is cached – only rebuilt on setState, not every frame.
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ImageNavTabButton(
                                      activeAsset: 'assets/icons/home_unfilled.png',
                                      inactiveAsset: 'assets/icons/home_unfilled.png',
                                      label: 'Home',
                                      index: 0,
                                      currentIndex: _currentIndex,
                                      isDark: isDark,
                                      dimmed: avo,
                                      onTap: () => _onTab(0),
                                      onPressStart: () => _onTabPressStart(0),
                                      onPressEnd: _onTabPressEnd,
                                      itemKey: tut.homeTabKey,
                                    ),
                                  ),
                                  Expanded(
                                    child: _NavTabButton(
                                      icon: LucideIcons.chefHat,
                                      iconSize: 28,
                                      label: 'Recipes',
                                      index: 1,
                                      currentIndex: _currentIndex,
                                      isDark: isDark,
                                      dimmed: avo,
                                      onTap: () => _onTab(1),
                                      onPressStart: () => _onTabPressStart(1),
                                      onPressEnd: _onTabPressEnd,
                                      itemKey: tut.recipesTabKey,
                                    ),
                                  ),
                                  Expanded(
                                    child: _NavTabButton(
                                      icon: LucideIcons.user,
                                      iconSize: 28,
                                      label: 'Profile',
                                      index: 2,
                                      currentIndex: _currentIndex,
                                      isDark: isDark,
                                      dimmed: avo,
                                      onTap: () => _onTab(2),
                                      onPressStart: () => _onTabPressStart(2),
                                      onPressEnd: _onTabPressEnd,
                                    ),
                                  ),
                                ],
                              ),
                              builder: (context, child) {
                                final indicatorPosition =
                                    (_pressedIndex ?? _slide.value).toDouble();
                                final isSliding =
                                  (_slide.value - _currentIndex).abs() > 0.02;
                                final indicatorExpanded =
                                  _pressedIndex != null || isSliding;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _GlassSlidingIndicator(
                                      position: indicatorPosition,
                                      tabCount: MainScaffold._tabCount,
                                      pillHeight: MainScaffold._pillHeight,
                                      padding: MainScaffold._indicatorPad,
                                      isDark: isDark,
                                      dimmed: avo,
                                      isSliding: isSliding,
                                      expanded: indicatorExpanded,
                                    ),
                                    LiquidGlassContainer(
                                      cornerRadius: MainScaffold._pillHeight / 2,
                                      glassOpacity: isDark ? 0.36 : 0.94,
                                      fallbackBlurSigma: 22.0,
                                      child: Stack(
                                        children: [
                                          // Force visible dark-mode glass tone even when native view appears bright.
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.black.withValues(alpha: 0.52)
                                                      : Colors.white.withValues(alpha: 0.02),
                                                ),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            behavior: HitTestBehavior.translucent,
                                            onHorizontalDragStart: _onDragStart,
                                            onHorizontalDragUpdate: _onDragUpdate,
                                            onHorizontalDragEnd: _onDragEnd,
                                            child: SizedBox(
                                              height: MainScaffold._pillHeight,
                                              child: child,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: navGap),

                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.06),
                              blurRadius: isDark ? 20 : 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: _onAvo,
                          behavior: HitTestBehavior.opaque,
                          child: _AvoCircle(
                            size: MainScaffold._avoSize,
                            imgSize: MainScaffold._avoImgSize,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Liquid Glass Sliding Indicator ──
class _GlassSlidingIndicator extends StatelessWidget {
  final double position;
  final int tabCount;
  final double pillHeight;
  final double padding;
  final bool isDark;
  final bool dimmed;
  final bool isSliding;
  final bool expanded;

  const _GlassSlidingIndicator({
    required this.position,
    required this.tabCount,
    required this.pillHeight,
    required this.padding,
    required this.isDark,
    this.dimmed = false,
    this.isSliding = false,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dimmed) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabCount;
          final baseInset = pillHeight * 0.05; // 5% top/bottom margin at rest.
          final baseHeight = pillHeight - (2 * baseInset);
          final heightBoost = isSliding
            ? pillHeight * 0.40
            : (expanded ? pillHeight * 0.27 : 0.0);
          final indicatorHeight = baseHeight + heightBoost;
          final indicatorWidth = isSliding
            ? tabWidth * 1.00
            : (expanded ? tabWidth * 0.94 : tabWidth * 0.79);
          final indicatorRadius = indicatorHeight / 2;
          final top = expanded ? (pillHeight - indicatorHeight) / 2 : baseInset;
          final left = (position * tabWidth) + (tabWidth - indicatorWidth) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                left: left,
                top: top,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    width: indicatorWidth,
                    height: indicatorHeight,
                    child: LiquidGlassContainer(
                      cornerRadius: indicatorRadius,
                      glassOpacity: isDark
                          ? (isSliding ? 0.44 : 0.34)
                          : (isSliding ? 0.92 : 0.84),
                      fallbackBlurSigma: isSliding ? 18.0 : 16.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(indicatorRadius),
                          color: isDark
                              ? const Color(0xFF111827).withValues(alpha: isSliding ? 0.74 : 0.64)
                              : Colors.white.withValues(alpha: isSliding ? 0.32 : 0.25),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: isSliding ? 0.18 : 0.14)
                                : Colors.white.withValues(alpha: isSliding ? 0.55 : 0.45),
                            width: isSliding ? 0.7 : 0.55,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withValues(alpha: isSliding ? 0.04 : 0.03)
                                  : Colors.white.withValues(alpha: isSliding ? 0.28 : 0.20),
                              blurRadius: isSliding ? 16 : 12,
                              spreadRadius: isSliding ? 0.4 : 0.2,
                              offset: const Offset(0, -1),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? (isSliding ? 0.24 : 0.18) : (isSliding ? 0.12 : 0.08)),
                              blurRadius: isSliding ? 14 : 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(indicatorRadius),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.35, 1.0],
                              colors: [
                                Colors.white.withValues(alpha: isDark ? (isSliding ? 0.16 : 0.12) : (isSliding ? 0.42 : 0.32)),
                                Colors.white.withValues(alpha: isDark ? (isSliding ? 0.06 : 0.04) : (isSliding ? 0.18 : 0.12)),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Nav Tab Button ──
class _NavTabButton extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int index, currentIndex;
  final bool isDark, dimmed;
  final VoidCallback onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final Key? itemKey;
  final double? iconSize;

  const _NavTabButton({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.dimmed = false,
    this.itemKey,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex && !dimmed;
    final activeColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF64748B).withValues(alpha: 0.72);

    return GestureDetector(
      onTapDown: (_) => onPressStart?.call(),
      onTapCancel: () => onPressEnd?.call(),
      onTapUp: (_) => onPressEnd?.call(),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        key: itemKey,
        height: MainScaffold._pillHeight,
        child: Center(
          child: Icon(
            isActive ? (activeIcon ?? icon) : icon,
            size: iconSize ?? MainScaffold._iconSize,
            color: isActive ? activeColor : inactiveColor,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

// ── Image-based Nav Tab Button ──
class _ImageNavTabButton extends StatelessWidget {
  final String activeAsset;
  final String inactiveAsset;
  final String label;
  final int index, currentIndex;
  final bool isDark, dimmed;
  final VoidCallback onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final Key? itemKey;

  const _ImageNavTabButton({
    required this.activeAsset,
    required this.inactiveAsset,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.dimmed = false,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex && !dimmed;
    final activeColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF64748B).withValues(alpha: 0.72);

    return GestureDetector(
      onTapDown: (_) => onPressStart?.call(),
      onTapCancel: () => onPressEnd?.call(),
      onTapUp: (_) => onPressEnd?.call(),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        key: itemKey,
        height: MainScaffold._pillHeight,
        child: Center(
          child: Image.asset(
            isActive ? activeAsset : inactiveAsset,
            width: MainScaffold._iconSize,
            height: MainScaffold._iconSize,
            color: isActive ? activeColor : inactiveColor,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

// ── Profile Nav Tab with avatar ──
class _ProfileNavTab extends StatelessWidget {
  final int index, currentIndex;
  final bool isDark, dimmed;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  const _ProfileNavTab({
    required this.index,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    this.dimmed = false,
    this.avatarUrl,
    this.displayName,
    this.onPressStart,
    this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex && !dimmed;
    final activeColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF64748B).withValues(alpha: 0.72);
    final iconSize = MainScaffold._iconSize;

    return GestureDetector(
      onTapDown: (_) => onPressStart?.call(),
      onTapCancel: () => onPressEnd?.call(),
      onTapUp: (_) => onPressEnd?.call(),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: MainScaffold._pillHeight,
        child: Center(
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(isActive, activeColor, inactiveColor),
                    )
                  : _buildFallback(isActive, activeColor, inactiveColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(bool isActive, Color activeColor, Color inactiveColor) {
    final initial = (displayName != null && displayName!.isNotEmpty)
        ? displayName![0].toUpperCase()
        : 'U';
    return Container(
      color: isActive
          ? activeColor.withValues(alpha: 0.1)
          : inactiveColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: MainScaffold._iconSize * 0.45,
            fontWeight: FontWeight.w600,
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}

// ── Avo circle ──
class _AvoCircle extends StatelessWidget {
  final double size, imgSize;
  final bool isDark;

  const _AvoCircle({
    required this.size,
    required this.imgSize,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: LiquidGlassContainer(
        isCircle: true,
          glassOpacity: isDark ? 0.36 : 0.94,
        fallbackBlurSigma: 22.0,
        child: Stack(
          children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.52)
                          : Colors.white.withValues(alpha: 0.02),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: size, height: size,
              child: Center(
                child: Image.asset('assets/avo/avo_excited.png', width: imgSize, height: imgSize, fit: BoxFit.contain),
              ),
            ),
          ],
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
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.82)
                      : const Color(0xFF0F172A).withValues(alpha: 0.78),
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.92)
                        : const Color(0xFF0F172A),
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
