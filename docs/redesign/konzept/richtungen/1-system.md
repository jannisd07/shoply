# Richtung 1: "Vorinstalliert"

Stand: 07.11.2026. Eine von fünf Design-Richtungen für das komplette Redesign. Arbeitsname der App: Avo (austauschbar).

## 1. Name und ein Satz

**Vorinstalliert.** Avo sieht aus, als wäre es mit iOS 27 auf das iPhone gekommen: gruppierte Listen auf Systemgrau, Liquid Glass nur in Tab-Bar und Toolbars, ein neu kalibriertes Avocado-Grün als einzige Handlungsfarbe, und die Marke zeigt sich nur in wenigen, gut gewählten Momenten.

---

## 2. Gefühl

**Emotion:** Ruhe und Vertrauen. Die App fühlt sich an wie ein Werkzeug, das schon immer da war. Man muss nichts lernen, weil alles so funktioniert wie im Rest des iPhones. Freude entsteht durch Präzision: Das Häkchen sitzt, die Liste ist sofort da, nichts ruckelt. Aufregung ist nicht das Ziel.

**Apple-Apps als Haltung (Muster übernehmen, nichts kopieren):**
- **Erinnerungen:** runde Abhak-Kreise, Listenfarbe plus Symbol, Schnelleingabe direkt in der Liste, Abgehaktes rutscht leise weg.
- **Notizen:** sofort tippen können, ohne Formular. Der Inhalt beginnt oben links.
- **Health:** Zusammenfassung zuerst, Details eine Ebene tiefer; ein Diagramm beantwortet genau eine Frage; Zahlen in SF Pro Rounded.
- **Musik:** Titel, darunter eine klare Hauptaktion (wie "Wiedergabe" unter einem Album); das Eingabe-Accessory über der Tab-Bar (wie der Mini-Player).
- **Wallet:** Vertrauen beim Bezahlen. Die Paywall bekommt dieselbe Nüchternheit wie Apple Pay: klare Summe, klare Bedingungen.

Was diese Richtung von den anderen vier unterscheidet: Sie verzichtet auf eine eigene Bildwelt für die Oberfläche. Die Markenidentität steckt in drei Dingen: der Akzentfarbe, den eigenen Artikel-Symbolen und dem "Avo-Kern" (siehe 7).

---

## 3. Fünf Prinzipien

1. **Inhalt unten, Bedienung schwebt.** Listen, Rezepte und Zahlen liegen auf festen Systemflächen. Alles, was man bedient (Tabs, Zurück, Teilen, Hinzufügen), schwebt als Glas darüber. Glas auf Inhalt gibt es nicht, Glas auf Glas auch nicht.
2. **Systemmuster vor Eigenbau.** Gruppierte Listen, Wischaktionen, Kontextmenüs, Sheets mit Teilhöhe, große Titel, die beim Scrollen einklappen. Ein eigenes Muster ist nur erlaubt, wenn es nachweisbar besser ist (Einkaufsmodus, Avo-Sprachmodus).
3. **Grün heißt: hier passiert etwas.** Die Akzentfarbe steht nur auf antippbaren Dingen und auf dem Häkchen. Alles andere ist Grau, Schwarz oder Weiß. Inhalte (Rezeptfotos, Artikel) sind das Bunte.
4. **Fließt mit jeder Schrift und jeder Breite.** Kein Text in einer festen Höhe. Jede Zeile wächst mit Dynamic Type bis AX5, jede Ansicht funktioniert ab 320 pt Breite (Anzeigezoom "Größerer Text"). Wenn es eng wird, bricht der Inhalt um, statt abgeschnitten zu werden.
5. **Marke in Momenten, Ehrlichkeit immer.** Das Maskottchen erscheint bei Begrüßung, leeren Zuständen und Erfolgen, sonst nie. Jede Zahl ist echt und belegt: Angebote "in deiner Region", "statt"-Preise "laut Händler", keine erfundenen Statistiken.

---

## 4. Farben

Grundlage sind die iOS-Systemfarben (gruppierte Hintergründe, Label-Stufen). Neu ist nur die Akzentfarbe. Alle Werte sind adaptiv, hell und dunkel. Kontrastwerte nach WCAG gemessen.

### Flächen und Text

| Rolle | Hell | Dunkel | Hinweis |
|---|---|---|---|
| Hintergrund (gruppiert) | `#F2F2F7` | `#000000` | Basis jedes Screens |
| Fläche (Sektion, Zeile, Karte) | `#FFFFFF` | `#1C1C1E` | Trennung über Tonstufe, nie über Schatten |
| Fläche 2 (Feld, Chip, Nutzer-Blase) | `#E9E9EE` | `#2C2C2E` | Eingabefelder in Inhalten, Segmente |
| Trennlinie in Sektionen | `#C6C6C8` | `#38383A` | Nur zwischen Zeilen einer Sektion, eingerückt ab dem Text |
| Text primär | `#000000` | `#FFFFFF` | Auch für Fließtext und Rezeptschritte |
| Text sekundär | `#6C6C70` | `#98989F` | Nur Metadaten (Menge, "von Lena", Uhrzeit). 5,2:1 auf Weiß, 5,9:1 auf `#1C1C1E` |
| Text tertiär / Platzhalter | `#AEAEB2` | `#636366` | Leerer Abhak-Kreis, Platzhalter im Feld |

### Akzent und Status

