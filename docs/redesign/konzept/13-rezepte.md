# 13 Rezepte, Rezeptdetail, Erstellen und Kochmodus

Stand: 07.11.2026. Besitz: **Teil A** (Rezepte sind Kern). Teil B liefert nur die Slots für Angebote und Kalorien sowie die Avo-Werkzeuge (siehe 18.5 und E-07). Baut auf `00-grundlagen.md` (Verweise "00 Kap. x") und `01-navigation-und-struktur.md` ("01 Kap. x") auf. Ist-Zustand: `inventar/recipes-browse.md` ("Inv-B"), `inventar/recipes-detail.md` ("Inv-D").

Markierungen: **R-xx** = Screen-Nummer dieses Kapitels, **E-xx** = Ergänzung zum Fundament (gesammelt in Kapitel 21), **Q-xx** = offene Frage (Kapitel 20).

Inhalt: 1 Überblick · 2 Regeln für den ganzen Bereich · 3 Tab Rezepte · 4 Suche · 5 Kategorie und Ernährung · 6 Alle und Beliebt · 7 Ersteller · 8 Ersteller-Seite · 9 Gespeichert · 10 Meine Rezepte · 11 Entwürfe · 12 Rezeptdetail · 13 Zutaten auf Liste · 14 Varianten · 15 Kommentare · 16 Kochmodus · 17 Rezept-Editor · 18 Kleine Dialoge, Menüs und Slots · 19 Abläufe · 20 Offene Fragen · 21 Ergänzungen zum Fundament

---

## 1. Überblick

### 1.1 Screens dieses Bereichs

| Nr. | Screen | Route | Muster (01 Kap. 6) | Hauptfrage |
|---|---|---|---|---|
| R-01 | Tab Rezepte (Entdecken) | `/recipes` | Tab-Wurzel | Was koche ich? |
| R-02 | Suche im Tab | `/recipes?q=` | Zustand von R-01 | Welches Rezept, welche Zutat, welche Person meine ich? |
| R-03 | Kategorie bzw. Ernährung | `/recipes/category/:categoryId` | Push | Was gibt es hier, das zu mir passt? |
| R-04 | Alle Rezepte / Beliebt | `/recipes/all`, `/recipes/popular` | Push | Was gibt es insgesamt bzw. was kochen gerade viele? |
| R-05 | Ersteller | `/recipes/creators` | Push | Wessen Rezepte will ich sehen? |
| R-06 | Ersteller-Seite | `/author/:authorId` | Push im aktuellen Tab (als 4. Ebene: Sheet groß, 2.6) | Wer ist das, und will ich mehr von dieser Person? |
| R-07 | Gespeichert | `/recipes/saved` | Push | Was wollte ich nachkochen? |
| R-08 | Meine Rezepte | `/recipes/my` | Push | Was habe ich geschrieben, und wie kommt es an? |
| R-09 | Entwürfe | `/recipes/drafts` | Push | Wo war ich beim Schreiben stehen geblieben? |
| R-10 | Rezeptdetail | `/recipes/:recipeId`, `/recipe/:recipeId` | Push mit Zoom (als 4. Ebene: Sheet groß, 2.6) | Will ich das kochen, und was brauche ich dafür? |
| R-11 | Zutaten auf Liste | `/recipes/:recipeId/to-list` | Sheet mittel | Was davon muss ich kaufen, und auf welche Liste? |
| R-12 | Variante | `/recipes/:recipeId/variations/:variationId` (E-10) | Sheet groß | Was ist bei dieser Abwandlung anders, und will ich sie? |
| R-13 | Kommentare | `/recipes/:recipeId/comments` (E-10) | Sheet groß | Was sagen andere, die es gekocht haben? |
| R-14 | Kochmodus | `/recipes/:recipeId/cook` | Vollbild-Cover | Was mache ich jetzt gerade? |
| R-15 | Rezept-Editor | `/recipes/add` (`draftId`, `recipeId`, `variationOf`) | Vollbild-Cover | je Schritt eine (17) |

Höchstens drei Push-Ebenen (01 Kap. 6): Rezepte > Kategorie > Rezept. Varianten und Kommentare sind deshalb Sheets, nicht weitere Pushes. Der Kreis Rezept > Ersteller > Rezept würde die Grenze sprengen; die Regel dafür steht in 2.6.

### 1.2 Was der Bereich leisten soll

- **Täglich nützlich:** Der Tab beantwortet "Was koche ich heute?" in den ersten 400 pt, ohne Statistik und ohne Kachelwand. "Weiter kochen" und "Schnell unter 20 Min" sind die Alltagsabschnitte; Entdecken folgt darunter.
- **Ein Tipp von Rezept zu Liste:** Die getönte Glas-Kapsel "Zutaten auf Liste" ist die Hauptaktion des Details; das Sheet weiß schon, welche Liste, welche Portionen und welche Zutaten man hat.
- **Sicher bei Allergien:** Allergene werden zuverlässig erkannt, nie aus Platzgründen versteckt, und ein Ersatz enthält nie ein eigenes Allergen (2.3).
- **Kochen mit schmutzigen Händen:** schwarzer Kochmodus, 28-pt-Schritte, Wischen, Timer, Avo per Stimme ("Weiter", "Timer 10 Minuten").
- **Schreiben ohne Angst:** Der Editor speichert jede Eingabe automatisch, auf beiden Geräten desselben Kontos.

---

## 2. Regeln für den ganzen Bereich

### 2.1 Daten: sofort da, nie leer durch Fehler

| Regel | Umsetzung | behebt (Inventar) |
|---|---|---|
| Der Rezeptkatalog für den Tab kommt beim ersten Frame aus dem lokalen Stand (vor `runApp` vorgewärmt, 00 Kap. 13). | Lokale Datenbank statt JSON in SharedPreferences (Isolate, kein `jsonEncode` auf dem UI-Thread); gespeichert werden je Rezept nur die Felder für Karten (Titel, Foto-URL, `photo_color`, Zeiten, Portionen, Labels, Bewertung, Autor, Allergen-Tags). Detaildaten werden beim ersten Öffnen nachgeladen und dann ebenfalls gespeichert. | Inv-B 4.7 |
| Auch "Rezept der Woche", "Für dich", "Beliebt" und "Neu" sind gecacht; was sich ändert, ersetzt den alten Stand erst beim nächsten Öffnen des Tabs (wie Hinweis-Zeilen, 00 12.12). | Kein Abschnitt springt nachträglich ins Layout. | Inv-B 2.1 Laden |
| Ein Netzfehler überschreibt nie den lokalen Stand. | Services werfen Fehler (statt `[]` zu liefern); Provider behalten den letzten Stand und melden den Fehler als `StatusRow`. | Inv-B 4.1, 4.3, 4.5 |
| Eigene Änderungen (neues, geändertes, gelöschtes, bewertetes, gemerktes Rezept) wirken sofort überall. | Ein zentraler `RecipeStore` (Teil A) mit `select` je Rezept; Editor, Detail, Merken und Bewerten schreiben dort optimistisch hinein. `refreshRecipeData` ohne Wirkung entfällt. | Inv-B 4.2 |
| Der Katalog ist pro Nutzer geschlüsselt. | Kontowechsel leert Bewertung und Merk-Zustand. | Inv-B 4.6 |
| Server statt ganzer Tabelle. | Abschnitte über eigene Abfragen bzw. RPCs mit Limit (Rezept der Woche, Beliebt, Neu, Für-dich-Kandidaten, Suche); Bewertungen aggregiert in der Datenbank. | Inv-B 4.7, Inv-D 32 |
| Rezepte in App-Sprache zuerst. | `Recipe.language` = App-Sprache wird bevorzugt, andere Sprache erscheint in der Suche mit der Metazeile "Englisch" (Q-07). | Inv-B 4.6 |
| Aufrufe zählen ohne eigene Rezepte und höchstens einmal pro Tag und Person. | Server-RPC prüft. Die Zahl wird nirgends angezeigt. | Inv-D 34 |

### 2.2 Zahlen und Mengen

- Mengen über `intl` mit Locale: "1,5 l", "200 g", "½ TL", "2 EL". Brüche für ¼, ⅓, ½, ⅔, ¾ bei Einheiten TL, EL, Tasse, Stück und ohne Einheit; sonst Dezimalkomma mit höchstens einer Nachkommastelle.
- Runden beim Skalieren: Gramm und Milliliter auf 5 (unter 20 auf 1), Stück auf ½ (Eier auf ganze Stück, darunter Hinweis "aufgerundet"), Prisen und "nach Geschmack" werden nicht skaliert.
- Zutaten ohne Menge sind erlaubt ("Salz nach Geschmack", "Pfeffer"). Keine "0", kein doppeltes Leerzeichen (Inv-D 9, 10).
- Zeiten: "35 Min", ab 60 "1 Std. 10 Min". Bewertungen: "4,7" mit Anzahl in Klammern "(128)". Keine Aufrufzahlen.
- Zahlen, die sich ändern (Portionen, Mengen, Anzahl ausgewählter Zutaten), sind `RollingNumber` (00 12.15).

### 2.3 Personalisierung und Allergien (Responsibility)

Grundlage sind die Einstellungen unter "Ernährung & Allergien" (`/settings/diet`, 01 Kap. 4): Ernährungsweisen, Allergien und Unverträglichkeiten (die 20 Werte aus `AllergyType`), Schalter "Rezepte automatisch anpassen" (Standard an).

**Erkennung (neu, Teil A mit KI-Hilfe von Teil B):**
1. Jede Zutat bekommt beim Veröffentlichen bzw. Import Allergen-Tags auf Zutatenebene (Erweiterung der vorhandenen Tabelle `ingredient_diet_tags` um Allergene; neue Zutatennamen klassifiziert der KI-Dienst von Teil B über Claude, das Ergebnis wird gespeichert und gilt für alle).
2. Für noch nicht klassifizierte Zutaten gilt lokal ein Wortabgleich mit Wortgrenzen und Komposita-Listen in Deutsch **und** Englisch ("Ei", "Eier", "Eigelb", "egg"; nicht "Reis", "Weizen", "Eis"; "Kokosmilch" und "Hafermilch" sind keine Milch, "Erdnussbutter" ist keine Butter, aber Erdnuss). Ersetzt die heutige Teilstring-Suche (Inv-D 4.1, 1 bis 3).
3. Kann eine Zutat nicht geprüft werden ("Gewürzmischung", "Pesto", "Brühe"), heißt sie **ungeprüft**. Ungeprüfte Zutaten werden genannt, nie stillschweigend als sicher behandelt.

**Ersatz:**
- Ein Ersatz wird nur vorgeschlagen, wenn er kein eigenes Allergen enthält und keine eigene Ernährungsweise verletzt (heute `||` statt `&&`, Inv-D 4.1, 2). Gibt es keinen sicheren Ersatz, wird nichts ersetzt und der Hinweis sagt es.
- Je Zutat höchstens ein Ersatz, ohne Doppel-Einträge.
- Die angepasste Fassung gilt überall gleich: Detail, Zutaten auf Liste, Kochmodus, Wochenplan (B), Avo (B). Die Ersatz-Logik liegt in einem Dienst `RecipeAdaptation` (Teil A), den B nur aufruft (E-07).

**Anzeige (nie aus Platzgründen weglassen):**

| Ort | Passt | Angepasst | Enthält Allergen ohne Ersatz | Ungeprüft |
|---|---|---|---|---|
| `RecipeCard` (Metazeile bzw. Zeile darunter) | nichts (kein "Passend"-Abzeichen) | `leaf` + "Für dich angepasst" in `labelSecondary` | `exclamationmark.triangle.fill` + "Enthält Erdnuss" in `warning` | nichts auf der Karte |
| Rezeptdetail, oben unter der Metazeile | nichts | Hinweis "Für dich angepasst: 1 Zutat ersetzt" | Hinweis in `warning`-Symbol, Text `label` (12.2 Nr. 4) | Hinweis "2 Zutaten konnten nicht geprüft werden: Gewürzmischung, Pesto" |
| Zutatenzeile | normal | `arrow.left.arrow.right` + Unterzeile "statt Feta · wegen Laktose" | `exclamationmark.triangle.fill` in `warning` hinter dem Namen | `questionmark.circle` in `labelSecondary` |

- Das heutige Abzeichen "Passend" entfällt bewusst: Der Normalfall braucht keine Markierung, und ein grünes "Passend" würde Sicherheit versprechen, die ungeprüfte Zutaten nicht hergeben. Warnungen bleiben dafür auf jeder Karte (Inv-B 6).
- "Für dich" schließt Rezepte mit eigenen Allergenen **ohne** sicheren Ersatz aus (heute nur −5 Punkte, Inv-B 4.4). Kategorien, Suche und Ersteller-Seiten zeigen sie, aber gekennzeichnet; dort gibt es den Filter-Chip "Passt zu mir".
- **"Passt zu mir"** heißt: kein eigenes Allergen ohne sicheren Ersatz, und die Ernährungsweise ist erfüllt (direkt oder nach Anpassung). Ungeprüfte Zutaten schließen nicht aus; sie bleiben im Detail genannt.
- **Schalter "Rezepte automatisch anpassen" aus:** Detail und R-11 starten in "Original"; Karten zeigen kein "Für dich angepasst". Allergie-Warnungen bleiben unverändert sichtbar, sie hängen nicht an diesem Schalter.
- Fußnote im Detail bei jedem Allergie-Hinweis: "Angaben ohne Gewähr. Prüfe die Zutaten auf der Packung." (`footnote`, `labelSecondary`).
- Kein Maskottchen, kein Grün, keine Witze an Allergie-Hinweisen (00 3.3). Haptik "Warnung" einmal, wenn ein Allergen-Hinweis im Detail erstmals pro Rezept und Sitzung erscheint (00 Kap. 11).
- Texte ohne Emojis; Allergie-Namen aus den Übersetzungen (heute deutsche Texte und Emojis fest im Service, Inv-B 4.6, Inv-D 3.4).

**"Für dich" berechnen:** Ausschluss nach 2.3; dann Ernährungsweise (+), gekocht oder gemerkt ähnliche Rezepte (+), Rezepte gefolgter Ersteller (+), Bewertung und Frische; ohne Profil die bestbewerteten. Die Onboarding-Prioritäten (`app_priorities`) entfallen als Signal (K-22, F-14).

### 2.4 Module, Kill-Switch und Pro in diesem Bereich

| Modul / Zustand | Wirkung im Bereich |
|---|---|
| Kalorien aus | Keine kcal in Karten-Metazeilen; im Detail entfällt "Ins Tagebuch". Die `NutritionRow` im Detail bleibt (Rezeptinformation, Kern). |
| Kalorien an | kcal in Metazeilen ("35 Min · 2 Portionen · 540 kcal"); "Ins Tagebuch" als Zeile unter der `NutritionRow` und auf der Abschluss-Seite des Kochmodus (Slot `showLogRecipeSheet`, B). |
| Preise & Angebote an | Gelbe Schilder an Zutaten (Detail, R-11) und eine Zeile "3 Zutaten bei Lidl im Angebot" nur für den Markt der Ziel-Liste (Slots, E-06). |
| Angebote aus oder Kill-Switch | Schilder und Zeile entfallen ohne Lücke; beim Hinzufügen werden keine Angebotspreise an Artikel gehängt. |
| Einzel-Schalter (00 15.4) | Die Schilder im Rezept folgen dem Schalter "Angebote in Listen" und dem Listen-Schalter "Angebote für diese Liste ausblenden" der Ziel-Liste. |
| Ziel-Liste ohne Markt | Keine Schilder, keine Angebotszeile; kein Hinweis "Markt wählen" im Rezept (der gehört in die Liste). |
| Wochenplan an | Menüeintrag "Zum Wochenplan" im Detail (18.1). |
| Avo an/aus | Keine Avo-Knöpfe im Bereich (01 Kap. 3). Der Avo-Kreis bleibt im Tab, im Detail und im Kochmodus; aus = Lupe (globale Suche). |
| Pro | Was Pro wird, entscheidet der Owner (F-05, F-10). Jede Rezept-Funktion lässt sich mit `ProBadge` und echter Vorschau sperren (16.6 für den Kochmodus). Angebote nie Pro. |
| Funktions-Status `hidden` | Varianten (14) und Kommentare (15) bleiben `hidden`, bis Melden und Blockieren serverseitig fertig sind (App Review 1.2, Q-01). |

### 2.5 Bewegung, Haptik und Glas im Bereich

- Zoom Rezeptkarte zu Detail mit `springMorph`, Zurück-Wischen schrumpft unterbrechbar zur Karte (00 10.2). Gilt von jeder `RecipeCard` aus (Tab, Kategorie, Gespeichert, Ersteller, Suche, Wochenplan B). Ist die Ursprungskarte nicht mehr sichtbar (z. B. Deep Link), normaler Push.
- Merken: `bookmark` füllt sich mit `springQuick`, ohne Haptik (normaler Knopf, 00 Kap. 11); der Zustandswechsel des Symbols ist die Rückmeldung. Kein Hinweis-Toast beim Merken (heute Snackbar, Inv-D 3.1).
- Stepper (Portionen): Auswahl-Haptik pro Schritt, Mengen rollen (`springDigits`).
- Glas pro Screen (00 8.5, höchstens 3): Tab Rezepte = Tab-Bar mit Avo-Kreis + Toolbar oben; Detail = Tab-Bar + Toolbar oben (clear) + Aktionsleiste; Kochmodus = Toolbar oben + Steuerung unten + Avo-Kreis (E-01).
- Öffnet ein Sheet in Teilhöhe über einer schwebenden Leiste (Aktionsleiste im Detail, Steuerung im Kochmodus), wird diese Leiste aus dem Baum genommen, solange das Sheet offen ist (00 8.4). Menüs aus einer Leiste ersetzen sie optisch, sie liegen nicht darauf.

### 2.6 Tiefe der Navigation (E-18, Q-15)

Ebene 1 ist die Tab-Wurzel, Ebene 2 eine Sammelseite (R-03 bis R-09) oder ein Detail, Ebene 3 ein Detail oder eine Ersteller-Seite. Eine 4. Ebene wird nicht gepusht:

- Würde ein Rezeptdetail oder eine Ersteller-Seite auf Ebene 4 entstehen (z. B. Rezepte > Mediterran > Ofengemüse > Mara Köhler), öffnet es als `AppSheet` groß mit eigenem Stapel aus höchstens zwei Ebenen (01 Kap. 6: Sheets stapeln höchstens zweimal). Im Sheet gilt derselbe Aufbau; die Aktionsleiste sitzt unten im Sheet auf fester Fläche (großes Sheet = kein Glas-Hintergrund, also kein Glas auf Glas); Tab-Bar und Avo-Kreis sind verdeckt (01 Kap. 3).
- Im Sheet ist der Rückweg in die Gegenrichtung nicht tippbar: Ein Rezept, das aus einem Ersteller-Sheet kam, zeigt die Autorzeile ohne Chevron. So entsteht keine Endlosschleife.
- Deep Links bauen nie mehr als Wurzel + Ziel (01 Kap. 6).

### 2.7 Große Schrift im ganzen Bereich

Gilt zusätzlich zu den Abschnitten "Große Schrift und 320 pt" der einzelnen Screens (00 6.3, 6.4):
- Ab AX1 werden alle `InsetSection`s randlos (`bgPlain`, Zeilen über die volle Breite), Rezept-Raster einspaltig mit `RecipeCard` groß, Mengen rutschen unter den Namen, zwei Buttons nebeneinander stehen untereinander, Maskottchen in leeren Zuständen entfällt.
- Beschriftungen in schwebenden Glas-Kapseln (Aktionsleiste, Kochmodus-Steuerung, Toolbar-Text-Kapseln) wachsen bis xxxL und bleiben dann auf dieser Größe; ab AX1 zeigt Langdruck sie im Large Content Viewer (E-19, wie die Tab-Beschriftungen in 00 5.3).
- Nirgends steht Text in einer festen Höhe; alle Zeilen haben nur Mindesthöhen (`rowMinHeight` 44).

