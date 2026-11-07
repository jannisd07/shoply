# 14 Wochenplan (neu)

Stand: 07.11.2026. Besitz: **Teil B** (Jannis, Mac 2), Arbeitspaket B7. Baut auf `00-grundlagen.md` (Tokens, Komponenten, Regeln; Verweise als "00 Kap. x") und `01-navigation-und-struktur.md` (Tab Plan, Routen, Ablauf 10.6; Verweise als "01 Kap. x") auf. Grundlage im Plan: Punkt 5 ("Rezepte wählen, Portionen anpassen, ein Tipp → alles auf der Liste") und Verbesserungsliste Punkt 11 ("Fertig, wenn ein Wochenplan mit 5 Rezepten eine saubere, zusammengefasste Liste erzeugt").

Markierungen: **W-xx** = Entscheidung dieses Kapitels (gesammelt in Kap. 15). **FW-xx** = offene Frage an den Owner (Kap. 16). **E-xx** = Ergänzung zum Fundament, die Teil A bestätigen bzw. umsetzen muss (Kap. 17).

Abgestimmt mit den Nachbarkapiteln: `10-heute.md` (Hinweis-Zeile "Heute im Plan", Wortlaut), `13-rezepte.md` (Menüeintrag "Zum Wochenplan" als Untermenü, Dienste `RecipeToList` und `RecipeAdaptation`, Grundzutaten "Hast du meist da", Wortlaut "Schon auf Wocheneinkauf (…)") und `16-avo.md` (Werkzeugnamen `add_to_plan`, `fill_plan`, `plan_to_list`, `get_plan`). Datumsformat nach 00 Kap. 3.2: "Mi., 11. Nov.".

Inhalt: 1 Überblick · 2 Beispielwoche · 3 Tab Plan · 4 Bausteine des Bereichs · 5 Sheet "Rezept wählen" · 6 Sheet "Zutaten der Woche" · 7 Erfolgsmoment und Rückgängig · 8 "Zum Wochenplan" (aus dem Rezept) · 9 Menüs · 10 Startseite "Heute im Plan" · 11 Verbindung zu Kalorien · 12 Einstellungen Wochenplan · 13 Daten und Logik · 14 Abläufe · 15 Entscheidungen · 16 Offene Fragen · 17 Ergänzungen zum Fundament · 18 Betroffene Dateien

---

## 1. Überblick

### 1.1 Hauptfrage und Platz in der App

- **Hauptfrage des Bereichs:** Was essen wir diese Woche, und ist alles auf der Liste? (01 Kap. 2.1)
- **Ort:** eigener Tab **Plan** (`calendar`, Position 3, Route `/plan`), nur mit Modul Wochenplan (00 Kap. 15.1, Standard an). Großer Titel "Wochenplan".
- **Warum ein eigener Tab (K-03):** Der Plan ist der Grund, die App an Tagen ohne Einkauf zu öffnen ("Was koche ich heute?"). Er verbindet die beiden Kernteile Rezepte und Liste und speist die Startseite ("Heute im Plan"), Kalorien (kcal pro Tag), Widget und Siri ("Was gibt's heute?").
- **Was es heute gibt:** nichts. Im Code existiert kein Wochenplan (keine Screens, keine Tabelle, kein Provider). Einzige Spur sind die Übersetzungsschlüssel `premium_feature_meal_planning` ("KI Essensplanung") und `premium_feature_meal_planning_desc` in `lib/core/localization/app_translations.dart` (Zeilen 976 f. und 2145 f.), die nur auf der heutigen Paywall stehen. Der Bereich ist vollständig neu.

### 1.2 Bestandteile

| Teil | Muster | Route | Kap. |
|---|---|---|---|
| Tab Plan, Woche mit sieben Tagen | Tab-Wurzel | `/plan`, `/plan/:weekStart` | 3 |
| Aktionsleiste "17 Zutaten auf Wocheneinkauf" | schwebende Glas-Gruppe über der Tab-Bar | – | 4.3 |
| Rezept wählen | Sheet groß | `/plan/add?day=YYYY-MM-DD` | 5 |
| Zutaten der Woche | Sheet mittel, zieht auf groß | `/plan/to-list` | 6 |
| Menge ändern (aus "Zutaten der Woche") | Push im Sheet (das Sheet zieht auf groß) | – | 6.8 |
| Erfolgsmoment und Rückgängig | Überlagerung, Rückgängig-Hinweis | – | 7 |
| Zum Wochenplan (aus dem Rezeptdetail) | Untermenü im Toolbar-Menü des Details (Teil A, 13 Kap. 18.1); Sheet mittel nur für "Anderes Datum…" | `/recipes/:recipeId/to-plan` (Sheet, neu, E-06) | 8 |
| Rezeptdetail aus dem Plan | Push im Tab Plan | `/plan/recipe/:recipeId?entry=:entryId` (neu, E-06) | 3.6 |
| Heute im Plan | Hinweis-Zeile auf der Startseite | – | 10 |
| Einstellungen Wochenplan, Vorrat | Push im Sheet "Profil" | `/settings/plan`, `/settings/plan/pantry` | 12 |

### 1.3 Grundregeln des Bereichs

1. **Planen ist frei und sofort.** Ein Rezept auf einen Tag legen, verschieben, Portionen ändern, entfernen: alles passiert sofort, lokal zuerst, ohne Speichern-Knopf, mit Rückgängig (00 Kap. 2, Prinzip 6).
2. **Ein Tipp bringt die Zutaten auf die Liste.** Die Aktionsleiste zählt, was noch fehlt; das Sheet "Zutaten der Woche" fasst gleiche Zutaten zusammen, lässt Vorhandenes und Grundzutaten weg und fügt alles in einem Schritt hinzu.
3. **Der Plan weiß, was schon auf der Liste ist.** Jeder Eintrag merkt sich, für wie viele Portionen seine Zutaten auf welcher Liste gelandet sind. Ändert man danach Portionen oder Rezepte, zählt die Leiste nur den Unterschied (W-05).
4. **Avo hat hier keinen eigenen Knopf** (01 Kap. 3). Avo kann den Plan füllen und auf die Liste bringen, aber nur über den Avo-Kreis.
5. **kcal nur mit Modul Kalorien.** Ohne Modul gibt es im ganzen Bereich keine Kalorienzahl.
6. **Angebote nur als Schild und Zeile** im Sheet "Zutaten der Woche", nur für den Markt der Ziel-Liste, nur mit Modul Angebote und ohne Kill-Switch (00 Kap. 4.4, 15.3).

---

## 2. Beispielwoche (gilt für alle Beispiele dieses Kapitels)

Heute ist **Mittwoch, 11. Nov. 2026**. Angezeigt wird die Woche **9.–15. Nov.** ("Diese Woche"). Ziel-Liste ist **Wocheneinkauf** (Listenfarbe Blau, Symbol `cart`, Markt-Chip **Lidl**, geteilt mit Lena). Standard-Portionen: 2. Modul Kalorien ist in den Beispielen an, sofern nicht anders gesagt.

| Tag | Rezept | Portionen | Zeit | kcal pro Portion | Status |
|---|---|---|---|---|---|
| Mo., 9. Nov. | Spaghetti mit Linsen-Bolognese | 2 | 25 Min | 610 | auf der Liste (am Sa., 7. Nov.) |
| Di., 10. Nov. | Ofengemüse mit Feta | 2 | 35 Min | 540 | auf der Liste (am Sa., 7. Nov.) |
| **Mi., 11. Nov. (Heute)** | Chili sin Carne | 4 (Rest für Do mittags) | 40 Min | 480 | noch nicht auf der Liste |
| Do., 12. Nov. | – | – | – | – | leer |
| Fr., 13. Nov. | Lachs mit Ofenkartoffeln | 2 | 30 Min | 650 | noch nicht auf der Liste |
| Sa., 14. Nov. | Gemüse-Curry mit Reis | 3 (Besuch) | 35 Min | 520 | noch nicht auf der Liste |
| Sa., 14. Nov. | Apfel-Crumble | 4 | 45 Min | 310 | noch nicht auf der Liste |
| So., 15. Nov. | – | – | – | – | leer |

**Zutaten ab heute (Mi bis So), zusammengefasst** für Wocheneinkauf, geordnet nach der Reihenfolge im Markt Lidl:

| Kategorie | Zutat | Menge | für | Vorauswahl |
|---|---|---|---|---|
| Obst & Gemüse | Zwiebeln | 3 | Chili sin Carne, Gemüse-Curry | an |
| | Knoblauch | 2 Zehen | Chili sin Carne | an |
| | Paprika | 1 | Chili sin Carne | an |
| | Koriander | 1 Bund | Chili sin Carne | an |
| | Kartoffeln | 600 g | Lachs mit Ofenkartoffeln | an |
| | Zitrone | 1 | Lachs mit Ofenkartoffeln | an |
| | Dill | 1 Bund | Lachs mit Ofenkartoffeln | an |
| | Brokkoli | 1 | Gemüse-Curry mit Reis | an |
| | Äpfel | 4 | Apfel-Crumble | an |
| Milch & Käse | Joghurt | 150 g | Gemüse-Curry mit Reis | an |
| | Butter | 100 g | Apfel-Crumble | an |
| Fleisch & Fisch | Lachsfilet | 2 (250 g) | Lachs mit Ofenkartoffeln | an |
| Vorrat | Kidneybohnen | 2 Dosen | Chili sin Carne | an |
| | Mais | 1 Dose | Chili sin Carne | an |
| | Passierte Tomaten | 500 g | Chili sin Carne | an |
| | Kokosmilch | 400 ml | Gemüse-Curry mit Reis | an |
| | Kichererbsen | 1 Dose | Gemüse-Curry mit Reis | an |
| | Reis | 475 g | Chili sin Carne, Gemüse-Curry | **aus**: "Schon auf Wocheneinkauf (1 kg)" |
| | Mehl | 150 g | Apfel-Crumble | **aus**: "Hast du meist da" |
| | Zucker | 80 g | Apfel-Crumble | **aus**: "Hast du meist da" |

Vorausgewählt sind **17 Zutaten**; daher heißt die Aktionsleiste "17 Zutaten auf Wocheneinkauf". Mit Modul Angebote sind bei Lidl diese Woche im Angebot: Lachsfilet 3,99 € (laut Händler statt 5,49 €), Kokosmilch 0,89 € (laut Händler statt 1,29 €), Äpfel 1,99 € je 1-kg-Beutel (laut Händler statt 2,49 €). Ersparnis-Zeile: "3 von 17 Zutaten diese Woche bei Lidl im Angebot, ca. 2,40 € gespart, in deiner Region".

kcal pro Tag (eine Portion je Rezept, also pro Person): Mo 610, Di 540, Mi 480, Fr 650, Sa 830.

---

## 3. Tab Plan (Wurzel "Wochenplan")

### 3.1 Zweck und Einstieg

- **Hauptfrage:** Was essen wir diese Woche, und ist alles auf der Liste?
- **Wann man hierher kommt:** Tab Plan; Hinweis-Zeile "Heute im Plan" auf der Startseite; Wochenplan-Widget; Siri "Was gibt's heute?" (öffnet bei Tipp auf das Snippet); Mitteilung "Woche planen" (nur wenn eingeschaltet, Kap. 12); Avo-Ergebniszeile "Ansehen"; Deep Link `shoply://plan`.
- **Welche Woche:** `/plan` zeigt immer die aktuelle Woche (Montag bis Sonntag, Wochenbeginn Montag, W-02). `/plan/:weekStart` zeigt die Woche ab diesem Montag. Erneutes Tippen auf den aktiven Tab: zur Wurzel, zur aktuellen Woche, zu "Heute".

### 3.2 Aufbau von oben nach unten

1. **Obere Zeile (44 pt):** rechts `GlassToolbar` als eine Glasgruppe mit drei Knöpfen: `chevron.left` ("Vorige Woche"), `chevron.right` ("Nächste Woche"), `ellipsis` ("Mehr", Menü 9.2). Links nichts (Tab-Wurzel).
2. **`LargeTitleNavBar`, Variante Tab-Wurzel:** großer Titel "Wochenplan" (`largeTitle`), rechts in der Titelzeile der Profil-Avatar (36 pt, kein Glas).
3. **Metazeile unter dem Titel** (8 pt Abstand, `subheadline`): schlichter Knopf mit Text in `label` und `chevron.down` 13 pt Semibold in `labelSecondary`: "Diese Woche · 9.–15. Nov.". Tippen öffnet das Wochen-Menü (9.1). Andere Wochen: "Nächste Woche · 16.–22. Nov.", "Letzte Woche · 2.–8. Nov.", sonst "KW 50 · 7.–13. Dez.". Darunter, nur wenn nötig, eine `StatusRow` (offline, ausstehend, Fehler; 3.5).
4. **Sektion "Vergangene Tage (2)"** (nur in der aktuellen Woche, nur wenn Tage vor heute existieren): `InsetSection` in der Variante einklappbar, standardmäßig eingeklappt, Titel mit `chevron.right`; ausgeklappt zeigt sie die Tagesabschnitte Mo und Di in derselben Form wie unten. Grund: Die Seite beginnt mit "Heute", ohne dass beim Öffnen der Titel wegscrollt (W-03). In anderen Wochen entfällt die Sektion; alle sieben Tage stehen offen untereinander.
5. **Ein Tagesabschnitt pro Tag** (`PlanDaySection`, 4.1), von heute bis Sonntag, jeweils mit `sectionGap` 32 pt Abstand:
   - Kopf: "Heute" (`headline`) und darunter "Mi., 11. Nov." (`subheadline`, `labelSecondary`); andere Tage nur "Do., 12. Nov." (`headline`). Rechts mit Modul Kalorien die geplanten kcal ("480 kcal", `numberS`, `labelSecondary`).
   - Zeilen: je Rezept eine `PlanEntryRow` (4.2): Foto 56 pt, Titel, Metazeile, Portionen-Stepper.
   - Letzte Zeile jedes Tages: schlichte Zeile `plus` und "Rezept hinzufügen" in `action` (wie "Neue Erinnerung" in Erinnerungen). Ein leerer Tag besteht nur aus dieser Zeile.
6. **Sektionsfuß nach Sonntag** (`footnote`, `labelSecondary`), nur mit Modul Kalorien: "kcal pro Person, eine Portion je Rezept." Keine Wochensumme (W-09).
7. **Unterer Inhaltsabstand** aus `ShellInsets` = Tab-Bar + Aktionsleiste + 16 (E-01).
8. **Aktionsleiste** `PlanActionBar` (4.3), schwebend 8 pt über der Tab-Bar: getönte Glas-Kapsel "17 Zutaten auf Wocheneinkauf" und rechts daneben der runde Glas-Knopf mit dem Glyph der Ziel-Liste. Nur sichtbar, wenn im gewählten Zeitraum Zutaten fehlen.
9. **Tab-Bar** mit Avo-Kreis (00 Kap. 12.1), Tab Plan ausgewählt.

Glas-Budget (00 Kap. 8.5): Tab-Bar mit Avo-Kreis (1), Toolbar-Gruppe oben (2), Aktionsleiste (3). Mehr Glas gibt es auf diesem Screen nicht. Ein `UndoToast` (00 Kap. 12.28) nimmt deshalb den Platz der Aktionsleiste ein: Die Leiste blendet aus (`springStandard`), der Hinweis erscheint an ihrer Stelle 8 pt über der Tab-Bar; nach Ablauf oder Wischen kehrt die Leiste zurück. Nie stehen Leiste und Hinweis übereinander. Menüs (Kap. 9) wachsen aus ihrem Auslöser und ersetzen ihn optisch, solange sie offen sind; sie liegen nicht auf einer anderen Glasfläche.

### 3.3 Beispielinhalt (Woche 9.–15. Nov., heute Mi)

- Metazeile: "Diese Woche · 9.–15. Nov."
- "Vergangene Tage (2)", eingeklappt.
- **Heute, Mi., 11. Nov.** · 480 kcal
  - Chili sin Carne · "40 Min · 480 kcal" · Stepper 4
  - Rezept hinzufügen
- **Do., 12. Nov.**
  - Rezept hinzufügen
- **Fr., 13. Nov.** · 650 kcal
  - Lachs mit Ofenkartoffeln · "30 Min · 650 kcal" · Stepper 2
  - Rezept hinzufügen
- **Sa., 14. Nov.** · 830 kcal
  - Gemüse-Curry mit Reis · "35 Min · 520 kcal" · Stepper 3
  - Apfel-Crumble · "45 Min · 310 kcal" · Stepper 4
  - Rezept hinzufügen
