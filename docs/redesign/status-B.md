# Status Teil B (Jannis, Mac 2): KI, Daten, Module und System

Aufbau laut [`arbeitsteilung.md`](arbeitsteilung.md) Abschnitt 5. Teil B schreibt nur diese Datei.

## Stand

**Regel ab 09.11.2026 (Owner, Wochenlimit): eine Sitzung je Arbeitspaket.** Jede B-Sitzung bearbeitet genau ein Paket,
aktualisiert am Ende diese Datei und [`b-sitzungen.md`](b-sitzungen.md), pusht, erinnert den Owner an eine neue Sitzung
und gibt ihm den Start-Prompt für die nächste. Pakete, Stand und „Als Nächstes“ stehen in `b-sitzungen.md`.

2026-11-09 (BAB2): **A's Wünsche aus AB2 und A12 sind erledigt** (Commit mit dieser Zeile): Siri und Widgets in
`systemSettingsRoutes`, Hinweis, wenn die Kurzbefehle-App nicht aufgeht; Angebots-Pfade aus `RoutePaths`;
`offerTargetListsProvider` auf A's `listsTodayFirstProvider`, „Neue Liste …“ mit vorausgewähltem Markt; neue
Mitteilungs-Kategorien für Push; `recipeOfferSummaryShowsProvider` und der Badge-Fehler von `RecipeOfferSummary`; tote
Home-Karten und `ml_recommendation_service` gelöscht; Badge ohne eigenes Semantik-Label, `offer_module_off_body`
gelöscht. Als Nächstes: B8 (B7 wartet auf A-P1–A-P4, A-K10).

2026-11-09 (BAB1): **B nutzt A's AB1-Komponenten** (Commit mit dieser Zeile): Markt-Chips auf `AppFilterChip`/
`SingleChoiceChipRow`, Postleitzahl auf `TextFieldRow`, S13 auf `ReorderableInsetSection` + `SelectCircle`, Avo-Composer
auf `AvoComposerField` (Anhalten, Zähler, Foto-Pull-down), Einkaufsmodus über `shoppingModeSessionProvider` (plus
`ShoppingModeHeader` für den ersten Frame), Angebotspreise über `ItemsNotifier.setPrice`/`clearPrice`/`undoPrice`, neue
`AvoIcons`; `StoreFilterChip`, `PostcodeFieldRow` und eigene Glyphen gelöscht. Neu in `b_slots.dart`:
`itemOfferRowExtras` (Anfrage 17 an A). Punkte 13–15: was AB1 betraf, ist erledigt; offen bleibt der Rest dort.
Als Nächstes: BAB2 (Wünsche von A aus AB2), dann B7 Wochenplan.

