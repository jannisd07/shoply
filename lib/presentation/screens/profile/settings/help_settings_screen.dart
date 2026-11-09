import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

// D2 data colours of the contact tiles (X-Profil palette).
const Color _kMailTile = Color(0xFF0062CC); // D2
const Color _kBugTile = Color(0xFFFF3B30); // D2
const Color _kStarTile = Color(0xFFFF9F0A); // D2
const Color _kTipsTile = Color(0xFF8E8E93); // D2
const Color _kGuideTile = Color(0xFF1F7A3A); // D2 tint

/// How long "Tipps zurückgesetzt · Widerrufen" can be undone (the toast's
/// time; with VoiceOver it stays longer).
const Duration _kUndo = Duration(seconds: 4);
const Duration _kUndoVoiceOver = Duration(seconds: 10);

/// One question of "Häufige Fragen".
class _Question {
  const _Question(this.id, {this.link});

  /// Key part: `setp_help_q_<id>` and `setp_help_a_<id>`.
  final String id;

  /// A path the answer names ("Profil › Konto"), opened as a plain link.
  final ({String labelKey, String location})? link;
}

/// Hilfe (`/settings/help`, Konzept 18 §5.8): Häufige Fragen that unfold in
/// place, Kontakt (mail to support, "Fehler melden" with visible device
/// details, rating), Tipps ("Tipps zurücksetzen" with Widerrufen, the guide
/// in the in-app browser) and the version.
class HelpSettingsScreen extends ConsumerStatefulWidget {
  const HelpSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<HelpSettingsScreen> createState() => _HelpSettingsScreenState();
}

class _HelpSettingsScreenState extends ConsumerState<HelpSettingsScreen> {
  final Set<String> _open = {};
  Timer? _resetTimer;
  void Function()? _pendingReset;

  @override
  void dispose() {
    // Leaving the page before the toast is gone keeps the reset.
    _commitReset();
    super.dispose();
  }

  void _commitReset() {
    _resetTimer?.cancel();
    _resetTimer = null;
    final reset = _pendingReset;
    _pendingReset = null;
    reset?.call();
  }

  /// Resets the tips once the undo time is over (Konzept 18 Regel 8).
  void _resetTips() {
    _commitReset();
    _pendingReset = ref.read(settingsTipsResetProvider);
    final voiceOver = MediaQuery.accessibleNavigationOf(context);
    final duration = voiceOver ? _kUndoVoiceOver : _kUndo;
    _resetTimer = Timer(duration, _commitReset);
    AvoToast.show(
      context,
      message: context.tr('setp_help_tips_done'),
      actionLabel: context.tr('common_undo'),
      duration: duration,
      onAction: () {
        _resetTimer?.cancel();
        _resetTimer = null;
        _pendingReset = null;
      },
    );
  }

  Future<void> _mail({required String subject, String? body}) async {
    final actions = ref.read(settingsExternalActionsProvider);
    final opened = await actions.openMail(
      to: LegalLinks.supportEmail,
      subject: subject,
      body: body,
    );
    if (opened || !mounted) return;
    await actions.copy(LegalLinks.supportEmail);
    if (!mounted) return;
    AvoToast.show(context, message: context.tr('setp_help_mail_copied'));
  }

  String _versionLine(BuildContext context) {
    final version = ref.read(settingsAppVersionProvider);
    if (version == null) return AppBrand.name;
    return context.tr('setp_help_version', params: {'version': version});
  }

  void _reportBug() {
    final version = ref.read(settingsAppVersionProvider);
    final system = ref.read(settingsSystemVersionProvider);
    final lines = [
      context.tr('setp_help_bug_body'),
      '',
      '',
      '${AppBrand.name} ${version ?? ''}'.trim(),
      if (system.isNotEmpty) 'iOS: $system',
    ];
    _mail(subject: context.tr('setp_help_bug_subject'), body: lines.join('\n'));
  }

