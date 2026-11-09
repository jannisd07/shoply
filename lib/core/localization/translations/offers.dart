// Texte des Bereichs "offers" (Teil B), Deutsch und Englisch.
// Entstanden am 07.11.2026 aus app_translations.dart (A1). Pflege: nur Teil B.
// Neue Schlüssel bekommen das Bereichs-Präfix, siehe docs/redesign/arbeitsteilung.md 3.6.

const Map<String, String> offersEn = {
  // Pflicht-Wortlaut (angebote.md 3.3); zusammengesetzt nur in
  // offer_savings.dart (offerSummaryText).
  'offer_summary_head_one': '{matched} of 1 item on offer at {store} this week',
  'offer_summary_head_other':
      '{matched} of {total} items on offer at {store} this week',
  'offer_summary_saved': 'about {amount} saved',
  'offer_in_your_area': 'in your area',
  'offer_retailer_prices': 'prices as stated by the retailer',
  'offer_summary_sentence': '{head}, about {amount} saved, in your area',
  'offer_summary_sentence_no_savings': '{head}, in your area',
  'offer_was_price': 'was {price}, as stated by the retailer',
  'offer_valid_until': 'until {date}',
  'offer_ends_tomorrow': 'ends tomorrow',
  'offer_ends_weekday': 'ends {weekday}',
  'offer_similar_product': 'Similar product',
  'offer_source_footnote':
      'Offers apply to your area, not to a specific store. Prices are as stated by the retailer; the app doesn\'t know regular prices. Source: {source}.',
  'offer_source_placeholder': 'retailer flyers',
  'offer_unit_price_a11y': '{price} per {unit}',
  'offer_unit_l': 'litre',
  'offer_unit_kg': 'kilogram',
  'offer_unit_piece': 'piece',
  'offer_distance_m': '{n} m',
  'offer_distance_km': '{n} km',
  'offer_distance_m_a11y': '{n} metres',
  'offer_distance_km_a11y': '{n} kilometres',
  // Rückgängig-Hinweise (3.7).
  'offer_toast_store_set': 'Store: {store}',
  'offer_toast_store_none': 'No fixed store',
  'offer_toast_store_failed': 'Store not saved',
  'offer_toast_price_taken': 'Price added to {item}',
  'offer_toast_price_removed': 'Price removed from {item}',
  'offer_toast_price_failed': 'Price not saved',
  'offer_toast_attached': 'Offer added to {item}',
  'offer_toast_added_list': '{item} added to {list}',
  'offer_toast_add_failed': 'Not added',
  'offer_toast_offer_hidden': 'Offer hidden for {item}',
  'offer_toast_summary_week': 'Savings line hidden for this week',
  'offer_toast_summary_off': 'Savings line turned off',
  // S1 Markt-Chip.
  'offer_store_choose': 'Choose store',
  'offer_store_other': 'Other store…',
  'offer_store_none': 'No fixed store',
  'offer_store_confirm_title': 'Is this your {store} list?',
  'offer_store_confirm_yes': 'Yes, {store}',
  'offer_store_dont_ask': 'Don\'t ask again',
  'offer_store_chip_a11y': 'Store: {store}, change',
  'offer_store_chip_suggested_a11y':
      'Suggested store: {store}. Confirm or change',
  'offer_hint_no_store':
      'Which store is {list} for? Then you\'ll see its offers.',
  'offer_hint_no_store_action': 'Choose store',
  // S2 Markt wählen.
  'offer_pick_title': 'Store',
  'offer_pick_search': 'Search stores',
  'offer_pick_yours': 'Your stores',
  'offer_pick_nearby': 'Nearby',
  'offer_pick_all': 'All stores',
  'offer_pick_distance': '{street} · {distance}',
  'offer_pick_no_result': 'No store called “{query}”.',
  'offer_pick_use_custom': 'Use “{query}” as your own store',
  // S3 Angebots-Pille.
  'offer_module_off_body':
      "Turn it on to see what's on offer at your store, right on your lists.",
  'offer_badge_a11y': 'on offer, {price} as stated by the retailer',
  'offer_badge_similar_a11y':
      'similar product on offer, {price} as stated by the retailer',
  'offer_action_view': 'View offer',
  // S4 Angebotskarte.
  'offer_card_kicker': 'Offer',
  'offer_card_title': '{store} · {price}',
  'offer_card_price_taken': 'Price added',
  'offer_card_a11y': 'Offer: {store}, {price}, {product}, {details}',
  // S5 Angebot.
  'offer_detail_title': 'Offer',
  'offer_detail_was': 'Was, as stated by the retailer',
  'offer_detail_unit_price': 'Unit price',
  'offer_detail_valid': 'Valid',
  'offer_detail_expired': 'ended',
  'offer_detail_store': 'Store',
  'offer_detail_area': 'Area',
  'offer_detail_similar':
      'Similar product. Check that it suits “{item}” before you buy it.',
  'offer_detail_not_this': 'Not this offer',
  'offer_detail_more_at': 'More offers at {store}',
  'offer_detail_take_price': 'Use this price',
  'offer_detail_add_to_list': 'Add to list',
  'offer_detail_remove_price': 'Remove this price',
  'offer_detail_expired_action': 'Offer has ended',
  'offer_detail_gone': 'This offer is no longer saved.',
  'offer_detail_swapped_a11y': 'Offer changed: {product}',
  'offer_price_tag_a11y': '{price}, offer price',
  // S6 Angebote beim Tippen.
  'offer_suggest_row_sub': '{store} · {pack} · until {weekday}',
  'offer_suggest_row_a11y':
      '{product}, {store}, {pack}, until {date}, on offer, {price} as stated by the retailer',
  'offer_suggest_row_hint_a11y': 'Adds {item}',
  'offer_suggest_added_a11y': '{item} added, on offer',
  // S7 Ersparnis-Zeile.
  'offer_summary_hide_week': 'Hide this week',
  'offer_summary_never': 'Don\'t show again',
  'offer_summary_hint_a11y': 'Shows this list\'s offers',
  'offer_summary_card_a11y': '{sentence}. Prices as stated by the retailer',
  // Zustände (3.4), Rückgängig (3.7), Erklärung (3.3).
  'offer_status_offline_as_of': 'You\'re offline. Offers as of {datetime}.',
  'offer_status_offline_search': 'You\'re offline. Showing saved offers only.',
  'offer_status_refresh_failed': 'Offers couldn\'t be updated just now.',
  'offer_status_load_failed': 'Offers couldn\'t be loaded just now.',
  'offer_hint_set_postcode': 'To see offers in your area, set your postcode',
  'offer_hint_set_postcode_action': 'Set postcode',
  'offer_datetime': '{date}, {time}',
  'offer_savings_explainer':
      '“Saved” is the difference to the retailers\' “was” prices, worked out per unit and for your quantities. It\'s an approximate value.',
  'offer_toast_attached_list': 'Offer added to {item} on {list}',
  'offer_toast_added_no_offer':
      '{item} added to {list} · offer only at {store}',
  'offer_toast_list_hidden': 'Offers hidden for {list}',
  'offer_toast_list_shown': 'Offers shown for {list}',
  'offer_toast_not_interested': 'Hidden until {date}',
  'offer_toast_region_set': 'Area: {postcode} {city}',
  'offer_toast_region_removed': 'Area removed',
  'offer_toast_favorite_removed': '{store} removed',
  // S9 Angebote bei {Markt}.
  'offer_list_title': 'Offers at {store}',
  'offer_list_title_no_store': 'Offers for {list}',
  'offer_list_on_list': 'On your list',
  'offer_list_regulars': 'Often bought, on offer at {store} this week',
  'offer_list_item_qty': '{item} · {qty}',
  'offer_list_all_offers': 'All offers this week',
  'offer_hide_for_list': 'Hide offers for this list',
  'offer_add_plus_a11y': 'Add {product} to {list}',
  'offer_list_empty_title': 'Nothing on offer right now.',
  'offer_list_empty_body': 'New offers usually arrive on Mondays.',
  'offer_need_area_title': 'You need an area to see offers.',
  'offer_need_area_action': 'Set postcode',
  'offer_list_hidden_title': 'Offers are hidden for {list}.',
  'offer_show_again': 'Show offers',
  // S10 Angebote der Woche.
  'offer_week_title': 'Offers this week',
  'offer_week_area': 'In your area · {postcode} {city}',
  'offer_week_area_a11y': 'Area: {postcode} {city}, change',
  'offer_week_search': 'Search offers',
  'offer_week_seg_lists': 'Your lists',
  'offer_week_seg_regulars': 'Often bought',
  'offer_week_section': '{list} · {store}',
  'offer_week_for_item': 'For “{item}” on {list}',
  'offer_week_rhythm': '{store} · You buy this about every {days} days',
  'offer_week_not_interested': 'Not interested',
  'offer_week_add_swipe': 'Add to list',
  'offer_week_no_area_title': 'Where do you shop?',
  'offer_week_no_area_body':
      'Offers depend on your area. Add your postcode to see what\'s on offer at your stores.',
  'offer_use_location': 'Use my location',
  'offer_enter_postcode': 'Enter postcode',
  'offer_location_off': 'Location is off. Allow it in Settings',
  'offer_week_lists_empty_title':
      'Nothing from your lists is on offer right now.',
  'offer_week_lists_empty_body': 'Search above for a specific product.',
  'offer_week_regulars_empty': 'Nothing you buy often is on offer right now.',
  'offer_week_regulars_new':
      'After a few shopping trips, you\'ll see what you often buy that\'s on offer.',
  'offer_week_search_empty': 'No offers for “{query}” in your area.',
  'offer_menu_which_list': 'Add to which list?',
  'offer_menu_not_valid_there': '{store} · offer doesn\'t apply there',
  'offer_menu_new_list': 'New list…',
  // S11 Region.
  'offer_region_title': 'Area',
  'offer_region_title_stores': 'Location',
  'offer_region_intro':
      'Offers apply to an area, not to a single store. We store your postcode and only send it to the offer source.',
  'offer_region_intro_stores':
      'With your location, Avo can suggest stores near you.',
  'offer_use_location_sub':
      'Asks for your location once. Only the postcode is saved.',
  'offer_use_location_current': 'Current: {postcode} {city}',
  'offer_postcode_label': 'Postcode',
  'offer_postcode_placeholder': 'e.g. {example}',
  'offer_postcode_place': '{postcode} · {city}',
  'offer_postcode_place_fallback': 'Postcode {postcode}',
  'offer_region_remove': 'Remove area',
  'offer_locating_a11y': 'Finding your location',
  'offer_location_unavailable':
      'Location isn\'t available right now. Enter your postcode.',
  'offer_location_abroad': 'Offers are only available in Germany.',
  'offer_location_abroad_stores': 'Avo only knows stores in Germany so far.',
  'offer_postcode_digits': 'Enter 5 digits.',
  'offer_postcode_unknown': 'We don\'t know this postcode.',
  // S12 Preise & Angebote.
  'offer_settings_title_stores': 'Stores',
  'offer_settings_master_sub':
      'Offers from your stores, in lists and while adding items',
  'offer_settings_show': 'Show',
  'offer_settings_on_items': 'Offers on items',
  'offer_settings_while_typing': 'Suggestions while typing',
  'offer_settings_in_list': 'Savings in the list',
  'offer_settings_in_list_sub': '“4 of 11 on offer”',
  'offer_settings_home_tips': 'Savings tips on Home',
  'offer_settings_history': 'Savings in history and after shopping',
  'offer_settings_my_stores': 'My stores',
  'offer_settings_add_store': '+ Store',
  'offer_settings_no_favorites': 'No favourite stores yet',
  'offer_settings_stores_a11y': 'My stores: {stores}. Edit',
  'offer_settings_detect': 'Detect store automatically',
  'offer_settings_detect_note':
      'Avo recognises the store from the list name and your shopping trips. With location on, Avo also asks when you\'re in a store. Anything Avo only guesses stays a suggestion.',
  'offer_settings_region': 'Area',
  'offer_settings_region_unset': 'Not set',
  'offer_settings_region_unset_a11y': 'not set, warning',
  'offer_settings_location_stores': 'Location',
  'offer_settings_location_stores_sub': 'For store suggestions',
  'offer_settings_hidden_for': 'Hidden for',
  // S13 Lieblingsmärkte.
  'offer_favorites_title': 'Favourite stores',
  'offer_favorites_yours': 'Your stores',
  'offer_favorites_more': 'More stores',
  'offer_favorites_note_stores':
      'These stores come first when you choose a store for a list.',
  'offer_favorites_empty': 'No favourite stores yet.',
  // S14 Onboarding.
  'offer_setup_region': 'Area',
  'offer_setup_location_sub':
      'Used once to find your area and nearby stores. Only the postcode is saved.',
  'offer_setup_stores': 'Your stores',
  'offer_setup_stores_note':
      'Pick where you usually shop. You can choose more than one.',
  'offer_setup_source_note':
      'Offers come from retailer flyers. Prices as stated by the retailer, without guarantee.',
  'offer_setup_next': 'Continue',
  'offer_setup_location_off':
      'Location is off. Enter your postcode or allow location in Settings.',
  // S15 Rezept.
  'offer_recipe_row_one':
      '1 ingredient on offer at {store} this week · for {list}, in your area',
  'offer_recipe_row_other':
      '{n} ingredients on offer at {store} this week · for {list}, in your area',
  'offer_recipe_row_hint_a11y': 'Shows the offers for this recipe',
  'offer_recipe_title': 'Offers for {recipe}',
  'offer_recipe_sentence':
      '{matched} of {total} ingredients on offer at {store} this week, for {list}, in your area',
  'offer_recipe_section': 'Ingredients on offer',
  // S8 Zähler.
  'offer_count_badge_one': '1 on offer',
  'offer_count_badge_other': '{n} on offer',
  'offer_count_badge_a11y_one': '1 item on offer',
  'offer_count_badge_a11y_other': '{n} items on offer',
  'offer_ends_today': 'ends today',
  'checkout_store_title': 'Which shop was that?',
  'checkout_store_body':
      'There are several shops here. Tell us which one, and Avo learns where you buy what — so offers shown to you are from the shops you actually use.',
  'checkout_store_location_off_body':
      'Without location access Avo cannot tell which shop you are in. That means no "your bananas are on offer at your REWE" — you can still enter the shop by hand.',
  'checkout_store_other': 'Another shop…',
  'checkout_store_hint': 'e.g. REWE, Lidl, Edeka',
  'checkout_store_skip': 'Skip',
  'flyer_title': 'Your flyer',
  'flyer_subtitle': '{count} things you buy regularly are on offer right now.',
  'flyer_section_savings': 'saves {amount} €',
  'offer_kw_show': 'offers, savings, show, hide offers, flyer',
  'offer_kw_detect': 'detect store, store, market, location, automatic',
};

