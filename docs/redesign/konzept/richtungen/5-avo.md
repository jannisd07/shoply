# Richtung 5: "Begleiter"

Stand: 07.11.2026. Eine von fünf Design-Richtungen für das komplette Redesign. Arbeitsname der App: Avo (austauschbar; überall, wo "Avo" als App-Name steht, lässt sich der finale Name einsetzen, die Figur heißt weiter Avo).

Grundlage: Jannis' Plan (`docs/Shoply-Ideen-und-Plan.md`, gilt bei Widersprüchen), Recherche zu Preisen und Bildern, Verbesserungsliste (16 Punkte), Funktionsliste (`chatgpt-redesign-prompt.md`, Abschnitt 3), Inventar unter `docs/redesign/konzept/inventar/`. Angesehen: `assets/avo/avo_waving.png`, `avo_thinking.png`, `tools/icon/app_icon_1024.png` (das in der Aufgabe genannte `assets/app_icon_1024.png` und `avo_happy.webp` existieren nicht).

---

## 1. Name und ein Satz

**Begleiter.** Die App ist ruhig, sachlich und aufgeräumt wie eine Apple-App, und in genau einem schwebenden Glasknopf wohnt Avo: eine kleine Avocado mit zwei Augen, die mitschaut, mitdenkt und sich mitfreut, ohne je den Inhalt zu verdecken.

Was diese Richtung von den anderen unterscheidet: Der Zustand der App wird nicht über Badges, Banner und Hinweis-Karten erzählt, sondern über Avos Ausdruck. Die Figur ersetzt Lärm, statt welchen hinzuzufügen.

---

## 2. Gefühl

**Emotion:** Vertraute Ruhe mit einem Lächeln. Man soll sich nicht beobachtet fühlen, sondern begleitet: wie mit jemandem einkaufen, der die Liste kennt, nichts vergisst und nicht dauernd redet. Erwachsen, warm, nie kindlich.

**Apple-Apps als Haltung (nichts davon kopieren):**
- **Memoji und Animoji:** viel Ausdruck mit sehr wenigen Mitteln. Avo zeigt Stimmung fast nur über die Augen.
- **Apple Invites:** Wärme und Festlichkeit, aber edel. Freude entsteht aus Material, Licht und Typografie, nicht aus Konfetti.
- **Fitness:** Belohnung ist verdient und selten. SF Pro Rounded für Zahlen und für die "Stimme" der App.
- **Erinnerungen:** die Liste ist der Star, der Haken ist die wichtigste Geste.
- **Wetter (Animationen):** Atmosphäre im Hintergrund, die die Lage spiegelt, ohne zu stören. Bei uns: Avos Stimmung spiegelt den Zustand von Liste und Tag.

---

## 3. Fünf Prinzipien

1. **Inhalt in der Mitte, Avo am Rand.** Avo lebt im einen Avo-Knopf. Auf einem Screen erscheint Avo höchstens einmal, nie in Listenzeilen, Karten oder Rezeptschritten. Wer Avo ausschaltet, verliert keine Funktion der Liste.
2. **Stimmung statt Meldung.** Statt roter Zähler und gestapelter Hinweis-Karten ändert Avo den Blick: aufmerksam, wenn er einen Vorschlag hat; zufrieden, wenn alles erledigt ist; schläfrig nachts. Wer mehr wissen will, tippt ihn an. Pro Screen höchstens eine Hinweiszeile im Inhalt.
3. **Ernst, wenn es ernst ist.** Bei Allergien, Geld, Löschen, Fehlern und Datenschutz gibt es kein Gesicht und keinen Witz. Dann spricht die App neutral in SF Pro, mit klaren Symbolen. Avo darf ehrlich sagen, was er nicht weiß ("Die Kalorien sind geschätzt, ca. 70 % sicher").
4. **Freude ist selten und verdient.** Große Reaktionen nur bei echten Momenten: Einkauf abgeschlossen, Wochenplan steht, Ziel erreicht, Serie gehalten. Jede Art höchstens einmal am Tag. Kleine Reaktionen (ein Blinzeln beim Abhaken) sind leise und kurz.
5. **Wärme aus Material, nicht aus Deko.** Warm wird die App über die Rundschrift in Avos Sätzen, über weiche Grüntöne aus der Frucht, über Federn und über Haptik im richtigen Moment. Keine Sticker, keine Muster, keine Illustrationen als Füllmaterial.

---

## 4. Farben

Die Palette kommt aus der Frucht selbst: **Schale** (Handlungsfarbe), **Fruchtfleisch** (Avos eigene Fläche), **Kern** (Angebot und Ersparnis). Der Rest ist fast neutral mit einem Hauch Grün, damit die App nicht nach Systemgrau-Klon aussieht, aber auch nicht nach Creme. Alle Werte sind adaptiv; Kontraste sind für Text auf der jeweiligen Fläche gewählt (Text primär > 15:1, Text sekundär > 6:1, Akzent auf Weiß 6,4:1).