| Rolle | Hell | Dunkel | Hinweis |
|---|---|---|---|
| **Akzent "Avocado"** | `#3F7A1F` | `#A6D45F` | Hell: Schale (5,2:1 auf Weiß, auch als Textfarbe nutzbar). Dunkel: Fruchtfleisch (9,9:1 auf `#1C1C1E`). Bewusst gelblicher und tiefer als Systemgrün `#34C759`, damit es nicht wie Standard-iOS aussieht |
| Text auf Akzent | `#FFFFFF` | `#0E1A06` | Gefüllte Buttons. Dunkel: dunkler Text auf hellem Grün (10,4:1) |
| Akzent-Fläche (gewählte Zeile, Pro-Marke) | `#E9F1DC` | `#25301A` | Nur als Hinterlegung, nie als Kartenfarbe |
| Erfolg | `#3F7A1F` | `#A6D45F` | Absichtlich identisch mit dem Akzent. Ein zweites Grün würde mit dem Akzent konkurrieren |
| Warnung | `#A85400` | `#FF9F0A` | Allergie-Hinweis, Offline, fehlende PLZ. 5,3:1 auf Weiß |
| Fehler / Löschen | `#D70015` | `#FF6961` | Destruktive Aktionen, Fehlermeldungen |
| **Angebot und Ersparnis** | Etikett `#FFD60A`, Text darauf `#1C1C1E` | Etikett `#FFD60A`, Text darauf `#1C1C1E` | Das gelbe Preisschild kennt jeder aus dem deutschen Supermarkt. Gelb steht nur als Füllung eines kleinen Etiketts, nie als Textfarbe (12:1). Die Ersparnis-Zeile selbst steht in Text primär mit `tag`-Symbol. Schaltet man das Modul ab, verschwindet Gelb vollständig aus der App |

### Listenfarben

Jede Liste hat eine Farbe und ein SF Symbol, wie in Erinnerungen. Die Farbe färbt **nur** den runden Listen-Glyph (28 pt Kreis mit weißem Symbol) und im Widget den Titel. Häkchen bleiben in allen Listen Akzentgrün, damit "erledigt" überall gleich aussieht.

| Name | Hell | Dunkel |
|---|---|---|
| Avocado | `#3F7A1F` | `#8DC24A` |
| Rot | `#FF3B30` | `#FF453A` |
| Orange | `#FF9500` | `#FF9F0A` |
| Gelb | `#FFCC00` | `#FFD60A` |
| Minze | `#00C7BE` | `#63E6E2` |
| Blau | `#007AFF` | `#0A84FF` |
| Indigo | `#5856D6` | `#5E5CE6` |
| Lila | `#AF52DE` | `#BF5AF2` |
| Rosa | `#FF2D55` | `#FF375F` |
| Braun | `#A2845E` | `#AC8E68` |
| Graphit | `#8E8E93` | `#98989D` |

Die heutigen Listen-Hintergründe (Verläufe, Bilder) gehen in Listenfarbe und Symbol auf. Die Daten in Supabase bleiben unberührt.

### Markt-Chips

Echte Supermarkt-Logos nur mit Erlaubnis. Bis dahin ist der Markt-Chip eine Kapsel in Fläche 2 mit einem 8-pt-Punkt in der Markenfarbe und dem Namen in Subheadline: Lidl `#0050AA`, REWE `#CC071E`, Aldi Süd `#00005F`, Aldi Nord `#00549F`, Edeka `#FFD400`, Kaufland `#E10915`, Netto `#FFE500`, PENNY `#CD1414`. Der Punkt ist das einzige Markenzeichen, die Schrift bleibt Systemschrift.

### Zugänglichkeit

- **Erhöhter Kontrast:** Akzent hell `#2E5C14` (7,9:1), Text sekundär hell `#3C3C43`, Trennlinien dunkler. Glas bekommt einen sichtbaren Rand.
- **Reduzierte Transparenz:** Glas wird zur festen Fläche (`#F9F9F9` hell, `#1C1C1E` dunkel).
- Farbe ist nie die einzige Information: Abgehakt = gefüllter Kreis plus Häkchen plus durchgestrichener Text; Angebot = Etikett mit Preis; Fehler = Symbol plus Text.

---

## 5. Typografie

Nur die Systemschrift: **SF Pro** (Text und Display schaltet iOS optisch selbst um), dazu **SF Pro Rounded** ausschließlich für Zahlen, die man liest wie eine Anzeige (Mengen, Preise, kcal, Fortschritt). So hat Health es vorgemacht. Keine Serifen, keine eigenen Schriften, keine Großbuchstaben-Zeilen über Überschriften.

Die Skala ist Apples Dynamic-Type-Skala in der Standardgröße "Large". Laufweite und Zeilenhöhe kommen aus Apples Tabelle, nicht frei gewählt.

| Stil | Größe / Zeile | Gewicht | Laufweite | Verwendung |
|---|---|---|---|---|
| Großer Titel | 34 / 41 | Bold | +0,40 | Screen-Titel ("Wocheneinkauf", "Rezepte") |
| Titel 1 | 28 / 34 | Bold | +0,38 | Rezeptname, Paywall-Titel |
| Titel 2 | 22 / 28 | Bold | -0,26 | Sprachmodus-Transkript, Einkaufsmodus-Gang |
| Titel 3 | 20 / 25 | Semibold | -0,45 | Artikel im Einkaufsmodus |
| Überschrift | 17 / 22 | Semibold | -0,43 | Sektionstitel (Gänge, "Zutaten"), Zeilentitel mit Gewicht |
| Fließtext | 17 / 22 | Regular | -0,43 | Artikelnamen, Rezeptschritte, Avo-Antworten |
| Hervorgehoben | 16 / 21 | Regular | -0,31 | Ersparnis-Zeile, Hinweise |
| Unterzeile | 15 / 20 | Regular | -0,23 | Metadaten, Markt-Chip, Button-Beschriftung klein |
| Fußnote | 13 / 18 | Regular | -0,08 | Quellen ("laut Händler", "Foto: Open Food Facts"), Sektionsfuß |
| Beschriftung 1 | 12 / 16 | Regular | 0 | Tab-Beschriftung, Zeitstempel |
| Beschriftung 2 | 11 / 13 | Semibold | +0,06 | Pro-Marke |
| Zahl groß | 34 / 41 | Rounded Bold | 0 | "640 kcal übrig", Fortschritt im Einkaufsmodus |
| Zahl | 17 / 22 | Rounded Semibold | 0 | Mengen ("2"), Preise ("0,99 €") |

