import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_descriptors.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';

import 'onboarding_fakes.dart';

void main() {
  late FakeOnboardingBackend backend;
  late FakeModuleStore store;
  late ProviderContainer container;

  Future<ProviderContainer> make([Map<String, Object> prefs = const {}]) async {
    await attachPrefs(prefs);
    final c = ProviderContainer(
      overrides: onboardingOverrides(backend: backend, store: store),
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    backend = FakeOnboardingBackend();
    store = FakeModuleStore();
    container = await make();
  });

  tearDown(() => OnboardingPrefs.instance.detach());

  group('plan and progress', () {
    test('standard run: 6 counted steps, e-mail and code count as Konto', () {
      final plan = plannedOnboardingSteps(
        mode: AccountStepMode.signUp,
        offersStep: true,
        goalStep: false,
      );
      expect(plan, [
        OnboardingStep.modules,
        OnboardingStep.region,
        OnboardingStep.account,
        OnboardingStep.name,
        OnboardingStep.diet,
        OnboardingStep.firstList,
      ]);
      ({int step, int total})? p(OnboardingStep s) =>
          onboardingProgress(plan, s, mode: AccountStepMode.signUp);
      expect(p(OnboardingStep.modules), (step: 1, total: 6));
      expect(p(OnboardingStep.email), (step: 3, total: 6));
      expect(p(OnboardingStep.code), (step: 3, total: 6));
      expect(p(OnboardingStep.firstList), (step: 6, total: 6));
      expect(p(OnboardingStep.welcome), isNull);
      expect(
        nextOnboardingStep(plan, OnboardingStep.welcome),
        OnboardingStep.modules,
      );
      expect(
        nextOnboardingStep(plan, OnboardingStep.code),
        OnboardingStep.name,
      );
      expect(nextOnboardingStep(plan, OnboardingStep.firstList), isNull);
    });

    test('Anmelden with a new account: modules after the account, '
        'the account step shows no line', () {
      final plan = plannedOnboardingSteps(
        mode: AccountStepMode.login,
        offersStep: false,
        goalStep: true,
      );
      expect(plan, [
        OnboardingStep.account,
        OnboardingStep.modules,
        OnboardingStep.name,
        OnboardingStep.diet,
        OnboardingStep.goal,
        OnboardingStep.firstList,
      ]);
      expect(
        onboardingProgress(
          plan,
          OnboardingStep.account,
          mode: AccountStepMode.login,
        ),
        isNull,
      );
      expect(
        onboardingProgress(
          plan,
          OnboardingStep.modules,
          mode: AccountStepMode.login,
        ),
        (step: 1, total: 5),
      );
    });

    test('region only with the offers module', () async {
      final c = container.onboarding;
      expect(c.plan, contains(OnboardingStep.region));
      c.setModule(AppModule.offers, false);
      await c.commitModules();
      expect(c.plan, isNot(contains(OnboardingStep.region)));
      c.setModule(AppModule.offers, true);
      await c.commitModules();
      expect(c.plan, contains(OnboardingStep.region));
      // Teil B had nothing to show: left out for the rest of the run.
      c.markRegionHidden();
      expect(c.plan, isNot(contains(OnboardingStep.region)));
    });

    test('goal only with the calories module', () async {
      final c = container.onboarding;
      expect(c.plan, isNot(contains(OnboardingStep.goal)));
      c.setModule(AppModule.calories, true);
      await c.commitModules();
      expect(c.plan, contains(OnboardingStep.goal));
      expect(c.nextAfter(OnboardingStep.diet), OnboardingStep.goal);
    });

    test('the line changes only when the module step is left', () async {
      final c = container.onboarding;
      final before = c.progressOf(OnboardingStep.modules);
      c.setModule(AppModule.calories, true);
      expect(c.progressOf(OnboardingStep.modules), before);
      await c.commitModules();
      expect(c.progressOf(OnboardingStep.modules)!.total, before!.total + 1);
    });
  });

  group('answers', () {
    test('skipping the module step takes the defaults', () async {
      final c = container.onboarding;
      c.setModule(AppModule.calories, true);
      c.setModule(AppModule.offers, false);
      await c.commitModules(skip: true);
      expect(container.draft.moduleChoice, AppModulesState.onboardingDefaults);
      expect(container.draft.isOn(AppModule.offers), isTrue);
      expect(container.draft.isOn(AppModule.calories), isFalse);
    });

    test('every change is saved, a new controller resumes', () async {
      final c = container.onboarding;
      c.setModule(AppModule.calories, true);
      await c.commitModules();
      c.setDiet(diet: {'vegan'}, allergies: {'peanuts'});
      c.enterStep(OnboardingStep.region);
      await settleWrites();
      final prefs = OnboardingPrefs.instance.raw!;
      expect(prefs.getString(kOnboardingStepKey), 'region');
      expect(prefs.getString(kPendingModulesKey), contains('"calories":true'));

      final resumed = ProviderContainer(
        overrides: onboardingOverrides(backend: backend, store: store),
      );
      addTearDown(resumed.dispose);
      final draft = resumed.draft;
      expect(draft.step, OnboardingStep.region);
      expect(draft.isOn(AppModule.calories), isTrue);
      expect(draft.isOn(AppModule.calories, planned: true), isTrue);
      expect(draft.diet, {'vegan'});
      expect(draft.allergies, {'peanuts'});
    });

    test('resumes from saved preferences', () async {
      final c = await make({
        kOnboardingStepKey: 'diet',
        kPendingModulesKey: jsonEncode({'offers': false, 'calories': true}),
        kOnboardingDraftKey: jsonEncode({
          'mode': 'login',
          'account_ready': true,
          'list_name': 'Lidl',
        }),
      });
      final draft = c.draft;
      expect(draft.step, OnboardingStep.diet);
      expect(draft.mode, AccountStepMode.login);
      expect(draft.accountReady, isTrue);
      expect(draft.listName, 'Lidl');
      expect(c.onboarding.plan, isNot(contains(OnboardingStep.region)));
      expect(c.onboarding.plan, contains(OnboardingStep.goal));
    });

    test('Willkommen is no step to resume in', () async {
      final c = container.onboarding;
      c.enterStep(OnboardingStep.modules);
      await settleWrites();
      c.enterStep(OnboardingStep.welcome);
      await settleWrites();
      expect(OnboardingPrefs.instance.resumeStep, isNull);
    });

    test('Ernährung writes both columns, merged (9.7)', () async {
      final c = container.onboarding;
      c.setDiet(diet: {'vegetarian'}, allergies: {'gluten', 'milk', 'peanuts'});
      c.finishDiet();
      await settleWrites();
      expect(backend.diets.single.diet, [
        'vegetarian',
        'gluten_free',
        'dairy_free',
        'nut_free',
      ]);
      expect(backend.diets.single.allergies, ['gluten', 'peanuts', 'milk']);
    });

    test('skipping Ernährung writes nothing and keeps defaults', () async {
      final c = container.onboarding;
      c.setDiet(diet: {'vegan'});
      c.finishDiet(skip: true);
      await settleWrites();
      expect(backend.diets, isEmpty);
      expect(container.draft.diet, isEmpty);
      expect(container.draft.dietSkipped, isTrue);
    });

    test('Dein Ziel saves only complete data', () async {
      final c = container.onboarding;
      c.finishGoal();
      await settleWrites();
      expect(backend.goals, isEmpty);
      expect(backend.calorieSwitches, 1);

      c.setGoal(
        const OnboardingGoalDraft(
          gender: 'female',
          age: 34,
          heightCm: 168,
          currentWeightKg: 68,
          targetWeightKg: 64,
        ),
      );
      c.finishGoal();
      await settleWrites();
      expect(backend.goals.single.age, 34);
    });

    test('a failed write is offered again', () async {
      final c = container.onboarding;
      backend.failWrites = true;
      c.setDiet(diet: {'vegan'});
      c.finishDiet();
      await settleWrites();
      expect(container.draft.syncFailed, isTrue);
      backend.failWrites = false;
      await c.retrySync();
      expect(container.draft.syncFailed, isFalse);
      expect(backend.diets, hasLength(1));
    });
  });

  group('neu oder eingerichtet', () {
    test('new account: modules from before go into the account', () async {
      final c = container.onboarding;
      c.setModule(AppModule.costSplit, true);
      await c.commitModules();
      final status = await c.resolveAccount();
      await settleWrites();
      expect(status, AccountSetupStatus.isNew);
      expect(container.draft.accountReady, isTrue);
      expect(store.remote?['cost_split'], isTrue);
      expect(OnboardingPrefs.instance.deviceOnboarded, isFalse);
    });

    test('set-up account: local answers are dropped', () async {
      final c = container.onboarding;
      c.setModule(AppModule.calories, true);
      c.setDiet(diet: {'vegan'});
      c.enterStep(OnboardingStep.account);
      await settleWrites();
      backend.status = AccountSetupStatus.setUp;
      await c.resolveAccount();
      await settleWrites();
      expect(store.remote, isNull);
      expect(container.draft.diet, isEmpty);
      final prefs = OnboardingPrefs.instance.raw!;
      expect(prefs.getString(kPendingModulesKey), isNull);
      expect(prefs.getString(kOnboardingDraftKey), isNull);
      expect(OnboardingPrefs.instance.resumeStep, isNull);
      expect(OnboardingPrefs.instance.deviceOnboarded, isTrue);
    });

    test('the check throws when the server is unreachable', () async {
      backend.failStatus = true;
      expect(container.onboarding.resolveAccount(), throwsStateError);
    });

    test('the end sets onboarding_completed and closes the run', () async {
      final c = container.onboarding;
      await c.resolveAccount();
      c.enterStep(OnboardingStep.firstList);
      await c.complete();
      await settleWrites();
      expect(backend.completed, 1);
      expect(OnboardingPrefs.instance.resumeStep, isNull);
      expect(OnboardingPrefs.instance.deviceOnboarded, isTrue);
    });

    test('decideAccountStatus: flag or an account older than the cutoff', () {
      final cutoff = DateTime.utc(2026, 11, 9);
      expect(
        decideAccountStatus(onboardingCompleted: true, cutoff: cutoff),
        AccountSetupStatus.setUp,
      );
      expect(
        decideAccountStatus(
          createdAt: DateTime.utc(2025, 3, 1),
          cutoff: cutoff,
        ),
        AccountSetupStatus.setUp,
      );
      expect(
        decideAccountStatus(
          onboardingCompleted: false,
          createdAt: DateTime.utc(2026, 11, 10),
          cutoff: cutoff,
        ),
        AccountSetupStatus.isNew,
      );
      expect(decideAccountStatus(cutoff: cutoff), AccountSetupStatus.isNew);
    });
  });

  group('data', () {
    test('the goal estimate matches Konzept 17 §3.10', () {
      const draft = OnboardingGoalDraft(
        goalType: NutritionGoalType.loseWeight,
        activityLevel: ActivityLevel.light,
        gender: 'female',
        age: 34,
        heightCm: 168,
        currentWeightKg: 68,
        targetWeightKg: 64,
        timelineWeeks: 16,
      );
      final t = draft.targets()!;
      expect(t.dailyCalorieTarget, 1649);
      expect(t.proteinTargetG, 122);
      expect(t.fatTargetG, 51);
      expect(t.carbsTargetG, 175);
      expect(const OnboardingGoalDraft(age: 34).targets(), isNull);
      expect(
        const OnboardingGoalDraft(
          goalType: NutritionGoalType.custom,
          customCalories: 2100,
        ).isComplete,
        isTrue,
      );
    });

    test('the allergy chips are exactly the 20 values of AllergyType', () {
      final shown = {...kOnboardingAllergies, ...kOnboardingMoreAllergies};
      expect(shown, AllergyType.values.toSet());
      expect(kOnboardingAllergies, hasLength(15));
      expect(
        kOnboardingDietIds,
        isNot(
          anyOf(
            contains('gluten_free'),
            contains('dairy_free'),
            contains('nut_free'),
          ),
        ),
      );
      expect(allergiesImpliedByDiet(['gluten_free', 'nut_free']), {
        'gluten',
        'nuts',
      });
    });

    test('module rows: unreleased modules never show', () {
      final rows = visibleModuleDescriptors().map((d) => d.module).toList();
      expect(rows, [
        AppModule.offers,
        AppModule.avo,
        AppModule.calories,
        AppModule.costSplit,
      ]);
      expect(
        visibleModuleDescriptors(offersAvailable: false).map((d) => d.module),
        isNot(contains(AppModule.offers)),
      );
    });

    test('every dynamic text key exists in both languages', () {
      final keys = [
        for (final t in AllergyType.values) 'onb_allergy_${t.name}',
        for (final d in moduleDescriptors) ...[d.titleKey, d.benefitKey],
        for (final id in kOnboardingDietIds) 'diet_$id',
        for (final l in ActivityLevel.values) ...[
          'activity_${l.dbValue}',
          'activity_${l.dbValue}_sub',
        ],
        for (final g in NutritionGoalType.values) 'goal_type_${g.dbValue}',
        for (final g in ['female', 'male', 'other']) 'gender_$g',
      ];
      for (final key in keys) {
        expect(AppTranslations.get(key, 'en'), isNot(key), reason: key);
        expect(AppTranslations.get(key, 'de'), isNot(key), reason: key);
      }
      for (final de in [
        AppTranslations.get('onb_welcome_sentence', 'de'),
        AppTranslations.get('onb_modules_title', 'de'),
      ]) {
        expect(de.contains('Shoply'), isFalse);
        expect(de.contains('\n'), isFalse);
      }
    });
  });
}
