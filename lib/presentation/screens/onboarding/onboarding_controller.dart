import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';

/// Steps that need an account before them in the new-user flow.
const Set<OnboardingStep> _postAccountSteps = {
  OnboardingStep.name,
  OnboardingStep.diet,
  OnboardingStep.goal,
  OnboardingStep.firstList,
};

/// Steps that belong to the account step and show its progress.
const Set<OnboardingStep> _accountSteps = {
  OnboardingStep.account,
  OnboardingStep.email,
  OnboardingStep.code,
};

/// Everything the flow has collected (Konzept 17 §1.2). Before the account it
/// lives only here and in SharedPreferences.
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.mode = AccountStepMode.signUp,
    this.step = OnboardingStep.welcome,
    this.modules = const {},
    this.plannedModules = const {},
    this.diet = const {},
    this.allergies = const {},
    this.dietSkipped = false,
    this.goal = const OnboardingGoalDraft(),
    this.listName = '',
    this.accountReady = false,
    this.regionHidden = false,
    this.joinDeclined = false,
    this.syncFailed = false,
  });

  /// New user (Los geht's) or "Ich habe schon ein Konto".
  final AccountStepMode mode;

  /// The step on screen, saved as `onb_step`.
  final OnboardingStep step;

  /// The module switches as they are now (defaults where missing).
  final Map<AppModule, bool> modules;

  /// The choice the remaining steps are planned with. Updated when the
  /// module step is left, so the progress line never changes while someone
  /// reads the switches (Konzept 17 §2.2).
  final Map<AppModule, bool> plannedModules;

  /// Diet ids from [kOnboardingDietIds].
  final Set<String> diet;

  /// `AllergyType` names.
  final Set<String> allergies;

  /// Ernährung was skipped (Tipp T7 asks later, Konzept 17 §6.1).
  final bool dietSkipped;

  final OnboardingGoalDraft goal;

  /// What the person typed in "Deine erste Liste".
  final String listName;

  /// Signed in with an account that is not set up yet: the answers from
  /// before are in it and there is no way back to the account step.
  final bool accountReady;

  /// Teil B's region step had nothing to show (kill switch, no data): it is
  /// left out without a trace for the rest of this run.
  final bool regionHidden;

  /// "Nicht beitreten": the last step is the first list after all.
  final bool joinDeclined;

  /// A background write failed; the next step shows "Erneut versuchen".
  final bool syncFailed;

  bool isOn(AppModule module, {bool planned = false}) {
    final source = planned ? plannedModules : modules;
    return source[module] ??
        AppModulesState.onboardingDefaults[module] ??
        false;
  }

  /// The full module choice, defaults filled in.
  Map<AppModule, bool> get moduleChoice => {
    for (final m in AppModule.values) m: isOn(m),
  };

  OnboardingDraft copyWith({
    AccountStepMode? mode,
    OnboardingStep? step,
    Map<AppModule, bool>? modules,
    Map<AppModule, bool>? plannedModules,
    Set<String>? diet,
    Set<String>? allergies,
    bool? dietSkipped,
    OnboardingGoalDraft? goal,
    String? listName,
    bool? accountReady,
    bool? regionHidden,
    bool? joinDeclined,
    bool? syncFailed,
  }) => OnboardingDraft(
    mode: mode ?? this.mode,
    step: step ?? this.step,
    modules: modules ?? this.modules,
    plannedModules: plannedModules ?? this.plannedModules,
    diet: diet ?? this.diet,
    allergies: allergies ?? this.allergies,
    dietSkipped: dietSkipped ?? this.dietSkipped,
    goal: goal ?? this.goal,
    listName: listName ?? this.listName,
    accountReady: accountReady ?? this.accountReady,
    regionHidden: regionHidden ?? this.regionHidden,
    joinDeclined: joinDeclined ?? this.joinDeclined,
    syncFailed: syncFailed ?? this.syncFailed,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'diet': diet.toList(),
    'allergies': allergies.toList(),
    'diet_skipped': dietSkipped,
    'goal': goal.toJson(),
    'list_name': listName,
    'account_ready': accountReady,
  };

  static OnboardingDraft fromPrefs(SharedPreferences? prefs) {
    if (prefs == null) return const OnboardingDraft();
    Map<AppModule, bool> modules = const {};
    final rawModules = prefs.getString(kPendingModulesKey);
    if (rawModules != null) {
      try {
        modules = AppModulesState.decode(
          (jsonDecode(rawModules) as Map).cast<String, dynamic>(),
          AppModulesState.onboardingDefaults,
        );
      } catch (_) {}
    }
    var draft = OnboardingDraft(modules: modules, plannedModules: modules);
    final raw = prefs.getString(kOnboardingDraftKey);
    if (raw != null) {
      try {
        final json = (jsonDecode(raw) as Map).cast<String, Object?>();
        draft = draft.copyWith(
          mode: json['mode'] == AccountStepMode.login.name
              ? AccountStepMode.login
              : AccountStepMode.signUp,
          diet: {...?(json['diet'] as List?)?.whereType<String>()},
          allergies: {...?(json['allergies'] as List?)?.whereType<String>()},
          dietSkipped: json['diet_skipped'] == true,
          goal: json['goal'] is Map
              ? OnboardingGoalDraft.fromJson(
                  (json['goal'] as Map).cast<String, Object?>(),
                )
              : null,
          listName: json['list_name'] as String? ?? '',
          accountReady: json['account_ready'] == true,
        );
      } catch (_) {}
    }
    final step = OnboardingStep.fromId(prefs.getString(kOnboardingStepKey));
    return step == null ? draft : draft.copyWith(step: step);
  }
}