Regeln:
- **Hierarchie aus Gewicht vor Größe.** Ein Screen nutzt höchstens drei Stile gleichzeitig sichtbar.
- **Sektionstitel** im iOS-26-Stil: gemischte Schreibweise, Überschrift-Stil, Text primär. Keine kleinen grauen Großbuchstaben.
- **Dynamic Type bis AX5.** Ab den Bedienungshilfen-Größen stapeln Zeilen: Die Menge rutscht unter den Namen, Markt-Chips brechen um, Tab-Beschriftungen werden ausgeblendet und per Langdruck im Large Content Viewer gezeigt. In Flutter heißt das: `MediaQuery.textScalerOf` überall durchreichen, keine `SizedBox(height:)` um Text, Zeilenlayout mit `Wrap` bzw. umschaltbarem `Row`/`Column` ab einer Schwelle.
- **Fetter Text** (Bedienungshilfe) wird durch die Systemschrift automatisch übernommen. Eigene Gewichte heben sich dann um eine Stufe an.

---

## 6. Material und Form

### Liquid Glass: wo genau

| Element | Glas | Bemerkung |
|---|---|---|
| Tab-Bar | ja | Schwebende Kapsel, minimiert sich beim Herunterscrollen auf das aktive Symbol |
| Eingabe-Accessory "Artikel hinzufügen" | ja | Sitzt über der Tab-Bar, verschmilzt beim Minimieren mit ihr in einer Zeile (Muster: Musik-Mini-Player) |
| Toolbar-Buttons oben (Zurück, Teilen, Menü, Profil) | ja | Kreise 44 pt, gruppierte Buttons teilen sich eine Kapsel |
| Menüs und Kontextmenüs | ja | Wachsen aus dem auslösenden Button |
| Sheets in Teilhöhe | ja | Schweben mit 8 pt Abstand zum Rand; bei voller Höhe werden sie fest |
| Avo-Eingabe und Sprachmodus-Steuerung | ja | Unten schwebend |
| Einkaufsmodus-Leiste "Fertig" | ja | Einziger schwebender Button im Einkaufsmodus |
| Listen, Zeilen, Karten, Rezeptbilder, Diagramme | **nein** | Feste Systemflächen |

Weitere Regeln:
- **Kein Glas auf Glas.** Ein Menü aus der Tab-Bar ersetzt die Tab-Bar optisch, es liegt nicht darauf.
- **Getöntes Glas** (Akzent) nur für die jeweils eine Hauptaktion einer Bedienebene, z. B. "Fertig" im Einkaufsmodus.
- **Scroll-Edge-Effekt** statt Trennlinie: Wo Inhalt unter Glas läuft, blendet ein weicher Verlauf aus der Hintergrundfarbe (oben 24 pt, unten 40 pt) den Inhalt aus. Keine Linie unter der Navigationsleiste.
- **Höchstens drei native Glas-Views pro Screen** (Platform Views kosten Leistung, siehe 12).

### Radien (konzentrisch)

| Element | Radius | Begründung |
|---|---|---|
| Sheet in Teilhöhe | Geräteradius minus 8 pt (Fallback 47 pt) | Konzentrisch zur Geräteecke |
| Sektion (gruppierte Liste) | 26 pt | iOS-26-Wert für inset-gruppierte Listen |
| Bild in einer Zeile (Rezept-Thumbnail 56 pt) | 12 pt | 26 minus Innenabstand, wirkt konzentrisch |
| OFF-Produktfoto in Zeile (36 pt) | 8 pt | |
| Rezeptbild in Rezepte-Tab (volle Breite in Sektion) | oben 26 pt, unten 0 | Teilt sich die Ecke mit der Sektion |
| Buttons, Chips, Felder, Etiketten | Kapsel (Höhe / 2) | iOS-26-Standard |
| Abhak-Kreis | Kreis 24 pt (Einkaufsmodus 32 pt) | |

### Raster und Tiefe

- Seitenrand 16 pt (ab 430 pt Breite 20 pt). Sektionsabstand 32 pt, Innenabstand der Zeile 16 pt horizontal, 11 pt vertikal.
- Mindesthöhe jeder Zeile 44 pt, im Einkaufsmodus 64 pt. Höhen sind Mindestwerte, nie feste Werte.
- **Tiefe kommt nur aus drei Ebenen:** Hintergrund, Fläche, Glas. Inhalte haben keine Schatten. Das Glas bringt seine eigene, systemgesteuerte Tiefe mit.

---

## 7. Ikonografie, Artikelbilder, Fotos, Maskottchen

**SF Symbols** für die gesamte Bedienung, im Rendering-Modus "hierarchisch", Gewicht passend zum danebenstehenden Text. Symbole stehen frei, ohne getönte Quadrate oder Kreise dahinter. Einzige Ausnahme ist der Listen-Glyph (Kreis in Listenfarbe), weil er Inhalt ist und Erinnerungen das so etabliert hat.

**Artikelbilder: "Avo Symbols".** Ein eigenes Set aus etwa 30 Kategorie-Symbolen und 200 Artikel-Symbolen (Milch, Bananen, Brötchen, Eier ...), gezeichnet auf dem SF-Symbols-Raster mit denselben Strichstärken und drei Gewichten. Es wird als echte SF-Symbol-Vorlage (`.svg` aus der SF-Symbols-App) exportiert. Vorteile:
- Sieht neben Systemsymbolen nativ aus und skaliert mit Dynamic Type.
- Läuft unverändert in Widgets, Siri-Antworten und im Control Center.
- Monochrom in Text sekundär, im Einkaufsmodus in Text primär. Getönte Widgets färben sie automatisch.
- In Flutter als Icon-Font oder SVG gerendert, also ohne Netzabfrage.

**Produktfotos** von Open Food Facts nur, wenn ein Markenprodukt erkannt oder ein Barcode gescannt wurde: 36 pt, weiße Unterlage, Radius 8 pt. Die Quelle "Foto: Open Food Facts, CC BY-SA" steht im Artikel-Sheet als Fußnote mit Link. Keine Bilder aus Händler-Shops oder Prospekten; Angebote ohne Lizenz zeigen das Avo Symbol der Kategorie.