- **So., 15. Nov.**
  - Rezept hinzufügen
- Ausgeklappt: **Mo., 9. Nov.** · 610 kcal: Spaghetti mit Linsen-Bolognese, Metazeile zweite Zeile "`checkmark` Auf Wocheneinkauf"; **Di., 10. Nov.** · 540 kcal: Ofengemüse mit Feta, ebenso.
- Aktionsleiste: "17 Zutaten auf Wocheneinkauf", Glyph-Knopf blauer Kreis mit weißem `cart`.

### 3.4 Interaktionen, Gesten, Bewegung, Haptik

| Aktion | Verhalten | Bewegung | Haptik |
|---|---|---|---|
| Woche wechseln per Toolbar | `chevron.left` / `chevron.right`: die Woche gleitet seitlich heraus, die neue herein; Metazeile wechselt | `springStandard`; Metazeile Überblendung | keine (normaler Knopf) |
| Woche wechseln per Wischen | Waagerechtes Wischen auf dem Inhalt (nicht in der Tab-Bar, nicht auf der Aktionsleiste): nach 10 pt Hysterese und eindeutig waagerechter Richtung folgt die Woche dem Finger 1:1, die Nachbarwoche ist schon gezeichnet. Beim Loslassen entscheidet die Wurfprojektion (00 Kap. 10.1), ob gewechselt wird | `springFling` mit Fingergeschwindigkeit; an der Grenze (52 Wochen zurück, 52 voraus) Gummiband | Auswahl beim Einrasten auf einer neuen Woche |
| Woche wählen über die Metazeile | Menü 9.1 wächst aus der Metazeile | `springMenu` | keine |
| Rezept antippen (Zeile außerhalb des Steppers) | Push Rezeptdetail im Tab Plan mit den Portionen des Eintrags (3.6) | Zoom-Übergang vom 56-pt-Foto ins Detail (`springMorph`) | keine |
| Portionen ändern | Stepper (00 Kap. 12.21), 1 bis 20; die Zahl rollt; kcal im Tageskopf ändern sich nicht (pro Person); ist der Eintrag schon auf der Liste, erscheint bzw. aktualisiert sich die Aktionsleiste ("2 Zutaten auf Wocheneinkauf") | `RollingNumber` mit `springDigits` | Auswahl pro Schritt |
| "Rezept hinzufügen" | öffnet Sheet "Rezept wählen" für diesen Tag (Kap. 5) | `springSheet` | keine |
| Langdruck auf eine Rezeptzeile | Kontextmenü 9.3 (Zeile hervorgehoben); Weiterziehen ohne Loslassen startet das Verschieben | Menü `springMenu` | systemseitig |
| Verschieben auf einen anderen Tag | Zeile hebt sich (Skalierung 1,03, `shadowFloat`), folgt dem Finger 1:1 mit Abstand zum Griffpunkt; über einem Tag öffnet sich die Lücke; Auto-Scroll am Rand; Loslassen legt sie ab; Ziehen auf die Toolbar-Chevrons blättert nach 0,6 s Verweilen in die Nachbarwoche | Nachbarn `springStandard`; Ablegen `springFling` | Auswahl beim Einrasten |
| Eintrag entfernen | nur über Kontextmenü "Entfernen" bzw. Bearbeiten-Modus; sofort, `UndoToast` "Apfel-Crumble entfernt · Widerrufen" | Höhe schrumpft mit `springStandard` | keine |
| Bearbeiten-Modus (Menü 9.2) | Zeilen zeigen links `minus.circle.fill` in `danger` und rechts den Griff `line.3.horizontal`; Stepper ausgeblendet; oben rechts statt der Toolbar-Gruppe der getönte Glas-Knopf `checkmark` ("Fertig") | Elemente blenden mit `springStandard` ein | keine |
| "Vergangene Tage" auf- und zuklappen | Sektion klappt auf bzw. zu, Zustand pro Gerät gemerkt | `springStandard` | keine |
| Aktionsleiste antippen | öffnet Sheet "Zutaten der Woche"; das Sheet steigt aus der Leiste auf, die Leiste geht im Sheet auf | `springSheet` | keine |
| Glyph-Knopf der Leiste | Menü "Ziel-Liste" (9.4) wächst aus dem Knopf | `springMenu` | keine |
| Ziehen nach unten am Inhaltsanfang | Systemverhalten: Neu laden (selten nötig, 00 Kap. 13) | System | keine |

**Wischaktionen auf Zeilen gibt es im Wochenplan nicht (W-04).** Waagerechtes Wischen gehört dem Wochenwechsel; zwei Bedeutungen derselben Geste auf derselben Fläche wären nicht vorhersagbar. Entfernen und Verschieben laufen über Kontextmenü, Ziehen und den Bearbeiten-Modus; VoiceOver hat dafür eigene Aktionen.

**Reduce Motion:** Wochenwechsel als Überblendung (`fadeReduced`), auch beim Wischen (der Finger zieht die Woche nicht mit; ein Wisch über 60 pt wechselt nach dem Loslassen). Zoom-Übergang als Überblendung. Verschieben: die gehobene Zeile folgt dem Finger, Nachbarn springen nicht, sondern blenden an die neue Stelle. Zahlen überblenden.

### 3.5 Zustände

| Zustand | Darstellung |
|---|---|
| **Erster Start** (noch nie ein Rezept geplant) | Unter Titel und Metazeile ein `EmptyState` an der Stelle der Tage: Maskottchen "zufrieden" 96 pt, Titel "Was essen wir diese Woche?" (`title3`), Satz "Leg Rezepte auf die Tage. Mit einem Tipp landen alle Zutaten auf deiner Liste." (`body`, `label`), prominent "Rezept für heute wählen" (öffnet Kap. 5 für heute), darunter schlicht "Tab ausblenden" (schaltet das Modul aus, mit `UndoToast` "Wochenplan ausgeblendet · Widerrufen"). Keine Tage, keine Aktionsleiste. Ab AX1 ohne Maskottchen. |
| **Leere Woche** (später, z. B. nächste Woche) | Alle sieben Tage mit "Rezept hinzufügen". Darüber, wenn die Vorwoche Einträge hatte, eine `InsetSection` mit einer Zeile: `doc.on.doc` 17 pt, "Rezepte der Vorwoche übernehmen" (`body`), Unterzeile "6 Rezepte · 9.–15. Nov.", schlichte Aktion "Übernehmen". Übernehmen legt alle Einträge mit gleichen Tagen und Portionen an, `UndoToast` "6 Rezepte übernommen · Widerrufen". |
| **Lädt mit lokalem Stand** | Woche sofort aus dem lokalen Speicher; Abgleich im Hintergrund; Änderungen von einem anderen Gerät desselben Kontos (Owner und Jannis!) wachsen ein bzw. schrumpfen weg, ohne Sprung. Kein Indikator. |
| **Allererstes Laden ohne lokalen Stand** (neues Gerät) | Skelett in Form der Woche: Titel und Metazeile echt, darunter sieben Tagesköpfe als ruhige `fill`-Flächen (Breite 96 pt, Höhe einer `headline`-Zeile) mit je einer Zeilenfläche 56 pt hoch. Kein Schimmer. Höchstens bis zur ersten Antwort. |
| **Allererstes Laden schlägt fehl** (neues Gerät, kein Netz, kein lokaler Stand) | Statt des Skeletts ein Fehler im Layout des leeren Zustands (00 Kap. 12.27): Symbol `icloud.slash` 48 pt Light, Titel "Wochenplan nicht geladen", Satz "Ohne Verbindung kann der Plan auf diesem iPhone noch nicht angezeigt werden.", schlicht "Erneut versuchen". Kein Maskottchen. Planen ist in diesem Zustand nicht möglich, weil sonst lokale und gespeicherte Einträge kollidieren. |
| **Nachbarwochen** | werden beim Öffnen des Tabs im Hintergrund vorgeladen (vorige und nächste), damit Wischen nie leer zeigt. |
| **Offline** | `StatusRow` unter der Metazeile: `icloud.slash`, "Offline. Änderungen werden gespeichert, sobald du wieder online bist." Planen, Portionen, Verschieben und "Zutaten auf die Liste" funktionieren (Warteschlange); geänderte Zeilen tragen das Sync-Zeichen `arrow.triangle.2.circlepath` 10 pt unten rechts am Foto. Fotos nicht gecachter Rezepte zeigen die `photo_color`-Fläche. |
| **Ausstehend** | `StatusRow` "3 Änderungen warten" mit `arrow.triangle.2.circlepath`, verschwindet nach dem Abgleich. |
| **Fehler beim Speichern** | Eintrag rollt zurück (wächst wieder ein bzw. springt an den alten Tag) mit Fehler-Haptik und `StatusRow` "Das hat nicht geklappt. Erneut versuchen" über dem betroffenen Tag. |
| **Rezept gelöscht** (vom Ersteller) | Zeile als Typo-Fläche (`fill`, ohne Foto), Titel aus der gespeicherten Kopie, Metazeile "Rezept nicht mehr verfügbar" (`labelSecondary`); Tippen öffnet das Kontextmenü mit "Entfernen"; Zutaten zählen nicht mehr. |
| **Vergangene Wochen** | lesbar und änderbar (Nachtragen fürs Kalorien-Tagebuch), aber ohne Aktionsleiste und ohne "Rezepte der Vorwoche übernehmen". |
| **Modul aus** | Tab fehlt (Tab-Bar blendet ihn mit `springStandard` aus, 00 Kap. 12.1). Steht man darauf, landet man auf Liste. `/plan…`-Routen, Widget und Siri öffnen das Modul-Sheet "Wochenplan ist ausgeschaltet" mit "Einschalten" / "Nicht jetzt" (00 Kap. 13). Die Daten bleiben; nach dem Einschalten ist der Plan wieder da. |
| **Pro gesperrt** (nur falls der Owner den Plan zu Pro macht, F-05) | Der ganze Tab ist voll benutzbar: planen, Portionen, verschieben, Rezepte ansehen. Die Aktionsleiste trägt hinter dem Text die `ProBadge` in der Variante "auf getönt" (E-02). Erst ihr Tipp öffnet die Paywall, die aus der Leiste wächst, mit "Wochenplan" oben (00 Kap. 16.2). Nach dem Kauf öffnet sich direkt das Sheet "Zutaten der Woche" (01 Kap. 10.10, Schritt 5). Kein Schloss, kein Sperrbildschirm. Bei unbekanntem Pro-Status keine Badge. |

### 3.6 Rezeptdetail aus dem Plan

- Tippen auf eine Rezeptzeile pusht das Rezeptdetail (Teil A, 13) **im Tab Plan** (Tab-Bar bleibt, Zurück führt zum Plan). Route `/plan/recipe/:recipeId?entry=:entryId` (E-06).
- Mit `entry` übernimmt das Detail die Portionen des Eintrags. Ändert man dort die Portionen, fragt das Detail nicht nach; der Plan-Eintrag übernimmt die neue Zahl (eine Wahrheit pro Eintrag).
- Unter dem Titel steht im Detail eine Metazeile "Im Plan: Mi., 11. Nov. · 4 Portionen" (`subheadline`, `labelSecondary`), Slot von B (E-07).
- Aktionsleiste des Details bleibt "Zutaten auf Liste" / "Kochen" (00 Kap. 8.1). "Zutaten auf Liste" aus dem Detail markiert den Plan-Eintrag ebenfalls als "Auf der Liste" (gemeinsame Logik, 13.3).

### 3.7 Große Schrift (AX) und 320 pt Breite

- **320 pt (iPhone SE, Anzeigezoom):** Seitenrand 16. Toolbar-Gruppe (3 × 44 pt) passt. Metazeile bricht bei Bedarf nach dem Mittelpunkt um ("Diese Woche ·" / "9.–15. Nov."). Tageskopf: kcal rutschen unter das Datum. `PlanEntryRow` stellt den Stepper unter die Metazeile (4.2). Aktionsleiste: Text bricht in zwei Zeilen ("17 Zutaten auf" / "Wocheneinkauf"), die Kapsel wird höher.
- **xxL bis xxxL:** wie 320 pt für Zeile und Stepper; Tageskopf mit kcal in zweiter Zeile.
- **Ab AX1:** Tab-Beschriftungen entfallen; Sektionen randlos (00 Kap. 6.4); Foto oben bündig zur ersten Titelzeile; Maskottchen im leeren Zustand entfällt; Toolbar-Knöpfe und Aktionsleiste mit Large Content Viewer.
- **Ab AX3:** Das 56-pt-Foto entfällt in Rezeptzeilen (E-05), der Titel bekommt die volle Breite. Die Aktionsleiste zeigt nur noch "17 Zutaten" in `headline` (bricht bei Bedarf in zwei Zeilen, die Kapsel wird höher); das Ziel zeigt der Glyph-Knopf daneben, ausgeschrieben steht es in VoiceOver und im Large Content Viewer ("17 Zutaten auf Wocheneinkauf").
- **AX5 auf 320 pt:** Der große Titel "Wochenplan" ist ein einzelnes Wort mit etwa 330 pt Breite bei 60 pt. Verfügbar sind 288 pt minus Avatar (36 pt plus 8 pt Abstand) = 244 pt. Verkleinern bis 0,8 (etwa 264 pt) reicht nicht; deshalb bricht der Titel an der in der Übersetzung hinterlegten Trennstelle mit Bindestrich um ("Wochen-" / "plan", E-04). Nie mitten im Wort ohne Bindestrich, nie Ellipse.
- Nie feste Höhen um Text; alle Zeilen haben `rowMinHeight` 44 als Mindestwert.

### 3.8 Barrierefreiheit

- Reihenfolge: Toolbar, Titel, Metazeile ("Woche wählen, Diese Woche, 9. bis 15. November"), Statuszeile, Tage, Aktionsleiste, Tab-Bar.
- Tageskopf als Überschrift: "Heute, Mittwoch, 11. November, 480 Kilokalorien pro Person".
- Rezeptzeile als ein Element: "Chili sin Carne, 40 Minuten, 480 Kilokalorien, 4 Portionen, noch nicht auf der Liste"; einstellbar (Wischen hoch/runter ändert Portionen); eigene Aktionen: Rezept ansehen, Kochen, Auf anderen Tag, Entfernen, Ins Tagebuch (Modul).
- Wochenwechsel zusätzlich als Rotor-Aktionen "Vorige Woche" / "Nächste Woche" auf dem Titel; Drei-Finger-Wischen wechselt die Woche.
- Änderungen von anderen Geräten werden höflich angesagt ("Apfel-Crumble am Samstag hinzugefügt").

### 3.9 Was sich gegenüber heute ändert, betroffene Dateien

- Neu (B): `lib/presentation/screens/plan/plan_screen.dart`, `widgets/plan_day_section.dart`, `widgets/plan_entry_row.dart`, `widgets/plan_action_bar.dart`, `widgets/plan_week_pager.dart`; Provider `lib/presentation/state/plan_provider.dart`; Modell `lib/data/models/meal_plan_entry.dart`; Dienst `lib/data/services/meal_plan_service.dart`; Routen `lib/routes/areas/plan_routes.dart`; Texte `lib/core/localization/translations/plan_de.dart` / `plan_en.dart` (Präfix `plan_`); Migration `supabase/migrations/<zeit>_b_meal_plan.sql`.
- Berührt (A, per Anfrage): `main_scaffold.dart` bzw. die neue Tab-Bar (Tab Plan, Modulsteuerung), `ShellInsets` (E-01), Rezeptdetail (Metazeile "Im Plan", Menüeintrag "Zum Wochenplan", Übernahme der Plan-Portionen).

### 3.10 Bildbeschreibung für ChatGPT

