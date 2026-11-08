import 'package:flutter/widgets.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// Code eingeben (Konzept 17 §3.7): checks the code sent to [email] and
/// calls [onVerified] once a session exists. Placeholder until the "Konto"
/// part of A7 fills it; the constructor is the contract with the flow.
class CodeStep extends StatelessWidget {
  const CodeStep({
    super.key,
    this.mode = AccountStepMode.signUp,
    required this.email,
    required this.onVerified,
    this.onBack,
    this.progress,
  });

  final AccountStepMode mode;
  final String email;
  final VoidCallback onVerified;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  Widget build(BuildContext context) => OnboardingStepPage(
    title: 'Code',
    progress: progress,
    onBack: onBack,
    primaryAction: AppButton.primary(
      label: 'OK',
      onPressed: onVerified,
      expand: true,
    ),
  );
}
