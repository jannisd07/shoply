import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';

enum SocialAuthProvider { google, apple }

/// Single Google / Apple sign-in flow used by welcome, login and signup.
///
/// On success new accounts go to the name prompt, returning users to /home.
/// The router is captured before awaiting because the auth-state redirect
/// can dispose the calling screen (e.g. /welcome) mid-flow. Push-token sync
/// is not done here: main.dart already saves it on every signedIn event.
///
/// [onError] receives a localized message; a user cancel reports nothing.
Future<void> signInWithSocialProvider(
  BuildContext context,
  SocialAuthProvider provider, {
  required ValueChanged<String> onError,
}) async {
  final router = GoRouter.of(context);
  try {
    final success = switch (provider) {
      SocialAuthProvider.google =>
        await SupabaseService.instance.signInWithGoogle(),
      SocialAuthProvider.apple =>
        await SupabaseService.instance.signInWithApple(),
    };
    if (success) routeAfterSignIn(router);
  } catch (e) {
    debugPrint('❌ [SOCIAL_AUTH] ${provider.name} sign-in failed: $e');
    if (!context.mounted) return;
    final message = socialAuthErrorMessage(context, e);
    if (message != null) onError(message);
  }
}

/// Sends a freshly created account to the name prompt, everyone else home.
void routeAfterSignIn(GoRouter router) {
  final user = SupabaseService.instance.currentUser;
  final createdAt = user != null ? DateTime.tryParse(user.createdAt) : null;
  final isNewAuthUser = createdAt != null &&
      DateTime.now().difference(createdAt.toLocal()).inMinutes < 3;
  router.go(isNewAuthUser ? '/name-prompt?new=1' : '/home');
}
