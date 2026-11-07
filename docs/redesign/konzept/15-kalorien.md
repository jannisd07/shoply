# 15 Kalorien und Gesundheit

Stand: 07.11.2026. Besitz: **Teil B** (Screens `calories`, Services, Health, Routen `lib/routes/areas/calories*`). Baut auf `00-grundlagen.md` (Verweise "00 x.y") und `01-navigation-und-struktur.md` (Verweise "01 x.y") auf. Soll: Plan 9, Verbesserungsliste Punkt 10. Ist: `inventar/calories.md` (Verweise "Inv. x.y").

Inhalt: 0 Vorab: zwei Konflikte mit neueren Owner-Entscheidungen · 1 Überblick · 2 Regeln für den ganzen Bereich · 3 Screens · 4 Berührungspunkte außerhalb des Tabs · 5 Abläufe · 6 Offene Fragen · 7 Ergänzungen zum Fundament

---

## 0. Vorab: zwei Konflikte mit neueren Owner-Entscheidungen

**0.1 "Nie Slider" (verbindlich, umgesetzt).** Commit `4ebb4fb` (07.11.2026, 21:18) hat in `CLAUDE.md` eine harte Regel des Owners ergänzt, die ausdrücklich auch für Design-Dokumente gilt: keine hereingleitenden Panels (keine Bottom-Sheets, keine halbhohen Modals, keine Drawer), Bearbeiten immer als eigener Vollbild-Screen mit Zurück und eigener Route oder direkt an Ort und Stelle, keine Schieberegler. Erlaubt bleiben zentrierte Alerts und Kontext- bzw. Pull-down-Menüs. 00 und 01 sehen für diesen Bereich noch Sheets vor ("Essen eintragen" als Sheet mittel, Mengen-Sheet, Modul-Sheet, Vorab-Erklärung als Sheet). Dieses Kapitel setzt die Owner-Regel um:

| In 00/01 | In diesem Kapitel |
|---|---|
| Sheet "Essen eintragen" (`/calories/add`, Sheet mittel) | Vollbild-Push `/calories/add` mit Zurück |
| Mengen-Sheet, Dialog "Menge (g)" | Push `/calories/add/food/:foodId` |
| Sheet "Ins Tagebuch" aus dem Rezept | Push `/calories/add/recipe/:recipeId` |
| Barcode-Kamera als Vollbild-Cover | Vollbild-Push ohne Tab-Bar `/calories/scan` (Übergang wie Push, Zurück oben links) |
| Modul-Sheet "Kalorien ist ausgeschaltet" | zentrierter Alert |
| Vorab-Erklärung Berechtigung als Sheet | Kamera: zentrierter Alert; Apple Health: Vollbild-Push `/calories/health` (zu viel Text für einen Alert) |
| Aktionsblatt "Änderungen verwerfen?" | zentrierter Alert |
| Datumswahl | Pull-down-Menü am Datum, darin "Datum wählen …" als Kalender-Menü, das aus dem Auslöser wächst |
| Ziel-Zeitraum als Schieberegler (heute) | Segment-Steuerung "Gemütlich / Normal / Zügig" |

Der Kopf aller Eintrage-Screens folgt dem Push-Muster: Zurück links, rechts eine getönte Glas-Text-Kapsel mit dem Verb ("Eintragen", "Sichern", "Übernehmen"). Das ersetzt für diese Screens K-30 (`xmark` / `checkmark` in Sheets). Siehe 7.1.

**0.2 Richtung D2 "Glas" mit 5 Tabs (nicht umgesetzt, offen).** Commit `ec5325c` (21:31) beschreibt in `docs/DESIGN-STATUS.md` eine Tab-Leiste Home · Listen · Avo · Rezepte · Profil, ohne Kalorien-Tab, mit einem Block "Kalorien heute" (Ring und Makros, "Mahlzeit hinzufügen" als Vollbild) auf der Startseite. Das widerspricht 01 2.1 (Tab Kalorien). Dieses Kapitel folgt 01, baut den Kopf des Tabs aber als eigenständige Komponente `CaloriesTodaySummary` (7.3), die ohne Änderung auch als Startseiten-Block funktioniert. Alle Unterseiten haben eigene Routen und hängen nicht am Tab. Entscheidung: Frage F-K1.

---

## 1. Überblick

### 1.1 Was der Bereich leistet

Modul **Kalorien & Gesundheit** (00 15.1, Standard aus, Owner-Frage F-04). Die Wurzel beantwortet nur eine Frage: **Wie viel kann ich heute noch essen?** Alles andere (Ziele, Woche, Gewicht, Workouts, Challenges, Ideen) liegt eine Ebene tiefer, wie in Health: Zusammenfassung zuerst, Details auf eigenen Seiten.

Plan 9 ist erfüllt, wenn ein Tag komplett per Foto, Barcode-Kamera und Suche geloggt werden kann und Gewicht, Wasser und Workouts in Apple Health landen und von dort zurückkommen (Verbesserungsliste 10, "Fertig, wenn").

### 1.2 Bereichskarte

| Screen | Route | Muster | Hauptfrage | Abschnitt |
|---|---|---|---|---|
| Tagebuch (Tab-Wurzel) | `/calories` (`?date=YYYY-MM-DD`) | Tab-Wurzel | Wie viel kann ich heute noch essen? | 3.1 |
| Tagebuch ohne Ziel | `/calories` | Zustand der Wurzel | Wie viel will ich am Tag essen? | 3.2 |
| Datum wählen | Menü an der Datumszeile | Menü | Welchen Tag will ich sehen? | 3.3 |
| Essen eintragen | `/calories/add` (`?meal=`, `?date=`) | Push | Was hast du gegessen? | 3.4 |
| Foto aufnehmen | `/calories/add/photo` | Vollbild-Push ohne Tab-Bar | Ist das Essen gut im Bild? | 3.5 |
| Schätzung prüfen | `/calories/add/estimate` | Push | Stimmt diese Schätzung? | 3.6 |
| Barcode-Kamera | `/calories/scan` | Vollbild-Push ohne Tab-Bar | Welches Produkt ist das? | 3.7 |
| Menge | `/calories/add/food/:foodId` | Push | Wie viel davon hast du gegessen? | 3.8 |
| Manuell | `/calories/add/manual` | Push | Was und wie viele Kalorien? | 3.9 |
| Eintrag | `/calories/entry/:entryId` | Push | Stimmt dieser Eintrag? | 3.10 |
| Rezept ins Tagebuch | `/calories/add/recipe/:recipeId` | Push | Wie viele Portionen, zu welcher Mahlzeit? | 3.11 |
| Wasser | Zeile im Tagebuch, Menü, Alert | Zeile | Habe ich genug getrunken? | 3.12 |
| Ziele | `/calories/goals` | Push | Was ist mein Tagesziel? | 3.13 |
| Ziel berechnen | `/calories/goals/setup` | Push | Was brauche ich für mein Ziel täglich? | 3.14 |
| Woche | `/calories/week` (`?start=YYYY-MM-DD`) | Push | Wie lief meine Woche? | 3.15 |
| Gewicht | `/calories/weight` | Push | Wie entwickelt sich mein Gewicht? | 3.16 |
| Workouts | `/calories/workouts` | Push | Wie viel habe ich mich bewegt? | 3.17 |
| Workout eintragen / bearbeiten | `/calories/workouts/new`, `/calories/workouts/:id` | Push | Was habe ich trainiert? | 3.18 |
| Challenges | `/calories/challenges` | Push | Halte ich meine Challenge heute ein? | 3.19 |
| Eigene Challenge | `/calories/challenges/new` | Push | Welche Gewohnheit will ich üben? | 3.20 |
| Ideen für heute | `/calories/ideas` | Push | Was passt noch in mein Budget? | 3.21 |
| Apple Health verbinden | `/calories/health` | Push | Will ich Health verbinden? | 3.22 |
| Einstellungen Kalorien & Gesundheit | `/settings/health` | Push in Profil | Wie ist der Bereich eingestellt? | 3.23 |
| Modul ist aus | jede `/calories/*`-Route | zentrierter Alert | Will ich Kalorien einschalten? | 3.24 |

Push-Tiefe höchstens drei Ebenen (01 6): Tagebuch > Essen eintragen > Menge. Die Schätzung ersetzt den Kamera-Screen im Stapel (Kamera > Schätzung zählt als eine Ebene).

### 1.3 Beispieltag (alle Beispiele in diesem Kapitel passen zusammen)

Samstag, 7. Nov. 2026, 18:40 Uhr. Ziel "Abnehmen", 74,0 kg Start, 72,4 kg heute, Zielgewicht 70,0 kg, leicht aktiv.

| Wert | Zahl |
|---|---|
| Tagesziel | 2.000 kcal · Protein 133 g · Kohlenhydrate 227 g · Fett 62 g · Wasser 2 l |
| Gegessen | 1.360 kcal · Protein 82 g · Kohlenhydrate 166 g · Fett 41 g |
| Übrig | **640 kcal** |
| Frühstück (420 kcal) | Haferflocken 60 g (220 kcal) · Milch 1,5 % 200 ml (94 kcal) · Banane 1 Stück (106 kcal) |
| Mittagessen (650 kcal) | Spaghetti Bolognese, geschätzt aus Foto (650 kcal) |
| Snacks (290 kcal) | Milbona Skyr Natur 250 g, per Barcode (158 kcal) · Studentenfutter 25 g (132 kcal) |
| Abendessen | noch nichts |
| Wasser | 1,25 l von 2 l (fünfmal 250 ml) |
| Workout heute | Laufen, 32 Min, 280 kcal, von der Apple Watch (aus Health) |
| Woche 2.–8. Nov. | Mo 1.910 · Di 2.080 · Mi nicht erfasst · Do 1.760 · Fr 1.950 · Sa 1.360 (läuft) · So offen; Ø 1.925 kcal an 4 abgeschlossenen Tagen, 4 von 4 im Ziel |
| Workouts der Woche | Laufen Sa 32 Min 280 kcal · Krafttraining Do 45 Min 260 kcal · Radfahren Di 23 Min 280 kcal = 1 Std. 40 Min, 820 kcal |
| Gewicht | 74,0 (2. Okt.) · 73,4 (28. Okt.) · 73,0 (31. Okt.) · 72,7 (Mi., 4. Nov.) · 72,4 (Sa., 7. Nov.) |
| Challenge | 16:8 Intervallfasten seit Di., 3. Nov., heute Tag 5, 4 von 4 Tagen geschafft; im Verlauf "30 Tage ohne Zucker", 1.–30. Okt., 26 von 30 Tagen |
| Allergie | Erdnuss (eingetragen in Ernährung & Allergien) |

---

## 2. Regeln für den ganzen Bereich

### 2.1 Daten und Laden (00 13)

- **Lokaler Stand pro Tag.** Einträge, Wasser, Workouts und Tagessummen liegen pro Kalendertag (`YYYY-MM-DD`, lokale Zeit) im lokalen Speicher. Der Tab zeigt beim Öffnen sofort diesen Stand; der Abgleich mit Supabase läuft im Hintergrund. Neue Werte rollen in die Zahlen, Zeilen wachsen ein. Nie ein Spinner.
- **Nachbartage vorladen.** Beim Öffnen eines Tages werden der Vortag und (falls nicht heute) der Folgetag geladen, damit Wischen nie wartet (behebt Inv. 4.21).
- **Summen lokal rechnen.** Ring, Makros und Mahlzeiten-Summen werden aus den Einträgen des Tages berechnet, nicht per eigener Abfrage. Eine Änderung invalidiert genau einen Tag und die laufende Woche (heute sieben Provider, Inv. 4.22).
- **Optimistisch.** Eintragen, Ändern, Löschen, Wasser und Gewicht erscheinen sofort; Speichern läuft in einer dauerhaften Warteschlange (offline-fest). Schlägt es endgültig fehl: die Zeile zeigt "Nicht gespeichert" mit `exclamationmark.circle` in `danger`, Tippen wiederholt, Fehler-Haptik.
- **Fehler werden nicht verschluckt.** Services geben bei Netzfehlern einen Fehler zurück, nicht `null` oder eine leere Liste. Ein Netzfehler darf nie den Zustand "Ziel fehlt" oder "Noch nichts eingetragen" erzeugen (behebt Inv. 4.1). Ohne lokalen Stand und mit Fehler: `StatusRow` "Das Tagebuch konnte nicht geladen werden. Erneut versuchen" an der Stelle der Sektionen.
- **Ungeloggte Tage** sind unbekannt, nicht 0 kcal (Diagramme leer, Durchschnitte nur über erfasste Tage).
- **Löschen mit Rückgängig** (00 2 Prinzip 6): Einträge, Wasser, Gewicht, Workouts. Bestätigung nur bei "Challenge abbrechen" (00 12.34) und "Alle Essensfotos löschen".

### 2.2 Rechnen und Zahlen

- **Übrig = Tagesziel − Gegessen.** Workouts werden standardmäßig **nicht** gutgeschrieben (Schätzungen des Verbrauchs sind ungenau). Schalter in Ziele: "Verbrauch durch Workouts gutschreiben" (aus). Ist er an: Übrig = Ziel − Gegessen + Workout-kcal, und die Unterzeile nennt den Posten ("+280 kcal Laufen"). Frage F-K3.
- **Über dem Ziel:** "120 kcal drüber" in `warning` mit `exclamationmark.triangle.fill`, Ring voll (00 12.14). Kein Rot, keine Wertung.
- Format über `intl`: "1.360 kcal", "1,25 l", "72,4 kg", "32 Min", "1 Std. 40 Min". kcal immer als Ganzzahl, Gramm bis 10 g mit einer Nachkommastelle ("0,5 g"), darüber ganzzahlig.
- Alle Eingabefelder akzeptieren Dezimalkomma und -punkt (`parseLocaleDouble`). Ungültige Eingabe: Hinweis direkt unter dem Feld ("Bitte eine Zahl, zum Beispiel 450 oder 450,5"), nie still 0 speichern (behebt Inv. 4.4, 4.5).
- Einheiten nach Einstellung (3.23): kg oder lb, kcal oder kJ. Beispiele hier in kg und kcal.
- Mahlzeiten (Begriffe verbindlich): Frühstück, Mittagessen, Abendessen, Snacks. Kurzformen nur in der Segment-Steuerung bei Platzmangel: "Früh", "Mittag", "Abend", "Snack".
- Mahlzeit nach Uhrzeit vorausgewählt: bis 10:29 Frühstück, 10:30 bis 14:59 Mittagessen, 15:00 bis 16:59 Snacks, 17:00 bis 21:29 Abendessen, danach Snacks. Für vergangene Tage: die Mahlzeit, deren "Eintragen" angetippt wurde, sonst Snacks.

### 2.3 KI-Schätzungen (Responsibility)

- Jede KI-Schätzung (Foto, Text "Kalorien schätzen lassen", Avo) ist eine **bearbeitbare Vorschau** mit sichtbarer Sicherheit und dem Wort "geschätzt". Gespeichert wird erst nach "Eintragen". Der gespeicherte Eintrag behält die Markierung "geschätzt".
- **Sicherheit in drei Stufen in Worten**, nicht als Prozent: "Recht sicher", "Unsicher", "Grob geschätzt". Grund: Prozentwerte eines Sprachmodells sind nicht kalibriert und wären eine erfundene Genauigkeit (00 1.5). Abweichung von 01 10.7 ("ca. 80 % sicher"), siehe 7.6.
- Die Schätzung nennt Bestandteile mit Gramm, damit man die Portion korrigieren kann (Portionsgröße ist der größte Fehler bei Fotos).
- Allergien aus "Ernährung & Allergien" werden mitgeprüft: erkennt die Schätzung ein eingetragenes Allergen, erscheint eine Warnzeile (Symbol plus Text, `warning`, Warn-Haptik einmal). Ohne Figur, ohne Witz (00 3.3).
- KI läuft über Claude via Supabase Edge Function (Plan 7), kein Schlüssel in der App, die Pause von 1.100 ms zwischen Aufrufen gilt weiter.
- Fotos liegen in einem **privaten** Bucket mit signierten URLs (behebt Inv. 4.17). Der Upload blockiert das Speichern nie.

### 2.4 Apple Health (Plan 9)

| Richtung | Datentypen | Regel |
|---|---|---|
| Schreiben | Nahrungsenergie, Protein, Kohlenhydrate, Fett (je Eintrag als Lebensmittel-Korrelation), Wasser, Körpergewicht, Workouts (mit Energie und Dauer) | Jeder geschriebene Wert trägt die Eintrags-ID als externe Kennung; Ändern und Löschen in der App ändert bzw. löscht den Health-Wert mit. |
| Lesen | Körpergewicht, Größe, Wasser, Workouts | Werte, die die App selbst geschrieben hat, werden beim Lesen erkannt und nicht doppelt gezeigt. Gelesene Werte anderer Quellen sind schreibgeschützt und tragen die Quelle ("Apple Watch", "Withings"). |
| Nicht lesen | Nahrungsenergie anderer Apps | sonst Doppelzählung mit anderen Kalorien-Apps (Frage F-K4) |

- Aus Health gelesene Werte werden **nur auf dem Gerät** angezeigt und nicht zu Supabase hochgeladen (Datenschutz; App-Review 5.1.3). Auf einem zweiten Gerät erscheinen sie, wenn dort Health dieselben Daten hat. Frage F-K5.
- Vorab-Erklärung vor der Systemabfrage (3.22), erst im Moment des Nutzens (00 13).
- Modul aus: Synchronisation pausiert, Daten bleiben (00 15.1).

### 2.5 Glas, Bewegung, Haptik in diesem Bereich

- Glas nur: Tab-Bar mit Avo-Kreis, Toolbar-Gruppe oben, auf den Kamera-Screens die Bedienleisten, Menüs, Rückgängig-Hinweis. Höchstens drei Glas-Views pro Screen (00 8.5); die Werte stehen je Screen.
- Zahlen (übrig, Makros, Wasser, Mengen, Wochen-Ø, Gewicht) sind `RollingNumber` mit `springDigits`; Ring und Balken folgen mit `springDigits`.
- Neue Zeilen wachsen mit `springStandard` ein; gelöschte schrumpfen mit `springStandard`.
- Haptik (00 11, Ergänzungen in 7.5): Eintrag gespeichert und Wasser hinzugefügt: leichter Impuls; Barcode erkannt: leichter Impuls; Challenge-Check-in: leichter Impuls; Challenge mit fester Dauer geschafft: Erfolg; Tag per Wischen gewechselt, Stepper, Segment per Wischen: Auswahl; Allergen erkannt: Warnung; nicht gespeichert: Fehler. Keine Haptik beim Öffnen von Screens, Menüs, Tippen in Felder.

---

## 3. Screens

### 3.1 Tagebuch (Tab-Wurzel `/calories`)

**Zweck.** Wie viel kann ich heute noch essen? Man kommt über den Tab Kalorien, das Kalorien-Widget, die Hinweis-Zeile "Noch 640 kcal heute" auf der Startseite, Siri, eine Mitteilung oder nach jedem Eintragen zurück hierher.

**Aufbau von oben nach unten.**

1. **`LargeTitleNavBar`, Variante Tab-Wurzel.** Großer Titel "Kalorien", rechts in der Titelzeile der Profil-Avatar (36 pt). Obere Zeile rechts: `GlassToolbar` mit einem Knopf `plus` (Label "Essen eintragen", öffnet 3.4 mit der Mahlzeit nach Uhrzeit).
2. **Datumszeile** 8 pt unter dem Titel (`subheadline`, `label`): "Heute, Sa., 7. Nov." mit `chevron.down` (13 pt Semibold, `labelSecondary`) direkt dahinter. Die ganze Zeile ist eine Taste und öffnet das Datums-Menü (3.3). Auf einem vergangenen Tag: "Do., 5. Nov." und rechts daneben die schlichte Aktion "Heute".
3. **`StatusRow`** (nur bei Bedarf): offline, ausstehende Änderungen ("2 Einträge warten"), Fehler.
4. **Tipp-Zeile** (einmalig, 00 K-21, im Stil `HintRow`): `heart` (16 pt, `labelSecondary`) "Mit Apple Health verbinden: Gewicht und Workouts deiner Apple Watch kommen automatisch dazu." rechts schlicht "Verbinden". Wischen nach links "Ausblenden". Erscheint erst ab dem zweiten Tag mit Einträgen, nie zusammen mit einer `StatusRow`.
5. **Sektion "Heute" = `CaloriesTodaySummary`** (`InsetSection` ohne Titel):
   - Zeile 1 (Mindesthöhe 152): links der Textblock: "640" in `numberXL` (`label`), darunter "kcal übrig" (`headline`), darunter "1.360 gegessen · Ziel 2.000" (`subheadline`, `labelSecondary`). Rechts `ProgressRing` 120 pt in `health` (Spur `fill`), Wert = gegessen / Ziel (68 %). Keine Zahl im Ring.
   - Zeilen 2 bis 4, **Makros** als drei getrennte Zeilen, alle in `health`: links "Protein" (`body`), rechts "82 von 133 g" (`number` für 82, Rest `subheadline` `labelSecondary`), darunter über die volle Textbreite ein Balken 4 pt hoch, Radius 2, Wert `health`, Spur `fill`. Dann "Kohlenhydrate 166 von 227 g", "Fett 41 von 62 g". Trennlinien in `separator` ab der Textkante.
   - Zeile 5 (`NavRow`, nur heute und bei mindestens 150 kcal übrig): `fork.knife` (17 pt, `labelSecondary`), "Was passt noch?", Wert "6 Rezepte", `chevron.right`. Öffnet 3.21.
6. **Vier Mahlzeiten-Sektionen** (`InsetSection` mit Titel), Reihenfolge Frühstück, Mittagessen, Snacks, Abendessen in der Reihenfolge des Tages (Snacks zwischen Mittag- und Abendessen). Titel `headline` "Frühstück", rechts der Zähler "420 kcal" (`numberS`, `labelSecondary`).
   - Zeilen `FoodEntryRow` (7.3): optional Foto 28 pt (`radiusPhotoS`) bei Foto-Einträgen und Produkten mit Foto, Name (`body`, bricht um), Unterzeile (`subheadline`, `labelSecondary`) "60 g" bzw. "1 Teller · geschätzt" bzw. "250 g · Milbona"; rechts "220" in `number` mit "kcal" in `subheadline` `labelSecondary`.
   - Letzte Zeile jeder Mahlzeit: schlichte Aktion `plus` "Eintragen" in `action` (öffnet 3.4 mit dieser Mahlzeit). Eine Mahlzeit ohne Einträge besteht nur aus dieser Zeile, der Zähler entfällt.
7. **Sektion "Wasser"** (eine Zeile, 3.12): `drop.fill` (mehrfarbig erlaubt, 00 9.1), "1,25 l von 2 l" (`number` für 1,25), darunter ein 4-pt-Balken in `health`; rechts kleine graue Kapsel "+250 ml" (`AppButton` klein, Grau).
8. **Sektion "Diese Woche"**: Titel als Taste "Diese Woche" mit `chevron.right` (öffnet 3.15). Inhalt: eine Zeile "Ø 1.925 kcal · 4 von 4 Tagen im Ziel" (`subheadline`, `label`), darunter `BarChart` 120 pt hoch: sieben Balken Mo bis So in `health`, Ziellinie 2.000 gestrichelt in `labelSecondary`, Achse `caption1` mit "Mo Di Mi Do Fr Sa So", "Sa" fett (heute). Mi leer (nicht erfasst), So leer (Zukunft).
9. **Sektion ohne Titel** mit `NavRow`s (je Symbol 17 pt frei in `labelSecondary`, Titel, Wert rechts, `chevron.right`):
   - `scalemass` "Gewicht" · "72,4 kg"
   - `figure.run` "Workouts" · "32 Min heute"
   - `flag` "Challenges" · "16:8 · Tag 5"
   - `target` "Ziele" · "2.000 kcal"
10. Unterer Abstand `bottomContentInset`, Scroll-Edge-Verlauf hinter der Tab-Bar.

Glas: Tab-Bar (1), Toolbar oben (2). Kein Accessory in diesem Tab.

**Beispielinhalt.** Wie 1.3. Workout-Zeile "32 Min heute" kommt aus Health; weil "Gutschreiben" aus ist, bleibt "640 kcal übrig".

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Erster Start, kein Ziel | 3.2 |
| Ziel, aber heute noch nichts | "2.000" `numberXL`, "kcal übrig", Unterzeile "Noch nichts gegessen · Ziel 2.000"; Ring leer; Makros "0 von 133 g"; alle Mahlzeiten nur mit "Eintragen". Kein leerer Zustand mit Maskottchen, die Seite ist ja nutzbar. |
| Lädt | sofort lokaler Stand. Nur beim allerersten Öffnen auf einem neuen Gerät ohne lokalen Stand: Tonflächen in `fill` in Form der Sektion "Heute" und zweier Mahlzeiten, bis die erste Antwort da ist. |
| Fehler ohne lokalen Stand | `StatusRow` "Das Tagebuch konnte nicht geladen werden." mit "Erneut versuchen" an der Stelle der Sektionen; Toolbar `plus` bleibt nutzbar (Einträge gehen in die Warteschlange). |
| Offline | `StatusRow` "Offline. Deine Einträge werden gespeichert, sobald du wieder online bist." Neue Zeilen tragen das Sync-Zeichen (`arrow.triangle.2.circlepath` 10 pt hinter der kcal-Zahl). Die Zeile "Was passt noch?" zeigt nur lokal gespeicherte Rezepte. |
| Über dem Ziel | "120" `numberXL`, "kcal drüber" in `warning` mit `exclamationmark.triangle.fill`, Ring voll; Zeile "Was passt noch?" entfällt. |
| Vergangener Tag | Statt "übrig": "1.950" `numberXL`, "kcal gegessen", Unterzeile "Ziel 2.000 · 50 unter Ziel". "Was passt noch?" entfällt. Woche zeigt die Woche dieses Tages. |
| Health nicht erlaubt (abgelehnt) | Workout-Zeile zeigt nur eingetragene Workouts; in der Zeile "Workouts" kein Hinweis. Der Hinweis sitzt nur auf 3.17 und 3.23. |
| Modul aus | Tab nicht vorhanden; Route öffnet 3.24. |
| Pro gesperrt | Die Tagesansicht ist nie gesperrt (Kern des Moduls). Gesperrte Unterfunktionen tragen `ProBadge` in ihrer Zeile (6, F-K2). |

**Interaktionen, Gesten, Bewegung, Haptik.**

- **Tag wechseln per Wischen** auf Datumszeile und Sektion "Heute": Der Inhalt der Sektion folgt dem Finger waagerecht 1:1 (mit Griffabstand), der Nachbartag schiebt nach. Beim Loslassen Ziel aus der Wurfprojektion, `springFling` mit Fingergeschwindigkeit, Auswahl-Haptik beim Einrasten. Die Sektionen darunter wechseln mit `fadeReduced` (sie sind vorgeladen). Nach rechts über "Heute" hinaus: Gummiband, kein Wechsel. Der ganze Bildschirm wischt nicht, damit Wischaktionen auf Zeilen und Zurück-Wischen frei bleiben.
- **Erneutes Tippen auf den Tab** springt zu "Heute" und nach oben.
- **Antippen eines Balkens** in "Diese Woche" zeigt den Tag (wie Wischen), langes Ziehen über das Diagramm zeigt den Wert in einer Zeile über dem Diagramm ("Do., 5. Nov.: 1.760 kcal"), Auswahl-Haptik pro Balken.
- **Eintrag antippen:** Push 3.10. **Wischen nach links:** "Löschen" (`danger`, volles Wischen löscht sofort, leichter Impuls beim Überschreiten der Schwelle), Rückgängig-Hinweis "Spaghetti Bolognese gelöscht · Widerrufen". **Langdruck:** Kontextmenü "Bearbeiten", "Zu anderer Mahlzeit" (Untermenü mit den drei anderen), "Heute nochmal eintragen" (nur auf vergangenen Tagen oder in einer anderen Mahlzeit), "Löschen".
- **Zahlen:** Nach jedem Eintrag rollt "640" auf den neuen Wert, der Ring und der Makro-Balken folgen mit `springDigits`; die neue Zeile wächst in ihrer Mahlzeit ein (`springStandard`). Leichter Impuls im Frame, in dem die Zeile erscheint, nicht beim Zurückkehren.
- **Pull-to-Refresh:** Systemverhalten, lädt den Tag neu.
- Reduce Motion: Tageswechsel als Überblendung; Ziffern blenden als Ganzes über.

**VoiceOver.** Datumszeile: "Datum: Heute, Samstag, 7. November. Tag wechseln, Taste". Sektion "Heute" als ein Element: "Kalorien heute, 640 von 2.000 übrig, 1.360 gegessen", eigene Aktionen "Vorheriger Tag", "Nächster Tag" (Wischen hoch/runter als einstellbares Element). Makro-Zeile: "Protein, 82 von 133 Gramm". Eintrag: "Spaghetti Bolognese, geschätzt, 650 Kilokalorien, Mittagessen", Aktionen Bearbeiten, Mahlzeit ändern, Löschen. Diagramm: Satz "Diese Woche im Schnitt 1.925 Kilokalorien an 4 Tagen, Ziel 2.000", dann Balken als Elemente.

**Große Schrift und 320 pt.**

- 320 pt (Textgröße L): Ring 120 und Textblock passen nebeneinander (256 pt Innenbreite: 120 Ring, 16 Abstand, 120 Text); die Unterzeile "1.360 gegessen · Ziel 2.000" rutscht unter beide in volle Breite.
- Ab xxxL: Ring unter den Textblock, linksbündig, 120 pt. `numberXL` höchstens 51 pt (00 5.3).
- Ab AX1: Sektionen randlos (`bgPlain`), Makro-Zeilen stapeln ("Protein" über "82 von 133 g"), Fotos in Eintragszeilen entfallen, kcal rutscht unter den Namen. "+250 ml" rutscht unter "1,25 l von 2 l". Achsenbeschriftungen des Diagramms ab AX1 aus, darunter als Text "Mo 1.910 · Di 2.080 · Mi – · …" (00 5.3).
- Die Sektion "Heute" bleibt auf iPhone SE bei L vollständig über dem Falz (Titel ca. 100 pt, Sektion ca. 340 pt).

**Was sich ändert, betroffene Dateien.** Ersetzt `_Dashboard` und `_SetupPrompt` in `lib/presentation/screens/calories/calories_screen.dart` (acht gleichrangige Blöcke, Kicker "KALORIEN", "Dein Tag,\nin Kalorien.", Paper-Farben, Regenbogen-Makros, zwei Outline-Buttons, doppelter Einstieg Wochenrückblick). Entfallen: `widgets/calorie_ring.dart` (durch `ProgressRing`), `widgets/macro_bar.dart`, `widgets/water_tracker_card.dart`, `widgets/weekly_calories_strip.dart`, `widgets/challenges_entry_card.dart`, `widgets/food_log_tile.dart` (durch `FoodEntryRow`). Neu: `widgets/calories_today_summary.dart`, `widgets/meal_section.dart`, `widgets/food_entry_row.dart`, `widgets/water_row.dart`. State: `nutrition_provider.dart` wird auf Tages-Familie mit lokalem Stand umgebaut (`dailyLogProvider(date)`), `invalidateNutritionLog()` invalidiert nur noch den Tag und die Woche. Tab-Label kommt aus der Übersetzung (heute hart "Kalorien" in `main_scaffold.dart`).

**Bildbeschreibung für ChatGPT.** Ein iPhone-17-Pro-Screenshot im hellen Modus einer vorinstallierten Apple-App aus iOS 27: Hintergrund #F2F2F7, weiße inset-gruppierte Sektionen mit 26 pt Eckenradius, SF Pro, Text #000000, Metadaten #636366, keine Schatten auf Inhalten. Oben der große fette Titel "Kalorien", rechts daneben ein runder Profilfoto-Avatar, darüber oben rechts ein runder, milchig-transparenter Liquid-Glass-Knopf mit Plus; unter dem Titel die Zeile "Heute, Sa., 7. Nov." mit kleinem grauem Chevron nach unten. Die erste weiße Sektion zeigt links groß in abgerundeten Ziffern "640", darunter "kcal übrig" in Halbfett und "1.360 gegessen · Ziel 2.000" in Grau, rechts einen dicken Fortschrittsring zu zwei Dritteln in Avocado-Grün #3F7A1F auf hellgrauer Spur #E9E9EE; darunter drei Zeilen "Protein 82 von 133 g", "Kohlenhydrate 166 von 227 g", "Fett 41 von 62 g", jede mit einem dünnen grünen Balken #3F7A1F, und eine Zeile "Was passt noch? 6 Rezepte" mit Chevron. Darunter Sektionen "Frühstück 420 kcal" (Haferflocken 60 g 220, Milch 1,5 % 200 ml 94, Banane 106), "Mittagessen 650 kcal" mit einem kleinen Foto Spaghetti Bolognese "1 Teller · geschätzt", jeweils mit einer grünen Textzeile "+ Eintragen" am Ende. Ganz unten schwebt eine Liquid-Glass-Tab-Bar mit vier Symbolen (Liste, Rezepte, Plan, Kalorien mit grün getönter Flamme ausgewählt) und rechts abgesetzt ein runder Glas-Knopf mit kleiner brauner Kugel #7A4A24 in hellgrünem Ring #C9DE6E. Ruhig, viel Luft, keine Großbuchstaben-Überschriften, keine bunten Balken, kein Maskottchen.

---

### 3.2 Tagebuch ohne Ziel (erster Start)

**Zweck.** Wie viel will ich am Tag essen? Erscheint, wenn das Modul an ist und noch kein Ziel gespeichert wurde (nicht bei Netzfehlern, 2.1).

**Aufbau.**

1. `LargeTitleNavBar` "Kalorien" mit Avatar; Toolbar `plus` bleibt (Eintragen ohne Ziel ist erlaubt).
2. `EmptyState` an der Stelle der Sektion "Heute": Symbol `target` 48 pt Light (`labelSecondary`), Titel (`title3`) "Wie viel willst du am Tag essen?", Satz (`body`, `label`) "Wir rechnen dein Tagesziel aus Größe, Gewicht und Alltag aus. Das dauert etwa eine Minute.", prominent "Ziel einrichten" (öffnet 3.14), darunter schlicht "Ohne Ziel eintragen" und schlicht "Tab ausblenden".
3. Nach "Ohne Ziel eintragen": die Wurzel wie 3.1, aber Sektion "Heute" zeigt "1.360" `numberXL` und "kcal gegessen", kein Ring, Makros ohne "von" ("Protein 82 g"), unten in der Sektion schlicht "Ziel festlegen".

**Zustände.** Offline beim ersten Start: `EmptyState` bleibt, "Ziel einrichten" funktioniert (Rechnung ist lokal, Speichern in der Warteschlange). Mit Apple Health verbunden: der Fragebogen ist mit Größe und Gewicht vorbefüllt.

**Interaktionen.** "Tab ausblenden" schaltet das Modul aus: Tab verschwindet mit `springStandard`, man landet auf Liste, Rückgängig-Hinweis "Kalorien ausgeblendet · Widerrufen". Keine Haptik.

**Große Schrift, 320 pt.** `EmptyState` fließt; drei Aktionen untereinander; ab AX1 ohne Symbol.

**Was sich ändert.** Ersetzt `_SetupPrompt` (Kicker, erzwungener Umbruch, `AppCard`, Material-`TextButton`, veralteter Fehlertext `calories_v0_card_sub`). Übersetzungsschlüssel `calories_v0_*` entfallen.

**Bildbeschreibung für ChatGPT.** Ein iPhone-Screenshot im hellen Modus im Stil einer Apple-App aus iOS 27, Hintergrund #F2F2F7. Oben der große fette Titel "Kalorien" mit rundem Profil-Avatar rechts und darüber ein runder Liquid-Glass-Knopf mit Plus. Im oberen Drittel, linksbündig wie ein leerer Zustand in Health, ein dünnes graues Zielscheiben-Symbol #636366 in 48 pt, darunter in Halbfett 20 pt "Wie viel willst du am Tag essen?" und in schwarzer Normalschrift #000000 der Satz "Wir rechnen dein Tagesziel aus Größe, Gewicht und Alltag aus. Das dauert etwa eine Minute.". Darunter eine breite gefüllte Kapsel in Avocado-Grün #3F7A1F mit weißer Schrift "Ziel einrichten", darunter zwei grüne Textlinks "Ohne Ziel eintragen" und "Tab ausblenden". Unten die schwebende Liquid-Glass-Tab-Bar mit vier Symbolen und abgesetztem rundem Avo-Knopf (braune Kugel #7A4A24 im hellgrünen Ring #C9DE6E). Keine Karten, keine Illustration, kein Maskottchen.

---

### 3.3 Datum wählen (Menü und Kalender-Menü)

**Zweck.** Welchen Tag will ich sehen? Über die Datumszeile in 3.1, auch auf 3.4, 3.11, 3.16 und 3.18 (dort als Wert-Zeile "Datum").

