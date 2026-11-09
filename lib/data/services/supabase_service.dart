import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/config/env.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase has not been initialized. Call initialize() first.');
    }
    return _client!;
  }

  // Auth methods
  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail(String email, String password, {String? emailRedirectTo}) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo,
    );
  }


  /// Sign in with Apple (iOS only). Null when the person closed the Apple
  /// sheet. Errors are rethrown unchanged
  /// ([SignInWithAppleAuthorizationException], [AuthException] with `code`,
  /// [PlatformException]); `PlatformException(code: 'apple_unavailable')`
  /// off iOS or where Apple sign-in is not available.
  ///
  /// The raw nonce goes to Supabase, its SHA-256 to Apple, so a token can't
  /// be replayed. Apple sends the name only at the first authorization; it
  /// is saved as `given_name`/`family_name` in the user metadata then.
  Future<AppleSignInResult?> signInWithApple() async {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        !await SignInWithApple.isAvailable()) {
      throw PlatformException(code: 'apple_unavailable');
    }
    final nonce = appleNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce.hashed,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple sent no identity token',
          code: 'apple_no_identity_token');
    }
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: nonce.raw,
    );
    final result = AppleSignInResult(
      givenName: _nonEmpty(credential.givenName),
      familyName: _nonEmpty(credential.familyName),
    );
    if (result.givenName != null || result.familyName != null) {
      try {
        await client.auth.updateUser(UserAttributes(data: {
          if (result.givenName != null) 'given_name': result.givenName,
          if (result.familyName != null) 'family_name': result.familyName,
        }));
      } on AuthException catch (e) {
        // The sign-in worked; the name step asks again if this failed.
        debugPrint('⚠️ [APPLE_AUTH] Saving the name failed: ${e.code}');
      }
    }
    return result;
  }

  /// A fresh nonce for Sign in with Apple: [raw] for Supabase, [hashed]
  /// (SHA-256, hex) for Apple.
  @visibleForTesting
  static ({String raw, String hashed}) appleNonce([Random? random]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rng = random ?? Random.secure();
    final raw = List.generate(32, (_) => charset[rng.nextInt(charset.length)])
        .join();
    return (raw: raw, hashed: sha256.convert(utf8.encode(raw)).toString());
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    debugPrint('🔵 [GOOGLE] signInWithGoogle() start');
    try {
      // Pass the iOS OAuth client ID explicitly on iOS so the plugin does not
      // silently rely on Info.plist GIDClientID lookup. This client ID MUST
      // match what's configured in Supabase → Auth → Providers → Google.
      // No serverClientId – Supabase validates against the iOS client directly.
      const iosClientId = '595687303381-0lkcria4dis8m5u36iflej3alosaep1a.apps.googleusercontent.com';
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? iosClientId : null,
      );
      debugPrint('🔵 [GOOGLE] plugin configured, calling signIn()');

      // Trigger Google Sign In flow with timeout
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('❌ [GOOGLE] signIn() timed out after 60s');
          throw TimeoutException('Google Sign In timeout', const Duration(seconds: 60));
        },
      );
      debugPrint('🔵 [GOOGLE] signIn() returned: ${googleUser?.email ?? "null (cancelled)"}');

      if (googleUser == null) {
        // User cancelled the sign-in
        return false;
      }

      // Get authentication details
      debugPrint('🔵 [GOOGLE] fetching authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;
      debugPrint('🔵 [GOOGLE] accessToken: ${accessToken != null ? "present (${accessToken.length} chars)" : "NULL"}');
      debugPrint('🔵 [GOOGLE] idToken: ${idToken != null ? "present (${idToken.length} chars)" : "NULL"}');

      if (accessToken == null || idToken == null) {
        throw Exception('Failed to get Google credentials (accessToken=${accessToken != null}, idToken=${idToken != null})');
      }

      // Sign in to Supabase with Google credentials
      debugPrint('🔵 [GOOGLE] posting idToken to Supabase...');
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      debugPrint('✅ [GOOGLE] Supabase signInWithIdToken OK');

      return true;
    } on TimeoutException catch (e, st) {
      debugPrint('❌ [GOOGLE] TimeoutException: $e\n$st');
      throw Exception('Google Sign In hat zu lange gedauert. Bitte versuchen Sie es erneut.');
    } catch (e, st) {
      debugPrint('❌ [GOOGLE] raw error: ${e.runtimeType}: $e');
      debugPrint('❌ [GOOGLE] stack: $st');
      if (e.toString().contains('validation_failed') || e.toString().contains('OAuth')) {
        throw Exception('Google Sign-In ist noch nicht konfiguriert. Bitte verwenden Sie Email/Passwort.');
      }
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw Exception('Netzwerkfehler. Bitte überprüfen Sie Ihre Internetverbindung.');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Sends a 6-digit code to [email] (Supabase OTP). With [createUser] the
  /// address may register a new account; without it only an existing
  /// account gets a code. Errors are rethrown unchanged ([AuthException]
  /// carries `code`), so the caller can tell them apart.
  Future<void> sendEmailCode(String email, {required bool createUser}) =>
      client.auth.signInWithOtp(email: email, shouldCreateUser: createUser);

  /// Signs in with the code [sendEmailCode] sent. Errors are rethrown
  /// unchanged.
  Future<AuthResponse> verifyEmailCode(String email, String code) =>
      client.auth.verifyOTP(email: email, token: code, type: OtpType.email);

  // Update user
  Future<UserResponse> updateUser(UserAttributes attributes) async {
    return await client.auth.updateUser(attributes);
  }

  // Update user metadata
  Future<void> updateUserMetadata(Map<String, dynamic> metadata) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Update auth metadata
    await client.auth.updateUser(UserAttributes(data: metadata));

    // Also update in users table
    if (metadata.containsKey('display_name')) {
      await client.from('users').update({
        'display_name': metadata['display_name'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    }

    if (metadata.containsKey('diet_preferences')) {
      await client.from('users').update({
        'diet_preferences': metadata['diet_preferences'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    }
  }

  // Database methods
  PostgrestQueryBuilder from(String table) => client.from(table);

  // Storage methods
  SupabaseStorageClient get storage => client.storage;

  // Realtime methods
  RealtimeChannel channel(String name) => client.channel(name);
}

/// The name Apple shared at the first authorization; both null on later
/// sign-ins (Apple sends the name only once).
class AppleSignInResult {
  const AppleSignInResult({this.givenName, this.familyName});

  final String? givenName;
  final String? familyName;
}
