import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/profile/account/account_auth_pages.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_icons.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/account/deletion_summary.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Hairlines of the summary groups start at the text, after the symbol.
const double _kIconRowIndent =
    AvoSpacing.l + kAccountInfoIconSize + AvoSpacing.m;

enum _Failure { delete, confirm, otherAccount }

/// Konto löschen (`/settings/account/delete`, Konzept 18 §7.3, §11.10,
/// App Store 5.1.1(v)): what gets deleted (from the local state), who gets
/// the shared lists, the hint that Avo Pro keeps running at Apple, then
/// "Konto löschen" and "Abbrechen".
///
/// "Konto löschen" asks for a fresh sign-in (Apple or Google sheet, a code
/// for email accounts), then the alert "Konto endgültig löschen?", then
/// runs `delete-account` behind [AccountDeletionService] with a progress
/// in the row while back and buttons are off. Success: success haptic, the
/// session goes, the router opens Willkommen and the toast says "Dein Konto
/// wurde gelöscht."; [onDeleted] runs too (tests). Failure: nothing was
/// deleted, the status line offers "Erneut versuchen". Offline the button
/// is off. The constructor is the contract with the router.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, this.highlightRowId, this.onDeleted});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  /// Called after the account was deleted.
  final VoidCallback? onDeleted;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirming = false;
  bool _deleting = false;
  _Failure? _failure;
  ReauthProof? _proof;

  bool get _busy => _confirming || _deleting;

  Future<void> _start() async {
    if (_busy || ref.read(isOfflineProvider)) return;
    final identity = ref.read(accountIdentityProvider);
    if (identity == null) return;
    final service = ref.read(accountDeletionProvider);
    final now = ref.read(accountClockProvider);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final otherAccountText = context.tr('acct_other_account');
    setState(() => _failure = null);

    var proof = _proof;
    if (proof == null || !proof.isFresh(now())) {
      setState(() => _confirming = true);
      try {
        proof = await _confirmIdentity(identity, service);
      } on AccountMismatchException {
        if (!mounted) {
          // The other account was signed out again; the page is gone.
          if (rootContext.mounted) {
            AvoToast.show(rootContext, message: otherAccountText);
          }
          return;
        }
        _fail(_Failure.otherAccount);
        return;
      } catch (e) {
        debugPrint('[ACCOUNT] confirming failed: ${e.runtimeType}');
        final kind = classifyAuthError(
          e,
          attempt: identity.method == SignInMethod.google
              ? AuthAttempt.google
              : AuthAttempt.apple,
        );
        if (!mounted) return;
        if (kind == AuthErrorKind.cancelled) {
          setState(() => _confirming = false);
          return;
        }
        _fail(_Failure.confirm);
        return;
      }
      if (!mounted) return;
      setState(() => _confirming = false);
      if (proof == null) return;
      _proof = proof;
    }

    final summary = ref.read(deletionSummaryProvider);
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('acct_delete_confirm_title'),
      message: _confirmMessage(context, summary),
      confirmLabel: context.tr('acct_delete_confirm_action'),
    );
    if (!confirmed || !mounted) return;

    final session = ref.read(accountSessionProvider);
    final deletedText = context.tr('acct_deleted');
    final onDeleted = widget.onDeleted;
    setState(() => _deleting = true);
    try {
      await service.deleteAccount(proof);
    } catch (e) {
      debugPrint('[ACCOUNT] deleting failed: $e');
      if (mounted) _fail(_Failure.delete);
      return;
    }
    AvoHaptics.success();
    await session.finishDeletion();
    if (rootContext.mounted) AvoToast.show(rootContext, message: deletedText);
    onDeleted?.call();
  }

  /// Apple or Google sheet; for email accounts a code on its own page.
  Future<ReauthProof?> _confirmIdentity(
    AccountIdentity identity,
    AccountDeletionService service,
  ) async {
    if (identity.method != SignInMethod.email) {
      return service.confirmWithProvider(identity.method);
    }
    final email = identity.email;
    await service.sendCode(email);
    if (!mounted) return null;
    ReauthProof? proof;
    final verified = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => AccountCodeScreen(
          title: context.tr('acct_reauth_title'),
          message: context.tr('acct_reauth_message', params: {'email': email}),
          onResend: () => service.sendCode(email),
          onVerify: (code) async {
            proof = await service.verifyCode(email, code);
          },
        ),
      ),
    );
    return verified == true ? proof : null;
  }

  void _fail(_Failure failure) {
    setState(() {
      _confirming = false;
      _deleting = false;
      _failure = failure;
      if (failure != _Failure.delete) _proof = null;
    });
    AvoHaptics.error();
  }

  String _confirmMessage(BuildContext context, DeletionSummary summary) {
    final name = summary.name?.trim() ?? '';
    final parts = [
      name.isEmpty
          ? context.tr('acct_delete_confirm_plain')
          : context.tr('acct_delete_confirm_named', params: {'name': name}),
      for (final h in summary.handovers) _handoverText(context, h),
    ];
    return parts.join(' ');
  }

  String _handoverText(BuildContext context, ListHandover h) {
    final member = h.memberName;
    return member == null
        ? context.tr(
            'acct_delete_handover_someone',
            params: {'list': h.listName},
          )
        : context.tr(
            'acct_delete_handover',
            params: {'list': h.listName, 'name': member},
          );
  }

  String _count(
    BuildContext context,
    int n, {
    required String one,
    required String many,
  }) => n == 1 ? context.tr(one) : context.tr(many, params: {'n': '$n'});

  List<Widget> _deletedRows(BuildContext context, DeletionSummary s) {
    final recipes = s.ownRecipes;
    final trips = s.trips;
    return [
      if (s.ownLists > 0)
        AccountInfoRow(
          icon: AccountIcons.checklist,
          text: _count(
            context,
            s.ownLists,
            one: 'acct_delete_lists_one',
            many: 'acct_delete_lists',
          ),
        ),
      if (recipes == null || recipes > 0)
        AccountInfoRow(
          icon: AvoIcons.forkKnife,
          text: recipes == null
              ? context.tr('acct_delete_recipes_unknown')
              : _count(
                  context,
                  recipes,
                  one: 'acct_delete_recipes_one',
                  many: 'acct_delete_recipes',
                ),
        ),
      if (trips == null || trips > 0)
        AccountInfoRow(
          icon: AccountIcons.history,
          text: trips == null
              ? context.tr('acct_delete_history_unknown')
              : _count(
                  context,
                  trips,
                  one: 'acct_delete_history_one',
                  many: 'acct_delete_history',
                ),
        ),
      AccountInfoRow(
        icon: AccountIcons.personCircle,
        text: context.tr('acct_delete_profile'),
      ),
      if (s.calories != CalorieDiary.none)
        AccountInfoRow(
          icon: AccountIcons.flame,
          text: context.tr(
            s.calories == CalorieDiary.on
                ? 'acct_delete_calories'
                : 'acct_delete_calories_off',
          ),
        ),
    ];
  }

  String _proText(BuildContext context, DeletionSummary s) {
    final renews = s.proRenewsOn;
    if (renews == null) return context.tr('acct_delete_pro');
    final locale = Localizations.localeOf(context).toLanguageTag();
    return context.tr(
      'acct_delete_pro_renews',
      params: {'date': DateFormat.yMMMd(locale).format(renews.toLocal())},
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = ref.watch(deletionSummaryProvider);
    final offline = ref.watch(isOfflineProvider);
    final balances = summary.openBalances ?? 0;

    final Widget? status;
    if (offline) {
      status = StatusRow(
        kind: StatusKind.offline,
        text: context.tr('acct_needs_connection'),
      );
    } else if (_failure != null) {
      status = StatusRow(
        kind: StatusKind.failed,
        text: context.tr(switch (_failure!) {
          _Failure.delete => 'acct_delete_failed',
          _Failure.confirm => 'acct_confirm_failed',
          _Failure.otherAccount => 'acct_other_account',
        }),
        actionLabel: context.tr('common_try_again'),
        onAction: _start,
      );
    } else {
      status = null;
    }

    final page = FullScreenEditor(
      title: context.tr('acct_delete'),
      leading: EditorLeading.back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null) status,
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.screen,
              vertical: AvoSpacing.s,
            ),
            child: Text(
              context.tr('acct_delete_intro'),
              style: context.text(AvoTextStyle.body),
            ),
          ),
          InsetSection(
            header: context.tr('acct_delete_what'),
            footer: summary.calories == CalorieDiary.none
                ? null
                : context.tr('acct_delete_health_footer'),
            separatorIndent: _kIconRowIndent,
            children: _deletedRows(context, summary),
          ),
          InsetSection(
            header: context.tr('acct_delete_shared'),
            separatorIndent: _kIconRowIndent,
            children: [
              for (final h in summary.handovers)
                AccountInfoRow(
                  icon: AvoIcons.people,
                  text: _handoverText(context, h),
                ),
              if (summary.leftLists > 0)
                AccountInfoRow(
                  icon: AvoIcons.people,
                  text: _count(
                    context,
                    summary.leftLists,
                    one: 'acct_delete_leave_one',
                    many: 'acct_delete_leave',
                  ),
                ),
            ],
          ),
          if (summary.pro || balances > 0) ...[
            const SizedBox(height: AvoSpacing.section),
            InsetSection(
              separatorIndent: _kIconRowIndent,
              children: [
                if (summary.pro)
                  AccountInfoRow(
                    icon: AvoIcons.exclamationmarkTriangleFill,
                    iconColor: colors.warning,
                    text: _proText(context, summary),
                    trailing: AppButton.secondary(
                      label: context.tr('acct_manage_subscription'),
                      onPressed: () => ref.read(manageSubscriptionsProvider)(),
                    ),
                  ),
                if (balances > 0)
                  AccountInfoRow(
                    icon: AvoIcons.people,
                    text: _count(
                      context,
                      balances,
                      one: 'acct_delete_balances_one',
                      many: 'acct_delete_balances',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AvoSpacing.section),
          InsetSection(
            children: [
              AccountDestructiveRow(
                title: context.tr('acct_delete'),
                onTap: _start,
                working: _busy,
                workingLabel: context.tr('acct_deleting'),
                enabled: !offline,
              ),
            ],
          ),
          const SizedBox(height: AvoSpacing.s),
          Center(
            child: AppButton.plain(
              label: context.tr('cancel'),
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );

    return RowHighlightScope(
      rowId: widget.highlightRowId,
      child: PopScope<Object?>(
        canPop: !_busy,
        child: AbsorbPointer(absorbing: _deleting, child: page),
      ),
    );
  }
}
