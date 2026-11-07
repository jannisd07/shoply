# 16 Avo: Einstieg, Chat und Sprachmodus

Stand: 07.11.2026. Besitz: **Teil B** (Jannis, Mac 2), außer der Tab-Bar mit Avo-Kreis und dem Feld "Frag Avo" (Teil A, 00 Kap. 12.1). Baut auf `00-grundlagen.md` (Tokens, Komponenten, Regeln; Verweise als "00 Kap. x") und `01-navigation-und-struktur.md` (Navigation, Routen; Verweise als "01 Kap. x") auf. Plan-Bezug: Plan 1 (genau ein Einstieg), Plan 7 (Claude statt Gemini), Plan 12 (kann alles, Sprachmodus, Löschen nur mit Rückfrage, nur mit den Rechten der Person).

Inhalt: 1 Überblick und Grundsätze · 2 Avo-Kreis · 3 Feld "Frag Avo oder suche" · 4 Avo-Sheet (Gespräch) · 5 Leerer Chat mit Schnellaktionen · 6 Antwortkarten für alle Werkzeuge · 7 Rückfragen (Auswahl) · 8 Rückfrage-Karte Löschen · 9 Foto an Avo und Schätzungen · 10 Sprachmodus · 11 Vorab-Erklärung Mikrofon · 12 "So arbeitet Avo" (erste Nutzung) · 13 Avo-Einstellungen · 14 Modul aus · 15 Verantwortung und Technik · 16 Abläufe · 17 Offene Fragen · 18 Ergänzungen zum Fundament

Durchgehende Beispieldaten (passen zueinander, Datum Sa., 7. Nov. 2026):
- Person: Jannis. Mitglied der geteilten Liste: Lena.
- Listen: "Wocheneinkauf" (Markt-Chip Lidl, geteilt mit Lena, 11 Artikel, davon 9 offen), "Drogerie" (kein Markt, 4 offen), "Party" (REWE, 14 Artikel).
- Rezepte: "Ofengemüse mit Feta" (35 Min · 2 Portionen · 520 kcal pro Portion), "Linsencurry mit Spinat" (30 Min), "Ofenlachs mit Zitrone" (25 Min).
- Kalorien (Modul an): Ziel 2.000 kcal, heute 1.360 gegessen, 640 kcal übrig.
- Angebote (Modul an, PLZ 80331): bei Lidl diese Woche 4 von 11 Artikeln im Angebot, ca. 3,20 € gespart; "Milbona Frische Vollmilch 3,5 %, 1 l" 0,99 €, laut Händler statt 1,15 €, gültig bis Sa., 14. Nov.
- Verlauf: letzter Einkauf Sa., 31. Okt., Lidl, 14 Artikel, 42,80 €.

---

## 1. Überblick und Grundsätze

### 1.1 Was Avo ist

Avo ist der Assistent der App. Er hat kein Gesicht; er erscheint als **Avo-Kern** (00 Kap. 3.4). Man erreicht ihn in der App über **genau einen** Einstieg: den Avo-Kreis rechts neben der Tab-Bar (K-04, 01 Kap. 3). Avo kann alles, was die Person in der App kann, mit deren Login und deren Rechten, per Text, per Foto und per Stimme.

### 1.2 Die Teile dieses Bereichs

| Teil | Muster | Route | Hauptfrage | Besitz |
|---|---|---|---|---|
| Avo-Kreis | Glas-Kreis in der Tab-Bar | – | Wo frage ich Avo? | A (Bau), B (Zustände) |
| Feld "Frag Avo oder suche" mit Vorschlags-Panel | Tab-Bar-Zustand `askAvo` | – | Was suche oder frage ich? | A (Feld), B (Panel-Inhalt Avo) |
| Avo-Sheet (Gespräch) | Sheet mittel / groß | `/avo` (`?prompt=`) | Was soll Avo für mich tun? | B |
| Leerer Chat | Zustand des Avo-Sheets | `/avo` | Womit fange ich an? | B |
| Antwortkarten | Inhalt des Gesprächs | – | Was hat Avo getan, und kann ich es zurücknehmen? | B |
| Rückfrage-Karte Löschen | Inhalt des Gesprächs | – | Soll das wirklich endgültig weg? | B |
| Sprachmodus | Sheet groß | `/avo/voice` | Was sage ich Avo? | B |
| Vorab-Erklärung Mikrofon | Sheet mittel | – | Darf Avo zuhören? | B |
| "So arbeitet Avo" | Sheet mittel, einmalig | – | Was sieht und darf Avo? | B |
| Avo-Einstellungen | Push im Profil-Sheet | `/settings/avo` | Wie soll Avo sprechen, und was darf er einbeziehen? | B |
| Modul-Sheet "Avo ist ausgeschaltet" | Sheet mittel | (bei `/avo`, `/avo/voice` mit Modul aus) | Will ich Avo einschalten? | A (Muster), B (Text) |

### 1.3 Grundsätze für Avo (verbindlich)

1. **Ein Einstieg, keine Werbung.** Außer dem Avo-Kreis gibt es in der App keinen Avo-Knopf, keinen Avo-Streifen, keine Avo-Karte und keinen Avo-Namen an Funktionen, die ohne Gespräch laufen (01 Kap. 3). Systemzugänge (Siri, Widget "Avo fragen", Kontrollzentrum, Action Button) öffnen dasselbe Sheet bzw. den Sprachmodus.
2. **Handeln, dann ein Satz.** Avo führt aus und zeigt zuerst das Ergebnis als Ergebniszeile, danach höchstens einen bis drei Sätze. Keine Vorrede ("Ich schaue mal nach"), keine Wiederholung dessen, was die Zeile schon sagt.
3. **Rückgängig statt Rückfrage.** Jede umkehrbare Änderung passiert sofort und trägt "Widerrufen". Eine Rückfrage gibt es nur bei unklarem Ziel (Auswahl-Zeilen) und vor jedem Löschen (Rückfrage-Karte mit Tipp).
4. **Nur mit den Rechten der Person.** Avo arbeitet ausschließlich mit der Sitzung der angemeldeten Person; was sie nicht darf, darf Avo nicht (Kapitel 15).
5. **Ernst, wenn es ernst ist.** Bei Allergie, Geld, Fehlern und Löschen: Kern `neutral`, keine Figur, kein Witz, keine Ausrufezeichen. Das Maskottchen erscheint im ganzen Avo-Bereich nie (00 Kap. 3.3).
6. **Ehrlich.** Schätzungen heißen "geschätzt". Preise stehen mit "laut Händler" und "in deiner Region". Avo vergleicht keine Märkte und nennt keinen "günstigsten Markt" (Plan 8). Was Avo nicht weiß, sagt er.
7. **Sofort da.** Das Sheet öffnet aus dem lokalen Stand (Gespräch der letzten 24 Stunden, Vorschläge lokal berechnet); gearbeitet wird sichtbar nur im Avo-Kern, nie mit Spinner.

### 1.4 Glas-Budget in diesem Bereich (00 Kap. 8.5: höchstens 3)

| Situation | Glas-Views | Anzahl |
|---|---|---|
| Feld "Frag Avo" offen | Tab-Bar-View (enthält das Feld) · Toolbar-Gruppe des Screens dahinter; Accessory wird aus dem Baum genommen | 2 |
| Avo-Sheet mittel | Toolbar-Gruppe des Screens dahinter · Sheet-Kopf (`xmark`, `ellipsis`) · Eingabe-Kapsel im Sheet; Tab-Bar und Accessory sind verdeckt und werden aus dem Baum genommen | 3 |
| Avo-Sheet groß | Sheet-Kopf · Eingabe-Kapsel (der Screen dahinter ist abgedunkelt, seine Glas-Views werden entfernt) | 2 |
| Sprachmodus | Steuerungs-Gruppe unten | 1 |

Das Avo-Sheet ist deshalb in beiden Höhen eine **feste Fläche** (Ergänzung E-01): Auf ihm sitzt die gläserne Eingabe-Kapsel, ohne Glas auf Glas.

---

## 2. Avo-Kreis (Einstieg)

**Zweck (Hauptfrage):** Wo frage ich Avo? Er ist auf jedem Screen mit Tab-Bar an derselben Stelle, außerdem im Einkaufs- und Kochmodus (01 Kap. 3).

**Wann man ihn sieht:** auf allen Tab-Wurzeln und Pushes in Tabs, im Einkaufsmodus und im Kochmodus. Nicht in Onboarding, Paywall, Rezept-Editor, Kamera und solange ein großes Sheet offen ist.

### 2.1 Aufbau

- Teil der Tab-Bar (`AppTabBar`, 00 Kap. 12.1): runder Glas-Kreis, Durchmesser = Höhe der Tab-Kapsel, 8 pt rechts neben ihr, beide in einem `UIGlassContainerEffect`.
- Inhalt: Symbol `avo.core` (eigenes Vorlage-Symbol: Kern gefüllt, Ring als Kontur) in Systemgröße der Tab-Bar. In farbiger Darstellung Kern `avoKern`, Ring `avoRing`; im erhöhten Kontrast und in getönten Darstellungen wie ein Systemsymbol.
- Modul Avo aus: Symbol `magnifyingglass`, Funktion nur Suche (Kapitel 14). Form und Position bleiben gleich.

### 2.2 Zustände (Enum `AvoCoreState`, Kanal `setAvoState`)

| Zustand | Bild im Kreis | Wann |
|---|---|---|
| `ruhig` | steht still | Standard |
| `denkt` | Ring atmet (Helligkeit 70 bis 100 %), keine Größenänderung | eine Antwort läuft, auch bei geschlossenem Sheet |
| `hoertZu` / `spricht` | im Kreis nicht sichtbar, weil der Sprachmodus den Kreis verdeckt | – |
| `neutral` | Ring in `labelSecondary` | die letzte Antwort betraf Allergie, Geld, einen Fehler oder wartet auf eine Lösch-Rückfrage; bis zur nächsten Berührung des Kreises |
| fertig, ungelesen | Ring leuchtet einmal auf (Helligkeit 100 auf 140 auf 100 %, `springStandard`), dann `ruhig` | Antwort kam an, während das Sheet zu war; VoiceOver sagt höflich "Avo hat geantwortet" |

### 2.3 Interaktionen

| Geste | Ergebnis | Bewegung | Haptik |
|---|---|---|---|
| Tippen | Feld "Frag Avo oder suche" (Kapitel 3) | `springMorph` | keine |
| Halten (Systemdauer, ca. 0,4 s) | Sprachmodus direkt (Kapitel 10) | Sheet wächst aus dem Kreis, `springSheet` | leichter Impuls, wenn das Zuhören beginnt |
| Tippen im Einkaufsmodus | wie oben; die Bodenleiste ("+", "Einkauf beenden") weicht dem Feld | `springMorph` | keine |
| VoiceOver | "Avo, Taste. Doppeltippen zum Fragen." Eigene Aktion "Sprechen" | – | – |

Gedrückt-Zustand: Skalierung 0,97 (`springQuick`). Ab AX1 zeigt Halten zuerst den Large Content Viewer "Avo" (wie bei Tab-Bars üblich); Loslassen über dem Kreis startet dann den Sprachmodus, Wegziehen bricht ab. Der Sprachmodus bleibt zusätzlich über `waveform` erreichbar.

### 2.4 Große Schrift und 320 pt

Der Kreis wächst nicht mit Dynamic Type (wie die System-Tab-Bar). Bei 320 pt bleibt er unverändert; die Tab-Kapsel zeigt nur Symbole (00 Kap. 6.3). Bei vier Tabs plus Kreis passt die Leiste auf 288 pt Innenbreite: Tab-Kapsel ca. 228 pt, 8 pt Abstand, Kreis ca. 52 pt (Maße aus der nativen Tab-Bar).

### 2.5 Änderungen gegenüber heute

- `_AvoOrb` (`lib/presentation/screens/main_scaffold.dart:415-456`, Fläche mit hartem Schatten, Lucide-Icon, Größe nach Bildschirmbreite) entfällt; ersetzt durch den Kreis in der nativen View `shoply/tab_bar` (Teil A).
- Der Home-Hinweisstreifen "Avo: Fehlt was? Frag mich nach Rezepten." (`lib/presentation/screens/home/home_screen.dart:270-320`) entfällt ersatzlos.
- Neu: Zustände über den Kanal, Langdruck für Sprachmodus, Lupen-Variante bei Modul aus.

### 2.6 Bildbeschreibung für ChatGPT

iPhone-Screen im Hellmodus, unterer Rand: Eine schwebende Liquid-Glass-Kapsel mit vier Tab-Symbolen (Checkliste, Messer und Gabel, Kalender, Flamme) und kleinen Beschriftungen "Liste", "Rezepte", "Plan", "Kalorien"; der erste Tab ist ausgewählt und in Avocado-Grün #3F7A1F getönt. Rechts daneben, 8 pt abgesetzt, ein runder Glas-Kreis gleicher Höhe. Im Kreis sitzt ein kleines Zeichen: eine gefüllte braune Kugel #7A4A24 mit einem hellgrünen Ring #C9DE6E darum, wie der Kern einer aufgeschnittenen Avocado, ohne Gesicht. Dahinter scrollt unscharf durch das Glas eine weiße Liste auf hellgrauem Grund #F2F2F7. Keine Schatten außer der natürlichen Glastiefe, keine weiteren Farben.

---

## 3. Feld "Frag Avo oder suche"

**Zweck (Hauptfrage):** Was suche oder frage ich? Ein Feld für beides: Tippen zeigt sofort App-Treffer; Return schickt die Frage an Avo (01 Kap. 3 und 9).

**Wann:** nach Tippen auf den Avo-Kreis, von jedem Screen mit Kreis aus.

### 3.1 Aufbau (unten nach oben)

1. **Tastatur** (Return-Taste "Senden"; bei Modul Avo aus "Suchen").
2. **Tab-Bar im Zustand `askAvo`** (00 Kap. 12.1), direkt auf der Tastatur: links ein Glas-Kreis 44 pt mit dem Symbol des aktiven Tabs (Tippen: zurück, Tastatur schließt); rechts daneben die Glas-Kapsel: `camera` (44-pt-Ziel), Textfeld (`body`, Platzhalter "Frag Avo oder suche"), `waveform` (44-pt-Ziel). `waveform` entfällt nie.
3. **Vorschlags-Panel** (`AskPanel`, Ergänzung E-02) über dem Feld: feste Fläche `surfaceElevated`, `radiusCard`, `shadowFloat`, 8 pt Abstand zum Feld und zu den Seitenrändern, kein Glas. Inhalt je nach Eingabe (3.2).
4. Darüber bleibt der aktuelle Screen sichtbar und bedienbar, solange das Panel ihn nicht verdeckt. Das Accessory "Artikel hinzufügen" wird aus dem Baum genommen (zwei Eingabefelder übereinander wären doppeldeutig).

### 3.2 Inhalt des Panels

**Feld leer** (bis 5 Zeilen, Zeilen `body`, Symbol 17 pt `labelSecondary` frei davor):
1. Läuft ein Gespräch (jünger als 24 Stunden): Zeile "Gespräch fortsetzen" mit Unterzeile der letzten Frage ("Zutaten für Ofengemüse mit Feta …", `subheadline`, `labelSecondary`, eine Zeile), Symbol `avo.core`.
2. Bis zu drei Kontext-Vorschläge (dieselben wie im leeren Chat, Tabelle 5.2), Tippen schickt sie sofort an Avo.

**Mit Text** (das Panel wächst nach oben bis 8 pt unter den sicheren Bereich, `springStandard`; ab drei Zeichen ersetzt es den sichtbaren Inhalt vollständig):
- Sektionen aus 01 Kap. 9: Aktionen, Listen, Artikel, Rezepte, Einstellungen (lokal sofort, Online-Rezepte entprellt unten angefügt).
- Letzte Zeile, immer sichtbar am Ende: Symbol `avo.core`, "Frag Avo: „Was koche ich mit Feta?“". Return tut dasselbe.

