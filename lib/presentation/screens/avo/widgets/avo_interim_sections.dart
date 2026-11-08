import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_destinations.dart';

// Cards of the tools that get their full design in later slices (Kap.
// 5.2, 5.3, 5.7); kept simple so their answers keep working.

/// Rows of a card: at most 8.
const int _maxRows = 8;

/// Recipe rows of a card (Kap. 5.3): at most three.
const int _maxRecipes = 3;
const double _recipeImage = 56; // D2

/// `update_setting`: "Darstellung / Dunkel, vorher System".
Widget avoSettingSection(BuildContext context, SettingChangeResult result) {
  final setting = {'setting': result.displayName};
  if (!result.success) {
    return AvoResultSection(
      title: context.tr('avo_setting_failed', params: setting),
      leading: AvoSymbolTile(
        neutral: true,
        icon: Icon(
          CupertinoIcons.exclamationmark_circle,
          color: context.colors.destructive,
        ),
      ),
    );
  }
  final old = result.oldValue;
  return AvoResultSection(
    title: result.displayName,
    subtitle: old == null
        ? result.newValue
        : context.tr(
            'avo_card_was',
            params: {'value': result.newValue, 'old': old},
          ),
    leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.gear)),
  );
}

/// `get_app_info`: the topic and Avo's answer.
Widget avoAppInfoSection(BuildContext context, AvoAppInfoData info) =>
    AvoResultSection(
      title: info.topic,
      leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.info)),
      details: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
          child: Text(info.answer, style: context.text(AvoTextStyle.body)),
        ),
      ],
    );

/// Recipes found or saved (interim until the recipe cards of Kap. 5.3).
class AvoRecipesSection extends StatelessWidget {
  const AvoRecipesSection({super.key, required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    return AvoResultSection(
      title: context.tr('avo_card_recipes'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.forkKnife)),
      detailIndent: ax
          ? AvoSpacing.l
          : AvoSpacing.l + _recipeImage + AvoSpacing.m,
      details: [
        for (final r in recipes.take(_maxRecipes))
          Semantics(
            container: true,
            button: true,
            label:
                '${r.name}, '
                '${context.tr('avo_card_minutes', params: {'n': '${r.totalTimeMinutes}'})}',
            excludeSemantics: true,
            onTap: () =>
                openAppDestination(context, AppDestinations.recipe(r.id)),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  openAppDestination(context, AppDestinations.recipe(r.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.l,
                  vertical: AvoSpacing.s,
                ),
                child: Row(
                  children: [
                    if (!ax) ...[
                      ItemThumb(
                        size: _recipeImage,
                        radius: AvoRadii.imageSmall,
                        image: r.imageUrl.isEmpty
                            ? null
                            : NetworkImage(r.imageUrl),
                      ),
                      const SizedBox(width: AvoSpacing.m),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text(AvoTextStyle.headline),
                          ),
                          Text(
                            context.tr(
                              'avo_card_minutes',
                              params: {'n': '${r.totalTimeMinutes}'},
                            ),
                            style: context.text(
                              AvoTextStyle.footnote,
                              color: colors.secondaryLabel,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shopping trips (interim until the history cards of Kap. 5.2), with "Alle
/// wieder auf {Liste}" for the newest trip.
class AvoHistorySection extends ConsumerWidget {
  const AvoHistorySection({super.key, required this.history});

  final List<ShoppingHistory> history;

  Future<void> _addAll(
    BuildContext context,
    ShoppingHistory trip,
    ShoppingListModel list,
  ) async {
    final message = avoTrCount(
      context,
      'avo_card_history_added',
      trip.items.length,
      {'list': list.name},
    );
    final undo = context.tr('avo_undo');
    try {
      final result = await ItemRepository.instance.addItems(list.id, [
        for (final i in trip.items)
          NewItem(
            name: i.name,
            quantity: i.quantity,
            unit: i.unit,
            category: i.category,
          ),
      ]);
      if (!context.mounted) return;
      AvoToast.show(
        context,
        message: message,
        actionLabel: undo,
        onAction: () => ItemRepository.instance.undoAddItems(result.token),
      );
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Trip not added: $e');
      unawaited(AvoHaptics.error());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lists = ref.watch(avoListsProvider);
    final target = lists.isEmpty ? null : lists.first;
    final newest = history.first;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    return AvoResultSection(
      title: context.tr('avo_card_trips'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.clock)),
      details: [
        for (final h in history.take(_maxRows))
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(h.listName, style: context.text(AvoTextStyle.body)),
                Text(
                  [
                    DateFormat.MMMEd(locale).format(h.completedAt),
                    avoTrCount(context, 'avo_card_items', h.items.length),
                  ].join(' · '),
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
      ],
      actions: [
        if (target != null && newest.items.isNotEmpty)
          AvoCardAction(
            label: context.tr(
              'avo_card_history_add_all',
              params: {'list': target.name},
            ),
            onPressed: () => _addAll(context, newest, target),
          ),
      ],
    );
  }
}

/// Nutrition of a recipe (interim until the cards of Kap. 5.3).
class AvoNutritionSection extends StatelessWidget {
  const AvoNutritionSection({super.key, required this.data});

  final AvoNutritionData data;

  @override
  Widget build(BuildContext context) {
    String grams(double? g, String key) =>
        g == null ? '' : '${g.round()} g ${context.tr(key)}';
    final parts = [
      if (data.calories != null) '${data.calories} kcal',
      grams(data.proteinG, 'protein'),
      grams(data.carbsG, 'carbs'),
      grams(data.fatG, 'fat'),
    ].where((p) => p.isNotEmpty).join(' · ');
    return AvoResultSection(
      title: data.recipeName,
      subtitle: parts,
      leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.flame)),
      footnote: [
        context.tr('avo_per_serving'),
        if (data.estimated) context.tr('avo_estimated_from_ingredients'),
      ].join(' · '),
    );
  }
}
