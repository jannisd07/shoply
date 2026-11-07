# Inventar: Rezepte entdecken (Ist-Zustand)

Stand: 2026-11-07, Branch `main` (3e886d0). Nur gelesen, kein Code geändert.
Umfang: Rezepte-Tab, Unterseiten (Alle, Beliebt, Kategorie, Ersteller, Autor, Gespeichert, Meine Rezepte, Entwürfe), gemeinsame Rezept-Widgets, Rezept-Provider, `recipe_service`.
Nicht im Umfang (eigene Inventare): Rezeptdetail, Editor (`multi_step_recipe_screen.dart`), Kochmodus. Deren Widgets aus `recipes/widgets/` sind hier nur kurz erfasst.

Hinweis: `lib/data/services/unified_search_service.dart` existiert nicht mehr. Er wurde in Commit 38ce871 ("delete unused services") gelöscht. Die Rezeptsuche ist heute ein lokaler Filter in `recipes_home_data.dart` (`searchRecipesLocally`).

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/recipes/recipes_screen.dart` | Rezepte-Tab (Startseite des Bereichs): Suche, Rezept der Woche, Shortcuts, Karussells, Kategorien, Ersteller, Neu | 557 |
| `lib/presentation/screens/recipes/recipes_home_data.dart` | Reine Hilfsfunktionen: `RecipeAuthorSummary`, Neu-Liste, Ersteller-Ranking, Kategorie-Zähler, lokale Suche, "Für dich" | 153 |
| `lib/presentation/screens/recipes/recipe_personalization.dart` | Scoring für "Für dich" (Ernährung, Allergien, Bewertung, Frische, App-Prioritäten) | 70 |
| `lib/presentation/screens/recipes/recipe_user_diet.dart` | Extension `UserDietX`: Allergie-/Diät-Strings zu Enums | 20 |
| `lib/presentation/screens/recipes/all_recipes_screen.dart` | "Alle Rezepte" und "Beliebte Rezepte" (Flag `popularOnly`) | 78 |
| `lib/presentation/screens/recipes/category_recipes_screen.dart` | Kategorie- bzw. Ernährungsseite mit Filter-Chips; `categoryRecipesProvider` | 329 |
| `lib/presentation/screens/recipes/creators_screen.dart` | Ersteller-Liste mit Suche; `creatorsProvider` | 349 |
| `lib/presentation/screens/recipes/recipe_author_page.dart` | Autorenprofil mit Rezeptraster | 414 |
| `lib/presentation/screens/recipes/saved_recipes_screen.dart` | Gespeicherte Rezepte (große Karten, Wischen zum Entfernen) | 377 |
| `lib/presentation/screens/recipes/my_recipes_screen.dart` | Eigene veröffentlichte Rezepte; `myRecipesProvider` | 263 |
| `lib/presentation/screens/recipes/recipe_drafts_screen.dart` | Lokale Entwürfe (SharedPreferences) | 339 |
| `lib/presentation/screens/recipes/widgets/recipes_home_widgets.dart` | Bausteine des Tabs: `RecipeSectionHeader`, `RecipeStatItem`, `FeaturedRecipeCard`, `RecipeActionCard`, `RecipeCategoryCard`, `CreatorAvatarCard`, `RecipeCarousel`, `DietAwareRecipeCard` | 509 |
| `lib/presentation/screens/recipes/widgets/recipe_image_card.dart` | Foto-Kachel mit Titel auf Verlauf, Badge, Lesezeichen | 267 |
| `lib/presentation/screens/recipes/widgets/recipe_grid_card.dart` | Raster-Kachel (Bild oben, Text unten) und `RecipeSliverGrid` | 166 |
| `lib/presentation/screens/recipes/widgets/recipes_search_results.dart` | Suchergebnis-Ansicht: Kategorie-, Ernährungs-, Ersteller-Treffer, Rezeptraster | 263 |
| `lib/presentation/screens/recipes/widgets/recipe_state_views.dart` | `RecipeErrorView`, `RecipeEmptyView`, `recipeListAppBar` | 110 |
| `lib/presentation/screens/recipes/widgets/author_avatar.dart` | Rundes Autorenbild mit Initial-Fallback | 72 |
| `lib/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart` | Sheet "Zur Einkaufsliste hinzufügen" (Portionen, Ersatzzutaten, Listenwahl, Hinzufügen), Erfolgs-HUD (genutzt von Detail und Avo) | 694 |
| `lib/presentation/screens/recipes/widgets/recipe_offers_card.dart` | Angebotskarte im Rezeptdetail | 237 |
| `lib/presentation/screens/recipes/widgets/servings_stepper.dart` | Portionen-Stepper | 90 |
| `lib/presentation/screens/recipes/widgets/step_progress_ring.dart` | Fortschrittsring (Editor, Kochmodus) | 59 |
| `lib/presentation/screens/recipes/widgets/recipe_editor_palette.dart` | Farbpalette "Cookbook Evening" (Editor, Kochmodus) | 25 |
| `lib/presentation/widgets/recipes/star_rating_widget.dart` | `StarRatingWidget`, `CompactStarRating`, `LargeStarRating` | 284 |
| `lib/presentation/widgets/recipes/nutrition_info_widget.dart` | Nährwertkarte (nur im Detail genutzt) | 252 |
| `lib/presentation/state/recipes_provider.dart` | `recipesProvider` (alle Rezepte), `recipeRefreshTriggerProvider`, `refreshRecipeData()` | 30 |
| `lib/presentation/state/saved_recipes_provider.dart` | `savedRecipesProvider` (StateNotifier), `isRecipeSavedProvider`, Widget-Push | 162 |
| `lib/presentation/providers/recipe_offers_provider.dart` | `recipeOffersProvider` (Angebote je Rezept, nur mit echter PLZ) | 49 |
| `lib/presentation/state/calorie_recipe_nudge_provider.dart` | Rezeptvorschläge nach Restkalorien (Home, Kalorien) | 49 |
| `lib/data/services/recipe_service.dart` | Supabase-Zugriff: alle Rezepte (30-s-Cache), Detail, CRUD, Bewertung, Speichern, Beliebt, Autor | 815 |
| `lib/data/services/recipe_features_service.dart` | `getRecipeOfTheWeek()` | (nur genutzte Methode gelesen) |
| `lib/data/services/recipe_draft_service.dart` | Entwürfe in SharedPreferences | (gelesen bis Zeile 60) |
| `lib/core/constants/recipe_categories.dart` | 12 Kategorien mit Emoji, Farbe, Suchbegriffen | 127 |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Rezepte-Tab (`RecipesScreen`)
- **Datei:** `recipes_screen.dart`
- **Route/Einstieg:** Tab 2 der Shell, `/recipes` (`app_router.dart:180`), `NoTransitionPage`. Query `?q=` füllt die Suche vor (Siri-Intent `ios/Runner/AppIntents.swift:278` erzeugt `shoply://recipes/search?q=`, `deep_link_service.dart:206` macht daraus `/recipes?q=`).
- **Hauptfrage heute:** unklar. Der Screen versucht gleichzeitig "Was koche ich?", "Was ist beliebt?", "Wer sind die Ersteller?" und "Wo sind meine Sachen?" zu beantworten.
- **Aufbau von oben nach unten:**
  1. Fester Kopf (scrollt nicht mit): Titel "Rezepte" in Georgia-Serif 27 pt, rechts runder Glas-Button "+" (neues Rezept, `/recipes/add`).
  2. Suchfeld als Glas-Kapsel, 42 pt hoch, Platzhalter "Rezepte und Benutzer suchen".
  3. Scrollbereich (`CustomScrollView`) mit Pull-to-Refresh:
     - Statistik-Banner: Anzahl Rezepte, Anzahl Ersteller, Anzahl gespeichert (Serif-Zahlen).
     - "REZEPT DER WOCHE" (Kicker in Großbuchstaben), Hero-Karte: Bild 150 pt, Pille "REZEPT DER WOCHE" auf dem Bild, Lesezeichen, Titel Serif 19, Zeile "x min · Autor · Stern", Zeile mit Einkaufswagen und "Zur Liste".
     - 2x2 Shortcut-Kacheln: Meine Rezepte, Gespeicherte Rezepte (mit Zähler-Badge), Meine Entwürfe, Ersteller.
     - "EMPFOHLEN FÜR DICH": horizontales Karussell (Foto-Kacheln 160x196).
     - "BELIEBT DIESE WOCHE" + "Alle anzeigen": Karussell.
     - "NACH KATEGORIE DURCHSUCHEN": 4-spaltiges Raster mit 12 Kacheln (Emoji, Name, Anzahl).
     - "TOP ERSTELLER" + "Alle anzeigen": horizontale Avatar-Reihe (max. 8).
     - "KÜRZLICH HINZUGEFÜGT" + "Alle anzeigen": 2-spaltiges Raster, max. 6 Kacheln mit Diät-Badge.
     - Unterer Abstand 120 pt + Safe Area (für die schwebende Tab-Leiste).
