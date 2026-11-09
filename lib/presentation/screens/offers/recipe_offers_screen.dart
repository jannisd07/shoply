import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_entry_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/postcode_hint.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_adaptation.dart'
    show formatRecipeAmount;
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// The recipe of "Angebote für {Rezept}": the one handed over by the
/// detail, one loaded this session or on the device, else from the server.
/// Override in tests.
final offerRecipeProvider = FutureProvider.autoDispose.family<Recipe?, String>((
  ref,
  recipeId,
) async {
  final actions = ref.watch(recipeDetailActionsProvider);
  final device = await actions.onDevice(recipeId);
  if (device != null) return device;
  try {
    return await actions.load(recipeId);
  } catch (e) {
    debugPrint('⚠️ [OFFERS] Recipe for its offers not loaded: $e');
    return null;
  }
});

/// "Angebote für {Rezept}" (S15, `/offers/recipe/:recipeId`, full screen
/// above the tab bar): which ingredients of the recipe are on offer at the
/// market of [listId] this week?
///
/// A large title, the sentence "3 von 9 Zutaten diese Woche bei Lidl im
/// Angebot, für Wocheneinkauf, in deiner Region" (no savings: the
/// ingredients are not on the list yet, a sum would be a guess), the
/// ingredients on offer with the amount for the chosen servings, and the
/// source footnote. A row opens the offer (S5, "Auf die Liste" onto
/// [listId]); there is no plus: ingredients go onto the list through
/// "Zutaten auf die Liste", where the list's offers attach themselves.
/// States as in S9; the route gate handles module and kill switch.
class RecipeOffersScreen extends ConsumerWidget {
  const RecipeOffersScreen({
    super.key,
    required this.recipeId,
    required this.listId,
    this.recipe,
    this.servings,
  });

  final String recipeId;
  final String listId;

