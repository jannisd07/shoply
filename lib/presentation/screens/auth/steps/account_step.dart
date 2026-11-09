import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/screens/auth/widgets/sign_in_buttons.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:url_launcher/url_launcher.dart';

/// Space between the sign-in buttons (Konzept 17 §3.5).
const double _kButtonGap = AvoSpacing.m;

/// Konto (Konzept 17 §3.5) and Anmelden (§4.1): Apple, Google, E-Mail.
///
/// Calls [onSignedIn] once a session exists; the flow decides whether the
/// account is new or already set up. Until the flow moves on, the chosen
/// button stays in its working state (no flash of the wrong next screen).
/// A second tap while a session exists only calls [onSignedIn] again (the
/// flow retries `apply_onboarding`, §3.5). The constructor is the contract
/// with the flow; [status], [onTerms] and [onPrivacy] are optional
/// additions.
class AccountStep extends ConsumerStatefulWidget {
  const AccountStep({
    super.key,
    this.mode = AccountStepMode.signUp,
    required this.onEmail,
    required this.onSignedIn,
    this.onPassword,
    this.onBack,
    this.progress,
    this.status,
    this.onTerms,
    this.onPrivacy,
  });

  final AccountStepMode mode;

  /// "Mit E-Mail fortfahren": the flow pushes [EmailStep].
  final VoidCallback onEmail;

  /// A Supabase session exists.
  final VoidCallback onSignedIn;

  /// Login mode only: "Mit Passwort anmelden".
  final VoidCallback? onPassword;

  final VoidCallback? onBack;
  final Widget? progress;

  /// A status line from the flow ("Deine Auswahl ist noch nicht gespeichert.
  /// Erneut versuchen", §3.5). Shown instead of the step's own line; when it
  /// appears the working state ends.
  final Widget? status;

  /// Opens the terms of use; defaults to the web page.
  final VoidCallback? onTerms;

  /// Opens the privacy notice; defaults to the web page.
  final VoidCallback? onPrivacy;

  @override
  ConsumerState<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends ConsumerState<AccountStep> {
  AuthAttempt? _busy;
  AuthErrorKind? _error;
  AuthAttempt? _errorAttempt;

  /// Bumped on every tap while offline, so the offline line is shown and
  /// announced again (§3.5: "ein Tipp zeigt dieselbe Zeile erneut").
  int _offlineNudge = 0;

  @override
  void didUpdateWidget(covariant AccountStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null && oldWidget.status == null && _busy != null) {
      setState(() => _busy = null);
    }
  }

  Future<void> _signIn(AuthAttempt attempt) async {
    if (_busy != null) return;
    final gateway = ref.read(authGatewayProvider);
    if (gateway.hasSession) {
      widget.onSignedIn();
      return;
    }
    if (ref.read(isOfflineProvider)) {
      setState(() {
        _error = null;
        _offlineNudge++;
      });
      AvoHaptics.error();
      return;
    }
    setState(() {
      _busy = attempt;
      _error = null;
    });
    try {
      final signedIn = attempt == AuthAttempt.apple
          ? await gateway.signInWithApple()
          : await gateway.signInWithGoogle();
      if (!mounted) return;
      if (!signedIn) {
        // Sheet closed: nothing happened, nothing to say.
        setState(() => _busy = null);
        return;
      }
      // The button keeps working until the flow shows the next screen.
      widget.onSignedIn();
    } catch (e) {
      debugPrint('[AUTH] ${attempt.name} sign-in failed: $e');
      if (!mounted) return;
      final kind = classifyAuthError(e, attempt: attempt);
      setState(() {
        _busy = null;
        _error = kind == AuthErrorKind.cancelled ? null : kind;
        _errorAttempt = attempt;
      });
      if (kind != AuthErrorKind.cancelled) AvoHaptics.error();
    }
  }