| Rolle | Hell | Dunkel | Einsatz |
|---|---|---|---|
| Hintergrund | `#F4F5F1` | `#0B0C0A` | Basis jedes Screens, unter allem |
| Fläche 1 | `#FFFFFF` | `#1A1B18` | Gruppierte Sektionen, Zeilen, Rezeptkarten |
| Fläche 2 | `#E8EAE3` | `#262823` | Eingabefelder im Inhalt, Segmente, Nutzer-Nachrichten bei Avo |
| Trennlinie (nur innerhalb einer Sektion) | `#D9DCD3` | `#33352F` | eingerückt ab Textbeginn |
| Text primär | `#12140F` | `#F2F3EE` | Titel, Artikel, Fließtext, Rezeptschritte |
| Text sekundär | `#575C52` | `#A6AB9F` | Mengen, Metadaten, "Jannis hat Milch hinzugefügt" |
| Text tertiär | `#8A8F84` | `#6E7368` | nur Platzhalter und Deaktiviertes |
| **Akzent "Schale"** | `#3A6B22` | `#B5DB7A` | Buttons, Links, aktiver Tab, Häkchen. Text auf Akzent: `#FFFFFF` hell, `#15240B` dunkel |
| **Signatur "Fruchtfleisch"** | `#EDF2C2` | `#2A3115` | ausschließlich Avos Flächen: Avo-Blatt-Tönung, Avos Antwortkarten, Avo-Zeile auf der Startseite |
| Erfolg | `#3A6B22` (= Akzent) | `#B5DB7A` (= Akzent) | Bewusst keine zweite Grünstufe: Abhaken ist Aktion und Erfolg zugleich. Erfolgsmeldungen tragen zusätzlich ein Symbol (`checkmark.circle.fill`) |
| Warnung | `#B86E00` | `#FFB547` | Läuft ab, Mitteilungen aus, PLZ fehlt |
| Fehler / Löschen | `#C9372C` | `#FF6B5E` | Destruktive Buttons, Fehlerzeilen, Allergie-Warnung |
| **Angebot / Ersparnis "Kern"** | Text `#7A4A1E` auf `#F5E6D3` | Text `#E8B27A` auf `#33241A` | Angebots-Markierung an Artikeln, Sparzeile, "laut Händler"-Preise. Kakaobraun, kein Rot: Sparen ist eine gute Nachricht, kein Alarm |
| Pro-Kennzeichen | Text `#3A6B22`, Rand `#3A6B22` 1 pt | Text `#B5DB7A`, Rand `#B5DB7A` | Kleine Kapsel "Pro", nie gefüllt, nie Gold |

**Listenfarben** (für Listensymbol, Punkt im Listenwähler und Widget-Akzent; nie als Flächenfüllung einer ganzen Liste):

| Name | Hell | Dunkel |
|---|---|---|
| Avocado | `#4E8A2A` | `#9CCF6B` |
| Blau | `#2F6BD8` | `#6FA0FF` |
| Lila | `#7A4FD0` | `#B49BFF` |
| Beere | `#B83A6A` | `#FF85B3` |
| Tomate | `#C9432F` | `#FF7F6B` |
| Kürbis | `#C76A12` | `#FFAE5C` |
| Senf | `#A88400` | `#F0CF4A` |
| Petrol | `#1B7F86` | `#5CD0D6` |
| Grafit | `#5C6168` | `#A3A9B1` |

Die heutigen Listen-Hintergründe (Verläufe, Bilder) entfallen als Vollflächen. Ein gewähltes Listenbild bleibt erhalten und erscheint als kleines rundes Listensymbol und im Widget-Hintergrund (abgedunkelt).

**Markt-Chips:** Kapsel mit Marktname in Text primär und einem 8-pt-Punkt in Markenfarbe (Lidl `#0050AA`, ALDI Süd `#00005F`, ALDI Nord `#1F4CA0`, REWE `#CC071E`, EDEKA `#FFD400`, Kaufland `#E10915`, Netto `#FFE500`, Penny `#CD1414`, dm `#002878`). Keine Logos ohne Erlaubnis.

**Erhöhter Kontrast:** Akzent hell `#2C531A`, dunkel `#CCEB9D`; Text sekundär wird Text primär; Trennlinien `#B9BDB2` / `#4A4D45`.

---

## 5. Typografie

Systemschrift SF Pro mit Dynamic Type über alle Stufen inklusive Bedienungshilfen-Größen. **SF Pro Rounded** ist Avos Stimme: alles, was Avo sagt, und alle "lebendigen" Zahlen (Fortschritt, Kalorien, Ersparnis). Alles andere ist SF Pro. So hört man Avo, ohne ihn zu sehen.

| Stil | Schrift | Größe / Zeilenhöhe | Gewicht | Laufweite | Einsatz |
|---|---|---|---|---|---|
| Large Title | SF Pro | 34 / 41 | Bold | -0,4 pt | Listenname auf der Startseite, Tab-Titel |
| Title 1 | SF Pro | 28 / 34 | Bold | -0,4 pt | Rezepttitel, Paywall-Titel |
| Title 2 | SF Pro | 22 / 28 | Bold | -0,3 pt | Sheet-Titel, Abschnitte der Rezeptseite |
| Title 3 | SF Pro | 20 / 25 | Semibold | -0,2 pt | Gang-Überschriften im Einkaufsmodus |
| Avo spricht | SF Pro Rounded | 17 / 23 | Medium | 0 | Avo-Zeile auf der Startseite, Avos Antworten |
| Avo spricht groß | SF Pro Rounded | 28 / 34 | Semibold | -0,3 pt | Live-Transkript im Sprachmodus, Abschluss-Moment |
| Headline | SF Pro | 17 / 22 | Semibold | -0,4 pt | Abschnittsköpfe (Gänge: "Obst & Gemüse"), Zeilentitel |
| Body | SF Pro | 17 / 22 | Regular | -0,4 pt | Artikelnamen, Rezeptschritte, Einstellungen |
| Einkaufsmodus-Artikel | SF Pro | 22 / 28 | Semibold | -0,3 pt | Artikel im Einkaufsmodus (skaliert wie Title 2) |
| Callout | SF Pro | 16 / 21 | Regular | -0,3 pt | Sparzeile, Hinweiszeile |
| Subheadline | SF Pro | 15 / 20 | Regular | -0,2 pt | Mengen, "von Jannis", Metadaten |
| Footnote | SF Pro | 13 / 18 | Regular | -0,1 pt | Quellenangaben ("Foto: Open Food Facts, CC BY-SA"), "laut Händler" |
| Caption | SF Pro | 12 / 16 | Medium | 0 | Tab-Beschriftungen, Pro-Kapsel |
| Zahl groß | SF Pro Rounded | 48 / 52 | Bold | -0,5 pt, Ziffern tabellarisch | Kalorien übrig, Fortschritt "7 von 11" |

