import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// A [StatusRow] for the `status` slot of `OnboardingStepPage` (under the
/// sentence, full width), with the texts of Konzept 17 §4.6.
class AuthStatusLine extends StatelessWidget {
  const AuthStatusLine({
    super.key,
    required this.kind,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  /// An offline line or an error line for [kind].
  factory AuthStatusLine.forError(
    BuildContext context,
    AuthErrorKind kind, {
    Key? key,
    AuthAttempt? attempt,
    String? offlineText,
    bool appleAvailable = true,
    VoidCallback? onAction,
  }) {
    if (kind == AuthErrorKind.offline) {
      return AuthStatusLine(
        key: key,
        kind: StatusKind.offline,
        text: offlineText ?? context.tr('auth_err_offline'),
      );
    }
    final message = authErrorMessage(
      context,
      kind,
      attempt: attempt,
      appleAvailable: appleAvailable,
    );
    return AuthStatusLine(
      key: key,
      kind: StatusKind.failed,
      text: message?.text ?? context.tr('auth_err_unknown'),
      actionLabel: onAction == null ? null : message?.actionLabel,
      onAction: message?.actionLabel == null ? null : onAction,
    );
  }

  final StatusKind kind;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AvoSpacing.s),
    child: StatusRow(
      kind: kind,
      text: text,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}
