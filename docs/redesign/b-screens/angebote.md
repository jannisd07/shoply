# Preise & Angebote: Screen-Spezifikation (Teil B, Paket B8 Angebote und Slots)

Stand 08.11.2026. Bauplan für alle Screens, Vollbild-Routen und Slots des Moduls `AppModule.offers` samt dem
Kern-Teil „Markt pro Liste“, damit alles direkt nach S2 (Tokens und Komponenten von Teil A) gebaut werden kann. Diese
Datei enthält keinen Code.

**Quellen und Rang.** Jannis' Plan (`docs/superpowers/plans/2026-11-07-teil-b.md`, Global Constraints) vor
`design-quelle.md` vor Konzept. Aussehen aus D2 · Glas (`D2-Komponenten`, `X-Angebote`, `X-Einkaufsmodus`,
`D2-Liste`, `D2-Artikel`, `D2-Home`, `X-Profil`). Funktion, Abläufe, Zustände, Texte und Barrierefreiheit aus
`konzept/12-angebote-verlauf.md` (Abschnitte 1 bis 6, 10, 11, 13 bis 15), `konzept/13-rezepte.md` (Slots E-06),
`konzept/17-onboarding.md` 3.4, Kapitel 00, 01 und 20. Recht aus `docs/research/Preise Angebote und Artikelbilder.md`
gilt immer. Verträge aus `status-A.md` (Routen, Module, Übersetzungen) und `prompt-b-vorrang.md` (Slot-Signaturen).
Wo D2 und Konzept sich widersprechen, steht in Abschnitt 5 eine Empfehlung; sie gilt, bis der Owner entscheidet.

**Owner-Regeln, die hier besonders greifen.** Keine Bottom-Sheets, halbhohen Modals, Drawer oder Schieberegler: jedes
Konzept-Sheet dieses Kapitels (Markt, Angebot, Angebote bei Lidl, Region, Vorab-Erklärung Standort, Modul-aus) ist
hier ein Vollbild-Screen, ein Pull-down-Menü oder ein zentrierter Dialog. Angebote sind nie Pro. Avo erscheint nie bei
Geld, Ersparnis, Fehlern oder Offline; in diesem Bereich gibt es genau eine erlaubte Figur (S10, Suche ohne Treffer).

Komponentennamen in `Code-Schrift` sind Bausteine von Teil A (S2a ist geliefert, S2b folgt) oder B-eigene Bausteine
(Abschnitt 2.3). Was fehlt, steht als Anfrage in Abschnitt 6. Alle Texte stehen Deutsch und Englisch hier und kommen in
`lib/core/localization/translations/offers.dart` mit Präfix `offer_` (Datei gehört während dieses Pakets einem
parallel laufenden Workflow, siehe Abschnitt 7). Sie sind mit `design:ux-copy` und `humanizer` geprüft: Du-Form, keine
Ausrufezeichen, keine Emojis, keine Werbesprache, Pflicht-Wortlaut „in deiner Region“, „laut Händler“, „ca.“. Die alten
Vergleichs-Schlüssel (`cheapest_basket`, `store_comparison`, `save_at_store`, `swap_saves`, `estimated_list_total`,
`home_price_highlight_*`, `closer_option_*`, `offers_nationwide_set_zip`, `recipe_offers_save`, `comparable_note`,
`items_on_offer_here`, `known_of_items`, `cheapest_at`, `price_data_from_offers` und die übrigen Marktvergleichs-Texte)
entfallen mit den Dateien, die sie heute nutzen.

## Inhalt

0. Überblick
1. Routen und Navigation
2. Bausteine und Maße aus D2
3. Regeln für alle Screens
4. Screens und Slots S1 bis S16
5. Konflikte zwischen D2 und Konzept, Owner-Fragen
6. Anfragen an Teil A
7. Datenquellen und Lücken
8. Prüfliste für Screenshots

---

## 0. Überblick

Die Frage des Bereichs: **Was von meiner Liste ist diese Woche bei meinem Markt im Angebot?** Die Antwort steht dort,
wo man einkauft: als grüne Pille an der Artikelzeile, als Satz unten in der Liste und oben im Einkaufsmodus. Alles
andere (Detail, Wochenübersicht, Region, Märkte) ist einen Tipp entfernt und nie Voraussetzung, um die Liste zu nutzen.

| Nr. | Screen oder Slot | Route | Art |
|---|---|---|---|
| S1 | Markt-Chip `StoreChip` mit Menü „Markt“ und Rückfrage „Ist das deine Lidl-Liste?“ | Slot im Listenkopf, im Einkaufsmodus, in der Listen-Info (A) | B-Widget + Pull-down-Menü |
| S2 | Markt wählen | `/stores/pick` | V (Vollbild) |
| S3 | Angebots-Pille `ItemOfferBadge` | Slot in der Artikelzeile (A) | B-Widget |
| S4 | Angebotskarte `ItemOfferCard` | Slot im Artikel-Vollbild (D2-Artikel, A) | B-Widget |
| S5 | Angebot | `/offers/offer/:offerId` | V |
| S6 | Angebote beim Tippen `OfferSuggestionsBar` | Slot im Vorschlags-Panel des Eingabefelds (A) | B-Widget |
| S7 | Ersparnis-Zeile `ListOfferSummary` | Slot am Ende der Liste und oben im Einkaufsmodus (A) | B-Widget |
| S8 | Zähler auf der Listenkarte `ListOfferCountBadge` | Slot auf dem Cover der Listenkarte (D2-Home, A) | B-Widget |
| S9 | Angebote bei {Markt} | `/offers/list/:listId` | K (Push im Listen-Tab) |
| S10 | Angebote der Woche, Menü „Auf welche Liste?“ | `/offers` | Wurzel (Push im Listen-Tab) |
| S11 | Region (bei Kill-Switch „Standort“) | `/settings/offers/region` und `/stores/region` | E bzw. V |
| S12 | Preise & Angebote (bei Kill-Switch „Märkte“) | `/settings/offers` | E (Push im Profil-Tab) |
| S13 | Lieblingsmärkte | `/settings/offers/markets` | E |
| S14 | Onboarding-Schritt `OffersSetupStep` | Slot in `/onboarding?step=region` (A) | B-Widget |
| S15 | `RecipeOffersCard` und „Angebote für {Rezept}“ | Slot im Rezeptdetail (A); `/offers/recipe/:recipeId` | B-Widget + V |
| S16 | Dialoge und Sonderseiten: Modul aus, Kill-Switch, Änderungen verwerfen | ohne eigene Route | zentrierter Dialog bzw. Fehlerseite von A |

Nicht Teil dieser Datei (eigene B-Specs): Einkauf abschließen samt Ersparnis-Unterzeile und Erfolgsmoment, Verlauf,
Kosten teilen, Home-Abschnitte (`HomeSavingsHint`, `HomeOffersTile`, `HomeSavingsGoal`). Sie nutzen dieselben Bausteine
aus Abschnitt 2.3 und dieselbe Rechnung aus `offer_savings.dart`.

---

## 1. Routen und Navigation

### 1.1 Vier Arten von Routen (Vertrag aus `status-A.md`, Datei `lib/routes/areas/offers_routes.dart`)

| Art | Liste in der Bereichsdatei | Wo es öffnet | Kopf | Tab-Leiste |
|---|---|---|---|---|
| Wurzel | `buildOffersRoot` | A hängt `/offers` als Push in den Listen-Branch | `GlassIconButton` `chevronBack` „Zurück“ | sichtbar |
| K (Kind) | `offersChildRoutes`, Pfade relativ (`'list/:listId'`) | im Listen-Branch | `chevronBack` | sichtbar |
| V (Vollbild) | `offersRootRoutes`, Pfade absolut (`'/offers/offer/:offerId'`, `'/stores/pick'`) | Root-Navigator über der Tab-Leiste, über dem Tab, aus dem man kommt | `chevronBack` (Detail) oder `xmark` „Schließen“ (Auswahl, Bearbeiten) | nicht sichtbar |
| E (Einstellung) | `offersSettingsRoutes`, relativ zu `/settings` (`'offers'`, `'offers/region'`, `'offers/markets'`) | Profil-Tab | `chevronBack` | sichtbar |

**Warum Angebot, Markt wählen, Region aus der Liste und Rezept-Angebote V-Routen sind:** Sie öffnen aus drei Tabs
(Listen, Rezepte, Avo) und aus A-Vollbildern (Einkaufsmodus, Einkauf abschließen). Als Kind von `/offers` läge jedes im
Listen-Branch; aus dem Rezepte-Tab würde GoRouter den Tab wechseln, und über einem Vollbild von A wären sie unsichtbar
(der Branch liegt unter dem Root-Navigator). Als V-Route öffnen sie über allem und kehren beim Schließen genau dorthin
zurück. Dafür müssen `offersRootRoutes` vor der Shell stehen, weil zwei davon mit `/offers` beginnen (Anfrage A-R1).

**Übergang.** Jede Route öffnet mit dem iOS-Push von rechts (Cupertino-Übergang, Zurück-Wischen vom linken Rand).
Nichts gleitet von unten herein. Markt wählen und Region geben ihr Ergebnis über `context.pop(result)` zurück; der
Aufrufer zeigt den Rückgängig-Hinweis (so steht er dort, wo man die Änderung sieht).

**Kern oder Modul.** `/stores/*` gehört zum Kern (Markt pro Liste, Standort für Markt-Vorschläge) und bleibt bei Modul
aus und Kill-Switch erreichbar. Alles unter `/offers/*` gehört zum Modul. `/settings/offers*` bleibt erreichbar und
ändert seinen Inhalt (S12).

### 1.2 Alle Pfade

| Nr. | Pfad | Art | Parameter | Zurück führt zu |
|---|---|---|---|---|
| S10 | `/offers` | Wurzel | `filter=regulars` (öffnet Segment „Oft gekauft“), `q=` (Suchbegriff vorbefüllt, von Avo) | Ausgangsort im Listen-Tab |
| S9 | `/offers/list/:listId` | K | | Liste bzw. S10 |
| S5 | `/offers/offer/:offerId` | V | `list=` (Ziel-Liste), `item=` (Artikel, an dem das Angebot hängt), `mode=take\|add` (Hauptaktion „Preis übernehmen“ bzw. „Auf die Liste“; fehlt: `take` mit `item`, sonst `add`); das Angebot selbst kommt aus dem lokalen Angebots-Cache, nicht aus der URL | Ausgangsort |
| S15 | `/offers/recipe/:recipeId` | V | `list=` (Ziel-Liste), `servings=` | Rezeptdetail |
| S2 | `/stores/pick` | V | `list=` (Liste, deren Markt gewählt wird; fehlt: nur Auswahl, z. B. aus „Neue Liste“ oder „Einkauf abschließen“), `from=chip\|checkout\|newList\|info` | Ausgangsort; Ergebnis `StoreChoice?` (Ketten-ID, eigener Name oder „kein fester Markt“) |
| S11 | `/stores/region` | V | `from=list\|offers\|panel\|avo` | Ausgangsort; Ergebnis `bool` (gespeichert) |
| S11 | `/settings/offers/region` | E | dasselbe Widget, damit man im Profil-Tab bleibt | S12 |
| S12 | `/settings/offers` | E | | Profil |
| S13 | `/settings/offers/markets` | E | | S12 |

Höchstens drei Ebenen im Listen-Tab: Liste > Angebote bei Lidl > (Angebot als V darüber). Über einem V liegt höchstens
ein weiteres V (Angebot > Markt wählen gibt es nicht; Angebote der Woche > Region ja).

### 1.3 Wächter pro Route

Die Prüfung macht der Modul-Wächter von A (S2a) mit einer Tabelle aus der B-Datei (Anfrage A-R2). Reihenfolge: zuerst
Kill-Switch, dann Modul, dann echte Region.

| Pfad | Kill-Switch aus (`offersRemoteEnabledProvider` false) | Modul aus | ohne echte Region |
|---|---|---|---|
| `/offers`, `/offers/list/:id`, `/offers/recipe/:id` | Fehlerseite von A („Diese Seite gibt es nicht mehr.“), ohne das Wort „Angebot“ | S16 Dialog „Preise & Angebote ist ausgeschaltet“, danach das Ziel | Screen öffnet mit Leerzustand „Wo kaufst du ein?“ (S10) bzw. „Für Angebote brauchst du eine Region.“ (S9, S15) |
| `/offers/offer/:id` | Fehlerseite | Dialog | kann nicht entstehen (ohne Region gibt es keine Angebote); falls doch: „Dieses Angebot ist nicht mehr gespeichert.“ |
| `/stores/pick` | öffnet normal | öffnet normal | öffnet normal |
| `/stores/region`, `/settings/offers/region` | Variante „Standort“ | öffnet normal | öffnet normal |
| `/settings/offers` | Variante „Märkte“ | Variante „Modul aus“ (S12) | `StatusRow` oben |
| `/settings/offers/markets` | Fuß-Variante | öffnet normal | öffnet normal |

Wechselt ein Flag, während ein Modul-Screen offen ist (Kill-Switch geht an, jemand schaltet das Modul auf einem
anderen Gerät aus), schließt der Screen still beim nächsten Wechsel des Flags; der Stapel fällt auf den letzten
Nicht-Angebots-Screen zurück. Kein Hinweis, kein Dialog.

### 1.4 Deep Links, Avo, Mitteilungen

| Einstieg | Ziel |
|---|---|
| `shoply://offers` | S10 über der Listen-Übersicht |
| `shoply://offers?filter=regulars`, Hinweis-Zeile „3 Sachen, die du oft kaufst …“ | S10, Segment „Oft gekauft“ |
| Avo-Ergebniszeile „Ansehen“ bei Angeboten einer Liste | S9 (wechselt in den Listen-Tab) |
| Avo „Zeig Angebote für Haferflocken“ | S10 mit `q=Haferflocken` |
| Avo „Setz meine PLZ auf 79098“ | ohne Screen; Ergebniszeile „Region: 79098 Freiburg“ mit „Widerrufen“ und „Ansehen“ (S11 als V) |
| Nachkauf-Mitteilung mit Angebot (`mascot_notification_service`, anderer Workflow) | S10 „Oft gekauft“ |
| Widget, Siri, Kontrollzentrum | keine Angebots-Ziele (K-27: kein Angebots-Widget ohne Lizenz) |

Doppelte Zustellung unter 2 s wird verworfen, ein Kaltstart-Link genau einmal ausgeführt (01 §8.1). Unbekannte
Unterpfade (`/offers/xyz`) zeigen die Fehlerseite von A.

---

## 2. Bausteine und Maße aus D2

Maße in pt (D2 zeigt px bei 390 pt Breite, 1 px = 1 pt). Hex-Werte stehen nur zur Orientierung; gebaut wird mit
`context.colors`, `context.text(AvoTextStyle.…)`, `AvoSpacing`, `AvoRadii`, `AvoSizes`, `AvoMotion`, `AvoHaptics`.

### 2.1 Grundmaße

| Element | D2-Wert | Quelle |
|---|---|---|
| Hintergrund | `background` #F2F2F7 | alle |
| Seitenrand | 16 (`AvoSpacing.screen`) | alle |
| Großer Titel | 34/41 Bold, Laufweite +0,2 (`largeTitle`); Inhalt beginnt 106 pt von oben, Titel bricht um, nie Ellipse | X-Angebote, X-Einkaufsmodus |
| Inline-Titel | 17/22 Semibold, zentriert in `GlassToolbar` | D2-Artikel |
| Toolbar | obere Kante 54; `GlassIconButton` 44 (Radius 22, Symbol 22 in `label`); getönte Text-Kapsel „Fertig“ 44 hoch, Innenrand 0 18, 17/22 Semibold weiß | D2-Artikel |
| Scroll-Kante | `ScrollEdgeFade` 110 hoch, `background` bis 30 %, dann transparent | alle |
| Gruppe | `InsetSection`: weiß, Radius 26, 16 vom Rand, Abstand zwischen Gruppen 24 | X-Angebote `.grp` |
| Gruppenkopf | `SectionCaps`: 13/18 Semibold, Großbuchstaben nur in der Anzeige, +0,3, `secondaryLabel`, Innenrand 18 32 6; Zahl rechts tabellarisch 13/18 Regular | X-Angebote `.hd`, X-Einkaufsmodus `.aisle` |
| Fußnote | 13/18 `secondaryLabel`, 6 unter der Gruppe, bei 32 vom Rand | X-Angebote `.ft` |
| Zeile | `NavRow`/`ToggleRow`/`ValueRow` von A: mindestens 52 (einzeilig) bzw. 60 (mit Unterzeile), Innenrand 16, Titel 17/22, Unterzeile 15/20 `secondaryLabel`, Wert rechts 17/22 `secondaryLabel`, Trenner 0,5 `separator` ab Textkante | X-Profil `.row`, X-Angebote `.row` (50) |
| Hauptschalter-Zeile | 56 hoch, Titel 17/22 Semibold | X-Angebote |
| Schalter | `CupertinoSwitch` 51 × 31 in `ToggleRow`, Spur `tintFill` #1F7A3A (nicht D2 #34C759, siehe 3.8), die ganze Zeile schaltet | A `settings_rows.dart` |
| Angebots-Pille | 11/13 Semibold, tabellarisch, `tint` auf `tintSoft`, Innenrand 3 8, Radius voll | D2-Komponenten, D2-Liste, X-Einkaufsmodus `.offer` |
| Markt-Chip (Liste) | 30 hoch, Innenrand 0 12 0 8, Radius voll, Fläche `surface` (weiß) mit Schatten 0 1 2 rgba(0,0,0,.06), Abstand 6, 15/20 Semibold; Buchstaben-Kachel 18 × 18 Radius 5, 10 pt Heavy; `chevronDown` 12 pt | X-Einkaufsmodus |
| Markt-Chip (Einstellungen) | 32 hoch, Innenrand 0 12 0 6, `fill`, 15/20 Medium; Kachel 20 × 20 Radius 6 | X-Angebote `.chip`, `.lg` |
| Ersparnis-Karte | weiß, Radius 20, Innenrand 12 14, Symbol `tag` 18 in `secondaryLabel`, Abstand 10, Zeile 1 15/20 Semibold `label`, Zeile 2 15/20 `secondaryLabel`; außen 16 Rand, 14 über der Karte | X-Einkaufsmodus |
| Angebotskarte im Artikel | `tintSoft`, Radius 26, Innenrand 14 16 4, 16 über der Karte; Kicker 11/13 Medium +0,4 in Großbuchstaben `tint`; Titel 17/22 Semibold `label`; Text 15/20 `tertiaryLabel`; Link 15/20 Semibold `tint`, 44 hoch | D2-Artikel |
| Zähler-Pille auf dem Cover | oben links 10/10, Innenrand 4 9 4 7, Radius voll, `ContentGlass` (weiß 92 %, Unschärfe 12), 11/13 Semibold `tint`, Symbol `tag` 11, Abstand 4 | D2-Home |
| Untere Hauptaktion (V-Screens) | `AppButton.primary` schwebend, volle Breite minus 2 × 16, 54 hoch, Radius 27, 17/22 Semibold, 28 über der Unterkante (plus sichere Zone) | X-Einkaufsmodus „Einkauf abschließen“ |
| Segmented Control | `AppSegmentedControl` 44 hoch, Spur `fill`, Innenrand 3, Daumen weiß 38 hoch Radius 19 mit Schatten, 15/20 (gewählt Semibold) | D2-Komponenten |
| Filter-Chip | `AppFilterChip` sichtbar 34, Trefferfläche 44, 15/20 Medium, Innenrand 14; gewählt `chipSelected` #1C1C1E mit weißer Schrift, sonst `fill` | D2-Komponenten |
| Suchfeld | `AvoSearchField`, mindestens 36 sichtbar in 44, wächst mit der Schrift | A |
| Kategorie-Symbol statt Produktfoto | 28 × 28 Radius 8 in Zeilen, 64 × 64 Radius 14 im Angebots-Kopf; Fläche `fill`, Kategorie-Symbol bzw. Illustration aus B4 (`ArticleImage` für eine Kategorie) | Konzept Regel 7, D2-Bildgrößen |
| Text-Knopf | 17/22 `tint`, destruktiv `destructive` #D70015, 44 hoch | D2-Komponenten „Buttons“ |

