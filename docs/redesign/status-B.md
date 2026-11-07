# Status Teil B (Jannis, Mac 2): KI, Daten, Module und System

Aufbau laut [`arbeitsteilung.md`](arbeitsteilung.md) Abschnitt 5. Teil B schreibt nur diese Datei.

## Stand

2026-11-07, 23:50: Zwei Workflows laufen (P0/P1 mit 14 Paketen; parallel nativer Unterbau, Kalorien- und
Wochenplan-Logik, Evals, Avo-Tool-Abdeckung, Screen-Specs). Plan steht in [`docs/superpowers/plans/2026-11-07-teil-b.md`](../superpowers/plans/2026-11-07-teil-b.md).
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
11. **Prio 4 – `ShoppingItemModel.barcode` (optional, nullable)**, damit `ArticleImage` ein Open-Food-Facts-Foto nur bei
    echtem Barcode zeigt.
12. **Vorwarnung:** `ListPriceSummaryBar` und die Ein-Argument-Form von `OfferSuggestionsBar(query:, onSelect:)` bleiben
    als Übergang. Bitte beim Listen-Umbau `ListOfferSummary(listId:)` und `OfferSuggestionsBar(listId:, query:)` nutzen,
    dann lösche ich die Übergänge.

Erledigt von A: 1 Paywall ohne Angebote (`10f30c6`), 3 Ordner `screens/system` und `evals` für B (`4d5e8fc`),
5 kein App-Remount (`91ecbc8`). Offen: 2 (`showAppBottomSheet` noch behalten), 4 (Kategorisierung umstellen, sobald
`categorizeLocal` gepusht ist). Danke auch für `addItems`/`undoAddItems` und `parseItemInput`: Der Wochenplan und Avo
nutzen beide direkt.

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
