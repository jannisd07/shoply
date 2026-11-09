# Teil A: eine Sitzung je Arbeitspaket

Stand 09.11.2026 (AB1 erledigt). Owner-Entscheidung 09.11.2026 (Wochenlimit): **jede Claude-Sitzung bearbeitet genau ein Paket** und
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
| **AB2 Anfragen von B: Listen, Router, Reste aus A5–A8** | **Als Nächstes** | unten |
| A9 Pro und Paywall | wartet auf den Owner (Free/Pro: Varianten A/B/C in `pro-konzept.md`) | prompt §5 A9, Konzept 18 Kap. 8–9 |
| A10 App-Icon und Maskottchen | wartet auf den Owner (Maskottchen F-17-11) | prompt §5 A10 |
| A12 Aufräumen und Analysen | offen | prompt §5 A12, „Aufräumen“ in a5–a8-stand |
| A11 Qualität für alle A-Screens | offen (braucht Builds, Platte prüfen) | prompt §5 A11 |
| S6 Gegenprüfung von B | offen | prompt §5 A11 „Gegenprüfung“ |
| S5 Bereiche fertig | offen | prompt §11 |

Reihenfolge: AB2, dann A9 oder A10, sobald der Owner entschieden hat, sonst A12, A11, S6, S5. Fragt die Sitzung den
Owner zu Beginn nach A9/A10, nur wenn eins davon „Als Nächstes“ ist.

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

Zuerst `status-B.md` „Anfragen an Teil A“ auf Neues seit AB1 prüfen und `ab1-stand.md` „Offen bei A“ lesen (die
neuen Komponenten dort beim Listen-Umbau nutzen, z. B. `ItemRow(trailingSemanticsLabel:, contextMenuItems:)`).

A-C4 (Accessory: B-Block, Fokus zurück), A-L1–A-L4 (Listenkopf mit `StoreChip`, Listen-Info „Markt“ und „Angebote
anzeigen“, Listenkarte, „Neue Liste“ mit Markt, „Liste von heute“), A-R1–A-R3 (Angebots-Routen vor der Shell,
Modul-Wächter, Deep Links), dazu „Offen bei A“ aus `a5-stand.md` bis `a8-stand.md` (Listen-Schalter verdrahten,
Mitteilungs-Kategorien durchsetzen, `recipeAutoAdaptProvider`, `ThemeMode.system`, T6 im Rezepte-Tab,
Startvorschläge im Accessory).

**Abstimmen mit B (Stand 09.11.2026):** B's Zweig `feature/b-settings-a8` (auf origin, nicht auf `main`) ersetzt in
A's `settings_search_index.dart` und dessen Test `bSettingsPagesSearchEntries` durch B's eigene Suchliste. Die nächste
B-Sitzung klärt das vor dem Merge; die A-Sitzung prüft den Diff (`git diff main...origin/feature/b-settings-a8 --
lib/presentation/screens/profile test/screens/profile`) und gibt das OK oder bessert nach. B's Übergabe:
`b-sitzungen.md`.

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

- Free gegen Pro (A9): `pro-konzept.md`.
- Server-Entwürfe freigeben: `a7-server-entwurf.sql` (Onboarding-RPC, Backfill; sonst `kOnboardingRedesignCutoff` auf
  den Release-Tag), `a8-server-entwurf.sql` (Konto löschen, Mitteilungen im Konto, `share_presence`, Profilfotos).
- Domain für Rechtstexte (F18-06), Daten exportieren (F18-07), KI-Einwilligung im Onboarding (F-17-03, F-17-12),
  Maskottchen (F-17-11).
