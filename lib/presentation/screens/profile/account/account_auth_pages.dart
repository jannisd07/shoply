import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/steps/code_step.dart'
    show CodeInputFormatter;
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Rule symbols next to 15 pt text at the default size (A7 Neues Passwort).
const double _kRuleSymbol = 18;
const double _kSubheadAtLarge = 15;

/// Passwort festlegen / ändern from Konto (Konzept 18 §7.1, F-17-01): the
/// A7 step frame and field with the three rules of Konzept 17 §4.4. Back
/// leaves without a question (nothing is saved until "Passwort speichern").
/// Pops with true once the password is saved.
///
/// `ResetPasswordScreen` is not reused because its "Abbrechen" signs out
/// (A8 report: an option there would remove this copy of the rule rows).
class AccountPasswordScreen extends ConsumerStatefulWidget {
  const AccountPasswordScreen({super.key, this.hasPassword = false});

  /// "Passwort ändern" instead of "Passwort festlegen".
  final bool hasPassword;

  @override
  ConsumerState<AccountPasswordScreen> createState() =>
      _AccountPasswordScreenState();
}

class _AccountPasswordScreenState extends ConsumerState<AccountPasswordScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  AuthErrorKind? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _controller.text;
    if (!passwordRulesMet(password) || _saving) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _status = AuthErrorKind.offline);
      AvoHaptics.error();
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await ref.read(accountSecurityProvider).updatePassword(password);
    } catch (e) {
      debugPrint('[ACCOUNT] password not saved: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = classifyAuthError(e, attempt: AuthAttempt.newPassword);
      });
      AvoHaptics.error();
      return;
    }
    // Lets iOS save the new password in the keychain.
    TextInput.finishAutofillContext();
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider);
    final password = _controller.text;
    final status = _status ?? (offline ? AuthErrorKind.offline : null);
    return AutofillGroup(
      child: OnboardingStepPage(
        title: context.tr(
          widget.hasPassword
              ? 'acct_password_title_change'
              : 'acct_password_title_set',
        ),
        message: context.tr('acct_password_message'),
        onBack: _saving ? null : () => Navigator.of(context).pop(false),
        primaryAction: AppButton.primary(
          label: context.tr('auth_save_password'),
          onPressed: passwordRulesMet(password) ? _save : null,
          working: _saving,
          workingLabel: context.tr('auth_saving'),
          size: AppButtonSize.large,
          expand: true,
        ),
        status: status == null
            ? null
            : AuthStatusLine.forError(
                context,
                status,
                attempt: AuthAttempt.newPassword,
                offlineText: context.tr('auth_offline_save'),
                onAction: status == AuthErrorKind.unknown ? _save : null,
              ),
        children: [
          AuthTextField(
            controller: _controller,
            label: context.tr('auth_new_password_title'),
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            autofocus: true,
            onChanged: (_) => setState(() {
              if (_status != AuthErrorKind.offline) _status = null;
            }),
            onSubmitted: (_) => _save(),
            suffix: FieldSymbolButton(
              icon: _obscure ? AvoIcons.eye : AvoIcons.eyeSlash,
              semanticLabel: context.tr(
                _obscure ? 'auth_show_password' : 'auth_hide_password',
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: AvoSpacing.m),
          for (final rule in PasswordRule.values)
            _RuleRow(
              text: context.tr(switch (rule) {
                PasswordRule.length => 'auth_rule_length',
                PasswordRule.upper => 'auth_rule_upper',
                PasswordRule.digit => 'auth_rule_digit',
              }),
              met: passwordRuleMet(rule, password),
            ),
        ],
      ),
    );
  }
}

/// One password rule: `circle` while open, `checkmark.circle.fill` when met
/// (the shape changes, not only the colour; A7 Neues Passwort).
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.text, required this.met});

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final line = typography.lineHeightOf(AvoTextStyle.subhead);
    final size =
        _kRuleSymbol *
        typography.sizeOf(AvoTextStyle.subhead) /
        _kSubheadAtLarge;
    return Semantics(
      container: true,
      label: text,
      value: context.tr(met ? 'auth_rule_met' : 'auth_rule_open'),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AvoSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: line,
              width: size,
              child: Center(
                child: AnimatedSwitcher(
                  duration: AvoMotion.fadeReduced,
                  child: met
                      ? AvoIcon(
                          AvoIcons.checkmarkCircleFill,
                          key: const ValueKey('met'),
                          size: size,
                          color: colors.tint,
                        )
                      : AvoIcon(
                          AvoIcons.circle,
                          key: const ValueKey('open'),
                          size: size,
                          color: colors.uncheckedRing,
                        ),
                ),
              ),
            ),
            const SizedBox(width: AvoSpacing.s),
            Expanded(
              child: Text(text, style: context.text(AvoTextStyle.subhead)),
            ),
          ],
        ),
      ),
    );
  }
}