iPhone-Screenshot im Hochformat (393 × 852 pt), iOS 27, hell, Hintergrund #F2F2F7. Oben rechts eine einzige schwebende Liquid-Glass-Kapsel mit drei Symbolen (Pfeil nach links, Pfeil nach rechts, drei Punkte), darunter links der große fette Titel "Wochenplan" in Schwarz #000000, rechts daneben ein runder Profil-Avatar ohne Glas. Unter dem Titel die Zeile "Diese Woche · 9.–15. Nov." in Schwarz mit einem kleinen grauen Pfeil nach unten, darunter eine eingeklappte weiße Sektion "Vergangene Tage (2)" mit grauem Pfeil nach rechts. Es folgen weiße, stark abgerundete Sektionen (Radius 26) pro Tag: Kopf "Heute" fett mit "Mi., 11. Nov." in Grau #636366 und rechts "480 kcal" in Grau; darin eine Zeile mit quadratischem Essensfoto (56 pt, Radius 12, rotes Chili), Titel "Chili sin Carne", Unterzeile "40 Min · 480 kcal" in Grau und rechts ein hellgrauer Kapsel-Stepper #E9E9EE mit "−", "4", "+"; darunter die Zeile "+ Rezept hinzufügen" in Avocado-Grün #3F7A1F. Weiter unten "Do., 12. Nov." nur mit "+ Rezept hinzufügen", dann "Fr., 13. Nov." mit "Lachs mit Ofenkartoffeln" und "Sa., 14. Nov." mit zwei Rezepten. Unten schwebt über einer milchigen Glas-Tab-Bar (Symbole mit Beschriftung "Liste", "Rezepte", "Plan" in Grün #3F7A1F ausgewählt, "Kalorien"; rechts abgesetzt ein runder Glas-Kreis mit kleiner brauner Kugel #7A4A24 in hellgrünem Ring #C9DE6E) eine grün getönte Glas-Kapsel #3F7A1F mit weißem Einkaufswagen-Symbol und weißem halbfettem Text "17 Zutaten auf Wocheneinkauf" und rechts daneben ein runder, ungetönter Glas-Knopf mit einem blauen Kreis #007AFF und weißem Einkaufswagen. Der Inhalt läuft unter Tab-Bar und Kapsel weich aus (Verlauf in #F2F2F7, keine Linie). Keine Großbuchstaben-Zeilen, keine Icons in farbigen Quadraten, keine Schatten auf den Sektionen, kein Maskottchen.

---

## 4. Bausteine des Bereichs

Alle aus Komponenten von 00 Kap. 12 zusammengesetzt; Teil B baut sie in `screens/plan/widgets/`.

### 4.1 Tagesabschnitt (`PlanDaySection`)

- **Anatomie:** `InsetSection` (inset, `radiusSection` 26) mit Sektionstitel als Tageskopf (3.2, Punkt 5), Zeilen `PlanEntryRow`, letzte Zeile "Rezept hinzufügen" (schlichte Zeile, `plus` 17 pt und Text `body` in `action`, Trennlinie ab der Textkante).
- **Varianten:** heute (zweizeiliger Kopf "Heute" / Datum), normal, leer (nur Hinzufügen-Zeile), Ablageziel beim Verschieben (Lücke 56 pt öffnet sich an der Einfügestelle), plain ab AX1.
- **Regel:** Der Kopf ist keine Taste. Tippen auf den Kopf tut nichts; "Rezept hinzufügen" ist der einzige Einstieg pro Tag.
- **Hinweis zu 00 Kap. 7.1:** Dort steht "Wochenplan-Tag" unter `radiusCard` (20). Die Tage sind aber Sektionen, keine frei stehenden Karten; es gilt `radiusSection` (E-08).

### 4.2 Rezeptzeile im Plan (`PlanEntryRow`)

- **Anatomie (links nach rechts):** `RecipeCard` in der Variante Zeile (00 Kap. 12.13): Thumbnail 56 pt mit `radiusThumb` 12 (`photo_color` als Fläche, Foto blendet in 0,2 s ein; ohne Foto Typo-Fläche `fill` mit einem Avo Symbol der Hauptzutat), Titel (`headline`, bricht um, keine Ellipse), Metazeile (`subheadline`, `labelSecondary`): "40 Min · 480 kcal" (kcal nur mit Modul Kalorien). Optionale zweite Metazeile: "`checkmark` Auf Wocheneinkauf" bzw. "`checkmark` Auf Wocheneinkauf · 2 Portionen mehr geplant", Mahlzeit ("Mittagessen", nur wenn gesetzt, nur mit Modul Kalorien), Allergie-Hinweis (`exclamationmark.triangle.fill` und Text in `warning`: "Enthält Erdnuss"). Rechts der Stepper (`ValueStepper`, Größe kompakt, E-03).
- **Layout-Umschaltung:** Stepper rechts neben dem Text bei Breite ab 390 pt und Textgröße bis xL; sonst unter der Metazeile, bündig zur Textkante (Flex mit Umschaltung, nicht `Row`). Mindesthöhe 72 pt bei Foto, sonst 44.
- **Zustände:** normal; auf der Liste; geändert seit "auf der Liste" (zweite Metazeile nennt den Unterschied); ausstehend (Sync-Zeichen); Fehler; Rezept nicht verfügbar (3.5); gehoben (beim Ziehen); Bearbeiten-Modus.
- **Flutter:** `RepaintBoundary` pro Zeile; Riverpod `select` auf den einzelnen Eintrag, damit ein Stepper-Schritt nur seine Zeile und die Aktionsleiste neu baut; Bilder über `CachedNetworkImage` mit `memCacheWidth` = 56 × Pixelverhältnis; die zwei Fotos der Nachbarwoche werden vorgeladen.

### 4.3 Aktionsleiste (`PlanActionBar`)

- **Zweck:** die eine Hauptaktion des Tabs: fehlende Zutaten auf die Liste.
- **Anatomie:** eine `LiquidGlassGroup` 8 pt über der Tab-Bar, Seitenrand `pageMargin`:
  - links getönte Glas-Kapsel (`action`), Mindesthöhe 50: Symbol `cart` 17 pt und Text in `onAction`, `headline`: "17 Zutaten auf Wocheneinkauf"; die Zahl als `RollingNumber`.
  - 8 pt Abstand, rechts runder Glas-Knopf 50 pt (ungetönt) mit dem Listen-Glyph der Ziel-Liste (28 pt, Kreis in Listenfarbe, weißes Symbol).
- **Inhalt der Zahl:** Anzahl der vorausgewählten Zeilen des Sheets "Zutaten der Woche" mit dem Standard-Zeitraum (Kap. 6), also ohne Grundzutaten, ohne schon Vorhandenes, nur noch nicht gesendete Mengen. Nach Änderungen an gesendeten Einträgen zählt sie nur den Unterschied ("2 Zutaten auf Wocheneinkauf").
- **Sichtbar:** auf der Wurzel des Tabs Plan, in der aktuellen und in künftigen Wochen, wenn die Zahl größer 0 ist. Ausgeblendet: Zahl 0, vergangene Woche, offene Tastatur, Bearbeiten-Modus, solange ein `UndoToast` an ihrer Stelle steht (3.2), Sheet in mittlerer oder großer Höhe (dann aus dem Baum genommen, 00 Kap. 8.4).
- **Varianten:** normal; Pro gesperrt (mit `ProBadge` "auf getönt" hinter dem Text, E-02); AX3 und größer (nur "17 Zutaten", 3.7); arbeitet (nach Tippen bis das Sheet steht, kein Indikator nötig, weil das Sheet sofort aus lokalem Stand aufgebaut wird).
- **Bewegung:** Ein- und Ausblenden von unten (Verschiebung 16 pt plus Deckkraft) mit `springStandard`; Zahl rollt mit `springDigits`; gedrückt Skalierung 0,97 (`springQuick`).
- **Barrierefreiheit:** Kapsel "17 Zutaten auf Wocheneinkauf setzen, Taste"; Knopf "Ziel-Liste: Wocheneinkauf, ändern". Bei Pro: Label endet mit ", Pro-Funktion".
- **Fundament:** Diese Leiste fehlt in der Glas-Liste 00 Kap. 8.1 und in der Tönungs-Regel 00 Kap. 8.2 und widerspricht der Regel 01 Kap. 6 ("sonst gibt es keine schwebende Leiste über der Tab-Bar"). Ergänzung E-01. Sie ist die einzige gefüllte Akzent-Kapsel des Screens (00 Kap. 4.2, K-09); "Rezept hinzufügen" bleibt deshalb schlicht.

---

## 5. Sheet "Rezept wählen"

### 5.1 Zweck und Einstieg

- **Hauptfrage:** Welches Rezept kommt auf diesen Tag?
- **Einstieg:** "Rezept hinzufügen" in einem Tag; prominente Aktion im leeren Zustand; Route `/plan/add?day=2026-11-12` (Sheet groß).
- **Besitz:** Die Rezeptauswahl ist laut `arbeitsteilung.md` ein Baustein von Teil A ("`RecipeCard` und die Rezeptauswahl"). Dieses Kapitel legt fest, wie der Plan ihn nutzt; die Komponente selbst fehlt in 00 Kap. 12 und wird als `RecipePicker` ergänzt (E-09).

### 5.2 Aufbau von oben nach unten

1. **Kopf** (`AppSheet`, groß, fest `bgGroupedElevated`): Griff; `xmark` links (Glas); Inline-Titel mittig "Rezept wählen"; rechts nichts (die Auswahl einer Zeile übernimmt sofort).
2. **Tag-Zeile:** Kapsel-Knopf in `fill` mit `calendar` 15 pt, "Für Do., 12. Nov." (`subheadline`, `label`) und `chevron.down` 11 pt; Tippen öffnet ein Menü mit den sieben Tagen der Woche (aktueller Tag mit `checkmark`). So lässt sich der Tag ändern, ohne das Sheet zu schließen.
3. **`SearchField`** im Inhalt: Platzhalter "Rezepte suchen".
4. **`SegmentedControl`** mit zwei Segmenten: "Gespeichert" und "Für dich". Standard: "Gespeichert", wenn es mindestens ein gespeichertes Rezept gibt, sonst "Für dich". Die Wahl wird pro Gerät gemerkt.
5. **Ergebnisse** als `InsetSection` mit `RecipeCard`-Zeilen (Thumbnail 56, Titel `headline`, Metazeile "35 Min · 520 kcal"). Zusatz-Unterzeile, wenn das Rezept in dieser Woche schon geplant ist: "Schon im Plan: Di., 10. Nov." (`labelSecondary`). Allergie-Hinweis wie 4.2.
   - "Gespeichert": gemerkte und eigene Rezepte (auch private; Entwürfe nicht), in Speicherreihenfolge (neueste zuerst). Eigene Rezepte tragen in der Metazeile "von dir".
   - "Für dich": dieselbe Personalisierung wie der Tab Rezepte (Teil A), höchstens 30 Zeilen. **Rezepte mit einem eingetragenen Allergen erscheinen hier nicht** (Responsibility; heute greift der Allergie-Schutz nicht, siehe `inventar/recipes-browse.md` 4.4). In "Gespeichert" und in der Suche erscheinen sie mit Hinweis.
   - Suche (sobald Text im Feld): ersetzt beide Segmente; Segment-Steuerung blendet aus; Sektionen "Gespeichert" (Treffer unter den eigenen) und "Alle Rezepte" (lokaler Cache sofort, Online-Treffer entprellt 300 ms unten angefügt).
6. Unten Inhaltsabstand bis zum Home-Indikator; keine schwebende Leiste.

### 5.3 Beispielinhalt

Für "Do., 12. Nov.", Segment "Gespeichert" (5 Rezepte): Ofengemüse mit Feta ("35 Min · 540 kcal", "Schon im Plan: Di., 10. Nov."), Linsen-Dal mit Spinat ("30 Min · 470 kcal"), Shakshuka ("25 Min · 390 kcal"), Kürbissuppe mit Ingwer ("40 Min · 320 kcal"), Flammkuchen mit Lauch ("30 Min · 680 kcal"). Suche "pas": Sektion "Gespeichert" leer (entfällt), "Alle Rezepte": Pasta Primavera, One-Pot-Pasta mit Tomaten, Pastinaken-Püree.

### 5.4 Zustände

| Zustand | Darstellung |
|---|---|
| Keine gespeicherten Rezepte | Im Segment "Gespeichert" `EmptyState` (im Sheet Maskottchen "zufrieden" 64 pt): Titel "Noch keine gespeicherten Rezepte", Satz "Tippe bei einem Rezept auf das Lesezeichen, dann findest du es hier.", schlichte Aktion "Für dich ansehen" (wechselt das Segment). |
| Keine Treffer | Maskottchen "suchend" 64 pt (ab AX1 Symbol `magnifyingglass` 48 pt Light), "Kein Rezept zu „pas“." |
| Lädt | Gespeichert und Für dich kommen aus dem lokalen Stand (Rezepte-Cache von Teil A); kein Indikator. Online-Suchtreffer erscheinen unten angefügt (`fadeReduced`). |
| Allererstes Laden ohne Rezepte-Cache | Unter Suchfeld und Segment fünf ruhige Zeilenflächen (`fill`, Thumbnail 56 pt, eine Titelzeile), kein Schimmer, höchstens bis zur ersten Antwort; schlägt sie fehl, gilt "Offline". |
| Offline | `StatusRow` unter dem Suchfeld: "Offline. Es werden nur gespeicherte Ergebnisse gezeigt." |
| Fehler | Online-Suche fehlgeschlagen: Zeile am Ende der Ergebnisse "Weitere Rezepte konnten nicht geladen werden. Erneut versuchen". Lokale Treffer bleiben. |
| Modul aus | Sheet nicht erreichbar (Route öffnet das Modul-Sheet). |
| Pro gesperrt | keine Sperre (Planen ist immer frei, W-07). |

### 5.5 Interaktionen, Bewegung, Haptik

- **Tippen auf eine Zeile** legt das Rezept mit den Standard-Portionen (Einstellung, Standard 2) an das Ende des gewählten Tags; das Sheet schließt (`springSheet`), danach wächst die neue Zeile im Tag ein (`springStandard`); liegt der Tag außerhalb des sichtbaren Bereichs, scrollt der Plan zu ihm. Kein Rückgängig-Hinweis, weil das Ergebnis sichtbar ist (00 Kap. 12.28); entfernen geht über das Kontextmenü. Keine Haptik (normale Auswahl).
- **Langdruck auf eine Zeile:** Kontextmenü mit Vorschau des Fotos: "Rezept ansehen" (Push des Rezeptdetails im Sheet, Zurück führt in die Auswahl), "Merken" bzw. "Nicht mehr merken" (`bookmark` / `bookmark.slash`). Mehrere Tage auf einmal gibt es nicht (Menüs mit Mehrfachauswahl und Bestätigen sind kein iOS-Muster); wer dasselbe Rezept zweimal kocht, wählt es zweimal.
- **Segmentwechsel:** Daumen gleitet mit `springQuick`; Inhalt wechselt sofort; Wischen über das Segment mit Auswahl-Haptik (00 Kap. 12.18).
- **Schließen:** Wischen nach unten oder `xmark`; ohne Auswahl passiert nichts (keine Rückfrage).
- **Reduce Motion:** Sheet blendet ein, neue Zeile blendet ein.

### 5.6 Große Schrift und 320 pt

- Tag-Knopf bricht als Kapsel um (Text zweizeilig), nie abgeschnitten.
- Segment-Steuerung: Passt "Gespeichert" / "Für dich" nicht in eine Zeile (ab etwa AX2 bei 320 pt), wird daraus ein Pull-down-Menü (00 Kap. 12.18).
- Rezeptzeilen wie 4.2 (Foto oben bündig ab AX1, entfällt ab AX3).

### 5.7 Was sich gegenüber heute ändert, betroffene Dateien

- Neu. Nutzt Daten von Teil A: `saved_recipes_provider.dart`, `recipes_provider.dart`, `recipe_personalization.dart` (mit korrigiertem Allergie-Ausschluss, Aufgabe von A laut Kapitel 13). Komponente `RecipePicker` (A, E-09) in `lib/presentation/widgets/recipes/`; Aufruf aus dem Plan in `screens/plan/` (B).

### 5.8 Bildbeschreibung für ChatGPT

iPhone-Screenshot (393 × 852 pt), hell: Ein Sheet in voller Höhe liegt über dem leicht verkleinerten, abgedunkelten Wochenplan; das Sheet hat oben einen grauen Griff, links einen runden Glas-Knopf mit "x" und mittig den Titel "Rezept wählen" in fettem Schwarz. Darunter eine hellgraue Kapsel #E9E9EE mit Kalender-Symbol und "Für Do., 12. Nov." und kleinem Pfeil nach unten, darunter ein hellgraues Suchfeld mit Lupe und "Rezepte suchen" in Grau #636366. Darunter eine Segment-Steuerung in Kapselform mit "Gespeichert" (weißer Daumen, ausgewählt) und "Für dich". Der Hintergrund des Sheets ist #F2F2F7, darauf eine weiße Sektion mit Radius 26 und fünf Zeilen, jeweils mit quadratischem Essensfoto 56 pt (Radius 12), fettem Titel und grauer Unterzeile: "Ofengemüse mit Feta" mit "35 Min · 540 kcal" und zweiter Zeile "Schon im Plan: Di., 10. Nov.", "Linsen-Dal mit Spinat" mit "30 Min · 470 kcal", "Shakshuka" mit "25 Min · 390 kcal", "Kürbissuppe mit Ingwer", "Flammkuchen mit Lauch". Dünne graue Trennlinien #C6C6C8 beginnen erst an der Textkante. Keine Tab-Bar sichtbar, kein grüner Knopf im Sheet; ruhige, systemnahe Gestaltung.

