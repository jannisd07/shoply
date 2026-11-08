# Kalorien & Gesundheit: Screen-Spezifikation (Teil B, Paket B6)

Stand 08.11.2026. Bauplan für alle Screens des Moduls `AppModule.calories`, damit B6 direkt nach S2 (Tokens und
Komponenten von Teil A) gebaut werden kann. Diese Datei enthält keinen Code.

Quellen und Rang: Aussehen aus D2 · Glas (`D2-Komponenten`, `X-Essen`, `D2-FuerDich` Abschnitt 6 und Kachel „Wasser
heute“, `X-Profil`). Funktion, Zustände, Texte und Barrierefreiheit aus `docs/redesign/konzept/15-kalorien.md`, dazu
Kapitel 00, 01 und 20. Verträge aus `status-A.md` (Routen, Module, Übersetzungen), Regeln aus dem Plan Teil B (Global
Constraints) und `status-B.md` (Owner-Entscheidungen). Wo D2 und Konzept sich widersprechen, steht in Abschnitt 5 eine
Empfehlung; sie gilt, bis der Owner entscheidet.

Komponentennamen in `Code-Schrift` sind die Bausteine, die Teil A mit S2 liefert, oder B-eigene Bausteine (Abschnitt
2.3). Was im D2-Blatt fehlt, steht als Anfrage in Abschnitt 6. Alle Texte stehen Deutsch und Englisch hier und kommen in
`lib/core/localization/translations/calories.dart` mit Präfix `cal_`. Sie sind mit `design:ux-copy` und `humanizer`
geprüft: Du-Form, keine Ausrufezeichen, keine Emojis, keine Werbesprache, „geschätzt“ und „ca.“ bei jeder KI- oder
Rechen-Schätzung, „Richtwerte, kein ärztlicher Rat.“ bei Zielen. Bestandsschlüssel (`meal_*`, `calories_*`,
`log_recipe_*`, `what_can_i_eat_*` usw.) entfallen mit den Screens, die sie heute nutzen.

## Inhalt

0. Überblick
1. Routen und Navigation
2. Bausteine und Maße aus D2
3. Regeln für alle Screens
4. Screens S0 bis S24
5. Konflikte zwischen D2 und Konzept
6. Anfragen an Teil A
7. Datenquellen und Lücken
8. Prüfliste für Screenshots

---

## 0. Überblick

Die Frage des ganzen Bereichs: **Wie viel kann ich heute noch essen?** Die größte Zahl auf Home-Karte und Tagebuch
beantwortet genau das („640 kcal übrig“). Die häufigste Aufgabe ist „etwas eintragen“; sie ist von Home-Karte,
Tagebuch, Widget und Kurzbefehl mit einem Tipp erreichbar, und „Zuletzt gegessen“ trägt mit einem weiteren Tipp ein.

| Nr. | Screen | Route | Art |
|---|---|---|---|
| S0 | Home-Karte „Kalorien heute“, Kachel „Wasser heute“, Hinweis „Noch 640 kcal“ | Slot auf Home (A ordnet) | B-Widget |
| S1 | Tagebuch | `/calories?date=` | Push im Home-Tab |
| S1a | Tagebuch ohne Ziel | wie S1 | Zustand von S1 |
| S2 | Datum wählen | Menü auf S1 | Pull-down-Menü |
| S3 | Essen eintragen | `/calories/add` | Vollbild |
| S4 | Foto aufnehmen | `/calories/add/photo` | Vollbild, Kamera |
| S5 | Schätzung prüfen | `/calories/add/estimate` | Vollbild |
| S6 | Barcode-Kamera | `/calories/scan` | Vollbild, Kamera |
| S7 | Menge | `/calories/add/food/:foodId` | Vollbild |
| S8 | Manuell | `/calories/add/manual` | Vollbild |
| S9 | Eintrag bearbeiten | `/calories/entry/:entryId` | Vollbild |
| S10 | Rezept ins Tagebuch | `/calories/add/recipe/:recipeId` | Vollbild |
| S12 | Wasser | Zeile auf S1, Kachel auf Home, Alert | ohne Route |
| S13 | Ziele | `/calories/goals`, `/settings/health/goals` | Push |
| S14 | Ziel berechnen | `/calories/goals/setup` | Vollbild |
| S15 | Woche | `/calories/week?start=` | Push im Home-Tab |
| S16 | Gewicht | `/calories/weight` | Push im Home-Tab |
| S17 | Workouts | `/calories/workouts` | Push im Home-Tab |
| S18 | Workout eintragen oder bearbeiten | `/calories/workouts/new`, `/calories/workouts/:workoutId` | Vollbild |
| S19 | Challenges | `/calories/challenges` | Push im Home-Tab |
| S20 | Eigene Challenge | `/calories/challenges/new` | Vollbild |
| S21 | Ideen für heute | `/calories/ideas` | Push im Home-Tab |
| S22 | Apple Health verbinden (Vorab-Screen) | `/calories/health` | Vollbild |
| S23 | Einstellungen „Kalorien & Gesundheit“ | `/settings/health` | Push im Profil-Tab |
| S24 | Modul ist aus | Alert vor jeder Route | zentrierter Dialog |

S11 ist im Konzept nicht vergeben und bleibt frei.

---

## 1. Routen und Navigation

### 1.1 Drei Arten von Routen (Vertrag aus `status-A.md`, Datei `lib/routes/areas/calories_routes.dart`)

| Art | Liste in der Bereichsdatei | Wo es öffnet | Kopf | Tab-Leiste |
|---|---|---|---|---|
| Wurzel | `buildCaloriesRoot` | A hängt `/calories` in den Home-Branch | Glas-Knopf 44 `chevron.left` „Zurück“ | sichtbar |
| K (Kind) | `caloriesChildRoutes`, Pfade relativ (`'week'`) | im Home-Branch über dem Tagebuch | Glas-Knopf 44 `chevron.left` | sichtbar |
| V (Vollbild) | `caloriesRootRoutes`, Pfade absolut (`'/calories/add'`) | Root-Navigator über der Tab-Leiste, über dem Tab, aus dem man kommt | `xmark` „Schließen“ (Anfang eines Ablaufs) oder `chevron.left` (Folgeschritt, Bearbeiten) | nicht sichtbar |
| E (Einstellung) | `caloriesSettingsRoutes`, relativ zu `/settings` (`'health'`) | Profil-Tab | Glas-Knopf 44 `chevron.left` | sichtbar |

Warum Eintragen und Bearbeiten V-Routen sind und keine Kinder von `/calories`: Ein Kind von `/calories` liegt im
Home-Branch. Öffnet man es aus dem Rezepte-Tab („Ins Tagebuch“) oder von der Home-Karte, baut GoRouter das Tagebuch
darunter und wechselt den Tab; „Schließen“ landet dann im Tagebuch statt dort, wo man war. Als V-Route öffnet der
Screen über dem aktuellen Tab und kehrt beim Schließen genau dorthin zurück (Home bleibt Home, das Rezept bleibt
offen). Das braucht eine Zusage von A: `caloriesRootRoutes` stehen in der Routenliste vor der Shell, weil sie mit
`/calories` beginnen (Anfrage A-R1). Test in `test/routes/app_routes_test.dart`: `/calories/add` aus dem Rezepte-Tab
öffnen, schließen, Rezepte-Tab ist wieder sichtbar.

**Übergang:** Jede Route öffnet mit dem normalen iOS-Push von rechts (Cupertino-Übergang, Zurück-Wischen vom linken
Rand). Nichts gleitet von unten herein, auch die Kameras nicht (Owner-Regel „keine Slider“). Zwischen Kamera und
Schätzung bzw. Kamera und Menge ersetzt der neue Screen den alten im Stapel (`pushReplacement`), damit „Zurück“ aus der
Schätzung nicht in eine leere Kamera führt.

### 1.2 Alle Pfade

| Nr. | Pfad | Art | Parameter | Zurück führt zu |
|---|---|---|---|---|
| S1 | `/calories` | Wurzel | `date=YYYY-MM-DD` (fehlt: heute), `focus=water` (scrollt zur Wasser-Zeile) | Home |
| S3 | `/calories/add` | V | `meal=breakfast\|lunch\|snack\|dinner` (fehlt: nach Uhrzeit), `date=`, `tab=photo\|barcode\|search` (fehlt: zuletzt genutzt, beim ersten Mal `search`) | Ausgangsort |
| S4 | `/calories/add/photo` | V | wie S3 | S3 |
| S5 | `/calories/add/estimate` | V, ersetzt S4 | Foto als `extra` (nicht in der URL) | S3 |
| S6 | `/calories/scan` | V | `meal=`, `date=` | Ausgangsort (S3 oder Deep-Link-Herkunft) |
| S7 | `/calories/add/food/:foodId` | V, ersetzt S6 bei Treffer | `foodId` = Strichcode, OFF-Code oder ID eines eigenen Lebensmittels; `meal=`, `date=` | S3 bzw. Ausgangsort |
| S8 | `/calories/add/manual` | V | `name=`, `barcode=`, `meal=`, `date=` (vorbefüllt aus Suche, Barcode, Avo) | vorheriger Screen |
| S9 | `/calories/entry/:entryId` | V | | S1 |
| S10 | `/calories/add/recipe/:recipeId` | V | `servings=`, `date=`, `meal=` (vom Wochenplan) | Rezept bzw. Wochenplan |
| S13 | `/calories/goals` | K | | S1 |
| S13 | `/settings/health/goals` | E | gleiches Widget wie oben, damit man im Profil-Tab bleibt | S23 |
| S14 | `/calories/goals/setup` | V | `from=onboarding\|empty\|goals` | Ausgangsort |
| S15 | `/calories/week` | K | `start=YYYY-MM-DD` (Montag; fehlt: laufende Woche) | S1 |
| S16 | `/calories/weight` | K | | S1 |
| S17 | `/calories/workouts` | K | | S1 |
| S18 | `/calories/workouts/new`, `/calories/workouts/:workoutId` | V | | S17 |
| S19 | `/calories/challenges` | K | | S1 |
| S20 | `/calories/challenges/new` | V | | S19 |
| S21 | `/calories/ideas` | K | | S1 bzw. Home (Hinweis, Mitteilung) |
| S22 | `/calories/health` | V | `from=` (nur Analytics) | Ausgangsort |
| S23 | `/settings/health` | E | | Profil |

Höchstens drei Ebenen: Home > Tagebuch > Unterseite im Tab; darüber höchstens ein V-Ablauf mit bis zu drei Schritten
(S3 > S6 → S7, S3 > S4 → S5).

### 1.3 Deep Links, Mitteilungen, Widgets, Siri

| Einstieg | Ziel |
|---|---|
| `shoply://calories`, Kalorien-Widget | S1, heute |
| `shoply://calories/add`, Kurzbefehl „Essen eintragen“ | S3 über Home |
| `shoply://calories/scan`, Kontrollzentrum „Barcode scannen“, Siri „Scanne einen Barcode in Avo“ | S6 über Home |
| `shoply://calories/water?ml=250`, Widget-Knopf „+250 ml“ (App Intent) | Widget und Siri tragen ein, ohne die App zu öffnen; der Link in der App öffnet S1 mit Rückgängig-Hinweis |
| `shoply://calories/ideas`, Mitteilung `avo_dinner_ideas` | S21 |
| Avo-Ergebniszeile „Ansehen“ | S1 bzw. der passende Screen (wechselt in den Home-Tab) |

Modul aus: Jeder dieser Einstiege zeigt zuerst S24. Nach „Einschalten“ öffnet das ursprüngliche Ziel; ohne Ziel S1a.
Doppelte Zustellung unter 2 s wird verworfen, ein Kaltstart-Link genau einmal ausgeführt (01 §8.1). Unbekannte
Unterpfade (`/calories/xyz`) zeigen die Fehlerseite von A.

---

## 2. Bausteine und Maße aus D2

### 2.1 Grundmaße

