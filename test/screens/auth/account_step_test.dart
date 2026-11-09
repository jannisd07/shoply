import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/steps/account_step.dart';
import 'package:shoply/presentation/screens/auth/steps/email_step.dart';
import 'package:shoply/presentation/screens/auth/widgets/sign_in_buttons.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import 'auth_fakes.dart';

void main() {
  late FakeAuthGateway gateway;
  var signedIn = 0;
  var email = 0;
  var password = 0;

  Widget step({
    AccountStepMode mode = AccountStepMode.signUp,
    Widget? status,
  }) => AccountStep(
    mode: mode,
    onEmail: () => email++,
    onSignedIn: () => signedIn++,
    onPassword: () => password++,
    onBack: () {},
    status: status,
    onTerms: () {},
    onPrivacy: () {},
  );

  setUp(() {
    gateway = FakeAuthGateway();
    signedIn = 0;
    email = 0;
    password = 0;
  });

  testWidgets('sign-up: title, three buttons, no password link', (
    tester,
  ) async {
    await pumpAuth(tester, step(), gateway);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Sign in with password'), findsNothing);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Privacy notice'), findsOneWidget);
  });

  testWidgets('login mode adds "Sign in with password"', (tester) async {
    await pumpAuth(tester, step(mode: AccountStepMode.login), gateway);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Use the same method as the first time.'), findsOneWidget);
    await tester.tap(find.text('Sign in with password'));
    expect(password, 1);
  });

  testWidgets('no Apple button where Apple is not available', (tester) async {
    gateway.appleAvailable = false;
    await pumpAuth(tester, step(), gateway);
    expect(find.byType(AppleSignInButton), findsNothing);
    expect(find.byType(GoogleSignInButton), findsOneWidget);
  });

  testWidgets('working: one flow at a time, button stays until the flow', (
    tester,
  ) async {
    gateway.hold = Completer<void>();
    await pumpAuth(tester, step(), gateway);
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    // A second tap anywhere starts nothing (Inventar Bug 7).
    await tester.tap(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with email'));
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(gateway.calls, ['apple']);
    expect(email, 0);

    gateway.hold!.complete();
    await tester.pump();
    expect(signedIn, 1);
    // Still working until the flow shows the next screen.
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('a status from the flow ends the working state', (tester) async {
    await pumpAuth(tester, step(), gateway);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(signedIn, 1);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    await tester.pumpWidget(
      authApp(step(status: const Text('Not saved yet')), gateway),
    );
    await tester.pump();
    expect(find.text('Not saved yet'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);

    // With a session a tap only asks the flow again, no second sign-in.
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(gateway.calls, ['google']);
    expect(signedIn, 2);
  });

  testWidgets('closing the Apple sheet says nothing', (tester) async {
    gateway.socialResult = false;
    await pumpAuth(tester, step(), gateway);
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(signedIn, 0);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.textContaining('didn’t work'), findsNothing);
  });

  testWidgets('Apple not available (simulator) points to the others', (
    tester,
  ) async {
    gateway.nextError = Exception(
      'Apple Sign-In ist auf diesem Gerät nicht verfügbar.',
    );
    await pumpAuth(tester, step(), gateway);
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(
      find.text(
        'Signing in with Apple isn’t working right now. Use Google or email.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed sign-in offers a retry of the same provider', (
    tester,
  ) async {
    gateway.nextError = AuthApiException('x', code: 'unexpected_failure');
    await pumpAuth(tester, step(), gateway);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(find.text('Signing in with Google didn’t work.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(gateway.calls, ['google', 'google']);
    expect(signedIn, 1);
  });

  testWidgets('offline: line stays, taps start nothing', (tester) async {
    await pumpAuth(tester, step(), gateway);
    setOffline(tester, true);
    await tester.pump();
    const text =
        'Offline. You need a connection to sign in. Your choices stay saved.';
    expect(find.text(text), findsOneWidget);

    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(gateway.calls, isEmpty);
    expect(find.text(text), findsOneWidget);

    // E-mail still opens: the address step works offline until "Code senden".
    await tester.tap(find.text('Continue with email'));
    expect(email, 1);
  });

  testWidgets('email step starts with the address typed last', (tester) async {
    await pumpAuth(tester, EmailStep(onCodeSent: (_) {}), gateway);
    await tester.enterText(find.byType(CupertinoTextField), 'lena@posteo.de');
    await tester.pumpWidget(authApp(const SizedBox(), gateway));
    // Same container: the draft survives.
    await tester.pumpWidget(authApp(EmailStep(onCodeSent: (_) {}), gateway));
    await tester.pump();
    expect(find.text('lena@posteo.de'), findsOneWidget);
  });
}
