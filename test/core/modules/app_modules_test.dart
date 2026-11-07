import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class _FakeStore implements ModuleStore {
  _FakeStore({this.local, this.remote, this.legacy, this.remoteGate});

  Map<String, dynamic>? local;
  Map<String, dynamic>? remote;
  bool? legacy;
  Completer<void>? remoteGate;
  final writesLocal = <Map<String, bool>>[];
  final writesRemote = <Map<String, bool>>[];

  @override
  Future<Map<String, dynamic>?> readLocal() async => local;
  @override
  Future<void> writeLocal(Map<String, bool> json) async {
    writesLocal.add(json);
    local = json;
  }

  @override
  Future<bool?> readLegacyCalories() async => legacy;
  @override
  Future<Map<String, dynamic>?> readRemote() async {
    await remoteGate?.future;
    return remote;
  }

  @override
  Future<void> writeRemote(Map<String, bool> json) async =>
      writesRemote.add(json);
}

ProviderContainer _container(_FakeStore store) => ProviderContainer(
      overrides: [
        moduleStoreProvider.overrideWithValue(store),
        authUserIdProvider.overrideWith((ref) => null),
      ],
    );

Future<AppModulesState> _loaded(ProviderContainer c) async {
  await c.read(appModulesProvider.notifier).ready;
  return c.read(appModulesProvider);
}

void main() {
  test('onboarding preselection is the owner decision of 07.11.2026', () {
    expect(AppModulesState.onboardingDefaults, {
      AppModule.offers: true,
      AppModule.mealPlan: true,
      AppModule.calories: false,
      AppModule.avo: true,
      AppModule.costSplit: false,
    });
  });

  test('an account without choices keeps everything, calories follow the '
      'old opt-in', () async {
    final off = await _loaded(_container(_FakeStore()));
    expect(off.isEnabled(AppModule.offers), isTrue);
    expect(off.isEnabled(AppModule.avo), isTrue);
    expect(off.isEnabled(AppModule.costSplit), isTrue);
    expect(off.isEnabled(AppModule.calories), isFalse);

    final on = await _loaded(_container(_FakeStore(legacy: true)));
    expect(on.isEnabled(AppModule.calories), isTrue);
  });

  test('an unreleased module is off even when chosen', () async {
    final s = await _loaded(
        _container(_FakeStore(local: {'meal_plan': true})));
    expect(s.choices[AppModule.mealPlan], isTrue);
    expect(s.isEnabled(AppModule.mealPlan), isFalse);
    expect(AppModulesState.visibleModules, isNot(contains(AppModule.mealPlan)));
  });

  test('local choices load, unknown keys and non-bools are ignored',
      () async {
    final s = await _loaded(_container(_FakeStore(local: {
      'offers': false,
      'avo': false,
      'teleport': true,
      'calories': 'yes',
    })));
    expect(s.isEnabled(AppModule.offers), isFalse);
    expect(s.isEnabled(AppModule.avo), isFalse);
    expect(s.isEnabled(AppModule.calories), isFalse);
    expect(s.isEnabled(AppModule.costSplit), isTrue);
  });

  test('account choices win over the device and are mirrored locally',
      () async {
    final store = _FakeStore(
      local: {'offers': true},
      remote: {'offers': false, 'calories': true},
    );
    final s = await _loaded(_container(store));
    expect(s.isEnabled(AppModule.offers), isFalse);
    expect(s.isEnabled(AppModule.calories), isTrue);
    expect(store.local?['offers'], isFalse);
  });

  test('setEnabled takes effect at once and saves on device and account',
      () async {
    final store = _FakeStore();
    final c = _container(store);
    await c.read(appModulesProvider.notifier).ready;
    final seen = <bool>[];
    c.listen<bool>(moduleEnabledProvider(AppModule.offers),
        (_, next) => seen.add(next),
        fireImmediately: true);

    await c
        .read(appModulesProvider.notifier)
        .setEnabled(AppModule.offers, false);
    // Dependents are rebuilt by Riverpod's scheduler, not synchronously.
    await Future<void>.delayed(Duration.zero);

    expect(c.read(moduleEnabledProvider(AppModule.offers)), isFalse);
    expect(seen, [true, false]);
    expect(store.writesLocal.last['offers'], isFalse);
    expect(store.writesRemote.last['offers'], isFalse);
  });

  test('a change made while the account is still loading is not '
      'overwritten', () async {
    final gate = Completer<void>();
    final store = _FakeStore(remote: {'avo': true}, remoteGate: gate);
    final c = _container(store);
    final notifier = c.read(appModulesProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await notifier.setEnabled(AppModule.avo, false);
    gate.complete();
    await notifier.ready;
    expect(c.read(moduleEnabledProvider(AppModule.avo)), isFalse);
  });

  test('setAll from onboarding stores every module', () async {
    final store = _FakeStore();
    final c = _container(store);
    await c.read(appModulesProvider.notifier).ready;
    await c
        .read(appModulesProvider.notifier)
        .setAll(AppModulesState.onboardingDefaults);
    expect(store.writesRemote.last, {
      'offers': true,
      'meal_plan': true,
      'calories': false,
      'avo': true,
      'cost_split': false,
    });
  });
}
