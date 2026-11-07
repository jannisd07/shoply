# Inventar: Rezeptdetail, Erstellen und Kochmodus

Stand: 2026-11-07, Branch `main` (Commit 3e886d0). Nur gelesen, kein Code geändert.
Alle Zeilenangaben beziehen sich auf diesen Stand. Pfade relativ zu `/Users/jannisdietrich/Apps/shoply-neu/`.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/recipes/recipe_detail_screen.dart` | Rezeptdetail: Hero-Bild, Kennzahlen, Kochen starten (Pro), Nährwerte, Beschreibung + Bewertung, Zutaten mit Ersatz, Angebote, Schritte, Quelle; Teilen, Merken, Bearbeiten, Löschen, Zutaten auf Liste | 1128 |
| `lib/presentation/screens/recipes/cooking_mode_screen.dart` | Kochmodus Vollbild: Seite 0 Zutaten abhaken, dann ein Schritt pro Seite, Timer mit lokaler Benachrichtigung, Portionen-Sheet, Bildschirm bleibt an | 1035 |
| `lib/presentation/screens/recipes/multi_step_recipe_screen.dart` | Rezept-Editor in 4 Schritten (Foto+Name, Zeiten+Portionen, Zutaten, Anleitung) für Neu, Entwurf und Bearbeiten; Entwurf speichern, Veröffentlichen | 1092 |
| `lib/presentation/screens/recipes/recipe_personalization.dart` | Reine Bewertungsfunktion `scoreForYouRecipe` für "Für dich" auf dem Rezept-Tab (nicht im Detail sichtbar) | 70 |
| `lib/presentation/screens/recipes/widgets/recipe_offers_card.dart` | Karte "Diese Woche im Angebot" im Rezeptdetail | 237 |
| `lib/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart` | Zutaten auf Liste: Liste wählen, Portionen, Ersatz an/aus, Bestätigen, sequentielles Hinzufügen; Erfolgs-HUD und Snackbars | 694 |
| `lib/data/services/ingredient_substitution_service.dart` | Erkennt Allergene/tierische Produkte per Teilstring und liefert Ersatzzutaten | 249 |
| `lib/data/services/recipe_offer_service.dart` | Gleicht Zutaten mit marktguru-Angeboten ab (max. 10 Suchen pro Rezept), 6-h-Cache in SharedPreferences | 227 |
| `lib/data/services/recipe_draft_service.dart` | Entwürfe lokal in SharedPreferences (Schlüssel `recipe_drafts`) | 87 |
| `lib/data/services/recipe_features_service.dart` | Nur noch "Rezept der Woche" (genutzt in `recipes_screen.dart:128`, nicht im Detail) | 95 |
| `lib/data/services/recipe_variations_service.dart` | **Existiert nicht mehr.** Gelöscht in Commit 38ce871 ("never-imported services") | 0 |
| `lib/data/services/unit_conversion_service.dart` | **Existiert nicht mehr.** Gelöscht in Commit 38ce871 | 0 |

Direkt beteiligte Hilfsdateien (außerhalb des Auftrags, aber nötig zum Verständnis):

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/recipes/widgets/servings_stepper.dart` | "− n +" Stepper, 30x30-Buttons, 1 bis 20 | 90 |
| `lib/presentation/screens/recipes/widgets/step_progress_ring.dart` | Ring "x/n" im Kopf von Editor und Kochmodus, 10 pt Text | 59 |
| `lib/presentation/screens/recipes/widgets/recipe_editor_palette.dart` | "Cookbook Evening"-Farben für Editor und Kochmodus | 25 |
| `lib/presentation/screens/recipes/recipe_draft_images.dart` | Kopiert Entwurfsfotos nach `Documents/recipe_drafts` | 56 |
| `lib/presentation/screens/recipes/recipe_drafts_screen.dart` | Entwurfsliste, öffnet Editor mit `draftId` | 339 |
| `lib/presentation/screens/recipes/recipe_user_diet.dart` | `UserModel` → `allergyTypes`, `dietTypes`, `hasDietProfile` | 20 |
| `lib/data/models/dietary_preference.dart` | `AllergyType`, `DietType`, `SubstitutionDatabase` (Ersatz-Tabelle, Filterlogik) | 553 |
| `lib/data/models/recipe.dart` | `Recipe`, `Ingredient.adjustForServings`, `Ingredient.displayText` | ~250 |
| `lib/data/models/recipe_offer_highlight.dart` | `RecipeIngredientOffer`, `RecipeOffersResult.knownSavings` | ~160 |
| `lib/presentation/providers/recipe_offers_provider.dart` | `recipeOffersProvider` (autoDispose family), nur mit echter PLZ | 46 |
| `lib/presentation/widgets/recipes/star_rating_widget.dart` | `LargeStarRating` (48-pt-Zahl + Sterne-Eingabe) | 284 |
| `lib/presentation/widgets/recipes/nutrition_info_widget.dart` | Nährwertkarte (Kalorien, Makro-Chips, Ballaststoffe usw.) | 252 |
| `lib/presentation/screens/calories/widgets/log_recipe_sheet.dart` | "Ins Tagebuch eintragen" (Kalorien-Modul) | 174 |
| `lib/presentation/widgets/common/liquid_glass_container.dart` | `AdaptiveGlass` → `LiquidGlassContainer` = `UiKitView` (native Platform View) | ~250 |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Rezeptdetail (`RecipeDetailScreen`)

- **Datei:** `recipe_detail_screen.dart`
- **Route / Einstieg:** `/recipes/:recipeId` (im Rezept-Tab-Branch, Tab-Leiste bleibt sichtbar, `app_router.dart:243-252`), Deep Link `/recipe/:recipeId` außerhalb der Shell (`app_router.dart:343-352`). Optional `extra: Recipe` als Sofortanzeige (`initialRecipe`), sonst Vollbild-Spinner. Nach "Veröffentlichen" im Editor per `pushReplacement` ohne `initialRecipe` (`multi_step_recipe_screen.dart:1039`).
- **Hauptfrage:** "Will ich das kochen, und was brauche ich dafür?"
- **Aufbau von oben nach unten:**
  1. `SliverAppBar` 280 pt hoch, gepinnt, Stretch (`:174-363`): Hero-Foto (`CachedNetworkImage`), Verlauf nach Schwarz, Titel 24 pt weiß mit Schatten, darunter Autor-Avatar 22 pt + Name (tippbar → `/author/:id`, nur bei nicht importierten Rezepten). Links Zurück-Button in `AdaptiveGlass`. Rechts: bei eigenem Rezept roter Löschen-Kreis + terrakotta Bearbeiten-Kreis (kein Glas), sonst Merken-Button in Glas (gemerkt = weißer Vollkreis); immer Teilen in Glas.
  2. Kennzahlen-Leiste (`:366-409`): Karte mit 4 Spalten, getrennt durch 1-pt-Linien: Gesamtzeit, Portionen (tippbar, Zusatz "tippen zum Ändern"), Sterne-Schnitt + Anzahl, Aufrufe.
  3. "Kochen starten" (`:411-417`, `:985-1065`): voller Akzent-Button; ohne Abo mit "PRO"-Badge, öffnet Paywall.
  4. Nährwerte (`:420-444`), nur wenn `nutrition.hasData`: `NutritionInfoWidget(expanded)`, darunter "Ins Tagebuch eintragen" nur wenn Kalorien-Modul an.
  5. Karte "Über" (`:446-482`): Beschreibung, darunter `LargeStarRating` (Schnitt 48 pt, "Bewerte dieses Rezept", 5 Sterne 32 pt).
  6. Karte "Zutaten" (`:487-635`): Kopf mit Schalter "Angepasst/Original zutaten" (nur mit Diät-Profil), Zeilen mit Punkt oder Tausch-Icon, ersetzte Zutat fett + "(statt X)" durchgestrichen, Gründe als 10-pt-Chips; unten voller Button "Zur Einkaufsliste hinzufügen".
  7. `RecipeOffersCard` (`:641-643`), erscheint nachträglich, wenn Treffer da sind.
  8. Karte "Anleitung" (`:646-704`): nummerierte graue Kreise 28 pt + Text.
  9. Quellen-Fußzeile nur bei importierten Rezepten (`:707-710`, `:721-787`): "Quelle: Wikibooks Cookbook · CC BY-SA 4.0", öffnet externen Browser.
  10. Leerraum 100 pt + Safe Area für die schwebende Tab-Leiste (`:713-715`).