---

## 3. R-01 Tab Rezepte (Entdecken)

**Zweck:** "Was koche ich?" Man kommt über den Tab, über Siri ("Such Rezepte mit Feta"), über das Rezept-Widget-Leerfeld und nach dem Veröffentlichen eines Rezepts hierher.

### 3.1 Aufbau von oben nach unten

1. **`LargeTitleNavBar`, Variante Tab-Wurzel:** großer Titel "Rezepte", rechts in der Titelzeile der Profil-Avatar (36 pt, kein Glas). Obere Zeile rechts eine `GlassToolbar` mit `plus` ("Neues Rezept", öffnet R-15).
2. **`SearchField`** im Inhalt: Platzhalter "Rezepte, Zutaten, Ersteller". Scrollt mit.
3. **Tipp-Zeile** (einmalig, nur ohne Ernährungsprofil, `HintRow`-Form, E-11): `leaf` + "Ernährung und Allergien einstellen. Rezepte passen sich daran an." rechts schlicht "Einstellen". Wegwischen = nie wieder. Ersetzt den Dialog nach 1,2 s (Inv-B 2.11).
4. **Weiter kochen** (nur, wenn ein Kochfortschritt jünger als 24 h existiert, `HintRow`-Form): Thumbnail 28 pt mit `radiusPhotoS`, "Weiter bei Schritt 3: Ofengemüse mit Feta", `chevron.right`. Tippen öffnet direkt R-14 an dieser Stelle. Es gibt höchstens eine `HintRow` pro Screen (E-11): Sind Tipp-Zeile (3) und "Weiter kochen" beide fällig, steht nur "Weiter kochen"; die Tipp-Zeile wartet auf ein späteres Öffnen.
5. **Hero "Rezept der Woche":** `RecipeCard` Variante Hero, 16:10, randlos über die volle Breite innerhalb von `pageMargin` mit `radiusCard`, Titel `title2` in `labelOnPhoto` auf Verlauf, darüber in `subheadline` "Rezept der Woche" (gemischte Schreibweise, kein Kicker in Großbuchstaben), darunter Metazeile auf dem Foto "35 Min · von Mara Köhler". Kein Text "Zur Liste" mehr (falsche Affordance, Inv-B 3.2). Rechts unten auf Höhe der Metazeile ein `bookmark`-Knopf (44-pt-Ziel, Symbol `labelOnPhoto`, kein Glas). Er sitzt bewusst im Verlauf am unteren Rand, weil Weiß oben auf einem hellen Foto keinen Kontrast hätte (00 9.6).
6. **Für dich** (Sektionstitel `headline`, ohne "Alle anzeigen"; eine Sammelseite "Alle Empfehlungen" würde der Hälfte-Regel widersprechen): waagerechte Foto-Reihe aus `RecipeCard` klein (160 pt breit, Foto 4:3, Titel 2 Zeilen, Meta `caption1`), 12 pt Abstand, 6 Karten, die nächsten 2 Fotos vorgeladen. Seitenrand links `pageMargin`, Karten rasten nicht ein (freies Scrollen wie App Store "Für dich").
7. **Kategorien:** eine waagerecht scrollende Zeile `FilterChip`s ohne Emojis und ohne Farben: "Schnell", "Vegetarisch", "Mediterran", "Asiatisch", "Italienisch", "Suppen", "Frühstück", "Gesund", "Comfort Food", "Mexikanisch", "Meeresfrüchte", "Desserts & Snacks". Tippen pusht R-03. Ab xxL `Wrap` (00 12.19).
8. **Schnell unter 20 Min:** `InsetSection` mit 3 `RecipeCard` Zeilen (Thumbnail 56 pt, Titel `headline`, Meta `subheadline`), Sektionsfuß schlicht "Alle schnellen Rezepte" (pusht R-04 "Alle Rezepte" mit aktivem Filter "Unter 20 Min"; Grundlage ist die Gesamtzeit, nicht das Label `quick`).
9. **Beliebt diese Woche:** Rangliste wie die Charts im App Store: waagerecht blätternde Spalten zu je 3 Rang-Zeilen (Rang in `numberL` `labelSecondary`, Thumbnail 56 pt, Titel, Meta), Spaltenbreite = Bildschirmbreite minus 48 pt, damit die nächste Spalte anschaut (E-02). "Alle anzeigen" pusht R-04 Beliebt.
10. **Neu:** kleines Raster, 2 Spalten, höchstens 6 `RecipeCard` klein in Rasterbreite (E-02); "Alle anzeigen" pusht R-04 Alle.
11. **Ersteller:** Avatar-Reihe (Avatar 64 pt, Name `footnote` `label` bis 2 Zeilen, darunter "24 Rezepte" `caption1` `labelSecondary`), gefolgte Ersteller zuerst mit 8-pt-Punkt `action` bei neuen Rezepten seit dem letzten Besuch; "Alle anzeigen" pusht R-05.
12. **Deine Rezepte:** `InsetSection` mit `NavRow`s: `bookmark` "Gespeichert" (Wert "12"), `square.and.pencil` "Meine Rezepte" (Wert "3"), `doc.text` "Entwürfe" (Wert "2", nur wenn vorhanden). Die Werte sind echte Anzahlen eigener Dinge, keine Vanity-Zahlen.
13. Unterer Inhaltsabstand `bottomContentInset`; Scroll-Edge-Verlauf hinter der Tab-Bar.

Entfällt: Statistik-Banner, 2 × 2-Kacheln, Emoji-Kategorie-Raster, Kicker in Großbuchstaben, Glas-Suchkapsel im Kopf (01 5.4).

**Hälfte-Regel und Ausschlüsse bleiben** (Inv-B 6): kein Abschnitt zeigt alle Rezepte; Rezept der Woche erscheint nicht in "Für dich" und "Beliebt"; "Für dich" schließt "Beliebt" aus. Hat der Katalog weniger als 8 Rezepte, entfallen "Beliebt" und "Neu" ganz.

### 3.2 Beispielinhalt

Rezept der Woche "Ofengemüse mit Feta" (35 Min, von Mara Köhler, 4,7 (128)). Für dich: "Linsen-Dal mit Spinat · 30 Min", "Shakshuka · 25 Min", "Zitronen-Hähnchen aus dem Ofen · 50 Min", "Gnocchi mit Salbeibutter · 20 Min". Schnell unter 20 Min: "Pasta aglio e olio · 15 Min · 2 Portionen", "Avocado-Toast mit Ei · 10 Min · 1 Portion", "Gurkensalat mit Sesam · 10 Min · 2 Portionen". Beliebt: "1 Shakshuka", "2 Linsen-Dal mit Spinat", "3 Ofengemüse mit Feta", "4 Kürbissuppe mit Ingwer", "5 Spaghetti Bolognese", "6 Pfannkuchen". Ersteller: Mara Köhler (24 Rezepte), Deniz Aydın (17), Sophie Brandt (11), Jonas Meier (9). Deine Rezepte: Gespeichert 12, Meine Rezepte 3, Entwürfe 2.

### 3.3 Zustände

| Zustand | Verhalten |
|---|---|
| Erster Start, Katalog noch nie geladen | Nur dann ein Skelett in Form der Abschnitte (Hero-Fläche, 3 Kachel-Flächen, 3 Zeilen) als ruhige Tonflächen `fill`, ohne Schimmer, bis zur ersten Antwort (00 Kap. 13). Kein Spinner, kein "Rezepte werden geladen ...". |
| Laden mit lokalem Stand | Alles sofort aus dem Cache; Abgleich im Hintergrund; neue Abschnittsinhalte erst beim nächsten Öffnen. Fotos: `photo_color`-Fläche ab dem ersten Frame, Foto blendet in 0,2 s darüber (`fadeReduced`). |
| Leer (Katalog leer, z. B. neue Sprache) | Hero und Rang-/Raster-Abschnitte entfallen. `EmptyState` (zufrieden, 96 pt; "suchend" gehört zu Suchen ohne Treffer, 00 3.3): "Noch keine Rezepte in dieser Sprache." Aktion prominent "Erstes Rezept schreiben". "Deine Rezepte" bleibt. |
| Keine eigenen Rezepte | Sektion "Deine Rezepte" zeigt nur "Gespeichert" (Wert leer) und "Meine Rezepte"; "Entwürfe" fehlt. |
| Fehler beim Abgleich | Inhalt bleibt; `StatusRow` unter dem Titel "Rezepte konnten nicht aktualisiert werden. Erneut versuchen". |
| Offline | `StatusRow` "Offline. Du siehst gespeicherte Rezepte." Fotos aus dem Bild-Cache, sonst `photo_color` bzw. Typo-Karte; Suche nur lokal. Der Cache wird nicht geleert (Inv-B 4.1). |
| Modul Kalorien aus/an | kcal in Metazeilen aus/an (2.4). |
| Pro gesperrt | Im Tab nichts; Sperren erscheinen erst an der Funktion. |

### 3.4 Interaktionen, Bewegung, Haptik

- Tippen auf eine Karte: Zoom ins Detail (`springMorph`); Zurück-Wischen schrumpft zur Karte. Reduce Motion: Überblendung.
- Langdruck auf eine Karte: `AppMenu` mit Vorschau des Rezepts (Systemmuster): "Merken"/"Nicht mehr merken", "Zutaten auf Liste" (öffnet R-11 direkt), "Zum Wochenplan" (Modul), "Teilen".
- `bookmark` auf Karten: Zustandswechsel mit `springQuick`, keine Haptik, kein Toast; VoiceOver sagt "Gemerkt".
- Pull-to-Refresh: Systemverhalten (`CupertinoSliverRefreshControl`), gleicht ab, Inhalt bleibt.
- Erneutes Tippen auf den Tab: zur Wurzel, dann nach oben (01 2.1).

### 3.5 Große Schrift und 320 pt

- 320 pt: Hero bleibt 16:10 über die volle Breite (288 pt); Foto-Reihe zeigt knapp zwei Karten (304 pt sichtbar: 160 + 12 + 132 pt der zweiten); Rangspalten 272 pt breit; Raster "Neu" wird **einspaltig** mit Karten "Zeile" statt kleiner Kacheln (00 6.3: Rezept-Raster 1 Spalte); Ersteller-Avatare 64 pt bleiben.
- Hero: Sobald "Rezept der Woche", Titel und Metazeile mehr als ein Drittel der Fotohöhe bräuchten (gemessen, in der Regel ab xxL, auf 320 pt früher), wandern sie unter das Foto auf `surface`; das Lesezeichen geht mit. Das Foto bleibt 16:10.
- Ab AX1: Foto-Reihe wird zu `RecipeCard` groß untereinander (höchstens 3, dann "Alle anzeigen"); Rangliste wird eine senkrechte Liste mit 5 Zeilen; Chips umbrechen; Ersteller-Reihe wird zu `ListRow`-ähnlichen Zeilen (Avatar 36, Name, Anzahl). Maskottchen im leeren Zustand entfällt.
- Kacheln haben keine feste Höhe (heute 210 pt, Inv-B 3.3): die Höhe ergibt sich aus Foto 4:3 plus Text; alle Kacheln einer Reihe bekommen die Höhe der höchsten (gemessen einmal je Textgröße, nicht pro Frame).

### 3.6 Was sich ändert, betroffene Dateien

Neu aufgebaut: `recipes_screen.dart` (Kopf als `LargeTitleSliver`, Abschnitte neu), `recipes_home_widgets.dart` (ersetzt durch `RecipeCard`, `FilterChip`, `InsetSection`, Rang-Variante), `recipes_home_data.dart` (Abschnittslogik serverseitig bzw. Store), `recipe_personalization.dart` (2.3), `recipe_image_card.dart`, `recipe_grid_card.dart`, `recipe_state_views.dart` (entfallen), `recipes_provider.dart`, `saved_recipes_provider.dart`, `recipe_service.dart` (Fehler werfen), `offline_cache_service.dart` (Rezepte), `recipe_features_service.dart` (Rezept der Woche serverseitig), `recipe_categories.dart` (Emojis, Farben raus), `contextual_prompt_service.dart` (Diät-Dialog raus), `DynamicTutorialService`-Schlüssel raus (K-21).

### 3.7 Bildbeschreibung für ChatGPT

iPhone-17-Pro-Screen im hellen Modus, Hintergrund #F2F2F7, gestaltet wie eine vorinstallierte Apple-App aus iOS 27 mit SF Pro. Oben der große fette Titel "Rezepte" linksbündig, rechts daneben ein runder Profil-Avatar 36 pt, darüber rechts ein kleiner runder milchiger Liquid-Glass-Knopf mit Plus. Darunter ein graues Kapsel-Suchfeld #E9E9EE mit Lupe und dem Platzhalter "Rezepte, Zutaten, Ersteller" in #636366. Dann eine große randlose Foto-Karte im Format 16:10 mit 20 pt Eckenradius: Ofengemüse mit Feta auf einem Blech, unten ein dunkler Verlauf, darauf in Weiß #FFFFFF klein "Rezept der Woche", groß und fett "Ofengemüse mit Feta" und "35 Min · von Mara Köhler", unten rechts auf Höhe dieser Zeile ein weißes Lesezeichen-Symbol. Darunter die Sektion "Für dich" mit fettem schwarzem Titel in gemischter Schreibweise, darunter eine waagerecht scrollende Reihe kleiner weißer Karten #FFFFFF mit 20 pt Radius und 4:3-Essensfotos ("Linsen-Dal mit Spinat · 30 Min", "Shakshuka · 25 Min"), die zweite Karte am rechten Rand angeschnitten. Dann eine Reihe grauer Kapsel-Chips #E9E9EE mit schwarzem Text ohne Emojis ("Schnell", "Vegetarisch", "Mediterran", "Asiatisch") und eine weiße Sektion mit 26 pt Radius "Schnell unter 20 Min" mit drei Zeilen aus quadratischem Thumbnail, fettem Rezeptnamen und grauer Metazeile. Ganz unten schwebt eine milchige Glas-Tab-Bar mit "Liste", "Rezepte" (ausgewählt, grün #3F7A1F), "Plan" und abgesetzt rechts ein runder Glas-Knopf mit einer kleinen braunen Kugel #7A4A24 in hellgrünem Ring #C9DE6E; kein Maskottchen, keine Großbuchstaben-Überschriften, keine Statistik.

---

## 4. R-02 Suche im Tab

**Zweck:** "Welches Rezept, welche Zutat, welche Person meine ich?" Einstieg: Tippen ins Suchfeld von R-01, Siri-Suche (`/recipes?q=`), Deep Link `shoply://recipes/search?q=`. Die globale Suche im Avo-Feld (01 Kap. 9) zeigt Rezepte als eine Sektion und führt mit "Alle Rezept-Treffer" hierher.

### 4.1 Aufbau

1. Bei Fokus gleitet das Suchfeld unter die obere Zeile, der große Titel klappt ein (`springStandard`), rechts erscheint schlicht "Abbrechen". Tab-Bar verschwindet mit der Tastatur (00 6.5).
2. **Vor dem ersten Buchstaben:** Sektion "Zuletzt gesucht" (bis 5 `NavRow`s mit `clock.arrow.circlepath`, Wischen löscht einzeln, Sektionsfuß schlicht "Verlauf löschen"), darunter Sektion "Ernährung" als Chips (Vegetarisch, Vegan, Glutenfrei, Low Carb, Gesund; mit Ernährungsprofil zusätzlich "Passt zu mir"). Die Chips nutzen die vorhandenen Labels (`vegetarian`, `vegan`, `gluten-free`, `low-carb`, `healthy`) und pushen R-03; "Passt zu mir" pusht R-04 "Alle Rezepte" mit diesem Filter. Ein Chip "Proteinreich" entfällt, weil es dafür kein Label und keine verlässliche Datengrundlage gibt.
3. **Mit Text**, Sektionen in dieser Reihenfolge, leere entfallen:
   - "Rezepte" (`RecipeCard` Zeilen, sortiert nach Relevanz: Titeltreffer vor Zutatentreffer vor Beschreibung, dann Bewertung); lokale Treffer sofort, Server-Treffer entprellt 300 ms **unten angefügt**, nie oben eingeschoben.
   - "Mit Zutat" (ab 3 Zeichen und wenn eine Zutat passt): Zeile "Rezepte mit Feta" mit Wert "14" → R-03 im Modus Zutat (E-10, Route `/recipes/category/ingredient:feta`).
   - "Kategorien" und "Ernährung" als Chips (ab 2 Zeichen).
   - "Ersteller" (bis 3 Zeilen mit Avatar 28, Name, "24 Rezepte"), "Alle Ersteller" schlicht.
4. Treffer sind Server-Volltext (RPC, Teil A) über Name, Beschreibung, Zutaten, Labels und Autor; der Platzhalter verspricht keine allgemeine Personensuche mehr (Inv-B 3.4).

### 4.2 Beispielinhalt

Eingabe "feta": Rezepte "Ofengemüse mit Feta", "Griechischer Salat", "Spinat-Feta-Taschen", "Wassermelone mit Feta und Minze"; Mit Zutat "Rezepte mit Feta · 14"; Ersteller keine.

### 4.3 Zustände

- **Keine Treffer:** `EmptyState` suchend: "Nichts gefunden für „Halloumi-Burger“." Satz: "Versuch es mit einer Zutat, zum Beispiel „Halloumi“." Aktion schlicht "Eigenes Rezept schreiben" (öffnet R-15 mit dem Namen vorbefüllt). Kein Avo-Knopf (01 Kap. 3).
- **Lädt:** nie sichtbar; lokale Treffer stehen sofort, Server-Treffer kommen unten dazu.
- **Offline:** `StatusRow` "Offline. Es werden nur gespeicherte Rezepte durchsucht."
- **Fehler der Server-Suche:** lokale Treffer bleiben; Sektionsfuß unter "Rezepte": "Weitere Treffer konnten nicht geladen werden. Erneut versuchen".
- **Siri-Aufruf bei lebendem Tab:** setzt den Suchtext bei jedem neuen `?q=` (heute nur in `initState`, Inv-B 4.6).

### 4.4 Interaktionen

Return schließt die Tastatur und lässt Ergebnisse stehen. Wischen nach unten in den Ergebnissen schließt die Tastatur. "Abbrechen" leert die Suche, der Titel klappt wieder auf. Keine Haptik.

### 4.5 Große Schrift und 320 pt

Rezept-Zeilen stapeln ab AX1: Thumbnail entfällt, Titel umbricht, Meta darunter. "Abbrechen" bleibt neben dem Feld bis xxxL, ab AX1 unter dem Feld rechtsbündig. Chips `Wrap`.

### 4.6 Was sich ändert

`recipes_search_results.dart` wird Teil des neuen Tabs (Sektionen statt Raster, `ListTile` und Emoji-Chips entfallen); `searchRecipesLocally` bleibt als lokaler Sofort-Teil (im Isolate statt auf dem UI-Thread, Inv-B 4.7), ergänzt um Server-RPC; Entprellung 300 ms (heute 250 ms) wie 00 12.25. Router-Redirect in `app_router.dart` reicht `shoply://recipes/search?q=` und `shoply://recipes/saved` an die richtigen Ziele weiter statt auf `/home` (Inv-B 4.6).

### 4.7 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, Tastatur offen unten. Oben ein graues Kapsel-Suchfeld #E9E9EE mit Lupe und dem eingetippten Wort "feta", daneben grüner Text "Abbrechen" #3F7A1F, der große Titel ist eingeklappt. Darunter eine fette Sektionsüberschrift "Rezepte" und eine weiße Sektion mit 26 pt Radius mit vier Zeilen: quadratisches Foto-Thumbnail mit 12 pt Radius, fetter Name ("Ofengemüse mit Feta", "Griechischer Salat", "Spinat-Feta-Taschen", "Wassermelone mit Feta und Minze") und graue Metazeile #636366 ("35 Min · 2 Portionen"). Darunter eine Sektion "Mit Zutat" mit einer Zeile "Rezepte mit Feta" und rechts grau "14" mit Chevron. Keine Emojis, keine Farbflächen hinter Symbolen, Text schwarz.

