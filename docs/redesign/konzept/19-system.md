# 19 Widgets, Siri, Mitteilungen und App-Icon

Stand: 07.11.2026. Besitz: **Teil B** (Jannis, Mac 2) für Widgets, Steuerelemente, Siri/App Intents, Mitteilungen (Dienste, Texte, Server), Berechtigungstexte und Startbildschirm; **Teil A** (Owner, Mac 1) für das App-Icon (`AppIcon.appiconset`, Icon-Composer-Datei) und die Oberfläche der Seite Einstellungen > Mitteilungen (Inhalt und Dienste von B). Grundlage laut `arbeitsteilung.md` Zeilen 38, 53 und 81.

Baut auf `00-grundlagen.md` (Verweise "00 x.y") und `01-navigation-und-struktur.md` (Verweise "01 x.y") auf. Ist-Zustand: `inventar/native.md` ("Inv-N x.y") und `inventar/brand.md` ("Inv-M x.y"). Plan-Grundlage: Plan 10 ("Füg Milch zu Shoply hinzu", "Was steht auf meiner Liste?") und Plan 11 ("schnell und schön, abhaken direkt im Widget"), Verbesserungsliste 12 und 13.

Markierungen: **S-xx** = Entscheidung dieses Kapitels (Kap. 20). **FS-xx** = offene Frage an den Owner (Kap. 21). **E-xx** = Ergänzung zum Fundament, die Teil A bestätigen bzw. umsetzen muss (Kap. 22).

**Owner-Regel "keine Slider" (CLAUDE.md, 07.11.2026):** keine Bottom-Sheets, keine halbhohen Modals, keine Drawer, keine Schieberegler; Bearbeiten als Vollbild-Push oder am Ort; erlaubt bleiben zentrierte Alerts und Kontext-/Pull-down-Menüs. Dieses Kapitel folgt der Regel für alle Flächen, die die App selbst zeichnet: das "Modul ist aus" aus Widget, Siri oder Mitteilung ist ein zentrierter Alert (statt des Sheets aus 00 Kap. 13), Vorab-Erklärungen für Berechtigungen stehen am Ort, die Einstellungsseiten sind Pushes. Systemoberflächen (Siri-Snippet, "Widget bearbeiten", Mitteilungen, Kontrollzentrum) zeichnet iOS; sie fallen nicht unter die Regel. Die Abweichungen vom Fundament stehen in E-05.

Inhalt: 1 Überblick · 2 Beispieldaten · 3 Gemeinsame Widget-Gestaltung · 4 Widget "Liste" · 5 Widget "Schnell hinzufügen" · 6 Widget "Rezept" · 7 Widget "Wochenplan" · 8 Widget "Kalorien und Wasser" · 9 Widget "Avo fragen" · 10 Sperrbildschirm · 11 StandBy · 12 Steuerelemente und Action Button · 13 Siri und Kurzbefehle · 14 Mitteilungen · 15 Einstellungsseiten und Modul-Alert · 16 Berechtigungen · 17 App-Icon · 18 Startbildschirm · 19 Abläufe · 20 Entscheidungen · 21 Offene Fragen · 22 Ergänzungen zum Fundament · 23 Betroffene Dateien

---

## 1. Überblick

### 1.1 Hauptfrage und Platz

- **Hauptfrage des Bereichs:** Was kann ich erledigen, ohne die App zu öffnen? Abhaken im Widget, "Füg Milch hinzu" zu Siri, "Fehlt noch etwas?" direkt aus der Mitteilung beantworten, ein Glas Wasser eintragen.
- **Warum das zählt:** Diese Flächen sind der stärkste Hebel für tägliche Nutzung (Verbesserungsliste 16). Wer die Liste auf dem Home-Bildschirm sieht und dort abhakt, öffnet die App öfter von selbst, weil sie verlässlich ist. Ein Widget, das einmal falsche Daten zeigt oder ein Häkchen verliert, wird entfernt und kommt nicht wieder. Deshalb steht Zuverlässigkeit (3.8) vor allem anderen.
- **Gestaltung:** exakt der App-Stil aus 00 ("Vorinstalliert"): Fläche `surface`, eine Akzentfarbe `action`, Listenfarbe nur im Titel, Systemschrift mit Dynamic-Type-Stilen, SF Symbols und Avo Symbols als Vorlagen, keine Emojis, kein Maskottchen (00 3.3: nie in Widgets und Mitteilungs-Bildern).
- **Was es nicht gibt:** keine Live Activity, keine Dynamic Island (Plan 5, verworfen). Kein Angebots-Widget, solange keine Lizenz besteht (K-27). Keine Mitteilungen, die Angebote bewerben (S-14). Kein Marktvergleich in irgendeiner Form (Plan 8).

### 1.2 Bestandteile

| Teil | Art | Größen bzw. Form | Modul | Kap. |
|---|---|---|---|---|
| Liste | Widget, interaktiv (Abhaken) | klein, mittel, groß; Sperrbildschirm rund, rechteckig, inline; StandBy | Kern | 4, 10, 11 |
| Schnell hinzufügen | Widget, interaktiv (Hinzufügen) | klein, mittel | Kern | 5 |
| Rezept | Widget mit Foto | klein, mittel, groß; StandBy | Kern | 6, 11 |
| Wochenplan | Widget | klein, mittel, groß; Sperrbildschirm rechteckig, inline | Wochenplan | 7, 10 |
| Kalorien und Wasser | Widget, interaktiv (+250 ml) | klein, mittel; Sperrbildschirm rund, rechteckig, inline; StandBy | Kalorien | 8, 10, 11 |
| Avo fragen | Widget | klein, mittel; Sperrbildschirm rund | Avo | 9, 10 |
| Steuerelemente | Kontrollzentrum, Sperrbildschirm unten, Action Button | Knopf | Kern bzw. Modul | 12 |
| Siri und Kurzbefehle | App Intents, App Shortcuts, Snippets | Sprache, Snippet | Kern bzw. Modul | 13 |
| Mitteilungen | lokal und Push | Banner, Sperrbildschirm, Mitteilungszentrale | Kern bzw. Modul | 14 |
| Einstellungen Mitteilungen, Siri & Kurzbefehle, Widgets | Push im Profil | Seite | Kern | 15 |
| Modul ist aus (Einstieg von außen) | zentrierter Alert | – | alle Module | 15.4 |
| Berechtigungstexte | `InfoPlist.xcstrings` DE/EN | Systemdialog | – | 16 |
| App-Icon "Die Hälfte" | Icon-Composer-Datei plus Asset-Varianten | hell, dunkel, klar, getönt | – | 17 |
| Startbildschirm | `LaunchScreen.storyboard` | eine Fläche | – | 18 |

### 1.3 Grundregeln des Bereichs

1. **Ohne App erledigen, was ohne App geht.** Abhaken, Hinzufügen, Vorlesen, Wasser eintragen und "Fehlt noch etwas?" laufen im Hintergrund, ohne dass die App sich öffnet. Was einen Bildschirm braucht (Einkaufsmodus, Essen per Foto, Avo-Sprachmodus), öffnet die App direkt an der richtigen Stelle.
2. **Ein Tipp, eine sichtbare Folge.** Jede Aktion im Widget zeigt ihr Ergebnis im selben Widget sofort (Kreis gefüllt, Zahl gesunken, Zeile "Auf der Liste"). Siri sagt, was passiert ist, nicht was passieren wird (heute bestätigt Siri vor dem Hinzufügen, Inv-N 4.2 Punkt 12).
3. **Nichts geht verloren.** Jede Aktion aus Widget, Siri, Steuerelement oder Mitteilung landet zuerst in einer dauerhaften Warteschlange der App Group und wird dann gesendet. Abgelaufene Anmeldung, kein Netz oder ein beendeter Prozess verlieren nichts (3.8).
4. **Dieselben Regeln wie in der App.** "2 Milch" wird Menge 2 plus Artikel; ein schon offener Artikel gleicher Einheit erhöht die Menge (01 10.1 Schritt 5); abgehakt wird mit `checked_by`; Mitglieder sehen es live; Mitteilungen gebündelt (K-39).
5. **Liste von heute als Standard.** Wo kein Ziel genannt ist (Siri ohne Liste, neues Widget, Steuerelement), gilt die Liste von heute nach 01 2.2. Siri fragt nur nach, wenn es noch keine Liste gibt.
6. **Module und Kill-Switch gelten auch außen.** Widget-Arten sind fest registriert und verschwinden nicht; ein Widget eines ausgeschalteten Moduls zeigt einen ruhigen Satz (00 15.2). Siri-Sätze eines ausgeschalteten Moduls antworten sachlich. Bei Kill-Switch verschwinden die Ersparnis-Zeile im großen Listen-Widget und jeder Angebotstext in Mitteilungen ohne Hinweis.
7. **Ruhig statt laut.** Keine Emojis, keine Ausrufezeichen, keine Werbesprache, kein Maskottchen. Eine Mitteilung pro Anlass, nicht pro Häkchen. Zeitkritisch ist nur der Kochtimer.
8. **Ein Name, eine Quelle.** Sichtbare Namen kommen aus `AppBrand` (00 3.1); Siri-Sätze nutzen `.applicationName`; Swift-Code liest den Anzeigenamen aus der `Info.plist` statt "Shoply" fest einzutragen (heute Fallback "Shoply" im Widget, Inv-N 3.1 Punkt 12).

### 1.4 Systemvoraussetzungen

Die App läuft heute ab iOS 15.6, die Widget-Erweiterung ab iOS 17.0 (Inv-N 1). Owner-Frage F-12 schlägt iOS 17 als Mindestversion vor. Funktionen nach Systemversion:

