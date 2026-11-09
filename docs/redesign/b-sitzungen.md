# Teil B: eine Sitzung je Arbeitspaket

Stand 09.11.2026 (nach BS6). Owner-Entscheidung 09.11.2026 (Wochenlimit): **jede Claude-Sitzung bearbeitet genau ein Paket** und
endet dann. Eine lange Sitzung liest bei jeder Antwort ihren ganzen Verlauf neu (P0–P2 von B lief in einer Sitzung mit
weit über einer Million Tokens). Wissen lebt nur in diesen Dateien, nicht in Sitzungen.

## Start-Prompt (für jede neue B-Sitzung gleich)

```
Teil B des Avo-Redesigns im Repo /Users/jannisdietrich/Apps/shoply-neu. Lies docs/redesign/b-sitzungen.md vollständig
und folge ihr. Bearbeite in dieser Sitzung genau das Paket unter „Als Nächstes“. Wenn es fertig ist: b-sitzungen.md
und status-B.md aktualisieren, committen, pushen, mich erinnern, eine neue Sitzung zu starten, und mir den Start-Prompt
für die nächste Sitzung geben.
```

## Ablauf jeder Sitzung

1. Lesen: diese Datei ganz, `prompt-teil-B.md` §6–§11 (Dateibesitz, Arbeitsweise, Git, Qualität, Owner),
   `status-B.md`, `status-A.md` („Stand“ und alles, was A von B braucht), die Spec des Pakets in
   `docs/redesign/b-screens/` (nur die Abschnitte des Pakets) und den Bericht der Vorgänger-Sitzung, falls genannt.
2. `git fetch -q origin && git merge --ff-only origin/main`, `flutter pub get`, `df -h /System/Volumes/Data` und
   `sysctl vm.swapusage` ansehen (Grenzen unten).
3. Paket bearbeiten (Arbeitsweise unten). Offene Wünsche von A an B gehen vor, wenn A darauf wartet.
4. Abschluss: Paket in der Tabelle unten abhaken, „Als Nächstes“ auf das nächste Paket setzen, die Paket-Notiz unten
   kürzen auf das, was noch fehlt; in `status-B.md` „Stand“, „Meilensteine“, „Anfragen an Teil A“ und „Fragen an den
   Owner“ nachziehen; committen, pushen, A per Nachricht Bescheid geben, wenn A etwas davon nutzt.
5. **Letzte Antwort an den Owner:** kurzes Ergebnis, dann die Erinnerung „Bitte jetzt eine neue Sitzung starten“ und
   den Start-Prompt oben als Codeblock. Danach in dieser Sitzung nichts Neues mehr beginnen.

## Pakete

| Paket | Stand | Unterlagen |
|---|---|---|
| P0 Vorrang-Aufgaben für A, P1 (B1 Claude, B2 Logik, B3 Start, nativer Unterbau) | erledigt | `status-B.md`, Plan `docs/superpowers/plans/2026-11-07-teil-b.md` |
| B2 Angebote: Slots S1–S8 und Screens S9–S16 | erledigt (`d5aff5a`, `e0b7a1b`) | `b-screens/angebote.md` |
| B5 Avo: Tab, Antwortkarten aller Werkzeuge, Foto an Avo | erledigt (`a3a25e2`, `e3a1023`) | `b-screens/avo.md` |
| B6 Kalorien: Tagebuch, Essen eintragen, Foto, Barcode, Menge, Manuell, Ziele | erledigt (`639e04d`) | `b-screens/kalorien.md` |
| BA8 Wünsche von A aus A8 (Einstellungsseiten, Bridge-Schlüssel, Schnittstellen) | erledigt (`c37182f`) | `status-B.md` „Erledigte Anfragen von Teil A“ |
| BAB1 Auf A's AB1-Komponenten umstellen | erledigt (Commit mit dieser Zeile) | `reports/w9-bab1-report.md`, `w9-bab1-review.md` |
| BAB2 Wünsche von A aus AB2 und A12 | erledigt (Commit mit dieser Zeile) | `status-B.md` „Erledigte Anfragen von Teil A“ |
| B8 Verlauf, Einkauf abschließen, Kosten teilen, Home-Abschnitte | erledigt (Commit mit dieser Zeile) | `b-screens/verlauf-kosten.md`, Reste unten |
| BS6 Avo erreichbar, Funde aus S6, Wünsche aus A9/A9b | erledigt (Commit mit dieser Zeile) | `reports/w12-bs6-report.md`, Reste unten |
| **B7 Wochenplan** | **Als Nächstes** (angefangen, Zweig `feature/b7-plan`) | unten, `b-screens/wochenplan.md` |
| B8c Verlauf auf A's S5b/AB3-Bausteine umstellen | offen | unten „B8 Reste“ |
| B5b Avo: Sprachmodus, „So arbeitet Avo“, Avo-Einstellungen, Foto über `shoply/camera` | offen | `b-screens/avo.md` §8–§10 |
| B6b Kalorien: Woche, Gewicht, Workouts, Challenges, Ideen, Apple Health, Fotos löschen | offen | `b-screens/kalorien.md` S11, S15–S24 |
| B4 Artikelbilder | offen (Logik da, Bilder fehlen) | Plan B4 |
| B9 Widgets, Siri, Kontrollzentrum, Mitteilungen | offen | Plan P3 B9, Konzept 19 |
| B3b Crashlytics | offen (pubspec, Pods, iOS-Build) | Plan B3 |
| B10 Qualität, S6 Gegenprüfung von A, Simulator-Durchgang mit Screenshots | offen | Plan P3 B10 |
| BR Umbenennung „Shoply“ → „Avo“ | ganz am Ende, wenn A und B ruhen | `status-B.md` „Entschieden am 08.11.2026“ |

