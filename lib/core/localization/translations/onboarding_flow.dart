// Texte des Bereichs "onboarding" (Teil A), Teil "Ablauf" (Willkommen, Module, Region, Ernährung, Ziel, Erste Liste), Deutsch und Englisch.
// Eigene Datei während A7, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A7 zusammengeführt. Präfix: onb_. Neue Texte sagen "Avo", nie "Shoply".
// Lange deutsche Wörter tragen weiche Trennstellen (U+00AD, Konzept 17 §2.3).

const Map<String, String> onboardingFlowEn = {
  // Rahmen
  'onb_progress': 'Step {step} of {total}',
  'onb_sync_failed': 'Your answers aren’t saved yet.',

  // Willkommen (§3.2)
  'onb_welcome_title': 'Avo',
  'onb_welcome_sentence': 'A shopping list and recipes that think ahead.',
  'onb_welcome_start': 'Get started',
  'onb_welcome_have_account': 'I already have an account',
  'onb_welcome_login': 'Sign in',
  'onb_welcome_new_account': 'Create a new account',
  'onb_welcome_invited': 'You’ve been invited to a list.',

  // Module (§3.3, D2)
  'onb_modules_title': 'What should Avo do for you?',
  'onb_modules_sentence':
      'Lists and recipes are always included. You can change the rest in your profile at any time.',
  'onb_modules_later': 'Decide later',
  'onb_modules_ai_note_avo':
      'Sorting into categories and Avo use AI by Anthropic (Claude). Item names and your questions are sent to Anthropic for this.',
  'onb_modules_ai_note':
      'Sorting into categories uses AI by Anthropic (Claude). Item names are sent to Anthropic for this.',
  'onb_modules_privacy': 'Privacy',
  'onb_module_offers_benefit': 'Shows what on your list is on offer this week.',
  'onb_module_meal_plan_benefit':
      'Recipes for the week, ingredients on the list with one tap.',
  'onb_module_avo_benefit': 'Ask or talk, Avo does it in the app.',
  'onb_module_calories_benefit':
      'Log food by photo or barcode, with Apple Health.',
  'onb_module_cost_split_benefit': 'Split shopping fairly in a flat or family.',

  // Region (§3.4)
  'onb_region_title': 'Offers in your area',
  'onb_region_sentence':
      'You only see offers from the stores you shop at. For that we need your area.',

  // Ernährung und Allergien (§3.9)
  'onb_food_title': 'Diet and allergies',
  'onb_food_sentence': 'Recipes adapt to it and point out allergens.',
  'onb_food_diet_heading': 'Diet',
  'onb_food_allergy_heading': 'Allergies and intolerances',
  'onb_food_more': 'Show more',
  'onb_food_footnote':
      'Allergen notes help, but they don’t replace checking the ingredient list.',
  'onb_allergy_gluten': 'Gluten',
  'onb_allergy_milk': 'Milk',
  'onb_allergy_lactose': 'Lactose',
  'onb_allergy_eggs': 'Eggs',
  'onb_allergy_peanuts': 'Peanuts',
  'onb_allergy_nuts': 'Tree nuts',
  'onb_allergy_soy': 'Soy',
  'onb_allergy_fish': 'Fish',
  'onb_allergy_crustaceans': 'Crustaceans',
  'onb_allergy_molluscs': 'Molluscs',
  'onb_allergy_celery': 'Celery',
  'onb_allergy_mustard': 'Mustard',
  'onb_allergy_sesame': 'Sesame',
  'onb_allergy_sulfites': 'Sulphites',
  'onb_allergy_lupin': 'Lupin',
  'onb_allergy_fructose': 'Fructose',
  'onb_allergy_histamine': 'Histamine',
  'onb_allergy_nightshades': 'Nightshades',
  'onb_allergy_corn': 'Corn',
  'onb_allergy_yeast': 'Yeast',

  // Dein Ziel (§3.10)
  'onb_target_title': 'Your goal',
  'onb_target_sentence':
      'From a few details we estimate your daily goal. You can change it at any time.',
  'onb_target_goal_heading': 'Goal',
  'onb_target_minor': 'We don’t calculate a weight-loss goal for under-18s.',
  'onb_target_about_heading': 'About you',
  'onb_target_gender': 'Gender',
  'onb_target_gender_choose': 'Choose',
  'onb_target_age': 'Age',
  'onb_target_height': 'Height',
  'onb_target_weight': 'Weight',
  'onb_target_target_weight': 'Target weight',
  'onb_target_weeks': 'Time frame',
  'onb_target_weeks_unit': 'weeks',
  'onb_target_kcal': 'Calories per day',
  'onb_target_activity_heading': 'Activity',
  'onb_target_footnote':
      'Estimate based on the Mifflin-St Jeor formula, not medical advice.',
  'onb_target_age_range': 'Enter an age between 13 and 110.',
  'onb_target_height_range': 'Enter a height between 100 and 250 cm.',
  'onb_target_height_converted': 'Taken as {cm} cm.',
  'onb_target_weight_range': 'Enter a weight between 30 and 300 kg.',
  'onb_target_kcal_range': 'Enter a value between 800 and 6,000 kcal.',
  'onb_target_above': 'The target weight is above your weight.',
  'onb_target_below': 'The target weight is below your weight.',
  'onb_target_result': 'About {kcal} kcal a day',
  'onb_target_result_floor': 'About {kcal} kcal a day, we don’t suggest less.',
  'onb_target_result_macros':
      '{protein} g protein · {carbs} g carbs · {fat} g fat',
  'onb_target_result_empty':
      'Enter height, weight and age to see your daily goal.',
  'onb_target_result_custom': '{kcal} kcal a day',
  'onb_target_result_custom_empty':
      'Enter how many calories you want to eat a day.',

  // Erste Liste (§3.11)
  'onb_list_title': 'Your first list',
  'onb_list_sentence_offers':
      'Name it after a store and we sort it by its aisles and show you its offers.',
  'onb_list_sentence': 'Name it after a store and we sort it by its aisles.',
  'onb_list_placeholder': 'For example Weekly shop',
  'onb_list_default_name': 'Weekly shop',
  'onb_list_drugstore': 'Drugstore',
  'onb_list_suggestions': 'Suggestions',
  'onb_list_create': 'Create list',
  'onb_list_failed': 'The list isn’t created yet.',

  // Beitreten (§5.1)
  'onb_join_title': 'Join the list?',
  'onb_join_sentence': 'You’ve been invited to a shared list.',
  'onb_join_action': 'Join',
  'onb_join_decline': 'Don’t join',
  'onb_join_failed': 'Joining didn’t work.',
  'onb_join_gone_title': 'This invitation is no longer valid.',
  'onb_join_gone_message': 'Ask for a new link.',
  'onb_join_own_list': 'Create my own list',

  // Nach der Anmeldung (§3.5)
  'onb_check_title': 'Almost done',
  'onb_check_sentence': 'We’re checking whether your account is set up.',
  'onb_check_failed': 'Your choices aren’t saved yet.',
  'onb_check_working': 'Checking',
};

