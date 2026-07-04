import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';

// Branch indices — must match the StatefulShellRoute branch order in
// app_router.dart. The calories branch always exists (stable indices);
// its tab is only shown when the user opted into calorie tracking.
// Avo chat lives outside the shell (full-screen push, no navbar).
const int _kBranchHome = 0;
const int _kBranchRecipes = 1;
const int _kBranchCalories = 2;
const int _kBranchProfile = 3;

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

/// Main scaffold with the Paper floating ink navigation ("D1" design).
///
/// Layout (matches the D1 mockup metrics): an ink pill spanning the screen
/// width (14pt margins, capped at 480pt for tablets) with 46pt tab seats
/// distributed spaceAround, plus a detached 58pt Avo orb on the right edge
/// and a soft background fade behind the whole bar. The active tab sits in
/// a 12% paper seat. The tab set is preference-driven:
/// [ list · book · (flame) · user ], where the Kalorien tab only appears
/// when the user opted into calorie tracking (onboarding or profile
/// settings). Create-list lives on the home screen ("+ Neue Liste").
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  /// The D1 mockup was drawn on a 300pt-wide phone frame. Every navbar
  /// metric scales linearly with screen width from that baseline, so the
  /// length-to-thickness ratio, seat and icon sizes match the mockup 1:1
  /// on any device (e.g. ×1.34 on a 402pt iPhone 17 Pro). Capped at 480pt
  /// of layout width so tablets don't get a comically large bar.
  static const double _mockupWidth = 300.0;

  static double navScale(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return math.min(w, 480.0) / _mockupWidth;
  }

  /// Pill/orb height (58 in the mockup), scaled to this screen.
  static double pillHeightOf(BuildContext context) => 58.0 * navScale(context);

  /// Bottom padding child screens need to clear the floating navbar.
  static double getNavbarClearance(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return safeBottom + pillHeightOf(context) + 16.0;
  }

  /// Y offset (from the bottom of the screen) of the top edge of the pill
  /// navbar. Use this when a widget needs to sit flush with the navbar.
  static double getNavbarTopOffset(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    final navBottom = safeBot > 20 ? safeBot - 4 : 12.0;
    return navBottom + pillHeightOf(context);
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

  @override
  Widget build(BuildContext context) {
    final kbd = MediaQuery.of(context).viewInsets.bottom > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final safeTop = MediaQuery.of(context).padding.top;
    final navBottom = safeBot > 20 ? safeBot - 4 : 12.0;
    final tut = DynamicTutorialService.instance;
    final isOffline = ref.watch(isOfflineProvider);
    final caloriesEnabled = ref.watch(calorieTrackingEnabledProvider);

    // If the tab was hidden while its branch was active (settings toggle or
    // "hide tab" on the calories screen), fall back to home.
    if (!caloriesEnabled && _currentBranch == _kBranchCalories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(calorieTrackingEnabledProvider)) {
          widget.navigationShell.goBranch(_kBranchHome);
        }
      });
    }

    final pillColor = isDark ? const Color(0xFF16181D) : PaperColors.ink;

    // All D1 mockup metrics (baseline: 300pt frame), scaled to this screen.
    final k = MainScaffold.navScale(context);
    final pillH = 58.0 * k;

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

          // Soft fade from transparent to the page background behind the
          // navbar, so scrolled content settles calmly under the bar
          // instead of colliding with it (clean zone, like the mockup).
          if (!kbd)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: navBottom + pillH + 24 * k,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (isDark ? Colors.black : PaperColors.paper).withValues(
                          alpha: 0.0,
                        ),
                        isDark ? Colors.black : PaperColors.paper,
                      ],
                      stops: const [0.0, 0.62],
                    ),
                  ),
                ),
              ),
            ),

          if (!kbd)
            Positioned(
              left: 0,
              right: 0,
              bottom: navBottom,
              child: Center(
                // D1 mockup structure at exact scaled metrics: 14k margins,
                // pill flex + 10k gap + 58k orb; capped for tablets.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14 * k),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: pillH,
                            padding: EdgeInsets.symmetric(horizontal: 6 * k),
                            decoration: BoxDecoration(
                              color: pillColor,
                              borderRadius: BorderRadius.circular(pillH / 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF201D18,
                                  ).withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _NavIcon(
                                  icon: LucideIcons.list,
                                  label: 'Listen',
                                  scale: k,
                                  active: _currentBranch == _kBranchHome,
                                  onTap: () => _goBranch(_kBranchHome),
                                  itemKey: tut.homeTabKey,
                                ),
                                _NavIcon(
                                  icon: LucideIcons.book,
                                  label: 'Rezepte',
                                  scale: k,
                                  active: _currentBranch == _kBranchRecipes,
                                  onTap: () => _goBranch(_kBranchRecipes),
                                  itemKey: tut.recipesTabKey,
                                ),
                                if (caloriesEnabled)
                                  _NavIcon(
                                    icon: LucideIcons.flame,
                                    label: 'Kalorien',
                                    scale: k,
                                    active: _currentBranch == _kBranchCalories,
                                    onTap: () => _goBranch(_kBranchCalories),
                                  ),
                                _NavIcon(
                                  icon: LucideIcons.user,
                                  label: 'Profil',
                                  scale: k,
                                  active: _currentBranch == _kBranchProfile,
                                  onTap: () => _goBranch(_kBranchProfile),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 10 * k),
                        _AvoOrb(
                          color: pillColor,
                          scale: k,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/avo');
                          },
                        ),
                      ],
                    ),
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
  final double scale;
  final bool active;
  final VoidCallback onTap;
  final Key? itemKey;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.scale,
    required this.active,
    required this.onTap,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    // Tab = its seat (46 in the mockup), distributed by the pill's
    // spaceAround. The active seat is a soft 12% paper circle so state
    // reads by shape, not just opacity.
    final seat = 46 * scale;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        key: itemKey,
        width: seat,
        height: 58 * scale,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: seat,
            height: seat,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? PaperColors.paper.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: active ? 1.0 : 0.42,
                child: Icon(
                  icon,
                  size: 21 * scale,
                  color: PaperColors.paper,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Detached circular Avo button sitting to the right of the tab pill —
/// same surface and shadow as the pill, so the two read as one system.
class _AvoOrb extends StatelessWidget {
  final Color color;
  final double scale;
  final VoidCallback onTap;

  const _AvoOrb({
    required this.color,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 58 * scale,
        height: 58 * scale,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF201D18).withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            LucideIcons.messageCircle,
            size: 22 * scale,
            color: PaperColors.paper,
            semanticLabel: 'Avo',
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