**Rezeptfotos** sind das Bunteste der App und dürfen groß sein: im Detail randlos oben, im Rezepte-Tab als 4:3-Bild in der Sektion. Nutzerfotos ohne Filter. Fehlt ein Foto, steht dort das Kategorie-Symbol groß auf Fläche 2, kein Platzhalter-Verlauf.

**Maskottchen.** Das heutige 3D-Avo wird neu gezeichnet: flacher, zwei Tonstufen statt Plastik-Glanz, gleiche Proportionen (Avocado-Hälfte, Kern, kurze Ärmchen). Vier Stimmungen reichen: winkend, denkend, feiernd, schlafend (für leere Zustände). Einsatz nur hier:
- Willkommens-Screen im Onboarding (groß, 160 pt).
- Leere Zustände ("Noch keine Liste", "Alles abgehakt"), 96 pt.
- Erfolgsmomente: Einkauf abgeschlossen, Wochenplan auf der Liste, Challenge geschafft (kurz, 1,5 s, dann weg).
- Nie in Toolbars, nie als Tab-Symbol, nie neben jeder Avo-Antwort.

**Der Avo-Kern.** Der Assistent selbst hat kein Gesicht. Er erscheint als runder Kern: eine Kugel in Kern-Braun `#7A4A24` mit einem Ring aus Fruchtfleisch-Grün `#C9DE6E`, die sich mit der Stimme bewegt. Das ist das Symbol für den Avo-Tab (als eigenes Avo Symbol), der Sprachmodus und die Ladeanzeige von Avo. Er ist das wiedererkennbare Markenzeichen dieser Richtung.

---

## 8. Navigation

### Tabs (iOS-26/27-Tab-Bar mit Glas)

| Position | Tab | SF Symbol | Sichtbar, wenn |
|---|---|---|---|
| 1 | **Heute** | `checklist` | immer (Kern) |
| 2 | **Listen** | `list.bullet` | immer (Kern) |
| 3 | **Rezepte** | `fork.knife` | immer (Kern). Der Wochenplan ist ein Segment oben im Rezepte-Tab ("Entdecken / Wochenplan"), wenn das Modul an ist |
| 4 | **Kalorien** | `flame` | nur mit Modul Kalorien |
| abgesetzt rechts | **Avo** | Avo-Kern | nur mit Modul Avo |

- Ohne Module sind es drei Tabs. Mit allen Modulen vier Tabs plus der abgesetzte Avo-Kreis. Das passt auch bei 320 pt Breite; dort zeigt die Tab-Bar nur Symbole, Beschriftungen kommen per Langdruck.
- Ein- und Ausschalten eines Moduls lässt den Tab per Feder ein- oder ausblenden. Der aktive Tab bleibt stehen, die Nachbarn rücken nach.
- **Angebote, Verlauf, Kosten teilen** sind keine Tabs. Sie leben als Sektionen im Tab "Listen" (siehe unten) und in der jeweiligen Liste. Schaltet man ein Modul ab, verschwindet seine Sektion ohne Lücke.

### Avo: genau ein Einstiegspunkt

Der abgesetzte Avo-Kreis rechts in der Tab-Bar ist der einzige Weg zu Avo innerhalb der App. Antippen lässt die Tab-Bar zu einem Eingabefeld "Frag Avo" morphen (Glas-Morph, wie die Suche in iOS 26). Langdruck startet direkt den Sprachmodus. Es gibt keinen Avo-Hinweisstreifen auf der Startseite und keinen zweiten Knopf. Siri, Widgets und der Action Button sind Systemzugänge außerhalb der App und zählen nicht dazu.

Antworten von Avo, die in anderen Screens etwas ändern (z. B. drei Artikel hinzugefügt), zeigen dort keine Avo-Werbung, sondern nur die Änderung mit "Rückgängig".

### Profil und Einstellungen

- Ein runder Avatar-Button (Glas, 44 pt) oben rechts auf jedem Tab-Startscreen, wie im App Store und in Health. Er öffnet ein Sheet in voller Höhe "Profil".
- Das Profil-Sheet ist eine gruppierte Liste mit Suchfeld oben. Reihenfolge: Profilkopf (Avatar, Name), Avo Pro, **Module** (alle Schalter an einem Ort), **Preise & Angebote** (eigener Bereich weit oben, alle Spar-Schalter, Standort/PLZ, Lieblingsmärkte, Markt-Erkennung), Ernährung & Allergien, Mitteilungen, Darstellung (System/hell/dunkel; Akzentfarbe bleibt fest, siehe 12), Sprache, Siri & Kurzbefehle, Widgets, Hilfe, Rechtliches, Abmelden.
- Jede Einstellung ist über die Suche und über Avo erreichbar.

### Tab "Listen"

Gruppierte Liste, von oben:
1. **Meine Listen** (Listen-Glyph, Name, Anzahl offen, rechts Markt-Chip falls gesetzt).
2. **Geteilt mit mir** (zusätzlich Mitglieder-Avatare als Stapel, 20 pt).
3. **Sparen** (nur Modul Angebote): "Angebote der Woche", Zeile mit Zahl "12 passen zu deinen Listen".
4. **Verlauf**: "Einkäufe", "Dein November" (Monatsrückblick), "Offene Beträge" (nur Modul Kosten teilen, mit Summe).
Oben rechts neben dem Avatar ein Glas-Button `plus` für "Neue Liste" und "Liste beitreten" (Menü wächst aus dem Button).

### Wayfinding und Onboarding