- **Komponenten:** SliverAppBar, FlexibleSpaceBar, AdaptiveGlass (3 Platform Views), `_QuickInfoItem`, Material `ElevatedButton`, `AdaptiveSwitch`, `LargeStarRating`, `NutritionInfoWidget`, `AppOutlineButton`, `RecipeOffersCard`, `AuthorAvatar`, Material `SnackBar`, Material `AlertDialog`.
- **Zustände:**
  - Laden ohne `initialRecipe`: leerer `Scaffold` mit `AppBar` und `CupertinoActivityIndicator` (`:145-150`). Mit `initialRecipe`: sofort Inhalt, stiller Hintergrund-Refresh (`:67-72`).
  - Fehler: Text "Rezept nicht gefunden" mittig (`:152-157`) plus roter Snackbar mit "Erneut versuchen" (`:102-114`). Kein Fehlerbild, kein Retry auf der Seite selbst.
  - Offline: keine eigene Behandlung; fällt in den Fehlerzustand bzw. zeigt gecachte `initialRecipe`.
  - Leer: Beschreibung leer bei allen selbst erstellten Rezepten (Editor hat kein Beschreibungsfeld) → Karte "Über" nur mit Überschrift und Bewertung.
  - Pro gesperrt: nur Kochmodus (`isSubscribedProvider`, `:986`). Badge "PRO" im Button, Tipp öffnet `showSubscriptionSheet`.
  - Modul aus: Kalorien-Modul steuert "Ins Tagebuch" (`:428`). Angebote haben **keinen** Modul-Schalter, nur die PLZ-Bedingung.
  - Kein Bild: `errorWidget` mit `Icons.restaurant` 80 pt.
- **Aktionen und Gesten:** Zurück (Pop oder `go('/home')`), Merken/Entmerken mit Snackbar, Teilen (System-Share), Bearbeiten (`push('/recipes/add', extra: {recipeId})`, lädt bei `true` still neu), Löschen (Bestätigungsdialog → Spinner → `go('/recipes')`), Portionen-Dialog, Bewerten (optimistisch, Rollback bei Fehler), Autor öffnen, Ersatz-Schalter, Zur Einkaufsliste, Kochen starten, Ins Tagebuch, Quelle öffnen. Keine Wischgesten außer Scroll und iOS-Zurückwischen.
- **Datenquellen:** `RecipeService()` direkt instanziiert (`:58`): `getRecipeById`, `trackRecipeView` (bei jedem Öffnen), `rateRecipe`, `deleteRecipe`, `getShareText`. Provider: `currentUserProvider`, `isRecipeSavedProvider`, `savedRecipesProvider`, `calorieTrackingEnabledProvider`, `recipeOffersProvider`, `isSubscribedProvider`, `refreshRecipeData(ref)`. Services: `IngredientSubstitutionService` (bei jedem Build).
- **Wichtigste sichtbare Texte (DE):** "Min. gesamt", "Portionen", "tippen zum Ändern", "Aufrufe", "Kochen starten", "PRO", "Über", "Bewerte dieses Rezept", "Zutaten", "Angepasst zutaten"/"Original zutaten", "statt {name}", "Zur Einkaufsliste hinzufügen", "Diese Woche im Angebot", "Anleitung", "Quelle: …", "Portionen anpassen", "Fertig", "Rezept löschen?", "Rezept gespeichert"/"entfernt" (Snackbar), "✅ Bewertung gespeichert".

### 2.2 Portionen-Dialog (Detail)

- **Datei:** `recipe_detail_screen.dart:800-828`. Einstieg: Tipp auf Portionen-Spalte.
- **Hauptfrage:** "Für wie viele koche ich?"
- **Aufbau:** Material `AlertDialog` mit Titel "Portionen anpassen", `ServingsStepper` (Zahl 32 pt, Buttons 30x30), Button "Fertig". Änderungen wirken sofort im Hintergrund (Zutaten skaliert).
- **Zustände:** Grenzen 1 bis 20 (Stepper-Default).

### 2.3 Lösch-Dialog (Detail, eigenes Rezept)

- **Datei:** `recipe_detail_screen.dart:880-923`. Material `AlertDialog`, "Abbrechen"/"Löschen" (rot). Danach ganzer Screen als Spinner, dann `context.go('/recipes')` und Snackbar. Kein Rückgängig.

### 2.4 Zutaten auf Liste (`SelectListBottomSheet`)

- **Datei:** `widgets/select_list_bottom_sheet.dart`, geöffnet aus `recipe_detail_screen.dart:938-983`. Trotz Name **kein Bottom Sheet**, sondern ein zentrierter `showDialog` (88 % Breite, max. 75 % Höhe, Radius 14).
- **Hauptfrage:** "Auf welche Liste, wie viele Portionen?"
- **Aufbau Schritt A (Liste wählen):** Kopf "Zur Einkaufsliste hinzufügen" + Schließen (30x30); Zeile Portionen mit Stepper; Schalter "Angepasste Zutaten" (nur wenn Ersatz existiert); Liste der Einkaufslisten (Einkaufswagen-Icon im blau getönten Quadrat, Name, Chevron).
- **Aufbau Schritt B (Bestätigen):** Kopf mit Zurück-Chevron + Listenname; Zusammenfassung "12 Zutaten · 4 Portionen" mit Chips "3 im Angebot" (grün) und "2 angepasst" (orange); Zutatenliste max. 220 pt hoch, scrollbar; blauer Button "Hinzufügen 12 Zutaten" bzw. "Füge 3 von 12 hinzu…" mit Spinner.
- **Zustände:** Listen laden (Spinner), Fehler (nur "Fehler" rot), keine Listen ("Noch keine Listen", keine Aktion zum Anlegen), Hinzufügen läuft (Sheet gesperrt per `PopScope`), Ergebnis: Erfolgs-HUD 120x120 "Hinzugefügt" (1,5 s), Teil-Erfolg orange Snackbar mit "Ansehen", Totalausfall rote Snackbar.
- **Aktionen:** Liste wählen, zurück, Portionen ändern, Ersatz an/aus, Hinzufügen. Haptik bei Listenauswahl (selectionClick) und Hinzufügen (mediumImpact).
- **Datenquellen:** `userListsProvider`, `ItemRepository().addItem` (sequentiell, mit Angebotspreis/Händler/"statt"-Preis je Zutat, Zusammenführen gleicher Artikel im Repository), danach `invalidate(itemsNotifierProvider(listId))`, `invalidate(listsNotifierProvider)`.
- **Texte:** "Zur Einkaufsliste hinzufügen", "Portionen", "Angepasste Zutaten", "Noch keine Listen", "{n} im Angebot", "{n} angepasst", "Hinzufügen", "Füge {current} von {total} hinzu…", "Hinzugefügt", "{added} von {total} hinzugefügt …", "Ansehen".

