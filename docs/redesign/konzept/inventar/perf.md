# Inventar: Tempo, Daten und Start (Ist-Zustand, Stand 2026-11-07)

Grundlage für das Redesign. Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf `main` (3e886d0). Paketversionen laut `pubspec.lock`: supabase_flutter 2.10.3, flutter_riverpod 2.6.1, go_router 13.2.5, connectivity_plus 5.0.2, cached_network_image 3.4.1, adaptive_platform_ui 0.1.100.

Kurzfassung: Die Datenschicht ist besser als ihr Ruf. Es gibt optimistische Item-Mutationen mit Rollback, einen In-Memory-Spiegel des Offline-Caches für den ersten Frame, Realtime nur solange eine Liste beobachtet wird, und einen Start, der vor `runApp` nur Supabase abwartet. Trotzdem fühlt sich die App langsam und fehlerhaft an. Die Ursachen sind konkret:

1. **Kaltstart ohne lokalen Stand:** Die Listen kommen beim Kaltstart immer zuerst aus dem Netz. Der Offline-Cache wird nur nach einem Netzfehler gelesen. Ergebnis: Spinner auf der Startseite, und bei schlechtem Netz im Supermarkt bis zum HTTP-Timeout.
2. **Kein Schreiben ohne Netz:** Es gibt keine Warteschlange. Abhaken ohne Netz springt still zurück, ohne Meldung.
3. **App-weiter Remount nach dem Start:** Theme und Sprache laden asynchron. Die ganze App hängt an `ValueKey('$themeMode-$languageCode')` und wird nach dem ersten Frame komplett neu aufgebaut (bis zu zweimal).
4. **Inhalte erscheinen nachträglich:** Bis zu sechs Startseiten-Karten, der Kalorien-Tab und der Pro-Status kommen erst nach Netzantworten. Dadurch springt das Layout.
5. **Hinzufügen wartet auf die KI:** Gemini-Parse plus Gemini-Kategorie laufen seriell hinter einem 1,1-s-Tor und vor dem Insert. "2 Milch" braucht ohne Cache mindestens 2,2 s plus vier Roundtrips, bis die echte Zeile steht. In der Zwischenzeit springt der Artikel.
6. **Ein Abhaken kostet etwa zehn Netzaufrufe** (Update, Touch, Push-Fan-out, Listen-Reload, Kaufstatistik, zwei Angebots-Scans der im Hintergrund lebenden Startseite, Echo-Reload).
7. **Keine Timeouts** auf Supabase- und Gemini-Aufrufen, keine Skeletons, 62 Spinner-Stellen.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/main.dart` | Start: Orientierung, `SupabaseService.initialize()` (blockiert vor `runApp`), Connectivity, danach Hintergrund-Init (Firebase, Gemini, IAP, AppReview, Notifications/FCM), Auth-Seiteneffekte (Widget-Credentials, Cache leeren, Reminder) | 175 |
| `lib/app.dart` | `AvoApp`: `AdaptiveApp.router` mit Remount-Key aus Theme und Sprache, Deep Links, Siri-Handler, Account-Wechsel-Invalidierung, Statusbar-Stil, `ScaffoldMessenger` und `TutorialOverlay` | 233 |
| `lib/routes/app_router.dart` | GoRouter: `initialLocation` aus Session, async `redirect` (Onboarding-Flag aus SharedPreferences, memoisiert), `StatefulShellRoute` mit 4 Branches, `/lists/:listId` außerhalb der Shell | 466 |
| `lib/presentation/screens/main_scaffold.dart` | `SlidingTabsContainer` (Tab-Wechsel als horizontales Schieben, 320 ms), Paper-Navbar, Offline-Banner | 518 |
| `lib/core/services/service_locator.dart` | **Existiert nicht.** CLAUDE.md beschreibt ein `Services.x`-Muster, im Code gibt es nur `XService.instance` | 0 |
| `lib/data/services/supabase_service.dart` | Supabase-Init, Auth (E-Mail, Apple, Google, OTP-Reset), dünne Wrapper `from`/`storage`/`channel` | 266 |
| `lib/data/services/offline_cache_service.dart` | SharedPreferences-Cache (Rezepte, Listen, Items pro Liste, Profil für Router) mit In-Memory-Spiegel für Items und Rezepte; `clearCache` bei Logout | 289 |
| `lib/data/services/connectivity_service.dart` | `connectivity_plus`-Wrapper, `connectivityProvider`, `isOfflineProvider` | 65 |
| `lib/data/repositories/item_repository.dart` | Items: Laden, Hinzufügen (Gemini-Parse, Merge, Gemini-Kategorie, Insert), Update, Toggle, Delete, Reorder, `_touchList`, Realtime-Kanal pro Liste, Push-Fan-out | 407 |
| `lib/data/repositories/list_repository.dart` | Listen mit Zähl-Embeds in einem Roundtrip, CRUD, Teilen/Beitreten, globaler Realtime-Kanal `db_changes` (alle Items und Listen) | 308 |
| `lib/presentation/state/lists_provider.dart` | `ListsNotifier` (Seed aus statischem `_lastKnown`, Realtime-Debounce 400 ms, Cache, Widget-Update), `userListsProvider` | 226 |
| `lib/presentation/state/items_provider.dart` | `ItemsNotifier` (Seed aus Memory-Cache, Generationszähler, optimistisches `_mutate` mit Rollback, Realtime an Listener gekoppelt, Debounce 300 ms, Widget-Update) | 451 |
| `lib/presentation/state/auth_provider.dart` | `authUserProvider` (Stream), `authUserIdProvider` (nur bei Accountwechsel), `currentUserProvider` (users-Zeile, Onboarding-Antworten anwenden, Profil cachen, 30-s-Retry) | 119 |
| `lib/presentation/state/theme_provider.dart` | Theme-Modus (Start: hell, dann lokal, dann Supabase), Akzentfarbe (zuerst Supabase, dann lokal) | 142 |
| `lib/presentation/state/language_provider.dart` | Sprache (Start: Systemsprache, dann gespeicherte Wahl) | 59 |
| `lib/presentation/state/recipes_provider.dart` | `recipesProvider` (Netz zuerst, Cache nur bei Exception) | 30 |
| `lib/presentation/state/saved_recipes_provider.dart` | Gespeicherte Rezepte, Widget-Update | 162 |
| `lib/presentation/state/shopping_history_provider.dart` | Verlauf (3 Provider, ohne Cache) | 102 |
| `lib/presentation/state/nutrition_provider.dart` | Kalorien: 10 autoDispose-FutureProvider ohne Cache, `invalidateNutritionLog` invalidiert 7 auf einmal | 161 |
| `lib/presentation/state/calorie_tracking_provider.dart` | Schalter für den Kalorien-Tab (Start: aus, dann lokal, dann Server) | 57 |
| `lib/presentation/state/avo_nudge_provider.dart` | Startseiten-Nudges (Nachkauf, Angebote, Prospekt), geteilter In-flight-Future | 87 |
| `lib/presentation/state/calorie_recipe_nudge_provider.dart`, `expense_split_provider.dart`, `diet_challenge_provider.dart`, `last_list_provider.dart` | Weitere autoDispose-FutureProvider ohne Cache | 49 / 59 / 28 / 50 |
| `lib/presentation/providers/subscription_provider.dart` | Pro-Status als Stream, Produkte, Kauf/Restore | 113 |
| `lib/presentation/providers/price_comparison_provider.dart` | PLZ/GPS, Angebotssuche, `basketComparisonProvider` (bis 25 Artikel parallel), `homePriceHighlightProvider`, `personalizedDealsProvider` | 362 |
| `lib/presentation/providers/recipe_offers_provider.dart`, `ml_recommendations_provider.dart` | Rezept-Angebote, Empfehlungen pro Liste | 49 / 39 |
| `lib/data/services/gemini_categorization_service.dart` | Gemini 2.0 flash-lite: Kategorie, Parse, Empfehlungen; 1100-ms-Warteschlange; Cache als ein JSON-String in SharedPreferences | 432 |
| `lib/data/services/avo_assistant_service.dart` | Avo-Chat (Gemini 2.0 flash-lite, Function Calling bis 4 Runden) plus zwei Einmal-Modelle für Nährwerte | ca. 1900 |
| `lib/data/services/meal_photo_analysis_service.dart` | Mahlzeiten-Foto mit Gemini 2.0 flash (multimodal) | ca. 90 |
| `lib/data/services/offer_price_service.dart` | marktguru-Suche: 30-min-Speichercache, In-flight-Dedupe, 250-ms-Throttle, 12-s-Timeout | 343 |
| `lib/data/services/user_location_service.dart` | GPS zu PLZ, Koordinaten-Cache, fragt standardmäßig nach Standortrechten | 249 |
| `lib/data/services/subscription_service.dart` | StoreKit-Init, Status `unknown` bis Cache/Server geladen | 497 |
| `lib/data/services/notification_service.dart`, `fcm_service.dart` | Lokale Notifications und FCM; Berechtigung wird beim Start abgefragt | – |
| `lib/data/services/push_notification_service.dart` | Fan-out an Listenmitglieder über Edge Function | ca. 150 |
| `lib/data/services/widget_service.dart`, `ios/Runner/AppDelegate.swift` | App-Group-Daten und `WidgetCenter`-Reloads | – |
| `lib/presentation/widgets/common/loading_indicator.dart` | Zentrierter `CupertinoActivityIndicator` mit optionalem Text | 30 |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Native Launch-Ansicht: Systemhintergrund plus `LaunchImage` 168x185 | – |

---

## 2. Screens, Sheets und Dialoge

Dieser Bereich hat kaum eigene Screens. Er besteht aus den Zuständen, die jeder Screen durchläuft: Start, Laden, Offline, Fehler, Berechtigungsdialoge. Deshalb sind diese Zustände hier als Oberflächen beschrieben.

### 2.1 Native Launch-Screen
- **Datei:** `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- **Einstieg:** Kaltstart, bis Flutter den ersten Frame zeichnet.
- **Hauptfrage:** "Startet die App?"
- **Aufbau:** Vollfläche in `systemBackgroundColor` (weiß oder schwarz), mittig `LaunchImage` (Avo-Motiv, 168x185 pt).
- **Zustände:** keine.
- **Problem:** Der erste Flutter-Frame ist Paper-Creme `#F7F3EC` (`paper_colors.dart:9`) und standardmäßig hell, auch wenn das System im Dunkelmodus ist. Dadurch gibt es einen Farbsprung, im Dunkelmodus einen hellen Blitz (siehe 3.1).

