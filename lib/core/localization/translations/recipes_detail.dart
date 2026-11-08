// Texte des Bereichs "recipes" (Teil A), Teil "Rezeptdetail, Zutaten auf die Liste", Deutsch und Englisch.
// Eigene Datei während A6, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A6 in recipes.dart zusammengeführt. Präfix: recipe_detail_.

const Map<String, String> recipesDetailEn = {
  // Toolbar, share
  'recipe_detail_save': 'Save',
  'recipe_detail_unsave': 'Remove from saved',
  'recipe_detail_share': 'Share',
  'recipe_detail_edit': 'Edit',
  'recipe_detail_share_text': '{name} by {author}. Recipe in Avo:',
  'recipe_detail_share_text_plain': '{name}. Recipe in Avo:',

  // Title, meta, author
  'recipe_detail_minutes': '{n} min',
  'recipe_detail_hours': '{h} h',
  'recipe_detail_hours_minutes': '{h} h {m} min',
  'recipe_detail_rating': '★ {rating} ({count})',
  'recipe_detail_rating_semantics': 'Rated {rating} of 5 by {count} people',
  'recipe_detail_vegan': 'vegan',
  'recipe_detail_vegetarian': 'vegetarian',
  'recipe_detail_by': 'by {name}',
  'recipe_detail_from_source': 'from {source}',
  'recipe_detail_source_wikibooks': 'Wikibooks Cookbook',
  'recipe_detail_source_web': 'a website',
  'recipe_detail_source_footer': 'Source: {source}',
  'recipe_detail_source_open': 'Open source',

  // States
  'recipe_detail_offline': 'Offline. Saved version.',
  'recipe_detail_loading': 'Loading recipe',
  'recipe_detail_gone_title': 'This recipe is no longer available.',
  'recipe_detail_gone_message': 'It was deleted or is no longer public.',
  'recipe_detail_gone_action': 'Go to recipes',
  'recipe_detail_failed_title': 'The recipe could not be loaded.',
  'recipe_detail_failed_message': 'Check your connection and try again.',
  'recipe_detail_failed_offline':
      'No connection, and this recipe is not saved on this iPhone yet.',
  'recipe_detail_more_text': 'More',

  // Allergy notice (Konzept 13 §2.3)
  'recipe_detail_contains': 'Contains {allergen} ({ingredients}).',
  'recipe_detail_you_listed': 'You listed “{allergy}” under your allergies.',
  'recipe_detail_substitute_suggested': 'A substitute is suggested.',
  'recipe_detail_no_safe_substitute':
      'We know no safe substitute for {allergen}.',
  'recipe_detail_adapted_diet_one':
      'Adapted for you: 1 ingredient replaced because you eat {diet}.',
  'recipe_detail_adapted_diet_many':
      'Adapted for you: {count} ingredients replaced because you eat {diet}.',
  'recipe_detail_diet_conflict':
      'Not {diet}: {ingredients}. We know no substitute for it.',
  'recipe_detail_unchecked_one':
      '1 ingredient could not be checked for allergens: {ingredients}.',
  'recipe_detail_unchecked_many':
      '{count} ingredients could not be checked for allergens: {ingredients}.',
  'recipe_detail_allergy_footnote':
      'No guarantee. Check the ingredients on the pack.',
  'recipe_detail_contains_short': 'contains {allergen}',
  'recipe_detail_unchecked_short': 'not checked for allergens',
  'recipe_detail_diet_vegan': 'vegan',
  'recipe_detail_diet_vegetarian': 'vegetarian',
  'recipe_detail_diet_pescatarian': 'pescatarian',
  'recipe_detail_allergen_gluten': 'gluten',
  'recipe_detail_allergen_crustaceans': 'shellfish',
  'recipe_detail_allergen_eggs': 'egg',
  'recipe_detail_allergen_fish': 'fish',
  'recipe_detail_allergen_peanuts': 'peanut',
  'recipe_detail_allergen_soy': 'soy',
  'recipe_detail_allergen_milk': 'milk',
  'recipe_detail_allergen_nuts': 'tree nuts',
  'recipe_detail_allergen_celery': 'celery',
  'recipe_detail_allergen_mustard': 'mustard',
  'recipe_detail_allergen_sesame': 'sesame',
  'recipe_detail_allergen_sulfites': 'sulphites',
  'recipe_detail_allergen_lupin': 'lupin',
  'recipe_detail_allergen_molluscs': 'molluscs',
  'recipe_detail_allergen_lactose': 'lactose',
  'recipe_detail_allergen_fructose': 'fructose',
  'recipe_detail_allergen_histamine': 'histamine',
  'recipe_detail_allergen_nightshades': 'nightshades',
  'recipe_detail_allergen_corn': 'corn',
  'recipe_detail_allergen_yeast': 'yeast',
  'recipe_detail_profile_gluten': 'You entered a gluten intolerance.',
  'recipe_detail_profile_crustaceans': 'You entered a shellfish allergy.',
  'recipe_detail_profile_eggs': 'You entered an egg allergy.',
  'recipe_detail_profile_fish': 'You entered a fish allergy.',
  'recipe_detail_profile_peanuts': 'You entered a peanut allergy.',
  'recipe_detail_profile_soy': 'You entered a soy allergy.',
  'recipe_detail_profile_milk': 'You entered a milk allergy.',
  'recipe_detail_profile_nuts': 'You entered a tree nut allergy.',
  'recipe_detail_profile_celery': 'You entered a celery allergy.',
  'recipe_detail_profile_mustard': 'You entered a mustard allergy.',
  'recipe_detail_profile_sesame': 'You entered a sesame allergy.',
  'recipe_detail_profile_sulfites': 'You entered a sulphite intolerance.',
  'recipe_detail_profile_lupin': 'You entered a lupin allergy.',
  'recipe_detail_profile_molluscs': 'You entered a mollusc allergy.',
  'recipe_detail_profile_lactose': 'You entered a lactose intolerance.',
  'recipe_detail_profile_fructose': 'You entered a fructose intolerance.',
  'recipe_detail_profile_histamine': 'You entered a histamine intolerance.',
  'recipe_detail_profile_nightshades':
      'You entered a nightshade intolerance.',
  'recipe_detail_profile_corn': 'You entered a corn allergy.',
  'recipe_detail_profile_yeast': 'You entered a yeast intolerance.',
  'recipe_detail_profile_gluten_free': 'You eat gluten-free.',
  'recipe_detail_profile_dairy_free': 'You eat dairy-free.',
  'recipe_detail_profile_nut_free': 'You eat nut-free.',

  // Ingredients and steps
  'recipe_detail_ingredients': 'Ingredients',
  'recipe_detail_servings': 'Servings',
  'recipe_detail_variant': 'Version',
  'recipe_detail_variant_adapted': 'Adapted for you',
  'recipe_detail_variant_original': 'Original',
  'recipe_detail_instead_allergen': 'instead of {name} · because of {reason}',
  'recipe_detail_instead_diet': 'instead of {name} · because you eat {diet}',
  'recipe_detail_on_list': 'Already on {list}',
  'recipe_detail_on_list_quantity': 'Already on {list} ({quantity})',
  'recipe_detail_steps': 'Method',
  'recipe_detail_steps_one': '1 step',
  'recipe_detail_steps_many': '{count} steps',
  'recipe_detail_step': 'Step {n}',

  // Nutrition
  'recipe_detail_nutrition': 'Nutrition',
  'recipe_detail_nutrition_footer':
      'Per serving. Bars: share of an adult’s daily reference intake.',
  'recipe_detail_energy': 'Energy',
  'recipe_detail_protein': 'Protein',
  'recipe_detail_carbs': 'Carbohydrates',
  'recipe_detail_fat': 'Fat',
  'recipe_detail_kcal': '{n} kcal',
  'recipe_detail_grams': '{n} g',
  'recipe_detail_nutrition_value':
      '{value}, {percent} percent of the daily reference',
  'recipe_detail_log': 'Log to food diary',

  // Rating
  'recipe_detail_your_rating': 'Your rating',
  'recipe_detail_stars': '{n} of 5 stars',
  'recipe_detail_not_rated': 'not rated',
  'recipe_detail_rating_failed': 'Rating not saved.',

  // Action bar
  'recipe_detail_to_list': 'Add ingredients to list',
  'recipe_detail_to_list_short': 'To list',
  'recipe_detail_cook': 'Cook',
  'recipe_detail_cook_start': 'Start cooking',
  'recipe_detail_cook_continue': 'Continue: step {n}',

  // Menu, delete, report
  'recipe_detail_report': 'Report',
  'recipe_detail_delete': 'Delete',
  'recipe_detail_delete_title': 'Delete “{name}”?',
  'recipe_detail_delete_message':
      'The recipe, its ratings and comments are deleted for everyone. People '
      'who saved it will no longer see it. This cannot be undone.',
  'recipe_detail_deleted': 'Recipe deleted',
  'recipe_detail_delete_failed': 'The recipe could not be deleted.',
  'recipe_detail_report_send': 'Send',
  'recipe_detail_report_reasons': 'What is wrong?',
  'recipe_detail_report_inappropriate': 'Inappropriate content',
  'recipe_detail_report_spam': 'Spam or advertising',
  'recipe_detail_report_dangerous': 'Dangerous information (e.g. wrong allergens)',
  'recipe_detail_report_copyright': 'Copyright',
  'recipe_detail_report_other': 'Something else',
  'recipe_detail_report_note': 'Anything we should know? (optional)',
  'recipe_detail_report_footer':
      'Your mail app opens with the report to {email}; send it there.',
  'recipe_detail_report_subject': 'Report recipe: {name}',
  'recipe_detail_report_body': 'Recipe: {name}\nID: {id}\nReason: {reason}\n\n{note}',
  'recipe_detail_report_ready': 'Your report is ready in your mail app.',
  'recipe_detail_report_no_mail': 'No mail app found. Write to {email}.',

  // Zutaten auf die Liste (Konzept 13 §13)
  'recipe_detail_tolist_list': 'List',
  'recipe_detail_tolist_new_list': 'New list',
  'recipe_detail_tolist_new_list_value': 'New list: {name}',
  'recipe_detail_tolist_default_name': 'Shopping',
  'recipe_detail_tolist_open_count': '{count} open',
  'recipe_detail_tolist_new_list_hint': 'Name of the list',
  'recipe_detail_tolist_create': 'Create',
  'recipe_detail_tolist_count': '{selected} of {total}',
  'recipe_detail_tolist_add_one': 'Add 1 ingredient',
  'recipe_detail_tolist_add_many': 'Add {count} ingredients',
  'recipe_detail_tolist_none': 'No ingredient selected',
  'recipe_detail_tolist_all_there': 'Everything is already on {list}.',
  'recipe_detail_tolist_staple': 'Usually at home',
  'recipe_detail_tolist_added_one': '1 ingredient on {list}',
  'recipe_detail_tolist_added_many': '{count} ingredients on {list}',
  'recipe_detail_tolist_failed': 'Ingredients not added.',
  'recipe_detail_tolist_undo_failed': 'Could not undo.',
  'recipe_detail_tolist_empty': 'This recipe has no ingredients.',
};