### 3.3 Beispielinhalt

Tab Liste, Liste "Wocheneinkauf". Feld leer: "Gespräch fortsetzen · Was ist davon bei Lidl im Angebot?", "Zutaten für Ofengemüse mit Feta hinzufügen", "Was kaufe ich sonst noch regelmäßig?". Eingabe "feta": Sektion "Artikel": "Feta · auf Wocheneinkauf"; Sektion "Rezepte": "Ofengemüse mit Feta", "Griechischer Salat"; letzte Zeile "Frag Avo: „feta“".

### 3.4 Zustände

| Zustand | Verhalten |
|---|---|
| erster Start / kein Gespräch | ohne Zeile "Gespräch fortsetzen"; drei Vorschläge |
| lädt | alles lokal; Online-Rezepte erscheinen unten, ohne die Zeilen darüber zu verschieben |
| offline | `StatusRow` oben im Panel "Offline. Es werden nur gespeicherte Ergebnisse gezeigt."; die Zeile "Frag Avo" bleibt, Senden führt zum Offline-Zustand des Sheets (4.5) |
| Modul Avo aus | Kapitel 14: Platzhalter "Suchen", ohne `camera`, `waveform`, Vorschläge und "Frag Avo"-Zeile |
| Pro gesperrt | entfällt hier; Sperren zeigen sich erst als Ergebniszeile (6.6) |

### 3.5 Interaktionen, Bewegung, Haptik

- **Öffnen:** Der Kreis dehnt sich nach links zum Feld, die Tab-Kapsel schrumpft zum 44-pt-Kreis (`springMorph`), die Tastatur fährt gleichzeitig hoch; das Panel blendet ein und wächst aus dem Feld nach oben (Skalierung 0,96 auf 1, Ursprung am Feld, `springMenu`).
- **Return mit Text:** Das Avo-Sheet steigt in mittlerer Höhe auf; die Frage wandert als Text aus dem Feld in die Nutzer-Blase oben im Sheet (`springMorph`), die Tastatur schließt. Das Feld der Tab-Bar und die Eingabe-Kapsel des Sheets liegen an derselben Stelle; die Übergabe ist eine Überblendung zweier gleich aussehender Kapseln.
- **Return ohne Text:** nichts.
- **Abbrechen:** Tippen auf den Tab-Kreis links, Wischen nach unten auf dem Panel oder Tippen in den Screen darüber: Morph zurück (`springMorph`), Text bleibt bis zum nächsten Öffnen erhalten.
- **`waveform`:** Sprachmodus (Kapitel 10), bereits getippter Text wird als erster Satz übernommen.
- **`camera`:** Menü wächst aus dem Knopf (`springMenu`): "Foto aufnehmen" (`camera`), "Foto auswählen" (`photo.on.rectangle`). Weiter in Kapitel 9.
- Haptik: keine (Tippen in Felder und Senden lösen nie Haptik aus, 00 Kap. 11).
- Reduce Motion: Morph und Panel als Überblendung (`fadeReduced`).

### 3.6 Große Schrift und 320 pt

- Das Feld ist mehrzeilig (bis 3 Zeilen, dann scrollt es), Höhe aus der Textmetrik wie beim Accessory (00 Kap. 12.4); die native Glasform wird per Kanal nachgeführt.
- Platzhalter: "Frag Avo oder suche"; passt er nicht in eine Zeile (schmal oder ab AX1), "Frag Avo".
- 320 pt: Tab-Kreis 44 + 8 + Kapsel 236 pt, davon Textbereich ca. 148 pt zwischen `camera` und `waveform`.
- Ab AX1: Panel-Zeilen brechen um, die Unterzeile "Gespräch fortsetzen" bis zwei Zeilen. Das Panel nimmt bei AX-Größen sofort die volle Höhe ein.

### 3.7 Änderungen gegenüber heute und betroffene Dateien

Heute gibt es weder Feld noch Suche: Der Orb öffnet den Vollbild-Chat. Neu sind Feld, Panel und globale Suche. Betroffen: `main_scaffold.dart` (Teil A), neue Datei `lib/presentation/screens/avo/widgets/ask_panel.dart` (Teil B, Avo-Zeilen) und das Such-Panel von Teil A (Sektionen der App-Suche).

### 3.8 Bildbeschreibung für ChatGPT

iPhone im Hellmodus, Tastatur offen im unteren Drittel. Direkt auf der Tastatur eine schwebende Liquid-Glass-Leiste: links ein kleiner Glas-Kreis mit Checklisten-Symbol, rechts eine lange Glas-Kapsel mit Kamera-Symbol links, grauem Platzhalter "Frag Avo oder suche" #636366 und einem Wellenform-Symbol rechts. Darüber, 8 pt abgesetzt, ein weißes Panel #FFFFFF mit 20 pt Eckenradius und weichem Schatten, darin drei Zeilen in schwarzer Systemschrift #000000 mit kleinen grauen Symbolen davor: "Gespräch fortsetzen" mit grauer Unterzeile "Was ist davon bei Lidl im Angebot?", "Zutaten für Ofengemüse mit Feta hinzufügen", "Was kaufe ich sonst noch regelmäßig?", getrennt durch feine graue Linien #C6C6C8. Vor der ersten Zeile ein winziges Zeichen aus brauner Kugel #7A4A24 mit hellgrünem Ring #C9DE6E. Oben sieht man noch den großen Titel "Wocheneinkauf" und die ersten Artikelzeilen auf hellgrauem Grund #F2F2F7.

---

## 4. Avo-Sheet (Gespräch)

**Zweck (Hauptfrage):** Was soll Avo für mich tun? Das Sheet steigt über dem aktuellen Screen auf und kennt dessen Kontext.

**Wann:** Return im Feld "Frag Avo", ein Vorschlag im Panel, "Gespräch fortsetzen", Route `/avo` (auch aus Siri, Widget, Kontrollzentrum, Deep Link `shoply://avo`), Ende des Sprachmodus, wenn er aus dem Sheet gestartet wurde.

### 4.1 Aufbau (oben nach unten)

1. **Griff** (36 × 5, `labelTertiary`).
2. **Kopf** (`LargeTitleNavBar`, Variante Sheet): links Glas-Knopf `xmark` ("Schließen"), mittig "Avo" (`headline`), rechts Glas-Knopf `ellipsis` mit Menü (`AppMenu`): "Neues Gespräch" (`plus`), "Avo-Einstellungen" (`gearshape`, Ergänzung E-09). Keine Pro-Kapsel, kein Maskottchen, kein Untertitel.
3. **Gesprächsverlauf** auf `bgGroupedElevated`, scrollt unter Kopf und Eingabe durch (Scroll-Edge-Verlauf oben 24 pt, unten 40 pt). Seitenrand `pageMargin`, 24 pt zwischen zwei Runden, 12 pt zwischen den Blöcken einer Runde. Bausteine:
   - `UserBubble` (00 Kap. 12.32), rechts; mit Foto als Variante (Ergänzung E-05).
   - Arbeits-Zeile (`AvoStatusLine`, Ergänzung E-04): Avo-Kern 20 pt im Zustand `denkt`, daneben was gerade geschieht (`subheadline`, `labelSecondary`): "Liest Wocheneinkauf", "Sucht Rezepte", "Schätzt das Essen"; rechts schlicht "Stopp".
   - Ergebnis-Sektionen (Kapitel 6) in der Reihenfolge, in der Avo sie erzeugt.
   - `AvoMessage` (00 Kap. 12.32): links, ohne Blase, `body` in `label`, markierbar, Wort für Wort.
   - Rückfrage-Zeilen (Kapitel 7), Rückfrage-Karte (Kapitel 8).
4. **Kontext-Kapsel** (`ContextChip`, Ergänzung E-06), linksbündig 8 pt über der Eingabe, nur solange das Gespräch noch keine Frage hat oder der Kontext gewechselt hat: Kapsel `fill`, Glyph bzw. Symbol des Kontexts, Name (`subheadline`, `label`), `xmark` 13 pt (Kontext entfernen). Beispiel: grüner Listen-Glyph und "Wocheneinkauf".
5. **Eingabe-Kapsel** (Glas, schwebend, 8 pt über dem unteren sicheren Bereich bzw. auf der Tastatur): `camera` links, Textfeld (`body`, Platzhalter "Frag weiter", 1 bis 3 Zeilen), `waveform` rechts. Return "Senden" schickt.

### 4.2 Detents

- **Mittel** (etwa die halbe Bildschirmhöhe, mindestens 360 pt): Standard beim Öffnen. Der Screen dahinter bleibt sichtbar und bedienbar; Änderungen, die Avo dort macht, sieht man live (eine neue Zeile wächst in "Wocheneinkauf" ein, während das Sheet offen ist).
- **Groß:** durch Ziehen, durch Tippen in die Eingabe (Tastatur hebt das Sheet auf groß, 00 Kap. 12.23) und ab Textgröße AX3 direkt beim Öffnen.
- Form: schwebend mit 8 pt Abstand und `radiusSheet` in mittel; `radiusSheetFull` oben in groß. Fläche in beiden Höhen fest (`bgGroupedElevated`), siehe Ergänzung E-01.

### 4.3 Verhalten des Gesprächs

- **Neue Runde:** Die Nutzer-Blase scrollt an den oberen Rand des sichtbaren Bereichs (`springStandard`), darunter entsteht die Antwort. Wächst sie über den sichtbaren Bereich hinaus, scrollt nichts automatisch weiter (kein Ziehen unter dem lesenden Auge).
- **Reihenfolge einer Antwort:** Arbeits-Zeile, dann Ergebnis-Sektionen, sobald sie fertig sind (wachsen ein mit `springStandard`), dann der kurze Text. Die Arbeits-Zeile verschwindet mit der ersten Ergebnis-Sektion bzw. dem ersten Wort und reserviert eine Zeilenhöhe, damit nichts springt.
- **Stopp:** bricht die Antwort ab; schon ausgeführte Änderungen bleiben als Ergebniszeilen mit "Widerrufen" stehen; darunter `labelSecondary` "Angehalten."
- **Senden während einer Antwort:** möglich; die neue Frage wartet sichtbar unter der laufenden Antwort und geht danach raus (heute wird sie still verworfen).
- **Schließen während einer Antwort:** Die Antwort läuft weiter, der Kreis zeigt `denkt` (2.2). Jede ausgeführte Änderung erscheint zusätzlich als `UndoToast` auf dem Screen, auf dem man gerade ist ("3 Artikel zu Wocheneinkauf hinzugefügt · Widerrufen"), ohne Avo-Namen.
- **"Ansehen" in einer Ergebniszeile:** schließt das Sheet (`springSheet`) und öffnet das Ziel; das Gespräch bleibt und ist über "Gespräch fortsetzen" im Panel erreichbar.
- **Gesprächsdauer:** bleibt 24 Stunden bzw. bis "Neues Gespräch" (01 Kap. 3). "Neues Gespräch" leert den Verlauf sofort und zeigt `UndoToast` "Neues Gespräch begonnen · Widerrufen".
- **Darstellung der Antworten:** Absätze und einfache Aufzählungen (Punkt, Einzug 16 pt). Keine Überschriften, keine Tabellen, kein Fettdruck außer Namen von Listen und Rezepten (`body` Semibold). Zahlen nach 00 Kap. 3.2 ("3,20 €", "1.840 kcal").

### 4.4 Beispielinhalt (Sheet mittel über "Wocheneinkauf")

- Nutzer-Blase: "Setz die Zutaten für Ofengemüse mit Feta auf die Liste, für 4 Personen."
- Ergebnis-Sektion: `plus` "9 Zutaten zu Wocheneinkauf hinzugefügt", Unterzeile "Feta, Paprika, Zucchini, Kartoffeln und 5 weitere · für 4 Portionen", rechts "Widerrufen". Zweite Zeile `checkmark` "2 standen schon drauf", Unterzeile "Zwiebeln, Olivenöl", rechts "Ansehen".
- Mit Modul Angebote eine dritte Zeile `tag` "3 davon bei Lidl im Angebot", Unterzeile "ca. 1,40 € gespart, laut Händler", rechts "Ansehen".
- Avo-Text: "Erledigt. Zwiebeln und Olivenöl hatte ich nicht doppelt aufgenommen."

### 4.5 Zustände

| Zustand | Darstellung |
|---|---|
| erster Start / leer | Kapitel 5 (leerer Chat). Vor der allerersten Frage einmalig "So arbeitet Avo" (Kapitel 12) |
| lädt (Öffnen) | Gespräch der letzten 24 Stunden sofort aus dem lokalen Speicher; kein Indikator |
| arbeitet | Arbeits-Zeile mit Kern `denkt`; Ziel: erstes sichtbares Ergebnis oder Wort unter 1,5 s |
| Fehler | Zeile `exclamationmark.circle` in `danger`, "Das hat nicht geklappt.", Unterzeile in Alltagssprache ("Avo ist gerade nicht erreichbar."), schlicht "Erneut versuchen"; Fehler-Haptik; Kern `neutral`. Nie englische oder rohe Fehlertexte |
| offline | `StatusRow` unter dem Kopf "Offline. Avo braucht eine Verbindung."; die gesendete Frage steht als Blase mit Unterzeile "Nicht gesendet" und schlicht "Erneut senden". Kein automatisches Senden später (Avo ändert nie unerwartet im Nachhinein etwas) |
| Tageslimit erreicht (falls der Owner eins setzt, F-16-1) | Zeile neutral "Für heute ist Schluss mit Fragen. Ab morgen geht es weiter." Ist das Limit ein Pro-Vorteil, darunter eine Pro-Zeile (6.6), höchstens einmal pro Woche |
| Modul aus | Sheet nicht erreichbar; `/avo` öffnet das Modul-Sheet (Kapitel 14) |
| Pro gesperrt | einzelne Werkzeuge als Pro-Zeile (6.6); das Sheet selbst bleibt offen |
| nicht angemeldet | nicht möglich (Kreis nur nach Login sichtbar); Siri/Widget führen zur Anmeldung und danach ins Sheet |
| Kontowechsel | Gespräch und Modell-Sitzung werden verworfen (Kapitel 15) |

### 4.6 Interaktionen, Bewegung, Haptik

- Öffnen: `springSheet` aus dem Feld; Ziehen folgt 1:1, Loslassen mit Wurfprojektion und `springFling`; Detent-Einrasten nach Ziehen: Auswahl-Haptik.
- Schließen: Wischen nach unten, `xmark`, Zwei-Finger-Z. Danach morpht die Tab-Bar in den Zustand `normal` zurück.
- Langdruck auf eine Avo-Antwort: Kontextmenü "Kopieren", "Vorlesen" (`speaker.wave.2`, Ergänzung E-09).
- Langdruck auf eine Nutzer-Blase: "Kopieren", "Bearbeiten und neu senden" (übernimmt den Text in die Eingabe).
- Haptik: keine beim Senden, beim Antworten oder beim Öffnen. Nur die Ereignisse aus 00 Kap. 11 (z. B. Erfolg bei "Einkauf gespeichert", leichter Impuls beim Abhaken in einer Listen-Sektion, Warnung bei Allergen, Fehler bei Fehlschlag), im selben Frame wie das Bild.
- Reduce Motion: Wort-für-Wort-Einblenden bleibt (Deckkraft), Einwachsen der Sektionen wird Überblendung, Kern ohne Atmen (drei Punkte, 00 Kap. 3.4).
- VoiceOver: Reihenfolge Kopf, Verlauf (älteste zuerst), Kontext-Kapsel, Eingabe. Antworten mit "Avo:" vorangestellt; neue Antwort und Ergebniszeilen werden höflich angesagt ("Avo: 9 Zutaten zu Wocheneinkauf hinzugefügt. Widerrufen verfügbar."). Streaming wird erst nach dem vollständigen Satz angesagt, nicht Wort für Wort.