  /// Handed over by the recipe detail (`extra`); loaded otherwise.
  final Recipe? recipe;
  final int? servings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final given = recipe;
    final loaded = given == null
        ? ref.watch(offerRecipeProvider(recipeId))
        : AsyncData<Recipe?>(given);
    final current = loaded.valueOrNull;
    if (current == null) {
      return OffersPage(
        title: context.tr('offer_detail_title'),
        bottom: OffersPageBottom.safeArea,
        children: [
          if (loaded.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: AvoSpacing.section),
              child: SkeletonSection(),
            )
          else
            EmptyState(
              icon: const AvoIcon(AvoIcons.tag),
              title: context.tr('offer_detail_gone'),
              actionLabel: context.tr('back'),
              onAction: () => context.pop(),
            ),
        ],
      );
    }
    return OffersPage(
      title: context.tr(
        'offer_recipe_title',
        params: {'recipe': current.name.trim()},
      ),
      bottom: OffersPageBottom.safeArea,
      onRefresh: () => refreshRecipeOffers(
        ref,
        recipeOfferKey(current.id, [
          for (final i in current.ingredients) i.name,
        ], listId),
      ),
      children: [_Body(recipe: current, listId: listId, servings: servings)],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.recipe, required this.listId, this.servings});

  final Recipe recipe;
  final String listId;
  final int? servings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listName = ref.watch(offerListNameProvider(listId)) ?? '';
    if (!ref.watch(regionLoadedProvider)) return const SizedBox.shrink();
    if (ref.watch(regionProvider) == null) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.location),
        title: context.tr('offer_need_area_title'),
        actionLabel: context.tr('offer_need_area_action'),
        onAction: () =>
            unawaited(openRegionFromList(context, from: RegionOrigin.offers)),
      );
    }
    if (ref.watch(offersHiddenForListProvider(listId))) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.eyeSlash),
        title: context.tr(
          'offer_list_hidden_title',
          params: {'list': listName},
        ),
        actionLabel: context.tr('offer_show_again'),
        onAction: () => unawaited(setOffersHiddenForList(ref, listId, false)),
      );
    }
    final guess = ref.watch(storeGuessForListProvider(listId));
    if (!guess.hasValue) return const SizedBox.shrink();
    final market = ref.watch(storeForListProvider(listId))?.id;
    if (market == null) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.storefront),
        title: context.tr('offer_hint_no_store', params: {'list': listName}),
        actionLabel: context.tr('offer_hint_no_store_action'),
        onAction: () => unawaited(openStorePicker(context, listId: listId)),
      );
    }

    final key = recipeOfferKey(recipe.id, [
      for (final i in recipe.ingredients) i.name,
    ], listId);
    ref.listen(recipeOffersProvider(key), (_, next) {
      final offers = next.valueOrNull;
      if (offers != null) {
        ref
            .read(recipeIngredientOffersProvider.notifier)
            .remember(listId, offers);
      }
    });
    final result = ref.watch(recipeOffersProvider(key));
    final offline = ref.watch(isOfflineProvider);
    final offers = result.valueOrNull;
    final store = storeNameOf(market);

    // A search failed: "nicht geladen" (nothing to show) or "nicht
    // aktualisiert" (some offers came); offline the offline row says it.
    // Never "Gerade nichts im Angebot." for an answer that is not complete.
    final incomplete = offers != null && !offers.complete;
    void retry() => unawaited(refreshRecipeOffers(ref, key));
    final Widget status;
    if (offline) {
      status = Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.m),
        child: StatusRow(
          kind: StatusKind.offline,
          text: context.tr('offer_status_offline_search'),
        ),
      );
    } else if ((result.hasError && offers == null) || incomplete) {
      status = Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.m),
        child: StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr(
            offers != null && offers.matches.isNotEmpty
                ? 'offer_status_refresh_failed'
                : 'offer_status_load_failed',
          ),
          actionLabel: context.tr('common_try_again'),
          onAction: retry,
        ),
      );
    } else {
      status = const SizedBox.shrink();
    }

    if (offers == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          status,
          if (result.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: AvoSpacing.section),
              child: SkeletonSection(),
            ),
        ],
      );
    }
    if (offers.matches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          status,
          if (offers.complete)
            EmptyState(
              icon: const AvoIcon(AvoIcons.tag),
              title: context.tr('offer_list_empty_title'),
              message: context.tr('offer_list_empty_body'),
            ),
        ],
      );
    }

    final lang = offerLanguageOf(context);
    final chosen =
        servings ??
        ref.watch(recipeServingsProvider(recipe.id)) ??
        recipe.defaultServings;
    final byName = {
      for (final i in recipe.ingredients) i.name.trim().toLowerCase(): i,
    };
    Widget row(RecipeIngredientOffer match) {
      final offer = match.storeOffer;
      final ingredient = byName[match.ingredientName.trim().toLowerCase()];
      final amount = ingredient == null || recipe.defaultServings <= 0
          ? ''
          : formatRecipeAmount(
              ingredient.adjustForServings(recipe.defaultServings, chosen),
              lang,
            );
      final title = amount.isEmpty
          ? match.ingredientName
          : context.tr(
              'offer_list_item_qty',
              params: {'item': match.ingredientName, 'qty': amount},
            );
      final was = OfferLines.was(offer, lang);
      return offerEntryRow(
        context,
        offer: offer,
        title: title,
        lines: [OfferLines.product(offer, lang), ?was],
        onTap: () {
          rememberOffer(context, offer);
          unawaited(
            context.push(
              offerDetailLocation(
                offer.id,
                listId: listId,
                mode: OfferDetailMode.add,
                name: match.ingredientName,
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OffersLead(
          context.tr(
            'offer_recipe_sentence',
            params: {
              'matched': '${offers.matches.length}',
              'total': '${offers.checked}',
              'store': store,
              'list': listName,
            },
          ),
        ),
        status,
        InsetSection(
          header: context.tr('offer_recipe_section'),
          headerTrailing: Text('${offers.matches.length}'),
          separatorIndent: AvoSpacing.l,
          children: [for (final m in offers.matches) row(m)],
        ),
        const OffersSourceFootnote(),
      ],
    );
  }
}
