// Texte des Bereichs "offers" (Teil B), Deutsch und Englisch.
// Entstanden am 07.11.2026 aus app_translations.dart (A1). Pflege: nur Teil B.
// Neue Schlüssel bekommen das Bereichs-Präfix, siehe docs/redesign/arbeitsteilung.md 3.6.

const Map<String, String> offersEn = {
  'weekly_deals_title': 'This week\'s deals',
  'search_deals_hint': 'Search for a product…',
  'deals_matching_your_lists': 'Matching your lists',
  'no_personalized_deals_hint':
      'No current offers match items on your lists. Try searching for something specific above.',
  'no_deals_found': 'No current offers found for that.',
  'deals_load_error': 'Couldn\'t load deals right now. Try again later.',
  'matched_for_item': 'For "{item}" on your list',
  'enter_zip_prompt': 'Enter your zip code to see nearby offers',
  'zip_code_label': 'Zip {zip}',
  'instead_of_price': 'was {price} €',
  'saves_amount': 'saves {amount} €',
  'offers_nearby': 'Offers nearby',
  'price_data_from_offers': 'Compare prices across nearby stores',
  'known_of_items': 'known ({known}/{total} items)',
  'cheapest_at': 'Cheapest: {store}',
  'cheapest_basket': 'cheapest basket',
  'store_comparison': 'Store comparison',
  'matched_of_items': 'Based on {count} items on your list with current offers',
  'offers_source_note':
      'Offer prices only — regular shelf prices aren\'t publicly available.',
  'offer_ends_today': 'Offer ends today',
  'offer_ends_in_days': 'Offer ends in {days}d',
  'similar_product_match': 'Similar product',
  'recipe_offers_title': 'On offer this week',
  'recipe_offers_subtitle':
      '{count} of {total} ingredients are on offer near you',
  'recipe_offers_save': 'Save up to {amount} € vs. regular prices',
  'similar_product_note':
      'Matched by category, not the exact name you typed — double-check it\'s the right product before adding.',
  'broad_match_items_note':
      '{count} item(s) priced from a similar product, not an exact name match — worth a quick check.',
  'set_zip_code_prompt': 'Add your zip code to see nearby offers',
  'set_zip_code_title': 'Set your zip code',
  'set_zip_code_body':
      'Used to show current offers and store prices near you. You can change this anytime in your profile.',
  'comparable_note':
      'Totals cover the same {count} items — items a store doesn\'t have on offer are filled with the cheapest price found nearby.',
  'items_on_offer_here': '{matched}/{total} on offer here',
  'save_at_store': 'Save {amount} € at {store}',
  'current_offer': 'Current offer',
  'apply_offer_price': 'Use this price',
  'swap_saves': 'Saves {amount} € vs. your saved price of {price} €',
  'valid_until_date': 'Valid until {date}',
  'estimated_list_total': 'Whole list, estimated ({known}/{total} items)',
  'offers_nationwide_set_zip':
      'Nationwide offers — set your zip for local prices',
  'closer_option_title': 'Closer option',
  'closer_option_body':
      '{store} has a branch {distance} away — only {extra} € more than the cheapest total.',
  'home_price_highlight_title':
      '{listName} is {amount} € cheaper at {cheaperStore} than {pricierStore}',
  'home_price_highlight_subtitle':
      'Based on {matched} of {total} items with current offers',
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
  'weekly_deals_title': 'Angebote der Woche',
  'search_deals_hint': 'Produkt suchen…',
  'deals_matching_your_lists': 'Passend zu deinen Listen',
  'no_personalized_deals_hint':
      'Aktuell kein Angebot passend zu deinen Listen. Nutze oben die Suche für ein bestimmtes Produkt.',
  'no_deals_found': 'Keine aktuellen Angebote dafür gefunden.',
  'deals_load_error':
      'Angebote konnten gerade nicht geladen werden. Versuch es später erneut.',
  'matched_for_item': 'Für „{item}“ auf deiner Liste',
  'enter_zip_prompt': 'PLZ eingeben, um Angebote in deiner Nähe zu sehen',
  'zip_code_label': 'PLZ {zip}',
  'instead_of_price': 'statt {price} €',
  'saves_amount': 'spart {amount} €',
  'offers_nearby': 'Angebote in der Nähe',
  'price_data_from_offers': 'Preise der Märkte in der Nähe vergleichen',
  'known_of_items': 'bekannt ({known}/{total} Artikel)',
  'cheapest_at': 'Günstigster: {store}',
  'cheapest_basket': 'günstigster Korb',
  'store_comparison': 'Marktvergleich',
  'matched_of_items':
      'Basierend auf {count} Artikeln deiner Liste mit aktuellen Angeboten',
  'offers_source_note':
      'Nur Angebotspreise — reguläre Preise sind nicht öffentlich verfügbar.',
  'offer_ends_today': 'Angebot endet heute',
  'offer_ends_in_days': 'Angebot endet in {days}T',
  'similar_product_match': 'Ähnliches Produkt',
  'recipe_offers_title': 'Diese Woche im Angebot',
  'recipe_offers_subtitle':
      '{count} von {total} Zutaten sind bei dir im Angebot',
  'recipe_offers_save': 'Spare bis zu {amount} € gegenüber Normalpreisen',
  'similar_product_note':
      'Über die Kategorie gefunden, nicht den genauen Namen — bitte prüfen, ob es das richtige Produkt ist, bevor du es hinzufügst.',
  'broad_match_items_note':
      '{count} Artikel mit Preis eines ähnlichen Produkts, nicht exakt passend — kurz prüfen lohnt sich.',
  'set_zip_code_prompt':
      'Postleitzahl hinzufügen, um Angebote in der Nähe zu sehen',
  'set_zip_code_title': 'Postleitzahl festlegen',
  'set_zip_code_body':
      'Wird verwendet, um aktuelle Angebote und Preise in deiner Nähe zu zeigen. Du kannst dies jederzeit in deinem Profil ändern.',
  'comparable_note':
      'Alle Summen umfassen dieselben {count} Artikel — Artikel ohne Angebot im Markt werden mit dem günstigsten Preis aus der Nähe aufgefüllt.',
  'items_on_offer_here': '{matched}/{total} hier im Angebot',
  'save_at_store': 'Spare {amount} € bei {store}',
  'current_offer': 'Aktuelles Angebot',
  'apply_offer_price': 'Preis übernehmen',
  'swap_saves':
      'Spart {amount} € gegenüber deinem gespeicherten Preis von {price} €',
  'valid_until_date': 'Gültig bis {date}',
  'estimated_list_total': 'Ganze Liste, geschätzt ({known}/{total} Artikel)',
  'offers_nationwide_set_zip':
      'Deutschlandweite Angebote — PLZ für lokale Preise festlegen',
  'closer_option_title': 'Näher dran',
  'closer_option_body':
      '{store} hat eine Filiale {distance} entfernt — nur {extra} € mehr als die günstigste Summe.',
  'home_price_highlight_title':
      '{listName} ist bei {cheaperStore} {amount} € günstiger als bei {pricierStore}',
  'home_price_highlight_subtitle':
      'Basierend auf {matched} von {total} Artikeln mit aktuellen Angeboten',
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
