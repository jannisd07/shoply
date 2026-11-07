# 10 Heute: die Liste von heute (Tab Liste)

Stand: 07.11.2026. Verbindlich für Teil A und Teil B. Baut auf `00-grundlagen.md` (Verweise "00 12.8") und `01-navigation-und-struktur.md` (Verweise "01 2.2") auf und benutzt nur deren Tokens, Komponenten und Routen. Was dort fehlt, steht als Vorschlag in 10.16 (E10-xx). Offene Fragen dieses Kapitels heißen F10-xx (10.15).

**Besitz:** Teil A baut den Screen, die Auswahl und Anordnung der Hinweise, die Darstellung von "Vielleicht auch", "Erledigt", das Titelmenü, die Präsenz und alle leeren Zustände. Teil B liefert die Inhalte der Hinweis-Zeilen aus seinen Bereichen (Angebote, Wochenplan, Kalorien, Kosten teilen, Standort-Markt), den Markt-Chip (`StoreChip`), die gelben Schilder (`ItemOfferBadge`), die Artikelbilder (`ArticleImage`) und die Nachkauf-Daten.

**Grundlage:** Plan 2 (Startseite = Liste von heute), Plan 4 (Kern-Ablauf, Präsenz, live), Plan 1 (Module, ein Avo-Einstieg), Plan 8 und Recherche (Wortlaut bei Angeboten), Verbesserungsliste 2, 3, 4, 6, 16 (jedes iPhone, Tempo, tägliche Nutzung), K-02, K-10, K-12, K-28, K-36, K-38.

Inhalt: 10.0 Überblick und Beispieldaten · 10.1 Liste von heute · 10.2 Metazeile und Präsenz · 10.3 "Für heute" und Hinweis-Zeilen · 10.4 Gang-Sektionen · 10.5 "Vielleicht auch" · 10.6 "Erledigt" und "Alles erledigt" · 10.7 Listen-Umschalter · 10.8 Toolbar der Wurzel · 10.9 Erste Liste · 10.10 Leere Liste · 10.11 Laden, Fehler, offline · 10.12 Tägliche Nutzung · 10.13 Abläufe · 10.14 Betroffene Dateien · 10.15 Offene Fragen · 10.16 Ergänzungen zum Fundament

---

## 10.0 Überblick und Beispieldaten

### 10.0.1 Was zu diesem Bereich gehört

| Nr. | Screen, Sheet, Dialog | Muster | Route | Besitz |
|---|---|---|---|---|
| 10.1 | Liste von heute | Tab-Wurzel | `/home`, `/home?list=:id`, `/lists/:listId` | A |
| 10.2 | Metazeile mit Markt, offener Anzahl, Mitgliedern und Präsenz | Teil von 10.1, live | – | A (Chip-Inhalt B) |
| 10.3 | Sektion "Für heute" mit Hinweis-Zeilen; Kontextmenü einer Hinweis-Zeile | Teil von 10.1; Kontextmenü | – | A (Auswahl, Anordnung), B (Inhalte) |
| 10.4 | Gang-Sektionen | Teil von 10.1 | – | A |
| 10.5 | "Vielleicht auch"; Kontextmenü eines Vorschlags | Teil von 10.1; Kontextmenü | – | A (Darstellung), B (Nachkauf-Daten) |
| 10.6 | "Erledigt (n)" und Zustand "Alles erledigt" | Teil von 10.1 | – | A |
| 10.7 | Listen-Umschalter (Titelmenü) | Menü aus dem Titel | – | A |
| 10.8 | Toolbar der Wurzel | Glas-Gruppe | – | A |
| 10.9 | Tab Liste ohne Liste ("Erste Liste") | Zustand von 10.1 | `/home` | A |
| 10.10 | Leere Liste ("Noch nichts auf der Liste.") | Zustand von 10.1 | – | A |
| 10.11 | Erstes Laden, Fehler, offline | Zustände von 10.1 | – | A |

**Nicht in diesem Kapitel** (nur verlinkt): `AddItemAccessory` mit Vorschlags-Panel, Artikel-Sheet, Einkaufsmodus, Alle Listen, Listen-Info, Liste teilen, Neue Liste, Liste beitreten, Reihenfolge im Markt (Kapitel 11); Markt-Sheet, Angebots-Sheet, Region, Abschluss, Verlauf, Offene Beträge, Angebote der Woche (Kapitel 12); Wochenplan (14); Kalorien (15); Avo (16); Paywall (18); Mitteilungen und Widgets (19).

### 10.0.2 Beispieldaten

Alle Beispiele und Bildbeschreibungen dieses Kapitels nutzen dieselben Daten, damit Zahlen zusammenpassen.

- **Zeit:** Samstag, 7. Nov. 2026, 9:41 Uhr. Gerät iPhone 17 Pro (402 pt), Textgröße L, hell, Module Angebote, Wochenplan, Avo an; Kalorien und Kosten teilen aus (Vorschlag F-04), wo nicht anders genannt.
- **Personen:** Jannis (Nutzer), Lena (Mitglied in Wocheneinkauf und Grillabend), Tom (Mitglied in Grillabend).

| Liste | Farbe, Symbol | Markt | Offen | Geteilt mit |
|---|---|---|---|---|
| **Wocheneinkauf** (Liste von heute, angeheftet) | Blau #007AFF, `cart` | Lidl (#0050AA) | 11 | Lena |
| Grillabend | Orange #FF9500, `flame` | REWE (#CC071E) | 7 | Lena, Tom |
| Drogerie | Lila #AF52DE, `drop` | kein Markt | 4 | – |
| Party Samstag | Rosa #FF2D55, `party.popper` | kein Markt | 0 (alles erledigt) | – |

**Wocheneinkauf, offene Artikel** (Reihenfolge im Markt Lidl; Kategorienamen aus `categories.dart`):

| Gang | Artikel (Menge rechts) | Angebot (nur Modul Angebote) |
|---|---|---|
| Obst & Gemüse (4) | Bananen · Avocados "2" · Cherrytomaten "250 g" · Gurke | Avocados 0,79 € je Stück, laut Händler statt 1,29 € |
| Bäckerei & Frischetheke (1) | Vollkornbrot | – |
| Milchprodukte (3) | Milch "2" · Gouda in Scheiben (von Lena) · Naturjoghurt "500 g" | Milch 0,99 €, laut Händler statt 1,19 €; Gouda 1,49 €, laut Händler statt 2,29 € |
| Trockenwaren (2) | Spaghetti "500 g" · Passierte Tomaten "2" | – |
| Haushalt & Hygiene (1) | Spülmittel | 0,95 €, laut Händler statt 1,95 € |

Daraus folgt die Ersparnis-Zeile: 4 von 11 Artikeln im Angebot; gespart 2 × 0,50 + 2 × 0,20 + 0,80 + 1,00 = 3,20 €. Erledigt (2): Butter, Eier (beide von Lena abgehakt). "Vielleicht auch": Haferflocken (etwa alle 10 Tage), Toilettenpapier (meistens samstags), Mineralwasser (oft auf dieser Liste). Wochenplan heute: Ofengemüse mit Feta; Feta und Paprika stehen noch nicht auf der Liste.

---

## 10.1 Liste von heute

### Zweck und Einstieg

- **Hauptfrage:** Was muss ich als Nächstes kaufen?
- **Nebenfragen, in dieser Rangfolge:** Für welchen Markt ist die Liste, wie viel ist offen, wer ist dabei und kauft gerade ein (10.2)? Gibt es heute etwas Wichtiges (10.3)? Was fehlt vielleicht noch (10.5)?
- **Wann man hierher kommt:** Kaltstart (Startroute für Angemeldete), Tab "Liste", Tippen auf eine Liste im Titelmenü oder in Alle Listen, Links `/lists/:id`, `/list/:id`, `/home?list=:id`, Listen-Widget, Mitteilungen geteilter Listen, Siri "Öffne die Lidl-Liste", Avo, Ende des Onboardings.
- **Welche Liste:** Regeln aus 01 2.2. Die Liste von heute wechselt nur durch eine ausdrückliche Wahl, nie durch Standort, Präsenz oder Wochenplan (K-28). Jede ausdrückliche Wahl wird als "zuletzt gewählt" gespeichert (`last_list_provider.dart`, pro Konto und Gerät).

### Aufbau von oben nach unten

Ein `CustomScrollView` aus Slivers; nichts davon hat eine feste Höhe um Text (00 6.2).

1. **Navigationsleiste** (`LargeTitleNavBar`, Variante Tab-Wurzel mit Listen-Umschalter, 00 12.2):
   - Obere Zeile 44 pt: links leer, rechts `GlassToolbar` mit `person.crop.circle.badge.plus` (Liste teilen) und `ellipsis` (Listenmenü), eine Glasform (Glas-View 3 von 3, 00 8.5). Siehe 10.8.
   - Großer Titel "Wocheneinkauf" (`largeTitle`, bis 2 Zeilen) mit `chevron.down` (13 pt Semibold, `labelSecondary`) hinter dem letzten Wort; der ganze Titel ist eine Taste und öffnet das Titelmenü (10.7).
   - Rechts in der Titelzeile der Profil-Avatar (`avatarL` 36 pt, ohne Glas), senkrecht auf die erste Titelzeile zentriert.
2. **Metazeile** (8 pt unter dem Titel, 10.2): Zeile 1 `StoreChip` "● Lidl" (Slot, Teil B) und `RollingNumber` "11 offen"; Zeile 2 nur bei geteilten Listen: `PresenceLine` "Mit Lena" bzw. "Lena kauft gerade bei Lidl ein".
3. **`StatusRow`** (nur wenn nötig): offline, ausstehende Änderungen, Sync-Fehler (10.11).
4. 24 pt Abstand (`space24`).
5. **Sektion "Für heute"** (`InsetSection`, Titel "Für heute", `headline`): höchstens zwei `HintRow`s (10.3). Entfällt komplett, wenn es keinen Hinweis gibt.
6. **Gang-Sektionen** (`AisleSection`, 10.4) in der Reihenfolge des Markts, je mit `ItemRow`s; zwischen Sektionen `sectionGap` 32.
7. **"Vielleicht auch"** (`InsetSection`, bis 3 `ItemRow` Variante Vorschlag, 10.5).
8. **"Erledigt (2)"** (`InsetSection` einklappbar, standardmäßig eingeklappt, 10.6).
9. **Unterer Inhaltsabstand** `bottomContentInset` aus `ShellInsets`, damit die letzte Zeile über der Bodenebene endet.
10. **Bodenebene, schwebend:** `AddItemAccessory` (Glas-View 2: `plus`, Feld "Artikel hinzufügen", `text.viewfinder`, getönte Kapsel `cart` "Einkaufen") 8 pt über der `AppTabBar` (Glas-View 1: "Liste" ausgewählt, "Rezepte", "Plan", abgesetzt der Avo-Kreis). Verhalten des Accessory: 00 12.4 und Kapitel 11.

Scroll-Edge-Effekte statt Linien: oben 24 pt Verlauf aus `bgGrouped` unter der Navigationsleiste, unten 40 pt hinter der Bodenebene (00 8.2). Beim Scrollen klappt der Titel in die obere Zeile ein: Inline-Titel "Wocheneinkauf" mit `chevron.down`, darunter als Untertitel "11 offen · Lidl" (E10-03). Der Avatar scrollt mit dem großen Titel weg.

**Was es hier nicht gibt:** Tageszeit-Gruß, Datum über dem Titel, Avo-Streifen oder Avo-Karte, Karten-Stapel, gefüllte Kapsel "Einkauf starten" im Inhalt (K-10), Fortschrittslinie unter dem Titel, Listen-Index, Angebote-Streifen, Verlaufszeile, Preisvergleich. Der Weg zu allen Listen, zum Verlauf und zu den Angeboten der Woche führt über das Titelmenü und Alle Listen (01 2.3).

### Beispielinhalt (Startzustand, von oben)

- Titel "Wocheneinkauf ⌄", Avatar Jannis (Foto).
- "● Lidl ⌄ · 11 offen"; darunter Lenas Avatar und "Mit Lena".
- Für heute: `calendar` "Heute im Plan: Ofengemüse mit Feta. Feta und Paprika fehlen noch." · "Hinzufügen"; `tag` "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" · `chevron.right`.
- Obst & Gemüse 4: Bananen; Avocados "2" mit Schild "0,79 €"; Cherrytomaten "250 g"; Gurke.
- Bäckerei & Frischetheke 1: Vollkornbrot.
- Milchprodukte 3: Milch "2" mit Schild "0,99 €"; Gouda in Scheiben, Unterzeile "von Lena", Schild "1,49 €"; Naturjoghurt "500 g".
- Trockenwaren 2: Spaghetti "500 g"; Passierte Tomaten "2".
- Haushalt & Hygiene 1: Spülmittel mit Schild "0,95 €".
- Vielleicht auch: Haferflocken "kaufst du etwa alle 10 Tage"; Toilettenpapier "kaufst du meistens samstags"; Mineralwasser "oft auf dieser Liste".
- Erledigt (2), eingeklappt.

### Zustände

