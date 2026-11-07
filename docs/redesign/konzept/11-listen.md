# 11 Listen, Hinzufügen und Einkaufsmodus

Stand: 07.11.2026. Baut Teil A (Owner, Mac 1). Slots mit Inhalt von Teil B sind markiert ("Slot B"). Grundlage: `00-grundlagen.md` (Verweise "00 Kap. x"), `01-navigation-und-struktur.md` (Verweise "01 Kap. x"), Jannis' Plan Punkt 4, Verbesserungsliste Punkte 2, 4 und 6c, Recherche zu Angeboten. Bei Widersprüchen gilt der Plan.

Markierungen: **L-xx** = Entscheidung dieses Kapitels, **LF-xx** = offene Frage an den Owner (Kap. 16), **E-xx** = Ergänzung zum Fundament (Kap. 17).

Inhalt: 0 Überblick · 1 Die Liste · 2 Hinzufügen · 3 Zettel importieren · 4 Artikel-Sheet · 5 Einkaufsmodus · 6 Einkauf beenden · 7 Alle Listen · 8 Neue Liste · 9 Teilen und Beitreten · 10 Listen-Info · 11 Markt pro Liste · 12 Reihenfolge im Markt · 13 Listenfarben statt Hintergründe · 14 Abläufe · 15 Dateien und Daten · 16 Offene Fragen · 17 Ergänzungen zum Fundament

---

## 0. Überblick

### 0.1 Abgrenzung

- **Kapitel 10** gestaltet die Wurzel des Tabs Liste als Startseite: Auswahl der Liste von heute (01 Kap. 2.2), die Sektion "Für heute" mit höchstens zwei Hinweis-Zeilen (00 Kap. 12.12), den Zustand "Erste Liste" (01 Kap. 2.4). Dieses Kapitel setzt die Sektion nur als Platzhalter ein.
- **Kapitel 11** (dieses) gestaltet alles, was die Liste selbst ist: Kopf, Artikel, Hinzufügen, Import, Artikel-Sheet, Einkaufsmodus, Teilen, Listen-Info, Markt-Chip, Reihenfolge im Markt, Alle Listen, Präsenz, Offline.
- **Kapitel 12** (Teil B) gestaltet den Inhalt von Angebots-Sheet, `ListOfferSummary`, Angebote der Woche, Abschluss-Sheet, Verlauf und Kosten teilen. Hier stehen nur Ort, Rahmen und Beispiel.

### 0.2 Screens dieses Bereichs

| Nr. | Screen / Sheet / Dialog | Route | Muster | Hauptfrage | Besitz |
|---|---|---|---|---|---|
| 1 | Die Liste (Wurzel Tab Liste) | `/home`, `/lists/:id` | Tab-Wurzel | Was muss ich als Nächstes kaufen? | A |
| 1.2 | Listen-Umschalter | – | Menü aus dem Titel | Welche Liste will ich sehen? | A |
| 1.3 | Menü "Mehr" | – | Menü aus `ellipsis` | Was kann ich mit dieser Liste tun? | A |
| 2 | Artikel hinzufügen (Accessory, Vorschlags-Panel) | `shoply://addItem` | Accessory | Was will ich hinzufügen? | A, Angebotszeilen Slot B |
| 3 | Zettel importieren, Sheet "14 Artikel erkannt" | – | Menü, Sheet groß | Stimmen die erkannten Artikel? | A, Erkennung B |
| 4 | Artikel-Sheet | – | Sheet mittel | Wie viel wovon, in welcher Kategorie? | A, Angebotszeile Slot B |
| 5 | Einkaufsmodus | `/lists/:id/shopping` | Vollbild-Cover (Morph) | Was fehlt noch im Wagen? | A |
| 6 | Einkauf beenden (Abschluss-Sheet), Erfolgsmoment | – | Sheet mittel | Wo war ich, was kommt in den Verlauf? | B (Inhalt), A (Rahmen) |
| 7 | Alle Listen | `/lists` | Push | Welche Listen habe ich? | A |
| 8 | Neue Liste | `/lists/new` | Sheet mittel | Wie heißt die Liste, für welchen Markt? | A |
| 9 | Liste teilen, Code, Liste beitreten, Beitritts-Sheet | `/lists/:id/share`, `/lists/join`, `/join/:code`, `/invite/:id` | Sheet mittel | Wie bekommt jemand Zugriff? | A |
| 10 | Listen-Info (mit Symbol wählen, Alle Änderungen) | `/lists/:id/info`, `/lists/:id/activities` | Sheet groß, Push im Sheet | Wie ist diese Liste eingerichtet, wer ist dabei? | A, Markt und Angebote Slot B |
| 11 | Markt-Sheet | – | Sheet mittel | Für welchen Markt ist diese Liste? | B |
| 12 | Reihenfolge im Markt, Eigene Kategorie | `/lists/:id/order` | Push im Sheet, Sheet mittel | In welcher Reihenfolge gehe ich durch den Markt? | A |

### 0.3 Beispieldaten (gelten für alle Beispiele und Bildbeschreibungen)

Heute ist Samstag, 7. November 2026, 10:42 Uhr. "Du" bist Jannis.

| Liste | Farbe, Symbol | Markt | Offen | Mitglieder |
|---|---|---|---|---|
| **Wocheneinkauf** (Liste von heute, angeheftet) | Blau #007AFF, `cart` | Lidl | 11 | Jannis (Ersteller), Lena |
| REWE | Rot #FF3B30, `basket` | REWE | 4 | Jannis |
| Drogerie | Lila #AF52DE, `bag` | kein Markt | 3 | Jannis |
| Party Samstag | Orange #FF9500, `party.popper` | kein Markt | 14 | Jannis, Lena, Max |
| WG-Vorrat (geteilt mit mir, neue Änderungen) | Grün #34C759, `house` | Aldi Süd | 6 | Tom (Ersteller), Jannis |

**Wocheneinkauf, offen (11), in der Reihenfolge des Lidl-Markts:**

| Kategorie (Anzeige) | Artikel |
|---|---|
| Obst & Gemüse (3) | Bananen · Gurken, Menge 2 · Tomaten, 500 g |
| Brot & Backwaren (1) | Vollkornbrot |
| Milch & Käse (3) | Milch, Menge 2, Angebot 0,99 € · Butter, von Lena · Feta, 200 g, Angebot 1,29 € |
| Fleisch & Fisch (1) | Hähnchenbrust, 400 g, Angebot 3,49 € |
| Vorrat (2) | Mehl, 1 kg · Spaghetti, Menge 2 |
| Getränke (1) | Mineralwasser, Menge 6, Notiz "still", Angebot 0,19 € |

- **Erledigt (2):** Eier (von dir abgehakt), Joghurt (von Lena abgehakt).
- **Vielleicht auch:** Haferflocken ("kaufst du etwa alle 8 Tage"), Zwiebeln ("oft auf dieser Liste"), Kaffee ("kaufst du etwa alle 2 Wochen").
- **Angebote (Modul an, echte PLZ 80331):** 4 von 11 Artikeln bei Lidl im Angebot. Ersparnis laut Händler: Milch 2 × 0,20 €, Feta 0,50 €, Hähnchenbrust 1,50 €, Mineralwasser 6 × 0,13 € = 3,18 €, angezeigt als "ca. 3,20 €".
- Kategorienamen: kurze Anzeigenamen nach E-01 (IDs unverändert).

### 0.4 Rahmen für alle Bildbeschreibungen

Gerät iPhone 17 Pro, 402 × 874 pt, Hochformat, Hellmodus, iOS 27, Systemschrift SF Pro, Textgröße Standard, sofern nicht anders gesagt. Statusleiste "10:42". Liquid Glass erscheint als milchig-transparente, leicht spiegelnde Kapseln mit hellen Kantenlichtern; der Inhalt darunter ist durchscheinend unscharf zu sehen. Symbole sind SF Symbols. Keine Emojis, keine Großbuchstaben-Zeilen über Überschriften, keine Icons in getönten Quadraten, keine Schlagschatten auf Inhalten.

### 0.5 Gemeinsame Regeln dieses Bereichs

- **Glas-Budget (00 Kap. 8.5):** Liste = Tab-Bar mit Avo-Kreis (1), Accessory (2), Toolbar-Gruppe oben rechts (3). Der Rückgängig-Hinweis zählt auf der Listen-Wurzel nicht extra, weil er Teil der Accessory-Gruppe wird (E-05). Einkaufsmodus = Glas-Knopf `chevron.down` (1), Bodenleiste (2), Rückgängig-Hinweis (3).
- **Kein sichtbares Laden.** Liste, Artikel, Mitglieder, Code, Reihenfolge und "Zuletzt geändert" kommen beim zweiten Öffnen aus dem lokalen Stand (00 Kap. 13).
- **Rückgängig statt Rückfrage.** Bestätigungsdialoge nur für: Liste löschen, Liste verlassen, Mitglied entfernen, Kategorie löschen (00 Kap. 12.34).
- **Haptik** nur nach 00 Kap. 11: Abhaken (leicht), letzter offener Artikel (Erfolg), Einkauf gespeichert (Erfolg), Fehler, Einrasten beim Umsortieren (Auswahl), Stepper (Auswahl), Wisch-Schwelle (leicht), Detent nach Ziehen (Auswahl).
- **Kern bleibt frei (00 Kap. 16).** In diesem Bereich gibt es keine Pro-Sperre, keine `ProBadge` und keinen Pro-Hinweis. Einzige Pro-Fläche: die einmalige Hinweis-Zeile nach dem ersten abgeschlossenen Einkauf (00 Kap. 16.4), angeordnet von Kapitel 10.
- **Modul Angebote aus oder Kill-Switch:** Alle Slot-B-Elemente rendern `SizedBox.shrink()`; es bleibt keine Lücke, kein Gelb, kein Hinweis. Der Markt-Chip bleibt (Kern).

---

## 1. Die Liste (Wurzel des Tabs Liste)

### 1.1 Hauptscreen

**Zweck.** Hauptfrage: *Was muss ich als Nächstes kaufen?* Man kommt hierher beim App-Start (Liste von heute), über den Tab Liste, über Titelmenü, Alle Listen, Deep Link `/lists/:id`, Widget, Mitteilung, Siri und Avo.

**Aufbau von oben nach unten** (`CustomScrollView` mit Slivers, Hintergrund `bgGrouped`; ab AX1 `bgPlain` und Sektionen plain nach 00 Kap. 6.4):

1. **Obere Zeile (44 pt):** rechts `GlassToolbar` als eine Glasgruppe mit zwei Knöpfen: `person.crop.circle.badge.plus` ("Liste teilen") und `ellipsis` ("Mehr", 1.3). Links nichts (Tab-Wurzel).
2. **Großer Titel** (`LargeTitleNavBar`, Variante Listen-Umschalter, 00 Kap. 12.2): "Wocheneinkauf" in `largeTitle` mit `chevron.down` 13 pt Semibold `labelSecondary` hinter dem letzten Wort; rechts in der Titelzeile der Profil-Avatar 36 pt (kein Glas).
3. **Metazeile** (8 pt unter dem Titel, `Wrap` mit 8 pt Abstand): `StoreChip` (Slot B, 00 Kap. 12.10) "Lidl" mit blauem Punkt · Text "11 offen" (`subheadline`, `labelSecondary`, Zahl als `RollingNumber`) · bei geteilten Listen Avatar-Stapel 20 pt (höchstens 3, dann "+n"). Tippen auf den Avatar-Stapel öffnet "Liste teilen" (9.1).
4. **Präsenz-Zeile** (nur wenn ein anderes Mitglied im Einkaufsmodus ist, `PresenceLine`, 00 Kap. 12.29): Avatar 20 pt mit Punkt `presence`, "Lena kauft gerade bei Lidl ein".
5. **`StatusRow`** (nur wenn nötig, 00 Kap. 12.27): offline oder "3 Änderungen warten".
6. **Sektion "Für heute"** (Kapitel 10, höchstens zwei `HintRow`s). Steht beim ersten Frame fest.
7. **Gang-Sektionen** (`AisleSection`, 00 Kap. 12.9): Titel = Kategoriename (`headline`), rechts Anzahl offen (`numberS`, `labelSecondary`); Zeilen = `ItemRow` (00 Kap. 12.8) mit `CheckCircle` 24 pt, `ArticleImage` 28 pt (Slot B), Name (`body`), Unterzeile (Notiz, "von Lena"), rechts Menge (`number`) und darunter `ItemOfferBadge` (Slot B). Reihenfolge der Sektionen nach "Reihenfolge im Markt" (12); innerhalb nach `order_index`, sonst Erstellzeit, neue Artikel unten in ihrer Kategorie. Leere Kategorien entfallen.
8. **`ListOfferSummary`** (Slot B, nur Modul Angebote mit echter PLZ): eine Zeile in eigener Sektion ohne Titel: `tag` 16 pt `labelSecondary`, "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" (`callout`, `label`), `chevron.right`. Tippen öffnet `/offers/list/:id` (Sheet mittel, Kapitel 12). Steht diese Zeile schon als Hinweis-Zeile in "Für heute", entfällt sie hier (nie doppelt, E-06).
9. **Sektion "Vielleicht auch"** (bis 3 Zeilen, Variante Vorschlag von `ItemRow`): `CheckCircle` gestrichelt mit `plus`, Name in `label`, Unterzeile mit Grund. Tippen setzt den Artikel auf die Liste (Zeile wandert mit `springMove` in ihre Kategorie, leichter Impuls). Wischen nach links: "Ausblenden" (für 30 Tage). Sektionsfuß entfällt. Quelle: Empfehlungs-Dienst (Teil B, stabile API), nur aus dem eigenen Kaufverhalten, nie erfundene Gründe wie "Beliebtes Produkt".
10. **Sektion "Erledigt (2)"** (`InsetSection`, einklappbar, Zustand pro Liste gemerkt, standardmäßig eingeklappt): rechts im Titel schlicht "Abschließen" (öffnet 6.1). Ausgeklappt: abgehakte Zeilen, Name durchgestrichen in `labelSecondary`, von anderen abgehakte mit Unterzeile "von Lena abgehakt".
11. **Unterer Abstand** `bottomContentInset` aus `ShellInsets`; Scroll-Edge-Verlauf 40 pt hinter der Bodenebene.
12. **Bodenebene:** `AddItemAccessory` (2.1) 8 pt über der `AppTabBar`; Tab-Bar mit Avo-Kreis.

**Beispielinhalt.** Wie 0.3. Metazeile: "Lidl · 11 offen · [Avatar Lena]". Keine Präsenz-Zeile (Lena ist zu Hause). "Für heute": "Heute im Plan: Ofengemüse mit Feta" (Kapitel 10).

**Zustände.**

| Zustand | Darstellung |
|---|---|
| Lädt, lokaler Stand vorhanden | sofort aus dem lokalen Stand (vor `runApp` geladen); Abgleich im Hintergrund; Änderungen wachsen ein bzw. Zahlen rollen. Kein Indikator. |
| Allererstes Laden ohne lokalen Stand (z. B. nach Beitritt) | Titel und Metazeile sind da (aus der Listenzeile); darunter drei ruhige Tonflächen in `fill` in Form von zwei Sektionen mit je 3 Zeilen, kein Schimmer, bis zur ersten Antwort. |
| Leer, noch nie Artikel | An Stelle der Sektionen `EmptyState` ohne Maskottchen: Symbol `checklist` 48 pt Light, "Noch nichts auf der Liste." (`title3`), "Schreib unten, was du brauchst, zum Beispiel „2 Milch“." (`body`), schlicht "Zettel importieren". "Vielleicht auch" bleibt, wenn es Vorschläge gibt. Accessory ohne "Einkaufen". |
| Alles erledigt | `EmptyState` mit Maskottchen "zufrieden" (96 pt, ab AX1 ohne): "Alles erledigt. Schön." / "13 Artikel sind abgehakt." / prominent "Einkauf abschließen" (einzige gefüllte Kapsel, weil "Einkaufen" im Accessory ausgeblendet ist). Darunter "Erledigt (13)". |
| Fehler beim Abgleich, lokaler Stand da | Inhalt bleibt; `StatusRow` "Die Liste konnte nicht aktualisiert werden. Erneut versuchen". |
| Fehler ohne lokalen Stand | Vollfläche im Layout des leeren Zustands: `exclamationmark.circle` 48 pt, "Die Liste lässt sich gerade nicht laden.", schlicht "Erneut versuchen". |
| Liste wurde gelöscht oder man wurde entfernt | Layout des leeren Zustands: "„WG-Vorrat“ gibt es nicht mehr." bzw. "Du bist nicht mehr Mitglied von „WG-Vorrat“.", schlicht "Zu deinen Listen" (Alle Listen). Die Liste von heute wechselt nach 01 Kap. 2.2 Regel 1 erst beim nächsten Öffnen. |
| Offline | `StatusRow` "Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist."; alles bleibt bedienbar (1.6). |
| Modul Angebote aus, Kill-Switch, "Angebote für diese Liste" aus | keine Schilder, keine `ListOfferSummary`, keine Angebotszeilen im Panel, ohne Lücke. Markt-Chip bleibt. |
| Pro | nicht relevant (0.5). |

**Interaktionen, Bewegung, Haptik.**
- **Abhaken:** Tippen auf die vorderen 56 pt der Zeile (Kreis-Bereich, K-36). Kreis füllt sich vom Mittelpunkt (`springQuick`), Häkchen zeichnet sich, Text wird durchgestrichen und `labelSecondary`, leichter Impuls im selben Frame; "11 offen" rollt auf "10 offen". Nach 0,6 s wandert die Zeile mit `springMove` in "Erledigt (3)", die Zeilen darunter rücken nach. Ist der Gang danach leer, schließt sich die Sektion mit `springStandard`. Widerruf: erneutes Tippen innerhalb der 0,6 s oder im Rückgängig-Hinweis "Abgehakt: Bananen · Widerrufen" (4 s). Letzter offener Artikel: Erfolgs-Haptik statt leichtem Impuls, dann Zustand "Alles erledigt".
- **Name antippen:** öffnet das Artikel-Sheet (4) mittel, `springSheet`.
- **Wischen nach links** (folgt 1:1, Gummiband am Ende): zwei Aktionen "Bearbeiten" (`fill`, `pencil`) und "Löschen" (`danger`, `trash`). Volles Wischen über 60 % der Breite löscht sofort (leichter Impuls beim Überschreiten der Schwelle); Zeile fällt mit `springFling` aus der Geschwindigkeit des Fingers zusammen; Rückgängig-Hinweis "Milch gelöscht · Widerrufen". Kein Dialog.
- **Langdruck:** Kontextmenü (`AppMenu`, 00 Kap. 12.24) wächst unter der hervorgehobenen Zeile: "Bearbeiten" (`pencil`), "Menge" (Untermenü mit `ValueStepper`-Zeile), "Kategorie" (Untermenü der Kategorien, aktuelle mit Häkchen), "Auf andere Liste" (Untermenü Listen), Trenner, "Löschen" (`danger`, `trash`). Bewegt man den Finger nach dem Langdruck, schließt das Menü und die Zeile hebt sich zum Umsortieren (Skalierung 1,03, `shadowFloat`), folgt dem Finger 1:1, Nachbarn machen mit `springStandard` Platz, Einrasten mit Auswahl-Haptik, Auto-Scroll am Rand mit Ticker statt `Timer`. Ziehen in eine andere Kategorie setzt die Kategorie (und lernt sie, 2.3).
- **Titel antippen:** Listen-Umschalter (1.2). **Erneutes Tippen auf den Tab:** nach oben scrollen.
- **Ziehen nach unten** am Anfang: Pull-to-Refresh (System), selten nötig.
- **Keine Haptik** bei: Tippen auf Name, Öffnen von Sheets und Menüs, Einklappen von "Erledigt".

