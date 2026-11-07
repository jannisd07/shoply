---
name: idiotensicher-testen
description: >
  Use when a website, web app, form, upload, booking, chat or customer-facing flow should be checked for being
  idiot-proof / foolproof ("idiotensicher", "jeder Edge Case", "versteht das ein Kunde", "läuft das flüssig"),
  before a launch or handover, or when customers get stuck, abort, submit wrong data or ask what to do.
---

# Idiotensicher testen

Mehrere Agenten mit verschiedenen Modellen prüfen ein System aus drei Richtungen: **Ahnungslose** probieren es blind
aus, **Brecher** gehen die Checkliste durch, **Prüfer** reproduzieren jeden Befund unabhängig. Idiotensicher heißt:
kein Befund P0/P1, jede Kernkategorie getestet, der Laie erreicht das Ziel ohne Hilfe.

**Grundregel:** Wer die Verständlichkeit beurteilt, darf den Code nicht kennen. Ein Agent, der den Code gelesen hat,
weiß, was gemeint ist, und kann nicht mehr ahnungslos sein.

## Ablauf

1. **Rahmen klären (Hauptsitzung, ohne Rückfrage, wenn ableitbar):** Ziel des Kunden in seinen Worten („Termin
   buchen“), Einstiegs-URL, Teststufe (Standard: Normal), Umgebung. Laufordner anlegen:
   `<scratchpad>/idiotensicher-<system>-<JJJJ-MM-TT>/`.
2. **Umgebung, in dieser Reihenfolge:** lokal (`localhost`) > eigene Testumgebung > Live nur ansehen. Vorher
   prüfen, ob eine „Testseite“ wirklich getrennt ist (eigene App, eigene Datenbank): Yandos
   `ki.dietrichserver.tech` läuft auf derselben App wie yando-ki.de und zählt also wie Live. Yando lokal: Dienst
   `ki-website` aus `.claude/launch.json` (Port 4321), E-Rechnung-Check dazu `werkzeug/erechnung-pruefer.sh` und
   `ERECHNUNG_PRUEFER_URL` in `.dev.vars`. Live wird nichts abgeschickt, was speichert, zählt, bucht oder Mails auslöst (Absenden per
   `fetch`-Abfangen simulieren). Nur ausgedachte Testdaten. Rate-Limit- und Massentests nie gegen Live.
3. **Kundendateien und Bilder vorbereiten:** Der Playwright-MCP lädt und speichert nur in seinem erlaubten Ordner
   (bei Yando `~/.cache/playwright-mcp-yando/`), also Testdateien und Screenshots dorthin. Dateien so benennen und
   mischen, wie ein Kunde sie hat, **inklusive des typischen Fehlgriffs** (normales PDF statt E-Rechnung, Foto statt
   Scan, Word statt PDF).
4. **Welle 1 parallel:** Kartograf; Erster-Eindruck braucht nur Screenshots (die Hauptsitzung macht sie vorher mit
   Playwright: Startseite, jeder Schritt, Handy 375 px).
5. **Welle 2:** Browser-Agenten **nacheinander** (ein Playwright-Browser, sonst kommen sich die Tabs in die Quere),
   Code- und API-Agenten parallel dazu. Jeder bekommt seinen Steckbrief aus [rollen.md](rollen.md) wörtlich, dazu
   seine Kategorien aus [checkliste.md](checkliste.md). Personas bekommen **nur** URL, Ziel und Persona, keine
   Karte, keinen Code, keinen Repo-Pfad.
6. **Welle 3, Prüfen:** Jeder Befund geht an einen Prüfer mit **anderem Modell** als der Finder. Nicht
   reproduziert = „unbestätigt“, nicht in die Befundliste.
7. **Bericht** nach [bericht.md](bericht.md): Urteil, Befunde, Abdeckungsmatrix, Denkaufwand. Datei ins Repo in den
   Doku-Ordner des geprüften Systems (sonst `pruefungen/` daneben) als `idiotensicher-JJJJ-MM-TT.md`, pushen.
8. **Nur wenn der Auftrag „reparieren“ enthält:** je Befund erst ein Test, der scheitert (vorhandene `*:testen`
   oder Playwright), dann der Fix, dann prüft ein **frischer** Agent derselben Rolle nach. Bis keine P0/P1 übrig.

## Teststufen

| Stufe | Rollen (Modell) | Agenten | Wann |
|---|---|---|---|
| Schnell | Kartograf (haiku), Laie (haiku), Erster Eindruck (haiku), Prüfer (sonnet) | 4 | kleine Änderung, ein Formular |
| **Normal** | Schnell + Eingabe-Brecher, Ablauf-Brecher, Gerät & Barrierefreiheit, Laien-Angreifer (je sonnet); Prüfer (opus) | 8 | Standard, vor Livegang |
| Gründlich | Normal + Persona Senior (haiku), Persona Handy im Zug (haiku), Richter (fable oder opus), Regressionstests | 11 | Kundenübergabe, Bezahl- und Buchungsabläufe |

Haiku spielt Laien bewusst: billig und liest flüchtig. Prüfer und Richter laufen mit einem stärkeren Modell, das die
Befunde nicht selbst gefunden hat.

## Abgrenzung

- Tiefer Sicherheitsscan des Codes: `claude-security`. Hier gibt es nur den Laien-Angreifer im Browser.
- Reine Codeprüfung ohne Bedienung: `superpowers:requesting-code-review`.
- Texte umschreiben, die der Test als unklar meldet: `copy-editing` und `humanizer`.

## Häufige Fehler

| Fehler | Folge | Richtig |
|---|---|---|
| Persona liest erst den Code | beurteilt Verständlichkeit mit Insiderwissen | Persona bekommt nur URL und Ziel; hat sie Code gelesen, Ergebnis verwerfen und neu starten |
| Ein Agent macht alles | blinde Flecken einer Sicht, keine Gegenprobe | Rollen trennen, Prüfer mit anderem Modell |
| „Nicht getestet“ nur am Ende erwähnt | Lücken sehen aus wie ok | jede Checklistenzeile mit Status in der Matrix |
| Live-Formular wirklich abgeschickt | echte Buchung, Mail, Zählung | lokal oder Absenden abfangen |
| Mehrere Browser-Agenten gleichzeitig | Tabs vermischt, falsche Befunde | Browser-Agenten nacheinander |
| Alle Agenten teilen eine IP und eine Grenze je IP | Grenze greift mitten im Test, Zustände nicht mehr prüfbar | Budget je Agent im Kopf nennen; lokal die Zähler vor jeder Welle leeren (Yando: Tabelle `grenzen` im lokalen D1 unter `.wrangler/state/`) |
| Zögern nicht gezählt | „hat geklappt“, obwohl der Kunde dreimal suchte | jedes Zögern und jede unnötige Entscheidung ist ein Befund (P1/P2) |