Regeln: Hierarchie aus Gewicht und Größe, keine Großbuchstaben-Kicker, keine Kursiven. Fließtext immer in Text primär. Kein Text in festen Höhen: Zeilen, Eingabeleiste und Buttons wachsen mit der Schrift (behebt den abgeschnittenen Text der Eingabeleiste auf dem iPhone 13 Pro bei Anzeigezoom). Ab den Bedienungshilfen-Größen stapeln sich Zeilen (Menge unter den Namen statt rechts daneben), Avo-Figuren werden ausgeblendet, Avos Augen im Knopf bleiben.

---

## 6. Material und Form

**Liquid Glass, nur Bedienebene:**
- Tab-Leiste unten (schwebende Kapsel) und **daneben der runde Avo-Knopf** als eigenes Glaselement (gleiche Höhe wie die Tab-Leiste, 56 pt Durchmesser, im iOS-26-Muster des abgesetzten Suchknopfs).
- Toolbars und Navigationsleisten (transparent, Inhalte scrollen darunter, Scroll-Edge-Effekt statt Linie).
- Eingabe-Accessory "Artikel hinzufügen" über der Tab-Leiste bzw. über der Tastatur.
- Avo-Blatt (Sheet in mittlerer Höhe), Teilhöhen-Sheets, Kontextmenüs, Pull-down-Menüs.
- Der schwebende Button "Zutaten auf die Liste" im Rezeptdetail und "Einkauf beenden" im Einkaufsmodus.

**Nie Glas:** Listenzeilen, Rezeptkarten, Avos Antwortkarten, Paywall-Pläne, Widgets-Inhalt. Kein Glas auf Glas: Inhalte im Avo-Blatt sitzen auf Fläche 1 bzw. Fruchtfleisch, nicht auf weiterem Glas. Das Avo-Blatt trägt eine sehr leichte Fruchtfleisch-Tönung (8 % Deckkraft) im Glas, damit man spürt, "hier ist Avo".

**Radien (konzentrisch, abgeleitet von 55 pt Geräteecke):**
- Avo-Blatt und andere Sheets oben: Geräteradius (Systemwert).
- Gruppierte Sektionen und Rezeptkarten: 26 pt bei 16 pt Rand zum Bildschirm.
- Elemente in Sektionen (Artikelbild-Kacheln, OFF-Fotos): 26 - 12 = 14 pt.
- Buttons, Chips, Markt-Chip, Eingabefeld: Kapsel.
- Häkchen: Kreis (normal 26 pt Zeichnung in 44-pt-Ziel; Einkaufsmodus 36 pt Zeichnung in 56-pt-Ziel).

**Tiefe:** Trennung über Tonstufen (Hintergrund, Fläche 1, Fläche 2), keine Schatten auf Inhalten. Die einzigen Schatten liefert das System-Glas. Avo selbst hat als einziges Element weiches Eigenlicht (seine 3D-Renderings), damit er "vor" der Oberfläche steht.

**Reduce Transparency:** Glas wird fest (`#FFFFFF` mit 1-pt-Rand `#D9DCD3` hell, `#1A1B18` mit Rand `#33352F` dunkel), Avos Augen bleiben sichtbar.

---

## 7. Ikonografie, Artikelbilder, Fotos und Maskottchen

**Symbole:** ausschließlich SF Symbols, Gewicht passend zur Schrift (Regular im Inhalt, Medium in der Tab-Leiste), mehrfarbig nur dort, wo Apple es vorsieht. Symbole stehen frei, nie in getönten Quadraten. Eigene Symbole nur für Avos Augen (als Custom Symbol im SF-Symbols-Raster, damit sie mit Schriftgröße und Gewicht skalieren).

**Artikelbilder (Verbesserungsliste 7):**
- Eigene Illustrationen für alle Kategorie-IDs und die ca. 200 häufigsten Artikel, im **gleichen Licht wie Avo**: einzelnes Objekt, weich schattiert wie ein matter Ton-Gegenstand, Licht von oben links, keine Kontur, kein Hintergrund, keine Gesichter (nur Avo hat ein Gesicht). Größe in Zeilen 32 pt, im Einkaufsmodus 44 pt. Sie stehen frei neben dem Namen, ohne Kachel.
- Produktfotos von Open Food Facts nur bei erkanntem Markenprodukt oder Barcode, in einer 14-pt-Kachel auf Fläche 2, mit Footnote "Foto: Open Food Facts, CC BY-SA" und Link in der Artikeldetailansicht.
- Keine Prospekt- oder Händlerfotos. Angebotszeilen ohne Lizenz zeigen die Kategorie-Illustration.

**Fotos:** Rezeptfotos randlos oben im Rezeptdetail, unter der Glas-Toolbar; natürliches Tageslicht, warme Holz- und Steinflächen, keine Stockfoto-Ästhetik. In Übersichten 4:3 mit 26-pt-Radius.

**Avo, die Figur (neu gezeichnet als "Avo 2"):**
Die heutige Figur (Arme, Beine, offener Mund, plastikgelbes Fruchtfleisch) wirkt kindlich. Avo 2 bleibt sofort erkennbar, wird aber erwachsener: matte, leicht samtige Schale in `#4E8A2A` bis `#2F5A1A`, Fruchtfleisch in gedämpftem `#E4EC9C` statt Neongelb, Kern `#7A4A1E` mit sanftem Glanz, kleinere Augen, Mund nur in freudigen Stimmungen. Arme und Beine gibt es nur in der ganzen Figur.