**Aufbau.** `AppMenu`, wächst aus der Datumszeile (`springMenu`, Ursprung am Chevron):
- Gruppe 1: "Heute", "Gestern", dann die fünf Tage davor ("Do., 5. Nov." …), der aktuelle mit `checkmark` links, Tage mit Einträgen rechts mit kleiner kcal-Zahl in `labelSecondary` ("1.760").
- Gruppe 2: "Datum wählen …" mit `calendar`.

"Datum wählen …" verwandelt das Menü an Ort und Stelle in ein **Kalender-Menü** (gleiche Glasfläche, wächst mit `springMenu` auf Kalendergröße): Monatskopf "November 2026" mit `chevron.left` / `chevron.right` (44 pt), Wochentage, Tage als 44-pt-Ziele; Tage mit Einträgen tragen einen 4-pt-Punkt in `labelSecondary`, heute in `action`, gewählter Tag als gefüllter Kreis in `action` mit `onAction`. Zukünftige Tage `labelTertiary`, nicht wählbar. Tippen wählt und schließt.

**Zustände.** Offline: Tage ohne lokalen Stand sind wählbar, zeigen dann die `StatusRow`. Reduce Motion: Überblendung statt Wachsen.

**Große Schrift, 320 pt.** Das Kalender-Menü nutzt bei 320 pt die volle Breite minus 16 pt Rand (Zellen 41 pt sichtbar, Trefferfläche 44 durch Überlappung der Ränder). Ab AX1 entfällt das Kalender-Raster; "Datum wählen …" zeigt stattdessen ein Rad-Auswahlfeld (Tag, Monat, Jahr) an derselben Stelle.

**Haptik.** Keine (Tippen in Menüs).

**Was sich ändert.** Ersetzt Chevron-Paar und Text-Tap in `calories_screen.dart:208-247` (zu kleine Ziele, Überlauf bei großer Schrift). Neu: Datumswahl über mehr als einen Tag zurück.

**Bildbeschreibung für ChatGPT.** Ausschnitt des Kalorien-Screens im hellen Modus, Hintergrund #F2F2F7, mit dem großen Titel "Kalorien" und der Zeile "Heute, Sa., 7. Nov." mit Chevron. Aus dieser Zeile wächst ein Liquid-Glass-Menü mit 20 pt Radius: Zeilen "Heute" mit grünem Häkchen #3F7A1F links, "Gestern 1.950", "Do., 5. Nov. 1.760", "Mi., 4. Nov.", "Di., 3. Nov. 2.080", die Zahlen klein in Grau #636366 rechtsbündig, darunter durch ein schmales Band getrennt "Datum wählen …" mit Kalender-Symbol rechts. Der Inhalt dahinter ist leicht sichtbar, aber nicht abgedunkelt. Schrift SF Pro, schwarz #000000, Zeilenhöhe 44 pt.

---

### 3.4 Essen eintragen (`/calories/add`)

**Zweck.** Was hast du gegessen? Über Toolbar `plus`, "Eintragen" in einer Mahlzeit, Avo-Feld `camera`-Menü "Essen eintragen", globale Suche (Aktion "Essen eintragen"), Widget, Siri, Deep Link `shoply://calories/add`.

**Aufbau (Vollbild-Push, Tab-Bar sichtbar).**

1. `LargeTitleNavBar` Push erste Ebene: Zurück "Kalorien", großer Titel "Essen eintragen". Keine Toolbar-Knöpfe.
2. **Mahlzeit:** `SegmentedControl` mit vier Segmenten "Frühstück · Mittag · Abend · Snack", vorausgewählt nach 2.2. Auf einem vergangenen Tag darunter `footnote` `labelSecondary` "Für Do., 5. Nov." (Taste, öffnet 3.3).
3. **`SearchField`** "Lebensmittel oder Marke suchen" (scrollt mit). Fokus schaltet den Screen in den Suchmodus (unten).
4. **Sektion ohne Titel**, drei `NavRow`s mit Symbol (17 pt, `labelSecondary`) und Unterzeile:
   - `camera` "Foto" · "Kalorien und Nährwerte werden geschätzt" → 3.5
   - `barcode.viewfinder` "Barcode scannen" · "Strichcode auf der Verpackung" → 3.7
   - `square.and.pencil` "Manuell" · "Name und Kalorien selbst eingeben" → 3.9
5. **Sektion "Heute im Plan"** (nur Modul Wochenplan, nur für heute, nur wenn ein Rezept geplant ist): Rezept-Zeile (Thumbnail 56 pt, "Ofengemüse mit Feta", "1 Portion · 520 kcal"), rechts schlicht `plus.circle` "Eintragen". Tippen auf die Zeile öffnet 3.11 mit den geplanten Portionen.
6. **Sektion "Zuletzt gegessen"** (bis 8 Zeilen, zuletzt und häufig gemischt, ohne Doppelte): `FoodEntryRow`-Variante mit rechts `plus.circle` (22 pt, `action`) statt der kcal-Zahl rechts; kcal steht in der Unterzeile. Beispiel: "Haferflocken · 60 g · 220 kcal", "Milbona Skyr Natur · 250 g · 158 kcal", "Banane · 1 Stück · 106 kcal", "Studentenfutter · 25 g · 132 kcal", "Vollkornbrot mit Käse · 2 Scheiben · 390 kcal".

**Suchmodus** (Feld fokussiert, ersetzt die Sektionen 4 bis 6; das Segment bleibt oben):
- Leer und fokussiert: "Zuletzt gegessen" bleibt sichtbar.
- Ab dem ersten Buchstaben, sofort lokal: Sektion "Zuletzt gegessen" (Treffer), Sektion "Eigene" (manuelle Einträge, die man schon einmal gemacht hat).
- Entprellt 300 ms, unten angefügt (nie oben eingeschoben): Sektion "Lebensmittel" mit Open-Food-Facts-Treffern. Zeile: Foto 28 pt (falls vorhanden, weiße Unterlage), Name (`body`, bricht um), Unterzeile "Milbona · 63 kcal pro 100 g"; rechts `chevron.right`. Tippen → 3.8.
- Fuß der Sektion (`footnote`): "Daten: Open Food Facts" als Link (behebt Inv. 4.19).
- "Abbrechen" rechts am Feld verlässt den Suchmodus.

**Beispielinhalt Suche "skyr".** Zuletzt gegessen: "Milbona Skyr Natur · 250 g · 158 kcal". Lebensmittel: "Skyr Natur · Milbona · 63 kcal pro 100 g", "Isländischer Skyr · Arla · 63 kcal pro 100 g", "Skyr Vanille · Ehrmann · 72 kcal pro 100 g".

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Erster Start | "Zuletzt gegessen" entfällt (Sektion ohne Rahmen weg); unter den drei Zeilen eine Tipp-Zeile "Tipp: Beim nächsten Mal steht hier, was du oft isst. Ein Tipp trägt es dann ein." |
| Lädt | Seite sofort aus dem lokalen Stand; Online-Treffer erscheinen unten, ohne Spinner. Während die Netzsuche läuft, zeigt das Feld rechts statt der Lupe nichts Zusätzliches. |
| Keine Treffer | `EmptyState` mit Maskottchen "suchend" (96 pt, ab AX1 ohne): "Nichts zu „Skyr Natur light“ gefunden." mit schlicht "Manuell eintragen" (übernimmt den Suchtext als Namen). |
| Fehler Netzsuche | `StatusRow` am Anfang der Sektion "Lebensmittel": "Die Suche hat nicht geklappt. Erneut versuchen"; lokale Treffer bleiben. |
| Offline | `StatusRow` unter dem Titel "Offline. Es werden nur eigene und zuletzt gegessene Lebensmittel gezeigt."; Zeile "Foto" mit Unterzeile "Braucht eine Verbindung" und deaktiviert (`labelTertiary`); "Barcode scannen" bleibt aktiv (schon gescannte Produkte liegen lokal). |
| Modul aus | 3.24 |
| Pro | Ist "Foto" Pro (F-K2): Zeile trägt `ProBadge`, die Kamera öffnet trotzdem; erst "Schätzen" öffnet die Paywall aus der Zeile (echte Vorschau: das eigene Foto ist zu sehen). |

**Interaktionen, Bewegung, Haptik.**
- Tippen auf eine Zeile in "Zuletzt gegessen" trägt sofort mit der gespeicherten Menge in die gewählte Mahlzeit ein: `plus.circle` wird mit `springQuick` zu `checkmark.circle.fill` in `action`, die Unterzeile wechselt 2 s zu "Eingetragen", leichter Impuls im selben Frame; Rückgängig-Hinweis "Haferflocken eingetragen · Widerrufen". Der Screen bleibt offen, damit man ein ganzes Frühstück nacheinander tippen kann. Zurück führt ins Tagebuch, wo die Zeilen schon stehen.
- Langdruck auf eine Zeile: Menü "Andere Menge …" (→ 3.8 bzw. 3.9 vorbefüllt), "Aus „Zuletzt“ entfernen".
- Segment wechselt mit `springQuick`; Auswahl-Haptik nur beim Wischen über die Segmente.

**Große Schrift, 320 pt.** Bei 320 pt Segmente "Früh · Mittag · Abend · Snack"; passt auch das nicht (ab xxL), wird die Segment-Steuerung zum Pull-down "Mahlzeit: Snacks" mit `chevron.up.chevron.down` (00 12.18). Zeilen brechen um; ab AX1 randlos, Fotos entfallen, `plus.circle` steht oben bündig zur ersten Textzeile.

**Was sich ändert.** Ersetzt `widgets/food_entry_sheet.dart` (Material-Modal mit eigenem Griff, vier Chips, nicht scrollbare Formulare, Inv. 4.25; `Image.network` ohne Cache, Inv. 4.24; Suchtreffer als Quelle `barcode`, Inv. 4.7). Neu: `add_food_screen.dart`. Neue Quelle `search` in `FoodLogSource` (Datenbank-Check anpassen, Teil B Migration).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, oben links ein runder Liquid-Glass-Zurück-Knopf mit Chevron. Großer fetter Titel "Essen eintragen", darunter eine graue Segment-Kapsel #E9E9EE mit "Frühstück · Mittag · Abend · Snack", in der "Abend" auf weißem Daumen gewählt ist, darunter ein graues Suchfeld mit Lupe "Lebensmittel oder Marke suchen". Darunter eine weiße Sektion mit 26 pt Radius und drei Zeilen mit dünnen grauen Symbolen #636366: Kamera "Foto" mit Unterzeile "Kalorien und Nährwerte werden geschätzt", Barcode-Sucher "Barcode scannen", Stift "Manuell", jeweils mit Chevron rechts. Darunter die Sektion "Zuletzt gegessen" mit Zeilen "Haferflocken" / "60 g · 220 kcal", "Milbona Skyr Natur" / "250 g · 158 kcal", "Banane" / "1 Stück · 106 kcal", rechts je ein grüner Plus-Kreis #3F7A1F; bei Haferflocken ist der Kreis schon ein gefülltes grünes Häkchen und die Unterzeile sagt "Eingetragen". Unten schwebt eine Glas-Kapsel "Haferflocken eingetragen · Widerrufen" über der Liquid-Glass-Tab-Bar. Text #000000, Metadaten #636366, keine Schatten auf Inhalten.

---

### 3.5 Foto aufnehmen (`/calories/add/photo`)

**Zweck.** Ist das Essen gut im Bild? Über "Foto" in 3.4, `camera` im Avo-Feld (Avo fragt dann im Gespräch, siehe 4.4) oder Deep Link.

