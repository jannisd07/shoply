# Architektur

Stand: 2026-11-07, nach dem großen Aufräumen (siehe [CHANGELOG](CHANGELOG.md)). Wer etwas Grundlegendes ändert,
passt diese Datei im selben Commit an.

## Schichten

```
lib/
├── main.dart            Start: Supabase vor runApp, alles andere parallel im Hintergrund
├── app.dart             AvoApp (AdaptiveApp.router), Theme/Sprache, ScaffoldMessenger
├── routes/app_router.dart   GoRouter, Auth-Redirect (ohne Netzwerk), Deep Links
├── core/                config (env.dart), constants (Farben, Kategorien, Links), localization,
│                        theme, design (D2-Tokens), utils (normalizeProductName, request_throttle, number_parsing)
├── data/
│   ├── models/          Datenklassen (Recipe+Ingredient in recipe.dart, ShoppingItemModel, ShoppingListModel …)
│   ├── repositories/    ListRepository, ItemRepository – alle Listen-/Artikel-Zugriffe auf Supabase
│   └── services/        ~60 Singletons (ServiceName.instance): Avo, Claude, Rezepte, Push, Angebote, Kalorien …
└── presentation/
    ├── state/           Riverpod: auth, lists, items, recipes, theme, language
    ├── providers/       Riverpod: subscription, Preise/Angebote
    ├── screens/<feature>/          ein Ordner pro Bereich, Teil-Widgets in screens/<feature>/widgets/
    └── widgets/         geteilte Widgets (design/ = D2-Komponenten, common/, recipes/, slots/, tips/)
```

Es gibt **keinen** Service-Locator mehr (`Services.x` ist gelöscht). Zugriff: `ServiceName.instance` oder ein
Riverpod-Provider. `ItemRepository.instance` / `ListRepository.instance` sind auch über `itemRepositoryProvider` /
`listRepositoryProvider` erreichbar (dieselbe Instanz).

## Start (main.dart)

1. Supabase wird vor `runApp` initialisiert, damit der Router die Session kennt.
2. Danach startet `_initializeServicesInBackground()` alles **gleichzeitig**: Firebase → Analytics, Gemini,
   Subscriptions, App-Review, Notifications → FCM. Ein Fehler in einem Teil stoppt die anderen nicht (`_guarded`).
3. Der Auth-Listener wird zuerst registriert. Bei `signedOut` werden Offline-Cache, gelernte Kategorien und
   Widget-Daten geleert. Der FCM-Token wird nur bei `signedIn` gespeichert.
4. Ist `lib/firebase_options.dart` der Platzhalter, loggt die App laut `❌ [FIREBASE]` und läuft ohne Push.

## Navigation

- GoRouter mit `StatefulShellRoute` für die Tabs (Home, Rezepte, Profil). Avo-Chat (`/avo`) und Listen-Detail
  (`/lists/:listId`) liegen **außerhalb** der Shell, also ohne Navbar. Dorthin immer mit `context.push`, nicht `go`.
- Die Paywall `/pro` ist eine `ZoomPage` (`widgets/design/zoom_page.dart`): Sie wächst aus dem Element, das sie
  geöffnet hat, und schrumpft dorthin zurück (Zurück-Wischen 1:1, Reduce Motion: Überblendung). Öffnen über
  `ProGate.run`/`ProGate.openPaywall(origin:)`; ein schlichtes `context.push` wächst aus dem letzten Tipp
  (`ZoomOrigin`, in `app.dart` gestartet).
- Der Redirect macht keine Netzwerkabfrage mehr. Das Onboarding-Flag wird gecacht, sobald es `true` ist.
- Screens, die *innerhalb* der Shell gepusht werden, müssen unten `MainScaffold.getNavbarClearance(context) + 16`
  Abstand lassen.
- Rezept-Listen geben das angetippte `Recipe` als GoRouter-`extra` mit. Die Detailseite zeigt es sofort und lädt
  im Hintergrund nach.
- Deep Links (`shoply://`, Universal Links) kommen nur über `uriLinkStream` (app_links 6 liefert auch den
  Start-Link dort). Dieselbe URI innerhalb von 2 s wird ignoriert. Notification-Taps (lokal und FCM) laufen alle
  über `NavigationService.handleNotificationData`.

## Listen und Artikel (wichtigster Datenfluss)

