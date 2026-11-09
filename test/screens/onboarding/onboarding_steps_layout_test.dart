import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/steps/account_check_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/diet_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/first_list_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/goal_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/join_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/modules_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/region_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/welcome_step.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';

import '../../layout/layout_matrix.dart';
import '../auth/auth_fakes.dart';
import 'onboarding_fakes.dart';

const _progress = StepProgress(step: 2, total: 6, semanticLabel: 'Step 2 of 6');

Widget _scope(Widget child, {OnboardingDraft? draft}) => ProviderScope(
  overrides: [
    ...authOverrides(FakeAuthGateway()),
    ...onboardingOverrides(
      backend: FakeOnboardingBackend(),
      store: FakeModuleStore(),
    ),
    if (draft != null)
      onboardingControllerProvider.overrideWith(
        () => PresetOnboardingController(draft),
      ),
  ],
  child: child,
);

void main() {
  layoutMatrix(
    'Willkommen',
    (context) => _scope(WelcomeStep(onStart: () {}, onLogin: () {})),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Willkommen, Anmelden-Variante mit Einladung',
    (context) => _scope(
      WelcomeStep(
        onStart: () {},
        onLogin: () {},
        returning: true,
        invited: true,
      ),
    ),
  );

  layoutMatrix(
    'Module',
    (context) => _scope(
      ModulesStep(
        progress: _progress,
        onBack: () {},
        onNext: () {},
        onSkip: () {},
      ),
      draft: const OnboardingDraft(modules: {AppModule.calories: true}),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Region',
    (context) => _scope(
      RegionStep(
        progress: _progress,
        onBack: () {},
        onNext: () {},
        onUnavailable: () {},
      ),
    ),
  );

  layoutMatrix(
    'Ernährung und Allergien',
    (context) => _scope(
      DietStep(
        progress: _progress,
        onNext: () {},
        onSkip: () {},
        onBack: () {},
      ),
      // "Mais" is behind "Weitere anzeigen": the chips start expanded.
      draft: const OnboardingDraft(
        diet: {'vegetarian'},
        allergies: {'peanuts', 'nightshades', 'corn'},
      ),
    ),
  );

  layoutMatrix(
    'Dein Ziel',
    (context) => _scope(
      GoalStep(
        progress: _progress,
        onNext: () {},
        onSkip: () {},
        onBack: () {},
      ),
      draft: const OnboardingDraft(
        goal: OnboardingGoalDraft(
          gender: 'female',
          age: 34,
          heightCm: 168,
          currentWeightKg: 68,
          targetWeightKg: 74,
          timelineWeeks: 16,
        ),
      ),
    ),
  );

  layoutMatrix(
    'Dein Ziel, eigenes Ziel',
    (context) => _scope(
      GoalStep(progress: _progress, onNext: () {}, onSkip: () {}),
      draft: const OnboardingDraft(
        goal: OnboardingGoalDraft(
          goalType: NutritionGoalType.custom,
          customCalories: 2100,
        ),
      ),
    ),
    cases: [
      const LayoutCase(width: 320, scale: 1),
      const LayoutCase(width: 320, scale: 3.1),
      const LayoutCase(width: 390, scale: 1),
    ],
  );

  layoutMatrix(
    'Erste Liste',
    (context) => _scope(
      FirstListStep(
        progress: _progress,
        onBack: () {},
        onCreate: (_) async => true,
        onSkip: () {},
      ),
      draft: const OnboardingDraft(listName: 'REWE Wocheneinkauf'),
    ),
  );

  layoutMatrix(
    'Beitreten',
    (context) => _scope(
      JoinStep(
        progress: _progress,
        join: () async => null,
        onJoined: (_) {},
        onDecline: () {},
      ),
    ),
  );

  layoutMatrix(
    'Konto prüfen, fehlgeschlagen',
    (context) =>
        _scope(AccountCheckStep(check: () async => false, failed: true)),
  );
}
