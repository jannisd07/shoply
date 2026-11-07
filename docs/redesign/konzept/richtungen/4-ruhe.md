# Richtung 4: "Stand"

Arbeitsname der Richtung im Konzept: **Ruhig und klar** (id `ruhe`). App-Name "Avo" ist Platzhalter und überall austauschbar.

---

## 1. Name und ein Satz

**Stand.** Fast monochrom wie Wallet, Aktien und die Health-Übersicht: Jeder Screen beantwortet seine eine Frage mit einer großen, ehrlichen Zahl, alles andere tritt zurück.

---

## 2. Gefühl

**Emotion:** Gelassene Kontrolle. Man öffnet die App, sieht in einer Sekunde "11 offen, ca. 3,20 Euro gespart, 640 kcal übrig" und weiß, wo man steht. Kein Lärm, keine Dekoration, nichts, das um Aufmerksamkeit bettelt. Die Ruhe selbst ist der Qualitätsbeweis, für den man Pro bezahlt.

**Apple-Apps als Haltung (nichts kopieren):**
- **Wallet:** Eine Zahl als Held, darunter die Bewegungen. Vertrauen durch Präzision und Zurückhaltung.
- **Aktien:** Fast nur Schwarz, Weiß und Grau; Farbe ist Information, nie Schmuck. Grün heißt etwas.
- **Health, Übersicht:** Kennzahlen als Zeilen mit großer Ziffer und kleiner Einheit, ein Diagramm beantwortet genau eine Frage.
- **Erinnerungen:** Abhaken ist der wichtigste Moment, schnell, rund, eindeutig.
- **Fitness (Zusammenfassung):** Fortschritt ist eine Form, die man auf einen Blick liest.

**Abgrenzung zu den anderen Richtungen:** Diese Richtung hat keine Markenfläche, keine farbigen Listen-Hintergründe, keine Illustrationen als Stimmung. Ihre Persönlichkeit kommt ausschließlich aus Typografie, Ziffern und Bewegung der Ziffern. Wer sie sieht, erkennt sie an den großen tabellarischen Zahlen und daran, dass Grün nur auftaucht, wenn es um Geld oder Gesundheit geht.

---

## 3. Fünf Prinzipien

1. **Eine Frage, eine Zahl.** Jeder Screen hat genau eine Hauptfrage und beantwortet sie mit einer Heldenzahl oben (Heute: "Was fehlt noch?" = 11 offen; Einkaufsmodus: "Wie viel noch?" = 7; Kalorien: "Wie viel darf ich noch?" = 640 kcal). Alles darunter erklärt diese Zahl.
2. **Farbe ist Bedeutung.** Die Oberfläche ist Graphit auf Hell bzw. Hell auf Schwarz. Grün bedeutet ausschließlich Geld (gespart, Angebot) oder Gesundheit (Ziel erreicht, Ring). Rot nur für Fehler und endgültiges Löschen, Bernstein nur für Warnungen (z. B. Allergie). Nichts anderes ist farbig, außer Markt-Chips (Markenfarbe als Punkt) und Listenfarben (als Punkt).
3. **Ehrliche Zahlen.** Jede Zahl ist echt, aus Nutzerdaten berechnet und beschriftet, woher sie kommt: "ca.", "in deiner Region", "laut Händler". Keine erfundenen Vanity-Werte, keine Zahl ohne Bedeutung. Fehlen Daten, steht ein Satz statt einer Null.
4. **Tonstufen statt Linien.** Flächen trennen sich über Helligkeit (Hintergrund, Fläche, erhöhte Fläche), nicht über Rahmen oder Schatten. Unter der schwebenden Glasebene gibt es Scroll-Edge-Effekte, keine Trennstriche.
5. **Präzision im Detail.** Tabellarische Ziffern überall, wo Zahlen sich ändern; Einheiten kleiner und leichter als die Zahl; Ziffern rollen beim Ändern statt zu springen; Ausrichtung an einer festen Zahlenkante rechts. Nichts ist zufällig, jeder Wert stammt aus dem Token-System.

---

## 4. Farben

Alle Farben sind adaptive Tokens (hell/dunkel) in `AppColors`. Kontrastwerte gegen die jeweilige Fläche geprüft (Text primär und sekundär mindestens 4,5:1). Bei "Kontrast erhöhen" gilt die dritte Spalte bzw. die angegebene Anpassung.

### Grundflächen und Text

| Rolle | Hell | Dunkel | Hinweis |
|---|---|---|---|
| Hintergrund (Seite, gruppiert) | `#F2F2F5` | `#000000` | Dunkel echtes Schwarz wie Wallet und Aktien |
| Fläche 1 (Zeilen, Inhaltsblöcke) | `#FFFFFF` | `#141416` | Gruppierte Listen, Kennzahlenblöcke |
| Fläche 2 (erhöht, Eingaben, gedrückt) | `#E9E9EE` | `#232327` | Suchfeld, gedrückter Zustand, Segmente |
| Fläche 3 (Spur von Fortschritt, Ring-Hintergrund) | `#DCDCE2` | `#2E2E33` | Leere Spur von Balken und Ringen |
| Trenner (nur eingerückt in Zeilengruppen) | `#E3E3E8` | `#2A2A2F` | 0,5 pt, eingerückt ab Textbeginn |
| Text primär (auch Fließtext) | `#0B0B0F` | `#F5F5F7` | Fließtext immer in voller Textfarbe |
| Text sekundär (Einheiten, Metazeilen) | `#5C5C66` | `#A1A1AA` | 6,5:1 auf Weiß, 7,1:1 auf `#141416` |
| Text tertiär (Platzhalter, deaktiviert) | `#8E8E96` | `#6C6C74` | Nie für lesenswerte Inhalte |
| Abgehakt (durchgestrichen) | `#8E8E96` | `#6C6C74` | Plus Durchstreichung, nicht nur Farbe |

### Aktion, Status, Bedeutung