Drei Darstellungsstufen, klar geregelt:

| Stufe | Aussehen | Wo | Technik |
|---|---|---|---|
| **Augen** | zwei Punkte (ovale Augen) auf Fruchtfleisch-Kreis, ohne Körper | Avo-Knopf, Widgets, Sperrbildschirm, App-Icon | Custom SF Symbol bzw. Vektor, in Flutter animierbar |
| **Kopf** | halbe Avocado von vorn mit Kern und Gesicht, ohne Gliedmaßen | Avo-Blatt (oben), leere Zustände, Onboarding-Schritte, Sprachmodus | 3D-Renderings als WebP-Sprites, Augen und Mund als animierte Ebene |
| **Ganze Figur** | Avo 2 mit Armen und Beinen | Willkommens-Screen, Einkauf abgeschlossen, Paywall, Wochenplan fertig | 3D-Renderings, wenige Posen |

**Stimmungen** (je für Augen und Kopf; die ganze Figur hat nur 4 Posen):
- **Ruhig:** Normalzustand. Blinzelt in zufälligen Abständen (4-9 s), kein gleichmäßiger Takt.
- **Aufmerksam:** Avo hat einen Vorschlag (z. B. "Milch geht dir wohl bald aus"). Augen schauen leicht nach oben links zum Inhalt; ein 6-pt-Punkt in Fruchtfleisch am Knopfrand. Kein roter Badge.
- **Hört zu:** Sprachmodus aktiv. Augen größer, Glasrand des Knopfs atmet mit der Lautstärke.
- **Denkt:** Avo arbeitet. Augen wandern langsam, dazu Skeleton-Karte im Avo-Blatt statt Ladekreis.
- **Freut sich:** Augen als Bögen. Nach Abhaken des letzten Artikels, nach Wochenplan, Ziel erreicht.
- **Schläft:** 23 bis 6 Uhr und offline. Augen als Striche. Die App funktioniert normal, Avo antwortet weiterhin.
- **Neutral (kein Gesicht):** bei Fehlern, Allergie-Warnungen, Löschen, Geld. Dann zeigt der Knopf nur das Fruchtfleisch-Rund ohne Augen, und die Meldung kommt in SF Pro mit Symbol (Prinzip 3).

Regeln: höchstens eine Avo-Darstellung pro Screen; Avo nie im Einkaufsmodus, außer im Abschluss-Moment; Avo nie über Rezeptfotos; nie Avo-Witze bei Ernährung und Gewicht (keine Bewertung von Essen, kein Schämen). Ist das Modul Avo aus, verschwinden Figur und Knopf vollständig; die App bleibt komplett und neutral.

---

## 8. Navigation

**Tabs** (schwebende Glas-Kapsel, Symbol plus Beschriftung):

| Tab | Inhalt | Sichtbar |
|---|---|---|
| **Einkauf** (`cart`) | Startseite = die Liste von heute; über den Titel wechselt man Listen | immer (Kern) |
| **Rezepte** (`fork.knife`) | Entdecken, Gespeichert, Meine Rezepte, Ersteller | immer (Kern) |
| **Woche** (`calendar`) | Wochenplan: Rezepte wählen, Portionen, alles auf die Liste | nur mit Modul Wochenplan |
| **Tagebuch** (`flame`) | Kalorien, Wasser, Gewicht, Workouts, Challenges | nur mit Modul Kalorien |

Rechts daneben, abgesetzt: **der Avo-Knopf**. Maximal 4 Tabs plus Avo. Unter 350 pt Breite (Anzeigezoom, iPhone SE mit großem Text) und ab Bedienungshilfen-Schriftgrößen werden die Tab-Beschriftungen ausgeblendet; Langdruck zeigt den großen Inhaltsanzeiger von iOS, VoiceOver liest die Namen.

Module ohne Tab: Angebote (in Listen, Sparzeile, eigene Seite "Angebote der Woche" per Push aus der Sparzeile), Kosten teilen (im Abschluss-Ablauf und im Verlauf), Verlauf und Statistiken (Profil).

**Avo-Einstieg, genau einer:** der runde Avo-Knopf neben der Tab-Leiste.
- Tippen: der Knopf morpht nach oben ins **Avo-Blatt** (Sheet mittlere Höhe, ziehbar auf groß). Avo kennt den Kontext des aktuellen Screens (offene Liste, Rezept, Tagebuch-Tag) und zeigt dazu passende Vorschläge.
- Gedrückt halten: sofort **Sprachmodus**, Loslassen schickt ab (Walkie-Talkie-Prinzip). Kurz tippen auf das Mikrofon im Blatt: freier Sprachmodus bis "Fertig".
- Der Knopf ist auf allen Tab-Wurzeln sichtbar; in Unterseiten (Rezeptdetail, Einstellungen) bleibt er als schwebender Knopf unten rechts, im Einkaufsmodus, Kochmodus, Onboarding und auf der Paywall ist er ausgeblendet.
- Kein zweiter Einstieg: keine Avo-Streifen auf der Startseite, keine Avo-Buttons in Listen oder Rezepten. Die Avo-Zeile auf der Startseite (siehe 9) ist eine Aussage, kein Button; antippen öffnet dasselbe Blatt am Knopf, mit derselben Morph-Animation zum Knopf hin. Siri ("Frag Avo") und Kurzbefehle öffnen ebenfalls dieses Blatt.