- **Komponenten:** `AdaptiveGlass` (native Liquid-Glass-Platform-View) für "+" und Suchfeld; `RecipeSectionHeader`, `RecipeStatItem`, `FeaturedRecipeCard`, `RecipeActionCard`, `RecipeCarousel` → `RecipeImageCard`, `RecipeCategoryCard`, `CreatorAvatarCard`, `DietAwareRecipeCard`; `CupertinoSliverRefreshControl`.
- **Zustände:**
  - Laden: Beim allerersten Start ohne Cache ganzseitiger Spinner mit "Rezepte werden geladen...". Mit Cache (`OfflineCacheService.getCachedRecipesSync`, in `main.dart:68` vorgewärmt) erscheint sofort Inhalt. "Rezept der Woche", "Für dich" und "Beliebt" sind nicht gecacht und erscheinen erst nach dem Netzwerkabruf (Layout springt).
  - Leer: kein eigener Zustand. Ohne Rezepte bleiben Shortcuts und das Kategorienraster (alle Zähler unsichtbar), alle anderen Abschnitte verschwinden.
  - Fehler: nur Snackbar "Fehler beim Laden der Rezepte". Praktisch nie erreichbar, weil `RecipeService.getRecipes` Fehler schluckt (siehe 4.1).
  - Offline: es gibt keinen Offline-Hinweis. Siehe Bug 4.1: Offline überschreibt den Cache mit einer leeren Liste.
  - Pro gesperrt / Modul aus: gibt es nicht (Rezepte sind Kern).
- **Suchmodus** (sobald Text im Feld): ersetzt den Scrollbereich durch `RecipesSearchResults` (2.2). Entprellung 250 ms, lokale Filterung.
- **Aktionen/Gesten:** Tippen auf Karte → `/recipes/:id` (Detail, Rezept als `extra`); Lesezeichen auf jeder Foto-Kachel (Haptik light); "+" → Editor; Shortcuts → `/recipes/my|saved|drafts|creators`; "Alle anzeigen" → `/recipes/popular`, `/recipes/creators`, `/recipes/all`; Kategorie → `/recipes/category/:id`; Ersteller → `/author/:id` (Top-Level-Route außerhalb der Shell); Pull-to-Refresh mit `forceRefresh`; Tastatur schließt beim Ziehen.
- **Nebeneffekte:** 1,2 s nach dem Öffnen kann ein Diät-Dialog aufpoppen (`ContextualPromptService.showDietPrompt`, `recipes_screen.dart:86-94`), einmalig, wenn keine Ernährungspräferenzen gesetzt sind. `DynamicTutorialService` hängt GlobalKeys an "+" und an den Scrollbereich (Tutorial-Overlay).
- **Datenquellen:** `recipesProvider` (alle Rezepte), `RecipeService.getPopularRecipes(limit: 9, thisWeekOnly: true)`, `RecipeFeaturesService.getRecipeOfTheWeek()`, `currentUserProvider` (Diät/Allergien/Prioritäten), `savedRecipesProvider` (nur Anzahl), `recipeRefreshTriggerProvider` (Listener), `OfflineCacheService`, `ContextualPromptService`, `DynamicTutorialService`. Alle Abschnitte außer "Beliebt" und "Rezept der Woche" werden im Speicher aus der einen Liste abgeleitet (`recipes_home_data.dart`).
- **Logik der Abschnitte:**
  - Rezept der Woche: Top 5 nach Bewertungen der letzten 7 Tage, sonst 30 Tage, sonst gesamt, sonst nach Aufrufen; daraus wochenstabil eins (`recipe_features_service.dart:24-59`).
  - Beliebt: Anzahl und Schnitt der Bewertungen der letzten 7 Tage; Rezept der Woche wird ausgeschlossen; max. 8.
  - Für dich: Score aus Diätlabels (+2), Allergen-Treffer (-5), Bewertung, Aufrufe, Anzahl Bewertungen, Frische; Priorität `eat_healthier` und `discover_recipes` verstärken; ohne Profil Top-bewertet; max. 6 (bei wenigen Rezepten die Hälfte).
  - Neu: nach `createdAt`, Hälfte-Regel bei wenigen Rezepten, max. 10 (angezeigt max. 6).
  - Ersteller: Score `(Rezepte*10) + (Aufrufe*0,1) + (Bewertungen*2) + (Schnitt*5)`.
- **Wichtigste Texte (DE):** "Rezepte", "Rezepte und Benutzer suchen", "Rezept der Woche", "Zur Liste", "Meine Rezepte", "Gespeicherte Rezepte", "Meine Entwürfe", "Ersteller", "Empfohlen für dich", "Beliebt diese Woche", "Alle anzeigen", "Nach Kategorie durchsuchen", "Top Ersteller", "Kürzlich hinzugefügt", "Rezepte werden geladen...".