const Map<String, String> offersDe = {
  // Pflicht-Wortlaut (angebote.md 3.3); zusammengesetzt nur in
  // offer_savings.dart (offerSummaryText).
  'offer_summary_head_one':
      '{matched} von 1 Artikel diese Woche bei {store} im Angebot',
  'offer_summary_head_other':
      '{matched} von {total} Artikeln diese Woche bei {store} im Angebot',
  'offer_summary_saved': 'ca. {amount} gespart',
  'offer_in_your_area': 'in deiner Region',
  'offer_retailer_prices': 'Preise laut Händler',
  'offer_summary_sentence': '{head}, ca. {amount} gespart, in deiner Region',
  'offer_summary_sentence_no_savings': '{head}, in deiner Region',
  'offer_was_price': 'laut Händler statt {price}',
  'offer_valid_until': 'bis {date}',
  'offer_ends_tomorrow': 'endet morgen',
  'offer_ends_weekday': 'endet {weekday}',
  'offer_similar_product': 'Ähnliches Produkt',
  'offer_source_footnote':
      'Angebote gelten für deine Region, nicht für einen bestimmten Markt. Preise sind Angaben des Händlers; Normalpreise kennt die App nicht. Quelle: {source}.',
  'offer_source_placeholder': 'Händlerprospekte',
  'offer_unit_price_a11y': '{price} pro {unit}',
  'offer_unit_l': 'Liter',
  'offer_unit_kg': 'Kilogramm',
  'offer_unit_piece': 'Stück',
  'offer_distance_m': '{n} m',
  'offer_distance_km': '{n} km',
  'offer_distance_m_a11y': '{n} Meter',
  'offer_distance_km_a11y': '{n} Kilometer',
  // Rückgängig-Hinweise (3.7).
  'offer_toast_store_set': 'Markt: {store}',
  'offer_toast_store_none': 'Kein fester Markt',
  'offer_toast_store_failed': 'Markt nicht gespeichert',
  'offer_toast_price_taken': 'Preis für {item} übernommen',
  'offer_toast_price_removed': 'Preis für {item} entfernt',
  'offer_toast_price_failed': 'Preis nicht gespeichert',
  'offer_toast_attached': 'Angebot an {item} angehängt',
  'offer_toast_added_list': '{item} auf {list}',
  'offer_toast_add_failed': 'Nicht hinzugefügt',
  'offer_toast_offer_hidden': 'Angebot für {item} ausgeblendet',
  'offer_toast_summary_week': 'Ersparnis-Zeile für diese Woche ausgeblendet',
  'offer_toast_summary_off': 'Ersparnis-Zeile ausgeschaltet',
  // S1 Markt-Chip.
  'offer_store_choose': 'Markt wählen',
  'offer_store_other': 'Anderer Markt …',
  'offer_store_none': 'Kein fester Markt',
  'offer_store_confirm_title': 'Ist das deine {store}-Liste?',
  'offer_store_confirm_yes': 'Ja, {store}',
  'offer_store_dont_ask': 'Nicht fragen',
  'offer_store_chip_a11y': 'Markt: {store}, ändern',
  'offer_store_chip_suggested_a11y':
      'Vorschlag: {store}. Bestätigen oder ändern',
  'offer_hint_no_store':
      'Für welchen Markt ist {list}? Dann siehst du dessen Angebote.',
  'offer_hint_no_store_action': 'Markt wählen',
  // S2 Markt wählen.
  'offer_pick_title': 'Markt',
  'offer_pick_search': 'Markt suchen',
  'offer_pick_yours': 'Deine Märkte',
  'offer_pick_nearby': 'In der Nähe',
  'offer_pick_all': 'Alle Märkte',
  'offer_pick_distance': '{street} · {distance}',
  'offer_pick_no_result': 'Kein Markt mit „{query}“ gefunden.',
  'offer_pick_use_custom': '„{query}“ als eigenen Markt verwenden',
  // S3 Angebots-Pille.
  'offer_module_off_body':
      'Schalte es ein, dann siehst du an deinen Listen, was bei deinem Markt im Angebot ist.',
  'offer_badge_a11y': 'im Angebot {price} laut Händler',
  'offer_badge_similar_a11y':
      'ähnliches Produkt im Angebot, {price} laut Händler',
  'offer_action_view': 'Angebot ansehen',
  // S4 Angebotskarte.
  'offer_card_kicker': 'Angebot',
  'offer_card_title': '{store} · {price}',
  'offer_card_price_taken': 'Preis übernommen',
  'offer_card_a11y': 'Angebot: {store}, {price}, {product}, {details}',
  // S5 Angebot.
  'offer_detail_title': 'Angebot',
  'offer_detail_was': 'laut Händler statt',
  'offer_detail_unit_price': 'Grundpreis',
  'offer_detail_valid': 'Gültig',
  'offer_detail_expired': 'abgelaufen',
  'offer_detail_store': 'Markt',
  'offer_detail_area': 'Region',
  'offer_detail_similar':
      'Ähnliches Produkt. Prüf vor dem Kauf, ob es zu „{item}“ passt.',
  'offer_detail_not_this': 'Nicht dieses Angebot',
  'offer_detail_more_at': 'Weitere Angebote bei {store}',
  'offer_detail_take_price': 'Preis übernehmen',
  'offer_detail_add_to_list': 'Auf die Liste',
  'offer_detail_remove_price': 'Übernommenen Preis entfernen',
  'offer_detail_expired_action': 'Angebot abgelaufen',
  'offer_detail_gone': 'Dieses Angebot ist nicht mehr gespeichert.',
  'offer_detail_swapped_a11y': 'Angebot gewechselt: {product}',
  'offer_price_tag_a11y': '{price}, Angebotspreis',
  // S6 Angebote beim Tippen.
  'offer_suggest_row_sub': '{store} · {pack} · bis {weekday}',
  'offer_suggest_row_a11y':
      '{product}, {store}, {pack}, bis {date}, im Angebot {price} laut Händler',
  'offer_suggest_row_hint_a11y': 'Fügt {item} hinzu',
  'offer_suggest_added_a11y': '{item} hinzugefügt, im Angebot',
  // S7 Ersparnis-Zeile.
  'offer_summary_hide_week': 'Diese Woche ausblenden',
  'offer_summary_never': 'Nicht mehr zeigen',
  'offer_summary_hint_a11y': 'Zeigt die Angebote dieser Liste',
  'offer_summary_card_a11y': '{sentence}. Preise laut Händler',
  // Zustände (3.4), Rückgängig (3.7), Erklärung (3.3).
  'offer_status_offline_as_of': 'Offline. Angebote vom Stand {datetime}.',
  'offer_status_offline_search':
      'Offline. Es werden nur gespeicherte Angebote gezeigt.',
  'offer_status_refresh_failed':
      'Angebote konnten gerade nicht aktualisiert werden.',
  'offer_status_load_failed': 'Angebote konnten gerade nicht geladen werden.',
  'offer_hint_set_postcode':
      'Für Angebote in deiner Region: Postleitzahl festlegen',
  'offer_hint_set_postcode_action': 'Festlegen',
  'offer_datetime': '{date}, {time}',
  'offer_savings_explainer':
      '„Gespart“ ist der Unterschied zu den „statt“-Preisen der Händler, gerechnet über den Grundpreis und deine Mengen. Der Wert ist ungefähr.',
  'offer_toast_attached_list': 'Angebot an {item} auf {list} angehängt',
  'offer_toast_added_no_offer':
      '{item} auf {list} · Angebot gilt nur bei {store}',
  'offer_toast_list_hidden': 'Angebote für {list} ausgeblendet',
  'offer_toast_list_shown': 'Angebote für {list} eingeblendet',
  'offer_toast_not_interested': 'Ausgeblendet bis {date}',
  'offer_toast_region_set': 'Region: {postcode} {city}',
  'offer_toast_region_removed': 'Region entfernt',
  'offer_toast_favorite_removed': '{store} entfernt',
  // S9 Angebote bei {Markt}.
  'offer_list_title': 'Angebote bei {store}',
  'offer_list_title_no_store': 'Angebote für {list}',
  'offer_list_on_list': 'Auf deiner Liste',
  'offer_list_regulars': 'Diese Woche bei {store}, oft gekauft',
  'offer_list_item_qty': '{item} · {qty}',
  'offer_list_all_offers': 'Alle Angebote der Woche',
  'offer_hide_for_list': 'Angebote für diese Liste ausblenden',
  'offer_add_plus_a11y': '{product} auf {list} setzen',
  'offer_list_empty_title': 'Gerade nichts im Angebot.',
  'offer_list_empty_body': 'Neue Angebote kommen meist am Montag.',
  'offer_need_area_title': 'Für Angebote brauchst du eine Region.',
  'offer_need_area_action': 'Postleitzahl festlegen',
  'offer_list_hidden_title': 'Angebote sind für {list} ausgeblendet.',
  'offer_show_again': 'Einblenden',
  // S10 Angebote der Woche.
  'offer_week_title': 'Angebote der Woche',
  'offer_week_area': 'In deiner Region · {postcode} {city}',
  'offer_week_area_a11y': 'Region: {postcode} {city}, ändern',
  'offer_week_search': 'Angebote suchen',
  'offer_week_seg_lists': 'Deine Listen',
  'offer_week_seg_regulars': 'Oft gekauft',
  'offer_week_section': '{list} · {store}',
  'offer_week_for_item': 'Für „{item}“ auf {list}',
  'offer_week_rhythm': '{store} · Kaufst du etwa alle {days} Tage',
  'offer_week_not_interested': 'Nicht interessiert',
  'offer_week_add_swipe': 'Auf die Liste',
  'offer_week_no_area_title': 'Wo kaufst du ein?',
  'offer_week_no_area_body':
      'Angebote gelten pro Region. Mit deiner Postleitzahl siehst du, was bei deinen Märkten im Angebot ist.',
  'offer_use_location': 'Standort verwenden',
  'offer_enter_postcode': 'Postleitzahl eingeben',
  'offer_location_off': 'Standort ist aus. In Einstellungen erlauben',
  'offer_week_lists_empty_title': 'Gerade nichts von deinen Listen im Angebot.',
  'offer_week_lists_empty_body': 'Such oben nach einem bestimmten Produkt.',
  'offer_week_regulars_empty':
      'Gerade ist nichts im Angebot, was du oft kaufst.',
  'offer_week_regulars_new':
      'Nach ein paar Einkäufen siehst du hier, was du oft kaufst und gerade im Angebot ist.',
  'offer_week_search_empty': 'Kein Angebot für „{query}“ in deiner Region.',
  'offer_menu_which_list': 'Auf welche Liste?',
  'offer_menu_not_valid_there': '{store} · Angebot gilt dort nicht',
  'offer_menu_new_list': 'Neue Liste …',
  // S11 Region.
  'offer_region_title': 'Region',
  'offer_region_title_stores': 'Standort',
  'offer_region_intro':
      'Angebote gelten für eine Region, nicht für einen einzelnen Markt. Wir speichern deine Postleitzahl und schicken sie nur an die Angebotsquelle.',
  'offer_region_intro_stores':
      'Mit deinem Standort kann Avo Märkte in deiner Nähe vorschlagen.',
  'offer_use_location_sub':
      'Fragt einmal nach deinem Standort. Gespeichert wird nur die Postleitzahl.',
  'offer_use_location_current': 'Aktuell: {postcode} {city}',
  'offer_postcode_label': 'Postleitzahl',
  'offer_postcode_placeholder': 'z. B. {example}',
  'offer_postcode_place': '{postcode} · {city}',
  'offer_postcode_place_fallback': 'PLZ {postcode}',
  'offer_region_remove': 'Region entfernen',
  'offer_locating_a11y': 'Standort wird ermittelt',
  'offer_location_unavailable':
      'Standort gerade nicht verfügbar. Gib deine Postleitzahl ein.',
  'offer_location_abroad': 'Angebote gibt es nur für Deutschland.',
  'offer_location_abroad_stores': 'Avo kennt bisher nur Märkte in Deutschland.',
  'offer_postcode_digits': 'Bitte 5 Ziffern eingeben.',
  'offer_postcode_unknown': 'Diese Postleitzahl kennen wir nicht.',
  // S12 Preise & Angebote.
  'offer_settings_title_stores': 'Märkte',
  'offer_settings_master_sub':
      'Angebote deiner Märkte in Listen und beim Hinzufügen',
  'offer_settings_show': 'Anzeigen',
  'offer_settings_on_items': 'Angebote an Artikeln',
  'offer_settings_while_typing': 'Vorschläge beim Tippen',
  'offer_settings_in_list': 'Ersparnis in der Liste',
  'offer_settings_in_list_sub': '„4 von 11 im Angebot“',
  'offer_settings_home_tips': 'Spar-Hinweise auf der Startseite',
  'offer_settings_history': 'Ersparnis im Verlauf und nach dem Einkauf',
  'offer_settings_my_stores': 'Meine Märkte',
  'offer_settings_add_store': '+ Markt',
  'offer_settings_no_favorites': 'Noch keine Lieblingsmärkte',
  'offer_settings_stores_a11y': 'Meine Märkte: {stores}. Bearbeiten',
  'offer_settings_detect': 'Markt automatisch erkennen',
  'offer_settings_detect_note':
      'Avo erkennt den Markt am Listennamen und an deinen Einkäufen. Mit Standort fragt Avo auch im Laden nach. Was Avo nur vermutet, bleibt ein Vorschlag.',
  'offer_settings_region': 'Region',
  'offer_settings_region_unset': 'Nicht festgelegt',
  'offer_settings_region_unset_a11y': 'nicht festgelegt, Warnung',
  'offer_settings_location_stores': 'Standort',
  'offer_settings_location_stores_sub': 'Für Markt-Vorschläge',
  'offer_settings_hidden_for': 'Ausgeblendet für',
  // S13 Lieblingsmärkte.
  'offer_favorites_title': 'Lieblingsmärkte',
  'offer_favorites_yours': 'Deine Märkte',
  'offer_favorites_more': 'Weitere Märkte',
  'offer_favorites_note_stores':
      'Diese Märkte stehen oben, wenn du für eine Liste einen Markt wählst.',
  'offer_favorites_empty': 'Noch keine Lieblingsmärkte.',
  // S14 Onboarding.
  'offer_setup_region': 'Region',
  'offer_setup_location_sub':
      'Einmalig, um Region und Märkte in der Nähe zu finden. Gespeichert wird nur die Postleitzahl.',
  'offer_setup_stores': 'Deine Märkte',
  'offer_setup_stores_note':
      'Wähl, wo du meistens einkaufst. Mehrere sind möglich.',
  'offer_setup_source_note':
      'Angebote stammen aus Prospekten der Händler. Preise laut Händler, ohne Gewähr.',
  'offer_setup_next': 'Weiter',
  'offer_setup_location_off':
      'Standort ist aus. Gib deine Postleitzahl ein oder erlaube ihn in den Einstellungen.',
  // S15 Rezept.
  'offer_recipe_row_one':
      '1 Zutat diese Woche bei {store} im Angebot · für {list}, in deiner Region',
  'offer_recipe_row_other':
      '{n} Zutaten diese Woche bei {store} im Angebot · für {list}, in deiner Region',
  'offer_recipe_row_hint_a11y': 'Zeigt die Angebote für dieses Rezept',
  'offer_recipe_title': 'Angebote für {recipe}',
  'offer_recipe_sentence':
      '{matched} von {total} Zutaten diese Woche bei {store} im Angebot, für {list}, in deiner Region',
  'offer_recipe_section': 'Zutaten im Angebot',
  // S8 Zähler.
  'offer_count_badge_one': '1 Angebot',
  'offer_count_badge_other': '{n} Angebote',
  'offer_count_badge_a11y_one': '1 Artikel im Angebot',
  'offer_count_badge_a11y_other': '{n} Artikel im Angebot',
  'offer_ends_today': 'endet heute',
  'checkout_store_title': 'In welchem Markt war das?',
  'checkout_store_body':
      'Hier liegen mehrere Märkte nebeneinander. Sag kurz welcher — dann lernt Avo, wo du was kaufst, und zeigt dir Angebote aus den Märkten, in denen du wirklich einkaufst.',
  'checkout_store_location_off_body':
      'Ohne Standortzugriff kann Avo nicht erkennen, in welchem Markt du bist. Damit entfällt „deine Bananen sind bei deinem REWE im Angebot“ — du kannst den Markt aber von Hand eintragen.',
  'checkout_store_other': 'Anderer Markt…',
  'checkout_store_hint': 'z. B. REWE, Lidl, Edeka',
  'checkout_store_skip': 'Überspringen',
  'flyer_title': 'Dein Prospekt',
  'flyer_subtitle':
      '{count} Sachen, die du regelmäßig kaufst, sind gerade im Angebot.',
  'flyer_section_savings': 'spart {amount} €',
  'offer_kw_show':
      'Angebote, Ersparnis, anzeigen, Angebote ausblenden, Prospekt',
  'offer_kw_detect': 'Markt erkennen, Markt, Laden, Standort, automatisch',
};
