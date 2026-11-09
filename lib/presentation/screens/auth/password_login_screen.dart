import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/steps/code_step.dart';
import 'package:shoply/presentation/screens/auth/steps/email_step.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/screens/auth/widgets/email_code_page.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/routes/route_paths.dart';

/// Labels wider than this share of the row stack above their field.
const double _kMaxLabelShare = 0.4;

/// Mit Passwort anmelden (Konzept 17 §4.2, `/login?method=password`): for
/// existing accounts with a password. E-Mail and Passwort in one section
/// (an `AutofillGroup`, so iOS offers the keychain and saves the login),
/// "Passwort vergessen?", "Anmelden", "Stattdessen Code per E-Mail".
///
/// Calls [onSignedIn] once a session exists. Wrong data or an unconfirmed
/// address offer "Code senden", which sends a code to the typed address and
/// shows the code step; its success also ends in [onSignedIn]. The
/// constructor is the contract with the flow; [onBack] is an optional
/// addition (default: pop).
class PasswordLoginScreen extends ConsumerStatefulWidget {
  const PasswordLoginScreen({super.key, required this.onSignedIn, this.onBack});

  final VoidCallback onSignedIn;
  final VoidCallback? onBack;

  @override
  ConsumerState<PasswordLoginScreen> createState() =>
      _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends ConsumerState<PasswordLoginScreen> {
  late final TextEditingController _email = TextEditingController(
    text: ref.read(authEmailDraftProvider),
  );
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _working = false;
  bool _sendingCode = false;
  AuthErrorKind? _status;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _ready =>
      looksLikeEmail(_email.text) && _password.text.isNotEmpty;

  void _changed() {
    ref.read(authEmailDraftProvider.notifier).state = normalizeEmail(
      _email.text,
    );
    setState(() {
      if (_status != AuthErrorKind.offline) _status = null;
    });
  }

  Future<void> _signIn() async {
    if (!_ready || _working) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _status = AuthErrorKind.offline);
      AvoHaptics.error();
      return;
    }
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      await ref
          .read(authGatewayProvider)
          .signInWithPassword(normalizeEmail(_email.text), _password.text);
      if (!mounted) return;
      // Lets iOS offer to save the login in the keychain.
      TextInput.finishAutofillContext();
      widget.onSignedIn();
    } catch (e) {
      debugPrint('[AUTH] password sign-in failed: $e');
      if (!mounted) return;
      setState(() {
        _working = false;
        _status = classifyAuthError(e, attempt: AuthAttempt.password);
      });
      AvoHaptics.error();
    }
  }

  /// "Code senden" after wrong data: a code to the typed address.
  Future<void> _sendCode() async {
    final email = normalizeEmail(_email.text);
    if (!looksLikeEmail(email) || _sendingCode) return;
    setState(() => _sendingCode = true);
    try {
      await ref.read(authGatewayProvider).sendSignInCode(email);
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _status = null;
      });
      _pushCode(email);
    } catch (e) {
      debugPrint('[AUTH] sending the code failed: $e');
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _status = classifyAuthError(e, attempt: AuthAttempt.sendCode);
      });
      AvoHaptics.error();
    }
  }

  void _pushCode(String email) {
    final navigator = Navigator.of(context);
    navigator.push(
      CupertinoPageRoute<void>(
        builder: (context) => CodeStep(
          mode: AccountStepMode.login,
          email: email,
          onBack: navigator.pop,
          onVerified: widget.onSignedIn,
        ),
      ),
    );
  }

  /// "Stattdessen Code per E-Mail": the address step, then the code.
  void _useCode() {
    final navigator = Navigator.of(context);
    navigator.push(
      CupertinoPageRoute<void>(
        builder: (context) => EmailStep(
          mode: AccountStepMode.login,
          initialEmail: normalizeEmail(_email.text),
          onBack: navigator.pop,
          onCodeSent: _pushCode,
        ),
      ),
    );
  }

  void _forgot() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) =>
            ResetPasswordRequestScreen(initialEmail: normalizeEmail(_email.text)),
      ),
    );
  }

  Widget? _statusLine(BuildContext context, bool offline) {
    final status = _status ?? (offline ? AuthErrorKind.offline : null);
    if (status == null) return null;
    final codeAction =
        status == AuthErrorKind.invalidCredentials ||
        status == AuthErrorKind.emailNotConfirmed;
    return AuthStatusLine.forError(
      context,
      status,
      attempt: AuthAttempt.password,
      onAction: codeAction
          ? _sendCode
          : status == AuthErrorKind.unknown
          ? _signIn
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider);
    final status = _statusLine(context, offline);
    final showLabel = context.tr(
      _obscure ? 'auth_show_password' : 'auth_hide_password',
    );

    return OnboardingStepPage(
      title: context.tr('auth_use_password'),
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      primaryAction: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: context.tr('auth_login_title'),
            onPressed: _ready ? _signIn : null,
            working: _working,
            workingLabel: context.tr('auth_signing_in'),
            size: AppButtonSize.large,
            expand: true,
          ),
          Center(
            child: AppButton.plain(
              label: context.tr('auth_use_code_instead'),
              onPressed: _working ? null : _useCode,
            ),
          ),
        ],
      ),
      status: status,
      children: [
        AutofillGroup(
          child: FullBleed(
            child: _FieldSection(
              rows: [
                _FieldRowData(
                  label: context.tr('auth_email_field'),
                  field: _InsetField(
                    controller: _email,
                    label: context.tr('auth_email_field'),
                    placeholder: context.tr('auth_email_placeholder'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autofocus: _email.text.isEmpty,
                    onChanged: (_) => _changed(),
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                ),
                _FieldRowData(
                  label: context.tr('auth_password_field'),
                  field: _InsetField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    label: context.tr('auth_password_field'),
                    placeholder: context.tr('auth_password_placeholder'),
                    obscureText: _obscure,
                    textInputAction: TextInputAction.go,
                    autofillHints: const [AutofillHints.password],
                    autofocus: _email.text.isNotEmpty,
                    onChanged: (_) => _changed(),
                    onSubmitted: (_) => _signIn(),
                  ),
                  trailing: FieldSymbolButton(
                    icon: _obscure ? AvoIcons.eye : AvoIcons.eyeSlash,
                    semanticLabel: showLabel,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.plain(
            label: context.tr('auth_forgot_password'),
            onPressed: _working ? null : _forgot,
          ),
        ),
      ],
    );
  }
}

/// Passwort vergessen (Konzept 17 §4.3, `/login?method=reset`): sends the
/// reset code to the address from §4.2 (prefilled) and shows "Code zum
/// Zurücksetzen"; after the code comes "Neues Passwort" (§4.4).
///
/// An unknown address gets the same answer as a known one. The optional
/// [initialEmail] defaults to the address typed last; [onCodeVerified]
/// defaults to opening `/reset-password`.
class ResetPasswordRequestScreen extends ConsumerWidget {
  const ResetPasswordRequestScreen({
    super.key,
    this.initialEmail,
    this.onCodeVerified,
  });

  final String? initialEmail;
  final VoidCallback? onCodeVerified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    void openNewPassword() {
      if (onCodeVerified != null) {
        onCodeVerified!();
      } else if (router != null) {
        router.go(RoutePaths.resetPassword);
      } else {
        navigator.pushReplacement(
          CupertinoPageRoute<void>(
            builder: (context) => const ResetPasswordScreen(),
          ),
        );
      }
    }

    return EmailCodePage(
      title: context.tr('auth_reset_title'),
      message: context.tr('auth_reset_message'),
      purpose: CodePurpose.passwordReset,
      initialEmail: initialEmail ?? ref.read(authEmailDraftProvider),
      onBack: () => navigator.maybePop(),
      onCodeSent: (email) => navigator.push(
        CupertinoPageRoute<void>(
          builder: (context) => CodeStep(
            mode: AccountStepMode.login,
            purpose: CodePurpose.passwordReset,
            email: email,
            onBack: navigator.pop,
            onVerified: openNewPassword,
          ),
        ),
      ),
    );
  }
}

@immutable
class _FieldRowData {
  const _FieldRowData({required this.label, required this.field, this.trailing});

  final String label;
  final Widget field;
  final Widget? trailing;
}

/// The white section with one row per field (Konzept 17 §4.2): label and
/// field side by side, the fields aligned; stacked from AX1 or when a label
/// takes more than 40 % of the row.
class _FieldSection extends StatelessWidget {
  const _FieldSection({required this.rows});

  final List<_FieldRowData> rows;

  @override
  Widget build(BuildContext context) {
    final style = context.text(AvoTextStyle.body);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var labelWidth = 0.0;
        for (final row in rows) {
          final painter = TextPainter(
            text: TextSpan(text: row.label, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          labelWidth = math.max(labelWidth, painter.width);
          painter.dispose();
        }
        final rowWidth = constraints.maxWidth - 2 * AvoSpacing.screen;
        final stacked =
            context.isAccessibilityText ||
            labelWidth > rowWidth * _kMaxLabelShare;
        return InsetSection(
          children: [
            for (final row in rows)
              _FieldRow(
                data: row,
                labelWidth: labelWidth.ceilToDouble(),
                stacked: stacked,
              ),
          ],
        );
      },
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.data,
    required this.labelWidth,
    required this.stacked,
  });

  final _FieldRowData data;
  final double labelWidth;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final label = ExcludeSemantics(
      child: Text(data.label, style: context.text(AvoTextStyle.body)),
    );
    final field = Row(
      children: [
        Expanded(child: data.field),
        ?data.trailing,
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kAuthFieldMinHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: AvoSpacing.l,
          end: data.trailing == null ? AvoSpacing.l : AvoSpacing.xs,
          top: stacked ? AvoSpacing.s : 0,
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [label, field],
              )
            : Row(
                children: [
                  SizedBox(width: labelWidth, child: label),
                  const SizedBox(width: AvoSpacing.l),
                  Expanded(child: field),
                ],
              ),
      ),
    );
  }
}

/// A plain field inside a section row (no capsule; the row is the surface).
class _InsetField extends StatelessWidget {
  const _InsetField({
    required this.controller,
    required this.label,
    this.focusNode,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = context.typography.lineHeightOf(AvoTextStyle.body);
    final vertical = math.max(0.0, (kAuthFieldMinHeight - line) / 2);
    return Semantics(
      label: label,
      textField: true,
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        placeholderStyle: context.text(
          AvoTextStyle.body,
          color: colors.placeholder,
        ),
        style: context.text(AvoTextStyle.body),
        cursorColor: colors.tint,
        decoration: null,
        padding: EdgeInsets.symmetric(vertical: vertical),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autofocus: autofocus,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        maxLines: 1,
      ),
    );
  }
}