### 2.2 Suchergebnisse (`RecipesSearchResults`)
- **Datei:** `widgets/recipes_search_results.dart`; eingebettet im Rezepte-Tab.
- **Hauptfrage:** "Welches Rezept, welche Kategorie oder welche Person meine ich?"
- **Aufbau:** Abschnitt "Kategorien" (Chips mit Emoji und Kategoriefarbe 15 %), "Ernährungsweisen" (Chips: vegan, vegetarisch, schnell, gesund, glutenfrei, Low Carb), "Ersteller" (max. 3 `ListTile`s mit Avatar), "Rezepte (n)" mit 2-spaltigem Raster aus `DietAwareRecipeCard`.
- **Zustände:** Leer → Symbol, "Keine Ergebnisse", "Versuche eine andere Suche". Kategorien/Diäten erst ab 2 Zeichen. Kein Laden (lokal).
- **Aktionen:** Chip → `/recipes/category/:id`; Ersteller → `/author/:id`; Rezept → Detail.
- **Suchlogik:** `searchRecipesLocally` (`recipes_home_data.dart:100-112`): ganzer Suchbegriff als Teilstring in Name, Beschreibung, Autor, Labels oder Zutatennamen; Sortierung nur nach Bewertung.

### 2.3 Alle Rezepte / Beliebte Rezepte (`AllRecipesScreen`)
- **Datei:** `all_recipes_screen.dart`; Routen `/recipes/all` und `/recipes/popular` (`app_router.dart:222-232`).
- **Hauptfrage:** "Alle Rezepte durchblättern" bzw. "Was ist am beliebtesten?"
- **Aufbau:** Material-`AppBar` mit Zurück-Pfeil und Titel 20 pt fett; 2-spaltiges Raster aus `RecipeGridCard` (Bild 120 pt, Name, Zeit, Stern). Keine Sortierung, kein Filter, keine Suche.
- **Zustände:** Laden (`CupertinoActivityIndicator` mittig), Fehler (`RecipeErrorView`: rotes Symbol, Text, Material-`ElevatedButton` "Erneut versuchen"), leer ("Keine Rezepte gefunden").
- **Datenquellen:** "Alle" = `recipesProvider`; "Beliebt" = privater `_popularRecipesPageProvider` (`getPopularRecipes(limit: 50)`, beobachtet Refresh-Trigger).
- **Aktionen:** Tippen → Detail; Lesezeichen (ohne Haptik); Pull-to-Refresh.

### 2.4 Kategorie-Seite (`CategoryRecipesScreen`)
- **Datei:** `category_recipes_screen.dart`; Route `/recipes/category/:categoryId`.
- **Hauptfrage:** "Welche Rezepte gibt es in dieser Kategorie, eingeschränkt nach meinem Bedarf?"
- **Aufbau:** AppBar mit übersetztem Kategorienamen (Fallback: ID mit Großbuchstaben); Chip-Leiste 52 pt hoch mit Haarlinie unten (nur Chips, die in der Kategorie vorkommen: Schnell, 30 Min, Einfach, Mittel, Fortgeschritten, Vegetarisch, Vegan, Glutenfrei, Gesund); Raster `RecipeSliverGrid`.
- **Zustände:** Laden, Fehler, leer ("Keine Rezepte gefunden" / "Keine Rezepte in dieser Kategorie"), leer durch Filter (+ Textbutton "Filter zurücksetzen").
- **Datenquellen:** `categoryRecipesProvider` (filtert `recipesProvider` per Teilstring im Label), `_categoryFiltersProvider` (Filter je Kategorie, nicht autoDispose, bleibt bis App-Neustart erhalten).
- **Aktionen:** Chip an/aus (UND-Verknüpfung, exakte Label-Gleichheit), Tippen → Detail, Pull-to-Refresh (invalidiert `recipesProvider`).

### 2.5 Ersteller (`CreatorsScreen`)
- **Datei:** `creators_screen.dart`; Route `/recipes/creators`.
- **Hauptfrage:** "Wessen Rezepte will ich mir ansehen?"
- **Aufbau:** AppBar mit Titel "Ersteller" und Lupe; Suche ersetzt den Titel durch ein `TextField` (Entprellung 300 ms, Schließen-X). Liste von Karten: Avatar 60 pt mit Verlaufsring (Terrakotta), Name 16 pt, Kapseln "n Rezepte" und Stern-Schnitt, Chevron in getöntem Quadrat. Ohne Suche Top 50, mit Suche alle Treffer.
- **Zustände:** Laden, Fehler, leer ("Noch keine Ersteller" / "Sei der Erste, der ein Rezept teilt!"), keine Treffer ("Keine Ersteller gefunden").
- **Datenquellen:** `creatorsProvider` = `topAuthorsFrom(recipesProvider)`.
- **Aktionen:** Karte → `/author/:id`; Zurück schließt erst die Suche; Pull-to-Refresh.

### 2.6 Autorenprofil (`RecipeAuthorPage`)
- **Datei:** `recipe_author_page.dart`; Route `/author/:authorId` (Top-Level, außerhalb der Shell, `app_router.dart:326`), auch als Deep Link `shoply://author/:id`.
- **Hauptfrage:** "Wer ist das und was hat diese Person gekocht?"
- **Aufbau:** AppBar mit Autorenname; Kopfkarte: Avatar 100 pt, Name 22 pt, Kapseln "n Rezepte" und "Ø 4,2"; Abschnitt "Rezepte von <Name>"; 2-spaltiges Raster eigener Karten (Bild, Zeit-Badge, Name, `CompactStarRating`). Kein Folgen, keine Bio, kein Teilen.
- **Zustände:** Laden (Spinner), leer ("Keine Rezepte gefunden"). Fehler-Snackbar "Profil konnte nicht geladen werden." ist praktisch unerreichbar (siehe 4.5).
- **Datenquellen:** `RecipeService.getRecipesByAuthor` direkt im State (kein Provider).
- **Aktionen:** Karte → `/recipe/:id` (Deep-Link-Route außerhalb der Shell), Pull-to-Refresh.

