# Richtung 2: Frisch

Arbeitsname der App: "Avo" (austauschbar). Stand: 07.11.2026. Grundlage: Jannis' Plan, Recherche zu Preisen und Bildern, Verbesserungsliste, Funktionsliste (chatgpt-redesign-prompt.md, Abschnitt 3), Inventar unter `docs/redesign/konzept/inventar/`.

---

## 1. Name und ein Satz

**Frisch.** Avo sieht aus wie frisch vom Markt: große Fotos vom Essen, kräftige Schrift und ruhige, schnelle Listen, in denen nur das Wichtige Farbe trägt.

---

## 2. Gefühl

**Emotion:** Appetit und Tatkraft. Man öffnet die App und hat Lust zu kochen, und der Einkauf wirkt sofort erledigbar. Die App soll sich nicht wie ein Formular anfühlen, sondern wie ein Wochenmarkt am Samstagmorgen, auf dem jemand schon aufgeräumt hat.

**Apple-Apps als Haltung (nichts kopieren):**
- **Fitness:** Mut zu sehr fetter Schrift und zu großen Zahlen, Schwarz als Bühne im Dunkelmodus, eine Leuchtfarbe für Fortschritt. Übernommen wird die Haltung "Zahlen und Fortschritt sind ein Erlebnis", nicht die Ringe.
- **Journal:** Inhalte von Menschen (Fotos, Notizen) sind der Star, die App tritt zurück. Übernommen: große Bilder ohne Rahmen, viel Weiß dazwischen.
- **Invites:** Ein Foto trägt die ganze Seite, Text sitzt selbstbewusst darauf. Übernommen für Rezeptdetail und Wochenplan.
- **Erinnerungen:** die Liste selbst. Runde Häkchen, Zeilen ohne Schmuck, Abhaken ohne Verzögerung. Übernommen für alles, was Liste ist.

Die Spannung dieser Richtung: **Bilder und Schrift laut, Listen leise.** Wo man genießt (Rezepte, Plan), darf es üppig sein. Wo man arbeitet (Liste, Einkaufsmodus), ist es so ruhig wie Erinnerungen.

---

## 3. Fünf Prinzipien

1. **Das Essen ist die Farbe.** Rezepte und Wochenplan leben von Fotos. Die Oberfläche selbst ist weiß oder schwarz, damit Tomatenrot und Basilikumgrün leuchten. Keine farbigen Hintergründe hinter Fotos, keine Verläufe als Dekoration.
2. **Laut, wo man genießt. Leise, wo man arbeitet.** Hero-Fotos und schwere Titel nur in Rezepte, Plan, Paywall und Erfolgsmomenten. Liste und Einkaufsmodus haben keine Bilder außer kleinen Artikel-Illustrationen und keine zweite Schriftgröße über dem Abschnittstitel.
3. **Eine Aktionsfarbe, Modulfarben nur als Kennung.** Alles, was man antippen kann, ist Avocadogrün. Wochenplan, Kalorien und Angebote haben je eine eigene Farbe, die nur in ihren eigenen Daten auftaucht (Tagespunkte, Kalorienbalken, Preisschild). Nie zwei Modulfarben auf einem Screen.
4. **Sofort da.** Kein Spinner, kein Skelett-Flackern. Listen erscheinen aus dem lokalen Stand, Fotos haben ab dem ersten Frame ihre Grundfarbe als Platzhalter, Abhaken wirkt im selben Frame. Laden ist nie sichtbar, nur Fertigwerden.
5. **Jeder Screen eine Frage, jede Größe ein Layout.** Jeder Screen beantwortet eine Hauptfrage (unten in Abschnitt 9 genannt). Alles fließt mit Dynamic Type bis AX5, mit fettem Text und mit 320 pt Breite (Anzeigezoom). Keine festen Höhen um Text, keine abgeschnittenen Zeilen.

---

## 4. Farben

Alle Farben sind adaptiv (hell/dunkel) und kommen ausschließlich aus `AppColors`. Für "Erhöhter Kontrast" gibt es je eine dunklere (hell) bzw. hellere (dunkel) Stufe; bei "Transparenz reduzieren" werden Glasflächen zu Fläche 2.

### Grundflächen und Text

| Rolle | Hell | Dunkel | Hinweis |
|---|---|---|---|
| Hintergrund | `#FFFFFF` | `#000000` | Reinweiß und echtes Schwarz als Bühne für Fotos |
| Fläche 1 (gruppierte Zeilen, Karten ohne Foto, Eingabefelder) | `#F3F4F1` | `#141615` | Leicht grünstichiges Neutral, kein Creme |
| Fläche 2 (erhöht: Inhalt in Sheets, Stepper, gewählte Zeile) | `#E8EAE6` | `#222523` | Trennung über Tonstufe statt Linie |
| Haarlinie (nur zwischen Zeilen innerhalb einer Gruppe) | `#DCDFDA` | `#2C302D` | 0,5 pt, mit Einzug ab Textbeginn |
| Text primär | `#0B0D0B` | `#F4F6F3` | Auch für Fließtext und Zutaten |
| Text sekundär | `#4A504B` | `#A3AAA4` | Mengen, Metadaten, Datum |
| Text tertiär (Platzhalter, deaktiviert) | `#6F766F` | `#8A918B` | Kontrast mindestens 4,5:1 |

### Aktion, Signatur, Status

| Rolle | Hell | Dunkel | Text darauf |
|---|---|---|---|
| **Akzent: Avocadogrün** (Buttons, Häkchen, Links, aktiver Tab) | `#1F7A3A` | `#5BD67F` | `#FFFFFF` / `#062311` |
| **Signatur: Limette** (Fortschritt, Pro-Kennzeichen, Avo-Sprachmodus, Widget-Akzent) | `#C6EF5E` | `#D5FA72` | immer `#17240A` |
| Erfolg | `#1C8C43` | `#3DDC74` | mit SF Symbol `checkmark.circle.fill`, nie Farbe allein |
| Warnung | `#B25E00` | `#FFB340` | z. B. Allergie-Hinweis in Rezepten |
| Fehler / Löschen | `#D70015` | `#FF6961` | nur für endgültiges Löschen und Fehler |
| **Angebot: Preisschild** (Fläche) | `#FFE14D` | `#FFD60A` | `#1E1A00` |
| Ersparnis (Betrag als Text) | `#1F7A3A` | `#5BD67F` | "ca. 3,20 € gespart" in Akzentgrün, nie Rot/Grün-Vergleich |