- `ListRepository.getUserLists()` holt alle Listen **in einer Abfrage** samt Artikelzahl und offenen Artikeln
  (PostgREST-Count-Embeds). Früher war das 1+1+N.
- `ListsNotifier` hört per Realtime auf Änderungen, **entprellt mit 400 ms**.
- `ItemsNotifier` (pro Liste) ändert den Zustand **optimistisch**: Abhaken, Bearbeiten, Löschen erscheinen sofort,
  bei einem Fehler wird zurückgerollt und der Fehler weitergeworfen (Aufrufer zeigen dann eine Snackbar).
- Der Realtime-Kanal einer Liste ist nur offen, solange jemand `itemsNotifierProvider(listId)` beobachtet.
  Wer den Notifier nur liest (Avo, Scanner), prüft vorher `ref.exists`.
- Push an Mitglieder läuft im Hintergrund (`unawaited`) und blockiert keine Eingabe mehr.
- Neuer Artikel: Gemini parst nur, wenn der Text eine Ziffer enthält ("2 Liter Milch"). Kategorien kommen aus
  Gemini (`gemini-2.0-flash-lite`, mind. 1100 ms Abstand, serialisiert) mit Fallback auf `ProductClassifierService`.
- Zusammenführen gleicher Artikel nur bei gleicher Einheit.
- Kategorien sind sprachneutrale IDs (`dairy`, `fruits_vegetables`); die UI liest `item.categoryId ?? item.category`.
  Eigene Kategorien und Kategorie-Reihenfolge sind derzeit **nur lokal pro Gerät** (siehe OPEN-ISSUES).

### Listen-Detail-Screen

`screens/lists/list_detail_screen.dart` (~770 Zeilen, vorher 3.457) delegiert an `screens/lists/widgets/`:
`item_form_dialog.dart` (ein Dialog für Neu und Bearbeiten), `list_item_tile.dart`, `list_category_section.dart`
(`groupItemsByCategory()`, gecacht), `list_drag_controller.dart` (Drag ohne `setState`), `list_detail_menu.dart`,
`share_list_dialog.dart` und `list_detail_parts.dart`. „Einkauf abschließen“ gehört Teil B: `openCheckoutFlow`
(`b_slots.dart`) pusht `/checkout/:listId` (`screens/history/checkout/`), speichert über
`tripHistoryProvider` (`presentation/state/trip_history_provider.dart`: lokaler Verlauf pro Konto, optimistisch,
Widerrufen) und `ShoppingHistoryService.completeTrip` (Server-Funktion `complete_shopping_trip`, Rückfall auf
Einzel-Inserts, solange die Migration fehlt).

## Rezepte

- `RecipeService.getRecipes()` ist die eine Quelle für alle Rezeptansichten. Es cached 30 s pro Nutzer, teilt
  laufende Anfragen und schreibt den Offline-Cache.
- Der Rezepte-Tab lädt die Liste **einmal** über `recipesProvider`. Neu, Top-Autoren, Kategorien, "Für dich" und
  Suche werden im Speicher berechnet (`screens/recipes/recipes_home_data.dart`). Suche: lokaler Filter, 250 ms Debounce.
- `refreshRecipeData(ref)` invalidiert alles Rezept-bezogene.
- Aufrufe zählt nur `RecipeService.trackRecipeView` (einmal pro Öffnen). Keyword-Labels: `recipe_auto_labeler.dart`.
- Karten in Scroll-Listen benutzen **kein** `AdaptiveGlass` mehr (jedes war eine native UiKitView). Glas nur noch
  auf fester Chrome (Suchkopf, Buttons).

## Avo (KI-Assistent)

- `avo_assistant_service.dart` ist der Ablauf (Werkzeug-Schleife über `ClaudeService.streamAvo`, Edge Function `ai`),
  dazu `avo_assistant_models.dart` (Antwortkarten als `AvoWidgetPayload`) und `avo_conversation.dart` (Verlauf,
  Einmal-Schlüssel fürs Löschen).