### 2.7 Gespeicherte Rezepte (`SavedRecipesScreen`)
- **Datei:** `saved_recipes_screen.dart`; Route `/recipes/saved`, Deep Link `shoply://recipes/saved`, Ziel des iOS-Widgets "Gespeicherte Rezepte".
- **Hauptfrage:** "Was wollte ich nachkochen?"
- **Aufbau:** `SliverAppBar` (ausgeklappt 100 pt, eingeklappt 60 pt) mit Titel 24 pt und "n Rezepte"; Liste großer Karten: Bild 160 pt, weißer Lesezeichen-Kreis, Name 17 pt, Beschreibung 2 Zeilen, Autor (tippbar → Profil), Zeit, Stern.
- **Zustände:** Laden (nur bei leerer Liste), leer (Lesezeichen-Symbol, "Keine gespeicherten Rezepte", "Speichere Rezepte, um sie später leicht zu finden", Outline-Button "Rezepte durchsuchen" = zurück).
- **Datenquellen:** `savedRecipesProvider`; lädt beim Öffnen neu.
- **Aktionen:** Tippen → Detail; Wischen nach links entfernt (roter Hintergrund mit Mülleimer, kein Rückgängig); Lesezeichen-Kreis entfernt; Autor → Profil.

### 2.8 Meine Rezepte (`MyRecipesScreen`)
- **Datei:** `my_recipes_screen.dart`; Route `/recipes/my`.
- **Hauptfrage:** "Was habe ich veröffentlicht, und wie kommt es an?"
- **Aufbau:** AppBar mit "+"; Liste von Zeilenkarten: Bild 100x100, Name, relatives Datum ("Heute", "vor 3 Tagen"), Zeit, Stern mit Anzahl; Bearbeiten-Button (Stift in getöntem Quadrat) und Chevron.
- **Zustände:** Laden, Fehler (praktisch unerreichbar, `getMyRecipes` gibt bei Fehler `[]`), leer ("Noch keine Rezepte", "Teile deine Lieblingsrezepte mit der Community!", Button "Rezept erstellen").
- **Datenquellen:** `myRecipesProvider` (autoDispose, beobachtet Refresh-Trigger) → `getMyRecipes`.
- **Aktionen:** Tippen → Detail; Stift → Editor mit `recipeId`; "+" → Editor; Pull-to-Refresh. Kein Löschen, kein Teilen in der Liste.

### 2.9 Meine Entwürfe (`RecipeDraftsScreen`)
- **Datei:** `recipe_drafts_screen.dart`; Route `/recipes/drafts`.
- **Hauptfrage:** "Wo war ich beim Rezepteschreiben stehen geblieben?"
- **Aufbau:** AppBar; Liste: lokales Bild 100x100 oder Platzhalter, Name (kursiv grau "Unbenannter Entwurf" wenn leer), Beschreibung (kursiv "no_description" wenn leer), relative Zeit, Status-Pille "Bereit zum Veröffentlichen" (grün) oder "Unvollständig" (Akzent), Mülleimer-Button.
- **Zustände:** Laden, leer ("Keine Entwürfe", "Deine Rezeptentwürfe erscheinen hier"). Kein Fehlerzustand.
- **Datenquellen:** `RecipeDraftService` (SharedPreferences, nur dieses Gerät), `RecipeDraftImages.resolve` (Pfad nach App-Update neu auflösen).
- **Aktionen:** Tippen → Editor mit `draftId`, danach Neuladen; Löschen → Material-`AlertDialog` "Entwurf löschen" / "Möchtest du diesen Entwurf wirklich löschen?" → Snackbar.

### 2.10 Sheet "Zur Einkaufsliste hinzufügen" (`SelectListBottomSheet`)
- **Datei:** `widgets/select_list_bottom_sheet.dart`; geöffnet aus Rezeptdetail und von Avo (`avo_assistant_service.dart:488` verweist auf dieselbe Logik).
- **Hauptfrage:** "Auf welche Liste, für wie viele Personen?"
- **Aufbau:** Kopf (Zurück-Chevron in Schritt 2, Titel, runder X-Button 30 pt); Portionen-Zeile mit Stepper; optional Schalter "Angepasste Zutaten" (orange); Schritt 1: Listen als gruppierte Zeilen (blaues Wagen-Symbol in getöntem Quadrat); Schritt 2: Zusammenfassung "n Zutaten · n Portionen" mit Pillen "n im Angebot" und "n angepasst", Zutatenliste (max. 220 pt hoch), blauer Button "Hinzufügen n Zutaten".
- **Zustände:** Listen laden, Fehler ("Fehler"), keine Listen ("Noch keine Listen", ohne Aktion), Hinzufügen läuft (Fortschritt "x von n", Sheet nicht schließbar über `PopScope`).
- **Ergebnis:** Erfolgs-HUD (eigener Dialog, grünes Häkchen, "Hinzugefügt", schließt nach 1,5 s), Teil-Erfolg (orange Snackbar mit "Ansehen" → Liste), Fehlschlag (rote Snackbar).
- **Logik:** Zutaten nacheinander über `ItemRepository.addItem`; Angebotspreis, Händler, Einheit und "statt"-Preis werden mitgespeichert; danach Invalidierung von Items und Listen.

### 2.11 Dialog "Ernährung" (`ContextualPromptService.showDietPrompt`)
- Einstieg: automatisch 1,2 s nach erstem Öffnen des Tabs, einmalig, nur wenn `users.diet_preferences` leer ist. Datei `lib/data/services/contextual_prompt_service.dart:21-56`. Inhalt gehört zum Onboarding-/Profil-Inventar.

### 2.12 Kleinere Bausteine (nur Detail/Editor/Kochmodus)
- `RecipeOffersCard`: Angebotskarte im Detail, nur mit echter PLZ, rendert nichts bei Laden/Fehler/keinen Treffern. Texte "Diese Woche im Angebot", "n von m Zutaten sind bei dir im Angebot", "Spare bis zu x € gegenüber Normalpreisen", "statt x €", "Ähnliches Produkt".
- `ServingsStepper`, `StepProgressRing`, `RecipeEditorPalette`, `NutritionInfoWidget`, `StarRatingWidget`/`LargeStarRating`: werden in den jeweiligen Inventaren behandelt.

---

## 3. Design-Probleme heute

### 3.1 Paper-Reste (Kicker, Serifen, Creme/Terrakotta)
- Kicker in Großbuchstaben über jeder Sektion: `recipes_home_widgets.dart:34-41` (`title.toUpperCase()`, 11 pt, Laufweite 2). Zweiter Kicker als Pille auf dem Hero-Bild: `recipes_home_widgets.dart:157-176`.
- Georgia-Serif: Tab-Titel `recipes_screen.dart:262` (27 pt), Statistik-Zahlen `recipes_home_widgets.dart:98`, Hero-Titel `recipes_home_widgets.dart:219`, Angebotspreis `recipe_offers_card.dart:205`.
- Creme/Terrakotta: Akzent `AppColors.accent = 0xFFC0502A` (`app_colors.dart:69`), Hintergrund hell `0xFFF7F3EC` (`app_colors.dart:41`, `recipeLightBg` `:121`); `PaperColors.paper/creamInk` im Hero `recipes_home_widgets.dart:163,172,187,193`; Salbei-Platzhalter `0xFFB7C4A9` `:145,149`; `PaperColors.cream` in Suche `recipes_search_results.dart:186`, Angebotskarte `recipe_offers_card.dart:122,126`, Sheet `select_list_bottom_sheet.dart:177,179,271`.
- Zwei Paletten nebeneinander: Tab nutzt `AppColors.background/surface`, Unterseiten `AppColors.recipeBg/recipeSurface` (dunkel grünstichig `0xFF0A120A`, `app_colors.dart:115`). Wechsel Tab → Unterseite ändert sichtbar den Hintergrund.
- Zweiter Akzent: Sheet und Stepper nutzen `CupertinoColors.systemBlue` (`select_list_bottom_sheet.dart:257,410,602`, `servings_stepper.dart:78,85`), der Rest Terrakotta.