### 2.5 Angebotskarte (`RecipeOffersCard`)

- **Datei:** `widgets/recipe_offers_card.dart`. Eingebettet im Detail unter den Zutaten.
- **Hauptfrage:** "Welche Zutaten sind gerade billiger?"
- **Aufbau:** Kopf (Icon + "Diese Woche im Angebot"), Unterzeile "{count} von {total} Zutaten sind bei dir im Angebot", optional "Spare bis zu {x} € gegenüber Normalpreisen" (ab 0,50 €), dann je Treffer: Produktfoto 38x38 vom marktguru-CDN, Zutatenname, "Produkt · Händler · Packungsgröße", ggf. "Ähnliches Produkt", rechts "-23 %"-Chip, Preis in Serifenschrift, "statt 2,49 €", Grundpreis.
- **Zustände:** Laden, Fehler, keine echte PLZ, keine Treffer → `SizedBox.shrink()` (Karte taucht später auf und verschiebt den Inhalt darunter). Abgelaufene Angebote werden im Provider gefiltert.
- **Aktionen:** keine (Zeilen sind nicht tippbar).
- **Datenquellen:** `recipeOffersProvider(RecipeOffersRequest)` → `effectiveZipProvider` → `RecipeOfferService.getOffers` → `OfferPriceService.trySearchOffers`.

### 2.6 Kochmodus (`CookingModeScreen`)

- **Datei:** `cooking_mode_screen.dart`. Einstieg nur aus dem Detail, `Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(fullscreenDialog: true))` (`recipe_detail_screen.dart:994-1002`); keine GoRouter-Route, kein Deep Link. Bekommt `recipe` und `servings`.
- **Hauptfrage:** "Was mache ich jetzt gerade?"
- **Aufbau:**
  1. Kopf (`:381-445`): Schließen-Kreis 44 pt, Rezeptname 16 pt einzeilig + "Zutaten" bzw. "Schritt 3 von 7", rechts `StepProgressRing`. Harte Linie unten.
  2. Timer-Leiste (`:447-521`), sichtbar wenn Timer läuft oder pausiert: Icon in getöntem Kreis, Restzeit 32 pt tabellarische Ziffern, Pause/Weiter (44 pt), Abbrechen (rot, 44 pt).
  3. `PageView` ohne Wischen (`NeverScrollableScrollPhysics`, `:361`).
     - Seite 0 "Zutaten sammeln" (`:523-724`): großes Icon im grünen Verlaufskreis 80 pt, Titel in Serifenschrift 24 pt, Untertitel, Portionen-Kapsel (tippbar), Karte mit "Alle auswählen" und Zutatenzeilen mit Checkbox 22 pt (grün, durchgestrichen wenn abgehakt).
     - Seiten 1..n (`:726-822`): Schrittnummer im Verlaufskreis 72 pt mit Schatten, Karte mit Anleitungstext 18 pt zentriert, darunter "Timer {n} Min. starten", wenn im Text "x Minuten/min" erkannt wird.
  4. Fußleiste (`:824-929`): "Zurück" (Outline) und "Weiter"/"Fertig" (voll, Akzent bzw. grün), je 48 pt hoch, Text per `FittedBox` verkleinert.
- **Sheets/Dialoge im Kochmodus:** Portionen-Sheet mit Raster 1,2,3,4,5,6,8,10,12 (64x64-Kacheln, `:953-1035`); "Timer fertig"-Dialog (`:229-286`, nicht wegtippbar); "Kochmodus verlassen?"-Dialog (`:294-342`), erscheint bei jedem Schließen, auch auf Seite 0.
- **Zustände:** kein Laden/Fehler (Daten kommen vom Detail). Pro-Sperre liegt vor dem Einstieg. Timer: läuft, pausiert, fertig. Hintergrund: Restzeit aus Wanduhr berechnet, lokale Benachrichtigung (`NotificationService`, ID 700100) feuert am Ende.
- **Aktionen und Gesten:** Tippen auf Zutaten (Haptik selectionClick), Alle auswählen (mediumImpact), Weiter/Zurück, Timer starten/pausieren/fortsetzen/abbrechen (Haptik), Portionen ändern (setzt Häkchen zurück), Schließen mit Rückfrage. Kein Wischen zwischen Schritten, keine Sprache, kein Zurückwischen (Fullscreen-Dialog).
- **Datenquellen:** nur Parameter; `WakelockPlus.enable/disable`, `NotificationService.scheduleNotification/cancel`, `RecipeEditorPalette`.
- **Texte:** "Zutaten", "Schritt {current} von {total}", "Zutaten sammeln", "Portion/Portionen", "Alle auswählen"/"Alle abwählen", "Timer {minutes} Min. starten", "Timer abgelaufen", "Die Zeit ist um", "Kochmodus verlassen?", "Dein Fortschritt wird nicht gespeichert", "Zurück", "Weiter", "Fertig".

### 2.7 Rezept-Editor (`MultiStepRecipeScreen`)

- **Datei:** `multi_step_recipe_screen.dart`. Route `/recipes/add` (im Rezept-Tab, Tab-Leiste sichtbar), `extra: {draftId}` oder `{recipeId}` (`app_router.dart:189-200`). Einstiege: Plus auf dem Rezept-Tab (`recipes_screen.dart:272`), "Meine Rezepte" (`my_recipes_screen.dart:38, 73, 93`), Entwürfe (`recipe_drafts_screen.dart:153`), Bearbeiten im Detail.
- **Hauptfrage:** je Schritt eine: "Wie heißt es und wie sieht es aus?", "Wie lange und für wie viele?", "Was kommt rein?", "Wie geht es?"
- **Aufbau:** Kopf (Schließen 44 pt mit Schatten, Titel "Rezept hinzufügen"/"Rezept bearbeiten" + Schrittname, `StepProgressRing`), `PageView` ohne Wischen, schwebende Fußleiste "Zurück" / "Weiter" bzw. "Veröffentlichen" 52 pt hoch, absichtlich 60 pt über dem unteren Safe-Bereich positioniert (über der Tab-Leiste, `:307-312`). Jede Seite (`_buildStepPage`, `:380-431`): Icon im getönten Kreis 80 pt, Titel 28 pt fett, Untertitel 16 pt, Karte.
  - Schritt 1: Fotofläche 180 pt (nur Galerie), Feld "Rezeptname".
  - Schritt 2: drei Zeilen mit Icon im getönten Quadrat: Vorbereitung (Min.), Kochzeit (Min.), Portionen; Zahlenfelder 50 pt breit. Portionen vorbelegt mit 4.
  - Schritt 3: Zeilen Name (flex 3) / Menge (50 pt) / Einheit (70 pt) / Entfernen-x; "Zutat hinzufügen".
  - Schritt 4: nummerierte Kreise 32 pt + zweizeiliges Textfeld; "Schritt hinzufügen".