---

## 5. R-03 Kategorie- und Ernährungsseite

**Zweck:** "Was gibt es hier, das zu mir passt?" Einstieg: Kategorie-Chip in R-01, Ernährungs-Chip in R-02, "Rezepte mit Feta".

### 5.1 Aufbau

1. `LargeTitleNavBar` Push: großer Titel "Mediterran" (bzw. "Vegetarisch", "Rezepte mit Feta"), Zurück "Rezepte". Toolbar rechts `arrow.up.arrow.down` (Sortieren-Menü: "Beliebt" (Standard), "Neu", "Schnellste zuerst", "Beste Bewertung"; aktuelle mit `checkmark`).
2. Metazeile unter dem Titel (`subheadline`, `labelSecondary`): "38 Rezepte", mit aktivem Filter "17 von 38 Rezepten" (Zahl als `RollingNumber`).
3. Filterzeile `FilterChip`s, nur Chips, die in der Menge vorkommen: "Passt zu mir" (nur mit Ernährungsprofil), "Unter 20 Min", "Bis 30 Min" (beide aus der Gesamtzeit), "Einfach", "Mittel", "Anspruchsvoll" (Labels `easy`, `medium`, `advanced`; Anzeige "Anspruchsvoll" statt heute "Fortgeschritten", passend zum Editor 17.4), "Vegetarisch", "Vegan", "Glutenfrei", "Gesund"; am Ende schlicht "Zurücksetzen", sobald ein Filter aktiv ist. Mehrfachauswahl, UND-Verknüpfung (00 12.19). Die Zuordnung nutzt exakte Label-IDs auf beiden Seiten (heute Teilstring gegen Gleichheit, Inv-B 4.6).
4. Raster 2 Spalten `RecipeCard` klein in Rasterbreite (E-02), 16 pt Spaltenabstand, 24 pt Zeilenabstand, Allergie-Zeile auf jeder Karte, wo zutreffend.

### 5.2 Beispielinhalt

"Mediterran · 38 Rezepte"; Nutzerin mit Laktoseintoleranz, "Passt zu mir" vorausgewählt, dazu "Bis 30 Min" aktiv → "17 von 38 Rezepten"; Karten "Shakshuka · 25 Min", "Griechischer Salat · 15 Min", "Pasta mit Zitrone und Ricotta · 20 Min" mit Zeile "Für dich angepasst". "Ofengemüse mit Feta · 35 Min" fehlt (zu lang). Wählt sie "Passt zu mir" ab, erscheinen auch Karten mit "Enthält Milch" in `warning`.

### 5.3 Zustände

- **Leer (Kategorie ohne Rezepte):** `EmptyState` suchend "In „Suppen“ gibt es noch keine Rezepte." Aktion schlicht "Rezept schreiben".
- **Leer durch Filter:** an Stelle des Rasters ein Satz "Keine Rezepte mit diesen Filtern." und schlicht "Filter zurücksetzen".
- **Laden:** aus dem Katalog-Cache sofort; Rest der Menge (über Paging vom Server) wird beim Scrollen unten angefügt.
- **Fehler, offline:** `StatusRow` unter dem Titel; vorhandene Karten bleiben.
- **Filter-Zustand** gilt nur für diesen Besuch (heute bleibt er bis zum App-Neustart, Inv-B 4.6). Ausnahme: "Passt zu mir" ist vorausgewählt, wenn man ein Allergieprofil hat (Q-09).

### 5.4 Interaktionen

Chip an/aus mit `springQuick`; das Raster passt sich mit `springStandard` an (Karten blenden aus, Nachbarn rücken nach), keine Haptik. Sortieren-Menü wächst aus dem Knopf (`springMenu`).

### 5.5 Große Schrift und 320 pt

320 pt: einspaltig mit `RecipeCard` Zeile. Ab AX1: einspaltig mit `RecipeCard` groß (Foto über dem Titel in voller Breite, 00 6.4). Raster ohne festes Seitenverhältnis (heute 0,75 und `Spacer`, Inv-B 3.3).

### 5.6 Was sich ändert

`category_recipes_screen.dart`: Material-`AppBar` → `LargeTitleSliver`; Chip-Leiste ohne feste 52 pt; `_categoryFiltersProvider` wird `autoDispose`; `categoryRecipesProvider` mit exakten Labels und Paging.

### 5.7 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7. Oben links ein runder milchiger Glas-Knopf mit Chevron nach links, oben rechts ein runder Glas-Knopf mit zwei Pfeilen hoch und runter. Großer fetter Titel "Mediterran", darunter grau #636366 "17 von 38 Rezepten". Eine Reihe Kapsel-Chips: "Passt zu mir" und "Bis 30 Min" ausgewählt (hellgrüne Fläche #EEF5E4, grüner Text #3F7A1F mit kleinem Häkchen), weitere grau #E9E9EE mit schwarzem Text ("Einfach", "Vegetarisch"), am Ende grüner Text "Zurücksetzen". Darunter ein zweispaltiges Raster weißer Karten #FFFFFF mit 20 pt Radius, oben je ein 4:3-Essensfoto, darunter fetter zweizeiliger Name und graue Zeile "25 Min · 2 Portionen"; eine Karte ("Pasta mit Zitrone und Ricotta") trägt eine dritte Zeile mit kleinem grauem Blatt-Symbol und grauem Text #636366 "Für dich angepasst". Unten die schwebende Glas-Tab-Bar mit dem runden Avo-Knopf.

---

## 6. R-04 Alle Rezepte und Beliebt

**Zweck:** "Alles durchblättern" bzw. "Was kochen gerade viele?" Einstieg: "Alle anzeigen" an "Neu" bzw. "Beliebt diese Woche"; "Alle schnellen Rezepte" (Filter "Unter 20 Min" aktiv) und Chip "Passt zu mir" in der Suche (Filter "Passt zu mir" aktiv) öffnen "Alle Rezepte" mit vorgewähltem Filter.

### 6.1 Aufbau

- **Alle Rezepte** (`/recipes/all`): wie R-03 (Titel "Alle Rezepte", Metazeile "412 Rezepte", Filterzeile, Sortieren-Menü mit Standard "Neu"), Paging vom Server.
- **Beliebt** (`/recipes/popular`): großer Titel "Beliebt diese Woche", Metazeile "Nach Bewertungen der letzten 7 Tage" (ehrliche Quelle), dann eine `InsetSection` mit bis zu 50 Rang-Zeilen (Rang `numberL` `labelSecondary`, Thumbnail 56, Titel `headline`, Meta "25 Min · 4,8 (64)"). Kein Filter.

### 6.2 Zustände

Wie R-03. Beliebt leer (weniger als 3 Bewertungen in der Woche): Satz "Diese Woche wurde noch wenig bewertet." und darunter die bestbewerteten Rezepte insgesamt unter der Überschrift "Insgesamt beliebt" (heute derselbe Rückfall, aber unbeschriftet).

### 6.3 Große Schrift und 320 pt

Rang-Zeilen ab AX1: Rang steht vor dem Titel in derselben Zeile ("1. Shakshuka"), Thumbnail entfällt.

### 6.4 Was sich ändert

`all_recipes_screen.dart`: Material-`AppBar`, `CupertinoActivityIndicator`, `RecipeErrorView` entfallen; `_popularRecipesPageProvider` wird serverseitig aggregiert.

### 6.5 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, oben links runder Glas-Zurück-Knopf. Großer fetter Titel "Beliebt diese Woche", darunter grau "Nach Bewertungen der letzten 7 Tage". Eine weiße Sektion mit 26 pt Radius und eingerückten feinen Trennlinien #C6C6C8 mit sechs Zeilen: links eine große graue gerundete Ziffer (1 bis 6), dann ein quadratisches Essensfoto mit 12 pt Radius, daneben fetter Name ("Shakshuka", "Linsen-Dal mit Spinat", "Ofengemüse mit Feta", "Kürbissuppe mit Ingwer", "Spaghetti Bolognese", "Pfannkuchen") und darunter grau "25 Min · 4,8 (64)". Schwarzer Text, keine Sterne in Gold, keine Badges. Unten die schwebende Glas-Tab-Bar.

---

## 7. R-05 Ersteller

**Zweck:** "Wessen Rezepte will ich sehen?" Einstieg: "Alle anzeigen" an der Ersteller-Reihe, "Alle Ersteller" in der Suche.

### 7.1 Aufbau

1. `LargeTitleNavBar` Push: "Ersteller".
2. `SearchField` "Ersteller suchen" (lokal sofort, Server entprellt 300 ms).
3. Sektion "Folge ich" (nur, wenn man jemandem folgt): Zeilen Avatar 36, Name (`body`), Unterzeile "24 Rezepte · neu: Kürbis-Risotto" (`subheadline`, `labelSecondary`; "neu" nur bei neuem Rezept seit dem letzten Besuch), `chevron.right`.
4. Sektion "Beliebte Ersteller": dieselben Zeilen, Unterzeile "24 Rezepte · Ø 4,6". Top 50.

Entfällt: Verlaufsringe in Terrakotta, Chevron im getönten Quadrat, Karten statt Zeilen (Inv-B 3.2).

### 7.2 Zustände

- Leer: `EmptyState` (zufrieden, 96 pt): "Noch keine Ersteller." Satz: "Wer ein Rezept veröffentlicht, erscheint hier." Aktion schlicht "Rezept schreiben".
- Keine Treffer: "Niemand gefunden für „Kim“."
- Offline, Fehler: `StatusRow`, gespeicherte Zeilen bleiben.

### 7.3 Interaktionen und Größen

Wischen nach links auf "Folge ich": "Nicht mehr folgen" (neutral grau, kein Rot), mit Rückgängig-Hinweis "Mara Köhler entfolgt · Widerrufen". Ab AX1 entfällt der Avatar nicht (Personen erkennt man am Bild), die Unterzeile bricht um.

### 7.4 Was sich ändert

`creators_screen.dart` neu als Sektionen; `creatorsProvider` serverseitig; Folgen ist neu (E-08, Tabelle `creator_follows` existiert in `database/migrations/new_recipe_features.sql`, App-Code wurde gelöscht; ob die Tabelle in Supabase angelegt ist, vor dem Bau prüfen).

### 7.5 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links. Großer fetter Titel "Ersteller", darunter graues Kapsel-Suchfeld #E9E9EE "Ersteller suchen". Sektion "Folge ich" mit zwei Zeilen in einer weißen 26-pt-Sektion: runde Profilfotos 36 pt, Namen "Mara Köhler" und "Deniz Aydın" in Schwarz, darunter grau #636366 "24 Rezepte · neu: Kürbis-Risotto" und "17 Rezepte", rechts graue Chevrons. Darunter Sektion "Beliebte Ersteller" mit vier weiteren Zeilen ("Sophie Brandt · 11 Rezepte · Ø 4,6", "Jonas Meier · 9 Rezepte · Ø 4,4"). Keine farbigen Ringe, keine Kacheln.

---

## 8. R-06 Ersteller-Seite

**Zweck:** "Wer ist das, und will ich mehr von dieser Person?" Einstieg: Autorzeile im Detail, Ersteller-Reihe, R-05, Deep Link `shoply://author/<id>`. Liegt jetzt immer im aktuellen Tab (Tab-Bar bleibt), nicht mehr außerhalb der Shell (01 5.4).

### 8.1 Aufbau

1. `LargeTitleNavBar` in der neuen Variante **Profil-Kopf** (E-17): statt des großen Titels steht der Kopf aus Punkt 2 (Muster aus Kontakte); Zurück links mit dem Namen der vorherigen Seite. Toolbar rechts `square.and.arrow.up` (Link teilen) und `ellipsis` ("Melden", "Blockieren").
2. Kopf mittig: Avatar 64 pt (`avatarXL`), Name `title2` (Überschriften-Rolle für VoiceOver), Metazeile `subheadline` `labelSecondary` "24 Rezepte · Ø 4,6". Beim Scrollen erscheint der Name als Inline-Titel (`headline`, eine Zeile) mit Scroll-Edge-Verlauf.
3. Hauptaktion `AppButton` prominent "Folgen" (`person.badge.plus`, E-12); gefolgt wird daraus grau "Folge ich" mit `checkmark`. Eigene Seite: kein Folgen-Knopf, stattdessen grau "Profil bearbeiten" (öffnet `/settings/profile`).
4. Satz unter dem Knopf, nur beim ersten Folgen einmalig: "Du bekommst eine Mitteilung bei neuen Rezepten. Ändern in Mitteilungen." (`footnote`).
5. Sektion "Rezepte" mit Sortieren-Menü rechts im Sektionstitel ("Neu", "Beliebt"), Raster 2 Spalten `RecipeCard` klein.

Keine Follower-Zahl im Kopf (Q-10), keine Bio (gibt es im Datenmodell nicht).

### 8.2 Beispielinhalt

Mara Köhler, "24 Rezepte · Ø 4,6"; Rezepte "Ofengemüse mit Feta", "Kürbis-Risotto", "Linsen-Dal mit Spinat", "Zitronen-Hähnchen aus dem Ofen".

### 8.3 Zustände

- Lädt: Kopf aus den Daten der Karte bzw. Zeile, über die man kam (Name, Avatar), sofort; Raster aus dem Katalog-Cache, Rest unten angefügt. Kein Spinner im Avatar (heute Inv-B 4.7).
- Fehler: `StatusRow`; heute zeigt ein Fehler "Keine Rezepte gefunden" (Inv-B 4.5), künftig "Rezepte konnten nicht geladen werden. Erneut versuchen".
- Person gelöscht oder blockiert: Satz "Diese Seite ist nicht mehr verfügbar." mit schlicht "Zu den Rezepten".
- Folgen offline: Zustand wechselt sofort, Abgleich später (Warteschlange).

### 8.4 Interaktionen, Haptik

Folgen: Knopf wechselt mit `springQuick` die Variante, keine Haptik. Entfolgen über denselben Knopf, ohne Rückfrage, mit Rückgängig-Hinweis. Blockieren: `confirmDestructive` ("Mara Köhler blockieren?" / "Du siehst keine Rezepte und Kommentare mehr von dieser Person. Du kannst das in den Einstellungen aufheben." / "Blockieren"), weil es Inhalte für einen ausblendet (E-09).

### 8.5 Große Schrift und 320 pt

Kopf bleibt mittig, Name bricht um (keine Begrenzung). Raster wie R-03. "Folgen" in voller Breite minus `pageMargin`, wächst in der Höhe mit. Ab AX1 bleibt der Avatar 64 pt (Personen erkennt man am Bild), das Raster wird einspaltig (2.7). Wird R-06 als 4. Ebene geöffnet, erscheint es als Sheet groß (2.6) mit `xmark` statt Zurück.

### 8.6 Was sich ändert

`recipe_author_page.dart` neu; Route im Tab statt Top-Level; `author_avatar.dart` wird `Avatar` (00 12.29); `getRecipesByAuthor` nutzt `_hydrate` (Bewertung des Nutzers, Inv-B 4.8).

### 8.7 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, oben links runder Glas-Zurück-Knopf, oben rechts eine Glas-Gruppe mit Teilen-Symbol und drei Punkten. Mittig ein rundes Porträtfoto 64 pt einer Frau in der Küche, darunter fett "Mara Köhler" und grau #636366 "24 Rezepte · Ø 4,6". Darunter eine breite grüne Kapsel #3F7A1F mit weißer Schrift und Personen-Plus-Symbol "Folgen". Dann der Sektionstitel "Rezepte" mit rechts grünem Text "Neu" und kleinem Chevron, darunter ein zweispaltiges Raster weißer Karten mit 4:3-Essensfotos (Ofengemüse, Kürbis-Risotto, Linsen-Dal, Zitronen-Hähnchen) und fetten Namen. Unten die schwebende Glas-Tab-Bar.

---

## 9. R-07 Gespeichert

**Zweck:** "Was wollte ich nachkochen?" Einstieg: "Deine Rezepte" > "Gespeichert", Deep Link `shoply://recipes/saved`, Rezept-Widget.

### 9.1 Aufbau

1. `LargeTitleNavBar` Push: "Gespeichert", Metazeile "12 Rezepte".
2. `SearchField` ab 10 gespeicherten Rezepten.
3. `InsetSection` mit `RecipeCard` Zeilen in Speicherreihenfolge (neueste oben), Metazeile mit Autor: "35 Min · von Mara Köhler".

### 9.2 Zustände

- Leer: `EmptyState` (zufrieden, 96 pt): "Noch keine gespeicherten Rezepte." Satz: "Tippe auf das Lesezeichen bei einem Rezept." Aktion schlicht "Rezepte entdecken" (wechselt zur Tab-Wurzel).
- Laden: lokal sofort; Server-Abgleich im Hintergrund. Ein Netzfehler leert die Liste nie (heute Inv-B 4.3); das iOS-Widget bekommt nur bestätigte Stände.
- Offline: `StatusRow`; Entfernen geht in die Warteschlange.
- Ein gespeichertes Rezept wurde vom Ersteller gelöscht: Zeile bleibt grau mit "Nicht mehr verfügbar" und Wischaktion "Entfernen".

### 9.3 Interaktionen

Wischen nach links: "Entfernen" in neutralem Grau (`fill`, Symbol `bookmark.slash`), nicht rot, weil nichts gelöscht wird (heute roter Mülleimer, Inv-B 3.2); volles Wischen entfernt sofort, `UndoToast` "Aus Gespeichert entfernt · Widerrufen". Langdruck: Kontextmenü wie in 3.4. Entfernen ändert nur die eine Zeile (`springStandard`), lädt nicht die ganze Liste neu (Inv-B 4.7).

### 9.4 Große Schrift und 320 pt

Wie R-02 Zeilen. Keine feste Kopfhöhe (heute `SliverAppBar` 100/60, Inv-B 3.3).

### 9.5 Was sich ändert

`saved_recipes_screen.dart` neu (große Karten werden Zeilen), `saved_recipes_provider.dart` (optimistisch, Fehler ohne Leeren, kein komplettes Neuladen nach jedem Tipp), `WidgetService.updateSavedRecipesWidget` nur mit bestätigtem Stand. Die Anzahl im Profil (`profile_screen.dart`) liest denselben `RecipeStore` wie Zeile, Widget und "Deine Rezepte". Die App-Bewertungs-Abfrage (`AppReviewService`) hängt nicht mehr am Merken, weil sie dort mitten im Stöbern unterbricht; neuer Auslöser nach Q-16.

### 9.6 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links. Großer fetter Titel "Gespeichert", darunter grau "12 Rezepte". Eine weiße Sektion mit 26 pt Radius mit fünf Zeilen aus quadratischem Essensfoto mit 12 pt Radius, fettem Namen und grauer Zeile ("Shakshuka · 25 Min · von Deniz Aydın", "Kürbissuppe mit Ingwer · 40 Min · von Sophie Brandt"). Eine Zeile ist halb nach links gewischt und zeigt dahinter eine graue Fläche #E9E9EE mit durchgestrichenem Lesezeichen und "Entfernen". Unten über der Glas-Tab-Bar schwebt eine kleine milchige Glas-Kapsel "Aus Gespeichert entfernt" mit grünem "Widerrufen" #3F7A1F.

---

## 10. R-08 Meine Rezepte

**Zweck:** "Was habe ich geschrieben, und wie kommt es an?" Einstieg: "Deine Rezepte" > "Meine Rezepte".

### 10.1 Aufbau

1. `LargeTitleNavBar` Push "Meine Rezepte"; Toolbar `plus` (R-15).
2. Wenn Entwürfe existieren: `InsetSection` mit einer `NavRow` `doc.text` "Entwürfe" Wert "2" → R-09.
3. Sektion "Öffentlich": `RecipeCard` Zeilen, Metazeile "4,6 (23) · vor 3 Tagen" (Bewertung ist hier die eine ehrliche Rückmeldung; keine Aufrufe).
4. Sektion "Nur für mich": dieselben Zeilen ohne Bewertung (E-05, neues Feld Sichtbarkeit).