---

## 6. Sheet "Zutaten der Woche"

### 6.1 Zweck und Einstieg

- **Hauptfrage:** Was davon muss wirklich auf die Liste?
- **Einstieg:** Tipp auf die Aktionsleiste; Menü `ellipsis` > "Zutaten der Woche"; Avo-Ergebniszeile "Ansehen"; Route `/plan/to-list` (optional `?week=YYYY-MM-DD`).
- **Muster:** `AppSheet`, öffnet mittel, Scrollen im Inhalt zieht es auf groß (Systemverhalten); Hintergrund in Teilhöhe Glas, ab groß fest.

### 6.2 Aufbau von oben nach unten

1. **Kopf:** Griff; `xmark` links; Inline-Titel "Zutaten der Woche". Rechts kein `checkmark`: Die Hauptaktion steht als Knopf unten, wie im Sheet "Zutaten auf Liste" des Rezepts (01 Kap. 10.5), damit beide Sheets gleich funktionieren.
2. **Sektion ohne Titel, zwei Zeilen:**
   - `NavRow` "Liste": führendes Listen-Glyph 28 pt, Titel "Wocheneinkauf", rechts der `StoreChip` "Lidl" (nur Anzeige) und `chevron.up.chevron.down`; Tippen öffnet das Menü "Ziel-Liste" (9.4).
   - Nur in der aktuellen Woche: `SegmentedControl` "Ab heute" / "Ganze Woche" (Standard "Ab heute"). In künftigen Wochen entfällt die Zeile (immer ganze Woche).
3. **Zutaten nach Kategorie**, je eine `InsetSection` mit Kategorie-Titel (`headline`) und Anzahl der ausgewählten (`numberS`, `labelSecondary`) in der Reihenfolge im Markt der Ziel-Liste. Jede Zeile ist eine **Zutaten-Auswahlzeile** (`IngredientPickRow`, E-10):
   - links Auswahl-Kreis: gewählt `checkmark.circle.fill` in `action`, nicht gewählt Ring 1,5 pt in `controlOutline` (wie `PlanRow` der Paywall, 00 Kap. 12.31);
   - Artikelbild 28 pt (Slot `ArticleImage`, abschaltbar, ab AX1 aus);
   - Name (`body`), darunter (`subheadline`, `labelSecondary`) die Herkunft: "für Chili sin Carne, Gemüse-Curry" bzw. ab drei Rezepten "für 3 Rezepte"; bei abgewählten Zeilen statt dessen der Grund: "Schon auf Wocheneinkauf (1 kg)" bzw. "Hast du meist da"; bei ersetzten Zutaten `arrow.left.arrow.right` und "Hafermilch statt Milch · wegen Laktose";
   - rechts die Menge (`number`): "3", "600 g", "2 Dosen", "1 Bund"; darunter mit Modul Angebote das gelbe Schild (`ItemOfferBadge`-Darstellung, nur Markt der Ziel-Liste).
4. **Sektionsfuß der letzten Sektion** (`footnote`, `labelSecondary`): "Grundzutaten wie Mehl und Zucker sind abgewählt. Ändern unter Einstellungen > Wochenplan > Hast du meist da." (Gemeinsame Liste mit dem Rezept-Sheet "Zutaten auf Liste", E-16.)
5. **Ersparnis-Zeile** (nur Modul Angebote, echte PLZ, kein Kill-Switch): `HintRow`-Darstellung ohne Aktion in eigener Sektion: `tag` 16 pt in `labelSecondary`, Text (`callout`, `label`): "3 von 17 Zutaten diese Woche bei Lidl im Angebot, ca. 2,40 € gespart, in deiner Region". Ohne echte PLZ entfällt die Zahl: "Für Angebote in deiner Region: Postleitzahl festlegen" (schlichte Aktion).
6. **Hauptaktion**, am unteren Sheet-Rand angeheftet (in Teilhöhe direkt auf dem Glas-Hintergrund des Sheets, ab groß auf `bgGroupedElevated`), darüber ein weicher Scroll-Edge-Verlauf aus der Sheet-Fläche, keine Linie: `AppButton` prominent "17 Zutaten hinzufügen" (gefüllte Kapsel, kein Glas; Zahl rollt bei jeder Auswahl). Bei 0 gewählten deaktiviert mit "Nichts ausgewählt". Es ist die einzige gefüllte Akzent-Kapsel im Sheet.

### 6.3 Beispielinhalt

Genau die Tabelle aus Kap. 2 (Ab heute, 17 gewählt, Reis, Mehl und Zucker abgewählt). Schilder: Lachsfilet "3,99 €", Kokosmilch "0,89 €", Äpfel "1,99 €". Umschalten auf "Ganze Woche" fügt keine Zeilen für Mo und Di hinzu, weil deren Zutaten schon gesendet sind; nur wenn man dort seither Portionen erhöht hat, erscheint der Unterschied.

### 6.4 Regeln zum Zusammenfassen (Kurzfassung, Details 13.2)

- Gleiche Zutat = gleicher normalisierter Name (Kleinschreibung, Einzahl/Mehrzahl, bekannte Synonyme wie "Zwiebel"/"Zwiebeln", "Knoblauchzehe"/"Knoblauch"); Ersetzungen nach Ernährung werden **vor** dem Zusammenfassen angewendet.
- Mengen gleicher Einheitenfamilie werden umgerechnet und addiert (g und kg, ml und l); "Stück", "Dose", "Bund", "Zehe", "Packung" nur mit sich selbst. Verschiedene Familien bleiben getrennte Zeilen mit gleichem Namen ("Butter · 100 g" und "Butter · 2 EL").
- "EL", "TL", "Prise", "nach Geschmack", "etwas": Die Zeile erscheint ohne Mengenangabe ("Olivenöl") und gilt als Grundzutat, wenn sie auf der Vorratsliste steht.
- Stückzahlen werden aufgerundet (2,5 Zwiebeln → 3), Gewichte und Volumen auf sinnvolle Schritte (unter 100 g auf 10 g, darüber auf 25 g; ml entsprechend).
- Anzeige mit Dezimalkomma und Locale ("1,5 l"), nie "133.333 g" (heutiger Fehler in `select_list_bottom_sheet.dart`, `inventar/recipes-detail.md` 4.2 Punkt 10).
- **Schon auf der Liste:** Gibt es auf der Ziel-Liste einen offenen Artikel mit gleichem Namen und gleicher Einheitenfamilie, ist die Zeile abgewählt mit "Schon auf Wocheneinkauf (1 kg)". Deckt die vorhandene Menge den Bedarf nicht, bleibt sie gewählt mit "2 schon auf Wocheneinkauf" und fügt nur den Rest hinzu.
- **Was der Plan selbst geschickt hat, zählt nicht als vorhanden.** Mengen, die dieser Plan bereits auf die Liste gesetzt hat (Herkunft am Artikel, 13.2), decken nur ihre eigenen Einträge. Beispiel: Die 400 ml Kokosmilch für 3 Portionen Curry stehen auf Wocheneinkauf; erhöht man auf 5 Portionen, erscheint "Kokosmilch · 275 ml" gewählt, nicht "Schon auf Wocheneinkauf". Sonst würden Zwiebeln von Montag die Zwiebeln für Mittwoch "abdecken".

### 6.5 Interaktionen, Bewegung, Haptik

- **Tippen auf eine Zeile** schaltet die Auswahl um; der Kreis füllt sich bzw. leert sich mit `springQuick`; die Zahl im Knopf und im Kategorie-Titel rollt. Zeilen bleiben an ihrem Platz (nichts springt). Keine Haptik.
- **Tippen auf die Menge** oder Langdruck > "Menge ändern" öffnet 6.8 als Push im Sheet.
- **Langdruck:** Kontextmenü "Menge ändern" (`pencil`), "Original verwenden: Milch" (`arrow.uturn.backward`, nur bei ersetzten Zutaten; nimmt für diesen Einkauf die Originalzutat, Unterzeile "Original statt Hafermilch"; ersetzt den heutigen Schalter "Angepasste Zutaten"), "Immer weglassen" (`minus.circle`, setzt die Zutat auf die Liste "Hast du meist da", die Zeile wird abgewählt und ihre Unterzeile lautet 4 s lang "Hast du meist da · Widerrufen" mit schlichter Aktion in `action`; kein schwebender Hinweis, weil das Sheet in Teilhöhe selbst Glas ist), "Rezepte ansehen" (Untermenü mit den Rezepten, Tippen pusht das Detail im Sheet).
- **Zeitraum umschalten:** Zeilen wachsen ein bzw. schrumpfen weg (`springStandard`), Zahlen rollen. Auswahl-Haptik nur beim Wischen über das Segment.
- **Ziel-Liste wechseln:** Abgleich "Schon auf der Liste" und Angebote berechnen sich lokal sofort neu; Schilder anderer Märkte erscheinen nicht (W-10).
- **"17 Zutaten hinzufügen":** Das Sheet schließt sofort (optimistisch); danach Erfolgsmoment und Rückgängig (Kap. 7). Es gibt keinen Fortschritt "3 von 17" und keine Sperre des Sheets (heute: `PopScope` und sequentielles Einfügen, über 10 s). Die Artikel erscheinen sofort auf der Liste mit lokal bestimmter Kategorie; die KI bestätigt Kategorien im Hintergrund unter Einhaltung der 1,1-s-Regel, ohne dass Zeilen springen (00 Kap. 12.4). Zutaten mit Schild übernehmen das Angebot **nur des Markts der Ziel-Liste** an den Artikel (Preis, "laut Händler statt …", Gültigkeit; Darstellung `ItemOfferBadge`); bei Modul aus oder Kill-Switch wird nichts angehängt (heute hängt das Sheet das billigste Angebot irgendeines Händlers an, `inventar/recipes-detail.md` 4.3 Punkt 25). Einen Knopf "Ansehen" gibt es nicht (ein Hinweis, eine Aktion, 00 Kap. 12.28): Ist die Ziel-Liste die Liste von heute, sieht man die Artikel im Tab Liste; sonst zeigt die Startseite "Zutaten für heute stehen auf Wocheneinkauf · Öffnen" (10.2).
- **Schließen ohne Hinzufügen:** Wischen nach unten oder `xmark`. Geänderte Auswahl wird nicht gespeichert und erzeugt keine Rückfrage (W-06): Beim nächsten Öffnen gilt wieder die Vorauswahl. Ausnahme: "Immer weglassen" und "Menge ändern" bleiben gespeichert, weil sie eigene Aktionen mit Rückgängig sind.

### 6.6 Zustände

| Zustand | Darstellung |
|---|---|
| Nichts zu tun | Kann nur über das Menü erreicht werden (die Leiste ist dann weg). `EmptyState` im Sheet: Symbol `checkmark.circle` 48 pt Light, Titel "Alles ist auf der Liste", Satz "Die Zutaten für diese Woche stehen auf Wocheneinkauf." Schlicht "Wocheneinkauf öffnen". |
| Keine Liste vorhanden | Zeile "Liste" zeigt "Neue Liste" in `action`; Tippen zieht "Zutaten der Woche" auf groß (feste Fläche) und öffnet darüber das Sheet "Neue Liste" (Teil A, zweites und letztes Sheet im Stapel, 01 Kap. 6), Vorschlag "Wocheneinkauf"; nach dem Anlegen schließt es, die neue Liste steht in der Zeile, weiter wie oben. Keine Sackgasse (heutiger Fehler "Noch keine Listen" ohne Aktion). |
| Lädt | Sofort aus lokalem Stand (Plan, Rezepte-Cache, offene Artikel der Ziel-Liste). Angebote kommen aus dem Angebots-Cache von Teil B; fehlen sie, erscheinen Schilder nicht nachträglich in sichtbaren Zeilen, sondern erst beim nächsten Öffnen (00 Kap. 13, nachladende Inhalte). |
| Rezept ohne Zutaten-Daten | Zeile in eigener Sektion "Ohne Zutatenliste": "Flammkuchen mit Lauch · Zutaten fehlen im Rezept", ohne Auswahl-Kreis. |
| Offline | `StatusRow` oben: "Offline. Die Zutaten werden hinzugefügt, sobald du wieder online bist." Hinzufügen funktioniert (Warteschlange); Schilder nur aus dem Cache, sonst entfallen sie. |
| Fehler nach dem Hinzufügen | Schlägt das Senden endgültig fehl, rollt die Liste die betroffenen Artikel zurück; im Plan erscheint unter der Metazeile die `StatusRow` "2 Zutaten konnten nicht hinzugefügt werden. Erneut versuchen" (fest, kein Glas), die betroffenen Einträge verlieren "Auf Wocheneinkauf", die Aktionsleiste zählt sie wieder; Fehler-Haptik. Teil-Erfolg nennt die Namen ("Dill und Koriander"). |
| Modul Angebote aus / Kill-Switch | Schilder und Ersparnis-Zeile fehlen ohne Lücke; Markt-Chip in der Listen-Zeile bleibt. |
| Modul Kalorien aus | keine Änderung (das Sheet zeigt keine kcal). |
| Pro gesperrt | Das Sheet ist erst nach dem Kauf erreichbar (Leiste öffnet die Paywall). Über das Menü `ellipsis` > "Zutaten der Woche" öffnet sich ebenfalls die Paywall, nicht das Sheet. |

### 6.7 Große Schrift und 320 pt

- Menge und Schild rutschen ab AX1 unter den Namen (wie `ItemRow`, 00 Kap. 12.8), der Kreis bleibt oben bündig zur ersten Zeile.
- Listen-Zeile: Markt-Chip bricht unter den Listennamen.
- Segment "Ab heute" / "Ganze Woche" wird bei Platzmangel zum Pull-down-Menü.
- Hauptknopf bricht um und wächst in der Höhe; "17 Zutaten hinzufügen" bleibt vollständig.

### 6.8 "Menge ändern" (Push im Sheet)

- **Hauptfrage:** Wie viel brauche ich davon?
- **Warum Push statt zweitem Sheet:** Ein zweites Sheet in Teilhöhe läge als Glas auf dem Glas-Sheet. Stattdessen zieht "Zutaten der Woche" auf groß (feste Fläche `bgGroupedElevated`) und die Seite schiebt sich von rechts hinein (`CupertinoPageRoute`, Zurück-Wischen folgt 1:1), wie "Reihenfolge im Markt" in der Listen-Info (01 Kap. 2.3).
- **Aufbau:** Kopf `chevron.left` (Glas, "Zurück zu Zutaten der Woche") / Inline-Titel "Zwiebeln" / `checkmark` (getönt, übernimmt, K-30). Sektion "Menge": `ValueStepper` (normale Größe) und daneben ein Zahlenfeld (`fill`, Kapsel, `number`, Ziffern-Tastatur). Sektion "Einheit": `FilterChip`s ("Stück", "g", "kg", "Bund"; nur sinnvolle für die Zutat, gewählte mit `checkmark`). Sektionsfuß "Berechnet: 3 für 2 Rezepte".
- **Verhalten:** `checkmark` setzt die Menge nur für diesen Einkauf (nicht im Rezept) und kehrt zurück; die Zeile zeigt danach "4" mit Unterzeile "angepasst" (kein "3 → 4"). Die Anpassung bleibt bis zum Hinzufügen gespeichert, auch wenn das Sheet zwischendurch geschlossen wird (W-06). Zurück ohne `checkmark` verwirft ohne Rückfrage. Stepper mit Auswahl-Haptik.
- **Zustände:** Eingabe 0 oder leer: `checkmark` deaktiviert (`labelTertiary`); offline wie überall (lokal).
- **AX/320:** Chips umbrechen (`Wrap`); Stepper und Feld untereinander ab AX1; Tastatur hebt den Inhalt, der Kopf bleibt stehen.

### 6.9 Was sich gegenüber heute ändert, betroffene Dateien