- **Zustände:** Laden beim Öffnen von Entwurf/Rezept (Vollbild-Spinner, `:273-278`); Fehler beim Laden (Snackbar, leeres Formular bleibt); Weiter gesperrt, solange Pflichtfelder fehlen (`_canProceed`, `:215-231`, Foto ist Pflicht); Veröffentlichen läuft (Spinner im Button); Validierungsfehler als rote Snackbar.
- **Dialog "Entwurf speichern?"** (`:827-868`): beim Schließen mit Daten; "Verwerfen" (rot) oder "Entwurf speichern" → `context.go('/recipes/drafts')`.
- **Aktionen:** Foto wählen, Felder, Zeilen hinzufügen/entfernen (lightImpact), Weiter/Zurück, Schließen, Entwurf speichern, Veröffentlichen (heavyImpact bei Erfolg). Nach Veröffentlichen: neues Rezept → `pushReplacement('/recipes/<id>')`; Bearbeiten → `pop(true)`.
- **Datenquellen:** `RecipeService()` (`getRecipeById`, `uploadRecipeImage` in Bucket `recipe-images`, `createRecipe`, `updateRecipe`), `RecipeDraftService()`, `RecipeDraftImages`, `ImagePicker`, `refreshRecipeData(ref)`.
- **Texte:** "Rezept hinzufügen", "Foto & Name", "Zeiten", "Zutaten", "Anleitung", "Tippen, um ein Foto hinzuzufügen", "Rezeptname", "Vorbereitungszeit", "Kochzeit", "Portionen", "Zutat hinzufügen", "Schritt hinzufügen", "Weiter", "Veröffentlichen", "Entwurf speichern?", "Du kannst später weitermachen", "Verwerfen", "Rezept veröffentlicht: …".

### 2.8 Unsichtbare Logik

- `scoreForYouRecipe` (`recipe_personalization.dart`) sortiert "Für dich" auf dem Rezept-Tab: Diät-Labels +2, Allergen-Treffer −5, Bewertung, Aufrufe, Anzahl Bewertungen, Frische, `app_priorities`.
- `RecipeFeaturesService.getRecipeOfTheWeek` für den Hero des Rezept-Tabs.

---

## 3. Design-Probleme heute

### 3.1 Abweichungen von den Apple-Regeln

- **Glas auf Inhalt und gemischte Stile in der Toolbar:** Zurück, Merken, Teilen sind `AdaptiveGlass` (`recipe_detail_screen.dart:184-198, 321-347, 353-360`), Löschen und Bearbeiten daneben sind volle Farbkreise ohne Glas (`:289-310`). Gemerkt-Zustand ersetzt Glas durch weißen Vollkreis (`:323-327`). Nach dem Einklappen der Hero-Leiste sitzen die Glasknöpfe auf hellem `scaffoldBg`, Titel fehlt (siehe Wayfinding).
- **Wayfinding:** Der Titel lebt nur im `FlexibleSpaceBar.background` (`:234-282`). Eingeklappt zeigt die Leiste keinen Rezeptnamen; man weiß nach dem Scrollen nicht mehr, wo man ist. Kochmodus und Editor sind Material-Vollbild-Dialoge ohne Zurückwischen.
- **Destruktive Aktion prominent:** roter Löschen-Kreis direkt in der Toolbar (`:289-299`). Apple: Löschen ins Menü ("…"), Bestätigung als Action Sheet; Bearbeiten als Textbutton.
- **Material statt iOS:** Material `AlertDialog` für Portionen (`:801-827`), Löschen (`:881-901`), Timer fertig (`cooking_mode_screen.dart:230-285`), Verlassen (`:295-341`), Entwurf (`multi_step_recipe_screen.dart:835-867`); Material `SnackBar` mit roter Fläche (`recipe_detail_screen.dart:102-114`); `ElevatedButton`/`OutlinedButton` überall; Kochmodus als `MaterialPageRoute` (`:995`).
- **Bestätigung statt Rückgängig:** "Kochmodus verlassen?" erscheint immer, selbst auf der Zutatenseite (`cooking_mode_screen.dart:392`). Merken zeigt bei jedem Tipp eine Snackbar (`recipe_detail_screen.dart:337-343`) statt nur Zustandswechsel mit Haptik.
- **Zwei Primäraktionen gleichen Gewichts:** "Kochen starten" (`:985-1019`) und "Zur Einkaufsliste hinzufügen" (`:618-631`) sind beide volle Akzentbuttons; Kochen steht vor dem Inhalt, obwohl es Pro ist. Die Hauptfrage des Screens wird nicht beantwortet, welche Aktion zählt.
- **Bewertung dreifach:** Kennzahlen-Leiste (`:393-398`), 48-pt-Zahl in `LargeStarRating` (`star_rating_widget.dart:235-240`), Sterne-Eingabe. Dazu Aufrufzahl als Vanity-Kennzahl (`recipe_detail_screen.dart:400-405`).
- **Harte Linien und Rahmen statt Tonstufen:** Karten mit Radius 6 und Rahmen (`:372-373, 452-454, 492-494, 650-653`, `recipe_offers_card.dart:37-38`), senkrechte 1-pt-Trenner (`recipe_detail_screen.dart:384, 392, 399`), Kopf-Unterlinie und Fußleisten-Oberlinie im Kochmodus (`cooking_mode_screen.dart:386, 835`). Radien 6/10/12/14/16/20 durcheinander, nicht konzentrisch.
- **Ikonografie:** Material `Icons.*` statt SF Symbols (20 im Detail, 13 im Kochmodus, 13 im Editor); das Add-to-List-Sheet mischt Material und Cupertino-Icons. Icons in getönten Kreisen/Quadraten: Editor-Seitenkopf (`multi_step_recipe_screen.dart:392-401`), Zeitzeilen (`:572-579`), Kochmodus-Kopf Zutaten (`cooking_mode_screen.dart:536-555`), Timer-Icon (`:463-474`), Listen-Icon im Sheet (`select_list_bottom_sheet.dart:406-416`).
- **Farbe nicht sparsam, nicht einheitlich:** Detail Akzent Terrakotta `recipeAccent #C0502A`, Sheet `systemBlue`-Button und blauer Stepper (`select_list_bottom_sheet.dart:601-604`, `servings_stepper.dart:76-86`), Ersatz-Schalter grün (`recipe_detail_screen.dart:522`) im Detail, orange im Sheet (`select_list_bottom_sheet.dart:349`), Stern-Gold hart (`recipe_detail_screen.dart:397`), Makro-Chips Blau/Gold/Terrakotta (`nutrition_info_widget.dart:79-95`, Regenbogen), Kalorien-Icon `#FF6B6B`.
- **Nicht adaptive Farben:** `scaffoldBg #262626/#FBFBFB` und `textSecondary #6B6B6B/#9CA3AF` fest im Code (`recipe_detail_screen.dart:160-164`, `recipe_offers_card.dart:28-29, 99-100`); Kochmodus/Editor nutzen eine ganz andere Palette (dunkelgrün `#0A120A`, creme `#F7F3EC`, `app_colors.dart:115-123`). Detail, Kochmodus und Editor sehen wie drei Apps aus.
- **Blasser Fließtext:** Beschreibung mit 80 % Deckkraft (`recipe_detail_screen.dart:469`), Labels in `_QuickInfoItem` 60 % (`:1113`), Weiß auf `#9CA3AF` in den Schrittkreisen (`:672-686`, Kontrast etwa 2,5:1).
- **Bewegung:** feste Dauern statt Federn: Seitenwechsel 300 ms `easeInOut` (`cooking_mode_screen.dart:92-96`, `multi_step_recipe_screen.dart:203-207`), Checkbox 200 ms (`cooking_mode_screen.dart:673`), Ring 250 ms. Kein Reduce-Motion-Zweig in keiner der Dateien. Keine Herkunft am Auslöser (Dialoge erscheinen mittig).
- **Haptik inflationär:** mediumImpact für "Alle auswählen" und Portionen-Sheet öffnen (`cooking_mode_screen.dart:124, 138`), lightImpact für jede Zeile im Editor; dagegen fehlt Erfolgs-Haptik beim Hinzufügen zur Liste (nur beim Tippen auf den Button, `select_list_bottom_sheet.dart:608`).
- **VoiceOver:** keine `Semantics`, `tooltip` oder `semanticLabel` in allen fünf UI-Dateien. Icon-Buttons (Zurück, Merken, Teilen, Löschen, Bearbeiten, Schließen, Timer-Steuerung, Entfernen-x) werden nur als "Taste" angesagt. Abhak-Zeilen im Kochmodus sind `GestureDetector` ohne Zustand "ausgewählt".
- **Reduce Transparency:** `AdaptiveGlass` prüft `MediaQuery.highContrastOf` (Erhöhter Kontrast), nicht Transparenz reduzieren (`liquid_glass_container.dart:147-148`).
- **Touch-Ziele unter 44 pt:** Stepper-Buttons 30x30 (`servings_stepper.dart:73-75`), Sheet-Schließen/Zurück 30x30 (`select_list_bottom_sheet.dart:249, 277-281`), Entfernen-x 20-pt-Icon ohne Fläche (`multi_step_recipe_screen.dart:663-672, 728-739`), Portionen-Spalte nur so groß wie ihr Text (`recipe_detail_screen.dart:1088`), Autor-Zeile 22 pt hoch (`:252-279`).
- **Schrift:** Satoshi statt SF Pro (`app_text_styles.dart:5-6`, Theme `app_theme.dart:31`), dazu Serifen aus Paper (siehe 3.3). Viele Größen fest in pt statt Textstilen.