### 4.7 Große Schrift und 320 pt

- Ab AX3 öffnet das Sheet groß.
- Nutzer-Blase höchstens 80 % der Breite; ab AX3 volle Breite minus 48 pt links (bleibt als Blase erkennbar).
- Ergebniszeilen stapeln ab AX1: Symbol oben bündig zur ersten Textzeile, "Widerrufen" unter die Unterzeile, linksbündig zur Textkante (Muster `ItemRow` AX-Layout).
- Kontext-Kapsel bricht um (Name bis zwei Zeilen), `xmark` bleibt 44 pt Trefferfläche.
- 320 pt: Kopf passt (zwei Glas-Knöpfe 44 pt plus Titel "Avo"); Eingabe-Kapsel 288 pt, Textbereich ca. 200 pt.

### 4.8 Änderungen gegenüber heute und betroffene Dateien

| Heute | Neu |
|---|---|
| Vollbild-Screen `/avo` außerhalb der Shell (`lib/routes/app_router.dart:289-296`) | Sheet über dem aktuellen Screen, `/avo` öffnet es (Route in `lib/routes/areas/avo*`, Teil B) |
| Kopfzeile mit Zurück, Maskottchen im Salbei-Kreis, Georgia-Titel, Untertitel "denkt nach…", Kapsel "Premium", "Tastatur ausblenden", "+" (`avo_chat_widgets.dart:306-419`) | Sheet-Kopf mit `xmark`, "Avo", `ellipsis` |
| `AvoComposer` mit 34-pt-Senden in Terrakotta (`avo_chat_widgets.dart:142-243`) | Glas-Eingabe-Kapsel mit `camera` und `waveform`, Return sendet |
| Tipp-Punkte als Endlosschleife (`avo_chat_widgets.dart:262-265`) | Arbeits-Zeile mit Kern `denkt` und "Stopp" |
| Antworten in Georgia 15, User in 14 pt | beide `body` SF Pro |
| `_messages` nur im State, Modell erinnert sich trotzdem (`avo_chat_screen.dart:91`, `avo_assistant_service.dart:66-70`) | ein Gesprächsspeicher (lokal, 24 h) als einzige Quelle für Oberfläche und Modell-Verlauf |
| Kein Streaming, bis 5 Modellaufrufe ohne Abbruch | Streaming über die Edge Function, Stopp jederzeit |
| Kontext = erste Liste (`avo_chat_screen.dart:241`) | Kontext = Screen, von dem man kommt (Tabelle 5.2) |

Dateien: `lib/presentation/screens/ai/avo_chat_screen.dart`, `avo_chat_message.dart`, `widgets/avo_chat_widgets.dart` entfallen; neu `lib/presentation/screens/avo/avo_sheet.dart`, `avo_conversation_store.dart`, `widgets/avo_status_line.dart`, `widgets/context_chip.dart` (Teil B). Übersetzungen nach `lib/core/localization/translations/avo*` (Schlüssel `avo_…`), Georgia- und `PaperColors`-Nutzung fällt weg.

### 4.9 Bildbeschreibung für ChatGPT

iPhone im Hellmodus. Oben ist noch die Liste "Wocheneinkauf" auf hellgrauem Grund #F2F2F7 zu sehen, darin weiße Artikelzeilen; davor schwebt von unten ein Sheet über die halbe Höhe mit 8 pt Abstand zum Rand und großen, zum Gerät passenden Ecken, Fläche hellgrau #F2F2F7. Im Sheet-Kopf links ein runder Glas-Knopf mit X, mittig "Avo" fett, rechts ein Glas-Knopf mit drei Punkten. Rechts eine graue Nutzer-Blase #E9E9EE mit schwarzem Text "Setz die Zutaten für Ofengemüse mit Feta auf die Liste, für 4 Personen." Darunter eine weiße Sektion #FFFFFF mit 26 pt Eckenradius und zwei Zeilen wie Wallet-Transaktionen: Plus-Symbol, "9 Zutaten zu Wocheneinkauf hinzugefügt", graue Unterzeile #636366 "Feta, Paprika, Zucchini, Kartoffeln und 5 weitere · für 4 Portionen", rechts grüner Text "Widerrufen" #3F7A1F; zweite Zeile mit Häkchen "2 standen schon drauf". Darunter links ohne Blase in Schwarz der Satz "Erledigt. Zwiebeln und Olivenöl hatte ich nicht doppelt aufgenommen." Unten schwebt eine Glas-Kapsel mit Kamera-Symbol, grauem Platzhalter "Frag weiter" und Wellenform-Symbol.

---

## 5. Leerer Chat mit Schnellaktionen

**Zweck (Hauptfrage):** Womit fange ich an? Drei Sätze, die zum aktuellen Screen passen, antippbar.

**Wann:** erstes Öffnen, nach "Neues Gespräch", nach 24 Stunden ohne Gespräch. Meist sieht man die Vorschläge schon im Panel (3.2); der leere Chat erscheint, wenn man das Sheet über `/avo`, Siri oder das Widget ohne Frage öffnet.

### 5.1 Aufbau (oben nach unten, im Sheet unter dem Kopf)

1. Avo-Kern 44 pt im Zustand `ruhig` (Ergänzung E-03), linksbündig an `pageMargin`, 16 pt Abstand nach oben.
2. "Wie kann ich helfen?" (`title3`, `label`), 8 pt darunter.
3. `InsetSection` ohne Titel, drei Zeilen: Symbol 17 pt `labelSecondary` frei, Text `body` `label` (bricht um), keine Chevrons. Tippen schickt den Satz sofort.
4. Sektionsfuß (`footnote`, `labelSecondary`): "Avo nutzt deine Listen, Rezepte und Einstellungen, um zu antworten." plus schlicht "Datenschutz" (öffnet Rechtliches > Datenschutz).
5. Kontext-Kapsel und Eingabe-Kapsel wie in 4.1.

Kein Maskottchen (00 Kap. 3.3: nie in Avo-Antworten; der Assistent ist der Kern).

### 5.2 Kontext und Vorschläge

Avo bekommt den Kontext des Screens, von dem man kommt. Vorschläge eines Moduls erscheinen nur, wenn das Modul an ist; Angebots-Vorschläge nur mit Markt an der Liste und echter PLZ. Fallen Zeilen weg, rücken Kern-Vorschläge nach.

| Screen | Kontext an Avo | Kontext-Kapsel | Drei Vorschläge (Symbol) |
|---|---|---|---|
| Tab Liste, Liste mit offenen Artikeln | Liste (ID, Name, Markt, offene Artikel), Wochenplan heute | Glyph + "Wocheneinkauf" | "Zutaten für Ofengemüse mit Feta hinzufügen" (`plus`, nur wenn heute im Plan); "Was ist davon bei Lidl im Angebot?" (`tag`); "Was kaufe ich sonst noch regelmäßig?" (`clock.arrow.circlepath`) |
| Tab Liste, Liste leer | Liste | Glyph + Name | "Setz meinen letzten Einkauf wieder drauf" (`clock.arrow.circlepath`); "Was koche ich diese Woche?" (`fork.knife`); "Einkaufszettel abfotografieren" (`camera`) |
| Einkaufsmodus | Liste, Gang-Reihenfolge, Markt | Glyph + Name | "Was fehlt noch?" (`checklist`); "Hak Milch und Butter ab" (`checkmark`); "Setz Backpapier dazu" (`plus`) |
| Alle Listen, Verlauf | alle Listen, letzte Einkäufe | keine | "Was habe ich letzten Samstag gekauft?" (`clock.arrow.circlepath`); "Leg eine Liste für die Party an" (`plus`); "Wie viel habe ich im November gespart?" (`tag`) |
| Tab Rezepte | Ernährung, gemerkte Rezepte | keine | "Was koche ich heute?" (`fork.knife`); "Vegetarisch unter 20 Minuten" (`leaf`); "Zeig meine gemerkten Rezepte" (`bookmark`) |
| Rezeptdetail | Rezept (ID, Portionen) | `fork.knife` + "Ofengemüse mit Feta" | "Zutaten für 4 Personen auf Wocheneinkauf" (`plus`); "Womit ersetze ich Feta?" (`arrow.left.arrow.right`); "Am Mittwoch in den Wochenplan" (`calendar`) |
| Kochmodus | Rezept, aktueller Schritt, Timer | `frying.pan` + "Schritt 3 von 7" | "Nächster Schritt" (`chevron.right`); "Timer auf 10 Minuten" (`timer`); "Womit ersetze ich Sahne?" (`arrow.left.arrow.right`) |
| Tab Plan | Woche, Tage, Standard-Portionen | `calendar` + "9. bis 15. Nov." | "Füll die freien Tage vegetarisch" (`calendar`); "Alle Zutaten der Woche auf Wocheneinkauf" (`plus`); "Was gibt's heute?" (`fork.knife`) |
| Tab Kalorien | Tag, Ziel, Einträge | `flame` + "Heute" | "Trag mein Mittagessen per Foto ein" (`camera`); "Was kann ich mit 640 kcal noch essen?" (`fork.knife`); "250 ml Wasser eintragen" (`drop`) |
| Profil und Einstellungen | aktuelle Einstellungsseite | Symbol der Seite + Titel | "Schalte den Dunkelmodus ein" (`circle.lefthalf.filled`); "Trag eine Erdnussallergie ein" (`leaf`); "Welche Module gibt es?" (`switch.2`) |
| Siri, Widget, Deep Link ohne Screen | Liste von heute | keine | wie Tab Liste |

Die Kontext-Kapsel entfernen (`xmark`) heißt: Avo bezieht sich nicht mehr auf diesen Screen; Vorschläge wechseln zu denen ohne Kontext (Zeile "Siri, Widget …").

### 5.3 Zustände

| Zustand | Darstellung |
|---|---|
| erster Start | wie oben; Tippen auf einen Vorschlag öffnet zuerst "So arbeitet Avo" (Kapitel 12) |
| lädt | nichts zu laden; Vorschläge aus lokalem Stand |
| offline | `StatusRow` unter dem Kopf "Offline. Avo braucht eine Verbindung."; Vorschläge sichtbar, aber `labelTertiary` und nicht antippbar |
| Fehler | entfällt (kein Netzaufruf) |
| Modul aus | nicht erreichbar (Kapitel 14) |
| Pro gesperrt | Vorschläge zu Pro-Funktionen bleiben sichtbar; ihr Ergebnis ist die Pro-Zeile (6.6). Kein `ProBadge` an Vorschlägen (keine Werbung im leeren Zustand) |

### 5.4 Interaktionen, Bewegung, Haptik

Tippen auf einen Vorschlag: Die Zeile wird zur Nutzer-Blase (Text wandert nach rechts oben, `springMorph`), Kern und Titel blenden aus (`fadeReduced`). Keine Haptik. VoiceOver: Vorschläge sind Tasten ("Vorschlag: Was koche ich heute? Doppeltippen zum Senden").

### 5.5 Große Schrift und 320 pt

Ab AX1 entfällt der Kern 44 pt (wie das Maskottchen in leeren Zuständen, 00 Kap. 3.3); Titel und Vorschläge bleiben und brechen um. Bei 320 pt keine Änderung außer Umbruch.

### 5.6 Änderungen gegenüber heute

Heute: winkendes Maskottchen 64 pt, "Wie kann ich helfen?" in Georgia 24, vier Kapsel-Chips (zwei fest, zwei zufällig aus zehn, einer nach Onboarding-Priorität, darunter "Welcher Laden ist für meine Liste am günstigsten?"). Neu: Kern statt Maskottchen, drei Zeilen nach Kontext statt Zufall, der Marktvergleich-Chip entfällt (Plan 8), Onboarding-Prioritäten entfallen (K-22). Betroffen: `avo_chat_widgets.dart` (`AvoChatEmptyState`, `_SuggestionPill`), `avo_chat_screen.dart:50` (Chip-Liste), `app_translations.dart` (`chip_*`, 12 Schlüssel; der Schlüssel des Marktvergleichs wird gelöscht), Test `buildSuggestionChipKeys`.

### 5.7 Bildbeschreibung für ChatGPT

iPhone im Dunkelmodus, ein Sheet über die halbe Höhe mit Fläche #1C1C1E, darüber am oberen Rand abgedunkelt eine Liste auf Schwarz #000000. Im Sheet-Kopf links ein Glas-Knopf mit X, mittig "Avo" in Weiß, rechts ein Glas-Knopf mit drei Punkten. Darunter linksbündig eine kleine Kugel 44 pt in warmem Braun #8A5A30 mit einem hellgrünen Ring #C9DE6E, daneben nichts, darunter "Wie kann ich helfen?" in weißer, halbfetter Systemschrift. Darunter eine Sektion in #2C2C2E mit 26 pt Ecken und drei Zeilen in Weiß mit grauen Symbolen davor #98989F: Plus "Zutaten für Ofengemüse mit Feta hinzufügen", Preisschild "Was ist davon bei Lidl im Angebot?", Uhr "Was kaufe ich sonst noch regelmäßig?". Darunter kleine graue Fußzeile "Avo nutzt deine Listen, Rezepte und Einstellungen, um zu antworten. Datenschutz", "Datenschutz" in hellem Avocado-Grün #A6D45F. Unten eine graue Kapsel mit grünem Listen-Punkt und "Wocheneinkauf" mit kleinem X, darunter die schwebende Glas-Eingabe mit Kamera, "Frag weiter" und Wellenform.

---

## 6. Antwortkarten für alle Werkzeuge

**Zweck (Hauptfrage jeder Karte):** Was hat Avo getan, und kann ich es zurücknehmen? Bzw. bei Lese-Ergebnissen: Was ist der Stand, und was kann ich direkt damit tun?

### 6.1 Bauregeln (gelten für alle Karten)

- Ergebnisse stehen in einer `InsetSection` auf `surfaceElevated` (im Sheet), nie auf Glas, nie als Reihe identischer Karten.
- **Änderungen** sind `AvoResultRow` (00 Kap. 12.32): Symbol der Aktion 20 pt frei, Titel `body`, Unterzeile `subheadline` `labelSecondary`, rechts eine schlichte Aktion. Regel für rechts: "Widerrufen", solange widerrufbar; sonst "Ansehen"; sonst nichts. Tippen auf die Zeile selbst klappt die Einzelheiten auf (bis 20 Unterzeilen, `springStandard`, dann "Alle in Wocheneinkauf ansehen") bzw. öffnet das Ziel, wenn es keine Einzelheiten gibt.
- **Lese-Ergebnisse** nutzen die Komponente, die der Inhalt in der App hat (`ListRow`, `ItemRow`, `RecipeCard` als Zeile, `NutritionRow`, `ProgressRing`, `BarChart`), damit alles gleich aussieht wie am Ursprungsort. Höchstens 8 Zeilen, dann schlicht "Alle 9 ansehen".
- **Zustände einer Ergebniszeile** (Ergänzung E-07): "wird ausgeführt" (Symbol ersetzt durch Kern 20 pt `denkt`), fertig, "Rückgängig gemacht" (Titel `labelSecondary`, keine Aktion), "Nicht mehr widerrufbar" (die betroffenen Daten wurden inzwischen geändert; Unterzeile "Inzwischen geändert"), Teilfehler (zweite Zeile mit `exclamationmark.circle` in `danger` und "Erneut versuchen"), ausstehend offline (Sync-Zeichen `arrow.triangle.2.circlepath` 10 pt am Symbol).
- **Widerrufen** nimmt genau diese Aktion zurück (Gegen-Aktion, lokal gemerkt), solange das Gespräch existiert und die betroffenen Daten unverändert sind. Keine Haptik. VoiceOver: eigene Aktion "Widerrufen".
- **Geld** (Ersparnis, Beträge, Preise): keine Figur, Kern `neutral` im Sprachmodus, Werte immer mit Quelle ("laut Händler", "in deiner Region").
- **Pro-Sperre** als eigene Zeile (6.6), nie als Fehler.
- Ab AX1: Zeilen stapeln (4.7). Bei 320 pt bricht die Unterzeile um; rechts stehende Aktionen behalten 44 pt Trefferfläche.