### 2.2 Startphase und erster Frame
- **Dateien:** `lib/main.dart:26-50`, `lib/app.dart`, `lib/routes/app_router.dart:106-449`
- **Ablauf:**
  1. `setPreferredOrientations` wird abgewartet.
  2. `SupabaseService.initialize()` wird abgewartet: Session aus dem Speicher lesen, Deep-Link-Setup.
  3. `ConnectivityService.initialize()` wird nicht abgewartet.
  4. `runApp`.
  5. Danach parallel: Auth-Listener, `warmRecipes`, Firebase plus Analytics, Gemini-Init (lädt Kategorie-Cache), IAP-Init, AppReview, Notifications (Berechtigungsdialog), FCM.
- **Router:** `initialLocation` ist `/home`, wenn eine Session existiert, sonst `/onboarding`. Der async `redirect` liest einmal `hasCompletedOnboarding()` aus SharedPreferences (`app_router.dart:398`) und blockiert damit den allerersten Frame bis zu diesem Read. Er macht keine Netzabfrage.
- **Danach im ersten Frame:** Theme startet hell (`theme_provider.dart:33`), Sprache startet als Systemsprache, Kalorien-Tab startet aus (`calorie_tracking_provider.dart:25`), Pro-Status ist `unknown` (`subscription_service.dart:40`). Alle vier Werte werden asynchron korrigiert, siehe 3.1 und 4.1.
- **Datenquellen:** SharedPreferences (27 Dateien mit 76 `getInstance()`-Aufrufen), Supabase, StoreKit.