const Map<String, String> onboardingFlowDe = {
  // Rahmen
  'onb_progress': 'Schritt {step} von {total}',
  'onb_sync_failed': 'Deine Angaben sind noch nicht gespeichert.',

  // Willkommen (§3.2)
  'onb_welcome_title': 'Avo',
  'onb_welcome_sentence': 'Einkaufsliste und Rezepte, die mitdenken.',
  'onb_welcome_start': 'Los geht’s',
  'onb_welcome_have_account': 'Ich habe schon ein Konto',
  'onb_welcome_login': 'Anmelden',
  'onb_welcome_new_account': 'Neues Konto anlegen',
  'onb_welcome_invited': 'Du wurdest zu einer Liste eingeladen.',

  // Module (§3.3, D2)
  'onb_modules_title': 'Was soll Avo für dich tun?',
  'onb_modules_sentence':
      'Liste und Rezepte sind immer dabei. Den Rest kannst du jederzeit im Profil ändern.',
  'onb_modules_later': 'Später entscheiden',
  'onb_modules_ai_note_avo':
      'Das Sortieren nach Kategorien und Avo nutzen KI von Anthropic (Claude). Dafür gehen Artikelnamen und deine Fragen an Anthropic.',
  'onb_modules_ai_note':
      'Das Sortieren nach Kategorien nutzt KI von Anthropic (Claude). Dafür gehen Artikelnamen an Anthropic.',
  'onb_modules_privacy': 'Datenschutz',
  'onb_module_offers_benefit':
      'Zeigt, was von deiner Liste diese Woche im Angebot ist.',
  'onb_module_meal_plan_benefit':
      'Rezepte für die Woche, Zutaten mit einem Tipp auf die Liste.',
  'onb_module_avo_benefit': 'Fragen oder sprechen, Avo erledigt es in der App.',
  'onb_module_calories_benefit':
      'Essen per Foto oder Barcode, mit Apple Health.',
  'onb_module_cost_split_benefit':
      'Einkäufe in der WG oder Familie fair aufteilen.',

  // Region (§3.4)
  'onb_region_title': 'Angebote in deiner Region',
  'onb_region_sentence':
      'Du siehst nur Angebote der Märkte, in denen du einkaufst. Dafür brauchen wir deine Region.',

  // Ernährung und Allergien (§3.9)
  'onb_food_title': 'Ernäh­rung und Allergien',
  'onb_food_sentence':
      'Rezepte passen sich daran an und weisen dich auf Allergene hin.',
  'onb_food_diet_heading': 'Ernäh­rung',
  'onb_food_allergy_heading': 'Allergien und Unverträg­lichkeiten',
  'onb_food_more': 'Weitere anzeigen',
  'onb_food_footnote':
      'Hinweise auf Allergene helfen, ersetzen aber nicht den Blick auf die Zutatenliste.',
  'onb_allergy_gluten': 'Gluten',
  'onb_allergy_milk': 'Milch',
  'onb_allergy_lactose': 'Laktose',
  'onb_allergy_eggs': 'Eier',
  'onb_allergy_peanuts': 'Erdnüsse',
  'onb_allergy_nuts': 'Schalenfrüchte (Nüsse)',
  'onb_allergy_soy': 'Soja',
  'onb_allergy_fish': 'Fisch',
  'onb_allergy_crustaceans': 'Krebstiere',
  'onb_allergy_molluscs': 'Weichtiere',
  'onb_allergy_celery': 'Sellerie',
  'onb_allergy_mustard': 'Senf',
  'onb_allergy_sesame': 'Sesam',
  'onb_allergy_sulfites': 'Sulfite',
  'onb_allergy_lupin': 'Lupinen',
  'onb_allergy_fructose': 'Fruktose',
  'onb_allergy_histamine': 'Histamin',
  'onb_allergy_nightshades': 'Nachtschatten­gewächse',
  'onb_allergy_corn': 'Mais',
  'onb_allergy_yeast': 'Hefe',

  // Dein Ziel (§3.10)
  'onb_target_title': 'Dein Ziel',
  'onb_target_sentence':
      'Aus ein paar Angaben schätzen wir dein Tagesziel. Du kannst es jederzeit ändern.',
  'onb_target_goal_heading': 'Ziel',
  'onb_target_minor': 'Für unter 18-Jährige berechnen wir kein Abnehm-Ziel.',
  'onb_target_about_heading': 'Über dich',
  'onb_target_gender': 'Geschlecht',
  'onb_target_gender_choose': 'Auswählen',
  'onb_target_age': 'Alter',
  'onb_target_height': 'Größe',
  'onb_target_weight': 'Gewicht',
  'onb_target_target_weight': 'Zielgewicht',
  'onb_target_weeks': 'Zeitraum',
  'onb_target_weeks_unit': 'Wochen',
  'onb_target_kcal': 'Kalorien pro Tag',
  'onb_target_activity_heading': 'Aktivität',
  'onb_target_footnote':
      'Schätzung nach der Mifflin-St-Jeor-Formel, kein medizinischer Rat.',
  'onb_target_age_range': 'Gib ein Alter zwischen 13 und 110 ein.',
  'onb_target_height_range': 'Gib eine Größe zwischen 100 und 250 cm ein.',
  'onb_target_height_converted': 'Als {cm} cm übernommen.',
  'onb_target_weight_range': 'Gib ein Gewicht zwischen 30 und 300 kg ein.',
  'onb_target_kcal_range': 'Gib einen Wert zwischen 800 und 6.000 kcal ein.',
  'onb_target_above': 'Das Zielgewicht liegt über deinem Gewicht.',
  'onb_target_below': 'Das Zielgewicht liegt unter deinem Gewicht.',
  'onb_target_result': 'Etwa {kcal} kcal am Tag',
  'onb_target_result_floor':
      'Etwa {kcal} kcal am Tag, niedriger empfehlen wir nicht.',
  'onb_target_result_macros':
      '{protein} g Protein · {carbs} g Kohlenhydrate · {fat} g Fett',
  'onb_target_result_empty':
      'Gib Größe, Gewicht und Alter ein, dann siehst du dein Tagesziel.',
  'onb_target_result_custom': '{kcal} kcal am Tag',
  'onb_target_result_custom_empty':
      'Gib ein, wie viele Kalorien du am Tag essen willst.',

  // Erste Liste (§3.11)
  'onb_list_title': 'Deine erste Liste',
  'onb_list_sentence_offers':
      'Heißt sie wie ein Markt, sortieren wir sie nach dessen Gängen und zeigen dir dort die Angebote.',
  'onb_list_sentence':
      'Heißt sie wie ein Markt, sortieren wir sie nach dessen Gängen.',
  'onb_list_placeholder': 'Zum Beispiel Wocheneinkauf',
  'onb_list_default_name': 'Wocheneinkauf',
  'onb_list_drugstore': 'Drogerie',
  'onb_list_suggestions': 'Vorschläge',
  'onb_list_create': 'Liste anlegen',
  'onb_list_failed': 'Die Liste ist noch nicht angelegt.',

  // Beitreten (§5.1)
  'onb_join_title': 'Liste beitreten?',
  'onb_join_sentence': 'Du wurdest zu einer geteilten Liste eingeladen.',
  'onb_join_action': 'Beitreten',
  'onb_join_decline': 'Nicht beitreten',
  'onb_join_failed': 'Beitreten hat nicht geklappt.',
  'onb_join_gone_title': 'Diese Einladung gilt nicht mehr.',
  'onb_join_gone_message': 'Frag nach einem neuen Link.',
  'onb_join_own_list': 'Eigene Liste anlegen',

  // Nach der Anmeldung (§3.5)
  'onb_check_title': 'Fast geschafft',
  'onb_check_sentence': 'Wir prüfen, ob dein Konto schon eingerichtet ist.',
  'onb_check_failed': 'Deine Auswahl ist noch nicht gespeichert.',
  'onb_check_working': 'Wird geprüft',
};
