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
  // S8 Zähler.
  'offer_count_badge_one': '1 on offer',
  'offer_count_badge_other': '{n} on offer',
  'offer_count_badge_a11y_one': '1 item on offer',
  'offer_count_badge_a11y_other': '{n} items on offer',
  'weekly_deals_title': 'This week\'s deals',
  'search_deals_hint': 'Search for a product…',
  'deals_matching_your_lists': 'Matching your lists',
  'no_personalized_deals_hint':
      'No current offers match items on your lists. Try searching for something specific above.',
  'no_deals_found': 'No current offers found for that.',
  'deals_load_error': 'Couldn\'t load deals right now. Try again later.',
  'matched_for_item': 'For "{item}" on your list',
  'instead_of_price': 'was {price} €',
  'offer_ends_today': 'ends today',
  'offer_ends_in_days': 'Offer ends in {days}d',
  'similar_product_match': 'Similar product',
  'recipe_offers_title': 'On offer this week',
  'recipe_offers_subtitle':
      '{count} of {total} ingredients are on offer near you',
  'set_zip_code_title': 'Set your zip code',
  'set_zip_code_body':
      'Used to show current offers and store prices near you. You can change this anytime in your profile.',
  'offers_nationwide_set_zip':
      'Nationwide offers — set your zip for local prices',
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
  // S8 Zähler.
  'offer_count_badge_one': '1 Angebot',
  'offer_count_badge_other': '{n} Angebote',
  'offer_count_badge_a11y_one': '1 Artikel im Angebot',
  'offer_count_badge_a11y_other': '{n} Artikel im Angebot',
  'weekly_deals_title': 'Angebote der Woche',
  'search_deals_hint': 'Produkt suchen…',
  'deals_matching_your_lists': 'Passend zu deinen Listen',
  'no_personalized_deals_hint':
      'Aktuell kein Angebot passend zu deinen Listen. Nutze oben die Suche für ein bestimmtes Produkt.',
  'no_deals_found': 'Keine aktuellen Angebote dafür gefunden.',
  'deals_load_error':
      'Angebote konnten gerade nicht geladen werden. Versuch es später erneut.',
  'matched_for_item': 'Für „{item}“ auf deiner Liste',
  'instead_of_price': 'statt {price} €',
  'offer_ends_today': 'endet heute',
  'offer_ends_in_days': 'Angebot endet in {days}T',
  'similar_product_match': 'Ähnliches Produkt',
  'recipe_offers_title': 'Diese Woche im Angebot',
  'recipe_offers_subtitle':
      '{count} von {total} Zutaten sind bei dir im Angebot',
  'set_zip_code_title': 'Postleitzahl festlegen',
  'set_zip_code_body':
      'Wird verwendet, um aktuelle Angebote und Preise in deiner Nähe zu zeigen. Du kannst dies jederzeit in deinem Profil ändern.',
  'offers_nationwide_set_zip':
      'Deutschlandweite Angebote — PLZ für lokale Preise festlegen',
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
};
