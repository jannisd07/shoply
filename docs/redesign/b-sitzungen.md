# Teil B: eine Sitzung je Arbeitspaket

Stand 09.11.2026. Owner-Entscheidung 09.11.2026 (Wochenlimit): **jede Claude-Sitzung bearbeitet genau ein Paket** und
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
| **BA8 Wünsche von A aus A8** (Einstellungsseiten, Bridge-Schlüssel, Schnittstellen) | **Als Nächstes** (angefangen, Zweig `feature/b-settings-a8`) | unten, `a8-stand.md` „Von Teil B“ |
| B7 Wochenplan | angefangen (Zweig `feature/b7-plan`) | `b-screens/wochenplan.md` |
| B8 Verlauf, Einkauf abschließen, Kosten teilen, Home-Abschnitte | offen | `b-screens/verlauf-kosten.md` |
| B5b Avo: Sprachmodus, „So arbeitet Avo“, Avo-Einstellungen, Foto über `shoply/camera` | offen | `b-screens/avo.md` §8–§10 |
| B6b Kalorien: Woche, Gewicht, Workouts, Challenges, Ideen, Apple Health, Fotos löschen | offen | `b-screens/kalorien.md` S11, S15–S24 |
| B4 Artikelbilder | offen (Logik da, Bilder fehlen) | Plan B4 |
| B9 Widgets, Siri, Kontrollzentrum, Mitteilungen | offen | Plan P3 B9, Konzept 19 |
| B3b Crashlytics | offen (pubspec, Pods, iOS-Build) | Plan B3 |
| B10 Qualität, S6 Gegenprüfung von A, Simulator-Durchgang mit Screenshots | offen | Plan P3 B10 |
| BR Umbenennung „Shoply“ → „Avo“ | ganz am Ende, wenn A und B ruhen | `status-B.md` „Entschieden am 08.11.2026“ |

Reihenfolge: BA8, B7, B8, B5b, B6b, B9, B4, B3b, B10, BR. A's Wünsche an B (status-A, `aN-stand.md` „Von Teil B“)
dürfen vorgezogen werden, wenn A darauf wartet.

### BA8 Wünsche von A aus A8 (Als Nächstes)

Auftrag mit allen Punkten: `a8-stand.md` „Von Teil B“. Reihenfolge: Schnittstellen zuerst (5 `pendingChangesCountProvider`,
`openSplitBalancesCountProvider`, Abo-Status; 6 `SupabaseService.requestEmailChange`/`verifyEmailChange`; 7 Zwischenspeicher
bei `signedOut` leeren, Avo-Antwort „Lösch mein Konto“ → `/settings/account/delete`), dann 1 Routen `/settings/health`,
`/settings/avo`, `/settings/siri`, `/settings/widgets` (`/settings/plan` gehört zu B7), 2 eigene Suchliste und
`RowHighlightScope`/`HighlightableRow`, 3 AvoSettingsBridge-Schlüssel (`accent_color` streichen), 4 Mitteilungszeiten aus
`setp_notif_time_*`, 8 Presence nur mit `sharePresence`.
Gebaut im Worktree `~/Apps/shoply-neu-wt/b8-offer-slots`, Zweig `feature/b-settings-a8` (auf origin gesichert,
`0620e1f`, nicht auf `main`): Punkte 5, 6 (`513d9c1`), 7 mit neuem Avo-Tool `show_settings_link` (`2a67b51`), 3
(`40f2e56`), 4 (`1ca7af1`), 1 und 2 als `wip` (`0620e1f`: Seiten Avo, Kalorien & Gesundheit, Siri, Widgets; eigene
Suchliste mit Zeilen und Hervorhebung). Punkt 8: nur der Schalter, es gibt noch keinen Presence-Kanal.
**Noch zu tun:** Barrierefreiheits- und Text-Review der neuen Seiten, volle Testsuite (nur gezielte Läufe grün),
CHANGELOG/OPEN-ISSUES/status-B, unabhängiges Review mit Fix-Runden, Rebase, Merge. Achtung: Der Zweig ändert A's
`settings_search_index.dart` und dessen Test (Brief verlangte es, `owner.sh` meldet es) → vor dem Merge mit A klären.
Der neue Avo-Tool und die Setting-Schlüssel brauchen einen Deploy von `ai` (Owner-Ja; Deno-Tests sind geschrieben,
liefen hier nicht, Deno fehlt: `npx deno test` versuchen). Abo-Felder „verlängert am“/„Familienfreigabe“ bleiben `null`
bis `verify-subscription` (E18-10). Bericht mit „Stand bei Abbruch“: `reports/w7-settings-a8-report.md`.

### B7 Wochenplan

Spec `b-screens/wochenplan.md` S1–S13 (inkl. Einstellungen `/settings/plan`), Tabellen sind angewendet. A-Schnittstellen:
`TipService.instance.markDone(TipId.mealPlan)` beim ersten Plan auf einer Liste, `TipSlot(place: TipPlace.plan, …)`
unter dem Großtitel, `ItemRepository.addItems`/`undoAddItems`, Home `HomeCookToday` (eigene Datei, synchroner
`HasContentProvider`), `addRecipeToPlan(recipeId, day, servings)` für A's Rezeptdetail über `b_slots.dart`. Ob A
`AppModule.mealPlan` schon freigeschaltet hat: `status-A.md`. Angefangen im Worktree `~/Apps/shoply-neu-wt/b5-avo-tab`,
Zweig `feature/b7-plan` (auf origin gesichert, `cbc8eeb`): nur Grundlagen (alle `plan_`-Texte DE/EN, Formate, Pfade,
Ansichtszustand, Store unterscheidet „noch nichts auf dem Gerät“/„Server hat geantwortet“/„je benutzt“, Summierung ohne
Zielliste und mit „Original verwenden“). Kein Screen gebaut, `plan_routes.dart`, `HomeCookToday` und `b_slots.dart`
unberührt. **Vorher mit A klären:** Der Rezepte-Tab hat keinen Platz für die Toolbar-Knöpfe, die schwebende Kapsel und
den grauen Grund des Plans (A-P1–A-P4); A's Menüs haben keine Untermenüs (A-K10); `ModuleGate` zeigt für nicht
freigegebene Module immer die Fehlerseite, auch mit Debug-Freischaltung, also braucht der Plan einen kleinen B-Wächter.
Bericht mit „Stand bei Abbruch“: `reports/w8-plan-report.md`.

### B8 Verlauf, Einkauf abschließen, Kosten teilen

Spec `b-screens/verlauf-kosten.md`. `openCheckoutFlow` ist heute ein Stub ohne eigene Bestätigung (Host zeigt den
Erfolgsmoment); B8 baut den Abschluss im Vollbild (atomar `complete_shopping_trip` als Server-Entwurf, Owner wendet an),
Monatsrückblick, Kosten teilen gleich/individuell mit Erinnern, offene Beträge, Home-Abschnitte `HomeMonthCard`,
`HomeSpendingComparison`, `HomeRecentTrips`, `HomeSavingsHint`/`HomeSavingsGoal`. Alte Sheets löschen
(`split_cost_sheet.dart`, `checkout_store_sheet.dart`). „Kosten teilen“ hat bei Avo kein Widerrufen (Owner-Frage).

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
