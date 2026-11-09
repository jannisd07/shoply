/// Everything Teil A places from Teil B, in one import
/// (`docs/redesign/prompt-b-vorrang.md`).
///
/// Every widget renders nothing (or, for [ArticleImage], a neutral square of
/// its final size) while its module is off, the offers kill switch is on,
/// the list hides offers or there is no data, so hosts never reserve space
/// for missing content. Signatures change only through a request in
/// `docs/redesign/status-B.md`.
library;

// Lists, items, shopping mode.
export 'package:shoply/data/models/store_info.dart' show StoreInfo;
export 'package:shoply/data/services/avo_nudge_service.dart'
    show RestockSuggestion;
export 'package:shoply/presentation/providers/list_offer_prefs_provider.dart'
    show offersHiddenForListProvider, setOffersHiddenForList;
// The favourite markets in their order (Profil row "Preise & Angebote ·
// Lidl, REWE").
export 'package:shoply/presentation/providers/offer_display_prefs_provider.dart'
    show favoriteStoresProvider;
export 'package:shoply/presentation/providers/store_choice_provider.dart'
    show ChainStoreChoice, CustomStoreChoice, NoStoreChoice, StoreChoice;
export 'package:shoply/presentation/providers/store_for_list_provider.dart'
    show storeForListProvider;
export 'package:shoply/presentation/screens/history/checkout/checkout_flow.dart'
    show openCheckoutFlow;
export 'package:shoply/presentation/screens/lists/widgets/item_offer_badge.dart'
    show ItemOfferBadge;
export 'package:shoply/presentation/screens/lists/widgets/item_offer_card.dart'
    show ItemOfferCard;
export 'package:shoply/presentation/screens/lists/widgets/list_offer_count_badge.dart'
    show ListOfferCountBadge;
export 'package:shoply/presentation/screens/lists/widgets/list_offer_summary.dart'
    show ListOfferSummary;
export 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart'
    show OfferSuggestionsBar;
export 'package:shoply/presentation/screens/lists/widgets/store_chip.dart'
    show StoreChip;
// "Markt wählen" (S2) for the list info row "Markt" and "Neue Liste"; the
// offer screens for the list menu ("Angebote dieser Liste", S9), the
// overview ("Angebote der Woche", S10) and the Profil row (S12).
export 'package:shoply/presentation/screens/offers/offer_paths.dart'
    show
        StorePickerOrigin,
        offerListLocation,
        offersSettingsPath,
        weeklyOffersLocation;
export 'package:shoply/presentation/screens/offers/store_menu.dart'
    show openStorePicker;
export 'package:shoply/presentation/state/avo_nudge_provider.dart'
    show restockSuggestionsProvider;
export 'package:shoply/presentation/widgets/article_image.dart'
    show ArticleImage, ArticleImageCredit, articleImagesShown;

// Recipes.
export 'package:shoply/presentation/screens/calories/log_recipe.dart'
    show openLogRecipe;
export 'package:shoply/presentation/screens/recipes/widgets/recipe_offers_card.dart'
    show IngredientOfferBadge, RecipeOfferSummary, RecipeOffersCard;

// Home "Für dich" sections (Stufe 2).
export 'package:shoply/presentation/widgets/home_sections/home_sections.dart'
    show
        HomeCaloriesToday,
        HomeCookToday,
        HomeMonthCard,
        HomeOffersTile,
        HomeRecentTrips,
        HomeRestockTile,
        HomeSavingsGoal,
        HomeSavingsHint,
        HomeSpendingComparison,
        HomeWaterTile,
        homeCaloriesHasContentProvider,
        homeCookTodayHasContentProvider,
        homeMonthHasContentProvider,
        homeOffersTileHasContentProvider,
        homeRecentTripsHasContentProvider,
        homeRestockHasContentProvider,
        homeSavingsGoalHasContentProvider,
        homeSavingsHintHasContentProvider,
        homeSpendingHasContentProvider,
        homeWaterHasContentProvider;

// Avo tab (Stufe 3): A's screens set where the person is.
export 'package:shoply/presentation/providers/avo_screen_context_provider.dart'
    show AvoScreenContext, avoScreenContextProvider;

// Avo tab: open it with a question Avo answers at once (in-app only; a URL
// only fills the composer).
export 'package:shoply/presentation/screens/avo/avo_hand_over.dart'
    show AvoAsk, openAvoWithQuestion;

// Onboarding, settings, modules.
export 'package:shoply/presentation/providers/app_flags_provider.dart'
    show
        offersAvailableProvider,
        offersKillSwitchOffProvider,
        offersRemoteEnabledProvider;
export 'package:shoply/presentation/state/calorie_tracking_provider.dart'
    show calorieTrackingEnabledProvider;
export 'package:shoply/presentation/widgets/deals/offers_setup_step.dart'
    show OffersSetupStep;