**Profil und Einstellungen:** rundes Profilbild oben rechts in der Navigationsleiste jeder Tab-Wurzel (Muster aus App Store, Musik, Fitness). Öffnet ein großes Sheet "Profil" mit: Name und Pro-Status; **Module** (ein Schalter pro Modul, dieselbe Darstellung wie im Onboarding); **Preise & Angebote** weit oben (Modul-Schalter, Angebote in Listen, Vorschläge beim Tippen, "X von Y im Angebot", Spar-Hinweise auf der Startseite, automatische Markt-Erkennung, PLZ und Lieblingsmärkte); Avo (Stimme, Stimmungen an/aus, "Avo schläft nachts" an/aus); Ernährung und Allergien; Mitteilungen; Darstellung; Sprache; Verlauf und Statistiken; Hilfe; Datenschutz; Abmelden. Oben ein Suchfeld über alle Einstellungen.

**Wayfinding:** Jede Tab-Wurzel hat einen Large Title, der sagt, wo man ist. Unterseiten pushen von rechts mit Zurück-Pfeil; Sheets haben "Fertig" oben rechts und lassen sich nach unten wischen. Der Einkaufsmodus ist ein Vollbild-Cover mit "Beenden" oben links.

---

## 9. Signatur-Screens

### Startseite: die Liste von heute (Tab Einkauf)
**Hauptfrage:** "Was muss ich heute besorgen?"
- Navigationsleiste: Large Title ist der Listenname, z. B. **"Wocheneinkauf"** mit Chevron; Tippen öffnet ein Pull-down-Menü aller Listen (mit Listenfarbe und Anzahl offen) plus "Alle Listen" und "Neue Liste". Rechts Profilbild und Teilen-Button.
- Unter dem Titel eine Zeile: Markt-Chip **"Lidl"** (blauer Punkt) und bei geteilten Listen gestapelte Avatare "Jannis kauft gerade ein" mit kleinem pulsierendem Punkt.
- **Avo-Zeile** in SF Pro Rounded auf Fruchtfleisch, eine Zeile, kein Bild: "Guten Morgen, Lena. 11 Sachen, davon 4 im Angebot." Passt sich der Tageszeit und dem Zustand an; ist alles erledigt: "Alles da. Schönen Abend." Bei Avo aus entfällt sie.
- **Sparzeile** (Modul Angebote, Kern-Farben): "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region". Antippen öffnet die Angebote der Woche. Ohne bestätigte PLZ keine Ersparnis-Zahl.
- Danach die Liste nach Gängen gruppiert: Headline "Obst & Gemüse", Zeilen mit Häkchen links, Illustration, Name in Body, Menge rechts in Subheadline ("1 kg"), Angebotsmarke als kleine Kern-Kapsel "0,99 €". "von Jannis" in sekundär, nur bei geteilten Listen.
- Unten das Glas-Accessory "Artikel hinzufügen" über der Tab-Leiste, mit Kamera-Symbol (Liste per Foto) rechts. Vorschläge aus dem Verlauf erscheinen als Chips über der Tastatur; "2 Milch" wird live als "2 × Milch" vorgezeigt.
- Rechts oben über der Liste der Button **"Einkaufen"** (Kapsel, Akzent), startet den Einkaufsmodus.
- Leer: Avo-Kopf (ruhig) mittig, darunter "Deine Liste ist leer." und Vorschläge "Was du oft kaufst" als Zeilen zum Antippen.

### Liste im Einkaufsmodus
**Hauptfrage:** "Was fehlt noch im Wagen?"
- Vollbild, Tab-Leiste und Avo-Knopf weg, Bildschirm bleibt an. Glas-Toolbar oben: "Beenden" links, Mitte "Lidl" mit Markt-Punkt, rechts das Teilen-Symbol.
- Darunter in SF Pro Rounded **"7 von 11"** mit einem dünnen Fortschrittsbalken in Akzent.
- Gänge als Title 3 ("Obst & Gemüse", "Kühlregal", "Backwaren"), Artikel in 22 pt Semibold, Illustration 44 pt, große runde Häkchen links (56-pt-Ziel). Mengen rechts groß genug, um sie im Gehen zu lesen.
- Abhaken: Häkchen füllt sich vom Finger aus, Name wird durchgestrichen, nach 0,6 s gleitet die Zeile in den eingeklappten Bereich "Im Wagen (4)" am Ende. Rückgängig: wieder antippen.
- Geteilt: Hakt Jannis etwas ab, gleitet es mit seinem Avatar-Punkt live heraus.
- Letzter Haken: kurzer Abschluss-Moment. Die ganze Figur Avo 2 erscheint von unten im Blatt, freut sich, darunter "Alles im Wagen." und "ca. 3,20 € gespart" (falls Angebote an). Dann zwei Buttons: "Einkauf abschließen" (fragt Markt, lernt ihn, bietet Kosten teilen an) und "Weiter einkaufen".

### Rezeptdetail
**Hauptfrage:** "Will ich das kochen, und was brauche ich dafür?"
- Randloses Foto oben unter der Glas-Toolbar (Zurück, Merken, Teilen). Darunter Title 1 "Ofengemüse mit Feta", Metazeile "35 Min · 520 kcal · vegetarisch", Ersteller mit Avatar.
- Portionen-Stepper (Kapsel, "4 Portionen"), Zutatenliste auf Fläche 1 mit Illustrationen; Zutaten, die schon auf der Liste stehen, tragen einen kleinen Haken; Angebots-Zutaten die Kern-Kapsel.
- Allergie-Hinweis (falls zutreffend) neutral oben: Symbol `exclamationmark.triangle.fill` in Fehlerfarbe, "Enthält Nüsse, du hast eine Nussallergie eingetragen. Ersatz: Sonnenblumenkerne." Kein Avo-Gesicht.
- Schritte nummeriert in Body, Varianten und Kommentare darunter.
- Schwebender Glas-Button unten: **"6 Zutaten auf die Liste"**; daneben (Kalorien-Modul) "Eintragen". Der Avo-Knopf schwebt rechts, sein Blatt kennt das Rezept ("Vegan machen?", "Für 2 umrechnen").
- Kochmodus über "Kochen" in der Toolbar: Vollbild, ohne Avo.