/// The steps of a run in order (Konzept 17 §1.1). [offersStep] false leaves
/// out the region step (module off or Teil B had nothing to show).
List<OnboardingStep> plannedOnboardingSteps({
  required AccountStepMode mode,
  required bool offersStep,
  required bool goalStep,
}) {
  final afterModules = [if (offersStep) OnboardingStep.region];
  final tail = [
    OnboardingStep.name,
    OnboardingStep.diet,
    if (goalStep) OnboardingStep.goal,
    OnboardingStep.firstList,
  ];
  return mode == AccountStepMode.signUp
      ? [
          OnboardingStep.modules,
          ...afterModules,
          OnboardingStep.account,
          ...tail,
        ]
      : [
          OnboardingStep.account,
          OnboardingStep.modules,
          ...afterModules,
          ...tail,
        ];
}

/// "Schritt x von n" of [step] in [plan]; null when the step shows no line
/// (Willkommen; the account steps in the login variant, Konzept 17 §4.1).
({int step, int total})? onboardingProgress(
  List<OnboardingStep> plan,
  OnboardingStep step, {
  required AccountStepMode mode,
}) {
  final counted = mode == AccountStepMode.login
      ? [
          for (final s in plan)
            if (s != OnboardingStep.account) s,
        ]
      : plan;
  final key = _accountSteps.contains(step) ? OnboardingStep.account : step;
  final index = counted.indexOf(key);
  if (index < 0) return null;
  return (step: index + 1, total: counted.length);
}

/// The step after [step] in [plan]; null at the end. Email and code count as
/// the account step.
OnboardingStep? nextOnboardingStep(
  List<OnboardingStep> plan,
  OnboardingStep step,
) {
  final key = _accountSteps.contains(step) ? OnboardingStep.account : step;
  if (key == OnboardingStep.welcome) return plan.first;
  final index = plan.indexOf(key);
  if (index < 0 || index + 1 >= plan.length) return null;
  return plan[index + 1];
}

/// The onboarding answers and where the run stands (Konzept 17 §1.2, §5.5).
/// Saves after every change, so a killed app resumes in the same step with
/// all inputs. Writes after the account go out at once in the background;
/// a failure shows up as [OnboardingDraft.syncFailed] in the next step.
class OnboardingController extends Notifier<OnboardingDraft> {
  final Map<String, Future<void> Function()> _failed = {};

  @override
  OnboardingDraft build() => OnboardingDraft.fromPrefs(_prefs);

  SharedPreferences? get _prefs => OnboardingPrefs.instance.raw;

  OnboardingAccountBackend get _backend => ref.read(onboardingBackendProvider);

  // --------------------------------------------------------------- planning

  /// The steps of this run with the module choice of [OnboardingDraft
  /// .plannedModules].
  List<OnboardingStep> get plan => plannedOnboardingSteps(
    mode: state.mode,
    offersStep:
        state.isOn(AppModule.offers, planned: true) && !state.regionHidden,
    goalStep: state.isOn(AppModule.calories, planned: true),
  );

  ({int step, int total})? progressOf(OnboardingStep step) =>
      onboardingProgress(plan, step, mode: state.mode);

  OnboardingStep? nextAfter(OnboardingStep step) =>
      nextOnboardingStep(plan, step);

  /// Whether [step] comes after the account in this run (no way back).
  bool isAfterAccount(OnboardingStep step) {
    final steps = plan;
    final account = steps.indexOf(OnboardingStep.account);
    final index = steps.indexOf(step);
    return index > account && account >= 0;
  }

  // ------------------------------------------------------------ navigation

  /// A new run from Willkommen with default answers ("Neues Konto anlegen":
  /// values of a signed-out account are not taken over, §3.2).
  void startFresh(AccountStepMode mode) {
    _failed.clear();
    state = OnboardingDraft(mode: mode, step: OnboardingStep.welcome);
    _save();
  }

  void setMode(AccountStepMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    _save();
  }

  /// [step] is on screen now.
  void enterStep(OnboardingStep step) {
    if (state.step == step) return;
    state = state.copyWith(step: step);
    unawaited(_saveStep());
  }

  // --------------------------------------------------------------- answers

  void setModule(AppModule module, bool on) {
    state = state.copyWith(modules: {...state.moduleChoice, module: on});
    _save();
  }

  /// Leaving the module step with "Weiter"; [skip] takes the defaults.
  Future<void> commitModules({bool skip = false}) async {
    final choice = skip
        ? Map<AppModule, bool>.of(AppModulesState.onboardingDefaults)
        : state.moduleChoice;
    state = state.copyWith(modules: choice, plannedModules: choice);
    _save();
    // In the login variant the account exists already: apply right away.
    if (state.accountReady) _applyModules(choice);
  }

