import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// Key used to track onboarding completion in SharedPreferences
const String kOnboardingCompleteKey = 'onboarding_complete_v1';

/// Check if onboarding has been completed
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kOnboardingCompleteKey) ?? false;
}

/// Mark onboarding as completed
Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kOnboardingCompleteKey, true);
}

// ─── Category model for the demo animation ──────────────────────────
class _DemoCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _DemoCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.items,
  });
}

const _demoCategories = [
  _DemoCategory(
    name: 'Milchprodukte',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF60A5FA),
    items: ['Milch', 'Joghurt'],
  ),
  _DemoCategory(
    name: 'Obst & Gemüse',
    icon: Icons.eco_outlined,
    color: Color(0xFF4ADE80),
    items: ['Äpfel', 'Tomaten'],
  ),
  _DemoCategory(
    name: 'Backwaren',
    icon: Icons.bakery_dining_outlined,
    color: Color(0xFFFBBF24),
    items: ['Brot'],
  ),
  _DemoCategory(
    name: 'Fleisch',
    icon: Icons.restaurant_outlined,
    color: Color(0xFFF87171),
    items: ['Hähnchen'],
  ),
];

const _allDemoItems = [
  'Milch',
  'Brot',
  'Tomaten',
  'Äpfel',
  'Hähnchen',
  'Joghurt',
];

