# Inventar: Kalorien und Gesundheit (Ist-Zustand)

Stand: Repo `main` (3e886d0), gelesen am 2026-11-07. Nur Bestandsaufnahme, kein Code geändert.
Grundlage für das Redesign. Plan-Abschnitt 9 ("Kalorientracking vollwertig") ist das Soll; dieses Dokument beschreibt, was heute da ist und was fehlt.

Kurzfassung: Ein funktionierendes, aber unfertiges Kalorien-Modul als eigener Tab. Vorhanden: Tagesdashboard mit Ring, Makros, Wasser, Mahlzeiten-Log, Foto-Schätzung (Gemini), Open-Food-Facts-Suche, Barcode nur per Zifferneingabe, Gewicht, Wochenrückblick, zwei Diät-Challenges, "Was kann ich heute noch essen?". Fehlt gegenüber dem Plan: Barcode-Kamera-Scanner (Paket `mobile_scanner` ist in `pubspec.yaml:48` auskommentiert), Workouts, Apple Health (kein HealthKit im Code), editierbares Wasserziel, eigene Kalorienziele ("Individuell" rechnet wie "Halten"), Bearbeiten von Einträgen, Offline-Fähigkeit. Optisch komplett im Paper-Stil (Creme, Terrakotta, Kicker) und mit Material-Bausteinen.

---

## 1. Dateien

### Screens und Widgets (`lib/presentation/screens/calories/`)

| Pfad | Rolle | Zeilen |
|---|---|---|
| `calories_screen.dart` | Tab "Kalorien" (`/calories`): Setup-Aufforderung oder Tagesdashboard | 444 |
| `goal_setup_screen.dart` | Ziel-Fragebogen, berechnet und speichert kcal/Makros | 359 |
| `weekly_summary_screen.dart` | Wochenrückblick (7 Tage) | 364 |
| `weight_tracking_screen.dart` | Gewichtsverlauf (Chart) und Eingabe | 119 |
| `challenges_screen.dart` | Diät-Challenges: aktiv, Katalog, Verlauf | 434 |
| `what_can_i_eat_screen.dart` | Rezeptvorschläge, die ins Restbudget passen | 219 |
| `widgets/food_entry_sheet.dart` | Sheet "Essen hinzufügen" (Suche, Barcode, Foto, Manuell) plus Gramm-Dialog | 697 |
| `widgets/log_recipe_sheet.dart` | Sheet "Ins Tagebuch eintragen" (aus Rezeptdetail) | 174 |
| `widgets/calorie_ring.dart` | Ring kcal verbraucht/Ziel (CustomPainter) | 111 |
| `widgets/macro_bar.dart` | Fortschrittsbalken je Makro | 55 |
| `widgets/water_tracker_card.dart` | Wasser-Karte mit +250/+500/+750 ml | 91 |
| `widgets/food_log_tile.dart` | Eintragszeile mit Wisch-Löschen | 105 |
| `widgets/weekly_calories_strip.dart` | 7 Mini-Balken auf dem Dashboard | 73 |
| `widgets/weight_chart.dart` | Linienchart Gewicht (CustomPainter) | 126 |
| `widgets/challenges_entry_card.dart` | Einstiegskarte zu Challenges | 61 |

### State (`lib/presentation/state/`)

| Pfad | Rolle | Zeilen |
|---|---|---|
| `nutrition_provider.dart` | Service-Provider, Ziel, gewähltes Datum, Tageslog, Summen, Wasser, Wochenwerte, Gewicht, OFF-Suche/Barcode, `invalidateNutritionLog()` | 161 |
| `calorie_tracking_provider.dart` | `calorieTrackingEnabledProvider` (Modul an/aus, SharedPreferences + Server) | 57 |
| `calorie_recipe_nudge_provider.dart` | Restbudget heute, Rezeptvorschläge (3 für Home, 15 für Screen), Dismiss | 49 |
| `diet_challenge_provider.dart` | aktive Challenges, Verlauf, `invalidateChallenges()` | 28 |

### Services (`lib/data/services/`)

| Pfad | Rolle | Zeilen |
|---|---|---|
| `food_log_service.dart` | CRUD `food_log_entries`, Wochensummen, Streak-Tage, Rezept-Einträge | 148 |
| `nutrition_goal_service.dart` | `NutritionGoalCalculator` (Mifflin-St Jeor) und CRUD `nutrition_goals` | 141 |
| `water_log_service.dart` | CRUD `water_log` (mehrere Zeilen pro Tag) | 88 |
| `weight_log_service.dart` | CRUD `weight_log` (Upsert, eine Zeile pro Tag) | 79 |
| `diet_challenge_service.dart` | CRUD `nutrition_challenges`, Check-ins (jsonb), Auto-Abschluss | 132 |
| `meal_photo_analysis_service.dart` | Gemini 2.0 Flash Vision: Foto zu kcal/Makros | 83 |
| `meal_photo_storage_service.dart` | Upload in Bucket `meal-photos` | 30 |
| `open_food_facts_service.dart` | OFF-Namenssuche und Barcode-Lookup | 83 |
| `open_prices_service.dart` | Open-Prices-Normalpreise (gehört fachlich zu Preisen, nicht zu Kalorien; in `lib/` nirgends benutzt, nur in `test/open_prices_test.dart`) | 332 |

### Modelle und angrenzende Dateien (nicht im Kernumfang, aber berührt)

`data/models/food_log_entry.dart` (179, `MealType`, `FoodLogSource`, `DailyNutritionTotals`), `nutrition_goal.dart` (179), `diet_challenge.dart` (184), `weekly_nutrition_summary.dart` (216), `water_log_entry.dart` (41), `weight_log_entry.dart` (45), `food_product.dart` (83), `shelf_price.dart` (86); `data/services/calorie_recipe_nudge_service.dart` (274); `screens/home/widgets/calorie_recipe_nudge_card.dart` (191); `screens/onboarding/widgets/onboarding_goal_page.dart` (345). Migrationen: `supabase/migrations/20260706000000_calorie_tracking.sql`, `20260714000000_diet_challenges_and_meal_photos.sql`.