### 10.2 Zustände

- Leer: `EmptyState` (zufrieden): "Du hast noch kein Rezept geschrieben." Satz: "Halte fest, was bei euch gut ankommt." Aktion prominent "Rezept schreiben".
- Fehler: `StatusRow` statt "Noch keine Rezepte" (heute Inv-B 4.5).
- Offline: lokal sichtbar; Bearbeiten geht (Entwurf), Veröffentlichen wartet.

### 10.3 Interaktionen

Tippen: Detail (Zoom). Kontextmenü: "Bearbeiten" (R-15 mit `recipeId`), "Teilen", "Sichtbarkeit: Nur für mich" bzw. "Öffentlich machen", "Löschen" (`danger`, `confirmDestructive`, 18.2). Wischen nach links: "Löschen" (mit derselben Bestätigung, weil endgültig für alle, die es gespeichert haben).

### 10.4 Große Schrift, 320 pt, Änderungen

Wie R-07. Datei `my_recipes_screen.dart` (Bearbeiten-Kachel im getönten Quadrat entfällt), `myRecipesProvider` (Store).

### 10.5 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf links, runder Glas-Plus-Knopf rechts. Großer fetter Titel "Meine Rezepte". Eine kleine weiße Sektion mit einer Zeile "Entwürfe" mit Dokument-Symbol, rechts grau "2" und Chevron. Darunter Sektion "Öffentlich" mit zwei Zeilen ("Omas Kartoffelsalat · 4,6 (23) · vor 3 Tagen", "Kürbis-Risotto · 4,8 (9) · vor 2 Wochen") mit quadratischen Fotos, und Sektion "Nur für mich" mit einer Zeile "Pausenbrot für Mia" ohne Foto, stattdessen ein graues Quadrat #E9E9EE mit 12 pt Radius und einem kleinen Brot-Symbol in Grau #636366. Text schwarz, Metazeilen grau #636366, keine Stift-Kacheln. Unten die schwebende Glas-Tab-Bar.

---

## 11. R-09 Entwürfe

**Zweck:** "Wo war ich beim Schreiben stehen geblieben?" Einstieg: "Deine Rezepte" > "Entwürfe", "Meine Rezepte" > "Entwürfe", Hinweis nach dem Schließen des Editors.

### 11.1 Aufbau

1. `LargeTitleNavBar` Push "Entwürfe".
2. `InsetSection` mit Zeilen: Thumbnail 56 (Entwurfsfoto oder Typo-Fläche), Titel `headline` ("Unbenannter Entwurf" in `label`, nicht kursiv grau), Unterzeile `subheadline`: Status als Text "Bereit zum Veröffentlichen" bzw. "Es fehlen: Zutaten, Anleitung", dahinter "· vor 2 Std. auf iPhone 13 Pro". Bei Entwürfen zu einem veröffentlichten Rezept: "Änderungen an „Kürbis-Risotto“".
3. Gerätename: Seit iOS 16 liefert `UIDevice.name` ohne Sonder-Berechtigung nur "iPhone". Angezeigt wird deshalb der Modellname aus der Modellkennung ("iPhone 13 Pro"); haben beide Geräte dasselbe Modell, heißt es "auf deinem anderen iPhone", auf dem eigenen Gerät "auf diesem iPhone".

### 11.2 Zustände

- Leer: Seite ist nur über "Deine Rezepte" erreichbar, wenn Entwürfe existieren; per Deep Link leer: `EmptyState` "Keine Entwürfe." Satz: "Was du anfängst, wird hier automatisch gespeichert."
- Synchronisierung: Entwürfe liegen im Konto (E-05) und erscheinen auf beiden Geräten (Owner und Jannis nutzen dasselbe Konto, Inv-D 33). Wird derselbe Entwurf auf zwei Geräten gleichzeitig bearbeitet, gilt die zuletzt gespeicherte Fassung je Feld; beim Öffnen eines auf einem anderen Gerät geänderten Entwurfs steht oben im Editor eine `StatusRow` "Zuletzt auf iPhone 15 geändert, vor 5 Min."
- Offline: lokal sichtbar und bearbeitbar; Abgleich später.

### 11.3 Interaktionen

Tippen öffnet R-15 im Entwurf. Wischen nach links "Löschen" (`danger`) → `confirmDestructive` "Entwurf löschen?" / "„Unbenannter Entwurf“ und sein Foto werden auf allen Geräten gelöscht." (endgültig, deshalb Rückfrage, 00 12.34).

### 11.4 Große Schrift, 320 pt, Änderungen

Wie R-07. `recipe_drafts_screen.dart` neu: kein `File.existsSync()` im `build`, Bilder mit `cacheWidth`, kein Material-`AlertDialog`, keine Snackbar (Inv-B 4.7). `RecipeDraftService` speichert lokal (Datenbank statt SharedPreferences-Liste) und synchronisiert in die Tabelle `recipe_drafts` (E-05).

### 11.5 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, runder Glas-Zurück-Knopf oben links. Großer fetter Titel "Entwürfe". Eine weiße Sektion mit 26 pt Radius und zwei Zeilen: links ein quadratisches Foto eines Risottos, daneben fett "Änderungen an „Kürbis-Risotto“" und grau #636366 "Bereit zum Veröffentlichen · vor 2 Std. auf iPhone 13 Pro"; zweite Zeile mit grauer Typo-Fläche #E9E9EE als Bild, fett "Unbenannter Entwurf" in Schwarz und grau "Es fehlen: Zutaten, Anleitung · gestern auf iPhone 15". Keine farbigen Status-Pillen, keine Mülleimer-Knöpfe. Unten die schwebende Glas-Tab-Bar.

---

## 12. R-10 Rezeptdetail

**Zweck:** "Will ich das kochen, und was brauche ich dafür?" Einstieg: jede `RecipeCard` (Zoom), Wochenplan (B), Avo-Ergebniszeile, Widget, Mitteilung (Bewertung, Kommentar, neues Rezept eines gefolgten Erstellers), Deep Link `/recipe/:id` (auch abgemeldet, 19.8).

### 12.1 Aufbau von oben nach unten

1. **Foto-Kopf:** Foto randlos 4:3 bis unter die Statusleiste (00 9.6), `photo_color` ab dem ersten Frame. Stretch beim Überziehen nach unten (Gummiband, Foto skaliert vom unteren Rand aus). Typo-Karte, wenn das Foto fehlt oder zu klein ist (Fläche `fill`, Titel `title2`, bis zu vier Avo Symbols der Hauptzutaten).
2. **`LargeTitleNavBar` Variante Foto-Kopf:** Glas `clear` mit Verlauf #000000 30 % am oberen Bildrand. Links `chevron.left` (Zurück). Rechts eine Gruppe: `bookmark` (Merken; bei eigenem Rezept stattdessen schlicht "Bearbeiten" als Text-Kapsel), `square.and.arrow.up` (Teilen), `ellipsis` (Menü 18.1). Beim Einklappen (Foto aus dem Bild gescrollt) wird die Leiste `regular`, der Rezeptname erscheint als Inline-Titel (`headline`, eine Zeile, Ellipse); heute fehlt der Titel eingeklappt (Inv-D 3.1). Kein roter Löschen-Kreis in der Toolbar.
3. **Titel und Metazeile** auf `bgGrouped`, `pageMargin`: Titel `title1` (bricht um, keine Begrenzung), 8 pt darunter Metazeile `subheadline` `labelSecondary`: "35 Min · Einfach · 4,7 (128)" (Bewertung nur, wenn mindestens 3 Bewertungen; sonst entfällt sie). Darunter Autorzeile: Avatar 28, "von Mara Köhler" (`subheadline`, `label`), `chevron.right`, ganze Zeile tippbar mit Mindesthöhe 44 pt (wächst mit der Schrift) → R-06 (bzw. Sheet nach 2.6). Bei importierten Rezepten statt Autor "aus Wikibooks Kochbuch" ohne Avatar.
4. **Allergie- und Anpassungs-Hinweis** (nur wenn zutreffend, `AllergenNotice`, E-03): eigene `InsetSection` direkt unter der Autorzeile, neutral: `exclamationmark.triangle.fill` in `warning`, Text `callout` `label`, Fußnote "Angaben ohne Gewähr. Prüfe die Zutaten auf der Packung." Treffen mehrere Fälle zu, steht je Fall eine Zeile in derselben Sektion, in dieser Reihenfolge: Allergen ohne Ersatz, Allergen mit Ersatz, Anpassung wegen Ernährungsweise, ungeprüft; die Fußnote steht einmal. Varianten:
   - "Enthält Milch (Feta). Du hast eine Laktoseintoleranz eingetragen. Ein Ersatz ist vorgeschlagen." (Ersatz vorhanden)
   - "Enthält Erdnuss. Du hast eine Erdnussallergie eingetragen. Für Erdnuss kennen wir keinen sicheren Ersatz." (kein Ersatz)
   - `questionmark.circle` in `labelSecondary`: "2 Zutaten konnten nicht auf Allergene geprüft werden: Gewürzmischung, Pesto." (ungeprüft)
   - Nur angepasst wegen Ernährungsweise (kein Allergen): `leaf` in `labelSecondary`, "Für dich angepasst: 1 Zutat ersetzt, weil du vegetarisch isst."
5. **Beschreibung** (nur wenn vorhanden): `body` in `label` (heute 80 % Deckkraft, Inv-D 3.1), ohne eigene Karte, bis 4 Zeilen mit schlichtem "Mehr", danach voll.
6. **Nährwerte:** `NutritionRow` (00 12.17) in einer `InsetSection` mit Titel "Nährwerte" und Sektionsfuß "pro Portion" bzw. bei KI-Schätzung "pro Portion, geschätzt". Werte gelten pro Portion und ändern sich mit dem Portionen-Stepper **nicht** (heute ohne Bezug, Inv-D 13). Mit Modul Kalorien darunter in derselben Sektion `NavRow` `flame` "Ins Tagebuch eintragen" (Slot `showLogRecipeSheet`, B). Ohne Nährwertdaten entfällt die Sektion ohne Lücke.
7. **Zutaten:** `InsetSection`. Kopf: Titel "Zutaten" (`headline`), rechts im selben Kopf `ValueStepper` "2 Portionen" (Wert als `RollingNumber`, Einheit "Portionen" als Teil des Werts, 1 bis 20). Darunter, nur wenn Anpassungen existieren, `SegmentedControl` "Für dich angepasst | Original" (Start: "Für dich angepasst", bei ausgeschaltetem "Rezepte automatisch anpassen" "Original"; 2.3). Zeilen (`body`): Menge rechtsbündig in einer Spalte (`number`, tabellarisch, "200 g"), Name links ("Feta"); angepasste Zeile mit `arrow.left.arrow.right` und Unterzeile "statt Feta · wegen Laktose"; Allergen-Zeile mit `exclamationmark.triangle.fill` in `warning` hinter dem Namen; ungeprüft mit `questionmark.circle`. Mit Modul Angebote: gelbes Schild an der Zeile (Slot `IngredientOfferBadge`, E-06) und als letzte Zeile der Sektion `RecipeOfferSummary`: `tag` + "3 Zutaten bei Lidl im Angebot · für Wocheneinkauf, in deiner Region" (Tippen öffnet das Angebots-Sheet von B, gefiltert). Maßgeblich ist die Ziel-Liste: die zuletzt in R-11 für dieses Rezept gewählte, sonst die Liste von heute (01 2.2). Hat sie keinen Markt, gibt es keine Schilder (2.4). Zeilen sind nicht zum Abhaken (das geschieht im Kochmodus und in R-11).
8. **Zubereitung:** `InsetSection` mit Titel "Zubereitung" und rechts im Titel `numberS` "5 Schritte". Jeder Schritt eine Zeile: Nummer in `numberS` `labelSecondary` links oben bündig, Text `body` `label`. Erkannte Zeiten stehen hier als normaler Text in `label`, nicht grün: Grün hieße "antippbar" (00 4.2), Timer gibt es erst im Kochmodus. In der angepassten Fassung ersetzt `RecipeAdaptation` wörtliche Nennungen einer ersetzten Zutat auch im Schritttext (Wortgrenzen wie 2.3); unter dem Schritt steht dann `footnote` `labelSecondary` "statt Feta · wegen Laktose". In "Original" steht der Originaltext.
9. **Varianten** (Status `hidden` bis Q-01): `InsetSection` "Varianten" mit Zähler "3" rechts im Titel (`numberS`, 00 12.5), bis 2 Zeilen ("Mit Halloumi statt Feta · von Deniz Aydın · 41 fanden das hilfreich", `arrow.triangle.branch`, E-12), Fuß schlicht "Alle 3 Varianten" und "Variante vorschlagen" → Kapitel 14.
10. **Bewerten** (nicht bei eigenem Rezept, Inv-D 14): `InsetSection` ohne Titel, eine Zeile "Deine Bewertung" links, rechts 5 Sterne (`star`/`star.fill` in `action`, E-12, je 44-pt-Ziel). Optimistisch, Rollback bei Fehler mit `StatusRow` an der Zeile. Ersetzt die 48-pt-Zahl und die doppelte Bewertung (Inv-D 3.1).
11. **Kommentare** (Status `hidden` bis Q-01): `InsetSection` "Kommentare" mit Zähler "12" rechts im Titel, die zwei neuesten (Avatar 28, Name, Text bis 3 Zeilen, Datum `caption1`), Fuß schlicht "Alle Kommentare" → R-13.
12. **Quelle** (nur importiert, Pflicht wegen Lizenz): Sektionsfuß `footnote`: "Quelle: Wikibooks Kochbuch · CC BY-SA 4.0", Link schlicht in `action`, öffnet Safari-Ansicht.
13. **Aktionsleiste** (schwebende Glas-Gruppe über der Tab-Bar, ersetzt das Accessory, 00 8.1): links getönte Glas-Kapsel `cart` "Zutaten auf Liste" (Hauptaktion), rechts Glas-Kapsel `frying.pan` "Kochen". Gibt es einen Kochfortschritt: "Weiter: Schritt 3" statt "Kochen". Mit Pro-Sperre trägt "Kochen" eine `ProBadge` (16.6). VoiceOver: "Zutaten auf Liste, Taste", "Kochen, Taste"; die Leiste kommt in der Lesereihenfolge nach dem Inhalt und vor der Tab-Bar.
14. Unterer Inhaltsabstand = Aktionsleiste + Tab-Bar + 16 (aus `ShellInsets`).

Entfällt: Kennzahlen-Leiste mit vier Spalten und Trennern, "Aufrufe", "tippen zum Ändern", Portionen-Dialog, Karte "Über" ohne Inhalt, Karten mit Rahmen, "Kochen starten" als zweiter voller Akzentknopf vor dem Inhalt, Angebotskarte über alle Märkte (Inv-D 3.1, 4.3).

### 12.2 Beispielinhalt

"Ofengemüse mit Feta", "35 Min · Einfach · 4,7 (128)", "von Mara Köhler". Hinweis (Nutzerin mit Laktoseintoleranz): "Enthält Milch (Feta). Du hast eine Laktoseintoleranz eingetragen. Ein Ersatz ist vorgeschlagen." Beschreibung: "Ein Blech, wenig Abwasch: Kartoffeln und Gemüse rösten, Feta obendrauf, fertig." Nährwerte pro Portion: 540 kcal, 18 g Protein, 52 g Kohlenhydrate, 29 g Fett.

Zutaten für 2 Portionen:

| Menge | Zutat | Besonderheit |
|---|---|---|
| 500 g | Kartoffeln, festkochend | |
| 1 | Zucchini | |
| 1 | rote Paprika | gelbes Schild "0,79 €" (Lidl) |
| 1 | rote Zwiebel | |
| 250 g | Cherrytomaten | gelbes Schild "1,29 €" |
| 200 g | laktosefreier Hirtenkäse | angepasst: "statt Feta · wegen Laktose" |
| 3 EL | Olivenöl | |
| 1 TL | Oregano, getrocknet | |
| 2 Zweige | Thymian | gelbes Schild "0,99 €" |
| | Salz | |
| | Pfeffer | |

Angebotszeile: "3 Zutaten bei Lidl im Angebot · für Wocheneinkauf, in deiner Region".

Zubereitung (angepasste Fassung; Schritt 4 trägt die Fußnote "statt Feta · wegen Laktose", in "Original" steht dort "Feta"):
1. Ofen auf 200 °C Umluft vorheizen. Kartoffeln waschen und in Spalten schneiden.
2. Zucchini, Paprika und Zwiebel in grobe Stücke schneiden.
3. Alles mit Olivenöl, Oregano, Salz und Pfeffer mischen, auf einem Blech verteilen und 15 Minuten backen.
4. Hirtenkäse zerbröseln, mit den Tomaten auf das Gemüse geben und weitere 10 Minuten backen.
5. Mit Thymian bestreuen und servieren.

(10 Min Vorbereitung + 25 Min Backen = 35 Min.)

### 12.3 Zustände

| Zustand | Verhalten |
|---|---|
| Lädt, Rezept aus Karte bekannt | Sofort voller Inhalt aus der Karte bzw. dem Cache (`initialRecipe`), fehlende Detailteile (Zutaten, Schritte) aus dem Detail-Cache; still abgleichen. |
| Lädt, nichts bekannt (Deep Link, erstes Öffnen) | Foto-Fläche in `photo_color` (falls im Link-Vorschau-Cache) bzw. `fill`, Titel-Skelett als Tonfläche, Sektionen als ruhige Tonflächen ohne Schimmer, bis zur ersten Antwort. Kein Vollbild-Spinner (Inv-D 27). |
| Nach Veröffentlichen | Detail zeigt sofort die lokale Fassung aus dem Editor (19.4), nie einen Spinner. |
| Rezept nicht gefunden (gelöscht, privat) | `EmptyState` suchend (96 pt): "Dieses Rezept gibt es nicht mehr." Aktion schlicht "Zu den Rezepten". Unterscheidet sich von: |
| Laden fehlgeschlagen ohne Cache | `EmptyState`-Layout ohne Maskottchen, `exclamationmark.circle`: "Das Rezept konnte nicht geladen werden." Aktion "Erneut versuchen". |
| Fehler beim Abgleich mit Cache | Inhalt bleibt; keine Meldung (der Stand ist gültig). |
| Offline | `StatusRow` unter der Autorzeile "Offline. Gespeicherte Fassung." Bewerten, Merken und Zutaten auf Liste gehen in die Warteschlange; Angebote, Varianten und Kommentare zeigen an ihrem Ort "Braucht eine Verbindung". |
| Kein Foto / schlechtes Foto | Typo-Karte als Kopf, Toolbar dann `regular` statt `clear`. |
| Keine Beschreibung / keine Nährwerte / keine Varianten / keine Kommentare | jeweilige Sektion entfällt komplett. |
| Modul Kalorien aus | "Ins Tagebuch" entfällt; `NutritionRow` bleibt. |
| Modul Angebote aus / Kill-Switch / keine echte PLZ / Ziel-Liste ohne Markt | Schilder und Angebotszeile entfallen ohne Lücke. Ohne PLZ bzw. Markt keine Aufforderung hier (die steht in Preise & Angebote, auf der Startseite bzw. am Markt-Chip der Liste). |
| Angebote kommen nach | Schilder erscheinen in der reservierten Breite am Zeilenende (keine Zeile wird höher), die Angebotszeile erscheint nur, wenn beim Öffnen schon gecacht; sonst erst beim nächsten Öffnen (heute schiebt die Karte die Anleitung, Inv-D 29). |
| Pro gesperrt (Kochen) | "Kochen" mit `ProBadge`; Tippen öffnet den Kochmodus als echte Vorschau (16.6). |
| Eigenes Rezept | `bookmark` wird "Bearbeiten"; kein Bewerten; Menü mit "Sichtbarkeit" und "Löschen". |
| Gesperrte Person (blockiert) | Rezept öffnet nicht; Satz "Du hast diese Person blockiert." mit "Aufheben" (Einstellungen). |
| Abgemeldet bzw. vor dem Onboarding (öffentlicher Link) | Inhalt voll sichtbar, ohne Tab-Bar und ohne Avo-Kreis; Merken, Bewerten, Zutaten auf Liste und Kochen führen ins Anmelden bzw. Onboarding und werden danach fortgesetzt (19.8). Ohne Profil gibt es weder Allergie-Hinweis noch Anpassung. |
| Als 4. Ebene geöffnet | Sheet groß nach 2.6: `xmark` statt Zurück, Aktionsleiste unten im Sheet, Autorzeile ohne Chevron, wenn man aus dem Ersteller kam. |