- Der Avo-Tab liegt in `lib/presentation/screens/avo/`: `AvoTabScreen` (Wurzel `/avo`; `?prompt=` und `?q=` aus
  einer URL füllen nur vor und senden nie; sofort senden nur über `openAvoWithQuestion`, das die Frage als
  `extra`/`AvoAsk` übergibt), `avoChatProvider` (`AvoChat`, ein Gespräch pro Konto, lebt über Tab-Wechsel hinweg,
  hält den Zustand jeder Karte und arbeitet nur mit dem `WidgetRef` der Tab-Wurzel) und `AvoBackend`
  (Schnittstelle zum Dienst, in Tests ein Fake). Schreibende Listen-Werkzeuge liefern über `AvoListChanges`
  (`lib/data/services/avo_list_changes.dart`, testbar über `AvoListWriter`) ein `AvoListChange` mit Gegen-Aktion
  für „Widerrufen“: Sie prüft vorher, ob die Daten unverändert sind; ein zusammengeführtes Hinzufügen bekommt nur
  die alte Menge zurück.
- Alle anderen Werkzeuge liefern ihre Karte als `AvoWidgetPayload.card(AvoCardData)` (Lesen und Rückfragen:
  Verlauf, Nachkauf, Rezepte, Wochenplan, Angebote, Kalorien, Schätzung, Allergie-Rückfrage) oder als
  `AvoWidgetPayload.record(AvoRecord)` (Schreiben mit Gegen-Aktion: mehrere Artikel auf einer Liste, Plan, Wasser,
  Gewicht, Training, Essen, Ziel, Einstellung, Modul, Kosten teilen), beide in
  `lib/data/services/avo_card_data.dart`. Mehrere Artikel auf einmal (Rezept, früherer Einkauf, Zettel) gehen über
  `AvoListChanges.addBatch` (`ItemRepository.addItems`, gleiche Zusammenführung wie „Zutaten auf die Liste“).
  Was erst ein Tipp der Person schreibt, schreibt der Dienst nie selbst: `log_food` zeigt nur die Schätzung
  („Eintragen“), `setup_nutrition_goal` immer die Vorschau („Übernehmen“, nennt jedes Feld, das sich ändert, auch
  einen Gewichtseintrag für heute), `allergies_remove` und `diet_remove` die Rückfrage (ohne Einwilligung „Ernährung
  und Allergien“ nur die Einwilligungskarte und ein neutrales Ergebnis), `add_to_plan` auf belegtem Tag „Dazulegen /
  Ersetzen“, `split_trip_cost` die Aufteilung zum „Teilen“ (Betrag und Zahler kommen aus dem Einkauf). Diese
  Entscheidungen sind reine Funktionen in `avo_tool_gates.dart` (getestet). Was Ziel- und Teilen-Tipp lesen und
  schreiben, liegt hinter `avoGoalStoreProvider` / `avoSplitStoreProvider` (`avo_stores.dart`): Der Tipp liest
  Ziel, Gewicht, Einkauf, Zahler und Aufteilung neu und schreibt nur, wenn alles noch wie auf der Karte ist; das
  übernommene Ziel behält Felder, die die Karte nicht zeigt (Wasser, Training, Tempo). Der Anteil des Zahlers
  bekommt dessen Konto-ID, damit `createSplits` ihn wieder als bezahlt anlegt; die Fußnote rechnet mit derselben
  Regel (`avoIsPayersShare`). Der Tipp auf „Entfernen“ (Allergie, Ernährung) schreibt über
  `avoSettingUpdateProvider`. Avo schaltet sich selbst
  erst nach dem Ende der Antwort aus. Die Karten liegen
  nach Bereich in `screens/avo/widgets/avo_*_sections.dart`, die Werkzeuge nach Bereich in den Teil-Dateien
  `lib/data/services/avo_tools_*.dart` (Erweiterungen des Dienstes).
- Jedes Werkzeug-Ergebnis geht durch `avoConsentFilter` (`avo_consent_filter.dart`): ohne „Kalorien, Gewicht und
  Ziele“ keine Summen, Ziele, Gewichte, Alter oder Größe, ohne „Ernährung und Allergien“ keine Allergien und keine
  Ernährung; die Postleitzahl nie (nur, ob eine gesetzt ist). Ein Werkzeug-Fehler geht nur als `tool_failed` an
  das Modell, nie mit dem Fehlertext. Tests rufen den Weg über `debugRunToolCall` auf.