// ─── Main onboarding screen ─────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await markOnboardingComplete();
    if (!mounted) return;
    context.go('/welcome');
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      unawaited(_finishOnboarding());
    }
  }

  void _skipToAuth() {
    unawaited(_finishOnboarding());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Page view
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _AIDemoPage(onNext: _nextPage),
              _SharedListsPage(onNext: _nextPage),
              _IngredientSwapPage(onNext: _nextPage),
            ],
          ),

          // Top: skip button (feature pages only)
          if (_currentPage < 3)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: TextButton(
                onPressed: _skipToAuth,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Bottom: page indicator (feature pages only)
          if (_currentPage < 3)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAGE 1: AI Categorization Demo
// ═══════════════════════════════════════════════════════════════════════
class _AIDemoPage extends StatefulWidget {
  final VoidCallback onNext;
  const _AIDemoPage({required this.onNext});

  @override
  State<_AIDemoPage> createState() => _AIDemoPageState();
}

class _AIDemoPageState extends State<_AIDemoPage>
    with TickerProviderStateMixin {
  // Phase tracking
  int _typedCount = 0; // how many items have "appeared"
  bool _sorted = false;
  Timer? _typeTimer;

  late final AnimationController _sortController;
  late final Animation<double> _sortAnimation;

  @override
  void initState() {
    super.initState();
    _sortController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sortAnimation = CurvedAnimation(
      parent: _sortController,
      curve: Curves.easeOutBack,
    );

    // Start the typing sequence after a short delay
    Future.delayed(const Duration(milliseconds: 600), _startTyping);
  }

  void _startTyping() {
    _typeTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_typedCount < _allDemoItems.length) {
        setState(() => _typedCount++);
      } else {
        timer.cancel();
        // Pause, then sort
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() => _sorted = true);
            _sortController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _sortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        left: 24,
        right: 24,
      ),
      child: Column(
        children: [
          // Title
          const Text(
            'Deine KI-Einkaufsliste.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Artikel werden automatisch sortiert.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Demo area
          Expanded(
            child: AnimatedBuilder(
              animation: _sortAnimation,
              builder: (context, _) =>
                  _sorted ? _buildSortedView() : _buildUnsortedList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Weiter',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsortedList() {
    return _ShoppingListPreview(
      child: Column(
        children: List.generate(_typedCount, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: _buildPlainItem(_allDemoItems[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSortedView() {
    return _ShoppingListPreview(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: _demoCategories.map((cat) {
          return FadeTransition(
            opacity: _sortAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(_sortAnimation),
              child: _buildCategorySection(cat),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySection(_DemoCategory cat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.icon, size: 17, color: cat.color),
              ),
              const SizedBox(width: 10),
              Text(
                cat.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cat.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cat.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildPlainItem(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingListPreview extends StatelessWidget {
  final Widget child;

  const _ShoppingListPreview({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wocheneinkauf',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '6 Artikel automatisch einsortiert',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAGE 2: Shared Lists Demo
// ═══════════════════════════════════════════════════════════════════════
class _SharedListsPage extends StatefulWidget {
  final VoidCallback onNext;
  const _SharedListsPage({required this.onNext});

  @override
  State<_SharedListsPage> createState() => _SharedListsPageState();
}

class _SharedListsPageState extends State<_SharedListsPage>
    with TickerProviderStateMixin {
  late final AnimationController _phoneController;
  late final AnimationController _itemController;
  late final AnimationController _pulseController;

  bool _itemAdded = false;
  bool _itemSynced = false;

  @override
  void initState() {
    super.initState();
    _phoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _itemController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Sequence: phones slide in -> item appears on left -> syncs to right
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _phoneController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _itemAdded = true);
        _itemController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) {
        setState(() => _itemSynced = true);
        _pulseController.forward();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _itemController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        left: 24,
        right: 24,
      ),
      child: Column(
        children: [
          // Title
          const Text(
            'Teile Listen in Echtzeit.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Rezepte entdecken. Zutaten mit einem Tap hinzufügen.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Two phone mockups
          Expanded(
            child: AnimatedBuilder(
              animation: _phoneController,
              builder: (context, _) {
                final slide = CurvedAnimation(
                  parent: _phoneController,
                  curve: Curves.easeOutCubic,
                ).value;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left phone
                    Transform.translate(
                      offset: Offset(-30 * (1 - slide), 0),
                      child: Opacity(
                        opacity: slide,
                        child: _buildPhone(
                          isLeft: true,
                          showNewItem: _itemAdded,
                          itemAnimation: _itemController,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right phone
                    Transform.translate(
                      offset: Offset(30 * (1 - slide), 0),
                      child: Opacity(
                        opacity: slide,
                        child: _buildPhone(
                          isLeft: false,
                          showNewItem: _itemSynced,
                          itemAnimation: _pulseController,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Next button
          AnimatedOpacity(
            opacity: _itemSynced ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _itemSynced ? widget.onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Weiter',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhone({
    required bool isLeft,
    required bool showNewItem,
    required AnimationController itemAnimation,
  }) {
    return Container(
      width: 155,
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Icon(
                    isLeft ? Icons.person : Icons.person_outline,
                    size: 14,
                    color: Colors.white54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isLeft ? 'Du' : 'Partner',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Einkaufsliste',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          // Existing items
          _buildMiniItem('Milch', true),
          _buildMiniItem('Brot', false),
          _buildMiniItem('Eier', false),
          const SizedBox(height: 4),
          // New synced item
          if (showNewItem)
            FadeTransition(
              opacity: itemAnimation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: itemAnimation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Avocados 🥑',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildMiniItem(String name, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: checked ? Colors.white24 : Colors.white30,
                width: 1,
              ),
              color: checked ? Colors.white24 : Colors.transparent,
            ),
            child: checked
                ? const Icon(Icons.check, size: 10, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              color: checked ? Colors.white38 : Colors.white70,
              decoration: checked ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAGE 3: Ingredient Swap Demo
// ═══════════════════════════════════════════════════════════════════════
class _IngredientSwapPage extends StatefulWidget {
  final VoidCallback onNext;
  const _IngredientSwapPage({required this.onNext});

  @override
  State<_IngredientSwapPage> createState() => _IngredientSwapPageState();
}

class _IngredientSwapPageState extends State<_IngredientSwapPage> {
  bool _swapEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        left: 24,
        right: 24,
      ),
      child: Column(
        children: [
          const Text(
            'Rezepte passen sich dir an.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Avo kann Zutaten automatisch ersetzen.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 44),

          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Automatisch ersetzen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'nach deinen Ernährungspräferenzen',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _swapEnabled,
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withValues(
                            alpha: 0.35,
                          ),
                          onChanged: (value) =>
                              setState(() => _swapEnabled = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _swapEnabled
                          ? const _SwapPreview(
                              key: ValueKey('enabled'),
                              rows: [
                                _IngredientSwap('Sahne', 'Hafercuisine'),
                                _IngredientSwap('Butter', 'Olivenöl'),
                                _IngredientSwap('Parmesan', 'Hefeflocken'),
                              ],
                            )
                          : const _SwapPreview(
                              key: ValueKey('disabled'),
                              rows: [
                                _IngredientSwap('Sahne', null),
                                _IngredientSwap('Butter', null),
                                _IngredientSwap('Parmesan', null),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Weiter',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientSwap {
  final String original;
  final String? replacement;

  const _IngredientSwap(this.original, this.replacement);
}

class _SwapPreview extends StatelessWidget {
  final List<_IngredientSwap> rows;

  const _SwapPreview({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(children: rows.map((row) => _SwapRow(row: row)).toList());
  }
}

class _SwapRow extends StatelessWidget {
  final _IngredientSwap row;

  const _SwapRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final replacement = row.replacement;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.original,
              style: TextStyle(
                color: replacement == null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.42),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: replacement == null
                    ? null
                    : TextDecoration.lineThrough,
                decorationColor: Colors.white38,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: replacement == null
                ? const SizedBox(width: 22, height: 22)
                : Row(
                    key: ValueKey(replacement),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white30,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          replacement,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
