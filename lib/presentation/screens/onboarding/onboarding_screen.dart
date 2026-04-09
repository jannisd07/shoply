import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/presentation/screens/auth/widgets/social_button.dart';
import 'package:shoply/data/services/supabase_service.dart';

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

const _allDemoItems = ['Milch', 'Brot', 'Tomaten', 'Äpfel', 'Hähnchen', 'Joghurt'];

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

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skipToAuth() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
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
              _AuthPage(
                onComplete: () async {
                  await markOnboardingComplete();
                  if (mounted) context.go('/home');
                },
                onNeedName: () async {
                  await markOnboardingComplete();
                  if (mounted) context.go('/name-prompt');
                },
              ),
            ],
          ),

          // Top: skip button (pages 0 and 1 only)
          if (_currentPage < 2)
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

          // Bottom: page indicator (pages 0 and 1 only)
          if (_currentPage < 2)
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

class _AIDemoPageState extends State<_AIDemoPage> with TickerProviderStateMixin {
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
              builder: (context, _) => _sorted
                  ? _buildSortedView()
                  : _buildUnsortedList(),
            ),
          ),

          // Next button (appears after sort)
          AnimatedOpacity(
            opacity: _sorted && _sortAnimation.value > 0.5 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _sorted ? widget.onNext : null,
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

  Widget _buildUnsortedList() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(_typedCount, (i) {
        return TweenAnimationBuilder<double>(
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
          child: _buildItemTile(_allDemoItems[i]),
        );
      }),
    );
  }

  Widget _buildSortedView() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: _demoCategories.map((cat) {
        return FadeTransition(
          opacity: _sortAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(_sortAnimation),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cat.color.withValues(alpha: 0.15),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header
                    Row(
                      children: [
                        Icon(cat.icon, size: 18, color: cat.color),
                        const SizedBox(width: 8),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cat.color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Items
                    ...cat.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemTile(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: itemAnimation,
                  curve: Curves.easeOutBack,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
// PAGE 3: Name + Auth
// ═══════════════════════════════════════════════════════════════════════
class _AuthPage extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onNeedName;
  const _AuthPage({required this.onComplete, required this.onNeedName});

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleAppleLogin() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final success = await SupabaseService.instance.signInWithApple();
      if (success && mounted) {
        await _saveNameAndComplete();
      }
    } catch (e) {
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Apple Sign In fehlgeschlagen';
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final success = await SupabaseService.instance.signInWithGoogle();
      if (success && mounted) {
        await _saveNameAndComplete();
      }
    } catch (e) {
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Google Sign In fehlgeschlagen';
      });
    }
  }

  Future<void> _saveNameAndComplete() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      try {
        final user = SupabaseService.instance.currentUser;
        if (user != null) {
          await SupabaseService.instance.client
              .from('users')
              .update({
                'display_name': name,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', user.id);
        }
      } catch (_) {}
      widget.onComplete();
    } else {
      // No name entered, let router redirect to name-prompt
      widget.onNeedName();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 40,
          left: 24,
          right: 24,
          bottom: bottomPad + 24,
        ),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Avo mascot
            const AvoMascot(
              size: 100,
              expression: AvoExpression.excited,
            ),
            const SizedBox(height: 20),

            // Speech bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Hey! Ich bin Avo 🥑\nDein smarter Einkaufsbegleiter!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Name input
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Dein Name',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Error message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 14),
                ),
              ),

            // Apple sign in (iOS only)
            if (Platform.isIOS) ...[
              SocialButton(
                text: 'Continue with Apple',
                icon: Icons.apple,
                backgroundColor: Colors.white,
                textColor: Colors.black,
                iconColor: Colors.black,
                onPressed: _isLoading ? () {} : () => _handleAppleLogin(),
              ),
              const SizedBox(height: 10),
            ],

            // Google sign in
            SocialButton(
              text: 'Continue with Google',
              customIcon: const GoogleLogo(size: 20),
              backgroundColor: const Color(0xFF1C1C1E),
              textColor: Colors.white,
              iconColor: Colors.white,
              onPressed: _isLoading ? () {} : () => _handleGoogleLogin(),
            ),
            const SizedBox(height: 10),

            // Email sign up
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        await markOnboardingComplete();
                        if (mounted) context.push('/signup');
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign up with Email',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Already have account
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      await markOnboardingComplete();
                      if (mounted) context.push('/login');
                    },
              child: Text(
                'Bereits ein Konto? Anmelden',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: CupertinoActivityIndicator(color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }
}
