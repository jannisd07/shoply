import 'package:flutter/widgets.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// Mit Passwort anmelden (Konzept 17 §4.2, `/login?method=password`): calls
/// [onSignedIn] once a session exists. Placeholder until the "Konto" part of
/// A7 fills it; the constructor is the contract with the flow.
class PasswordLoginScreen extends StatelessWidget {
  const PasswordLoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) => OnboardingStepPage(
    title: 'Password',
    onBack: () => Navigator.of(context).maybePop(),
    primaryAction: AppButton.primary(
      label: 'OK',
      onPressed: onSignedIn,
      expand: true,
    ),
  );
}

/// Passwort vergessen (Konzept 17 §4.3, `/login?method=reset`): sends the
/// reset code; the new password follows in `ResetPasswordScreen` (§4.4).
/// Placeholder until the "Konto" part of A7 fills it.
class ResetPasswordRequestScreen extends StatelessWidget {
  const ResetPasswordRequestScreen({super.key});

  @override
  Widget build(BuildContext context) => OnboardingStepPage(
    title: 'Reset',
    onBack: () => Navigator.of(context).maybePop(),
    primaryAction: AppButton.primary(
      label: 'OK',
      onPressed: () {},
      expand: true,
    ),
  );
}
