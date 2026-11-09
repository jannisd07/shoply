// Texte des Bereichs "settings" (Teil A), Teil "Seiten" (Module, Ernährung, Persönliches, Listen, Mitteilungen, Darstellung, Sprache, Hilfe, Rechtliches), Deutsch und Englisch.
// Eigene Datei während A8, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A8 zusammengeführt. Präfix: setp_. Neue Texte sagen "Avo", nie "Shoply".

const Map<String, String> settingsPagesEn = {
  // Shared
  'setp_not_set': 'Not set',
  'setp_open_ios_settings': 'Open iOS Settings',
  'setp_picker_range': 'Between {min} and {max}.',
  'setp_picker_time_invalid': 'Enter a time like 9:00.',
  'setp_picker_hours': 'Hours',
  'setp_picker_minutes': 'Minutes',

  // In-app browser
  'setp_browser_open_safari': 'Open in Safari',
  'setp_browser_loading': 'Loading page',
  'setp_browser_offline_title': 'Needs a connection.',
  'setp_browser_offline_body': 'The page loads once you\'re online.',
  'setp_browser_empty_title': 'This page can\'t be shown here.',
  'setp_browser_empty_body': 'Safari shows it in full.',

  // Modules
  'setp_modules_title': 'Modules',
  'setp_modules_intro':
      'Lists and recipes are always there. Turn everything else on or off here. Your data stays.',
  'setp_modules_tabs': 'Your tabs: {tabs}.',
  'setp_modules_off_toast': '{module} turned off',
  'setp_modules_off_offers': 'Stores and aisle order stay.',
  'setp_modules_off_calories': 'Apple Health is paused. Your entries stay.',
  'setp_modules_off_avo': 'The Avo tab is hidden. Your chats stay.',

  // Diet & allergies
  'setp_diet_title': 'Diet & allergies',
  'setp_diet_intro': 'Recipes adapt to this and point out allergens.',
  'setp_diet_allergies': 'Allergies and intolerances',
  'setp_diet_allergies_footer':
      'Allergen hints help, but they don\'t replace a look at the ingredients.',
  'setp_diet_diet': 'Diet',
  'setp_diet_diet_footer': 'Nothing chosen means no restriction.',
  'setp_diet_auto': 'Adapt recipes automatically',
  'setp_diet_auto_sub': 'Swaps ingredients that don\'t fit and shows why.',
  'setp_diet_removed': '{name} removed',

  // Personal details
  'setp_personal_title': 'Personal details',
  'setp_personal_age': 'Age',
  'setp_personal_age_value': '{n} years',
  'setp_personal_years': 'years',
  'setp_personal_height': 'Height',
  'setp_personal_cm': '{n} cm',
  'setp_personal_ft_in': '{ft} ft {in} in',
  'setp_personal_ft_in_short': 'ft, in',
  'setp_personal_unit': 'Unit',
  'setp_personal_feet': 'Feet',
  'setp_personal_inches': 'Inches',
  'setp_personal_gender': 'Gender',
  'setp_gender_female': 'Female',
  'setp_gender_male': 'Male',
  'setp_gender_other': 'Diverse',
  'setp_gender_prefer_not_to_say': 'Not specified',
  'setp_personal_footer_on':
      'Avo works out your daily needs from this. The details stay in your account.',
  'setp_personal_footer_off':
      'Only used for calorie goals. Calories & health is turned off.',

  // Lists
  'setp_lists_title': 'Lists',
  'setp_lists_display': 'Display',
  'setp_lists_images': 'Show item pictures',
  'setp_lists_images_sub':
      'Symbols and product photos next to the name. Turns off by itself at very large text sizes.',
  'setp_lists_images_ax':
      'Hidden at your text size. Applies again at smaller sizes.',
  'setp_lists_suggestions': 'Maybe also',
  'setp_lists_suggestions_sub':
      'Suggestions for what you\'ll need again soon, at the end of the list',
  'setp_lists_on_open': 'When opening',
  'setp_lists_start': 'List at start',
  'setp_lists_start_last': 'Last used list',
  'setp_lists_shopping': 'Shopping mode',
  'setp_lists_screen_on': 'Keep screen on',
  'setp_lists_screen_on_sub': 'Only while you shop',
  'setp_lists_presence': 'Show others that I\'m shopping',
  'setp_lists_presence_sub':
      'Members of shared lists see when you\'re shopping.',
  'setp_lists_presence_sub_named':
      'Members of shared lists see “{name} is shopping”.',
  'setp_lists_categories': 'Categories',
  'setp_lists_order': 'Order in the store',
  'setp_lists_order_sub': 'Per list, in the list info',
  'setp_lists_order_none': 'Per list, once you have a list',

  // Notifications
  'setp_notif_title': 'Notifications',
  'setp_notif_allow': 'Allow notifications',
  'setp_notif_allow_sub':
      'Find out when someone adds something or goes shopping.',
  'setp_notif_denied':
      'Notifications are off in iOS. Your choice here applies once you allow them.',
  'setp_notif_open_settings': 'Allow in Settings',
  'setp_notif_master': 'Notifications from Avo',
  'setp_notif_master_sub': 'For your whole account',
  'setp_notif_shared': 'Shared lists',
  'setp_notif_shopping_started': 'Someone is shopping',
  'setp_notif_list_changes': 'Changes to lists',
  'setp_notif_list_changes_sub': 'Bundled, e.g. “Lena checked off 5 items”',
  'setp_notif_shopping_completed': 'Shopping finished',
  'setp_notif_invitations': 'Invitations and new members',
  'setp_notif_reminders': 'Reminders',
  'setp_notif_restock': 'Restock reminder',
  'setp_notif_time': 'Time',
  'setp_notif_cooking_timer': 'Cooking timer',
  'setp_notif_cooking_timer_sub': 'Time-sensitive, also in Focus',
  'setp_notif_modules': 'Modules',
  'setp_notif_plan_reminder': 'Remind me about next week',
  'setp_notif_dinner_ideas': 'Dinner ideas',
  'setp_notif_cost_split': 'Open amounts',
  'setp_notif_recipes': 'Recipes',
  'setp_notif_recipe_likes': 'Ratings and likes',
  'setp_notif_recipe_comments': 'Comments',
  'setp_notif_new_recipes': 'New recipes from creators you follow',

  // Appearance
  'setp_appearance_title': 'Appearance',
  'setp_appearance_system': 'System',
  'setp_appearance_system_sub': 'Follows your iPhone',
  'setp_appearance_light': 'Light',
  'setp_appearance_dark': 'Dark',
  'setp_appearance_footer':
      'Text size, bold text and contrast are set in iOS Settings. Avo follows them.',

  // Language
  'setp_language_title': 'Language',
  'setp_language_intro':
      'Applies to the app, notifications and Avo. What you write in lists stays as it is.',
  'setp_language_system': 'System',
  'setp_language_system_sub': '{language}, like your iPhone',
  'setp_language_footer':
      'You can also set the language per app in iOS Settings.',

  // Help
  'setp_help_title': 'Help',
  'setp_help_faq': 'Frequently asked questions',
  'setp_help_q_share': 'How do I share a list?',
  'setp_help_a_share':
      'Open the list, tap Share and invite people by link or code. Everyone sees changes right away.',
  'setp_help_q_shopping': 'How does shopping mode work?',
  'setp_help_a_shopping':
      'In the store, tap Shop on the list. Items are sorted by aisle, checked items move down and the screen stays on.',
  'setp_help_q_category': 'How is the category chosen?',
  'setp_help_a_category':
      'Avo picks it from the name at once and learns from your changes. You can change it in the item at any time.',
  'setp_help_q_offers': 'Where do the offers come from?',
  'setp_help_a_offers':
      'From the flyers of the stores near you. Prices are as stated by the store and can be out of date.',
  'setp_help_q_pro': 'How do I cancel Avo Pro?',
  'setp_help_a_pro':
      'In iOS Settings under your name, Subscriptions. Avo Pro stays active until the end of the period.',
  'setp_help_link_pro': 'Profile › Avo Pro',
  'setp_help_q_delete': 'How do I delete my account?',
  'setp_help_a_delete':
      'Under Profile › Account › Delete account. You see beforehand what gets deleted.',
  'setp_help_link_account': 'Profile › Account',
  'setp_help_contact': 'Contact',
  'setp_help_mail': 'Email support',
  'setp_help_mail_subject': 'Avo support',
  'setp_help_mail_copied': 'Address copied',
  'setp_help_bug': 'Report a bug',
  'setp_help_bug_sub': 'Version and iOS go into the mail, you see them',
  'setp_help_bug_subject': 'Avo: bug report',
  'setp_help_bug_body': 'What happened?',
  'setp_help_rate': 'Rate Avo',
  'setp_help_tips': 'Tips',
  'setp_help_tips_reset': 'Reset tips',
  'setp_help_tips_reset_sub': 'Shows the short explanations in the app again.',
  'setp_help_tips_done': 'Tips reset',
  'setp_help_guide': 'Guide',
  'setp_help_version': 'Avo · Version {version}',

  // Legal
  'setp_legal_title': 'Legal',
  'setp_legal_privacy': 'Privacy',
  'setp_legal_imprint': 'Imprint',
  'setp_legal_terms': 'Terms of use',
  'setp_legal_sources': 'Data sources',
  'setp_legal_licenses': 'Licences',
  'setp_licenses_footer': '{n} open-source packages',
  'setp_licenses_error': 'The licences can\'t be read right now.',
  'setp_sources_title': 'Data sources',
  'setp_sources_products_title': 'Product photos and nutrition',
  'setp_sources_products_body':
      'Open Food Facts, data under the Open Database License (ODbL), photos under CC BY-SA.',
  'setp_sources_prices_title': 'Prices',
  'setp_sources_prices_body':
      'Open Prices by Open Food Facts, under the Open Database License (ODbL). Community data, can be out of date.',
  'setp_sources_stores_title': 'Stores and locations',
  'setp_sources_stores_body':
      '© OpenStreetMap contributors, under the Open Database License (ODbL).',
  'setp_sources_offers_title': 'Offers',
  'setp_sources_offers_body':
      'marktguru. Prices as stated by the store, can be out of date.',

  // Search words (comma-separated)
  'setp_kw_modules': 'modules, tabs, hide, turn on, turn off, features',
  'setp_kw_modules_offers': 'offers, flyer, deals, discounts, prices',
  'setp_kw_modules_avo': 'assistant, AI, chat, voice',
  'setp_kw_modules_calories': 'calories, health, Apple Health, food diary',
  'setp_kw_modules_cost_split': 'split, costs, money, share costs',
  'setp_kw_diet': 'diet, food, eat, nutrition',
  'setp_kw_diet_allergies':
      'allergy, allergies, intolerance, nut, peanut, gluten, lactose, milk, egg, soy',
  'setp_kw_diet_diet':
      'vegan, vegetarian, pescatarian, keto, low carb, halal, kosher',
  'setp_kw_diet_auto': 'adapt, swap, substitute, replace',
  'setp_kw_personal': 'personal, data, body',
  'setp_kw_personal_age': 'age, years, birthday',
  'setp_kw_personal_height': 'height, cm, feet, size',
  'setp_kw_personal_gender': 'gender, sex',
  'setp_kw_lists': 'lists, shopping list',
  'setp_kw_lists_images': 'pictures, photos, images, symbols',
  'setp_kw_lists_suggestions': 'suggestions, maybe also, recommendations',
  'setp_kw_lists_start': 'start, open, launch, pin, default list',
  'setp_kw_lists_screen_on': 'screen on, display, lock, sleep',
  'setp_kw_lists_presence': 'presence, shopping now, privacy, others see',
  'setp_kw_lists_order': 'order, aisle, categories, store, sort',
  'setp_kw_notif': 'notifications, push, alerts, reminders',
  'setp_kw_notif_master': 'notifications off, push, mute',
  'setp_kw_notif_shopping_started': 'shopping, someone shopping',
  'setp_kw_notif_list_changes': 'changes, added, checked off',
  'setp_kw_notif_invitations': 'invitation, invite, members',
  'setp_kw_notif_restock': 'restock, reminder, time, buy again',
  'setp_kw_notif_cooking_timer': 'timer, cooking, alarm',
  'setp_kw_notif_recipes': 'recipes, likes, comments, follow',
  'setp_kw_notif_plan_reminder': 'meal plan, week, Sunday, plan',
  'setp_kw_notif_dinner_ideas': 'dinner, evening, calories, ideas',
  'setp_kw_notif_cost_split': 'amounts, owe, split costs, money',
  'setp_kw_help_offers': 'offers, flyer, deals, prices',
  'setp_kw_appearance': 'appearance, theme, colours, design',
  'setp_kw_appearance_dark': 'dark, dark mode, night mode, black',
  'setp_kw_appearance_light': 'light, bright, white',
  'setp_kw_language': 'language, English, German, Deutsch',
  'setp_kw_help': 'help, support, questions, FAQ',
  'setp_kw_help_share': 'share, invite, together',
  'setp_kw_help_shopping': 'shopping mode, store, aisle',
  'setp_kw_help_category': 'category, sorting',
  'setp_kw_help_pro': 'cancel, subscription, Pro, abo',
  'setp_kw_help_delete': 'delete account, remove account',
  'setp_kw_help_mail': 'support, contact, email, mail',
  'setp_kw_help_bug': 'bug, error, problem, crash',
  'setp_kw_help_rate': 'rate, review, stars, App Store',
  'setp_kw_help_tips': 'tips, tutorial, reset, introduction',
  'setp_kw_help_guide': 'guide, manual, instructions',
  'setp_kw_legal': 'legal, law',
  'setp_kw_legal_privacy': 'privacy, data protection, GDPR',
  'setp_kw_legal_imprint': 'imprint, publisher, contact',
  'setp_kw_legal_terms': 'terms, conditions, agreement',
  'setp_kw_legal_sources':
      'sources, Open Food Facts, OpenStreetMap, ODbL, attribution',
  'setp_kw_legal_licenses': 'licences, licenses, open source',
};

