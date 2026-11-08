import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/item_quantity.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_adaptation.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_texts.dart';
import 'package:shoply/presentation/screens/recipes/widgets/servings_stepper.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

// "Zutaten auf die Liste" (Konzept 13 §13, R-11): a full screen instead of
// the sheet the concept describes (owner rule: no sheets).

/// Minimum height of the rows here (D2 settings rows).
const double _rowMinHeight = 52; // D2

/// Gap between the selection circle and the text.
const double _circleGap = AvoSpacing.xs;

/// What "Zutaten auf die Liste" closes with: the target list and the items.
class AddIngredientsResult {
  const AddIngredientsResult({
    required this.recipeId,
    required this.listName,
    required this.items,
    this.listId,
  });

  final String recipeId;

  /// The chosen list; null creates a new list called [listName].
  final String? listId;
  final String listName;

  /// What goes on the list, already scaled, merged and adapted.
  final List<NewItem> items;

  bool get createsList => listId == null;
}

/// Opens "Zutaten auf die Liste" for [recipe] at [servings] (the one entry
/// point; Teil "browse" uses it for the hero button). [adapted] starts in
/// "Für dich angepasst" (default) or "Original". After "Hinzufügen" the
/// screen closes at once and the items land in one batch with an undo toast.
Future<void> openIngredientsToList(
  BuildContext context, {
  required Recipe recipe,
  required int servings,
  bool adapted = true,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // Toasts go through the caller while it is there (the detail stays), else
  // through the app's toast host above the root navigator.
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final result = await pushFullScreenEditor<AddIngredientsResult>(
    context,
    (_) => RecipeToListScreen(
      recipe: recipe,
      servings: servings,
      adapted: adapted,
    ),
  );
  if (result == null) return;
  final toastContext = context.mounted ? context : rootContext;
  if (!toastContext.mounted) return;
  await showAddIngredientsResult(toastContext, result, container: container);
}

/// Puts [result] on its list in one batch (creating the list first if
/// needed) and shows "8 Zutaten auf Wocheneinkauf · Widerrufen" at once;
/// "Widerrufen" takes the whole batch back. A failure replaces the toast
/// with "Zutaten nicht hinzugefügt · Erneut versuchen".
Future<void> showAddIngredientsResult(
  BuildContext context,
  AddIngredientsResult result, {
  ProviderContainer? container,
}) async {
  final c = container ?? ProviderScope.containerOf(context, listen: false);
  final repository = c.read(itemRepositoryProvider);
  final count = result.items.length;
  if (count == 0) return;
  final message = count == 1
      ? context.tr(
          'recipe_detail_tolist_added_one',
          params: {'list': result.listName},
        )
      : context.tr(
          'recipe_detail_tolist_added_many',
          params: {'count': '$count', 'list': result.listName},
        );
  final undo = context.tr('common_undo');
  final failed = context.tr('recipe_detail_tolist_failed');
  final retry = context.tr('common_try_again');
  final undoFailed = context.tr('recipe_detail_tolist_undo_failed');

  final actions = c.read(recipeDetailActionsProvider);
  void refresh(String listId) => actions.refreshList(c, listId);

  Future<(String, String)> add() async {
    var listId = result.listId;
    if (listId == null) {
      final created = await actions.createList(c, result.listName);
      listId = created.id;
    }
    rememberRecipeTargetList(c, result.recipeId, listId);
    final added = await repository.addItems(listId, result.items);
    refresh(listId);
    // Tip T6 has done its job (Konzept 17 §6.1).
    c.read(tipServiceProvider).markDone(TipId.recipeToList);
    return (listId, added.token);
  }

  final batch = add();
  AvoToast.show(
    context,
    message: message,
    actionLabel: undo,
    onAction: () async {
      try {
        final (listId, token) = await batch;
        await repository.undoAddItems(token);
        refresh(listId);
      } catch (e) {
        debugPrint('❌ [RECIPE_TO_LIST] Undo failed: $e');
        if (context.mounted) AvoToast.show(context, message: undoFailed);
      }
    },
  );
  try {
    await batch;
  } catch (e) {
    debugPrint('❌ [RECIPE_TO_LIST] Add failed: $e');
    unawaited(AvoHaptics.error());
    if (!context.mounted) return;
    AvoToast.show(
      context,
      message: failed,
      actionLabel: retry,
      onAction: () => showAddIngredientsResult(context, result, container: c),
    );
  }
}

/// One line of the list here: a recipe ingredient (merged, scaled, adapted).
class _Row {
  _Row({required this.key, required this.info, required this.ingredient});

  final String key;
  final AdaptedIngredient info;
  final Ingredient ingredient;
  ShoppingItemModel? onList;
  bool staple = false;

  /// Preselection (Konzept 13 §13.1 Nr. 3): off when it is on the list
  /// already or a basic people have at home; allergens stay on.
  bool get suggested => onList == null && !staple;
}

/// The full screen behind [openIngredientsToList]: target list (menu),
/// servings, "Für dich angepasst | Original", every ingredient with a
/// selection circle, and "8 Zutaten hinzufügen" at the bottom. Pops with an
/// [AddIngredientsResult]; the close button pops with nothing.
class RecipeToListScreen extends ConsumerStatefulWidget {
  const RecipeToListScreen({
    super.key,
    required this.recipe,
    required this.servings,
    this.adapted = true,
  });

  final Recipe recipe;
  final int servings;
  final bool adapted;

  @override
  ConsumerState<RecipeToListScreen> createState() => _RecipeToListScreenState();
}

class _RecipeToListScreenState extends ConsumerState<RecipeToListScreen> {
  final _listKey = GlobalKey(debugLabel: 'toListTarget');
  late int _servings = widget.servings;
  late bool _adapted = widget.adapted;

  /// A list picked here; null uses the recipe's target list.
  String? _listId;

  /// A list to create on "Hinzufügen" ("Neue Liste" in the menu).
  String? _newListName;

  /// Rows the person ticked or unticked themselves; these keep their state
  /// when the list or the servings change.
  final Map<String, bool> _chosen = {};

  RecipeAdaptation? _adaptation;
  Object? _adaptationUser;

  RecipeAdaptation _adaptationFor(Object? user) {
    final known = _adaptation;
    if (known != null && identical(user, _adaptationUser)) return known;
    _adaptationUser = user;
    return _adaptation = RecipeAdaptation.of(
      widget.recipe,
      RecipeDietProfile.ofUser(ref.read(currentUserProvider).valueOrNull),
    );
  }

  List<_Row> _rows(RecipeAdaptation adaptation, bool adapted) {
    final recipe = widget.recipe;
    final byKey = <String, _Row>{};
    for (final info in adaptation.ingredients) {
      final scaled = scaleIngredient(
        info.shown(adapted: adapted),
        recipe.defaultServings,
        _servings,
      );
      final key =
          '${recipeTokens(scaled.name).join(' ')}|'
          '${recipeTokens(scaled.unit).join(' ')}';
      final prev = byKey[key];
      if (prev == null) {
        byKey[key] = _Row(key: key, info: info, ingredient: scaled);
      } else {
        // The same ingredient twice ("2 EL Olivenöl", "1 EL Olivenöl").
        final sum = mergeIngredients([prev.ingredient, scaled]).single;
        byKey[key] = _Row(key: key, info: prev.info, ingredient: sum);
      }
    }
    return byKey.values.toList(growable: false);
  }

  ({String? id, String name, bool isNew}) _target(
    List<ShoppingListModel> lists,
    ShoppingListModel? suggested,
  ) {
    final fresh = _newListName;
    if (fresh != null) return (id: null, name: fresh, isNew: true);
    final picked = _listId;
    if (picked != null) {
      for (final l in lists) {
        if (l.id == picked) return (id: l.id, name: l.name, isNew: false);
      }
    }
    if (suggested != null) {
      return (id: suggested.id, name: suggested.name, isNew: false);
    }
    return (
      id: null,
      name: context.tr('recipe_detail_tolist_default_name'),
      isNew: true,
    );
  }

  Future<void> _pickList(List<ShoppingListModel> lists, String? current) {
    return showAvoMenu(
      context,
      anchorKey: _listKey,
      items: [
        for (final l in lists)
          AvoMenuItem(
            label: l.name,
            subtitle: (l.uncheckedCount ?? 0) > 0
                ? context.tr(
                    'recipe_detail_tolist_open_count',
                    params: {'count': '${l.uncheckedCount}'},
                  )
                : null,
            checked: l.id == current,
            onSelected: () => setState(() {
              _listId = l.id;
              _newListName = null;
            }),
          ),
        const AvoMenuDivider(),
        AvoMenuItem(
          label: context.tr('recipe_detail_tolist_new_list'),
          icon: AvoIcons.plus,
          onSelected: _askNewList,
        ),
      ],
    );
  }

  Future<void> _askNewList() async {
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => const _NewListDialog(),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      _newListName = trimmed;
      _listId = null;
    });
  }

  void _submit(List<_Row> rows, ({String? id, String name, bool isNew}) to) {
    final items = [
      for (final row in rows)
        if (_chosen[row.key] ?? row.suggested)
          recipeIngredientToItem(row.ingredient),
    ];
    if (items.isEmpty) return;
    Navigator.of(context).pop(
      AddIngredientsResult(
        recipeId: widget.recipe.id,
        listId: to.id,
        listName: to.name,
        items: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final adaptation = _adaptationFor(user);
    final adapted = _adapted && adaptation.hasSubstitutes;
    final lists = ref.watch(recipeTargetListsProvider);
    final to = _target(
      lists,
      ref.watch(recipeTargetListProvider(widget.recipe.id)),
    );
    final targetId = to.id;
    final openItems = targetId == null
        ? null
        : ref.watch(recipeListOpenItemsProvider(targetId));
    final language = Localizations.localeOf(context).languageCode;

    final rows = _rows(adaptation, adapted);
    for (final row in rows) {
      row.staple = isStapleIngredient(row.ingredient.name);
      if (openItems == null) continue;
      for (final item in openItems) {
        if (sameShoppingName(row.ingredient.name, item.name)) {
          row.onList = item;
          break;
        }
      }
    }
    final count = rows.where((r) => _chosen[r.key] ?? r.suggested).length;
    final allThere =
        rows.isNotEmpty &&
        openItems != null &&
        rows.every((r) => r.onList != null);

    final label = count == 0
        ? context.tr('recipe_detail_tolist_none')
        : count == 1
        ? context.tr('recipe_detail_tolist_add_one')
        : context.tr(
            'recipe_detail_tolist_add_many',
            params: {'count': '$count'},
          );

    final listValue = to.isNew
        ? context.tr(
            'recipe_detail_tolist_new_list_value',
            params: {'name': to.name},
          )
        : to.name;

    return FullScreenEditor(
      title: context.tr('recipe_detail_to_list'),
      bottom: AppButton.primary(
        label: label,
        icon: const AvoIcon(AvoIcons.cart),
        size: AppButtonSize.large,
        expand: true,
        onPressed: count == 0 ? null : () => _submit(rows, to),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsetSection(
            children: [
              _ValueRow(
                title: context.tr('recipe_detail_tolist_list'),
                value: listValue,
                valueKey: _listKey,
                onTap: () => _pickList(lists, targetId),
              ),
              _StepperRow(
                title: context.tr('recipe_detail_servings'),
                stepper: ServingsStepper(
                  value: _servings,
                  onChanged: (v) => setState(() => _servings = v),
                ),
              ),
              if (adaptation.hasSubstitutes)
                Padding(
                  padding: const EdgeInsets.all(AvoSpacing.m),
                  child: AppSegmentedControl<bool>(
                    semanticLabel: context.tr('recipe_detail_variant'),
                    selected: adapted,
                    onChanged: (v) => setState(() => _adapted = v),
                    segments: [
                      SegmentItem(
                        value: true,
                        label: context.tr('recipe_detail_variant_adapted'),
                      ),
                      SegmentItem(
                        value: false,
                        label: context.tr('recipe_detail_variant_original'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (allThere)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.xxxl,
                AvoSpacing.section,
                AvoSpacing.xxxl,
                0,
              ),
              child: Text(
                context.tr(
                  'recipe_detail_tolist_all_there',
                  params: {'list': to.name},
                ),
                style: context.text(AvoTextStyle.subhead),
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AvoSpacing.xxxl),
              child: Text(
                context.tr('recipe_detail_tolist_empty'),
                textAlign: TextAlign.center,
                style: context.text(
                  AvoTextStyle.body,
                  color: context.colors.secondaryLabel,
                ),
              ),
            )
          else
            InsetSection(
              header: context.tr('recipe_detail_ingredients'),
              headerTrailing: Text(
                context.tr(
                  'recipe_detail_tolist_count',
                  params: {'selected': '$count', 'total': '${rows.length}'},
                ),
              ),
              separatorIndent: AvoSpacing.l + AvoSizes.checkCircle + _circleGap,
              children: [
                for (final row in rows)
                  _PickRow(
                    key: ValueKey(row.key),
                    name: row.ingredient.name,
                    amount: formatRecipeAmount(row.ingredient, language),
                    subline: _subline(context, row, to.name, language, adapted),
                    allergen: row.info.allergens.isEmpty
                        ? null
                        : recipeAllergenName(context, row.info.allergens.first),
                    selected: _chosen[row.key] ?? row.suggested,
                    onTap: () => setState(
                      () => _chosen[row.key] =
                          !(_chosen[row.key] ?? row.suggested),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String? _subline(
    BuildContext context,
    _Row row,
    String listName,
    String language,
    bool adapted,
  ) {
    final lines = <String>[];
    final item = row.onList;
    if (item != null) {
      final quantity = formatQuantity(
        item.quantity,
        item.unit,
        languageCode: language,
      );
      lines.add(
        quantity == null
            ? context.tr('recipe_detail_on_list', params: {'list': listName})
            : context.tr(
                'recipe_detail_on_list_quantity',
                params: {'list': listName, 'quantity': quantity},
              ),
      );
    } else if (row.staple) {
      lines.add(context.tr('recipe_detail_tolist_staple'));
    }
    if (adapted) {
      final instead = recipeInsteadText(context, row.info);
      if (instead != null) lines.add(instead);
    }
    return lines.isEmpty ? null : lines.join('\n');
  }
}

/// Title and a tappable value with the up-down chevron ("Liste
/// Wocheneinkauf ⌃⌄"); the menu grows out of the value. Stacks from AX1 on.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.title,
    required this.value,
    required this.valueKey,
    required this.onTap,
  });

  final String title;
  final String value;
  final GlobalKey valueKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titleText = Text(title, style: context.text(AvoTextStyle.body));
    final valueText = Row(
      key: valueKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            style: context.text(AvoTextStyle.body, color: colors.tint),
          ),
        ),
        const SizedBox(width: AvoSpacing.xs),
        Icon(
          CupertinoIcons.chevron_up_chevron_down,
          size: context.typography.sizeOf(AvoTextStyle.footnote),
          color: colors.tint,
        ),
      ],
    );
    return Semantics(
      button: true,
      label: '$title, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m,
            ),
            child: context.isAccessibilityText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleText, valueText],
                  )
                : Row(
                    children: [
                      titleText,
                      const SizedBox(width: AvoSpacing.m),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: valueText,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A title with a stepper at the end; the stepper moves below from AX1 on.
class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.title, required this.stepper});

  final String title;
  final Widget stepper;

  @override
  Widget build(BuildContext context) {
    final titleText = ExcludeSemantics(
      child: Text(title, style: context.text(AvoTextStyle.body)),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.xs,
        ),
        child: context.isAccessibilityText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AvoSpacing.s),
                    child: titleText,
                  ),
                  stepper,
                ],
              )
            : Row(
                children: [
                  Expanded(child: titleText),
                  stepper,
                ],
              ),
      ),
    );
  }
}

