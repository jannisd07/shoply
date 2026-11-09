# A11 Qualität für alle A-Screens – Ergebnis Teil 1 (09.11.2026)

Plan: [`a11-pruefplan.md`](a11-pruefplan.md). Commits: `git log --grep A11`. Zuerst status-B 17 erledigt.
Screenshots: [`abnahme/a11/`](abnahme/a11/).

## Ergebnis

**status-B 17 (1) A-C1** (`004b3fd`): Liste und Einkaufsmodus reichen `itemOfferRowExtras` an `ItemRow` durch
(Satz der Pille in der Zeile, „Angebot ansehen“ als Aktion). Im Einkaufsmodus öffnet langes Drücken mit Angebot ein
Menü „Bearbeiten“/„Angebot ansehen“, ohne Angebot wie bisher direkt Bearbeiten. 17 A-D1 (Kommentar an
`ItemPrice.retailer`) stand schon so.

**Prüfmatrix:** Lücken geschlossen für `RecipesScreen`, `AllRecipesScreen`, `CategoryRecipesScreen`,
`RecipeDraftsScreen`, `MyRecipesScreen`, `SavedRecipesScreen`, `CreatorsScreen`, `RecipeAuthorPage` (376 Fälle),
`HomeScreen` (58), `ShoppingModeScreen` (61), `EmailCodePage` (134), je mit ihren Zuständen (Inhalt, leer, lädt,
Fehler, offline, Module aus) und Touch-Ziel-Stichprobe (`iOSTapTargetGuideline`, `labeledTapTargetGuideline`). Alle
A-Screens außer der Paywall (A9) haben jetzt einen Matrix-Test.

**Design-Regeln:** `tool/design_check.sh [A|B]` (Konzept 20 §7.8). A-Dateien: 0 Funde. Behoben: Farben in
`confirm_dialog`, `shopping_trip_completion`, Glas-Ersatz `liquid_glass_container` (jetzt `glassFill`/`glassBorder`,
damit auch „Kontrast erhöhen“). Markiert statt geändert: Markenfarben (Apple, Google), D2-Kachelfarben, Initialen im
Avatar, Ziffern ohne Laufweite, Android-Fallback-Icons nativer Alerts.

**Fehler behoben:**
- Rezeptdetail öffnet im „Original“, wenn „Rezepte automatisch anpassen“ aus ist (aus AB2 offen).
- `HomeScreen` hatte einen eigenen Supabase-Auth-Listener und lud nach Kontowechsel Listen und Verlauf doppelt
  (beide hängen an `authUserIdProvider`, Widget-Zugang schickt `main.dart`).
- Onboarding: Der letzte Absatz (KI-Hinweis im Schritt Module) lag im Verlauf über der Aktionsleiste; der Inhalt endet
  jetzt 40 pt darüber (im Simulator gefunden).

**Leistung:** Messtests `integration_test/perf/` S1 (Liste scrollen), S2 (Abhaken in Serie), S5 (Rezepte-Tab) mit
Testdaten ohne Server und lokalem Bildserver, Treiber schreibt JSON. Messen nur am Gerät (README dort).
Gesamtsuite im Hauptordner: 12.000 Tests grün, `dart analyze lib test` 0/0.
Simulator-Probelauf: S2 grün, S1 bricht ab (Ursache offen), S5 nie gelaufen.

**Simulator (iPhone 17):** Home hell (angemeldet), Start hell/dunkel, Onboarding Module (auch AX3 dunkel), Angebote,
Konto hell/dunkel. Danach war die App abgemeldet: Der Probelauf der Messtests hat die installierte App ersetzt. Ohne
Anmeldung des Owners keine weiteren Screens.

## Braucht den Owner

- **Im Simulator (iPhone 17) wieder anmelden**, bevor A11b läuft.
- Messung am echten iPhone 13 Pro: `flutter drive --profile …` (README in `integration_test/perf/`), Ergebnis in
  status-A.
- Abnahme am Gerät (Konzept 20 §7.6): VoiceOver-Runde, AX3 mit Anzeigezoom, Flugmodus im Einkaufsmodus.

## Von Teil B (gewünscht)

- `bash tool/design_check.sh B` meldet in B-Dateien: Farbe 12, Schriftgröße 110, Dauer 1, Icon 31, Haptik 20,
  Sheet/Slider 2 (`checkout_store_sheet`, `split_cost_sheet`, harte Regel). Bitte mit den D2-Umbauten abbauen.
- `lib/main.dart`, Kommentar über dem Auth-Listener: „home_screen only re-pushes on launch/user change“ stimmt nicht
  mehr (Home hat keinen eigenen Listener mehr).

## Offen bei A (→ A11b)

- Simulator-Rundgang angemeldet, hell/dunkel, eine Runde AX3: Liste mit Vorschlags-Panel, Listen-Info, Einkaufsmodus
  (mit Angebotsmenü), Rezepte-Tab mit Tipp, Rezeptdetail mit Angeboten, Profil, Einstellungen.
- Flows mit `idiotensicher-testen`: Hinzufügen, Teilen (Onboarding nur bis zum Konto geprüft; Paywall mit A9).
- S1-Abbruch der Messtests klären, S5 einmal laufen lassen (am Gerät).
- 30 Stellen `CupertinoIcons` statt `AvoIcons` (v. a. Rezeptdetail, Kochmodus, Editor): fehlende Glyphen zeichnen.
- Entwürfe: fehlgeschlagenes Laden zeigt „Keine Entwürfe“ statt eines Fehlerzustands.
- Aus BAB2 (B, 09.11., sobald auf `main`): direkten Import von `store_for_list_provider.dart` in
  `all_lists_new_list.dart` weglassen; `_offerSummary` in `recipe_detail_screen.dart` über
  `recipeOfferSummaryShowsProvider(recipeOfferSummaryKey(recipe, listId))` vereinfachen; `nudge_card.dart` und
  `data/models/recommendation_item.dart` löschen (kein Nutzer mehr). OK für B's Zeile in `profile_routes_test.dart`
  gegeben.
- Weiter aus AB1/AB2: A-K10, Galerie-Einträge, `SwipeActions`-Reste, `ItemRow`-Vorschlagsvariante, Präsenz im
  Einkaufsmodus (es gibt noch keinen Präsenz-Kanal; `shoppingCompanionsProvider` liefert immer leer).

## Bewusst abgewichen

- Keine Prüf-Worktree für die Gesamtsuite: die Platte hatte 12–14 GB (Regel: unter 15 GB keine Worktrees); die
  Suite lief im sauberen Hauptordner.
- `ListCard` blendet das Cover ab AX1 weiter nicht aus: kein Konzept verlangt es.
- CupertinoIcons meldet `design_check.sh` nur als Hinweis, bis `AvoIcons` die Glyphen hat.
