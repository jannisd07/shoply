import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/account/account_auth_pages.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_search.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/account/delete_account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// Konto (`/settings/account`, Konzept 18 §7.1, §7.2): email and sign-in
/// method; for email accounts "E-Mail ändern" and "Passwort"; "Abmelden"
/// and "Konto löschen" as centred red rows in groups of their own.
///
/// Abmelden asks only when changes are still waiting on the device, shows a
/// small progress in the row and then leaves through the router (signed
/// out → Willkommen, variant Anmelden). The constructor is the contract with
/// the router; [highlightRowId] highlights a row once (ids in
/// [AccountRows]). [onSignedOut] runs after signing out (tests, isolated
/// screens).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.highlightRowId, this.onSignedOut});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  /// Called after signing out.
  final VoidCallback? onSignedOut;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  int _unsentChanges() =>
      ref.read(unsentChangesProvider)() +
      ref.read(profileEditControllerProvider.notifier).unsentChanges;

  Future<void> _signOut() async {
    if (_signingOut) return;
    final unsent = _unsentChanges();
    if (unsent > 0) {
      final confirmed = await showAvoConfirm(
        context,
        title: context.tr('acct_sign_out_title'),
        message: unsent == 1
            ? context.tr('acct_sign_out_unsent_one')
            : context.tr('acct_sign_out_unsent', params: {'n': '$unsent'}),
        confirmLabel: context.tr('acct_sign_out'),
      );
      if (!confirmed || !mounted) return;
    }
    final session = ref.read(accountSessionProvider);
    final done = widget.onSignedOut;
    setState(() => _signingOut = true);
    try {
      await session.signOut();
    } catch (e) {
      // The session implementation signs out locally in any case.
      debugPrint('[ACCOUNT] sign-out: ${e.runtimeType}');
    }
    done?.call();
    if (mounted) setState(() => _signingOut = false);
  }

  void _openDelete() => pushAccountPage<void>(
    context,
    RoutePaths.settingsAccountDelete,
    (_) => const DeleteAccountScreen(),
  );

  Future<void> _openChangeEmail(String currentEmail) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => AccountEmailChangeScreen(currentEmail: currentEmail),
      ),
    );
    if (changed == true && mounted) {
      AvoToast.show(context, message: context.tr('acct_email_changed'));
    }
  }

  Future<void> _openPassword(bool hasPassword) async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => AccountPasswordScreen(hasPassword: hasPassword),
      ),
    );
    if (saved == true && mounted) {
      ref.read(passwordSavedProvider.notifier).state = true;
      AvoToast.show(context, message: context.tr('acct_password_saved'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(accountIdentityProvider);
    final method = identity?.method;
    final isEmail = method == SignInMethod.email;
    final saved = ref.watch(passwordSavedProvider);
    final known = isEmail
        ? ref.watch(passwordStateProvider).valueOrNull ?? PasswordState.unknown
        : PasswordState.unknown;
    final password = saved ? PasswordState.set : known;

    return SettingsPage(
      title: context.tr('acct_title'),
      highlightRowId: widget.highlightRowId,
      children: [
        InsetSection(
          children: [
            if (identity != null)
              HighlightableRow(
                id: AccountRows.email,
                child: ValueRow(
                  title: context.tr('acct_email'),
                  value: breakableEmail(identity.email),
                ),
              ),
            if (method != null)
              HighlightableRow(
                id: AccountRows.method,
                child: ValueRow(
                  title: context.tr('acct_signed_in_with'),
                  value: signInMethodLabel(context, method),
                ),
              ),
            if (isEmail) ...[
              HighlightableRow(
                id: AccountRows.changeEmail,
                child: NavRow(
                  title: context.tr('acct_change_email'),
                  onTap: () => _openChangeEmail(identity!.email),
                ),
              ),
              HighlightableRow(
                id: AccountRows.password,
                child: NavRow(
                  title: context.tr('acct_password'),
                  value: switch (password) {
                    PasswordState.set => context.tr('acct_password_set'),
                    PasswordState.notSet => context.tr('acct_password_not_set'),
                    PasswordState.unknown => null,
                  },
                  onTap: () => _openPassword(password == PasswordState.set),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: kSettingsSectionGap),
        InsetSection(
          children: [
            HighlightableRow(
              id: AccountRows.signOut,
              child: AccountDestructiveRow(
                title: context.tr('acct_sign_out'),
                onTap: _signOut,
                working: _signingOut,
                workingLabel: context.tr('acct_signing_out'),
              ),
            ),
          ],
        ),
        const SizedBox(height: kSettingsSectionGap),
        InsetSection(
          footer: context.tr('acct_delete_footer'),
          children: [
            HighlightableRow(
              id: AccountRows.delete,
              child: AccountDestructiveRow(
                title: context.tr('acct_delete'),
                onTap: _openDelete,
                enabled: !_signingOut,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
