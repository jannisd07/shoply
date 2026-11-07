# Inventar: Verlauf, Kosten teilen, Angebote der Woche (Ist-Zustand, Stand 2026-11-07)

Grundlage für das Redesign. Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf `main` (3e886d0).

Kurzfassung: Der Bereich besteht aus drei Oberflächen, die alle nur per `Navigator.push` (ohne GoRouter-Route, ohne Deep Link) von der Startseite erreichbar sind: der Verlauf ("Aktivitäten", Paper-Stil mit Kickern und Georgia-Serifen), das Sheet "Kosten teilen" und der Screen "Angebote der Woche". Dazu kommen zwei Startseiten-Karten (offene Aufteilungen, "Einkauf teilen?"). Die Datenlogik ist solide und getestet: Spar-Summen nur aus echten Händler-Streichpreisen, Cent-genaues Aufteilen, Insert-vor-Delete beim Neu-Aufteilen, gebündelte Abfragen. Die Oberfläche hat viele Material-Reste, winzige Touch-Ziele (unter 30 pt), feste Breiten, die bei 320 pt brechen, und mehrere echte Datenfehler: "Bearbeiten" einer Aufteilung setzt bezahlte Anteile zurück, der Verlauf aktualisiert sich nach einem Einkauf nicht, und Offline-Fehler bei Angeboten erscheinen als "keine Angebote".

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/history/shopping_history_screen.dart` | Verlauf-Screen "Dein {Monat}.": Monatszahlen, Ersparnis, Wochentags-Diagramm, aufklappbare Einkaufszeilen mit Artikeln, Ersparnis pro Einkauf und Kosten-Aufteilung (`_SplitSection`, `_SplitParticipantRow`) | 712 |
| `lib/presentation/screens/history/widgets/split_cost_sheet.dart` | `showSplitCostSheet()` + `_SplitCostSheet`: Gesamtbetrag, Teilnehmer (Listen-Mitglieder + Namen), gleich/individuell, Zahler, Speichern | 448 |
| `lib/presentation/screens/home/weekly_deals_screen.dart` | "Angebote der Woche": Suchfeld, PLZ-Hinweis, "Passend zu deinen Listen", Angebotskarten, Sheet "Zur Einkaufsliste hinzufügen" (`_AddDealSheet`) | 625 |
| `lib/presentation/screens/home/widgets/pending_splits_banner.dart` | Startseiten-Karte: "X schuldet dir", "Du schuldest X" mit Schnellaktion | 159 |
| `lib/presentation/screens/home/widgets/split_trip_nudge_card.dart` | Startseiten-Karte "„{Liste}“ mit deiner Gruppe teilen?" öffnet das Teilen-Sheet | 58 |
| `lib/data/services/expense_split_service.dart` | Aufteilen speichern (Insert vor Delete), bezahlt umschalten + Push an Gegenseite, "schuldet mir" / "ich schulde", Kandidat für Teilen-Karte | 347 |
| `lib/data/services/shopping_history_service.dart` | Einkauf abschließen (History + Items + Preis-Schnappschuss + Start-Gesamtsumme), Verlauf laden (eigene + Mitglieds-Listen), löschen | 149 |
| `lib/data/services/purchase_tracking_service.dart` | `item_purchase_stats` fortschreiben (Anzahl, Daten, Intervall, bevorzugter Markt via `mergeRetailer`), Häufig-Artikel | 257 |
| `lib/data/services/personalized_deals_service.dart` | Kandidaten-Namen aus offenen Listen-Artikeln (max. 10), Abgleich mit Angeboten, Sortierung nach Rabatt-% | 60 |
| `lib/data/services/split_nudge_cache_service.dart` | SharedPreferences: zuletzt weggewischte Teilen-Karte (eine ID) | 37 |
| `lib/data/models/shopping_history.dart` | `ShoppingHistory`, `ShoppingHistoryItem` (`savingsPerUnit`), `totalSavingsOf`, `tripsInMonth` | 201 |
| `lib/data/models/expense_split.dart` | `ExpenseSplit`, `TripSplitSummary` | 136 |
| `lib/presentation/state/shopping_history_provider.dart` | `shoppingHistoryProvider`, `recentHistoryProvider` (5), `shoppingHistoryNotifierProvider` (StateNotifier, nicht autoDispose) | 102 |
| `lib/presentation/state/expense_split_provider.dart` | `tripSplitsProvider(historyId)`, `splitCandidateMembersProvider(listId)`, `tripsAwaitingPaymentToMeProvider`, `tripsIOweProvider`, `unsplitTripNudgeProvider` | 59 |
| `lib/presentation/providers/price_comparison_provider.dart` (geteilt) | `userZipCodeProvider`, `effectiveZipProvider`, `offerSearchAllProvider(query)`, `personalizedDealsProvider` (Z. 299-317, max. 2 Listen) | 362 |
| `lib/data/services/offer_price_service.dart` (geteilt) | marktguru-Suche, 30-min-Cache, In-flight-Teilen, 250-ms-Drossel, Fallback-Keys (Z. 26-28) | 343 |
| `lib/data/services/recipe_offer_service.dart` (geteilt) | `matchOffers`, `pickBestOffer`, `isRelevantMatch` (Relevanzregel) | 227 |
| `lib/presentation/screens/lists/shopping_trip_completion.dart` (geteilt) | Einstieg "Einkauf abschließen": Markt erkennen, History schreiben, Snackbar mit Aktion "Kosten teilen" | ca. 250 |
| `supabase/migrations/20260702055031_pricing_and_cost_splitting.sql` | Schema `expense_splits` + RLS, Spalten `total_cost`, `paid_by_*` | ca. 100 |
| `supabase/migrations/20260727000000_price_old_value_savings_tracking.sql` | Spalte `price_old_value` für Spar-Tracking | – |
| Tests | `test/savings_tracking_logic_test.dart`, `purchase_retailer_test.dart`, `personalized_deals_logic_test.dart`, `avo_personalized_deals_logic_test.dart`, `avo_nutrition_challenges_savings_tools_test.dart` | – |

Hinweis: `lib/presentation/widgets/deals/` existiert nicht (mehr). Alle Angebots-Widgets dieses Bereichs liegen privat in `weekly_deals_screen.dart`.

---

## 2. Screens, Sheets und Dialoge

### 2.1 Verlauf ("Aktivitäten") – `ShoppingHistoryScreen`

- **Datei:** `lib/presentation/screens/history/shopping_history_screen.dart`
- **Einstieg:** Startseite, Verlaufszeile unten (`home_screen.dart:578-590`, `Navigator.push` + `MaterialPageRoute`); Tippen auf eine Zeile der Karte "Offene Aufteilungen" (`pending_splits_banner.dart:93-97`). Keine GoRouter-Route, kein Deep Link, kein Push-Ziel.
- **Hauptfrage:** "Was habe ich eingekauft, und was ist mit dem Geld (gespart, geteilt, offen)?" Heute vermischt der Screen drei Fragen: Monatsrückblick, Einkaufsarchiv, Schulden.
- **Aufbau von oben nach unten:**
  1. Material-`AppBar` transparent, nur Pfeil `Icons.arrow_back` links, kein Titel (Z. 61-69).
  2. Kicker "AKTIVITÄTEN" (11 pt, Laufweite 2, Großbuchstaben, Z. 139-147).
  3. Serif-Überschrift "Dein November." (Georgia 28, Z. 149-155).
  4. Kennzahlen-Reihe aus drei `_Stat` (Serif-Zahl 26 + 11-pt-Label in fester Breite 82): "Artikel gekauft" (Monat), "Einkäufe" (Monat), "Verlauf" (alle Einträge, Lebenszeit) (Z. 159-177, 331-363).
  5. Nur wenn Ersparnis > 0,01: Sparschwein-Icon + "Du hast X € durch Angebote gespart." (Akzentfarbe) und darunter Monatszeile mit Vergleich zum Vormonat (Z. 179-220).
  6. Nur wenn Einkäufe vorhanden: Wochentags-Balkendiagramm (7 Balken, feste Höhe 90, stärkster Tag in Akzentfarbe), Tageskürzel (10 pt), Satz "Samstag ist dein Einkaufstag." (Z. 222-285).
  7. Kicker "VERLAUF" (Z. 288-296).
  8. Liste aller Einkäufe als `_HistoryRow`: Listenname (Serif 17), "Heute/Gestern/3. Nov. · 12 Artikel", Chevron. Antippen klappt auf: Artikel mit Punkt + Menge/Einheit, "Du hast X € bei diesem Einkauf gespart.", `_SplitSection` (Z. 365-508).
  9. `_SplitSection` (aufgeklappt): ohne `totalCost` nur Link "Kosten teilen"; mit `totalCost`: "Gesamtkosten: X €" + "Bearbeiten", "Bezahlt von: Name", je Anteil eine Zeile mit Name, Kopier-Icon (Erinnerung), Betrag, Pille "Bezahlt/Offen" zum Umschalten (Z. 510-712).
- **Komponenten:** `Scaffold`, Material-`AppBar`, `SingleChildScrollView` + `Column` (alle Zeilen auf einmal gebaut), `GestureDetector`, Material-Icons (`savings_outlined`, `call_split_rounded`, `copy_rounded`, `chevron_right`, `keyboard_arrow_down`), `Tooltip`, `CircularProgressIndicator`, `CupertinoActivityIndicator`, `confirmDestructive` (AdaptiveAlertDialog mit SF-Symbol `trash.fill`), Material-`SnackBar`.
- **Zustände:**
  - Laden: zentrierter `CupertinoActivityIndicator` für den ganzen Screen (Z. 71).
  - Fehler: zentrierter Text "loading_error", kein Erneut-Versuchen, kein Pull-to-Refresh (Z. 72).
  - Leer: Kennzahlen zeigen 0, Diagramm entfällt, unter "VERLAUF" der Text "Kein Einkaufsverlauf" (Z. 299-306). Kein Erklärtext, wie Einträge entstehen.
  - Offline: wie Fehler. Kein lokaler Cache.
  - Aufteilung lädt: 14-pt-Material-Spinner in der Zeile (Z. 585-594); Fehler: Anteile verschwinden still (Z. 595).
  - Pro gesperrt / Modul aus: gibt es nicht. Verlauf und Kosten teilen sind immer an.
- **Aktionen und Gesten:** Tippen auf Zeile = auf-/zuklappen (Haptik `selectionClick`). Langes Drücken = Löschen mit Bestätigungsdialog (Haptik `mediumImpact`, Z. 29-49, 400). "Kosten teilen"/"Bearbeiten" öffnet Sheet. Kopier-Icon kopiert Zahlungserinnerung in die Zwischenablage + Snackbar. Pille schaltet bezahlt/offen (Haptik `lightImpact`), danach Invalidierung von drei Providern. Zurück-Pfeil.
- **Datenquellen:** `shoppingHistoryNotifierProvider` (lädt einmal bei Login, `ShoppingHistoryService.getShoppingHistory()` = alle eigenen Einkäufe + alle Einkäufe auf Listen, in denen man Mitglied ist, mit allen Items), `tripSplitsProvider(entry.id)`, `expenseSplitServiceProvider`. Kennzahlen, Ersparnis (`totalSavingsOf`, `tripsInMonth`) und Wochentage werden in `build` berechnet.
- **Wichtigste Texte (DE):** "Aktivitäten", "Dein {Monat}.", "Artikel gekauft", "Einkäufe", "Verlauf", "Du hast {amount} durch Angebote gespart.", "Das sind {amount} in diesem Monat — mehr als letzten Monat mit {prevAmount}.", "{day} ist dein Einkaufstag.", "Kein Einkaufsverlauf", "Du hast {amount} bei diesem Einkauf gespart.", "Kosten teilen", "Gesamtkosten", "Bearbeiten", "Bezahlt von", "Bezahlt", "Offen", "Erinnerung kopieren", "Erinnerung in Zwischenablage kopiert", Erinnerungstext "Hi {name}! Kleine Erinnerung: du schuldest mir noch {amount} € für unseren Einkauf "{list}". Danke! 🛒", "Eintrag löschen" / "Möchtest du diesen Eintrag wirklich löschen?".

### 2.2 Sheet "Kosten teilen" – `_SplitCostSheet`

- **Datei:** `lib/presentation/screens/history/widgets/split_cost_sheet.dart`
- **Einstieg:** drei Wege, alle über `showSplitCostSheet(context, ref, entry:)`: (a) Verlauf, aufgeklappte Zeile, "Kosten teilen" oder "Bearbeiten" (`shopping_history_screen.dart:526, 566`); (b) Snackbar-Aktion nach "Einkauf abschließen", nur wenn die Liste mindestens 2 Mitglieder hat (`shopping_trip_completion.dart:136-163`); (c) Startseiten-Karte `SplitTripNudgeCard`. Avo hat zusätzlich das Tool `split_trip_cost` ohne UI (`avo_assistant_service.dart:1013ff.`).
- **Hauptfrage:** "Wer bekommt wie viel von diesem Einkauf zurück?"
- **Aufbau:** Material-`showModalBottomSheet` (transparent, `isScrollControlled`), eigene Container-Fläche mit Radius 24 oben und selbst gemaltem Griff (36×4). Titel "Kosten teilen" (Serif 22), Listenname (13 pt). `TextField` Gesamtkosten mit `OutlineInputBorder`, Präfix "€ " (Serif 20). Kicker "AUFTEILEN ZWISCHEN" + Textlink "Individuell/Gleich aufteilen". Pro Teilnehmer: Material-`Checkbox`, Name, Betragsfeld (feste Breite 84, nur im Modus "Individuell" editierbar). Feld "Person per Name hinzufügen" + `IconButton add_circle`. Kicker "BEZAHLT VON" + Chips (Wrap) zur Zahler-Wahl. Prüfzeile "Zugewiesen  X € / Y €" (Terrakotta bei Abweichung). Volle Breite `ElevatedButton` "Aufteilung speichern" (Spinner beim Speichern).
- **Komponenten:** Material-Sheet, `TextField` (Outline/Underline), `Checkbox`, `IconButton`, `ElevatedButton`, `CircularProgressIndicator`, `StatefulBuilder` (innerhalb eines `ConsumerStatefulWidget`).
- **Zustände:** Laden des Nutzers: 200-pt-Box mit Material-Spinner (Z. 173-176). Fehler: `SizedBox.shrink()` auf transparentem Sheet, also unsichtbar (Z. 177). Mitglieder laden: still, werden nachträglich eingefügt (Z. 85-103, 181-184). Speichern: Button deaktiviert + Spinner. Speicherfehler: Snackbar "Aufteilung konnte nicht gespeichert werden." Ungültiger Betrag (≤ 0): nur `heavyImpact`, kein Text (Z. 130-133). Offline: Fehler erst beim Speichern. Modul aus / Pro: gibt es nicht.
- **Aktionen:** Betrag tippen (gleiches Aufteilen rechnet live in ganzen Cent, Rest auf die ersten Personen, Z. 115-127), Teilnehmer an/aus, Person per Name ergänzen, Modus wechseln, Zahler wählen, speichern (schließt Sheet, danach Invalidierung von `tripSplitsProvider`, `tripsAwaitingPaymentToMeProvider`, `tripsIOweProvider`).
- **Datenquellen:** `currentUserProvider`, `splitCandidateMembersProvider(listId)` (`ListRepository.getListMembers`), `expenseSplitServiceProvider.createSplits(...)`.
- **Texte:** "Kosten teilen", "Gesamtkosten", "Aufteilen zwischen", "Gleich aufteilen", "Individuell", "Person per Name hinzufügen", "Bezahlt von", "Zugewiesen", "Aufteilung speichern", "Mitglied" (Fallback-Name), "Du" (Fallback eigener Name).

### 2.3 Angebote der Woche – `WeeklyDealsScreen`

- **Datei:** `lib/presentation/screens/home/weekly_deals_screen.dart`
- **Einstieg:** nur der cremefarbene "Angebote"-Streifen der Startseite (`home_screen.dart:491-565`, `Navigator.push`). Teaser zeigt "{count} Angebote passend zu deinen Listen", wenn `personalizedDealsProvider` Daten hat. Keine Route, kein Deep Link, keine Prüfung eines Modul-Schalters oder Kill-Switches.
- **Hauptfrage:** "Was von dem, was ich ohnehin kaufen will, ist diese Woche im Angebot?" (Standardansicht). Die Suche beantwortet eine zweite Frage: "Ist Produkt X gerade irgendwo im Angebot?"
- **Aufbau:** Material-`AppBar` mit Pfeil und Serif-Titel "Angebote der Woche" (18, linksbündig). Darunter eigenes Suchfeld (Fläche + Rahmen, Radius 14, Lupe, X zum Leeren). Ohne echte PLZ: Zeile "Deutschlandweite Angebote — PLZ für lokale Preise festlegen" mit Pin und Chevron, öffnet `showZipCodeSheet` (Z. 127-152). Darunter entweder:
  - **Personalisiert** (Suchtext < 2 Zeichen): Kicker "PASSEND ZU DEINEN LISTEN", dann `_DealCard`-Liste (Z. 244-294).
  - **Suche** (≥ 2 Zeichen): `_DealCard`-Liste aller Treffer (Z. 211-242).
- **`_DealCard`** (Z. 324-474): Karte mit Fläche, Rahmen, Radius 16, Innenabstand 12. Links Produktbild 46×46 (`Image.network` auf marktguru-CDN, Fallback Korb-Icon auf Creme). Mitte: Produktname (14, 1 Zeile), "Händler · Packungsgröße" (11,5), "Für „{item}“ auf deiner Liste" (10,5), "Ähnliches Produkt" (10), "Angebot endet heute/in {n}T" (10, Warnfarbe, nur ≤ 3 Tage). Rechts: Rabatt-Badge "-X%" (10, Akzent) + Preis (Serif 14), darunter "statt X €" (9,5).
- **`_AddDealSheet`** (Z. 479-625): Material-Sheet, Radius 24, "Zur Einkaufsliste hinzufügen", Produktname, gruppierte Liste aller Listen (Cupertino-Buttons mit blauem Wagen-Icon, Trennlinien ab 42 pt). Tippen fügt einen neuen Artikel mit Angebotspreis, Händler, Packungsgröße und Streichpreis hinzu (`autoParse: false`) und schließt das Sheet.
- **Zustände:** Laden: zentrierter `CupertinoActivityIndicator` für die ganze Fläche (Z. 219, 253). Fehler: Icon `wifi_off` + "Angebote konnten gerade nicht geladen werden." (praktisch nie erreicht, siehe Bugs). Leer (personalisiert): Icon `local_offer_outlined` + "Aktuell kein Angebot passend zu deinen Listen. Nutze oben die Suche für ein bestimmtes Produkt." Leer (Suche): `search_off` + "Keine aktuellen Angebote dafür gefunden." Ohne PLZ: Hinweiszeile. Sheet: Laden/Fehler/keine Listen ("no_lists_yet"), Hinzufügen-Spinner, Fehler-Snackbar rot mit Rohtext der Exception. Modul aus / Kill-Switch / Pro: nicht vorhanden.
- **Aktionen:** Tippen in Suche (jede Eingabe löst neue Abfrage aus), X leert, PLZ-Zeile öffnet PLZ-Sheet, Karte antippen öffnet Listen-Wahl, Liste antippen fügt hinzu (Haptik `mediumImpact`).
- **Datenquellen:** `userZipCodeProvider`, `effectiveZipProvider` (Fallback-PLZ 10115), `offerSearchAllProvider(query)` → `OfferPriceService.searchOffers`, `personalizedDealsProvider` → offene Artikel der 2 zuletzt geänderten Listen mit offenen Artikeln → max. 10 Namen → `RecipeOfferService.matchOffers` (bestes relevantes Angebot je Name, alle Märkte gemischt) → Sortierung Rabatt-% absteigend, dann Preis. `userListsProvider`, `itemsNotifierProvider(listId).addItem`.
- **Texte:** "Angebote der Woche", "Produkt suchen…", "Deutschlandweite Angebote — PLZ für lokale Preise festlegen", "Passend zu deinen Listen", "Für „{item}“ auf deiner Liste", "Ähnliches Produkt", "Angebot endet heute", "Angebot endet in {days}T", "statt {price} €", "Zur Einkaufsliste hinzufügen", Fehler- und Leertexte oben.

### 2.4 Startseiten-Karte "Offene Aufteilungen" – `PendingSplitsBanner`

- **Datei:** `lib/presentation/screens/home/widgets/pending_splits_banner.dart`; eingebunden in `home_screen.dart:323`.
- **Hauptfrage:** "Wem schulde ich Geld, wer schuldet mir Geld?"
- **Aufbau:** `NudgeCardShell` (Fläche + Rahmen, Radius 14). Je offenem Anteil eine `_SplitRow`: Pfeil-Icon 14 pt (runter = Akzent für "schuldet dir", hoch = Terrakotta für "du schuldest"), Text (12,5, max. 2 Zeilen), rechts Textaktion "Als bezahlt markieren" bzw. "Zurückgezahlt" (11,5). Ohne Obergrenze: jede offene Schuld ist eine eigene Zeile.
- **Zustände:** rendert nichts, wenn beides leer oder noch ladend oder Fehler (`valueOrNull ?? []`). Kein Modul-Schalter.
- **Aktionen:** Zeile antippen öffnet den ganzen Verlauf (nicht den betroffenen Einkauf). Schnellaktion setzt sofort bezahlt (Haptik `lightImpact`), ohne Rückgängig und ohne Fehlerbehandlung.
- **Datenquellen:** `tripsAwaitingPaymentToMeProvider`, `tripsIOweProvider`, `expenseSplitServiceProvider.setPaid`.
- **Texte:** "{name} schuldet dir {amount} € · {list}", "Du schuldest {name} {amount} €", "Als bezahlt markieren", "Zurückgezahlt".

### 2.5 Startseiten-Karte "Einkauf teilen?" – `SplitTripNudgeCard`

- **Datei:** `lib/presentation/screens/home/widgets/split_trip_nudge_card.dart`; eingebunden in `home_screen.dart:809` über die Karten-Reihenfolge.
- **Hauptfrage:** "Willst du den letzten gemeinsamen Einkauf aufteilen?"
- **Aufbau:** `NudgeCard` (Icon `people_outline` im getönten Kreis, Titel "„{list}“ mit deiner Gruppe teilen?", Untertitel "≈ {amount} € gesamt — antippen zum Teilen" oder "Antippen, um die Kosten zu teilen", X zum Wegwischen).
- **Bedingung:** jüngster eigener Einkauf der letzten 7 Tage auf einer Liste mit ≥ 2 Mitgliedern, noch ohne Aufteilung, nicht weggewischt (`expense_split_service.dart:263-325`, `expense_split_provider.dart:50-59`).
- **Aktionen:** Antippen öffnet das Teilen-Sheet mit einem nachgebauten `ShoppingHistory` (ohne Items); X speichert die ID in SharedPreferences.

### 2.6 Nicht-visuelle Teile, die zum Bereich gehören

- **Push "Anteil beglichen/wieder geöffnet"** (`expense_split_service.dart:148-202`): geht an Zahler bzw. Teilnehmer, nie an den Auslöser, nie an Namens-Teilnehmer.
- **Avo-Tools:** `split_trip_cost`, `get_savings_summary` (gleiche Rechnung wie der Verlauf über `totalSavingsOf`), `get_personalized_deals` (liest `personalizedDealsProvider`), `get_shopping_history` (`avo_assistant_service.dart:269-304, 946, 1013, 1761`).
- **Kaufstatistik** (`purchase_tracking_service.dart`): speist Nachkauf-Rhythmus (Avo-Karte, Benachrichtigungen) und den "meist gekauften Markt" pro Artikel (`preferred_retailer`, `retailer_counts`). Grundlage für "Markt pro Liste, gelernt aus Einkäufen".
- **Profil:** zeigt die Anzahl der Einkäufe aus `shoppingHistoryProvider` (`profile_screen.dart:429-430`).

---

## 3. Design-Probleme heute

### 3.1 Paper-Reste (Kicker, Serifen, Creme/Terrakotta)

| Stelle | Problem |
|---|---|
| `shopping_history_screen.dart:16` | Kommentar und Konzept "Paper-style activities screen" |
| `shopping_history_screen.dart:139-147`, `288-296` | Großbuchstaben-Kicker "AKTIVITÄTEN", "VERLAUF" (11 pt, Laufweite 2) |
| `shopping_history_screen.dart:154`, `344`, `422` | Georgia-Serif für Überschrift (28), Kennzahlen (26) und jeden Listennamen (17) |
| `split_cost_sheet.dart:215`, `228`, `231` | Serif für Sheet-Titel und Betragsfeld |
| `split_cost_sheet.dart:243-249`, `345-351` | Kicker "AUFTEILEN ZWISCHEN", "BEZAHLT VON" |
| `split_cost_sheet.dart:408`, `421`, `433` | `PaperColors.terracotta` für Summen-Abweichung, `PaperColors.paper` als Button-Textfarbe (fest, nicht adaptiv) |
| `weekly_deals_screen.dart:112`, `458` | Serif für Titel und Preise |
| `weekly_deals_screen.dart:273-281` | Kicker "PASSEND ZU DEINEN LISTEN" |
| `weekly_deals_screen.dart:379`, `384` | `PaperColors.cream`/`creamInk` als Bild-Fallback |
| `weekly_deals_screen.dart:522-524` | `PaperColors.surface`/`hairline` im Listen-Sheet |
| `pending_splits_banner.dart:67` | Terrakotta für "Du schuldest" |
| `home_screen.dart:519-555` (Einstieg) | Cremefarbener Angebote-Streifen mit Kicker "ANGEBOTE" und Serif-Teaser |

### 3.2 Abweichungen von den Apple-Regeln

- **Navigation ohne Wayfinding:** Verlauf hat eine Material-`AppBar` ohne Titel (`shopping_history_screen.dart:61-69`), der Titel steht als Fließtext im Inhalt. Beide Screens nutzen `Icons.arrow_back` (Android-Pfeil) statt iOS-Zurück mit Vorgänger-Titel, kein Large Title, kein Scroll-Edge-Effekt, kein Wischen-zurück-Hinweis über `CupertinoPageRoute` (es ist `MaterialPageRoute`, `home_screen.dart:512, 586`; `pending_splits_banner.dart:96`).
- **Material statt iOS-Bausteinen:** `Checkbox` (`split_cost_sheet.dart:276`), `OutlineInputBorder`/`UnderlineInputBorder` (`:233`, `:304`, `:324`), `ElevatedButton` (`:417`), `IconButton add_circle` (`:328`), `CircularProgressIndicator` (`:175`, `:431`; `shopping_history_screen.dart:591`), `InkWell` mit Ripple (`pending_splits_banner.dart:123`), `Tooltip` (`shopping_history_screen.dart:660`), Material-`showModalBottomSheet` mit selbst gemaltem Griff statt Sheet mit Detents (`split_cost_sheet.dart:19-24`, `202-211`; `weekly_deals_screen.dart:353-357`). Eigenes Suchfeld statt `CupertinoSearchTextField` bzw. Such-Bar in der Navigation (`weekly_deals_screen.dart:168-209`).
- **Material-Icons statt SF Symbols:** `savings_outlined`, `call_split_rounded`, `copy_rounded`, `chevron_right`, `keyboard_arrow_down`, `arrow_downward_rounded`, `arrow_upward_rounded`, `location_on_outlined`, `wifi_off_rounded`, `local_offer_outlined`, `shopping_basket_outlined` (durchgehend).
- **Touch-Ziele unter 44 pt:**
  - "Kosten teilen"-Link 12,5-pt-Text ohne Polster (`shopping_history_screen.dart:523-541`), ca. 18 pt hoch.
  - "Bearbeiten" 12-pt-Text (`:563-572`).
  - Kopier-Icon 13 pt mit 6 pt seitlichem Polster (`:656-669`), ca. 15×25 pt.
  - Bezahlt/Offen-Pille, Polster 3 pt vertikal, Text 10,5 (`:688-706`), ca. 20 pt hoch.
  - Zahler-Chips, Polster 6 pt vertikal (`split_cost_sheet.dart:362-363`), ca. 30 pt.
  - Modus-Link "Individuell" 12-pt-Text (`:251-266`).
  - Schnellaktion "Als bezahlt markieren" 11,5 pt (`pending_splits_banner.dart:140-152`), ca. 15 pt hoch, direkt neben der Zeilen-Tippfläche.
  - PLZ-Hinweiszeile, 12-pt-Text (`weekly_deals_screen.dart:129-151`), ca. 16 pt hoch.
- **Versteckte Geste als einziger Weg:** Löschen nur per langem Druck auf die Zeile (`shopping_history_screen.dart:400`), kein Wischen-zum-Löschen, kein Kontextmenü, keine sichtbare Alternative.
- **Bestätigung statt Rückgängig:** "Als bezahlt markieren" und die Pille schalten ohne Rückgängig um; umgekehrt nutzt das Löschen einen Dialog (bei endgültigem Löschen mit kaskadierenden Schulden ist das vertretbar, aber dann sichtbar machen).
- **Sichtbares Laden:** Vollflächen-Spinner beim Öffnen des Verlaufs (`:71`) und der Angebote (`weekly_deals_screen.dart:219`, `253`); kein Skeleton, kein Cache-zuerst. Spinner in einzelnen Verlaufszeilen (`:585-594`). Angebotsbilder ploppen ohne Platzhalter auf (`:371`).
- **Keine Animation beim Aufklappen:** Chevron springt (`shopping_history_screen.dart:433-438`), Inhalt erscheint ohne Übergang. Keine Feder, kein Reduce-Motion-Pfad nötig, aber auch keine Herkunft.
- **Reihen identischer Karten mit Rahmen:** `_DealCard` mit `Border.all` (`weekly_deals_screen.dart:362-366`), Suchfeld mit Rahmen (`:180`), `NudgeCardShell` mit Rahmen. Flächen werden über Linien statt Tonstufen getrennt; Verlaufszeilen mit harter Unterlinie (`shopping_history_screen.dart:403-407`).
- **Farbe:** Fest kodierte Farben `Color(0xFF2C2C2E)` (`weekly_deals_screen.dart:379`, `522`), `Colors.white`/`Colors.black` (`:602`), `CupertinoColors.systemBlue` für das Listen-Icon statt Akzent (`:594`), `Colors.red` für Fehler-Snackbar (`:511`). Text in der Ersparnis-Zeile ganz in Akzentfarbe (`shopping_history_screen.dart:193-197`), Fließtext oft `textSecondary`/`textTertiary` (Artikel im aufgeklappten Einkauf `:461-464`, Teilnehmer `:648-652`), also blass statt voller Textfarbe.
- **Diagramm:** Wochentags-Diagramm ohne Semantics/VoiceOver-Beschreibung (`:225-274`), Labels 10 pt in `textTertiary`. Diagramm zählt alle Einkäufe der Lebenszeit, während die Überschrift "Dein November." lautet (`:86-89`): eine Frage, aber zwei Zeiträume.
- **Kennzahlen gemischt:** "Artikel gekauft" und "Einkäufe" gelten für den Monat, "Verlauf" (die dritte Zahl) für alle Zeit (`:162-176`). Das Label "Verlauf" unter einer Zahl ist unverständlich ("37 Verlauf").
- **Statt-Preis und Rabatt:** "statt X €" ohne Kennzeichnung "laut Händler" (`weekly_deals_screen.dart:461-466`) und ein selbst berechnetes, hervorgehobenes "-X%"-Badge (`:444-456`). Die Recherche verlangt das Gegenteil (Abschnitt "Streichpreise"). Die Sortierung nach eigenem Rabatt-% verstärkt das (`personalized_deals_service.dart:52-58`). Keine Quellenangabe für Angebote, kein "in deiner Region".
- **Ersparnis-Aussage ohne Einschränkung:** "Du hast X € durch Angebote gespart." (`shopping_history_screen.dart:186-198`) beruht auf Händler-Streichpreisen. Laut Recherche keine eigene Ersparnisrechnung als Fakt darstellen; mindestens "ca." und "laut Händler".
- **Emojis in Nutzertexten:** Erinnerungstext endet auf "🛒" (`app_translations.dart:1627-1628`), Push-Titel "💶 Share settled" (`expense_split_service.dart:179`).
- **Teilen der Erinnerung:** Nur Zwischenablage + Snackbar (`shopping_history_screen.dart:617-633`), kein iOS-Teilen-Sheet, obwohl das der erwartbare Weg ist.

### 3.3 Feste Maße, die bei 320 pt Breite oder großer Schrift brechen

| Stelle | Problem |
|---|---|
| `shopping_history_screen.dart:159-177`, `350-352` | Drei `_Stat` mit fester Breite 82 + 2×28 Abstand = 302 pt in einer `Row` ohne Umbruch. Bei 320 pt Breite (Anzeigezoom) bleiben nach 2×24 pt Rand nur 272 pt: **RenderFlex-Überlauf um 30 pt**. Bei großen Schriftstufen werden die Serif-Zahlen (26) breiter als 82 pt. |
| `shopping_history_screen.dart:225-226`, `234-235` | Diagramm feste Höhe 90, Balken 14 + 76 × Anteil |
| `shopping_history_screen.dart:142`, `258-262`, `356`, `428`, `471`, `580`, `699` | Feste Schriftgrößen 10 bis 12,5 pt ohne Bezug zu Dynamic Type-Stilen; skaliert zwar mit `textScaler`, aber ohne Hierarchie-Logik und mit vielen Werten unter 13 pt |
| `shopping_history_screen.dart:670-707` | Teilnehmerzeile: Name (Expanded) + Icon + Betrag + Pille in einer Row; bei großer Schrift wird der Name auf wenige Zeichen gequetscht |
| `split_cost_sheet.dart:293-311` | Betragsfeld feste Breite 84: "123,45 €" passt bei großer Schrift nicht |
| `split_cost_sheet.dart:198` | Sheet ist eine `Column(mainAxisSize: min)` **ohne Scroll**. Mit Tastatur (Padding `viewInsets`, Z. 187-189), mehreren Teilnehmern oder großer Schrift läuft das Sheet über den Bildschirm hinaus; auf dem iPhone SE schon ab ca. 4 Teilnehmern mit offener Tastatur |
| `split_cost_sheet.dart:173-176` | Lade-Box feste Höhe 200 |
| `weekly_deals_screen.dart:371-378` | Bild 46×46 fest; daneben bis zu fünf Textzeilen 9,5 bis 14 pt |
| `weekly_deals_screen.dart:438-467` | Preisspalte ohne Breitenbegrenzung neben `Expanded`; bei großer Schrift drückt "-30 % 12,99 €" den Produktnamen auf wenige Zeichen |
| `weekly_deals_screen.dart:532-621` | Listen-Sheet ohne Scroll und ohne `isScrollControlled`: bei vielen Listen oder großer Schrift Überlauf |
| `pending_splits_banner.dart:131-152` | Text `maxLines: 2` + Ellipse neben Schnellaktion ohne Mindestbreite; bei großer Schrift wird die Schuld-Aussage abgeschnitten |

### 3.4 Zahlen- und Datumsformat

Beträge werden überall per `toStringAsFixed(2)` + " €" gebaut, nicht über `NumberFormat.currency(locale)`: Deutsch zeigt "3.20 €" statt "3,20 €". Betroffen: `shopping_history_screen.dart:118`, `124`, `190`, `489`, `556`, `623`, `671`; `split_cost_sheet.dart:401`; `pending_splits_banner.dart:45`, `71`; `split_trip_nudge_card.dart:33`; `weekly_deals_screen.dart:457`, `464`. Das Sheet setzt "€ " als Präfix vor die Zahl (`split_cost_sheet.dart:230`), im Deutschen steht das Zeichen dahinter. Mengen werden roh formatiert (`shopping_history_screen.dart:468`, z. B. "0.5 kg").

---

## 4. Bugs, Risiken und Performance

### 4.1 Datenfehler

1. **"Bearbeiten" setzt eine Aufteilung zurück und verliert Daten.** `_initFromData` (`split_cost_sheet.dart:73-83`) lädt die bestehenden Anteile nicht: Es startet mit "ich" + Listen-Mitgliedern, gleichem Aufteilen und mir als Zahler. Namens-Teilnehmer, individuelle Beträge und der echte Zahler fehlen. Beim Speichern ersetzt `createSplits` alle Zeilen (`expense_split_service.dart:61-114`), **bereits bezahlte Anteile werden wieder "Offen"** (nur der Zahler-Anteil wird bezahlt angelegt, Z. 93).
2. **Individuelle Beträge werden ohne Summenprüfung gespeichert.** `_save` (`split_cost_sheet.dart:129-163`) prüft nur `_total > 0`, nicht `_sumMatchesTotal`. Die rote Prüfzeile (`:393-412`) ist nur Anzeige. Schulden ergeben dann nicht den Gesamtbetrag.
3. **Verlauf ist nach einem Einkauf veraltet.** `shoppingHistoryNotifierProvider` ist nicht autoDispose und lädt nur beim Login (`shopping_history_provider.dart:91-102`). `completeShoppingTrip` invalidiert ihn nicht (`shopping_trip_completion.dart`, kein `invalidate`), nur ein Kontowechsel tut es (`app.dart:77-81`). Auch neue Aufteilungen und Einkäufe anderer Mitglieder erscheinen erst nach App-Neustart. Kein Pull-to-Refresh.
4. **Löschen fremder Einkäufe scheitert still.** Der Verlauf zeigt auch Einkäufe anderer Listen-Mitglieder (`shopping_history_service.dart:106-124`), Langdruck bietet Löschen an. Ein `DELETE` ohne Treffer durch RLS liefert in PostgREST keinen Fehler; `deleteHistory` entfernt den Eintrag dann lokal (`shopping_history_provider.dart:66-78`), beim nächsten Laden ist er wieder da. Die RLS-Regeln für `shopping_history` sind nicht im Repo dokumentiert (nur die für `expense_splits`), daher **plausibel, nicht verifiziert**. Gleiches Risiko für das `UPDATE` von `total_cost`/`paid_by_*` in `createSplits` durch ein Nicht-Eigentümer-Mitglied (`expense_split_service.dart:103-107`): Anteile würden gespeichert, Gesamtbetrag und Zahler nicht.
5. **Fehler im Notifier zerstört die Liste.** Schlägt `deleteHistory` fehl, setzt der Notifier `state = AsyncValue.error` (`shopping_history_provider.dart:75-77`) und wirft nicht weiter. Der Screen fängt in `_confirmDelete` (`shopping_history_screen.dart:38-48`) deshalb nie einen Fehler, zeigt aber den ganzen Screen als "loading_error".
6. **Bezahlt-Schalter ohne Fehlerbehandlung.** `setPaid` wirft bei Netzfehler (`.single()`, `expense_split_service.dart:128-142`); Pille (`shopping_history_screen.dart:679-687`) und Schnellaktion (`pending_splits_banner.dart:53-60`, `78-85`) fangen das nicht ab: unbehandelte Exception, keine Rückmeldung, kein optimistischer Zustand (die Pille ändert sich erst nach Netz-Rundlauf).
7. **Gesamtbetrag ist eine Teilsumme.** `completeShoppingTrip` setzt `total_cost` aus den Artikeln mit bekanntem Angebotspreis (`shopping_history_service.dart:42-60`). Haben nur 2 von 15 Artikeln einen Preis, steht "Gesamtkosten: 3,49 €" im Verlauf, die Karte zeigt "≈ 3,49 € gesamt" (`split_trip_nudge_card.dart:30-35`), und der Verlauf zeigt dann statt "Kosten teilen" schon "Gesamtkosten … Bearbeiten" ohne Anteile (`shopping_history_screen.dart:520`).
8. **Personalisierte Angebote erzeugen Doppel-Einträge.** `_AddDealSheet._addTo` legt immer einen neuen Artikel mit dem vollen Produktnamen an (`weekly_deals_screen.dart:495-503`), auch wenn das Angebot zu einem Artikel passt, der schon auf der Liste steht ("Milch" + "Milbona Frische Vollmilch 3,5 %"). `showItemOfferSheet` (Preis an bestehenden Artikel hängen) wird hier nicht genutzt. Auch die Ziel-Liste ist nicht vorausgewählt, obwohl die Herkunftsliste bekannt wäre.
9. **Offline sieht aus wie "keine Angebote".** `searchOffers` liefert bei Fehlern `[]` (`offer_price_service.dart:69-77`), `matchOffers` wirft nie und das `complete`-Flag wird in `PersonalizedDealsService.getMatches` verworfen (`personalized_deals_service.dart:50-52`). Die Fehlerzweige in `weekly_deals_screen.dart:220-223`, `254-257` werden praktisch nie erreicht; offline steht "Keine aktuellen Angebote dafür gefunden".
10. **Name-Fallback falsch.** "Du schuldest {name}" nutzt `trip.paidByName ?? trip.listName` (`pending_splits_banner.dart:72`). Hat der Zahler eine Konto-ID, aber keinen gespeicherten Namen (Avo-Tool oder Default-Pfad in `createSplits`, Z. 71-73), lautet der Satz "Du schuldest Wocheneinkauf 3.20 €".
11. **Push-Texte nur Englisch, mit Emoji.** `_notifySplitStatusChanged` baut Titel und Text fest auf Englisch (`expense_split_service.dart:168-186`), Fallback "Someone". Deutsche Nutzer bekommen englische Mitteilungen. Der Typ `expense_split` wird beim Antippen nicht geroutet (`navigation_service.dart:68-90` kennt ihn nicht).
12. **Teilen-Karte erfasst nur eigene Einkäufe.** `getUnsplitTripNudgeCandidate` filtert `user_id = ich` (`expense_split_service.dart:269-275`). Kauft der Partner ein, sieht nur er die Karte. Weggewischt wird pro einzelner ID (`split_nudge_cache_service.dart:18-36`); ältere, ungeteilte Einkäufe tauchen nach dem Wegwischen nicht mehr auf, ein neuer Einkauf überschreibt die gemerkte ID.
13. **Seiteneffekt im Build.** `membersAsync?.whenData((m) => _mergeMembers(...))` in `build` (`split_cost_sheet.dart:181-184`) verändert State und plant `setState` per Post-Frame-Callback; ein `StatefulBuilder` steckt zusätzlich in einem `ConsumerStatefulWidget` (`:196`). Fehleranfällig, z. B. doppelte Teilnehmer bei gleichem Namen (keine Prüfung beim manuellen Hinzufügen, `:330-338`).
14. **Betragseingabe:** `replaceAll(',', '.')` (`split_cost_sheet.dart:105`, `307-308`) macht aus "1.234,56" den Wert 0. Ungültige Eingaben werden still zu 0.
15. **Unsichtbares Sheet bei Fehler.** `currentUserProvider` mit Fehler rendert `SizedBox.shrink()` auf transparentem Hintergrund (`split_cost_sheet.dart:177`): das Sheet ist offen, aber leer und unsichtbar.
16. **Fallback-PLZ und Ersparnis.** Mit der Fallback-PLZ 10115 (Berlin) heißt der Hinweis "Deutschlandweite Angebote" (`weekly_deals_screen.dart:142`, Text `offers_nationwide_set_zip`), es sind aber Berliner Regionalangebote. Laut Liste 6a darf mit Fallback-PLZ keine Ersparnis behauptet werden; der Verlauf zählt Ersparnisse unabhängig davon, woher der Preis kam.
17. **Rohtext von Exceptions** in der Fehler-Snackbar (`weekly_deals_screen.dart:510`).

### 4.2 Recht und Produktentscheidungen (aus Plan/Recherche)

- Kein Modul-Schalter und kein Remote-Kill-Switch: Angebote der Woche, Angebote-Streifen und Teilen-Funktionen sind immer sichtbar (`home_screen.dart:491-565`, `323`, `809`). Plan 1 und Liste 6a/6d verlangen beides.
- Angebote mischen alle Märkte (`personalizedDealsProvider`, `price_comparison_provider.dart:299-317`). Es gibt keinen Markt pro Liste und keinen Ketten-Filter (Liste 6c).
- Produktbilder sind Hotlinks auf das marktguru-CDN (`StoreOffer.imageUrl`, `weekly_deals_screen.dart:371`); laut Liste 6a nur mit Lizenz.
- "statt"-Preise ohne "laut Händler", eigenes Rabatt-Badge, Sortierung nach eigenem Rabatt-% (siehe 3.2).
- Fest eingebaute marktguru-Ersatz-Keys (`offer_price_service.dart:26-28`).

### 4.3 Performance

- **Verlauf lädt alles auf einmal:** alle Einkäufe mit allen Items ohne Limit oder Seiten (`shopping_history_service.dart:106-124`), dazu vorher eine Mitgliedschafts-Abfrage. Gebaut wird in einer `SingleChildScrollView` + `Column` (`shopping_history_screen.dart:134-323`), also jede Zeile sofort, kein `ListView.builder`/Sliver. Kennzahlen, Monatsfilter, Wochentage und `totalSavingsOf` laufen bei jedem `setState` (Aufklappen) über alle Einträge neu; jede Zeile rechnet `totalSavingsOf([entry])` erneut (`:396`).
- **Offene-Schulden-Karte:** zwei Abfragen bei jedem Aufbau der Startseite (autoDispose), `getTripsAwaitingPaymentToMe` lädt alle eigenen bezahlten Einkäufe mit allen Splits, auch die längst beglichenen (`expense_split_service.dart:206-219`), und filtert erst im Client.
- **Teilen-Karte:** drei Abfragen pro Startseiten-Aufbau (`expense_split_service.dart:263-325`); gut gebündelt, aber ohne Cache.
- **Suche ohne Entprellen:** Jeder Tastendruck ab 2 Zeichen erzeugt einen neuen `offerSearchAllProvider`-Eintrag und eine Netzabfrage (`weekly_deals_screen.dart:125`, `157-158`); gemildert durch 250-ms-Drossel, In-flight-Teilen und 30-min-Cache in `offer_price_service.dart:54-96`, aber jede Zwischeneingabe ("mi", "mil", "milc") kostet einen API-Aufruf.
- **Personalisierte Angebote:** bis zu 10 parallele Suchen beim ersten Öffnen (gedrosselt), Vollflächen-Spinner bis alle fertig sind; keine Teilergebnisse.
- **Bilder:** `Image.network` ohne Disk-Cache und ohne Platzhalter (`weekly_deals_screen.dart:371`), lädt beim Scrollen neu.
- **Nach Bezahlt-Umschalten** werden drei Provider invalidiert, was alle drei Abfragen erneut auslöst (`shopping_history_screen.dart:684-686`).

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Startseite (Teil A, `home_screen.dart`):** bindet `PendingSplitsBanner` (Z. 323), `SplitTripNudgeCard` (Z. 809, über `home_nudge_card_order.dart`), den Angebote-Streifen mit `personalizedDealsProvider` (Z. 491-565) und die Verlaufszeile mit `recentHistoryProvider` (Z. 578-590, 826). Laut Arbeitsteilung liefert Teil B die Hinweis-Karten als eigene Widgets, Teil A ordnet sie an.
- **Listen (Teil A):** `shopping_trip_completion.dart` erzeugt die History-Einträge, öffnet das Teilen-Sheet per Snackbar und ruft `CheckoutStoreResolver` (Markt beim Abschluss). `list_detail_screen.dart:451` startet den Abschluss. `itemsNotifierProvider.addItem` wird vom Angebots-Sheet genutzt; `zip_code_sheet.dart` (`lib/presentation/screens/lists/widgets/`) für die PLZ. `offer_suggestions_bar.dart` teilt sich `offerSearchAllProvider` mit der Angebots-Suche.
- **Preise/Angebote (Teil B, geteilt):** `price_comparison_provider.dart` (auch `homePriceHighlightProvider`, `basketComparisonProvider`, die laut Plan wegfallen), `offer_price_service.dart`, `recipe_offer_service.dart`, `user_location_service.dart` (Fallback-PLZ), `StoreOffer`, `RecipeIngredientOffer` (`recipe_offer_highlight.dart`).
- **Avo (Teil B):** Tools `split_trip_cost`, `get_savings_summary`, `get_personalized_deals`, `get_shopping_history` (`avo_assistant_service.dart`, `avo_tool_declarations.dart:242`, `554`, `avo_system_prompt.dart:50`, `88`). `AvoNudgeService` und `MascotNotificationService` nutzen `PurchaseTrackingService` (Nachkauf-Rhythmus, Meilensteine "10. Einkauf").
- **Empfehlungen:** `ml_recommendation_service.dart:21-50` nutzt `PurchaseTrackingService` und `getHistoryForList`. `lists_provider.dart:30` hält eine eigene `PurchaseTrackingService`-Instanz.
- **Profil (Teil A):** Einkaufszahl aus `shoppingHistoryProvider` (`profile_screen.dart:429-430`).
- **App-Root:** `app.dart:77-81` invalidiert die History-Provider bei Kontowechsel.
- **Push:** `PushNotificationService.sendToUsers` (Edge Function `send-push-notification`), `navigation_service.dart` und `fcm_service.dart` ohne Fall für `expense_split`.
- **Gemeinsame UI-Bausteine:** `NudgeCardShell`/`NudgeCard` (`home/widgets/nudge_card.dart`), `confirmDestructive` (`widgets/common/confirm_dialog.dart`), `AppColors`, `PaperColors`/`PaperTextStyles` (`core/constants/paper_colors.dart`).
- **Strings:** alle in `lib/core/localization/app_translations.dart` (EN ca. Z. 378-502, DE ca. Z. 1546-1671, dazu `delete_entry*` Z. 956/2125, `no_shopping_history` Z. 817/1986). Schlüssel u. a.: `activities_label`, `your_month_headline`, `items_bought`, `purchases_label`, `history_label`, `history_savings_*`, `history_trip_savings_line`, `shopping_day_line`, `split_*`, `paid_by`, `paid`, `unpaid`, `payment_reminder_message`, `copy_reminder`, `reminder_copied`, `owed_to_me_line`, `i_owe_line`, `mark_as_paid`, `i_paid_back`, `weekly_deals_title`, `search_deals_hint`, `offers_nationwide_set_zip`, `deals_*`, `no_deals_found`, `no_personalized_deals_hint`, `matched_for_item`, `similar_product_match`, `offer_ends_*`, `instead_of_price`, `add_to_shopping_list`.
- **Datenbank:** Tabellen `shopping_history`, `shopping_history_items` (mit `price`, `price_retailer`, `price_old_value`), `expense_splits` (RLS im Repo), `item_purchase_stats` (mit `preferred_retailer`, `retailer_counts`), `list_members`, `users.display_name`.
- **Tests**, die bei Umbauten grün bleiben müssen: siehe Abschnitt 1.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Verlauf**
- Verlauf zeigt eigene Einkäufe **und** Einkäufe aller Listen, in denen man Mitglied ist, neueste zuerst; pro Einkauf Listenname, Datum (Heute/Gestern/Datum), Artikelzahl, Artikel mit Menge und Einheit, wer eingekauft hat (`completed_by_name`, heute nicht angezeigt, aber gespeichert).
- Preis-Schnappschuss pro Artikel (Preis, Händler, Streichpreis) und der Markt des Einkaufs (über `CheckoutStoreResolver` in `price_retailer`): Grundlage für "Markt pro Liste, gelernt aus Einkäufen".
- Ersparnis nur aus echten Daten: `savingsPerUnit` zählt nur, wenn Preis und Händler-Streichpreis bekannt und der Preis wirklich niedriger ist; nie geschätzt. Lebenszeit, Monat, Vormonatsvergleich nur bei echter Vormonats-Basis, pro Einkauf. Dieselbe Rechnung (`totalSavingsOf`, `tripsInMonth`) speist Avo, damit Chat und Screen nie widersprechen. Wortlaut künftig "ca." und "laut Händler".
- Einkaufstag-Erkennung (Wochentags-Verteilung) als echte, persönliche Information.
- Löschen eines Einkaufs (kaskadiert die Aufteilung) mit Rückfrage, weil endgültig.
- Kaufstatistik beim Abschluss (Anzahl, Daten, Intervall, bevorzugter Markt) läuft im Hintergrund weiter und blockiert nie.

**Kosten teilen**
- Teilen nach dem Abschluss (sofort), aus dem Verlauf (später), per Startseiten-Hinweis und per Avo.
- Teilnehmer: Listen-Mitglieder automatisch + Personen nur per Name (ohne App-Konto).
- Gleich aufteilen in ganzen Cent mit exakter Summe (10,00 / 3 = 3,34 + 3,33 + 3,33) und individuell aufteilen mit Summenkontrolle.
- Zahler frei wählbar, auch eine Namens-Person; der Anteil des Zahlers gilt sofort als bezahlt und wird nie als offene Schuld gezeigt.
- Neu-Aufteilen ersetzt die alte Aufteilung erst nach erfolgreichem Insert (keine halben Zustände).
- Bezahlt/offen umschaltbar durch Zahler und Teilnehmer, mit Push an die jeweils andere Seite (nie an den Auslöser, nie an Namens-Personen).
- Übersicht "schuldet dir" / "du schuldest", ohne die eigenen Anteile des Zahlers.
- Zahlungserinnerung für offene Anteile (heute Zwischenablage, künftig Teilen-Sheet), nicht für den eigenen Anteil.
- Hinweis "Einkauf teilen?" nur bei echten gemeinsamen Listen (≥ 2 Mitglieder), nur 7 Tage, nur ungeteilt, wegwischbar pro Einkauf.
- Kosten teilen ist laut Plan ein Modul: alles Obige muss spurlos ausblendbar sein.

**Angebote der Woche**
- Standardansicht "Angebote zu dem, was auf deinen Listen steht"; daneben freie Produktsuche.
- Relevanzregel `isRelevantMatch`/`pickBestOffer`: exakter Treffer vor Stamm-Treffer, lieber kein Angebot als ein falsches; "Ähnliches Produkt" kennzeichnen; "Für „Milch“ auf deiner Liste" zeigen, wenn der Produktname abweicht.
- Kostenbremse: max. 10 Namen, max. 2 Listen, Cache, In-flight-Teilen, Drossel.
- Ablaufhinweis ("endet heute", "endet in 2 Tagen") für Angebote mit ≤ 3 Tagen.
- Ein Tipp legt das Angebot mit Preis, Händler, Packungsgröße und Streichpreis auf eine Liste (künftig: an den passenden vorhandenen Artikel hängen statt duplizieren).
- PLZ-Hinweis, wenn keine echte PLZ bekannt ist, mit direktem Weg zur PLZ-Eingabe.
- Pflichten aus Plan und Recherche: Modul abschaltbar, Remote-Kill-Switch (dann spurlos weg, auch Avo-Tools und Startseiten-Streifen), nie Pro, "in deiner Region", "statt"-Preis als "laut Händler", kein Markt- oder Korbvergleich, Markt-Chip mit Name und Markenfarbe statt Logo, Angebote pro Liste auf deren Markt gefiltert, mit Fallback "alle Märkte der Region".

**Sonderfälle**
- Einkauf ohne Liste (`list_id` null, Altdaten): kein Mitglieder-Abruf, Teilen nur mit Namens-Personen.
- Einkauf ohne Gesamtbetrag vs. mit Teilsumme aus Angebotspreisen (heute verwechselt, siehe Bug 7).
- Ältere Aufteilungen, in denen der Zahler-Anteil noch als offen gespeichert ist (wird in `pending_splits_banner.dart:34-38` und `shopping_history_screen.dart:639-640` herausgefiltert).
- Datenbanken ohne Retailer-Migration (`purchase_tracking_service.dart:109-118`, `240-245`): Schreiben muss weiter gelingen.
- Fremde Einkäufe im Verlauf: nur lesen, nicht löschen (UI muss das künftig unterscheiden).