Limette ist nie Textfarbe auf Weiß (zu wenig Kontrast), immer Fläche mit dunkler Schrift. Das gelbe Preisschild greift das Regalschild im Supermarkt auf und ist die einzige gelbe Fläche der App. Ist das Angebots-Modul aus oder per Kill-Switch abgeschaltet, gibt es kein Gelb mehr in der App.

### Modulfarben (nur Kennung in eigenen Daten)

| Modul | Hell | Dunkel | Wo sie auftaucht |
|---|---|---|---|
| Listen (Kern) | Akzentgrün | Akzentgrün | keine eigene Farbe |
| Rezepte (Kern) | keine | keine | Die Fotos sind die Farbe |
| Wochenplan | `#4E4BD8` | `#8E8BFF` | Tagespunkte, Kalorien-pro-Tag-Balken im Plan, Plan-Widget |
| Kalorien | `#E8384F` | `#FF5E78` | Kalorienbalken, Tageszahl, Wochenübersicht |
| Wasser (in Kalorien) | `#1A7FE0` | `#4DB2FF` | nur Wasser-Anzeige |
| Angebote | Preisschild-Gelb | Preisschild-Gelb | nur Preisschild |
| Avo | Limette | Limette | nur Avo-Knopf und Sprachmodus |

Diagramme haben immer genau eine Datenreihe in der Modulfarbe; Ziel- oder Vergleichslinien sind Text sekundär. Keine Regenbogen-Diagramme.

### Listenfarben (wählbar pro Liste, wie in Erinnerungen)

Sie färben nur den runden Listenpunkt, die Listen-Überschrift im Listenwechsler und das Widget. Nie den Hintergrund der Liste.

| Name | Hell | Dunkel |
|---|---|---|
| Avocado | `#1F7A3A` | `#5BD67F` |
| Blau | `#1F6FEB` | `#5AA2FF` |
| Indigo | `#5856D6` | `#8E8BFF` |
| Himbeere | `#D63168` | `#FF5C8A` |
| Orange | `#D9650A` | `#FF9F3A` |
| Senf | `#A87C00` | `#FFD43B` |
| Türkis | `#0E8A85` | `#3CD6CF` |
| Graphit | `#5E6366` | `#A1A6AA` |

Die heutigen Listen-Hintergründe (Farben, Verläufe, Bilder) werden zu: Listenfarbe plus optionales **Titelfoto**, das nur im Listenwechsler und in "Alle Listen" als Kachel erscheint, nie hinter den Artikeln.

### Markt-Chips (keine echten Logos ohne Erlaubnis)

Kapsel mit kleinem Punkt in Markenfarbe und dem Namen in Text primär: REWE `#CC071E`, Lidl `#0050AA`, Aldi Süd `#00005F`, Aldi Nord `#1E5AA8`, Edeka `#FFD400`, Kaufland `#E10915`, Netto `#FFE500` (Punkt mit Haarlinie), PENNY `#CD1414`. Der Chip ist Fläche 1, nicht in Markenfarbe gefüllt.

---

## 5. Typografie

Systemschrift SF Pro (in Flutter auf iOS die Systemschrift über `CupertinoTextThemeData`, keine gebündelte Schrift). Jede Stufe hängt an einem Dynamic-Type-Stil und skaliert bis AX5. Laufweite folgt Apples Größentabelle (große Schrift enger). Zahlen (Mengen, Preise, kcal, Zähler) als **SF Pro Rounded, Halbfett, tabellarische Ziffern**; das ist die einzige Schriftvariante neben SF Pro.

| Stufe | Dynamic-Type-Basis | Größe / Zeilenhöhe | Gewicht | Laufweite | Einsatz |
|---|---|---|---|---|---|
| Bühne | Large Title, Faktor 1,18 | 40 / 44 | Heavy (800) | -0,9 | Rezepttitel auf Foto, Paywall-Titel, Erfolgsmoment |
| Großer Titel | Large Title | 34 / 41 | Heavy (800) | -0,6 | Tab-Wurzeln: "Heute", "Rezepte", "Plan", "Kalorien" |
| Titel 1 | Title 1 | 28 / 34 | Bold | -0,4 | Listenname im Kopf, Sheet-Titel |
| Titel 2 | Title 2 | 22 / 28 | Bold | -0,3 | Abschnitte auf Startseite ("Heute kochen") |
| Abschnitt | Title 3 | 20 / 25 | Bold | -0,2 | Gang-Überschriften ("Obst & Gemüse"), im normalen Satz, nie Großbuchstaben |
| Zeile hervorgehoben | Headline | 17 / 22 | Semibold | -0,4 | Artikelname im Einkaufsmodus, Buttons |
| Text | Body | 17 / 22 | Regular | -0,4 | Artikelname in der Liste, Fließtext, Schritte |
| Hinweis | Callout | 16 / 21 | Regular | -0,3 | Spar-Zeile, Avo-Antworten |
| Unterzeile | Subheadline | 15 / 20 | Regular | -0,2 | Menge, "von Lena", Rezept-Meta |
| Fußnote | Footnote | 13 / 18 | Regular | -0,1 | Quellenangaben ("laut Händler", "Foto: Open Food Facts, CC BY-SA") |
| Etikett | Caption 1 | 12 / 16 | Semibold | 0 | Preisschild, Pro-Kennzeichen, Tab-Beschriftung |
| Klein | Caption 2 | 11 / 13 | Medium | +0,1 | nur Widgets und Sperrbildschirm |
| Kochmodus-Schritt | Title 1, Faktor 1,15 | 32 / 40 | Semibold | -0,5 | Schritttext im Kochmodus |
| Große Zahl | Large Title | 34 bis 56 | Rounded Bold | -0,8 | "640 kcal übrig", "3,20 €" im Erfolgsmoment |

