import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';

class _FakeStore implements ModuleStore {
  _FakeStore({
    this.local,
    this.remote,
    this.legacy,
    this.remoteGate,
    this.accountLive = true,
  });

  Map<String, dynamic>? local;
  Map<String, dynamic>? remote;
  bool? legacy;

  /// When set, [readRemote] answers only after it completes, with the value
  /// from the moment it was asked.
  final Completer<void>? remoteGate;
  final remoteRequested = Completer<void>();

  /// False: A's migration `20261107230000_a_user_modules.sql` is not applied,
  /// so the account keeps no module choice.
  final bool accountLive;

  @override
  Future<Map<String, dynamic>?> readLocal() async => local;
  @override
  Future<void> writeLocal(Map<String, bool> json) async => local = json;
  @override
  Future<bool?> readLegacyCalories() async => legacy;
  @override
  Future<Map<String, dynamic>?> readRemote() async {
    final answer = remote;
    if (!remoteRequested.isCompleted) remoteRequested.complete();
    await remoteGate?.future;
    return answer;
  }

  @override
  Future<void> writeRemote(Map<String, bool> json) async {
    if (accountLive) remote = json;
  }
}

/// Stands in for `nutrition_goals.calorie_tracking_enabled`.
class _FakeServerSwitch implements LegacyCalorieSwitch {
  _FakeServerSwitch([this.value]);

  /// Null: the account has no goal row.
  bool? value;

  /// Writes that reached the server, in order.
  final writes = <bool>[];
  var failWrites = false;

  /// When set, [read] answers only after it completes, with the value from
  /// the moment it was asked (a response already on its way).
  Completer<void>? readGate;
  final readStarted = Completer<void>();

  /// Each write waits for the next gate in this list, if there is one.
  final writeGates = <Completer<void>>[];

  @override
  Future<bool?> read() async {
    final answer = value;
    if (!readStarted.isCompleted) readStarted.complete();
    await readGate?.future;
    return answer;
  }

  @override
  Future<bool> write(bool enabled) async {
    if (writeGates.isNotEmpty) await writeGates.removeAt(0).future;
    if (failWrites) return false;
    writes.add(enabled);
    value = enabled;
    return true;
  }
}