| Funktion | ab iOS | Rückfall darunter |
|---|---|---|
| Interaktive Widgets (Abhaken, Hinzufügen, +250 ml) | 17 | Widget ohne Knöpfe, Tippen öffnet die Liste (betrifft nur App-Versionen unter 17, Widget-Erweiterung setzt 17 ohnehin voraus) |
| Sperrbildschirm-Widgets, StandBy | 16 bzw. 17 | – |
| Steuerelemente (Kontrollzentrum, Sperrbildschirm, Action Button) | 18 | Kurzbefehl in der Kurzbefehle-App; Action Button über "Kurzbefehl" |
| Getöntes App-Icon und getönte Widgets | 18 | Standard-Icon |
| Klares Icon, Liquid-Glass-Widgets, Icon Composer | 26 | getönt bzw. Standard |
| Interaktive Siri-Snippets ("Widerrufen" im Snippet) | 26 | Snippet ohne Knopf; Rückgängig in der App |
| Widget-Aktualisierung per Push (APNs-Typ für Widgets) | 26 (vor dem Bau prüfen) | Hintergrund-Push mit Systembudget, Zeitleiste alle 15 Minuten |
| App Intents ohne App-Öffnen | 16 | – |

Alle Werte vor dem Bau mit der aktuellen Apple-Dokumentation abgleichen (iOS 27 kann Details ändern).

---

## 2. Beispieldaten (gelten für alle Beispiele dieses Kapitels)