- Jeder Screen hat einen großen Titel (wo bin ich), Glas-Buttons oben (was kann ich hier tun), Zurück oben links oder Wischen vom Rand (wie komme ich raus). Sheets schließen per Wischen nach unten oder "Fertig".
- **Onboarding** in fünf Schritten, jeder überspringbar: Willkommen (winkender Avo, "Mit Apple fortfahren"), "Was brauchst du?" (Module als gruppierte Liste mit Schaltern und einem Satz Nutzen; Angebote standardmäßig an), bei Angeboten PLZ und Märkte, Ernährung (optional), erste Liste anlegen mit drei Vorschlägen. Mitteilungen werden erst gefragt, wenn man eine Liste teilt. Die Pro-Testphase erscheint erst nach dem ersten abgeschlossenen Einkauf oder dem ersten Wochenplan.

---

## 9. Signatur-Screens

### Startseite "Heute" (die Liste von heute)

- **Hauptfrage:** Was muss ich als Nächstes kaufen?
- Welche Liste "heute" ist, entscheidet die App: angeheftete Liste, sonst die zuletzt bearbeitete, sonst die Liste, deren Markt man gerade betritt (als Vorschlag). Der große Titel ist der Listenname mit kleinem Chevron, Antippen öffnet ein Menü zum Wechseln.
- Unter dem Titel eine Metazeile: Listen-Glyph, Markt-Chip "Lidl", "11 offen". In geteilten Listen zusätzlich die Mitglieder-Avatare.
- Darunter eine gefüllte Akzent-Kapsel **"Einkauf starten"** (Muster: "Wiedergabe" unter einem Album).
- **Ersparnis-Zeile** (nur Modul Angebote, nur mit echter PLZ): `tag`-Symbol, "4 von 11 Artikeln diese Woche bei Lidl im Angebot · ca. 3,20 € gespart · in deiner Region". Antippen öffnet die Angebote dieser Liste als Sheet in Teilhöhe.
- Artikel als gruppierte Sektionen nach Gang ("Obst & Gemüse", "Milch & Käse", "Backwaren"). Zeile: leerer Abhak-Kreis, Avo Symbol, Name in Fließtext, darunter optional "von Lena" in Unterzeile sekundär, rechts Menge in Rounded ("2") und ggf. das gelbe Etikett "0,99 €".
- Unten eine Sektion **"Vielleicht auch"** mit bis zu drei Vorschlägen aus dem Verlauf ("Milch, kaufst du etwa alle 6 Tage"), als Zeilen mit gestricheltem Plus-Kreis. Antippen setzt den Artikel auf die Liste. Diese Zeilen ersetzen alle heutigen Hinweis-Karten.
- Weitere Tagesinhalte (nur wenn Module an): eine Zeile "Heute im Wochenplan: Ofengemüse mit Feta" und eine Zeile "Noch 640 kcal". Keine Karten, keine Kacheln.
- Unten das Glas-Accessory **"Artikel hinzufügen"**: Kapsel mit `plus`, Platzhalter, rechts `camera` (Foto-Import). Beim Tippen erscheinen darüber Vorschläge aus dem Verlauf als Zeilen; "2 Milch" zeigt sofort "Milch · Menge 2". Mit Modul Angebote unter den Vorschlägen bis zu drei Angebote des Markts der Liste. Das Feld wächst mit der Schrift in der Höhe mit (behebt den abgeschnittenen Text auf dem iPhone 13 Pro).

### Liste im Einkaufsmodus

- **Hauptfrage:** Was fehlt noch im Wagen?
- Gleiche Liste, gleiche Reihenfolge, aber vergrößert: Abhak-Kreise 32 pt, Zeilen mindestens 64 pt, Artikel in Titel 3. Sortiert nach der Gang-Reihenfolge des Markts der Liste. Tab-Bar und Accessory sind weg.
- Oben: großer Titel "Lidl", rechts in Zahl groß "5 von 11", darunter eine dünne Fortschrittslinie in Akzent.
- Geteilte Liste: Zeile oben "Lena kauft auch gerade ein" mit Avatar und Punkt in Akzent. Was Lena abhakt, bekommt ihren Avatar (16 pt) am Kreis und rutscht dann nach unten.
- Abgehakte Artikel rutschen nach 0,6 s in die eingeklappte Sektion "Im Wagen (5)". In dieser Zeit lässt sich das Häkchen per erneutem Tippen zurücknehmen.
- Ein Glas-Button unten, getönt in Akzent: **"Fertig"**. Er öffnet ein Sheet in Teilhöhe: "Wo warst du?" (Markt-Chips, vorausgewählt), "Betrag (optional)", "Kosten teilen" (nur Modul). Danach der feiernde Avo für 1,5 s mit "Einkauf gespeichert" und, wenn zutreffend, "ca. 3,20 € durch Angebote gespart, laut Händler".
- Der Bildschirm bleibt an; das steht einmal als Fußnote beim ersten Start des Modus.

### Rezeptdetail

- **Hauptfrage:** Will ich das kochen, und was brauche ich dafür?
- Randloses Foto oben (4:3), darüber nur Glas-Buttons: Zurück, Merken (`heart`), Teilen, Menü.
- Unter dem Foto auf der Fläche: Name in Titel 1, Metazeile "35 Min · 2 Portionen · 520 kcal" (kcal nur mit Modul Kalorien), Ersteller-Zeile mit Avatar und "Folgen".
- Zwei Buttons nebeneinander: gefüllt **"Zutaten auf Liste"**, grau **"Kochen"**.
- Sektion "Zutaten" mit Portions-Stepper im Kopf. Mengen in Rounded rechts. Angepasste Zutaten stehen direkt in der Zeile ("Haferdrink statt Milch, für dich angepasst") mit "Original zeigen". Ein Allergen steht in Warnung-Orange mit `exclamationmark.triangle` und dem Grund ("enthält Erdnuss").
- Mit Modul Angebote: das gelbe Etikett an den Zutaten, die im Markt der Ziel-Liste im Angebot sind.
- Sektion "Zubereitung": nummerierte Schritte in Fließtext, Timer-Dauern als antippbarer Text in Akzent ("12 Min").
- Nährwerte als eine Zeile mit einem gestapelten Balken (Protein, Kohlenhydrate, Fett in drei Graustufen plus Akzent für Protein) und Zahlen darunter. Danach Varianten, Kommentare, "Ins Tagebuch eintragen" (Modul Kalorien) als einfache Zeilen.