### 2.2 Farben im Bereich

| Rolle | Token (D2-Wert hell) | Einsatz | Hinweis |
|---|---|---|---|
| Angebot | `tint` #1F7A3A auf `tintSoft` #E7F3EA | Pille, Angebotskarte, großer Preis, Zähler-Pille | einzige Angebotsfarbe; das Gelb #FFD60A aus dem Konzept entfällt |
| Text | `label` #1C1C1E | Namen, Sätze, Werte in Bedienelementen | |
| Sekundär | `secondaryLabel` #6C6C70 | Unterzeilen, Fußnoten, Werte | nie auf `fill` außerhalb weißer Gruppen (4,09:1) |
| Text auf Angebotskarte | `tertiaryLabel` #3A3A3C (D2 #3C3C43) | „laut Händler statt …“ | 9,6:1 |
| Akzent | `tint` | Text-Knöpfe, Links, getönte Kapsel, Standort-Zeile | |
| Destruktiv | `destructive` #D70015 | „Region entfernen“, Fehlertexte unter Feldern | nie `red` #FF3B30 für Text |
| Vorschlag | `uncheckedRing` #8A8A8E | gestrichelter Rand am vorgeschlagenen Markt-Chip, 1 pt Kontur an hellen Markenkacheln | 3,44:1 auf Weiß |
| Warnung | `warning` (neu, Vorschlag #A8521A) | Symbol vor „Nicht festgelegt“ (Region) | Anfrage A-T1; iOS-Orange #FF9500 hat nur 2,2:1 |
| Markenfarben | aus `store_chain_directory.dart` (Daten, keine Tokens): Lidl #0050AA/#FFE500, REWE #CC071E/weiß, Edeka #FFD400/#1C1C1E, Aldi Süd #00005F, Aldi Nord #00549F, Kaufland #E10915, Netto #FFE500/#1C1C1E, PENNY #CD1414 | nur in der Buchstaben-Kachel | Buchstabe auf Kachel überall ≥ 4,9:1 (3.8); eigene Märkte ohne Markenfarbe |

Dunkel und „Kontrast erhöhen“ kommen aus den Token-Varianten von A (`AvoColors.dark`, `…HighContrast`); die
Angebots-Pille hat dort 6,4:1 bzw. 7,3:1. Markenfarben bleiben in allen Varianten gleich.

### 2.3 B-eigene Bausteine (Ordner `lib/presentation/screens/offers/widgets/`)

Aus A-Tokens und A-Komponenten gebaut, keine eigenen Farben, Größen oder Dauern:

- **`StoreMark`**: Buchstaben-Kachel des Markts (D2). Größen 18 (Liste, Zeilen), 20 (Chips in Einstellungen), 28
  (S2-Zeilen). Fläche Markenfarbe, Buchstabe in Markenkontrastfarbe aus dem Verzeichnis (`StoreInfo.shortLabel`,
  `brandColor`), Heavy, so groß, dass zwei Buchstaben („AS“) passen. Helle Markenfarben (relative Leuchtdichte über
  0,6: Edeka, Netto) bekommen eine 1-pt-Innenkontur in `uncheckedRing`. Eigener Markt: Fläche `fill`, erster Buchstabe
  in `label`. Wächst mit Dynamic Type bis AX2, dann nicht mehr. Für VoiceOver ausgeblendet, der Name daneben trägt die
  Information.
- **`StoreLabel`** (Konzept E-01): `StoreMark` 18 plus Name in der Schrift der umgebenden Zeile, ohne Kapsel und
  Chevron, nicht antippbar. VoiceOver „Markt Lidl“.
- **`OfferPriceTag`**: Angebots-Pille. Größe S (Werte 2.1) in drei Inhalten: nur Preis „0,99 €“; Preis mit Markt
  „0,99 € · Lidl“ (nur in Listen ohne Markt und in Zeilen, die Märkte mischen); unsicherer Treffer mit führendem
  `questionmark.circle` 11 pt in `tint`. Größe L (nur S5): 28/34 Bold `tint` auf `tintSoft`, Innenrand 6 16, Radius 22,
  mindestens 44 hoch. S wächst bis AX2 (Konzept 00 §6.4), L bis höchstens 51 pt Schrift. Die Pille selbst hat keine
  eigene Semantik; sie liefert ihren Satz an die Zeile (3.11).
- **`OfferRow`** (Konzept E-03): Zeile für ein Angebot in zwei Varianten. Kompakt (S6): Kategorie-Symbol 28, Titel
  17/22 bis 2 Zeilen, eine Unterzeile 15/20, rechts `OfferPriceTag` S; mindestens 52 hoch. Voll (S5 „Weitere
  Angebote“, S9, S10, S15): Titel, bis drei Unterzeilen (Zuordnung, Packung · Grundpreis · „laut Händler statt …“,
  Ablauf oder „Ähnliches Produkt“), rechts Pille, optional `plus.circle` 22 pt in einer 44-pt-Fläche; mindestens 60
  hoch. Ab AX1 stapelt die Zeile: Symbol entfällt, Pille unter dem Text, `plus.circle` rechts oben bündig zur ersten
  Zeile. Trenner 0,5 ab Textkante (56 mit Symbol, 16 ohne).
- **`OfferSummaryCard`**: Konfiguration von `HintRow` (A) für die Ersparnis-Zeile, mit zweizeiligem Text aus
  `OfferSummaryText` (Abschnitt 3.3). Variante „antippbar“ (Liste, mit Chevron) und „still“ (Einkaufsmodus).
- **Markt-Chips** (seit BAB1 ohne eigenen Baustein): A's `AppFilterChip(leading: StoreMark…, secondaryLabel: "400 m")`;
  Einfachauswahl (S10, erneutes Tippen hebt auf) als `SingleChoiceChipRow(allowDeselect: true)`, Mehrfachauswahl (S14)
  als einzelne `AppFilterChip`s (gewählt dunkel, ohne Häkchen: A's Chip hat keins).
- **`OffersSourceFootnote`**: die Quellen-Fußnote als ein Widget, damit der Pflicht-Wortlaut nie auseinanderläuft.
- **`UseLocationRow`**: Zeile „Standort verwenden“ mit `location`-Symbol und Titel in `tint`, Unterzeile je Zustand,
  rechts kleiner Aktivitätsanzeiger während der Ortung (am Auslöser, kein Vollbild-Spinner).
- **Postleitzahl-Zeile** (seit BAB1 ohne eigenen Baustein): A's `TextFieldRow` „Postleitzahl“ (Ziffernblock,
  `AutofillHints.postalCode`, `postcodeInputFormatters` aus `region_rows.dart`), Fehler als `errorText`, Ort als
  `hintText`, beide in der Zeile statt unter der Gruppe; ab AX1 Beschriftung über dem Feld.

---

## 3. Regeln für alle Screens

### 3.1 Wann eine Angebotsfläche existiert

Eine Angebotsfläche existiert nur, wenn **alle** Bedingungen stimmen; sonst rendert sie `SizedBox.shrink()` ohne
reservierten Platz, ohne Hinweis „nicht verfügbar“ und ohne Lücke:

1. `offersAvailableProvider` ist wahr (Modul an **und** Kill-Switch an).
2. Es gibt eine echte Region (Standort-PLZ oder eingegebene PLZ, `regionProvider` nicht `null`). Ohne Region gehen
   keine Anfragen raus; einige Flächen zeigen stattdessen den Hinweis „Postleitzahl festlegen“ (3.4).
3. Die Liste ist nicht über „Angebote für diese Liste ausblenden“ ausgenommen (`offersVisibleForListProvider(listId)`).
4. Der Einzel-Schalter der Fläche ist an (S12).
5. Es gibt Daten, und sie sind beim ersten Frame bekannt (3.2).

| Fläche | Einzel-Schalter in S12 |
|---|---|
| S3 Pille, S4 Angebotskarte, S8 Zähler, S9 Zeilen, S15 Rezept-Zeile | „Angebote an Artikeln“ |
| S6 Angebote beim Tippen | „Vorschläge beim Tippen“ |
| S7 Ersparnis-Zeile | „Ersparnis in der Liste“ |
| S9 Sektion „oft gekauft“, S10 Segment „Oft gekauft“, Hinweis „3 Sachen, die du oft kaufst …“ | „Spar-Hinweise auf der Startseite“ |
| Ersparnis beim Abschluss und im Verlauf (andere Spec) | „Ersparnis im Verlauf und nach dem Einkauf“ |

Der Markt-Chip (S1), Markt wählen (S2), Lieblingsmärkte (S13) und die Region als Standort gehören zum Kern und folgen
keiner dieser Bedingungen. Ein einziger Provider prüft alles (`offerSurfaceVisibleProvider(surface, listId)`, Lücke L3),
damit kein Slot eine Bedingung vergisst.

### 3.2 Lokal zuerst, nichts springt

- Pillen, Ersparnis-Zeile, Zähler und Rezept-Zeile erscheinen nur, wenn das Angebot beim ersten Frame aus dem Cache
  bekannt ist (Cache pro Liste, höchstens 6 h alt, nur der Markt der Liste). Neu gefundene Angebote erscheinen beim
  nächsten Öffnen der Liste oder nach Rückkehr in den Vordergrund, nie während man liest (K12-02). Ist in der Zeile
  schon Platz, blendet eine Pille dort ein (`AvoMotion.fadeReduced`), ohne die Zeilenhöhe zu ändern.
- Abgelaufene Angebote verschwinden beim nächsten Öffnen. Abhaken und Hinzufügen zählen lokal neu, ohne Netzanfrage;
  Zahlen rollen an Ort und Stelle (`RollingNumber`), die Höhe bleibt.
- Skelett (`SkeletonSection`, ruhig, ohne Schimmer, VoiceOver ein Element „Wird geladen“) nur beim allerersten Öffnen
  von S10, S9 und S15 ohne lokalen Stand, Sektion für Sektion ersetzt; Teilergebnisse erscheinen sofort. Nie ein
  Spinner. Nach 12 s ohne Antwort (Angebots-Timeout, Kap. 20 §2.5) der Fehler-Zustand der Sektion.
- Spätere Öffnungen: sofort aus dem Cache, Abgleich im Hintergrund; neue Zeilen nur unterhalb der Leseposition.
- Schreiben (Preis übernehmen, Artikel hinzufügen, Markt setzen, Region, Schalter) ist optimistisch und geht durch die
  Warteschlange von A; offline trägt der Artikel das Sync-Zeichen.

### 3.3 Wortlaut, Zahlen und Recht (verbindlich)

- **Ersparnis-Satz**, immer in dieser Form und nur aus `offer_savings.dart` (`summarizeListOffers`,
  `formatOfferSummary`): „4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region“.
  Für die zweizeilige D2-Darstellung (S7) liefert dieselbe Funktion drei Teile (`OfferSummaryText`): `head` „4 von 11
  Artikeln diese Woche bei Lidl im Angebot“, `detail` „ca. 3,20 € gespart · in deiner Region · Preise laut Händler“ und
  `sentence` (der Satz oben, für VoiceOver und S9). Es gibt keinen zweiten Ort, der den Satz zusammensetzt.
- **Ersparnis-Rechnung** (Regel 5): (Vergleichs-Grundpreis des Händlers − Angebots-Grundpreis) × Listenmenge in
  Grundeinheit, bei nicht vergleichbarer Einheit Packungsdifferenz × Anzahl. Artikel ohne „statt“-Preis zählen bei
  „4 von 11“ mit und tragen 0 € bei. Auf 10 ct gerundet mit „ca.“; **unter 0,50 € entfällt der Spar-Teil** („4 von 11
  Artikeln diese Woche bei Lidl im Angebot, in deiner Region“). Ohne echte Region gibt es keine Ersparnis.
- **„von 11“** zählt die offenen Artikel der Liste. Im Einkaufsmodus zählen die beim Start offenen plus die seitdem
  abgehakten (sonst schrumpft der Satz mit jedem Häkchen; Owner-Frage 4).
- **Vergleichspreise** nur als „laut Händler statt 1,19 €“ und nur, wenn der Händler einen „statt“-Preis nennt. Eine
  UVP ist kein „statt“-Preis (Owner-Frage 9). Keine eigene Prozentrechnung, kein „−23 %“, kein „Spare …“, keine
  Korbsumme, kein Marktvergleich, kein „günstigster“, keine Sortierung nach Preis oder Rabatt über Märkte hinweg.
- **„in deiner Region“**, nie „in deinem Markt“ oder „in der Nähe“ (die Quelle filtert nach PLZ). „In der Nähe“ steht
  nur dort, wo es um echte Entfernungen zu Märkten geht (S2, S14).
- **Keine Händler- oder Prospektbilder.** Angebote zeigen das Kategorie-Symbol. Supermarkt-Logos nur mit Erlaubnis;
  die D2-Buchstaben-Kachel ist kein Logo (Owner-Frage 1).
- **Quellen-Fußnote** an jeder Fläche mit Preisdetail (S5, S9, S10, S12, S15), Wortlaut unten. `{source}` ist bis zur
  Lizenzklärung „Händlerprospekte“ (Owner-Frage 5).
- **Zahlen**: `NumberFormat.currency` nach Gerätesprache: „0,99 €“ / „€0.99“, „3,20 €“ / „€3.20“; Grundpreis „0,99 €/l“
  / „€0.99/L“, „5,96 €/kg“ / „€5.96/kg“; Packung „1 l“ / „1 L“, „250 g“, „6 × 1,5 l“ / „6 × 1.5 L“. Immer
  tabellarische Ziffern.
- **Datum**: „bis Sa., 14. Nov.“ / „until Sat, Nov 14“. Ablauf nur bei höchstens 3 Kalendertagen in lokaler Zeit:
  „endet heute“, „endet morgen“, „endet Montag“ / „ends today“, „ends tomorrow“, „ends Monday“. Keine Warnfarbe.
- **Plural** in ICU-Schreibweise. Solange `context.tr` das nicht kann, wird daraus je ein Schlüssel `…_one` und
  `…_other` (wie in `kalorien.md` 3.3).
- **Markenname** der App nur über `AppBrand` (`{app}` = Avo).

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_summary_head` | {matched} von {total, plural, =1{1 Artikel} other{# Artikeln}} diese Woche bei {store} im Angebot | {matched} of {total, plural, =1{1 item} other{# items}} on offer at {store} this week |
| `offer_summary_saved` | ca. {amount} gespart | about {amount} saved |
| `offer_in_your_area` | in deiner Region | in your area |
| `offer_retailer_prices` | Preise laut Händler | prices as stated by the retailer |
| `offer_summary_sentence` | {head}, ca. {amount} gespart, in deiner Region | {head}, about {amount} saved, in your area |
| `offer_summary_sentence_no_savings` | {head}, in deiner Region | {head}, in your area |
| `offer_was_price` | laut Händler statt {price} | was {price}, as stated by the retailer |
| `offer_valid_until` | bis {date} | until {date} |
| `offer_ends_today` (Bestand, neu getextet) | endet heute | ends today |
| `offer_ends_tomorrow` | endet morgen | ends tomorrow |
| `offer_ends_weekday` | endet {weekday} | ends {weekday} |
| `offer_similar_product` | Ähnliches Produkt | Similar product |
| `offer_source_footnote` | Angebote gelten für deine Region, nicht für einen bestimmten Markt. Preise sind Angaben des Händlers; Normalpreise kennt die App nicht. Quelle: {source}. | Offers apply to your area, not to a specific store. Prices are as stated by the retailer; the app doesn't know regular prices. Source: {source}. |
| `offer_source_placeholder` | Händlerprospekte | retailer flyers |
| `offer_savings_explainer` | „Gespart“ ist der Unterschied zu den „statt“-Preisen der Händler, gerechnet über den Grundpreis und deine Mengen. Der Wert ist ungefähr. | “Saved” is the difference to the retailers' “was” prices, worked out per unit and for your quantities. It's an approximate value. |

### 3.4 Zustände, die überall gleich aussehen

| Zustand | Darstellung | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Offline mit Cache | `StatusRow(kind: offline)` unter dem Titel, erscheint nach 1 s | `offer_status_offline_as_of` | Offline. Angebote vom Stand {datetime}. | You're offline. Offers as of {datetime}. |
| Offline bei Suche | `StatusRow` über den Treffern | `offer_status_offline_search` | Offline. Es werden nur gespeicherte Angebote gezeigt. | You're offline. Showing saved offers only. |
| Aktualisieren gescheitert, Inhalt bleibt | `StatusRow(kind: sectionError)` mit Aktion `common_try_again` | `offer_status_refresh_failed` | Angebote konnten gerade nicht aktualisiert werden. | Offers couldn't be updated just now. |
| Laden gescheitert, kein Cache | `StatusRow(kind: sectionError)` in der betroffenen Sektion, mit Aktion | `offer_status_load_failed` | Angebote konnten gerade nicht geladen werden. | Offers couldn't be loaded just now. |
| Ohne echte Region (Hinweis) | `HintRow` mit `location`-Symbol in `secondaryLabel`, Aktion | `offer_hint_set_postcode`, `offer_hint_set_postcode_action` | Für Angebote in deiner Region: Postleitzahl festlegen · Festlegen | To see offers in your area, set your postcode · Set postcode |
| Liste ohne Markt (Hinweis), höchstens 1 × pro Woche | `HintRow` mit `storefront`-Symbol, Aktion öffnet das Menü aus S1 | `offer_hint_no_store`, `offer_hint_no_store_action` | Für welchen Markt ist {list}? Dann siehst du dessen Angebote. · Markt wählen | Which store is {list} for? Then you'll see its offers. · Choose store |
| Braucht Verbindung | Text an der Aktion (A) | `common_needs_connection` | Braucht eine Verbindung | Needs a connection |
| Zeile nicht gespeichert | Zeile mit `exclamationmark.circle` in `destructive`, Tippen wiederholt, Fehler-Haptik | `common_not_saved` | Nicht gespeichert | Not saved |
| Modul aus | Flächen verschwinden; Routen zeigen S16 | | | |
| Kill-Switch | Flächen verschwinden; Routen zeigen die Fehlerseite; S12 heißt „Märkte“ | | | |
| Pro gesperrt | **gibt es nicht.** Angebote sind nie Pro: kein `ProBadge`, keine Paywall, kein Pro-Hinweis an einer Angebotsfläche | | | |
| Standort abgelehnt | `StatusRow(kind: permission)` am Ort (S11, S14, S10 Leerzustand); Funktion startet nach Rückkehr nicht von selbst | je Screen | | |

Der Hinweis „Postleitzahl festlegen“ lässt sich wegwischen (`HintRow.onDismiss`, „Ausblenden“) und kommt dann 7 Tage
nicht wieder; der Zustand liegt im Konto (Regel 15, Lücke L6).

### 3.5 Bewegung (Federn aus `AvoMotion`)

| Was | Feder | Reduce Motion |
|---|---|---|
| Menüs wachsen aus ihrem Auslöser (Markt-Chip, `plus.circle`, Kontextmenüs) | `AvoMotion.menu` (Menü von A) | Überblendung |
| Chip-Text wechselt nach Marktwahl, Gänge sortieren sich um | Text: Überblendung; Gänge: `AvoMotion.move` | Überblendung |
| Ziffern („4 von 11“, „ca. 3,20 €“, Zähler) | `RollingNumber` mit `AvoMotion.digits` | Überblendung der ganzen Zahl |
| Zeile kommt hinzu (Stammartikel auf die Liste, Markt zu Lieblingsmärkten) | `AvoMotion.move` vom aktuellen Ort aus | Überblendung |
| Sektion klappt zusammen (Modul aus in S12, ausgeblendete Liste) | `AvoMotion.standard` | sofort, Überblendung |
| Segment und Chips | `AvoMotion.quick`, Inhalt per Überblendung | Überblendung |
| Umsortieren (S13) | Zeile folgt dem Finger 1:1, Nachbarn mit `AvoMotion.standard`, Loslassen mit Geschwindigkeit an `AvoMotion.move` | nur über Aktionen „Nach oben“/„Nach unten“, Überblendung |
| Wischen auf Zeilen (S7, S10) | 1:1 mit dem Finger, Gummiband, Entscheidung nach Richtung der Geschwindigkeit | Aktion über Kontextmenü |

Keine Endlos-Animation, kein Schimmer, kein Pulsieren.

### 3.6 Haptik (über `AvoHaptics`, nie `HapticFeedback` im Screen)

| Ereignis | Haptik |
|---|---|
| Preis übernehmen, Angebot anhängen, Artikel aus einem Angebot hinzufügen, Markt wählen, Region speichern, ausblenden, Schalter | keine (umkehrbar und sichtbar) |
| Wisch-Aktion überschreitet die Auslöse-Schwelle | `light` |
| Segment per Wischen gewechselt, Zeile rastet beim Umsortieren ein | `selection` |
| Speichern endgültig gescheitert (Preis, Markt, Region) | `error`, im Frame, in dem der Rückgängig-Hinweis zur Fehlermeldung wird |
| Öffnen von Screens, Menüs, Feldern | keine |

Kein Erfolg-Haptik in diesem Bereich (Geld ist kein Erfolgsmoment, E-14).

### 3.7 Rückgängig-Hinweis (`AvoToast` mit `AvoToastHost` von A)

- Glas-Kapsel über der Tab-Leiste bzw. über der unteren Hauptaktion, ein Satz plus Text-Knopf `common_undo`
  „Widerrufen“ / „Undo“. Sichtbar 4 s, mit VoiceOver 10 s, Ansage beim Erscheinen; die Zeit läuft nicht, solange der
  VoiceOver-Fokus auf dem Hinweis liegt. „Widerrufen“ ist zusätzlich als Aktion am geänderten Element erreichbar,
  solange der Hinweis steht.
- Rückgängig statt Rückfrage überall in diesem Bereich. Es gibt hier keinen Bestätigungsdialog außer „Änderungen
  verwerfen?“ (S16).
- Alle Hinweise des Bereichs:

| Auslöser | Schlüssel | Deutsch | English |
|---|---|---|---|
| Markt gewählt | `offer_toast_store_set` | Markt: {store} | Store: {store} |
| Kein fester Markt | `offer_toast_store_none` | Kein fester Markt | No fixed store |
| Preis übernommen | `offer_toast_price_taken` | Preis für {item} übernommen | Price added to {item} |
| Preis entfernt | `offer_toast_price_removed` | Preis für {item} entfernt | Price removed from {item} |
| Preis nicht gespeichert (Aktion `common_try_again`) | `offer_toast_price_failed` | Preis nicht gespeichert | Price not saved |
| Angebot an vorhandenen Artikel gehängt | `offer_toast_attached` | Angebot an {item} angehängt | Offer added to {item} |
| … auf einer anderen Liste | `offer_toast_attached_list` | Angebot an {item} auf {list} angehängt | Offer added to {item} on {list} |
| Artikel auf eine Liste gesetzt | `offer_toast_added_list` | {item} auf {list} | {item} added to {list} |
| … wo das Angebot nicht gilt | `offer_toast_added_no_offer` | {item} auf {list} · Angebot gilt nur bei {store} | {item} added to {list} · offer only at {store} |
| Hinzufügen gescheitert (Aktion `common_try_again`) | `offer_toast_add_failed` | Nicht hinzugefügt | Not added |
| Angebot für einen Artikel ausgeblendet | `offer_toast_offer_hidden` | Angebot für {item} ausgeblendet | Offer hidden for {item} |
| Angebote für eine Liste ausgeblendet | `offer_toast_list_hidden` | Angebote für {list} ausgeblendet | Offers hidden for {list} |
| Ersparnis-Zeile diese Woche ausgeblendet | `offer_toast_summary_week` | Ersparnis-Zeile für diese Woche ausgeblendet | Savings line hidden for this week |
| Ersparnis-Zeile ausgeschaltet | `offer_toast_summary_off` | Ersparnis-Zeile ausgeschaltet | Savings line turned off |
| „Nicht interessiert“ | `offer_toast_not_interested` | Ausgeblendet bis {date} | Hidden until {date} |
| Region gespeichert | `offer_toast_region_set` | Region: {postcode} {city} | Area: {postcode} {city} |
| Region entfernt | `offer_toast_region_removed` | Region entfernt | Area removed |
| Lieblingsmarkt entfernt | `offer_toast_favorite_removed` | {store} entfernt | {store} removed |

### 3.8 Kontrast (WCAG 2.1 AA, berechnet aus den D2-Werten)

| Element | Vorne | Hinten | Wert | Nötig | Ergebnis und Lösung |
|---|---|---|---|---|---|
| Angebots-Pille (11 pt Semibold) | #1F7A3A | #E7F3EA | 4,72:1 | 4,5:1 | knapp gut; Pille nie auf `fill` oder Glas legen. Dunkel 6,39:1, Kontrast erhöht 7,30:1 |
| Großer Preis S5 (28 pt Bold) | #1F7A3A | #E7F3EA | 4,72:1 | 3:1 | gut |
| Zähler-Pille auf dem Cover | #1F7A3A | weiß 92 % über schwarzem Foto (#EBEBEB) | 4,50:1 | 4,5:1 | gerade gut im schlechtesten Fall; Deckkraft nie unter 92 % (A's `ContentGlass` hat 78 %: 3,18:1, Anfrage A-T2) |
| Destruktiver Text | #FF3B30 | #FFFFFF | 3,55:1 | 4,5:1 | nicht für Text; `destructive` #D70015 (5,38:1, auf #F2F2F7 4,83:1) |
| Weiße Schrift auf getönter Kapsel 88 % über Weiß | #FFFFFF | #3A8A52 | 4,25:1 | 4,5:1 | Kapsel mit Text auf hellem Grund 96 % (#287F42, 4,99:1), wie D2-FuerDich „Angebote ansehen“; Anfrage A-T3 |
| Schalter an (D2) | #34C759 | #FFFFFF | 2,22:1 | 3:1 | A nutzt schon `tintFill` #1F7A3A (5,38:1); D2-Grün nicht übernehmen |
| Warn-Symbol „Nicht festgelegt“ | #FF9500 | #FFFFFF | 2,20:1 | 3:1 | Token `warning` #A8521A (5,40:1), Symbol plus Text |
| Gestrichelter Rand „Lidl?“ | #8A8A8E | weißer Chip | 3,44:1 | 3:1 | gut; zusätzlich „?“ im Text und „Vorschlag“ in VoiceOver (Farbe nie allein) |
| Sekundärtext auf `fill` außerhalb weißer Gruppen | #6C6C70 | #E3E3E9 | 4,09:1 | 4,5:1 | Entfernung im Chip „· 400 m“ nur in Chips innerhalb weißer Gruppen (4,55:1); in Bedienelementen sonst `label` |
| Sekundär | #6C6C70 | #FFFFFF / #F2F2F7 / #E7F3EA | 5,23 / 4,69 / 4,58:1 | 4,5:1 | gut |
| Text auf Angebotskarte | #3A3A3C | #E7F3EA | 9,6:1 | 4,5:1 | gut |
| Akzent-Text, Links | #1F7A3A | #FFFFFF / #F2F2F7 | 5,38 / 4,82:1 | 4,5:1 | gut |
| Buchstabe auf Markenkachel | Lidl #FFE500 auf #0050AA; REWE weiß auf #CC071E; Kaufland weiß auf #E10915; Edeka #1C1C1E auf #FFD400 | | 6,03 / 5,81 / 4,94 / 11,89:1 | 4,5:1 | gut für alle acht Ketten |
| Helle Kachel gegen Weiß | #FFD400 / #FFE500 | #FFFFFF | 1,43 / 1,28:1 | (dekorativ) | 1-pt-Innenkontur `uncheckedRing`; die Kachel ist dekorativ, der Name trägt die Information |
| Angebots-Pille gegen Zeile | #E7F3EA | #FFFFFF | 1,14:1 | (keine) | die Pille trägt Text; nichts hängt an ihrer Fläche |

Fetter Text (iOS „Fetter Text“) und erhöhter Kontrast laufen in der Prüfmatrix mit; mit erhöhtem Kontrast bekommt
Glas eine Kontur (A), der Markt-Chip eine 1-pt-Kontur in `separator`-Variante von A.

### 3.9 Trefferflächen (mindestens 44 × 44 pt)

| D2-Element | sichtbar | Lösung |
|---|---|---|
| Markt-Chip in der Liste | 30 hoch | Trefferfläche 44 hoch (7 pt über und unter dem Chip), Breite = Chip, mindestens 44 |
| Markt-Chip in den Einstellungen | 32 hoch | 44 hoch, Abstand zwischen Chips 8 (Trefferflächen dürfen sich nicht überlappen) |
| Filter-Chip | 34 | 44 (A) |
| Angebots-Pille, wenn antippbar (normale Liste) | ca. 19 hoch, ab 40 breit | 44 × max(44, Pillenbreite + 8) am rechten Zeilenende; außerhalb öffnet die Zeile den Artikel |
| Angebots-Pille im Einkaufsmodus | | nicht separat antippbar (Fehltipps im Gehen); Zeile hakt ab (A, Ziel dort 56) |
| `plus.circle` in Zeilen | 22 | 44 × 44 am rechten Rand, Zeilenhöhe mindestens 60 |
| Schließen in `HintRow` | 12 | 44 (A) |
| Zieh-Griff S13 | 22 | 44 × 44 |
| Link „Angebot ansehen“ in S4 | 20 hoch | 44 (D2 `min-height: 44px`) |
| Metazeile „In deiner Region · 79098 Freiburg“ (S10) | 20 hoch | Text-Knopf 44 hoch |
| „Einblenden“ (S12) | Text | 44 |

### 3.10 Große Schrift und 320 pt

- Prüfmatrix (`layoutMatrix` von A): Breiten 320 × 568, 320 × 693, 375 × 667, 390 × 844, 402 × 874, 440 × 956;
  Textgrößen L, xxxL, AX3, AX5; fett an/aus; hell/dunkel. Dazu einmal bei 390/L: erhöhter Kontrast, Reduce Motion,
  Transparenz reduzieren. Kein abgeschnittener Text, keine Ausnahme, keine Ellipse außer im Inline-Titel.
- **320 pt bei L**: Markt-Chip und „11 offen · mit Lena“ brechen in zwei Zeilen; Pille bleibt rechts, solange der
  Artikelname mindestens 120 pt behält, sonst darunter; Ersparnis-Karte bis 3 Zeilen; Segment „Deine Listen | Oft
  gekauft“ passt in eine Zeile.
- **Ab xxL**: Chip-Reihen werden ein Umbruch (`ChipRow` ab xxxL von A, Markt-Chips in S12 immer `Wrap`); Segmente, die
  nicht passen, werden das Pull-down von `AppSegmentedControl`.
- **Ab AX1**: Gruppen randlos (A), Zeilen stapeln (Wert unter Titel, Pille unter dem Namen neben der Menge),
  Kategorie-Symbole in Zeilen und im Angebots-Kopf entfallen (Bilder sind ab AX1 aus, Kap. 20), `StoreMark` bleibt
  neben dem Namen und wächst bis AX2; die Avo-Figur entfällt; der Markt-Chip steht in einer eigenen Zeile;
  Feld-Beschriftungen stehen über dem Feld; zwei Knöpfe nebeneinander stehen untereinander.
- **Deckel**: Pille und `StoreMark` wachsen bis AX2; großer Preis in S5 höchstens 51 pt; Hinweis-Zeilen kürzen nie.

### 3.11 VoiceOver-Grundregeln

- **Zeilen sind ein Element** mit vollem Satz. Die Pille liefert ihren Teil an die Artikelzeile von A (A verbindet die
  Semantik der Zeile, Anfrage A-C1): „Avocados, 3 Stück, im Angebot 0,99 Euro laut Händler“. Eigene Aktion „Angebot
  ansehen“. In Listen ohne Markt: „im Angebot bei Lidl, 0,99 Euro laut Händler“.
- **Aussprache**: Beträge „0,99 Euro“ / “99 cents”, Grundpreis „0,99 Euro pro Liter“ / “99 cents per litre”, „1 l“
  „1 Liter“, „ca.“ „circa“ / “about”, „Sa., 14. Nov.“ „Samstag, 14. November“. Die Labels werden dafür ausgeschrieben,
  nicht dem Vorlesen überlassen.
- **Überschriften**: Großer Titel und jeder `SectionCaps`-Kopf sind Überschriften (Rotor „Überschriften“) und werden in
  normaler Schreibung vorgelesen. Die Anzahl rechts im Kopf gehört zum Kopf: „Auf deiner Liste, 4“.
- **Wisch- und Kontextmenü-Aktionen** sind eigene Aktionen (`customSemanticsActions`). Menüs sind Schaltflächen mit
  „Menü“ und öffnen mit Doppeltipp.
- **Dekoratives** ist ausgeblendet: `StoreMark`, Kategorie-Symbole, Trenner, die Pille als Fläche.
- **Ansagen** (`SemanticsService.announce`, einmal, nach dem vollständigen Satz): Artikel aus einem Angebot
  hinzugefügt, Angebot angehängt, Region gespeichert, Standort gefunden. Die `StatusRow` sagt sich selbst einmal an (A).
- **Fokus-Reihenfolge** folgt der Leserichtung: Toolbar links, Titel, Toolbar rechts, Inhalt von oben nach unten,
  untere Hauptaktion zuletzt. Nach dem Öffnen liegt der Fokus auf dem Titel; nach dem Schließen eines V-Screens auf dem
  Element, das ihn geöffnet hat (Pille, Chip, Zeile).
- **Live-Werte**: Ändert sich „4 von 11“ durch Abhaken, wird es nicht angesagt (sonst redet die Liste bei jedem
  Häkchen); der neue Wert steht beim nächsten Fokus im Label.

### 3.12 Reduce Motion, Transparenz reduzieren, fetter Text

- Reduce Motion: siehe 3.5. Keine Bewegung, nur Überblendungen.
- Transparenz reduzieren (nativer Kanal `shoply/accessibility`, A nutzt ihn in `GlassSurface`/`ContentGlass`): Glas wird
  eine feste Fläche mit Kontur, getöntes Glas festes `tintFill`, die Scroll-Kante eine feste Fläche, die Zähler-Pille auf
  dem Cover festes Weiß mit Kontur. Die Angebots-Pille ist ohnehin deckend.
- Fetter Text (`MediaQuery.boldTextOf`): Pille und Chips werden breiter; nichts darf deshalb abschneiden (Prüfmatrix).

### 3.13 Avo-Figur

Höchstens eine Figur pro Bildschirmhöhe, immer `AvoFigure` mit der echten 3D-Figur aus `assets/avo/`. In diesem Bereich
geht es fast immer um Geld, Preise oder Fehler; dort gibt es keine Figur (Konzept Regel 12).

| Ort | Pose | Größe | Ab |
|---|---|---|---|
| S10 Suche ohne Treffer | `AvoPose.thinking` (Avo sucht mit) | 96 pt (`EmptyState(pose:)`) | ab AX1 weg (A's `EmptyState` macht das) |
| alle anderen Screens, Slots und Zustände | keine | | |

Im Onboarding (S14) zeigt der Rahmen von A höchstens eine Figur; der B-Inhalt bringt keine mit. Leere Zustände nutzen
Symbole (`tag`, `location`) in 48 pt Light statt der Figur.

### 3.14 Glas pro Screen

Höchstens drei Glas-Flächen gleichzeitig: Toolbar oben, Tab-Leiste oder untere Hauptaktion, Rückgängig-Hinweis. Genau
eine getönte Kapsel pro Screen (die Hauptaktion). In Listen-Inhalten kein echtes Glas (nur `ContentGlass` auf Fotos).

### 3.15 Netz und Datenschutz

- Ohne echte Region keine einzige Anfrage an die Angebotsquelle (Test: Mock-Client bekommt keinen Aufruf).
- Suche ab 2 Zeichen nach 300 ms Pause; Abgleich pro Liste höchstens alle 6 h, nur für den Markt der Liste; nie
  Kataloge oder viele PLZ vorladen; Caches höchstens 200 Einträge (LRU); Angebots-Timeout 12 s.
- Standort nur nach Tipp auf „Standort verwenden“; nie beim Start, nie ohne Erklärung; frische Koordinaten mit 3 s
  Zeitlimit; Marktsuche in der Nähe (Overpass) nur in S2 und S14, Radius 250 m für „Du bist bei …“, sonst wie heute
  begrenzt.
- Suchbegriffe und PLZ gehen an die Angebotsquelle, Koordinaten an Overpass/OSM; das steht in der Datenschutzerklärung
  (OPEN-ISSUES, Owner).

---

## 4. Screens und Slots

Jeder Eintrag: Zweck, Ort und Route, Aufbau von oben nach unten, Zustände mit Texten, Interaktion, Barrierefreiheit,
Daten, Avo-Figur. Was in Abschnitt 3 steht, gilt zusätzlich und wird nicht wiederholt.

---

### S1 Markt-Chip `StoreChip` mit Menü „Markt“ (Kern)

**Zweck.** Für welchen Markt ist diese Liste? Der Markt steuert Reihenfolge im Markt, Titel im Einkaufsmodus, Verlauf
und, mit Modul, die Angebote. Der Chip ist Kern und bleibt bei Modul aus und Kill-Switch unverändert.

**Ort.** Slot `StoreChip({required String listId})` aus `b_slots.dart`. A setzt ihn in die Metazeile unter dem großen
Titel der Liste (D2 `X-Einkaufsmodus`: Chip, daneben „5 von 11 erledigt“) und in den Kopf des Einkaufsmodus.
`D2-Liste` zeigt noch keinen Chip; A ergänzt ihn dort (Anfrage A-L1). In der Listen-Info baut A eine Zeile „Markt“ mit
Wert aus `storeForListProvider`; Tippen öffnet S2 direkt.

**Aufbau (D2 `X-Einkaufsmodus`).** Weiße Kapsel 30 hoch mit leichtem Schatten: `StoreMark` 18, Name 15/20 Semibold,
`chevronDown` 12. Trefferfläche 44 hoch.

**Zustände.**

| Zustand | Anzeige |
|---|---|
| Markt gesetzt (`user`) oder aus dem Listennamen erkannt (`name`) | `StoreMark` + „Lidl“ + Chevron |
| Einmal nach Erkennung aus dem Namen | darunter eine Zeile 13/18 `secondaryLabel` „Markt aus dem Namen erkannt. Tippen zum Ändern.“; verschwindet nach dem nächsten Tipp auf den Chip oder nach dem dritten Öffnen der Liste |
| Vorschlag (`learned`: zweimal derselbe Markt beim Abschluss; `location`: Liste im Umkreis von 80 m eines eindeutig erkannten Markts geöffnet, nur mit Standort-Erlaubnis) | „Lidl?“ mit 1-pt-Strichrand `uncheckedRing`; Tippen öffnet das Rückfrage-Menü |
| Kein Markt | Symbol `storefront` 16 in `secondaryLabel` + „Markt wählen“ in `secondaryLabel` + Chevron |
| „Markt automatisch erkennen“ aus (S12) | keine Vorschläge, keine Erkennung aus dem Namen; nur gesetzter Markt oder „Markt wählen“ |
| Modul aus, Kill-Switch, offline | unverändert (Ketten-Verzeichnis liegt lokal) |
| Speichern gescheitert | Chip springt auf den alten Markt zurück, Rückgängig-Hinweis wird `offer_toast_store_failed` mit `common_try_again`, `error`-Haptik |

**Menü „Markt“** (Pull-down von A, wächst aus dem Chip, `AvoMotion.menu`, Zeilen mindestens 44):

1. Lieblingsmärkte in ihrer Reihenfolge (`StoreMark` + Name), der aktuelle mit Häkchen.
2. Märkte aus dem Verlauf dieser Liste, die keine Lieblingsmärkte sind (höchstens 3).
3. Ohne beides: die häufigsten Ketten des Verzeichnisses (Lidl, Aldi Süd bzw. Aldi Nord nach PLZ, REWE, Edeka,
   Kaufland, Netto).
4. Trenner, „Anderer Markt …“ (`storefront`, öffnet S2), „Kein fester Markt“.

Auswahl wirkt sofort: Chip-Text blendet über, A sortiert die Gänge um, die Angebote der neuen Kette werden einmal für
diese Liste abgeglichen (eine Nutzer-Aktion, kein Hintergrund-Abgleich), Rückgängig-Hinweis `offer_toast_store_set`.
Keine Haptik.

**Rückfrage-Menü** (gleiches Menü, wenn der Chip ein Vorschlag ist): Titelzeile „Ist das deine Lidl-Liste?“ (13/18
`secondaryLabel`, kein Knopf), „Ja, Lidl“ (Häkchen; setzt `source = user`, Strichrand verschwindet mit
`AvoMotion.quick`), „Anderer Markt …“, „Nicht fragen“ (dauerhaft für diese Liste und diesen Markt; ein anderer Markt
darf später vorgeschlagen werden; Chip wird „Markt wählen“).

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_store_choose` | Markt wählen | Choose store |
| `offer_store_from_name_tip` | Markt aus dem Namen erkannt. Tippen zum Ändern. | Store recognised from the list name. Tap to change. |
| `offer_store_other` | Anderer Markt … | Other store… |
| `offer_store_none` | Kein fester Markt | No fixed store |
| `offer_store_confirm_title` | Ist das deine {store}-Liste? | Is this your {store} list? |
| `offer_store_confirm_yes` | Ja, {store} | Yes, {store} |
| `offer_store_dont_ask` | Nicht fragen | Don't ask again |
| `offer_toast_store_failed` | Markt nicht gespeichert | Store not saved |
| `offer_store_chip_a11y` | Markt: {store}, ändern | Store: {store}, change |
| `offer_store_chip_suggested_a11y` | Vorschlag: {store}. Bestätigen oder ändern | Suggested store: {store}. Confirm or change |

**Barrierefreiheit.** Schaltfläche mit Merkmal „Menü“; Label wie oben, bei keinem Markt „Markt wählen“. Menüzeilen
„Lidl, ausgewählt“. Fokus nach dem Schließen des Menüs zurück auf dem Chip. AX: ab AX1 eigene Zeile unter dem Titel,
`StoreMark` bis AX2; 320/L: Chip und „11 offen · mit Lena“ in zwei Zeilen.

**Daten.** `storeForListProvider(listId)` (nur bestätigt), `storeGuessForListProvider(listId)` (Vorschlag mit Quelle),
`listStoreRepositoryProvider` (schreibt `list_store_assignments_b`, Quelle `user`), `store_chain_directory.dart`,
Lieblingsmärkte und Erkennungs-Schalter (`offerPrefsProvider`, Lücke L4), Märkte aus dem Verlauf der Liste (Lücke L7).
Datei `lib/presentation/screens/lists/widgets/store_chip.dart`.

**Avo.** Keine Figur.

---

### S2 Markt wählen `/stores/pick` (Vollbild, Kern)

**Zweck.** Welcher Markt ist es, wenn er nicht im Menü steht? Ersetzt `checkout_store_sheet.dart` (Kacheln, feste
280 pt, Freitext) und das Konzept-Sheet „Markt“.

**Route.** V aus „Anderer Markt …“ (S1), aus „Neue Liste“ und Listen-Info (A), aus „Einkauf abschließen“ (andere
Spec, `from=checkout`). Gibt `StoreChoice?` zurück; mit `list=` speichert S2 selbst und der Aufrufer zeigt den
Rückgängig-Hinweis.

**Aufbau.**

1. `GlassToolbar`: links `GlassIconButton` `xmark` „Schließen“, Inline-Titel „Markt“, rechts nichts (Tippen wählt).
2. `AvoSearchField` „Markt suchen“, 16 vom Rand.
3. `SectionCaps` „Deine Märkte“ + `InsetSection`: Lieblingsmärkte und schon genutzte Märkte; Zeile 52: `StoreMark` 28,
   Name 17/22; der aktuelle Markt mit Häkchen 17 pt in `tint` am Zeilenanfang. Fehlt die Sektion, steht nichts da.
4. `SectionCaps` „In der Nähe“ + Gruppe (nur mit Standort-Erlaubnis und frischer Position, höchstens 5, bis 2 km):
   Zeile 60: `StoreMark` 28, Name, Unterzeile „Kaiser-Joseph-Straße · 120 m“. Blendet ein, sobald die Abfrage fertig
   ist, und schiebt nur „Alle Märkte“ nach unten (unterhalb der Leseposition).
5. `SectionCaps` „Alle Märkte“ + Gruppe: Ketten-Verzeichnis alphabetisch.
6. Gruppe mit einer Zeile „Kein fester Markt“.

**Suche.** Filtert alle Sektionen sofort lokal (Aliase und Tippfehler: „lidel“ findet Lidl). Ohne Treffer: Text 17/22
„Kein Markt mit „Bio Kaiser“ gefunden.“ und Text-Knopf „„Bio Kaiser“ als eigenen Markt verwenden“. Ein eigener Markt
hat keine Markenfarbe (`StoreMark` in `fill`) und keine Angebote.

**Zustände.** Lädt: „In der Nähe“ fehlt, bis es Ergebnisse gibt (kein Spinner); offline oder ohne Standort: „In der
Nähe“ fehlt ohne Lücke und ohne Hinweis (hier wird nie nach dem Standort gefragt); Speichern gescheitert: wie S1.

**Interaktion.** Tippen wählt und schließt (Push zurück nach rechts). Zurück-Wischen bricht ab. Keine Haptik.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_pick_title` | Markt | Store |
| `offer_pick_search` | Markt suchen | Search stores |
| `offer_pick_yours` | Deine Märkte | Your stores |
| `offer_pick_nearby` | In der Nähe | Nearby |
| `offer_pick_all` | Alle Märkte | All stores |
| `offer_pick_distance` | {street} · {distance} | {street} · {distance} |
| `offer_pick_no_result` | Kein Markt mit „{query}“ gefunden. | No store called “{query}”. |
| `offer_pick_use_custom` | „{query}“ als eigenen Markt verwenden | Use “{query}” as your own store |

**Barrierefreiheit.** Zeilen „Lidl, ausgewählt“, „REWE, Bertoldstraße, 340 Meter“; Sektionsköpfe sind Überschriften;
Fokus beim Öffnen auf dem Titel, nicht im Suchfeld (Tastatur erst nach Tipp). AX: Unterzeile unter dem Namen,
Entfernung bricht um.

**Daten.** `store_chain_directory.dart` (Suche, Aliase), `store_locator_service.dart` (Overpass `node` und `way`;
gehört gerade dem parallelen Workflow), `user_location_service.dart` (Erlaubnis, 3 s), Lieblingsmärkte (L4), Verlauf
der Liste (L7). Datei `lib/presentation/screens/offers/store_picker_screen.dart`.

---

### S3 Angebots-Pille `ItemOfferBadge`

**Zweck.** Ist dieser Artikel diese Woche bei meinem Markt im Angebot?

**Ort.** Slot `ItemOfferBadge({required String listId, required ShoppingItemModel item, bool compact = false})` am
rechten Ende der Artikelzeile von A (normale Liste: `compact: false`; Einkaufsmodus: `compact: true`), außerdem in
„Zutaten auf Liste“ (A, Rezept) und im Wochenplan „Zutaten der Woche“ (B7).

**Aufbau.** `OfferPriceTag` S. Liste mit Markt: „0,99 €“. Liste ohne Markt (Lieblingsmärkte-Regel K12-03, je Artikel
höchstens ein Angebot, ausgewählt in der Reihenfolge der Lieblingsmärkte, nie nach Preis): „0,99 € · Lidl“. Unsicherer
Treffer: führendes `questionmark.circle`. Preis übernommen: unverändert.

**Zustände.** Nur aus dem Cache beim ersten Frame; abgelaufen verschwindet beim nächsten Öffnen; offline bleibt sie,
solange das Angebot laut Gültigkeit läuft; „Nicht dieses Angebot“ für den Artikel gesetzt: keine Pille; Bedingungen
3.1 nicht erfüllt: nichts, auch keine gespeicherten Angebotspreise am Artikel.

**Interaktion.** Normale Liste: Tippen auf die Pille (Trefferfläche 3.9) öffnet S5 mit `mode=take`. Einkaufsmodus:
nicht separat antippbar; das Kontextmenü der Zeile (A) bekommt den Eintrag „Angebot ansehen“ (Anfrage A-C1). Keine
Haptik.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_badge_a11y` | im Angebot {price} laut Händler | on offer, {price} as stated by the retailer |
| `offer_badge_store_a11y` | im Angebot bei {store}, {price} laut Händler | on offer at {store}, {price} as stated by the retailer |
| `offer_badge_similar_a11y` | ähnliches Produkt im Angebot, {price} laut Händler | similar product on offer, {price} as stated by the retailer |
| `offer_action_view` | Angebot ansehen | View offer |

**Barrierefreiheit.** Kein eigenes Element; der Satz hängt am Label der Zeile, „Angebot ansehen“ ist eine Aktion der
Zeile. AX1: Pille unter dem Namen neben der Menge, wächst bis AX2. 320: rechts, solange der Name 120 pt behält.

**Daten.** `listOffersProvider(listId)` (Cache pro Liste, Lücke L1), `offerSurfaceVisibleProvider` (L3), „Nicht
dieses Angebot“ pro Artikel (L6). Datei `lib/presentation/screens/lists/widgets/item_offer_badge.dart`; ersetzt
`ItemOfferChip` („Spare X € bei …“) und `item_offer_sheet.dart` (Bottom-Sheet, wird gelöscht).

---

### S4 Angebotskarte `ItemOfferCard` im Artikel-Vollbild

**Zweck.** Im Artikel-Vollbild (D2-Artikel, A) zeigen, welches Angebot an diesem Artikel hängt.

**Ort.** Slot `ItemOfferCard({required String listId, required ShoppingItemModel item})` zwischen der Karte „Menge,
Einheit, Kategorie“ und der Karte „Notiz“, 16 darüber.

**Aufbau (D2-Artikel, Wortlaut nach Konzept).**

1. Kicker „Angebot“ (11/13 Medium, Großbuchstaben nur in der Anzeige, `tint`).
2. Titel 17/22 Semibold `label`: „Lidl · 0,99 €“.
3. Zeile 15/20 `tertiaryLabel`: Produkt und Packung „Milbona Frische Vollmilch 3,5 %, 1 l“ (D2 lässt sie weg; nötig,
   weil das Produkt anders heißt als der Artikel).
4. Zeile 15/20 `tertiaryLabel`: „laut Händler statt 1,49 € · bis Sa., 14. Nov.“; ohne „statt“-Preis nur „bis Sa.,
   14. Nov.“; unsicherer Treffer „Ähnliches Produkt · bis Sa., 14. Nov.“.
5. Nur wenn der Preis übernommen ist: Zeile „Preis übernommen“.
6. Link 15/20 Semibold `tint`, 44 hoch: „Angebot ansehen“ (D2 „Im Prospekt ansehen“, siehe Konflikt K8) öffnet S5.

**Zustände.** Kein Angebot oder Bedingungen 3.1 nicht erfüllt: nichts (die Karte „Notiz“ rückt ohne Lücke nach);
offline unverändert aus dem Cache.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_card_kicker` | Angebot | Offer |
| `offer_card_title` | {store} · {price} | {store} · {price} |
| `offer_card_price_taken` | Preis übernommen | Price added |
| `offer_card_a11y` | Angebot: {store}, {price}, {product}, {details} | Offer: {store}, {price}, {product}, {details} |

**Barrierefreiheit.** Die Karte ist ein Element (Label oben, Kicker als Überschrift „Angebot“), der Link ein eigenes
Element danach. AX: alles bricht um, nichts kürzt.

**Daten.** wie S3. Datei `lib/presentation/screens/lists/widgets/item_offer_card.dart`.

---

### S5 Angebot `/offers/offer/:offerId` (Vollbild)

**Zweck.** Was genau ist im Angebot, und will ich den Preis übernehmen bzw. es auf die Liste setzen? Ersetzt das
heutige Angebots-Sheet (Kicker „AKTUELLES ANGEBOT“, „−X %“, „Spart X € gegenüber deinem gespeicherten Preis“,
Händlerbild, rohe Fehler-Snackbar, Datum fest deutsch).

**Route.** V aus S3, S4, S6 (Langdruck), S9, S10, S15 und Avo. Kopf `chevronBack`, Tab-Leiste unsichtbar.

**Aufbau (von oben nach unten).**

1. `GlassToolbar`: links `GlassIconButton` `chevronBack` „Zurück“, Inline-Titel „Angebot“; `ScrollEdgeFade`.
2. Kopf (wie D2-Artikel: Innenrand 0 16, Abstand 16): Kategorie-Kachel 64 Radius 14; daneben Produktname 22/28 Bold
   (`title2`, bricht beliebig um, Überschrift) und darunter 15/20 `secondaryLabel`: `StoreLabel` „Lidl“ · „1 l“.
3. 16 darunter, linksbündig: `OfferPriceTag` L „0,99 €“.
4. 24 darunter `InsetSection` mit `ValueRow`s (fehlende Daten: Zeile entfällt):
   „laut Händler statt“ · „1,19 €“; „Grundpreis“ · „0,99 €/l“; „Gültig“ · „bis Sa., 14. Nov.“ bzw. „abgelaufen“;
   „Markt“ · `StoreLabel` Lidl; „Region“ · „79098 Freiburg“.
5. Nur bei unsicherem Treffer: eigene Gruppe mit einer Zeile, `questionmark.circle` 22 `secondaryLabel`, Text 16/21
   `label`: „Ähnliches Produkt. Prüf vor dem Kauf, ob es zu „Milch“ passt.“
6. Nur bei `mode=take`: Text-Knopf „Nicht dieses Angebot“ (17/22 `tint`, 44 hoch, zentriert).
7. Nur wenn es welche gibt: `SectionCaps` „Weitere Angebote bei Lidl“ + Gruppe mit höchstens 3 `OfferRow` (voll,
   gleicher Markt, passend zum selben Artikel). Tippen tauscht das Angebot dieses Screens (Inhalt blendet über, der
   Titel bleibt; VoiceOver sagt „Angebot gewechselt: {produkt}“).
8. `OffersSourceFootnote`.
9. Unten schwebend die Hauptaktion (2.1): `AppButton.primary` „Preis übernehmen“ (`mode=take`) bzw. „Auf die Liste“
   (`mode=add`). Ist der Preis dieses Angebots schon übernommen: `AppButton.secondary` „Übernommenen Preis entfernen“.
   Abgelaufen: deaktiviert mit „Angebot abgelaufen“. Ab AX3 steht die Hauptaktion am Ende des Inhalts statt schwebend
   (sonst verdeckt sie den halben Bildschirm).

**Zustände.**

| Zustand | Verhalten |
|---|---|
| Laden | gibt es nicht: der Screen öffnet nur mit einem Angebot aus dem lokalen Cache |
| Angebot nicht mehr gespeichert (alter Deep Link, Cache geleert) | `EmptyState(icon: tag)` „Dieses Angebot ist nicht mehr gespeichert.“, Aktion „Zurück“ |
| Preis übernehmen | optimistisch: Screen schließt sofort, der Artikel trägt den Preis (Preis, Händler als Ketten-ID, Einheit, Vergleichspreis, Datum), Hinweis `offer_toast_price_taken` |
| Speichern gescheitert | Artikel rollt zurück, Hinweis wird `offer_toast_price_failed` mit „Erneut versuchen“, `error`-Haptik, die Zeile zeigt kurz „Nicht gespeichert“ (A) |
| Offline | geht in die Warteschlange, Sync-Zeichen am Artikel |
| „Auf die Liste“ mit `list=` | setzt direkt auf diese Liste (Anhängen statt Duplikat, K12-04), Hinweis `offer_toast_added_list` bzw. `offer_toast_attached_list` |
| „Auf die Liste“ ohne `list=` | öffnet das Menü „Auf welche Liste?“ (S10) aus dem Knopf |
| „Nicht dieses Angebot“ | blendet dieses Angebot für diesen Artikel bis zum Ablauf aus, schließt, Hinweis `offer_toast_offer_hidden` |
| Angebot läuft während des Lesens ab | „Gültig“ zeigt „abgelaufen“, Hauptaktion deaktiviert |
| Modul aus oder Kill-Switch während der Screen offen ist | schließt still beim nächsten Wechsel des Flags |
| Pro | nie |

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_detail_title` | Angebot | Offer |
| `offer_detail_was` | laut Händler statt | Was, as stated by the retailer |
| `offer_detail_unit_price` | Grundpreis | Unit price |
| `offer_detail_valid` | Gültig | Valid |
| `offer_detail_expired` | abgelaufen | ended |
| `offer_detail_store` | Markt | Store |
| `offer_detail_area` | Region | Area |
| `offer_detail_similar` | Ähnliches Produkt. Prüf vor dem Kauf, ob es zu „{item}“ passt. | Similar product. Check that it suits “{item}” before you buy it. |
| `offer_detail_not_this` | Nicht dieses Angebot | Not this offer |
| `offer_detail_more_at` | Weitere Angebote bei {store} | More offers at {store} |
| `offer_detail_take_price` | Preis übernehmen | Use this price |
| `offer_detail_add_to_list` | Auf die Liste | Add to list |
| `offer_detail_remove_price` | Übernommenen Preis entfernen | Remove this price |
| `offer_detail_expired_action` | Angebot abgelaufen | Offer has ended |
| `offer_detail_gone` | Dieses Angebot ist nicht mehr gespeichert. | This offer is no longer saved. |
| `offer_detail_swapped_a11y` | Angebot gewechselt: {product} | Offer changed: {product} |
| `offer_price_tag_a11y` | {price}, Angebotspreis | {price}, offer price |

**Barrierefreiheit.** Fokus beim Öffnen auf dem Produktnamen (Überschrift); Reihenfolge Zurück, Titel, Kopf, Preis,
Werte, Hinweis, „Nicht dieses Angebot“, weitere Angebote, Fußnote, Hauptaktion. `ValueRow` liest „laut Händler statt,
1,19 Euro“. AX: Kopf-Kachel entfällt ab AX1, Werte stapeln unter die Titel, Preis höchstens 51 pt.

**Daten.** Angebot aus dem Angebots-Cache nach `offerId` (L2), Artikel aus `itemsNotifierProvider(listId)`, Schreiben
über `ItemRepository` (Preis-Schnittstelle fehlt, Anfrage A-D1), ausgeblendete Angebote pro Artikel (L6),
`regionProvider` (L5). Datei `lib/presentation/screens/offers/offer_detail_screen.dart`.

**Avo.** Keine Figur.

---

### S6 Angebote beim Tippen `OfferSuggestionsBar`

**Zweck.** Ist das, was ich gerade tippe, bei meinem Markt im Angebot? Das Panel dient dem Hinzufügen, nicht dem
Stöbern.

**Ort.** Slot `OfferSuggestionsBar({required String listId, required String query, VoidCallback? onAdded})` im
Vorschlags-Panel über dem Eingabefeld (`AddItemAccessory`, A, S2b). Block 3 am oberen Ende des Panels (E-17): Vorschau
direkt über dem Feld, darüber Verlaufstreffer, ganz oben die Angebote, damit nachkommende Angebote nichts unter dem
Finger verschieben.

**Aufbau.** Bis zu 3 `OfferRow` kompakt: Kategorie-Symbol 28, Produktname 17/22 (bis 2 Zeilen), Unterzeile „Lidl ·
1 l · bis Sa.“, rechts `OfferPriceTag` S. Kein Kopf, kein Kicker, kein „Spare bis zu“, keine Händlerbilder. Liste ohne
Markt: Treffer des ersten Lieblingsmarkts mit Treffer, Pille „0,99 € · Lidl“.

**Zustände.** Suche ab 2 Zeichen nach 300 ms, Mengen über `parseSingleItem` abgetrennt („2 mi“ sucht „mi“). Keine
Treffer, lädt, Fehler, offline: Block fehlt still, das Panel bleibt nutzbar. Ergebnisse kommen: das Panel wächst nach
oben (A, Reduce Motion: Einblenden). Ohne echte Region höchstens einmal pro Sitzung eine Zeile
`offer_hint_set_postcode` mit `location`-Symbol; Tippen öffnet `/stores/region` (die Tastatur schließt; nach dem
Zurückkommen setzt A den Fokus wieder ins Feld, Anfrage A-C4).

**Interaktion.** Tippen: steht der Artikel schon offen auf der Liste („Milch“), wird nur das Angebot angehängt,
Hinweis `offer_toast_attached`; sonst neuer Artikel mit dem getippten Namen und der Menge („Milch“, 2), nicht mit dem
Produktnamen, plus Angebotspreis (`ItemRepository.addItems` mit Preis, Anfrage A-D1); danach `onAdded()` (A leert das
Feld, der Fokus bleibt). Langdruck öffnet S5 mit `mode=add` und `list=`. Keine Haptik.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_suggest_row_sub` | {store} · {pack} · bis {weekday} | {store} · {pack} · until {weekday} |
| `offer_suggest_row_a11y` | {product}, {store}, {pack}, bis {date}, im Angebot {price} laut Händler | {product}, {store}, {pack}, until {date}, on offer, {price} as stated by the retailer |
| `offer_suggest_row_hint_a11y` | Fügt {item} hinzu | Adds {item} |
| `offer_suggest_added_a11y` | {item} hinzugefügt, im Angebot | {item} added, on offer |

**Barrierefreiheit.** Jede Zeile ein Knopf mit Label und Hinweis oben; nach dem Hinzufügen Ansage
`offer_suggest_added_a11y`. AX: Zeilen brechen um, ab AX1 Pille unter dem Namen und kein Symbol; das Panel zeigt
höchstens 5 Zeilen und scrollt intern (A).

**Daten.** Angebotssuche mit Status `ok | leer | fehler` für die Kette der Liste (L2; `offer_price_service.dart` gehört
gerade dem parallelen Workflow), `storeForListProvider`, `regionProvider`, Schalter „Vorschläge beim Tippen“. Datei
`lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart`; die Übergangsform mit `onSelect:` entfällt, sobald
A umgestellt hat.

---

### S7 Ersparnis-Zeile `ListOfferSummary`

**Zweck.** Wie viel von meiner Liste ist diese Woche bei meinem Markt im Angebot?

**Ort.** Slot `ListOfferSummary({required String listId})` an zwei Stellen (A): in der Liste nach der letzten offenen
Kategorie und vor „Erledigt“ (20 darüber); im Einkaufsmodus unter dem Kopf (14 unter der Präsenz-Zeile, D2
`X-Einkaufsmodus`). Die Variante hängt am Modus; dafür braucht der Slot einen Parameter `shoppingMode` (Anfrage A-C3).

**Aufbau (D2 `X-Einkaufsmodus`, als `OfferSummaryCard`).** Weiße Karte Radius 20, Innenrand 12 14, Symbol `tag` 18
`secondaryLabel`, Zeile 1 15/20 Semibold „4 von 11 Artikeln diese Woche bei Lidl im Angebot“, Zeile 2 15/20
`secondaryLabel` „ca. 3,20 € gespart · in deiner Region · Preise laut Händler“. Unter 0,50 € oder ohne „statt“-Preise:
Zeile 2 „in deiner Region · Preise laut Händler“.

- Liste: ganze Karte antippbar (öffnet S9), rechts `chevronRight`, oben rechts Schließen-Knopf („Diese Woche
  ausblenden“, 44).
- Einkaufsmodus: still, ohne Chevron, ohne Schließen (keine Fehltipps im Gehen).

**Zustände.**

| Zustand | Anzeige |
|---|---|
| 0 Angebote | nichts |
| ohne echte Region (nur Liste) | Hinweis `offer_hint_set_postcode` mit Aktion; nach Wegwischen 7 Tage Pause |
| Liste ohne Markt (nur Liste) | Hinweis `offer_hint_no_store`, höchstens 1 × pro Woche |
| Zahl ändert sich (abhaken, hinzufügen) | Ziffern rollen, Höhe bleibt; ob die Karte erscheint, steht beim ersten Frame fest |
| Ersparnis fällt beim Lesen unter 0,50 € | Satz bleibt bis zum nächsten Öffnen |
| offline | aus dem Cache, unverändert |
| Bedingungen 3.1 | nichts |

**Interaktion.** Tippen öffnet S9. Wischen nach links: „Ausblenden“ (diese Woche), Hinweis
`offer_toast_summary_week`. Kontextmenü: „Diese Woche ausblenden“, „Nicht mehr zeigen“ (schaltet „Ersparnis in der
Liste“ aus, Hinweis `offer_toast_summary_off`). Keine Haptik außer `light` an der Wisch-Schwelle.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_summary_hide_week` | Diese Woche ausblenden | Hide this week |
| `offer_summary_never` | Nicht mehr zeigen | Don't show again |
| `offer_summary_hint_a11y` | Zeigt die Angebote dieser Liste | Shows this list's offers |
| `offer_summary_card_a11y` | {sentence}. Preise laut Händler | {sentence}. Prices as stated by the retailer |

**Barrierefreiheit.** Ein Element; Label ist der Pflicht-Satz in einem Stück (`OfferSummaryText.sentence`), nicht die
zwei Zeilen. Aktionen „Diese Woche ausblenden“, „Nicht mehr zeigen“. Wertänderungen werden nicht angesagt. AX: Text
unbegrenzt, Symbol ab AX1 über dem Text (A's `HintRow`); 320/L bis 3 Zeilen.

**Daten.** `listOffersProvider(listId)` (L1), `offer_savings.dart` (L5), `storeForListProvider`, `regionProvider`,
Schalter und Wegwisch-Zustand (L4, L6). Datei `lib/presentation/screens/lists/widgets/list_offer_summary.dart`; ersetzt
`ListPriceSummaryBar`, `PriceComparisonNudgeCard`, `basketComparisonProvider`, `homePriceHighlightProvider`,
`comparableTotal`, `home_price_comparison_cache_service.dart` (werden gelöscht).

---

### S8 Zähler auf der Listenkarte `ListOfferCountBadge`

**Zweck.** Auf einen Blick in der Listen-Übersicht: In dieser Liste sind Sachen im Angebot.

**Ort.** Slot `ListOfferCountBadge({required String listId})` oben links auf dem Cover der Listenkarte (D2-Home).

**Aufbau (D2-Home).** `ContentGlass`-Pille: `tag` 11 + „2 Angebote“, 11/13 Semibold `tint`. Deckkraft mindestens 92 %
(3.8).

**Zustände.** 0 oder Bedingungen 3.1 nicht erfüllt: nichts. Zählt offene Artikel mit Angebot des Listen-Markts (bzw.
nach der Lieblingsmärkte-Regel) aus dem Cache; offline unverändert. Zeigt A das Cover ab AX1 nicht, setzt A die Pille
in die Metazeile der Karte (Anfrage A-L2).

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_count_badge` | {n, plural, =1{1 Angebot} other{# Angebote}} | {n} on offer |
| `offer_count_badge_a11y` | {n, plural, =1{1 Artikel im Angebot} other{# Artikel im Angebot}} | {n, plural, =1{1 item on offer} other{# items on offer}} |

**Barrierefreiheit.** Nicht antippbar (die Karte ist es); der Satz hängt am Label der Karte. Transparenz reduzieren:
festes Weiß mit Kontur.

**Daten.** `listOffersProvider(listId)`. Datei `lib/presentation/screens/lists/widgets/list_offer_count_badge.dart`.

---

### S9 Angebote bei {Markt} `/offers/list/:listId`

**Zweck.** Welche Artikel meiner Liste sind bei Lidl im Angebot? Ersetzt das Konzept-Sheet „Angebote bei Lidl“.

**Route.** K im Listen-Tab aus S7, aus dem Listenmenü „Angebote dieser Liste“ (A) und aus Avo („Ansehen“). Kopf
`chevronBack`, Tab-Leiste sichtbar. Zurück führt zur Liste (Test: nicht zu S10, auch wenn `/offers` der Elternpfad ist).

**Aufbau.**

1. `GlassToolbar` mit `chevronBack`; großer Titel „Angebote bei Lidl“ (bricht um).
2. Satz 16/21 `label` (16 Rand, 8 unter dem Titel): der Pflicht-Satz `OfferSummaryText.sentence`.
3. `SectionCaps` „Auf deiner Liste“ mit Anzahl rechts + Gruppe mit `OfferRow` (voll), Reihenfolge wie in der Liste
   (Reihenfolge im Markt), nie nach Rabatt: Titel „Milch · 2“ (Artikel und Menge), Unterzeile 1 „Milbona Frische
   Vollmilch 3,5 % · 1 l · bis Sa., 14. Nov.“, Unterzeile 2 „laut Händler statt 1,19 €“, rechts Pille. Tippen öffnet
   S5 (`mode=take`).
4. Nur mit Schalter „Spar-Hinweise auf der Startseite“: `SectionCaps` „Diese Woche bei Lidl, oft gekauft“ + Gruppe mit
   bis zu 3 Stammartikeln, die nicht auf der Liste stehen, je mit `plus.circle` (44). Plus setzt den Artikel mit
   Angebot auf diese Liste; die Zeile wandert in „Auf deiner Liste“ (`AvoMotion.move`), Ziffern im Satz rollen
   („5 von 12“), Hinweis `offer_toast_added_list`.
5. Gruppe mit zwei Text-Knöpfen (je eigene Zeile, 52): „Alle Angebote der Woche“ (öffnet S10) und „Angebote für diese
   Liste ausblenden“ mit Symbol `eye.slash`, in `tint`, nicht rot (umkehrbar, löscht nichts).
6. Fußnoten: `offer_savings_explainer`, darunter `OffersSourceFootnote`.

**Liste ohne Markt.** Titel „Angebote für {Liste}“, kein Satz (er braucht genau einen Markt), Zeilen mit Pille „0,99 € ·
Lidl“, Fuß `offer_list_no_store_note` und Text-Knopf „Markt wählen“ (öffnet S2 mit `list=`).

**Zustände.**

| Zustand | Anzeige | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Erstes Öffnen ohne Cache | `SkeletonSection` (3 Zeilen, mit Bild) | | | |
| Offline | `StatusRow` 3.4 mit Stand | | | |
| Aktualisieren gescheitert | `StatusRow` 3.4, Inhalt bleibt | | | |
| Nichts (mehr) im Angebot | `EmptyState(icon: tag)`, ohne Figur (Geld) | `offer_list_empty_title`, `offer_list_empty_body` | Gerade nichts im Angebot. · Neue Angebote kommen meist am Montag. | Nothing on offer right now. · New offers usually arrive on Mondays. |
| Ohne echte Region | `EmptyState(icon: location)` mit Aktion „Postleitzahl festlegen“ (öffnet `/stores/region`) | `offer_need_area_title`, `offer_need_area_action` | Für Angebote brauchst du eine Region. · Postleitzahl festlegen | You need an area to see offers. · Set postcode |
| Angebote für diese Liste ausgeblendet | `EmptyState(icon: eye.slash)` mit Aktion „Einblenden“ | `offer_list_hidden_title`, `offer_show_again` | Angebote sind für {list} ausgeblendet. · Einblenden | Offers are hidden for {list}. · Show offers |
| Liste gelöscht, kein Mitglied mehr | Fehlerseite von A | | | |
| Modul aus / Kill-Switch | 1.3 | | | |

**Interaktion.** „Ausblenden“ wirkt sofort: der Screen schließt, in der Liste verschwinden Pillen und Ersparnis-Zeile
(`AvoMotion.standard`), Hinweis `offer_toast_list_hidden`. Ziehen nach unten am Anfang aktualisiert (System-Verhalten).

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_list_title` | Angebote bei {store} | Offers at {store} |
| `offer_list_title_no_store` | Angebote für {list} | Offers for {list} |
| `offer_list_on_list` | Auf deiner Liste | On your list |
| `offer_list_regulars` | Diese Woche bei {store}, oft gekauft | Often bought, on offer at {store} this week |
| `offer_list_item_qty` | {item} · {qty} | {item} · {qty} |
| `offer_list_all_offers` | Alle Angebote der Woche | All offers this week |
| `offer_hide_for_list` | Angebote für diese Liste ausblenden | Hide offers for this list |
| `offer_list_no_store_note` | {list} hat keinen festen Markt. Du siehst Angebote deiner Lieblingsmärkte, in deren Reihenfolge. | {list} has no fixed store, so you see offers from your favourite stores, in your order. |
| `offer_add_plus_a11y` | {product} auf {list} setzen | Add {product} to {list} |

**Barrierefreiheit.** Titel ist Überschrift, danach der Satz als eigenes Element; Sektionsköpfe mit Anzahl; Zeilen
„Milch, 2, Milbona Frische Vollmilch 3,5 Prozent, 1 Liter, bis Samstag, 14. November, laut Händler statt 1,19 Euro, im
Angebot 0,99 Euro“; Plus mit Label `offer_add_plus_a11y`. AX: Zeilen stapeln, Plus oben rechts.

**Daten.** `listOffersProvider(listId)`, `offer_savings.dart`, Stammartikel im Angebot (Regeln aus `AvoNudgeService`,
anderer Workflow; L8), `setOffersHiddenForList`, `itemsNotifierProvider`. Datei
`lib/presentation/screens/offers/list_offers_screen.dart`.

**Avo.** Keine Figur.

---

### S10 Angebote der Woche `/offers` und Menü „Auf welche Liste?“

**Zweck.** Was von meinen Sachen ist diese Woche im Angebot? Zwei Fragen, je ein Segment: „Was von meinen Listen?“ und
„Was kaufe ich oft, das gerade im Angebot ist?“. Ersetzt `weekly_deals_screen.dart` (Material-AppBar, Kicker,
Händlerbilder, „−X %“, Sortierung nach Rabatt, Vollflächen-Spinner, Bottom-Sheet `_AddDealSheet`).

**Route.** Wurzel `/offers` im Listen-Tab (Push). Einstiege: Listen-Übersicht (A, Abschnitt „Sparen“), Home „Angebote
ansehen“ und Kachel (A/B), Hinweis „3 Sachen …“ (`filter=regulars`), S9, Avo (`q=`).

**Aufbau.**

1. `GlassToolbar` mit `chevronBack`; großer Titel „Angebote der Woche“.
2. Metazeile als Text-Knopf (44 hoch): „In deiner Region · 79098 Freiburg“ 15/20 `secondaryLabel` mit `chevronRight`
   11; öffnet `/stores/region`.
3. `AvoSearchField` „Angebote suchen“ (12 darunter).
4. `AppSegmentedControl` „Deine Listen | Oft gekauft“ (12 darunter). Fehlt, wenn „Spar-Hinweise auf der Startseite“ aus
   ist; dann gilt nur „Deine Listen“.
5. `ChipRow` mit `StoreFilterChip` (Einfachauswahl): erst die Märkte der Listen, dann Lieblingsmärkte. Ohne Auswahl
   gelten alle; erneutes Tippen hebt die Auswahl auf. Märkte filtern nur, sie werden nie gegeneinander gestellt.
6. Segment „Deine Listen“: eine Sektion pro Liste mit Markt (höchstens die 2 zuletzt geänderten Listen mit offenen
   Artikeln): `SectionCaps` „Wocheneinkauf · Lidl“ mit Anzahl. `OfferRow` voll: Produktname; Unterzeile 1 „Für „Milch“
   auf Wocheneinkauf“ (nur wenn der Produktname abweicht); Unterzeile 2 „1 l · 0,99 €/l · laut Händler statt 1,19 €“;
   Unterzeile 3 nur bei höchstens 3 Kalendertagen „endet morgen“ bzw. „Ähnliches Produkt“; rechts Pille und
   `plus.circle` (setzt direkt auf die Liste der Sektion). Liste ohne Markt: Sektion „Drogerie · Lieblingsmärkte“,
   Pille mit Markt.
7. Segment „Oft gekauft“: eine Gruppe mit Stammartikeln, die nicht offen auf einer Liste stehen, je bei dem Markt, bei
   dem man sie meist kauft, sonst beim ersten Lieblingsmarkt; Unterzeile „REWE · Kaufst du etwa alle 10 Tage“; rechts
   Pille und `plus.circle` (öffnet das Menü „Auf welche Liste?“). Kein Marktwechsel wegen des Preises.
8. Suche (ab 2 Zeichen, 300 ms): das Segment blendet aus, die Chips bleiben; Treffer gruppiert nach Markt (Listen-Märkte,
   Lieblingsmärkte, dann alphabetisch), nie nach Preis, innerhalb des Markts nach Relevanz (exakter Treffer vor
   Stamm-Treffer); `SectionCaps` „Lidl“ mit Anzahl; `plus.circle` öffnet das Menü.
9. `OffersSourceFootnote`; unten Platz für die Tab-Leiste.

**Menü „Auf welche Liste?“** (Pull-down aus dem `plus.circle`, kein Häkchen, scrollt intern, Zeilen mindestens 44):
oben die Liste von heute, dann weitere nach zuletzt geändert; je Zeile Listen-Glyph (A), Name, darunter der Markt der
Liste. Gilt das Angebot dort nicht: Unterzeile „Lidl · Angebot gilt dort nicht“, die Liste bleibt wählbar (dann kommt
nur der Artikel, Hinweis `offer_toast_added_no_offer`). Trenner, „Neue Liste …“ (öffnet „Neue Liste“ von A mit dem
Markt des Angebots vorausgewählt; danach landet der Artikel dort, Anfrage A-L3). Passt das Angebot zu einem offenen
Artikel der Ziel-Liste, wird es angehängt statt dupliziert; sonst neuer Artikel mit einfachem Namen („Haferflocken“).

**Zustände.**

| Zustand | Anzeige | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Ohne echte Region | statt Suche, Segment, Chips: `EmptyState(icon: location)`, ohne Figur; Aktion des `EmptyState` „Standort verwenden“ (fragt direkt das System, die Erklärung steht im Satz), darunter ein Text-Knopf „Postleitzahl eingeben“ (öffnet `/stores/region`), weil `EmptyState` nur eine Aktion hat. Keine Anfragen | `offer_week_no_area_title`, `offer_week_no_area_body`, `offer_use_location`, `offer_enter_postcode` | Wo kaufst du ein? · Angebote gelten pro Region. Mit deiner Postleitzahl siehst du, was bei deinen Märkten im Angebot ist. · Standort verwenden · Postleitzahl eingeben | Where do you shop? · Offers depend on your area. Add your postcode to see what's on offer at your stores. · Use my location · Enter postcode |
| Standort abgelehnt | im Leerzustand `StatusRow(kind: permission)` statt „Standort verwenden“ | `offer_location_off` | Standort ist aus. In Einstellungen erlauben | Location is off. Allow it in Settings |
| Erstes Laden | `SkeletonSection` je Sektion, Teilergebnisse sofort | | | |
| Keine Listen-Treffer | Sektion entfällt; alle leer: `EmptyState(icon: tag)` | `offer_week_lists_empty_title`, `offer_week_lists_empty_body` | Gerade nichts von deinen Listen im Angebot. · Such oben nach einem bestimmten Produkt. | Nothing from your lists is on offer right now. · Search above for a specific product. |
| „Oft gekauft“ leer | `EmptyState(icon: tag)` | `offer_week_regulars_empty` | Gerade ist nichts im Angebot, was du oft kaufst. | Nothing you buy often is on offer right now. |
| „Oft gekauft“ ohne Kaufstatistik | `EmptyState(icon: tag)` | `offer_week_regulars_new` | Nach ein paar Einkäufen siehst du hier, was du oft kaufst und gerade im Angebot ist. | After a few shopping trips, you'll see what you often buy that's on offer. |
| Suche ohne Treffer | `EmptyState(pose: AvoPose.thinking)` 96 pt, ab AX1 ohne Figur | `offer_week_search_empty` | Kein Angebot für „{query}“ in deiner Region. | No offers for “{query}” in your area. |
| Offline | `StatusRow` mit Stand; Suche nur im Cache mit `offer_status_offline_search` | | | |
| Fehler einer Sektion | `StatusRow(kind: sectionError)` in der Sektion, nie als „keine Angebote“ | | | |
| Modul aus / Kill-Switch | 1.3 | | | |
| Pro | nie | | | |

**Interaktion.** Zeile öffnet S5 (`mode=add`, mit `list=` in „Deine Listen“). Wischen nach rechts auf einer Zeile: „Auf
die Liste“ (wie `plus.circle`). In „Oft gekauft“ Wischen nach links bzw. Kontextmenü „Nicht interessiert“: blendet das
Angebot bis zu seinem Ablauf aus, höchstens 7 Tage, Hinweis `offer_toast_not_interested`. Segment-Wechsel per Wischen
mit `selection`-Haptik. Ziehen nach unten am Anfang aktualisiert.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_week_title` | Angebote der Woche | Offers this week |
| `offer_week_area` | In deiner Region · {postcode} {city} | In your area · {postcode} {city} |
| `offer_week_area_a11y` | Region: {postcode} {city}, ändern | Area: {postcode} {city}, change |
| `offer_week_search` | Angebote suchen | Search offers |
| `offer_week_seg_lists` | Deine Listen | Your lists |
| `offer_week_seg_regulars` | Oft gekauft | Often bought |
| `offer_week_section` | {list} · {store} | {list} · {store} |
| `offer_week_section_favorites` | {list} · Lieblingsmärkte | {list} · Favourite stores |
| `offer_week_for_item` | Für „{item}“ auf {list} | For “{item}” on {list} |
| `offer_week_rhythm` | {store} · Kaufst du etwa alle {days} Tage | {store} · You buy this about every {days} days |
| `offer_week_not_interested` | Nicht interessiert | Not interested |
| `offer_week_add_swipe` | Auf die Liste | Add to list |
| `offer_menu_which_list` | Auf welche Liste? | Add to which list? |
| `offer_menu_not_valid_there` | {store} · Angebot gilt dort nicht | {store} · offer doesn't apply there |
| `offer_menu_new_list` | Neue Liste … | New list… |

**Barrierefreiheit.** Reihenfolge: Zurück, Titel, Region-Knopf, Suche, Segment, Chips, Sektionen, Fußnote. Segment
liest „Deine Listen, ausgewählt, 1 von 2“ (A). Chips „Lidl, Filter, ausgewählt“. Zeilen wie S9, Aktionen „Auf die
Liste“, „Nicht interessiert“, „Angebot ansehen“. AX: Chips ab xxxL umbrochen, Segment wird ab AX1 Pull-down „Zeigen:
Deine Listen“, wenn es nicht passt (A), Zeilen stapeln, Plus oben rechts. 320/L: Unterzeilen brechen, Pille rechts bis
L, darüber darunter.

**Daten.** Angebote je Liste (`listOffersProvider`, höchstens 2 Listen), Stammartikel (`personalized_deals_service` und
`AvoNudgeService`, anderer Workflow, nach Listen-Reihenfolge statt Rabatt sortiert; L8), Suche mit Status (L2),
Lieblingsmärkte (L4), Listen (A, `listsNotifierProvider`, „Liste von heute“ L9), `regionProvider`. Datei
`lib/presentation/screens/offers/weekly_offers_screen.dart`.

**Avo.** `AvoPose.thinking` nur bei „Suche ohne Treffer“ (3.13).

---

### S11 Region `/settings/offers/region` und `/stores/region` (bei Kill-Switch „Standort“)

**Zweck.** Für welche Region sollen Angebote gelten? Ersetzt `zip_code_sheet.dart`, `showManualZipDialog` und das
Konzept-Sheet „Region für Angebote“ samt zweitem Sheet für die Standort-Erklärung. Die PLZ wandert aus „Persönliche
Daten“ hierher; die Ersatz-PLZ 10115 gibt es nicht mehr.

**Route.** E im Profil-Tab aus S12; V `/stores/region` aus S7-Hinweis, S6, S9, S10 und Avo. Ein Widget, zwei Köpfe:

| | E | V |
|---|---|---|
| links | `chevronBack` „Zurück“ | `xmark` „Schließen“ |
| rechts | getönte Text-Kapsel „Fertig“ (44, D2-Artikel), aktiv bei gültiger, geänderter Region | gleich |
| Titel | Inline „Region“, bei Kill-Switch „Standort“ | gleich |

**Aufbau.**

1. Satz 17/22 `label`, 16 Rand.
2. Gruppe 1: `UseLocationRow` „Standort verwenden“. Unterzeile vor der ersten Nutzung „Fragt einmal nach deinem
   Standort. Gespeichert wird nur die Postleitzahl.“ (das ist die Erklärung vor der Systemabfrage, am Ort statt in
   einem zweiten Sheet; Owner-Frage 12); mit Ergebnis „Aktuell: 79098 Freiburg im Breisgau“. Tippen fragt das System
   („Beim Verwenden der App“), ortet mit 3 s Zeitlimit und füllt das Feld; gespeichert wird erst mit „Fertig“.
3. Gruppe 2: `PostcodeFieldRow` „Postleitzahl“, Platzhalter „z. B. 79098“. Unter der Gruppe die Ortszeile 13/18
   `secondaryLabel` „79098 · Freiburg im Breisgau“ (lokal aus der PLZ-Tabelle, ohne Tabelle „PLZ 79098“) bzw. die
   Fehlerzeile mit `exclamationmark.circle` in `destructive`.
4. Nur wenn eine Region gesetzt ist: `DestructiveRow` „Region entfernen“ in eigener Gruppe; ohne Rückfrage, mit
   Rückgängig-Hinweis, der Screen bleibt offen und das Feld wird leer.

**Zustände.**

| Zustand | Anzeige | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Ortung läuft | Aktivitätsanzeiger rechts in Zeile 1, Text bleibt | `offer_locating_a11y` | Standort wird ermittelt | Finding your location |
| Standort abgelehnt | Zeile 1 wird `StatusRow(kind: permission)` mit Aktion (öffnet die iOS-Einstellungen); Feld bleibt nutzbar | `offer_location_off` | Standort ist aus. In Einstellungen erlauben | Location is off. Allow it in Settings |
| Standort nicht ermittelbar | `StatusRow(kind: sectionError)` | `offer_location_unavailable` | Standort gerade nicht verfügbar. Gib deine Postleitzahl ein. | Location isn't available right now. Enter your postcode. |
| Standort im Ausland | Text unter Zeile 1 | `offer_location_abroad` | Angebote gibt es nur für Deutschland. | Offers are only available in Germany. |
| Weniger als 5 Ziffern beim Verlassen des Felds | Fehlerzeile, „Fertig“ aus | `offer_postcode_digits` | Bitte 5 Ziffern eingeben. | Enter 5 digits. |
| Unbekannte PLZ | Fehlerzeile, „Fertig“ aus | `offer_postcode_unknown` | Diese Postleitzahl kennen wir nicht. | We don't know this postcode. |
| Offline | Speichern lokal, gilt sofort | | | |
| Schließen mit ungesicherter Änderung | Dialog „Änderungen verwerfen?“ (S16) | | | |
| Kill-Switch | Titel „Standort“, eigener Satz, Ausland-Text ohne „Angebote“ | `offer_location_abroad_stores` | Avo kennt bisher nur Märkte in Deutschland. | Avo only knows stores in Germany so far. |
| Modul aus | öffnet normal (die Region bleibt für später gespeichert) | | | |

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_region_title` | Region | Area |
| `offer_region_title_stores` | Standort | Location |
| `offer_region_intro` | Angebote gelten für eine Region, nicht für einen einzelnen Markt. Wir speichern deine Postleitzahl und schicken sie nur an die Angebotsquelle. | Offers apply to an area, not to a single store. We store your postcode and only send it to the offer source. |
| `offer_region_intro_stores` | Mit deinem Standort kann Avo Märkte in deiner Nähe vorschlagen. | With your location, Avo can suggest stores near you. |
| `offer_use_location` | Standort verwenden | Use my location |
| `offer_use_location_sub` | Fragt einmal nach deinem Standort. Gespeichert wird nur die Postleitzahl. | Asks for your location once. Only the postcode is saved. |
| `offer_use_location_current` | Aktuell: {postcode} {city} | Current: {postcode} {city} |
| `offer_postcode_label` | Postleitzahl | Postcode |
| `offer_postcode_placeholder` | z. B. {example} | e.g. {example} |
| `offer_postcode_place` | {postcode} · {city} | {postcode} · {city} |
| `offer_postcode_place_fallback` | PLZ {postcode} | Postcode {postcode} |
| `offer_region_remove` | Region entfernen | Remove area |
| `done` (Bestand) | Fertig | Done |

**Barrierefreiheit.** Feld mit Label „Postleitzahl“ und Wert; Fehler werden angesagt und hängen am Feld („Postleitzahl,
7909, Bitte 5 Ziffern eingeben.“); Ortszeile als Wert-Hinweis des Felds. „Fertig“ deaktiviert liest „gedimmt“. AX:
Beschriftung über dem Feld, Ziffernfeld wächst mit der Schrift (keine feste Höhe).

**Daten.** `regionProvider` (neu, ersetzt `userZipCodeProvider`/`effectiveZipProvider`, L5),
`user_location_service.dart` (anderer Workflow), PLZ-Tabelle (L10, Quelle und Lizenz offen), Speicherort Konto (L4).
Datei `lib/presentation/screens/offers/region_screen.dart`.

**Avo.** Keine Figur.

---

### S12 Preise & Angebote `/settings/offers` (bei Kill-Switch „Märkte“)

**Zweck.** Was zeigt mir die App zu Angeboten und Märkten, und woher weiß sie es? D2 `X-Angebote` gibt das Aussehen,
das Konzept 6.3 den Inhalt; was D2 fehlt, ist im D2-Stil ergänzt (Konflikt K7).

**Route.** E im Profil-Tab aus der Zeile „Preise & Angebote · Lidl, REWE“ (A, X-Profil) und aus Einstellungen > Module
(A). Suchwörter für die Einstellungs-Suche (A-Index): „Angebote“, „PLZ“, „Postleitzahl“, „Region“, „Prospekt“, „Markt“,
„Sparen“; bei Kill-Switch nur „Markt“, „Märkte“, „Standort“.

**Aufbau.**

1. `GlassToolbar` mit `chevronBack`; großer Titel „Preise & Angebote“.
2. Gruppe ohne Kopf: `ToggleRow` (56, Titel Semibold) „Preise & Angebote“ mit Unterzeile „Angebote deiner Märkte in
   Listen und beim Hinzufügen“. Das ist der Modul-Schalter (`appModulesProvider.notifier.setEnabled(AppModule.offers,
   …)`), derselbe wie im Profil. Fußnote: `OffersSourceFootnote`.
3. Nur mit Modul an: `SectionCaps` „Anzeigen“ + Gruppe mit fünf `ToggleRow`s, alle standardmäßig an:
   „Angebote an Artikeln“, „Vorschläge beim Tippen“, „Ersparnis in der Liste“ (Unterzeile „„4 von 11 im Angebot““),
   „Spar-Hinweise auf der Startseite“, „Ersparnis im Verlauf und nach dem Einkauf“.
4. `SectionCaps` „Meine Märkte“ + Gruppe: oben die Chips der Lieblingsmärkte in ihrer Reihenfolge (D2: `StoreMark` 20,
   Name, 32 hoch, `Wrap`, Abstand 8, Innenrand 12 16) und ein Chip „+ Markt“ in `tint`; der ganze Chip-Bereich ist ein
   Knopf und öffnet S13. Darunter, getrennt, `ToggleRow` „Markt automatisch erkennen“. Fußnote
   `offer_settings_detect_note`.
5. Gruppe: `NavRow` `location` „Region“ mit Wert „79098 Freiburg“, öffnet S11. Ohne Region: Wert „Nicht festgelegt“
   mit Symbol `exclamationmark.triangle.fill` in `warning` davor (Symbol plus Text).
6. Nur mit Modul an und ausgeblendeten Listen: `SectionCaps` „Ausgeblendet für“ + Gruppe: je Liste Name und rechts
   Text-Knopf „Einblenden“ (44). Einblenden: Zeile verschwindet (`AvoMotion.move`), Hinweis `offer_toast_list_shown`.
7. Gruppe: `NavRow` „Datenquellen“ (öffnet die Seite von A unter Rechtliches).

**Zustände.**

| Zustand | Inhalt |
|---|---|
| Modul an | 1 bis 7 |
| Modul aus (Schalter in 2 aus) | 3 und 6 klappen zusammen (`AvoMotion.standard`); 2, 4, 5, 7 bleiben; Fußnote bleibt |
| Kill-Switch | Titel „Märkte“ (auch Profil-Zeile und Suchtreffer); 2, 3, 6 und die Quellen-Fußnote entfallen; 4 bleibt; 5 heißt „Standort“ mit Unterzeile „Für Markt-Vorschläge“; 7 bleibt (die Seite Datenquellen nennt dann keine Angebotsquelle, L12) |
| Keine Lieblingsmärkte | im Chip-Bereich Text 15/20 `secondaryLabel` „Noch keine Lieblingsmärkte“ und Chip „+ Markt“ |
| Offline | Schalter wirken lokal sofort, Abgleich mit dem Konto später |
| Pro | nie |

Jede Zeile schaltet als Ganzes (A); Wirkung sofort und neustartfest; keine Haptik.

| Schlüssel | Deutsch | English |
|---|---|---|
| `common_module_offers` (A, Bestand) | Preise & Angebote | Prices & offers |
| `offer_settings_title_stores` | Märkte | Stores |
| `offer_settings_master_sub` | Angebote deiner Märkte in Listen und beim Hinzufügen | Offers from your stores, in lists and while adding items |
| `offer_settings_show` | Anzeigen | Show |
| `offer_settings_on_items` | Angebote an Artikeln | Offers on items |
| `offer_settings_while_typing` | Vorschläge beim Tippen | Suggestions while typing |
| `offer_settings_in_list` | Ersparnis in der Liste | Savings in the list |
| `offer_settings_in_list_sub` | „4 von 11 im Angebot“ | “4 of 11 on offer” |
| `offer_settings_home_tips` | Spar-Hinweise auf der Startseite | Savings tips on Home |
| `offer_settings_history` | Ersparnis im Verlauf und nach dem Einkauf | Savings in history and after shopping |
| `offer_settings_my_stores` | Meine Märkte | My stores |
| `offer_settings_add_store` | + Markt | + Store |
| `offer_settings_no_favorites` | Noch keine Lieblingsmärkte | No favourite stores yet |
| `offer_settings_stores_a11y` | Meine Märkte: {stores}. Bearbeiten | My stores: {stores}. Edit |
| `offer_settings_detect` | Markt automatisch erkennen | Detect store automatically |
| `offer_settings_detect_note` | Avo erkennt den Markt am Listennamen und an deinen Einkäufen. Mit Standort fragt Avo auch im Laden nach. Was Avo nur vermutet, bleibt ein Vorschlag. | Avo recognises the store from the list name and your shopping trips. With location on, Avo also asks when you're in a store. Anything Avo only guesses stays a suggestion. |
| `offer_settings_region` | Region | Area |
| `offer_settings_region_unset` | Nicht festgelegt | Not set |
| `offer_settings_location_stores` | Standort | Location |
| `offer_settings_location_stores_sub` | Für Markt-Vorschläge | For store suggestions |
| `offer_settings_hidden_for` | Ausgeblendet für | Hidden for |
| `offer_show_again` | Einblenden | Show offers |
| `offer_toast_list_shown` | Angebote für {list} eingeblendet | Offers shown for {list} |
| `offer_settings_sources` | Datenquellen | Data sources |

**Barrierefreiheit.** Schalter mit Zustand; Unterzeile Teil des Labels. Chip-Bereich ein Knopf mit
`offer_settings_stores_a11y`. „Nicht festgelegt“ mit Symbol liest „Region, nicht festgelegt, Warnung“. AX: Werte und
Schalter unter den Titeln (A), Chips umbrechen, ab AX3 ein Chip pro Zeile.

**Daten.** `moduleEnabledProvider(AppModule.offers)`, `offersRemoteEnabledProvider`, Einzel-Schalter, Lieblingsmärkte,
Erkennung, ausgeblendete Listen (alle in `offerPrefsProvider`, L4; heute `hiddenOfferListsProvider` nur lokal),
`regionProvider`. Datei `lib/presentation/screens/profile/settings/offers_settings_screen.dart` (B-Ausnahme im A-Ordner).

**Avo.** Keine Figur.

---

### S13 Lieblingsmärkte `/settings/offers/markets` (Kern)

**Zweck.** Bei welchen Märkten kaufe ich ein, und in welcher Reihenfolge? Die Reihenfolge ist der Vorrang bei Listen
ohne Markt (K12-03) und die Reihenfolge im Markt-Menü.

**Route.** E im Profil-Tab aus S12. Kopf `chevronBack`, Inline-Titel „Lieblingsmärkte“ (dritte Ebene).

**Aufbau.**

1. `SectionCaps` „Deine Märkte“ + Gruppe: Zeile 52 mit Auswahl-Kreis (gewählt, `tint`), `StoreMark` 28, Name, rechts
   Zieh-Griff (`line.3.horizontal`, 22 in 44). Fußnote `offer_favorites_note`.
2. Ab 12 Ketten: `AvoSearchField` „Markt suchen“ über „Weitere Märkte“.
3. `SectionCaps` „Weitere Märkte“ + Gruppe: Ketten-Verzeichnis alphabetisch, Auswahl-Kreis leer (`uncheckedRing`).

**Interaktion.** Tippen auf eine Zeile schaltet hinzu oder weg. Hinzufügen: Zeile wandert ans Ende von „Deine Märkte“
(`AvoMotion.move`), kein Hinweis. Entfernen: zurück an den alphabetischen Platz, Hinweis
`offer_toast_favorite_removed`. Umsortieren über den Zieh-Griff oder Langdruck auf die Zeile: die Zeile folgt dem
Finger 1:1, Nachbarn machen Platz, Einrasten mit `selection`-Haptik. Ab AX1 zusätzlich Kontextmenü „Nach oben“ / „Nach
unten“.

**Zustände.** Keine gewählt: Satz 17/22 „Noch keine Lieblingsmärkte.“ an Stelle der Gruppe, Fußnote bleibt. Offline:
gilt sofort lokal. Kill-Switch: Fußnote `offer_favorites_note_stores`. Reduce Motion: Überblenden statt Wandern.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_favorites_title` | Lieblingsmärkte | Favourite stores |
| `offer_favorites_yours` | Deine Märkte | Your stores |
| `offer_favorites_more` | Weitere Märkte | More stores |
| `offer_favorites_note` | Listen ohne festen Markt zeigen Angebote dieser Märkte, in dieser Reihenfolge. | Lists without a fixed store show offers from these stores, in this order. |
| `offer_favorites_note_stores` | Diese Märkte stehen oben, wenn du für eine Liste einen Markt wählst. | These stores come first when you choose a store for a list. |
| `offer_favorites_empty` | Noch keine Lieblingsmärkte. | No favourite stores yet. |
| `offer_favorites_row_a11y` | {store}, Lieblingsmarkt, Platz {n} von {m} | {store}, favourite store, {n} of {m} |
| `offer_favorites_move_up` | Nach oben | Move up |
| `offer_favorites_move_down` | Nach unten | Move down |
| `offer_favorites_reorder_a11y` | Verschieben | Reorder |

**Barrierefreiheit.** Gewählte Zeilen lesen Platz und Anzahl; Aktionen „Nach oben“, „Nach unten“, „Entfernen“; der
Zieh-Griff ist für VoiceOver ausgeblendet (die Aktionen ersetzen ihn). AX: Zeilen brechen um, Zieh-Griff oben rechts
bündig zur ersten Textzeile.

**Daten.** Lieblingsmärkte mit Reihenfolge (`offerPrefsProvider`, L4), `store_chain_directory.dart`. Datei
`lib/presentation/screens/offers/favorite_markets_screen.dart`.

---

### S14 Onboarding-Schritt `OffersSetupStep` (Slot in `/onboarding?step=region`)

**Zweck.** Für welche Region und welche Märkte soll ich Angebote sehen? Unter 10 s auf dem Standardweg (Konzept 17).

**Ort.** Slot `OffersSetupStep({required VoidCallback onDone})`. A baut den Rahmen (Zurück, Fortschrittslinie,
„Überspringen“), den Titel „Angebote in deiner Region“ und den Satz „Du siehst nur Angebote der Märkte, in denen du
einkaufst. Dafür brauchen wir deine Region.“ Nur bei Modul an und Kill-Switch an; sonst rendert B
`SizedBox.shrink()` und A überspringt den Schritt ohne Spur.

**Aufbau (B-Inhalt).**

1. `SectionCaps` „Region“ + Gruppe: `UseLocationRow` mit Unterzeile `offer_setup_location_sub` (Erklärung am Ort; der
   Tipp löst direkt die Systemabfrage aus), darunter `PostcodeFieldRow` mit Platzhalter „z. B. 10437“. Unter der
   Gruppe die Ortszeile „10437 Berlin“.
2. `SectionCaps` „Deine Märkte“ + weiße Gruppe mit `StoreFilterChip`s (Mehrfachauswahl, `Wrap`, Abstand 8): ohne
   Standort in fester Reihenfolge Lidl, Aldi, REWE, Edeka, Kaufland, Netto, PENNY; mit PLZ wird „Aldi“ zu „Aldi Nord“
   bzw. „Aldi Süd“; mit Standort stehen die nächsten Märkte vorn mit Entfernung („Lidl · 400 m“). Gewählt: Häkchen und
   `chipSelected`. Fußnote `offer_setup_stores_note`.
3. Fußnote `offer_setup_source_note`.
4. Hauptaktion „Weiter“ (`AppButton.primary`, schwebend unten): speichert Region und Märkte, ruft `onDone`. Ob B oder A
   diesen Knopf zeichnet, klärt Anfrage A-O1; Vorschlag: B, weil nur B weiß, wann alles gespeichert ist.

**Zustände.**

| Zustand | Anzeige | Schlüssel | Deutsch | English |
|---|---|---|---|---|
| Erster Start | Feld leer, Chips in fester Reihenfolge, nichts gewählt | | | |
| Ortung läuft | Aktivitätsanzeiger in Zeile 1, Chips bleiben bedienbar | | | |
| Standort nicht ermittelbar | `StatusRow(kind: sectionError)` | `offer_location_unavailable` | wie S11 | wie S11 |
| Standort abgelehnt | `StatusRow(kind: permission)` mit Aktion „Einstellungen“ | `offer_setup_location_off` | Standort ist aus. Gib deine Postleitzahl ein oder erlaube ihn in den Einstellungen. | Location is off. Enter your postcode or allow location in Settings. |
| Ungefährer Standort | Region erkannt, Chips ohne Entfernung, kein Hinweis | | | |
| Ungültige PLZ | Fehlerzeile wie S11 | | | |
| Offline | PLZ und Märkte gehen (lokale Tabelle), Entfernungen fehlen | | | |
| Übersprungen oder ohne Region | keine Ersparnis-Zahlen in der App; später der Hinweis „Postleitzahl festlegen“ | | | |

Die Chip-Reihe sortiert sich nach erkanntem Standort genau einmal um (`AvoMotion.standard`), und nur, solange noch kein
Chip gewählt ist. Keine Haptik.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_setup_region` | Region | Area |
| `offer_setup_location_sub` | Einmalig, um Region und Märkte in der Nähe zu finden. Gespeichert wird nur die Postleitzahl. | Used once to find your area and nearby stores. Only the postcode is saved. |
| `offer_setup_stores` | Deine Märkte | Your stores |
| `offer_setup_stores_note` | Wähl, wo du meistens einkaufst. Mehrere sind möglich. | Pick where you usually shop. You can choose more than one. |
| `offer_setup_source_note` | Angebote stammen aus Prospekten der Händler. Preise laut Händler, ohne Gewähr. | Offers come from retailer flyers. Prices as stated by the retailer, without guarantee. |
| `offer_setup_chip_distance` | {store} · {distance} | {store} · {distance} |
| `offer_setup_chip_a11y` | {store}, {distance} entfernt | {store}, {distance} away |
| `offer_setup_next` | Weiter | Continue |

**Barrierefreiheit.** Chips als Umschalter („Lidl, 400 Meter entfernt, ausgewählt“); Reihenfolge Region, Feld,
Ortszeile, Märkte, Fußnoten, Weiter. AX: Beschriftung über dem Feld ab AX1; bei 320/L zwei bis drei Chips pro Zeile,
ab AX3 ein Chip pro Zeile; `StoreMark` bis AX2.

**Daten.** `regionProvider`, Lieblingsmärkte (L4), Märkte in der Nähe mit Entfernung (`store_locator_service`, anderer
Workflow), PLZ-Tabelle (L10). Antworten liegen bis zum Konto im `OnboardingController` von A bzw. lokal und gehen danach
ins Konto. Datei `lib/presentation/widgets/deals/offers_setup_step.dart`.

**Avo.** Keine Figur im B-Inhalt.

---

### S15 `RecipeOffersCard` im Rezeptdetail und „Angebote für {Rezept}“ `/offers/recipe/:recipeId`

**Zweck.** Welche Zutaten dieses Rezepts sind bei meinem Markt im Angebot? Ersetzt die heutige Karte über alle Märkte
mit „Spare bis zu … gegenüber Normalpreisen“.

**Ort.** Slot `RecipeOffersCard({required Recipe recipe})` als letzte Zeile der Gruppe „Zutaten“ im Rezeptdetail (A,
Konzept 13 §11 `RecipeOfferSummary`). Ziel-Liste: die zuletzt in „Zutaten auf Liste“ für dieses Rezept gewählte, sonst
die Liste von heute; dafür braucht der Slot `listId` (Anfrage A-C6). Die Pillen an einzelnen Zutaten kommen über einen
zweiten Slot `IngredientOfferBadge(listId:, ingredient:)` (Konzept 13 E-06, Anfrage A-C6) und sehen aus wie S3.

**Aufbau der Zeile.** Zeile mindestens 52 in der weißen Gruppe: `tag` 17 `secondaryLabel`, Text 15/20 `label`
„3 Zutaten diese Woche bei Lidl im Angebot · für Wocheneinkauf, in deiner Region“, rechts `chevronRight`. Ganze Zeile
antippbar.

**Wann sie fehlt.** Bedingungen 3.1; Ziel-Liste ohne Markt (kein Hinweis „Markt wählen“ im Rezept, der gehört in die
Liste); keine Treffer; Treffer nicht schon beim Öffnen gecacht (nichts schiebt die Anleitung nach unten); Grundzutaten
(Salz, Pfeffer, Wasser, Öl, Zucker) zählen nie.

**Screen „Angebote für {Rezept}“ (V, `chevronBack`).**

1. Großer Titel „Angebote für Shakshuka“ (bricht um).
2. Satz 16/21: „3 von 9 Zutaten diese Woche bei Lidl im Angebot, für Wocheneinkauf, in deiner Region“. Keine Ersparnis:
   die Zutaten stehen noch nicht auf der Liste, eine Summe wäre geraten.
3. `SectionCaps` „Zutaten im Angebot“ + Gruppe mit `OfferRow` (voll): Titel Zutat und Menge für die gewählten Portionen
   („rote Paprika · 1“), Unterzeilen Produkt, Packung, Gültigkeit, „laut Händler statt …“, rechts Pille. Tippen öffnet
   S5 mit `mode=add` und `list=` der Ziel-Liste. Kein eigenes Plus: Zutaten kommen über „Zutaten auf Liste“ von A auf
   die Liste, dort hängen sich die Angebote des Listen-Markts an.
4. `OffersSourceFootnote`.

Zustände wie S9 (Skelett beim ersten Öffnen ohne Cache, offline mit Stand, Fehler mit „Erneut versuchen“, leer
`EmptyState(icon: tag)` mit `offer_list_empty_title`), Wächter 1.3.

| Schlüssel | Deutsch | English |
|---|---|---|
| `offer_recipe_row` | {n, plural, =1{1 Zutat} other{# Zutaten}} diese Woche bei {store} im Angebot · für {list}, in deiner Region | {n, plural, =1{1 ingredient} other{# ingredients}} on offer at {store} this week · for {list}, in your area |
| `offer_recipe_row_hint_a11y` | Zeigt die Angebote für dieses Rezept | Shows the offers for this recipe |
| `offer_recipe_title` | Angebote für {recipe} | Offers for {recipe} |
| `offer_recipe_sentence` | {matched} von {total} Zutaten diese Woche bei {store} im Angebot, für {list}, in deiner Region | {matched} of {total} ingredients on offer at {store} this week, for {list}, in your area |
| `offer_recipe_section` | Zutaten im Angebot | Ingredients on offer |

**Barrierefreiheit.** Zeile ein Knopf mit Label (Text oben) und Hinweis. AX: Text unbegrenzt, Chevron oben rechts.

**Daten.** `recipe_offers_provider.dart` (B) auf `recipe_offer_service.dart` (anderer Workflow; heute „billigster
Händler aller Märkte“, muss auf den Markt der Ziel-Liste eingeschränkt werden, L8), `storeForListProvider`,
`regionProvider`. Dateien `lib/presentation/screens/recipes/widgets/recipe_offers_card.dart` (anderer Workflow) und
`lib/presentation/screens/offers/recipe_offers_screen.dart`. Der Übergangs-Konstruktor `RecipeOffersCard(request:)`
entfällt, sobald A umgestellt hat.

---

### S16 Dialoge und Sonderseiten

**Modul ist aus.** `showModuleOffAlert(context, moduleName: 'Preise & Angebote', onEnable: …)` von A, zentrierter
Dialog vor jeder Route unter `/offers` und vor Avo-Aktionen mit Angeboten (dort stattdessen Ergebniszeile mit
„Einschalten“). „Einschalten“ ist der fette Standard-Knopf; danach öffnet das ursprüngliche Ziel. „Nicht jetzt“ bleibt,
wo man war (Kaltstart: Listen-Übersicht).

| Schlüssel | Deutsch | English |
|---|---|---|
| `common_module_off_title` (A) | Preise & Angebote ist ausgeschaltet | Prices & offers is turned off |
| `offer_module_off_body` (B, seit BAB1 vorhanden; A's `ModuleGate` reicht ihn als `showModuleOffAlert(body:)` durch, Anfrage an A) | Schalte es ein, dann siehst du an deinen Listen, was bei deinem Markt im Angebot ist. | Turn it on to see what's on offer at your store, right on your lists. |
| `common_not_now`, `common_module_turn_on` (A) | Nicht jetzt · Einschalten | Not now · Turn on |

**Kill-Switch.** Kein Dialog. Routen unter `/offers` zeigen die Fehlerseite von A mit `common_route_error_title` „Diese
Seite gibt es nicht mehr.“, `common_route_error_body` „Der Link ist vielleicht alt, oder der Inhalt wurde gelöscht.“
und `common_route_error_action` „Zur Startseite“. Kein Wort „Angebot“, kein Grün der Pille.

**Änderungen verwerfen?** Nur in S11, wenn eine gültige, nicht gesicherte Änderung offen ist und „Zurück“/„Schließen“
getippt oder vom Rand gewischt wird. Zentrierter Dialog von A (`confirm_dialog.dart`), Texte `common_discard_changes_title`,
`common_discard` (destruktiv), `common_keep_editing` (fett). Kein Aktionsblatt.

**Keine weiteren Dialoge.** „Region entfernen“, „ausblenden“, „Nicht dieses Angebot“, Marktwahl: Rückgängig statt
Rückfrage.

---

## 5. Konflikte zwischen D2 und Konzept, Owner-Fragen

| Nr. | Thema | D2 | Konzept | Empfehlung |
|---|---|---|---|---|
| K1 | Angebotsfarbe | grüne Pille `tint` auf `tintSoft` | gelbes Schild #FFD60A | D2. Die Kill-Switch-Prüfregel sucht statt Gelb die Pillen-Fläche `tintSoft` an Angebotsflächen und die Wörter „Angebot“, „gespart“, „laut Händler“ (EN „offer“, „saved“, „as stated by the retailer“) |
| K2 | Markt in der Pille | immer „0,99 € · Lidl“ (D2-Komponenten, D2-Liste mit Lidl und Rewe gemischt) | nur Preis; Markt nur als Punkt in Listen ohne Markt | Liste mit Markt: nur Preis (wie D2 `X-Einkaufsmodus`). Liste ohne Markt: „0,99 € · Lidl“ (D2-Schreibweise). `D2-Liste` ist so gelesen eine Liste ohne Markt, und „Rewe“ heißt nach Verzeichnis „REWE“ |
| K3 | Markenzeichen | Buchstaben-Kachel in Markenfarben | 8-pt-Punkt, Logos nur mit Erlaubnis | D2-Kachel (kein Logo, nur Buchstabe und Farbe); Rückfall bei Einwand einer Kette: Kachel in `fill` mit `label`-Buchstabe (Owner-Frage 1) |
| K4 | Markt-Chip | weiße Kapsel 30 mit Schatten | `fill`-Kapsel mit Punkt | D2, Trefferfläche 44 |
| K5 | Ersparnis-Zeile im Einkaufsmodus | Karte oben, zweizeilig | erscheint dort nicht; Satz in einer Zeile | D2 (Owner-Entscheidung zum Einkaufsmodus-Artboard). Beide Zeilen bestehen nur aus den Teilen des Pflicht-Satzes; VoiceOver liest den Satz am Stück (Owner-Frage 3) |
| K6 | Zählbasis im Einkaufsmodus | „4 von 11“ neben „5 von 11 erledigt“ | „von 11“ = offene Artikel | im Einkaufsmodus offene plus seit Start abgehakte Artikel (Owner-Frage 4) |
| K7 | Einstellungen | Schalter „Spar-Funktionen“, Sektion „In Listen“ mit 4 Schaltern inkl. Markt-Erkennung, Chips „Meine Märkte“, Region zuletzt, kurze Fußnote | Modul-Schalter „Preise & Angebote“, Region, Märkte (Kern), 5 Anzeige-Schalter, „Ausgeblendet für“, Datenquellen, volle Quellen-Fußnote | D2-Reihenfolge und Chips, Konzept-Inhalt: Schalter heißt wie das Modul („Preise & Angebote“, ein Name pro Sache), Sektion „Anzeigen“ mit 5 Schaltern, Markt-Erkennung unter „Meine Märkte“ (Kern, muss bei Modul aus bleiben), volle Quellen-Fußnote (Owner-Frage 2) |
| K8 | Angebotskarte im Artikel | „statt 1,49 € · gültig bis Samstag“, Link „Im Prospekt ansehen“ | „laut Händler statt“, kein Prospekt-Link ohne Lizenz | Karte nach D2, Wortlaut „laut Händler statt 1,49 € · bis Sa., 14. Nov.“, Link „Angebot ansehen“ auf S5; Produktzeile ergänzt (Owner-Frage 6) |
| K9 | Sheets | (D2 zeigt keine) | Markt, Angebot, Angebote bei Lidl, Region, Vorab-Erklärung, Modul-aus als Sheets | Vollbild-Screens (S2, S5, S9, S11), Pull-down-Menüs (S1, „Auf welche Liste?“), zentrierte Dialoge (S16); Standort-Erklärung als Unterzeile am Auslöser statt zweitem Sheet (Owner-Frage 12) |
| K10 | Bilder an Angeboten | echte Produktfotos überall | Kategorie-Symbol, nie Händlerbild | Kategorie-Symbol bzw. B4-Illustration der Kategorie; kein OFF-Foto für Angebote (die Zuordnung Angebot → Produkt ist zu unsicher) |
| K11 | Modulname | X-Onboarding „Angebote & Sparen“, X-Profil „Angebote“ | „Preise & Angebote“ | überall `common_module_offers` „Preise & Angebote“ (A) |
| K12 | Fehlerseite bei Kill-Switch | | Knopf „Zur Liste“ | Fehlerseite von A unverändert („Zur Startseite“), damit es eine Fehlerseite gibt |
| K13 | Home-Texte | „Lidl lohnt sich diese Woche … du sparst ca. 2,40 €“, „Angebote in der Nähe“, Chip „Wo ist es günstiger?“ | kein Marktvergleich, „in deiner Region“, „ca. … gespart“ | gehört in die Home-Spec; die Kachel heißt „Angebote in deiner Region“, der Spar-Hinweis nutzt `OfferSummaryText` |

### Owner-Fragen aus diesem Bereich

| Nr. | Frage | Vorschlag |
|---|---|---|
| 1 | Dürfen Buchstaben-Kacheln in Markenfarben ohne Erlaubnis der Ketten erscheinen? | ja, sie sind kein Logo; bei Einwand Kachel in Grau |
| 2 | Hauptschalter in „Preise & Angebote“: Name „Preise & Angebote“ (Modulname) statt D2 „Spar-Funktionen“? | ja |
| 3 | Ersparnis-Karte im Einkaufsmodus (D2) trotz Konzept „nicht im Einkaufsmodus“? | ja, still und ohne Tippen |
| 4 | Zählbasis im Einkaufsmodus: offene plus seit Start abgehakte Artikel? | ja |
| 5 | Name der Quelle in der Fußnote bis zur Lizenz (F12-1) | „Händlerprospekte“ |
| 6 | Link „Im Prospekt ansehen“ (D2-Artikel) nur mit Lizenz? | ja; bis dahin „Angebot ansehen“ (S5) |
| 7 | Listen ohne Markt: Angebote der Lieblingsmärkte in deren Reihenfolge (K12-03) statt „alle Märkte der Region“? | ja |
| 8 | Freie Suche in Angebote der Woche zeigt Treffer mehrerer Märkte untereinander (nach Markt gruppiert, nie nach Preis). Ist das in Ordnung (F12-10)? | ja |
| 9 | Zählt eine UVP als „statt“-Preis? | nein (keine Angabe des Händlers) |
| 10 | Text der Standort-Abfrage (Info.plist `NSLocationWhenInUseUsageDescription`) | „Avo nutzt deinen Standort, um deine Postleitzahl für Angebote zu finden und den Markt vorzuschlagen, in dem du gerade bist.“ / “Avo uses your location to find your postcode for offers and to suggest the store you're in.” |
| 11 | Quelle und Lizenz der PLZ-Tabelle (PLZ → Ort, offline) | offene Daten mit Namensnennung, Quelle in „Datenquellen“ |
| 12 | Standort-Erklärung als Unterzeile am Auslöser (wie Onboarding) statt eigenem Vorab-Screen? | ja; ein Tipp weniger, gleiche Information vor der Systemabfrage |
| 13 | „Angebote in der Nähe“-Kachel und Home-Texte (K13) | Wortlaut „in deiner Region“, kein Marktvergleich |
| 14 | `user_offer_prefs` als Migration (Schalter, Lieblingsmärkte, Region, ausgeblendete Listen, Wegwisch-Zustände pro Konto, Regel 15) | ja, nach Einzel-Ja anwenden |

---

## 6. Anfragen an Teil A

Komponenten fehlen im D2-Blatt oder brauchen eine Variante:

| Nr. | Anfrage |
|---|---|
| A-C1 | `ItemRow` (S2b): Semantik des rechten Slots in das Zeilen-Label einbinden (inkl. eigener Aktionen wie „Angebot ansehen“), Einträge für das Kontextmenü aus dem Slot, Slot rückt ab AX1 unter den Namen neben die Menge, Tipp auf den Slot erreicht den Slot (Pille) und nicht die Zeile |
| A-C2 | `AppFilterChip`: Platz `leading` (für `StoreMark`) und eine sekundäre Unterbeschriftung („· 400 m“); `ChipRow` mit erzwungenem Umbruch (S12, S14) |
| A-C3 | `HintRow`: optionaler fetter `title` plus `text` (zweizeilige Ersparnis-Karte), Wisch-Aktion und Kontextmenü; Slot `ListOfferSummary(listId:, shoppingMode:)` oder ein Provider „Einkaufsmodus aktiv für Liste“ |
| A-C4 | `AddItemAccessory` (S2b): B-Block am oberen Ende des Vorschlags-Panels (E-17), höchstens 5 Zeilen mit internem Scrollen, Fokus zurück ins Feld nach Rückkehr von einer V-Route |
| A-C5 | Textfeld-Zeile für Gruppen: Beschriftung links, Feld rechtsbündig, Tastatur-Typ, Autofill, Fehler-/Hinweiszeile darunter, ab AX1 gestapelt |
| A-C6 | Rezept-Slots nach Konzept 13 E-06: `RecipeOffersCard(recipe:, listId:)` und `IngredientOfferBadge(listId:, ingredient:)` an Zutatenzeilen und in „Zutaten auf Liste“ |
| A-C7 | `showModuleOffAlert` mit optionalem `body:` für den Nutzen-Satz des Moduls |
| A-C8 | Pull-down-Menü (S2b `AvoMenuButton`/`showAvoMenu`): Titelzeile ohne Aktion, Sektionen mit Trennern, Häkchen vorn, Unterzeile pro Eintrag, Glyph vorn, internes Scrollen, Ursprung am Auslöser (auch an einem Knopf unten) |
| A-C9 | Auswahl-Kreis `SelectCircle` (E-08) und sortierbare Zeilen in `InsetSection` mit Zieh-Griff 44 und VoiceOver-Aktionen |
| A-C10 | `AvoIcons`: `location`, `storefront`, `eyeSlash`, `plusCircle`, `questionmarkCircle`, `exclamationmarkCircle`, `exclamationmarkTriangleFill`, `line3Horizontal` (Zieh-Griff), `checkmarkCircleFill` |

Tokens:

| Nr. | Anfrage |
|---|---|
| A-T1 | Token `warning` (hell #A8521A, 5,40:1; dunkel und Kontrast erhöht abgeleitet) für Warn-Symbole mit Text |
| A-T2 | `ContentGlass` für Text-Pillen auf Fotos mit mindestens 92 % Deckkraft (heute 78 %: 3,18:1 im schlechtesten Fall) |
| A-T3 | getöntes Glas mit Text auf hellem Grund 96 % (4,99:1 statt 4,25:1), wie in `kalorien.md` angefragt |

Routen, Listen, Profil, Onboarding, Daten, Tests:

| Nr. | Anfrage |
|---|---|
| A-R1 | `offersRootRoutes` vor der Shell einhängen (`/offers/offer/:offerId`, `/offers/recipe/:recipeId`, `/stores/pick`, `/stores/region`) und die Pfade in `RoutePaths` aufnehmen; Test: `/offers/offer/x` aus dem Rezepte-Tab öffnen und schließen, der Rezepte-Tab ist wieder sichtbar |
| A-R2 | Modul-Wächter mit der Tabelle aus 1.3: `/offers*` → Kill-Switch Fehlerseite, Modul aus Dialog und danach das Ziel; `/stores/*` und `/settings/offers*` ohne Wächter |
| A-R3 | Deep-Link-Übersetzung für `shoply://offers`, `?filter=regulars`, `?q=` |
| A-L1 | Listenkopf: `StoreChip` in der Metazeile (fehlt in `D2-Liste`); Listen-Info: Zeile „Markt“ (öffnet S2) und `ToggleRow` „Angebote anzeigen“; Listenmenü: „Angebote dieser Liste“ (`/offers/list/:id`) und „Angebote für diese Liste ausblenden“, beide nur mit `offersAvailableProvider`; `ListOfferSummary` nach der letzten offenen Kategorie vor „Erledigt“ und im Einkaufsmodus unter dem Kopf |
| A-L2 | Listenkarte: Platz für `ListOfferCountBadge` in der Metazeile, wenn das Cover ab AX1 fehlt |
| A-L3 | „Neue Liste“ mit vorausgewähltem Markt und Rückgabe der neuen Listen-ID (für „Neue Liste …“ im Menü „Auf welche Liste?“) |
| A-L4 | Provider „Liste von heute“ für die Reihenfolge im Menü und die Ziel-Liste im Rezept |
| A-P1 | Profil-Zeile „Preise & Angebote · Lidl, REWE“, bei Kill-Switch „Märkte · Lidl, REWE“; Modul-Schalter in Profil und Onboarding fehlen bei Kill-Switch; Einstellungs-Suche mit den Suchwörtern aus S12 |
| A-O1 | `OffersSetupStep`: B zeichnet den Inhalt und den Knopf „Weiter“ und ruft `onDone`; A zeichnet Rahmen, Titel, Satz und „Überspringen“. Bitte bestätigen oder anders festlegen |
| A-D1 | `ItemRepository`: Angebotspreis an einen Artikel hängen und entfernen (Preis, Währung, Händler als Ketten-ID, Einheit, Vergleichspreis, Datum), `NewItem` mit diesen Feldern; über Warteschlange und Rückgängig wie alle Schreibwege |
| A-Q1 | `owner.sh` ordnet `test/layout/*` A zu. B legt seine Layout-Tests unter `test/screens/offers/*_layout_test.dart` mit `layoutMatrix` an, außer A gibt `test/layout/screens/b/` frei; dazu ein Lauf der Prüfmatrix mit Kill-Switch (E-15) |

---

## 7. Datenquellen und Lücken

| Was | Quelle | Stand |
|---|---|---|
| Modul und Kill-Switch | `moduleEnabledProvider(AppModule.offers)`, `offersRemoteEnabledProvider`, `offersAvailableProvider` (`app_flags_provider.dart`) | vorhanden |
| Markt der Liste | `storeForListProvider` (bestätigt), `storeGuessForListProvider` (Vorschlag mit Quelle), `listStoreRepositoryProvider` (`list_store_assignments_b`) | vorhanden |
| Ketten-Verzeichnis | `store_chain_directory.dart` (13 Ketten, Aliase, Tippfehler, Handelsmarken, Markenfarben) | vorhanden |
| Angebote pro Liste ausblenden | `offersHiddenForListProvider`, `offersVisibleForListProvider`, `setOffersHiddenForList` | vorhanden, nur auf dem Gerät (L4) |
| Märkte in der Nähe | `store_locator_service.dart`, `nearbyStoresProvider` | vorhanden; heute nur `node`, 8 km |
| Listen, Artikel, Schreiben | `listsNotifierProvider`, `itemsNotifierProvider`, `ItemRepository.addItems/undoAddItems` (A5) | teils vorhanden (A-D1) |
| Mengen-Parser | `parseSingleItem` (A) | vorhanden |
| Rezept-Angebote | `recipe_offers_provider.dart` auf `recipe_offer_service.dart` | vorhanden, zeigt heute alle Märkte (L8) |

Lücken:

- **L1** `listOffersProvider(listId)`: Angebots-Cache pro Liste (nur Markt der Liste, höchstens alle 6 h, LRU 200,
  synchron lesbar für den ersten Frame), Grundlage für S3, S4, S7, S8, S9. Fehlt.
- **L2** Angebotssuche mit Status `ok | leer | fehler` und ein Angebots-Cache nach `offerId` (S5 öffnet nur aus dem
  Cache). `offer_price_service.dart` gehört gerade dem parallelen Workflow.
- **L3** `offerSurfaceVisibleProvider(surface, listId)` mit allen Bedingungen aus 3.1. Fehlt.
- **L4** `offerPrefsProvider` pro Konto: fünf Einzel-Schalter, Lieblingsmärkte mit Reihenfolge, Markt-Erkennung,
  ausgeblendete Listen, Region. Braucht die Migration `user_offer_prefs` (nur nach Einzel-Ja des Owners); heute liegt
  `hiddenOfferListsProvider` nur auf dem Gerät.
- **L5** `regionProvider` (B2.1) und `offer_savings.dart` mit `OfferSummaryText` (B2.2). Fehlen; ohne sie zeigen alle
  Flächen nichts (sicherer Standard).
- **L6** Wegwisch- und Schlummer-Zustände pro Konto: Hinweis „Postleitzahl festlegen“ (7 Tage), Ersparnis-Zeile diese
  Woche, „Nicht dieses Angebot“ pro Artikel bis Ablauf, „Nicht interessiert“ bis Ablauf (höchstens 7 Tage).
- **L7** Märkte aus dem Verlauf einer Liste (Ketten-IDs vergangener Einkäufe) für das Menü in S1 und „Deine Märkte“ in
  S2. Braucht `shopping_history.store_chain` (Modell gehört dem parallelen Workflow).
- **L8** Stammartikel im Angebot („Oft gekauft“) und Rezept-Angebote nur für einen Markt: `personalized_deals_service`,
  `avo_nudge_service`, `recipe_offer_service` gehören dem parallelen Workflow; Sortierung nach Listen-Reihenfolge statt
  Rabatt, kein Marktwechsel wegen Preis.
- **L9** „Liste von heute“ (A, A-L4).
- **L10** PLZ-Tabelle (PLZ → Ort, lokal, offline): Quelle und Lizenz offen (Owner-Frage 11); ohne sie zeigt S11 nur
  „PLZ 79098“.
- **L11** Grundpreis, Einheit und Packungsgröße stehen weder am Artikel noch im Verlauf; Regel 5 rechnet deshalb aus dem
  Angebots-Cache (Liste) und ist im Verlauf nicht nachrechenbar (Verlauf-Spec).
- **L12** Text der Seite „Datenquellen“ ohne Angebotsquelle bei Kill-Switch, Datenschutzerklärung (Suchbegriffe, PLZ,
  Koordinaten): Owner und OPEN-ISSUES.
- **L13** `connectionStateProvider` (Kap. 20) für das Offline-Signal nach 1 s; bis dahin gilt „offline“ erst nach einer
  gescheiterten Anfrage.
- **L14** Besitz: Alle Slot-Dateien dieses Bereichs (`lists/widgets/{store_chip,item_offer_badge,item_offer_card,
  list_offer_summary,list_offer_count_badge,offer_suggestions_bar}.dart`, `widgets/deals/offers_setup_step.dart`,
  `recipes/widgets/recipe_offers_card.dart`), die Provider (`store_for_list_provider`, `list_offer_prefs_provider`,
  `region_provider`, `price_comparison_provider`) und `translations/offers.dart` gehören gerade dem parallel laufenden
  Workflow. Gebaut wird erst, wenn er abgeschlossen ist. Neue Dateien unter `lib/presentation/screens/offers/` und
  `offers_settings_screen.dart` gehören B.

---

## 8. Prüfliste für Screenshots

Jeder Punkt muss auf einem Screenshot sichtbar erfüllt sein (Simulator 390 × 844, hell, Textgröße L, wenn nicht anders
genannt). Zusätzlich je Screen: 320 × 568 bei L und AX3, 440 × 956 bei AX5, dunkel, fett.

**Überall**
- [ ] Kein Gelb, kein „−X %“, kein „Spare …“, kein „günstigster“, keine Korbsumme, kein Vergleich zwischen Märkten.
- [ ] Jede Ersparnis mit „ca.“, jeder „statt“-Preis mit „laut Händler“, jede Angebotsaussage mit „in deiner Region“.
- [ ] Keine Händler- oder Prospektbilder; Angebote zeigen das Kategorie-Symbol.
- [ ] Kein `ProBadge`, keine Paywall an einer Angebotsfläche.
- [ ] Keine Avo-Figur außer bei „Suche ohne Treffer“ in S10.
- [ ] Kein Sheet, kein halbhohes Panel, kein Schieberegler; Menüs wachsen aus ihrem Auslöser.
- [ ] Kein abgeschnittener Text bei 320 pt und AX5; keine Ellipse außer im Inline-Titel.
- [ ] Destruktiver Text in #D70015, nie #FF3B30; Schalter-Spur grün `tintFill`, nicht #34C759.
- [ ] Kein Ausrufezeichen, kein Emoji, kein englischer Rohfehler.

**Kill-Switch aus (offers_enabled = false)**
- [ ] Liste, Einkaufsmodus, Artikel, Rezept, Listen-Übersicht: keine Pille, keine Karte, keine Ersparnis, kein Zähler,
      kein Hinweis, keine Menüeinträge zu Angeboten; Markt-Chip unverändert.
- [ ] Einstellungen heißen „Märkte“: Meine Märkte, Markt automatisch erkennen, Standort; keine Quellen-Fußnote.
- [ ] `/offers` zeigt die Fehlerseite von A ohne das Wort „Angebot“.
- [ ] In keinem Screenshot steht „Angebot“, „gespart“ oder „laut Händler“.

**Modul aus**
- [ ] Gleiche Flächen verschwinden ohne Lücke; `/offers` zeigt den zentrierten Dialog „Preise & Angebote ist
      ausgeschaltet“ mit „Nicht jetzt“ und fettem „Einschalten“.
- [ ] S12 zeigt Hauptschalter aus, Meine Märkte, Region, Datenquellen; „Anzeigen“ und „Ausgeblendet für“ fehlen.

**Ohne Region**
- [ ] Liste: Hinweis „Für Angebote in deiner Region: Postleitzahl festlegen“ mit „Festlegen“, keine Zahl.
- [ ] S10: Leerzustand „Wo kaufst du ein?“ ohne Suche, Segment und Chips, ohne Figur.

**S1 Markt-Chip**
- [ ] Weiße Kapsel mit Kachel, Name, Chevron; vorgeschlagen „Lidl?“ mit Strichrand; ohne Markt „Markt wählen“.
- [ ] Menü aus dem Chip: Lieblingsmärkte mit Häkchen am aktuellen, Trenner, „Anderer Markt …“, „Kein fester Markt“.
- [ ] Nach Wahl: Rückgängig-Hinweis „Markt: REWE · Widerrufen“ über der Tab-Leiste.
- [ ] AX1: Chip in eigener Zeile; 320/L: Chip und Metazeile umbrochen.

**S2 Markt wählen**
- [ ] Keine Tab-Leiste, `xmark` links, Titel „Markt“, Suchfeld, Sektionen „Deine Märkte“ (Häkchen), „In der Nähe“
      (Straße · Entfernung), „Alle Märkte“, Zeile „Kein fester Markt“.
- [ ] Ohne Standort fehlt „In der Nähe“ ohne Lücke und ohne Frage.
- [ ] Suche ohne Treffer: Satz und „„Bio Kaiser“ als eigenen Markt verwenden“.

**S3/S4 Pille und Angebotskarte**
- [ ] Liste mit Markt: Pille nur mit Preis; Liste ohne Markt: „0,99 € · Lidl“; unsicher mit Fragezeichen.
- [ ] Einkaufsmodus: Pille ohne eigenen Tipp.
- [ ] Artikel-Vollbild: grüne Karte mit „ANGEBOT“, „Lidl · 0,99 €“, Produktzeile, „laut Händler statt 1,49 € · bis
      Sa., 14. Nov.“, Link „Angebot ansehen“ (44 hoch).
- [ ] AX1: Pille unter dem Namen neben der Menge.

**S5 Angebot**
- [ ] Kopf mit Kategorie-Kachel (bis L), Produktname groß, „Lidl · 1 l“; großer Preis in grüner Kapsel.
- [ ] Werte „laut Händler statt“, „Grundpreis“, „Gültig“, „Markt“, „Region“; fehlende Daten ohne leere Zeile.
- [ ] Unsicher: Hinweis „Ähnliches Produkt. Prüf vor dem Kauf …“.
- [ ] Unten eine getönte Kapsel „Preis übernehmen“ bzw. „Auf die Liste“; abgelaufen deaktiviert „Angebot abgelaufen“.
- [ ] Quellen-Fußnote vollständig; ab AX3 Hauptaktion am Ende des Inhalts.

**S6 Angebote beim Tippen**
- [ ] Höchstens 3 Zeilen am oberen Ende des Panels, ohne Kopf; Vorschau direkt über dem Feld bleibt stehen.
- [ ] Nach Tipp: Artikel heißt wie getippt („Milch“), nicht wie das Produkt.

**S7 Ersparnis-Zeile**
- [ ] Liste: weiße Karte, „4 von 11 Artikeln diese Woche bei Lidl im Angebot“ fett, „ca. 3,20 € gespart · in deiner
      Region · Preise laut Händler“, Chevron, Schließen.
- [ ] Unter 0,50 €: zweite Zeile ohne Ersparnis.
- [ ] Einkaufsmodus: dieselbe Karte ohne Chevron und Schließen.

**S8 Zähler**
- [ ] Glas-Pille „2 Angebote“ oben links auf dem Cover, grüne Schrift lesbar auf hellem und dunklem Foto.

**S9 Angebote bei Lidl**
- [ ] Großer Titel, Pflicht-Satz, „AUF DEINER LISTE 4“, Zeilen in Listen-Reihenfolge mit „laut Händler statt …“.
- [ ] „Diese Woche bei Lidl, oft gekauft“ mit Plus (44), „Alle Angebote der Woche“, „Angebote für diese Liste
      ausblenden“ in Grün mit Auge, nicht rot.
- [ ] Fußnoten „Gespart ist …“ und Quelle; Leerzustand ohne Figur.

**S10 Angebote der Woche**
- [ ] Großer Titel, „In deiner Region · 79098 Freiburg“, Suchfeld, Segment „Deine Listen | Oft gekauft“, Markt-Chips
      mit Kachel, keiner gewählt.
- [ ] Sektionen „WOCHENEINKAUF · LIDL 4“; Zeilen mit „Für „Milch“ auf Wocheneinkauf“; keine Sortierung nach Preis.
- [ ] Menü „Auf welche Liste?“ aus dem Plus mit „Lidl · Angebot gilt dort nicht“ und „Neue Liste …“, ohne Häkchen.
- [ ] Suche ohne Treffer: Avo „überlegt“ 96 pt und „Kein Angebot für „Hummus“ in deiner Region.“; AX1 ohne Figur.
- [ ] Erstes Laden: ruhiges Skelett, kein Spinner.

**S11 Region**
- [ ] Satz zur Region, „Standort verwenden“ mit Erklärung, Feld „Postleitzahl“, Ortszeile „79098 · Freiburg im
      Breisgau“, „Region entfernen“ in #D70015, „Fertig“ getönt oben rechts.
- [ ] Fehler „Diese Postleitzahl kennen wir nicht.“ mit Symbol in Rot, „Fertig“ gedimmt.
- [ ] Standort abgelehnt: Statuszeile „Standort ist aus. In Einstellungen erlauben“.
- [ ] Kill-Switch: Titel „Standort“, kein Wort „Angebot“.

**S12 Preise & Angebote**
- [ ] Großer Titel, Hauptschalter „Preise & Angebote“ mit Unterzeile, Quellen-Fußnote; „ANZEIGEN“ mit fünf Schaltern;
      „MEINE MÄRKTE“ mit Chips und „+ Markt“, darunter „Markt automatisch erkennen“; „Region · 79098 Freiburg“;
      „Datenquellen“.
- [ ] Ohne Region: „Nicht festgelegt“ mit Warn-Symbol in dunklem Orange (#A8521A), nicht #FF9500.
- [ ] Ausgeblendete Liste mit „Einblenden“.

**S13 Lieblingsmärkte**
- [ ] „DEINE MÄRKTE“ mit Häkchen-Kreis, Kachel, Name, Zieh-Griff; „WEITERE MÄRKTE“ alphabetisch; Fußnote.
- [ ] Beim Ziehen folgt die Zeile dem Finger, Nachbarn weichen aus (Video-Prüfung).

**S14 Onboarding**
- [ ] Region-Gruppe mit „Standort verwenden“ und Feld, Ortszeile; Chips in weißer Gruppe, gewählte mit Häkchen,
      Entfernungen; Fußnoten; „Weiter“.
- [ ] Kill-Switch: Schritt fehlt.

**S15 Rezept**
- [ ] Letzte Zeile der Zutaten „3 Zutaten diese Woche bei Lidl im Angebot · für Wocheneinkauf, in deiner Region“ mit
      Chevron; ohne Markt der Ziel-Liste keine Zeile und kein Hinweis.
- [ ] „Angebote für Shakshuka“ ohne Ersparnis-Summe.

**Barrierefreiheit (VoiceOver-Aufnahme)**
- [ ] Artikelzeile liest „…, im Angebot 0,99 Euro laut Händler“ mit Aktion „Angebot ansehen“.
- [ ] Ersparnis-Karte liest den Pflicht-Satz am Stück.
- [ ] Markt-Chip liest „Markt: Lidl, ändern“; Abschnittsköpfe als Überschriften in normaler Schreibung.
- [ ] Rückgängig-Hinweis steht 10 s und ist erreichbar.
- [ ] Reduce Motion: nur Überblendungen; Transparenz reduzieren: Zähler-Pille und Toolbar deckend mit Kontur.