Regeln:
- Hierarchie aus Gewicht und Größe, nicht aus Farbe. Fließtext immer Text primär.
- Keine Kicker in Großbuchstaben über Überschriften. Datum über "Heute" steht in Unterzeile, normaler Satz, Text sekundär.
- Ab Dynamic Type AX1: Artikelzeilen brechen um (Menge unter den Namen statt daneben), Rezept-Raster wird einspaltig, Tab-Beschriftungen nutzen den Großinhalts-Viewer per langem Druck.
- "Fetter Text" der Bedienungshilfen wird respektiert (Heavy bleibt Heavy, Regular wird Semibold).

---

## 6. Material und Form

### Liquid Glass: nur die schwebende Bedienebene

| Element | Glas | Bemerkung |
|---|---|---|
| Tab-Leiste mit separatem Avo-Knopf | ja, nativ | `UITabBar` über `adaptive_platform_ui`, schrumpft beim Scrollen nach unten (Minimize-Verhalten) |
| Eingabe-Accessory "Artikel hinzufügen" über der Tab-Leiste | ja | eine Kapsel, verschmilzt beim Fokus mit der Tastatur-Toolbar |
| Toolbar-Buttons (Zurück, Teilen, Merken, Mehr) über Fotos | ja, rund | auf Rezeptdetail und Wochenplan über dem Foto |
| Menüs (Listenwechsler, Sortierung, Mehr) | ja | wachsen aus dem auslösenden Button |
| Sheets in Teilhöhe (Avo, Artikel bearbeiten, Markt wählen) | ja | ab voller Höhe opak (Fläche 1), so wie iOS 26 |
| Einkaufsmodus-Leiste unten ("ca. 3,20 € gespart", "Einkauf abschließen") | ja | einzige Glasfläche im Einkaufsmodus neben der Toolbar |
| Listenzeilen, Artikel, Rezeptkarten, Hinweise, Chat-Blasen | **nein** | Inhalt ist nie Glas |

Kein Glas auf Glas: Ein Menü aus der Toolbar ersetzt den Button (Morph), es liegt nicht darauf. Wo Inhalt unter die Glasebene scrollt, gibt es eine weiche Scroll-Kante (Verlauf des Hintergrunds, 24 pt) statt einer Linie. Über Fotos bekommt die Toolbar keine Kante, das Glas trägt sich selbst.

### Radien (konzentrisch)

Bezug ist der Geräteradius (iPhone 17 Pro ca. 55 pt; iPhone SE ohne Rundung, dort gelten die Werte in Klammern).

| Element | Radius |
|---|---|
| Elemente am Bildschirmrand mit 16 pt Abstand (Tab-Leiste, Accessory, Einkaufsleiste) | Kapsel |
| Große Fotokarten (Rezept, "Heute kochen", Plan-Tag) | 28 pt (SE: 20) |
| Element innerhalb einer Karte mit 12 pt Innenabstand | 16 pt (Karte minus Abstand) |
| Gruppierte Zeilenblöcke (Einstellungen, Zutaten) | 22 pt |
| Buttons, Chips, Markt-Chip, Preisschild, Eingabefelder | Kapsel |
| Artikel-Illustration | keine Form, freigestellt |
| Avatare | Kreis |

### Tiefe

- Inhalte haben **keine Schatten** und **keine Rahmen**. Trennung nur über Tonstufen (Hintergrund, Fläche 1, Fläche 2) und Weißraum.
- Schatten trägt nur das Glas (System-Schatten).
- Modale Aufgaben (Paywall, Kochmodus, Einkauf abschließen) dimmen und schieben den Hintergrund leicht zurück. Parallele Sheets (Avo in mittlerer Höhe) dimmen nicht.

### Abstände

Raster 4 pt. Seitenrand 16 pt (bei 320 pt Breite ebenfalls 16 pt, nie weniger). Zwischen Abschnitten 32 pt, zwischen Titel und Inhalt 12 pt. Zeilenhöhe Liste mindestens 52 pt, Einkaufsmodus mindestens 64 pt, beide wachsen mit der Schrift. Touch-Ziele mindestens 44 × 44 pt.

---

## 7. Ikonografie, Artikelbilder, Fotos, Maskottchen

### Ikonografie
- Ausschließlich **SF Symbols** (Hierarchical-Rendering für Navigation, Multicolor nur in Widgets und Kalorien). Material-Icons, Cupertino-Icons und Lucide fallen weg (über die native Brücke von `adaptive_platform_ui` bzw. einen SF-Symbol-Export als Fallback).
- Symbole stehen frei, nie in getönten Quadraten oder Kreisen.
- Tabs: Heute `checklist`, Rezepte `fork.knife`, Plan `calendar`, Kalorien `flame`, Avo eigenes Symbol (Avocado-Silhouette als Custom SF Symbol, drei Gewichte).

### Artikelbilder
- **Eigenes Illustrationsset "Marktstand"**: freigestellte, vollfarbige Lebensmittel in weichem, leicht plastischem Stil (eine Lichtquelle von oben links, keine Konturlinie, keine Gesichter), passend zur Machart des Maskottchens, aber ernster. 28 pt in der Liste, 40 pt im Einkaufsmodus, 64 pt in Vorschlägen.
- Umfang laut Recherche: alle Kategorie-IDs plus die ca. 200 häufigsten generischen Artikel. Fehlt eine Illustration, zeigt die Zeile die der Kategorie.
- **Open-Food-Facts-Fotos** nur bei erkanntem Markenprodukt oder Barcode, nicht freigestellt (ein Freisteller wäre eine Bearbeitung unter Share-Alike), daher als kleines Rechteck 4:5 mit 6 pt Radius, Quellenangabe in der Artikelansicht als Fußnote "Foto: Open Food Facts, CC BY-SA".
- Keine Händler- oder Prospektfotos. Angebote ohne Lizenz zeigen die Kategorie-Illustration.

### Fotos
- **Rezepte:** Hero 4:5 randlos (Detail), Karten 3:2 (Raster) und 16:10 (Hero "Rezept der Woche"). Jedes Rezeptfoto bekommt beim Hochladen eine Grundfarbe (Supabase-Feld, z. B. `photo_color`), die ab dem ersten Frame als Platzhalter steht.
- Bildsprache: Tageslicht, von schräg oben, echte Teller, kein Studio-Weiß. Für "Rezept der Woche" und das Onboarding eigene, kuratierte Fotos.
- Community-Fotos in schlechter Qualität: Ist ein Foto zu klein oder fehlt es, wird die Karte zur **Typo-Karte** (Fläche 1, Titel in Titel 2, Zutaten-Illustrationen in einer Reihe), nie ein gestrecktes Bild.
- Text auf Fotos nur mit Verlauf vom Bildrand (Schwarz 0 auf 55 %, unteres Drittel), Schrift immer Weiß. Kein Glas als Textunterlage.