### Avo mit Sprachmodus

- **Hauptfrage:** Was soll Avo für mich tun?
- Avo öffnet als Sheet in voller Höhe über dem aktuellen Tab. Leerer Zustand: Avo-Kern klein, darunter drei Vorschläge als Zeilen ("Milch auf die Liste", "Wochenplan für 2 Personen", "Was kann ich heute noch essen?").
- Nutzer-Nachrichten als Blase in Fläche 2, rechts. Avo antwortet ohne Blase in Fließtext, Ergebnisse als gruppierte Sektion: "3 Artikel zu Wocheneinkauf hinzugefügt" mit den Zeilen und "Rückgängig". Fragt Avo nach ("Welche Liste?"), stehen die Listen als antippbare Zeilen da.
- Löschen nur mit Rückfrage: Avo zeigt eine Sektion mit der Liste und einem roten Button "Liste löschen" und einem grauen "Abbrechen". Im Sprachmodus fragt er zusätzlich hörbar.
- Unten das Glas-Feld "Frag Avo" mit `camera` links und `waveform` rechts.
- **Sprachmodus:** Das Sheet wird ruhig: der Avo-Kern in der Mitte (120 pt), der sich mit der eigenen Stimme und der Antwort bewegt; darüber das Live-Transkript in Titel 2; Avos Antwort erscheint Wort für Wort darunter und wird gesprochen. Unten drei Glas-Buttons: Mikro stumm, Kamera (Essen fotografieren), Beenden (`xmark`). Ergebnis-Sektionen erscheinen auch hier, damit man sieht, was passiert ist.

### Paywall "Avo Pro"

- **Hauptfrage:** Lohnt sich Pro für mich?
- Sheet in voller Höhe auf Hintergrund (gruppiert). Oben App-Icon (64 pt), "Avo Pro" in Titel 1, ein Satz Nutzen in Fließtext.
- Vorteile als gruppierte Sektion, jede Zeile: SF Symbol in Akzent, Titel in Überschrift, eine Zeile Erklärung. Die Sektion ist datengetrieben, damit der Owner später festlegt, was Pro wird. Kommt man über einen kontextuellen Hinweis, steht dieses Feature oben und ist mit Akzent-Fläche hinterlegt.
- Zwei Plan-Zeilen zur Auswahl: "Jährlich, 29,99 €, entspricht 2,50 € im Monat, spart 16 %" (vorausgewählt, Akzent-Häkchen) und "Monatlich, 2,99 €".
- Eine Zeitleiste mit drei Zeilen: "Heute: alles freigeschaltet", "Tag 12: Erinnerung per Mitteilung", "Tag 14: Abo beginnt".
- Gefüllte Akzent-Kapsel **"14 Tage gratis testen"**, darunter in Fußnote "Danach 29,99 € pro Jahr. Jederzeit in den Einstellungen kündbar." und die Links "Käufe wiederherstellen · Bedingungen · Datenschutz".
- Kein Countdown, kein durchgestrichener Fantasiepreis, kein Schließen-Kreuz, das erst nach Sekunden erscheint.
- **Pro-Kennzeichnung überall:** eine kleine Kapsel "Pro" in Beschriftung 2, Akzent-Text auf Akzent-Fläche, rechts in der Zeile des Features. **Kontextuelle Hinweise:** eine Fußnote unter der betroffenen Sektion ("Mit Pro plant Avo die ganze Woche") mit Link zur Paywall. Gesperrte Funktionen sind sichtbar und antippbar, sie öffnen die Paywall mit diesem Feature oben. Der Kern bleibt immer frei.

### Widget

- **Liste (klein):** Listen-Glyph und Name, "7 offen" in Zahl groß, die nächsten drei Artikel.
- **Liste (mittel):** Name und Markt-Chip, fünf Artikel mit Abhak-Kreisen, direkt im Widget abhakbar (App Intent). Rechts oben `plus` für Schnell hinzufügen.
- **Liste (groß):** bis zu zwölf Artikel nach Gang gruppiert, Gang-Namen in Überschrift.
- **Weitere Typen:** Schnell hinzufügen, Wochenplan (heute und morgen), Rezept (gemerkt oder Vorschlag), Kalorien und Wasser (Modul), Angebote der eigenen Liste (Modul, nur mit Lizenz).
- **Sperrbildschirm:** rechteckig ("Wocheneinkauf · 7 offen" plus zwei Artikel), rund (Fortschrittsring), inline ("7 offen bei Lidl"). Dazu StandBy und Control-Center-Buttons "Artikel hinzufügen" und "Liste öffnen".
- **Darstellungen:** Hintergrund Fläche (hell `#FFFFFF`, dunkel `#1C1C1E`). Im getönten und klaren Modus sind Abhak-Kreise und Titel als akzentfähig markiert, Avo Symbols sind Vorlagen und färben sich mit. Konfigurierbar: Liste, Erledigtes zeigen, nach Gang gruppieren.

---

## 10. Bewegung und Haptik

### Federn

| Situation | Dämpfung | Antwort |
|---|---|---|
| Standard (Zeilen, Tabs ein/aus, Morph der Tab-Bar zu "Frag Avo") | 1,0 | 0,35 s |
| Abhak-Kreis füllt sich | 1,0 | 0,25 s |
| Abgehakte Zeile rutscht nach "Im Wagen" | 1,0 | 0,4 s (nach 0,6 s Wartezeit) |
| Sheet öffnen/schließen ohne Wurf | 1,0 | 0,4 s |
| Sheet nach Wischen/Wurf, Zeile nach Wischaktion | 0,8 | 0,35 s, mit Wurfgeschwindigkeit |
| Menü wächst aus dem Button | 1,0 | 0,3 s, Ursprung am Button |

