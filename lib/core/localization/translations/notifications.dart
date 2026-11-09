// Texte des Bereichs "notifications" (Teil B), Deutsch und Englisch.
// Entstanden am 07.11.2026 aus app_translations.dart (A1). Pflege: nur Teil B.
// Neue Schlüssel bekommen das Bereichs-Präfix, siehe docs/redesign/arbeitsteilung.md 3.6.

const Map<String, String> notificationsEn = {
  'notif_pro_trial_ends':
      'Your {pro} trial ends the day after tomorrow. After that it is {price} a year.',
  // B8 trips and splits (verlauf-kosten.md V14); `_one` is the singular.
  'notif_trip_done_one': '{name} shopped at {store} (1 item).',
  'notif_trip_done': '{name} shopped at {store} ({n} items).',
  'notif_trip_done_no_store_one': '{name} went shopping (1 item).',
  'notif_trip_done_no_store': '{name} went shopping ({n} items).',
  'notif_split_paid': '{name} marked your share ({amount}) as paid.',
  'notif_split_reopened': '{name} marked your share ({amount}) as open again.',
  'restock_notification_title': '🥑 Time to restock?',
  'restock_notification_body_one':
      '{item} is probably running low – you buy it about every {days} days.',
  'restock_notification_body_many':
      '{item} and {count} more are probably running low. Avo has the details.',
  'restock_notification_body_offer':
      '{item} is probably running low – and on offer at {store} right now ({price} €).',
  'calorie_nudge_notification_title': '🥑 Dinner idea?',
  'calorie_nudge_notification_body_one':
      'You have about {kcal} kcal left today — Avo found a recipe that fits: {recipe}.',
  'calorie_nudge_notification_body_many':
      'You have about {kcal} kcal left today — Avo found {count} recipes that fit, starting with {recipe}.',
  // Recipe of the Week
  'recipe_of_the_day': 'Recipe of the Day',
  'push_notifications': 'Push Notifications',
  'weekly_high_protein_milestone_message':
      'Nice! You\'ve cooked {count} high-protein meals this week 💪',
};

const Map<String, String> notificationsDe = {
  'notif_pro_trial_ends':
      'Deine {pro}-Testphase endet übermorgen. Danach {price} pro Jahr.',
  // B8 Einkäufe und Aufteilungen (verlauf-kosten.md V14); `_one` ist Einzahl.
  'notif_trip_done_one': '{name} hat bei {store} eingekauft (1 Artikel).',
  'notif_trip_done': '{name} hat bei {store} eingekauft ({n} Artikel).',
  'notif_trip_done_no_store_one': '{name} hat eingekauft (1 Artikel).',
  'notif_trip_done_no_store': '{name} hat eingekauft ({n} Artikel).',
  'notif_split_paid': '{name} hat deinen Anteil ({amount}) als bezahlt markiert.',
  'notif_split_reopened':
      '{name} hat deinen Anteil ({amount}) wieder als offen markiert.',
  'restock_notification_title': '🥑 Zeit nachzukaufen?',
  'restock_notification_body_one':
      '{item} ist wahrscheinlich fast aufgebraucht – du kaufst es etwa alle {days} Tage.',
  'restock_notification_body_many':
      '{item} und {count} weitere sind wahrscheinlich fast aufgebraucht. Avo hat die Details.',
  'restock_notification_body_offer':
      '{item} ist wahrscheinlich fast aufgebraucht – und gerade im Angebot bei {store} ({price} €).',
  'calorie_nudge_notification_title': '🥑 Idee fürs Abendessen?',
  'calorie_nudge_notification_body_one':
      'Du hast heute noch etwa {kcal} kcal übrig – Avo hat ein passendes Rezept gefunden: {recipe}.',
  'calorie_nudge_notification_body_many':
      'Du hast heute noch etwa {kcal} kcal übrig – Avo hat {count} passende Rezepte gefunden, z. B. {recipe}.',
  // Recipe of the Week
  'recipe_of_the_day': 'Rezept des Tages',
  'push_notifications': 'Push-Benachrichtigungen',
  'weekly_high_protein_milestone_message':
      'Stark! Du hast diese Woche {count} proteinreiche Mahlzeiten gekocht 💪',
};