---

## 2. Screens, Sheets und Dialoge

### 2.1 Kalorien-Tab, Zustand "Ziele fehlen" (`_SetupPrompt`)
- Datei: `calories_screen.dart:56-148`. Route `/calories` (Shell-Branch 2, `app_router.dart:258-270`), Tab nur sichtbar, wenn `calorieTrackingEnabledProvider == true` (`main_scaffold.dart:200, 312-318`, Label hart codiert "Kalorien").
- Hauptfrage: "Willst du deine Ziele einrichten?"
- Aufbau: Kicker "KALORIEN" (Großbuchstaben, Akzentfarbe) / Titel "Dein Tag,\nin Kalorien." / Karte mit Flammen-Icon, "Richte deine Ziele ein", Erklärtext, Button "Los geht's" / Textbutton "Tab ausblenden".
- Komponenten: `AppCard`, `AppButton`, Material `TextButton`.
- Zustände: laden = Material-Spinner zentriert (`:41`); Fehler = Text `calories_v0_card_sub` ("Mahlzeiten-Log, Ziele und Fortschritt sind in Arbeit ... gezählt wird hier noch nichts", `:42-43`), also ein veralteter Platzhaltertext. Offline: siehe Bug 4.1, der Nutzer landet hier statt im Dashboard. Modul aus: Tab verschwindet, Shell springt auf Home (`main_scaffold.dart:204-209`). Pro: kein Pro-Gate im ganzen Bereich.
- Aktionen: Push `GoalSetupScreen`; "Tab ausblenden" setzt Modul aus (Haptik selectionClick).
- Daten: `nutritionGoalProvider`, `calorieTrackingEnabledProvider`.

### 2.2 Kalorien-Tab, Tagesdashboard (`_Dashboard`)
- Datei: `calories_screen.dart:150-444`.
- Hauptfrage (gemeint): "Wie viel darf ich heute noch essen?" Tatsächlich konkurrieren acht Blöcke gleichrangig.
- Aufbau von oben nach unten:
  1. Zeile: Chevron links, Datum ("Heute" bzw. "Donnerstag, 12. Nov."), Chevron rechts (an "Heute" deaktiviert), Spacer, Tune-Icon zu Zielen (`:208-247`).
  2. Rechtsbündiger Link "Wochenrückblick >" (`:249-278`).
  3. `WeeklyCaloriesStrip` (7 Balken, Tap öffnet ebenfalls Wochenrückblick) (`:280-285`).
  4. `CalorieRing` 180 pt: Restkalorien groß, "kcal übrig"/"kcal drüber" (`:287-294`).
  5. Outline-Button "Was kann ich heute noch essen?" (`:296-302`).
  6. Karte mit drei `MacroBar` (Protein blau, Kohlenhydrate ocker, Fett rot) (`:304-330`).
  7. `WaterTrackerCard` (`:332`).
  8. `ChallengesEntryCard` (`:334`).
  9. Outline-Button "Gewicht eintragen" (`:336-342`).
  10. Vier Mahlzeitenkarten Frühstück, Mittagessen, Abendessen, Snack; je Kopfzeile mit Name, kcal-Summe, Plus-Icon; darunter `FoodLogTile`s oder "Noch nichts eingetragen" (`:344-439`).
- Zustände: Mahlzeitenliste laden = Spinner (`:345-348`), Fehler = "Tagesprotokoll konnte nicht geladen werden." (praktisch unerreichbar, Service schluckt Fehler); leer = je Mahlzeit "Noch nichts eingetragen". Wochenstreifen lädt als leere 56-pt-Box, Fehler unsichtbar. Kein Offline-Zustand.
- Aktionen und Gesten: Pull-to-refresh (Material `RefreshIndicator`, invalidiert nur Tageslog und Wasser); Tag wechseln per Chevrons (Haptik); Tap auf Datum springt zu heute; Plus je Mahlzeit öffnet `FoodEntrySheet`; Eintrag nach links wischen löscht sofort auf dem Server (kein Undo); Wasser-Chips; Navigation in fünf Unterscreens. Kein Wischen zwischen Tagen, kein Datumswähler, kein Bearbeiten eines Eintrags.
- Daten: `selectedLogDateProvider`, `dailyFoodLogProvider`, `dailyNutritionTotalsProvider`, `dailyWaterTotalProvider`, `weeklyNutritionTotalsProvider`, `activeChallengesProvider`, `foodLogServiceProvider`.
- Wichtige Texte: "Heute", "Wochenrückblick", "kcal übrig", "kcal drüber", "Was kann ich heute noch essen?", "Protein", "Kohlenhydrate", "Fett", "Wasser", "Challenges", "Challenge starten" / "{count} aktiv — heute eintragen", "Gewicht eintragen", "Frühstück/Mittagessen/Abendessen/Snack", "Noch nichts eingetragen", "{n} kcal".

### 2.3 Sheet "Essen hinzufügen" (`FoodEntrySheet`)
- Datei: `widgets/food_entry_sheet.dart:20-484`. Einstieg: Plus in einer Mahlzeitenkarte. `showAppBottomSheet`, max. 88 % Bildschirmhöhe, Material-Modal mit eigenem Griff.
- Hauptfrage: "Was hast du gegessen?"
- Aufbau: Titel "Essen hinzufügen" / horizontal scrollende Chips Suche, Barcode, Foto, Manuell / Tab-Inhalt.
  - Suche (`:259-317`): Textfeld mit Lupe, 350 ms Debounce; unter 2 Zeichen Hinweis "Gib mindestens 2 Zeichen ein"; Ergebnisliste `_ProductTile` (44-pt-Bild per `Image.network`, Name, Marke · kcal/100 g, Plus-Icon). Leer: "Keine Produkte gefunden." Fehler: "Suche fehlgeschlagen — Verbindung prüfen." (unerreichbar, siehe 4.1).
  - Barcode (`:319-379`): Erklärtext "Gib die Barcode-Nummer unter dem Strichcode ein.", Zahlenfeld "z.B. 4000417025005", Button "Suchen"; Ergebnis als `_ProductTile` oder "Kein Produkt zu diesem Barcode gefunden. Versuche es mit manueller Eingabe." Kein Kamera-Scan.
  - Foto (`:381-483`): Hinweistext, zwei Outline-Buttons "Kamera"/"Galerie"; während Analyse Spinner + "Foto wird analysiert..."; danach Konfidenzzeile mit Funkel-Icon ("KI-Schätzung (geringe Sicherheit) — bitte prüfen"), editierbare Felder Name, Kalorien, Protein/Kohlenhydrate/Fett nebeneinander, Button "Hinzufügen". Fehlschlag: rote Zeile "Couldn't identify food ...".
  - Manuell (`_ManualEntryForm`, `:590-697`): Name, Kalorien (Ganzzahl), drei Makrofelder nebeneinander, Button "Hinzufügen" (deaktiviert, bis Name und ganzzahlige kcal da sind).
