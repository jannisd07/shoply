import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/presentation/screens/ai/avo_chat_message.dart';
import 'package:shoply/presentation/screens/ai/widgets/avo_action_cards.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Shared card look for the rich chat payloads.
BoxDecoration _cardDecoration(
  BuildContext context, {
  double radius = 14,
  double darkFillAlpha = 0.04,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: darkFillAlpha)
        : PaperColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.hairline,
    ),
  );
}

// ════════════════════════════════════════════════════════
// AVO MESSAGE — no bubble, with rich content
// ════════════════════════════════════════════════════════

class AvoMessage extends StatelessWidget {
  final ChatMessage msg;

  /// Local check state for list-item payloads (item id → checked), applied
  /// over the item snapshot frozen in the payload.
  final Map<String, bool> checkedOverrides;
  final void Function(ShoppingListModel list) onListTap;
  final void Function(String recipeId) onRecipeTap;
  final Future<void> Function(String listId, AvoPickListData data) onPickList;
  final Future<void> Function(String itemId, String listId, bool isChecked) onCheckItem;
  final Future<void> Function(ShoppingHistory entry, ShoppingHistoryItem? item) onAddHistoryItem;

  const AvoMessage({
    super.key,
    required this.msg,
    required this.checkedOverrides,
    required this.onListTap,
    required this.onRecipeTap,
    required this.onPickList,
    required this.onCheckItem,
    required this.onAddHistoryItem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: SelectableText(
                msg.text,
                style: PaperTextStyles.serif(
                  15,
                  color: AppColors.textPrimary(context),
                  height: 1.55,
                ),
              ),
            ),
          for (var i = 0; i < msg.payloads.length; i++) ...[
            if (msg.text.isNotEmpty || i > 0) const SizedBox(height: 12),
            _buildPayload(msg.payloads[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPayload(AvoWidgetPayload p) {
    switch (p.kind) {
      case AvoPayloadKind.recipes:
        return _RecipeCards(recipes: p.recipes ?? [], onTap: onRecipeTap);
      case AvoPayloadKind.listItems:
        return _ListItemsView(
          items: p.items ?? [],
          listName: p.listName ?? '',
          listId: p.listId ?? '',
          checkedOverrides: checkedOverrides,
          onCheck: onCheckItem,
        );
      case AvoPayloadKind.lists:
        return _ListOverview(lists: p.lists ?? [], onTap: onListTap);
      case AvoPayloadKind.history:
        return _HistoryView(
          history: p.history ?? [],
          onAddAll: (entry) => onAddHistoryItem(entry, null),
          onAddOne: (entry, item) => onAddHistoryItem(entry, item),
        );
      case AvoPayloadKind.pickList:
        return _PickListView(data: p.pickListData!, onPick: onPickList);
      case AvoPayloadKind.nutrition:
        return _NutritionCard(data: p.nutrition!);
      case AvoPayloadKind.settingChange:
        return _SettingChangeCard(result: p.settingChange!);
      case AvoPayloadKind.appInfo:
        return _AppInfoCard(data: p.appInfo!);
      case AvoPayloadKind.confirmDelete:
        return AvoConfirmDeleteCard(pending: p.pendingDelete!);
      case AvoPayloadKind.consentRequest:
        return AvoConsentCard(kind: p.consentKind!);
    }
  }
}

// ════════════════════════════════════════════════════════
// RICH: Recipe Cards (horizontal scroll)
// ════════════════════════════════════════════════════════

class _RecipeCards extends StatelessWidget {
  final List<Recipe> recipes;
  final void Function(String) onTap;
  const _RecipeCards({required this.recipes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final r = recipes[i];
          return GestureDetector(
            onTap: () => onTap(r.id),
            child: Container(
              width: 200,
              decoration: _cardDecoration(context, darkFillAlpha: 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: r.imageUrl.isNotEmpty
                        ? Image.network(r.imageUrl, height: 80, width: 200, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.textTertiary(context)),
                      const SizedBox(width: 3),
                      Text('${r.totalTimeMinutes}m', style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context))),
                      if (r.averageRating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(r.averageRating.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context))),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 80, width: 200,
    color: AppColors.freshGreen.withValues(alpha: 0.15),
    child: const Icon(Icons.restaurant_rounded, color: AppColors.freshGreen, size: 28),
  );
}

// ════════════════════════════════════════════════════════
// RICH: List Items with check toggles
// ════════════════════════════════════════════════════════

class _ListItemsView extends StatelessWidget {
  final List<ShoppingItemModel> items;
  final String listName;
  final String listId;
  final Map<String, bool> checkedOverrides;
  final Future<void> Function(String, String, bool) onCheck;
  const _ListItemsView({
    required this.items,
    required this.listName,
    required this.listId,
    required this.checkedOverrides,
    required this.onCheck,
  });

  bool _isChecked(ShoppingItemModel item) => checkedOverrides[item.id] ?? item.isChecked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unchecked = items.where((i) => !_isChecked(i)).toList();
    final checkedCount = items.length - unchecked.length;

    return Container(
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(Icons.checklist_rounded, size: 16, color: AppColors.accentColor(context)),
              const SizedBox(width: 8),
              Text(listName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
              const Spacer(),
              Text(context.tr('avo_items_left', params: {'count': '${unchecked.length}'}),
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
            ]),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : PaperColors.hairline),
          // Only unchecked items are listed; checked ones collapse to a count.
          ...unchecked.take(10).map((item) => _itemRow(context, item)),
          if (checkedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Text(context.tr('avo_items_checked', params: {'count': '$checkedCount'}),
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
            ),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, ShoppingItemModel item) {
    return GestureDetector(
      onTap: () => onCheck(item.id, listId, _isChecked(item)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textTertiary(context), width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            item.name,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
          )),
          if (item.quantity > 1 || (item.unit != null && item.unit!.isNotEmpty))
            Text(
              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context)),
            ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: List Overview cards
// ════════════════════════════════════════════════════════

class _ListOverview extends StatelessWidget {
  final List<ShoppingListModel> lists;
  final void Function(ShoppingListModel) onTap;
  const _ListOverview({required this.lists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return Text(context.tr('avo_no_lists'),
          style: TextStyle(color: AppColors.textTertiary(context), fontSize: 14));
    }
    return Column(
      children: lists.take(5).map((list) => GestureDetector(
        onTap: () => onTap(list),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _cardDecoration(context, radius: 12),
          child: Row(children: [
            Icon(Icons.list_rounded, size: 18, color: AppColors.accentColor(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(list.name, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context),
            ))),
            Text('${list.itemCount ?? 0}', style: TextStyle(fontSize: 13, color: AppColors.textTertiary(context))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary(context)),
          ]),
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Shopping History
// ════════════════════════════════════════════════════════

class _HistoryView extends StatelessWidget {
  final List<ShoppingHistory> history;
  final Future<void> Function(ShoppingHistory entry) onAddAll;
  final Future<void> Function(ShoppingHistory entry, ShoppingHistoryItem item) onAddOne;
  const _HistoryView({
    required this.history,
    required this.onAddAll,
    required this.onAddOne,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (history.isEmpty) {
      return Text(
        context.tr('avo_no_history'),
        style: TextStyle(color: AppColors.textTertiary(context), fontSize: 14),
      );
    }
    return Column(
      children: history.take(5).map((h) {
        final date = '${h.completedAt.day}/${h.completedAt.month}/${h.completedAt.year}';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: _cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.accentColor(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.listName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                Text(date,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary(context))),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: h.items.take(12).map((item) {
                  return GestureDetector(
                    onTap: () => onAddOne(h, item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : PaperColors.hairline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 12,
                              color: AppColors.accentColor(context)),
                          const SizedBox(width: 4),
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (h.items.length > 12)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      context.tr('avo_more_items', params: {'count': '${h.items.length - 12}'}),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary(context))),
                ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => onAddAll(h),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add_rounded,
                          size: 16, color: AppColors.accentColor(context)),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('avo_add_all_items', params: {'count': '${h.items.length}'}),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Pick List (for add item)
// ════════════════════════════════════════════════════════

class _PickListView extends ConsumerWidget {
  final AvoPickListData data;
  final Future<void> Function(String, AvoPickListData) onPick;
  const _PickListView({required this.data, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const <ShoppingListModel>[];

    if (lists.isEmpty) {
      return Text(context.tr('avo_no_lists_available'),
          style: TextStyle(color: AppColors.textTertiary(context)));
    }

    return Column(
      children: lists.take(3).map((list) => GestureDetector(
        onTap: () => onPick(list.id, data),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.accentColor(context).withValues(alpha: 0.08)
                : AppColors.accentColor(context).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentColor(context).withValues(alpha: 0.20)),
          ),
          child: Row(children: [
            Icon(Icons.add_rounded, size: 18, color: AppColors.accentColor(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(list.name, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context),
            ))),
            Text(context.tr('avo_items_count', params: {'count': '${list.itemCount ?? 0}'}),
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
          ]),
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Nutrition Card
// ════════════════════════════════════════════════════════

class _NutritionCard extends StatelessWidget {
  final AvoNutritionData data;
  const _NutritionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_fire_department_rounded,
                size: 16, color: AppColors.accentColor(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.recipeName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(context.tr('avo_per_serving'),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textTertiary(context))),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macro(context, 'kcal',
                  data.calories != null ? '${data.calories}' : '—'),
              _macro(context, context.tr('protein'),
                  data.proteinG != null ? '${data.proteinG!.round()}g' : '—'),
              _macro(context, context.tr('carbs'),
                  data.carbsG != null ? '${data.carbsG!.round()}g' : '—'),
              _macro(context, context.tr('fat'),
                  data.fatG != null ? '${data.fatG!.round()}g' : '—'),
            ],
          ),
          if (data.estimated) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('avo_estimated_from_ingredients'),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macro(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Setting Change Confirmation
// ════════════════════════════════════════════════════════

class _SettingChangeCard extends StatelessWidget {
  final SettingChangeResult result;
  const _SettingChangeCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = result.success
        ? AppColors.accentColor(context)
        : Colors.red.shade400;
    final setting = {'setting': result.displayName};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? accent.withValues(alpha: 0.08)
            : accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.success
                      ? context.tr('avo_setting_updated', params: setting)
                      : context.tr('avo_setting_failed', params: setting),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.success
                      ? (result.oldValue != null
                          ? '${result.oldValue}  →  ${result.newValue}'
                          : result.newValue)
                      : (result.error ?? context.tr('avo_unknown_error')),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: App Info Card
// ════════════════════════════════════════════════════════

class _AppInfoCard extends StatelessWidget {
  final AvoAppInfoData data;
  const _AppInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.accentColor(context)),
            const SizedBox(width: 6),
            Text(
              data.topic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.accentColor(context),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            data.answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