### 6.2 Katalog: Werkzeug, Darstellung, Rückfrage

Heute 35 Werkzeuge (`avo_tool_declarations.dart`); verworfen werden `compare_list_prices` und der "günstigster Markt"-Teil von `search_offers` (Plan 8). Neu dazu kommen die Lücken aus dem Inventar (Kennzeichnung "neu").

**Listen und Artikel**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| `get_lists` | "Welche Listen habe ich?" | Sektion "Deine Listen" mit `ListRow`s (Glyph, Name, "9 offen · Lidl", Avatar-Stapel) | Chevron, Tippen öffnet | – |
| `get_list_contents` | "Was steht auf Wocheneinkauf?" | Sektion, Titel "Wocheneinkauf" mit Zähler "9 offen"; `ItemRow`s (normal), Kreis hakt ab (leichter Impuls), Name öffnet die Liste mit markiertem Artikel | – | – |
| `add_item_to_list` | "Setz 2 Milch auf die Liste" | `plus` "Milch zu Wocheneinkauf hinzugefügt", Unterzeile "Menge 2 · Milch & Käse"; mit Angebot: "0,99 € bei Lidl, laut Händler" | Widerrufen | Liste unklar: Kapitel 7 |
| `ask_pick_list` | – | Auswahl-Zeilen (Kapitel 7) | – | ist selbst die Rückfrage |
| `check_items` | "Hak Milch und Butter ab" | `checkmark` "2 Artikel abgehakt", Unterzeile "Milch, Butter" | Widerrufen | – |
| `update_item` | "Mach 3 Milch draus" | `pencil` "Milch: Menge 2 → 3" | Widerrufen | – |
| `move_items` | "Zahnpasta und Duschgel auf Drogerie" | `arrow.right` "2 Artikel nach Drogerie verschoben", Unterzeile "Zahnpasta, Duschgel" | Widerrufen | – |
| `create_list` | "Leg eine Partyliste für REWE an" | `plus` "Liste „Party“ angelegt", Unterzeile "Markt: REWE" | Widerrufen (solange leer), sonst Ansehen | – |
| `rename_list` | "Nenn Party in Grillabend um" | `pencil` "Umbenannt in „Grillabend“", Unterzeile "vorher: Party" | Widerrufen | – |
| `complete_list` (gleicher Abschluss wie in der App, legt Verlaufs-Eintrag an) | "Ich bin fertig mit Einkaufen" | `checkmark.circle` "Einkauf gespeichert", Unterzeile "11 Artikel · Lidl" (mit Modul Angebote: "· ca. 3,20 € gespart, laut Händler"); Erfolgs-Haptik | Widerrufen | Markt unklar: Auswahl "Wo warst du?" mit Markt-Zeilen |
| `delete_item`, `delete_list` | "Lösch die Partyliste" | Rückfrage-Karte (Kapitel 8) | nach Tipp: Artikel mit Widerrufen, Liste ohne | immer |
| neu `start_shopping` | "Starte meinen Einkauf" | öffnet den Einkaufsmodus direkt (Sheet schließt); im Gespräch bleibt `cart` "Einkaufsmodus für Wocheneinkauf" | Ansehen | – |
| neu `import_list_photo` | Foto eines Zettels | Sektion "14 Artikel erkannt" wie das Import-Sheet der App (01 Kap. 5.3), Zeilen abwählbar, "Nicht erkannt" als eigene Sektion; schlicht "Alle hinzufügen"; danach `plus` "14 Artikel zu Wocheneinkauf hinzugefügt" | Widerrufen | Ziel-Liste unklar: Kapitel 7 |
| neu `share_list` | "Lad Lena zur Partyliste ein" | `person.crop.circle.badge.plus` "Einladung zu „Party“", Unterzeile "Link zum Teilen bereit" | schlicht "Teilen …" öffnet das System-Teilen; Avo verschickt nie selbst | – |
| neu `remove_member` | "Nimm Max aus der Partyliste" | Rückfrage-Karte (gilt als endgültig, 00 Kap. 12.34) | – | immer |
| neu `set_store` | "Das ist meine Lidl-Liste" | `storefront` "Markt für Wocheneinkauf: Lidl" | Widerrufen | – |

**Verlauf, Nachkauf, Kosten teilen**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| `get_shopping_history` | "Was habe ich letzten Samstag gekauft?" | Sektion "Einkäufe" mit Zeilen wie Wallet-Transaktionen: `StoreChip` "Lidl", Unterzeile "Sa., 31. Okt. · 14 Artikel", rechts "42,80 €" (`number`, nur wenn erfasst); Tippen klappt Artikel auf; Sektionsfuß schlicht "Alle wieder auf Wocheneinkauf" | – | – |
| `add_history_items_to_list` | "Setz das wieder auf die Liste" | `plus` "12 Artikel zu Wocheneinkauf hinzugefügt", Unterzeile "2 standen schon drauf" | Widerrufen | Ziel unklar: Kapitel 7 (Standard: Kontext-Liste, sonst Liste von heute; heute fest die erste Liste) |
| `get_restock_suggestions` | "Was kaufe ich sonst noch regelmäßig?" | Sektion "Vielleicht auch": `ItemRow` Variante Vorschlag (gestrichelter Kreis mit `plus`), "Milch", Unterzeile "kaufst du etwa alle 6 Tage"; Tippen setzt auf die Liste und wird zur Ergebniszeile | – | – |
| `split_trip_cost` (Modul Kosten teilen) | "Teil den Einkauf vom Samstag mit Lena" | `eurosign.circle` "Einkauf vom 31. Okt. geteilt", Unterzeile "Lena 21,40 € · du 21,40 €" | Widerrufen | Personen unklar: Auswahl-Zeilen mit `Avatar` |

**Rezepte und Kochen**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| `search_recipes`, `get_saved_recipes` | "Was koche ich heute?" | Sektion mit bis zu 3 `RecipeCard` als Zeile (Thumbnail 56 pt, `photo_color` bis das Foto da ist, Titel `headline`, "35 Min · 2 Portionen · 520 kcal"); Fuß schlicht "Mehr Rezepte" (öffnet `/recipes?q=`) | Tippen öffnet das Detail (Sheet schließt) | – |
| `add_recipe_to_list` | "Zutaten für 4 Personen auf die Liste" | wie 4.4: `plus` "9 Zutaten zu Wocheneinkauf hinzugefügt", Unterzeile mit Portionen; ggf. Zeile "2 standen schon drauf" | Widerrufen | Ziel unklar: Kapitel 7 |
| `get_recipe_nutrition` | "Wie viele Kalorien hat das?" | `NutritionRow` (520 kcal, 24 g Protein, 48 g Kohlenhydrate, 26 g Fett), Fußnote "pro Portion, geschätzt" | – | – |
| neu `save_recipe` | "Merk dir das Linsencurry" | `bookmark.fill` "Linsencurry mit Spinat gemerkt" | Widerrufen | – |
| neu `rate_recipe` | "Gib dem Ofenlachs 5 Sterne" | `star` "Ofenlachs mit Zitrone bewertet", Unterzeile "5 von 5" | Widerrufen | – |
| neu `create_recipe_draft` | "Speicher das als Rezept" | `square.and.pencil` "Entwurf „Linsencurry“ gespeichert" | Ansehen (öffnet Rezept-Editor) | – |
| neu `delete_recipe` | "Lösch mein Rezept Nudelsalat" | Rückfrage-Karte | – | immer |
| neu `substitute_ingredient` | "Womit ersetze ich Feta?" | Text plus Zeile `arrow.left.arrow.right` "Feta → Hirtenkäse oder Tofu natur", Fuß "Passt zu deiner Ernährung: vegetarisch" | – | – |
| neu `cooking_step`, `start_timer` (im Kochmodus) | "Nächster Schritt", "Timer auf 10 Minuten" | Schritt springt im Kochmodus; Zeile `timer` "Timer 10:00 läuft" | schlicht "Stoppen" | – |

**Wochenplan (Modul)**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| neu `add_to_plan` | "Ofengemüse am Mittwoch" | `calendar` "Ofengemüse mit Feta am Mi., 11. Nov.", Unterzeile "2 Portionen" | Widerrufen | Tag schon belegt: Auswahl "Dazulegen" / "Ersetzen" |
| neu `fill_plan` (Pro-Kandidat) | "Füll die freien Tage vegetarisch" | Sektion "Wochenplan, 9. bis 15. Nov." mit Tageszeilen (`RecipeCard` als Zeile, Unterzeile "Do, 12. Nov. · 2 Portionen"); darüber `calendar` "4 Tage geplant" | Widerrufen | – |
| neu `plan_to_list` | "Alle Zutaten der Woche auf Wocheneinkauf" | `plus` "17 Zutaten zu Wocheneinkauf hinzugefügt", Unterzeile "zusammengefasst aus 4 Rezepten · 3 standen schon drauf"; Erfolgs-Haptik (00 Kap. 11) | Widerrufen | – |
| neu `get_plan` | "Was gibt's heute?" | eine `RecipeCard`-Zeile "Heute: Ofengemüse mit Feta" | Tippen öffnet | – |

**Angebote (Modul Preise & Angebote, nur Markt der Liste)**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| `search_offers` (ohne "günstigster Markt") | "Ist Milch bei Lidl im Angebot?" | Sektion "Lidl, diese Woche": Zeile mit Kategorie-Symbol 28 pt, "Milbona Frische Vollmilch 3,5 %, 1 l", Unterzeile "laut Händler statt 1,15 € · bis Sa., 14. Nov.", rechts `ItemOfferBadge` "0,99 €" und Glas-freier `plus`-Knopf (44 pt, schlicht, `action`); Tippen auf die Zeile öffnet das Angebots-Sheet (00 Kap. 12.11). Sektionsfuß: "Preise laut Händler, in deiner Region (80331). Quelle: {Angebotsquelle}" | `plus` | – |
| `get_personalized_deals` | "Was ist davon im Angebot?" | `tag` Zeile "4 von 11 Artikeln diese Woche bei Lidl im Angebot", Unterzeile "ca. 3,20 € gespart, in deiner Region"; aufklappbar zu den vier Angebots-Zeilen | Ansehen (öffnet `/offers/list/:id`) | – |
| `get_savings_summary` | "Wie viel habe ich im November gespart?" | `tag` "November: ca. 12,40 € durch Angebote gespart", Unterzeile "laut Händler · 6 Einkäufe" | Ansehen (Verlauf) | – |
| `compare_list_prices` | – | **entfällt** (Plan 8) | – | – |

Regeln: Ohne PLZ zeigt Avo keine Angebote, sondern eine Zeile `location` "Für Angebote in deiner Region: Postleitzahl festlegen" (öffnet das Sheet "Region für Angebote", Teil B). Fragt jemand nach dem günstigsten Markt, antwortet Avo: "Märkte vergleiche ich nicht. Bei Lidl sind diese Woche 4 deiner Artikel im Angebot." Bei aktivem Kill-Switch hat Avo keine Angebots-Werkzeuge und antwortet sachlich "Dazu kann ich gerade nichts sagen." (00 Kap. 15.3), ohne gelbes Schild, ohne Hinweis auf das Modul.

**Kalorien und Gesundheit (Modul)**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| `get_nutrition_status` | "Wie viel darf ich heute noch?" | Zeile mit `ProgressRing` 44 pt (`health`), Titel "640 kcal übrig" (`number`), Unterzeile "1.360 von 2.000 kcal" | Ansehen | – |
| `log_food` (Text oder Foto) | "Trag mein Mittagessen ein" + Foto | Schätzungs-Vorschau (Kapitel 9); nie direkt gespeichert | Bearbeiten / Eintragen | ist selbst die Bestätigung |
| `log_water` | "250 ml Wasser" | `drop` "250 ml Wasser eingetragen", Unterzeile "heute 1,25 von 2 l" | Widerrufen | – |
| `log_weight` | "Ich wiege 78,4 kg" | `scalemass` "78,4 kg eingetragen", Unterzeile "Sa., 7. Nov." | Widerrufen | – |
| neu `log_workout` | "Ich war 30 Minuten joggen" | `figure.run` "Laufen, 30 Min eingetragen", Unterzeile "ca. 310 kcal, geschätzt" | Widerrufen | – |
| `setup_nutrition_goal` | "Ich will abnehmen" | höchstens zwei Fragen pro Nachricht als Auswahl-Zeilen, vorbefüllt aus dem Profil; Ergebnis als Ziel-Vorschau "Neues Ziel: 1.800 kcal am Tag", Unterzeile "bisher 2.000"; schlicht "Übernehmen" | nach Übernehmen: Widerrufen | Ersetzen nur über "Übernehmen" (ersetzt die heutige Textfrage) |
| `get_weekly_nutrition_summary` | "Wie war meine Woche?" | `BarChart` (eine Reihe `health`, Zielmarke gestrichelt), darunter Satz "Diese Woche im Schnitt 1.840 kcal, Ziel 2.000." | Ansehen | – |
| `get_challenge_status` | "Wie läuft meine Challenge?" | `flag` "Wasser-Woche: 4 von 7 Tagen" | Ansehen | – |
| `delete_food_log` | "Lösch das Croissant von heute früh" | Rückfrage-Karte | nach Tipp: Widerrufen | immer |
| neu `sync_health` | "Schreib das auch in Health" | öffnet bei fehlender Erlaubnis die Vorab-Erklärung aus Konzept-Kapitel 15 (Kalorien); Avo setzt nie selbst Berechtigungen | – | – |

**Einstellungen, Module, Profil**

| Werkzeug | Beispiel | Darstellung | Rechts | Rückfrage |
|---|---|---|---|---|
| `update_setting` | "Schalte den Dunkelmodus ein" | Zeile mit dem Symbol der Einstellungsseite (00 Kap. 9.2), "Darstellung: Dunkel", Unterzeile "vorher: System"; Tippen öffnet die Seite | Widerrufen | – |
| `update_setting` Allergien/Ernährung | "Trag eine Erdnussallergie ein" | `leaf` "Allergie eingetragen: Erdnuss", Unterzeile "Rezepte mit Erdnuss werden markiert"; Kern `neutral`, kein Witz. Avo fügt einzelne Einträge hinzu oder entfernt sie, ersetzt nie die ganze Liste | Widerrufen | Entfernen einer Allergie: Rückfrage-Karte, Variante Sicherheit (8.6, Ergänzung E-08) |
| neu `set_module` | "Schalte Kalorien ein" | `switch.2` "Kalorien & Gesundheit eingeschaltet", Unterzeile "Neuer Tab Kalorien"; der Tab erscheint mit `springStandard`, sichtbar nach dem Schließen | Widerrufen | – |
| `update_setting` PLZ | "Meine PLZ ist 80331" | `location` "Region: 80331 München" | Widerrufen | – |
| `get_user_profile`, `get_app_info` | "Was kostet Pro?" | Text; Preise kommen aus StoreKit, Umfang aus `pro_features` (00 Kap. 16.3); Zeile `NavRow` zur passenden Seite ("{pro}", "Hilfe") | Chevron | – |
| nie per Avo | Konto löschen, Abmelden, Abo kaufen oder kündigen, Systemberechtigungen, Nachrichten an andere schicken | Avo öffnet die passende Seite (`NavRow` "Konto", "{pro}", Systemeinstellungen) und sagt, dass man es dort selbst tut | – | – |

### 6.3 Navigation als Antwort

