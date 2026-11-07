# Status Teil B (Jannis, Mac 2): KI, Daten, Module und System

Aufbau laut [`arbeitsteilung.md`](arbeitsteilung.md) Abschnitt 5. Teil B schreibt nur diese Datei.

## Stand

2026-11-07: Plan steht in [`docs/superpowers/plans/2026-11-07-teil-b.md`](../superpowers/plans/2026-11-07-teil-b.md).
Jetzt läuft P0 (die Anfragen 2–4 von A: Slot-Stubs, Kalorien-Alias, Kill-Switch-Provider), parallel P1: Edge Function
`ai` mit Quoten, Claude-Client, Kategorisierung lokal zuerst, Angebots-Logik (Region ohne 10115, Ersparnis-Funktion,
Markt pro Liste), App-Start. Sichtbare Screens erst ab S2.

## Meilensteine

| Meilenstein | Stand | Datum | Commit |
|---|---|---|---|
| S0 Aufräumen gemergt (A) | erledigt (laut status-A) | 07.11.2026 | `950921d` |
| S1 Struktur (A) | erledigt (laut status-A) | 07.11.2026 | `ab83f21`…`6112576` |
| S2 Fundament (A) | wartet | | |
| S3 Claude live (B) | in Arbeit | | |
| S4 Angebote abgesichert (B) | in Arbeit: Ersatz-Keys raus und Hänger in der Angebotssuche behoben | 07.11.2026 | `8de8a40` |
| S5 Bereiche fertig (B) | offen | | |
| S6 Gegenprüfung (B prüft A) | offen | | |

## Anfragen an Teil A

1. **Paywall ohne Angebote.** `lib/presentation/screens/subscription/subscription_screen.dart:180-185` und der Schlüssel
   `premium_feat_deals` (DE/EN) versprechen Angebote als Pro. Angebote sind nie Pro (Plan 8). Bitte streichen.
2. **`showAppBottomSheet` noch nicht löschen.** Elf B-Dateien nutzen es heute. Ich baue sie in P2 auf Vollbild um und
   melde, wenn keine B-Datei es mehr braucht.
3. **Ordner für B-Systemseiten.** `/settings/siri` und `/settings/widgets` brauchen einen B-Ordner. Vorschlag in
   `owner.sh`: `lib/presentation/screens/system/*` → B. Dazu `evals/*` → B (promptfoo-Evals für die KI).
4. **Vorwarnung Kategorisierung (kommt mit B1.5):** `item_repository.dart:106-125,167-178` wartet heute vor dem Insert
   auf die KI. Sobald `AiCategorizationService.categorizeLocal` (synchron) und `refineCategory` (Hintergrund) da sind,
   bitte darauf umstellen. Die alten Methoden bleiben bis dahin unverändert nutzbar.
5. **Vorwarnung Start (B3):** Für das Startbudget (≤ 150 ms vor `runApp`) brauche ich später zwei Dinge aus A-Dateien:
   den Remount-Key `app.dart:188` entfernen und den Router-Redirect synchron machen (`app_router.dart:405`).
   Genauer Wortlaut folgt mit dem B3-Messergebnis.

## Erledigte Anfragen von Teil A

1. **`claude/daily` pausieren:** In Jannis' Account gibt es diese Routine nicht. Geprüft am 07.11.: 4 Cloud-Routinen
   (Jarvis Welt, Jarvis Morgen, zwei deaktivierte), 2 lokale geplante Aufgaben (Website-Update, Postfach), keine mit
   Shoply-Bezug. `origin/claude/daily` steht auf `5bd4abf` (main von heute) ohne eigene Commits. Es gibt nichts zu
   pausieren; falls sie woanders läuft (GitHub-Actions-Schedule gibt es nicht), bitte Bescheid geben.
2. Slot-Stubs (Anfrage 2): in Arbeit (P0.3).
3. Kalorien-Alias (Anfrage 3): in Arbeit (P0.2).
4. Kill-Switch-Provider (Anfrage 4): in Arbeit (P0.1), Name `offersRemoteEnabledProvider` wie gewünscht, dazu
   `offersAvailableProvider` (Modul an **und** Kill-Switch an).
5. Home-Hinweise (Anfrage 5): verstanden, ich baue keine neue Home-Karte fest ein und warte auf den A4-Vorschlag.

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
- Kontakt-E-Mail für den Open-Food-Facts-User-Agent (`Avo/<version> (<E-Mail>)`).
- Berechtigungstexte (Mikrofon, Spracherkennung, Kamera, Health) und HealthKit-Capability im Developer-Portal.
- Welche B-Funktionen Pro werden (Angebote nie). Kommt mit der A9-Analyse.
- Partneranfrage verschicken (Entwurf folgt in `docs/redesign/angebote-partneranfrage.md`); Supermarkt-Logos nur mit
  Erlaubnis.
- Illustrationen für Artikelbilder erzeugen (Bild-Prompts folgen in `docs/redesign/artikelbilder-prompts.md`).
- Wann der alte Gemini-Key widerrufen wird (alte Builds rufen ihn noch auf).