### Avo mit Sprachmodus
**Hauptfrage:** "Was soll Avo für mich erledigen?"
- Avo-Blatt in mittlerer Höhe, Glas mit Fruchtfleisch-Hauch. Oben der Avo-Kopf (48 pt) und in Rounded: "Was brauchst du?" Darunter drei kontextbezogene Vorschläge als Kapseln ("Wochenplan für 2", "Was fehlt für Lasagne?", "Wasser eintragen").
- Unten Eingabe-Kapsel mit Kamera, Textfeld, Mikrofon.
- **Sprachmodus:** Das Blatt wird groß. Der Avo-Kopf rückt in die Mitte und hört zu (große Augen), um ihn herum ein weicher Ring aus Fruchtfleisch-Licht, der der Stimme folgt. Darunter das Live-Transkript in "Avo spricht groß": "Setz Milch, Eier und zwei Gurken auf die Lidl-Liste". Avo antwortet mit Stimme, gleichzeitig erscheint der Text.
- **Ergebnisse als Karten** auf Fruchtfleisch (nicht Glas): "3 Artikel zu Lidl hinzugefügt", mit Zeilen und Button "Rückgängig".
- **Löschen nur mit Rückfrage:** Karte ohne Gesicht, in SF Pro: "Liste 'Party' mit 14 Artikeln löschen? Das lässt sich nicht rückgängig machen." Buttons "Löschen" (Fehlerfarbe) und "Abbrechen". Per Stimme genügt "Ja, löschen" nicht allein; es braucht den Tipp.
- Unterbrechen: Antippen des Kopfes stoppt Avos Sprache sofort.

### Paywall
**Hauptfrage:** "Lohnt sich Pro für mich?"
- Volle Seite, Hintergrund in Hintergrundfarbe, oben die ganze Figur Avo 2 in einer ruhigen, stolzen Pose, darunter Title 1 "Avo Pro" und ein Satz in Rounded: "Mehr Zeit beim Einkaufen. Mehr Ideen beim Kochen."
- Nutzenliste als 3-4 Zeilen mit SF Symbol in Akzent (frei, ohne Kachel) und Text primär. Die Inhalte kommen aus einer Konfiguration, damit jede spätere Pro-Entscheidung des Owners ohne Redesign passt (z. B. Wochenplan, Avo mit Stimme, Tagebuch mit Apple Health). Angebote stehen nie hier.
- Zwei Pläne als wählbare Zeilen auf Fläche 1: **Jährlich 29,99 €** (vorausgewählt, Zusatz "2,50 € pro Monat · 14 Tage gratis") und Monatlich 2,99 €.
- Vertrauens-Zeitleiste (drei Punkte): "Heute: alles freigeschaltet", "Tag 12: wir erinnern dich", "Tag 14: Abo beginnt, jederzeit kündbar".
- Haupt-Button "14 Tage gratis testen" (Akzent, Kapsel), darunter Footnote mit Preis nach der Testphase, "Käufe wiederherstellen", AGB, Datenschutz. Schließen-Kreuz oben rechts, sofort sichtbar.
- **Pro-Kennzeichnung im Rest der App:** Kapsel "Pro" mit Akzentrand neben dem Feature-Namen. **Kontextueller Hinweis:** eine Zeile im Inhalt, "Mit Pro plant Avo deine ganze Woche." mit Button "Ansehen", höchstens einmal pro Feature und Woche, ohne Avo-Gesicht. Gesperrte Funktionen zeigen eine echte Vorschau statt Schloss-Bildschirm.

### Widget
**Hauptfrage:** "Was steht drauf, und kann ich es gleich abhaken?"
- **Klein:** Listenname "Wocheneinkauf" in Headline, darunter 3 Artikel mit runden Häkchen-Buttons (interaktiv, App Intents), unten rechts Avos Augen. Sind alle erledigt: Avos Augen als Bögen und "Alles erledigt".
- **Mittel:** 6 Artikel in zwei Spalten, Kopf mit Markt-Chip "Lidl" und "7 offen", Plus-Button für Schnell hinzufügen.
- **Groß:** nach Gängen gruppiert, bis 12 Artikel, Sparzeile in Kern-Farben (falls Modul an).
- **Weitere Widgets:** Schnell hinzufügen, Wochenplan ("Heute: Ofengemüse"), Rezept, Kalorien und Wasser (Modul), Avo fragen (öffnet das Avo-Blatt).
- **Sperrbildschirm:** rund (Fortschrittsring "7/11" mit Avos Augen in der Mitte), rechteckig (3 Artikel), inline ("Lidl: 4 offen"). StandBy: große Ziffer "4 offen" in Rounded.
- **Getönt und klar:** alles einfarbig, Avos Augen bleiben als Form erkennbar, Häkchen als Kreis-Kontur.
- Control Center und Action Button: "Artikel hinzufügen", "Liste öffnen".

---

## 10. Bewegung und Haptik

**Federn:** Standard Dämpfung 1,0, Antwort 0,35 s. Nach Wisch oder Flick (Zeilen wegwischen, Sheets werfen) Dämpfung 0,8. Alles unterbrechbar und vom aktuellen Wert aus.

