import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/presentation/screens/history/widgets/split_cost_sheet.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';

/// Paper-style activities screen: "Dein Juli." with stats, weekday
/// rhythm chart and shopping history.
class ShoppingHistoryScreen extends ConsumerStatefulWidget {
  const ShoppingHistoryScreen({super.key});

  @override
  ConsumerState<ShoppingHistoryScreen> createState() =>
      _ShoppingHistoryScreenState();
}

class _ShoppingHistoryScreenState extends ConsumerState<ShoppingHistoryScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(shoppingHistoryNotifierProvider);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          final monthName =
              DateFormat('MMMM', locale).format(DateTime.now());
          final now = DateTime.now();
          final monthEntries = entries
              .where((e) =>
                  e.completedAt.year == now.year &&
                  e.completedAt.month == now.month)
              .toList();
          final itemsBought = monthEntries.fold<int>(
            0,
            (sum, e) => sum + e.totalItems,
          );

          // Weekday distribution (Mo..So) over all entries.
          final weekdayCounts = List<int>.filled(7, 0);
          for (final e in entries) {
            weekdayCounts[e.completedAt.weekday - 1]++;
          }
          final maxCount = weekdayCounts.fold<int>(0, (a, b) => a > b ? a : b);
          final topWeekday =
              maxCount > 0 ? weekdayCounts.indexOf(maxCount) : -1;
          final topWeekdayName = topWeekday >= 0
              ? DateFormat('EEEE', locale).format(
                  // Any date with the desired weekday (2024-01-01 is a Monday).
                  DateTime(2024, 1, 1 + topWeekday),
                )
              : null;

          // Lifetime savings from live offers applied to purchased items
          // (Feature 8: ties Feature 1's pricing infra into the history
          // screen's own stats). Only items with both a real price and the
          // offer's known regular price count — never a guessed baseline.
          var totalSavings = 0.0;
          for (final e in entries) {
            for (final item in e.items) {
              final perUnit = item.savingsPerUnit;
              if (perUnit != null) totalSavings += perUnit * item.quantity;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('activities_label').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'your_month_headline',
                    params: {'month': monthName},
                  ),
                  style: PaperTextStyles.serif(28, color: textPrimary),
                ),
                const SizedBox(height: 22),

                // Stats row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stat(
                      value: '$itemsBought',
                      label: context.tr('items_bought'),
                    ),
                    const SizedBox(width: 28),
                    _Stat(
                      value: '${monthEntries.length}',
                      label: context.tr('purchases_label'),
                    ),
                    const SizedBox(width: 28),
                    _Stat(
                      value: '${entries.length}',
                      label: context.tr('history_label'),
                    ),
                  ],
                ),

                if (totalSavings > 0.01) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.savings_outlined, size: 16, color: accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr(
                            'history_savings_line',
                            params: {
                              'amount': '${totalSavings.toStringAsFixed(2)} €',
                            },
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (maxCount > 0) ...[
                  const SizedBox(height: 26),
                  // Weekday rhythm chart
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: maxCount > 0
                                  ? 14 + 76 * (weekdayCounts[i] / maxCount)
                                  : 14,
                              decoration: BoxDecoration(
                                color: i == topWeekday
                                    ? accent
                                    : AppColors.border(context),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (int i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('E', locale)
                                .format(DateTime(2024, 1, 1 + i)),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: i == topWeekday
                                  ? accent
                                  : AppColors.textTertiary(context),
                              fontWeight: i == topWeekday
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (topWeekdayName != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      context.tr(
                        'shopping_day_line',
                        params: {'day': topWeekdayName},
                      ),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ],

                const SizedBox(height: 28),
                Text(
                  context.tr('history_label').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),

                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      context.tr('no_shopping_history'),
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  )
                else
                  for (final entry in entries)
                    _HistoryRow(
                      entry: entry,
                      expanded: _expandedId == entry.id,
                      locale: locale,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _expandedId =
                              _expandedId == entry.id ? null : entry.id;
                        });
                      },
                      onDelete: () async {
                        HapticFeedback.mediumImpact();
                        await ref
                            .read(shoppingHistoryNotifierProvider.notifier)
                            .deleteHistory(entry.id);
                      },
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: PaperTextStyles.serif(
            26,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  final ShoppingHistory entry;
  final bool expanded;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryRow({
    required this.entry,
    required this.expanded,
    required this.locale,
    required this.onTap,
    required this.onDelete,
  });

  String _dateLabel(BuildContext context) {
    final now = DateTime.now();
    final d = entry.completedAt;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return context.tr('today');
    if (diff == 1) return context.tr('yesterday');
    return DateFormat('d. MMM', locale).format(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider(context)),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.listName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PaperTextStyles.serif(17, color: textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_dateLabel(context)} · ${entry.totalItems} ${context.tr('items')}',
                        style:
                            TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary(context),
                ),
              ],
            ),
            if (expanded && entry.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final item in entry.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}${item.unit != null && item.unit!.isNotEmpty ? ' ${item.unit}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (expanded) _SplitSection(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _SplitSection extends ConsumerWidget {
  final ShoppingHistory entry;

  const _SplitSection({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    if (entry.totalCost == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            showSplitCostSheet(context, ref, entry: entry);
          },
          child: Row(
            children: [
              Icon(Icons.call_split_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                context.tr('split_trip_cost'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final splitsAsync = ref.watch(tripSplitsProvider(entry.id));
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr('total_cost')}: ${entry.totalCost!.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showSplitCostSheet(context, ref, entry: entry);
                },
                child: Text(
                  context.tr('edit_split'),
                  style: TextStyle(fontSize: 12, color: accent),
                ),
              ),
            ],
          ),
          if (entry.paidByName != null && entry.paidByName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${context.tr('paid_by')}: ${entry.paidByName}',
                style: TextStyle(fontSize: 11.5, color: textSecondary),
              ),
            ),
          const SizedBox(height: 6),
          splitsAsync.when(
            loading: () => const SizedBox(
              height: 20,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (splits) => Column(
              children: [
                for (final split in splits)
                  _SplitParticipantRow(split: split, entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitParticipantRow extends ConsumerWidget {
  final ExpenseSplit split;
  final ShoppingHistory entry;

  const _SplitParticipantRow({required this.split, required this.entry});

  /// Copies a friendly, localized payment-reminder message for this share
  /// to the clipboard, ready to paste into any messenger.
  Future<void> _copyReminder(BuildContext context) async {
    HapticFeedback.selectionClick();
    final message = context.tr(
      'payment_reminder_message',
      params: {
        'name': split.participantName,
        'amount': split.amount.toStringAsFixed(2),
        'list': entry.listName,
      },
    );
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('reminder_copied'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Copying a reminder only makes sense for shares someone still owes the
    // payer — not for the payer's own (auto-settled) share.
    final showReminder = !split.isPaid &&
        (split.userId == null || split.userId != entry.paidByUserId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              split.participantName,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          if (showReminder)
            GestureDetector(
              onTap: () => _copyReminder(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Tooltip(
                  message: context.tr('copy_reminder'),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ),
            ),
          Text(
            '${split.amount.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await ref
                  .read(expenseSplitServiceProvider)
                  .setPaid(split.id, !split.isPaid);
              ref.invalidate(tripSplitsProvider(entry.id));
              ref.invalidate(tripsAwaitingPaymentToMeProvider);
              ref.invalidate(tripsIOweProvider);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: split.isPaid
                    ? AppColors.accentColor(context).withValues(alpha: 0.12)
                    : AppColors.border(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                split.isPaid ? context.tr('paid') : context.tr('unpaid'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: split.isPaid
                      ? AppColors.accentColor(context)
                      : AppColors.textTertiary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
