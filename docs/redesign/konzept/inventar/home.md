# Inventar: Startseite (Ist-Zustand, Stand 2026-11-07)

Grundlage für das Redesign. Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf den Stand von `main` (3e886d0).

Kurzfassung: Die heutige Startseite ist ein Paper-Dashboard: serifige Begrüßung, ein cremefarbener Avo-Hinweis, bis zu sechs datengetriebene Karten (Schulden, Teilen, Nachkaufen, Prospekt, Kalorien-Rezepte, Preisvergleich), darunter alle Listen als nummerierte Zeilen, ein Angebote-Streifen und eine Verlaufszeile. Laut Plan soll die Startseite künftig **die Liste von heute** sein. Die Karten-Logik dahinter (Rhythmus-Erkennung, Angebots-Abgleich, Kalorien-Rezepte, Kosten teilen) ist gut gebaut und muss erhalten bleiben. Die Oberfläche selbst kann komplett neu entstehen.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/home/home_screen.dart` | Startseite (Tab 0, `/home`): Sliver-Aufbau, Listen-Index, Angebote-Streifen, Verlaufszeile, Dialoge Neue Liste / Liste beitreten / Löschen, Tutorial-Hook, Widget-Credentials-Sync | 950 |
| `lib/presentation/screens/home/home_nudge_card_order.dart` | Reihenfolge der Karten nach Onboarding-Prioritäten (`orderedHomeNudgeCards`) | 60 |
| `lib/presentation/screens/home/widgets/greeting_header.dart` | Einklappender Sliver-Header: Datum, Tageszeit-Gruß mit Namen (Serif), Avatar | 143 |
| `lib/presentation/screens/home/widgets/nudge_card.dart` | Gemeinsame Bausteine: `NudgeCardShell` (Karte mit Rahmen), `NudgeDismissButton`, `NudgeCard` (Icon im getönten Kreis + Titel + Untertitel + x) | 146 |
| `lib/presentation/screens/home/widgets/avo_nudge_card.dart` | Avo-Karte: Nachkauf-Vorschläge (Rhythmus) und Rhythmus-Artikel im Angebot, Ein-Tipp-Hinzufügen, Schlummern | 392 |
| `lib/presentation/screens/home/widgets/personal_flyer_card.dart` | „Dein Prospekt“: Rhythmus-Artikel im Angebot, nach Markt gruppiert | 267 |
| `lib/presentation/screens/home/widgets/calorie_recipe_nudge_card.dart` | „Noch N kcal, Ideen fürs Abendessen“: bis zu 3 Rezepte | 191 |
| `lib/presentation/screens/home/widgets/pending_splits_banner.dart` | Offene Kosten-Aufteilungen: „X schuldet dir“, „Du schuldest X“ mit Schnellaktion | 159 |
| `lib/presentation/screens/home/widgets/split_trip_nudge_card.dart` | „Einkauf X mit deiner Gruppe teilen?“ öffnet `showSplitCostSheet` | 58 |
| `lib/presentation/screens/home/widgets/price_comparison_nudge_card.dart` | „Liste ist bei A X € günstiger als bei B“ (**verworfen laut Plan**) | 44 |
| `lib/presentation/screens/home/weekly_deals_screen.dart` | Angebote-Screen (Suche + „passend zu deinen Listen“), wird von der Startseite per `Navigator.push` geöffnet. Details im Inventar „history“ | 625 |
| `lib/presentation/state/avo_nudge_provider.dart` | `restockSuggestionsProvider`, `offerNudgesProvider`, `personalFlyerProvider`, geteilter In-flight-Future, `groupOffersByRetailer` | 87 |
| `lib/presentation/state/calorie_recipe_nudge_provider.dart` | `remainingCaloriesTodayProvider`, `calorieRecipeSuggestionsProvider`, `calorieNudgeDismissedProvider`, `whatCanIEatSuggestionsProvider` | 49 |
| `lib/presentation/state/expense_split_provider.dart` | `tripsAwaitingPaymentToMeProvider`, `tripsIOweProvider`, `unsplitTripNudgeProvider` | 59 |
| `lib/presentation/providers/price_comparison_provider.dart` | `homePriceHighlightProvider`, `basketComparisonProvider`, `personalizedDealsProvider`, `effectiveZipProvider` | 362 |
| `lib/presentation/state/lists_provider.dart` | `listsNotifierProvider` (Listen inkl. Realtime, Offline-Cache, Widget-Update), `userListsProvider` | 226 |
| `lib/presentation/state/shopping_history_provider.dart` | `recentHistoryProvider` (letzte 5 Einkäufe) | 102 |
| `lib/data/services/avo_nudge_service.dart` | Rhythmus-Logik, Angebots-Abgleich (marktguru), Schlummer-Speicher, 6-h-Cache, `openItemNamesLower` | 673 |
| `lib/data/services/calorie_recipe_nudge_service.dart` | Rest-Kalorien heute, Rezept-Ranking (Diät, Allergien, Listen-Treffer, zuletzt gekocht), „heute ausgeblendet“ | 274 |
| `lib/data/services/home_price_comparison_cache_service.dart` | 6-h-Cache und Ausblenden für den Preisvergleich | 101 |
| `lib/data/services/split_nudge_cache_service.dart` | Ausblenden der Teilen-Karte pro Einkauf | 37 |
| `lib/data/services/mascot_notification_service.dart` | Avo-Benachrichtigungen (Nachkauf morgens, Abendessen-Ideen) aus denselben Daten wie die Karten | 360 |
| `lib/core/mascot/avo_mascot.dart` | Avo-Maskottchen als PNG (`assets/avo/avo_*.png`), 8 Ausdrücke auf 4 Bilder, optionale Sprechblase | 129 |
| `lib/core/constants/paper_colors.dart` | `PaperColors`, `PaperTextStyles.serif/kicker` (Georgia), von der Startseite stark genutzt | ca. 70 |
| `lib/presentation/screens/main_scaffold.dart` | Schwebende Tab-Pille + Avo-Orb (zweiter Avo-Einstieg), Tab 0 heißt „Listen“ | 518 |
| `test/home_nudge_card_order_test.dart` | Unit-Test für die Karten-Reihenfolge | – |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Startseite (`HomeScreen`)

- **Datei:** `home_screen.dart`
- **Route/Einstieg:** `/home`, Branch 0 der `StatefulShellRoute` (`app_router.dart:162-172`), Tab „Listen“ in der schwebenden Pille. Start-Route für angemeldete Nutzer (`app_router.dart:107`).
- **Hauptfrage heute (unklar):** Der Screen versucht, gleichzeitig „Welche Listen habe ich?“, „Was sollte ich nachkaufen?“, „Was ist im Angebot?“, „Wer schuldet wem Geld?“ und „Was esse ich heute Abend?“ zu beantworten. Es gibt keine eine Hauptfrage. Laut Plan soll sie werden: „Was kaufe ich heute ein?“
- **Aufbau von oben nach unten** (`CustomScrollView`, `home_screen.dart:208-634`):
  1. `CupertinoSliverRefreshControl` mit eigenem Indikator (214-252), lädt nur die Listen neu.
  2. `SliverSafeArea` nur für den oberen Abstand (254-258).
  3. `GreetingHeader` (260-268): Datumszeile („Samstag, 7. November“), darunter serifig „Guten Morgen,\nName.“, rechts Avatar (36 pt). Klappt beim Scrollen weg (Opacity, Scale, Translate), nicht angeheftet.
  4. Avo-Hinweisstreifen (270-321): cremefarbene Box, Blatt-Icon, „Avo: Fehlt was? Frag mich nach Rezepten.“, rechts „Zeigen“ in Terrakotta. Tipp öffnet `/avo`.
  5. `PendingSplitsBanner` (323).
  6. Bis zu fünf Karten in Prioritätsreihenfolge (334-335): Teilen, Avo-Nachkauf, Prospekt, Kalorien-Rezepte, Preisvergleich.
  7. Abschnittskopf „DEINE LISTEN“ als Großbuchstaben-Kicker, rechts „+ Neue Liste“ als Text-Button (341-377). Langes Drücken auf „+ Neue Liste“ = Liste beitreten.
  8. Listen-Index (384-485): alle Listen, nach `updatedAt` sortiert, als `_PaperListRow`: serifige Nummer „01“, Name (Serif 18), Status „noch 3 Artikel · geteilt“, Personen-Icon bei geteilt, darunter 2,5-pt-Fortschrittslinie.
  9. Angebote-Streifen (491-569): Cremeblock, Kicker „ANGEBOTE“, darunter Serif „N Angebote passend zu deinen Listen“ bzw. „Angebote der Woche aus deinen Märkten“, Pfeil. Öffnet `WeeklyDealsScreen`.
  10. Verlaufszeile (575-619): Haarlinie oben, Glocken-Icon, „Zuletzt eingekauft: Liste · 3. Nov.“, Chevron. Öffnet `ShoppingHistoryScreen`.
  11. Fester Leerraum 200 pt + Safe Area unten (627-633) für die schwebende Tab-Pille.
- **Komponenten:** `GreetingHeader`, `NudgeCardShell`/`NudgeCard`, `AvoNudgeCard`, `PersonalFlyerCard`, `CalorieRecipeNudgeCard`, `PendingSplitsBanner`, `SplitTripNudgeCard`, `PriceComparisonNudgeCard`, `_PaperListRow`, `_LatestActivityLine`, `AvoMascot` (22 pt in Karten).
- **Zustände:**
  - *Laden (Listen):* Nur beim allerersten Laden, 140 pt hoher Bereich mit `CupertinoActivityIndicator` (465-468). Danach Seed aus `_lastKnown` bzw. Offline-Cache (`lists_provider.dart:50-54, 89-97`), also meist kein Spinner.
  - *Laden (Karten):* kein Platzhalter. Jede Karte ist `SizedBox.shrink()`, bis ihre Daten da sind, und springt dann ins Layout (Layout-Sprung).
  - *Leer:* Karte 140 pt mit „Noch keine Listen“, ohne Aktion (389-411). Im aktiven Tutorial wird automatisch „Meine erste Liste“ angelegt (112-151).
  - *Fehler:* Karte 140 pt mit „Fehler beim Laden“, ohne Wiederholen (469-483). Bei Netzfehler mit vorhandenem Cache werden die gecachten Listen gezeigt.
  - *Offline:* auf der Startseite kein eigener Zustand. `isOfflineProvider` wird nur in `main_scaffold.dart` ausgewertet. Karten verschwinden still (Services fangen Fehler und liefern leere Listen).
  - *Pro gesperrt:* keiner. Nichts auf der Startseite prüft `isPremium`.
  - *Modul aus:* keiner. Es gibt noch keine Modul-Schalter. Die Kalorien-Karte erscheint nur, wenn Kalorien-Tracking an ist und ein Ziel gesetzt ist (`calorie_recipe_nudge_service.dart:49-64`). Angebote-Karten erscheinen nur mit echter PLZ. Der Angebote-Streifen erscheint **immer**.
- **Aktionen und Gesten:**
  - Ziehen zum Aktualisieren (nur Listen).
  - Avatar tippen: `/profile` (264).
  - Avo-Streifen tippen: `/avo` (280).
  - „+ Neue Liste“ tippen: Eingabe-Alert (640-686). Lange drücken: Beitreten per Code (688-782).
  - Listenzeile tippen: `/lists/:id?name=` (446-455), schließt den Tutorial-Schritt ab. Lange drücken: Löschen mit destruktiver Bestätigung (784-804).
  - Angebote-Streifen tippen: `WeeklyDealsScreen` (507-515, mit `HapticFeedback.selectionClick`).
  - Verlaufszeile tippen: `ShoppingHistoryScreen` (582-589).
  - Scrollstart nimmt den Tastaturfokus weg (201-207).
  - Keine Wisch-Aktionen, kein Kontextmenü, kein Umsortieren der Listen (obwohl `reorderLists` im Notifier existiert, `lists_provider.dart:192-215`).
- **Datenquellen:** `listsNotifierProvider`, `currentUserProvider` (Name, Avatar, `appPriorities`), `recentHistoryProvider`, `personalizedDealsProvider`, plus alle Karten-Provider (siehe 2.3-2.8). Services: `SupabaseService` (Auth-Listener), `DynamicTutorialService`, `WidgetService.syncCredentialsFromSession` (153-155).
- **Sichtbare Texte (DE):** „Guten Morgen / Guten Tag / Guten Abend“, „Avo: Fehlt was? Frag mich nach Rezepten.“, „Zeigen“, „DEINE LISTEN“, „+ Neue Liste“, „Noch keine Listen“, „Fehler beim Laden“, „noch {n} Artikel“, „alles erledigt“, „leer“, „geteilt“, „ANGEBOTE“, „{count} Angebote passend zu deinen Listen“, „Angebote der Woche aus deinen Märkten“, „Zuletzt eingekauft:“, „Einkaufsverlauf“, „Liste erstellt“.

### 2.2 Begrüßungskopf (`GreetingHeader`)

- **Datei:** `widgets/greeting_header.dart`
- **Hauptfrage:** „Wer bin ich, welcher Tag ist heute?“ Dekorativ, keine Handlung außer Avatar.
- **Aufbau:** Datum (13 pt, sekundär), 4 pt, Gruß „{Gruß},\n{Name}.“ (Georgia 27, Zeilenhöhe 1,2, max. 2 Zeilen), rechts `CircleAvatar` Radius 18 mit Netzwerkbild oder Initiale (Serif 15 auf Creme).
- **Logik:** Gruß nach Uhrzeit: vor 11 Uhr Morgen, vor 18 Uhr Tag, sonst Abend (80-85). `minExtent` 60, `maxExtent` 130 (21-25). Name über `DisplayNameHelper.getDisplayName`, Fallback „User“.

### 2.3 Avo-Karte: Nachkaufen und Rhythmus-Angebote (`AvoNudgeCard`)

- **Datei:** `widgets/avo_nudge_card.dart`
- **Hauptfrage:** „Was geht mir wahrscheinlich bald aus?“
- **Aufbau:** Kopfzeile mit Avo (22 pt, nachdenklich) und Kicker „WAHRSCHEINLICH FAST LEER“ oder „FÜR DICH IM ANGEBOT“. Darunter bis zu 3 Nachkauf-Zeilen (Name, „Etwa alle 7 Tage · zuletzt vor 9 Tagen“ oder „· meistens sonntags“, optional Angebotszeile in Akzentfarbe „Frische Vollmilch · −23 % · 0.99 € · Lidl“), dann bis zu 2 Angebotszeilen für Rhythmus-Artikel ohne Nachkauf-Zeile. Jede Zeile: Text „Hinzufügen“, „x“ zum Schlummern.
- **Zustände:** nichts zu tun: unsichtbar. Laden/Fehler: unsichtbar.
- **Aktionen:** Zeile oder „Hinzufügen“ tippen fügt zur **zuletzt geänderten Liste** hinzu, inklusive Angebotspreis (111-167), dann SnackBar „{item} zu „{list}“ hinzugefügt“. „x“: Nachkauf schlummert einen eigenen Rhythmus lang (mind. 2 Tage), Angebot bis Ablauf oder 7 Tage (`avo_nudge_service.dart:544-616`).
- **Daten:** `restockSuggestionsProvider` (limit 3), `offerNudgesProvider` (Top 2 von 12), `userListsProvider`, `itemsNotifierProvider(listId)`. Service: `AvoNudgeService` mit `item_purchase_stats`, `OfferPriceService` (marktguru), `UserLocationService` (nur echte PLZ, kein Berechtigungsdialog).
- **Regeln im Service, die bleiben müssen:** mind. 2 Käufe; Rhythmus 2-60 Tage; nicht mehr vorschlagen ab 4-fach überfällig; Wochentags-Muster (mind. 3 Käufe am selben Tag und mind. die Hälfte); Ranking `dueness * habitStrength`; nichts vorschlagen, was schon offen auf einer Liste steht (fail closed); Angebots-Treffer nur, wenn der Artikel das Kopfwort ist („Milchreis“ ist keine Milch, `offerMatchesItem` 447-478); kein erfundener Rabatt, „−X %“ nur bei vom Händler genanntem Normalpreis; Stammmarkt bevorzugt, außer ein anderer ist mehr als 0,50 € günstiger (507-542); max. 6 Angebotssuchen pro 6 h.

### 2.4 Prospekt (`PersonalFlyerCard`)

- **Datei:** `widgets/personal_flyer_card.dart`
- **Hauptfrage:** „Welche meiner Stammartikel sind diese Woche wo im Angebot?“
- **Aufbau:** Karte (Radius 20, Rahmen, Schatten). Kopf: Serif „Dein Prospekt“, „{count} Sachen, die du regelmäßig kaufst, sind gerade im Angebot.“, Zähler-Pille. Je Markt ein Abschnitt: Marktname als Großbuchstaben-Kicker (10 pt), Haarlinie, „spart X €“ (nur bei genannten Normalpreisen, ab 0,20 €). Zeilen: Artikel, Produktname, Preis, „−X %“.
- **Zustände:** unter 3 Angeboten unsichtbar (`_minDeals`, 24/33).
- **Aktionen:** keine auf der Startseite. `onSelect` ist auf der Startseite `null` (`home_screen.dart:813`), die Zeilen sind nicht tippbar.
- **Daten:** `personalFlyerProvider` (gleiche Berechnung wie `offerNudgesProvider`, `groupOffersByRetailer`).

### 2.5 Kalorien-Rezepte (`CalorieRecipeNudgeCard`)

- **Datei:** `widgets/calorie_recipe_nudge_card.dart`
- **Hauptfrage:** „Was kann ich heute noch essen?“
- **Aufbau:** Kopf mit Avo (fröhlich), Kicker „NOCH 312 KCAL · IDEEN FÜRS ABENDESSEN“, „x“. Bis zu 3 Rezeptzeilen: Bild 38x38, Name, „450 kcal · 25 Min.“, optional „Nutzt Zwiebel, Tomate von deiner Liste“, Chevron.
- **Zustände:** unsichtbar, wenn Tracking aus, kein Ziel, weniger als 150 kcal übrig, kein passendes Rezept mit gespeicherten Nährwerten, oder heute ausgeblendet.
- **Aktionen:** Zeile tippen: `/recipes/:id`. „x“: für heute ausblenden.
- **Daten:** `remainingCaloriesTodayProvider`, `calorieRecipeSuggestionsProvider` (Diät, Allergien aus `currentUserProvider`), `calorieNudgeDismissedProvider`. Service: `NutritionGoalService`, `FoodLogService`, `RecipeService` (gespeichert, beliebt, neu), `AvoNudgeService.openItemNamesLower`.

### 2.6 Offene Aufteilungen (`PendingSplitsBanner`)

- **Datei:** `widgets/pending_splits_banner.dart`
- **Hauptfrage:** „Wer schuldet wem noch Geld?“
- **Aufbau:** Karte mit Zeilen: Pfeil runter (Akzent) „{Name} schuldet dir 4.20 € · {Liste}“ + „Als bezahlt markieren“; Pfeil hoch (Terrakotta) „Du schuldest {Name} 4.20 €“ + „Zurückgezahlt“.
- **Zustände:** alles beglichen: unsichtbar.
- **Aktionen:** Zeile tippen: `ShoppingHistoryScreen`. Schnellaktion: `setPaid(id, true)` sofort, ohne Rückgängig.
- **Daten:** `tripsAwaitingPaymentToMeProvider`, `tripsIOweProvider`, `expenseSplitServiceProvider`.

### 2.7 Einkauf teilen (`SplitTripNudgeCard`)

- **Datei:** `widgets/split_trip_nudge_card.dart`
- **Hauptfrage:** „Soll ich den letzten gemeinsamen Einkauf aufteilen?“
- **Aufbau:** `NudgeCard` mit Personen-Icon: „„{Liste}“ mit deiner Gruppe teilen?“, „≈ 23.40 € gesamt — antippen zum Teilen“.
- **Zustände:** nur bei geteiltem, abgeschlossenem, noch nicht aufgeteiltem Einkauf der letzten 7 Tage.
- **Aktionen:** Tippen: `showSplitCostSheet` (Sheet aus dem Bereich Verlauf). „x“: für diesen Einkauf ausblenden.
- **Daten:** `unsplitTripNudgeProvider`, `SplitNudgeCacheService`, `authUserProvider`.

### 2.8 Preisvergleich (`PriceComparisonNudgeCard`) – verworfen

- **Datei:** `widgets/price_comparison_nudge_card.dart`
- **Inhalt:** „{Liste} ist bei {A} 2.30 € günstiger als bei {B}“, „Basierend auf 5 von 9 Artikeln mit aktuellen Angeboten“. Tipp öffnet die Liste, „x“ blendet genau diesen Vergleich aus.
- **Daten:** `homePriceHighlightProvider` → `basketComparisonProvider` (bis 25 marktguru-Suchen), `HomePriceComparisonCacheService`.
- **Status:** Widerspricht dem Plan (kein „günstigster Markt / Korbsumme pro Markt“, kein „bei X wäre es Y € günstiger“). Im Redesign entfällt die Karte samt Provider-Pfad für die Startseite.

### 2.9 Dialoge

| Dialog | Datei:Zeile | Einstieg | Inhalt |
|---|---|---|---|
| Neue Liste | `home_screen.dart:640-686` | „+ Neue Liste“ tippen | `AdaptiveAlertDialog.inputShow` (natives Alert mit Textfeld, SF Symbol `list.bullet.circle.fill`), „Abbrechen“/„Erstellen“; danach SnackBar „Liste erstellt“ oder „Fehler: {Exception}“ |
| Liste beitreten | `home_screen.dart:688-782` | „+ Neue Liste“ **lange** drücken | Alert mit Code-Feld, Großschreibung; Erfolg-, Ungültig- und Fehler-Alert (Fehler zeigt rohe Exception) |
| Liste löschen | `home_screen.dart:784-804` | Listenzeile lange drücken | `confirmDestructive` mit Icon 48, danach `deleteList`; Fehler als SnackBar „action_failed“ |
| Angebote | `weekly_deals_screen.dart` | Angebote-Streifen | Eigener Screen mit Material-`AppBar`, Suchfeld, „passend zu deinen Listen“, Sheet „Zur Einkaufsliste hinzufügen“ (Details: Inventar history) |

---

## 3. Design-Probleme heute

### 3.1 Abweichungen von den Apple-Regeln

- **Keine Navigationsebene, keine Hauptfrage.** Kein großer Titel, keine Toolbar, keine Scroll-Edge-Effekte. Inhalte scrollen unter die Statusleiste ohne Kante (`home_screen.dart:254-268`). Wayfinding fehlt: der Tab heißt „Listen“ (`main_scaffold.dart`), der Screen sagt „Guten Morgen“.
- **Zwei Avo-Einstiege** (Plan: genau einer): Hinweisstreifen `home_screen.dart:279-280` und Avo-Orb `main_scaffold.dart:337`.
- **Startseite ist nicht „die Liste von heute“**, sondern ein Index aller Listen unter bis zu sechs Karten (`home_screen.dart:323-485`).
- **Reihen gleichartiger Karten** (Anti-Slop): Teilen, Nachkauf, Prospekt, Kalorien, Preisvergleich und Schulden sind gestapelte Karten mit gleicher Hülle (`nudge_card.dart:21-39`, `home_screen.dart:334-335`).
- **Icon im getönten Kreis** (Anti-Slop): `nudge_card.dart:104-113`.
- **Material-Icons statt SF Symbols:** `Icons.eco_outlined` (292), `Icons.arrow_forward` (558), `Icons.notifications_none` als Symbol für den Verlauf, also falsche Metapher (601), `Icons.chevron_right` (610), `Icons.people_outline` (931), `Icons.close_rounded` (`nudge_card.dart:66`, `avo_nudge_card.dart:381`), `Icons.savings_outlined` (`price_comparison_nudge_card.dart:23`), Pfeile in `pending_splits_banner.dart:40,66`.
- **Touch-Ziele unter 44 pt:** „+ Neue Liste“ als 12-pt-Text ohne Padding (`home_screen.dart:361-372`); Schließen-„x“ 16 pt + 4 pt Padding = 24 pt (`nudge_card.dart:57-71`); „Hinzufügen“ 11,5 pt mit 6 pt Padding (`avo_nudge_card.dart:360-374`); Schlummer-„x“ (375-386); Schnellaktion „Als bezahlt markieren“ nur `left: 8` Padding (`pending_splits_banner.dart:140-152`); Avatar 36 pt (`greeting_header.dart:123-124`).
- **Versteckte Funktionen:** Beitreten nur per langem Druck auf einen Text (`home_screen.dart:363`); Löschen nur per langem Druck auf die Zeile (457), ohne Kontextmenü-Vorschau. Apple-Muster wären Kontextmenü, Wischaktion und ein „+“-Menü in der Toolbar.
- **Ganze Zeile fügt hinzu:** In der Avo-Karte löst ein Tipp irgendwo auf die Zeile das Hinzufügen aus (`avo_nudge_card.dart:315-316`). Kein Rückgängig, keine Wahl der Liste.
- **Material-SnackBar statt iOS-Rückmeldung:** `home_screen.dart:674-683`, `avo_nudge_card.dart:152-162`. Kein Rückgängig-Angebot (Agency).
- **Material-Effekte:** `InkWell`-Ripple in `avo_nudge_card.dart:315`, `calorie_recipe_nudge_card.dart:109`, `pending_splits_banner.dart:123`; `MaterialPageRoute` für Angebote und Verlauf (`home_screen.dart:509-514, 583-588`; `pending_splits_banner.dart:94-96`), dadurch keine go_router-Route und kein Deep Link.
- **Bewegung:** Header-Kollaps über lineare Opacity/Scale/Translate (`greeting_header.dart:29-58`); Refresh-Indikator mit `AnimatedContainer` 200 ms `Curves.easeOut` (`home_screen.dart:168-170`). Keine Federn, keine Reduce-Motion-Beachtung. Karten erscheinen ohne Übergang (Sprung).
- **Haptik inkonsistent:** `selectionClick` beim Öffnen der Angebote (508), `lightImpact` beim Hinzufügen, `mediumImpact` schon beim langen Druck vor dem Löschdialog (785). Keine Erfolgs-Haptik nach Hinzufügen.
- **Harte Trennlinien:** Haarlinie über der Verlaufszeile (`home_screen.dart:593-597`), Haarlinie in Prospekt-Abschnitten (`personal_flyer_card.dart:155-160`), Rahmen um jede Karte (`nudge_card.dart:34`, `personal_flyer_card.dart:42`).
- **Ecken nicht konzentrisch:** 6 pt (Streifen, 288 und 524), 14 pt (Karten), 20 pt (Prospekt), 28 pt (`AppDimensions.cardBorderRadius` bei Leer/Fehler), 8 und 10 pt (Rezeptbild, InkWell). Kein Bezug zueinander oder zu den Geräteecken.
- **Pro-Flächen fehlen** komplett: keine Kennzeichnung, keine kontextuellen Hinweise.

### 3.2 Feste Größen, die bei großer Schrift oder 320 pt Breite brechen

- **Header-Höhe fest 60/130 pt** (`greeting_header.dart:21-25`), Inhalt: 24 + Datum 13 pt + 4 + zwei Zeilen Serif 27 bei 1,2 + 8. Bei 1,0 rund 117 pt, ab ungefähr Dynamic-Type „xxxLarge“ (Faktor ca. 1,35) über 130 pt, also Überlauf/Abschneiden. Es gibt keine Begrenzung des `textScaler` in `app.dart`/`main.dart` (grep ohne Treffer), die Schrift skaliert also voll.
- **Feste 140-pt-Kästen** für Leer, Laden und Fehler (`home_screen.dart:395, 466, 474`).
- **Fester Leerraum unten 200 pt** (`home_screen.dart:631`) statt der echten Höhe der Tab-Pille (`MainScaffold.getNavbarTopOffset` existiert, `main_scaffold.dart:160-164`).
- **Seitenrand 24 pt** (`AppDimensions.screenHorizontalPadding`, `app_dimensions.dart:3`), bei Karten zusätzlich 14 pt Innenabstand. Bei 320 pt Breite bleiben für Text in einer Avo-Zeile ca. 320 − 48 − 28 − „Hinzufügen“ − „x“ ≈ 150 pt; bei großer Schrift wird der Artikelname auf wenige Zeichen gekürzt (`avo_nudge_card.dart:319-386`).
- **Feste Schriftgrößen ohne Textstile:** 9,5 bis 27 pt verstreut, darunter unter Apples Minimum von 11 pt: 10 pt (`personal_flyer_card.dart:148`), 10,5 pt (169). Weitere: 11 / 11,5 / 12 / 12,5 / 13 / 14,5 / 15 pt in allen Karten. Keine Verbindung zu Dynamic-Type-Stilen (Body, Subheadline, Footnote …).
- **Überall `maxLines: 1` + Ellipse** bei Inhalten: Avo-Streifen (301-302), Listenname (908-909), Karten-Titel und Untertitel (`nudge_card.dart:131-132`, `avo_nudge_card.dart:327-328, 339-340, 348-349`, `calorie_recipe_nudge_card.dart:52-53, 143-144`, `personal_flyer_card.dart:214-215`). Bei großer Schrift wird Inhalt abgeschnitten statt umzubrechen.
- **Rezeptbild fest 38x38** (`calorie_recipe_nudge_card.dart:120-131`), Avo 22 pt fest, Fortschrittslinie 2,5 pt (`home_screen.dart:936`).
- **Zeilen ohne Umbruch-Alternative:** Kopfzeile der Liste (`Row` mit `spaceBetween`, 347-375) und Prospekt-Abschnittskopf (`personal_flyer_card.dart:143-176`) haben kein Umbruchverhalten. Bei großer Schrift und 320 pt kollidieren Text und Aktion.
- **Prospekt ohne Seitenrand:** `PersonalFlyerCard` hat nur `margin: bottom 24` (`personal_flyer_card.dart:38`) und steht direkt in einem `SliverToBoxAdapter` (`home_screen.dart:335`). Die Karte läuft also randlos von Kante zu Kante, anders als alle anderen Karten mit 24 pt.

### 3.3 Paper-Reste

- **Serife (Georgia):** Gruß (`greeting_header.dart:109-113`), Avatar-Initiale (132-135), Listennummer und -name (`home_screen.dart:899, 910`), Angebote-Text (549-552), Prospekt-Titel (`personal_flyer_card.dart:84-87`).
- **Großbuchstaben-Kicker:** „DEINE LISTEN“ (`home_screen.dart:352-358`), „ANGEBOTE“ (533-539), Avo-Karten-Titel (`avo_nudge_card.dart:56-68`), Kalorien-Titel (`calorie_recipe_nudge_card.dart:49-59`), Marktnamen im Prospekt (`personal_flyer_card.dart:146-152`), „PASSEND ZU DEINEN LISTEN“ (`weekly_deals_screen.dart:274`).
- **Creme/Terrakotta, nicht adaptiv (bleibt im Dunkelmodus hell):** `Color(0xFFEFE8DA)` und Textfarbe `0xFF5A5346` (`home_screen.dart:287, 305`), `PaperColors.sageInk` (295), `PaperColors.terracotta` für „Zeigen“ (313) und für „Du schuldest“ (`pending_splits_banner.dart:67`), `PaperColors.cream`/`creamInk` und `0xFF4A4232` im Angebote-Streifen (523, 538, 551, 560), Avatar-Hintergrund Creme (`greeting_header.dart:125, 134`).
- **Editorial-Index** mit „01, 02 …“ statt Listen-Zeilen (`home_screen.dart:417-418, 897-900`).
- **Nur-Hell-Farbe im Dunkelmodus:** `AppColors.lightTextSecondary` beim Leerzustand (`home_screen.dart:406`).
- **Blasser Fließtext:** Status- und Untertitel durchgehend in `textSecondary` mit 11,5-12,5 pt (Anti-Slop: Fließtext in voller Textfarbe).

---

## 4. Bugs, Risiken und Performance-Probleme

1. **Verworfene Funktion aktiv:** Preisvergleich „bei A X € günstiger als bei B“ (`price_comparison_nudge_card.dart:24-29`, `price_comparison_provider.dart:196-292`). Der Plan verlangt, dass „günstigster Korb“ nirgends mehr steht.
2. **Angebote können „anderer Markt ist günstiger“ zeigen:** `pickOffer` ersetzt den Stammmarkt, wenn ein anderer Markt mehr als 0,50 € günstiger ist (`avo_nudge_service.dart:536-537`). Laut Konzept sollen pro Liste nur die Angebote des erkannten Markts erscheinen.
3. **Teurer Home-Besuch:** Beim ersten Öffnen starten parallel bis zu ca. 15 Abfragen: Listen, Nutzer, Verlauf, 2x Splits, Split-Kandidat, Kaufstatistik, offene Artikel, PLZ plus bis zu 6 sequenzielle marktguru-Suchen (`avo_nudge_service.dart:398-418`), Ziel und Essens-Log, 3 Rezept-Pools plus kürzlich gekocht, Artikel von bis zu 5 Listen plus **bis zu 25 parallele marktguru-Suchen** für den Preisvergleich (`price_comparison_provider.dart:100-117`), Artikel von 2 Listen plus `getMatches` für den Angebote-Streifen. Caches (6 h) dämpfen das, aber jeder Cache-Fehlschlag kostet viel.
4. **Realtime-Leck im Preisvergleich:** `_computeAndCacheHighlight` nutzt `ref.watch(basketComparisonProvider(listId).future)` (`price_comparison_provider.dart:241`), und `basketComparisonProvider` beobachtet `itemsNotifierProvider(listId)` (100). Damit wird genau die Realtime-Subscription pro Liste geöffnet, die der Kommentar in 296-298 vermeiden will.
5. **Layout springt:** Alle Karten erscheinen erst nach Datenankunft (`SizedBox.shrink` vorher), dadurch rutschen die Listen nach unten, während der Nutzer schon tippen will. Widerspricht „nie sichtbares Laden“.
6. **Ziehen zum Aktualisieren lädt nur die Listen** (`home_screen.dart:250-251`), nicht Karten, Angebote, Verlauf oder Splits.
7. **Deutsche Preise mit Punkt:** `toStringAsFixed(2)` statt `NumberFormat` ergibt „0.99 €“ in der deutschen Oberfläche: `avo_nudge_card.dart:193, 202`, `personal_flyer_card.dart:166, 242`, `price_comparison_nudge_card.dart:26`, `split_trip_nudge_card.dart:33`, `pending_splits_banner.dart:46, 71`.
8. **Angebote-Zähler ohne Region:** `personalizedDealsProvider` nutzt `effectiveZipProvider` mit bundesweitem Fallback (`price_comparison_provider.dart:301`), der Streifen sagt aber „aus deinen Märkten“ bzw. zählt bundesweite Treffer als „passend zu deinen Listen“ (`home_screen.dart:501-548`). Die Avo-Karte dagegen verlangt eine echte PLZ. Das ist inkonsistent und kann irreführen.
9. **Prospekt nicht bedienbar:** `onSelect` ist auf der Startseite nicht gesetzt (`home_screen.dart:813`), die Angebotszeilen reagieren nicht.
10. **Hinzufügen landet in irgendeiner Liste:** Avo-Karte nimmt stets die zuletzt geänderte Liste (`avo_nudge_card.dart:124-127`). Keine Listen-Wahl, kein Rückgängig; ohne Listen passiert still nichts (122). Fehler nur im Log (164-166).
11. **„Als bezahlt markieren“ ohne Fehlerbehandlung und ohne Rückgängig:** `await setPaid(...)` ohne try/catch (`pending_splits_banner.dart:55-59, 80-84`). Ein Netzfehler wirft eine unbehandelte Ausnahme.
12. **Löschen geteilter Listen:** `deleteList` löscht per `delete().eq('id')` (`list_repository.dart:114-116`). Für Mitglieder, die nicht Eigentümer sind, greift vermutlich RLS still (0 Zeilen), die Liste taucht nach dem Neuladen wieder auf. Es gibt kein „Liste verlassen“. (Plausibel, RLS nicht geprüft.)
13. **Rohe Fehlertexte für Nutzer:** `'${context.tr('error')}: $e'` (`home_screen.dart:682`) und `'${context.tr('join_error')}: $e'` (767).
14. **Fallback-Name „User“ unübersetzt:** `DisplayNameHelper.getDisplayName` gibt „User“ zurück (`display_name_helper.dart:12-14`). Die Begrüßung lautet dann „Guten Morgen,\nUser.“
15. **Datumsformat fest deutsch:** `'EEEE, d. MMMM'` (`greeting_header.dart:90`) und `'d. MMM'` (`home_screen.dart:837`) auch im Englischen („Saturday, 7. November“).
16. **Gruß veraltet:** `shouldRebuild` vergleicht nur Name und Avatar (`greeting_header.dart:63-66`). Bleibt die App offen, bleibt „Guten Morgen“ über 11 Uhr hinaus stehen.
17. **Avatar ohne Fehler-Handling:** `NetworkImage` ohne `onBackgroundImageError` und ohne Cache (`greeting_header.dart:126-127`). Ein toter Link erzeugt Bildfehler im Log und keine Initiale.
18. **Allergie-Filter naiv (Responsibility/KI-Sicherheit):** Allergien werden nur als Teilstring in Zutatennamen gesucht (`calorie_recipe_nudge_service.dart:211-215`). Eine deutsch eingetragene Allergie („Erdnüsse“) findet englische Zutaten („peanuts“) nicht. Spuren und Zutaten-Untergruppen werden nicht erkannt.
19. **„Ideen fürs Abendessen“ zu jeder Tageszeit:** Der Titel ist fest (`app_translations.dart`, `calorie_nudge_title`), auch um 8 Uhr morgens.
20. **SharedPreferences nicht pro Konto:** Schlummer-Liste, Angebots-Cache, Preisvergleich-Cache und Split-Ausblendung (`avo_nudge_service.dart:143-145`, `home_price_comparison_cache_service.dart:23-24`, `split_nudge_cache_service.dart:18`, `calorie_recipe_nudge_service.dart:43`) gelten gerätweit. Nach einem Kontowechsel wirken alte Schlummer-Einstellungen weiter.
21. **Tutorial legt automatisch eine Liste an** (`home_screen.dart:140-150`), auch nach bewusstem Löschen der letzten Liste, solange der Tutorial-Schritt `openShoppingList` aktiv ist (86-93).
22. **Kein Offline-Zustand:** Ohne Netz verschwinden Karten kommentarlos. Es gibt keine Rückmeldung und keinen Hinweis, dass Daten veraltet sein könnten.

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Listen:** `/lists/:id?name=` (Listen-Detail), `listsNotifierProvider` (Realtime, Offline-Cache, Widget-Listen, Quick-Add-Vorschläge in `loadLists`), `itemsNotifierProvider` (Hinzufügen aus Avo-Karte), `ItemRepository.getItemsForLists`. Der Listen-Index der Startseite ist heute die einzige Listen-Übersicht.
- **Verlauf/Kosten teilen:** `ShoppingHistoryScreen`, `showSplitCostSheet` (`history/widgets/split_cost_sheet.dart`), `expense_split_provider.dart`, `ExpenseSplitService`.
- **Angebote (Bereich history):** `WeeklyDealsScreen`, `personalizedDealsProvider`, `OfferPriceService`, `PersonalizedDealsService`, `UserLocationService`, `StoreLocatorService`. Künftig: Modul-Schalter, Remote-Kill-Switch, Markt pro Liste (`shopping_lists.store_chain` noch nicht vorhanden).
- **Rezepte:** `/recipes/:id`, `RecipeService` (saved/popular/recent).
- **Kalorien:** `NutritionGoalService`, `FoodLogService`, `whatCanIEatSuggestionsProvider` teilt das Ranking mit der Startseite, `calorieTrackingEnabledProvider` (Tab-Sichtbarkeit in `main_scaffold.dart`).
- **Avo:** `/avo` (`AvoChatScreen`), Avo-Orb in `main_scaffold.dart`, `AvoMascot` und `assets/avo/*.png`, `MascotNotificationService` (nutzt `AvoNudgeService` und `CalorieRecipeNudgeService` für Push um 8 Uhr bzw. abends; `app.dart:48-49, 176-177`, `main.dart:153-163`, `avo_settings_bridge.dart:307-309`).
- **Profil:** Avatar führt nach `/profile`; `currentUserProvider` (Name, Avatar, `appPriorities`, `dietPreferences`, `allergies`).
- **Onboarding:** `kAppPriorities` (`lib/core/constants/app_priorities.dart`) und `onboarding_priorities_page.dart` steuern die Karten-Reihenfolge; `recipe_personalization.dart` nutzt dieselbe Konvention.
- **Tutorial:** `DynamicTutorialService` (`firstListCardKey`, Schritt `openShoppingList`, `homeTabKey` in `main_scaffold.dart`).
- **Widgets (iOS):** `WidgetService.syncCredentialsFromSession` beim Start und Kontowechsel der Startseite (`home_screen.dart:153-155`), `WidgetService.updateAvailableLists` und `updateRecentItems` in `ListsNotifier.loadLists`.
- **Navigation/Shell:** `MainScaffold` (schwebende Pille, Bottom-Inset), `SlidingTabsContainer`, `app_router.dart` (Redirects auf `/home`, ausstehende Deep Links auf `/home`, 436-450).
- **Gemeinsame Bausteine:** `confirm_dialog.dart` (`confirmDestructive`), `adaptive_platform_ui` (`AdaptiveAlertDialog`, `PlatformInfo.isIOS26OrHigher`), `PaperColors`/`PaperTextStyles` (werden auch in Auth/Onboarding und `paper_settings.dart` genutzt), `AppColors`, `AppDimensions`, `AppTextStyles`.
- **Strings:** `app_translations.dart` Schlüssel `greeting_*`, `avo_hint_home`, `show_label`, `your_lists`, `new_list_plus`, `no_lists_yet`, `deals_*`, `last_shopped_prefix`, `items_left`, `all_done_label`, `list_empty_label`, `shared_label`, `restock_*`, `offer_nudge_*`, `calorie_nudge_*`, `home_price_highlight_*` (zu löschen), `split_trip_nudge_*`, `owed_to_me_line`, `i_owe_line`, `mark_as_paid`, `i_paid_back`, `flyer_*`, `my_first_list`, `create_new_list`, `join_list`, `enter_share_code`, `joined_*`, `invalid_share_code`; plus `AppLocalizations.deleteList*`.
- **Tests:** `test/home_nudge_card_order_test.dart`; Logik-Tests mit Bezug: `avo_personalized_deals_logic_test.dart`, `avo_price_compare_logic_test.dart`, `offer_price_stem_test.dart`.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**
- Schneller Zugriff auf alle Listen inklusive geteilter Listen, Fortschritt (offen/erledigt/leer) und Kennzeichnung „geteilt“. Wenn die Startseite „die Liste von heute“ wird, braucht es einen gleichwertigen Weg zu allen anderen Listen (Umschalter oder Übersicht).
- Liste anlegen, Liste per Code beitreten, Liste löschen mit echter Bestätigung (endgültig). Dazu fehlt heute „Liste verlassen“ für Mitglieder.
- Ziehen zum Aktualisieren (künftig für alle Daten der Seite).
- Avo-Nachkauf-Vorschläge mit Ein-Tipp-Hinzufügen und Schlummern, inklusive Wochentags-Satz („meistens sonntags“).
- Rhythmus-Artikel im Angebot (nur mit echter PLZ, nur echte Treffer, Rabatt nur bei vom Händler genanntem Normalpreis, als „laut Händler“ kennzeichnen), künftig auf den Markt der Liste beschränkt und als abschaltbares Modul.
- Kalorien-Rezeptideen mit Diät- und Allergiefilter, Bevorzugung von Zutaten auf der Liste, Vermeidung kürzlich gekochter Gerichte, „heute ausblenden“.
- Offene Aufteilungen (wer schuldet wem) mit Schnellaktion und der Vorschlag, den letzten gemeinsamen Einkauf aufzuteilen.
- Einstieg in Verlauf und Angebote.
- Avatar/Profil-Zugang und ein persönlicher Moment (Gruß), aber nicht auf Kosten der Hauptfrage.

**Daten und Logik (nicht neu erfinden)**
- `AvoNudgeService`: Schwellen, Ranking (`habitStrength`, `suggestionPriority`), `dominantWeekday`, `offerMatchesItem`, Ausschluss offener Artikel (fail closed), Schlummer-Dauer, 6-h-Cache, max. 6 Suchen, kein Berechtigungsdialog im Hintergrund.
- `CalorieRecipeNudgeService.rankSuggestions` und die 150-kcal-Grenze; nur Rezepte mit gespeicherten Nährwerten, nie eine KI-Schätzung beim Anzeigen.
- `orderedHomeNudgeCards`-Idee: Onboarding-Prioritäten bestimmen, was zuerst kommt (künftig über Module).
- `ListsNotifier`: Seed aus letztem Stand und Offline-Cache (kein Spinner beim zweiten Öffnen), Realtime mit 400-ms-Entprellung, Vorwärmen der Listen-Artikel, Widget-Updates.
- Dismiss-Semantik: Teilen-Karte pro Einkauf, Kalorien-Karte pro Tag, Angebote bis Ablauf.
- `MascotNotificationService` nutzt dieselben Berechnungen; Änderungen an den Services wirken auch auf Push.

**Sonderfälle**
- Neu angemeldet ohne Listen und aktives Tutorial: erste Liste wird angelegt, `firstListCardKey` muss am ersten Listeneintrag hängen.
- Kontowechsel: Listen neu laden, Verlauf invalidieren, Widget-Credentials neu synchronisieren (`home_screen.dart:71-80`).
- Kein Standort bzw. nur bundesweite PLZ: keine „in deiner Nähe“-Aussagen.
- Kalorien-Tracking aus oder ohne Ziel: keine Kalorien-Fläche.
- Geteilte Liste, die man nicht besitzt.
- Lange Listennamen, Namen und Marktnamen bei großer Schrift und 320 pt Breite.
- Hell und dunkel, Reduce Motion, Reduce Transparency, VoiceOver (heute keine Semantik-Labels auf der Startseite außer den Tab-Labels).
- Kein Name gesetzt oder E-Mail als Name: neutraler, übersetzter Gruß.