| Zustand | Verhalten |
|---|---|
| Erster Start ohne Liste | Zustand "Erste Liste" (10.9). |
| Liste ohne Artikel | "Noch nichts auf der Liste." (10.10). |
| Alles abgehakt, Einkauf nicht abgeschlossen | "Alles erledigt. Schön." mit "Einkauf abschließen" (10.6). |
| Lädt (zweites Öffnen, Kaltstart mit lokalem Stand) | Erster Frame vollständig aus dem lokalen Stand, der vor `runApp` geladen ist: Listenname, Artikel, Erledigt-Zustand, Hinweise und "Vielleicht auch" aus dem Cache (00 13). Abgleich im Hintergrund; neue Werte ersetzen alte ohne Sprung: Zahlen rollen, neue Zeilen wachsen an ihrem Platz ein, entfernte klappen zusammen. Kein Indikator. |
| Allererstes Laden ohne lokalen Stand | Ruhiges Skelett aus `fill`-Tonflächen, höchstens bis zur ersten Antwort (10.11). |
| Fehler | Mit lokalem Stand: Inhalt bleibt, `StatusRow` "Das hat nicht geklappt. Erneut versuchen"; einzelne nicht gespeicherte Zeilen zeigen "Nicht gespeichert" (00 12.8). Ohne lokalen Stand: Vollflächen-Fehler im Layout des leeren Zustands (10.11). |
| Offline | `StatusRow` "Offline. Änderungen werden gespeichert, sobald du wieder online bist."; Abhaken, Hinzufügen, Löschen gehen in die dauerhafte Warteschlange; Zeilen tragen das Sync-Zeichen am Kreis; Präsenz wird nicht angezeigt (10.2); "Liste beitreten" ist im Titelmenü deaktiviert (10.7). |
| Modul aus | Elemente des Moduls verschwinden ohne Lücke (Tabelle in 10.3.6). Der Markt-Chip bleibt immer (Kern). |
| Kill-Switch Angebote | Wie Modul aus; Gelb kommt auf dem Screen nicht mehr vor; keine Ersparnis-, Prospekt- oder Regions-Zeile; wirkt beim nächsten Öffnen des Tabs. |
| Pro gesperrt | Der Screen ist Kern und nie gesperrt. Pro erscheint nur als Hinweis-Zeile nach dem Aha-Moment oder an einer Hinweis-Aktion, die ein Pro-Feature auslöst (10.3.7). |
| Pro-Status unbekannt | Keine Pro-Hinweise; Pro-Aktionen verhalten sich wie beim zuletzt bekannten Status (00 13). |

### Interaktionen, Bewegung, Haptik

| Geste | Ergebnis | Bewegung | Haptik |
|---|---|---|---|
| Titel tippen | Titelmenü wächst aus dem Titel (10.7) | `springMenu` | keine |
| Avatar tippen | Sheet "Profil" groß (01 4) | `springSheet` | keine |
| `person.crop.circle.badge.plus` | Sheet "Liste teilen" mittel (Kapitel 11) | `springSheet` | keine |
| `ellipsis` | Listenmenü wächst aus dem Knopf (10.8) | `springMenu` | keine |
| Abhak-Kreis tippen (vordere 56 pt der Zeile, K-36) | Kreis füllt sich vom Mittelpunkt, Häkchen zeichnet sich, Text wird durchgestrichen; "11 offen" rollt auf "10 offen"; Rückgängig-Hinweis "Bananen abgehakt · Widerrufen" (4 s); nach 0,6 s wandert die Zeile in "Erledigt (3)" | `springQuick`, dann `springMove`, Ziffern `springDigits` | leichter Impuls im Frame des Füllens; beim letzten offenen Artikel Erfolg |
| Name tippen | Artikel-Sheet mittel (Kapitel 11) | `springSheet` | keine |
| Zeile nach links wischen | "Bearbeiten", "Löschen"; volles Wischen löscht sofort, "Milch gelöscht · Widerrufen" | folgt 1:1, Loslassen `springFling` | leichter Impuls beim Überschreiten der Schwelle |
| Zeile lange drücken | Kontextmenü (Bearbeiten, Menge ändern, Kategorie ändern, Löschen); danach Ziehen zum Umsortieren, auch in einen anderen Gang | Anheben 1,03 mit `shadowFloat`, Nachbarn `springStandard` | Kontextmenü systemseitig; Auswahl beim Einrasten |
| Hinweis-Aktion tippen | Aktion des Hinweises (10.3.4) | Zeile klappt mit `springStandard` zusammen | keine (Fehler: Fehler-Haptik) |
| Vorschlag tippen | Artikel kommt auf die Liste (10.5) | neue Zeile wächst ein, Vorschlag klappt zusammen, `springStandard` | keine |
| "Erledigt (2)" tippen | Auf- bzw. zuklappen, Zustand pro Liste gemerkt | `springStandard`, Chevron dreht sich mit | keine |
| Nach unten ziehen | Aktualisieren (System-`CupertinoSliverRefreshControl` mit Standarddarstellung): Liste, Mitglieder, Präsenz und Hinweis-Kandidaten | System | keine |
| Tab "Liste" erneut tippen oder Statusleiste tippen | nach oben scrollen | Systemscrollen | keine |
| Tippen in die Liste bei offener Tastatur, Scrollbeginn | Tastatur schließt, Tab-Bar kommt zurück | `springStandard` | keine |

Regeln:
- **Hinzufügen** über das Accessory: neue Zeile wächst in ihrem Gang ein; liegt der Gang außerhalb des sichtbaren Bereichs, scrollt die Liste nicht, das Accessory zeigt kurz "Milch → Milchprodukte" (00 10.3, 01 10.1).
- **Scroll-Anker:** Ändert sich etwas oberhalb der aktuellen Leseposition (Zeile von anderen eingefügt, `StatusRow` erscheint, Präsenz bricht anders um), korrigiert die Liste den Scroll-Versatz im selben Frame, damit das, worauf man schaut, stehen bleibt (E10-05).
- **Reduce Motion:** Abgehakte Zeilen bleiben durchgestrichen an ihrem Platz und wandern erst nach 1 s ohne Scrollen und Tippen (K-12); Zahlen blenden über; Menüs blenden über statt zu wachsen.
- **Haptik nur bei eigenen Aktionen.** Was andere live abhaken, löst auf diesem Gerät keine Haptik aus.

### Große Schrift, 320 pt Breite und niedrige Bildschirme

Ziel: Die erste Artikelzeile bleibt im ersten Bild sichtbar, auch auf dem iPhone SE (375 × 667 pt) mit AX3 und auf dem iPhone 13 Pro mit Anzeigezoom "Größerer Text" (320 × 693 pt). Dafür gibt es genau einen Hebel: Die Sektion "Für heute" zeigt weniger Hinweise oder rückt ans Ende der Liste. Die Entscheidung fällt aus Textgrößen-Kategorie und Höhenklasse (`DesignScope`, E10-04), nicht durch Messen nach dem Frame.

| Textgröße | Höhe ab 700 pt (13, 13 Pro, 14 bis 17, Max) | Höhe unter 700 pt (SE 667, 13 Pro mit Anzeigezoom 693) |
|---|---|---|
| xS bis xxL | "Für heute" oben, bis 2 Hinweise | oben, bis 2 Hinweise |
| xxxL | oben, bis 2 | oben, 1 Hinweis |
| AX1 bis AX3 | oben, 1 Hinweis | "Für heute" steht am Ende, zwischen letztem Gang und "Vielleicht auch", bis 2 Hinweise |
| AX4, AX5 | am Ende, bis 2 | am Ende, bis 2 |

Rechnung für iPhone SE, AX3 (Werte aus 00 5.3, gerundet): Statusleiste 20, obere Zeile 44, Titel einzeilig 63, Metazeile 48 + 4 + Avatar-Zeile 28 = 80, Abstand 24, Gang-Titel 52 + 8 = 60, erste Artikelzeile (Name 52, Menge darunter 52, Innenabstand 22) = 126. Summe 417 pt. Bodenebene: Accessory 78, 8, Tab-Bar 49, 8 = 143 pt. 417 + 143 = 560 pt von 667 pt; selbst ein zweizeiliger Titel (+63) passt noch (623 pt). Für 320 × 693 mit AX3 wird zusätzlich der große Titel einzeilig (Regel unten); dann passt die erste Zeile vollständig (rund 670 von 693 pt).

Weitere Regeln:
- **Ab AX1** gilt das AX-Layout der Zeilen (00 6.4): Sektionen randlos auf `bgPlain`, Menge und Schild unter dem Namen, Artikelbilder aus, Kreis oben bündig zur ersten Textzeile. Gang-Titel brechen um.
- **Großer Titel:** bis 2 Zeilen, dann Ellipse (00 5.3). Auf schmalen Breiten (unter 350 pt) ab AX1 nur eine Zeile; der volle Name steht im Titelmenü und in VoiceOver.
- **Metazeile:** `Wrap`. Bei 320 pt bricht sie in zwei Zeilen (Chip, dann "11 offen"); ab AX1 mit niedriger Höhe wandert der Avatar-Stapel der Mitglieder in die Zeile 1 (ohne Text "Mit Lena"; der Text bleibt für VoiceOver und erscheint bei Langdruck im Large Content Viewer). Präsenz-Text bleibt immer sichtbar, weil er handlungsrelevant ist.
- **Hinweis-Zeilen:** Text bis 3 Zeilen, nie abgeschnitten. Ist die Textspalte schmaler als 160 pt (320 pt Breite ab xL, 375 pt ab AX1), steht die schlichte Aktion unter dem Text, linksbündig an der Textkante (E10-18).
- **Accessory:** wächst mit der Schrift (00 12.4); "Einkaufen" nur als Symbol-Kreis bei 320 pt und ab xxxL (00 6.3).
- **Tab-Bar:** Beschriftungen unter 350 pt und ab AX1 aus, Large Content Viewer bei Langdruck.

### VoiceOver

Reihenfolge: Titel ("Liste wechseln, Wocheneinkauf, 11 offen, Taste", Überschrift), Avatar ("Profil und Einstellungen"), Toolbar ("Liste teilen", "Mehr"), Metazeile ("Markt: Lidl, ändern"; "11 offen"; "Geteilt mit Lena"), Hinweise, Gang-Sektionen (Überschrift "Obst und Gemüse, 4 offen"), Zeilen ("Avocados, Menge 2, im Angebot 0,79 Euro laut Händler, nicht erledigt"; Aktionen Bearbeiten, Menge ändern, Verschieben, Löschen), Vielleicht auch, Erledigt, zuletzt Bodenebene. Änderungen durch andere werden höflich angesagt (10.2). Zwei-Finger-Doppeltippen (Magic Tap) fokussiert "Artikel hinzufügen" (E10-12).

### Was sich gegenüber heute ändert

- Die Startseite ist kein Dashboard mehr, sondern die Liste selbst. Das heutige Listen-Detail (`/lists/:id`, eigener Screen ohne Tab-Bar) wird zur Wurzel des Tabs; die Route wählt nur noch die Liste.
- Gruß, Avo-Streifen, sechs Karten, Listen-Index, Angebote-Streifen, Verlaufszeile, Material-Snackbars, Fortschritts-Haarlinie, "Einkauf abschließen"-Pille am Listenende, Empfehlungs-Karte oben und Preis-Leiste über der Eingabe entfallen.
- Hinweise erscheinen nie nachträglich (heute springen Karten nach Datenankunft ins Layout), der Preisvergleich entfällt, Angebote zeigen nur den Markt der Liste.
- Dateien: siehe 10.14.

### Bildbeschreibung für ChatGPT

Hochformat-Screenshot eines iPhone 17 Pro im hellen Modus, gestaltet wie eine vorinstallierte Apple-App aus iOS 27 (Familie Erinnerungen): Hintergrund #F2F2F7, weiße inset-gruppierte Sektionen mit 26 pt Eckenradius ohne Schatten, Systemschrift SF Pro, Text #000000, Metadaten #636366, einzige Handlungsfarbe Avocado-Grün #3F7A1F. Oben rechts zwei runde, milchig-transparente Liquid-Glass-Knöpfe als eine Gruppe (Person mit Plus, drei Punkte); darunter links der große fette Titel "Wocheneinkauf" mit kleinem grauem Chevron nach unten, rechts daneben ein runder Profilfoto-Avatar ohne Glas. Unter dem Titel eine graue Kapsel #E9E9EE mit blauem Punkt #0050AA und "Lidl", daneben "11 offen", darunter ein kleiner runder Avatar und "Mit Lena". Es folgt die Sektion "Für heute" mit zwei Zeilen: Kalender-Symbol und "Heute im Plan: Ofengemüse mit Feta. Feta und Paprika fehlen noch." mit grünem Textknopf "Hinzufügen", sowie Etikett-Symbol und "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" mit grauem Chevron. Darunter die Sektion "Obst & Gemüse" mit grauer "4" rechts im Titel und den Zeilen Bananen, Avocados (rechts "2" in abgerundeten Ziffern und ein kleines gelbes Preisschild #FFD60A mit "0,79 €"), Cherrytomaten "250 g" und Gurke, jede mit leerem grauem Abhak-Kreis #8A8A8E und kleinem grauem Linien-Symbol; die nächste Sektion "Bäckerei & Frischetheke" ist angeschnitten. Unten schweben eine milchige Glas-Kapsel mit Plus, "Artikel hinzufügen" und Zettel-Scan-Symbol sowie daneben eine grün getönte Glas-Kapsel mit Einkaufswagen und "Einkaufen", darunter die Glas-Tab-Bar mit "Liste" (ausgewählt, grün), "Rezepte", "Plan" und abgesetzt rechts ein runder Glas-Kreis mit kleiner brauner Kugel #7A4A24 in hellgrünem Ring #C9DE6E. Kein Maskottchen, keine Karten, keine Großbuchstaben-Überschriften.

