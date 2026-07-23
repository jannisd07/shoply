import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_diet_page.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_goal_page.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_priorities_page.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';

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

/// Paper-style onboarding: three calm feature pages, then /welcome.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _caloriesOptIn = false;
  Set<String> _dietPreferences = {};
  Set<String> _priorities = {};
  OnboardingGoalDraft? _goalDraft;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    // Persist the calorie-tracking choice (skipping keeps the default: off —
    // the toggle stays available in profile settings either way).
    await ref
        .read(calorieTrackingEnabledProvider.notifier)
        .setEnabled(_caloriesOptIn);
    // There's no account yet at this point (onboarding runs before
    // signup/login) — stash the answers locally so they can be applied to
    // the real account the moment one exists (see
    // OnboardingAnswersService / currentUserProvider).
    await OnboardingAnswersService.instance.savePendingAnswers(
      dietPreferences: _dietPreferences.toList(),
      appPriorities: _priorities.toList(),
      caloriesOptedIn: _caloriesOptIn,
      goalDraft: _caloriesOptIn ? _goalDraft : null,
    );
    await markOnboardingComplete();
    if (!mounted) return;
    context.go('/welcome');
  }

  List<Widget> get _pages => [
        _PaperFeaturePage(
          kicker: context.tr('onb_sorted_kicker'),
          title: context.tr('onb_sorted_title'),
          subtitle: context.tr('onb_sorted_sub'),
          illustration: const _SortedListIllustration(),
        ),
        _PaperFeaturePage(
          kicker: context.tr('onb_shared_kicker'),
          title: context.tr('onb_shared_title'),
          subtitle: context.tr('onb_shared_sub'),
          illustration: const _SharedListIllustration(),
        ),
        _PaperFeaturePage(
          kicker: context.tr('onb_recipes_kicker'),
          title: context.tr('onb_recipes_title'),
          subtitle: context.tr('onb_recipes_sub'),
          illustration: const _RecipesIllustration(),
        ),
        OnboardingPrioritiesPage(
          selected: _priorities,
          onChanged: (s) => setState(() => _priorities = s),
        ),
        OnboardingDietPage(
          selected: _dietPreferences,
          onChanged: (s) => setState(() => _dietPreferences = s),
        ),
        _CalorieOptInPage(
          optedIn: _caloriesOptIn,
          onChanged: (v) => setState(() => _caloriesOptIn = v),
        ),
        if (_caloriesOptIn)
          OnboardingGoalPage(
            onDraftChanged: (draft) => _goalDraft = draft,
          ),
      ];

  void _nextPage(int pageCount) {
    if (_currentPage < pageCount - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      unawaited(_finishOnboarding());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final pageCount = pages.length;
    // Swiping back past the goal page (or toggling calorie tracking off
    // while ahead of it) can leave the page index pointing past the end of
    // a now-shorter page list — clamp instead of letting PageView throw.
    if (_currentPage > pageCount - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(pageCount - 1);
          setState(() => _currentPage = pageCount - 1);
        }
      });
    }
    final isLast = _currentPage == pageCount - 1;

    return Scaffold(
      backgroundColor: PaperColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 14, top: 4),
                child: TextButton(
                  onPressed: () => unawaited(_finishOnboarding()),
                  child: Text(
                    context.tr('skip'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: PaperColors.muted,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(pageCount, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 18 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: active
                              ? PaperColors.ink
                              : PaperColors.hairline,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  PaperPrimaryButton(
                    label: isLast
                        ? context.tr('get_started')
                        : context.tr('next'),
                    onPressed: () => _nextPage(pageCount),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperFeaturePage extends StatelessWidget {
  final String kicker;
  final String title;
  final String subtitle;
  final Widget illustration;

  const _PaperFeaturePage({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          illustration,
          const SizedBox(height: 28),
          PaperKicker(kicker, color: PaperColors.terracotta),
          const SizedBox(height: 10),
          Text(title, style: PaperTextStyles.serif(28)),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: PaperTextStyles.body(color: PaperColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Final onboarding page: opt into calorie tracking (Feature 7 — the
/// choice only controls whether the Kalorien tab appears in the navbar
/// and can be changed anytime in profile settings).
class _CalorieOptInPage extends StatelessWidget {
  final bool optedIn;
  final ValueChanged<bool> onChanged;

  const _CalorieOptInPage({required this.optedIn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: PaperColors.cream,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Icon(
                Icons.local_fire_department_outlined,
                size: 64,
                color: PaperColors.creamInk,
              ),
            ),
          ),
          const SizedBox(height: 28),
          PaperKicker(context.tr('onb_cal_kicker'),
              color: PaperColors.terracotta),
          const SizedBox(height: 10),
          Text(context.tr('onb_cal_title'), style: PaperTextStyles.serif(28)),
          const SizedBox(height: 12),
          Text(
            context.tr('onb_cal_sub'),
            style: PaperTextStyles.body(color: PaperColors.muted),
          ),
          const SizedBox(height: 20),
          _CalorieChoiceCard(
            label: context.tr('onb_cal_no'),
            selected: !optedIn,
            onTap: () => onChanged(false),
          ),
          const SizedBox(height: 10),
          _CalorieChoiceCard(
            label: context.tr('onb_cal_yes'),
            selected: optedIn,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _CalorieChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CalorieChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: PaperColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? PaperColors.ink : PaperColors.hairline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: PaperColors.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 18, color: PaperColors.ink),
          ],
        ),
      ),
    );
  }
}

/// Sage block with a mini list whose items carry category labels.
class _SortedListIllustration extends StatelessWidget {
  const _SortedListIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PaperColors.sage,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: PaperColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _MiniKicker('OBST & GEMÜSE'),
              _MiniItem('Tomaten', checked: true),
              _MiniItem('Avocados'),
              SizedBox(height: 8),
              _MiniKicker('MILCHPRODUKTE'),
              _MiniItem('Milch'),
              _MiniItem('Joghurt'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cream block with overlapping member avatars and a shared row.
class _SharedListIllustration extends StatelessWidget {
  const _SharedListIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PaperColors.cream,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 108,
              height: 52,
              child: Stack(
                children: const [
                  _AvatarDot('J', PaperColors.creamInk, left: 0),
                  _AvatarDot('M', PaperColors.terracotta, left: 28),
                  _AvatarDot('L', PaperColors.sageInk, left: 56),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: PaperColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: const Text(
                'Marie hat „Milch" abgehakt',
                style: TextStyle(fontSize: 13, color: PaperColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blush block with a recipe card and a swap hint.
class _RecipesIllustration extends StatelessWidget {
  const _RecipesIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PaperColors.blush,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Container(
          width: 210,
          decoration: BoxDecoration(
            color: PaperColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: PaperColors.sage,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 10),
              Text('Ofengemüse', style: PaperTextStyles.serif(16)),
              const SizedBox(height: 4),
              const Text(
                '35 Min · vegetarisch',
                style: TextStyle(fontSize: 11, color: PaperColors.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: PaperColors.terracotta,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sahne → Hafercreme',
                      style: TextStyle(
                        fontSize: 12,
                        color: PaperColors.terracotta,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniKicker extends StatelessWidget {
  final String text;

  const _MiniKicker(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 1.5,
          color: PaperColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniItem extends StatelessWidget {
  final String text;
  final bool checked;

  const _MiniItem(this.text, {this.checked = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checked ? PaperColors.terracotta : null,
              border: checked
                  ? null
                  : Border.all(color: PaperColors.faint, width: 1.2),
            ),
            child: checked
                ? const Icon(Icons.check, size: 10, color: PaperColors.paper)
                : null,
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: checked ? PaperColors.faint : PaperColors.ink,
              decoration: checked ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  final String initial;
  final Color color;
  final double left;

  const _AvatarDot(this.initial, this.color, {required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: PaperColors.cream, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 18,
            color: PaperColors.paper,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
