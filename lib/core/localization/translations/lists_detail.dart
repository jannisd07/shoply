// Texte des Bereichs "lists" (Teil A), Teil "die Liste (Hauptscreen, Hinzufügen, Menü)", Deutsch und Englisch.
// Eigene Datei während A5, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A5 in lists.dart zusammengeführt. Präfix: list_.

const Map<String, String> listsDetailEn = {
  // Toolbar, header
  'list_detail_share': 'Share list',
  'list_detail_shop': 'Start shopping mode',
  'list_detail_progress': 'Progress',
  // Rows
  'list_detail_rows_count': '{count} items',
  'list_detail_delete_item': 'Delete',
  'list_detail_diet_warning': 'Doesn’t fit your diet',
  'list_detail_checked': 'Checked off: {name}',
  'list_detail_deleted': '{name} deleted',
  'list_detail_action_failed': 'That didn’t work. Please try again.',
  'list_detail_unit_pcs': 'pcs',
  'list_detail_unit_kg': 'kg',
  'list_detail_unit_g': 'g',
  'list_detail_unit_l': 'L',
  'list_detail_unit_ml': 'ml',
  'list_detail_unit_dozen': 'dozen',
  'list_detail_unit_pack': 'pack',
  'list_detail_unit_bottle': 'btl.',
  'list_detail_unit_can': 'can',
  'list_detail_unit_box': 'box',
  'list_detail_unit_bunch': 'bunch',
  // Done section
  'list_detail_done': 'Done',
  'list_detail_done_summary': '{count} done: {names}',
  // States
  'list_detail_empty_title': 'Nothing on the list yet.',
  'list_detail_empty_message':
      'Type what you need below, for example “2 milk”.',
  'list_detail_all_done_title': 'All done. Nice.',
  'list_detail_all_done_message': '{count} items are checked off.',
  'list_detail_all_done_message_one': '1 item is checked off.',
  'list_detail_load_error': 'The list can’t be loaded right now.',
  // Add field
  'list_detail_add_placeholder': 'Add item',
  'list_detail_add_hint': 'For example 2 milk, or several with commas',
  'list_detail_added_many': '{count} items added',
  'list_detail_add_failed': 'Couldn’t add that. Please try again.',
  // "More" menu
  'list_detail_menu_shop': 'Go shopping',
  'list_detail_menu_checkout': 'Finish shopping',
  'list_detail_menu_info': 'List info',
  'list_detail_menu_rename': 'Rename',
  'list_detail_menu_order': 'Store order',
  'list_detail_menu_hide_offers': 'Hide offers for this list',
  'list_detail_menu_show_offers': 'Show offers for this list',
  'list_detail_menu_import': 'Import a note',
  'list_detail_menu_delete': 'Delete list',
  'list_detail_menu_leave': 'Leave list',
  'list_detail_delete_title': 'Delete “{name}”?',
  'list_detail_delete_message':
      'The list and its items are deleted for everyone on it.',
  'list_detail_delete_confirm': 'Delete',
  'list_detail_leave_title': 'Leave “{name}”?',
  'list_detail_leave_message':
      'You won’t see the list anymore. The others keep it.',
  'list_detail_leave_confirm': 'Leave',
  // A-C4: suggestion panel above the add field
  'list_detail_suggestions': 'Suggestions',
  'list_detail_start_1': 'Milk',
  'list_detail_start_2': 'Bread',
  'list_detail_start_3': 'Eggs',
  'list_detail_start_4': 'Bananas',
  'list_detail_start_5': 'Butter',
  'list_detail_added_one': '{name} added',
  // "Maybe also" (Konzept 11 §1.1 item 9)
  'list_detail_maybe_also': 'Maybe also',
  'list_detail_maybe_also_rhythm': 'You buy it about every {n} days',
  'list_detail_maybe_also_hide': 'Hide',
  // A-L1: offers in the "More" menu
  'list_detail_menu_offers': 'Offers for this list',
};

