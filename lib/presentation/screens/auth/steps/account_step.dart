import 'package:flutter/widgets.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// Konto (Konzept 17 §3.5) and Anmelden (§4.1): Apple, Google, E-Mail.
/// Calls [onSignedIn] once a session exists; the flow decides whether the
/// account is new or already set up. Placeholder until the "Konto" part of
/// A7 fills it; the constructor is the contract with the flow.
class AccountStep extends StatelessWidget {
  const AccountStep({
    super.key,
    this.mode = AccountStepMode.signUp,
    required this.onEmail,
    required this.onSignedIn,
    this.onPassword,
    this.onBack,
    this.progress,
  });

  final AccountStepMode mode;

  /// "Mit E-Mail fortfahren": the flow pushes [EmailStep].
  final VoidCallback onEmail;

  /// A Supabase session exists.
  final VoidCallback onSignedIn;

  /// Login mode only: "Mit Passwort anmelden".
  final VoidCallback? onPassword;

  final VoidCallback? onBack;
  final Widget? progress;

  @override
  Widget build(BuildContext context) => OnboardingStepPage(
    title: 'Account',
    progress: progress,
    onBack: onBack,
    primaryAction: AppButton.primary(
      label: 'E-Mail',
      onPressed: onEmail,
      expand: true,
    ),
  );
}
