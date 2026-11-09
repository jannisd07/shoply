// Fakes and harness for the A8 part "Konto" (Profil bearbeiten, Konto,
// Abmelden, Konto löschen): no Supabase, no platform channels. Every fake
// records its calls and can hold or fail the next one.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/deletion_summary.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../../layout/layout_matrix.dart';
import '../../auth/auth_fakes.dart';

/// Shared behaviour of the fakes: a call log, a hold and a one-shot error.
mixin _Recorder {
  final List<String> calls = [];
  Object? nextError;
  Completer<void>? hold;

  Future<void> run(String call) async {
    calls.add(call);
    final waitFor = hold;
    if (waitFor != null) await waitFor.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}

class FakeProfileEditor with _Recorder implements ProfileEditor {
  @override
  Future<void> saveName(String name) => run('saveName:$name');

  @override
  Future<String> uploadPhoto(String filePath) async {
    await run('upload:$filePath');
    return 'https://example.test/$filePath';
  }

  @override
  Future<void> removePhoto() => run('removePhoto');
}

class FakeAccountSecurity with _Recorder implements AccountSecurityService {
  PasswordState state = PasswordState.notSet;

  @override
  Future<PasswordState> passwordState() async => state;

  @override
  Future<void> updatePassword(String password) =>
      run('updatePassword:$password');

  @override
  Future<void> requestEmailChange(String newEmail) =>
      run('requestEmailChange:$newEmail');

  @override
  Future<void> verifyEmailChange(String newEmail, String code) =>
      run('verifyEmailChange:$newEmail:$code');
}

class FakeAccountDeletion with _Recorder implements AccountDeletionService {
  FakeAccountDeletion(this.clock);

  final DateTime Function() clock;

  /// Result of the Apple/Google sheet: false means closed.
  bool confirmResult = true;

  @override
  Future<ReauthProof?> confirmWithProvider(SignInMethod method) async {
    await run('confirm:${method.name}');
    if (!confirmResult) return null;
    return ReauthProof(
      method: method,
      at: clock(),
      appleAuthorizationCode: method == SignInMethod.apple
          ? 'apple-code'
          : null,
    );
  }

  @override
  Future<void> sendCode(String email) => run('sendCode:$email');

  @override
  Future<ReauthProof> verifyCode(String email, String code) async {
    await run('verifyCode:$email:$code');
    return ReauthProof(method: SignInMethod.email, at: clock());
  }

  @override
  Future<void> deleteAccount(ReauthProof proof) =>
      run('delete:${proof.method.name}:${proof.appleAuthorizationCode}');
}

class FakeAccountSession with _Recorder implements AccountSession {
  @override
  Future<void> signOut() => run('signOut');

  @override
  Future<void> finishDeletion() => run('finishDeletion');
}

/// Everything the account pages read, in one place.
class AccountTestWorld {
  AccountTestWorld({
    this.identity = const AccountIdentity(
      userId: 'u1',
      email: 'jannis.d@beispiel.de',
      method: SignInMethod.apple,
    ),
    this.profile = const AccountProfile(displayName: 'Jannis'),
    this.summary = const DeletionSummary(
      name: 'Jannis',
      ownLists: 3,
      handovers: [ListHandover(listName: 'Wocheneinkauf', memberName: 'Lena')],
      leftLists: 1,
      ownRecipes: 2,
      trips: 41,
    ),
    this.unsent = 0,
  });

  AccountIdentity? identity;
  AccountProfile profile;
  DeletionSummary summary;
  int unsent;

  DateTime now = DateTime(2026, 11, 7, 10);
  final editor = FakeProfileEditor();
  final security = FakeAccountSecurity();
  late final deletion = FakeAccountDeletion(() => now);
  final session = FakeAccountSession();
  final auth = FakeAuthGateway(hasSession: true);

  /// What the photo picker returns next; null means cancelled.
  PickedPhoto? nextPhoto = PickedPhoto(bytes: tinyPng(), path: 'photo.jpg');

  /// Thrown by the photo picker next.
  Object? pickerError;
  CameraAccess camera = CameraAccess.notAsked;
  final List<String> opened = [];

  List<Override> overrides({bool offline = false}) => [
    ...authOverrides(auth),
    if (offline) testOfflineProvider.overrideWith((ref) => true),
    accountIdentityProvider.overrideWith((ref) => identity),
    accountProfileProvider.overrideWith((ref) => profile),
    deletionSummaryProvider.overrideWith((ref) => summary),
    profileEditorProvider.overrideWithValue(editor),
    accountSecurityProvider.overrideWithValue(security),
    accountDeletionProvider.overrideWithValue(deletion),
    accountSessionProvider.overrideWithValue(session),
    accountClockProvider.overrideWithValue(() => now),
    unsentChangesProvider.overrideWithValue(() => unsent),
    photoPickerProvider.overrideWithValue((source) async {
      opened.add('picker:${source.name}');
      final error = pickerError;
      if (error != null) {
        pickerError = null;
        throw error;
      }
      return nextPhoto;
    }),
    cameraAccessProvider.overrideWithValue(() async => camera),
    openAppSettingsProvider.overrideWithValue(() async {
      opened.add('settings');
    }),
    manageSubscriptionsProvider.overrideWithValue(() async {
      opened.add('subscriptions');
    }),
  ];
}

/// The app's delegates (`app.dart`), so German Cupertino texts exist.
const List<LocalizationsDelegate<dynamic>> kAccountTestDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// A 2 × 2 PNG, a valid image for `Image.memory`.
Uint8List tinyPng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

/// The screen in an app-like harness (390 pt, default text, English unless
/// [locale] says otherwise), with a navigator so pushes work.
Future<void> pumpAccount(
  WidgetTester tester,
  Widget child,
  AccountTestWorld world, {
  bool offline = false,
  Locale? locale,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: world.overrides(offline: offline),
      child: _toastHarness(
        layout,
        SizedBox.expand(
          child: Builder(
            builder: (context) => locale == null
                ? child
                : Localizations.override(
                    context: context,
                    locale: locale,
                    delegates: kAccountTestDelegates,
                    child: child,
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// [layoutHarness] with the app's [AvoToastHost] around the navigator, so
/// toasts outlive a pop like in the app.
Widget _toastHarness(LayoutCase c, Widget child) => MediaQuery(
  data: MediaQueryData(
    size: Size(c.width, kLayoutHeight),
    devicePixelRatio: 3,
    textScaler: TextScaler.linear(c.scale),
    boldText: c.bold,
    platformBrightness: c.brightness,
    padding: const EdgeInsets.only(top: 47, bottom: 34),
    viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
  ),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: c.brightness,
      platform: TargetPlatform.iOS,
      fontFamily: 'CupertinoSystemText',
    ),
    localizationsDelegates: kAccountTestDelegates,
    supportedLocales: const [Locale('en'), Locale('de')],
    builder: (context, navigator) => AvoToastHost(child: navigator!),
    home: AvoDesignScope(
      child: Builder(
        builder: (context) =>
            ColoredBox(color: context.colors.background, child: child),
      ),
    ),
  ),
);

/// The [ProviderContainer] of the pumped harness.
ProviderContainer accountContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SizedBox).first));

/// For [layoutMatrix]: the screen with the world's overrides, in German
/// (the longer texts).
Widget accountLayoutHost(
  BuildContext context,
  Widget child,
  AccountTestWorld world, {
  bool offline = false,
}) => ProviderScope(
  overrides: world.overrides(offline: offline),
  child: SizedBox.expand(
    child: Localizations.override(
      context: context,
      locale: const Locale('de'),
      delegates: kAccountTestDelegates,
      child: child,
    ),
  ),
);