### 3.2 Abweichungen von Apple-Regeln
- **Kein Large Title, kein Scroll unter Glas:** Kopf ist eine feste `Column` über dem Scrollbereich (`recipes_screen.dart:230-243`); Inhalte scrollen nicht unter die Navigationsebene, kein Einklappen, kein Scroll-Edge-Effekt. Unterseiten nutzen Material-`AppBar` mit eigenem `arrow_back_ios_rounded` (`recipe_state_views.dart:96-108`, `creators_screen.dart:72-123`, `recipe_author_page.dart:90-106`, `recipe_drafts_screen.dart:91-107`).
- **Glas auf Inhalt:** Suchfeld ist eine Glas-Platform-View (`recipes_screen.dart:295-319`). Als Teil der Navigationsebene vertretbar, aber es sitzt in einer opaken Kopfzeile ohne Inhalt darunter, also ohne Nutzen und mit Kosten einer Platform View. `AdaptiveGlass` nimmt `MediaQuery.highContrastOf` als Ersatz für "Transparenz reduzieren" (`liquid_glass_container.dart:149`), das ist das falsche Signal.
- **Emojis statt SF Symbols:** Kategorie-Icons (`recipe_categories.dart:27-105`, gerendert `recipes_home_widgets.dart:341`, `recipes_search_results.dart:123`). Material-Icons statt SF Symbols fast überall (`Icons.bookmark_rounded`, `Icons.restaurant_rounded` usw.).
- **Icons in getönten Quadraten:** Chevron-Kachel `creators_screen.dart:330-341`, Stift-Kachel `my_recipes_screen.dart:221-236`, Wagen-Kachel `select_list_bottom_sheet.dart:406-416`.
- **Reihen identischer Karten:** 2x2 Shortcut-Kacheln `recipes_screen.dart:383-431`; 12 gleiche Kategoriekacheln `:457-478`; gleichförmige Ersteller-Karten `creators_screen.dart:180-348`.
- **Vanity-Zahlen:** Statistik-Banner Rezepte/Ersteller/Gespeichert `recipes_screen.dart:337-365`. "Gespeichert" doppelt (Banner und Badge `:402`).
- **Material-Muster:** `InkWell`-Ripple (`creators_screen.dart:217`, `saved_recipes_screen.dart:241`, `recipe_drafts_screen.dart:206`), `ElevatedButton` (`recipe_state_views.dart:22`), `OutlinedButton` (`saved_recipes_screen.dart:180`, `my_recipes_screen.dart:92`), `AlertDialog` (`recipe_drafts_screen.dart:52`), `ListTile` (`recipes_search_results.dart:178`), Material-Snackbars.
- **Rückgängig fehlt:** Entfernen aus Gespeichert per Wischen ohne Undo (`saved_recipes_screen.dart:220-223`), der Hintergrund zeigt einen roten Mülleimer, obwohl nichts gelöscht wird (`:224-233`). Entwurf löschen per Bestätigungsdialog statt Undo (`recipe_drafts_screen.dart:49-79`).
- **Falsche Affordance:** "Zur Liste" mit Wagen im Hero ist reiner Text; Tippen öffnet nur das Rezept (`recipes_home_widgets.dart:230-239`).
- **Touch-Ziele unter 44 pt:** "Alle anzeigen" als `GestureDetector` um 12-pt-Text (`recipes_home_widgets.dart:44-54`); Hero-Lesezeichen ca. 32 pt (`:180-196`); Lesezeichen `RecipeGridCard` ca. 28 pt (`recipe_grid_card.dart:59-77`); Entfernen-Kreis Gespeichert ca. 36 pt (`saved_recipes_screen.dart:275-289`); Bearbeiten ca. 36 pt (`my_recipes_screen.dart:221-235`); Sheet-X und Zurück 30 pt (`select_list_bottom_sheet.dart:247-249,275-293`); Stepper-Buttons 30 pt (`servings_stepper.dart:73-75`); Diät-/Kategorie-Chips ca. 34 pt (`recipes_search_results.dart:86`, `category_recipes_screen.dart:304`).
- **Haptik uneinheitlich:** Lesezeichen in `RecipeImageCard` mit Haptik (`recipe_image_card.dart:193`), in `RecipeGridCard`, Hero und Gespeichert ohne.
- **Bewegung:** feste Dauer statt Feder bei Filter-Chips (`category_recipes_screen.dart:301-303`, 180 ms easeInOut), `StepProgressRing` 250 ms. Kein Reduce-Motion-Pfad im Bereich (grep `disableAnimations` ohne Treffer).
- **Nicht adaptive Farben:** Diät-Badge `Colors.orange/green/red` (`recipes_home_widgets.dart:489-491`); Kartenhintergrund `0xFF1E1E1E`/weiß hart (`creators_screen.dart:200`); Textgrau hart `0xFF6B6B6B`/`0xFF9CA3AF` (`recipe_offers_card.dart:28-29,99-100`); Fallback `0xFF2C2C2E` (`recipe_image_card.dart:215`).
- **Blasser Fließtext:** Leer-Titel in `textSecondary` (`recipe_state_views.dart:62`), Untertitel mit 0,7 Alpha (`:72`), Entwurfstexte 0,7 Alpha (`recipe_drafts_screen.dart:283,289`).
- **VoiceOver:** Lesezeichen-Buttons, "+", Kategorie- und Foto-Kacheln haben keine `Semantics`-Labels (grep ohne Treffer im Bereich); Emoji wird vorgelesen.