**Große Schrift und 320 pt.**
- 320 pt: Metazeile bricht in zwei Zeilen (Markt-Chip, dann "11 offen" mit Avataren). Titel bis zwei Zeilen, dann Ellipse; der volle Name steht im Titelmenü. Toolbar-Knöpfe bleiben 44 pt.
- Ab AX1: plain-Sektionen auf `bgPlain`, Artikelbild entfällt, Menge und Schild rutschen unter den Namen, Kreis oben bündig zur ersten Textzeile, Markt-Chip bricht um. Tab-Beschriftungen entfallen.
- AX5 auf 320 pt (Prüfgerät): Artikelname 53 pt bricht auf mehrere Zeilen; kein Text wird abgeschnitten; die Liste beginnt auf iPhone SE spätestens nach Titel, Metazeile und einer Hinweis-Zeile (Kapitel 10 zeigt ab AX3 höchstens eine).
- Fetter Text: Gewichte steigen eine Stufe; Zeilen wachsen in der Höhe, nie in fester Höhe.

**Was sich ändert, betroffene Dateien.**
- `lib/presentation/screens/lists/list_detail_screen.dart` wird zur Wurzel des Tabs Liste (neu z. B. `screens/lists/list_screen.dart`); `/lists/:id` wählt die Liste statt einen eigenen Screen ohne Tab-Bar zu pushen.
- Material-`AppBar`, Serifentitel, Fortschritts-Haarlinie, schwarze "Einkauf abschließen"-Pille am Listenende (`list_detail_parts.dart`) entfallen.
- Karte "KI-Empfehlungen" oben (`widgets/recommendations/ml_recommendations_section.dart`, `recommendation_card.dart`) wird Sektion "Vielleicht auch" am Ende, ohne Layout-Sprung (erscheint nur, wenn beim ersten Frame im Cache, sonst beim nächsten Öffnen).
- `list_item_tile.dart` wird `ItemRow` (Kreis-Bereich hakt ab, Rest öffnet Sheet; Drag-Griff-Symbol entfällt; Wischen mit Rückgängig; Kontextmenü neu).
- `list_category_section.dart` wird `AisleSection` (keine Großbuchstaben-Köpfe, keine Drop-Zonen, kein `basketComparisonProvider` pro Sektion).
- `list_drag_controller.dart`: Auto-Scroll per Ticker.
- `ListPriceSummaryBar` und Marktvergleich entfallen (Slot B `ListOfferSummary`).
- Bewertungsdialog beim vollständigen Abhaken entfällt; Systemdialog höchstens nach dem dritten abgeschlossenen Einkauf, nie im Einkaufsmodus (`AppReviewService`).
- Nebenwirkungen beim Öffnen bleiben: Ungelesen setzen, Badge und zugestellte Mitteilungen dieser Liste entfernen.

**Bildbeschreibung für ChatGPT.**
iPhone-Screenshot einer Einkaufsliste im Stil einer vorinstallierten Apple-App (iOS 27), Hintergrund #F2F2F7. Oben rechts zwei runde Liquid-Glass-Knöpfe in einer gemeinsamen Glaskapsel mit einem Person-plus-Symbol und drei Punkten; darunter links der große fette Titel "Wocheneinkauf" in Schwarz #000000 mit einem kleinen grauen Pfeil nach unten, rechts ein runder Profil-Avatar mit Foto. Unter dem Titel eine graue Kapsel #E9E9EE mit einem blauen Punkt #0050AA und dem Wort "Lidl", daneben "11 offen" in Grau #636366 und ein kleiner runder Avatar einer Frau. Darunter weiße Sektionen #FFFFFF mit 26 pt Eckenradius und fetten Überschriften in Schwarz: "Obst & Gemüse 3" mit Zeilen "Bananen", "Gurken" (rechts "2"), "Tomaten" (rechts "500 g"), dann "Milch & Käse 3" mit "Milch" (rechts "2" und darunter ein kleines gelbes Preisschild #FFD60A mit "0,99 €" in #1C1C1E), "Butter" mit grauer Unterzeile "von Lena" und "Feta". Jede Zeile beginnt mit einem leeren grauen Kreis-Ring #8A8A8E und einem kleinen grauen Kategorie-Symbol (Karotte, Tropfen); zwischen den Zeilen feine graue Trennlinien #C6C6C8, die erst an der Textkante beginnen. Unten schwebt eine Liquid-Glass-Leiste: eine breite Kapsel mit Plus-Symbol, dem grauen Platzhalter "Artikel hinzufügen" und einem Textscanner-Symbol, rechts daneben eine grün getönte Glas-Kapsel #3F7A1F mit weißem Einkaufswagen und "Einkaufen". Darunter die schwebende Glas-Tab-Bar mit den Tabs "Liste" (grün ausgewählt, Checklisten-Symbol), "Rezepte", "Plan" und abgesetzt rechts ein runder Glas-Kreis mit einem braunen Kern und grünem Ring #C9DE6E; der Listeninhalt scheint unscharf durch das Glas.

---

### 1.2 Listen-Umschalter (Menü aus dem Titel)

**Zweck.** *Welche Liste will ich sehen?* Tippen auf den Titel.

**Aufbau** (`AppMenu`, wächst mit `springMenu` aus dem Titel, Ursprung am `chevron.down`):
1. Listen als Menüzeilen (`ListRow`, Variante Menü): Listen-Glyph 28 pt, Name (`body`), rechts offene Anzahl (`number`, `labelSecondary`); aktuelle Liste mit `checkmark` links; angeheftete Liste oben mit `pin` 13 pt; Listen mit neuen Änderungen anderer mit Ungelesen-Punkt 8 pt in `action` vor der Anzahl; jemand kauft ein: Unterzeile "Lena kauft gerade ein" mit `presence`-Punkt. Sortierung: angeheftet, dann zuletzt geändert. Höchstens 8 Listen, dann scrollt das Menü.
2. Trenner (8-pt-Band).
3. "Neue Liste" (`plus`), "Liste beitreten" (`link`), "Alle Listen" (`list.bullet`).

**Beispiel.** "Wocheneinkauf 11" (mit Häkchen, angeheftet), "Party Samstag 14", "WG-Vorrat 6" (mit Ungelesen-Punkt), "REWE 4", "Drogerie 3"; dann "Neue Liste", "Liste beitreten", "Alle Listen".

**Zustände.** Offline: Menü aus dem lokalen Stand, "Liste beitreten" deaktiviert mit Unterzeile "Braucht eine Verbindung". Nur eine Liste: Menü zeigt sie trotzdem (Weg zu "Neue Liste").

**Interaktion.** Auswahl wechselt die Liste mit Überblendung (`fadeReduced`), keine Haptik; Tippen daneben schließt; Zurück-Morph in den Titel. VoiceOver: Titel ist "Liste wechseln, Wocheneinkauf, 11 offen, Taste".

**AX und 320 pt.** Menü nimmt höchstens die Breite minus 2 × 16 pt; Namen brechen um; ab AX3 entfällt der Glyph im Menü, die Anzahl rutscht unter den Namen.

**Was sich ändert.** Ersetzt den Listen-Index der Startseite (`home_screen.dart:341-480`) als schnellen Weg; Ungelesen-Anzeige ist neu (`UnreadService.isUnread` wird erstmals gelesen).

**Bildbeschreibung für ChatGPT.**
Ausschnitt des Listen-Screens wie oben, aber aus dem großen Titel "Wocheneinkauf" ist ein Liquid-Glass-Menü mit 20 pt Eckenradius nach unten aufgeklappt, der Hintergrund ist leicht abgedunkelt. Im Menü fünf Zeilen, jede mit einem runden Farbkreis mit weißem Symbol links: blauer Kreis #007AFF mit Einkaufswagen und "Wocheneinkauf" mit grünem Häkchen #3F7A1F davor und rechts "11", orangener Kreis #FF9500 mit Konfetti-Symbol "Party Samstag" und "14", grüner Kreis #34C759 mit Haus "WG-Vorrat" mit einem kleinen grünen Punkt und "6", roter Kreis #FF3B30 mit Korb "REWE" und "4", lila Kreis #AF52DE mit Tasche "Drogerie" und "3". Nach einem schmalen Abstand drei Zeilen in Schwarz mit Symbolen rechts: "Neue Liste" (Plus), "Liste beitreten" (Kettenglied), "Alle Listen" (Liste). Schrift SF Pro 17 pt, Zahlen in Grau #636366.

---

### 1.3 Menü "Mehr" (`ellipsis`)

**Zweck.** *Was kann ich mit dieser Liste tun?*

**Aufbau** (`AppMenu` aus dem Knopf, Gruppen durch 8-pt-Bänder):
1. "Einkaufen" (`cart`, nur mit offenen Artikeln), "Einkauf abschließen" (`checkmark.circle`, nur wenn Erledigtes da ist).
2. "Listen-Info" (`info.circle`), "Reihenfolge im Markt" (`arrow.up.arrow.down`), "Beim Start zeigen" (`pin`, Häkchen links, wenn aktiv).
3. "Angebote für diese Liste ausblenden" (`tag`, Slot B: `setOffersHiddenForList`, nur Modul an).
4. "Erledigte entfernen" (`trash`, normaler Text, weil umkehrbar: Rückgängig-Hinweis "2 erledigte Artikel entfernt · Widerrufen"; sie kommen nicht in den Verlauf).

**Zustände.** Einträge ohne Bedeutung entfallen (nicht deaktiviert). Offline: alles verfügbar (Warteschlange).

**Was sich ändert.** Ersetzt `list_detail_menu.dart` (Umbenennen, Kategoriereihenfolge, Listeneinstellungen). Umbenennen wandert in Listen-Info.

**Bildbeschreibung für ChatGPT.**
Oben rechts auf dem Listen-Screen ist aus dem runden Glas-Knopf mit drei Punkten ein Liquid-Glass-Menü gewachsen, etwa 250 pt breit, mit 20 pt Ecken. Erste Gruppe: "Einkaufen" mit Einkaufswagen-Symbol rechts, "Einkauf abschließen" mit Häkchen-Kreis. Zweite Gruppe nach einem schmalen grauen Band: "Listen-Info" (i im Kreis), "Reihenfolge im Markt" (zwei Pfeile hoch und runter), "Beim Start zeigen" mit einem grünen Häkchen #3F7A1F links und einer Stecknadel rechts. Dritte Gruppe: "Angebote für diese Liste ausblenden" mit Preisschild-Symbol. Vierte Gruppe: "Erledigte entfernen" mit Papierkorb. Text 17 pt Schwarz #000000, Symbole in Schwarz, Hintergrund des Screens leicht abgedunkelt.

---

### 1.4 Gesten am Artikel im Überblick

| Geste | Normale Liste | Einkaufsmodus |
|---|---|---|
| Tippen Kreis-Bereich (56 pt vorne) | abhaken | abhaken |
| Tippen Rest der Zeile | Artikel-Sheet | abhaken (K-36) |
| Wischen nach links | Bearbeiten, Löschen (volles Wischen löscht) | Löschen (volles Wischen löscht) |
| Wischen nach rechts | – | nur in "Im Wagen": zurückholen |
| Langdruck | Kontextmenü, dann Ziehen zum Umsortieren | Kontextmenü (Bearbeiten, Menge, Kategorie, Löschen); kein Umsortieren |
| VoiceOver | ein Element "Milch, Menge 2, im Angebot 0,99 Euro laut Händler, nicht erledigt"; Doppeltippen hakt ab; Aktionen: Bearbeiten, Menge ändern, Verschieben, Löschen | gleich, Doppeltippen hakt ab, Ansage "5 von 11 erledigt" |

---

### 1.5 Geteilte Liste live und Präsenz

**Zweck.** Plan 4: *sehen, wer gerade einkauft; Abgehaktes live.*

**Was man sieht.**
- **Metazeile:** Avatar-Stapel der Mitglieder (ohne einen selbst).
- **Präsenz-Zeile** unter der Metazeile, nur wenn jemand im Einkaufsmodus ist: "Lena kauft gerade bei Lidl ein" (Markt nur, wenn die Liste einen Markt hat; sonst "Lena kauft gerade ein"). Der Punkt pulsiert beim Erscheinen einmal (Reduce Motion: statisch). Zwei Personen: "Lena und Max kaufen gerade ein".
- **Live-Änderungen:** Neue Artikel anderer wachsen an ihrem Platz ein (`springStandard`) mit Unterzeile "von Lena". Von anderen abgehakte Zeilen zeigen 2 s den Avatar (16 pt) unten rechts am Kreis, dann wandern sie wie eigene. Von anderen gelöschte Zeilen fallen ohne Meldung zusammen. Umbenennen der Liste aktualisiert den Titel mit Überblendung.
- **VoiceOver** sagt höflich an: "Lena hat Butter abgehakt", "Lena hat Kaffee hinzugefügt" (gebündelt, höchstens eine Ansage pro 3 s).
- **Titelmenü und Alle Listen:** Ungelesen-Punkt und Präsenz-Unterzeile.
- **Mitteilungen** (Teil B, K-39): gebündelt; "Lena kauft gerade bei Lidl ein" einmal pro Einkauf; nie eine Mitteilung pro Häkchen.

**Regeln (L-01).**
- Präsenz läuft über Supabase Realtime Presence auf dem Kanal der Liste; Nutzlast: Nutzer-ID, Anzeigename, Avatar, Modus (`ansehen` oder `einkaufen`), Markt, Beginn. Angezeigt wird nur `einkaufen`; "schaut gerade" wird nicht gezeigt (Privatsphäre, kein Mehrwert).
- Präsenz endet beim Verlassen des Einkaufsmodus, nach 5 Minuten im Hintergrund (01 Kap. 10.2) oder beim Abschluss.
- Nach Rückkehr aus dem Hintergrund (über 2 s) lädt die Liste einmal nach (00 Kap. 13).
- Gleichzeitiges Abhaken desselben Artikels ist kein Konflikt (beide sehen ihn abgehakt). Ändern zwei Personen dasselbe Feld, gewinnt die letzte Änderung; keine Meldung.
- Leistung: ein Realtime-Kanal pro sichtbarer Liste (gefiltert auf `list_id`), kein globaler ungefilterter Kanal; das eigene Echo löst kein Neuladen aus.

**Was sich ändert.** Präsenz gibt es heute nicht. Push pro Häkchen (`item_repository.dart:267-276`) entfällt zugunsten gebündelter Mitteilungen (B). Der globale Kanal ohne Filter (`list_repository.dart:282-300`) wird ersetzt. Neu: `lib/data/services/list_presence_service.dart` (A).

**Bildbeschreibung für ChatGPT.**
Gleicher Listen-Screen "Wocheneinkauf" wie oben, aber unter der Metazeile mit "Lidl" und "11 offen" steht eine zusätzliche Zeile: ein kleiner runder Avatar einer Frau mit einem grünen Punkt #3F7A1F unten rechts und daneben der Text "Lena kauft gerade bei Lidl ein" in Schwarz, 15 pt. In der Sektion "Milch & Käse" ist die Zeile "Butter" gerade abgehakt: der Kreis ist grün gefüllt mit weißem Häkchen, der Name grau #636366 und durchgestrichen, und unten rechts am Kreis sitzt ein winziger 16-pt-Avatar von Lena. Sonst wie der Haupt-Screen, Hintergrund #F2F2F7, weiße Sektionen, Glas-Leiste unten.

---

### 1.6 Offline, Warteschlange und Sync-Zeichen

**Zweck.** Im Laden ohne Netz darf nichts verloren gehen (00 Kap. 13).

**Regeln (L-02).**
- Jede Änderung (hinzufügen, abhaken, ändern, löschen, umsortieren, Liste anlegen, umbenennen, Farbe) wird sofort lokal angewendet und in eine **dauerhafte Warteschlange** geschrieben (übersteht App-Ende und Neustart). Gesendet wird in Reihenfolge, sobald Netz da ist.
- Neue Artikel und Listen bekommen ihre endgültige ID (UUID) im Gerät (E-03). Dadurch sind frische Artikel sofort bedienbar (behebt Bug "1-3 s nicht bedienbar") und Wiederholungen sind idempotent (behebt doppelte Mengen beim Import).
- Ausstehende Zeilen tragen am Kreis `arrow.triangle.2.circlepath` 10 pt in `labelSecondary` (`CheckCircle`-Zustand "ausstehend").
- Fehlschlag nach Netz-Rückkehr (z. B. Liste inzwischen gelöscht, keine Rechte): Zeile zeigt "Nicht gespeichert" mit `exclamationmark.circle` in `danger`, Tippen wiederholt; Wischen löscht lokal. Fehler-Haptik einmal.
- Netz-Funktionen zeigen am Ort "Braucht eine Verbindung": Liste beitreten, Code erzeugen, Zettel importieren, Angebotszeilen, Avo.

**`StatusRow`-Texte in diesem Bereich.**

| Lage | Text |
|---|---|
| offline, nichts ausstehend | "Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist." |
| offline, ausstehend | "Offline. 3 Änderungen warten." |
| online, Senden läuft länger als 3 s | "3 Änderungen werden gesendet." |
| Senden fehlgeschlagen | "1 Änderung konnte nicht gespeichert werden. Erneut versuchen" |
| Einkaufsmodus offline | "Offline. Abhaken wird gespeichert und später gesendet." |

**Bildbeschreibung für ChatGPT (Zustand offline in der Liste).**
Listen-Screen "Wocheneinkauf" wie im Hauptbild, Hintergrund #F2F2F7. Direkt unter der Metazeile mit "Lidl" und "11 offen" steht eine Zeile ohne Fläche: links ein graues Wolke-mit-Schrägstrich-Symbol #636366, daneben in Schwarz 15 pt "Offline. 2 Änderungen warten." In der Sektion "Obst & Gemüse" ist "Bananen" grün abgehakt #3F7A1F und trägt unten rechts am Kreis ein winziges graues Pfeil-Kreis-Symbol (Sync), ebenso die neue Zeile "Backpapier" in "Haushalt & Drogerie". Keine roten Banner, keine Warnfarben. Unten wie gewohnt die Glas-Leiste mit "Artikel hinzufügen" und "Einkaufen".

