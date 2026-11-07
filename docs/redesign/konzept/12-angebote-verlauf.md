# 12 Angebote, Verlauf und Kosten teilen

Stand: 07.11.2026. Baut auf `00-grundlagen.md` (Verweise "00 x.y") und `01-navigation-und-struktur.md` (Verweise "01 x.y") auf. Gebaut wird dieser Bereich von **Teil B** (Ordner `screens/offers`, `screens/history`, Angebots-Widgets der Liste, Hinweis-Zeilen-Inhalte, Seite "Preise & Angebote"). Teil A baut die Slots, in denen B-Widgets sitzen (Listenkopf, Accessory, Artikelzeile, Startseite, Einstellungs-Sheet).

Grundlagen dieses Kapitels: Jannis' Plan Punkt 8 (gilt bei Widerspruch), Recherche "Preise, Angebote und Artikelbilder", Verbesserungsliste 6a bis 6d, Inventare `history.md`, `lists-more.md`, `home.md`.

Inhalt: 1 Regeln des Bereichs · 2 Beispieldaten · 3 Markt pro Liste · 4 Angebote in der Liste · 5 Angebote der Woche · 6 Region und Einstellungen · 7 Einkauf abschließen · 8 Verlauf · 9 Kosten teilen · 10 Dialoge und Sonderzustände · 11 Avo in diesem Bereich · 12 Abläufe · 13 Entscheidungen dieses Kapitels · 14 Offene Fragen · 15 Ergänzungen zum Fundament · 16 Abdeckung der Inventare

---

## 1. Regeln des Bereichs (verbindlich)

**Angebote**
1. **Modul plus Kill-Switch.** Alles Angebotsbezogene gehört zum Modul "Preise & Angebote" (00 15.1) und hängt zusätzlich am Remote-Flag `app_flags.offers_enabled` (00 15.3). Ist eines davon aus, verschwindet es spurlos: kein Gelb, keine Lücke, kein reservierter Platz, kein "nicht verfügbar". Der Markt-Chip bleibt (Kern).
2. **Nur der Markt der Liste.** In einer Liste erscheinen nur Angebote des Markts dieser Liste. Ohne Listen-Markt gilt Abschnitt 3.4. Es gibt keinen Vergleich zwischen Märkten, keine Korbsumme, keine Rangliste, keinen Satz "bei X wäre es Y € günstiger", auch nicht versteckt (keine Sortierung "günstigster zuerst" über Märkte hinweg).
3. **Wortlaut.** Ersparnis-Satz immer in dieser Form: "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region". Vergleichspreise nur als "laut Händler statt 1,19 €". Keine selbst berechneten Prozent-Rabatte, kein "-23 %"-Abzeichen, kein "Spare …".
4. **Ersparnis nur mit echter Region.** Echte Region = per Standort ermittelte oder vom Nutzer eingegebene Postleitzahl. Ohne echte Region keine Ersparnis-Zahl, keine Angebote (die heutige Ersatz-PLZ 10115 wird in der Oberfläche nicht mehr verwendet, K12-01), stattdessen die Zeile "Für Angebote in deiner Region: Postleitzahl festlegen".
5. **Ersparnis-Rechnung.** Summe über alle Artikel der Liste mit Angebot des Listen-Markts, für die der Händler einen Vergleichspreis nennt: (Vergleichs-Grundpreis minus Angebots-Grundpreis) mal Listenmenge in Grundeinheit; bei nicht vergleichbarer Einheit Packungsdifferenz mal Anzahl. Artikel ohne Händler-Vergleichspreis zählen bei "4 von 11" mit, tragen aber 0 € bei. Anzeige auf 10 Cent gerundet mit "ca.". Unter 0,50 € entfällt der Teil "ca. … gespart" (der Satz endet dann mit "im Angebot, in deiner Region").
6. **Nie Pro.** Kein `ProBadge`, keine Paywall, kein Pro-Hinweis an einer Angebotsfläche; Angebote stehen nie in `pro_features`. Der heutige Paywall-Text `premium_feat_deals` und die Angebots-Aussagen in `AvoAppKnowledge` entfallen (Verbesserungsliste 6a).
7. **Keine Händlerbilder.** Angebote zeigen das Avo Symbol der Kategorie (00 9.4), nie das Bild der Angebotsquelle (heute Hotlink `mg2de.b-cdn.net`). Supermarkt-Logos nur mit Erlaubnis; bis dahin Markenpunkt plus Name (00 4.8).
8. **Kein eigenes Angebots-Widget** auf dem Home-Bildschirm, solange keine Lizenz besteht (K-27). Die Ersparnis-Zeile im großen Listen-Widget gehört zum Modul (Kapitel 19).
9. **Quellen sichtbar.** Jede Angebotsfläche mit Preisdetail trägt die Fußnote "Angebote gelten für deine Region, nicht für einen bestimmten Markt. Preise sind Angaben des Händlers; Normalpreise kennt die App nicht. Quelle: {Angebotsquelle}." (`footnote`, `labelSecondary`; `{Angebotsquelle}` ist ein Platzhalter bis zur Lizenzklärung, F12-1). Im Folgenden kurz "Quellen-Fußnote".
10. **Datensparsam und sparsam im Netz.** Ohne echte Region gehen keine Anfragen an die Angebotsquelle. Beim Tippen wird erst ab 2 Zeichen und 300 ms Pause gesucht; nie ganze Kataloge oder viele Postleitzahlen vorladen. Die Angebote der Listenartikel werden pro Liste höchstens alle 6 h im Hintergrund abgeglichen, nur für den Markt der Liste; Abhaken und Hinzufügen zählen lokal neu und lösen keine Netzanfrage aus (heute startet jedes Abhaken den Korbvergleich neu). Such- und Angebots-Caches sind begrenzt (höchstens 200 Einträge, älteste fliegen zuerst). Fest eingebaute Ersatz-Schlüssel und das Auslesen von Schlüsseln aus Webseiten entfallen (6a). Die Datenschutzerklärung nennt, dass Suchbegriffe und Postleitzahl an die Angebotsquelle gehen.

**Verlauf und Kosten teilen**
11. **Verlauf ist Kern** (K-26), frei, nie abschaltbar. Ersparnis im Verlauf gehört zum Modul Angebote; Beträge und Aufteilungen zum Modul Kosten teilen (außer dem Feld "Betrag", das zum Kern gehört, siehe 7.1).
12. **Geld ist ernst.** Kein Maskottchen und kein Avo-Kern-Glanz bei Beträgen, Schulden, Ersparnis-Details und Fehlern (00 3.3). Ausnahme: der Erfolgsmoment nach dem Abschluss (00 12.35), dort steht die Ersparnis nur als Unterzeile.
13. **Rückgängig statt Rückfrage** bei "bezahlt", Aufteilung ändern, Einkauf abschließen. Rückfrage nur bei "Einkauf löschen" (endgültig, löscht die Aufteilung für alle).
14. **Gesamtbetrag nur vom Menschen.** `total_cost` entsteht nur durch Eingabe (Abschluss-Sheet, Einkauf, Kosten teilen, Avo), nie aus der Summe bekannter Angebotspreise (behebt Inventar history Bug 7).
15. **Ausblenden gilt pro Konto.** Weggewischte Hinweise, "Nicht dieses Angebot", ausgeblendete Listen und Schlummer-Zustände werden im Konto gespeichert, nicht gerätweit (heute bleiben sie nach einem Kontowechsel stehen, Inventar home Bug 20).

---

## 2. Beispieldaten (durchgehend verwendet)

Heute ist Sa., 7. Nov. 2026. "Du" ist Jannis. Region: 79098 Freiburg im Breisgau (per Standort). Lieblingsmärkte: Lidl, REWE.

**Liste "Wocheneinkauf"** (Listenfarbe Grün, Symbol `cart`, Markt Lidl, geteilt mit Lena), 11 offene Artikel:

| Artikel | Menge | Angebot bei Lidl (bis Sa., 14. Nov.) | laut Händler statt | Grundpreis | Ersparnis |
|---|---|---|---|---|---|
| Bananen | 1 kg | Bananen, 1 kg · 1,29 € | 1,79 € | 1,29 €/kg | 0,50 € |
| Avocados | 2 | – | | | |
| Cherrytomaten | 1 | – | | | |
| Brokkoli | 1 | – | | | |
| Milch | 2 | Milbona Frische Vollmilch 3,5 %, 1 l · 0,99 € | 1,19 € | 0,99 €/l | 0,40 € |
| Butter | 2 | Milbona Deutsche Markenbutter, 250 g · 1,49 € | 2,29 € | 5,96 €/kg | 1,60 € |
| Gouda in Scheiben | 1 | – | | | |
| Eier Größe M | 10 | – | | | |
| Spaghetti | 1 | – | | | |
| Passierte Tomaten | 2 | – | | | |
| Kaffee | 1 | Barissimo Kaffee Crema, 1 kg · 9,99 € | 10,69 € | 9,99 €/kg | 0,70 € |

Ergibt: **"4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region".**

**Einkauf heute 18:40 bei Lidl:** 9 Artikel im Wagen (Brokkoli und Gouda bleiben auf der Liste), Betrag 42,80 €, geteilt mit Lena: je 21,40 €, bezahlt von dir.

**Verlauf November** (bis heute): 6 Einkäufe, 58 Artikel, Ausgaben 168,40 € (aus 4 von 6 Einkäufen), ca. 9,80 € durch Angebote gespart. Ausgaben pro Monat: Jun 240,10 €, Jul 286,50 €, Aug 198,30 €, Sep 262,70 €, Okt 251,90 €, Nov 168,40 € (laufend).

| Einkauf | Liste | Markt | Wann | Artikel | Betrag | Wer | Aufteilung |
|---|---|---|---|---|---|---|---|
| 1 | Wocheneinkauf | Lidl | Heute, 18:40 | 9 | 42,80 € | du | Lena schuldet dir 21,40 € |
| 2 | Wocheneinkauf | REWE | Mi., 4. Nov. | 7 | 23,15 € | Lena | du schuldest Lena 11,58 € |
| 3 | Wocheneinkauf | Aldi Süd | Di., 3. Nov. | 8 | – | Lena | – |
| 4 | Wocheneinkauf | Lidl | Mo., 2. Nov. | 15 | 62,85 € | du | nicht geteilt |
| 5 | Grillabend | Kaufland | So., 1. Nov. | 14 | 39,60 € | du | Tom (ohne Konto) schuldet dir 13,20 €, Lena hat 13,20 € bezahlt (am 2. Nov.) |
| 6 | Drogerie | – | So., 1. Nov. | 5 | – | du | – |

Probe: 9 + 7 + 8 + 15 + 14 + 5 = 58 Artikel; 42,80 + 23,15 + 62,85 + 39,60 = 168,40 € aus 4 von 6 Einkäufen.

Offene Beträge (3 Anteile): schuldet dir 34,60 € (Lena 21,40 €, Tom 13,20 €); du schuldest 11,58 € (Lena; 23,15 € geteilt ergibt 11,58 € + 11,57 €, der Restcent liegt beim ersten Teilnehmer). Erledigt: Lena 13,20 € (Grillabend).

**Stammartikel im Angebot ("Oft gekauft"), nicht offen auf einer Liste:** Kölln Zarte Haferflocken, 500 g · REWE · 1,49 € (kaufst du etwa alle 10 Tage); Weihenstephan Joghurt mild 3,5 %, 500 g · REWE · 0,99 € (etwa alle 7 Tage); Saskia Mineralwasser still, 6 × 1,5 l · Lidl · 1,49 € (etwa alle 14 Tage). Ergibt die Hinweis-Zeile "3 Sachen, die du oft kaufst, sind diese Woche im Angebot".

**Angebote der Woche, passend zu deinen Listen:** Wocheneinkauf (Lidl) 4, Grillabend (Kaufland) 2, zusammen 6 ("6 passen zu deinen Listen").

---

## 3. Markt pro Liste

Der Markt der Liste ist Kern (00 15.1): Er steuert die Reihenfolge im Markt, den Titel im Einkaufsmodus, den Verlauf und, mit Modul, die Angebote. Daten (Teil B): `shopping_lists.store_chain` (Ketten-ID, z. B. `lidl`), `store_source` (`user`, `name`, `learned`, `location`, `none`), Migration in `database/migrations/`. Ketten-Verzeichnis mit Aliasen, Tippfehlern, Handelsmarken und Markenfarbe als Daten (00 4.8).

### 3.1 Markt-Chip im Listenkopf (`StoreChip`, Slot Teil A, Inhalt Teil B)