- Foto an Avo (`AvoChat.sendPhoto`, `avo_chat_photo.dart`): Das Foto bleibt auf dem Gerät im Gespräch und geht nie
  in den `avo_chat`-Verlauf. Kontext Kalorien = Essen (`meal_photo`), Liste/Einkaufsmodus = Zettel (`list_import`),
  sonst fragt die Runde. Kamera und Fotoauswahl über `avoPhotoSourceProvider` (`image_picker`; „Kamera ist aus“
  kommt aus dessen Fehler `camera_access_denied`, nicht aus permission_handler, dessen Kamera-Prüfung im Podfile
  nicht einkompiliert ist); Dialog 11.3 erklärt einmal pro Installation vor der ersten Systemabfrage. Erst „Eintragen“ lädt ein Essensfoto in den
  privaten Bucket `meal-photos` (`MealPhotoStorageService`, Pfad `<uid>/…`).
- Die Sitzung setzt sich bei Account-Wechsel selbst zurück, der Verlauf wird auf die letzten 10 Nutzerzüge gekürzt.
- Schreibende Tools (Artikel hinzufügen, abhaken, Rezept auf Liste) gehen über `ItemRepository` und schicken
  **eine** Push-Nachricht statt einer pro Artikel.

## Kalorien (Modul `AppModule.calories`, Teil B)

- **Routen** (`routes/areas/calories_routes.dart`): Tagebuch `/calories` ist ein Push im Home-Tab (`?date=YYYY-MM-DD`,
  nie nach heute; `?focus=water`). Kinder im Home-Tab: `goals` (Ziele, S13), dazu `week`, `weight`, `challenges`,
  `ideas` (vorerst die alten Screens), `water` leitet auf `/calories?focus=water` um. Dasselbe Ziele-Widget hängt als
  `/settings/health/goals` im Profil-Tab. Vollbild über dem Tab, aus dem man kommt, alle mit `ModuleGate`:
  `/calories/add` (S3), `/calories/add/photo` (S4), `/calories/add/estimate` (S5, das Foto nur als `extra`; ohne
  Foto zurück zur Kamera), `/calories/scan` (S6), `/calories/add/food/:foodId` (S7), `/calories/add/manual` (S8),
  `/calories/entry/:entryId?date=` (S9), `/calories/add/recipe/:recipeId` (S10, `openLogRecipe` in `b_slots.dart`
  pusht sie mit dem Rezept als `extra`) und `/calories/goals/setup` (S14). Alle Vollbild-Routen von Teil B
  (`bRootRoutes()` in `app_router.dart`: Avo, Kalorien, Plan, Angebote, Verlauf) stehen **vor** der Shell, damit sie
  über dem aktuellen Tab öffnen (AB2, A-R1). Einstellungsseiten von B für Siri und Widgets: `systemSettingsRoutes` in
  `lib/routes/areas/system_routes.dart` (B), unter `/settings` eingehängt.
- **Eintrage-Ablauf:** Die Seiten von S3 bis S8 tragen den Namen `kCalorieFlowPageName`. Nach „Eintragen“ schließt
  `popCalorieFlow` den ganzen Ablauf, die Person landet dort, wo S3 geöffnet wurde (Home, Rezept, Avo); der
  Rückgängig-Hinweis steht dort. Kamera → Schätzung und Kamera → Menge ersetzen die Kamera-Seite (`pushReplacement`).
  Alle Eintrage-Screens bauen auf `CalorieFlowScaffold` (Kopf, Inhalt, untere Kapsel über der Tastatur,
  „verwerfen?“-Dialog mit eigenen Texten). S9 speichert beim Verlassen.
- **Kameras sind nativ:** Barcode über `shoply/scanner` (VisionKit), Essensfoto und Fotoauswahl über `shoply/camera`
  (`ios/Runner/NativeChannels/MealCameraChannel.swift`: eigene `AVCaptureSession`, `PHPickerViewController`, beide
  Vollbild mit Überblendung, nie von unten; JPEG 1024 px, 80 %, nur im Speicher). Die Kamera-Erlaubnis fragt Dart
  über `shoply/scanner` erst nach dem eigenen Alert. Screens sprechen nur mit `calorieCameraProvider`
  (`CalorieCamera`), in Tests ein Fake.
