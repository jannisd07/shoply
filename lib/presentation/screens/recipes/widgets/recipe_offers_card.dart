import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

const double _kRowMin = 52; // D2 one line
const double _kRowVertical = AvoSpacing.s; // D2
const double _kTag = 17; // D2 tag glyph in the row
const double _kChevron = 14; // D2 disclosure chevron

/// "3 Zutaten diese Woche bei Lidl im Angebot · für Wocheneinkauf, in
/// deiner Region" (S15) for the recipe detail where it sits today: the row
/// of [RecipeOfferSummary] in a group of its own, for the recipe's target
/// list (the list last chosen in "Zutaten auf die Liste", else the list of
/// today, else the one changed last). Renders nothing in all the cases
/// [RecipeOfferSummary] does, and without any list.
class RecipeOffersCard extends ConsumerWidget {
  const RecipeOffersCard({super.key, required this.recipe, this.listId});

  final Recipe recipe;

  /// The target list; null takes the recipe's target list.
  final String? listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offers first: while they are unavailable nothing else is read.
    if (!ref.watch(offersRemoteEnabledProvider) ||
        !ref.watch(offersAvailableProvider)) {
      return const SizedBox.shrink();
    }
    final target = listId ?? ref.watch(recipeTargetListProvider(recipe.id))?.id;
    if (target == null) return const SizedBox.shrink();
    return _CollapsingGroup(
      child: RecipeOfferSummary(recipe: recipe, listId: target),
    );
  }
}

/// An [InsetSection] around a row that may render nothing: then the group
/// renders nothing either (no empty white box).
class _CollapsingGroup extends StatelessWidget {
  const _CollapsingGroup({required this.child});

  final RecipeOfferSummary child;

  @override
  Widget build(BuildContext context) => _SummaryVisibility(
    summary: child,
    builder: (row) => InsetSection(children: [row]),
  );
}

/// Builds [builder] around the summary row only while it shows.
class _SummaryVisibility extends ConsumerWidget {
  const _SummaryVisibility({required this.summary, required this.builder});

  final RecipeOfferSummary summary;
  final Widget Function(Widget row) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shows = ref.watch(
      recipeOfferSummaryShowsProvider(
        recipeOfferSummaryKey(summary.recipe, summary.listId),
      ),
    );
    return shows ? builder(summary) : const SizedBox.shrink();
  }
}

/// The key of [RecipeOfferSummary] for [recipe] on [listId], for
/// [recipeOfferSummaryShowsProvider].
RecipeOfferKey recipeOfferSummaryKey(Recipe recipe, String listId) =>
    recipeOfferKey(recipe.id, [
      for (final i in recipe.ingredients) i.name,
    ], listId);

/// What the summary row of [RecipeOfferKey] shows, or null when it renders
/// nothing.
final _summaryOffersProvider = Provider.autoDispose
    .family<RecipeListOffers?, RecipeOfferKey>((ref, key) {
      final offers = ref.watch(recipeOffersCachedProvider(key)).valueOrNull;
      if (offers == null || offers.matches.isEmpty) return null;
      final name = ref.watch(offerListNameProvider(key.listId));
      if (name == null || name.isEmpty) return null;
      return offers;
    });

/// Whether `RecipeOfferSummary(recipe:, listId:)` shows its row (key:
/// [recipeOfferSummaryKey]). Hosts pass the row only while this is true, so
/// a group has no empty last row. Reading it asks nothing new: it follows
/// what the device has.
final recipeOfferSummaryShowsProvider = Provider.autoDispose
    .family<bool, RecipeOfferKey>(
      (ref, key) => ref.watch(_summaryOffersProvider(key)) != null,
    );

/// The last row of the group "Zutaten" in the recipe detail (S15, slot
/// `RecipeOfferSummary(recipe:, listId:)`): `tag`, "3 Zutaten diese Woche
/// bei Lidl im Angebot · für Wocheneinkauf, in deiner Region", chevron; the
/// whole row opens "Angebote für {Rezept}".
///
/// Only the market of [listId] counts; pantry staples never do. The row
/// shows only what the device had when the detail opened, so it never
/// pushes the instructions down: on a miss the offers are looked up in the
/// background for the next opening. Renders nothing, and asks nothing,
/// while offers may not show on the list (kill switch, module, hidden list,
/// no real region, "Angebote an Artikeln" off), when the list has no market
/// (no "Markt wählen" here; that belongs to the list) or nothing is on
/// offer. Never Pro.
class RecipeOfferSummary extends ConsumerStatefulWidget {
  const RecipeOfferSummary({
    super.key,
    required this.recipe,
    required this.listId,
  });