### 2.3 Offline-Banner
- **Datei:** `lib/presentation/screens/main_scaffold.dart:224-232`, Widget `_OfflineBanner` `:458-517`
- **Einstieg:** automatisch über `isOfflineProvider`, sobald `connectivity_plus` "none" meldet.
- **Hauptfrage:** "Bin ich offline?"
- **Aufbau:** schwebende Kapsel oben mittig, Wolke-durchgestrichen-Icon plus Text "Offline". Gleitet mit 320 ms und `easeOutCubic` herein. `IgnorePointer`.
- **Zustände:** sichtbar oder unsichtbar. Es gibt keinen Zustand "Verbindung schlecht" und keinen für "ausstehende Änderungen".
- **Lücken:**
  - Der Banner steht nur in der Tab-Shell. Die Listenansicht `/lists/:listId` liegt außerhalb der Shell (`app_router.dart:298`) und zeigt ihn nie, obwohl dort im Laden Offline am häufigsten ist.
  - Der Text "Offline" ist hart codiert und nicht lokalisiert (`main_scaffold.dart:501`).
  - "Netzwerk vorhanden" wird mit "Internet erreichbar" gleichgesetzt (`connectivity_service.dart:42`). Captive Portal oder Funkloch im Markt zählen also als online.

### 2.4 Ladezustände (Spinner-Katalog)
- **Komponenten:** `LoadingIndicator` (`widgets/common/loading_indicator.dart`), inline `CupertinoActivityIndicator`, Material `CircularProgressIndicator`.
- **Umfang:** 62 Treffer, davon 18 Material-Spinner (alle im Kalorien- und Verlaufsbereich: `calories_screen.dart:41,347`, `food_entry_sheet.dart` 3x, `challenges_screen.dart` 2x, `what_can_i_eat_screen.dart` 2x, `split_cost_sheet.dart` 2x, `shopping_history_screen.dart`, `item_offer_sheet.dart`, `zip_code_sheet.dart`, `goal_setup_screen.dart`, `weekly_summary_screen.dart`, `weight_tracking_screen.dart`, `step_progress_ring.dart`). Es gibt keine Skeletons und keine Platzhalter mit der Form des Inhalts.
- **Wichtigste Stellen:**

| Stelle | Datei:Zeile | Wann sichtbar |
|---|---|---|
| Listen auf der Startseite | `home_screen.dart:465-468` (140 pt Box) | Jeder Kaltstart, bis `getUserLists()` antwortet |
| Items der Liste ("Artikel werden geladen...") | `list_detail_screen.dart:385-386` | Wenn der Memory-Cache für diese Liste nicht vorgewärmt ist: Widget- oder Siri- oder Deep-Link-Kaltstart, Offline-Kaltstart |
| Kalorien-Tab komplett | `calories_screen.dart:41` | Jeder Besuch nach Kaltstart (`nutritionGoalProvider` autoDispose, ohne Cache) |
| Tageslog Kalorien | `calories_screen.dart:345-348` | Bei jedem Tageswechsel im Day-Switcher |
| Rezept-Detail per Deep Link | `recipe_detail_screen.dart:148` | Wenn kein `initialRecipe` übergeben wurde |
| Rezepte-Tab | `recipes_screen.dart:550` | Nur ohne vorgewärmten Rezept-Cache |
| Pull-to-Refresh Startseite | `home_screen.dart:157-191` | Eigener nachgebauter Cupertino-Refresh |

- **Texte:** "Artikel werden geladen..." / "Loading items...", "Fehler beim Laden" / "Error loading data".

### 2.5 Fehlerzustände
- **Startseite:** feste 140-pt-Box mit "Fehler beim Laden" (`home_screen.dart:469-482`), ohne Erneut-Button. Erscheint nur, wenn das Netz scheitert und der Listen-Cache leer ist.
- **Liste:** zentrierter Text "Fehler beim Laden" (`list_detail_screen.dart:387-388`), ohne Aktion.
- **Kalorien:** Fehler zeigt den Untertitel einer Karte (`calories_v0_card_sub`, `calories_screen.dart:42-43`), also fachlich falschen Text.
- **Abhaken oder Löschen fehlgeschlagen:** keine Anzeige. Das Häkchen springt still zurück (`items_provider.dart:189-195`, Aufrufer `list_item_tile.dart:88-93` wartet nicht und fängt nicht ab).
- **Rezepte offline:** Der gesäte Cache-Inhalt wird durch eine leere Liste ersetzt (siehe 4.2).

### 2.6 System-Berechtigungsdialoge beim Start
- **Push:** `NotificationService.initialize()` mit `requestAlertPermission: true` (`notification_service.dart:51-55`) läuft direkt nach dem ersten Frame in `_initializeServicesInBackground` (`main.dart:83`). Der iOS-Dialog erscheint beim allerersten Start über dem Onboarding, ohne Kontext. FCM fragt auf Android noch einmal (`fcm_service.dart:41`).
- **Standort:** `effectiveZipProvider` ruft `getZipInfo()` mit `allowPermissionPrompt = true` auf (`price_comparison_provider.dart:23-25`). Die Startseite beobachtet `personalizedDealsProvider` und `homePriceHighlightProvider`. Der Standortdialog erscheint also beim ersten Besuch der Startseite, ohne Erklärung.