### 3.2 Feste Maße, die bei großer Schrift oder 320 pt Breite brechen

Die App klemmt die Schriftskalierung nirgends (kein `textScaler` in `app.dart`/`main.dart`), große Dynamic-Type-Stufen kommen also voll an.

- Kennzahlen-Leiste: `Row` mit 4 Spalten + 3 Trennern ohne `Expanded`/`Flexible` (`recipe_detail_screen.dart:375-406`). Bei 320 pt und großer Schrift Überlauf (gelb-schwarzer Streifen). Werte 18 pt, Labels 11 pt, "tippen zum Ändern" 9 pt (`:1096-1122`), Trenner fest 40 pt hoch.
- Hero-Titel 24 pt ohne `maxLines` (`:241-249`) in 280 pt fester Höhe (`:175`): langer Name + Autor + große Schrift schiebt den Text unter die Toolbar-Buttons.
- Zutaten-Kopf: `Row(Icon, Titel, Spacer, Row(Text, Switch))` ohne `Expanded` am Text (`:499-531`) → Überlauf bei 320 pt bzw. großer Schrift.
- Ersatz-Gründe 10 pt (`:598-601`), Quellenzeile 12 pt (`:762-764`), Autor 13 pt (`:273`).
- Add-to-List-Dialog: Breite 88 % fest (`:957`), Zutatenliste max. 220 pt (`select_list_bottom_sheet.dart:532`), Zusammenfassungszeile `Row` mit Text ohne `Expanded` + zwei Chips (`:475-525`) → Überlauf bei 320 pt. Erfolgs-HUD fest 120x120 mit Text (`:79-100`).
- Angebotskarte: 13,5 / 11 / 9,5 / 10 / 9,5 pt (`recipe_offers_card.dart:141, 151, 166, 196, 226`), rechte Preisspalte ohne Breitenbegrenzung neben 38-pt-Bild.
- Kochmodus: Fußleisten-Buttons fest 48 pt hoch mit `FittedBox(scaleDown)` (`cooking_mode_screen.dart:847-923`) → Text wird bei großer Schrift kleiner statt größer. Timer-Ziffern 32 pt fest in einer `Row` mit zwei 44-pt-Knöpfen (`:461-518`). Rezeptname im Kopf einzeilig 16 pt (`:410-420`). Schritttext 18 pt fest und zentriert (`:778-787`). Ring-Text 10 pt (`step_progress_ring.dart:49-55`). Portionen-Kacheln 64x64 mit 20 pt (`:1005-1023`).
- Editor: Zahlenfelder 50 pt breit bei 20 pt Schrift (`multi_step_recipe_screen.dart:589-601`) → "120" Minuten passt bei großer Schrift nicht. Zutatenzeile Menge 50 pt, Einheit 70 pt fest (`:644-661`) → bei 320 pt bleiben für den Namen wenige Zeichen. Schritttexte `maxLines: 2` (`:716`). Fotofläche 180 pt fest (`:465`). Fußleiste fest 52 pt (`:777, 798`) und fest 60 pt über Safe Area (`:310`), plus fester Platzhalter 100 pt (`:302`); bei offener Tastatur bleibt das Raster aus Leiste + Abstand bestehen.

### 3.3 Paper-Reste (Kicker, Serifen, Creme/Terrakotta)

- Serifen: `PaperTextStyles.serif(24)` für "Zutaten sammeln" (`cooking_mode_screen.dart:562`), Preis in der Angebotskarte `PaperTextStyles.serif(15)` (`recipe_offers_card.dart:205`).
- Creme/Terrakotta: `PaperColors.cream`/`creamInk` als Bild-Platzhalter (`recipe_offers_card.dart:122, 126`), `PaperColors.surface`/`hairline`/`ink` im Sheet (`select_list_bottom_sheet.dart:177-179, 271`), "Cookbook Evening"-Palette creme `#F7F3EC`/`#FFFDF8`/`#E2D9C8` mit Terrakotta `#C0502A` (`app_colors.dart:104-126`, genutzt über `recipe_editor_palette.dart`). Terrakotta ist zugleich Akzent im Detail (`recipeAccentColor`).
- Imports von `paper_colors.dart` in `cooking_mode_screen.dart:7`, `recipe_offers_card.dart:5`, `select_list_bottom_sheet.dart:2`.
- Kicker in Großbuchstaben: in diesen Dateien keine gefunden. "PRO"-Badge 10 pt in Großbuchstaben (`recipe_detail_screen.dart:1052-1059`).
- `AppColors.recipeGreenColor` liefert Terrakotta statt Grün (`app_colors.dart:177-180`), Altlast der Paper-Umstellung.

### 3.4 Anti-Slop

- Reihe gleichartiger Karten mit Icon + Überschrift (Über, Zutaten, Angebote, Anleitung), alle Radius 6 mit Rahmen.
- Vanity-Zahl "Aufrufe" in der Kennzahlen-Leiste; Bewertung mehrfach.
- Verlaufskreise mit Schatten für Schrittnummern (`cooking_mode_screen.dart:738-766`), Verlaufsfläche der Timer-Leiste (`:452-459`).
- Emojis in Datenstrings: "🌱 Vegan", "🥗 Vegetarisch" (`ingredient_substitution_service.dart:36-39, 185-187`), Allergie-Emojis (`dietary_preference.dart:22-46`), "✅" in der Bewertungs-Snackbar (`recipe_detail_screen.dart:857`), "🍳" im Share-Betreff (`:930`).

