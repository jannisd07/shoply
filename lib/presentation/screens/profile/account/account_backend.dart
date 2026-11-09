
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend_supabase.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// How the account signs in (Konzept 18 §7.1 "Angemeldet mit").
enum SignInMethod { apple, google, email }

/// The sign-in method from Supabase's `app_metadata` (`provider`, the way
/// the account was created). Anything that is not Apple or Google is an
/// email account (code or password).
SignInMethod signInMethodFromMetadata(Map<String, dynamic>? appMetadata) {
  final provider = appMetadata?['provider'];
  return switch (provider) {
    'apple' => SignInMethod.apple,
    'google' => SignInMethod.google,
    _ => SignInMethod.email,
  };
}

/// The signed-in account as the account pages need it, available in the
/// first frame (from the restored session, no request).
@immutable
class AccountIdentity {
  const AccountIdentity({
    required this.userId,
    required this.email,
    required this.method,
  });

  final String userId;
  final String email;
  final SignInMethod method;

  @override
  bool operator ==(Object other) =>
      other is AccountIdentity &&
      other.userId == userId &&
      other.email == email &&
      other.method == method;

  @override
  int get hashCode => Object.hash(userId, email, method);
}

/// The signed-in account, or null when signed out. Follows every auth event
/// (an email change arrives as `userUpdated`). Overridden in tests.
final accountIdentityProvider = Provider<AccountIdentity?>((ref) {
  final user =
      ref.watch(authUserProvider).valueOrNull ??
      SupabaseService.instance.currentUser;
  if (user == null) return null;
  return AccountIdentity(
    userId: user.id,
    email: user.email ?? '',
    method: signInMethodFromMetadata(user.appMetadata),
  );
});

/// Name and photo of the account (Konzept 18 §4.4): the name from the
/// device cache in the first frame, then from `users`; the photo URL once
/// the profile is loaded (the image itself comes from the disk cache).
@immutable
class AccountProfile {
  const AccountProfile({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      other is AccountProfile &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(displayName, avatarUrl);
}

/// The profile of the signed-in account. Overridden in tests.
final accountProfileProvider = Provider<AccountProfile>((ref) {
  final cached = ref.watch(cachedUserProfileProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;
  return AccountProfile(
    displayName: user?.displayName ?? cached?.displayName,
    avatarUrl: user?.avatarUrl,
  );
});

/// Whether an email account has a password (Konzept 18 §7.1, F-17-01).
enum PasswordState { unknown, set, notSet }

/// Writes name and photo (Profil bearbeiten). Implementations refresh the
/// profile providers after a change.
abstract class ProfileEditor {
  /// `users.display_name` and the auth metadata.
  Future<void> saveName(String name);

  /// Uploads a square JPEG to the bucket `profile-pictures`; returns the URL.
  Future<String> uploadPhoto(String filePath);

  /// Deletes the stored photo and clears `users.avatar_url`.
  Future<void> removePhoto();
}

final profileEditorProvider = Provider<ProfileEditor>(
  (ref) => SupabaseProfileEditor(ref),
);

/// Password and email of an email account (Konzept 18 §7.1).
abstract class AccountSecurityService {
  /// Asks the server; [PasswordState.unknown] when it cannot tell.
  Future<PasswordState> passwordState();

  /// Saves a new password for the signed-in account.
  Future<void> updatePassword(String password);

  /// Sends the 6-digit code to [newEmail].
  Future<void> requestEmailChange(String newEmail);

  /// Checks the code; the account has the new address afterwards.
  Future<void> verifyEmailChange(String newEmail, String code);
}

final accountSecurityProvider = Provider<AccountSecurityService>(
  (ref) => SupabaseAccountSecurity(ref),
);

/// The password state of the signed-in account, asked once per account.
final passwordStateProvider = FutureProvider<PasswordState>((ref) async {
  final identity = ref.watch(accountIdentityProvider);
  if (identity == null || identity.method != SignInMethod.email) {
    return PasswordState.unknown;
  }
  return ref.watch(accountSecurityProvider).passwordState();
});

/// A password was saved in this session (shows "Festgelegt" at once).
final passwordSavedProvider = StateProvider<bool>((ref) {
  ref.watch(accountIdentityProvider.select((i) => i?.userId));
  return false;
});

/// A fresh sign-in, the condition for deleting the account (Konzept 18
/// §7.3: under 5 minutes old). For Apple it carries the authorization code
/// the server needs to revoke the Apple token.
@immutable
class ReauthProof {
  const ReauthProof({
    required this.method,
    required this.at,
    this.appleAuthorizationCode,
  });

  final SignInMethod method;
  final DateTime at;
  final String? appleAuthorizationCode;

  /// How long a proof counts as fresh.
  static const Duration maxAge = Duration(minutes: 5);

  bool isFresh(DateTime now) => now.difference(at) < maxAge;
}

/// The person confirmed with a different account than the one to delete.
class AccountMismatchException implements Exception {
  const AccountMismatchException();
}

/// `delete-account` answered with an error; nothing was deleted.
class AccountDeletionFailed implements Exception {
  const AccountDeletionFailed(this.reason);

  final String reason;

  @override
  String toString() => 'AccountDeletionFailed($reason)';
}

/// Everything "Konto löschen" needs from the server (Konzept 18 §7.3,
/// E18-09). The Edge Function `delete-account` does not exist yet; the
/// default implementation calls it and fails until it is deployed. Tests
/// override [accountDeletionProvider] with a fake.
abstract class AccountDeletionService {
  /// Apple or Google confirmation sheet. Null when the person closed it;
  /// throws [AccountMismatchException] for another account.
  Future<ReauthProof?> confirmWithProvider(SignInMethod method);

  /// Email accounts: sends a code to [email].
  Future<void> sendCode(String email);

  /// Email accounts: checks the code.
  Future<ReauthProof> verifyCode(String email, String code);

  /// Deletes the account in one server call. Throws when anything failed;
  /// then nothing was deleted (one transaction).
  Future<void> deleteAccount(ReauthProof proof);
}

final accountDeletionProvider = Provider<AccountDeletionService>(
  (ref) => SupabaseAccountDeletion(ref),
);

/// Signing out and the local clean-up (Konzept 18 §7.2, K18-09).
abstract class AccountSession {
  /// Removes this device's push token, signs out (locally even when the
  /// server is not reachable) and deletes the account-bound local values.
  Future<void> signOut();

  /// After `delete-account`: drops the session locally and deletes the
  /// account-bound local values.
  Future<void> finishDeletion();
}

final accountSessionProvider = Provider<AccountSession>(
  (ref) => DefaultAccountSession(ref),
);

/// The clock of the account pages (proof age). Tests move it.
final accountClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Apple's subscription management ("Abo verwalten", Konzept 18 §7.3).
/// Overridden in tests.
final manageSubscriptionsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await launchUrl(
        Uri.parse('https://apps.apple.com/account/subscriptions'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[ACCOUNT] subscriptions not opened: ${e.runtimeType}');
    }
  },
);