### Maskottchen Avo
- Modernisiert: gleiche Figur, aber matter und ruhiger (weniger Glanz, gedecktere Haut `#3E7D2A`, Fruchtfleisch `#D9EE8A`), fünf Stimmungen bleiben, Animation als Rive- oder Lottie-Datei mit wenigen Bewegungen.
- **Wo:** Onboarding (Willkommen, Modulwahl), leere Zustände (eine Pose je Bereich), Erfolgsmomente (Einkauf abgeschlossen, Challenge geschafft), Kopf des Avo-Sheets klein (32 pt), App-Fehler mit Nachsicht ("Avo findet das Netz gerade nicht").
- **Wo nicht:** Tab-Leiste, Listen, Einkaufsmodus, Rezeptdetail, Paywall-Kopf, Widgets (außer leeres Listen-Widget). In Arbeits-Screens stört eine Figur.
- Im Sprachmodus spricht nicht die Figur, sondern ein abstrakter **Kern** (siehe 9).

---

## 8. Navigation

### Tabs (iOS-26-Tab-Leiste, nativ, mit Beschriftung)

| Tab | Sichtbar wenn | Inhalt |
|---|---|---|
| **Heute** | immer | Die Liste von heute, darunter "Heute kochen" und kompakte Modul-Zeilen |
| **Rezepte** | immer | Entdecken, Suche, Gespeichert, Meine Rezepte, Community, Ersteller |
| **Plan** | Modul Wochenplan an | Woche als Foto-Streifen, Portionen, "Alles auf die Liste" |
| **Kalorien** | Modul Kalorien an | Tag, Essen hinzufügen, Wasser, Gewicht, Workouts, Woche, Challenges |
| **Avo** (separater runder Glasknopf rechts) | Modul Avo an | der eine Einstieg in Avo |

- Bei ausgeschalteten Modulen verschwinden Tabs ohne Lücke; mindestens zwei Tabs bleiben (Heute, Rezepte). Ist Avo aus, gibt es keinen runden Knopf.
- Wechsel zwischen Tabs ohne seitliches Durchschieben (heutiger Bug): Tabs überblenden sofort, wie in iOS.
- Bei 320 pt Breite und AX-Größen: Beschriftungen bleiben, Symbole werden 2 pt kleiner; langer Druck zeigt den Großinhalts-Viewer.

### Der eine Avo-Einstieg
- Der runde Avo-Knopf rechts neben der Tab-Leiste ist **der einzige** Einstieg in der App (der heutige Hinweisstreifen auf Home entfällt). Antippen: Der Knopf morpht in ein Glas-Sheet in mittlerer Höhe, der aktuelle Screen bleibt sichtbar, Avo kennt den Kontext ("Du bist in Wocheneinkauf").
- **Langer Druck** auf denselben Knopf startet direkt den Sprachmodus (gleicher Einstieg, schnellere Geste).
- Außerhalb der App erreichen Siri, Kurzbefehle und der Action Button Avo über App Intents; das sind keine zusätzlichen In-App-Einstiege.
- Wo Avo heute in Screens auftauchen würde (z. B. "Liste per Foto importieren"), steht eine normale Aktion im Menü, die denselben Dienst nutzt, ohne Chat.

### Profil und Einstellungen
- **Profilbild oben rechts** in der Navigationsleiste jeder Tab-Wurzel (wie App Store und Fitness). Öffnet ein Sheet "Profil" mit: Name und Avatar, Pro-Status, **Module** (Schalter für jedes Modul), **Preise & Angebote** (weit oben, mit allen Schaltern aus Verbesserungsliste 6d), Ernährung und Allergien, Mitteilungen, Darstellung (System/Hell/Dunkel, Akzent bleibt fest), Sprache, Verlauf und Statistiken, Hilfe, Datenschutz, Abmelden. Oben ein Suchfeld über alle Einstellungen.

### Listen, Verlauf, Angebote der Woche
- **Listenwechsler:** Der Listenname im Kopf von "Heute" ist ein Menü-Button ("Wocheneinkauf" mit kleinem Chevron). Er öffnet ein Glas-Menü mit allen Listen (Listenpunkt, offene Anzahl, Markt), "Neue Liste" und "Alle Listen".
- **Alle Listen:** Seite mit Listen als Zeilen (Listenpunkt, Titelfoto klein rechts, "Lena hat Milch hinzugefügt"), darunter Verlauf (Monatsrückblick) und offene Kostenaufteilungen.
- Welche Liste "heute" ist: die zuletzt benutzte; eine Liste lässt sich als "Immer zuerst zeigen" anheften.
- **Angebote der Woche** (Modul): erreichbar über die Spar-Zeile in der Liste und eine Zeile auf "Heute". Kein eigener Tab.

---

## 9. Signatur-Screens

