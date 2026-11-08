# Status Teil B (Jannis, Mac 2): KI, Daten, Module und System

Aufbau laut [`arbeitsteilung.md`](arbeitsteilung.md) Abschnitt 5. Teil B schreibt nur diese Datei.

## Stand

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
| S4 Angebote abgesichert (B) | Logik fertig (`26677f3`): keine Ersatz-Keys, Kill-Switch, Wortlaut, nur Listen-Markt; Slots noch Hüllen bis zum Zeichnen mit S2b | 08.11.2026 | `26677f3` |
| S5 Bereiche fertig (B) | offen | | |
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

Erledigt von A: 1 Paywall ohne Angebote (`10f30c6`), 3 Ordner `screens/system` und `evals` für B (`4d5e8fc`),
5 kein App-Remount (`91ecbc8`). Offen: 2 (`showAppBottomSheet` noch behalten), 4 (Kategorisierung umstellen, sobald
`categorizeLocal` gepusht ist). Danke auch für `addItems`/`undoAddItems` und `parseItemInput`: Der Wochenplan und Avo
nutzen beide direkt.

## Erledigte Anfragen von Teil A

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

Offen:
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