Reihenfolge: B7, B8c, B5b, B6b, B9, B4, B3b, B10, BR. A's Wünsche an B (status-A, `aN-stand.md` „Von Teil B“)
dürfen vorgezogen werden, wenn A darauf wartet.

### Reste aus BA8, BAB1 und BAB2

Offen: Deploy von `ai` (Owner, OPEN-ISSUES 2.), Deno-Tests danach; Owner-Frage zu „Bis zu 24 Stunden“ und „Kalorien
übrig“. Bekannt, nicht behoben (klein): laufende Anfragen können nach dem Abmelden ihr Ergebnis in die gerade geleerten
Zwischenspeicher schreiben (Generationszähler pro Dienst); „Widerrufen“ der Startliste sucht die Liste per Name statt
id. Für B9: Siri-Sätze auf dem Gerät prüfen. Aus BAB1: Anfrage 17 (2) an A (`ItemPrice.retailer`-Doku). Aus BAB2:
Wochenplan-Erinnerung muss beim Planen `NotificationCategory.planReminder` übergeben (B7, es gibt noch keinen Sender);
die Push-Typen `shopping_started` und `split_reminder` sind in der App zugeordnet, aber der Server sendet sie noch nicht
(Erinnern läuft über das System-Teilen). `AppColors`/`PaperColors`/`design_system.dart` hängen nur noch an Kalorien
(`challenges`, `weekly_summary`, `weight_tracking`, `what_can_i_eat`, `macro_bar`, `weight_chart`, also B6b); der
Verlauf ist seit B8 frei davon. `bash tool/design_check.sh B` (A11): Verlauf und Abschluss ohne Funde, keine Sheets
mehr; Rest mit B6b und BS6 abbauen. `integration_test/perf` nie mit gebootetem Simulator laufen lassen (ersetzt die App).
Bewusst so gelassen (Review M1, M11, M12): „Antwort anhalten“
nur bei leerem Feld (Kap. 2.11); S14-Chips ohne Häkchen, VoiceOver „Lidl, 400 m“, Ziehen in S13 nur am Griff (A's
Komponenten). Nicht umgestellt: alte Material-Screens mit `Icons.*` (eigene Pakete) und Symbole ohne `AvoIcons`-Gegenstück.

### B7 Wochenplan (Als Nächstes)

