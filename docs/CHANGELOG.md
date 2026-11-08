# Changelog

Größere Änderungen am Repo, neueste oben. Kleine Fixes stehen nur in der Git-Historie.

## 2026-11-08: Avo-Tab im D2-Design (Teil B, B5 W1)

- Neuer Avo-Tab (`lib/presentation/screens/avo/`) nach `docs/redesign/b-screens/avo.md` §1–§6: großer Titel mit
  Avo-Figur, Nutzer-Blase, Avo-Text Wort für Wort, Arbeits-Zeile mit Stopp, eine Ergebniskarte pro Antwort,
  Auswahlkarte „Auf welche Liste?“, Rückfrage-Karte Löschen, Pro- und Modul-Zeile, Kontext-Kapsel, Folge-Chips,
  leerer Chat mit Vorschlägen nach Herkunfts-Screen, alle Fehlerzustände (offline, Limit, Kill-Switch, Anmeldung).
- Antwortkarten für Listen und Artikel mit „Widerrufen“ (hinzufügen, abhaken, ändern, verschieben, anlegen,
  umbenennen); `?prompt=` füllt das Feld nur vor.
- Alte Chat-Dateien unter `screens/ai/` und ihre Texte (`chip_*`, `how_can_i_help` …) entfernt.

## 2026-11-08: Angebote an Artikeln und Markt pro Liste (Teil B, W2)

Die Angebots-Slots, die Teil A in Liste, Artikel, Einkaufsmodus und Listen-Übersicht setzt, zeigen jetzt echte
Inhalte im D2-Stil (`docs/redesign/b-screens/angebote.md` S1–S8): Markt-Chip mit Menü, Vollbild „Markt wählen“
(`/stores/pick`), grüne Angebots-Pille, Angebotskarte im Artikel, Vollbild „Angebot“ (`/offers/offer/:offerId`)
statt Bottom-Sheet, Angebote beim Tippen, Ersparnis-Zeile im Pflicht-Wortlaut und „2 Angebote“ auf der Listenkarte.
Ohne echte Region, bei Modul aus, Kill-Switch oder ausgeblendeter Liste erscheint nichts und es geht keine Anfrage
raus. Die Einzel-Schalter und „Diese Woche ausblenden“ liegen vorerst nur auf dem Gerät.

## 2026-11-07: Großes Aufräumen

Ausgangslage: 292 Dart-Dateien, ~86.000 Zeilen, 59 Analyzer-Warnungen, App langsam und fehleranfällig.
Neun parallele Prüfer fanden 300 Probleme, ein zweiter Durchgang verwarf 10 davon als falsch.
Neun Fixer haben die Funde in getrennten Branches behoben, danach wurde alles zusammengeführt.

**Ergebnis:** 259 Dateien, ~64.000 Zeilen, `dart analyze` 0 Fehler / 0 Warnungen (59 Infos statt 541),
168 Tests grün, Simulator-Build grün.

**Schneller**
- Home lädt alle Listen in **einer** Abfrage statt 1+1+N. Realtime ist entprellt und hört nur noch auf das Nötige.
- Abhaken, Bearbeiten und Löschen sind sofort sichtbar (optimistisch). Pushes an Mitglieder blockieren nicht mehr.
- Artikel hinzufügen wartet nicht mehr auf zwei Gemini-Aufrufe, wenn keine Mengenangabe im Text steht.
- Rezepte-Tab lädt die Rezepttabelle einmal statt 3–4× und nicht mehr bei jedem Tastendruck.
- Router-Redirect ohne Netzwerkabfrage. App-Start initialisiert Dienste parallel.
- Keine nativen Glas-Views mehr in Scroll-Listen. Offscreen-Tabs werden nicht mehr gezeichnet.
- Eine dauerhaft laufende Animation an der App-Wurzel entfernt.

**Bugs (Auswahl von ~100)**
- Snackbars (Fehler- und Erfolgsmeldungen) warfen auf iOS eine Exception, weil der `ScaffoldMessenger` fehlte.
- Siri-/Deep-Links beim Kaltstart wurden doppelt ausgeführt, also Artikel doppelt hinzugefügt.
- Öffnen einer Liste löschte alle geplanten Erinnerungen.
- Abo-Bildschirm drehte nach abgebrochenem Kauf endlos.
- Deutsche Kommazahlen ("1,5") wurden in Kalorien-Feldern verworfen.
- Rezept bearbeiten löschte die Beschreibung, Zutaten wurden beim Hinzufügen doppelt skaliert.
- Diät-Warnungen griffen nie. Eine fehlerhafte DB-Zeile leerte den ganzen Rezept-Feed.
- Account-Daten (Listen, gespeicherte Rezepte, Cache) blieben nach dem Abmelden für den nächsten Nutzer sichtbar.
- Avo-Chat behielt den Verlauf über Account-Wechsel, Avo-Benachrichtigungen waren immer englisch.

**Aufgeräumt**
- ~10.000 Zeilen toter Code gelöscht (alte Screens, `*_old.dart`, Tutorial-Ketten, Achievements, KI-Labeling,
  ungenutzte Widgets und Provider), außerdem ~29 MB ungenutzte Assets und 13 ungenutzte Pakete.
- Riesendateien aufgeteilt: `list_detail_screen.dart` 3.457 → ~770 Zeilen, `recipes_screen.dart` 1.566 → ~450,
  Avo-Service in Prompt, Tool-Deklarationen und Modelle zerlegt.
- `print` → `debugPrint`, harte deutsche Texte in Übersetzungen verschoben, `scripts/` (zeigte auf alten Checkout)
  entfernt, `linux/` und `windows/` entfernt.
- CI: neue Prüfung bei jedem Push (`check.yml`), TestFlight-Workflow auf API-Key-Signierung umgebaut.
- Doku neu: README, `docs/ARCHITECTURE.md`, `docs/OPEN-ISSUES.md`, `docs/DESIGN-STATUS.md`. Die veraltete
  `FEATURE_IMPLEMENTATION_STATUS.md` (6.584 Zeilen) liegt in `docs/archive/`.

Offen: siehe [OPEN-ISSUES.md](OPEN-ISSUES.md).