---

## 4. Bugs, Risiken und Performance-Probleme

### 4.1 Sicherheit und Korrektheit (Allergien, Diät)

1. **Teilstring-Erkennung erzeugt Fehlalarme.** `'ei'` in der Tierprodukt-Liste (`ingredient_substitution_service.dart:131`) trifft "Reis", "Weizen", "Weißwein", "Eis"; `'ham'` (`:138, 158`) trifft "Champignons"; `'milch'`/`'butter'` (`:127`) treffen "Kokosmilch", "Hafermilch", "Erdnussbutter". Folge für Veganer: "Leinsamen-Ei … statt Reis" (Ersatz über Schlüssel `'Ei'`, `dietary_preference.dart:525-530`). Die Allergie `eggs` mit Schlüsselwort "Ei" (`dietary_preference.dart:24`) markiert ebenfalls Reis.
2. **Ersatz wird nicht gegen die eigenen Allergien geprüft.** Filter ist `avoidsNeededAllergies || suitableForDiet` (`dietary_preference.dart:536-548`). Vegetarier mit Soja-Allergie bekommt für "Hähnchen" als besten Ersatz "Tofu" (erster Eintrag), mit Gluten-Allergie "Seitan"; "Käse" → "Hefeflocken" trotz Hefe-Allergie; "Semmelbrösel" → "Gemahlene Mandeln" trotz Nuss-Allergie. Apple-Prinzip Responsibility verletzt.
3. **Allergene nur deutsch.** Schlüsselwörter der `AllergyType`s sind deutsch (`dietary_preference.dart:21-46`); englische Rezepte ("milk", "egg", "peanut") lösen keine Allergiewarnung aus. Tierprodukt-Listen sind zweisprachig, Allergien nicht.
4. **Kochmodus und Avo ignorieren den Ersatz.** Kochmodus bekommt das Originalrezept (`recipe_detail_screen.dart:997-1000`, `cooking_mode_screen.dart:51-60`): der Allergiker sieht im Detail "Hafermilch statt Milch", im Kochmodus wieder "Milch". Avos Tool `add_recipe_to_list` skaliert, ersetzt aber nicht (`avo_assistant_service.dart:509-517`).
5. **"Für dich" vergleicht Enum-Namen mit Zutaten.** `allergies` sind Werte wie `milk`, `eggs`, `nuts` (`recipe_user_diet.dart:11-14`); `scoreForYouRecipe` sucht diese englischen Kürzel als Teilstring in meist deutschen Zutaten (`recipe_personalization.dart:35-41`) → greift praktisch nie, und auch bei Treffer nur −5 statt Ausblenden.
6. **Doppelte Ersatz-Einträge:** exakter Treffer und Teilstring-Treffer werden beide angehängt (`dietary_preference.dart:525-534`).

### 4.2 Funktionale Bugs

7. **Editor: Mengen-/Einheitsänderung zählt nicht als Änderung.** `_hasChanges` vergleicht nur Zutatennamen (`multi_step_recipe_screen.dart:257-266`). Wer im Bearbeiten-Modus nur "200 g" auf "300 g" ändert und schließt, verliert die Änderung ohne Rückfrage (`:829-832`).
8. **Editor: "Entwurf speichern" beim Bearbeiten erzeugt Duplikate.** Der Entwurf kennt keine `recipeId` (`:902-920`); Veröffentlichen aus dem Entwurf ruft `createRecipe` (`:1000-1014`) → zweites Rezept. Das vorhandene Bild geht verloren, weil nur `_selectedImage` gesichert wird (`:898-900`), und Schritt 1 lässt ohne neues Foto kein Weiter zu (`:218-219`). Danach `context.go('/recipes/drafts')` (`:924`) wirft auch das offene Detail aus dem Stapel.
9. **Menge ist Pflicht.** Leere Menge → `_parseAmount` liefert null → Fehler "Ungültige Menge" (`:954-957`). "Salz nach Geschmack" ist nicht eingebbar; Workaround "0" erzeugt im Detail "0  Salz" (`recipe.dart` `displayText`, doppeltes Leerzeichen bei leerer Einheit).
10. **Unformatierte Kommazahlen:** Bestätigungsliste druckt Rohwerte (`select_list_bottom_sheet.dart:573`) → "133.33333333333334 g Mehl"; diese Rohmenge wird auch so in die Liste geschrieben (`:663`). `displayText` zeigt "1.5" mit Punkt statt deutschem Komma, keine Brüche, keine sinnvolle Rundung für "Stück" (2,5 Eier).
11. **Portionen-Raster im Kochmodus passt nicht zum Detail.** Detail erlaubt 1 bis 20, Kochmodus bietet nur 1-6, 8, 10, 12 (`cooking_mode_screen.dart:999`); bei 7 ist nichts markiert. Portionswechsel löscht alle Häkchen (`:151`).
12. **Timer-Erkennung schmal:** nur "x Minuten/min" (`:931-950`); "1 Stunde", "90 Sekunden", "1,5 Std." nicht; bei "10-15 Minuten" greift das erste Muster auf "15". Nur ein Timer gleichzeitig; Timer läuft über Schritte weiter, wird aber nur auf seinem Schritt nicht neu angeboten.
13. **Nährwerte ohne Bezug:** `NutritionInfoWidget` bekommt keine Portionen (`recipe_detail_screen.dart:427`), zeigt pro Portion ohne Hinweis "pro Portion", während Zutaten auf `_servings` skaliert sind.
14. **Bewertung des eigenen Rezepts möglich:** `LargeStarRating` ohne `isOwnRecipe`-Prüfung (`:473-478`).
15. **Leere "Über"-Karte:** Editor speichert immer `description: ''` (`multi_step_recipe_screen.dart:1004`), Detail rendert die Karte trotzdem (`:446-482`).
16. **Sprachfehler:** "Angepasst zutaten"/"Original zutaten" durch Zusammenkleben + `toLowerCase()` (`recipe_detail_screen.dart:510-512`). Share-Text nur Englisch mit Emojis und fester Domain `https://shoplyai.app/recipe/<id>` (`recipe_service.dart:442-448`). `RecipeCompatibility.badgeText` hart deutsch (`ingredient_substitution_service.dart:240-248`). Rezepte haben kein Übersetzungsfeld im Modell (`recipe.dart`), werden immer in Originalsprache gezeigt.
17. **Leere Listen = Sackgasse:** "Noch keine Listen" ohne "Liste anlegen" (`select_list_bottom_sheet.dart:363-380`).
18. **Löschen ohne Rückweg:** Vollbild-Spinner (`recipe_detail_screen.dart:905`), dann `go('/recipes')` statt Pop (`:914`), kein Rückgängig. Hochgeladene Bilder werden nie aus Storage gelöscht (kein `remove` in `recipe_service.dart`; neues Bild bekommt neuen Dateinamen, `multi_step_recipe_screen.dart:971-974`).
19. **Foto nur aus Galerie,** und `maxHeight: 1080` (`:872-877`) verkleinert Hochformat-Fotos auf ca. 810 px Breite, für ein 280-pt-Hero auf 3x-Displays zu wenig.

### 4.3 Datenschutz und Recht

