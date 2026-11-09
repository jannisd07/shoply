# B5 Avo: Screen-Spezifikation (baufertig ab S2)

Stand 08.11.2026, Teil B. Nur Dokumentation, kein Code. Gilt für den Avo-Tab (Chat), alle Antwortkarten, die
Rückfrage-Karte Löschen, den leeren Chat, den Sprachmodus, „So arbeitet Avo“ und die Avo-Einstellungen.

**Quellen und Vorrang:** Jannis' Plan (`docs/superpowers/plans/2026-11-07-teil-b.md`) vor `design-quelle.md` vor
Konzept `konzept/16-avo.md`. Aussehen aus D2 (`D2-Komponenten`, `X-Avo`, `X-AvoSprache`), Inhalt, Zustände, Texte und
Barrierefreiheit aus dem Konzept. Owner-Regeln: keine Bottom-Sheets, Slide-ins, Drawer oder Schieberegler; Bearbeiten
im Vollbild; kurze Rückfragen als zentrierter Dialog; Avo nur als echte 3D-Figur aus `assets/avo/`, höchstens eine pro
Bildschirmhöhe; Trefferflächen ab 44 pt. Wo D2 und Konzept sich widersprechen, steht eine Empfehlung in Kapitel 13;
der Owner entscheidet.

Maße in pt (D2 zeigt px bei 390 pt Breite, 1 px = 1 pt). Farbangaben nennen D2-Werte nur zur Orientierung; gebaut
wird ausschließlich mit Tokens und Komponenten von Teil A (S2). Texte gehen später in
`lib/core/localization/translations/avo.dart` (Präfix `avo_`), die Schlüssel unten sind Vorschläge.

---

## Inhalt

1. Überblick: Screens, Routen, Dateien
2. B-Bausteine des Avo-Bereichs (auf A-Komponenten)
3. Screen 1: Avo-Tab (Chat)
4. Zustand im Tab: leerer Chat mit Schnellaktionen
5. Antwortkarten für alle Werkzeuge
6. Rückfrage-Karte Löschen
7. Foto an Avo und Schätzungen
8. Screen 2: Sprachmodus `/avo/voice`
9. Screen 3: „So arbeitet Avo“ `/avo/intro`
10. Screen 4: Avo-Einstellungen `/settings/avo` und Stimme `/settings/avo/voice`
11. Dialoge
12. Querschnitt: Barrierefreiheit, Kontrast, Bewegung, Haptik
13. Konflikte D2 gegen Konzept und weitere Owner-Fragen
14. Datenquellen und Lücken
15. Was Teil A liefern muss
16. Prüfliste für Screenshots

---

## 1. Überblick: Screens, Routen, Dateien

| Screen | Pfad | Navigationsart | Route-Datei (B) | Neue Screen-Datei (Vorschlag) |
|---|---|---|---|---|
| Avo-Tab (Chat, auch leerer Chat) | `/avo`, optional `?prompt=` | Tab-Wurzel „Avo“ (ab S2), bis S2 Vollbild | `buildAvoRoot` in `lib/routes/areas/avo_routes.dart` | `lib/presentation/screens/avo/avo_tab_screen.dart` |
| Sprachmodus | `/avo/voice` | Vollbild über der Tab-Leiste, Kind `'voice'` in `avoChildRoutes` mit `parentNavigatorKey: rootNavigatorKey` | `avoChildRoutes` | `.../avo/avo_voice_screen.dart` |
| So arbeitet Avo | `/avo/intro` | Vollbild über der Tab-Leiste, Kind `'intro'` | `avoChildRoutes` | `.../avo/avo_intro_screen.dart` |
| Avo-Einstellungen | `/settings/avo` | Push im Profil-Tab | `avoSettingsRoutes` (`'avo'`) | `.../avo/avo_settings_screen.dart` |
| Stimme wählen | `/settings/avo/voice` | Push im Profil-Tab, Kind von `'avo'` | `avoSettingsRoutes` | `.../avo/avo_voice_picker_screen.dart` |
| Paywall aus Pro-Zeile | `/pro?feature=<id>` | Vollbild (A) | A | A |
| Systemkamera, Fotoauswahl | keine eigene Route | Systemoberfläche | | |

Übergänge: Die zwei Vollbild-Routen `/avo/voice` und `/avo/intro` blenden über (Fade-through 250 ms, `AppMotion` von A)
statt von unten hereinzufahren. Beim Sprachmodus wächst zusätzlich die Figur aus dem Sprachmodus-Knopf in die Mitte
(Ursprung am Auslöser, Apple-Regel „räumliche Konsistenz“). Schließen läuft denselben Weg zurück. Push-Screens in den
Einstellungen nutzen den normalen iOS-Push von rechts mit Zurück-Wischen.

Deep Links: `shoply://avo` öffnet den Tab, `shoply://avo?prompt=<text>` **füllt nur das Eingabefeld vor und sendet nie
selbst** (eine fremde App oder Webseite könnte sonst Avo-Aktionen auslösen). Siri „Frag Avo“ geht über den App Intent
in die App und darf direkt senden, weil die Person gesprochen hat. `shoply://avo/voice` öffnet den Sprachmodus.
Die Übersetzung der Links baut A (S2), B liefert die Pfade.

Alte Dateien, die beim Bau gelöscht werden (gehören derzeit einem anderen laufenden Workflow, nicht anfassen, bis er
fertig ist): `lib/presentation/screens/ai/avo_chat_screen.dart`, `avo_chat_message.dart`,
`widgets/avo_chat_widgets.dart`, `widgets/avo_payload_cards.dart`; Übersetzungen `chip_*` (inkl.
`chip_cheapest_store`), `how_can_i_help`, `thinking_label`, `your_shopping_assistant`.

---

## 2. B-Bausteine des Avo-Bereichs

Diese Bausteine baut B im Ordner `lib/presentation/screens/avo/widgets/`, zusammengesetzt aus A-Komponenten (S2).
Werte aus `X-Avo`/`X-AvoSprache`, ergänzt um Barrierefreiheit.

### 2.1 Avo-Kopf (Tab)

- Navigationszeile 44 pt hoch direkt unter der Statusleiste (y 54 bei 390 × 844). Rechts eine Glas-Gruppe
  (Toolbar-Muster aus D2: Glas, Höhe 44, Radius 22, Innenabstand 0 4) mit zwei Knöpfen à 40 × 44:
  „Neues Gespräch“ (Sprechblase mit Plus, Symbol 20 pt, Strich wie D2) und „Mehr“ (`ellipsis`, Pull-down-Menü mit
  „Avo-Einstellungen“ / “Avo settings”, `avo_menu_settings`). Labels: „Neues Gespräch“ / “New conversation”
  (`avo_new_conversation`), „Mehr“ / “More” (`avo_more`). Toast danach: „Neues Gespräch begonnen“ / “New conversation
  started” (`avo_new_conversation_toast`).
  Siehe Konflikt K6; die D2-Variante hat nur den einzelnen Glas-Knopf 44 „Neuer Chat“.
- Großer Titel darunter (y 106): Avo-Figur 44 × 44 (Bild `contain`, sichtbar ca. 36 × 44, dekorativ) mit 10 pt
  Abstand zu „Avo“ in LargeTitle 34/41 Bold, linksbündig an 16 pt.
- Beim Scrollen klappt der große Titel wie bei iOS in die Navigationszeile ein (Headline 17/22 Semibold, mittig);
  die Figur scrollt mit dem großen Titel weg und erscheint nicht klein in der Zeile (eine Figur pro Bildschirmhöhe).
- Scroll-Kante oben: Verlauf 104 pt von Grundfarbe 30 % zu transparent (D2), kein Trennstrich.

### 2.2 Nutzer-Blase (`AvoUserBubble`)