| Rolle | Hell | Dunkel | Einsatz |
|---|---|---|---|
| **Akzent (Aktionen): Graphit** | `#111114` | `#F2F2F4` | Primäre Buttons (gefüllte Kapsel), Schalter "an", ausgewähltes Segment, Häkchen-Kreis gefüllt, Links in Semibold. Die eine Aktionsfarbe. |
| Text auf Akzent | `#FFFFFF` | `#0B0B0F` | Beschriftung in gefüllten Buttons |
| **Geld und Gesundheit: Avocado-Grün** | `#1F7A45` | `#4CC27A` | "gespart", Angebotspreis, Kalorienring, "Ziel erreicht". 5,3:1 auf Weiß, 8,6:1 auf Schwarz |
| Grün, flächig schwach (Angebots-Kapsel) | `#1F7A45` mit 10 % auf Fläche 1 (`#E9F2EC`) | `#4CC27A` mit 16 % (`#16301F`) | Nur die kleine Kapsel "Angebot", nie große Flächen |
| Erfolg | `#1F7A45` | `#4CC27A` | Gleiches Grün; nur als Symbol in Bestätigungen (z. B. Häkchen im Abschluss-Sheet), nie als Hintergrund |
| Warnung | `#A35400` | `#FFB340` | Allergie-Hinweis, Kalorien über Ziel (kein Rot, keine Beschämung), Daten veraltet |
| Fehler und endgültiges Löschen | `#D70015` | `#FF6961` | Fehlermeldung, Löschen-Button im Bestätigungsdialog |
| Pro-Kennzeichnung | Graphit-Kontur `#111114`, Text `#111114` | Kontur `#F2F2F4`, Text `#F2F2F4` | Kleine Kapsel "Pro", bewusst ohne Gold oder Farbe |

**Kontrast erhöhen:** Text sekundär wird `#3C3C43` / `#C7C7CC`, Trenner werden 1 pt und `#C7C7CC` / `#48484A`, Grün wird `#176236` / `#6BD592`.

### Listenfarben (Identität einer Liste)

Listenfarben erscheinen nur als 10-pt-Punkt vor dem Listennamen, als Farbe des Fortschrittsbalkens dieser Liste in der Listenübersicht und im Widget. Nie als Seitenhintergrund. Bewusst ohne Grün (reserviert) und ohne Terrakotta.

| Name | Hell | Dunkel |
|---|---|---|
| Graphit (Standard) | `#3A3A40` | `#C7C7CC` |
| Schiefer | `#4E6175` | `#9FB3C8` |
| Ozean | `#1F6F8B` | `#5FB4D1` |
| Indigo | `#4B4FB0` | `#8F93F0` |
| Pflaume | `#7A4E7E` | `#C796CB` |
| Rosé | `#A8566A` | `#E59AAE` |
| Bernstein | `#8A6410` | `#E0B54F` |

Die heutigen Listen-Hintergründe (Farben, Verläufe, Bilder) werden so übersetzt: Farben und Verläufe werden zu einer der sieben Listenfarben; ein eigenes Bild bleibt erlaubt und erscheint als ruhiges Kopfbild (180 pt hoch, nach unten in den Seitenhintergrund ausgeblendet) nur in der Listenansicht, nicht im Einkaufsmodus.

### Markt-Chips (keine echten Logos)

Kapsel in Fläche 2, darin ein 8-pt-Punkt in Markenfarbe und der Name in Subhead Semibold, Text primär. Punktfarben: REWE `#CC071E`, Lidl `#0050AA`, Aldi Süd `#1C2B6B`, Aldi Nord `#00549F`, Edeka `#FFD400` (mit 0,5-pt-Kontur in Text tertiär, damit Gelb auf Weiß sichtbar bleibt), Kaufland `#E10915`, Netto `#FFE500` (ebenfalls mit Kontur), PENNY `#CD1414`. "Kein fester Markt" = Punkt in Text tertiär. Echte Logos erst mit schriftlicher Erlaubnis.

### Diagramme

Eine Frage, eine Datenreihe: Balken und Linien in Text primär (Graphit) mit 100 %, Vergleichsperiode in Fläche 3. Grün nur, wenn die Reihe Geld oder Gesundheit ist (Ersparnis pro Monat, Kalorien). Zielmarke als gestrichelte Linie in Text sekundär. Nie mehrere Farben nebeneinander.

---

## 5. Typografie

**Schrift:** SF Pro (Systemschrift, in Flutter `CupertinoSystemText`/`CupertinoSystemDisplay` über `.SF`-Fallback, keine eingebundene Schrift). Alle sich ändernden Zahlen mit tabellarischen Ziffern (`FontFeature.tabularFigures()`), damit Spalten und rollende Ziffern nicht springen.

**Regeln:**
- Hierarchie aus Gewicht, Größe und Zeilenabstand als Satz. Keine Großbuchstaben-Kicker, keine Laufweite-gesperrten Überschriften; Abschnittstitel sind Satzschreibung ("Obst und Gemüse", nicht "OBST & GEMÜSE").
- Laufweite größenabhängig: Systemstile nach Apples SF-Tabelle (Werte unten), Heldenzahlen ab 40 pt zusätzlich deutlich enger, weil große Ziffern sonst auseinanderfallen.
- Einheit neben einer Heldenzahl: gleiche Grundlinie, Größe 40 % der Zahl, Gewicht Medium, Text sekundär ("640" groß, "kcal übrig" klein).
- Dynamic Type bis AX5. Jeder Stil skaliert mit; Heldenzahlen skalieren bis Faktor 1,6 und verkleinern sich darüber nur, wenn die Breite nicht reicht (nie abgeschnitten, nie mit "...").
- Fetter Text (Bold Text) hebt jeden Stil um eine Gewichtsstufe; Layouts sind darauf geprüft.

| Token | Größe / Zeile | Gewicht | Laufweite | Einsatz |
|---|---|---|---|---|
| `zahlXL` | 64 / 64 pt | Semibold | -2,0 pt | Heldenzahl eines Screens (11 offen, 640 kcal, 29,99 Euro) |
| `zahlL` | 40 / 42 pt | Semibold | -1,0 pt | Zweite Ebene (Monatsausgaben, Gewicht) |
| `zahlM` | 22 / 26 pt | Semibold | -0,3 pt | Kennzahlen in Zeilen und Nährwertzeilen |
| `largeTitle` | 34 / 41 pt | Bold | +0,37 pt | Screen-Titel, schrumpft beim Scrollen in die Inline-Leiste |
| `title1` | 28 / 34 pt | Bold | +0,36 pt | Rezepttitel, Paywall-Überschrift |
| `title2` | 22 / 28 pt | Bold | +0,35 pt | Abschnitte auf Übersichtsseiten |
| `title3` | 20 / 25 pt | Semibold | +0,38 pt | Sheet-Titel, Kochmodus-Schritt-Kopf |
| `headline` | 17 / 22 pt | Semibold | -0,43 pt | Kategorie-Überschriften, Zeilentitel mit Gewicht |
| `body` | 17 / 22 pt | Regular | -0,43 pt | Artikelnamen, Fließtext, Eingabe |
| `callout` | 16 / 21 pt | Regular | -0,31 pt | Avo-Antworten, Beschreibungen |
| `subhead` | 15 / 20 pt | Regular / Semibold | -0,23 pt | Metazeilen, Markt-Chip, Buttons sekundär |
| `footnote` | 13 / 18 pt | Regular | -0,08 pt | Quellenangaben ("laut Händler", "Foto: Open Food Facts") |
| `caption1` | 12 / 16 pt | Medium | 0 pt | Achsen, Tab-Beschriftung, Einheiten in Widgets |
| `caption2` | 11 / 13 pt | Semibold | +0,06 pt | Kapsel "Pro", "Angebot" |

Kochmodus-Schritttext: 28 / 36 pt Regular (`title1` in Regular), damit er aus einem Meter lesbar ist.

---

## 6. Material und Form

### Liquid Glass (nur Bedienebene)
- **Tab-Leiste:** schwebende Glas-Kapsel unten mit Icon und Beschriftung, rechts daneben ein separater runder Glas-Knopf (Avo, siehe Abschnitt 8). Native Komponente über `adaptive_platform_ui` bzw. `UIGlassEffect`.
- **Eingabe-Accessory:** Die Hinzufügen-Leiste in Listen sitzt als Glas-Kapsel direkt über der Tab-Leiste (iOS-Muster "Bottom Accessory"); beim Scrollen nach unten verschmilzt sie mit der Tab-Leiste (Glas-Morph), beim Fokus fährt sie über die Tastatur.
- **Toolbars:** Glas-Knöpfe oben (Zurück, Teilen, Mehr-Menü) als einzelne runde Glas-Elemente, keine Leistenfläche.
- **Schwebende Primärknöpfe:** "Zutaten auf Liste" im Rezept, "Einkauf beenden" im Einkaufsmodus, als Glas-Kapsel mit Graphit-Füllung (getöntes Glas).
- **Menüs und Kontextmenüs:** wachsen aus dem auslösenden Knopf.
- **Sheets in Teilhöhe:** Avo, Markt wählen, Menge ändern, Einkauf abgeschlossen. In voller Höhe wird ein Sheet opak (Fläche 1), wie bei iOS.
- **Nie Glas:** Listenzeilen, Kennzahlenblöcke, Rezeptkarten, Diagramme, Chat-Antworten. Kein Glas auf Glas: Knöpfe innerhalb eines Glas-Sheets sind Graphit-Kapseln oder Fläche 2, nicht wieder Glas.
- **Scroll-Edge:** Inhalte laufen unter Tab-Leiste und Toolbars durch; dort ein weicher Unschärfe- und Ausblendverlauf (Höhe 24 pt) statt einer Linie.
- **Reduce Transparency:** Glas wird zu einer festen Fläche (hell `#F7F7F9`, dunkel `#1C1C1F`) mit 0,5-pt-Kontur. **Kontrast erhöhen:** gleiche feste Fläche, Kontur 1 pt.

### Radien (konzentrisch)
- Basis ist der Geräteradius (ca. 55 pt bei aktuellen iPhones). Ein Element mit Abstand `a` zum Rand bekommt Radius `Geräteradius minus a`.
- Tab-Leiste und Eingabe-Accessory: volle Kapsel (Radius = halbe Höhe).
- Sheets: oben konzentrisch zum Gerät (iOS-Standard), Inhaltsblöcke darin mit 16 pt Rand bekommen 26 pt.
- Inhaltsblöcke auf der Seite (16 pt Seitenrand): 24 pt. Zeilen innerhalb eines Blocks: keine eigenen Ecken.
- Kapseln (Buttons, Chips, Segmente): volle Kapsel.
- Thumbnails (Artikelbild, Produktfoto) 8 pt, Rezeptbild im Detail randlos ohne Ecken oben, in Listen 16 pt.
- Widgets: Systemradius, Innenelemente konzentrisch (Widget-Rand 16 pt).

### Tiefe
- Inhalte haben **keine Schatten**. Tiefe entsteht durch Tonstufen (Hintergrund, Fläche 1, Fläche 2) und durch die Glasebene, die über den Inhalten schwebt.
- Die einzige Ausnahme ist das Glas selbst (sein Systemschatten) und der Ziehzustand einer Zeile (leicht angehoben, 1,02-fach, weicher Schatten 12 pt, 8 % Schwarz).

### Raster und Abstände
- Seitenrand 16 pt (bei 320 pt Breite ebenfalls 16 pt, nie weniger), Blockabstand 28 pt, Zeilen-Innenabstand 12 pt vertikal.
- Zeilen haben Mindesthöhe 52 pt in Listen, 64 pt im Einkaufsmodus; Höhe wächst mit dem Text, nie feste Höhen um Text. Touch-Ziele mindestens 44 x 44 pt.
- Zahlenkante: Alle Beträge und Mengen stehen rechtsbündig an derselben Kante (16 pt vom Rand), tabellarisch.

---

## 7. Ikonografie, Artikelbilder, Fotos, Maskottchen

### Ikonografie
- **Nur SF Symbols**, Gewicht passend zum Text daneben (Regular zu Body, Semibold zu Headline), Rendering monochrom in Text primär oder sekundär. Hierarchisch nur, wo Apple es selbst tut (z. B. `checkmark.circle.fill`).
- Nie Icons in getönten Quadraten. Einstellungszeilen haben ein freistehendes Symbol in Text sekundär, 22 pt Spalte, ohne Hintergrundkachel.
- Rezeptkategorien bekommen SF Symbols statt Emojis (`leaf` vegan, `timer` schnell, `dumbbell` proteinreich usw.).
- Häkchen: eigener Kreis 26 pt (Liste) bzw. 32 pt (Einkaufsmodus), Kontur 1,5 pt Text tertiär, abgehakt gefüllt in Graphit mit weißem `checkmark` (dunkel: gefüllt Hell mit schwarzem Haken). Bewusst nicht grün: Abhaken ist Handlung, nicht Geld.

### Artikelbilder
- **Eigene Illustrationen** für alle Kategorie-IDs und die ca. 200 häufigsten Artikel: monochrome Strichzeichnungen, 1,5 pt Linie in Text sekundär, eine Tonfläche in Fläche 3, gerade Ansicht, ohne Rahmen und ohne Kachel, 28 pt in Listen, 36 pt im Einkaufsmodus. Sie wirken wie eine Erweiterung der SF Symbols und funktionieren in hell, dunkel, getönt und in Widgets.
- **Produktfotos von Open Food Facts** nur bei erkanntem Produkt oder Barcode: freigestellt auf Fläche 2, 8 pt Ecken, mit "Foto: Open Food Facts, CC BY-SA" im Artikel-Detail.
- Keine Prospekt- oder Händlerfotos. Ohne Lizenz zeigen auch Angebotszeilen die Illustration.
- In den Einstellungen abschaltbar ("Artikelbilder anzeigen"), dann rückt der Text an den Häkchen-Kreis.

### Fotos
- Rezeptfotos sind die einzige große Farbe in der App und deshalb Helden des Rezeptbereichs: natürliches Licht, keine Filter, keine Rahmen. Im Detail randlos oben, darüber nur die Glas-Toolbar-Knöpfe.
- Essensfotos im Kalorien-Modul: quadratisch, 16 pt Ecken, mit der KI-Schätzung als Zahl daneben und der Sicherheit in Worten ("ziemlich sicher", "grobe Schätzung").

### Maskottchen
Die heutige Avocado (3D, glänzend, gelbgrünes Fruchtfleisch, brauner Kern, Ärmchen und Beinchen) bleibt erkennbar, wird aber für diese Richtung **flach und matt** neu gezeichnet: drei Tonwerte (Schale `#1F7A45`, Fruchtfleisch `#D9E8B8`, Kern `#6B4A2E`), keine Glanzlichter, gleiche Linienstärke-Logik wie die Artikel-Illustrationen. Stimmungen bleiben (winkend, denkend, feiernd).

Einsatz bewusst selten, damit er Gewicht hat:
- **Ja:** Willkommen im Onboarding (einmal, winkend), leere Zustände (klein, 96 pt, eine Zeile Text daneben), der erste abgeschlossene Einkauf und der Monatsrückblick (feiernd, einmal pro Anlass), Avos Avatar im Chat (nur Kopf, 28 pt).
- **Nein:** als Figur in der Tab-Leiste (dort nur die einfarbige Silhouette als Symbol des Avo-Knopfs), auf der Paywall, in Widgets, in Hinweisen, als Lade-Animation.

---

## 8. Navigation

### Tabs (schwebende Glas-Tab-Leiste, Icon plus Beschriftung)

| Tab | SF Symbol | Bedingung | Inhalt |
|---|---|---|---|
| **Heute** | `checklist` | immer | Die Liste von heute mit Tageszeile; Listenwechsel über den Titel |
| **Rezepte** | `fork.knife` | immer | Entdecken, Gespeichert, Meine, Ersteller; bei Modul Wochenplan zusätzlich Segment "Woche" oben |
| **Kalorien** | `chart.bar.xaxis` bzw. `flame` | Modul Kalorien an | Tagesübersicht, Mahlzeiten, Wasser, Gewicht, Workouts, Woche |
| **Bilanz** | `eurosign.circle` | Modul Angebote oder Kosten teilen an | Monat: ausgegeben, gespart, Verlauf, Kosten teilen, Angebote der Woche |

- Mindestens 2, höchstens 4 Tabs. Ein Modul, das man ausschaltet, nimmt seinen Tab mit; der Inhalt wechselt per Überblendung, ohne seitlichen Slide.
- **Bilanz** ist die Signatur dieser Richtung: Hier liegen alle Zahlen zu Geld an einem Ort (wie Wallet), statt Spar-Karten über die App zu verstreuen. Ist weder Angebote noch Kosten teilen an, gibt es den Tab nicht; Verlauf liegt dann im Profil.
- **Wochenplan** ist kein eigener Tab, sondern die erste Ansicht des Rezepte-Tabs, wenn das Modul an ist ("Woche" | "Entdecken" | "Gespeichert"), weil Planen und Rezepte dieselbe Frage teilen.

### Avo: genau ein Einstieg
- Der runde Glas-Knopf rechts neben der Tab-Leiste, an der Stelle, an der Apple den Suchen-Tab setzt. Symbol: die flache Avo-Silhouette als eigenes Template-Symbol (einfarbig, im Stil der SF Symbols).
- **Tippen:** Avo-Sheet in Teilhöhe wächst aus dem Knopf (Glas-Morph). **Lang drücken:** startet direkt den Sprachmodus.
- Keine weiteren Avo-Einstiege: kein Hinweisstreifen auf Heute, keine Avo-Knöpfe in Listen. Andere Bereiche verweisen höchstens mit Text auf "Frag Avo" und öffnen dasselbe Sheet.
- **Modul Avo aus:** Der Knopf wird zur App-weiten Suche (`magnifyingglass`), wie bei Apple.

### Profil und Einstellungen
- Avatar (32 pt, Initialen auf Fläche 2) oben rechts in der großen Titelleiste jedes Tab-Startscreens, wie in App Store und Health.
- Tippen öffnet ein Sheet in voller Höhe: Kopf mit Name und Pro-Status, darunter gruppierte Einstellungen. Ganz oben: **Module** (Schalter für Kalorien, Wochenplan, Angebote, Kosten teilen, Avo) und **Preise und Angebote** (eigener Bereich mit allen Spar-Schaltern, Standort/PLZ, Lieblingsmärkte, Markt-Erkennung). Dann Ernährung und Allergien, Mitteilungen, Darstellung, Sprache, Konto, Hilfe, Rechtliches.
- Suchfeld oben im Einstellungs-Sheet, damit "Angebote" oder "Allergien" in einem Schritt gefunden werden.

### Wegfindung
- Drilldowns (Liste, Rezept, Einstellungen) behalten die Tab-Leiste und haben oben links den Glas-Zurück-Knopf.
- Modale Vollbild-Abläufe (Einkaufsmodus, Kochmodus, Rezept erstellen, Onboarding) verbergen die Tab-Leiste und haben oben links "Fertig" bzw. "Schließen".
- Der große Titel nennt immer den Ort ("Wocheneinkauf", "Rezepte", "November"), nie "Home".

---

## 9. Signatur-Screens

### Startseite "Heute" (die Liste von heute)
**Hauptfrage:** Was muss ich noch kaufen?
- Oben: großer Titel ist der Listenname mit kleinem Pfeil ("Wocheneinkauf" mit `chevron.down`); Tippen öffnet ein Menü aus dem Titel mit allen Listen (Name, Listenfarbe, offene Anzahl) und "Neue Liste". Rechts der Avatar. Darunter in Subhead sekundär: "Samstag, 7. November".
- "Liste von heute" ist die zuletzt aktive Liste, bzw. die, die für heute im Wochenplan steht oder an der gerade ein Mitglied einkauft.
- **Heldenzahl:** "11" in `zahlXL`, daneben "von 18 offen" in sekundär. Darunter ein 4-pt-Fortschrittsbalken in Listenfarbe auf Fläche 3. Darunter der Markt-Chip ("REWE") und Mitglieder-Avatare; kauft jemand gerade ein: "Lena ist gerade bei REWE" mit pulsierendem Punkt (sanft, unter Reduce Motion statisch).
- **Tageszeile:** ein Block mit bis zu drei Kennzahlen nebeneinander, je `zahlM` plus Einheit: "11 offen", "ca. 3,20 Euro gespart" (grün), "640 kcal übrig" (grün, nur mit Kalorien-Modul). Jede Zahl ist antippbar. Bei 320 pt Breite oder ab der größten normalen Textstufe stapeln sie sich untereinander.
- **Angebote dieser Liste** (Modul an, Liste nicht ausgeblendet): eine Zeile "4 von 11 Artikeln diese Woche bei REWE im Angebot, ca. 3,20 Euro gespart, in deiner Region". Tippen zeigt die vier Artikel.
- **Die Liste selbst:** nach Gang gruppiert, Kategorie-Überschrift in `headline` mit Anzahl rechts. Zeile: Häkchen-Kreis, Illustration, Artikelname (`body`), Menge rechts tabellarisch ("2"), bei Angebot darunter "1,19 Euro bei REWE, laut Händler statt 1,79 Euro" in footnote mit grünem Preis. Wer hinzugefügt hat, als Initiale nur bei geteilten Listen.
- **Unten:** Eingabe-Accessory "Artikel hinzufügen" (Glas) mit Kamera-Symbol (Foto-Import) und einem Graphit-Knopf "Einkaufen" (`cart`), der den Einkaufsmodus startet. Beim Tippen ins Feld erscheinen Vorschläge aus dem Verlauf als Zeilen über der Tastatur; "2 Milch" zeigt live "Menge 2 · Milch". Die Leiste wächst mit Dynamic Type mit (behebt den abgeschnittenen Text).
- Ganz unten in der Liste, nach dem letzten Gang: "Erledigt (7)" eingeklappt.

### Liste im Einkaufsmodus
**Hauptfrage:** Was fehlt in diesem Gang noch?
- Vollbild, Tab-Leiste weg, Bildschirm bleibt an (`wakelock`). Oben links "Fertig", rechts Mehr-Menü (Artikelbilder an/aus, Erledigte zeigen).
- Kopf: "7" in `zahlXL`, daneben "noch · REWE" und der Fortschrittsbalken; die Zahl rollt bei jedem Haken herunter.
- Gänge als haftende Überschriften ("Obst und Gemüse 3"), Reihenfolge nach Markt (falls bekannt), sonst nach eigener Sortierung.
- Zeilen 64 pt: 32-pt-Häkchen-Kreis links, Illustration 36 pt, Name in `body` Semibold, Menge rechts groß in `zahlM`. Die ganze Zeile ist Tippfläche.
- Abgehakt: Kreis füllt sich, Text wird durchgestrichen und grau, nach 0,6 s gleitet die Zeile in "Im Wagen" am Ende; Wischen nach rechts auf "Im Wagen" holt sie zurück. Unten erscheint 4 s lang "Abgehakt: Bananen · Widerrufen".
- Live von anderen: Hakt Lena ab, füllt sich der Kreis mit ihrer Initiale "L" kurz sichtbar, dann wie oben.
- Unten Glas-Leiste: "Lena kauft auch ein" (Avatar) und rechts die Graphit-Kapsel "Einkauf beenden". Sie öffnet das Abschluss-Sheet: "18 Artikel", Markt-Chip "REWE" vorausgewählt (gelernt), optional "Betrag eintragen" oder "Bon fotografieren", "ca. 3,20 Euro gespart" in Grün, "Kosten teilen" (Modul) und "Fertig".

### Rezeptdetail
**Hauptfrage:** Will ich das kochen, und was brauche ich dafür?
- Randloses Foto oben (ca. 45 % der Höhe), darüber nur Glas-Knöpfe Zurück, Speichern, Teilen. Beim Scrollen wird der Titel inline.
- Titel `title1`, darunter Autor und "25 Min · 2 Portionen".
- **Nährwertzeile** wie Health: vier Spalten "540 kcal", "32 g Protein", "48 g Kohlenhydrate", "21 g Fett", Zahlen in `zahlM`, Einheiten klein. Bei schmaler Breite 2 x 2.
- Portionen-Stepper (Glas-frei, Fläche 2, `minus` / `plus`), alle Mengen rechnen live mit rollenden Ziffern um.
- **Allergie-Hinweis** (Responsibility), wenn zutreffend, ganz oben im Inhalt in Bernstein: "Enthält Erdnüsse. Passt nicht zu deinen Allergien. Avo kann eine Variante ohne vorschlagen."
- Zutaten als Zeilen mit Menge rechts tabellarisch; "Schon auf deiner Liste" in sekundär; Angebote mit grünem Preis (Modul an).
- Schritte nummeriert in `body`, Timer im Text als antippbare Kapsel ("12 Min").
- Schwebend unten: Glas-Kapsel "Zutaten auf Liste" (Graphit gefüllt) und runder Glas-Knopf "Kochen" (`frying.pan`). Darunter im Inhalt: "Ins Tagebuch eintragen" (Kalorien-Modul), Varianten, Kommentare.

### Avo mit Sprachmodus
**Hauptfrage:** Was soll Avo für mich tun?
- **Sheet in Teilhöhe** aus dem Avo-Knopf. Leer: drei Vorschläge als Textzeilen (keine Karten) passend zum Moment ("Was fehlt für Lasagne?", "Trag mein Mittagessen ein", "Was ist diese Woche im Angebot?"). Unten Eingabefeld mit Kamera, Mikrofon und Senden.
- **Chat:** Nutzertext rechts in Fläche 2, Avos Antworten links ohne Blase als `callout` in voller Textfarbe mit kleinem Avo-Kopf. Aktionen erscheinen als **Ergebniszeile** im Stil einer Wallet-Transaktion: Symbol, "3 Artikel zu Wocheneinkauf hinzugefügt", rechts "Widerrufen". Rezepte als eine kompakte Zeile mit Foto 44 pt.
- **Rückfrage bei Mehrdeutigkeit:** Avo zeigt die Listen als auswählbare Zeilen.
- **Löschen nur mit Rückfrage:** eigene Zeile "Liste 'Party' mit 12 Artikeln löschen? Das lässt sich nicht widerrufen." mit "Löschen" (Rot) und "Abbrechen". Andere Änderungen ohne Dialog, aber mit Widerrufen.
- **Sprachmodus** (Mikrofon antippen oder Avo-Knopf lang drücken): Sheet wächst auf volle Höhe, Hintergrund wird Schwarz (dunkel) bzw. `#F2F2F5` (hell). In der Mitte eine einzelne waagerechte Wellenlinie in Graphit (Pegel der Stimme, wie Sprachmemos), darüber das Gesprochene live in `title2`, Avos Antwort danach in `title2` in voller Textfarbe, während sie gesprochen wird. Ausgeführte Aktionen erscheinen als Ergebniszeilen am unteren Rand. Unten zwei große runde Knöpfe: Stummschalten und Beenden (Rot `xmark`). Unter Reduce Motion statt Welle ein ruhiger Pegelbalken.

### Paywall
**Hauptfrage:** Lohnt sich Pro für mich?
- Sheet in voller Höhe, ohne Maskottchen, ohne Verläufe, ohne Konfetti. Oben links "Schließen" (immer sichtbar).
- Überschrift `title1`: "Avo Pro". Darunter die Heldenzahl "29,99 Euro" in `zahlXL` und "pro Jahr, das sind 2,50 Euro im Monat" in sekundär.
- **Plan-Wahl** als zwei Zeilen in einem Block: "Jährlich, 29,99 Euro, spart 16 %" (vorausgewählt, Graphit-Häkchen) und "Monatlich, 2,99 Euro". Keine erfundenen Rabattbalken.
- **Was Pro enthält:** Zeilen mit freistehendem SF Symbol und einem Satz pro Funktion, aus einer Konfiguration gespeist (`pro_features`), damit der Owner später beliebige Features eintragen kann. Die Funktion, über die man gekommen ist, steht oben und ist fett.
- **Zeitleiste der Testphase** (Vertrauen): drei Punkte auf einer Linie: "Heute: alles frei", "Tag 12: Wir erinnern dich", "Tag 15: Abo beginnt, 29,99 Euro".
- Graphit-Kapsel "14 Tage gratis testen", darunter in footnote "Danach 29,99 Euro pro Jahr. Jederzeit in den Einstellungen kündbar." und "Käufe wiederherstellen", "AGB", "Datenschutz".
- **Pro-Kennzeichnung in der App:** kleine Kapsel "Pro" (Graphit-Kontur, `caption2`) neben gesperrten Funktionen. **Kontextueller Hinweis:** eine Zeile am Ort der Funktion, kein Pop-up: "Der Wochenplan ist Teil von Avo Pro. 14 Tage gratis testen" mit Pfeil. Angebote tragen nie die Kapsel.

### Widget
- **Klein:** Listenpunkt und Name in `caption1`, darunter "11" in großer Ziffer und "offen", unten Markt-Chip "REWE" klein. Tippen öffnet die Liste.
- **Mittel:** links Heldenzahl "11 offen" und Fortschrittsbalken, rechts vier Artikel mit Häkchen-Kreisen, die direkt im Widget abhaken (App Intents); die Zahl rollt nach.
- **Groß:** Listenname, Fortschritt, acht Artikel nach Gang gruppiert mit Häkchen, unten die Zeile "4 im Angebot, ca. 3,20 Euro gespart" (Modul an) und ein "+" für Schnell hinzufügen.
- **Weitere Typen:** Schnell hinzufügen, Wochenplan (heute und morgen), Rezept (gespeichert, mit Foto), Kalorien und Wasser (Ring plus "640 kcal"), Angebote (nur wenn Modul an und lizenzrechtlich erlaubt). Konfigurierbar: Liste, Erledigte zeigen, nach Gang gruppieren.
- **Sperrbildschirm:** rund als Fortschrittsring "7/18", rechteckig "Wocheneinkauf · 11 offen · REWE", inline "11 offen". **StandBy:** riesige Ziffer und Listenname.
- **Getönt und klar:** Weil die Richtung schon monochrom ist, bleibt im getönten Modus die gesamte Hierarchie erhalten (Hierarchie hängt an Größe und Helligkeit, nicht an Farbe). Grün wird dann einfach zur Tönungsfarbe.
- **Control Center / Action Button:** "Artikel hinzufügen", "Liste öffnen".

### Wie der Rest getragen wird (kurz)
- **Onboarding:** Ein Screen pro Frage, große Überschrift, eine Aktion. Willkommen mit winkendem Avo und "Mit Apple fortfahren". Danach Module als Liste mit Schalter und einem Satz Nutzen (Angebote standardmäßig an, dann PLZ und Lieblingsmärkte im selben Ablauf). Mitteilungen erst, wenn eine geteilte Liste entsteht. Pro-Test erst nach dem ersten abgeschlossenen Einkauf.
- **Rezepte-Tab:** Großer Titel, Suchfeld, ein großes "Rezept der Woche"-Foto, danach Abschnitte mit unterschiedlicher Form (eine Reihe großer Fotos, eine Liste kompakter Zeilen, Ersteller als Avatar-Reihe), keine Wände identischer Karten. Filter als Kapseln in Fläche 2.
- **Kochmodus:** Schwarz (auch im hellen Modus, damit es in der Küche ruhig ist), "Schritt 3 von 7" als Zahl oben, Schritttext 28 pt, Timer als große Ziffern, Zutaten-Check zuerst.
- **Kalorien:** Heldenzahl "640 kcal übrig", ein grüner Ring, drei Makro-Balken je eine Reihe in Graphit, die grün werden, wenn das Ziel erreicht ist. Mahlzeiten als Zeilen mit kcal rechts. Wasser als Zahl mit "+250 ml". Gewicht als Linie mit Zielmarke. Workouts als Zeilen. Wochenansicht: sieben Balken in Graphit, heute in Grün. Hinzufügen: Foto, Barcode-Kamera, Suche, manuell als vier Zeilen im Sheet.
- **Bilanz:** "November" groß, "186,40 Euro ausgegeben" in `zahlXL`, "18,60 Euro gespart" in Grün, ein Balkendiagramm Ausgaben pro Woche (eine Reihe), darunter vergangene Einkäufe wie Wallet-Transaktionen (Markt-Chip, Datum, Betrag rechts). Kosten teilen als Ablauf aus einem Einkauf heraus. "Angebote der Woche" als Zeile mit Anzahl, gefiltert auf die eigenen Listen.
- **Foto-Import:** Prüf-Sheet mit erkannten Artikeln als bearbeitbare Zeilen, Zahl oben "14 Artikel erkannt", Knopf "Alle hinzufügen".
- **Leere Zustände:** kleiner Avo, ein Satz, eine Aktion. Statt "0 offen": "Alles erledigt. Schön."

