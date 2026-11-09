import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/screens/auth/widgets/email_code_page.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

export 'package:shoply/presentation/screens/auth/widgets/email_code_page.dart'
    show CodePurpose;

/// The wrong-code shake (Konzept 17 §3.7): three swings of 8 pt that fade
/// out. A one-off of this step (Konzept 17 §3.7), no token for it.
const double _kShakeDistance = 8;
const int _kShakeSwings = 3;
const Duration _kShakeDuration = Duration(milliseconds: 420);

/// Code eingeben (Konzept 17 §3.7): one capsule for the 6 digits with
/// one-time-code autofill, checks by itself at 6 digits and calls
/// [onVerified] once a session exists.
///
/// Wrong code: the field shakes and stays filled, a red line explains.
/// Offline: the check waits and runs when the connection is back. "Neuen
/// Code senden" waits 60 s after each code. The constructor is the contract
/// with the flow; [purpose] (title and send method for "Passwort
/// vergessen", §4.3) and [status] (a line from the flow, ends the working
/// state) are optional additions. [onBack] also serves "Adresse ändern".
class CodeStep extends ConsumerStatefulWidget {
  const CodeStep({
    super.key,
    this.mode = AccountStepMode.signUp,
    required this.email,
    required this.onVerified,
    this.onBack,
    this.progress,
    this.purpose = CodePurpose.signIn,
    this.status,
  });

  final AccountStepMode mode;
  final String email;
  final VoidCallback onVerified;
  final VoidCallback? onBack;
  final Widget? progress;
  final CodePurpose purpose;
  final Widget? status;