### 2.7 Avo-Chat: Bereitschaft und Wartezeit
- **Datei:** `avo_assistant_service.dart:91-118,150-215`, Init beim Öffnen des Chats (`avo_chat_screen.dart:129`).
- **Zustände:** "I'm not ready yet — give me a moment!" (`:158-161`, englisch hart codiert), Quota-Fehler und allgemeiner Fehler ebenfalls nur englisch (`:205-213`).
- **Wartezeit:** Antwort ohne Streaming (`sendMessage`, nicht `sendMessageStream`). Bis zu 5 Gemini-Roundtrips nacheinander (1 plus 4 Function-Call-Runden). Kein Timeout.

### 2.8 Widget-Datenfluss (unsichtbar, aber spürbar)
- Jeder Commit einer Liste führt zu `updateShoppingListWidget` und damit zu `reloadTimelines(ShoppingListWidget)` (`items_provider.dart:128-154`, `AppDelegate.swift:130`).
- Jedes `loadLists` führt zu `updateAvailableLists`, zu einer `item_purchase_stats`-Abfrage und zu `updateRecentItems` (`lists_provider.dart:84-88,104-118`).
- Die Widget-Credentials werden an drei Stellen synchronisiert: `main.dart:131-135`, `home_screen.dart:56,74`.

---

## 3. Design-Probleme heute

### 3.1 Abweichungen von den Apple-Regeln
- **Start-Flackern statt ruhigem Übergang:**
  - Launch-Screen in Systemfarbe (`LaunchScreen.storyboard:24`), danach Paper-Creme hell.
  - `ThemeModeNotifier` startet fest hell (`theme_provider.dart:33`) und ignoriert für neue Nutzer den System-Dunkelmodus. Apple verlangt adaptive Farben.
  - Danach `ValueKey('$themeMode-$languageCode')` an `AdaptiveApp.router` (`app.dart:188`): Weicht der gespeicherte Wert ab, wird die gesamte App nach dem ersten Frame neu montiert. Danach kann `userPreferencesProvider` aus Supabase ein zweites Mal umschalten (`theme_provider.dart:48-53`).
  - Sichtbar: Blitz, verlorener Scroll- und Eingabezustand, doppelte `initState`-Arbeit.
- **Tab-Wechsel ist keine iOS-Geste:** `SlidingTabsContainer` schiebt die Tabs horizontal mit fester Dauer 320 ms und `easeOutCubic` (`main_scaffold.dart:53,85`). Von Tab 0 nach Tab 3 werden alle Zwischen-Tabs mit gelayoutet und gezeichnet (`:101-102`). iOS-Tab-Bars wechseln ohne Schiebe-Animation. Regel: Federn statt fester Dauern.
- **Navbar wächst linear mit der Bildschirmbreite** (`MainScaffold.navScale`, `main_scaffold.dart:144-147`, Basis 300 pt). Sie reagiert nicht auf Dynamic Type. Das ist keine native Tab-Bar und kein Liquid Glass (Details im Inventar `shell.md`).
- **Inhalte springen nachträglich ins Layout:**
  - Fünf Nudge-Karten (`home_screen.dart:333-335`, Karten in `home/widgets/*`) plus `PendingSplitsBanner` rendern während des Ladens `SizedBox.shrink()` und erscheinen dann ohne Übergang. Die Listen darunter rutschen nach unten. Keine der Karten nutzt `AnimatedSize` oder `AnimatedSwitcher`.
  - Der Kalorien-Tab erscheint erst nach dem SharedPreferences-Read in der Navbar (`calorie_tracking_provider.dart:25-32`).
- **Offline-Banner:** feste Dauern (`main_scaffold.dart:468-473`), Material-Icon `Icons.cloud_off_rounded` statt SF Symbol, deckt den Navigationsbereich oben ab und kann nicht bedient werden.
- **Material-Spinner auf iOS:** 18 `CircularProgressIndicator` (siehe 2.4).
- **Fehler ohne Weg hinaus:** Fehlerzustände zeigen keine Aktion ("Erneut versuchen"). Fehlgeschlagene Schreibvorgänge zeigen gar nichts (2.5). Das verletzt Wayfinding und Agency.
- **Berechtigungen ohne Kontext:** Push beim ersten Start, Standort beim ersten Startseiten-Besuch (2.6). Apple verlangt die Abfrage im Moment des Nutzens, mit Erklärung vorher.
- **Pull-to-Refresh nachgebaut** (`home_screen.dart:157-191,208-247`) mit `AnimatedContainer` 200 ms. Das native Verhalten wäre `CupertinoSliverRefreshControl` mit Standard-Builder.

### 3.2 Feste Höhen, Breiten und Schriftgrößen (brechen bei großer Schrift oder 320 pt)
- **Startseite:**
  - Leer-, Lade- und Fehlerbox mit fester Höhe `height: 140` (`home_screen.dart:395,466,474`). Bei Bedienungshilfen-Größen kann der Fehlertext abgeschnitten werden.
  - Feste Schriftgrößen 11 und 12 ohne Textstil (`home_screen.dart:304,312,354,368,535,828,925`). Sie skalieren zwar mit dem Textscaler, liegen aber unter der iOS-Mindestgröße für Fließtext.
- **Offline-Banner:** `fontSize: 13`, feste Ränder links und rechts 24 pt (`main_scaffold.dart:227-228,500-503`). Bei 320 pt und sehr großer Schrift passt es noch, weil der Text kurz ist.
- **Schriftfamilie:**
  - `AppTextStyles.fontFamily = 'Satoshi'` (`app_text_styles.dart:5-6`), die Schrift ist aber nicht im `pubspec.yaml` gebündelt. Es fällt still auf die Systemschrift zurück. Das ist gewollt-ungewollt und sollte explizit SF Pro sein.
  - Paper-Serife `Georgia` (`paper_colors.dart:32`).