const Map<String, String> recipesDetailDe = {
  // Toolbar, share
  'recipe_detail_save': 'Merken',
  'recipe_detail_unsave': 'Nicht mehr merken',
  'recipe_detail_share': 'Teilen',
  'recipe_detail_edit': 'Bearbeiten',
  'recipe_detail_share_text': '{name} von {author}. Rezept in Avo:',
  'recipe_detail_share_text_plain': '{name}. Rezept in Avo:',

  // Title, meta, author
  'recipe_detail_minutes': '{n} Min',
  'recipe_detail_hours': '{h} Std.',
  'recipe_detail_hours_minutes': '{h} Std. {m} Min',
  'recipe_detail_rating': '★ {rating} ({count})',
  'recipe_detail_rating_semantics': 'Bewertet mit {rating} von 5, {count} Bewertungen',
  'recipe_detail_vegan': 'vegan',
  'recipe_detail_vegetarian': 'vegetarisch',
  'recipe_detail_by': 'von {name}',
  'recipe_detail_from_source': 'aus {source}',
  'recipe_detail_source_wikibooks': 'Wikibooks Kochbuch',
  'recipe_detail_source_web': 'einer Webseite',
  'recipe_detail_source_footer': 'Quelle: {source}',
  'recipe_detail_source_open': 'Quelle öffnen',

  // States
  'recipe_detail_offline': 'Offline. Gespeicherte Fassung.',
  'recipe_detail_loading': 'Rezept wird geladen',
  'recipe_detail_gone_title': 'Dieses Rezept gibt es nicht mehr.',
  'recipe_detail_gone_message': 'Es wurde gelöscht oder ist nicht mehr öffentlich.',
  'recipe_detail_gone_action': 'Zu den Rezepten',
  'recipe_detail_failed_title': 'Das Rezept konnte nicht geladen werden.',
  'recipe_detail_failed_message': 'Prüf die Verbindung und versuch es noch einmal.',
  'recipe_detail_failed_offline':
      'Keine Verbindung, und das Rezept ist noch nicht auf diesem iPhone gespeichert.',
  'recipe_detail_more_text': 'Mehr',

  // Allergy notice (Konzept 13 §2.3)
  'recipe_detail_contains': 'Enthält {allergen} ({ingredients}).',
  'recipe_detail_you_listed': 'Du hast „{allergy}“ bei deinen Allergien eingetragen.',
  'recipe_detail_substitute_suggested': 'Ein Ersatz ist vorgeschlagen.',
  'recipe_detail_no_safe_substitute':
      'Für {allergen} kennen wir keinen sicheren Ersatz.',
  'recipe_detail_adapted_diet_one':
      'Für dich angepasst: 1 Zutat ersetzt, weil du {diet} isst.',
  'recipe_detail_adapted_diet_many':
      'Für dich angepasst: {count} Zutaten ersetzt, weil du {diet} isst.',
  'recipe_detail_diet_conflict':
      'Nicht {diet}: {ingredients}. Dafür kennen wir keinen Ersatz.',
  'recipe_detail_unchecked_one':
      '1 Zutat konnte nicht auf Allergene geprüft werden: {ingredients}.',
  'recipe_detail_unchecked_many':
      '{count} Zutaten konnten nicht auf Allergene geprüft werden: {ingredients}.',
  'recipe_detail_allergy_footnote':
      'Angaben ohne Gewähr. Prüfe die Zutaten auf der Packung.',
  'recipe_detail_contains_short': 'enthält {allergen}',
  'recipe_detail_unchecked_short': 'nicht auf Allergene geprüft',
  'recipe_detail_diet_vegan': 'vegan',
  'recipe_detail_diet_vegetarian': 'vegetarisch',
  'recipe_detail_diet_pescatarian': 'pescetarisch',
  'recipe_detail_allergen_gluten': 'Gluten',
  'recipe_detail_allergen_crustaceans': 'Krebstiere',
  'recipe_detail_allergen_eggs': 'Ei',
  'recipe_detail_allergen_fish': 'Fisch',
  'recipe_detail_allergen_peanuts': 'Erdnuss',
  'recipe_detail_allergen_soy': 'Soja',
  'recipe_detail_allergen_milk': 'Milch',
  'recipe_detail_allergen_nuts': 'Nüsse',
  'recipe_detail_allergen_celery': 'Sellerie',
  'recipe_detail_allergen_mustard': 'Senf',
  'recipe_detail_allergen_sesame': 'Sesam',
  'recipe_detail_allergen_sulfites': 'Sulfite',
  'recipe_detail_allergen_lupin': 'Lupinen',
  'recipe_detail_allergen_molluscs': 'Weichtiere',
  'recipe_detail_allergen_lactose': 'Laktose',
  'recipe_detail_allergen_fructose': 'Fruktose',
  'recipe_detail_allergen_histamine': 'Histamin',
  'recipe_detail_allergen_nightshades': 'Nachtschattengewächse',
  'recipe_detail_allergen_corn': 'Mais',
  'recipe_detail_allergen_yeast': 'Hefe',
  'recipe_detail_profile_gluten': 'Du hast eine Glutenunverträglichkeit eingetragen.',
  'recipe_detail_profile_crustaceans':
      'Du hast eine Allergie gegen Krebstiere eingetragen.',
  'recipe_detail_profile_eggs': 'Du hast eine Eierallergie eingetragen.',
  'recipe_detail_profile_fish': 'Du hast eine Fischallergie eingetragen.',
  'recipe_detail_profile_peanuts': 'Du hast eine Erdnussallergie eingetragen.',
  'recipe_detail_profile_soy': 'Du hast eine Sojaallergie eingetragen.',
  'recipe_detail_profile_milk': 'Du hast eine Milchallergie eingetragen.',
  'recipe_detail_profile_nuts': 'Du hast eine Nussallergie eingetragen.',
  'recipe_detail_profile_celery': 'Du hast eine Sellerieallergie eingetragen.',
  'recipe_detail_profile_mustard': 'Du hast eine Senfallergie eingetragen.',
  'recipe_detail_profile_sesame': 'Du hast eine Sesamallergie eingetragen.',
  'recipe_detail_profile_sulfites':
      'Du hast eine Sulfitunverträglichkeit eingetragen.',
  'recipe_detail_profile_lupin': 'Du hast eine Lupinenallergie eingetragen.',
  'recipe_detail_profile_molluscs':
      'Du hast eine Allergie gegen Weichtiere eingetragen.',
  'recipe_detail_profile_lactose': 'Du hast eine Laktoseintoleranz eingetragen.',
  'recipe_detail_profile_fructose': 'Du hast eine Fruktoseintoleranz eingetragen.',
  'recipe_detail_profile_histamine':
      'Du hast eine Histaminintoleranz eingetragen.',
  'recipe_detail_profile_nightshades':
      'Du hast eine Unverträglichkeit gegen Nachtschattengewächse eingetragen.',
  'recipe_detail_profile_corn': 'Du hast eine Maisallergie eingetragen.',
  'recipe_detail_profile_yeast': 'Du hast eine Hefeunverträglichkeit eingetragen.',
  'recipe_detail_profile_gluten_free': 'Du isst glutenfrei.',
  'recipe_detail_profile_dairy_free': 'Du isst milchfrei.',
  'recipe_detail_profile_nut_free': 'Du isst nussfrei.',

  // Ingredients and steps
  'recipe_detail_ingredients': 'Zutaten',
  'recipe_detail_servings': 'Portionen',
  'recipe_detail_variant': 'Fassung',
  'recipe_detail_variant_adapted': 'Für dich angepasst',
  'recipe_detail_variant_original': 'Original',
  'recipe_detail_instead_allergen': 'statt {name} · wegen {reason}',
  'recipe_detail_instead_diet': 'statt {name} · weil du {diet} isst',
  'recipe_detail_on_list': 'Schon auf {list}',
  'recipe_detail_on_list_quantity': 'Schon auf {list} ({quantity})',
  'recipe_detail_steps': 'Zubereitung',
  'recipe_detail_steps_one': '1 Schritt',
  'recipe_detail_steps_many': '{count} Schritte',
  'recipe_detail_step': 'Schritt {n}',

  // Nutrition
  'recipe_detail_nutrition': 'Nährwerte',
  'recipe_detail_nutrition_footer':
      'Pro Portion. Balken: Anteil an der Tagesreferenz für Erwachsene.',
  'recipe_detail_energy': 'Energie',
  'recipe_detail_protein': 'Eiweiß',
  'recipe_detail_carbs': 'Kohlenhydrate',
  'recipe_detail_fat': 'Fett',
  'recipe_detail_kcal': '{n} kcal',
  'recipe_detail_grams': '{n} g',
  'recipe_detail_nutrition_value': '{value}, {percent} Prozent der Tagesreferenz',
  'recipe_detail_log': 'Ins Tagebuch eintragen',

  // Rating
  'recipe_detail_your_rating': 'Deine Bewertung',
  'recipe_detail_stars': '{n} von 5 Sternen',
  'recipe_detail_not_rated': 'nicht bewertet',
  'recipe_detail_rating_failed': 'Bewertung nicht gespeichert.',

  // Action bar
  'recipe_detail_to_list': 'Zutaten auf die Liste',
  'recipe_detail_to_list_short': 'Auf die Liste',
  'recipe_detail_cook': 'Kochen',
  'recipe_detail_cook_start': 'Kochen starten',
  'recipe_detail_cook_continue': 'Weiter: Schritt {n}',

  // Menu, delete, report
  'recipe_detail_report': 'Melden',
  'recipe_detail_delete': 'Löschen',
  'recipe_detail_delete_title': '„{name}“ löschen?',
  'recipe_detail_delete_message':
      'Das Rezept, seine Bewertungen und Kommentare werden für alle gelöscht. '
      'Wer es gespeichert hat, sieht es nicht mehr. Das lässt sich nicht '
      'rückgängig machen.',
  'recipe_detail_deleted': 'Rezept gelöscht',
  'recipe_detail_delete_failed': 'Rezept konnte nicht gelöscht werden.',
  'recipe_detail_report_send': 'Senden',
  'recipe_detail_report_reasons': 'Was stimmt nicht?',
  'recipe_detail_report_inappropriate': 'Unpassender Inhalt',
  'recipe_detail_report_spam': 'Spam oder Werbung',
  'recipe_detail_report_dangerous': 'Gefährliche Angaben (z. B. Allergene falsch)',
  'recipe_detail_report_copyright': 'Urheberrecht',
  'recipe_detail_report_other': 'Etwas anderes',
  'recipe_detail_report_note': 'Was sollen wir wissen? (freiwillig)',
  'recipe_detail_report_footer':
      'Deine Mail-App öffnet sich mit der Meldung an {email}; dort sendest du sie.',
  'recipe_detail_report_subject': 'Rezept melden: {name}',
  'recipe_detail_report_body': 'Rezept: {name}\nID: {id}\nGrund: {reason}\n\n{note}',
  'recipe_detail_report_ready': 'Die Meldung ist in deiner Mail-App fertig.',
  'recipe_detail_report_no_mail': 'Keine Mail-App gefunden. Schreib an {email}.',

  // Zutaten auf die Liste (Konzept 13 §13)
  'recipe_detail_tolist_list': 'Liste',
  'recipe_detail_tolist_new_list': 'Neue Liste',
  'recipe_detail_tolist_new_list_value': 'Neue Liste: {name}',
  'recipe_detail_tolist_default_name': 'Einkauf',
  'recipe_detail_tolist_open_count': '{count} offen',
  'recipe_detail_tolist_new_list_hint': 'Name der Liste',
  'recipe_detail_tolist_create': 'Anlegen',
  'recipe_detail_tolist_count': '{selected} von {total}',
  'recipe_detail_tolist_add_one': '1 Zutat hinzufügen',
  'recipe_detail_tolist_add_many': '{count} Zutaten hinzufügen',
  'recipe_detail_tolist_none': 'Keine Zutat gewählt',
  'recipe_detail_tolist_all_there': 'Alles schon auf {list}.',
  'recipe_detail_tolist_staple': 'Hast du meist da',
  'recipe_detail_tolist_added_one': '1 Zutat auf {list}',
  'recipe_detail_tolist_added_many': '{count} Zutaten auf {list}',
  'recipe_detail_tolist_failed': 'Zutaten nicht hinzugefügt.',
  'recipe_detail_tolist_undo_failed': 'Widerrufen hat nicht geklappt.',
  'recipe_detail_tolist_empty': 'Dieses Rezept hat keine Zutaten.',
};