### 12.4 Interaktionen, Bewegung, Haptik

- **Zoom-Übergang:** Das Foto der Karte wächst in den Foto-Kopf, Titel und Inhalt blenden ein (`springMorph`); Zurück-Wischen vom linken Rand oder nach unten (bei Scroll-Position oben) schrumpft das Detail 1:1 zur Karte zurück, unterbrechbar; Loslassen mit Wurfprojektion entscheidet (00 10.1). Reduce Motion: Überblendung.
- **Portionen-Stepper:** jeder Schritt Auswahl-Haptik; alle Mengen rollen gleichzeitig (`springDigits`), Spalte bleibt bündig (tabellarisch). Langdruck wiederholt. Die gewählte Portionenzahl gilt für R-11, R-14 und wird pro Rezept gemerkt.
- **Segment Angepasst/Original:** Zeilen wechseln mit `springStandard` (Name blendet über, Unterzeile wächst/schrumpft). Keine Haptik bei Tippen (00 Kap. 11).
- **Merken:** Symbol füllt sich, keine Haptik, kein Toast. **Teilen:** System-Teilen wächst aus dem Knopf, mit Link `https://shoplyai.app/recipe/<id>` und Text "Ofengemüse mit Feta von Mara Köhler. Rezept in {app}:" (lokalisiert, ohne Emoji; heute nur Englisch mit Emojis, Inv-D 16).
- **Allergie-Hinweis:** erscheint ohne Animation mit dem Inhalt; Haptik "Warnung" einmal pro Rezept und Sitzung.
- **Stern-Bewertung:** Tippen auf Stern 4 füllt 1 bis 4 mit `springQuick`, keine Haptik; Ziehen über die Sterne folgt dem Finger mit Auswahl-Haptik pro Stern; Ansage "4 von 5 Sternen".
- **Aktionsleiste:** bleibt sichtbar beim Scrollen; die Tab-Bar ebenfalls (Push, 01 Kap. 6). Öffnet R-11, wird die Leiste aus dem Baum genommen, bis das Sheet geschlossen ist (2.5).
- **Langdruck auf eine Zutat:** Menü wächst aus der Zeile: "Auf Wocheneinkauf setzen" (nur diese Zutat, auf die Ziel-Liste aus 12.1 Nr. 7, skaliert; `UndoToast` "Feta zu Wocheneinkauf · Widerrufen"), "Ersatz anzeigen" (wenn vorhanden).

### 12.5 Große Schrift und 320 pt

- 320 pt: Foto bleibt 4:3; Aktionsleiste zeigt "Zutaten auf Liste" mit Text und "Kochen" nur als Symbol-Kreis `frying.pan` (44 pt); `NutritionRow` 2 × 2 (00 6.3); Portionen-Stepper rutscht unter den Titel "Zutaten" (eigene Zeile, linksbündig). Ab xxL reicht die Breite für "Zutaten auf Liste" nicht mehr (Kapsel plus Symbol-Kreis brauchen dann über 288 pt); die Kapsel heißt dann kurz "Auf Liste", das VoiceOver-Label bleibt "Zutaten auf Liste".
- Ab xxxL: Mengen-Spalte rechts entfällt, die Menge steht vor dem Namen in derselben Zeile ("200 g Feta"), damit der Name die volle Breite hat; der Portionen-Stepper steht auf jeder Breite in eigener Zeile unter "Zutaten".
- Ab AX1: Sektionen randlos (2.7); Metazeile bricht in Teile untereinander; Autor-Avatar bleibt; `SegmentedControl` wird Pull-down-Menü "Zutaten: Für dich angepasst" mit `chevron.down` (00 12.18); `NutritionRow` 2 × 2. Aktionsleiste: "Zutaten auf Liste" bzw. "Auf Liste" als Kapsel mit Text, "Kochen" als Symbol-Kreis; die Beschriftung bleibt auf xxxL-Größe stehen und zeigt bei Langdruck den Large Content Viewer (E-19). So bleibt die Leiste einzeilig und verdeckt nicht den Inhalt.
- Ab AX3: Foto-Kopf 16:10 statt 4:3, damit der Titel im ersten Bildschirm beginnt.
- Keine feste Kopfhöhe (heute 280 pt, Titel ohne `maxLines` unter den Knöpfen, Inv-D 3.2).

### 12.6 Was sich ändert, betroffene Dateien

`recipe_detail_screen.dart` (neu aufgebaut, `RecipeService()` direkt instanziiert entfällt zugunsten des Stores), `nutrition_info_widget.dart` → `NutritionRow`, `star_rating_widget.dart` (`LargeStarRating` entfällt, Sterne-Zeile bleibt), `servings_stepper.dart` → `ValueStepper`, `recipe_offers_card.dart` → B-Slots `RecipeOfferSummary` und `IngredientOfferBadge` (E-06), `ingredient_substitution_service.dart` und `dietary_preference.dart` → `RecipeAdaptation` (2.3), `recipe_service.dart` (`getShareText` lokalisiert, `trackRecipeView` serverseitig gebremst), `liquid_glass_container.dart` (keine drei Einzel-Views, eine Gruppe), `log_recipe_sheet.dart` (B, bleibt Slot).

### 12.7 Bildbeschreibung für ChatGPT

iPhone-Screen hell, oben randlos bis unter die Statusleiste ein 4:3-Foto eines Blechs mit geröstetem Gemüse und zerbröseltem weißem Käse, am oberen Rand ein leichter dunkler Verlauf. Über dem Foto schweben klare, fast durchsichtige Liquid-Glass-Knöpfe: links ein runder Zurück-Knopf mit Chevron, rechts eine Glas-Gruppe mit Lesezeichen, Teilen und drei Punkten. Darunter auf hellgrauem Hintergrund #F2F2F7 der große fette Titel "Ofengemüse mit Feta" in Schwarz, darunter grau #636366 "35 Min · Einfach · 4,7 (128)" und eine Zeile mit kleinem runden Porträt und "von Mara Köhler". Dann eine weiße Sektion mit 26 pt Radius mit orangem Warndreieck #A85400 und schwarzem Text "Enthält Milch (Feta). Du hast eine Laktoseintoleranz eingetragen. Ein Ersatz ist vorgeschlagen." und kleiner grauer Fußnote #636366 "Angaben ohne Gewähr. Prüfe die Zutaten auf der Packung." Darunter eine weiße Sektion "Nährwerte" mit vier Spalten wie in Health: "540 kcal", "18 g Protein", "52 g Kohlenhydrate", "29 g Fett" in abgerundeten Ziffern. Dann die Sektion "Zutaten" mit rechts einem grauen Kapsel-Stepper "− 2 Portionen +", darunter Zeilen mit Zutatennamen links und Mengen rechts ("Kartoffeln, festkochend 500 g", "rote Paprika 1" mit kleinem gelbem Preisschild #FFD60A "0,79 €", "laktosefreier Hirtenkäse 200 g" mit kleinem Tausch-Symbol und grauer Unterzeile "statt Feta · wegen Laktose"). Unten schwebt über der Glas-Tab-Bar eine Glas-Leiste mit einer grün getönten Kapsel #3F7A1F "Zutaten auf Liste" mit Einkaufswagen in Weiß und einer milchigen Glas-Kapsel "Kochen" mit Pfannen-Symbol; rechts neben der Tab-Bar der runde Avo-Knopf mit brauner Kugel #7A4A24 in hellgrünem Ring #C9DE6E.

---

## 13. R-11 Sheet "Zutaten auf Liste"

**Zweck:** "Was davon muss ich kaufen, und auf welche Liste?" Einstieg: Aktionsleiste im Detail, Kontextmenü einer Rezeptkarte, Avo-Ergebniszeile "Ansehen" (B), Route `/recipes/:id/to-list`.

### 13.1 Aufbau (`AppSheet` mittel, Ziehen auf groß)

1. **Kopf:** `xmark` links, Inline-Titel "Zutaten auf Liste". Kein `checkmark` rechts; die Hauptaktion steht als Knopf mit Anzahl unten (die Anzahl braucht Text; Ausnahme von K-30, Q-08).
2. **Sektion ohne Titel:**
   - `ValueRow` "Liste" mit Wert: Listen-Glyph (`listGlyph` 28 pt) + "Wocheneinkauf" + `chevron.up.chevron.down`; Tippen öffnet `AppMenu`, das aus dem Wert wächst, mit allen Listen (Glyph, Name, offene Anzahl, aktuelle mit `checkmark`) und "Neue Liste". Standard: Liste von heute (01 2.2).
   - Zeile "Portionen" mit `ValueStepper` (übernimmt den Wert aus dem Detail).
   - Nur mit Anpassungen: `SegmentedControl` "Für dich angepasst | Original".
3. **Sektion "Zutaten"**, rechts im Titel `numberS` "8 von 11": jede Zutat eine Zeile mit Auswahl-Kreis vorn (Variante von `CheckCircle`: gewählt = gefüllt `action` mit Häkchen; nicht gewählt = Ring `controlOutline`), Name `body`, Menge rechts `number` (skaliert, gerundet nach 2.2). Unterzeilen (`subheadline`, `labelSecondary`):
   - "Schon auf Wocheneinkauf (1 Flasche)" → standardmäßig abgewählt. Wird sie gewählt: "wird zusammengefasst: 2 Flaschen" (gleiche Einheit) bzw. "kommt als eigene Zeile dazu" (andere Einheit).
   - "Hast du meist da" für Grundzutaten (Salz, Pfeffer, Wasser, Öl, Zucker; Liste E-04) → standardmäßig abgewählt (Q-05). Trifft beides zu, gilt die genauere Unterzeile "Schon auf …".
   - Kommt dieselbe Zutat mehrmals im Rezept vor (z. B. "2 EL Olivenöl" für das Blech, "1 EL Olivenöl" zum Beträufeln), steht sie hier einmal mit der Summe ("3 EL"), wenn die Einheit gleich ist; sonst als getrennte Zeilen.
   - "statt Feta · wegen Laktose" bei angepassten Zutaten.
   - Allergen ohne Ersatz: `exclamationmark.triangle.fill` in `warning` hinter dem Namen, Zeile bleibt **gewählt** (der Nutzer entscheidet; der Hinweis steht schon im Detail).
   - Mit Modul Angebote: gelbes Schild am Zeilenende (nur Markt der gewählten Liste; Wechsel der Liste wechselt die Schilder).
4. **Sektionsfuß** (Modul Angebote): "3 davon diese Woche bei Lidl im Angebot, laut Händler, in deiner Region." Ohne Markt an der Liste, ohne echte PLZ oder mit ausgeblendeten Angeboten der Liste: kein Fuß, keine Schilder.
5. **Hauptaktion** am unteren Rand des Sheets, fest stehend über dem Sheet-Hintergrund, der Inhalt läuft mit Scroll-Edge-Verlauf darunter aus: `AppButton` prominent "8 Zutaten hinzufügen" (Zahl als `RollingNumber`). Bei 0 gewählt: deaktiviert mit "Keine Zutat gewählt".

### 13.2 Ergebnis

- Tippen auf die Hauptaktion schließt das Sheet **sofort** (`springSheet`). Die Artikel werden optimistisch in einem Rutsch lokal angelegt (Kategorie lokal sofort, KI-Bestätigung im Hintergrund unter Einhaltung der 1,1-s-Regel, Batch-Insert zum Server; heute sequentiell mit sichtbarem "Füge 3 von 12 hinzu", Inv-D 28).
- `UndoToast`: "8 Zutaten zu Wocheneinkauf · Widerrufen". Widerrufen entfernt die neu angelegten Artikel und setzt zusammengefasste Mengen zurück. Tippen auf den Text des Hinweises öffnet die Liste im Tab Liste (Variante "mit Ziel", E-16; VoiceOver-Aktion "Liste öffnen"). Das ersetzt die heutige Aktion "Ansehen" (Inv-B 6: Sprung zur Liste bleibt).
- Keine Erfolgs-HUD-Box, keine eigene Haptik (der Hinweis ist die Rückmeldung; heute HUD 120 × 120, Inv-D 2.4).
- Angebotspreis, Händler und "statt"-Preis werden nur übernommen, wenn das Angebot zum Markt der Ziel-Liste gehört (heute billigster Händler aller Märkte, Inv-D 25).
- Teil-Fehler (Server lehnt einzelne Artikel ab): Die betroffenen Zeilen stehen in der Liste mit `exclamationmark.circle` "Nicht gespeichert" (00 12.8, Tippen wiederholt); zusätzlich `UndoToast` reiner Status "2 Zutaten nicht gespeichert".

### 13.3 Beispielinhalt

Liste "Wocheneinkauf" (Markt Lidl, 9 offen), 2 Portionen, angepasst. Gewählt: Kartoffeln 500 g, Zucchini 1, rote Paprika 1 (0,79 €), rote Zwiebel 1, Cherrytomaten 250 g (1,29 €), laktosefreier Hirtenkäse 200 g, Oregano 1 TL, Thymian 2 Zweige (0,99 €) = 8. Abgewählt: Olivenöl ("Schon auf Wocheneinkauf (1 Flasche)"), Salz und Pfeffer ("Hast du meist da"). Knopf "8 Zutaten hinzufügen". Ergebnis "8 Zutaten zu Wocheneinkauf · Widerrufen".

### 13.4 Zustände

- **Keine Liste vorhanden:** Zeile "Liste" zeigt "Neue Liste: Einkauf" (`label`); Hinzufügen legt die Liste "Einkauf" an (Name änderbar über die Zeile, Menü "Neue Liste" mit Namensfeld). Keine Sackgasse (heute "Noch keine Listen" ohne Aktion, Inv-D 17).
- **Listen laden:** nie sichtbar; Listen kommen aus dem lokalen Stand.
- **Offline:** alles geht; Artikel tragen das Sync-Zeichen; Schilder entfallen, wenn Angebote nicht gecacht sind.
- **Alle Zutaten schon auf der Liste:** alle abgewählt; Satz über der Sektion "Alles schon auf Wocheneinkauf." Knopf deaktiviert.
- **Modul Angebote aus / Kill-Switch / Liste ohne Markt:** keine Schilder, kein Fuß, keine Lücke.
- **Liste gewechselt:** Unterzeilen "Schon auf …" und Schilder wechseln mit `springStandard` zur neuen Liste; die Auswahl wird neu vorbelegt, aber nur für Zeilen, die der Nutzer noch nicht selbst geändert hat.
- **Pro:** nie gesperrt (Kern).

### 13.5 Interaktionen, Bewegung, Haptik

Tippen auf eine Zeile wählt an/ab (Kreis mit `springQuick`, keine Haptik; die Zahl im Titel und im Knopf rollt). Portionen-Stepper: Auswahl-Haptik, Mengen rollen. Ziehen am Sheet 1:1, Rasten mit Auswahl-Haptik (00 Kap. 11). Wischen nach unten schließt ohne Rückfrage (es gibt nichts zu verlieren außer der Auswahl). Solange das Sheet offen ist, sind Aktionsleiste und Tab-Bar verdeckt bzw. aus dem Baum genommen (00 8.4).

### 13.6 Große Schrift und 320 pt

Ab AX1 öffnet das Sheet gleich groß. Menge rutscht unter den Namen; der Auswahl-Kreis bleibt oben bündig zur ersten Textzeile; Schilder stehen unter der Menge. Die Zeile "Liste" stapelt Titel und Wert. Der Knopf bricht um und wächst in der Höhe. 320 pt: Menge rechts bleibt bis xxL, darüber unter dem Namen.

### 13.7 Was sich ändert

`select_list_bottom_sheet.dart` wird ein echtes `AppSheet` (heute zentrierter Dialog, 88 % breit, Zutatenliste max. 220 pt, blauer Akzent, `PopScope`-Sperre, Erfolgs-HUD). Die Logik wandert in einen Dienst `RecipeToList` (Teil A, E-07), den Avo (B) und der Wochenplan (B) mitbenutzen, damit Ersatz, Rundung und Zusammenführen überall gleich sind (heute eigene Avo-Logik ohne Ersatz, Inv-D 4.1, 4).

### 13.8 Bildbeschreibung für ChatGPT

iPhone-Screen, unten ein schwebendes Sheet in mittlerer Höhe mit milchigem Liquid-Glass-Hintergrund und Eckenradius passend zum Gerät, darüber abgedunkelt das Rezeptdetail mit dem Gemüsefoto. Im Sheet oben ein grauer Griff, links ein runder Knopf mit X, mittig fett "Zutaten auf Liste". Darunter eine weiße Sektion mit den Zeilen "Liste" (rechts ein kleiner blauer Kreis mit weißem Einkaufswagen und "Wocheneinkauf" mit Doppel-Chevron) und "Portionen" (rechts grauer Kapsel-Stepper "− 2 +"). Dann die Sektion "Zutaten" mit rechts grau "8 von 11": Zeilen mit grün gefüllten Kreisen #3F7A1F und weißem Häkchen ("Kartoffeln, festkochend 500 g", "rote Paprika 1" mit gelbem Schild #FFD60A "0,79 €", "laktosefreier Hirtenkäse 200 g" mit grauer Unterzeile "statt Feta · wegen Laktose") und drei Zeilen mit leerem grauem Ring #8A8A8E ("Olivenöl" mit Unterzeile "Schon auf Wocheneinkauf (1 Flasche)", "Salz" und "Pfeffer" mit "Hast du meist da"). Ganz unten eine breite grüne Kapsel #3F7A1F mit weißem Text "8 Zutaten hinzufügen". Keine Icons in getönten Quadraten, kein Blau als Akzent.

---

## 14. Varianten (R-12 und Editor-Modus)

Status: **`hidden`** bis Melden, Blockieren und eine Prüf-Warteschlange stehen (Q-01). Datenbasis: Tabellen `recipe_variations` und `recipe_variation_votes` in `database/migrations/new_recipe_features.sql` (App-Code gelöscht in 38ce871; Anlage in Supabase vor dem Bau prüfen).

### 14.1 Sektion im Detail

Siehe 12.1 Nr. 9. Sortierung: "hilfreich" absteigend, dann neu. Höchstens 2 Zeilen im Detail.

### 14.2 R-12 Sheet "Variante" (groß)

