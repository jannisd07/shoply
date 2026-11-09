// Fakes and harness for the account screens (A7 "Konto"): no Supabase, no
// platform channels. The gateway records every call and can hold or fail it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';

import '../../layout/layout_matrix.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({
    this.appleAvailable = true,
    this.hasSession = false,
    this.suggestedFirstName,
  });

  @override
  bool appleAvailable;

  @override
  bool hasSession;

  @override
  String? suggestedFirstName;

  /// Every call as "method:argument".
  final List<String> calls = [];

  /// Thrown by the next call, then cleared.
  Object? nextError;

  /// While set, calls wait for it.
  Completer<void>? hold;

  /// Result of the Apple and Google sign-ins (false: sheet closed).
  bool socialResult = true;

  bool? resetPending;

  Future<void> _run(String call) async {
    calls.add(call);
    final waitFor = hold;
    if (waitFor != null) await waitFor.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  Future<bool> signInWithApple() async {
    await _run('apple');
    if (socialResult) hasSession = true;
    return socialResult;
  }

  @override
  Future<bool> signInWithGoogle() async {
    await _run('google');
    if (socialResult) hasSession = true;
    return socialResult;
  }

  @override
  Future<void> sendSignInCode(String email) => _run('sendSignInCode:$email');

  @override
  Future<void> verifySignInCode(String email, String code) async {
    await _run('verifySignInCode:$email:$code');
    hasSession = true;
  }

  @override
  Future<void> sendPasswordResetCode(String email) =>
      _run('sendPasswordResetCode:$email');

  @override
  Future<void> verifyPasswordResetCode(String email, String code) async {
    await _run('verifyPasswordResetCode:$email:$code');
    hasSession = true;
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    await _run('signInWithPassword:$email:$password');
    hasSession = true;
  }

  @override
  Future<void> updatePassword(String password) =>
      _run('updatePassword:$password');

  @override
  Future<void> saveDisplayName(String name) => _run('saveDisplayName:$name');

  @override
  Future<void> signOut() async {
    await _run('signOut');
    hasSession = false;
  }

  @override
  Future<void> setPasswordResetPending(bool pending) async {
    calls.add('resetPending:$pending');
    resetPending = pending;
  }
}

/// Test switch for [isOfflineProvider].
final testOfflineProvider = StateProvider<bool>((ref) => false);

/// A settable clock for [authClockProvider].
class TestClock {
  DateTime now = DateTime(2026, 11, 8, 10);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

List<Override> authOverrides(FakeAuthGateway gateway, {TestClock? clock}) => [
  authGatewayProvider.overrideWithValue(gateway),
  isOfflineProvider.overrideWith((ref) => ref.watch(testOfflineProvider)),
  if (clock != null) authClockProvider.overrideWithValue(clock.call),
];

/// The screen inside the app-like harness at 390 pt, default text, English.
Widget authApp(
  Widget child,
  FakeAuthGateway gateway, {
  TestClock? clock,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) => ProviderScope(
  overrides: authOverrides(gateway, clock: clock),
  child: layoutHarness(layout, SizedBox.expand(child: child)),
);

/// Pumps [authApp] at the size of [layout].
Future<void> pumpAuth(
  WidgetTester tester,
  Widget child,
  FakeAuthGateway gateway, {
  TestClock? clock,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(authApp(child, gateway, clock: clock, layout: layout));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Sets the test offline switch from inside the tree.
void setOffline(WidgetTester tester, bool offline) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SizedBox).first),
  );
  container.read(testOfflineProvider.notifier).state = offline;
}

/// The [ProviderContainer] of the pumped harness.
ProviderContainer authContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SizedBox).first));