/// One ingredient with its selection circle. The whole row toggles, without
/// haptics (Konzept 13 §13.5); VoiceOver reads name, amount, subline and
/// the selected state. From xxxL on the amount moves under the name.
class _PickRow extends StatelessWidget {
  const _PickRow({
    super.key,
    required this.name,
    required this.amount,
    required this.selected,
    required this.onTap,
    this.subline,
    this.allergen,
  });

  final String name;
  final String amount;
  final String? subline;

  /// The allergen it contains ("Erdnuss"): a warning sign after the name.
  final String? allergen;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stacked =
        context.typography.category.index >= ContentSizeCategory.xxxLarge.index;
    final warning = allergen;
    final nameText = Text.rich(
      TextSpan(
        text: name,
        children: [
          if (warning != null) ...[
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: context.typography.sizeOf(AvoTextStyle.subhead),
                color: colors.destructive,
              ),
            ),
          ],
        ],
      ),
      style: context.text(AvoTextStyle.body),
    );
    final amountText = amount.isEmpty
        ? null
        : Text(
            amount,
            style: context.text(
              AvoTextStyle.body,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          );
    final sub = subline;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        nameText,
        if (stacked && amountText != null) amountText,
        if (sub != null)
          Text(
            sub,
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
      ],
    );

    final label = [
      name,
      if (amount.isNotEmpty) amount,
      if (warning != null)
        context.tr(
          'recipe_detail_contains_short',
          params: {'allergen': warning},
        ),
      ?sub,
    ].join(', ');

    return Semantics(
      button: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AvoSpacing.l - (AvoSizes.hitTarget - AvoSizes.checkCircle) / 2,
              AvoSpacing.xs,
              AvoSpacing.l,
              AvoSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: stacked || sub != null
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: CheckCircle(
                      checked: selected,
                      itemName: name,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                const SizedBox(width: _circleGap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
                    child: details,
                  ),
                ),
                if (!stacked && amountText != null) ...[
                  const SizedBox(width: AvoSpacing.m),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
                    child: amountText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Neue Liste" with a name field, as a centred alert (Konzept 13 §13.4).
class _NewListDialog extends StatefulWidget {
  const _NewListDialog();

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  TextEditingController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= TextEditingController(
      text: context.tr('recipe_detail_tolist_default_name'),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return CupertinoAlertDialog(
      title: Text(context.tr('recipe_detail_tolist_new_list')),
      content: Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.m),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: context.tr('recipe_detail_tolist_new_list_hint'),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(context.tr('recipe_detail_tolist_create')),
        ),
      ],
    );
  }
}
