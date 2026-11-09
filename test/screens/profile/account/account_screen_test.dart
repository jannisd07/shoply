import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/profile/account/account_auth_pages.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/account_search.dart';
import 'package:shoply/presentation/screens/profile/account/delete_account_screen.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import '../../../layout/layout_matrix.dart';
import 'account_fakes.dart';

const _emailAccount = AccountIdentity(
  userId: 'u1',
  email: 'jannis.d@beispiel.de',
  method: SignInMethod.email,
);

void main() {
  group('Konto (§7.1)', () {
    testWidgets('Apple: email and method, no password rows', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const AccountScreen(), world);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Signed in with'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Change email'), findsNothing);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(
        find.text('Deletes your account and your data for good.'),
        findsOneWidget,
      );
    });

    testWidgets('email account: change email and the password state', (
      tester,
    ) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.pump();
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Change email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('an unknown password state shows no value', (tester) async {
      final world = AccountTestWorld(identity: _emailAccount);
      world.security.state = PasswordState.unknown;
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.pump();
      expect(find.text('Not set'), findsNothing);
      expect(find.text('Set'), findsNothing);
    });

    testWidgets('?row= highlights "Konto löschen"', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(
        tester,
        const AccountScreen(highlightRowId: AccountRows.delete),
        world,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is HighlightableRow && w.id == AccountRows.delete,
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('"Konto löschen" opens the delete page', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });
  });

  group('Abmelden (§7.2, §11.9)', () {
    testWidgets('without unsent changes it signs out at once', (tester) async {
      final world = AccountTestWorld();
      var done = 0;
      await pumpAccount(
        tester,
        AccountScreen(onSignedOut: () => done++),
        world,
      );
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(world.session.calls, ['signOut']);
      expect(done, 1);
    });

    testWidgets('the row shows progress while signing out', (tester) async {
      final world = AccountTestWorld();
      world.session.hold = Completer<void>();
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      world.session.hold!.complete();
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('unsent changes ask first; cancel keeps the session', (
      tester,
    ) async {
      final world = AccountTestWorld()..unsent = 3;
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      expect(
        find.text(
          '3 changes haven’t been sent yet and will be lost if you sign out now.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(world.session.calls, isEmpty);
    });

    testWidgets('unsent changes: confirming signs out', (tester) async {
      final world = AccountTestWorld()..unsent = 1;
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '1 change hasn’t been sent yet and will be lost if you sign out now.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await tester.pumpAndSettle();
      expect(world.session.calls, ['signOut']);
    });
  });

  group('Passwort (§7.1, F-17-01)', () {
    testWidgets('set a password: rules, save, back to Konto with "Set"', (
      tester,
    ) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.pump();
      await tester.tap(find.text('Password'));
      await tester.pumpAndSettle();
      expect(find.text('Set a password'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Save password'))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(CupertinoTextField), 'Geheim123');
      await tester.pump();
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(world.security.calls, ['updatePassword:Geheim123']);
      expect(find.byType(AccountPasswordScreen), findsNothing);
      expect(find.text('Set'), findsOneWidget);
      expect(find.text('Password saved.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a weak password keeps the button off', (tester) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(
        tester,
        const AccountPasswordScreen(hasPassword: true),
        world,
      );
      expect(find.text('Change password'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), 'kurz');
      await tester.pump();
      await tester.tap(find.text('Save password'));
      await tester.pump();
      expect(world.security.calls, isEmpty);
    });

    testWidgets('a server error shows the line and stays', (tester) async {
      final world = AccountTestWorld(identity: _emailAccount);
      world.security.nextError = AuthApiException(
        'New password should be different',
        code: 'same_password',
      );
      await pumpAccount(tester, const AccountPasswordScreen(), world);
      await tester.enterText(find.byType(CupertinoTextField), 'Geheim123');
      await tester.pump();
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPasswordScreen), findsOneWidget);
      expect(world.security.calls, ['updatePassword:Geheim123']);
    });
  });

  group('E-Mail ändern (§7.1)', () {
    testWidgets('new address, code, back to Konto with the toast', (
      tester,
    ) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(tester, const AccountScreen(), world);
      await tester.tap(find.text('Change email'));
      await tester.pumpAndSettle();
      expect(find.text('New email address'), findsOneWidget);
      await tester.enterText(
        find.byType(CupertinoTextField),
        ' Jannis@Neu.de ',
      );
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(world.security.calls, ['requestEmailChange:jannis@neu.de']);
      expect(find.text('Enter the code'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), '482913');
      await tester.pumpAndSettle();
      expect(
        world.security.calls.last,
        'verifyEmailChange:jannis@neu.de:482913',
      );
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byType(AccountEmailChangeScreen), findsNothing);
      expect(find.text('Email changed.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the same address is refused under the field', (tester) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(
        tester,
        const AccountEmailChangeScreen(currentEmail: 'jannis.d@beispiel.de'),
        world,
      );
      await tester.enterText(
        find.byType(CupertinoTextField),
        'jannis.d@beispiel.de',
      );
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(find.text('That’s already your address.'), findsOneWidget);
      expect(world.security.calls, isEmpty);
    });

    testWidgets('a wrong code stays on the code page', (tester) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(
        tester,
        AccountCodeScreen(
          title: 'Enter the code',
          message: 'We sent it to x@y.de.',
          onResend: () async {},
          onVerify: (code) async {
            throw AuthApiException('Token has expired', code: 'otp_expired');
          },
        ),
        world,
      );
      await tester.enterText(find.byType(CupertinoTextField), '111111');
      await tester.pumpAndSettle();
      expect(find.byType(AccountCodeScreen), findsOneWidget);
      expect(find.textContaining('code'), findsWidgets);
    });

    testWidgets('offline the address page says it needs a connection', (
      tester,
    ) async {
      final world = AccountTestWorld(identity: _emailAccount);
      await pumpAccount(
        tester,
        const AccountEmailChangeScreen(currentEmail: 'jannis.d@beispiel.de'),
        world,
        offline: true,
      );
      expect(find.text('Needs a connection.'), findsOneWidget);
    });
  });

  layoutMatrix(
    'AccountScreen',
    (context) => accountLayoutHost(
      context,
      const AccountScreen(),
      AccountTestWorld(
        identity: const AccountIdentity(
          userId: 'u1',
          email: 'maximiliane.musterfrau-langenberg@beispiel-mail.de',
          method: SignInMethod.email,
        ),
      ),
    ),
  );
  layoutMatrix(
    'AccountPasswordScreen',
    (context) => accountLayoutHost(
      context,
      const AccountPasswordScreen(),
      AccountTestWorld(identity: _emailAccount),
    ),
  );
  layoutMatrix(
    'AccountEmailChangeScreen',
    (context) => accountLayoutHost(
      context,
      const AccountEmailChangeScreen(currentEmail: 'jannis.d@beispiel.de'),
      AccountTestWorld(identity: _emailAccount),
      offline: true,
    ),
  );
}
