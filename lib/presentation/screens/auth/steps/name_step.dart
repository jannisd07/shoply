import 'package:flutter/widgets.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// Name (Konzept 17 §3.8): writes `users.display_name` (targeted update) and
/// calls [onDone]; [onSkip] keeps the name empty. No back button. Placeholder
/// until the "Konto" part of A7 fills it; the constructor is the contract
/// with the flow.
class NameStep extends StatelessWidget {
  const NameStep({super.key, required this.onDone, this.onSkip, this.progress});

  final VoidCallback onDone;
  final VoidCallback? onSkip;
  final Widget? progress;

  @override
  Widget build(BuildContext context) => OnboardingStepPage(
    title: 'Name',
    progress: progress,
    onSkip: onSkip,
    primaryAction: AppButton.primary(
      label: 'OK',
      onPressed: onDone,
      expand: true,
    ),
  );
}
