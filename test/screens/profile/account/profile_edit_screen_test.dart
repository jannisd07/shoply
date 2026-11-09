import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/account_search.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_screen.dart';

import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';

import '../../../layout/layout_matrix.dart';
import '../../auth/auth_fakes.dart' show testOfflineProvider;
import 'account_fakes.dart';

Finder get _field => find.byType(CupertinoTextField);

/// Opens Profil bearbeiten as a pushed page above a plain home, so back
/// can be tested.
Future<void> _pumpPushed(WidgetTester tester, AccountTestWorld world) async {
  await pumpAccount(
    tester,
    Builder(
      builder: (context) => Center(
        child: CupertinoButton(
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => const ProfileEditScreen()),
          ),
          child: const Text('open'),
        ),
      ),
    ),
    world,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Back to Profile'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('name (§4.3)', () {
    testWidgets('shows name and email at once, no save button', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(
        tester.widget<CupertinoTextField>(_field).controller!.text,
        'Jannis',
      );
      expect(find.text(breakableEmail('jannis.d@beispiel.de')), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('Return takes a valid name over, trimmed', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.enterText(_field, '  Jannis D.  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(world.editor.calls, ['saveName:Jannis D.']);
    });

    testWidgets('Return with one character shows the error and keeps it', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.enterText(_field, 'J');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('At least 2 characters.'), findsOneWidget);
      expect(world.editor.calls, isEmpty);

      // Typing a valid name hides the error again.
      await tester.enterText(_field, 'Jo');
      await tester.pump();
      expect(find.text('At least 2 characters.'), findsNothing);
    });

    testWidgets('names longer than 40 characters are cut while typing', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.enterText(_field, 'A' * 45);
      await tester.pump();
      expect(
        tester.widget<CupertinoTextField>(_field).controller!.text.length,
        kNameMaxLength,
      );
    });

    testWidgets('leaving takes a valid name over', (tester) async {
      final world = AccountTestWorld();
      await _pumpPushed(tester, world);
      await tester.enterText(_field, 'Lena');
      await _back(tester);
      expect(world.editor.calls, ['saveName:Lena']);
      expect(find.byType(ProfileEditScreen), findsNothing);
    });

    testWidgets('leaving with a too short name keeps the old one and says so', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await _pumpPushed(tester, world);
      await tester.enterText(_field, 'L');
      await _back(tester);
      expect(world.editor.calls, isEmpty);
      expect(find.text('Name not changed: too short'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an unchanged name is not sent again', (tester) async {
      final world = AccountTestWorld();
      await _pumpPushed(tester, world);
      await tester.enterText(_field, ' Jannis ');
      await _back(tester);
      expect(world.editor.calls, isEmpty);
    });

    testWidgets('offline the name waits with the sync sign and is sent later', (
      tester,
    ) async {
      final world = AccountTestWorld();
      world.editor.nextError = Exception('offline');
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.enterText(_field, 'Lena');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        find.bySemanticsLabel('Saved on this iPhone, sent once you are online'),
        findsOneWidget,
      );
      final container = accountContainer(tester);
      expect(container.read(accountDisplayNameProvider), 'Lena');
      expect(
        container.read(profileEditControllerProvider.notifier).unsentChanges,
        1,
      );
    });
  });

  group('photo (§4.3, §11.5)', () {
    testWidgets('the menu offers choose and take, remove only with a photo', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      expect(find.text('Choose photo'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Asks once for the camera'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing);
    });

    testWidgets('a chosen photo shows at once and uploads in the background', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(world.opened, ['picker:library']);
      expect(world.editor.calls, ['upload:photo.jpg']);
      final avatar = tester.widget<Avatar>(find.byType(Avatar));
      expect(avatar.image, isA<MemoryImage>());
      expect(avatar.syncing, isFalse);
    });

    testWidgets('a failed upload keeps the photo and offers to retry', (
      tester,
    ) async {
      final world = AccountTestWorld();
      world.editor.nextError = Exception('500');
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(find.text('Photo not uploaded.'), findsOneWidget);
      expect(tester.widget<Avatar>(find.byType(Avatar)).image, isNotNull);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(world.editor.calls, ['upload:photo.jpg', 'upload:photo.jpg']);
      expect(find.text('Photo not uploaded.'), findsNothing);
    });

    testWidgets('offline the upload waits until the connection is back', (
      tester,
    ) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      accountContainer(tester).read(testOfflineProvider.notifier).state = true;
      await tester.pump();
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(world.editor.calls, isEmpty);
      expect(tester.widget<Avatar>(find.byType(Avatar)).syncing, isTrue);
      accountContainer(tester).read(testOfflineProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(world.editor.calls, ['upload:photo.jpg']);
    });

    testWidgets(
      'removing shows initials and deletes only after the undo time',
      (tester) async {
        final world = AccountTestWorld(
          profile: const AccountProfile(
            displayName: 'Jannis',
            avatarUrl: 'https://example.test/a.jpg',
          ),
        );
        await pumpAccount(tester, const ProfileEditScreen(), world);
        await tester.tap(find.text('Change photo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove photo'));
        await tester.pump();
        expect(tester.widget<Avatar>(find.byType(Avatar)).image, isNull);
        expect(find.text('Photo removed'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(world.editor.calls, isEmpty);
        await tester.pump(const Duration(seconds: 2));
        expect(world.editor.calls, ['removePhoto']);
      },
    );

    testWidgets('undo brings the photo back without any server call', (
      tester,
    ) async {
      final world = AccountTestWorld(
        profile: const AccountProfile(
          displayName: 'Jannis',
          avatarUrl: 'https://example.test/a.jpg',
        ),
      );
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      // Let the toast rise into place (each pump is one frame).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(seconds: 6));
      expect(world.editor.calls, isEmpty);
      expect(
        tester.widget<Avatar>(find.byType(Avatar)).image,
        isA<CachedNetworkImageProvider>().having(
          (p) => p.url,
          'url',
          'https://example.test/a.jpg',
        ),
      );
    });

    testWidgets('a denied camera shows the permission line with settings', (
      tester,
    ) async {
      final world = AccountTestWorld()
        ..camera = CameraAccess.denied
        ..pickerError = PlatformException(code: 'camera_access_denied');
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      expect(find.text('Asks once for the camera'), findsNothing);
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      expect(find.text('Camera is off.'), findsOneWidget);
      await tester.tap(find.text('Allow in Settings'));
      await tester.pump();
      expect(world.opened, ['picker:camera', 'settings']);
    });
  });

  group('links and search', () {
    testWidgets('"Account" under the email opens Konto', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(tester, const ProfileEditScreen(), world);
      await tester.ensureVisible(find.text('Account'));
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('?row= highlights the name row', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(
        tester,
        const ProfileEditScreen(highlightRowId: ProfileEditRows.name),
        world,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RowHighlightScope && w.rowId == ProfileEditRows.name,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is HighlightableRow && w.id == ProfileEditRows.name,
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('German texts', (tester) async {
      final world = AccountTestWorld();
      await pumpAccount(
        tester,
        const ProfileEditScreen(),
        world,
        locale: const Locale('de'),
      );
      expect(find.text('Profil bearbeiten'), findsOneWidget);
      expect(find.text('Foto ändern'), findsOneWidget);
      expect(
        find.text(
          'So sehen dich andere in geteilten Listen und bei deinen Rezepten.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ändern kannst du sie unter Konto.'), findsOneWidget);
    });
  });

  layoutMatrix(
    'ProfileEditScreen',
    (context) => accountLayoutHost(
      context,
      const ProfileEditScreen(),
      AccountTestWorld(
        profile: const AccountProfile(
          displayName: 'Maximiliane Musterfrau-Langenberg',
        ),
        identity: const AccountIdentity(
          userId: 'u1',
          email: 'maximiliane.musterfrau-langenberg@beispiel-mail.de',
          method: SignInMethod.email,
        ),
      ),
    ),
  );
}
