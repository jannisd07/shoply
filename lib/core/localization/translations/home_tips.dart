// Texte des Bereichs "tips" (Teil A), Teil "Tipps" (Tipp-Zeilen statt Tutorial), Deutsch und Englisch.
// Eigene Datei während A7, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A7 zusammengeführt. Präfix: tip_. Neue Texte sagen "Avo", nie "Shoply".

const Map<String, String> homeTipsEn = {
  // Tip rows T1–T9 (Konzept 17 §6.1)
  'tip_t1': 'Tip: Type “2 milk” and the quantity is set right away.',
  'tip_t2':
      'Tip: In the store, tap Go shopping. Everything gets big and sorted by aisle.',
  'tip_t3': 'Tip: The circle checks an item off, the name opens it.',
  'tip_t4': 'Tip: Share the list to see who is shopping right now.',
  'tip_t5': 'Tip: What others check off shows up right away.',
  'tip_t6':
      'Tip: “Add ingredients to list” in a recipe puts everything you need for it on your list.',
  'tip_t7': 'Tip: Set your diet and allergies, and recipes adapt to you.',
  'tip_t7_action': 'Set up',
  'tip_t8':
      'Tip: You can also talk to Avo. In the Avo tab, tap the waveform on the right of the input field.',
  'tip_t9':
      'Tip: Put recipes on the days. “To list” then puts all their ingredients on your list at once.',
  'tip_hide': 'Hide',
  'tip_section_today': 'For today',

  // Arrival after signing in with an account that was set up (§3.12)
  'tip_arrival_existing': 'Signed in as {name}. Your lists are here.',
  'tip_arrival_existing_anonymous': 'You’re signed in. Your lists are here.',

  // Profile, help
  'tip_reset': 'Reset tips',
  'tip_reset_done': 'Tips will show again.',
};

const Map<String, String> homeTipsDe = {
  // Tipp-Zeilen T1–T9 (Konzept 17 §6.1)
  'tip_t1': 'Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei.',
  'tip_t2':
      'Tipp: Im Markt auf Einkaufen tippen. Dann ist alles groß und nach Gängen sortiert.',
  'tip_t3': 'Tipp: Der Kreis hakt ab, der Name öffnet den Artikel.',
  'tip_t4': 'Tipp: Teil die Liste, dann siehst du, wer gerade einkauft.',
  'tip_t5': 'Tipp: Was andere abhaken, siehst du sofort.',
  'tip_t6':
      'Tipp: „Zutaten auf die Liste“ im Rezept setzt alles, was du dafür brauchst, auf deine Liste.',
  'tip_t7':
      'Tipp: Stell Ernährung und Allergien ein, dann passen sich Rezepte an.',
  'tip_t7_action': 'Einstellen',
  'tip_t8':
      'Tipp: Du kannst auch mit Avo sprechen. Tippe im Avo-Tab auf das Wellen-Symbol rechts im Eingabefeld.',
  'tip_t9':
      'Tipp: Leg Rezepte auf die Tage. „Auf die Liste“ setzt danach alle Zutaten auf einmal auf deine Liste.',
  'tip_hide': 'Ausblenden',
  'tip_section_today': 'Für heute',

  // Ankunft nach der Anmeldung mit einem eingerichteten Konto (§3.12)
  'tip_arrival_existing': 'Angemeldet als {name}. Deine Listen sind da.',
  'tip_arrival_existing_anonymous': 'Du bist angemeldet. Deine Listen sind da.',

  // Profil, Hilfe
  'tip_reset': 'Tipps zurücksetzen',
  'tip_reset_done': 'Die Tipps erscheinen wieder.',
};
