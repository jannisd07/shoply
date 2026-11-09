import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/password_login_screen.dart';
import 'package:shoply/presentation/screens/auth/steps/email_step.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import 'auth_fakes.dart';

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  late FakeAuthGateway gateway;
  late List<String> sent;

  setUp(() {
    gateway = FakeAuthGateway();
    sent = [];
  });

  testWidgets('"Send code" waits for an address, then sends it cleaned', (
    tester,
  ) async {
    await pumpAuth(tester, EmailStep(onCodeSent: sent.add), gateway);
    expect(find.text('Your email address'), findsOneWidget);
    expect(_button(tester, 'Send code').onPressed, isNull);

    await tester.enterText(find.byType(CupertinoTextField), 'lena@');
    await tester.pump();
    expect(_button(tester, 'Send code').onPressed, isNull);

    await tester.enterText(
      find.byType(CupertinoTextField),
      ' Lena.Berger@Posteo.de ',
    );
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(gateway.calls, ['sendSignInCode:lena.berger@posteo.de']);
    expect(sent, ['lena.berger@posteo.de']);
  });

  testWidgets('Return sends', (tester) async {
    await pumpAuth(tester, EmailStep(onCodeSent: sent.add), gateway);
    await tester.enterText(find.byType(CupertinoTextField), 'lena@posteo.de');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sent, ['lena@posteo.de']);
  });

  testWidgets('server says the address is invalid: line under the field', (
    tester,
  ) async {
    gateway.nextError = AuthApiException('x', code: 'email_address_invalid');
    await pumpAuth(tester, EmailStep(onCodeSent: sent.add), gateway);
    await tester.enterText(find.byType(CupertinoTextField), 'lena@posteo.de');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('This email address doesn’t look right.'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.enterText(find.byType(CupertinoTextField), 'lena@posteo.com');
    await tester.pump();
    expect(find.text('This email address doesn’t look right.'), findsNothing);
  });

  testWidgets('too many attempts and offline as status lines', (tester) async {
    gateway.nextError = AuthApiException(
      'x',
      code: 'over_email_send_rate_limit',
    );
    await pumpAuth(tester, EmailStep(onCodeSent: sent.add), gateway);
    await tester.enterText(find.byType(CupertinoTextField), 'lena@posteo.de');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(
      find.text('Too many attempts. Please wait a minute.'),
      findsOneWidget,
    );

    setOffline(tester, true);
    await tester.enterText(find.byType(CupertinoTextField), 'lena@posteo.com');
    await tester.pump();
    expect(
      find.text('Offline. You need a connection to send the code.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(gateway.calls, ['sendSignInCode:lena@posteo.de']);
  });

  testWidgets('"Sign in with password" only when the flow asks for it', (
    tester,
  ) async {
    var password = 0;
    await pumpAuth(
      tester,
      EmailStep(onCodeSent: sent.add, onPassword: () => password++),
      gateway,
    );
    await tester.tap(find.text('Sign in with password'));
    expect(password, 1);
  });

  testWidgets('reset: unknown address gets the same answer (§4.3)', (
    tester,
  ) async {
    gateway.nextError = AuthApiException(
      'Signups not allowed for otp',
      code: 'otp_disabled',
    );
    await pumpAuth(
      tester,
      const ResetPasswordRequestScreen(initialEmail: 'nobody@posteo.de'),
      gateway,
    );
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('nobody@posteo.de'), findsOneWidget, reason: 'prefilled');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(gateway.calls, ['sendPasswordResetCode:nobody@posteo.de']);
    expect(find.text('Code to reset'), findsOneWidget);
    expect(
      find.text(
        'If there’s an account for nobody@posteo.de, the code is on its way.',
      ),
      findsOneWidget,
    );
  });
}