Spec `b-screens/wochenplan.md` S1–S13 (inkl. Einstellungen `/settings/plan`), Tabellen sind angewendet. A-Schnittstellen:
`TipService.instance.markDone(TipId.mealPlan)` beim ersten Plan auf einer Liste, `TipSlot(place: TipPlace.plan, …)`
unter dem Großtitel, `ItemRepository.addItems`/`undoAddItems`, Home `HomeCookToday` (eigene Datei, synchroner
`HasContentProvider`), `addRecipeToPlan(recipeId, day, servings)` für A's Rezeptdetail über `b_slots.dart`. Ob A
`AppModule.mealPlan` schon freigeschaltet hat: `status-A.md`. Angefangen im Worktree `~/Apps/shoply-neu-wt/b5-avo-tab`,
Zweig `feature/b7-plan` (auf origin gesichert, `cbc8eeb`): nur Grundlagen (alle `plan_`-Texte DE/EN, Formate, Pfade,
Ansichtszustand, Store unterscheidet „noch nichts auf dem Gerät“/„Server hat geantwortet“/„je benutzt“, Summierung ohne
Zielliste und mit „Original verwenden“). Kein Screen gebaut, `plan_routes.dart`, `HomeCookToday` und `b_slots.dart`
unberührt. **A hat geliefert (A11b `920ba7e`):** `buildPlanSegment` ist ein Sliver im `CustomScrollView` (A-P1);
`buildPlanFloatingBar` sitzt bei `ShellInsets.aboveTabBar` über dem Inhalt, den Platz unten im Sliver lässt B selbst,
A polstert nur `ShellInsets.bottom` (A-P2); `buildPlanToolbarActions` statt Gespeichert/Mehr (A-P3); Grund
`background`/`backgroundPlain` mit 200 ms Überblendung, das Segment ist lokaler Zustand, `week`/`day` bleiben in der URL
(A-P4); `AvoSubmenu(label:, items:, icon:, subtitle:, enabled:, trailing:, trailingLabel:)` als Eintrag in
`showAvoMenu`, beliebig tief, dazu `showAvoMenu(…, preview:)` (A-K10). Offen bleibt: `ModuleGate` zeigt für nicht
freigegebene Module immer die Fehlerseite, also braucht der Plan einen kleinen B-Wächter. Pro (A9, Variante B): nur
„Avo füllt die Woche“ über `ProGate.run(feature: ProFeatures.planSuggestions)`, „N Zutaten auf Wocheneinkauf“ bleibt
frei ohne Badge. Der Worktree `b5-avo-tab` trägt jetzt BS6 (`feature/bs6`, nach dem Merge löschbar); `feature/b7-plan` neu auschecken.
Bericht mit „Stand bei Abbruch“: `reports/w8-plan-report.md`.

### BS6 Reste

Owner: Secret `ANTHROPIC_API_KEY` fehlt in Supabase (Ursache „Avo nicht erreichbar“), danach Deploy `ai` und
`extract-shopping-list`; APNs-Schlüssel (`BadEnvironmentKeyInToken`). Logs der Edge Functions sind über `query_logs`
(Supabase-MCP, Quelle `function_logs`) lesbar. Wartet auf A (status-B 21): Tipp auf die Testphasen-Erinnerung,
Zettel-Import-Limit, `AvoMotion`-Werte (S6-6), 14 `AvoIcons` (Rest von S6-9), `StatusRow` mit Symbol; danach die
Stellen in B umstellen. Nicht im Simulator geprüft: Titel-Einklappen, Paywall aus der Pro-Zeile.

### B8 Reste

Owner: Migrationen `b_trip_checkout` und `b_trip_checkout_rls` erst auf einem Supabase-Branch testen, dann in der
Reihenfolge aus OPEN-ISSUES anwenden (die RLS-Datei erst, wenn alte Builds weg sind); Frage, ob Home „Ausgaben im
Vergleich“ auch Pro wird. Folgeaufgaben: dauerhafte Warteschlange für Einkäufe, die offline warten (heute nur
Arbeitsspeicher, Neuversuch bei Verbindung), Hinweis „Kosten teilen einschalten“, Abschnitt „Geblieben“, Artikelbilder
im Verlauf (L10, mit B4), A-Bausteine `AmountField` (A-V3), Balkenauswahl (A-V4), Zahler-Zeile (A-V6) ersetzen B's
Übergangsversionen (status-B 19, 20). Kleinere offene Review-Punkte: `reports/w11-review.md` (M3, M5, M10, M11),
Rückgängig einer Aufteilung setzt `total_cost_source` immer auf `user`. A räumt `list_shop_saved_*` auf (S5b).
Nicht auf dem Gerät geprüft: Simulator-Durchgang V1–V12 mit B10.

**B8c (A hat geliefert, S5b und AB3, `s5b-stand.md`/`ab3-stand.md` „Von Teil B“):** `AmountField` statt
`HistoryAmountField`, `AvoBarChart(selectedIndex:, onSelected:)` statt `SpendingBars`, Tokens `chartBar`,
`chartHighlight`, `monthCardGradient` und `AvoTextStyle.numberXL` für die Monatskarte (ersetzt „D2 numberXL cap“ in
`month_review.dart`), `MenuValueRow`/`ValueRow(subtitle:)` für „Bezahlt von“, `AppFilterChip(trailing:)` für
„Anderer Markt …“, `AvoToast.show(onDismissed:)` für die 2-min-Sperre, `ItemRepository.addItemsSkippingOpen` und
`removeItems`, `RowActions` statt `SwipeActions` + `onLongPress` in `trip_row`, `open_balances_screen`,
`trip_detail_screen`, `split_editor_screen`. A-V14: bei `push` bleiben. A-V22 (dauerhafte Warteschlange) bleibt B.