  void _email() {
    if (_busy != null) return;
    widget.onEmail();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AUTH] opening $url failed: $e');
    }
  }

  Widget? _statusLine(BuildContext context, {required bool offline}) {
    if (widget.status != null) return widget.status;
    final appleAvailable = ref.read(authGatewayProvider).appleAvailable;
    final signUp = widget.mode == AccountStepMode.signUp;
    if (offline || _error == AuthErrorKind.offline) {
      return AuthStatusLine(
        key: ValueKey('offline-$_offlineNudge'),
        kind: StatusKind.offline,
        text: context.tr(
          signUp ? 'auth_offline_keeps_choice' : 'auth_err_offline',
        ),
      );
    }
    final error = _error;
    if (error == null) return null;
    final attempt = _errorAttempt;
    VoidCallback? action;
    switch (error) {
      case AuthErrorKind.accountUsesGoogle:
        action = () => _signIn(AuthAttempt.google);
      case AuthErrorKind.accountUsesApple:
        if (appleAvailable) action = () => _signIn(AuthAttempt.apple);
      case AuthErrorKind.socialFailed:
      case AuthErrorKind.unknown:
        if (attempt != null) action = () => _signIn(attempt);
      default:
        action = null;
    }
    return AuthStatusLine.forError(
      context,
      error,
      attempt: attempt,
      appleAvailable: appleAvailable,
      onAction: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(authGatewayProvider);
    final offline = ref.watch(isOfflineProvider);
    final login = widget.mode == AccountStepMode.login;
    final busy = _busy;
    final working = context.tr('auth_signing_in');
    final status = _statusLine(context, offline: offline);

    return OnboardingStepPage(
      title: context.tr(login ? 'auth_login_title' : 'auth_account_title'),
      message: context.tr(
        login ? 'auth_login_message' : 'auth_account_message',
      ),
      progress: widget.progress,
      onBack: widget.onBack,
      // The three buttons are the actions; there is no action bar (§3.5).
      status: status,
      children: [
        if (gateway.appleAvailable) ...[
          AppleSignInButton(
            label: context.tr('auth_continue_apple'),
            working: busy == AuthAttempt.apple,
            workingLabel: working,
            onPressed: busy == null || busy == AuthAttempt.apple
                ? () => _signIn(AuthAttempt.apple)
                : null,
          ),
          const SizedBox(height: _kButtonGap),
        ],
        GoogleSignInButton(
          label: context.tr('auth_continue_google'),
          working: busy == AuthAttempt.google,
          workingLabel: working,
          onPressed: busy == null || busy == AuthAttempt.google
              ? () => _signIn(AuthAttempt.google)
              : null,
        ),
        const SizedBox(height: _kButtonGap),
        EmailSignInButton(
          label: context.tr('auth_continue_email'),
          onPressed: busy == null ? _email : null,
        ),
        if (login && widget.onPassword != null) ...[
          const SizedBox(height: AvoSpacing.xs),
          Center(
            child: AppButton.plain(
              label: context.tr('auth_use_password'),
              onPressed: busy == null ? widget.onPassword : null,
            ),
          ),
        ],
        const SizedBox(height: AvoSpacing.xxl),
        _LegalNotice(
          onTerms: widget.onTerms ?? () => _open(LegalLinks.terms),
          onPrivacy: widget.onPrivacy ?? () => _open(LegalLinks.privacy),
        ),
      ],
    );
  }
}

/// "Mit dem Fortfahren akzeptierst du …" and the two links, each with a
/// 44 pt target (§3.5). The links sit as their own targets under the
/// sentence: inline links in a 13 pt line cannot reach 44 pt.
class _LegalNotice extends StatelessWidget {
  const _LegalNotice({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('auth_legal_notice'),
          style: context.text(
            AvoTextStyle.footnote,
            color: colors.secondaryLabel,
          ),
        ),
        Wrap(
          spacing: AvoSpacing.l,
          children: [
            _FootnoteLink(label: context.tr('auth_terms'), onTap: onTerms),
            _FootnoteLink(label: context.tr('auth_privacy'), onTap: onPrivacy),
          ],
        ),
      ],
    );
  }
}

class _FootnoteLink extends StatelessWidget {
  const _FootnoteLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    link: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: PressableScale(
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AvoSizes.hitTarget,
          minWidth: AvoSizes.hitTarget,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            label,
            style: context.text(
              AvoTextStyle.footnote,
              color: context.colors.tint,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}
