import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/constants/app_config.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/notification_permission_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Glyph next to the list name (Konzept 11 §9.1: 36 pt).
const double _kHeaderGlyph = 36;

/// The bell of the notification explanation (Konzept 11 §9.3: 48 pt).
const double _kBellSize = 48;

/// Set once the notification explanation was answered on this device.
const String _kIntroSeenKey = 'list_share_notif_intro_seen_v1';

/// Whether "Liste teilen" starts with the notification explanation
/// (Konzept 11 §9.3: once, only while the system prompt was never shown).
/// Overridden in tests.
final shareNotificationIntroProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kIntroSeenKey) ?? false) return false;
  return !(prefs.getBool(NotificationPermissionService.promptedKey) ?? false);
});

/// Asks for notifications ("Mitteilungen erlauben"). Overridden in tests.
final shareNotificationRequestProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () =>
          NotificationPermissionService.instance.requestIfUseful('list_shared'),
);

/// Opens the system share sheet. Overridden in tests.
final shareSheetProvider =
    Provider<Future<void> Function(String text, String subject, Rect origin)>(
      (ref) =>
          (text, subject, origin) =>
              Share.share(text, subject: subject, sharePositionOrigin: origin),
    );

/// "482 913": a code in two groups of three.
String groupShareCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

/// The invitation text: sentence, link, and the code for "Liste beitreten"
/// (no emoji, Konzept 11 §9.1).
String shareInviteText(
  BuildContext context, {
  required String listName,
  required String code,
  String? link,
}) {
  final url = link ?? AppConfig.generateShareLink(code);
  return '${context.tr('list_ov_invite_message', params: {'name': listName, 'app': AppBrand.name})}'
      '\n$url\n\n'
      '${context.tr('list_ov_invite_code', params: {'code': code})}';
}

/// "Liste teilen" full screen (Konzept 11 §9, instead of the dialog): the
/// list, its members, "Personen einladen" (system share with link and
/// code), "Code anzeigen" with copy and, for the creator, "Neuen Code
/// erzeugen". The code stays the same between visits (L-05): a new one is
/// only made when there is none yet or the creator asks for it.
///
/// With [showIntro] it starts with the one-time notification explanation
/// (§9.3) and continues to the sharing part after either answer.
class ShareListScreen extends ConsumerStatefulWidget {
  const ShareListScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.showIntro = false,
  });

  final String listId;
  final String listName;
  final bool showIntro;

  @override
  ConsumerState<ShareListScreen> createState() => _ShareListScreenState();
}

class _ShareListScreenState extends ConsumerState<ShareListScreen> {
  late bool _intro = widget.showIntro;
  bool _askingNotifications = false;
  bool _codeOpen = false;
  bool _generating = false;

  /// A code made on this screen, before the lists reload.
  String? _freshCode;

  ShoppingListModel? _list(List<ShoppingListModel>? lists) {
    for (final l in lists ?? const <ShoppingListModel>[]) {
      if (l.id == widget.listId) return l;
    }
    return null;
  }

  Future<void> _finishIntro({required bool allow}) async {
    if (allow) {
      setState(() => _askingNotifications = true);
      try {
        await ref.read(shareNotificationRequestProvider)();
      } catch (e) {
        debugPrint('⚠️ [SHARE_LIST] Notification request failed: $e');
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIntroSeenKey, true);
    } catch (e) {
      debugPrint('⚠️ [SHARE_LIST] Failed to store the intro flag: $e');
    }
    ref.invalidate(shareNotificationIntroProvider);
    if (mounted) {
      setState(() {
        _askingNotifications = false;
        _intro = false;
      });
    }
  }

  /// The current code, making one when the list has none yet.
  Future<String?> _ensureCode(String? existing) async {
    if (existing != null && existing.isNotEmpty) return existing;
    return _newCode();
  }

  Future<String?> _newCode() async {
    setState(() => _generating = true);
    try {
      final code = await ref
          .read(listActionsProvider)
          .generateShareCode(widget.listId);
      if (mounted) {
        setState(() {
          _freshCode = code;
          _generating = false;
        });
      }
      return code;
    } catch (e) {
      debugPrint('❌ [SHARE_LIST] Failed to create a code: $e');
      if (mounted) {
        setState(() => _generating = false);
        AvoHaptics.error();
        AvoToast.show(context, message: context.tr('list_ov_code_failed'));
      }
      return null;
    }
  }

  Future<void> _invite(BuildContext anchor, ShoppingListModel? list) async {
    final code = await _ensureCode(_freshCode ?? list?.shareCode);
    if (code == null || !mounted || !anchor.mounted) return;
    final name = list?.name ?? widget.listName;
    final text = shareInviteText(
      context,
      listName: name,
      code: code,
      link: _freshCode == null ? list?.shareLink : null,
    );
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    await ref.read(shareSheetProvider)(text, name, origin);
  }

  Future<void> _toggleCode(String? existing) async {
    if (_codeOpen) {
      setState(() => _codeOpen = false);
      return;
    }
    final code = await _ensureCode(existing);
    if (code != null && mounted) setState(() => _codeOpen = true);
  }