- Es gibt keine globale Begrenzung des Textscalers (`grep textScaler` findet nichts). Das ist gut. Feste Container um Text brechen deshalb aber tatsächlich.

### 3.3 Paper-Reste in diesem Bereich
- Kicker in Großbuchstaben mit `letterSpacing: 2` über "Deine Listen" (`home_screen.dart:351-357,533-537`).
- Creme-Box `#EFE8DA` und Terrakotta-Link (`home_screen.dart:287,313`).
- Offline-Banner in `PaperColors.surface`/`ink`/`hairline` (`main_scaffold.dart:478-485`).
- Seiten- und Navbar-Hintergrund `PaperColors.paper`, Navbar-Pille `PaperColors.ink` (`main_scaffold.dart:211,218`).
- Fallback-Flächen für Bilder in `PaperColors.cream` (`weekly_deals_screen.dart:379`, `offer_suggestions_bar.dart:305`, `recipe_offers_card.dart:122`).
- Google-Logo-Fallback in `PaperColors.creamInk` (`google_logo.dart:16`).

---

## 4. Bugs, Risiken und Performance-Probleme

### 4.1 Start und erster Frame
1. **App-Remount nach Start** (`app.dart:188`, `theme_provider.dart:33,44-53`, `language_provider.dart:28-39`). Jede Abweichung zwischen Startwert und gespeichertem Wert baut den kompletten Widget-Baum neu.
   - `HomeScreen.initState` läuft doppelt (Tutorial-Liste, Widget-Sync).
   - `RecipesScreen` startet `_loadAllData` doppelt.
   - Texteingaben gehen verloren.
   - Dasselbe passiert bei jedem Theme- oder Sprachwechsel in den Einstellungen.
2. **Pro-Status flackert:** `SubscriptionStatus.unknown` ist bis zu `_iap.isAvailable()` und `_loadCachedStatus()` gesetzt (`subscription_service.dart:40,64-74`). `isSubscribedProvider` liefert bis dahin `false` (`subscription_provider.dart:28-35`). Pro-Nutzer sehen kurz Sperren oder Paywall-Hinweise.
3. **Akzentfarbe:** Supabase zuerst, lokal nur als Fallback (`theme_provider.dart:94-114`). Beim Start blinkt Systemblau, bis das Netz antwortet. Offline kommt die Akzentfarbe erst nach dem Netzfehler.
4. **Kalorien-Tab springt in die Navbar** (`calorie_tracking_provider.dart:25-32`). Zusätzlich kann der Server-Abgleich ihn wieder entfernen. Das löst `goBranch(home)` aus (`main_scaffold.dart:202-209`).
5. **Push-Berechtigung beim ersten Start** (`main.dart:83,108-116`, `notification_service.dart:51-55`), siehe 2.6.
6. **Kein SharedPreferences-Vorladen:** 76 verstreute `getInstance()`-Aufrufe in 27 Dateien, jeder Notifier lädt asynchron und korrigiert danach. Ein einmaliges Laden vor `runApp` mit Provider-Override würde 1, 3 und 4 und den Theme-Teil von Punkt 1 synchron lösen.
7. **Große Blobs in NSUserDefaults:**
   - Alle Rezepte als JSON-Liste (`offline_cache_service.dart:56-65`), alle Items jeder Liste, der Gemini-Kategorie-Cache als ein String, der bei jeder neuen Kategorie komplett neu geschrieben wird (`gemini_categorization_service.dart:62-69,113-114`).
   - SharedPreferences lädt auf iOS die ganze Plist beim ersten `getInstance()`. Wachsende Blobs verlangsamen den Start und jedes Schreiben.
   - Der Kategorie-Cache hat keine Obergrenze.
8. **CLAUDE.md beschreibt einen Service-Locator, den es nicht gibt**. Neue Sessions suchen sonst danach.

### 4.2 Laden und Cache
1. **Listen beim Kaltstart immer aus dem Netz** (`lists_provider.dart:36-37,50-54,63-68`). `_lastKnown` ist nur statischer Speicher. Der SharedPreferences-Listencache wird nur im `catch` gelesen (`:89-97`). Ohne Netzfehler, aber mit langsamem Netz, bleibt der Spinner (`home_screen.dart:465`) bis zur Antwort stehen. Supabase-Abfragen haben keinen Timeout (in `lib/data` gibt es `.timeout` nur in 5 Dateien, keine davon ist ein Repository). Im Funkloch dauert es bis zum URLSession-Standard-Timeout.
2. **Offline-Kaltstart wärmt keine Items vor:** `warmListItems` wird nur im Erfolgszweig aufgerufen (`lists_provider.dart:80-82`), nicht wenn die Listen aus dem Cache kommen (`:92-96`). Öffnet man offline eine Liste, zeigt sie erst einen Spinner und den Inhalt erst nach dem gescheiterten Netzaufruf (`items_provider.dart:104-122`).
3. **Rezepte offline werden gelöscht statt gezeigt:**
   - `RecipeService._fetchAllRecipes` fängt Fehler ab und gibt `[]` zurück (`recipe_service.dart:91-95`). Deshalb greift der Fallback in `recipesProvider` (`recipes_provider.dart:25-28`) nie.
   - Stattdessen schreibt `recipesProvider` die leere Liste in den Offline-Cache (`recipes_provider.dart:23`), und `RecipesScreen._loadAllData` überschreibt den gesäten Inhalt mit `[]`.
   - Folge: Nach einem Offline-Start ist auch der nächste Start leer.