| Element | D2-Wert |
|---|---|
| Hintergrund | `groupedBg` #F2F2F7 |
| Seitenrand | 16 pt, ab 430 pt Breite 20 pt |
| Großer Titel | 34/41 Bold, Laufweite +0,2; Inhalt beginnt 106 pt von oben (unter Toolbar) |
| Inline-Titel | 17/22 Semibold, zentriert zwischen den Toolbar-Knöpfen (X-Essen) |
| Toolbar | obere Kante 54 pt; Glas-Knopf 44 (Kreis, Radius 22, `.glass`, Symbol 18 bis 22 pt in #1C1C1E); Glas-Gruppe (44 hoch, Radius 22, Knöpfe je 40 × 44); getönter Primär-Kreis 44 (Symbol weiß) |
| Scroll-Kante | Verlauf 104 pt von #F2F2F7 (30 %) zu transparent unter der Toolbar, nur wo Inhalt darunter scrollt |
| Gruppe | weiß, Radius 26, außen 16 pt Rand, Abstand zwischen Gruppen 24 pt |
| Gruppenkopf | GROSS 13/18 Semibold #6C6C70, Laufweite +0,3, 18 pt über der Gruppe, Text bei 32 pt vom Bildschirmrand; Zahl rechts (z. B. „420 kcal“) 13/18 tabellarisch |
| Fußnote | 13/18 #6C6C70, 6 pt unter der Gruppe, bei 32 pt |
| Zeile | einzeilig mindestens 52 pt (X-Profil), zweizeilig mindestens 64 pt (D2-FuerDich `.row`); Innenrand 16; Titel 17/22; Unterzeile 15/20 #6C6C70; Wert rechts 17/22 #6C6C70; Chevron 8 × 14 #C7C7CC; Trenner 0,5 pt #E5E5EA ab Textkante |
| Schalter | 51 × 31, an #34C759 (X-Profil) |
| Segmented Control | 44 hoch, Spur `fill`, Innenabstand 3, Daumen weiß 38 hoch Radius 19 mit Schatten, Text 15/20 (gewählt 600, sonst 500). Die 36-pt-Variante aus X-Essen wird nicht gebaut (unter 44 pt) |
| Stepper | 44 hoch, Radius 22, `fill`, „−“ und „+“ je 44 × 44, Wert 17/22 600 tabellarisch, mindestens 28 breit |
| Filter-Chip | sichtbar 34 hoch, Trefferfläche 44, 15/20 500, Innenrand 14; gewählt #1C1C1E mit weißer Schrift, sonst `fill` |
| Getönte Kapsel | 54 hoch Radius 27, 17/22 600 (unten auf Vollbild-Screens, X-Essen); 50 hoch Radius 25 (in Karten, D2-FuerDich); 44 hoch Radius 22, 15/20 600 mit Symbol 18 (in Inhalten) |
| Glas-Kapsel | 44 hoch, 15/20 600 #1C1C1E (auf Kameras, über Fotos) |
| Glas-Pille | 28 hoch, Radius 14, 13/18 600 (auf Fotos, X-Essen) |
| Text-Knopf | 17/22, Grün #1F7A3A, destruktiv #D70015, Höhe 44 |
| Suchfeld | weiß, 48 hoch, Radius 24, Schatten wie das „Frag Avo“-Feld (D2-FuerDich), Lupe 17 pt #6C6C70, Platzhalter #6C6C70 |
| Zahlen | immer tabellarische Ziffern; Hauptzahl `numberXL` 34/41 Bold (A-Token, wächst mit Dynamic Type bis höchstens 51 pt) |
| Ring | 112 pt (Home) bzw. 120 pt (Tagebuch), Strich 12, Spur #ECECF0, runde Kappe |
| Balken | Makros 6 pt Radius 3 auf #ECECF0 (D2); Wasser in Zeilen 4 pt Radius 2 |
| Bilder | Artikel- und Produktbild 44 Radius 10; Produktkopf 64 Radius 14; Foto groß 300 hoch Radius 26 (X-Essen) bzw. 4:3 Radius 20; Mini-Bild 20 Radius 6 |
| Avo | `AvoFigure(pose:)` aus `assets/avo/`, mit der weichen grünen Schatten-Ellipse aus D2 |

### 2.2 Farben im Bereich (D2, als Tokens von A)

| Rolle | D2-Wert | Einsatz | Hinweis |
|---|---|---|---|
| Text | #1C1C1E | alles Lesbare | |
| Sekundär | #6C6C70 | Unterzeilen, Fußnoten, Werte | nicht auf `fill` über #F2F2F7 (4,09:1), siehe 3.7 |
| Akzent | #1F7A3A | Text-Knöpfe, getönte Kapseln, Häkchen | |
| Kicker Kalorien | #A8521A | „KALORIEN“ auf der Home-Karte, Warn-Text „kcal drüber“ | 5,40:1 |
| Ring und Kohlenhydrate | #E8833A | Ring, Kohlenhydrat-Balken, Wochenbalken | 2,71:1, Vorschlag #C8641A (3.7) |
| Protein | #3B82F6 | Protein-Balken | nur Grafik |
| Fett | #A855F7 | Fett-Balken | nur Grafik |
| Wasser | #3B82F6, Fläche #E8F0FE | Tropfen, Wasser-Balken, Symbol-Kachel | nur Grafik |
| Health | #FF2D55 | Herz in „Wird auch in Apple Health gespeichert“ | dekorativ neben Text |
| Destruktiv | #D70015 | „Eintrag löschen“, „Challenge abbrechen“ | nicht #FF3B30 |
| Spur | #ECECF0 | Ring- und Balkenspur | trägt keine Information |

Dunkel: D2 ist nur hell. Alle Werte oben braucht es auch dunkel (Anfrage A-T3).

### 2.3 B-eigene Bausteine (Ordner `lib/presentation/screens/calories/widgets/`)

Aus A-Tokens gebaut, keine eigenen Farben, Größen oder Dauern:

- `CaloriesTodaySummary` in drei Größen: groß (Tagebuch), Karte (Home, D2 Abschnitt 6), kompakt (Hinweiszeile, 44-pt-Ring).
- `MacroRow` (Label links, „62 von 110 g“ rechts, 6-pt-Balken darunter; ab AX1 gestapelt).
- `MealSection` (Gruppenkopf mit Summe, `FoodEntryRow`s, letzte Zeile „Eintragen“).
- `FoodEntryRow` (Tagebuch, „Zuletzt gegessen“, Suche; Zustände normal, wartet, nicht gespeichert, „Eingetragen“ für 2 s).
- `WaterRow` (Tagebuch) und `WaterTile` (Home-Kachel 148 pt, D2).
- `ConfidenceRow` (drei 8-pt-Punkte plus Wort, nie Prozent).
- `ComponentRow` (Bestandteil einer Schätzung mit Gramm-Feld und Stepper an Ort und Stelle).
- `DayDots` (Challenge-Tage), `GoalForm` (S14, auch für das Onboarding von A), `ScannerFrame` (S6), `CameraShutter` (S4).
- `WeekBars` und `WeightLine` als Konfiguration der A-Diagramme (`BarChart`, `LineChart`), nicht als eigene Zeichnung.

---

## 3. Regeln für alle Screens

### 3.1 Lokal zuerst

- Jeder Screen zeigt im ersten Frame den lokalen Stand (Tag, Woche, Ziele, Wasser, „Zuletzt gegessen“, Produkt-Cache).
  Der Abgleich mit Supabase läuft danach unsichtbar; Zahlen rollen an Ort und Stelle, neue Zeilen wachsen ein. Kein
  Spinner, kein Skelett beim zweiten Öffnen.
- Skelett (`SkeletonSection` von A, ruhige Tonflächen in `fill`, keine Animation, VoiceOver ein Element „Wird geladen“)
  nur beim allerersten Öffnen auf einem Gerät ohne lokalen Stand. Nach 10 s ohne Antwort: Fehler-Zustand.
- Nachbartage (±7) sind vorgewärmt, damit der Tageswechsel ohne Warten geht.
- Schreiben ist optimistisch und geht durch die dauerhafte Warteschlange. Ein Netzfehler erzeugt nie „Ziel fehlt“ oder
  „Noch nichts gegessen“ (Konzept 15 2.1). Ungeloggte Tage sind unbekannt, nicht 0 kcal.

### 3.2 Zustände, die überall gleich aussehen

| Zustand | Darstellung | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Offline | `StatusRow` unter dem Titel, erscheint nach 1 s | `cal_status_offline` | Offline. Deine Einträge werden gespeichert, sobald du wieder online bist. | You're offline. Your entries will be saved once you're back online. |
| Wartet | `StatusRow`, ICU-Plural | `cal_status_pending` | {n, plural, =1{1 Eintrag wartet} other{# Einträge warten}} | {n, plural, =1{1 entry waiting} other{# entries waiting}} |
| Verbindung schlecht | Text aus dem Bereich `system` (B) | `sys_status_poor` | Verbindung schlecht. Es wird der letzte Stand gezeigt. | Poor connection. Showing the last saved data. |
| Zeile nicht gespeichert | Zeile mit `exclamationmark.circle` in #D70015 statt kcal, Tippen wiederholt, Fehler-Haptik | `cal_row_not_saved` | Nicht gespeichert | Not saved |
| | VoiceOver-Zusatz | `cal_row_not_saved_a11y` | {name}, nicht gespeichert. Doppeltippen zum Wiederholen. | {name}, not saved. Double-tap to try again. |
| Zeile wird gesendet | `arrow.triangle.2.circlepath` 10 pt hinter der kcal-Zahl, VoiceOver-Zusatz | `cal_row_sending_a11y` | wird gesendet | sending |
| Fehler einer Sektion | ein Satz am Ort, Text-Knopf `retry` (common) | je Screen | | |
| Modul aus | Elemente verschwinden ohne Lücke; Route zeigt S24 | | | |
| KI-Kill-Switch (`aiRemoteEnabledProvider` false) | Foto-Segment, „Kalorien schätzen lassen“ und Avo-Schätzungen verschwinden ohne Hinweis (Empfehlung, Owner-Frage 8) | | | |
| Tageslimit KI | siehe S3/S5 | | | |
| Pro gesperrt | `ProBadge` an der gesperrten Aktion, echte Vorschau, Paywall `/pro?feature=<id>` erst bei der Aktion; nichts davon ist heute entschieden (F-K2), Standard: nichts gesperrt außer dem Tageslimit | | | |
| Berechtigung abgelehnt | `StatusRow` am Ort, Funktion startet nach Rückkehr nicht von selbst | je Screen | | |

Der Angebots-Kill-Switch (`offersRemoteEnabledProvider`) betrifft diesen Bereich nicht. Es gibt hier keine Preise und
keine Angebote.

### 3.3 Zahlen und Wortlaut

- Format mit `intl` und Gerätesprache: „1.360 kcal“ / „1,360 kcal“, „1,25 l“ / „1.25 L“, „72,4 kg“ / „72.4 kg“,
  „32 Min“ / „32 min“, „1 Std. 40 Min“ / „1 hr 40 min“. kcal ganzzahlig; Gramm unter 10 g mit einer Nachkommastelle
  („0,5 g“). Einheiten nach Einstellung (kg/lb, kcal/kJ; kJ = kcal × 4,184, gerundet).
- Alle Felder nehmen Komma und Punkt (`parseLocaleDouble`). Ungültig heißt nie still 0, sondern Hinweis unter dem Feld:
  `cal_number_invalid` „Bitte eine Zahl, zum Beispiel 450 oder 450,5“ / „Enter a number, for example 450 or 450.5“.
- Datum: „Heute“, „Gestern“, sonst „Do., 5. Nov.“ / „Thu, Nov 5“; relativ nur bis 7 Tage.
- Mahlzeiten verbindlich: Frühstück, Mittagessen, Snacks, Abendessen / Breakfast, Lunch, Snacks, Dinner. Kurzformen nur
  bei Platzmangel im Segment: Früh, Mittag, Snack, Abend. Vorauswahl nach Uhrzeit: bis 10:29 Frühstück, 10:30 bis 14:59
  Mittagessen, 15:00 bis 16:59 Snacks, 17:00 bis 21:29 Abendessen, danach Snacks.
- KI-Werte heißen immer „geschätzt“, kcal mit „ca.“, Sicherheit in drei Wörtern: „Recht sicher“, „Unsicher“, „Grob
  geschätzt“ / „Fairly sure“, „Unsure“, „Rough estimate“. Nie Prozent. Nie direkt gespeichert, auch nicht von Avo.
- Rechen-Schätzungen (Workout-kcal, Ziel) mit „ca.“ bzw. „Richtwerte, kein ärztlicher Rat.“ /
  „Guide values, not medical advice.“
- Allergie-Hinweise versprechen nie Freiheit von einem Allergen („Kann … enthalten“, „Prüf die Zutaten trotzdem
  selbst“).
- Über dem Ziel: Zahl plus „kcal drüber“ in #A8521A mit `exclamationmark.triangle.fill`. Kein Rot, keine Wertung, Ring
  voll.
- Markenname nur über `AppBrand` (`{app}` = Avo, `{pro}` = Avo Pro, `{assistant}` = Avo).
- Plural-Texte stehen hier in ICU-Schreibweise. Solange `context.tr` das nicht kann (Anfrage A-L1), wird daraus je ein
  Schlüssel `…_one` und `…_other`.
- Ein Schlüssel, der in zwei Tabellen steht (`cal_set_goal`, `cal_not_now`), wird einmal angelegt; doppelte Schlüssel
  sind in den `const`-Karten ein Compile-Fehler.

### 3.4 Bewegung (Federn aus `AppMotion` von A)

| Was | Feder | Reduce Motion |
|---|---|---|
| Zahlen (übrig, Makros, Wasser, Mengen, Ø, Gewicht) | `RollingNumber` mit `springDigits` | ganze Zahl blendet über |
| Ring und Balken | folgen mit `springDigits` vom aktuellen Wert aus (unterbrechbar) | springen ohne Bewegung auf den neuen Wert |
| Neue Zeile, gelöschte Zeile | wächst bzw. schrumpft mit `springStandard` | Überblendung |
| Tag wechseln (Wischen) | 1:1 mit dem Finger, Ziel aus der Wurfprojektion, `springFling` mit Fingergeschwindigkeit, Gummiband rechts von „Heute“ | Überblendung, kein Wischen nötig (Aktionen) |
| Scanner-Rahmen rastet ein | `springQuick` | Rahmen erscheint am Code |
| `plus.circle` → Häkchen | `springQuick` | Überblendung |
| Menü verwandelt sich in Kalender | Menü-Übergang von A | Überblendung |

Keine Endlos-Animationen. Ausnahme: die Glas-Pille „Wird geschätzt …“ auf S5 pulsiert sanft (Deckkraft), mit Reduce
Motion steht sie still.

### 3.5 Haptik (über `AppHaptics` von A, nie `HapticFeedback` im Screen)

| Ereignis | Haptik |
|---|---|
| Eintrag gespeichert (auch aus „Zuletzt gegessen“, Rezept, Avo nach Bestätigung), Wasser hinzugefügt, Barcode erkannt, Challenge-Check-in | leichter Impuls, im Frame, in dem die Zeile erscheint |
| Feste Challenge geschafft | Erfolg |
| Tag oder Woche per Wischen gewechselt, Stepper, Segment gewechselt | Auswahl |
| Allergen erkannt | Warnung, einmal pro Schätzung |
| Endgültig nicht gespeichert, Schätzung fehlgeschlagen | Fehler |
| Öffnen von Screens, Menüs, Feldern; Auslöser der Kamera | keine |

### 3.6 Rückgängig-Hinweis (`UndoToast` von A)

- Glas-Kapsel über der Tab-Leiste bzw. über der unteren Kapsel, ein Satz plus Text-Knopf „Widerrufen“ / „Undo“.
- Sichtbar 4 s, mit VoiceOver 10 s (00 Kap. 14). Die Zeit läuft nicht, solange der VoiceOver-Fokus auf dem Hinweis
  liegt.
- VoiceOver: Ansage beim Erscheinen (höflich, Fokus springt nicht), danach erreichbar als Element „{Satz}. Widerrufen,
  Taste“. Zusätzlich ist „Widerrufen“ als eigene Aktion am geänderten Element (Zeile, Wasser) erreichbar, solange der
  Hinweis steht.
- Health-Werte werden erst nach Ablauf des Hinweises gelöscht (Konzept 15 5.5).
- Wo Rückgängig reicht, gibt es keinen Bestätigungsdialog. Bestätigt wird nur „Challenge abbrechen“ und „Alle
  Essensfotos löschen“.

### 3.7 Kontrast (WCAG 2.1 AA, berechnet aus den D2-Werten)

| Element | Vorne | Hinten | Wert | Nötig | Ergebnis und Lösung |
|---|---|---|---|---|---|
| Ring, Kohlenhydrat-Balken, Wochenbalken | #E8833A | #FFFFFF | 2,71:1 | 3:1 (Grafik) | zu schwach. Vorschlag Token `calRing` = #C8641A (3,97:1 auf Weiß, 3,37:1 auf der Spur). Zahl und Text tragen die Information ohnehin, der Ring ist in VoiceOver ausgeblendet (Owner-Frage 2) |
| Destruktiver Text | #FF3B30 | #FFFFFF | 3,55:1 | 4,5:1 | nicht für Text. #D70015 (5,38:1) |
| Weiße Schrift auf getönter Kapsel 88 % über Weiß | #FFFFFF | #3A8A52 | 4,25:1 | 4,5:1 (17 pt Semibold ist kein großer Text) | Kapsel auf hellem Grund mit 96 % Deckkraft wie auf D2-Home (4,99:1); Anfrage A-T2 |
| Sekundärtext auf `fill` über #F2F2F7 (Stepper, Segment außerhalb weißer Gruppen) | #6C6C70 | #E3E3E9 | 4,09:1 | 4,5:1 | in Bedienelementen immer #1C1C1E; Sekundär auf `fill` nur innerhalb weißer Gruppen (4,55:1) |
| Leere Wasser-Tropfen | #DCDCE1 | #FFFFFF | 1,37:1 | 3:1 | leere Tropfen als Kontur 1,5 pt in #8E8E93 (3,26:1), gefüllt als Fläche; Text „1,25 / 2 l“ trägt die Zahl |
| Sekundärtext auf Glas über Kamera | #6C6C70 | ca. #A3A3A3 | 2,07:1 | 4,5:1 | auf Kameras nur #1C1C1E auf Glas (6,75:1) oder Weiß auf dunkler Kapsel |
| Hinweistext auf Kamera | #FFFFFF | Kamerabild | wechselnd | 4,5:1 | Text auf dunkler Kapsel rgba(0,0,0,.6) (mindestens 5,7:1 bei weißem Motiv); Anfrage A-T4 |
| Warn-Text „kcal drüber“ | #A8521A | #FFFFFF | 5,40:1 | 4,5:1 | gut; iOS-Orange #FF9500 nicht für Text |
| Protein-Balken, Wasser | #3B82F6 | #FFFFFF | 3,68:1 | 3:1 | gut für Grafik, nie als Text (Text-Blau wäre #2563EB, 5,17:1) |
| Fett-Balken | #A855F7 | #FFFFFF | 3,96:1 | 3:1 | gut |
| Health-Herz | #FF2D55 | #F2F2F7 | 3,27:1 | 3:1 | gut, dekorativ neben Text |
| Kicker | #A8521A | #FFFFFF | 5,40:1 | 4,5:1 | gut |
| Akzent-Text | #1F7A3A | #FFFFFF / #F2F2F7 | 5,38:1 / 4,82:1 | 4,5:1 | gut |
| Sekundär | #6C6C70 | #FFFFFF / #F2F2F7 | 5,23:1 / 4,69:1 | 4,5:1 | gut |

Erhöhter Kontrast: Glas bekommt eine 1-pt-Kontur, Sekundärtext #3A3A3C, Ring #A8521A. Dunkle Werte prüft A beim
Token-Set (Anfrage A-T3).

### 3.8 Trefferflächen

Alles, was man antippt, hat mindestens 44 × 44 pt. D2-Chips (34 sichtbar) und Stepper-Knöpfe sitzen in 44-pt-Zielen,
das Segmented Control ist 44 hoch. „Eintragen“ je Mahlzeit ist eine ganze Zeile (52 pt), nicht ein 30-pt-Plus wie
heute. `plus.circle` in Zeilen ist 22 pt groß, die Trefferfläche 44 × 44 am rechten Rand. Glas-Knöpfe auf Kameras
haben ab AX1 den Large Content Viewer.

### 3.9 Große Schrift und 320 pt

- Kein abgeschnittener Text bei 320, 375, 390, 402 und 440 pt Breite und L, xxxL, AX3, AX5 (Prüfmatrix von A in
  `test/layout/`, B-Tests in `test/layout/screens/b/`). Ellipse nur im eingeklappten Inline-Titel.
- `numberXL` höchstens 51 pt; Zahl im Ring der Home-Karte höchstens 28 pt (sonst sprengt sie den Ring), ab xxxL steht
  die Zahl unter dem Ring statt darin.
- Ab xxL: Segmente, die nicht passen, werden ein Pull-down mit `chevron.up.chevron.down` (A-Baustein). Stepper rutscht
  unter sein Feld. Zwei Knöpfe nebeneinander stehen untereinander.
- Ab AX1: Gruppen randlos (volle Breite, kein Radius), Zeilen stapeln (Wert unter den Titel, kcal unter den Namen),
  Bilder in Zeilen entfallen, Avo-Figuren in leeren Zuständen entfallen, Makro-Zeilen stapeln, Diagramm-Achsen werden
  eine Textzeile unter dem Diagramm („Mo 1.910 · Di 2.080 · Mi – · …“), das Kalender-Raster wird ein Rad.
- 320 pt bei L: Ring und Textblock passen nebeneinander (Ring 112 bzw. 120, Abstand 16, Text ab 120 pt), die
  Unterzeile rutscht unter beide.

### 3.10 VoiceOver-Grundregeln

- Jede Zeile ist ein Element mit vollem Satz; Wisch- und Kontextmenü-Aktionen sind eigene Aktionen
  (`customSemanticsActions`).
- Werte, die man mit Wischen hoch/runter ändert (Tag, Stepper), sind einstellbare Elemente (`onIncrease`,
  `onDecrease`, `increasedValue`, `decreasedValue`), nicht `slider`.
- Ring, Balken, Tropfen, Punkte und Avo-Figuren sind ausgeblendet, wenn ein Text dieselbe Zahl sagt. Diagramme lesen
  zuerst einen Satz vor, danach die Balken als Elemente.
- Großbuchstaben-Köpfe („KALORIEN“, „FRÜHSTÜCK“) werden in normaler Schreibung vorgelesen (Label ohne Großbuchstaben,
  Großschreibung nur im Textstil), sonst buchstabiert VoiceOver.
- „kcal“ wird „Kilokalorien“ / „calories“ vorgelesen, „g“ „Gramm“ / „grams“, „l“ „Liter“ / „litres“, „Kohlenh.“
  „Kohlenhydrate“.
- Live-Änderungen (Zahl nach dem Eintragen, Barcode erkannt, Schätzung fertig) werden mit `SemanticsService.announce`
  angesagt, einmal, nach dem vollständigen Satz.
- Fokus-Reihenfolge folgt der Leserichtung: Toolbar links, Titel, Toolbar rechts, Inhalt von oben nach unten, untere
  Kapsel zuletzt. Nach dem Öffnen eines Screens liegt der Fokus auf dem Titel; nach dem Schließen eines V-Screens auf
  dem Element, das ihn geöffnet hat.

### 3.11 Reduce Motion, Transparenz reduzieren, fetter Text

- Reduce Motion: siehe 3.4.
- Transparenz reduzieren (nativer Kanal `shoply/accessibility`, B registriert ihn in `AppDelegate.swift`, A nutzt ihn im
  `DesignScope`): `.glass` wird eine feste Fläche #F9F9F9 mit 0,5-pt-Kontur #C7C7CC, `.glass-tint` wird festes
  #1F7A3A, die Scroll-Kante wird eine feste #F2F2F7-Fläche. Auf Kameras werden Glas-Gruppen festes #1C1C1E mit weißen
  Symbolen.
- Fetter Text (`MediaQuery.boldTextOf`): Prüfmatrix läuft mit und ohne; nichts darf deshalb umbrechen und abschneiden.

### 3.12 Avo-Figur

Höchstens eine Figur pro Bildschirmhöhe, immer die echte 3D-Figur aus `assets/avo/`, in Anzeigegröße dekodiert. Nie
bei Fehlern, Offline, Löschen, Allergie, Körpergewicht oder Gesundheitsdaten-Erklärung.

| Ort | Pose | Größe | Ab |
|---|---|---|---|
| S1a Tagebuch ohne Ziel | `avo_waving` (erster Schritt) | 96 pt hoch | ab AX1 weg |
| S3 Suche ohne Treffer | `avo_thinking` | 96 pt | ab AX1 weg |
| S5 während der Schätzung | `avo_thinking` als Mini-Figur 22 × 27 in der Glas-Pille (wie D2-Hero „Avo freut sich“) | 22 × 27 | ab AX3 nur Text |
| S19 feste Challenge geschafft (`SuccessMoment`) | `avo_celebrating` | 120 pt | ab AX3 weg |
| S21 kein passendes Rezept | `avo_thinking` | 96 pt | ab AX1 weg |
| alle anderen Screens und Zustände | keine | | |

Die Home-Karte trägt keine Figur; Home hat seine Avo-Karte weiter oben (A achtet auf eine Figur pro Bildschirmhöhe).

### 3.13 Glas pro Screen

Höchstens drei Glas-Flächen gleichzeitig: Toolbar oben, untere Kapsel oder Tab-Leiste, Rückgängig-Hinweis. Kameras:
zwei Glas-Gruppen über der Kamera-Ansicht (Platform View ohne Glas). Getönte Kapsel: genau eine pro Screen (die
Hauptaktion).

---

## 4. Screens

Jeder Screen: Zweck, Route, Aufbau von oben nach unten, Zustände mit Texten, Interaktion, Barrierefreiheit, Daten,
Avo. Was in Abschnitt 3 steht, gilt zusätzlich und wird nicht wiederholt.

### S0 Home: Karte „Kalorien heute“, Kachel „Wasser heute“, Hinweis

**Zweck.** Auf einen Blick sehen, wie viel heute noch geht, und mit einem Tipp etwas eintragen.

**Route.** Keine. B liefert drei Widgets, A setzt sie auf Home (D2-FuerDich) und ordnet sie (`home_nudge_card_order.dart`,
Anfrage A-H1). Jedes rendert `SizedBox.shrink()`, wenn `moduleEnabledProvider(AppModule.calories)` aus ist. Inhalt
im ersten Frame aus dem lokalen Schnappschuss, damit oberhalb der Leseposition nichts nachträglich einspringt.

**Aufbau `CaloriesHomeCard` (D2 Abschnitt 6).**

1. Weiße Karte, Radius 26, Innenabstand 16, Abstand 24 nach oben, 16 seitlich, Schatten `0 1px 2px rgba(0,0,0,.04)`.
2. Kicker 11/13 Bold, Laufweite +0,5, #A8521A: „KALORIEN“ (`cal_home_kicker`).
3. Titel 20/25 Semibold „Heute“, darunter 13/18 #6C6C70 „1.360 gegessen · Ziel 2.000“ (in D2 nicht vorhanden, Inhalt aus
   Konzept 4.1).
4. Zeile mit 16 pt Abstand: links Ring 112 (Strich 12) mit Mitte „640“ 22/28 Bold und „kcal übrig“ 12/16 #6C6C70;
   rechts drei `MacroRow`s mit 11 pt Abstand: „Protein“ / „82 von 133 g“, „Kohlenhydrate“ / „166 von 227 g“, „Fett“ /
   „41 von 62 g“, Label 13/18 #1C1C1E, Wert 13/18 #6C6C70, Balken 6 pt (Blau, Orange, Lila).
5. 16 pt darunter getönte Kapsel 50 (Radius 25, Grün 96 %), Symbol `plus` 16, „Essen eintragen“. Öffnet S3 mit der
   Mahlzeit nach Uhrzeit.
6. 12 pt darunter Fußzeile (nur heute, Ziel gesetzt, mindestens 150 kcal übrig, mindestens ein Rezept mit Nährwerten):
   zwei Mini-Rezeptbilder 20 (Radius 6, 2-pt-Weißrand, um 4 pt überlappend) und 13/18 #6C6C70 „Was passt noch?
   6 Rezepte“. Die ganze Zeile ist ein 44-pt-Ziel und öffnet S21.
7. Tippen auf Kopf, Ring oder Makros öffnet S1 (eine Trefferfläche über Zeilen 2 bis 4).

**Aufbau `WaterTile` (D2 Kachel „Wasser heute“).** Kachel 148 hoch, Radius 22, Innenabstand 14, im 2-Spalten-Raster von
„Für dich“. Oben links Symbol-Kachel 32 (Radius 9, #E8F0FE) mit Tropfen #3B82F6; oben rechts ein 44-pt-Ziel mit
getöntem 32-pt-Kreis und `plus` 14 (wie die D2-Kachel „Nochmal kaufen“, Owner-Frage 6), fügt die Schnelltaste
(Standard 250 ml) hinzu. Unten: „Wasser heute“ 13/18 Semibold #6C6C70, „1,25 / 2 l“ 20/25 Bold, Tropfenreihe 12 × 14
mit 4 pt Abstand (gefüllt = Glas getrunken, leer = Kontur, Anzahl = Ziel ÷ Schnelltaste, höchstens 12; darüber nur der
Balken 4 pt). Tippen auf die Kachel öffnet `/calories?focus=water`.

**Aufbau `CalorieIdeasHint`.** Hinweiszeile im Stil der A-Hinweise, nur 16 bis 21 Uhr, Ziel gesetzt, mindestens
150 kcal übrig und ein passendes Rezept im lokalen Cache: `flame` 17 #6C6C70, „Noch 640 kcal heute. Ideen fürs
Abendessen“, Chevron. Öffnet S21. „Heute ausblenden“ als Wischaktion. Ob er erscheint, steht im ersten Frame fest
(A-Anfrage 5 aus `status-A.md`).

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Normal | wie oben |
| Heute noch nichts | Mitte „2.000“ / „kcal übrig“, Ring leer, Unterzeile „Noch nichts gegessen · Ziel 2.000“, Makros „0 von 133 g“ |
| Über dem Ziel | Mitte „120“ / „kcal drüber“ in #A8521A mit Warn-Symbol 12 pt, Ring voll, Fußzeile entfällt |
| Kein Ziel | Titel „Heute“, Satz „Wie viel willst du am Tag essen?“ 15/20, Kapsel „Ziel einrichten“ (öffnet S14); hat der Tag Einträge, darunter „1.360 kcal gegessen“; kein Ring, keine Makros |
| Wartet / offline | `arrow.triangle.2.circlepath` 13 pt hinter der Unterzeile; keine `StatusRow` auf Home |
| Fehler ohne lokalen Stand | Karte bleibt gleich hoch: „Kalorien von heute konnten nicht geladen werden.“ 15/20 und Text-Knopf `retry`; „Essen eintragen“ bleibt nutzbar (Warteschlange) |
| Erster Start ohne lokalen Stand | Tonflächen in Form der Karte, nur bis zur ersten Antwort |
| Modul aus | `SizedBox.shrink()`, auch Kachel und Hinweis |
| Pro | nie gesperrt |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_home_kicker` | Kalorien | Calories |
| `cal_today` | Heute | Today |
| `cal_eaten_goal` | {eaten} gegessen · Ziel {goal} | {eaten} eaten · goal {goal} |
| `cal_nothing_eaten_goal` | Noch nichts gegessen · Ziel {goal} | Nothing eaten yet · goal {goal} |
| `cal_unit_left` | kcal übrig | kcal left |
| `cal_unit_over` | kcal drüber | kcal over |
| `cal_unit_eaten` | kcal gegessen | kcal eaten |
| `cal_macro_protein` | Protein | Protein |
| `cal_macro_carbs` | Kohlenhydrate | Carbs |
| `cal_macro_fat` | Fett | Fat |
| `cal_macro_of` | {eaten} von {goal} g | {eaten} of {goal} g |
| `cal_add_food` | Essen eintragen | Log food |
| `cal_what_fits` | Was passt noch? | What still fits? |
| `cal_recipes_count` | {n, plural, =1{1 Rezept} other{# Rezepte}} | {n, plural, =1{1 recipe} other{# recipes}} |
| `cal_home_no_goal` | Wie viel willst du am Tag essen? | How much do you want to eat each day? |
| `cal_set_goal` | Ziel einrichten | Set a goal |
| `cal_home_error` | Kalorien von heute konnten nicht geladen werden. | Couldn't load today's calories. |
| `cal_water_today` | Wasser heute | Water today |
| `cal_water_tile_value` | {amount} / {goal} l | {amount} / {goal} L |
| `cal_water_add_a11y` | {ml} ml Wasser hinzufügen | Add {ml} ml of water |
| `cal_water_added` | {ml} ml Wasser eingetragen | Added {ml} ml of water |
| `cal_hint_ideas` | Noch {kcal} kcal heute. Ideen fürs Abendessen | {kcal} kcal left today. Dinner ideas |

**Barrierefreiheit.**

- Karte als Container mit Überschrift „Kalorien heute“. Ein Element für Kopf, Ring und Makros: „Kalorien heute: 640 von
  2.000 übrig, 1.360 gegessen. Protein 82 von 133 Gramm, Kohlenhydrate 166 von 227 Gramm, Fett 41 von 62 Gramm.“ /
  „Calories today: 640 of 2,000 left, 1,360 eaten. Protein 82 of 133 grams, carbs 166 of 227 grams, fat 41 of 62 grams.“
  Hinweis „Öffnet das Tagebuch“ / „Opens your diary“. Danach Kapsel „Essen eintragen, Taste“, danach Fußzeile „Was passt
  noch? 6 Rezepte, Taste“.
- Kachel: „Wasser heute, 1,25 von 2 Litern. 5 von 8 Gläsern.“ plus eigenes Element „250 ml Wasser hinzufügen, Taste“.
- 320 pt: Ring 112 und Makros passen bis L nebeneinander (Makro-Spalte 160 pt). Ab xxxL stehen die Makros unter dem
  Ring, die Zahl rutscht aus dem Ring darunter („640 kcal übrig“ in einer Zeile 20/25 Bold). Ab AX1 entfallen
  Mini-Bilder, die Kachel wächst in der Höhe statt abzuschneiden (Raster wird einspaltig, A).
- Reduce Motion: Zahl blendet über, Ring springt.

**Daten.** `dailyLogProvider(today)` (neu, Familie mit lokalem Stand, siehe 7), `nutritionGoalProvider`,
`dailyWaterTotalProvider(today)`, `calorieRecipeSuggestionsProvider` (nur Anzahl und zwei Bilder), Einstellung
Schnelltaste (`calorieSettingsProvider`, neu). Für den ersten Frame: Home-Schnappschuss Kalorien (neu, synchron aus
dem lokalen Speicher).

**Avo.** Keine Figur.

---

### S1 Tagebuch `/calories`

**Zweck.** Wie viel kann ich heute noch essen, was habe ich gegessen, und schnell etwas eintragen oder korrigieren.

**Route.** Wurzel des Bereichs, Push im Home-Tab, Tab-Leiste sichtbar. `?date=` zeigt einen anderen Tag, `?focus=water`
scrollt die Wasser-Zeile in die Mitte und setzt den VoiceOver-Fokus darauf.

**Aufbau.**

1. Toolbar (54 pt): links Glas-Knopf 44 `chevron.left` „Zurück“; rechts getönter Primär-Kreis 44 `plus`
   „Essen eintragen“ (öffnet S3 mit der Mahlzeit nach Uhrzeit und dem angezeigten Tag).
2. Großer Titel 34/41 „Kalorien“.
3. Datumszeile 8 pt darunter, 15/20 #1C1C1E: „Heute, Sa., 7. Nov.“ mit `chevron.down` 13 Semibold #6C6C70. Die ganze
   Zeile (44 pt hoch) ist eine Taste und öffnet S2. Auf einem anderen Tag: „Do., 5. Nov.“ und rechts Text-Knopf „Heute“.
4. `StatusRow` bei Bedarf (offline, wartet, Fehler).
5. Tipp-Zeile Apple Health (einmalig, ab dem zweiten Tag mit Einträgen, nie zusammen mit einer `StatusRow`, nur wenn
   Health verfügbar und nicht verbunden): Zeile in weißer Gruppe, `heart` 17 #6C6C70, Text 15/20, rechts Text-Knopf
   „Verbinden“ (öffnet S22); Wischen nach links „Ausblenden“.
6. Gruppe „Heute“ ohne Kopf = `CaloriesTodaySummary` groß, Innenabstand 16:
   - Zeile 1 (mindestens 152 hoch): links Textblock „640“ in `numberXL`, darunter „kcal übrig“ 17/22 Semibold, darunter
     „1.360 gegessen · Ziel 2.000“ 15/20 #6C6C70; rechts Ring 120 ohne Zahl (Wert gegessen ÷ Ziel).
   - Drei `MacroRow`s in voller Breite (wie S0), 12 pt Abstand.
   - Zeile `NavRow` 52 (nur heute und mindestens 150 kcal übrig): `fork.knife` 17 #6C6C70, „Was passt noch?“, Wert
     „6 Rezepte“, Chevron. Öffnet S21.
7. Vier `MealSection`s in der Reihenfolge des Tages: FRÜHSTÜCK, MITTAGESSEN, SNACKS, ABENDESSEN. Kopf GROSS 13/18 mit
   Summe rechts „420 kcal“ (entfällt, wenn leer).
   - `FoodEntryRow` (mindestens 60 hoch): links Bild 44 Radius 10, wenn der Eintrag ein Foto oder Produktbild hat. Hat
     irgendeine Zeile der Mahlzeit ein Bild, reservieren alle Zeilen dieser Mahlzeit den 44-pt-Platz (leer, ohne graue
     Fläche), damit die Textkante gerade bleibt. Name 17/22 (bricht um), Unterzeile 15/20 #6C6C70 („60 g“, „1 Teller ·
     geschätzt“, „250 g · Milbona“), rechts „220“ 17/22 tabellarisch und „kcal“ 15/20 #6C6C70.
   - Letzte Zeile jeder Mahlzeit (52 hoch): `plus` 17 Grün und „Eintragen“ 17/22 Grün. Öffnet S3 mit dieser Mahlzeit.
     Eine leere Mahlzeit besteht nur aus dieser Zeile.
8. Gruppe WASSER: `WaterRow` (64 hoch): `drop.fill` 20 #3B82F6, „1,25 l von 2 l“ 17/22 (Zahl Semibold), darunter
   Balken 4 pt #3B82F6 über die Textbreite; rechts Chip „+250 ml“ (inaktiver Filter-Chip, 34 sichtbar, 44 Ziel).
   Unterzeile „davon 0,5 l aus Health“, wenn Health-Wasser anderer Apps dabei ist.
9. Gruppe DIESE WOCHE: Kopfzeile als Taste „Diese Woche“ 17/22 Semibold mit Chevron (öffnet S15), darunter
   „Ø 1.925 kcal · 4 von 4 Tagen im Ziel“ 15/20, darunter `BarChart` 120 hoch: 7 Säulen Mo bis So, eckig (oben höchstens
   Radius 4), alle in `calRing` (keine blassen Säulen, sonst fällt der Kontrast unter 3:1); Achsentext 13/18, heute
   Semibold #1C1C1E, die anderen Tage #6C6C70; Ziellinie 1 pt gestrichelt #6C6C70 mit „2.000“ 12/16 am rechten Ende;
   nicht erfasste Tage und die Zukunft ohne Säule, nur mit dem Wochentag darunter.
10. Gruppe ohne Kopf, vier `NavRow`s 52 mit Symbol 17 #6C6C70 frei (ohne Kachel): `scalemass` „Gewicht“ · „72,4 kg“,
    `figure.run` „Workouts“ · „32 Min heute“, `flag` „Challenges“ · „16:8 · Tag 5“, `target` „Ziele“ · „2.000 kcal“.
11. Unterer Abstand `ShellInsets.bottom` (A), Scroll-Kante hinter der Tab-Leiste.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Ziel, heute nichts | „2.000“ / „kcal übrig“, „Noch nichts gegessen · Ziel 2.000“, Ring leer, Makros „0 von 133 g“, alle Mahlzeiten nur „Eintragen“; kein leerer Zustand, keine Figur |
| Kein Ziel | S1a |
| Lädt | lokaler Stand sofort; nur ohne lokalen Stand Tonflächen in Form von „Heute“ und zwei Mahlzeiten |
| Fehler ohne lokalen Stand | statt der Gruppen: „Das Tagebuch konnte nicht geladen werden.“ und `retry`; Toolbar-Plus bleibt nutzbar |
| Offline ohne lokalen Stand | „Offline. Dein Tagebuch erscheint, sobald du wieder online bist.“, ohne Knopf, lädt selbst, sobald online |
| Offline mit Stand | `StatusRow` offline, neue Zeilen mit Sync-Zeichen; „Was passt noch?“ zählt nur lokal gespeicherte Rezepte |
| Über dem Ziel | „120“ / „kcal drüber“ in #A8521A mit Warn-Symbol, Ring voll, „Was passt noch?“ entfällt |
| Vergangener Tag | „1.950“ / „kcal gegessen“, „Ziel 2.000 · 50 unter Ziel“ (bzw. „120 über Ziel“); „Was passt noch?“ entfällt; Woche dieses Tages |
| Health abgelehnt | Workout-Zeile zählt nur eigene Workouts, kein Hinweis hier |
| Workouts gutschreiben an | Unterzeile „1.360 gegessen · Ziel 2.000 + 280 Laufen“ |
| Eintrag auf anderem Gerät gelöscht | Zeile schrumpft weg, ohne Hinweis |
| Modul aus | S24 |
| Pro | Tagesansicht nie gesperrt |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_title` | Kalorien | Calories |
| `cal_date_today` | Heute, {date} | Today, {date} |
| `cal_date_yesterday` | Gestern, {date} | Yesterday, {date} |
| `cal_jump_today` | Heute | Today |
| `cal_health_tip` | Verbinde Apple Health, dann kommen Gewicht und Workouts deiner Apple Watch von selbst dazu. | Connect Apple Health to bring in weight and workouts from your Apple Watch. |
| `cal_health_tip_action` | Verbinden | Connect |
| `cal_hide` | Ausblenden | Hide |
| `cal_past_goal_under` | Ziel {goal} · {diff} unter Ziel | Goal {goal} · {diff} under |
| `cal_past_goal_over` | Ziel {goal} · {diff} über Ziel | Goal {goal} · {diff} over |
| `cal_credit_line` | {eaten} gegessen · Ziel {goal} + {kcal} {workout} | {eaten} eaten · goal {goal} + {kcal} {workout} |
| `cal_meal_breakfast` | Frühstück | Breakfast |
| `cal_meal_lunch` | Mittagessen | Lunch |
| `cal_meal_snack` | Snacks | Snacks |
| `cal_meal_dinner` | Abendessen | Dinner |
| `cal_meal_sum` | {kcal} kcal | {kcal} kcal |
| `cal_log` | Eintragen | Log food |
| `cal_estimated_suffix` | geschätzt | estimated |
| `cal_water` | Wasser | Water |
| `cal_water_of` | {amount} l von {goal} l | {amount} L of {goal} L |
| `cal_water_from_health` | davon {amount} l aus Health | {amount} L from Health |
| `cal_week_this` | Diese Woche | This week |
| `cal_week_line` | Ø {avg} kcal · {n} von {m} Tagen im Ziel | Avg {avg} kcal · {n} of {m} days on target |
| `cal_week_empty` | Noch keine Woche erfasst. | No week logged yet. |
| `cal_nav_weight` | Gewicht | Weight |
| `cal_nav_workouts` | Workouts | Workouts |
| `cal_workouts_today` | {min} Min heute | {min} min today |
| `cal_workouts_none_today` | Keine heute | None today |
| `cal_nav_challenges` | Challenges | Challenges |
| `cal_challenge_day` | {name} · Tag {n} | {name} · day {n} |
| `cal_challenges_none` | Keine aktiv | None active |
| `cal_nav_goals` | Ziele | Goals |
| `cal_deleted` | {name} gelöscht | {name} deleted |
| `cal_menu_edit` | Bearbeiten | Edit |
| `cal_menu_move` | Zu anderer Mahlzeit | Move to another meal |
| `cal_menu_again` | Heute nochmal eintragen | Log again today |
| `cal_menu_delete` | Löschen | Delete |
| `cal_diary_error` | Das Tagebuch konnte nicht geladen werden. | Couldn't load your diary. |
| `cal_diary_offline_empty` | Offline. Dein Tagebuch erscheint, sobald du wieder online bist. | You're offline. Your diary will appear once you're back online. |

Fehlender Wert in einer `NavRow` (kein Gewicht): grauer Strich „–“ in Wertgröße 15/20, nicht in 17 pt fett.

**Interaktion.**

- Tag wechseln per waagerechtem Wischen nur auf Datumszeile und Gruppe „Heute“ (1:1, Griffabstand bleibt, Wurfprojektion,
  `springFling`, Auswahl-Haptik beim Einrasten, Gummiband rechts von heute). Die Gruppen darunter wechseln mit
  Überblendung, sie sind vorgeladen. Der Rest des Screens wischt nicht, damit Zeilen-Wischen und Zurück-Wischen frei
  bleiben.
- Säule antippen zeigt den Tag; langes Ziehen über das Diagramm zeigt den Wert in einer Zeile über dem Diagramm
  („Do., 5. Nov.: 1.760 kcal“), Auswahl-Haptik pro Säule.
- Eintrag antippen öffnet S9. Wischen nach links: „Löschen“ (#D70015, volles Wischen löscht sofort, leichter Impuls an
  der Schwelle), Rückgängig „Spaghetti Bolognese gelöscht“. Langdruck: Kontextmenü „Bearbeiten“, „Zu anderer Mahlzeit“
  (Untermenü mit den drei anderen), „Heute nochmal eintragen“ (nur auf vergangenen Tagen), „Löschen“.
- Nach jedem Eintragen rollt „640“, Ring und Balken folgen, die Zeile wächst in ihrer Mahlzeit ein, leichter Impuls im
  selben Frame. Beim bloßen Zurückkehren keine Haptik.
- Wasser-Chip und Langdruck: S12.
- Pull-to-Refresh: Systemverhalten, lädt den Tag neu.

**Barrierefreiheit.**

| Element | Vorgelesen (Deutsch) | English |
|---|---|---|
| Datumszeile | Datum: Heute, Samstag, 7. November. Taste. Hinweis: Tag wechseln | Date: Today, Saturday, November 7. Button. Hint: change day |
| Gruppe „Heute“ (einstellbar) | Kalorien heute: 640 von 2.000 übrig, 1.360 gegessen. Wischen nach oben oder unten wechselt den Tag. | Calories today: 640 of 2,000 left, 1,360 eaten. Swipe up or down to change the day. |
| Makro | Protein, 82 von 133 Gramm | Protein, 82 of 133 grams |
| Eintrag | Spaghetti Bolognese, geschätzt, 650 Kilokalorien, Mittagessen. Aktionen: Bearbeiten, Mahlzeit ändern, Löschen | Spaghetti Bolognese, estimated, 650 calories, lunch. Actions: Edit, Change meal, Delete |
| Mahlzeitkopf | Frühstück, 420 Kilokalorien, Überschrift | Breakfast, 420 calories, heading |
| „Eintragen“-Zeile | Frühstück eintragen, Taste | Log breakfast, button |
| Diagramm | Diese Woche im Schnitt 1.925 Kilokalorien an 4 Tagen, Ziel 2.000. Danach je Säule: Montag, 1.910 Kilokalorien; Mittwoch, nicht erfasst | This week an average of 1,925 calories over 4 days, goal 2,000. Then per bar: Monday, 1,910 calories; Wednesday, not logged |

Fokus-Reihenfolge: Zurück, Titel, Plus, Datumszeile, `StatusRow`, Tipp-Zeile, „Heute“, Makros, „Was passt noch?“,
Mahlzeiten von oben, Wasser, Woche, Nav-Zeilen.

Große Schrift: 320 pt siehe 3.9; ab xxxL Ring unter dem Textblock, linksbündig; ab AX1 Gruppen randlos, Makros
gestapelt („Protein“ über „82 von 133 g“), Bilder weg, kcal unter dem Namen, „+250 ml“ unter dem Wasser-Text,
Diagramm-Achsen als Textzeile. Bei L passt die Gruppe „Heute“ auf dem iPhone SE vollständig über den Falz.

**Daten.** `dailyLogProvider(date)` (neu: Einträge, Summen, Wasser, Sync-Status je Zeile, lokal zuerst; ersetzt
`selectedLogDateProvider`, `dailyFoodLogProvider`, `dailyNutritionTotalsProvider`, `dailyWaterTotalProvider`),
`nutritionGoalProvider` (muss bei Netzfehler werfen statt `null`), `weekSummaryProvider(weekStart)` (neu, Summen statt
ganzer Zeilen), `weightLatestProvider`, `workoutsTodayProvider` (neu, eigene + Health lokal), `activeChallengesProvider`
(heute in `diet_challenge_provider.dart`), `whatCanIEatSuggestionsProvider` (nur Anzahl), `healthStatusProvider` (neu,
Kanal `shoply/health`), `connectionStateProvider` und `syncStatusProvider`. Löschen über die Warteschlange mit
`FoodLogService.deleteEntry`; Health-Löschen nach Ablauf des Rückgängig-Hinweises.

**Avo.** Keine Figur (Arbeits-Screen).

---

### S1a Tagebuch ohne Ziel

**Zweck.** Beim ersten Öffnen erklären, wofür das Ziel gut ist, und es in einer Minute einrichten lassen. Nur wenn das
Modul an ist und wirklich kein Ziel gespeichert ist (nie bei Netzfehler).

**Aufbau.** Toolbar und großer Titel wie S1, Datumszeile entfällt. Darunter `EmptyState` in einer weißen Gruppe:
`avo_waving` 96 pt (ab AX1 weg), Titel 20/25 Semibold „Wie viel willst du am Tag essen?“, Satz 17/22 „Aus Größe, Gewicht
und Alltag rechnen wir dein Tagesziel aus. Das dauert etwa eine Minute.“, getönte Kapsel 50 „Ziel einrichten“ (öffnet
S14 mit `from=empty`), Text-Knopf „Ohne Ziel eintragen“ (zeigt das Tagebuch ohne Ziel), Text-Knopf „Kalorien
ausschalten“ (Modul aus, Rückgängig-Hinweis, zurück nach Home).

**Tagebuch ohne Ziel** (nach „Ohne Ziel eintragen“ und solange kein Ziel gesetzt ist): Gruppe „Heute“ zeigt „1.360“ /
„kcal gegessen“, keinen Ring, Makros ohne „von“ („Protein 82 g“, ohne Balken), darunter Zeile „Ziel festlegen“ in Grün
(öffnet S14). Mahlzeiten, Wasser (ohne Ziel: „1,25 l“ ohne Balken), Woche ohne Ziellinie.

**Zustände.** Offline: „Ziel einrichten“ funktioniert (Rechnung lokal, Speichern in der Warteschlange). Mit Health:
Fragebogen in S14 vorbefüllt. Fehler beim Laden des Ziels: S1-Fehlerzustand, nie S1a.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_empty_goal_title` | Wie viel willst du am Tag essen? | How much do you want to eat each day? |
| `cal_empty_goal_body` | Aus Größe, Gewicht und Alltag rechnen wir dein Tagesziel aus. Das dauert etwa eine Minute. | We work out a daily goal from your height, weight and routine. It takes about a minute. |
| `cal_set_goal` | Ziel einrichten | Set a goal |
| `cal_log_without_goal` | Ohne Ziel eintragen | Log without a goal |
| `cal_turn_off` | Kalorien ausschalten | Turn off Calories |
| `cal_turned_off` | Kalorien ausgeschaltet | Calories turned off |
| `cal_macro_plain` | {name} {g} g | {name} {g} g |
| `cal_set_goal_row` | Ziel festlegen | Set a goal |

**Barrierefreiheit.** Figur ausgeblendet. Reihenfolge: Titel der Seite, Überschrift des leeren Zustands, Satz, drei
Knöpfe. Ab AX1 ohne Figur, Knöpfe in voller Breite untereinander.

**Daten.** `nutritionGoalProvider` (drei Zustände: geladen, kein Ziel, Fehler), `appModulesProvider.notifier` für
„ausschalten“.

**Avo.** `avo_waving` 96 pt, einzige Figur.

---

### S2 Datum wählen (Menü auf S1)

**Zweck.** Einen anderen Tag öffnen, ohne Pfeil-Paare und ohne Panel.

**Navigation.** Pull-down-Menü (`AppMenu` von A) an der Datumszeile; kein Sheet.

**Aufbau.** Gruppe 1: „Heute“, „Gestern“, dann die fünf Tage davor („Do., 5. Nov.“); rechts in #6C6C70 die kcal des
Tages („1.760 kcal“), wenn der Tag Einträge hat; der angezeigte Tag mit `checkmark`. Gruppe 2: `calendar` „Datum
wählen …“. Das verwandelt das Menü an Ort und Stelle in das Kalender-Menü (Anfrage A-C3): Kopf „November 2026“ mit
Chevrons 44 („Voriger Monat“, „Nächster Monat“), Tage 44 pt, Punkt 4 pt unter Tagen mit Daten, heute in Grün, gewählter
Tag gefüllter grüner Kreis mit weißer Zahl, Zukunft grau und nicht wählbar. Ab AX1 statt Raster ein Rad (Tag, Monat,
Jahr). Bei 320 pt nutzt das Raster die volle Breite minus 16 pt (Zellen 41 sichtbar, 44 Trefferfläche).

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_date_pick` | Datum wählen … | Choose date… |
| `cal_month_prev` | Voriger Monat | Previous month |
| `cal_month_next` | Nächster Monat | Next month |

**Barrierefreiheit.** Tag im Raster: „Donnerstag, 5. November, 1.760 Kilokalorien“ / „Thursday, November 5,
1,760 calories“; ausgewählt „ausgewählt“; Zukunft „nicht verfügbar“. Menüeinträge sind Systemmenü-Elemente.

**Daten.** `loggedDaysProvider(month)` (neu, Tage mit Daten und kcal-Summe, aus `getRecentLoggedDates` erweitert).
Auch S4, S7, S8, S9, S10, S16, S18 nutzen dieses Menü für ihre Zeile „Datum“.

---

### S3 Essen eintragen `/calories/add` (D2 `X-Essen`)

**Zweck.** Der eine Einstieg für alles Eintragen: suchen und mit einem Tipp eintragen, fotografieren, scannen oder von
Hand eingeben.

**Route.** V-Route, Vollbild über dem Tab, aus dem man kommt. Schließen führt dorthin zurück; nach „Eintragen“ in einem
Folgeschritt auch (Owner-Frage 5).

**Aufbau (D2-Maße).**

1. Kopf (54 pt): links Glas-Knopf 44 `xmark` „Schließen“. Mitte Inline-Titel 17/22 Semibold „Mittagessen eintragen“ mit
   `chevron.down` 11 pt: eine Taste, die ein Pull-down öffnet (Frühstück, Mittagessen, Snacks, Abendessen, aktuelle mit
   `checkmark`). Auf einem anderen Tag zweite Zeile 13/18 #6C6C70 „Für Do., 5. Nov.“, als Taste zum Datums-Menü (S2).
   Rechts 44 pt Platzhalter, damit der Titel mittig bleibt.
2. 14 pt darunter Segmented Control 44 „Foto | Barcode | Suche“ (Radiogruppe „Art der Eingabe“). Start: zuletzt
   genutztes Segment, beim ersten Mal „Suche“ (Owner-Frage 4).
3. Inhalt des Segments (scrollt unter dem Kopf mit Scroll-Kante):

**Segment „Suche“.**

- Suchfeld 48 (weiß, Radius 24), Platzhalter „Lebensmittel oder Marke suchen“, Lupe, Löschen-Knopf 44 bei Text.
  Tastatur nicht automatisch offen (sonst verdeckt sie „Zuletzt gegessen“).
- Gruppe HEUTE IM PLAN (nur mit Modul Wochenplan, heute, Rezept geplant): Zeile 64 mit Rezeptbild 44 Radius 10,
  „Ofengemüse mit Feta“, „1 Portion · 520 kcal“, rechts `plus.circle` 22 in Grün (öffnet S10 vorbefüllt).
- Gruppe ZULETZT GEGESSEN (bis 8, zuletzt und häufig gemischt, ohne Doppelte): Zeile 60, Name 17/22, Unterzeile
  „60 g · 220 kcal“ 15/20 #6C6C70, rechts `plus.circle` 22 in Grün (Ziel 44). Ein Tipp trägt sofort ein: Symbol wird
  `checkmark.circle.fill` (`springQuick`), Unterzeile 2 s „Eingetragen“, leichter Impuls, Rückgängig-Hinweis; der Screen
  bleibt offen. Tippen auf den Text der Zeile öffnet S7 mit dieser Menge. Langdruck: „Andere Menge …“ (öffnet S7),
  „Aus „Zuletzt“ entfernen“.
- Zeile „Manuell eintragen“ (52, `square.and.pencil` 17 #6C6C70, Unterzeile „Name und Kalorien selbst eingeben“,
  Chevron), öffnet S8.
- Beim Tippen: sofort lokale Treffer in ZULETZT GEGESSEN und EIGENE, nach 300 ms Pause darunter LEBENSMITTEL (Open Food
  Facts): Zeile 60 mit Produktbild 44 Radius 10 auf Weiß (nicht freigestellt), Name 17/22, „Milbona · 63 kcal pro
  100 g“ (bei Getränken „pro 100 ml“), Chevron, öffnet S7. Fußzeile 13/18 „Daten: Open Food Facts“ als Link.
  Online-Treffer hängen sich unten an, nichts springt.

**Segment „Foto“.**

- Karte 300 hoch, Radius 26, Fläche `fill`, mittig `camera` 34 #6C6C70, darunter 17/22 „Fotografier deinen Teller von
  oben.“, getönte Kapsel 44 mit `camera.fill` „Foto aufnehmen“ (öffnet S4), Text-Knopf „Aus Fotos wählen“ (System-
  Fotoauswahl ohne Fotos-Berechtigung, danach direkt S5).
- Fußnote 13/18: „Kalorien und Nährwerte werden aus dem Foto geschätzt. Das Foto wird nur dafür verwendet und privat
  gespeichert.“
- Zeile „Heute ist noch eine Foto-Schätzung frei.“ 13/18 #6C6C70 nur, wenn genau eine übrig ist.

**Segment „Barcode“.**

- Karte 300 hoch, Radius 26, Fläche `fill`, `barcode.viewfinder` 34, 17/22 „Halte die Kamera auf den Strichcode der
  Verpackung.“, getönte Kapsel 44 „Kamera öffnen“ (öffnet S6).
- Darunter Gruppe mit Feld „Nummer eingeben“ (Ziffernblock, Platzhalter „13 Ziffern unter dem Strichcode“, Return
  „Suchen“), sucht im lokalen Produkt-Cache, dann bei Open Food Facts, öffnet S7.
- Gruppe ZULETZT GESCANNT (bis 5, auch offline nutzbar), Zeilen wie LEBENSMITTEL.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Erster Start | ZULETZT GEGESSEN entfällt; an seiner Stelle Fußnote „Hier steht bald, was du oft isst. Ein Tipp trägt es dann ein.“ |
| Lädt | lokale Treffer sofort, Online-Treffer unten angehängt, kein Spinner |
| Keine Treffer | `EmptyState` im Inhalt: `avo_thinking` 96 (ab AX1 weg), „Nichts zu „Skyr Natur light“ gefunden.“, getönte Kapsel 44 „Manuell eintragen“ (übernimmt den Suchtext) |
| Fehler Online-Suche | `StatusRow` „Die Online-Suche hat nicht geklappt.“ + `retry`; lokale Treffer bleiben |
| Offline | `StatusRow` „Offline. Du siehst nur eigene und zuletzt gegessene Lebensmittel.“; Foto-Kapsel deaktiviert mit Zeile „Die Foto-Schätzung braucht eine Verbindung.“; Barcode aktiv mit lokalem Cache |
| Kamera ohne Strichcode-Leser (iOS unter 16, Gerät ohne A12) | Barcode-Segment zeigt nur Feld und ZULETZT GESCANNT, Fußnote „Dieses iPhone liest Strichcodes nicht mit der Kamera. Gib die Nummer ein.“ |
| KI-Kill-Switch | Segment „Foto“ entfällt, Control zeigt nur „Barcode“ und „Suche“ |
| Tageslimit Foto, Free | Foto-Karte zeigt „Für heute sind die Foto-Schätzungen aufgebraucht. Morgen geht es wieder, mit Avo Pro bis zu 15 am Tag.“, Kapseln „Manuell eintragen“ (getönt) und Text-Knopf „Avo Pro ansehen“ (`/pro?feature=cal_photo`) |
| Tageslimit Foto, Pro | „Für heute sind die Foto-Schätzungen aufgebraucht. Morgen geht es weiter.“ + „Manuell eintragen“ |
| Pro gesperrt (falls Owner Foto zu Pro macht) | `ProBadge` am Segment „Foto“; Kamera öffnet trotzdem, erst „Schätzen“ auf S5 öffnet die Paywall |
| Modul aus | S24 |
| Schließen ohne Eingabe | kein Dialog (S3 selbst hält keine ungespeicherten Daten) |

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_add_title` | {meal} eintragen | Log {meal} |
| `cal_add_for_date` | Für {date} | For {date} |
| `cal_close` | Schließen | Close |
| `cal_input_method_a11y` | Art der Eingabe | Input method |
| `cal_seg_photo` | Foto | Photo |
| `cal_seg_barcode` | Barcode | Barcode |
| `cal_seg_search` | Suche | Search |
| `cal_search_placeholder` | Lebensmittel oder Marke suchen | Search food or brand |
| `cal_sec_plan_today` | Heute im Plan | Planned for today |
| `cal_sec_recent` | Zuletzt gegessen | Recently eaten |
| `cal_sec_own` | Eigene | Your foods |
| `cal_sec_foods` | Lebensmittel | Foods |
| `cal_sec_recent_scans` | Zuletzt gescannt | Recently scanned |
| `cal_per_100g` | {brand} · {kcal} kcal pro 100 g | {brand} · {kcal} kcal per 100 g |
| `cal_per_100ml` | {brand} · {kcal} kcal pro 100 ml | {brand} · {kcal} kcal per 100 ml |
| `cal_logged` | Eingetragen | Logged |
| `cal_logged_toast` | {name} eingetragen | {name} logged |
| `cal_log_item_a11y` | {name} eintragen | Log {name} |
| `cal_other_amount` | Andere Menge … | Different amount… |
| `cal_remove_recent` | Aus „Zuletzt“ entfernen | Remove from recent |
| `cal_manual_row` | Manuell eintragen | Enter manually |
| `cal_manual_row_sub` | Name und Kalorien selbst eingeben | Type in the name and calories |
| `cal_off_source` | Daten: Open Food Facts | Data: Open Food Facts |
| `cal_recent_first_run` | Hier steht bald, was du oft isst. Ein Tipp trägt es dann ein. | Foods you eat often will show up here. One tap logs them. |
| `cal_search_none` | Nichts zu „{query}“ gefunden. | Nothing found for “{query}”. |
| `cal_search_error` | Die Online-Suche hat nicht geklappt. | Online search didn't work. |
| `cal_search_offline` | Offline. Du siehst nur eigene und zuletzt gegessene Lebensmittel. | You're offline. Only your own and recent foods are shown. |
| `cal_photo_prompt` | Fotografier deinen Teller von oben. | Take a photo of your plate from above. |
| `cal_photo_take` | Foto aufnehmen | Take photo |
| `cal_photo_pick` | Aus Fotos wählen | Choose from Photos |
| `cal_photo_note` | Kalorien und Nährwerte werden aus dem Foto geschätzt. Das Foto wird nur dafür verwendet und privat gespeichert. | Calories and nutrients are estimated from the photo. It's only used for that and stored privately. |
| `cal_photo_offline` | Die Foto-Schätzung braucht eine Verbindung. | Photo estimates need a connection. |
| `cal_photo_one_left` | Heute ist noch eine Foto-Schätzung frei. | One photo estimate left today. |
| `cal_photo_limit_free` | Für heute sind die Foto-Schätzungen aufgebraucht. Morgen geht es wieder, mit {pro} bis zu {n} am Tag. | You've used today's photo estimates. They're back tomorrow, or get up to {n} a day with {pro}. |
| `cal_photo_limit_pro` | Für heute sind die Foto-Schätzungen aufgebraucht. Morgen geht es weiter. | You've used today's photo estimates. They're back tomorrow. |
| `cal_see_pro` | {pro} ansehen | See {pro} |
| `cal_barcode_prompt` | Halte die Kamera auf den Strichcode der Verpackung. | Point the camera at the barcode on the pack. |
| `cal_barcode_open` | Kamera öffnen | Open camera |
| `cal_barcode_enter` | Nummer eingeben | Enter number |
| `cal_barcode_placeholder` | 13 Ziffern unter dem Strichcode | 13 digits under the barcode |
| `cal_barcode_search` | Suchen | Search |
| `cal_barcode_unsupported` | Dieses iPhone liest Strichcodes nicht mit der Kamera. Gib die Nummer ein. | This iPhone can't read barcodes with the camera. Enter the number instead. |

**Barrierefreiheit.**

- Titel-Taste: „Mittagessen eintragen. Mahlzeit ändern, Taste“ / „Log lunch. Change meal, button“.
- Segmente: Radiogruppe „Art der Eingabe“, je „Foto, 1 von 3, ausgewählt“.
- „Zuletzt gegessen“-Zeile: ein Element „Haferflocken, 60 Gramm, 220 Kilokalorien“ mit Standard-Aktion „Eintragen“ und
  Aktionen „Andere Menge“, „Aus Zuletzt entfernen“. Nach dem Tipp Ansage „Haferflocken eingetragen“.
- Deaktivierte Foto-Kapsel: „Foto aufnehmen, nicht verfügbar, braucht eine Verbindung“.
- Fokus: Schließen, Titel, Segmente, Inhalt, Fußzeilen.
- 320 pt: Segmente passen bis L; ab xxL wird das Control ein Pull-down „Eingabe: Suche“ mit `chevron.up.chevron.down`.
  Ab AX1 Gruppen randlos, Bilder weg, `plus.circle` oben bündig zur ersten Textzeile, Karten der Segmente ohne feste
  Höhe (wachsen mit dem Text).

**Daten.** `recentFoodsProvider` (neu, lokal), `userFoodsProvider` (neu, Tabelle `user_food`), `foodSearchProvider(q)`
(Open Food Facts, wirft bei Fehler statt `[]`), `productCacheProvider` (neu, lokal), `planTodayProvider` (B7),
`photoQuotaProvider` (neu, aus `ai_usage_daily_b` und `app_flags.ai_limits`; Lücke, siehe 7), `aiRemoteEnabledProvider`,
`scannerSupportProvider` (neu, Kanal `shoply/scanner`: `DataScannerViewController.isSupported`), letzte Segmentwahl
lokal. Eintragen aus „Zuletzt“ über die Warteschlange mit `FoodLogSource.search` bzw. der Quelle des Originals.

**Avo.** Nur im Zustand „Keine Treffer“: `avo_thinking` 96.

---

### S4 Foto aufnehmen `/calories/add/photo`

**Zweck.** Ein Foto vom Teller machen, das gut zu schätzen ist.

**Route.** V-Route, Vollbild, Tab-Leiste aus dem Baum genommen. Erreichbar nur online (offline ist die Kapsel auf S3
aus). Der Auslöser ersetzt diesen Screen durch S5.

**Aufbau.** Hintergrund #000000, Kamerabild randlos (Platform View). Oben Glas-Gruppe: `chevron.left` „Zurück“ und
Blitz (`bolt.slash` / `bolt`, Wert „aus“/„an“). Darunter dunkle Hinweis-Kapsel (rgba(0,0,0,.6), Radius 16, 15/20 weiß,
Innenrand 12/8): „Den Teller von oben und ganz ins Bild nehmen. Eine Gabel daneben hilft, die Größe zu schätzen.“ Unten
mittig der Auslöser (Ring 72 weiß 4 pt, Kreis 60 weiß, kein Glas), links Glas-Knopf 44 `photo.on.rectangle`
„Aus Fotos“, rechts Platzhalter 44.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Kamera noch nie gefragt | vor dem Öffnen von S4 zentrierter Alert auf S3: „Kamera für Essensfotos“ / „Das Foto wird nur für die Schätzung verwendet und privat gespeichert.“ / „Nicht jetzt“ · „Weiter“; erst „Weiter“ öffnet S4 und die Systemabfrage |
| Kamera abgelehnt | S4 zeigt #F2F2F7 statt Kamera, `StatusRow` „Kamera ist nicht erlaubt. In Einstellungen erlauben“ und getönte Kapsel 54 „Aus Fotos wählen“ |
| Ab AX3 | Hinweis kürzer: „Teller von oben fotografieren.“ |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_camera_hint` | Den Teller von oben und ganz ins Bild nehmen. Eine Gabel daneben hilft, die Größe zu schätzen. | Shoot the plate from above with all of it in the frame. A fork next to it helps judge the size. |
| `cal_camera_hint_short` | Teller von oben fotografieren. | Photograph the plate from above. |
| `cal_flash` | Blitz | Flash |
| `cal_shutter` | Foto aufnehmen | Take photo |
| `cal_from_photos` | Aus Fotos | From Photos |
| `cal_cam_pre_title` | Kamera für Essensfotos | Camera for meal photos |
| `cal_cam_pre_body` | Das Foto wird nur für die Schätzung verwendet und privat gespeichert. | The photo is only used for the estimate and stored privately. |
| `cal_not_now` | Nicht jetzt | Not now |
| `cal_continue` | Weiter | Continue |
| `cal_camera_denied` | Kamera ist nicht erlaubt. In Einstellungen erlauben | Camera access is off. Allow in Settings |

**Barrierefreiheit.** Fokus: Zurück, Blitz, Hinweis, Aus Fotos, Auslöser. Auslöser „Foto aufnehmen, Taste“. Glas-Knöpfe
mit Large Content Viewer ab AX1. Keine Haptik beim Auslösen (das System macht das Kamera-Geräusch). Transparenz
reduziert: Glas-Gruppe festes #1C1C1E mit weißen Symbolen.

**Daten.** Kamera über `image_picker` mit eigener Vorschau oder eigene `AVCaptureSession`-Ansicht über einen Kanal
(Entscheidung im Spike, kein neues Paket). Berechtigungsstatus über den nativen Kanal (`permission_handler` meldet
ohne Podfile-Makros immer „abgelehnt“). Foto in 1024 px Kantenlänge, JPEG 80 %, nur im Speicher bis S5.

**Avo.** Keine.

---

### S5 Schätzung prüfen `/calories/add/estimate` (D2 `X-Essen`, Ergebnisteil)

**Zweck.** Die Schätzung aus dem Foto prüfen, korrigieren und erst dann eintragen.

**Route.** V-Route, ersetzt S4. `chevron.left` „Zurück“ führt zu S3 und bricht eine laufende Schätzung ab.

**Aufbau.**

1. Kopf: Glas-Knopf 44 `chevron.left`, Inline-Titel „Mittagessen eintragen“ (Taste mit Mahlzeit-Menü wie S3).
2. Foto 300 hoch, Radius 26, randlos in der Breite (16 pt Rand). Oben links Glas-Pille 28: während der Schätzung
   Mini-Figur `avo_thinking` 22 × 27 und „Wird geschätzt …“ (Pille pulsiert sanft); danach Funkeln 14 in Grün und
   „Geschätzt“.
3. Ergebniskarte weiß, Radius 26, Innenabstand 14/16 (X-Essen): Name 20/25 Semibold (Taste, wird an Ort und Stelle ein
   Feld), rechts „ca. 650 kcal“ 20/25 Bold tabellarisch. Darunter `ConfidenceRow` 13/18: drei Punkte 8 pt (gefüllt
   #1C1C1E, leer Kontur #8E8E93) und „Unsicher“. Trennlinie, dann vier Spalten (X-Essen `.mac`): Wert 17/22 Semibold,
   Label 12/16 #6C6C70: „32 g“ Protein, „78 g“ Kohlenhydrate (bei Platzmangel „Kohlenh.“), „21 g“ Fett, „1“ Portion.
   Während der Schätzung stehen an allen Werten Tonflächen in der endgültigen Größe (kein Sprung).
4. Gruppe ALLERGIE (nur bei Treffer): `exclamationmark.triangle.fill` #A8521A, 15/20 „Kann Erdnuss enthalten. Du hast
   eine Erdnussallergie eingetragen.“; Fußnote „Die Prüfung ersetzt keinen Blick auf die Zutaten.“ Warn-Haptik einmal.
   Die Gruppe bleibt, bis kein passender Bestandteil mehr da ist, dann schrumpft sie weg.
5. Gruppe BESTANDTEILE: `ComponentRow` 60: Name 17/22, Unterzeile „ca. 220 g“, rechts „345 kcal“. Tippen klappt an Ort
   und Stelle ein Gramm-Feld und einen Stepper (±10 g) auf; kcal und Makros ändern sich proportional, Summe rollt.
   Wischen nach links „Entfernen“. Letzte Zeile „Bestandteil hinzufügen“ in Grün (Name und Gramm an Ort und Stelle,
   kcal pro 100 g aus dem Produkt-Cache oder Feld).
6. Fußnote: „Geschätzt aus dem Foto. Die Portionsgröße ist am schwersten zu erkennen, prüf vor allem die Gramm.“
   Nach eigener Änderung zusätzlich „Von dir angepasst.“
7. Gruppe mit `ToggleRow` „Foto im Tagebuch behalten“ (an); Fußnote „Das Foto wird privat gespeichert. Alle
   Essensfotos kannst du in den Einstellungen löschen.“
8. Zeile ohne Gruppe (nur mit Health verbunden und Schreiben erlaubt): Herz 20 #FF2D55, 15/20 #3A3A3C „Wird auch in
   Apple Health gespeichert“.
9. Unten fest, 34 pt über der Unterkante: getönte Kapsel 54 „Eintragen“ (deaktiviert bis zum Ergebnis). Inhalt scrollt
   darunter, Scroll-Kante unten.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Schätzt (meist 3 bis 8 s, höchstens 30 s) | Pille „Wird geschätzt …“, Tonflächen, Kapsel aus; Zurück bricht ohne Frage ab |
| Fertig | Ansage „Schätzung fertig: Spaghetti Bolognese, ungefähr 650 Kilokalorien, unsicher“, keine Haptik |
| Kein Essen (`no_food_detected`) | statt Karte: `questionmark.circle` 48 #6C6C70, „Auf dem Foto ist kein Essen zu erkennen.“, getönte Kapsel 44 „Neues Foto“, Text-Knopf „Manuell eintragen“ |
| Foto unbrauchbar (`unreadable_image`) | „Das Foto ist zu dunkel oder unscharf.“ + „Neues Foto“ |
| Abgelehnt (`refused`) | „Dieses Foto kann nicht geschätzt werden.“ + „Manuell eintragen“ |
| Fehler, Zeitüberschreitung (`provider_error`, `timeout`, `network_error`) | `StatusRow` „Die Schätzung hat nicht geklappt.“ + `retry`, Foto bleibt, Fehler-Haptik |
| Offline | „Offline. Die Schätzung braucht eine Verbindung.“ + `retry` |
| Tageslimit (`quota_exceeded`) | Texte wie S3 (`cal_photo_limit_free` / `_pro`), Foto bleibt, „Manuell eintragen“ |
| KI aus (`ai_disabled`) | „Foto-Schätzungen sind gerade nicht verfügbar.“ + „Manuell eintragen“ |
| Pro gesperrt (falls entschieden) | Fußnote „Mit {pro} schätzt {app} Kalorien aus Fotos.“ + `ProBadge`, Kapsel heißt „Schätzen“ und öffnet `/pro?feature=cal_photo` |
| Verlassen mit Ergebnis, nicht eingetragen | Alert „Schätzung verwerfen?“ / „Das Essen wird nicht eingetragen.“ / „Verwerfen“ (destruktiv) · „Weiter bearbeiten“ |
| „Eintragen“ | zurück zum Ausgangsort von S3 (S3 wird übersprungen), Rückgängig „Spaghetti Bolognese eingetragen“; der Eintrag bleibt „geschätzt“ mit seiner Sicherheitsstufe; Health schreibt sofort, ein Widerrufen löscht den Health-Wert wieder |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_estimating` | Wird geschätzt … | Estimating… |
| `cal_estimated` | Geschätzt | Estimated |
| `cal_about_kcal` | ca. {kcal} kcal | about {kcal} kcal |
| `cal_conf_high` | Recht sicher | Fairly sure |
| `cal_conf_medium` | Unsicher | Unsure |
| `cal_conf_low` | Grob geschätzt | Rough estimate |
| `cal_serving` | Portion | Serving |
| `cal_macro_carbs_short` | Kohlenh. | Carbs |
| `cal_allergy_warning` | Kann {allergen} enthalten. Du hast {condition} eingetragen. | May contain {allergen}. Your profile lists {condition}. |
| `cal_allergy_note` | Die Prüfung ersetzt keinen Blick auf die Zutaten. | This check doesn't replace reading the ingredients. |
| `cal_sec_components` | Bestandteile | What's on the plate |
| `cal_about_grams` | ca. {g} g | about {g} g |
| `cal_component_add` | Bestandteil hinzufügen | Add an item |
| `cal_component_remove` | Entfernen | Remove |
| `cal_grams` | Gramm | Grams |
| `cal_estimate_note` | Geschätzt aus dem Foto. Die Portionsgröße ist am schwersten zu erkennen, prüf vor allem die Gramm. | Estimated from the photo. Portion size is the hardest part to see, so check the grams first. |
| `cal_adjusted_by_you` | Von dir angepasst. | Adjusted by you. |
| `cal_keep_photo` | Foto im Tagebuch behalten | Keep photo in diary |
| `cal_keep_photo_note` | Das Foto wird privat gespeichert. Alle Essensfotos kannst du in den Einstellungen löschen. | The photo is stored privately. You can delete all meal photos in Settings. |
| `cal_health_write_line` | Wird auch in Apple Health gespeichert | Also saved to Apple Health |
| `cal_log_button` | Eintragen | Log |
| `cal_no_food` | Auf dem Foto ist kein Essen zu erkennen. | There's no food in this photo. |
| `cal_new_photo` | Neues Foto | New photo |
| `cal_photo_unreadable` | Das Foto ist zu dunkel oder unscharf. | The photo is too dark or blurry. |
| `cal_photo_refused` | Dieses Foto kann nicht geschätzt werden. | This photo can't be estimated. |
| `cal_estimate_error` | Die Schätzung hat nicht geklappt. | The estimate didn't work. |
| `cal_estimate_offline` | Offline. Die Schätzung braucht eine Verbindung. | You're offline. The estimate needs a connection. |
| `cal_ai_off` | Foto-Schätzungen sind gerade nicht verfügbar. | Photo estimates aren't available right now. |
| `cal_pro_photo` | Mit {pro} schätzt {app} Kalorien aus Fotos. | With {pro}, {app} estimates calories from photos. |
| `cal_estimate_button` | Schätzen | Estimate |
| `cal_discard_estimate_title` | Schätzung verwerfen? | Discard estimate? |
| `cal_discard_food_body` | Das Essen wird nicht eingetragen. | The food won't be logged. |
| `cal_discard` | Verwerfen | Discard |
| `cal_keep_editing` | Weiter bearbeiten | Keep editing |

Allergene (Wort und Bedingung), aus `AllergyType` mit deutschen Stichwörtern (`dietary_preference.dart:20-40`):

| Typ | `{allergen}` DE | `{condition}` DE | `{allergen}` EN | `{condition}` EN |
|---|---|---|---|---|
| Erdnuss | Erdnuss | eine Erdnussallergie | peanuts | a peanut allergy |
| Nüsse | Nüsse | eine Nussallergie | nuts | a nut allergy |
| Gluten | Gluten | eine Glutenunverträglichkeit | gluten | gluten intolerance |
| Laktose | Laktose | eine Laktoseintoleranz | lactose | lactose intolerance |

Weitere Typen nach demselben Muster, je Typ ein Schlüsselpaar `cal_allergen_<typ>` und `cal_condition_<typ>`.

**Barrierefreiheit.**

- Foto: „Foto vom Teller“ / „Photo of the plate“; Pille Teil des Fotos, Figur ausgeblendet.
- Karte als ein Element: „Spaghetti Bolognese, ungefähr 650 Kilokalorien, geschätzt, unsicher. 32 Gramm Protein,
  78 Gramm Kohlenhydrate, 21 Gramm Fett, 1 Portion.“ Aktion „Namen ändern“. Punkte ausgeblendet.
- Allergie-Gruppe: Ansage beim Erscheinen (höflich), Label wie sichtbar.
- Bestandteil: „Spaghetti, gekocht, ungefähr 220 Gramm, 345 Kilokalorien. Aktionen: Gramm ändern, Entfernen“. Aufgeklappt
  ist der Stepper einstellbar („220 Gramm“, Wischen hoch/runter ±10).
- Fokus: Zurück, Titel, Foto, Karte, Allergie, Bestandteile, Fußnote, Schalter, Health-Zeile, „Eintragen“.
- 320 pt und ab xxxL: Makro-Spalten 2 × 2. Ab AX1 Bestandteile gestapelt (kcal unter den Gramm), Foto bleibt 300 hoch
  bei voller Breite, Name und kcal untereinander. Ab AX3 Pille ohne Figur.
- Reduce Motion: Pille steht still, Werte blenden ein statt zu rollen.

**Daten.** `MealPhotoAnalysisService` auf Claude (Edge Function `ai`, Task `meal_photo`, Modell `claude-sonnet-5-5`,
Zeitlimit 30 s; Ergebnis `MealPhotoEstimate` mit `dish`, `components[{name, grams}]`, `kcal`, Makros, `confidence`
(`recht_sicher|unsicher|grob`), `allergens[]`, `no_food`), `ClaudeException`-Codes wie in der Tabelle, Allergien aus
`users.allergies` (Abgleich mit `AllergyType`-Stichwörtern, auch Komposita), `MealPhotoStorageService` (privater
Bucket, Upload blockiert das Speichern nie), `healthStatusProvider`. Eintrag mit `FoodLogSource.photo`, `estimated: true`,
`confidence`, `logged_time` (neue Spalten, Migration offen).

**Avo.** Mini-Figur `avo_thinking` in der Pille nur während der Schätzung (eine Figur).

---

### S6 Barcode-Kamera `/calories/scan`

**Zweck.** Ein verpacktes Lebensmittel mit der Kamera erkennen statt 13 Ziffern zu tippen.

**Route.** V-Route, Vollbild, Tab-Leiste aus dem Baum. Treffer ersetzt S6 durch S7. Einstiege: S3, Deep Link,
Kontrollzentrum, Kurzbefehl, Avo.

**Aufbau.** Kamerabild randlos (VisionKit `DataScannerViewController` über den Kanal `shoply/scanner`, iOS 16+).
Außerhalb des Rahmens #000000 40 %. Oben Glas-Gruppe: `chevron.left` „Zurück“, Taschenlampe
(`flashlight.off.fill` / `flashlight.on.fill`). Sucherrahmen mittig 280 × 160 (bei 320 pt 248 × 144), Ecken 4 pt weiß,
Radius 20. Darunter dunkle Hinweis-Kapsel „Strichcode in den Rahmen halten“. Unten Glas-Kapsel 44 `keyboard`
„Nummer eingeben“.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Erkannt | Rahmen springt auf den Code (`springQuick`), Ecken werden #34C759 mit weißem `checkmark.circle.fill` 22 oben rechts (nicht nur Farbe), Ziffern „4 056489 123457“ in der Kapsel, leichter Impuls, Ansage „Strichcode erkannt“; nach 0,4 s S7 |
| Sucht | Kapsel „4 056489 123457 · wird gesucht …“; erst lokaler Cache, dann Open Food Facts; kein Spinner |
| Nicht gefunden | Kapsel „Zu diesem Strichcode ist nichts bekannt.“; unten zwei Kapseln: getönt „Manuell eintragen“ (S8 mit hinterlegtem Strichcode) und Glas „Erneut scannen“ |
| Ohne Nährwerte | S7 im Zustand „Nährwerte fehlen“ |
| Nummer eingeben | Glas-Feld 48 über der Tastatur, Ziffernblock, Platzhalter „13 Ziffern unter dem Strichcode“, Return „Suchen“ |
| Kamera noch nie gefragt | vorher zentrierter Alert: „Kamera für Strichcodes“ / „Die Kamera liest nur den Strichcode. Es werden keine Bilder gespeichert.“ / „Nicht jetzt“ · „Weiter“ |
| Kamera abgelehnt | #F2F2F7 statt Kamera, `StatusRow` „Kamera ist nicht erlaubt. In Einstellungen erlauben“, direkt das Ziffern-Feld |
| Offline | Kapsel „Offline. Nur schon gescannte Produkte werden erkannt.“ |
| Gerät ohne Scanner | direkt das Ziffern-Feld (iOS 15.6 bis 15.x, Geräte vor A12) |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_scan_hint` | Strichcode in den Rahmen halten | Hold the barcode inside the frame |
| `cal_flashlight` | Taschenlampe | Flashlight |
| `cal_scan_found_a11y` | Strichcode erkannt | Barcode found |
| `cal_scan_searching` | {code} · wird gesucht … | {code} · looking it up… |
| `cal_scan_not_found` | Zu diesem Strichcode ist nichts bekannt. | Nothing is known about this barcode. |
| `cal_scan_again` | Erneut scannen | Scan again |
| `cal_scan_pre_title` | Kamera für Strichcodes | Camera for barcodes |
| `cal_scan_pre_body` | Die Kamera liest nur den Strichcode. Es werden keine Bilder gespeichert. | The camera only reads the barcode. No images are saved. |
| `cal_scan_offline` | Offline. Nur schon gescannte Produkte werden erkannt. | You're offline. Only products you've scanned before are recognised. |

**Barrierefreiheit.** Fokus: Zurück, Taschenlampe, Hinweis, „Nummer eingeben“. VoiceOver sagt nur den Treffer an
(„Strichcode erkannt“, dann die Ziffern). Large Content Viewer ab AX1. Reduce Motion: Rahmen erscheint am Code ohne Sprung. Transparenz reduziert: Gruppe fest #1C1C1E.

**Daten.** `ScannerChannel` (neu, Swift, Kanal `shoply/scanner`: `isSupported`, `isAvailable`, Ergebnis als Text mit
Symbologie EAN-13/EAN-8/UPC-A), `barcodeLookupProvider(code)` (lokal zuerst, Open Food Facts mit User-Agent
`Avo/<version> (<Kontakt>)`, höchstens 15 Produktabfragen pro Minute), `userFoodsProvider` (eigene Produkte mit
Strichcode gewinnen vor Open Food Facts).

**Avo.** Keine.

---

### S7 Menge `/calories/add/food/:foodId`

**Zweck.** Für ein bekanntes Produkt die gegessene Menge festlegen und die Nährwerte live sehen.

**Route.** V-Route. Zurück führt zu S3 bzw. zum Ausgangsort des Scans.

**Aufbau.**

1. Kopf: `chevron.left`, Inline-Titel „Menge“.
2. Gruppe Produkt: Bild 64 Radius 14 auf Weiß, „Skyr Natur“ 17/22 Semibold, „Milbona · 500-g-Becher“ 15/20 #6C6C70,
   „63 kcal pro 100 g“ 15/20 #6C6C70.
3. Gruppe MENGE: Zeile mit Zahlenfeld (34/41 Bold tabellarisch, linksbündig, Dezimal-Ziffernblock beim Öffnen
   fokussiert) und Einheit 17/22 #6C6C70 dahinter; rechts Stepper 44 (±10 g bzw. ±0,5 Portion, Langdruck wiederholt).
   Darunter Chips Einzelauswahl: „g“, „Portion · 150 g“, „Packung · 500 g“ (nur, wenn Open Food Facts sie nennt), bei
   Getränken „ml“.
4. Nährwert-Zeile (`NutritionRow`, vier Spalten wie X-Essen): „158 kcal“, „27,5 g Protein“, „10 g Kohlenhydrate“,
   „0,5 g Fett“; rollt live.
5. Gruppe: `ValueRow` „Mahlzeit“ (Menü), „Datum“ (S2-Menü).
6. Fußnote: „Nährwerte und Foto: Open Food Facts (ODbL, Foto CC BY-SA). Angaben können fehlen oder abweichen.“ als
   Link auf die Produktseite.
7. Unten getönte Kapsel 54 „Eintragen“; mit offener Tastatur sitzt sie 8 pt über der Tastatur.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Nährwerte fehlen | Gruppe NÄHRWERTE PRO 100 G mit Feldern kcal, Protein, Kohlenhydrate, Fett; Satz darüber „Für dieses Produkt sind keine Nährwerte hinterlegt. Trag sie von der Verpackung ein (pro 100 g).“; „Eintragen“ erst mit kcal; Fußnote „Wir merken uns die Werte für das nächste Mal.“ |
| Ungültige Menge | `cal_number_invalid` unter dem Feld, Kapsel aus |
| Offline | voll nutzbar mit lokal bekannten Produkten |
| Foto lädt | Tonfläche 64, Überblendung |
| „Eintragen“ | zurück zum Ausgangsort, Rückgängig „Skyr Natur eingetragen“ |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_amount_title` | Menge | Amount |
| `cal_sec_amount` | Menge | Amount |
| `cal_unit_serving` | Portion · {g} g | Serving · {g} g |
| `cal_unit_pack` | Packung · {g} g | Pack · {g} g |
| `cal_less` | Weniger | Less |
| `cal_more` | Mehr | More |
| `cal_meal` | Mahlzeit | Meal |
| `cal_date` | Datum | Date |
| `cal_off_attribution` | Nährwerte und Foto: Open Food Facts (ODbL, Foto CC BY-SA). Angaben können fehlen oder abweichen. | Nutrition and photo: Open Food Facts (ODbL, photo CC BY-SA). Details may be missing or differ. |
| `cal_nutrients_missing` | Für dieses Produkt sind keine Nährwerte hinterlegt. Trag sie von der Verpackung ein (pro 100 g). | This product has no nutrition data. Enter it from the pack (per 100 g). |
| `cal_sec_per_100g` | Nährwerte pro 100 g | Nutrition per 100 g |
| `cal_nutrients_remembered` | Wir merken uns die Werte für das nächste Mal. | We'll remember these values next time. |

**Barrierefreiheit.** Feld „Menge, 250 Gramm, Textfeld“; Stepper einstellbar „Menge, 250 Gramm“ mit increased/decreased
„260 Gramm“/„240 Gramm“; Chips als Radiogruppe „Einheit“; Nährwert-Zeile ein Element „158 Kilokalorien, 27,5 Gramm
Protein, 10 Gramm Kohlenhydrate, 0,5 Gramm Fett“, Änderung angesagt nach 1 s Ruhe. Ab xxL Stepper unter dem Feld in
voller Breite, Chips brechen um; 320 pt Nährwert-Zeile 2 × 2; ab AX1 Produktbild weg.

**Daten.** `productProvider(foodId)` (lokaler Cache, `user_food`, Open Food Facts; Felder zusätzlich `serving_size`,
`serving_quantity`, `product_quantity`, `quantity`), `FoodProduct`-Parser verträgt Zahlen als Text (heute Absturz bei
`(v as num)`). Eintrag mit `FoodLogSource.barcode` (gescannt) bzw. `search` (gesucht).

**Avo.** Keine.

---

### S8 Manuell `/calories/add/manual`

**Zweck.** Etwas eintragen, das keine Datenbank kennt, und es sich als eigenes Lebensmittel merken.

**Route.** V-Route, vorbefüllt über `name=`, `barcode=` (aus Suche, Barcode, Avo).

**Aufbau.**

1. Kopf: `chevron.left` (aus S3, S6) bzw. `xmark` (direkt geöffnet), Inline-Titel „Manuell eintragen“.
2. Gruppe: Feld „Name“ (Platzhalter „Zum Beispiel Käsebrötchen“), Feld „Kalorien“ mit „kcal“ dahinter.
3. Text-Knopf mit Funkeln 17 „Kalorien schätzen lassen“ (nur online, nur mit Name, nur wenn KI an). Ergebnis setzt das
   Feld, darunter Fußnote „geschätzt, bitte prüfen“.
4. Gruppe NÄHRWERTE: Protein, Kohlenhydrate, Fett untereinander, je Feld mit „g“; Fußnote „Optional. Ohne Angabe zählen
   sie nicht zu den Tageswerten.“
5. Gruppe MENGE: Zahlenfeld und Chips „g“, „ml“, „Stück“, „Portion“ (optional).
6. Gruppe: „Mahlzeit“, „Datum“.
7. Unten getönte Kapsel 54 „Eintragen“ (aktiv mit gültigem Namen und gültiger kcal-Zahl).

**Zustände.** Ungültige Zahl: `cal_number_invalid` unter dem Feld. Offline: „Kalorien schätzen lassen“ entfällt.
Schätzung fehlgeschlagen: Zeile unter dem Knopf „Die Schätzung hat nicht geklappt.“ + `retry`. Ungespeichert verlassen:
Alert „Eingaben verwerfen?“ / „Das Essen wird nicht eingetragen.“ / „Verwerfen“ · „Weiter bearbeiten“. Nach „Eintragen“
wird das Essen ein eigenes Lebensmittel (EIGENE in S3), mit Strichcode, falls einer hinterlegt war. Rückgängig
„Käsebrötchen eingetragen“.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_manual_title` | Manuell eintragen | Enter manually |
| `cal_name` | Name | Name |
| `cal_name_placeholder` | Zum Beispiel Käsebrötchen | For example cheese roll |
| `cal_calories` | Kalorien | Calories |
| `cal_estimate_kcal` | Kalorien schätzen lassen | Estimate calories |
| `cal_estimated_check` | geschätzt, bitte prüfen | estimated, please check |
| `cal_sec_nutrients` | Nährwerte | Nutrients |
| `cal_nutrients_optional` | Optional. Ohne Angabe zählen sie nicht zu den Tageswerten. | Optional. Left empty, they don't count toward your daily totals. |
| `cal_unit_piece` | Stück | piece |
| `cal_unit_portion` | Portion | serving |
| `cal_discard_input_title` | Eingaben verwerfen? | Discard your input? |

**Barrierefreiheit.** Jedes Feld hat eine sichtbare Beschriftung links (ab xxL darüber), kein Platzhalter als Label.
Fehlertext ist mit dem Feld verknüpft und wird beim Verlassen des Felds angesagt. Keine Makrofelder nebeneinander.

**Daten.** `UserFoodService` (neu, Tabelle `user_food`), Claude-Task `nutrition_estimate` (Haiku, Zeitlimit 6 s; Limit
pro Tag nicht festgelegt, siehe 7), Eintrag mit `FoodLogSource.manual` bzw. `manual_estimated`.

**Avo.** Keine.

---

### S9 Eintrag bearbeiten `/calories/entry/:entryId`

**Zweck.** Einen Eintrag ändern (Menge, Mahlzeit, Tag, Uhrzeit, Nährwerte) oder löschen. Heute gibt es kein Bearbeiten.

**Route.** V-Route aus dem Tagebuch (Tippen, Kontextmenü „Bearbeiten“) und aus Avo. Speichert beim Verlassen, keine
Kapsel.

**Aufbau.**

1. Kopf: `chevron.left` „Zurück“, rechts Glas-Knopf 44 `ellipsis` „Mehr“ mit Menü „Heute nochmal eintragen“, „Als
   eigenes Lebensmittel merken“.
2. Großer Titel 34/41 = Name (bricht auf zwei Zeilen um; eingeklappt als Inline-Titel mit Ellipse).
3. Foto 4:3, Radius 20, falls vorhanden.
4. Gruppe: Feld „Name“.
5. Gruppe MENGE: Zahl, Stepper, Einheit wie S7.
6. Gruppe: „Mahlzeit“ (Menü), „Datum“ (S2), „Uhrzeit“ (Rad an Ort und Stelle).
7. Gruppe NÄHRWERTE als Felder: Kalorien, Protein, Kohlenhydrate, Fett. Bei einer KI-Schätzung darunter die
   `ConfidenceRow` und „geschätzt“; eine eigene Änderung macht daraus „geschätzt, von dir angepasst“.
8. Fußnote mit der Quelle: „Geschätzt aus einem Foto, Sa., 7. Nov., 12:41“ / „Open Food Facts, Strichcode
   4 056489 123457“ / „Aus dem Rezept Ofengemüse mit Feta, 1 Portion“ (Link zum Rezept) / „Von dir eingetragen“.
9. Eigene Gruppe: Text-Knopf „Eintrag löschen“ #D70015. Löscht sofort, schließt den Screen, Rückgängig im Tagebuch, kein
   Dialog.

**Zustände.** Geändert: beim Verlassen gespeichert, im Tagebuch Rückgängig „Eintrag geändert“. Speichern
fehlgeschlagen: `StatusRow` „Nicht gespeichert.“ + `retry`, Screen bleibt offen. Auf einem anderen Gerät gelöscht:
Screen schließt ohne Meldung. Offline: Änderung in der Warteschlange, Sync-Zeichen im Tagebuch. Health: Wert wird per
`HKMetadataKeySyncIdentifier` (Eintrags-ID) und erhöhter `SyncVersion` ersetzt.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_more_a11y` | Mehr | More |
| `cal_save_as_own` | Als eigenes Lebensmittel merken | Save as your own food |
| `cal_saved_as_own` | Als eigenes Lebensmittel gemerkt | Saved as your own food |
| `cal_time` | Uhrzeit | Time |
| `cal_src_photo` | Geschätzt aus einem Foto, {date}, {time} | Estimated from a photo, {date}, {time} |
| `cal_src_barcode` | Open Food Facts, Strichcode {code} | Open Food Facts, barcode {code} |
| `cal_src_search` | Open Food Facts | Open Food Facts |
| `cal_src_recipe` | Aus dem Rezept {recipe}, {servings} | From the recipe {recipe}, {servings} |
| `cal_src_manual` | Von dir eingetragen | Entered by you |
| `cal_src_avo` | Von {assistant} geschätzt, von dir bestätigt | Estimated by {assistant}, confirmed by you |
| `cal_estimated_adjusted` | geschätzt, von dir angepasst | estimated, adjusted by you |
| `cal_delete_entry` | Eintrag löschen | Delete entry |
| `cal_entry_changed` | Eintrag geändert | Entry changed |
| `cal_not_saved_status` | Nicht gespeichert. | Not saved. |

**Barrierefreiheit.** Titel als Überschrift; Fokus Zurück, Mehr, Titel, Foto, Felder, Quelle, Löschen. „Eintrag
löschen, Taste. Hinweis: Löscht sofort, du kannst es danach widerrufen.“ Ab xxL Beschriftungen über den Feldern.

**Daten.** `foodEntryProvider(entryId)` (lokal), `FoodLogService.updateEntry` (neu), `updated_at` für zwei Geräte
(zuletzt geschrieben gewinnt, Spalte neu), `HealthSyncService.replaceFood/deleteFood`.

**Avo.** Keine.

---

### S10 Rezept ins Tagebuch `/calories/add/recipe/:recipeId`

**Zweck.** Ein Rezept als Mahlzeit eintragen, mit Portionen, Mahlzeit und Tag.

**Route.** V-Route. Slot für A: `openLogRecipe(context, recipe)` pusht diesen Pfad (mit `recipe` als `extra`). Er
öffnet über dem Rezepte-Tab bzw. dem Wochenplan und kehrt dorthin zurück. Der Slot bricht heute bei Rezepten ohne
Nährwerte still ab; künftig öffnet er den Zustand „ohne Nährwerte“.

**Aufbau.**

1. Kopf: `chevron.left`, Inline-Titel „Ins Tagebuch“.
2. Gruppe Rezept: Bild 64 Radius 14, Titel 17/22 Semibold, „520 kcal pro Portion“ 15/20 #6C6C70.
3. Gruppe: Zeile „Portionen“ mit Stepper 44 rechts (0,5 bis 20 in 0,5er-Schritten, Wert „1“, „1,5“).
4. Gruppe: „Mahlzeit“ (nach Uhrzeit; vom Wochenplan: Abendessen), „Datum“ (heute; vom Wochenplan: der Plan-Tag, sofern
   nicht in der Zukunft).
5. `NutritionRow` live, Fußnote „Für die gewählte Menge, laut Rezept.“ bzw. „geschätzt“, wenn die Rezeptwerte selbst
   geschätzt sind.
6. Unten getönte Kapsel 54 „Eintragen“.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Ohne Nährwerte | Satz „Für dieses Rezept sind keine Nährwerte hinterlegt.“; online Text-Knopf „Kalorien schätzen lassen“, sonst Feld „Kalorien pro Portion“ |
| Plan-Tag in der Zukunft | Datum heute, Fußnote „Geplant für Mo., 9. Nov. Eintragen kannst du ab dem Tag selbst.“ |
| Offline | voll nutzbar |
| „Eintragen“ | zurück zum Rezept, Rückgängig „Ofengemüse mit Feta eingetragen“. Der Maskottchen-Meilenstein „proteinreiche Mahlzeit“ entfällt |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_log_recipe_title` | Ins Tagebuch | Add to diary |
| `cal_kcal_per_serving` | {kcal} kcal pro Portion | {kcal} kcal per serving |
| `cal_servings` | Portionen | Servings |
| `cal_recipe_note` | Für die gewählte Menge, laut Rezept. | For the amount chosen, from the recipe. |
| `cal_recipe_no_nutrition` | Für dieses Rezept sind keine Nährwerte hinterlegt. | This recipe has no nutrition data. |
| `cal_kcal_per_serving_field` | Kalorien pro Portion | Calories per serving |
| `cal_recipe_future` | Geplant für {date}. Eintragen kannst du ab dem Tag selbst. | Planned for {date}. You can log it from that day. |

**Barrierefreiheit.** Stepper einstellbar „Portionen, 1“ (increased „1,5“). Ab xxL Stepper unter dem Label. 320 pt
`NutritionRow` 2 × 2.

**Daten.** `recipeProvider(id)` (A, lesend), `FoodLogService` mit `FoodLogSource.recipe`, `source_recipe_id`;
`planEntryProvider` (B7) für Plan-Tag. Ersetzt `log_recipe.dart` und `log_recipe_sheet.dart` (beide Dateien gehören
gerade einem anderen Workflow; Umbau erst danach).

**Avo.** Keine.

---

### S12 Wasser (Zeile, Menü, Alert)

**Zweck.** Wasser mit einem Tipp für den angezeigten Tag eintragen.

**Navigation.** Keine Route. `WaterRow` auf S1, `WaterTile` auf Home, Kontextmenü auf beiden, zentrierter Alert für
eine andere Menge.

**Verhalten.** Tipp auf „+250 ml“ (Schnelltaste aus S23): Zahl rollt („1,25“ → „1,5“), Balken bzw. Tropfen füllen sich,
leichter Impuls, Rückgängig „250 ml Wasser eingetragen“. Gilt für den **angezeigten** Tag (heute wird heute immer
genommen, `water_tracker_card.dart:26` ruft `addEntry` ohne Datum). Langdruck auf Zeile oder Kachel: Menü „+150 ml“,
„+330 ml“, „+500 ml“, „Andere Menge …“, Trenner, „Letzten Eintrag entfernen (250 ml, 16:10)“ (destruktiv, mit
Rückgängig). „Andere Menge …“ öffnet einen zentrierten Alert mit Feld „Menge in ml“ und „Abbrechen“ / „Hinzufügen“.

**Zustände.** Ziel erreicht: „2 l von 2 l“ mit `checkmark.circle.fill` Grün, kein Erfolgsmoment. Ohne Wasserziel:
„1,25 l“ ohne „von“ und ohne Balken. Health-Wasser anderer Apps zählt mit („davon 0,5 l aus Health“), lässt sich hier
nicht entfernen. Offline: Warteschlange, Sync-Zeichen.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_water_quick` | +{ml} ml | +{ml} ml |
| `cal_water_other` | Andere Menge … | Other amount… |
| `cal_water_remove_last` | Letzten Eintrag entfernen ({ml} ml, {time}) | Remove last entry ({ml} ml, {time}) |
| `cal_water_removed` | {ml} ml Wasser entfernt | Removed {ml} ml of water |
| `cal_water_alert_title` | Wasser hinzufügen | Add water |
| `cal_water_alert_field` | Menge in ml | Amount in ml |
| `cal_add` | Hinzufügen | Add |
| `cal_water_a11y` | Wasser, {amount} von {goal} Litern | Water, {amount} of {goal} litres |
| `cal_water_a11y_add` | {ml} Milliliter hinzufügen | Add {ml} millilitres |
| `cal_water_a11y_remove` | Letzten Eintrag entfernen | Remove last entry |

**Barrierefreiheit.** Zeile ein Element mit Standard-Aktion „250 Milliliter hinzufügen“ und Aktionen „Andere Menge“,
„Letzten Eintrag entfernen“. Chip 34 im 44-Ziel. Ab xxL bei 320 pt und ab AX1 überall steht der Chip unter dem Text.

**Daten.** `WaterLogService.addEntry(ml, date:)`, `deleteEntry`, `dailyLogProvider(date)`, Health `dietaryWater`
(schreiben eigene, lesen fremde), `calorieSettingsProvider.waterQuickMl`. Für Widget und Siri: Server-Funktion
`log_water(ml, source)` (B9).

**Avo.** Keine.

---

### S13 Ziele `/calories/goals` und `/settings/health/goals`

**Zweck.** Tagesziele ansehen und einzeln selbst festlegen, ohne Schieberegler.

**Route.** K im Home-Tab; dasselbe Widget als E unter `/settings/health/goals`, damit man im Profil-Tab bleibt.
Ohne Ziel leitet die Route direkt auf S14 um.

**Aufbau.**

1. Toolbar `chevron.left`; großer Titel „Ziele“.
2. Gruppe PRO TAG: `ValueRow`s „Kalorien“ · „2.000 kcal“, „Protein“ · „133 g“, „Kohlenhydrate“ · „227 g“, „Fett“ ·
   „62 g“, „Wasser“ · „2 l“. Tippen klappt die Zeile an Ort und Stelle auf: Zahlenfeld plus Stepper (kcal ±50,
   Makros ±5 g, Wasser ±0,25 l). Fußnote „Berechnet am 2. Nov. aus deinen Angaben. Tippe auf einen Wert, um ihn selbst
   festzulegen.“ bzw. „Eigene Werte.“ mit Link „Neu berechnen“.
3. Gruppe DEIN ZIEL: „Ziel“ · „Abnehmen“, „Zielgewicht“ · „70,0 kg · etwa Ende Feb.“, „Alltag“ · „Leicht aktiv“,
   `NavRow` „Neu berechnen“ (öffnet S14 mit `from=goals`).
4. Gruppe WORKOUTS: `ToggleRow` „Workout-Kalorien zum Tagesbudget zählen“ (aus); Fußnote „Dann steigt dein Tagesbudget
   um die geschätzten Kalorien deiner Workouts.“
5. Gruppe: `NavRow` mit `heart` „Apple Health“ · „Verbunden“ (öffnet S23 bzw. im Profil-Tab den Zurück-Weg) oder
   „Nicht verbunden“ (öffnet S22). Entfällt auf Geräten ohne Health.
6. Fußnote unter allem: „Richtwerte, kein ärztlicher Rat.“

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Kalorien unter 1.200 gesetzt | Warnzeile in der Gruppe mit `exclamationmark.triangle.fill` #A8521A: „Unter 1.200 kcal am Tag ist ohne ärztliche Begleitung nicht zu empfehlen.“ (Wert wird trotzdem gespeichert) |
| Makros passen nicht zu kcal (über 10 %) | Fußnote „Deine Makros ergeben 1.720 kcal, dein Ziel ist 2.000.“ |
| Eigene Werte | Fußnote „Eigene Werte.“ + „Neu berechnen“; Typ „Eigene Werte“ (rechnet heute wie „Halten“, `nutrition_goal_service.dart:52-64`) |
| Offline | Änderungen in der Warteschlange |
| Geändert | Rückgängig „Kalorienziel geändert“ |
| Kein Ziel | Umleitung auf S14 |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_goals_title` | Ziele | Goals |
| `cal_sec_per_day` | Pro Tag | Per day |
| `cal_goals_calc_note` | Berechnet am {date} aus deinen Angaben. Tippe auf einen Wert, um ihn selbst festzulegen. | Calculated on {date} from your details. Tap a value to set it yourself. |
| `cal_goals_custom` | Eigene Werte. | Your own values. |
| `cal_recalculate` | Neu berechnen | Recalculate |
| `cal_sec_your_goal` | Dein Ziel | Your goal |
| `cal_goal` | Ziel | Goal |
| `cal_target_weight` | Zielgewicht | Target weight |
| `cal_target_weight_value` | {kg} kg · etwa {when} | {kg} kg · around {when} |
| `cal_activity` | Alltag | Activity |
| `cal_credit_workouts` | Workout-Kalorien zum Tagesbudget zählen | Add workout calories to my budget |
| `cal_credit_workouts_note` | Dann steigt dein Tagesbudget um die geschätzten Kalorien deiner Workouts. | Your daily budget then grows by the estimated calories of your workouts. |
| `cal_health` | Apple Health | Apple Health |
| `cal_health_connected` | Verbunden | Connected |
| `cal_health_not_connected` | Nicht verbunden | Not connected |
| `cal_guide_values` | Richtwerte, kein ärztlicher Rat. | Guide values, not medical advice. |
| `cal_below_1200` | Unter 1.200 kcal am Tag ist ohne ärztliche Begleitung nicht zu empfehlen. | Below 1,200 kcal a day isn't recommended without medical supervision. |
| `cal_macros_mismatch` | Deine Makros ergeben {macroKcal} kcal, dein Ziel ist {goal}. | Your macros add up to {macroKcal} kcal; your goal is {goal}. |
| `cal_goal_changed` | Kalorienziel geändert | Calorie goal changed |

Der Schalter-Text weicht vom Konzept („Verbrauch durch Workouts gutschreiben“) ab, weil „gutschreiben“ nach Bank klingt
und der neue Satz sagt, was passiert.

**Barrierefreiheit.** Zeile „Kalorien, 2.000 Kilokalorien. Taste. Hinweis: zum Ändern doppeltippen“; aufgeklappt
Stepper einstellbar „2.050 Kilokalorien“. Warnzeile wird beim Erscheinen angesagt. Ab AX1 Wert unter dem Titel; ab xxL
Stepper unter dem Feld.

**Daten.** `nutritionGoalProvider`, `NutritionGoalService.saveGoal` (stabile API für A), neue Felder `credit_workouts`,
`pace`, Kennzeichen „eigene Werte“ und `calculated_at` (Lücke, siehe 7), `healthStatusProvider`.

**Avo.** Keine.

---

### S14 Ziel berechnen `/calories/goals/setup`

**Zweck.** Ein Tagesziel aus Größe, Gewicht, Alter und Alltag ausrechnen. Ein Formular mit Ergebnis oben, kein
Assistent, kein Schieberegler.

**Route.** V-Route aus S1a, S13 und dem Onboarding von A (dort baut A die Oberfläche selbst mit `GoalForm` und
`NutritionGoalCalculator`; diese Route gilt dann nur für die App).

**Aufbau.**

1. Kopf: `chevron.left`, Inline-Titel „Ziel berechnen“; beim Scrollen eingeklappt „Ziel · 2.000 kcal“.
2. Gruppe ERGEBNIS (immer oben, rollt live): „2.000“ `numberXL` und „kcal am Tag“ 17/22, darunter `NutritionRow`, darunter
   „Wasser 2 l“; Fußnote „Berechnet nach Mifflin-St Jeor aus deinen Angaben. Richtwerte, kein ärztlicher Rat.“ Fehlen
   Angaben: „–“ in #6C6C70 und „Alter, Größe und Gewicht fehlen noch.“
3. Gruppe ZIEL: drei Zeilen mit `checkmark` (Einzelauswahl) „Abnehmen“, „Gewicht halten“, „Muskeln aufbauen“.
4. Gruppe ÜBER DICH: „Geschlecht“ (Menü: Weiblich, Männlich, Divers, Keine Angabe), „Alter“ (Zahl, „Jahre“), „Größe“
   (Zahl, „cm“), „Gewicht“ (Zahl, „kg“). Mit Health oben Zeile „Aus Apple Health übernehmen“ (füllt Größe, Gewicht,
   Geburtsjahr, erst dann die Systemabfrage, falls noch nicht gefragt); Fußnote „Größe und Gewicht aus Apple Health.“
5. Gruppe ZIELGEWICHT (nur Abnehmen und Muskeln aufbauen): Zahlenfeld „Zielgewicht“ und Segmented Control 44
   „Gemütlich | Normal | Zügig“ (Abnehmen 0,25 / 0,5 / 0,75 kg pro Woche; Aufbau 0,1 / 0,25 / 0,4); darunter 15/20
   „Etwa 0,5 kg pro Woche. Zielgewicht etwa Ende Februar.“ Ersetzt den `Slider` in `goal_setup_screen.dart:318`.
6. Gruppe ALLTAG: fünf Zeilen mit `checkmark` und Unterzeile: „Meist sitzend“ · „Büro, wenig Sport“; „Leicht aktiv“ ·
   „1 bis 3 Mal Sport pro Woche“; „Mäßig aktiv“ · „3 bis 5 Mal pro Woche“; „Sehr aktiv“ · „6 bis 7 Mal pro Woche“;
   „Extrem aktiv“ · „Körperliche Arbeit und Sport“.
7. Fußnote: „Alter, Größe und Geschlecht werden in deinen persönlichen Daten gespeichert und nur für diese Berechnung
   verwendet.“
8. Unten getönte Kapsel 54 „Übernehmen“ (aktiv mit gültigem Alter, Größe, Gewicht).

**Zustände und Prüfungen.**

| Fall | Verhalten |
|---|---|
| Abnehmen, Zielgewicht über Gewicht | Zeile in ZIELGEWICHT: „Das Zielgewicht liegt über deinem Gewicht. Meinst du „Muskeln aufbauen“?“ + Text-Knopf „Wechseln“; Kapsel aus |
| Tempo unter der Untergrenze | „Für ein schnelleres Tempo müsstest du unter {floor} kcal essen. Wir rechnen nicht darunter.“ (Untergrenzen 1.200 bzw. 1.500) |
| Unter 18 | „Abnehmen“ deaktiviert mit Unterzeile „Für unter 18-Jährige berechnen wir kein Abnehm-Ziel.“ |
| Größe außerhalb 100 bis 250, Gewicht außerhalb 30 bis 300, Alter außerhalb 13 bis 110 | Hinweis unter dem Feld (Texte unten), Kapsel aus |
| „1,68“ bei Größe | wird „168 cm“, Hinweis „Als 168 cm übernommen“ |
| Divers, Keine Angabe | Mittelwert beider Formeln (F-K7, fachlich prüfen lassen) |
| Offline | Rechnung lokal, Speichern in der Warteschlange |
| Verlassen mit Änderungen | Alert „Änderungen verwerfen?“ / „Dein Ziel bleibt, wie es war.“ / „Verwerfen“ · „Weiter bearbeiten“ |
| „Übernehmen“ | zurück zum Ausgangsort, Gewicht nur loggen, wenn geändert (mit Health schreiben), kein Erfolgsmoment |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_setup_title` | Ziel berechnen | Calculate goal |
| `cal_setup_collapsed` | Ziel · {kcal} kcal | Goal · {kcal} kcal |
| `cal_sec_result` | Ergebnis | Result |
| `cal_kcal_per_day` | kcal am Tag | kcal a day |
| `cal_water_goal_line` | Wasser {amount} l | Water {amount} L |
| `cal_formula_note` | Berechnet nach Mifflin-St Jeor aus deinen Angaben. Richtwerte, kein ärztlicher Rat. | Calculated with the Mifflin-St Jeor formula from your details. Guide values, not medical advice. |
| `cal_missing_inputs` | Alter, Größe und Gewicht fehlen noch. | Age, height and weight are still missing. |
| `cal_goal_lose` | Abnehmen | Lose weight |
| `cal_goal_keep` | Gewicht halten | Keep my weight |
| `cal_goal_gain` | Muskeln aufbauen | Build muscle |
| `cal_sec_about` | Über dich | About you |
| `cal_sex` | Geschlecht | Sex |
| `cal_sex_female` | Weiblich | Female |
| `cal_sex_male` | Männlich | Male |
| `cal_sex_diverse` | Divers | Non-binary |
| `cal_sex_none` | Keine Angabe | Prefer not to say |
| `cal_age` | Alter | Age |
| `cal_years` | {n} Jahre | {n} years |
| `cal_height` | Größe | Height |
| `cal_weight` | Gewicht | Weight |
| `cal_use_health` | Aus Apple Health übernehmen | Use Apple Health data |
| `cal_from_health_note` | Größe und Gewicht aus Apple Health. | Height and weight from Apple Health. |
| `cal_pace_relaxed` | Gemütlich | Relaxed |
| `cal_pace_normal` | Normal | Steady |
| `cal_pace_fast` | Zügig | Fast |
| `cal_pace_line` | Etwa {kg} kg pro Woche. Zielgewicht etwa {when}. | About {kg} kg a week. Target weight around {when}. |
| `cal_sec_activity` | Alltag | Activity |
| `cal_act_sedentary` | Meist sitzend | Mostly sitting |
| `cal_act_sedentary_sub` | Büro, wenig Sport | Desk job, little exercise |
| `cal_act_light` | Leicht aktiv | Lightly active |
| `cal_act_light_sub` | 1 bis 3 Mal Sport pro Woche | Exercise 1 to 3 times a week |
| `cal_act_moderate` | Mäßig aktiv | Moderately active |
| `cal_act_moderate_sub` | 3 bis 5 Mal pro Woche | 3 to 5 times a week |
| `cal_act_active` | Sehr aktiv | Very active |
| `cal_act_active_sub` | 6 bis 7 Mal pro Woche | 6 to 7 times a week |
| `cal_act_very_active` | Extrem aktiv | Extremely active |
| `cal_act_very_active_sub` | Körperliche Arbeit und Sport | Physical job and exercise |
| `cal_privacy_note` | Alter, Größe und Geschlecht werden in deinen persönlichen Daten gespeichert und nur für diese Berechnung verwendet. | Age, height and sex are saved in your personal details and only used for this calculation. |
| `cal_apply` | Übernehmen | Use this goal |
| `cal_target_above` | Das Zielgewicht liegt über deinem Gewicht. Meinst du „Muskeln aufbauen“? | Your target is above your current weight. Did you mean “Build muscle”? |
| `cal_switch` | Wechseln | Switch |
| `cal_floor` | Für ein schnelleres Tempo müsstest du unter {floor} kcal essen. Wir rechnen nicht darunter. | A faster pace would mean eating under {floor} kcal. We don't go below that. |
| `cal_under_18` | Für unter 18-Jährige berechnen wir kein Abnehm-Ziel. | We don't calculate a weight-loss goal for anyone under 18. |
| `cal_height_range` | Bitte eine Größe zwischen 100 und 250 cm. | Enter a height between 100 and 250 cm. |
| `cal_weight_range` | Bitte ein Gewicht zwischen 30 und 300 kg. | Enter a weight between 30 and 300 kg. |
| `cal_age_range` | Bitte ein Alter zwischen 13 und 110. | Enter an age between 13 and 110. |
| `cal_height_converted` | Als {cm} cm übernommen | Saved as {cm} cm |
| `cal_discard_changes_title` | Änderungen verwerfen? | Discard changes? |
| `cal_discard_changes_body` | Dein Ziel bleibt, wie es war. | Your goal stays as it was. |

**Barrierefreiheit.** Ergebnis ist eine Live-Region (höflich, nach 1 s Ruhe angesagt: „Ergebnis: 2.000 Kilokalorien am
Tag“). Zielwahl und Alltag als Radiogruppen. Segmente bei 320 pt bis L, darüber Pull-down „Tempo: Normal“. Alle Felder
einspaltig (heute zwei nebeneinander, `goal_setup_screen.dart:252-296`). `numberXL` höchstens 51 pt.

**Daten.** `NutritionGoalCalculator` (mit Tempo in kg pro Woche, `timelineWeeks` bleibt für A), `NutritionGoalService`,
`users.age|height|gender` (heute ungefragt geschrieben; die Fußnote macht es sichtbar), `HealthSyncService.readProfile`
(Größe, Gewicht, Geburtsdatum, nur auf dem Gerät).

**Avo.** Keine.

---

### S15 Woche `/calories/week`

**Zweck.** Wie lief die Kalenderwoche (Mo bis So) im Vergleich zum Ziel?

**Route.** K im Home-Tab, `?start=` Montag.

**Aufbau.**

1. Toolbar: links `chevron.left`; rechts Glas-Gruppe `chevron.left` „Vorige Woche“ und `chevron.right` „Nächste Woche“
   (nächste nur bis zur laufenden).
2. Großer Titel „Woche“, darunter 15/20 #6C6C70 „2.–8. Nov.“.
3. Gruppe KALORIEN: „Ø 1.925“ `numberXL` mit „kcal“ 17/22, Unterzeile „an 4 abgeschlossenen Tagen · Ziel 2.000 ·
   Vorwoche Ø 2.040“, `BarChart` 180 hoch: y-Achse rechts mit 0, 1.000, 2.000, 3.000 (12/16 #6C6C70, 4 waagerechte
   Linien 1 pt #E5E5EA), Säulen eckig in `calRing`, laufender Tag nicht mitgezählt, Ziellinie gestrichelt mit
   „Ziel 2.000“ am Ende; nicht erfasste Tage ohne Säule.
4. Gruppe AUF KURS: „Im Ziel“ · „4 von 4 Tagen“; „Protein erreicht“ · „2 von 4 Tagen“; „Erfasst in Folge“ · „5 Tage“
   (ab 2); „Gekocht“ · „3 Mahlzeiten, 2 proteinreich“ (nur mit Rezept-Einträgen).
5. Gruppe MAKROS PRO TAG: „Protein“ · „Ø 96 von 133 g“, „Kohlenhydrate“, „Fett“.
6. Gruppe WASSER: „Ø 1,6 l an 5 Tagen“.
7. Gruppe: `NavRow` „Gewicht“ · „72,4 kg · −0,3 kg seit Mi.“, „Workouts“ · „3 · 1 Std. 40 Min“.
8. Fußnote (laufende Woche): „Heute zählt ab morgen mit.“

**Zustände.** Keine Daten: Gruppe KALORIEN mit leerem Diagramm (Achse, Ziellinie, keine Säulen) und Satz „Noch keine
Woche erfasst.“ Eine Wiegung: Gewicht ohne Delta. Offline: lokaler Stand; ältere Wochen ohne Cache: „Diese Woche ist
offline nicht gespeichert.“ Pro (falls Statistiken Pro werden): laufende Woche frei, „Vorige Woche“ trägt `ProBadge`
und öffnet `/pro?feature=cal_history`.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_week_title` | Woche | Week |
| `cal_week_prev` | Vorige Woche | Previous week |
| `cal_week_next` | Nächste Woche | Next week |
| `cal_avg_prefix` | Ø {avg} | Avg {avg} |
| `cal_week_sub` | an {n} abgeschlossenen Tagen · Ziel {goal} · Vorwoche Ø {prev} | over {n} completed days · goal {goal} · last week avg {prev} |
| `cal_goal_line_label` | Ziel {goal} | Goal {goal} |
| `cal_sec_on_track` | Auf Kurs | On track |
| `cal_on_target` | Im Ziel | On target |
| `cal_days_of` | {n} von {m} Tagen | {n} of {m} days |
| `cal_protein_reached` | Protein erreicht | Protein reached |
| `cal_streak` | Erfasst in Folge | Logged in a row |
| `cal_days` | {n, plural, =1{1 Tag} other{# Tage}} | {n, plural, =1{1 day} other{# days}} |
| `cal_cooked` | Gekocht | Cooked |
| `cal_cooked_value` | {n} Mahlzeiten, {p} proteinreich | {n} meals, {p} high in protein |
| `cal_sec_macros_day` | Makros pro Tag | Macros per day |
| `cal_avg_of` | Ø {avg} von {goal} g | Avg {avg} of {goal} g |
| `cal_water_avg` | Ø {amount} l an {n} Tagen | Avg {amount} L over {n} days |
| `cal_weight_delta` | {kg} kg · {delta} kg seit {day} | {kg} kg · {delta} kg since {day} |
| `cal_today_counts_tomorrow` | Heute zählt ab morgen mit. | Today counts from tomorrow. |
| `cal_week_offline_missing` | Diese Woche ist offline nicht gespeichert. | This week isn't saved for offline use. |

**Interaktion.** Waagerechtes Wischen auf der Gruppe KALORIEN wechselt die Woche (wie der Tageswechsel, Auswahl-Haptik).
Säule antippen öffnet S1 mit diesem Tag.

**Barrierefreiheit.** Diagramm: „Woche vom 2. bis 8. November: im Schnitt 1.925 Kilokalorien an 4 Tagen, Ziel 2.000“,
dann Säulen als Elemente mit „Montag, 1.910 Kilokalorien, im Ziel“ / „Mittwoch, nicht erfasst“. Achsen bis xxxL, ab
AX1 Werte als Textzeile unter dem Diagramm. Gruppe einstellbar für Wochenwechsel.

**Daten.** `weekSummaryProvider(weekStart)` (neu; Semantik von `WeeklyNutritionSummary` bleibt: Ø nur erfasste Tage, im
Ziel bis 105 %, Protein ab 90 %, Delta erst ab zwei Wiegungen, Serie bricht nicht am offenen Tag, proteinreich ab 20 g
und 30 % der kcal), Abfragen nur Summen.

**Avo.** Keine.

---

### S16 Gewicht `/calories/weight`

**Zweck.** Gewicht eintragen und den Verlauf sehen.

**Route.** K im Home-Tab.

**Aufbau.**

1. Toolbar: `chevron.left`; rechts getönter Primär-Kreis 44 `plus` „Gewicht eintragen“.
2. Großer Titel „Gewicht“.
3. Kopf ohne Gruppe: „72,4“ `numberXL` „kg“, darunter 15/20 #6C6C70 „Sa., 7. Nov. · −1,6 kg seit 2. Okt. · Ziel 70,0 kg“.
4. Segmented Control 44 „Monat | 3 Monate | Jahr | Alle“ (Standard 3 Monate; bei 320 pt „3 M.“).
5. Gruppe mit `LineChart` 180 hoch: x nach Datum (Lücken bleiben Lücken), gerade Segmente 2 pt in #1C1C1E, y-Ticks
   rechts in runden Schritten, Ziellinie gestrichelt „Ziel 70,0 kg“.
6. Gruppe EINTRÄGE (neueste oben, seitenweise je 30): „72,4 kg“ · „Sa., 7. Nov.“; Health-Einträge „73,0 kg“ ·
   „Sa., 31. Okt. · Withings“ (ohne Wischaktion). Fußnote „Einträge anderer Apps änderst du in Health.“

**Verhalten.** `plus` setzt oben eine neue Zeile im Bearbeiten-Zustand (Feld fokussiert, Datum „Heute“), Return
speichert, Health schreibt. Gleicher Tag ersetzt: Rückgängig „Gewicht für heute ersetzt (vorher 72,6 kg)“. Eigene Zeile
antippen: Wert und Datum an Ort und Stelle; der Punkt im Diagramm wandert mit `springStandard`. Wischen links „Löschen“
mit Rückgängig, Health-Wert danach mit.

**Zustände.** Leer: `EmptyState` ohne Figur, `scalemass` 48 #6C6C70, „Noch kein Gewicht eingetragen.“, getönte Kapsel
44 „Gewicht eintragen“. Ein Eintrag: Diagramm durch Satz ersetzt „Ab zwei Einträgen siehst du hier den Verlauf.“
Unplausibel (mehr als 3 kg in 2 Tagen): Zeile unter dem Feld „Das sind 3,4 kg mehr als am Mittwoch. Stimmt das?“,
Speichern bleibt möglich. Offline: Warteschlange.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_weight_title` | Gewicht | Weight |
| `cal_log_weight` | Gewicht eintragen | Log weight |
| `cal_weight_sub` | {date} · {delta} kg seit {since} · Ziel {target} kg | {date} · {delta} kg since {since} · target {target} kg |
| `cal_range_month` | Monat | Month |
| `cal_range_3m` | 3 Monate | 3 months |
| `cal_range_3m_short` | 3 M. | 3 mo |
| `cal_range_year` | Jahr | Year |
| `cal_range_all` | Alle | All |
| `cal_sec_entries` | Einträge | Entries |
| `cal_health_entries_note` | Einträge anderer Apps änderst du in Health. | Change entries from other apps in Health. |
| `cal_weight_empty` | Noch kein Gewicht eingetragen. | No weight logged yet. |
| `cal_weight_one` | Ab zwei Einträgen siehst du hier den Verlauf. | Your trend shows up after two entries. |
| `cal_weight_replaced` | Gewicht für heute ersetzt (vorher {old} kg) | Today's weight replaced (was {old} kg) |
| `cal_weight_check` | Das sind {diff} kg mehr als am {day}. Stimmt das? | That's {diff} kg more than on {day}. Is that right? |
| `cal_weight_check_less` | Das sind {diff} kg weniger als am {day}. Stimmt das? | That's {diff} kg less than on {day}. Is that right? |
| `cal_weight_deleted` | {kg} kg gelöscht | {kg} kg deleted |

**Barrierefreiheit.** Diagramm: „Gewicht in den letzten 3 Monaten: von 74,0 auf 72,4 Kilogramm, Ziel 70,0“, dann Punkte
als Elemente. Zeile „72,4 Kilogramm, Samstag, 7. November. Aktionen: Bearbeiten, Löschen“; Health-Zeile „…, aus
Withings, nur lesen“. Segmente ab xxL Pull-down. Keine Figur bei Körpergewicht.

**Daten.** `weightHistoryProvider(range)` (heute 90 Tage), `WeightLogService.upsert(date)` und `delete` (neu), Health
`bodyMass` lesen und schreiben, eigene Werte per Quelle erkennen und nicht doppelt zeigen.

**Avo.** Keine.

---

### S17 Workouts `/calories/workouts` (neu)

**Zweck.** Eigene Workouts eintragen und die aus Apple Health sehen.

**Route.** K im Home-Tab.

**Aufbau.**

1. Toolbar: `chevron.left`; getönter Primär-Kreis 44 `plus` „Workout eintragen“ (öffnet S18).
2. Großer Titel „Workouts“.
3. Gruppe DIESE WOCHE: „1 Std. 40 Min“ `numberXL`, „3 Workouts · ca. 820 kcal“ 15/20, `BarChart` 120 (Minuten je Tag,
   eckig, eine Farbe #1C1C1E, y-Ticks rechts 0, 30, 60 Min).
4. Je Tag eine Gruppe mit Kopf „HEUTE“, „GESTERN“, „DO., 5. NOV.“: Zeile 64 mit Symbol der Art 20 #6C6C70, „Laufen“
   17/22, Unterzeile „18:05 · 32 Min · Apple Watch“, rechts „280 kcal“ (bei Health-Werten ohne „ca.“, bei eigenen
   „ca. 280 kcal“).
5. Fußnote (mit Health): „Workouts von Apple Watch und anderen Apps kommen aus Apple Health.“

**Zustände.** Leer ohne Health: `EmptyState` `figure.run` 48 #6C6C70, „Noch keine Workouts.“, „Trag ein Workout ein oder
verbinde Apple Health, dann erscheinen die Workouts deiner Apple Watch hier.“, getönte Kapsel 44 „Workout eintragen“,
Text-Knopf „Mit Apple Health verbinden“ (S22). Leer mit Health: nur „Noch keine Workouts.“ und Kapsel. Health
abgelehnt: `StatusRow` „Apple Health ist nicht erlaubt. In Health erlauben“ (öffnet die Health-App). Offline: eigene in
der Warteschlange, Health ohnehin lokal. Pro (falls Health Pro): Text-Knopf trägt `ProBadge`.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_workouts_title` | Workouts | Workouts |
| `cal_log_workout` | Workout eintragen | Log workout |
| `cal_workouts_week_sub` | {n, plural, =1{1 Workout} other{# Workouts}} · ca. {kcal} kcal | {n, plural, =1{1 workout} other{# workouts}} · about {kcal} kcal |
| `cal_workout_row_sub` | {time} · {min} Min · {source} | {time} · {min} min · {source} |
| `cal_workouts_health_note` | Workouts von Apple Watch und anderen Apps kommen aus Apple Health. | Workouts from Apple Watch and other apps come from Apple Health. |
| `cal_workouts_empty_title` | Noch keine Workouts. | No workouts yet. |
| `cal_workouts_empty_body` | Trag ein Workout ein oder verbinde Apple Health, dann erscheinen die Workouts deiner Apple Watch hier. | Log a workout, or connect Apple Health to see your Apple Watch workouts here. |
| `cal_connect_health` | Mit Apple Health verbinden | Connect Apple Health |
| `cal_health_denied` | Apple Health ist nicht erlaubt. In Health erlauben | Apple Health access is off. Allow in Health |

**Barrierefreiheit.** Zeile „Laufen, heute 18:05, 32 Minuten, Apple Watch, 280 Kilokalorien“; Diagramm-Satz „Diese Woche
1 Stunde 40 Minuten an 3 Tagen“. Ab AX1 kcal unter der Unterzeile, Achsen als Textzeile.

**Daten.** `workoutsProvider(week)` (neu, eigene aus `workout_log` + Health lokal, eigene Health-Kopien per Quelle
ausgeblendet), `WorkoutLogService` (neu, Migration `workout_log`), `healthStatusProvider`.

**Avo.** Keine.

---

### S18 Workout eintragen oder bearbeiten `/calories/workouts/new`, `/calories/workouts/:workoutId`

**Zweck.** Ein Workout ohne Uhr nachtragen oder ein eigenes korrigieren.

**Route.** V-Route. Neu mit Kapsel; Bearbeiten speichert beim Verlassen.

**Aufbau.**

1. Kopf: `xmark` (neu) bzw. `chevron.left` (bearbeiten), Inline-Titel „Workout eintragen“ bzw. „Workout“.
2. Gruppe: „Art“ (Menü mit Symbolen: Laufen `figure.run`, Gehen `figure.walk`, Radfahren `figure.outdoor.cycle`,
   Schwimmen `figure.pool.swim`, Krafttraining `figure.strengthtraining.traditional`, Yoga `figure.yoga`,
   Intervalltraining `figure.highintensity.intervaltraining`, Wandern `figure.hiking`, Tanzen `figure.dance`, Sonstiges
   `figure.mixed.cardio`; vor iOS 17 `figure.run` bzw. `heart`), „Beginn“ (Datum und Uhrzeit, Rad an Ort und Stelle).
3. Gruppe: „Dauer“ mit Zahlenfeld „Min“ und Stepper ±5.
4. Gruppe: „Intensität“ Segmented Control 44 „Leicht | Mittel | Hart“.
5. Gruppe: „Kalorien“ Feld mit „ca. 280 kcal“ (vorbefüllt, änderbar); Fußnote „Geschätzt aus Art, Dauer, Intensität
   und deinem Gewicht (72,4 kg). Du kannst den Wert ändern.“ Ohne Gewicht: 70 kg und Fußnote „Mit deinem Gewicht wird
   die Schätzung genauer.“
6. Bearbeiten: eigene Gruppe „Workout löschen“ #D70015 (sofort, Rückgängig in S17).
7. Neu: unten getönte Kapsel 54 „Eintragen“.

**Zustände.** Health-Workout (nur lesen): alle Felder als Werte, Fußnote „Aus Apple Health · Apple Watch“, Text-Knopf
„In Health öffnen“. Verlassen mit Eingaben (neu): Alert „Workout verwerfen?“ / „Das Workout wird nicht eingetragen.“ /
„Verwerfen“ · „Weiter bearbeiten“. Nach „Eintragen“: Rückgängig „Krafttraining, 45 Min eingetragen“, Health schreibt.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_workout_title` | Workout | Workout |
| `cal_workout_type` | Art | Type |
| `cal_wt_running` | Laufen | Running |
| `cal_wt_walking` | Gehen | Walking |
| `cal_wt_cycling` | Radfahren | Cycling |
| `cal_wt_swimming` | Schwimmen | Swimming |
| `cal_wt_strength` | Krafttraining | Strength training |
| `cal_wt_yoga` | Yoga | Yoga |
| `cal_wt_hiit` | Intervalltraining | Interval training |
| `cal_wt_hiking` | Wandern | Hiking |
| `cal_wt_dance` | Tanzen | Dancing |
| `cal_wt_other` | Sonstiges | Other |
| `cal_start` | Beginn | Start |
| `cal_duration` | Dauer | Duration |
| `cal_minutes` | {n} Min | {n} min |
| `cal_intensity` | Intensität | Intensity |
| `cal_int_light` | Leicht | Light |
| `cal_int_medium` | Mittel | Moderate |
| `cal_int_hard` | Hart | Hard |
| `cal_workout_kcal_note` | Geschätzt aus Art, Dauer, Intensität und deinem Gewicht ({kg} kg). Du kannst den Wert ändern. | Estimated from type, duration, intensity and your weight ({kg} kg). You can change it. |
| `cal_workout_no_weight` | Mit deinem Gewicht wird die Schätzung genauer. | Adding your weight makes this estimate more accurate. |
| `cal_from_health_source` | Aus Apple Health · {source} | From Apple Health · {source} |
| `cal_open_in_health` | In Health öffnen | Open in Health |
| `cal_delete_workout` | Workout löschen | Delete workout |
| `cal_discard_workout_title` | Workout verwerfen? | Discard workout? |
| `cal_discard_workout_body` | Das Workout wird nicht eingetragen. | The workout won't be logged. |
| `cal_workout_logged` | {type}, {min} Min eingetragen | {type}, {min} min logged |

Die Kapsel heißt „Eintragen“ statt „Sichern“ (Konzept), damit jede Aufnahme im Bereich dasselbe Verb trägt.

**Barrierefreiheit.** Stepper einstellbar „Dauer, 45 Minuten“. Segmente ab L bei 320 pt Pull-down. Rad in voller Breite.

**Daten.** kcal lokal per MET-Tabelle × kg × Stunden, keine KI. `WorkoutLogService`, `HealthSyncService.saveWorkout`
(`HKWorkout` mit `activeEnergyBurned`).

**Avo.** Keine.

---

### S19 Challenges `/calories/challenges`

**Zweck.** Eine Gewohnheit üben und jeden Tag abhaken, ob es geklappt hat.

**Route.** K im Home-Tab.

**Aufbau.**

1. Toolbar `chevron.left`; großer Titel „Challenges“.
2. Je aktive Challenge eine Gruppe mit Kopf als Name („16:8 INTERVALLFASTEN“):
   - „Tag 5“ 20/25 Semibold, Unterzeile „seit Di., 3. Nov. · 4 von 4 Tagen geschafft“.
   - `DayDots` 12 pt (gefüllt #1C1C1E = geschafft, Ring mit kleinem `xmark` = nicht geschafft, gestrichelter Ring =
     offen; 14 Tage, 30-Tage-Challenges in Reihen zu 7 bzw. 10).
   - „Heute geschafft?“ 17/22 mit zwei Knöpfen nebeneinander: getönte Kapsel 44 „Geschafft“ und Glas-Kapsel 44 „Heute
     nicht“. Danach „Heute: geschafft“ mit `checkmark.circle.fill` Grün bzw. „Heute: nicht geschafft“ und Text-Knopf
     „Ändern“.
   - Fußzeile der Gruppe: Text-Knopf „Beenden“ (Grün, nur ohne Ende; speichert als abgeschlossen, Rückgängig) und
     Text-Knopf „Challenge abbrechen“ (#D70015, Bestätigungsdialog).
3. Gruppe STARTEN: Zeilen 64 „16:8 Intervallfasten“ · „16 Stunden nichts essen, 8 Stunden Essenszeit. Läuft, bis du sie
   beendest.“; „30 Tage ohne Zucker“ · „Kein zugesetzter Zucker, 30 Tage lang.“; `NavRow` „Eigene Challenge“ (S20).
   Aktive Typen fehlen hier.
4. Gruppe ABGESCHLOSSEN: „30 Tage ohne Zucker“ · „1.–30. Okt. · 26 von 30 Tagen“ bzw. „abgebrochen nach 9 Tagen“.
5. Fußnote: „Challenges sind freiwillig. Ein verpasster Tag beendet nichts.“

**Zustände.** Keine aktiv: kleiner `EmptyState` ohne Figur über STARTEN: `flag` 48, „Eine Gewohnheit üben?“, „Wähle unten
eine Challenge. Du hakst jeden Tag ab, ob es geklappt hat.“ Feste Challenge abgelaufen: steht in ABGESCHLOSSEN
(serverseitig geschlossen, nicht beim Lesen). Feste Challenge erfüllt: `SuccessMoment` mit `avo_celebrating` 120,
„30 Tage ohne Zucker geschafft.“ / „26 von 30 Tagen“, Erfolgs-Haptik, einmal. Offline: Check-in in der Warteschlange.
Zwei Geräte: Check-in als eigene Zeile, kein Überschreiben. Pro (falls entschieden): „Eigene Challenge“ mit
`ProBadge`.

Starten geht ohne Dialog: Tipp auf die Zeile startet, Rückgängig „16:8 Intervallfasten gestartet“. Abbrechen-Dialog:
„„30 Tage ohne Zucker“ abbrechen?“ / „Dein Fortschritt bleibt im Verlauf. Die Challenge lässt sich nicht fortsetzen.“ /
„Challenge abbrechen“ (destruktiv) · „Weitermachen“.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_challenges_title` | Challenges | Challenges |
| `cal_ch_fasting` | 16:8 Intervallfasten | 16:8 intermittent fasting |
| `cal_ch_fasting_sub` | 16 Stunden nichts essen, 8 Stunden Essenszeit. Läuft, bis du sie beendest. | 16 hours without food, then an 8-hour eating window. Runs until you finish it. |
| `cal_ch_nosugar` | 30 Tage ohne Zucker | 30 days without sugar |
| `cal_ch_nosugar_sub` | Kein zugesetzter Zucker, 30 Tage lang. | No added sugar for 30 days. |
| `cal_ch_custom` | Eigene Challenge | Your own challenge |
| `cal_ch_day` | Tag {n} | Day {n} |
| `cal_ch_since` | seit {date} · {k} von {n} Tagen geschafft | since {date} · {k} of {n} days done |
| `cal_ch_question_default` | Heute geschafft? | Done today? |
| `cal_ch_done` | Geschafft | Done |
| `cal_ch_not_today` | Heute nicht | Not today |
| `cal_ch_today_done` | Heute: geschafft | Today: done |
| `cal_ch_today_missed` | Heute: nicht geschafft | Today: not done |
| `cal_ch_change` | Ändern | Change |
| `cal_ch_finish` | Beenden | Finish |
| `cal_ch_stop` | Challenge abbrechen | Stop challenge |
| `cal_ch_stop_title` | „{name}“ abbrechen? | Stop “{name}”? |
| `cal_ch_stop_body` | Dein Fortschritt bleibt im Verlauf. Die Challenge lässt sich nicht fortsetzen. | Your progress stays in your history. You can't resume this challenge. |
| `cal_ch_keep_going` | Weitermachen | Keep going |
| `cal_sec_start` | Starten | Start one |
| `cal_sec_finished` | Abgeschlossen | Finished |
| `cal_ch_result` | {range} · {k} von {n} Tagen | {range} · {k} of {n} days |
| `cal_ch_stopped_after` | abgebrochen nach {n, plural, =1{1 Tag} other{# Tagen}} | stopped after {n, plural, =1{1 day} other{# days}} |
| `cal_ch_note` | Challenges sind freiwillig. Ein verpasster Tag beendet nichts. | Challenges are voluntary. Missing a day doesn't end anything. |
| `cal_ch_empty_title` | Eine Gewohnheit üben? | Want to practise a habit? |
| `cal_ch_empty_body` | Wähle unten eine Challenge. Du hakst jeden Tag ab, ob es geklappt hat. | Pick a challenge below. Each day you tick off whether it worked. |
| `cal_ch_started` | {name} gestartet | {name} started |
| `cal_ch_finished_toast` | {name} beendet | {name} finished |
| `cal_ch_success` | {name} geschafft. | {name} done. |

**Barrierefreiheit.** `DayDots` als ein Element „14 Tage: 4 geschafft, 1 nicht geschafft, 9 offen“, Punkte ausgeblendet
(Farbe nie allein: Form unterscheidet geschafft, nicht geschafft, offen). Knöpfe ab xxL und bei 320 pt untereinander.
Erfolgsmoment: Figur ausgeblendet, Text angesagt, ab AX3 ohne Figur.

**Daten.** `activeChallengesProvider`, `DietChallengeService` (Check-ins als Tabelle `challenge_checkins` statt jsonb,
Unique-Index für `custom` anpassen, Auto-Abschluss als geplante Edge Function; Migrationen offen).

**Avo.** `avo_celebrating` nur im Erfolgsmoment.

---

### S20 Eigene Challenge `/calories/challenges/new`

**Zweck.** Eine eigene Gewohnheit mit eigener Frage anlegen.

**Route.** V-Route.

**Aufbau.** Kopf `xmark`, Inline-Titel „Eigene Challenge“. Gruppe: Feld „Name“ (Platzhalter „Zum Beispiel Kein Alkohol
unter der Woche“), Feld „Tägliche Frage“ (vorbefüllt „Heute geschafft?“). Gruppe: „Dauer“ mit Stepper (7 bis 90 Tage in
7er-Schritten) und darunter `ToggleRow` „Ohne Ende“ (an: Stepper verschwindet). Fußnote „Du hakst jeden Tag ab, ob es
geklappt hat.“ Unten getönte Kapsel 54 „Starten“ (aktiv mit Namen).

**Zustände.** Name fehlt: Kapsel aus. Ungespeichert verlassen: Alert „Challenge verwerfen?“ / „Sie wird nicht
gestartet.“ / „Verwerfen“ · „Weiter bearbeiten“. Nach „Starten“: zurück zu S19, Rückgängig „{name} gestartet“.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_ch_new_title` | Eigene Challenge | Your own challenge |
| `cal_ch_name_placeholder` | Zum Beispiel Kein Alkohol unter der Woche | For example no alcohol on weekdays |
| `cal_ch_question` | Tägliche Frage | Daily question |
| `cal_ch_no_end` | Ohne Ende | No end date |
| `cal_ch_new_note` | Du hakst jeden Tag ab, ob es geklappt hat. | Each day you tick off whether it worked. |
| `cal_ch_start` | Starten | Start |
| `cal_ch_discard_title` | Challenge verwerfen? | Discard challenge? |
| `cal_ch_discard_body` | Sie wird nicht gestartet. | It won't be started. |

**Barrierefreiheit.** Stepper einstellbar „Dauer, 28 Tage“. Felder einspaltig, ab xxL Beschriftung über dem Feld.

**Daten.** `DietChallengeService.startChallenge` mit `title`, `duration_days`, `question` (neue Spalten).

**Avo.** Keine.

---

### S21 Ideen für heute `/calories/ideas`

**Zweck.** Rezepte finden, die noch ins heutige Budget passen.

**Route.** K im Home-Tab. Einstiege: „Was passt noch?“ (S0, S1), Hinweis auf Home, Mitteilung „Ideen fürs Abendessen“.

**Aufbau.**

1. Toolbar `chevron.left`; großer Titel „Ideen für heute“; Unterzeile 15/20 #6C6C70 „Noch 640 kcal · Abendessen“.
2. Chip-Reihe (scrollt waagerecht in ihrer eigenen Zeile): „Bis 400 kcal“, „Schnell“, „Mit meiner Liste“ (Mehrfachwahl,
   UND-verknüpft), danach Text-Knopf „Zurücksetzen“, sobald einer gewählt ist.
3. Gruppe mit Rezeptzeilen 76: Bild 56 Radius 10, Titel 17/22 Semibold (2 Zeilen), „520 kcal · 35 Min“ 15/20 #6C6C70,
   Zeile mit `checklist` 13 „3 Zutaten stehen auf Wocheneinkauf“. Sortierung: passt ins Budget, Zutaten auf der Liste,
   eigene gespeicherte zuerst. Tippen öffnet das Rezeptdetail über diesem Tab, damit Zurück
   wieder hier landet (Anfrage A-R3).
4. Fußnote bei eingetragener Allergie: „Wir blenden Rezepte aus, in deren Zutaten Erdnuss steht. Prüf die Zutaten
   trotzdem selbst.“ und Link „Ernährung & Allergien“.

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Unter 150 kcal übrig | `EmptyState` ohne Figur: `fork.knife` 48, „Nur noch 90 kcal heute.“, „Für ein ganzes Gericht reicht das nicht mehr.“, Text-Knopf „Alle Rezepte“ |
| Über dem Ziel | „Heute bist du 120 kcal über deinem Ziel.“, „Morgen geht es mit 2.000 kcal weiter.“ |
| Keine Treffer | `avo_thinking` 96, „Für 640 kcal passt gerade nichts aus deinen Rezepten.“, Text-Knopf „Rezepte entdecken“ |
| Kein Ziel | „Ohne Ziel gibt es kein Budget.“, getönte Kapsel 44 „Ziel einrichten“ |
| Offline | `StatusRow` „Offline. Du siehst nur gespeicherte Rezepte.“, nur lokale Rezepte |
| Leer | immer scrollbar, Pull-to-Refresh |

Kontextmenü einer Zeile: „Ins Tagebuch eintragen“ (S10), „Zum Wochenplan“ (nur Modul Wochenplan), „Merken“.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_ideas_title` | Ideen für heute | Ideas for today |
| `cal_ideas_sub` | Noch {kcal} kcal · {meal} | {kcal} kcal left · {meal} |
| `cal_chip_under_400` | Bis 400 kcal | Up to 400 kcal |
| `cal_chip_quick` | Schnell | Quick |
| `cal_chip_my_list` | Mit meiner Liste | Uses my list |
| `cal_reset` | Zurücksetzen | Reset |
| `cal_recipe_meta` | {kcal} kcal · {min} Min | {kcal} kcal · {min} min |
| `cal_on_list` | {n, plural, =1{1 Zutat steht auf {list}} other{# Zutaten stehen auf {list}}} | {n, plural, =1{1 ingredient is on {list}} other{# ingredients are on {list}}} |
| `cal_allergy_filter_note` | Wir blenden Rezepte aus, in deren Zutaten {allergen} steht. Prüf die Zutaten trotzdem selbst. | Recipes that list {allergen} as an ingredient are hidden. Please still check the ingredients yourself. |
| `cal_diet_allergies` | Ernährung & Allergien | Diet & allergies |
| `cal_ideas_low_title` | Nur noch {kcal} kcal heute. | Only {kcal} kcal left today. |
| `cal_ideas_low_body` | Für ein ganzes Gericht reicht das nicht mehr. | That's not enough for a full meal. |
| `cal_all_recipes` | Alle Rezepte | All recipes |
| `cal_ideas_over_title` | Heute bist du {kcal} kcal über deinem Ziel. | You're {kcal} kcal over your goal today. |
| `cal_ideas_over_body` | Morgen geht es mit {goal} kcal weiter. | Tomorrow starts again at {goal} kcal. |
| `cal_ideas_none` | Für {kcal} kcal passt gerade nichts aus deinen Rezepten. | None of your recipes fit {kcal} kcal right now. |
| `cal_discover_recipes` | Rezepte entdecken | Discover recipes |
| `cal_ideas_no_goal` | Ohne Ziel gibt es kein Budget. | Without a goal there's no budget. |
| `cal_ideas_offline` | Offline. Du siehst nur gespeicherte Rezepte. | You're offline. Only saved recipes are shown. |
| `cal_add_to_diary` | Ins Tagebuch eintragen | Add to diary |
| `cal_add_to_plan` | Zum Wochenplan | Add to meal plan |
| `cal_save_recipe` | Merken | Save |

**Barrierefreiheit.** Chips mit Zustand „ausgewählt“; Ergebnisanzahl wird nach jeder Filteränderung angesagt („4
Rezepte“). Rezeptzeile „Ofengemüse mit Feta, 520 Kilokalorien, 35 Minuten, 3 Zutaten auf Wocheneinkauf“. Ab xxxL
brechen Chips um (Reihe wird mehrzeilig statt zu scrollen); ab AX1 Bild über dem Titel.

**Daten.** `whatCanIEatSuggestionsProvider` (bleibt, `CalorieRecipeNudgeService` ohne KI), Allergie-Abgleich mit
`AllergyType`-Stichwörtern statt roher IDs (heute wirkungslos, `calorie_recipe_nudge_service.dart:211-215`),
Listen-Abgleich über `ItemRepository` (A, lesend).

**Avo.** `avo_thinking` nur bei „Keine Treffer“.

---

### S22 Apple Health verbinden (Vorab-Screen) `/calories/health`

**Zweck.** Vor der Systemabfrage sagen, was geschrieben und gelesen wird und wo die Daten bleiben. Zu viel Text für
einen Alert, deshalb Vollbild.

**Route.** V-Route. Einstiege: Tipp-Zeile S1, S13, S17, S23 „Verbinden“, S14 „Aus Apple Health übernehmen“,
Avo-Werkzeug `sync_health` (öffnet nur diesen Screen, setzt nie selbst Berechtigungen), Onboarding-Link (A). Auf Geräten
ohne Health (`HKHealthStore.isHealthDataAvailable()` false) gibt es keinen Einstieg.

**Aufbau.**

1. Kopf: `xmark` „Schließen“.
2. Mittig Health-Symbol 48: das offizielle Health-App-Symbol aus Apples Marketing-Material, falls der Owner es freigibt,
   sonst SF Symbol `heart.fill` in #FF2D55. Kein nachgebautes Health-Logo.
3. Titel 28/34 Bold „Apple Health verbinden“.
4. Gruppe „AVO SCHREIBT IN HEALTH“ (Kopf mit `{app}`): Zeilen 52 mit Symbol 20 #6C6C70: `fork.knife` „Essen mit Kalorien
   und Nährwerten“, `drop` „Wasser“, `scalemass` „Gewicht“, `figure.run` „Workouts“.
5. Gruppe „AVO LIEST AUS HEALTH“: `scalemass` „Gewicht, zum Beispiel von deiner Waage“, `ruler` „Größe“, `drop` „Wasser“,
   `figure.run` „Workouts, zum Beispiel von deiner Apple Watch“.
6. Absatz 15/20 #3A3A3C: „Was Avo aus Health liest, bleibt auf deinem iPhone und wird nicht auf unseren Server geladen.
   Was du erlaubst, änderst du jederzeit in Health.“
7. Unten getönte Kapsel 54 „Weiter“ (öffnet die Systemabfrage für Lesen und Schreiben), darüber Text-Knopf „Nicht
   jetzt“.

**Zustände.** Nach der Abfrage: Screen schließt, Health-Daten blenden am Ausgangsort ein, Ansage „Apple Health
verbunden“. Zurück ohne Entscheidung zählt wie „Nicht jetzt“ (die Tipp-Zeile auf S1 kommt nicht wieder). Pro (falls
Health Pro wird): `ProBadge` hinter dem Titel, Kapsel „Mit Avo Pro verbinden“ öffnet `/pro?feature=cal_health`, nach dem
Kauf direkt die Systemabfrage. Schon gefragt und Schreiben abgelehnt: Kapsel „In Health öffnen“ statt „Weiter“, Satz
„Apple Health ist nicht erlaubt. In Health erlauben“.

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_hk_title` | Apple Health verbinden | Connect Apple Health |
| `cal_hk_writes` | {app} schreibt in Health | {app} writes to Health |
| `cal_hk_reads` | {app} liest aus Health | {app} reads from Health |
| `cal_hk_food` | Essen mit Kalorien und Nährwerten | Food with calories and nutrients |
| `cal_hk_water` | Wasser | Water |
| `cal_hk_weight` | Gewicht | Weight |
| `cal_hk_workouts` | Workouts | Workouts |
| `cal_hk_weight_read` | Gewicht, zum Beispiel von deiner Waage | Weight, for example from your scale |
| `cal_hk_height` | Größe | Height |
| `cal_hk_workouts_read` | Workouts, zum Beispiel von deiner Apple Watch | Workouts, for example from your Apple Watch |
| `cal_hk_privacy` | Was {app} aus Health liest, bleibt auf deinem iPhone und wird nicht auf unseren Server geladen. Was du erlaubst, änderst du jederzeit in Health. | What {app} reads from Health stays on your iPhone and isn't uploaded to our server. You can change what's allowed in Health at any time. |
| `cal_hk_connected_a11y` | Apple Health verbunden | Apple Health connected |
| `cal_hk_connect_pro` | Mit {pro} verbinden | Connect with {pro} |

**Barrierefreiheit.** Titel als Überschrift, Gruppenköpfe als Überschriften (normale Schreibung im Label), Symbole
ausgeblendet. Fokus: Schließen, Titel, Gruppen, Absatz, „Nicht jetzt“, „Weiter“. Ab AX1 Knöpfe in voller Breite
untereinander.

**Daten.** `HealthSyncService` (neu) über den Kanal `shoply/health` (Swift: `requestAuthorization`, Lese- und
Schreibtypen wie Digest 15 Abschnitt 4, `authorizationStatus(for:)` nur für Schreiben aussagekräftig). Voraussetzungen:
HealthKit-Capability in `Runner.entitlements` und `RunnerDebug.entitlements`, App-ID im Developer-Portal (Owner),
`NSHealthShareUsageDescription` und `NSHealthUpdateUsageDescription` mit `InfoPlist.strings` DE/EN (Owner-Freigabe der
Texte; ohne sie stürzt die Abfrage ab). Der Satz in Punkt 6 muss technisch stimmen: Health-Daten gehen nicht an
Supabase und nicht an Claude.

**Avo.** Keine (Gesundheitsdaten).

---

### S23 Einstellungen „Kalorien & Gesundheit“ `/settings/health`

**Zweck.** Health, Ziele, Wasser, Einheiten, Erinnerungen und Essensfotos an einem Ort.

**Route.** E im Profil-Tab. A verlinkt aus `X-Profil` die Zeile „Apple Health · Verbunden“ und den Modul-Bereich
hierher. Ist das Modul aus, ist die Seite im Profil unsichtbar und die Route zeigt S24.

**Aufbau (X-Profil-Stil: Gruppen mit Zeilen 52, ohne Symbol-Kacheln).**

1. Toolbar `chevron.left`; großer Titel „Kalorien & Gesundheit“.
2. Gruppe APPLE HEALTH: „Status“ · „Verbunden“ bzw. Zeile „Verbinden“ in Grün (S22); „In Health verwalten“ (öffnet die
   Health-App). Fußnote „Avo schreibt Essen, Wasser, Gewicht und Workouts. Was Avo lesen darf, änderst du in Health unter
   Teilen > Apps > Avo.“
3. Gruppe ZIELE: `NavRow` „Ziele“ · „2.000 kcal“ (öffnet `/settings/health/goals`).
4. Gruppe WASSER: „Tagesziel“ · „2 l“ (Stepper ±0,25 l an Ort und Stelle; heute fest 2.000 ml), „Schnelltaste“ ·
   „250 ml“ (Menü 150, 200, 250, 330, 500 ml).
5. Gruppe EINHEITEN: „Gewicht“ · „kg“ (Menü kg, lb), „Energie“ · „kcal“ (Menü kcal, kJ).
6. Gruppe ERINNERUNGEN: `ToggleRow` „Ideen fürs Abendessen“ mit Unterzeile „Täglich um 18:00, wenn noch Budget übrig
   ist“; ist er an, darunter Zeile „Uhrzeit“ · „18:00“ (Rad an Ort und Stelle). `ToggleRow` „Wochenrückblick“ ·
   „Sonntags um 19:00“ (Standard aus). Die Mitteilungs-Erlaubnis wird erst beim Einschalten gefragt.
7. Gruppe DATEN: Text-Knopf „Alle Essensfotos löschen“ #D70015 (ohne Fotos deaktiviert mit Wert „Keine“).

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Health verbunden, aber keine Daten gelesen | Fußnote zusätzlich „Keine Daten aus Health. Prüf in Health unter Teilen > Apps > Avo, was erlaubt ist.“ |
| Gerät ohne Health | Gruppe APPLE HEALTH entfällt |
| Mitteilungen abgelehnt | `StatusRow` in der Gruppe „Mitteilungen sind aus. In Einstellungen erlauben“, Schalter bleiben aus |
| Fotos löschen | Alert „Alle 23 Essensfotos löschen?“ / „Die Einträge bleiben, nur die Fotos werden gelöscht. Das lässt sich nicht rückgängig machen.“ / „Fotos löschen“ (destruktiv) · „Abbrechen“; danach Hinweis ohne Rückgängig „23 Essensfotos gelöscht“ |
| Offline | Einstellungen lokal sofort, Konto-Abgleich in der Warteschlange; Fotos löschen braucht Verbindung („Braucht eine Verbindung“ am Knopf) |
| Modul aus | S24 |

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_settings_title` | Kalorien & Gesundheit | Calories & Health |
| `cal_set_status` | Status | Status |
| `cal_set_connect` | Verbinden | Connect |
| `cal_set_manage_health` | In Health verwalten | Manage in Health |
| `cal_set_health_note` | {app} schreibt Essen, Wasser, Gewicht und Workouts. Was {app} lesen darf, änderst du in Health unter Teilen > Apps > {app}. | {app} writes food, water, weight and workouts. Change what {app} can read in Health under Sharing > Apps > {app}. |
| `cal_set_no_health_data` | Keine Daten aus Health. Prüf in Health unter Teilen > Apps > {app}, was erlaubt ist. | No data from Health. Check what's allowed in Health under Sharing > Apps > {app}. |
| `cal_set_water_goal` | Tagesziel | Daily goal |
| `cal_set_quick_add` | Schnelltaste | Quick add |
| `cal_set_units` | Einheiten | Units |
| `cal_set_energy` | Energie | Energy |
| `cal_set_reminders` | Erinnerungen | Reminders |
| `cal_set_dinner_ideas` | Ideen fürs Abendessen | Dinner ideas |
| `cal_set_dinner_ideas_sub` | Täglich um {time}, wenn noch Budget übrig ist | Daily at {time} if there's budget left |
| `cal_set_weekly` | Wochenrückblick | Weekly summary |
| `cal_set_weekly_sub` | Sonntags um 19:00 | Sundays at 7 pm |
| `cal_set_notif_denied` | Mitteilungen sind aus. In Einstellungen erlauben | Notifications are off. Allow in Settings |
| `cal_set_data` | Daten | Data |
| `cal_set_delete_photos` | Alle Essensfotos löschen | Delete all meal photos |
| `cal_set_none` | Keine | None |
| `cal_set_delete_photos_title` | {n, plural, =1{Das Essensfoto löschen?} other{Alle # Essensfotos löschen?}} | {n, plural, =1{Delete the meal photo?} other{Delete all # meal photos?}} |
| `cal_set_delete_photos_body` | Die Einträge bleiben, nur die Fotos werden gelöscht. Das lässt sich nicht rückgängig machen. | Your entries stay; only the photos are deleted. This can't be undone. |
| `cal_set_delete_photos_confirm` | Fotos löschen | Delete photos |
| `cal_set_photos_deleted` | {n, plural, =1{1 Essensfoto gelöscht} other{# Essensfotos gelöscht}} | {n, plural, =1{1 meal photo deleted} other{# meal photos deleted}} |
| `cal_needs_connection` | Braucht eine Verbindung | Needs a connection |

Einstellungs-Suche (A-Index, Schlüssel `health_*`): Suchwörter „Health“, „Apple Health“, „Wasser“, „kJ“, „lb“,
„Kalorien“, „Erinnerung“, „Essensfotos“.

**Barrierefreiheit.** Schalter mit Zustand „ein/aus“; Unterzeile Teil des Labels. Destruktiver Knopf mit Hinweis „Fragt
vorher nach“. Ab AX1 Werte unter den Titeln.

**Daten.** `calorieSettingsProvider` (neu: Wasserziel, Schnelltaste, Einheiten, Erinnerungen, lokal und im Konto; Lücke
Spalten, siehe 7), `healthStatusProvider`, `MascotNotificationService.rearmDinnerIdeasReminder` (gehört gerade einem
anderen Workflow; Schwelle 150 oder 300 kcal ist offen), `MealPhotoStorageService.deleteAll` (neu, privater Bucket),
`NotificationPermissionService`.

**Avo.** Keine.

---

### S24 Modul ist aus (zentrierter Dialog)

**Zweck.** Ein Aufruf eines Kalorien-Screens bei ausgeschaltetem Modul (Deep Link, Widget, Mitteilung, Siri, Kurzbefehl,
Avo) landet nicht still auf Home, sondern fragt.

**Navigation.** `showModuleOffAlert(context, AppModule.calories, onEnable:)` von A (A2), zentrierter Dialog, kein Sheet.
In Avo statt Dialog eine Ergebniszeile „Das Modul Kalorien ist aus“ mit „Einschalten“.

**Texte.**

| Schlüssel | Deutsch | English |
|---|---|---|
| `cal_module_off_title` | Das Modul Kalorien ist aus | The Calories module is off |
| `cal_module_off_body` | Schalte es ein, um dein Tagebuch zu öffnen. Deine Einträge sind noch da. | Turn it on to open your diary. Your entries are still here. |
| `cal_not_now` | Nicht jetzt | Not now |
| `cal_turn_on` | Einschalten | Turn on |

„Einschalten“ ist der Standard-Knopf (fett). Danach öffnet das ursprüngliche Ziel, ohne Ziel S1a. „Nicht jetzt“ bleibt
dort, wo man war (bei Kaltstart: Home). Health-Synchronisation pausiert, solange das Modul aus ist; Daten bleiben.

**Barrierefreiheit.** Systemdialog; Fokus auf dem Titel.

**Daten.** `moduleEnabledProvider(AppModule.calories)`, `appModulesProvider.notifier.setEnabled`.

**Avo.** Keine.

---

## 5. Konflikte zwischen D2 und Konzept

Optik entscheidet D2, Inhalt das Konzept. Wo beides kollidiert, gilt die Empfehlung bis zur Owner-Entscheidung.
Nummern in Klammern verweisen auf die Owner-Fragen im Rückgabe-Ergebnis.

| Nr. | Stelle | D2 | Konzept | Empfehlung |
|---|---|---|---|---|
| K1 | Ring-Mitte Home-Karte | „1.240 von 2.000 kcal“ (gegessen) | „640 kcal übrig“ | D2-Optik, Inhalt Konzept: „640“ / „kcal übrig“ in der Mitte, „1.360 gegessen · Ziel 2.000“ unter „Heute“ (Owner-Frage 1) |
| K2 | Ring- und Makrofarben | Orange, Blau, Orange, Lila | alles eine Farbe | D2-Farben; Ring und Kohlenhydrate in #C8641A statt #E8833A wegen 3:1 (Owner-Frage 2) |
| K3 | Werte-Schreibweise | „62 / 110 g“ | „82 von 133 g“ | „62 von 110 g“ (Text ist Inhalt; liest sich wie gesprochen) |
| K4 | Essen eintragen | Segment Foto, Barcode, Suche; Ergebnis direkt auf dem Screen | Suchfeld, drei Zeilen, Manuell, Zuletzt gegessen, Mahlzeit-Segment, Kamera und Schätzung als eigene Screens | D2-Segment, Start „Suche“; „Zuletzt gegessen“ und „Manuell“ im Segment Suche; Mahlzeit über das Titel-Menü; Kamera und Schätzung als eigene Vollbild-Screens, die Schätzung im X-Essen-Look (Owner-Frage 4) |
| K5 | Segmenthöhe | 36 pt | – | 44 pt aus `D2-Komponenten` (Trefferfläche) |
| K6 | Hauptaktion in Eintrage-Screens | Kapsel 54 unten | getönte Text-Kapsel oben rechts (`EditorScaffold`) | D2: unten in voller Breite, über der Tastatur mitlaufend |
| K7 | Schließen | `xmark` | Zurück-Pfeil, Tab-Leiste sichtbar | `xmark` am Anfang eines Ablaufs, `chevron.left` in Folgeschritten und beim Bearbeiten, keine Tab-Leiste in Eintrage-Screens; Übergang immer Push von rechts |
| K8 | Nach dem Eintragen | – | immer zurück ins Tagebuch | zurück zum Ausgangsort (Home bleibt Home, Rezept bleibt Rezept), Rückgängig-Hinweis dort (Owner-Frage 5) |
| K9 | Pille auf dem Foto | „Avo hat erkannt“ | – (Ehrlichkeit: „geschätzt“) | „Geschätzt“ mit Funkeln; während der Schätzung Mini-Avo „Wird geschätzt …“ (Owner-Frage 3) |
| K10 | Sicherheitstext | „KI-Schätzung, mittlere Sicherheit · bitte kurz prüfen“ | Wortstufen, „ca.“, „geschätzt“ | „ca. 650 kcal“, Punkte plus „Unsicher“, Fußnote zu den Gramm (Owner-Frage 3) |
| K11 | Health-Zeile auf der Schätzung | immer sichtbar | – | nur mit Health verbunden und Schreiben erlaubt |
| K12 | Knopf der Home-Karte | „Mahlzeit hinzufügen“ | „Essen eintragen“ (Toolbar, Titel S3) | „Essen eintragen“, damit Einstieg, Titel und Kapsel dasselbe Verb tragen |
| K13 | Fußzeile der Home-Karte | „Passt zu deinem Ziel: Feta, Hafermilch auf der Liste“ | „Was passt noch? 6 Rezepte“ | Konzept-Text mit den D2-Mini-Bildern; die D2-Aussage hat keine belegbare Quelle (Owner-Frage 10) |
| K14 | Wasser-Kachel | ohne Knopf, „1,2 / 2 L“ | Zeile mit „+250 ml“, „1,25 l von 2 l“ | D2-Kachel mit 44-pt-Plus wie „Nochmal kaufen“; Zahl mit zwei Nachkommastellen nach `intl`, „l“ klein (Owner-Frage 6) |
| K15 | Großbuchstaben | Kicker „KALORIEN“, Gruppenköpfe groß | normale Schreibung | D2; VoiceOver-Label in normaler Schreibung |
| K16 | Leere Zustände | Avo-Figuren in Bildern | Symbole (`target`, `flag`) | Figur dort, wo sie zum Anlass passt (S1a, S3, S19, S21), Symbole bei Körper- und Gesundheitsdaten (S16, S17, S22) |
| K17 | Zahlgröße | größte Zahl 34/41 | `numberXL` | `numberXL` = 34/41 Bold bei L, höchstens 51 pt |
| K18 | Workout speichern | – | „Sichern“ | „Eintragen“ (ein Verb für alles Aufnehmen) |
| K19 | Schalter Workouts | – | „Verbrauch durch Workouts gutschreiben“ | „Workout-Kalorien zum Tagesbudget zählen“ |
| K20 | Modul-aus-Titel | – | „Kalorien ist ausgeschaltet“ (Kap. 15) bzw. „Kalorien & Gesundheit ist ausgeschaltet“ (Kap. 18) | „Das Modul Kalorien ist aus“ (grammatisch sauber, Owner-Frage 7) |
| K21 | Eintrage-Flows auf Kamera | – | Kamera als Cover von unten | Push von rechts; nichts gleitet von unten herein (Owner-Regel) |

---

## 6. Anfragen an Teil A

Bausteine, die im D2-Blatt fehlen oder für diesen Bereich eine Variante brauchen. Ohne sie baut B nicht selbst ins
Designsystem.

| Nr. | Anfrage | Wofür |
|---|---|---|
| A-C1 | `InsetSection` (Gruppe 26 mit GROSS-Kopf, Zahl rechts im Kopf, Fußnote) und Zeilen-Varianten `NavRow`, `ValueRow`, `ToggleRow` (Schalter 51 × 31), Feld-Zeile mit Label links und ab xxL darüber, ausklappbare Zeile mit Feld und Stepper | alle Screens |
| A-C2 | `EditorScaffold` für V-Routen: Kopf mit `xmark` oder `chevron.left` und Inline-Titel als optionale Menü-Taste, untere getönte Kapsel 54, die über der Tastatur mitläuft, „verwerfen?“-Dialog beim Verlassen, Glas-Budget | S3 bis S10, S14, S18, S20 |
| A-C3 | `AppMenu` mit Kalender-Variante (verwandelt sich an Ort und Stelle in ein Monatsraster, Tage 44, Punkt für Tage mit Daten, Zukunft gesperrt) und Rad ab AX1 | S2 und alle Zeilen „Datum“ |
| A-C4 | Segmented Control 44 mit Pull-down-Rückfall ab xxL (`chevron.up.chevron.down`) | S3, S14, S16, S18 |
| A-C5 | Stepper 44 mit Langdruck-Wiederholung, einstellbarer Semantik (`onIncrease`, `onDecrease`, `increasedValue`) und frei formatiertem Wert („250 g“, „1,5“) | S5, S7, S10, S13, S18, S20 |
| A-C6 | Zahlenfeld mit Komma und Punkt, Fehlerzeile darunter, Einheit dahinter, Dezimal-Ziffernblock | S7 bis S9, S13, S14, S16, S18 |
| A-C7 | `ProgressRing` (112 und 120, Strich 12, Spur-Token, Farbe als Parameter, ohne Semantik, `RepaintBoundary`) und Fortschrittsbalken 6 und 4 pt | S0, S1 |
| A-C8 | `BarChart` und `LineChart` mit Ziellinie, Achsen rechts, Säule antippen und langes Ziehen, Satz plus Elemente für VoiceOver, Achsen als Textzeile ab AX1 | S1, S15, S16, S17 |
| A-C9 | `RollingNumber` (`springDigits`, Reduce Motion: Überblenden) | S0, S1, S5, S7, S12, S14 |
| A-C10 | `UndoToast` mit 4 s und 10 s bei VoiceOver, Pause bei VoiceOver-Fokus, Ansage, Aktion „Widerrufen“ | überall |
| A-C11 | `StatusRow`, `EmptyState` mit Platz für `AvoFigure(pose:)` (ab AX1 ohne Figur), `SkeletonSection`, `SuccessMoment` (Figur ab AX3 weg), `ProBadge` | überall |
| A-C12 | `SearchField` (weiß 48, Radius 24) und Filter-Chip mit Einzel- und Mehrfachwahl | S3, S21 |
| A-C13 | `NutritionRow` (vier Spalten wie X-Essen, 2 × 2 bei 320 pt und ab xxxL), auch für das Rezeptdetail | S5, S7, S8, S10, S14 |
| A-C14 | Glas auf Kameras: Glas-Gruppe und Glas-Kapsel über dunklem Bild, dunkle Hinweis-Kapsel rgba(0,0,0,.6), Large Content Viewer ab AX1 | S4, S6 |
| A-T1 | Tokens für die Kalorienfarben (`calRing`, Protein, Fett, Wasser, Wasser-Fläche, Kicker, Health-Herz) samt erhöhtem Kontrast | S0, S1, S12, S15 |
| A-T2 | Getönte Kapsel auf hellem Grund mit 96 % statt 88 % (weiß auf Grün 4,99:1 statt 4,25:1) | alle Hauptaktionen |
| A-T3 | Dunkle Werte für alle Tokens dieses Bereichs, Kontrast geprüft | alle |
| A-T4 | `warningText` (#A8521A) und destruktiver Text #D70015 als Tokens, nie #FF3B30 für Text | S0, S1, S5, S13 |
| A-T5 | `numberXL` 34/41 Bold, mit Dynamic Type bis 51 pt | S1, S7, S14 bis S17 |
| A-R1 | `caloriesRootRoutes` vor der Shell einhängen (Präfix `/calories` überschneidet sich mit der Wurzel im Home-Branch) und Test „aus dem Rezepte-Tab öffnen, schließen, Rezepte-Tab sichtbar“ | S3 bis S10, S14, S18, S20, S22 |
| A-R2 | `caloriesSettingsRoutes` mit `'health'` und `'health/goals'` unter `/settings` einhängen; Profil-Zeile „Apple Health“ und Modul-Bereich verlinken hierher | S13, S23 |
| A-R3 | Rezeptdetail als Route, die über jedem Tab öffnen kann (für S21 und S3 „Heute im Plan“), oder Zusage, dass `/recipes/:id` aus dem Home-Tab in den Rezepte-Tab wechselt (dann ist das so gewollt) | S21 |
| A-H1 | Plätze auf Home für `CaloriesHomeCard`, `WaterTile` und `CalorieIdeasHint` nach dem A4-Vorschlag (Anfrage 5 aus `status-A.md`); Home zeigt höchstens eine Avo-Figur pro Bildschirmhöhe | S0 |
| A-P1 | Eingabe für Allergien in „Ernährung & Allergien“ (`users.allergies`; heute setzt sie nur Avo) | S5, S21 |
| A-P2 | Onboarding-Zielschritt nutzt `GoalForm` und `NutritionGoalCalculator` (stabile API) und fragt Health nicht ab, sondern zeigt nur die Zeile „Aus Apple Health übernehmen“ | S14 |
| A-P3 | `showModuleOffAlert(context, AppModule.calories, onEnable:)` mit dem Text aus S24 | S24 |
| A-L1 | Plural in `context.tr` (ICU `{n, plural, =1{…} other{…}}`); heute kann `AppTranslations.get` das nicht. Bis dahin legt B je Plural zwei Schlüssel `_one` und `_other` an | alle Texte mit `plural` |
| A-P4 | Paywall-Feature-IDs `cal_photo`, `cal_health`, `cal_history`, `cal_custom_challenge` in `pro_features`, falls der Owner sie zu Pro macht | S3, S5, S15, S17, S19, S22 |

---

## 7. Datenquellen und Lücken

### 7.1 Was es schon gibt (B, lesend für die Screens)

`nutritionGoalProvider`, `NutritionGoalService` und `NutritionGoalCalculator`, `FoodLogService`, `WaterLogService`,
`WeightLogService`, `DietChallengeService` und `diet_challenge_provider.dart`, `OpenFoodFactsService`,
`calorieRecipeSuggestionsProvider`, `whatCanIEatSuggestionsProvider`, `remainingCaloriesTodayProvider`,
`calorieTrackingEnabledProvider` (Alias auf `moduleEnabledProvider(AppModule.calories)`), `aiRemoteEnabledProvider`,
`ClaudeService` mit Fehlercodes (`quota_exceeded`, `no_food_detected`, `unreadable_image`, `refused`, `timeout`,
`ai_disabled`, `network_error`), `MealPhotoAnalysisService` und `MealPhotoStorageService` (werden gerade von einem
anderen Workflow auf Claude und den privaten Bucket umgebaut).

### 7.2 Was für die Screens fehlt

| Lücke | Für | Art |
|---|---|---|
| `dailyLogProvider(date)` als Familie mit lokalem Stand, Sync-Status je Zeile, ±7 Tage vorgewärmt; ersetzt fünf Provider und das Invalidieren von sieben | S0, S1, S12 | Provider, lokaler Speicher (JSON, ohne neues Paket) |
| Dauerhafte Schreib-Warteschlange (A-Baustein `WriteQueue`) für Einträge, Wasser, Gewicht, Workouts, Check-ins | alle | A/B |
| Services werfen bei Netzfehlern statt `null`/`[]` (`getGoal`, `getEntriesForDate`, `getHistory`, OFF-Suche); alle Aufrufer anpassen | S1, S3, S13 | Umbau |
| `FoodLogService.updateEntry`, Spalten `estimated`, `confidence`, `logged_time`, `health_uuid`, `updated_at`, Quellen `search` und `manual_estimated` | S5, S8, S9 | Migration, Owner wendet an |
| Tabelle `user_food` und `UserFoodService` | S3, S6, S7, S8 | Migration |
| Lokaler Produkt-Cache und „Zuletzt gegessen“ | S3, S6, S7 | lokal |
| Tabelle `workout_log`, `WorkoutLogService`, MET-Tabelle | S1, S17, S18 | Migration |
| `challenge_checkins`, Spalten `title`, `duration_days`, `question`, Unique-Index für `custom`, Auto-Abschluss per geplanter Edge Function | S19, S20 | Migration, Function-Deploy |
| `nutrition_goals`: `credit_workouts`, `pace`, Kennzeichen „eigene Werte“, `calculated_at` | S13, S14 | Migration |
| Einstellungen Wasserziel, Schnelltaste, Einheiten, Erinnerungen (`calorieSettingsProvider`, lokal und Konto) | S12, S23 | Spalten oder `user_preferences` |
| `HealthSyncService` mit Kanal `shoply/health` (Swift), Entitlements, Info.plist-Texte | S1, S13, S14, S16, S17, S22, S23 | nativ, Owner-Freigabe der Texte |
| `ScannerChannel` mit Kanal `shoply/scanner` (VisionKit, iOS 16+, Ziffern-Rückfall für 15.6) | S3, S6 | nativ |
| Berechtigungsstatus Kamera über nativen Kanal (`permission_handler` ohne Podfile-Makros meldet immer „abgelehnt“) | S4, S6 | nativ |
| `photoQuotaProvider`: verbleibende Foto-Schätzungen aus `ai_usage_daily_b` (RLS select own) und `app_flags.ai_limits` | S3, S5 | Provider |
| Tageslimit für `nutrition_estimate` (Text-Schätzung „Kalorien schätzen lassen“) ist nicht festgelegt | S8, S10 | Owner |
| Allergie-Abgleich mit `AllergyType`-Stichwörtern und Komposita, gemeinsam für Foto und Ideen | S5, S21 | Logik |
| Home-Schnappschuss Kalorien und Wasser für den ersten Frame | S0 | lokal |
| `planTodayProvider` (Heute im Plan) | S3, S10 | B7 |
| OFF-Felder `serving_size`, `serving_quantity`, `product_quantity`, `quantity`; Parser für Zahlen als Text; kein englischer Rückfall „Unknown product“ | S3, S7 | Umbau |
| Bucket `meal-photos` privat mit signierten URLs, fester `cacheKey` = Pfad, Löschfrist 90 Tage, `deleteAll` | S5, S9, S23 | Migration (Plan B1.7) |

### 7.3 Recht und Ehrlichkeit, vor dem Bau zu klären

- Der Satz „Das Foto wird nur für die Schätzung verwendet und privat gespeichert“ muss zur Verarbeitung bei Anthropic
  passen (Aufbewahrung der API). Prüfen, sonst Satz anpassen.
- „Was Avo aus Health liest, bleibt auf deinem iPhone“ gilt nur, wenn kein Health-Wert in Supabase, Avo-Kontext oder
  Widgets-Server landet. Avo bekommt Health-Workouts höchstens als lokalen Kontext mit Einwilligung.
- Gesundheitsdaten (Gewicht, Essen, Fotos, Alter, Größe, Geschlecht) sind wahrscheinlich besondere Kategorien nach
  Art. 9 DSGVO: Einwilligung und Datenschutzerklärung prüfen lassen (Owner).
- Open Food Facts verlangt die Quellenangaben aus S3 und S7.

---

## 8. Prüfliste für Screenshots

Für jeden Screen und Zustand: Prüfmatrix in `test/layout/screens/b/` (Breiten 320 × 568, 320 × 693, 375 × 667,
390 × 844, 402 × 874, 440 × 956; Textgrößen L, xxxL, AX3, AX5; fetter Text an und aus; hell und dunkel), Goldens der
Diagonale G1 bis G6, dazu je einmal 390 × 844 bei L mit erhöhtem Kontrast, Reduce Motion und Transparenz reduzieren.
Screenshots aus dem Simulator nach `docs/redesign/abnahme/kalorien/<screen>/`.

### 8.1 Für alle Screens

- [ ] Kein abgeschnittener Text, kein Überlauf, kein waagerechtes Scrollen (außer der Chip-Reihe auf S21).
- [ ] Jede Trefferfläche mindestens 44 × 44 pt, auch Chips, Stepper-Knöpfe, `plus.circle`, Wasser-Chip.
- [ ] Kein Spinner, kein Skelett beim zweiten Öffnen; erster Frame zeigt den lokalen Stand.
- [ ] Keine Bottom-Sheets, keine halbhohen Panels, keine Drawer, keine Schieberegler; jede Route öffnet als Push von
      rechts.
- [ ] Eintragen und Bearbeiten sind Vollbild-Screens ohne Tab-Leiste; Unterseiten zeigen die Tab-Leiste.
- [ ] Höchstens eine Avo-Figur pro Bildschirmhöhe, nur an den Stellen aus 3.12, ab AX1 (Erfolgsmoment ab AX3) weg.
- [ ] Genau eine getönte Kapsel bzw. ein getönter Primär-Kreis pro Screen; höchstens drei Glas-Flächen gleichzeitig.
- [ ] Kein Text in #FF3B30; destruktiv #D70015; weiße Schrift auf Grün mit 96 % Deckkraft.
- [ ] Ring und Kohlenhydrat-Balken in der freigegebenen Farbe (3:1 auf Weiß).
- [ ] Farbe nie allein: „kcal drüber“ mit Symbol, leere Tropfen als Kontur, Challenge-Tage mit unterschiedlicher Form.
- [ ] Zahlen tabellarisch, `intl`-Format der Gerätesprache, „ca.“ und „geschätzt“ bei jeder Schätzung, nie Prozent bei
      der Sicherheit.
- [ ] „Richtwerte, kein ärztlicher Rat.“ auf S13 und S14 sichtbar.
- [ ] Englisch genauso geprüft wie Deutsch (längere Wörter, andere Zahlformate).
- [ ] Offline: `StatusRow` sichtbar, Sync-Zeichen an neuen Zeilen, netzabhängige Knöpfe sagen „Braucht eine
      Verbindung“ bzw. sind ausgeblendet wie beschrieben.
- [ ] Modul aus: kein Kalorien-Pixel auf Home, Rezept und Profil; Deep Link zeigt S24.
- [ ] Reduce Motion: Zahlen blenden über, Tageswechsel blendet über, Pille steht still.
- [ ] Transparenz reduziert: Glas fest, Text lesbar.
- [ ] Dunkel: alle Flächen und Kalorienfarben mit Kontrast geprüft.
- [ ] VoiceOver: Fokus-Reihenfolge wie beschrieben, keine buchstabierten Großbuchstaben, „Kilokalorien“, Diagramme
      mit Satz.

### 8.2 Je Screen

- [ ] S0: Karte im D2-Maß (Radius 26, Kicker #A8521A, Ring 112, drei Makro-Zeilen, Kapsel 50, Fußzeile mit zwei
      Mini-Bildern); Mitte „640 kcal übrig“; Zustände leer, über Ziel, kein Ziel, Fehler; Kachel mit Plus und Tropfen;
      Modul aus = nichts.
- [ ] S1: Titel „Kalorien“, Datumszeile als Taste, „Heute“-Gruppe mit `numberXL` und Ring 120, vier Mahlzeiten mit
      „Eintragen“-Zeilen, Wasser, Woche mit Ziellinie, vier Nav-Zeilen; vergangener Tag, über Ziel, offline,
      nicht gespeichert, Health-Tipp; Tageswechsel per Wischen; bei L auf dem SE „Heute“ über dem Falz.
- [ ] S1a: Avo winkt (96), Satz, drei Knöpfe; Tagebuch ohne Ziel ohne Ring.
- [ ] S2: Menü mit sieben Tagen und kcal, Kalender an Ort und Stelle, Rad ab AX1.
- [ ] S3: Kopf mit `xmark` und Mahlzeit-Menü, Segmented Control 44, Suche mit „Zuletzt gegessen“ und Häkchen-Moment,
      Foto- und Barcode-Karten 300 pt Radius 26; keine Treffer mit Avo überlegt; Tageslimit Free und Pro; Kill-Switch
      ohne Foto-Segment; Pull-down ab xxL.
- [ ] S4: schwarze Kamera, zwei Glas-Gruppen, Hinweis auf dunkler Kapsel, Auslöser 72/60; Vorab-Dialog; abgelehnt.
- [ ] S5: Foto 300 Radius 26 mit Pille, Ergebniskarte im X-Essen-Look mit „ca.“ und Wortstufe, Bestandteile mit
      Gramm-Stepper, Allergie-Gruppe, Health-Zeile nur verbunden, Kapsel 54; alle Fehlerzustände; Verwerfen-Dialog.
- [ ] S6: Rahmen 280 × 160 (248 × 144 bei 320), erkannt mit Häkchen, nicht gefunden mit zwei Kapseln, Ziffern-Feld,
      Vorab-Dialog, Gerät ohne Scanner.
- [ ] S7: Produktkopf 64, große Mengen-Zahl mit Stepper, Einheiten-Chips, Nährwerte live, Quellenangabe; Nährwerte
      fehlen.
- [ ] S8: einspaltige Felder, „Kalorien schätzen lassen“ nur online, Fehlertext unter dem Feld.
- [ ] S9: großer Titel als Name, Quelle in der Fußnote, „Eintrag löschen“ in #D70015, Speichern beim Verlassen.
- [ ] S10: Portionen-Stepper 0,5 bis 20, Zukunfts-Fußnote, ohne Nährwerte.
- [ ] S12: Zeile und Kachel, Menü mit fünf Einträgen, Alert „Wasser hinzufügen“, Ziel erreicht ohne Feier.
- [ ] S13: Werte klappen an Ort und Stelle auf, Warnung unter 1.200, Makro-Abweichung, Schalter Workouts, Fußnote
      Richtwerte.
- [ ] S14: Ergebnis oben, Segmente „Gemütlich | Normal | Zügig“ statt Slider, alle Prüfungen, Kapsel „Übernehmen“.
- [ ] S15: Wochenkopf mit Pfeil-Gruppe, Diagramm mit Achse und Ziellinie, „Heute zählt ab morgen mit.“
- [ ] S16: Kopfzahl, Zeitraum-Segmente, Linie mit Lücken, Einträge mit Health-Quelle, leer ohne Figur.
- [ ] S17: Woche in Minuten, Tagesgruppen, leer mit und ohne Health, Health abgelehnt.
- [ ] S18: Art-Menü mit Symbolen, Dauer-Stepper, Intensität 44, kcal mit „ca.“ und Fußnote, Health nur lesen.
- [ ] S19: aktive Challenge mit Tagespunkten und „Heute geschafft?“, Starten, Abgeschlossen, Erfolgsmoment mit Avo
      feiert, Abbrechen-Dialog.
- [ ] S20: Name, Frage, Dauer oder „Ohne Ende“, Kapsel „Starten“.
- [ ] S21: Chips, Rezeptzeilen mit Listen-Bezug, Allergie-Fußnote ohne Versprechen, alle leeren Zustände.
- [ ] S22: Health-Symbol, zwei Gruppen „schreibt“/„liest“, Datenschutz-Satz, „Weiter“ und „Nicht jetzt“; Systemabfrage
      erst nach „Weiter“.
- [ ] S23: sechs Gruppen, Wasserziel per Stepper, Einheiten-Menüs, Erinnerungen mit Uhrzeit, Fotos-löschen-Dialog.
- [ ] S24: zentrierter Dialog mit „Einschalten“ fett, danach das ursprüngliche Ziel.