**Zweites Bild (große Schrift):** Derselbe Screen auf einem iPhone SE (kleiner Bildschirm mit Home-Taste) mit sehr großer Bedienungshilfen-Schrift (AX3), hell, Hintergrund #FFFFFF randlos ohne inset-Sektionen. Oben einzeilig groß "Wocheneinkauf" mit Chevron und Avatar, darunter in großer Schrift die graue Kapsel "● Lidl" und "11 offen", darunter nur ein kleiner Avatar. Direkt danach der Gang-Titel "Obst & Gemüse" fett und eine einzige große Artikelzeile: leerer grauer Kreis #8A8A8E oben bündig, "Bananen" in großer Schrift, keine Bilder. Die Sektion "Für heute" ist nicht oben zu sehen. Unten eine höhere Glas-Kapsel "Artikel hinzufügen" mit einem runden grün getönten Einkaufswagen-Knopf daneben und die Glas-Tab-Bar nur mit Symbolen, ohne Beschriftungen, plus dem Avo-Kreis. Nichts ist abgeschnitten oder überlappt.

---

## 10.2 Metazeile und Präsenz

### Zweck und Einstieg

- **Hauptfrage:** Für welchen Markt ist diese Liste, wie viel ist offen, und kauft gerade jemand ein?
- Immer sichtbar unter dem Titel von 10.1; scrollt mit dem großen Titel weg (eingeklappt übernimmt der Untertitel "11 offen · Lidl", E10-03).

### Aufbau

**Zeile 1** (`Wrap`, Abstand 8 pt, vertikal zentriert):
1. `StoreChip` (Teil B, 00 12.10): gesetzt "● Lidl ⌄"; vorgeschlagen "Lidl?" mit gestricheltem Rand (Tippen fragt "Ist das deine Lidl-Liste?" mit "Ja" / "Anderer Markt"); kein Markt "Markt wählen" mit `storefront` in `labelSecondary`. Tippen öffnet das Markt-Sheet (Kapitel 12).
2. `RollingNumber` mit Text: "11 offen" (`subheadline`, `label`, tabellarische Ziffern; nur die Ziffern rollen, E10-11). Bei 0 offenen Artikeln: "Alles erledigt"; bei leerer Liste entfällt die Zahl.

**Zeile 2** (nur geteilte Listen, `PresenceLine`, 00 12.29; 4 pt unter Zeile 1):
- **Ruhig:** Avatar-Stapel 20 pt (höchstens 3, dann "+n") und "Mit Lena" bzw. "Mit Lena und Tom" bzw. "Mit Lena, Tom und 2 weiteren" (`subheadline`, `labelSecondary`).
- **Jemand kauft ein:** Avatar der Person mit 8-pt-Punkt `presence` unten rechts und "Lena kauft gerade bei Lidl ein" (`subheadline`, `label`); der Punkt pulsiert beim Erscheinen einmal (`springCelebrate` auf die Punktgröße, keine Schleife). Ohne bekannten Markt: "Lena kauft gerade ein". Mehrere: "Lena und Tom kaufen gerade ein".
- Tippen auf Zeile 2 öffnet Listen-Info an der Stelle Mitglieder (Kapitel 11).

### Präsenz: Regeln

- **Beginn:** wenn ein Mitglied den Einkaufsmodus dieser Liste startet (Kapitel 11). Normales Abhaken außerhalb des Einkaufsmodus erzeugt keine Präsenz.
- **Ende:** "Einkauf beenden"; Einkaufsmodus verlassen und 5 Minuten im Hintergrund (01 10.2); 30 Minuten ohne Abhaken; Verbindung des Einkäufers länger als 5 Minuten weg.
- **Eigene Präsenz** wird auf dem eigenen Gerät nicht angezeigt.
- **Sichtbar nur für Mitglieder.** Gezeigt wird höchstens der Marktname, nie ein Ort oder eine Entfernung.
- **Offline (eigenes Gerät):** Zeile 2 zeigt den ruhigen Zustand, weil Präsenz nicht prüfbar ist.
- **Daten:** eigene Tabelle bzw. Realtime-Präsenz (E10-10, Teil A); dieselbe Quelle speist Titelmenü (10.7), Alle Listen, Mitteilung `shopping_started` (01 8.2) und die Hinweis-Zeile "Präsenz in anderer Liste" (10.3).

### Live-Änderungen anderer Mitglieder

| Ereignis | Darstellung | Bewegung | Ansage (VoiceOver, höflich) |
|---|---|---|---|
| Lena hakt Gouda ab | Kreis füllt sich, Lenas Avatar (16 pt) sitzt 2 s unten rechts am Kreis, dann wandert die Zeile nach "Erledigt"; "11 offen" rollt auf "10 offen" | `springQuick`, `springMove`, `springDigits` | "Lena hat Gouda abgehakt" |
| Lena hakt in 10 s mehr als 3 Artikel ab | wie oben pro Zeile | wie oben | gebündelt: "Lena hat 4 Artikel abgehakt" |
| Lena fügt Paprika hinzu | Zeile wächst in "Obst & Gemüse" ein, Unterzeile "von Lena" | `springStandard`; oberhalb der Leseposition per Scroll-Anker | "Lena hat Paprika hinzugefügt" |
| Lena löscht einen Artikel | Zeile klappt zusammen, ohne Meldung | `springStandard` | keine |
| Lena beginnt einzukaufen | Zeile 2 wechselt von "Mit Lena" auf "Lena kauft gerade bei Lidl ein" | Text überblendet (`fadeReduced`), Punkt pulsiert einmal | "Lena kauft gerade ein" |
| Rückkehr aus dem Hintergrund (über 2 s) | einmal nachladen, Unterschiede wie oben ohne Einzelansagen | wie oben | eine Zusammenfassung, falls sich etwas geändert hat: "3 Änderungen von Lena" |

Mitteilungen derselben Liste werden unterdrückt, solange man sie im Vordergrund ansieht; sonst gebündelt (K-39, Kapitel 19).

### Zustände

| Zustand | Zeile 1 | Zeile 2 |
|---|---|---|
| Nicht geteilt, Markt gesetzt | "● Lidl ⌄ · 11 offen" | entfällt |
| Nicht geteilt, kein Markt | "Markt wählen · 4 offen" | entfällt |
| Geteilt, niemand kauft ein | wie oben | "Mit Lena" |
| Geteilt, Lena kauft ein | wie oben | "Lena kauft gerade bei Lidl ein" mit Punkt |
| Modul Angebote aus oder Kill-Switch | Chip bleibt (Kern), ohne jede Angebotsangabe | unverändert |
| Offline | unverändert, Zahl aus lokalem Stand | ruhiger Zustand |
| Leere Liste | nur Chip | wie oben |

### Große Schrift und 320 pt

Siehe 10.1: Zeile 1 bricht um; ab AX1 bei niedriger Höhe wandert der Stapel ohne "Mit Lena" in Zeile 1. Der Präsenz-Text bleibt immer ausgeschrieben und bricht um. Chip-Punkt wächst nur bis AX2 (00 5.3).

### Was sich gegenüber heute ändert

Heute zeigt die Liste unter dem Serifen-Titel "3 offen · 5 Artikel" in 11 pt und eine 3-pt-Haarlinie; Präsenz gibt es nicht; geteilte Listen erkennt man nur am Personen-Icon im Index. Neu: Markt-Chip, rollende Zahl, Mitglieder und Präsenz live, Ansagen. Betroffen: `list_detail_screen.dart` (Kopf), `list_detail_parts.dart` (Haarlinie entfällt), `items_provider.dart` (Herkunft "von anderen" für den 2-s-Avatar), neu `list_presence_provider.dart` (A).

### Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screenshot im dunklen Modus derselben App: Hintergrund #000000, Sektionen #1C1C1E mit 26 pt Radius, Text #FFFFFF, Metadaten #98989F, Akzent hellgrün #A6D45F. Oben der große fette Titel "Wocheneinkauf" mit grauem Chevron, rechts ein runder Foto-Avatar, darüber rechts zwei runde dunkle Liquid-Glass-Knöpfe. Darunter eine dunkelgraue Kapsel #2C2C2E mit blauem Punkt #0050AA und "Lidl" sowie "10 offen", und in der Zeile darunter ein kleiner runder Avatar einer Frau mit einem hellgrünen Punkt #A6D45F unten rechts und dem weißen Text "Lena kauft gerade bei Lidl ein". In der Sektion "Milchprodukte" ist die Zeile "Gouda in Scheiben" gerade abgehakt: gefüllter hellgrüner Kreis mit dunklem Häkchen #0E1A06, an dessen unterer rechter Ecke ein winziger Avatar von Lena sitzt, der Text grau #98989F und durchgestrichen; darunter "Milch" mit "2" und einem gelben Preisschild #FFD60A "0,99 €" und "Naturjoghurt" mit "500 g", beide mit leeren grauen Kreisen #7C7C80. Unten die dunklen Glas-Elemente "Artikel hinzufügen", die getönte Kapsel "Einkaufen" und die Tab-Bar mit Avo-Kreis (braune Kugel #8A5A30, Ring #C9DE6E). Keine Benachrichtigungs-Banner, kein Maskottchen.

---

## 10.3 Sektion "Für heute" und Hinweis-Zeilen

### 10.3.1 Zweck und Einstieg

- **Hauptfrage der Sektion:** Gibt es heute etwas, das ich wegen dieser Liste oder meines Tages tun sollte?
- Ersetzt alle Karten der heutigen Startseite (00 12.12, 01 5.2). Höchstens zwei `HintRow`s (K-38), nach Relevanz. Die Sektion entfällt komplett, wenn es keinen Hinweis gibt; dann beginnt die Liste direkt mit dem ersten Gang.

### 10.3.2 Aufbau einer Hinweis-Zeile

`HintRow` (00 12.12) in der `InsetSection` "Für heute": führendes Symbol 16 pt (`labelSecondary`; `warning` nur bei fehlender Postleitzahl), Text `callout` in `label` bis 3 Zeilen, rechts eine schlichte Aktion in `action` ("Hinzufügen", "Erledigt", "Öffnen") oder `chevron.right`. Zeilenhöhe nach Inhalt, mindestens 44 pt. Zwischen zwei Hinweisen die normale Trennlinie ab der Textkante. Kein Maskottchen, kein getöntes Quadrat, keine Farbe pro Hinweis-Art. Beim Pro-Hinweis ersetzt eine `ProBadge` das Symbol.

### 10.3.3 Katalog

Rang 1 ist am wichtigsten. "Familie" begrenzt Wiederholungen (10.3.5). Wortlaut verbindlich; Zahlen und Namen aus echten Daten.

