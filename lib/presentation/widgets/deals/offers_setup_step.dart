import 'package:flutter/widgets.dart';

/// The offers step of the onboarding: region and favourite markets
/// (contract `b_slots.dart`). Calls [onDone] once the person finished or
/// skipped it.
///
/// Shell until S4: renders nothing and calls [onDone] right after the first
/// frame, so the onboarding moves on by itself.
class OffersSetupStep extends StatefulWidget {
  const OffersSetupStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OffersSetupStep> createState() => _OffersSetupStepState();
}

class _OffersSetupStepState extends State<OffersSetupStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