  void markRegionHidden() {
    if (state.regionHidden) return;
    state = state.copyWith(regionHidden: true);
  }

  void setDiet({Set<String>? diet, Set<String>? allergies}) {
    state = state.copyWith(diet: diet, allergies: allergies);
    _save();
  }

  /// "Weiter" in Ernährung: writes both columns (optimistic). [skip] keeps
  /// the account without restrictions and writes nothing.
  void finishDiet({bool skip = false}) {
    if (skip) {
      state = state.copyWith(diet: {}, allergies: {}, dietSkipped: true);
      _save();
      return;
    }
    state = state.copyWith(dietSkipped: false);
    _save();
    final merged = mergeDietAndAllergies(
      diet: state.diet,
      allergies: state.allergies,
    );
    _write(
      'diet',
      () => _backend.saveDiet(
        dietPreferences: merged.dietPreferences,
        allergies: merged.allergies,
      ),
    );
  }

  void setGoal(OnboardingGoalDraft goal) {
    state = state.copyWith(goal: goal);
    _save();
  }

  /// "Weiter" in Dein Ziel: saves the goal when the data is complete;
  /// without data no goal is saved (the calories tab asks later, §3.10).
  void finishGoal({bool skip = false}) {
    final goal = state.goal;
    if (!skip && goal.isComplete) {
      _write('goal', () => _backend.saveGoal(goal));
    } else {
      _write('calories', _backend.enableCalorieTracking);
    }
  }

  void setListName(String name) {
    if (state.listName == name) return;
    state = state.copyWith(listName: name);
    _save();
  }

  void declineJoin() => state = state.copyWith(joinDeclined: true);

  // --------------------------------------------------------------- account

  /// Right after a session exists: new or set up (§1.2). For a new account
  /// the answers from before are written into it (modules through
  /// `appModulesProvider`, Vertrag 1). Throws when the server cannot be
  /// reached; the caller offers "Erneut versuchen".
  Future<AccountSetupStatus> resolveAccount() async {
    final status = await _backend.accountStatus();
    if (status == AccountSetupStatus.setUp) {
      await discard();
      return status;
    }
    final wasReady = state.accountReady;
    state = state.copyWith(accountReady: true);
    _save();
    if (!wasReady && state.mode == AccountStepMode.signUp) {
      _applyModules(state.moduleChoice);
    }
    return status;
  }

  void _applyModules(Map<AppModule, bool> choice) {
    _write(
      'modules',
      () => ref.read(appModulesProvider.notifier).setAll(choice),
    );
  }

  /// The account was set up before: local answers are dropped (§5.3).
  Future<void> discard() async {
    _failed.clear();
    state = const OnboardingDraft();
    await _clearRun();
  }

  /// The end ("Liste anlegen", "Beitreten" or skipping the last step):
  /// `users.onboarding_completed = true` and the run is closed (§1.2).
  Future<void> complete() async {
    // Retry what failed once more before closing the run.
    await retrySync();
    _write('completed', _backend.markCompleted);
    _failed.clear();
    state = const OnboardingDraft();
    await _clearRun();
  }

  /// "Erneut versuchen" in a [OnboardingDraft.syncFailed] row.
  Future<void> retrySync() async {
    for (final entry in Map.of(_failed).entries) {
      await _attempt(entry.key, entry.value);
    }
  }

  void _write(String key, Future<void> Function() task) {
    unawaited(_attempt(key, task));
  }

  Future<void> _attempt(String key, Future<void> Function() task) async {
    try {
      await task();
      _failed.remove(key);
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Saving $key failed: $e');
      _failed[key] = task;
    }
    final failed = _failed.isNotEmpty;
    if (state.syncFailed != failed) {
      state = state.copyWith(syncFailed: failed);
    }
  }

  // ------------------------------------------------------------ persistence

  void _save() => unawaited(_saveAll());

  Future<void> _saveAll() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        kPendingModulesKey,
        jsonEncode(AppModulesState.encode(state.moduleChoice)),
      );
      await prefs.setString(kOnboardingDraftKey, jsonEncode(state.toJson()));
      await _saveStep();
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Saving the draft failed: $e');
    }
  }

  Future<void> _saveStep() async {
    final step = state.step;
    // Willkommen is no step to resume in; the answers stay (§5.5).
    await OnboardingPrefs.instance.setResumeStep(
      step == OnboardingStep.welcome ? null : step,
    );
  }

  Future<void> _clearRun() async {
    final prefs = _prefs;
    await OnboardingPrefs.instance.setDeviceOnboarded();
    await OnboardingPrefs.instance.setResumeStep(null);
    if (prefs == null) return;
    await prefs.remove(kPendingModulesKey);
    await prefs.remove(kOnboardingDraftKey);
  }

  /// Whether [step] needs an account before it in the new-user order.
  static bool needsAccount(OnboardingStep step) =>
      _postAccountSteps.contains(step);
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );
