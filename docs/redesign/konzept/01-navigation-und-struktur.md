# 01 Navigation und Struktur

> **Gilt nur noch inhaltlich (Stand 07.11.2026, 22 Uhr):** Das Aussehen der App kommt aus dem D2-Glas-Artifact, siehe [`../design-quelle.md`](../design-quelle.md). Hex-Werte, Tokens, Tab-Struktur, Avo-Kreis und Komponentenaussehen in dieser Datei sind überholt. Funktionen, Abläufe, Zustände, Barrierefreiheits- und Textregeln gelten weiter.

Stand: 07.11.2026. Verbindlich für Teil A und Teil B. Baut auf `00-grundlagen.md` auf (Komponenten und Regeln dort, Verweise als "00 Kap. x"). Entscheidungen K-xx und offene Fragen F-xx stehen in 00 Kap. 18.

Inhalt: 1 Grundgerüst · 2 Tabs und die Liste von heute · 3 Der eine Avo-Einstieg · 4 Profil und Einstellungen · 5 Screen-Karte alt nach neu · 6 Navigationsmuster · 7 Routen · 8 Deep Links, Mitteilungen, Widgets, Siri · 9 Suche · 10 Abläufe

---

## 1. Grundgerüst

```
App
├─ Tab-Bar (00 Kap. 12.1)
│   ├─ Liste ........ Wurzel: die Liste von heute            (Kern, Teil A)
│   ├─ Rezepte ...... Wurzel: Entdecken                       (Kern, Teil A)
│   ├─ Plan ......... Wurzel: Wochenplan                      (Modul Wochenplan, Teil B)
│   ├─ Kalorien ..... Wurzel: Tagebuch heute                  (Modul Kalorien, Teil B)
│   └─ Avo-Kreis .... "Frag Avo" / Sprachmodus / Suche        (Modul Avo, Teil B; aus = Lupe)
├─ Profil-Avatar in jeder Tab-Wurzel → Sheet "Profil und Einstellungen" (Teil A, B-Seiten verlinkt)
├─ Vollbild-Cover: Einkaufsmodus, Kochmodus, Rezept-Editor, Kamera/Scanner, Onboarding
└─ Sheets: Avo, Paywall, Listen-Info, Teilen, Abschluss, Artikel, Zutaten auf Liste, Essen eintragen …
```

Jeder Screen beantwortet: Wo bin ich (großer Titel), wohin kann ich (Tabs, Toolbar, Zeilen mit Chevron), was ist hier (eine Hauptfrage, unten pro Screen genannt), wie komme ich raus (Zurück oben links bzw. Wischen vom Rand; Sheets nach unten wischen oder `xmark`; Cover über `xmark` bzw. `chevron.down` oben links).

---

## 2. Tabs und die Liste von heute

### 2.1 Tabs

| Pos. | Tab | Symbol | Route (Wurzel) | Sichtbar | Großer Titel | Hauptfrage der Wurzel |
|---|---|---|---|---|---|---|
| 1 | **Liste** | `checklist` | `/home` | immer | Name der Liste von heute, mit Umschalter | Was muss ich als Nächstes kaufen? |
| 2 | **Rezepte** | `fork.knife` | `/recipes` | immer | "Rezepte" | Was koche ich? |
| 3 | **Plan** | `calendar` | `/plan` | Modul Wochenplan | "Wochenplan" | Was essen wir diese Woche, und ist alles auf der Liste? |
| 4 | **Kalorien** | `flame` | `/calories` | Modul Kalorien | "Kalorien" (Unterzeile Datum) | Wie viel kann ich heute noch essen? |
| abgesetzt | **Avo-Kreis** | `avo.core` bzw. `magnifyingglass` | `/avo` (Sheet) | immer (Avo an: Avo; aus: Suche) | – | Was soll Avo für mich tun? |

Regeln:
- Ohne Module zwei Tabs plus Kreis, mit allen Modulen vier Tabs plus Kreis (K-02, K-03). Mehr Tabs gibt es nicht.
- Die Route `/home` bleibt der Name des Tabs Liste (Links, Analytics-Namen und Siri hängen daran).
- Tab-Wechsel sofort, ohne Animation; jeder Tab behält seinen Stapel und seine Scrollposition. Erneutes Tippen auf den aktiven Tab: zur Wurzel, dann nach oben.
- Wird ein Modul ausgeschaltet, während man auf seinem Tab steht, landet man auf Liste.
- Unter 350 pt Breite und ab AX1 nur Symbole (Large Content Viewer bei Langdruck).
- Angebote, Verlauf, Kosten teilen und "Alle Listen" sind **keine** Tabs. Sie liegen als Seiten unter der Liste (2.3).

### 2.2 Welche Liste ist "die Liste von heute"

1. **Beim Kaltstart:** die angeheftete Liste (Listenmenü "Beim Start zeigen"); sonst die zuletzt gewählte Liste (pro Gerät gespeichert); sonst die zuletzt geänderte; sonst der Zustand "Erste Liste" (2.4).
2. **Ausdrückliche Wahl wechselt sofort** (Überblendung): Titelmenü, "Alle Listen", Deep Link, Widget, Mitteilung, Siri, Avo ("Öffne die Lidl-Liste").
3. **Nie automatisch umschalten (K-28).** Signale werden zu einer Hinweis-Zeile (00 Kap. 12.12):
   - Standort in einem Markt, für den es eine Liste gibt: "Du bist bei Lidl. Lidl-Liste öffnen?"
   - Ein Mitglied kauft gerade ein: "Lena kauft gerade bei REWE ein · Wocheneinkauf öffnen"
   - Wochenplan-Zutaten liegen auf einer anderen Liste: "Zutaten für heute stehen auf Wocheneinkauf · Öffnen"
4. **Wird die Liste gelöscht oder verlassen,** gilt Regel 1 für die nächste.
5. **Mehrere aktive Listen** sind normal; das Titelmenü zeigt alle mit offener Anzahl, sortiert nach zuletzt geändert, angeheftete oben.

### 2.3 Unter dem Tab Liste

| Seite | Weg dorthin | Muster | Hauptfrage |
|---|---|---|---|
| **Alle Listen** (`/lists`) | Titelmenü > "Alle Listen" | Push | Welche Listen habe ich, und was ist erledigt? |
| Listen-Info (`/lists/:id/info`) | Toolbar `ellipsis` > "Listen-Info", Kontextmenü einer Liste | Sheet groß | Wie ist diese Liste eingerichtet, wer ist dabei? |
| Reihenfolge im Markt (`/lists/:id/order`) | Listen-Info | Push im Sheet | In welcher Reihenfolge gehe ich durch den Markt? |
| Liste teilen (`/lists/:id/share`) | Toolbar `person.crop.circle.badge.plus` | Sheet mittel | Wie bekommt jemand Zugriff? |
| Einkaufsmodus (`/lists/:id/shopping`) | "Einkaufen" im Accessory | Vollbild-Cover (Morph) | Was fehlt noch im Wagen? |
| Abschluss (Sheet, Teil B) | "Einkauf beenden" bzw. Listenmenü | Sheet mittel | Wo war ich, was kommt in den Verlauf? |
| Verlauf (`/history`) | Alle Listen > Verlauf | Push | Was habe ich eingekauft? |
| Angebote der Woche (`/offers`) | Alle Listen > Sparen; Ersparnis-Zeile; Hinweis-Zeile | Push | Was von meinen Sachen ist diese Woche im Angebot? |
| Offene Beträge (`/splits`) | Alle Listen > Offene Beträge; Hinweis-Zeile | Push | Wer schuldet wem? |

**Alle Listen** (gruppierte Sektionen, von oben):
1. Suchfeld (ab 7 Listen).
2. "Meine Listen" (`ListRow`s).
3. "Geteilt mit mir" (mit Avatar-Stapel).
4. "Sparen" (nur Modul Angebote): "Angebote der Woche" mit Zahl "12 passen zu deinen Listen".
5. "Verlauf": "Einkäufe" (Monat und Anzahl), "Offene Beträge" (nur Modul Kosten teilen, mit Summe).
6. Toolbar oben rechts: `plus` (Menü: "Neue Liste", "Liste beitreten").

### 2.4 Tab Liste ohne Liste

Großer Titel "Erste Liste", darunter ein leerer Zustand ohne Maskottchen-Pflicht: "Wie soll deine erste Liste heißen?" mit drei Vorschlags-Zeilen ("Wocheneinkauf", "Lidl", "Drogerie") und "Eigener Name". Tippen legt die Liste an (bei "Lidl" mit Markt-Chip Lidl) und fokussiert das Accessory.

---

## 3. Der eine Avo-Einstieg

**In der App gibt es genau einen Einstieg: den Avo-Kreis rechts neben der Tab-Bar (K-04).**

| Geste am Kreis | Ergebnis |
|---|---|
| Tippen | Der Kreis morpht zum Feld "Frag Avo oder suche" in der Tab-Bar, Tastatur offen (00 Kap. 12.1). Während man tippt, erscheinen Suchtreffer (Kapitel 9). Return schickt die Frage an Avo: Das Avo-Sheet steigt in mittlerer Höhe auf, der aktuelle Screen bleibt sichtbar. |
| `waveform` im Feld | Sprachmodus (Sheet groß, 00 Kap. 12.33) |
| `camera` im Feld | Foto an Avo (Essen eintragen, Zettel importieren, "Was kann ich daraus kochen?") |
| Halten | Sprachmodus direkt |

- **Kontext:** Avo kennt den Screen, von dem man kommt (Liste, Rezept, Kalorien-Tag, Wochenplan-Woche), und schlägt im leeren Zustand dazu passende Sätze vor.
- **Wo der Kreis sichtbar ist:** auf allen Tab-Wurzeln und Pushes in Tabs, im Einkaufsmodus und im Kochmodus an derselben Stelle. Nicht in Onboarding, Paywall, Rezept-Editor, Kamera und solange ein großes Sheet offen ist.
- **Das Avo-Sheet:** Kopf mit `xmark` links, "Avo" mittig, `ellipsis` rechts ("Neues Gespräch", "Avo-Einstellungen"); Gesprächsverlauf (00 Kap. 12.32); unten das Glas-Feld mit `camera` links und `waveform` rechts. Ziehen auf groß, Wischen nach unten schließt (die Antwort läuft weiter; der Kreis zeigt `denkt`, bis sie fertig ist).
- **Gespräch:** bleibt erhalten, bis man "Neues Gespräch" wählt oder 24 Stunden vergangen sind (Speicherung lokal, Teil B).
- **Außerhalb der App** (zählen nicht als zweiter Einstieg): Siri "Frag Avo", Kurzbefehl, Action Button, Widget "Avo fragen", Steuerelement im Kontrollzentrum. Sie öffnen dasselbe Sheet bzw. den Sprachmodus.
- **Verboten:** Avo-Streifen, Avo-Karten auf der Startseite, Avo-Knöpfe in Listen oder Rezepten, Avo-Werbung in Ergebnissen. Funktionen, die ohne Gespräch laufen (Zettel importieren, Kategorien, Nachkauf-Vorschläge, Rezept anpassen), heißen ohne Avo-Namen und sind normale Aktionen.
- **Modul Avo aus:** Der Kreis zeigt `magnifyingglass` und öffnet nur die Suche. Siri-Satz und Widget "Avo fragen" öffnen dann das Modul-Sheet ("Avo ist ausgeschaltet").
- **Avo kann alles in der App** mit Login und Rechten der Person; Löschen nur mit Rückfrage-Karte und Tipp (00 Kap. 12.32). Jede ausgeführte Änderung erscheint als Ergebniszeile mit "Widerrufen" und, wo sie sichtbar wird, ohne Avo-Hinweis.

---

## 4. Profil und Einstellungen

- **Ort:** runder Avatar (36 pt, kein Glas) rechts in der Titelzeile jeder Tab-Wurzel (K-05). Tippen öffnet das Sheet "Profil" (groß) mit Suchfeld oben.
- **Jede Seite hat eine Route** (`/settings/...`), damit Avo, Siri, Mitteilungen und Links sie öffnen können. `/profile` bleibt als Alias und öffnet das Sheet.

Aufbau des Sheets (Sektionen von oben):

| Sektion / Zeile | Route | Inhalt | Besitz |
|---|---|---|---|
| Kopf: Avatar, Name, E-Mail | `/settings/profile` | Name, Profilbild (Menü am Avatar: Fotos, Kamera, Entfernen mit Rückgängig) | A |
| {pro} | `/pro` | Status ("14 Tage gratis testen" / "Aktiv bis 7. Dez.") | A |
| **Module** | `/settings/modules` | Schalter je Modul mit einem Satz Nutzen (00 Kap. 15) | A |
| **Preise & Angebote** (bei Kill-Switch "Märkte") | `/settings/offers` | Einzel-Schalter (00 Kap. 15.4), Region/PLZ, Lieblingsmärkte, Markt-Erkennung | B |
| Kalorien & Gesundheit (Modul) | `/settings/health` | Ziele, Apple Health lesen/schreiben, Wasserziel, Einheiten | B |
| Wochenplan (Modul) | `/settings/plan` | Standard-Portionen, Ziel-Liste | B |
| Avo (Modul) | `/settings/avo` | Stimme, Sprachausgabe an/aus, Gespräch löschen | B |
| Ernährung & Allergien | `/settings/diet` (Alias `/diet-preferences`) | 12 Ernährungsweisen, **Allergien** (heute ohne Oberfläche), "Rezepte automatisch anpassen" | A |
| Persönliche Daten | `/settings/personal` | Alter, Größe, Geschlecht (für Kalorien); die PLZ wandert zu Preise & Angebote | A |
| Listen | `/settings/lists` | Artikelbilder anzeigen, Vorschläge "Vielleicht auch", Bildschirm im Einkaufsmodus anlassen | A |
| Mitteilungen | `/settings/notifications` | Status der iOS-Erlaubnis mit Link in die Einstellungen, Kategorien, Uhrzeiten der Erinnerungen | A (Dienste B) |
| Darstellung | `/settings/appearance` | System / Hell / Dunkel; Akzentfarbe fest (K-06) | A |
| Sprache | `/settings/language` | System / Deutsch / English | A |
| Siri & Kurzbefehle | `/settings/siri` | verfügbare Sätze, Hinweis auf die Kurzbefehle-App | B |
| Widgets | `/settings/widgets` | Vorschau der Widget-Arten, Anleitung | B |
| Hilfe | `/settings/help` | Fragen, Kontakt, Fehler melden, App bewerten, Tipps zurücksetzen | A |
| Rechtliches | `/settings/legal` | Datenschutz, Impressum, Nutzungsbedingungen, Datenquellen (Open Food Facts, Open Prices, OpenStreetMap, Angebotsquelle) | A |
| Konto | `/settings/account` | Abmelden (rot), **Konto löschen** (App-Store-Pflicht, heute fehlend, mit Bestätigung) | A |
| Fuß | – | Version | A |

Jede Seite ist zusätzlich über die Suche im Sheet und über Avo erreichbar (Kapitel 9).

---

## 5. Screen-Karte alt nach neu

Jeder heutige Screen, jedes Sheet und jeder Dialog aus `konzept/inventar/` hat einen neuen Ort oder entfällt mit Grund. Spalte "Kap." = Konzept-Kapitel, das ihn gestaltet.

### 5.1 Shell (`inventar/shell.md`, `perf.md`)

| Heute | Neu | Kap. |
|---|---|---|
| `MainScaffold` mit Tinten-Pille, `_NavIcon`, `_AvoOrb` | `AppTabBar` mit Avo-Kreis (00 12.1) | 00, 01 |
| `SlidingTabsContainer` (Seiten-Slide) | entfällt: Tab-Wechsel ohne Animation (K-35); behebt Slide durch leere Tabs | 00 |
| `_OfflineBanner` | `StatusRow` unter dem Titel in jedem Screen, auch in Liste und Einkaufsmodus | 00, 20 |
| Verlauf hinter der Leiste | Scroll-Edge-Effekt (00 8.2) | 00 |
| Router ohne `errorBuilder` | Fehlerseite "Diese Seite gibt es nicht mehr" mit "Zur Liste" | 20 |
| `AvoApp` mit Remount-Schlüssel | bleibt als Rahmen; `DesignScope`, kein Remount (00 17.2) | 20 |
| `TutorialOverlay` | entfällt (K-21); einmalige Tipp-Zeilen am Ort | 17 |
| `confirmDestructive` | bleibt (00 12.34) | 00 |
| `showAppBottomSheet` | `AppSheet` (00 12.23) | 00 |
| `EmptyState`, `AppEmptyState`, `LoadingIndicator` | `EmptyState` neu; Ladeanzeige entfällt (00 Kap. 13) | 00, 20 |
| `PaperSettingsAppBar` | `LargeTitleNavBar` (00 12.2) | 00 |
| Native Launch-Screen mit 1-px-Bild | nur `systemBackground`, erster Frame in Systemfarbe | 19, 20 |
| Startphase mit Flackern (Theme, Sprache, Kalorien-Tab, Pro-Status) | lokaler Stand vor `runApp`, kein Neuaufbau | 20 |
| Spinner-Katalog (62 Stellen), Fehlerboxen ohne Aktion | Zustands-Regeln 00 Kap. 13 | 20 |
| Berechtigungsdialoge beim Start (Push, Standort) | im Moment des Nutzens mit Vorab-Erklärung | 17, 19 |

### 5.2 Startseite (`inventar/home.md`)

| Heute | Neu | Kap. |
|---|---|---|
| `HomeScreen` (`/home`), Paper-Dashboard | Tab Liste, Wurzel = Liste von heute | 10 |
| `GreetingHeader` (Tageszeit-Gruß) | entfällt; der Titel ist der Listenname; Begrüßung nur im Onboarding | 10 |
| Avo-Hinweisstreifen | entfällt (einziger Einstieg ist der Avo-Kreis) | 16 |
| `AvoNudgeCard` (Nachkauf) | Sektion "Vielleicht auch" am Ende der Liste (bis 3 Zeilen); der Angebots-Teil wird die Hinweis-Zeile "Prospekt" (B) | 10, 11, 12 |
| `PersonalFlyerCard` | Hinweis-Zeile "5 Sachen, die du oft kaufst, sind im Angebot" → Angebote der Woche, gefiltert (B) | 10, 12 |
| `CalorieRecipeNudgeCard` | Hinweis-Zeile "Noch 640 kcal heute · Ideen" → Was kann ich noch essen? (B, Modul) | 10, 15 |
| `PendingSplitsBanner` | eine gebündelte Hinweis-Zeile ("2 offene Beträge") → Offene Beträge (B, Modul) | 10, 12 |
| `SplitTripNudgeCard` | Hinweis-Zeile "Wocheneinkauf mit Lena teilen?" → Kosten teilen (B, Modul) | 10, 12 |
| `PriceComparisonNudgeCard` | **entfällt** (Marktvergleich verworfen, Plan 8) | 12 |
| Listen-Index "Deine Listen" | Titelmenü und Seite Alle Listen | 10, 11 |
| Angebote-Streifen | Zeile "Angebote der Woche" in Alle Listen > Sparen (B, Modul) | 12 |
| Verlaufszeile | Alle Listen > Verlauf | 12 |
| Dialog "Neue Liste" | Sheet "Neue Liste" (Name, Farbe, Symbol, Markt-Chip) aus Titelmenü und Alle Listen | 11 |
| Dialog "Liste beitreten" (Langdruck auf "+ Neue Liste") | Sheet "Liste beitreten" (Code oder Link) aus Titelmenü und Alle Listen; Links öffnen den Beitritt direkt | 11 |
| Liste löschen per Langdruck | Wischen und Kontextmenü in Alle Listen, Listen-Info; mit Bestätigung | 11 |
| Pull-to-Refresh | bleibt als Systemverhalten, wird selten gebraucht | 10 |

### 5.3 Listen (`inventar/lists-core.md`, `lists-more.md`)

| Heute | Neu | Kap. |
|---|---|---|
| Listen-Übersicht (Abschnitt der Startseite) | Alle Listen (`/lists`) und Titelmenü | 11 |
| Listen-Detail `/lists/:id` (ohne Tab-Bar) | **ist** die Wurzel des Tabs Liste; `/lists/:id` wählt die Liste | 10, 11 |
| `AddItemComposer` | `AddItemAccessory` (00 12.4) | 11 |
| Anhang-Menü "+" (Kamera, Fotos, Dateien) | Menü aus `text.viewfinder` im Accessory; Verarbeitung als Status im Accessory ("Zettel wird gelesen …", Abbrechen) | 11 |
| Import-Prüf-Sheet | Sheet "14 Artikel erkannt": Zeilen bearbeitbar, unsichere mit `questionmark.circle`, nicht erkannte Zeilen (`unparsedLines`, heute verworfen) als Sektion "Nicht erkannt", "Alle hinzufügen" | 11 |
| Artikel-Dialog (Material, zentriert) | Artikel-Sheet mittel: Name, Menge (Stepper) und Einheit (Chips), Kategorie (Menü), Notiz, "Hinzugefügt von", Foto und Quelle, Angebot (B), Löschen | 11 |
| Teilen-Dialog (Code, Link) | Sheet "Liste teilen": Mitglieder, "Personen einladen" (System-Teilen mit Link), "Code anzeigen" | 11 |
| Umbenennen-Dialog | Name direkt im Listen-Info-Sheet bearbeiten | 11 |
| "Einkauf abschließen" (Button am Listenende + Bestätigungs-Alert) | "Einkauf beenden" im Einkaufsmodus bzw. Listenmenü; Abschluss-Sheet ohne Alert, mit Rückgängig | 11, 12 |
| `showCheckoutStoreSheet` | Teil des Abschluss-Sheets ("Wo warst du?", vorausgewählt) (B) | 12 |
| `ListSettingsScreen` | Listen-Info-Sheet: Name, Farbe und Symbol, Markt, Mitglieder (einladen, entfernen), Angebote ausblenden (B), Reihenfolge im Markt, Beim Start zeigen, Zuletzt geändert, Verlassen bzw. Löschen | 11 |
| `CategoryOrderScreen` und Kategorie-Formular | Push "Reihenfolge im Markt" aus Listen-Info; eigene Kategorien im Sheet; neu: pro Liste bzw. Markt im Konto gespeichert (heute nur Gerät) | 11 |
| `ListActivitiesScreen` (`/lists/:id/activities`, immer leer) | Abschnitt "Zuletzt geändert" im Listen-Info-Sheet mit echten Daten; die Route öffnet ihn (K-33) | 11 |
| `OfferSuggestionsBar` (Karte über der Eingabe) | Zeilen im Vorschlags-Panel des Accessory, nur Markt der Liste (B) | 11, 12 |
| `ListPriceSummaryBar` und Marktvergleich | **entfällt** (Plan 8); ersetzt durch Hinweis-Zeile `ListOfferSummary` "4 von 11 …" (B) | 12 |
| `ItemOfferChip` und Angebots-Sheet | `ItemOfferBadge` und Angebots-Sheet, nur Markt der Liste, "laut Händler" (B) | 12 |
| `showZipCodeSheet` | Sheet "Region für Angebote" (PLZ oder Standort) aus Preise & Angebote, Hinweis-Zeile ohne PLZ, Onboarding (B) | 12, 17 |
| "…"-Menü (Umbenennen, Kategoriereihenfolge, Listeneinstellungen) | Toolbar `ellipsis`: Einkaufsmodus starten, Einkauf abschließen (wenn Erledigtes da), Listen-Info, Reihenfolge im Markt, Angebote ausblenden (B), Erledigte entfernen (mit Rückgängig), Beim Start zeigen | 11 |
| KI-Empfehlungen (Karte oben in der Liste) | zusammen mit Nachkauf in "Vielleicht auch" am Listenende | 11 |
| Bewertungsdialog, wenn alles abgehakt | Systemdialog zur Bewertung höchstens nach dem dritten abgeschlossenen Einkauf, nie im Einkaufsmodus | 11 |
| Unsichtbare Dienste (Ungelesen, Badge) | Ungelesen-Punkt in Titelmenü und Alle Listen für geteilte Listen mit neuen Änderungen | 11 |

### 5.4 Rezepte (`inventar/recipes-browse.md`, `recipes-detail.md`)

| Heute | Neu | Kap. |
|---|---|---|
| `RecipesScreen` (`/recipes`) | Tab Rezepte: Suchfeld, Hero "Rezept der Woche", Abschnitte unterschiedlicher Form ("Für dich" als Foto-Reihe, "Schnell unter 20 Min" als Zeilen, "Beliebt diese Woche" als Reihe, Kategorien als Chips, "Neu" als Raster mit höchstens 6, "Ersteller" als Avatar-Reihe), Sektion "Deine Rezepte" mit Zeilen Gespeichert, Meine Rezepte, Entwürfe; `plus` in der Toolbar | 13 |
| Statistik-Banner (Anzahl Rezepte, Ersteller, gespeichert) | **entfällt** (Zahlen ohne Nutzen) | 13 |
| 2 × 2-Kacheln (Meine, Gespeichert, Entwürfe, Ersteller) | Zeilen in "Deine Rezepte" | 13 |
| Emoji-Kategorie-Raster | Chips ohne Emojis | 13 |
| `RecipesSearchResults` | Suchmodus im Tab, Sektionen Rezepte, Kategorien, Ernährung, Ersteller | 13 |
| `AllRecipesScreen` (`/recipes/all`, `/recipes/popular`) | Push mit Raster und Sortier-Menü | 13 |
| `CategoryRecipesScreen` | Push mit Filter-Chips und "Zurücksetzen" | 13 |
| `CreatorsScreen` | Push, Ersteller als Zeilen mit Avatar, Suche | 13 |
| `RecipeAuthorPage` (`/author/:id`, außerhalb der Shell) | Push im aktuellen Tab (Tab-Bar bleibt), Kopf mit Avatar und Anzahl, Rezepte als Raster | 13 |
| `SavedRecipesScreen` | Push, Rezept-Zeilen, Wischen entfernt mit Rückgängig | 13 |
| `MyRecipesScreen` | Push, Zeilen mit Bearbeiten im Kontextmenü | 13 |
| `RecipeDraftsScreen` | Push, Zeilen mit Status "Bereit" / "Unvollständig" als Text, Löschen mit Bestätigung | 13 |
| `SelectListBottomSheet` (zentrierter Dialog) | Sheet "Zutaten auf Liste": Ziel-Liste (Standard: Liste von heute), Portionen, Zutaten abwählbar ("Schon auf der Liste" markiert), angepasste Zutaten, Angebote (B); Ergebnis als Rückgängig-Hinweis statt Erfolgs-HUD | 13 |
| Ernährungs-Dialog nach 1,2 s | **entfällt**; einmalige Tipp-Zeile im Tab Rezepte "Ernährung und Allergien einstellen" | 13 |
| `RecipeDetailScreen` (`/recipes/:id`, `/recipe/:id`) | Push mit Zoom-Übergang; Foto-Kopf; Aktionsleiste "Zutaten auf Liste" / "Kochen" unten | 13 |
| Portionen-Dialog | Stepper im Kopf der Zutaten | 13 |
| Lösch-Dialog (eigenes Rezept) | Toolbar-Menü "Löschen" mit Bestätigung | 13 |
| Bewertung mit großen Sternen | Abschnitt "Bewerten" im Detail, optimistisch | 13 |
| `RecipeOffersCard` | gelbe Schilder an Zutaten plus eine Zeile "3 Zutaten bei Lidl im Angebot" (B, Modul) | 13 |
| `CookingModeScreen` (ohne Route) | Vollbild-Cover `/recipes/:id/cook`, immer schwarz, Wischen zwischen Schritten, Timer-Kapsel; Avo-Kreis bleibt | 13 |
| Portionen-Raster im Kochmodus | Stepper | 13 |
| "Timer fertig"-Dialog | zeitkritische Mitteilung plus Hinweis im Modus, nicht blockierend | 13, 19 |
| "Kochmodus verlassen?"-Dialog | **entfällt**; der Fortschritt bleibt, beim nächsten Öffnen "Weiter bei Schritt 3" | 13 |
| `MultiStepRecipeScreen` (`/recipes/add`, mit Tab-Bar) | Vollbild-Cover ohne Tab-Bar, vier Schritte bleiben, Entwurf wird automatisch gespeichert | 13 |
| Dialog "Entwurf speichern?" | **entfällt** (automatisch gespeichert); "Entwurf verwerfen" im Menü mit Bestätigung | 13 |

### 5.5 Kalorien (`inventar/calories.md`, Teil B)

| Heute | Neu | Kap. |
|---|---|---|
| `_SetupPrompt` | leerer Zustand des Tabs: "Richte dein Ziel ein" plus schlicht "Tab ausblenden" | 15 |
| `_Dashboard` (acht gleichrangige Blöcke) | Tab Kalorien: große Zahl "640 kcal übrig" mit Ring, Makros als drei Zeilen, Mahlzeiten als Sektionen, Wasser als Zeile mit "+250 ml", Woche als ein Diagramm; Tage per Wischen und Datums-Menü | 15 |
| `FoodEntrySheet` (vier Chips) | Sheet "Essen eintragen": Zeilen Foto, Barcode, Suche, Manuell, darunter "Zuletzt gegessen"; Mahlzeit nach Uhrzeit vorausgewählt | 15 |
| Barcode als Zifferneingabe | Barcode-Kamera als Vollbild-Cover `/calories/scan`; Zifferneingabe als Rückfall | 15 |
| Dialog "Menge (g)" | Mengen-Sheet mit Feld und Stepper, Live-kcal | 15 |
| `GoalSetupScreen` | Push `/calories/goals` mit Ergebnis-Vorschau vor dem Speichern | 15 |
| `WeeklySummaryScreen` | Push `/calories/week` | 15 |
| `WeightTrackingScreen` | Push `/calories/weight` mit Einträgen, Datum, Löschen | 15 |
| `ChallengesScreen` | Push `/calories/challenges` | 15 |
| `WhatCanIEatScreen` | Push `/calories/ideas` | 15 |
| `showLogRecipeSheet` | Sheet "Ins Tagebuch" aus dem Rezeptdetail | 15 |
| fehlt heute | Workouts `/calories/workouts`, Apple Health (`/settings/health`), Wasserziel | 15 |

### 5.6 Avo (`inventar/avo.md`, Teil B)

| Heute | Neu | Kap. |
|---|---|---|
| `AvoChatScreen` (`/avo`, Vollbild) | Avo-Sheet über dem aktuellen Screen; `/avo` öffnet es | 16 |
| Ergebnis-Karten (`avo_payload_cards.dart`) | Ergebniszeilen mit "Widerrufen", Rückfrage-Zeilen, Rückfrage-Karte für Löschen | 16 |
| zwei Einstiege (Orb, Startseiten-Streifen) | ein Einstieg: Avo-Kreis | 16 |
| Avo-Karten auf der Startseite | siehe 5.2 | 10 |
| Avo-Mitteilungen (Nachkauf 9 Uhr, Abendessen 18 Uhr) | "Nachkauf-Erinnerung" gehört zum Kern (Mitteilungen > Listen), "Ideen fürs Abendessen" zum Modul Kalorien; ohne Emojis; Tippen führt zum Ziel (Kapitel 8) | 19 |
| Einmal-Hinweis Ernährung | Tipp-Zeile (5.4) | 13 |
| Einmal-Hinweis Mitteilungen vor dem ersten Teilen | Vorab-Erklärung im Teilen-Ablauf (10.3) | 11 |
| fehlt heute | Sprachmodus, Foto an Avo, Werkzeuge für Wochenplan, Einladen, Rezepte anlegen, Module | 16 |

### 5.7 Onboarding und Login (`inventar/onboarding.md`)

| Heute | Neu | Kap. |
|---|---|---|
| `OnboardingScreen`: drei Feature-Seiten | **entfallen**; der Willkommens-Schritt sagt es in einem Satz, die Modulwahl zeigt den Nutzen | 17 |
| Seite "Was bringt dich zu uns?" | **entfällt** (K-22), ersetzt durch Modulwahl | 17 |
| Seite Ernährung | Schritt "Ernährung und Allergien" (überspringbar) | 17 |
| Kalorien ja/nein | Teil der Modulwahl | 17 |
| Ziel-Seite | Schritt "Dein Ziel", nur mit Modul Kalorien, überspringbar | 17 |
| `WelcomeScreen` (`/welcome`) | Schritt "Konto" (Mit Apple, Mit Google, Mit E-Mail); `/welcome` bleibt für Abgemeldete | 17 |
| `LoginScreen` mit OTP | "Anmelden": Apple, Google, E-Mail mit Code; im neuen Stil, hell und dunkel | 17 |
| `SignUpScreen` mit OTP | "Mit E-Mail fortfahren" mit Code | 17 |
| `ResetPasswordScreen` (fest dunkel) | im neuen Stil, hell und dunkel | 17 |
| `NamePromptScreen` | Schritt "Name", vorbefüllt mit dem Namen von Apple bzw. Google | 17 |
| Coach-Mark-Tutorial | **entfällt** (K-21) | 17 |
| Material-Dialoge und Snackbars | native Alerts bzw. `StatusRow` | 17 |
| fehlt heute | Modulwahl, Angebots-Einrichtung (B), erste Liste mit Markt | 17 |

### 5.8 Profil, Einstellungen, Pro (`inventar/profile.md`)

| Heute | Neu | Kap. |
|---|---|---|
| Tab Profil "Einstellungen" (`/profile`) | Sheet "Profil" aus dem Avatar; `/profile` als Alias | 18 |
| Profilkarte mit drei Zählern | Kopf mit Avatar, Name, E-Mail; Zähler entfallen | 18 |
| Premium-Karte | Zeile "{pro}" | 18 |
| Sheet "Datenquellen" | Rechtliches > Datenquellen | 18 |
| `DisplayNameScreen` | `/settings/profile` | 18 |
| Dialog "Profilbild ändern" | Menü am Avatar; "Entfernen" mit Rückgängig | 18 |
| `PersonalInfoScreen` (inkl. PLZ) | `/settings/personal`; PLZ zu Preise & Angebote | 18, 12 |
| `DietPreferencesScreen` | `/settings/diet` plus Allergien | 18 |
| `AppPrioritiesScreen` | **entfällt** (K-22) | 18 |
| `ThemeCustomizationScreen` | `/settings/appearance`, Standard "System" | 18 |
| `NotificationsScreen` | `/settings/notifications` mit iOS-Status und Uhrzeiten | 18, 19 |
| `LanguageScreen` | `/settings/language` | 18 |
| `HelpSupportScreen` | `/settings/help`; "Tutorial neu starten" wird "Tipps zurücksetzen" | 18 |
| `SubscriptionScreen` (Vollbild) | Paywall-Sheet `/pro` (00 12.31) | 18 |
| Kochmodus-Sperre | nach Pro-Konfiguration (F-10) | 13, 18 |
| Pro-Kapsel "Premium" im Avo-Kopf und in der Profilkarte | `ProBadge` bzw. Status-Zeile | 18 |
| Abmelden ohne Rückfrage | Konto > Abmelden (Rückfrage nur bei ungesendeten Änderungen) | 18 |
| fehlt heute | Konto löschen, Module, Preise & Angebote, Allergien, Widgets, Siri | 18 |

### 5.9 Verlauf, Kosten teilen, Angebote der Woche (`inventar/history.md`, Teil B)

| Heute | Neu | Kap. |
|---|---|---|
| `ShoppingHistoryScreen` (ohne Route) | Push `/history` aus Alle Listen: Sektion Monat ("November": Einkäufe, Artikel, Ausgaben falls erfasst, Ersparnis nur mit Modul, ein Diagramm mit einer Reihe), darunter Einkäufe als Zeilen wie Wallet-Transaktionen (Markt-Chip, Datum, Betrag rechts) | 12 |
| aufklappbare Einkaufszeile | Push `/history/:tripId`: Artikel, Ersparnis, Kosten teilen, "Alle wieder auf die Liste" | 12 |
| `_SplitCostSheet` | Sheet `/history/:tripId/split` (Modul Kosten teilen) | 12 |
| Löschen per Langdruck | Wischen bzw. Kontextmenü, mit Bestätigung | 12 |
| `WeeklyDealsScreen` (ohne Route) | Push `/offers` (Modul) mit Suche, Standard "Passend zu deinen Listen" | 12 |
| `_AddDealSheet` | Menü "Auf welche Liste?" mit Standard Liste von heute, danach Rückgängig-Hinweis | 12 |
| `PendingSplitsBanner` | Hinweis-Zeile und Seite Offene Beträge `/splits` | 12 |
| `SplitTripNudgeCard` | Hinweis-Zeile | 12 |

### 5.10 iOS-Systemflächen (`inventar/native.md`, Teil B außer Icon)

| Heute | Neu | Kap. |
|---|---|---|
| Widget "Einkaufsliste" (klein, mittel, groß) | Listen-Widget neu, abhakbar, im neuen Stil, getönt und klar | 19 |
| Widget "Schnell hinzufügen" | zeigt die Ziel-Liste, Rückmeldung nach dem Tipp | 19 |
| Widget "Gespeicherte Rezepte" | Widget "Rezept" mit Foto | 19 |
| `ShoppingListWidgetControl` (leer) | Steuerelemente "Artikel hinzufügen", "Liste öffnen", "Einkauf starten", "Frag Avo" | 19 |
| Neu | Widgets Wochenplan, Kalorien und Wasser, Avo fragen; Sperrbildschirm rund, rechteckig, inline; StandBy | 19 |
| App Intents (öffnen alle die App) | Hinzufügen und "Was steht auf meiner Liste?" ohne App-Öffnen; neue Intents für Einkaufsmodus, Wochenplan, Essen, Avo | 19 |
| Mitteilungen (englisch, Emojis, eine pro Häkchen) | lokalisiert, ohne Emojis, gebündelt (K-39), Aktionen, Gruppierung pro Liste | 19 |
| Berechtigungstexte (gemischt) | lokalisiert (`InfoPlist.strings` DE/EN), konkret; neu Mikrofon, Spracherkennung, Health; ungenutzter Tracking-Text entfällt | 19 |
| App-Icon (3D-Figur auf Weiß) | "Die Hälfte" in allen Erscheinungen (00 3.5) | 19 |
| Liquid-Glass-Views | erweitert um Update-Kanal und Tab-Bar (00 8.4) | 00 |

### 5.11 Neue Screens ohne Vorgänger

Alle Listen, Listen-Info, Einkaufsmodus, Abschluss-Sheet, Wochenplan (Tab, "Rezept wählen", "Zutaten auf die Liste"), Barcode-Kamera, Workouts, Avo-Sprachmodus, Modulwahl im Onboarding, Angebots-Einrichtung, Einstellungen Module / Preise & Angebote / Kalorien & Gesundheit / Wochenplan / Avo / Listen / Siri / Widgets / Konto, Konto löschen, Markt-Sheet, Modul-ist-aus-Sheet, Vorab-Erklärungen für Berechtigungen, Erfolgsmoment, Fehlerseite, Komponenten-Galerie (nur Debug, `/debug/components`).

---

## 6. Navigationsmuster

| Muster | Wann | Tab-Bar | Schließen |
|---|---|---|---|
| **Push** | Drilldown in einem Bereich (Rezeptdetail, Alle Listen, Verlauf, Einstellungsseite im Sheet) | sichtbar (immer, konsistent) | Zurück oben links, Wischen vom linken Rand |
| **Sheet mittel** | kurze Aufgabe mit Bezug zum Screen dahinter (Teilen, Abschluss, Artikel, Zutaten auf Liste, Essen eintragen, Avo) | verdeckt | Wischen nach unten, `xmark` |
| **Sheet groß** | längere Aufgabe oder eigener Bereich (Profil und Einstellungen, Listen-Info, Paywall, Sprachmodus) | verdeckt | Wischen nach unten, `xmark` |
| **Vollbild-Cover** | Modus, der volle Aufmerksamkeit braucht (Einkaufsmodus, Kochmodus, Rezept-Editor, Kamera und Scanner, Onboarding) | ausgeblendet (Avo-Kreis bleibt im Einkaufs- und Kochmodus) | `xmark` bzw. `chevron.down` oben links; im Onboarding nur über Abschluss |
| **Menü** | Auswahl von Aktionen oder Zielen (Titelmenü, `ellipsis`, `plus`, Kontextmenü) | bleibt | Tippen daneben |
| **Alert** | nur endgültiges Löschen und Gleichwertiges (00 12.34) | bleibt | Abbrechen |
| **Rückgängig-Hinweis** | Ergebnis einer umkehrbaren Aktion | bleibt | läuft ab, Wischen |

Regeln:
- **Höchstens drei Push-Ebenen** pro Tab (z. B. Rezepte > Kategorie > Rezept). Tiefer wird ein Sheet.
- **Sheets stapeln höchstens zweimal** (z. B. Listen-Info > Reihenfolge als Push im Sheet; nicht Sheet auf Sheet auf Sheet).
- **Accessory** nur auf der Wurzel des Tabs Liste. Im Rezeptdetail ersetzt die Aktionsleiste es; sonst gibt es keine schwebende Leiste über der Tab-Bar.
- **Zurück-Verhalten nach Deep Link:** Ein Link baut den passenden Stapel (Tab-Wurzel plus Ziel), statt alles zu ersetzen. Zurück führt dann zur Tab-Wurzel. Gilt für Links, Mitteilungen, Widgets und Siri gleichermaßen (heute: Links ersetzen den Stapel, Mitteilungen pushen).
- **Ungespeicherte Eingaben** gehen beim Schließen nicht verloren: Formulare speichern Entwürfe (Rezept-Editor) oder fragen per Aktionsblatt "Änderungen verwerfen?".

---

## 7. Routen

Alle heutigen Pfade bleiben gültig (Links sind extern verteilt); neue kommen dazu. Besitz nach `arbeitsteilung.md`: Teil A pflegt `lib/routes/` (Gerüst und A-Bereiche), Teil B die Bereichsdateien `lib/routes/areas/{avo,calories,plan,offers,history}*`.

| Route | Ziel | Muster | Besitz | Heute |
|---|---|---|---|---|
| `/home` | Tab Liste, Liste von heute | Tab-Wurzel | A | gleich |
| `/home?list=:id` | Tab Liste mit gewählter Liste | Tab-Wurzel | A | neu |
| `/lists` | Alle Listen | Push (Tab Liste) | A | neu |
| `/lists/:listId` (`?name=`) | wählt die Liste, zeigt Tab Liste | Tab-Wurzel | A | gleich (heute eigener Screen) |
| `/list/:listId` | Alias auf `/lists/:listId` | – | A | gleich |
| `/invite/:listId` | Beitritts-Sheet, wenn nicht Mitglied; sonst wie `/lists/:listId` | Sheet | A | gleich (heute ohne Beitritt) |
| `/join/:code` | Beitritts-Sheet mit Code | Sheet | A | neu (Universal Link `shoplyai.app/join/<CODE>` existiert) |
| `/lists/new` | Neue Liste | Sheet | A | neu |
| `/lists/join` (`?code=`) | Liste beitreten | Sheet | A | neu |
| `/lists/:listId/info` | Listen-Info | Sheet groß | A | neu |
| `/lists/:listId/activities` | Listen-Info, Abschnitt "Zuletzt geändert" | Sheet groß | A | gleich (Ziel geändert) |
| `/lists/:listId/order` | Reihenfolge im Markt | Push im Sheet | A | neu |
| `/lists/:listId/share` | Liste teilen | Sheet mittel | A | neu |
| `/lists/:listId/shopping` | Einkaufsmodus | Vollbild-Cover | A | neu |
| `/history` | Verlauf | Push (Tab Liste) | B | neu |
| `/history/:tripId` | Einkauf | Push | B | neu |
| `/history/:tripId/split` | Kosten teilen | Sheet | B | neu |
| `/splits` | Offene Beträge | Push | B | neu |
| `/offers` | Angebote der Woche | Push | B | neu |
| `/offers/list/:listId` | Angebote dieser Liste | Sheet mittel | B | neu |
| `/recipes` (`?q=`) | Tab Rezepte | Tab-Wurzel | A | gleich |
| `/recipes/:recipeId` | Rezeptdetail | Push | A | gleich |
| `/recipe/:recipeId` | öffentlicher Link, öffnet Rezeptdetail im Tab Rezepte | Push | A | gleich (heute außerhalb der Shell) |
| `/recipes/:recipeId/cook` | Kochmodus | Vollbild-Cover | A | neu |
| `/recipes/:recipeId/to-list` | Zutaten auf Liste | Sheet mittel | A | neu |
| `/recipes/add` (`draftId`, `recipeId`) | Rezept-Editor | Vollbild-Cover | A | gleich (heute mit Tab-Bar) |
| `/recipes/drafts`, `/recipes/saved`, `/recipes/my`, `/recipes/creators`, `/recipes/popular`, `/recipes/all` | Unterseiten | Push | A | gleich |
| `/recipes/category/:categoryId` | Kategorie | Push | A | gleich |
| `/author/:authorId` | Ersteller | Push im aktuellen Tab | A | gleich (heute außerhalb der Shell) |
| `/plan` | Tab Plan, aktuelle Woche | Tab-Wurzel | B | neu |
| `/plan/:weekStart` | Woche (Montag, `YYYY-MM-DD`) | Tab-Wurzel | B | neu |
| `/plan/add` (`?day=`) | Rezept wählen | Sheet groß | B | neu |
| `/plan/to-list` | Zutaten der Woche auf die Liste | Sheet mittel | B | neu |
| `/calories` | Tab Kalorien, heute | Tab-Wurzel | B | gleich |
| `/calories/add` (`?meal=`) | Essen eintragen | Sheet mittel | B | neu |
| `/calories/scan` | Barcode-Kamera | Vollbild-Cover | B | neu |
| `/calories/goals`, `/calories/week`, `/calories/weight`, `/calories/workouts`, `/calories/challenges`, `/calories/ideas` | Unterseiten | Push | B | neu (heute ohne Route) |
| `/avo` (`?prompt=`) | Avo-Sheet, optional vorbefüllt | Sheet | B | gleich (heute Vollbild) |
| `/avo/voice` | Sprachmodus | Sheet groß | B | neu |
| `/settings` | Profil und Einstellungen | Sheet groß | A | neu |
| `/profile` | Alias auf `/settings` | – | A | gleich (heute Tab) |
| `/settings/<seite>` | Seiten aus Kapitel 4 | Push im Sheet | A bzw. B laut Kapitel 4 | neu |
| `/diet-preferences` | Alias auf `/settings/diet` | – | A | gleich |
| `/pro` (`?feature=<id>`) | Paywall, Feature oben | Sheet groß | A | neu (heute ohne Route) |
| `/onboarding` (`?step=`) | Onboarding | Vollbild | A | gleich |
| `/welcome`, `/login`, `/signup`, `/reset-password`, `/name-prompt?new=1` | Konto-Schritte | Vollbild | A | gleich |
| `/debug/components` | Komponenten-Galerie (nur Debug-Build) | Push | A | neu |
| alles andere | Fehlerseite | Vollbild | A | neu (heute go_router-Standardfehler) |

Regeln:
- Routen eines ausgeschalteten Moduls öffnen das Modul-Sheet ("Kalorien ist ausgeschaltet", "Einschalten" / "Nicht jetzt"); bei Kill-Switch für Angebote: Fehlerseite ohne Hinweis auf Angebote.
- Routennamen (`name:`) bleiben, wo es sie gibt, wegen der Analytics-Screen-Namen; neue Routen bekommen sprechende Namen (`list-info`, `shopping-mode` …).
- Abgemeldet geöffnete private Links (nicht nur Listen wie heute) werden gemerkt und nach dem Login fortgesetzt.

---

## 8. Deep Links, Mitteilungen, Widgets, Siri

### 8.1 Schema und Universal Links

| Link | Ziel |
|---|---|
| `shoply://recipe/<id>`, `https://shoplyai.app/recipe/<id>` | `/recipe/:id` |
| `shoply://list/<id>`, `https://shoplyai.app/list/<id>` | `/lists/:id` |
| `shoply://invite/<id>`, `https://shoplyai.app/invite/<id>` | `/invite/:id` |
| `https://shoplyai.app/join/<CODE>` | `/join/:code` |
| `shoply://author/<id>`, `https://shoplyai.app/author/<id>` | `/author/:id` |
| `shoply://lists` | `/lists` |
| `shoply://recipes`, `shoply://recipes/saved`, `shoply://recipes/search?q=` | `/recipes`, `/recipes/saved`, `/recipes?q=` |
| `shoply://addItem` | `/home` mit fokussiertem Accessory |
| `shoply://add-item?name=&list=&quantity=` | fügt hinzu (Liste per Name, sonst neu), zeigt die Liste, Rückgängig-Hinweis |
| `shoply://create-list?name=` | legt an (bzw. öffnet die gleichnamige), zeigt sie |
| neu: `shoply://shopping?list=<id>` | Einkaufsmodus |
| neu: `shoply://avo`, `shoply://avo/voice` | Avo-Sheet, Sprachmodus |
| neu: `shoply://plan`, `shoply://calories/add`, `shoply://calories/scan` | Plan, Essen eintragen, Barcode |
| neu: `shoply://settings/<seite>`, `shoply://pro` | Einstellungsseite, Paywall |

Doppelte Zustellung innerhalb 2 s wird verworfen; der Kaltstart-Link wird genau einmal behandelt (wie heute).

### 8.2 Mitteilungen: Ziel beim Tippen

| Typ | Ziel |
|---|---|
| `list_update`, `item_toggled`, `item_deleted` | Liste |
| `list_activity`, `category_change` | Liste mit Listen-Info "Zuletzt geändert" |
| `list_invitation` | Beitritts-Sheet (wenn nicht Mitglied), sonst Liste |
| `list_member_joined` (Schlüssel `listId` statt `list_id` angleichen) | Listen-Info, Mitglieder |
| neu: `shopping_started` ("Lena kauft gerade bei REWE ein") | Liste |
| `shopping_complete` | Verlauf, dieser Einkauf |
| `expense_split` | Einkauf, Abschnitt Kosten teilen |
| `recipe_rating`, `recipe_like`, `recipe_comment` (auch altes Feld `recipe_id`) | Rezeptdetail (bei Kommentar am Abschnitt Kommentare) |
| `avo_restock` (Nachkauf-Erinnerung) | Liste von heute, "Vielleicht auch" hervorgehoben |
| `avo_dinner_ideas` | `/calories/ideas` (Modul Kalorien; sonst Liste) |
| Kochtimer | Kochmodus des Rezepts |

### 8.3 Widgets und Siri: Ziele

| Quelle | Ziel |
|---|---|
| Listen-Widget, freie Fläche | `/lists/:id` |
| Listen-Widget, Zeile | hakt im Widget ab (App Intent), öffnet nicht |
| Listen-Widget, `plus` | `/home?list=:id` mit fokussiertem Accessory |
| Schnell hinzufügen | fügt im Widget hinzu, öffnet nicht |
| Rezept-Widget | `/recipe/:id` |
| Wochenplan-Widget | `/plan` (Tag) |
| Kalorien-Widget | `/calories` |
| Avo fragen (Widget, Steuerelement, Action Button) | `/avo/voice` |
| Siri "Füg Milch zu {app} hinzu" | fügt hinzu ohne App-Öffnen, Antwort im Siri-Snippet |
| Siri "Was steht auf meiner Liste?" | liest die Liste von heute vor, ohne App-Öffnen |
| Siri "Starte meinen Einkauf" | `shoply://shopping` |
| Siri "Frag Avo" | `/avo/voice` |

---

## 9. Suche

**Global:** im Feld "Frag Avo oder suche" (Avo an) bzw. hinter dem Lupen-Kreis (Avo aus). Beim Tippen erscheinen sofort lokale Treffer in Sektionen:

1. **Aktionen:** "Neue Liste", "Einkauf starten", "Essen eintragen" (Modul), "Liste teilen".
2. **Listen:** Name, offene Anzahl.
3. **Artikel:** "Milch · auf Wocheneinkauf".
4. **Rezepte:** lokaler Cache sofort, Online-Treffer entprellt nachgeladen (unten angefügt, nie oben eingeschoben).
5. **Einstellungen:** jede Seite mit Titel und Suchwörtern (z. B. "PLZ", "Postleitzahl", "Region" → Preise & Angebote; "dunkel" → Darstellung; "Allergie" → Ernährung & Allergien).
6. Letzte Zeile (nur Avo an): "Frag Avo: „…“". Return schickt an Avo.

**Bereichssuchen (im Inhalt):** Tab Rezepte (Rezepte, Kategorien, Ernährung, Ersteller), Einstellungen-Sheet, Alle Listen (ab 7 Listen), Angebote der Woche (B), Lebensmittel im Essen-Sheet (B), Ersteller-Seite.

Offline: nur lokale Treffer, darüber `StatusRow` "Offline. Es werden nur gespeicherte Ergebnisse gezeigt."

---

## 10. Abläufe

### 10.1 Artikel hinzufügen

1. Tab Liste, Liste von heute ist offen. Daumen tippt unten auf "Artikel hinzufügen".
2. Tab-Bar fährt weg, Tastatur öffnet, das Feld sitzt auf der Tastatur. Das Vorschlags-Panel zeigt vor dem ersten Buchstaben bis zu 5 oft gekaufte Artikel, die nicht offen auf der Liste stehen.
3. Eingabe "2 Mi": Die erste Zeile zeigt sofort "Milch · Menge 2 · Milch & Käse"; darunter Verlaufstreffer ("Milch", "Mineralwasser"); mit Modul Angebote bis zu drei Angebote des Listen-Markts ("Milbona Frische Vollmilch 0,99 € bei Lidl").
4. Return (oder Tippen auf eine Zeile): Die Zeile erscheint sofort in "Milch & Käse" (wächst ein). Liegt die Kategorie außerhalb des sichtbaren Bereichs, zeigt das Accessory kurz "Milch → Milch & Käse". VoiceOver sagt "Milch hinzugefügt". Das Feld leert sich, der Fokus bleibt.
5. Nächster Artikel. Ist derselbe Artikel mit gleicher Einheit schon offen, erhöht sich die Menge ("Milch: Menge jetzt 3 · Widerrufen").
6. Wischen nach unten oder Tippen in die Liste schließt die Tastatur; die Tab-Bar kommt zurück.

Sonderfälle: offline wird die Zeile mit Sync-Zeichen angelegt und später gesendet; korrigiert die KI die Kategorie, wandert die Zeile ohne Sprung; ein Angebot übernommen setzt Preis und Händler am Artikel ("laut Händler").

**Variante Zettel importieren:** `text.viewfinder` > Kamera / Fotos / Dateien > Status im Accessory "Zettel wird gelesen …" (Abbrechen) > Sheet "14 Artikel erkannt" (Zeilen bearbeiten, unsichere markiert, nicht erkannte Zeilen sichtbar) > "Alle hinzufügen" > Zeilen erscheinen, Rückgängig-Hinweis "14 Artikel hinzugefügt · Widerrufen".

### 10.2 Im Laden einkaufen

1. Tab Liste. Daumen tippt unten rechts "Einkaufen" (nur sichtbar, wenn mindestens ein Artikel offen ist).
2. Beim ersten Mal steht unter dem Titel einmalig "Der Bildschirm bleibt an, solange du einkaufst."
3. Morph: Die Tab-Bar zieht sich in den Knopf zurück, das Accessory wird zum "+"-Knopf unten links, der Avo-Kreis bleibt unten rechts, dazwischen erscheint "Einkauf beenden" (getönt). Die Liste wird randlos und groß.
4. Kopf: großer Titel = Markt der Liste ("Lidl", sonst der Listenname), rechts "0 von 11" (`numberXL`), darunter eine dünne Fortschrittslinie in Textfarbe. Gibt es weitere Einkäufer: "Lena kauft auch gerade ein".
5. Mitglieder sehen "Jannis kauft gerade bei Lidl ein" in ihrer Liste (live) und bekommen einmal eine gebündelte Mitteilung.
6. Gänge haften oben in der Reihenfolge des Markts ("Obst & Gemüse 3"). Tippen irgendwo auf eine Zeile hakt ab: Kreis füllt sich, leichter Impuls, "1 von 11" rollt, unten "Abgehakt: Bananen · Widerrufen" für 4 s, nach 0,6 s wandert die Zeile nach "Im Wagen (1)". Unter Reduce Motion bleibt sie stehen, bis man nicht mehr scrollt.
7. Was Lena abhakt, zeigt 2 s ihren Avatar am Kreis und wandert dann ebenso; VoiceOver sagt "Lena hat Butter abgehakt".
8. Vergessen? "+" unten links öffnet ein kleines Eingabefeld auf der Tastatur; der neue Artikel erscheint im passenden Gang. Avo-Kreis halten: "Was fehlt für Lasagne?".
9. Versehentlich abgehakt: "Widerrufen" in der Leiste oder in "Im Wagen" nach rechts wischen.
10. Offline: `StatusRow` unter dem Titel; Abhaken geht in die Warteschlange und geht nicht verloren.
11. Letzter Artikel: Erfolgs-Haptik, unter der Liste "Alles im Wagen." Weiter mit 10.4.
12. Unterbrechen ohne Abschluss: `chevron.down` oben links; der Stand bleibt, die Präsenz endet nach 5 Minuten im Hintergrund.

### 10.3 Liste teilen und beitreten

**Teilen:**
1. Tab Liste > Toolbar `person.crop.circle.badge.plus`.
2. Sheet "Liste teilen" (mittel): bisherige Mitglieder, prominent "Personen einladen", schlicht "Code anzeigen".
3. Beim ersten Teilen vorher die Vorab-Erklärung "Erfahre, wenn jemand etwas hinzufügt oder einkauft" mit "Mitteilungen erlauben" / "Nicht jetzt", danach ggf. die Systemabfrage.
4. "Personen einladen" öffnet das System-Teilen mit Link `https://shoplyai.app/list/<id>` und Text "Komm auf meine Liste „Wocheneinkauf“ in {app}." (ohne Emoji).
5. "Code anzeigen" zeigt den sechsstelligen Code groß (`numberXL`), Tippen kopiert ("Code kopiert" als Hinweis).
6. Ist das Modul Kosten teilen aus, erscheint einmalig die Hinweis-Zeile "Kosten teilen einschalten? Praktisch für gemeinsame Einkäufe".
7. Tritt jemand bei: Mitteilung, Avatar erscheint in der Metazeile.

**Beitreten (Empfänger):**
1. Link öffnet die App (ohne App über die Brücke auf `joinavo.app` zum App Store).
2. Abgemeldet: Onboarding bzw. Anmelden; der Link wird gemerkt.
3. Sheet "„Wocheneinkauf“ beitreten? Von Jannis · 12 Artikel" mit "Beitreten" (prominent) und "Abbrechen".
4. Nach dem Beitritt wird die Liste die Liste von heute. Per Code: Titelmenü > "Liste beitreten" > Code eingeben.

### 10.4 Einkauf abschließen

1. Einkaufsmodus > "Einkauf beenden" (oder im normalen Modus Listenmenü > "Einkauf abschließen", sobald Erledigtes da ist). Kein Bestätigungs-Alert.
2. Abschluss-Sheet (mittel, Teil B):
   - "11 Artikel im Wagen" und, falls zutreffend, "3 bleiben auf der Liste".
   - "Wo warst du?": Markt-Chips, vorausgewählt in dieser Reihenfolge: Markt der Liste, gelernter Markt, Märkte am Standort; "Anderer Markt".
   - "Betrag" (optional, Zahlenfeld in `number`).
   - "Kosten teilen" (nur Modul Kosten teilen und geteilte Liste).
   - Mit Modul Angebote: "ca. 3,20 € durch Angebote gespart, laut Händler".
   - Rechts oben `checkmark` (getönt) "Speichern".
3. Sheet schließt, dann Erfolgsmoment (feiernder Avo, "Einkauf gespeichert.", Erfolgs-Haptik), 1,5 s, Tippen schließt.
4. Einkaufsmodus endet, die Tab-Bar morpht zurück. Die Liste zeigt nur noch die offenen Artikel; Erledigtes liegt im Verlauf.
5. Rückgängig-Hinweis "Einkauf gespeichert · Widerrufen" (4 s; Widerrufen stellt die Artikel und den Zustand wieder her).
6. War "Kosten teilen" gewählt, öffnet sich danach das Sheet Kosten teilen.
7. Mitglieder erhalten eine Mitteilung "Jannis hat bei Lidl eingekauft (11 Artikel)". Der gewählte Markt wird gelernt (nach zweimal demselben Markt Vorschlag für den Markt-Chip).
8. Nach dem ersten abgeschlossenen Einkauf: einmalig die Hinweis-Zeile mit dem Pro-Angebot (00 Kap. 16.4).

### 10.5 Rezept auf die Liste