**Bildbeschreibung für ChatGPT (Zustand "Alles erledigt").**
Listen-Screen "Wocheneinkauf" auf #F2F2F7 mit Titel und Metazeile "Lidl · 0 offen". Wo sonst die Artikel stehen, mittig ein flach gezeichnetes, zufrieden lächelndes Avocado-Maskottchen in zwei Grüntönen mit braunem Kern, 96 pt groß. Darunter "Alles erledigt. Schön." in 20 pt halbfett Schwarz, darunter "13 Artikel sind abgehakt." in 17 pt Schwarz und eine breite grüne Kapsel #3F7A1F mit weißem Text "Einkauf abschließen". Darunter eine eingeklappte weiße Zeile "Erledigt (13)" mit Pfeil. Unten die Glas-Kapsel "Artikel hinzufügen" über die volle Breite, ohne "Einkaufen"-Knopf.

**Was sich ändert.** Heute scheitert offline jede Mutation und wird zurückgerollt; `_OfflineBanner` erscheint in Liste und Einkaufsmodus nicht. Betroffen: `items_provider.dart`, `lists_provider.dart`, `item_repository.dart`, `list_repository.dart`, `offline_cache_service.dart` (Warteschlange, A).

---

## 2. Hinzufügen

### 2.1 `AddItemAccessory` in Ruhe

**Zweck.** *Was will ich hinzufügen?* und der Start des Einkaufsmodus. Immer sichtbar an der Wurzel des Tabs Liste (00 Kap. 12.4).

**Aufbau (links nach rechts, eine `LiquidGlassGroup`):**
1. Glas-Kapsel: `plus` 17 pt `labelSecondary` (dekorativ), Textfeld (`body`, Platzhalter "Artikel hinzufügen" in `labelSecondary`), `text.viewfinder` (44-pt-Ziel, "Zettel importieren").
2. 8 pt Abstand.
3. Getönte Glas-Kapsel (`action`) mit `cart` und "Einkaufen" (`headline`, `onAction`). Nur sichtbar, wenn mindestens ein Artikel offen ist; sonst wächst das Feld mit `springStandard` über die volle Breite.

**Beispiel.** "+ Artikel hinzufügen [Scanner]" und rechts "Einkaufen".

**Zustände.** leer; mit Text; mehrzeilig (bis 3 Zeilen, ab AX3 bis 2, dann scrollt das Feld, E-04); fokussiert (2.2); Verarbeitung Zettel (3.2); kurze Bestätigung nach dem Hinzufügen außerhalb des Sichtbereichs: Platzhalter wird 1,5 s zu "Milch → Milch & Käse" (`subheadline`, `labelSecondary`, Überblendung); offline: gleich, neue Zeilen tragen das Sync-Zeichen; Liste ohne offene Artikel: ohne "Einkaufen".

**Interaktion.** Tippen ins Feld fokussiert (keine Haptik). "Einkaufen" startet den Einkaufsmodus (5.1). `text.viewfinder` öffnet das Import-Menü (3.1). Tastatur offen: Tab-Bar fährt mit `springStandard` weg, das Accessory sitzt direkt auf der Tastatur.

**320 pt und große Schrift** (Tabelle 00 Kap. 6.3):
- Unter 350 pt Breite: "Einkaufen" nur als getönter Symbol-Kreis 44 pt mit `cart`; VoiceOver und Large Content Viewer "Einkaufsmodus starten".
- 375 pt: Symbol und Text bis xxL, darüber nur Symbol. Ab 390 pt: Symbol und Text bis xxxL.
- Symbole im Accessory wachsen bis xxxL (23 pt) und bleiben dann (E-04); der Text wächst weiter.
- Würde das Feld schmaler als 160 pt (320 pt ab xxxL), verlässt `text.viewfinder` die Kapsel und erscheint als erste Zeile "Zettel importieren" im Vorschlags-Panel und im Menü "Mehr" (E-04).