- **Zweck:** "Was ist bei dieser Abwandlung anders, und will ich sie?" Einstieg: Zeile in der Varianten-Sektion, "Alle 3 Varianten" (dann zuerst eine Liste aller Varianten im selben Sheet, Push im Sheet).
- **Aufbau:** Kopf `xmark`, Inline-Titel "Variante", rechts `ellipsis` ("Melden", bei eigener "Bearbeiten", "Löschen"). Titel `title2` "Mit Halloumi statt Feta", Metazeile "von Deniz Aydın · vor 5 Tagen". Kurzer Text des Erstellers (`body`). Sektion "Was anders ist": je Änderung eine Zeile mit `arrow.left.arrow.right`: "Halloumi 200 g" mit Unterzeile "statt Feta 200 g"; "Schritt 4" mit Unterzeile "Halloumi in Scheiben, nicht zerbröseln; 8 statt 10 Minuten". Allergie-Prüfung nach 2.3 gilt auch hier (Halloumi = Milch). Darunter eine Zeile in eigener `InsetSection`: `hand.thumbsup` (E-12) und "Hilfreich" links, rechts die Zahl "41" (`number`, `labelSecondary`). Tippen schaltet um: Symbol wird `hand.thumbsup.fill` in `action`, die Zahl rollt auf "42" (`springDigits`), keine Haptik; erneutes Tippen nimmt es zurück (eine Richtung, keine Abwertung, Q-01). VoiceOver: "Hilfreich, 41, Taste, nicht ausgewählt". Hauptaktion prominent "Diese Variante kochen" und schlicht "Zutaten dieser Variante auf Liste".
- **Wirkung:** "Diese Variante kochen" schließt das Sheet und schaltet das Detail auf die Variante: unter dem Titel eine Zeile `arrow.triangle.branch` "Variante: Mit Halloumi statt Feta · Original zeigen"; Zutaten, Schritte, Kochmodus und R-11 nutzen die Variante. Gemerkt wird pro Rezept, welche Fassung zuletzt gewählt war.
- **Zustände:** offline "Braucht eine Verbindung" (nur im Cache gesehene Varianten bleiben lesbar); gemeldet und ausgeblendet: Zeile verschwindet für den Meldenden sofort; Variante inzwischen gelöscht: Satz "Diese Variante gibt es nicht mehr." mit schlicht "Zum Original"; war sie im Detail gewählt, schaltet das Detail auf das Original zurück, Status-Hinweis "Variante nicht mehr verfügbar".
- **AX/320:** Änderungs-Zeilen stapeln; Knöpfe untereinander.
- **Bildbeschreibung für ChatGPT:** iPhone-Screen mit einem großen Sheet auf #F2F2F7, oben ein Griff, links ein Glas-Knopf mit X, mittig "Variante", rechts drei Punkte. Fetter Titel "Mit Halloumi statt Feta", darunter grau #636366 "von Deniz Aydın · vor 5 Tagen" und ein Absatz schwarzer Text "Halloumi wird im Ofen schön braun und bleibt in Form." Eine weiße Sektion "Was anders ist" mit zwei Zeilen mit Tausch-Pfeilen: "Halloumi 200 g" mit grauer Unterzeile "statt Feta 200 g" und "Schritt 4" mit Unterzeile "Halloumi in Scheiben, 8 statt 10 Minuten". Darunter eine Zeile mit Daumen-hoch-Symbol "Hilfreich" und grau "41". Unten eine breite grüne Kapsel #3F7A1F "Diese Variante kochen" und darunter grüner Text "Zutaten dieser Variante auf Liste".

### 14.3 Variante vorschlagen

"Variante vorschlagen" öffnet R-15 im Modus Variante (`/recipes/add?variationOf=<id>`): zweite Titelzeile "Variante · 1 von 4" (17.2), in Schritt 1 über dem Feld der Sektionstitel "Variante von „Ofengemüse mit Feta“", Schritt 1 nur mit Titel der Variante und einem Satz, Schritte 3 und 4 mit den Original-Zutaten und -Schritten vorbefüllt; geänderte Zeilen werden mit `arrow.left.arrow.right` markiert, das Diff entsteht automatisch. Zeiten und Portionen (Schritt 2) übernommen und änderbar. Abschluss "Variante teilen". Eigene Rezepte haben keinen Varianten-Vorschlag, sondern "Bearbeiten".

---

## 15. R-13 Kommentare

Status: **`hidden`** wie Varianten (Q-01). Datenbasis: `recipe_comments` (`database/migrations/add_recipe_comments.sql`, max. 500 Zeichen). Mitteilungstyp `recipe_comment` öffnet dieses Sheet (01 8.2).

- **Zweck:** "Was sagen andere, die es gekocht haben?" Einstieg: "Alle Kommentare" im Detail, Mitteilung.
- **Aufbau (`AppSheet` groß):** Kopf `xmark`, "Kommentare". Liste neueste zuerst: Avatar 28, Name `headline`, Zeit `caption1`, Text `body` `label` (markierbar). Eigene Kommentare: Kontextmenü "Bearbeiten", "Löschen" (mit Rückgängig, weil es der eigene ist und sofort wiederherstellbar). Fremde: "Melden", "Person blockieren". Unten ein Eingabefeld in Kapselform (`fill`, nicht Glas, da Inhalt eines Sheets) "Kommentar schreiben" mit Senden-Knopf `arrow.up.circle.fill` in `action`, wächst bis 5 Zeilen, Zähler "120/500" erst ab 400 Zeichen.
- **Zustände:** leer "Noch keine Kommentare. Hast du es gekocht? Erzähl, wie es war."; offline: Lesen aus Cache, Senden in die Warteschlange mit Sync-Zeichen; Senden fehlgeschlagen: Zeile mit "Nicht gesendet · Erneut versuchen".
- **Interaktion:** Senden fügt den Kommentar sofort oben ein (`springStandard`), keine Haptik.
- **AX/320:** Avatar bleibt, Text bricht um; Feld wächst.
- **Bildbeschreibung für ChatGPT:** iPhone-Screen mit großem Sheet auf #F2F2F7, oben Griff, links runder Glas-Knopf mit X, mittig fett "Kommentare". Eine weiße Sektion mit drei Kommentaren: rundes Porträt 28 pt, fetter Name ("Lena Wolf", "Tim Berger", "Aylin Kaya"), grau #636366 "vor 2 Std.", darunter schwarzer Text wie "Mit Süßkartoffeln statt Kartoffeln auch super, 5 Minuten länger backen." Unten über der Tastatur ein graues Kapselfeld #E9E9EE "Kommentar schreiben" mit grünem runden Pfeil-nach-oben-Knopf #3F7A1F.

---

## 16. R-14 Kochmodus

**Zweck:** "Was mache ich jetzt gerade?" Einstieg: "Kochen" bzw. "Weiter: Schritt 3" im Detail, "Weiter kochen" in R-01, Mitteilung eines Kochtimers, Avo ("Starte den Kochmodus für Ofengemüse"), Route `/recipes/:id/cook` (heute ohne Route, Inv-D 2.6).

### 16.1 Grundregeln

