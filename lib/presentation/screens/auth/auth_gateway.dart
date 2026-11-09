import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

/// SharedPreferences flag: a password reset code was accepted but no new
/// password is saved yet (Konzept 17 §4.4, §9.6, Bug 9). The router sends
/// the next start to `/reset-password` while it is set.
const String kPasswordResetPendingKey = 'password_reset_pending';

/// Supabase lets a new code go to the same address only after this time;
/// "Neuen Code senden" waits for it (Konzept 17 §3.7).
const Duration kCodeResendCooldown = Duration(seconds: 60);

/// Lifetime of an email code (Supabase default `MAILER_OTP_EXP`, 1 hour).
/// Supabase answers a wrong and an expired code with the same error
/// (`otp_expired`); after this time the code step calls it expired.
const Duration kCodeLifetime = Duration(hours: 1);

/// Number of digits of the email code.
const int kCodeLength = 6;

/// Everything the account screens need from the sign-in backend
/// (Konzept 17 §3.5–3.8, §4). The app uses [SupabaseAuthGateway]; tests
/// override [authGatewayProvider] with a fake.
///
/// Errors are thrown as they come (`AuthException` with its `code`, or the
/// exceptions of `SupabaseService`); `classifyAuthError` turns them into
/// the texts of §4.6.
abstract class AuthGateway {
  /// Sign in with Apple is offered (iOS only, §3.5).
  bool get appleAvailable;

  /// A Supabase session exists right now.
  bool get hasSession;

  /// First name from Apple or Google for the name step (§3.8), never the
  /// part of the email before the @.
  String? get suggestedFirstName;

  /// Apple sign-in. False when the user closed the Apple sheet.
  Future<bool> signInWithApple();

  /// Google sign-in. False when the user closed the Google sheet.
  Future<bool> signInWithGoogle();

  /// Sends the 6-digit code that signs in or creates the account (§3.6,
  /// F-17-01: new accounts need no password).
  Future<void> sendSignInCode(String email);

  /// Checks the code from [sendSignInCode]; a session exists afterwards.
  Future<void> verifySignInCode(String email, String code);

  /// Sends the code for "Passwort vergessen" (§4.3). Never creates an
  /// account.
  Future<void> sendPasswordResetCode(String email);

  /// Checks the code from [sendPasswordResetCode]; a session exists
  /// afterwards and the new password follows (§4.4).
  Future<void> verifyPasswordResetCode(String email, String code);

  /// Email and password (§4.2, existing accounts).
  Future<void> signInWithPassword(String email, String password);

  /// Saves a new password for the signed-in account (§4.4).
  Future<void> updatePassword(String password);

  /// Writes `users.display_name` (targeted update, §1.2 and §3.8).
  Future<void> saveDisplayName(String name);

  Future<void> signOut();

  /// Sets or clears [kPasswordResetPendingKey].
  Future<void> setPasswordResetPending(bool pending);
}

/// The sign-in backend of the app. Goes through `SupabaseService` (Teil B);
/// where it has no method yet, it uses the public `client` like the old
/// screens did (see the A7 report for the missing methods).
class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway();

  SupabaseService get _service => SupabaseService.instance;

  @override
  bool get appleAvailable => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get hasSession => _service.currentSession != null;

  @override
  String? get suggestedFirstName {
    final user = _service.currentUser;
    if (user == null) return null;
    return firstNameFromMetadata(user.userMetadata, email: user.email);
  }

  @override
  Future<bool> signInWithApple() => _service.signInWithApple();

  @override
  Future<bool> signInWithGoogle() => _service.signInWithGoogle();

  @override
  Future<void> sendSignInCode(String email) =>
      // Until SupabaseService.sendEmailCode(email, createUser: true) exists.
      _service.client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<void> verifySignInCode(String email, String code) =>
      // verifyOTP with OtpType.email: covers new (signup) and existing
      // accounts. The method name in SupabaseService says "reset", the call
      // is the same.
      _service.verifyPasswordResetOtp(email, code);

  @override
  Future<void> sendPasswordResetCode(String email) =>
      _service.resetPassword(email);

  @override
  Future<void> verifyPasswordResetCode(String email, String code) =>
      _service.verifyPasswordResetOtp(email, code);

  @override
  Future<void> signInWithPassword(String email, String password) =>
      _service.signInWithEmail(email, password);

  @override
  Future<void> updatePassword(String password) =>
      _service.updateUser(UserAttributes(password: password));

  @override
  Future<void> saveDisplayName(String name) =>
      _service.updateUserMetadata({'display_name': name});

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<void> setPasswordResetPending(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    if (pending) {
      await prefs.setBool(kPasswordResetPendingKey, true);
    } else {
      await prefs.remove(kPasswordResetPendingKey);
    }
  }
}

/// The sign-in backend for the account screens.
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => const SupabaseAuthGateway(),
);

/// The clock of the code step (resend cooldown, code lifetime). Tests
/// override it to move time without waiting.
final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The address typed last in an account screen, so "Passwort vergessen?"
/// and "Stattdessen Code per E-Mail" start with it (§4.3). Kept in memory
/// only, never in a route.
final authEmailDraftProvider = StateProvider<String>((ref) => '');

/// The first name from the provider metadata (Apple `given_name` saved at
/// the first authorization, Google `given_name` or the first word of
/// `full_name`/`name`). Returns null for anything that looks like an email
/// or equals the part of [email] before the @ (Konzept 17 §3.8, Bug 13).
String? firstNameFromMetadata(Map<String, dynamic>? metadata, {String? email}) {
  if (metadata == null) return null;
  final localPart = email == null || !email.contains('@')
      ? null
      : email.split('@').first.toLowerCase();
  for (final key in ['given_name', 'first_name', 'full_name', 'name']) {
    final value = metadata[key];
    if (value is! String) continue;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('@')) continue;
    final first = key == 'full_name' || key == 'name'
        ? trimmed.split(RegExp(r'\s+')).first
        : trimmed;
    if (localPart != null && first.toLowerCase() == localPart) continue;
    return first;
  }
  return null;
}

final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// The input has the form of an email address (Konzept 17 §3.6: "Code
/// senden" stays off until then). The server has the last word.
bool looksLikeEmail(String value) => _emailShape.hasMatch(value.trim());

/// Normalises a typed address: trimmed, lower case (iOS adds a trailing
/// space after autocomplete).
String normalizeEmail(String value) => value.trim().toLowerCase();

/// The three rules of a new password (Konzept 17 §4.4).
enum PasswordRule { length, upper, digit }

/// Whether [password] meets [rule].
bool passwordRuleMet(PasswordRule rule, String password) => switch (rule) {
  PasswordRule.length => password.length >= 8,
  PasswordRule.upper => password.contains(RegExp(r'[A-ZÄÖÜ]')),
  PasswordRule.digit => password.contains(RegExp(r'[0-9]')),
};

/// Whether [password] meets every [PasswordRule].
bool passwordRulesMet(String password) =>
    PasswordRule.values.every((r) => passwordRuleMet(r, password));