1. Rezeptdetail > Aktionsleiste unten "Zutaten auf Liste" (getönt).
2. Sheet mittel: Ziel-Liste oben (Menü, Standard Liste von heute), Portionen-Stepper, Zutaten mit Häkchen (abwählbar; "Schon auf der Liste" ist abgewählt und markiert; angepasste Zutaten mit `arrow.left.arrow.right` und Grund; Angebote mit Schild).
3. "12 Zutaten hinzufügen" (prominent). Sheet schließt, Rückgängig-Hinweis "12 Zutaten zu Wocheneinkauf · Widerrufen". Gleiche Zutaten werden mit bestehenden Artikeln gleicher Einheit zusammengefasst.

### 10.6 Wochenplan zur Liste (Teil B)

1. Tab Plan ("Wochenplan", aktuelle Woche; Wochenwechsel über die Toolbar `chevron.left` / `chevron.right` und Wischen).
2. Die Woche als senkrechte Tage ("Mo, 9. Nov."), je Tag Rezept-Zeilen (Foto 56 pt, Titel, Portionen-Stepper) oder schlicht "Rezept hinzufügen". Mit Modul Kalorien: kcal pro Tag rechts im Tageskopf.
3. "Rezept hinzufügen" > Sheet "Rezept wählen" (Gespeichert, Für dich, Suche) > Tippen legt das Rezept auf den Tag (Portionen = Standard aus den Einstellungen).
4. Portionen pro Tag anpassen (Stepper, Auswahl-Haptik, Mengen rollen).
5. Schwebende Aktionsleiste über der Tab-Bar: "17 Zutaten auf Wocheneinkauf" (getönt; Ziel-Liste per Menü daneben).
6. Sheet "Zutaten der Woche": gleiche Zutaten zusammengefasst ("Zwiebeln · 4 Stück · für 3 Rezepte"), abwählbar ("Hab ich schon"), schon offene markiert. "Hinzufügen".
7. Erfolgsmoment ("Wochenplan ist auf der Liste."), Rückgängig-Hinweis. Die Startseite zeigt ab dann "Heute im Plan: …".
8. Gesperrt (falls Pro): Der Plan ist voll benutzbar zum Ansehen und Füllen; erst Schritt 5 öffnet die Paywall aus der Leiste.

### 10.7 Essen loggen (Teil B)

1. Tab Kalorien > Toolbar `plus` bzw. "Eintragen" im Kopf einer Mahlzeit.
2. Sheet "Essen eintragen" (Mahlzeit nach Uhrzeit vorausgewählt, oben änderbar): Zeilen "Foto", "Barcode", "Suche", "Manuell", darunter "Zuletzt gegessen" (ein Tipp trägt ein).
3. **Foto:** Kamera als Cover > Foto > zurück im Sheet: Zeile mit Avo-Kern (`denkt`) "Wird geschätzt …" > Vorschau "Spaghetti Bolognese · ca. 650 kcal · geschätzt, ca. 80 % sicher" mit bearbeitbaren Feldern (Menge, kcal, Makros) > "Eintragen". Nie direkt gespeichert. Kein Essen erkannt: "Ich erkenne darauf kein Essen. Manuell eintragen?"
4. **Barcode:** Kamera als Cover mit Sucher > erkannt (leichter Impuls) > Produkt mit Foto (Quelle Open Food Facts) > Mengen-Sheet (Gramm, Stepper, Live-kcal) > "Eintragen". Nicht gefunden: Zifferneingabe als Rückfall, dann Manuell.
5. **Suche:** Feld mit lokalen und Open-Food-Facts-Treffern > Produkt > Mengen-Sheet.
6. Ergebnis: Sheet schließt, der Eintrag erscheint in der Mahlzeit, "640 kcal übrig" rollt, der Ring folgt; Rückgängig-Hinweis. Mit Apple Health: wird geschrieben.
7. Per Avo: "Trag mein Mittagessen ein" plus Foto ergibt dieselbe Vorschau als Ergebniszeile mit "Bearbeiten" und "Eintragen".

### 10.8 Avo per Sprache (Teil B)

1. Avo-Kreis halten (oder im Feld "Frag Avo" auf `waveform` tippen).
2. Beim ersten Mal: Vorab-Erklärung "Sprich mit Avo. Deine Stimme wird nur für diese Anfrage verarbeitet." > Systemabfragen Mikrofon und Spracherkennung.
3. Sheet groß, Avo-Kern in der Mitte, "Avo hört zu" (Ansage und leichter Impuls).
4. Sprechen: "Setz Milch, Eier und zwei Gurken auf die Lidl-Liste." Das Transkript erscheint live.
5. Pause erkannt: Kern `denkt`, dann `spricht`: "Erledigt: drei Artikel auf Lidl." Text Wort für Wort, darunter die Ergebniszeile "3 Artikel zu Lidl hinzugefügt · Widerrufen".
6. Weiter sprechen oder `xmark`. Antippen des Kerns unterbricht Avo sofort.
7. Löschen per Sprache: Avo fragt hörbar und zeigt die Rückfrage-Karte; erst der Tipp auf "Löschen" führt aus.
8. Unklar ("Welche Liste?"): Avo fragt hörbar und zeigt die Listen als Zeilen; Antwort per Stimme oder Tipp.
9. Offline: "Ich höre dich gerade nicht. Prüfe deine Verbindung." (neutral, ohne Figur).

### 10.9 Erster Start mit Modulwahl

Ziel: unter 60 Sekunden bis zur eigenen Liste. Jeder Schritt außer "Konto" ist überspringbar; Zurück oben links.

1. Start: Systemhintergrund, dann **Willkommen**: winkender Avo (160 pt), "{app}" in `largeTitle`, ein Satz (Text legt der Owner fest, z. B. "Einkaufsliste und Rezepte, die mitdenken."), prominent "Los geht's", schlicht "Ich habe schon ein Konto".
2. **Module** "Was brauchst du?": Satz "Liste und Rezepte sind immer dabei." Darunter `ToggleRow`s je Modul mit einem Satz Nutzen, Standard nach F-04 (Angebote an). Prominent "Weiter".
3. **Angebote in deiner Region** (nur, wenn Angebote an; Teil B, `OffersSetupStep`): "Standort verwenden" (Vorab-Erklärung, dann Systemabfrage) oder Postleitzahl eintippen; Lieblingsmärkte als Chips (mehrere wählbar). Überspringen möglich.
4. **Konto:** "Mit Apple fortfahren" (Systembutton), "Mit Google fortfahren", "Mit E-Mail fortfahren" (Adresse, dann 6-stelliger Code).
5. **Name:** vorbefüllt von Apple bzw. Google; "Wie sollen andere dich in geteilten Listen sehen?"
6. **Ernährung und Allergien** (optional): Ernährungsweisen als Chips, Allergien als Chips; Hinweis "Rezepte passen sich daran an."
7. **Dein Ziel** (nur mit Modul Kalorien, optional): kurzer Fragebogen mit Ergebnis-Vorschau ("Etwa 2.000 kcal am Tag").
8. **Erste Liste:** "Wie heißt deine erste Liste?" mit Vorschlägen "Wocheneinkauf", "Lidl", "Drogerie" und eigenem Namen; ein Kettenname setzt den Markt-Chip.
9. Tab Liste mit fokussiertem Accessory und einer Tipp-Zeile "Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei."

Nicht im Onboarding: Mitteilungen (erst beim Teilen), Pro-Testphase (erst nach dem ersten Einkauf oder Wochenplan), Tutorial. Wer sich anmeldet und schon ein Konto hat, überspringt Schritte 2, 3, 5 bis 8 (Module und Daten kommen aus dem Konto).

### 10.10 Pro kaufen

1. Einstieg: `ProBadge` an einem Feature, eine gesperrte Aktion (z. B. "Auf die Liste" im Wochenplan), eine kontextuelle Hinweis-Zeile oder Profil > "{pro}".
2. Die Paywall wächst als Sheet aus dem angetippten Element; das Feature steht oben, hervorgehoben.
3. Jährlich ist vorausgewählt; Preise kommen aus StoreKit. Zeitleiste der Testphase sichtbar.
4. "14 Tage gratis testen" > System-Kaufblatt (Face ID).
5. Erfolg: Erfolgsmoment ("{pro} ist aktiv."), Erfolgs-Haptik, Paywall schließt, man ist wieder am Ausgangspunkt, und die ursprünglich gewünschte Aktion läuft weiter (z. B. die Zutaten landen auf der Liste).
6. Abbruch im Kaufblatt: nichts passiert, die Paywall bleibt offen.
7. Fehler: `StatusRow` in der Paywall "Der Kauf hat nicht geklappt. Erneut versuchen".
8. Ausstehend (Familie, "Kaufen anfragen"): "Wartet auf Freigabe" in der Paywall und im Profil.
9. Wiederherstellen: Link in der Paywall und im Profil; Ergebnis als Status-Hinweis.
10. Verwalten und kündigen: Profil > {pro} > "Abo verwalten" (Systemblatt).