- Neu (B): `screens/plan/widgets/plan_to_list_sheet.dart`, `plan_quantity_page.dart` (Push im Sheet).
- Ersetzt für den Plan die Logik aus `lib/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart` (zentrierter Dialog, sequentielles `ItemRepository.addItem` pro Zutat, Fortschritt "Füge 3 von 12 hinzu", unformatierte Mengen, Angebote des billigsten Händlers statt des Listen-Markts).
- Braucht von A: den Dienst `RecipeToList` (13 Kap. 13.7, dort E-07) mit Stapel-API `ItemRepository.addItems(...)`, erweitert um mehrere Rezepte und die Herkunft "aus dem Plan" (E-11). `item_merge_service.dart`, auf den `prompt-teil-B.md` B7 verweist, existiert im Repo nicht; das heutige Zusammenführen steckt nur in `ItemRepository.addItem` nach Name und exakter Einheit, `unit_conversion_service.dart` wurde gelöscht. Ersetzungen kommen aus `RecipeAdaptation` (A). `IngredientPickRow` (E-10) teilt sich der Plan mit dem Rezept-Sheet 01 Kap. 10.5.

Abdeckung der heutigen Funktionen von `select_list_bottom_sheet.dart` (`inventar/recipes-browse.md` 2.x, `inventar/recipes-detail.md` 2.3), soweit der Plan sie nutzt:

| Heute | Im Plan |
|---|---|
| Liste wählen (Schritt A) | Zeile "Liste" mit Menü 9.4; Standard aus den Einstellungen |
| Portionen im Sheet | Portionen pro Eintrag im Plan (Stepper); das Sheet rechnet sie zusammen |
| Schalter "Angepasste Zutaten" an/aus | Ersetzung nach Einstellung automatisch; pro Zutat "Original verwenden" im Kontextmenü (6.5) |
| Zusammenfassung "12 Zutaten · 4 Portionen" mit Pillen "n im Angebot", "n angepasst" | Zahl im Hauptknopf, Zähler pro Kategorie, Schilder an den Zeilen, Ersparnis-Zeile; Pillen entfallen (Doppelung) |
| Zutatenliste max. 220 pt hoch | ganze Liste im Sheet, Sheet zieht auf groß |
| Angebotspreis an den Listeneintrag hängen | nur Angebot des Markts der Ziel-Liste (6.5) |
| Fortschritt "Füge 3 von 12 hinzu", Sperre | entfällt; optimistisch, ein Stapel-Aufruf |
| Teil-Erfolg mit Namen der fehlgeschlagenen Zutaten | bleibt: `StatusRow` "Dill und Koriander konnten nicht hinzugefügt werden. Erneut versuchen" (6.6) |
| Erfolgs-HUD 120 × 120 und "Ansehen" | `SuccessMoment` beim ersten Senden der Woche, sonst `UndoToast` (Kap. 7); "Ansehen" entfällt (6.5) |
| "Noch keine Listen" ohne Aktion | "Neue Liste" in der Zeile (6.6) |
| Übersetzungsschlüssel `premium_feature_meal_planning` ("KI Essensplanung") | entfällt; Pro-Eintrag `meal_plan` nur, falls der Plan Pro wird (Kap. 18) |
- Angebote: `RecipeOfferService` / Angebots-Cache (B) mit Markt-Filter auf den Markt der Ziel-Liste (heute `pickBestOffer` über alle Händler, `inventar/recipes-detail.md` 4.3 Punkt 22).

### 6.10 Bildbeschreibung für ChatGPT

iPhone-Screenshot (393 × 852 pt), hell: Über dem leicht verkleinerten, abgedunkelten Wochenplan liegt ein Sheet, das auf volle Höhe gezogen ist: fester Hintergrund #F2F2F7, oben Ecken passend zur Geräteecke; oben ein grauer Griff, links ein runder, milchiger Glas-Knopf "x", mittig der fette Titel "Zutaten der Woche" in Schwarz #000000. Darunter eine weiße Sektion #FFFFFF mit Radius 26 mit zwei Zeilen: links ein blauer Kreis #007AFF mit weißem Einkaufswagen, "Wocheneinkauf", rechts eine hellgraue Kapsel #E9E9EE mit einem 8-pt-Punkt in Lidl-Blau #0050AA und "Lidl"; zweite Zeile eine Segment-Steuerung "Ab heute" (ausgewählt) / "Ganze Woche". Dann die Sektion "Obst & Gemüse" mit grauer Zahl "9" rechts: Zeilen mit grünem gefülltem Häkchen-Kreis #3F7A1F links, Name in Schwarz und grauer Unterzeile, Menge rechts: "Zwiebeln" · "für Chili sin Carne, Gemüse-Curry" · "3"; "Kartoffeln" · "600 g"; "Äpfel" · "4" mit kleinem gelbem Preisschild #FFD60A "1,99 €" in dunkler Schrift #1C1C1E. Sektionstitel in fettem Schwarz, gemischte Schreibweise, Unterzeilen in Grau #636366, Trennlinien #C6C6C8 ab der Textkante. Weiter unten in der Sektion "Vorrat" die Zeile "Reis" mit leerem grauem Ring #8A8A8E und Unterzeile "Schon auf Wocheneinkauf (1 kg)". Am unteren Rand des Sheets, über einem weichen Verlauf in #F2F2F7, ein breiter grüner Kapsel-Knopf #3F7A1F mit weißer halbfetter Schrift "17 Zutaten hinzufügen". Keine Tab-Bar sichtbar, keine Prozent-Rabatte, keine Marktvergleiche, keine Großbuchstaben, kein Maskottchen.

---

## 7. Erfolgsmoment und Rückgängig

### 7.1 Zweck

Bestätigt den Aha-Moment des Plans ("ein Tipp, alles auf der Liste") und macht ihn umkehrbar.

### 7.2 Wann er erscheint

Der Erfolgsmoment gehört zum **ersten Senden einer Woche** auf die Liste (E-15). Jedes weitere Senden derselben Woche (später ergänzte Rezepte, mehr Portionen, "Hinzufügen" aus der Hinweis-Zeile) zeigt nur den `UndoToast`. Grund: Ein Fest bei jeder Ergänzung nutzt sich ab (00 Kap. 12.35, "einmal pro Ereignis"). In der Beispielwoche war das erste Senden am Sa., 7. Nov. (14.1, Schritt 5: 9 Zutaten für Mo. und Di.); das Senden der 17 Zutaten am Mi., 11. Nov. zeigt nur den Hinweis.

### 7.3 Ablauf und Aufbau (Beispiel Sa., 7. Nov., Woche 9.–15. Nov.)

1. Das Sheet "Zutaten der Woche" schließt (`springSheet`).
2. Erst danach erscheint der `SuccessMoment` (00 Kap. 12.35) mittig über dem Plan: Maskottchen "feiernd" 120 pt, `title2` "Wochenplan ist auf der Liste.", Unterzeile (`subheadline`, `labelSecondary`) "9 Zutaten zu Wocheneinkauf". Mit Modul Angebote, echter PLZ und mindestens einem Treffer zusätzlich die Zahl der Angebote, z. B. "2 davon bei Lidl im Angebot, laut Händler" (keine Euro-Summe neben dem Maskottchen, 00 Kap. 3.3 "nie bei Geld"; die Ersparnis steht im Sheet und in der Liste). Skalierung aus 0,9 mit `springCelebrate`, Erfolgs-Haptik im selben Frame, 1,5 s, Tippen schließt.
3. **Gleichzeitig** mit dem Erfolgsmoment erscheint der `UndoToast` an der Stelle der Aktionsleiste (3.2): "9 Zutaten zu Wocheneinkauf · Widerrufen", 4 s (VoiceOver 10 s). So ist Widerrufen sofort erreichbar und nicht erst nach dem Fest. Glasflächen in diesem Moment: Tab-Bar, Toolbar, Hinweis = 3.
4. Im Plan bekommen die Rezeptzeilen von Mo. und Di. die Metazeile "`checkmark` Auf Wocheneinkauf" (blendet ein); die Aktionsleiste ist ausgeblendet, weil nichts mehr fehlt.
5. **Widerrufen** entfernt genau die neu angelegten Artikel und setzt erhöhte Mengen bestehender Artikel zurück (eine Rückgängig-Kennung aus `addItems`, E-11); die Plan-Einträge verlieren die Markierung; die Leiste erscheint wieder mit "9". Ein späteres Senden derselben Woche zeigt dann wieder den Erfolgsmoment, weil das erste Senden zurückgenommen ist.
6. Mitglieder der Ziel-Liste (Lena) sehen die neuen Artikel live; eine gebündelte Mitteilung "Jannis hat 9 Artikel zu Wocheneinkauf hinzugefügt" (00 K-39, Kapitel 19).
7. **Erstes Mal überhaupt:** Nach dem ersten Wochenplan auf der Liste erscheint am nächsten Öffnen der Startseite einmalig die Hinweis-Zeile mit dem Pro-Angebot (00 Kap. 16.4, 10-heute Hinweis Nr. 9), sofern noch keine Testphase lief und der Pro-Status bekannt ist. Nicht als Pop-up.

### 7.4 Zustände

- **Reduce Motion:** Erfolgsmoment nur Einblenden; Toast überblendet.
- **VoiceOver:** Ansage "Wochenplan ist auf der Liste. 9 Zutaten zu Wocheneinkauf." statt visueller Dauer; der Toast bekommt den Fokus nicht automatisch, "Widerrufen" ist über den Rotor und als Aktion der Ansage erreichbar.
- **Offline:** gleicher Ablauf; die Artikel tragen auf der Liste das Sync-Zeichen. Schlägt das Senden später endgültig fehl, gilt 6.6 "Fehler nach dem Hinzufügen".
- **Weiteres Senden derselben Woche:** kein Erfolgsmoment, nur der Toast, z. B. "17 Zutaten zu Wocheneinkauf · Widerrufen" (Mi., 11. Nov.) bzw. "5 Zutaten zu Wocheneinkauf · Widerrufen" (14.3).
- **Ab AX1:** Maskottchen entfällt nicht (Erfolgsmoment ist kein leerer Zustand), wird aber auf 96 pt begrenzt; der Text bricht um. Reicht die Höhe nicht (AX5 auf 320 pt), entfällt das Maskottchen, Text und Haptik bleiben.

### 7.5 Bildbeschreibung für ChatGPT

iPhone-Screenshot (393 × 852 pt), hell: Im Hintergrund der Wochenplan "Nächste Woche · 9.–15. Nov." auf #F2F2F7 mit weißen Tagessektionen #FFFFFF (Radius 26); unter "Spaghetti mit Linsen-Bolognese" (Mo., 9. Nov.) und "Ofengemüse mit Feta" (Di., 10. Nov.) jeweils eine graue Zeile #636366 mit kleinem Häkchen "Auf Wocheneinkauf". In der Mitte des Bildschirms, ohne Karte und ohne Rahmen, eine flach gezeichnete, fröhlich springende Avocado-Hälfte mit braunem Kern und kurzen Ärmchen (zwei Tonstufen Grün #C3D867 und #3F7A1F, Kern #7A4A24), darunter in fettem Schwarz #000000 "Wochenplan ist auf der Liste." und in Grau #636366 "9 Zutaten zu Wocheneinkauf". Unten, 8 pt über der milchigen Glas-Tab-Bar (Plan grün #3F7A1F ausgewählt, rechts der Avo-Kreis mit brauner Kugel #7A4A24 in hellgrünem Ring #C9DE6E), eine schmale milchige Glas-Kapsel mit "9 Zutaten zu Wocheneinkauf" in Schwarz und rechts "Widerrufen" in Avocado-Grün #3F7A1F; keine grüne Aktionsleiste. Kein Konfetti, keine Emojis, kein Ausrufezeichen, kein Euro-Betrag.

---

## 8. "Zum Wochenplan" (aus dem Rezeptdetail)

### 8.1 Zweck und Einstieg

- **Hauptfrage:** An welchem Tag koche ich das?
- **Einstieg (abgestimmt mit 13 Kap. 18.1):** Rezeptdetail (Teil A) > Toolbar `ellipsis` > "Zum Wochenplan" (`calendar`) als **Untermenü**, das wie in iOS das Menü an derselben Stelle ersetzt (Kopfzeile "Zum Wochenplan" mit `chevron.left`; keine zweite Glasfläche über der ersten); ebenso im Kontextmenü einer `RecipeCard` (13 Kap. 5); nur mit Modul Wochenplan (00 Kap. 15.1). Avo nutzt `add_to_plan` (13.4).
- **Untermenü:** die nächsten sieben Tage ab heute ("Heute, Mi., 11. Nov.", "Morgen, Do., 12. Nov.", "Fr., 13. Nov." … "Di., 17. Nov."), je mit den schon geplanten Rezepten als Untertitel des Menüeintrags ("Chili sin Carne"); Trenner; "Anderes Datum…" (`calendar.badge.plus`).
- **Ein Tipp auf einen Tag** legt das Rezept mit der Portionenzahl an, die im Detail gerade eingestellt ist (sonst Standard aus den Einstellungen), über die B-Schnittstelle `addRecipeToPlan(recipeId, day, servings)` (13 E-07). Das Menü schließt, `UndoToast` "Auf Do., 12. Nov. im Wochenplan · Widerrufen" (Wortlaut aus 13 Kap. 18.1; das Ergebnis ist hier nicht sichtbar, daher Hinweis). Keine Haptik (einfaches Planen ist kein Erfolgsereignis). Die Metazeile "Im Plan: Do., 12. Nov. · 2 Portionen" erscheint danach unter dem Titel des Details (E-07).
- **"Anderes Datum…"** öffnet das Sheet 8.2 (Route `/recipes/:recipeId/to-plan`, auch für Avo-Ergebniszeilen und Deep Links). Inhalt von Teil B, der Menüeintrag ist ein Slot von A.

### 8.2 Sheet "Anderes Datum" (Sheet mittel)

1. Kopf: `xmark` links, Inline-Titel "Zum Wochenplan" mittig, `checkmark` rechts (getönt, übernimmt, K-30).
2. Rezept als `RecipeCard`-Zeile (Thumbnail 56, Titel "Ofengemüse mit Feta", "35 Min · 540 kcal"), nicht antippbar.
3. Sektion "Tag": System-Datumswähler in der Kalender-Darstellung (inline, Monatsblatt, `action` als Auswahlfarbe), wählbar von 52 Wochen zurück bis 52 Wochen voraus (wie die Wochen im Tab Plan). Vorausgewählt: der erste freie Tag nach den sieben Tagen des Untermenüs. Darunter eine Zeile mit den an diesem Tag schon geplanten Rezepten ("Schon geplant: Chili sin Carne") oder "Noch nichts geplant" (`subheadline`, `labelSecondary`).
4. Sektion "Portionen": `ValueStepper` normal (1 bis 20), vorbelegt wie oben.
5. Sektionsfuß: "Die Zutaten kommen erst auf die Liste, wenn du sie im Wochenplan hinzufügst."

### 8.3 Verhalten und Zustände

- `checkmark`: legt den Eintrag an, Sheet schließt, `UndoToast` "Auf Mo., 23. Nov. im Wochenplan · Widerrufen". Keine Haptik.
- Schließen ohne Auswahl ohne Rückfrage (es gibt nichts zu verlieren).
- Steht das Rezept schon in derselben Woche, zeigt die Rezeptzeile die Unterzeile "Schon im Plan: Di., 10. Nov." (kein Verbot, man darf zweimal dasselbe kochen).
- **Zustände:** offline wie überall (lokal, Warteschlange, Sync-Zeichen im Plan); Modul aus: Menüeintrag fehlt, Route öffnet das Modul-Sheet; Pro gesperrt: frei (W-07); Rezept nicht mehr verfügbar (Deep Link auf gelöschtes Rezept): Sheet zeigt im Layout des leeren Zustands "Rezept nicht mehr verfügbar" ohne `checkmark`.
- **AX/320:** Der Kalender ist für große Schrift zu dicht; ab AX1 ersetzt ihn der kompakte System-Datumswähler (eine Zeile "Mo., 23. Nov." mit Menü); das Sheet öffnet ab AX1 gleich groß; Stepper ab AX1 in eigener Zeile unter "Portionen". Untermenü-Einträge brechen wie Systemmenüs um.
- **Betroffene Dateien:** neu `screens/plan/widgets/add_to_plan_sheet.dart` und `addRecipeToPlan` in `plan_provider.dart` (B); Menüeintrag mit Untermenü im Rezeptdetail und in Rezept-Kontextmenüs (A, per Anfrage, E-07).

### 8.4 Bildbeschreibung für ChatGPT

