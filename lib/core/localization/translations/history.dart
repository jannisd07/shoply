// Texte des Bereichs "history" (Teil B), Deutsch und Englisch.
// Entstanden am 07.11.2026 aus app_translations.dart (A1). Pflege: nur Teil B.
// Neue Schlüssel bekommen das Bereichs-Präfix, siehe docs/redesign/arbeitsteilung.md 3.6.

const Map<String, String> historyEn = {
  'your_month_headline': 'Your {month}.',
  'items_bought': 'items bought',
  'shopping_day_line': '{day} is your shopping day.',
  'history_savings_line': "You've saved {amount} thanks to offers.",
  'history_savings_month_line': "That's {amount} this month.",
  'history_savings_month_up_line':
      "That's {amount} this month — up from {prevAmount} last month.",
  'history_savings_month_down_line':
      "That's {amount} this month — down from {prevAmount} last month.",
  'history_savings_month_flat_line':
      "That's {amount} this month, same as last month.",
  'history_trip_savings_line': 'You saved {amount} on this trip.',
  'history_label': 'History',
  'activities_label': 'Activities',
  'split_between': 'Split between',
  'split_equal': 'Split equally',
  'split_custom': 'Custom split',
  'add_person_hint': 'Add person by name',
  'split_sum_check': 'Assigned',
  'save_split': 'Save split',
  'split_save_failed': 'Could not save the split. Try again.',
  'edit_split': 'Edit',
  'paid': 'Paid',
  'unpaid': 'Unpaid',
  'mark_as_paid': 'Mark as paid',
  'copy_reminder': 'Copy reminder',
  'reminder_copied': 'Reminder copied to clipboard',
  'owed_to_me_line': '{name} owes you {amount} € · {list}',
  'i_owe_line': 'You owe {amount} € to {name}',
  'paid_by': 'Paid by',
  'i_paid_back': 'I paid it back',
  'payment_reminder_message':
      'Hi {name}! Quick reminder: you still owe me {amount} € for our shopping trip "{list}". Thanks! 🛒',
  'split_trip_nudge_title': 'Split "{list}" with your group?',
  'split_trip_nudge_subtitle_amount': '≈ {amount} € total — tap to split',
  'split_trip_nudge_subtitle_no_amount': 'Tap to split the cost',
  'no_shopping_history': 'No shopping history',
  'purchased_items': 'Purchased Items',
  'delete_entry': 'Delete Entry',
  'delete_entry_confirm': 'Are you sure you want to delete this entry?',
  // P0.3 checkout route (Teil B)
};

const Map<String, String> historyDe = {
  'your_month_headline': 'Dein {month}.',
  'items_bought': 'Artikel gekauft',
  'shopping_day_line': '{day} ist dein Einkaufstag.',
  'history_savings_line': 'Du hast {amount} durch Angebote gespart.',
  'history_savings_month_line': 'Das sind {amount} in diesem Monat.',
  'history_savings_month_up_line':
      'Das sind {amount} in diesem Monat — mehr als letzten Monat mit {prevAmount}.',
  'history_savings_month_down_line':
      'Das sind {amount} in diesem Monat — weniger als letzten Monat mit {prevAmount}.',
  'history_savings_month_flat_line':
      'Das sind {amount} in diesem Monat, genauso viel wie letzten Monat.',
  'history_trip_savings_line': 'Du hast {amount} bei diesem Einkauf gespart.',
  'history_label': 'Verlauf',
  'activities_label': 'Aktivitäten',
  'split_between': 'Aufteilen zwischen',
  'split_equal': 'Gleich aufteilen',
  'split_custom': 'Individuell',
  'add_person_hint': 'Person per Name hinzufügen',
  'split_sum_check': 'Zugewiesen',
  'save_split': 'Aufteilung speichern',
  'split_save_failed': 'Aufteilung konnte nicht gespeichert werden.',
  'edit_split': 'Bearbeiten',
  'paid': 'Bezahlt',
  'unpaid': 'Offen',
  'mark_as_paid': 'Als bezahlt markieren',
  'copy_reminder': 'Erinnerung kopieren',
  'reminder_copied': 'Erinnerung in Zwischenablage kopiert',
  'owed_to_me_line': '{name} schuldet dir {amount} € · {list}',
  'i_owe_line': 'Du schuldest {name} {amount} €',
  'paid_by': 'Bezahlt von',
  'i_paid_back': 'Zurückgezahlt',
  'payment_reminder_message':
      'Hi {name}! Kleine Erinnerung: du schuldest mir noch {amount} € für unseren Einkauf "{list}". Danke! 🛒',
  'split_trip_nudge_title': '„{list}" mit deiner Gruppe teilen?',
  'split_trip_nudge_subtitle_amount':
      '≈ {amount} € gesamt — antippen zum Teilen',
  'split_trip_nudge_subtitle_no_amount': 'Antippen, um die Kosten zu teilen',
  'no_shopping_history': 'Kein Einkaufsverlauf',
  'purchased_items': 'Gekaufte Artikel',
  'delete_entry': 'Eintrag löschen',
  'delete_entry_confirm': 'Möchtest du diesen Eintrag wirklich löschen?',
  // P0.3 checkout route (Teil B)
};
