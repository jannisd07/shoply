import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The optional parts of Avo (Konzept 00, Kap. 15). The core (lists, recipes,
/// purchase history, store per list) is always on and has no entry here.
///
/// Contract 3.1 in docs/redesign/arbeitsteilung.md: Teil A owns this file,
/// Teil B only reads [moduleEnabledProvider] and hides its features (renders
/// `SizedBox.shrink()`) when a module is off.
enum AppModule {
  /// Preise & Angebote: offers at items, "4 von 11 im Angebot", flyer hints.
  offers('offers', onboardingDefault: true),

  /// Wochenplan: segment in the Rezepte tab.
  mealPlan('meal_plan', onboardingDefault: true, released: false),

  /// Kalorien & Gesundheit: food diary, Apple Health.
  calories('calories', onboardingDefault: false),

  /// Avo, the AI assistant: the Avo tab with chat and voice. Background AI
  /// (categories, photo import) belongs to the core and stays on.
  avo('avo', onboardingDefault: true),

  /// Kosten teilen: amounts and splits after shopping together. Off for new
  /// users; suggested once when a list is shared for the first time.
  costSplit('cost_split', onboardingDefault: false);

  const AppModule(
    this.storageKey, {
    required this.onboardingDefault,
    this.released = true,
  });

  /// Stable id used in local storage and in `user_preferences.modules`.
  final String storageKey;

  /// Preselection in the onboarding module step (owner decision 07.11.2026).
  final bool onboardingDefault;

  /// Half-finished modules are hidden everywhere (onboarding, settings, Avo)
  /// and always count as off, except when unlocked in a debug build.
  final bool released;

  static AppModule? fromStorageKey(String key) {
    for (final m in values) {
      if (m.storageKey == key) return m;
    }
    return null;
  }
}

/// Snapshot of the user's module choices.
@immutable
class AppModulesState {
  const AppModulesState({
    required this.choices,
    this.debugUnlocked = const {},
  });

  /// What the user chose (or the defaults for accounts that never chose).
  final Map<AppModule, bool> choices;

  /// Unreleased modules unlocked from the developer menu (debug builds only).
  final Set<AppModule> debugUnlocked;

  bool isEnabled(AppModule module) {
    if (!module.released &&
        !(kDebugMode && debugUnlocked.contains(module))) {
      return false;
    }
    return choices[module] ?? false;
  }

  /// Modules that may be shown in onboarding and settings.
  static List<AppModule> get visibleModules =>
      [for (final m in AppModule.values) if (m.released) m];

  AppModulesState copyWith({
    Map<AppModule, bool>? choices,
    Set<AppModule>? debugUnlocked,
  }) =>
      AppModulesState(
        choices: choices ?? this.choices,
        debugUnlocked: debugUnlocked ?? this.debugUnlocked,
      );

  /// Defaults for an account that never made a choice. Such accounts used the
  /// app before modules existed, so everything they had stays on; calories
  /// follow the old opt-in flag.
  static Map<AppModule, bool> existingUserDefaults({bool? legacyCalories}) => {
        for (final m in AppModule.values)
          m: m == AppModule.calories ? (legacyCalories ?? false) : true,
      };

  /// Preselection for the onboarding module step.
  static Map<AppModule, bool> get onboardingDefaults =>
      {for (final m in AppModule.values) m: m.onboardingDefault};

  static Map<String, bool> encode(Map<AppModule, bool> choices) =>
      {for (final e in choices.entries) e.key.storageKey: e.value};

  /// Unknown keys are ignored; missing modules are filled from [fallback].
  static Map<AppModule, bool> decode(
    Map<String, dynamic> json,
    Map<AppModule, bool> fallback,
  ) {
    final out = Map<AppModule, bool>.of(fallback);
    json.forEach((key, value) {
      final m = AppModule.fromStorageKey(key);
      if (m != null && value is bool) out[m] = value;
    });
    return out;
  }
}

/// Where module choices are kept: on the device and in the account.
abstract class ModuleStore {
  Future<Map<String, dynamic>?> readLocal();
  Future<void> writeLocal(Map<String, bool> json);

  /// The legacy calorie opt-in (`calorie_tracking_enabled`), if ever set.
  Future<bool?> readLegacyCalories();

  /// Null when signed out, when the account has no choice yet or on error.
  Future<Map<String, dynamic>?> readRemote();
  Future<void> writeRemote(Map<String, bool> json);
}

/// SharedPreferences on the device, `user_preferences.modules` (jsonb) in the
/// account (migration `database/migrations/20261107230000_a_user_modules.sql`).
class DefaultModuleStore implements ModuleStore {
  const DefaultModuleStore();

  static const _localKey = 'app_modules_v1';
  static const _legacyCaloriesKey = 'calorie_tracking_enabled';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Map<String, dynamic>?> readLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeLocal(Map<String, bool> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(json));
  }

  @override
  Future<bool?> readLegacyCalories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legacyCaloriesKey);
  }

  @override
  Future<Map<String, dynamic>?> readRemote() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('user_preferences')
          .select('modules')
          .eq('user_id', userId)
          .maybeSingle();
      final modules = row?['modules'];
      if (modules is Map && modules.isNotEmpty) {
        return modules.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint('⚠️ [Modules] Reading account modules failed: $e');
    }
    return null;
  }

  @override
  Future<void> writeRemote(Map<String, bool> json) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('user_preferences').upsert(
        {'user_id': userId, 'modules': json},
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('⚠️ [Modules] Saving account modules failed: $e');
    }
  }
}

