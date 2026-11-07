import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/screens/recipes/widgets/servings_stepper.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Outcome of adding a recipe's ingredients to a list; the sheet pops with
/// it so the still-mounted caller can show the confirmation.
class AddIngredientsResult {
  final String listId;
  final int total;
  final int added;
  final List<String> failedNames;

  const AddIngredientsResult({
    required this.listId,
    required this.total,
    required this.added,
    required this.failedNames,
  });
}

/// Shows the success HUD, or a snackbar for partial/total failure.
void showAddIngredientsResult(BuildContext context, AddIngredientsResult result) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (result.added > 0 && result.failedNames.isEmpty) {
    _showSuccessHUD(context, isDark);
  } else if (result.added > 0) {
    final names = result.failedNames.take(3).join(', ') +
        (result.failedNames.length > 3 ? '…' : '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('ingredients_added_partial', params: {
          'added': '${result.added}',
          'total': '${result.total}',
          'names': names,
        })),
        backgroundColor: CupertinoColors.systemOrange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: context.tr('view_action'),
          textColor: Colors.white,
          onPressed: () => context.push('/lists/${result.listId}'),
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('ingredients_add_failed')),
        backgroundColor: CupertinoColors.systemRed,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

void _showSuccessHUD(BuildContext context, bool isDark) {
  showCupertinoDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
        if (ctx.mounted) Navigator.pop(ctx);
      });
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.checkmark_circle_fill,
                    size: 44, color: CupertinoColors.systemGreen),
                const SizedBox(height: 8),
                Text(
                  context.tr('added'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Picks a list and adds the recipe's ingredients to it. Pops with an
/// [AddIngredientsResult] once the add finished (null when cancelled).
class SelectListBottomSheet extends ConsumerStatefulWidget {
  /// Ingredients as currently shown, already scaled to [recipeDefaultServings].
  final List<IngredientWithSubstitution> ingredientsWithInfo;

  /// Servings the stepper starts at.
  final int defaultServings;

  /// Servings [ingredientsWithInfo] are scaled to; the sheet only scales by
  /// its own stepper change relative to this.
  final int recipeDefaultServings;
  final bool useAdaptedIngredients;

  /// Current offers for the recipe's ingredients, keyed by lowercased
  /// ingredient name — matched ingredients are added with their offer
  /// price/retailer attached so they count into the list's price total.
  final Map<String, RecipeIngredientOffer> ingredientOffers;

  const SelectListBottomSheet({
    super.key,
    required this.ingredientsWithInfo,
    this.defaultServings = 2,
    this.recipeDefaultServings = 2,
    this.useAdaptedIngredients = true,
    this.ingredientOffers = const {},
  });

  @override
  ConsumerState<SelectListBottomSheet> createState() =>
      _SelectListBottomSheetState();
}

class _SelectListBottomSheetState extends ConsumerState<SelectListBottomSheet> {
  late int _servings;
  late bool _useAdapted;
  String? _selectedListId;
  String? _selectedListName;

  /// Number of ingredients processed so far while the add runs; null when idle.
  int? _addProgress;
  bool get _isAdding => _addProgress != null;

  @override
  void initState() {
    super.initState();
    _servings = widget.defaultServings;
    _useAdapted = widget.useAdaptedIngredients;
  }

  List<Ingredient> get _finalIngredients {
    return widget.ingredientsWithInfo.map((info) {
      final ingredient = _useAdapted ? info.adaptedIngredient : info.original;
      return ingredient.adjustForServings(
          widget.recipeDefaultServings, _servings);
    }).toList();
  }

  bool get _hasSubstitutions {
    return widget.ingredientsWithInfo
        .any((info) => info.needsSubstitution && info.bestSubstitute != null);
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(userListsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : PaperColors.surface;
    final separatorColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.hairline;

    // Keep the sheet open while adding: closing it mid-way used to drop the
    // confirmation and the list refresh.
    return PopScope(
      canPop: !_isAdding,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(isDark),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Servings row
                  _buildServingsRow(isDark, cardColor),
                  const SizedBox(height: 16),

                  // Substitution toggle
                  if (_hasSubstitutions) ...[
                    _buildSubstitutionToggle(isDark, cardColor),
                    const SizedBox(height: 16),
                  ],

                  // List selection or confirmation
                  if (_selectedListId != null)
                    _buildConfirmationView(
                        isDark, cardColor, separatorColor)
                  else
                    listsAsync.when(
                      data: (lists) => _buildListSelection(
                          lists, isDark, cardColor, separatorColor),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(context.tr('error'),
                            style: TextStyle(
                                color: CupertinoColors.systemRed
                                    .resolveFrom(context))),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          if (_selectedListId != null) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _isAdding ? null : () => setState(() {
                _selectedListId = null;
                _selectedListName = null;
              }),
              child: Icon(
                CupertinoIcons.chevron_back,
                size: 22,
                color: CupertinoColors.systemBlue.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              _selectedListId != null
                  ? _selectedListName ?? ''
                  : context.tr('add_to_shopping_list'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : PaperColors.ink,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _isAdding ? null : () => Navigator.pop(context),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.xmark,
                size: 13,
                color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingsRow(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.person_2_fill,
              size: 18,
              color: CupertinoColors.systemGrey.resolveFrom(context)),
          const SizedBox(width: 10),
          Text(
            context.tr('servings'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          ServingsStepper(
            value: _servings,
            onChanged: (v) {
              if (!_isAdding) setState(() => _servings = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubstitutionToggle(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.arrow_right_arrow_left,
              color: CupertinoColors.systemOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('adapted_ingredients'),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
          CupertinoSwitch(
            value: _useAdapted,
            activeTrackColor: CupertinoColors.systemOrange,
            onChanged: _isAdding ? null : (value) => setState(() => _useAdapted = value),
          ),
        ],
      ),
    );
  }

  Widget _buildListSelection(
    List lists,
    bool isDark,
    Color cardColor,
    Color separatorColor,
  ) {
    if (lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(CupertinoIcons.cart,
                size: 36, color: CupertinoColors.systemGrey3.resolveFrom(context)),
            const SizedBox(height: 12),
            Text(
              context.tr('no_lists_yet'),
              style: TextStyle(
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                  fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < lists.length; i++) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedListId = lists[i].id;
                  _selectedListName = lists[i].name;
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.cart_fill,
                          size: 16, color: CupertinoColors.systemBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lists[i].name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 14,
                        color: CupertinoColors.systemGrey3
                            .resolveFrom(context)),
                  ],
                ),
              ),
            ),
            if (i < lists.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Container(height: 0.5, color: separatorColor),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationView(
    bool isDark,
    Color cardColor,
    Color separatorColor,
  ) {
    final ingredients = _finalIngredients;
    final substitutedCount = widget.ingredientsWithInfo
        .where((info) =>
            info.needsSubstitution &&
            info.bestSubstitute != null &&
            _useAdapted)
        .length;
    final onOfferCount = ingredients
        .where((ing) =>
            widget.ingredientOffers.containsKey(ing.name.trim().toLowerCase()))
        .length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill,
                  size: 18, color: CupertinoColors.systemGreen),
              const SizedBox(width: 10),
              Text(
                '${ingredients.length} ${context.tr('ingredients')} · $_servings ${context.tr('servings')}',
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 15),
              ),
              if (substitutedCount > 0 || onOfferCount > 0) const Spacer(),
              if (onOfferCount > 0)
                Container(
                  margin: EdgeInsets.only(right: substitutedCount > 0 ? 6 : 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        CupertinoColors.systemGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.tr('on_offer_count',
                        params: {'count': '$onOfferCount'}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                ),
              if (substitutedCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.tr('adapted_count',
                        params: {'count': '$substitutedCount'}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ingredient list
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: widget.ingredientsWithInfo.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Container(height: 0.5, color: separatorColor),
            ),
            itemBuilder: (context, index) {
              final info = widget.ingredientsWithInfo[index];
              final isSubstituted = info.needsSubstitution &&
                  info.bestSubstitute != null &&
                  _useAdapted;
              final ingredient = ingredients[index];

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isSubstituted
                          ? CupertinoIcons.arrow_right_arrow_left
                          : CupertinoIcons.circle_fill,
                      size: isSubstituted ? 14 : 6,
                      color: isSubstituted
                          ? CupertinoColors.systemOrange
                          : CupertinoColors.systemGrey2,
                    ),
                    SizedBox(width: isSubstituted ? 14 : 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ingredient.amount > 0 ? "${ingredient.amount % 1 == 0 ? ingredient.amount.toInt() : ingredient.amount} " : ""}${ingredient.unit} ${ingredient.name}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          if (isSubstituted)
                            Text(
                              context.tr('ingredient_instead_of',
                                  params: {'name': info.original.name}),
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.systemGrey
                                    .resolveFrom(context),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Add button
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: CupertinoColors.systemBlue,
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: _isAdding
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _addIngredientsToList(_selectedListId!, ingredients);
                  },
            child: _isAdding
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CupertinoActivityIndicator(color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('adding_ingredients_progress', params: {
                          'current': '${(_addProgress! + 1).clamp(1, ingredients.length)}',
                          'total': '${ingredients.length}',
                        }),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '${context.tr('add')} ${ingredients.length} ${context.tr('ingredients')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Adds the ingredients one by one while the sheet stays open, then pops
  /// with the result. Sequential on purpose: each add may hit the Gemini
  /// categorizer, which enforces its own minimum delay between calls.
  Future<void> _addIngredientsToList(
    String listId,
    List<Ingredient> adjustedIngredients,
  ) async {
    setState(() => _addProgress = 0);
    final itemRepository = ItemRepository();
    var added = 0;
    final failedNames = <String>[];

    for (final ingredient in adjustedIngredients) {
      final offer =
          widget.ingredientOffers[ingredient.name.trim().toLowerCase()];
      try {
        await itemRepository.addItem(
          listId: listId,
          name: ingredient.name,
          quantity: ingredient.amount,
          unit: ingredient.unit,
          category: null,
          price: offer?.price,
          priceCurrency: offer != null ? 'EUR' : null,
          priceRetailer: offer?.retailerName,
          priceUnit: offer?.unitSizeLabel,
          priceOldValue: offer?.regularPrice,
        );
        added++;
      } catch (e) {
        debugPrint('❌ [ADD_TO_LIST] Failed to add "${ingredient.name}": $e');
        failedNames.add(ingredient.name);
      }
      if (!mounted) return;
      setState(() => _addProgress = _addProgress! + 1);
    }

    ref.invalidate(itemsNotifierProvider(listId));
    ref.invalidate(listsNotifierProvider);
    setState(() => _addProgress = null);
    Navigator.pop(
      context,
      AddIngredientsResult(
        listId: listId,
        total: adjustedIngredients.length,
        added: added,
        failedNames: failedNames,
      ),
    );
  }
}
