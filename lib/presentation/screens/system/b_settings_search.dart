import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/avo/avo_settings_screen.dart'
    show AvoSettingsRows;
import 'package:shoply/presentation/screens/calories/calories_settings_screen.dart'
    show CaloriesSettingsRows;
import 'package:shoply/presentation/screens/profile/profile_root_pages.dart'
    show ProfileIcons;
import 'package:shoply/presentation/screens/profile/settings/offers_settings_screen.dart'
    show OffersSettingsRows;
import 'package:shoply/presentation/screens/profile/settings_search_entry.dart';
import 'package:shoply/routes/route_paths.dart';

// Page titles of Teil B's settings pages, used as the path of row hits.
const _offers = 'prof_row_offers';
const _markets = 'prof_row_markets';
const _health = 'cal_settings_title';
const _avo = 'avo_set_title';
const _siri = 'sys_siri_title';

/// Search entries of Teil B's settings pages (Konzept 18 §3.5, A8): every
/// page and the rows a search should find, with the `rowId` the page
/// highlights (`HighlightableRow`, `?row=`). Teil A's index reads it through
/// `b_slots.dart`.
///
/// An entry shows only while its route exists and its module is on (by
/// [SettingsSearchEntry.module], else the page's module). Offers words
/// ([SettingsSearchEntry.offersTerm]) never lead anywhere under the kill
/// switch; markets and the region stay findable there as "Märkte".
const List<SettingsSearchEntry> bSettingsSearchEntries = [
  // ------------------------------------------------- Preise & Angebote
  // Markets stay findable under the kill switch, as "Märkte".
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: _offers,
    killSwitchTitleKey: _markets,
    keywordsKeys: ['prof_kw_markets'],
    icon: ProfileIcons.offers,
  ),
  // Offers words ("Angebot", "Prospekt") never lead anywhere under the kill
  // switch (§3.5).
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: _offers,
    keywordsKeys: ['prof_kw_offers'],
    icon: ProfileIcons.offers,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'common_module_offers',
    pathKeys: [_offers],
    keywordsKeys: ['offer_kw_show'],
    rowId: OffersSettingsRows.module,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'offer_settings_on_items',
    pathKeys: [_offers],
    keywordsKeys: ['offer_kw_show'],
    rowId: 'offers.itemOffers',
    module: AppModule.offers,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'offer_settings_while_typing',
    pathKeys: [_offers],
    rowId: 'offers.typingSuggestions',
    module: AppModule.offers,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'offer_settings_in_list',
    pathKeys: [_offers],
    rowId: 'offers.listSavings',
    module: AppModule.offers,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'offer_settings_home_tips',
    pathKeys: [_offers],
    rowId: 'offers.homeTips',
    module: AppModule.offers,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'offer_settings_history',
    pathKeys: [_offers],
    rowId: 'offers.historySavings',
    module: AppModule.offers,
    offersTerm: true,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffers,
    titleKey: 'offer_settings_detect',
    pathKeys: [_offers],
    killSwitchPathKeys: [_markets],
    keywordsKeys: ['offer_kw_detect'],
    rowId: OffersSettingsRows.detect,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffersRegion,
    titleKey: 'prof_row_region',
    pathKeys: [_offers],
    killSwitchPathKeys: [_markets],
    keywordsKeys: ['prof_kw_region'],
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffersMarkets,
    titleKey: 'prof_row_favorite_markets',
    pathKeys: [_offers],
    killSwitchPathKeys: [_markets],
    keywordsKeys: ['prof_kw_favorite_markets'],
  ),

  // --------------------------------------------- Kalorien & Gesundheit
  SettingsSearchEntry(
    route: RoutePaths.settingsHealth,
    titleKey: 'prof_row_health',
    keywordsKeys: ['prof_kw_health'],
    module: AppModule.calories,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsHealth,
    titleKey: 'cal_goals_title',
    pathKeys: [_health],
    keywordsKeys: ['cal_kw_goals'],
    rowId: CaloriesSettingsRows.goals,
    module: AppModule.calories,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsHealth,
    titleKey: 'cal_set_dinner_ideas',
    pathKeys: [_health],
    keywordsKeys: ['cal_kw_dinner_ideas'],
    rowId: CaloriesSettingsRows.dinnerIdeas,
    module: AppModule.calories,
  ),

  // ------------------------------------------------------- Wochenplan
  // The page and its rows come with the Wochenplan slice (B7).
  SettingsSearchEntry(
    route: RoutePaths.settingsPlan,
    titleKey: 'prof_row_plan',
    keywordsKeys: ['prof_kw_plan'],
    module: AppModule.mealPlan,
  ),

  // -------------------------------------------------------------- Avo
  SettingsSearchEntry(
    route: RoutePaths.settingsAvo,
    titleKey: 'prof_row_avo',
    keywordsKeys: ['prof_kw_avo'],
    module: AppModule.avo,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAvo,
    titleKey: 'avo_set_consent_diet',
    pathKeys: [_avo],
    keywordsKeys: ['avo_kw_consent_diet'],
    rowId: AvoSettingsRows.consentDiet,
    module: AppModule.avo,
  ),
  // Only while both Avo and Kalorien are on; the search checks one module,
  // so the row names Kalorien and lives on the Avo page.
  SettingsSearchEntry(
    route: RoutePaths.settingsAvo,
    titleKey: 'avo_set_consent_health',
    pathKeys: [_avo],
    keywordsKeys: ['avo_kw_consent_health'],
    rowId: AvoSettingsRows.consentHealth,
    module: AppModule.calories,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAvo,
    titleKey: 'avo_set_delete_conversation',
    pathKeys: [_avo],
    keywordsKeys: ['avo_kw_conversation'],
    rowId: AvoSettingsRows.deleteConversation,
    module: AppModule.avo,
  ),

  // ------------------------------------------------ Siri & Kurzbefehle
  SettingsSearchEntry(
    route: RoutePaths.settingsSiri,
    titleKey: 'prof_row_siri',
    keywordsKeys: ['prof_kw_siri', 'sys_kw_siri_phrases'],
    icon: ProfileIcons.siri,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsSiri,
    titleKey: 'sys_siri_open_shortcuts',
    pathKeys: [_siri],
    keywordsKeys: ['sys_kw_shortcuts'],
    rowId: 'siri.shortcuts',
  ),

  // ------------------------------------------------------------ Widgets
  SettingsSearchEntry(
    route: RoutePaths.settingsWidgets,
    titleKey: 'prof_row_widgets',
    keywordsKeys: ['prof_kw_widgets', 'sys_kw_widgets_add'],
    icon: ProfileIcons.widgets,
  ),
];