4. **Komplette Rezepttabelle ohne Limit** (`recipe_service.dart:78-81`) plus Autoren-Join. Das wächst mit jedem Community-Rezept und wird komplett in SharedPreferences gespiegelt.
5. **Kalorien ohne lokalen Stand:** Alle Provider in `nutrition_provider.dart` sind autoDispose ohne Cache. Der Tab zeigt bei jedem Kaltstart einen Vollbild-Spinner. Ein Tageswechsel zeigt einen Spinner (`skipLoadingOnReload` wird nirgends genutzt). Offline ist der Tab unbenutzbar. Nach jedem Eintrag werden 7 Provider invalidiert (`:153-161`), also 7 Roundtrips. Es gibt keine optimistischen Updates.
6. **Verlauf ohne Cache**, `loadHistory` setzt immer `loading` (`shopping_history_provider.dart:47-49`).
7. **Startseiten-Fan-out beim ersten Frame:** `currentUserProvider`, Listen, `tripsAwaitingPaymentToMe`, `tripsIOwe`, `unsplitTripNudge`, `restockSuggestions`, `offerNudges` plus `personalFlyer` (geteilt), `remainingCalories` plus `calorieRecipeSuggestions`, `homePriceHighlight` (Standort, Items-Scan, bis 25 Angebotsabfragen), `personalizedDeals`, `recentHistory`. Das sind mehr als 12 parallele Ketten, jede mit eigenem Layout-Sprung.
8. **Bilder:**
   - 11 `Image.network` ohne Disk-Cache und ohne Decode-Größe in scrollenden Listen: `weekly_deals_screen.dart:371`, `offer_suggestions_bar.dart:297`, `item_offer_sheet.dart:218`, `recipe_offers_card.dart:114`, `food_log_tile.dart:75`, `food_entry_sheet.dart:506`, `avo_payload_cards.dart:150`, `list_settings_screen.dart:281`, `google_logo.dart:11`.
   - Dazu `NetworkImage` für Avatare (`greeting_header.dart:127`, `item_form_dialog.dart:504`, `display_name_screen.dart:293`).
   - Mahlzeitenfotos werden mit 1024 px Breite hochgeladen (`food_entry_sheet.dart:84`) und in der Log-Zeile auf 32 pt in voller Auflösung decodiert (`food_log_tile.dart:75`).
   - Das Google-Logo wird bei jedem Login-Screen von `google.com/favicon.ico` geladen.
   - `CachedNetworkImage` ist dagegen meist sauber mit `memCacheWidth` (Rezepte).
   - `precacheImage` wird nirgends genutzt.

### 4.3 Schreiben, Sync und Realtime
1. **Kein Offline-Schreiben:** `_mutate` setzt optimistisch, `write()` scheitert, dann Rollback und Reload (`items_provider.dart:164-203`). Es gibt keine Warteschlange und keinen Status "ausstehend". Im Laden ohne Netz geht jedes Häkchen verloren.
2. **Stilles Scheitern beim Abhaken:** `list_item_tile.dart:88-93` ruft `toggleItemChecked` ohne `await` und ohne `catch` auf. Der Fehler wird erneut geworfen (`items_provider.dart:195`) und landet als unbehandelte Async-Exception. Der Nutzer sieht nur, dass das Häkchen zurückspringt.
3. **Rollback überschreibt parallele Änderungen:** `before` ist ein Snapshot vor der Mutation (`items_provider.dart:169,192`). Scheitert die erste von zwei schnellen Änderungen, verschwindet auch die zweite optimistische Änderung bis zum Reload.
4. **Abhaken eines noch ausstehenden Artikels:**
   - Während `addItem` auf Gemini wartet, trägt der Artikel die ID `pending-…` (`items_provider.dart:250`).
   - Ein Tipp darauf ruft `updateItem(..).single()` mit einer nicht existierenden ID auf (`item_repository.dart:244-249`). Das scheitert, und die Änderung wird zurückgerollt.
   - Gleiches gilt für Löschen und Bearbeiten.
5. **Hinzufügen blockiert auf KI** (`item_repository.dart:106-125,167-178`). Ohne Cache läuft es in dieser Reihenfolge:
   1. Gemini-Parse (nur bei Ziffer im Text), danach mindestens 1,1 s Pause.
   2. Merge-Abfrage.
   3. Gemini-Kategorie, wieder mindestens 1,1 s seit dem letzten Aufruf.
   4. Insert.
   5. `_touchList`.

   Bis dahin zeigt die Liste "2 Milch" mit Menge 1 ohne Kategorie. Dann springt der Eintrag zu "Milch" mit Menge 2 in seinen Gang. Die Keyword-Klassifizierung (`ProductClassifierService`) läuft nur als Fallback, obwohl sie lokal und sofort wäre. Beim Foto-Import (`importItems`, `:323-332`) geht jeder Artikel einzeln durch das 1,1-s-Tor: 20 Artikel brauchen also mindestens 22 s.
6. **Kosten pro Abhaken** (private Liste, gemessen am Code):
   - `update` und `_touchList`: 2 Aufrufe (`item_repository.dart:258-266,320-329`).
   - Push-Fan-out: Listenname, Anzeigename, `list_members`, bei Mitgliedern zusätzlich `users` plus eine Edge Function pro Token (`:377-405`, `push_notification_service.dart:18-40,115-140`).
   - Eigenes Realtime-Echo: Item-Reload.
   - Globaler Kanal: Listen-Reload mit Zähl-Embeds (`lists_provider.dart:56-61`), daraus `item_purchase_stats` und ein Widget-Reload.
   - Die im Tab-Stack lebende Startseite reagiert auf die geänderte `uncheckedCount`: `personalizedDealsProvider` und `homePriceHighlightProvider` laufen erneut, je mit `getItemsForLists`. Bei neuer Namensmenge gibt es einen Cache-Miss auf `HomePriceComparisonCacheService`, und Angebotsabfragen werden nur durch den 30-min-Speichercache abgefangen (`price_comparison_provider.dart:196-230,327-341`).

   In Summe sind das etwa 10 Netzaufrufe pro Häkchen, bei geteilten Listen mehr.