---

## 10. Bewegung und Haptik

**Federn (Flutter: `SpringDescription` aus Dämpfung und Antwort umgerechnet, ein zentraler `AppMotion`-Token-Satz):**

| Anlass | Dämpfung | Antwort | Bemerkung |
|---|---|---|---|
| Standard (Einblenden, Umordnen, Sheet-Detents ohne Wisch) | 1,0 | 0,35 s | Kein Überschwingen |
| Häkchen-Kreis füllt sich | 1,0 | 0,25 s | Kreis skaliert von 0,9 auf 1,0 beim Drücken, füllt beim Loslassen |
| Abgehakte Zeile gleitet nach "Im Wagen" | 1,0 | 0,4 s | Startet 0,6 s nach dem Haken, abbrechbar durch erneutes Tippen |
| Nach Wisch oder Flick (Sheet loslassen, Zeile wegwischen) | 0,8 | 0,35 s | Übernimmt die Fingergeschwindigkeit |
| Glas-Morph (Avo-Knopf zu Sheet, Accessory in Tab-Leiste) | 1,0 | 0,4 s | Herkunft am Knopf |
| Menüs | 1,0 | 0,3 s | Wachsen aus dem auslösenden Element |

**Signatur: rollende Ziffern.** Ändert sich eine Zahl (offen, gespart, kcal, Portionen), rollen nur die betroffenen Ziffern vertikal in Richtung der Änderung (abwärts beim Weniger-Werden), tabellarisch, damit nichts seitlich springt. Unter Reduce Motion: Überblenden der Zahl in 0,2 s.

**Regeln:**
- Alles ist unterbrechbar und startet vom aktuellen Wert; Gesten folgen dem Finger 1:1 mit Rand-Gummiband.
- Tab-Wechsel: Überblenden ohne Slide, ohne Haptik.
- Fortschrittsbalken und Ring folgen der Zahl mit derselben Feder.
- Laden ist nie sichtbar: Daten aus dem lokalen Stand erscheinen sofort; neue Werte vom Server rollen ein. Platzhalter nur beim allerersten Start, als ruhige Tonflächen ohne Schimmer.
- Reduce Motion: alle Bewegungen werden Überblendungen, keine Pulse, keine Wellenlinie.

**Haptik (zeitgleich mit dem Bild, nur bei Bedeutung):**
- Abhaken: leichter Impuls (`lightImpact`) im Moment, in dem sich der Kreis füllt.
- Abhaken des letzten Artikels: Erfolg (`notificationSuccess`).
- Sheet rastet auf Detent ein, Zeile rastet beim Umsortieren ein: Auswahl-Tick (`selectionClick`).
- Fehler (nicht gespeichert, offline fehlgeschlagen): Fehler-Haptik.
- Keine Haptik bei Tab-Wechsel, Zurück, Scrollen, normalen Knöpfen.

---

## 11. App-Icon-Idee

**Motiv:** Eine halbierte Avocado von oben, auf Geometrie reduziert: ein ovaler Ring (Schale und Fruchtfleisch als zwei konzentrische Formen) und darin der runde Kern. **Der Kern ist ein Häkchen-Kreis:** Aus dem Kern ist ein Haken ausgespart. Avocado und abgehakte Liste in einem Zeichen, ohne Gesicht, ohne Text. Das Maskottchen lebt in der App, das Icon bleibt ruhig.

| Erscheinung | Gestaltung |
|---|---|
| **Hell** | Hintergrund sehr helles Grau `#F5F5F7` mit kaum sichtbarem Verlauf nach `#E9E9EE`. Schale `#1F7A45`, Fruchtfleisch `#D9E8B8`, Kern Graphit `#111114`, Haken ausgespart (Hintergrundfarbe scheint durch). |
| **Dunkel** | Hintergrund Schwarz `#000000` nach `#141416`. Schale `#4CC27A`, Fruchtfleisch `#2E4A2A` (gedämpft, damit es nachts nicht leuchtet), Kern `#F5F5F7` mit ausgespartem schwarzem Haken. |
| **Klar (Liquid Glass)** | In Icon Composer drei Ebenen: hinten das Glas, Mitte der Ring als mattierte Glasform, vorne der Kern mit Haken als klarste, schärfste Ebene. Der Haken bleibt durch Aussparung lesbar, unabhängig vom Hintergrundbild. |
| **Getönt** | Reine Helligkeitsstufen: Ring mittel, Fruchtfleisch hell, Kern dunkel, Haken hell. Weil das Zeichen schon aus wenigen Tonstufen besteht, verliert es beim Tönen nichts. |

Der Kern sitzt leicht unter der Mitte (wie in einer echten Avocado), dadurch wirkt das Icon nicht wie ein generisches Kreis-Symbol.

---

## 12. Stärken, Risiken, Aufwand und Performance in Flutter

### Stärken
- **Wirkt sofort hochwertig und vertrauenswürdig**, wie eine Apple-App aus der Finanz- und Gesundheitsfamilie. Das passt zu einem Abo-Produkt.
- **Trägt tägliche Nutzung:** Die Tageszeile und die Bilanz machen Ersparnis, Fortschritt und Kalorien zu Gründen, die App auch ohne Einkauf zu öffnen.
- **Module fügen sich ohne Umbau ein:** Ein Modul ist eine weitere Kennzahl in der Tageszeile und ggf. ein Tab; ausgeschaltet verschwindet es spurlos (auch Angebote beim Kill-Switch: die Zeile und das grüne "gespart" fallen weg, sonst ändert sich nichts).
- **Bestes Verhalten bei großer Schrift und kleinen Geräten:** Wenige Elemente, keine Dekoration, Zahlen stapeln sich. 320 pt und AX-Stufen sind einfacher als bei bildlastigen Richtungen.
- **Widgets im getönten Modus** funktionieren von Natur aus.
- **Einfachstes Token-System** aller Richtungen: eine Aktionsfarbe, ein Bedeutungs-Grün, Tonstufen.