ProviderContainer _container(
  _FakeStore store,
  _FakeServerSwitch server, {
  StateProvider<String?>? user,
}) {
  final c = ProviderContainer(
    overrides: [
      moduleStoreProvider.overrideWithValue(store),
      legacyCalorieSwitchProvider.overrideWithValue(server),
      authUserIdProvider
          .overrideWith((ref) => user == null ? null : ref.watch(user)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Reads the alias (which starts the legacy sync) and waits until module
/// choices are loaded and the one-time server migration has run.
Future<bool> _settled(ProviderContainer c) async {
  c.read(calorieTrackingEnabledProvider);
  await c.read(calorieLegacySyncProvider.future);
  return c.read(calorieTrackingEnabledProvider);
}

/// Lets every pending microtask run.
Future<void> _drain() => Future<void>.delayed(Duration.zero);

void main() {
  test('the alias reflects AppModule.calories on and off', () async {
    final c = _container(
      _FakeStore(local: {'calories': true}),
      _FakeServerSwitch(),
    );
    expect(await _settled(c), isTrue);

    await c
        .read(appModulesProvider.notifier)
        .setEnabled(AppModule.calories, false);
    expect(c.read(calorieTrackingEnabledProvider), isFalse);

    await c
        .read(appModulesProvider.notifier)
        .setEnabled(AppModule.calories, true);
    expect(c.read(calorieTrackingEnabledProvider), isTrue);
  });

  test('setEnabled switches the calories module and saves the choice',
      () async {
    final store = _FakeStore(local: {'calories': false});
    final c = _container(store, _FakeServerSwitch());
    expect(await _settled(c), isFalse);

    await c.read(calorieTrackingEnabledProvider.notifier).setEnabled(true);

    expect(c.read(moduleEnabledProvider(AppModule.calories)), isTrue);
    expect(c.read(appModulesProvider).choices[AppModule.calories], isTrue);
    expect(store.local?['calories'], isTrue);
    expect(c.read(calorieTrackingEnabledProvider), isTrue);
  });

  test('without a saved choice the old server switch is applied once',
      () async {
    final store = _FakeStore();
    final server = _FakeServerSwitch(true);
    final first = _container(store, server);

    expect(await _settled(first), isTrue);
    expect(store.local?['calories'], isTrue);
    expect(store.remote?['calories'], isTrue);
    expect(server.writes, isEmpty);

    // Next launch: the old switch changed elsewhere, but the choice saved
    // by the migration stands and the switch is brought back in line.
    server.value = false;
    final next = _container(store, server);
    expect(await _settled(next), isTrue);
    expect(server.writes, [true]);
  });

  test('a choice saved in the account wins over the old server switch',
      () async {
    final store = _FakeStore(remote: {'calories': false});
    final server = _FakeServerSwitch(true);
    final c = _container(store, server);

    expect(await _settled(c), isFalse);
    expect(store.local?['calories'], isFalse);
    expect(server.writes, [false]);
  });

  test('a choice kept only on the device (onboarding before login) wins '
      'over the old server switch', () async {
    final store = _FakeStore(local: {'calories': false}, accountLive: false);
    final server = _FakeServerSwitch(true);
    final c = _container(store, server);

    expect(await _settled(c), isFalse);
    expect(store.local?['calories'], isFalse);
    expect(server.value, isFalse);
  });

  test('switching while the server answers keeps the new choice', () async {
    final server = _FakeServerSwitch(false)..readGate = Completer<void>();
    final c = _container(_FakeStore(), server);
    c.read(calorieTrackingEnabledProvider);
    await server.readStarted.future;

    await c.read(calorieTrackingEnabledProvider.notifier).setEnabled(true);
    server.readGate!.complete();
    await c.read(calorieLegacySyncProvider.future);

    expect(c.read(calorieTrackingEnabledProvider), isTrue);
    expect(server.writes, [true]);
  });

  test('switching before the choices are loaded keeps the new choice',
      () async {
    final store = _FakeStore(
      legacy: true,
      remoteGate: Completer<void>(),
      accountLive: false,
    );
    final server = _FakeServerSwitch(true);
    final c = _container(store, server);
    c.read(calorieTrackingEnabledProvider);
    await store.remoteRequested.future;

    await c.read(calorieTrackingEnabledProvider.notifier).setEnabled(false);
    store.remoteGate!.complete();
    await c.read(calorieLegacySyncProvider.future);

    expect(c.read(calorieTrackingEnabledProvider), isFalse);
    expect(store.local?['calories'], isFalse);
    expect(server.writes, [false]);
  });

  test('a server switch that matches the current state saves nothing',
      () async {
    final store = _FakeStore(legacy: true);
    final server = _FakeServerSwitch(true);
    final c = _container(store, server);

    expect(await _settled(c), isTrue);
    expect(store.local, isNull);
    expect(server.writes, isEmpty);
  });

  test('changes after loading are mirrored to the old server switch',
      () async {
    final server = _FakeServerSwitch(true);
    final c = _container(_FakeStore(legacy: true), server);
    expect(await _settled(c), isTrue);

    await c
        .read(appModulesProvider.notifier)
        .setEnabled(AppModule.calories, false);
    await c.read(calorieTrackingEnabledProvider.notifier).setEnabled(true);

    expect(server.writes, [false, true]);
  });

  test('loading choices and the migration write nothing to the server',
      () async {
    final server = _FakeServerSwitch(false);
    final c = _container(_FakeStore(legacy: true), server);

    expect(await _settled(c), isFalse);
    expect(server.writes, isEmpty);
  });

  test('switching another module writes nothing to the server', () async {
    final server = _FakeServerSwitch();
    final c = _container(_FakeStore(remote: {'calories': false}), server);
    expect(await _settled(c), isFalse);

    await c
        .read(appModulesProvider.notifier)
        .setEnabled(AppModule.offers, false);

    expect(server.writes, isEmpty);
    expect(server.value, isNull);
  });

  test('setEnabled returns once the server switch is saved', () async {
    final server = _FakeServerSwitch(true);
    final c = _container(_FakeStore(legacy: true), server);
    expect(await _settled(c), isTrue);

    final gate = Completer<void>();
    server.writeGates.add(gate);
    var done = false;
    final call = c
        .read(calorieTrackingEnabledProvider.notifier)
        .setEnabled(false)
        .then((_) => done = true);
    await _drain();
    expect(done, isFalse);
    expect(server.value, isTrue);

    gate.complete();
    await call;
    expect(server.value, isFalse);
  });

  test('quick switches reach the server in order', () async {
    final server = _FakeServerSwitch(true);
    final c = _container(_FakeStore(legacy: true), server);
    expect(await _settled(c), isTrue);

    final slow = Completer<void>();
    final fast = Completer<void>();
    server.writeGates.addAll([slow, fast]);
    final notifier = c.read(calorieTrackingEnabledProvider.notifier);
    final off = notifier.setEnabled(false);
    await _drain(); // The "off" write is on its way and slow.
    final on = notifier.setEnabled(true);
    fast.complete();
    await _drain();
    slow.complete();
    await Future.wait([off, on]);

    expect(server.writes, [false, true]);
    expect(server.value, isTrue);
    expect(c.read(calorieTrackingEnabledProvider), isTrue);
  });

  test('an opt-out the server missed is sent again on the next launch',
      () async {
    final store = _FakeStore(local: {'calories': true}, accountLive: false);
    final server = _FakeServerSwitch(true);
    final first = _container(store, server);
    expect(await _settled(first), isTrue);

    server.failWrites = true; // Offline.
    await first.read(calorieTrackingEnabledProvider.notifier).setEnabled(false);
    expect(server.value, isTrue);

    server.failWrites = false;
    final next = _container(store, server);
    expect(await _settled(next), isFalse);
    expect(server.value, isFalse);
    expect(server.writes, [false]);
  });

  test('an account switch while the server answers leaves the new account '
      'alone', () async {
    final user = StateProvider<String?>((ref) => 'a');
    final store = _FakeStore();
    final server = _FakeServerSwitch(true)..readGate = Completer<void>();
    final c = _container(store, server, user: user);
    c.read(calorieTrackingEnabledProvider);
    await server.readStarted.future;
    final before = c.read(calorieTrackingEnabledProvider.notifier);

    // Account b has no goal row; a's answer (on) is still on its way.
    server.value = null;
    c.read(user.notifier).state = 'b';
    c.read(calorieTrackingEnabledProvider);
    server.readGate!.complete();
    await c.read(calorieLegacySyncProvider.future);
    await before.setEnabled(true);
    await _drain();

    expect(c.read(calorieTrackingEnabledProvider), isFalse);
    expect(c.read(moduleEnabledProvider(AppModule.calories)), isFalse);
    expect(store.local, isNull);
    expect(server.writes, isEmpty);
  });
}