7. **Push bei jedem einzelnen Häkchen** an alle Mitglieder (`item_repository.dart:267-276`). Die Texte sind englisch hart codiert ("checked off", "removed", "Someone"). Für geteilte Listen ist das Spam, und der Plan verlangt "kein Benachrichtigungs-Spam".
8. **Kein Nachladen nach Rückkehr in die App:** Realtime liefert verpasste Events nicht nach. `AppLifecycleState.resumed` wird nur in `app.dart:174` für Reminder behandelt. Eine offene Liste bleibt nach längerem Hintergrund veraltet, bis das nächste Event kommt. Das ist kritisch für "Abgehaktes erscheint live".
9. **Globaler Realtime-Kanal ohne Filter** (`list_repository.dart:281-301`). Jede Änderung an irgendeinem sichtbaren Item oder irgendeiner Liste löst einen vollen `getUserLists()` aus. `_touchList` erzeugt zu jedem Item-Event zusätzlich ein Listen-Event, das nur durch den Debounce zusammenfällt. Der Kanalname `db_changes` ist fest, und `unsubscribeFromItemChanges` setzt das Feld auf `null`. Bei überlappendem Neuaufbau des Notifiers kann der neue Kanal vom alten `dispose` geschlossen werden (Risiko, nicht beobachtet).
10. **Mehrfache Auth-Listener** mit überlappender Arbeit: `main.dart:124`, `app.dart:51`, `home_screen.dart:69` (ruft `loadLists` zusätzlich zum ohnehin neu gebauten Notifier), `avo_assistant_service.dart:105`, `GoRouterRefreshStream`, `authUserProvider`.
11. **Item-Notifier sind nicht autoDispose** (`items_provider.dart:438-451`). Jede jemals geöffnete Liste und jede Liste, die `basketComparisonProvider` von der Startseite aus beobachtet (`price_comparison_provider.dart:146-150`), behält ihren Notifier samt Items im Speicher. Realtime wird zwar korrekt geschlossen, der Speicher aber nicht freigegeben.

### 4.4 KI-Aufrufe und Wartezeiten
1. **Keine Timeouts** auf `generateContent` und `sendMessage`: `gemini_categorization_service.dart:128ff,305ff`, `avo_assistant_service.dart:176,189,468,1834`, `meal_photo_analysis_service.dart:62`.
2. **Uneinheitliches Rate-Limit:** Nur `GeminiCategorizationService` hält die 1100-ms-Regel ein. Avo-Chat, Nährwert-Schätzungen und Foto-Analyse rufen ohne Tor auf. Die Projektregel aus CLAUDE.md wird also teilweise verletzt.
3. **Fünf `GenerativeModel`-Instanzen**, davon zwei pro Aufruf neu gebaut (`avo_assistant_service.dart:448,1817`).
4. **Avo antwortet ohne Streaming** und mit bis zu 5 Roundtrips nacheinander (`avo_assistant_service.dart:176-190`). Ein Sprachmodus (Plan) braucht Streaming und geringe Latenz.
5. **API-Schlüssel im Client:** `Env.geminiApiKey` wird in die App kompiliert. Der Plan sagt "alle KI über Claude". Das sollte serverseitig (Edge Function) laufen, auch wegen Schlüsselschutz und Rate-Limit pro Nutzer.
6. **Kategorie-Cache-Schlüssel hängt an der Spracherkennung** (`'${language}_$normalizedName'`, `gemini_categorization_service.dart:103`). Dasselbe Wort wird bei unsicherer Erkennung doppelt angefragt.

### 4.5 Verschiedenes
- `builder` in `app.dart:221-223` registriert bei jedem Build einen Post-Frame-Callback für `SystemChrome`.
- Gleiches Muster in `main_scaffold.dart:203` (Callback im Build).
- `SlidingTabsContainer` hält alle besuchten Tabs aktiv. Offstage-Tabs beobachten weiter ihre Provider, deshalb rechnet die Startseite im Hintergrund weiter (4.3 Punkt 6).
- `BackdropFilter` als Fallback in `add_item_composer.dart:296,363` und weiteren Sheets (nur Nicht-iOS oder bei Reduce Transparency mit Sigma 0, aber trotzdem ein Filter-Layer). `liquid_glass_button.dart:52,149` und `liquid_glass_container.dart:88` blurren auch auf iOS, wenn sie verwendet werden.

---

## 5. Abhängigkeiten zu anderen Bereichen