**Bildbeschreibung für ChatGPT.**
Nahaufnahme des unteren Bildschirmdrittels eines iPhones mit einer Einkaufsliste dahinter (weiße Zeilen auf #F2F2F7, leicht unscharf durch das Glas). Über der schwebenden Glas-Tab-Bar liegt eine Liquid-Glass-Leiste: links eine breite, milchig-transparente Kapsel 48 pt hoch mit einem grauen Plus #636366, dem grauen Platzhalter "Artikel hinzufügen" in 17 pt und am rechten Ende einem Textscanner-Symbol (Rahmen mit Textzeilen); 8 pt daneben eine kürzere Glas-Kapsel, grün getönt #3F7A1F, mit weißem Einkaufswagen-Symbol und dem Wort "Einkaufen" in Weiß #FFFFFF, halbfett. Beide Kapseln wirken wie aus einem Stück Glas, ihre Kanten fließen ineinander. Darunter die Glas-Tab-Bar mit "Liste" ausgewählt in Grün und rechts der runde Avo-Kreis mit braunem Kern #7A4A24 und hellgrünem Ring #C9DE6E.

---

### 2.2 Fokussiert, mit Vorschlags-Panel

**Zweck.** Schnell eintragen, ohne zu tippen, was man schon oft gekauft hat.

**Aufbau (von unten nach oben):** Tastatur; Accessory auf der Tastatur (ohne "Einkaufen"); 8 pt darüber das **Vorschlags-Panel**: Fläche `surfaceElevated`, `radiusCard`, `shadowFloat`, kein Glas, Breite wie das Accessory, bis 5 Zeilen à mindestens 44 pt:
1. **Vorschau des Getippten** (nur mit Text): `plus.circle.fill` in `action` 22 pt, Name (`body`), Unterzeile (`subheadline`, `labelSecondary`) "Menge 2 · Obst & Gemüse". Ist der Artikel mit gleicher Einheit schon offen: "Schon auf der Liste (2), Menge wird 4". Mehrere Artikel (Komma oder Zeilenumbruch): "3 Artikel hinzufügen" mit Unterzeile "Milch, Eier, Butter".
2. **Verlauf** (bis 3, bzw. vor dem ersten Buchstaben bis 5): Artikel aus dem eigenen Kaufverlauf, die nicht offen auf der Liste stehen; Präfix- und Teilwort-Treffer, sortiert nach Häufigkeit und Aktualität. Zeile: `clock.arrow.circlepath` 17 pt `labelSecondary`, Name, Unterzeile mit Kategorie und zuletzt verwendeter Menge ("500 g · zuletzt am 31. Okt.").
3. **Angebote des Listen-Markts** (Slot B `OfferSuggestionsBar(listId:, query:)`, bis 3, ab 2 Zeichen, nur Modul an, nur Markt der Liste bzw. Region, wenn kein Markt): Avo Symbol der Kategorie (kein Händlerbild), Produktname mit Größe, Unterzeile "Lidl · bis Sa., 14. Nov.", rechts gelbes Schild mit Preis; "Ähnliches Produkt" als Unterzeile bei Broad-Match. Erscheinen nur in vorab reserviertem Platz unterhalb der Verlaufszeilen (nie verschieben sie die Vorschau).
4. Ab AX3 oder wenn der Platz zwischen Navigationsleiste und Accessory kleiner ist: weniger Zeilen, die Vorschau bleibt immer.

**Beispiel.** Getippt "2 Paprika". Vorschau "Paprika · Menge 2 · Obst & Gemüse". Verlauf: "Paprika rot · 3 Stück · zuletzt am 24. Okt.", "Paprikapulver · Vorrat". Angebot: "Spitzpaprika rot, 500 g · Lidl · bis Sa., 14. Nov." mit Schild "1,49 €".

**Zustände.** Vor dem ersten Buchstaben: nur Verlauf ("Oft gekauft"), ohne Kopfzeile. Keine Treffer: nur Vorschau. Kein Verlauf (neuer Nutzer): Panel zeigt nur die Vorschau, vorher gar nichts. Offline: Verlauf aus dem lokalen Stand, keine Angebotszeilen, kein Hinweis. Fehler der Angebotsquelle: Zeilen entfallen still.

**Interaktion.** Return fügt die Vorschau hinzu und behält den Fokus; Tippen auf eine Zeile fügt diese hinzu (Verlauf mit seiner Menge, Angebot mit Preis und Händler ohne KI-Umschreibung des Namens). Danach leert sich das Feld, das Panel zeigt wieder "Oft gekauft". Die neue Zeile wächst in ihrer Kategorie ein (`springStandard`); VoiceOver "Paprika hinzugefügt, Obst und Gemüse". Keine Haptik beim Hinzufügen (normale Aktion). Wischen nach unten auf dem Panel oder Tippen in die Liste schließt die Tastatur. Das Panel blendet mit `fadeReduced` ein, Zeilen wechseln ohne Sprung (feste Reihenfolge der Bereiche).

**AX und 320 pt.** Zeilen brechen um, das Schild rutscht ab AX1 unter den Namen. Bei 320 pt und AX3: Vorschau plus 1 Verlaufszeile sichtbar, Panel scrollt intern.

**Was sich ändert.** Heute gibt es weder Verlaufsvorschläge noch lokale Mengen-Erkennung; die Angebotskarte mit festen 72-pt-Zeilen, "ANGEBOTE IN DER NÄHE" und "Spare bis zu X €" (`offer_suggestions_bar.dart`) entfällt. Der Senden-Pfeil entfällt (Return und Vorschau-Zeile genügen). Betroffen: `add_item_composer.dart` (wird Komponente in `widgets/design/`, Teil A), neu `screens/lists/widgets/item_suggestion_panel.dart`, Verlaufsquelle über `PurchaseTrackingService` bzw. Empfehlungs-Dienst (B, stabile API).

**Bildbeschreibung für ChatGPT.**
iPhone mit geöffneter Systemtastatur im Hellmodus. Direkt auf der Tastatur sitzt eine Liquid-Glass-Kapsel mit grauem Plus und dem getippten Text "2 Paprika" in Schwarz 17 pt, rechts ein Textscanner-Symbol; der grüne "Einkaufen"-Knopf ist verschwunden. Darüber schwebt ein weißes Panel #FFFFFF mit 20 pt Eckenradius und weichem Schatten, darin vier Zeilen mit feinen Trennlinien: oben ein grüner gefüllter Plus-Kreis #3F7A1F mit "Paprika" und grauer Unterzeile "Menge 2 · Obst & Gemüse" #636366; dann zwei Zeilen mit grauem Uhr-Pfeil-Symbol "Paprika rot" ("3 Stück · zuletzt am 24. Okt.") und "Paprikapulver" ("Vorrat"); unten "Spitzpaprika rot, 500 g" mit Unterzeile "Lidl · bis Sa., 14. Nov." und rechts einem kleinen gelben Preisschild #FFD60A mit "1,49 €" in Fast-Schwarz #1C1C1E. Oberhalb des Panels ist die Liste "Wocheneinkauf" auf #F2F2F7 zu sehen.

---

### 2.3 Eingabe verstehen: "2 Milch" (L-03)

Alles läuft lokal und sofort; nichts wartet auf das Netz.

| Eingabe | Ergebnis |
|---|---|
| `2 Milch`, `Milch 2`, `2x Milch`, `2 x Milch`, `Milch x2` | Milch, Menge 2, Einheit Stück |
| `500 g Mehl`, `500g Mehl`, `Mehl 500 g` | Mehl, 500, g |
| `1,5 l Wasser`, `1.5l Wasser` | Wasser, 1,5, l |
| `1 kg Kartoffeln`, `2 Pck. Butter`, `2 Packungen Butter` | Einheit kg bzw. Packung |
| `zwei Gurken`, `ein Brot`, `ein Dutzend Eier` | Zahlwörter eins bis zwölf, "Dutzend" = 12 Stück |
| `Milch, Eier, Butter` oder mehrere Zeilen (Einfügen) | drei Artikel, Vorschau "3 Artikel hinzufügen" |
| `Milch (laktosefrei)` | Milch, Notiz "laktosefrei" |
| `Tomaten 2 Dosen` | Tomaten, 2, Dose |
| `7Up`, `4 Jahreszeiten Pizza` | Ziffern im Namen bleiben Name, wenn kein Trenner folgt (Wörterbuch bekannter Namen; sonst KI-Korrektur im Hintergrund ohne Sprung des Namens) |

- **Einheiten (Anzeige):** Stück, g, kg, ml, l, Packung, Flasche, Dose, Schachtel, Dutzend (IDs aus `Categories.units`). Komma und Punkt als Dezimaltrenner; Anzeige nach Locale ("1,5 l").
- **Zusammenführen:** gleicher Name (ohne Groß-/Kleinschreibung) und gleiche Einheit auf offenen Artikeln erhöht die Menge; Rückgängig-Hinweis "Milch: Menge jetzt 4 · Widerrufen". Andere Einheit ergibt einen zweiten Artikel.
- **Kategorie sofort:** 1. gelernte Zuordnung dieses Nutzers (Kategorie-ID pro Artikelname, im Konto gespeichert, E-07), 2. Schlüsselwörter aus `categories.dart`, 3. sonst "Sonstiges". Die KI (Claude, Teil B, stabile API) bestätigt im Hintergrund; weicht sie ab und hat der Nutzer die Kategorie nicht selbst gesetzt, wandert die Zeile mit `springStandard` (ohne Sprung, ohne Meldung). Eine eigene Zuordnung (Ziehen, Artikel-Sheet, Kontextmenü) gewinnt immer und wird gelernt.
- **Diät und Allergien:** passt ein Artikel nicht zu den Einstellungen, trägt die Zeile in der Unterzeile `exclamationmark.triangle.fill` in `warning` mit "Enthält Laktose" (behebt "Diät-Warnung nie angezeigt"). Nie Maskottchen, nie Witz.
- **Was sich ändert:** Heute parst ein LLM-Aufruf die Menge ("2 Milch" steht 1-3 s als "2 Milch, Menge 1" in "Sonstiges"). Neu: `lib/core/utils/item_input_parser.dart` (A, mit Unit-Tests), `SmartCategorizationService` arbeitet mit Kategorie-IDs statt lokalisierten Namen. Betroffen: `item_repository.dart:106-172`, `list_category_section.dart:147`, `smart_categorization_service.dart:238-245`.

---

### 2.4 Bugfix Eingabeleiste (Verbesserungsliste Punkt 2)

**Ursache heute.** Im iOS-Glas-Pfad liegt der Inhalt in `SizedBox(height: h)` mit `Stack`; `h` wird nach dem Frame aus genau diesem Inhalt gemessen und kann deshalb nie über den Startwert 38 pt wachsen (`add_item_composer.dart:111-118`, `211-245`). Jede Textgröße über Standard, jeder Umbruch und fetter Text werden oben und unten abgeschnitten, auf jedem iPhone, besonders sichtbar bei 320 pt mit Anzeigezoom.

**Neue Regel (L-04).**
1. Die Höhe kommt aus der Textmetrik vor dem Layout: `lineHeight = AppText.of(context, body).height × fontSize` (Kategorie aus `DesignScope`, inklusive fettem Text); `zeilen` aus einem `TextPainter` mit der tatsächlich verfügbaren Feldbreite (aus `LayoutBuilder`, gleicher Frame), begrenzt auf 1 bis 3 (ab AX3: 2). `höhe = max(48, lineHeight × zeilen + 2 × 13)`.
2. Der Flutter-Inhalt bestimmt die Größe des `Stack`; die native Glasform liegt als `Positioned.fill` dahinter. Kein `SizedBox(height:)` um Text, kein `_height`-Zustand, keine Messung nach dem Frame, kein `setState` auf dem ganzen Screen.
3. Ändert sich die Höhe, sendet der Baustein die neue Form über den Glas-Update-Kanal (00 Kap. 8.4). Eine Zeile: Kapsel (Radius = Höhe / 2). Ab zwei Zeilen: Rechteck mit Radius 24 (halbe Mindesthöhe), damit die Ecken konzentrisch zur Kapsel bleiben, wie in Nachrichten.
4. `TextField(minLines: 1, maxLines: 3)`, `textScaler` aus dem `DesignScope` (keine doppelte Skalierung), vertikaler Innenabstand 13 pt, Text vertikal zentriert bei einer Zeile.
5. Der untere Inhaltsabstand der Liste kommt aus `ShellInsets` und folgt der Accessory-Höhe ohne Nachmessen (heute geschätzt 110 pt und nachgemessen).

**Beispielwerte.** L: 22 pt Zeile → 48 pt. xxxL: 23 pt × 1,29 = 30 pt → 56 pt. AX3: 40 pt × 1,29 = 52 pt → 78 pt. AX5: 53 pt × 1,29 = 68 pt → 94 pt pro Zeile, zweizeilig 162 pt.

**Abnahme (Pflicht, Teil A).**
- Echtes iPhone 13 Pro mit Anzeigezoom "Größerer Text" (320 pt), Textgröße AX5, fetter Text an: Platzhalter, eine Zeile, Umbruch auf zwei Zeilen, Scrollen ab Zeile 3; nichts abgeschnitten, Glasform passt.
- Dasselbe mit Textgröße L, xxxL und AX3; dazu iPhone SE (375 pt).
- Widget-Test in `test/layout/` mit 320, 375, 390, 402, 440 pt × L, xxxL, AX3, AX5 × fett an/aus: kein Überlauf, Höhe = Formel.
- Screenshots in `status-A.md`.

**Bildbeschreibung für ChatGPT.**
Vergleichsbild zweier iPhone-Ausschnitte nebeneinander, beide 320 pt breit mit sehr großer Bedienungshilfen-Schrift. Links (vorher): eine schmale Glas-Kapsel, in der die Wörter "Artikel hinzufügen" oben und unten abgeschnitten sind. Rechts (nachher): eine hohe Liquid-Glass-Fläche mit 24 pt runden Ecken, die zwei Zeilen großen Text "2 Packungen Butter" vollständig zeigt, links ein graues Plus #636366, rechts daneben ein grün getönter runder Glas-Knopf #3F7A1F mit weißem Einkaufswagen. Hintergrund hinter dem Glas: weiße Listenzeilen auf #F2F2F7. Beschriftung unter den Bildern in Grau: "Vorher" und "Nachher".

---

## 3. Zettel importieren

### 3.1 Menü und Vorab-Erklärung

**Zweck.** Eine Liste vom Papier, aus einem Screenshot oder einer Datei übernehmen. Einstieg: `text.viewfinder` im Accessory (bzw. Panel-Zeile bei Platzmangel), Avo-Kreis mit `camera`.

**Aufbau.** `AppMenu` wächst aus dem Symbol: "Kamera" (`camera`), "Fotos" (`photo.on.rectangle`), "Dateien" (`folder`). Keine Erklärtexte, keine Kreise hinter Symbolen. Beim ersten Kamera-Aufruf vorher ein **Sheet mittel** (00 Kap. 13, Berechtigung): `camera` 48 pt Light, "Zettel fotografieren" (`title3`), "Die Kamera wird nur für dieses Foto benutzt. Das Bild wird nach dem Auslesen gelöscht." (`body`), prominent "Weiter", schlicht "Nicht jetzt"; danach die Systemabfrage.

**Zustände.** Kamera abgelehnt: `StatusRow` im Menü-Ort als Rückgängig-Hinweis-Fläche "Kamera ist aus. In Einstellungen erlauben" mit Link. Offline: Menüeinträge deaktiviert, Unterzeile "Braucht eine Verbindung".

**Was sich ändert.** Das 82-%-Glas-Panel mit farbigen Kreis-Icons und Erklärtext (`attachment_sheet.dart`) entfällt; der Text "Avo liest deine Liste" entfällt (Funktion ohne Avo-Namen, 01 Kap. 3).

### 3.2 Verarbeitung im Accessory

**Aufbau.** Nach der Auswahl wird das Accessory zur Status-Kapsel: kleiner Fortschrittsindikator am Ort des `plus` (Systembaustein, kein Spinner im Inhalt), Text "Zettel wird gelesen …" (`body`), rechts schlicht "Abbrechen". Die Liste bleibt bedienbar.

**Zustände.**

| Lage | Anzeige |
|---|---|
| läuft | "Zettel wird gelesen …" |
| länger als 8 s | "Dauert etwas länger …" |
| keine Liste erkannt | Kapsel: "Auf dem Bild wurde keine Liste erkannt." mit schlicht "Anderes Bild", nach 6 s zurück zum Feld; Fehler-Haptik |
| Datei nicht lesbar (HEIC, PDF) | "Diese Datei lässt sich nicht lesen. Anderes Bild" |
| Netzfehler | "Das hat nicht geklappt. Erneut versuchen" |
| abgebrochen | Feld kehrt mit `springStandard` zurück, Upload wird gelöscht |

Alle Fehlerwege enden in einem Zustand mit Aktion (behebt "Menü bleibt im Laden hängen": jeder Fehler aus Picker, PDF-Rendering und Upload wird gefangen).

**AX und 320 pt (3.1, 3.2).** Menüzeilen brechen um; der Status-Text in der Kapsel bricht auf zwei Zeilen und die Kapsel wächst nach der Formel aus 2.4; "Abbrechen" bleibt 44 pt.

**Bildbeschreibung für ChatGPT (Menü und Verarbeitung).**
Zwei iPhone-Ausschnitte des unteren Bildschirmrands über einer Einkaufsliste auf #F2F2F7. Links: aus dem Textscanner-Symbol am rechten Ende der Glas-Kapsel "Artikel hinzufügen" ist ein kleines Liquid-Glass-Menü nach oben gewachsen mit drei Zeilen "Kamera", "Fotos", "Dateien", jeweils mit schwarzem SF Symbol rechts (Kamera, zwei Fotos, Ordner), ohne farbige Kreise. Rechts: die Glas-Kapsel zeigt statt des Platzhalters einen kleinen grauen Fortschrittskreis, den Text "Zettel wird gelesen …" in Schwarz und rechts grünen Text #3F7A1F "Abbrechen"; der grüne "Einkaufen"-Knopf daneben ist unverändert. Die Liste dahinter bleibt vollständig sichtbar, kein abgedunkelter Hintergrund.

### 3.3 Sheet "14 Artikel erkannt"

**Zweck.** *Stimmen die erkannten Artikel?* Öffnet sich nach erfolgreicher Erkennung als Sheet groß (Inhalt ist eine Liste).

**Aufbau.**
1. Kopf (`LargeTitleNavBar`, Variante Sheet): `xmark` links, Inline-Titel "14 Artikel erkannt".
2. Zielliste als `ValueRow`: "Auf Liste: Wocheneinkauf" mit Menü (Standard: aktuelle Liste).
3. Sektion "Erkannt": Zeilen mit Auswahl-Kreis links (`checkmark.circle.fill` in `action` = wird hinzugefügt, Ring `controlOutline` = abgewählt; alle vorausgewählt), Name (`body`, Tippen macht ihn editierbar), Unterzeile Kategorie, rechts Menge mit Einheit (`number`, Tippen öffnet Menü mit `ValueStepper` und Einheiten). Unsichere Zeilen (Sicherheit unter 0,75): Unterzeile `questionmark.circle` 13 pt in `labelSecondary` + "Bitte prüfen" in `label`. Schon offene Artikel: Unterzeile "Schon auf der Liste, Menge wird addiert".
4. Sektion "Nicht erkannt (2)" (heute verworfen, `unparsedLines`): Rohtext in `label`, Unterzeile "Tippen, um als Artikel zu übernehmen"; Tippen verschiebt die Zeile nach "Erkannt" (wächst ein) und macht den Namen editierbar.
5. Sektionsfuß: "Das Bild wurde nach dem Auslesen gelöscht."
6. Unten fest über dem Rand (auf `bgGroupedElevated`, Scroll-Edge-Verlauf darüber): prominent "13 Artikel hinzufügen" (Zahl rollt bei Ab- und Anwahl).

**Beispiel.** 14 erkannt: Kartoffeln 1 kg, Möhren, Zwiebeln 3, Lauch, Sahne 2, Parmesan, Penne, Hackfleisch 500 g, Spülmittel, Klopapier, Apfelsaft 2, Brot, Äpfel 6, "Schmand?" (unsicher). Nicht erkannt: "für Sonntag", "Oma anrufen". Ein Artikel abgewählt (Brot) → "13 Artikel hinzufügen".

**Zustände.** Alles abgewählt: Hauptaktion deaktiviert ("0 Artikel hinzufügen"). Offline während des Sheets: Hinzufügen geht in die Warteschlange (lokal sofort). Schließen mit Änderungen: Aktionsblatt "Erkannte Artikel verwerfen?" mit "Verwerfen" (rot) und "Abbrechen".

**Interaktion.** Hinzufügen schreibt alle Artikel in einem Stapel mit Geräte-IDs (atomar, wiederholbar ohne Verdopplung, E-03); das Sheet schließt (`springSheet`), die Zeilen wachsen in ihren Kategorien ein, Rückgängig-Hinweis "13 Artikel hinzugefügt · Widerrufen". Kein Erfolgsmoment (keine Feier für Routine). Wischen nach links auf einer Zeile: "Entfernen".

**AX und 320 pt.** Menge rutscht ab AX1 unter den Namen; keine festen Breiten für Menge und Einheit (heute 42 und 44 pt). Hauptaktion bricht um, Höhe wächst.

**Was sich ändert.** Ersetzt `import_review_sheet.dart` (60-%-Sheet mit Blur, 55-%-Deckkraft für unsichere Zeilen, Minus-Knöpfe). Import ist heute sequenziell und dauert bei 20 Artikeln über 25 s; neu ein Stapel. Betroffen: `items_provider.dart:323-332`, `list_import_service.dart` (B, Sprache aus der App-Sprache statt `userMetadata`, alle PDF-Seiten).

**Bildbeschreibung für ChatGPT.**
Ein großes iOS-Sheet auf hellgrauem Grund #F2F2F7 mit runden Ecken oben, dahinter ist der Listen-Screen verkleinert und abgedunkelt zu sehen. Oben links ein runder Glas-Knopf mit X, mittig der Titel "14 Artikel erkannt" in 17 pt halbfett. Darunter eine weiße Zeile "Auf Liste: Wocheneinkauf" mit kleinem Pfeil. Dann eine weiße Sektion "Erkannt" mit Zeilen: links je ein grün gefüllter Häkchen-Kreis #3F7A1F, Namen "Kartoffeln" (rechts "1 kg"), "Möhren", "Zwiebeln" (rechts "3"), "Sahne" (rechts "2"), "Schmand" mit grauer Unterzeile mit Fragezeichen-Kreis und "Bitte prüfen", und eine Zeile "Brot" mit leerem grauen Ring #8A8A8E. Darunter Sektion "Nicht erkannt (2)" mit "für Sonntag" und "Oma anrufen" in Schwarz und grauer Unterzeile "Tippen, um als Artikel zu übernehmen". Unten über dem Rand eine breite grüne Kapsel #3F7A1F mit weißem Text "13 Artikel hinzufügen".

---

## 4. Artikel-Sheet

**Zweck.** *Wie viel wovon, in welcher Kategorie, mit welcher Notiz?* Einstieg: Name einer Zeile antippen, "Bearbeiten" im Kontextmenü oder Wischen.

**Aufbau** (`AppSheet` mittel, groß bei Tastatur; Hintergrund `bgGroupedElevated`, Zeilen `surfaceElevated`):
1. Kopf: `xmark` links, Inline-Titel = Artikelname ("Milch"), `checkmark` rechts getönt (übernehmen, aktiv erst nach einer Änderung; K-30).
2. Sektion: Feld "Name" (`body`), Feld "Notiz" (Platzhalter "Notiz, z. B. 3,5 % Fett").
3. Sektion "Menge": `ValueStepper` (Wert als `RollingNumber`, Schritt 1, bei g/ml Schritt 50, Tippen auf den Wert öffnet Dezimal-Tastatur mit Komma), darunter Einheiten als `FilterChip`s (Einfachauswahl, `Wrap`): Stück, g, kg, ml, l, Packung, Flasche, Dose.
4. Sektion: `NavRow` "Kategorie" mit Wert "Milch & Käse" (öffnet `AppMenu` mit allen Kategorien inkl. eigener, aktuelle mit Häkchen); `NavRow` "Liste" mit Wert "Wocheneinkauf" (Menü der Listen, verschiebt den Artikel).
5. Slot B (nur Modul an und Angebot des Listen-Markts): Zeile mit gelbem Schild "0,99 €", Text "Bei Lidl im Angebot, laut Händler statt 1,19 €", Unterzeile "gültig bis Sa., 14. Nov. · in deiner Region", `chevron.right` → Angebots-Sheet (Kapitel 12). Gespeicherter Preis (falls übernommen): `ValueRow` "Preis" "0,99 € · Lidl · übernommen am 7. Nov.".
6. Diät-Zeile (nur bei Konflikt): `exclamationmark.triangle.fill` `warning`, "Enthält Laktose. Du hast „laktosefrei“ eingestellt."
7. Sektion: Zeile "Hinzugefügt von Lena · Do., 5. Nov." mit Avatar 28 pt (nicht antippbar; heute öffnet sie fälschlich die Rezept-Autorenseite). Slot B `ArticleImage` mit Quelle als `footnote`: "Foto: Open Food Facts, CC BY-SA" (nur bei erkanntem Produkt).
8. Sektion: "Artikel löschen" (Text `danger`).

**Beispiel.** "Milch", Notiz leer, Menge 2 Stück, Kategorie Milch & Käse, Liste Wocheneinkauf, Angebot 0,99 € laut Händler statt 1,19 €, "Hinzugefügt von dir · heute, 9:15".

**Zustände.** Offline: alles änderbar (Warteschlange). Artikel inzwischen von anderen gelöscht: Sheet bleibt offen, Kopf-Unterzeile "Dieser Artikel wurde gelöscht.", `checkmark` wird "Wieder hinzufügen". Artikel von anderen gleichzeitig geändert: Felder, die man nicht selbst bearbeitet, aktualisieren sich live.

**Interaktion.** `checkmark` übernimmt, Sheet schließt, die Zeile aktualisiert sich (wandert bei Kategoriewechsel mit `springStandard`). Wischen nach unten ohne Änderung schließt; mit Änderung Aktionsblatt "Änderungen verwerfen?". "Artikel löschen" schließt sofort und zeigt "Milch gelöscht · Widerrufen" (kein Dialog). Stepper: Auswahl-Haptik pro Schritt. Detent nach Ziehen: Auswahl-Haptik.

**AX und 320 pt.** Ab AX1 werden Einheiten-Chips umgebrochen; `ValueStepper` behält 44-pt-Knöpfe, der Wert bricht nicht; `NavRow`-Werte rutschen unter den Titel. Sheet startet ab AX3 direkt groß.

**Was sich ändert.** Ersetzt `item_form_dialog.dart` (zentrierter Material-Dialog, Creme-Fläche, Schließen 32 pt, Löschen ohne Rückgängig, Komma geht verloren). Neu: Kategorie, Liste, Angebot, Diät-Zeile, Foto-Quelle. `PaperPrimaryButton` aus dieser Datei wird durch `AppButton` ersetzt; Login, Signup, Welcome, OTP und Onboarding importieren ihn heute und werden mit umgestellt (Kapitel 17). Neue Datei: `screens/lists/widgets/item_sheet.dart`.

**Bildbeschreibung für ChatGPT.**
Ein iOS-Sheet in halber Höhe, schwebend mit 8 pt Abstand zum Bildschirmrand und Liquid-Glass-Rand, dahinter die Einkaufsliste. Oben links ein runder Glas-Knopf mit X, mittig "Milch", oben rechts ein runder grün getönter Glas-Knopf #3F7A1F mit weißem Häkchen. Innen auf #F2F2F7 weiße Sektionen #FFFFFF mit 26 pt Ecken: Feld "Milch" und grauer Platzhalter "Notiz, z. B. 3,5 % Fett"; Sektion "Menge" mit einer grauen Kapsel #E9E9EE mit Minus, großer Zahl "2" und Plus, darunter Chips "Stück" (hellgrün hinterlegt #EEF5E4 mit grüner Schrift und Häkchen), "g", "kg", "ml", "l", "Packung"; dann Zeilen "Kategorie · Milch & Käse ›" und "Liste · Wocheneinkauf ›"; dann eine Zeile mit gelbem Preisschild "0,99 €" und dem Text "Bei Lidl im Angebot, laut Händler statt 1,19 €". Ganz unten in Rot #D70015 "Artikel löschen".

---

## 5. Einkaufsmodus

### 5.1 Start: Morph und erster Start

**Zweck.** In den Modus für den Laden wechseln, ohne die Orientierung zu verlieren. Einstieg: "Einkaufen" im Accessory, Menü "Mehr", Siri "Starte meinen Einkauf", `shoply://shopping?list=`, Steuerelement im Kontrollzentrum.

**Bewegung (`springMorph`, 00 Kap. 10.2).** Die Tab-Kapsel zieht sich in den Knopf "Einkaufen" zurück; das Accessory schrumpft zum "+"-Glasknopf unten links; der Avo-Kreis bleibt an seiner Stelle; zwischen beiden wächst aus dem Knopf "Einkaufen" die getönte Kapsel "Einkauf beenden". Gleichzeitig werden die Sektionen randlos (`bgPlain`), Kreise wachsen von 24 auf 36 pt, Namen von 17 auf 22 pt, Zeilen auf mindestens 64 pt; der Titel wechselt mit Überblendung zum Markt. "Erledigt" wird zu "Im Wagen". Reduce Motion oder misslungener Spike: Überblendung beider Zustände in 0,25 s. Keine Haptik (Ortswechsel, kein Ergebnis).

**Erster Start.** Unter dem Kopf einmalig eine Tipp-Zeile (K-21) mit `sun.max` 16 pt: "Der Bildschirm bleibt an, solange du einkaufst." und schlicht "Einstellungen" (öffnet `/settings/lists`). Wegwischen blendet sie dauerhaft aus.

**Präsenz.** Mit dem Start meldet sich das Gerät im Präsenz-Kanal mit Modus `einkaufen` und Markt; Mitglieder sehen live "Jannis kauft gerade bei Lidl ein" und bekommen einmal eine gebündelte Mitteilung (B).

**Bildschirm an.** `wakelock_plus` (schon im Projekt, heute nur im Kochmodus) solange der Modus offen und die App im Vordergrund ist; Einstellung "Bildschirm im Einkaufsmodus anlassen" (Standard an).

### 5.2 Hauptscreen Einkaufsmodus

**Zweck.** *Was fehlt noch im Wagen?* Eine Hand, im Gehen, mit Daumen.

**Aufbau von oben nach unten** (Vollbild-Cover, Hintergrund `bgPlain`, randlos, keine Tab-Bar):
1. **Obere Zeile:** links Glas-Knopf `chevron.down` ("Einkauf unterbrechen"). Rechts nichts (Glas-Budget, 0.5).
2. **Kopf:** großer Titel = Markt der Liste "Lidl" (`largeTitle`), sonst der Listenname; rechts in derselben Grundlinie "0 von 11" in `numberXL` (`RollingNumber`, Live-Region). Darunter, nur wenn der Titel ein Markt ist: "Wocheneinkauf" (`subheadline`, `labelSecondary`). Darunter die **Fortschrittslinie**: Kapsel 4 pt hoch, volle Breite minus Ränder, Spur `fill`, Wert in `label` (nicht grün, K-09), folgt der Zahl mit `springDigits`.
3. **Präsenz-Zeile** (nur bei weiteren Einkäufern): "Lena kauft auch gerade ein" mit Avatar und Punkt.
4. **`StatusRow`** offline bzw. ausstehend (1.6).
5. **Tipp-Zeile** beim ersten Start (5.1).
6. **Gänge** (`AisleSection`, Variante Einkaufsmodus): Titel haftet oben auf `bgPlain` mit Scroll-Edge-Verlauf, `headline` plus Anzahl offen ("Obst & Gemüse 3"); Zeilen `ItemRow` Variante Einkaufsmodus: Kreis 36 pt in 56-pt-Ziel, Artikelbild 36 pt (Slot B), Name 22 pt Semibold (wächst wie Title 2), Unterzeile (`subheadline`): Notiz und "von Lena", rechts Menge in `numberL` ("2", "500 g"), darunter das gelbe Schild (Slot B). Ganze Zeile hakt ab. Trennlinien ab Textkante. Reihenfolge der Gänge nach "Reihenfolge im Markt" für den Markt der Liste.
7. **"Im Wagen (n)"** (`InsetSection` plain, einklappbar, standardmäßig eingeklappt): abgehakte Zeilen durchgestrichen.
8. **Ende:** wenn alles abgehakt: Text "Alles im Wagen." (`title3`) mittig unter "Im Wagen".
9. **Bodenleiste** (eine Glasgruppe, Teil der Tab-Bar-View im Modus `shopping`): links Glas-Kreis `plus` ("Artikel hinzufügen"), Mitte getönte Kapsel `checkmark.circle` + "Einkauf beenden" (`headline`, `onAction`), rechts der Avo-Kreis an seiner üblichen Stelle. Höhe wie die Tab-Bar.
10. **Rückgängig-Hinweis** 8 pt über der Bodenleiste: "Abgehakt: Bananen · Widerrufen", 4 s (VoiceOver 10 s).

**Beispiel.** "Lidl", "Wocheneinkauf", "5 von 11", Linie zu 45 %. Präsenz "Lena kauft auch gerade ein". Gang "Milch & Käse 2": "Feta" (200 g, Schild 1,29 €), "Butter" (von Lena). Gang "Fleisch & Fisch 1": "Hähnchenbrust" (400 g, Schild 3,49 €). "Im Wagen (5)" eingeklappt. Hinweis "Abgehakt: Bananen · Widerrufen".

**Zustände.**

| Zustand | Darstellung |
|---|---|
| Lädt | nie sichtbar; der Modus öffnet aus dem lokalen Stand der Liste. |
| Leer (über Siri/Link ohne offene Artikel) | `EmptyState` ohne Maskottchen: "Nichts mehr offen." / "Füg etwas hinzu oder beende den Einkauf." Bodenleiste unverändert. |
| Alles im Wagen | Erfolgs-Haptik beim letzten Häkchen; "Alles im Wagen."; "Einkauf beenden" bleibt die einzige Hauptaktion (kein automatisches Öffnen des Abschlusses). |
| Offline | `StatusRow` "Offline. Abhaken wird gespeichert und später gesendet."; Abhaken geht in die Warteschlange; Zeilen tragen das Sync-Zeichen; Präsenz pausiert und meldet sich beim Wiederverbinden neu. |
| Modul Angebote aus | keine Schilder, ohne Lücke. |
| Modul Avo aus | Avo-Kreis zeigt `magnifyingglass` (Suche), gleiche Form. |
| Pro | nie ein Pro-Hinweis im Einkaufsmodus (00 Kap. 16.5). |
| Liste wird von anderen gelöscht | Cover bleibt; `StatusRow` "„Wocheneinkauf“ wurde gelöscht. Dein Stand ist noch hier."; Abschluss weiterhin möglich (Verlauf lokal). |

**Interaktion, Bewegung, Haptik.**
- **Tippen irgendwo auf eine Zeile:** Kreis füllt sich (`springQuick`), leichter Impuls im selben Frame, "5 von 11" rollt auf "6 von 11", Linie folgt; Rückgängig-Hinweis erscheint; nach 0,6 s wandert die Zeile mit `springMove` nach "Im Wagen"; ist der Gang leer, klappt er mit `springStandard` zusammen und der nächste Titel rückt nach. Die Liste scrollt nie automatisch.
- **Reduce Motion (K-12):** Zeilen bleiben durchgestrichen stehen und wandern erst, wenn 1 s weder gescrollt noch getippt wurde, oder beim Beenden; Überblendung statt Bewegung; Zahl blendet über.
- **Widerrufen:** in der Leiste (letztes Häkchen) oder in "Im Wagen" nach rechts wischen ("Zurück auf die Liste", leichter Impuls an der Schwelle); die Zeile wächst an ihrem Platz wieder ein.
- **Langdruck:** Kontextmenü "Bearbeiten" (Artikel-Sheet), "Menge", "Kategorie", "Löschen". Kein Umsortieren im Laden.
- **Langdruck auf einen Gang-Titel:** Menü "Gang nach oben", "Gang nach unten", "Reihenfolge im Markt …" (öffnet 12.1 als Sheet). Die Änderung gilt sofort für diesen Markt; die Liste springt nicht, der Gang wandert mit `springStandard`.
- **Abgehakt von anderen:** Avatar 16 pt am Kreis für 2 s, dann Wanderung wie eigene; VoiceOver "Lena hat Butter abgehakt"; "6 von 11" rollt.
- **`plus`:** 5.3. **Avo-Kreis:** Tippen "Frag Avo" (Sheet mittel), Halten Sprachmodus ("Was fehlt für Lasagne?").
- **"Einkauf beenden":** öffnet das Abschluss-Sheet (6.1); keine Rückfrage.
- **`chevron.down`:** unterbricht (5.4).

**Große Schrift und 320 pt.**
- 320 pt: Titel und Zahl teilen sich die Zeile, solange beide passen; sonst steht "5 von 11" unter dem Titel (rechtsbündig bleibt nicht erzwungen). `numberXL` höchstens 51 pt.
- "Einkauf beenden" bis xxxL mit Text; ab AX1 Kurzbeschriftung "Beenden" (VoiceOver und Large Content Viewer: "Einkauf beenden"); unter 350 pt ab AX3 nur `checkmark.circle` in der getönten Kapsel (E-08).
- Ab AX1: Menge und Schild unter dem Namen, Bild entfällt, Kreis oben bündig. Name bricht um, nie Ellipse.
- AX5: Name 56 pt; eine Zeile kann 3 bis 4 Textzeilen hoch werden; der Abhak-Bereich ist die ganze Zeile, das bleibt bedienbar.

**Was sich ändert.** Den Modus gibt es heute nicht. Neu: `screens/lists/shopping_mode_screen.dart` (A), Route `/lists/:id/shopping`, Tab-Bar-Modus `shopping` (00 Kap. 12.1), `list_presence_service.dart`, Wakelock. "Im Wagen" ist dieselbe Datenlage wie "Erledigt" (`is_checked`).

**Bildbeschreibung für ChatGPT.**
iPhone-Vollbild im Hellmodus, reinweißer Hintergrund #FFFFFF ohne Karten, Zeilen über die volle Breite. Oben links ein runder Liquid-Glass-Knopf mit Pfeil nach unten. Darunter der große fette Titel "Lidl" in Schwarz #000000, rechts auf derselben Höhe groß und abgerundet "5 von 11"; darunter klein in Grau #636366 "Wocheneinkauf" und eine dünne schwarze Fortschrittslinie auf hellgrauer Spur #E9E9EE, knapp zur Hälfte gefüllt. Eine Zeile mit kleinem Avatar und grünem Punkt #3F7A1F: "Lena kauft auch gerade ein". Ein haftender Abschnittstitel "Milch & Käse 2" in 17 pt halbfett, darunter zwei hohe Zeilen mit großen leeren Kreis-Ringen 36 pt in Grau #8A8A8E und großen halbfetten Namen 22 pt "Feta" (rechts "200 g" und ein gelbes Schild #FFD60A "1,29 €") und "Butter" (graue Unterzeile "von Lena"); dann "Fleisch & Fisch 1" mit "Hähnchenbrust" (rechts "400 g", Schild "3,49 €"). Unten eine eingeklappte Zeile "Im Wagen (5)" mit kleinem Pfeil. Ganz unten schwebt eine Liquid-Glass-Leiste: links ein runder Glas-Knopf mit Plus, in der Mitte eine grün getönte Glas-Kapsel #3F7A1F mit weißem Häkchen-Kreis und "Einkauf beenden", rechts der runde Avo-Kreis mit braunem Kern #7A4A24 und hellgrünem Ring #C9DE6E; knapp darüber eine kleine Glas-Kapsel "Abgehakt: Bananen · Widerrufen" mit "Widerrufen" in Grün.

**Variante dunkel (zweites Bild).** Gleicher Aufbau auf Schwarz #000000, Text Weiß #FFFFFF, Unterzeilen #98989F, leere Kreise #7C7C80, Fortschrittslinie weiß auf #2C2C2E, getönte Kapsel #A6D45F mit dunkler Schrift #0E1A06, gelbe Schilder unverändert #FFD60A.

### 5.3 Nachtragen im Laden ("+")

**Aufbau.** Tippen auf `plus` morpht den Knopf (`springMorph`) zu einem Glas-Feld auf der Tastatur (Variante kompakt des `AddItemAccessory`: ohne `text.viewfinder`, ohne "Einkaufen"), darüber das Vorschlags-Panel wie 2.2 (Verlauf, Angebote des Markts). Return fügt hinzu; der Artikel wächst in seinem Gang ein (ein schon zusammengeklappter Gang öffnet sich wieder); "0 von 11" wird "5 von 12". Wischen nach unten oder Tippen in die Liste schließt das Feld, es morpht zurück zum `plus`.

**Bildbeschreibung für ChatGPT.**
Einkaufsmodus wie oben (weißer Grund, große Zeilen), aber unten ist die Systemtastatur offen; direkt darauf eine Liquid-Glass-Kapsel mit grauem Plus und dem getippten Wort "Backpapier". Darüber ein weißes Panel mit 20 pt Ecken und weichem Schatten mit zwei Zeilen: grüner Plus-Kreis #3F7A1F "Backpapier" mit Unterzeile "Menge 1 · Haushalt & Drogerie" und eine Zeile mit Uhr-Symbol "Backpapier, Zuschnitte" mit Unterzeile "zuletzt am 3. Okt.". Oben bleibt "Lidl" mit "5 von 11" sichtbar.

### 5.4 Unterbrechen und Fortsetzen

- `chevron.down`: Cover schließt mit dem umgekehrten Morph; die Liste zeigt den Stand (abgehakte in "Erledigt"); kein Dialog (00 Kap. 12.34). Präsenz bleibt 5 Minuten bestehen (man könnte zurückkehren) und endet dann.
- Wechsel in den Hintergrund: Wakelock endet; Präsenz endet nach 5 Minuten.
- Erneutes Öffnen: "Einkaufen" setzt beim gleichen Stand fort.
- Mitglied startet parallel: beide sind im Modus, beide sehen "… kauft auch gerade ein".

---

## 6. Einkauf beenden

### 6.1 Abschluss-Sheet (Inhalt Teil B, Slot `showCheckoutFlow(context, listId)`)

**Zweck.** *Wo war ich, und was kommt in den Verlauf?* Einstieg: "Einkauf beenden" (Einkaufsmodus), "Einkauf abschließen" im Menü "Mehr", "Abschließen" im Kopf von "Erledigt", prominente Aktion im Zustand "Alles erledigt". Ohne abgehakte Artikel ist der Einstieg ausgeblendet (statt heute: Alert "Bitte wähle …").

**Aufbau** (`AppSheet` mittel, Kopf `xmark` links, Titel "Einkauf beenden", `checkmark` rechts getönt = Speichern):
1. Zusammenfassung (`body`): "11 Artikel im Wagen", darunter (`subheadline`, `labelSecondary`) "3 bleiben auf der Liste" (nur wenn zutreffend).
2. Sektion "Wo warst du?": Markt-Chips (`StoreChip`, Auswahl, `Wrap`), vorausgewählt in dieser Reihenfolge: Markt der Liste, gelernter Markt, Märkte am Standort (nur mit Erlaubnis und eingeschalteter Markt-Erkennung, frische Koordinaten, 250 m Umkreis); dazu "Anderer Markt" (Suchfeld über das Ketten-Verzeichnis). Sektionsfuß ohne Standort: "Ohne Standort schlagen wir den Markt deiner Liste vor."
3. Sektion: Feld "Betrag (optional)" in `number`, Platzhalter "0,00 €".
4. Sektion (nur Modul Kosten teilen und geteilte Liste): `ToggleRow` "Kosten teilen" mit Unterzeile "Mit Lena".
5. Zeile (nur Modul Angebote, echte PLZ): `tag` "ca. 3,20 € durch Angebote gespart, laut Händler".

**Beispiel.** "11 Artikel im Wagen" · Wo warst du? [Lidl ✓] [Aldi Süd] [REWE] [Anderer Markt] · Betrag leer · Kosten teilen aus · "ca. 3,20 € durch Angebote gespart, laut Händler".

**Zustände.** Offline: Speichern geht in die Warteschlange (Verlauf und Entfernen der Artikel in einem atomaren Schritt beim Senden, E-09); Märkte am Standort entfallen. Fehler beim Speichern: `StatusRow` im Sheet "Das hat nicht geklappt. Erneut versuchen", Fehler-Haptik, nichts doppelt.

**Interaktion (Rahmen Teil A).** Speichern schließt das Sheet; **danach** der `SuccessMoment` (00 Kap. 12.35) mit feierndem Maskottchen 120 pt, "Einkauf gespeichert." und Unterzeile "11 Artikel · ca. 3,20 € durch Angebote gespart, laut Händler" (Ersparnis nur mit Modul), Erfolgs-Haptik im selben Frame, 1,5 s, Tippen schließt. Dann endet der Einkaufsmodus (umgekehrter Morph), die Liste zeigt nur noch Offenes, Rückgängig-Hinweis "Einkauf gespeichert · Widerrufen" (4 s; stellt Artikel, Häkchen und Verlauf wieder her). War "Kosten teilen" an, öffnet danach das Sheet Kosten teilen (B). Mitglieder erhalten "Jannis hat bei Lidl eingekauft (11 Artikel)" (B). Der gewählte Markt wird als Ketten-ID gespeichert und gelernt (11.3). Nach dem dritten Abschluss höchstens einmal der Systemdialog zur Bewertung (nicht im Einkaufsmodus, also nach dessen Ende). Nach dem ersten Abschluss: Pro-Hinweis-Zeile (Kapitel 10, 00 Kap. 16.4).

**AX und 320 pt.** Chips brechen um; Sheet ab AX3 groß.

**Was sich ändert.** Entfallen: Bestätigungs-Alert vor dem Abschluss, stilles GPS mit bis zu 30 s Wartezeit, grüner Snackbar mit Emoji. `shopping_trip_completion.dart` wird zum dünnen Aufrufer (A) von `showCheckoutFlow` (B); `checkout_store_sheet.dart` geht im Abschluss-Sheet auf (B).

**Bildbeschreibung für ChatGPT.**
Ein schwebendes iOS-Sheet in halber Höhe mit Liquid-Glass-Rand über dem Einkaufsmodus. Kopf: links runder Glas-Knopf mit X, mittig "Einkauf beenden", rechts runder grün getönter Glas-Knopf #3F7A1F mit weißem Häkchen. Darunter in Schwarz "11 Artikel im Wagen". Sektion "Wo warst du?" mit Kapseln: "Lidl" mit blauem Punkt #0050AA, hellgrün hinterlegt #EEF5E4 und grünem Häkchen, daneben graue Kapseln #E9E9EE "Aldi Süd" (dunkelblauer Punkt #00005F), "REWE" (roter Punkt #CC071E) und "Anderer Markt". Darunter eine weiße Zeile "Betrag (optional)" mit grauem "0,00 €" rechts. Unten eine Zeile mit grauem Preisschild-Symbol und dem Text "ca. 3,20 € durch Angebote gespart, laut Händler" in Schwarz.

### 6.2 Erfolgsmoment

**Bildbeschreibung für ChatGPT.**
Die Einkaufsliste im Hintergrund, leicht abgedunkelt. In der Mitte ein flach gezeichnetes Avocado-Maskottchen in zwei Grüntönen mit braunem Kern, kurzen Ärmchen in die Luft gestreckt, etwa 120 pt groß. Darunter "Einkauf gespeichert." in 22 pt fett Schwarz und darunter in Grau #636366 "11 Artikel · ca. 3,20 € durch Angebote gespart, laut Händler". Keine Konfetti, keine Emojis, kein Rahmen.

---

## 7. Alle Listen

**Zweck.** *Welche Listen habe ich, und was ist erledigt?* Einstieg: Titelmenü > "Alle Listen", `/lists`, `shoply://lists`, "Zu deinen Listen" aus Fehlerzuständen.

**Aufbau** (Push im Tab Liste, `bgGrouped`, großer Titel "Alle Listen", Zurück "Wocheneinkauf"):
1. Toolbar rechts: `plus` (Menü: "Neue Liste", "Liste beitreten").
2. `SearchField` (erst ab 7 Listen).
3. Sektion "Meine Listen": `ListRow`s (Glyph 28, Name, Unterzeile "11 offen · Lidl", rechts Avatar-Stapel bei geteilten, `chevron.right`). Angeheftete oben mit `pin`; danach nach "zuletzt geändert", aber nur beim Öffnen der Seite sortiert (nie live springend).
4. Sektion "Geteilt mit mir": `ListRow`s mit Ersteller in der Unterzeile ("6 offen · von Tom").
5. Sektion "Sparen" (nur Modul Angebote, Slot B): "Angebote der Woche" mit "12 passen zu deinen Listen".
6. Sektion "Verlauf": "Einkäufe" mit "November · 6 Einkäufe" (B), "Offene Beträge" mit Summe (nur Modul Kosten teilen, B).

**Beispiel.** Meine Listen: Wocheneinkauf (11 offen · Lidl · Lena), Party Samstag (14 offen · Lena, Max), REWE (4 offen · REWE), Drogerie (3 offen). Geteilt mit mir: WG-Vorrat (6 offen · von Tom · Ungelesen-Punkt; Unterzeile wechselt bei Präsenz zu "Tom kauft gerade ein").

**Zustände.** Lädt: aus dem lokalen Stand. Keine Listen: `EmptyState` "Noch keine Listen." / prominent "Neue Liste" / schlicht "Liste beitreten". Nur geteilte: Sektion "Meine Listen" entfällt. Offline: `StatusRow`; "Liste beitreten" deaktiviert. Fehler: Inhalt bleibt, `StatusRow`.

**Interaktion.** Tippen wählt die Liste und kehrt zur Wurzel zurück (Pop mit Überblendung des Inhalts). Wischen nach links: "Teilen" (`fill`) und "Löschen" bzw. "Verlassen" (`danger`, öffnet die Bestätigung 10.4). Kontextmenü: "Anheften" (= Beim Start zeigen, genau eine Liste, E-10), "Umbenennen" (öffnet Listen-Info mit fokussiertem Namen), "Teilen", "Farbe und Symbol", "Löschen"/"Verlassen". Nach Löschen: Zeile fällt zusammen, kein Rückgängig (endgültig, bestätigt).

**AX und 320 pt.** Ab AX1 plain; Avatar-Stapel rutscht unter die Unterzeile; Glyph bleibt 28 pt bis AX2, dann 36.

**Was sich ändert.** Ersetzt den Abschnitt "DEINE LISTEN" der Startseite (nummerierte Serifen-Zeilen "01, 02", Fortschrittslinien, 140-pt-Boxen, Löschen per verstecktem Langdruck, Beitreten per Langdruck auf "+ Neue Liste"). Neue Datei `screens/lists/all_lists_screen.dart`; `home_screen.dart:341-480`, `584-805`, `852-950` entfallen.

**Bildbeschreibung für ChatGPT.**
iOS-Screen "Alle Listen" auf #F2F2F7, oben links ein runder Glas-Zurück-Knopf, oben rechts ein runder Glas-Knopf mit Plus, großer fetter Titel "Alle Listen". Sektion "Meine Listen" in einer weißen Fläche mit 26 pt Ecken: Zeilen mit runden Farbkreisen und weißen Symbolen, blau #007AFF Einkaufswagen "Wocheneinkauf" mit kleiner Stecknadel und grauer Unterzeile "11 offen · Lidl" und rechts einem kleinen Avatar, orange #FF9500 Konfetti "Party Samstag" ("14 offen") mit zwei überlappenden Avataren, rot #FF3B30 Korb "REWE" ("4 offen · REWE"), lila #AF52DE Tasche "Drogerie" ("3 offen"), jeweils mit grauem Chevron rechts. Sektion "Geteilt mit mir": grün #34C759 Haus "WG-Vorrat" mit kleinem grünem Punkt #3F7A1F und Unterzeile "6 offen · von Tom". Sektion "Sparen": Zeile "Angebote der Woche" mit "12 passen zu deinen Listen". Sektion "Verlauf": "Einkäufe" mit "November · 6 Einkäufe". Unten die Glas-Tab-Bar, kein Eingabefeld.

---

## 8. Neue Liste

**Zweck.** *Wie heißt die Liste, und für welchen Markt?* Einstieg: Titelmenü, Alle Listen `plus`, `/lists/new`, `shoply://create-list?name=` (legt direkt an, ohne Sheet), Avo.

**Aufbau** (`AppSheet` mittel; `xmark` links, "Neue Liste", `checkmark` getönt rechts, aktiv sobald ein Name da ist):
1. Listen-Glyph 64 pt mittig (Farbe und Symbol live), darunter Namensfeld (`title2` Bold, zentriert, Kapsel `fill`, Platzhalter "Name der Liste", Autofokus).
2. Zeile `StoreChip` (Slot B) "Markt wählen" mit `storefront`; erkennt der Name eine Kette ("Lidl", "REWE Wocheneinkauf", "aldi süd", auch mit Tippfehler), zeigt der Chip sie sofort gesetzt ("Lidl"), sichtbar und vor dem Speichern änderbar.
3. Sektion "Farbe": 11 Farbkreise 30 pt sichtbar, 44 pt Ziel, `Wrap`; gewählter mit Ring 2 pt in `label` und 2 pt Abstand. Vorausgewählt: nächste unbenutzte Farbe (00 Kap. 4.3).
4. Sektion "Symbol": 20 Symbole (00 Kap. 4.3) als Raster 44 pt, gewähltes auf `fill`-Kreis.

**Beispiel.** Name "Lidl" → Chip "Lidl" gesetzt, Farbe Indigo (nächste freie), Symbol `cart`.

**Zustände.** Offline: Anlegen lokal mit Geräte-ID, erscheint sofort im Titelmenü mit Sync-Zeichen. Name doppelt: erlaubt. Leerer Name: `checkmark` deaktiviert.

**Interaktion.** `checkmark` legt an (optimistisch, eine atomare Server-Operation statt zwei Inserts), schließt das Sheet, wechselt zur neuen Liste und fokussiert das Accessory. Return im Namensfeld = `checkmark`. Keine Haptik.

**AX und 320 pt.** Farben 6 pro Zeile bei 320 pt; Symbol-Raster 5 Spalten bei 320 pt, ab AX3 Raster eingeklappt hinter `NavRow` "Symbol"; Glyph 64 pt fest.

**Was sich ändert.** Ersetzt den Eingabe-Alert "Neue Liste erstellen" (`home_screen.dart:584-660`). Neu: Farbe, Symbol, Markt beim Anlegen. Datei `screens/lists/new_list_sheet.dart`.

**Bildbeschreibung für ChatGPT.**
Schwebendes iOS-Sheet in halber Höhe mit Glasrand. Kopf: X links, "Neue Liste" mittig, grün getönter Häkchen-Knopf #3F7A1F rechts. Mittig ein großer indigofarbener Kreis #5856D6 mit weißem Einkaufswagen, darunter ein graues Kapselfeld #E9E9EE mit dem Text "Lidl" in 22 pt fett. Darunter eine graue Kapsel mit blauem Punkt #0050AA und "Lidl". Dann eine weiße Sektion mit elf Farbkreisen in zwei Reihen (Blau, Rot, Orange, Gelb, Grün, Minze, Indigo mit schwarzem Ring, Lila, Rosa, Braun, Graphit) und darunter ein Raster grauer Symbole (Wagen, Korb, Tasche, Haus, Gebäude, Personen, Besteck, Karotte, Blatt, Torte, Geschenk, Konfetti, Pfote, Koffer, Tropfen, Flamme, Sonne, Mond, Stern, Herz), der Wagen auf hellgrauem Kreis.

---

## 9. Teilen und Beitreten

### 9.1 Liste teilen

**Zweck.** *Wie bekommt jemand Zugriff?* Einstieg: Toolbar `person.crop.circle.badge.plus`, Avatar-Stapel in der Metazeile, Wischen in Alle Listen, `/lists/:id/share`.

**Aufbau** (`AppSheet` mittel; `xmark` links, "Liste teilen"):
1. Kopf-Zeile: Glyph 36 pt + "Wocheneinkauf" (`headline`).
2. Sektion "Mitglieder (2)": Zeilen mit Avatar 28, Name, Unterzeile "Ersteller" bzw. "Du" bzw. Präsenz "kauft gerade ein".
3. Prominent "Personen einladen" (`AppButton`, `square.and.arrow.up`) → System-Teilen mit Link und Text "Komm auf meine Liste „Wocheneinkauf“ in {app}." (ohne Emoji).
4. Schlicht "Code anzeigen" → 9.2.
5. Einmalig (Modul Kosten teilen aus): Hinweis-Zeile "Kosten teilen einschalten? Praktisch für gemeinsame Einkäufe" mit "Einschalten" (Kapitel 01 10.3).

**Zustände.** Beim allerersten Teilen vorher die Vorab-Erklärung Mitteilungen (9.3). Offline: "Personen einladen" teilt den gespeicherten Link (der Code existiert schon, L-05); gibt es noch keinen Code: Knopf deaktiviert, Unterzeile "Braucht eine Verbindung". Kein Warten vor dem Öffnen (heute Netzaufruf vor dem Dialog).

**Was sich ändert.** Ersetzt `share_list_dialog.dart` (Material-Dialog, neuer Code bei jedem Öffnen, Link ohne Beitritt, Emoji im Text, Überlauf bei 320 pt). Neue Datei `screens/lists/widgets/share_list_sheet.dart`.

**Bildbeschreibung für ChatGPT.**
Schwebendes iOS-Sheet in halber Höhe über der Liste. Kopf: X links, "Liste teilen" mittig. Darunter eine Zeile mit blauem Kreis #007AFF mit Einkaufswagen und "Wocheneinkauf" halbfett. Weiße Sektion "Mitglieder (2)" mit zwei Zeilen: runder Avatar eines Mannes "Jannis" mit Unterzeile "Du · Ersteller", runder Avatar einer Frau "Lena". Darunter eine breite grüne Kapsel #3F7A1F mit weißem Teilen-Symbol und "Personen einladen", darunter grüner Text ohne Fläche "Code anzeigen". Hintergrund des Sheets #F2F2F7.

### 9.2 Code anzeigen

**Aufbau.** Unter "Code anzeigen" klappt eine Sektion auf (`springStandard`): Code "482 913" in `numberXL`, tabellarisch, in zwei Dreiergruppen; Unterzeile "Tippen zum Kopieren"; Sektionsfuß "Der Code bleibt gültig, bis du einen neuen erzeugst."; schlicht "Neuen Code erzeugen" (nur Ersteller, LF-03). Tippen auf den Code kopiert; Status-Hinweis "Code kopiert".

**L-05 Code stabil.** Ein Code wird einmal erzeugt und bleibt, bis jemand ausdrücklich "Neuen Code erzeugen" wählt (behebt "Teilen macht alte Codes ungültig"). Server prüft Kollisionen. Der Einladungslink trägt den Code (E-11), damit ein neuer Code auch alte Links ungültig macht.

**AX und 320 pt.** Code bricht nach der Dreiergruppe um; nie Laufweite 6 wie heute.

**Bildbeschreibung für ChatGPT.**
Das Sheet "Liste teilen" wie oben, aber unter "Code anzeigen" ist eine weiße Sektion aufgeklappt. Darin groß und abgerundet in Schwarz die Ziffern "482 913" mit tabellarischen Ziffern, darunter grau #636366 "Tippen zum Kopieren". Unter der Sektion klein in Grau "Der Code bleibt gültig, bis du einen neuen erzeugst." und grüner Text #3F7A1F "Neuen Code erzeugen". Darüber eine kleine Glas-Kapsel "Code kopiert".

### 9.3 Vorab-Erklärung Mitteilungen (einmal beim ersten Teilen)

**Aufbau** (Sheet mittel): `bell` 48 pt Light, "Erfahre, wenn jemand etwas hinzufügt oder einkauft" (`title3`), "Du bekommst eine Mitteilung pro Einkauf, nicht pro Häkchen." (`body`), prominent "Mitteilungen erlauben" (danach Systemabfrage), schlicht "Nicht jetzt". Danach geht es mit 9.1 weiter. "Nicht jetzt" fragt bei diesem Gerät nicht wieder beim Teilen; die Zeile in Einstellungen > Mitteilungen bleibt.

**Bildbeschreibung für ChatGPT.**
Schwebendes iOS-Sheet in halber Höhe auf #F2F2F7. Mittig ein dünn gezeichnetes Glocken-Symbol in Grau #636366, 48 pt, ohne Kreis dahinter. Darunter "Erfahre, wenn jemand etwas hinzufügt oder einkauft" in 20 pt halbfett Schwarz, zweizeilig zentriert, darunter "Du bekommst eine Mitteilung pro Einkauf, nicht pro Häkchen." in 17 pt Schwarz. Unten eine breite grüne Kapsel #3F7A1F "Mitteilungen erlauben" und darunter grüner Text "Nicht jetzt".

### 9.4 Liste beitreten (per Code)

**Zweck.** *Wie komme ich auf eine fremde Liste?* Einstieg: Titelmenü und Alle Listen > "Liste beitreten", `/lists/join?code=`.

**Aufbau** (Sheet mittel; `xmark`, "Liste beitreten"): Satz "Gib den 6-stelligen Code ein, den du bekommen hast." (`body`); Code-Feld zentriert in `numberXL`, Ziffern-Tastatur, Einfügen erlaubt (Leerzeichen werden ignoriert). Nach der 6. Ziffer Vorschau-Zeile: Glyph, "„WG-Vorrat“", Unterzeile "von Tom · 6 Artikel · 2 Mitglieder"; darunter prominent "Beitreten".

**Zustände.** Prüfen läuft: kleiner Indikator im Feld, kein Vollbild. Falscher Code (keine Schüttel-Animation): Zeile `exclamationmark.circle` `danger` "Keine Liste mit diesem Code gefunden. Prüfe die Ziffern." und Fehler-Haptik. Schon Mitglied: "Du bist schon auf dieser Liste." mit "Öffnen". Offline: "Beitreten braucht eine Verbindung." Zu viele Versuche: "Zu viele Versuche. Versuch es in einer Minute wieder." (Server-Drossel gegen Raten).

**Interaktion.** "Beitreten" schließt das Sheet, die Liste wird die Liste von heute (Überblendung), Rückgängig-Hinweis als Status "Du bist jetzt auf „WG-Vorrat“."

**AX und 320 pt.** Code-Feld in `numberXL` (höchstens 51 pt) passt mit 6 Ziffern auf 288 pt; Vorschau-Zeile bricht um; Sheet ab AX3 groß.

**Bildbeschreibung für ChatGPT.**
Schwebendes iOS-Sheet in halber Höhe über der Systemtastatur mit Zifferntasten. Kopf: X links, "Liste beitreten" mittig. Darunter in Schwarz "Gib den 6-stelligen Code ein, den du bekommen hast." und ein graues Kapselfeld #E9E9EE mit groß und abgerundet "715 204". Darunter eine weiße Zeile mit grünem Kreis #34C759 mit weißem Haus, "„WG-Vorrat“" und grauer Unterzeile "von Tom · 6 Artikel · 2 Mitglieder" #636366. Darunter eine breite grüne Kapsel #3F7A1F mit weißem "Beitreten".

### 9.5 Beitritts-Sheet (per Link)

**Zweck.** Empfänger eines Links tritt mit einem Tipp bei (behebt "Link lässt niemanden beitreten").

**Aufbau** (Sheet mittel, ohne Kopf-Titel): Glyph 64 pt, "„Wocheneinkauf“ beitreten?" (`title2`), "Von Jannis · 12 Artikel · 2 Mitglieder" (`subheadline`, `labelSecondary`), prominent "Beitreten", schlicht "Abbrechen".

**Zustände.** Abgemeldet: Onboarding bzw. Anmelden, Link gemerkt, danach dieses Sheet. Schon Mitglied: kein Sheet, die Liste öffnet. Link ungültig (neuer Code erzeugt, Liste gelöscht): "Diese Einladung gilt nicht mehr. Bitte um einen neuen Link." mit "OK". Offline: "Beitreten braucht eine Verbindung." mit "Erneut versuchen".

**Was sich ändert (9.4, 9.5).** Ersetzt den Code-Alert per Langdruck (`home_screen.dart:663-805`). Neu: Vorschau vor dem Beitritt, Beitritt per Link. Server: sichere Vorschau- und Beitritts-Funktionen (E-11). Neue Dateien `join_list_sheet.dart`, Routen `/join/:code`, `/invite/:id`, `/lists/join`.

**Bildbeschreibung für ChatGPT (9.5).**
Schwebendes iOS-Sheet in halber Höhe über einer unscharfen App. Mittig ein großer blauer Kreis #007AFF mit weißem Einkaufswagen, darunter in 22 pt fett "„Wocheneinkauf“ beitreten?", darunter in Grau #636366 "Von Jannis · 12 Artikel · 2 Mitglieder". Unten eine breite grüne Kapsel #3F7A1F mit weißem "Beitreten" und darunter grüner Text "Abbrechen". Hintergrund des Sheets #F2F2F7, Glasrand.

---

## 10. Listen-Info

### 10.1 Sheet

**Zweck.** *Wie ist diese Liste eingerichtet, und wer ist dabei?* Ersetzt Listeneinstellungen, Umbenennen und den Aktivitäten-Screen. Einstieg: Menü "Mehr" > "Listen-Info", Kontextmenü in Alle Listen, `/lists/:id/info`, `/lists/:id/activities` (scrollt zu "Zuletzt geändert"), Mitteilung `list_member_joined` (scrollt zu Mitglieder).

**Aufbau** (`AppSheet` groß; `xmark` links, Inline-Titel "Listen-Info"; Änderungen wirken sofort, deshalb kein `checkmark`):
1. **Kopf:** Glyph 64 pt, darunter der Name als Feld (`title2` Bold, zentriert, Kapsel `fill`); Return oder Verlassen des Felds speichert (optimistisch); darunter "Erstellt von Jannis · seit 12. Okt." (`subheadline`, `labelSecondary`).
2. **Sektion "Farbe und Symbol":** Farbkreise wie 8 (inline); `NavRow` "Symbol" mit dem aktuellen Symbol rechts → 10.2.
3. **Sektion "Markt"** (Slot B für Chip und Erkennung): Zeile `StoreChip` "Lidl" mit Unterzeile zur Quelle ("Von dir festgelegt" / "Aus dem Listennamen" / "Vorschlag aus 2 Einkäufen"); `NavRow` "Reihenfolge im Markt" → 12.1; `ToggleRow` "Angebote in dieser Liste" (Slot B, nur Modul an; aus = `setOffersHiddenForList`).
4. **Sektion "Mitglieder (2)":** Mitglieder-Zeilen (Avatar 28, Name, Unterzeile "Du", "Ersteller", "kauft gerade ein", "beigetreten am 14. Okt."); letzte Zeile "Personen einladen" in `action` mit `person.crop.circle.badge.plus` → 9.1. Ersteller: Wischen nach links "Entfernen" bzw. Kontextmenü "Entfernen" an fremden Mitgliedern (Bestätigung 10.4).
5. **Sektion "Start":** `ToggleRow` "Beim Start zeigen" mit Fuß "Diese Liste erscheint beim Öffnen der App."
6. **Sektion "Mitteilungen"** (Dienst Teil B): `ToggleRow` "Mitteilungen für diese Liste" mit Unterzeile "Wenn jemand einkauft oder viel ändert" (nur geteilte Listen).
7. **Sektion "Zuletzt geändert":** bis 5 Zeilen (10.3), schlicht "Alle anzeigen" im Sektionstitel rechts.
8. **Sektion (destruktiv):** "Liste löschen" (Ersteller) bzw. "Liste verlassen" (Mitglied), Text `danger`, Sektionsfuß beim Löschen "Die Liste wird für alle Mitglieder gelöscht."

**Beispiel.** Wocheneinkauf, Blau, `cart`; Markt Lidl "Von dir festgelegt"; Angebote an; Mitglieder Jannis (Du, Ersteller), Lena (beigetreten am 14. Okt.); Beim Start zeigen an; Zuletzt geändert: "Lena hat Butter hinzugefügt · vor 12 Min", "Lena hat Joghurt abgehakt · vor 40 Min", "Du hast Mineralwasser hinzugefügt · 9:15", "Lena ist beigetreten · 14. Okt.".

**Zustände.** Lädt: aus dem lokalen Stand (Mitglieder und Änderungen gecacht), kein Vollbild-Spinner. Mitglieder-Abfrage scheitert: Sektion zeigt den letzten Stand plus `StatusRow` "Mitglieder konnten nicht aktualisiert werden. Erneut versuchen" (heute still leer). Offline: Name, Farbe, Symbol, Schalter lokal mit Warteschlange; Entfernen, Verlassen, Löschen deaktiviert mit Unterzeile "Braucht eine Verbindung". Nicht geteilte Liste: Mitglieder-Sektion zeigt nur "Du" und "Personen einladen"; Mitteilungen-Sektion entfällt.

**Interaktion.** Name bearbeiten: kein Dialog, Titel der Liste ändert sich live. Farbe tippen: Glyph wechselt mit `springQuick`, keine Haptik. Sheet stapelt höchstens einen Push (10.2, 10.3, 12.1).

**AX und 320 pt.** Ab AX1 plain; Farbkreise 6 pro Zeile bei 320 pt; Name bricht im Feld um (mehrzeilig, keine feste Höhe).

**Was sich ändert.** Ersetzt `list_settings_screen.dart` (Paper-App-Bar, Kicker "MITGLIEDER"/"AKTIONEN", Minus-Kreis 20 pt, Mitglied öffnet Autorenseite, Vollbild-Spinner, `MaterialPageRoute` ohne Route), den Umbenennen-Dialog (`list_detail_parts.dart:11-60`) und `list_activities_screen.dart` (K-33). Neue Datei `screens/lists/list_info_sheet.dart`.

**Bildbeschreibung für ChatGPT.**
Großes iOS-Sheet über die ganze Höhe auf #F2F2F7 mit runden oberen Ecken, oben links ein runder Glas-Knopf mit X, mittig "Listen-Info". Darunter ein großer blauer Kreis #007AFF mit weißem Einkaufswagen und darunter ein graues Kapselfeld #E9E9EE mit "Wocheneinkauf" in 22 pt fett, darunter grau #636366 "Erstellt von Jannis · seit 12. Okt.". Weiße Sektionen mit 26 pt Ecken: eine Reihe Farbkreise (Blau mit schwarzem Ring) und eine Zeile "Symbol" mit Wagen-Symbol und Chevron; Sektion "Markt" mit einer grauen Kapsel "Lidl" mit blauem Punkt #0050AA und Unterzeile "Von dir festgelegt", Zeile "Reihenfolge im Markt ›", Zeile "Angebote in dieser Liste" mit grünem Schalter #3F7A1F; Sektion "Mitglieder (2)" mit zwei Avatar-Zeilen "Jannis" ("Du · Ersteller") und "Lena" ("beigetreten am 14. Okt.") und einer grünen Zeile "Personen einladen". Weiter unten angeschnitten "Zuletzt geändert" mit "Lena hat Butter hinzugefügt" und rechts "vor 12 Min".

### 10.2 Symbol wählen (Push im Sheet)

Inline-Titel "Symbol", Zurück "Listen-Info". Glyph 64 pt oben, darunter das Raster der 20 Symbole (44 pt, Auswahl auf `fill`-Kreis). Tippen wählt und bleibt auf der Seite (Glyph wechselt mit `springQuick`, keine Haptik), Zurück kehrt zurück. Raster bei 320 pt 5 Spalten, ab AX3 4. Offline: lokal mit Warteschlange. VoiceOver: jedes Symbol mit Namen ("Einkaufswagen, ausgewählt").

**Bildbeschreibung für ChatGPT.**
iOS-Seite in einem großen Sheet auf #F2F2F7, oben links Glas-Zurück-Knopf, mittig "Symbol". Oben mittig ein großer blauer Kreis #007AFF mit weißem Einkaufswagen. Darunter eine weiße Sektion mit einem Raster aus 20 grauen Symbolen in vier Reihen (Wagen, Korb, Tasche, Haus, Gebäude, zwei Personen, Besteck, Karotte, Blatt, Torte, Geschenk, Konfetti, Pfote, Koffer, Tropfen, Flamme, Sonne, Mond, Stern, Herz); der Wagen liegt auf einem hellgrauen Kreis #E9E9EE.

### 10.3 Zuletzt geändert und "Alle Änderungen"

**Zweck.** *Was haben andere hier gemacht?* Ersetzt den toten Aktivitäten-Screen mit echten Daten (K-33).

**Zeile.** Avatar 20 pt, Text (`body`, `label`) "Lena hat Butter hinzugefügt", rechts Zeit (`caption1`, `labelSecondary`) "vor 12 Min", "9:15", "Gestern", "14. Okt.". Gebündelt: "Lena hat 5 Artikel abgehakt" (aufeinanderfolgende gleiche Ereignisse einer Person innerhalb 10 Minuten). Keine Emojis, keine farbigen Quadrate, kein Glas.

**Ereignisse:** Artikel hinzugefügt, abgehakt, gelöscht; Liste umbenannt; Markt geändert; Mitglied beigetreten, verlassen, entfernt; Einkauf abgeschlossen ("Jannis hat bei Lidl eingekauft · 11 Artikel", tippbar → Verlauf, B); Einkauf begonnen wird nicht protokolliert (nur Präsenz).

**"Alle Änderungen" (Push im Sheet):** Sektionen nach Tag ("Heute", "Gestern", "Mo., 2. Nov."), 30 Tage zurück. Kein "Verlauf löschen" (geteilte Daten; Aufräumen macht der Server nach 30 Tagen).

**Zustände.** Leer: "Noch keine Änderungen." (Satz in der Sektion). Offline: letzter Stand.

**Daten.** Serverseitig aus einer Tabelle `list_events`, geschrieben von Datenbank-Triggern, lesbar für Mitglieder (E-12). `ListActivityService` (lokal, nie aufgerufen) entfällt.

**AX und 320 pt.** Zeit rutscht ab AX1 unter den Text; Avatar wächst bis AX2.

**Bildbeschreibung für ChatGPT ("Alle Änderungen").**
iOS-Seite in einem großen Sheet auf #F2F2F7, oben links ein runder Glas-Zurück-Knopf, mittig "Alle Änderungen". Sektionstitel "Heute" in 17 pt halbfett Schwarz, darunter eine weiße Sektion mit 26 pt Ecken und Zeilen: kleiner runder Avatar 20 pt, Text in Schwarz "Lena hat Butter hinzugefügt" mit "vor 12 Min" rechts in Grau #636366, "Lena hat 2 Artikel abgehakt" mit "vor 40 Min", "Du hast Mineralwasser hinzugefügt" mit "9:15". Sektion "Gestern" mit "Jannis hat bei Lidl eingekauft · 11 Artikel" und Chevron. Sektion "Mi., 14. Okt." mit "Lena ist beigetreten". Keine Emojis, keine farbigen Kästchen, kein Glas auf den Zeilen.

### 10.4 Bestätigungen (nativer Alert, 00 Kap. 12.34)

| Aktion | Titel | Nachricht | Knöpfe |
|---|---|---|---|
| Liste löschen (Ersteller) | "„Wocheneinkauf“ löschen?" | "Die Liste und 11 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen." | "Abbrechen", rot "Löschen" |
| Liste verlassen | "„WG-Vorrat“ verlassen?" | "Du kannst nur mit einer neuen Einladung zurück." | "Abbrechen", rot "Verlassen" |
| Mitglied entfernen | "Lena entfernen?" | "Lena kann „Wocheneinkauf“ dann nicht mehr sehen." | "Abbrechen", rot "Entfernen" |
| Kategorie löschen | "„Getränkemarkt“ löschen?" | "3 Artikel kommen nach „Sonstiges“." | "Abbrechen", rot "Löschen" |

Nach Löschen oder Verlassen: Sheet schließt, die Liste von heute wechselt nach 01 Kap. 2.2 Regel 4 (Überblendung), Status-Hinweis "„Wocheneinkauf“ gelöscht.". Keine Haptik außer bei Fehler. Offline sind die vier Aktionen deaktiviert (Server muss bestätigen). Alerts sind nativ und folgen Dynamic Type und 320 pt selbst.

**Was sich ändert.** Heute fragen auch "Mitglied entfernen" und "Aktivitäten leeren" per `CupertinoAlertDialog` bzw. Material-`AlertDialog` (rote `TextButton`); "Aktivitäten leeren" entfällt; Texte nach Muster 00 Kap. 12.34.

**Bildbeschreibung für ChatGPT (Liste löschen).**
Ein nativer iOS-27-Alert mittig über dem abgedunkelten Listen-Info-Sheet, Liquid-Glass-Fläche mit großen runden Ecken. Titel in 17 pt halbfett "„Party Samstag“ löschen?", darunter in 13 pt "Die Liste und 14 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen." Zwei Kapsel-Knöpfe nebeneinander: links grau "Abbrechen", rechts mit roter Schrift #D70015 "Löschen". Keine Symbole, kein Maskottchen.

---

## 11. Markt pro Liste (Verbesserungsliste 6c)

### 11.1 Markt-Chip im Listenkopf (Slot B `StoreChip(listId:)`, Gestaltung 00 Kap. 12.10)

| Zustand | Aussehen | Tippen |
|---|---|---|
| gesetzt | Kapsel `fill`, Punkt in Markenfarbe, "Lidl", `chevron.down` 11 pt | Markt-Sheet (11.2) |
| vorgeschlagen | "Lidl?" mit gestricheltem Rand `controlOutline` | Menü aus dem Chip: "Ist das deine Lidl-Liste?" mit "Ja" / "Anderer Markt" / "Kein fester Markt" |
| kein Markt | `storefront` + "Markt wählen" in `labelSecondary` | Markt-Sheet |
| Modul Angebote aus | wie gesetzt; Markt dient Reihenfolge, Verlauf, Einkaufsmodus-Titel | Markt-Sheet |

Regeln (L-06): Der Chip steht nur in der Metazeile der Liste, in Listen-Info, Neue Liste und im Abschluss-Sheet. Er ist nie ein Logo (9.7 Fundament). Ein Vorschlag wird nie automatisch übernommen; abgelehnte Vorschläge kommen für diese Liste und diesen Markt nicht wieder.

### 11.2 Markt-Sheet (Inhalt Teil B)

**Zweck.** *Für welchen Markt ist diese Liste?*

**Aufbau** (Sheet mittel; `xmark`, "Markt", `checkmark` getönt):
1. `SearchField` "Markt suchen" (Ketten-Verzeichnis mit Aliasen, z. B. "aldi süd", "Rewe City").
2. Sektion "Vorschläge" (nur wenn vorhanden): "Lidl · aus 2 Einkäufen", "REWE · in deiner Nähe" (nur mit Standort-Erlaubnis und eingeschalteter Markt-Erkennung).
3. Sektion "Lieblingsmärkte" (aus Preise & Angebote, B).
4. Sektion "Alle Märkte": Zeilen mit Punkt in Markenfarbe und Name, alphabetisch.
5. Zeile "Kein fester Markt" mit Sektionsfuß "Dann zeigen wir Angebote aller Märkte in deiner Region." (mit Modul Angebote) bzw. "Die Reihenfolge im Markt gilt dann allgemein." (ohne).

**Beispiel.** Vorschläge: Lidl (aus 2 Einkäufen); Lieblingsmärkte: Lidl, REWE; Alle: Aldi Nord, Aldi Süd, Edeka, Kaufland, Lidl ✓, Netto, PENNY, REWE.

**Zustände.** Offline: Verzeichnis lokal, Vorschläge aus Standort entfallen. Standort aus: keine Nähe-Vorschläge, kein Hinweis (der Hinweis lebt in Preise & Angebote).

**Bildbeschreibung für ChatGPT.**
Schwebendes iOS-Sheet in halber Höhe. Kopf: X links, "Markt" mittig, grün getönter Häkchen-Knopf #3F7A1F rechts. Ein graues Suchfeld #E9E9EE mit Lupe und "Markt suchen". Weiße Sektion "Vorschläge" mit "Lidl" (blauer Punkt #0050AA) und grauer Unterzeile "aus 2 Einkäufen". Sektion "Alle Märkte" mit Zeilen, jeweils farbiger 8-pt-Punkt und Name: "Aldi Nord" (#00549F), "Aldi Süd" (#00005F), "Edeka" (gelber Punkt #FFD400 mit feiner grauer Kontur), "Kaufland" (#E10915), "Lidl" mit grünem Häkchen rechts, "Netto" (#FFE500 mit Kontur), "PENNY" (#CD1414), "REWE" (#CC071E). Keine Logos, nur Systemschrift.

### 11.3 Signale und Vorrang

1. **Eigene Wahl** (Chip, Neue Liste, Listen-Info, Avo) schlägt alles; Quelle "Von dir festgelegt".
2. **Listenname** beim Anlegen: setzt sichtbar (8). Beim späteren Umbenennen: nur Vorschlag "REWE?".
3. **Gelernt:** zweimal derselbe Markt im Abschluss → Vorschlag "Lidl?".
4. **Standort:** nur mit Erlaubnis und eingeschalteter Markt-Erkennung; erzeugt eine Hinweis-Zeile "Du bist bei Lidl. Lidl-Liste öffnen?" (Kapitel 10) bzw. einen Vorschlag, nie eine Zuordnung, nie ein Listenwechsel (K-28).
5. **Handelsmarken** ("Milbona", "ja!", "Gut & Günstig"): nur verstärkendes Signal für 3.
6. **Fallback:** kein fester Markt.

Daten (B): `shopping_lists.store_chain`, `store_source` (Migration Teil B, Kapitel 12). Teil A braucht nur `StoreChip(listId:)` und die Markt-ID der Liste für Reihenfolge und Einkaufsmodus-Titel (E-13).

---

## 12. Reihenfolge im Markt

### 12.1 Push "Reihenfolge im Markt"

**Zweck.** *In welcher Reihenfolge gehe ich durch den Markt?* Einstieg: Listen-Info, Menü "Mehr", Langdruck auf Gang-Titel im Einkaufsmodus, `/lists/:id/order`.

**Aufbau** (Push im Listen-Info-Sheet; aus Menü und Einkaufsmodus als eigenes Sheet groß; Inline-Titel "Reihenfolge im Markt"):
1. Satz oben (`body`, `label`): "Für Lidl. Gilt für alle auf „Wocheneinkauf“." bzw. ohne Markt "Für diese Liste."
2. Sektion: alle Kategorien als Zeilen, immer im Sortier-Modus: Kategorie-Symbol 17 pt `labelSecondary` (Übergangssymbole 00 Kap. 9.4), Name (`body`), rechts Anzahl offen (`number`, `labelSecondary`, nur wenn größer 0) und Griff `line.3.horizontal` (44-pt-Ziel). Ziehen am Griff oder Langdruck auf die Zeile hebt sie (1,03, `shadowFloat`), Einrasten mit Auswahl-Haptik.
3. Eigene Kategorien (Symbol `tag`) stehen als normale Zeilen in Sektion 2 und werden wie alle anderen einsortiert; sie haben zusätzlich ein Kontextmenü "Umbenennen", "Löschen". Eine eigene Sektion enthält nur "Kategorie hinzufügen" (`plus`, `action`) → 12.2.
4. Sektionsfuß: "Tipp: Halte im Einkaufsmodus einen Gang gedrückt, um ihn zu verschieben."
5. Schlicht "Standard-Reihenfolge" am Ende (stellt die Standard-Reihenfolge her, Rückgängig-Hinweis).

**Beispiel (Lidl).** Obst & Gemüse 3, Brot & Backwaren 1, Milch & Käse 3, Fleisch & Fisch 1, Vorrat 2, Snacks & Süßes, Tiefkühl, Getränke 1, Haushalt & Drogerie, Sonstiges.

**Regeln (L-07).** Die Reihenfolge gehört zur Liste und gilt für alle Mitglieder (geteilt, im Konto gespeichert, nicht mehr nur auf dem Gerät). Wird eine Liste neu einem Markt zugeordnet, für den man schon eine Reihenfolge hat, wird diese als Startwert übernommen. Eigene Kategorien gehören ebenfalls zur Liste (alle Mitglieder sehen sie; behebt "eigene Kategorien nur lokal"). Automatisches Lernen der Reihenfolge aus der Abhak-Folge ist ein Vorschlag (LF-02), nicht Teil von Version 1.

**Zustände.** Lädt: lokaler Stand. Offline: Sortieren lokal mit Warteschlange. Geändert von einem anderen Mitglied: Zeilen wandern live mit `springStandard` (nicht während man selbst zieht; dann nach dem Loslassen).

**AX und 320 pt.** Ab AX1 plain; Anzahl rutscht unter den Namen; Griff bleibt 44 pt.

**Was sich ändert.** Ersetzt `category_order_screen.dart` (Vollbild-Dialog mit Zurück-Pfeil, Material-Griff, Farbpunkte, nur lokal). `category_order_service.dart` speichert im Konto (E-14).

**Bildbeschreibung für ChatGPT.**
iOS-Sheet in voller Höhe auf #F2F2F7, oben links ein runder Glas-Zurück-Knopf mit "Listen-Info", mittig "Reihenfolge im Markt". Darunter der Satz "Für Lidl. Gilt für alle auf „Wocheneinkauf“." in Schwarz. Eine weiße Sektion mit zehn Zeilen: links je ein graues Kategorie-Symbol (Karotte, Torte, Fisch, Tropfen, Korb, Popcorn, Schneeflocke, Flasche, Seifenblasen, Tasche), Namen "Obst & Gemüse", "Brot & Backwaren", "Milch & Käse" usw., rechts teils graue Zahlen "3", "1" und je ein Griff aus drei waagerechten Linien. Die Zeile "Getränke" ist angehoben, leicht vergrößert, mit weichem Schatten, zwischen "Vorrat" und "Snacks & Süßes" gezogen. Darunter eine Sektion mit grüner Zeile "+ Kategorie hinzufügen" #3F7A1F.

### 12.2 Eigene Kategorie (Sheet mittel)

**Aufbau.** `xmark`, "Neue Kategorie" bzw. "Kategorie bearbeiten", `checkmark` getönt; ein Feld "Name" (Platzhalter "z. B. Getränkemarkt"); Sektionsfuß "Eigene Kategorien sehen alle auf dieser Liste." Keine Farbwahl (keine Farbe pro Kategorie, 00 Kap. 12.19), Symbol immer `tag`. Bearbeiten-Variante zusätzlich "Kategorie löschen" (`danger`, Bestätigung 10.4).

**Zustände.** Leerer Name: `checkmark` deaktiviert. Gleicher Name wie eine bestehende Kategorie: Zeile `exclamationmark.circle` `danger` "Diese Kategorie gibt es schon." Offline: lokal mit Warteschlange.

**Was sich ändert.** Ersetzt `_CategoryFormSheet` (Glas-Sheet mit 16 Material-Farben, eigener Griff, Glas-Buttons).

**Bildbeschreibung für ChatGPT.**
Kleines schwebendes iOS-Sheet in mittlerer Höhe über der Seite "Reihenfolge im Markt". Kopf: X links, "Neue Kategorie" mittig, grün getönter Häkchen-Knopf #3F7A1F rechts. Eine weiße Sektion mit einem Textfeld, in dem "Getränkemarkt" steht, darunter in Grau #636366 "Eigene Kategorien sehen alle auf dieser Liste." Keine Farbauswahl, keine Symbole außer einem grauen Preisschild-Symbol links im Feld. Unten die Systemtastatur.

---

## 13. Listenfarben statt Hintergründe (K-07)

- **Sichtbar:** Jede Liste hat Farbe und Symbol (00 Kap. 4.3). Die Farbe färbt nur den Glyph (Titelmenü, Alle Listen, Neue Liste, Listen-Info, Teilen, Beitreten) und den Titel im Listen-Widget (B). Häkchen bleiben `action`.
- **Nicht mehr sichtbar:** Verläufe und Bilder (`background_type`, `background_value`, `background_image_url`). Die Spalten bleiben unverändert, damit ältere App-Versionen nicht brechen.
- **Migration (Teil A):** neue Spalten `shopping_lists.color` (Text, Name aus der Palette) und `shopping_lists.symbol` (SF-Symbol-Name, Standard `cart`). Bestand: Farbe = Grundfarbe des Verlaufs bzw. nächstliegende Palettenfarbe, Bild = Blau. Ohne Hintergrund: Farbe nach Erstellreihenfolge.
- **Aufräumen:** `lib/core/constants/list_background_gradients.dart`, `ListsNotifier.saveBackground`, `ListRepository.saveBackground` entfallen; die Modellfelder bleiben lesbar, werden nicht mehr geschrieben.
- **Bildbeschreibung:** siehe Neue Liste (8) und Listen-Info (10.1).

---

## 14. Abläufe

### 14.1 Erste Liste anlegen (aus "Erste Liste", Kapitel 10)
1. Tab Liste ohne Liste: "Wie soll deine erste Liste heißen?" mit "Wocheneinkauf", "Lidl", "Drogerie", "Eigener Name".
2. Tippen auf "Lidl": Liste "Lidl" wird lokal angelegt (Farbe Blau, Symbol `cart`, Markt-Chip Lidl), erscheint sofort.
3. Accessory ist fokussiert, Tipp-Zeile "Tipp: Schreib „2 Milch“, dann steht die Menge gleich dabei."
4. "Eigener Name" öffnet Neue Liste (8).

### 14.2 Artikel hinzufügen mit "2 Milch"
1. Accessory antippen: Tab-Bar fährt weg, Panel zeigt bis 5 "oft gekauft".
2. "2 Mi": Vorschau "Mi · Menge 2"; nach "2 Milch" "Milch · Menge 2 · Milch & Käse"; Verlauf "Milch 1,5 %"; Angebot "Milbona Frische Vollmilch 1 l · Lidl" mit 0,99 €.
3. Return: Zeile wächst in "Milch & Käse" ein; liegt die Sektion außerhalb, Platzhalter zeigt kurz "Milch → Milch & Käse"; Feld leer, Fokus bleibt.
4. Gleicher Artikel offen: "Milch: Menge jetzt 4 · Widerrufen".
5. KI im Hintergrund bestätigt; bei Abweichung wandert die Zeile ohne Sprung.
6. Offline: identisch, Zeile mit Sync-Zeichen, `StatusRow` "Offline. 1 Änderung wartet."

### 14.3 Zettel importieren
1. `text.viewfinder` > "Kamera" (erstes Mal: Vorab-Erklärung > Systemabfrage).
2. Foto; Accessory zeigt "Zettel wird gelesen …" mit "Abbrechen"; Liste bleibt bedienbar.
3. Sheet "14 Artikel erkannt": unsichere prüfen ("Schmand?"), "Nicht erkannt" ansehen, "Brot" abwählen.
4. "13 Artikel hinzufügen": Sheet schließt, Zeilen wachsen ein, "13 Artikel hinzugefügt · Widerrufen".
5. Fehler: Kapsel "Auf dem Bild wurde keine Liste erkannt. Anderes Bild".

### 14.4 Artikel ändern und löschen
1. Name "Feta" antippen: Artikel-Sheet mittel.
2. Menge per Stepper von 200 auf 400 g (Schritt 50, Auswahl-Haptik), Notiz "griechisch".
3. `checkmark`: Sheet schließt, Zeile zeigt "400 g", Unterzeile "griechisch".
4. Löschen: Zeile ganz nach links wischen, sie fällt zusammen, "Feta gelöscht · Widerrufen" (4 s). Kein Dialog.

### 14.5 Umsortieren und Kategorie korrigieren
1. "Backpapier" steht in "Sonstiges". Langdruck: Kontextmenü erscheint.
2. Finger bewegen: Menü schließt, Zeile hebt sich; nach "Haushalt & Drogerie" ziehen, Einrasten mit Auswahl-Haptik.
3. Kategorie ist gesetzt und gelernt: das nächste "Backpapier" landet direkt dort.

### 14.6 Im Laden einkaufen
1. "Einkaufen": Morph in den Einkaufsmodus; erstes Mal Tipp-Zeile "Der Bildschirm bleibt an …".
2. Kopf "Lidl", "0 von 11"; Lena sieht "Jannis kauft gerade bei Lidl ein".
3. Gang für Gang abhaken (ganze Zeile); leichter Impuls; Zahl rollt; Zeile wandert nach 0,6 s nach "Im Wagen".
4. Falsch abgehakt: "Widerrufen" in der Leiste oder in "Im Wagen" nach rechts wischen.
5. Vergessen: `plus` > "Backpapier" > erscheint in "Haushalt & Drogerie"; "5 von 12".
6. Gang liegt anders: Langdruck auf "Getränke" > "Gang nach oben".
7. Letzter Artikel: Erfolgs-Haptik, "Alles im Wagen."
8. Weiter mit 14.8.

### 14.7 Gemeinsam einkaufen (zwei Geräte, Abnahme Plan 4)
1. Jannis startet den Einkaufsmodus bei Lidl. Lenas Liste zeigt sofort die Präsenz-Zeile; Lena bekommt eine Mitteilung "Jannis kauft gerade bei Lidl ein" (einmal).
2. Lena fügt zu Hause "Kaffee" hinzu: bei Jannis wächst "Kaffee" in "Vorrat" ein, Unterzeile "von Lena", "5 von 12".
3. Lena kommt dazu und startet ebenfalls den Einkaufsmodus: beide sehen "… kauft auch gerade ein".
4. Lena hakt "Butter" ab: bei Jannis 2 s Avatar am Kreis, dann Wanderung; VoiceOver "Lena hat Butter abgehakt".
5. Jannis beendet; Lena bekommt "Jannis hat bei Lidl eingekauft (11 Artikel)"; ihre Präsenz-Zeile verschwindet.
6. Prüfen: keine Mitteilung pro Häkchen; Zähler auf beiden Geräten gleich; nach Flugmodus und Rückkehr stimmt alles.

### 14.8 Einkauf beenden
1. "Einkauf beenden": Abschluss-Sheet mittel, kein Alert.
2. "Wo warst du?": Lidl vorausgewählt; Betrag optional; mit Modul "ca. 3,20 € durch Angebote gespart, laut Händler".
3. `checkmark`: Sheet schließt, Erfolgsmoment 1,5 s mit Erfolgs-Haptik.
4. Einkaufsmodus endet (Morph zurück); Liste zeigt nur Offenes; "Einkauf gespeichert · Widerrufen".
5. Markt wird gelernt; Mitglieder bekommen eine Mitteilung; nach dem ersten Mal Pro-Hinweis-Zeile auf der Startseite (Kapitel 10).

### 14.9 Teilen und beitreten
1. Toolbar `person.crop.circle.badge.plus`; erstes Mal Vorab-Erklärung Mitteilungen.
2. "Personen einladen" > System-Teilen > WhatsApp an Lena.
3. Lena tippt den Link: App öffnet (sonst App Store über `joinavo.app`), Beitritts-Sheet "„Wocheneinkauf“ beitreten?" > "Beitreten".
4. Bei Jannis: Mitteilung, Avatar erscheint in der Metazeile, "Lena ist beigetreten" in "Zuletzt geändert".
5. Alternativ: "Code anzeigen" "482 913" vorlesen; Lena: Titelmenü > "Liste beitreten" > Code > Vorschau > "Beitreten".

### 14.10 Markt festlegen und erkennen
1. Liste "Wocheneinkauf" ohne Markt; Chip "Markt wählen".
2. Zwei Abschlüsse bei Lidl: Chip wird "Lidl?" (gestrichelt).
3. Tippen: "Ist das deine Lidl-Liste?" > "Ja": Chip "Lidl", Quelle "Vorschlag aus 2 Einkäufen"; Angebote zeigen nur noch Lidl; Einkaufsmodus heißt "Lidl"; Reihenfolge für Lidl gilt.
4. Später den Chip auf "REWE" ändern: eigene Wahl gewinnt, Lidl wird nicht mehr vorgeschlagen.

### 14.11 Liste verlassen oder löschen
1. Menü "Mehr" > "Listen-Info" > ganz unten "Liste löschen".
2. Alert "„Party Samstag“ löschen?" > "Löschen".
3. Sheet schließt, die Liste von heute wechselt (Überblendung), Status-Hinweis "„Party Samstag“ gelöscht."; Mitglieder sehen beim nächsten Öffnen "„Party Samstag“ gibt es nicht mehr."

### 14.12 Offline im Laden
1. Im Keller des Markts kein Netz: `StatusRow` "Offline. Abhaken wird gespeichert und später gesendet."
2. Abhaken geht weiter; Zeilen tragen das Sync-Zeichen; App wird beendet und neu geöffnet: Stand ist da.
3. Netz zurück: Warteschlange sendet in Reihenfolge; Sync-Zeichen verschwinden; Präsenz meldet sich neu; Mitglieder sehen die Häkchen in einem Bündel.

---

## 15. Dateien und Daten

### 15.1 Dateien (Teil A, außer markiert)

| Heute | Neu | Schicksal |
|---|---|---|
| `screens/lists/list_detail_screen.dart` | `screens/lists/list_screen.dart` (Wurzel Tab Liste) | ersetzt |
| `screens/home/home_screen.dart` (Listen-Teil, Dialoge) | `all_lists_screen.dart`, `new_list_sheet.dart`, `join_list_sheet.dart`, Titelmenü | Listen-Teil entfällt (Rest Kapitel 10) |
| `widgets/add_item_composer.dart` | `widgets/design/add_item_accessory.dart`, `screens/lists/widgets/item_suggestion_panel.dart`, `lib/core/utils/item_input_parser.dart` | ersetzt |
| `widgets/attachment_sheet.dart` | Import-Menü und Status im Accessory | ersetzt |
| `widgets/import_review_sheet.dart` | `import_review_sheet.dart` neu | ersetzt |
| `widgets/list_item_tile.dart`, `list_category_section.dart`, `list_drag_controller.dart` | `ItemRow`, `AisleSection` (`widgets/design/`), neues Umsortieren | ersetzt |
| `widgets/list_detail_parts.dart`, `list_detail_menu.dart` | Toolbar und Menü "Mehr" | entfällt |
| `widgets/item_form_dialog.dart` (inkl. `PaperPrimaryButton`) | `item_sheet.dart`, `AppButton` | ersetzt; Nutzer in Auth/Onboarding mit umstellen |
| `widgets/share_list_dialog.dart` | `share_list_sheet.dart` | ersetzt |
| `shopping_trip_completion.dart` | dünner Aufrufer von `showCheckoutFlow` (B), Erfolgsmoment | gekürzt |
| `widgets/checkout_store_sheet.dart` (B) | Teil des Abschluss-Sheets (B) | B |
| `list_settings_screen.dart` | `list_info_sheet.dart` | ersetzt |
| `category_order_screen.dart` | `store_order_screen.dart`, `custom_category_sheet.dart` | ersetzt |
| `list_activities_screen.dart`, `data/services/list_activity_service.dart`, `models/list_activity.dart` | Abschnitt in Listen-Info, `list_events` | entfällt |
| `widgets/recommendations/ml_recommendations_section.dart`, `recommendation_card.dart` | Sektion "Vielleicht auch" | ersetzt |
| `widgets/list_price_summary_bar.dart`, `offer_suggestions_bar.dart`, `item_offer_sheet.dart`, `zip_code_sheet.dart` (B) | `ListOfferSummary`, Panel-Zeilen, `ItemOfferBadge`, Region-Sheet (B) | B |
| – | `shopping_mode_screen.dart`, `data/services/list_presence_service.dart` | neu |
| `state/lists_provider.dart`, `items_provider.dart`, `last_list_provider.dart` | optimistisch mit Warteschlange, Geräte-IDs, Liste von heute, `select` pro Artikel | geändert (APIs nur erweitern, Vertrag 5) |
| `repositories/item_repository.dart`, `list_repository.dart` | lokales Parsen, kein LLM im Hinzufügen-Pfad, keine Push pro Häkchen, stabiler Code, Beitritt per Link, Farbe/Symbol | geändert |
| `services/category_order_service.dart`, `unread_service.dart`, `offline_cache_service.dart` | Konto-Speicherung, Ungelesen-Anzeige, dauerhafte Warteschlange | geändert |
| `core/constants/list_background_gradients.dart` | – | entfällt |
| `core/constants/categories.dart` | Anzeigenamen kurz, SF Symbols, keine Material-Farben | geändert (E-01) |
| `routes/app_router.dart` | `routes/areas/lists.dart` mit Routen aus 01 Kap. 7 | aufgeteilt |
| Übersetzungen `app_translations.dart` | `translations/lists_de.dart`, `lists_en.dart`, Präfix `list_` | aufgeteilt |

### 15.2 Daten und Server

| Änderung | Besitz |
|---|---|
| `shopping_lists.color`, `symbol` (+ Bestands-Migration) | A |
| Geräte-erzeugte UUIDs für Artikel und Listen akzeptieren (Insert mit ID) | A |
| Stapel-Insert für Import, idempotent | A |
| `list_category_order` (Liste, Kategorie-ID, Position) und `list_custom_categories` (Liste, ID, Name) mit RLS für Mitglieder | A |
| Gelernte Kategorie pro Nutzer und Artikelname (`user_item_categories`) | A |
| `list_events` mit Triggern auf `shopping_items`, `shopping_lists`, `list_members`; Aufräumen nach 30 Tagen | A |
| Funktionen `get_invite_preview(code)`, `join_list(code)` (Drossel, Kollisionsprüfung), `rotate_share_code(list_id)` | A |
| Realtime Presence pro Liste (keine Tabelle) | A |
| `shopping_lists.store_chain`, `store_source`; Ketten-Verzeichnis | B |
| atomarer Abschluss `complete_shopping_trip` | B |
| gebündelte Mitteilungen (`shopping_started`, Abschluss, Beitritt, Zusammenfassungen) | B |

---

## 16. Offene Fragen an den Owner

| Nr. | Frage | Vorschlag |
|---|---|---|
| LF-01 | Sollen die Kategorien kürzere Anzeigenamen bekommen ("Milch & Käse" statt "Milchprodukte", "Brot & Backwaren" statt "Bäckerei & Frischetheke")? IDs bleiben. | ja (E-01) |
| LF-02 | Soll die Reihenfolge im Markt später automatisch aus der Abhak-Folge im Einkaufsmodus gelernt werden (mit Fußnote "Aus 3 Einkäufen bei Lidl gelernt", manuelle Sortierung gewinnt)? | ja, nach Version 1 |
| LF-03 | Wer darf einladen und einen neuen Code erzeugen? | alle Mitglieder laden ein; nur der Ersteller erzeugt einen neuen Code und entfernt Mitglieder |
| LF-04 | Gilt die Reihenfolge im Markt für alle Mitglieder einer Liste (geteilt) statt pro Person? | ja, geteilt (L-07) |
| LF-05 | Soll es im Einkaufsmodus "Nicht bekommen" geben (Artikel bleibt nach dem Abschluss auf der Liste, ohne abgehakt zu sein)? | heute deckt "nicht abhaken" das ab; erst nach Nutzer-Feedback |
| LF-06 | Darf der Ersteller die Liste an ein Mitglied übergeben, statt sie zu löschen? | später; Version 1 ohne |
| LF-07 | Sollen "Erledigte entfernen" (ohne Verlauf) und "Einkauf abschließen" (mit Verlauf) beide bleiben? | ja, Entfernen ist für Listen ohne Einkauf (z. B. Packliste) |
| LF-08 | Sollen Änderungen anderer bei "Zuletzt geändert" auch Mengen- und Notizänderungen zeigen? | nein, nur die Ereignisse aus 10.3 |

---

## 17. Ergänzungen zum Fundament

Was dieses Kapitel braucht und in 00 oder 01 fehlt oder ungenau ist. Teil A übernimmt sie in 00/01 bzw. in die Komponenten, sobald der Owner zustimmt.

| Nr. | Ergänzung | Grund |
|---|---|---|
| E-01 | **Kurze Anzeigenamen der 10 Kategorien** (IDs unverändert): Obst & Gemüse, Brot & Backwaren, Fleisch & Fisch, Vorrat, Snacks & Süßes, Getränke, Haushalt & Drogerie, Milch & Käse, Tiefkühl, Sonstiges (EN: Produce, Bakery, Meat & Fish, Pantry, Snacks & Sweets, Drinks, Household, Dairy, Frozen, Other). | 00 nutzt in Beispielen "Milch & Käse" und "Kühlregal", der Code "Milchprodukte" und "Bäckerei & Frischetheke" (zu lang für 320 pt im haftenden Gang-Titel). "Kühlregal" ist keine Kategorie und wird aus den 00-Beispielen ersetzt. |
| E-02 | **`ItemRow` Variante Einkaufsmodus: Wischen nach links "Löschen"** zusätzlich zum Zurückholen in "Im Wagen". | 00 Kap. 12.8 nennt im Einkaufsmodus nur Langdruck und Wischen nach rechts. |
| E-03 | **Geräte-erzeugte IDs** (UUID) für neue Artikel und Listen als Regel in 00 Kap. 13 "Nutzer-Aktionen". | Grundlage für sofort bedienbare neue Zeilen, Warteschlange und idempotente Wiederholung. |
| E-04 | **`AddItemAccessory`:** ab AX3 höchstens 2 Zeilen; Symbole wachsen nur bis xxxL (23 pt); ist das Feld schmaler als 160 pt, wandert `text.viewfinder` als Zeile "Zettel importieren" in das Vorschlags-Panel und das Menü "Mehr"; ab zwei Zeilen Form = Rechteck mit Radius 24. | 00 Kap. 12.4 fordert 160 pt Mindestbreite, ohne zu sagen, was bei 320 pt und AX passiert; drei Zeilen à 94 pt bei AX5 verdecken die Liste. |
| E-05 | **Rückgängig-Hinweis auf der Listen-Wurzel als Form in der Accessory-Glasgruppe** (morpht aus dem Accessory nach oben), statt eigener Glas-View. Im Einkaufsmodus eigene Glasfläche (Budget dort frei). | Sonst vier Glas-Views (Tab-Bar, Accessory, Toolbar, Hinweis) und Verstoß gegen 00 Kap. 8.5. |
| E-06 | **Ersparnis der Liste nie doppelt:** `ListOfferSummary` steht in der Liste nach den Gängen (Slot "Liste unten"), außer Kapitel 10 wählt sie als Hinweis-Zeile; dann entfällt sie in der Liste. | 00 Kap. 12.12 (Hinweis-Zeile oben) und `arbeitsteilung.md` (Slot "Liste unten") widersprechen sich. |
| E-07 | **Gelernte Kategorie pro Nutzer** als Kontodaten (nicht Gerät), gespeichert als Kategorie-ID. | Bug "gelernte Kategorien wirken nie"; gleiches Verhalten auf allen Geräten. |
| E-08 | **Bodenleiste Einkaufsmodus bei AX:** "Einkauf beenden" ab AX1 als "Beenden", unter 350 pt ab AX3 nur Symbol; Höhe der Leiste = Tab-Bar-Höhe. | 00 Kap. 6.3 regelt nur "Einkaufen" im Accessory. |
| E-09 | **Abschluss offline:** Abschluss geht in die Warteschlange und wird atomar gesendet; Verlauf entsteht serverseitig in einer Funktion. | 00 Kap. 13 fordert Warteschlange, Abschluss ist heute nicht atomar (doppelte Einträge). |
| E-10 | **"Anheften" = "Beim Start zeigen"**, genau eine Liste. Ein Begriff in allen Menüs: "Beim Start zeigen" (mit `pin`). | 00 Kap. 12.6 ("Anheften") und 01 Kap. 2.2 ("Beim Start zeigen") nennen dasselbe verschieden. |
| E-11 | **Einladungslink trägt den Code:** `https://shoplyai.app/join/<CODE>` für Einladungen; `/list/<id>` bleibt für Mitglieder (Teilen eines Links zur eigenen Liste) und öffnet bei Nicht-Mitgliedern "Bitte um eine Einladung". Vorschau und Beitritt über Server-Funktionen mit Drossel. | 01 Kap. 10.3 nennt `list/<id>` als Einladungslink; dann bliebe ein Link für immer gültig und "Neuen Code erzeugen" wäre wirkungslos. |
| E-12 | **`list_events`** als Datenquelle für "Zuletzt geändert", per Trigger geschrieben, 30 Tage. | K-33 sagt "echte Daten", nennt aber keine Quelle; Push-Bündelung (B) kann dieselbe Tabelle nutzen. |
| E-13 | **Vertrag A↔B ergänzen:** `storeForListProvider(listId)` (B) liefert Ketten-ID, Name, Markenfarbe; A nutzt ihn für Einkaufsmodus-Titel, Reihenfolge und Präsenz-Text. | `arbeitsteilung.md` nennt nur das Widget `StoreChip`, A braucht die Daten ohne Widget. |
| E-14 | **Reihenfolge im Markt und eigene Kategorien pro Liste im Konto** (Tabellen 15.2) als Regel in 00 Kap. 12.9. | 00 sagt "pro Markt gelernt bzw. eingestellt", lässt Speicherort und Geltung offen. |
| E-15 | **Präsenz-Regeln** (L-01) in 00 Kap. 12.29: nur Modus "einkaufen" wird gezeigt, Ende nach 5 Minuten Hintergrund, Realtime Presence ohne Tabelle. | 00 beschreibt nur das Aussehen. |
| E-16 | **Tipp-Zeile** (K-21) als Komponente: Symbol 16 pt `labelSecondary`, Text `callout` `label`, schlichte Aktion, Wischen blendet dauerhaft aus; Ort: unter dem Kopf des Screens. | K-21 nennt Tipp-Zeilen, 00 Kap. 12 hat keine Komponente dafür (`HintRow` gehört zur Startseite). |