| Rang | Hinweis | Erscheint, wenn | Text (Beispiel) | Symbol | Aktion → Ziel | Modul | Familie | Inhalt von |
|---|---|---|---|---|---|---|---|---|
| 1 | Präsenz in anderer Liste | Ein Mitglied kauft für eine **andere** eigene Liste ein | "Tom kauft gerade für Grillabend ein, bei REWE." | `cart` | "Öffnen" → wechselt die Liste von heute (Überblendung) | Kern | Menschen | A |
| 2 | Markt am Standort | "Automatische Markt-Erkennung" an, Standort erlaubt, man ist in einem Markt, für den es eine **andere** Liste gibt | "Du bist bei Lidl. Wocheneinkauf ist deine Lidl-Liste." | `location` | "Öffnen" → wechselt die Liste von heute | Kern (Märkte) | Ort | B |
| 3 | Wochenplan heute | Rezept für heute geplant, Zutaten fehlen auf der Ziel-Liste | "Heute im Plan: Ofengemüse mit Feta. Feta und Paprika fehlen noch." | `calendar` | "Hinzufügen" → fehlende Zutaten auf die Liste von heute, Rückgängig-Hinweis; Text tippen → Rezeptdetail | Wochenplan | Plan | B |
| 3 | Wochenplan, Zutaten auf anderer Liste | wie oben, Zutaten stehen auf einer anderen Liste | "Zutaten für heute stehen auf Grillabend." | `calendar` | "Öffnen" → wechselt die Liste | Wochenplan | Plan | B |
| 3 | Wochenplan morgen | ab 20 Uhr, Rezept für morgen mit fehlenden Zutaten | "Morgen im Plan: Linsencurry. 3 Zutaten fehlen noch." | `calendar` | "Hinzufügen" | Wochenplan | Plan | B |
| 4 | Kalorien | 16 bis 21 Uhr, Ziel gesetzt, mindestens 150 kcal übrig, passendes Rezept mit gespeicherten Nährwerten | "Noch 640 kcal heute. Ideen fürs Abendessen" | `flame` | `chevron.right` → "Was kann ich noch essen?" (`/calories/ideas`, Push im Tab Liste, E10-08) | Kalorien | Tag | B |
| 5 | Ersparnis dieser Liste | Markt der Liste gesetzt, echte PLZ, mindestens 2 Artikel im Angebot dieses Markts | "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" | `tag` | `chevron.right` → Angebote dieser Liste (`/offers/list/:listId`, Sheet mittel) | Angebote | Angebote | B (`ListOfferSummary`) |
| 5 | Region fehlt | Modul an, Markt gesetzt, keine echte PLZ und kein Standort; höchstens einmal pro Woche | "Für Angebote in deiner Region: Postleitzahl festlegen" | `exclamationmark.triangle.fill` in `warning` | `chevron.right` → Sheet "Region für Angebote" (Kapitel 12) | Angebote | Angebote | B |
| 6 | Offener Betrag (eine Person) | Modul Kosten teilen, genau ein offener Betrag | "Lena schuldet dir 4,20 € für Wocheneinkauf vom 3. Nov." bzw. "Du schuldest Tom 6,80 € für Grillabend." | `eurosign.circle` | "Erledigt" bzw. "Zurückgezahlt" → als bezahlt markiert, Rückgängig-Hinweis; Text tippen → Offene Beträge | Kosten teilen | Geld | B |
| 6 | Offene Beträge (mehrere) | mehr als ein offener Betrag | "3 offene Beträge, zusammen 18,40 €" | `eurosign.circle` | `chevron.right` → Offene Beträge (`/splits`) | Kosten teilen | Geld | B |
| 7 | Einkauf teilen | geteilte Liste, Einkauf der letzten 7 Tage, nicht aufgeteilt | "Einkauf von gestern bei Lidl mit Lena teilen? 42,60 €" (Betrag nur, wenn beim Abschluss eingetragen) | `eurosign.circle` | "Teilen" → Sheet Kosten teilen (`/history/:tripId/split`) | Kosten teilen | Geld | B |
| 8 | Persönlicher Prospekt | mindestens 3 Artikel aus dem eigenen Kaufrhythmus, die nicht auf der Liste stehen, sind im Angebot des Listen-Markts | "5 Sachen, die du oft kaufst, sind diese Woche bei Lidl im Angebot, in deiner Region" | `tag` | `chevron.right` → Angebote der Woche, gefiltert "Passend zu dir" (`/offers`) | Angebote | Angebote | B |
| 9 | Kosten teilen vorschlagen | einmalig nach dem ersten Teilen einer Liste, Modul aus (01 10.3) | "Kosten teilen einschalten? Praktisch für gemeinsame Einkäufe." | `eurosign.circle` | "Einschalten" → Modul an, Rückgängig-Hinweis | Kern | Einmalig | A |
| 9 | Pro nach dem Aha-Moment | einmalig nach dem ersten abgeschlossenen Einkauf oder dem ersten Wochenplan auf der Liste; Pro-Status bekannt und nicht Pro | "14 Tage {pro} gratis testen" | `ProBadge` statt Symbol | "Ansehen" → Paywall wächst aus der Zeile (`/pro`) | Kern | Einmalig | A |
| 9 | Tipp | einmalige Tipps am Ort (K-21), höchstens einer pro Tag | "Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei." · "Tipp: Halte einen Artikel gedrückt, um ihn in einen anderen Gang zu ziehen." · "Tipp: Teile die Liste, dann seht ihr, wer gerade einkauft." | `lightbulb` (E10-06) | `xmark` als schlichte Aktion "Verstanden" | Kern | Einmalig | A |

Nicht mehr erlaubt (Plan 8): jeder Vergleich zwischen Märkten, Korbsummen, "bei X wäre es Y € günstiger", Rabatt-Prozente ohne Händlerangabe, Ersparnis mit Ersatz-PLZ. Der heutige Preisvergleich entfällt ersatzlos.

### 10.3.4 Auswahl und Stabilität

1. **Kandidaten** liefert jede Quelle synchron aus einem lokalen, kontobezogenen Cache (E10-01). Die Quellen rechnen im Hintergrund neu (App-Start nach dem ersten Frame, Listenwechsel, Rückkehr in die App, höchstens alle 6 h bei Angeboten) und schreiben nur den Cache.
2. **Beim Öffnen des Tabs** (Kaltstart, Tab-Wechsel zu Liste, Rückkehr aus dem Hintergrund nach mehr als 60 s, Wechsel der Liste von heute) wählt Teil A aus den gültigen Kandidaten nach Rang aus; bei gleichem Rang gewinnt der neuere. Danach steht die Auswahl fest, bis der Tab das nächste Mal geöffnet wird. Neu berechnete Hinweise erscheinen nie während man liest (00 12.12).
3. **Höchstens zwei**, nach Höhenregel ggf. einer (10.1). Höchstens einer pro Familie "Angebote", "Geld", "Plan", "Einmalig". Ein Pro-Hinweis nie am selben Tag wie ein anderer einmaliger Hinweis und höchstens einer pro Tag (00 16.5).
4. **Gegen Banner-Gewöhnung:** Ein Hinweis, der an drei Tagen hintereinander gezeigt und nicht angetippt wurde, pausiert zwei Tage; dann rückt der nächste nach.
5. **Gültigkeit beim Anzeigen:** Ein Kandidat wird beim Öffnen gegen den lokalen Stand geprüft (Präsenz noch aktiv, Betrag noch offen, Zutaten noch nicht auf der Liste, Angebot noch gültig). Ungültige fallen still weg.
6. **Inhalt ändert sich während des Lesens nur durch eigene Aktionen:** Fügt man Feta hinzu, wird aus "Feta und Paprika fehlen noch." im selben Moment "Paprika fehlt noch."; aus "4 von 11" wird "4 von 12" (Ziffern rollen). Wächst oder schrumpft die Zeile dadurch, mit `springStandard`.
7. **Ausnahme Ziehen zum Aktualisieren:** Nach einem bewussten Aktualisieren darf die Auswahl neu gebildet werden, sobald die Aktualisierungsanzeige verschwunden ist; Änderungen mit `springStandard`.

### 10.3.5 Interaktionen

| Geste | Ergebnis |
|---|---|
| Schlichte Aktion tippen | führt aus; die Zeile klappt mit `springStandard` zusammen; Rückgängig-Hinweis, wo umkehrbar ("Feta und Paprika hinzugefügt · Widerrufen", "Als bezahlt markiert · Widerrufen"); der frei gewordene Platz wird bis zum nächsten Öffnen nicht nachgefüllt |
| Text der Zeile tippen | öffnet das Ziel aus der Tabelle; bei Zeilen mit `chevron.right` ist die ganze Zeile die Taste |
| Nach links wischen | "Ausblenden" (für heute); volles Wischen blendet sofort aus, "Hinweis ausgeblendet · Widerrufen" |
| Lange drücken | Kontextmenü (unten) |
| Pro-Aktion | Paywall wächst aus der Zeile (`springMorph`), Feature oben; nach dem Kauf läuft die ursprüngliche Aktion weiter (01 10.10) |
| Fehler beim Ausführen | Zeile bleibt, darunter "Das hat nicht geklappt. Erneut versuchen" in `danger` mit `exclamationmark.circle`; Fehler-Haptik |

Keine Haptik bei Hinweis-Aktionen (normale Knöpfe), außer der Wischschwelle (leichter Impuls) und Fehlern.

### 10.3.6 Zustände

| Zustand | Verhalten |
|---|---|
| Keine Hinweise | Sektion entfällt ohne Lücke. |
| Erster Start, frisches Konto | Kein Cache, also keine Hinweise beim ersten Öffnen; Ausnahme: der Tipp "2 Milch" direkt nach dem Onboarding, weil er durch die eigene Aktion entsteht (01 10.9). |
| Offline | Hinweise aus dem Cache bleiben, solange gültig. Aktionen, die Netz brauchen (Prospekt, Region), öffnen ihr Ziel, das dort seinen Offline-Zustand zeigt. "Hinzufügen" und "Erledigt" gehen in die Warteschlange. Präsenz-Hinweise entfallen. |
| Modul Angebote aus | Ersparnis, Region, Prospekt entfallen. |
| Modul Wochenplan aus | Plan-Hinweise entfallen. |
| Modul Kalorien aus | Kalorien-Hinweis entfällt. |
| Modul Kosten teilen aus | Beträge und "Einkauf teilen" entfallen (Daten bleiben); einmalig der Vorschlag "Kosten teilen einschalten?". |
| Modul Avo aus | ohne Wirkung; kein Hinweis trägt den Namen Avo (01 3). |
| Kill-Switch Angebote | wie Modul aus, ohne Spur; Kandidaten werden verworfen, nicht nur ausgeblendet. |
| Pro gesperrt | Hinweis-Aktionen, die ein Pro-Feature auslösen (z. B. "Hinzufügen" beim Wochenplan, falls der Owner ihn zu Pro macht), tragen eine `ProBadge` vor der Aktion. |
| Pro-Status unbekannt | kein Pro-Hinweis; Pro-Aktionen wie zuletzt bekannt. |
| "Nicht mehr zeigen" gewählt | Art dauerhaft aus; wieder einschaltbar in Einstellungen > Listen > "Hinweise für heute" (E10-14). |

### 10.3.7 Kontextmenü einer Hinweis-Zeile

- **Zweck:** Wie werde ich diesen Hinweis los, ohne die Funktion zu verlieren?
- **Aufbau** (`AppMenu` auf Glas, wächst unter der angehobenen Zeile; dahinter `scrim`): Gruppe 1 "Heute ausblenden" (`eye.slash`), "Nicht mehr zeigen" (`minus.circle`); Gruppe 2 je nach Art: Ersparnis "Angebote für diese Liste ausblenden" (`tag.slash`, ruft `setOffersHiddenForList`), Betrag "Als bezahlt markieren" (`checkmark`), Plan "Wochenplan öffnen" (`calendar`), Präsenz "Mitteilungen für Grillabend" (`bell`).
- **Bewegung:** `springMenu` aus der Zeile; Schließen durch Tippen daneben.
- **VoiceOver:** Alle Einträge sind zusätzlich Aktionen der Zeile.
- **AX und 320 pt:** Menübreite = Bildschirm minus 2 × 16 pt; Einträge brechen um.

### 10.3.8 Was sich gegenüber heute ändert

Heute: bis zu sechs Karten (Teilen, Nachkauf, Prospekt, Kalorien, Preisvergleich, Schulden) in Paper-Hüllen mit Großbuchstaben-Kickern, Icons in getönten Kreisen, 24-pt-Schließen-"x", erscheinen nach Datenankunft (Layout-Sprung), Reihenfolge nach Onboarding-Prioritäten, Preise mit Punkt ("0.99 €"), "Ideen fürs Abendessen" auch morgens, Schlummer-Daten gerätweit statt pro Konto, "Als bezahlt markieren" ohne Fehlerbehandlung und ohne Rückgängig. Neu: eine Sektion, höchstens zwei Zeilen, Auswahl beim ersten Frame, Rang statt Onboarding-Prioritäten (K-22), Zahlen über `intl`, Uhrzeitfenster, kontobezogener Cache, Rückgängig überall. Dateien: 10.14.

### Bildbeschreibung für ChatGPT (Kontextmenü)

iPhone-17-Pro-Screenshot im hellen Modus derselben App, der Inhalt im Hintergrund leicht abgedunkelt. In der Mitte ist eine einzelne weiße Zeile mit 26 pt Eckenradius angehoben und leicht vergrößert: links ein graues Etikett-Symbol, Text in Schwarz #000000 "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region", rechts ein grauer Chevron. Direkt darunter wächst ein milchig-transparentes Liquid-Glass-Menü mit 20 pt Radius heraus, Einträge links Text und rechts ein schlichtes Liniensymbol: "Heute ausblenden" (durchgestrichenes Auge), "Nicht mehr zeigen" (Kreis mit Minus), dann ein schmales Trennband, "Angebote für diese Liste ausblenden" (durchgestrichenes Etikett). Schrift SF Pro, kein Rot, keine Großbuchstaben, keine Emojis. Unten bleiben Accessory und Tab-Bar sichtbar, aber gedimmt.

---

## 10.4 Gang-Sektionen

- **Hauptfrage:** In welcher Reihenfolge finde ich die Sachen im Markt?
- **Aufbau:** je Kategorie eine `AisleSection` (00 12.9): Titel = Kategoriename (`headline`), rechts die Zahl offener Artikel (`numberS`, `labelSecondary`), darunter `ItemRow`s (00 12.8) mit `CheckCircle` 24 pt, Artikelbild 28 pt (Slot `ArticleImage`, Teil B; bis die Avo Symbols fertig sind, das Kategorie-Symbol, 00 9.4), Name, optional Unterzeile "von Lena" bzw. Notiz, rechts Menge und `ItemOfferBadge`.
- **Reihenfolge:** "Reihenfolge im Markt" der Liste bzw. ihres Markts (Kapitel 11); ohne Markt die Standard-Reihenfolge. Innerhalb eines Gangs die eigene Reihenfolge (Umsortieren), sonst Erstellzeit. Leere Gänge entfallen. Eigene Kategorien mit Symbol `tag`.
- **Neue Artikel** ohne bekannte Kategorie: lokal sofort zugeordnet (Schlüsselwörter, gelernte Zuordnung); erst wenn nichts passt, "Sonstiges". Die KI bestätigt später; ändert sie die Kategorie, wandert die Zeile mit `springStandard` (00 10.3).
- **Zustände, Gesten, AX:** wie 10.1 und 00 12.8. Offline ausstehende Zeilen tragen das Sync-Zeichen; nicht gespeicherte zeigen "Nicht gespeichert" (Tippen wiederholt).
- **Was sich ändert:** Großbuchstaben-Köpfe mit Laufweite 2, Drop-Zonen und Drag-Griff-Icon entfallen; die Zeile ist nicht mehr in unsichtbare Tippzonen geteilt, sondern Kreis = abhaken, Name = Sheet (K-36). Betroffen: `list_category_section.dart`, `list_item_tile.dart`, `list_drag_controller.dart` (Details Kapitel 11).

