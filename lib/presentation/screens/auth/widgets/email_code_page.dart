import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// What an email code is for: signing in (and creating the account,
/// Konzept 17 §3.6) or resetting the password (§4.3).
enum CodePurpose { signIn, passwordReset }

/// The address screen shared by "Deine E-Mail-Adresse" (§3.6) and
/// "Passwort zurücksetzen" (§4.3): one capsule field, "Code senden" (off
/// until the input looks like an address), errors under the field or as a
/// status line.
///
/// For [CodePurpose.passwordReset] an unknown address is answered like a
/// known one (no hint whether an account exists, §4.3).
class EmailCodePage extends ConsumerStatefulWidget {
  const EmailCodePage({
    super.key,
    required this.title,
    required this.message,
    required this.purpose,
    required this.onCodeSent,
    this.initialEmail,
    this.onBack,
    this.progress,
    this.onPassword,
  });

  final String title;
  final String message;
  final CodePurpose purpose;
  final ValueChanged<String> onCodeSent;
  final String? initialEmail;
  final VoidCallback? onBack;
  final Widget? progress;

  /// Shows "Mit Passwort anmelden" under the main action.
  final VoidCallback? onPassword;

  @override
  ConsumerState<EmailCodePage> createState() => _EmailCodePageState();
}

class _EmailCodePageState extends ConsumerState<EmailCodePage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _sending = false;
  bool _fieldError = false;
  AuthErrorKind? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String _) {
    final draft = normalizeEmail(_controller.text);
    ref.read(authEmailDraftProvider.notifier).state = draft;
    if (_fieldError || _status != null) {
      setState(() {
        _fieldError = false;
        if (_status != AuthErrorKind.offline) _status = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _send() async {
    final email = normalizeEmail(_controller.text);
    if (!looksLikeEmail(email) || _sending) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _status = AuthErrorKind.offline);
      AvoHaptics.error();
      return;
    }
    final gateway = ref.read(authGatewayProvider);
    setState(() {
      _sending = true;
      _status = null;
      _fieldError = false;
    });
    try {
      if (widget.purpose == CodePurpose.signIn) {
        await gateway.sendSignInCode(email);
      } else {
        await gateway.sendPasswordResetCode(email);
      }
    } catch (e) {
      final unknownAccount =
          widget.purpose == CodePurpose.passwordReset &&
          isUnknownAccountError(e);
      if (!unknownAccount) {
        debugPrint('[AUTH] sending the code failed: $e');
        if (!mounted) return;
        final kind = classifyAuthError(e, attempt: AuthAttempt.sendCode);
        setState(() {
          _sending = false;
          if (kind == AuthErrorKind.emailInvalid) {
            _fieldError = true;
          } else {
            _status = kind;
          }
        });
        AvoHaptics.error();
        return;
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    widget.onCodeSent(email);
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider);
    final valid = looksLikeEmail(_controller.text);
    final status = _status ?? (offline ? AuthErrorKind.offline : null);

    final primary = AppButton.primary(
      label: context.tr('auth_send_code'),
      onPressed: valid ? _send : null,
      working: _sending,
      workingLabel: context.tr('auth_sending'),
      size: AppButtonSize.large,
      expand: true,
    );

    return OnboardingStepPage(
      title: widget.title,
      message: widget.message,
      progress: widget.progress,
      onBack: widget.onBack,
      primaryAction: widget.onPassword == null
          ? primary
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primary,
                Center(
                  child: AppButton.plain(
                    label: context.tr('auth_use_password'),
                    onPressed: widget.onPassword,
                  ),
                ),
              ],
            ),
      status: status == null
          ? null
          : AuthStatusLine.forError(
              context,
              status,
              attempt: AuthAttempt.sendCode,
              offlineText: context.tr('auth_offline_send_code'),
              onAction: _send,
            ),
      children: [
        AuthTextField(
          controller: _controller,
          label: context.tr('auth_email_label'),
          placeholder: context.tr('auth_email_placeholder'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          autofocus: true,
          error: _fieldError,
          onChanged: _changed,
          onSubmitted: (_) => _send(),
        ),
        if (_fieldError) FieldErrorLine(context.tr('auth_err_email_invalid')),
      ],
    );
  }
}