const Map<String, String> settingsPagesDe = {
  // Shared
  'setp_not_set': 'Nicht angegeben',
  'setp_open_ios_settings': 'iOS-Einstellungen öffnen',
  'setp_picker_range': 'Zwischen {min} und {max}.',
  'setp_picker_time_invalid': 'Gib eine Uhrzeit wie 9:00 ein.',
  'setp_picker_hours': 'Stunden',
  'setp_picker_minutes': 'Minuten',

  // In-app browser
  'setp_browser_open_safari': 'In Safari öffnen',
  'setp_browser_loading': 'Seite wird geladen',
  'setp_browser_offline_title': 'Braucht eine Verbindung.',
  'setp_browser_offline_body': 'Die Seite lädt, sobald du online bist.',
  'setp_browser_empty_title': 'Diese Seite lässt sich hier nicht zeigen.',
  'setp_browser_empty_body': 'In Safari siehst du sie ganz.',

  // Module
  'setp_modules_title': 'Module',
  'setp_modules_intro':
      'Liste und Rezepte sind immer dabei. Alles andere schaltest du hier ein oder aus. Deine Daten bleiben erhalten.',
  'setp_modules_tabs': 'Deine Tabs: {tabs}.',
  'setp_modules_off_toast': '{module} ausgeschaltet',
  'setp_modules_off_offers': 'Märkte und Gang-Reihenfolge bleiben.',
  'setp_modules_off_calories': 'Apple Health pausiert. Deine Einträge bleiben.',
  'setp_modules_off_avo':
      'Der Tab Avo ist ausgeblendet. Deine Gespräche bleiben.',

  // Ernährung & Allergien
  'setp_diet_title': 'Ernährung & Allergien',
  'setp_diet_intro':
      'Rezepte passen sich daran an und weisen dich auf Allergene hin.',
  'setp_diet_allergies': 'Allergien und Unverträglichkeiten',
  'setp_diet_allergies_footer':
      'Hinweise auf Allergene helfen, ersetzen aber nicht den Blick auf die Zutatenliste.',
  'setp_diet_diet': 'Ernährung',
  'setp_diet_diet_footer': 'Nichts gewählt heißt: keine Einschränkung.',
  'setp_diet_auto': 'Rezepte automatisch anpassen',
  'setp_diet_auto_sub':
      'Ersetzt Zutaten, die nicht passen, und zeigt den Grund.',
  'setp_diet_removed': '{name} entfernt',

  // Persönliche Daten
  'setp_personal_title': 'Persönliche Daten',
  'setp_personal_age': 'Alter',
  'setp_personal_age_value': '{n} Jahre',
  'setp_personal_years': 'Jahre',
  'setp_personal_height': 'Größe',
  'setp_personal_cm': '{n} cm',
  'setp_personal_ft_in': '{ft} ft {in} in',
  'setp_personal_ft_in_short': 'ft, in',
  'setp_personal_unit': 'Einheit',
  'setp_personal_feet': 'Fuß',
  'setp_personal_inches': 'Zoll',
  'setp_personal_gender': 'Geschlecht',
  'setp_gender_female': 'Weiblich',
  'setp_gender_male': 'Männlich',
  'setp_gender_other': 'Divers',
  'setp_gender_prefer_not_to_say': 'Keine Angabe',
  'setp_personal_footer_on':
      'Daraus berechnet Avo deinen Tagesbedarf. Die Angaben bleiben in deinem Konto.',
  'setp_personal_footer_off':
      'Wird nur für Kalorienziele genutzt. Kalorien & Gesundheit ist ausgeschaltet.',

  // Listen
  'setp_lists_title': 'Listen',
  'setp_lists_display': 'Anzeige',
  'setp_lists_images': 'Artikelbilder anzeigen',
  'setp_lists_images_sub':
      'Symbole und Produktfotos neben dem Namen. Bei sehr großer Schrift automatisch aus.',
  'setp_lists_images_ax':
      'Bei deiner Schriftgröße ausgeblendet. Gilt wieder bei kleinerer Schrift.',
  'setp_lists_suggestions': 'Vielleicht auch',
  'setp_lists_suggestions_sub':
      'Vorschläge, was du bald wieder brauchst, am Ende der Liste',
  'setp_lists_on_open': 'Beim Öffnen',
  'setp_lists_start': 'Liste beim Start',
  'setp_lists_start_last': 'Zuletzt benutzte Liste',
  'setp_lists_shopping': 'Einkaufsmodus',
  'setp_lists_screen_on': 'Bildschirm anlassen',
  'setp_lists_screen_on_sub': 'Nur solange du einkaufst',
  'setp_lists_presence': 'Anderen zeigen, dass ich einkaufe',
  'setp_lists_presence_sub':
      'Mitglieder geteilter Listen sehen, wenn du gerade einkaufst.',
  'setp_lists_presence_sub_named':
      'Mitglieder geteilter Listen sehen „{name} kauft gerade ein“.',
  'setp_lists_categories': 'Kategorien',
  'setp_lists_order': 'Reihenfolge im Markt',
  'setp_lists_order_sub': 'Pro Liste in der Listen-Info',
  'setp_lists_order_none': 'Pro Liste, sobald du eine Liste hast',

  // Mitteilungen
  'setp_notif_title': 'Mitteilungen',
  'setp_notif_allow': 'Mitteilungen erlauben',
  'setp_notif_allow_sub': 'Erfahre, wenn jemand etwas hinzufügt oder einkauft.',
  'setp_notif_denied':
      'Mitteilungen sind in iOS ausgeschaltet. Deine Auswahl hier gilt, sobald du sie erlaubst.',
  'setp_notif_open_settings': 'In Einstellungen erlauben',
  'setp_notif_master': 'Mitteilungen von Avo',
  'setp_notif_master_sub': 'Für dein ganzes Konto',
  'setp_notif_shared': 'Geteilte Listen',
  'setp_notif_shopping_started': 'Jemand kauft ein',
  'setp_notif_list_changes': 'Änderungen an Listen',
  'setp_notif_list_changes_sub':
      'Gebündelt, z. B. „Lena hat 5 Artikel abgehakt“',
  'setp_notif_shopping_completed': 'Einkauf abgeschlossen',
  'setp_notif_invitations': 'Einladungen und neue Mitglieder',
  'setp_notif_reminders': 'Erinnerungen',
  'setp_notif_restock': 'Nachkauf-Erinnerung',
  'setp_notif_time': 'Uhrzeit',
  'setp_notif_cooking_timer': 'Kochtimer',
  'setp_notif_cooking_timer_sub': 'Zeitkritisch, auch im Fokus-Modus',
  'setp_notif_modules': 'Module',
  'setp_notif_plan_reminder': 'An die nächste Woche erinnern',
  'setp_notif_dinner_ideas': 'Ideen fürs Abendessen',
  'setp_notif_cost_split': 'Offene Beträge',
  'setp_notif_recipes': 'Rezepte',
  'setp_notif_recipe_likes': 'Bewertungen und Likes',
  'setp_notif_recipe_comments': 'Kommentare',
  'setp_notif_new_recipes': 'Neue Rezepte von Erstellern, denen du folgst',

  // Darstellung
  'setp_appearance_title': 'Darstellung',
  'setp_appearance_system': 'System',
  'setp_appearance_system_sub': 'Folgt dem iPhone',
  'setp_appearance_light': 'Hell',
  'setp_appearance_dark': 'Dunkel',
  'setp_appearance_footer':
      'Textgröße, fetter Text und Kontrast stellst du in den iOS-Einstellungen ein. Avo folgt ihnen.',

  // Sprache
  'setp_language_title': 'Sprache',
  'setp_language_intro':
      'Gilt für die App, Mitteilungen und Avo. Was du in Listen schreibst, bleibt, wie es ist.',
  'setp_language_system': 'System',
  'setp_language_system_sub': '{language}, wie dein iPhone',
  'setp_language_footer':
      'Du kannst die Sprache auch in den iOS-Einstellungen pro App festlegen.',

  // Hilfe
  'setp_help_title': 'Hilfe',
  'setp_help_faq': 'Häufige Fragen',
  'setp_help_q_share': 'Wie teile ich eine Liste?',
  'setp_help_a_share':
      'Öffne die Liste, tippe auf Teilen und lade Leute per Link oder Code ein. Alle sehen Änderungen sofort.',
  'setp_help_q_shopping': 'Wie funktioniert der Einkaufsmodus?',
  'setp_help_a_shopping':
      'Tippe im Markt in der Liste auf Einkaufen. Die Artikel stehen nach Gängen, Abgehaktes rutscht nach unten und der Bildschirm bleibt an.',
  'setp_help_q_category': 'Wie kommt die Kategorie zustande?',
  'setp_help_a_category':
      'Avo erkennt sie sofort am Namen und lernt aus deinen Änderungen. Du kannst sie im Artikel jederzeit ändern.',
  'setp_help_q_offers': 'Woher kommen die Angebote?',
  'setp_help_a_offers':
      'Aus den Prospekten der Märkte in deiner Nähe. Preise laut Händler, sie können veraltet sein.',
  'setp_help_q_pro': 'Wie kündige ich Avo Pro?',
  'setp_help_a_pro':
      'In den iOS-Einstellungen unter deinem Namen, Abonnements. Avo Pro bleibt bis zum Ende des Zeitraums aktiv.',
  'setp_help_link_pro': 'Profil › Avo Pro',
  'setp_help_q_delete': 'Wie lösche ich mein Konto?',
  'setp_help_a_delete':
      'Unter Profil › Konto › Konto löschen. Vorher siehst du, was gelöscht wird.',
  'setp_help_link_account': 'Profil › Konto',
  'setp_help_contact': 'Kontakt',
  'setp_help_mail': 'E-Mail an den Support',
  'setp_help_mail_subject': 'Avo Support',
  'setp_help_mail_copied': 'Adresse kopiert',
  'setp_help_bug': 'Fehler melden',
  'setp_help_bug_sub': 'Version und iOS stehen sichtbar in der Mail',
  'setp_help_bug_subject': 'Avo: Fehler melden',
  'setp_help_bug_body': 'Was ist passiert?',
  'setp_help_rate': 'Avo bewerten',
  'setp_help_tips': 'Tipps',
  'setp_help_tips_reset': 'Tipps zurücksetzen',
  'setp_help_tips_reset_sub':
      'Zeigt die kurzen Erklärungen in der App noch einmal.',
  'setp_help_tips_done': 'Tipps zurückgesetzt',
  'setp_help_guide': 'Anleitung',
  'setp_help_version': 'Avo · Version {version}',

  // Rechtliches
  'setp_legal_title': 'Rechtliches',
  'setp_legal_privacy': 'Datenschutz',
  'setp_legal_imprint': 'Impressum',
  'setp_legal_terms': 'Nutzungsbedingungen',
  'setp_legal_sources': 'Datenquellen',
  'setp_legal_licenses': 'Lizenzen',
  'setp_licenses_footer': '{n} Open-Source-Pakete',
  'setp_licenses_error': 'Die Lizenzen lassen sich gerade nicht lesen.',
  'setp_sources_title': 'Datenquellen',
  'setp_sources_products_title': 'Produktfotos und Nährwerte',
  'setp_sources_products_body':
      'Open Food Facts, Daten unter der Open Database License (ODbL), Fotos unter CC BY-SA.',
  'setp_sources_prices_title': 'Preise',
  'setp_sources_prices_body':
      'Open Prices von Open Food Facts, unter der Open Database License (ODbL). Gemeinschaftsdaten, können veraltet sein.',
  'setp_sources_stores_title': 'Märkte und Standorte',
  'setp_sources_stores_body':
      '© OpenStreetMap-Mitwirkende, unter der Open Database License (ODbL).',
  'setp_sources_offers_title': 'Angebote',
  'setp_sources_offers_body':
      'marktguru. Preise laut Händler, können veraltet sein.',

  // Suchwörter (durch Komma getrennt)
  'setp_kw_modules':
      'Module, Tab, Tabs, ausblenden, einschalten, ausschalten, Funktionen',
  'setp_kw_modules_offers':
      'Angebot, Angebote, Prospekt, Sparen, Rabatt, Preise',
  'setp_kw_modules_avo': 'Assistent, KI, Chat, Stimme',
  'setp_kw_modules_calories': 'Kalorien, Gesundheit, Apple Health, Tagebuch',
  'setp_kw_modules_cost_split': 'Kosten, teilen, Geld, aufteilen',
  'setp_kw_diet': 'Ernährung, Essen, Diät',
  'setp_kw_diet_allergies':
      'Allergie, Allergien, Unverträglichkeit, Nuss, Nüsse, Erdnuss, Gluten, Laktose, Milch, Ei, Soja',
  'setp_kw_diet_diet':
      'vegan, vegetarisch, pescetarisch, Keto, Low-Carb, halal, koscher',
  'setp_kw_diet_auto': 'anpassen, ersetzen, Ersatz, austauschen',
  'setp_kw_personal': 'persönlich, Daten, Körper',
  'setp_kw_personal_age': 'Alter, Jahre, Geburtstag',
  'setp_kw_personal_height': 'Größe, cm, Fuß, Körpergröße',
  'setp_kw_personal_gender': 'Geschlecht',
  'setp_kw_lists': 'Listen, Einkaufsliste',
  'setp_kw_lists_images': 'Bilder, Fotos, Artikelbilder, Symbole',
  'setp_kw_lists_suggestions': 'Vorschläge, Vielleicht auch, Empfehlungen',
  'setp_kw_lists_start': 'Start, öffnen, Startliste, anheften, Standardliste',
  'setp_kw_lists_screen_on': 'Bildschirm an, Display, Sperre, anlassen',
  'setp_kw_lists_presence':
      'Präsenz, einkaufen, gerade einkaufen, Datenschutz, andere sehen',
  'setp_kw_lists_order':
      'Reihenfolge, Gang, Gänge, Kategorien, Markt, sortieren',
  'setp_kw_notif': 'Mitteilungen, Benachrichtigung, Push, Erinnerung',
  'setp_kw_notif_master': 'Mitteilungen aus, Push, stumm',
  'setp_kw_notif_shopping_started': 'einkaufen, kauft ein',
  'setp_kw_notif_list_changes': 'Änderungen, hinzugefügt, abgehakt',
  'setp_kw_notif_invitations': 'Einladung, einladen, Mitglieder',
  'setp_kw_notif_restock': 'Nachkauf, Erinnerung, Uhrzeit, wieder kaufen',
  'setp_kw_notif_cooking_timer': 'Timer, Kochen, Wecker',
  'setp_kw_notif_recipes': 'Rezepte, Likes, Kommentare, folgen',
  'setp_kw_notif_plan_reminder': 'Wochenplan, Woche, Sonntag, Plan',
  'setp_kw_notif_dinner_ideas': 'Abendessen, Abend, Kalorien, Ideen',
  'setp_kw_notif_cost_split': 'Beträge, offen, Kosten teilen, Geld',
  'setp_kw_help_offers': 'Angebote, Prospekt, Sparen, Preise',
  'setp_kw_appearance': 'Darstellung, Design, Farben, Thema',
  'setp_kw_appearance_dark':
      'dunkel, Dunkelmodus, Nachtmodus, Dark Mode, schwarz',
  'setp_kw_appearance_light': 'hell, weiß, Tag',
  'setp_kw_language': 'Sprache, Deutsch, Englisch, English',
  'setp_kw_help': 'Hilfe, Support, Fragen, FAQ',
  'setp_kw_help_share': 'teilen, einladen, gemeinsam',
  'setp_kw_help_shopping': 'Einkaufsmodus, Markt, Gang',
  'setp_kw_help_category': 'Kategorie, sortieren',
  'setp_kw_help_pro': 'kündigen, Abo, Abonnement, Pro',
  'setp_kw_help_delete': 'löschen, Konto löschen, Konto entfernen',
  'setp_kw_help_mail': 'Support, Kontakt, E-Mail, Mail',
  'setp_kw_help_bug': 'Fehler, Bug, Problem, Absturz',
  'setp_kw_help_rate': 'bewerten, Bewertung, Sterne, App Store',
  'setp_kw_help_tips': 'Tipps, Tutorial, zurücksetzen, Einführung',
  'setp_kw_help_guide': 'Anleitung, Handbuch, Erklärung',
  'setp_kw_legal': 'Rechtliches, Recht',
  'setp_kw_legal_privacy': 'Datenschutz, DSGVO, Privatsphäre',
  'setp_kw_legal_imprint': 'Impressum, Anbieter, Kontakt',
  'setp_kw_legal_terms': 'AGB, Nutzungsbedingungen, Bedingungen',
  'setp_kw_legal_sources':
      'Quellen, Datenquellen, Open Food Facts, OpenStreetMap, ODbL',
  'setp_kw_legal_licenses': 'Lizenzen, Open Source',
};
