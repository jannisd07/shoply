# Richtung 3: Glas und Tiefe

Arbeitsname der App: Avo (austauschbar). Diese Datei beschreibt eine von fünf Design-Richtungen. Sie gilt nur, wenn diese Richtung gewählt wird.

---

## 1. Name und ein Satz

**Farbraum.** Jede Liste ist ein eigener Raum in ihrer Farbe: ein ruhiger, tiefer Hintergrund wie der Himmel in Wetter oder das Albumlicht in Musik, darauf liegen opake, gut lesbare Inhalte, und darüber schwebt eine Glasebene, die die Farbe des Raums aufnimmt.

---

## 2. Gefühl

**Emotion:** Ankommen und Überblick. Man öffnet die App und ist sofort "in" seiner Liste, erkennt sie an ihrer Farbe, bevor man ein Wort gelesen hat. Ruhig, warm, ein wenig festlich, nie laut. Beim Einkaufen soll es sich anfühlen, als würde der Raum heller, je weiter man kommt.

**Apple-Apps als Haltung (nichts kopieren):**
- **Wetter:** Jeder Ort hat seinen eigenen Himmel, man wischt zwischen Orten. Bei uns: Jede Liste hat ihren eigenen Raum, man wechselt zwischen Listen.
- **Musik (Jetzt läuft):** Die Farbe des Covers füllt den Hintergrund. Bei uns: Das Rezeptfoto färbt den Raum des Rezepts.
- **Erinnerungen:** Listenfarben als Identität, die Häkchen nehmen die Listenfarbe an.
- **Fitness:** Kennzahlen in gerundeter Schrift, Ringe als einzige Datenreihe, Erfolgsmomente mit Gewicht.
- **Wallet:** Tiefe durch geschichtete Ebenen, ein Hauptobjekt pro Screen.

---

## 3. Fünf Prinzipien

1. **Drei Ebenen, nie vermischt.** Raum (Atmosphäre, ganz hinten) – Blatt (opake Inhalte) – Glas (schwebende Bedienung). Text steht nur auf dem Blatt oder, als einzelner großer Titel, direkt im Raum. Glas trägt nie Inhalte, Inhalte sind nie aus Glas.
2. **Farbe ist Ort.** Die Listenfarbe sagt "wo bin ich". Pro Screen gibt es genau eine Aktionsfarbe: außerhalb von Listen Avocado, innerhalb einer Liste die Listenfarbe. Der Raum ist in Hell blass und in Dunkel tief, nie knallig.
3. **Fortschritt ist Licht.** Zustände werden als Licht im Raum gezeigt statt mit zusätzlichen Balken oder Zahlen: Je mehr im Einkaufsmodus abgehakt ist, desto heller steigt das Licht im Raum. Ruhezustand ist immer still: keine Schleifen-Animationen, keine Partikel.
4. **Glas morpht, Inhalte bleiben.** Wechsel von Modus und Ebene passieren in der Glasebene (Tab-Bar wird zum Einkaufsmodus-Werkzeug, der Avo-Knopf wird zum Avo-Sheet). Inhalte springen nicht, sie bleiben an ihrem Ort.
5. **Lesbar zuerst, schön danach.** Jede Kombination aus Raum, Blatt und Text erfüllt mindestens 4,5:1 Kontrast, auch bei 320 pt Breite, AX-Schriftgrößen, fettem Text, Reduce Transparency und erhöhtem Kontrast. Wenn Atmosphäre und Lesbarkeit kollidieren, gewinnt Lesbarkeit und der Raum wird flacher.

---

## 4. Farben

