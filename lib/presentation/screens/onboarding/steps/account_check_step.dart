import 'package:flutter/widgets.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// After a sign-in the flow asks the account whether it is new or set up
/// (Konzept 17 §3.5, "Nach der Anmeldung"). This step shows while that
/// answer is missing: on a cold start with a session, and when the check
/// failed ("Deine Auswahl ist noch nicht gespeichert. Erneut versuchen").
/// The sign-in itself stays; a retry only asks again.
class AccountCheckStep extends StatefulWidget {
  const AccountCheckStep({
    super.key,
    required this.check,
    this.failed = false,
    this.autoStart = false,
  });

  /// Asks again; false when it failed.
  final Future<bool> Function() check;

  /// The first attempt failed already.
  final bool failed;

  /// Starts the check right away (cold start).
  final bool autoStart;

  @override
  State<AccountCheckStep> createState() => _AccountCheckStepState();
}

class _AccountCheckStepState extends State<AccountCheckStep> {
  late bool _failed = widget.failed;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  Future<void> _run() async {
    if (_working || !mounted) return;
    setState(() => _working = true);
    final ok = await widget.check();
    if (!mounted) return;
    setState(() {
      _working = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepPage(
      title: context.tr('onb_check_title'),
      message: context.tr('onb_check_sentence'),
      status: _failed && !_working
          ? StatusRow(
              kind: StatusKind.failed,
              text: context.tr('onb_check_failed'),
            )
          : null,
      primaryAction: AppButton.primary(
        label: context.tr('retry'),
        onPressed: _run,
        working: _working,
        workingLabel: context.tr('onb_check_working'),
        size: AppButtonSize.large,
        expand: true,
      ),
    );
  }
}