20. **E-Mail als öffentlicher Autorname.** Ohne `display_name` setzt `createRecipe` `authorName = user.email` (`recipe_service.dart:218-231`); jedes Rezept ist öffentlich (kein Privat-Schalter im Editor, "Veröffentlichen" ist der einzige Abschluss).
21. **Angebote ohne Modul-/Kill-Switch:** weder `recipeOffersProvider` noch die Karte prüfen einen Schalter (`recipe_offers_provider.dart:33-46`). Laut Recherche nötig: Remote-Kill-Switch, spurlos ausblendbar.
22. **Implizit "günstigster Markt":** `pickBestOffer` nimmt das billigste Angebot über alle Händler (`recipe_offer_service.dart:126-143`). Die Karte mischt so Lidl, REWE, Aldi in einer Liste und summiert "Spare bis zu X €" über verschiedene Märkte (`recipe_offer_highlight.dart:144-146`, `recipe_offers_card.dart:63-74`). Widerspricht Plan 8 (nur der Markt der Liste) und der Recherche (keine eigene Ersparnisrechnung hervorheben).
23. **"statt"-Preis ohne "laut Händler"** (`recipe_offers_card.dart:213-221`, Schlüssel `instead_of_price`), Rabatt-Prozent selbst berechnet und hervorgehoben (`recipe_offer_highlight.dart:62-67`, Karte `:183-200`).
24. **Produktbilder per Hotlink vom marktguru-CDN** (`recipe_offers_card.dart:114`), laut Recherche nur mit Lizenz.
25. **Angebotspreise landen in der Liste:** beim Hinzufügen werden Preis, Händler, "statt"-Preis des billigsten Händlers an den Listeneintrag gehängt (`select_list_bottom_sheet.dart:657-671`), auch wenn die Liste für einen anderen Markt ist.

### 4.4 Performance und "nie sichtbares Laden"

26. **Drei native Platform Views über einem scrollenden Hero** (`AdaptiveGlass` → `UiKitView`, `liquid_glass_container.dart:60`): Zurück, Merken, Teilen im `SliverAppBar`. Platform Views zwingen Flutter in Hybrid-Composition; beim Stretch/Scroll auf iPhone 13 Pro ruckelanfällig.
27. **Sichtbares Laden an vielen Stellen:** Detail ohne `initialRecipe` Vollbild-Spinner (`recipe_detail_screen.dart:145-150`), nach Veröffentlichen immer so (`multi_step_recipe_screen.dart:1039`), Editor-Laden Spinner (`:273-278`), Löschen Spinner, Listenauswahl Spinner, Hinzufügen mit Fortschritt "Füge 3 von 12 hinzu…".
28. **Hinzufügen strikt sequentiell:** je Zutat ein `select` + `insert`/`update` auf Supabase (`select_list_bottom_sheet.dart:656-679`, `item_repository.dart:127-145`). Bei 12 Zutaten 24+ Roundtrips, der Dialog blockiert die ganze Zeit. Kein optimistisches Einfügen, kein Batch-Insert.
29. **Angebotskarte springt nachträglich ins Layout** (`recipe_offers_card.dart:21-24`): erscheint erst nach bis zu 10 API-Suchen (`recipe_offer_service.dart:79-97`) und schiebt die Anleitung nach unten, während der Nutzer liest.
30. **Ersatzberechnung bei jedem Build** inkl. `debugPrint` (`recipe_detail_screen.dart:165-167`, `ingredient_substitution_service.dart:68-69`): jede Portionsänderung, jedes Rebuild durch `ref.watch`.
31. **Angebotsbild ohne Cache und Größe:** `Image.network` statt `CachedNetworkImage` mit `memCacheWidth` (`recipe_offers_card.dart:114-129`).
32. **Rezept der Woche lädt alle Bewertungen:** `_getTopIdsByRatings(days: null)` holt die gesamte Tabelle `recipe_ratings` ohne Limit und aggregiert in Dart (`recipe_features_service.dart:63-94`).
33. **Entwürfe nur lokal:** `SharedPreferences`, ganze Liste wird bei jedem Speichern neu geschrieben (`recipe_draft_service.dart:41-55, 81-85`). Kein Abgleich zwischen Geräten; Fotos in `Documents/recipe_drafts`. Bei zwei Geräten mit demselben Konto (Owner und Jannis) sieht jeder nur seine Entwürfe.
34. **View-Zählung bei jedem Öffnen** (`recipe_detail_screen.dart:77`), auch beim eigenen Rezept und bei jedem Deep Link.
35. **Tab-Leiste überlagert Editor und Detail:** Beide liegen im Shell-Branch. Der Editor schiebt seine Fußleiste fest 60 pt hoch (`multi_step_recipe_screen.dart:310`), während die Tab-Leiste mit `MainScaffold.navScale` proportional skaliert (`main_scaffold.dart:212-213`) → auf kleinen Geräten (SE, 320 pt Zoom) Überlappung oder Lücke möglich.

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Routing:** `lib/routes/app_router.dart` (`/recipes/add` :189-200, `/recipes/:recipeId` :243-252, `/author/:authorId` :326, `/recipe/:recipeId` :343-352). `DeepLinkService` und der Share-Link `shoplyai.app/recipe/<id>`. Kochmodus ohne Route (Root-Navigator).
- **Shell/Navigation:** `main_scaffold.dart` (schwebende Tab-Leiste bleibt über Detail und Editor sichtbar, Fade-Fläche unten, Offline-Banner).
- **Listen-Bereich:** `ItemRepository.addItem` (Zusammenführen, Preise), `userListsProvider`, `itemsNotifierProvider`, `listsNotifierProvider`, Preissumme der Liste (`list_price_summary_bar.dart:272`, `pricingQuantity`). Ziel `/lists/:listId` aus der Teil-Erfolg-Snackbar.
- **Angebote/Sparen:** `OfferPriceService`, `effectiveZipProvider` (`price_comparison_provider.dart:23`), `RecipeOfferService` wird auch von `PersonalizedDealsService` (`personalized_deals_service.dart:51`) und Avo (`avo_assistant_service.dart:525`) genutzt.
- **Avo:** Tools `search_recipes`, `get_saved_recipes`, `get_recipe_nutrition`, `add_recipe_to_list` (`avo_assistant_service.dart:235-241`) mit eigener, paralleler Hinzufügen-Logik.
- **Kalorien-Modul:** `calorieTrackingEnabledProvider`, `showLogRecipeSheet` (`calories/widgets/log_recipe_sheet.dart`), `NutritionInfo`.
- **Pro:** `isSubscribedProvider` (zählt nur `SubscriptionStatus.subscribed`, `subscription_provider.dart:28-34`), `showSubscriptionSheet` (Material-Vollbild-Route, `subscription_screen.dart:504-511`).
- **Profil/Diät:** `currentUserProvider`, `UserDietX` (`recipe_user_diet.dart`), `dietary_preference.dart` (gemeinsam mit Diät-Einstellungen `/diet-preferences`).
- **Rezept-Tab:** `recipes_provider.dart` (`refreshRecipeData`), `saved_recipes_provider.dart`, `recipes_home_widgets.dart` (nutzt `IngredientSubstitutionService`), `recipes_home_data.dart` (nutzt `scoreForYouRecipe`), `recipe_drafts_screen.dart`, `my_recipes_screen.dart`, `recipe_author_page.dart`.
- **Geteilte Widgets:** `AdaptiveGlass`/`LiquidGlassContainer` (überall), `ServingsStepper` (Detail-Dialog + Sheet), `StepProgressRing` und `RecipeEditorPalette` (Editor + Kochmodus), `AuthorAvatar`, `LargeStarRating`/`StarRatingWidget`, `NutritionInfoWidget`, `AppOutlineButton` und `showAppBottomSheet` (`core/widgets/design_system.dart`).
- **Design-Tokens:** `AppColors.recipe*` (`app_colors.dart:104-180`), `PaperColors`/`PaperTextStyles` (`core/constants/paper_colors.dart`), `AppTextStyles` (Satoshi), `AppDimensions.borderRadiusSmall`.
- **Services:** `RecipeService` (`getRecipeById`, `trackRecipeView` → RPC `increment_recipe_view_count`, `rateRecipe`, `deleteRecipe`, `createRecipe` mit `autoLabelRecipe`, `updateRecipe`, `uploadRecipeImage` → Bucket `recipe-images`), `NotificationService`, `SupabaseService`.
- **Pakete:** `wakelock_plus`, `image_picker`, `share_plus`, `url_launcher`, `cached_network_image`, `adaptive_platform_ui` (`AdaptiveSwitch`), `go_router`, `flutter_riverpod`.
- **Strings:** `lib/core/localization/app_translations.dart` (EN ab Zeile ~100, DE ab ~1270). Schlüssel u. a. `recipe_min_total`, `portions`, `tap_to_adjust`, `views`, `start_cooking`, `about`, `ingredients`, `adapted`, `original`, `ingredient_instead_of`, `add_to_shopping_list`, `instructions`, `recipe_source_label`, `recipe_source_external`, `adjust_servings`, `rating_submitted`, `rating_updated`, `rating_save_failed`, `delete_recipe_title`, `delete_recipe_confirm`, `recipe_deleted`, `recipe_delete_failed`, `recipe_not_found`, `recipe_not_found_detail`, `recipe_load_failed`, `recipe_saved_toast`, `recipe_unsaved_toast`, `log_recipe_cta`, `recipe_offers_title`, `recipe_offers_subtitle`, `recipe_offers_save`, `instead_of_price`, `similar_product_match`, `on_offer_count`, `adapted_count`, `adapted_ingredients`, `adding_ingredients_progress`, `ingredients_added_partial`, `ingredients_add_failed`, `added`, `view_action`, `no_lists_yet`, alle `cooking_mode_*`, `recipe_step_*`, `recipe_add_photo_*`, `recipe_times_*`, `recipe_ingredients_subtitle`, `recipe_instructions_subtitle`, `save_draft_question`, `save_draft_question_desc`, `discard`, `save_draft`, `publish`, `recipe_published`, `invalid_numbers_error`, `invalid_amount_error`, `no_instructions_error`, `image_required_error`. Dazu hart codierte Texte in Services (Emojis, deutsche Badges, englischer Share-Text).
- **Funktionsliste weicht ab:** `docs/redesign/chatgpt-redesign-prompt.md` Abschnitt 3 nennt "Varianten" (Abwandlungen einreichen, abstimmen) und "folgen, Likes, Kommentare". Die Varianten-Logik (`recipe_variations_service.dart`), Folgen-Button und Kommentar-Modell wurden in Commit 38ce871 als nie importiert gelöscht. Einheitenumrechnung (`unit_conversion_service.dart`) ebenso. Diese Funktionen gibt es in der App nicht.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Rezeptdetail**
- Sofortanzeige mit dem schon geladenen Rezept (`initialRecipe`) und stiller Hintergrund-Refresh, der bei Fehler den Inhalt behält.
- Portionen skalieren alle Zutaten live; dieselbe Portionszahl geht in Kochmodus und Liste.
- Diät/Allergie-Ersatz mit Umschalter Original/Angepasst und sichtbarem Grund (aber korrigierte Logik, siehe 4.1), Ersatz auch im Kochmodus und bei Avo.
- Ein Tipp: alle Zutaten auf eine Liste, inklusive Portionen, Ersatz an/aus, Zusammenführen mit vorhandenen Einträgen (Repository-Merge nach Name + Einheit), Teil-Erfolg mit Namen der fehlgeschlagenen Zutaten.
- Merken (fremde Rezepte), Bearbeiten und Löschen (eigene), Teilen per Link, Autorenseite.
- Bewertung mit optimistischer Anzeige und Rollback.
- Nährwerte pro Portion und "Ins Tagebuch" nur bei aktivem Kalorien-Modul.
- Quellenangabe und Lizenz bei importierten Rezepten (Wikibooks CC BY-SA 4.0), Link nach außen. Pflicht wegen Lizenz.
- Angebote nur mit echter PLZ, nie mit Fallback-PLZ; abgelaufene Angebote ausblenden; "Ähnliches Produkt" kennzeichnen; Grundpreis zeigen. Künftig: Modul-Schalter, Remote-Kill-Switch, nur der Markt der Liste, "laut Händler".
- Fehler "nicht gefunden" vs. "Laden fehlgeschlagen" unterscheiden (Deep Link auf gelöschtes Rezept).
- Deep Link `/recipe/:id` ohne Shell.

