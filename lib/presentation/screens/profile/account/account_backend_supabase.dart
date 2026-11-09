import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/fcm_service.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/profile_picture_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/data/services/user_category_preferences.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_local_data.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How long sign-out waits for the push token removal before it goes on
/// without it (offline sign-out must not hang, Konzept 18 §7.2).
const Duration _kTokenRemovalTimeout = Duration(seconds: 3);

SupabaseClient get _client => SupabaseService.instance.client;

/// Name and photo through the A7 gateway and `ProfilePictureService`.
class SupabaseProfileEditor implements ProfileEditor {
  SupabaseProfileEditor(this._ref);

  final Ref _ref;

  @override
  Future<void> saveName(String name) async {
    await _ref.read(authGatewayProvider).saveDisplayName(name);
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId != null) {
      final cache = OfflineCacheService.instance;
      // Keep the cached onboarding flag: the router reads it offline.
      final cached = cache.getCachedUserProfileSync(userId);
      await cache.cacheUserProfile(
        userId: userId,
        displayName: name,
        onboardingCompleted: cached?.onboardingCompleted,
      );
    }
    _refresh();
  }

  @override
  Future<String> uploadPhoto(String filePath) async {
    final url = await ProfilePictureService().uploadProfilePicture(filePath);
    _refresh();
    return url;
  }

  @override
  Future<void> removePhoto() async {
    await ProfilePictureService().deleteProfilePicture();
    _refresh();
  }

  void _refresh() {
    _ref
      ..invalidate(currentUserProvider)
      ..invalidate(cachedUserProfileProvider);
  }
}

/// Password through the A7 gateway; email change with Supabase's
/// `email_change` code. The password state needs the RPC
/// `account_has_password()` (A8 report); without it the state is unknown.
class SupabaseAccountSecurity implements AccountSecurityService {
  SupabaseAccountSecurity(this._ref);

  final Ref _ref;

  @override
  Future<PasswordState> passwordState() async {
    try {
      final result = await _client.rpc<dynamic>('account_has_password');
      if (result is bool) {
        return result ? PasswordState.set : PasswordState.notSet;
      }
    } catch (e) {
      debugPrint('[ACCOUNT] password state unknown: ${e.runtimeType}');
    }
    return PasswordState.unknown;
  }

  @override
  Future<void> updatePassword(String password) =>
      _ref.read(authGatewayProvider).updatePassword(password);

  @override
  Future<void> requestEmailChange(String newEmail) =>
      SupabaseService.instance.requestEmailChange(newEmail);

  /// Confirms with the code; `users.email` follows in
  /// `SupabaseService.verifyEmailChange` (Teil B, A8).
  @override
  Future<void> verifyEmailChange(String newEmail, String code) =>
      SupabaseService.instance.verifyEmailChange(newEmail, code);
}

/// Konto löschen against the Edge Function `delete-account` (E18-09, draft
/// in the A8 report). Apple confirms with a fresh authorization code (the
/// server exchanges it and revokes the Apple token), Google and email
/// with a fresh sign-in (the server checks `last_sign_in_at`).
class SupabaseAccountDeletion implements AccountDeletionService {
  SupabaseAccountDeletion(this._ref);

  final Ref _ref;

  DateTime _now() => _ref.read(accountClockProvider)();

  @override
  Future<ReauthProof?> confirmWithProvider(SignInMethod method) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('No session');
    switch (method) {
      case SignInMethod.apple:
        return _confirmWithApple(userId);
      case SignInMethod.google:
        final signedIn = await _ref
            .read(authGatewayProvider)
            .signInWithGoogle();
        if (!signedIn) return null;
        if (_client.auth.currentUser?.id != userId) {
          // Google signed in another account: leave it, the account to
          // delete stays as it is.
          await _client.auth.signOut(scope: SignOutScope.local);
          throw const AccountMismatchException();
        }
        return ReauthProof(method: SignInMethod.google, at: _now());
      case SignInMethod.email:
        throw ArgumentError('Email accounts confirm with a code');
    }
  }

  Future<ReauthProof?> _confirmWithApple(String userId) async {
    final raw = _nonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final appleId = _appleIdOfAccount();
    final tokenSubject = _jwtSubject(credential.identityToken);
    if (appleId != null && tokenSubject != null && appleId != tokenSubject) {
      throw const AccountMismatchException();
    }
    return ReauthProof(
      method: SignInMethod.apple,
      at: _now(),
      appleAuthorizationCode: credential.authorizationCode,
    );
  }

  /// The Apple user id (`sub`) linked to the signed-in account.
  String? _appleIdOfAccount() {
    for (final identity in _client.auth.currentUser?.identities ?? const []) {
      if (identity.provider == 'apple') {
        final sub = identity.identityData?['sub'];
        return sub is String ? sub : identity.id;
      }
    }
    return null;
  }

  @override
  Future<void> sendCode(String email) =>
      SupabaseService.instance.sendEmailCode(email, createUser: false);

  @override
  Future<ReauthProof> verifyCode(String email, String code) async {
    final userId = _client.auth.currentUser?.id;
    await SupabaseService.instance.verifyEmailCode(email, code);
    if (_client.auth.currentUser?.id != userId) {
      throw const AccountMismatchException();
    }
    return ReauthProof(method: SignInMethod.email, at: _now());
  }

  @override
  Future<void> deleteAccount(ReauthProof proof) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'delete-account',
        body: {
          'method': proof.method.name,
          if (proof.appleAuthorizationCode != null)
            'apple_authorization_code': proof.appleAuthorizationCode,
        },
      );
    } on FunctionException catch (e) {
      throw AccountDeletionFailed('status ${e.status}');
    }
    final data = response.data;
    if (response.status != 200 || data is! Map || data['ok'] != true) {
      throw AccountDeletionFailed('status ${response.status}');
    }
  }
}

/// Sign-out with the clean-up of Konzept 18 §7.2. The auth listener in
/// `main.dart` additionally clears widget data, reminders and caches on
/// `signedOut`, as before.
class DefaultAccountSession implements AccountSession {
  DefaultAccountSession(this._ref);

  final Ref _ref;

  @override
  Future<void> signOut() async {
    try {
      await FCMService.instance.removeTokenForCurrentUser().timeout(
        _kTokenRemovalTimeout,
      );
    } catch (e) {
      // FCMService drops the token from the old row when the next account
      // saves it on this device.
      debugPrint('[ACCOUNT] push token not removed: ${e.runtimeType}');
    }
    try {
      await _ref.read(authGatewayProvider).signOut();
    } catch (e) {
      // The server may be unreachable: drop the session on the device.
      debugPrint('[ACCOUNT] sign-out at the server failed: ${e.runtimeType}');
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
    await _clearLocal();
  }

  @override
  Future<void> finishDeletion() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('[ACCOUNT] local sign-out failed: ${e.runtimeType}');
    }
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    // Tips first: reset() saves its state, the clean-up below removes it.
    TipService.instance.reset();
    UserCategoryPreferences.instance.clearCache();
    await OfflineCacheService.instance.clearCache();
    final prefs = await SharedPreferences.getInstance();
    await clearAccountBoundPreferences(prefs);
    _ref
      ..invalidate(profileEditControllerProvider)
      ..invalidate(passwordSavedProvider)
      ..invalidate(passwordStateProvider);
  }
}

String _nonce() {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    32,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

/// The `sub` claim of a JWT, without checking it (the server does).
String? _jwtSubject(String? token) {
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final sub = (jsonDecode(payload) as Map)['sub'];
    return sub is String ? sub : null;
  } catch (_) {
    return null;
  }
}