---

## 10.5 "Vielleicht auch"

### Zweck und Einstieg

- **Hauptfrage:** Was fehlt mir wahrscheinlich, ohne dass ich daran gedacht habe?
- Am Ende der offenen Gänge, vor "Erledigt". Kern, kein Modul. Ersetzt die Avo-Nachkauf-Karte und die Karte "KI-Empfehlungen" (01 5.2, 5.3). Ohne Avo-Namen (01 3).
- Abschaltbar in Einstellungen > Listen > "Vorschläge „Vielleicht auch“" (01 4).

### Aufbau

`InsetSection` "Vielleicht auch" mit bis zu 3 `ItemRow`s in der Variante Vorschlag (00 12.8): gestrichelter `CheckCircle` mit `plus`, Name (`body`, `label`), Unterzeile (`subheadline`, `labelSecondary`) mit dem Grund, rechts optional `ItemOfferBadge` (nur Modul Angebote, nur Markt der Liste).

Gründe (Wortlaut, lokalisiert, ICU-Plural):
- Rhythmus: "kaufst du etwa alle 10 Tage"
- Wochentag: "kaufst du meistens samstags"
- Häufig auf dieser Liste: "oft auf dieser Liste"
- Kombination mit Angebot: Grund bleibt, das Schild steht rechts ("0,49 €"); Tippen auf das Schild öffnet das Angebots-Sheet.

### Quellen und Regeln

- **Nachkauf** (Daten Teil B, `AvoNudgeService`; bleibt unverändert): mindestens 2 Käufe, Rhythmus 2 bis 60 Tage, nicht mehr ab 4-fach überfällig, Wochentags-Muster, Rang `dueness × habitStrength`, nichts, was schon offen auf einer Liste steht (fail closed).
- **Häufig auf dieser Liste** (Teil A, `ml_recommendations_provider.dart`): ohne KI-Ergänzungen und ohne erfundene Gründe ("Beliebtes Produkt" entfällt).
- **Pro Liste:** bevorzugt Artikel, die zuletzt über diese Liste gekauft wurden; Angebote nur vom Markt dieser Liste (heute kann ein anderer Markt gewinnen, wenn er 0,50 € günstiger ist; das entfällt).
- **Höchstens 3**, dedupliziert; Reihenfolge nach Rang. Kandidaten kommen synchron aus dem Cache (E10-01); neue Kandidaten ersetzen Zeilen beim nächsten Öffnen oder werden unten angefügt, nie oberhalb der Leseposition eingeschoben.

### Interaktionen

| Geste | Ergebnis | Bewegung |
|---|---|---|
| Zeile tippen | Artikel kommt mit Menge 1 (bzw. der üblichen Menge) und Angebotspreis (falls angetippt übernommen) auf die Liste; Vorschlag klappt zusammen, neue Zeile wächst in ihrem Gang ein; "Haferflocken hinzugefügt · Widerrufen" | `springStandard` |
| Nach links wischen | "Später" (schlummert einen eigenen Rhythmus lang, mindestens 2 Tage) | 1:1, `springFling` |
| Lange drücken | Kontextmenü: "Später erinnern" (`moon.zzz`), "Nicht mehr vorschlagen" (`minus.circle`), "Auf andere Liste …" (`list.bullet`, Untermenü mit Listen) | `springMenu` |

Keine Haptik (normales Hinzufügen). VoiceOver: "Haferflocken, kaufst du etwa alle 10 Tage, Vorschlag, Doppeltippen zum Hinzufügen"; Kontextmenü-Einträge als Aktionen.

### Zustände

| Zustand | Verhalten |
|---|---|
| Neues Konto, weniger als 2 Einkäufe | Sektion entfällt. |
| Alle Kandidaten schon auf der Liste | Sektion entfällt. |
| Liste leer | Sektion steht direkt unter dem leeren Zustand (10.10) und ist dort besonders nützlich. |
| Offline | aus dem Cache; Hinzufügen geht in die Warteschlange. |
| Modul Angebote aus, Kill-Switch | Schilder entfallen, Gründe bleiben. |
| Einstellung aus | Sektion entfällt; die Nachkauf-Mitteilung (Kapitel 19) bleibt davon unabhängig. |
| Geöffnet über Nachkauf-Mitteilung (`avo_restock`) | Die Liste scrollt so, dass der Sektionstitel im oberen Drittel steht; die Sektion ist 1,5 s mit `fillPressed` hinterlegt und blendet dann aus (`fadeReduced`, E10-07). |

AX und 320 pt: wie `ItemRow`; Unterzeile bricht um; das Schild steht ab AX1 unter dem Grund.

**Was sich ändert:** Heute fügt die Avo-Karte per Tipp irgendwo auf die Zeile in die **zuletzt geänderte** Liste ein, ohne Rückgängig, mit Material-Snackbar; die Empfehlungs-Karte oben springt nach dem Übergang ins Layout und lädt bei jeder Namensänderung neu. Neu: Ziel ist immer die Liste von heute, Rückgängig, kein Layout-Sprung, Gründe übersetzt. Betroffen: `avo_nudge_card.dart` (B, entfällt als Karte), `ml_recommendations_section.dart`, `recommendation_card.dart` (A, entfallen), `avo_nudge_provider.dart` (B, neuer Datenvertrag E10-09), `ml_recommendation_service.dart` (B, Gründe als Schlüssel statt deutscher Texte).

### Bildbeschreibung für ChatGPT (unteres Ende der Liste)

iPhone-17-Pro-Screenshot im hellen Modus derselben App, nach unten gescrollt: oben ist der Titel eingeklappt zu einer kleinen mittigen Zeile "Wocheneinkauf" mit Chevron und der grauen Unterzeile "11 offen · Lidl" unter einem weichen Verlauf aus #F2F2F7, ohne Trennlinie. Darunter die weißen Sektionen "Trockenwaren" mit Spaghetti "500 g" und Passierte Tomaten "2" und "Haushalt & Hygiene" mit Spülmittel und gelbem Preisschild #FFD60A "0,95 €", alle mit leeren grauen Kreisen #8A8A8E. Dann die Sektion "Vielleicht auch" mit drei Zeilen, deren Kreise gestrichelt grau sind und ein kleines Plus enthalten: "Haferflocken" mit grauer Unterzeile #636366 "kaufst du etwa alle 10 Tage", "Toilettenpapier" mit "kaufst du meistens samstags", "Mineralwasser" mit "oft auf dieser Liste". Darunter eine eingeklappte Sektion "Erledigt (2)" mit kleinem grauem Chevron nach rechts. Unten wie immer die Glas-Kapsel "Artikel hinzufügen", die grün getönte Kapsel "Einkaufen" #3F7A1F und die Glas-Tab-Bar mit Avo-Kreis. Kein Maskottchen, keine Karte, keine Funkel-Symbole.

---

## 10.6 "Erledigt (n)" und "Alles erledigt"

### "Erledigt (n)"

- **Hauptfrage:** Was habe ich schon, und kann ich etwas zurückholen?
- **Aufbau:** einklappbare `InsetSection`, Titel "Erledigt (2)" (`headline`; Zahl als `RollingNumber`) mit `chevron.right` (eingeklappt) bzw. `chevron.down` (offen). Standard eingeklappt; Zustand pro Liste und Gerät gemerkt. Offen: `ItemRow`s im Zustand erledigt (gefüllter Kreis `action`, Name durchgestrichen in `labelSecondary`), zuletzt Abgehaktes oben; bei von anderen Abgehaktem Unterzeile "von Lena abgehakt". Sektionsfuß (nur offen): schlichte Aktion "Einkauf abschließen".
- **Interaktionen:** Titel tippen klappt (`springStandard`). Kreis tippen holt den Artikel zurück: Kreis leert sich (`springQuick`, leichter Impuls), Zeile wandert in ihren Gang (`springMove`), "offen" rollt hoch. Wischen nach links: "Löschen" mit Rückgängig. "Einkauf abschließen" öffnet den Abschluss (`showCheckoutFlow`, Teil B, 01 10.4). "Erledigte entfernen" steht im Listenmenü (10.8).
- **Zustände:** keine erledigten Artikel: Sektion entfällt. Offline: wie überall. Reduce Motion: K-12.
- **VoiceOver:** "Erledigt, 2 Artikel, eingeklappt, Taste".

### Zustand "Alles erledigt"

- **Wann:** Der letzte offene Artikel wird abgehakt, der Einkauf ist noch nicht abgeschlossen.
- **Hauptfrage:** Bin ich fertig, und was passiert mit dem Erledigten?
- **Aufbau (an Stelle der Gänge):** `EmptyState` (00 12.26): Maskottchen "zufrieden" 96 pt (ab AX1 entfällt), Titel "Alles erledigt. Schön." (`title3`), Satz "Schließ den Einkauf ab, dann landet er im Verlauf." (`body`, `label`), prominenter Button "Einkauf abschließen" (die einzige gefüllte Akzent-Kapsel des Screens; "Einkaufen" im Accessory ist ausgeblendet, weil nichts offen ist). Darunter "Vielleicht auch" und "Erledigt (11)". Metazeile "Alles erledigt". Hinweise bleiben, wie sie beim Öffnen waren.
- **Bewegung und Haptik:** Mit dem letzten Häkchen Erfolgs-Haptik; die Gänge klappen mit `springStandard` zusammen, der leere Zustand blendet ein; das Maskottchen macht einmal einen kurzen Sprung (höchstens 1 s, Reduce Motion statisch).
- **Nach dem Abschluss:** Erfolgsmoment (00 12.35), danach ist die Liste leer: Titel "Alles erledigt. Schön.", Satz "Der Einkauf ist im Verlauf.", schlichte Aktion "Verlauf ansehen" (`/history`); darunter "Vielleicht auch". Rückgängig-Hinweis "Einkauf gespeichert · Widerrufen" (01 10.4).
- **Was sich ändert:** Heute: Pille "Einkauf abschließen" (54 pt fest) am Listenende, Bestätigungs-Alert, grüner Snackbar mit Emoji, Bewertungsdialog beim Öffnen einer vollständig abgehakten Liste. Neu: kein Alert, Rückgängig, Bewertungsanfrage frühestens nach dem dritten abgeschlossenen Einkauf und nie hier (01 5.3). Betroffen: `list_detail_parts.dart`, `shopping_trip_completion.dart` (Ablauf geht an Teil B, `showCheckoutFlow`).

### Bildbeschreibung für ChatGPT (Alles erledigt)

iPhone-17-Pro-Screenshot im hellen Modus derselben App: Hintergrund #F2F2F7, oben großer fetter Titel "Party Samstag" mit grauem Chevron und Avatar rechts, darunter grau #636366 "Alles erledigt". In der Mitte des Inhaltsbereichs eine flach gezeichnete, zufriedene Avocado-Hälfte mit braunem Kern als Maskottchen (zwei Grüntöne, keine Glanzeffekte, etwa 96 pt), darunter in Schwarz halbfett "Alles erledigt. Schön." und in normaler Schrift "Schließ den Einkauf ab, dann landet er im Verlauf.", darunter eine gefüllte, avocadogrüne Kapsel #3F7A1F mit weißem Text "Einkauf abschließen". Weiter unten eine eingeklappte weiße Sektion "Erledigt (9)" mit Chevron. Unten die Glas-Kapsel "Artikel hinzufügen" ohne Einkaufen-Knopf und die Glas-Tab-Bar mit Avo-Kreis. Ruhig, viel Luft, kein Konfetti.

---

## 10.7 Listen-Umschalter (Titelmenü)

### Zweck und Einstieg

- **Hauptfrage:** Welche andere Liste will ich jetzt sehen?
- Tippen auf den großen oder eingeklappten Titel. Auch erreichbar per VoiceOver-Aktion "Liste wechseln" und per Tastatur-Kurzbefehl auf externer Tastatur (nicht gestaltet).

### Aufbau (`AppMenu`, 00 12.24, Glas, wächst aus dem Titel)

1. **Listen** (höchstens 6, angeheftete oben mit `pin` 13 pt hinter dem Namen, dann nach zuletzt geändert; die Reihenfolge wird beim Öffnen festgelegt und springt nicht, während das Menü offen ist). Jede Zeile ist die Menüvariante der `ListRow` (00 12.6):
   - links eine 20-pt-Spalte: `checkmark` bei der aktuellen Liste, sonst bei neuen Änderungen anderer der Ungelesen-Punkt (8 pt, `unread`, E10-13), sonst leer;
   - Listen-Glyph 36 pt (Kreis in Listenfarbe, weißes Symbol);
   - Name (`body`), Unterzeile (`subheadline`, `labelSecondary`): "Lidl · mit Lena", bei Präsenz "Lena kauft gerade ein" mit `presence`-Punkt;
   - rechts offene Anzahl (`number`, `labelSecondary`), bei 0 `checkmark.circle` in `labelSecondary`.
2. Band (8 pt).
3. "Neue Liste" (`plus`) → Sheet Neue Liste (Kapitel 11); "Liste beitreten" (`link`) → Sheet Liste beitreten (Kapitel 11).
4. Band.
5. "Alle Listen" (`list.bullet`), rechts die Gesamtzahl der Listen → Push `/lists`.