| Was | Geteilt mit | Hinweis |
|---|---|---|
| `listsNotifierProvider`, `userListsProvider` | Startseite, Listen, Avo, Siri (`app.dart:107-143`), Widgets, Angebote, Verlauf | Jede Änderung am Seed oder Cache betrifft alle |
| `itemsNotifierProvider(listId)` | Listen-Detail, Avo (`avo_chat_screen.dart:225,276-282`), Scanner, Siri, `basketComparisonProvider`, `mlRecommendationsProvider` | Nicht autoDispose wegen dieser Ausleiher |
| `OfflineCacheService` | `main.dart`, `auth_provider.dart`, `recipes_provider.dart`, `recipe_service.dart`, `lists_provider.dart`, `items_provider.dart`, `recipes_screen.dart`, `avo_chat_screen.dart` | Nicht nutzerbezogen, wird bei Logout und Accountwechsel geleert |
| `authUserIdProvider` | fast alle account-bezogenen Provider | Bei Accountwechsel wird der Cache geleert (`auth_provider.dart:33-37`) |
| `ItemRepository.addItem` | Listen, Avo, Siri, Import, Rezepte "auf die Liste" | Parse- und Kategorie-Logik zentral, Plan-Feature "2 Milch" hängt hier |
| `GeminiCategorizationService` | Items, Empfehlungen, Ingredient-Parse in Rezepten | Wird mit Umstieg auf Claude ersetzt |
| `isOfflineProvider` | nur `main_scaffold.dart` | Muss in das Redesign der Shell und der Liste |
| `subscriptionStatusProvider`, `isSubscribedProvider` | Paywall, alle Pro-Gates | Startwert `unknown` muss als "noch unbekannt" gestaltet werden, nicht als "gesperrt" |
| `calorieTrackingEnabledProvider` | Shell (Tab-Anzahl), Onboarding, Profil | Modul-Schalter-Prinzip des Plans |
| `themeModeProvider`, `languageProvider` | `app.dart` Remount-Key, Profil-Einstellungen | |
| `WidgetService` und App-Group-Schlüssel `widget_*` | iOS-Widgets, `AppDelegate.swift`, Auth-Logout | Widget-Redesign braucht dieselben Schlüssel oder eine Migration |
| `effectiveZipProvider`, `UserLocationService` | Angebote, Rezept-Angebote, Avo, Startseite | Standortdialog-Zeitpunkt |
| Strings `loading_error`, `loading_items`, `no_lists_yet`, `my_first_list` (`app_translations.dart:762-810,1931-1979`) | Startseite, Liste | "Offline" und die Avo-Fehlertexte fehlen in den Übersetzungen |
| `CachedNetworkImage` | Rezepte, Profil, Kalorien | Einheitliche Bildkomponente fehlt |
| Inventare `home.md`, `lists-core.md`, `shell.md`, `calories.md`, `avo.md`, `recipes-browse.md` | | Sie beschreiben die Oberflächen. Dieses Dokument beschreibt die Daten- und Startursachen dahinter |

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen und Muster, die funktionieren:**
- Optimistische Item-Mutationen mit Generationszähler (`items_provider.dart:27-34,164-203`) und Zurückhalten von Realtime-Echos während laufender Schreibvorgänge (`_pendingWrites`, `_reloadWanted`). Das ist die Basis für flüssiges Abhaken. Sie muss um eine persistente Warteschlange ergänzt werden, nicht ersetzt.
- Der In-Memory-Seed aus dem Cache für den ersten Frame (`offline_cache_service.dart:134-157`, `items_provider.dart:51-55`, `recipes_screen.dart:97-111`): Stale-while-revalidate ist das richtige Muster und muss auf Listen, Kalorien, Verlauf und Pro-Status ausgeweitet werden.
- Realtime nur, solange jemand zuschaut (`items_provider.dart:448-449`), mit Nachladen nach mehr als 2 s Pause (`:67-71`).
- Listen mit Zählern in einem Roundtrip (`list_repository.dart:26-57`).
- Merge gleicher, nicht abgehakter Artikel nur bei gleicher Einheit (`item_repository.dart:127-162`). Das verhindert "2 kg + 500 g = 502 kg".
- `ilike`-Escaping (`item_repository.dart:220-221`).
- Router-Redirect ohne Netzabfrage, mit gecachtem Profil für Offline-Start (`offline_cache_service.dart:198-244`) und gemerktem Freigabelink bei Login (`_pendingListLink`).
- Hintergrund-Init parallel und einzeln abgesichert (`main.dart:58-93`), damit ein Fehler die anderen nicht stoppt.
- Angebots-Throttle, Dedupe und 30-min-Cache (`offer_price_service.dart:53-61,89-97`), 6-h-Cache der Offer-Nudges, Signatur-Cache des Home-Highlights.
- Debounce für Realtime (300 ms Items, 400 ms Listen).
- Respekt vor Reduce Transparency im Composer (`add_item_composer.dart:286-299`).

**Daten und Sonderfälle:**
- Logout und Accountwechsel leeren Offline-Cache, Kategorie-Präferenzen, Widget-App-Group und Reminder (`main.dart:137-163`, `auth_provider.dart:33-37`). Nichts vom vorigen Konto darf sichtbar bleiben.
- Widget-Credentials folgen jedem Token-Refresh (`main.dart:131-135`). Sonst scheitert Abhaken im Widget.
- Siri: "Füge X zu Y hinzu" nutzt die vorhandene Liste bei Namensgleichheit ohne Groß- und Kleinschreibung, sonst wird eine neue Liste angelegt (`app.dart:103-150`).
- Firebase fehlt im Build (Platzhalter-Optionen): Die App muss trotzdem starten (`main.dart:97-105`).
- Gelöschte Zeile wurde schon von einem anderen Mitglied entfernt: kein Fehler (`item_repository.dart:289`).
- `order_index` mit `nullsFirst: false` plus `created_at` als stabile Sortierung. Beim Reorder wird jede Zeile neu nummeriert (`items_provider.dart:373-405`).
- Pro-Status: Die Kontodaten (`users.subscription_*`) sind die Quelle der Wahrheit, ohne stilles `restorePurchases` beim Start (`subscription_service.dart:86-91`).
- Gemini-Kategorie-Cache, damit bekannte Artikel nicht erneut angefragt werden. Beim Umstieg auf Claude migrieren oder durch lokale Keyword-Klassifizierung als ersten Schritt ersetzen.
- Projektregel 1100 ms zwischen Gemini-Aufrufen, solange Gemini im Einsatz ist.

**Anforderungen aus Plan und Wunschliste, die dieser Bereich tragen muss:**
- Kein sichtbares Laden für Daten, die schon einmal da waren.
- Offline sauber, Abgehaktes erscheint bei allen Mitgliedern live.
- "Wer kauft gerade ein" in geteilten Listen.
- "2 Milch" wird lokal sofort Menge 2 plus Artikel.
- Bildschirm bleibt im Einkaufsmodus an (`wakelock_plus` ist schon im Projekt, heute nur im Kochmodus: `cooking_mode_screen.dart:70`).
- Angebote als abschaltbares Modul mit Remote-Kill-Switch. Heute laufen die Angebots-Provider ungefragt beim Startseiten-Render, sie müssen hinter den Modul-Schalter.
