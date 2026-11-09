import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/profile/account/account_auth_pages.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/account/delete_account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/deletion_summary.dart';

import '../../../layout/layout_matrix.dart';
import 'account_fakes.dart';

Finder _inAlert(String text) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(text),
);

/// After a successful deletion the row keeps spinning until the router
/// leaves the page, so `pumpAndSettle` would never settle.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapDelete(WidgetTester tester, {bool enabled = true}) async {
  final row = find.descendant(
    of: find.byType(AccountDestructiveRow),
    matching: find.text('Delete account'),
  );
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row, warnIfMissed: enabled);
  await tester.pumpAndSettle();
}

void main() {
  group('summary (§7.3)', () {
    testWidgets('lists, recipes, history, profile, shared lists', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      expect(
        find.text(
          'Your account and everything that only belongs to you will be '
          'deleted for good. This can’t be undone.',
        ),
        findsOneWidget,
      );
      expect(find.text('3 lists that only belong to you'), findsOneWidget);
      expect(find.text('2 of your own recipes'), findsOneWidget);
      expect(find.text('History with 41 shopping trips'), findsOneWidget);
      expect(find.text('Profile, photo and settings'), findsOneWidget);
      expect(find.text('Wocheneinkauf goes to Lena.'), findsOneWidget);
      expect(
        find.text(
          'You leave 1 shared list. What you added there stays for the '
          'others, without your name.',
        ),
        findsOneWidget,
      );
      expect(find.text('Manage subscription'), findsNothing);
    });

    testWidgets('unknown numbers give rows without a number', (tester) async {
      final world = AccountTestWorld(summary: const DeletionSummary());
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      expect(find.text('Your recipes'), findsOneWidget);
      expect(find.text('Your history'), findsOneWidget);
      expect(find.textContaining('lists that only'), findsNothing);
      expect(find.text('Shared lists'), findsNothing);
    });

    testWidgets('Pro, calories and open amounts', (tester) async {
      final world = AccountTestWorld(
        summary: DeletionSummary(
          pro: true,
          proRenewsOn: DateTime(2027, 11, 7),
          calories: CalorieDiary.on,
          openBalances: 2,
        ),
      );
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      expect(find.text('Calorie diary'), findsOneWidget);
      expect(
        find.text('Data in Apple Health stays in Health.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your Avo Pro subscription keeps running until you cancel it with '
          'Apple. It renews on Nov 7, 2027.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('2 open amounts will be marked as settled for the others.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Manage subscription'));
      await tester.pump();
      await tester.tap(find.text('Manage subscription'));
      await tester.pump();
      expect(world.opened, ['subscriptions']);
    });

    testWidgets('German texts', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(
        tester,
        const DeleteAccountScreen(),
        world,
        locale: const Locale('de'),
      );
      expect(find.text('WAS GELÖSCHT WIRD'), findsOneWidget);
      expect(find.text('3 Listen, die nur dir gehören'), findsOneWidget);
      expect(find.text('Verlauf mit 41 Einkäufen'), findsOneWidget);
      expect(find.text('Wocheneinkauf geht an Lena über.'), findsOneWidget);
    });
  });

  group('flow (§7.3, §11.10)', () {
    testWidgets('Apple: confirm, alert, delete, finish, done', (tester) async {
      final world = AccountTestWorld();
      var deleted = 0;
      await pumpAccount(
        tester,
        DeleteAccountScreen(onDeleted: () => deleted++),
        world,
      );
      await _tapDelete(tester);
      expect(world.deletion.calls, ['confirm:apple']);
      expect(find.text('Delete account for good?'), findsOneWidget);
      expect(
        find.text(
          'Jannis, your account and your data will be deleted. '
          'Wocheneinkauf goes to Lena.',
        ),
        findsOneWidget,
      );
      await tester.tap(_inAlert('Delete'));
      await _frames(tester);
      expect(world.deletion.calls, [
        'confirm:apple',
        'delete:apple:apple-code',
      ]);
      expect(world.session.calls, ['finishDeletion']);
      expect(deleted, 1);
      expect(find.text('Your account has been deleted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('closing the Apple sheet does nothing', (tester) async {
      final world = AccountTestWorld();
      world.deletion.confirmResult = false;
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(world.deletion.calls, ['confirm:apple']);
    });

    testWidgets('cancel in the alert deletes nothing', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      await tester.tap(_inAlert('Cancel'));
      await tester.pumpAndSettle();
      expect(world.deletion.calls, ['confirm:apple']);
      expect(world.session.calls, isEmpty);
    });

    testWidgets('a failure says nothing was deleted; retry skips the sheet', (
      tester,
    ) async {
      final world = AccountTestWorld();
      world.deletion.hold = null;
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      world.deletion.nextError = const AccountDeletionFailed('status 500');
      await tester.tap(_inAlert('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Deleting didn’t work. Nothing was deleted.'),
        findsOneWidget,
      );
      expect(world.session.calls, isEmpty);

      await tester.ensureVisible(find.text('Try again'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      // The proof is still fresh: straight to the alert.
      expect(
        world.deletion.calls.where((c) => c == 'confirm:apple'),
        hasLength(1),
      );
      await tester.tap(_inAlert('Delete'));
      await _frames(tester);
      expect(world.session.calls, ['finishDeletion']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an old proof asks again', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      await tester.tap(_inAlert('Cancel'));
      await tester.pumpAndSettle();
      world.now = world.now.add(const Duration(minutes: 6));
      await _tapDelete(tester);
      expect(
        world.deletion.calls.where((c) => c == 'confirm:apple'),
        hasLength(2),
      );
      await tester.tap(_inAlert('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('while deleting the row shows progress and back is off', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      final hold = Completer<void>();
      world.deletion.hold = hold;
      await tester.tap(_inAlert('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is AbsorbPointer && w.absorbing),
        findsOneWidget,
      );
      hold.complete();
      await _frames(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('another account: nothing deleted, line shown', (tester) async {
      final world = AccountTestWorld();
      world.deletion.nextError = const AccountMismatchException();
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      expect(
        find.text('That was a different account. Nothing was deleted.'),
        findsOneWidget,
      );
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('email: code page "Confirm it’s you", then the alert', (
      tester,
    ) async {
      final world = AccountTestWorld(
        identity: const AccountIdentity(
          userId: 'u1',
          email: 'jannis.d@beispiel.de',
          method: SignInMethod.email,
        ),
      );
      await pumpAccount(tester, const DeleteAccountScreen(), world);
      await _tapDelete(tester);
      expect(world.deletion.calls, ['sendCode:jannis.d@beispiel.de']);
      expect(find.text('Confirm it’s you'), findsOneWidget);
      expect(find.byType(AccountCodeScreen), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), '482913');
      await tester.pumpAndSettle();
      expect(
        world.deletion.calls.last,
        'verifyCode:jannis.d@beispiel.de:482913',
      );
      expect(find.text('Delete account for good?'), findsOneWidget);
      await tester.tap(_inAlert('Delete'));
      await _frames(tester);
      expect(world.deletion.calls.last, 'delete:email:null');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('offline: status line and the button is off', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(
        tester,
        const DeleteAccountScreen(),
        world,
        offline: true,
      );
      expect(find.text('Needs a connection.'), findsOneWidget);
      await _tapDelete(tester, enabled: false);
      expect(world.deletion.calls, isEmpty);
    });
  });

  layoutMatrix(
    'DeleteAccountScreen',
    (context) => accountLayoutHost(
      context,
      const DeleteAccountScreen(),
      AccountTestWorld(
        summary: DeletionSummary(
          name: 'Jannis',
          ownLists: 3,
          handovers: const [
            ListHandover(
              listName: 'Wocheneinkauf fürs lange Wochenende',
              memberName: 'Maximiliane',
            ),
          ],
          leftLists: 2,
          ownRecipes: 12,
          trips: 141,
          calories: CalorieDiary.off,
          pro: true,
          proRenewsOn: DateTime(2027, 11, 7),
          openBalances: 2,
        ),
      ),
    ),
  );
  layoutMatrix(
    'DeleteAccountScreen offline',
    (context) => accountLayoutHost(
      context,
      const DeleteAccountScreen(),
      AccountTestWorld(),
      offline: true,
    ),
    cases: const [
      LayoutCase(width: 320, scale: 3.1),
      LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
    ],
  );
}