iPhone-Screenshot (393 × 852 pt), hell: Ein Rezeptdetail mit großem randlosem Foto (Ofengemüse mit Feta) oben; oben rechts eine milchige Glas-Knopfgruppe mit drei Punkten. Aus dem Drei-Punkte-Knopf ist ein einziges milchiges Glas-Menü gewachsen, das gerade das Untermenü zeigt: Kopfzeile mit kleinem Pfeil nach links und fett "Zum Wochenplan", darunter Zeilen in Schwarz #000000 und grauen Untertiteln #636366: "Heute, Mi., 11. Nov." (Untertitel "Chili sin Carne"), "Morgen, Do., 12. Nov.", "Fr., 13. Nov." (Untertitel "Lachs mit Ofenkartoffeln"), "Sa., 14. Nov." (Untertitel "Gemüse-Curry mit Reis, Apfel-Crumble"), "So., 15. Nov.", "Mo., 16. Nov.", "Di., 17. Nov.", nach einem schmalen Trennband "Anderes Datum…" mit Kalender-Plus-Symbol. Der Rest des Bildschirms ist leicht abgedunkelt. Keine Icons in farbigen Quadraten, keine Großbuchstaben, kein Maskottchen.

---

## 9. Menüs

Alle als `AppMenu` (00 Kap. 12.24), wachsen aus dem Auslöser mit `springMenu`, Glas nur solange offen.

### 9.1 Wochen-Menü (aus der Metazeile)

Einträge: "Diese Woche" (mit `checkmark`, wenn gewählt), "Nächste Woche", "Letzte Woche"; Trenner; die nächsten vier Wochen mit Datum ("KW 48 · 23.–29. Nov."); Trenner; "Datum wählen…" (System-Datumswähler, springt in die Woche des Tages).

### 9.2 Menü `ellipsis` (Toolbar)

1. "Zutaten der Woche" (`cart`), auch wenn nichts fehlt (dann leerer Zustand 6.6).
2. "Rezepte der Vorwoche übernehmen" (`doc.on.doc`), nur wenn die Vorwoche Einträge hat.
3. "Bearbeiten" (`pencil`).
4. Trenner. "Woche leeren" (`trash`, `danger`): sofort, `UndoToast` "Woche geleert · Widerrufen" (umkehrbar, daher keine Rückfrage, W-08).
5. Trenner. "Wochenplan-Einstellungen" (`gearshape`, E-12), öffnet `/settings/plan`.

### 9.3 Kontextmenü einer Rezeptzeile

Kopf: Foto-Vorschau mit Titel. Einträge: "Rezept ansehen" (`book`), "Kochen" (`frying.pan`, öffnet den Kochmodus `/recipes/:id/cook` mit den Plan-Portionen; trägt `ProBadge`, falls der Kochmodus Pro ist, F-10), "Auf anderen Tag" (`calendar`, Untermenü mit den sieben Tagen und "Nächste Woche…"), "Ins Tagebuch" (`flame`, nur Modul Kalorien, öffnet `showLogRecipeSheet` mit 1 Portion und dem Tag des Eintrags), "Mahlzeit" (`fork.knife`, nur Modul Kalorien, Untermenü Frühstück, Mittagessen, Abendessen, Snack, Standard keine Angabe = Abendessen), Trenner, "Entfernen" (`trash`, `danger`, sofort mit `UndoToast`).

### 9.4 Menü "Ziel-Liste" (Glyph-Knopf der Aktionsleiste und Listen-Zeile im Sheet)

Alle Listen als Menüzeilen (`ListRow`-Variante Menü: Glyph, Name, offene Anzahl rechts), aktuelle mit `checkmark`; Trenner; "Neue Liste" (`plus`). Die Wahl gilt für diese Woche (gespeichert am Plan); Standard für neue Wochen kommt aus den Einstellungen.

---

## 10. Startseite: "Heute im Plan"

### 10.1 Zweck und Ort

- **Hauptfrage der Zeile:** Was koche ich heute, und habe ich alles?
- **Ort:** Hinweis-Zeile (`HintRow`, 00 Kap. 12.12) in der Sektion "Für heute" ganz oben im Tab Liste. Widget von Teil B (`PlanTodayHint` in `screens/plan/widgets/`), Anordnung durch Teil A (`home_nudge_card_order.dart`). Höchstens zwei Hinweis-Zeilen insgesamt (K-38); welche, steht beim ersten Frame aus dem Cache fest.

### 10.2 Varianten

| Variante | Text (`callout`, `label`) | Aktion rechts | Tippen auf die Zeile |
|---|---|---|---|
| Heute geplant, Zutaten auf der Liste oder schon gekauft | "Heute im Plan: Chili sin Carne." (mit Modul Kalorien: "Heute im Plan: Chili sin Carne · 480 kcal.") | `chevron.right` | Rezeptdetail im Tab Plan mit Plan-Portionen (`/plan/recipe/:id?entry=`), Stapel Plan-Wurzel + Detail |
| Heute geplant, Zutaten fehlen auf der Liste | "Heute im Plan: Chili sin Carne. 7 Zutaten fehlen noch." Bei einer oder zwei fehlenden Zutaten stehen die Namen: "… Koriander und Paprika fehlen noch." (Wortlaut wie 10-heute, Hinweis Nr. 3) | schlicht "Hinzufügen" (fügt genau diese Zutaten zur Ziel-Liste des Plans hinzu, `UndoToast` "7 Zutaten zu Wocheneinkauf · Widerrufen", Zeile wechselt in Variante 1) | wie oben |
| Heute geplant, Zutaten auf einer anderen Liste als der angezeigten | "Zutaten für heute stehen auf Wocheneinkauf." (01 Kap. 2.2) | schlicht "Öffnen" (wechselt die Liste von heute, Überblendung) | wie Aktion |
| Ab 20 Uhr und morgen geplant | "Morgen im Plan: Lachs mit Ofenkartoffeln." bzw. mit fehlenden Zutaten "… 4 Zutaten fehlen noch." | `chevron.right` bzw. schlicht "Hinzufügen" | Detail wie oben |
| Sonntag ab 16 Uhr, nächste Woche leer, Plan in den letzten 4 Wochen benutzt | "Nächste Woche ist noch leer" | schlicht "Planen" (Tab Plan, nächste Woche) | wie Aktion |
| Nichts geplant | keine Zeile | – | – |

- Symbol links: `calendar` 16 pt in `labelSecondary`.
- **Ausblenden:** Wischen nach links "Ausblenden" (für heute), Kontextmenü "Heute ausblenden" / "Nicht mehr zeigen" (schaltet in den Einstellungen "Heute im Plan zeigen" aus, mit Rückgängig) und "Wochenplan öffnen" (`calendar`, wie 10-heute).
- **Zustände:** Modul aus: Zeile entfällt ohne Lücke. Offline: Variante 1 bzw. 2 aus dem lokalen Stand; "Hinzufügen" geht in die Warteschlange. Pro gesperrt (nur falls "auf die Liste" Pro wird): "Hinzufügen" bleibt sichtbar und trägt davor die `ProBadge` (wie 10-heute, Zustand "Pro gesperrt"); Tippen öffnet die Paywall, die aus der Zeile wächst; nach dem Kauf laufen die Zutaten auf die Liste. Pro-Status unbekannt: keine Badge, "Hinzufügen" wie normal und erst beim Tippen prüfen.
- **AX/320:** Text bis 3 Zeilen; die Aktion rutscht ab AX1 unter den Text (Taste über die volle Breite).
- **VoiceOver:** "Heute im Plan: Chili sin Carne. 7 Zutaten fehlen noch. Taste"; eigene Aktionen "Hinzufügen", "Ausblenden".
- **Was sich ändert:** Neu. Ersetzt keine heutige Karte; nimmt den Platz einer der heutigen sechs Karten ein (01 Kap. 5.2). `CalorieRecipeNudgeCard` (Kalorien-Ideen) wird nicht gezeigt, wenn für heute ein Rezept geplant ist (Abstimmung mit Kap. 15).

### 10.3 Bildbeschreibung für ChatGPT

iPhone-Screenshot (393 × 852 pt), hell, Tab Liste: oben der große fette Titel "Wocheneinkauf" mit kleinem grauem Pfeil nach unten, rechts ein runder Profil-Avatar, darunter eine hellgraue Kapsel #E9E9EE mit blauem Punkt #0050AA und "Lidl". Hintergrund #F2F2F7. Darunter die Sektion "Für heute" mit fettem schwarzem Titel und einer weißen Fläche #FFFFFF (Radius 26) mit einer Zeile: links ein graues Kalender-Linien-Symbol #636366, Text in Schwarz #000000 "Heute im Plan: Chili sin Carne. 7 Zutaten fehlen noch.", rechts "Hinzufügen" in Avocado-Grün #3F7A1F ohne Fläche. Darunter beginnen die Gänge der Einkaufsliste ("Obst & Gemüse" mit grauer "3") mit weißen Artikelzeilen und leeren grauen Abhak-Kreisen #8A8A8E. Unten schwebt die milchige Glas-Kapsel "Artikel hinzufügen" mit Plus und daneben die grün getönte Glas-Kapsel #3F7A1F "Einkaufen" mit Einkaufswagen über der Glas-Tab-Bar ("Liste" grün ausgewählt, "Rezepte", "Plan", rechts der Avo-Kreis mit brauner Kugel #7A4A24 in hellgrünem Ring #C9DE6E). Kein Banner, keine Karte mit Bild, kein Maskottchen, nur diese eine ruhige Zeile.

---

## 11. Verbindung zu Kalorien (nur Modul Kalorien)

1. **kcal pro Tag im Plan:** Summe der kcal pro Portion aller Rezepte des Tages (eine Portion je Rezept, also pro Person), rechts im Tageskopf (`numberS`, `labelSecondary`). Rezepte ohne Nährwerte zählen nicht; fehlt mindestens einer, steht "ab 480 kcal" und der Sektionsfuß nennt "Für Apfel-Crumble fehlen Nährwerte." Keine Farbe, keine Bewertung gegen das Tagesziel im Plan (der Plan zeigt meist nur eine Mahlzeit; ein Vergleich mit 2.000 kcal wäre irreführend, W-09).
2. **Mahlzeit pro Eintrag:** optional über das Kontextmenü (9.3); bestimmt, in welche Mahlzeit "Ins Tagebuch" einträgt. Standard Abendessen.
3. **Im Tab Kalorien (Kapitel 15, Teil B):** In der Mahlzeit des Eintrags erscheint am Plan-Tag eine Vorschlagszeile im Stil "Vielleicht auch" (gestrichelter Kreis mit `plus`): "Aus dem Plan: Chili sin Carne · 480 kcal", Tippen trägt 1 Portion ein (Rückgängig-Hinweis), Langdruck öffnet das Sheet "Ins Tagebuch" mit Portionen in 0,5er-Schritten. Schnittstelle: `planEntriesForDayProvider(date)` von Teil B (E-13).
4. **"Was kann ich heute noch essen?"** berücksichtigt geplante, noch nicht eingetragene Rezepte des Tages nicht als gegessen; es zeigt oben eine Zeile "Heute im Plan: Chili sin Carne · passt mit 480 kcal" bzw. "· 120 kcal über deinem Rest" (`warning` mit Symbol), damit der Plan nicht verdrängt wird.
5. **Startseite:** Variante 1 der Hinweis-Zeile nennt die kcal (10.2); die Hinweis-Zeile "Noch 640 kcal heute · Ideen" erscheint nicht, wenn für heute ein Rezept geplant ist (keine zwei Essens-Hinweise gleichzeitig).
6. **Modul Kalorien aus:** Alle Punkte entfallen ohne Lücke; Mahlzeit-Angaben bleiben gespeichert, werden aber nicht angezeigt.

---

## 12. Einstellungen Wochenplan

### 12.1 Seite `/settings/plan` (Push im Sheet "Profil", Teil B)

- **Hauptfrage:** Wie soll der Plan standardmäßig arbeiten?
- **Aufbau:**
  1. `LargeTitleNavBar` Push erste Ebene, Titel "Wochenplan".
  2. Sektion "Standard": Zeile "Portionen" mit kompaktem `ValueStepper` im rechten Slot (E-03; Standard 2; 1 bis 20 wie im Plan und im Rezeptdetail); `NavRow` "Ziel-Liste" mit Wert "Liste von heute" bzw. Listenname (Auswahlseite mit Zeile "Liste von heute" und allen Listen).
  3. Sektion "Zutaten": `NavRow` "Hast du meist da" mit Wert "6" (Seite 12.2). Sektionsfuß: "Diese Zutaten sind abgewählt, wenn du Zutaten aus dem Wochenplan oder aus einem Rezept auf die Liste setzt."
  4. Sektion "Startseite": `ToggleRow` "Heute im Plan zeigen" (Standard an).
  5. Sektion "Mitteilungen": `ToggleRow` "An die nächste Woche erinnern" (Standard aus), darunter bei an `NavRow` "Wann" mit Wert "Sonntag, 18:00" (öffnet ein Menü mit den Wochentagen und den kompakten System-Zeitwähler) (Mitteilung "Nächste Woche ist noch leer. Jetzt planen?"; nur wenn die nächste Woche leer ist). Erst beim Einschalten die Vorab-Erklärung und Systemabfrage für Mitteilungen (00 Kap. 13).
  6. Sektion ohne Titel: `NavRow` "Module" mit Unterzeile "Wochenplan ausschalten" (führt zu `/settings/modules`).
- **Zustände:** lokal sofort; Änderungen gelten sofort und synchronisieren über das Konto; offline mit Sync-Zeichen; Modul aus: Seite nicht erreichbar (Zeile im Profil fehlt).
- **AX/320:** Werte rutschen unter die Titel (`NavRow` stapelt ab AX1).

### 12.2 Seite "Hast du meist da" (`/settings/plan/pantry`)

- **Hauptfrage:** Was soll beim Hinzufügen zur Liste abgewählt sein?
- `LargeTitleNavBar` Push zweite Ebene, Inline-Titel "Hast du meist da". Oben ein Feld "Zutat hinzufügen" (Kapsel `fill`, `plus` statt Lupe, Return fügt hinzu, die Zeile wächst oben ein). Darunter eine Sektion mit den Zutaten als Zeilen (`body`), Wischen nach links "Entfernen" (sofort, `UndoToast` "Mehl entfernt · Widerrufen"). Startwerte: Salz, Pfeffer, Wasser, Öl (deckt "Olivenöl", "Rapsöl"), Zucker, Mehl (FW-06; die ersten fünf wie 13 E-04). Fuß: "Diese Zutaten sind abgewählt, wenn du Zutaten auf die Liste setzt. Du kannst sie dort jederzeit wieder auswählen."
- **Eine Liste für die ganze App:** Dieselbe Liste gilt für "Zutaten der Woche" und für "Zutaten auf Liste" im Rezept (13 Kap. 13); die Daten liegen bei Teil A, diese Seite bearbeitet sie (E-16).
- **Zustände:** leer: "Keine Zutaten. Alles kommt auf die Liste." (kein Maskottchen, Arbeits-Screen); offline: lokal mit Sync-Zeichen; doppelte Eingabe: die vorhandene Zeile wird kurz hervorgehoben (`fillPressed`, `springQuick`), keine zweite Zeile.
- **AX/320:** Zeilen brechen um; das Feld wird höher, nie abgeschnitten.

### 12.3 Bildbeschreibung für ChatGPT

iPhone-Screenshot (393 × 852 pt), hell: Ein Sheet in voller Höhe auf #F2F2F7, oben links ein runder Glas-Knopf mit Pfeil zurück, darunter der große fette Titel "Wochenplan". Darunter weiße Sektionen mit Radius 26: "Standard" mit den Zeilen "Portionen" und rechts ein hellgrauer Kapsel-Stepper #E9E9EE "− 2 +", sowie "Ziel-Liste" mit grauem Wert "Liste von heute" und Pfeil nach rechts. Sektion "Zutaten" mit "Hast du meist da", grauer Zahl "6" und Pfeil, darunter eine graue Fußnote. Sektion "Startseite" mit "Heute im Plan zeigen" und einem grünen Schalter #3F7A1F an. Sektion "Mitteilungen" mit "An die nächste Woche erinnern" und einem grauen Schalter #E9E9EE aus. Text #000000, Werte und Fußnoten #636366, Trennlinien #C6C6C8 ab der Textkante. Sektionstitel in fettem Schwarz, gemischte Schreibweise, keine Großbuchstaben, keine Icons in farbigen Quadraten.

---

## 13. Daten und Logik (Vorgaben für Teil B)

### 13.1 Tabellen (neue Migration `…_b_meal_plan.sql`, Vorschlag)