/// E-Mail ändern (Konzept 18 §7.1): the new address, then the 6-digit code
/// (Konzept 17 §3.7). Pops with true once the account has the new address.
class AccountEmailChangeScreen extends ConsumerStatefulWidget {
  const AccountEmailChangeScreen({super.key, required this.currentEmail});

  final String currentEmail;

  @override
  ConsumerState<AccountEmailChangeScreen> createState() =>
      _AccountEmailChangeScreenState();
}

class _AccountEmailChangeScreenState
    extends ConsumerState<AccountEmailChangeScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _fieldError;
  AuthErrorKind? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = normalizeEmail(_controller.text);
    if (!looksLikeEmail(email) || _sending) return;
    if (email == normalizeEmail(widget.currentEmail)) {
      setState(() => _fieldError = context.tr('acct_email_same'));
      AvoHaptics.error();
      return;
    }
    if (ref.read(isOfflineProvider)) {
      setState(() => _status = AuthErrorKind.offline);
      AvoHaptics.error();
      return;
    }
    final service = ref.read(accountSecurityProvider);
    setState(() {
      _sending = true;
      _status = null;
      _fieldError = null;
    });
    try {
      await service.requestEmailChange(email);
    } catch (e) {
      debugPrint('[ACCOUNT] email change not started: ${e.runtimeType}');
      if (!mounted) return;
      final kind = classifyAuthError(e, attempt: AuthAttempt.sendCode);
      final taken = e is AuthException && e.code == 'email_exists';
      setState(() {
        _sending = false;
        if (taken) {
          _fieldError = context.tr('acct_email_taken');
        } else if (kind == AuthErrorKind.emailInvalid) {
          _fieldError = authErrorMessage(context, kind)?.text;
        } else {
          _status = kind;
        }
      });
      AvoHaptics.error();
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final navigator = Navigator.of(context);
    final verified = await navigator.push<bool>(
      CupertinoPageRoute(
        builder: (_) => AccountCodeScreen(
          title: context.tr('auth_code_title'),
          message: context.tr('auth_code_sent_to', params: {'email': email}),
          onResend: () => service.requestEmailChange(email),
          onVerify: (code) => service.verifyEmailChange(email, code),
        ),
      ),
    );
    if (verified == true && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider);
    final status = _status ?? (offline ? AuthErrorKind.offline : null);
    final fieldError = _fieldError;
    return OnboardingStepPage(
      title: context.tr('acct_new_email_title'),
      message: context.tr('acct_new_email_message'),
      onBack: () => Navigator.of(context).pop(false),
      primaryAction: AppButton.primary(
        label: context.tr('auth_send_code'),
        onPressed: looksLikeEmail(_controller.text) ? _send : null,
        working: _sending,
        workingLabel: context.tr('auth_sending'),
        size: AppButtonSize.large,
        expand: true,
      ),
      status: status == null
          ? null
          : AuthStatusLine.forError(
              context,
              status,
              attempt: AuthAttempt.sendCode,
              offlineText: context.tr('acct_needs_connection'),
              onAction: status == AuthErrorKind.unknown ? _send : null,
            ),
      children: [
        AuthTextField(
          controller: _controller,
          label: context.tr('auth_email_label'),
          placeholder: context.tr('auth_email_placeholder'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          autofocus: true,
          error: fieldError != null,
          onChanged: (_) => setState(() {
            _fieldError = null;
            if (_status != AuthErrorKind.offline) _status = null;
          }),
          onSubmitted: (_) => _send(),
        ),
        if (fieldError != null) FieldErrorLine(fieldError),
      ],
    );
  }
}

/// A 6-digit code step for the account pages (Konzept 17 §3.7): one capsule
/// with one-time-code autofill, checks by itself at 6 digits, "Neuen Code
/// senden" after 60 s, wrong code under the field, offline waits.
/// [onVerify] throws on a wrong code; the page pops with true on success.
/// Used for "E-Mail ändern" and "Bestätige, dass du es bist" (Konto
/// löschen), whose texts the A7 `CodeStep` cannot take.
class AccountCodeScreen extends ConsumerStatefulWidget {
  const AccountCodeScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onResend,
    required this.onVerify,
  });

  final String title;
  final String message;
  final Future<void> Function() onResend;
  final Future<void> Function(String code) onVerify;

  @override
  ConsumerState<AccountCodeScreen> createState() => _AccountCodeScreenState();
}