  void _openGuide() {
    final loader = ref.read(settingsWebLoaderProvider);
    final actions = ref.read(settingsExternalActionsProvider);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => InAppBrowserPage(
          title: context.tr('setp_help_guide'),
          url: Uri.parse(LegalLinks.userGuide),
          loader: loader,
          onOpenExternally: actions.openUrl,
          backLabel: context.tr('setp_help_title'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offersShown =
        ref.watch(moduleEnabledProvider(AppModule.offers)) &&
        !ref.watch(offersKillSwitchProvider);
    final questions = <_Question>[
      const _Question('share'),
      const _Question('shopping'),
      const _Question('category'),
      if (offersShown) const _Question('offers'),
      const _Question(
        'pro',
        link: (labelKey: 'setp_help_link_pro', location: RoutePaths.pro),
      ),
      const _Question(
        'delete',
        link: (
          labelKey: 'setp_help_link_account',
          location: RoutePaths.settingsAccount,
        ),
      ),
    ];

    return SettingsPage(
      title: context.tr('setp_help_title'),
      highlightRowId: widget.highlightRowId,
      children: [
        InsetSection(
          header: context.tr('setp_help_faq'),
          children: [
            for (final q in questions)
              HighlightableRow(
                id: 'help.faq_${q.id}',
                child: ExpandableRow(
                  title: context.tr('setp_help_q_${q.id}'),
                  answer: context.tr('setp_help_a_${q.id}'),
                  expanded: _open.contains(q.id),
                  onTap: () => setState(
                    () => _open.contains(q.id)
                        ? _open.remove(q.id)
                        : _open.add(q.id),
                  ),
                  actions: [
                    if (q.link case final link?)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppButton.plain(
                          label: context.tr(link.labelKey),
                          onPressed: () =>
                              openSettingsLocation(context, link.location),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_help_contact'),
          separatorIndent: kSettingsTileRowIndent,
          children: [
            HighlightableRow(
              id: 'help.support',
              child: NavRow(
                title: context.tr('setp_help_mail'),
                leading: const SettingsIconTile(
                  icon: AvoIcons.envelope,
                  color: _kMailTile,
                ),
                onTap: () =>
                    _mail(subject: context.tr('setp_help_mail_subject')),
              ),
            ),
            HighlightableRow(
              id: 'help.bug',
              child: NavRow(
                title: context.tr('setp_help_bug'),
                subtitle: context.tr('setp_help_bug_sub'),
                leading: const SettingsIconTile(
                  icon: SettingsIcons.ant,
                  color: _kBugTile,
                ),
                onTap: _reportBug,
              ),
            ),
            HighlightableRow(
              id: 'help.rate',
              child: NavRow(
                title: context.tr('setp_help_rate'),
                leading: const SettingsIconTile(
                  icon: SettingsIcons.star,
                  color: _kStarTile,
                ),
                onTap: () =>
                    ref.read(settingsExternalActionsProvider).requestReview(),
              ),
            ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_help_tips'),
          separatorIndent: kSettingsTileRowIndent,
          children: [
            HighlightableRow(
              id: 'help.tips_reset',
              child: SettingsActionRow(
                title: context.tr('setp_help_tips_reset'),
                subtitle: context.tr('setp_help_tips_reset_sub'),
                leading: const SettingsIconTile(
                  icon: SettingsIcons.reset,
                  color: _kTipsTile,
                ),
                onTap: _resetTips,
              ),
            ),
            HighlightableRow(
              id: 'help.guide',
              child: NavRow(
                title: context.tr('setp_help_guide'),
                leading: const SettingsIconTile(
                  icon: SettingsIcons.book,
                  color: _kGuideTile,
                ),
                onTap: _openGuide,
              ),
            ),
          ],
        ),
        SettingsFooter(
          _versionLine(context),
          onLongPress: kDebugMode
              ? () => openSettingsLocation(context, RoutePaths.debugComponents)
              : null,
        ),
        const SizedBox(height: AvoSpacing.s),
      ],
    );
  }
}