### B5b, B6b, B9, B4, B3b, B10, BR

Siehe Plan und Specs. Hinweise: Sprachmodus setzt `TipService.instance.markDone(TipId.voice)` (T8). Avo's Foto auf den
Vollbild-Kanal `shoply/camera` des Kalorien-Teils umstellen (Systemblatt verstößt gegen die Owner-Regel). B9: Siri-Sätze
mit „Avo“, Widgets lesen den App-Group-Snapshot, keine Live Activity. BR: Paket `shoply` → `avo` samt Imports, Texte,
Links, Docs, Ordner, Repo-Name; Bundle-ID, App-Group, Abo-Produkt-IDs, Firebase/Supabase bleiben; `avo://` neu,
`shoply://` geht weiter; gespeicherte Schlüssel migrieren.

## Arbeitsweise (erprobt in P0–P2)

- **Gemeinsamer Ordner mit A** (`~/Apps/shoply-neu`, `main`). B arbeitet in eigenen Worktrees unter
  `~/Apps/shoply-neu-wt/<paket>` (`git worktree add -b feature/<paket> <pfad> origin/main`, dann `env.dart`,
  `firebase_options.dart`, `ios/Runner/GoogleService-Info.plist` hineinkopieren, `flutter pub get`). Im gemeinsamen
  Ordner nie `git add -A`, `stash`, `checkout`, `switch`, `reset`, `restore`, `clean`; nur eigene Pfade committen
  (`git commit -m "…" -- <pfade>`), abgleichen mit `git fetch -q origin && git merge --ff-only origin/main`.
- **Paket mit Agenten (subagent-driven-development):** Auftrag als Datei (gemeinsame Regeln + Paket-Brief), ein
  Implementierer (opus) pro Worktree, er committet nur auf seinem Zweig, pusht nie. Danach ein unabhängiger Reviewer
  (opus, nur lesend), Fix-Runden durch denselben Implementierer, gezielte Nachprüfung (sonnet, nur lesend) bis sauber.
  Bei knapper Platte prüfen Reviewer nur lesend, ohne Tests.
- **Merge auf `main`:** im Worktree `git fetch origin && git rebase origin/main`, Konflikte in `CHANGELOG.md`/
  `OPEN-ISSUES.md` beide Seiten behalten, `flutter pub get`, `dart analyze` (0/0), `TZ=UTC flutter test` (ganze Suite,
  ~4–7 min), dann `git push origin HEAD:refs/heads/main` nur, wenn `main` sich seit dem Rebase nicht bewegt hat; im
  gemeinsamen Ordner `merge --ff-only`. A per Nachricht Bescheid geben.
- **Ledger und Briefs** (nicht im Repo, `.superpowers/` ist ignoriert):
  `.superpowers/sdd/2026-11-07-teil-b/progress.md` (alle Entscheidungen und Commits), `briefs/common.md` (gemeinsame
  Regeln für jeden Agenten: Hard Rules, D2, Texte, Tests, Bericht), `briefs/w*.md`, `reports/w*-report.md` und
  `*-review*.md`. Für einen neuen Agenten `briefs/common.md` mitgeben.
- **Native Änderungen** (Swift, `project.pbxproj`, Podfile): einmal `flutter build ios --simulator --debug` im
  Worktree, danach `build/ios` löschen. Vorher mit A absprechen, wer baut.
- **Server:** Migrationen und `supabase functions deploy` nur nach Einzel-Ja des Owners; Entwürfe in
  `supabase/migrations/`. Die Supabase-MCP-Tools gehen (`apply_migration`, `get_advisors`, `execute_sql` lesend).

## Stolperfallen

- **Platte:** macOS lädt im Hintergrund ein Update (Preboot ~21 GB). Unter 15 GB keine neuen Worktrees, unter 10 GB
  keine Builds. Owner 09.11.: Platz selbst schaffen ist erlaubt, aber nur Regenerierbares (Xcode `iOS DeviceSupport`,
  `DerivedData`, `~/Library/Caches/org.swift.swiftpm`, VS-Code-Update-Reste, ungenutzte Simulatoren mit
  `xcrun simctl erase`); nie Downloads, Papierkorb oder fremde Projekte. Das macOS-Update nicht anfassen
  (Systemeinstellung, macht der Owner).
- **RAM (16 GB):** höchstens 3 eigene Agenten; mit A zusammen höchstens 2 gleichzeitige `flutter test`-Läufe. Verwaiste
  `flutter_tester` (PPID 1) aus abgebrochenen Läufen selbst beenden (`lsof -p <pid>` zeigt den Worktree).
