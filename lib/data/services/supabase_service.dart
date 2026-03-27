import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/config/env.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

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


  // Sign in with Apple (iOS only)
  Future<bool> signInWithApple() async {
    debugPrint('🍎 [APPLE_AUTH] signInWithApple() called');
    debugPrint('🍎 [APPLE_AUTH] Platform: $defaultTargetPlatform');
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        // Check if Apple Sign In is available (not available in Simulator)
        final isAvailable = await SignInWithApple.isAvailable();
        debugPrint('🍎 [APPLE_AUTH] isAvailable: $isAvailable');
        
        if (!isAvailable) {
          throw Exception('Apple Sign-In ist auf diesem Gerät nicht verfügbar. Bitte verwenden Sie ein echtes iOS-Gerät.');
        }
        
        debugPrint('🍎 [APPLE_AUTH] Requesting Apple credentials...');
        
        // Use native Apple Sign In package for better UX
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        
        debugPrint('🍎 [APPLE_AUTH] Got Apple credential, identityToken present: ${appleCredential.identityToken != null}');

        if (appleCredential.identityToken == null) {
          throw Exception('Apple Sign-In fehlgeschlagen: Kein Identity Token erhalten.');
        }

        debugPrint('🍎 [APPLE_AUTH] Signing in to Supabase...');
        
        // Sign in to Supabase with Apple credentials
        await client.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: appleCredential.identityToken!,
        );

        debugPrint('🍎 [APPLE_AUTH] Success!');
        return true;
      } on SignInWithAppleAuthorizationException catch (e) {
        debugPrint('🍎 [APPLE_AUTH] Authorization exception: ${e.code} - ${e.message}');
        if (e.code == AuthorizationErrorCode.canceled) {
          // User cancelled - not an error
          return false;
        }
        throw Exception('Apple Sign-In Fehler: ${e.message}');
      } catch (e) {
        debugPrint('🍎 [APPLE_AUTH] Error: $e');
        // Check if it's a configuration error
        if (e.toString().contains('validation_failed') || e.toString().contains('OAuth secret')) {
          throw Exception('Apple Sign-In ist noch nicht konfiguriert. Bitte verwenden Sie Email/Passwort.');
        }
        if (e.toString().contains('nicht verfügbar')) {
          rethrow;
        }
        rethrow;
      }
    } else {
      throw Exception('Apple Sign-In ist nur auf iOS-Geräten verfügbar.');
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      // Get Google Client ID from env if available, otherwise use empty string
      String? clientId;
      try {
        clientId = Env.googleClientId;
      } catch (e) {
        // If googleClientId doesn't exist in Env, leave it null
        clientId = null;
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: clientId, // Optional - only needed for backend auth
      );

      // Trigger Google Sign In flow with timeout
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Google Sign In timeout - bitte versuchen Sie es erneut');
        },
      );
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return false;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Failed to get Google credentials');
      }

      // Sign in to Supabase with Google credentials
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return true;
    } on TimeoutException catch (e) {
      throw Exception('Google Sign In hat zu lange gedauert. Bitte versuchen Sie es erneut.');
    } catch (e) {
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

  // Reset password - sends OTP code instead of magic link
  Future<void> resetPassword(String email) async {
    debugPrint('🔐 [SUPABASE] Sending password reset OTP to: $email');
    
    try {
      // Use signInWithOtp with shouldCreateUser: false to send recovery code
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Don't create new user, just send recovery code
      );
      debugPrint('✅ [SUPABASE] Password reset OTP sent successfully');
    } catch (e) {
      debugPrint('❌ [SUPABASE] Password reset OTP error: $e');
      rethrow;
    }
  }

  // Verify OTP for password reset and sign in
  Future<AuthResponse> verifyPasswordResetOtp(String email, String otp) async {
    debugPrint('🔐 [SUPABASE] Verifying password reset OTP for: $email');
    
    try {
      final response = await client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email, // Use email type for signInWithOtp
      );
      debugPrint('✅ [SUPABASE] Password reset OTP verified successfully');
      return response;
    } catch (e) {
      debugPrint('❌ [SUPABASE] Password reset OTP verification error: $e');
      rethrow;
    }
  }

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