### Startseite "Heute" (die Liste von heute)
**Hauptfrage:** Was muss ich heute noch besorgen?
- Oben: Datum "Samstag, 7. November" (Unterzeile, sekundär), darunter großer Titel "Heute" in Heavy, rechts das Profilbild.
- **Listenkopf:** "Wocheneinkauf" (Titel 1, Menü-Button), daneben Markt-Chip "REWE". Zeile darunter: zwei überlappende Avatare und "7 offen". Ist das Angebots-Modul an und die PLZ echt (nicht Fallback 10115): "4 von 11 Artikeln diese Woche bei REWE im Angebot, ca. 3,20 € gespart, in deiner Region" als Hinweis-Text, nicht als Karte; antippen öffnet die Angebote dieser Liste.
- **Die Artikel selbst**, nach Gang gruppiert, Abschnittstitel in Title 3 Bold. Zeile: runder Häkchenkreis 24 pt links, Illustration 28 pt, Name (Body), Menge in Rounded rechts, ggf. gelbes Preisschild "1,49 €". Wer etwas hinzugefügt hat, steht nur, wenn es nicht man selbst war ("von Lena").
- Ab 12 offenen Artikeln: nur die ersten zwei Gänge, dann "Alle 23 Artikel" (öffnet die Liste im Vollbild, gleiche Darstellung).
- Darunter Abschnitt **"Heute kochen"**: eine große Fotokarte aus dem Wochenplan (oder Vorschlag, wenn Plan aus): Foto 3:2, Titel, "35 Min · 2 Portionen". Ist Kalorien an: eine schlichte Zeile "Noch 640 kcal heute" mit dünnem Balken in Kalorienfarbe.
- Hinweise ("Milch geht dir wohl bald aus") erscheinen als **Vorschlags-Zeile** direkt in der Liste (Illustration, Name grau, "+"-Knopf), nicht als Karte.
- Unten: Glas-Kapsel **"Artikel hinzufügen"** als Accessory über der Tab-Leiste, mit Mikrofon und Kamera (Zettel importieren). Fokus: Vorschläge aus dem Verlauf erscheinen als Chips über der Tastatur; "2 Milch" zeigt sofort eine Vorschau "2 × Milch · Kühlregal". Angebote zum Getippten (Modul an) als eine Zeile mit Preisschild unter den Chips, nie als Karussell.
- Schwebender Button "Einkaufen" (gefüllt grün, Kapsel) rechts unten über dem Accessory, sobald mindestens ein Artikel offen ist.

### Liste im Einkaufsmodus
**Hauptfrage:** Was fehlt mir noch im Wagen?
- Vollbild, Tab-Leiste und Accessory weg, Bildschirm bleibt an (`wakelock_plus`).
- Oben Glas-Toolbar: "Fertig" links, Titel "REWE · 4 von 11", rechts "Mehr" (Sortierung, Angebote für diese Liste ausblenden). Unter der Toolbar eine 3 pt dünne Fortschrittslinie in Limette.
- Darunter, wenn jemand anderes auch einkauft: Kapsel "Lena kauft auch gerade ein" mit Avatar. Abhaken anderer erscheint live: Die Zeile hakt sich mit kurzem Avatar-Blitz selbst ab.
- Zeilen 64 pt+, Häkchenkreis 30 pt mit Trefferfläche über die ganze Zeile, Name Headline, Menge Rounded groß, Illustration 40 pt. Gänge als klebende Abschnittstitel in Title 3 Bold.
- Abgehaktes gleitet nach 0,6 s in den Abschnitt **"Im Wagen (4)"** am Ende (eingeklappt), ausgegraut mit gefülltem grünem Häkchen. In diesen 0,6 s und danach per Tipp rückgängig.
- Unten Glas-Leiste: links "ca. 3,20 € gespart" (nur mit Angebots-Modul, sonst "7 offen"), rechts Kapsel-Button "Einkauf abschließen". Abschließen fragt den Markt ab (vorausgewählt), dann Erfolgsmoment.
- **Erfolgsmoment:** Vollflächig Weiß/Schwarz, Avo feiernd (klein), "Erledigt." in Bühne, darunter "11 Artikel · ca. 3,20 € gespart" mit hochzählender Zahl, optional "Kosten teilen". Haptik Erfolg.

### Rezeptdetail
**Hauptfrage:** Will ich das kochen, und was brauche ich dafür?
- Foto 4:5 randlos bis unter die Statusleiste, darüber nur runde Glas-Knöpfe (Zurück, Teilen, Merken). Titel in Bühne (40 Heavy, Weiß) unten im Foto auf Verlauf: "Ofengemüse mit Feta".
- Unter dem Foto drei Werte nebeneinander, groß in Rounded: "35 Min", "2 Portionen", "540 kcal" (kcal nur mit Kalorien-Modul), daneben der Portionen-Stepper. Bei AX-Größen untereinander.
- Ersteller-Zeile mit Avatar, "Folgen". Personalisierung als ruhiger Hinweis: "An deine Ernährung angepasst: Feta durch Tofu ersetzt" (Warnfarbe nur bei Allergie-Konflikt, mit SF Symbol `exclamationmark.triangle`).
- **Zutaten** als gruppierter Block (Fläche 1, 22 pt): Illustration, Menge in Rounded, Name; Zutaten im Angebot mit kleinem Preisschild. Darunter Primär-Button **"Alles auf die Liste"** (Kapsel, grün), mit Listenwahl im Menü daneben.
- **Schritte** als große nummerierte Absätze (Body, Ziffern Rounded Bold in Akzent), Timer-Angaben als antippbare Kapsel "12 Min Timer".
- Schwebender Glas-Button "Kochen" unten rechts startet den Kochmodus (Vollbild, schwarz, Schritt in 32 pt, Wischen zwischen Schritten, Timer als Glas-Kapsel oben).
- Unten: Varianten der Community (horizontale Zeilen, kein Kartenraster), Kommentare, "Ins Tagebuch eintragen" (Kalorien-Modul).

### Avo mit Sprachmodus
**Hauptfrage:** Was soll Avo für mich tun?
- Sheet aus dem Avo-Knopf, mittlere Höhe, ziehbar auf voll. Kopf: kleines Avo (32 pt), "Avo", Schließen. Leer: drei Vorschläge als Textzeilen passend zum Kontext ("Zutaten für Ofengemüse auf Wocheneinkauf", "Was koche ich heute?", "Trag mein Mittagessen per Foto ein").
- Chat: Nutzer rechts als Kapsel in Fläche 2, Avo links ohne Blase als Fließtext (Callout), Ergebnisse als **Inhalts-Karten** (Fläche 1): Liste mit Häkchen, Rezept mit Foto 3:2, Kalorien-Eintrag mit "geschätzt". Jede ausgeführte Aktion hat "Rückgängig".
- **Löschen nur mit Rückfrage:** Karte "Liste 'Party' mit 14 Artikeln löschen?" mit Button "Löschen" in Fehlerrot und "Abbrechen". Das ist der einzige Bestätigungsdialog-Typ in Avo.
- **Sprachmodus:** Mikrofon im Eingabefeld oder langer Druck auf den Avo-Knopf. Das Sheet geht auf volle Höhe und wird dunkel (auch im hellen Modus, wie Fitness-Workouts), in der Mitte der **Kern**: eine Avocado-Kontur in Limette, deren Rand mit der Stimme atmet (Amplitude, Feder). Darunter die Mitschrift live in Titel 2, Avos Antwort erscheint Wort für Wort und wird gesprochen. Unten zwei Glas-Knöpfe: "Stumm" und "Beenden". Aktionen erscheinen als kleine Karten unter der Mitschrift.
- Bei Reduce Motion: Der Kern pulsiert nicht, sondern zeigt einen ruhigen Pegelbalken.