  @override
  ConsumerState<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends ConsumerState<CodeStep>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: _kShakeDuration,
  );
  late DateTime _sentAt;
  Timer? _ticker;

  bool _verifying = false;
  bool _verified = false;
  bool _resending = false;
  bool _waitingForNetwork = false;
  AuthErrorKind? _codeError;
  AuthErrorKind? _status;

  /// What "Erneut versuchen" in the status line repeats.
  VoidCallback? _statusRetry;

  bool get _reset => widget.purpose == CodePurpose.passwordReset;

  @override
  void initState() {
    super.initState();
    // The code was sent right before this step appeared.
    _sentAt = ref.read(authClockProvider)();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant CodeStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null && oldWidget.status == null && _verifying) {
      setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    _controller.dispose();
    super.dispose();
  }

  Duration get _cooldownLeft {
    final left =
        kCodeResendCooldown - ref.read(authClockProvider)().difference(_sentAt);
    return left.isNegative ? Duration.zero : left;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_cooldownLeft == Duration.zero) timer.cancel();
    });
  }

  void _changed(String value) {
    setState(() {
      if (_codeError != null) _codeError = null;
      if (_status != null && _status != AuthErrorKind.offline) _status = null;
    });
    if (value.length == kCodeLength) _verify();
  }

  Future<void> _verify() async {
    final code = _controller.text;
    if (code.length != kCodeLength || _verifying) return;
    final gateway = ref.read(authGatewayProvider);
    if (_verified && gateway.hasSession) {
      // The code is used up; the flow only has to try its next step again.
      widget.onVerified();
      return;
    }
    if (ref.read(isOfflineProvider)) {
      setState(() => _waitingForNetwork = true);
      return;
    }
    setState(() {
      _verifying = true;
      _waitingForNetwork = false;
      _codeError = null;
      _status = null;
    });
    try {
      if (_reset) {
        // Set before the session appears, so the router keeps the user on
        // the way to the new password even if the app is closed now.
        await gateway.setPasswordResetPending(true);
        await gateway.verifyPasswordResetCode(widget.email, code);
      } else {
        await gateway.verifySignInCode(widget.email, code);
      }
      if (!mounted) return;
      _verified = true;
      // Stays in the working state until the flow shows the next screen.
      widget.onVerified();
    } catch (e) {
      debugPrint('[AUTH] code check failed: $e');
      if (_reset) unawaited(gateway.setPasswordResetPending(false));
      if (!mounted) return;
      final kind = classifyAuthError(
        e,
        attempt: AuthAttempt.verifyCode,
        sinceCodeSent: ref.read(authClockProvider)().difference(_sentAt),
        codeLifetime: kCodeLifetime,
      );
      if (kind == AuthErrorKind.offline) {
        setState(() {
          _verifying = false;
          _waitingForNetwork = true;
        });
        return;
      }
      final codeProblem =
          kind == AuthErrorKind.codeInvalid ||
          kind == AuthErrorKind.codeExpired;
      setState(() {
        _verifying = false;
        if (codeProblem) {
          _codeError = kind;
        } else {
          _status = kind;
          _statusRetry = _verify;
        }
      });
      AvoHaptics.error();
      if (codeProblem && !context.reduceMotion) _shake.forward(from: 0);
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldownLeft > Duration.zero) return;
    if (ref.read(isOfflineProvider)) {
      setState(() => _status = AuthErrorKind.offline);
      AvoHaptics.error();
      return;
    }
    final gateway = ref.read(authGatewayProvider);
    setState(() {
      _resending = true;
      _status = null;
    });
    try {
      if (_reset) {
        await gateway.sendPasswordResetCode(widget.email);
      } else {
        await gateway.sendSignInCode(widget.email);
      }
    } catch (e) {
      if (!(_reset && isUnknownAccountError(e))) {
        debugPrint('[AUTH] sending a new code failed: $e');
        if (!mounted) return;
        setState(() {
          _resending = false;
          _status = classifyAuthError(e, attempt: AuthAttempt.sendCode);
          _statusRetry = _resend;
        });
        AvoHaptics.error();
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _resending = false;
      _codeError = null;
      _sentAt = ref.read(authClockProvider)();
      _controller.clear();
    });
    _startTicker();
    _announce(context.tr('auth_code_resent'));
  }

  void _announce(String text) {
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      text,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  String _cooldownText(Duration left) {
    final seconds = (left.inMilliseconds / 1000).ceil();
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return context.tr('auth_code_resend_in', params: {'time': '$m:$s'});
  }

  Widget? _statusLine(BuildContext context, bool offline) {
    if (widget.status != null) return widget.status;
    if (_waitingForNetwork || (offline && _status == null)) {
      return AuthStatusLine(
        kind: StatusKind.offline,
        text: context.tr(
          _waitingForNetwork ? 'auth_offline_code_waits' : 'auth_err_offline',
        ),
      );
    }
    final status = _status;
    if (status == null) return null;
    return AuthStatusLine.forError(
      context,
      status,
      attempt: AuthAttempt.sendCode,
      onAction: status == AuthErrorKind.unknown ? _statusRetry : null,
    );
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
    final status = _statusLine(context, offline);
    final complete = _controller.text.length == kCodeLength;
    final codeError = _codeError;

    final field = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx =
            math.sin(t * _kShakeSwings * 2 * math.pi) *
            _kShakeDistance *
            (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: AuthTextField(
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
        suffix: _verifying
            ? const SizedBox.square(
                dimension: AvoSizes.hitTarget,
                child: CupertinoActivityIndicator(),
              )
            : null,
      ),
    );

    return OnboardingStepPage(
      title: context.tr(_reset ? 'auth_code_title_reset' : 'auth_code_title'),
      message: context.tr(
        _reset ? 'auth_code_sent_if_account' : 'auth_code_sent_to',
        params: {'email': widget.email},
      ),
      progress: widget.progress,
      onBack: widget.onBack,
      // For VoiceOver and Voice Control; the step also checks by itself.
      primaryAction: AppButton.primary(
        label: context.tr('auth_code_confirm'),
        onPressed: complete ? _verify : null,
        working: _verifying,
        workingLabel: context.tr('auth_code_checking'),
        size: AppButtonSize.large,
        expand: true,
      ),
      status: status,
      children: [
        field,
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
        if (widget.onBack != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.plain(
              label: context.tr('auth_code_change_email'),
              onPressed: widget.onBack,
            ),
          ),
      ],
    );
  }
}

/// Keeps the code field to [kCodeLength] digits. A pasted text such as
/// "Dein Code: 482 913" gives "482913": six digits in the pasted part win
/// (also when the field had digits before), otherwise all digits are kept,
/// cut to six.
class CodeInputFormatter extends TextInputFormatter {
  const CodeInputFormatter();

  static final RegExp _plain = RegExp(r'^\d{0,6}$');
  static final RegExp _run = RegExp(r'(?<!\d)\d{6}(?!\d)');

  static String? _sixDigits(String text) {
    final direct = _run.firstMatch(text);
    if (direct != null) return direct.group(0);
    final grouped = _run.firstMatch(text.replaceAll(RegExp(r'[ \u00A0-]'), ''));
    return grouped?.group(0);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (_plain.hasMatch(text)) return newValue;
    String? digits;
    final old = oldValue.selection;
    final start = old.isValid ? math.min(old.start, old.end) : 0;
    final end = newValue.selection.isValid ? newValue.selection.end : text.length;
    if (start >= 0 && end >= start && end <= text.length) {
      digits = _sixDigits(text.substring(start, end));
    }
    digits ??= _sixDigits(text);
    if (digits == null) {
      digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length > kCodeLength) {
        digits = digits.substring(0, kCodeLength);
      }
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
