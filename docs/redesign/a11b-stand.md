# A11b Qualität, Teil 2 – Ergebnis (09.11.2026)

Vorgänger: [`a11-stand.md`](a11-stand.md). Commits: `git log --grep A11b`. Screenshots:
[`abnahme/a11b/`](abnahme/a11b/) (Simulator iPhone 17, angemeldet, Sprache Englisch).

## Ergebnis

**Zuerst B's Wünsche** (Commit „A11b: Wuensche von B …“):
- status-B 18: `_offerSummary` im Rezeptdetail liest `recipeOfferSummaryShowsProvider(recipeOfferSummaryKey(…))`,
  die eigenen Zeilen mit `recipeOffersCachedProvider`/`remember` sind weg; Import in `all_lists_new_list.dart`
  gestrichen; `nudge_card.dart` und `recommendation_item.dart` gelöscht.
- A-P1 bis A-P4 (B7 Wochenplan): `buildPlanSegment` liefert jetzt Slivers und steht direkt im `CustomScrollView`
  des Rezepte-Tabs; `buildPlanFloatingBar` liegt über dem Inhalt bei `ShellInsets.aboveTabBar`; die Toolbar zeigt
  `buildPlanToolbarActions` statt „Gespeichert“/„Mehr“; der Grund wechselt mit dem Segment (`background` /
  `backgroundPlain`, 200 ms). Die Platzhalter in B's `plan_routes.dart` hat A mit B's OK eingetragen. Das Segment ist
  lokaler Zustand, `week`/`day` in der URL bleiben beim Wechsel.
- A-K10: `AvoSubmenu(label:, items:, icon:, subtitle:, enabled:, trailing:, trailingLabel:)` als Eintrag in
  `showAvoMenu`: öffnet an derselben Stelle, Titelzeile führt zurück, beliebig tief; Häkchen, Untertitel, Trenner,
  destruktiv und `ProBadge` (über `trailing`) wie im Hauptmenü. Kontextmenü mit Vorschau: `showAvoMenu(…, preview:)`
  zeichnet die Vorschau an der Stelle des Auslösers und dimmt stärker. Tests in `avo_menu_test.dart` (mit Matrix).

**Simulator-Rundgang** (hell, dunkel, AX3): Home, Liste mit Vorschlags-Panel, Einkaufsmodus, Listenmenü,
Listen-Info, Teilen (Vorab-Erklärung Mitteilungen, Mitglieder), Rezepte-Tab, Rezeptdetail, Profil, Module.
Funde und Folgen:
1. **Rezept „vegan“ mit Eigelb** (P1, behoben): Die Kopfzeile im Detail und der Hero las die ML-Labels mit
   Teilstring („non-vegan“ hätte auch gezählt) und ohne Blick auf die Zutaten. Neu `recipeShownDiet(recipe)`: exaktes
   Label, nur solange keine Zutat dagegen spricht (`breaksRecipeDiet`); ein falsches „vegan“ fällt auf
   „vegetarisch“ zurück. Im Simulator nachgeprüft (`rezeptdetail_vegetarisch_behoben.png`).
2. **Datum ohne Jahr** (P2, behoben): „seit 9. Nov.“ neben „beigetreten 7. Dez.“ las sich wie ein Widerspruch.
   `listDate` zeigt das Jahr, wenn es nicht das laufende ist (Listen-Info, Mitglieder, Änderungen, relative Zeiten).
3. **PLZ-Hinweis im Vorschlags-Panel ohne Fläche** (P2, B's Datei): siehe „Von Teil B“.
4. Kein Fund: Listenmenü zeigt „Einkaufen“ und „Einkauf abschließen“ gleichzeitig (Konzept 11 §1.3); Gruppen bei AX
   randlos (iOS-Verhalten); Vorab-Erklärung vor dem Teilen (Konzept 01 Nr. 3); alte Listenfarbe außerhalb der Palette
   hat keinen Haken.

**Flows mit `idiotensicher-testen`** (Stufe „Schnell“, angepasst): Hinzufügen und Teilen im Simulator von Hand,
dazu ein ahnungsloser Agent (haiku, nur Screenshots, kein Code). Ergebnis: beide Ziele ohne Hilfe erreichbar, keine
P1. P2 aus dem Laien-Blick: Personen-Symbol in der Liste ohne Text, „Nicht jetzt“ nur als Textknopf, „Code zeigen“
unklar, „Kosten teilen“ im Profil klingt nach Teilen der Liste. Gemischte Sprache kam von der Simulator-Sprache
(Englisch), nicht von der App.

**AvoIcons:** neue Glyphen `star` (gefüllt über `filled:`), `infoCircle`, `book`, `bell`, `arrowUpArrowDown`,
`arrowRightArrowLeft`, `leafArrowCirclepath`. Alle 30 `CupertinoIcons`-Stellen in A-Dateien nutzen jetzt
`AvoIcon`; `bash tool/design_check.sh A` meldet keine mehr.

**Entwürfe:** Schlägt das Laden fehl, zeigt der Screen „Entwürfe konnten nicht geladen werden.“ mit „Erneut
versuchen“ statt „Keine Entwürfe“; vorhandene Entwürfe bleiben mit der Zeile darüber stehen (`LibraryStatus(failedKey:)`).

## Braucht den Owner

- Messung am echten iPhone 13 Pro (`integration_test/perf/README.md`), S1-Abbruch dort prüfen, S5 einmal laufen
  lassen.
- Abnahme am Gerät (Konzept 20 §7.6): VoiceOver-Runde, AX3 mit Anzeigezoom, Flugmodus im Einkaufsmodus.
- Rezept „Dillsenfsoße“ (Britta) trägt das Label „vegan“ trotz Eigelb: in den Daten korrigieren (die App zeigt es
  jetzt nicht mehr als vegan an).

## Von Teil B (gewünscht)

- `offer_suggestions_bar.dart` `_PostcodeHintRow`: denselben Schatten wie die Angebotskarte darüber; ohne ihn liegt
  die weiße Zeile unsichtbar auf den weißen Listenzeilen (`abnahme/a11b/fund_panel_ohne_flaeche.png`). B per
  Nachricht informiert.
- Aus `a11-stand.md` weiter offen: `design_check.sh B`-Funde, Kommentar über dem Auth-Listener in `main.dart`.

## Offen bei A (→ S6/S5)

- Filter-Chips „Vegan“/„Vegetarisch“ und „Passt zu mir“ zählen weiter nur Labels; sollen sie `recipeShownDiet`
  nutzen, ändert sich die Trefferzahl (Entscheidung beim nächsten Rezept-Paket).
- Aus AB1/AB2: Galerie-Einträge (u. a. `AvoSubmenu`), `SwipeActions`-Reste, `ItemRow`-Vorschlagsvariante, Präsenz
  im Einkaufsmodus (kein Präsenz-Kanal).
- Artikel-Bilder sind graue Flächen, bis B4 `ArticleImage` füllt.

## Bewusst abgewichen

- `idiotensicher-testen` nur in Stufe „Schnell“ mit einem Agenten (Wochenlimit); die Flows liefen von Hand im
  Simulator, nicht mit Playwright.
- Gesamtsuite im Hauptordner statt im Prüf-Worktree: 13–15 GB frei (Regel: unter 15 GB keine Worktrees).
- Ziehen aus der Kontextmenü-Vorschau (A-K10 „falls machbar“) gibt es nicht; verschieben geht per Untermenü.
