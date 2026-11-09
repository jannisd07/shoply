# Teil A: eine Sitzung je Arbeitspaket

Stand 09.11.2026 (A9 erledigt mit Owner-Variante B, `a9-stand.md`). Owner-Entscheidung 09.11.2026 (Wochenlimit): **jede Claude-Sitzung bearbeitet genau ein Paket** und
endet dann. Eine lange Sitzung liest bei jeder Antwort ihren ganzen Verlauf neu (A5–A8 lief in einer Sitzung mit über
600.000 Tokens Kontext). Wissen lebt nur in diesen Dateien, nicht in Sitzungen.

## Start-Prompt (für jede neue A-Sitzung gleich)

```
Teil A des Avo-Redesigns im Repo /Users/jannisdietrich/Apps/shoply-neu. Lies docs/redesign/a-sitzungen.md vollständig
und folge ihr. Bearbeite in dieser Sitzung genau das Paket unter „Als Nächstes“. Wenn es fertig ist: a-sitzungen.md
und status-A.md aktualisieren, committen, pushen, mich erinnern, eine neue Sitzung zu starten, und mir den Start-Prompt
für die nächste Sitzung geben.
```

## Ablauf jeder Sitzung

1. Lesen: diese Datei, `prompt-teil-A.md` §6–§11 (Dateibesitz, Arbeitsweise, Git, Qualität, Owner), `status-A.md`,
   `status-B.md` („Anfragen an Teil A“), das `aN-stand.md` des letzten Pakets. Das Konzeptkapitel des Pakets erst, wenn
   das Paket es braucht.
2. `git config core.hooksPath` prüfen, `git fetch origin && git merge --ff-only origin/main`, `flutter pub get`.
3. Paket bearbeiten (Arbeitsweise unten). Hat B mehrere Wünsche offen, gehen sie vor (prompt §8.5).
4. Abschluss: `aN-stand.md` schreiben (Ergebnis, Braucht den Owner, Von Teil B, Offen bei A, Bewusst abgewichen),
   Zeile in `status-A.md` (Meilensteine), in dieser Datei das Paket abhaken und „Als Nächstes“ setzen, committen,
   pushen.
5. **Letzte Antwort an den Owner:** kurzes Ergebnis, dann die Erinnerung „Bitte jetzt eine neue Sitzung starten“ und den
   Start-Prompt oben als Codeblock. Danach in dieser Sitzung nichts Neues mehr beginnen.

## Pakete

| Paket | Stand | Unterlagen |
|---|---|---|
| S0, S1, A1–A3, S2 | erledigt | `status-A.md` |
| A4 Home | erledigt | `status-A.md` |
| A5 Listen | erledigt | `a5-stand.md` |
| A6 Rezepte | erledigt | `a6-stand.md` |
| A7 Onboarding, Login, Tipps | erledigt | `a7-stand.md`, `a7-server-entwurf.sql` |
| A8 Profil und Einstellungen | erledigt | `a8-stand.md`, `a8-server-entwurf.sql` |
| AB1 Anfragen von B: Komponenten und Daten | erledigt | `ab1-stand.md` |
| AB2 Anfragen von B: Listen, Router, Reste aus A5–A8 | erledigt | `ab2-stand.md` |
| A9 Pro und Paywall | erledigt (Owner 09.11.2026: Variante B „KI + Komfort“) | `a9-stand.md` |
| A10 App-Icon und Maskottchen | wartet auf den Owner (Maskottchen F-17-11) | prompt §5 A10 |
| A12 Aufräumen und Analysen | erledigt | `a12-stand.md`, `feature-ideen.md` |
| A11 Qualität, Teil 1 | erledigt | `a11-pruefplan.md`, `a11-stand.md` |
| A11b Qualität, Teil 2 | erledigt | `a11b-stand.md` |
| S6 Gegenprüfung von B | erledigt (B6b/B7/B8 folgen in S5) | `s6-stand.md` |
| S5 Bereiche fertig | erledigt (A-V9 und Gegenprüfung B6b/B7/B8 folgen in S5b) | `s5-stand.md`, `abschlussbericht-A.md` |
| **S5b Nachzug von B** | **Als Nächstes**, wenn B8, B7 oder B6b auf `main` ist | unten, `s5-stand.md` |
| A9b Pro, Rest | Ersatz, wenn S5b noch nicht geht und A10 nicht entschieden ist | unten, `a9-stand.md` |