2026-11-09 (BA8): **A8-Wünsche sind auf `main`** (Commit mit dieser Zeile): Einstellungsseiten Avo, Kalorien &
Gesundheit, Siri, Widgets, eigene Suchliste mit Zeilen und Hervorhebung, `b_slots`-Schnittstellen für Konto und Abo,
E-Mail ändern, Abmelden leert B's Zwischenspeicher, Avo-Werkzeug `show_settings_link`, neue `update_setting`-Schlüssel
mit Widerrufen, Erinnerungen zu den gewählten Uhrzeiten. Braucht den Deploy von `ai` (OPEN-ISSUES 2.). Als Nächstes:
BAB1 (auf A's AB1-Komponenten umstellen), dann B7 Wochenplan.

2026-11-09: Auf `main` sind B2 Angebote komplett (Slots S1–S8 `d5aff5a`, Screens S9–S16 `e0b7a1b`), B5 Avo-Tab
(`a3a25e2`) und Antwortkarten aller Werkzeuge mit „Foto an Avo“ (`e3a1023`), B6 Kalorien Tagebuch, Essen eintragen,
Foto, Barcode, Menge, Manuell, Ziele (`639e04d`), dazu Apple-Anmeldung mit Nonce (`52da1d1`), Anmeldung per Code
(`2022317`), die Abo-RPC-Sperre (`5314e0f`) und die Simulator-Funde von A (`ccf9895`). Angefangen, nicht auf `main`:
A8-Wünsche (`feature/b-settings-a8`) und Wochenplan (`feature/b7-plan`).

2026-11-08 abends: **S3 erreicht, Claude ist live.** Secret gesetzt (Owner), alle sechs B-Migrationen angewendet
(App-Flags, KI-Kontingent, private Essensfotos, Markt pro Liste, Kalorien v2, Wochenplan), `ai` und
`extract-shopping-list` deployt; beide antworten ohne Anmeldung mit 401. Neue Tabellen für A: `list_store_assignments_b`,
`user_food`, `workout_log`, `challenge_checkins`, `meal_plans`, `meal_plan_entries`, `meal_plan_settings`, RPC
`log_water`. Als Nächstes: Swift-Seite der nativen Kanäle committen (iOS-Build grün), dann B-Screens auf S2a/S2b,
Widgets/Siri, Evals, Prüfmatrix.

## Meilensteine

| Meilenstein | Stand | Datum | Commit |
|---|---|---|---|
| S0 Aufräumen gemergt (A) | erledigt (laut status-A) | 07.11.2026 | `950921d` |
| S1 Struktur (A) | erledigt (laut status-A) | 07.11.2026 | `ab83f21`…`6112576` |
| S2 Fundament (A) | S2a erreicht (laut status-A) | 08.11.2026 | `f16e071` |
| S3 Claude live (B) | erreicht: Secret, 6 Migrationen, Deploy `ai` + `extract-shopping-list` | 08.11.2026 | `0721f38` |
| S4 Angebote abgesichert (B) | erreicht: Logik (`26677f3`), Slots mit Inhalt (`d5aff5a`), alle Angebots-Screens (`e0b7a1b`) | 09.11.2026 | `e0b7a1b` |
| S5 Bereiche fertig (B) | in Arbeit: Angebote, Avo-Tab und -Karten, Kalorien-Kern, B-Einstellungen (BA8) fertig; offen siehe `b-sitzungen.md` | | |
| S6 Gegenprüfung (B prüft A) | offen | | |

## Anfragen an Teil A

Nach Dringlichkeit. Prio 1 entscheidet, wann ich die B-Screens bauen kann (die Logik dahinter läuft schon).

6. **Prio 1 – S2-Komponenten zuerst für die B-Screens, gern in Teilen (S2a).** Ich baue nicht gegen Tokens allein, sonst
   doppelte Arbeit. Gebraucht (Namen wie im D2-Komponenten-Blatt): Toolbar mit Glas-Knopf 44, Gruppe (Radius 26) mit
   Zeile/Trennlinie, Karte (Radius 20), Abschnittstitel, Chips, Segmented Control, kompakter `ValueStepper`, getönte
   Kapsel (Hauptaktion), Glas-Eingabefeld (Avo-Composer), `StatusRow`, `EmptyState`, `SkeletonSection`, `UndoToast`
   mit Host, `SuccessMoment`, `EditorScaffold` (Vollbild-Bearbeiten mit Schließen), zentrierter Bestätigungsdialog,
   `ProgressRing` und einfache Balken-Charts (Kalorien, Verlauf), `ProBadge` und `ProGate.run`. Dazu die D2-Tab-Bar mit
   dem **Avo-Tab auf `/avo`**. Was davon zuerst kommt, sag kurz in status-A, dann ziehe ich die Screens in derselben
   Reihenfolge nach.
7. **Prio 2 – Avo-Kontext:** ein Provider `avoScreenContextProvider` (`screen`, `listId`, `listName`), den A-Screens
   setzen, plus ein Navigations-Helfer `openAppDestination(String id)` für Avo-Antwortkarten („Liste öffnen“). Ohne das
   startet Avo immer mit der ersten Liste.
8. **Prio 2 – Home-Hinweise:** der Vertrag `TodayHintSource` aus deinem A4-Plan, sobald er steht. Die Daten liefere ich
   schon (Wochenplan heute, Kalorien übrig, Ersparnis, offene Beträge).
9. **Prio 3 – `AppBrand` und `pro_features`** (Name „Avo“, Pro-Liste), damit Avos App-Wissen nicht von Hand gepflegt
   wird.
10. **Prio 3 – Deep-Link-Übersetzung mit Fehlerseite (S2)** für Widgets und Siri: `shopping?list=`,
    `lists/<id>?focus=add`, `avo/voice`, `plan?day=`, `calories/water?ml=`.
11. ~~Prio 4 – `ShoppingItemModel.barcode`~~ gibt es schon (laut A), erledigt.

13. **Nach den Angebots-Slots (d5aff5a)** (A-C1, A-C3, A-C8, A-D1 mit AB1 erledigt, B umgestellt in BAB1; Rest offen): A-C1 `ItemRow` übernimmt eine Custom Action aus dem Trailing-Slot
    („Angebot ansehen“) in die Zeilen-Semantik, plus Kontextmenü im Einkaufsmodus; A-C3 `ListOfferSummary(listId:,
    shoppingMode:)` oder Provider „Einkaufsmodus aktiv“ + Session-Start (bis dahin erkennt B `ShoppingModeHeader` als
    Vorfahre); Listen-Screen: einklappende Polsterung um `ListOfferSummary` (heute 24 pt Lücke ohne Inhalt); A-C8
    Menü-Titelzeile mit Glyphe; A-C10 Icons `storefront`, `questionmarkCircle`; A-T2 `ContentGlass` ≥ 92 % für
    Text-Pillen; A-L1 Listen-Info „Markt“ → `openStorePicker(…, from: StorePickerOrigin.info)`; A-D1
    Preis-Schnittstelle in `ItemRepository`; A-Q1 `owner.sh`: `test/layout/screens/b/*` gehört B.

14. **Nach dem Avo-Tab (a3a25e2)** (Composer, kompakte `ItemRow`, `AppButton`-Varianten, Glyphen mit AB1 erledigt, B umgestellt in BAB1; Rest offen): `AvoComposerField` mit drittem Zustand „Antwort anhalten“ (`onStop`),
    `enabled`, `maxLength`/Zähler, eigenem `semanticLabel`, Foto-Knopf mit Pull-down; kompakte `ItemRow` (56 hoch,
    Kreis 22, Bild 36/Radius 9); `AppButton` „gefüllt neutral“ und „gefüllt destruktiv“ + Token `destructiveFill`;
    Glyphen `plus.bubble`, `leaf`, `switch.2`, `checklist`; Neue-Liste-Editor mit vorbefülltem Namen;
    `ProFeatures`-Eintrag `avo_questions` (A9); Punkt am Avo-Tab bei neuer Antwort; `home_avo_card.dart` auf
    `openAvoWithQuestion` aus `b_slots.dart` umstellen (die eigene gleichnamige Funktion dort löschen).

15. **Nach den Angebots-Screens (W4, S9–S16)** (von A mit AB2 erledigt, siehe `ab2-stand.md`):
    - **A-R2 `/offers`:** `app_router.dart` legt A's `ModuleGate` um `buildOffersRoot`. Wird das Modul ausgeschaltet,
      während „Angebote der Woche“ offen ist, fragt dieser Wächter mit dem Dialog; laut angebote.md 1.3 schließt der
      Screen still. B's `_OffersGate` in `buildOffersRoot` deckt Kill-Switch, Modul aus beim Öffnen und den stillen
      Wechsel schon ab: bitte den `ModuleGate` um `/offers` weglassen (oder ihm einen stillen Modus geben).
    - **A-P1 Profil:** Zeile „Preise & Angebote · Lidl, REWE“ (bei Kill-Switch „Märkte · …“) öffnet
      `offersSettingsPath`; die Märkte liefert `favoriteStoresProvider`, beides aus `b_slots.dart`.
    - **A-L1 Listenmenü:** „Angebote dieser Liste“ → `context.push(offerListLocation(listId))`; „Angebote der Woche“ in
      der Listen-Übersicht → `weeklyOffersLocation()` (beide aus `b_slots.dart`).
    - **A-R3 Deep Links:** `shoply://offers?filter=regulars&q=…` → `weeklyOffersLocation(regulars:, query:)`.
    - **A-C6 Rezept:** `RecipeOfferSummary(recipe:, listId:)` als letzte Zeile der Gruppe „Zutaten“ und
      `IngredientOfferBadge(listId:, ingredient:)` an den Zutatenzeilen (beide exportiert). Bis dahin steht
      `RecipeOffersCard(recipe:)` mit eigener Gruppe; das `SizedBox(height: AvoSpacing.l)` davor in
      `recipe_detail_screen.dart` bleibt als Lücke stehen, wenn die Karte nichts zeigt (bitte einklappend).
    - **Datenquellen:** S12 braucht eine Seite „Datenquellen“ unter Rechtliches als Route; heute ist sie ein
      Bottom-Sheet im Profil. Bis dahin fehlt die Zeile in S12.
    - **A-C2, A-C5, A-C9:** mit BAB1 umgestellt (`AppFilterChip`/`SingleChoiceChipRow`, `TextFieldRow`,
      `ReorderableInsetSection` + `SelectCircle` in S13); `StoreFilterChip` und `PostcodeFieldRow` sind gelöscht.
    - **A-L3:** „Neue Liste …“ im Menü „Auf welche Liste?“ öffnet `openNewListEditor` und setzt den Markt danach
      selbst; ein vorausgewählter Markt im Editor wäre schöner.
    - **A-C4:** Nach der Rückkehr von `/stores/region` (Hinweis im Vorschlags-Panel) den Fokus wieder ins Eingabefeld.
    - **Onboarding:** `OffersSetupStep` zeichnet seine Gruppen ohne eigenen Seitenrand, weil `OnboardingStepPage` die
      Kinder schon 16 pt einrückt. Beim allerersten Start wartet der Schritt bis zu 3 s auf die App-Flags (bis dahin
      leer), statt sich zu überspringen.
    - **Test-Fund:** `test/screens/lists/list_settings_screen_test.dart` „all changes: sections per day“ schlägt
      zwischen 0 und 2 Uhr fehl (der Eintrag „gestern“ liegt `now − 1 Tag 2 h` zurück, nachts also vorgestern).
    - **Persönliche Daten:** Das PLZ-Feld in `personal_info_screen.dart` bitte entfernen. Die Region wohnt jetzt in
      „Region“ (S11, `/settings/offers/region`, Zeile „Region“ in „Preise & Angebote“); das Feld dort speichert ohne
      die Prüfung von S11 (`isKnownZip`, „Region entfernen“, Ortszeile).

16. **Nach BA8 (B-Einstellungen)** (von A mit AB2 erledigt, `466eec0`, `78b4c4b`; B zieht in BAB2 nach):
    - `DestructiveRow` mit `onTap: null` und `subtitle` (gedimmt, `Semantics(enabled: false)`) für „Gespräch löschen“
      ohne Gespräch (Avo §10.1). Bis dahin liest VoiceOver „gedimmt“, der Titel sieht aber aktiv aus.
    - `StatusRow`: die Aktion bricht nicht um und läuft bei 320 pt ×1,35 über; B nutzt kurze Aktionen.
    - Eine B-Routendatei `system_routes.dart` in `profile_routes.dart` einhängen; bis dahin liegen `/settings/siri` und
      `/settings/widgets` in `avoSettingsRoutes` (nicht hinter dem Avo-Modul).
    - Suche (`settings_search_index.dart` `_visible`): Modul der Zeile **und** der Seite prüfen. Heute findet die Suche
      bei Avo aus und Kalorien an die Avo-Zeile „Kalorien, Gewicht und Ziele“, der Tipp zeigt nur „Avo ist aus“.
    - `PinnedListNotifier._load` überschreibt einen Pin, der vor dem Laden gesetzt wurde (Rennen). B pinnt in
      `AvoSettingsBridge` nach dem Laden erneut; besser wäre, dass `_load` einen schon gesetzten Pin stehen lässt.
    - `SettingsExternalActions.openUrl` gibt nichts zurück; fehlt die Kurzbefehle-App, passiert beim Tipp nichts.
      Bitte `Future<bool>`, dann zeigt B einen Hinweis.
    - A-Aufrufer können umstellen: `unsentChangesProvider` → `pendingChangesCountProvider` (zählt die richtigen
      Schlüssel pro Konto), eigene E-Mail-Änderung → `SupabaseService.requestEmailChange`/`verifyEmailChange`,
      `DeletionSummary.openBalances` → `openSplitBalancesCountProvider`, Pro-Zeile → `proSubscriptionDetailsProvider`,
      Präsenz → `sharePresenceProvider`, Abendessen-Kategorie setzt B's Sender schon über `notif_dinner_ideas` durch.

17. **Nach BAB1 (Umstellung auf AB1):** (1) von A erledigt (`004b3fd`), B hat das eigene Semantik-Label im Badge
    in BAB2 entfernt; (3) entfällt, `offer_module_off_body` ist gelöscht; offen bleibt (2).
    - ~~**A-C1 Angebotspille in `ItemRow`**~~ (Liste und Einkaufsmodus, A's Dateien): `itemOfferRowExtras` aus `b_slots.dart`
      in der Zeile aufrufen und durchreichen:
      `final o = itemOfferRowExtras(context, ref, listId: listId, item: item, shoppingMode: shopping);` dann
      `ItemRow(…, trailing: ItemOfferBadge(listId: listId, item: item, compact: shopping),
      trailingSemanticsLabel: o?.semanticsLabel, trailingActions: o?.actions ?? const {},
      contextMenuItems: [...eigeneEinträge, ...?o?.menuItems])`.
    - **A-D1 Doku:** `ItemPrice.retailer` (`item_batch.dart`) ist der Händlername in Verzeichnis-Schreibweise („Lidl“,
      „Aldi Süd“), nicht die Ketten-ID; das lesen Kassenzettel-Verlauf, Markterkennung und `isOfferPriceTaken`. Bitte
      den Doc-Kommentar so ändern.
    - ~~**A-C7 Modul aus:** `ModuleGate` für `AppModule.offers` mit `body:`~~ entfällt (Antwort an A, 09.11.): den
      `ModuleGate` um `/offers` **nicht** wieder einsetzen, `_OffersGate` deckt alles ab (Nr. 15). Es gibt keinen
      anderen A-Ort, der für Angebote `showModuleOffAlert` zeigt. B entfernt `offer_module_off_body` in BAB2 oder nutzt
      ihn selbst in `_OffersGate`.

Erledigt von A: 1 Paywall ohne Angebote (`10f30c6`), 3 Ordner `screens/system` und `evals` für B (`4d5e8fc`),
5 kein App-Remount (`91ecbc8`). Offen: 2 (`showAppBottomSheet` noch behalten), 4 (Kategorisierung umstellen, sobald
`categorizeLocal` gepusht ist). Danke auch für `addItems`/`undoAddItems` und `parseItemInput`: Der Wochenplan und Avo
nutzen beide direkt.

18. **Nach BAB2:**
    - `recipe_detail_screen.dart` `_offerSummary` kann auf `recipeOfferSummaryShowsProvider(recipeOfferSummaryKey(recipe,
      listId))` aus `b_slots.dart` umstellen und die eigenen Zeilen mit `recipeOffersCachedProvider`, `recipeOfferKey`,
      `offerListNameProvider` und `remember` streichen; `RecipeOfferSummary` gibt die Angebote jetzt selbst an die
      Zutaten-Pillen weiter.
    - `all_lists_new_list.dart`: den direkten Import von `store_for_list_provider.dart` streichen (Info-Lint
      `unnecessary_import`, beides kommt jetzt aus `b_slots.dart`).
    - Ohne Nutzer, also löschbar: `screens/home/widgets/nudge_card.dart`, `data/models/recommendation_item.dart`.

19. **Nach W10 (B8a, Einkauf abschließen V1–V3, `feature/b8-history`):**
    - **A-V9 (dringend, sonst doppelter Erfolgsmoment):** `openCheckoutFlow` zeigt V3 (`showSuccessMoment` mit
      „9 Artikel bei Lidl · ca. 3,20 € …“) und danach den Hinweis „Einkauf gespeichert · Widerrufen“ selbst. In
      `shopping_mode_screen.dart` `_finish` und `list_detail_screen.dart` `_checkout` den eigenen
      `showSuccessMoment(...)` streichen (nur noch `TipEvent.tripCompleted` notieren und schließen); Schlüssel
      `list_shop_saved_*` entfallen dann. Bei 0 abgehakten Artikeln `openCheckoutFlow` nicht aufrufen.
    - **A-V9 Rest:** `screens/lists/shopping_trip_completion.dart` hat keinen Aufrufer mehr (Alert „Einkauf
      abschließen?“, Sheet, Snackbar): löschen. Danach löscht B `screens/lists/widgets/checkout_store_sheet.dart`
      (Bottom-Sheet, Verstoß gegen die feste Regel; heute nur noch von dieser Datei importiert) und die Schlüssel
      `complete_shopping_question`, `complete_shopping_checked_message`, `shopping_complete_push_*`, falls frei.
    - **A-V3:** `AmountField` (kompakt/groß, Locale-Eingabe, Cent). Bis dahin nutzt B `HistoryAmountField` in
      `screens/history/widgets/amount_field.dart`; Regel `parseAmountCents` in `data/services/trip_split_math.dart`.
    - **A-V11:** `navigation_service.dart`: Push-Typen `shopping_complete` und `expense_split` tragen jetzt
      `history_id`; Tippen soll `historyTripLocation(historyId)` (`/history/:tripId`, ab W11) öffnen.
    - **A-V12:** Listen-Übersicht „Verlauf“: `historyEntrySummaryProvider` (`HistoryEntrySummary{month,
      tripsThisMonth, hasTrips}`, synchron) und `openBalancesSummaryProvider` (`OpenBalancesSummary?{openCount,
      owedToMeCents, iOweCents, totalOpenCents, people}`, null bei Modul aus) aus
      `presentation/state/trip_history_provider.dart`; Export in `b_slots.dart` ist ergänzt.
    - **Neu A-V23:** `ItemRepository.removeItems(listId, ids)` ohne Push pro Artikel. Nur der Rückfall ohne Migration
      löscht die abgehakten Artikel heute selbst in einem Aufruf (wie vorher `shopping_trip_completion.dart`).
    - `AppFilterChip` ohne `trailing`: „Anderer Markt …“ zeigt kein `chevron.right` 11 (Spec V1 Punkt 3).
    - **Neu A-V24:** `AvoToast.show(onDismissed:)` (wenn der Hinweis geht, auch nach VoiceOver-Pause). Mit VoiceOver
      gibt B die Mitteilungen „… hat eingekauft“ heute erst nach 2 min frei, weil das Ende des Hinweises unbekannt ist.
20. **Nach W11 (B8b, Verlauf V4–V13, `feature/b8-history`):** Routen `/history/:tripId` (V5),
    `/history/:tripId/amount` und `/history/:tripId/split` (V6, V7, `rootNavigatorKey`) und `/splits` (V8,
    `historyBranchRoutes[AppBranch.lists]`) sind da; Pfade in `screens/history/history_paths.dart`
    (`historyTripLocation`, `historyLocation(listId:)`, `splitsLocation(done:)`).
    - **A-V13:** Home `HomeSplitHint()` mit `homeSplitHintHasContentProvider` (synchron, neu in `b_slots.dart`),
      Vorschlag direkt unter der Avo-Karte. `HomeMonthCard`, `HomeSpendingComparison`, `HomeRecentTrips` haben jetzt
      Inhalt; ihre `…HasContentProvider` sind ab dem ersten Frame richtig. `HomeSavingsGoal` bleibt leer (§5 Zeile 9).
    - **A-V14:** bestätigen, dass `context.push('/history/<id>')` aus Home oder dem Avo-Tab in den Listen-Tab wechselt
      und dort Verlauf und Detail stapelt (B pusht so aus V11 und aus Avo „Ansehen“).
    - **A-V12:** die Zeilen „Einkäufe“ → `context.push(historyLocation())`, „Offene Beträge“ →
      `context.push(splitsLocation())` (nur Modul Kosten teilen).
    - **A-V19:** `ItemRepository.addItems(skipOpenDuplicates: true)`; bis dahin filtert B in V5 die offenen Artikel
      vorher selbst heraus (gleicher Name ohne Groß/klein), sie werden nie zusammengeführt.
    - **A-V4:** Balken mit Auswahl und zweiter Kürzelzeile „bisher“, Tokens `chartBar`/`chartHighlight`/
      `monthCardGradient`. B wählt heute über eine eigene Trefferfläche über `AvoBarChart` (gleiche Geometrie), ohne
      „bisher“-Zeile; der Monatsverlauf auf Home ist `tintSoft` über `surface` statt #EEF7EF.
    - **A-V6:** Zeile mit Wert und Pull-down („Bezahlt von“); B nutzt bis dahin eine eigene Zeile in V7.
    - **A-V21:** großer Titel für Verlauf und Offene Beträge auf dritter Ebene (B zeigt ihn schon über `OffersPage`).
    - **A-V9 Rest** (siehe 19) bleibt offen: solange `shopping_trip_completion.dart` lebt, zeigt
      `tool/design_check.sh B` noch die Funde in `checkout_store_sheet.dart`.

## Erledigte Anfragen von Teil A

- **AB2 und A12 „Von Teil B“** (Commit mit dieser Zeile): `/settings/siri` und `/settings/widgets` liegen in
  `systemSettingsRoutes`; Siri zeigt einen Hinweis, wenn `openUrl` `false` meldet; Kommentar über `offersRootRoutes`
  korrigiert, `offer_paths.dart` nimmt die Muster aus `RoutePaths`. `b_slots.dart` exportiert zusätzlich
  `listStoreRepositoryProvider`, `storeInfoForChain`, `recipeOfferSummaryKey`, `recipeOfferSummaryShowsProvider`
  (A's `todayListProvider`/`listsTodayFirstProvider` bleiben A's Exporte; B liest sie direkt). `offerTargetListsProvider`
  folgt `listsTodayFirstProvider`; „Neue Liste …“ öffnet `openNewListEditor(storeChainId:)`, sucht man im Editor einen
  anderen Markt aus, kommt nur der Artikel ohne Angebot auf die Liste. `notificationCategoryForPushType`:
  `shopping_started` → „Jemand kauft ein“, `expense_split`/`split_reminder` → „Offene Beträge“ (der Wochenplan-Sender
  kommt mit B7). `RecipeOfferSummary` meldet Angebote auch beim Einhängen mit schon geladenen Daten an die Pillen (Test).
  Gelöscht: `avo_nudge_card`, `price_comparison_nudge_card`, `pending_splits_banner`, `calorie_recipe_nudge_card`,
  `personal_flyer_card`, `split_trip_nudge_card`, `ml_recommendation_service` mit Test, `offer_module_off_body`. Die
  Paper-Shims hängen nur noch an Kalorien- und Verlaufs-Screens, die B6b und B8 ohnehin neu bauen.

- **A8 „Von Teil B“** (Commit mit dieser Zeile): Routen `/settings/health`, `/settings/avo`, `/settings/siri`,
  `/settings/widgets` (`/settings/plan` kommt mit B7); eigene Suchliste `bSettingsSearchEntries` mit Seiten und Zeilen,
  `RowHighlightScope` in allen B-Einstellungsrouten (A's OK für die Änderung an `settings_search_index.dart` und
  dessen Test kam per Nachricht); `AvoSettingsBridge`-Schlüssel ohne `accent_color`; Uhrzeiten aus
  `setp_notif_time_*`; `pendingChangesCountProvider`, `openSplitBalancesCountProvider`,
  `subscriptionRenewsOnProvider`/`subscriptionFamilySharedProvider` (ehrlich `null` bis `verify-subscription`),
  `SupabaseService.requestEmailChange`/`verifyEmailChange`, Zwischenspeicher bei `signedOut` leeren, Avo-Zeile
  „Konto löschen“ → `/settings/account/delete`. Präsenz: nur die Sperre `sharePresenceProvider`, einen Präsenz-Kanal
  gibt es noch nicht. Abschnitt Stimme auf der Avo-Seite kommt mit B5b, Apple Health und Wasser auf der
  Gesundheitsseite mit B6b.
- **A6 (1) Allergene** (Commit mit dieser Zeile): `allergen_matcher.dart` kennt Feta, Halloumi, Gouda, Emmentaler,
  Cheddar, Camembert, Brie, Pecorino, Gorgonzola, Burrata, Ghee, Skyr, Paneer, Frischkäse, Buttermilch, Crème fraîche
  Crème double, Edamer, Labneh, Raclette und Manchego unter Milch **und** Laktose („Brief“ und „Edamame“ sind
  ausgenommen). Die lokale Ergänzung im Rezeptdetail kann
  raus. **A6 (2)** `RecipeOfferSummary`, `IngredientOfferBadge` kommen mit Angebote S15, `addRecipeToPlan` mit B7.
- **Simulator-Funde A** (Commit mit dieser Zeile): (1) Fälschlich „Offline“: `connectivity_plus` 5 meldet auf iOS
  `none`, wenn der Netzpfad eine unbekannte Schnittstelle nutzt. `ConnectivityService` prüft ein „none“ jetzt mit
  einer echten Anfrage an Supabase und wiederholt sie offline alle 20 s. (2) Mitteilungsabfrage ohne Erklärung beim
  Öffnen einer Liste: `flutter_app_badger` fragte bei jedem Aufruf nach Erlaubnis. Ersetzt durch den Kanal
  `shoply/app` (`AppBadge.clear()`, fragt nie), Paket entfernt.
- **Nach A5** (Commit mit dieser Zeile): `OfferSuggestionsBar` braucht jetzt `listId`, `onSelect` und
  `ListPriceSummaryBar` sind gelöscht. `b_slots.dart` exportiert `restockSuggestionsProvider` und `RestockSuggestion`.
  `openCheckoutFlow` zeigt keine eigene Bestätigung mehr (kein Fertig-Screen, keine grüne Snackbar, keine
  Meilenstein-Zeile) und kommt nach dem Speichern sofort mit `true` zurück; den Erfolgsmoment zeigt der Host. „Kosten
  aufteilen“ bleibt über die Home-Karte erreichbar, bis B8 den Abschluss neu baut. Unbenutzt in A's Datei
  `translations/lists.dart`: `trip_completed_items`.
- **Vorrang Stufe 1 – Slot-Hüllen** (`d449d9c`): alles aus der Tabelle in `prompt-b-vorrang.md` mit der dortigen
  Signatur, exportiert aus `b_slots.dart`. Übergänge, bis A umgebaut hat: `OfferSuggestionsBar` nimmt zusätzlich
  noch `onSelect:` und `listId` ist so lange nullable; `RecipeOffersCard` nimmt zusätzlich noch `request:`.
  `ArticleImage` ist bis B4 eine neutrale Fläche in `context.colors.fill`. `storeForListProvider` liefert nur einen
  **bestätigten** Markt (ausdrücklich gewählt), eine bloße Vermutung bleibt `null`; die Vermutung mit Quelle gibt es
  als `storeGuessForListProvider` (async). `openCheckoutFlow` öffnet vorerst den heutigen Abschluss im Vollbild.
  Entfernt: die marktübergreifende „Spare bis zu“-Zeile im Vorschlags-Panel (Marktvergleich).
- **Vorrang Stufe 2 – Home-Abschnitte** (Commit mit dieser Zeile): `HomeSavingsHint`, `HomeMonthCard`,
  `HomeSpendingComparison`, `HomeSavingsGoal`, `HomeCaloriesToday`, `HomeRestockTile`, `HomeOffersTile`,
  `HomeWaterTile`, `HomeRecentTrips`, `HomeCookToday` mit je `home…HasContentProvider` (synchron, heute `false`),
  Datei `lib/presentation/widgets/home_sections/home_sections.dart`, über `b_slots.dart` exportiert, Test mit
  `layoutMatrix`. Die alten Home-Karten überführe bzw. lösche ich, sobald Home (A4) sie nicht mehr zeigt.
- **Vorrang Stufe 3 – Avo im Tab** (Commit mit dieser Zeile): `/avo` ist die Wurzel des Avo-Tabs, kein `pop()` und
  kein Zurück-Knopf mehr, die Eingabe sitzt über der Tab-Bar (`ShellInsets.aboveTabBar`). `buildAvoRoot` liest
  `?q=` und schickt die Frage genau einmal (`AvoInitialQuestion`, getestet). **`avoScreenContextProvider`** liegt in
  `lib/presentation/providers/avo_screen_context_provider.dart` (`StateProvider<AvoScreenContext?>`,
  `AvoScreenContext { String screen; String? listId; String? listName; }`), auch über `b_slots.dart` exportiert.
  Bitte in den A-Screens setzen (Liste, Einkaufsmodus, Rezept, Home). Avo liest ihn ab dem B5-Umbau.
- `claude/daily`: in Jannis' Account nicht vorhanden (siehe 07.11.), nichts zu pausieren.
- Kalorien-Alias: `calorieTrackingEnabledProvider` folgt `AppModule.calories`; `.notifier.setEnabled` bleibt für die
  A-Aufrufer gültig und schreibt ins Modulsystem.
- Kill-Switch: `offersRemoteEnabledProvider` und `offersAvailableProvider` (Modul an **und** Kill-Switch an).

## Fragen an den Owner

Entschieden am 07.11.2026:
- S0 gilt für Teil B als erreicht (inzwischen auch von A gemeldet).
- Modelle: Kategorien, Empfehlungen, Nährwert-Schätzung `claude-haiku-5-5`; Avo-Chat, Essens- und Zettelfotos
  `claude-sonnet-5-5`.
- Claude-API-Key ist vorhanden. Der Owner setzt das Supabase-Secret selbst.
- Migrationen und Edge-Function-Deploys: Teil B fragt vor jedem einzelnen Schritt und führt erst nach dem Ja aus.
- Angebote: Quelle läuft bis zur Lizenz weiter (Plan 8), Kill-Switch standardmäßig an, Partneranfrage parallel.
- KI-Limits pro Person und Tag: **Pro** Avo 60, Essensfoto 15, Zettel-Import 10, Kategorien 500, Empfehlungen 30.
  **Free** so knapp, dass es fast nichts kostet: Avo 3, Essensfoto 1, Zettel-Import 1, Kategorien 200,
  Empfehlungen 5. Die Werte liegen in `app_flags.ai_limits` und lassen sich ohne Deploy ändern.
- Crash-Reporting: Firebase Crashlytics.
- Apple Health, Barcode-Kamera, Sprachmodus: eigene Swift-Kanäle, kein Fremdpaket.
- Arbeitsweise: mehr Agenten und Prüfungen, gründliche Design-Reviews mit den Design-Skills, alter Code sofort raus;
  am Ende Simulator-Durchgang mit Screenshots aller Screens und Überarbeitung von allem, was nicht perfekt aussieht.

Entschieden am 08.11.2026:
- **Name „Shoply“ verschwindet überall** (nach Teil B, als letzter Schritt, wenn A und B ruhen): alles Sichtbare
  (Texte, Links, Domains) und der ganze Code (Dart-Paket `shoply` → `avo` samt Imports, Klassen, Kanäle,
  Widget-Kinds), Docs, Ordner und Repo-Name. **Bleiben:** Bundle-ID `com.dominik.shoply`, App-Group
  `group.com.shoply.app`, Abo-Produkt-IDs `shoply_premium_*`, Firebase-/Supabase-Projekt (sonst neue App im App
  Store). Neues URL-Schema `avo://`, alte `shoply://`-Links funktionieren weiter. Gespeicherte Schlüssel mit
  „shoply“ werden migriert, nicht einfach umbenannt.

Offen:
- „24 Stunden, nur auf diesem iPhone“ (Avo §10) heißt jetzt „Bis zu 24 Stunden …“, weil das Gespräch nur im
  Arbeitsspeicher liegt; „wenn noch Budget übrig ist“ (Kalorien S23) heißt „wenn noch Kalorien übrig sind“. Bitte
  bestätigen.
- Avo-Tab (Empfehlungen umgesetzt, bitte bestätigen): Karte vor Text (K2); „Neues Gespräch“ als Glas-Knopf (K6/K7);
  Pro-Zeile beim Tageslimit höchstens 1× pro Woche, nur Free; fester Vorschlag „Setz Backpapier dazu“ im
  Einkaufsmodus (Spec-Wortlaut) – gewollt?
- **Abo-RPCs** (Advisor, alt): Sofortmaßnahme angewendet (`20261108003000`), kein `anon` mehr, nur das eigene Konto.
  Selbst-Pro ohne Beleg bleibt bis zur Belegprüfung möglich (`docs/OPEN-ISSUES.md` oben).
- Gemini-Key widerrufen und Monatsgrenze in der Claude Console setzen (Owner).
- Kontakt-E-Mail für den Open-Food-Facts-User-Agent (`Avo/<version> (<E-Mail>)`).
- Berechtigungstexte (Mikrofon, Spracherkennung, Kamera, Health) und HealthKit-Capability im Developer-Portal.
- Welche B-Funktionen Pro werden (Angebote nie). Kommt mit der A9-Analyse.
- Partneranfrage verschicken (Entwurf folgt in `docs/redesign/angebote-partneranfrage.md`); Supermarkt-Logos nur mit
  Erlaubnis.
- Illustrationen für Artikelbilder erzeugen (Bild-Prompts folgen in `docs/redesign/artikelbilder-prompts.md`).
- Wann der alte Gemini-Key widerrufen wird (alte Builds rufen ihn noch auf).