### Paywall "Avo Pro"
**Hauptfrage:** Ist mir Pro das wert?
- Vollbild-Sheet. Oben ein randloses Foto eines gedeckten Wochentisches (eigenes Foto), daraus wächst nach unten Weiß/Schwarz. Titel in Bühne: "Avo Pro". Unterzeile: "Mehr planen, weniger nachdenken." (Text final später).
- **Vorteile als Liste**, nicht als Kartenraster: SF Symbol frei in Akzentgrün, Titel Headline, eine Zeile Erklärung. Die Liste wird aus einer Konfiguration gebaut (Feature-ID, Symbol, Titel, Satz), damit der Owner später festlegt, was Pro ist. Angebote stehen dort nie.
- **Zwei Pläne** als große Auswahlzeilen (Fläche 1, gewählte mit 2 pt Akzent-Kontur): "Jährlich, 29,99 € im Jahr, 2,50 € im Monat" mit Limetten-Etikett "16 % günstiger"; "Monatlich, 2,99 € im Monat".
- **Zeitleiste der Testphase** (wie Apples eigene Abos): "Heute: alles frei", "Tag 12: Erinnerung", "Tag 14: erste Abbuchung". Darunter der Button "14 Tage gratis testen" (Kapsel, grün, volle Breite), dann "Jederzeit in den Einstellungen kündbar", "Käufe wiederherstellen", AGB, Datenschutz.
- Wird nach einem Aha-Moment gezeigt (z. B. nach dem dritten abgeschlossenen Einkauf oder beim ersten Wochenplan), nie als Hürde im Onboarding.
- **Pro-Kennzeichnung im Rest der App:** kleine Limetten-Kapsel "Pro" (Caption 1, dunkle Schrift) hinter dem Feature-Namen. **Kontextueller Hinweis:** eine Zeile am Ort des Features, z. B. im Plan "Plane die ganze Woche mit Pro", Antippen öffnet die Paywall mit diesem Vorteil oben. Kein Banner, kein Countdown, keine wiederkehrenden Pop-ups.

### Widgets
- **Liste klein:** Listenname mit Listenpunkt, offene Anzahl groß in Rounded, drei Artikel mit Häkchenkreis (interaktiv per App Intent).
- **Liste mittel:** sechs Artikel in zwei Spalten, abhakbar, rechts oben "+" (öffnet die App mit fokussiertem Eingabefeld).
- **Liste groß:** nach Gang gruppiert, bis zu 12 Artikel, Kopf mit Markt-Chip.
- **Heute kochen** (klein/mittel): Rezeptfoto randlos, Titel weiß auf Verlauf, Zeit. Nur Widget-Typ mit Foto.
- **Plan** (mittel): sieben Tage als Punkte in Plan-Indigo mit Gerichtsnamen. **Kalorien und Wasser** (klein, rund auf Sperrbildschirm). **Schnell hinzufügen** (klein, Control Center, Action Button).
- Sperrbildschirm: rund (offene Anzahl), rechteckig (drei Artikel), inline ("Wocheneinkauf · 7 offen"). StandBy: große Liste in Weiß auf Schwarz, rote Nachtdarstellung automatisch.
- Darstellungen: hell und dunkel mit Weiß/Schwarz-Grund; **getönt** (alle Elemente als Glyphen, Häkchen und Zahlen voll, Illustrationen weg); **klar** (Glas: Text Weiß, Häkchenkreise mit Kontur, keine Flächen).

### Weitere Screens in dieser Sprache (Kurzregeln)
- **Rezepte-Tab:** großer Titel, Suche als Glas-Feld in der Toolbar, "Rezept der Woche" als 16:10-Foto randlos, danach Abschnitte mit unterschiedlichen Formen (eine horizontale Foto-Reihe, eine Textliste "Schnell unter 20 Min", ein Raster), nie drei gleiche Kartenreihen hintereinander. Filter-Chips als Kapseln.
- **Wochenplan:** Tage als senkrechter Streifen großer Fotos (16:10) mit Tag links in Rounded ("Mo 9."), Portionen-Stepper je Tag, unten Glas-Leiste "17 Zutaten auf Wocheneinkauf", gleiche Zutaten zusammengefasst.
- **Kalorien:** Tag als große Zahl "640 kcal übrig" in Rounded, ein einzelner Balken in Kalorienfarbe, Makros als drei schlichte Textzeilen mit Mini-Balken in derselben Farbe abgestuft, Mahlzeiten als Gruppenblöcke. "Essen hinzufügen" als Glas-Button mit Menü: Foto, Barcode-Kamera, Suche, Manuell. Foto-Analyse zeigt "geschätzt, ca. 80 % sicher" als Text.
- **Onboarding:** Willkommen mit Avo winkend auf Weiß, Titel in Bühne. Danach höchstens vier Schritte: Ziele, **Module** (eine Liste mit Schaltern, Angebote standardmäßig an, dann direkt Standort/PLZ und Lieblingsmärkte), Ernährung (überspringbar), Liste anlegen mit vorgeschlagenem Markt. Mitteilungen erst beim ersten Teilen einer Liste.
- **Leere Zustände:** Avo-Pose, ein Satz, ein Button. **Fehler:** ein Satz in Fließtext, "Erneut versuchen", nie Vollbild-Fehler bei vorhandenem lokalem Stand.

---

## 10. Bewegung und Haptik

