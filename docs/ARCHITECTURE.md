# Architektur

Stand: 2026-11-07, nach dem großen Aufräumen (siehe [CHANGELOG](CHANGELOG.md)). Wer etwas Grundlegendes ändert,
passt diese Datei im selben Commit an.

## Schichten

```
lib/
├── main.dart            Start: Supabase vor runApp, alles andere parallel im Hintergrund
├── app.dart             AvoApp (AdaptiveApp.router), Theme/Sprache, ScaffoldMessenger, TutorialOverlay
├── routes/app_router.dart   GoRouter, Auth-Redirect (ohne Netzwerk), Deep Links
├── core/                config (env.dart), constants (Farben, Kategorien, Links), localization,
│                        theme, utils (normalizeProductName, request_throttle, number_parsing), widgets/paper
├── data/
│   ├── models/          Datenklassen (Recipe+Ingredient in recipe.dart, ShoppingItemModel, ShoppingListModel …)
│   ├── repositories/    ListRepository, ItemRepository – alle Listen-/Artikel-Zugriffe auf Supabase
│   └── services/        ~60 Singletons (ServiceName.instance): Avo, Gemini, Rezepte, Push, Angebote, Kalorien …
└── presentation/
    ├── state/           Riverpod: auth, lists, items, recipes, theme, language
    ├── providers/       Riverpod: subscription, ML-Empfehlungen, Preise/Angebote
    ├── screens/<feature>/          ein Ordner pro Bereich, Teil-Widgets in screens/<feature>/widgets/
    └── widgets/         geteilte Widgets (common/, recipes/, recommendations/, tutorial/)
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
`share_list_dialog.dart`, `list_detail_parts.dart` und `shopping_trip_completion.dart` (Einkauf abschließen).

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
- Die Sitzung setzt sich bei Account-Wechsel selbst zurück, der Verlauf wird auf die letzten 10 Nutzerzüge gekürzt.
- Schreibende Tools (Artikel hinzufügen, abhaken, Rezept auf Liste) gehen über `ItemRepository` und schicken
  **eine** Push-Nachricht statt einer pro Artikel.

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
  Angebots- und Markt-Screens von Teil B liegen als Vollbild über der Tab-Leiste (`offersRootRoutes`:
  `/offers/offer/:offerId`, `/stores/pick`), geöffnet mit den Helfern in `screens/offers/offer_paths.dart`.

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