  Future<void> _regenerate() async {
    final code = await _newCode();
    if (code != null && mounted) {
      AvoToast.show(context, message: context.tr('list_ov_new_code_done'));
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    AvoToast.show(context, message: context.tr('list_ov_code_copied'));
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final cover = route is PageRoute && route.fullscreenDialog;
    final leading = cover ? EditorLeading.close : EditorLeading.back;
    final title = context.tr('list_ov_share_title');
    if (_intro) {
      return FullScreenEditor(
        title: title,
        leading: leading,
        child: _NotificationIntro(
          asking: _askingNotifications,
          onAllow: () => _finishIntro(allow: true),
          onLater: () => _finishIntro(allow: false),
        ),
      );
    }

    final colors = context.colors;
    final list = _list(ref.watch(allListsSourceProvider).valueOrNull);
    final userId = ref.watch(authUserIdProvider);
    final offline = ref.watch(isOfflineProvider);
    final membersValue = ref.watch(listMembersProvider(widget.listId));
    final members = membersValue.valueOrNull ?? const <ListMember>[];
    final code = _freshCode ?? list?.shareCode;
    final hasCode = code != null && code.isNotEmpty;
    final creator = userId != null && list?.ownerId == userId;
    final name = list?.name ?? widget.listName;
    final needsConnection = context.tr('common_needs_connection');

    return FullScreenEditor(
      title: title,
      leading: leading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Row(
              children: [
                ListGlyph(
                  color: list == null
                      ? kListPalette.first.resolve(context)
                      : listDisplayColor(context, list),
                  coverUrl: list == null ? null : listCoverUrl(list),
                  size: _kHeaderGlyph,
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Text(name, style: context.text(AvoTextStyle.headline)),
                ),
              ],
            ),
          ),
          InsetSection(
            header: membersValue.hasValue
                ? context.tr(
                    'list_ov_members_count',
                    params: {'n': '${members.length}'},
                  )
                : context.tr('members'),
            children: [
              for (final m in members)
                MemberRow(member: m, currentUserId: userId),
            ],
          ),
          if (membersValue.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.s),
              child: StatusRow(
                kind: StatusKind.sectionError,
                text: context.tr('list_ov_members_error'),
                actionLabel: context.tr('common_try_again'),
                onAction: () =>
                    ref.invalidate(listMembersProvider(widget.listId)),
              ),
            ),
          const SizedBox(height: AvoSpacing.section),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Builder(
              builder: (anchor) => AppButton.primary(
                label: context.tr('list_ov_invite'),
                icon: const AvoIcon(AvoIcons.share),
                size: AppButtonSize.large,
                expand: true,
                working: _generating,
                onPressed: !hasCode && offline
                    ? null
                    : () => _invite(anchor, list),
              ),
            ),
          ),
          if (!hasCode && offline)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.xs),
              child: Text(
                needsConnection,
                textAlign: TextAlign.center,
                style: context.text(
                  AvoTextStyle.footnote,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
          const SizedBox(height: AvoSpacing.xs),
          Center(
            child: AppButton.plain(
              label: context.tr(
                _codeOpen ? 'list_ov_hide_code' : 'list_ov_show_code',
              ),
              onPressed: (!hasCode && offline) || _generating
                  ? null
                  : () => _toggleCode(code),
            ),
          ),
          AnimatedSize(
            duration: AvoMotion.fadeReduced,
            alignment: Alignment.topCenter,
            child: _codeOpen && hasCode
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InsetSection(
                        footer: context.tr('list_ov_code_footer'),
                        children: [
                          _CodeTile(code: code, onCopy: () => _copy(code)),
                        ],
                      ),
                      if (creator)
                        Padding(
                          padding: const EdgeInsets.only(top: AvoSpacing.s),
                          child: Center(
                            child: AppButton.plain(
                              label: context.tr('list_ov_new_code'),
                              onPressed: offline || _generating
                                  ? null
                                  : _regenerate,
                            ),
                          ),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The code in big tabular digits, "Tippen zum Kopieren" below; tapping
/// copies it. Breaks after the first group at large text sizes.
class _CodeTile extends StatelessWidget {
  const _CodeTile({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text(
      AvoTextStyle.largeTitle,
      weight: FontWeight.w600,
      tabular: true,
    );
    final groups = groupShareCode(code).split(' ');
    return Semantics(
      container: true,
      button: true,
      label: context.tr(
        'list_ov_code_label',
        params: {'code': code.split('').join(' ')},
      ),
      hint: context.tr('list_ov_tap_to_copy'),
      onTap: onCopy,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCopy,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: AvoSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AvoSpacing.m,
                children: [for (final g in groups) Text(g, style: style)],
              ),
              const SizedBox(height: AvoSpacing.xs),
              Text(
                context.tr('list_ov_tap_to_copy'),
                textAlign: TextAlign.center,
                style: context.text(
                  AvoTextStyle.subhead,
                  color: colors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Konzept 11 §9.3: the bell, one heading, one sentence, "Mitteilungen
/// erlauben" and "Nicht jetzt".
class _NotificationIntro extends StatelessWidget {
  const _NotificationIntro({
    required this.asking,
    required this.onAllow,
    required this.onLater,
  });

  final bool asking;
  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AvoSpacing.xxl),
          ExcludeSemantics(
            child: AvoIcon(
              AvoIcons.bell,
              size: _kBellSize,
              color: colors.secondaryLabel,
            ),
          ),
          const SizedBox(height: AvoSpacing.l),
          Semantics(
            header: true,
            child: Text(
              context.tr('list_ov_notif_title'),
              textAlign: TextAlign.center,
              style: context.text(AvoTextStyle.title3),
            ),
          ),
          const SizedBox(height: AvoSpacing.s),
          Text(
            context.tr('list_ov_notif_body'),
            textAlign: TextAlign.center,
            style: context.text(AvoTextStyle.body),
          ),
          const SizedBox(height: AvoSpacing.xxl),
          AppButton.primary(
            label: context.tr('list_ov_notif_allow'),
            size: AppButtonSize.large,
            expand: true,
            working: asking,
            onPressed: asking ? null : onAllow,
          ),
          const SizedBox(height: AvoSpacing.xs),
          Center(
            child: AppButton.plain(
              label: context.tr('common_not_now'),
              onPressed: asking ? null : onLater,
            ),
          ),
        ],
      ),
    );
  }
}