- Dialog "Menge (g)" (`showQuantityGramsDialog`, `:549-588`): Material `AlertDialog` mit Produktname, Feld vorbelegt "100", Live-kcal, "Abbrechen"/"Hinzufügen".
- Zustände: Fehler beim Speichern = SnackBar "generic_error", Sheet bleibt offen; Bildwahl verweigert = SnackBar.
- Daten: `foodSearchProvider(query)`, `barcodeLookupProvider(code)`, `MealPhotoAnalysisService`, `MealPhotoStorageService`, `foodLogServiceProvider`, `authUserProvider`; nach Speichern `invalidateNutritionLog`.

### 2.4 Ziel-Fragebogen (`GoalSetupScreen`)
- Datei: `goal_setup_screen.dart`. Einstieg: Setup-Karte und Tune-Icon im Dashboard (CupertinoPageRoute, innerhalb der Tab-Shell). Kommentar `:19-20` behauptet Erreichbarkeit aus dem Profil; per grep nicht vorhanden.
- Hauptfrage: "Was ist dein Ziel, und was brauchst du dafür täglich?"
- Aufbau: Material-AppBar "Deine Ziele" / Untertitel / Abschnitt Ziel (Chips Abnehmen, Muskeln aufbauen, Gewicht halten, Individuell) / Geschlecht (weiblich, männlich, divers) / Zeile Alter + Größe (cm) / Zeile aktuelles Gewicht + Zielgewicht (nur bei Abnehmen/Aufbauen) / Aktivität als fünf `AppListTile`s mit Radio-Icon / Zeitraum-Slider 4-52 Wochen (nur bei Abnehmen/Aufbauen) / Button "Speichern" / Hinweis "Alter, Größe und Gewicht ausfüllen, um fortzufahren."
- Zustände: Laden = ganzer Screen Spinner (`:195-200`); Laden-Fehler = leeres Formular; Speicherfehler = SnackBar mit roher Exception (`:181-183`).
- Aktionen: Speichern (Haptik medium) berechnet Ziele, upsertet `nutrition_goals`, loggt Gewicht nur bei Änderung, schreibt Alter/Größe/Geschlecht ins Nutzerprofil, `pop(true)`.
- Was fehlt: Ergebnisvorschau (kcal/Makros werden nie vor dem Speichern gezeigt), eigene Werte bei "Individuell", Wasserziel.

### 2.5 Wochenrückblick (`WeeklySummaryScreen`)
- Datei: `weekly_summary_screen.dart`. Einstieg: Link und Wochenstreifen im Dashboard (zwei Einstiege für dasselbe Ziel).
- Hauptfrage: "Wie lief meine Woche?"
- Aufbau: AppBar "Deine Woche" / Datumsbereich / Streak-Zeile ab 2 Tagen ("{n} Tage in Folge geloggt") / Karte Kalorien: "Ø {avg}" 30 pt, "kcal / {Ziel}", "{x} von 7 Tagen geloggt · {y} im Budget", `_WeekBars` (96 pt hoch, kcal-Zahl 9 pt über jedem Balken) / Karte Makros (Ø pro geloggtem Tag, "Protein an {n} von {m} Tagen erreicht") / optional Karte gekochte Rezepte ("{n} Mahlzeiten gekocht", "{n} davon proteinreich") / Karte Wasser / tappbare Karte Gewicht (Delta, aktuell) zu `WeightTrackingScreen`.
- Zustände: laden Spinner; Fehler "Tagesprotokoll konnte nicht geladen werden."; leer `AppEmptyState` (Icon im 80-pt-Kreis, "weekly_summary_empty_*").
- Daten: `weeklyNutritionSummaryProvider` (fünf parallele Abfragen: Wochensummen, Wasser, Gewicht 90 Tage, geloggte Tage 60 Tage, Rezept-Einträge), `nutritionGoalProvider`.

### 2.6 Gewicht (`WeightTrackingScreen`)
- Datei: `weight_tracking_screen.dart`. Einstieg: Button im Dashboard, Karte im Wochenrückblick.
- Hauptfrage: "Wie entwickelt sich mein Gewicht?"
- Aufbau: AppBar "Gewicht" / Karte mit `WeightChart` (180 pt, Linie, gestrichelte Ziellinie, letzter Wert als Label; unter zwei Einträgen nur große Zahl oder "—") / Zeile Feld "Gewicht (kg)" + Button "Speichern" / "Ziel: {x} kg".
- Zustände: laden Spinner in 180-pt-Box; Fehler "weight_tracking_error" (praktisch unerreichbar, Service gibt [] zurück).
- Aktionen: Speichern (Haptik), upsert für heute, Feld leeren. Kein Datum wählbar, keine Liste der Einträge, kein Löschen/Bearbeiten, nur kg.
- Daten: `weightHistoryProvider` (90 Tage), `nutritionGoalProvider`, `weightLogServiceProvider`.