Alle Farben sind adaptiv. Kontrastwerte geprüft gegen die jeweilige Blatt-Fläche (Weiß bzw. #141716).

### 4.1 Neutrale Palette

| Rolle | Hell | Dunkel | Hinweis |
|---|---|---|---|
| Neutraler Raum (ohne Liste) oben → unten | #EEF2EF → #F5F7F6 | #0C120F → #000000 | Rezepte, Kalorien, Profil |
| Blatt (Fläche für Inhalte) | #FFFFFF | #141716 | Alle Abschnitte, Zeilen, Karten |
| Blatt erhöht (Sheets, Eingabefelder im Blatt) | #F7F8F8 | #1E2220 | |
| Tonstufe (Trennung über Fläche statt Linie) | #ECEFEE | #262B29 | Segment-Hintergründe, gedrückte Zeile |
| Zeilentrenner (eingerückt, nur innerhalb eines Abschnitts) | #E3E7E5 | #2A302D | |
| Text primär | #0B0F0D | #F4F7F5 | Auch Fließtext, nie blassgrau |
| Text sekundär | #4A524E | #B4BDB8 | Unterzeilen, Metadaten (ca. 8:1 bzw. 9:1) |
| Text tertiär | #7A827E | #7F8984 | Nur Platzhalter und Deaktiviertes |
| Akzent (Aktionen außerhalb von Listen) | #2F7A4A | #6BD08F | "Avocado", 5,1:1 auf Weiß |
| Erfolg | #1E8E3E | #5BD57A | Nur Bestätigungen, nie als Aktionsfarbe |
| Warnung | #B25E00 | #FFB340 | |
| Fehler / Löschen | #D70015 | #FF6961 | |
| Angebot-Chip Fläche / Text | #FFE45C / #3D3000 | #3A3205 / #FFE066 | "Prospekt-Gelb", nur im Angebots-Modul |
| Ersparnis-Betrag (Text) | #7A5C00 | #FFD84D | "ca. 3,20 € gespart" |

Pro bekommt keine eigene Farbe. Pro-Flächen nutzen den Akzent, damit Pro wie ein Teil der App wirkt und nicht wie Werbung.

### 4.2 Listenfarben

Jede Liste wählt eine von acht Farben oder ein eigenes Bild. Die Farbe erzeugt den Raum (Verlauf oben → unten) und ist in der Liste die Aktionsfarbe (Häkchen, Hinzufügen-Knopf, getönter Hauptknopf). Alle Aktionsfarben haben mindestens 4,5:1 auf dem Blatt.

| Name | Aktion hell | Aktion dunkel | Raum hell (oben → unten) | Raum dunkel (oben → unten) |
|---|---|---|---|---|
| Avocado | #2F7A4A | #6BD08F | #DDEFE3 → #F3F7F4 | #0F2E1C → #050A07 |
| Lagune | #0E7490 | #5CC8E0 | #D6EEF3 → #F2F7F8 | #0B2A33 → #04090B |
| Ozean | #2F5BD3 | #7EA2FF | #DCE5FB → #F3F5FA | #101F4A → #05070F |
| Pflaume | #7A4FCF | #B79BFF | #E7DFF8 → #F5F3FA | #23164A → #08060F |
| Beere | #C23B6E | #FF8AB5 | #F7DDE7 → #FAF3F5 | #3A1024 → #0D0508 |
| Mandarine | #C2410C | #FF9A62 | #FBE3D3 → #FAF5F1 | #3D1A08 → #0D0704 |
| Kakao | #7A4E2D | #D9A57B | #EFE3D8 → #F7F4F1 | #2E1D12 → #0A0705 |
| Schiefer | #4B5563 | #B6BECB | #E3E6EA → #F4F5F6 | #1D2229 → #07080A |

**Eigenes Bild als Raum:** Das Bild wird stark weichgezeichnet (Radius ca. 60), in Hell auf mindestens 85 % Helligkeit angehoben, in Dunkel auf höchstens 18 % abgesenkt und leicht entsättigt. Aus dem Bild wird die nächstliegende der acht Listenfarben als Aktionsfarbe gewählt. So bleibt ein Bild Atmosphäre und wird nie zum Muster hinter Text. Die heutigen 15 bunten Verläufe ("Northern Lights" usw.) entfallen.

**Raum-Licht:** Jeder Raum hat zusätzlich ein weiches Licht (radialer Verlauf, Aktionsfarbe mit 18 % Deckkraft in Hell, 28 % in Dunkel), das oben rechts sitzt. Im Einkaufsmodus wandert es mit dem Fortschritt nach unten und wird breiter (siehe Abschnitt 9).

**Markt-Chip:** Kein Logo, solange keine Erlaubnis vorliegt. Der Chip ist eine opake Kapsel (Blatt-Fläche) mit einem 10-pt-Punkt in der Markenfarbe und dem Marktnamen in Text primär, zum Beispiel REWE #CC071E, Lidl #0050AA, ALDI SÜD #00005F, EDEKA #1B3D8F, Kaufland #E10915, PENNY #CD1414, Netto #FFE500 (mit 1-pt-Rand #3D3000, damit Gelb auf Weiß sichtbar bleibt).

---

## 5. Typografie

SF Pro als Systemschrift, für Kennzahlen SF Pro Rounded. Alle Stile hängen an Apples Text-Styles und skalieren mit Dynamic Type bis zu den Bedienungshilfen-Größen. Laufweite größenabhängig, große Schrift enger.

| Stil | Größe / Zeilenhöhe | Gewicht | Laufweite | Einsatz |
|---|---|---|---|---|
| Raum-Titel | 40 / 44 | Bold | -0,9 pt | Ein Titel pro Screen direkt im Raum: Listenname, "Avo Pro" |
| Large Title | 34 / 41 | Bold | -0,4 pt | Rezepte, Kalorien, Profil |
| Title 1 | 28 / 34 | Bold | -0,4 pt | Rezeptname, Sheet-Titel |
| Title 2 | 22 / 28 | Semibold | -0,3 pt | Artikel im Einkaufsmodus, Avo-Transkript |
| Title 3 | 20 / 25 | Semibold | -0,2 pt | Abschnittstitel (Gänge, "Zutaten") |
| Headline | 17 / 22 | Semibold | -0,4 pt | Zeilentitel mit Gewicht, Buttons |
| Body | 17 / 22 | Regular | -0,4 pt | Artikelzeilen, Fließtext, Schritte |
| Callout | 16 / 21 | Regular | -0,3 pt | Hinweiszeilen im Abschnitt "Heute" |
| Subheadline | 15 / 20 | Regular | -0,2 pt | Unterzeilen ("Lena hat Milch hinzugefügt") |
| Footnote | 13 / 18 | Regular | -0,1 pt | Quellenangaben, "laut Händler", Rechtliches |
| Caption 1 | 12 / 16 | Medium | 0 | Tab-Beschriftungen, Chips |
| Kennzahl groß | 48 / 52 | Semibold, Rounded | -1,0 pt | "640 kcal übrig", "7 von 12" im Einkaufsmodus |
| Kennzahl | 20 / 24 | Semibold, Rounded | -0,2 pt | Mengen, Preise, Zeiten, Portionen |

**Regeln:**
- Zahlen, die sich live ändern (Fortschritt, Mengen, Kalorien), mit Ziffern gleicher Breite, damit nichts springt.
- Hierarchie aus Gewicht und Größe, keine Großbuchstaben-Kicker, keine Serifen.
- Der Raum-Titel bricht bei 320 pt Breite oder großen Schriftstufen auf zwei Zeilen um, ab AX-Größen ist er auf 56 pt gedeckelt und läuft auf bis zu drei Zeilen. Beim Scrollen schrumpft er in die Glas-Toolbar (Headline, einzeilig, mit Auslassung).
- Ab AX-Größen stapelt jede Artikelzeile Menge über Namen statt daneben. Keine Zeile hat eine feste Höhe, nur eine Mindesthöhe.
- Die Eingabeleiste wächst mit der Schrift (Mindesthöhe 44 pt, Höhe aus der Textmetrik, nicht gemessen nach dem Frame). Das behebt den abgeschnittenen Text auf dem iPhone 13 Pro mit Anzeigezoom.

---

## 6. Material und Form

### 6.1 Das Ebenenmodell

| Ebene | Material | Was | Was nie |
|---|---|---|---|
| Raum | Opaker Verlauf plus ein weiches Licht, statisch | Hintergrund jedes Screens, sichtbar oben (Titelzone) und in den Abständen zwischen Abschnitten | Text außer dem einen Raum-Titel und der Unterzeile direkt darunter |
| Blatt | Opak (#FFFFFF / #141716) | Abschnitte, Zeilen, Rezeptkarten, Avo-Antwortkarten, Chips | Glas, Schatten, Verläufe |
| Glas | Liquid Glass (nativ) | Tab-Bar, Avo-Knopf, Toolbar-Knöpfe, Eingabeleiste (Bottom Accessory), schwebender Hauptknopf, Menüs, Sheets in Teilhöhe | Listenzeilen, Karten, Abschnitte, Glas auf Glas |

**Wie das Glas gefärbt wird:** Nicht durch Anmalen. Das Glas bricht das Licht des Raums und der darunter scrollenden Inhalte, dadurch nimmt es die Listenfarbe von selbst auf. Nur der eine Hauptknopf pro Screen bekommt getöntes Glas in der Aktionsfarbe ("Einkaufen", "Zutaten auf die Liste", "14 Tage gratis testen").

**Scroll-Edge-Effekt:** Wo Inhalte unter Glas laufen (oben unter der Toolbar, unten über Tab-Bar und Eingabeleiste), blendet ein weicher Übergang in die Raumfarbe aus. Keine harten Linien unter Leisten.

**Sheets:** Teilhöhe = Glas (Avo, Menüs, "Wo warst du?"). Vollhöhe = Blatt-Fläche erhöht mit Abdunkelung des Hintergrunds. Gestapelte Sheets schieben die Ebene dahinter zurück und dunkeln sie stufenweise ab.

### 6.2 Radien (konzentrisch)

| Element | Radius | Begründung |
|---|---|---|
| Tab-Bar, Eingabeleiste, Buttons, Chips | Kapsel | Systemform von Liquid Glass |
| Sheets oben | folgt dem Geräteradius | System |
| Abschnitt auf dem Blatt (Gruppe von Zeilen) | 26 pt, kontinuierliche Kurve | konzentrisch zum Geräterand bei 16 pt Seitenabstand |
| Bild in einer Zeile oder Karte | 26 minus Innenabstand, z. B. 26 − 12 = 14 pt | konzentrisch zum Abschnitt |
| Artikel-Illustration | keine Kachel, freigestellt | |
| Rezeptkarte | 26 pt, Foto innen randlos | |
| Widgets | Container-Radius des Systems, Inhalte konzentrisch über `ContainerRelativeShape` | |

**Abstände:** Seitenrand 16 pt (bei 320 pt Breite 12 pt), Abstand zwischen Abschnitten 24 pt, Innenabstand im Abschnitt 16 pt, Zeilen mindestens 44 pt, im Einkaufsmodus mindestens 64 pt.

### 6.3 Tiefe

- Inhalte haben keine Schatten. Sie heben sich vom Raum über die Tonstufe ab.
- Tiefe entsteht durch Bewegung: Der Raum scrollt mit 30 % Geschwindigkeit (Parallaxe), das Blatt mit 100 %, das Glas steht still. Beim Überziehen am oberen Rand dehnt sich der Raum (Gummiband), der Titel bleibt.
- Nur Glas hat den systemeigenen Schatten.

### 6.4 Bedienungshilfen

- **Reduce Transparency:** Glas wird zu einer festen Fläche (Blatt erhöht, mit 4 % Listenfarbe), der Raum wird zu einer einzigen flachen Farbe (oberer Wert).
- **Erhöhter Kontrast:** Raum flach in neutral, Glas mit 1-pt-Rand in Text sekundär, Zeilentrenner kräftiger.
- **Reduce Motion:** keine Parallaxe, kein wanderndes Licht, Raumwechsel als Überblendung, Avo-Kern ändert nur Helligkeit.
- **VoiceOver:** Listenfarbe wird mit angesagt ("Wocheneinkauf, Lagune, 9 offen"), Angebote als Teil des Artikels ("Milch, 2 Stück, im Angebot bei REWE").

---

## 7. Ikonografie, Artikelbilder, Fotos, Maskottchen

**Ikonografie:** Ausschließlich SF Symbols, hierarchische Darstellung, Gewicht passend zum Text daneben (Body → Regular, Headline → Semibold). Symbole stehen frei, nie in getönten Quadraten oder Kreisen. Farbe nur, wenn das Symbol eine Aktion ist (dann Aktionsfarbe) oder einen Zustand trägt (Erfolg, Warnung, Fehler).

**Artikelbilder ("Glasfrüchte"):** Eigene Illustrationen für alle Kategorie-IDs und die ca. 200 häufigsten Artikel. Stil: weich modellierte Objekte mit einer Lichtquelle oben links, leicht durchscheinenden Kanten und kräftigem, aber natürlichem Farbton, freigestellt ohne Kachel, 32 pt in Listen, 44 pt im Einkaufsmodus. Der Stil passt zum 3D-Maskottchen und zum Glas, ohne selbst Glas zu sein. Hell und Dunkel nutzen dieselbe Illustration, in Dunkel mit einem schmalen Lichtrand für Kontrast.

**Produktfotos:** Open-Food-Facts-Fotos nur bei erkanntem Markenprodukt oder Barcode, im 14-pt-Rahmen, nicht freigestellt (CC BY-SA). Die Quelle "Foto: Open Food Facts, CC BY-SA" steht im Artikel-Detail mit Link. Keine Fotos aus Händler-Shops oder Prospekten, keine marktguru-Bilder; Angebote zeigen die Illustration der Kategorie.

**Rezeptfotos:** Randlos als Hero, laufen unter der Glas-Toolbar. Aus dem Foto wird einmal die dominante Farbe berechnet, auf die nächstliegende Listenfarbe geklemmt und als Raum des Rezepts genutzt (Ergebnis wird am Rezept gespeichert, nicht bei jedem Öffnen neu berechnet).

**Maskottchen:** Die vorhandene 3D-Avocado bleibt erkennbar, wird aber erwachsener: etwas weniger gesättigt, ohne Konturlinie, mit einem Glanzlicht wie die Glasfrüchte. Einsatz höchstens einmal pro Screen und nie in Listen oder Rezepten:
- Onboarding (winkend), leere Zustände ("Noch nichts auf der Liste", denkend), Erfolgsmomente (Einkauf erledigt, Challenge geschafft, feiernd).
- **Avo als Assistent zeigt nicht das ganze Maskottchen, sondern seinen Kern:** eine glänzende Kugel im Ton des Avocado-Kerns (#8A5A2B mit grünem Randlicht #6BD08F). Der Kern ist das Symbol für "Avo hört zu / denkt / spricht" und das Glyph im Avo-Knopf. So wirkt der Assistent hochwertig, und die Figur bleibt für emotionale Momente.

---

## 8. Navigation

### 8.1 Tabs (Liquid-Glass-Tab-Bar, schwebend)

| Tab | SF Symbol | Sichtbar | Inhalt |
|---|---|---|---|
| Einkauf | `checklist` | immer | Startseite = die Liste von heute, im Raum ihrer Farbe |
| Rezepte | `fork.knife` | immer | Entdecken, Gespeichert, Meine Rezepte, Community; Segment "Woche" nur mit Modul Wochenplan |
| Kalorien | `flame` | nur mit Modul Kalorien | Tag, Woche, Gewicht, Wasser, Workouts, Challenges |

Wird ein Modul ausgeschaltet, verschwindet sein Tab sofort und die übrigen Tabs rücken mit einer Feder nach (Glas morpht, kein Sprung). Steht man gerade auf dem Tab, landet man auf "Einkauf".

**Liste von heute:** die Liste, die zuletzt geöffnet oder gerade von jemandem im Einkaufsmodus genutzt wird, sonst die mit den meisten offenen Artikeln. Man kann eine Liste fest als "Heute" anheften.

**Zwischen Listen wechseln:** Wie Orte in Wetter. Wischen im Raum-Titel-Bereich wechselt zur nächsten Liste, der Raum blendet in die neue Farbe über. Punkte unter dem Titel zeigen die Position, Tippen auf den Titel öffnet die Listenauswahl als Glas-Menü, das aus dem Titel wächst (alle Listen mit Farbe und offener Anzahl, "Neue Liste", "Liste beitreten", "Alle Listen und Verlauf"). Zeilen behalten ihre eigenen Wisch-Aktionen, Listenwechsel per Wischen gibt es nur im Titelbereich.

**Alle Listen:** eigener Screen (Push), gruppiert in "Meine Listen", "Geteilt", "Erledigte Einkäufe" (Verlauf, Monatsrückblick, Kosten teilen, wenn Modul an).

### 8.2 Avo: genau ein Einstieg

Ein runder Glasknopf rechts neben der Tab-Bar, an der Stelle, an der iOS die Suche als eigenen Knopf führt. Er zeigt den Avo-Kern.
- **Tippen:** Der Knopf morpht in ein Glas-Sheet in Teilhöhe: "Frag Avo oder suche". Avo ist damit auch die globale Suche (Listen, Artikel, Rezepte, Einstellungen).
- **Gedrückt halten:** startet sofort den Sprachmodus.
- Avo kennt den Screen, von dem man kommt ("diese Liste", "dieses Rezept").
- Der Knopf bleibt im Einkaufsmodus und im Kochmodus an exakt derselben Stelle, auch wenn die Tab-Bar verschwindet.
- Ist das Modul Avo aus, zeigt derselbe Knopf eine Lupe und ist nur Suche. Es gibt keinen zweiten Avo-Einstieg, keine Avo-Banner, keine Avo-Karten auf der Startseite.

### 8.3 Profil und Einstellungen

- Ein runder Avatar-Knopf (Glas) oben rechts in der Toolbar von Einkauf, Rezepte und Kalorien, wie das Konto in App Store und Musik.
- Öffnet das Profil als Sheet: Name und Avatar, Pro-Status, dann gruppiert: **Module** (Schalter für Angebote, Kalorien, Wochenplan, Kosten teilen, Avo), **Preise & Angebote** (weit oben, über die Suche findbar), Ernährung und Allergien, Mitteilungen, Darstellung, Sprache, Hilfe, Rechtliches, Abmelden.
- In jeder Liste zusätzlich im "…"-Menü: "Angebote für diese Liste ausblenden", Markt ändern, Farbe und Hintergrund, Mitglieder, Kategoriereihenfolge.

---

## 9. Signatur-Screens

### 9.1 Startseite: die Liste von heute (Tab Einkauf)

- **Raum:** Lagune (Liste "Wocheneinkauf"), Licht oben rechts.
- **Glas oben:** links Knopf "Alle Listen" (`square.stack`), rechts Teilen (`person.2`) und Avatar; daneben der getönte Hauptknopf "Einkaufen".
- **Im Raum:** Raum-Titel "Wocheneinkauf", darunter Punkte für 4 Listen, dann eine Zeile mit Markt-Chip "● REWE" und "9 offen · Lena und du".
- **Blatt, Abschnitt "Heute"** (höchstens drei Zeilen, nur aus eingeschalteten Modulen, jede mit einer Aktion):
  - "Milch geht wahrscheinlich bald aus" – Knopf "Hinzufügen"
  - "4 von 11 Artikeln diese Woche bei REWE im Angebot, ca. 3,20 € gespart · in deiner Region" (Ersparnis in #7A5C00)
  - "Heute im Wochenplan: Linsen-Dal" (Wochenplan-Modul)
  - Ist das Angebots-Modul aus oder der Kill-Switch aktiv, fehlt die Zeile ohne Lücke.
- **Blatt, Abschnitte nach Gang:** "Obst & Gemüse" (Bananen, 6 Tomaten, Zitronen), "Milch & Käse" (2 Milch mit gelbem Chip "Angebot 0,99 €", Gouda), "Backwaren" (Vollkornbrot). Jede Zeile: Häkchen-Kreis in Aktionsfarbe, Illustration, Name, Menge in Rounded rechts, bei geteilten Listen ein kleiner Initialen-Punkt der Person, die es hinzugefügt hat.
- **Glas unten:** Eingabeleiste als Bottom Accessory über der Tab-Bar: "+" (Foto-Import, Rezept, Verlauf) und Feld "Artikel hinzufügen". Beim Tippen erscheinen Vorschläge aus dem Verlauf als Glas-Leiste über der Tastatur; "2 Milch" wird live als "2 × Milch" angezeigt. Angebots-Vorschläge beim Tippen nur aus dem Markt der Liste.
- **Hauptfrage:** Was brauche ich noch?

### 9.2 Liste im Einkaufsmodus

- **Übergang:** "Einkaufen" antippen: Die Tab-Bar schrumpft in den Knopf zurück und verschwindet, die Eingabeleiste wird zu einem kleinen "+"-Glasknopf unten links, der Avo-Knopf bleibt unten rechts. Bildschirm bleibt an.
- **Raum:** dieselbe Listenfarbe, etwas gesättigter. Das Licht steht anfangs oben und steigt mit jedem Häkchen weiter in den Raum hinein. Bei 100 % ist der ganze Raum hell durchflutet.
- **Glas oben:** "Schließen" (x) links, Mitte "7 von 12" (Kennzahl, Rounded), rechts getönter Knopf "Fertig".
- **Präsenz:** eine Glas-Kapsel unter der Toolbar: "Lena kauft auch gerade ein · REWE". Was Lena abhakt, hakt sich bei dir live ab, kurz mit ihrem Initialen-Punkt markiert.
- **Blatt:** Gänge als Abschnitte in der gelernten Reihenfolge des Markts, der aktuelle Gang-Titel bleibt oben haften. Zeilen mindestens 64 pt, Name in Title 2, Häkchen-Kreis 32 pt mit 44-pt-Trefferfläche über die ganze Zeile. Abgehakte Zeilen bleiben 0,6 s stehen (Rückgängig durch erneutes Tippen) und gleiten dann in den eingeklappten Abschnitt "Im Wagen · 7".
- **Angebote:** gelber Chip "Angebot 1,19 €" an der Zeile, im Detail "statt 1,59 € laut Händler".
- **Fertig:** Glas-Sheet in Teilhöhe "Wo warst du?" mit dem Markt der Liste vorausgewählt. Danach Erfolgsmoment: Raum voll hell, kleines feierndes Maskottchen, "Einkauf erledigt" und, falls zutreffend, "ca. 3,20 € durch Angebote gespart". Optional "Kosten teilen" (Modul).
- **Hauptfrage:** Was fehlt noch im Wagen?

### 9.3 Rezeptdetail

- **Foto** randlos oben (ca. 45 % der Höhe), läuft unter der Glas-Toolbar (Zurück, Merken, Teilen). Beim Überziehen dehnt es sich, beim Scrollen bewegt es sich langsamer als der Inhalt.
- **Raum** aus der Fotofarbe (z. B. Mandarine für Linsen-Dal), Titel "Linsen-Dal mit Kokos" in Title 1 auf dem Raum direkt unter dem Foto, darunter Kennzahlen "25 Min · 2 Portionen · 540 kcal".
- **Blatt:** Portionen-Stepper (rastet mit Haptik ein), "Für dich angepasst"-Zeile, wenn Ersetzungen aktiv sind ("Kokosmilch statt Sahne, weil laktosefrei", mit "Original zeigen"), Zutaten mit Mengen in Rounded und gelbem Angebots-Chip, falls Modul an. Bei Allergien sichtbar: "Prüfe Zutaten bei Allergien selbst, Ersetzungen sind Vorschläge". Dann Schritte, Nährwerte, Varianten, Kommentare.
- **Glas unten:** getönter Hauptknopf "Zutaten auf die Liste" (Menü wählt die Liste, Standard = Liste von heute) und Glasknopf "Kochen" (Kochmodus Vollbild, großer Text, Timer).
- **Hauptfrage:** Will ich das kochen, und was brauche ich dafür?

### 9.4 Avo mit Sprachmodus

- **Öffnen:** Der Avo-Knopf morpht in ein Glas-Sheet in Teilhöhe; nach oben ziehen = Vollhöhe. Im Sheet ein eigener Raum in Avocado.
- **Leer:** Kern in der Mitte, darunter drei Vorschläge als Kapseln passend zum Kontext ("Was fehlt für Linsen-Dal?", "Plane meine Woche", "Trag mein Mittagessen ein").
- **Sprachmodus:** Der Kern wird größer und reagiert auf die Lautstärke (nur bei Ton, nicht in Schleife). Das Live-Transkript steht in Title 2 auf dem Blatt: "Setz die Zutaten für Linsen-Dal auf den Wocheneinkauf." Avo antwortet mit Stimme und Text.
- **Ergebniskarten (Blatt):** "6 Artikel zu Wocheneinkauf hinzugefügt" mit Artikelnamen, Knöpfe "Ansehen" und "Rückgängig". Bei Löschen immer eine Rückfrage-Karte: "Liste 'Grillabend' endgültig löschen? 14 Artikel, für alle Mitglieder." mit rotem "Löschen" und "Abbrechen". Unklare Liste: Auswahl als Kapseln mit Listenfarbe.
- **Glas unten:** großer getönter Mikrofon-Knopf, daneben Tastatur und Kamera (Foto vom Essen, Zettel).
- **Hauptfrage:** Was soll Avo für mich tun?

### 9.5 Paywall

- **Raum:** neutral-tief mit Avocado-Licht; Raum-Titel "Avo Pro", darunter "14 Tage gratis, danach 29,99 € pro Jahr. Jederzeit kündbar."
- **Blatt:** Vorteile als Zeilen (kein Raster aus gleichen Karten), jede mit SF Symbol in Akzent, Titel und einem Satz Nutzen. Die Zeilen kommen aus einer Feature-Liste im Code, damit jedes Feature Pro werden kann, ohne dass die Paywall neu gestaltet wird. Kommt man über eine gesperrte Funktion, steht diese Funktion als erste Zeile, hervorgehoben.
- **Pläne:** zwei auswählbare Zeilen: "Jährlich · 29,99 € · entspricht 2,50 € pro Monat · 16 % günstiger" (vorausgewählt) und "Monatlich · 2,99 €".
- **Glas unten:** getönter Hauptknopf "14 Tage gratis testen", darunter in Footnote: "Wir erinnern dich 2 Tage vor Ende der Testphase." und "Käufe wiederherstellen · AGB · Datenschutz".
- **Kein Druck:** kein Countdown, keine durchgestrichenen Fantasiepreise, Schließen-Knopf sofort sichtbar. Angebote kommen auf der Paywall nicht vor.
- **Pro-Kennzeichnung im Rest der App:** eine kleine Kapsel "Pro" (Caption 1, Semibold, Akzent-Umriss) neben dem Feature-Namen. Gesperrte Aktion antippen: Paywall als Sheet, das aus dem angetippten Element wächst. Kontextueller Hinweis höchstens einmal pro Feature und Woche als Zeile im passenden Abschnitt, nie als Pop-up beim App-Start.
- **Hauptfrage:** Lohnt sich Pro für mich?

### 9.6 Widget

- **Klein:** Raum der Liste als Widget-Hintergrund, Listenname (Headline), "9 offen", drei Artikel mit antippbaren Häkchen (App Intent, ohne App zu öffnen).
- **Mittel:** sechs Artikel in zwei Spalten mit Häkchen, oben rechts "+" (öffnet direkt das Eingabefeld).
- **Groß:** nach Gang gruppiert, bis zu zwölf Artikel, unten Markt-Chip und "Lena kauft gerade ein", wenn zutreffend.
- **Getönt und klar:** Raum entfällt, Häkchen und Listenname werden zur Akzent-Gruppe, Illustrationen werden monochrom.
- **Sperrbildschirm:** rund = Fortschrittsring "3/12"; rechteckig = "Wocheneinkauf · 9 offen · Milch, Bananen, Brot"; inline = "9 offen auf Wocheneinkauf". StandBy nutzt das große Layout.
- **Weitere Typen:** Schnell hinzufügen, Wochenplan heute, Rezept, Kalorien und Wasser (Modul), Angebote (Modul und Lizenz). Konfiguration: Liste, Erledigtes zeigen, nach Gang gruppieren. Steuerelemente für Kontrollzentrum und Action-Button: "Artikel hinzufügen", "Liste öffnen".

---

## 10. Bewegung und Haptik

| Moment | Bewegung | Haptik |
|---|---|---|
| Standard (Push, Sheet, Menü) | Feder, Dämpfung 1,0, Antwort 0,35 s, Herkunft am Auslöser | keine |
| Listenwechsel per Wischen | folgt dem Finger 1:1, Freigabe mit Schwung-Projektion, Dämpfung 0,8, Antwort 0,4 s; Raumfarbe blendet parallel über | Einrasten (Selection) bei der neuen Liste |
| Abhaken | Kreis füllt sich vom Berührungspunkt aus, Häkchen zeichnet sich; Licht im Raum steigt mit Feder (1,0 / 0,5 s) | leichter Impact, im selben Frame |
| Zeile wandert in "Im Wagen" | nach 0,6 s, Feder 1,0 / 0,4 s, Zeilen darunter rücken nach | keine |
| Einkaufsmodus an/aus | Tab-Bar morpht in den Knopf, Eingabeleiste morpht zum "+" | keine |
| Einkauf erledigt | Raum wird einmal voll hell, Maskottchen erscheint mit Feder 0,8 / 0,4 s | Erfolg (Notification Success) |
| Avo öffnen | Knopf morpht zum Sheet; Wegwischen geht den gleichen Weg zurück | keine |
| Avo spricht oder hört | Kern skaliert mit dem Pegel (max. 8 %), Licht folgt | keine |
| Portionen, Mengen | Stepper rastet ein | Selection |
| Fehler (z. B. offline nicht speicherbar) | Zeile wackelt kurz horizontal | Fehler (Notification Error) |
| Drag zum Umsortieren | Zeile hebt sich an (Skalierung 1,03), folgt 1:1, Gummiband an Rändern | Selection beim Einrasten |

**Regeln:** Alles unterbrechbar und vom aktuellen Wert aus. Keine Endlos-Animationen im Raum, kein Schimmern, kein Skeleton-Flackern: Daten sind lokal sofort da, Abgleich läuft unsichtbar. Rückgängig statt Bestätigung, außer bei endgültigem Löschen. Reduce Motion: alle Wege werden Überblendungen von 0,2 s, das Licht wechselt nur die Helligkeit.

---

## 11. App-Icon: "Kern im Glas"

Eine halbierte Avocado von vorn, stark vereinfacht: die tropfenförmige Fruchtfläche als eigene Glasschicht, darin der Kern als glänzende Kugel. Kein Gesicht im Icon; das Maskottchen lebt in der App. Aufbau in drei Ebenen für den Icon Composer:

1. Hintergrund: Verlauf
2. Fruchtfläche (Tropfenform, leicht nach oben versetzt)
3. Kern (Kugel, im unteren Drittel der Frucht, mit Glanzlicht oben links)

| Erscheinung | Hintergrund | Fruchtfläche | Kern |
|---|---|---|---|
| Hell | #1F6B3F → #0F3D24 (oben → unten) | #E9F5C4 → #CFE8A0, mattes Glas | #8A5A2B mit Glanzlicht #E2B98A |
| Dunkel | #0C1F14 → #06130B | dunkles Grün #2F7A4A mit hellem Randlicht #6BD08F | #7A4A22, warmes Glanzlicht |
| Klar | transparent, Hintergrundbild scheint durch | klares Glas mit Lichtkante | klares Glas, stärkste Lichtbrechung |
| Getönt | Systemtönung | mittlerer Tonwert | hellster Tonwert, damit der Kern das Zentrum bleibt |

Das Icon ist damit die Brücke zum Avo-Knopf: Der Kern im Icon ist derselbe Kern, der in der App für den Assistenten steht.

---

## 12. Stärken, Risiken, Aufwand, Performance

### Stärken
- Unverwechselbar: Keine andere Einkaufslisten-App gibt Listen einen eigenen Raum. Man erkennt die Liste an der Farbe, auch im Widget und auf dem Sperrbildschirm.
- Apple-nah ohne Kopie: Wetter-, Musik- und Erinnerungen-Muster sind vertraut, Liquid Glass wird genau so eingesetzt, wie Apple es vorsieht.
- Wirkt hochwertig und emotional, gut für Pro-Verkauf und App-Store-Screenshots.
- Fortschritt als Licht macht den Einkaufsmodus belohnend, ohne Gamification-Lärm.
- Das Ebenenmodell ist eine einfache, durchsetzbare Regel für zwei parallel arbeitende Entwickler.

### Risiken
- **Farbmenge:** Acht Listenfarben plus Angebots-Gelb plus Akzent können bunt wirken. Gegenmittel: pro Screen eine Aktionsfarbe, blasse Räume in Hell, Angebots-Gelb nur als kleiner Chip.
- **Lesbarkeit im Raum:** Nur ein Titel steht direkt im Raum, alles andere auf dem Blatt. Eigene Bilder werden stark weichgezeichnet und in der Helligkeit geklemmt.
- **Gesten-Konflikt:** Listenwechsel per Wischen gegen Wisch-Aktionen auf Zeilen. Gegenmittel: Wischen nur im Titelbereich, sonst über Titel-Menü und Punkte. Mit echten Nutzern testen; wenn es verwirrt, Wischen streichen und nur das Titel-Menü behalten.
- **Kill-Switch:** Angebote müssen spurlos verschwinden. Der Gelb-Chip und die Heute-Zeile hängen an einem Flag; Layouts dürfen keine Lücke reservieren.
- **Fotofarben:** Automatisch berechnete Räume können unpassend wirken. Gegenmittel: Klemmen auf die acht Listenfarben.

### Aufwand in Flutter (grob, Personentage)
| Baustein | Aufwand |
|---|---|
| Tokens (Farben, Typo, Radien, Abstände) in `AppColors`, `AppTextStyles`, `AppDimensions`; Paper entfernen | 3–4 |
| `RaumBackground`-Widget (Verlauf, Licht, Parallaxe, Farbübergang, Bild-Raum) | 2–3 |
| Shell: native Glas-Tab-Bar, Avo-Knopf, Bottom Accessory, Morph in den Einkaufsmodus | 5–7 |
| Listen-Screen, Listenwechsel, Einkaufsmodus mit Licht-Fortschritt und Präsenz | 6–8 |
| Rezepte inkl. Detail, Kochmodus, Fotofarbe | 5–6 |
| Avo-Sheet mit Kern und Sprachmodus (UI-Teil) | 3–4 |
| Paywall und Pro-Bausteine | 2–3 |
| Widgets in SwiftUI (alle Typen, Größen, getönt) | 5–7 |
| Glasfrucht-Illustrationen (extern oder generiert, ca. 230 Stück) | separat |

Insgesamt mittel bis hoch, gut auf zwei Personen aufteilbar (Shell und Listen auf der einen, Rezepte, Avo, Paywall, Widgets auf der anderen Seite).

### Performance (Ziel: iPhone 13 Pro mit 120 Hz, also 8 ms pro Frame)
- **Raum ist billig:** statischer Verlauf plus ein radialer Verlauf, in einer `RepaintBoundary`, kein `BackdropFilter`. Parallaxe nur über `Transform`. Farbübergänge interpolieren zwei Farbwerte, kein Neuaufbau des Baums.
- **Glas ist teuer:** native Glas-Views (`adaptive_platform_ui`, `LiquidGlassViewFactory.swift`) nur für Tab-Bar, Avo-Knopf, Eingabeleiste und höchstens drei Toolbar-Knöpfe. Höchstens etwa sechs Platform Views gleichzeitig, nie in scrollenden Listen. Menüs und Sheets nativ über das Paket.
- **Scroll-Edge-Effekt** als Verlaufsmaske (`ShaderMask`), nicht als Blur.
- **Bild-Räume** werden einmal weichgezeichnet und verkleinert zwischengespeichert, nie live geblurrt.
- **Listen:** Zeilen mit `select` auf einzelne Artikel, damit ein Häkchen nur eine Zeile neu baut; Illustrationen als vorab gerasterte Assets.
- **Reduce Transparency** spart zusätzlich Leistung, weil Glas dann zur festen Fläche wird.

---

## 13. Bildzeile für ChatGPT

Zwei iPhone-17-Pro-Mockups nebeneinander im Hellmodus, iOS 27 mit Liquid Glass, SF-Pro-Schrift, deutsche Texte. Links die Startseite: Der Hintergrund ist ein blasser Petrol-Verlauf von #D6EEF3 oben nach #F2F7F8 unten mit einem weichen Lichtfleck oben rechts, darin groß in fettem Schwarz (#0B0F0D) der Titel "Wocheneinkauf", darunter vier kleine Seitenpunkte, eine weiße Kapsel mit rotem Punkt (#CC071E) und dem Wort "REWE" sowie "9 offen · Lena und du"; oben schweben runde Glasknöpfe und ein petrolfarben getönter Glasknopf "Einkaufen". Darunter liegen opake weiße Abschnitte mit 26-pt-Ecken: zuerst "Heute" mit den Zeilen "Milch geht wahrscheinlich bald aus" und "4 von 11 Artikeln diese Woche bei REWE im Angebot, ca. 3,20 € gespart · in deiner Region" (Betrag in #7A5C00), dann "Obst & Gemüse" mit Bananen, 6 Tomaten, Zitronen und "Milch & Käse" mit "2 Milch" samt kleinem gelben Chip (#FFE45C, Text #3D3000) "Angebot 0,99 €" und Gouda, jede Zeile mit leerem Kreis in Petrol (#0E7490) und kleiner weicher 3D-Lebensmittel-Illustration ohne Kachel; unten schweben eine Glas-Eingabeleiste "Artikel hinzufügen" mit Plus und darunter eine Glas-Tab-Bar mit "Einkauf", "Rezepte", "Kalorien" plus ein separater runder Glasknopf mit einer glänzenden braunen Avocadokern-Kugel. Rechts dieselbe Liste im Einkaufsmodus ohne Tab-Bar: Der Petrol-Raum ist kräftiger und von oben bis zur Mitte hell durchflutet, oben schwebt eine Glasleiste mit "x", groß in gerundeter Schrift "7 von 12" und einem petrolfarbenen Glasknopf "Fertig", darunter eine Glas-Kapsel "Lena kauft auch gerade ein · REWE". Die weißen Abschnitte "Getränke" und "Tiefkühl" zeigen große Zeilen (64 pt) in 22-pt-Halbfett wie "Mineralwasser 6 × 1,5 l", "Hafermilch", "TK-Spinat" mit großen Kreisen, eine Zeile ist gerade petrolfarben abgehakt, und darunter ist ein eingeklappter Abschnitt "Im Wagen · 7" zu sehen; unten links ein kleiner runder Glasknopf "+", unten rechts derselbe runde Glasknopf mit dem Avocadokern.