- Jede Bewegung ist unterbrechbar und startet vom aktuellen Wert. Ein halb geöffnetes Sheet lässt sich greifen und zurückwerfen.
- Gesten folgen dem Finger 1:1: Wischaktionen auf Zeilen, Sheets, Umsortieren nach Langdruck, Wechsel der Wochenplan-Tage.
- Herkunft am Auslöser: Das Accessory wird zum Eingabefeld, der Avo-Kreis zum "Frag Avo"-Feld, der Listen-Titel zum Wechsel-Menü.
- **Avo-Kern** folgt direkt der Lautstärke von Mikrofon und Sprachausgabe. Im Ruhezustand steht er still, keine Endlos-Animation.
- **Erfolgsmoment** (feiernder Avo): Skalierung aus 0,9 mit Dämpfung 0,8, nach 1,5 s Ausblenden. Nur einmal pro Einkauf.
- Kein sichtbares Laden: Listen kommen aus dem lokalen Stand, neue Daten blenden sich ohne Layout-Sprung ein. Wo Avo arbeitet, dreht sich nicht ein Spinner, sondern der Kern "atmet" in der Antwortzeile.

### Haptik (gleichzeitig mit dem Bild)

| Moment | Haptik |
|---|---|
| Artikel abhaken | leichter Impuls |
| Einkauf abgeschlossen, Wochenplan auf Liste, Kauf erfolgreich | Erfolg |
| Fehler (offline, Kauf fehlgeschlagen) | Fehler |
| Zeile rastet beim Umsortieren ein, Stepper-Schritt | Auswahl |
| Sprachmodus beginnt zuzuhören | leichter Impuls |

Sonst keine Haptik: nicht beim Scrollen, nicht beim Tab-Wechsel, nicht bei jedem Tippen.

### Bedienungshilfen

- **Reduce Motion:** Alle Verschiebungen werden zu Überblendungen (0,2 s), der Morph der Tab-Bar ebenso. Der Avo-Kern zeigt Lautstärke nur über Helligkeit, nicht über Größe. Der Erfolgsmoment blendet nur ein.
- **Reduce Transparency:** Glas wird fest (siehe 4).
- **VoiceOver:** Jede Artikelzeile ist ein Element: "Milch, Menge 2, im Angebot 0,99 Euro laut Händler, nicht erledigt". Abhaken per Doppeltipp, Bearbeiten und Löschen als benutzerdefinierte Aktionen. Tabs haben die Tab-Rolle. Der Sprachmodus kündigt "Avo hört zu" an.

---

## 11. App-Icon "Die Hälfte"

Eine aufgeschnittene Avocado-Hälfte von vorn, mittig, ohne Gesicht und ohne Zettel. Der Kern sitzt etwas unterhalb der Mitte, genau wie ein Abhak-Kreis in einer Zeile: rund, satt, fertig. Gebaut in der Icon Composer-App in drei Ebenen (Hintergrund, Fruchtfleisch mit Schale, Kern), damit iOS die Glas-Eigenschaften und alle Erscheinungen selbst rendert.

| Erscheinung | Gestaltung |
|---|---|
| **Hell** | Hintergrund sanfter Verlauf `#F3F6DF` nach `#E3ECB8`. Schale als Rand `#3F7A1F`, Fruchtfleisch `#D8E77E` nach `#C3D867` zur Schale hin. Kern `#7A4A24` mit einem weichen Glas-Glanz oben links |
| **Dunkel** | Hintergrund `#0E1508` nach `#16210D`. Schale `#5E8F2E`, Fruchtfleisch gedimmt `#A9C459`, Kern `#8A5A30`. Der Kern bleibt das hellste Glanzlicht |
| **Klar** | Alle drei Ebenen werden Glas. Die Form liest sich über die Kantenlichter der Schale und den deutlich dichteren Kern. Hintergrund transparent |
| **Getönt** | Die Ebenen werden in Helligkeit übersetzt: Hintergrund dunkel, Fruchtfleisch mittel, Kern hell. So bleibt die Hälfte mit Kern in jeder Tönung erkennbar |

Das Maskottchen steckt nicht im Icon. Das hält das Icon erwachsen und lässt Avo als Figur für die Momente in der App.

---

## 12. Stärken, Risiken, Aufwand und Performance in Flutter

### Stärken

- **Vertrauen auf den ersten Blick.** Die App wirkt wie ein Teil des iPhones. Das hilft bei der Bereitschaft, ein Abo abzuschließen, und bei der App-Store-Präsentation.
- **Beste Zugänglichkeit** der fünf Richtungen: Systemfarben, Systemschrift und Systemmuster bringen Dynamic Type, Kontrast und VoiceOver fast mit. Der 320-pt-Fall und der Fehler in der Eingabeleiste werden durch das Prinzip "keine festen Höhen" grundsätzlich gelöst.
- **Module fügen sich ohne Lücke ein.** Weil alles gruppierte Zeilen und Sektionen sind, verschwindet ein abgeschaltetes Modul (z. B. Angebote per Kill-Switch) spurlos.
- **Altert gut.** Neue iOS-Versionen verändern Systemflächen und Glas; die App zieht mit, statt veraltet auszusehen.
- **Geringster Aufwand** der fünf Richtungen, weil die meisten Bausteine Systembausteine sind.

### Risiken

- **Verwechselbarkeit.** "Sieht aus wie Erinnerungen" kann als austauschbar gelten. Gegenmittel: Akzentgrün, Avo Symbols, Avo-Kern, gelbes Preisschild, sorgfältige Erfolgsmomente. Ohne diese vier Dinge wird die Richtung blass.
- **Wenig Spielraum für Gefühl.** Die Paywall und das Onboarding müssen über Klarheit und Handwerk überzeugen, nicht über Bildwelt. Das verlangt sehr gute Texte.
- **Avo Symbols sind echte Gestaltungsarbeit** (etwa 230 Symbole in drei Gewichten). Bis sie fertig sind, braucht es eine Übergangslösung: SF Symbols der Kategorie (`carrot`, `fish`, `birthday.cake`, `waterbottle` ...).
- **Feste Akzentfarbe.** Die heutige Einstellung "Akzentfarbe wählen" fällt weg oder wird auf eine Auswahl der Listenfarben für die eigene Standard-Liste reduziert. Das braucht eine Entscheidung.
- **Listen-Hintergründe** (Bilder, Verläufe) verschwinden als sichtbares Feature. Wer sie heute nutzt (laut Inventar unsichtbar, also faktisch niemand), verliert nichts.

