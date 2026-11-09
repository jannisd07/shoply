import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/password_login_screen.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import 'auth_fakes.dart';

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  late FakeAuthGateway gateway;

  setUp(() => gateway = FakeAuthGateway());

  group('PasswordLoginScreen (§4.2)', () {
    var signedIn = 0;
    setUp(() => signedIn = 0);

    Widget screen() => PasswordLoginScreen(onSignedIn: () => signedIn++);

    Future<void> fill(WidgetTester tester) async {
      final fields = find.byType(CupertinoTextField);
      await tester.enterText(fields.at(0), 'jannis@beispiel.de');
      await tester.enterText(fields.at(1), 'Geheim123');
      await tester.pump();
    }

    testWidgets('keychain autofill on both fields, password hidden', (
      tester,
    ) async {
      await pumpAuth(tester, screen(), gateway);
      final fields = tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .toList();
      expect(fields[0].autofillHints, contains(AutofillHints.username));
      expect(fields[1].autofillHints, contains(AutofillHints.password));
      expect(fields[1].obscureText, isTrue);
      expect(find.byType(AutofillGroup), findsOneWidget);

      expect(find.bySemanticsLabel('Show password'), findsOneWidget);
      await tester.tap(find.byType(FieldSymbolButton));
      await tester.pump();
      expect(
        tester
            .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
            .last
            .obscureText,
        isFalse,
      );
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    });

    testWidgets('signs in with email and password', (tester) async {
      await pumpAuth(tester, screen(), gateway);
      expect(_button(tester, 'Sign in').onPressed, isNull);
      await fill(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(gateway.calls, ['signInWithPassword:jannis@beispiel.de:Geheim123']);
      expect(signedIn, 1);
    });

    testWidgets('wrong data offers a code, which leads to the code step', (
      tester,
    ) async {
      gateway.nextError = AuthApiException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      await pumpAuth(tester, screen(), gateway);
      await fill(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Email or password is wrong.'), findsOneWidget);
      expect(signedIn, 0);

      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(gateway.calls.last, 'sendSignInCode:jannis@beispiel.de');
      expect(find.text('Enter the code'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).last, '482913');
      await tester.pump();
      expect(signedIn, 1);
    });

    testWidgets('"Forgot password?" opens the reset with the address', (
      tester,
    ) async {
      await pumpAuth(tester, screen(), gateway);
      await fill(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('jannis@beispiel.de'), findsWidgets);
    });

    testWidgets('"Get a code by email instead" opens the address step', (
      tester,
    ) async {
      await pumpAuth(tester, screen(), gateway);
      await tester.tap(find.text('Get a code by email instead'));
      await tester.pumpAndSettle();
      expect(find.text('Your email address'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen (§4.4)', () {
    var done = 0;
    var cancelled = 0;
    setUp(() {
      done = 0;
      cancelled = 0;
    });

    Widget screen() => ResetPasswordScreen(
      onDone: () => done++,
      onCancelled: () => cancelled++,
    );

    testWidgets('rules tick off; saving needs all three', (tester) async {
      await pumpAuth(tester, screen(), gateway);
      expect(find.text('New password'), findsOneWidget);
      expect(_button(tester, 'Save password').onPressed, isNull);
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.autofillHints, contains(AutofillHints.newPassword));

      await tester.enterText(find.byType(CupertinoTextField), 'abcdefgh');
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('At least 8 characters')),
        matchesSemantics(label: 'At least 8 characters', value: 'met'),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('One capital letter')),
        matchesSemantics(label: 'One capital letter', value: 'missing'),
      );
      expect(_button(tester, 'Save password').onPressed, isNull);

      await tester.enterText(find.byType(CupertinoTextField), 'Abcdefg1');
      await tester.pump();
      await tester.tap(find.text('Save password'));
      await tester.pump();
      expect(gateway.calls, ['updatePassword:Abcdefg1', 'resetPending:false']);
      expect(done, 1);
    });

    testWidgets('the server reason shows as a status line', (tester) async {
      gateway.nextError = AuthApiException('x', code: 'same_password');
      await pumpAuth(tester, screen(), gateway);
      await tester.enterText(find.byType(CupertinoTextField), 'Abcdefg1');
      await tester.pump();
      await tester.tap(find.text('Save password'));
      await tester.pump();
      expect(
        find.text('That’s your current password. Choose a new one.'),
        findsOneWidget,
      );
      expect(done, 0);
    });

    testWidgets('cancel asks, then signs out', (tester) async {
      await pumpAuth(tester, screen(), gateway);
      await tester.tap(find.bySemanticsLabel('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Stop resetting?'), findsOneWidget);

      await tester.tap(find.text('Keep setting it'));
      await tester.pumpAndSettle();
      expect(gateway.calls, isEmpty);

      await tester.tap(find.bySemanticsLabel('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(gateway.calls, ['signOut', 'resetPending:false']);
      expect(cancelled, 1);
    });
  });
}