### 3.3 Feste Höhen, Breiten, Schriftgrößen (brechen bei großer Schrift oder 320 pt)
Es gibt keine globale Begrenzung von `textScaler` (grep in `app.dart`/`main.dart` ohne Treffer), Dynamic Type schlägt also voll durch.
- Suchfeld `SizedBox(height: 42)` mit 14-pt-Text (`recipes_screen.dart:295-316`): gleicher Fehlertyp wie die abgeschnittene Listen-Eingabeleiste; bei großen Stufen wird der Text oben/unten abgeschnitten.
- Karussell `SizedBox(height: 210)`, Kacheln 160x196 (`recipes_home_widgets.dart:444-457`): zweizeiliger Titel plus Meta-Zeile laufen bei großer Schrift aus der Kachel.
- Ersteller-Reihe `SizedBox(height: 110)`, Breite 80, Texte 12/10 pt (`recipes_screen.dart:488-489`, `recipes_home_widgets.dart:396,419,426`): unten Overflow.
- Kategorieraster 4 Spalten, Seitenverhältnis 0,75, Text 11/10 pt (`recipes_screen.dart:460-465`, `recipes_home_widgets.dart:341-363`): bei 320 pt ca. 64 pt breite Kacheln, Namen wie "Mediterran"/"Comfort Food" werden abgeschnitten; bei großer Schrift Overflow.
- Raster mit festem Seitenverhältnis: 0,82 (`recipes_screen.dart:525`, `recipes_search_results.dart:249`), 0,75 mit fester Bildhöhe 120 und `Spacer` (`recipe_grid_card.dart:17,97,153`), 0,75 im Autorenprofil (`recipe_author_page.dart:227`): RenderFlex-Overflow bei großer Schrift.
- Hero-Bild 150 pt fest (`recipes_home_widgets.dart:136`).
- Chip-Leiste `height: 52` (`category_recipes_screen.dart:239`).
- `SliverAppBar` `expandedHeight: 100`, `collapsedHeight: 60`, Titel 24 pt plus Untertitel (`saved_recipes_screen.dart:64-99`): Überlappung bei großer Schrift.
- Feste Bildflächen 100x100 in Zeilen (`my_recipes_screen.dart:145-160`, `recipe_drafts_screen.dart:220-222`); Zeile kann bei großer Schrift höher werden, Bild nicht.
- Erfolgs-HUD 120x120 mit Text (`select_list_bottom_sheet.dart:79-80`).
- Zutatenliste im Sheet `maxHeight: 220` (`select_list_bottom_sheet.dart:532`).
- Kleinste Schriften: 9,5 pt (`recipe_offers_card.dart:159,166,227`), 10 pt (`recipes_home_widgets.dart:169,292,362,426`, `step_progress_ring.dart:50`), 10,5/11,5 pt (`recipe_image_card.dart:146,179`), 11 pt an vielen Stellen.
- Zeilen ohne Umbruch: Statistik-Banner `spaceEvenly` (`recipes_screen.dart:347-362`); Autoren-/Zeit-/Stern-Zeile Gespeichert ohne `Expanded` um den Autorennamen (`saved_recipes_screen.dart:318-366`) läuft bei langem Namen oder 320 pt über; Zusammenfassung im Sheet ohne `Expanded` (`select_list_bottom_sheet.dart:475-525`); Shortcut-Labels einzeilig mit Ellipse (`recipes_home_widgets.dart:301-311`).
- Fester Unterabstand für die Tab-Leiste: 120 pt (`recipes_screen.dart:539`), 100 pt (`recipe_grid_card.dart:147`, `recipes_search_results.dart:242`, `creators_screen.dart:144`, `saved_recipes_screen.dart:123`, `my_recipes_screen.dart:64`, `recipe_author_page.dart:244`).

### 3.4 Wayfinding und Informationsarchitektur
- Der Tab hat neun Abschnitte und keine Hauptfrage. Eigene Inhalte (Meine Rezepte, Entwürfe, Gespeichert) und Entdecken (Für dich, Beliebt, Kategorien, Ersteller, Neu) stehen gleichrangig untereinander.
- "Ersteller" hat drei Einstiege (Shortcut, "Top Ersteller" + "Alle anzeigen", Suche).
- "Meine Rezepte" (Server) und "Meine Entwürfe" (nur lokal) sind zwei Screens für dieselbe Frage.
- Autorenprofil und Rezepte daraus liegen außerhalb der Shell (`/author/:id`, `/recipe/:id`), alle anderen innerhalb (`/recipes/...`). Je nach Weg ist die Tab-Leiste da oder weg.
- Platzhalter "Rezepte und Benutzer suchen" verspricht Benutzersuche, gefunden werden aber nur Personen mit veröffentlichten Rezepten.

---

## 4. Bugs, Risiken, Performance

### 4.1 Offline löscht den Rezept-Cache (hoch)
`RecipeService._fetchAllRecipes` fängt jeden Fehler und gibt `[]` zurück (`recipe_service.dart:92-96`). Dadurch greift der Offline-Fallback in `recipesProvider` nie (`recipes_provider.dart:25-28`). Schlimmer: `recipesProvider` schreibt die leere Liste mit `cacheRecipes([])` in Speicher und SharedPreferences (`recipes_provider.dart:20-23`, `offline_cache_service.dart:56-61`). Ablauf: App offline öffnen → Tab zeigt kurz die gecachten Rezepte (`_seedFromCache`), dann ersetzt `_loadAllData` sie durch nichts (`recipes_screen.dart:150-158`), und der Cache ist für den nächsten Start leer.

### 4.2 Neue, gelöschte oder bewertete Rezepte bleiben unsichtbar (hoch)
`refreshRecipeData` erhöht nur den Trigger (`recipes_provider.dart:11-13`). `recipesProvider` beobachtet den Trigger nicht und wird nirgends danach invalidiert (grep: nur `refreshRecipeData` in Editor `multi_step_recipe_screen.dart:1026` und Detail `recipe_detail_screen.dart:853,910`). Der Tab lädt zwar neu (`recipes_screen.dart:222-224`), liest aber per `ref.read(recipesProvider.future)` den alten, bereits aufgelösten Wert. Der Kommentar dort beschreibt eine Invalidierung, die nicht existiert. Folge: Ein gerade veröffentlichtes Rezept fehlt unter "Neu", ein gelöschtes bleibt in Neu, Kategorie, Alle, Ersteller sichtbar, bis man manuell nach unten zieht.

### 4.3 Ein Netzfehler löscht alle Lesezeichen in der Anzeige (hoch)
`getSavedRecipeIds` gibt bei Fehler `{}` zurück, `getSavedRecipes` `[]` (`recipe_service.dart:568-584,532-565`). `loadSavedRecipes` übernimmt das ungeprüft (`saved_recipes_provider.dart:51-63`) und schickt die leere Liste auch an das iOS-Widget. Weil `toggleSave` nach jedem Speichern komplett neu lädt (`:121-122`), reicht ein Funkloch beim Speichern eines Rezepts, und alle Lesezeichen erscheinen leer, das Widget auch.