- **`flutter pub get`** ändert oft `macos/Flutter/GeneratedPluginRegistrant.swift`: zurücksetzen
  (`git checkout -- <datei>` im eigenen Worktree), sonst bricht `git rebase --continue` mit „You must edit all merge
  conflicts“ ab.
- **Zeitabhängige Tests:** ganze Suite mit `TZ=UTC`; A's Tests mit `DateTime.now()` sind nachts flackrig gewesen.
- **zsh:** `$var:` wird zum Modifier (`${var}:` schreiben), Strings werden nicht aufgeteilt (Arrays nehmen), `cat >>
  datei` ohne Heredoc wartet ewig auf Eingabe.
- **`whenComplete(() => map.remove(key))`** gibt die Future selbst zurück und wartet ewig: Blockkörper schreiben.
- **Plugins, die heimlich fragen:** `flutter_app_badger` fragte bei jedem Aufruf nach Mitteilungen (ersetzt durch
  `AppBadge.clear()`). `image_picker` fährt Kamera und Fotos von unten herein (Systemblatt, Owner-Regel): den
  Vollbild-Kanal `shoply/camera` nehmen. `permission_handler` liefert für die Kamera ohne `PERMISSION_CAMERA` einen
  festen Status: Fehlercodes von `image_picker` auswerten.
- **Avo-Sicherheit:** nichts Sensibles ohne Tipp (Kosten teilen, Ziele, Allergie/Ernährung entfernen, Essen eintragen,
  Plan ersetzen, Löschen nur mit Einmal-Schlüssel); jeder Tool-Ergebnis-Pfad durch den Zustimmungsfilter; Postleitzahl
  und Fehlertexte nie ans Modell; Namen aus geteilten Listen nur gekürzt und ohne Anführungszeichen.
- **Deep Links** füllen nur vor (`shoply://avo?q=`); sofort senden nur in der App über `openAvoWithQuestion`.

## Offen beim Owner (gesammelt, Details in `status-B.md` und `OPEN-ISSUES.md`)

- Alten Gemini-Key widerrufen; Monatsgrenze in der Claude Console.
- Belegprüfung bei Apple (heute kann sich ein angemeldetes Konto selbst Pro setzen).
- Supabase-Einstellungen für die Anmeldung per Code (Mailvorlagen `{{ .Token }}`, 60 s, 3600 s, Passwortregeln).
- Angebote: Tabelle `user_offer_prefs` (Wahl pro Konto auf dem Server), Region pro Gerät statt pro Konto, Partneranfrage,
  Kontakt-E-Mail für den Open-Food-Facts-User-Agent, Supermarkt-Logos nur mit Erlaubnis.
- Avo: Karte vor Text (K2), „Neues Gespräch“ als Glas-Knopf (K6/K7), Pro-Zeile höchstens 1× pro Woche (F1),
  „Setz Backpapier dazu“, Kosten teilen ohne Widerrufen, Schätzkarte → Mengen-Screen von B6.
- Kalorien: stimmt „Das Foto wird nur für die Schätzung genutzt und privat gespeichert“ zur Claude-API?
- HealthKit-Capability im Developer-Portal (Login nötig), Geräteprüfungen (Kamera, Barcode, VoiceOver-Fokus).
- macOS-Update abbrechen oder installieren (gibt ~20 GB frei).
- `TODO(human)` in `resolveStoreForList` (`store_detection_service.dart`): welche Markt-Quelle gewinnt.

## Abstimmung mit Teil A

- A's Sitzung über `ListAgents` finden und per `SendMessage` schreiben; Wünsche an A zusätzlich in `status-B.md`
  „Anfragen an Teil A“, A trägt Erledigtes in `status-A.md` ein. A's Wünsche an B stehen in `status-A.md` und
  `aN-stand.md` „Von Teil B“; B trägt Erledigtes in `status-B.md` „Erledigte Anfragen von Teil A“ ein.
- A's Dateien nur ändern, wenn A es in der Nachricht ausdrücklich erlaubt (bisher: zwei Testdateien und einzelne Zeilen
  in `list_detail_screen.dart`, `auth_gateway.dart`, `recipe_detail_screen.dart`), immer im selben Commit wie B's Seite,
  damit `main` grün bleibt.
- `b_slots.dart` ist A's einzige Tür zu B: bestehende Exporte und Konstruktoren nie ändern, nur ergänzen.
- Vor iOS-Builds und vor Gesamtsuiten kurz Bescheid geben; die Umbenennung „Shoply“ → „Avo“ nur, wenn beide ruhen.
