import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/common/success_alert.dart';

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
      return context.tr('today');
    } else if (entryDate == yesterday) {
      return context.tr('yesterday');
    } else {
      return DateFormat('d. MMM', locale).format(date);
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

  Future<void> _addAllItemsToList(List<ShoppingHistoryItem> items, String listId, String listName) async {
    for (final item in items) {
      await ref.read(itemsNotifierProvider(listId).notifier).addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
      );
    }

    if (mounted) {
      SuccessAlert.showItemsAdded(
        context,
        count: items.length,
        listName: listName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(shoppingHistoryNotifierProvider);
    final listsAsync = ref.watch(listsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lists = listsAsync.valueOrNull ?? [];

    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF);
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final inputFill = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          context.tr('shopping_history'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (historyAsync.hasValue && historyAsync.value!.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                size: 22,
                color: textSecondary,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(
                      context.tr('clear_history'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    content: Text(
                      context.tr('clear_history_confirm'),
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
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
        error: (error, _) => _buildEmptyState(isDark, textPrimary, textSecondary, inputFill, isError: true),
        data: (history) {
          if (history.isEmpty) {
            return _buildEmptyState(isDark, textPrimary, textSecondary, inputFill);
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
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...entries.map((entry) => _buildHistoryCard(entry, isDark, lists, textPrimary, textSecondary, cardColor, inputFill, iconColor)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textPrimary, Color textSecondary, Color inputFill, {bool isError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.wifi_off_rounded : Icons.receipt_long_rounded,
            size: 48,
            color: textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            isError ? context.tr('loading_error') : context.tr('no_shopping_trips'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isError ? context.tr('retry') : context.tr('completed_trips_appear_here'),
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          if (isError) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => ref.read(shoppingHistoryNotifierProvider.notifier).refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ShoppingHistory entry, bool isDark, List<dynamic> lists, Color textPrimary, Color textSecondary, Color cardColor, Color inputFill, Color iconColor) {
    final isExpanded = _expandedEntries.contains(entry.id);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              context.tr('delete_entry'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            content: Text(
              context.tr('delete_entry_confirm'),
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
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
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                _formatDate(entry.completedAt, context),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                              if (entry.completedByName != null) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(fontSize: 13, color: textSecondary),
                                ),
                                Flexible(
                                  child: Text(
                                    entry.completedByName!,
                                    style: TextStyle(fontSize: 13, color: textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Item count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.totalItems}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded items with add functionality
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                    ? _HistoryExpandedContent(
                        entry: entry,
                        lists: lists,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        inputFill: inputFill,
                        iconColor: iconColor,
                        onAddAllItems: _addAllItemsToList,
                      )
                    : const SizedBox(width: double.infinity, height: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expanded content with list selector, add all, and individual add buttons
class _HistoryExpandedContent extends ConsumerStatefulWidget {
  final ShoppingHistory entry;
  final List<dynamic> lists;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color inputFill;
  final Color iconColor;
  final Future<void> Function(List<ShoppingHistoryItem> items, String listId, String listName) onAddAllItems;

  const _HistoryExpandedContent({
    required this.entry,
    required this.lists,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.inputFill,
    required this.iconColor,
    required this.onAddAllItems,
  });

  @override
  ConsumerState<_HistoryExpandedContent> createState() => _HistoryExpandedContentState();
}

class _HistoryExpandedContentState extends ConsumerState<_HistoryExpandedContent> {
  String? _selectedListId;
  final Set<String> _addedItemIds = {};
  bool _isAddingAll = false;

  @override
  void initState() {
    super.initState();
    if (widget.lists.isNotEmpty) {
      _selectedListId = widget.lists.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant _HistoryExpandedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedListId == null && widget.lists.isNotEmpty) {
      setState(() {
        _selectedListId = widget.lists.first.id;
      });
    }
    if (_selectedListId != null && widget.lists.isNotEmpty) {
      final stillExists = widget.lists.any((l) => l.id == _selectedListId);
      if (!stillExists) {
        setState(() {
          _selectedListId = widget.lists.first.id;
        });
      }
    }
  }

  Future<void> _addSingleItem(ShoppingHistoryItem item) async {
    if (_selectedListId == null) return;

    HapticFeedback.lightImpact();
    setState(() {
      _addedItemIds.add(item.id);
    });

    try {
      await ref.read(itemsNotifierProvider(_selectedListId!).notifier).addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
      );

      if (mounted) {
        final selectedList = widget.lists.firstWhere((l) => l.id == _selectedListId);
        SuccessAlert.showItemAdded(
          context,
          listName: selectedList.name,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addedItemIds.remove(item.id);
        });
        SuccessAlert.show(
          context,
          title: context.tr('error_adding_items'),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
        );
      }
    }
  }

  Future<void> _addAllItems() async {
    if (_selectedListId == null) return;

    setState(() {
      _isAddingAll = true;
      for (final item in widget.entry.items) {
        _addedItemIds.add(item.id);
      }
    });

    try {
      final selectedList = widget.lists.firstWhere((l) => l.id == _selectedListId);
      await widget.onAddAllItems(widget.entry.items, _selectedListId!, selectedList.name);
    } catch (e) {
      if (mounted) {
        setState(() {
          for (final item in widget.entry.items) {
            _addedItemIds.remove(item.id);
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        _isAddingAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entry.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text(
          context.tr('no_items'),
          style: TextStyle(
            fontSize: 13,
            color: widget.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Divider
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),

        // List selector + add all button
        if (widget.lists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('add_to_list').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                // Horizontal scrolling list cards
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.lists.length,
                    itemBuilder: (context, index) {
                      final list = widget.lists[index];
                      final isSelected = list.id == _selectedListId;
                      return _buildListCard(list, isSelected);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Add all button
                GestureDetector(
                  onTap: _selectedListId == null || _isAddingAll ? null : _addAllItems,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedListId == null
                          ? widget.inputFill.withValues(alpha: widget.isDark ? 0.04 : 0.03)
                          : widget.inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isAddingAll)
                          CupertinoActivityIndicator(
                            radius: 10,
                            color: widget.iconColor,
                          )
                        else
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _selectedListId == null
                                ? widget.textSecondary.withValues(alpha: 0.5)
                                : widget.iconColor,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '${context.tr('add_all')} (${widget.entry.items.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedListId == null
                                ? widget.textSecondary.withValues(alpha: 0.5)
                                : widget.iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Items list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            children: widget.entry.items.map((item) {
              final isAdded = _addedItemIds.contains(item.id);
              final qty = item.quantity.truncateToDouble() == item.quantity
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(1);
              final detail = item.unit != null ? '$qty ${item.unit}' : (item.quantity > 1 ? '${qty}x' : '');

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isAdded
                        ? (widget.isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FDF4))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Check icon
                      Icon(
                        isAdded ? Icons.check_circle_rounded : Icons.check_rounded,
                        size: 14,
                        color: isAdded
                            ? const Color(0xFF22C55E)
                            : widget.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      // Item name
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: widget.textPrimary,
                          ),
                        ),
                      ),
                      // Quantity
                      if (detail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            detail,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.textSecondary,
                            ),
                          ),
                        ),
                      // Add button
                      if (widget.lists.isNotEmpty && _selectedListId != null)
                        GestureDetector(
                          onTap: isAdded ? null : () => _addSingleItem(item),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isAdded
                                  ? const Color(0xFF22C55E)
                                  : widget.inputFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isAdded ? Icons.check_rounded : Icons.add_rounded,
                              size: 16,
                              color: isAdded
                                  ? Colors.white
                                  : widget.iconColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard(dynamic list, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedListId = list.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.10))
              : widget.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: widget.textPrimary,
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                list.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