  final Recipe recipe;
  final String listId;

  @override
  ConsumerState<RecipeOfferSummary> createState() => _RecipeOfferSummaryState();
}

class _RecipeOfferSummaryState extends ConsumerState<RecipeOfferSummary> {
  ProviderSubscription<AsyncValue<RecipeListOffers?>>? _handover;

  RecipeOfferKey get _key =>
      recipeOfferSummaryKey(widget.recipe, widget.listId);

  @override
  void initState() {
    super.initState();
    _handOver();
  }

  @override
  void didUpdateWidget(RecipeOfferSummary old) {
    super.didUpdateWidget(old);
    if (recipeOfferSummaryKey(old.recipe, old.listId) != _key) {
      _handover?.close();
      _handOver();
    }
  }

  /// Hands the offers to the ingredient pills ([IngredientOfferBadge]), the
  /// ones already on the device too (the row may mount after they loaded).
  /// Never while the tree builds: the pills above watch the same state.
  void _handOver() {
    final listId = widget.listId;
    _handover = ref.listenManual(recipeOffersCachedProvider(_key), (_, next) {
      final offers = next.valueOrNull;
      if (offers == null) return;
      Future.microtask(() {
        if (!mounted) return;
        ref
            .read(recipeIngredientOffersProvider.notifier)
            .remember(listId, offers);
      });
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final listId = widget.listId;
    final offers = ref.watch(_summaryOffersProvider(_key));
    if (offers == null) return const SizedBox.shrink();
    final listName = ref.watch(offerListNameProvider(listId))!;
    final colors = context.colors;
    final n = offers.matches.length;
    final text = n == 1
        ? context.tr(
            'offer_recipe_row_one',
            params: {'store': storeNameOf(offers.chainId), 'list': listName},
          )
        : context.tr(
            'offer_recipe_row_other',
            params: {
              'n': '$n',
              'store': storeNameOf(offers.chainId),
              'list': listName,
            },
          );
    void open() => unawaited(
      context.push(
        offerRecipeLocation(
          recipe.id,
          listId: listId,
          servings: ref.read(recipeServingsProvider(recipe.id)),
        ),
        extra: recipe,
      ),
    );
    final ax = context.isAccessibilityText;
    final scale = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      button: true,
      label: text,
      hint: context.tr('offer_recipe_row_hint_a11y'),
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: _kRowVertical,
            ),
            child: Row(
              crossAxisAlignment: ax
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                AvoIcon(
                  AvoIcons.tag,
                  size: scale.scale(_kTag),
                  color: colors.secondaryLabel,
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Text(text, style: context.text(AvoTextStyle.subhead)),
                ),
                const SizedBox(width: AvoSpacing.m),
                AvoIcon(
                  AvoIcons.chevronRight,
                  size: _kChevron,
                  color: colors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The offer pill at an ingredient row of the recipe detail (S15, slot
/// `IngredientOfferBadge(listId:, ingredient:)`), like the item pill (S3):
/// "0,99 €", a question mark for a similar product. Shows the offers the
/// recipe row found for the market of [listId]; renders nothing otherwise
/// and while offers may not show on the list. Not tappable (the row opens
/// "Angebote für {Rezept}"); its sentence joins the ingredient row's label.
class IngredientOfferBadge extends ConsumerWidget {
  const IngredientOfferBadge({
    super.key,
    required this.listId,
    required this.ingredient,
  });

  final String listId;
  final Ingredient ingredient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(
      recipeIngredientOfferProvider((listId: listId, name: ingredient.name)),
    );
    if (offer == null) return const SizedBox.shrink();
    final lang = offerLanguageOf(context);
    return Semantics(
      label: context.tr(
        offer.isBroadMatch ? 'offer_badge_similar_a11y' : 'offer_badge_a11y',
        params: {'price': spokenEuro(offer.price, lang)},
      ),
      child: ExcludeSemantics(
        child: OfferPriceTag(
          price: formatEuro(offer.price, lang),
          uncertain: offer.isBroadMatch,
        ),
      ),
    );
  }
}
