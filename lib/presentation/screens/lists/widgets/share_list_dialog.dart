import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_form_dialog.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Generates a share code for the list and shows it with "share code" and
/// "share link" actions.
Future<void> showShareListDialog(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required String listName,
}) async {
  final String code;
  try {
    code = await ref.read(listsNotifierProvider.notifier).generateShareCode(
          listId,
        );
  } catch (e) {
    debugPrint('❌ [LIST_DETAIL] Failed to generate share code: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('action_failed'))),
      );
    }
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _ShareListDialog(
      code: code,
      onShareCode: () {
        Navigator.pop(dialogContext);
        _shareText(
          context,
          _codeShareText(context, listName, code),
          subject: context.tr('share_list_subject'),
        );
      },
      onShareLink: () {
        Navigator.pop(dialogContext);
        _shareText(
          context,
          '🛒 $listName\n\nhttps://shoplyai.app/list/$listId',
          subject: listName,
        );
      },
    ),
  );
}

String _codeShareText(BuildContext context, String listName, String code) {
  return '${context.tr('share_list_text', params: {'name': listName})}'
      '\n\n${context.tr('share_list_join_code', params: {'code': code})}';
}

void _shareText(
  BuildContext context,
  String text, {
  required String subject,
}) {
  if (!context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  Share.share(
    text,
    subject: subject,
    sharePositionOrigin: box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100),
  );
}

class _ShareListDialog extends StatelessWidget {
  final String code;
  final VoidCallback onShareCode;
  final VoidCallback onShareLink;

  const _ShareListDialog({
    required this.code,
    required this.onShareCode,
    required this.onShareLink,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);
    final dim = AppColors.textTertiary(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.shareCodeTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.shareCodeMessage,
              style: TextStyle(color: muted, fontSize: 14, letterSpacing: -0.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Code display
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('code_copied')),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_rounded, size: 18, color: dim),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('tap_to_copy'),
              style: TextStyle(color: dim, fontSize: 12),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onShareCode,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.numbers_rounded, size: 18, color: fg),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('share_via_code'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: fg,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PaperPrimaryButton(
                    label: context.tr('share_via_link'),
                    icon: Icons.link_rounded,
                    onTap: onShareLink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