"Öffne die Lidl-Liste", "Zeig mir meine gemerkten Rezepte", "Geh zu den Mitteilungen": Avo führt direkt aus, das Sheet schließt (`springSheet`), das Ziel öffnet sich nach den Regeln aus 01 Kap. 6 (Stapel aufbauen, Zurück zur Tab-Wurzel). Im Gespräch bleibt eine Zeile mit dem Symbol des Ziels und "Wocheneinkauf geöffnet". Keine Haptik.

### 6.4 Beispielinhalt einer Lese-Karte

Frage "Was steht auf Wocheneinkauf?": Sektion mit Titel "Wocheneinkauf" und Zähler "9 offen"; Zeilen "Bananen" (Menge "6"), "Milch" ("2", gelbes Schild "0,99 €"), "Feta" ("200 g"), "Paprika" ("3"), "Zucchini" ("2"), "Vollkornbrot", "Eier" ("10"), "Butter", dann schlicht "Alle 9 ansehen". Avo-Text darunter: "Lena hat vorhin Butter dazugeschrieben."

### 6.5 Zustände aller Karten (gemeinsam)

| Zustand | Verhalten |
|---|---|
| lädt | Kern 20 pt `denkt` an der Stelle des Symbols; die Zeile reserviert ihre Höhe |
| Fehler | Teilfehler-Zeile; ganze Aktion fehlgeschlagen: Fehler-Zeile (4.5) und Fehler-Haptik |
| offline | Werkzeuge, die schreiben, nutzen die Warteschlange der App; die Zeile trägt das Sync-Zeichen, bis gesendet |
| Modul aus | Werkzeuge des Moduls fehlen; fragt man danach, Zeile `switch.2` "Kalorien ist ausgeschaltet" mit schlicht "Einschalten" (schaltet per `set_module`, Ergebniszeile mit Widerrufen) |
| Kill-Switch Angebote | keine Angebots-Karten, keine Erwähnung |
| geteilte Liste | Änderungen erscheinen bei Mitgliedern live wie eigene Änderungen; Mitteilungen gebündelt (K-39) |

### 6.6 Pro-Zeile (Pro gesperrt)

- Aufbau: Symbol der Funktion 20 pt, Titel "Ganze Woche planen" mit `ProBadge`, Unterzeile "Mit {pro} verfügbar", rechts schlicht "Ansehen".
- Tippen auf "Ansehen" oder die Kapsel: Paywall wächst als Sheet aus der Zeile (`springMorph`), mit dieser Funktion oben (`/pro?feature=fill_plan`). Nach dem Kauf führt Avo die ursprüngliche Bitte aus und zeigt die Ergebniszeile (wie 01 Kap. 10.10, Schritt 5).
- Avo erwähnt Pro nur, wenn die Bitte eine Pro-Funktion braucht. Keine Pro-Hinweise in anderen Antworten, keine im Sprachmodus außer der Sperre selbst (16.5 im Fundament).

### 6.7 Änderungen gegenüber heute und betroffene Dateien

Heute acht Karten (`avo_payload_cards.dart`): horizontale Rezeptkarten fest 200 × 140 pt, Listenkarte mit nie gefülltem Abhak-Kreis, Verlauf mit 28-pt-Chips, Auswahl nur 3 Listen, Nährwerte mit Überlauf, Einstellungs-Karte ohne Rückgängig und mit englischen Werten, App-Info englisch. Für Angebote, Kalorien, Löschen, Verschieben, Umbenennen, Liste anlegen gibt es nur Fließtext. Neu: jede Aktion als Ergebniszeile mit Widerrufen, Lese-Ergebnisse in den App-Komponenten, keine festen Größen. Betroffen: `avo_payload_cards.dart` (entfällt; neu `lib/presentation/screens/avo/widgets/avo_result_row.dart`, `avo_result_section.dart`, `avo_estimate_row.dart`, `avo_confirm_card.dart`), `avo_assistant_models.dart` (`AvoPayloadKind` um alle Werkzeuge erweitern, `AvoExpressionType`/`AvoExpression` entfallen), `avo_tool_declarations.dart`, `avo_assistant_service.dart`, `avo_settings_bridge.dart` (deutsche Werte, Einzel-Änderung statt Ersetzen der Allergie-Liste), `avo_app_knowledge.dart` (entfällt, ersetzt durch `pro_features` und `AppBrand`).

### 6.8 Bildbeschreibung für ChatGPT (Gespräch mit mehreren Kartenarten)

iPhone im Hellmodus, Avo-Sheet in großer Höhe, Fläche hellgrau #F2F2F7, oben Glas-Knöpfe X und drei Punkte, mittig "Avo". Eine graue Nutzer-Blase #E9E9EE rechts: "Was ist davon bei Lidl im Angebot?". Darunter eine weiße Sektion #FFFFFF mit 26 pt Ecken: oben eine Zeile mit Preisschild-Symbol, schwarzem Text "4 von 11 Artikeln diese Woche bei Lidl im Angebot" und grauer Unterzeile #636366 "ca. 3,20 € gespart, in deiner Region"; darunter aufgeklappt eine Zeile mit kleinem grauen Tropfen-Symbol, "Milbona Frische Vollmilch 3,5 %, 1 l", Unterzeile "laut Händler statt 1,15 € · bis Sa., 14. Nov.", rechts ein gelbes Preisschild #FFD60A mit dunkler Schrift #1C1C1E "0,99 €" und ein grünes Plus #3F7A1F. Unter der Sektion eine kleine graue Fußzeile "Preise laut Händler, in deiner Region (80331)". Darunter links ohne Blase der schwarze Satz "Feta und Paprika sind auch dabei, die anderen zwei siehst du oben." Am unteren Rand die schwebende Glas-Eingabe mit Kamera, "Frag weiter" und Wellenform. Kein Maskottchen, keine Farbverläufe.

---

## 7. Rückfragen (Auswahl)

**Zweck (Hauptfrage):** Was genau meinst du? Avo fragt nur, wenn das Ziel unklar ist, und bietet die Antworten als antippbare Zeilen an.

**Wann:** mehrere passende Listen ohne Kontext ("Welche Liste?"), Markt beim Abschluss unbekannt ("Wo warst du?"), Wochentag belegt ("Dazulegen oder ersetzen?"), Foto ohne klare Absicht ("Was soll ich damit machen?"), Kalorienziel (höchstens zwei Fragen pro Nachricht).

### 7.1 Aufbau

1. Avo-Text als Frage (`body`): "Auf welche Liste?"
2. `InsetSection` mit Antwort-Zeilen: für Listen `ListRow` (Variante Avo-Rückfrage: Glyph, Name, "9 offen · Lidl", kein Chevron); für Märkte Zeilen mit `StoreChip`; für Personen `Avatar` 28 pt und Name; sonst Symbol plus Text.
3. Letzte Zeile, wo sinnvoll: `plus` "Neue Liste …" (öffnet das Sheet "Neue Liste" mit vorbefülltem Namen, falls genannt) bzw. "Anderer Markt".
4. Alle Listen sind wählbar (heute nur drei): ab 6 Listen die 5 zuletzt geänderten und "Alle Listen anzeigen" (klappt auf).

### 7.2 Beispielinhalt

"Setz Backpapier drauf" ohne Kontext (aus Siri): "Auf welche Liste?" mit "Wocheneinkauf · 9 offen · Lidl", "Drogerie · 4 offen", "Party · 14 offen · REWE", "Neue Liste …".

### 7.3 Zustände, Interaktionen, Haptik

- Tippen auf eine Zeile: Die gewählte Zeile bekommt `checkmark` (`action`) links, die anderen werden `labelTertiary` und nicht mehr antippbar; Avo führt aus, darunter erscheint die Ergebniszeile. Keine Haptik.
- Antwort per Text oder Stimme ("die Lidl-Liste") gilt ebenso.
- Unbeantwortet und das Gespräch geht weiter: Die Rückfrage bleibt antippbar, bis eine neue Frage gestellt wird; danach `labelTertiary` mit Unterzeile "Nicht beantwortet".
- Offline: Zeilen nicht antippbar, `StatusRow` wie 4.5.
- Ab AX1 und 320 pt: `ListRow` stapelt Unterzeile und Avatar-Stapel.
- VoiceOver: "Auswahl, 4 Möglichkeiten"; jede Zeile eine Taste.

### 7.4 Änderungen gegenüber heute

`_PickListView` (`avo_payload_cards.dart:452-494`, höchstens 3 Listen, keine "Neue Liste") entfällt. Rückfragen zu Märkten, Tagen und Fotos gibt es heute nicht.

### 7.5 Bildbeschreibung für ChatGPT

Ausschnitt des hellen Avo-Sheets #F2F2F7. Links ohne Blase in Schwarz die Frage "Auf welche Liste?". Darunter eine weiße Sektion #FFFFFF mit 26 pt Ecken und vier Zeilen, getrennt durch feine Linien #C6C6C8: ein blauer Kreis #007AFF mit weißem Wagen-Symbol und "Wocheneinkauf", graue Unterzeile #636366 "9 offen · Lidl"; ein lila Kreis #AF52DE mit weißer Tasche und "Drogerie", "4 offen"; ein orangefarbener Kreis #FF9500 mit Partyhut-Symbol und "Party", "14 offen · REWE"; als letzte Zeile ein grünes Plus #3F7A1F und grüner Text "Neue Liste …". Keine Pfeile rechts, keine Schatten.

---

## 8. Rückfrage-Karte Löschen (`AvoConfirmCard`)

**Zweck (Hauptfrage):** Soll das wirklich weg? Jedes Löschen über Avo braucht einen Tipp auf diese Karte, auch per Stimme (Plan 12). "Ja" reicht nicht.

**Wann:** `delete_item`, `delete_list`, `delete_food_log`, `delete_recipe`, `remove_member`, Liste verlassen, Einkauf aus dem Verlauf löschen, Kategorie löschen, Challenge abbrechen, Entwurf verwerfen. Außerdem in der Variante Sicherheit beim Entfernen einer Allergie (8.6).

### 8.1 Aufbau (eine Sektion, oben nach unten)

