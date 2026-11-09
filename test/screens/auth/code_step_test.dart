import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/steps/code_step.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import 'auth_fakes.dart';

const _email = 'lena.berger@posteo.de';

TextEditingValue _format(String old, String typed, {int? cursor}) {
  final oldValue = TextEditingValue(
    text: old,
    selection: TextSelection.collapsed(offset: cursor ?? old.length),
  );
  final newValue = TextEditingValue(
    text: typed,
    selection: TextSelection.collapsed(offset: typed.length),
  );
  return const CodeInputFormatter().formatEditUpdate(oldValue, newValue);
}

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  group('CodeInputFormatter', () {
    test('typing digits passes through', () {
      expect(_format('48', '482').text, '482');
    });

    test('pasting a mail sentence keeps the six digits', () {
      expect(_format('', 'Dein Code: 482913. Gültig 60 Minuten').text, '482913');
      expect(_format('', '482 913').text, '482913');
      expect(_format('', '482-913').text, '482913');
    });

    test('pasting into a half-filled field takes the pasted code', () {
      expect(_format('48', '48482913').text, '482913');
    });

    test('letters are dropped, never more than six digits', () {
      expect(_format('', 'a1b2c3').text, '123');
      expect(_format('482913', '4829131').text, '482913');
    });
  });

  group('CodeStep', () {
    late FakeAuthGateway gateway;
    late TestClock clock;
    var verified = 0;

    Widget step({CodePurpose purpose = CodePurpose.signIn}) => CodeStep(
      email: _email,
      purpose: purpose,
      onVerified: () => verified++,
      onBack: () {},
    );

    setUp(() {
      gateway = FakeAuthGateway();
      clock = TestClock();
      verified = 0;
    });

    testWidgets('six digits check by themselves', (tester) async {
      await pumpAuth(tester, step(), gateway, clock: clock);
      expect(find.text('We sent it to $_email.'), findsOneWidget);
      expect(_button(tester, 'Confirm').onPressed, isNull);

      await tester.enterText(find.byType(CupertinoTextField), '48291');
      await tester.pump();
      expect(gateway.calls, isEmpty);

      await tester.enterText(find.byType(CupertinoTextField), '482913');
      await tester.pump();
      expect(gateway.calls, ['verifySignInCode:$_email:482913']);
      expect(verified, 1);
    });

    testWidgets('pasted text from the mail is cleaned and checked', (
      tester,
    ) async {
      await pumpAuth(tester, step(), gateway, clock: clock);
      await tester.enterText(
        find.byType(CupertinoTextField),
        'Dein Avo-Code: 482 913',
      );
      await tester.pump();
      expect(gateway.calls, ['verifySignInCode:$_email:482913']);
    });

    testWidgets('wrong code: field stays, red line, deleting clears it', (
      tester,
    ) async {
      gateway.nextError = AuthApiException(
        'Token has expired or is invalid',
        code: 'otp_expired',
      );
      await pumpAuth(tester, step(), gateway, clock: clock);
      await tester.enterText(find.byType(CupertinoTextField), '111111');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('The code isn’t right. Check it or get a new one.'),
        findsOneWidget,
      );
      expect(find.text('111111'), findsOneWidget, reason: 'not cleared');
      expect(verified, 0);

      // Deleting a digit removes the error line.
      await tester.enterText(find.byType(CupertinoTextField), '11111');
      await tester.pump();
      expect(
        find.text('The code isn’t right. Check it or get a new one.'),
        findsNothing,
      );
    });

    testWidgets('a code older than its lifetime is called expired', (
      tester,
    ) async {
      await pumpAuth(tester, step(), gateway, clock: clock);
      clock.advance(const Duration(hours: 2));
      gateway.nextError = AuthApiException('x', code: 'otp_expired');
      await tester.enterText(find.byType(CupertinoTextField), '111111');
      await tester.pump();
      expect(find.text('The code has expired.'), findsOneWidget);
    });

    testWidgets('new code only after 60 s, then the countdown restarts', (
      tester,
    ) async {
      await pumpAuth(tester, step(), gateway, clock: clock);
      expect(find.text('New code in 1:00'), findsOneWidget);
      expect(_button(tester, 'New code in 1:00').onPressed, isNull);

      clock.advance(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('New code in 0:48'), findsOneWidget);

      clock.advance(const Duration(seconds: 48));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Send a new code'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), '12');
      await tester.tap(find.text('Send a new code'));
      await tester.pump();
      expect(gateway.calls, ['sendSignInCode:$_email']);
      expect(find.text('New code in 1:00'), findsOneWidget);
      expect(find.text('12'), findsNothing, reason: 'field cleared');
    });

    testWidgets('offline: the check waits and runs when back online', (
      tester,
    ) async {
      await pumpAuth(tester, step(), gateway, clock: clock);
      setOffline(tester, true);
      await tester.pump();
      await tester.enterText(find.byType(CupertinoTextField), '482913');
      await tester.pump();
      expect(gateway.calls, isEmpty);
      expect(
        find.text(
          'Offline. The code is checked as soon as you’re back online.',
        ),
        findsOneWidget,
      );

      setOffline(tester, false);
      await tester.pump();
      await tester.pump();
      expect(gateway.calls, ['verifySignInCode:$_email:482913']);
      expect(verified, 1);
    });

    testWidgets('too many attempts shows a status line', (tester) async {
      gateway.nextError = AuthApiException(
        'x',
        code: 'over_request_rate_limit',
      );
      await pumpAuth(tester, step(), gateway, clock: clock);
      await tester.enterText(find.byType(CupertinoTextField), '482913');
      await tester.pump();
      expect(
        find.text('Too many attempts. Please wait a minute.'),
        findsOneWidget,
      );
    });

    testWidgets('reset: pending flag before the check, cleared on failure', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        step(purpose: CodePurpose.passwordReset),
        gateway,
        clock: clock,
      );
      expect(find.text('Code to reset'), findsOneWidget);
      expect(
        find.text('If there’s an account for $_email, the code is on its way.'),
        findsOneWidget,
      );

      gateway.nextError = AuthApiException('x', code: 'otp_expired');
      await tester.enterText(find.byType(CupertinoTextField), '111111');
      await tester.pump();
      expect(gateway.calls, [
        'resetPending:true',
        'verifyPasswordResetCode:$_email:111111',
        'resetPending:false',
      ]);

      gateway.calls.clear();
      await tester.enterText(find.byType(CupertinoTextField), '482913');
      await tester.pump();
      expect(gateway.calls, [
        'resetPending:true',
        'verifyPasswordResetCode:$_email:482913',
      ]);
      expect(gateway.resetPending, isTrue);
      expect(verified, 1);
    });

    testWidgets('one-time-code autofill and number keyboard', (tester) async {
      await pumpAuth(tester, step(), gateway, clock: clock);
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.keyboardType, TextInputType.number);
    });
  });
}
