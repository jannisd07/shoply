import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Records what the flow writes into the account.
class FakeOnboardingBackend implements OnboardingAccountBackend {
  AccountSetupStatus status = AccountSetupStatus.isNew;
  bool failStatus = false;
  bool failWrites = false;
  String? lastList = 'list-9';

  final List<({List<String> diet, List<String> allergies})> diets = [];
  final List<OnboardingGoalDraft> goals = [];
  int calorieSwitches = 0;
  int completed = 0;

  void _maybeFail() {
    if (failWrites) throw StateError('offline');
  }

  @override
  Future<AccountSetupStatus> accountStatus() async {
    if (failStatus) throw StateError('offline');
    return status;
  }

  @override
  Future<void> saveDiet({
    required List<String> dietPreferences,
    required List<String> allergies,
  }) async {
    _maybeFail();
    diets.add((diet: dietPreferences, allergies: allergies));
  }

  @override
  Future<void> saveGoal(OnboardingGoalDraft draft) async {
    _maybeFail();
    goals.add(draft);
  }

  @override
  Future<void> enableCalorieTracking() async {
    _maybeFail();
    calorieSwitches++;
  }

  @override
  Future<void> markCompleted() async {
    _maybeFail();
    completed++;
  }

  @override
  Future<String?> lastListId() async => lastList;
}

/// Module choices without Supabase.
class FakeModuleStore implements ModuleStore {
  Map<String, bool>? local;
  Map<String, bool>? remote;

  @override
  Future<Map<String, dynamic>?> readLocal() async => local;

  @override
  Future<void> writeLocal(Map<String, bool> json) async => local = json;

  @override
  Future<bool?> readLegacyCalories() async => null;

  @override
  Future<Map<String, dynamic>?> readRemote() async => null;

  @override
  Future<void> writeRemote(Map<String, bool> json) async => remote = json;
}

/// Fresh mock SharedPreferences attached to [OnboardingPrefs].
Future<SharedPreferences> attachPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  OnboardingPrefs.instance.attach(prefs);
  return prefs;
}

/// The overrides every onboarding test needs.
List<Override> onboardingOverrides({
  required FakeOnboardingBackend backend,
  required FakeModuleStore store,
}) => [
  onboardingBackendProvider.overrideWithValue(backend),
  moduleStoreProvider.overrideWithValue(store),
  authUserIdProvider.overrideWith((ref) => 'user-1'),
];

/// Lets fire-and-forget writes finish.
Future<void> settleWrites() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

extension OnboardingContainer on ProviderContainer {
  OnboardingController get onboarding =>
      read(onboardingControllerProvider.notifier);
  OnboardingDraft get draft => read(onboardingControllerProvider);
}

/// A controller that starts from [preset] (layout tests).
class PresetOnboardingController extends OnboardingController {
  PresetOnboardingController(this.preset);

  final OnboardingDraft preset;

  @override
  OnboardingDraft build() => preset;
}