class _AccountCodeScreenState extends ConsumerState<AccountCodeScreen> {
  final _controller = TextEditingController();
  late DateTime _sentAt;
  Timer? _ticker;
  bool _verifying = false;
  bool _resending = false;
  bool _waitingForNetwork = false;
  AuthErrorKind? _codeError;
  AuthErrorKind? _status;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    // The code was sent right before this page opened.
    _sentAt = ref.read(authClockProvider)();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _cooldownLeft > Duration.zero) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Duration get _cooldownLeft {
    final left =
        kCodeResendCooldown - ref.read(authClockProvider)().difference(_sentAt);
    return left.isNegative ? Duration.zero : left;
  }

  void _changed(String value) {
    setState(() {
      _codeError = null;
      if (_status != AuthErrorKind.offline) {
        _status = null;
        _statusText = null;
      }
    });
    if (value.length == kCodeLength) _verify();
  }

  Future<void> _verify() async {
    final code = _controller.text;
    if (code.length != kCodeLength || _verifying) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _waitingForNetwork = true);
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _verifying = true;
      _waitingForNetwork = false;
      _codeError = null;
      _status = null;
      _statusText = null;
    });
    try {
      await widget.onVerify(code);
    } catch (e) {
      debugPrint('[ACCOUNT] code not accepted: ${e.runtimeType}');
      if (!mounted) return;
      final since = ref.read(authClockProvider)().difference(_sentAt);
      setState(() {
        _verifying = false;
        if (e is AccountMismatchException) {
          _statusText = context.tr('acct_other_account');
          return;
        }
        final kind = classifyAuthError(
          e,
          attempt: AuthAttempt.verifyCode,
          sinceCodeSent: since,
          codeLifetime: kCodeLifetime,
        );
        if (kind == AuthErrorKind.codeInvalid ||
            kind == AuthErrorKind.codeExpired) {
          _codeError = kind;
        } else {
          _status = kind;
        }
      });
      AvoHaptics.error();
      return;
    }
    navigator.pop(true);
  }

  Future<void> _resend() async {
    if (_resending || _cooldownLeft > Duration.zero) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _status = AuthErrorKind.offline);
      return;
    }
    final sentText = context.tr('auth_code_resent');
    final direction = Directionality.of(context);
    final view = View.of(context);
    setState(() => _resending = true);
    try {
      await widget.onResend();
      _sentAt = ref.read(authClockProvider)();
      unawaited(SemanticsService.sendAnnouncement(view, sentText, direction));
    } catch (e) {
      debugPrint('[ACCOUNT] code not resent: ${e.runtimeType}');
      if (mounted) {
        setState(
          () => _status = classifyAuthError(e, attempt: AuthAttempt.sendCode),
        );
      }
      AvoHaptics.error();
    }
    if (mounted) setState(() => _resending = false);
  }

  String _cooldownText(Duration left) {
    final m = left.inMinutes;
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return context.tr('auth_code_resend_in', params: {'time': '$m:$s'});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offline = ref.watch(isOfflineProvider);
    ref.listen<bool>(isOfflineProvider, (previous, nowOffline) {
      if (!nowOffline && _waitingForNetwork) _verify();
    });
    final left = _cooldownLeft;
    final codeStyle = context
        .text(AvoTextStyle.title2, weight: FontWeight.w600, tabular: true)
        .copyWith(letterSpacing: 0);
    final codeError = _codeError;
    final statusText = _statusText;
    final Widget? status;
    if (statusText != null) {
      status = AuthStatusLine(kind: StatusKind.failed, text: statusText);
    } else {
      final kind = _status ?? (offline ? AuthErrorKind.offline : null);
      status = kind == null
          ? null
          : AuthStatusLine.forError(
              context,
              kind,
              attempt: AuthAttempt.verifyCode,
              offlineText: context.tr('acct_needs_connection'),
              onAction: kind == AuthErrorKind.unknown ? _verify : null,
            );
    }

    return OnboardingStepPage(
      title: widget.title,
      message: widget.message,
      onBack: _verifying ? null : () => Navigator.of(context).pop(false),
      primaryAction: AppButton.primary(
        label: context.tr('auth_code_confirm'),
        onPressed: _controller.text.length == kCodeLength ? _verify : null,
        working: _verifying,
        workingLabel: context.tr('auth_code_checking'),
        size: AppButtonSize.large,
        expand: true,
      ),
      status: status,
      children: [
        AuthTextField(
          controller: _controller,
          label: context.tr('auth_code_label'),
          placeholder: '0' * kCodeLength,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          autofocus: true,
          textAlign: TextAlign.center,
          style: codeStyle,
          placeholderStyle: codeStyle.copyWith(color: colors.secondaryLabel),
          inputFormatters: const [CodeInputFormatter()],
          readOnly: _verifying,
          error: codeError != null,
          onChanged: _changed,
          onSubmitted: (_) => _verify(),
        ),
        if (codeError != null)
          FieldErrorLine(
            authErrorMessage(context, codeError)?.text ??
                context.tr('auth_err_otp_invalid'),
          ),
        const SizedBox(height: AvoSpacing.m),
        Text(
          context.tr('auth_code_spam'),
          style: context.text(
            AvoTextStyle.footnote,
            color: colors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AvoSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.plain(
            label: left > Duration.zero
                ? _cooldownText(left)
                : context.tr('auth_code_resend'),
            onPressed: left > Duration.zero ? null : _resend,
            working: _resending,
            workingLabel: context.tr('auth_sending'),
          ),
        ),
      ],
    );
  }
}