- **Produkte und eigene Lebensmittel** (`state/calorie_food_provider.dart`): `lookupCalorieBarcode` fragt erst die
  eigenen Lebensmittel (`userFoodsProvider`, Tabelle `user_food`, lokal gespeichert, Schreiben über die
  Warteschlange), dann den Produkt-Cache auf dem Gerät (`calorieProductCacheProvider`, auch „Zuletzt gescannt“), dann
  Open Food Facts. `OpenFoodFactsService.search` und `lookupBarcode` werfen `OffRequestFailed` bei Netz- oder
  Serverfehlern; leer bzw. `null` heißt wirklich „nichts gefunden“. Fehlende Nährwerte (S7) werden als eigenes
  Lebensmittel mit Strichcode gemerkt.
- **KI-Schätzungen:** Foto über `mealPhotoAnalyzerProvider` (Task `meal_photo`), Text über
  `calorieNutritionEstimatorProvider` (Task `nutrition_estimate`, S8 und S10). Nichts wird ohne Prüfung gespeichert;
  Einträge behalten `estimated` und `confidence`. `quota_exceeded` merkt sich den Tag (`caloriePhotoLimitReachedProvider`),
  S3 zeigt dann das Tageslimit (für `nutrition_estimate` ebenso, `calorieTextEstimateLimitReachedProvider`). Das Foto
  lädt `CalorieDiary.attachPhoto` nach dem Eintragen im Hintergrund in `meal-photos` hoch und trägt den Pfad nach; das
  läuft im Provider, nicht im Screen, der da schon geschlossen ist. Es sucht den Eintrag per id (auch wenn S9 ihn auf
  einen anderen Tag gelegt hat); ist er inzwischen gelöscht (Rückgängig), wartet das Foto mit ihm auf „Widerrufen“
  und wird sonst nach dem Rückgängig-Fenster gelöscht.
- **Fotos löschen:** `CalorieDiary.deleteFood` nimmt den Eintrag, wie das Tagebuch ihn gerade hat (per id, mit einem
  später nachgetragenen Foto), und plant das Löschen des Fotos nach dem Rückgängig-Fenster (10 s, `MealPhotoCleanup`,
  auf dem Gerät gemerkt); „Widerrufen“ stellt die ganze Zeile wieder her und hebt das Löschen auf. `updateFood` behält
  ein später nachgetragenes Foto, wenn der Aufrufer das Foto nicht selbst ändert. Liegengebliebene Löschungen (offline,
  App im Fenster geschlossen) laufen, sobald `calorieBackendProvider` startet (er hört auf `mealPhotoCleanupProvider`,
  pro Konto), also mit der ersten Kalorien-Ansicht nach dem Start. Avo löscht nach seiner Bestätigungskarte über
  `FoodLogService.deleteEntryWithPhoto`, Zeile und Foto sofort. Gelöscht wird nur im eigenen Ordner `<uid>/`. Ein
  „Alle Essensfotos löschen“ gibt es erst mit S23.
- **Eigene Lebensmittel und die DB-Prüfungen:** `UserFood.fitsServer` spiegelt die Checks von `user_food` (Name 1–200,
  kcal 0–900 und Makros 0–100 pro 100 g, Portion/Packung > 0, Strichcode 6–14 Ziffern). `UserFood.fromEntry` und
  `UserFoodsNotifier.save` legen nichts an, was der Server dauerhaft ablehnen würde; S8 sagt es vorher. Lokal gemerkte
  Lebensmittel, die der Server nicht mehr kennt, verschwinden beim Abgleich (außer sie warten noch in der
  Warteschlange).
- **Dateien:** `state/calorie_entry_provider.dart` exportiert `calorie_camera_provider.dart`,
  `calorie_food_provider.dart`, `calorie_ai_provider.dart` und `calorie_person_provider.dart`; S3 besteht aus
  `calories_add_screen.dart` und den Segmenten `widgets/calorie_add_search|photo|barcode.dart`.
