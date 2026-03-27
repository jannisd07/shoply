import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';

class ShoppingHistoryScreen extends ConsumerStatefulWidget {
  const ShoppingHistoryScreen({super.key});

  @override
  ConsumerState<ShoppingHistoryScreen> createState() => _ShoppingHistoryScreenState();
}

class _ShoppingHistoryScreenState extends ConsumerState<ShoppingHistoryScreen> {
  final Set<String> _expandedEntries = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(shoppingHistoryNotifierProvider.notifier).refresh();
    });
  }

  String _getDateGroupLabel(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return context.tr('today');
    } else if (entryDate == yesterday) {
      return context.tr('yesterday');
    } else if (now.difference(date).inDays < 7) {
      return context.tr('this_week');
    } else if (now.month == date.month && now.year == date.year) {
      return context.tr('this_month');
    } else {
      return DateFormat('MMMM yyyy', Localizations.localeOf(context).languageCode).format(date);
    }
  }

  Map<String, List<ShoppingHistory>> _groupHistoryByDate(List<ShoppingHistory> history) {
    final grouped = <String, List<ShoppingHistory>>{};
    for (final entry in history) {
      final label = _getDateGroupLabel(entry.completedAt, context);
      grouped.putIfAbsent(label, () => []).add(entry);
    }
    return grouped;
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  String _formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);
    final locale = Localizations.localeOf(context).languageCode;

    if (entryDate == today) {
      return '${context.tr('today')}, ${_formatTime(date)}';
    } else if (entryDate == yesterday) {
      return '${context.tr('yesterday')}, ${_formatTime(date)}';
    } else {
      return DateFormat('d. MMM, HH:mm', locale).format(date);
    }
  }

  Future<void> _deleteEntry(String id) async {
    HapticFeedback.mediumImpact();
    await ref.read(shoppingHistoryNotifierProvider.notifier).deleteHistory(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('entry_deleted')),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(shoppingHistoryNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          context.tr('shopping_history'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (historyAsync.hasValue && historyAsync.value!.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                size: 22,
                color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(
                      context.tr('clear_history'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    content: Text(
                      context.tr('clear_history_confirm'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          context.tr('cancel'),
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: Text(
                          context.tr('clear'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(shoppingHistoryNotifierProvider.notifier).clearAllHistory();
                }
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: historyAsync.when(
        loading: () => Center(
          child: CupertinoActivityIndicator(color: isDark ? Colors.white38 : Colors.black26, radius: 10),
        ),
        error: (error, _) => _buildEmptyState(isDark, isError: true),
        data: (history) {
          if (history.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final grouped = _groupHistoryByDate(history);
          final groupKeys = grouped.keys.toList();

          return ListView.builder(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 100,
            ),
            itemCount: groupKeys.length,
            itemBuilder: (context, index) {
              final groupKey = groupKeys[index];
              final entries = grouped[groupKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 8 : 24,
                      bottom: 12,
                    ),
                    child: Text(
                      groupKey.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...entries.map((entry) => _buildHistoryCard(entry, isDark)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {bool isError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.wifi_off_rounded : Icons.receipt_long_rounded,
            size: 48,
            color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
          ),
          const SizedBox(height: 16),
          Text(
            isError ? context.tr('loading_error') : context.tr('no_shopping_trips'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isError ? context.tr('retry') : context.tr('completed_trips_appear_here'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
            ),
          ),
          if (isError) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => ref.read(shoppingHistoryNotifierProvider.notifier).refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF8E8E93),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ShoppingHistory entry, bool isDark) {
    final isExpanded = _expandedEntries.contains(entry.id);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              context.tr('delete_entry'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            content: Text(
              context.tr('delete_entry_confirm'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(
                  context.tr('delete'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _deleteEntry(entry.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isExpanded) {
              _expandedEntries.remove(entry.id);
            } else {
              _expandedEntries.add(entry.id);
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    // List name + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.listName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(entry.completedAt, context),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Item count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.totalItems}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : const Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded items
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildItemsList(entry, isDark),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList(ShoppingHistory entry, bool isDark) {
    if (entry.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text(
          context.tr('no_items'),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Container(
            height: 0.5,
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 10),
          ...entry.items.take(15).map((item) {
            final qty = item.quantity.truncateToDouble() == item.quantity
                ? item.quantity.toInt().toString()
                : item.quantity.toStringAsFixed(1);
            final detail = item.unit != null ? '$qty ${item.unit}' : (item.quantity > 1 ? '${qty}x' : '');

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF3C3C43),
                      ),
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (entry.items.length > 15)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${entry.items.length - 15} ${context.tr('more_items')}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