Reihenfolge: zu Beginn mit `git log origin/main --oneline | grep -E "B8|B7|B6b"` prüfen, ob B nachgezogen hat (dann
S5b), und mit `AskUserQuestion` fragen, ob der Owner A10 (Maskottchen F-17-11: 3D-Figur behalten oder neu flach)
entschieden hat (dann A10). Sonst A9b. Erklär dem Owner bei der Frage kurz, worum es geht (er hat am 09.11. „was ist
das überhaupt“ gefragt).

### AB1 Anfragen von B: Komponenten und Daten

Quellen: `status-B.md` „Anfragen an Teil A“ (Punkte 13 und 14 und neuere), `b-screens/angebote.md` §6 (A-C*, A-T*,
A-D1), `b-screens/*.md` „Anfragen an Teil A“, „Komponenten“ in `a6-stand.md` bis `a8-stand.md`. Inhalt: `ItemRow`
(A-C1, kompakte Variante), `AppFilterChip`/`ChipRow` (A-C2), `HintRow` (A-C3), Textfeld-Zeile (A-C5),
`showModuleOffAlert(body:)` (A-C7), Menü-Titelzeile, Sektionen, Glyph (A-C8), `SelectCircle` und sortierbare Zeilen
(A-C9), `AvoComposerField` (Antwort anhalten, `enabled`, `maxLength`, Foto-Pull-down), `AppButton` gefüllt neutral und
destruktiv (+ `destructiveFill`), `NavRow(valueLeading:)`, `AvatarSize.xl` mit Foto, `AvoSearchField` mit Mikrofon,
`AvoToast` mit Ziel, fehlende `AvoIcons`, `ItemRepository`-Preis-Schnittstelle (A-D1). Dazu für B's Wochenplan (`feature/b7-plan`)
A-P1–A-P4 (Platz im Rezepte-Tab für Toolbar-Knöpfe, schwebende Kapsel, grauer Grund) und A-K10 (Untermenüs im
Pull-down), Einzelheiten in `b-screens/wochenplan.md` (nicht verwechseln mit A-P1 „Profil“ aus
`b-screens/angebote.md`, das mit A8 erledigt ist); weitere Kalorien-Wünsche in `b-screens/kalorien.md`. Erledigtes mit Commit in
`status-A.md` („Anfragen von B aus den Angebots-Slots“) eintragen und B Bescheid geben.

### AB2 Anfragen von B: Listen, Router, Reste aus A5–A8

Zuerst `status-B.md` „Anfragen an Teil A“ auf Neues seit AB1 prüfen (mindestens Nr. 16 aus BA8 `c37182f`:
`DestructiveRow` gedimmt mit `onTap: null` + `subtitle`, `StatusRow`-Aktion ohne Umbruch, `system_routes.dart` in
`profile_routes` einhängen, Suche `_visible` prüft Modul von Zeile und Seite, Rennen in `PinnedListNotifier._load`,
`SettingsExternalActions.openUrl` als `Future<bool>`, Aufrufer auf B's neue Provider umstellen) und `ab1-stand.md` „Offen bei A“ lesen (die
neuen Komponenten dort beim Listen-Umbau nutzen, z. B. `ItemRow(trailingSemanticsLabel:, contextMenuItems:)`).

A-C4 (Accessory: B-Block, Fokus zurück), A-L1–A-L4 (Listenkopf mit `StoreChip`, Listen-Info „Markt“ und „Angebote
anzeigen“, Listenkarte, „Neue Liste“ mit Markt, „Liste von heute“), A-R1–A-R3 (Angebots-Routen vor der Shell,
Modul-Wächter, Deep Links), dazu „Offen bei A“ aus `a5-stand.md` bis `a8-stand.md` (Listen-Schalter verdrahten,
Mitteilungs-Kategorien durchsetzen, `recipeAutoAdaptProvider`, `ThemeMode.system`, T6 im Rezepte-Tab,
Startvorschläge im Accessory).