### 4.4 Allergie-Schutz in "Für dich" wirkungslos (hoch, Sicherheit)
`scoreForYouRecipe` vergleicht die gespeicherten Allergie-Strings (Enum-Namen wie `milk`, `eggs`, `nuts`, `gluten`, siehe `dietary_preference.dart:20-35`, `recipe_user_diet.dart:11-14`) per Teilstring mit deutschen Zutatennamen (`recipe_personalization.dart:35-41`). "Milch", "Ei", "Weizenmehl" enthalten diese Wörter nicht, die Strafe greift praktisch nie. Selbst wenn, reicht -5 nicht zum Ausschluss (`recipes_home_data.dart:140` nimmt alles mit Score > 0). Dazu zeigen Karussell-Kacheln ("Für dich", "Beliebt") kein Diät-/Allergie-Badge, nur das Raster "Neu" und die Suche (`recipes_home_widgets.dart:451-458` vs. `:469-508`).

### 4.5 Fehler werden überall als "leer" angezeigt (mittel)
`getMyRecipes` (`recipe_service.dart:599-602`) und `getRecipesByAuthor` (`:810-813`) geben bei Fehler `[]` zurück. Offline sagt "Meine Rezepte" "Noch keine Rezepte, teile deine Lieblingsrezepte", das Autorenprofil "Keine Rezepte gefunden". Die Fehlerzweige (`RecipeErrorView`, Snackbar `recipe_author_page.dart:65-72`) sind toter Code. Gleiches gilt für den Fehlerzweig im Tab (`recipes_screen.dart:166-173`).

### 4.6 Weitere Bugs
- Diät-Badge-Texte fest auf Deutsch ("Passend", "n Anpassungen", "Nicht geeignet", `ingredient_substitution_service.dart:240-248`), englische Nutzer sehen Deutsch.
- `initialQuery` wird nur in `initState` gelesen (`recipes_screen.dart:66-73`), kein `didUpdateWidget`. Lebt der Tab schon (StatefulShellBranch hält ihn), kann ein zweiter Siri-Suchaufruf ignoriert werden (Risiko, nicht am Gerät geprüft).
- Router-Redirect wandelt `shoply://`-Links nur für die Hosts `recipe, list, invite, author` um, alles andere geht auf `/home` (`app_router.dart:372-379`). `shoply://recipes/search?q=` und `shoply://recipes/saved` landen auf Home, falls der Link den Router vor `DeepLinkService` erreicht (Risiko, Pfad nicht am Gerät geprüft).
- Gespeichert-Karte ohne Bild-URL: Der `Stack` hat dann kein Kind mit Größe, der Lesezeichen-Kreis sitzt über dem Text (`saved_recipes_screen.dart:247-291`).
- Kategorie-Filter bleiben nach Verlassen der Seite gespeichert (`category_recipes_screen.dart:27-28`, kein autoDispose); beim nächsten Besuch ist die Seite unerwartet gefiltert.
- Kategorie-Zuordnung per Teilstring im Label (`recipes_home_data.dart:87-95`, `category_recipes_screen.dart:18-23`), Filter-Chips per exakter Gleichheit (`:96-101`). Inkonsistent; ein Label wie "non-vegan" zählt zu "vegan".
- Rezepte werden ohne Sprachfilter gemischt angezeigt, obwohl `Recipe.language` existiert (`recipe.dart`, Feld `language`).
- `recipesProvider` ist global und nicht pro Nutzer geschlüsselt; `userRating` im Cache gehört nach Kontowechsel zum vorigen Konto (der Service-Cache prüft die User-ID, der Provider nicht).
- Diät-Dialog poppt 1,2 s nach Tab-Öffnung ungefragt auf (`recipes_screen.dart:86-94`) und unterbricht das Stöbern.

### 4.7 Performance
- Ganze Tabelle bei jedem Laden: `select('*, recipe_ratings!left(user_id, rating)')` ohne Limit (`recipe_service.dart:33,77-81`), also alle Rezepte mit allen Bewertungszeilen; Cache nur 30 s (`:37`). Wächst linear mit der Community.
- Der gesamte Katalog wird als JSON-Liste in SharedPreferences geschrieben (`offline_cache_service.dart:56-61`), `jsonEncode` auf dem UI-Isolate.
- Rezept der Woche: bis zu 4 Abfragen nacheinander plus `getRecipeById` (`recipe_features_service.dart:27-54`); `_loadAllData` wartet per `Future.wait` darauf, bevor irgendein Abschnitt aktualisiert wird (`recipes_screen.dart:124-129`).
- "Beliebt diese Woche" lädt alle Bewertungen der Woche roh und aggregiert im Client (`recipe_service.dart:626-650`).
- `toggleSave` lädt nach jedem Tipp die komplette Gespeichert-Liste neu (2 Abfragen + Autoren-Join) und triggert App-Review-Logik (`saved_recipes_provider.dart:121-130`).
- Zur Liste hinzufügen: Zutaten nacheinander, je Zutat Duplikat-Abfrage, Insert und Kategorisierung mit 1,1 s Mindestabstand (`select_list_bottom_sheet.dart:647-679`, `item_repository.dart:127-170`). 10 Zutaten dauern über 10 s, sichtbar als Fortschritt "3 von 10".
- Sichtbares Laden: ganzseitiger Spinner beim Kaltstart ohne Cache (`recipes_screen.dart:545-556`), Spinner in allen Unterseiten, Spinner als Bild-Platzhalter im Hero (`recipes_home_widgets.dart:144-147`) und Autorenprofil (`recipe_author_page.dart:335-340`).
- Schatten mit Blur 14 auf jeder Foto-Kachel (`recipe_image_card.dart:79-85`) im Scroll; `RepaintBoundary` vorhanden.
- Zwei Glas-Platform-Views im Tab-Kopf (`recipes_screen.dart:281,297`).
- Synchrones Datei-I/O im `build`: `File(...).existsSync()` je Entwurfszeile (`recipe_drafts_screen.dart:201-202`); `Image.file` ohne `cacheWidth` dekodiert Kamerafotos in voller Auflösung für 100x100 (`:224-227`).
- `Image.network` statt `CachedNetworkImage` für Angebotsbilder (`recipe_offers_card.dart:114`).
- Lokale Suche filtert alle Rezepte inkl. Zutaten auf dem UI-Thread (`recipes_home_data.dart:100-112`), bei großem Katalog spürbar.