- **Hauptfrage:** Für welchen Markt ist diese Liste?
- **Wann:** immer im Kopf der Liste von heute (Metazeile unter dem großen Titel, Lage bestimmt Kapitel 10/11), im Listen-Info-Sheet als Zeile "Markt".
- **Aufbau:** 00 12.10 unverändert: Kapsel `fill`, 8-pt-Punkt in Markenfarbe, Name in `subheadline` `label`, `chevron.down` 11 pt.
- **Beispiel:** "● Lidl" (Punkt #0050AA). Vorgeschlagen: "● Lidl?" mit gestricheltem Rand. Kein Markt: `storefront` + "Markt wählen" in `labelSecondary`.
- **Zustände:**
  - gesetzt durch Nutzer (`user`): schlägt jedes andere Signal, wird nie überschrieben.
  - erkannt aus dem Listennamen beim Anlegen (`name`, z. B. "Lidl", "REWE Wocheneinkauf", "Aldi Süd", "lidel"): gilt direkt als gesetzt, weil der Name eine Aussage des Nutzers ist; einmal Tipp-Zeile "Markt aus dem Namen erkannt. Tippen zum Ändern." (wegwischbar). Beim späteren Umbenennen nur Vorschlag "REWE?" (wie Kapitel 11, 11.3).
  - gelernt (zweimal derselbe Markt beim Abschluss, `learned`) oder Standort (`location`): nur Vorschlag "Lidl?" (3.2).
  - Handelsmarken (Milbona, ja!, Gut & Günstig) sind nur Zusatzsignal für die Reihenfolge der Vorschläge, nie allein ein Vorschlag.
  - kein Markt: "Markt wählen".
  - Modul Angebote aus oder Kill-Switch: Chip bleibt unverändert; nur die Angebote fehlen.
  - Markt-Erkennung ausgeschaltet (6.3): keine Vorschläge aus Einkäufen oder Standort und keine Erkennung aus dem Listennamen; der Chip zeigt nur den selbst gesetzten Markt oder "Markt wählen".
  - offline: gleich (Ketten-Verzeichnis liegt lokal).
- **Interaktion:** Tippen öffnet das Menü "Markt" (wächst aus dem Chip, `springMenu`, 00 12.24): oben die Lieblingsmärkte, dann Märkte aus dem Verlauf dieser Liste, Trenner, "Anderer Markt …" (öffnet 3.3), "Kein fester Markt". Auswahl wirkt sofort (Chip-Text wechselt per Überblendung, Gänge sortieren sich mit `springStandard` um, Angebote wechseln), Rückgängig-Hinweis "Markt: REWE · Widerrufen". Keine Haptik.
- **AX / 320 pt:** Chip bricht in der Metazeile um (00 6.3: Metazeile in 2 Zeilen bei 320 pt); ab AX1 eigene Zeile; Punkt wächst bis AX2.
- **Änderung gegenüber heute:** Es gibt heute kein Markt-Feld (`shopping_list_model.dart`). Neu: Modell, Migration, Ketten-Verzeichnis, `store_chip.dart` (B, `widgets/deals/`).
- **Bildbeschreibung für ChatGPT:** Ausschnitt einer iPhone-Liste im hellen Modus auf Hintergrund #F2F2F7. Oben links großer fetter Titel "Wocheneinkauf" in #000000 mit kleinem grauem Chevron nach unten. Darunter eine Metazeile mit einer grauen Kapsel #E9E9EE mit einem 8-pt-Punkt in Lidl-Blau #0050AA, dem Wort "Lidl" in schwarzer Systemschrift 15 pt und einem winzigen Chevron, daneben in #636366 "11 offen · mit Lena". Rechts daneben ein geöffnetes Glas-Menü, das aus der Kapsel wächst, mit Zeilen "Lidl" (mit Häkchen links), "REWE", Trennband, "Anderer Markt …", "Kein fester Markt". Keine Logos, keine Großbuchstaben, keine Schatten auf Inhalten.

### 3.2 Markt-Vorschlag (Rückfrage)

- **Hauptfrage:** Ist das deine Lidl-Liste?
- **Wann:** Tippen auf einen vorgeschlagenen Chip "Lidl?" oder auf die Hinweis-Zeile "Du warst zweimal mit dieser Liste bei Lidl. Als Markt festlegen?".
- **Aufbau:** `AppMenu` aus dem Chip mit Titelzeile "Ist das deine Lidl-Liste?" (`footnote`, `labelSecondary`) und Einträgen "Ja, Lidl" (`checkmark`), "Anderer Markt …" (`storefront`), "Nicht fragen" (`xmark`).
- **Zustände:** "Nicht fragen" gilt dauerhaft für diese Liste und diesen Markt (ein anderer Markt darf später noch vorgeschlagen werden, Kapitel 11, 11.1); der Chip wird "Markt wählen". Standort-Vorschlag erscheint nur, wenn die Liste im Umkreis von 80 m eines eindeutig erkannten Markts geöffnet wird (Regel aus `checkout_store_resolver.dart`), und nie, wenn Standort nicht erlaubt ist (dann wird auch nicht gefragt).
- **Interaktion:** "Ja" setzt `store_source = user`, Chip verliert den gestrichelten Rand (`springQuick`). Keine Haptik.
- **AX / 320 pt:** Menüzeilen brechen um, Mindesthöhe 44.
- **Änderung:** neu; ersetzt die stille Speicherung des OSM-Anzeigenamens.
- **Bildbeschreibung für ChatGPT:** iPhone-Ausschnitt hell, Hintergrund #F2F2F7. Unter dem großen Titel "Wocheneinkauf" eine graue Kapsel #E9E9EE mit gestricheltem Rand in #8A8A8E, blauem Punkt #0050AA und dem Text "Lidl?". Aus der Kapsel wächst ein milchiges Liquid-Glass-Menü mit abgerundeten Ecken (20 pt). Oben im Menü kleiner grauer Text #636366 "Ist das deine Lidl-Liste?", darunter drei Zeilen in schwarzer 17-pt-Schrift: "Ja, Lidl" mit Häkchen-Symbol rechts, "Anderer Markt …" mit Laden-Symbol, "Nicht fragen" mit X-Symbol. Die Liste dahinter ist leicht sichtbar, ruhig, ohne Farbe außer dem Blau.

### 3.3 Markt wählen (Sheet "Markt")

- **Hauptfrage:** Welcher Markt ist es?
- **Wann:** "Anderer Markt …" aus Chip-Menü, Neue-Liste-Sheet (Kapitel 11), Abschluss-Sheet (Push im Sheet, 7.2), Listen-Info.
- **Aufbau (Sheet mittel, groß beim Suchen):** Kopf `xmark`, "Markt", kein `checkmark` (Tippen wählt). `SearchField` "Markt suchen". Sektion "Deine Märkte" (Lieblingsmärkte und schon genutzte; der aktuelle Markt mit `checkmark` links). Sektion "In der Nähe" (nur mit Standort-Erlaubnis; Zeilen mit Markenpunkt, Name, Straße und Entfernung "120 m" in `labelSecondary`). Sektion "Alle Märkte" (Ketten-Verzeichnis alphabetisch: Aldi Nord, Aldi Süd, Edeka, Kaufland, Lidl, Netto, PENNY, REWE …). Letzte Zeile "Kein fester Markt".
- **Beispiel:** In der Nähe: "● Lidl · Kaiser-Joseph-Straße · 120 m", "● REWE · Bertoldstraße · 340 m".
- **Zustände:** ohne Standort entfällt "In der Nähe" ohne Lücke; Suche ohne Treffer: "Kein Markt mit „Bio Kaiser“ gefunden. Als eigenen Markt verwenden?" (ein eigener Markt hat keine Markenfarbe; sein Punkt ist ein Ring in `controlOutline`); offline: nur lokale Sektionen. Nie ein Spinner. Damit nichts unter dem Finger springt, steht "Deine Märkte" oben (sofort aus dem lokalen Stand) und "In der Nähe" darunter: Diese Sektion blendet ein, sobald die Abfrage fertig ist (`fadeReduced`), und schiebt nur "Alle Märkte" nach unten, die unterhalb der Leseposition liegen (00 13).
- **Interaktion:** Tippen wählt und schließt (`springSheet`). Ziehen 1:1 zwischen mittel und groß.
- **AX / 320 pt:** Zeilen brechen um, Entfernung rutscht unter den Namen.
- **Änderung:** ersetzt `checkout_store_sheet.dart` (Kacheln, feste 280 pt Höhe, Freitextfeld). Speichert Ketten-ID statt OSM-Namen; Overpass fragt künftig `node` und `way` im Radius 250 m ab.
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe, schwebend mit Glas-Hintergrund und konzentrischen Ecken, darin eine Fläche #F2F2F7. Oben links ein runder Glas-Knopf mit X, mittig fett "Markt". Darunter ein graues Suchfeld #E9E9EE mit Lupe und Platzhalter "Markt suchen". Sektion "Deine Märkte" in schwarzer Semibold-Überschrift 17 pt, darunter eine weiße Gruppe (#FFFFFF, Radius 26) mit zwei Zeilen: grünes Häkchen #3F7A1F links, blauer Punkt #0050AA, "Lidl" in Schwarz; roter Punkt #CC071E, "REWE". Darunter Sektion "In der Nähe" mit den gleichen Zeilenformen und grauen Unterzeilen #636366 "Kaiser-Joseph-Straße · 120 m" und "Bertoldstraße · 340 m". Feine Trennlinien #C6C6C8 ab der Textkante. Keine Logos, nur Punkte und Namen, keine Schatten auf den Zeilen.

### 3.4 Was eine Liste ohne Markt zeigt

- Markt-Chip "Markt wählen".
- Angebote (Modul an): Angebote der **Lieblingsmärkte**, je Artikel höchstens eines, ausgewählt in der Reihenfolge der Lieblingsmärkte (nicht nach Preis, damit kein verdeckter Vergleich entsteht). Weil die Liste keinen Markt nennt, trägt das Schild hier vor dem Preis den 8-pt-Markenpunkt des Markts (Variante "mit Markt", E-16); VoiceOver sagt "im Angebot bei Lidl, 0,99 Euro laut Händler", das Angebots-Sheet nennt den Markt ohnehin. Ohne Lieblingsmärkte: keine Schilder.
- Abweichung von Verbesserungsliste 6c (dort "Angebote aller Märkte der Region"): Bei allen Märkten müsste pro Artikel eines von mehreren Angeboten gewählt werden; jede Regel außer einer festen, vom Nutzer gesetzten Reihenfolge wäre ein verdeckter Preisvergleich (Plan 8). Begründung in K12-03.
- Keine Ersparnis-Zeile (der Satz braucht genau einen Markt). Stattdessen höchstens einmal pro Woche die Hinweis-Zeile "Für welchen Markt ist Wocheneinkauf? Dann siehst du dessen Angebote." mit "Markt wählen".

---

## 4. Angebote in der Liste

Alle Flächen dieses Abschnitts existieren nur, wenn Modul an, Kill-Switch aus, echte Region bekannt und die Liste nicht per "Angebote für diese Liste ausblenden" ausgenommen ist. Jede Fläche hat zusätzlich ihren Einzel-Schalter (6.3).

### 4.1 Gelbes Schild am Artikel (`ItemOfferBadge`)

- **Hauptfrage:** Ist dieser Artikel diese Woche bei meinem Markt im Angebot?
- **Wann:** an der `ItemRow` in der normalen Liste und im Einkaufsmodus, im Sheet "Zutaten auf Liste" (Kapitel 13), im Wochenplan-Sheet (Kapitel 14).
- **Aufbau:** 00 12.11: gelbe Kapsel `dealTag` (#FFD60A) mit 0,5-pt-Kante `dealTagStroke`, Preis in `numberS` `onDealTag` (#1C1C1E). Rechts in der Zeile unter bzw. neben der Menge.
- **Beispiel:** "Milch · 2" mit Schild "0,99 €"; "Butter · 2" mit "1,49 €"; "Bananen · 1 kg" mit "1,29 €"; "Kaffee" mit "9,99 €".
- **Zustände:**
  - sichtbar.
  - Daten noch nicht da beim Öffnen: Das Schild erscheint nur, wenn das Angebot beim ersten Frame aus dem Cache bekannt ist (Cache pro Liste, 6 h, Teil B). Neu gefundene Angebote erscheinen erst beim nächsten Öffnen der Liste oder nach Rückkehr in den Vordergrund, nie während man liest; ist im Layout schon Platz (Zeile mit Menge rechts), blendet das Schild dort ein (`fadeReduced`), ohne die Zeilenhöhe zu ändern (K12-02).
  - Angebot abgelaufen: verschwindet beim nächsten Öffnen.
  - "Ähnliches Produkt" (Broad-Match): Schild mit führendem `questionmark.circle` 11 pt in `onDealTag`; erklärt im Sheet.
  - Preis übernommen: unverändert (der Artikel trägt den Preis, das Schild zeigt ihn weiter).
  - offline: Schild aus dem Cache bleibt, solange das Angebot laut Gültigkeit läuft.
  - Modul aus, Kill-Switch, Liste ausgenommen, Einzel-Schalter aus: entfällt ohne Platzreservierung; gespeicherte Angebotspreise am Artikel werden nicht gezeigt.
- **Interaktion:** Tippen auf das Schild öffnet das Angebots-Sheet (4.2), wachsend aus dem Schild (`springSheet` mit Ursprung am Schild). Im Einkaufsmodus hakt Tippen auf die Zeile ab; das Schild ist dort nicht separat antippbar (Fehltipps im Gehen), das Sheet kommt über Langdruck > "Angebot ansehen". Keine Haptik.
- **AX / 320 pt:** ab AX1 steht das Schild unter dem Namen neben der Menge (00 12.8); Schild wächst bis AX2. Bei 320 pt bleibt es rechts, solange der Name mindestens 120 pt behält, sonst darunter.
- **Barrierefreiheit:** im Zeilen-Element "im Angebot 0,99 Euro laut Händler"; eigene Aktion "Angebot ansehen".
- **Änderung:** ersetzt `ItemOfferChip` ("Spare X € bei {store}", Akzenttext, erscheint verspätet und macht die Zeile höher). Kein "Spare" mehr, kein Markt im Schild (der Markt steht im Chip), keine Abhängigkeit vom Korbvergleich. Dateien: `item_offer_sheet.dart` wird zu `item_offer_badge.dart` und `offer_sheet.dart` (B); `list_item_tile.dart` (A) bekommt nur den Slot; `list_category_section.dart` beobachtet `basketComparisonProvider` nicht mehr.
- **Bildbeschreibung für ChatGPT:** Ausschnitt einer weißen gruppierten Sektion (#FFFFFF, Radius 26) auf #F2F2F7, Überschrift "Milch & Käse" fett schwarz. Zeile 1: leerer grauer Abhak-Kreis (#8A8A8E, 24 pt), kleines graues Linien-Symbol eines Tropfens, "Milch" in schwarzer 17-pt-Schrift, rechts die Zahl "2" in abgerundeten Ziffern und daneben ein kleines gelbes Preisschild #FFD60A mit dunkler Schrift #1C1C1E "0,99 €". Zeile 2: "Butter" mit "2" und gelbem Schild "1,49 €". Zeile 3: "Gouda in Scheiben", darunter grau #636366 "von Lena", ohne Schild. Feine graue Trennlinien #C6C6C8 ab der Textkante, sonst keine Rahmen.

### 4.2 Angebots-Sheet

- **Hauptfrage:** Was genau ist im Angebot, und will ich den Preis übernehmen?
- **Wann:** Schild am Artikel; Zeile in "Angebote bei Lidl" (4.5); Zeile in "Angebote der Woche" (5.1); Angebots-Zeile im Vorschlags-Panel per Langdruck.
- **Aufbau (Sheet mittel, Kopf: `xmark` links, Titel "Angebot"):**
  1. Kopf-Zeile auf `surfaceElevated`: Avo Symbol der Kategorie 36 pt (`labelSecondary`), Produktname (`headline`, bricht um), darunter "Lidl · 1 l" (`subheadline`, `labelSecondary`, mit Markenpunkt).
  2. Großes Schild (Variante L, Ergänzung E-02): `dealTag`, Preis "0,99 €" in `numberL`.
  3. Sektion mit `ValueRow`s: "laut Händler statt" 1,19 € · "Grundpreis" 0,99 €/l · "Gültig" bis Sa., 14. Nov. · "Markt" ● Lidl · "Region" 79098 Freiburg. Zeilen ohne Daten entfallen (kein Vergleichspreis: Zeile fehlt; keine Gültigkeit: Zeile fehlt).
  4. Nur bei Broad-Match: Hinweis-Zeile `questionmark.circle` "Ähnliches Produkt. Prüfe vor dem Kauf, ob es zu „Milch“ passt." (`callout`, `label`).
  5. Hauptaktion (prominent): "Preis übernehmen" (aus einem Artikel) bzw. "Auf die Liste" (aus Angebote der Woche, siehe 5.2). Ist der Preis schon übernommen: graue Aktion "Übernommenen Preis entfernen".
  6. Schlicht: "Nicht dieses Angebot" (blendet dieses Angebot für diesen Artikel bis zum Ablauf aus).
  7. Weitere Angebote desselben Markts für diesen Artikel (höchstens 3) als Sektion "Weitere Angebote bei Lidl", Zeilen wie 5.1; Tippen tauscht das Angebot im Sheet.
  8. Quellen-Fußnote (Regel 9).
- **Kopf bei Push im Sheet** (aus 4.5): `chevron.left` "Angebote bei Lidl" links statt `xmark`; Wischen vom linken Rand führt zurück.
- **Beispiel:** Milbona Frische Vollmilch 3,5 % · Lidl · 1 l · 0,99 € · laut Händler statt 1,19 € · 0,99 €/l · bis Sa., 14. Nov.
- **Zustände:** Daten liegen immer vor (Sheet öffnet nur mit Angebot), kein Laden. "Preis übernehmen" ist optimistisch (00 13): Das Sheet schließt sofort, der Artikel trägt den Preis. Scheitert das Speichern, rollt der Artikel zurück, der Rückgängig-Hinweis wird zu "Preis nicht gespeichert · Erneut versuchen", Fehler-Haptik, die Zeile zeigt kurz "Nicht gespeichert" (00 12.8); nie eine rohe Ausnahme. Offline: geht in die Warteschlange (Artikel trägt das Sync-Zeichen). Angebot während des Öffnens abgelaufen: Zeile "Gültig" zeigt "abgelaufen" in `labelSecondary`, Hauptaktion deaktiviert. Modul aus oder Kill-Switch während das Sheet offen ist: Sheet schließt still beim nächsten Wechsel des Flags.
- **Interaktion:** "Preis übernehmen" schreibt `price`, `price_currency`, `price_retailer` (Ketten-ID), `price_unit`, `price_updated_at`, `price_old_value`; Sheet schließt (`springSheet`), Rückgängig-Hinweis "Preis für Milch übernommen · Widerrufen". Keine Haptik (umkehrbar, sichtbar).
- **AX / 320 pt:** Sheet geht bei AX automatisch auf groß; `ValueRow`s stapeln Wert unter Titel ab AX1; Kopf-Symbol entfällt ab AX1.
- **Änderung:** ersetzt das heutige Angebots-Sheet (Kicker "AKTUELLES ANGEBOT", Serif-Preis 26 pt, "-X %"-Abzeichen, "Spart X € gegenüber deinem gespeicherten Preis", Händlerbild, `FilledButton` 50 pt fest, rote Snackbar mit Rohtext, Datum "d.m." fest deutsch). Neu: Wortlaut "laut Händler", kein eigener Prozentwert, kein Vergleich zum eigenen Preis, Quellenfußnote, "Nicht dieses Angebot".
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe im hellen Modus, schwebend aus Liquid Glass mit 8 pt Abstand zum Rand, innen Fläche #F2F2F7. Oben links runder Glas-Knopf mit X, Titel "Angebot" mittig. Darunter eine weiße Zeile mit grauem Linien-Symbol eines Tropfens, fett "Milbona Frische Vollmilch 3,5 %" und grau #636366 "● Lidl · 1 l" mit blauem Punkt #0050AA. Darunter ein größeres gelbes Preisschild #FFD60A mit "0,99 €" in dunklen, abgerundeten Ziffern #1C1C1E. Eine weiße gruppierte Sektion mit Zeilen "laut Händler statt 1,19 €", "Grundpreis 0,99 €/l", "Gültig bis Sa., 14. Nov.", "Region 79098 Freiburg", Werte rechts in Grau. Unten eine breite gefüllte Kapsel in Avocado-Grün #3F7A1F mit weißer Schrift "Preis übernehmen", darunter grüner Textlink "Nicht dieses Angebot" und eine kleine graue Fußnote zur Quelle.

### 4.3 Angebote beim Tippen (Vorschlags-Panel, `OfferSuggestionsBar`)

- **Hauptfrage:** Ist das, was ich gerade tippe, bei meinem Markt im Angebot?
- **Wann:** Fokus im Accessory "Artikel hinzufügen" (00 12.4), ab 2 Zeichen und 300 ms Pause.
- **Aufbau:** Teil B liefert bis zu 3 Zeilen für den dritten Block des Vorschlags-Panels (nach Vorschau und Verlaufstreffern). Der Block liegt am vom Eingabefeld abgewandten Ende des Panels, also oben (Vorschlag E-17): Die Vorschau sitzt direkt über dem Feld, darüber die Verlaufstreffer, ganz oben die Angebote. So bleiben Vorschau und Verlaufstreffer an ihrer Stelle, wenn Angebote nachkommen. Zeile (`OfferRow` kompakt, E-03): Avo Symbol 28 pt, Produktname (`body`, bis 2 Zeilen), Unterzeile "Lidl · 1 l · bis Sa." (`subheadline`, `labelSecondary`), rechts gelbes Schild. Kein Kopf, kein Kicker, kein "Spare bis zu". Weitere Treffer (heute "alle Treffer erreichbar") gibt es nicht im Panel; wer mehr sucht, nutzt die Suche in Angebote der Woche (bewusst entfernt: das Panel dient dem Hinzufügen, nicht dem Stöbern).
- **Beispiel:** Eingabe "2 mi": Vorschau "Milch · Menge 2 · Milch & Käse"; Verlauf "Milch", "Mineralwasser"; Angebot "Milbona Frische Vollmilch 3,5 % · Lidl · 1 l · bis Sa." mit "0,99 €".
- **Zustände:** keine Angebote: Block entfällt ohne Platz; laden: Block entfällt bis Ergebnisse da sind, dann wächst das Panel nach oben um den Block (`springStandard`; Vorschau und Verlaufstreffer bleiben stehen, Reduce Motion: Einblenden); Fehler oder offline: Block entfällt still (das Panel bleibt nutzbar); ohne Region: höchstens einmal pro Sitzung eine Zeile "Für Angebote in deiner Region: Postleitzahl festlegen" (`location`, `warning`), Tippen öffnet das Region-Sheet (6.1), Tastatur bleibt.
- **Interaktion:** Tippen fügt "Milch" mit Menge 2 hinzu und hängt das Angebot (Preis, Händler, Einheit, Vergleichspreis) an den Artikel; der Artikel heißt so, wie der Nutzer tippt ("Milch"), nicht wie das Produkt (vermeidet "Milch" plus "Milbona Frische Vollmilch 3,5 %"). Steht "Milch" schon offen auf der Liste, wird das Angebot nur angehängt ("Angebot an Milch angehängt · Widerrufen"). Langdruck öffnet das Angebots-Sheet. Fokus bleibt im Feld. Haptik: keine (Hinzufügen hat keine).
- **AX / 320 pt:** Zeilen brechen um; ab AX1 Schild unter dem Namen, Symbol entfällt; das Panel scrollt intern, wenn es höher als der Platz über der Tastatur wird (höchstens 5 Zeilen gesamt, 00 12.4).
- **Änderung:** ersetzt die Karte über der Eingabe (feste Zeilenhöhe 72 pt, Kicker "ANGEBOTE IN DER NÄHE", "Spare bis zu X €" gegen den teuersten Treffer, alle Märkte, Händlerbilder, Plus 26 pt, Layout-Sprung). Nur Markt der Liste. Datei `offer_suggestions_bar.dart` (B) wird zum Zeilen-Lieferanten; `list_detail_screen.dart` (A) verliert Höhenmessung und `_addItemFromOffer`.
- **Bildbeschreibung für ChatGPT:** Unterer Teil eines iPhones im hellen Modus mit offener Tastatur. Direkt auf der Tastatur eine Liquid-Glass-Kapsel mit Plus-Symbol und dem getippten Text "2 mi". Darüber ein weißes, fest gefülltes Vorschlags-Panel (#FFFFFF, Radius 20, weicher Schatten) mit Zeilen von oben nach unten: eine Zeile mit grauem Tropfen-Symbol, "Milbona Frische Vollmilch 3,5 %" in Schwarz und grau #636366 "Lidl · 1 l · bis Sa.", rechts ein kleines gelbes Preisschild #FFD60A mit dunkler Schrift #1C1C1E "0,99 €"; dann "Mineralwasser" und "Milch" mit grauem Uhr-Symbol; ganz unten, direkt über dem Feld, "Milch · Menge 2 · Milch & Käse" in Schwarz. Feine Trennlinien #C6C6C8. Kein Glas im Panel, keine Großbuchstaben, keine Prozentangaben.

### 4.4 Ersparnis-Zeile der Liste (`ListOfferSummary`)

- **Hauptfrage:** Wie viel von meiner Liste ist diese Woche bei meinem Markt im Angebot?
- **Wann:** Startseite = Liste von heute, als `HintRow` in "Für heute" (00 12.12, höchstens 2 Hinweise, Reihenfolge nach Relevanz durch Teil A).
- **Aufbau:** `HintRow`: `tag` 16 pt in `labelSecondary`, Text in `callout` `label` (bis 3 Zeilen), rechts `chevron.right`. Text gemäß Regel 3 und 5.
- **Beispiel:** "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region". Ohne Händler-Vergleichspreise: "4 von 11 Artikeln diese Woche bei Lidl im Angebot, in deiner Region". Nur 1 Angebot: "1 von 11 Artikeln …" (Plural über ICU).
- **Zustände:** ohne Angebote (0 von 11): Zeile entfällt. Ohne Region: an ihrer Stelle die Zeile "Für Angebote in deiner Region: Postleitzahl festlegen" (`location` in `warning`, Aktion "Festlegen"), höchstens einmal pro Woche nach Wegwischen. Ohne Listen-Markt: 3.4. Zahl ändert sich (abgehakt, hinzugefügt): Ziffern rollen (`springDigits`, tabellarisch, die Zeile ändert ihre Höhe nicht); ob die Zeile überhaupt erscheint oder verschwindet, steht beim ersten Frame fest und ändert sich erst beim nächsten Öffnen (00 12.12). Fällt die Ersparnis während des Lesens unter 0,50 €, bleibt der Satz bis zum nächsten Öffnen mit dem gerundeten Wert stehen. Offline: Zeile aus dem Cache, unverändert. Modul/Kill-Switch/Liste ausgenommen/Einzel-Schalter "Ersparnis in der Liste" aus: entfällt.
- **Zählweise:** "von 11" = offene Artikel der Liste; abgehakte zählen nicht mehr mit (im Einkaufsmodus zählt die Zeile nicht, dort erscheint sie nicht).
- **Interaktion:** Tippen öffnet "Angebote bei Lidl" (4.5). Wischen nach links "Ausblenden" (für diese Woche), Kontextmenü "Diese Woche ausblenden", "Nicht mehr zeigen" (schaltet den Einzel-Schalter aus, mit Rückgängig-Hinweis "Ersparnis-Zeile ausgeschaltet · Widerrufen").
- **AX / 320 pt:** bricht um, bis 3 Zeilen bei L; ab AX1 unbegrenzt (Hinweis-Zeilen kürzen nie). Bei 320 pt: 3 Zeilen.
- **Änderung:** ersetzt `ListPriceSummaryBar` ("X € günstigster Korb", "bekannt (k/n)", Marktvergleich-Sheet, PLZ-Chip) und `PriceComparisonNudgeCard` ("ist bei A 2,30 € günstiger als bei B"). Beide Dateien werden gelöscht, ebenso `basketComparisonProvider`, `homePriceHighlightProvider`, `comparableTotal`, `closestReasonableAlternative`, `home_price_comparison_cache_service.dart`. Rechnung über Grundpreis (`referencePrice`) statt Packungspreis. Neue Datei `list_offer_summary.dart` (B).
- **Bildbeschreibung für ChatGPT:** Oberer Teil eines iPhones im hellen Modus, Hintergrund #F2F2F7. Großer fetter Titel "Wocheneinkauf" mit Chevron, darunter die graue Kapsel "● Lidl" mit blauem Punkt #0050AA und grau "11 offen · mit Lena". Darunter eine weiße gruppierte Sektion (#FFFFFF, Radius 26) mit dem Titel "Für heute": eine Zeile mit kleinem grauem Etikett-Symbol #636366 und schwarzem Text in 16 pt "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region", rechts ein grauer Chevron. Der Text steht über zwei Zeilen, in voller Textfarbe, ohne Grün, ohne Gelb. Darunter beginnt die Sektion "Obst & Gemüse" mit Bananen und Avocados.

### 4.5 Sheet "Angebote bei Lidl" (`/offers/list/:listId`)

- **Hauptfrage:** Welche Artikel meiner Liste sind bei Lidl im Angebot?
- **Wann:** Ersparnis-Zeile; Listenmenü `ellipsis` > "Angebote dieser Liste"; Avo ("Was ist auf meiner Liste im Angebot?" > "Ansehen").
- **Aufbau (Sheet mittel, Kopf `xmark`, Titel "Angebote bei Lidl"):**
  1. Satz (`callout`, `label`): der Ersparnis-Satz aus 4.4.
  2. Sektion "Auf deiner Liste" (`headline`, rechts Anzahl "4"): Zeilen je Artikel: Avo Symbol 28 pt, Artikelname (`body`: "Milch · 2"), Unterzeile Produkt und Gültigkeit ("Milbona Frische Vollmilch 3,5 % · 1 l · bis Sa., 14. Nov."), darunter "laut Händler statt 1,19 €" (`subheadline`, `labelSecondary`), rechts gelbes Schild. Reihenfolge wie in der Liste (Reihenfolge im Markt), nicht nach Rabatt.
  3. Sektion "Diese Woche bei Lidl, oft gekauft" (nur mit Einzel-Schalter "Spar-Hinweise auf der Startseite" an): bis 3 Stammartikel, die nicht auf der Liste stehen, mit `plus.circle`-Knopf (44-pt-Ziel) rechts neben dem Schild. Im Beispiel: Saskia Mineralwasser still, 6 × 1,5 l, "1,49 €".
  4. Schlicht (`action`): "Alle Angebote der Woche" (schließt das Sheet und pusht `/offers` im Tab Liste).
  5. Schlicht (`action`, mit `eye.slash`): "Angebote für diese Liste ausblenden". Kein Rot: die Aktion ist umkehrbar und löscht nichts.
  6. Fußnote: Ersparnis-Erklärung "Gespart = Unterschied zu den „statt“-Preisen der Händler, über den Grundpreis und deine Mengen gerechnet. Ungefährer Wert." plus Quellen-Fußnote (Regel 9).
- **Zustände:** wie 4.4; offline: Inhalt aus dem Cache plus `StatusRow` "Offline. Angebote vom Stand Fr., 6. Nov., 19:10."; Fehler beim Aktualisieren: Inhalt bleibt, `StatusRow` "Angebote konnten gerade nicht aktualisiert werden. Erneut versuchen". Keine Angebote mehr (alles abgehakt): `EmptyState` ohne Maskottchen (Geld-Kontext): `tag` 48 pt Light, "Gerade nichts im Angebot.", "Neue Angebote kommen meist am Montag."
- **Interaktion:** Tippen auf eine Zeile öffnet das Angebots-Sheet als Push im Sheet (Sheets stapeln höchstens zweimal, 01 6). `plus` setzt den Stammartikel mit Angebot auf die Liste, Zeile wandert mit `springMove` in die obere Sektion, Ziffern "5 von 12" rollen, Rückgängig-Hinweis. "Ausblenden" wirkt sofort: Sheet schließt, alle Schilder und die Ersparnis-Zeile dieser Liste verschwinden mit `springStandard`, Rückgängig-Hinweis "Angebote für Wocheneinkauf ausgeblendet · Widerrufen".
- **AX / 320 pt:** Sheet öffnet bei AX groß; Zeilen stapeln (Schild unter dem Text).
- **Änderung:** neu (heute gibt es nur den verworfenen Marktvergleich). Datei `list_offers_sheet.dart` (B).
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe, Liquid-Glass-Rand, innen #F2F2F7. Oben X-Knopf aus Glas und Titel "Angebote bei Lidl". Darunter ein schwarzer Satz in 16 pt "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region". Eine weiße Sektion "Auf deiner Liste" mit vier Zeilen, je mit grauem Linien-Symbol, schwarzem Namen ("Bananen · 1 kg", "Milch · 2", "Butter · 2", "Kaffee"), grauen Unterzeilen wie "Milbona Frische Vollmilch 3,5 % · 1 l · bis Sa., 14. Nov." und "laut Händler statt 1,19 €", rechts je ein kleines gelbes Preisschild #FFD60A mit dunkler Schrift #1C1C1E ("1,29 €", "0,99 €", "1,49 €", "9,99 €"). Darunter eine weiße Sektion "Diese Woche bei Lidl, oft gekauft" mit einer Zeile "Saskia Mineralwasser still, 6 × 1,5 l", gelbem Schild "1,49 €" und grünem Plus-im-Kreis #3F7A1F. Unten zwei grüne Textlinks #3F7A1F "Alle Angebote der Woche" und "Angebote für diese Liste ausblenden" mit durchgestrichenem Auge, darunter eine kleine graue Fußnote #636366. Keine Prozente, kein Rot.

### 4.6 "Angebote für diese Liste ausblenden"

- Ort: Listenmenü `ellipsis` (Kapitel 11, Slot `setOffersHiddenForList`), Listen-Info ("Angebote anzeigen" als `ToggleRow`), Sheet 4.5, Avo.
- Wirkung: sofort, pro Liste, im Konto gespeichert (für alle Geräte dieser Person, nicht für andere Mitglieder). Rückgängig-Hinweis. Die Liste erscheint in "Preise & Angebote" unter "Ausgeblendet für" (6.3).
- Ist das Modul aus, steht der Menüeintrag nicht im Menü (spurlos).

---

## 5. Angebote der Woche (`/offers`)

### 5.1 Screen

- **Hauptfrage:** Was von meinen Sachen ist diese Woche im Angebot?
- **Wann:** Alle Listen > Sektion "Sparen" > "Angebote der Woche" ("6 passen zu deinen Listen"); Hinweis-Zeile "3 Sachen, die du oft kaufst, sind diese Woche im Angebot" (öffnet mit Segment "Oft gekauft", Route `/offers?filter=regulars`); Sheet 4.5; Avo; Suche ("Angebote").
- **Aufbau (Push, großer Titel, E-06):**
  1. `LargeTitleNavBar` "Angebote der Woche", darunter Metazeile (`subheadline`, `labelSecondary`): "In deiner Region · 79098 Freiburg" als schlichter Knopf (öffnet Region-Sheet).
  2. `SearchField` "Angebote suchen".
  3. `SegmentedControl` (00 12.18) "Deine Listen" | "Oft gekauft" (K12-13). Jedes Segment beantwortet eine Frage: "Was von meinen Listen ist im Angebot?" bzw. "Was kaufe ich oft, das gerade im Angebot ist?". Ist der Einzel-Schalter "Spar-Hinweise auf der Startseite" aus, entfällt das Segment ganz und nur "Deine Listen" bleibt.
  4. Markt-Chips (`FilterChip` mit Markenpunkt, E-09, Einfachauswahl, waagerecht scrollend): "● Lidl", "● Kaufland", "● REWE" (Listen-Märkte und Lieblingsmärkte, in dieser Reihenfolge). Ohne gewählten Chip gelten alle; erneutes Tippen auf den gewählten Chip hebt die Auswahl auf. Märkte filtern nur, sie werden nie gegeneinander gestellt.
  5. Segment "Deine Listen" (Standard): eine Sektion pro Liste mit Markt (höchstens die 2 zuletzt geänderten Listen mit offenen Artikeln, Kostenbremse): Titel "Wocheneinkauf · Lidl" (`headline`, Markenpunkt vor "Lidl"), rechts "4"; Zeilen (`OfferRow`, E-03): Avo Symbol 28 pt, Produktname (`body`), Unterzeile 1 "Für „Milch“ auf Wocheneinkauf" (nur wenn der Produktname vom Artikel abweicht), Unterzeile 2 "1 l · 0,99 €/l · laut Händler statt 1,19 €", Unterzeile 3 nur bei 3 Kalendertagen oder weniger (lokale Zeit, nicht 24-h-Blöcke in UTC wie heute): "endet morgen" bzw. "endet heute" (`labelSecondary`, keine Warnfarbe), bei Broad-Match "Ähnliches Produkt"; rechts gelbes Schild.
  6. Segment "Oft gekauft" (persönlicher Prospekt): Stammartikel aus der Kaufstatistik, die nicht offen auf einer Liste stehen, je bei dem Markt, bei dem man sie meist kauft (`preferred_retailer`), sonst beim ersten Lieblingsmarkt; Unterzeile "● REWE · Kaufst du etwa alle 10 Tage". Kein Marktwechsel wegen Preis (behebt `pickOffer` "anderer Markt mehr als 0,50 € günstiger"). Kostenbremse wie heute: höchstens 6 Angebotssuchen pro 6 h. Die Regeln aus `AvoNudgeService` bleiben (mindestens 2 Käufe, Rhythmus 2 bis 60 Tage, nur Kopfwort-Treffer: "Milchreis" ist keine Milch).
  7. Quellen-Fußnote (Regel 9).
- **Beispiel:**
  - Segment "Deine Listen", "Wocheneinkauf · ● Lidl" (4): Bananen, 1 kg · 1,29 €/kg · laut Händler statt 1,79 € · "1,29 €"; Milbona Frische Vollmilch 3,5 % · Für „Milch“ auf Wocheneinkauf · 1 l · 0,99 €/l · laut Händler statt 1,19 € · "0,99 €"; Milbona Deutsche Markenbutter · Für „Butter“ auf Wocheneinkauf · 250 g · 5,96 €/kg · laut Händler statt 2,29 € · "1,49 €"; Barissimo Kaffee Crema · Für „Kaffee“ auf Wocheneinkauf · 1 kg · laut Händler statt 10,69 € · "9,99 €" (alle gültig bis Sa., 14. Nov., daher ohne Ablaufzeile).
  - "Grillabend · ● Kaufland" (2): Grillwürstchen, 400 g · "2,99 €"; Halloumi, 225 g · endet morgen · "1,99 €".
  - Segment "Oft gekauft" (3): Kölln Zarte Haferflocken, 500 g · ● REWE · Kaufst du etwa alle 10 Tage · "1,49 €"; Weihenstephan Joghurt mild 3,5 %, 500 g · ● REWE · etwa alle 7 Tage · "0,99 €"; Saskia Mineralwasser still, 6 × 1,5 l · ● Lidl · etwa alle 14 Tage · "1,49 €".
- **Suche (ab 2 Zeichen, 300 ms entprellt):** Während der Suche blendet das Segment aus (`fadeReduced`), die Markt-Chips bleiben. Ergebnisse ersetzen den Inhalt darunter, gruppiert nach Markt in der Reihenfolge Listen-Märkte, Lieblingsmärkte, dann alphabetisch (nie nach Preis, kein Hinweis auf den niedrigsten Preis). Innerhalb eines Markts nach Relevanz (`isRelevantMatch`: exakter Treffer vor Stamm-Treffer). Sektionskopf pro Markt "● Lidl" mit Anzahl. Ein Markt-Chip schränkt ein.
- **Zustände:**
  - erster Start ohne Region: `EmptyState` ohne Maskottchen: `location` 48 pt Light, Titel "Wo kaufst du ein?", Satz "Angebote gelten pro Region. Mit deiner Postleitzahl siehst du, was bei deinen Märkten im Angebot ist.", prominent "Standort verwenden", schlicht "Postleitzahl eingeben". Suchfeld, Segment und Chips entfallen bis dahin (keine Anfragen ohne Region).
  - keine Listen-Treffer: Sektion entfällt; sind alle leer: `EmptyState` `tag` 48 pt Light, "Gerade nichts von deinen Listen im Angebot.", "Suche oben nach einem bestimmten Produkt."; Segment "Oft gekauft" leer: "Gerade ist nichts im Angebot, was du oft kaufst." (noch keine Kaufstatistik: "Nach ein paar Einkäufen siehst du hier, was du oft kaufst und gerade im Angebot ist."); Suche ohne Treffer: Maskottchen "suchend" 96 pt erlaubt (es geht um eine Suche, nicht um Beträge; ab AX1 ohne Maskottchen), "Kein Angebot für „Hummus“ in deiner Region."
  - Liste ohne Markt: ihre Sektion heißt "Drogerie · Lieblingsmärkte" und zeigt pro Artikel höchstens ein Angebot nach 3.4, mit Markenpunkt in der Unterzeile.
  - lädt beim allerersten Öffnen: Skelett in Form der Zeilen als `fill`-Flächen ohne Schimmer, Sektion für Sektion ersetzt; Teilergebnisse erscheinen sofort (heute: Spinner, bis alle 10 Suchen fertig sind).
  - später: sofort aus dem Cache (6 h), Abgleich im Hintergrund; neue Zeilen erscheinen nur unterhalb der Leseposition bzw. beim nächsten Öffnen.
  - offline: Cache plus `StatusRow` "Offline. Angebote vom Stand Fr., 6. Nov., 19:10."; Suche nur im Cache, darüber "Offline. Es werden nur gespeicherte Angebote gezeigt."
  - Fehler (Quelle nicht erreichbar): `StatusRow` "Angebote konnten gerade nicht geladen werden. Erneut versuchen" in der betroffenen Sektion; nie als "keine Angebote" (behebt Bug 9: `searchOffers` liefert künftig Ergebnis mit Status `ok | leer | fehler`).
  - Modul aus: Route öffnet das Modul-Sheet "Preise & Angebote ist ausgeschaltet" (10.3). Kill-Switch: Fehlerseite ohne Angebotsbezug (01 7).
  - Pro: nie.
- **Interaktion:** Tippen auf eine Zeile öffnet das Angebots-Sheet (4.2) mit Hauptaktion "Auf die Liste". `plus` rechts (44-pt-Ziel, schlichtes Symbol `plus.circle` in `action`) setzt direkt auf die Liste der Sektion; in "Oft gekauft" und in der Suche öffnet `plus` das Menü "Auf welche Liste?" (5.2), das aus dem Knopf wächst. Wischen nach rechts auf einer Zeile: "Auf die Liste" (Auslöse-Schwelle mit leichtem Impuls). In "Oft gekauft" zusätzlich Wischen nach links bzw. Kontextmenü "Nicht interessiert": blendet dieses Angebot bis zu seinem Ablauf aus, höchstens 7 Tage (Schlummer-Regel von heute), mit Rückgängig-Hinweis. Segment und Chips: `springQuick`, Inhalt wechselt per Überblendung; Segment-Wechsel per Wischen mit Auswahl-Haptik. Ziehen nach unten am Anfang: Aktualisieren (System-Verhalten, selten nötig).
- **AX / 320 pt:** Chips ab xxL als `Wrap`; Segment wird ab AX1 zum Pull-down "Zeigen: Deine Listen" (00 12.18), wenn die Beschriftungen nicht in eine Zeile passen; Zeilen stapeln ab AX1 (Schild unter dem Text, Symbol entfällt, `plus.circle` rechts oben bündig zur ersten Zeile). Bei 320 pt: Unterzeilen brechen um, Schild bleibt rechts bis L, darüber darunter; Segment passt bei L in eine Zeile (zwei kurze Wörter je Segment).
- **Änderung gegenüber heute:** `weekly_deals_screen.dart` (Material-AppBar, Serif-Titel, eigenes Suchfeld mit Rahmen, Kicker "PASSEND ZU DEINEN LISTEN", `_DealCard` mit Rahmen und Händlerbild, "-X %"-Abzeichen, Sortierung nach eigenem Rabatt, alle Märkte gemischt, Vollflächen-Spinner, Offline sieht aus wie leer, kein Modul-Schalter) wird ersetzt durch `screens/offers/weekly_offers_screen.dart` (B) mit Route `/offers`. `personalized_deals_service.dart` sortiert nach Listen-Reihenfolge statt Rabatt-%; Prospekt (`personal_flyer_card.dart`) geht in das Segment "Oft gekauft" und die Hinweis-Zeile über; die Schlummer-Logik der Avo-Karte für Angebote (`avo_nudge_card.dart`) wird zu "Nicht interessiert".
- **Bildbeschreibung für ChatGPT:** iPhone im hellen Modus, Hintergrund #F2F2F7, oben links ein runder Liquid-Glass-Zurück-Knopf. Großer fetter Titel "Angebote der Woche", darunter grau #636366 "In deiner Region · 79098 Freiburg". Ein graues Suchfeld #E9E9EE "Angebote suchen", darunter ein Segment-Schalter mit grauer Kapsel-Spur #E9E9EE und weißem Daumen auf "Deine Listen", daneben "Oft gekauft". Darunter eine Reihe grauer Kapsel-Chips #E9E9EE, keiner gewählt: "● Lidl" mit blauem Punkt #0050AA, "● Kaufland" mit rotem Punkt #E10915, "● REWE" mit rotem Punkt #CC071E. Sektion "Wocheneinkauf · ● Lidl" mit weißer Gruppe (#FFFFFF, Radius 26): Zeilen mit grauen Linien-Symbolen, schwarzen Produktnamen wie "Milbona Frische Vollmilch 3,5 %", grauen Unterzeilen "Für „Milch“ auf Wocheneinkauf" und "1 l · 0,99 €/l · laut Händler statt 1,19 €", rechts gelbe Preisschilder #FFD60A und daneben ein grünes Plus-im-Kreis-Symbol. Keine Produktfotos, keine Prozent-Abzeichen, unten schwebt die Glas-Tab-Bar mit dem runden Avo-Knopf (braune Kugel #7A4A24 im Ring #C9DE6E).

### 5.2 Menü "Auf welche Liste?"

- **Hauptfrage:** Auf welche Liste soll das?
- **Aufbau:** `AppMenu` aus dem `plus.circle`-Knopf (`springMenu`, Ursprung am Knopf): ganz oben die Liste von heute, dann weitere Listen nach zuletzt geändert (Menüvariante der `ListRow`: Glyph, Name, darunter der Markt der Liste in `labelSecondary`, z. B. "Grillabend", darunter "Kaufland"), Trenner, "Neue Liste …" (`plus`). Kein `checkmark`: Das Menü wählt ein Ziel, es zeigt keinen Zustand. Gilt das Angebot nicht für den Markt einer Liste, lautet deren Unterzeile "Lidl · Angebot gilt dort nicht"; die Liste bleibt wählbar (dann kommt nur der Artikel auf die Liste, ohne Angebot; der Rückgängig-Hinweis sagt es).
- **Wirkung:** Passt das Angebot zu einem offenen Artikel der Ziel-Liste, wird es angehängt statt dupliziert ("Angebot an Milch auf Wocheneinkauf angehängt · Widerrufen"); sonst neuer Artikel mit dem einfachen Artikelnamen aus der Zuordnung (Kategorie-Wort, z. B. "Haferflocken") und, wenn der Markt passt, dem Angebot. "Neue Liste …" öffnet das Neue-Liste-Sheet (Kapitel 11) mit dem Markt des Angebots vorausgewählt; danach landet der Artikel dort.
- **Zustände:** nur eine Liste: Menü zeigt sie und "Neue Liste …"; keine Liste: nur "Neue Liste …"; offline: Hinzufügen geht in die Warteschlange (Sync-Zeichen am Artikel); Fehler: Rückgängig-Hinweis wird zu "Nicht hinzugefügt · Erneut versuchen", Fehler-Haptik.
- **AX / 320 pt:** Menüzeilen brechen um, Mindesthöhe 44; das Menü scrollt intern, wenn es höher als der Bildschirm wird (heute läuft das Sheet über); Glyph entfällt ab AX1.
- **Änderung:** ersetzt `_AddDealSheet` (Material-Sheet, blaue Wagen-Symbole, ohne Vorauswahl, legt Duplikate an, Rohfehler-Snackbar).
- **Bildbeschreibung für ChatGPT:** Ausschnitt aus "Angebote der Woche" im hellen Modus auf #F2F2F7, Segment "Oft gekauft" gewählt. Aus dem grünen Plus-im-Kreis #3F7A1F rechts in der weißen Zeile (#FFFFFF) "Kölln Zarte Haferflocken" mit gelbem Schild #FFD60A "1,49 €" wächst ein milchiges Liquid-Glass-Menü mit 20 pt Eckenradius. Oben die Zeile "Wocheneinkauf" mit grünem Listenkreis #34C759 und weißem Wagen-Symbol, darunter grau #636366 "Lidl · Angebot gilt dort nicht". Darunter "Grillabend" mit orangem Listenkreis #FF9500 und grau "Kaufland · Angebot gilt dort nicht", dann ein 8-pt-Trennband und "Neue Liste …" mit Plus-Symbol. Schrift schwarz #000000, 17 pt, keine Häkchen, ruhige Anordnung.

---

## 6. Region und Einstellungen

### 6.1 Sheet "Region für Angebote"

- **Hauptfrage:** Für welche Region sollen Angebote gelten?
- **Wann:** Hinweis-Zeile ohne PLZ, Metazeile in Angebote der Woche, Einstellungen > Region, Vorschlags-Panel, Avo ("Setz meine PLZ auf 79098"). Inhalt gleich im Onboarding-Schritt `OffersSetupStep` (dort als Seite, Kapitel 17).
- **Aufbau (Sheet mittel, Kopf `xmark`, "Region", `checkmark` getönt rechts, aktiv sobald 5 Ziffern):**
  1. Satz (`body`, `label`): "Angebote gelten pro Region, nicht pro Markt. Deine Postleitzahl bleibt bei uns und der Angebotsquelle."
  2. Sektion: Zeile "Standort verwenden" (`location`, `action`, schlicht) mit Unterzeile "Aktuell: 79098 Freiburg im Breisgau" bzw. "Fragt einmal nach deinem Standort".
  3. Sektion: Feld "Postleitzahl" (Ziffernblock, genau 5 Ziffern, `number`), darunter live der Ort ("79098 · Freiburg im Breisgau", lokal aus einer PLZ-Tabelle).
  4. Nur wenn eine PLZ gesetzt ist: schlicht destruktiv "Region entfernen" (`danger`, ohne Rückfrage, mit Rückgängig).
- **Zustände:** Standort abgelehnt: Zeile 2 wird `StatusRow` "Standort ist aus. In Einstellungen erlauben" plus Feld bleibt; ungültig (4 Ziffern, keine deutsche PLZ): Text unter dem Feld "Bitte 5 Ziffern eingeben." bzw. "Diese Postleitzahl kennen wir nicht." mit `exclamationmark.circle` in `danger`, `checkmark` deaktiviert; Standort im Ausland: "Angebote gibt es nur für Deutschland." Offline: Speichern lokal, gilt sofort.
- **Vorab-Erklärung Standort** (00 13, beim ersten "Standort verwenden"): Sheet mittel, das auf dem Region-Sheet liegt (zweite Sheet-Ebene, 01 6), mit `location` 48 pt Light, Titel "Standort für Angebote" und Satz "Damit die App deine Postleitzahl für Angebote findet und vorschlagen kann, in welchem Markt du gerade bist. Nur, während du die App benutzt.", prominent "Weiter", schlicht "Nicht jetzt"; danach Systemabfrage "Beim Verwenden der App". (Die übrige Oberfläche spricht nicht als Avo, 00 3.2.)
- **Interaktion:** Speichern schließt das Sheet; alle Angebotsflächen nutzen sofort die neue Region (ein gemeinsamer Provider `regionProvider` ersetzt `userZipCodeProvider` und `effectiveZipProvider`, behebt "PLZ-Änderung wirkt nicht überall"). Rückgängig-Hinweis "Region: 79098 Freiburg · Widerrufen".
- **AX / 320 pt:** Sheet geht auf groß; Feld wächst mit der Schrift (Mindesthöhe, keine feste Höhe).
- **Änderung:** ersetzt `zip_code_sheet.dart` (Serif-Titel, 50-pt-Button fest, unter 4 Ziffern ohne Rückmeldung, kein Löschen, nur ein Provider invalidiert) und `showManualZipDialog`; die PLZ wandert aus "Persönliche Daten" hierher (01 5.8). Ersatz-PLZ 10115 entfällt in der Oberfläche (K12-01).
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe aus Liquid Glass, innen #F2F2F7. Oben links X-Glasknopf, mittig "Region", rechts ein grün getönter runder Glasknopf mit Häkchen. Darunter schwarzer Satz #000000 in 17 pt "Angebote gelten pro Region, nicht pro Markt. Deine Postleitzahl bleibt bei uns und der Angebotsquelle." Eine weiße Gruppe (#FFFFFF, Radius 26) mit der Zeile "Standort verwenden" in Grün #3F7A1F mit Pfeil-Symbol und grauer Unterzeile #636366 "Aktuell: 79098 Freiburg im Breisgau". Darunter eine weiße Gruppe mit der Beschriftung "Postleitzahl" und rechts der Zahl "79098" in abgerundeten Ziffern, darunter grau #636366 "79098 · Freiburg im Breisgau". Unten eine geöffnete Ziffern-Tastatur. Kein Maskottchen, keine Karte.

### 6.2 Hinweis-Zeilen dieses Bereichs (Inhalte für 00 12.12)

Alle als `HintRow`, Anordnung und Höchstzahl (2) durch Teil A, Inhalt und Bedingungen durch Teil B. Geld-Zeilen ohne Maskottchen.

| Zeile | Text | Aktion | Bedingung | Modul |
|---|---|---|---|---|
| Ersparnis | "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" | `chevron.right` > 4.5 | Listen-Markt, echte Region, mindestens 1 Angebot | Angebote |
| Region fehlt | "Für Angebote in deiner Region: Postleitzahl festlegen" (`location` in `warning`) | "Festlegen" > 6.1 | keine echte Region; nach Wegwischen 7 Tage Pause | Angebote |
| Markt fehlt | "Für welchen Markt ist Wocheneinkauf? Dann siehst du dessen Angebote." | "Markt wählen" > 3.1-Menü | Liste ohne Markt, höchstens 1-mal pro Woche | Angebote |
| Prospekt | "3 Sachen, die du oft kaufst, sind diese Woche im Angebot" | `chevron.right` > `/offers?filter=regulars` | mindestens 3 Stammartikel im Angebot bei ihrem meist genutzten Markt bzw. Lieblingsmarkt; Einzel-Schalter "Spar-Hinweise auf der Startseite"; nach Ausblenden Pause bis zum Ablauf der Angebote, höchstens 7 Tage | Angebote |
| Markt-Vorschlag | "Du bist bei Lidl. Lidl-Liste öffnen?" | "Öffnen" | Standort erlaubt, eindeutiger Markt, Liste mit diesem Markt existiert und ist nicht die Liste von heute | Kern |
| Markt lernen | "Du warst zweimal mit Wocheneinkauf bei Lidl. Als Markt festlegen?" | "Festlegen" | Liste ohne `user`-Markt, zwei Abschlüsse beim selben Markt | Kern |
| Einkauf teilen | "Wocheneinkauf mit Lena teilen? 42,80 €" (ohne Betrag: "Wocheneinkauf von heute mit Lena teilen?") | "Teilen" > 9.1 | eigener oder fremder Einkauf der letzten 7 Tage auf geteilter Liste, noch nicht geteilt, nicht weggewischt (pro Einkauf) | Kosten teilen |
| Offener Betrag (einer) | "Lena schuldet dir 21,40 € · Wocheneinkauf" bzw. "Du schuldest Lena 11,58 € · Wocheneinkauf" | "Bezahlt" bzw. "Zurückgezahlt" | genau ein offener Anteil | Kosten teilen |
| Offene Beträge (mehrere) | "3 offene Beträge · dir werden 34,60 € geschuldet, du schuldest 11,58 €" (fehlt eine Richtung, entfällt ihr Teil) | `chevron.right` > 9.3 | mehr als ein offener Anteil | Kosten teilen |
| Kosten teilen einschalten | "Kosten teilen einschalten? Praktisch für gemeinsame Einkäufe." | "Einschalten" (mit Rückgängig-Hinweis) | einmalig nach dem ersten Teilen einer Liste, Modul aus | Kern (Vorschlag für das Modul) |

Ersetzte Dateien (alle B): `pending_splits_banner.dart`, `split_trip_nudge_card.dart`, `personal_flyer_card.dart` und der Angebots-Teil von `avo_nudge_card.dart` werden je ein `HintRow`-Inhalt; `price_comparison_nudge_card.dart` entfällt ersatzlos. Die Teilen-Hinweis-Bedingung gilt künftig auch für Einkäufe anderer Mitglieder (heute nur eigene, Bug 12) und das Ausblenden wird pro Einkauf im Konto gespeichert (heute eine ID gerätweit).

"Bezahlt" in der Hinweis-Zeile wirkt sofort (optimistisch), die Zeile verschwindet mit `springStandard`, Rückgängig-Hinweis "Als bezahlt markiert · Widerrufen". Bei Fehler kommt die Zeile zurück, `StatusRow`-Text in der Zeile "Nicht gespeichert. Erneut versuchen", Fehler-Haptik.

**Bildbeschreibung für ChatGPT (Startseiten-Ausschnitt mit zwei Hinweis-Zeilen):** iPhone im hellen Modus, Hintergrund #F2F2F7, großer fetter Titel "Wocheneinkauf" mit Chevron und rechts ein runder Profil-Avatar ohne Glas. Darunter die graue Kapsel "● Lidl" (#0050AA-Punkt) und grau "11 offen · mit Lena". Eine weiße Sektion "Für heute" mit zwei Zeilen: erste mit grauem Etikett-Symbol und schwarzem Text "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" und Chevron; zweite mit grauem Euro-Kreis-Symbol #636366 und schwarzem Text "3 offene Beträge · dir werden 34,60 € geschuldet, du schuldest 11,58 €", rechts ein grauer Chevron. Beide Texte über zwei Zeilen in 16 pt, volle Textfarbe #000000, getrennt durch eine feine Linie #C6C6C8 ab der Textkante. Darunter beginnt die Sektion "Obst & Gemüse". Keine Karten, keine Banner, kein Maskottchen, kein Grün außer bei Bedienelementen.

### 6.3 Einstellungen "Preise & Angebote" (`/settings/offers`)

- **Hauptfrage:** Was zeigt mir die App zu Angeboten und Märkten, und woher weiß sie es?
- **Wann:** Profil-Sheet > "Preise & Angebote" (weit oben, 01 4); Einstellungen > Module (Zeile "Preise & Angebote" führt hierher); Suche ("PLZ", "Postleitzahl", "Region", "Angebote", "Prospekt", "Markt", "Sparen"); Avo. "Nicht mehr zeigen" an einer Hinweis-Zeile navigiert nicht hierher, schaltet aber den passenden Schalter dieser Seite aus (sichtbar beim nächsten Besuch).
- **Aufbau (Push im Profil-Sheet, großer Titel "Preise & Angebote", `InsetSection`s):**
  1. Sektion ohne Titel: `ToggleRow` `tag` "Preise & Angebote" mit Unterzeile "Angebote deiner Märkte in Listen und beim Hinzufügen". Fuß: Quellen-Fußnote (Regel 9).
  2. Sektion "Region": `NavRow` `location` "Region" Wert "79098 Freiburg · Standort" > 6.1. Ohne Region: Wert "Nicht festgelegt" mit `exclamationmark.triangle.fill` in `warning` davor (Symbol plus Text).
  3. Sektion "Märkte" (Kern, auch bei Modul aus): `NavRow` `storefront` "Lieblingsmärkte" Wert "Lidl, REWE" > 6.4; `ToggleRow` "Markt automatisch erkennen" Unterzeile "Aus Listenname und deinen Einkäufen. Mit Standort auch, in welchem Markt du gerade bist. Immer nur als Vorschlag."
  4. Sektion "Anzeigen" (nur Modul an; klappt beim Ausschalten mit `springStandard` zusammen): `ToggleRow`s, alle Standard an: "Angebote in Listen" (gelbe Schilder), "Vorschläge beim Tippen", "Ersparnis in der Liste" ("4 von 11 im Angebot"), "Spar-Hinweise auf der Startseite" (Prospekt), "Ersparnis im Verlauf und nach dem Einkauf".
  5. Sektion "Ausgeblendet für" (nur wenn Listen ausgenommen sind): `ListRow`s ohne Chevron, rechts schlicht "Einblenden".
  6. Schlicht: "Datenquellen" (> Rechtliches > Datenquellen).
- **Beispiel:** wie oben, "Ausgeblendet für: Drogerie".
- **Zustände:** Modul aus: Abschnitte 4 und 5 entfallen; 1 bis 3 bleiben. Kill-Switch: Seite heißt "Märkte" (Titel, Zeile im Profil, Suchtreffer), Abschnitt 1, 4, 5 und die Quellen-Fußnote entfallen, Abschnitt 2 heißt "Standort" mit Unterzeile "Für Markt-Vorschläge" (K-27). Offline: Schalter wirken lokal sofort, Sync später (Sync-Zeichen hinter dem Titel nicht nötig). Pro: nie.
- **Interaktion:** Jede Zeile schaltet als Ganzes (00 12.22), `springQuick`; Wirkung sofort und neustartfest (Liste 6d). Keine Haptik (Schalter haben System-Haptik nur, wenn nativ; hier keine).
- **AX / 320 pt:** Unterzeilen brechen um; Werte rutschen ab AX1 unter den Titel.
- **Änderung:** neu (heute keine Schalter; PLZ in "Persönliche Daten"). Datei `profile/settings/offers_settings_screen.dart` (B, Ausnahme im A-Ordner laut Arbeitsteilung).
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in voller Höhe im hellen Modus, Hintergrund #F2F2F7, oben ein Glas-Zurück-Knopf und großer fetter Titel "Preise & Angebote". Erste weiße Gruppe (#FFFFFF, Radius 26) mit Etikett-Symbol, "Preise & Angebote", grauer Unterzeile und einem grünen Schalter #3F7A1F, darunter eine kleine graue Fußnote zur Quelle. Gruppe "Region" mit Zeile "Region" und grauem Wert "79098 Freiburg · Standort" mit Chevron. Gruppe "Märkte" mit "Lieblingsmärkte · Lidl, REWE" und Schalter "Markt automatisch erkennen". Gruppe "Anzeigen" mit fünf Schalter-Zeilen ("Angebote in Listen", "Vorschläge beim Tippen", "Ersparnis in der Liste", "Spar-Hinweise auf der Startseite", "Ersparnis im Verlauf und nach dem Einkauf"), alle grün eingeschaltet. Sektionsüberschriften schwarz, Semibold, gemischte Schreibweise.

### 6.4 Lieblingsmärkte (Push)

- **Hauptfrage:** Bei welchen Märkten kaufe ich ein?
- **Wann:** "Preise & Angebote" > "Lieblingsmärkte" (Push im Profil-Sheet, Inline-Titel, dritte Ebene); Inhalt gleich im Onboarding-Schritt "Angebote in deiner Region" als Chips (Kapitel 17); Avo ("Mein Lieblingsmarkt ist REWE").
- **Aufbau:** Sektion "Deine Märkte" (sortierbar, Reihenfolge = Vorrang bei Listen ohne Markt), darunter "Weitere Märkte" (Ketten-Verzeichnis alphabetisch, mit `SearchField` "Markt suchen" ab 12 Ketten); Tippen schaltet hinzu/weg (`checkmark` links wie im Menü). Fuß: "Listen ohne festen Markt zeigen Angebote dieser Märkte, in dieser Reihenfolge."
- **Interaktion:** Hinzufügen: Zeile wandert mit `springMove` ans Ende von "Deine Märkte"; Entfernen: zurück an ihren alphabetischen Platz, Rückgängig-Hinweis "REWE entfernt · Widerrufen". Umsortieren über den Zieh-Griff rechts (44-pt-Ziel) oder Langdruck auf die Zeile; die Zeile folgt dem Finger 1:1, Nachbarn machen mit `springStandard` Platz, Einrasten mit Auswahl-Haptik (00 10.3). VoiceOver-Aktionen "Nach oben", "Nach unten".
- **Zustände:** keine gewählt: Satz "Noch keine Lieblingsmärkte." (`body`, `label`) an Stelle der Sektion; offline: Änderungen gelten sofort lokal, Abgleich später; Kill-Switch: Seite bleibt (Kern, unter "Märkte"), nur der Fuß lautet "Diese Märkte stehen bei neuen Listen oben in der Markt-Auswahl." Reduce Motion: Überblenden statt Wandern.
- **AX / 320 pt:** Zeilen brechen um, Zieh-Griff bleibt rechts oben bündig zur ersten Textzeile; ab AX1 Umsortieren zusätzlich über das Kontextmenü "Nach oben" / "Nach unten", weil Ziehen bei großer Schrift mühsam wird.
- **Bildbeschreibung für ChatGPT:** iPhone-Einstellungsseite hell, #F2F2F7, Titel "Lieblingsmärkte" klein in der Navigationsleiste. Weiße Gruppe "Deine Märkte" mit "● Lidl" (#0050AA) und "● REWE" (#CC071E), je mit grünem Häkchen links und grauem Zieh-Griff rechts. Darunter Gruppe "Weitere Märkte" mit Aldi Nord (#00549F), Aldi Süd (#00005F), Edeka (gelber Punkt #FFD400 mit feiner grauer Kontur), Kaufland (#E10915), Netto (#FFE500 mit Kontur), PENNY (#CD1414), ohne Häkchen. Kleine graue Fußnote unten.

---

## 7. Einkauf abschließen

### 7.1 Abschluss-Sheet (`showCheckoutFlow`, Teil B)

- **Hauptfrage:** Wo war ich, und was kommt in den Verlauf?
- **Wann:** Einkaufsmodus > "Einkauf beenden"; normale Liste > Listenmenü > "Einkauf abschließen" (sichtbar, sobald etwas abgehakt ist); Avo ("Ich bin fertig mit Einkaufen"). **Kein Bestätigungs-Alert davor** (heute: Alert "Einkauf abschließen?").
- **Aufbau (Sheet mittel; Kopf: `xmark` links, Titel "Einkauf abschließen", `checkmark` rechts getönt = Speichern):**
  1. Zusammenfassung (Sektion ohne Titel): "9 Artikel im Wagen" (`headline`), darunter "2 bleiben auf Wocheneinkauf: Brokkoli, Gouda in Scheiben" (`subheadline`, `label`). Alles abgehakt: nur Zeile 1.
  2. Sektion "Wo warst du?": Markt-Chips (`FilterChip` mit Markenpunkt, E-09, Einfachauswahl, `Wrap`). Vorausgewählt in dieser Reihenfolge: Markt der Liste, gelernter Markt, eindeutig erkannter Markt am Standort. Weitere Chips: Lieblingsmärkte, Märkte am Standort (Radius 250 m), zuletzt "Anderer Markt …" (Push im Sheet: 3.3). Fuß (`footnote`): Herkunft der Vorauswahl: "Markt dieser Liste" / "Erkannt über deinen Standort" / "Wie beim letzten Mal".
  3. Sektion "Betrag" (Kern): Zeile mit `AmountField` kompakt (E-04): Titel "Betrag", rechts Feld mit Platzhalter "optional", `number`, Ziffernblock mit Komma. Fuß: "Für deinen Monatsrückblick." (bzw. mit Kosten teilen: "Für deinen Monatsrückblick und zum Teilen.").
  4. Sektion "Kosten teilen" (nur Modul Kosten teilen und Liste mit mindestens 2 Mitgliedern): `ToggleRow` `eurosign.circle` "Kosten teilen" Unterzeile "Mit Lena. Danach legst du die Anteile fest." Standard aus; an, wenn beim letzten Einkauf dieser Liste geteilt wurde.
  5. Ersparnis-Zeile (nur Modul, echte Region, Einzel-Schalter "Ersparnis im Verlauf und nach dem Einkauf", Ersparnis mindestens 0,50 €): `tag` + "ca. 3,20 € durch Angebote gespart, laut Händler" (`callout`, `label`). Gerechnet nur über abgehakte Artikel mit Angebot des gewählten Markts. Wechselt man den Markt-Chip auf einen anderen Markt, entfällt die Zeile (`springStandard`), weil die Angebote nicht für diesen Markt galten.
- **Beispiel:** 9 Artikel im Wagen · 2 bleiben (Brokkoli, Gouda in Scheiben) · Wo warst du? "● Lidl" gewählt, "● REWE", "Anderer Markt …", Fuß "Markt dieser Liste" · Betrag 42,80 € · Kosten teilen an (mit Lena) · "ca. 3,20 € durch Angebote gespart, laut Händler".
- **Zustände:**
  - Standort nicht erlaubt und kein Markt vorausgewählt: einmalig (danach nie wieder) Fuß unter "Wo warst du?": "Mit Standort erkennt die App den Markt selbst." mit schlichtem "In Einstellungen erlauben". Standort erlaubt, aber gerade nicht ermittelt (Zeitlimit, Fehler): kein Hinweis, nur kein Standort-Chip (heute meldet das Sheet dann fälschlich "Ohne Standortzugriff").
  - Standort-Abfrage: läuft beim Öffnen parallel (frische Koordinaten, Zeitlimit 3 s, kein Prompt, wenn nicht erlaubt). Stilles Erkennen nur bei eindeutiger Lage (Regel aus `checkout_store_resolver.dart`: innerhalb 80 m, nächste andere Kette mindestens 50 m entfernt). Die Vorauswahl steht beim ersten Frame aus Liste bzw. Gelerntem fest und wird nie nachträglich geändert; ein Standort-Ergebnis fügt höchstens einen Chip "● REWE (hier)" am Ende hinzu (blendet ein). Hat die Liste keinen Markt und gibt es nichts Gelerntes, ist kein Chip gewählt, bis der Standort eindeutig ist oder der Nutzer wählt; Speichern geht auch ohne Markt.
  - nichts abgehakt: Sektionen 2 bis 5 entfallen; Satz "Noch nichts im Wagen." und prominent "Einkaufsmodus verlassen" statt `checkmark`; schlicht "Weiter einkaufen". Kein Verlaufseintrag.
  - offline: alles wie online; Speichern geht in die Warteschlange, der Einkauf erscheint im Verlauf mit Sync-Zeichen, Mitteilungen gehen beim Abgleich raus. Standort-Chip entfällt (Overpass braucht Netz).
  - Fehler beim späteren Abgleich: Verlaufszeile zeigt "Nicht gespeichert" mit `exclamationmark.circle` in `danger`, Tippen wiederholt; keine Datenverluste (Artikel bleiben bis zur Bestätigung lokal).
  - ungespeicherte Eingaben und Wischen nach unten: Aktionsblatt "Änderungen verwerfen?" nur, wenn ein Betrag getippt wurde; sonst schließt das Sheet, der Einkaufsmodus bleibt.
  - Modul Kosten teilen aus: Sektion 4 entfällt; Modul Angebote aus oder Kill-Switch: Zeile 5 entfällt. Beides ohne Lücke.
  - Pro (falls Kosten teilen Pro wird): Zeile 4 trägt `ProBadge`; Einschalten öffnet die Paywall aus der Zeile (16.2); nach Kauf steht der Schalter an.
- **Interaktion:** Tastatur hebt das Sheet auf groß (00 12.23). `checkmark` speichert sofort (optimistisch): Sheet schließt (`springSheet`), danach Erfolgsmoment (7.3). Chips `springQuick`, keine Haptik. Betrag: Eingabe "42,8" wird "42,80 €" beim Verlassen; "1.234,56" wird korrekt gelesen (behebt Bug 14).
- **AX / 320 pt:** Sheet öffnet groß ab AX1; Chips brechen um; "Betrag" stapelt Titel über Feld ab AX1. Bei 320 pt passen zwei Markt-Chips pro Zeile.
- **Änderung:** ersetzt den Ablauf in `shopping_trip_completion.dart` (A-Datei; die Ablauf-Logik wandert nach `checkout_flow.dart`, B, A ruft nur `showCheckoutFlow(context, listId)`), `checkout_store_sheet.dart` (nur bei Unklarheit, wartete bis 30 s unsichtbar auf GPS und Overpass) und die Snackbar-Aktion "Kosten teilen". Neu: Betrag als Eingabe (heute Teilsumme aus Angebotspreisen), Ketten-ID statt OSM-Name, Standort frisch statt 24-h-Cache, Overpass mit `way` und 250 m.
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe im hellen Modus, schwebend aus Liquid Glass über einer randlosen Einkaufsliste, innen #F2F2F7. Oben links X-Glasknopf, mittig "Einkauf abschließen", rechts ein grün getönter runder Glasknopf mit Häkchen. Eine weiße Gruppe mit fett "9 Artikel im Wagen" und darunter schwarz "2 bleiben auf Wocheneinkauf: Brokkoli, Gouda in Scheiben". Sektion "Wo warst du?" mit Kapsel-Chips: "● Lidl" gewählt (hellgrün #EEF5E4, grüner Text #3F7A1F, blauer Punkt #0050AA, Häkchen), "● REWE" grau #E9E9EE mit rotem Punkt #CC071E, "Anderer Markt …" grau; darunter grau "Markt dieser Liste". Gruppe "Betrag" mit der Zahl "42,80 €" rechts in abgerundeten Ziffern, Gruppe mit Euro-Kreis-Symbol, "Kosten teilen", Unterzeile "Mit Lena" und grünem Schalter. Ganz unten eine Zeile mit grauem Etikett-Symbol und schwarzem Text "ca. 3,20 € durch Angebote gespart, laut Händler".

### 7.2 Push "Anderer Markt" im Abschluss-Sheet

Inhalt wie 3.3; Tippen wählt und kehrt zurück (Zurück-Pfeil im Sheet), der gewählte Markt erscheint als gewählter Chip vorn. Eine Wahl hier setzt nicht den Listen-Markt, sondern nur den Markt des Einkaufs (Lernen siehe 7.4).

### 7.3 Erfolgsmoment und Rückgängig

- **Erfolgsmoment** (00 12.35): erst nach dem Schließen des Sheets; Maskottchen feiernd 120 pt, "Einkauf gespeichert." (`title2`), Unterzeile (`subheadline`, `labelSecondary`) "9 Artikel bei Lidl · ca. 3,20 € durch Angebote gespart, laut Händler" (ohne Modul, ohne echte Ersparnis oder unter 0,50 €: "9 Artikel bei Lidl"; ohne Markt: "9 Artikel"), Erfolgs-Haptik im selben Frame, `springCelebrate`, 1,5 s, Tippen schließt. Reduce Motion: nur Einblenden. VoiceOver: Ansage "Einkauf gespeichert, 9 Artikel bei Lidl". AX: Texte brechen um, das Maskottchen bleibt 120 pt (Erfolg ist kein leerer Zustand); ab AX3 entfällt es, damit der Text in den Bildschirm passt.
- Danach endet der Einkaufsmodus (Morph zurück, 00 10.2); die Liste zeigt nur noch offene Artikel.
- **Rückgängig-Hinweis** "Einkauf gespeichert · Widerrufen" (4 s, mit VoiceOver 10 s): Widerrufen löscht den Verlaufseintrag samt einer eben gespeicherten Aufteilung, stellt die abgehakten Artikel als abgehakt wieder her und setzt den Einkaufsmodus nicht neu auf (man ist in der normalen Liste mit "Erledigt (9)"). Mitteilungen an Mitglieder (7.4) gehen deshalb erst raus, wenn der Hinweis abgelaufen ist; nach einem Widerrufen gehen keine raus.
- War "Kosten teilen" an: Nach dem Erfolgsmoment öffnet sich das Sheet "Kosten teilen" (9.1) mit Betrag vorbefüllt; der Rückgängig-Hinweis erscheint nach dem Schließen dieses Sheets.
- Erster abgeschlossener Einkauf überhaupt: einmalig die Pro-Hinweis-Zeile (00 16.4), nie als Pop-up.
- **Bildbeschreibung für ChatGPT:** iPhone im hellen Modus, Liste "Wocheneinkauf" auf #F2F2F7 leicht im Hintergrund. In der Mitte schwebt ohne Karte ein flach gezeichnetes Avocado-Maskottchen (halbe Avocado mit braunem Kern #7A4A24, hellgrünem Fruchtfleisch #D8E77E, Schale #3F7A1F, kurze Ärmchen hochgereckt) in 120 pt. Darunter fett schwarz #000000 22 pt "Einkauf gespeichert." und grau #636366 15 pt "9 Artikel bei Lidl · ca. 3,20 € durch Angebote gespart, laut Händler". Unten über der Glas-Tab-Bar eine schmale Liquid-Glass-Kapsel "Einkauf gespeichert" mit grünem Textknopf "Widerrufen". Kein Konfetti, keine Emojis.

### 7.4 Was im Hintergrund passiert

- Verlaufseintrag mit Ketten-ID, Betrag, Preis-Schnappschuss (Preis, Händler, Vergleichspreis) pro Artikel, `completed_by`.
- Kaufstatistik (`purchase_tracking_service.dart`) blockiert nie; speist Nachkauf, "Oft gekauft" und Markt-Lernen (nach zweimal demselben Markt Hinweis-Zeile "Markt lernen", 6.2). Datenbanken ohne die Retailer-Spalten (alte Migrationen) dürfen das Speichern nicht verhindern; der Markt fehlt dann nur (heutige Rückfall-Logik bleibt).
- Verlauf aktualisiert sich sofort (der Provider wird ergänzt statt erst nach Neustart geladen, behebt Bug 3); Einkäufe anderer Mitglieder kommen per Realtime bzw. beim Öffnen.
- Mitteilung an Mitglieder (gebündelt, Kapitel 19): "Jannis hat bei Lidl eingekauft (9 Artikel)."

---

## 8. Verlauf (`/history`)

### 8.1 Screen

- **Hauptfrage:** Was habe ich eingekauft (und was hat es gekostet)?
- **Wann:** Alle Listen > Sektion "Verlauf" > "Einkäufe" (Wert "November · 6"); Mitteilung `shopping_complete` (direkt ins Einkauf-Detail); Avo; Suche ("Verlauf", "Einkäufe", "Ausgaben").
- **Aufbau (Push, großer Titel "Verlauf", E-06; Toolbar rechts `line.3.horizontal.decrease.circle` = Menü "Alle Listen / Wocheneinkauf / Grillabend / Drogerie", E-07):**
  1. **Monats-Sektion** (`InsetSection` ohne Titel, damit es keine zwei Überschriften "November" gibt):
     - Kopfzeile über dem Diagramm (`subheadline`, `labelSecondary`): "Ausgaben pro Monat"; darunter der Wert des gewählten Monats in `numberXL`: "168,40 €"; darunter (`subheadline`, `label`) der Monat: "November, bisher" im laufenden Monat, sonst "Oktober".
     - **Diagramm** (`BarChart`, 00 12.16): eine Reihe, 6 Monate (Jun bis Nov), Balken in `label`, gewählter Monat über fette Achsenbeschriftung markiert, laufender Monat mit gestricheltem Balkenumriss in `labelSecondary` über dem Ist-Wert (zeigt "läuft noch", keine Prognose-Zahl). Die Zeichenfläche hat eine feste Höhe von 120 pt, weil sie keinen Text enthält; die Achsenbeschriftung darunter wächst mit der Schrift.
     - Reihe gewählt nach Datenlage (K12-05): Ausgaben, wenn in mindestens 3 der 6 Monate Beträge erfasst sind; sonst "Einkäufe pro Monat" (Anzahl). Die Kopfzeile nennt immer, was die Reihe zeigt.
     - Zeilen (`ValueRow`): "Einkäufe" 6 · "Artikel" 58 · "Ausgaben" 168,40 € mit Unterzeile "aus 4 von 6 Einkäufen" (nur wenn nicht alle einen Betrag haben) · "Durch Angebote gespart" "ca. 9,80 €" mit Unterzeile "laut Händler" (nur Modul, nur echte Werte) · "Meist eingekauft" "samstags" (nur mit mindestens 6 Einkäufen in 90 Tagen, Zeitraum in der Unterzeile "in den letzten 3 Monaten").
     - Vergleich zum Vormonat nur in abgeschlossenen Monaten und nur, wenn beide Monate gleich gut erfasst sind (Anteil mit Betrag je mindestens 80 %): Unterzeile bei "Ausgaben", Beispiel mit Oktober gewählt: "10,80 € weniger als im September" (251,90 € gegen 262,70 €). Im laufenden Monat gibt es keinen Vergleich.
  2. **Einkäufe nach Monat:** je Monat eine `InsetSection` mit Titel "November" und Zähler "6" (`numberS`), Zeilen `TripRow` (E-05) wie Wallet-Transaktionen, neueste zuerst; geladen werden 3 Monate, weitere beim Scrollen (Sliver, Seiten zu 30 Einkäufen).
  3. **`TripRow`:** führend Listen-Glyph 28 pt (Listenfarbe); Titel = Listenname (`body`); Unterzeile (`subheadline`, `labelSecondary`): `StoreLabel` (E-01: Punkt + Kettenname) · Datum · Artikelzahl ("● Lidl · Heute, 18:40 · 9 Artikel"); zweite Unterzeile nur bei Bedarf: "von Lena" (fremder Einkauf), "Lena schuldet dir 21,40 €" (Modul Kosten teilen, `label`); rechts Betrag in `number` ("42,80 €") oder nichts; `chevron.right`.
- **Beispiel (November, 6 Einkäufe):** Wocheneinkauf · ● Lidl · Heute, 18:40 · 9 Artikel · Lena schuldet dir 21,40 € · 42,80 € | Wocheneinkauf · ● REWE · Mi., 4. Nov. · 7 Artikel · von Lena · du schuldest Lena 11,58 € · 23,15 € | Wocheneinkauf · ● Aldi Süd · Di., 3. Nov. · 8 Artikel · von Lena (ohne Betrag) | Wocheneinkauf · ● Lidl · Mo., 2. Nov. · 15 Artikel · 62,85 € | Grillabend · ● Kaufland · So., 1. Nov. · 14 Artikel · Tom schuldet dir 13,20 € · 39,60 € | Drogerie · So., 1. Nov. · 5 Artikel (ohne Markt, ohne Betrag).
- **Zustände:**
  - leer: `EmptyState` mit Maskottchen "zufrieden" (96 pt; kein Geld sichtbar), Titel "Noch keine Einkäufe.", Satz "Wenn du im Einkaufsmodus auf „Einkauf beenden“ tippst, landet dein Einkauf hier.", schlicht "Zur Liste". Ab AX1 ohne Maskottchen.
  - erster Monat bzw. weniger als 2 Monate mit Daten: Diagramm entfällt, an seiner Stelle der Satz "Ab dem zweiten Monat siehst du hier deinen Verlauf." (`body`); Zeilen bleiben.
  - keine Beträge erfasst: Reihe "Einkäufe pro Monat", Zeile "Ausgaben" entfällt; einmalig Tipp-Zeile "Tipp: Gib beim Abschluss den Betrag ein, dann siehst du hier deine Ausgaben." (wegwischbar).
  - lädt: sofort aus lokalem Cache (letzte 3 Monate, Teil B); allererstes Laden ohne Cache: Skelett-Zeilen in `fill` ohne Schimmer, Diagramm-Fläche als ruhige Tonfläche gleicher Höhe.
  - Fehler: Inhalt aus dem Cache bleibt, `StatusRow` "Verlauf konnte nicht aktualisiert werden. Erneut versuchen"; ohne Cache: Vollflächen-Fehler im Layout des leeren Zustands (Symbol `exclamationmark.circle`, "Der Verlauf lädt gerade nicht.", "Erneut versuchen").
  - offline: Cache plus `StatusRow` "Offline. Neue Einkäufe erscheinen, sobald du wieder online bist."; eigene ausstehende Einkäufe mit Sync-Zeichen.
  - Modul Angebote aus oder Kill-Switch: Zeile "Durch Angebote gespart" entfällt; Modul Kosten teilen aus: Schuld-Unterzeilen entfallen (Daten bleiben).
  - Pro (falls "Statistiken" Pro werden, F-05): Monats-Sektion zeigt den laufenden Monat vollständig; Ziehen auf frühere Monate oder Tippen auf deren Balken öffnet die Paywall aus dem Diagramm (`springMorph`), `ProBadge` hinter "Ausgaben pro Monat". Einkaufsliste darunter bleibt immer frei (Kern).
- **Interaktion:** Ziehen über das Diagramm wählt den Monat (Auswahl-Haptik pro Balken, 00 12.16), Wert und Zeilen der Monats-Sektion rollen (`springDigits`), die Monatszeile wechselt per Überblendung; Ziehen nach unten am Anfang der Seite aktualisiert Einkäufe und Aufteilungen (heute fehlt das); Tippen auf einen Balken wählt ebenso; Loslassen lässt die Auswahl stehen; erneutes Öffnen startet beim laufenden Monat. Tippen auf eine `TripRow` pusht das Einkauf-Detail (8.2). Wischen nach links: "Löschen" (nur eigene Einkäufe; Rückfrage 10.1). Kontextmenü: "Alle wieder auf die Liste", "Kosten teilen" (Modul), "Betrag eintragen", "Löschen" (nur eigene, `danger`). Fremde Einkäufe zeigen kein Löschen (behebt stilles Scheitern, Bug 4). Filter-Menü filtert alle Sektionen inklusive Diagramm; aktiver Filter steht als Metazeile unter dem Titel "Nur Wocheneinkauf" mit schlichtem "Alle".
- **AX / 320 pt:** Diagramm-Achsen bis xxxL, darüber entfallen sie und die Monatswerte stehen als Zeilen unter dem Diagramm (00 5.3); `numberXL` höchstens 51 pt. `TripRow` ab AX1: Glyph entfällt, Betrag rutscht unter die Unterzeilen. Bei 320 pt: 6 Balken bleiben (je mindestens 24 pt breit, Abstand 8), Monatskürzel "Jun", "Jul" …; Unterzeilen brechen um.
- **Barrierefreiheit:** Diagramm-Zusammenfassung: "Ausgaben pro Monat. November bisher 168,40 Euro, Oktober 251,90 Euro, …"; jeder Balken eigenes Element. `TripRow`: "Wocheneinkauf, Lidl, heute 18 Uhr 40, 9 Artikel, 42,80 Euro, Lena schuldet dir 21,40 Euro"; Aktionen als eigene VoiceOver-Aktionen.
- **Änderung gegenüber heute:** `shopping_history_screen.dart` (Material-AppBar ohne Titel, Kicker "AKTIVITÄTEN"/"VERLAUF", Georgia-Serifen, drei `_Stat` mit fester Breite 82 und Überlauf bei 320 pt, Lebenszeit-Zahl "Verlauf" neben Monatszahlen, Wochentags-Diagramm über alle Zeit mit Akzent-Balken, aufklappbare Zeilen, Löschen nur per Langdruck, Vollbild-Spinner, kein Cache, kein Aktualisieren nach Einkauf, "3.20 €" mit Punkt) wird ersetzt durch `screens/history/history_screen.dart` mit Route `/history`. Aufklappen entfällt zugunsten des Einkauf-Details. Formatierung über `NumberFormat.currency(locale)`. `shopping_history_service.dart` lädt seitenweise; `shoppingHistoryNotifierProvider` wird beim Abschluss ergänzt.
- **Bildbeschreibung für ChatGPT:** iPhone im hellen Modus, Hintergrund #F2F2F7, oben links runder Glas-Zurück-Knopf, oben rechts runder Glas-Knopf mit Filter-Symbol. Großer fetter Titel "Verlauf". Eine weiße Sektion ohne Überschrift (#FFFFFF, Radius 26): oben grau #636366 "Ausgaben pro Monat", darunter groß "168,40 €" in abgerundeten fetten Ziffern, darunter schwarz "November, bisher", dann ein Balkendiagramm mit sechs schwarzen Balken (Jun bis Nov, Höhen etwa 240, 286, 198, 262, 252, 168), der letzte mit gestricheltem grauem Umriss darüber, Monatskürzel darunter grau, "Nov" fett. Darunter Wertezeilen "Einkäufe 6", "Artikel 58", "Ausgaben 168,40 €" mit grauer Unterzeile "aus 4 von 6 Einkäufen", "Durch Angebote gespart ca. 9,80 €" mit Unterzeile "laut Händler". Darunter Sektion "November 6" mit Transaktions-Zeilen wie in Wallet: grüner runder Listenkreis mit Wagen-Symbol, "Wocheneinkauf", grau "● Lidl · Heute, 18:40 · 9 Artikel" mit blauem Punkt #0050AA, schwarz "Lena schuldet dir 21,40 €", rechts "42,80 €" in abgerundeten Ziffern und Chevron; zweite Zeile "Wocheneinkauf · ● REWE (#CC071E) · Mi., 4. Nov. · 7 Artikel · von Lena", rechts "23,15 €". Außer den Marktpunkten und dem Listenkreis keine Farbe, ruhig wie Apple Wallet und Health.

### 8.2 Einkauf-Detail (`/history/:tripId`)

- **Hauptfrage:** Was war in diesem Einkauf, und ist alles erledigt (Geld, Nachkaufen)?
- **Wann:** `TripRow`; Mitteilung `shopping_complete` und `expense_split`; Offene Beträge; Avo-Ergebniszeile "Ansehen".
- **Aufbau (Push, Inline-Titel = Listenname "Wocheneinkauf", 3. Ebene; Toolbar `ellipsis`: "Betrag ändern", "Markt ändern", "Kosten teilen" (Modul), "Löschen" (nur eigene, `danger`)):**
  1. Kopf-Sektion (ohne Titel): `StoreLabel` groß ("● Lidl", `title3`), Datum und Zeit "Sa., 7. Nov., 18:40" (`subheadline`), "Eingekauft von dir" bzw. "von Lena" mit Avatar 20 pt; rechts der Betrag in `numberXL` ("42,80 €"); ohne Betrag statt der Zahl schlicht "Betrag eintragen".
  2. Hauptaktion (prominent, volle Breite): "Alle wieder auf die Liste" mit `cart.badge.plus` (E-07). Ziel = Liste des Einkaufs (Standard), Menü-Pfeil daneben (grau, 44 pt, `chevron.down`) wählt eine andere Liste. Ist die Liste gelöscht oder man kein Mitglied mehr: Ziel = Liste von heute.
  3. Sektion "Kosten teilen" (Modul): wie 9.2.
  4. Sektion "Gespart" (Modul, echte Werte): "ca. 3,20 € durch Angebote gespart, laut Händler" als Zeile mit `tag`; Fuß "4 Artikel im Angebot bei Lidl".
  5. Sektion "Artikel" mit Zähler "9": Zeilen ohne Abhak-Kreis: Avo Symbol 28 pt, Name (`body`), Menge rechts (`number`); bei Angebotsartikeln Unterzeile "0,99 € laut Händler statt 1,19 €" (nur Modul; bei Kill-Switch entfällt). Steht der Artikel schon offen auf einer Liste: Unterzeile "Auf Wocheneinkauf" in `labelSecondary`.
  6. Sektion "Geblieben" (falls Artikel auf der Liste blieben): "Brokkoli, Gouda in Scheiben" als Satz, schlicht "Zur Liste".
- **Beispiel:** ● Lidl · Sa., 7. Nov., 18:40 · Eingekauft von dir · 42,80 € · Alle wieder auf Wocheneinkauf · Kosten teilen: Lena 21,40 € offen · Gespart ca. 3,20 € · Artikel: Bananen 1 kg, Avocados 2, Cherrytomaten, Milch 2, Butter 2, Eier Größe M 10, Spaghetti, Passierte Tomaten 2, Kaffee.
- **Zustände:** fremder Einkauf: kein Löschen, Betrag nur durch den Einkäufer änderbar (Toolbar-Einträge entfallen statt grau), "Kosten teilen" darf jedes Mitglied (gleiche Regel wie heute, Schreibrechte serverseitig prüfen). Einkauf ohne Liste (Altdaten): Hauptaktion-Ziel Liste von heute, Kosten teilen nur mit Namens-Personen. Offline: alles lesbar; Aktionen gehen in die Warteschlange. Gelöscht von anderem Gerät oder Mitglied: automatisch zurück zum Verlauf plus Status-Hinweis "Dieser Einkauf wurde gelöscht." Laden ohne Cache (Mitteilung im Kaltstart): Skelett der Kopf-Sektion und 5 Zeilen.
- **Interaktion:** "Alle wieder auf die Liste" fügt alle Artikel hinzu, die nicht schon offen auf der Ziel-Liste stehen, mit ihren Mengen (ohne alte Preise; aktuelle Angebote hängen sich automatisch an). Beim Einkauf von heute kommen alle 9 Artikel zurück ("9 Artikel auf Wocheneinkauf · Widerrufen"); beim Einkauf vom 4. Nov. stehen 2 von 7 schon offen, also "5 Artikel auf Wocheneinkauf · Widerrufen" (die 2 tragen in den Zeilen "Auf Wocheneinkauf"). Stehen alle schon offen, ist die Hauptaktion deaktiviert mit Unterzeile "Alles steht schon auf Wocheneinkauf". Keine Navigation weg; Wischen nach rechts auf einer Artikelzeile: "Auf die Liste" (einzeln, leichter Impuls an der Schwelle). Kontextmenü pro Zeile: "Auf die Liste", "Auf andere Liste …". Betrag eintragen: `AmountField`-Sheet klein (mittel) mit `checkmark`; Ziffern rollen in Kopf und Verlauf.
- **AX / 320 pt:** Kopf stapelt: Markt, Datum, Person, darunter der Betrag (`numberXL` gedeckelt 51 pt). Hauptaktion bricht um, Menü-Knopf rutscht darunter (Flex-Umschaltung). Bei 320 pt Betrag unter dem Markt.
- **Änderung:** heute nur aufklappbare Zeile im Verlauf; neu als eigener Push mit Route `/history/:tripId` (Datei `screens/history/trip_detail_screen.dart`, B). "Alle wieder auf die Liste" ist neu.
- **Bildbeschreibung für ChatGPT:** iPhone im hellen Modus, Hintergrund #F2F2F7, oben links Glas-Zurück-Knopf, mittig klein "Wocheneinkauf", rechts runder Glas-Knopf mit drei Punkten. Weiße Kopf-Sektion: links groß "● Lidl" mit blauem Punkt #0050AA, darunter grau "Sa., 7. Nov., 18:40" und "Eingekauft von dir", rechts groß "42,80 €" in abgerundeten fetten Ziffern. Darunter eine breite gefüllte grüne Kapsel #3F7A1F mit weißem Wagen-Plus-Symbol und "Alle wieder auf die Liste", rechts daneben ein kleiner grauer Kapsel-Knopf mit Chevron. Sektion "Kosten teilen" mit Avatar "Lena", grau "offen", rechts "21,40 €" und grünem Textknopf "Bezahlt". Sektion "Gespart" mit Etikett-Symbol und "ca. 3,20 € durch Angebote gespart, laut Händler". Sektion "Artikel 9" mit Zeilen wie "Milch 2", grau "0,99 € laut Händler statt 1,19 €", ohne Abhak-Kreise.

---

## 9. Kosten teilen

### 9.1 Sheet "Kosten teilen" (`/history/:tripId/split`)

- **Hauptfrage:** Wer bekommt wie viel von diesem Einkauf?
- **Wann:** nach dem Abschluss (Schalter an), Einkauf-Detail (Sektion bzw. Toolbar), Hinweis-Zeile "Einkauf teilen", Mitteilung, Avo (Ergebniszeile "Aufteilung" mit "Ansehen").
- **Aufbau (Sheet mittel, wächst auf groß; Kopf `xmark`, "Kosten teilen", `checkmark` getönt, deaktiviert bis gültig):**
  1. Betrag (`AmountField` groß, E-04): Beschriftung "Gesamtbetrag" (`subheadline`, `labelSecondary`), Wert "42,80 €" in `numberXL`, linksbündig, Ziffernblock mit Komma. Fuß: "Wocheneinkauf · ● Lidl · Sa., 7. Nov."
  2. Zeile "Bezahlt von" (`ValueRow` mit Menü): "Du" > Menü mit allen Teilnehmern.
  3. `SegmentedControl` "Gleich" | "Individuell".
  4. Sektion "Wer teilt?" (Zähler "2"): Zeilen mit Auswahl-Kreis (E-08, `checkmark.circle.fill` in `action` bzw. Ring `controlOutline`), Avatar 28 pt, Name (`body`), Unterzeile "hat bezahlt" beim Zahler bzw. "ohne Konto" bei Namens-Personen, rechts Anteil in `number` ("21,40 €"). In "Individuell" ist der Anteil ein Feld (Kapsel `fill`, wächst mit dem Inhalt, Mindestbreite 88 pt).
  5. Zeile "Person hinzufügen" (`person.badge.plus`, `action`): öffnet eine neue Zeile mit Namensfeld (Tastatur), Return übernimmt; doppelte Namen werden abgelehnt ("Lena ist schon dabei.").
  6. Summen-Fuß (`footnote`): gleich und glatt teilbar: "Je 21,40 €."; gleich mit Rest: "13,34 € und 2 × 13,33 €. Der Restcent geht an die erste Person." (Beispiel 40,00 € durch 3); individuell: "Verteilt 42,80 € von 42,80 €" (`label`) bzw. "Noch 3,20 € zu verteilen" mit `exclamationmark.circle` in `warning` (Symbol plus Text), `checkmark` bleibt dann deaktiviert (behebt Bug 2).
- **Beispiel:** 42,80 € · Bezahlt von Du · Gleich · Du (hat bezahlt) 21,40 € · Lena 21,40 € · Fuß "Je 21,40 €." Grillabend: 39,60 € · Du, Lena, Tom (ohne Konto) je 13,20 €.
- **Zustände:**
  - neu: Teilnehmer = alle Mitglieder der Liste plus du; Zahler = Einkäufer; Betrag aus dem Einkauf (sonst leer, Feld fokussiert).
  - bearbeiten (Aufteilung existiert): lädt alle Teilnehmer inklusive Namens-Personen, individuelle Beträge, Modus und Zahler (behebt Bug 1). Bezahlt-Status bleibt für jede Person, deren Anteil gleich bleibt; ändert sich ein bezahlter Anteil, Fuß-Zeile "Lenas Anteil ändert sich. Er gilt danach wieder als offen." (vor dem Speichern sichtbar, kein Dialog).
  - Liste mit nur dir (Namens-Personen): Sektion zeigt nur dich plus "Person hinzufügen"; `checkmark` erst ab 2 Teilnehmern aktiv.
  - Betrag 0 oder leer: `checkmark` deaktiviert, unter dem Feld "Gib den Betrag ein." (kein reines Fehler-Vibrieren wie heute).
  - Mitglieder laden: aus Cache sofort; ohne Cache stehen Platzhalter-Zeilen in `fill`, nie ein Spinner, nie nachträgliches Einfügen über bereits gesetzte Werte. Laden scheitert ohne Cache: Sektion zeigt dich und "Person hinzufügen", darüber `StatusRow` "Mitglieder konnten nicht geladen werden. Erneut versuchen" (heute bleibt das Sheet dann leer und unsichtbar, Bug 15).
  - Speichern läuft: optimistisch; Sheet schließt sofort. Fehler: Rückgängig-Leiste wird zu "Aufteilung nicht gespeichert · Erneut versuchen", Fehler-Haptik, Einkauf-Detail zeigt den alten Stand.
  - offline: Speichern in die Warteschlange; Mitteilungen an Mitglieder gehen beim Abgleich raus.
  - ungespeicherte Änderungen beim Wischen nach unten: Aktionsblatt "Änderungen verwerfen?".
  - Modul aus: Route öffnet Modul-Sheet (10.3). Pro (falls): Paywall wächst aus dem auslösenden Element, das Sheet öffnet erst nach Kauf.
- **Interaktion:** Betrag tippen: Anteile rollen live (`springDigits`), ganze Cent mit exakter Summe (10,00 / 3 = 3,34 + 3,33 + 3,33). Teilnehmer an/aus: Kreis `springQuick`, Anteile rollen. Segment-Wechsel per Wischen: Auswahl-Haptik. Speichern: Sheet schließt (`springSheet`), Rückgängig-Hinweis "Aufteilung gespeichert · Widerrufen" (stellt die vorige Aufteilung wieder her, inklusive Bezahlt-Status). Keine Erfolgs-Haptik, kein Maskottchen (Geld).
- **AX / 320 pt:** Sheet öffnet groß ab xxL; Zeilen stapeln ab AX1 (Anteil unter dem Namen, Feld volle Breite); Segment wird ab AX zu Pull-down "Aufteilen: Gleich". Bei 320 pt bleibt das Anteil-Feld rechts, solange der Name 100 pt behält, sonst darunter. Das Sheet scrollt immer (behebt Überlauf ab 4 Teilnehmern mit Tastatur).
- **Änderung:** ersetzt `split_cost_sheet.dart` (Material-Sheet ohne Scroll, Serif, Kicker, `Checkbox`, `OutlineInputBorder`, Betrag mit "€ " davor und fester Breite 84, `ElevatedButton`, unsichtbares Sheet bei Fehler, Seiteneffekt im Build). `expense_split_service.dart`: Bezahlt-Status erhalten, lokalisierte Mitteilungen ohne Emoji, Routing `expense_split` (in `navigation_service.dart`, Teil B laut Mitteilungs-Besitz).
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe aus Liquid Glass, innen #F2F2F7. Oben links X-Glasknopf, mittig "Kosten teilen", rechts grün getönter Häkchen-Knopf. Darunter grau "Gesamtbetrag" und groß "42,80 €" in fetten abgerundeten Ziffern, darunter klein grau "Wocheneinkauf · ● Lidl · Sa., 7. Nov." mit blauem Punkt #0050AA. Eine weiße Zeile "Bezahlt von" mit grauem Wert "Du" und Doppelpfeil. Ein Segment-Schalter mit grauer Spur #E9E9EE, weißem Daumen auf "Gleich", daneben "Individuell". Sektion "Wer teilt?" mit zwei Zeilen: grüner gefüllter Kreis mit Häkchen #3F7A1F, runder Avatar, "Du" mit grauer Unterzeile "hat bezahlt", rechts "21,40 €"; dasselbe für "Lena" mit "21,40 €". Darunter grüne Zeile "Person hinzufügen" mit Personen-Plus-Symbol und grau "Je 21,40 €.". Kein Maskottchen.

### 9.2 Sektion "Kosten teilen" im Einkauf-Detail

- **Aufbau:** Titel "Kosten teilen", rechts schlicht "Ändern" (öffnet 9.1). Zeilen je Teilnehmer außer dem Zahler-Anteil: Avatar 28 pt, Name, Unterzeile "offen" bzw. "bezahlt am 8. Nov." (`labelSecondary`), rechts Betrag (`number`); dahinter schlicht "Bezahlt" (für dich als Zahler) bzw. "Zurückgezahlt" (wenn du schuldest). Fuß: "Bezahlt von dir · 42,80 € · gleich aufgeteilt".
- **Ohne Aufteilung:** eine Zeile `eurosign.circle` "Kosten teilen" (`action`, schlicht) mit Unterzeile "Mit Lena".
- **Interaktion:** "Bezahlt" wirkt sofort (optimistisch): Unterzeile "bezahlt am 7. Nov.", Rückgängig-Hinweis "Lena: bezahlt · Widerrufen"; Fehler: zurückrollen, Zeilen-`StatusRow` "Nicht gespeichert. Erneut versuchen", Fehler-Haptik (behebt Bug 6). Wischen nach links auf einer Zeile, die dir geschuldet wird: "Erinnern" (`square.and.arrow.up`) öffnet das System-Teilen mit dem Text "Kleine Erinnerung: 21,40 € für unseren Einkauf „Wocheneinkauf“ bei Lidl am 7. Nov. Danke." (ohne Emoji; heute Zwischenablage plus Snackbar). Für Anteile, die du schuldest, und für bezahlte Anteile gibt es kein "Erinnern". Bezahlte Zeilen haben im Kontextmenü "Wieder als offen markieren" (mit Rückgängig-Hinweis). Mitteilung an die Gegenseite (nie an den Auslöser, nie an Namens-Personen, erst nach Ablauf des Rückgängig-Hinweises): "Jannis hat deinen Anteil (21,40 €) als bezahlt markiert." bzw. "Jannis hat deinen Anteil (21,40 €) wieder als offen markiert."
- **Zustände:** offline: "Bezahlt" wirkt sofort lokal, Sync-Zeichen an der Zeile; Aufteilung lädt ohne Cache: Platzhalter-Zeilen in `fill`; Fehler beim Laden: Sektion zeigt `StatusRow` "Aufteilung konnte nicht geladen werden. Erneut versuchen" statt still zu verschwinden (heute); Modul aus: Sektion entfällt ohne Lücke, Daten bleiben.
- **AX / 320 pt:** Aktion rutscht unter den Betrag; Trefferflächen 44 pt (heute 20 pt Pillen).

### 9.3 Offene Beträge (`/splits`)

- **Hauptfrage:** Wer schuldet wem?
- **Wann:** Alle Listen > Sektion "Verlauf" > "Offene Beträge" (Wert "34,60 €"); Hinweis-Zeile mit mehreren Beträgen; Avo.
- **Aufbau (Push, großer Titel "Offene Beträge", E-06):**
  1. Sektion "Schuldet dir" (rechts Summe `numberS` "34,60 €"): Zeilen je offenem Anteil: Avatar 28 pt, Name (`body`), Unterzeile "Wocheneinkauf · ● Lidl · Heute" (`subheadline`, `labelSecondary`), rechts Betrag (`number`) und schlicht "Bezahlt".
  2. Sektion "Du schuldest" (Summe "11,58 €"): gleich, Aktion "Zurückgezahlt".
  3. Sektion "Erledigt" (einklappbar, eingeklappt, letzte 30 Tage): gleiche Zeilen, Unterzeile "bezahlt am 1. Nov.", ohne Aktion.
- **Beispiel:** Schuldet dir: Lena 21,40 € (Wocheneinkauf · ● Lidl · Heute), Tom 13,20 € (Grillabend · ● Kaufland · So., 1. Nov., "ohne Konto"). Du schuldest: Lena 11,58 € (Wocheneinkauf · ● REWE · Mi., 4. Nov.). Erledigt (1): Lena 13,20 € (Grillabend, bezahlt am 2. Nov.).
- **Zustände:** leer: `EmptyState` ohne Maskottchen (Geld): `checkmark.circle` 48 pt Light, "Alles beglichen.", "Offene Beträge erscheinen hier, wenn du einen Einkauf teilst."; nur eine Richtung offen: die andere Sektion entfällt ohne Lücke; Altdaten, in denen der Anteil des Zahlers noch als offen gespeichert ist: werden nie als Schuld gezeigt (heutige Filterregel bleibt); Name fehlt: "ein Mitglied"; lädt: aus Cache sofort; Fehler/Offline wie 8.1 mit `StatusRow`; Modul aus: Route öffnet Modul-Sheet, Zeile in Alle Listen entfällt; Pro: nicht vorgesehen (Kosten teilen insgesamt oder gar nicht).
- **Interaktion:** "Bezahlt" bzw. Wischen nach links "Bezahlt" (leichter Impuls an der Schwelle, volles Wischen löst aus): Zeile wandert mit `springMove` nach "Erledigt", Summe rollt, Rückgängig-Hinweis. Kontextmenü: "Als bezahlt markieren", "Erinnern" (System-Teilen, nur in "Schuldet dir"), "Einkauf ansehen"; in "Erledigt": "Wieder als offen markieren", "Einkauf ansehen". Tippen auf die Zeile: Einkauf-Detail. "Erledigt" klappt mit `springStandard` auf und zu (Zustand gemerkt).
- **AX / 320 pt:** Aktion unter dem Betrag; Summe im Sektionskopf bricht unter den Titel ab AX1.
- **Änderung:** ersetzt `PendingSplitsBanner` (eine Zeile pro Schuld ohne Obergrenze auf der Startseite, Terrakotta, Material-Pfeile, Schnellaktion 15 pt hoch, ohne Rückgängig und Fehlerbehandlung, "Du schuldest Wocheneinkauf 3.20 €" bei fehlendem Namen). Neu: Datei `screens/history/open_balances_screen.dart` (B), Route `/splits`; Namens-Rückfall "ein Mitglied" statt Listenname (Bug 10). Abfrage nur offener Anteile serverseitig statt aller bezahlten Einkäufe.
- **Bildbeschreibung für ChatGPT:** iPhone im hellen Modus, #F2F2F7, Glas-Zurück-Knopf, großer fetter Titel "Offene Beträge". Sektion "Schuldet dir" mit grauer Summe rechts "34,60 €" in abgerundeten Ziffern, weiße Gruppe mit zwei Zeilen: runder Foto-Avatar "Lena", grau "Wocheneinkauf · ● Lidl · Heute" mit blauem Punkt #0050AA, rechts "21,40 €" und grüner Textknopf #3F7A1F "Bezahlt"; Initialen-Avatar "T" auf grauer Fläche #E9E9EE, "Tom", grau "Grillabend · ● Kaufland · So., 1. Nov. · ohne Konto" mit rotem Punkt #E10915, rechts "13,20 €" und "Bezahlt". Sektion "Du schuldest 11,58 €" mit "Lena", grau "Wocheneinkauf · ● REWE · Mi., 4. Nov.", rechts "11,58 €" und grünem "Zurückgezahlt". Eingeklappte Zeile "Erledigt (1)" mit Chevron. Kein Rot, keine Pfeile, kein Maskottchen.

---

## 10. Dialoge und Sonderzustände

### 10.1 "Einkauf löschen?" (`confirmDestructive`, 00 12.34)

- Einziger Bestätigungsdialog des Bereichs. Nur eigene Einkäufe.
- Titel "Einkauf vom 7. Nov. löschen?"; Nachricht "Der Einkauf und seine Aufteilung werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen."; Knöpfe "Abbrechen" und rot "Löschen".
- Nach dem Löschen: Zeile verschwindet (`springStandard`), Monatswerte rollen, kein Rückgängig (endgültig). Fehler: Zeile kommt zurück, Status-Hinweis "Löschen hat nicht geklappt. Erneut versuchen" (der Screen bleibt intakt, behebt Bug 5).
- Auslöser: Wischen nach links bzw. Kontextmenü in der `TripRow`, Toolbar `ellipsis` im Einkauf-Detail, Avo (`AvoConfirmCard`). Offline: Löschen geht in die Warteschlange, die Zeile trägt bis dahin das Sync-Zeichen.
- **AX / 320 pt:** nativer Alert; das System bricht den Text um und stellt die Knöpfe ab großer Schrift untereinander.
- **Bildbeschreibung für ChatGPT:** Nativer iOS-Alert im hellen Modus mittig über abgedunkeltem Verlauf-Screen (Schleier #000000 mit 20 %). Milchige Glasfläche mit fettem Titel "Einkauf vom 7. Nov. löschen?", darunter in normaler Schrift "Der Einkauf und seine Aufteilung werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen." Zwei Knöpfe nebeneinander: "Abbrechen" und rot #D70015 "Löschen". Keine Symbole, kein Maskottchen.

### 10.2 "Änderungen verwerfen?" (Aktionsblatt, 00 12.23)

Im Abschluss-Sheet (nur mit getipptem Betrag), im Kosten-teilen-Sheet und im Betrag-Sheet beim Wischen nach unten. Aktionen "Änderungen verwerfen" (rot) und "Weiter bearbeiten".

### 10.3 Modul-ist-aus-Sheet (00 13)

- Auslöser: Deep Link, Mitteilung, Widget oder Siri auf `/offers`, `/offers/list/:id`, `/splits`, `/history/:id/split` bei ausgeschaltetem Modul.
- Sheet mittel: Symbol des Moduls (48 pt Light: `tag` bzw. `eurosign.circle`), Titel "Preise & Angebote ist ausgeschaltet" bzw. "Kosten teilen ist ausgeschaltet", Satz mit Nutzen ("Dann siehst du, was bei deinem Markt im Angebot ist." / "Dann teilst du Einkäufe mit Mitgliedern und siehst, wer wem etwas schuldet."), prominent "Einschalten", schlicht "Nicht jetzt". Einschalten öffnet danach das ursprüngliche Ziel.
- Kill-Switch aktiv: kein Sheet; Angebots-Routen zeigen die Fehlerseite "Diese Seite gibt es nicht mehr" mit "Zur Liste" (01 7), ohne das Wort "Angebote".
- "Einschalten" wirkt sofort (00 15.2), offline auch; das Sheet schließt mit `springSheet`, das Ziel öffnet danach. "Nicht jetzt" schließt; man bleibt auf der Tab-Wurzel, zu der der Link den Stapel gebaut hat (01 6).
- **AX / 320 pt:** Sheet öffnet groß ab AX1; Titel und Satz brechen um; die beiden Knöpfe stehen schon untereinander.
- **Bildbeschreibung für ChatGPT:** iPhone-Sheet in halber Höhe aus Liquid Glass, innen #F2F2F7, X-Glasknopf oben links. Mittig ein großes, dünnes graues Euro-Kreis-Symbol #636366 in 48 pt, darunter fett 20 pt "Kosten teilen ist ausgeschaltet" und schwarz 17 pt "Dann teilst du Einkäufe mit Mitgliedern und siehst, wer wem etwas schuldet." Darunter eine breite grüne Kapsel #3F7A1F "Einschalten" mit weißer Schrift und grüner Textknopf "Nicht jetzt". Ruhig, kein Maskottchen.

### 10.4 Kill-Switch: was genau verschwindet

| Ort | Bei `offers_enabled = false` |
|---|---|
| Liste | gelbe Schilder, Angebots-Zeilen im Vorschlags-Panel, Ersparnis-Zeile, Hinweis "Region fehlt", "Markt fehlt" (Angebots-Begründung), "Prospekt"; Menüeintrag "Angebote dieser Liste" und "Angebote für diese Liste ausblenden" |
| Abschluss | Ersparnis-Zeile; Erfolgsmoment ohne Ersparnis |
| Verlauf | "Durch Angebote gespart", Sektion "Gespart", Angebotspreise an Artikeln |
| Alle Listen | Sektion "Sparen" |
| Rezepte, Wochenplan | Schilder an Zutaten, Zeile "3 Zutaten bei Lidl im Angebot" |
| Einstellungen | Seite heißt "Märkte" (6.3); Modul-Schalter fehlt auch in Einstellungen > Module und im Onboarding (Schritt "Angebote in deiner Region" entfällt) |
| Avo | Werkzeuge `get_personalized_deals`, Angebots-Suche, `get_savings_summary` entfallen; Antwort sachlich "Dazu kann ich gerade nichts sagen." |
| Widgets | Ersparnis-Zeile im großen Listen-Widget |
| Bleibt | Markt-Chip, Markt-Erkennung, Reihenfolge im Markt, Verlauf mit Märkten, Lieblingsmärkte, Standort/PLZ unter "Märkte" |

Prüfregel für Teil B: Mit Kill-Switch kommt in keinem Screenshot der App Gelb (#FFD60A) vor, und kein Text enthält "Angebot", "gespart" oder "laut Händler".

---

## 11. Avo in diesem Bereich (Teil B, Kapitel 16)

- Werkzeuge: Angebote der Liste, Angebote suchen, Ersparnis (dieselbe Rechnung wie Regel 5 in Abschnitt 1 und der Verlauf, damit Chat und Screen nie widersprechen), Verlauf lesen, Einkauf wiederholen, Kosten teilen, bezahlt markieren, Region setzen, Schalter aus 6.3 ändern (`update_setting`), Markt einer Liste setzen.
- Ergebnisse als `AvoResultRow` mit "Widerrufen" bzw. "Ansehen": "Angebote für Wocheneinkauf ausgeblendet", "7 Artikel aus dem Einkauf vom 4. Nov. auf Wocheneinkauf", "Wocheneinkauf geteilt: Lena 21,40 €", "Lena: bezahlt".
- Löschen eines Einkaufs nur mit `AvoConfirmCard`.
- Avo nennt nie "günstigster Markt" und vergleicht auf Nachfrage nicht ("Wo ist meine Liste am günstigsten?"): sachliche Antwort "Einen Preisvergleich zwischen Märkten kann ich nicht seriös machen, weil es keine Normalpreise gibt. Bei Lidl sind diese Woche 4 deiner 11 Artikel im Angebot." (Kern `neutral`).

---

## 12. Abläufe

### 12.1 Angebot beim Hinzufügen übernehmen
Ausgangslage: Auf "Wocheneinkauf" fehlt Milch noch (10 offene Artikel). Die Ersparnis-Zeile lautet "3 von 10 Artikeln diese Woche bei Lidl im Angebot, ca. 2,80 € gespart, in deiner Region".
1. Tab Liste, "Wocheneinkauf" (● Lidl). Tippen auf "Artikel hinzufügen".
2. "2 mi" tippen. Panel (von unten nach oben): Vorschau "Milch · Menge 2 · Milch & Käse", Verlauf "Milch", Angebot "Milbona Frische Vollmilch 3,5 % · Lidl · 1 l · bis Sa." mit Schild "0,99 €".
3. Tippen auf die Angebots-Zeile. "Milch, Menge 2" erscheint in "Milch & Käse" mit Schild "0,99 €". VoiceOver: "Milch hinzugefügt, Milch und Käse, im Angebot".
4. Die Ersparnis-Zeile zählt mit, ihre Ziffern rollen auf "4 von 11 … ca. 3,20 € gespart" (Höhe unverändert). Hätte die Liste vorher kein Angebot gehabt, erschiene die Zeile erst beim nächsten Öffnen (Regel gegen Layout-Sprünge).
5. Stünde "Milch" schon offen auf der Liste, hinge sich das Angebot nur an ("Angebot an Milch angehängt · Widerrufen"), ohne zweite Zeile.

### 12.2 Angebot ansehen und Preis übernehmen
1. Tippen auf das Schild "1,49 €" bei Butter.
2. Angebots-Sheet wächst aus dem Schild: Milbona Deutsche Markenbutter, 250 g, laut Händler statt 2,29 €, 5,96 €/kg, bis Sa., 14. Nov.
3. "Preis übernehmen". Sheet schließt; "Preis für Butter übernommen · Widerrufen".
4. Alternativ "Nicht dieses Angebot": Schild verschwindet für Butter bis zum Ablauf, Rückgängig-Hinweis.

### 12.3 Markt einer Liste festlegen
1. Neue Liste "Lidl" (Kapitel 11): Markt-Chip "● Lidl" steht sofort (aus dem Namen).
2. Liste "Wocheneinkauf" ohne Markt: Chip "Markt wählen" > Menü > "Lidl". Gänge sortieren sich nach der Lidl-Reihenfolge, Schilder erscheinen beim nächsten Öffnen bzw. sofort, wenn der Cache Lidl-Angebote kennt.
3. Gelernt: Nach dem zweiten Abschluss bei Lidl erscheint "Du warst zweimal mit Wocheneinkauf bei Lidl. Als Markt festlegen?" > "Festlegen".
4. Standort: Jannis öffnet die App vor dem REWE (80 m, eindeutig). Hinweis-Zeile "Du bist bei REWE. REWE-Liste öffnen?" nur, wenn eine REWE-Liste existiert und sie nicht die Liste von heute ist. Sonst passiert bei "Wocheneinkauf" nichts, weil ihr Markt selbst gesetzt ist; eine Liste ohne Markt bekäme den vorgeschlagenen Chip "REWE?" (3.2). Nie automatisches Umschalten.

### 12.4 Region festlegen
1. Erste Nutzung ohne Onboarding-Region: Ersparnis-Zeile fehlt, stattdessen "Für Angebote in deiner Region: Postleitzahl festlegen" > "Festlegen".
2. Region-Sheet: "Standort verwenden" > Vorab-Erklärung > "Weiter" > Systemabfrage > "Aktuell: 79098 Freiburg im Breisgau" > `checkmark`.
3. Alternativ PLZ tippen "79098", Ort erscheint live, `checkmark`.
4. Ab dem nächsten Öffnen der Liste: Schilder und Ersparnis-Zeile.

### 12.5 Angebote der Woche auf die Liste
1. Alle Listen > Sparen > "Angebote der Woche · 6 passen zu deinen Listen".
2. Segment "Oft gekauft": "Kölln Zarte Haferflocken · ● REWE · 1,49 €" > `plus.circle`.
3. Menü "Auf welche Liste?" wächst aus dem Knopf: "Wocheneinkauf" steht oben, darunter grau "Lidl · Angebot gilt dort nicht". Jannis wählt "Wocheneinkauf". Hinweis "Haferflocken auf Wocheneinkauf · Angebot gilt nur bei REWE · Widerrufen"; der Artikel wird ohne Angebot angelegt, weil die Liste eine Lidl-Liste ist.
4. Segment "Deine Listen", Sektion "Wocheneinkauf · Lidl": Kaffee-Angebot `plus.circle` > hängt sich an den offenen Artikel "Kaffee" an ("Angebot an Kaffee angehängt · Widerrufen"), keine zweite Zeile.

### 12.6 Angebote abschalten
1. Einzeln: Ersparnis-Zeile wischen > "Nicht mehr zeigen" > Rückgängig-Hinweis; in "Preise & Angebote" steht "Ersparnis in der Liste" auf aus.
2. Pro Liste: Listenmenü > "Angebote für diese Liste ausblenden" > alle Schilder dieser Liste verschwinden mit `springStandard`.
3. Ganz: Profil > "Preise & Angebote" > Hauptschalter aus > Abschnitt "Anzeigen" klappt zusammen; in der ganzen App verschwindet Gelb; Sektion "Sparen" in Alle Listen weg; Markt-Chip bleibt.
4. Per Avo: "Schalte die Angebote aus." > Ergebniszeile "Preise & Angebote ausgeschaltet · Widerrufen".
5. Remote: Flag `offers_enabled = false` > beim nächsten Öffnen jedes Screens wie 3, zusätzlich Seite "Märkte", kein Schalter, kein Hinweis.

### 12.7 Einkauf abschließen mit Betrag und Kosten teilen
1. Einkaufsmodus Lidl, 9 von 11 abgehakt > "Einkauf beenden".
2. Abschluss-Sheet: "9 Artikel im Wagen", "2 bleiben …", "● Lidl" vorausgewählt ("Markt dieser Liste"), Betrag "42,80" tippen (Sheet wird groß), "Kosten teilen" an, "ca. 3,20 € durch Angebote gespart, laut Händler".
3. `checkmark`. Sheet schließt; Erfolgsmoment "Einkauf gespeichert." mit "9 Artikel · ca. 3,20 € …", Erfolgs-Haptik.
4. Sheet "Kosten teilen" öffnet: 42,80 €, Bezahlt von Du, Gleich, Du und Lena je 21,40 €. `checkmark`.
5. Rückgängig-Hinweis "Einkauf gespeichert · Widerrufen" (4 s). Liste zeigt Brokkoli und Gouda.
6. Lena bekommt: "Jannis hat bei Lidl eingekauft (9 Artikel)." und "Jannis hat den Einkauf geteilt: dein Anteil 21,40 €."
7. Startseite Lenas: Hinweis-Zeile "2 offene Beträge · du schuldest 21,40 €, dir werden 11,58 € geschuldet" mit Chevron (Lena schuldet den Anteil von heute, Jannis ihr noch den vom 4. Nov.; Beträge werden nicht verrechnet, K12-09). Hätte sie nur diesen einen offenen Anteil, stünde dort "Du schuldest Jannis 21,40 € · Wocheneinkauf" mit "Zurückgezahlt".

### 12.8 Einkauf wiederholen
1. Alle Listen > Verlauf > Zeile "Wocheneinkauf · ● REWE · Mi., 4. Nov." > Einkauf-Detail.
2. "Alle wieder auf die Liste" (Ziel Wocheneinkauf). "5 Artikel auf Wocheneinkauf · Widerrufen"; 2 Zeilen zeigen "Auf Wocheneinkauf".
3. Zurück-Wischen zum Verlauf; Tab Liste zeigt die neuen Artikel in ihren Gängen mit aktuellen Lidl-Angeboten.

### 12.9 Kosten nachträglich teilen, erinnern, bezahlt
So entstand die Aufteilung des Grillabends (Einkauf 5 der Beispieldaten), am 1. und 2. Nov.:
1. Startseite: Hinweis-Zeile "Grillabend mit Lena teilen? 39,60 €" > "Teilen".
2. Sheet: "Person hinzufügen" > "Tom" > Return; Gleich: je 13,20 €. `checkmark`.
3. Einkauf-Detail > Sektion "Kosten teilen" > Zeile Tom nach links wischen > "Erinnern" > System-Teilen mit dem Text "Kleine Erinnerung: 13,20 € für unseren Einkauf „Grillabend“ bei Kaufland am 1. Nov. Danke." > Nachrichten.
4. Lena überweist am 2. Nov.: "Bezahlt" bei Lena > Rückgängig-Hinweis "Lena: bezahlt · Widerrufen"; "Schuldet dir" zählt herunter (Ziffern rollen). Tom ist bis heute offen (13,20 €).

### 12.10 Offene Beträge begleichen
1. Hinweis-Zeile "3 offene Beträge · dir werden 34,60 € geschuldet, du schuldest 11,58 €" > Offene Beträge.
2. Lena nach links wischen > "Bezahlt" (leichter Impuls an der Schwelle) > Zeile wandert nach "Erledigt (2)", "Schuldet dir" rollt auf 13,20 €.
3. Lena bekommt: "Jannis hat deinen Anteil (21,40 €) als bezahlt markiert."
4. Versehentlich? "Widerrufen" im Hinweis.

---

## 13. Entscheidungen dieses Kapitels

| Nr. | Entscheidung | Grund |
|---|---|---|
| K12-01 | Ohne echte Region keine Angebote und keine Anfragen an die Angebotsquelle; die Ersatz-PLZ 10115 wird in der Oberfläche nicht mehr genutzt | Recherche (Ersparnis ohne PLZ ist falsch, "deutschlandweit" war Berlin), Datensparsamkeit, Ehrlichkeit |
| K12-02 | Schilder und Ersparnis-Zeile erscheinen nur aus dem Cache beim ersten Frame; neue Angebote beim nächsten Öffnen | 00 13 (keine Layout-Sprünge); heute wird jede Zeile nachträglich höher |
| K12-03 | Liste ohne Markt zeigt Angebote der Lieblingsmärkte in deren Reihenfolge, nie das günstigste; das Schild trägt dann den Markenpunkt (E-16); ohne Lieblingsmärkte keine Schilder, stattdessen die Hinweis-Zeile "Markt fehlt". Bewusste Abweichung von Verbesserungsliste 6c ("alle Märkte der Region") | Bei mehreren Märkten pro Artikel müsste eine Auswahlregel greifen; jede andere als eine feste Nutzer-Reihenfolge wird ein verdeckter Marktvergleich (Plan 8). Der Plan selbst nennt keinen Rückfall |
| K12-04 | Angebot aus dem Panel oder aus Angebote der Woche hängt sich an einen vorhandenen Artikel bzw. legt den Artikel mit einfachem Namen an | behebt Duplikate (Bug 8), Liste bleibt in der Sprache des Nutzers |
| K12-05 | Verlauf-Diagramm zeigt Ausgaben pro Monat, wenn in 3 von 6 Monaten Beträge erfasst sind, sonst Einkäufe pro Monat; der Einkaufstag wird ein Satz statt Diagramm | eine Frage, eine Reihe (00 4.7); heute zwei Zeiträume in einem Bild |
| K12-06 | "Betrag" im Abschluss ist Kern (für den Monatsrückblick), "Kosten teilen" ist Modul | Verlauf ist Kern; Ausgaben brauchen keinen Teilen-Zusammenhang |
| K12-07 | `total_cost` nur aus Eingabe, nie aus Angebotspreisen | Bug 7 (Teilsumme als Gesamtkosten) |
| K12-08 | Einkauf-Detail als eigener Push statt Aufklappen | Platz für "Alle wieder auf die Liste", Kosten teilen, Mitteilungsziel; Route möglich |
| K12-09 | Offene Beträge pro Anteil (eine Zeile pro Einkauf und Person), nicht pro Person summiert | jede Zeile ist einzeln begleichbar; Summen stehen im Sektionskopf |
| K12-10 | Ändert sich ein bezahlter Anteil, wird er wieder offen, angekündigt im Sheet statt per Dialog | Agency; behebt das stille Zurücksetzen (Bug 1) |
| K12-11 | Zahlungserinnerung über das System-Teilen, nicht Zwischenablage | iOS-Muster, ein Schritt weniger |
| K12-12 | Bei "Ersparnis unter 0,50 €" entfällt der Spar-Teil des Satzes | Kleinstbeträge wirken wie Werbung und sind innerhalb der Rundung ungenau |
| K12-13 | Angebote der Woche trennt "Deine Listen" und "Oft gekauft" per Segment; Markt-Chips sind Einfachauswahl | Eine Seite, eine Frage pro Ansicht; die frühere Chip-Reihe mischte Ansichten und Filter, und UND-Verknüpfung (00 12.19) ergäbe bei zwei Märkten oder "Listen" plus "Oft gekauft" immer eine leere Menge |
| K12-14 | Mitteilungen zu Einkauf, Aufteilung und "bezahlt" gehen erst nach Ablauf des Rückgängig-Hinweises raus | Ein Widerrufen soll bei anderen keine falsche Nachricht hinterlassen |

---

## 14. Offene Fragen

| Nr. | Frage | Vorschlag |
|---|---|---|
| F12-1 | Wie heißt die Angebotsquelle in der Fußnote, solange keine Lizenz besteht (marktguru wird angefragt)? Darf sie überhaupt genannt werden? | Platzhalter `{Angebotsquelle}`; Text "Quelle: Händlerprospekte" bis zur Klärung |
| F12-2 | Arbeitsteilung nennt für `ListOfferSummary` den Ort "Liste unten", 00 12.12 die Sektion "Für heute" oben. Welche gilt? | 00 gilt (Hinweis-Zeile oben, höchstens 2); Arbeitsteilung anpassen |
| F12-3 | Kassenbon scannen (Verbesserungsliste 16) als Weg zum Betrag und zum Aufteilen? | später; im Abschluss-Sheet ist neben "Betrag" Platz für `camera` "Bon scannen", ohne Umbau |
| F12-4 | Wie weit reicht der Verlauf zurück (heute ohne Grenze geladen)? | alles behalten, seitenweise laden; Diagramm 6 Monate; Jahresrückblick später (Pro-Kandidat) |
| F12-5 | Werden "Statistiken" (Monatsrückblick über den laufenden Monat hinaus) oder "Kosten teilen" Pro (F-05)? | Flächen sind vorbereitet (8.1, 7.1); Empfehlung: Kosten teilen frei (Wachstum über geteilte Listen), Statistiken Pro-Kandidat |
| F12-6 | Kosten teilen auch für nicht geteilte Listen mit Namens-Personen im Abschluss-Sheet anbieten? | nein im Abschluss (nur geteilte Listen), ja nachträglich im Einkauf-Detail |
| F12-7 | Gelten Lieblingsmärkte und "Angebote ausblenden" pro Person oder für alle Mitglieder einer Liste? | pro Person; der Listen-Markt selbst gilt für alle Mitglieder |
| F12-8 | Monatsbudget / Spar-Ziel (Verbesserungsliste 16)? | nicht in Version 1; die Monats-Sektion kann später eine Zielmarke (gestrichelt, 00 12.16) bekommen |
| F12-9 | Darf das Ketten-Verzeichnis Markenfarben ohne Erlaubnis nutzen (nur Farbpunkt, kein Logo)? | ja als Punkt; bei Einwand der Kette Punkt in Graphit |
| F12-10 | Die freie Suche in Angebote der Woche zeigt Treffer mehrerer Märkte untereinander. Ist das schon ein Marktvergleich im Sinne von Plan 8? | nein, solange nichts sortiert, markiert oder summiert wird (5.1); falls der Owner strenger sein will: Suche standardmäßig auf Listen-Märkte filtern |
| F12-11 | 01 2.3 und 00 12.12 nennen als Beispiel "12 passen zu deinen Listen" bzw. "5 Sachen" und "Ca. 42 €"; dieses Kapitel rechnet mit 6, 3 und 42,80 € aus den Beispieldaten | Beispielzahlen in 00/01 angleichen (Teil A) |
| F12-12 | Kapitel 11 beschreibt die B-Slots teils anders als dieses Kapitel: (a) Tippen auf den gesetzten Markt-Chip öffnet dort das Markt-Sheet, hier ein Menü aus dem Chip (3.1); (b) Markt-Sheet dort mit `checkmark` und Sektionen "Vorschläge / Lieblingsmärkte / Alle", hier Tippen wählt und "Deine Märkte / In der Nähe / Alle" (3.3); (c) dortiger Fuß "Kein fester Markt: Dann zeigen wir Angebote aller Märkte in deiner Region" widerspricht K12-03; (d) Abschluss-Sheet heißt dort "Einkauf beenden", hier "Einkauf abschließen"; (e) Speichern-Fehler dort als `StatusRow` im offenen Sheet, hier optimistisch mit Rückgängig-Leiste; (f) Fuß ohne Standort dort dauerhaft, hier einmalig (7.1) | Inhalte der B-Slots legt dieses Kapitel fest; Teil A gleicht 11 an. Für (d) Vorschlag: Sheet-Titel "Einkauf beenden" wie der Knopf im Einkaufsmodus, Menüeintrag ebenso; dann hier anpassen |

---

## 15. Ergänzungen zum Fundament

Diese Punkte fehlen in 00/01 und werden hier vorgeschlagen; Teil A entscheidet über Aufnahme in die Komponenten-Bibliothek, Teil B baut die mit "B" markierten im eigenen Ordner.

| Nr. | Ergänzung | Inhalt | Wer |
|---|---|---|---|
| E-01 | `StoreLabel` (kompakte Variante von `StoreChip`) | 8-pt-Markenpunkt plus Kettenname in der Schrift der umgebenden Zeile, ohne Kapsel und ohne Chevron; für Zeilen (Verlauf, Offene Beträge, Angebote, Sektionstitel). Nicht antippbar. VoiceOver "Markt Lidl". | B |
| E-02 | `ItemOfferBadge` Größe L | gelbe Kapsel mit Preis in `numberL`, nur im Angebots-Sheet; wächst bis AX2 | B |
| E-03 | `OfferRow` | Zeile für ein Angebot: Avo Symbol 28 pt, Produktname (`body`), bis drei Unterzeilen (`subheadline`, `labelSecondary`): Zuordnung "Für „Milch“ auf …", "Packung · Grundpreis · laut Händler statt …", Ablauf bzw. "Ähnliches Produkt"; rechts `ItemOfferBadge`, optional `plus.circle` 44 pt. Varianten kompakt (Panel: eine Unterzeile) und voll. AX: stapelt. | B |
| E-04 | `AmountField` | Betragseingabe nach Locale ("42,80 €", Zeichen nach der Zahl im Deutschen), Ziffernblock mit Komma, liest "1.234,56" und "1234,5", tabellarische Ziffern; Varianten kompakt (in `ValueRow`, `number`) und groß (`numberXL`, linksbündig, gedeckelt 51 pt). Keine feste Breite. | A (Basis), B nutzt |
| E-05 | `TripRow` | Zeile wie Wallet-Transaktion: Listen-Glyph 28 pt, Titel, Unterzeile mit `StoreLabel` · Datum · Anzahl, optionale zweite Unterzeile in `label` (Geld-Status), rechts Betrag in `number`, Chevron; Zustände ausstehend (Sync-Zeichen), Fehler. AX: Glyph entfällt, Betrag unter den Text. | B |
| E-06 | Großer Titel für Bereichsseiten | 00 12.2 sagt "tiefere Ebenen: nur Inline-Titel". Ausnahme vorschlagen: Verlauf, Angebote der Woche und Offene Beträge tragen immer einen großen Titel, weil sie auch direkt von Hinweis-Zeilen der Tab-Wurzel (erste Ebene) erreicht werden und sonst je nach Weg anders aussähen. Einkauf-Detail bleibt Inline. | A entscheidet |
| E-07 | Symbole für 00 9.2 | `cart.badge.plus` (Wieder auf die Liste, Auf die Liste), `plus.circle` (Angebot hinzufügen in Zeilen), `line.3.horizontal.decrease.circle` (Filter im Verlauf), `questionmark.circle` (Ähnliches Produkt, unsichere Zuordnung; auch 01 5.3 Import), `person.badge.plus` (Person hinzufügen), `eye.slash` (Angebote für diese Liste ausblenden), `chevron.up.chevron.down` (Auswahl-Menü in einer Zeile, z. B. "Bezahlt von"). Alle ab iOS 15 vorhanden. | A (Manifest) |
| E-08 | Auswahl-Kreis (`SelectCircle`) | Mehrfachauswahl in Zeilen (Teilnehmer, Zutaten abwählen): `checkmark.circle.fill` in `action` bzw. Ring `controlOutline`, 22 pt in 44-pt-Ziel; ausdrücklich getrennt von `CheckCircle` (Abhaken), damit "erledigt" eindeutig bleibt; keine Haptik. Gleiches Bild wie `PlanRow` (00 12.31). | A |
| E-09 | `FilterChip` mit Markenpunkt, Einfachauswahl | Variante von 00 12.19 mit führendem 8-pt-Markenpunkt; gewählt wie gehabt (`actionFill`, `checkmark`, der Punkt bleibt). Abweichend von 00 12.19 Einfachauswahl (ein Markt), erneutes Tippen hebt die Auswahl auf. Für Abschluss "Wo warst du?" und Marktfilter in Angebote der Woche. | A (Variante), B nutzt |
| E-10 | Hinweis-Zeilen-Inhalte | Tabelle 6.2 ergänzt 00 12.12 um "Region fehlt", "Markt fehlt", "Markt lernen", "Kosten teilen einschalten", Varianten "Offener Betrag (einer/mehrere)" mit Sofort-Aktion "Bezahlt". | B (Inhalt), A (Anordnung) |
| E-11 | Regel "Keine Angebote ohne echte Region" | 00 15.3/15.4 und 4.4 ergänzen um K12-01: Ohne echte Region erscheint keine Angebotsfläche und es gehen keine Anfragen raus. | Konzept 00 |
| E-12 | Routen | `/offers?filter=regulars` (Oft gekauft), `/history?list=:id` (Filter), `/history/:tripId/amount` (Betrag-Sheet, optional) in die Routentabelle 01 7 | A (Gerüst), B (Bereichsdatei) |
| E-13 | Daten | `shopping_lists.store_chain`, `store_source`; `shopping_history.store_chain` (Ketten-ID statt OSM-Name), `total_cost_source` (`user`), `user_offer_prefs` (Einzel-Schalter, ausgeblendete Listen, Lieblingsmärkte mit Reihenfolge, Region), lokale Liste "Nicht dieses Angebot" pro Artikel; `app_flags.offers_enabled`. Dokumentation in `database/migrations/`. | B |
| E-14 | Haptik-Tabelle 00 11 | Klarstellen: "Bezahlt markieren" ohne Haptik (umkehrbar, sichtbar), Wischen über die Schwelle wie gehabt leichter Impuls; Speichern einer Aufteilung ohne Erfolg-Haptik (Geld ist kein Erfolgsmoment). | Konzept 00 |
| E-15 | Prüfregel Kill-Switch | Layout-Prüfgerüst (`test/layout/`) bekommt einen Lauf mit `offers_enabled = false`, der in den Goldens die Farbe #FFD60A und die Wörter "Angebot", "gespart", "laut Händler" verbietet. | A (Gerüst), B (Testfälle) |
| E-16 | `ItemOfferBadge` Variante "mit Markt" | 8-pt-Markenpunkt vor dem Preis im gelben Schild (helle Punkte mit 0,5-pt-Kontur in `separator`); nur in Listen ohne Markt (3.4) und in Zeilen, die mehrere Märkte mischen. VoiceOver nennt den Markt. | B |
| E-17 | Reihenfolge im Vorschlags-Panel (00 12.4) | Zählung vom Eingabefeld aus: Vorschau direkt über dem Feld, darüber Verlaufstreffer, am oberen Ende die Angebote. Nachkommende Angebote vergrößern das Panel nach oben, ohne dass Vorschau oder Verlaufstreffer unter dem Finger wandern. | A entscheidet |
| E-18 | Glas-Budget mit Rückgängig-Hinweis | Auf Screens mit drei Glas-Elementen (z. B. Einkauf-Detail: Zurück, `ellipsis`, Tab-Bar) wäre der schwebende Rückgängig-Hinweis das vierte (00 8.5). Vorschlag: Der Hinweis zählt nicht mit, weil er kurz lebt, oder die Toolbar-Knöpfe links und rechts bilden eine Glasgruppe. | A entscheidet |

---

## 16. Abdeckung der Inventare

Jede heutige Fläche aus `inventar/history.md`, `inventar/lists-more.md` und `inventar/home.md`, die diesen Bereich berührt, mit ihrem neuen Ort oder dem Grund für das Entfernen. Flächen, die nur Teil A betreffen, stehen mit Verweis auf Kapitel 11.

| Heute | Neu | Abschnitt |
|---|---|---|
| Verlauf "Aktivitäten" (`ShoppingHistoryScreen`, ohne Route) | Push `/history` mit Monats-Sektion und `TripRow`s | 8.1 |
| Kennzahlen "Artikel gekauft / Einkäufe / Verlauf" (Lebenszeit) | Zeilen der Monats-Sektion; die Lebenszeit-Zahl entfällt (mischte zwei Zeiträume); die Einkaufszahl im Profil bleibt (Teil A) | 8.1 |
| "Du hast X € durch Angebote gespart." und Vormonatsvergleich | "Durch Angebote gespart · ca. 9,80 € · laut Händler" (Modul), Vergleich nur bei gleich guter Erfassung | 8.1 |
| Wochentags-Diagramm, "Samstag ist dein Einkaufstag." | Satz-Zeile "Meist eingekauft · samstags" (eine Frage, eine Reihe) | 8.1, K12-05 |
| Aufklappbare Einkaufszeile mit Artikeln, Ersparnis, Aufteilung | Einkauf-Detail `/history/:tripId` | 8.2, K12-08 |
| Löschen per Langdruck mit Dialog | Wischen und Kontextmenü, Rückfrage bleibt (endgültig) | 8.1, 10.1 |
| `_SplitSection`, Pille "Bezahlt/Offen", Kopier-Erinnerung | Sektion "Kosten teilen" mit "Bezahlt", "Wieder als offen markieren", "Erinnern" per System-Teilen | 9.2 |
| `_SplitCostSheet` | Sheet "Kosten teilen" | 9.1 |
| `WeeklyDealsScreen` mit `_DealCard`, Rabatt-Badge, Händlerbild | Push `/offers` mit Segment, Markt-Chips, `OfferRow` | 5.1 |
| `_AddDealSheet` | Menü "Auf welche Liste?" | 5.2 |
| `PendingSplitsBanner` | Hinweis-Zeilen "Offener Betrag" und Seite Offene Beträge | 6.2, 9.3 |
| `SplitTripNudgeCard` | Hinweis-Zeile "Einkauf teilen" | 6.2 |
| Startseiten-Angebote-Streifen | Alle Listen > Sparen > "Angebote der Woche" (01 2.3) | 5.1 |
| Startseiten-Verlaufszeile "Zuletzt eingekauft" | Alle Listen > Verlauf > "Einkäufe" (01 2.3) | 8.1 |
| `PersonalFlyerCard` ("Dein Prospekt", nicht bedienbar) | Hinweis-Zeile "Prospekt" und Segment "Oft gekauft", jetzt bedienbar | 6.2, 5.1 |
| `AvoNudgeCard`, Angebots-Teil (inkl. Schlummern) | Segment "Oft gekauft" mit "Nicht interessiert"; der Nachkauf-Teil gehört zu "Vielleicht auch" (Kapitel 11) | 5.1 |
| `PriceComparisonNudgeCard` ("bei A X € günstiger als bei B") | entfällt ersatzlos (Plan 8) | 4.4 |
| `ListPriceSummaryBar` ("günstigster Korb", "bekannt k/n", PLZ-Chip) | Ersparnis-Zeile `ListOfferSummary` | 4.4 |
| Marktvergleich-Sheet mit Rangliste und "Näher dran … nur X € mehr" | entfällt ersatzlos (Plan 8) | 4.4 |
| `ItemOfferChip` ("Spare X € bei {store}") und Angebots-Sheet ("AKTUELLES ANGEBOT", "-X %", "Spart X € gegenüber …") | `ItemOfferBadge` und Angebots-Sheet mit "laut Händler" | 4.1, 4.2 |
| `OfferSuggestionsBar` (Karte, 72 pt feste Zeilen, "Spare bis zu") | Angebots-Block im Vorschlags-Panel, nur Markt der Liste | 4.3 |
| `showZipCodeSheet`, `showManualZipDialog`, PLZ in "Persönliche Daten" | Sheet "Region für Angebote" | 6.1 |
| Fallback-PLZ 10115 ("Deutschlandweite Angebote") | entfällt in der Oberfläche (K12-01) | 1, 6.1 |
| `checkout_store_sheet.dart` und stilles GPS vor dem Abschluss | Abschluss-Sheet mit "Wo warst du?" und Sheet "Markt" | 7.1, 3.3 |
| Bestätigungs-Alert "Einkauf abschließen?" und Snackbar "Kosten teilen" | entfällt; Abschluss-Sheet, Erfolgsmoment, Rückgängig-Hinweis | 7.1, 7.3 |
| `total_cost` aus Angebotspreisen | Betrag nur durch Eingabe | 1 (Regel 14), K12-07 |
| Push "Anteil beglichen" (englisch, Emoji, ohne Routing) | lokalisierte Mitteilungen, Ziel Einkauf-Detail | 9.1, 9.2 |
| Avo-Werkzeuge `split_trip_cost`, `get_savings_summary`, `get_personalized_deals`, `get_shopping_history`, Korbvergleich | Werkzeuge in 11; Korbvergleich entfällt | 11 |
| marktguru-Ersatz-Schlüssel, Schlüssel aus Seitenquelltext | entfallen (6a) | 1 (Regel 10) |
| Listeneinstellungen, Kategorie-Reihenfolge, Teilen-Dialog, Listen-Aktivitäten, Ungelesen, Listen-Hintergründe | Kapitel 11 (Listen-Info 10, Reihenfolge im Markt 12, Teilen 9, "Alle Änderungen" 10.3, Ungelesen-Punkt 1.2, Listenfarben 13) | – |
| Kalorien-Rezepte, Begrüßung, Listen-Index der Startseite | Kapitel 10, 11 und Kalorien-Kapitel | – |