**Erledigt (B hat `feature/b-settings-a8` mit A's OK auf `main` gebracht, `c37182f`):** B's Zweig `feature/b-settings-a8` (auf origin, nicht auf `main`) ersetzt in
A's `settings_search_index.dart` und dessen Test `bSettingsPagesSearchEntries` durch B's eigene Suchliste. Die nächste
B-Sitzung klärt das vor dem Merge; die A-Sitzung prüft den Diff (`git diff main...origin/feature/b-settings-a8 --
lib/presentation/screens/profile test/screens/profile`) und gibt das OK oder bessert nach. B's Übergabe:
`b-sitzungen.md`.

### A11 Qualität für alle A-Screens

Quellen: prompt §5 A11 und §9, `konzept/20-qualitaet.md`, „Offen bei A“ in `ab1-stand.md`, `ab2-stand.md`,
`a12-stand.md` (u. a. „Im Simulator ansehen“ aus AB2: Vorschlags-Panel, Listen-Info, Rezept-Zutaten mit Angeboten,
Rezepte-Tab mit Tipp). Vorher `status-B.md` auf neue Anfragen an A prüfen; die gehen vor. **Zuerst status-B 17 (1):**
`itemOfferRowExtras` aus `b_slots.dart` in Liste und Einkaufsmodus an `ItemRow` durchreichen (`trailingSemanticsLabel`,
`trailingActions`, `contextMenuItems`; genauer Aufruf in status-B 17). 17 (2) ist mit A12 erledigt, 17 (3) entfällt. Simulator-Build mit B
absprechen, vorher `df -h /System/Volumes/Data` (unter 10 GB keine Builds). Erst den Prüfplan schreiben (Screens,
Zustände, Prüfmatrix, Barrierefreiheit), dann Funde beheben.

### A11b Qualität, Teil 2

Quellen: „Offen bei A“ und „Braucht den Owner“ in `a11-stand.md`, `a11-pruefplan.md` §2. **Zuerst die Anfragen von B**
(sie blockieren B): status-B Nr. 18 (BAB2 `659ea0f`: `recipeOfferSummaryShowsProvider` in `_offerSummary`, unnötiger
Import in `all_lists_new_list.dart`, `nudge_card.dart` und `recommendation_item.dart` löschen) und für B7 (Wochenplan)
A-P1–A-P4 und A-K10 aus `b-screens/wochenplan.md`. Zu Beginn fragen, ob der Owner im Simulator (iPhone 17) angemeldet ist; ohne
Anmeldung nur die Code-Punkte. Reihenfolge: Simulator-Rundgang (Screenshots nach `abnahme/a11/`, Funde beheben),
Flows Hinzufügen und Teilen mit `idiotensicher-testen`, fehlende `AvoIcons`-Glyphen für die 30 `CupertinoIcons`-Stellen
(`bash tool/design_check.sh A` zeigt sie), Fehlerzustand der Entwürfe. **Nie** `flutter test integration_test/…` mit
gebootetem Simulator (ersetzt die App, meldet ab). Platte: unter 15 GB keine Worktrees, unter 10 GB keine Builds,
`build/` nach dem Rundgang löschen.

### S6 Gegenprüfung von B

Quellen: prompt §5 A11 „Gegenprüfung“ und §9, `status-B.md` (Meilensteine, „Anfragen an Teil A“ zuerst),
`b-sitzungen.md`, „Von Teil B“ in `a11-stand.md` und `a11b-stand.md`. A prüft B's fertige Screens mit denselben
Maßstäben wie die eigenen (Prüfmatrix, `bash tool/design_check.sh B`, harte Regel keine Sheets/Slider, Simulator-
Stichproben nach Absprache), ändert B's Dateien nie und schreibt Funde als Wünsche in `s6-stand.md` „Von Teil B“
und per Nachricht an B. Vorher fragen, ob der Owner im Simulator angemeldet ist.

### S5 Bereiche fertig

Quellen: prompt §11 („Fertig, wenn“), „Offen bei A“ in `s6-stand.md`, `a11b-stand.md`, `ab1-stand.md`, `ab2-stand.md`;
vorher `status-B.md` „Anfragen an Teil A“ (gehen vor). **A-V9 (status-B 19):** sobald B8 (`feature/b8-history`) auf
`main` kommt, lassen `shopping_mode_screen.dart` und `list_detail_screen.dart` ihren Erfolgsmoment nach
`openCheckoutFlow == true` weg, im selben Push wie B (B meldet sich). Sind B6b, B7 oder B8 schon auf `main`, deren
Screens wie in S6 gegenprüfen (Matrix, `design_check.sh B`, Sheets/Slider) und Funde an B. Rest aus „Offen bei A“
(Filter-Chips mit `recipeShownDiet` nur nach Owner-Frage, Galerie-Einträge, `SwipeActions`-Reste,
`ItemRow`-Vorschlagsvariante). Dann prompt §11 Punkt für Punkt prüfen und den Abschlussbericht für den Owner
schreiben (`abschlussbericht-A.md`: gebaut, offen, Entscheidungen; A9/A10 als offen, falls weiter ohne Entscheidung).

### S5b Nachzug von B

Quellen: `s5-stand.md` und `s6-stand.md` „Offen bei A“, `status-B.md` „Anfragen an Teil A“ (gehen vor),
`abschlussbericht-A.md`. **A-V9 (status-B 19):** mit B8 lassen `shopping_mode_screen.dart` und
`list_detail_screen.dart` ihren Erfolgsmoment nach `openCheckoutFlow == true` weg, im selben Push wie B. Danach die
neuen B-Screens (B6b, B7, B8) wie in S6 gegenprüfen (Matrix, `bash tool/design_check.sh B`, keine Sheets/Slider,
Simulator nach Absprache, vorher fragen, ob der Owner angemeldet ist), Funde an B in `s5b-stand.md` „Von Teil B“ und
per Nachricht. Dann den Abschlussbericht nachführen. Zeit übrig: Reste aus „Offen bei A“ im Abschlussbericht
(`ListCard` ab AX1 ohne Cover, Galerie und gestrichelter Kreis im Simulator ansehen).

### A9b Pro, Rest

Quellen: `a9-stand.md` „Offen bei A“ und „Von Teil B“ (was B schon umgesetzt hat, in `status-B.md` nachsehen),
Konzept 18 §8.2, §8.7, §9.3, §11.11. Inhalt: Zoom-Übergang der Paywall aus dem auslösenden Element (`springMorph`,
Reduce Motion: Überblendung), kontextueller Pro-Hinweis auf der Startseite nach dem ersten Einkauf (`ProHintCounter`,
höchstens einer pro Tag, „Nicht mehr zeigen“), Preis-Cache für die erste Öffnung, Paywall-Screenshots im Simulator
hell/dunkel/AX3 (nach Absprache mit B, vorher Platte prüfen). Erinnerung an Tag 12 nur, wenn eine lokale Mitteilung
dafür ohne B-Dateien geht; sonst als Wunsch an B.

### A12 Aufräumen und Analysen

Quellen: prompt §5 A12, „Aufräumen“ und „Offen bei A“ in `a7-stand.md`, `a8-stand.md`, `ab1-stand.md`,
`ab2-stand.md` (alte Texte, ungenutzte Services, Paper-Reste in A-Dateien, `@Deprecated`-Aliase wie
`unsentChangesProvider`, sobald B nichts mehr davon nutzt). Vorher `status-B.md` auf neue Anfragen an A prüfen; die
gehen vor.

## Arbeitsweise (erprobt in A5–A8)

- **Ein gemeinsamer Ordner mit B** (`~/Apps/shoply-neu`, Zweig `main`). B arbeitet meist in eigenen Worktrees unter
  `~/Apps/shoply-neu-wt/`. Nie `git add -A`, `stash`, `checkout`, `switch`, `reset`, `restore`, `clean`. Committen:
  `git add <eigene Pfade> && git commit -m "…" -- <eigene Pfade>`, dann `git fetch -q origin && git merge --ff-only
  origin/main && git push origin HEAD:main`. Pushen auf `main` ist erlaubt (TestFlight läuft nur von Hand). Kleine
  Commits, Betreff ein deutscher Aussagesatz ohne Umlaute, keine Claude-Zeilen.
- **Paket mit Agenten:** zuerst `aN-auftrag.md` (Regeln, Dateien je Teil, Schnittstellen, Berichtsformat) und die
  gemeinsamen Schnittstellen selbst bauen und committen (Platzhalter-Klassen mit festen Konstruktoren, Routen,
  Textdateien je Teil `translations/<bereich>_<teil>.dart` in `app_translations.dart` registriert). Dann 2–3 Agenten
  (`general-purpose`, Hintergrund) mit kurzem Auftrag „lies aN-auftrag.md, dein Teil ist …“. Agenten committen nie.
- **Prüfen vor dem Commit:** saubere Kopie von `origin/main` als Worktree im Scratchpad, alle geänderten Dateien
  hineinkopieren (Schleifenvariable nie `path` nennen, in zsh ist das `PATH`), `lib/core/config/env.dart` und
  `lib/firebase_options.dart` mitkopieren, `flutter pub get`, `dart analyze lib test` (0 Errors, 0 Warnings),
  `flutter test --no-pub --concurrency=2` im Hintergrund (~25 min), Worktree danach entfernen. Immer `set -o
  pipefail` vor `flutter test … | tail && git commit`.
- **Tests der Agenten:** nur dateiweise, vorher `pgrep -x flutter_tester | wc -l`; bei 2 oder mehr warten. Verwaiste
  `flutter_tester` (PPID 1, 0 % CPU) gehören meist dem Worktree, aus dem sie kamen; nicht fremde beenden.
- **`dart format` nur auf eigene Dateien**, nie auf Ordner mit fremden Dateien (sonst eigene Formatierung in fremden
  Dateien wieder mit `git show HEAD:<pfad> > <pfad>` zurücksetzen).
- **Simulator:** iPhone 17 (`15046FA6-89B7-4FB2-9A8C-C4BF2F03C3A4`). Vorher mit B absprechen, wer baut; vor dem Build
  `df -h /System/Volumes/Data` (unter 10 GB keine Builds). `flutter build ios --simulator --debug --no-codesign`,
  App mit dem Simulator-Tool starten (Koordinaten in Punkten, 402 × 874), Debug-Build braucht ~10 s bis zum ersten
  Bild. `build/` danach löschen. Abmelden nur mit Ja des Owners; er meldet sich selbst wieder an.
- **Mit B reden:** B's Sitzung über `ListAgents` finden und per `SendMessage` schreiben; Wünsche an B zusätzlich in
  `aN-stand.md` „Von Teil B“, B trägt Erledigtes in `status-B.md` ein. B's Dateien nie ändern (`owner.sh`).
- **Server:** keine Migrationen, kein SQL auf der Datenbank, keine Edge Functions; nur Entwürfe in
  `aN-server-entwurf.sql`.

## Offen beim Owner (gesammelt)

- Pro-Sicherheit vor dem Start: Belegprüfung und `activate_subscription` absichern (`a9-stand.md`), Testphase in App
  Store Connect einheitlich, Paywall-Foto.
- Routine `claude/daily` pausieren (Owner-Entscheidung 09.11.2026, A12).
- Ideen aus `feature-ideen.md` §5.
- Server-Entwürfe freigeben: `a7-server-entwurf.sql` (Onboarding-RPC, Backfill; sonst `kOnboardingRedesignCutoff` auf
  den Release-Tag), `a8-server-entwurf.sql` (Konto löschen, Mitteilungen im Konto, `share_presence`, Profilfotos).
- Domain für Rechtstexte (F18-06), Daten exportieren (F18-07), KI-Einwilligung im Onboarding (F-17-03, F-17-12),
  Maskottchen (F-17-11).
