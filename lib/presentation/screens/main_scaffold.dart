import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';

/// Main scaffold with floating Liquid Glass navigation islands (iOS 26 style).
///
/// Layout: [ glass pill (Home · Recipes · Profile) ]  [ glass circle (Avo) ]
/// The pill indicator is draggable – swipe horizontally to slide between tabs.
class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

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
  AnimationController get _slide =>
      _slideController ??= AnimationController.unbounded(vsync: this, value: 0.0);
  int _currentIndex = 0;
  int? _pressedIndex;
  double _pillWidth = 0;

  @override
  void initState() {
    super.initState();
    // Warm-up to guarantee availability before first frame.
    _slide;
  }

  @override
  void dispose() {
    _slideController?.dispose();
    super.dispose();
  }

  // ── Route helpers ──

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/home')) return 0;
    if (loc.startsWith('/recipes')) return 1;
    if (loc.startsWith('/profile')) return 2;
    return 0;
  }

  bool _isAvoActive(BuildContext context) =>
      GoRouterState.of(context).matchedLocation.startsWith('/avo');

  // ── Navigation ──

  void _springTo(int index) {
    final spring = SpringDescription(mass: 1.0, stiffness: 500, damping: 30);
    _slide.animateWith(
      SpringSimulation(spring, _slide.value, index.toDouble(), 0),
    );
  }

  void _navigateTo(BuildContext context, int index) {
    setState(() => _currentIndex = index);
    final t = DynamicTutorialService.instance;
    switch (index) {
      case 0: context.go('/home'); t.onRouteChanged('/home');
      case 1: context.go('/recipes'); t.onRouteChanged('/recipes');
      case 2: context.go('/profile');
    }
  }

  void _onTab(BuildContext context, int index) {
    if (index == _currentIndex && !_isAvoActive(context)) return;
    HapticFeedback.lightImpact();
    _springTo(index);
    _navigateTo(context, index);
  }

  void _onTabPressStart(int index) {
    if (_pressedIndex == index) return;
    setState(() => _pressedIndex = index);
  }

  void _onTabPressEnd() {
    if (_pressedIndex == null) return;
    setState(() => _pressedIndex = null);
  }

  void _onAvo(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.go('/avo');
  }

  // ── Drag gesture (slide between tabs) ──

  void _onDragStart(DragStartDetails _) => _slide.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    if (_pillWidth <= 0) return;
    final tabWidth = _pillWidth / MainScaffold._tabCount;
    _slide.value = (_slide.value + details.delta.dx / tabWidth)
        .clamp(0.0, (MainScaffold._tabCount - 1).toDouble());
  }

  void _onDragEnd(DragEndDetails details, BuildContext context) {
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
      _navigateTo(context, nearest);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final kbd = MediaQuery.of(context).viewInsets.bottom > 0;
    final routeIndex = _selectedIndex(context);
    final avo = _isAvoActive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = MainScaffold._horizontalPad(screenW);
    final onePercent = screenW * 0.02;
    final navGap = (MainScaffold._gap - onePercent).clamp(0.0, MainScaffold._gap);
    final baseBottom = safeBot > 20 ? safeBot - 5 : 10.0;
    final navBottom = (baseBottom - onePercent).clamp(0.0, double.infinity);
    final tut = DynamicTutorialService.instance;

    // Sync indicator when route changes externally (e.g. deep link, back).
    if (!avo && routeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && routeIndex != _currentIndex) {
          _springTo(routeIndex);
          setState(() => _currentIndex = routeIndex);
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          widget.child,

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
                                      onTap: () => _onTab(context, 0),
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
                                      onTap: () => _onTab(context, 1),
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
                                      onTap: () => _onTab(context, 2),
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
                                            onHorizontalDragEnd: (d) => _onDragEnd(d, context),
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
                          onTap: () => _onAvo(context),
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
