import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/auth/login_screen.dart';
import 'package:shoply/presentation/screens/auth/name_prompt_screen.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/signup_screen.dart';
import 'package:shoply/presentation/screens/auth/welcome_screen.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Onboarding and sign-in (Teil A). Top-level routes without the tab bar.
final List<RouteBase> authRoutes = [
  // Onboarding (first-time users)
  GoRoute(
    path: RoutePaths.onboarding,
    name: 'onboarding',
    builder: (context, state) => const OnboardingScreen(),
  ),

  // Welcome / Auth Entry (returning users who completed onboarding)
  GoRoute(
    path: RoutePaths.welcome,
    name: 'welcome',
    builder: (context, state) => const WelcomeScreen(),
  ),

  GoRoute(
    path: RoutePaths.login,
    name: 'login',
    builder: (context, state) => const LoginScreen(),
  ),

  GoRoute(
    path: RoutePaths.signup,
    name: 'signup',
    builder: (context, state) => const SignUpScreen(),
  ),

  GoRoute(
    path: RoutePaths.resetPassword,
    name: 'reset-password',
    builder: (context, state) => const ResetPasswordScreen(),
  ),

  // Name prompt route (after login if no display name)
  GoRoute(
    path: RoutePaths.namePrompt,
    name: 'name-prompt',
    builder: (context, state) => const NamePromptScreen(),
  ),
];