Heute ist **Mittwoch, 11. Nov. 2026, 17:40 Uhr** (wie in Kapitel 14). Die Person am iPhone ist **Jannis**. Die Liste von heute ist **Wocheneinkauf** (Listenfarbe Blau #007AFF / #0A84FF, Symbol `cart`, Markt-Chip Lidl #0050AA, geteilt mit **Lena**).

**Wocheneinkauf**, 11 Artikel, 9 offen, 2 erledigt, Reihenfolge im Markt Lidl:

| Gang (Kategorie) | Artikel | Menge | Bemerkung |
|---|---|---|---|
| Obst & Gemüse | Bananen | – | |
| | Gurken | 2 | |
| | Paprika rot | – | von Lena |
| Backwaren | Vollkornbrot | – | |
| Milch & Käse | Milch | 2 | Angebot 0,99 € laut Händler (Modul Angebote) |
| | Eier | 10 Stück | |
| | Joghurt | 500 g | |
| Vorrat | Reis | 1 kg | |
| | Haferflocken | – | von Lena |
| erledigt | Butter, Kaffee | | |

Mit Modul Angebote: "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" (Wortlaut aus 00 3.2).

**Weitere Listen:** Drogerie (Lila #AF52DE, `bag`, ohne Markt, 4 offen), Party (Orange #FF9500, `party.popper`, REWE #CC071E, 14 offen).

**Häufig gekauft, gerade nicht offen** (für Schnell hinzufügen): Tomaten, Gouda, Äpfel, Mineralwasser, Toastbrot, Spülmittel. Nachkauf fällig: Milch ("kaufst du etwa alle 6 Tage, zuletzt am Do., 5. Nov.").

**Rezepte:** gemerkt Ofengemüse mit Feta (35 Min, 2 Portionen, 540 kcal), Shakshuka (25 Min, 2 Portionen, 430 kcal), Linsen-Dal (30 Min, 4 Portionen, 470 kcal). Rezept der Woche: Ofengemüse mit Feta.

**Wochenplan** (Woche 9.–15. Nov., wie Kapitel 14): Mi (heute) Chili sin Carne, 4 Portionen, 40 Min; Do nichts; Fr Lachs mit Ofenkartoffeln; Sa Gemüse-Curry mit Reis und Apfel-Crumble; So nichts. 17 Zutaten fehlen noch auf Wocheneinkauf.

**Kalorien:** Ziel 2.000 kcal, gegessen 1.360 kcal, also **640 kcal übrig**. Protein 62 von 110 g, Kohlenhydrate 158 von 230 g, Fett 53 von 70 g. Wasser 1,25 von 2 l (5 × 250 ml).

**Geteilt:** Lena startet um 17:42 den Einkaufsmodus bei Lidl.

---

## 3. Gemeinsame Widget-Gestaltung

Gilt für alle Widgets in Kapitel 4 bis 11. Widgets werden nativ in SwiftUI gebaut (Teil B, `ios/ShoppingListWidget/`); sie übernehmen die Tokens aus 00 Kap. 4 bis 9 über Asset-Katalog-Farben (E-01).

### 3.1 Fläche, Ränder, Ecken

- **Hintergrund:** `.containerBackground(for: .widget) { Color("Surface") }` mit `surface` (#FFFFFF hell, #1C1C1E dunkel). Keine eigene Fläche im Inhalt (heute doppelt: `.containerBackground(.clear)` plus `.background(bg)`, Inv-N 3.1 Punkt 2). Nur so kann iOS den Hintergrund in getönter, klarer und StandBy-Darstellung entfernen.
- **Ränder:** die System-Inhaltsränder (`widgetContentMargins`, iOS 17+), kein zusätzliches `padding(12/14/16)`. Innen gilt die Abstands-Skala aus 00 6.1 (`space4` bis `space16`).
- **Ecken:** Den äußeren Radius setzt iOS. Innere Formen sind konzentrisch über `ContainerRelativeShape` (Rezeptfoto im mittleren Widget, Fortschrittsfläche), nie mit festen Radien. Kapseln (Markt-Chip, "+250 ml") bleiben Kapseln (00 7.1).
- **Kein Glas im Widget.** Liquid Glass bringt iOS 26 selbst über die klare Darstellung; der Inhalt bleibt Fläche (00 8.1 "Nie Glas: Widget-Inhalte").
- **Keine Schatten, keine Rahmen, keine Verläufe**, außer dem Lesbarkeits-Verlauf auf Fotos (00 9.6: #000000 von 0 auf 55 % über das untere Drittel).

### 3.2 Farbe in den drei Darstellungsarten

iOS zeichnet Widgets in drei Arten (`@Environment(\.widgetRenderingMode)`). Jede ist geprüft:

| Darstellung | Wo | Hintergrund | Text | Akzent (Häkchen, Knöpfe, "+") | Listenfarbe | Fotos |
|---|---|---|---|---|---|---|
| **Vollfarbe** (`fullColor`) | Home-Bildschirm Standard, StandBy tagsüber | `surface` | `label`; Metadaten in Asset-Farbe `LabelSecondary` (#636366 / #98989F, 5,99:1 bzw. 5,94:1 auf `surface`) | `action` (#3F7A1F / #A6D45F); gefüllter Kreis mit Häkchen in `onAction` | nur der Listentitel (Blau #007AFF / #0A84FF) | farbig |
| **Getönt bzw. klar** (`accented`) | Home-Bildschirm "Getönt" (iOS 18) und "Klar" (iOS 26) | vom System entfernt | `.primary`, Metadaten `.secondary` (Systemstile, damit iOS sie lesbar tönt) | Gruppe `.widgetAccentable()`: Listentitel, gefüllte Kreise, "+", "+250 ml", Ring | geht in der Akzent-Gruppe auf | `.widgetAccentedRenderingMode(.accentedDesaturated)`, Rezeptfotos bleiben als Helligkeitsbild erkennbar |
| **Vibrant** (`vibrant`) | Sperrbildschirm, StandBy nachts (rot) | vom System entfernt | `.primary`/`.secondary`, das System bestimmt die Farbe | über Gewicht und Füllung, nie über Farbe | entfällt | nur in StandBy, entsättigt |

Regeln:
- **Farbe nie allein** (00 4.2): Erledigt = gefüllter Kreis plus Häkchen plus durchgestrichener Text in jeder Darstellung. Über Kalorienziel = Symbol `exclamationmark.triangle.fill` plus Text "120 kcal drüber".
- **Höchstens drei Farbtöne** außer Graustufen (00 4.2): Akzent, Listenfarbe, in Kalorien kein weiterer. Gelb (`dealTag`) kommt in Widgets nicht vor (S-05).
- **Erhöhter Kontrast** (`colorSchemeContrast == .increased`): Asset-Farben haben eigene Varianten aus 00 4.5 (`action` #2E5C14 / #C4E88A, `LabelSecondary` #3C3C43 / #C7C7CC, Listenfarben dunklere Varianten aus 00 4.3).
- Der leere Abhak-Kreis ist `controlOutline` (#8A8A8E / #7C7C80) in Vollfarbe und `.secondary` in den anderen Darstellungen.

### 3.3 Schrift und Dynamic Type

Widgets nutzen SwiftUI-Textstile, die mit der Textgröße des Systems wachsen (00 5.3 "Widgets skalieren nach den Regeln des Systems"). Keine `.font(.system(size:))` (heute 9 bis 17 pt fest, Inv-N 3.1 Punkt 1).

| Rolle | SwiftUI-Stil | Entspricht in 00 5.2 |
|---|---|---|
| Listentitel, Rezepttitel | `.headline` | `headline` |
| Artikelzeile (klein, mittel) | `.subheadline` | `subheadline` |
| Artikelzeile (groß), Rezepttitel groß | `.body` | `body` |
| Metazeile ("9 offen · Lidl", "35 Min") | `.footnote` | `footnote` |
| Große Zahl ("9", "640") | `.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()` | `numberXL` |
| Menge in der Zeile ("2", "500 g") | `.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit()` | `number` |

- SF Pro Rounded ist in SwiftUI direkt verfügbar (`design: .rounded`), anders als in Flutter (K-18). Damit sehen Zahlen in Widgets genau so aus, wie 00 es für die App vorsieht.
- **Zeilenanzahl aus Höhe und Textgröße**, nie abgeschnitten: Jedes Widget berechnet, wie viele Zeilen in die verfügbare Höhe passen (`GeometryReader`, Zeilenhöhe nach `dynamicTypeSize`), und zeigt den Rest als "+3 weitere". Richtwerte für das Listen-Widget:

| Textgröße | klein | mittel (rechte Spalte) | groß |
|---|---|---|---|
| xS bis L | 3 | 4 | 8 |
| xL bis xxxL | 3 | 3 | 6 |
| AX1 bis AX2 | 2 | 2 | 4 |
| AX3 bis AX5 | 1 und Zahl | 1 | 3 |

- **Ab AX1 steht die Menge vor dem Namen** in derselben Zeile ("2 Milch", wie man es eintippt), statt rechtsbündig; so bleibt die volle Breite für den Namen. Namen kürzen mit Ellipse am Ende (Widgets sind eine der drei erlaubten Stellen für Ellipsen, 00 5.3).
- **Fetter Text** (`legibilityWeight == .bold`) macht SwiftUI selbst; keine eigenen Gewichte.

### 3.4 Symbole

- SF Symbols direkt aus dem System (im Widget nativ, kein Kanal nötig). Gewicht folgt dem Text daneben (00 9.1).
- Abhak-Kreis: `circle` (leer) und `checkmark.circle.fill` (erledigt) in `.title3`-Größe des Stils der Zeile, Trefferfläche siehe 3.7.
- Artikelbilder: Avo Symbols als Symbol-Assets in der Widget-Erweiterung (00 9.4, K-17); bis sie fertig sind, die Kategorie-Symbole aus 00 9.4 (`carrot`, `birthday.cake`, `drop` …). In Widgets nur im großen Listen-Widget bei Textgröße bis xxxL; sonst entfallen sie (Platz).
- Avo-Kern: Vorlage-Symbol `avo.core` (00 3.4) als Symbol-Asset; in Vollfarbe mehrfarbig (Kern `avoKern`, Ring `avoRing`), sonst einfarbig.
- Mehrfarbig nur `drop.fill` (Wasser) und `flame.fill` (Kalorien), wie 00 9.1 erlaubt.
- Keine Symbole in getönten Quadraten oder Kreisen; einzige Ausnahme bleibt der Listen-Glyph (in Widgets nicht verwendet, der Titel trägt die Listenfarbe).

### 3.5 Bewegung im Widget

- Widgets animieren zwischen zwei Zeitleisten-Einträgen mit Systemfedern. Erlaubt und genutzt:
  - Zahlen: `.contentTransition(.numericText(value:))` für "9 offen", "640 kcal", "1,25 l"; das ist die Widget-Fassung der rollenden Ziffern (00 12.15, K-34).
  - Abhak-Kreis: `.contentTransition(.symbolEffect(.replace))` von `circle` zu `checkmark.circle.fill`.
  - Nachrückende Zeilen: `.transition(.push(from: .bottom))`, nur wenn eine erledigte Zeile das Widget verlässt (siehe 4.5).
  - Ausstehende Aktion: `.invalidatableContent()` am betroffenen Wert; iOS blendet ihn kurz ab, bis die Aktion bestätigt ist.
- Reduce Motion behandelt iOS selbst (Überblenden statt Schieben).
- **Keine Haptik:** Widgets können keine auslösen, iOS gibt beim Tippen keine. Rückmeldung ist rein sichtbar (00 Kap. 11 bleibt unberührt, E-08).

### 3.6 Zustände für alle Widgets

| Zustand | Verhalten |
|---|---|
| **Galerie-Vorschau** | Beispieldaten aus Kapitel 2 in der Sprache des Systems (Wocheneinkauf, Milch, Eier …), nie leere Rahmen. |
| **Platzhalter** (iOS lädt noch) | `.redacted(reason: .placeholder)` in der echten Form: graue Kapseln in `fill` statt Text, kein Spinner, kein Schimmer (00 13). |
| **Abgemeldet bzw. erster Start ohne Konto** | ruhiger Satz in `.subheadline`: "Melde dich in {app} an, um deine Liste hier zu sehen." Tippen öffnet die App (Anmelden bzw. Onboarding). Kein Firmenname "Shoply" (heute Inv-N 2.1). |
| **Lädt** | immer zuerst der zuletzt gespeicherte Stand aus der App Group; frische Daten ersetzen ihn beim nächsten Eintrag ohne Sprung (3.8). |
| **Fehler beim Abgleich** | Inhalt bleibt sichtbar (fail-open, Inv-N 6); ausstehende Zeilen tragen `arrow.triangle.2.circlepath` (10 pt, `.secondary`) am Kreis. Kein roter Fehlertext im Widget. Nach 24 h ohne erfolgreichen Abgleich steht unter dem Titel in `.footnote`: "Stand: gestern, 18:10". |
| **Offline** | wie Fehler: Aktionen wirken sofort im Widget, gehen in die Warteschlange und werden gesendet, sobald Netz da ist. |
| **Konfigurierte Liste gelöscht oder verlassen** | Satz "Diese Liste gibt es nicht mehr. Halte das Widget gedrückt, um eine andere zu wählen." Kein stilles Umschalten auf eine andere Liste (heute Inv-N 4.1 Punkt 4). |
| **Modul aus** | ruhiger Satz mit Modulsymbol (48 pt Light ist zu groß; hier `.title2` Light, `.secondary`): "Wochenplan ist ausgeschaltet." Tippen öffnet die App mit dem Modul-Alert (15.4). |
| **Kill-Switch Angebote** | betrifft nur die Ersparnis-Zeile im großen Listen-Widget: entfällt ohne Lücke, ohne Hinweis. |
| **Pro gesperrt** (falls der Owner ein Modul zu Pro macht, F-05) | echte Vorschau mit eigenen Daten (00 16.2); wo eine Aktion Pro bräuchte (z. B. "+250 ml", falls Kalorien Pro wird), steht statt des Knopfs die Kapsel "Pro" (`ProBadge`-Optik: `action` auf `actionFill`); Tippen öffnet `/pro?feature=<id>`. Unbekannter Pro-Status gilt als zuletzt bekannter (00 13). Vorschlag des Konzepts: kein Widget wird Pro (FS-03). |

### 3.7 Trefferflächen und Barrierefreiheit

- **Trefferflächen:** Jede abhakbare Zeile ist über die volle Breite ein Knopf (`Button(intent:)` um die ganze Zeile), mindestens 32 pt hoch im kleinen und mittleren Widget und 36 pt im großen; zwischen zwei Zeilen mindestens 4 pt Abstand, damit kein Tipp die Nachbarzeile trifft. Die 44 pt aus 00 6.2 passen in Widgets nicht; Apple erlaubt dort kleinere, klar getrennte Ziele. Im kleinen Widget höchstens 3 Ziele, im mittleren höchstens 5 (heute 8 in zwei Spalten, Inv-N 3.1 Punkt 5).
- **VoiceOver:** jede Zeile ein Element mit vollem Satz ("Milch, Menge 2, nicht erledigt"; Aktion "Doppeltippen zum Abhaken"); Titel "Wocheneinkauf, 9 offen, Markt Lidl"; Zahlen ausgeschrieben ("640 Kilokalorien übrig"). Heute gibt es keine Labels (Inv-N 3.1 Punkt 8).
- **Fetter Text, erhöhter Kontrast, Reduce Motion, Intelligente Umkehrung:** über Systemstile und Asset-Varianten (3.2, 3.3); Rezeptfotos bekommen `.accessibilityIgnoresInvertColors()`.
- **Sprache:** alle Texte aus einem String-Katalog (`Localizable.xcstrings`, DE/EN) der Erweiterung; Einzahl/Mehrzahl über die Plural-Regeln des Katalogs ("1 Artikel", "9 Artikel"). Heute alles deutsch fest im Code, Intent-Titel englisch (Inv-N 3.1 Punkt 12).

### 3.8 Daten und Zuverlässigkeit (Grundlage für alle Systemflächen)

Heute verlieren Widgets Häkchen, wenn das Token abgelaufen ist, warten den Netzaufruf nicht ab, zeigen nur Listen, die auf diesem Gerät geöffnet wurden, und laden nie aus dem Netz (Inv-N 4.1). Neu, gebaut von Teil B:

1. **Gemeinsamer Swift-Kern** `ios/Shared/` (eigenes Framework bzw. Dateien in beiden Targets): App-Group-Schlüssel, Modelle, kleiner Supabase-REST-Client, Anmeldung, Warteschlange, Eingabe-Parser. Heute kennen zwei Targets dieselben Schlüssel doppelt (Inv-N 5).
2. **Anmeldung über einen gemeinsamen Schlüsselbund** (Keychain-Zugriffsgruppe für App und Erweiterung) mit Refresh-Token, damit Widget und Siri eine abgelaufene Sitzung selbst erneuern. Kein Zugangs-Token mehr im Klartext in den App-Group-Einstellungen (heute Inv-N 4.1 Punkt 10).
3. **Schnappschuss v2:** Die App schreibt `widget_snapshot_v2.json` in die App Group: alle Listen der Person (nicht nur die geöffneten) mit den ersten 30 offenen Artikeln in Markt-Reihenfolge, Zählern, Farbe, Symbol, Markt; Wochenplan der laufenden und nächsten Woche; Kalorien und Wasser von heute; drei Rezepte mit Foto. Rezeptfotos legt die App verkleinert (Anzeigegröße × 3, JPEG) unter `widget_images/` ab, weil Widgets keine Bilder aus dem Netz laden können. Geschrieben wird entprellt 1 s nach jeder Änderung, beim Wechsel in den Hintergrund und nach einem Hintergrund-Push.
4. **Widgets laden selbst nach:** Der Zeitleisten-Anbieter liest zuerst den Schnappschuss und holt danach frische Daten aus Supabase (mit erneuerter Sitzung). Zeitleiste: neuer Eintrag spätestens alle 15 Minuten, sonst bei Ereignissen.
5. **Änderungen anderer erreichen das Widget:** Ändert sich eine geteilte Liste, sendet der Server einen Widget-Push (ab iOS 26, E-15) bzw. einen stillen Hintergrund-Push; die Erweiterung holt die Liste neu und lädt die Widgets. Gleiches gilt für den zweiten iPhone desselben Kontos (die beiden Macs des Owners und Jannis' Testgeräte).
6. **Aktionen sind eine Warteschlange:** Abhaken, Hinzufügen, Wasser schreiben zuerst einen Eintrag in `pending_actions.json` (App Group, mit Dateikoordination), ändern sofort den Schnappschuss (Widget zeigt das Ergebnis) und rufen dann **abgewartet** (`await` innerhalb von `perform()`) eine Server-Funktion auf. Gelingt sie, wird der Eintrag entfernt. Gelingt sie nicht, bleibt er; die App sendet ihn beim nächsten Start, die Erweiterung bei der nächsten Aktion oder Zeitleiste. Heute wird der Netzaufruf nicht abgewartet und Fehler werden nur geloggt (Inv-N 4.1 Punkt 2).
7. **Server-Funktionen statt direkter Tabellen-Schreibzugriffe:** `set_item_checked(item_id, checked, source)` setzt `is_checked`, `checked_at`, `checked_by` und meldet das Ereignis an die gebündelten Mitteilungen; `add_items(list_id, items[], source)` fasst gleiche Artikel zusammen (Menge erhöhen) und setzt `category_id` lokal geparst, die KI bestätigt später wie in der App. `source` ist `widget`, `siri`, `control`, `notification`; so verhalten sich alle Wege wie die App (heute fehlen `checked_by` und Push, Inv-N 4.1 Punkt 9).
8. **Konflikte:** zuletzt geschrieben gewinnt (Zeitstempel des Geräts); ein von anderen gelöschter Artikel verschwindet ohne Fehlermeldung (00 13). Eine Menge kann gebrochen sein ("0,5 kg"); das Modell nutzt überall Dezimalzahlen (heute Double/Int gemischt, Inv-N 4.1 Punkt 6).
9. **Eine App Group:** `group.com.shoply.app` bleibt; `group.com.dominik.shoply` entfällt aus den Entitlements (Inv-N 4.1 Punkt 11).
10. **Modulzustand, Kill-Switch, Pro-Status, Sprache, Darstellung und die Einstellung "Inhalte auf gesperrtem iPhone zeigen"** stehen in `system_state.json` der App Group; Widgets und Intents lesen sie bei jedem Eintrag.
11. **Abmelden** löscht alle `widget_*`-Schlüssel, Schnappschuss, Bilder, Warteschlange und Schlüsselbund-Einträge und lädt alle Widgets und Steuerelemente neu (wie heute, erweitert).
12. **Migration:** Die alten Schlüssel (`widget_list_<id>`, `widget_available_lists`, `widget_recent_items`, `widget_saved_recipes`, `widget_supabase_*`) werden beim ersten Start der neuen Version in den Schnappschuss übernommen und danach gelöscht. Die Widget-Kinds `ShoppingListWidget`, `QuickAddWidget`, `SavedRecipesWidget` bleiben unverändert, damit platzierte Widgets nicht vom Home-Bildschirm verschwinden (Inv-N 6); nur die angezeigten Namen ändern sich.

---

## 4. Widget "Liste"

Kind `ShoppingListWidget` (unverändert). Galerie-Name "Liste", Beschreibung "Sieh, was noch fehlt, und hak direkt im Widget ab." (EN "List", "See what's left and check items off right in the widget."). Größen: klein, mittel, groß; dazu die Sperrbildschirm-Familien (Kap. 10).

### 4.1 Zweck und Einstieg

- **Hauptfrage:** Was muss ich noch kaufen, und kann ich es gleich abhaken?
- **Einstieg:** Widget-Galerie; Seite Einstellungen > Widgets (15.3); einmalige Tipp-Zeile nach dem dritten abgeschlossenen Einkauf "Tipp: Leg dir deine Liste als Widget auf den Home-Bildschirm" (Ort: Tab Liste, Kapitel 10 bzw. 11; Text von B).
- **Konfiguration** ("Widget bearbeiten", System, `AppIntentConfiguration` mit `ListWidgetIntent`):
  - "Liste": "Liste von heute" (Standard, folgt 01 2.2) oder eine bestimmte Liste (Auswahl mit Name, offener Anzahl und Listenfarbe).
  - "Erledigtes zeigen": aus (Standard) / an. An: erledigte Artikel stehen durchgestrichen am Ende.
  - "Nach Kategorie gruppieren": an (Standard nur im großen Widget wirksam).
  - Ersetzt `SelectListIntent` (heute englisch "Select Shopping List"); die gewählte Liste wird übernommen.

### 4.2 Klein

**Aufbau von oben nach unten** (Innenmaß auf 390-pt-Geräten etwa 126 × 126 pt):
1. Kopfzeile: Listenname in `.headline`, Listenfarbe, eine Zeile, Ellipse. Rechts daneben die offene Anzahl in `.headline` rounded `monospacedDigit` in `label` ("9"). Kein `cart.fill`-Symbol (heute), die Farbe des Titels erkennt man.
2. 8 pt Abstand.
3. Bis zu 3 Artikelzeilen: Kreis (`circle`, `controlOutline`), 6 pt, Name `.subheadline` `label` (eine Zeile), Menge rechts in `number`-Optik `LabelSecondary` ("2"). Jede Zeile ist ein `Button(intent: ToggleItemIntent)`.
4. Fuß, nur wenn mehr offen sind: "+6 weitere" in `.footnote` `LabelSecondary`. Tippen auf den Fuß oder den Kopf öffnet die Liste.

**Beispielinhalt:** "Wocheneinkauf" (blau) · "9" | Bananen | Gurken 2 | Paprika rot | "+6 weitere".

**Bildbeschreibung für ChatGPT:** Ein einzelnes kleines quadratisches iOS-Widget auf einem unscharfen hellen Home-Bildschirm, weiße Fläche #FFFFFF mit den typischen stark gerundeten Widget-Ecken. Oben links in fetter 17-pt-Systemschrift "Wocheneinkauf" in Blau #007AFF, rechts oben die Zahl "9" in fetter, abgerundeter Ziffernschrift in Schwarz #000000. Darunter drei Zeilen, jede mit einem leeren grauen Kreisring #8A8A8E links und dem Artikelnamen in 15-pt-Schwarz: "Bananen", "Gurken" mit einer grauen "2" #636366 rechtsbündig, "Paprika rot". Unten in 13-pt-Grau #636366 "+6 weitere". Kein Einkaufswagen-Symbol, keine Karte im Widget, keine Schatten, keine Emojis, viel ruhiger Weißraum wie bei Apples Erinnerungen-Widget.

### 4.3 Mittel

**Aufbau** (zwei Spalten, links etwa ein Drittel):
- **Links (Überblick, ein großer Tippbereich `widgetURL` zur Liste):** Listenname `.headline` in Listenfarbe (bis 2 Zeilen); darunter die große Zahl "9" in `numberXL`-Optik (Rounded Bold) und "offen" in `.footnote` `LabelSecondary`; unten der Markt als Text mit Punkt ("● Lidl": 8-pt-Punkt in Markenfarbe, Name `.footnote` `label`, wie `StoreChip` ohne Kapsel, weil der Platz fehlt). Bei Präsenz statt des Markts: Punkt `presence` und "Lena kauft ein" (`.footnote`).
- **Rechts (Aktionen):** bis zu 4 Artikelzeilen wie im kleinen Widget, eine Spalte (nicht zwei wie heute), Menge rechtsbündig. Fuß "+5 weitere".

**Beispielinhalt:** links "Wocheneinkauf" / "9" / "offen" / "● Lidl"; rechts Bananen, Gurken 2, Paprika rot, Vollkornbrot, "+5 weitere". Um 17:42 wechselt "● Lidl" zu "● Lena kauft ein".

**Bildbeschreibung für ChatGPT:** Ein mittleres, breites iOS-Widget (etwa doppelt so breit wie hoch) auf weißer Fläche #FFFFFF mit großen runden Ecken. Links oben "Wocheneinkauf" in fetter blauer Systemschrift #007AFF, darunter sehr groß die Zahl "9" in fetter, abgerundeter schwarzer Ziffernschrift, darunter klein in Grau #636366 "offen" und ganz unten ein kleiner dunkelblauer Punkt #0050AA mit "Lidl" in Schwarz. Rechts, durch Weißraum getrennt (keine Linie), eine Spalte mit vier Zeilen: leerer grauer Kreisring #8A8A8E, dann "Bananen", "Gurken" mit grauer "2" rechts, "Paprika rot", "Vollkornbrot", jeweils in 15 pt Schwarz; darunter klein grau "+5 weitere". Die zweite Zeile zeigt den Moment des Abhakens: Kreis gefüllt in Avocado-Grün #3F7A1F mit weißem Häkchen, "Gurken" durchgestrichen in Grau. Keine Kacheln, keine Karten, keine Symbole in Quadraten.

### 4.4 Groß

**Aufbau von oben nach unten:**
1. Kopf: Listenname `.headline` in Listenfarbe; rechts ein runder Knopf `plus` (`action`, 28 pt Symbolfläche in 36-pt-Ziel; `Link` zu `shoply://lists/<id>?focus=add`, öffnet den Tab Liste mit fokussiertem Accessory, E-12).
2. Metazeile `.footnote` `LabelSecondary`: "9 offen · Lidl" bzw. "9 offen · Lena kauft gerade bei Lidl ein" mit `presence`-Punkt.
3. 12 pt Abstand.
4. Artikel, gruppiert nach Gang in Markt-Reihenfolge (Konfiguration "Nach Kategorie gruppieren"): Gang-Titel `.footnote` Semibold `label` mit Anzahl rechts ("Obst & Gemüse 3"), darunter die Zeilen: Kreis, Avo Symbol bzw. Kategorie-Symbol 17 pt `LabelSecondary` (bis xxxL), Name `.body`, Menge rechts. Gang-Titel zählen als Zeile in der Höhenberechnung (3.3). Ohne Gruppierung: reine Zeilenliste.
5. Fuß links "+3 weitere" (`.footnote`), rechts nichts.
6. **Ersparnis-Zeile** (nur Modul Angebote, Einzelschalter "X von Y im Angebot · gespart" an, echte PLZ, kein Kill-Switch): `tag` 13 pt `LabelSecondary` plus "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart" in `.footnote` `label`, bis 2 Zeilen; "in deiner Region" steht hier nicht (Platz), dafür liegt die Zeile nur bei echter PLZ vor. Tippen öffnet `/offers/list/<id>`. Kein gelbes Schild im Widget (S-05). Entfällt ohne Lücke, wenn eine Bedingung fehlt.

**Beispielinhalt:** "Wocheneinkauf" · `plus` | "9 offen · Lidl" | Obst & Gemüse 3: Bananen, Gurken 2, Paprika rot | Backwaren 1: Vollkornbrot | Milch & Käse 3: Milch 2, Eier 10 Stück … | "+3 weitere" | "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart".

**Bildbeschreibung für ChatGPT:** Ein großes quadratisches iOS-Widget im Hellmodus, weiße Fläche #FFFFFF, große runde Ecken, auf einem unscharfen Home-Bildschirm. Oben links "Wocheneinkauf" in fetter blauer Systemschrift #007AFF, oben rechts ein freistehendes grünes Plus-Symbol #3F7A1F ohne Hintergrundkreis; darunter in kleinem Grau #636366 "9 offen · ● Lidl" mit dunkelblauem Punkt #0050AA. Darunter Abschnitte mit kleinen fetten schwarzen Gang-Titeln und grauer Anzahl rechts: "Obst & Gemüse 3" mit Zeilen "Bananen", "Gurken 2", "Paprika rot", dann "Backwaren 1" mit "Vollkornbrot", dann "Milch & Käse 3" mit "Milch 2"; jede Zeile hat links einen leeren grauen Kreisring #8A8A8E und ein feines graues Liniensymbol (Karotte, Brot, Tropfen), Namen in 17 pt Schwarz, Mengen grau rechtsbündig in abgerundeten Ziffern. Unten klein grau "+3 weitere" und darunter eine Zeile mit kleinem grauem Preisschild-Liniensymbol und schwarzem Text "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart". Keine Fortschrittsbalken, kein gelbes Schild, keine Karten, keine Trennlinien, Grün nur am Plus.

### 4.5 Interaktionen und Bewegung

- **Abhaken:** Tippen irgendwo auf eine Zeile führt `ToggleItemIntent` aus. Sofort (aus dem Schnappschuss): Kreis wird `checkmark.circle.fill` in `action` (Symbol-Übergang), Name durchgestrichen in `LabelSecondary`, Zahl im Kopf zählt herunter (`numericText`). Danach Server-Aufruf (3.8 Punkt 6); während er läuft, trägt der Kreis `.invalidatableContent()`.
- **Kein Wegspringen unter dem Finger** (heute Inv-N 3.1 Punkt 7): Eine im Widget abgehakte Zeile bleibt 5 Minuten durchgestrichen an ihrem Platz. Erneutes Tippen hakt sie wieder auf (das ist das Rückgängig des Widgets). Danach bzw. beim nächsten Zeitleisten-Eintrag nach 5 Minuten verlässt sie das Widget, die offenen Artikel rücken nach (`.push(from: .bottom)`). In der App gilt dagegen 00 10.3 (0,6 s und "Erledigt").
- **Von anderen abgehakt:** verschwindet beim nächsten Eintrag; kein Avatar im Widget (Platz). Der Kopf zeigt die neue Zahl.
- **Tippen auf Titel, Zahl, Fuß oder freie Fläche:** öffnet `/lists/:id` (01 8.3). Großes Widget `plus`: Tab Liste mit fokussiertem Accessory.
- **Alles erledigt:** Zeilen bleiben die 5 Minuten stehen; danach der Satz "Alles erledigt." in `.subheadline` mit `checkmark.circle` 22 pt `LabelSecondary` und darunter klein "Tippen zum Hinzufügen" (öffnet Accessory). Leere Liste ohne Vorgeschichte: "Noch nichts auf der Liste." (00 3.2). Heute zeigt eine ganz abgehakte Liste die durchgestrichenen Artikel und eine leere Liste "Alles erledigt!" mit Ausrufezeichen.
- **Haptik:** keine (3.5).

### 4.6 Zustände (zusätzlich zu 3.6)

| Zustand | Klein / mittel / groß |
|---|---|
| Liste von heute wechselt (anderer Tag, angeheftete Liste) | Widget mit "Liste von heute" folgt beim nächsten Eintrag; Titel wechselt mit Überblendung |
| Geteilte Liste, jemand kauft ein | mittel und groß zeigen die Präsenz ("Lena kauft ein"); klein nicht |
| Offline, ausstehendes Häkchen | Kreis gefüllt mit kleinem `arrow.triangle.2.circlepath` unten rechts |
| Artikel ohne Kategorie (KI noch nicht fertig) | Gang "Sonstiges" vorläufig; nach Bestätigung beim nächsten Eintrag am richtigen Platz |
| Modul Angebote aus, Kill-Switch, keine PLZ, Liste "Angebote ausblenden" | Ersparnis-Zeile entfällt ohne Lücke |

### 4.7 Große Schrift und 320 pt

- Zeilenanzahl nach Tabelle 3.3; die Höhe ist nie fest, der Fuß zählt mit.
- Ab AX1: Menge vor dem Namen ("2 Gurken"), Symbole im großen Widget entfallen, Gang-Titel entfallen (Gruppierung aus), mittleres Widget zeigt links nur Titel und Zahl.
- Ab AX3: kleines Widget zeigt Titel, Zahl und genau eine Zeile; mittleres links Titel und Zahl, rechts eine Zeile und "+8 weitere".
- 320 pt Breite (Anzeigezoom "Größerer Text", iPhone 13 mini u. a.): iOS verkleinert die Widgets (klein etwa 141 × 141 pt, mittel 292 × 141, groß 292 × 311; Werte vor dem Bau mit der WidgetKit-Größentabelle abgleichen). Die Höhenberechnung nimmt automatisch eine Zeile weniger; Namen kürzen mit Ellipse.
- Referenzgrößen zum Prüfen (Apple-Tabelle, abgleichen): 375 pt (SE 3) klein 148, mittel 321 × 148, groß 321 × 324; 390/393 pt klein 158, mittel 338 × 158, groß 338 × 354; 430 pt klein 170, mittel 364 × 170, groß 364 × 382.

### 4.8 Was sich gegenüber heute ändert

- Fläche über `containerBackground` statt eigener weißer bzw. #1C1C1E-Fläche mit doppeltem Rand; getönt, klar und StandBy funktionieren erst dadurch.
- Dynamic-Type-Stile statt 9 bis 17 pt fest; Zeilen aus Höhe berechnet statt 14 feste Zeilen, die im großen Widget abgeschnitten werden.
- Grün aus dem Token `action` statt `rgb(0.3, 0.75, 0.4)`; Listenfarbe im Titel statt `cart.fill`.
- Mittel: eine Spalte mit 4 Zielen statt 8 Zielen in zwei Spalten.
- Kein Fortschrittsbalken mehr im großen Widget (Fortschritt steht als Zahl im Kopf; 00 4.2 "Fortschritt in `label`").
- Abhaken zuverlässig (3.8), mit `checked_by`, gebündelter Mitteilung und Präsenz.
- Lokalisiert, mit VoiceOver-Labels.
- Dateien: `ios/ShoppingListWidget/ShoppingListWidget.swift` (neu aufgeteilt in `ListWidget.swift`, `ListWidgetViews.swift`, `ToggleItemIntent.swift`), `ios/Shared/*` (neu), `lib/data/services/widget_service.dart` (Schnappschuss v2), `lib/presentation/state/items_provider.dart` und `lists_provider.dart` (Schreiben über den Dienst statt direkt; diese Provider gehören Teil A, Anfrage über die stabile API laut `arbeitsteilung.md` Kap. 5), `ios/Runner/AppDelegate.swift` (Kanal `com.shoply.widget` um `writeSnapshot`, `drainPendingActions` erweitert).

---

## 5. Widget "Schnell hinzufügen"

Kind `QuickAddWidget` (unverändert). Galerie-Name "Schnell hinzufügen", Beschreibung "Setz Sachen, die du oft kaufst, mit einem Tipp auf deine Liste." Größen: klein, mittel.

### 5.1 Zweck und Einstieg

- **Hauptfrage:** Was kaufe ich oft, und steht es schon auf der Liste?
- **Konfiguration:** "Ziel-Liste" ("Liste von heute" als Standard oder eine bestimmte Liste).
- **Vorschläge:** Artikel aus dem eigenen Verlauf, die gerade nicht offen sind, sortiert nach "fällig" (Nachkauf-Rhythmus, 01 5.2 "Vielleicht auch") und dann nach Häufigkeit. Keine Angebote (S-05).

### 5.2 Aufbau

- **Kopf:** "Auf" in `.footnote` `LabelSecondary` und darunter der Name der Ziel-Liste in `.headline` Listenfarbe ("Wocheneinkauf"). So ist die Ziel-Liste immer sichtbar (heute fehlt sie, Inv-N 2.2). Rechts ein `plus` in `action` als `Link` zum Accessory der Ziel-Liste (freie Eingabe).
- **Zeilen:** klein 3, mittel 6 in zwei Spalten zu je 3 (die Zeilen sind ruhige Textzeilen, keine getönten Kärtchen; heute "Reihen identischer Karten", Inv-N 3.1 Punkt 10). Jede Zeile: `plus.circle` in `action` (17 pt), Name `.subheadline` `label`. Knopf `Button(intent: QuickAddItemIntent)` über die ganze Zeile.
- **Nach dem Tipp:** Die Zeile wird zu `checkmark.circle.fill` in `action` und "Auf der Liste" in `.footnote` `LabelSecondary` unter dem Namen (Symbol-Übergang). Erneutes Tippen innerhalb von 10 Minuten nimmt den Artikel wieder von der Liste (Rückgängig). Danach rückt beim nächsten Eintrag ein neuer Vorschlag nach.
- **Steht der Artikel schon offen** (z. B. von Lena hinzugefügt): Zeile zeigt `checkmark.circle` (Kontur) und "Steht schon drauf"; Tippen erhöht nicht die Menge (Schutz vor Doppelungen, heute Inv-N 4.1 Punkt 5), sondern tut nichts.

**Beispielinhalt (mittel):** "Auf" / "Wocheneinkauf" (blau) · `plus` | Tomaten, Gouda, Äpfel | Mineralwasser, Toastbrot, Spülmittel. Nach Tipp auf "Tomaten": "Tomaten · Auf der Liste".

### 5.3 Zustände

| Zustand | Anzeige |
|---|---|
| Noch kein Verlauf (neues Konto) | Vorschläge aus Avo Symbols der Grundartikel (Milch, Brot, Eier, Bananen, Butter, Tomaten), Fuß "Wird mit deinen Einkäufen persönlicher." |
| Ziel-Liste gelöscht | wie 3.6 |
| Offline | Hinzufügen wirkt sofort im Widget, geht in die Warteschlange |
| Abgemeldet, Modul: | wie 3.6 (Kern, kein Modul) |

### 5.4 Große Schrift und 320 pt

- Mittel ab xL: eine Spalte mit 3 Zeilen; ab AX1: klein 2, mittel 2 Zeilen; Kopf nur Listenname ohne "Auf" (VoiceOver liest "Hinzufügen zu Wocheneinkauf").
- 320 pt: wie 4.7.

### 5.5 Was sich ändert, Dateien

Ziel-Liste sichtbar, Rückmeldung und Rückgängig, Schutz vor Doppelungen, Kategorie über `add_items` (3.8), Menge als Dezimalzahl. Dateien: `ios/ShoppingListWidget/QuickAddWidget.swift` (neu), `QuickAddItemIntent.swift` (neu), Vorschlagsquelle im Schnappschuss (heute `widget_recent_items` aus `item_purchase_stats`).

### 5.6 Bildbeschreibung für ChatGPT

Ein mittleres iOS-Widget, breit, weiße Fläche #FFFFFF mit großen runden Ecken, auf einem unscharfen Home-Bildschirm. Oben links klein in Grau #636366 "Auf" und darunter fett in Blau #007AFF "Wocheneinkauf"; oben rechts ein freistehendes grünes Plus #3F7A1F. Darunter zwei Spalten mit je drei ruhigen Textzeilen ohne Kästen: links "Tomaten", "Gouda", "Äpfel", rechts "Mineralwasser", "Toastbrot", "Spülmittel", jede Zeile beginnt mit einem grünen Plus-im-Kreis-Liniensymbol #3F7A1F und schwarzem 15-pt-Text. Die Zeile "Tomaten" zeigt stattdessen einen gefüllten grünen Kreis mit weißem Häkchen und darunter klein grau "Auf der Liste". Keine getönten Kärtchen, keine Blitz-Symbole, keine Emojis.

---

## 6. Widget "Rezept"

Kind `SavedRecipesWidget` (unverändert; Konfiguration wechselt von statisch zu `AppIntentConfiguration`, vor dem Bau prüfen, dass platzierte Widgets erhalten bleiben). Galerie-Name "Rezept", Beschreibung "Ein Rezept mit Foto, das du gemerkt hast oder das heute dran ist." Größen: klein, mittel, groß.

### 6.1 Zweck und Konfiguration

- **Hauptfrage:** Was koche ich?
- **Konfiguration "Zeigen":** "Gemerkte Rezepte" (Standard; wechselt täglich durch die gemerkten), "Rezept der Woche", "Heute im Plan" (nur Modul Wochenplan; ohne Eintrag fällt es auf gemerkte zurück).

### 6.2 Aufbau

- **Klein:** Foto randlos als Hintergrund-Inhalt (nicht `containerBackground`, damit es in StandBy bleibt), unteres Drittel Verlauf #000000 0 auf 55 %, darauf Titel `.headline` `labelOnPhoto` (#FFFFFF, bis 2 Zeilen) und "35 Min" in `.footnote` #FFFFFF. Ein Ziel: `widgetURL` `shoply://recipe/<id>` (heute funktionieren die Zeilen-Links im kleinen Widget nicht, Inv-N 4.1 Punkt 7).
- **Mittel:** links das Foto quadratisch, konzentrisch über `ContainerRelativeShape` mit 8 pt Innenabstand; rechts Titel `.headline` `label` (bis 3 Zeilen), Metazeile `.footnote` `LabelSecondary` "35 Min · 2 Portionen" (plus "· 540 kcal" nur mit Modul Kalorien), unten zwei schlichte Ziele in `action`: "Ansehen" (`Link` Rezept) und "Auf die Liste" (`Link` `/recipes/:id/to-list`). Keine Knöpfe mit Flächen.
- **Groß:** oben Foto 16:10 über die volle Breite (oben konzentrisch, unten gerade), darunter Titel `.title3`-Optik (`.headline` reicht nicht für die Fläche; SwiftUI `.title3` Semibold), Metazeile, darunter Abschnitt "Auch gemerkt" (`.footnote` Semibold) mit zwei Zeilen: Thumbnail 36 pt (`radiusPhotoS`-Optik über `RoundedRectangle(cornerRadius: 8)`), Titel `.subheadline`, Zeit rechts. Jede Zeile ein `Link`.
- **Ohne Foto oder Foto unter 600 px:** Typo-Karte (00 9.6): Fläche `fill`, Titel `.title3`, bis zu vier Avo Symbols der Hauptzutaten in `LabelSecondary`.
- **Getönt/klar:** Foto `.widgetAccentedRenderingMode(.accentedDesaturated)`; der Titel bleibt lesbar, weil er auf dem Verlauf steht.

**Beispielinhalt:** "Ofengemüse mit Feta", "35 Min · 2 Portionen · 540 kcal"; groß zusätzlich "Shakshuka 25 Min", "Linsen-Dal 30 Min".

### 6.3 Zustände

| Zustand | Anzeige |
|---|---|
| Keine gemerkten Rezepte | "Noch keine gemerkten Rezepte. Tippe im Rezept auf das Lesezeichen." mit `bookmark` 22 pt `LabelSecondary`; Tippen öffnet den Tab Rezepte (heute mit hartem Zeilenumbruch, Inv-N 2.3) |
| Foto noch nicht im Container | Fläche in `photo_color` des Rezepts (00 9.6), Titel darauf; beim nächsten Eintrag das Foto |
| Rezept gelöscht oder nicht mehr gemerkt | nächstes gemerktes Rezept |
| "Heute im Plan" ohne Modul | wie Modul aus (3.6) |

### 6.4 Große Schrift und 320 pt

Ab xxxL entfällt im mittleren Widget die Metazeile, ab AX1 auch "Auf die Liste" (dann ist das ganze Widget ein Ziel); im großen Widget entfällt ab AX1 der Abschnitt "Auch gemerkt". Klein: Titel bis 2 Zeilen, Zeit entfällt ab AX1.

### 6.5 Was sich ändert, Dateien

Fotos statt grüner Gabel-Kreise in jeder Zeile (heute werden die mitgelieferten Bilder nicht gezeigt, Inv-N 3.1 Punkt 9); ein Rezept im Mittelpunkt statt einer Namensliste. Dateien: `ios/ShoppingListWidget/SavedRecipesWidget.swift` (neu als `RecipeWidget`-Ansichten, Kind gleich), Bild-Ablage im Schnappschuss, `lib/presentation/state/saved_recipes_provider.dart` (A, Anfrage: Bilder über `WidgetService` ablegen).

### 6.6 Bildbeschreibung für ChatGPT

Drei iOS-Widgets nebeneinander auf einem hellen, unscharfen Home-Bildschirm: klein, mittel, groß, alle mit den typischen großen runden Ecken. Das kleine zeigt randlos ein appetitliches Foto von Ofengemüse mit zerbröseltem Feta auf einem Blech, unten ein weicher dunkler Verlauf mit weißem fettem Text "Ofengemüse mit Feta" und klein "35 Min". Das mittlere ist weiß #FFFFFF: links dasselbe Foto als Quadrat mit gleichmäßig gerundeten Ecken, rechts "Ofengemüse mit Feta" fett schwarz, darunter grau #636366 "35 Min · 2 Portionen · 540 kcal", unten zwei grüne Textaktionen #3F7A1F "Ansehen" und "Auf die Liste" ohne Knopfflächen. Das große zeigt oben das Foto im Breitformat, darunter den Titel groß, die graue Metazeile und einen kleinen Abschnitt "Auch gemerkt" mit zwei Zeilen und kleinen Vorschaubildern: "Shakshuka 25 Min" und "Linsen-Dal 30 Min". Keine Sterne, keine Herz-Symbole, keine Emojis.

---

## 7. Widget "Wochenplan" (Modul Wochenplan)

Neues Kind `MealPlanWidget`. Galerie-Name "Wochenplan", Beschreibung "Was es heute und die nächsten Tage gibt." Größen: klein, mittel, groß; Sperrbildschirm rechteckig und inline (Kap. 10).

### 7.1 Zweck

- **Hauptfrage:** Was gibt es heute, und ist alles da?
- **Einstieg:** Galerie; Einstellungen > Widgets; einmalige Tipp-Zeile im Tab Plan nach der ersten geplanten Woche (Text für Kapitel 14).
- **Ziele beim Tippen:** Tag bzw. freie Fläche `/plan` am Tag (01 8.3, `shoply://plan?day=2026-11-11`, E-12); Rezept `/plan/recipe/:id?entry=` (Kapitel 14); Fuß "17 Zutaten fehlen" `/plan/to-list`.

### 7.2 Aufbau

- **Klein:** "Heute" in `.footnote` Semibold `LabelSecondary`; darunter das Foto des heutigen Rezepts als Inhalt mit Verlauf (wie Rezept klein) und Titel "Chili sin Carne" `.headline` #FFFFFF, darunter "4 Portionen". Ohne Foto Typo-Fläche `fill`. Nichts geplant: "Heute ist nichts geplant." `.subheadline` `label` und `calendar` 22 pt `LabelSecondary`, Tippen öffnet `/plan/add?day=`.
- **Mittel:** links (ein Drittel) "Heute" plus Foto quadratisch konzentrisch; rechts drei Zeilen für heute und die nächsten zwei Tage mit Eintrag: Tageskürzel `.footnote` Semibold ("Heute", "Fr", "Sa") in einer festen Spalte, Rezeptname `.subheadline` `label` (eine Zeile). Ein Tag ohne Eintrag wird übersprungen; zwei Rezepte am Tag stehen als zwei Zeilen ("Sa Gemüse-Curry mit Reis", "Sa Apfel-Crumble").
- **Groß:** Kopf "Wochenplan" `.headline` und "9.–15. Nov." `.footnote` `LabelSecondary`; sieben Tageszeilen Mo bis So: Kürzel, Rezeptname bzw. "–" in `labelTertiary`-Optik (`.tertiary`), heute in `.headline` Gewicht und mit `action`-Punkt links (Farbe nie allein: zusätzlich fett und "Heute" statt "Mi"); mit Modul Kalorien rechts kcal pro Portion `LabelSecondary` ("480 kcal"). Fuß: `cart` 13 pt plus "17 Zutaten fehlen noch auf Wocheneinkauf" `.footnote` `label`, Ziel `/plan/to-list`. Steht alles auf der Liste: "Alles für diese Woche ist auf der Liste."

**Beispielinhalt (groß):** Mo Spaghetti mit Linsen-Bolognese · Di Ofengemüse mit Feta · **Heute** Chili sin Carne · Do – · Fr Lachs mit Ofenkartoffeln · Sa Gemüse-Curry mit Reis, Apfel-Crumble (eine Zeile, Komma) · So – | "17 Zutaten fehlen noch auf Wocheneinkauf".

### 7.3 Zustände

Modul aus: "Wochenplan ist ausgeschaltet." (3.6). Keine Woche geplant: klein wie "nichts geplant", groß mit sieben "–" und Fuß "Woche planen" (Ziel `/plan`). Pro (falls der Plan Pro wird, F-05): Ansehen bleibt frei (00 16.2), der Fuß "17 Zutaten fehlen" trägt die Kapsel "Pro" und öffnet die Paywall erst in der App. Offline: Stand aus dem Schnappschuss.

### 7.4 Große Schrift und 320 pt

Ab xL im großen Widget ohne kcal-Spalte; ab AX1 nur die Tage ab heute (bis 4), Fuß bleibt. Mittel ab AX1: nur heute und der nächste Tag, Foto entfällt.

### 7.5 Was sich ändert, Dateien

Neu. Dateien: `ios/ShoppingListWidget/MealPlanWidget.swift` (neu), Plan-Daten im Schnappschuss aus `lib/presentation/state/plan_provider.dart` (Kapitel 14, B).

### 7.6 Bildbeschreibung für ChatGPT

Ein großes quadratisches iOS-Widget auf weißer Fläche #FFFFFF mit großen runden Ecken. Oben "Wochenplan" fett schwarz und klein grau #636366 "9.–15. Nov.". Darunter sieben ruhige Zeilen mit einer schmalen Spalte für den Tag und dem Rezeptnamen: "Mo Spaghetti mit Linsen-Bolognese", "Di Ofengemüse mit Feta", dann hervorgehoben in Fett mit einem kleinen avocadogrünen Punkt #3F7A1F davor "Heute Chili sin Carne", "Do –" in hellem Grau, "Fr Lachs mit Ofenkartoffeln", "Sa Gemüse-Curry mit Reis, Apfel-Crumble", "So –"; rechts in jeder belegten Zeile grau eine Kalorienzahl wie "480 kcal". Unten ein kleines graues Einkaufswagen-Liniensymbol und schwarzer Text "17 Zutaten fehlen noch auf Wocheneinkauf". Kein Kalender-Raster, keine farbigen Tagesblöcke, keine Emojis.

---

## 8. Widget "Kalorien und Wasser" (Modul Kalorien)

Neues Kind `CaloriesWidget`. Galerie-Name "Kalorien und Wasser", Beschreibung "Wie viel heute noch geht, und ein Glas Wasser mit einem Tipp." Größen: klein, mittel; Sperrbildschirm rund, rechteckig, inline; StandBy.

### 8.1 Zweck

- **Hauptfrage:** Wie viel kann ich heute noch essen, und habe ich genug getrunken?
- **Ziele beim Tippen:** freie Fläche `/calories`; "+250 ml" trägt im Hintergrund ein (`AddWaterIntent`); mittel "Eintragen" öffnet `/calories/add` (Mahlzeit nach Uhrzeit).

### 8.2 Aufbau

- **Klein:** oben `ProgressRing`-Optik als SwiftUI `Gauge` (`.accessoryCircularCapacity`-ähnlich, gezeichnet als Ring 64 pt, Spur `fill`, Wert `health` = `action`, Strich 10 % des Durchmessers wie 00 12.14); in der Mitte "640" `numberXL`-Optik verkleinert auf `.title2` rounded und darunter "übrig" `.caption`. Darunter eine Zeile: `drop.fill` mehrfarbig 15 pt, "1,25 von 2 l" `.footnote` `label`, rechts Kapsel "+250 ml" (`actionFill` mit `action`-Text, `.footnote` Semibold, Mindesthöhe 28 sichtbar, Ziel 36) als `Button(intent: AddWaterIntent)`.
- **Mittel:** links der Ring 96 pt mit "640" und "kcal übrig"; rechts drei Makro-Zeilen nach 00 12.17/4.7 (drei getrennte Zeilen, je ein dünner Balken in `health`, Spur `fill`, keine drei Farben): "Protein 62 / 110 g", "Kohlenhydrate 158 / 230 g", "Fett 53 / 70 g" (`.footnote`, Zahlen rounded); darunter die Wasser-Zeile wie klein. Rechts oben schlicht `plus` "Eintragen" in `action`.
- **Ziel überschritten:** Ring voll, Zahl "120" und "kcal drüber" in `warning` (#A85400 / #FF9F0A) mit `exclamationmark.triangle.fill` (Farbe nie allein).
- **Wasser erreicht:** "2 von 2 l" mit `checkmark` 13 pt; "+250 ml" bleibt (man darf mehr trinken).

**Beispielinhalt:** klein "640 übrig" · "1,25 von 2 l" · "+250 ml". Nach Tipp: "1,5 von 2 l" rollt (`numericText`), Wasser-Ring bzw. Zeile folgt.

### 8.3 Zustände

| Zustand | Anzeige |
|---|---|
| Modul aus | "Kalorien ist ausgeschaltet." (3.6) |
| Kein Ziel eingerichtet | "Richte dein Ziel ein, dann siehst du hier, was heute noch geht." Tippen öffnet `/calories/goals` |
| Heute noch nichts eingetragen | Ring leer, "2.000" "übrig"; kein "0 kcal gegessen" |
| Neuer Tag (nach Mitternacht) | Zeitleisten-Eintrag um 0:00 setzt den Tag zurück, ohne App-Start |
| Apple Health schreibt Wasser | wird gezählt, wenn Health-Lesen an ist (Kapitel 15) |
| Pro (falls Kalorien Pro wird) | Anzeige frei; "+250 ml" wird Kapsel "Pro" (3.6) |

### 8.4 Große Schrift und 320 pt

Ab xxxL entfallen im mittleren Widget die Makro-Balken (nur Text-Zeilen); ab AX1 zeigt mittel nur Ring und Wasser-Zeile, klein nur Zahl "640 kcal übrig" als Text ohne Ring plus "+250 ml".

### 8.5 Was sich ändert, Dateien

Neu. Dateien: `ios/ShoppingListWidget/CaloriesWidget.swift`, `AddWaterIntent.swift` (neu), Kalorien-Tageswerte im Schnappschuss aus dem Kalorien-Bereich (Kapitel 15, B), Server-Funktion `log_water(ml, source)`.

### 8.6 Bildbeschreibung für ChatGPT

Ein mittleres iOS-Widget auf weißer Fläche #FFFFFF mit großen runden Ecken. Links ein dicker Ring mit hellgrauer Spur #E9E9EE, zu zwei Dritteln in Avocado-Grün #3F7A1F gefüllt, in der Mitte groß "640" in fetter abgerundeter schwarzer Ziffernschrift und darunter klein grau #636366 "kcal übrig". Rechts drei schmale Zeilen: "Protein 62 / 110 g", "Kohlenhydrate 158 / 230 g", "Fett 53 / 70 g", jede mit einem dünnen grünen Balken auf grauer Spur, alle in derselben Farbe. Darunter eine Zeile mit einem blauen Wassertropfen-Symbol, "1,25 von 2 l" in Schwarz und rechts eine hellgrüne Kapsel #EEF5E4 mit grünem Text #3F7A1F "+250 ml". Oben rechts klein grün "+ Eintragen". Keine bunten Makro-Farben, keine Flammen-Emojis.

---

## 9. Widget "Avo fragen" (Modul Avo)

Neues Kind `AskAvoWidget`. Galerie-Name "Avo fragen" (Name aus `AppBrand.assistantName`), Beschreibung "Sprich mit Avo oder stell eine Frage." Größen: klein, mittel; Sperrbildschirm rund.

### 9.1 Zweck

- **Hauptfrage:** Was soll Avo für mich tun?
- Zählt nicht als zweiter Avo-Einstieg in der App (01 3, Systemzugänge). Kein Maskottchen (00 3.3), sondern der Avo-Kern.

### 9.2 Aufbau

- **Klein:** Avo-Kern-Symbol `avo.core` 44 pt in Vollfarbe (Kern `avoKern`, Ring `avoRing`), darunter "Frag Avo" `.headline` `label` und "Sprechen" mit `waveform` `.footnote` `LabelSecondary`. Ein Ziel: `/avo/voice` (Sprachmodus, 01 8.3).
- **Mittel:** links Kern und "Frag Avo"; rechts drei Vorschlagszeilen nach Tageszeit und Modulen (keine Kärtchen), jede ein Ziel `shoply://avo?prompt=…`: morgens "Was koche ich heute?", nachmittags "Was fehlt für Chili sin Carne?" (aus dem Plan), abends "Trag mein Abendessen per Foto ein" (nur Modul Kalorien). Unten zwei Symbol-Ziele: `waveform` (Sprachmodus) und `camera` (`/avo?camera=1`, E-12).

### 9.3 Zustände

Modul aus: "Avo ist ausgeschaltet." mit Kern in `.secondary` (Zustand `neutral`), Tippen öffnet den Modul-Alert. Pro (falls Sprachmodus Pro wird): Widget bleibt, der Sprachmodus zeigt nach 00 16.2 die Bühne und erst das Sprechen die Paywall. Offline: unverändert; Avo selbst meldet dann "Braucht eine Verbindung".

### 9.4 Große Schrift und 320 pt

Ab AX1 im mittleren Widget nur ein Vorschlag; klein ohne "Sprechen".

### 9.5 Bildbeschreibung für ChatGPT

Ein kleines quadratisches iOS-Widget auf weißer Fläche #FFFFFF mit großen runden Ecken. Oben links ein kreisrundes Symbol: eine satte braune Kugel #7A4A24 mit einem hellgrünen Ring #C9DE6E darum, wie ein Avocadokern, ohne Gesicht. Darunter fett schwarz "Frag Avo" und klein grau #636366 ein Wellenform-Symbol mit "Sprechen". Viel Weißraum, keine Figur, keine Sprechblase, keine Emojis, keine Farbverläufe.

---

## 10. Sperrbildschirm (rund, rechteckig, inline)

Sperrbildschirm-Widgets sind immer vibrant (3.2): einfarbig, Gewicht statt Farbe, kein Hintergrund. Privatsphäre: Ist die Einstellung "Inhalte auf gesperrtem iPhone zeigen" aus (15.2, 15.3), stehen Artikel- und Rezeptnamen als `.privacySensitive()` und werden gesperrt ausgeblendet (Zahlen bleiben).

| Widget | Rund (`accessoryCircular`) | Rechteckig (`accessoryRectangular`) | Inline (`accessoryInline`) |
|---|---|---|---|
| Liste | `Gauge` mit Anteil erledigt (2 von 11), in der Mitte "9" rounded und darunter `checklist` 10 pt; Ziel Liste | Zeile 1 `.headline`: "Wocheneinkauf · 9"; Zeile 2 bis 3 `.body`: "Bananen, Gurken, Paprika, Vollkornbrot …" (fortlaufend, Ellipse); Ziel Liste | `checklist` "Wocheneinkauf: 9 offen" |
| Wochenplan | – | Zeile 1 "Heute"; Zeile 2 "Chili sin Carne"; Zeile 3 "Fr: Lachs mit Ofenkartoffeln" | `fork.knife` "Heute: Chili sin Carne" |
| Kalorien und Wasser | `Gauge` kcal (gegessen von Ziel), Mitte "640", unten "kcal" | Zeile 1 "640 kcal übrig"; Zeile 2 `drop.fill` "1,25 von 2 l"; Zeile 3 dünner Kapazitätsbalken kcal | `flame` "640 kcal übrig" |
| Avo fragen | `avo.core` 28 pt einfarbig; Ziel Sprachmodus | – | – |

- Nicht interaktiv: Tippen öffnet nach dem Entsperren das Ziel. Abhaken geschieht auf dem Home-Bildschirm, im Widget der App oder in der Mitteilung (S-07).
- Leer bzw. Modul aus: rechteckig "Wocheneinkauf · alles erledigt" bzw. "Wochenplan aus"; rund zeigt "–".
- Dynamic Type: das System skaliert; ab AX1 rechteckig nur zwei Zeilen.

**Was sich ändert:** Heute gibt es keine Sperrbildschirm-Widgets (Inv-N 3.1 Punkt 11). Dateien: Familien in `ListWidget.swift`, `MealPlanWidget.swift`, `CaloriesWidget.swift`, `AskAvoWidget.swift`.

**Bildbeschreibung für ChatGPT:** Ein iPhone-Sperrbildschirm mit einem ruhigen, unscharfen Foto eines Marktstands als Hintergrund, oben die große Uhrzeit "17:40" und darüber "Mittwoch, 11. November". Unter der Uhr eine Widget-Reihe in halbtransparentem Weiß: links ein runder Ring zu einem Fünftel gefüllt mit der Zahl "9" und einem kleinen Listen-Symbol, daneben ein runder Ring mit "640" und "kcal", rechts ein rechteckiges Widget mit fetter Zeile "Wocheneinkauf · 9" und darunter "Bananen, Gurken, Paprika, Vollkornbrot …". Über der Uhr eine einzeilige Inline-Angabe mit Besteck-Symbol "Heute: Chili sin Carne". Alles einfarbig weiß im iOS-Sperrbildschirm-Stil, keine Farben, keine Emojis.

---

## 11. StandBy

StandBy zeigt kleine Widgets groß, ohne Hintergrund, nachts rot (vibrant). Geeignet und dafür geprüft: Liste (klein), Kalorien und Wasser (klein), Wochenplan (klein), Rezept (klein).

- **Ohne Hintergrund** (`showsWidgetContainerBackground == false`): Texte bleiben `.primary`/`.secondary`, der Ring nutzt Gewicht, nicht Farbe. Das Rezeptfoto bleibt als Inhalt (6.2) und wird nachts vom System rot getönt.
- **Interaktiv:** Abhaken im Listen-Widget und "+250 ml" funktionieren in StandBy (iOS 17). Großer Abstand zwischen Zeilen (3.7) verhindert Fehltipps auf dem Ladeständer.
- **Nachtmodus:** keine eigene Gestaltung nötig; geprüft, dass erledigte Zeilen über Durchstreichen und gefüllten Kreis erkennbar bleiben.

**Bildbeschreibung für ChatGPT:** Ein iPhone liegt quer auf einem Ladeständer in einer dunklen Küche, StandBy-Modus mit schwarzem Hintergrund. Links groß das Listen-Widget ohne Fläche: "Wocheneinkauf" in Blau #0A84FF, rechts davon "9" in fetter abgerundeter weißer Schrift, darunter drei Zeilen mit leeren grauen Kreisringen #7C7C80 und weißen Namen "Bananen", "Gurken 2", "Paprika rot". Rechts groß das Kalorien-Widget: ein Ring in hellem Avocado-Grün #A6D45F auf dunkelgrauer Spur #2C2C2E, in der Mitte "640" und klein "übrig", darunter ein Tropfen-Symbol mit "1,25 von 2 l" und eine dunkelgrüne Kapsel #25301A mit hellgrünem Text #A6D45F "+250 ml". Keine Karten, keine Rahmen, ruhig und gut aus zwei Metern lesbar.

---

## 12. Steuerelemente: Kontrollzentrum, Sperrbildschirm, Action Button

Ab iOS 18 (`ControlWidget`). Dieselben Steuerelemente erscheinen im Kontrollzentrum, unten auf dem Sperrbildschirm (statt Taschenlampe/Kamera) und auf dem Action Button. Heute ist `ShoppingListWidgetControl.swift` leer (Inv-N 1).

| Steuerelement | Symbol | Titel (Wert) | Aktion | Konfiguration | Modul |
|---|---|---|---|---|---|
| Artikel hinzufügen | `plus` | "Hinzufügen" ("Wocheneinkauf") | öffnet die App im Tab Liste der gewählten Liste mit fokussiertem Accessory (`shoply://lists/<id>?focus=add`) | Liste (Standard Liste von heute) | Kern |
| Liste öffnen | `checklist` | Listenname ("9 offen") | öffnet die Liste | Liste | Kern |
| Einkauf starten | `cart` | "Einkaufen" ("Wocheneinkauf") | öffnet direkt den Einkaufsmodus (`shoply://shopping?list=<id>`) | Liste | Kern |
| Frag Avo | `avo.core` | "Frag Avo" | Sprachmodus `/avo/voice` | – | Avo |
| Wasser | `drop.fill` | "Wasser" ("1,25 l") | trägt 250 ml ein, ohne zu öffnen | Menge 250 / 330 / 500 ml | Kalorien |

- **Empfehlung für den Action Button** (Text auf Seite Widgets, 15.3): "Frag Avo" oder "Artikel hinzufügen".
- **Rückmeldung:** iOS zeigt bei Knopf-Steuerelementen nur das kurze Aufleuchten; "Wasser" aktualisiert den Wert ("1,5 l").
- **Modul aus:** Steuerelement bleibt (iOS kann es nicht entfernen), Tippen öffnet die App mit dem Modul-Alert (15.4).
- **Gesperrt:** "Wasser" läuft ohne Entsperren; alle anderen öffnen die App und brauchen Face ID.
- **Bildbeschreibung für ChatGPT:** Das iOS-Kontrollzentrum mit dunkel getöntem Glas über einem unscharfen Home-Bildschirm. Neben den Systemknöpfen für WLAN und Taschenlampe eine Reihe runder Steuerelemente in derselben Glasoptik: ein Plus mit Beschriftung "Hinzufügen" und klein "Wocheneinkauf", ein Einkaufswagen mit "Einkaufen", ein Kreis-Symbol aus brauner Kugel #8A5A30 mit hellgrünem Ring #C9DE6E und "Frag Avo", ein Wassertropfen mit "Wasser 1,25 l". Alles in Weiß auf Glas wie Apples eigene Steuerelemente, keine bunten Kacheln.