- `meal_plan_entries`: `id` (uuid), `user_id` (uuid, RLS `auth.uid()`), `plan_date` (date, lokaler Kalendertag, nicht UTC), `recipe_id` (uuid, nullable bei gelöschtem Rezept), `recipe_snapshot` (jsonb: Name, Foto-URL, `photo_color`, kcal pro Portion; für "Rezept nicht mehr verfügbar" und schnelles Rendern), `servings` (int), `meal_type` (text, nullable), `position` (int), `sent_list_id` (uuid, nullable), `sent_servings` (int, nullable), `sent_at` (timestamptz, nullable), `created_at`, `updated_at`.
- `meal_plan_settings` (oder Felder in `user_preferences`): `default_servings`, `target_list_id` (null = Liste von heute), `show_today_hint` (bool), `reminder_enabled`, `reminder_weekday`, `reminder_time`.
- Wochenweise Ziel-Liste: `meal_plan_weeks` (`user_id`, `week_start`, `target_list_id`), nur angelegt, wenn vom Standard abweichend.
- Realtime auf `meal_plan_entries` für dasselbe Konto auf mehreren Geräten (Owner und Jannis testen genau so). Konflikte: pro Eintrag letzter Schreiber; Einträge sind unabhängige Zeilen, daher keine Lese-Misch-Schreib-Fehler wie bei Challenges (`inventar/calories.md` 4.10).
- Lokaler Stand: aktuelle Woche plus vier Wochen voraus und zwei zurück im lokalen Speicher, vor dem ersten Frame verfügbar (00 Kap. 13, "Start").

### 13.2 Zusammenfassen und Zählen

- Eingabe: Einträge im Zeitraum, je Rezept die Zutaten mit `Ingredient.adjustForServings(defaultServings, servings)`, danach Ersetzungen nach Ernährung (wenn "Rezepte automatisch anpassen" an), danach Normalisierung und Zusammenfassen (6.4), danach Abgleich mit offenen Artikeln der Ziel-Liste und mit der Vorratsliste.
- **Unterschied nach dem Senden (W-05):** Für einen gesendeten Eintrag zählt nur `servings − sent_servings`, wenn positiv. Weniger Portionen oder entfernte Rezepte nehmen **nichts** von der Liste (FW-04); die Rezeptzeile zeigt dann "Auf Wocheneinkauf · 2 Portionen weniger geplant" als reine Information.
- Wechselt die Ziel-Liste nach dem Senden, gelten gesendete Einträge als erledigt; nur neue Einträge gehen auf die neue Liste.
- Der Plan zählt einen Eintrag als "auf der Liste", sobald gesendet; ob die Artikel später gekauft oder gelöscht wurden, ändert das nicht (kein stilles Nachsenden).
- Herkunft am Artikel: Neu angelegte Artikel bekommen die Notiz "für Chili sin Carne, Gemüse-Curry" (Artikel-Unterzeile, 00 Kap. 12.8); bei zusammengeführten bestehenden Artikeln bleibt deren Notiz unverändert. Zusätzlich speichert jeder Artikel, welche Menge aus welchem Plan-Eintrag stammt (`plan_contributions` jsonb: Eintrag-ID, Menge, Einheit), damit der Abgleich "Schon auf Wocheneinkauf" Plan-Mengen nicht doppelt zählt (6.4) und Widerrufen genau diese Mengen zurücknimmt.
- Leistung: Die Zusammenfassung ist eine reine Funktion ohne Netz, läuft bei über 30 Zutaten in einem Isolate und wird pro Woche zwischengespeichert; ein Stepper-Schritt rechnet nur den betroffenen Eintrag neu.

### 13.3 Gemeinsame Logik mit dem Rezept

"Zutaten auf Liste" im Rezeptdetail (Teil A, 01 Kap. 10.5, 13 Kap. 13) und "Zutaten der Woche" nutzen denselben Dienst `RecipeToList` mit `RecipeAdaptation` und dieselbe Stapel-API (E-11), damit Ersatz, Rundung und Zusammenführen überall gleich sind. Ist das Rezept für heute oder künftig im Plan und wird es aus dem Detail auf die Liste gesetzt, setzt Teil A über eine Plan-Schnittstelle von B (`markPlanEntrySent(entryId, listId, servings)`) die Markierung, damit nichts doppelt auf die Liste kommt.

### 13.4 Avo-Werkzeuge (Kapitel 16, Teil B)

- Namen wie in 16 Kap. 6.2: `get_plan`, `add_to_plan(day, recipe, servings)` (Tag schon belegt: Auswahl "Dazulegen" / "Ersetzen"), `fill_plan(days, wishes)` (z. B. "Plane Do. bis So. vegetarisch, unter 30 Minuten"; nur aus vorhandenen Rezepten, Allergien ausgeschlossen, Pro-Kandidat), `plan_to_list(range, list)`. Neu in diesem Kapitel, in 16 zu ergänzen: `move_in_plan(entry, day)` und `remove_from_plan(entries)` bzw. "Woche leeren".
- Jede Ausführung erscheint als `AvoResultRow` mit `calendar`: "2 Rezepte in den Plan gelegt" mit Unterzeile "Do.: Shakshuka, So.: Linsen-Dal mit Spinat", rechts "Widerrufen"; "Ansehen" öffnet Tab Plan in dieser Woche.
- **Entfernen per Avo nur mit Rückfrage-Karte** (`AvoConfirmCard`, Plan 12: "Löschen nur mit Rückfrage"; gleiche Regel wie `delete_item` in 16): "Lachs mit Ofenkartoffeln am Fr., 13. Nov. aus dem Plan nehmen?" bzw. "Alle 6 Rezepte der Woche 9.–15. Nov. aus dem Plan nehmen?"; erst der Tipp führt aus, danach Ergebniszeile mit "Widerrufen". In der App selbst bleibt Entfernen sofort mit Rückgängig (W-08), weil man dort sieht, was man tut.
- Ist der Plan Pro und der Nutzer nicht: `plan_to_list` liefert "Mit {pro} verfügbar · Ansehen" (00 Kap. 16.1); Planen selbst bleibt frei.
- Kontext im leeren Avo-Sheet, wenn man aus dem Tab Plan kommt (16 Kap. 5): "Plane den Rest der Woche", "Was koche ich heute?", "Zutaten der Woche auf Wocheneinkauf".

### 13.5 Widget und Siri (Kapitel 19, Teil B)

- Wochenplan-Widget: heute und die nächsten Tage mit Rezeptnamen (klein: nur heute); Tippen öffnet `/plan` am Tag bzw. das Detail. Modul aus: ruhiger Satz "Wochenplan ist ausgeschaltet".
- Siri "Was gibt's heute?": "Heute im Plan: Chili sin Carne." Ohne Eintrag: "Für heute ist nichts geplant." Ohne App-Öffnen.

---

## 14. Abläufe

### 14.1 Woche planen und einkaufen (Hauptablauf, Plan 5)

1. Sa., 7. Nov.: Tab Plan, Toolbar `chevron.right` (oder Wischen) zu "Nächste Woche · 9.–15. Nov.". Die Woche ist leer. Daumen tippt bei "Mo., 9. Nov." auf "Rezept hinzufügen".
2. Sheet "Rezept wählen" (groß), Segment "Gespeichert". Tipp auf "Spaghetti mit Linsen-Bolognese": Sheet schließt, die Zeile wächst bei Montag ein (2 Portionen).
3. Mit dem ersten Rezept erscheint die Aktionsleiste; nach Dienstag (Ofengemüse mit Feta) zeigt sie "9 Zutaten auf Wocheneinkauf".
4. Leiste antippen: Sheet "Zutaten der Woche", künftige Woche, daher ohne Zeitraum-Wahl (ganze Woche). Olivenöl ist abgewählt ("Hast du meist da"). "9 Zutaten hinzufügen".
5. Sheet schließt, Erfolgsmoment "Wochenplan ist auf der Liste.", Erfolgs-Haptik, Toast "9 Zutaten zu Wocheneinkauf · Widerrufen". Mo. und Di. zeigen "Auf Wocheneinkauf". Das ist das erste Senden dieser Woche (7.2).
6. Mi., 11. Nov., morgens: Plan für Mi. bis Sa. ergänzt (Chili 4 Portionen, Lachs, Curry 3 Portionen, Crumble 4 Portionen; Portionen jeweils per Stepper, Auswahl-Haptik pro Schritt, Zahlen rollen). Leiste: "17 Zutaten auf Wocheneinkauf".
7. Leiste antippen: Zeitraum "Ab heute", 17 gewählt, Reis abgewählt ("Schon auf Wocheneinkauf (1 kg)"), Mehl und Zucker abgewählt. Mit Angebote: drei Schilder, Ersparnis-Zeile "3 von 17 …".
8. "17 Zutaten hinzufügen". Der Erfolgsmoment kam für diese Woche schon am Sa., 7. Nov. (7.2, E-15), daher nur der Toast "17 Zutaten zu Wocheneinkauf · Widerrufen".
9. Lena sieht 17 neue Artikel live auf Wocheneinkauf, je mit Notiz "für Chili sin Carne" usw.; Mitteilung gebündelt.
10. Im Laden (01 Kap. 10.2) erscheinen die Artikel in den Gängen von Lidl.

**Fertig-Kriterium (Verbesserungsliste 11):** Eine Woche mit 5 Rezepten ergibt eine zusammengefasste Liste ohne doppelte Zeilen, mit addierten Mengen gleicher Einheitenfamilie, ohne Grundzutaten und ohne schon Vorhandenes.

### 14.2 Rezept aus dem Rezeptdetail in den Plan

1. Mi., 11. Nov.: Tab Rezepte > Rezept "Ofengemüse mit Feta" (Portionen im Detail: 2) > Toolbar `ellipsis` > "Zum Wochenplan". Das Menü zeigt an derselben Stelle das Untermenü mit den sieben Tagen.
2. Tipp auf "Morgen, Do., 12. Nov.": Menü schließt, Toast "Auf Do., 12. Nov. im Wochenplan · Widerrufen"; unter dem Titel des Details steht jetzt "Im Plan: Do., 12. Nov. · 2 Portionen".
3. Im Tab Plan steht am Donnerstag die Zeile; die Aktionsleiste zählt die neuen Zutaten.
4. Für einen Tag nach dem 17. Nov.: Untermenü > "Anderes Datum…" > Sheet mit Kalender (8.2) > Tag wählen > `checkmark`.

### 14.3 Portionen ändern, nachdem schon alles auf der Liste ist

1. Sa-Besuch wird größer: Stepper beim Gemüse-Curry von 3 auf 5. Zahl rollt, Auswahl-Haptik.
2. Zeile zeigt "Auf Wocheneinkauf · 2 Portionen mehr geplant"; Aktionsleiste erscheint: "5 Zutaten auf Wocheneinkauf". Die 400 ml Kokosmilch, die der Plan schon geschickt hat, zählen nicht als vorhanden (6.4).
3. Leiste antippen: Sheet zeigt nur den Unterschied für 2 Portionen: "Kokosmilch · 275 ml", "Kichererbsen · 1 Dose", "Brokkoli · 1", "Zwiebeln · 1", "Joghurt · 100 g"; "Reis" abgewählt ("Schon auf Wocheneinkauf (1 kg)").
4. "5 Zutaten hinzufügen": nur Toast; Mengen bestehender offener Artikel werden erhöht (Kokosmilch 400 ml → 675 ml), fehlende neu angelegt.
5. Portionen später verringern: nichts verschwindet von der Liste; die Zeile zeigt "2 Portionen weniger geplant" (FW-04).

### 14.4 Rezept verschieben oder entfernen

1. Langdruck auf "Lachs mit Ofenkartoffeln" (Fr., 13. Nov.): Kontextmenü erscheint; ohne Loslassen weiterziehen: die Zeile hebt sich und folgt dem Finger.
2. Über "Do., 12. Nov." öffnet sich eine Lücke; Loslassen legt ab, Auswahl-Haptik beim Einrasten.
3. Alternativ Kontextmenü > "Auf anderen Tag" > "Do., 12. Nov.".
4. Entfernen: Kontextmenü > "Entfernen", Zeile schrumpft weg, Toast "Lachs mit Ofenkartoffeln entfernt · Widerrufen". War der Eintrag schon auf der Liste, bleiben die Artikel dort (FW-04).

### 14.5 Heute kochen (von der Startseite)

1. Tab Liste, Mi., 17 Uhr: Hinweis-Zeile "Heute im Plan: Chili sin Carne · 480 kcal".
2. Tippen: Wechsel in den Tab Plan, Stapel Wurzel + Rezeptdetail (4 Portionen vorbelegt, Metazeile "Im Plan: Mi., 11. Nov. · 4 Portionen").
3. Aktionsleiste des Details > "Kochen": Kochmodus (schwarz) mit 4 Portionen und den angepassten Zutaten.
4. Nach dem letzten Schritt (Kapitel 13) mit Modul Kalorien: Im Tab Kalorien steht beim Abendessen "Aus dem Plan: Chili sin Carne · 480 kcal"; ein Tipp trägt 1 Portion ein, "640 kcal übrig" rollt.

### 14.6 Vorwoche übernehmen

1. So., 15. Nov., 16 Uhr: Startseite zeigt "Nächste Woche ist noch leer · Planen".
2. "Planen": Tab Plan, Woche 16.–22. Nov. Oben die Zeile "Rezepte der Vorwoche übernehmen · 6 Rezepte · 9.–15. Nov." > "Übernehmen".
3. Sechs Zeilen wachsen an ihren Tagen ein, Toast "6 Rezepte übernommen · Widerrufen". Danach einzelne Rezepte über das Kontextmenü tauschen oder entfernen.

### 14.7 Pro gesperrt (nur falls der Owner den Plan zu Pro macht)

1. Nutzer ohne Pro plant frei (14.1, Schritte 1 bis 3).
2. Aktionsleiste: "9 Zutaten auf Wocheneinkauf" mit `ProBadge` (Variante auf getönt).
3. Tippen: Paywall wächst aus der Leiste (`springMorph`), "Wochenplan" steht oben, hinterlegt mit `actionFill`.
4. "14 Tage gratis testen" > Face ID > Erfolgsmoment "{pro} ist aktiv." > Paywall schließt > Sheet "Zutaten der Woche" öffnet sich direkt (die ursprüngliche Aktion läuft weiter).
5. Abbruch: Paywall schließen, der Plan bleibt vollständig erhalten; kein weiterer Hinweis in dieser Woche (00 Kap. 16.5).

### 14.8 Avo plant den Rest der Woche

1. Im Tab Plan: Avo-Kreis tippen, "Plane Donnerstag und Sonntag, vegetarisch, unter 30 Minuten."
2. Avo-Sheet (mittel), Kern `denkt`, dann Antwort: "Ich habe zwei Rezepte gefunden." Ergebniszeile `calendar` "2 Rezepte in den Plan gelegt", Unterzeile "Do.: Shakshuka, So.: Linsen-Dal mit Spinat", rechts "Widerrufen"; "Ansehen" öffnet die Woche (Werkzeug `fill_plan`, 13.4).
3. Im Plan (sichtbar hinter dem Sheet in mittlerer Höhe) wachsen die Zeilen ein; die Aktionsleiste ist ausgeblendet, solange das Sheet offen ist, und erscheint danach mit der neuen Zahl.
4. Folgefrage "Und alles auf die Liste": Ergebniszeile "9 Zutaten zu Wocheneinkauf hinzugefügt · Widerrufen" (`plan_to_list`; ohne Erfolgsmoment, Avo zeigt sein Ergebnis selbst).
5. "Nimm den Lachs am Freitag raus": Avo zeigt die Rückfrage-Karte "Lachs mit Ofenkartoffeln am Fr., 13. Nov. aus dem Plan nehmen?" mit "Entfernen" (gefüllt `danger`) und "Abbrechen"; per Stimme reicht "Ja" nicht, erst der Tipp führt aus (13.4).

---

## 15. Entscheidungen dieses Kapitels