### Aufwand und Umsetzung in Flutter

- **Tab-Bar und Glas:** `adaptive_platform_ui` liefert die native iOS-26-Tab-Bar und Glas-Buttons; `LiquidGlassViewFactory.swift` deckt Kapseln und Gruppen ab. Das abgesetzte Avo-Element und der Morph zu "Frag Avo" sind der aufwendigste Teil der Shell. Wenn der native Morph nicht gelingt, ist eine Überblendung zwischen zwei Glas-Formen der Fallback.
- **Eingabe-Accessory über der Tab-Bar:** natives Muster existiert in UIKit/SwiftUI, in Flutter muss es nachgebaut werden. Plan: Flutter-Layout mit einer nativen Glas-Kapsel als Hintergrund, Textfeld in Flutter, Höhe aus der Textgröße berechnet (nicht nach dem Frame gemessen).
- **Gruppierte Listen und große Titel:** `CupertinoSliverNavigationBar` und eigene `InsetSection`-Widgets mit den Tokens aus 4 bis 6. Flutters `CupertinoListSection` hat noch iOS-15-Radien; eigene Komponente nötig, einmal gebaut für alle Screens.
- **Tokens:** `AppColors`, `AppDimensions`, `AppTextStyles` werden die einzigen Quellen; `PaperColors`, `PaperTextStyles`, `design_system.dart` und die Paper-Bausteine fallen weg. SF Pro Rounded über `fontFamily: '.SF Pro Rounded'` bzw. die iOS-Systemschrift-Variante prüfen; Fallback SF Pro mit tabellarischen Ziffern.
- **Performance auf dem iPhone 13 Pro:**
  - Platform Views (natives Glas) höchstens drei pro Screen und nie in scrollenden Zeilen. Jede Platform View kostet Komposition pro Frame.
  - Kein `BackdropFilter` in Listen. Der Scroll-Edge-Effekt ist ein einfacher Farbverlauf, keine Unschärfe.
  - Gruppierte Zeilen ohne Schatten und ohne Transparenz sind billig zu rendern; das ist der große Vorteil dieser Richtung.
  - Avo Symbols als Icon-Font: keine Bild-Dekodierung beim Scrollen. OFF-Fotos nur gecacht und klein.
  - Ziel: unter 16 ms pro Frame beim Scrollen und Abhaken, gemessen im Profile-Modus.
- **Grobe Einschätzung:** kleinster Aufwand der fünf Richtungen. Shell und Komponenten etwa ein Drittel der Arbeit, die Screens zwei Drittel, die Avo Symbols laufen parallel als Gestaltungsaufgabe.

---

## 13. Bildzeile für ChatGPT

Zwei iPhone-17-Pro-Mockups nebeneinander im hellen Modus, gestaltet wie eine vorinstallierte Apple-App aus iOS 27 (Familie Erinnerungen und Health): Hintergrund `#F2F2F7`, weiße inset-gruppierte Sektionen mit 26 pt Eckenradius, SF Pro, schwarzer Text, sekundärer Text `#6C6C70`, einzige Akzentfarbe ein tiefes Avocado-Grün `#3F7A1F`, keine Schatten auf Inhalten und Liquid Glass nur in der schwebenden Tab-Bar und den runden Toolbar-Buttons. Links die Startseite "Heute": großer fetter Titel "Wocheneinkauf" mit kleinem Chevron, darunter eine Metazeile mit grünem Listenkreis, einer grauen Kapsel "● Lidl" mit blauem Punkt `#0050AA` und "11 offen", darunter eine gefüllte grüne Kapsel "Einkauf starten" mit weißer Schrift und eine Zeile mit Etikett-Symbol "4 von 11 Artikeln diese Woche bei Lidl im Angebot · ca. 3,20 € gespart · in deiner Region"; dann Sektionen "Obst & Gemüse" (Bananen, 2 Avocados, Cherrytomaten), "Milch & Käse" (Milbona Frische Vollmilch mit kleinem gelbem Preisschild `#FFD60A` "0,99 €", Gouda in Scheiben "von Lena") und "Vielleicht auch" mit einem gestrichelten Plus-Kreis "Haferflocken, kaufst du etwa alle 10 Tage", jede Zeile mit leerem grauem Abhak-Kreis, kleinem monochromem Linien-Symbol des Artikels und der Menge in abgerundeten Ziffern rechts. Ganz unten schwebt eine milchig-transparente Glas-Kapsel "Artikel hinzufügen" mit Plus und Kamera über einer schwebenden Glas-Tab-Bar mit "Heute", "Listen", "Rezepte" und abgesetzt rechts einem runden Glas-Knopf mit einer kleinen braunen Kugel `#7A4A24` in grünem Ring `#C9DE6E` (der Assistent Avo), oben rechts ein runder Glas-Avatar-Button. Rechts dieselbe Liste im Einkaufsmodus ohne Tab-Bar: großer Titel "Lidl", rechts groß "5 von 11" in abgerundeten Ziffern mit dünner grüner Fortschrittslinie, darunter eine Zeile mit kleinem Avatar "Lena kauft auch gerade ein", große Zeilen mit 32-pt-Kreisen und Artikeln in 20 pt Semibold (Brokkoli, Spaghetti, Passierte Tomaten, Butter, Eier Größe M), zwei davon mit gefülltem grünem Kreis und weißem Häkchen und durchgestrichen, eine eingeklappte Sektion "Im Wagen (5)" und unten mittig ein grün getönter Glas-Button "Fertig". Ruhig, präzise, viel Luft, keine Großbuchstaben-Überschriften, keine Karten-Kacheln, kein Maskottchen auf diesen beiden Screens.