1. Kopfzeile: Symbol `trash` 20 pt in `labelSecondary` (neutral, nicht rot), Titel `headline` `label`: "„Party“ löschen?"
2. Folge (`body`, `label`): "Die Liste und 14 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen." Bei Artikeln stattdessen: "3 Artikel aus Wocheneinkauf löschen?" und Unterzeile (`subheadline`, `labelSecondary`) "Milch, Eier, Gurken" ohne den Satz "nicht rückgängig", weil Artikel danach widerrufbar sind.
3. Zwei Knöpfe (`AppButton`, Größe mittel 44): "Abbrechen" (Grau) links, "Löschen" (Destruktiv gefüllt `danger`, Text `onAction` #FFFFFF) rechts. Ab AX1 und bei 320 pt untereinander, "Löschen" oben, "Abbrechen" darunter.
4. Kein Maskottchen, kein Kern in der Karte; im Sprachmodus steht der Kern auf `neutral`.

### 8.2 Beispielinhalt

Frage "Lösch die Partyliste": Avo schreibt nichts davor. Karte: "„Party“ löschen?" / "Die Liste und 14 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen." / "Abbrechen" · "Löschen".

### 8.3 Zustände

| Zustand | Verhalten |
|---|---|
| wartet | Karte aktiv; der Avo-Kreis zeigt `neutral`, bis sie beantwortet ist |
| gelöscht | Karte klappt zur Ergebniszeile zusammen (`springStandard`): `trash` "Liste „Party“ gelöscht" ohne Aktion; bei Artikeln "3 Artikel gelöscht · Widerrufen" |
| abgebrochen | Ergebniszeile `labelSecondary` "Nicht gelöscht." |
| abgelaufen | nach 10 Minuten oder wenn sich das Objekt geändert hat (z. B. Lena hat einen Artikel ergänzt): Knöpfe deaktiviert, Unterzeile "Diese Rückfrage ist abgelaufen. Frag noch einmal." |
| Fehler | Fehler-Zeile "Das hat nicht geklappt." mit "Erneut versuchen", Fehler-Haptik; nichts gelöscht |
| offline | "Löschen" deaktiviert, `StatusRow` "Offline. Löschen geht erst mit Verbindung." (Löschen läuft nie über die Warteschlange) |
| keine Rechte | erscheint nicht: Darf die Person nicht löschen (z. B. Mitglied einer fremden Liste), sagt Avo das und bietet "Liste verlassen" als eigene Rückfrage-Karte an |

### 8.4 Interaktionen, Haptik, Barrierefreiheit

- Gedrückt: Skalierung 0,97, 90 % Deckkraft beim Berühren. Keine Haptik beim Löschen (00 Kap. 11 sieht keine vor); Fehler-Haptik nur bei Fehlschlag.
- VoiceOver: Karte als Gruppe "Rückfrage: „Party“ löschen? …"; "Löschen" mit Hinweis "Löscht die Liste endgültig". Der Fokus springt beim Erscheinen auf den Titel.
- Sprachmodus: Avo sagt hörbar "Soll ich „Party“ mit 14 Artikeln löschen? Tippe auf Löschen, wenn du sicher bist." Gesprochenes "Ja" oder "Lösch es" beantwortet Avo mit "Dafür brauche ich deinen Tipp auf Löschen." "Nein" oder "Abbrechen" per Stimme gilt dagegen sofort.

### 8.5 Große Schrift und 320 pt

Knöpfe untereinander, volle Sektionsbreite; Text bricht um. Ab AX3 steht die Karte immer vollständig im sichtbaren Bereich (das Sheet scrollt sie beim Erscheinen in Sicht, ohne die Nutzer-Blase zu verdecken).

### 8.6 Variante Sicherheit (Allergie entfernen)

Gleiches Muster, Symbol `exclamationmark.triangle.fill` in `warning`, Titel "Erdnuss aus deinen Allergien entfernen?", Text "Rezepte mit Erdnuss werden dann nicht mehr markiert.", Knöpfe "Abbrechen" und "Entfernen" (Destruktiv gefüllt). Danach Ergebniszeile mit "Widerrufen". Grund: Sicherheitsrelevant (Apple-Prinzip Responsibility), obwohl umkehrbar. Ergänzung E-08, Owner-Frage F-16-4.

### 8.7 Änderungen gegenüber heute

Heute fragt das Modell in festem englischem Text, der Nutzer tippt "ja"; die App prüft nicht, ob er zugestimmt hat, das Modell kann `confirm: true` direkt senden (`avo_assistant_service.dart:1091, 1111`, `avo_system_prompt.dart:62-65`). Neu: Das Modell kann nur einen Lösch-Vorschlag erzeugen; ausgeführt wird erst nach dem Tipp, von der App (Kapitel 15.3).

### 8.8 Bildbeschreibung für ChatGPT

Ausschnitt des hellen Avo-Sheets #F2F2F7. Eine graue Nutzer-Blase #E9E9EE rechts: "Lösch die Partyliste". Darunter eine weiße Sektion #FFFFFF mit 26 pt Ecken, ruhig und ohne Figur: oben ein graues Mülleimer-Symbol #636366 und fett "„Party“ löschen?", darunter in normaler schwarzer Schrift "Die Liste und 14 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen." Unten zwei gleich breite Kapsel-Knöpfe nebeneinander: links hellgrau #E9E9EE mit schwarzem "Abbrechen", rechts rot gefüllt #D70015 mit weißem "Löschen". Keine anderen Farben, kein Grün, kein Maskottchen.

---

## 9. Foto an Avo und Schätzungen

**Zweck (Hauptfrage):** Was soll Avo mit diesem Foto tun? Essen eintragen, einen Zettel in Artikel verwandeln oder aus dem Kühlschrank-Inhalt Rezepte vorschlagen.

**Wann:** `camera` im Feld "Frag Avo", in der Eingabe-Kapsel des Sheets oder im Sprachmodus.

### 9.1 Ablauf und Aufbau

1. `camera` öffnet ein Menü (`AppMenu`, aus dem Knopf): "Foto aufnehmen" (`camera`), "Foto auswählen" (`photo.on.rectangle`).
2. "Foto aufnehmen" öffnet die Systemkamera als Vollbild-Cover (kein eigener Kamera-Screen; Systemmuster vor Eigenbau). "Foto auswählen" öffnet die Systemauswahl (nur ein Bild, ohne Fotomediathek-Freigabe).
3. Zurück im Avo-Sheet (mittel): Nutzer-Blase mit Foto (Ergänzung E-05): Bild 4:3, Breite 200 pt (höchstens 80 % der Breite), `radiusCard`, dekodiert in Anzeigegröße; ein optionaler Text steht darunter in derselben Blase.
4. Avo erkennt die Absicht aus Kontext und Bild. Im Tab Kalorien gilt Essen als gemeint; im Tab Liste ein Zettel; sonst Rückfrage "Was soll ich damit machen?" mit Zeilen `flame` "Als Essen eintragen" (Modul Kalorien), `text.viewfinder` "Artikel auf eine Liste", `fork.knife` "Rezepte daraus".

### 9.2 Schätzungs-Vorschau (`AvoEstimateRow`, Ergänzung E-07)

Eine Sektion, nie direkt gespeichert:
1. Titel `headline`: "Spaghetti Bolognese", Unterzeile `subheadline` `labelSecondary`: "ca. 650 kcal · geschätzt, ca. 80 % sicher".
2. `ValueRow` "Mahlzeit" mit Wert "Mittagessen" (nach Uhrzeit vorausgewählt, Menü zum Ändern).
3. `ValueRow` "Menge" mit Wert "1 Teller, ca. 400 g" (Tippen öffnet das Mengen-Sheet aus Konzept-Kapitel 15).
4. `NutritionRow`: "650 kcal", "28 g Protein", "72 g Kohlenhydrate", "24 g Fett", Fußnote "geschätzt".
5. Knöpfe: "Bearbeiten" (Grau, öffnet das Sheet "Essen eintragen" vorbefüllt) und "Eintragen" (Prominent, Größe mittel). Nur die jüngste offene Vorschau im Gespräch trägt einen gefüllten Knopf; ältere zeigen "Eintragen" schlicht.
6. Nach "Eintragen": Die Sektion klappt zur Ergebniszeile `flame` "Spaghetti Bolognese eingetragen", Unterzeile "Mittagessen · 650 kcal · noch 640 kcal übrig" (Restwert aus dem echten Tagesstand). Rechts "Widerrufen". Mit Apple Health wird auch dort geschrieben.

Beispiel stimmig zu den Durchgangsdaten: Vor dem Mittagessen waren 710 kcal gegessen, 1.290 übrig; nach dem Eintrag 1.360 gegessen, Unterzeile "Mittagessen · 650 kcal · noch 640 kcal übrig".

### 9.3 Zustände

| Zustand | Verhalten |
|---|---|
| lädt | Arbeits-Zeile "Schätzt das Essen" mit Kern `denkt`; das Foto ist schon in der Blase |
| kein Essen erkannt | Text "Ich erkenne darauf kein Essen. Manuell eintragen?" und Zeile `square.and.pencil` "Manuell eintragen" |
| Zettel | Import-Sektion (6.2, `import_list_photo`) |
| Kühlschrank / Zutaten | Text mit erkannten Zutaten ("Ich sehe Zucchini, Feta, Eier und Paprika.") und Rezept-Zeilen |
| Allergen erkannt | eigene Zeile `exclamationmark.triangle.fill` in `warning`: "Enthält vermutlich Erdnuss. Du hast eine Erdnussallergie eingetragen." Warnungs-Haptik einmal; Kern `neutral` |
| offline | Foto bleibt in der Blase mit "Nicht gesendet" und "Erneut senden" |
| Modul Kalorien aus | Zeile "Als Essen eintragen" entfällt; fragt man ausdrücklich, Modul-Zeile (6.5) |
| Kamera-Erlaubnis fehlt | Vorab-Erklärung "Avo braucht die Kamera für dieses Foto." mit "Weiter" / "Nicht jetzt"; abgelehnt: `StatusRow` "Kamera ist aus. In Einstellungen erlauben" |

### 9.4 Bewegung, Haptik, AX, 320 pt

- Foto erscheint mit `fadeReduced` (photo_color nicht nötig, das Bild ist lokal). Keine Haptik beim Senden.
- Ab AX1 und 320 pt: `NutritionRow` 2 × 2, Knöpfe untereinander, Foto volle Blasenbreite.

### 9.5 Änderungen gegenüber heute

Heute kein Foto, kein Anhang im Chat; Essen nur per Text-Schätzung (`log_food`, zweiter Gemini-Aufruf, `avo_assistant_service.dart:1817`). Neu: Foto im Gespräch, Schätzung als Vorschau mit "Eintragen", Absicht über Kontext oder Rückfrage. Betroffen: neue Dateien `avo_estimate_row.dart`, Kamera- und Fotoauswahl über ein vorhandenes oder neues Paket (Teil B), Edge Function für Bilder (Kapitel 15).

### 9.6 Bildbeschreibung für ChatGPT

Helles Avo-Sheet #F2F2F7 in großer Höhe. Rechts eine Nutzer-Blase mit einem appetitlichen Foto eines Tellers Spaghetti Bolognese im Format 4:3 mit 20 pt Ecken, darunter in der grauen Blase #E9E9EE der Text "Mein Mittagessen". Darunter eine weiße Sektion #FFFFFF mit 26 pt Ecken: fett "Spaghetti Bolognese", graue Unterzeile #636366 "ca. 650 kcal · geschätzt, ca. 80 % sicher"; zwei Zeilen "Mahlzeit · Mittagessen" und "Menge · 1 Teller, ca. 400 g" mit grauem Wert rechts; eine Nährwertzeile mit vier Spalten "650 kcal", "28 g Protein", "72 g Kohlenhydrate", "24 g Fett" in runden, halbfetten Ziffern. Unten zwei Knöpfe: hellgrau "Bearbeiten" und avocadogrün gefüllt #3F7A1F mit weißem "Eintragen". Unten am Rand die Glas-Eingabe mit Kamera, "Frag weiter" und Wellenform.

---

## 10. Sprachmodus (`AvoVoiceStage`)

**Zweck (Hauptfrage):** Was sage ich Avo? Sprechen statt tippen; Avo antwortet mit Stimme und zeigt, was er getan hat.

**Wann:** Avo-Kreis halten; `waveform` im Feld "Frag Avo", in der Eingabe-Kapsel des Sheets oder im Einkaufs- und Kochmodus über den Kreis; Siri "Frag Avo", Widget "Avo fragen", Kontrollzentrum, Action Button, `/avo/voice`.

### 10.1 Aufbau (oben nach unten, Sheet groß, feste Fläche `bgGroupedElevated` in Systemdarstellung, K-37)

1. Griff.
2. Statuszeile oben links (`subheadline`, `labelSecondary`), nur bei Bedarf: `StatusRow` (offline, Berechtigung) oder Kontext-Kapsel ("Wocheneinkauf").
3. **Transkript** der Person (`title2` Regular, `label`, linksbündig, höchstens 4 Zeilen; ältere Zeilen blenden nach oben aus mit einem 24-pt-Verlauf). Noch unsichere Wörter in `labelSecondary`, bis die Erkennung sie festlegt.
4. **Avo-Kern 120 pt** mittig (Geometrie: Kern 84 pt, Ring außen 120 pt, Ringstärke 8 pt, Abstand 10 pt; Ergänzung E-03), etwa bei 45 % der Höhe.
5. Zustandstext unter dem Kern, zentriert (`subheadline`, `labelSecondary`): "Hört zu", "Denkt nach", "Spricht · Tippen zum Unterbrechen", "Mikrofon aus".
6. **Avos Antwort** (`title2` Regular, `label`, linksbündig), Wort für Wort im Takt der Stimme; scrollt, wenn länger.
7. **Ergebniszeilen** (Kapitel 6) in einer Sektion direkt über der Steuerung, höchstens zwei sichtbar; ältere fassen sich zu einer Zeile "3 Ergebnisse · Ansehen" zusammen (öffnet nach dem Ende das Gespräch).
8. **Steuerung** unten: eine Glas-Gruppe mit drei 44-pt-Knöpfen, mittig: `mic.slash` (stumm, umschaltbar; gewählt `mic.slash.fill` auf `fill`), `camera` (Foto an Avo, Kapitel 9), `xmark` (Beenden).

### 10.2 Zustände

| Zustand | Kern | Zustandstext | Sonstiges |
|---|---|---|---|
| hört zu | `hoertZu`, Ring folgt der Mikrofon-Lautstärke, Skalierung bis 8 % | "Hört zu" | leichter Impuls beim Beginn; Ansage "Avo hört zu" |
| denkt | `denkt` | "Denkt nach" | Ergebniszeilen erscheinen, sobald Werkzeuge fertig sind |
| spricht | `spricht`, Ring folgt der Sprachausgabe | "Spricht · Tippen zum Unterbrechen" | danach automatisch wieder "hört zu" (abschaltbar, Kapitel 13) |
| stumm | `ruhig` | "Mikrofon aus" | Avo spricht noch zu Ende, hört nicht zu |
| Rückfrage Löschen | `neutral` | "Wartet auf deinen Tipp" | Rückfrage-Karte über der Steuerung (Kapitel 8) |
| Rückfrage Auswahl | `ruhig` | "Hört zu" | Auswahl-Zeilen über der Steuerung; Antwort per Stimme oder Tipp |
| Allergie, Geld, Fehler | `neutral` | wie oben | keine Figur, ruhiger Ton |
| Fehler | `neutral` | – | Avo sagt und zeigt: "Ich höre dich gerade nicht. Prüfe deine Verbindung."; Fehler-Haptik |
| offline | `neutral` | "Offline" | `StatusRow` oben; Spracherkennung auf dem Gerät läuft, das Senden wartet nicht: Transkript bleibt mit "Erneut senden" stehen |
| Berechtigung fehlt | `ruhig` | – | vorher Vorab-Erklärung (Kapitel 11); abgelehnt: `StatusRow` "Mikrofon ist aus. In Einstellungen erlauben" und schlicht "Stattdessen tippen" (öffnet das Sheet mit Tastatur) |
| Pro gesperrt (falls der Sprachmodus Pro wird, F-05) | `ruhig` | "Tippe auf den Kern und sprich." | Mikrofon startet nicht; Tippen auf den Kern lässt die Paywall aus dem Kern wachsen (`springMorph`, `/pro?feature=voice`); echte Vorschau statt Schloss (00 Kap. 16.2) |
| Modul Avo aus | – | – | Modul-Sheet (Kapitel 14) |

### 10.3 Beispielinhalt

Transkript: "Setz Milch, Eier und zwei Gurken auf die Lidl-Liste." Antwort, gesprochen und geschrieben: "Erledigt: drei Artikel auf Wocheneinkauf." Ergebniszeile: `plus` "3 Artikel zu Wocheneinkauf hinzugefügt", Unterzeile "Milch, Eier, Gurken (2)", rechts "Widerrufen". Kontext-Kapsel oben: "Wocheneinkauf" (die Lidl-Liste wurde über den Markt-Chip erkannt).

### 10.4 Interaktionen, Bewegung, Haptik

- **Start durch Halten:** Das Sheet wächst aus dem Kreis (`springSheet`, Ursprung am Kreis), der Kern fliegt aus dem Kreis in die Mitte (`springMorph`). Loslassen sendet nicht und beendet nicht.
- **Ende eines Satzes:** nach ca. 1,0 s Stille; die Erkennung läuft auf dem Gerät, wo verfügbar.
- **Unterbrechen:** Antippen des Kerns stoppt die Sprachausgabe sofort und startet das Zuhören.
- **Beenden:** `xmark`, Wischen nach unten, Zwei-Finger-Z. Wurde der Sprachmodus aus dem Sheet gestartet, schrumpft er zurück ins Gespräch (Sheet mittel, alle Runden als Text mit ihren Ergebniszeilen); sonst schließt er, der Screen ist wieder frei, und Änderungen erscheinen dort als `UndoToast`.
- **Sprache der Stimme:** App-Sprache; Stimme aus den Avo-Einstellungen. Andere Audioausgabe (Musik) wird während Avos Antwort leiser gestellt und danach wieder lauter.
- **Bildschirm bleibt an**, solange der Sprachmodus offen ist. Geht die App in den Hintergrund, endet der Sprachmodus; das Gespräch bleibt.
- **Vorlesen:** Avo liest Ergebnisse kurz vor: höchstens fünf Artikel, bei Rezepten nur das erste mit Zeit ("Ich habe drei Rezepte gefunden. Das erste: Ofengemüse mit Feta, 35 Minuten."). Preise mit "laut Händler".
- **Haptik:** leichter Impuls, wenn das Zuhören beginnt (00 Kap. 11); Fehler-Haptik bei Fehlern; Erfolgs-Haptik nur für die Erfolgs-Ereignisse aus 00 Kap. 11.
- **Reduce Motion:** Kern nur über Helligkeit, keine Größe; Übergänge als Überblendung; Transkript ohne Verlauf-Ausblenden, ältere Zeilen springen nach oben ohne Bewegung.
- **VoiceOver:** Ansage "Avo hört zu"; Transkript und Antwort als Live-Region. Mit VoiceOver kein automatisches Satzende: nach dem Sprechen "Zum Senden doppeltippen" auf dem Kern (00 Kap. 12.33). Avos Sprachausgabe pausiert, solange VoiceOver spricht.

### 10.5 Große Schrift und 320 pt

- Bis xxxL wie beschrieben. Ab AX1: Transkript und Antwort teilen sich einen scrollenden Bereich, je höchstens 3 sichtbare Zeilen.
- Ab AX3 (und bei weniger als 700 pt Höhe, z. B. iPhone SE): Kern 64 pt, oben links neben dem Zustandstext (Ergänzung E-03); darunter ein scrollender Bereich mit Transkript und Antwort; Ergebniszeilen stapeln.
- Steuerung bleibt 3 × 44 pt (Large Content Viewer ab AX1). Bei 320 pt keine Änderung der Steuerung; Text bricht um.

### 10.6 Änderungen gegenüber heute

Einen Sprachmodus gibt es heute nicht, auch nicht halb: Kein Paket für Spracherkennung oder Sprachausgabe in `pubspec.yaml`; `voice_assistant_service.dart` und `ios/Runner/VoiceAssistantPlugin.swift` existieren nicht mehr (CLAUDE.md ist dort veraltet). Neu: `lib/presentation/screens/avo/avo_voice_stage.dart`, `widgets/avo_core.dart` (Kern als Flutter-Widget mit Zuständen; dasselbe Enum wie der Kanal der Tab-Bar), ein Sprachdienst (Teil B): Spracherkennung über Apples Speech-Framework (auf dem Gerät, wo verfügbar), Sprachausgabe über `AVSpeechSynthesizer` mit Pegel-Werten für den Ring, beides über einen eigenen Kanal `shoply/voice` (Ergänzung E-10). Info.plist: Texte für Mikrofon und Spracherkennung (DE/EN, 01 Kap. 5.10).

### 10.7 Bildbeschreibung für ChatGPT

Ganzes iPhone im Hellmodus, ein Sheet in voller Höhe mit hellgrauer Fläche #F2F2F7, oben ein kleiner grauer Griff und eine graue Kapsel #E9E9EE mit blauem Listen-Punkt und "Wocheneinkauf". Darunter linksbündig in großer, ruhiger Systemschrift (22 pt, normal) schwarz #000000: "Setz Milch, Eier und zwei Gurken auf die Lidl-Liste." In der Mitte eine große Kugel 120 pt: innen warmes Kern-Braun #7A4A24 mit weichem Glanz oben links, außen ein dicker hellgrüner Ring #C9DE6E, der leicht pulsiert, ohne Gesicht. Darunter klein und grau #636366 "Spricht · Tippen zum Unterbrechen". Darunter linksbündig groß in Schwarz "Erledigt: drei Artikel auf Wocheneinkauf." Darunter eine weiße Sektion #FFFFFF mit 26 pt Ecken: Plus-Symbol, "3 Artikel zu Wocheneinkauf hinzugefügt", graue Unterzeile "Milch, Eier, Gurken (2)", rechts grün #3F7A1F "Widerrufen". Ganz unten mittig eine schwebende Liquid-Glass-Gruppe mit drei runden Knöpfen: durchgestrichenes Mikrofon, Kamera, X.

---

## 11. Vorab-Erklärung Mikrofon und Spracherkennung

**Zweck (Hauptfrage):** Darf Avo zuhören? Erklärt in einem Satz, bevor iOS fragt (00 Kap. 13).

**Wann:** beim ersten Start des Sprachmodus, wenn die Erlaubnis noch nicht erteilt ist.

### 11.1 Aufbau (Sheet mittel, Glas in Teilhöhe, Inhalt auf `surfaceElevated`)

1. Symbol `waveform` 48 pt Light, `label`, oben mittig.
2. Titel `title3`: "Sprich mit Avo".
3. Satz `body` `label`: "Deine Stimme wird auf dem iPhone in Text umgewandelt und nur für diese Anfrage verwendet." (gilt, wenn die Erkennung auf dem Gerät läuft; sonst "… von Apple in Text umgewandelt …", Text richtet sich nach der Technik, F-16-2).
4. Prominent "Weiter" (löst nacheinander die Systemabfragen Mikrofon und Spracherkennung aus), schlicht "Nicht jetzt".

Zustände: abgelehnt (siehe 10.2); nur eine der zwei Erlaubnisse erteilt: wie abgelehnt mit passendem Text. AX: Symbol entfällt ab AX3, Knöpfe untereinander ab AX1. 320 pt: Umbruch. Keine Haptik. Neu, ersetzt nichts.

### 11.2 Bildbeschreibung für ChatGPT

Helles iPhone, unten ein schwebendes Sheet über ein Drittel der Höhe aus Liquid Glass mit großen, zum Gerät passenden Ecken. Oben mittig ein dünnes schwarzes Wellenform-Symbol 48 pt, darunter halbfett "Sprich mit Avo", darunter ein Satz in normaler schwarzer Schrift "Deine Stimme wird auf dem iPhone in Text umgewandelt und nur für diese Anfrage verwendet." Darunter ein breiter avocadogrüner Kapsel-Knopf #3F7A1F mit weißem "Weiter" und darunter grüner Text "Nicht jetzt". Dahinter unscharf die Liste "Wocheneinkauf".

---

## 12. "So arbeitet Avo" (erste Nutzung)

**Zweck (Hauptfrage):** Was sieht und darf Avo? Einmal vor der ersten Frage, damit niemand überrascht ist (Apple-Prinzip Responsibility; Gesundheitsdaten nur mit Einwilligung).

**Wann:** genau einmal pro Konto, beim ersten Senden einer Frage (Text, Vorschlag, Stimme oder Foto). Die Frage wird danach gesendet.

### 12.1 Aufbau (Sheet mittel, Inhalt auf `surfaceElevated`)

1. Kopf: Titel "So arbeitet Avo" (Variante Sheet, `xmark` links schließt ohne zu senden).
2. `InsetSection` mit drei Zeilen (Symbol 22 pt `label` frei, Titel `headline`, Satz `subheadline` `labelSecondary`):
   - `checklist` "Kennt, was du in {app} hast": "Listen, Rezepte, Wochenplan und Einstellungen, damit die Antworten passen."
   - `hand.raised` "Ändert nur mit deinem Konto": "Avo darf nur, was du auch darfst. Änderungen lassen sich widerrufen, Löschen nur nach deinem Tipp."
   - `exclamationmark.circle` "Kann sich irren": "Schätzungen sind als geschätzt markiert. Prüfe Allergene immer auf der Verpackung."
3. `ToggleRow` "Ernährung und Allergien einbeziehen" (Standard aus), Unterzeile "Dann schlägt Avo passende Rezepte vor und warnt im Gespräch." Mit Modul Kalorien eine zweite `ToggleRow` "Kalorien, Gewicht und Ziele einbeziehen" (Standard aus).
4. Sektionsfuß: "Avo nutzt Claude von Anthropic. Deine Fragen werden über unseren Server weitergeleitet. Datenschutz" ("Datenschutz" schlicht).
5. Prominent "Weiter".

### 12.2 Zustände und Verhalten

- Allergien werden beim Suchen von Rezepten immer beachtet, auch wenn der Schalter aus ist (die Filterung läuft in den Werkzeugen, nicht im Modell; Kapitel 15.4). Der Schalter bestimmt nur, ob Avo sie im Gespräch kennt.
- Offline: "Weiter" bleibt möglich; die Frage geht in den Offline-Zustand (4.5).
- AX: Symbole entfallen ab AX3; Schalter-Zeilen stapeln. 320 pt: Umbruch.
- Haptik keine. Bewegung `springSheet`.
- Änderbar jederzeit in den Avo-Einstellungen (Kapitel 13).

### 12.3 Änderungen gegenüber heute

Heute gehen Allergien, Diät, Name, Gewicht und Ziele ohne Hinweis bei jeder Kontextänderung an Gemini (Inventar 4, Sicherheit). Neu: einmalige Erklärung, Gesundheitsangaben nur mit Einwilligung, jederzeit widerrufbar.

### 12.4 Bildbeschreibung für ChatGPT

Helles iPhone mit einem schwebenden Sheet über die halbe Höhe, Kopf mit Glas-Knopf X links und mittig fett "So arbeitet Avo". Darin eine weiße Sektion #FFFFFF mit 26 pt Ecken und drei Zeilen mit schwarzen, frei stehenden Symbolen (Checkliste, erhobene Hand, Ausrufezeichen im Kreis), je mit fettem Titel "Kennt, was du in Avo hast", "Ändert nur mit deinem Konto", "Kann sich irren" und grauem Satz #636366 darunter. Darunter eine zweite weiße Zeile "Ernährung und Allergien einbeziehen" mit einem ausgeschalteten grauen Schalter rechts. Darunter kleine graue Fußzeile über Claude von Anthropic mit grünem Link "Datenschutz" #3F7A1F. Unten ein breiter avocadogrüner Kapsel-Knopf mit weißem "Weiter".

---

## 13. Avo-Einstellungen (`/settings/avo`)

**Zweck (Hauptfrage):** Wie soll Avo sprechen, und was darf er einbeziehen?

**Wann:** Profil und Einstellungen > Avo (nur Modul Avo an); Avo-Sheet `ellipsis` > "Avo-Einstellungen"; Suche ("Stimme", "Avo", "vorlesen").

### 13.1 Aufbau (Push im Profil-Sheet, `LargeTitleNavBar` mit großem Titel "Avo")

1. **Stimme:** `NavRow` "Stimme" mit Wert "Anna (Premium)" (Auswahl aus den installierten Systemstimmen der App-Sprache, mit Probehören; Hinweis-Fußnote "Weitere Stimmen in den iPhone-Einstellungen unter Bedienungshilfen > Gesprochene Inhalte"); `ToggleRow` "Antworten im Chat vorlesen" (aus); `ToggleRow` "Nach der Antwort weiter zuhören" (an, Sprachmodus).
2. **Was Avo einbeziehen darf:** `ToggleRow` "Ernährung und Allergien"; `ToggleRow` "Kalorien, Gewicht und Ziele" (nur Modul Kalorien). Sektionsfuß: "Allergien beachtet {app} beim Suchen immer. Diese Schalter bestimmen nur, ob Avo sie im Gespräch kennt."
3. **Gespräch:** `ValueRow` "Gespeichert" mit "24 Stunden, nur auf diesem iPhone"; destruktive Zeile "Gespräch löschen" (`confirmDestructive`: "Gespräch löschen?" / "Der Verlauf mit Avo wird von diesem iPhone gelöscht." / "Abbrechen", "Löschen").
4. **Fuß:** `footnote` "Avo nutzt Claude von Anthropic." und schlicht "Datenschutz".

Zustände: lädt nichts (lokal); Stimmen-Liste leer (keine deutsche Stimme installiert): Zeile "Systemstimme" mit Fußnote; Modul aus: Seite nicht erreichbar, Route öffnet das Modul-Sheet. Pro: falls der Sprachmodus Pro wird, tragen "Nach der Antwort weiter zuhören" und "Stimme" kein `ProBadge` (Einstellungen sind keine Werbefläche); der Sprachmodus selbst zeigt die Sperre. AX und 320 pt: Standardverhalten der Einstellungszeilen (00 Kap. 12.22). Haptik: keine.

Heute: keine Avo-Einstellungen; "Avo-Erinnerungen" stehen in den Mitteilungs-Einstellungen (`notifications_screen.dart:127-136`) und wandern in den Kern (Mitteilungen > Listen, 01 Kap. 5.6). Neu: `lib/presentation/screens/avo/avo_settings_screen.dart` (Teil B), Zeile im Profil-Sheet (Teil A, Slot).

### 13.2 Bildbeschreibung für ChatGPT

Helles iPhone, Einstellungsseite im Sheet mit großem Titel "Avo" und Glas-Zurück-Knopf oben links, Hintergrund #F2F2F7. Erste weiße Sektion #FFFFFF mit 26 pt Ecken unter dem Sektionstitel "Stimme" in halbfetter schwarzer Schrift: Zeile "Stimme" mit grauem Wert "Anna (Premium)" und Pfeil, Zeile "Antworten im Chat vorlesen" mit grauem Schalter aus, Zeile "Nach der Antwort weiter zuhören" mit avocadogrünem Schalter an #3F7A1F. Zweite Sektion "Was Avo einbeziehen darf" mit zwei Schalter-Zeilen, darunter graue Fußnote #636366. Dritte Sektion "Gespräch" mit "Gespeichert · 24 Stunden, nur auf diesem iPhone" und einer roten Zeile #D70015 "Gespräch löschen". Keine Icons in getönten Quadraten.

---

## 14. Modul Avo aus

**Zweck (Hauptfrage):** Will ich Avo einschalten? (nur beim direkten Aufruf); sonst: Wo suche ich?

### 14.1 Verhalten

- Der Kreis zeigt `magnifyingglass` und heißt "Suchen". Tippen öffnet das Feld im Zustand `askAvo` mit Platzhalter "Suchen", ohne `camera` und `waveform`, Return-Taste "Suchen"; Panel nur mit Such-Sektionen (01 Kap. 9), ohne "Gespräch fortsetzen", Vorschläge und "Frag Avo"-Zeile. Halten tut nichts außer dem Large Content Viewer ab AX1.
- Nirgends sonst Avo: keine Avo-Einstellungen, keine Siri-Sätze zu Avo, das Widget "Avo fragen" zeigt einen ruhigen Satz.
- Gespräch und Einstellungen bleiben gespeichert (00 Kap. 15.2); Hintergrund-KI (Kategorien, Zettel importieren) läuft weiter, weil sie Kern ist.
- Wird das Modul ausgeschaltet, während das Avo-Sheet offen ist: Sheet schließt (`springSheet`), der Kreis wechselt zur Lupe (Überblendung des Symbols, `fadeReduced`).

### 14.2 Modul-Sheet "Avo ist ausgeschaltet" (Sheet mittel)

Für `/avo`, `/avo/voice`, `shoply://avo`, Siri "Frag Avo", Widget "Avo fragen", Steuerelement. Aufbau: Kern 44 pt `ruhig` (statt Maskottchen; der Assistent hat kein Gesicht), Titel `title3` "Avo ist ausgeschaltet", Satz `body` "Avo erledigt Listen, Rezepte und mehr für dich, per Text oder Stimme.", prominent "Einschalten", schlicht "Nicht jetzt". "Einschalten" schaltet das Modul, schließt das Sheet und öffnet direkt das Avo-Sheet bzw. den Sprachmodus. AX: Kern entfällt ab AX1, Knöpfe untereinander.

### 14.3 Änderungen gegenüber heute

Heute lässt sich Avo nicht abschalten. Neu: Modul `AppModule.avo` (Teil A, `lib/core/modules/app_modules.dart`), Abfrage in Tab-Bar, Routen, Siri-Intents (`ios/Runner/AppIntents.swift`) und Widget.

### 14.4 Bildbeschreibung für ChatGPT

Helles iPhone, unten eine schwebende Liquid-Glass-Tab-Bar mit zwei Tabs "Liste" und "Rezepte" und rechts abgesetzt ein Glas-Kreis mit einer schwarzen Lupe statt des Avocado-Kerns. Darüber schwebt ein Sheet über ein Drittel der Höhe aus Glas mit einer kleinen braunen Kugel #7A4A24 mit hellgrünem Ring #C9DE6E, darunter halbfett "Avo ist ausgeschaltet", ein Satz in Schwarz, ein avocadogrüner Kapsel-Knopf #3F7A1F "Einschalten" und grüner Text "Nicht jetzt".

---

## 15. Verantwortung und Technik

Gilt für alle Teile dieses Kapitels. Besitz Teil B, außer wo genannt.

### 15.1 Modell und Server (Plan 7)

- Alle Avo-Aufrufe laufen über eine Supabase Edge Function `avo` (Schlüssel nicht in der App; heute `Env.geminiApiKey` im Client). Starkes Claude-Modell für Gespräch und Fotos (Wahl nach Qualitätstest, Verbesserungsliste 8). Antwort als Datenstrom (Server-Sent Events): Textteile, Werkzeug-Aufrufe, Ende.
- Die Edge Function prüft das Supabase-JWT der Person, setzt ein Nutzungslimit pro Person und Tag (Zahl legt der Owner fest) und protokolliert nur Zählwerte, keine Inhalte.
- Der System-Prompt kommt aus `AppBrand` und `pro_features` (00 Kap. 3.1, 16.3), deutsch und englisch, ohne "Shoply", ohne Dollar, ohne Marktvergleich.

### 15.2 Rechte der Person

- Werkzeuge werden **in der App** mit der Sitzung der angemeldeten Person ausgeführt (Repositories von Teil A, Supabase mit RLS). Das Modell sieht nur Ergebnisse. Damit kann Avo genau das, was die Person darf, und nichts darüber hinaus.
- Bei Kontowechsel werden Gespräch, Kontext und Modell-Sitzung verworfen (heute schon in `avo_assistant_service.dart:105-111`, beibehalten).
- Nie per Avo: Konto löschen, Abmelden, Käufe und Abos, Systemberechtigungen, Nachrichten an andere senden (6.2).

### 15.3 Löschen nur nach Tipp (technisch erzwungen)

- Das Modell hat keine Werkzeuge, die löschen. Es hat `propose_delete(target)`; die App prüft Rechte und Objekt, erzeugt eine Rückfrage-Karte mit einem Einmal-Schlüssel (gültig 10 Minuten, an Objekt und Version gebunden) und gibt dem Modell nur "wartet auf Bestätigung" zurück.
- Erst der Tipp auf "Löschen" führt das Löschen in der App aus; das Modell erfährt das Ergebnis danach. Gesprochene Zustimmung hat keinen Weg zur Ausführung.

### 15.4 Allergien und Gesundheit

- Rezeptsuche filtert Allergene aus dem Profil **immer** in den Werkzeugen, unabhängig davon, was das Modell übergibt, mit Abgleich über deutsche Komposita und Mehrzahl ("Nüsse" findet "Haselnuss"); heute nur, wenn das Modell `exclude_allergens` übergibt, per Teilstring.
- Allergien und Ernährung werden nur einzeln hinzugefügt oder entfernt, nie als ganze Liste ersetzt; Entfernen über die Rückfrage-Karte (8.6).
- Gesundheitsangaben gehen nur mit Einwilligung ans Modell (Kapitel 12).
- Antworten mit Allergie-Bezug: Kern `neutral`, `warning`-Zeile mit Symbol, Satz ohne Witz ("Enthält Erdnuss. Du hast eine Erdnussallergie eingetragen.").

### 15.5 Kontext und Gedächtnis

- Kontext pro Frage: der Screen, von dem man kommt (Tabelle 5.2), plus Liste von heute, Liste der Listen (Name, ID, Markt, offene Anzahl), Module und Pro-Status. Artikel nur der Kontext-Liste, nicht der ersten drei Listen. Gesendet nur bei Änderung.
- Ein Gesprächsspeicher (lokal, 24 Stunden) ist die einzige Quelle für Oberfläche und Modell-Verlauf; Kürzung nur an ganzen Nutzer-Runden, damit Werkzeug-Paare zusammenbleiben (heute in `avo_assistant_service.dart:130-146`, beibehalten).
- Mehrere Änderungen einer Antwort werden gebündelt geschrieben (ein Push, ein "gelesen"-Vermerk, `_afterBulkListChange`), nicht Artikel für Artikel (heute bei `add_recipe_to_list` und `add_history_items_to_list` einzeln).

### 15.6 Widerrufen technisch

Jede ändernde Werkzeug-Ausführung speichert ihre Gegen-Aktion (z. B. "diese 9 Artikel-IDs entfernen", "Einstellung X auf Wert Y zurück") und die Version der betroffenen Daten. "Widerrufen" prüft die Version; ist sie verändert, zeigt die Zeile "Inzwischen geändert".

---

## 16. Abläufe

### 16.1 Frage per Text aus der Liste

1. Tab Liste, "Wocheneinkauf". Daumen tippt auf den Avo-Kreis.
2. Kreis morpht zum Feld "Frag Avo oder suche", Tastatur offen, Panel mit drei Vorschlägen.
3. Eingabe "Zutaten für Ofengemüse mit Feta für 4 Personen", Return.
4. Avo-Sheet mittel steigt auf, Frage als Blase oben, Kontext-Kapsel war "Wocheneinkauf". Arbeits-Zeile "Sucht Rezept", dann "Schreibt auf Wocheneinkauf".
5. Hinter dem Sheet wachsen neun Zeilen in der Liste ein. Im Sheet: Ergebniszeile "9 Zutaten zu Wocheneinkauf hinzugefügt · Widerrufen", Zeile "2 standen schon drauf", mit Modul Angebote "3 davon bei Lidl im Angebot". Danach ein Satz.
6. Wischen nach unten schließt; die Tab-Bar kommt zurück.

### 16.2 Unklares Ziel

1. Siri "Frag Avo" > "Setz Backpapier drauf".
2. Avo-Sheet öffnet über der Liste von heute; da Siri keinen Screen-Kontext liefert: "Auf welche Liste?" mit allen Listen und "Neue Liste …".
3. Tipp auf "Drogerie": Häkchen an der Zeile, Ergebniszeile "Backpapier zu Drogerie hinzugefügt · Widerrufen".

### 16.3 Löschen mit Rückfrage (Text und Stimme)

1. "Lösch die Partyliste."
2. Rückfrage-Karte "„Party“ löschen?" mit Folge; der Kreis zeigt `neutral`.
3. Im Sprachmodus sagt Avo dazu hörbar, dass ein Tipp nötig ist; "Ja" führt nicht aus.
4. Tipp auf "Löschen": Karte wird zur Zeile "Liste „Party“ gelöscht". Die Liste verschwindet aus Titelmenü und Alle Listen; war sie die Liste von heute, gilt 01 Kap. 2.2 Regel 1.
5. Abbrechen: Zeile "Nicht gelöscht."

### 16.4 Sprachmodus aus dem Einkaufsmodus

1. Im Einkaufsmodus Avo-Kreis halten. Leichter Impuls, Sheet wächst aus dem Kreis, "Hört zu".
2. "Hak Milch und Butter ab und setz Backpapier dazu."
3. Kern denkt, dann spricht: "Erledigt. Backpapier steht unter Haushalt." Zeilen "2 Artikel abgehakt · Widerrufen" und "Backpapier zu Wocheneinkauf hinzugefügt · Widerrufen".
4. Avo hört weiter zu; `xmark` beendet. Der Einkaufsmodus zeigt "2 von 11" mehr abgehakt (rollende Ziffern), die Zeilen sind nach "Im Wagen" gewandert.

### 16.5 Essen per Foto

1. Tab Kalorien, Kreis tippen, `camera` > "Foto aufnehmen", Systemkamera, Foto.
2. Sheet mittel: Foto-Blase, Arbeits-Zeile "Schätzt das Essen".
3. Schätzungs-Vorschau "Spaghetti Bolognese · ca. 650 kcal · geschätzt". Menge korrigieren: "Menge" > 300 g, Werte rollen.
4. "Eintragen": Zeile "Spaghetti Bolognese eingetragen · Widerrufen"; nach dem Schließen rollt im Tab "640 kcal übrig", der Ring folgt.

### 16.6 Einstellung ändern und widerrufen

1. "Schalte Kalorien ein."
2. Zeile "Kalorien & Gesundheit eingeschaltet · Widerrufen", Unterzeile "Neuer Tab Kalorien".
3. Sheet schließen: Der Tab Kalorien blendet in der Tab-Bar ein (`springStandard`).
4. Sheet wieder öffnen ("Gespräch fortsetzen"), "Widerrufen": Tab blendet aus; steht man darauf, landet man auf Liste.

### 16.7 Pro-Funktion

1. Tab Plan, "Füll die freien Tage vegetarisch."
2. Ist `fill_plan` Pro: Zeile "Ganze Woche planen" mit `ProBadge`, "Mit {pro} verfügbar · Ansehen".
3. "Ansehen": Paywall wächst aus der Zeile, Funktion oben. Kauf erfolgreich: Paywall schließt, Avo führt aus, Zeile "4 Tage geplant · Widerrufen".
4. Abbruch: nichts passiert, das Gespräch bleibt.

### 16.8 Offline

1. Im Funkloch im Markt, Kreis tippen: Panel zeigt `StatusRow` und nur lokale Treffer.
2. Return mit "Was fehlt noch?": Sheet mit `StatusRow` "Offline. Avo braucht eine Verbindung.", Frage als Blase "Nicht gesendet · Erneut senden".
3. Wieder online: Nichts passiert automatisch. Tipp auf "Erneut senden" schickt die Frage.

### 16.9 Erste Nutzung

1. Erstes Tippen auf einen Vorschlag.
2. Sheet "So arbeitet Avo"; Schalter "Ernährung und Allergien einbeziehen" einschalten; "Weiter".
3. Avo-Sheet mit der Frage; die Antwort läuft.

---

## 17. Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| F-16-1 | Gibt es ein Tageslimit für Avo-Fragen, und hebt Pro es auf? | Ja, großzügiges Limit für alle (z. B. 30 Fragen am Tag) gegen Missbrauch und Kosten; ob Pro es aufhebt, entscheidet der Owner mit F-05 |
| F-16-2 | Spracherkennung und Stimme: nur Apple auf dem Gerät (`SFSpeechRecognizer`, `AVSpeechSynthesizer`), oder eine Cloud-Stimme für natürlicheren Klang? | Apple auf dem Gerät: kein weiterer Datenempfänger, offline erkennbar, kostenlos; Cloud-Stimme später prüfen |
| F-16-3 | Wird der Sprachmodus Pro (F-05)? | Kandidat; die Bühne ist so gebaut, dass beides geht (10.2) |
| F-16-4 | Soll das Entfernen einer Allergie über Avo eine Rückfrage-Karte bekommen (8.6), obwohl es umkehrbar ist? | Ja, Sicherheit vor Bequemlichkeit |
| F-16-5 | Rechtliche Prüfung: Einwilligung für Gesundheitsangaben (Allergien, Gewicht) an Anthropic nach DSGVO Art. 9; Text für Datenschutz und App-Store-Datenschutzangaben; Zusage, dass API-Daten nicht zum Training genutzt werden | vor dem Start durch den Owner klären; bis dahin Schalter in Kapitel 12 standardmäßig aus |
| F-16-6 | Darf Avo im Gespräch auch Mitglieder einer geteilten Liste ändern lassen, z. B. "Setz das auf Lenas Liste"? | Nur Listen, in denen die Person Mitglied ist (RLS); nie Listen anderer ohne Mitgliedschaft |
| F-16-7 | Soll das Gespräch zwischen Geräten (zwei iPhones mit demselben Konto) synchron sein? | Nein, lokal und 24 Stunden; weniger gespeicherte Daten |
| F-16-8 | Soll "Antworten im Chat vorlesen" standardmäßig aus sein? | Ja; der Sprachmodus spricht immer |

---

## 18. Ergänzungen zum Fundament

Diese Punkte fehlen in `00-grundlagen.md` bzw. `01-navigation-und-struktur.md` oder weichen bewusst ab. Teil A entscheidet über die Aufnahme ins Fundament; bis dahin gelten sie für diesen Bereich.

| Nr. | Ergänzung | Bezug | Grund |
|---|---|---|---|
| E-01 | **Avo-Sheet ist in beiden Höhen eine feste Fläche** (`bgGroupedElevated`, schwebend mit 8 pt Abstand und `radiusSheet` in mittel), abweichend von 00 Kap. 8.1 "Sheets in Teilhöhe: Glas". Glas sind nur Sheet-Kopf und Eingabe-Kapsel. Tab-Bar und Accessory werden bei offenem Avo-Sheet aus dem Baum genommen (wie 00 Kap. 8.4 für das Accessory). | 00 Kap. 8.1, 8.2, 8.4, 8.5 | kein Glas auf Glas für die Eingabe; ruhige Lesefläche beim Streaming; Glas-Budget 3 (1.4) |
| E-02 | **`AskPanel`**: Vorschlags- und Suchfläche über dem Feld "Frag Avo" im Stil des Vorschlags-Panels aus 00 Kap. 12.4 (`surfaceElevated`, `radiusCard`, `shadowFloat`); wächst ab drei Zeichen auf volle Höhe. Teil A baut das Panel (Such-Sektionen), Teil B liefert die Avo-Zeilen ("Gespräch fortsetzen", Vorschläge, "Frag Avo"). | 00 Kap. 12.1, 12.25; 01 Kap. 9 | Ort der globalen Suchergebnisse ist im Fundament nicht festgelegt |
| E-03 | **`AvoCore` als Flutter-Widget** in den Größen 20 pt (Arbeits-Zeile, Ergebniszeile lädt), 44 pt (leerer Chat, Modul-Sheet), 64 pt (Sprachmodus ab AX3 bzw. unter 700 pt Höhe), 120 pt (Sprachmodus). Geometrie: Kern 70 % des Durchmessers, Ringstärke 6,7 %, Abstand Kern zu Ring Rest; ab 44 pt weicher Glanz oben links auf dem Kern. Das Fundament nennt nur 22 pt (Symbol) und 120 pt. | 00 Kap. 3.4, 12.33 | einheitlicher Kern an allen Stellen |
| E-04 | **`AvoStatusLine`**: Arbeits-Zeile mit Kern 20 pt `denkt`, Text des aktuellen Schritts (`subheadline`, `labelSecondary`) und schlicht "Stopp". | 00 Kap. 12.32, 13 | ersetzt Tipp-Punkte; zeigt, was Avo gerade liest (Vertrauen) und erlaubt Abbruch |
| E-05 | **`UserBubble` mit Foto**: Bild 4:3, Breite 200 pt (höchstens 80 %), `radiusCard`, Text darunter in derselben Blase; Zustand "Nicht gesendet" mit "Erneut senden". | 00 Kap. 12.32 | Foto an Avo |
| E-06 | **`ContextChip`**: Kapsel `fill` mit Glyph oder Symbol, Name (`subheadline`), `xmark` 13 pt, Mindesthöhe 32, Trefferfläche 44; über der Avo-Eingabe und im Sprachmodus. | 01 Kap. 3 ("kennt den Kontext") | Wayfinding: Man sieht, worauf sich Avo bezieht, und kann es lösen |
| E-07 | **`AvoResultRow` erweitert:** Zustände "wird ausgeführt", "Rückgängig gemacht", "Inzwischen geändert", Teilfehler, ausstehend offline; aufklappbare Einzelheiten; Regel für die rechte Aktion (Widerrufen, sonst Ansehen). Neue Varianten: Pro-Zeile (6.6), Schätzungs- und Ziel-Vorschau `AvoEstimateRow` (9.2, 6.2 Kalorienziel). | 00 Kap. 12.32 | alle Werkzeug-Ergebnisse abbilden |
| E-08 | **`AvoConfirmCard` Variante Sicherheit** (Allergie entfernen) mit `warning`-Symbol; sowie Knopfreihenfolge untereinander ("Löschen" oben) und Zustand "abgelaufen". Das Fundament sieht die Karte "nur für Löschen" vor. | 00 Kap. 12.32, 12.34 | Responsibility; F-16-4 |
| E-09 | **Weitere SF Symbols** für die Tabelle 00 Kap. 9.2: `arrow.right` (verschieben), `star` (bewerten), `photo.on.rectangle` (Foto auswählen), `mic.slash.fill` (stumm, gewählt), `speaker.wave.2` (vorlesen), `gearshape` (Avo-Einstellungen im Menü), `square.and.pencil` (Entwurf, schon als "Manuell eintragen" vorhanden, hier zweite Bedeutung). | 00 Kap. 9.2 | Avo-Aktionen und Menüs |
| E-10 | **Nativer Kanal `shoply/voice`** (Teil B, eigene Swift-Datei; Registrierung in `AppDelegate.swift` durch Teil B): Spracherkennung starten/stoppen mit Teil- und Endergebnis, Pegel des Mikrofons und der Sprachausgabe (ca. 30 Werte pro Sekunde für den Ring), Sprachausgabe mit Stimme und Unterbrechen, Audio-Sitzung mit Leiserstellen anderer Audioausgabe. | 00 Kap. 17.7 | Kern folgt der Lautstärke; kein passendes Paket liefert Pegel beider Richtungen |
| E-11 | **Kanal `shoply/tab_bar` erweitert:** `setAskText(text)`, `focusAsk()`, `blurAsk()`, `setAskPlaceholder(text)`, `setAskReturnKey(send | search)`, Ereignis `onAskFocusChange(bool)`; Zustand "fertig, ungelesen" für den Kern (einmaliges Aufleuchten). | 00 Kap. 12.1 | Panel, Vorbefüllung bei `waveform` und `/avo?prompt=`, Lupen-Modus |
| E-12 | **Route** `/avo` nimmt zusätzlich `?context=` nicht an: Kontext kommt immer aus dem aktuellen Screen; Siri, Widget und Deep Links öffnen ohne Kontext (Zeile "Siri, Widget …" in 5.2). Keine eigene Route für die Kamera (Systemkamera). | 01 Kap. 7 | klare Regel für Kontext |
| E-13 | **Tonalität Avo** (zu 00 Kap. 3.2): Avo spricht in der ersten Person, beginnt nie mit Vorrede, wiederholt keine Ergebniszeile, höchstens drei Sätze nach einer Aktion; Antworten ohne Überschriften, Tabellen und Fettdruck außer Namen. | 00 Kap. 3.2 | gleicher Ton auf beiden Macs und im System-Prompt |
| E-14 | **Haptik** (zu 00 Kap. 11): Abhaken in einer Avo-Listen-Sektion = leichter Impuls; Ergebniszeilen selbst ohne Haptik, außer den Erfolgs-Ereignissen der Tabelle (Einkauf gespeichert, Wochenplan auf der Liste) und Warnung bei erkanntem Allergen auf einem Foto. | 00 Kap. 11 | Lücke für Ergebnisse, die Avo erzeugt |