**Kochmodus**
- Bildschirm bleibt an (Wakelock) und wird beim Verlassen wieder freigegeben.
- Erst Zutaten sammeln und abhaken, dann ein Schritt pro Ansicht mit "Schritt x von n".
- Portionen im Kochmodus änderbar.
- Timer aus dem Schritttext erkannt; Restzeit nach Wanduhr (korrekt im Hintergrund), lokale Benachrichtigung am Ende, Pause/Fortsetzen/Abbrechen, Benachrichtigung wird beim Abbrechen/Verlassen entfernt.
- Pro-Kennzeichnung bleibt möglich (heute Pro), muss aber für jedes Feature umschaltbar sein.

**Editor**
- Neu, aus Entwurf, Bearbeiten in einem Screen; Bearbeiten kehrt mit Ergebnis zum Detail zurück, das neu lädt.
- Entwürfe mit dauerhaft kopiertem Foto (nicht tmp), Entwurf wird nach Veröffentlichen samt Foto gelöscht.
- Mengen-Parser für "1", "1,5", "0.5", "1/2".
- Beim Bearbeiten bleibt die gespeicherte Beschreibung erhalten (`description: null`).
- Neue Rezepte werden automatisch gelabelt (`autoLabelRecipe`), damit Filter und "Für dich" funktionieren.
- Verwerfen-Schutz bei ungespeicherten Änderungen (korrigiert auf Mengen/Einheiten/Bild).

**Daten und Sonderfälle**
- `Recipe`-Felder: `labels`, `language`, `nutrition`, `sourceUrl`/`sourceName`, `authorAvatarUrl`, `userRating`, `viewCount`, `ratingCount`.
- Rezepte ohne Bild, ohne Beschreibung, ohne Nährwerte, mit 0 Zutaten-Menge, mit sehr vielen Zutaten (Angebotsprüfung auf 10 begrenzt), mit sehr langen Namen und Schritten.
- Grundzutaten (Salz, Pfeffer, Wasser) nie als Angebot zeigen.
- Gleiche Zutat mehrfach im Rezept (Angebote dedupliziert, Liste führt zusammen).
- Zwei Geräte mit demselben Konto: Entwürfe müssen künftig synchronisiert oder bewusst als gerätelokal gekennzeichnet werden.