### Risiken
- **Kann kühl wirken** für eine Familien- und WG-App. Gegenmittel: die rollenden Ziffern, das seltene Maskottchen, warme Formulierungen ("Alles erledigt. Schön."), Rezeptfotos als einzige große Farbe.
- **Graphit als Aktionsfarbe** ist weniger auffällig als ein farbiger Akzent. Gegenmittel: Aktionen immer als gefüllte Kapsel oder mit SF Symbol, Links in Semibold; im Usability-Test prüfen, ob "Zutaten auf Liste" gefunden wird.
- **Zahlen-Disziplin ist Pflicht:** Die Richtung lebt von ehrlichen Zahlen. Schätzungen müssen "ca." tragen, Angebote "in deiner Region" und "laut Händler", mit Fallback-PLZ keine Ersparnis. Fehlen Daten (neuer Nutzer), wirken leere Heldenzahlen traurig; dafür braucht es gute Sätze statt Nullen.
- **Grün-Disziplin im Team:** Zwei Leute bauen parallel. Wenn einer Grün für "fertig" oder einen Schalter nutzt, bricht die Richtung. Deshalb Grün nur über die Tokens `money` und `health`, kein generisches `success`-Grün im Code.
- **Heldenzahlen bei AX5:** 64 pt mal 1,6 ist sehr groß; Verkleinerungsregel und Umbruch der Einheit unter die Zahl müssen sauber implementiert sein.

### Aufwand (grob, für zwei Personen mit Claude Code)
- **Klein:** Token-System (`AppColors`, `AppTextStyles`, `AppDimensions`, `AppMotion`), Paper vollständig ersetzen. Wegen der wenigen Farben schneller als jede andere Richtung.
- **Mittel:** Komponenten `HeroNumber` (rollende tabellarische Ziffern, Dynamic-Type-Regeln), `MetricRow`, `ProgressBar`/`Ring` mit Federn, Häkchen-Kreis, Markt-Chip, Ergebniszeile (Avo), Pro-Kapsel und kontextueller Pro-Hinweis.
- **Mittel bis groß:** Bilanz-Tab (neuer Bereich aus Verlauf, Statistiken, Kosten teilen, Angebote), Artikel-Illustrationen (ca. 230 Strichzeichnungen, als SVG oder Template-Asset), neues Maskottchen flach, Widgets in SwiftUI im selben Stil.
- **Groß, aber in jeder Richtung gleich:** Sprachmodus, Einkaufsmodus mit Live-Präsenz, Wochenplan, Kalorien-Ausbau.

### Performance in Flutter (Ziel iPhone 13 Pro, 120 Hz)
- **Wenig Glas = wenig Kosten:** gleichzeitig höchstens drei native Glas-Elemente (Tab-Leiste, Avo-Knopf, Eingabe-Accessory), Sheets über native Präsentation bzw. `adaptive_platform_ui`. Kein `BackdropFilter` in Zeilen oder Karten. Der Scroll-Edge-Effekt als ein einziger Verlauf pro Kante.
- **Keine Schatten auf Inhalten** spart Rasterarbeit beim Scrollen.
- **Rollende Ziffern** als eigenes leichtes Widget (pro Ziffer ein `ClipRect` mit `Transform`, `RepaintBoundary` um die Zahl), nur die geänderten Ziffern animieren.
- **Listen:** `SliverList` mit festen Schlüsseln, Riverpod `select` pro Zeile, damit ein Haken nur eine Zeile neu baut. Illustrationen als vorgeladene, gecachte Vektor- oder Rasterbilder in zwei Größen.
- **Diagramme** als `CustomPainter` mit einer Reihe, kein Diagramm-Paket mit Schatten und Verläufen.
- **Dunkel echtes Schwarz** spart auf OLED zusätzlich Energie, was im Einkaufsmodus mit dauerhaft eingeschaltetem Bildschirm zählt.

---

## 13. Bildzeile für ChatGPT

Zeichne zwei iPhone-17-Pro-Mockups nebeneinander im hellen Modus, im Stil einer Apple-App aus iOS 27 mit Liquid Glass, fast monochrom wie Apple Wallet und Aktien: Seitenhintergrund #F2F2F5, Inhaltsblöcke reines Weiß #FFFFFF mit 24 pt Ecken ohne Schatten und ohne Rahmen, Text Graphit #0B0B0F und Grau #5C5C66, Schrift SF Pro, keine Großbuchstaben-Überschriften, als einzige Farbe ein dunkles Avocado-Grün #1F7A45, das nur bei Geldbeträgen und Kalorien vorkommt. Links die Startseite "Heute": großer fetter Titel "Wocheneinkauf" mit kleinem Pfeil nach unten, rechts ein runder Avatar "JD", darunter "Samstag, 7. November", dann eine riesige Zahl "11" mit "von 18 offen" daneben, ein dünner grauer Fortschrittsbalken, eine graue Kapsel mit rotem Punkt und "REWE", der Satz "Lena ist gerade bei REWE", ein weißer Block mit drei Kennzahlen nebeneinander "11 offen", "ca. 3,20 € gespart" (grün) und "640 kcal übrig" (grün), darunter die Zeile "4 von 11 Artikeln diese Woche bei REWE im Angebot, in deiner Region" und die Liste nach Gängen mit Überschriften "Obst und Gemüse 3" und "Milchprodukte 2", Zeilen mit leeren runden Häkchen-Kreisen, kleinen grauen Strichzeichnungen und Artikeln "Bananen", "Cherrytomaten", "Avocados 2", "Hafermilch 2", "Griechischer Joghurt", wobei bei Hafermilch klein steht "1,19 € bei REWE, laut Händler statt 1,79 €" mit grünem Preis. Unten links schwebt über der Liste eine milchig-transparente Liquid-Glass-Kapsel "Artikel hinzufügen" mit Kamera-Symbol und einem schwarzen runden Knopf mit Einkaufswagen, darunter eine schwebende Liquid-Glass-Tab-Leiste mit Symbolen und Beschriftungen "Heute", "Rezepte", "Kalorien", "Bilanz" und rechts daneben ein separater runder Glas-Knopf mit einer kleinen flachen Avocado-Silhouette. Rechts der Einkaufsmodus ohne Tab-Leiste: oben links "Fertig", eine riesige Zahl "7" mit "noch · REWE" und Fortschrittsbalken, große haftende Abschnittsüberschrift "Backwaren 2" und "Getränke 3", hohe Zeilen mit großen runden Häkchen-Kreisen und Mengen rechts in großen Ziffern ("Vollkornbrot 1", "Brezeln 4", "Mineralwasser 6", "Apfelschorle 2", "Kaffeebohnen 1"), eine Zeile gerade abgehakt mit schwarz gefülltem Kreis, weißem Haken und grau durchgestrichenem Text, darunter eingeklappt "Im Wagen 11", und unten eine Liquid-Glass-Leiste mit kleinem Avatar "L" und "Lena kauft auch ein" sowie einer schwarzen Kapsel "Einkauf beenden" mit weißer Schrift.
