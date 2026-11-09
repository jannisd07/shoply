import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_field.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// Rule symbols next to 15 pt text at the default size (SF Symbols).
const double _kRuleSymbol = 18;

/// Subhead size at the default category, the reference for scaling the
/// rule symbols with Dynamic Type.
const double _kSubheadAtLarge = 15;

/// Neues Passwort (Konzept 17 §4.4, `/reset-password`): after the reset
/// code, or on the next start while [kPasswordResetPendingKey] is set.
///
/// One hidden field with "Passwort anzeigen" and iOS's strong-password
/// suggestion, three rules that tick off while typing, "Passwort speichern"
/// once all are met. Success keeps the session and opens Tab Liste with
/// "Passwort geändert."; "Abbrechen" (top left, `xmark`) asks first and
/// signs out. [onDone] and [onCancelled] override where it goes next.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.onDone, this.onCancelled});

  final VoidCallback? onDone;
  final VoidCallback? onCancelled;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
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
    final gateway = ref.read(authGatewayProvider);
    final router = GoRouter.maybeOf(context);
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await gateway.updatePassword(password);
    } catch (e) {
      debugPrint('[AUTH] saving the new password failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = classifyAuthError(e, attempt: AuthAttempt.newPassword);
      });
      AvoHaptics.error();
      return;
    }
    await gateway.setPasswordResetPending(false);
    // Lets iOS save the new password in the keychain.
    TextInput.finishAutofillContext();
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
      return;
    }
    AvoToast.show(context, message: context.tr('auth_password_changed'));
    router?.go(RoutePaths.lists);
  }

  Future<void> _cancel() async {
    if (_saving) return;
    final gateway = ref.read(authGatewayProvider);
    final router = GoRouter.maybeOf(context);
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('auth_reset_cancel_title'),
      message: context.tr('auth_reset_cancel_message'),
      confirmLabel: context.tr('auth_sign_out'),
      cancelLabel: context.tr('auth_reset_keep_going'),
    );
    if (!confirmed) return;
    try {
      await gateway.signOut();
    } catch (e) {
      debugPrint('[AUTH] sign-out after cancelled reset failed: $e');
    }
    await gateway.setPasswordResetPending(false);
    if (!mounted) return;
    if (widget.onCancelled != null) {
      widget.onCancelled!();
    } else {
      router?.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final offline = ref.watch(isOfflineProvider);
    final password = _controller.text;
    final status = _status ?? (offline ? AuthErrorKind.offline : null);

    final page = OnboardingStepPage(
      title: context.tr('auth_new_password_title'),
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
    );

    // "Abbrechen" sits where the back button of the step frame sits
    // (Konzept 17 §4.4: `xmark` instead of back) and is read first.
    return AutofillGroup(
      child: Stack(
        children: [
          Semantics(
            container: true,
            sortKey: const OrdinalSortKey(1),
            child: page,
          ),
          PositionedDirectional(
            top: media.padding.top + AvoSpacing.xs,
            start: AvoSpacing.screen,
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(0),
              child: GlassIconButton(
                icon: const AvoIcon(AvoIcons.xmark),
                semanticLabel: context.tr('cancel'),
                onPressed: _saving ? null : _cancel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One rule: `circle` while open, `checkmark.circle.fill` when met; the
/// shape changes, not only the colour (Konzept 17 §4.4).
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
        _kRuleSymbol * typography.sizeOf(AvoTextStyle.subhead) / _kSubheadAtLarge;
    final symbol = met
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
          );
    final reduce = context.reduceMotion;
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
                  transitionBuilder: (child, animation) => reduce
                      ? FadeTransition(opacity: animation, child: child)
                      : ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                  child: symbol,
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