| Nr. | Entscheidung | Grund |
|---|---|---|
| W-01 | Tage als senkrechte Inset-Sektionen, Rezepte als Zeilen mit 56-pt-Foto und Stepper; keine Kalender-Raster-Ansicht | Leitplanke aus 01 Kap. 10.6; liest sich auf 320 pt und bei AX; Muster aus Erinnerungen |
| W-02 | Woche beginnt am Montag (Route `/plan/:weekStart` = Montag) | deutscher Standard; FW-02 für andere Regionen |
| W-03 | In der aktuellen Woche liegen vergangene Tage in einer eingeklappten Sektion oben; die Seite beginnt mit "Heute" | Hauptfrage "heute" ohne Wegscrollen des Titels (Wayfinding) |
| W-04 | Keine Wischaktionen auf Rezeptzeilen; waagerechtes Wischen wechselt die Woche; Entfernen über Kontextmenü und Bearbeiten-Modus mit Rückgängig | eine Geste, eine Bedeutung |
| W-05 | Der Plan merkt sich pro Eintrag die gesendeten Portionen; die Leiste zählt nur Fehlendes bzw. den Unterschied | "Ein Tipp" darf nicht doppelt auf die Liste schreiben |
| W-06 | Auswahländerungen im Sheet "Zutaten der Woche" werden nicht gespeichert; "Immer weglassen" und "Menge ändern" schon | einfache Erwartung; dauerhafte Wünsche sind eigene Aktionen |
| W-07 | Planen bleibt immer frei; nur "auf die Liste" kann Pro sein | 00 Kap. 16.2, echte Vorschau |
| W-08 | "Woche leeren" ohne Rückfrage, mit Rückgängig | umkehrbar (00 Kap. 2, Prinzip 6) |
| W-09 | kcal pro Tag pro Person, ohne Wochensumme und ohne Vergleich mit dem Tagesziel im Plan | Plan enthält meist nur eine Mahlzeit; keine irreführenden Zahlen |
| W-10 | Angebote im Sheet nur für den Markt der Ziel-Liste; keine Ersparnis-Zahl ohne echte PLZ | Plan 8, Recherche |
| W-11 | Rezeptdetail aus dem Plan als Push im Tab Plan, Portionen aus dem Eintrag | Tab-Bar bleibt, Zurück führt zum Plan; eine Wahrheit pro Eintrag |
| W-12 | Neue Artikel tragen die Notiz "für <Rezept>" | im Laden weiß man, wofür etwas gekauft wird |
| W-13 | Erfolgsmoment nur beim ersten Senden einer Woche, sonst nur Rückgängig-Hinweis; Hinweis erscheint gleichzeitig mit dem Erfolgsmoment | ein Fest nutzt sich sonst ab; Widerrufen sofort erreichbar (E-15) |
| W-14 | Ein `UndoToast` im Tab Plan steht an der Stelle der Aktionsleiste, nie zusätzlich | Glas-Budget 3 (00 Kap. 8.5), kein Glas auf Glas |
| W-15 | "Menge ändern" ist ein Push im Sheet, kein zweites Sheet; "Immer weglassen" widerruft man in der Zeile selbst | kein Glas-Sheet auf Glas-Sheet, kein schwebender Hinweis auf einem Glas-Sheet |
| W-16 | "Zum Wochenplan" im Rezept ist ein Untermenü mit sieben Tagen (wie 13 Kap. 18.1), das Sheet nur für "Anderes Datum…" | ein Tipp statt Sheet für den häufigen Fall; Herkunft am Auslöser |
| W-17 | Mengen, die der Plan selbst geschickt hat, zählen beim Abgleich nicht als "schon auf der Liste" | sonst decken Montags-Zwiebeln den Mittwoch ab und der Unterschied nach Portionsänderungen ginge verloren |
| W-18 | Avo entfernt Plan-Einträge nur nach Rückfrage-Karte; in der App selbst sofort mit Rückgängig | Plan 12 ("Löschen nur mit Rückfrage"); in der App sieht man, was man tut |

---

## 16. Offene Fragen an den Owner

| Nr. | Frage | Vorschlag |
|---|---|---|
| FW-01 | Wird der Wochenplan Pro (F-05)? | Planen frei, "auf die Liste" Pro ist möglich; das Konzept trägt beides. Empfehlung: frei lassen, bis der Kern-Ablauf Nutzer bindet |
| FW-02 | Wochenbeginn immer Montag oder nach Region (Sonntag in den USA)? | Montag für Deutsch, Sonntag bei englischer Region; Route bleibt "Wochenstart" |
| FW-03 | Soll der Plan im Haushalt geteilt werden (z. B. mit den Mitgliedern einer Liste)? | Version 1 persönlich (pro Konto); die Zutaten landen ohnehin auf der geteilten Liste. Teilen später als eigenes Feature |
| FW-04 | Sollen weniger Portionen oder entfernte Rezepte Artikel von der Liste nehmen? | nein, nur Hinweis an der Zeile; automatisches Löschen auf geteilten Listen überrascht andere |
| FW-05 | Eigene Einträge ohne Rezept ("Auswärts essen", "Reste", "Pizza bestellen")? | ja, als Textzeile ohne Zutaten in Version 1.1; nicht im ersten Bau |
| FW-06 | Startwerte für "Hast du meist da" (eine Liste für Plan und Rezept, E-16)? | Salz, Pfeffer, Wasser, Öl, Zucker (wie 13 E-04) plus Mehl; Essig nicht (wird selten vorrätig vermutet) |
| FW-07 | Erinnerung "Woche planen" am Sonntag standardmäßig aus? | ja, aus; einschaltbar in den Einstellungen und einmalig als Tipp-Zeile nach dem zweiten geplanten Wochenende |

---

## 17. Ergänzungen zum Fundament

| Nr. | Betrifft | Ergänzung | Wer |
|---|---|---|---|
| E-01 | 00 Kap. 8.1, 8.5, 6.2; 01 Kap. 6 | Glas-Liste um "Aktionsleiste im Wochenplan (`PlanActionBar`): eine Gruppe, getönte Hauptaktion plus Ziel-Listen-Knopf, nur Wurzel des Tabs Plan" erweitern. Regel 01 Kap. 6 ("sonst gibt es keine schwebende Leiste über der Tab-Bar") um diese Ausnahme ergänzen. `ShellInsets` liefert den unteren Inhaltsabstand auch für diese Leiste. Glas-Budget im Tab Plan: Tab-Bar, Toolbar, Aktionsleiste = 3; ein `UndoToast` ersetzt dort die Aktionsleiste (W-14). Tönungs-Regel 00 Kap. 8.2 um "Kapsel '… Zutaten auf <Liste>' der Aktionsleiste im Wochenplan" ergänzen | A bestätigt, B baut die Leiste |
| E-02 | 00 Kap. 12.30 | `ProBadge` Variante "auf getönt": Kapsel `onAction`, Text `action` (Kontrast hell 5,23:1, dunkel 10,44:1), für getönte Glas-Kapseln (Aktionsleiste Plan, ggf. Aktionsleiste Rezeptdetail "Kochen") | A |
| E-03 | 00 Kap. 12.21 | `ValueStepper` Größe "kompakt": sichtbare Kapsel 32 pt hoch, Knöpfe sichtbar 36 pt breit mit 44 × 44 Trefferfläche (ragt in den Zeilen-Innenabstand), Wert `number`; Gesamtbreite etwa 108 pt. Für Zeilen mit Stepper (Plan, Einstellungen) | A |
| E-04 | 00 Kap. 5.3, 12.2 | Großer Titel aus einem einzigen Wort, der breiter als die verfügbare Breite ist (z. B. "Wochenplan" bei AX5 auf 320 pt), wird bis auf 0,8 verkleinert statt mitten im Wort umzubrechen. Reicht das nicht, bricht er an einer in der Übersetzung hinterlegten Trennstelle mit Bindestrich um ("Wochen-" / "plan"; Schreibweise im Schlüssel z. B. `Wochen|plan`, angezeigt ohne Strich, solange er passt). Erst ohne Trennstelle Ellipse. Gilt für alle großen Titel (deutsche Komposita: "Einkaufsliste", "Wocheneinkauf") | A |
| E-05 | 00 Kap. 6.4, 12.13 | `RecipeCard` Variante Zeile: ab AX1 Thumbnail oben bündig zur ersten Titelzeile, ab AX3 entfällt das Thumbnail (analog Artikelbilder ab AX1); optionaler rechter Slot (`trailing`) für Stepper bzw. Auswahl | A |
| E-06 | 01 Kap. 7 | Neue Routen: `/plan/recipe/:recipeId?entry=:entryId` (Rezeptdetail als Push im Tab Plan, Besitz B für die Route, Screen A); `/recipes/:recipeId/to-plan` (Sheet mittel "Zum Wochenplan" mit Kalender für "Anderes Datum…", Avo und Deep Links; Inhalt B); `/settings/plan/pantry` (Push im Sheet, B). Deep Link `shoply://plan?day=YYYY-MM-DD` öffnet die Woche des Tages und scrollt zu ihm | A (Router-Gerüst), B (Bereichsdatei) |
| E-07 | Kapitel 13 (Rezeptdetail) | Slot im Rezeptdetail unter dem Titel: `PlanEntryMeta(recipeId:, entryId:)` von B ("Im Plan: Mi., 11. Nov. · 4 Portionen"), rendert `SizedBox.shrink()` ohne Modul oder Eintrag. Menüeintrag "Zum Wochenplan" (`calendar`, wie 13 Kap. 18.1) im Toolbar-Menü `ellipsis` und im Kontextmenü von `RecipeCard`, als Untermenü mit den nächsten sieben Tagen und "Anderes Datum…"; Aufruf von `addRecipeToPlan(recipeId, day, servings)` (B, 13 E-07); Übernahme der Portionen aus `entry` | A baut Slot und Menü, B füllt |
| E-08 | 00 Kap. 7.1 | In der Radien-Tabelle bei `radiusCard` "Wochenplan-Tag" streichen: Die Tage sind `InsetSection`s mit `radiusSection` | A |
| E-09 | 00 Kap. 12 | Neue Komponente `RecipePicker` (Teil A laut `arbeitsteilung.md` 3.4): Sheet-Inhalt mit Kopf-Slot (Tag-Knopf), `SearchField`, `SegmentedControl` Gespeichert / Für dich, Ergebnis-Sektionen aus `RecipeCard`-Zeilen, Rückgabe des gewählten Rezepts; Allergene in "Für dich" ausgeschlossen, sonst mit Hinweis; Kontextmenü "Rezept ansehen". Aufbau wie Kap. 5 | A |
| E-10 | 00 Kap. 12 | Neue Komponente `IngredientPickRow` (Auswahlzeile für Zutaten): Auswahl-Kreis (`checkmark.circle.fill` `action` / Ring `controlOutline`), Artikelbild-Slot, Name, Unterzeile (Herkunft, Grund, Ersetzung), Menge, Schild-Slot; AX-Layout wie `ItemRow`. Genutzt von "Zutaten auf Liste" (01 Kap. 10.5, A) und "Zutaten der Woche" (B) | A |
| E-11 | `arbeitsteilung.md` Kap. 3.5, `prompt-teil-B.md` B7, 13 E-07 | `item_merge_service.dart` existiert nicht; die Logik gehört in den Dienst `RecipeToList` aus 13 E-07 (Teil A). Ergänzungen für den Plan: Eingabe mehrerer Rezepte mit je eigenen Portionen; Normalisierung von Namen und Einheiten (g/kg, ml/l, Stück, Dose, Bund, Zehe; EL/TL/Prise ohne Menge), Rundung, Zusammenfassen, Abgleich mit offenen Artikeln einer Liste unter Ausschluss der Plan-eigenen Mengen (W-17); Feld `plan_contributions` (jsonb) an `shopping_items`. Dazu `ItemRepository.addItems(listId, items)`: ein Aufruf, optimistisch, lokal kategorisiert, KI-Bestätigung im Hintergrund mit 1,1-s-Abstand, Rückgabe einer Rückgängig-Kennung (`undoAddItems(token)`) | A |
| E-12 | 00 Kap. 9.2 | Symbole ergänzen: Anderes Datum (im Untermenü "Zum Wochenplan") `calendar.badge.plus`, Vorwoche übernehmen `doc.on.doc`, Einstellungen eines Bereichs `gearshape`, Rezept ansehen `book`, Griff zum Umsortieren `line.3.horizontal`, Entfernen im Bearbeiten-Modus `minus.circle.fill`, Ziel-Liste wählen `chevron.up.chevron.down` (steht auch in 13 E-12), Immer weglassen `minus.circle`, Original verwenden `arrow.uturn.backward`. "Zum Wochenplan" selbst nutzt `calendar` (13 Kap. 18.1) | A (Symbol-Manifest) |
| E-13 | Kapitel 15 (Kalorien), 10 (Startseite) | Schnittstellen von B: `planEntriesForDayProvider(date)`, `PlanTodayHint` (Hinweis-Zeile mit den Varianten aus 10.2), Regel "keine Kalorien-Ideen-Zeile, wenn heute ein Rezept geplant ist" in der Anordnung `home_nudge_card_order.dart` | B liefert, A ordnet an |
| E-14 | 00 Kap. 11 | Haptik-Tabelle um "Woche wechselt per Wischen: Auswahl" und "Rezept rastet beim Verschieben auf einem Tag ein: Auswahl" ergänzen (fällt unter bestehende Zeilen, zur Klarheit ausdrücklich nennen); keine Haptik beim Planen eines Rezepts | A |
| E-15 | 00 Kap. 12.35 | Erfolgsmoment "Wochenplan ist auf der Liste." gilt beim ersten Senden einer Woche (wird es widerrufen, gilt das nächste Senden wieder als erstes); spätere Ergänzungen derselben Woche nur mit Rückgängig-Hinweis. Der Rückgängig-Hinweis erscheint gleichzeitig mit dem Erfolgsmoment, nicht danach (W-13) | A bestätigt |
| E-16 | 13 E-04, 13 Q-05 | Eine einzige Grundzutaten-Liste "Hast du meist da" für Rezept-Sheet und Wochenplan, pro Konto änderbar (Startwerte FW-06). Daten und Abgleich bei Teil A (`RecipeToList`); die Bearbeitungsseite `/settings/plan/pantry` baut B. Ist das Modul Wochenplan aus, zieht die Seite nach `/settings/lists` (A), damit sie erreichbar bleibt | A entscheidet den Ort, B baut die Seite |

---

## 18. Betroffene Dateien (Gesamtübersicht)

**Neu, Teil B:**
- `lib/presentation/screens/plan/plan_screen.dart`, `plan_settings_screen.dart`, `plan_pantry_screen.dart`
- `lib/presentation/screens/plan/widgets/plan_day_section.dart`, `plan_entry_row.dart`, `plan_action_bar.dart`, `plan_week_pager.dart`, `plan_to_list_sheet.dart`, `plan_quantity_page.dart`, `add_to_plan_sheet.dart`, `plan_today_hint.dart`, `plan_entry_meta.dart`
- `lib/presentation/state/plan_provider.dart` (Woche, Einträge, Zählung, Einstellungen)
- `lib/data/models/meal_plan_entry.dart`, `meal_plan_settings.dart`
- `lib/data/services/meal_plan_service.dart` (Supabase, lokaler Stand, Realtime)
- `lib/routes/areas/plan_routes.dart`, `lib/core/localization/translations/plan_de.dart`, `plan_en.dart`
- `supabase/migrations/<YYYYMMDDHHMMSS>_b_meal_plan.sql`
- Avo-Werkzeuge in `avo_assistant_service.dart` bzw. dessen Nachfolger (B), Widget- und Siri-Teile unter `ios/` (B, Kapitel 19)

**Anfragen an Teil A:**
- Dienst `RecipeToList` (13 E-07) mit den Plan-Ergänzungen aus E-11 statt eines eigenen `item_merge_service.dart`; `RecipeAdaptation` (Ersatz); `lib/data/repositories/item_repository.dart` (`addItems`, `undoAddItems`); Feld `plan_contributions` an `shopping_items` (Migration A); Grundzutaten-Liste "Hast du meist da" (E-16)
- `lib/presentation/widgets/recipes/recipe_picker.dart` (neu), `RecipeCard` (Zeile mit `trailing`, AX-Regel), `IngredientPickRow` (neu), `ValueStepper` kompakt, `ProBadge` auf getönt, `LargeTitleSliver` (Verkleinern einzelner Wörter, Trennstelle mit Bindestrich, E-04)
- `lib/presentation/screens/recipes/recipe_detail_screen.dart` (Slot `PlanEntryMeta`, Untermenü "Zum Wochenplan" auch im `RecipeCard`-Kontextmenü, Portionen aus `entry`, `markPlanEntrySent` nach "Zutaten auf Liste")
- Tab-Bar / `main_scaffold.dart`, `ShellInsets`, Router-Gerüst (Routen E-06), `home_nudge_card_order.dart`
- `lib/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart` wird durch das neue Sheet "Zutaten auf Liste" ersetzt und nutzt denselben Dienst `RecipeToList`

**Entfällt bzw. wird ersetzt:**
- Übersetzungsschlüssel `premium_feature_meal_planning` und `premium_feature_meal_planning_desc` ("KI Essensplanung") in `app_translations.dart`; ersetzt durch den Eintrag `meal_plan` in der Konfiguration `pro_features` (00 Kap. 16.3), nur falls der Plan Pro wird.