const Map<String, String> listsDetailDe = {
  // Toolbar, header
  'list_detail_share': 'Liste teilen',
  'list_detail_shop': 'Einkaufsmodus starten',
  'list_detail_progress': 'Fortschritt',
  // Rows
  'list_detail_rows_count': '{count} Artikel',
  'list_detail_delete_item': 'Löschen',
  'list_detail_diet_warning': 'Passt nicht zu deiner Ernährung',
  'list_detail_checked': 'Abgehakt: {name}',
  'list_detail_deleted': '{name} gelöscht',
  'list_detail_action_failed': 'Das hat nicht geklappt. Bitte noch einmal.',
  'list_detail_unit_pcs': 'St.',
  'list_detail_unit_kg': 'kg',
  'list_detail_unit_g': 'g',
  'list_detail_unit_l': 'L',
  'list_detail_unit_ml': 'ml',
  'list_detail_unit_dozen': 'Dutzend',
  'list_detail_unit_pack': 'Pck.',
  'list_detail_unit_bottle': 'Fl.',
  'list_detail_unit_can': 'Dose',
  'list_detail_unit_box': 'Schachtel',
  'list_detail_unit_bunch': 'Bund',
  // Done section
  'list_detail_done': 'Erledigt',
  'list_detail_done_summary': '{count} erledigt: {names}',
  // States
  'list_detail_empty_title': 'Noch nichts auf der Liste.',
  'list_detail_empty_message':
      'Schreib unten, was du brauchst, zum Beispiel „2 Milch“.',
  'list_detail_all_done_title': 'Alles erledigt. Schön.',
  'list_detail_all_done_message': '{count} Artikel sind abgehakt.',
  'list_detail_all_done_message_one': '1 Artikel ist abgehakt.',
  'list_detail_load_error': 'Die Liste lässt sich gerade nicht laden.',
  // Add field
  'list_detail_add_placeholder': 'Artikel hinzufügen',
  'list_detail_add_hint': 'Zum Beispiel 2 Milch, mehrere mit Komma',
  'list_detail_added_many': '{count} Artikel hinzugefügt',
  'list_detail_add_failed':
      'Konnte nicht hinzugefügt werden. Bitte noch einmal.',
  // "Mehr" menu
  'list_detail_menu_shop': 'Einkaufen',
  'list_detail_menu_checkout': 'Einkauf abschließen',
  'list_detail_menu_info': 'Listen-Info',
  'list_detail_menu_rename': 'Umbenennen',
  'list_detail_menu_order': 'Reihenfolge im Markt',
  'list_detail_menu_hide_offers': 'Angebote für diese Liste ausblenden',
  'list_detail_menu_show_offers': 'Angebote für diese Liste zeigen',
  'list_detail_menu_import': 'Zettel importieren',
  'list_detail_menu_delete': 'Liste löschen',
  'list_detail_menu_leave': 'Liste verlassen',
  'list_detail_delete_title': '„{name}“ löschen?',
  'list_detail_delete_message':
      'Die Liste und ihre Artikel werden für alle Mitglieder gelöscht.',
  'list_detail_delete_confirm': 'Löschen',
  'list_detail_leave_title': '„{name}“ verlassen?',
  'list_detail_leave_message':
      'Du siehst die Liste danach nicht mehr. Die anderen behalten sie.',
  'list_detail_leave_confirm': 'Verlassen',
  // A-C4: Vorschlags-Panel über dem Eingabefeld
  'list_detail_suggestions': 'Vorschläge',
  'list_detail_start_1': 'Milch',
  'list_detail_start_2': 'Brot',
  'list_detail_start_3': 'Eier',
  'list_detail_start_4': 'Bananen',
  'list_detail_start_5': 'Butter',
  'list_detail_added_one': '{name} hinzugefügt',
  // "Vielleicht auch" (Konzept 11 §1.1 Punkt 9)
  'list_detail_maybe_also': 'Vielleicht auch',
  'list_detail_maybe_also_rhythm': 'Kaufst du etwa alle {n} Tage',
  'list_detail_maybe_also_hide': 'Ausblenden',
  // A-L1: Angebote im Menü "Mehr"
  'list_detail_menu_offers': 'Angebote dieser Liste',
};
