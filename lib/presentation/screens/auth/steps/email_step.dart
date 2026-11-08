import 'package:flutter/widgets.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// E-Mail-Adresse (Konzept 17 §3.6): sends the 6-digit code and calls
/// [onCodeSent] with the address. Placeholder until the "Konto" part of A7
/// fills it; the constructor is the contract with the flow.
class EmailStep extends StatelessWidget {
  const EmailStep({
    super.key,
    this.mode = AccountStepMode.signUp,
    required this.onCodeSent,
    this.onBack,
    this.progress,
  });

  final AccountStepMode mode;
  final ValueChanged<String> onCodeSent;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  Widget build(BuildContext context) => OnboardingStepPage(
    title: 'E-Mail',
    progress: progress,
    onBack: onBack,
    primaryAction: AppButton.primary(
      label: 'Code',
      onPressed: () => onCodeSent(''),
      expand: true,
    ),
  );
}