### 2.7 Challenges (`ChallengesScreen`)
- Datei: `challenges_screen.dart`. Einstieg: `ChallengesEntryCard` im Dashboard.
- Hauptfrage: "Halte ich meine Challenge heute ein?"
- Aufbau: AppBar "Challenges" / Untertitel "Baue dir eine Gewohnheit auf ... komplett freiwillig." / Abschnitt "Aktiv": `_ActiveChallengeCard` (Icon, Titel, Streak-Chip mit Flamme, "Tag x von y", "noch n Tage", Einhaltung in %, Buttons "Heute nicht"/"Heute geschafft" oder nach Check-in Status + "Ändern", unten "Abbrechen"/"Als abgeschlossen markieren") / Abschnitt Katalog: `_CatalogCard` für 16:8 Intervallfasten und 30 Tage ohne Zucker (nur nicht aktive) mit "Starten" / Abschnitt Verlauf: `_HistoryTile` (abgeschlossen/abgebrochen, %).
- Zustände: Spinner je Abschnitt; leer "challenge_empty_active"/"challenge_empty_history"; Fehler aktiv zeigt den Leer-Text, Fehler Verlauf zeigt nichts.
- Aktionen: Pull-to-refresh, Start (Haptik medium, bei Duplikat SnackBar), Check-in (Haptik), Abbrechen mit Material-Bestätigungsdialog, Abschließen ohne Rückfrage.
- Daten: `activeChallengesProvider`, `challengeHistoryProvider`, `dietChallengeServiceProvider`.

### 2.8 Was kann ich essen? (`WhatCanIEatScreen`)
- Datei: `what_can_i_eat_screen.dart`. Einstieg: Outline-Button im Dashboard.
- Hauptfrage: "Welches Rezept passt noch in mein Budget?"
- Aufbau: AppBar / Zeile "Noch {kcal} kcal übrig · {n} passende Rezepte" / bis zu 15 `_RecipeCard` (56-pt-Bild, Name, "{kcal} kcal · {min} Min.", optional in Akzentfarbe "Nutzt {items} von deiner Liste") zu `/recipes/:id`.
- Zustände: kein Ziel = `AppEmptyState` (nicht scrollbar, Pull-to-refresh funktioniert dort nicht); Budget unter Mindestwert = Leerzustand "Nur noch {kcal} kcal übrig ..."; keine Treffer = Leerzustand mit Button "Rezepte entdecken" zu `/recipes`; Fehler = Text.
- Daten: `remainingCaloriesTodayProvider`, `whatCanIEatSuggestionsProvider` (`CalorieRecipeNudgeService`, berücksichtigt Diät und Allergien des Nutzers).

### 2.9 Sheet "Ins Tagebuch eintragen" (`showLogRecipeSheet`)
- Datei: `widgets/log_recipe_sheet.dart`. Einstieg: Rezeptdetail, Button "Ins Tagebuch eintragen" nur bei aktivem Modul (`recipe_detail_screen.dart:428-439`).
- Hauptfrage: "Wie viele Portionen, zu welcher Mahlzeit?"
- Aufbau: Titel / Rezeptname / Mahlzeit-Chips (Standard Abendessen) / Portionen-Stepper 0,5-20 in 0,5er-Schritten / "{kcal} kcal" / Button.
- Aktionen: Speichern (Haptik medium), danach SnackBar, ggf. Maskottchen-Meilenstein ("weeklyHighProteinMealMessage").

### 2.10 Einstiegskarte Challenges, Ring, Balken (Komponenten)
- `ChallengesEntryCard`: Flagge oder Flamme, "Challenges", Untertitel, Chevron.
- `CalorieRing`: Track in Rahmenfarbe, Fortschritt in Akzent, über Budget Orange `0xFFE0764A`; keine Animation, keine Semantik.
- `MacroBar`: "112 / 150 g", Material `LinearProgressIndicator` 6 pt.
- `WaterTrackerCard`: Tropfen-Icon blau, "0.25 / 2.0 l", Balken, drei Outline-Chips.
- `FoodLogTile`: Quellen-Icon oder 32-pt-Foto, Name, "12g P · 30g C · 8g F", "{kcal} kcal".

### 2.11 Weitere Oberflächen außerhalb des Ordners
- Home-Karte `CalorieRecipeNudgeCard` ("312 kcal übrig — 3 Ideen fürs Abendessen"), tagesweise wegklickbar (`home_screen.dart:815`).
- Profil: Schalter "Kalorien-Tracking" (`profile_screen.dart:199-212`).
- Onboarding: Wahl "Nur Einkaufen & Rezepte" / "Mit Kalorien-Tracking" und eigene Zielseite `onboarding_goal_page.dart` (Entwurf wird nach Login per `onboarding_answers_service.dart:150-193` gespeichert).
- Avo-Werkzeuge (`avo_assistant_service.dart:287-302`): `setup_nutrition_goal`, `get_nutrition_status`, `log_food` (schätzt kcal per KI, wenn keine angegeben), `log_water`, `log_weight`, `delete_food_log` (mit Rückfrage), `get_weekly_nutrition_summary`, `get_challenge_status`; Einstellung `calorie_tracking` über `avo_settings_bridge.dart:315-335`.
- Benachrichtigung "Ideen fürs Abendessen" (`MascotNotificationService.rearmDinnerIdeasReminder`, aufgerufen in `app.dart`, `main.dart`, Einstellungen, Avo).

---

## 3. Design-Probleme heute

### Paper-Reste
- Kicker in Großbuchstaben mit Laufweite 2 und Akzentfarbe über dem Titel: `calories_screen.dart:73-81`.
- Paper-Headline mit erzwungenem Umbruch "Dein Tag,\nin Kalorien.": `calories_screen.dart:83-90`, String `app_translations.dart:1489`.
- Palette des ganzen Bereichs über `AppColors`: Hintergrund Creme `0xFFF7F3EC`, Karten `0xFFFFFDF8`, Akzent Terrakotta `0xFFC0502A`, Sekundärtext `0xFF8A8274` (`app_colors.dart:41, 44, 59, 69`). Dashboard-Ring, Chips, Buttons, Wochenbalken sind dadurch terrakotta.
- Shell-Hintergrund `PaperColors.paper` (`main_scaffold.dart` ab `:219`), unter dem der Tab liegt.