### Beispielinhalt

Wocheneinkauf (ausgewählt mit Häkchen, blau, `cart`, angeheftet) "Lidl · mit Lena" 11 · Grillabend (orange, `flame`, Ungelesen-Punkt) "Tom kauft gerade ein" mit Punkt, 7 · Drogerie (lila, `drop`) 4 · Party Samstag (rosa, `party.popper`) erledigt · Band · Neue Liste · Liste beitreten · Band · Alle Listen 4.

### Zustände

| Zustand | Verhalten |
|---|---|
| Nur eine Liste | diese Liste mit Häkchen, dann die Gruppen; "Alle Listen" bleibt (dort Verlauf, Angebote, Beträge). |
| Mehr als 6 Listen | die ersten 6; "Alle Listen 9" führt zum Rest. |
| Keine Liste (10.9) | nur "Neue Liste" und "Liste beitreten". |
| Offline | Listen aus dem lokalen Stand, keine Präsenz; "Neue Liste" geht (ausstehend); "Liste beitreten" deaktiviert mit Unterzeile "Braucht eine Verbindung". |
| Modul aus, Pro | ohne Wirkung. |

### Interaktionen, Bewegung, Haptik

- Öffnen: Menü wächst aus dem Titel (Ursprung am Chevron, Skalierung 0,6 auf 1 plus Deckkraft, `springMenu`); Inhalt dahinter bleibt sichtbar, leicht abgedunkelt.
- Liste wählen: Menü schrumpft zurück in den Titel; Titel und Inhalt überblenden (`fadeReduced`, 0,2 s), die neue Liste beginnt oben; Hinweise werden für die neue Liste ausgewählt (10.3.4); "zuletzt gewählt" wird gespeichert. Keine Haptik (Wechsel ist Navigation).
- Ziehen über die Einträge mit gehaltenem Finger wählt beim Loslassen (iOS-Menüverhalten).
- Tippen daneben schließt. Reduce Motion: Überblendung statt Wachsen.

### Große Schrift und 320 pt

Menübreite höchstens Bildschirm minus 2 × 16 pt (288 pt bei 320). Namen und Unterzeilen brechen um, nie Ellipse. Ab AX1 entfällt die Unterzeile nicht, aber der Glyph wächst nicht mit. Ist das Menü höher als der Platz zwischen Titel und Bodenebene, scrollt es in sich; die Gruppen 3 bis 5 bleiben unten erreichbar.

### VoiceOver

Menü als Liste; Zeilen "Wocheneinkauf, 11 offen, Markt Lidl, geteilt mit Lena, ausgewählt"; "Grillabend, 7 offen, neue Änderungen, Tom kauft gerade ein". Nach der Wahl Ansage "Grillabend".

### Was sich gegenüber heute ändert

Heute gibt es keinen Umschalter: Man wechselt über den Listen-Index der Startseite und einen Push. Neue Liste per Eingabe-Alert, Beitreten nur per Langdruck auf "+ Neue Liste", Löschen per Langdruck ohne Vorschau. Neu: Menü am Titel, sichtbare Einträge für Anlegen und Beitreten, Löschen nur in Alle Listen und Listen-Info. Betroffen: `home_screen.dart` (Listen-Index und Dialoge entfallen), `lists_provider.dart` (Sortierung beim Öffnen fixieren), neu `list_switcher_menu.dart` (A).

### Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screenshot im hellen Modus derselben App: Aus dem großen Titel "Wocheneinkauf" oben links ist ein milchig-transparentes Liquid-Glass-Menü mit 20 pt Radius nach unten gewachsen, der Inhalt dahinter (weiße Sektionen auf #F2F2F7) ist leicht gedimmt. Im Menü vier Zeilen mit je einem farbigen runden Listen-Symbol mit weißem Piktogramm: ganz links ein grünes Häkchen #3F7A1F, dann blauer Kreis #007AFF mit Einkaufswagen, "Wocheneinkauf" mit kleinem Pin, Unterzeile grau "Lidl · mit Lena", rechts "11"; ein kleiner grüner Punkt links, oranger Kreis #FF9500 mit Flamme, "Grillabend", Unterzeile mit grünem Punkt "Tom kauft gerade ein", rechts "7"; lila Kreis #AF52DE mit Tropfen, "Drogerie", rechts "4"; rosa Kreis #FF2D55 mit Partytröte, "Party Samstag", rechts ein graues Kreis-Häkchen. Nach einem schmalen Band "Neue Liste" mit Plus und "Liste beitreten" mit Ketten-Symbol, nach einem weiteren Band "Alle Listen" mit Listen-Symbol und rechts "4". Text schwarz #000000, Nebentext #636366, Systemschrift, keine Großbuchstaben.

---

## 10.8 Toolbar der Wurzel

- **Hauptfrage:** Was kann ich mit dieser Liste als Ganzes tun?
- **Aufbau:** eine `GlassToolbar` oben rechts mit zwei Knöpfen (44 pt, Symbol 17 pt Medium): `person.crop.circle.badge.plus` "Liste teilen" → Sheet Liste teilen (Kapitel 11, 01 10.3); `ellipsis` "Mehr" → Listenmenü (Inhalt und Reihenfolge Kapitel 11, 01 5.3: Einkaufsmodus starten, Einkauf abschließen, Listen-Info, Reihenfolge im Markt, Beim Start zeigen, Angebote für diese Liste ausblenden (B, nur Modul an), Erledigte entfernen mit Rückgängig).
- **Zustände:** Keine Liste: Toolbar entfällt (nur Avatar). Offline: "Liste teilen" öffnet das Sheet mit "Braucht eine Verbindung" für Einladungen; das Menü bleibt bedienbar. Geteilt: Symbol bleibt gleich; Mitglieder sieht man in der Metazeile.
- **AX:** Large Content Viewer bei Langdruck ab AX1.
- **Was sich ändert:** Heute laden Zurück- und Teilen-Kreise (36 pt sichtbar) und ein Menü in der Material-AppBar; Teilen erzeugt vor dem Dialog per Netz einen neuen Code und macht alte Codes ungültig. Neu: eine Glasgruppe, Teilen öffnet sofort (Kapitel 11). Betroffen: `list_detail_parts.dart`, `list_detail_menu.dart`, `share_list_dialog.dart`.

---

## 10.9 Erste Liste (Tab Liste ohne Liste)

### Zweck und Einstieg

- **Hauptfrage:** Wie fange ich meine erste Liste an?
- **Wann:** Onboarding-Schritt "Erste Liste" übersprungen; letzte Liste gelöscht oder verlassen; angemeldetes Konto ohne Listen (z. B. neues Gerät, frisches Konto über "Ich habe schon ein Konto").

### Aufbau

1. Navigationsleiste: großer Titel "Erste Liste" mit `chevron.down` (Menü mit nur "Neue Liste" und "Liste beitreten"), Avatar rechts. Keine Toolbar.
2. 24 pt, Satz "Wie soll deine erste Liste heißen?" (`title3`, `label`).
3. `InsetSection` mit vier Zeilen (je 44 pt Mindesthöhe, führendes Symbol 17 pt frei in `labelSecondary`):
   - `cart` "Wocheneinkauf"
   - `basket` "Lidl", Unterzeile "Mit Markt Lidl, für Angebote und die Reihenfolge im Markt" (Modul Angebote aus: "Mit Markt Lidl, für die Reihenfolge im Markt")
   - `drop` "Drogerie"
   - `pencil` "Eigener Name" (wird beim Tippen zur Eingabezeile in derselben Sektion, Return legt an)
4. Sektionsfuß: "Name, Farbe und Markt kannst du später ändern."
5. `InsetSection` mit einer Zeile `link` "Liste beitreten", Unterzeile "Mit Code oder Link von jemand anderem" → Sheet Liste beitreten.
6. Bodenebene wie immer; das Accessory ist bedienbar, "Einkaufen" ausgeblendet.

Die vorgeschlagene Markt-Zeile nutzt, falls bekannt, den ersten Lieblingsmarkt aus dem Onboarding statt "Lidl".

### Verhalten

- Tippen auf einen Vorschlag legt die Liste sofort an (optimistisch; Farbe Blau, weil sie die erste ist, 00 4.3; bei "Lidl" Markt-Chip Lidl), der Titel überblendet auf den Namen, die Vorschläge klappen zusammen (`springStandard`), es folgt der Zustand 10.10, das Accessory bekommt den Fokus, in "Für heute" steht der Tipp "Schreib „2 Milch“ …".
- Tippt man zuerst in das Accessory, entsteht beim ersten Artikel automatisch die Liste "Einkaufsliste" mit Rückgängig-Hinweis "Liste „Einkaufsliste“ angelegt · Umbenennen" (E10-17).
- Keine Haptik; Erfolgsmoment erst beim ersten abgeschlossenen Einkauf, nicht hier.

### Zustände

Offline: Anlegen geht (ausstehend), "Liste beitreten" ist deaktiviert mit "Braucht eine Verbindung". Fehler beim Anlegen: Zeile bleibt, "Das hat nicht geklappt. Erneut versuchen" unter der Sektion. Module, Pro: ohne Wirkung. Kein Maskottchen (01 2.4).

### AX und 320 pt

Satz und Zeilen brechen um; ab AX1 randlose Zeilen. Auf dem SE mit AX3 sind Satz und die ersten zwei Vorschläge im ersten Bild sichtbar.

### Was sich ändert

Heute: 140-pt-Karte "Noch keine Listen" ohne Aktion; im Tutorial legt die App automatisch "Meine erste Liste" an, auch nach bewusstem Löschen. Neu: Wahl mit einem Tipp, Beitreten sichtbar, kein automatisches Anlegen ohne eigene Handlung. Betroffen: `home_screen.dart`, `DynamicTutorialService` (entfällt, K-21), `lists_provider.dart` (optimistisches Anlegen).

### Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screenshot im hellen Modus derselben App: Hintergrund #F2F2F7, oben links großer fetter Titel "Erste Liste" mit kleinem grauem Chevron, rechts ein runder Avatar mit Initiale "J" in Schwarz auf hellgrauem Kreis #E9E9EE, keine Glas-Knöpfe oben. Darunter halbfett "Wie soll deine erste Liste heißen?". Eine weiße Sektion mit 26 pt Radius und vier Zeilen mit grauen Liniensymbolen #636366: Einkaufswagen "Wocheneinkauf", Korb "Lidl" mit grauer Unterzeile "Mit Markt Lidl, für Angebote und die Reihenfolge im Markt", Tropfen "Drogerie", Stift "Eigener Name"; darunter klein grau "Name, Farbe und Markt kannst du später ändern." Eine zweite weiße Sektion mit Ketten-Symbol "Liste beitreten" und Unterzeile "Mit Code oder Link von jemand anderem". Unten die milchige Glas-Kapsel "Artikel hinzufügen" ohne Einkaufen-Knopf und die Glas-Tab-Bar "Liste", "Rezepte", "Plan" mit Avo-Kreis (braune Kugel #7A4A24, Ring #C9DE6E). Kein Maskottchen, keine Illustration.

---

## 10.10 Leere Liste

- **Hauptfrage:** Was schreibe ich als Erstes auf?
- **Wann:** Liste angelegt und noch nie gefüllt, oder alle Artikel gelöscht. (Nach einem abgeschlossenen Einkauf gilt 10.6 "Alles erledigt. Schön.")
- **Aufbau:** Navigationsleiste und Metazeile wie 10.1 (ohne Zahl). Hinweise wie immer. An Stelle der Gänge `EmptyState`: Symbol `checklist` 48 pt Light in `labelSecondary` (kein Maskottchen), Titel "Noch nichts auf der Liste." (`title3`), Satz "Schreib unten, was du brauchst, zum Beispiel „2 Milch“." (`body`, `label`), schlichte Aktion "Zettel importieren" (`text.viewfinder`, öffnet dasselbe Menü wie im Accessory). Darunter "Vielleicht auch" (falls Kandidaten). "Einkaufen" ausgeblendet.
- **Verhalten:** Der erste Artikel ersetzt den leeren Zustand: `EmptyState` blendet aus, der Gang wächst ein (`springStandard`).
- **Zustände:** offline gleich; Module ohne Wirkung außer Schildern in "Vielleicht auch".
- **AX:** Symbol wächst nicht über 48 pt; Text bricht um.
- **Was sich ändert:** Heute "Leere Liste. Füge Produkte hinzu, um mit dem Einkaufen zu beginnen" mit Button, der den Material-Dialog öffnet statt der Eingabe. Betroffen: `list_detail_screen.dart`, `empty_state.dart` (ersetzt durch 00 12.26).

### Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screenshot im hellen Modus derselben App: Hintergrund #F2F2F7, großer fetter Titel "Drogerie" mit grauem Chevron, Avatar rechts, darunter eine graue Kapsel #E9E9EE mit Laden-Symbol und "Markt wählen" in Grau #636366. In der oberen Bildhälfte mittig ein dünnes graues Checklisten-Symbol, darunter halbfett "Noch nichts auf der Liste." und in Schwarz "Schreib unten, was du brauchst, zum Beispiel „2 Milch“.", darunter ein grüner Textknopf #3F7A1F mit Scan-Symbol "Zettel importieren". Weiter unten die weiße Sektion "Vielleicht auch" mit gestrichelten Plus-Kreisen: "Zahnpasta" mit "kaufst du etwa alle 4 Wochen" und "Duschgel" mit "oft auf dieser Liste". Unten die Glas-Kapsel "Artikel hinzufügen" ohne Einkaufen-Knopf und die Glas-Tab-Bar mit Avo-Kreis.

