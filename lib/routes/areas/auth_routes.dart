import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/auth/password_login_screen.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_flow.dart';
import 'package:shoply/presentation/screens/onboarding/steps/join_step.dart';
import 'package:shoply/routes/route_paths.dart';

/// Onboarding and sign-in (Teil A, Konzept 17). Top-level routes without the
/// tab bar; every entry runs through [OnboardingFlow], which decides after a
/// sign-in whether the account is new or set up.
final List<RouteBase> authRoutes = [
  // First start, or the step a run stopped at (`?step=` is informational;
  // the flow resumes from `onb_step`).
  GoRoute(
    path: RoutePaths.onboarding,
    name: 'onboarding',
    builder: (context, state) => const OnboardingFlow(),
  ),

  // Willkommen in the variant "Anmelden" (after signing out, §3.2).
  GoRoute(
    path: RoutePaths.welcome,
    name: 'welcome',
    builder: (context, state) =>
        const OnboardingFlow(entry: OnboardingEntry.welcomeBack),
  ),

  // Anmelden (§4.1); `?method=password` (§4.2), `?method=reset` (§4.3).
  GoRoute(
    path: RoutePaths.login,
    name: 'login',
    builder: (context, state) => switch (state.uri.queryParameters['method']) {
      'password' => const OnboardingFlow(entry: OnboardingEntry.loginPassword),
      'reset' => const ResetPasswordRequestScreen(),
      _ => const OnboardingFlow(entry: OnboardingEntry.login),
    },
  ),

  // The e-mail step of a new account (§3.6).
  GoRoute(
    path: RoutePaths.signup,
    name: 'signup',
    builder: (context, state) =>
        const OnboardingFlow(entry: OnboardingEntry.signup),
  ),

  // Neues Passwort (§4.4), reachable with and without a session.
  GoRoute(
    path: RoutePaths.resetPassword,
    name: 'reset-password',
    builder: (context, state) => const ResetPasswordScreen(),
  ),

  // Name for a signed-in account that is not set up yet (§3.8).
  GoRoute(
    path: RoutePaths.namePrompt,
    name: 'name-prompt',
    builder: (context, state) =>
        const OnboardingFlow(entry: OnboardingEntry.namePrompt),
  ),

  // An invitation by share code for a signed-in person (§5.1). Without a
  // session the router remembers it as `pending_link` first.
  GoRoute(
    path: '${RoutePaths.join}/:code',
    name: 'join-code',
    builder: (context, state) =>
        JoinLinkScreen(code: state.pathParameters['code'] ?? ''),
  ),
];