### Abweichungen von den Apple-Regeln
- Material statt iOS: `AppBar` in allen Unterscreens (`goal_setup_screen.dart:204`, `weekly_summary_screen.dart:27`, `weight_tracking_screen.dart:58`, `challenges_screen.dart:27`, `what_can_i_eat_screen.dart:32`), `CircularProgressIndicator` an 14 Stellen, `RefreshIndicator` (`calories_screen.dart:195`, `challenges_screen.dart:35`, `what_can_i_eat_screen.dart:41`), `AlertDialog` (`food_entry_sheet.dart:556`, `challenges_screen.dart:256`), Material-`Slider` (`goal_setup_screen.dart:318`), `InkWell`-Ripple, `SnackBar` für Erfolg und Fehler.
- Ikonografie Material `Icons.*` statt SF Symbols, z. B. `Icons.local_fire_department_outlined`, `Icons.tune`, `Icons.qr_code_scanner`.
- Keine Liquid-Glass-Navigationsebene: Sheets sind feste Flächen (`design_system.dart:497-543`), Tage-Umschalter sind Inhalt statt Toolbar, kein schwebender Hinzufügen-Button.
- Keine eine Hauptfrage auf dem Dashboard: acht gleichrangige Blöcke, davon zwei Outline-Buttons zwischen Karten (`calories_screen.dart:296, 336`), Reihen fast identischer Karten (Makros, Wasser, Challenges, vier Mahlzeiten).
- Doppelter Einstieg zum Wochenrückblick (Link und Streifen, `calories_screen.dart:249-285`).
- Regenbogen-Makros mit festen, nicht adaptiven Farben: Blau `0xFF5B9BD5`, Ocker `0xFFE0A458`, Rot `0xFFD9694F` (`calories_screen.dart:312, 319, 326`, dupliziert in `weekly_summary_screen.dart:153-165`), Wasser ebenfalls `0xFF5B9BD5` (`water_tracker_card.dart:21`), Überschreitung `0xFFE0764A` (`calorie_ring.dart:33`, `weekly_calories_strip.dart:51`, `weekly_summary_screen.dart:345`).
- Fließtext und Erklärungen in blassem Sekundärgrau (`0xFF8A8274` auf Creme, Kontrast etwa 3,5:1, unter 4,5:1 für 12-13 pt): z. B. `calories_screen.dart:112-118`, `challenges_screen.dart:41-42`, `food_entry_sheet.dart:325-326`.
- Touch-Ziele unter 44 pt: Plus je Mahlzeit 22-pt-Icon + 4 pt Padding = ca. 30 pt (`calories_screen.dart:391-405`); Link "Wochenrückblick" ca. 20 pt hoch (`:251-277`); Datum als reiner Text-Tap (`:215-234`); `AppChip` ca. 33 pt (`design_system.dart:573`); Wasser-Chips ca. 37 pt (`water_tracker_card.dart:83`); Text-Buttons 12,5 pt in der Challenge-Karte (`challenges_screen.dart:377-385`).
- Löschen ohne Rückgängig: Wisch-Löschen löscht sofort auf dem Server, kein Undo (`food_log_tile.dart:53-67`, `calories_screen.dart:424-430`). Umgekehrt Bestätigungsdialog beim Beenden einer Challenge (`challenges_screen.dart:253-270`), wo Undo reichen würde.
- Haptik uneinheitlich: Selection-Klick beim Wasser und Tageswechsel, medium beim Speichern; keine Erfolgs-Haptik beim Eintragen von Essen (`food_entry_sheet.dart:171-181`), keine bei Löschen.
- Keine Bewegung: Ring, Balken und Werte springen ohne Animation; keine Federn, kein Reduce Motion nötig, weil nichts animiert ist.
- VoiceOver: Ring und Charts sind `CustomPaint` ohne `Semantics` (`calorie_ring.dart:41-44`, `weight_chart.dart:30-39`, `weekly_calories_strip.dart:29-69`); Icon-Buttons ohne Tooltip/Label (`calories_screen.dart:211-245`).
- Wochenbalken nur mit Anfangsbuchstaben des Wochentags, kcal-Zahlen 9 pt (`weekly_summary_screen.dart:338`), Wochentage 10 pt (`weekly_calories_strip.dart:59`).
- Leerzustand mit Icon im getönten 80-pt-Kreis (`design_system.dart:632-645`).
- Konfidenz der KI-Schätzung mit Funkel-Icon, aber ohne Erklärung, was "gering" für den Nutzer bedeutet (`food_entry_sheet.dart:405-412`).