**Aufbau (Vollbild-Push ohne Tab-Bar, Hintergrund #000000).**
1. Kamerabild randlos (natives Kamerabild als Platform View).
2. Oben links Glas-Knopf `chevron.left` ("Zurück"), oben rechts Glas-Knopf `bolt.slash` / `bolt` (Blitz), eine Glasgruppe, Variante `clear` mit Verlauf #000000 30 % am oberen Rand.
3. Über dem unteren Drittel ein Verlauf #000000 von 0 auf 55 %, darauf in `labelOnPhoto` (`subheadline`): "Teller von oben, ganz im Bild. Eine Gabel daneben hilft beim Schätzen der Größe."
4. Unten eine Glasgruppe: links `photo.on.rectangle` ("Aus Fotos"), Mitte Auslöser (weißer Ring 72 pt mit weißem Kreis 60 pt, kein Glas), rechts leer (Platzhalter für Symmetrie).

Glas: zwei Gruppen (oben, unten). Keine Tab-Bar, kein Avo-Kreis.

**Zustände.** Kamera-Berechtigung fehlt: vor der Systemabfrage ein zentrierter Alert "Kamera für Essensfotos" mit "Das Foto wird nur für die Schätzung verwendet und privat gespeichert." und "Nicht jetzt" / "Weiter". Abgelehnt: der Screen zeigt auf `bgGrouped` eine `StatusRow` "Kamera ist aus. In Einstellungen erlauben" und darunter prominent "Aus Fotos wählen". Offline: nicht erreichbar (Zeile in 3.4 deaktiviert).

**Interaktionen.** Auslöser: Bild friert ein (Blende-Animation des Systems), ersetzt den Screen im Stapel durch 3.6 (Push-Übergang; Zurück aus 3.6 führt zu 3.4). Keine Haptik (Systemklang der Kamera genügt). "Aus Fotos": System-Fotoauswahl (eine Auswahl), dann 3.6.

**Große Schrift, 320 pt.** Hinweistext bricht um; ab AX3 kürzer: "Teller von oben fotografieren." Glas-Knöpfe mit Large Content Viewer.

**Was sich ändert.** Ersetzt die Buttons "Kamera" / "Galerie" im Foto-Tab von `food_entry_sheet.dart:381-483` (System-Picker). Neu: `food_photo_camera_screen.dart` (nativ über das vorhandene `image_picker` mit Kamera-Overlay oder eigene `AVCaptureSession`-View, Teil B).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot einer Kameraansicht im Stil der iOS-27-Kamera, randlos: von oben fotografiert ein weißer Teller mit Spaghetti Bolognese und Parmesan auf einem hellen Holztisch, eine Gabel liegt daneben. Oben links und oben rechts je ein runder, klarer Liquid-Glass-Knopf (Chevron nach links, Blitz-Symbol) über einem leichten dunklen Verlauf. Im unteren Drittel ein weicher schwarzer Verlauf, darauf weiße Schrift #FFFFFF "Teller von oben, ganz im Bild. Eine Gabel daneben hilft beim Schätzen der Größe.". Unten mittig ein großer weißer Auslöser-Ring, links davon in einer Glas-Kapsel ein Fotos-Symbol. Keine Tab-Bar, keine Karten.

---

### 3.6 Schätzung prüfen (`/calories/add/estimate`)

**Zweck.** Stimmt diese Schätzung? Nach jedem Foto (3.5), nach "Bearbeiten" an einer Avo-Ergebniszeile (4.4).

**Aufbau (Push, Tab-Bar sichtbar).**
1. `LargeTitleNavBar`: Zurück, Inline-Titel bis zum Ergebnis "Schätzung", danach der Name ("Spaghetti Bolognese"). Rechts getönte Glas-Text-Kapsel **"Eintragen"** (deaktiviert, bis das Ergebnis da ist).
2. **Sektion Foto:** das eigene Foto 4:3 oben in der Sektion (`radiusSection` oben, unten 0), darunter auf `surface`:
   - Während der Schätzung: Zeile mit Avo-Kern 22 pt im Zustand `denkt` und "Wird geschätzt …" (`body`). Darunter ruhige Tonflächen in `fill` in Form der folgenden Zeilen.
   - Danach: Name als bearbeitbares Feld (`title3` Semibold, bricht um), Unterzeile "Mittagessen · Sa., 7. Nov., 12:41" (Taste: Mahlzeit und Zeit ändern per Menü).
3. **Sektion "Sicherheit"** (eine Zeile): links "Unsicher" (`body`), davor drei 8-pt-Punkte (gefüllt in `label`, leer als Ring `controlOutline`: recht sicher = 3, unsicher = 2, grob geschätzt = 1); Fuß (`footnote`, `labelSecondary`): "Geschätzt aus dem Foto. Die Portionsgröße ist am schwersten zu erkennen. Prüf vor allem die Gramm."
4. **Warnzeile Allergie** (nur bei Treffer, eigene Sektion): `exclamationmark.triangle.fill` in `warning`, "Kann Erdnuss enthalten. Du hast eine Erdnussallergie eingetragen." (`callout`, `label`). Warn-Haptik einmal beim Erscheinen.
5. **Sektion "Bestandteile":** Zeilen "Spaghetti, gekocht" / "ca. 220 g" / rechts "345 kcal"; "Bolognese-Soße" / "ca. 180 g" / "270 kcal"; "Parmesan" / "ca. 8 g" / "35 kcal". Tippen auf eine Zeile klappt sie an Ort und Stelle auf: Gramm-Feld (`numberL`) und `ValueStepper` (±10 g), kcal und Makros rechnen proportional mit (rollend). Letzte Zeile schlicht `plus` "Bestandteil hinzufügen" (Name und kcal).
6. **Sektion "Summe":** `NutritionRow` "650 kcal · 32 g Protein · 78 g Kohlenhydrate · 21 g Fett", Fuß "geschätzt". Werte rollen mit, wenn sich Bestandteile ändern. Tippen auf einen Wert erlaubt, die Summe direkt zu überschreiben (dann Fuß "geschätzt, von dir angepasst").
7. **Sektion ohne Titel:** `ToggleRow` "Foto im Tagebuch behalten" (an); Fuß "Das Foto wird privat gespeichert. Du kannst alle Essensfotos in den Einstellungen löschen."

Glas: Tab-Bar (1), Toolbar oben mit Zurück und "Eintragen" (2).

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Schätzt (3 bis 8 s) | wie oben; Zurück bricht ab, ohne zu fragen (nichts gespeichert). Der Avo-Kreis in der Tab-Bar zeigt ebenfalls `denkt`. |
| Kein Essen erkannt | an der Stelle der Ergebnis-Sektionen: Symbol `questionmark.circle` 48 pt Light, Titel "Auf dem Foto ist kein Essen zu erkennen.", prominent "Neues Foto", schlicht "Manuell eintragen". |
| Fehler | `StatusRow` "Die Schätzung hat nicht geklappt. Erneut versuchen"; Foto bleibt; Fehler-Haptik. |
| Offline während der Schätzung | `StatusRow` "Offline. Die Schätzung braucht eine Verbindung." mit "Erneut versuchen"; das Foto bleibt im Screen. |
| Ungespeichert verlassen | Zurück mit Änderungen: zentrierter Alert "Schätzung verwerfen?" / "Das Essen wird nicht eingetragen." / "Verwerfen" (rot), "Weiter bearbeiten". |
| Pro gesperrt (falls F-K2) | Foto und Hinweis "Mit {pro} schätzt {app} Kalorien aus Fotos." mit `ProBadge`; die Toolbar-Kapsel heißt "Schätzen" und öffnet die Paywall aus der Kapsel. |

**Interaktionen.** "Eintragen": Screen schließt (Pop zurück ins Tagebuch, 3.4 wird übersprungen), die Zeile wächst in "Mittagessen" ein, "640" rollt, leichter Impuls, Rückgängig-Hinweis "Spaghetti Bolognese eingetragen · Widerrufen". Mit Health: wird geschrieben. Ergebnis erscheint per `fadeReduced` in die Tonflächen (kein Layout-Sprung, Flächen sind reserviert).

**Große Schrift, 320 pt.** `NutritionRow` 2 × 2 bei 320 pt und ab xxxL (00 6.3). Bestandteil-Zeilen stapeln ab AX1 (kcal unter den Gramm). Foto bleibt 4:3 in voller Breite.

**Was sich ändert.** Ersetzt den Foto-Tab in `food_entry_sheet.dart` (Konfidenz als Funkel-Icon mit "geringe Sicherheit" ohne Erklärung, Inv. 3; drei Makrofelder nebeneinander, Inv. 3; 0 kcal bei leerem Feld, Inv. 4.4; Fehlermeldung auf Englisch "Couldn't identify food"). `meal_photo_analysis_service.dart` wechselt auf Claude über die Edge Function, liefert Bestandteile, Gramm, Sicherheitsstufe (Enum mit Rückfall auf "grob geschätzt" bei unbekanntem Wert, Inv. 4.16) und erkannte Allergene. `meal_photo_storage_service.dart` auf privaten Bucket. Neu: `food_estimate_screen.dart`.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7. Oben links ein runder Liquid-Glass-Zurück-Knopf, oben rechts eine grün getönte Glas-Kapsel #3F7A1F mit weißem Text "Eintragen", in der Mitte klein "Spaghetti Bolognese". Darunter eine weiße Sektion mit 26 pt Radius, oben randlos ein appetitliches Foto eines Tellers Spaghetti Bolognese von oben, darunter der Name "Spaghetti Bolognese" in Halbfett und grau #636366 "Mittagessen · Sa., 7. Nov., 12:41". Eine Zeile "Unsicher" mit drei kleinen Punkten (zwei schwarz gefüllt, einer als grauer Ring) und darunter eine graue Fußnote "Geschätzt aus dem Foto. Die Portionsgröße ist am schwersten zu erkennen.". Sektion "Bestandteile" mit "Spaghetti, gekocht · ca. 220 g · 345 kcal", "Bolognese-Soße · ca. 180 g · 270 kcal", "Parmesan · ca. 8 g · 35 kcal" und grünem Textlink "+ Bestandteil hinzufügen", darunter eine Zeile mit vier Spalten wie in Health: "650 kcal", "32 g Protein", "78 g Kohlenhydrate", "21 g Fett" in abgerundeten Ziffern. Keine bunten Farben außer dem Foto und dem einen Grün.

---

### 3.7 Barcode-Kamera (`/calories/scan`)

**Zweck.** Welches Produkt ist das? Über "Barcode scannen" (3.4), Avo-Feld-Menü, Steuerelement im Kontrollzentrum, Kurzbefehl, `shoply://calories/scan`.

**Aufbau (Vollbild-Push ohne Tab-Bar, Hintergrund #000000).**
1. Kamerabild randlos.
2. Oben Glasgruppe `clear`: links `chevron.left`, rechts `flashlight.off.fill` / `flashlight.on.fill` (Taschenlampe).
3. Mitte: Sucherrahmen 280 × 160 pt (bei 320 pt Breite 248 × 144), Ecken als 4-pt-Winkel in #FFFFFF mit `radiusCard` (20), außerhalb des Rahmens das Bild mit #000000 40 % abgedunkelt.
4. Unter dem Rahmen `labelOnPhoto` (`subheadline`): "Strichcode in den Rahmen halten".
5. Unten eine Glas-Kapsel `keyboard` "Nummer eingeben".

Glas: zwei Gruppen.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Erkannt | Der Rahmen springt mit `springQuick` auf die Umrisse des Codes und wird `action`-farben (dunkle Variante #A6D45F für Kontrast auf Kamerabild), die Ziffern "4 056489 123457" stehen 0,4 s unter dem Rahmen, leichter Impuls im selben Frame. Dann Push-Ersatz durch 3.8 (Produkt). |
| Sucht Produkt | unter dem Rahmen "4 056489 123457 · wird gesucht …" ohne Spinner; erst lokaler Produkt-Cache, dann Open Food Facts. Meist unter 1 s. |
| Nicht gefunden | Text unter dem Rahmen "Zu diesem Strichcode ist nichts bekannt." Die untere Glasgruppe wechselt (Morph `springMorph`) zu "Manuell eintragen" (getönt, öffnet 3.9 mit hinterlegtem Barcode, damit der nächste Scan das Produkt kennt) und "Erneut scannen". |
| Produkt ohne Nährwerte | weiter zu 3.8; dort die Sektion "Nährwerte fehlen" (Inv. 4.6 behoben). |
| Nummer eingeben | Ein Glas-Feld mit Ziffernblock sitzt auf der Tastatur (Muster wie `AddItemAccessory`, Platzhalter "13 Ziffern unter dem Strichcode"), Return sucht. Das Kamerabild bleibt dahinter. |
| Kamera nicht erlaubt | Vorab zentrierter Alert "Kamera für Strichcodes" / "Die Kamera liest nur den Strichcode. Es werden keine Bilder gespeichert." / "Nicht jetzt", "Weiter". Abgelehnt: Screen auf `bgGrouped` mit `StatusRow` "Kamera ist aus. In Einstellungen erlauben" und direkt das Ziffern-Feld (Rückfall). |
| Offline | `StatusRow`-ähnliche Zeile unter dem Rahmen (`labelOnPhoto`): "Offline. Nur schon gescannte Produkte werden erkannt." |
| Gerät ohne Kamera-Scanner-Unterstützung | direkt Ziffern-Feld. |

**Interaktionen.** Gesten außer Tippen keine; Zurück-Wischen vom Rand führt zu 3.4. Reduce Motion: Rahmen springt nicht, er blendet in die neue Farbe.

**Große Schrift, 320 pt.** Rahmen schrumpft auf 248 pt Breite; Texte brechen um; Glas-Knöpfe mit Large Content Viewer ab AX1.

**Was sich ändert.** Ersetzt den Barcode-Tab mit Zifferneingabe (`food_entry_sheet.dart:319-379`). Neu: `barcode_scanner_screen.dart`. Technik: Empfehlung VisionKit `DataScannerViewController` über einen nativen Kanal in Teil Bs Swift-Code (kein neues Paket, iOS 16+); Alternative `mobile_scanner` (in `pubspec.yaml:48` auskommentiert, laut CLAUDE.md nur nach Test wieder einschalten). Frage F-K6.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot einer randlosen Kameraansicht: eine Hand hält einen weißen Becher Skyr Natur mit blauem Etikett, der Strichcode ist im Bild. Der Bereich um einen querliegenden Rahmen in der Mitte ist leicht abgedunkelt, der Rahmen hat weiße, abgerundete Eckwinkel mit 20 pt Radius und hat sich auf den Strichcode gelegt, die Winkel leuchten hellgrün #A6D45F. Darunter in weißer Schrift #FFFFFF die Ziffern "4 056489 123457". Oben links ein runder klarer Liquid-Glass-Knopf mit Chevron, oben rechts einer mit Taschenlampen-Symbol; unten mittig eine Glas-Kapsel mit Tastatur-Symbol "Nummer eingeben". Keine Tab-Bar.

---

### 3.8 Menge (`/calories/add/food/:foodId`)

**Zweck.** Wie viel davon hast du gegessen? Nach Barcode, Suchtreffer oder "Andere Menge …" aus "Zuletzt gegessen". `foodId` = Barcode bzw. Open-Food-Facts-Code bzw. ID eines eigenen Lebensmittels.

**Aufbau (Push).**
1. `LargeTitleNavBar`: Zurück, Inline-Titel "Menge", rechts getönte Glas-Text-Kapsel "Eintragen".
2. **Sektion Produkt** (eine Zeile, Mindesthöhe 72): Produktfoto 56 pt auf weißer Unterlage (`radiusThumb`), Name (`headline`, bricht um) "Skyr Natur", Unterzeile "Milbona · 500-g-Becher", zweite Unterzeile "63 kcal pro 100 g".
3. **Sektion "Menge":**
   - Zeile: großes Zahlenfeld "250" (`numberL`, rechtsbündig vor der Einheit), daneben `ValueStepper` (±10 g; bei "Portion" ±0,5).
   - Zeile: Einheiten als `FilterChip`s (Einzelauswahl): "g", "Portion · 150 g", "Packung · 500 g" (Portion und Packung nur, wenn Open Food Facts sie nennt).
4. **Sektion "Nährwerte":** `NutritionRow` live: "158 kcal · 27,5 g Protein · 10 g Kohlenhydrate · 0,5 g Fett", alle Werte rollen bei jeder Änderung (`springDigits`).
5. **Sektion ohne Titel:** `ValueRow` "Mahlzeit" mit Wert "Snacks" (Menü), `ValueRow` "Datum" "Heute" (Menü 3.3).
6. Fuß (`footnote`, `labelSecondary`): "Nährwerte und Foto: Open Food Facts (ODbL, Foto CC BY-SA). Angaben können fehlen oder abweichen." mit Link.

Die Tastatur (Dezimal-Ziffernblock) ist beim Öffnen im Mengenfeld fokussiert; der Screen scrollt, sodass Feld und Nährwerte über der Tastatur stehen.

**Zustände.** Nährwerte fehlen: Sektion "Nährwerte fehlen" mit Satz "Für dieses Produkt sind keine Nährwerte hinterlegt. Trag sie von der Verpackung ein (pro 100 g)." und vier Zeilen-Felder kcal, Protein, Kohlenhydrate, Fett; "Eintragen" erst mit kcal aktiv. Die eingetragenen Werte werden als eigenes Lebensmittel gemerkt. Ungültige Menge: Hinweis unter dem Feld, Kapsel deaktiviert. Offline: funktioniert mit lokal bekannten Produkten vollständig. Foto lädt: Fläche in `fill`, Foto blendet ein (`fadeReduced`).

**Interaktionen.** Stepper: Auswahl-Haptik pro Schritt, Langdruck wiederholt. "Eintragen": Pop zurück ins Tagebuch (bzw. in 3.4, wenn man von dort kam und "Zuletzt gegessen" offen hatte: Rückkehr ins Tagebuch ist Standard), Zeile wächst ein, leichter Impuls, Rückgängig-Hinweis "Skyr Natur eingetragen · Widerrufen".

**Große Schrift, 320 pt.** Zahlenfeld und Stepper stapeln ab xxL (Stepper unter dem Feld, volle Breite). Chips brechen um. `NutritionRow` 2 × 2 bei 320 pt.

**Was sich ändert.** Ersetzt den Material-`AlertDialog` "Menge (g)" (`food_entry_sheet.dart:549-588`). Neu: `food_amount_screen.dart`. Lokaler Produkt-Cache (Teil B) für gescannte und eingetragene Produkte.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, oben links runder Glas-Zurück-Knopf, oben rechts eine grün getönte Glas-Kapsel #3F7A1F "Eintragen", mittig klein "Menge". Eine weiße Sektion mit einem kleinen Produktfoto eines Skyr-Bechers auf weißer Unterlage mit 12 pt Radius, daneben "Skyr Natur" in Halbfett, grau #636366 "Milbona · 500-g-Becher" und "63 kcal pro 100 g". Darunter eine Sektion "Menge" mit großer abgerundeter Zahl "250" und "g", rechts eine graue Stepper-Kapsel #E9E9EE mit Minus und Plus, darunter drei Kapsel-Chips "g" (gewählt, hellgrün #EEF5E4 mit grünem Text #3F7A1F und Häkchen), "Portion · 150 g", "Packung · 500 g" in Grau. Darunter vier Spalten wie in Health "158 kcal", "27,5 g Protein", "10 g Kohlenhydrate", "0,5 g Fett". Unten am Bildschirm der iOS-Dezimal-Ziffernblock. Graue Fußnote "Nährwerte und Foto: Open Food Facts".

---

### 3.9 Manuell (`/calories/add/manual`)

**Zweck.** Was und wie viele Kalorien? Für selbst Gekochtes ohne Rezept, Essen unterwegs, Produkte ohne Barcode.

**Aufbau (Push).**
1. `LargeTitleNavBar`: Zurück, großer Titel "Manuell", rechts getönte Kapsel "Eintragen" (aktiv, sobald Name und kcal gültig sind).
2. **Sektion:** Feld-Zeile "Name" (Platzhalter "Zum Beispiel Käsebrötchen"), Feld-Zeile "Kalorien" mit rechtsbündigem Zahlenfeld und Einheit "kcal". Darunter schlicht (ohne Symbol): "Kalorien schätzen lassen" (nur online, nur mit Name; füllt kcal und Makros als Vorschlag, Zeile bekommt den Fuß "geschätzt, bitte prüfen").
3. **Sektion "Nährwerte" (optional):** drei Zeilen untereinander "Protein", "Kohlenhydrate", "Fett", je rechts Zahlenfeld mit "g". Fuß: "Optional. Ohne Angabe zählen sie nicht zu den Tageswerten."
4. **Sektion "Menge" (optional):** Zahlenfeld und Einheiten-Chips "g", "ml", "Stück", "Portion".
5. **Sektion:** `ValueRow` "Mahlzeit", `ValueRow` "Datum".

**Beispielinhalt.** "Käsebrötchen vom Bäcker", 390 kcal, Protein 16 g, Kohlenhydrate 42 g, Fett 17 g, 1 Stück, Snacks.

**Zustände.** Ungültige Zahl: Hinweis unter dem Feld "Bitte eine Zahl, zum Beispiel 450 oder 450,5" (statt still deaktiviertem Button, Inv. 4.5). Offline: "Kalorien schätzen lassen" ausgeblendet. Ungespeichert verlassen: Alert "Eingaben verwerfen?" wie 3.6. Vorbefüllt aus Suche ("Nichts gefunden"), Barcode ("nicht gefunden", mit hinterlegtem Barcode) oder Avo.

**Interaktionen.** Return springt ins nächste Feld; "Eintragen" wie 3.8. Der Eintrag wird als eigenes Lebensmittel gemerkt (Sektion "Eigene" in der Suche).

**Große Schrift, 320 pt.** Alle Felder stehen untereinander mit Beschriftung links und Feld rechts; ab xxL steht die Beschriftung über dem Feld. Keine nebeneinander liegenden Makrofelder mehr (behebt Inv. 3, "Kohlenhydrate (g)" abgeschnitten).

**Was sich ändert.** Ersetzt `_ManualEntryForm` (`food_entry_sheet.dart:590-697`). Neu: `manual_food_screen.dart`.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links und grün getönte Glas-Kapsel #3F7A1F "Eintragen" oben rechts. Großer fetter Titel "Manuell". Eine weiße Sektion mit 26 pt Radius: Zeile "Name" mit Eingabe "Käsebrötchen vom Bäcker", Zeile "Kalorien" mit rechtsbündig "390 kcal", darunter ein grüner Textlink "Kalorien schätzen lassen". Sektion "Nährwerte" mit drei untereinander stehenden Zeilen "Protein 16 g", "Kohlenhydrate 42 g", "Fett 17 g", darunter graue Fußnote #636366 "Optional. Ohne Angabe zählen sie nicht zu den Tageswerten.". Sektion mit "Mahlzeit Snacks" und "Datum Heute", Werte grau mit kleinem Doppel-Chevron. Text schwarz #000000, dünne Trennlinien #C6C6C8 ab der Textkante.

---

### 3.10 Eintrag (`/calories/entry/:entryId`)

**Zweck.** Stimmt dieser Eintrag? Über Tippen auf eine Eintragszeile, Kontextmenü "Bearbeiten", Avo-Ergebniszeile "Ansehen".

**Aufbau (Push, Bearbeiten an Ort und Stelle, speichert automatisch).**
1. `LargeTitleNavBar`: Zurück, großer Titel = Name (bis 2 Zeilen), Toolbar `ellipsis` (Menü: "Heute nochmal eintragen", "Als eigenes Lebensmittel merken").
2. Foto (falls vorhanden) 4:3 oben in der ersten Sektion; darunter Name als Feld.
3. **Sektion:** "Menge" (Zahl, Stepper, Einheit), "Mahlzeit" (Menü), "Datum" (Menü 3.3), "Uhrzeit" (inline aufklappendes Rad).
4. **Sektion "Nährwerte":** Zeilen "Kalorien 650 kcal", "Protein 32 g", "Kohlenhydrate 78 g", "Fett 21 g", jeder Wert ein Feld.
5. **Fuß zur Quelle** (`footnote`, `labelSecondary`): "Geschätzt aus Foto, Sa., 7. Nov., 12:41" bzw. "Open Food Facts, Strichcode 4 056489 123457" bzw. "Aus dem Rezept Ofengemüse mit Feta, 1 Portion" (Link zum Rezept) bzw. "Von dir eingetragen".
6. **Sektion:** destruktive Zeile "Eintrag löschen" (`danger`).

**Zustände.** Änderungen werden beim Verlassen gespeichert (wie Erinnerungen); ein Rückgängig-Hinweis "Eintrag geändert · Widerrufen" erscheint im Tagebuch. Einträge aus Health gibt es nicht (Nahrung wird nicht gelesen). Offline: speichert in die Warteschlange. Fehler: `StatusRow` oben "Nicht gespeichert. Erneut versuchen". Eintrag wurde auf dem anderen Gerät gelöscht: Pop zurück ohne Fehlermeldung (00 13).

**Interaktionen.** "Eintrag löschen": sofort, Pop zurück, die Zeile im Tagebuch schrumpft weg (`springStandard`), Rückgängig-Hinweis. Kein Alert.

**Große Schrift, 320 pt.** wie 3.9.

**Was sich ändert.** Neu (heute gibt es kein Bearbeiten, Inv. 2.2). Neu: `food_entry_detail_screen.dart`, Service-Methode `updateEntry`. Health-Wert wird über die externe Kennung ersetzt.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links und runder Glas-Knopf mit drei Punkten oben rechts. Großer fetter Titel "Spaghetti Bolognese". Eine weiße Sektion mit 26 pt Radius, oben randlos ein Foto des Tellers, darunter Zeilen "Menge 1 Teller", "Mahlzeit Mittagessen", "Datum Heute", "Uhrzeit 12:41". Sektion "Nährwerte" mit "Kalorien 650 kcal", "Protein 32 g", "Kohlenhydrate 78 g", "Fett 21 g", Werte in abgerundeten Ziffern rechts. Graue Fußnote #636366 "Geschätzt aus Foto, Sa., 7. Nov., 12:41" und darunter eine eigene weiße Sektion mit rotem Text #D70015 "Eintrag löschen". Unten die Liquid-Glass-Tab-Bar.

---

### 3.11 Rezept ins Tagebuch (`/calories/add/recipe/:recipeId`)

**Zweck.** Wie viele Portionen, zu welcher Mahlzeit? Über das Rezeptdetail (Toolbar-Menü `ellipsis` > "Ins Tagebuch eintragen", nur mit Modul; Ort legt Kapitel 13 fest), "Heute im Plan" (3.4), Ideen (3.21), Wochenplan-Tag (Kontextmenü "Ins Tagebuch").

**Aufbau (Push im Stapel des aufrufenden Tabs).**
1. `LargeTitleNavBar`: Zurück, Inline-Titel "Ins Tagebuch", rechts getönte Kapsel "Eintragen".
2. **Sektion Rezept:** Rezept-Zeile (Thumbnail 56 pt `radiusThumb`, "Ofengemüse mit Feta" `headline`, "520 kcal pro Portion").
3. **Sektion:** `ValueStepper` "Portionen" (0,5 bis 20 in 0,5er-Schritten, Wert "1"), `ValueRow` "Mahlzeit" (vorausgewählt nach Uhrzeit, aus dem Wochenplan: der Plan-Tag und Abendessen), `ValueRow` "Datum" (Standard heute; vom Wochenplan: der Plan-Tag, sofern nicht in der Zukunft).
4. **Sektion "Nährwerte":** `NutritionRow` live "520 kcal · 21 g Protein · 48 g Kohlenhydrate · 27 g Fett", Fuß "pro gewählter Menge, aus dem Rezept" bzw. "geschätzt", wenn die Rezept-Nährwerte geschätzt sind.

**Zustände.** Rezept ohne Nährwerte: Sektion "Nährwerte fehlen" mit Satz "Für dieses Rezept sind keine Nährwerte hinterlegt." und schlicht "Kalorien schätzen lassen" (online) bzw. Feld "Kalorien pro Portion". Zukunftsdatum aus dem Plan: Datum steht auf heute, Fuß "Geplant für Mo., 9. Nov. Eintragen kannst du ab dem Tag selbst." Offline: funktioniert (Rezept liegt lokal).

**Interaktionen.** Stepper: Auswahl-Haptik, Zahlen rollen. "Eintragen": Pop zum Rezept, leichter Impuls, Rückgängig-Hinweis "Ofengemüse mit Feta eingetragen · Widerrufen". Der bisherige Maskottchen-Meilenstein "proteinreiche Mahlzeit" entfällt hier (Maskottchen nicht in Arbeits-Screens); die Zahl steht im Wochenrückblick.

**Große Schrift, 320 pt.** Stepper unter dem Label ab xxL; `NutritionRow` 2 × 2.

**Was sich ändert.** Ersetzt `widgets/log_recipe_sheet.dart` (Sheet, Standard immer Abendessen und heute, Inv. 4.3; `Wrap` ohne Zeilenabstand; `maxLines: 1` am Rezeptnamen). Neu: `log_recipe_screen.dart`. Die Route liegt in B's `calories_routes`, damit Teil A im Rezeptdetail nur `context.push('/calories/add/recipe/$id')` aufruft.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf und grün getönte Glas-Kapsel #3F7A1F "Eintragen". Eine weiße Sektion mit einem quadratischen Rezeptfoto (Ofengemüse mit Feta auf einem Blech) mit 12 pt Radius, daneben "Ofengemüse mit Feta" in Halbfett und grau "520 kcal pro Portion". Darunter eine Sektion mit "Portionen" und einer grauen Stepper-Kapsel #E9E9EE "− 1 +", "Mahlzeit Abendessen", "Datum Heute". Darunter vier Spalten "520 kcal", "21 g Protein", "48 g Kohlenhydrate", "27 g Fett" in abgerundeten Ziffern und eine graue Fußnote "pro gewählter Menge, aus dem Rezept". Text schwarz #000000, ruhig, keine Karten.

---

### 3.12 Wasser (Zeile, Menü, Alert)

**Zweck.** Habe ich genug getrunken? Teil der Tagebuch-Wurzel, kein eigener Screen.

**Aufbau.** Siehe 3.1 Punkt 7. Die Kapsel "+250 ml" nutzt die Schnelltaste aus 3.23 (Standard 250 ml).

**Interaktionen.**
- Tippen "+250 ml": Wert rollt (`springDigits`) von "1,25" auf "1,5", Balken folgt, leichter Impuls, Rückgängig-Hinweis "250 ml Wasser · Widerrufen". Gilt für den angezeigten Tag (behebt Inv. 4.2, heute immer "heute").
- Langdruck auf die Kapsel oder die Zeile: Kontextmenü "+150 ml", "+330 ml", "+500 ml", "Andere Menge …", Trenner, "Letzten Eintrag entfernen (250 ml, 16:10)" (`danger`, mit Rückgängig).
- "Andere Menge …": zentrierter Alert mit Zahlenfeld "Menge in ml", "Abbrechen" / "Hinzufügen".
- Ziel erreicht (2 l): Zeile zeigt "2 l von 2 l" und `checkmark.circle.fill` in `health` hinter der Zahl; kein Erfolgsmoment (zu klein für eine Feier).

**Zustände.** Aus Health gelesenes Wasser anderer Apps zählt mit; die Unterzeile nennt es: "davon 0,5 l aus Health". Offline: Warteschlange, Sync-Zeichen hinter der Zahl. Kein Wasserziel gesetzt: "1,25 l" ohne "von", kein Balken.

**Große Schrift, 320 pt.** Kapsel unter dem Text ab xxL bei 320 pt und ab AX1 bei allen Breiten.

**VoiceOver.** "Wasser, 1,25 von 2 Litern", Aktionen "250 Milliliter hinzufügen", "Andere Menge", "Letzten Eintrag entfernen".

**Was sich ändert.** Ersetzt `water_tracker_card.dart` (feste Blaufarbe `0xFF5B9BD5`, drei Chips mit ca. 37 pt, abweichender Außenrand). Wasserziel wird einstellbar (Inv. 4.8).

**Bildbeschreibung für ChatGPT.** Ausschnitt einer weißen inset-gruppierten Sektion mit 26 pt Radius auf #F2F2F7 im Apple-Stil iOS 27: Titel "Wasser" darüber in Halbfett. In der Zeile links ein blaues Tropfen-Symbol, daneben "1,25 l von 2 l" in schwarzen abgerundeten Ziffern #000000, darunter ein dünner Balken über die Textbreite, zu 62 % in Avocado-Grün #3F7A1F auf Grau #E9E9EE. Rechts eine kleine graue Kapsel #E9E9EE mit schwarzem Text "+250 ml". Darunter schwebt eine Liquid-Glass-Kapsel "250 ml Wasser · Widerrufen" mit grünem "Widerrufen".

---

### 3.13 Ziele (`/calories/goals`)

**Zweck.** Was ist mein Tagesziel? Über "Ziele" in 3.1, `/settings/health`, Avo ("Setz mein Ziel auf 1.800 kcal").

**Aufbau (Push).**
1. `LargeTitleNavBar` "Ziele".
2. **Sektion "Pro Tag":** `ValueRow`s "Kalorien 2.000 kcal", "Protein 133 g", "Kohlenhydrate 227 g", "Fett 62 g", "Wasser 2 l". Tippen auf eine Zeile öffnet sie an Ort und Stelle: Zahlenfeld und `ValueStepper` (kcal ±50, Makros ±5 g, Wasser ±0,25 l), Return schließt. Fuß: "Berechnet am 2. Nov. aus deinen Angaben. Tippe auf einen Wert, um ihn selbst festzulegen."
3. **Sektion "Dein Ziel":** `ValueRow` "Ziel" "Abnehmen", `ValueRow` "Zielgewicht" "70,0 kg · etwa Ende Feb.", `ValueRow` "Alltag" "Leicht aktiv", `NavRow` "Neu berechnen" → 3.14.
4. **Sektion "Workouts":** `ToggleRow` "Verbrauch durch Workouts gutschreiben" (aus). Fuß: "Dann steigt dein Tagesbudget um die geschätzten Kalorien deiner Workouts."
5. **Sektion:** `NavRow` `heart` "Apple Health" · "Verbunden" → 3.23 (bzw. "Nicht verbunden" → 3.22).
6. Fuß der Seite: "Richtwerte, kein ärztlicher Rat."

**Zustände.** Eigener Wert gesetzt: Fuß "Eigene Werte. Neu berechnen" (schlicht), Ziel-Typ zeigt "Eigene Werte" (behebt Inv. 4.8, "Individuell" ohne Eingaben). Kalorien unter 1.200: Warnzeile in `warning` mit Symbol "Unter 1.200 kcal am Tag ist ohne ärztliche Begleitung nicht zu empfehlen." (Wert wird trotzdem gespeichert, Agency). Makros passen nicht zu den kcal (Abweichung über 10 %): Fuß "Deine Makros ergeben 1.720 kcal, dein Ziel ist 2.000." (keine Sperre). Offline: speichert in die Warteschlange. Kein Ziel: Route öffnet direkt 3.14.

**Interaktionen.** Änderungen gelten sofort und rollen im Tagebuch nach; Rückgängig-Hinweis "Kalorienziel geändert · Widerrufen". Stepper mit Auswahl-Haptik.

**Große Schrift, 320 pt.** Wert unter dem Titel ab AX1; Stepper unter dem Feld ab xxL.

**Was sich ändert.** Neu als Übersicht (heute führt das Tune-Icon direkt in den Fragebogen). Neu: `goals_screen.dart`; Feld `credit_workouts` in `nutrition_goals` (Migration Teil B).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27 wie die Health-App, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links, großer fetter Titel "Ziele". Sektion "Pro Tag" als weiße Fläche mit 26 pt Radius: "Kalorien 2.000 kcal", "Protein 133 g", "Kohlenhydrate 227 g", "Fett 62 g", "Wasser 2 l", Werte grau #636366 rechtsbündig in abgerundeten Ziffern; darunter graue Fußnote. Sektion "Dein Ziel" mit "Ziel Abnehmen", "Zielgewicht 70,0 kg · etwa Ende Feb.", "Alltag Leicht aktiv" und einer Zeile "Neu berechnen" mit Chevron. Sektion mit Schalter "Verbrauch durch Workouts gutschreiben" (aus, grauer Schalter) und Sektion mit Herz-Symbol "Apple Health Verbunden". Schwarzer Text #000000, keine Karten, keine bunten Farben.

---

### 3.14 Ziel berechnen (`/calories/goals/setup`)

**Zweck.** Was brauche ich für mein Ziel täglich? Über 3.2 "Ziel einrichten", 3.13 "Neu berechnen". Das Onboarding (Kapitel 17, Teil A) bettet dasselbe Formular `GoalForm` ein (7.3), damit es nur noch einen Fragebogen gibt (heute zwei, Inv. 5).

**Aufbau (Push, ein Formular, kein Assistent mit Schritten).**
1. `LargeTitleNavBar`: Zurück, großer Titel "Ziel berechnen", rechts getönte Kapsel "Übernehmen" (aktiv, sobald Alter, Größe und Gewicht gültig sind). Eingeklappt zeigt der Inline-Titel "Ziel · 2.000 kcal" (Zahl rollt mit).
2. **Sektion "Ergebnis"** (oben, live): "2.000" `numberXL` "kcal am Tag", darunter `NutritionRow` "133 g Protein · 227 g Kohlenhydrate · 62 g Fett", Zeile "Wasser 2 l". Fuß: "Berechnet nach Mifflin-St Jeor aus deinen Angaben. Richtwerte, kein ärztlicher Rat." Solange Angaben fehlen: "–" statt Zahl und Fuß "Alter, Größe und Gewicht fehlen noch."
3. **Sektion "Ziel":** drei Auswahlzeilen mit `checkmark` links bei der gewählten: "Abnehmen", "Gewicht halten", "Muskeln aufbauen".
4. **Sektion "Über dich":** `ValueRow` "Geschlecht" (Menü: Weiblich, Männlich, Divers), Feld-Zeilen "Alter 34 Jahre", "Größe 176 cm", "Gewicht 74,0 kg". Mit Health: Fuß "Größe und Gewicht aus Apple Health."
5. **Sektion "Zielgewicht"** (nur Abnehmen und Muskeln aufbauen): Feld "Zielgewicht 70,0 kg", `SegmentedControl` "Gemütlich · Normal · Zügig" (0,25 / 0,5 / 0,75 kg pro Woche beim Abnehmen; 0,1 / 0,25 / 0,4 beim Aufbauen), darunter `subheadline` `label`: "Etwa 0,5 kg pro Woche. Zielgewicht etwa Ende Februar."
6. **Sektion "Alltag":** Auswahlzeilen mit Unterzeile: "Meist sitzend" · "Büro, wenig Sport"; "Leicht aktiv" · "1 bis 3 Mal Sport pro Woche"; "Mäßig aktiv" · "3 bis 5 Mal pro Woche"; "Sehr aktiv" · "6 bis 7 Mal pro Woche"; "Extrem aktiv" · "Körperliche Arbeit und Sport".
7. Fuß der Seite: "Alter, Größe und Geschlecht werden in deinen persönlichen Daten gespeichert und nur für diese Berechnung verwendet."

**Beispielinhalt.** Weiblich, 34, 176 cm, 74,0 kg, Ziel 70,0 kg, Normal, Leicht aktiv → 2.000 kcal (Werte aus 1.3).

**Zustände.**
- Widersprüchlich: "Abnehmen" mit Zielgewicht über dem Gewicht → Warnzeile unter dem Feld "Das Zielgewicht liegt über deinem Gewicht. Meinst du „Muskeln aufbauen“?" mit schlicht "Wechseln"; "Übernehmen" deaktiviert (behebt Inv. 4.9).
- Ergebnis an der Untergrenze (1.200 bzw. 1.500): Fuß "Für ein schnelleres Tempo müsstest du unter {floor} kcal essen. Wir rechnen nicht darunter." (Zahl aus der Rechnung)
- Divers: rechnet mit dem Mittelwert beider Formeln (Frage F-K7).
- Offline: alles lokal, Speichern in die Warteschlange.
- Ungespeichert verlassen: Alert "Änderungen verwerfen?".

**Interaktionen.** Jede Änderung rollt das Ergebnis (`springDigits`), ohne Haptik. "Übernehmen": Pop zu 3.13 bzw. ins Tagebuch (bei Ersteinrichtung), Werte rollen dort; Gewicht wird nur geloggt, wenn es sich geändert hat (Inv. 6); mit Health wird das Gewicht geschrieben. Bei Ersteinrichtung kein Erfolgsmoment (Formular, keine Leistung).

**Große Schrift, 320 pt.** Segmente "Gemütlich · Normal · Zügig" passen bei 320 pt bis L; darüber Pull-down. Ergebnis-Zahl max. 51 pt. Felder einspaltig (behebt zwei Felder nebeneinander, Inv. 3).

**Was sich ändert.** Ersetzt `goal_setup_screen.dart` (Material-`AppBar`, Vollbild-Spinner, `Slider` 4 bis 52 Wochen, keine Vorschau, rohe Exception im Fehlertext, Inv. 2.4, 4.15) und die Formular-Kopie in `onboarding/widgets/onboarding_goal_page.dart` (Teil A ersetzt sie durch `GoalForm`). `NutritionGoalCalculator` bekommt Tempo in kg pro Woche statt Wochen; die bestehende Begrenzung der Tagesänderung (200 bis 1.000 kcal) bleibt.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links, grün getönte Glas-Kapsel #3F7A1F "Übernehmen" oben rechts, großer fetter Titel "Ziel berechnen". Erste weiße Sektion "Ergebnis": groß in abgerundeten Ziffern "2.000" und "kcal am Tag", darunter vier Spalten "133 g Protein", "227 g Kohlenhydrate", "62 g Fett", eine Zeile "Wasser 2 l" und eine graue Fußnote #636366 "Berechnet nach Mifflin-St Jeor aus deinen Angaben. Richtwerte, kein ärztlicher Rat.". Sektion "Ziel" mit drei Zeilen, "Abnehmen" mit grünem Häkchen links. Sektion "Über dich" mit "Geschlecht Weiblich", "Alter 34 Jahre", "Größe 176 cm", "Gewicht 74,0 kg". Sektion "Zielgewicht" mit "70,0 kg" und einer grauen Segment-Kapsel "Gemütlich · Normal · Zügig" mit "Normal" auf weißem Daumen, darunter "Etwa 0,5 kg pro Woche. Zielgewicht etwa Ende Februar.". Kein Schieberegler.

---

### 3.15 Woche (`/calories/week`)

**Zweck.** Wie lief meine Woche? Über die Sektion "Diese Woche" in 3.1, Avo, Mitteilung "Dein Wochenrückblick" (falls eingeschaltet, Kapitel 19).

**Aufbau (Push).**
1. `LargeTitleNavBar` "Woche", Datumszeile darunter "2.–8. Nov." Toolbar oben rechts: Glasgruppe `chevron.left` / `chevron.right` (vorige / nächste Woche; nächste nur bis zur aktuellen).
2. **Sektion "Kalorien":** "Ø 1.925" `numberXL` "kcal", Unterzeile "an 4 abgeschlossenen Tagen · Ziel 2.000 · Vorwoche Ø 2.040". `BarChart` Mo bis So in `health`, Ziellinie gestrichelt, heute fett beschriftet, Mi und So leer.
3. **Sektion "Auf Kurs"** (Zeilen mit Wert rechts, kein Chevron): "Im Ziel" · "4 von 4 Tagen"; "Protein erreicht" · "2 von 4 Tagen"; "Erfasst in Folge" · "5 Tage" (nur ab 2); "Gekocht" · "3 Mahlzeiten, 2 proteinreich" (nur mit Rezept-Einträgen).
4. **Sektion "Makros pro Tag":** drei Zeilen wie im Tagebuch, Werte als Ø über erfasste Tage ("Protein Ø 96 von 133 g").
5. **Sektion "Wasser":** "Ø 1,6 l an 5 Tagen".
6. **Sektion:** `NavRow` "Gewicht" · "72,4 kg · −0,3 kg seit Mi." → 3.16; `NavRow` "Workouts" · "3 · 1 Std. 40 Min" → 3.17.

**Zustände.** Keine Daten: `BarChart`-Satz "Noch keine Woche erfasst." und nur Sektion "Kalorien". Laufende Woche: heute zählt erst morgen in Ø und "Im Ziel" (Fuß "Heute zählt ab morgen mit."). Gewicht mit nur einer Wiegung: Zeile "72,4 kg" ohne Veränderung (Inv. 6). Offline: lokaler Stand, ältere Wochen ohne Cache zeigen `StatusRow`. Pro (falls F-K2 "Statistiken"): aktuelle Woche frei, `chevron.left` zu älteren Wochen trägt `ProBadge` und öffnet die Paywall aus dem Knopf.

**Interaktionen.** Wischen waagerecht über das Diagramm wechselt die Woche (1:1, `springFling`, Auswahl-Haptik). Tippen auf einen Balken öffnet das Tagebuch dieses Tages (Pop zur Wurzel, Tag gesetzt). Ziehen über das Diagramm zeigt Werte.

**Große Schrift, 320 pt.** Werte unter Titeln ab AX1; Achsen ab AX1 als Textzeile (00 5.3).

**Was sich ändert.** Ersetzt `weekly_summary_screen.dart` (Material-`AppBar`, Karten, `_WeekBars` mit fester Höhe 96 und 9-pt-Zahlen, Regenbogen-Makros, `AppEmptyState` im getönten Kreis). Woche = Kalenderwoche Mo bis So (wie Wochenplan) statt "letzte 7 Tage". Die dokumentierte Semantik aus `weekly_nutrition_summary.dart:10-24` bleibt. Abfragen nur Summen (Inv. 4.23).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27 wie die Health-App, Hintergrund #F2F2F7, oben links runder Glas-Zurück-Knopf, oben rechts eine Glas-Kapsel mit zwei Chevrons links und rechts. Großer fetter Titel "Woche", darunter grau "2.–8. Nov.". Weiße Sektion mit groß "Ø 1.925" und "kcal" in abgerundeten Ziffern, darunter grau #636366 "an 4 abgeschlossenen Tagen · Ziel 2.000 · Vorwoche Ø 2.040" und ein Balkendiagramm mit sieben Spalten Mo bis So in Avocado-Grün #3F7A1F, Mi und So leer, eine gestrichelte graue Ziellinie, "Sa" fett. Sektion "Auf Kurs" mit Zeilen "Im Ziel 4 von 4 Tagen", "Protein erreicht 2 von 4 Tagen", "Erfasst in Folge 5 Tage", "Gekocht 3 Mahlzeiten, 2 proteinreich". Nur eine Farbe im Diagramm, keine Karten.

---

### 3.16 Gewicht (`/calories/weight`)

**Zweck.** Wie entwickelt sich mein Gewicht? Über "Gewicht" in 3.1, Woche, Avo ("Ich wiege heute 72,4").

**Aufbau (Push).**
1. `LargeTitleNavBar` "Gewicht", Toolbar `plus` ("Gewicht eintragen").
2. **Sektion Zusammenfassung:** "72,4" `numberXL` "kg", Unterzeile "Sa., 7. Nov. · −1,6 kg seit 2. Okt. · Ziel 70,0 kg".
3. **Sektion Verlauf:** `SegmentedControl` "Monat · 3 Monate · Jahr · Alle" (Standard 3 Monate), darunter `LineChart` 180 pt (Mindesthöhe; wächst mit der Achsenschrift): Linie 2 pt in `health`, Punkte je Wiegung, x-Achse nach Datum (Lücken bleiben Lücken, behebt Inv. 4.12), Ziellinie 70,0 gestrichelt in `labelSecondary`.
4. **Sektion "Einträge":** Zeilen "72,4 kg" (`number`) mit Unterzeile "Sa., 7. Nov."; "72,7 kg" "Mi., 4. Nov."; "73,0 kg" "Sa., 31. Okt. · Withings" (aus Health); "73,4 kg" "Mi., 28. Okt."; "74,0 kg" "Fr., 2. Okt.". Neueste oben, alle Einträge (seitenweise nachgeladen beim Scrollen).

**Zustände.**
- Neuer Eintrag (`plus`): Eine neue Zeile wächst oben in "Einträge" ein (`springStandard`), im Bearbeiten-Zustand: Zahlenfeld fokussiert (Dezimal-Ziffernblock), Datum "Heute" (Taste, Menü 3.3). Return speichert, die Zeile setzt sich, Zahl oben rollt, Linie verlängert sich, leichter Impuls, Health wird geschrieben.
- Gleicher Tag schon vorhanden: ersetzt, Rückgängig-Hinweis "Gewicht für heute ersetzt (vorher 72,6 kg) · Widerrufen".
- Unter zwei Einträgen: kein Diagramm, nur die Zahl und der Satz "Ab zwei Einträgen siehst du hier den Verlauf."
- Leer: `EmptyState` Symbol `scalemass` 48 pt "Noch kein Gewicht eingetragen." prominent "Gewicht eintragen".
- Einträge anderer Apps (Health): ohne Wischaktion; Fuß der Sektion "Einträge anderer Apps änderst du in Health."
- Offline: Warteschlange, Sync-Zeichen.
- Unplausibel (Änderung über 3 kg zum letzten Eintrag binnen 2 Tagen): Hinweis unter dem Feld "Das sind 3,4 kg mehr als am Mittwoch. Stimmt das?" mit "Speichern" bleibt möglich.

**Interaktionen.** Tippen auf eine eigene Zeile: Bearbeiten an Ort und Stelle (Wert und Datum). Wischen nach links: "Löschen", Rückgängig-Hinweis; Health-Wert wird mitgelöscht. Segment wechselt den Zeitraum; die Linie morpht mit `springStandard`. Ziehen über die Linie zeigt "Mi., 4. Nov.: 72,7 kg", Auswahl-Haptik pro Punkt.

**Große Schrift, 320 pt.** Achsen bis xxxL, darüber entfallen sie (Werte stehen ohnehin in "Einträge"). Segmente bei 320 pt "Monat · 3 M. · Jahr · Alle"; ab xxL Pull-down.

**Was sich ändert.** Ersetzt `weight_tracking_screen.dart` und `widgets/weight_chart.dart` (nur heute, keine Liste, kein Löschen, x nach Index, Repaint ignoriert Hell/Dunkel, Inv. 4.12, 4.26). Neu: Datumswahl, Bearbeiten, Löschen, Health. `weight_log_service.dart` bekommt `delete` und `upsert(date)`.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27 wie Health, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links, runder Glas-Knopf mit Plus oben rechts, großer fetter Titel "Gewicht". Weiße Sektion mit groß "72,4" und "kg" in abgerundeten Ziffern, darunter grau #636366 "Sa., 7. Nov. · −1,6 kg seit 2. Okt. · Ziel 70,0 kg". Darunter eine Sektion mit grauer Segment-Kapsel "Monat · 3 Monate · Jahr · Alle" ("3 Monate" gewählt) und einem Liniendiagramm, das in Avocado-Grün #3F7A1F von 74,0 auf 72,4 sinkt, mit kleinen Punkten je Wiegung und einer gestrichelten grauen Ziellinie bei 70,0. Sektion "Einträge" mit Zeilen "72,4 kg / Sa., 7. Nov.", "72,7 kg / Mi., 4. Nov.", "73,0 kg / Sa., 31. Okt. · Withings". Eine Farbe, keine Karten.

---

### 3.17 Workouts (`/calories/workouts`)

**Zweck.** Wie viel habe ich mich bewegt? Über "Workouts" in 3.1, Woche, Avo ("Ich war 30 Minuten laufen").

**Aufbau (Push).**
1. `LargeTitleNavBar` "Workouts", Toolbar `plus` ("Workout eintragen").
2. **Sektion "Diese Woche":** "1 Std. 40 Min" `numberXL`, Unterzeile "3 Workouts · ca. 820 kcal". `BarChart` Minuten pro Tag Mo bis So in `health`.
3. **Sektionen pro Tag** (neueste oben, Titel "Heute", "Do., 5. Nov.", "Di., 3. Nov."): Zeilen mit Symbol der Art (17 pt, `labelSecondary`), Titel "Laufen", Unterzeile "18:05 · 32 Min · Apple Watch", rechts "280" `number` "kcal". Eigene Einträge ohne Quellenangabe bzw. "Von dir eingetragen" nur in 3.18.
4. Fuß bei Health: "Workouts von Apple Watch und anderen Apps kommen aus Apple Health."

**Beispielinhalt.** Heute: Laufen 32 Min 280 kcal (Apple Watch). Do., 5. Nov.: Krafttraining 45 Min ca. 260 kcal (eingetragen). Di., 3. Nov.: Radfahren 23 Min 280 kcal (Apple Watch).

**Zustände.** Leer ohne Health: `EmptyState` Symbol `figure.run` 48 pt "Noch keine Workouts." Satz "Trag ein Workout ein oder verbinde Apple Health, dann erscheinen die Workouts deiner Apple Watch hier." prominent "Workout eintragen", schlicht "Mit Apple Health verbinden" (→ 3.22). Health abgelehnt: `StatusRow` "Apple Health ist nicht erlaubt. In Health erlauben" (Link öffnet die Health-App-Einstellungen). Offline: eigene Einträge in der Warteschlange; Health-Workouts sind ohnehin lokal. Pro (falls F-K2): Liste frei; das Schreiben nach Health gehört zu "Apple Health" (siehe 3.22).

**Interaktionen.** Tippen auf ein eigenes Workout → 3.18; auf ein Health-Workout → 3.18 im Nur-Lesen-Zustand mit schlicht "In Health öffnen". Wischen nach links auf eigene: "Löschen" mit Rückgängig.

**Große Schrift, 320 pt.** kcal unter die Unterzeile ab AX1; Diagramm-Achsen wie 3.15.

**Was sich ändert.** Neu (Plan 9: Workouts sind neu). Neu: `workouts_screen.dart`, `workout_log_service.dart`, Tabelle `workout_log` (Migration Teil B, siehe 7.4).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27 wie die Fitness-Übersicht in Health, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf und runder Glas-Plus-Knopf oben, großer fetter Titel "Workouts". Weiße Sektion "Diese Woche" mit groß "1 Std. 40 Min" in abgerundeten Ziffern, grau #636366 "3 Workouts · ca. 820 kcal" und einem kleinen Balkendiagramm Mo bis So in Avocado-Grün #3F7A1F. Sektion "Heute" mit einer Zeile: graues Läufer-Symbol, "Laufen", grau "18:05 · 32 Min · Apple Watch", rechts "280 kcal". Sektionen "Do., 5. Nov." mit "Krafttraining · 45 Min · ca. 260 kcal" und "Di., 3. Nov." mit "Radfahren · 23 Min · 280 kcal". Schwarzer Text #000000, keine bunten Ringe, keine Karten.

---

### 3.18 Workout eintragen / bearbeiten (`/calories/workouts/new`, `/calories/workouts/:id`)

**Zweck.** Was habe ich trainiert?

**Aufbau (Push).**
1. `LargeTitleNavBar`: Zurück, Inline-Titel "Workout", rechts getönte Kapsel "Sichern" (nur bei neu; bearbeiten speichert beim Verlassen wie 3.10).
2. **Sektion:** `ValueRow` "Art" mit Symbol und Name (Menü mit Symbolen: Laufen `figure.run`, Gehen `figure.walk`, Radfahren `figure.outdoor.cycle`, Schwimmen `figure.pool.swim`, Krafttraining `figure.strengthtraining.traditional`, Yoga `figure.yoga`, Intervalltraining `figure.highintensity.intervaltraining`, Wandern `figure.hiking`, Tanzen `figure.dance`, Sonstiges `figure.mixed.cardio`; Rückfälle vor iOS 17 laut 00 9.2). `ValueRow` "Beginn" "Heute, 18:05" (klappt an Ort und Stelle ein Rad für Datum und Uhrzeit auf).
3. **Sektion:** `ValueStepper` "Dauer" in 5-Minuten-Schritten "30 Min" (Feld für genaue Minuten), `SegmentedControl` "Intensität" "Leicht · Mittel · Hart".
4. **Sektion:** `ValueRow` "Kalorien" "ca. 280 kcal" mit Fuß "Geschätzt aus Art, Dauer, Intensität und deinem Gewicht (72,4 kg). Du kannst den Wert ändern." Tippen öffnet ein Zahlenfeld.
5. Bei bearbeiten: destruktive Zeile "Workout löschen".

**Zustände.** Kein Gewicht bekannt: Schätzung mit 70 kg und Fuß "Mit deinem Gewicht wird die Schätzung genauer." Health-Workout (Nur-Lesen): alle Werte als Text, Fuß "Aus Apple Health · Apple Watch", schlicht "In Health öffnen", keine Kapsel, kein Löschen. Ungespeichert verlassen (neu): Alert "Workout verwerfen?".

**Interaktionen.** Werte ändern die Schätzung rollend. "Sichern": Pop, Zeile wächst in "Heute" ein, leichter Impuls, Rückgängig-Hinweis "Krafttraining eingetragen · Widerrufen"; mit Health: als Workout geschrieben.

**Große Schrift, 320 pt.** Segmente bei 320 pt passen bis L, darüber Pull-down. Rad-Auswahl bleibt in voller Breite.

**Was sich ändert.** Neu. Datei `workout_edit_screen.dart`. Die kcal-Schätzung ist lokal (MET-Tabelle pro Art und Intensität × kg × Stunden), keine KI.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links und grün getönte Glas-Kapsel #3F7A1F "Sichern" oben rechts, mittig klein "Workout". Weiße Sektion mit "Art" und rechts grauem Hantel-Symbol und "Krafttraining", "Beginn Do., 5. Nov., 18:30". Sektion mit "Dauer" und grauer Stepper-Kapsel #E9E9EE "− 45 Min +" und einer Segment-Kapsel "Leicht · Mittel · Hart" mit "Mittel" gewählt. Sektion "Kalorien ca. 260 kcal" mit grauer Fußnote #636366 "Geschätzt aus Art, Dauer, Intensität und deinem Gewicht (72,4 kg). Du kannst den Wert ändern.". Schwarzer Text, keine Schieberegler.

---

### 3.19 Challenges (`/calories/challenges`)

**Zweck.** Halte ich meine Challenge heute ein? Über "Challenges" in 3.1, Mitteilung "Check-in" (falls eingeschaltet), Avo.

**Aufbau (Push).**
1. `LargeTitleNavBar` "Challenges".
2. **Pro aktiver Challenge eine Sektion** mit Titel "16:8 Intervallfasten":
   - Zeile: "Tag 5" `numberL`, Unterzeile "seit Di., 3. Nov. · 4 von 4 Tagen geschafft".
   - Zeile Tagesreihe: je Tag ein 12-pt-Kreis (gefüllt `health` = geschafft, Ring `controlOutline` = nicht geschafft mit `xmark` 8 pt, Ring gestrichelt = offen), die letzten 14 Tage, heute rechts. Bei 30-Tage-Challenges: 30 Kreise in zwei Reihen.
   - Zeile Check-in: Frage "Heute geschafft?" (`body`), darunter nebeneinander prominent "Geschafft" und grau "Heute nicht". Nach dem Check-in ersetzt durch "Heute: geschafft" mit `checkmark.circle.fill` in `health` und schlicht "Ändern".
   - Sektionsfuß mit schlichten Aktionen: "Beenden" (bei 16:8, ohne festes Ende; speichert als abgeschlossen mit Rückgängig) und "Abbrechen" (`danger`, Bestätigung, 00 12.34).
3. **Sektion "Starten":** Zeilen mit `plus.circle` rechts: "16:8 Intervallfasten" · "16 Stunden nichts essen, 8 Stunden Essenszeit. Läuft, bis du sie beendest."; "30 Tage ohne Zucker" · "Kein zugesetzter Zucker, 30 Tage lang."; `NavRow` "Eigene Challenge" → 3.20. Aktive Typen sind ausgeblendet.
4. **Sektion "Abgeschlossen":** "30 Tage ohne Zucker" · "1.–30. Okt. · 26 von 30 Tagen"; abgebrochene mit "abgebrochen nach 9 Tagen".
5. Fuß der Seite: "Challenges sind freiwillig. Ein verpasster Tag beendet nichts."

**Zustände.** Keine aktive: Sektion 2 entfällt, oben `EmptyState` klein (Symbol `flag` 48 pt) "Eine Gewohnheit üben?" Satz "Wähle unten eine Challenge. Du hakst jeden Tag ab, ob es geklappt hat." Abgelaufene feste Challenge: erscheint beim nächsten Öffnen in "Abgeschlossen" (Abschluss serverseitig per Zeitplan, nicht beim Lesen, Inv. 4.11). Offline: Check-in in die Warteschlange. Zwei Geräte gleichzeitig: Check-ins pro Tag als eigene Zeile, kein Überschreiben (Inv. 4.10, 7.4). Pro (falls F-K2): "Eigene Challenge" mit `ProBadge`.

**Interaktionen.**
- "Geschafft": Kreis des Tages füllt sich (`springQuick`), Zahl "4 von 4" rollt auf "5 von 5", leichter Impuls; die Knöpfe weichen der Statuszeile (`springStandard`).
- Starten: Tippen auf eine Zeile startet sofort, die neue Sektion wächst oben ein, Rückgängig-Hinweis "16:8 gestartet · Widerrufen" (kein Bestätigungsdialog).
- Letzter Tag einer 30-Tage-Challenge erfüllt: `SuccessMoment` mit Maskottchen "feiernd": "30 Tage ohne Zucker geschafft." Unterzeile "26 von 30 Tagen", Erfolgs-Haptik.
- "Abbrechen": nativer Alert "„30 Tage ohne Zucker“ abbrechen?" / "Dein Fortschritt bleibt im Verlauf. Die Challenge lässt sich nicht fortsetzen." / "Abbrechen" (rot), "Weitermachen".

**Große Schrift, 320 pt.** Knöpfe untereinander ab xxL und bei 320 pt; Kreisreihe bricht in Zeilen zu je 7.

**Was sich ändert.** Ersetzt `challenges_screen.dart` (Karten, Streak-Chip mit Flamme, 12,5-pt-Text-Buttons, Material-Dialog, `RefreshIndicator`, rohe Exception). `diet_challenge_service.dart`: Check-in als Einzelzeile bzw. serverseitige Funktion, Auto-Abschluss nicht mehr in der Lese-Abfrage. Neu: Typ `custom` bekommt Oberfläche (3.20).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf, großer fetter Titel "Challenges". Weiße Sektion mit Titel "16:8 Intervallfasten": "Tag 5" in abgerundeten Ziffern, grau #636366 "seit Di., 3. Nov. · 4 von 4 Tagen geschafft", darunter eine Reihe kleiner Kreise, vier gefüllt in Avocado-Grün #3F7A1F und der letzte gestrichelt leer. Darunter "Heute geschafft?" und nebeneinander eine gefüllte grüne Kapsel "Geschafft" mit weißer Schrift und eine graue Kapsel #E9E9EE "Heute nicht". Sektion "Starten" mit "30 Tage ohne Zucker" und grauer Beschreibung sowie grünem Plus-Kreis, und "Eigene Challenge" mit Chevron. Sektion "Abgeschlossen" mit "30 Tage ohne Zucker · 1.–30. Okt. · 26 von 30 Tagen". Keine Flammen-Icons, keine Karten.

---

### 3.20 Eigene Challenge (`/calories/challenges/new`)

**Zweck.** Welche Gewohnheit will ich üben?

**Aufbau (Push).** Kapsel "Starten" (getönt) rechts oben. Sektion: Feld "Name" (Platzhalter "Zum Beispiel Kein Alkohol unter der Woche"), Feld "Tägliche Frage" (vorbefüllt "Heute geschafft?"). Sektion: `ValueStepper` "Dauer" 7 bis 90 Tage in 7er-Schritten oder `ToggleRow` "Ohne Ende". Fuß: "Du hakst jeden Tag ab, ob es geklappt hat."

**Zustände.** Name fehlt: Kapsel deaktiviert. Ungespeichert verlassen: Alert.

**Interaktionen.** "Starten": Pop zu 3.19, neue Sektion wächst oben ein, Rückgängig-Hinweis.

**Große Schrift, 320 pt.** Felder einspaltig, Stepper unter dem Label ab xxL.

**Was sich ändert.** Neu (Typ `custom` existiert in der Datenbank ohne Oberfläche). Datei `challenge_new_screen.dart`; Felder `title`, `duration_days` an `nutrition_challenges` (Migration B).

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links, grün getönte Glas-Kapsel #3F7A1F "Starten" oben rechts, mittig klein "Eigene Challenge". Weiße Sektion mit Zeile "Name" und Eingabe "Kein Alkohol unter der Woche", Zeile "Tägliche Frage" mit "Heute geschafft?". Sektion mit "Dauer" und grauer Stepper-Kapsel #E9E9EE "− 28 Tage +" und einem Schalter "Ohne Ende" (aus). Graue Fußnote #636366 "Du hakst jeden Tag ab, ob es geklappt hat.".

---

### 3.21 Ideen für heute (`/calories/ideas`)

**Zweck.** Was passt noch in mein Budget? Über "Was passt noch?" in 3.1, Hinweis-Zeile auf der Startseite ("Noch 640 kcal heute · Ideen"), Mitteilung "Ideen fürs Abendessen" (01 8.2), Avo.

**Aufbau (Push).**
1. `LargeTitleNavBar` "Ideen für heute", Unterzeile "Noch 640 kcal · Abendessen" (Mahlzeit nach Uhrzeit).
2. `FilterChip`-Zeile: "Bis 400 kcal", "Schnell", "Mit meiner Liste" (UND-verknüpft, "Zurücksetzen" am Ende).
3. **Sektion ohne Titel:** Rezept-Zeilen (`RecipeCard` Variante Zeile): Thumbnail 56 pt, "Ofengemüse mit Feta" (`headline`), Meta "520 kcal · 35 Min", zweite Unterzeile mit `checklist` 15 pt: "3 Zutaten stehen auf Wocheneinkauf". Weitere: "Linsensuppe mit Brot · 480 kcal · 30 Min"; "Gebratener Reis mit Ei · 610 kcal · 20 Min · 2 Zutaten stehen auf Wocheneinkauf"; "Zucchini-Puffer mit Joghurt · 390 kcal · 25 Min". Sortiert nach: passt ins Budget, Zutaten auf einer Liste, eigene gespeicherte zuerst.
4. Fuß: "Rezepte mit Erdnuss sind ausgeblendet, weil du eine Erdnussallergie eingetragen hast. Ernährung & Allergien" (Link).

**Zustände.** Budget unter 150 kcal: `EmptyState` (Symbol `fork.knife` 48 pt) "Nur noch 90 kcal heute." Satz "Für ein ganzes Gericht reicht das nicht mehr." schlicht "Alle Rezepte". Über dem Ziel: "Heute bist du 120 kcal über deinem Ziel." Satz "Morgen geht es mit 2.000 kcal weiter." Keine Treffer: Maskottchen "suchend" "Für 640 kcal passt gerade nichts aus deinen Rezepten." prominent "Rezepte entdecken" (Tab Rezepte). Kein Ziel: `EmptyState` "Ohne Ziel gibt es kein Budget." prominent "Ziel einrichten". Offline: nur lokal gespeicherte Rezepte, `StatusRow`. Leer ist immer scrollbar (Pull-to-Refresh funktioniert, Inv. 2.8).

**Interaktionen.** Tippen: Rezeptdetail als Push im Kalorien-Tab (Zoom-Übergang, 00 10.2). Dort "Ins Tagebuch eintragen" (3.11) und "Zutaten auf Liste" (A). Kontextmenü auf einer Zeile: "Ins Tagebuch eintragen", "Zum Wochenplan" (Modul), "Merken".

**Große Schrift, 320 pt.** Chips umbrechen ab xxxL; Zeilen ab AX1 mit Foto über dem Titel (00 6.4).

**Was sich ändert.** Ersetzt `what_can_i_eat_screen.dart` (Material-`AppBar`, `maxLines: 1`, Akzentfarbe für "Nutzt … von deiner Liste", nicht scrollbarer Leerzustand). `CalorieRecipeNudgeService` bleibt (Ranking mit Diät und Allergien); neu ist die sichtbare Allergie-Fußnote.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf, großer fetter Titel "Ideen für heute" und darunter grau #636366 "Noch 640 kcal · Abendessen". Eine Zeile grauer Kapsel-Chips #E9E9EE "Bis 400 kcal", "Schnell", "Mit meiner Liste" (letzter gewählt in Hellgrün #EEF5E4 mit grünem Text #3F7A1F). Eine weiße Sektion mit 26 pt Radius und vier Rezept-Zeilen mit quadratischen Fotos (12 pt Radius): "Ofengemüse mit Feta" mit "520 kcal · 35 Min" und "3 Zutaten stehen auf Wocheneinkauf", "Linsensuppe mit Brot", "Gebratener Reis mit Ei", "Zucchini-Puffer mit Joghurt". Unten eine graue Fußnote "Rezepte mit Erdnuss sind ausgeblendet, weil du eine Erdnussallergie eingetragen hast." Die Fotos sind die einzigen kräftigen Farben.

---

### 3.22 Apple Health verbinden (`/calories/health`)

**Zweck.** Will ich Health verbinden? Vorab-Erklärung vor der Systemabfrage (00 13). Über die Tipp-Zeile in 3.1, "Mit Apple Health verbinden" in 3.17, 3.13, 3.23, Onboarding-Schritt "Dein Ziel" (Teil A verlinkt).

**Aufbau (Vollbild-Push).**
1. `LargeTitleNavBar`: Zurück, kein Titel in der Leiste.
2. Kopf: Symbol `heart.fill` mehrfarbig 48 pt, Titel (`title1`) "Apple Health verbinden".
3. **Sektion "{app} schreibt in Health":** Zeilen mit Symbolen: `fork.knife` "Essen mit Kalorien und Nährwerten", `drop` "Wasser", `scalemass` "Gewicht", `figure.run` "Workouts".
4. **Sektion "{app} liest aus Health":** `scalemass` "Gewicht, zum Beispiel von deiner Waage", `ruler` "Größe", `drop` "Wasser", `figure.run` "Workouts, zum Beispiel von deiner Apple Watch".
5. Satz (`body`, `label`): "Was {app} aus Health liest, bleibt auf deinem iPhone. Es wird nicht auf unseren Server geladen. Was du in Health erlaubst, kannst du dort jederzeit ändern."
6. Prominent "Weiter" (öffnet die Health-Systemabfrage), darunter schlicht "Nicht jetzt".

**Zustände.** Nach der Systemabfrage: Pop zum Ausgangsort; dort erscheinen Health-Daten (Gewicht, Workouts) mit `fadeReduced`. iOS meldet nicht, ob Lesen erlaubt wurde; zeigt Health nach dem Verbinden keine Daten, steht auf 3.23 "Keine Daten aus Health. Prüfe in Health > Teilen > Apps > {app}, was erlaubt ist." Gerät ohne Health: Seite nicht erreichbar, Zeilen entfallen. Pro (falls F-K2 "Kalorien mit Apple Health"): `ProBadge` hinter dem Titel; "Weiter" heißt "Mit {pro} verbinden" und öffnet die Paywall aus dem Knopf; nach dem Kauf läuft die Systemabfrage direkt weiter.

**Interaktionen.** Keine Haptik. Zurück ohne Entscheidung zählt wie "Nicht jetzt" (Tipp-Zeile kommt nicht wieder).

**Große Schrift, 320 pt.** Fließt; Knöpfe volle Breite untereinander.

**Was sich ändert.** Neu (kein HealthKit im Code). Neu: `health_intro_screen.dart`, `health_sync_service.dart` (Teil B), Health-Fähigkeit, Berechtigungstexte `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` in `InfoPlist.strings` DE/EN (Teil B, Kapitel 19), Paket- bzw. Kanalwahl F-K6.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus, Apple-Stil iOS 27, Hintergrund #F2F2F7, oben links runder Glas-Zurück-Knopf. Linksbündig ein rotes Health-Herz-Symbol 48 pt, darunter fetter Titel "Apple Health verbinden". Weiße Sektion "Avo schreibt in Health" mit vier Zeilen und dünnen grauen Symbolen #636366: Besteck "Essen mit Kalorien und Nährwerten", Tropfen "Wasser", Waage "Gewicht", Läufer "Workouts". Zweite Sektion "Avo liest aus Health" mit "Gewicht, zum Beispiel von deiner Waage", "Größe", "Wasser", "Workouts, zum Beispiel von deiner Apple Watch". Darunter schwarzer Fließtext #000000 "Was Avo aus Health liest, bleibt auf deinem iPhone. Es wird nicht auf unseren Server geladen." und unten eine breite gefüllte Kapsel in Avocado-Grün #3F7A1F "Weiter" mit weißer Schrift, darunter grüner Textlink "Nicht jetzt".

---

### 3.23 Einstellungen Kalorien & Gesundheit (`/settings/health`)

**Zweck.** Wie ist der Bereich eingestellt? Über Profil > "Kalorien & Gesundheit" (01 4), Ziele, Suche ("Health", "Wasser", "kJ").

**Aufbau (Push im Profil).** Titel "Kalorien & Gesundheit".
1. **Sektion "Apple Health":** `ValueRow` "Status" "Verbunden" bzw. `NavRow` "Verbinden" (→ 3.22); bei verbunden `NavRow` "In Health verwalten" (öffnet Health). Fuß: "{app} schreibt Essen, Wasser, Gewicht und Workouts. Was {app} lesen darf, änderst du in Health > Teilen > Apps > {app}."
2. **Sektion "Ziele":** `NavRow` "Ziele" · "2.000 kcal" (→ 3.13).
3. **Sektion "Wasser":** `ValueRow` "Tagesziel" "2 l" (Stepper an Ort und Stelle), `ValueRow` "Schnelltaste" "250 ml" (Menü 150, 200, 250, 330, 500 ml).
4. **Sektion "Einheiten":** `ValueRow` "Gewicht" "kg" (Menü kg, lb), `ValueRow` "Energie" "kcal" (Menü kcal, kJ).
5. **Sektion "Erinnerungen":** `ToggleRow` "Ideen fürs Abendessen" mit Unterzeile "Täglich 18:00, wenn noch Budget übrig ist" (Uhrzeit-Zeile darunter, klappt Rad auf), `ToggleRow` "Wochenrückblick" (Sonntag 19:00). Mitteilungs-Erlaubnis nach 00 13.
6. **Sektion "Daten":** destruktive Zeile "Alle Essensfotos löschen" (Bestätigung: "Alle 23 Essensfotos löschen?" / "Die Einträge bleiben, nur die Fotos werden gelöscht. Das lässt sich nicht rückgängig machen.").

**Zustände.** Modul aus: die Seite ist im Profil nicht sichtbar (01 4); Route öffnet 3.24. Offline: Schalter wirken lokal, Abgleich später.

**Was sich ändert.** Neu (heute nur ein Schalter "Kalorien-Tracking" im Profil, `profile_screen.dart:199-212`; der Modul-Schalter wandert nach Einstellungen > Module, Teil A). Neu: `health_settings_screen.dart` im B-Ordner `screens/calories/settings/`.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus wie eine Seite der iOS-Einstellungen, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf, großer fetter Titel "Kalorien & Gesundheit". Weiße Sektionen mit 26 pt Radius: "Apple Health" mit "Status Verbunden" und "In Health verwalten" mit Chevron und grauer Fußnote; "Ziele 2.000 kcal"; "Wasser" mit "Tagesziel 2 l" und "Schnelltaste 250 ml"; "Einheiten" mit "Gewicht kg" und "Energie kcal"; "Erinnerungen" mit einem grünen Schalter #3F7A1F "Ideen fürs Abendessen" und grauer Unterzeile "Täglich 18:00, wenn noch Budget übrig ist"; ganz unten eine Sektion mit rotem Text #D70015 "Alle Essensfotos löschen". Schwarzer Text #000000, graue Werte #636366.

---

### 3.24 Modul ist aus (zentrierter Alert)

**Zweck.** Will ich Kalorien einschalten? Bei jedem Aufruf einer `/calories/*`-Route oder von `/settings/health` mit ausgeschaltetem Modul (Deep Link, Widget, Mitteilung, Siri, Kurzbefehl).

**Aufbau.** Nativer Alert: Titel "Kalorien ist ausgeschaltet", Nachricht "Schalte das Modul ein, um Essen, Wasser, Gewicht und Workouts einzutragen.", Knöpfe "Nicht jetzt" und "Einschalten" (fett, Standard).

**Verhalten.** "Einschalten": Modul an, Tab Kalorien blendet mit `springStandard` ein, dann wird die ursprüngliche Route geöffnet (bei fehlendem Ziel 3.2). "Nicht jetzt": man bleibt, wo man war. Avo statt Alert: Ergebniszeile "Kalorien ist ausgeschaltet" mit "Einschalten".

**Was sich ändert.** Heute springt die Shell still auf Home und ein Kaltstart-Link kann verloren gehen (Inv. 4.13). Das Modul liest beim Start den lokalen Stand (kein Flackern) über `moduleEnabledProvider(AppModule.calories)` (Teil A), `calorieTrackingEnabledProvider` entfällt bzw. wird Alias.

**Bildbeschreibung für ChatGPT.** iPhone-Screenshot im hellen Modus: die Listen-Seite einer Apple-Stil-App liegt leicht abgedunkelt im Hintergrund, mittig ein nativer iOS-27-Alert mit Liquid-Glass-Fläche: fetter Titel "Kalorien ist ausgeschaltet", darunter "Schalte das Modul ein, um Essen, Wasser, Gewicht und Workouts einzutragen.", zwei Kapsel-Knöpfe nebeneinander "Nicht jetzt" (grau) und "Einschalten" (grün #3F7A1F, fett). Kein Maskottchen, keine Illustration.

---

## 4. Berührungspunkte außerhalb des Tabs

### 4.1 `CaloriesTodaySummary` an anderen Orten

Dieselbe Komponente (7.3) in kompakter Variante: Zeile mit Ring 44 pt, "640 kcal übrig" (`headline` + `number`), Unterzeile "1.360 gegessen · Ziel 2.000", `chevron.right`. Einsatz:
- als Inhalt der Hinweis-Zeile "Noch 640 kcal heute · Ideen" auf der Startseite (00 12.12, Teil A ordnet an), Ziel `/calories/ideas`;
- als Startseiten-Block "Kalorien heute", falls der Owner D2 wählt (0.2), Ziel `/calories`;
- im Kalorien-Widget (Kapitel 19, gleiche Zahlen aus der App Group).

### 4.2 Rezepte und Wochenplan

- Rezept-Metazeile zeigt kcal nur mit Modul (00 12.13). Rezeptdetail: "Ins Tagebuch eintragen" öffnet 3.11 (Ort im Detail legt Kapitel 13 fest).
- Wochenplan (Kapitel 14): kcal pro Tag im Tageskopf; Kontextmenü eines geplanten Rezepts "Ins Tagebuch"; 3.4 zeigt "Heute im Plan".

### 4.3 Onboarding (Teil A, Kapitel 17)

Schritt "Dein Ziel" bettet `GoalForm` (3.14) ein, mit derselben Ergebnis-Vorschau; Health-Verbinden wird dort nicht abgefragt (erst im Moment des Nutzens).

### 4.4 Avo (Teil B, Kapitel 16)

Werkzeuge (heute acht, `avo_assistant_service.dart:287-302`) wandern auf Claude und zeigen Ergebnisse als `AvoResultRow`:
- "Trag mein Mittagessen ein" mit Foto: Ergebniszeile `flame` "Spaghetti Bolognese · ca. 650 kcal · geschätzt, unsicher" mit "Bearbeiten" (öffnet 3.6 vorbefüllt) und "Eintragen". Nie direkt gespeichert.
- "Ich hatte zwei Brötchen mit Käse": dieselbe Vorschau aus Text.
- Wasser, Gewicht, Workout: direkt ausgeführt, Ergebniszeile mit "Widerrufen" ("250 ml Wasser eingetragen", "72,4 kg eingetragen", "Laufen, 30 Min, ca. 260 kcal eingetragen").
- "Wie viel kann ich heute noch essen?": Antwort plus Ergebniszeile "640 kcal übrig · Ansehen".
- Löschen eines Eintrags: `AvoConfirmCard` (Plan 12, auch wenn im Tab Rückgängig reicht).
- Ziel ändern: Ergebniszeile "Kalorienziel auf 1.800 kcal gesetzt · Widerrufen".
- Neu: `log_workout`, `get_ideas`, `start_challenge`, `checkin_challenge`.
- Sprachmodus: "Ich habe gerade einen Apfel gegessen" ergibt hörbar "Ein Apfel, etwa 80 Kilokalorien, als Snack. Eintragen?" und die Vorschau-Zeile; "Ja" per Stimme trägt ein (Eintragen ist umkehrbar; nur Löschen braucht den Tipp).

### 4.5 Mitteilungen, Widgets, Siri (Kapitel 19)

- "Ideen fürs Abendessen" (18:00, nur mit Budget über 300 kcal): "Noch 640 kcal heute. 4 Rezepte passen dazu." → `/calories/ideas`. Ohne Emojis, ohne Maskottchen.
- Kalorien- und Wasser-Widget: Ring, "640 kcal übrig", Knopf "+250 ml" (App Intent, ohne App-Öffnen).
- Siri / Kurzbefehle: "Trag 250 ml Wasser in {app} ein", "Wie viele Kalorien habe ich heute noch?", "Scanne einen Barcode in {app}" (→ `/calories/scan`).
- Steuerelement im Kontrollzentrum "Barcode scannen" (neu, Ergänzung zu 01 5.10).

---

## 5. Abläufe

### 5.1 Ein ganzer Tag (Abnahme Plan 9)

1. 7:40, Tab Kalorien: "2.000 kcal übrig". Toolbar `plus` → "Essen eintragen", Segment steht auf "Frühstück".
2. "Zuletzt gegessen": Tippen auf "Haferflocken · 60 g", "Milch 1,5 % · 200 ml", "Banane · 1 Stück". Jede Zeile wird zum grünen Häkchen, leichter Impuls je Tipp. Zurück: Frühstück zeigt 420 kcal, "1.580 kcal übrig" ist bereits gerollt.
3. 12:41: Toolbar `plus` → "Foto" → Kamera → Auslöser → "Wird geschätzt …" → "Spaghetti Bolognese", "Unsicher", Bestandteile. Spaghetti von 220 auf 200 g korrigiert: Summe rollt auf 620 kcal; zurück auf 220 g, 650 kcal. "Eintragen" → Tagebuch, "930 kcal übrig".
4. 16:10: "Eintragen" unter Snacks → "Barcode scannen" → Skyr-Becher in den Rahmen → Rahmen rastet ein, leichter Impuls → "Menge" mit Skyr Natur, 250 g → "Eintragen". Danach im Suchfeld "Studentenfutter" → Treffer → 25 g → "Eintragen". "640 kcal übrig".
5. Wasser über den Tag fünfmal "+250 ml": "1,25 l von 2 l".
6. 18:40: Zeile "Was passt noch?" → "Ofengemüse mit Feta" → Rezeptdetail → "Ins Tagebuch eintragen" → 1 Portion, Abendessen → "Eintragen". "120 kcal übrig".
7. Mit Health: Essen und Wasser stehen in Health unter "Ernährung", das Lauf-Workout der Apple Watch erscheint in Workouts.

### 5.2 Ziel einrichten (erster Start)

1. Modul im Onboarding oder in Einstellungen > Module eingeschaltet → Tab Kalorien erscheint.
2. Tab: "Wie viel willst du am Tag essen?" → "Ziel einrichten".
3. "Ziel berechnen": Abnehmen, Weiblich, 34, 176 cm, 74,0 kg, Zielgewicht 70,0, Normal, Leicht aktiv. Ergebnis oben rollt auf "2.000 kcal".
4. "Übernehmen" → Tagebuch mit "2.000 kcal übrig". Gewicht 74,0 kg ist eingetragen.
5. Ab dem zweiten Tag mit Einträgen: Tipp-Zeile "Mit Apple Health verbinden".

### 5.3 Foto-Schätzung korrigieren und Allergie

1. Foto eines Pad Thai → Schätzung "Pad Thai mit Huhn · ca. 720 kcal · Unsicher".
2. Warnzeile erscheint (Warn-Haptik): "Kann Erdnuss enthalten. Du hast eine Erdnussallergie eingetragen."
3. Bestandteil "Erdnüsse · ca. 15 g" wird weggewischt (das Essen war ohne), Summe rollt auf 630 kcal; die Warnzeile bleibt stehen, bis keine Erdnuss-Bestandteile mehr da sind, dann schrumpft sie weg.
4. "Eintragen". Der Eintrag bleibt als "geschätzt" markiert.

### 5.4 Barcode nicht gefunden

1. Barcode-Kamera → Code erkannt → "Zu diesem Strichcode ist nichts bekannt."
2. "Manuell eintragen" (getönt) → Manuell mit hinterlegtem Barcode, Name leer.
3. Name "Protein-Riegel Erdbeere", 198 kcal, Protein 20 g → "Eintragen".
4. Beim nächsten Scan desselben Codes geht es direkt zu "Menge" mit diesem eigenen Lebensmittel.

### 5.5 Eintrag löschen und zurückholen

1. Tagebuch: "Studentenfutter" nach links wischen bis zum Ende → Zeile schrumpft weg, "640" rollt auf "772", Rückgängig-Hinweis "Studentenfutter gelöscht · Widerrufen".
2. "Widerrufen" innerhalb von 4 s → Zeile wächst wieder ein, Zahl rollt zurück. Health-Wert wird erst nach Ablauf des Hinweises gelöscht.

### 5.6 Gewicht korrigieren

1. Gewicht → `plus` → neue Zeile oben, Feld fokussiert, "72,4", Datum "Heute" → Return.
2. Fehler bemerkt (es war gestern): Zeile antippen → Datum "Gestern" → fertig. Die Linie verschiebt den Punkt mit `springStandard`.
3. Falscher Eintrag vom 28. Okt.: wischen → "Löschen" → Rückgängig-Hinweis.

### 5.7 Workout mit und ohne Health

1. Ohne Health: Workouts → "Workout eintragen" → Krafttraining, Do., 5. Nov., 18:30, 45 Min, Mittel → "ca. 260 kcal" → "Sichern".
2. Health verbinden: Tipp-Zeile oder Workouts > "Mit Apple Health verbinden" → Erklärung → "Weiter" → Systemabfrage (Lesen und Schreiben) → zurück.
3. Das Krafttraining wird nach Health geschrieben; Läufe der Apple Watch erscheinen mit Quelle "Apple Watch", schreibgeschützt.
4. "Gutschreiben" ist aus: "übrig" bleibt unverändert; mit Schalter an steigt es um die Workout-kcal, die Unterzeile nennt "+280 kcal Laufen".

### 5.8 Challenge

1. Challenges → "16:8 Intervallfasten" antippen → startet sofort, Rückgängig-Hinweis.
2. Jeden Tag: "Heute geschafft?" → "Geschafft" (leichter Impuls) oder "Heute nicht".
3. Korrektur: "Ändern" → wieder die beiden Knöpfe.
4. 30-Tage-Challenge am letzten Tag erfüllt → Erfolgsmoment "30 Tage ohne Zucker geschafft.", Erfolgs-Haptik, Eintrag in "Abgeschlossen".

### 5.9 Offline im Restaurant

1. Kein Netz: `StatusRow` unter dem Titel. "Foto" ist deaktiviert ("Braucht eine Verbindung").
2. Manuell: "Pizza Margherita", 850 kcal → "Eintragen". Zeile mit Sync-Zeichen, "übrig" rollt sofort.
3. Wieder online: Sync-Zeichen verschwindet ohne weitere Meldung; Health wird geschrieben.

### 5.10 Modul aus und wieder an

1. Einstellungen > Module > Kalorien aus: Tab verschwindet mit `springStandard`; kcal in Rezepten und Wochenplan, Hinweis-Zeile, Widget-Inhalt verschwinden; Health-Synchronisation pausiert; Daten bleiben.
2. Kalorien-Widget antippen → App öffnet, Alert "Kalorien ist ausgeschaltet" → "Einschalten" → Tab erscheint, Tagebuch von heute mit allen alten Daten.

---

## 6. Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| F-K1 | Gilt die Tab-Struktur aus 01 (Kalorien als eigener Modul-Tab) oder die D2-Notiz aus `DESIGN-STATUS.md` (5 Tabs Home · Listen · Avo · Rezepte · Profil, Kalorien als Block auf Home)? Beide Konzepte widersprechen sich; 00/01 und D2 entstanden am selben Abend. | Owner entscheidet vor S2. Dieses Kapitel funktioniert mit beiden: `CaloriesTodaySummary` ist Tab-Kopf oder Home-Block, alle Unterseiten haben eigene Routen. |
| F-K2 | Welche Teile dieses Bereichs werden Pro (00 F-05 nennt "Kalorien mit Apple Health")? Kandidaten: Apple Health, Foto-Schätzung (kostet KI pro Bild), ältere Wochen und Statistiken, eigene Challenges. | Tagebuch, Suche, Barcode, Manuell, Wasser, Gewicht frei. Pro-Kandidaten: Apple Health und Foto-Schätzung über ein Kontingent (z. B. 3 Fotos pro Woche frei). Gate-Stellen stehen je Screen. |
| F-K3 | Sollen Workouts das Tagesbudget erhöhen? | Standard aus, Schalter in Ziele. |
| F-K4 | Nahrungsdaten anderer Apps aus Health lesen? | Nein (Doppelzählung). |
| F-K5 | Aus Health gelesene Daten nur lokal anzeigen statt in Supabase speichern? Folge: auf dem zweiten Gerät nur sichtbar, wenn Health dort dieselben Daten hat. | Ja, nur lokal (Datenschutz, App-Review 5.1.3). |
| F-K6 | Technik für Barcode-Kamera und Health: VisionKit und HealthKit über eigene Swift-Kanäle (Teil B, kein neues Paket) oder Pakete (`mobile_scanner`, `health`)? | VisionKit per Kanal (iOS 16+); HealthKit über das Paket `health` nach einem Spike von höchstens einem Tag, sonst eigener Kanal. Paket-Commits nach `arbeitsteilung.md` (eigener Mini-Commit). |
| F-K7 | Wie rechnet "Divers"? Heute wie männlich. Welche Untergrenzen gelten (1.200 / 1.500)? | Mittelwert beider Formeln, Untergrenze 1.200 kcal. Fachlich prüfen lassen. |
| F-K8 | Sicherheit der Foto-Schätzung in drei Wortstufen statt "ca. 80 % sicher" (01 10.7)? | Ja, Prozentwerte eines Sprachmodells sind nicht kalibriert. |
| F-K9 | Bleibt die Woche eine Kalenderwoche Mo bis So (wie Wochenplan) statt "letzte 7 Tage"? | Ja. |
| F-K10 | Mitteilung "Wochenrückblick" (So 19:00) als neue, abschaltbare Erinnerung? | Ja, Standard aus. |
| F-K11 | Sollen Essensfotos nach einer Frist (z. B. 90 Tage) automatisch gelöscht werden? | Ja, 90 Tage; Einträge bleiben. |

---

## 7. Ergänzungen zum Fundament

### 7.1 Muster "Eintrage-Screen als Push" (wegen der Owner-Regel "Nie Slider")

00 12.23 (`AppSheet`) und K-30 sind für diesen Bereich durch die Owner-Regel in `CLAUDE.md` (Commit `4ebb4fb`) überholt. Vorschlag für 00 als neue Komponente `EditorScaffold` (Teil A):
- Push mit eigener Route, Tab-Bar sichtbar (01 6), Zurück links.
- Neues anlegen: rechts eine getönte Glas-Text-Kapsel mit dem Verb ("Eintragen", "Sichern", "Übernehmen", "Starten"); deaktiviert, bis die Eingaben gültig sind. Das ist die eine getönte Hauptaktion der Bedienebene (00 8.2).
- Bestehendes bearbeiten: speichert beim Verlassen, Rückgängig-Hinweis am Ziel; keine Kapsel.
- Verlassen mit ungespeicherten neuen Eingaben: zentrierter Alert ("… verwerfen?" / "Verwerfen" rot / "Weiter bearbeiten") statt Aktionsblatt.
- Vorab-Erklärungen für Berechtigungen: zentrierter Alert bei einem Satz, Vollbild-Push bei mehr Inhalt (Health).
- Das Modul-ist-aus-"Sheet" aus 00 13 wird ein zentrierter Alert.
- 00 und 01 sollten diese Regel für alle Kapitel übernehmen (betrifft u. a. Artikel-Sheet, Teilen, Abschluss, Paywall, Avo-Sheet, Profil). Das klärt Teil A.

### 7.2 Kalender-Menü

Neue Variante von `AppMenu` (00 12.24): Menü, das sich an Ort und Stelle in ein Monatsraster verwandelt (Tage 44 pt, Punkt für Tage mit Daten, Auswahl als gefüllter Kreis `action`), ab AX1 als Rad-Auswahl. Wird auch von Wochenplan (Woche wählen) und Verlauf gebraucht, daher in Teil A's Bibliothek.

### 7.3 Neue Komponenten (Teil B baut nach den Regeln aus 00 12)

| Komponente | Zweck | Aufbau |
|---|---|---|
| `CaloriesTodaySummary` | Kopf des Tabs; kompakt für Startseite und Widget | 3.1 Punkt 5 bzw. 4.1 |
| `MacroRow` | eine Makro-Zeile mit Balken | Label `body`, Wert `number` + `subheadline`, Balken 4 pt `health` auf `fill`; ab AX1 gestapelt |
| `FoodEntryRow` | Eintrag im Tagebuch, in "Zuletzt gegessen" und Suche | optionales Foto 28 pt, Name `body`, Unterzeile `subheadline` `labelSecondary`, rechts kcal (`number`) oder `plus.circle`; Zustände normal, ausstehend, Fehler, "Eingetragen" (2 s) |
| `ConfidenceRow` | Sicherheit einer KI-Schätzung | drei 8-pt-Punkte (`label` gefüllt, `controlOutline` Ring) plus Wort; Fuß mit Erklärung |
| `DayDots` | Tagesreihe einer Challenge | 12-pt-Kreise in `health` / `controlOutline`, Zeilen zu je 7 ab Platzmangel |
| `GoalForm` | Fragebogen mit Ergebnis-Vorschau, auch im Onboarding | 3.14 |
| `ScannerFrame` | Sucherrahmen der Barcode-Kamera | Eckwinkel 4 pt `labelOnPhoto`, Erkannt in dunkler `action`-Variante, Abdunkelung #000000 40 % |

### 7.4 Daten und Backend (Teil B)

- Tabelle `workout_log` (`id`, `user_id`, `started_at`, `duration_min`, `type`, `intensity`, `calories`, `health_uuid`, `created_at`), RLS über `auth.uid()`.
- `food_log_entries`: Quelle `search` und `manual_estimated` ergänzen; Feld `estimated` (bool), `confidence` (Text-Enum), `health_uuid`; `logged_time` für die Uhrzeit.
- `nutrition_goals`: `credit_workouts` (bool), `pace` (Text) statt `timeline_weeks` (alt bleibt lesbar).
- `nutrition_challenges`: `title`, `duration_days`, `question` für `custom`; Check-ins als eigene Tabelle `challenge_checkins` (`challenge_id`, `date`, `kept`) mit Unique (`challenge_id`, `date`) statt jsonb (Inv. 4.10); Auto-Abschluss per geplanter Edge Function.
- Bucket `meal-photos` privat, signierte URLs; Löschfrist (F-K11).
- `user_food` (eigene Lebensmittel, inkl. Barcode) für Manuell und nicht gefundene Barcodes.
- Migrationen nur dokumentieren und nach Freigabe des Owners anwenden (`arbeitsteilung.md` 6).

### 7.5 Haptik (Ergänzung zu 00 11)

| Ereignis | Haptik |
|---|---|
| Essen eingetragen (auch aus "Zuletzt gegessen", Rezept, Avo nach Bestätigung) | leichter Impuls, im Frame, in dem die Zeile erscheint bzw. das Häkchen sich füllt |
| Wasser hinzugefügt | leichter Impuls |
| Barcode erkannt | leichter Impuls (01 10.7 nennt ihn schon) |
| Challenge-Check-in | leichter Impuls |
| Challenge mit fester Dauer geschafft | Erfolg (00 11 nennt "Challenge geschafft") |
| Tag im Tagebuch per Wischen gewechselt, Woche per Wischen gewechselt | Auswahl (wie Wochentag-Wechsel in 00 11) |

### 7.6 Texte, die von 01 abweichen

- 01 10.7 "ca. 80 % sicher" → Wortstufen "Recht sicher / Unsicher / Grob geschätzt" (2.3, F-K8).
- 01 10.7 "Ich erkenne darauf kein Essen." → "Auf dem Foto ist kein Essen zu erkennen." (Oberfläche ohne Ich-Form, 00 3.2; in Avo-Antworten darf die Ich-Form bleiben).
- 01 5.5 "Zeilen Foto, Barcode, Suche, Manuell" → Suchfeld oben plus drei Zeilen (Suchen ist der häufigste Weg und gehört nach 00 12.25 als Feld unter den Titel).

### 7.7 Routen (Ergänzung zu 01 7, alle Teil B, Muster Push)

`/calories?date=`, `/calories/add/photo`, `/calories/add/estimate`, `/calories/add/food/:foodId`, `/calories/add/manual`, `/calories/add/recipe/:recipeId`, `/calories/entry/:entryId`, `/calories/goals/setup`, `/calories/week?start=`, `/calories/workouts/new`, `/calories/workouts/:id`, `/calories/challenges/new`, `/calories/health`. Deep Links neu: `shoply://calories/water?ml=250` (fügt hinzu, Rückgängig-Hinweis), `shoply://calories/ideas`. `/calories/add` und `/calories/scan` werden Push statt Sheet bzw. Cover (0.1).

### 7.8 Symbole (Ergänzung zu 00 9.2)

`heart.fill` (Health, mehrfarbig, nur 3.22), `ruler` (Größe), `flashlight.off.fill` / `flashlight.on.fill`, `bolt` / `bolt.slash` (Blitz), `photo.on.rectangle` (Aus Fotos), `keyboard` (Nummer eingeben), `plus.circle` / `checkmark.circle.fill` (Eintragen aus Zeilen), `checklist` (Zutaten auf einer Liste), Workout-Arten aus 3.18 (`figure.walk`, `figure.outdoor.cycle`, `figure.pool.swim`, `figure.strengthtraining.traditional`, `figure.yoga`, `figure.highintensity.intervaltraining`, `figure.hiking`, `figure.dance`, `figure.mixed.cardio`), jeweils mit Rückfall vor iOS 17 (`figure.run` bzw. `heart`).

### 7.9 Glas-Budget je Screen

Tagebuch, Unterseiten mit Tab-Bar: Tab-Bar plus Toolbar oben = 2. Kamera und Barcode: zwei Glasgruppen über der Kamera-View (Kamera ist eine Platform View ohne Glas) = 2 Glas plus 1 Kamera; die Tab-Bar ist dort aus dem Baum genommen (00 8.4). Rückgängig-Hinweis kommt jeweils als drittes Element hinzu.