- **Lokal zuerst:** Jeder Tag ist ein `calorieDayProvider(dateKey)` (`state/nutrition_provider.dart`). Er startet mit
  dem Tag aus `CalorieDayStore` (SharedPreferences, heute und 14 Tage davor), fragt danach den Server und führt die
  Antwort mit der Schreib-Warteschlange zusammen (`mergeServerDay`). Der Server kann den Tag lesen, bevor ein
  Schreiben ankommt, das schon bestätigt ist, wenn die Antwort eintrifft (zum Beispiel beim Zurückkommen ins Netz,
  wenn Warteschlange und Neuladen gleichzeitig starten). Deshalb gilt für die eigenen Schreibvorgänge dieses Geräts:
  Was beim Start des Abrufs in der Warteschlange stand, und was während des Abrufs lokal geändert wurde
  (`applyLocalChanges`), liegt über der Antwort, nach ID, also weder verloren noch doppelt. Abrufe eines Tages laufen
  nie gleichzeitig (ein weiterer Aufruf läuft danach). Ändert ein anderes Gerät dieselbe Zeile gleichzeitig, gilt bis
  zum nächsten Abruf die Fassung dieses Geräts.
- **Schreiben** nur über `calorieDiaryProvider` (`CalorieDiary`): sofort im lokalen Tag, dann
  `CalorieWriteQueue` (dauerhaft, Wiederholung mit Backoff, „Nicht gespeichert“ bei Ablehnung), dann Apple Health.
  Rückgängig legt die Zeile an ihren alten Platz zurück (Reihenfolge nach `created_at`). Neue Spalten nur mit
  `app_flags.calories_schema_v2` (prüfen die Services).
- **Heute** ist `calorieTodayKeyProvider`: er rechnet sich um Mitternacht neu, sobald die App aus dem Hintergrund
  zurückkommt, und zur Sicherheit jede Minute (Timer stehen still, solange iOS die App pausiert). Alles, was
  „für heute“ schreibt (Home-Wasser,
  „Essen eintragen“ ohne Datum, „Heute nochmal eintragen“), liest die Uhr erst beim Tippen
  (`calorieTodayKeyNow`), damit ein über Nacht offener Screen nie in gestern schreibt.
- **Ziel:** `calorieGoalStateProvider` unterscheidet lädt / kein Ziel / gesetzt / Fehler und nimmt bis zur Antwort das
  gespeicherte Ziel. Ein Ladefehler sieht nie wie „kein Ziel“ aus (S1a nur bei `none`). S13 ändert einzelne Werte an
  Ort und Stelle (Feld und Stepper, kein Slider) und speichert beim Zuklappen als „Eigene Werte“ (`goalType custom`).
  S14 rechnet mit `GoalForm`/`GoalDraft` (Teil A kann das Formular im Onboarding zeigen) und
  `NutritionGoalCalculator` mit Tempo statt Zeitraum.
- **Abruf mit Zeitlimit:** Ein Tages-Abruf, der nach 20 s nicht antwortet (`calorieFetchTimeoutProvider`), zählt als
  Netzfehler; spätere Abrufe desselben Tages warten nicht mehr auf ihn.
- **Nachbartage:** Das Tagebuch lädt den Tag davor und danach mit. ±7 Tage wie im Konzept wären 42 Abfragen beim
  Öffnen; die 14 gespeicherten Tage öffnen ohnehin sofort mit Zahlen.
- **Wieder online:** Tagebuch und Home-Karte laden von selbst neu, sobald `isOfflineProvider` wieder `false` ist.
- **Home:** `widgets/home_sections/home_calories.dart` (`HomeCaloriesToday`, `HomeWaterTile`, Abend-Hinweis), in
  `home_sections.dart` re-exportiert. Die `…HasContentProvider` sind synchron und lesen zuerst das Modul.

## Benachrichtigungen

- Lokal: `flutter_local_notifications` (`NotificationService`, `MascotNotificationService`).
- Push: FCM. Der Token liegt in `users.fcm_token` (nur ein Gerät pro Nutzer). Versand über die Edge Function
  `send-push-notification`, Aufruf über `PushNotificationService.sendToUsers` / `sendToListMembers`.

## Offline und Cache

- `OfflineCacheService`: Schlüssel mit Präfix `offline_cache_v2_`, wird bei Account-Wechsel und Logout geleert.
- `UserCategoryPreferences`: pro Nutzer unter `user_category_prefs_v1_<uid>`.
- Externe Preis-/Angebotsdienste teilen sich `core/utils/request_throttle.dart` und cachen keine Fehler.
- Angebote einer Liste: 6-h-Schnappschuss pro Liste und Markt (`ListOfferSync`, SharedPreferences
  `offers_list_snapshot_v1:<listId>`). Listenkarten und das Angebots-Vollbild lesen nur diesen Cache, nie die Quelle.
  Was die Person an Angebotsflächen ein- und ausschaltet und welche Listen sie ausblendet, liegt pro Konto auf dem
  Gerät (`offers_display_prefs_v1:<uid>`, `offers_hidden_lists_v1:<uid>`); ein anderes Konto sieht nichts davon.