- Vollbild-Cover, **immer schwarz** (`cookingBg`), unabhängig von Hell/Dunkel (K-25). Text `cookingLabel` (#FFFFFF), Metadaten `cookingSecondary` (#98989F), Akzent immer in der Dunkel-Variante (`action` #A6D45F, `onAction` #0E1A06), Flächen `cookingSurface` #1C1C1E und `cookingFill` #2C2C2E (E-04).
- Bildschirm bleibt an, solange der Kochmodus vorn ist; beim Schließen und im Hintergrund wird die Sperre freigegeben.
- **Kein Verlassen-Dialog.** `chevron.down` schließt sofort; Fortschritt (Seite, abgehakte Zutaten, Portionen, laufende Timer, gewählte Fassung) bleibt 24 h pro Rezept gespeichert (lokal). Beim nächsten Öffnen: direkt an der alten Stelle, oben einmalig `StatusRow`-Form "Weiter bei Schritt 3 · Von vorn" (schlicht).
- Es gilt die Fassung aus dem Detail (angepasst oder Original, Variante) und die dort gewählte Portionenzahl (heute Original und eigene Portionen, Inv-D 4.1, 4 und 11).
- Avo-Kreis bleibt unten rechts an seiner Stelle (01 Kap. 3); die Tab-Kapsel ist ausgeblendet (E-01).

### 16.2 Aufbau

1. **Toolbar oben** (eine Glas-Gruppe, `regular` auf Schwarz): links `chevron.down` ("Kochmodus schließen"); mittig Inline-Titel in zwei Zeilen: Rezeptname (`subheadline` Semibold `cookingLabel`, eine Zeile, Ellipse) und "Schritt 3 von 5" (`footnote` `cookingSecondary`); rechts Text-Kapsel "2 Portionen" (öffnet Portionen-Sheet) und `list.bullet` (Übersicht).
2. **Fortschrittslinie** unter der Toolbar: 2 pt, Spur `cookingFill`, Wert `cookingLabel` (00 4.2: Fortschritt in Textfarbe), Länge = aktueller Schritt / Schrittanzahl (Seite "Zutaten" = leer, Schritt 3 von 5 = drei Fünftel, Seite "Fertig" = voll), folgt mit `springDigits`.
3. **Seiten** (waagerecht blätternd, eine Seite pro Bildschirm):
   - **Seite "Zutaten"** (immer zuerst): Titel `title1` "Zutaten bereitlegen", Unterzeile `callout` `cookingSecondary` "für 2 Portionen". Darunter `InsetSection` auf `cookingSurface`: jede Zutat eine Zeile mit `CheckCircle` (24 pt in 44-pt-Ziel, leer Ring #7C7C80, erledigt gefüllt #A6D45F mit Häkchen #0E1A06), Name `body`, Menge `number` rechts; abgehakte Zeilen durchgestrichen in `cookingSecondary`, sie **bleiben stehen** (nichts wandert im Kochmodus). Sektionsfuß schlicht "Alle abhaken"; sind alle abgehakt, heißt er "Alle zurücksetzen". Angepasste Zutaten mit `arrow.left.arrow.right` und "statt Feta".
   - **Schritt-Seiten:** oben `headline` `cookingSecondary` "Schritt 3"; Schritttext `title1` **Regular** 28 pt in `cookingLabel`, linksbündig (heute 18 pt zentriert, Inv-D 3.2), Zeilenhöhe nach 00 5.3; erkannte Zeiten im Text unterstrichen in `action` und antippbar (startet denselben Timer wie der Knopf darunter; 44-pt-Trefferfläche um das Wort). Schritttext in der gewählten Fassung (12.1 Nr. 8: ersetzte Zutaten auch im Text). Darunter Sektion "Dafür" (`headline`), Zeilen `body` der Zutaten, die im Schritt vorkommen ("3 EL Olivenöl", "1 TL Oregano", "Salz, Pfeffer"), ohne Abhaken. Darunter, wenn eine Zeit erkannt ist, `AppButton` grau (auf `cookingFill`) `timer` "Timer 15 Min" (bei Bereichen "10–15 Minuten": "Timer 10 Min" und ein Menü am Knopf mit "15 Min"). Läuft der Timer dieses Schritts, steht an der Stelle des Knopfs schlicht `cookingSecondary` "Timer läuft" (kein zweiter Start).
   - **Seite "Fertig"** (nach dem letzten Schritt): `title1` "Guten Appetit." Darunter `InsetSection` mit: Zeile "Bewerten" mit 5 Sternen (nicht bei eigenem Rezept), mit Modul Kalorien `NavRow` `flame` "Ins Tagebuch eintragen" (Slot B), `NavRow` `square.and.arrow.up` "Rezept teilen". Kein Maskottchen (Arbeits-Screen), keine Konfetti.
4. **Steuerung unten** (eine Glas-Gruppe auf Schwarz, `regular`): links Kreis `chevron.left` ("Vorheriger Schritt", auf Seite "Zutaten" deaktiviert); Mitte die **Timer-Kapsel** (nur wenn ein Timer läuft): `timer` + "Schritt 3 · 12:47" in `numberL` tabellarisch; rechts getönte Kapsel "Weiter" (`action`) bzw. auf der letzten Schritt-Seite "Fertig", auf der Seite "Fertig" "Schließen". Daneben, abgesetzt, der Avo-Kreis.
5. Scroll innerhalb einer Seite senkrecht, wenn der Text länger als der Bildschirm ist; Scroll-Edge-Verlauf in Schwarz oben und unten.

### 16.3 Sheets und Menüs im Kochmodus

- Solange ein Sheet oder Menü offen ist, tritt die Steuerung unten zurück (aus dem Baum bzw. vom Menü optisch ersetzt), damit kein Glas auf Glas liegt (2.5).
- **Portionen** (`AppSheet` mittel, dunkel erzwungen): `ValueStepper` 1 bis 20 (gleiche Grenzen wie im Detail, heute Raster 1 bis 6, 8, 10, 12, Inv-D 11), darunter Vorschau zweier Mengen, die rollen ("Kartoffeln 750 g", "Hirtenkäse 300 g"). Wirkt sofort, abgehakte Zutaten **bleiben abgehakt** (heute zurückgesetzt).
- **Übersicht** (`list.bullet`, `AppSheet` mittel): Zeilen "Zutaten", "1 Ofen vorheizen …", … mit Häkchen an besuchten Seiten; Tippen springt dorthin.
- **Timer-Menü** (Tippen auf die Timer-Kapsel, `AppMenu` aus der Kapsel): je laufendem Timer eine Gruppe "Schritt 3 · 12:47" mit "Pausieren"/"Fortsetzen", "+1 Min", "Stoppen" (`danger`, ohne Rückfrage; entfernt auch die geplante Mitteilung). Mehrere Timer gleichzeitig sind erlaubt (heute einer); die Kapsel zeigt den, der zuerst abläuft, plus "+1".
- **Timer abgelaufen:** Die Kapsel zeigt `checkmark.circle.fill` + "Schritt 3 fertig" in `cookingLabel`, bleibt ungetönt (die eine Tönung der Leiste gehört "Weiter", 00 8.2) und wächst einmal kurz (Skalierung 1,08 und zurück, `springQuick`; Reduce Motion: ohne). Dazu System-Ton der Mitteilung und Haptik "Warnung" (E-13); kein blockierender Dialog (heute nicht wegtippbar, Inv-D 2.6). Tippen auf die Kapsel quittiert. VoiceOver sagt "Timer Schritt 3 abgelaufen" an. Ist die App im Hintergrund: zeitkritische Mitteilung "Ofengemüse mit Feta: Schritt 3 fertig." mit Aktion "+1 Min" (01 8.2, E-14). Restzeit immer nach Wanduhr.

### 16.4 Zustände

| Zustand | Verhalten |
|---|---|
| Erster Start im Kochmodus | Einmalig unter der Fortschrittslinie: "Der Bildschirm bleibt an. Wisch zwischen den Schritten." (`footnote`, verschwindet beim ersten Wischen). |
| Lädt | nie: Daten kommen aus dem Detail bzw. Cache. Per Mitteilung oder Deep Link ohne Cache: Detail-Ladezustand (12.3), dann Cover. |
| Rezept ohne Schritte | nur Seite "Zutaten" und "Fertig"; "Weiter" führt direkt zu "Fertig". |
| Sehr langer Schritt | senkrechtes Scrollen in der Seite; "Weiter" bleibt erreichbar. |
| Offline | ohne Einschränkung (alles lokal); keine `StatusRow` nötig, außer beim Bewerten auf "Fertig" (Warteschlange). |
| Modul Kalorien aus | "Ins Tagebuch" auf "Fertig" entfällt. |
| Avo aus | Kreis zeigt `magnifyingglass` (globale Suche); bleibt an derselben Stelle. |
| Fortschritt älter als 24 h | verworfen; Kochmodus beginnt bei "Zutaten". |
| Rezept inzwischen gelöscht | Ein offener Kochmodus bleibt mit der lokalen Fassung nutzbar, bis man ihn schließt; danach verschwindet "Weiter kochen", Timer laufen zu Ende. |

### 16.5 Interaktionen, Bewegung, Haptik

- **Wischen** zwischen Seiten folgt dem Finger 1:1; an der ersten und letzten Seite Gummiband; Loslassen mit Wurfprojektion entscheidet, `springFling`. Auswahl-Haptik, wenn eine Seite nach Wischen einrastet; keine Haptik bei "Weiter"/"Zurück" per Tippen (normale Knöpfe).
- **Weiter** auf der Seite "Zutaten", obwohl nicht alles abgehakt ist: kein Hinweis, kein Blockieren.
- **Abhaken** einer Zutat: Kreis füllt sich (`springQuick`), leichter Impuls (00 Kap. 11, "Abhaken").
- **Timer starten:** Knopf "Timer 15 Min" morpht in die Timer-Kapsel unten (`springMorph`, Herkunft am Auslöser); keine Haptik. Ziffern wechseln sekündlich, sie rollen nicht (00 12.15).
- **Avo per Stimme:** Avo-Kreis halten: "Weiter", "Zurück", "Timer 10 Minuten", "Wie viel Öl?" (B-Werkzeuge, E-07). Anders als sonst (00 12.33) öffnet Halten hier **kein** großes Sprachmodus-Sheet, weil es den Schritt verdecken würde: Der Kern im Kreis geht in `hoertZu`, das Transkript erscheint als eine Zeile `footnote` `cookingSecondary` unter der Fortschrittslinie, Loslassen sendet (E-20, Q-17). Ergebnis als kurze gesprochene Antwort, die Seite wechselt mit derselben Feder wie beim Tippen. Tippen auf den Kreis öffnet wie überall das Feld "Frag Avo".
- **Reduce Motion:** Seitenwechsel als Überblendung; Morph der Timer-Kapsel als Einblenden.
- **VoiceOver:** Schritttext als Überschrift der Seite; eigene Aktionen "Nächster Schritt", "Vorheriger Schritt", "Timer starten"; Timer-Ablauf wird angesagt ("Timer Schritt 3 abgelaufen"). Drei-Finger-Wischen blättert.

### 16.6 Pro gesperrt (falls der Owner den Kochmodus zu Pro macht, F-10)

Echte Vorschau (00 16.2): Der Kochmodus öffnet; Seite "Zutaten" und Schritt 1 sind voll nutzbar; "Weiter" auf Schritt 1 trägt eine `ProBadge` und öffnet die Paywall als Sheet aus der Kapsel (`springMorph`) mit "Kochmodus" oben. Nach dem Kauf geht es auf Schritt 2 weiter. Nie ein Schloss-Bildschirm, nie ein Pro-Hinweis mitten im Kochen ohne Anlass (00 16.5: nie im Kochmodus; die Badge an "Weiter" ist die Sperre selbst, kein Hinweis).

### 16.7 Große Schrift und 320 pt

- Schritttext wächst wie Title 1 bis 58 pt (AX5); bricht um; Seite scrollt senkrecht.
- 320 pt: Steuerung = `chevron.left` (44) + Timer-Kapsel nur mit Zeit "12:47" + "Weiter" als Kreis `chevron.right` (44) getönt + Avo-Kreis; Portionen-Kapsel oben wird zum Symbol `person.2` mit Zahl.
- Ab AX1: Inline-Titel oben zeigt nur "3 von 5"; Rezeptname entfällt dort (steht in der Übersicht). Seite "Zutaten" randlos (2.7), Menge unter dem Namen, Abhak-Kreis oben bündig zur ersten Textzeile. "Dafür"-Zeilen stapeln Menge unter Name. "Timer 15 Min" bricht um und wächst in der Höhe. Glas-Knöpfe mit Large Content Viewer, Beschriftungen auf xxxL gedeckelt (E-19).
- Keine festen Höhen (heute Fußleiste 48 pt mit `FittedBox`, die Text verkleinert, Inv-D 3.2).

### 16.8 Was sich ändert, betroffene Dateien

`cooking_mode_screen.dart` neu (Route statt `MaterialPageRoute`, Wischen statt `NeverScrollableScrollPhysics`, mehrere Timer, Fortschritt gespeichert, Dialoge entfallen, keine Verlaufskreise mit Schatten, kein `RecipeEditorPalette`), `step_progress_ring.dart` entfällt (Fortschrittslinie), `recipe_editor_palette.dart` entfällt (Tokens `cooking*`), `NotificationService` (zeitkritische Kategorie, Aktion "+1 Min", mehrere IDs statt 700100), Timer-Erkennung neu (Minuten, Stunden, Sekunden, Bereiche, Dezimal "1,5 Std.", Deutsch und Englisch; heute nur "x Minuten/min", Inv-D 12).

### 16.9 Bildbeschreibung für ChatGPT

iPhone-Screen komplett schwarz #000000, ein Kochmodus wie von Apple. Oben eine milchige dunkle Liquid-Glass-Gruppe: links ein runder Knopf mit Chevron nach unten, mittig zweizeilig "Ofengemüse mit Feta" in Weiß und "Schritt 3 von 5" in Grau #98989F, rechts eine Glas-Kapsel "2 Portionen" und ein Listen-Symbol; darunter eine dünne weiße Fortschrittslinie, drei Fünftel gefüllt, auf dunkelgrauer Spur #2C2C2E. In der Mitte linksbündig in Grau "Schritt 3" und darunter großer weißer Text in 28 pt Regular: "Alles mit Olivenöl, Oregano, Salz und Pfeffer mischen, auf einem Blech verteilen und 15 Minuten backen.", wobei "15 Minuten" in hellem Grün #A6D45F unterstrichen ist. Darunter fett "Dafür" und weiße Zeilen "3 EL Olivenöl", "1 TL Oregano", "Salz, Pfeffer", dann in Grau #98989F der kurze Text "Timer läuft". Unten schwebt eine dunkle Glas-Gruppe: links runder Knopf mit Chevron nach links, in der Mitte eine Kapsel mit Timer-Symbol und "Schritt 3 · 14:12" in weißen abgerundeten Ziffern, rechts eine hellgrün getönte Kapsel #A6D45F mit dunkler Schrift #0E1A06 "Weiter"; abgesetzt ganz rechts der runde Glas-Knopf mit brauner Kugel #8A5A30 in hellgrünem Ring #C9DE6E. Keine Karten mit Rahmen, keine Verlaufskreise, kein Maskottchen.

---

## 17. R-15 Rezept-Editor

**Zweck je Schritt:** 1 "Wie heißt es, und wie sieht es aus?" · 2 "Wie lange, für wie viele, wie schwer?" · 3 "Was kommt rein?" · 4 "Wie geht es, und wer darf es sehen?" Einstieg: `plus` in R-01 und R-08, Entwurf in R-09, "Bearbeiten" im Detail, "Variante vorschlagen" (14.3), "Eigenes Rezept schreiben" in der leeren Suche.

### 17.1 Grundregeln

- **Vollbild-Cover ohne Tab-Bar und ohne Avo-Kreis** (01 Kap. 3; heute mit Tab-Bar und fester 60-pt-Verschiebung der Fußleiste, Inv-D 35).
- **Automatischer Entwurf:** Jede Änderung wird 1 s nach der letzten Eingabe lokal gespeichert und ins Konto synchronisiert (E-05); Fotos werden sofort in den App-Speicher kopiert (wie heute `RecipeDraftImages`) und im Hintergrund in einen privaten Speicherbereich geladen. Ein Entwurf entsteht erst, wenn mindestens ein Feld Inhalt hat.
- **Kein Dialog "Entwurf speichern?"** (01 5.4): `xmark` schließt sofort. Hat der Entwurf Inhalt, erscheint danach `UndoToast` als reiner Status "Als Entwurf gespeichert" (das Ergebnis ist sonst nicht sichtbar, 00 12.28). "Entwurf verwerfen" steht im `ellipsis`-Menü mit `confirmDestructive`.
- **Bearbeiten eines veröffentlichten Rezepts** erzeugt einen Entwurf mit Bezug (`recipeId`); Abschluss heißt "Änderungen speichern" und aktualisiert dasselbe Rezept (heute entsteht beim Veröffentlichen aus einem solchen Entwurf ein Duplikat ohne Bild, Inv-D 8). Das vorhandene Foto bleibt erhalten.
- **Änderungserkennung** umfasst alle Felder inklusive Mengen, Einheiten, Bild und Reihenfolge (Inv-D 7).
- **Foto ist optional.** Ohne Foto erscheint das Rezept als Typo-Karte (00 9.6). Heute Pflicht (Inv-D 2.7).
- **Validierung am Feld**, nicht per Snackbar: "Weiter" ist immer tippbar; fehlt Pflichtinhalt, springt der Fokus zum Feld, darunter erscheint ein Satz in `danger` mit `exclamationmark.circle` ("Gib dem Rezept einen Namen."), Haptik "Fehler".

### 17.2 Aufbau (alle Schritte)

1. **Toolbar oben** (Glas-Gruppe): links `xmark`; rechts `ellipsis` (Menü: "Vorschau" (öffnet das Detail in der aktuellen Fassung als Sheet groß), "Entwurf verwerfen" in `danger`). Mittig Inline-Titel als Schritt-Umschalter: "Zutaten" + `chevron.down`, darunter `footnote` `labelSecondary` mit Modus und Stand: "Neues Rezept · 3 von 4", "Bearbeiten · 3 von 4" bzw. "Variante · 3 von 4" (Wayfinding: man sieht immer, was man gerade schreibt); Tippen öffnet ein `AppMenu` mit den vier Schritten (erledigt mit `checkmark`, unvollständig mit `exclamationmark.circle` in `labelSecondary`), Tippen springt (Muster des Listen-Umschalters, 00 12.2).
2. **Fortschrittslinie** 2 pt unter der Toolbar, Wert `label`, Spur `fill`.
3. **Inhalt** auf `bgGrouped`, scrollt.
4. **Fußbereich** am unteren Rand, auf der Tastatur sitzend, wenn sie offen ist: `AppButton` grau "Zurück" (ab Schritt 2) und prominent "Weiter" bzw. im letzten Schritt "Veröffentlichen" / "Speichern" (nach Sichtbarkeit) / "Änderungen speichern" / "Variante teilen". Fester Bereich ohne Glas, mit Scroll-Edge-Verlauf aus `bgGrouped` (00 8.1 nennt den Editor nicht als Glasstelle).

### 17.3 Schritt 1 "Foto und Name"

- `InsetSection` mit Foto-Fläche 4:3 oben in voller Sektionsbreite (oben `radiusSection`): leer = Fläche `fill`, mittig `camera` 48 pt Light und schlicht "Foto hinzufügen"; Tippen öffnet `AppMenu` "Foto aufnehmen" (Kamera, heute fehlt sie, Inv-D 19), "Aus Fotos wählen". Mit Foto: Menü "Foto ersetzen", "Ausschnitt ändern" (System-Zuschnitt 4:3), "Foto entfernen" (mit Rückgängig). Fotos werden mit bis zu 2.000 px kurzer Seite gespeichert (heute auf 1.080 px Höhe verkleinert, Inv-D 19); ist das Original kleiner als 600 px, erscheint ein Satz unter dem Foto "Das Foto ist klein und wird als Textkarte gezeigt." (00 9.6); `photo_color` wird beim Speichern berechnet.
- Feld "Name" (`title3`, Platzhalter "Zum Beispiel Omas Kartoffelsalat"), Pflicht.
- Feld "Beschreibung" (`body`, mehrzeilig bis 6 Zeilen, Platzhalter "Ein, zwei Sätze, worum es geht", optional; heute gibt es das Feld nicht, Inv-D 15).
- Im Modus Variante: Feld "Was ist anders?" (Pflicht) statt Beschreibung; kein Foto nötig.

### 17.4 Schritt 2 "Zeiten und Portionen"

`InsetSection` mit Zeilen:
- "Vorbereitung" Wert "10 Min" und "Garzeit" Wert "25 Min": Tippen klappt unter der Zeile eine Dauer-Auswahl (Stunden und Minuten, Systemmuster der Timer-Dauer in der Uhr-App) mit `springStandard` auf; die Summe steht im Sektionsfuß "Insgesamt 35 Min".
- "Portionen" mit `ValueStepper` (Standard 2, nicht 4; Q-06).
- "Schwierigkeit" mit `SegmentedControl` "Einfach | Mittel | Anspruchsvoll" (wird als Label `easy` / `medium` / `advanced` gespeichert, dieselben IDs wie die Filter in 5.1).
Keine Icons in getönten Quadraten, keine 50-pt-Zahlenfelder (Inv-D 3.2).

### 17.5 Schritt 3 "Zutaten"

- `InsetSection` "Zutaten", jede Zutat eine Zeile mit **einem** Textfeld (`body`): Eingabe "200 g Feta" wird beim Tippen mit demselben Parser wie im Accessory (00 12.4) in Menge, Einheit und Name zerlegt; die Unterzeile zeigt das Ergebnis "200 g · Feta" (`subheadline`, `labelSecondary`). "Salz nach Geschmack", "1 Prise Muskat", "½ TL Kreuzkümmel", "1,5 l Brühe", "1/2 Zitrone" sind gültig. Menge ist keine Pflicht (Inv-D 9).
- Return legt eine neue Zeile darunter an und setzt den Fokus dorthin; Return in einer leeren letzten Zeile schließt die Tastatur.
- Unter der letzten Zeile schlicht `plus` "Zutat hinzufügen".
- Wischen nach links "Löschen" (sofort, `UndoToast` "Feta entfernt · Widerrufen"); Langdruck hebt die Zeile zum Umsortieren (00 10.3).
- Unklare Zeile (Parser findet keinen Namen): Unterzeile `questionmark.circle` "Name fehlt" in `labelSecondary`.
- Einfügen eines ganzen Textblocks (mehrere Zeilen aus Notizen) legt je Zeile eine Zutat an.
- Pflicht: mindestens eine Zutat.

### 17.6 Schritt 4 "Zubereitung und Sichtbarkeit"

- `InsetSection` "Zubereitung": Zeilen mit Nummer (`numberS` `labelSecondary`) und mehrzeiligem Feld (`body`, wächst ohne Begrenzung; heute `maxLines: 2`, Inv-D 3.2). Erkannte Zeiten zeigen in der Unterzeile `timer` "Timer 15 Min im Kochmodus". Return erzeugt einen Zeilenumbruch; schlicht `plus` "Schritt hinzufügen" legt den nächsten Schritt an. Wischen löscht mit Rückgängig, Langdruck sortiert um. Pflicht: mindestens ein Schritt.
- `InsetSection` "Wer sieht das Rezept?" mit zwei Auswahlzeilen (Kreis wie Paywall-Pläne): "Alle in der Community" mit Unterzeile "Erscheint unter deinem Namen: Jannis D." (schlicht "Namen ändern" → `/settings/profile`) und "Nur ich" mit Unterzeile "Nur in Meine Rezepte". Standard nach Q-03. Ohne Anzeigenamen wird nie die E-Mail-Adresse veröffentlicht (Inv-D 20): Wahl "Alle" verlangt dann zuerst einen Namen (Zeile in `warning`-Symbol + Text "Lege zuerst einen Namen fest").
- Im Modus Bearbeiten steht die Sichtbarkeit wie gespeichert; im Modus Variante entfällt die Sektion (Varianten sind öffentlich).

### 17.7 Veröffentlichen

1. Tippen auf "Veröffentlichen": Cover schließt mit `springSheet` nach unten; der Tab Rezepte pusht sofort das Detail des neuen Rezepts aus der lokalen Fassung auf den Stapel, von dem man kam (kein Spinner, kein `pushReplacement` ohne Daten, Inv-D 27). Käme das Detail dadurch auf Ebene 4 (Start aus Rezepte > Meine Rezepte > Entwürfe), ersetzt es die Seite "Entwürfe", deren Zeile ohnehin verschwindet (2.6).
2. Upload (Foto, Rezept, automatische Labels, Allergen-Tags) läuft im Hintergrund. Haptik "Erfolg" und `UndoToast` reiner Status "Veröffentlicht" erst nach Bestätigung durch den Server.
3. Fehlschlag: `StatusRow` oben im Detail "Noch nicht veröffentlicht. Erneut versuchen"; der Entwurf bleibt erhalten, bis der Server bestätigt; danach wird er samt Foto gelöscht.
4. Bearbeiten: Cover schließt, das Detail zeigt die neue Fassung sofort (`springStandard` für geänderte Zeilen), Status "Änderungen gespeichert".
5. Ersetzte Fotos werden aus dem Speicher gelöscht (heute nie, Inv-D 18).

### 17.8 Zustände

| Zustand | Verhalten |
|---|---|
| Neu, leer | Schritt 1 mit leerem Foto und fokussiertem Namensfeld; kein Entwurf, solange nichts eingegeben ist. |
| Entwurf öffnen | sofort aus dem lokalen Stand (heute Vollbild-Spinner, Inv-D 2.7). |
| Bearbeiten öffnen | sofort aus dem Detail-Cache. |
| Offline | alles bearbeitbar; "Veröffentlichen" legt in die Warteschlange, Detail zeigt `StatusRow` "Wird veröffentlicht, sobald du online bist." |
| Auf anderem Gerät geändert | `StatusRow` unter der Toolbar "Zuletzt auf iPhone 15 geändert, vor 5 Min." (11.2). |
| Fehler beim Speichern des Entwurfs | lokal immer erfolgreich; nur der Abgleich kann scheitern, dann `arrow.triangle.2.circlepath` neben dem Schritt-Titel, kein Hinweis-Lärm. |
| Pro | nie gesperrt (Kern). |

### 17.9 Interaktionen, Bewegung, Haptik

Schrittwechsel per "Weiter"/"Zurück" als seitliche Bewegung mit `springStandard` (heute 300 ms `easeInOut`); Zurück-Wischen vom linken Rand geht einen Schritt zurück (nicht aus dem Cover). Reduce Motion: Überblendung. Haptik nur bei Validierungsfehler (Fehler) und Veröffentlichen (Erfolg); keine Haptik beim Hinzufügen von Zeilen (heute leichter Impuls je Zeile, Inv-D 3.1).

### 17.10 Große Schrift und 320 pt

- Zutatenzeile hat nur ein Feld, deshalb keine Spaltenbreiten (heute Menge 50 pt, Einheit 70 pt, Inv-D 3.2); die Unterzeile bricht um.
- Ab AX1: Fußbereich stellt "Zurück" und "Weiter" untereinander (00 6.4); Schritt-Umschalter zeigt nur "3 von 4" mit Chevron.
- Foto-Fläche 4:3 aus der Breite, keine feste Höhe (heute 180 pt).
- 320 pt: alles einspaltig; Dauer-Auswahl in voller Breite. Passt "Einfach | Mittel | Anspruchsvoll" nicht in die Breite (auf 320 pt schon ab Textgröße L knapp), wird es ein Pull-down-Menü "Schwierigkeit: Einfach" mit `chevron.up.chevron.down` (00 12.18).
- Der zweizeilige Inline-Titel bricht nicht um, sondern kürzt ab AX1 auf "3 von 4" (s. o.); der Modus steht dann in VoiceOver ("Neues Rezept, Schritt 3 von 4, Zutaten").

### 17.11 Was sich ändert, betroffene Dateien

`multi_step_recipe_screen.dart` neu (Cover-Route `/recipes/add` mit `fullscreenDialog`, ohne Tab-Bar; vier Schritte bleiben), `recipe_draft_service.dart` (lokale Datenbank plus Konto-Sync), `recipe_draft_images.dart` (bleibt, plus Upload), `recipe_service.dart` (`createRecipe` ohne E-Mail als Autorname, `updateRecipe` aus Entwurf mit `recipeId`, Bild löschen, Sichtbarkeit), `step_progress_ring.dart` und `recipe_editor_palette.dart` entfallen; Übersetzungen `save_draft_question*`, `image_required_error`, `invalid_amount_error` entfallen.

### 17.12 Bildbeschreibung für ChatGPT

iPhone-Screen hell, Hintergrund #F2F2F7, Vollbild ohne Tab-Bar, Tastatur unten offen. Oben links ein runder milchiger Glas-Knopf mit X, rechts einer mit drei Punkten, in der Mitte fett "Zutaten" mit kleinem Chevron nach unten und darunter grau #636366 "Neues Rezept · 3 von 4", darunter eine dünne schwarze Fortschrittslinie #000000 zu drei Vierteln auf grauer Spur #E9E9EE. Eine weiße Sektion mit 26 pt Radius "Zutaten" mit Zeilen, in denen man frei tippt: "500 g Kartoffeln" mit grauer Unterzeile #636366 "500 g · Kartoffeln", "200 g Feta" mit "200 g · Feta", "Salz nach Geschmack" mit "Salz · nach Geschmack", die letzte Zeile mit blinkendem Cursor "1 TL Oreg"; darunter grüner Text #3F7A1F mit Plus "Zutat hinzufügen". Direkt über der Tastatur ein Fußbereich mit einer grauen Kapsel #E9E9EE "Zurück" und einer grünen Kapsel #3F7A1F mit weißem Text "Weiter". Keine Icons in getönten Kreisen, keine kleinen Zahlenfelder.

---

## 18. Kleine Dialoge, Menüs und Slots

### 18.1 Toolbar-Menü im Detail (`ellipsis`, `AppMenu` aus dem Knopf)

| Eintrag | Symbol | Wann |
|---|---|---|
| Zum Wochenplan | `calendar` | Modul Wochenplan; Untermenü mit den nächsten 7 Tagen ("Heute, Sa., 7. Nov.", "Morgen, So., 8. Nov." …), ein Tipp legt das Rezept mit der aktuellen Portionenzahl auf den Tag (B-API `addRecipeToPlan`, E-07), `UndoToast` "Auf Mo., 9. Nov. im Wochenplan · Widerrufen" |
| Ins Tagebuch eintragen | `flame` | Modul Kalorien (zusätzlich zur Zeile unter den Nährwerten) |
| Variante vorschlagen | `arrow.triangle.branch` | Varianten aktiv, fremdes Rezept |
| Bearbeiten | `pencil` | eigenes Rezept |
| Sichtbarkeit: Nur ich / Alle | `eye` | eigenes Rezept |
| Original-Rezept zeigen | `arrow.uturn.backward` | wenn eine Variante gewählt ist |
| Melden | `exclamationmark.bubble` (E-12) | fremdes Rezept |
| Löschen | `trash`, `danger` | eigenes Rezept, am Ende |

### 18.2 Rezept löschen (`confirmDestructive`)

Titel "„Ofengemüse mit Feta“ löschen?" Nachricht "Das Rezept, seine Bewertungen und Kommentare werden für alle gelöscht. Wer es gespeichert hat, sieht es nicht mehr. Das lässt sich nicht rückgängig machen." Knöpfe "Abbrechen", rot "Löschen". Danach `pop` zur vorherigen Seite (nicht `go('/recipes')`, Inv-D 18), die Zeile verschwindet aus allen Listen mit `springStandard`, Status-Hinweis "Rezept gelöscht". Das Foto wird aus dem Speicher (`recipe-images`) entfernt (Inv-D 18). Kein Vollbild-Spinner. Schlägt das Löschen am Server fehl, kehrt das Rezept an seinen Platz zurück, `StatusRow` "Rezept konnte nicht gelöscht werden. Erneut versuchen", Haptik "Fehler".

### 18.3 Entwurf verwerfen (`confirmDestructive`)

"Entwurf verwerfen?" / "Alles, was du hier eingegeben hast, wird auf allen Geräten gelöscht." / "Verwerfen". Bei einem Bearbeiten-Entwurf: "Änderungen verwerfen?" / "Das veröffentlichte Rezept bleibt, wie es ist."

### 18.4 Melden (`AppSheet` mittel)

Kopf nach K-30: `xmark` links, Inline-Titel "Melden", rechts getöntes `checkmark` ("Senden", deaktiviert, bis ein Grund gewählt ist). Auswahlzeilen "Unpassender Inhalt", "Spam oder Werbung", "Gefährliche Angaben (z. B. Allergene falsch)", "Urheberrecht", "Etwas anderes" mit optionalem Textfeld (Feld auf `fill`, kein Glas). Ab AX1 öffnet das Sheet groß. Ergebnis: Sheet schließt, Status-Hinweis "Danke. Wir sehen es uns an." Gemeldete Inhalte sind für die meldende Person sofort ausgeblendet (E-09).

### 18.5 Slots für Teil B in diesem Bereich

| Ort (A) | Slot (B) | Verhalten |
|---|---|---|
| Detail, Zutatenzeile; R-11 Zeile | `IngredientOfferBadge(listId:, ingredient:)` (neu, E-06) | gelbes Schild, nur Markt der Liste; `SizedBox.shrink()` bei Modul aus, Kill-Switch, Einzel-Schalter aus, keiner PLZ, Liste ohne Markt, keinem Treffer; nie an Grundzutaten (E-04) und nie für abgelaufene Angebote. Das Angebots-Sheet von B nennt Grundpreis, Gültigkeit, "laut Händler statt …" (nur wenn der Händler ihn nennt) und kennzeichnet ein nur ähnliches Produkt als "Ähnliches Produkt"; Produktbild nur mit Lizenz, sonst Avo Symbol der Kategorie |
| Detail, letzte Zeile der Zutaten; R-11 Sektionsfuß | `RecipeOfferSummary(recipe:, listId:)` (ersetzt `RecipeOffersCard(recipe:)`, E-06) | "3 Zutaten bei Lidl im Angebot · für Wocheneinkauf, in deiner Region"; Tippen öffnet B-Angebots-Sheet |
| Detail Nährwerte, Kochmodus "Fertig", Menü | `showLogRecipeSheet(context, recipe)` (besteht) | Portionen werden übergeben (E-07) |
| Detail-Menü | `addRecipeToPlan(recipeId, day, servings)` (neu, E-07) | Wochenplan |

---

## 19. Abläufe

### 19.1 "Was koche ich heute?" bis zum Essen

1. Tab Rezepte. "Weiter kochen" fehlt (nichts angefangen). Hero "Ofengemüse mit Feta".
2. Tippen auf den Hero: Foto zoomt ins Detail (`springMorph`).
3. Allergie-Hinweis oben (Laktoseintoleranz), Haptik "Warnung" einmal. Zutaten zeigen "laktosefreier Hirtenkäse · statt Feta".
4. Portionen auf 3: Mengen rollen, Auswahl-Haptik je Schritt.
5. "Zutaten auf Liste" → R-11: Wocheneinkauf vorausgewählt, Olivenöl abgewählt ("Schon auf Wocheneinkauf"), Salz und Pfeffer abgewählt. "8 Zutaten hinzufügen".
6. Sheet schließt, `UndoToast` "8 Zutaten zu Wocheneinkauf · Widerrufen". Im Tab Liste stehen die Zutaten in ihren Kategorien, mit Lidl-Schildern.
7. Später: Detail > "Kochen" → Kochmodus, schwarz, Seite "Zutaten" (abhaken mit leichtem Impuls), Wischen zu Schritt 1.
8. Schritt 3: "Timer 15 Min" → Kapsel unten; Avo-Kreis halten: "Weiter" → Schritt 4; "Timer 10 Minuten" → zweiter Timer.
9. Timer läuft ab, während das iPhone gesperrt ist: zeitkritische Mitteilung; Tippen öffnet den Kochmodus an der Stelle.
10. "Fertig" → Seite "Guten Appetit.": 5 Sterne, "Ins Tagebuch eintragen" (Modul Kalorien) → Sheet von B mit 3 Portionen vorbelegt. "Schließen".

### 19.2 Kochen unterbrechen und fortsetzen

1. Kochmodus auf Schritt 3, Timer läuft. `chevron.down`: Cover schließt sofort, kein Dialog.
2. Der Timer läuft weiter (Mitteilung geplant). Die Aktionsleiste im Detail zeigt "Weiter: Schritt 3"; R-01 zeigt "Weiter bei Schritt 3: Ofengemüse mit Feta".
3. Tippen auf "Weiter: Schritt 3": Kochmodus öffnet direkt dort, Timer-Kapsel mit Restzeit.
4. Nach 24 h ohne Öffnen ist der Fortschritt weg; die Zeile in R-01 verschwindet beim nächsten Öffnen des Tabs.

### 19.3 Rezept finden mit Allergie

1. Profil > Ernährung & Allergien: "Erdnüsse" an.
2. Tab Rezepte > "Für dich": kein Rezept mit Erdnuss ohne sicheren Ersatz mehr.
3. Suche "curry": "Erdnuss-Curry mit Süßkartoffel" erscheint mit "Enthält Erdnuss" in `warning` auf der Zeile.
4. Detail: Hinweis "Enthält Erdnuss. Du hast eine Erdnussallergie eingetragen. Für Erdnuss kennen wir keinen sicheren Ersatz." plus Fußnote; Zutatenzeilen "Erdnussbutter" und "geröstete Erdnüsse" mit Warndreieck.
5. Kategorie "Asiatisch": Chip "Passt zu mir" ist vorausgewählt; das Curry fehlt im Raster.

### 19.4 Eigenes Rezept schreiben und veröffentlichen

1. Tab Rezepte > `plus` → Editor (Cover). Foto aufnehmen, Name "Omas Kartoffelsalat". Ab jetzt existiert ein Entwurf.
2. "Weiter": Zeiten 20 + 30 Min, Portionen 4, "Einfach".
3. Zutaten: "1 kg Kartoffeln, festkochend" Return, "1 Zwiebel" Return, "150 ml Brühe" Return, "4 EL Essig", "Salz, Pfeffer nach Geschmack".
4. Zubereitung: vier Schritte; "Kartoffeln 25 Minuten kochen" zeigt "Timer 25 Min im Kochmodus".
5. Sichtbarkeit "Alle in der Community, erscheint als Jannis D." → "Veröffentlichen".
6. Cover schließt, Detail zeigt sofort das Rezept; nach Server-Bestätigung Haptik "Erfolg" und "Veröffentlicht". In R-01 erscheint es beim nächsten Öffnen unter "Neu", in R-08 sofort.

### 19.5 Entwurf auf dem anderen iPhone weiterschreiben

1. Owner beginnt auf iPhone 13 Pro ein Rezept, schließt mit `xmark`: "Als Entwurf gespeichert".
2. Jannis (gleiches Konto) öffnet auf seinem iPhone 15 Rezepte > Deine Rezepte > Entwürfe: "Kürbis-Risotto · Es fehlen: Anleitung · vor 2 Min. auf iPhone 13 Pro".
3. Er ergänzt die Anleitung; beim Owner zeigt der Editor beim nächsten Öffnen "Zuletzt auf iPhone 15 geändert".

### 19.6 Ersteller folgen

1. Detail > Autorzeile "von Mara Köhler" → R-06.
2. "Folgen": Knopf wird "Folge ich"; einmaliger Satz zu Mitteilungen.
3. Mara veröffentlicht "Kürbis-Risotto": Mitteilung "Mara Köhler hat ein neues Rezept: Kürbis-Risotto." (Kategorie "Neue Rezepte von Erstellern, denen du folgst", E-14); in R-01 trägt ihr Avatar den Punkt; in R-05 steht "neu: Kürbis-Risotto".

### 19.7 Variante vorschlagen (wenn freigeschaltet)

1. Detail eines fremden Rezepts > `ellipsis` > "Variante vorschlagen".
2. Editor im Modus Variante, Zutaten und Schritte vorbefüllt; "Feta" wird zu "Halloumi", Schritt 4 geändert (markiert).
3. "Was ist anders?" ausfüllen > "Variante teilen". Status "Variante geteilt"; im Detail erscheint sie in "Varianten".
4. Andere tippen "Hilfreich"; die Ersteller-Person des Originals bekommt eine Mitteilung.

### 19.8 Geteilten Rezept-Link öffnen

1. Link `https://shoplyai.app/recipe/<id>` aus einer Nachricht.
2. App installiert, angemeldet: Tab Rezepte wird aktiv, Stapel = Wurzel + Detail (01 Kap. 6); Zurück führt zur Wurzel.
3. Abgemeldet bzw. vor dem Onboarding: Detail öffnet ohne Login (öffentliche Route bleibt); Merken, Zutaten auf Liste und Kochen führen ins Onboarding bzw. Anmelden, die Aktion wird gemerkt und danach fortgesetzt (01 Kap. 7).
4. Rezept gelöscht oder privat: "Dieses Rezept gibt es nicht mehr."

---

## 20. Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| Q-01 | Varianten und Kommentare in Version 1 bauen? Beide brauchen Melden, Blockieren und Prüfung (App Review 1.2). Varianten: nur "Hilfreich" ohne Abwertung? | Version 1 mit Folgen, Bewertung und Melden; Varianten und Kommentare gestaltet, aber `hidden` bis eine Prüf-Warteschlange steht. Nur "Hilfreich". |
| Q-02 | "Likes" entfallen zugunsten von Merken und Bewerten? (Mitteilungstyp `recipe_like` existiert) | ja; `recipe_like` wird nicht mehr gesendet |
| Q-03 | Standard-Sichtbarkeit neuer Rezepte: "Alle" oder "Nur ich"? | "Alle", mit sichtbarem Anzeigenamen und ohne E-Mail-Rückfall |
| Q-04 | Wird der Kochmodus Pro (F-10)? | frei, bis der Pro-Umfang steht; Fläche 16.6 liegt bereit |
| Q-05 | Grundzutaten (Salz, Pfeffer, Wasser, Öl, Zucker) beim Hinzufügen standardmäßig abwählen? Später ein Vorrat ("Hab ich da") pro Person? | ja, feste Liste; Vorrat als späteres Modul |
| Q-06 | Standard-Portionen im Editor 2 statt 4? | 2 (Paare und WGs sind die Zielgruppe) |
| Q-07 | Rezepte in der anderen Sprache: ausblenden, unten zeigen oder per KI übersetzen? | in der Suche zeigen und kennzeichnen; Übersetzung per Claude später |
| Q-08 | Ausnahme von K-30 im Sheet "Zutaten auf Liste" (Hauptaktion unten mit Anzahl statt `checkmark` oben) in Ordnung? | ja |
| Q-09 | Filter "Passt zu mir" in Kategorien bei Allergieprofil vorausgewählt? | ja |
| Q-10 | Follower-Zahl auf der Ersteller-Seite zeigen? | nein, nur Rezeptanzahl und Bewertungsschnitt |
| Q-11 | Sammlungen (Ordner für Gespeichert; Tabelle `recipe_collections` existiert) | später; Version 1 nur Gespeichert mit Suche |
| Q-12 | Rezept aus Link, Foto oder Text per KI übernehmen (Plan 7) | eigener Einstieg im `plus`-Menü "Aus Link übernehmen" in Version 1.1 (Teil B: KI-Dienst, Teil A: Editor öffnet vorbefüllt) |
| Q-13 | Zutaten-Gruppen ("Für die Soße") im Datenmodell? | später; Editor-Zeilen sind dafür vorbereitet (Zwischenüberschrift als eigene Zeilenart) |
| Q-14 | Lizenz der kuratierten Fotos für "Rezept der Woche" (F-07) | gemeinsam mit F-07 |
| Q-15 | Rezept > Ersteller > Rezept sprengt die drei Push-Ebenen (01 Kap. 6). Regel 2.6 (4. Ebene als Sheet groß) übernehmen oder Ausnahme "beliebig tief wie App Store" erlauben? | 2.6 übernehmen; hält die Regel aus 01 und verhindert Endlos-Stapel |
| Q-16 | Neuer Auslöser der App-Bewertungs-Abfrage (heute beim Merken) | nach dem zweiten "Guten Appetit." im Kochmodus oder dem dritten gespeicherten Einkauf, höchstens wie von StoreKit erlaubt; nie im Kochen, nie beim Stöbern |
| Q-17 | Kochmodus: Avo per Halten ohne großes Sheet (E-20) als Abweichung von 00 12.33 in Ordnung? Später freihändig ("Weiter" ohne Halten)? | ja für Version 1; freihändiges Zuhören erst nach Datenschutz- und Akku-Prüfung |

---

## 21. Ergänzungen zum Fundament

Was dieses Kapitel braucht und in `00-grundlagen.md` bzw. `01-navigation-und-struktur.md` fehlt. Teil A trägt sie nach Abstimmung ins Fundament ein.

| Nr. | Ergänzung | Wo im Fundament | Grund |
|---|---|---|---|
| E-01 | `AppTabBar` bekommt den Modus `cooking`: Tab-Kapsel ausgeblendet, nur der Avo-Kreis an seiner Stelle, Glas dunkel auf Schwarz. Kanal `setMode(normal \| askAvo \| hidden \| shopping \| cooking)`. Glas-Budget im Kochmodus: Toolbar oben, Steuerung unten, Avo-Kreis = 3. | 00 12.1, 8.1, 8.5 | 01 Kap. 3 verlangt den Avo-Kreis im Kochmodus; heute gibt es nur `shopping` |
| E-02 | `RecipeCard` zwei weitere Varianten: **Rang-Zeile** (Rang `numberL` `labelSecondary` + Zeile; für "Beliebt") und **Raster-Kachel** (wie "klein", aber Breite aus der Rasterspalte statt fest 160 pt; Reihenhöhe = höchste Kachel). | 00 12.13 | Beliebt soll eine andere Form haben als "Für dich"; Raster in R-03, R-04, R-06 |
| E-03 | Komponente `AllergenNotice`: Sektion mit Symbol (`exclamationmark.triangle.fill` `warning` / `questionmark.circle` / `leaf` `labelSecondary`), Text `callout` `label`, feste Fußnote; Haptik "Warnung" einmal pro Rezept und Sitzung; nie ausblendbar. | 00 Kap. 12 (neu, 12.37) | Responsibility; heute keine Komponente |
| E-04 | Kochmodus-Tokens: `cookingSurface` #1C1C1E, `cookingFill` #2C2C2E, `cookingSeparator` #38383A, `cookingControlOutline` #7C7C80; `action`/`onAction` im Kochmodus immer in der Dunkel-Variante (#A6D45F / #0E1A06), mit erhöhtem Kontrast #C4E88A. Grundzutaten-Liste (Salz, Pfeffer, Wasser, Öl, Zucker) als Daten bei Teil A. | 00 4.6 | 00 nennt nur `cookingBg`, `cookingLabel`, `cookingSecondary` |
| E-05 | Datenfelder (Teil A, Supabase): `recipes.visibility` (`public` \| `private`), Tabelle `recipe_drafts` (Konto-Sync, Fotos in privatem Storage-Pfad), `recipes.photo_color` (steht schon in 00 9.6), Allergen-Tags je Zutat in `ingredient_diet_tags`, Server-Volltextsuche (RPC) und serverseitige Abschnitte (Rezept der Woche, Beliebt, Neu, Für-dich-Kandidaten). | 00 Kap. 13, 17 | Inv-D 20, 33; Inv-B 4.7 |
| E-06 | Slots für Teil B: `RecipeOffersCard(recipe:)` wird ersetzt durch `RecipeOfferSummary(recipe:, listId:)` und `IngredientOfferBadge(listId:, ingredient:)`; nur Markt der übergebenen Liste, kein "Spare bis zu", keine eigene Prozentrechnung, "statt" nur als "laut Händler", Produktbilder nur mit Lizenz. | `arbeitsteilung.md` Slot-Tabelle | Plan 8, Recherche; Inv-D 22 bis 25 |
| E-07 | Gemeinsame Dienste von Teil A, die B aufruft: `RecipeAdaptation` (Allergie-Erkennung und Ersatz, 2.3), `RecipeToList` (Zutaten auf Liste mit Rundung, Zusammenführen, Batch, Angebotspreis nur für den Markt der Liste), Kochfortschritt-API für Avo (`cookingNext`, `cookingPrevious`, `cookingStartTimer(minutes)`). Von B an A: `addRecipeToPlan(recipeId, day, servings)`; `showLogRecipeSheet` bekommt `servings`. Avo-Werkzeug `add_recipe_to_list` nutzt `RecipeToList`. | `arbeitsteilung.md` Kap. 5 | Ersatz überall gleich (Inv-D 4.1, 4) |
| E-08 | Funktion "Folgen": Tabelle `creator_follows` (Migration vorhanden), Mitteilungskategorie "Neue Rezepte von Erstellern, denen du folgst" in `/settings/notifications`. | 01 Kap. 4, 8.2 | Funktionsliste "Creator und Folgen" |
| E-09 | Nutzerinhalte: "Melden" und "Blockieren" für Rezepte, Varianten, Kommentare und Personen; Einstellungsseite "Blockierte Personen" unter Konto (`/settings/blocked`); Server-Tabelle für Meldungen. Varianten und Kommentare bleiben `hidden`, bis das steht. | 01 Kap. 4, 7; 00 15.2 | App Review 1.2 |
| E-10 | Routen: `/recipes/:recipeId/variations/:variationId` (Sheet groß), `/recipes/:recipeId/comments` (Sheet groß), `/recipes/add?variationOf=:recipeId` (Cover), `/recipes/category/ingredient:<name>` (Push, Rezepte mit Zutat). | 01 Kap. 7 | R-12, R-13, 4.1, 14.3 |
| E-11 | `HintRow` auch außerhalb der Startseite, höchstens eine pro Screen, für einmalige Tipps und "Weiter kochen" im Tab Rezepte. | 00 12.12 | 01 5.4 ersetzt den Diät-Dialog durch eine Tipp-Zeile im Tab Rezepte |
| E-12 | Symbole ergänzen: Bewertung `star` / `star.fill` (in `action`, nie Gold), Folgen `person.badge.plus`, Variante `arrow.triangle.branch`, Hilfreich `hand.thumbsup`, Kommentare `bubble.left`, Melden `exclamationmark.bubble`, Nicht mehr merken `bookmark.slash`, Sichtbarkeit `eye`, Übersicht `list.bullet`, Senden `arrow.up.circle.fill`, Fotos `photo.on.rectangle`, Liste wählen `chevron.up.chevron.down`. Sortieren nutzt `arrow.up.arrow.down` (wie "Reihenfolge im Markt"; anderer Kontext, kein Konflikt im selben Screen). | 00 9.2 | fehlen in der Tabelle |
| E-13 | Haptik ergänzen: "Timer abgelaufen" = Warnung (mit System-Ton); "Seite rastet nach Wischen ein" im Kochmodus = Auswahl; "Stern-Bewertung per Ziehen" = Auswahl pro Stern. | 00 Kap. 11 | Tabelle nennt diese Momente nicht |
| E-14 | Mitteilungen: Kochtimer als zeitkritische Mitteilung (Berechtigung "Time Sensitive Notifications" im Entitlement), Aktion "+1 Min", eine ID je Timer; neue Kategorien "Neue Rezepte von Erstellern, denen du folgst", "Bewertungen und Kommentare zu deinen Rezepten". | 01 8.2; Kapitel 19 | heute eine feste ID 700100, nicht zeitkritisch |
| E-15 | Der Editor hat einen festen Fußbereich mit prominentem Knopf auf `bgGrouped` (kein Glas). Bestätigen, dass das die Regel für Schritt-Abläufe in Covern ist (gilt dann auch für Onboarding). | 00 8.1, 12.20 | 00 8.1 nennt den Editor nicht; ein festes Muster verhindert zwei Varianten auf den Macs |
| E-16 | `UndoToast` Variante **mit Ziel**: Tippen auf den Text öffnet das Ergebnis (z. B. die Liste), "Widerrufen" bleibt die Aktion; VoiceOver-Aktion "Liste öffnen". | 00 12.28 | Sprung zur Liste nach "Zutaten auf Liste" muss erhalten bleiben (Inv-B 6) |
| E-17 | `LargeTitleNavBar` Variante **Profil-Kopf**: Avatar 64, Name `title2`, Metazeile mittig statt großem Titel; Inline-Titel beim Scrollen. | 00 12.2 | Ersteller-Seite (R-06), später auch eigenes Profil |
| E-18 | Tiefenregel: Eine 4. Push-Ebene öffnet als `AppSheet` groß mit eigenem Stapel (höchstens 2), Rückweg in Gegenrichtung nicht tippbar. | 01 Kap. 6 | Rezept > Ersteller > Rezept (2.6, Q-15) |
| E-19 | Obergrenze für Beschriftungen schwebender Glas-Kapseln (Aktionsleiste, Kochmodus-Steuerung, Toolbar-Text-Kapseln): wachsen bis xxxL, darüber Large Content Viewer; Kurzfassung der Beschriftung, wenn die Breite nicht reicht ("Auf Liste"). | 00 5.3 (Obergrenzen) | 00 regelt das nur für Tab-Beschriftungen und das Accessory |
| E-20 | Avo im Kochmodus: Halten des Avo-Kreises hört kompakt zu (Kern `hoertZu`, Transkript als eine Zeile im Inhalt, Loslassen sendet), ohne Sprachmodus-Sheet. | 00 12.33, 01 Kap. 3 | Ein großes Sheet würde den Schritt verdecken (Q-17) |