### Feste Größen, die bei großer Schrift oder 320 pt Breite brechen
- `AppButton`/`AppOutlineButton` feste Höhe 52 pt mit nicht umbrechender `Row` (`design_system.dart:150-151, 209-210, 220-238`): "Was kann ich heute noch essen?" mit Icon braucht bei 16 pt etwa 300 pt, bei 320 pt Bildschirm bleiben nach 2 x 24 pt Rand (`app_dimensions.dart:3`) nur 272 pt, Überlauf schon in Standardgröße (`calories_screen.dart:296-302`). Gleiches Risiko bei "Gewicht eintragen" mit großer Schrift.
- `WeeklyCaloriesStrip` feste Höhe 56 pt mit Balken bis 32 pt plus Text (`weekly_calories_strip.dart:32-34, 48, 57-61`): Text wächst mit Dynamic Type, Spalte läuft über.
- `_WeekBars` feste Höhe 96 pt mit zwei Textzeilen (`weekly_summary_screen.dart:318-356`): Überlauf bei großen Stufen.
- `CalorieRing` feste 180 pt, Zahl `size * 0.2` = 36 pt, skaliert mit Dynamic Type, Ring nicht (`calorie_ring.dart:23, 35-63`): Zahl ragt bei AX-Größen aus dem Ring.
- `WeightChart` feste 180 pt (`weight_chart.dart:12`), Lade- und Fehlerbox ebenfalls 180 pt (`weight_tracking_screen.dart:73-77`).
- Datumszeile im Dashboard: Text ohne `Flexible` zwischen drei IconButtons und `Spacer` (`calories_screen.dart:208-247`): "Donnerstag, 12. Nov." läuft bei großen Stufen über.
- Drei Makrofelder nebeneinander im Sheet (`food_entry_sheet.dart:422-439, 665-690`): bei 320 pt bleiben etwa 88 pt je Feld, Label "Kohlenhydrate (g)" wird abgeschnitten.
- Zwei Felder nebeneinander im Fragebogen (`goal_setup_screen.dart:252-296`): "Aktuelles Gewicht (kg)" und "Zielgewicht (kg)" in je etwa 130 pt.
- Barcode- und Gewichtszeile: Feld + Button mit fester Höhe 52 pt (`food_entry_sheet.dart:338-352`, `weight_tracking_screen.dart:93-104`).
- Challenge-Karte: Zeile mit zwei Text-Buttons "Abbrechen" und "Als abgeschlossen markieren" ohne Flex (`challenges_screen.dart:374-387`); Kopfzeile Titel + Streak-Chip (`:298-311`).
- Zeilen mit `maxLines: 1` schneiden wichtige Inhalte ab: Rezeptname (`what_can_i_eat_screen.dart:183-188`), Produktname (`food_entry_sheet.dart:516-519`), Rezeptname im Log-Sheet (`log_recipe_sheet.dart:70-72`).
- Mahlzeit-Chips im Log-Sheet als `Wrap` ohne `runSpacing` (`log_recipe_sheet.dart:77-86`): Zeilen kleben aneinander.
- Unterer Abstand hart 140 pt statt Navbar-Freiraum (`calories_screen.dart:70, 205`, `challenges_screen.dart:39`).
- Schriftgrößen als Einzelwerte (9, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 18, 28, 30) statt Textstilen; keine Typo-Hierarchie.
- `AppCard` mit Standard-Außenrand 16/6 pt bei `WaterTrackerCard` (`water_tracker_card.dart:38`) und im Gewichtsscreen (`weight_tracking_screen.dart:71`), während alle Nachbarn `margin: EdgeInsets.zero` setzen: die Wasserkarte ist sichtbar schmaler eingerückt.

---

## 4. Bugs, Risiken und Performance

### Datenkorrektheit
- 4.1 Offline oder Serverfehler zeigt falsche Zustände: `getGoal()` fängt jeden Fehler und gibt `null` zurück (`nutrition_goal_service.dart:111-114`), also landet ein Nutzer mit Zielen offline beim Setup-Prompt. Ebenso geben `getEntriesForDate`, `getHistory`, OFF-`search` bei Fehlern leere Listen zurück (`food_log_service.dart:30-33`, `weight_log_service.dart:33-36`, `open_food_facts_service.dart:53-56`): Anzeige "Noch nichts eingetragen" bzw. "Keine Produkte gefunden" statt eines Fehlers. Die Fehlerzweige in der UI sind dadurch tot.
- 4.2 Wasser wird immer für heute gespeichert, auch wenn ein vergangener Tag angezeigt wird: `addEntry(ml)` ohne Datum (`water_tracker_card.dart:26`, `water_log_service.dart:76`). Die Karte zeigt aber den Wert des gewählten Tages; der Tap scheint wirkungslos.
- 4.3 Rezept-Log ignoriert den Tag und die Uhrzeit: `loggedDate: DateTime.now()` und Standard-Mahlzeit Abendessen (`log_recipe_sheet.dart:48, 126`).
- 4.4 Foto-Eintrag speichert stillschweigend 0 kcal, wenn das Feld leer ist oder ein Komma enthält: `int.tryParse(...) ?? 0` (`food_entry_sheet.dart:126`). Makrofelder im Foto-Tab ohne Zahlentastatur (`:425-436`).
- 4.5 Manuelle kcal nur als Ganzzahl; "450,5" lässt den Button ohne Hinweis deaktiviert (`food_entry_sheet.dart:619-620`).
- 4.6 Produkte ohne Nährwerte werden mit 0 kcal eingetragen (`food_product.dart:30-31`, Dialog erlaubt Hinzufügen ohne kcal-Anzeige, `food_entry_sheet.dart:569-581`).
- 4.7 Suchtreffer werden als Quelle `barcode` gespeichert (`food_entry_sheet.dart:193`), im Log erscheint dann das Scanner-Icon.
- 4.8 Ziel "Individuell" hat keine eigenen Eingaben und rechnet wie "Halten" (`nutrition_goal_service.dart:52-64`); Wasserziel ist fest 2000 ml und nirgends änderbar (`goal_setup_screen.dart:148`).
- 4.9 Geschlecht "divers" wird als männlich gerechnet (+5, Minimum 1500 kcal) (`nutrition_goal_service.dart:45-50`). Bei "Abnehmen" mit Zielgewicht über dem aktuellen Gewicht wird trotzdem ein Defizit berechnet (`.abs()`, `:53-54`), ohne Validierung.
- 4.10 Challenge-Check-in ist Lesen-Mischen-Schreiben des gesamten jsonb (`diet_challenge_service.dart:102-111`): Bei zwei Geräten mit demselben Konto (genau der Arbeitsmodus von Owner und Jannis) überschreibt ein Gerät die Check-ins des anderen.
- 4.11 Lese-Abfrage mit Seiteneffekt: `getActiveChallenges` schließt abgelaufene Challenges per Update ab, sequentiell in einer Schleife (`diet_challenge_service.dart:39-46`).
- 4.12 Gewicht: Upsert pro Tag ohne Datumswahl, kein Löschen oder Korrigieren möglich (`weight_log_service.dart:57-78`); Chart-x-Achse ist der Index, nicht das Datum, Lücken verzerren den Verlauf (`weight_chart.dart:72-73`).
- 4.13 Modul-Schalter startet mit `false` und lädt asynchron (`calorie_tracking_provider.dart:25-43`): Tab flackert beim Start herein; ein Deep Link auf `/calories` beim Kaltstart kann vom Fallback in `main_scaffold.dart:204-209` auf Home umgeleitet werden.
- 4.14 Fehlerzustand des Tabs zeigt den alten Platzhalter "in Arbeit, gezählt wird noch nichts" (`calories_screen.dart:42-43`).
- 4.15 Rohe Exceptions im UI: `goal_setup_save_error` mit `$e` (`goal_setup_screen.dart:182`), `error_generic` mit `$e` (`challenges_screen.dart:171`).
- 4.16 Konfidenz-Schlüssel kommt ungeprüft von der KI (`food_entry_sheet.dart:409`, `meal_photo_analysis_service.dart:76`): ein anderer Wert als low/medium/high ergibt einen fehlenden Übersetzungsschlüssel.