---

## 10.11 Laden, Fehler, offline

| Zustand | Aufbau | Text | Aktion |
|---|---|---|---|
| **Lokaler Stand vorhanden** (Normalfall) | voller Screen ab dem ersten Frame | – | – |
| **Allererstes Laden ohne lokalen Stand** (neues Gerät, frische Anmeldung) | Titel als ruhige Tonfläche (`fill`, Höhe der Titelzeile, 50 % Breite), Metazeile als Kapsel-Tonfläche, eine Sektion mit 5 Zeilen (leere Kreise in `fill`, Balken 40 bis 70 % Breite); keine Hinweise, kein "Vielleicht auch"; Accessory sichtbar, aber deaktiviert (Platzhalter `labelTertiary`) | – | – |
| … nach 10 s ohne Antwort | Layout des leeren Zustands, Symbol `exclamationmark.circle` 48 pt Light | "Deine Listen konnten nicht geladen werden." | prominent "Erneut versuchen" |
| … und offline | Layout des leeren Zustands, Symbol `icloud.slash` | "Offline. Deine Listen erscheinen, sobald du wieder online bist." | – (lädt automatisch bei Verbindung) |
| **Offline mit lokalem Stand** | `StatusRow` unter der Metazeile; in der eingeklappten Leiste ein `icloud.slash` 13 pt hinter dem Inline-Titel (E10-03) | "Offline. Änderungen werden gespeichert, sobald du wieder online bist." | – |
| **Änderungen warten** (wieder online, Warteschlange läuft) | `StatusRow` mit `arrow.triangle.2.circlepath` | "3 Änderungen warten" | – (verschwindet von selbst) |
| **Sync-Fehler** | `StatusRow` mit `exclamationmark.circle` in `danger` | "Das hat nicht geklappt." | schlicht "Erneut versuchen" |
| **Einzelne Zeile nicht gespeichert** | Zeilenzustand Fehler (00 12.8), Fehler-Haptik | "Nicht gespeichert" | Tippen wiederholt |
| **Liste wurde von anderen gelöscht oder man wurde entfernt** | Liste von heute wechselt nach 01 2.2 Regel 1 (Überblendung) | Rückgängig-Hinweis ohne Aktion: "„Grillabend“ gibt es nicht mehr." | – |

Erscheinen und Verschwinden einer `StatusRow` mit `springStandard` und Scroll-Anker (E10-05); Reduce Motion: Überblendung. Kein Vollbild-Spinner, kein Schimmer, keine rohen Fehlertexte.

**Was sich ändert:** Heute lädt der Kaltstart die Listen zuerst aus dem Netz (Spinner in 140-pt-Box), Offline-Banner nur in der Shell, nie in der Liste; Abhaken ohne Netz springt still zurück; Fehler "Fehler beim Laden" ohne Aktion. Betroffen: `lists_provider.dart`, `items_provider.dart` (lokaler Stand vor `runApp`, Warteschlange), `offline_cache_service.dart`, `main_scaffold.dart` (`_OfflineBanner` entfällt), `connectivity_service.dart` (Teil B, Erreichbarkeit statt nur Netz).

### Bildbeschreibung für ChatGPT (offline)

iPhone-17-Pro-Screenshot im hellen Modus derselben App, Liste "Wocheneinkauf": Unter der Zeile "● Lidl" und "10 offen" steht eine schlichte Textzeile ohne Hintergrund mit grauem Wolken-durchgestrichen-Symbol #636366 und schwarzem Text "Offline. Änderungen werden gespeichert, sobald du wieder online bist." Darunter die Sektion "Obst & Gemüse": "Bananen" ist gerade abgehakt (gefüllter grüner Kreis #3F7A1F mit weißem Häkchen, Text grau durchgestrichen) und trägt unten rechts am Kreis ein winziges graues Kreispfeil-Symbol als Zeichen für "wartet auf Sync"; "Avocados", "Cherrytomaten" und "Gurke" haben leere graue Kreise. Unten schwebt kurz eine Glas-Kapsel "Bananen abgehakt · Widerrufen" mit grünem "Widerrufen" über der Kapsel "Artikel hinzufügen" und der Tab-Bar. Kein rotes Banner, keine Spinner.

---

## 10.12 Tägliche Nutzung

Die Startseite soll jeden Tag eine Frage beantworten, ohne Banner und ohne Mitteilungs-Spam (00 1.3). Sie tut das mit genau drei Mitteln: der Liste selbst, höchstens zwei Hinweisen und "Vielleicht auch".

| Anlass | Was Heute zeigt | Woher | Modul |
|---|---|---|---|
| Morgens, Kaffee | "Vielleicht auch" mit Nachkauf (Haferflocken, Toilettenpapier); "Heute im Plan: Ofengemüse mit Feta. Feta und Paprika fehlen noch." | Nachkauf-Rhythmus, Wochenplan | Kern, Wochenplan |
| Optional 9 Uhr | Nachkauf-Mitteilung (Kapitel 19) öffnet die Liste mit hervorgehobenem "Vielleicht auch" | Nachkauf | Kern, abschaltbar |
| Unterwegs | "Lena kauft gerade bei Lidl ein" in der Metazeile; schnell etwas ergänzen über Accessory, Widget oder Siri | Präsenz | Kern |
| Im Laden | "Einkaufen" unten rechts; beim nächsten Öffnen ggf. "Du bist bei Lidl." | Standort (erlaubt) | Kern |
| Nach dem Einkauf | "Einkauf von gestern mit Lena teilen?"; einmalig "14 Tage {pro} gratis testen" | Verlauf, Pro | Kosten teilen, Kern |
| Nachmittags 16 bis 21 Uhr | "Noch 640 kcal heute. Ideen fürs Abendessen" | Kalorien | Kalorien |
| Abends ab 20 Uhr | "Morgen im Plan: Linsencurry. 3 Zutaten fehlen noch." | Wochenplan | Wochenplan |
| Neue Prospektwoche | "5 Sachen, die du oft kaufst, sind diese Woche bei Lidl im Angebot, in deiner Region" | Angebote | Angebote |

Bewusst nicht: Tageszeit-Gruß, Serien und Abzeichen auf der Startseite, Zähler ohne Handlung, Avo-Werbung.

---

## 10.13 Abläufe

### A1 Morgens öffnen und Wochenplan-Zutaten ergänzen

1. App öffnen (Kaltstart). Erster Frame: Wocheneinkauf aus dem lokalen Stand, "11 offen", Hinweise aus dem Cache: Plan und Ersparnis.
2. Im Hintergrund gleicht die Liste ab; Lena hat nachts Gouda ergänzt: Zeile wächst in "Milchprodukte" ein, "11 offen" stand schon im Cache, nichts springt.
3. Tippen auf "Hinzufügen" in "Heute im Plan …": Feta (Milchprodukte) und Paprika (Obst & Gemüse) wachsen ein, "11 offen" rollt auf "13 offen", die Hinweis-Zeile klappt zusammen, Rückgängig-Hinweis "Feta und Paprika hinzugefügt · Widerrufen".
4. Die Ersparnis-Zeile zeigt jetzt "4 von 13 Artikeln …" (Ziffern rollen); kein neuer Hinweis rückt nach.

### A2 Liste wechseln

1. Titel "Wocheneinkauf" tippen; Menü wächst aus dem Titel.
2. "Grillabend" tippen; Menü schrumpft in den Titel, Inhalt überblendet, Titel "Grillabend", Metazeile "● REWE · 7 offen", Zeile 2 "Tom kauft gerade bei REWE ein".
3. Hinweise werden für Grillabend gewählt (z. B. Ersparnis bei REWE). "Grillabend" ist ab jetzt die zuletzt gewählte Liste; beim nächsten Kaltstart erscheint trotzdem Wocheneinkauf, weil sie angeheftet ist.

### A3 Nachkauf-Vorschlag übernehmen

1. Nach unten scrollen bis "Vielleicht auch".
2. "Haferflocken" tippen: Zeile klappt zusammen, "Haferflocken" wächst in "Trockenwaren" ein (liegt der Gang oberhalb, korrigiert der Scroll-Anker), "11 offen" rollt auf "12 offen", Rückgängig-Hinweis.
3. "Toilettenpapier" lange drücken > "Später erinnern": Zeile klappt zusammen; erscheint frühestens nach dem eigenen Rhythmus wieder.

### A4 Hinweis loswerden

1. Ersparnis-Zeile nach links wischen: "Ausblenden"; volles Wischen blendet für heute aus, "Hinweis ausgeblendet · Widerrufen".
2. Alternativ lange drücken > "Nicht mehr zeigen": Art dauerhaft aus; zurück über Einstellungen > Listen > "Hinweise für heute".
3. Alternativ lange drücken > "Angebote für diese Liste ausblenden": alle gelben Schilder dieser Liste verschwinden ohne Lücke (`springStandard`), Ersparnis-Zeile ebenfalls; Rückgängig-Hinweis.

### A5 Lena kauft ein, Jannis sieht es live

1. Lena startet bei Lidl den Einkaufsmodus von Wocheneinkauf.
2. Bei Jannis (Liste offen): Zeile 2 der Metazeile wechselt auf "Lena kauft gerade bei Lidl ein", der Punkt pulsiert einmal; VoiceOver "Lena kauft gerade ein". Keine Mitteilung, weil die Liste im Vordergrund ist.
3. Lena hakt Gouda ab: Kreis füllt sich, Lenas Avatar 2 s am Kreis, Zeile wandert nach "Erledigt (3)", "11 offen" rollt auf "10 offen". Keine Haptik bei Jannis.
4. Jannis fällt Kaffee ein, tippt unten "Kaffee"; bei Lena erscheint die Zeile im Einkaufsmodus im richtigen Gang (Kapitel 11).
5. Lena beendet den Einkauf: Zeile 2 wird wieder "Mit Lena"; Erledigtes verschwindet aus der Liste in den Verlauf; beim nächsten Öffnen kann "Einkauf von heute mit Lena teilen?" erscheinen (Modul Kosten teilen).

### A6 Erster Start bis zum ersten Artikel

1. Onboarding endet ohne Liste (Schritt übersprungen): Tab Liste zeigt "Erste Liste".
2. "Lidl" tippen: Liste "Lidl" entsteht mit Markt-Chip Lidl, Titel überblendet, leerer Zustand, Accessory fokussiert, Tipp-Zeile "Schreib „2 Milch“ …".
3. "2 Milch" + Return: "Milch", Menge 2, wächst in "Milchprodukte" ein; leerer Zustand blendet aus; VoiceOver "Milch hinzugefügt, Milchprodukte".

### A7 Offline abhaken

1. Im Funkloch die Liste öffnen: erster Frame aus dem lokalen Stand, `StatusRow` "Offline. …".
2. Bananen abhaken: Kreis füllt sich (leichter Impuls), Sync-Zeichen am Kreis, Rückgängig-Hinweis; die Zeile wandert nach "Erledigt".
3. Verbindung zurück: `StatusRow` "1 Änderung wartet", dann verschwindet sie; das Sync-Zeichen verschwindet; Lena sieht das Häkchen.

### A8 Offenen Betrag erledigen (Modul Kosten teilen)

1. Hinweis "Lena schuldet dir 4,20 € für Wocheneinkauf vom 3. Nov." > "Erledigt".
2. Optimistisch als bezahlt markiert, Zeile klappt zusammen, Rückgängig-Hinweis "Als bezahlt markiert · Widerrufen".
3. Fehler beim Speichern: Zeile kommt zurück, "Das hat nicht geklappt. Erneut versuchen", Fehler-Haptik.

### A9 Im Markt die passende Liste vorschlagen

1. Liste von heute ist "Drogerie"; Jannis betritt Lidl, öffnet die App (Rückkehr nach mehr als 60 s): Der Standort-Kandidat liegt aus dem Hintergrund-Abgleich im Cache.
2. Hinweis "Du bist bei Lidl. Wocheneinkauf ist deine Lidl-Liste." > "Öffnen": Liste wechselt mit Überblendung. Nie automatisch.
3. War der Kandidat beim Öffnen noch nicht im Cache, erscheint er nicht nachträglich; das Titelmenü zeigt aber sofort "In der Nähe" an der Lidl-Liste (E10-15).

---

## 10.14 Betroffene Dateien