| Moment | Bewegung | Haptik |
|---|---|---|
| Abhaken | Kreis füllt sich per Feder (Dämpfung 1,0, Antwort 0,3 s) vom Tippunkt, Häkchen zeichnet sich, Name wird sekundär. Nach 0,6 s gleitet die Zeile nach "Im Wagen" (Feder 1,0 / 0,4) | leichter Impuls im selben Frame |
| Letzter Artikel abgehakt | Fortschrittslinie läuft voll, Leiste unten wechselt zu "Einkauf abschließen" in Limette | Erfolg |
| Artikel hinzufügen | neue Zeile wächst an ihrem Gang-Platz auf (Höhe und Deckkraft gemeinsam), Liste rückt per Feder nach | keine |
| Wischen zum Löschen | folgt dem Finger 1:1, rastet mit Gummiband-Widerstand ein, Löschen ohne Dialog, "Rückgängig" als Glas-Kapsel unten 4 s | Einrasten beim Schwellwert |
| Rezeptkarte → Detail | Zoom-Übergang: Foto wächst aus der Karte zum Hero (Flutter `Hero` mit Federkurve), Zurück-Wischen schrumpft es in die Karte zurück, unterbrechbar | keine |
| Avo-Knopf → Sheet | Glas morpht aus dem Knopf in das Sheet (Herkunft am Auslöser), Schließen morpht zurück | leichter Impuls beim Öffnen per langem Druck |
| Menüs | wachsen aus ihrem Button (Feder 1,0 / 0,3), Inhalt blendet versetzt ein | keine |
| Sheet nach Wisch loslassen | Feder 0,8 / 0,3 mit Geschwindigkeitsübernahme und Momentum-Projektion | Einrasten auf Detent |
| Tab-Wechsel | sofortiges Überblenden, kein Schieben | Auswahl-Tick |
| Zahlen (gespart, kcal) | zählen per Feder hoch, nie linear | keine |
| Sprachmodus | Kern-Kontur folgt der Amplitude mit Feder 1,0 / 0,15, keine Dauerschleife | Start und Ende des Zuhörens |
| Fehler | Feld zittert einmal horizontal (Feder 0,5, kleine Amplitude) | Fehler |

Regeln: Federn statt fester Dauern; jede Animation startet vom aktuellen Wert und ist unterbrechbar; Überschwingen nur nach Wisch oder Flick. **Reduce Motion:** alle Bewegungen werden zu Überblendungen (0,2 s), Zoom-Übergang wird Überblendung, Zahlen springen. **Reduce Transparency:** Glas wird zu Fläche 2 mit Haarlinie. **Erhöhter Kontrast:** Textsekundär wird primär, Haarlinien 1 pt. **VoiceOver:** Artikelzeile als ein Element ("Milch, 2 Stück, Kühlregal, im Angebot 1,49 Euro, nicht erledigt"), Abhaken als Standardaktion, Löschen als benutzerdefinierte Aktion.

---

## 11. App-Icon

**Idee "Halbe Avocado mit Häkchen":** Eine aufgeschnittene Avocado-Hälfte von vorn, leicht schräg, ohne Gesicht. Der Kern ist ein satter brauner Kreis, aus dem ein Häkchen ausgespart ist. Avocado und Einkaufsliste in einem Zeichen, ohne Text, ohne Zettel.

Aufbau in Icon Composer (drei Ebenen, damit iOS die Erscheinungen selbst rechnet):
1. Hintergrund
2. Avocado (Schale und Fruchtfleisch)
3. Kern mit ausgespartem Häkchen (vorderste Ebene, bekommt den stärksten Glanz)

| Erscheinung | Hintergrund | Avocado | Kern / Häkchen |
|---|---|---|---|
| **Hell** | Verlauf von `#2E9B4F` (oben) nach `#1F7A3A` | Schale `#14522A`, Fruchtfleisch Verlauf `#E3F7A0` → `#C6EF5E` | Kern `#6B4423`, Häkchen ausgespart (Hintergrund scheint durch) |
| **Dunkel** | Schwarz `#000000` mit sehr leichtem Grünschimmer `#0C1A10` unten | Schale `#2E9B4F`, Fruchtfleisch `#D5FA72` leuchtend | Kern `#7A4F2A`, Häkchen ausgespart |
| **Klar** | Glas | Avocado als milchiges Glas, Fruchtfleisch heller | Kern als dichteres Glas, Häkchen als Lichtkante |
| **Getönt** | System-Tönung | Avocado in mittlerer Tönungsstufe | Kern in voller Tönung, Häkchen ausgespart |

Das Häkchen muss bei 29 pt (Einstellungen) noch lesbar sein: Strichstärke mindestens 9 % der Kerngröße. Das Maskottchen bleibt aus dem Icon heraus; es lebt in der App.

---

## 12. Stärken, Risiken, Aufwand, Performance

### Stärken
- **Unverwechselbar im Store:** Food-Fotos und schwere Typografie heben sich von Bring!, Listonic und AnyList ab, die alle flach und blass sind. Screenshots verkaufen Appetit.
- **Tägliche Nutzung:** "Heute kochen" und der Wochenplan geben auch an Tagen ohne Einkauf einen Grund zu öffnen.
- **Pro wirkt hochwertig:** Paywall und Plan sind die schönsten Flächen der App, genau dort, wo Pro-Kandidaten liegen.
- **Arbeits-Screens bleiben nüchtern:** Liste und Einkaufsmodus sind so ruhig wie Erinnerungen, damit schnell und gut für große Schrift.
- **Angebote sind abschaltbar ohne Loch:** Gelb ist an ein einziges Element gebunden; fällt das Modul weg, verschwindet es spurlos.

### Risiken
- **Abhängig von Fotoqualität:** Community-Rezepte haben oft schlechte Fotos. Gegenmittel: Typo-Karte als gleichwertige Alternative, Mindestauflösung beim Hochladen, kuratierte Startseite.
- **Illustrationsset ist Aufwand:** ca. 230 Illustrationen in einheitlichem Stil. Ohne Illustratorin braucht es KI-Erzeugung plus Nacharbeit; uneinheitliche Bilder würden die Richtung billig wirken lassen.
- **Heavy-Titel können laut werden:** Bei AX-Größen und 320 pt Breite brechen 40-pt-Titel oft um. Regel: Bühnen-Stil maximal dreizeilig, dann automatisch auf Großer Titel zurück.
- **SF Pro Rounded in Flutter:** Die Rounded-Variante ist nicht über den Standard-`fontFamily`-Weg erreichbar. Entweder einbetten (Apples Lizenz erlaubt Nutzung in Apps für Apple-Plattformen; vor dem Einbetten prüfen) oder als Ersatz SF Pro mit tabellarischen Ziffern (`FontFeature.tabularFigures()`).
- **Dunkler Sprachmodus im hellen Modus** ist eine bewusste Ausnahme; muss sich wie ein Modus anfühlen, nicht wie ein Fehler.
- **Nähe zu Fitness:** Limette auf Schwarz erinnert an Apple Fitness. Abgrenzung durch Avocado-Formen statt Ringe und durch Fotos statt Diagramme.

