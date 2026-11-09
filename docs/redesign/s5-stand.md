# S5 Bereiche fertig – Ergebnis (09.11.2026)

## Ergebnis

- **Diät-Filter prüfen Zutaten** (Owner-Entscheidung 09.11.2026): „Vegan“ und „Vegetarisch“ im Rezepte-Tab, auf den
  Listen-Seiten und auf den Kategorieseiten nutzen `recipeShownDiet` wie das Rezeptdetail (`isShownVegan`,
  `isShownVegetarian` in `recipes_home_data.dart`). Ein Rezept mit Label „vegan“ und Honig zählt als vegetarisch,
  eins mit Label „vegetarisch“ und Hähnchen gar nicht. „Passt zu mir“ verlässt sich nicht mehr auf das Label allein.
  Die Kategorieseite „Vegetarisch“ zeigt weiter nur Rezepte mit diesem Label.
- **`SwipeActions`:** nur eine Zeile ist offen (eine andere wischen schließt die erste), Scrollen der Liste schließt
  die offene Zeile, ein abgebrochenes Ziehen schließt sie auch (wie iOS).
- **`ItemRow(suggestion: true)`** mit `SuggestionCircle` (gestrichelter Ring mit Plus in `uncheckedRing`, Konzept 00
  §12.8): Kreis und Zeile legen den Artikel an, VoiceOver liest einen Knopf, kein Häkchen. „Vielleicht auch“ nutzt
  die Variante statt `ListInfoActionRow`, „Ausblenden“ liegt weiter auf dem Wischen.
- **Galerie:** Abschnitt „Weitere Bausteine“ mit Vorschlagszeile, `SwipeActions`, `SelectCircle`,
  `ReorderableInsetSection`, `TextFieldRow`, `ChipSection`, `PickerRow`/`NumberPicker`/`MenuValueRow`, `AvoSubmenu`
  und Menü mit Vorschau.
- **Abschlussbericht:** [`abschlussbericht-A.md`](abschlussbericht-A.md), prompt §11 Punkt für Punkt.
- Tests: neue Fälle in `recipes_browse_data_test.dart`, `swipe_actions_test.dart`, `item_row_test.dart` (inkl.
  Prüfmatrix), volle Suite und `dart analyze lib test` (0/0) vor dem Commit.

## Braucht den Owner

- Siehe `abschlussbericht-A.md` „Entscheidungen“: A9, A10, Server-Entwürfe, Deploy von `ai`, Geräte-Abnahme.
- Platte: 14 GB frei. Unter 15 GB keine Worktrees (deshalb Prüfung im Hauptordner), unter 10 GB keine Builds.

## Von Teil B

- Keine neuen Anfragen an A (status-B bis Nr. 18 erledigt). Die Wünsche aus `s6-stand.md` „Von Teil B“ stehen weiter.
- B8 meldet sich vor dem Merge wegen A-V9.

## Offen bei A (→ S5b)

- A-V9 mit B8, Gegenprüfung von B6b, B7, B8 (Matrix, `design_check.sh B`, Sheets/Slider, Simulator nach Absprache).
- Reste aus `abschlussbericht-A.md` „Offen bei A“.

## Bewusst abgewichen

- Kein Simulator-Rundgang: die Änderungen sind mit Widget-Tests und Prüfmatrix belegt; der gestrichelte Kreis und
  die Galerie gehören in den nächsten Rundgang.
- Prüfung im Hauptordner statt in einem Worktree (Platte unter 15 GB).