| Datei | Besitz | Schicksal |
|---|---|---|
| `lib/presentation/screens/home/home_screen.dart` | A | neu als Wurzel "Liste von heute" (Slivers aus 10.1); Listen-Index, Angebote-Streifen, Verlaufszeile, Dialoge, Tutorial-Hook und Widget-Credentials-Sync raus (Letzteres zu Teil B in `main.dart`/Auth-Listener) |
| `lib/presentation/screens/home/widgets/greeting_header.dart` | A | entfällt |
| `lib/presentation/screens/home/widgets/nudge_card.dart` | A | entfällt (ersetzt durch `HintRow`, 00 12.12) |
| `lib/presentation/screens/home/home_nudge_card_order.dart`, `test/home_nudge_card_order_test.dart` | A | werden `today_hint_order.dart` mit Rang- und Familienregeln (10.3.4) und neuem Test |
| `lib/presentation/screens/lists/list_detail_screen.dart` | A | aufgelöst; Inhalt geht in die Wurzel, `/lists/:id` wählt nur die Liste |
| `lib/presentation/screens/lists/widgets/list_detail_parts.dart`, `list_detail_menu.dart` | A | Haarlinie, Abschluss-Pille, Zurück-Kreis entfallen; Menü wird `AppMenu` (Kapitel 11) |
| `lib/presentation/widgets/recommendations/ml_recommendations_section.dart`, `recommendation_card.dart` | A | entfallen; "Vielleicht auch" (10.5) |
| `lib/presentation/state/lists_provider.dart`, `items_provider.dart`, `last_list_provider.dart` | A | lokaler Stand vor `runApp`, Liste von heute nach 01 2.2, angeheftete Liste, `select` pro Artikel, Herkunft "von anderen", Warteschlange |
| neu `lib/presentation/state/list_presence_provider.dart`, `today_hints_provider.dart` | A | Präsenz (E10-10), Auswahl der Hinweise (E10-01) |
| neu `lib/presentation/screens/home/widgets/list_meta_line.dart`, `list_switcher_menu.dart`, `suggestions_section.dart`, `done_section.dart`, `first_list_state.dart` | A | Bausteine dieses Kapitels |
| `lib/presentation/screens/home/widgets/avo_nudge_card.dart` | B | entfällt als Karte; Nachkauf-Daten für "Vielleicht auch" (E10-09), Rhythmus-Angebote als Prospekt-Hinweis |
| `personal_flyer_card.dart`, `calorie_recipe_nudge_card.dart`, `pending_splits_banner.dart`, `split_trip_nudge_card.dart` | B | je eine Hinweis-Quelle nach E10-01; Texte nach 10.3.3; Uhrzeitfenster Kalorien; Fehlerbehandlung und Rückgängig bei Beträgen |
| `price_comparison_nudge_card.dart`, `home_price_comparison_cache_service.dart`, Startseiten-Pfad von `price_comparison_provider.dart` | B | entfallen |
| `avo_nudge_provider.dart`, `calorie_recipe_nudge_provider.dart`, `expense_split_provider.dart`, `avo_nudge_service.dart` | B | synchrone Cache-Kandidaten, kontobezogene Speicherung, Angebote nur Markt der Liste |
| `weekly_deals_screen.dart` | B | wird `/offers` (Kapitel 12), nicht mehr per `MaterialPageRoute` von der Startseite |
| `lib/presentation/screens/main_scaffold.dart` | A | Tab "Liste", `AppTabBar`, `_OfflineBanner` entfällt |
| `lib/core/localization/…` (Bereichsdateien) | A bzw. B | löschen: `greeting_*`, `avo_hint_home`, `show_label`, `your_lists`, `new_list_plus`, `no_lists_yet`, `deals_*` (Startseite), `last_shopped_prefix`, `home_price_highlight_*`, Karten-Kicker; neu: `list_today_*`, `list_hint_*` (A), `offer_hint_*`, `plan_hint_*`, `cal_hint_*`, `hist_hint_*` (B) |
| `lib/data/services/mascot_notification_service.dart` | B | Ziele nach 01 8.2; Texte ohne Emojis |

---

## 10.15 Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| F10-01 | Arbeitsteilung nennt für `ListOfferSummary` den Slot "Liste unten"; 00 12.12 und 01 5.3 machen daraus eine Hinweis-Zeile. Wo steht die Ersparnis? | Als Hinweis-Zeile in "Für heute" (Rang 5); der Slot "Liste unten" entfällt. Teil B baut dasselbe Widget, nur in der Form `HintRow`. |
| F10-02 | Kategorienamen: 00 und 01 schreiben in Beispielen "Milch & Käse", `categories.dart` sagt "Milchprodukte". Welche Namen gelten? | Die Namen aus `categories.dart`; Beispiele in 00 und 01 beim nächsten Durchgang angleichen. |
| F10-03 | Soll jedes Abhaken in der normalen Liste einen Rückgängig-Hinweis zeigen (00 10.3) oder nur im Einkaufsmodus? | Ja, aber ein neuer ersetzt den alten; bei schnellem Abhaken in Serie fasst er zusammen ("3 Artikel abgehakt · Widerrufen"). |
| F10-04 | Darf ein Standort-Hinweis, der erst nach dem ersten Frame feststeht, nachträglich erscheinen? | Nein (Regel gegen Layout-Sprünge); stattdessen sofort im Titelmenü markieren (E10-15) und beim nächsten Öffnen als Hinweis. |
| F10-05 | Zeitfenster Kalorien-Hinweis 16 bis 21 Uhr und Plan "morgen" ab 20 Uhr in Ordnung? | ja |
| F10-06 | Wird die angeheftete Liste ("Beim Start zeigen") pro Gerät oder im Konto gespeichert? | im Konto (gilt auf allen Geräten); "zuletzt gewählt" pro Gerät |
| F10-07 | Ist der Präsenz-Zeitraum (Ende nach 30 min ohne Abhaken) richtig? | ja; Owner prüft mit echtem Einkauf |
| F10-08 | Soll "Vielleicht auch" auch Wochenplan-Zutaten enthalten? | nein; dafür gibt es den Plan-Hinweis mit "Hinzufügen" |
| F10-09 | Sollen Tipps (K-21) auf der Startseite als Hinweis-Zeile erscheinen oder nur am Ort der Funktion? | als Hinweis-Zeile mit Rang 9, höchstens einer pro Tag, insgesamt höchstens 5 Tipps |
| F10-10 | Wird bei einer leeren Liste nach dem Abschluss "Alles erledigt. Schön." gezeigt, auch Tage später? | nur bis Mitternacht des Abschlusstags; danach "Noch nichts auf der Liste." |

---

## 10.16 Ergänzungen zum Fundament

Vorschläge für `00-grundlagen.md` bzw. `01-navigation-und-struktur.md`. Bis zur Übernahme gelten sie für dieses Kapitel.

| Nr. | Ergänzung | Grund |
|---|---|---|
| E10-01 | **Vertrag `TodayHintSource`** (A definiert in `lib/core/modules/` bzw. `lib/presentation/state/today_hints_provider.dart`, B implementiert je Quelle): `String id`, `HintFamily family` (Menschen, Ort, Plan, Tag, Angebote, Geld, Einmalig), `int rank`, `HintCandidate? cachedCandidate(String listId)` **synchron** aus einem kontobezogenen Cache, `Future<void> refresh(String listId)` im Hintergrund, `bool isStillValid(HintCandidate)`, `Widget build(BuildContext, HintCandidate)` (rendert eine `HintRow`). Ein Kandidat trägt `validUntil`, `shownDays`, `isProAction`. | Ohne synchrone Kandidaten kann Teil A beim ersten Frame nicht wissen, welche B-Widgets Inhalt haben; `SizedBox.shrink()` allein führt zu Layout-Sprüngen und bricht die Zwei-Hinweise-Regel. |
| E10-02 | **`ListMetaLine`** als Komponente: Zeile 1 `StoreChip`-Slot + `RollingNumber` mit Text; Zeile 2 `PresenceLine` nur bei geteilten Listen. `PresenceLine` bekommt den ruhigen Zustand "Mit Lena" (Avatar-Stapel + Text). | 00 12.29 kennt nur den aktiven Präsenz-Zustand; ohne ruhigen Zustand springt die Höhe, wenn jemand zu kaufen beginnt. |
| E10-03 | **Untertitel im eingeklappten Navigationstitel** (`LargeTitleNavBar`): `subheadline` `labelSecondary`, eine Zeile ("11 offen · Lidl"), wie der Navigations-Untertitel von iOS 26; dazu `icloud.slash` 13 pt hinter dem Inline-Titel, solange offline. | Nach dem Scrollen fehlt sonst die Antwort "wie viel ist offen" und der Offline-Hinweis. |
| E10-04 | **Höhenklasse** im `DesignScope`: niedrig unter 700 pt (iPhone SE 667, 13 Pro mit Anzeigezoom 693), normal ab 700 pt; dazu die Tabelle aus 10.1 als Regel "Hinweise weichen nach unten". | 00 6.3 kennt nur Breitenklassen; die SE-mit-AX3-Regel braucht die Höhe. |
| E10-05 | **Scroll-Anker** als Zustandsregel in 00 13: Ändert sich Inhalt oberhalb der Leseposition (Zeilen anderer, `StatusRow`, umbrechende Präsenz), wird der Scroll-Versatz im selben Frame korrigiert. | Live-Listen und Statuszeilen sonst mit sichtbaren Sprüngen. |
| E10-06 | **Symbole** in 00 9.2 aufnehmen: Tipp `lightbulb`; Ausblenden `eye.slash`; Nicht mehr zeigen `minus.circle`; Angebote ausblenden `tag.slash`; Später erinnern `moon.zzz`; Erledigt-Liste `checkmark.circle` (Anzahl 0 im Menü). | fehlen in der Symboltabelle |
| E10-07 | **Einmalige Hervorhebung** (`HighlightOnce`): Hinterlegung `fillPressed` für 1,5 s, Ausblenden mit `fadeReduced`; für Ziele aus Mitteilungen und Links ("Vielleicht auch", ein Artikel aus Siri). | 01 8.2 verlangt "hervorgehoben", 00 definiert es nicht. |
| E10-08 | **Ziele aus Hinweis-Zeilen** öffnen als Push im aktuellen Tab (wie `/author/:id`), auch wenn die Route zu einem Modul-Tab gehört (`/calories/ideas`, `/recipes/:id`); Zurück führt zur Liste. | 01 6 regelt nur Links und Mitteilungen; ein Tab-Wechsel aus einem Hinweis würde den Rückweg brechen. |
| E10-09 | **Datenvertrag Nachkauf** (B liefert, A rendert): `restockSuggestionsForListProvider(listId)` mit `RestockSuggestion { name, categoryId, reasonKey, reasonArgs, offer? }`, synchron aus dem Cache, Gründe als Übersetzungsschlüssel, Angebote nur vom Markt der Liste. | "Vielleicht auch" ist Kern (A), die Rhythmus-Logik gehört B; heute sind Gründe hart deutsch. |
| E10-10 | **Präsenz-Daten** (Teil A, Migration `…_a_list_presence.sql`): Tabelle `list_presence (list_id, user_id, store_chain, started_at, last_seen_at)` mit RLS für Mitglieder und Realtime; Ende nach den Regeln in 10.2; Provider `listPresenceProvider(listId)` und `presenceForAllListsProvider`. Teil B nutzt sie für die Mitteilung `shopping_started`. | Plan 4 "sehen, wer gerade einkauft"; das Titelmenü braucht Präsenz auch für nicht geöffnete Listen. |
| E10-11 | **`RollingNumber` mit Text** ("11 offen", "Erledigt (2)"): nur die Ziffern rollen, der Text steht; Plural über ICU ("1 offen" bleibt gleich, "1 Artikel"/"2 Artikel" wechselt ohne Rollen). | 00 12.15 beschreibt nur reine Zahlen. |
| E10-12 | **Magic Tap** auf der Wurzel des Tabs Liste fokussiert "Artikel hinzufügen"; im Einkaufsmodus beendet er nichts. | schneller Weg für VoiceOver-Nutzer zur wichtigsten Aktion |
| E10-13 | **Token `unread`** = `action`, als 8-pt-Punkt links vom Listen-Glyph in Titelmenü und Alle Listen; Abgrenzung zu `presence`: Präsenz sitzt immer am Avatar, Ungelesen nie. | 01 5.3 nennt den Ungelesen-Punkt, 00 hat keinen Token. |
| E10-14 | **Einstellungen > Listen > "Hinweise für heute"**: Schalter je Hinweis-Art (Präsenz, Markt am Standort, Wochenplan, Kalorien, Ersparnis, Beträge, Prospekt, Tipps); "Nicht mehr zeigen" setzt den Schalter, Kontextmenü-Hinweis nennt den Ort. Modul-Hinweise erscheinen dort nur, wenn das Modul an ist; Angebots-Schalter spiegeln 00 15.4. | "Nicht mehr zeigen" braucht einen Weg zurück (Agency). |
| E10-15 | **Markierung "In der Nähe"** in Titelmenü und Alle Listen (Unterzeile mit `location` 13 pt) für die Liste des Markts, in dem man gerade ist (nur mit Erlaubnis und Markt-Erkennung an). | Ersatz für nachträglich erscheinende Standort-Hinweise (F10-04). |
| E10-16 | **Kontobezogener lokaler Speicher** als Regel in 00 13: Ausblenden, Schlummern, Hinweis-Cache, Einklapp-Zustände werden mit der Nutzer-ID im Schlüssel gespeichert und beim Kontowechsel nicht übernommen. | heute gerätweit (Inventar home, Bug 20) |
| E10-17 | **Automatisch angelegte Liste:** Wer ohne Liste einen Artikel eingibt, bekommt die Liste "Einkaufsliste" (lokalisiert) mit Rückgängig-Hinweis "Liste „Einkaufsliste“ angelegt · Umbenennen". | Ziel "unter 60 s bis zur eigenen Liste"; kein Fehler, wenn man direkt lostippt. |
| E10-18 | **`HintRow` bei Platzmangel:** Ist die Textspalte schmaler als 160 pt, steht die schlichte Aktion unter dem Text an der Textkante; Trefferfläche bleibt 44 pt. | 00 12.12 beschreibt die Aktion nur rechts. |