- Rechtsbündig an 16 pt, höchstens 75 % der Inhaltsbreite (270 pt bei 390, 216 pt bei 320).
- Fläche Akzent (#1F7A3A), Text weiß Body 17/22, Innenabstand 10 oben/unten, 14 links/rechts, Radius 20/20/6/20
  (Ecke unten rechts klein).
- Mit Foto: Bild 4:3, Breite 200 pt (höchstens 75 %), Radius 20 (Karte), Text darunter in derselben Blase. Bild in
  Anzeigegröße dekodieren.
- Unterzeile unter der Blase (Footnote 13/18, sekundär, rechtsbündig), nur bei Bedarf: „Nicht gesendet“ mit
  Textknopf „Erneut senden“ oder „Wird nach dieser Antwort gesendet“.
- Ab AX3: volle Breite minus 48 pt links, bleibt als Blase erkennbar.

### 2.3 Avo-Text (`AvoMessage`)

- Links ohne Blase, volle Inhaltsbreite, Body 17/23 (D2), Text in Grundtextfarbe, markierbar.
- Erscheint Wort für Wort (Deckkraft 0 auf 1 in 120 ms je Wort, auch bei Reduce Motion, weil es nur Deckkraft ist).
- Formatierung: Absätze, einfache Aufzählung mit Punkt und 16 pt Einzug. Keine Überschriften, keine Tabellen, kein
  Fettdruck außer Listen- und Rezeptnamen (Headline-Gewicht). Zahlen nach Locale („3,20 €“, „1.840 kcal“).

### 2.4 Arbeits-Zeile (`AvoStatusLine`)

- Erscheint sofort nach dem Senden an der Stelle der Antwort und reserviert eine Zeilenhöhe von 44 pt.
- Links ein ruhiges Aktivitätszeichen: drei Punkte à 5 pt in Sekundärfarbe, Deckkraft-Welle 1,2 s (einzige
  Endlos-Animation, Kap. 20). Keine zweite Avo-Figur, der Kopf zeigt in der Zeit die Pose „überlegt“ (2.13).
- Text Subhead 15/20 Sekundärfarbe, was gerade passiert (Tabelle 3.4).
- Rechts schlichter Textknopf „Stopp“ (Body 17, Akzent, Trefferfläche 44 × 44).
- Verschwindet mit der ersten Ergebniskarte bzw. dem ersten Wort, ohne dass etwas springt.

### 2.5 Ergebniskarte (`AvoResultCard`, D2-Muster aus `X-Avo`)

Eine Antwort ergibt **eine** weiße Gruppe (Radius 26). Jede Änderung oder jedes Leseergebnis ist ein Abschnitt darin,
getrennt durch eine Trennlinie 0,5 pt über die volle Breite. Nie mehrere gleiche Karten untereinander.

Abschnitt, oben nach unten:

1. **Kopfzeile** (Innenabstand 12 oben, 16 seitlich, 2 unten; Abstand 10): links Objektbild 36 × 36, Radius 10
   (Listen-Cover, Rezeptfoto, sonst SF-Symbol 20 auf hellem Akzent #E7F3EA bzw. auf `fill`), daneben Titel
   = **das Objekt** (Subhead 15/20 Semibold, z. B. „Wocheneinkauf“) und Unterzeile = **was passiert ist**
   (Footnote 13/18 sekundär, Ziffern tabellarisch, z. B. „3 hinzugefügt · Lidl“).
2. **Detailzeilen** (optional): Mindesthöhe 56, Innenabstand 6/16, Abstand 12. Bei Artikeln wie die Listenzeile:
   Abhak-Kreis 22 pt in 44er-Trefferfläche, Artikelbild 36 × 36 Radius 9 bzw. Kategorie-Symbol auf hellem Akzent,
   Name Body 17/22, rechts Menge Subhead 15/20 sekundär. Trennlinie ab x = 88. Höchstens 8 Zeilen, dann Textknopf
   „Alle 12 ansehen“.
3. **Fußzeile** (Innenabstand 10/16/14, Abstand 18): bis zu zwei schlichte Textknöpfe Body 17/22 in Akzent, jeder
   mindestens 44 pt hoch: zuerst das Ziel („Liste öffnen“, „Ansehen“), dann „Widerrufen“.

Regel für „Widerrufen“: steht da, solange das Gespräch existiert (24 h) und die Daten unverändert sind.

Texte der Fußzeile: „Liste öffnen“ / “Open list” (`avo_open_list`), „Ansehen“ / “View” (`avo_view`), „Widerrufen“ /
“Undo” (`avo_undo`), „Alle {n} ansehen“ / “See all {n}” (`avo_see_all`), „Alle in {list} ansehen“ / “See all in
{list}” (`avo_see_all_in`).

Zustände eines Abschnitts:

| Zustand | Darstellung | DE | EN | Schlüssel |
|---|---|---|---|---|
| läuft | Kopfzeile mit Aktivitätszeichen statt Objektbild, Fußzeile fehlt, Höhe reserviert | Unterzeile aus Tabelle 3.4 | | |
| fertig | wie oben | (je Werkzeug, Kapitel 5) | | |
| widerrufen | Titel sekundär, Unterzeile ersetzt, nur noch „Ansehen“ | Rückgängig gemacht | Undone | `avo_row_undone` |
| nicht mehr widerrufbar | „Widerrufen“ entfällt, Unterzeile ergänzt | Inzwischen geändert | Changed since | `avo_row_changed_since` |
| Teilfehler | zusätzliche Zeile mit `exclamationmark.circle` in Text-Rot, Textknopf rechts | 2 Artikel nicht hinzugefügt · Erneut versuchen | 2 items not added · Try again | `avo_row_partial_items` (Plural) |
| ausstehend offline | Sync-Symbol `arrow.triangle.2.circlepath` 13 pt vor der Unterzeile | Wird gesendet, sobald du online bist | Will be sent when you're back online | `avo_row_pending_offline` |
| Leseergebnis älter als 10 min | Fußnote unter dem Abschnitt | Stand {Uhrzeit} | As of {time} | `avo_row_as_of` |

Barrierefreiheit: Ein Abschnitt ist ein VoiceOver-Element mit vollem Satz, z. B. „Wocheneinkauf: 3 Artikel
hinzugefügt, Lidl. Feta 200 g, Paprika rot 2, Passierte Tomaten 500 g.“ Eigene Aktionen: „Widerrufen“, „Liste
öffnen“, „Einzelheiten zeigen“. Abhak-Kreise sind eigene Elemente mit Rolle Schalter („Feta abhaken“, Wert „nicht
abgehakt“). Ab AX1: Objektbild und Artikelbilder aus, Detailzeilen stapeln (Menge unter den Namen), Fußknöpfe
untereinander, linksbündig.

### 2.6 Auswahlkarte (`AvoChoiceCard`, Rückfrage)

- Avo-Text als Frage darüber („Auf welche Liste?“), darunter eine weiße Gruppe Radius 26 mit Antwortzeilen
  (Mindesthöhe 56): für Listen Cover/Glyph 36, Name Body 17, Unterzeile Subhead 15 sekundär „9 offen · Lidl“, kein
  Chevron; für Märkte der `StoreChip`; für Personen `Avatar` 28 und Name; sonst Symbol 20 und Text.
- Letzte Zeile, wo sinnvoll: grünes `plus` und „Neue Liste …“ (öffnet A's Vollbild „Neue Liste“ mit vorbefülltem
  Namen) bzw. „Anderer Markt“.
- Alle Listen sind wählbar; ab 6 Listen die 5 zuletzt geänderten und „Alle Listen anzeigen“ (klappt auf).
- Nach der Wahl: gewählte Zeile mit `checkmark` in Akzent, die anderen in Sekundärfarbe und deaktiviert.
  Antwort per Text oder Stimme („die Lidl-Liste“) gilt genauso.
- Unbeantwortet und eine neue Frage kommt: Zeilen deaktiviert, Unterzeile „Nicht beantwortet“.
- VoiceOver: Gruppe „Auswahl, 4 Möglichkeiten“, jede Zeile eine Taste.

### 2.7 Pro-Zeile (`AvoProRow`)

- Eigener Abschnitt in der Ergebniskarte: Symbol der Funktion, Titel mit `ProBadge`, Unterzeile, Textknopf „Ansehen“.
- „Ansehen“ öffnet `/pro?feature=<id>` (A). Nach dem Kauf führt Avo die ursprüngliche Bitte aus und zeigt deren
  Ergebnis; Abbruch ändert nichts.
- Avo erwähnt Pro nur, wenn die Bitte eine Pro-Funktion braucht, keine Pro-Hinweise sonst, keine an Vorschlägen.

| Fall | DE | EN | Schlüssel |
|---|---|---|---|
| allgemein | {Funktion} · Mit {pro} verfügbar | {feature} · Available with {pro} | `avo_pro_available` |
| Tageslimit (nur Free, höchstens einmal pro Woche) | Mehr Fragen am Tag · Mit {pro} bis zu {limit} Fragen am Tag | More questions a day · Up to {limit} questions a day with {pro} | `avo_pro_more_questions_title`, `avo_pro_more_questions_sub` |
| Knopf | Ansehen | View | `avo_view` |

`{limit}` kommt aus `app_flags.ai_limits` (Pro, Avo), nie fest im Text.

### 2.8 Modul-Zeile (`AvoModuleOffRow`)

Fragt man nach einer Funktion eines ausgeschalteten Moduls: Abschnitt mit `switch.2`, Titel „{Modul} ist
ausgeschaltet“, Textknopf „Einschalten“ (schaltet per `appModulesProvider.notifier.setEnabled`, danach
Ergebnisabschnitt „{Modul} eingeschaltet“ mit „Widerrufen“, und Avo führt die Bitte aus).
DE „Kalorien & Gesundheit ist ausgeschaltet“, EN „Calories & Health is turned off“, Knopf „Einschalten“ / „Turn on“
(`avo_module_off`, `avo_turn_on`). Modulnamen kommen aus A's Modul-Labels. **Nie** für Angebote bei aktivem
Kill-Switch und nie für `mealPlan`, solange er nicht freigegeben ist (dann gibt es das Thema für Avo nicht).

### 2.9 Kontext-Kapsel (`AvoContextChip`)

- Linksbündig 8 pt über der Eingabe, nur solange das Gespräch zu diesem Kontext noch keine Frage hat oder der
  Kontext gewechselt hat.
- Kapsel `fill`, Mindesthöhe 32, Innenabstand 0 6 0 12: Symbol bzw. Listen-Glyph 15, Name Subhead 15/20, `xmark`
  13 pt mit eigener Trefferfläche 44 × 44.
- VoiceOver: „Avo bezieht sich auf Wocheneinkauf“, Taste „Wocheneinkauf nicht einbeziehen“.
- Ab AX1 bricht der Name um (bis 2 Zeilen).

| | DE | EN | Schlüssel |
|---|---|---|---|
| Ansage | Avo bezieht sich auf {name} | Avo is looking at {name} | `avo_context_label` |
| X | {name} nicht einbeziehen | Don't include {name} | `avo_context_remove` |

### 2.10 Folge-Vorschläge (Chips, D2)

- Unter der jüngsten Antwort höchstens 2 Chips, Innenabstand oben 14, Abstand 8, Zeilenabstand beim Umbruch 10.
- D2-Chip: sichtbar 34 hoch, Innenabstand 0 14, Radius Kapsel, Fläche `fill`, Text Subhead 15/20 Medium in
  Grundtextfarbe; **Trefferfläche 44** (je 5 pt oben und unten, deshalb Zeilenabstand mindestens 10).
- Tippen sendet sofort. Vorschläge älterer Antworten verschwinden, sobald eine neue Frage gesendet ist.
- Lokal berechnet aus dem letzten Ergebnis, nur für eingeschaltete Module, Angebots-Vorschläge nur bei
  `offersAvailableProvider`, Markt an der Liste und echter Region. Kein Marktvergleich, kein `ProBadge`.
- Beispiele: nach Zutaten auf Lidl-Liste „Was ist bei Lidl im Angebot?“ / „What's on offer at Lidl?“; mit Wochenplan
  „Plan für Freitag“ / „Plan for Friday“; nach Rezeptsuche „Zutaten auf {Liste}“ / „Ingredients to {list}“.
- VoiceOver: „Vorschlag: Was ist bei Lidl im Angebot?“, Hinweis „Sendet die Frage an Avo“ (`avo_suggestion_label`,
  `avo_suggestion_hint`; EN „Suggestion: {text}“, „Sends the question to Avo“).

### 2.11 Eingabe-Kapsel (`AvoComposer`)

- Glas (D2 `.glass`), Höhe 52 (wächst bis 5 Zeilen nach oben), Radius 26, links und rechts 16 pt Rand, 12 pt über
  der Oberkante der Tab-Leiste (D2: Unterkante 96 pt über dem Bildschirmrand). Mit Tastatur 8 pt über der Tastatur,
  die Tab-Leiste liegt dann darunter verborgen.
- Links Knopf „Foto hinzufügen“ (Kamera-Symbol), **Trefferfläche 44 × 44** (D2 zeigt 32 breit; Innenabstand links
  deshalb 4 statt 14), öffnet ein Pull-down-Menü: „Foto aufnehmen“, „Foto auswählen“.
- Textfeld Body 17/22, Platzhalter „Frag Avo …“ in Sekundärfarbe, verstecktes Label „Avo fragen“, Return-Taste
  „Senden“. Externe Tastatur: Enter sendet, Umschalt+Enter macht eine neue Zeile.
- Rechts getönter Glas-Kreis 40 pt in 44er-Fläche, wechselt nach Inhalt:
  leer = „Sprachmodus starten“ (Wellenform), mit Text = „Senden“ (Pfeil nach oben), während Avo antwortet und das
  Feld leer ist = „Antwort anhalten“ (Quadrat).
- Ab 3.800 Zeichen Fußnote über der Kapsel „Noch {n} Zeichen“; bei 4.000 nimmt das Feld nichts mehr an.
- Hinter Kapsel und Tab-Leiste liegt eine Scroll-Kante unten (Verlauf 40 pt aus der Grundfarbe), damit dunkler
  Inhalt nie direkt unter dem Platzhalter steht (Kontrast, siehe 12.1).
- 320 pt: Kapsel 288 breit, Textfeld etwa 178 pt.

| Element | DE | EN | Schlüssel |
|---|---|---|---|
| Platzhalter | Frag Avo … | Ask Avo… | `avo_input_placeholder` |
| Feld-Label | Avo fragen | Ask Avo | `avo_input_label` |
| Foto-Knopf | Foto hinzufügen | Add photo | `avo_photo_add` |
| Menü | Foto aufnehmen · Foto auswählen | Take photo · Choose photo | `avo_photo_take`, `avo_photo_choose` |
| Sprachmodus | Sprachmodus starten | Start voice mode | `avo_voice_start` |
| Senden | Senden | Send | `avo_send` |
| Anhalten | Antwort anhalten | Stop answer | `common_stop_answer` (A, Standard von `AvoComposerField`) |
| Zeichen | Noch {n} Zeichen | {n} characters left | `common_chars_left` (A, Zähler von `AvoComposerField`) |

### 2.12 Statuszeile (`StatusRow` von A)

Unter dem Kopf, über dem Verlauf, wird einmal höflich angesagt. Texte in Kapitel 3.3.

### 2.13 Avo-Figur

- Assets `assets/avo/avo_waving.png`, `avo_thinking.png`, `avo_excited.png`, `avo_celebrating.png` (je ca.
  450 × 550, nicht quadratisch, immer `contain`, mit `cacheWidth` in Anzeigegröße × Gerätefaktor dekodieren).
- **Eine Figur pro Bildschirmhöhe.** Im Tab ist das die Kopf-Figur; Karten, Statuszeile, Rückfrage-Karte und leerer
  Chat bekommen keine eigene.
- Pose nach Anlass, Wechsel als Überblendung 200 ms:

| Anlass | Pose |
|---|---|
| leerer Chat, Begrüßung, Ruhe | `avo_waving` |
| Avo arbeitet (Arbeits-Zeile sichtbar) | `avo_thinking` |
| Erfolg ohne Geld- oder Gesundheitsbezug („Einkauf gespeichert“, „Wochenplan auf der Liste“), 3 s, dann zurück | `avo_celebrating` |
| Allergie, Geld, Fehler, Löschen, Tageslimit, Kill-Switch | `avo_waving` ohne Wechsel (keine Freude, kein Feiern) |

- Ab AX1 entfällt die Figur ganz (Fundament-Regel), der Titel „Avo“ bleibt.
- Semantik: im Tab dekorativ (ausgeblendet); im Sprachmodus beschreibt sie den Zustand (Kapitel 8).

---

## 3. Screen 1: Avo-Tab (Chat)

**Zweck:** Was soll Avo für mich tun? Fragen per Text, Foto oder Stimme; Avo handelt mit den Rechten der Person, zeigt
das Ergebnis und lässt es widerrufen.

**Route:** `/avo` als Wurzel des Tabs `AppBranch.avo` (`buildAvoRoot`). Bis S2 Vollbild-Route wie heute.
`?prompt=` füllt das Feld vor, ohne zu senden.

### 3.1 Aufbau oben nach unten (390 × 844, D2 `X-Avo`)

1. Statusleiste.
2. Kopf (2.1): Glas-Gruppe rechts (y 54), großer Titel mit Figur (y 106). Scroll-Kante oben 104 pt.
3. Statuszeile (2.12), nur bei Bedarf.
4. Verlauf, scrollt unter Kopf, Eingabe und Tab-Leiste durch. Seitenrand 16, Beginn 18 pt unter dem Titel, 24 pt
   zwischen zwei Runden. Abstände innerhalb einer Runde: 14 pt von der Blase zum ersten Block, 10 pt zwischen
   Karte und Avo-Text, 14 pt zu den Chips. Inhaltsabstand unten 164 pt (Eingabe 52 + 12 + Tab-Leiste 64 + 20 + Luft
   16), damit nichts dauerhaft verdeckt ist.
   Eine Antwort baut sich in dieser Reihenfolge auf: Arbeits-Zeile, dann die Ergebniskarte, sobald das Werkzeug fertig
   ist, dann der Avo-Text (Konflikt K2: D2 setzt den Text vor die Karte).
5. Kontext-Kapsel (2.9).
6. Eingabe-Kapsel (2.11).
7. Tab-Leiste (A, D2 v2): Glas-Kapsel 64 hoch, 12 pt Rand, Avo aktiv mit grünem Lichtschein.

### 3.2 Verhalten

- **Öffnen:** Gespräch der letzten 24 Stunden sofort aus dem lokalen Speicher, Position an der letzten Runde, kein
  Indikator. Kehrt man zurück, bleibt die Scroll-Position.
- **Neue Runde:** Die Blase scrollt an den oberen Rand unter den eingeklappten Kopf (Feder `AppMotion.standard`,
  Dämpfung 1,0). Wächst die Antwort darüber hinaus, scrollt nichts automatisch weiter.
- **Stopp:** bricht ab; ausgeführte Änderungen bleiben mit „Widerrufen“, darunter Footnote „Angehalten.“
- **Senden während einer Antwort:** erlaubt; die Frage steht als Blase mit „Wird nach dieser Antwort gesendet“ und
  geht danach raus.
- **Tab verlassen während einer Antwort:** Die Antwort läuft weiter. Jede ausgeführte Änderung erscheint zusätzlich
  als `UndoToast` (A) auf dem aktuellen Screen, ohne Avo-Namen, z. B. „3 Artikel zu Wocheneinkauf hinzugefügt ·
  Widerrufen“. Der Avo-Tab zeigt, dass Avo arbeitet, und danach einen Punkt „neue Antwort“ (Vertrag mit A, Kap. 15).
- **„Liste öffnen“ / „Ansehen“:** wechselt per A-Helfer in den passenden Tab und baut den Stapel auf; das Gespräch
  bleibt.
- **Neues Gespräch:** leert sofort, `UndoToast` „Neues Gespräch begonnen · Widerrufen“.
- **Kontowechsel, Abmelden:** Gespräch, Kontext und Rückgängig-Speicher werden verworfen, kein Toast.
- **App wird während einer Antwort beendet:** Beim nächsten Öffnen steht die Runde mit „Angehalten.“, ausgeführte
  Änderungen behalten „Widerrufen“.
- **Doppelt getippt:** ein Tipp, eine Frage (Senden ignoriert weitere Tipps, bis die Blase im Verlauf steht).

### 3.3 Zustände

| Zustand | Darstellung | DE | EN | Schlüssel |
|---|---|---|---|---|
| leer | Kapitel 4 | | | |
| lädt | lokaler Stand sofort, kein Indikator, kein Skelett (nichts aus dem Netz nötig) | | | |
| arbeitet | Arbeits-Zeile (2.4), Kopf-Figur `avo_thinking`; Ziel: erstes Ergebnis oder Wort unter 1,5 s | Tabelle 3.4 | | |
| Fehler allgemein | Abschnitt mit `exclamationmark.circle` in Text-Rot, Titel, Unterzeile, Textknopf; Fehler-Haptik | Das hat nicht geklappt. · Avo ist gerade nicht erreichbar. · Erneut versuchen | That didn't work. · Avo can't be reached right now. · Try again | `avo_err_title`, `avo_err_unreachable`, `avo_retry` |
| Zeitüberschreitung (8 s ohne erstes Wort, 60 s gesamt) | wie Fehler | Avo antwortet gerade nicht. · Erneut versuchen | Avo isn't responding right now. · Try again | `avo_err_timeout` |
| ausgelastet (`rate_limited`) | wie Fehler, „Erneut versuchen“ erst nach `retry_after_s` aktiv | Avo ist gerade ausgelastet. Versuch es gleich noch einmal. | Avo is busy right now. Try again in a moment. | `avo_err_busy` |
| abgelehnt (`refused`) | nur Avo-Text, kein Fehler-Symbol, keine Haptik | Dabei kann ich dir nicht helfen. | I can't help with that. | `avo_err_refused` |
| Anmeldung abgelaufen (`unauthorized`) | Fehler-Abschnitt mit Knopf zur Anmeldung (A) | Deine Anmeldung ist abgelaufen. Melde dich neu an, dann geht es weiter. · Neu anmelden | Your sign-in has expired. Sign in again to continue. · Sign in again | `avo_err_session`, `avo_sign_in_again` |
| offline | `StatusRow` unter dem Kopf; gesendete Frage bleibt als Blase mit „Nicht gesendet · Erneut senden“; nichts wird später automatisch gesendet; Vorschläge und Chips deaktiviert | Offline. Avo braucht eine Verbindung. | You're offline. Avo needs a connection. | `avo_offline`, `avo_not_sent`, `avo_resend` |
| Verbindung schlecht | `StatusRow` | Verbindung schlecht. Avo antwortet vielleicht langsamer. | Weak connection. Avo may answer more slowly. | `avo_slow_connection` |
| Tageslimit (`quota_exceeded`) | neutraler Abschnitt ohne Fehler-Symbol, Eingabe bleibt aktiv (Widerrufen, Lesen gehen weiter), Free: darunter Pro-Zeile höchstens einmal pro Woche | Für heute ist Schluss mit Fragen. Ab morgen geht es weiter. | That's all the questions for today. You can ask again tomorrow. | `avo_limit_reached` |
| Kill-Switch KI (`aiRemoteEnabledProvider` false bzw. `ai_disabled`) | `StatusRow`, Feld und Sprachmodus-Knopf deaktiviert mit Grund, Verlauf lesbar, Widerrufen geht weiter (lokal) | Avo ist gerade nicht verfügbar. Deine Listen und Rezepte funktionieren wie immer. | Avo isn't available right now. Your lists and recipes work as usual. | `avo_unavailable` |
| Kill-Switch Angebote | keine Angebots-Karten, -Vorschläge oder -Chips, kein Hinweis darauf; Avo sagt auf Nachfrage „Dazu kann ich gerade nichts sagen.“ (Werkzeug-Variante `no_offers`, Text vom Server) | Dazu kann ich gerade nichts sagen. | I can't say anything about that right now. | serverseitig |
| Modul Avo aus | Tab gibt es nicht (Empfehlung K5); Direktaufruf zeigt Dialog 11.1 | | | |
| Pro gesperrt | pro Werkzeug als Pro-Zeile (2.7), der Tab bleibt nutzbar | | | |
| nicht angemeldet | nicht erreichbar; Siri/Widget führen zur Anmeldung (A) und danach in den Tab | | | |
| Berechtigung Kamera fehlt | siehe 7.4 | | | |

Optional (Owner-Frage F3): Free-Nutzer sehen bei nur noch einer Frage eine Fußnote über der Eingabe
„Heute noch 1 Frage“ / „1 question left today“ (`avo_questions_left`, Plural).

### 3.4 Texte der Arbeits-Zeile

| Schritt | DE | EN | Schlüssel |
|---|---|---|---|
| vor dem ersten Werkzeug | Denkt nach | Thinking | `avo_status_thinking` |
| Liste lesen | Liest {list} | Reading {list} | `avo_status_reading_list` |
| auf Liste schreiben | Schreibt auf {list} | Adding to {list} | `avo_status_writing_list` |
| Rezepte suchen | Sucht Rezepte | Finding recipes | `avo_status_recipes` |
| Angebote (nur wenn verfügbar) | Sieht bei {store} nach | Checking {store} | `avo_status_offers` |
| Foto | Liest das Foto | Reading the photo | `avo_status_photo` |
| Essen schätzen | Schätzt das Essen | Estimating the meal | `avo_status_estimate` |
| Wochenplan | Plant die Woche | Planning the week | `avo_status_plan` |
| Einstellung | Ändert die Einstellung | Changing the setting | `avo_status_setting` |
| Verlauf | Sieht im Verlauf nach | Checking your history | `avo_status_history` |
| angehalten | Angehalten. | Stopped. | `avo_stopped` |
| wartet | Wird nach dieser Antwort gesendet | Sends after this answer | `avo_queued` |

### 3.5 Interaktionen

- Langdruck auf Avo-Text: Kontextmenü „Kopieren“, „Vorlesen“ (`speaker.wave.2`). Langdruck auf eine Nutzer-Blase:
  „Kopieren“, „Bearbeiten und neu senden“ (Text geht in die Eingabe). DE/EN: Kopieren/Copy, Vorlesen/Read aloud,
  Bearbeiten und neu senden/Edit and resend (`avo_copy`, `avo_read_aloud`, `avo_edit_resend`).
- Tippen auf einen Kartenabschnitt: klappt Einzelheiten auf (bis 20 Zeilen, Feder, dann „Alle in {Liste} ansehen“)
  oder öffnet das Ziel, wenn es keine gibt.
- Abhak-Kreis in einer Avo-Listenkarte: hakt den echten Artikel ab, leichter Impuls.
- Scrollen schließt die Tastatur interaktiv (wie Nachrichten). Keine Wischgesten auf Karten, kein Ziehen zum
  Aktualisieren.
- Gedrückt: Knöpfe und Chips 0,97 Skalierung und 90 % Deckkraft beim Berühren (sofort, nicht erst beim Loslassen).

### 3.6 Barrierefreiheit

- Fokus-Reihenfolge: Titel „Avo“ (Überschrift) → „Neues Gespräch“ → „Mehr“ → Statuszeile → Verlauf älteste zuerst →
  Chips → Kontext-Kapsel → Foto → Feld → Sprachmodus/Senden → Tab-Leiste.
- Jede Nutzer-Frage ist eine Überschrift, damit der Rotor „Überschriften“ Runde für Runde springt. Avo-Antworten mit
  vorangestelltem „Avo:“.
- Ansagen: höflich und erst nach einem vollständigen Satz, nicht Wort für Wort; nicht, solange die Person tippt.
  Ergebnis: „Avo: 9 Zutaten zu Wocheneinkauf hinzugefügt. Widerrufen verfügbar.“
  (`avo_a11y_prefix` „Avo:“ / „Avo:“, `avo_a11y_undo_available` „Widerrufen verfügbar.“ / „Undo available.“)
- Trefferflächen: alle Glas-Knöpfe 44, Foto-Knopf 44 statt 32, Chips 44 statt 34, Abhak-Kreis 44, Fußknöpfe 44 hoch,
  `xmark` der Kontext-Kapsel 44.
- Large Content Viewer ab AX1 für Tab-Leiste, Glas-Gruppe und die Knöpfe der Eingabe-Kapsel.
- Dynamic Type: ab AX1 Figur aus, Bilder aus, Kartenzeilen stapeln, Fußknöpfe untereinander, Chips volle Breite;
  großer Titel klappt früher ein; ab AX3 Nutzer-Blase volle Breite minus 48. Eingabe wächst bis 5 Zeilen, dann
  scrollt das Feld.
- 320 pt: Kopf passt (Glas-Gruppe 88 + Titel), Blase 216 pt, Eingabe 288 mit Feld etwa 178 pt, alles bricht um,
  nichts wird abgeschnitten.
- Reduce Motion: Einwachsen der Karten wird Überblendung 200 ms, Wort-für-Wort bleibt (Deckkraft), Posenwechsel
  Überblendung, Aktivitätszeichen ohne Welle (drei feste Punkte).
- Reduce Transparency: Glas der Eingabe und der Glas-Gruppe wird feste Fläche (Token von A), getöntes Glas wird
  voller Akzent.

### 3.7 Daten

Siehe Kapitel 14. Kurz: `AvoAssistantService` (Werkzeug-Schleife, B1.6) über `ClaudeService.streamAvo`, lokaler
Gesprächsspeicher, `aiRemoteEnabledProvider`, `moduleEnabledProvider(AppModule.*)`, `offersAvailableProvider`,
Screen-Kontext von A, Verbindungsstatus.

---

## 4. Zustand im Tab: leerer Chat mit Schnellaktionen

**Zweck:** Womit fange ich an? Drei Sätze, die zum Screen passen, von dem man kommt; Tippen sendet sofort.

**Wann:** erstes Öffnen, nach „Neues Gespräch“, nach 24 Stunden ohne Gespräch, bei `/avo` ohne Frage.

### 4.1 Aufbau oben nach unten

1. Kopf wie 3.1 (Figur `avo_waving` im großen Titel ist die einzige Figur; keine zweite im leeren Zustand).
2. 18 pt Abstand, dann „Wie kann ich helfen?“ in Title3 20/25 Semibold.
3. 8 pt, dann weiße Gruppe Radius 26 mit drei Zeilen: Mindesthöhe 52, Innenabstand 14/16, Symbol 17 pt in
   Sekundärfarbe, Text Body 17/22 (bricht um), keine Chevrons.
4. Fußnote 13/18 Sekundärfarbe unter der Gruppe, 8 pt Abstand, mit Textknopf „Datenschutz“ in Akzent
   (öffnet A's Datenschutz-Seite).
5. Kontext-Kapsel und Eingabe wie 3.1.

| Element | DE | EN | Schlüssel |
|---|---|---|---|
| Titel | Wie kann ich helfen? | How can I help? | `avo_empty_title` |
| Fuß | Avo nutzt deine Listen, Rezepte und Einstellungen, um zu antworten. | Avo uses your lists, recipes and settings to answer. | `avo_empty_footer` |
| Link | Datenschutz | Privacy | `avo_privacy` |

### 4.2 Vorschläge nach Kontext

Modul-Vorschläge nur bei Modul an; Angebots-Vorschläge nur bei `offersAvailableProvider`, Markt an der Liste und echter
Region; Wochenplan-Vorschläge nur, wenn `mealPlan` freigegeben und an ist. Fällt eine Zeile weg, rückt der nächste
Kern-Vorschlag nach (Reserve: „Was steht auf meiner Liste?“ / „What's on my list?“, `avo_sugg_whats_on_list`).

| Kontext (vom Screen, von dem man kommt) | Kapsel | Vorschläge DE (Symbol) | EN |
|---|---|---|---|
| Liste mit offenen Artikeln | Glyph + Listenname | Zutaten für {Rezept von heute} hinzufügen (`plus`, nur mit Plan für heute) · Was ist davon bei {Markt} im Angebot? (`tag`) · Was kaufe ich sonst noch regelmäßig? (`clock.arrow.circlepath`) | Add ingredients for {recipe} · What's on offer at {store} from this? · What else do I buy regularly? |
| Liste leer | Glyph + Name | Setz meinen letzten Einkauf wieder drauf · Was koche ich diese Woche? (`fork.knife`) · Einkaufszettel abfotografieren (`camera`) | Add my last shop again · What should I cook this week? · Take a photo of a shopping list |
| Einkaufsmodus | Glyph + Name | Was fehlt noch? (`checklist`) · Hak Milch und Butter ab (`checkmark`, Namen aus den offenen Artikeln) · Setz Backpapier dazu (`plus`) | What's still missing? · Check off milk and butter · Add baking paper |
| Listen-Übersicht, Verlauf | keine | Was habe ich letzten Samstag gekauft? · Leg eine Liste für die Party an (`plus`) · Wie viel habe ich im November gespart? (`tag`, nur Angebote verfügbar und echte Region) | What did I buy last Saturday? · Make a list for the party · How much did I save in November? |
| Home | keine | wie Liste von heute | |
| Rezepte | keine | Was koche ich heute? · Vegetarisch unter 20 Minuten (`leaf`) · Zeig meine gemerkten Rezepte (`bookmark`) | What should I cook today? · Vegetarian in under 20 minutes · Show my saved recipes |
| Rezeptdetail | `fork.knife` + Rezeptname | Zutaten für {n} Personen auf {Liste} · Womit ersetze ich {Zutat}? (`arrow.left.arrow.right`) · Am Mittwoch in den Wochenplan (`calendar`, nur Plan) | Ingredients for {n} people to {list} · What can I use instead of {ingredient}? · Add to the meal plan on Wednesday |
| Kochmodus | `frying.pan` + „Schritt 3 von 7“ | Nächster Schritt · Timer auf 10 Minuten (`timer`) · Womit ersetze ich Sahne? | Next step · Set a timer for 10 minutes · What can I use instead of cream? |
| Wochenplan | `calendar` + „9. bis 15. Nov.“ | Füll die freien Tage vegetarisch · Alle Zutaten der Woche auf {Liste} · Was gibt's heute? | Fill the free days with vegetarian meals · Add all of this week's ingredients to {list} · What's for dinner today? |
| Kalorien | `flame` + „Heute“ | Trag mein Mittagessen per Foto ein (`camera`) · Was kann ich mit {n} kcal noch essen? · 250 ml Wasser eintragen (`drop`) | Log my lunch from a photo · What can I still eat with {n} kcal? · Log 250 ml of water |
| Profil, Einstellungen | Symbol + Seitentitel | Schalte den Dunkelmodus ein (`circle.lefthalf.filled`) · Trag eine Erdnussallergie ein (`leaf`) · Welche Module gibt es? (`switch.2`) | Turn on dark mode · Add a peanut allergy · Which modules are there? |
| Siri, Widget, Deep Link | keine | wie Liste von heute | |

Kontext-Kapsel entfernen heißt: Avo bezieht sich nicht mehr auf diesen Screen, die Vorschläge wechseln auf die Zeile
„Siri, Widget, Deep Link“.

### 4.3 Zustände

| Zustand | Darstellung |
|---|---|
| erster Start | wie oben; der erste Tipp auf einen Vorschlag (oder das erste Senden) öffnet zuerst `/avo/intro` (Kapitel 9) |
| lädt | nichts zu laden, Vorschläge aus lokalem Stand |
| offline | `StatusRow` „Offline. Avo braucht eine Verbindung.“; Vorschläge sichtbar, deaktiviert, VoiceOver-Zusatz „braucht eine Verbindung“ / „needs a connection“ (`avo_needs_connection`) |
| Fehler | entfällt (kein Netzaufruf) |
| Kill-Switch KI | `StatusRow` 3.3, Vorschläge deaktiviert |
| Pro gesperrt | Vorschläge zu Pro-Funktionen bleiben, ihr Ergebnis ist die Pro-Zeile; kein `ProBadge` am Vorschlag |

### 4.4 Interaktion und Barrierefreiheit

- Tippen: Die Zeile wird zur Nutzer-Blase (Text wandert nach rechts oben, Feder; Reduce Motion: Überblendung), Titel
  und Gruppe blenden aus. Keine Haptik.
- Vorschläge sind Tasten: „Vorschlag: Was koche ich heute?“, Hinweis „Sendet die Frage an Avo“.
- Ab AX1: Figur aus, Titel und Vorschläge bleiben und brechen um. 320 pt: nur Umbruch.

---

## 5. Antwortkarten für alle Werkzeuge

Alle Karten folgen 2.5 (Kopfzeile = Objekt, Unterzeile = was passiert ist), Leseergebnisse nutzen die Bausteine, die
der Inhalt in der App hat. Rechts in der Tabelle steht, was die Fußzeile trägt (W = „Widerrufen“, A = „Ansehen“ bzw.
Ziel-Knopf). EN-Texte stehen unter den DE-Texten. Werkzeuge mit „neu“ fehlen heute (Plan B5: Tool-Lücken schließen).
Löschwerkzeuge gibt es für das Modell nicht; es hat nur `propose_delete` (Kapitel 6).

Ehrlichkeitsregeln für alle Karten: Preise „laut Händler“, „in deiner Region“; Ersparnis nur mit echter Region, unter
0,50 € entfällt sie, sonst auf 10 ct gerundet mit „ca.“; kein Marktvergleich, keine Korbsumme, keine %-Rabatte;
Schätzungen „geschätzt“; Gesundheitswerte mit „Richtwerte, kein ärztlicher Rat“ wo ein Ziel oder eine Empfehlung
steht. Das Kalorien-Feld „kcal“ in Rezeptzeilen nur mit Modul Kalorien.

### 5.1 Listen und Artikel

| Werkzeug | Karte (Bausteine) | Kopf / Unterzeile DE | EN | Fuß |
|---|---|---|---|---|
| `get_lists` | Abschnitt „Deine Listen“, Zeilen wie Listenzeile (Cover 36, Name, Unterzeile), Tippen öffnet | Deine Listen · Wocheneinkauf / 9 offen · Lidl | Your lists · Weekly shop / 9 open · Lidl | |
| `get_list_contents` | Kopf + Artikelzeilen (D2), Kreis hakt ab | Wocheneinkauf / 9 offen · Lidl; leer: Wocheneinkauf ist leer. | Weekly shop / 9 open · Lidl; empty: Weekly shop is empty. | Liste öffnen, „Alle 9 ansehen“ ab 9 |
| `add_item_to_list` | Kopf + Zeile „Milch · 2“; mit Angebot rechts D2-Pille „0,99 € · Lidl“ (`ItemOfferBadge`) | Wocheneinkauf / 1 hinzugefügt · Lidl | Weekly shop / 1 added · Lidl | Liste öffnen, W |
| `ask_pick_list` | Auswahlkarte 2.6 | Auf welche Liste? | Which list? | |
| `check_items` | Kopf + Zeilen abgehakt | Wocheneinkauf / 2 abgehakt | Weekly shop / 2 checked off | W |
| `update_item` | Kopf + Zeile | Wocheneinkauf / Milch: Menge 3, vorher 2 | Weekly shop / Milk: quantity 3, was 2 | W |
| `move_items` | Kopf Zielliste + Zeilen | Drogerie / 2 verschoben aus Wocheneinkauf | Drugstore / 2 moved from Weekly shop | Liste öffnen, W |
| `create_list` | Kopf neue Liste | Party / Neue Liste · REWE | Party / New list · REWE | Liste öffnen, W (nur solange leer) |
| `rename_list` | Kopf | Grillabend / Umbenannt, vorher Party | BBQ night / Renamed, was Party | W |
| `complete_list` (gleicher Abschluss wie die App, atomar, mit Verlauf) | Kopf; Erfolgs-Haptik, Figur feiert 3 s nur ohne Ersparnis-Zeile | Wocheneinkauf / Einkauf gespeichert · 11 Artikel · Lidl; mit Angebote verfügbar und Ersparnis: · ca. 3,20 € gespart, laut Händler | Weekly shop / Shopping trip saved · 11 items · Lidl; · about €3.20 saved, according to the retailer | Ansehen (Verlauf), W |
| Markt unklar beim Abschluss | Auswahlkarte mit `StoreChip`s | Wo warst du einkaufen? · Anderer Markt · Kein bestimmter Markt | Where did you shop? · Other store · No particular store | |
| neu `start_shopping` | Navigation; im Verlauf bleibt Kopf `cart` | Wocheneinkauf / Einkaufsmodus geöffnet | Weekly shop / Shopping mode opened | Ansehen |
| neu `import_list_photo` | Kapitel 7 | | | |
| neu `share_list` | Kopf; „Teilen …“ öffnet das System-Teilen, Avo verschickt nie selbst | Party / Einladungslink ist bereit | Party / Invite link is ready | Teilen … |
| neu `join_list` (Code, Link) | Kopf | Party / Beigetreten · mit Lena | Party / Joined · with Lena | Liste öffnen |
| neu `leave_list`, `remove_member` | Rückfrage-Karte 6 | | | |
| neu `set_store` | Kopf | Wocheneinkauf / Markt: Lidl | Weekly shop / Store: Lidl | W |
| neu `set_offers_hidden_for_list` (nur Angebote verfügbar) | Kopf | Wocheneinkauf / Angebote ausgeblendet | Weekly shop / Offers hidden | W |
| neu `set_category_order` | Kopf | Wocheneinkauf / Reihenfolge im Markt geändert | Weekly shop / Store order changed | W |
| neu `get_list_activity` | nur Avo-Text („Lena hat vorhin Butter dazugeschrieben.“), keine Karte | | | |
| Navigation („Öffne …“) | Kopf mit Symbol des Ziels, führt sofort aus | Wocheneinkauf / Geöffnet | Weekly shop / Opened | Ansehen |

Mehrere Listen im Kontext und keine genannt: Auswahlkarte. Standard-Ziel sonst: Kontext-Liste, dann Liste von heute.

### 5.2 Verlauf, Nachkauf, Kosten teilen

| Werkzeug | Karte | DE | EN | Fuß |
|---|---|---|---|---|
| `get_shopping_history` | Abschnitt, Zeilen: `StoreChip` „Lidl“, Unterzeile, rechts Betrag nur wenn erfasst; Tippen klappt Artikel auf | Einkäufe · Lidl / Sa., 31. Okt. · 14 Artikel · 42,80 €; leer: Noch keine Einkäufe gespeichert. | Shopping trips · Lidl / Sat, 31 Oct · 14 items · €42.80; empty: No shopping trips saved yet. | Alle wieder auf {Liste} |
| `add_history_items_to_list` | Kopf | Wocheneinkauf / 12 hinzugefügt · 2 standen schon drauf | Weekly shop / 12 added · 2 already on it | Liste öffnen, W |
| `get_restock_suggestions` | Abschnitt, Zeilen mit gestricheltem Kreis und `plus`; Tippen setzt auf die Liste und wird zur Ergebniszeile | Vielleicht auch · Milch / kaufst du etwa alle 6 Tage | Maybe also · Milk / you buy it about every 6 days | |
| `split_trip_cost` (Modul Kosten teilen) | Kopf; Personen aus den Listen-Mitgliedern (Auswahl mit `Avatar`) | Einkauf vom 31. Okt. / Geteilt: Lena 21,40 € · du 21,40 € | Trip on 31 Oct / Split: Lena €21.40 · you €21.40 | Ansehen, W |
| neu `set_split_paid` | Kopf | Einkauf vom 31. Okt. / Lena hat bezahlt | Trip on 31 Oct / Lena has paid | W |
| neu `get_open_amounts` | Abschnitt | Offene Beträge · Lena schuldet dir 4,20 € · Du schuldest Max 3,10 € | Open amounts · Lena owes you €4.20 · You owe Max €3.10 | Ansehen |
| neu `delete_trip`, `clear_history` | Rückfrage-Karte 6 | | | |

Geld-Karten: keine Figurenfreude (Kopf-Figur bleibt `avo_waving`), Beträge tabellarisch, VoiceOver liest „gespart“
vor dem Betrag.

### 5.3 Rezepte und Kochen

| Werkzeug | Karte | DE | EN | Fuß |
|---|---|---|---|---|
| `search_recipes`, `get_saved_recipes` | Abschnitt mit bis zu 3 Rezeptzeilen (Bild 56 Radius 10, Titel Headline 17/22 bis 2 Zeilen, Meta Footnote); Fußnote, wenn Allergene gefiltert wurden | Rezepte bzw. Gemerkt · Ofengemüse mit Feta / 35 Min · 2 Portionen · 520 kcal; Fußnote: Rezepte mit deinen Allergenen sind ausgeblendet.; leer: Dazu finde ich kein Rezept. | Recipes or Saved · Roast vegetables with feta / 35 min · 2 servings · 520 kcal; Recipes with your allergens are hidden.; empty: I couldn't find a recipe for that. | Mehr Rezepte (öffnet `/recipes?q=`) |
| `add_recipe_to_list` (über A's `RecipeToList`) | Kopf + Zeile „2 standen schon drauf“; mit Angebote verfügbar, Markt und Region dritte Zeile `tag` | Wocheneinkauf / 9 Zutaten hinzugefügt · für 4 Portionen · 2 standen schon drauf: Zwiebeln, Olivenöl · 3 davon bei Lidl im Angebot / ca. 1,40 € gespart, laut Händler | Weekly shop / 9 ingredients added · for 4 servings · 2 already on it: onions, olive oil · 3 of them on offer at Lidl / about €1.40 saved, according to the retailer | Liste öffnen, W |
| `get_recipe_nutrition` | `NutritionRow` (4 Werte), Fußnote | 520 kcal · 24 g Protein · 48 g Kohlenhydrate · 26 g Fett; pro Portion, geschätzt | 520 kcal · 24 g protein · 48 g carbs · 26 g fat; per serving, estimated | |
| neu `save_recipe` | Kopf | Linsencurry mit Spinat / Gemerkt; entmerken: Nicht mehr gemerkt | Lentil curry with spinach / Saved; Removed from saved | W |
| neu `rate_recipe` | Kopf | Ofenlachs mit Zitrone / Bewertet: 5 von 5 Sternen | Baked salmon with lemon / Rated 5 of 5 stars | W |
| neu `create_recipe_draft` | Kopf | Linsencurry / Entwurf gespeichert | Lentil curry / Draft saved | Ansehen (Editor, A) |
| neu `delete_recipe`, `discard_draft` | Rückfrage-Karte 6 | | | |
| neu `substitute_ingredient` | Avo-Text + Zeile `arrow.left.arrow.right`, Fußnote nur mit Einwilligung Ernährung | Statt Feta: Hirtenkäse oder Tofu natur; Passt zu deiner Ernährung: vegetarisch | Instead of feta: white brine cheese or plain tofu; Fits your diet: vegetarian | |
| neu `cooking_step` | springt im Kochmodus (A-API), Kopf | Ofengemüse mit Feta / Schritt 4 von 7 | Roast vegetables with feta / Step 4 of 7 | Ansehen |
| neu `start_timer` | Kopf `timer` | Timer / 10:00 läuft | Timer / 10:00 running | Stoppen |
| neu `log_recipe` (Modul Kalorien) | Schätzungskarte 7.2 mit Portionen | | | |

### 5.4 Wochenplan (Modul, erst nach Freigabe von `AppModule.mealPlan`)

| Werkzeug | Karte | DE | EN | Fuß |
|---|---|---|---|---|
| neu `get_plan` | Rezeptzeile | Heute: Ofengemüse mit Feta; leer: Heute ist nichts geplant. | Today: Roast vegetables with feta; Nothing planned for today. | Ansehen |
| neu `add_to_plan` | Kopf Tag | Mi., 11. Nov. / Ofengemüse mit Feta · 2 Portionen | Wed, 11 Nov / Roast vegetables with feta · 2 servings | W |
| Tag schon belegt | Auswahlkarte | Am Mittwoch steht schon Linsencurry. · Dazulegen · Ersetzen | Lentil curry is already planned for Wednesday. · Add alongside · Replace | |
| neu `fill_plan` (Pro-Kandidat) | Kopf + Rezeptzeilen je Tag | Wochenplan, 9. bis 15. Nov. / 4 Tage geplant · Do., 12. Nov. · 2 Portionen | Meal plan, 9 to 15 Nov / 4 days planned · Thu, 12 Nov · 2 servings | Ansehen, W |
| neu `plan_to_list` | Kopf; Erfolgs-Haptik, Figur feiert 3 s | Wocheneinkauf / 17 Zutaten hinzugefügt · aus 4 Rezepten zusammengefasst · 3 standen schon drauf | Weekly shop / 17 ingredients added · combined from 4 recipes · 3 already on it | Liste öffnen, W |
| neu `move_in_plan` | Kopf | Ofengemüse mit Feta / Verschoben auf Fr., 13. Nov. | Roast vegetables with feta / Moved to Fri, 13 Nov | W |
| neu `remove_from_plan`, Woche leeren | Rückfrage-Karte 6 | | | |

### 5.5 Angebote (Modul Preise & Angebote, nur `offersAvailableProvider`, nur Markt der Liste)

| Werkzeug | Karte | DE | EN | Fuß |
|---|---|---|---|---|
| `search_offers` (ohne „günstigster Markt“) | Abschnitt, Zeilen: Kategorie-Symbol 28, Produktname, Unterzeile, rechts D2-Pille (`ItemOfferBadge`) und schlichter `plus`-Knopf 44 (fügt hinzu); Tippen auf die Zeile öffnet das Angebots-Detail (B8, Vollbild); Fußnote | Lidl, diese Woche · Milbona Frische Vollmilch 3,5 %, 1 l / laut Händler statt 1,15 € · bis Sa., 14. Nov. (ohne statt-Preis vom Händler: laut Händler · bis Sa., 14. Nov.); Fußnote: Preise laut Händler, in deiner Region ({PLZ}). Quelle: {Quelle} | Lidl, this week · Milbona fresh whole milk 3.5%, 1 l / was €1.15 according to the retailer · until Sat, 14 Nov; Prices according to the retailer, in your area ({postcode}). Source: {source} | |
| `get_personalized_deals` (für die Liste) | Kopf `tag`, aufklappbar zu den Angebotszeilen | 4 von 11 Artikeln diese Woche bei Lidl im Angebot / ca. 3,20 € gespart, in deiner Region | 4 of 11 items on offer at Lidl this week / about €3.20 saved, in your area | Ansehen (Angebote der Liste, B8) |
| `get_savings_summary` | Kopf `tag` | November: ca. 12,40 € durch Angebote gespart / laut Händler · 6 Einkäufe; ohne Ersparnis: Für November ist keine Ersparnis erfasst. | November: about €12.40 saved through offers / according to the retailer · 6 trips; No savings recorded for November. | Ansehen (Verlauf) |
| keine echte Region | Abschnitt `location`, öffnet die Region-Eingabe (B8, Vollbild) | Für Angebote in deiner Region: Postleitzahl festlegen | Set your postcode to see offers in your area | |
| Liste ohne Markt | Abschnitt mit `StoreChip` „Markt wählen“ | Wocheneinkauf hat noch keinen Markt. | Weekly shop has no store yet. | Markt wählen / Choose store |
| Frage nach dem günstigsten Markt | nur Avo-Text (Server-Prompt) | Märkte vergleiche ich nicht. Bei Lidl sind diese Woche 4 deiner Artikel im Angebot. | I don't compare stores. 4 of your items are on offer at Lidl this week. | |
| `compare_list_prices`, `cheapest_store` | **entfallen** (Plan 8) | | | |

Ersparnis-Teil entfällt ohne echte Region und unter 0,50 €. Bei aktivem Kill-Switch oder Modul aus gibt es diese
Werkzeuge nicht; Avo erwähnt Angebote dann gar nicht.

### 5.6 Kalorien und Gesundheit (Modul)

| Werkzeug | Karte | DE | EN | Fuß |
|---|---|---|---|---|
| `get_nutrition_status` | Kopf mit `ProgressRing` 44 statt Bild; über dem Ziel Symbol `exclamationmark.triangle` und Text (nie nur Farbe) | 640 kcal übrig / 1.360 von 2.000 kcal heute; drüber: 120 kcal drüber / 2.120 von 2.000 kcal heute | 640 kcal left / 1,360 of 2,000 kcal today; 120 kcal over / 2,120 of 2,000 kcal today | Ansehen |
| `log_food` (Text oder Foto) | Schätzungskarte 7.2, nie direkt gespeichert | | | Bearbeiten, Eintragen |
| `log_water` | Kopf `drop` | Wasser / 250 ml eingetragen · heute 1,25 von 2 l | Water / 250 ml logged · 1.25 of 2 l today | W |
| `log_weight` | Kopf `scalemass` | Gewicht / 78,4 kg eingetragen · Sa., 7. Nov. | Weight / 78.4 kg logged · Sat, 7 Nov | W |
| neu `log_workout` | Kopf `figure.run` | Laufen / 30 Min eingetragen · ca. 310 kcal, geschätzt | Running / 30 min logged · about 310 kcal, estimated | W |
| `setup_nutrition_goal` | höchstens zwei Fragen pro Nachricht als Auswahl, vorbefüllt; dann Ziel-Vorschau mit Knopf | Neues Ziel: 1.800 kcal am Tag / bisher 2.000 · Richtwert, kein ärztlicher Rat · Übernehmen; danach: Ziel übernommen: 1.800 kcal am Tag | New goal: 1,800 kcal a day / was 2,000 · guide value, not medical advice · Use this goal; Goal set: 1,800 kcal a day | W (nach Übernehmen) |
| `get_weekly_nutrition_summary` | `BarChart` (eine Reihe, Zielmarke gestrichelt), darunter Satz; ungeloggte Tage leer | Diese Woche im Schnitt 1.840 kcal, Ziel 2.000.; leer: Noch keine Woche erfasst. | This week you averaged 1,840 kcal, goal 2,000.; No week logged yet. | Ansehen |
| `get_challenge_status` | Kopf `flag` | Wasser-Woche / 4 von 7 Tagen | Water week / 4 of 7 days | Ansehen |
| neu `start_challenge`, `checkin_challenge` | Kopf | Wasser-Woche / Gestartet, Tag 1 von 7 · Heute abgehakt | Water week / Started, day 1 of 7 · Checked in today | W |
| neu `get_ideas` | Avo-Text + Rezeptzeilen | Mit 640 kcal passt zum Beispiel: | With 640 kcal left, these would fit: | Mehr Rezepte |
| `delete_food_log`, Wasser/Gewicht löschen, Challenge abbrechen | Rückfrage-Karte 6 | | | |
| neu `sync_health` | ohne Erlaubnis Abschnitt, öffnet `/settings/health` (B6); Avo setzt nie selbst Berechtigungen | Apple Health ist noch nicht verbunden. | Apple Health isn't connected yet. | Verbinden / Connect |

Gesundheitsangaben (Allergien, Ernährung, Gewicht, Ziele) gehen nur mit Einwilligung (Kapitel 9) ans Modell. Allergie-
Bezug: Kopf-Figur bleibt `avo_waving`, Warnzeile mit Symbol, kein Witz.

### 5.7 Einstellungen, Module, Profil

| Werkzeug | Karte | DE | EN | Fuß |
|---|---|---|---|---|
| `update_setting` | Kopf mit Symbol der Einstellungsseite, Tippen öffnet die Seite | Darstellung / Dunkel, vorher System | Appearance / Dark, was System | W |
| Allergie hinzufügen (einzeln, nie ganze Liste) | Kopf `leaf` | Allergien / Erdnuss hinzugefügt · Rezepte mit Erdnuss werden markiert | Allergies / Peanut added · recipes with peanut will be flagged | W |
| Allergie entfernen | Rückfrage-Karte Variante Sicherheit (6.5) | | | |
| Ernährung | Kopf | Ernährung / Vegetarisch, vorher keine Angabe | Diet / Vegetarian, was not set | W |
| PLZ | Kopf `location` | Region / 80331 München | Region / 80331 Munich | W |
| Mitteilungen einzeln | Kopf `bell` | Mitteilungen / Listen-Aktivität aus, vorher an | Notifications / List activity off, was on | W |
| Avo-Einstellungen | Kopf | Avo / Antworten werden vorgelesen | Avo / Answers are read aloud | W |
| neu `set_module` | Kopf `switch.2`; Hinweis, wo das Modul erscheint | Module / Kalorien & Gesundheit eingeschaltet · Die Karte erscheint auf Home | Modules / Calories & Health turned on · The card appears on Home | W |
| `set_module` Avo aus | Avo-Text, dann schließt sich der Tab; globaler Toast | Avo ist jetzt aus. Im Profil kannst du Avo wieder einschalten. · Toast: Avo ausgeschaltet · Widerrufen | Avo is now off. You can turn it back on in Profile. · Avo turned off · Undo | |
| `get_app_info`, Pro-Fragen | Avo-Text aus `pro_features` und `AppBrand`, Preise aus StoreKit; Zeile zur Seite | Avo Pro, Hilfe | Avo Pro, Help | Chevron |
| nie per Avo (Konto löschen, Abmelden, Abo, Systemrechte, Nachrichten an andere) | Avo-Text + Zeile zur Seite | Das machst du am besten selbst unter Konto. | You can do that yourself under Account. | Konto öffnen / Open Account |

---

## 6. Rückfrage-Karte Löschen (`AvoConfirmCard`)

**Zweck:** Soll das wirklich weg? Jedes Löschen über Avo braucht einen Tipp auf diese Karte, auch im Sprachmodus.

**Technik (erzwungen):** Das Modell hat nur `propose_delete(target)`. Die App prüft Rechte und Objekt, erzeugt die
Karte mit einem Einmal-Schlüssel (10 Minuten gültig, an Objekt und Version gebunden) und meldet dem Modell nur
„wartet auf Bestätigung“. Erst der Tipp auf den destruktiven Knopf löscht, in der App. Gesprochene Zustimmung hat keinen
Weg zur Ausführung. Löschen läuft nie über die Offline-Warteschlange.

### 6.1 Aufbau (ein Abschnitt in der weißen Gruppe, Radius 26, Innenabstand 16)

1. Kopfzeile: Symbol `trash` 20 pt in Sekundärfarbe (neutral, nicht rot), Titel Headline 17/22.
2. Folge in Body 17/22 bzw. Unterzeile Subhead 15/20 sekundär.
3. Zwei Knöpfe nebeneinander, gleich breit, je 44 hoch, Radius 22: „Abbrechen“ (Fläche `fill`, Grundtext) links,
   destruktiv gefüllt rechts (**Text-Rot #D70015** als Fläche, weißer Text 5,38:1; nie #FF3B30 mit Text, 3,55:1).
   Ab AX1 und bei 320 pt untereinander, destruktiver Knopf oben, volle Breite.
4. Keine Figur in der Karte; Avo schreibt nichts davor.

### 6.2 Texte je Ziel

| Ziel | Titel DE | Folge DE | Titel EN | Folge EN | Knopf DE / EN |
|---|---|---|---|---|---|
| Liste mit Mitgliedern | „{name}“ löschen? | Die Liste und {n} Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen. | Delete “{name}”? | The list and its {n} items will be deleted for all members. You can't undo this. | Löschen / Delete |
| eigene Liste ohne Mitglieder | „{name}“ löschen? | Die Liste und {n} Artikel werden gelöscht. Das lässt sich nicht rückgängig machen. | Delete “{name}”? | The list and its {n} items will be deleted. You can't undo this. | Löschen / Delete |
| Artikel | {n} Artikel aus {list} löschen? (1: „Milch aus {list} löschen?“) | Unterzeile: Milch, Eier, Gurken | Delete {n} items from {list}? (1: “Delete Milk from {list}?”) | Milk, eggs, cucumbers | Löschen / Delete |
| Liste verlassen (keine Rechte zum Löschen) | „{name}“ verlassen? | Du siehst die Liste danach nicht mehr. {owner} kann dich wieder einladen. | Leave “{name}”? | You won't see the list anymore. {owner} can invite you again. | Verlassen / Leave |
| Mitglied entfernen | {person} aus „{list}“ entfernen? | {person} sieht die Liste danach nicht mehr. | Remove {person} from “{list}”? | {person} won't see the list anymore. | Entfernen / Remove |
| Essen | „{food}“ aus dem Tagebuch löschen? | Unterzeile: {meal} · {kcal} kcal | Delete “{food}” from your diary? | {meal} · {kcal} kcal | Löschen / Delete |
| Wasser, Gewicht | {amount} von {time} löschen? | | Delete {amount} from {time}? | | Löschen / Delete |
| Rezept | Rezept „{name}“ löschen? | Das lässt sich nicht rückgängig machen. | Delete recipe “{name}”? | You can't undo this. | Löschen / Delete |
| Entwurf | Entwurf „{name}“ verwerfen? | | Discard draft “{name}”? | | Verwerfen / Discard; Abbrechen heißt hier „Behalten“ / „Keep“ |
| Einkauf im Verlauf | Einkauf vom {date} löschen? | Er verschwindet aus deinem Verlauf und aus dem Monatsrückblick. Das lässt sich nicht rückgängig machen. | Delete the trip on {date}? | It disappears from your history and your monthly review. You can't undo this. | Löschen / Delete |
| ganzer Verlauf | Alle {n} Einkäufe löschen? | wie oben | Delete all {n} trips? | as above | Alle löschen / Delete all |
| eigene Kategorie | Kategorie „{name}“ löschen? | Die Artikel darin landen unter „Sonstiges“. (Verhalten mit `category_order_service` prüfen) | Delete category “{name}”? | Its items move to “Other”. | Löschen / Delete |
| Challenge | „{name}“ beenden? | Dein Fortschritt von {n} Tagen geht verloren. | End “{name}”? | You'll lose {n} days of progress. | Beenden / End; Abbrechen heißt hier „Weitermachen“ / „Keep going“ |
| Rezept aus dem Plan | {recipe} am {date} aus dem Plan nehmen? | Die Zutaten bleiben auf deinen Listen. | Remove {recipe} on {date} from the plan? | The ingredients stay on your lists. | Herausnehmen / Remove |
| Woche leeren | Alle {n} Rezepte vom {range} aus dem Plan nehmen? | wie oben | Remove all {n} recipes from {range}? | as above | Alle herausnehmen / Remove all |

Abbrechen DE/EN: „Abbrechen“ / „Cancel“ (`avo_cancel`). Schlüssel je Ziel `avo_confirm_<ziel>_title`/`_body`.

### 6.3 Zustände

| Zustand | Verhalten | DE | EN | Schlüssel |
|---|---|---|---|---|
| wartet | Karte aktiv, Kopf-Figur `avo_waving` ohne Wechsel | | | |
| gelöscht (Liste, Rezept, Verlauf) | Karte klappt zur Ergebniszeile, ohne Aktion | Liste „{name}“ gelöscht | List “{name}” deleted | `avo_deleted_list` |
| gelöscht (Artikel, Essen, Plan) | Ergebniszeile mit W (Wieder-Einfügen, neue IDs) | {n} Artikel gelöscht | {n} items deleted | `avo_deleted_items` |
| abgebrochen | Zeile Sekundärfarbe | Nicht gelöscht. | Not deleted. | `avo_not_deleted` |
| abgelaufen (10 min oder Objekt geändert) | Knöpfe deaktiviert, Unterzeile | Diese Rückfrage ist abgelaufen. Frag noch einmal. | This request has expired. Ask again. | `avo_confirm_expired` |
| Fehler | Fehler-Abschnitt, Fehler-Haptik, nichts gelöscht | Das hat nicht geklappt. · Erneut versuchen | That didn't work. · Try again | `avo_err_title`, `avo_retry` |
| offline | destruktiver Knopf deaktiviert, Unterzeile | Offline. Löschen geht erst mit Verbindung. | You're offline. You can delete once you're connected. | `avo_confirm_offline` |
| keine Rechte | Karte erscheint nicht; Avo sagt es und bietet „Liste verlassen“ als eigene Karte an | Die Liste gehört {owner}. Löschen kann ich sie nicht, verlassen kannst du sie. | The list belongs to {owner}. I can't delete it, but you can leave it. | Server-Prompt |

### 6.4 Interaktion, Sprachmodus, Barrierefreiheit

- Gedrückt: 0,97 und 90 % Deckkraft. Keine Haptik beim Löschen, Fehler-Haptik nur bei Fehlschlag.
- VoiceOver: Karte als Gruppe „Rückfrage: „Party“ löschen? Die Liste und 14 Artikel …“; Fokus springt beim Erscheinen
  auf den Titel; destruktiver Knopf mit Hinweis „Löscht die Liste endgültig.“ / „Deletes the list permanently.“
  (`avo_confirm_hint_list`). Ab AX3 scrollt der Verlauf die Karte vollständig in Sicht, ohne die Blase zu verdecken.
- Sprachmodus: Avo sagt „Soll ich „{name}“ mit {n} Artikeln löschen? Tippe auf Löschen, wenn du sicher bist.“ /
  “Should I delete “{name}” with {n} items? Tap Delete if you're sure.” Auf „Ja“ oder „Lösch es“: „Dafür brauche ich
  deinen Tipp auf Löschen.“ / “I need you to tap Delete for that.” „Nein“ oder „Abbrechen“ per Stimme gilt sofort
  (`avo_voice_confirm_delete`, `avo_voice_need_tap`).

### 6.5 Variante Sicherheit (Allergie entfernen)

Gleiches Muster, Symbol `exclamationmark.triangle.fill` im Warn-Token (Kontrast mindestens 3:1, Anfrage an A), Titel
„{allergen} aus deinen Allergien entfernen?“, Folge „Rezepte mit {allergen} werden dann nicht mehr markiert.“, Knöpfe
„Abbrechen“ und „Entfernen“ (destruktiv gefüllt). Danach Ergebniszeile mit W. EN: “Remove {allergen} from your
allergies?”, “Recipes with {allergen} will no longer be flagged.”, “Remove”. Owner-Frage F-16-4 (Vorschlag ja).

---

## 7. Foto an Avo und Schätzungen

### 7.1 Ablauf

1. Foto-Knopf → Pull-down-Menü „Foto aufnehmen“ (Systemkamera) / „Foto auswählen“ (System-Auswahl, ein Bild, ohne
   Freigabe der Fotomediathek).
2. Nutzer-Blase mit Foto (2.2), Arbeits-Zeile „Liest das Foto“ bzw. „Schätzt das Essen“, „Stopp“ sichtbar
   (Zeitlimit 30 s).
3. Absicht aus dem Kontext: Kalorien = Essen, Liste = Zettel; sonst Auswahlkarte „Was soll ich mit dem Foto machen?“
   mit „Als Essen eintragen“ (`flame`, nur Modul Kalorien), „Artikel auf eine Liste“ (`text.viewfinder`), „Rezepte
   daraus“ (`fork.knife`). EN: “What should I do with this photo?”, “Log as a meal”, “Add items to a list”, “Find
   recipes with this”.

### 7.2 Schätzungskarte (`AvoEstimateCard`), nie direkt gespeichert

1. Kopf: Titel Headline 17/22 „Spaghetti Bolognese“, Unterzeile „ca. 650 kcal · {Sicherheit}“.
   Sicherheit aus `meal_photo.confidence` (Plan B1.7, drei Stufen): `recht_sicher` „geschätzt, recht sicher“ /
   “estimated, fairly sure”; `unsicher` „geschätzt, unsicher“ / “estimated, unsure”; `grob` „grob geschätzt“ /
   “rough estimate” (siehe Konflikt K9; das Konzept nennt Prozent).
2. Zeile „Mahlzeit“ / “Meal” mit Wert nach Uhrzeit (Pull-down: Frühstück, Mittagessen, Abendessen, Snack / Breakfast,
   Lunch, Dinner, Snack).
3. Zeile „Menge“ / “Amount“ mit Wert „1 Teller, ca. 400 g“ / “1 plate, about 400 g”; Tippen öffnet die Mengen-Eingabe
   aus B6 als Vollbild (Stepper und Zahlenfeld, kein Schieberegler).
4. `NutritionRow`: „650 kcal“, „28 g Protein“, „72 g Kohlenhydrate“, „24 g Fett“; ab AX1 2 × 2.
5. Fußnote „Geschätzt. Richtwerte, kein ärztlicher Rat.“ / “Estimated. Guide values, not medical advice.”
6. Knöpfe 44: „Bearbeiten“ (Glas-Kapsel, öffnet „Essen eintragen“ aus B6 vorbefüllt, Vollbild) und „Eintragen“
   (getönte Kapsel; Text auf getöntem Glas nur mit Deckkraft ab 0,92, Anfrage an A). Nur die jüngste offene Schätzung
   hat den gefüllten Knopf, ältere zeigen „Eintragen“ schlicht.
7. Nach „Eintragen“: Ergebniszeile `flame` „Spaghetti Bolognese eingetragen“, Unterzeile „Mittagessen · 650 kcal ·
   noch 640 kcal übrig“ (über dem Ziel „· 120 kcal drüber“), W. EN “Spaghetti Bolognese logged”, “Lunch · 650 kcal ·
   640 kcal left”, “· 120 kcal over”. Mit Apple Health auch dort geschrieben.
8. Sprachmodus: Avo sagt „Spaghetti Bolognese, etwa 650 Kilokalorien, als Mittagessen. Eintragen?“; „Ja“ per Stimme
   trägt ein (Eintragen ist widerrufbar, nur Löschen braucht den Tipp).

### 7.3 Zettel und Kühlschrank

- Zettel (`list_import`, ein Aufruf pro Zettel): Abschnitt „14 Artikel erkannt“ / “14 items found” mit abwählbaren
  Zeilen (alle gewählt), Abschnitt „Nicht erkannt“ / “Couldn't read”, Knopf „{n} hinzufügen“ / “Add {n}” (Zahl
  folgt der Auswahl); danach Ergebniszeile „{n} Artikel zu {list} hinzugefügt“ mit W. Ziel-Liste unklar: Auswahlkarte.
- Kühlschrank: Avo-Text mit erkannten Zutaten („Ich sehe Zucchini, Feta, Eier und Paprika.“) und Rezeptzeilen.

### 7.4 Zustände

| Zustand | DE | EN | Schlüssel |
|---|---|---|---|
| kein Essen (`no_food_detected`) | Ich erkenne darauf kein Essen. · Manuell eintragen | I can't see any food in this photo. · Add manually | `avo_photo_no_food`, `avo_photo_manual` |
| keine Artikel (`no_items_found`) | Auf dem Foto finde ich keine Artikel. · Neues Foto | I can't find any items in this photo. · New photo | `avo_photo_no_items`, `avo_photo_new` |
| unlesbar (`unreadable_image`) | Das Foto kann ich nicht lesen. Versuch es mit mehr Licht und etwas näher dran. · Neues Foto | I can't read this photo. Try again with more light and a bit closer. · New photo | `avo_photo_unreadable` |
| Allergen erkannt | Warnzeile mit `exclamationmark.triangle.fill`, Warnungs-Haptik einmal: Enthält vermutlich {allergen}. Du hast {allergen} als Allergie eingetragen. | Probably contains {allergen}. You've listed {allergen} as an allergy. | `avo_photo_allergen` |
| Tageslimit Essensfoto | Heute geht kein weiteres Essensfoto. Du kannst das Essen manuell eintragen. · Manuell eintragen | No more meal photos today. You can add the meal manually. · Add manually | `avo_photo_limit_meal` |
| Tageslimit Zettel | Heute geht kein weiterer Zettel. Ab morgen wieder. | No more list photos today. You can try again tomorrow. | `avo_photo_limit_list` |
| offline | Foto-Blase „Nicht gesendet · Erneut senden“ | | |
| Modul Kalorien aus | Zeile „Als Essen eintragen“ entfällt; ausdrücklich gefragt: Modul-Zeile 2.8 | | |
| Kamera nicht erlaubt (vor der Systemabfrage) | Dialog 11.3 | | |
| Kamera abgelehnt | `StatusRow` mit Knopf „Einstellungen“, darunter Textknopf: Kamera ist aus. In Einstellungen erlauben · Stattdessen Foto auswählen | Camera is off. Allow it in Settings · Choose a photo instead | `avo_camera_denied`, `avo_photo_choose_instead` |

Haptik nur bei Allergen (Warnung) und Fehler. Foto erscheint per Überblendung.

---

## 8. Screen 2: Sprachmodus `/avo/voice`

**Zweck:** Sprechen statt tippen; Avo antwortet mit Stimme und zeigt, was er getan hat.

**Route:** `/avo/voice` (Kind `'voice'` unter `/avo`, Root-Navigator, ohne Tab-Leiste). Einstiege: Sprachmodus-Knopf
der Eingabe, Siri „Frag Avo“, Widget „Avo fragen“, Kontrollzentrum, Action Button, `shoply://avo/voice`. Beenden
führt immer zurück in den Avo-Tab, wo alle Runden als Text mit ihren Ergebniskarten stehen.

**Technik:** eigener Kanal `shoply/voice` (Swift, Apple Speech + `AVSpeechSynthesizer`, kein Fremdpaket): Erkennung
starten/stoppen mit Teil- und Endergebnis, Pegel von Mikrofon und Sprachausgabe (ca. 30 Werte/s), Sprachausgabe mit
Stimme und Unterbrechen, Audio-Sitzung mit Leiserstellen anderer Audioausgabe. Bildschirm bleibt an, solange der
Sprachmodus offen ist. App im Hintergrund: Sprachmodus endet, Gespräch bleibt.

### 8.1 Aufbau oben nach unten (390 × 844, D2 `X-AvoSprache`)

1. Grund #F2F2F7 (Token), keine Tab-Leiste, keine Griffleiste, kein Zurück oben.
2. Statuszeile oben links (nur bei Bedarf): `StatusRow` bzw. Kontext-Kapsel 2.9.
3. Figur 120 × 120 (`contain`) mittig in einem Kreis 210 pt mit grünem radialem Schein (22 % → 8 % → 0), Oberkante
   150 pt vom Bildschirmrand (96 pt unter dem sicheren Bereich). Die Figur ist eine Taste (8.4).
4. Pegel: 8 Balken 6 pt breit, Radius 3, Abstand 5, Akzent, Fläche 44 hoch, 18 pt unter dem Kreis; Höhe 10 bis
   40 pt nach Pegel. Dekorativ (für VoiceOver ausgeblendet).
5. Zustandstext Subhead 15/20 Sekundärfarbe, mittig, 18 pt Abstand, Seitenrand 32.
6. Textbereich, 8 pt Abstand, Seitenrand 28, mittig, höchstens 4 sichtbare Zeilen, ältere blenden nach oben aus:
   - Person spricht: Transkript in deutschen Anführungszeichen, 24/30 Semibold (D2), noch unsichere Wörter in
     Sekundärfarbe, bis die Erkennung sie festlegt.
   - Avo spricht: Antwort ohne Anführungszeichen, 24/30 Regular, Wort für Wort im Takt der Stimme.
7. Ergebnisbereich, 26 pt Abstand, Seitenrand 16: weiße Gruppe Radius 26, Innenabstand 14/16. Vor dem ersten Ergebnis
   der Hinweis aus D2 mit grünem Haken-Kreis (nur in den ersten drei Sitzungen, Owner-Frage F7); danach höchstens zwei
   Ergebnisabschnitte (2.5, kompakt: Kopfzeile + Fuß), ältere als eine Zeile „3 Ergebnisse · Ansehen“ (öffnet nach dem
   Ende den Chat). Rückfrage-Karte und Auswahlkarte erscheinen hier.
8. Steuerung, Unterkante 44 pt über dem Bildschirmrand: Empfehlung K4 sind vier Kreise in einer Reihe, 64 pt bei
   Breite ab 375 (Abstand 24), 60 pt bei 320 (Abstand 16, ergibt genau 288): „Zur Texteingabe wechseln“ (Glas,
   Tastatur), „Foto hinzufügen“ (Glas, Kamera), „Mikrofon stummschalten“ (Glas, `mic.slash`, gewählt
   `mic.slash.fill` auf `fill`), „Sprachmodus beenden“ (rot gefüllt, weißes X, Schatten wie D2). Die D2-Variante hat
   nur Tastatur und Beenden.

Kompakte Bühne bei weniger als 700 pt Höhe (iPhone SE, Anzeigezoom) oder ab AX3: Figur 64 pt oben links neben dem
Zustandstext, Schein 112 pt, Pegel rechts daneben 24 pt hoch, darunter ein scrollender Bereich mit Transkript und
Antwort (linksbündig), dann Ergebnisbereich, Steuerung unverändert.

### 8.2 Zustände

| Zustand | Figur / Schein / Pegel | Zustandstext DE | EN | Sonstiges |
|---|---|---|---|---|
| Vorab-Erklärung (Mikrofon oder Spracherkennung noch nicht gefragt) | `avo_waving`, Schein ruhig, Pegel aus | Titel statt Zustandstext: Sprich mit Avo | Talk to Avo | Text (on-device): Deine Stimme wird auf dem iPhone in Text umgewandelt. Avo bekommt nur den Text. / Your voice is turned into text on your iPhone. Avo only gets the text. Ohne On-device-Erkennung: Apple wandelt deine Stimme in Text um. Avo bekommt nur den Text. / Apple turns your voice into text. Avo only gets the text. Knöpfe im Ergebnisbereich: getönt „Weiter“ / “Continue” (löst nacheinander Mikrofon und Spracherkennung aus), schlicht „Nicht jetzt“ / “Not now” (zurück in den Tab). Schlüssel `avo_voice_intro_*` |
| hört zu | `avo_waving`, Schein skaliert bis 8 % mit dem Pegel, Balken folgen dem Mikrofon | Avo hört zu | Avo is listening | leichter Impuls beim Beginn; Ansage „Avo hört zu“; Satzende nach ca. 1,0 s Stille (nicht mit VoiceOver) |
| nichts gehört (8 s) | ruhig | Ich habe nichts gehört. Tippe auf Avo und sprich. | I didn't hear anything. Tap Avo and speak. | Mikrofon stoppt |
| denkt | `avo_thinking`, Schein langsam pulsierend (einzige Endlos-Animation), Balken flach | Avo denkt nach | Avo is thinking | Ergebnisse erscheinen, sobald Werkzeuge fertig sind |
| spricht | `avo_waving`, Schein folgt der Sprachausgabe | Avo spricht · Tippen zum Unterbrechen | Avo is speaking · Tap to interrupt | danach wieder „hört zu“, wenn „Nach der Antwort weiter zuhören“ an ist |
| stumm | ruhig, Balken aus | Mikrofon aus | Microphone off | Avo spricht zu Ende, hört nicht zu |
| Rückfrage Löschen | `avo_waving`, kein Schein | Wartet auf deinen Tipp | Waiting for your tap | Rückfrage-Karte im Ergebnisbereich; „Ja“ führt nicht aus (6.4) |
| Rückfrage Auswahl | ruhig | Avo hört zu | Avo is listening | Auswahl per Stimme oder Tipp |
| Allergie, Geld | `avo_waving`, kein Schein | wie Zustand | | ruhiger Ton, keine Freude |
| Fehler Netz | ruhig | Ich höre dich gerade nicht. Prüfe deine Verbindung. | I can't hear you right now. Check your connection. | Fehler-Haptik; Transkript bleibt mit „Erneut senden“ |
| offline | ruhig | Offline | Offline | `StatusRow` oben „Offline. Avo braucht eine Verbindung.“; Erkennung auf dem Gerät läuft, Transkript bleibt mit „Erneut senden“ / “Send again”, nichts geht später automatisch raus |
| Spracherkennung nicht verfügbar | ruhig | Die Spracherkennung geht gerade nicht. Du kannst stattdessen tippen. | Speech recognition isn't working right now. You can type instead. | Textknopf „Stattdessen tippen“ / “Type instead” |
| Mikrofon belegt (Anruf) | ruhig | Das Mikrofon wird gerade benutzt, zum Beispiel für einen Anruf. | The microphone is in use, for example by a call. | startet nach Ende der Unterbrechung nicht von selbst |
| Mikrofon abgelehnt | ruhig | | | `StatusRow` „Mikrofon ist aus. In Einstellungen erlauben“ / “Microphone is off. Allow it in Settings” + „Stattdessen tippen“ (Tab mit Tastatur) |
| Spracherkennung abgelehnt (nur eine Erlaubnis erteilt gilt wie abgelehnt) | ruhig | | | „Spracherkennung ist aus. In Einstellungen erlauben“ / “Speech recognition is off. Allow it in Settings” |
| Tageslimit | ruhig | Für heute ist Schluss mit Fragen. Ab morgen geht es weiter. | That's all the questions for today. You can ask again tomorrow. | Mikrofon aus; Free: Pro-Zeile im Ergebnisbereich höchstens einmal pro Woche |
| Kill-Switch KI | ruhig | Avo ist gerade nicht verfügbar. | Avo isn't available right now. | nur „Beenden“ aktiv |
| Pro gesperrt (nur falls der Owner den Sprachmodus Pro macht, F-16-3) | ruhig | Tippe auf Avo und sprich. | Tap Avo and speak. | Mikrofon startet nicht; Tipp auf die Figur öffnet `/pro?feature=voice`; echte Bühne statt Schloss |
| Modul Avo aus | | | | Dialog 11.1 vor dem Öffnen |

„ruhig“ heißt: `avo_waving`, Schein steht still, Balken aus. Schlüssel der Zustände nach dem Muster
`avo_voice_<zustand>` (`avo_voice_listening`, `avo_voice_thinking`, `avo_voice_speaking`, `avo_voice_muted`,
`avo_voice_waiting_tap`, `avo_voice_nothing_heard`, `avo_voice_err_network`, `avo_voice_err_unavailable`,
`avo_voice_mic_busy`, `avo_voice_mic_denied`, `avo_voice_speech_denied`, `avo_type_instead`); Tageslimit, Kill-Switch
und Offline nutzen die Schlüssel aus 3.3.

Vorlesen: höchstens fünf Artikel, bei Rezepten nur das erste mit Zeit („Ich habe drei Rezepte gefunden. Das erste:
Ofengemüse mit Feta, 35 Minuten.“), Preise mit „laut Händler“. Stimme in App-Sprache, Auswahl in den Avo-Einstellungen.

Hinweis-Karte D2 (humanisiert): „Ich sage dir, was ich geändert habe. Löschen mache ich nur, wenn du es bestätigst.“ /
“I'll tell you what I changed. I only delete things after you confirm.” (`avo_voice_hint`)

### 8.3 Interaktionen

- Tippen auf die Figur: unterbricht die Sprachausgabe und startet das Zuhören. Mit VoiceOver: Doppeltippen sendet,
  was gesagt wurde (kein automatisches Satzende).
- Beenden: X-Knopf, Zwei-Finger-Z (VoiceOver). Kein Wischen nach unten (es gibt kein Sheet). Rückweg wie Hinweg
  (Figur schrumpft zurück zum Knopf, Überblendung).
- Tastatur-Knopf: beendet den Sprachmodus und öffnet den Tab mit fokussiertem Feld.
- Kamera-Knopf: Menü wie 7.1, Foto erscheint im Ergebnisbereich als Vorschau.
- Haptik: leichter Impuls beim Beginn des Zuhörens, Fehler-Haptik bei Fehlern, Erfolg nur bei „Einkauf gespeichert“
  und „Wochenplan auf der Liste“. Avos Sprachausgabe pausiert, solange VoiceOver spricht.

### 8.4 Barrierefreiheit

- Beim Öffnen Ansage „Avo hört zu“. Fokus-Reihenfolge: Statuszeile → Figur → Zustandstext → Textbereich →
  Ergebnisbereich → Steuerung links nach rechts.
- Figur: Label „Avo“, Wert = Zustand („hört zu“, „denkt nach“, „spricht“), Hinweis je Zustand: „Sendet, was du gesagt
  hast“ / “Sends what you said” (mit VoiceOver beim Zuhören), „Unterbricht Avo“ / “Interrupts Avo” (beim Sprechen).
- Transkript und Antwort sind Live-Bereiche, angesagt erst nach vollständigem Satz.
- Steuerung: Labels „Zur Texteingabe wechseln“ / “Switch to typing”, „Foto hinzufügen“ / “Add photo”, „Mikrofon
  stummschalten“ / “Mute microphone” (Zustand „ausgewählt“), „Sprachmodus beenden“ / “End voice mode”. Large Content
  Viewer ab AX1.
- Kontrast: weißes X auf #FF3B30 3,55:1 reicht für ein Symbol (3:1), der Kreis gegen den Grund 3,18:1 ebenfalls; bei
  „Kontrast erhöhen“ Fläche Text-Rot #D70015. Nie Text auf #FF3B30.
- Reduce Motion: Figur und Schein ohne Größenänderung, nur Helligkeit; Balken in fester Höhe, Deckkraft folgt dem
  Pegel; Transkript ohne Ausblend-Verlauf, ältere Zeilen springen ohne Bewegung nach oben; Übergang nur Überblendung.
- Reduce Transparency: Glas-Knöpfe feste Fläche.
- Dynamic Type: bis xxxL wie beschrieben; ab AX1 Transkript und Antwort in einem scrollenden Bereich, je höchstens 3
  sichtbare Zeilen; ab AX3 kompakte Bühne. Ab AX1 ist die Figur hier **nicht** ausgeblendet, sondern klein (64 pt),
  weil sie die Haupttaste ist (Abweichung von der Fundament-Regel, Owner-Frage F11).
- 320 pt: Steuerung 4 × 60 + 3 × 16 = 288; Text bricht um.

### 8.5 Daten

`shoply/voice` (neu, B), `AvoVoiceController` (neu, B: Zustandsmaschine, Pegel per `select`, `RepaintBoundary` um
Figur und Balken), dieselbe Werkzeug-Schleife wie der Chat, Avo-Einstellungen (Stimme, weiter zuhören), Berechtigungs-
status über den Kanal, `aiRemoteEnabledProvider`, Verbindungsstatus. Info.plist braucht
`NSMicrophoneUsageDescription` und `NSSpeechRecognitionUsageDescription` (DE/EN, Owner-Freigabe offen, Vorschlag in
Kapitel 13 F8).

---

## 9. Screen 3: „So arbeitet Avo“ `/avo/intro`

**Zweck:** Was sieht und darf Avo? Einmal pro Konto vor der ersten Frage, mit Einwilligung für Gesundheitsangaben.

**Route und Navigation:** `/avo/intro` (Kind `'intro'`, Root-Navigator, Vollbild, Überblendung). Wird beim ersten
Senden geöffnet (Text, Vorschlag, Stimme, Foto). „Weiter“ speichert, schließt und sendet die Frage. „Schließen“
schließt ohne zu senden; die Frage steht dann weiter im Eingabefeld (geht nicht verloren).

### 9.1 Aufbau oben nach unten

1. Toolbar: Glas-Knopf 44 „Schließen“ (`xmark`) oben links.
2. Figur 64 pt `avo_waving` linksbündig (einzige Figur), 8 pt darunter großer Titel „So arbeitet Avo“ 34/41 Bold.
3. 24 pt, weiße Gruppe Radius 26 mit drei Zeilen (Innenabstand 14/16, Symbol 22 in Grundtextfarbe, Titel Headline
   17/22, Text Subhead 15/20 sekundär).
4. 24 pt, weiße Gruppe mit `ToggleRow`s (Schalter-Farbe „an“ = Akzent bzw. A-Token), Unterzeile je Schalter.
5. Fußnote 13/18 sekundär mit Textknopf „Datenschutz“.
6. Unten fest: getönte Kapsel groß 50 pt, Radius 25, volle Breite minus 32, „Weiter“, 16 pt über dem sicheren
   Bereich; Scroll-Kante darüber. Inhalt scrollt.

| Element | DE | EN | Schlüssel |
|---|---|---|---|
| Titel | So arbeitet Avo | How Avo works | `avo_intro_title` |
| Zeile 1 (`checklist`) | Kennt, was du in der App hast · Listen, Rezepte, Wochenplan und Einstellungen, damit die Antworten passen. (Wochenplan nur mit Modul) | Knows what's in the app · Lists, recipes, meal plan and settings, so the answers fit. | `avo_intro_knows_title`, `avo_intro_knows_body` |
| Zeile 2 (`hand.raised`) | Ändert nur mit deinem Konto · Avo darf nur, was du auch darfst. Änderungen kannst du widerrufen, gelöscht wird nur nach deinem Tipp. | Only acts with your account · Avo can only do what you can do. You can undo changes, and nothing is deleted until you tap. | `avo_intro_account_*` |
| Zeile 3 (`exclamationmark.circle`) | Kann sich irren · Schätzungen sind als geschätzt markiert. Prüfe Allergene immer auf der Verpackung. | Can be wrong · Estimates are marked as estimated. Always check allergens on the packaging. | `avo_intro_wrong_*` |
| Schalter 1 (Standard aus) | Ernährung und Allergien einbeziehen · Dann schlägt Avo passende Rezepte vor und warnt dich im Chat. | Include diet and allergies · Avo then suggests recipes that fit and warns you in the chat. | `avo_consent_diet_*` |
| Schalter 2 (nur Modul Kalorien, Standard aus) | Kalorien, Gewicht und Ziele einbeziehen · Dann kann Avo dein Tagebuch und deine Ziele nutzen. | Include calories, weight and goals · Avo can then use your diary and goals. | `avo_consent_health_*` |
| Fußnote | Avo nutzt Claude von Anthropic. Deine Fragen und die Daten, die Avo dafür liest, gehen über unseren Server an Anthropic. · Datenschutz | Avo uses Claude by Anthropic. Your questions and the data Avo reads to answer them go to Anthropic through our server. · Privacy | `avo_disclosure_long` |
| Knopf | Weiter | Continue | `avo_continue` |
| Schließen | Schließen | Close | `avo_close` |

### 9.2 Zustände und Regeln

- Allergien werden beim Suchen von Rezepten immer beachtet (Filter in den Werkzeugen), auch mit Schalter aus; der
  Schalter bestimmt nur, ob Avo sie im Gespräch kennt.
- Offline: „Weiter“ geht; die Frage landet im Offline-Zustand 3.3.
- Kill-Switch KI: Screen wird nicht gezeigt, der Tab zeigt den Zustand 3.3.
- Modul Kalorien aus: Schalter 2 fehlt.
- Wiederholung: nie, außer nach Kontowechsel (neues Konto). Änderbar in den Avo-Einstellungen.
- Haptik keine.
- Barrierefreiheit: Titel ist Überschrift, Fokus beginnt auf dem Titel; ab AX1 Figur aus; ab AX3 Symbole aus,
  Schalter-Zeilen stapeln (Schalter unter dem Text, linksbündig); „Weiter“ bleibt fest unten und wird bei AX5 nicht
  höher als 3 Zeilen (Text bricht um). 320 pt: Umbruch. Reduce Motion: Übergang Überblendung (ist er ohnehin).

---

## 10. Screen 4: Avo-Einstellungen `/settings/avo` und Stimme `/settings/avo/voice`

**Zweck:** Wie soll Avo sprechen, und was darf er einbeziehen?

**Route:** `/settings/avo` (Push im Profil-Tab, nur mit Modul Avo an; Einstieg Profil > Avo als A-Slot, Avo-Menü
„Mehr > Avo-Einstellungen“, Suche). Kind `/settings/avo/voice`.

### 10.1 Aufbau `/settings/avo`

1. Toolbar: Glas-Knopf 44 „Zurück“ oben links. Großer Titel „Avo“ 34/41. Keine Figur (kein Anlass für eine Pose),
   kein `ProBadge`.
2. Abschnittstitel in Großbuchstaben 13/18 Semibold sekundär (VoiceOver liest normale Schreibung), dann Gruppen
   Radius 26. Jeder Schalter speichert sofort (ein Speichermodell, kein Sichern-Knopf).

| Abschnitt | Zeile | Komponente | DE | EN | Schlüssel |
|---|---|---|---|---|---|
| Stimme / Voice | Stimme | `NavRow`, Wert = gewählte Stimme | Stimme · Anna (Premium) | Voice · Anna (Premium) | `avo_set_voice` |
| | Antworten im Chat vorlesen (aus) | `ToggleRow` | Antworten im Chat vorlesen | Read answers aloud in the chat | `avo_set_read_aloud` |
| | Nach der Antwort weiter zuhören (an) | `ToggleRow` + Fußnote | Nach der Antwort weiter zuhören · Gilt im Sprachmodus. | Keep listening after an answer · In voice mode. | `avo_set_keep_listening`, `avo_set_keep_listening_note` |
| Was Avo einbeziehen darf / What Avo can use | Ernährung und Allergien | `ToggleRow` | Ernährung und Allergien | Diet and allergies | `avo_set_consent_diet` |
| | Kalorien, Gewicht und Ziele (nur Modul Kalorien) | `ToggleRow` | Kalorien, Gewicht und Ziele | Calories, weight and goals | `avo_set_consent_health` |
| | Fußnote | | Allergien beachtet Avo beim Suchen von Rezepten immer. Diese Schalter bestimmen nur, ob Avo sie im Chat kennt. | Avo always respects your allergies when searching for recipes. These switches only decide whether Avo knows about them in the chat. | `avo_set_consent_note` |
| Gespräch / Conversation | Gespeichert | `ValueRow` | Gespeichert · 24 Stunden, nur auf diesem iPhone | Kept · 24 hours, only on this iPhone | `avo_set_kept`, `avo_set_kept_value` |
| | Fragen heute (nur falls F3 ja) | `ValueRow` | Fragen heute · 2 von 3 | Questions today · 2 of 3 | `avo_set_usage` |
| | Gespräch löschen | destruktive Zeile, Text-Rot #D70015, zuletzt | Gespräch löschen | Delete conversation | `avo_set_delete_conversation` |
| Fuß | | Footnote + Textknopf | Avo nutzt Claude von Anthropic. · Datenschutz | Avo uses Claude by Anthropic. · Privacy | `avo_disclosure_short` |

„Gespräch löschen“ öffnet den zentrierten Dialog 11.2. Danach Zeile kurz deaktiviert mit Unterzeile „Kein Gespräch
gespeichert“ / “No conversation saved” (`avo_set_no_conversation`); ist schon keins gespeichert, ist die Zeile
deaktiviert mit diesem Text.

### 10.2 Aufbau `/settings/avo/voice`

- Großer Titel „Stimme“ / “Voice”. Gruppe mit allen installierten Systemstimmen der App-Sprache, sortiert Premium,
  Erweitert, Standard (DE „Premium“, „Erweitert“, „Standard“; EN “Premium”, “Enhanced”, “Default”).
- Zeile: Name Body 17, Qualität Subhead 15 sekundär, gewählte Zeile mit `checkmark` in Akzent links; rechts Knopf
  44 „Probe anhören: {name}“ / “Play sample: {name}” (`speaker.wave.2`, zweites Tippen stoppt). Wahl speichert sofort.
- Probesatz: „Hallo, ich bin Avo. Soll ich Milch auf deine Liste setzen?“ / “Hi, I'm Avo. Should I add milk to your
  list?” (`avo_voice_sample`).
- Fußnote: „Weitere Stimmen findest du in den iPhone-Einstellungen unter Bedienungshilfen > Gesprochene Inhalte >
  Stimmen.“ / “You can add voices in iPhone Settings under Accessibility > Spoken Content > Voices.”
  (`avo_voice_more_note`).

### 10.3 Zustände

| Zustand | Verhalten | DE | EN |
|---|---|---|---|
| lädt | alles lokal; Stimmenliste kommt über den Kanal, bis dahin nur die gespeicherte Wahl, Zeilen wachsen ohne Springen ein, kein Spinner | | |
| keine Stimme der App-Sprache | eine Zeile „Systemstimme“ gewählt, Fußnote wie oben | Systemstimme | System voice |
| gewählte Stimme gelöscht | fällt still auf die beste vorhandene zurück, Wert zeigt sie | | |
| Modul Avo aus | Route nicht erreichbar, Dialog 11.1 | | |
| Modul Kalorien aus | Schalter „Kalorien, Gewicht und Ziele“ fehlt | | |
| offline | keine Änderung (alles lokal; Einwilligungen gehen mit, sobald online, falls im Konto gespeichert, Lücke L5) | | |
| Pro | kein `ProBadge`, auch wenn der Sprachmodus Pro wird | | |

Barrierefreiheit: Standardverhalten der Einstellungszeilen (Schalter mit Zustand, ganze Zeile tippbar, 44+), ab AX1
Schalter unter den Text; Abschnittstitel als Überschriften; Probe-Knopf mit eigenem Label. 320 pt: Werte brechen unter
den Titel. Haptik keine. „Avo-Erinnerungen“ stehen nicht hier, sondern in den Mitteilungen (B-Bereich `notifications`).

---

## 11. Dialoge (zentriert, `showAdaptiveDialog` über A)

### 11.1 Modul Avo aus (Direktaufruf von `/avo`, `/avo/voice`, `/avo/intro`, `/settings/avo`, Siri, Widget, Deep Link)

| | DE | EN | Schlüssel |
|---|---|---|---|
| Titel | Avo ist ausgeschaltet | Avo is turned off | `avo_off_title` |
| Text | Schalte Avo ein, um Fragen zu stellen und mit Avo zu sprechen. | Turn on Avo to ask questions and talk to Avo. | `avo_off_body` |
| Knöpfe | Nicht jetzt · Einschalten (bevorzugt) | Not now · Turn on | `avo_not_now`, `avo_turn_on` |

„Einschalten“ schaltet das Modul und öffnet direkt das Ziel; „Nicht jetzt“ bleibt auf dem aktuellen Screen (bei einem
Deep Link auf Home). Gespräch und Einstellungen bleiben gespeichert, Hintergrund-KI (Kategorien, Zettel-Import) läuft
weiter. Wird das Modul ausgeschaltet, während man im Avo-Tab ist: Tab verschwindet, man landet auf Home.

### 11.2 Gespräch löschen

Titel „Gespräch löschen?“ / “Delete conversation?”; Text „Der Chat mit Avo wird von diesem iPhone gelöscht.“ / “Your
chat with Avo will be deleted from this iPhone.”; Knöpfe „Abbrechen“ / “Cancel”, „Löschen“ / “Delete” (destruktiv).
Schlüssel `avo_delete_conv_*`.

### 11.3 Kamera vor der Systemabfrage

Titel „Foto für Avo“ / “Photo for Avo”; Text „Avo braucht die Kamera für dieses Foto.“ / “Avo needs the camera for this
photo.”; Knöpfe „Nicht jetzt“ / “Not now”, „Weiter“ / “Continue” (dann Systemabfrage). Schlüssel `avo_camera_*`.

---

## 12. Querschnitt: Barrierefreiheit, Kontrast, Bewegung, Haptik

### 12.1 Kontrast (berechnet nach WCAG 2.1, D2-Werte)

| Paar | Verhältnis | nötig | Ergebnis | Maßnahme |
|---|---|---|---|---|
| Weiß auf #1F7A3A (Nutzer-Blase) | 5,38:1 | 4,5 | ok | |
| Weiß auf getöntem Glas 88 % über #F2F2F7 („Weiter“, „Eintragen“) | 4,35:1 | 4,5 | **zu wenig** | Kapseln mit Text: Deckkraft ab 0,92 (4,67:1) bzw. fest bei Reduce Transparency (Anfrage A) |
| #1F7A3A auf Weiß / auf #F2F2F7 (Textknöpfe) | 5,38 / 4,82 | 4,5 | ok | |
| #6C6C70 auf Weiß / #F2F2F7 / Glas über Grund | 5,23 / 4,69 / 5,03 | 4,5 | ok | |
| #6C6C70 Platzhalter auf Glas über grüner Blase bzw. dunklem Text (ohne Blur gerechnet) | 3,10 / 2,34 | 4,5 | **zu wenig** | Scroll-Kante unten hinter Eingabe und Tab-Leiste (2.11), Reduce Transparency fest |
| #6C6C70 auf Chip-Fläche über #F2F2F7 | 4,10 | 4,5 | knapp darunter | Chip-Text immer Grundtextfarbe (13,35:1), deaktivierte Chips mit Zusatz „braucht eine Verbindung“ |
| #FF3B30 als Text auf Weiß | 3,55 | 4,5 | **nie als Text** | Text-Rot #D70015 (5,38:1) für Text und destruktive Flächen mit Text |
| Weißes Symbol auf #FF3B30 (Sprachmodus beenden) | 3,55 | 3 (Symbol) | ok | bei „Kontrast erhöhen“ #D70015 |
| Abhak-Kreis #C7C7CC auf Weiß | 1,68 | 3 (Bedienelement) | **zu wenig** | Kreis-Token #8E8E93 (3,26:1) (Anfrage A) |
| Kalorien-Ring #E8833A auf Weiß / auf Spur #ECECF0 | 2,71 / 2,30 | 3 (Grafik) | **zu wenig** | Ring #B5420C (5,60:1, steht schon in D2), Wert immer zusätzlich als Text |
| Chip-Fläche gegen #F2F2F7 | 1,14 | nicht nötig (Text erkennt den Chip) | ok | bei „Kontrast erhöhen“ 1 pt Kante #8E8E93 |
| Pegel #1F7A3A auf #F2F2F7 | 4,82 | dekorativ | ok | |

D2 definiert nur hell. Dunkel, „Kontrast erhöhen“ und „Transparenz reduzieren“ leitet A in den Tokens ab; B nutzt nur
Tokens. Jede Prüfung läuft hell und dunkel.

### 12.2 Dynamic Type, Breiten, fetter Text

- Prüfmatrix (A-Gerüst `test/layout/`, B-Tests in `test/layout/screens/b/`): Breiten 320 × 568, 320 × 693, 375 × 667,
  390 × 844, 402 × 874, 440 × 956; Textgrößen L, xxxL, AX3, AX5; fett an/aus; hell/dunkel. Kontrast, Reduce Motion
  und Reduce Transparency je einmal bei 390, L. Prüfungen: keine Ausnahme, kein abgeschnittener Text
  (`didExceedMaxLines` false), `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, kein
  Spinner.
- Stapelregeln ab AX1: Figur aus (außer Sprachmodus, 8.4), Artikel- und Objektbilder aus, Kartenzeilen stapeln,
  Knopfpaare untereinander, Chips volle Breite, `NutritionRow` 2 × 2, Schalter unter den Text.
- `ProBadge`, Pille „0,99 € · Lidl“ und Markt-Punkt wachsen nur bis AX2. Große Zahlen höchstens 51 pt.
- 320 pt: nichts horizontal scrollen, nichts abschneiden; Trefferflächen bleiben 44.

### 12.3 Bewegung

- Federn nur aus `AppMotion` (A): Standard Dämpfung 1,0, Antwort 0,35 s für Einwachsen, Scrollen der Blase, Aufklappen;
  keine Federn mit Überschwingen (keine Geste mit Schwung im Avo-Bereich).
- Übergänge der Vollbild-Routen: Überblendung 250 ms, Sprachmodus mit wachsender Figur vom Knopf aus.
- Endlos-Animation nur im Zustand „denkt“ (Aktivitätszeichen, Schein im Sprachmodus).
- Reduce Motion: alles Verschieben und Skalieren wird Überblendung; Wort für Wort bleibt (Deckkraft).
- Leistung: Pegel 30 Hz nur mit `select` und `RepaintBoundary`; Streaming ohne Frames über 16 ms (Szenario in
  `integration_test/perf/b/`).

### 12.4 Haptik (über `AppHaptics` von A, im selben Frame wie das Bild)

| Ereignis | Haptik |
|---|---|
| Senden, Antwort, Öffnen, Karte erscheint, Widerrufen, Löschen | keine |
| Abhaken in einer Avo-Listenkarte | leichter Impuls |
| Zuhören beginnt (Sprachmodus) | leichter Impuls |
| „Einkauf gespeichert“, „Wochenplan auf der Liste“ | Erfolg |
| Allergen im Foto erkannt | Warnung, einmal |
| Fehlschlag (Fehler-Abschnitt, Fehler im Sprachmodus) | Fehler |

### 12.5 Rückgängig-Toasts

`UndoToast` von A, globaler Host über der Tab-Leiste, Aktion „Widerrufen“, sichtbar 4 s, mit VoiceOver oder
Schaltersteuerung 10 s, wird höflich angesagt, „Widerrufen“ ist eine eigene Aktion. Im Avo-Tab selbst nur für
„Neues Gespräch begonnen“; sonst stehen Änderungen als Karten mit „Widerrufen“ im Verlauf (ohne Zeitlimit, 24 h).

---

## 13. Konflikte D2 gegen Konzept und weitere Owner-Fragen

| Nr. | Thema | D2 | Konzept | Empfehlung |
|---|---|---|---|---|
| K1 | Wort für Undo | „Rückgängig“ | „Widerrufen“ | „Widerrufen“ (iOS-Standard auf Deutsch, Konzept-Texte sind verbindlich); A's `UndoToast` muss dasselbe Wort nutzen |
| K2 | Reihenfolge Text und Karte | Avo-Text vor der Karte | Ergebnis vor dem Text | Ergebnis zuerst: Die Karte ist fertig, bevor der Schlusstext streamt; Text über der Karte würde die Karte beim Streamen nach unten schieben |
| K3 | Figur bei Ernstem (Geld, Allergie, Fehler, Löschen) | Figur immer | keine Figur | Kopf-Figur bleibt (eine pro Bildschirmhöhe), aber ohne Freude oder Feiern; in Karten nie eine Figur |
| K4 | Steuerung Sprachmodus | Tastatur + Beenden | Stumm + Kamera + Beenden | vier Kreise: Tastatur, Kamera, Stumm, Beenden (Funktionen aus dem Konzept, Optik aus D2) |
| K5 | Modul Avo aus im Tab-Modell | 5 feste Tabs | Kreis wird Suche | Avo-Tab ausblenden (4 Tabs), Direktaufrufe zeigen Dialog 11.1 |
| K6 | Kopf | nur „Neuer Chat“ | Menü mit „Neues Gespräch“ und „Avo-Einstellungen“ | Glas-Gruppe mit „Neues Gespräch“ und „Mehr“ (Avo-Einstellungen) im D2-Toolbar-Muster |
| K7 | Begriff | „Neuer Chat“ | „Neues Gespräch“ | „Neues Gespräch“, passt zu „Gespräch löschen“ in den Einstellungen |
| K8 | Transkript | mittig, in Anführungszeichen, 24/30 Semibold | linksbündig, Title2 Regular | D2 (Optik), Funktion aus dem Konzept: max. 4 Zeilen, unsichere Wörter grau; Avos Antwort ohne Anführungszeichen, Regular |
| K9 | Sicherheit der Schätzung | | „ca. 80 % sicher“ | drei Stufen aus dem Plan (`recht_sicher`, `unsicher`, `grob`), keine Prozentzahl |
| K10 | Avo-Kern (Arbeits-Zeile, leerer Chat, Modul-Sheet) | echte Figur | Kern ohne Gesicht | Kern entfällt; Arbeits-Zeile mit drei Punkten, Kopf-Figur wechselt auf „überlegt“ |
| K11 | Globale Suche, Feld „Frag Avo oder suche“ | nicht vorhanden | `AskPanel` | Avo liefert keine Suche; Ort der Suche entscheidet A/Owner |

### Weitere Owner-Fragen aus diesem Bereich

| Nr. | Frage | Vorschlag |
|---|---|---|
| F1 | Pro-Zeile beim Tageslimit (Free 3 Fragen) höchstens einmal pro Woche, sonst nur der neutrale Satz? | ja (Fundament: ein Hinweis pro Funktion und Woche) |
| F2 | Wird der Sprachmodus Pro (F-16-3)? | offen mit A9; die Bühne kann beides (8.2) |
| F3 | Free-Nutzer sehen „Heute noch 1 Frage“ über der Eingabe und „Fragen heute · 2 von 3“ in den Einstellungen? | ja, bei nur 3 Fragen am Tag sonst überraschend |
| F4 | Allergie entfernen nur über die Rückfrage-Karte (F-16-4)? | ja |
| F5 | Rechtliche Prüfung: Einwilligung für Gesundheitsangaben an Anthropic (DSGVO Art. 9), Offenlegungstext 9.1, App-Store-Datenschutzangaben (F-16-5) | vor dem Start; bis dahin Schalter aus |
| F6 | Einwilligungen und „Intro gesehen“ im Konto speichern (Migration `user_preferences`) statt nur auf dem Gerät? | Konto |
| F7 | D2-Hinweiskarte im Sprachmodus nur in den ersten drei Sitzungen? | ja, danach bleibt der Bereich bis zum ersten Ergebnis leer |
| F8 | Info.plist-Texte (DE/EN) freigeben: Mikrofon „Avo hört zu, wenn du im Sprachmodus sprichst.“ / “Avo listens when you talk to it in voice mode.”; Spracherkennung „Damit Avo versteht, was du sagst, wird deine Stimme in Text umgewandelt.“ / “Your voice is turned into text so Avo understands what you say.” (Kamera mit B6 abstimmen) | freigeben |
| F9 | Gespräch nur lokal, 24 h, nicht geräteübergreifend (F-16-7); „Antworten im Chat vorlesen“ standardmäßig aus (F-16-8) | ja, ja |
| F10 | Langdruck auf den Avo-Tab startet den Sprachmodus? | ja, wenn A das in der Tab-Leiste anbietet (ab AX1 zeigt Langdruck dort den Large Content Viewer, dann nicht) |
| F11 | Figur im Sprachmodus ab AX1 klein (64 pt) statt ausgeblendet, weil sie die Haupttaste ist? | ja |

---

## 14. Datenquellen und Lücken

| Was | Quelle | Stand |
|---|---|---|
| Antworten streamen | `ClaudeService.streamAvo` / `cancelAvoStream` (`lib/data/services/claude_service.dart`), Events `AvoTextDelta`, `AvoMessageDone`, `AvoStreamError` | vorhanden |
| Werkzeug-Schleife, Werkzeuge, `propose_delete`, Einmal-Schlüssel | `AvoAssistantService` (B1.6) | Umbau offen |
| Gesprächsspeicher 24 h (einzige Quelle für UI und Modell-Verlauf), Rückgängig-Speicher mit Gegen-Aktion und Version | neu, B, über A's `LocalStore` | fehlt (L1) |
| KI-Kill-Switch, Angebote verfügbar | `aiRemoteEnabledProvider`, `offersAvailableProvider` (`app_flags_provider.dart`) | vorhanden |
| Module | `moduleEnabledProvider(AppModule.avo/offers/calories/mealPlan/costSplit)`, `appModulesProvider.notifier.setEnabled` (A) | vorhanden |
| Markt der Liste | `storeForListProvider(listId)` | vorhanden |
| Angebote pro Liste ausgeblendet | `offersVisibleForListProvider(listId)` | vorhanden |
| echte Region | `regionProvider` (B2.1) | fehlt (L2) |
| Ersparnis-Wortlaut | `offer_savings.dart` (B2.2, `formatOfferSummary`) | fehlt (L2) |
| Verbindungsstatus | `connectionStateProvider` (Kap. 20) | fehlt (L3) |
| Tageslimit, verbleibende Fragen | `ai_usage_daily_b` (RLS select own) + `app_flags.ai_limits` + `is_premium_user` | Provider fehlt (L4) |
| Einwilligungen, Stimme, Vorlesen, weiter zuhören, „Intro gesehen“ | neu `avoSettingsProvider` | Speicherort offen (L5) |
| Screen-Kontext | `avoScreenContextProvider` (B definiert, A schreibt) | Vertrag fehlt (Anfrage A) |
| Listen, Artikel, Schreiben | `listsNotifierProvider`, `itemsNotifierProvider`, `ItemRepository.addItems/undoAddItems` (A5) | teils vorhanden |
| Rezepte, Kochmodus | A-Dienste `RecipeToList`, `RecipeAdaptation`, Kochmodus-API | A |
| Fotos | `meal_photo_analysis_service`, `list_import_service` (Tasks `meal_photo`, `list_import`) | Umbau B1.7 |
| Kalorien, Wasser, Gewicht, Challenges | `nutrition_provider`, `food_log_service`, `water_log_service`, `weight_log_service`, `diet_challenge_service` | vorhanden |
| Workouts | `workout_log` (B6, Migration) | fehlt |
| Wochenplan | `meal_plan_*` (B7) | fehlt |
| Verlauf, Kosten teilen | `shopping_history_service`, `expense_split_service` | vorhanden |
| Stimme, Erkennung, Pegel | Kanal `shoply/voice` (Swift, B) | fehlt (L6) |
| Pro | `subscription_provider`, `proFeatureProvider(id)`, `ProGate.run` (A) | teils A |

Lücken:

- **L1** Gesprächs- und Rückgängig-Speicher brauchen A's `LocalStore`; bis dahin SharedPreferences-frei als Datei im
  Kontoordner (B), gedeckelt auf 24 h.
- **L2** `regionProvider` und `offer_savings.dart` fehlen; ohne sie zeigen Avo-Karten keine Ersparnis und keine
  Angebote (sicherer Standard).
- **L3** `connectionStateProvider` fehlt; bis dahin Offline erst nach fehlgeschlagenem Senden.
- **L4** **Quote zählt heute pro Aufruf der Edge Function** (`handler.ts` verbraucht eine Einheit pro Request). Die
  Werkzeug-Schleife läuft beim Client in mehreren Runden; mit Free 3 Fragen am Tag kann eine einzige Frage das Limit
  aufbrauchen. Nötig: Zählung pro Nutzer-Frage (erste Runde zählt, Folgerunden mit Werkzeug-Ergebnissen nicht, vom
  Server geprüft). Außerdem ein lesender Provider für „verbleibend“.
- **L5** Wo Einwilligungen gespeichert werden: Gerät oder Konto (`user_preferences`, Migration). Empfehlung Konto, weil
  „So arbeitet Avo“ einmal pro Konto gilt.
- **L6** `shoply/voice` fehlt; Registrierung in `AppDelegate.swift` gehört gerade einem anderen Workflow; Info.plist-
  Texte fehlen.
- **L7** `ClaudeService` meldet keinen Werkzeug-Start; die Arbeits-Zeile kann den Werkzeug-Text erst zeigen, wenn die
  App das Werkzeug ausführt (davor „Denkt nach“). Wünschenswert: Event `AvoToolUseStart(name)`.
- **L8** Kühlschrank-Fotos brauchen Bilder im `avo_chat`-Verlauf; die B1.6-Schnittstelle nennt das nicht.
- **L9** Widerrufen von Löschungen heißt Wieder-Einfügen (neue IDs, erneute Pushes); Kosten-teilen-Widerruf braucht
  eine Service-Methode, die es nicht gibt; Listen-Löschen bleibt endgültig.

---

## 15. Was Teil A liefern muss (fehlt im D2-Blatt oder braucht Festlegung)

Komponenten (nicht im D2-Blatt): `ToggleRow`, `NavRow`, `ValueRow`, `StatusRow`, `UndoToast` mit globalem Host
(4 s / 10 s mit VoiceOver, Aktion „Widerrufen“), `ProBadge`, `ProgressRing`, `NutritionRow`, `BarChart`, `Avatar`,
`AppMenu` (Pull-down), zentrierter Bestätigungsdialog, `Mascot`-Widget (Posen, `cacheWidth`, ab AX1 aus,
dekorative Semantik), Abschnittstitel in Großbuchstaben mit Semantik-Label in normaler Schreibung.

Varianten: Artikelzeile kompakt (56 hoch, Kreis 22, Bild 36 Radius 9, Trennlinie ab 88) wie in `X-Avo`;
Listenzeile ohne Chevron für Auswahl; Rezeptkarte als Zeile (Bild 56); Glas-Eingabekapsel als Variante des
Bottom-Accessory (44er Knopf links, Feld 1 bis 5 Zeilen, getönter 40er Knopf rechts mit drei Zuständen);
Glas-Gruppe mit zwei Knöpfen im Kopf eines Tab-Screens mit großem Titel und Scroll-Kante.

Tokens: getöntes Glas mit Text ab Deckkraft 0,92; Abhak-Kreis #8E8E93; Kalorien-Ring #B5420C; destruktive Flächen
#D70015; Warn-Token (Symbol ≥ 3:1); Dunkel, „Kontrast erhöhen“, „Transparenz reduzieren“ (Glas fest); Scroll-Kante
unten hinter schwebender Eingabe und Tab-Leiste.

Verträge: Avo-Tab ausblenden bei Modul aus (oder Owner-Entscheidung K5); Tab-Zustand „arbeitet“ und „neue Antwort“
aus einem B-Provider; `avoScreenContextProvider` beschreiben (Liste, Rezept mit Portionen, Kochschritt, Planwoche,
Kalorientag, Einstellungsseite); Navigations-Helfer „Ziel öffnen“ (Tab wechseln, Stapel bauen); `RoutePaths` für
`/avo/voice`, `/avo/intro`, `/settings/avo`, `/settings/avo/voice`; Deep-Link-Übersetzung mit Modul-Prüfung (Dialog
11.1) und `?prompt=` nur vorbefüllen; Profil-Zeile „Avo“ → `/settings/avo` nur mit Modul an; `pro_features`-Eintrag
für mehr Avo-Fragen und `ProGate.run(onUnlocked:)` zurück in den Avo-Tab; Route der Datenschutz-Seite;
Tastatur-Verhalten der Shell (Eingabe über der Tastatur, Tab-Leiste darunter); `AppHaptics` (leicht, Erfolg,
Warnung, Fehler); `ItemRepository.addItems/undoAddItems` und ein Wieder-Einfügen für widerrufene Löschungen.

---

## 16. Prüfliste für Screenshots

Jeder Punkt muss auf einem Screenshot (Simulator, 390 × 844 hell, wenn nicht anders genannt) sichtbar erfüllt sein.

**Avo-Tab**
- [ ] Großer Titel „Avo“ mit Figur 44 links, Glas-Gruppe rechts oben, keine zweite Figur auf derselben Höhe.
- [ ] Nutzer-Blase grün, rechts, Ecke unten rechts klein, höchstens 75 % breit.
- [ ] Ergebniskarte: Kopfzeile Objekt + „was passiert ist“, Detailzeilen mit Kreis, Bild 36, Menge rechts grau,
      Fuß mit „Liste öffnen“ und „Widerrufen“.
- [ ] Ergebnis steht vor dem Avo-Text (oder Owner hat K2 anders entschieden).
- [ ] Höchstens 2 Chips unter der jüngsten Antwort, kein Marktvergleich, kein `ProBadge`.
- [ ] Eingabe-Kapsel 12 pt über der Tab-Leiste, Platzhalter „Frag Avo …“, rechts Wellenform; mit Text Pfeil.
- [ ] Unter Eingabe und Tab-Leiste kein harter Inhalt direkt unter dem Platzhalter (Scroll-Kante sichtbar).
- [ ] Arbeits-Zeile mit drei Punkten und „Stopp“, Kopf-Figur „überlegt“.
- [ ] Offline: Statuszeile, Blase „Nicht gesendet · Erneut senden“, Chips deaktiviert.
- [ ] Tageslimit: neutraler Abschnitt, Free mit Pro-Zeile, Eingabe bleibt.
- [ ] Kill-Switch KI: Statuszeile, Feld deaktiviert, Verlauf lesbar.
- [ ] Kill-Switch Angebote und Modul Angebote aus: nirgends ein Angebot, kein Hinweis darauf.
- [ ] Kein englischer oder roher Fehlertext, kein Ausrufezeichen, kein Emoji.

**Leerer Chat**
- [ ] „Wie kann ich helfen?“, drei Vorschläge passend zum Herkunfts-Screen, Fußnote mit „Datenschutz“.
- [ ] Kontext-Kapsel über der Eingabe mit X; nach X andere Vorschläge.

**Karten**
- [ ] Angebotskarte sagt „laut Händler“ und „in deiner Region“, Ersparnis mit „ca.“, keine %-Angabe, kein
      Händlerbild; ohne Region nur „Postleitzahl festlegen“.
- [ ] Schätzungskarte mit „geschätzt“, „Richtwerte, kein ärztlicher Rat.“, zwei Knöpfe, nichts schon gespeichert.
- [ ] Kalorien-Ring dunkles Orange (#B5420C-Token), Wert auch als Text, über dem Ziel Symbol + „drüber“.
- [ ] Rückfrage-Karte: graues Mülleimer-Symbol, Titel mit Namen, Folge, „Abbrechen“ grau, „Löschen“ in #D70015;
      keine Figur in der Karte.
- [ ] Rückfrage-Karte abgelaufen: Knöpfe grau, „Diese Rückfrage ist abgelaufen. Frag noch einmal.“
- [ ] Allergie-Entfernen: Warn-Symbol, „Entfernen“.

**Sprachmodus**
- [ ] Keine Tab-Leiste, Figur 120 im grünen Schein, 8 Balken, „Avo hört zu“, Transkript mittig in „…“.
- [ ] Ergebnisbereich weiß, höchstens zwei Ergebnisse.
- [ ] Steuerung unten (vier Kreise oder D2-Variante laut K4), rot nur ohne Text.
- [ ] Vorab-Erklärung „Sprich mit Avo“ mit „Weiter“/„Nicht jetzt“ vor jeder Systemabfrage.
- [ ] Mikrofon abgelehnt: Statuszeile + „Stattdessen tippen“.
- [ ] 375 × 667 und 320 × 568: kompakte Bühne, Figur 64 oben links, nichts abgeschnitten.

**So arbeitet Avo, Einstellungen**
- [ ] Drei Zeilen, Schalter standardmäßig aus, Fußnote nennt Claude von Anthropic und den Server, „Weiter“ unten.
- [ ] Einstellungen: Abschnitte Stimme, Was Avo einbeziehen darf, Gespräch; „Gespräch löschen“ rot und zuletzt;
      kein `ProBadge`; keine Figur.
- [ ] Stimmenliste mit Haken, Probe-Knopf je Zeile, Fußnote zu weiteren Stimmen.

**Querschnitt (Matrix)**
- [ ] 320, 375, 390, 402, 440 pt: nichts abgeschnitten, kein horizontales Scrollen.
- [ ] AX3 und AX5: keine Figur (außer Sprachmodus klein), Zeilen gestapelt, Knöpfe untereinander, Blase volle Breite
      minus 48.
- [ ] Fetter Text: keine Umbrüche, die Zeilen sprengen.
- [ ] Dunkel und „Kontrast erhöhen“: alle Texte lesbar, Kreise und Ring sichtbar.
- [ ] „Transparenz reduzieren“: Eingabe, Glas-Knöpfe und Tab-Leiste fest, Kapseln mit Text in vollem Grün.
- [ ] Reduce Motion (Aufnahme): nur Überblendungen, Figur und Schein ohne Größenänderung.
- [ ] VoiceOver (Gerät): Fragen als Überschriften, „Avo:“ vor Antworten, „Widerrufen“ als Aktion, Rückfrage-Karte
      bekommt den Fokus, Trefferflächen alle 44.