### Datenschutz und KI
- 4.17 Bucket `meal-photos` ist öffentlich lesbar (`supabase/migrations/20260714000000_diet_challenges_and_meal_photos.sql:31, 35-38`), Pfad aus User-ID und Zeitstempel (`meal_photo_storage_service.dart:18`). Essensfotos sind Gesundheitsdaten-nah; gehören in einen privaten Bucket mit signierten URLs.
- 4.18 Foto-Analyse läuft über Gemini 2.0 Flash mit Client-API-Key (`meal_photo_analysis_service.dart:35-40`), ohne die Pflicht-Pause von 1100 ms aus `CLAUDE.md`. Plan: alle KI künftig über Claude. Prompt fragt keine Allergene oder Unsicherheiten ab.
- 4.19 Keine Quellenangabe für Open Food Facts (ODbL) in Suche und Barcode-Ergebnissen; die vorhandene Quellenangabe `data_sources_body` betrifft nur Preise.
- 4.20 Gesundheitswerte (Alter, Größe, Geschlecht) werden beim Speichern der Ziele ungefragt ins allgemeine Nutzerprofil geschrieben (`goal_setup_screen.dart:163-171`).

### Performance und sichtbares Laden
- 4.21 Tageswechsel lädt die Mahlzeitenliste neu mit Spinner (`calories_screen.dart:344-348`); kein Cache pro Tag, kein Vorladen der Nachbartage.
- 4.22 Jede Änderung invalidiert sieben Provider (`nutrition_provider.dart:153-161`), also bis zu sieben Supabase-Abfragen pro Wassertap.
- 4.23 `getWeeklyTotals` und `getWeeklyRecipeSourcedEntries` holen ganze Zeilen (`select()`), obwohl nur Summen gebraucht werden (`food_log_service.dart:105-111, 128-133`); Wochenrückblick lädt Gewicht über 90 Tage und geloggte Tage über 60 Tage.
- 4.24 Bilder ohne Cache per `Image.network` (`food_log_tile.dart:75`, `food_entry_sheet.dart:506`): flackern bei jedem Rebuild/Neuladen.
- 4.25 Sheet nicht scrollbar: Foto- und Manuell-Formular sind `Column`s ohne Scroll in einem `Flexible` (`food_entry_sheet.dart:211-250, 400-447, 648-695`); mit Tastatur auf dem iPhone SE läuft der Inhalt über.
- 4.26 `WeightChart.shouldRepaint` vergleicht nur die Liste (`weight_chart.dart:125`): Farbwechsel hell/dunkel wird nicht neu gezeichnet.
- 4.27 `_removedIds` wird nie geleert (`calories_screen.dart:170`), harmlos, aber Zustand wächst pro Sitzung.
- 4.28 `OpenPricesService` ist in `lib/` ungenutzt (nur Test); fachlich gehört er zum Bereich Preise/Angebote, nicht zu Kalorien.

---

## 5. Abhängigkeiten zu anderen Bereichen

- Navigation: Shell-Branch 2 `/calories` in `routes/app_router.dart:258-270`; Tab-Sichtbarkeit und Fallback in `presentation/screens/main_scaffold.dart:19, 200-209, 312-318` (Label "Kalorien" hart codiert, nicht übersetzt). Unterscreens werden per `CupertinoPageRoute` innerhalb der Shell gepusht und nutzen `MainScaffold.getNavbarClearance`.
- Modul-Schalter: `calorieTrackingEnabledProvider` wird gelesen/geschrieben von Profil (`profile_screen.dart:199-212`), Onboarding (`onboarding_screen.dart:62`), Rezeptdetail (`recipe_detail_screen.dart:428`), Avo (`avo_assistant_service.dart:1235-1671`), Avo-Einstellungsbrücke (`avo_settings_bridge.dart:315-335`). Server-Spiegel `nutrition_goals.calorie_tracking_enabled`. Das künftige Modulsystem muss diesen Schalter ersetzen oder übernehmen.
- Rezepte: `showLogRecipeSheet` aus `recipe_detail_screen.dart:433`; `what_can_i_eat_screen.dart` pusht `/recipes/:id` und geht zu `/recipes`; `NutritionInfo` aus dem Rezeptmodell.
- Home: `CalorieRecipeNudgeCard` (`home_screen.dart:815`) über `calorie_recipe_nudge_provider.dart` und `CalorieRecipeNudgeService` (liest Ziel, heutigen Log, letzte Rezept-IDs, Einkaufslisten, Diät und Allergien).
- Avo: acht Kalorien-Werkzeuge in `avo_assistant_service.dart:287-302` mit direkten Service-Aufrufen und `invalidateNutritionLog(ref)`; Avo schätzt kcal selbst (`_estimateFoodNutrition`). Beim Wechsel auf Claude müssen diese Werkzeuge mitwandern.
- Onboarding: `onboarding_goal_page.dart` (eigene Kopie des Fragebogens) und `onboarding_answers_service.dart:150-193` (speichert Ziel, Gewicht, Profilfelder nach Login). Zwei Fragebögen für dasselbe Ziel.
- Benachrichtigungen: `MascotNotificationService.rearmDinnerIdeasReminder` (app.dart, main.dart, notifications_screen, Avo) und `weeklyHighProteinMealMessage` (Log-Sheet).
- Nutzerprofil: `UserService.updateUserProfile` (Alter, Größe, Geschlecht), `currentUserProvider`, `authUserProvider`, `authUserIdProvider`.
- Design-System: `core/widgets/design_system.dart` (`AppCard`, `AppButton`, `AppOutlineButton`, `AppTextField`, `AppChip`, `AppListTile`, `AppSectionHeader`, `AppEmptyState`, `showAppBottomSheet`), `AppColors`, `AppDimensions`. Ein Redesign dieser Bausteine wirkt sofort auf alle Kalorien-Screens.
- Hilfen: `core/utils/number_parsing.dart` (`parseLocaleDouble`, Dezimalkomma).
- Strings: etwa 150 Schlüssel in `core/localization/app_translations.dart` (EN ab ca. Zeile 1013, DE ab ca. 2182; dazu `calories_v0_*` bei 321/1489, `calorie_nudge_*`, `onb_cal_*`, `goal_type_*`, `activity_*`, `meal_*`, `challenge_*`, `weekly_*`, `add_food_*`, `weight_tracking_*`, `what_can_i_eat_*`, `log_recipe_*`). Einige Texte hart im Code: "kcal", "+250 ml", "g P/C/F" (englische Abkürzungen, `food_log_tile.dart:37-39`), "Ø".
- Backend: Tabellen `food_log_entries`, `water_log`, `weight_log` (Unique `user_id, logged_date`), `nutrition_goals` (eine Zeile pro Nutzer), `nutrition_challenges` (Unique aktiv pro Typ, `daily_checkins` jsonb), Storage-Bucket `meal-photos`. Externe APIs: Open Food Facts (search.openfoodfacts.org, world.openfoodfacts.org v2), Gemini.
- Pakete: `image_picker`, `google_generative_ai`, `http`, `cached_network_image`, `intl`; `mobile_scanner` auskommentiert; `wakelock_plus` vorhanden (für den Einkaufsmodus, nicht hier). Kein HealthKit-Paket.