| Moment | Bewegung | Haptik |
|---|---|---|
| Avo-Knopf → Avo-Blatt | Glas morpht aus dem Knopf nach oben, Avos Augen wandern in den Kopf oben im Blatt (gemeinsame Ebene), Feder 1,0 / 0,4 s; zurück auf demselben Weg | keine |
| Halten für Sprache | Knopf wächst um 8 %, Augen werden groß, Glasrand beginnt zu atmen | leichter Impuls beim Start der Aufnahme |
| Abhaken | Häkchen füllt sich radial vom Berührungspunkt, Feder 1,0 / 0,25 s; Avos Augen im Knopf blinzeln einmal | leichter Impuls, auf demselben Frame |
| Zeile wandert nach "Im Wagen" | Nach 0,6 s Verzögerung gleitet die Zeile nach unten, Liste schließt die Lücke mit Feder 1,0 / 0,35 s | keine |
| Letzter Haken | Avo 2 hüpft von unten ins Bild, Feder 0,8 / 0,4 s, ein einziges Mal | Erfolg (Notification Success) |
| Wischen zum Löschen | Zeile folgt dem Finger 1:1, Gummiband am Ende, danach Rückgängig-Leiste 5 s | Einrasten beim Schwellwert |
| Markt erkannt | Markt-Chip blendet mit Feder ein, Avo schaut kurz zum Chip | keine |
| Fehler (z. B. offline) | Avo-Knopf wird neutral (kein Gesicht), sachliche Zeile im Inhalt | Fehler-Haptik nur bei vom Nutzer ausgelösten Aktionen |
| Avo denkt | Augen wandern langsam, Skeleton-Karte schimmert einmal pro 1,2 s | keine |
| Tabwechsel | Überblenden mit minimalem Versatz, kein seitliches Durchschieben leerer Seiten | Auswahl-Tick |

Avos Mikrobewegungen: Blinzeln 120 ms, zufällige Abstände; Blick folgt der Scrollrichtung um wenige Punkte; nach 30 s Inaktivität keine Bewegung mehr (Akku, Ruhe). Keine Dauerschleifen.

**Reduce Motion:** alle Bewegungen werden zu 0,2-s-Überblendungen, Avo wechselt Ausdrücke per Überblendung, kein Hüpfen, kein Atmen des Glasrands (statt dessen ein statischer Ring). **VoiceOver:** Avo-Knopf heißt "Avo, aufmerksam, 1 Vorschlag" bzw. "Avo"; Stimmungen werden als Wert vorgelesen, nie als Pflichtinformation. Häkchen sind Schalter mit "erledigt / offen".

---

## 11. App-Icon

**Idee:** Avo 2 als "Augen"-Stufe, randlos groß: eine halbe Avocado von vorn, leicht nach rechts geneigt, Fruchtfleisch füllt etwa 70 % der Fläche, der Kern sitzt unten, darüber zwei kleine ovale Augen. Keine Arme, kein Mund. Gebaut in Icon Composer mit vier Ebenen (Schale, Fruchtfleisch, Kern, Augen), damit Liquid Glass Licht und Tiefe pro Ebene setzt.

| Erscheinung | Gestaltung |
|---|---|
| **Hell** | Hintergrund Verlauf `#5A9632` → `#2F5A1A` von oben nach unten, Fruchtfleisch `#E4EC9C`, Kern `#7A4A1E` mit Glanzpunkt, Augen `#1E2A12` |
| **Dunkel** | Hintergrund `#0E120B`, Schale als schmaler Rand `#4E8A2A`, Fruchtfleisch abgedunkelt `#C9D47E`, Kern `#6A3F18`, Augen `#0E120B` |
| **Klar** | Ebenen als Glas: Fruchtfleisch milchig, Kern dichter, Augen opak; Hintergrund durchsichtig, die Silhouette trägt allein |
| **Getönt** | einfarbige Ebenen in Stufen: Kern am dunkelsten, Fruchtfleisch am hellsten, Augen als Aussparung |

Das Icon ist zugleich die Form des Avo-Knopfs, des Widget-Zeichens und des Sperrbildschirm-Rings: eine Form überall.

---

## 12. Stärken, Risiken, Aufwand und Performance in Flutter

**Stärken**
- Unverwechselbar: Keine andere Einkaufslisten-App hat eine Figur, die so leise und gleichzeitig so präsent ist. Bring! hat Illustrationen, aber keinen Begleiter.
- Löst Plan-Punkt "Avo hat genau einen Einstieg" elegant: Der Einstieg ist zugleich Statusanzeige, Vorschlagsträger und Sprach-Button.
- Weniger UI-Lärm: Stimmungen ersetzen Badges, Banner und Karten-Stapel der heutigen Startseite.
- Starker Grund für tägliche Nutzung: Avo begrüßt, erinnert ("Milch geht dir wohl bald aus") und freut sich mit; das bindet emotional, ohne Benachrichtigungs-Spam.
- Trägt Pro: Avo mit Stimme und Wochenplan lassen sich als "Avo kann mehr" verkaufen, mit klarem Bild.
- Abschaltbar: Ohne Modul Avo ist die App eine saubere, neutrale Apple-App.

**Risiken**
- **Kitsch-Gefahr:** Wenn die Figur zu oft oder zu laut auftritt, wirkt die App kindlich und der Pro-Preis unglaubwürdig. Gegenmittel: die Regeln aus 3 und 7 als harte Code-Regeln (ein Avo pro Screen, Freude einmal am Tag), Test mit Erwachsenen 30-55.
- **Kunst-Aufwand:** Avo 2 braucht ein konsistentes Set (6 Stimmungen × 2 Stufen + 4 Posen) und ca. 200 Artikel-Illustrationen im selben Licht. Ohne saubere Produktion wirkt es billig. Empfehlung: Blender-Szene mit festem Licht und Material, alle Renders daraus; Augen und Mund als separate Vektor-Ebene.
- **Mehrdeutigkeit der Stimmungen:** Wer Avos Blick nicht deutet, verpasst Vorschläge. Darum gibt es pro Screen trotzdem die eine Avo-Zeile bzw. Hinweiszeile im Inhalt; Stimmung ist Zusatz, nie einzige Information.
- **Name:** Die Richtung lebt von "Avo". Heißt die App am Ende "Shoply", bleibt Avo der Name der Figur und des Assistenten, das Icon zeigt trotzdem die Avocado.
- **Grün-Sättigung:** Fünf Richtungen nutzen Grün. Diese hebt sich über Fruchtfleisch und Kern ab, nicht über den Akzent.
- **Erfolg = Akzent:** spart eine Farbe, kann aber Aktion und Zustand verwischen. Darum tragen Erfolgsmeldungen immer ein Symbol.

