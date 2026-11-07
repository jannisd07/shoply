# Design-Quelle: D2 · Glas (verbindlich)

**Das Design der App ist das Artifact „Shoply Redesign – 5 Richtungen“, Seite „D2 · Glas“:**
https://claude.ai/artifact/FKDP5yDZnBeGzfn6HH19dU

Lies es mit dem Artifact-Tool (`action: "read"`, URL oben; einzelne Screens mit `path`, z. B. `project/D2-Komponenten.dc.html`). Beide Macs nutzen denselben Claude-Account und haben deshalb Zugriff.

## Was gilt wofür

| Thema | Quelle |
|---|---|
| Aussehen: Farben, Glas, Schrift, Abstände, Radien, Komponenten, Tab-Bar, Bildsprache | **D2-Artifact** (vor allem `D2-Komponenten`) |
| Screens mit festem Aussehen | die D2-Artboards (Tabelle unten) |
| Funktionen, Abläufe, Zustände (leer, lädt, Fehler, offline, Modul aus, Pro), Barrierefreiheit, Texte | `docs/redesign/konzept/` (Kapitel 10 bis 20) |
| Entscheidungen bei Widersprüchen | Jannis' Plan, dann dieses Dokument, dann das Konzept |

Die Konzept-Dateien in `docs/redesign/konzept/` wurden für eine andere Design-Richtung („Vorinstalliert“) geschrieben. **Ihre optischen Angaben gelten nicht:** Hex-Werte, Tokens, Tab-Struktur, Avo-Kreis, Komponentenaussehen. **Ihre inhaltlichen Angaben gelten weiter:** Funktionen, Abläufe, Zustände, Barrierefreiheit, Texte. Bei jedem Widerspruch gewinnt D2.

## Feste Owner-Regeln (aus `docs/DESIGN-STATUS.md`, gelten immer)

- **Keine Slider:**
  - keine Bottom-Sheets, keine halbhohen Modals, keine Drawer, keine Schieberegler
  - Bearbeiten und Eintragen ist immer ein eigener Vollbild-Screen mit Zurück- oder Schließen-Knopf
  - erlaubt bleiben zentrierte Bestätigungsdialoge und Kontext- bzw. Pull-down-Menüs
  - Die Konzept-Kapitel sprechen an manchen Stellen von Sheets: Dort wird stattdessen ein Vollbild-Screen gebaut.
- **Avo** ist immer die echte 3D-Figur aus `assets/avo/`, mit Pose nach Anlass. Höchstens eine Avo-Figur pro Bildschirmhöhe. Das Avo-Tab-Icon (Funkeln) ist die Ausnahme.
- **Kein Profil-Avatar in der Kopfzeile, kein separater Avo-Knopf:** Profil und Avo sind Tabs.
- `docs/DESIGN-STATUS.md` beschreibt außerdem, warum das Theme auf iOS heute nicht greift (`CupertinoApp`). Teil A muss das beim Token-Set lösen.

## D2 in Kürze (aus den Artboards gelesen)

- **Hintergrund** #F2F2F7 (Rezepte: #FFFFFF); **Text** #1C1C1E, sekundär #6C6C70, #3A3A3C; Trennlinien #E5E5EA.
- **Akzent** #1F7A3A (Grün), Hover #165C2B, helle Fläche #E7F3EA (Angebots-Pille: grüne Schrift auf #E7F3EA).
- **Glas** (`.glass`): weiß 64 % mit Blur 22 px, feine helle Kante, weicher Schatten. Getöntes Glas (`.glass-tint`): Grün 88 % für die Hauptaktion.
- **Flächen:** weiße Gruppen mit 26 px Radius, Karten und Bilder 20 px, Artikelbilder 10–14 px.
- **Typografie:** SF Pro, großer Titel 34/41 Bold, Abschnittstitel 20/25 Semibold, Fließtext 17/22, Meta 15/20 und 13/18. Kategorie-Überschriften in Listen in Großbuchstaben 13/18 Semibold, grau.
- **Tab-Bar:** schwebende Glas-Kapsel mit 5 Tabs: **Home, Listen, Avo, Rezepte, Profil**. Der aktive Tab bekommt einen grünen Lichtschein. Avo ist ein eigener Tab, damit erfüllt D2 „Avo hat genau einen Einstieg“.
- **Hinzufügen:** Glas-Feld „Artikel hinzufügen“ über der Tab-Bar, mit grünem Plus, Diktat-Knopf und Summe.
- **Echte Fotos** für Artikel und Rezepte, Maskottchen-Bilder „Avo winkt“ und „Avo überlegt“.

## Wo die Module in D2 sitzen

- **Wochenplan:** im Tab Rezepte als zweites Segment („Entdecken | Wochenplan“), siehe `X-Wochenplan`.
- **Kalorien:** Karte auf Home („Für dich“), Vollbild-Screens per Push; „Essen eintragen“ siehe `X-Essen`.
- **Angebote:** an Artikeln, in der Liste, auf Home; Einstellungen siehe `X-Angebote`.
- **Kosten teilen:** auf Home und in der Liste.
- **Module an und aus:** im Profil (`X-Profil`) und im Onboarding (`X-Onboarding`).
- Ist ein Modul aus, verschwinden seine Karten, Segmente und Einstellungen.

## Artboards

| Artboard | Inhalt | Konzept-Kapitel (Funktion) |
|---|---|---|
| `D2-FuerDich` | Home, ganze Seite | 10 |
| `D2-Home` | Listen-Übersicht | 11 |
| `D2-Liste` | Liste Wocheneinkauf | 11 |
| `D2-Artikel` | Artikel bearbeiten (Vollbild) | 11 |
| `D2-Rezepte` | Rezepte | 13 |
| `D2-Komponenten` | **alle Bausteine, Referenz für das Designsystem** | 00 |
| `D2-Widgets` | Widgets Start- und Sperrbildschirm | 19 |
| `X-Einkaufsmodus` | Einkaufsmodus: Markt pro Liste, nur dessen Angebote, „4 von 11 im Angebot … in deiner Region“, Präsenz, große Häkchen nach Gang, Bildschirm bleibt an | 11, 12 |
| `X-Avo` | Avo-Tab: Chat mit Antwortkarte, Rückgängig, Sprachmodus-Knopf | 16 |
| `X-AvoSprache` | Avo-Sprachmodus | 16 |
| `X-Wochenplan` | Wochenplan im Rezepte-Tab | 14 |
| `X-Essen` | Essen eintragen per Foto, Barcode, Suche, mit Apple Health | 15 |
| `X-Profil` | Profil mit Modul-Schaltern und Einstellungen | 18 |
| `X-Angebote` | Einstellungen „Preise & Angebote“ | 12 |
| `X-Onboarding` | Onboarding: Module wählen | 17 |
| `X-Pro` | Paywall „Avo Pro“ (Umfang nur als Beispiel) | 18 |

Die `X-…`-Screens hat Claude am 07.11.2026 im D2-Stil ergänzt. Sie zeigen die Funktionen aus Jannis' Plan und der Verbesserungsliste, die in D2 noch fehlten. Die übrigen Seiten (A bis E) sind verworfene Richtungen.

**Fehlt ein Screen im Artifact,** wird er aus den D2-Bausteinen (`D2-Komponenten`) und dem passenden Konzept-Kapitel gebaut.
