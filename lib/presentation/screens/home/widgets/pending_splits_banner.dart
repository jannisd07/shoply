import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/history/shopping_history_screen.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';

/// Home-screen card summarizing unpaid trip-cost splits: money owed to the
/// current user, and money the current user still owes someone else.
/// Renders nothing once everything is settled.
class PendingSplitsBanner extends ConsumerWidget {
  const PendingSplitsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owedToMe = ref.watch(tripsAwaitingPaymentToMeProvider).valueOrNull ?? const [];
    final iOwe = ref.watch(tripsIOweProvider).valueOrNull ?? const [];

    if (owedToMe.isEmpty && iOwe.isEmpty) return const SizedBox.shrink();

    final accent = AppColors.accentColor(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        8,
        AppDimensions.screenHorizontalPadding,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (final trip in owedToMe)
              // Skip the payer's own share (settled at the register; older
              // splits may still carry it as an unpaid row).
              for (final split in trip.splits.where(
                  (s) => !s.isPaid && s.userId != trip.paidByUserId))
                _SplitRow(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: accent,
                  text: context.tr(
                    'owed_to_me_line',
                    params: {
                      'name': split.participantName,
                      'amount': split.amount.toStringAsFixed(2),
                      'list': trip.listName,
                    },
                  ),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _openHistory(context),
                  onQuickAction: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(expenseSplitServiceProvider)
                        .setPaid(split.id, true);
                    ref.invalidate(tripsAwaitingPaymentToMeProvider);
                    ref.invalidate(tripsIOweProvider);
                  },
                  quickActionLabel: context.tr('mark_as_paid'),
                ),
            for (final trip in iOwe)
              for (final split in trip.splits)
                _SplitRow(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: PaperColors.terracotta,
                  text: context.tr(
                    'i_owe_line',
                    params: {
                      'amount': split.amount.toStringAsFixed(2),
                      'name': trip.paidByName ?? trip.listName,
                    },
                  ),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _openHistory(context),
                  onQuickAction: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(expenseSplitServiceProvider)
                        .setPaid(split.id, true);
                    ref.invalidate(tripsIOweProvider);
                    ref.invalidate(tripsAwaitingPaymentToMeProvider);
                  },
                  quickActionLabel: context.tr('i_paid_back'),
                ),
          ],
        ),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShoppingHistoryScreen()),
    );
  }
}



class _SplitRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback? onQuickAction;
  final String? quickActionLabel;

  const _SplitRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    this.onQuickAction,
    this.quickActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: textPrimary),
              ),
            ),
            if (onQuickAction != null)
              GestureDetector(
                onTap: onQuickAction,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    quickActionLabel ?? '',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