### 4.8 Toter Code
`RecipeService.getRecipesByCategory`, `getTopAuthors`, `searchAuthors` (0 Aufrufer), `creatorCountFrom` (`recipes_home_data.dart:83`), `searchCategories`, `getCategoryById` (`recipe_categories.dart:111-127`). `getRecipesByAuthor` dupliziert `_hydrate` und setzt kein `user_rating` (`recipe_service.dart:761-814`).

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Rezeptdetail** (`recipe_detail_screen.dart`): Ziel jeder Karte (`/recipes/:id` und `/recipe/:id`), nutzt `SelectListBottomSheet`, `ServingsStepper`, `RecipeOffersCard`, `NutritionInfoWidget`, `StarRatingWidget`, `AuthorAvatar`; ruft `refreshRecipeData`.
- **Editor** (`multi_step_recipe_screen.dart`): `/recipes/add` mit `draftId` oder `recipeId`; nutzt `StepProgressRing`, `RecipeEditorPalette`, `RecipeDraftService`, `RecipeDraftImages`.
- **Kochmodus** (`cooking_mode_screen.dart`): `StepProgressRing`, `RecipeEditorPalette`.
- **Avo** (`avo_assistant_service.dart:324,388,488`): `RecipeService.searchRecipes` und dieselbe Zutaten-auf-Liste-Logik wie das Sheet.
- **Listen**: `ItemRepository.addItem`, `itemsNotifierProvider`, `listsNotifierProvider`, `userListsProvider`; Snackbar-Aktion `/lists/:id`.
- **Angebote** (Modul): `recipeOffersProvider` → `effectiveZipProvider` (`price_comparison_provider.dart`), `RecipeOfferService`; Angebotspreise werden in Listenartikel geschrieben (`price*`-Felder).
- **Kalorien** (Modul): `CalorieRecipeNudgeService.getRecentRecipes` nutzt `RecipeService`; Home-Karte "Dinner-Ideen" und "Was kann ich heute noch essen?" zeigen Rezepte.
- **Profil**: `profile_screen.dart:432` zeigt Anzahl gespeicherter Rezepte; Diät/Allergien aus `currentUserProvider` steuern "Für dich" und Badges; `/diet-preferences` Route; `ContextualPromptService` (Diät-Dialog).
- **Widgets (iOS)**: `WidgetService.updateSavedRecipesWidget` aus `savedRecipesProvider` (App Group).
- **Siri/Deep Links**: `AppIntents.swift:278` (Rezeptsuche), `DeepLinkService._parseCustomSchemePath` (`recipe`, `recipes/saved`, `recipes/search`, `author`), Router-Redirect (`app_router.dart:372-379`, `/recipe/` ist öffentlich ohne Login).
- **Tutorial**: `DynamicTutorialService` (`recipesTabKey`, `recipesAreaKey`, `addRecipeButtonKey`, `updateRecipesData`).
- **Offline/Start**: `OfflineCacheService.warmRecipes` in `main.dart:68`.
- **App-Bewertung**: `AppReviewService` beim Speichern.
- **Gemeinsame Design-Dateien**: `app_colors.dart` (recipe*-Farben, Akzent), `paper_colors.dart` (`PaperColors`, `PaperTextStyles.serif`), `app_text_styles.dart`, `liquid_glass_container.dart` (`AdaptiveGlass`).
- **Strings**: `app_translations.dart` (EN ab ca. Zeile 200, DE ab ca. 1260), z. B. `recipes`, `search_recipes_users`, `recipe_of_the_week`, `recommended_for_you`, `popular_this_week`, `browse_by_category`, `top_creators`, `recently_added`, `see_all`, `my_drafts`, `creators`, `saved_recipes`, `recipe_search_*`, `filter_*`, `category_*`, `instead_of_price` ("statt {price} €"), `recipe_offers_*`.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**
- Suche über Name, Beschreibung, Autor, Labels und Zutaten, mit Sprung zu passenden Kategorien, Ernährungsweisen und Erstellern; Vorbefüllung per Siri (`?q=`).
- Personalisierte Empfehlungen nach Ernährung, Allergien und App-Prioritäten (`eat_healthier`, `discover_recipes`) mit Fallback auf Top-bewertet. Allergien müssen dabei tatsächlich ausschließen (heute kaputt, 4.4).
- Rezept der Woche (wochenstabil), Beliebt diese Woche, Neu, alle Rezepte.
- 12 Kategorien plus Ernährungsseiten (vegan, vegetarisch, schnell, gesund, glutenfrei, Low Carb) mit kombinierbaren Filtern (Schnell, 30 Min, Schwierigkeit, Diät).
- Diät-/Allergie-Badge auf jeder Rezeptkachel ("Passend", "n Anpassungen", "Nicht geeignet"); der Code-Kommentar (`recipe_image_card.dart:37-39`) hält fest: eine Warnung darf nie aus Platzgründen verschwinden.
- Lesezeichen von jeder Kachel aus, optimistisch, mit Haptik; Gespeichert-Liste in Speicherreihenfolge; Push an das iOS-Widget.
- Ersteller: Ranking, Suche, Profil mit Rezeptanzahl und Bewertungsschnitt.
- Eigene Rezepte: Liste, Bearbeiten, neues Rezept; Entwürfe mit Status "Bereit"/"Unvollständig", Fortsetzen, Löschen.
- Zur Einkaufsliste: Liste wählen, Portionen skalieren, Ersatzzutaten an/aus, Angebotspreise mitnehmen, Teil-Erfolg mit Fehlernamen melden, Sprung zur Liste.
- Pull-to-Refresh überall; Sofortanzeige aus dem Offline-Cache beim Start.

**Daten und Sonderfälle**
- `Recipe`-Felder: `labels` (Grundlage für Kategorien, Filter, Diät), `language`, `nutrition`, `defaultServings`, `prepTimeMinutes`/`cookTimeMinutes`, `averageRating`/`ratingCount`/`userRating`, `viewCount`, `authorId/Name/AvatarUrl`, `sourceUrl`/`sourceName` (z. B. Wikibooks: Quellenangabe bleibt Pflicht).
- Autorenname und Avatar kommen live aus `users`, mit Fallback auf die gespeicherte Kopie; leerer Name ergibt Initial "?" (`author_avatar.dart:30-33`).
- Hälfte-Regel bei kleinem Katalog: kein Abschnitt zeigt alle Rezepte (`recipes_home_data.dart:38-39`, `recipe_service.dart:609-611`).
- Rezept der Woche wird aus "Beliebt" und "Für dich" ausgeschlossen, "Für dich" schließt "Beliebt" aus.
- Entwürfe liegen nur lokal; Bildpfade müssen nach App-Updates neu aufgelöst werden (`RecipeDraftImages.resolve`).
- Angebote im Rezept nur mit echter PLZ (GPS oder manuell), abgelaufene Angebote werden ausgefiltert; das Modul muss spurlos abschaltbar sein; "statt"-Preise künftig als "laut Händler" kennzeichnen.
- Geteilte Rezepte (`/recipe/:id`) sind ohne Login und vor dem Onboarding erreichbar.
- Das Hinzufügen-Sheet darf während des Hinzufügens nicht schließen (`PopScope`), sonst gehen Bestätigung und Listen-Refresh verloren; die 1,1-s-Regel der Kategorisierung bleibt bestehen (das Redesign muss das Warten verstecken, etwa durch Hinzufügen im Hintergrund mit sofortiger Bestätigung).
- Speichern-Zähler im Profil und im Widget hängen am selben Provider.