**Aufwand (grob, zusätzlich zum Grund-Redesign)**
- Avo 2 Figur, Renders und Augen-Animation: 5-8 Tage (Gestaltung plus Einbau).
- Artikel-Illustrationen (200 + Kategorien): 6-10 Tage, gut stapelbar über Blender-Vorlage oder Bildmodell mit Nachbearbeitung.
- Avo-Knopf mit Stimmungen und Morph ins Blatt: 3-5 Tage.
- Sprachmodus (Spracherkennung, Sprachausgabe, Unterbrechen): 4-6 Tage, unabhängig von dieser Richtung ohnehin nötig.
- Widgets mit Augen-Zustand: 1-2 Tage zusätzlich.

**Performance in Flutter (Ziel iPhone 13 Pro, keine Frames über 16 ms)**
- Tab-Leiste und Avo-Knopf als **eine** native Glasgruppe (adaptive_platform_ui bzw. `LiquidGlassViewFactory.swift`), damit nur eine Platform View existiert. Avos Augen werden **im nativen Knopf** gezeichnet (Swift, SF-Symbol-Variante mit Symbol-Effekten), nicht als Flutter-Overlay über dem Glas. Die Stimmung kommt per MethodChannel als kleiner Enum-Wert.
- Avo-Blatt: native Sheet-Präsentation mit Glas, Inhalt in Flutter; kein eigener `BackdropFilter`. Falls ein Flutter-Sheet nötig ist, genau ein `BackdropFilter` mit begrenzter Fläche.
- Avo-Kopf und Figur als vorgerenderte WebP-Sprites (je Stimmung 1-3 Bilder, max. 512 px, vorab in den Bildcache geladen); keine Echtzeit-3D, keine großen Lottie-Dateien. Augen-Animation als `CustomPainter` mit `RepaintBoundary`.
- Artikel-Illustrationen als kleine WebP in festen Größen (32 und 44 pt @3x), gebündelt in der App, mit `precacheImage` für die sichtbare Liste.
- Avos Bewegungen ruhen nach 30 s, im Einkaufsmodus ist er aus: der teuerste Screen bleibt der leichteste.
- Stimmungs-Logik als einfacher Riverpod-Provider, der nur Zustände zusammenfasst (offene Vorschläge, Uhrzeit, Online-Status, Liste erledigt); er darf nie Netzabfragen auslösen.

---

## 13. Bildzeile für ChatGPT

Zwei iPhone-17-Pro-Mockups nebeneinander auf neutral hellgrauem Grund, beide im hellen Modus, im Stil einer echten iOS-27-App mit Liquid Glass (nur die Tab-Leiste, Toolbars und ein runder Glasknopf sind aus durchscheinendem Glas, alle Inhalte liegen auf festen Flächen), Schrift SF Pro, Avos Sätze in SF Pro Rounded, Hintergrund `#F4F5F1`, Flächen `#FFFFFF`, Text `#12140F`, Akzent `#3A6B22`, keine Großbuchstaben-Überschriften, keine Icons in farbigen Quadraten. Links die Startseite: Large Title "Wocheneinkauf" mit kleinem Chevron, darunter eine Kapsel "Lidl" mit blauem Punkt `#0050AA` und zwei kleine runde Avatare mit dem Text "Jannis kauft gerade ein", dann eine einzeilige Fläche in hellem Avocado-Fruchtfleisch `#EDF2C2` mit "Guten Morgen, Lena. 11 Sachen, davon 4 im Angebot.", darunter eine Zeile in Kakaobraun `#7A4A1E` auf `#F5E6D3` "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region", danach weiße abgerundete Gruppen mit den Überschriften "Obst & Gemüse" (Bananen 1 Bund, Gurke 2, Tomaten 500 g mit kleiner brauner Kapsel "0,99 €") und "Kühlregal" (Milch 2 l, Eier 10 Stück, Joghurt 4 Becher), jeder Artikel mit leerem runden Häkchen links und einer kleinen matt schattierten Illustration ohne Hintergrund, unten eine Glas-Eingabeleiste "Artikel hinzufügen" und eine schwebende Glas-Tab-Leiste mit "Einkauf", "Rezepte", "Woche", rechts daneben ein separater runder Glasknopf, in dem nur ein hellgrüner Kreis mit zwei kleinen dunklen ovalen Augen sitzt (Avo, die Avocado). Rechts der Einkaufsmodus im Vollbild ohne Tab-Leiste: oben eine Glas-Toolbar mit "Beenden" links und "Lidl" in der Mitte, darunter groß in Rundschrift "7 von 11" mit einem dünnen grünen Fortschrittsbalken `#3A6B22`, dann Gänge "Backwaren" (Vollkornbrot, Brezeln 4) und "Kühlregal" (Butter, Gouda in Scheiben) in großer, fetter Schrift mit großen runden Häkchen, von denen zwei grün gefüllt mit weißem Haken und durchgestrichen sind, und ganz unten eine eingeklappte Zeile "Im Wagen (4)". Die Stimmung ist ruhig, hochwertig und warm wie eine Apple-App, das Avocado-Gesicht ist die einzige Figur auf beiden Screens und wirkt erwachsen und dezent, nicht kindlich.
