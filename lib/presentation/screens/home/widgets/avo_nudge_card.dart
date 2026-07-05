import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/presentation/state/avo_nudge_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Home-screen card with Avo's restock suggestions ("you buy milk about
/// every 5 days — last bought 8 days ago"), computed from the user's own
/// purchase rhythm. One-tap add to the most recently used list, or dismiss
/// to snooze the item for one of its own purchase cycles.
/// Renders nothing when nothing is due.
class AvoNudgeCard extends ConsumerWidget {
  const AvoNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions =
        ref.watch(restockSuggestionsProvider).valueOrNull ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AvoMascot(size: 22, expression: AvoExpression.thinking),
                const SizedBox(width: 8),
                Text(
                  context.tr('restock_title').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            for (final suggestion in suggestions)
              _SuggestionRow(
                suggestion: suggestion,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
                onAdd: () => _addToList(context, ref, suggestion),
                onSnooze: () => _snooze(ref, suggestion),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToList(
    BuildContext context,
    WidgetRef ref,
    RestockSuggestion suggestion,
  ) async {
    HapticFeedback.lightImpact();
    try {
      final lists = await ref.read(userListsProvider.future);
      if (lists.isEmpty) return;

      // Add to the most recently touched list.
      final sorted = List<ShoppingListModel>.from(lists)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final target = sorted.first;

      await ref.read(itemRepositoryProvider).addItem(
            listId: target.id,
            name: suggestion.displayName,
            quantity: suggestion.preferredQuantity ?? 1.0,
            category: suggestion.preferredCategory,
            // The name comes from the user's own purchase stats — no need
            // for the Gemini free-text parse pass.
            autoParse: false,
          );

      ref.invalidate(listItemsProvider(target.id));
      ref.invalidate(itemsByCategoryProvider(target.id));
      ref.invalidate(restockSuggestionsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('restock_added_to', params: {
              'item': suggestion.displayName,
              'list': target.name,
            })),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to add suggestion: $e');
    }
  }

  Future<void> _snooze(WidgetRef ref, RestockSuggestion suggestion) async {
    HapticFeedback.selectionClick();
    await AvoNudgeService.instance.snooze(suggestion);
    ref.invalidate(restockSuggestionsProvider);
  }
}

class _SuggestionRow extends StatelessWidget {
  final RestockSuggestion suggestion;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onSnooze;

  const _SuggestionRow({
    required this.suggestion,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAdd,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.tr('restock_line', params: {
                      'avg': '${suggestion.averageDays}',
                      'days': '${suggestion.daysSince}',
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  context.tr('restock_add_action'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onSnooze,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
                child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