---

## 6. Was ein Redesign unbedingt erhalten muss

### Funktionen
- Tageslog nach vier Mahlzeiten (Frühstück, Mittagessen, Abendessen, Snack) mit kcal- und Makrosummen je Mahlzeit und Tag; Blättern durch vergangene Tage (nie in die Zukunft).
- Restbudget als Kernzahl inklusive Überschreitung ("kcal drüber").
- Vier Eingabewege: Lebensmittelsuche (Open Food Facts), Barcode (heute Ziffern, künftig Kamera, die Zifferneingabe als Rückfall behalten), Foto-Schätzung mit immer editierbarer Vorschau vor dem Speichern, manuelle Eingabe. Grammabfrage mit Live-kcal bei Produkten.
- Rezept ins Tagebuch mit Portionen in 0,5er-Schritten und Mahlzeitwahl; "Was kann ich heute noch essen?" mit Ranking nach Restbudget, Einkaufslisten-Treffern, Diät und Allergien; Home-Hinweis "Ideen fürs Abendessen" (wegklickbar pro Tag).
- Wasser mit Schnelltasten und Tagesziel; Gewicht mit Verlauf, Ziellinie und Wochen-Delta.
- Ziel-Fragebogen mit Mifflin-St-Jeor-Berechnung, Aktivitätsfaktoren, Untergrenzen 1200/1500 kcal, Begrenzung der Tagesänderung auf 200-1000 kcal, Proteinfaktoren 2,0/1,8/1,4 g/kg, Fett 28 %.
- Wochenrückblick mit den dokumentierten Semantiken (`weekly_nutrition_summary.dart:10-24`): Durchschnitt nur über geloggte Tage, "im Budget" bis 105 %, Protein erreicht ab 90 %, Gewichts-Delta nur bei zwei Wiegungen, Streak bricht nicht an einem noch offenen Tag, gekochte proteinreiche Mahlzeiten (mind. 20 g und 30 % der kcal).
- Challenges 16:8 und 30 Tage ohne Zucker: Start, tägliches Check-in mit Korrektur, Streak, Einhaltung in %, Auto-Abschluss nach Ablauf, Verlauf; höchstens eine aktive pro Typ (serverseitig).
- Modul ein- und ausschaltbar (Onboarding, Einstellungen, Avo), synchron über Geräte; "Tab ausblenden" direkt im leeren Zustand.
- Avo-Werkzeuge für Ziele, Status, Essen, Wasser, Gewicht, Wochenrückblick, Challenges; Löschen nur mit Rückfrage.

### Daten und Sonderfälle
- Alle Tabellen und Felder (inkl. `source`, `source_recipe_id`, `barcode`, `photo_url`, `brand`, `quantity`, `unit`) und die Server-Unique-Regeln; Datum als lokaler Kalendertag (`YYYY-MM-DD`), nicht UTC.
- Dezimalkomma bei allen Zahlenfeldern (`parseLocaleDouble`).
- KI-Schätzungen nie direkt speichern, immer als Vorschlag mit sichtbarer Unsicherheit; bei "kein Essen erkannt" auf manuelle Eingabe verweisen statt etwas zu erfinden.
- Foto-Upload darf das Speichern des Eintrags nie blockieren.
- Gewicht beim Ziel-Speichern nur loggen, wenn es sich geändert hat (schützt neuere Einträge).
- Wochenwerte zählen ungeloggte Tage als unbekannt, nicht als 0 kcal.
- Abgelaufene Challenges erscheinen als Ergebnis im Verlauf, nicht als ewig aktiv.

### Lücken, die das Redesign gemäß Plan schließen muss (heute nicht vorhanden)
- Barcode-Kamera-Scanner, Workouts, Apple Health lesen und schreiben, editierbares Wasserziel, eigene kcal/Makros bei "Individuell", Bearbeiten und Rückgängig von Einträgen, Offline-Cache, Gewicht mit Datum und Löschen, Ergebnisvorschau im Fragebogen, privater Foto-Speicher, Open-Food-Facts-Quellenangabe, KI über Claude, Avo-Sprachmodus "Foto vom Essen wird eingetragen".
