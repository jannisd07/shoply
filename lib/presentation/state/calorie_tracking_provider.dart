import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether calorie tracking is on: an alias for
/// `moduleEnabledProvider(AppModule.calories)` (contract 3.1, request A-3).
///
/// Kept as a `StateNotifierProvider` so callers that use `.notifier.setEnabled`
/// keep compiling until Teil A switches them to [appModulesProvider]. The
/// notifier is rebuilt whenever the module flag changes, so its state is
/// always the module's state. Reading it starts the server sync
/// ([calorieLegacySyncProvider]).
final calorieTrackingEnabledProvider =
    StateNotifierProvider<CalorieTrackingNotifier, bool>((ref) {
  final sync = ref.watch(_calorieSyncProvider);
  return CalorieTrackingNotifier(
    ref.watch(appModulesProvider.notifier),
    ref.watch(moduleEnabledProvider(AppModule.calories)),
    serverSaved: () => sync.saved,
  );
});

class CalorieTrackingNotifier extends StateNotifier<bool> {
  CalorieTrackingNotifier(
    this._modules,
    bool enabled, {
    Future<void> Function()? serverSaved,
  })  : _serverSaved = serverSaved,
        super(enabled);

  final AppModulesNotifier _modules;
  final Future<void> Function()? _serverSaved;

  /// Switches the calories module (and saves the choice). Returns once the
  /// old server switch has the new value too, because the calorie dinner
  /// ideas read it right after (Avo's settings tool).
  Future<void> setEnabled(bool enabled) async {
    if (!_modules.mounted) return; // Signed-in account changed meanwhile.
    await _modules.setEnabled(AppModule.calories, enabled);
    await _serverSaved?.call();
  }
}

/// The old server switch `nutrition_goals.calorie_tracking_enabled`. It
/// still gates the calorie dinner ideas (home card, evening reminder), so
/// it follows the calories module. Override in tests.
class LegacyCalorieSwitch {
  const LegacyCalorieSwitch();

  /// Null when signed out, when there is no goal row or on error.
  Future<bool?> read() async {
    if (Supabase.instance.client.auth.currentUser == null) return null;
    final goal = await NutritionGoalService.instance.getGoal();
    return goal?.calorieTrackingEnabled;
  }

  /// False when signed out or when saving failed.
  Future<bool> write(bool enabled) async {
    if (Supabase.instance.client.auth.currentUser == null) return false;
    try {
      await NutritionGoalService.instance.setTrackingEnabled(enabled);
      return true;
    } catch (e) {
      debugPrint('⚠️ [CalorieTracking] Saving the server switch failed: $e');
      return false;
    }
  }
}

final legacyCalorieSwitchProvider =
    Provider<LegacyCalorieSwitch>((ref) => const LegacyCalorieSwitch());

/// Completes when the sync between the old server switch and the calories
/// module has run for the signed-in account (see [_CalorieServerSync]).
final calorieLegacySyncProvider = FutureProvider<void>(
  (ref) => ref.watch(_calorieSyncProvider).migrated,
);

/// One sync per account: rebuilt with [appModulesProvider].
final _calorieSyncProvider = Provider<_CalorieServerSync>((ref) {
  final sync = _CalorieServerSync(
    ref.watch(appModulesProvider.notifier),
    ref.watch(moduleStoreProvider),
    ref.watch(legacyCalorieSwitchProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// Bridges the old server switch and the calories module.
///
/// - Migration: when neither the device nor the account has a module
///   choice (a user from before modules existed), the server switch is
///   taken over once. Taking it over saves the choice, so the next launch
///   finds one.
/// - A saved choice wins, also one made only on this device (onboarding
///   runs before login) or while offline: the server switch is brought in
///   line with it on every launch.
/// - Mirror: every later switch of the calories module (settings,
///   onboarding, Avo) is written to the server switch, one write at a time.
class _CalorieServerSync {
  _CalorieServerSync(this._modules, this._store, this._server) {
    // The notifier's own listener runs synchronously on every change; a
    // `ref.listen` would only hear about it on Riverpod's next refresh.
    _removeListener = _modules.addListener(_onModules);
    migrated = _migrate();
  }

  final AppModulesNotifier _modules;
  final ModuleStore _store;
  final LegacyCalorieSwitch _server;
  late final void Function() _removeListener;

  /// Completes when the migration (or the launch check) has run.
  late final Future<void> migrated;

  var _calories = false;

  /// Module choices are read; every calories switch from now on is the
  /// user's.
  var _loaded = false;

  /// The user switched calories after loading.
  var _switched = false;
  var _disposed = false;

  /// What the server switch holds, once known. Null: no goal row (or the
  /// read failed).
  var _serverKnown = false;
  bool? _onServer;
  Future<void> _writes = Future<void>.value();

  bool get _gone => _disposed || !_modules.mounted;

  /// Completes when every server write queued so far is done.
  Future<void> get saved => _writes;

  void dispose() {
    _disposed = true;
    _removeListener();
  }

  void _onModules(AppModulesState state) {
    final on = state.isEnabled(AppModule.calories);
    if (on == _calories) return;
    _calories = on;
    if (!_loaded) return;
    _switched = true;
    _queueWrite();
  }

  /// Writes run one after another, each with the value current when it
  /// starts, so a quick on-off can't land out of order.
  void _queueWrite() {
    _writes = _writes.then((_) => _write());
  }

  Future<void> _write() async {
    if (_gone) return;
    final on = _calories;
    if (_serverKnown && on == _onServer) return;
    try {
      if (!await _server.write(on)) return;
      _serverKnown = true;
      _onServer = on;
    } catch (e) {
      debugPrint('⚠️ [CalorieTracking] Saving the server switch failed: $e');
    }
  }

  Future<void> _migrate() async {
    try {
      await _modules.ready;
      if (_gone) return;
      _loaded = true;
      // A's loader saves choices on the device only when the account has
      // some, so a choice on the device means the user or the account made
      // one (also while loading).
      final hasChoice = await _store.readLocal() != null;
      if (_gone) return;

      final serverValue = await _server.read();
      // A switch while the server answered is newer and already on its way.
      if (_gone || _switched) return;
      _serverKnown = true;
      _onServer = serverValue;
      if (serverValue == null || serverValue == _calories) return;

      if (hasChoice) {
        debugPrint('🔵 [CalorieTracking] Updating the server switch');
        _queueWrite();
        await _writes;
        return;
      }
      debugPrint('🔵 [CalorieTracking] Taking the server switch: $serverValue');
      await _modules.setEnabled(AppModule.calories, serverValue);
    } catch (e) {
      debugPrint('⚠️ [CalorieTracking] Syncing the server switch failed: $e');
    }
  }
}
