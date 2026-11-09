import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/widgets/email_code_page.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';

/// E-Mail-Adresse (Konzept 17 §3.6): sends the 6-digit code and calls
/// [onCodeSent] with the address. The same code signs in to an existing
/// account and creates a new one (F-17-01, no password needed).
///
/// The constructor is the contract with the flow; [initialEmail] and
/// [onPassword] ("Mit Passwort anmelden" under the main action) are
/// optional additions. Without [initialEmail] the field starts with the
/// address typed last in an account screen.
class EmailStep extends ConsumerWidget {
  const EmailStep({
    super.key,
    this.mode = AccountStepMode.signUp,
    required this.onCodeSent,
    this.onBack,
    this.progress,
    this.initialEmail,
    this.onPassword,
  });

  final AccountStepMode mode;
  final ValueChanged<String> onCodeSent;
  final VoidCallback? onBack;
  final Widget? progress;
  final String? initialEmail;
  final VoidCallback? onPassword;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmailCodePage(
    title: context.tr('auth_email_title'),
    message: context.tr('auth_email_message'),
    purpose: CodePurpose.signIn,
    initialEmail: initialEmail ?? ref.read(authEmailDraftProvider),
    onCodeSent: onCodeSent,
    onBack: onBack,
    progress: progress,
    onPassword: onPassword,
  );
}