### Aufwand (grob, für zwei Personen mit Claude Code)
| Baustein | Aufwand |
|---|---|
| Design-Tokens (`AppColors`, `AppTextStyles`, `AppDimensions`) und Ablösung von Paper | mittel, 2 bis 3 Tage |
| Shell: native Tab-Leiste, Avo-Knopf, Accessory, Profil-Sheet | mittel, 2 bis 3 Tage |
| Heute und Einkaufsmodus | hoch, 4 bis 5 Tage |
| Rezepte, Detail mit Hero-Übergang, Kochmodus, Plan | hoch, 5 bis 6 Tage |
| Avo-Sheet und Sprachmodus (Spracherkennung und Sprachausgabe neu) | hoch, 4 bis 5 Tage |
| Paywall, Pro-Kennzeichnung, Onboarding | mittel, 3 Tage |
| Widgets (SwiftUI, App Intents, alle Darstellungen) | hoch, 4 bis 5 Tage |
| Illustrationsset und Icon | hoch, parallel, 1 bis 2 Wochen inkl. Nacharbeit |

### Performance in Flutter (Ziel iPhone 13 Pro: keine Frames über 16 ms laut Verbesserungsliste, bei 120 Hz 8 ms anstreben)
- **Glas sparsam:** gleichzeitig höchstens drei native Glas-Platform-Views (Tab-Leiste zählt als eine, wenn sie nativ ist). Kein `BackdropFilter` in scrollenden Listen. Scroll-Kanten als einfacher Farbverlauf, nicht als Unschärfe.
- **Bilder:** `cached_network_image` mit `memCacheWidth` passend zur Anzeigegröße (Karte 3:2 bei 390 pt: ca. 1170 px Breite), Grundfarbe als Platzhalter statt Shimmer, Vorladen der nächsten zwei Rezeptfotos beim Scrollen. Server liefert drei Größen (Supabase Storage mit Bildtransformation).
- **Illustrationen** als WebP in einer vorab geladenen Sprite-Datei bzw. 2x/3x-Assets; kein SVG-Parsing pro Zeile.
- **Listen:** `SliverList` mit festen Schlüsseln, Riverpod `select` pro Zeile, Abhaken optimistisch und lokal zuerst. Hero-Übergang nur für das Foto, nicht für ganze Karten.
- **Sprachmodus:** Amplitude mit 30 Hz abtasten und per Feder glätten, keine Shader-Animation.
- **Widgets** sind SwiftUI und unabhängig von Flutter-Performance; Daten über die App Group.

---

## 13. Bildzeile für ChatGPT

Zwei iPhone-17-Pro-Mockups nebeneinander im hellen Modus, fotorealistisch wie ein Apple-Pressebild, Stil iOS 27 mit Liquid Glass, Schrift SF Pro, Hintergrund reinweiß #FFFFFF, Text fast schwarz #0B0D0B, Aktionsfarbe Avocadogrün #1F7A3A, Signaturfarbe Limette #C6EF5E, gruppierte Flächen #F3F4F1, keine Rahmen, keine Schatten auf Inhalten, keine Großbuchstaben-Überschriften und kein Maskottchen auf diesen beiden Screens. Links die Startseite: oben klein grau „Samstag, 7. November“, darunter sehr fett und groß „Heute“, rechts oben ein rundes Profilfoto; darunter „Wocheneinkauf“ mit kleinem Chevron, ein grauer Kapsel-Chip mit rotem Punkt #CC071E und „REWE“, zwei überlappende runde Avatare „Lena“ und „Jannis“, „7 offen“ und in Grün die Zeile „4 von 11 Artikeln diese Woche bei REWE im Angebot, ca. 3,20 € gespart, in deiner Region“; dann Artikelzeilen mit leeren runden Häkchenkreisen und kleinen freigestellten, farbigen Lebensmittel-Illustrationen unter fetten Abschnittstiteln „Obst & Gemüse“ (Bananen, 6 Tomaten, 2 Avocados) und „Kühlregal“ (2 × Milch 1,5 %, Butter, Gouda mit zitronengelbem Preisschild #FFE14D „1,49 €“), darunter die Überschrift „Heute kochen“ mit einer großen randlosen Fotokarte (28-pt-Ecken) von Ofengemüse mit Feta auf einem Blech und „35 Min · 2 Portionen“. Am unteren Rand der linken Ansicht schwebt eine Liquid-Glass-Kapsel „Artikel hinzufügen“ mit Plus, Mikrofon und Kamera, rechts darüber ein grüner Kapsel-Button „Einkaufen“, und ganz unten eine Liquid-Glass-Tab-Leiste mit beschrifteten SF-Symbol-Tabs „Heute“ (aktiv, grün), „Rezepte“, „Plan“, „Kalorien“ sowie rechts daneben ein separater runder Glasknopf mit einer grünen Avocado-Silhouette. Rechts derselbe Wocheneinkauf im Einkaufsmodus ohne Tab-Leiste: oben eine Glas-Toolbar mit „Fertig“, dem Titel „REWE · 4 von 11“ und darunter eine dünne limettengrüne Fortschrittslinie, dann eine kleine graue Kapsel mit Avatar „Lena kauft auch gerade ein“, große 64-pt-Zeilen mit 30-pt-Häkchenkreisen und größeren Illustrationen unter klebenden fetten Abschnittstiteln „Obst & Gemüse“, „Kühlregal“ und „Getränke“ (Mineralwasser 6 × 1,5 l, Apfelschorle), und am Ende ein Abschnitt „Im Wagen (4)“ mit ausgegrauten Artikeln und grün gefüllten Häkchen. Ganz unten in der rechten Ansicht eine Liquid-Glass-Leiste mit „ca. 3,20 € gespart“ links und einem gefüllten avocadogrünen Kapsel-Button „Einkauf abschließen“ mit weißer Schrift rechts.