- Markt pro Liste: Tabelle `list_store_assignments_b` plus Gerätecache `list_store_guess_v1` (`ListStoreRepository`).
  Angebots- und Markt-Screens von Teil B, geöffnet mit den Helfern in `screens/offers/offer_paths.dart`:
  „Angebote der Woche“ `/offers` und „Angebote bei {Markt}“ `/offers/list/:listId` im Listen-Tab; als Vollbild über
  der Tab-Leiste (`offersRootRoutes`) `/offers/offer/:offerId`, `/offers/recipe/:recipeId`, `/stores/pick`,
  `/stores/region`; im Profil-Tab `/settings/offers`, `/settings/offers/region`, `/settings/offers/markets`.
  `/offers*` laufen durch `_OffersGate` (Kill-Switch: Fehlerseite, Modul aus: Dialog, Wechsel im offenen Screen:
  still schließen); `/stores/*` und `/settings/offers*` sind Kern und ohne Wächter.
- Lieblingsmärkte (Reihenfolge), „Markt automatisch erkennen“, „Nicht interessiert“ und die Pause des Hinweises
  „Postleitzahl festlegen“ liegen in denselben Konto-Einstellungen (`offers_display_prefs_v1:<uid>`). Im Onboarding
  (noch ohne Konto) gewählte Märkte warten unter `offers_pending_favorites_v1` und gehen an das erste Konto, das
  keine eigenen hat.
- Region: `RegionController` (`region_provider.dart`). „Standort verwenden“ (`locate()`) fragt einmal nach der
  Erlaubnis, ortet mit 3 s Zeitlimit und speichert nichts; gespeichert wird erst mit „Fertig“ (`saveRegion`).
  „Region entfernen“ (`remove()`) setzt `offers_region_removed_v1`, damit der Hintergrund keine Region nachlädt.
  Die Region liegt pro Gerät, nicht pro Konto (Owner-Frage in OPEN-ISSUES). Koordinaten werden nie gespeichert,
  nur die Postleitzahl (und der Ort); die letzte Ortung bleibt höchstens 30 min im Speicher (Märkte in der Nähe).

## Backend (Supabase)

- Tabellen siehe [CLAUDE.md](../CLAUDE.md) ("Supabase Schema"). RLS überall über `auth.uid()`.
- Edge Functions in `supabase/functions/`: `send-push-notification`, `extract-shopping-list`, `expire-subscriptions`.
  Änderungen dort werden erst mit `supabase functions deploy <name>` live.
- SQL-Migrationen liegen in `database/migrations/` (historisch) und `supabase/migrations/`. Sie werden von Hand im
  Supabase-SQL-Editor ausgeführt.
- `upsert` auf `user_preferences` braucht `onConflict: 'user_id'`.

## Plattformen

iOS ist die Hauptplattform. `android/`, `macos/` und `web/` (Deep-Link-Seite und AASA) sind noch im Repo;
`linux/` und `windows/` sind entfernt. In-App-Käufe gibt es nur auf iOS.

## Prüfen

- `dart analyze` (0 Errors, 0 Warnings) und `flutter test`. Jeder Screen und jede Komponente hat einen Test mit
  `layoutMatrix` aus `test/layout/layout_matrix.dart` (320–440 pt, Textgröße ×1,0–×3,1, fett, dunkel, Kontrast).
- `bash tool/design_check.sh A` (bzw. `B`): D2-Regeln in Screens und Widgets (keine festen Farben, Schriftgrößen,
  Animationsdauern, Material-Icons, direkte Haptik, keine Sheets oder Slider). Ausnahmen stehen im Skript;
  gewollte Einzelfälle tragen `// D2`, `// brand data` oder `// design-check: ok <Grund>`.
- Leistung: `integration_test/perf/` (S1 Liste scrollen, S2 Abhaken in Serie, S5 Rezepte-Tab) nur am echten iPhone
  mit `flutter drive --profile`, Anleitung im README dort. Nie im Simulator: das ersetzt die installierte App.