/// Override in tests.
final moduleStoreProvider =
    Provider<ModuleStore>((ref) => const DefaultModuleStore());

/// All module choices. Rebuilt per signed-in account, so a login pulls that
/// account's choices.
final appModulesProvider =
    StateNotifierProvider<AppModulesNotifier, AppModulesState>((ref) {
  ref.watch(authUserIdProvider);
  return AppModulesNotifier(ref.watch(moduleStoreProvider));
});

/// Whether [AppModule] is on. Takes effect at once, without a restart.
final moduleEnabledProvider = Provider.family<bool, AppModule>(
  (ref, module) =>
      ref.watch(appModulesProvider.select((s) => s.isEnabled(module))),
);

class AppModulesNotifier extends StateNotifier<AppModulesState> {
  AppModulesNotifier(this._store)
      : super(AppModulesState(
          choices: AppModulesState.existingUserDefaults(),
        )) {
    _ready = _load();
  }

  final ModuleStore _store;
  late final Future<void> _ready;
  bool _changedLocally = false;

  /// Completes when local and account choices have been read.
  Future<void> get ready => _ready;

  Future<void> _load() async {
    final legacy = await _store.readLegacyCalories();
    final fallback =
        AppModulesState.existingUserDefaults(legacyCalories: legacy);
    final local = await _store.readLocal();
    if (!mounted) return;
    if (!_changedLocally) {
      state = state.copyWith(
        choices: local == null
            ? fallback
            : AppModulesState.decode(local, fallback),
      );
    }

    final remote = await _store.readRemote();
    if (!mounted || remote == null || _changedLocally) return;
    final merged = AppModulesState.decode(remote, state.choices);
    state = state.copyWith(choices: merged);
    await _store.writeLocal(AppModulesState.encode(merged));
  }

  /// Switches one module on or off (settings, Avo, a tab's empty state).
  Future<void> setEnabled(AppModule module, bool enabled) =>
      setAll({...state.choices, module: enabled});

  /// Saves the whole choice at once (onboarding module step).
  Future<void> setAll(Map<AppModule, bool> choices) async {
    _changedLocally = true;
    final next = {...state.choices, ...choices};
    state = state.copyWith(choices: next);
    final json = AppModulesState.encode(next);
    await _store.writeLocal(json);
    await _store.writeRemote(json);
  }

  /// Developer menu (debug builds): shows an unreleased module.
  void setDebugUnlocked(AppModule module, bool unlocked) {
    if (!kDebugMode) return;
    final set = {...state.debugUnlocked};
    unlocked ? set.add(module) : set.remove(module);
    state = state.copyWith(debugUnlocked: set);
  }
}
