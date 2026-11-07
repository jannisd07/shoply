# Inventar: Listen-Kern (Ist-Zustand, Stand 07.11.2026)

Grundlage für das Redesign. Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf den Stand von `main` (Commit `3e886d0`).

Vorab zwei Korrekturen an der Aufgabenbeschreibung:

- `lib/presentation/screens/lists/lists_screen.dart` existiert nicht. Die Listen-Übersicht ist heute ein Abschnitt von `lib/presentation/screens/home/home_screen.dart` (Zeilen 341-480, Zeile `_PaperListRow` ab 852). Sie ist hier als Screen 1 erfasst, weil sie zum Listen-Kern gehört; der Rest der Startseite gehört ins Home-Inventar.
- Ein `item_merge_service` existiert nicht. Das Zusammenführen gleicher Artikel steckt in `ItemRepository.addItem` (`lib/data/repositories/item_repository.dart:127-165`).

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/home/home_screen.dart` (Teil) | Listen-Übersicht, Dialoge "Neue Liste", "Liste beitreten", "Liste löschen" | 950 (davon ca. 300 Listen) |
| `lib/presentation/screens/lists/list_detail_screen.dart` | Listen-Detail: Kopf, gruppierte Artikel, schwebende Eingabeleiste, alle Add-Wege, Menü | 767 |
| `lib/presentation/screens/lists/widgets/add_item_composer.dart` | Eingabeleiste im Stil von Nachrichten ("+"-Kreis, Glas-Kapsel, Senden-Pfeil), nativer Glas-Verbund | 432 |
| `lib/presentation/screens/lists/widgets/attachment_sheet.dart` | "+"-Menü (Kamera, Fotos, Dateien), wächst aus dem Button, Foto-Import mit Lade-, Fehler- und Berechtigungszustand | 641 |
| `lib/presentation/screens/lists/widgets/import_review_sheet.dart` | Prüf-Sheet nach dem Foto-Import (Zeilen bearbeiten, löschen, importieren) | 338 |
| `lib/presentation/screens/lists/widgets/list_item_tile.dart` | Artikelzeile: Abhaken (linke 2/3), Bearbeiten (rechts), Wischen zum Löschen, Langdruck-Ziehen, Angebots-Chip | 393 |
| `lib/presentation/screens/lists/widgets/list_category_section.dart` | Gruppierung nach Kategorie, Kategorie-Kopf, Drop-Ziele, Lern-Aufruf für Kategorien | 317 |
| `lib/presentation/screens/lists/widgets/list_drag_controller.dart` | Drag-Zustand und Auto-Scroll am Rand | 104 |
| `lib/presentation/screens/lists/widgets/list_detail_parts.dart` | Umbenennen-Dialog, Zurück- und Teilen-Button (Glas), Fortschritts-Haarlinie, "Einkauf abschließen"-Button | 204 |
| `lib/presentation/screens/lists/widgets/list_detail_menu.dart` | "..."-Menü (Umbenennen, Kategoriereihenfolge, Listeneinstellungen), nativ ab iOS 26 | 122 |
| `lib/presentation/screens/lists/widgets/item_form_dialog.dart` | Dialog Artikel hinzufügen/bearbeiten/löschen, "Hinzugefügt von", `PaperPrimaryButton` (auch von Auth/Onboarding genutzt) | 549 |
| `lib/presentation/screens/lists/widgets/share_list_dialog.dart` | Teilen-Dialog mit Code und Link | 224 |
| `lib/presentation/screens/lists/shopping_trip_completion.dart` | Ablauf "Einkauf abschließen" (Bestätigung, Markt erkennen, Verlauf, Löschen, Push, Kosten teilen) | 238 |
| `lib/presentation/screens/lists/widgets/checkout_store_sheet.dart` | Sheet "In welchem Markt warst du?" | 292 |
| `lib/presentation/screens/lists/list_settings_screen.dart` | Listeneinstellungen: Mitglieder, entfernen, verlassen, löschen | 432 |
| `lib/presentation/screens/lists/category_order_screen.dart` | Kategoriereihenfolge, eigene Kategorien anlegen/bearbeiten/löschen | 536 |
| `lib/presentation/screens/lists/list_activities_screen.dart` | Aktivitäten einer Liste (verwaist, siehe 4.) | 344 |
| `lib/presentation/screens/lists/widgets/list_price_summary_bar.dart` | Preis-Leiste über der Eingabe ("günstigster Korb") und Markt-Vergleichs-Sheet | 551 |
| `lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart` | Live-Angebote beim Tippen | 458 |
| `lib/presentation/screens/lists/widgets/item_offer_sheet.dart` | Angebots-Chip in der Zeile und Angebots-Sheet | 407 |
| `lib/presentation/screens/lists/widgets/zip_code_sheet.dart` | PLZ-Eingabe | 158 |
| `lib/presentation/widgets/recommendations/ml_recommendations_section.dart` | Aufklappbare Karte "KI-Empfehlungen" oben in der Liste | 169 |
| `lib/presentation/widgets/recommendations/recommendation_card.dart` | Zeile einer Empfehlung | 127 |
| `lib/presentation/state/lists_provider.dart` | `listsNotifierProvider`, `userListsProvider`, Listen-CRUD, globaler Realtime-Kanal | 226 |
| `lib/presentation/state/items_provider.dart` | `itemsNotifierProvider(listId)`: optimistische Mutationen, Realtime pro Liste, Offline-Seed, Widget-Update | 451 |
| `lib/presentation/state/last_list_provider.dart` | zuletzt geöffnete Liste (lokal pro Nutzer) | 50 |
| `lib/presentation/providers/ml_recommendations_provider.dart` | Empfehlungs-Provider pro Liste | 39 |
| `lib/data/repositories/item_repository.dart` | Artikel lesen/schreiben, KI-Parsing, Zusammenführen, Kategorisierung, Push an Mitglieder, Realtime | 407 |
| `lib/data/repositories/list_repository.dart` | Listen lesen/schreiben, Share-Code, Beitreten, Mitglieder, globaler Realtime-Kanal | 308 |
| `lib/data/services/ml_recommendation_service.dart` | Mehrfaktor-Empfehlungen (Verlauf, Häufigkeit, Nachkauf-Rhythmus, Gemini-Ergänzungen) | 611 |
| `lib/data/services/smart_categorization_service.dart` | Lokale Kategorisierung (gelernte Vorlieben, Wissensbasis, Ähnlichkeit, Schlüsselwörter) | 308 |
| `lib/data/services/list_import_service.dart` | Foto/PDF komprimieren, hochladen, Edge Function `extract-shopping-list` | 294 |
| `lib/data/services/category_order_service.dart` | Kategoriereihenfolge und eigene Kategorien, nur lokal in SharedPreferences | ca. 120 |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Listen-Übersicht (Abschnitt der Startseite)

- **Datei:** `home_screen.dart:341-480`, Zeile `_PaperListRow` 852-950, Dialoge 584-805.
- **Einstieg:** Tab "Home" (`/home`).
- **Hauptfrage:** Welche Liste will ich öffnen?
- **Aufbau oben nach unten:** Kopf "DEINE LISTEN" (Großbuchstaben-Kicker) links, Textaktion "+ Neue Liste" rechts. Darunter nummerierte Zeilen: Serifen-Nummer "01" in Akzentfarbe, Serifen-Name 18 pt, Unterzeile "noch 3 Artikel · Geteilt", Personen-Icon bei geteilten Listen, darunter eine 2,5-pt-Fortschrittslinie.
- **Sortierung:** nach `updatedAt` absteigend (`home_screen.dart:415`).
- **Zustände:** leer: Karte 140 pt "Noch keine Listen"; laden: 140-pt-Box mit Spinner; Fehler: Karte mit "Fehler beim Laden", ohne Wiederholen; offline: Lists aus `OfflineCacheService`; Pro gesperrt und Modul aus: nicht vorhanden.
- **Aktionen und Gesten:** Tippen öffnet `/lists/:id?name=`; Langdruck auf eine Zeile löscht die Liste (mit Bestätigung `confirmDestructive`); Tippen auf "+ Neue Liste" öffnet einen Eingabe-Alert; Langdruck auf "+ Neue Liste" öffnet "Liste beitreten" (Code-Eingabe). Pull-to-Refresh.
- **Datenquellen:** `listsNotifierProvider`, `DynamicTutorialService` (Tutorial-Schlüssel an der ersten Zeile, legt bei Bedarf "Meine erste Liste" an, `home_screen.dart:111-150`).
- **Texte:** "Deine Listen", "+ Neue Liste", "noch {n} Artikel", "Alles erledigt", "Liste leer", "Geteilt", "Neue Liste erstellen", "Liste beitreten", "Erfolgreich beigetreten".

### 2.2 Listen-Detail

- **Datei:** `list_detail_screen.dart`.
- **Route:** `/lists/:listId?name=` (CupertinoPage, `app_router.dart:297-322`); Aliase `/list/:id` und `/invite/:id` leiten nur um (`app_router.dart:356-365`, 459-466). Unterroute `/lists/:id/activities`.
- **Hauptfrage:** Was muss ich noch kaufen, und wie trage ich etwas ein?
- **Aufbau oben nach unten:**
  1. Material-`AppBar`, transparent: Zurück-Glas-Kreis links (40 pt in 44 pt), Titel = Listenname in Serifen-Schrift 24 pt, darunter "3 offen · 5 Artikel" in 11 pt; rechts "..."-Menü (native Glas-Popup ab iOS 26) und Teilen-Glas-Kreis.
  2. Fortschritts-Haarlinie 3 pt in Akzentfarbe.
  3. Scrollende Liste (`ListView.builder`): an Index 0 die Karte "KI-Empfehlungen" (erst nach dem Push-Übergang), dann je Kategorie ein Abschnitt (Großbuchstaben-Kopf, Artikelzeilen, unsichtbare Drop-Zone), am Ende der Button "Einkauf abschließen" (54 pt, schwarze/weiße Pille).
  4. Schwebende Bodenleiste (Stack, `Positioned`), fährt mit der Tastatur: oben wahlweise Live-Angebote (beim Tippen ab 2 Zeichen) oder Preis-Leiste (ohne Tastatur), darunter die Eingabeleiste.
- **Artikelzeile (`list_item_tile.dart`):** Kreis-Checkbox 22 pt, Name 15 pt (durchgestrichen und blass, wenn abgehakt), Notiz 12 pt, Preiszeile 11,5 pt in Akzentfarbe ("1,29 € · 500 g · Lidl"), Angebots-Chip, rechts Menge 12 pt und ein Drag-Griff-Icon.
- **Zustände:** leer: `EmptyState` mit Einkaufswagen-Icon, "Leere Liste", "Füge Produkte hinzu, um mit dem Einkaufen zu beginnen", Button "Artikel hinzufügen" (öffnet den Dialog, nicht die Eingabeleiste); laden: nur ohne Cache, Vollbild-`LoadingIndicator` "Artikel werden geladen..."; Fehler: nur Text "Fehler beim Laden", kein Wiederholen; offline: Lesen aus Cache, Schreiben scheitert und wird zurückgerollt (keine Warteschlange); Pro gesperrt: nicht vorhanden; Modul aus: nicht vorhanden, Angebots- und Preis-Elemente erscheinen immer.
- **Aktionen und Gesten:** Tippen linke 2/3 der Zeile = abhaken; Tippen rechts = Bearbeiten-Dialog; Wischen nach links = sofort löschen (Snackbar "Milch Gelöscht", kein Rückgängig); Langdruck 300 ms = Ziehen, in andere Kategorie oder an andere Position, Auto-Scroll am Rand; Eingabe + Senden = Schnell-Hinzufügen (Tastatur bleibt offen); "+" = Anhang-Menü; Tippen auf Empfehlung = hinzufügen; Tippen auf Live-Angebot = Produkt mit Preis hinzufügen; Tippen auf Angebots-Chip = Angebots-Sheet; Menü: Umbenennen, Kategoriereihenfolge, Listeneinstellungen; Teilen-Button = Teilen-Dialog.
- **Nebenwirkungen beim Öffnen:** Ungelesen-Zähler zurücksetzen, App-Badge entfernen, zugestellte Mitteilungen dieser Liste löschen (`list_detail_screen.dart:195-226`), Tutorial-Schritt, Bewertungsdialog, wenn alle Artikel abgehakt sind (`268-291`).
- **Datenquellen:** `itemsNotifierProvider(listId)`, `listsNotifierProvider` (Name), `currentUserProvider` (Diät-Warnung), `mlRecommendationsProvider`, `basketComparisonProvider`, `effectiveZipProvider`, `userZipCodeProvider`, `CategoryOrderService`, `UnreadService`, `NotificationService`, `DynamicTutorialService`, `AppReviewService`.
- **Texte:** "Artikel hinzufügen" (Platzhalter), "offen", "Artikel", "Einkauf abschließen", "Artikel hierher ziehen", "günstigster Korb", "{name} hinzugefügt".

### 2.3 Eingabeleiste (Composer)

- **Datei:** `add_item_composer.dart`. Einstieg: immer am unteren Rand der Liste.
- **Hauptfrage:** Was will ich hinzufügen?
- **Aufbau links nach rechts:** "+"-Kreis (38 pt sichtbar, 44 pt Tippfläche), Glas-Kapsel mit Textfeld (17 pt, wächst bis 5 Zeilen), Senden-Pfeil (30 pt Akzent-Kreis) erscheint mit Skalierung, sobald Text da ist.
- **Material:** auf iOS ein einziger nativer `UIGlassContainerEffect` für Kreis und Kapsel (`LiquidGlassGroup`, Zeilen 203-248), damit beide verschmelzen; mit erhöhtem Kontrast fester Hintergrund.
- **Zustände:** leer, mit Text, mehrzeilig; Reduce Motion schaltet die Senden-Animation ab.
- **Verhalten:** Senden leert das Feld, ruft `onSubmit`, behält den Fokus. Kein Vorschlag aus dem Verlauf, keine lokale Mengen-Erkennung.

### 2.4 Anhang-Menü ("+")

- **Datei:** `attachment_sheet.dart`. Einstieg: "+" in der Eingabeleiste.
- **Hauptfrage:** Woher soll Avo die Liste lesen?
- **Aufbau:** schwebendes Glas-Panel (Radius 32), links unten verankert, max. 82 % Breite, ohne Abdunklung. Erklärtext 13 pt, drei Zeilen mit farbigen Kreis-Icons 40 pt und 20-pt-Beschriftung: Kamera, Fotos, Dateien.
- **Zustände:** Menü, Verarbeitung (Spinner, "Avo liest deine Liste...", Abbrechen), Fehler (Text je Fehlercode, "Erneut versuchen", "Andere Datei wählen"), Kamera verweigert ("Einstellungen öffnen", "Zurück").
- **Gesten:** wächst aus dem "+" (Skalierung von 0,15 mit `easeOutBack`, 380 ms), Ziehen nach unten folgt dem Finger, Loslassen nach Geschwindigkeit; Tippen daneben schließt.
- **Datenquellen:** `ImagePicker`, `FilePicker` (jpg, png, heic, webp, pdf), `ListImportService`.
- **Texte:** "Importiere eine Einkaufsliste vom Papier - Avo liest die Artikel automatisch aus.", "Kamera", "Fotos", "Dateien", "Avo liest deine Liste...".

### 2.5 Import-Prüf-Sheet

- **Datei:** `import_review_sheet.dart`. Einstieg: nach erfolgreicher Erkennung, strikt nach dem Schließen des Anhang-Menüs.
- **Hauptfrage:** Stimmen die erkannten Artikel?
- **Aufbau:** Bottom-Sheet bis 60 % Höhe, Blur-Hintergrund, Griff, Titel "{count} Artikel erkannt", Untertitel, Liste editierbarer Zeilen (Name, Menge 42 pt breit, Einheit 44 pt breit, Fragezeichen bei geringer Sicherheit, Minus-Button), unten "Abbrechen" und "{count} importieren".
- **Zustände:** Zeilen mit Sicherheit < 0,75 bei 55 % Deckkraft; leer: "import_review_empty"; Import-Button aus bei 0 gültigen Zeilen.
- **Gesten:** Wischen nach links löscht Zeile, Minus löscht Zeile.
- **Nicht genutzt:** `unparsedLines` aus dem Ergebnis wird nirgends angezeigt (grep: nur in `list_import_service.dart`).

### 2.6 Artikel-Dialog (Hinzufügen / Bearbeiten)

- **Datei:** `item_form_dialog.dart`. Einstieg: Tippen rechts in einer Zeile (Bearbeiten), Button im leeren Zustand (Hinzufügen).
- **Hauptfrage:** Wie viel wovon, mit welcher Notiz?
- **Aufbau:** zentrierter Material-Dialog (Radius 20, Creme-Fläche im Hellmodus): Serifen-Titel 22 pt und Schließen-Kreis 32 pt; bei Bearbeiten "Hinzugefügt von" mit Avatar (tippbar, öffnet `/author/:id`); Felder Name, Menge, Einheiten-Pillen (Hinzufügen: pcs, kg, g, l, ml, pack; Bearbeiten: alle `Categories.units`), Notiz; unten Löschen-Kachel (rot) und "Speichern" bzw. "Artikel hinzufügen" (`PaperPrimaryButton`, 52 pt).
- **Fehlt:** Kategorie ändern, Preis, Bild, Diät-Hinweis.
- **Zustände:** Speichern sperrt Doppel-Tippen; Fehler als roter Snackbar mit Roh-Fehlertext.

### 2.7 Teilen-Dialog

- **Datei:** `share_list_dialog.dart`. Einstieg: Teilen-Button im Listenkopf.
- **Hauptfrage:** Wie lade ich jemanden ein?
- **Ablauf:** erst Netzwerkaufruf `generateShareCode` plus Neuladen aller Listen, dann Dialog. Code 28 pt, Laufweite 6, Tippen kopiert; Buttons "Code" (System-Teilen mit Text) und "Link" (`https://shoplyai.app/list/<listId>`, mit Einkaufswagen-Emoji im Text).
- **Texte:** "Teilen-Code", "Nutze diesen Code um der Liste beizutreten", "Tippen zum Kopieren".

### 2.8 Umbenennen

- **Datei:** `list_detail_parts.dart:11-60`. `CupertinoAlertDialog` mit Textfeld. Speichern wartet auf Server und Neuladen aller Listen.

### 2.9 Einkauf abschließen

- **Datei:** `shopping_trip_completion.dart`, `checkout_store_sheet.dart`. Einstieg: Button am Listenende.
- **Hauptfrage:** Bin ich fertig, und was kommt in den Verlauf?
- **Ablauf:** keine abgehakten Artikel: Alert "Bitte wähle ein oder mehrere Produkte aus..."; sonst Bestätigungs-Alert "Einkauf abschließen? {count} ausgewählte Artikel werden im Verlauf gespeichert und von der Liste entfernt."; dann GPS + Overpass-Suche nach Märkten in der Nähe; nur bei Unklarheit das Sheet "In welchem Markt warst du?" (Markt-Kacheln, freie Eingabe, Überspringen); Verlauf speichern, abgehakte Artikel löschen, Push an Mitglieder, Meilenstein-Text oder "{count} Artikel erfolgreich abgeschlossen!" (mit Häkchen-Emoji im String) als grüner Snackbar, bei mehreren Mitgliedern Aktion "Kosten teilen".

### 2.10 Listeneinstellungen

- **Datei:** `list_settings_screen.dart`. Einstieg: Menü "Listeneinstellungen" (MaterialPageRoute, keine GoRoute).
- **Hauptfrage:** Wer ist auf dieser Liste, und will ich sie verlassen oder löschen?
- **Aufbau:** `PaperSettingsAppBar`, Listenname in Serifen 15 pt, Kicker "MITGLIEDER" (Großbuchstaben 10 pt, Laufweite 2), Mitgliederzeilen mit Initialen-Avatar (Creme), "(Du)", "Ersteller", Entfernen für den Ersteller; Kicker "AKTIONEN": "Liste verlassen" (Mitglied) oder "Liste löschen" (Ersteller) mit Hinweis.
- **Zustände:** laden: Vollbild-Spinner; Fehler: still, leere Liste.
- **Dialoge:** Mitglied entfernen, Liste verlassen, Liste löschen (alle `CupertinoAlertDialog`).

### 2.11 Kategoriereihenfolge

- **Datei:** `category_order_screen.dart`. Einstieg: Menü, Vollbild-Dialog.
- **Hauptfrage:** In welcher Reihenfolge gehe ich durch den Markt?
- **Aufbau:** Hinweis "Ziehen zum Sortieren", `ReorderableListView` aller 29 Kategorien plus eigene Kategorien, Plus-Button für eigene Kategorie, Sheet mit Name und Farbwahl, Löschen mit Bestätigung.
- **Speicherort:** nur dieses Gerät (`category_order_service.dart:12-56`).

### 2.12 Aktivitäten

- **Datei:** `list_activities_screen.dart`. Route `/lists/:id/activities`.
- **Hauptfrage:** Was haben andere auf der Liste geändert?
- **Aufbau:** nach Datum gruppierte Karten mit Blur, leerer Zustand "Keine Aktivitäten", "Verlauf löschen".
- **Status:** verwaist, siehe 4.

### 2.13 Live-Angebote, Preis-Leiste, Angebots-Sheet, PLZ-Sheet (eingebettet, Modul "Angebote")

- **Dateien:** `offer_suggestions_bar.dart`, `list_price_summary_bar.dart`, `item_offer_sheet.dart`, `zip_code_sheet.dart`. Hier nur als Teil der Liste erfasst; Details gehören ins Angebots-Inventar.
- **Live-Angebote:** Karte über der Eingabe, 3 sichtbare Zeilen à 72 pt, Kicker "ANGEBOTE IN DER NÄHE", Produktbild, Preis, Grundpreis, "endet in X Tagen"; Tippen fügt Produkt mit Preis und Händler hinzu.
- **Preis-Leiste:** "23,40 € günstigster Korb" oder "bekannte Summe"; Tippen öffnet Vergleich aller Märkte inklusive "Näherer Markt"-Option. **Widerspricht dem Plan** (Korbsumme pro Markt ist verworfen).
- **Angebots-Chip pro Zeile:** nutzt `comparison.cheapestOfferFor(name)` über alle Märkte (`list_category_section.dart:220-222`), also ebenfalls Markt-Vergleich.

### 2.14 KI-Empfehlungen

- **Datei:** `ml_recommendations_section.dart`, `recommendation_card.dart`. Einstieg: erste Zeile der Liste.
- **Aufbau:** eingeklappte Karte mit Funkel-Icon, Serifen-Titel "KI-Empfehlungen", "Basierend auf deinen Einkäufen", Pfeil; aufgeklappt bis 5 Zeilen mit Grund ("Oft gekauft", "Wieder Zeit zu kaufen") und Plus-Button.
- **Zustände:** laden: Karte mit Spinner; leer und Fehler: verschwindet.

---

## 3. Design-Probleme heute

### 3.1 Abweichungen von den Apple-Regeln

- **Kein Large Title, keine Glas-Navigationsebene.** Material-`AppBar` mit transparentem Hintergrund und eigenem Spalten-Titel (`list_detail_screen.dart:313-363`). Inhalt scrollt nicht unter eine Glas-Leiste, kein Scroll-Edge-Effekt; stattdessen harte Haarlinie (`list_detail_screen.dart:369-380`, `list_detail_parts.dart:139-162`).
- **Versteckte Gesten statt sichtbarer Bedienung:** Liste löschen per Langdruck (`home_screen.dart:457`), Liste beitreten per Langdruck auf "+ Neue Liste" (`home_screen.dart:363`), Zeile in zwei unsichtbare Tippzonen geteilt (`list_item_tile.dart:259-387`). Kein Kontextmenü, kein Wischen zum Abhaken.
- **Irreführendes Icon:** Drag-Griff rechts in der Zeile (`list_item_tile.dart:379-383`) öffnet beim Tippen den Bearbeiten-Dialog; Ziehen geht per Langdruck überall.
- **Löschen ohne Rückgängig:** Wischen löscht sofort, Snackbar ohne "Rückgängig" (`list_item_tile.dart:58-81`, `144-166`); Löschen im Dialog ebenfalls (`item_form_dialog.dart:161-178`). Umgekehrt braucht der nicht endgültige Abschluss einen Bestätigungs-Alert (`shopping_trip_completion.dart:54-79`). Apple-Prinzip Agency ist damit an beiden Stellen verletzt.
- **Dialog statt Sheet:** Artikel bearbeiten als zentrierter Material-Dialog (`item_form_dialog.dart:28-32`, `203-346`); Teilen als eigener Dialog statt System-Teilen mit Einladungs-Vorschau (`share_list_dialog.dart:36-57`).
- **Bewegung mit festen Dauern statt Federn:** Anhang-Menü 380/260 ms mit `easeOutBack` (`attachment_sheet.dart:89-93`, `140-156`), Senden-Button 180 ms `easeOutBack` (`add_item_composer.dart:387-398`), Checkbox 200 ms (`list_item_tile.dart:270-271`), Empfehlungen 250 ms (`ml_recommendations_section.dart:104-146`), Drop-Hover 150/200 ms.
- **Haptik zu oft:** leichter Stoß schon beim Tippen auf "+" (`add_item_composer.dart:315`), schwerer Stoß beim Wischen-Löschen (`list_item_tile.dart:161`), Auswahl-Klick beim Öffnen des Editors (`list_item_tile.dart:95`).
- **Material-Icons statt SF Symbols:** `Icons.shopping_cart`, `Icons.delete`, `Icons.check_rounded`, `Icons.drag_indicator`, `Icons.close_rounded`, `Icons.copy_rounded`, `Icons.numbers_rounded`, `Icons.auto_awesome`, `Icons.people_outline` (u. a. `list_detail_screen.dart:405`, `list_item_tile.dart:155`, `item_form_dialog.dart:239`, `share_list_dialog.dart:163,192`, `ml_recommendations_section.dart:43`, `home_screen.dart:937`).
- **Touch-Ziele unter 44 pt:** Schließen-Kreis 32 pt (`item_form_dialog.dart:229-244`), Senden-Pfeil 38 pt Tippfläche (`add_item_composer.dart:407-409`), Minus-Button kompakt (`import_review_sheet.dart:324-332`), "+ Neue Liste" als 12-pt-Textlink (`home_screen.dart:361-374`), Teilen-Glas 36 pt sichtbar (`list_detail_parts.dart:128`).
- **Fehlertexte technisch:** roter Snackbar mit `e.toString()` (`list_detail_screen.dart:624-633`, `item_form_dialog.dart:114-124`, `home_screen.dart:618`, `home_screen.dart:701-703`).
- **Glas auf Inhalt:** Aktivitäten-Karten mit `BackdropFilter` (`list_activities_screen.dart:154-160`).
- **Kein Wayfinding beim Teilen:** Teilen-Button lädt erst über das Netz, bevor etwas erscheint (`share_list_dialog.dart:20-34`), also sichtbares Warten ohne Rückmeldung.

### 3.2 Feste Höhen, Breiten und Schriftgrößen (große Schrift, 320 pt)

Die App klemmt den Text-Skalierungsfaktor nirgends (grep `textScaler` in `lib/app.dart`, `lib/main.dart`, `lib/core`: keine Treffer). Dynamic Type wirkt also, und folgende feste Maße brechen:

- **Eingabeleiste (gemeldeter Bug "Text halb abgeschnitten"):** Ursache gefunden. Im iOS-Glas-Pfad liegt der Inhalt in `SizedBox(height: h)` mit `Stack` (`add_item_composer.dart:211-245`). Nicht positionierte Kinder eines Stacks bekommen höchstens diese Höhe. Die Höhe wird aber aus genau diesem Inhalt gemessen (`add_item_composer.dart:111-118`). Der Inhalt kann also nie höher werden als der Startwert 38 pt (`_kControlSize`, Zeile 61), und die Messung bestätigt immer 38. Schon bei Standardgröße ist eine Zeile 17 pt plus 2 x 9 pt Padding knapp über 38 pt (`add_item_composer.dart:172-188`); jede größere Textstufe und jeder Zeilenumbruch wird oben/unten abgeschnitten. Das trifft jedes iOS-Gerät, nicht nur 320 pt.
- Schriftgröße im Composer fest 17 pt (`add_item_composer.dart:173`, `180`).
- Listentitel in der AppBar: Serifen 24 pt plus 11 pt in fester Toolbar-Höhe 56 pt (`list_detail_screen.dart:327-348`) läuft bei großen Stufen über.
- "Einkauf abschließen": `SizedBox(height: 54)` mit einzeiliger Row (`list_detail_parts.dart:176-198`).
- `PaperPrimaryButton` fest 52 pt hoch (`item_form_dialog.dart:383-386`), Teilen-Buttons 52 pt (`share_list_dialog.dart:181`), Löschen-Kachel 52 pt (`item_form_dialog.dart:313`).
- Live-Angebote: feste Zeilenhöhe 72 pt bei 4 Textzeilen 9,5-13,5 pt (`offer_suggestions_bar.dart:19-20`).
- Import-Prüfung: Menge 42 pt und Einheit 44 pt breit (`import_review_sheet.dart:287-313`), bei 320 pt und großer Schrift unlesbar.
- Viele Kleinstgrößen unter Apples Caption-Stufe: 9,5 pt (`offer_suggestions_bar.dart:105,355,433`), 10,5 pt (`list_price_summary_bar.dart:143,222,531,539,545`), 11 pt (`list_detail_screen.dart:344`, `list_category_section.dart:203`, `ml_recommendations_section.dart:63`), 11,5 pt Preise (`list_item_tile.dart:337`).
- Leer-Box und Lade-Box der Übersicht fest 140 pt (`home_screen.dart:394-396`, `466-469`).
- Bodenleisten-Abstand wird mit 110 pt geschätzt und nachgemessen (`list_detail_screen.dart:101-102`, `149-161`), das erste Bild kann Zeilen unter der Leiste verstecken.

### 3.3 Paper-Reste (müssen im Redesign verschwinden)

- **Serifen:** Listentitel (`list_detail_screen.dart:335`), Listen-Übersicht Nummer und Name (`home_screen.dart:898`, `910`), Artikel-Dialog-Titel (`item_form_dialog.dart:227`), Empfehlungs-Titel (`ml_recommendations_section.dart:54`), Listeneinstellungen (`list_settings_screen.dart:244`, `396`), Markt-Sheet (`checkout_store_sheet.dart:91`), Angebots-Teaser (`home_screen.dart:543`).
- **Großbuchstaben-Kicker:** Kategorie-Köpfe 11 pt, Laufweite 2 (`list_category_section.dart:200-207`), "DEINE LISTEN" (`home_screen.dart:352-358`), "ANGEBOTE IN DER NÄHE" (`offer_suggestions_bar.dart:103`), "AKTUELLES ANGEBOT" (`item_offer_sheet.dart:204`), `PaperSectionHeader` (`paper_settings.dart:146-151`).
- **Creme und Terrakotta:** Hintergrund `#F7F3EC` und Akzent `#C0502A` als App-Standard (`app_colors.dart:41`, `69`, `72`); `PaperColors.surface/paper/cream/creamInk/muted` in Artikel-Dialog, Teilen-Dialog, Empfehlungen, leerer eigener Kategorie, Notizen (`item_form_dialog.dart:183-185`, `share_list_dialog.dart:102`, `recommendation_card.dart:37,44`, `list_category_section.dart:254-272`, `list_item_tile.dart:321`); Avo-Streifen hart `#EFE8DA` (`home_screen.dart:287`).
- **Paper-Ornamente:** Fortschritts-Haarlinie (`list_detail_parts.dart:139-162`, `home_screen.dart:937-947`), nummerierte "Editorial"-Zeilen "01, 02" (`home_screen.dart:898`), schwarze "Tinte"-Pille (`list_detail_parts.dart:165-203`).
- **Kontrast:** tertiäre Textfarbe `#B5AB97` auf `#F7F3EC` (`app_colors.dart:62`) für Platzhalter, abgehakte Artikel und den leeren Checkbox-Rand (`add_item_composer.dart:179`, `list_item_tile.dart:246-306`) liegt deutlich unter 4,5:1.

### 3.4 Anti-Slop

- Reihen gleichförmiger Karten: Empfehlungs-Karte plus Preis-Leiste plus Angebots-Karte konkurrieren mit der Liste.
- Icons in getönten Kreisen im Anhang-Menü (`attachment_sheet.dart:492-499`) sind hier Messages-Muster und vertretbar; die Creme-Initialen-Avatare sind es nicht.
- Erfundene Gründe: "Beliebtes Produkt" für feste Startvorschläge (`ml_recommendation_service.dart:583-606`).

---

## 4. Bugs, Risiken und Performance

### 4.1 Bugs

1. **Eingabeleiste schneidet Text ab**, Ursache siehe 3.2 (`add_item_composer.dart:111-118`, `211-245`).
2. **Frisch hinzugefügter Artikel ist 1-3 s lang nicht bedienbar.** Der optimistische Platzhalter hat die ID `pending-...` (`items_provider.dart:250`). Abhaken ruft `updateItem` mit dieser ID, `.single()` wirft, es gibt Rollback und Fehler (`item_repository.dart:244-249`). Löschen des Platzhalters wird vom späteren Reconcile rückgängig gemacht: der Artikel taucht wieder auf (`items_provider.dart:289-290`).
3. **Artikel springt nach dem Hinzufügen die Kategorie.** Platzhalter ohne Kategorie landet in "Sonstiges" (`list_category_section.dart:52`), erst nach KI-Parsing, Merge-Abfrage und Gemini-Kategorisierung (Wartezeit mindestens 1,1 s, `gemini_categorization_service.dart:21`) springt er an die richtige Stelle. Bei "2 Milch" steht bis dahin "2 Milch" mit Menge 1 da, weil die Mengen-Erkennung ein LLM-Aufruf ist (`item_repository.dart:106-125`).
4. **Gelernte Kategorien wirken nie.** Ziehen in eine andere Kategorie speichert den lokalisierten Gruppennamen als Vorliebe (`list_category_section.dart:147`), `SmartCategorizationService` vergleicht mit deutschen `ProductCategory.displayName` (`smart_categorization_service.dart:238-245`), und `addItem` nutzt diesen Dienst gar nicht, sondern Gemini (`item_repository.dart:172`). `CategoryDetector.detectCategory` wird nirgends aufgerufen (grep).
5. **Import-Wiederholung verdoppelt Mengen.** `importItems` schreibt nacheinander (`items_provider.dart:323-332`); scheitert Artikel 7 von 10, wird alles optimistisch zurückgerollt, die ersten 6 stehen aber schon in der Datenbank. "Erneut versuchen" (`list_detail_screen.dart:606-614`) fügt alle 10 erneut hinzu, das Zusammenführen addiert die Mengen der ersten 6.
6. **Anhang-Menü kann im Lade-Zustand hängen bleiben.** `_process` fängt nur `ListImportException` (`attachment_sheet.dart:238`). Fehler aus PDF-Rendering (`list_import_service.dart:106-125`) oder aus den Pickern (`attachment_sheet.dart:206-223`, ohne try) bleiben unbehandelt, der Spinner bleibt.
7. **Teilen macht alte Codes ungültig.** Jeder Tipp auf Teilen erzeugt einen neuen Code und überschreibt den alten (`share_list_dialog.dart:22`, `list_repository.dart:142-156`). Keine Prüfung auf Kollision des 6-stelligen Codes.
8. **Teilen per Link führt zu keinem Beitritt.** Der Link enthält die Listen-ID (`share_list_dialog.dart:52`), der Router leitet nur auf `/lists/:id` um (`app_router.dart:459-466`), ein Beitritt über Link wird im Client nirgends ausgelöst (grep `joinListWithLink`: nur Definition). Ein Nicht-Mitglied sieht vermutlich eine leere Liste (RLS nicht geprüft).
9. **Diät-Warnung wird gespeichert, aber nie angezeigt** (`list_detail_screen.dart:618-622`, `item_form_dialog.dart:142-143`; grep `isDietWarning` in Zeilen-Widgets: keine Treffer). Bei Allergien ein Verantwortungs-Problem.
10. **Kommazahlen gehen verloren.** "1,5" im Mengenfeld wird zu 1 (`item_form_dialog.dart:112`); beim Hinzufügen gibt es nur eine Zahlentastatur ohne Komma (`item_form_dialog.dart:269-271`). Widget schneidet Mengen ab (`items_provider.dart:146`, `quantity.toInt()`).
11. **Eigene Kategorien sind nur lokal.** Reihenfolge und eigene Kategorien liegen in SharedPreferences (`category_order_service.dart:12-56`), die Artikel bekommen aber eine `custom_...`-ID in der geteilten Datenbank. Beim Partner landen sie unter "Sonstiges" (`list_category_section.dart:53-54`).
12. **Aktivitäten-Screen ist tot.** Kein Aufruf von `navigateToListActivities` (grep), `ListActivityService.logActivity` wird nie aufgerufen (grep), Daten nur lokal. Der Screen ist immer leer.
13. **Listen-Hintergründe existieren nur noch im Provider.** `saveBackground` (`lists_provider.dart:177-190`) hat keine UI mehr (grep `background_type` in `lib/presentation`: nur Provider).
14. **`reorderLists` ist tot und würde scheitern:** schreibt `order_index` auf `shopping_lists`, laut eigenem Kommentar keine Spalte (`list_repository.dart:49-50`, `lists_provider.dart:192-215`).
15. **Push-Texte hart auf Englisch:** "checked off", "removed", "added", "Someone", "New List Member!" (`item_repository.dart:267-270`, `297`, `369`, `393`; `list_repository.dart:213-220`). Der Abschluss-Push nutzt die Sprache des Absenders (`shopping_trip_completion.dart:227-236`).
16. **Empfehlungs-Gründe hart auf Deutsch** ("Oft gekauft", "Passt gut dazu", "Wieder Zeit zu kaufen", "Beliebtes Produkt") und deutsche Startartikel auch für englische Nutzer (`ml_recommendation_service.dart:78`, `90`, `101`, `155`, `583-606`).
17. **Import-Sprache falsch:** Locale kommt aus `userMetadata`, Standard `de-DE`, nicht aus der App-Sprache (`list_import_service.dart:192-194`). HEIC wird bei Fehlschlag roh mit `image/jpeg` hochgeladen (`list_import_service.dart:149-156`, `166`). Nur Seite 1 eines PDFs (`list_import_service.dart:109`).
18. **Abschluss nicht atomar:** erst Verlauf speichern, dann löschen (`shopping_trip_completion.dart:97-106`). Scheitert das Löschen, steht der Einkauf im Verlauf, die Artikel bleiben, ein zweiter Versuch speichert doppelt.

### 4.2 Performance

- **Jeder Abhak-Tipp löst eine Kaskade aus:** Update + Select, `_touchList`-Update (`item_repository.dart:252`, `320-329`), Push-Fan-out mit zwei weiteren Abfragen (`item_repository.dart:268-276`, `386-405`), Realtime-Echo der eigenen Änderung mit vollem Neuladen der Liste nach 300 ms (`items_provider.dart:81-90`), und über den globalen Kanal ein volles Neuladen aller Listen mit Zähl-Embeds (`list_repository.dart:281-301`, `lists_provider.dart:56-61`), inklusive `warmListItems`, Widget-Update und Kaufstatistik-Abfrage für das Widget (`lists_provider.dart:80-88`). Beim Einkaufen mit 20 Artikeln sind das über 100 Anfragen.
- **Push pro Abhaken an alle Mitglieder** (`item_repository.dart:267-276`): im Einkaufsmodus Mitteilungs-Spam.
- **Globaler Realtime-Kanal ohne Filter** auf `shopping_items` und `shopping_lists` (`list_repository.dart:282-300`).
- **Listen-Übersicht springt:** jede Artikeländerung setzt `updated_at` der Liste (`item_repository.dart:320-329`), die Übersicht sortiert nach `updatedAt` (`home_screen.dart:415`).
- **Layout-Sprünge in der Liste:** Empfehlungs-Karte erscheint erst nach dem Übergang oben (`list_detail_screen.dart:441-446`) und schiebt alles nach unten; sie zeigt bei jeder Namensänderung wieder den Lade-Zustand (`ml_recommendations_section.dart:152-163`, Provider `ml_recommendations_provider.dart:23-38`) und ruft dabei Gemini für Ergänzungen (`ml_recommendation_service.dart:549-580`) und lädt 50 Einkäufe (`ml_recommendation_service.dart:45-52`). Preis-Leiste erscheint und verschwindet mit der Tastatur (`list_detail_screen.dart:516-525`).
- **Bodenleiste misst sich pro Tastendruck neu** (`list_detail_screen.dart:497`) und setzt bei Änderung `setState` auf den ganzen Screen (`list_detail_screen.dart:158`), was die ganze Liste neu baut.
- **Import langsam:** pro Artikel Merge-Abfrage, Gemini-Kategorie mit 1,1-s-Abstand, Insert und Touch, nacheinander (`items_provider.dart:323-332`). 20 Artikel dauern über 25 s.
- **Ziehen:** jede Zeile ist `DragTarget` plus `LongPressDraggable` plus `Dismissible` (`list_item_tile.dart:107-171`); Auto-Scroll per `Timer.periodic(16 ms)` statt Ticker (`list_drag_controller.dart:79-82`).
- **Offline:** Schreiben ohne Warteschlange; offline scheitert jede Mutation und wird zurückgerollt (grep nach Queue in `lib/data/services`: kein Treffer).
- **Listen-Mutationen nicht optimistisch:** Anlegen, Umbenennen, Löschen warten auf Server und volles Neuladen (`lists_provider.dart:138-152`). Anlegen sind zwei nicht atomare Inserts (`list_repository.dart:83-93`).

### 4.3 Risiken

- Abschluss fragt bei jedem Einkauf GPS ab und sendet die Position an Overpass (`shopping_trip_completion.dart:181-203`); im Konzept als Opt-in mit Erklärung behandeln.
- Angebots-Funktionen in der Liste (Preis-Leiste "günstigster Korb", Markt-Vergleich, `cheapestOfferFor`) widersprechen dem Plan und haben weder Modul-Schalter noch Kill-Switch (grep `isPremium|module` in `screens/lists`: keine Treffer).
- Keine Pro-Kennzeichnung oder Sperre im Listen-Kern.

---

## 5. Abhängigkeiten zu anderen Bereichen

- **`itemsNotifierProvider` / `ItemRepository`** werden auch genutzt von: Avo (`avo_assistant_service.dart`, `avo_chat_screen.dart`), Rezepte (`select_list_bottom_sheet.dart`), Angebote (`weekly_deals_screen.dart`, `price_comparison_provider.dart`), Home (`avo_nudge_card.dart`), App-Start/Siri/Widget-Handler (`lib/app.dart`). Der Provider ist bewusst nicht `autoDispose` (`items_provider.dart:436-451`), weil Avo, Siri und Scanner lange Schreibvorgänge darauf ausführen.
- **`listsNotifierProvider` / `userListsProvider`** zusätzlich in Profil, Avo-Payload-Karten, Rezepte, Angebote.
- **`PaperPrimaryButton`** aus `item_form_dialog.dart` wird von Login, Signup, Welcome, OTP und Onboarding importiert; beim Entfernen der Paper-Optik dort mit ersetzen.
- **iOS-Widget:** `WidgetService.updateShoppingListWidget` bei jedem Commit (`items_provider.dart:135-154`), `updateAvailableLists` und `updateRecentItems` beim Laden der Listen (`lists_provider.dart:84-88`).
- **Offline-Cache:** `OfflineCacheService` (Seed der Artikel im ersten Bild, `items_provider.dart:51-55`; Listen-Cache).
- **Benachrichtigungen:** `PushNotificationService`, `NotificationService`, `UnreadService`, `FlutterAppBadger`.
- **Verlauf und Kosten teilen:** `ShoppingHistoryService.completeShoppingTrip`, `showSplitCostSheet` (`screens/history/widgets/split_cost_sheet.dart`), `MascotNotificationService` (Meilensteine), `PurchaseTrackingService`.
- **Standort und Märkte:** `UserLocationService`, `StoreLocatorService`, `CheckoutStoreResolver`, `effectiveZipProvider`, `basketComparisonProvider`.
- **KI:** `GeminiCategorizationService` (Kategorie, Mengen-Parsing, Empfehlungen), Edge Function `extract-shopping-list`, Storage-Bucket `list-imports`. Laut Plan alles künftig über Claude.
- **Tutorial:** `DynamicTutorialService` hängt Schlüssel an Listen-Bereich, Eingabeleiste und erste Listenzeile (`list_detail_screen.dart:382`, `528`; `home_screen.dart:448-450`).
- **Router:** `/lists/:id`, `/list/:id`, `/invite/:id`, `/lists/:id/activities`, `/author/:id` (aus "Hinzugefügt von"); `DeepLinkService` erzeugt Einladungs-Links `.../invite/<listId>` (`deep_link_service.dart:244`).
- **Strings:** alle über `context.tr` / `AppLocalizations` in `lib/core/localization/app_translations.dart` (DE und EN), z. B. `add_item`, `empty_list_hint`, `items_open_suffix`, `import_*`, `complete_shopping*`, `trip_completed_items`, `cheapest_basket`, `drag_items_here`, `your_lists`, `new_list_plus`, `items_left`.
- **Gemeinsame Komponenten:** `LiquidGlassGroup` / `LiquidGlassContainer` (`widgets/common/liquid_glass_container.dart`), `adaptive_platform_ui` (Glas-Buttons, Popup, Alerts), `EmptyState`, `LoadingIndicator`, `PaperSettingsAppBar`, `PaperSectionHeader`, `confirmDestructive`.
- **Kategorien:** `core/constants/categories.dart` (29 IDs, Farben, Namen DE/EN), `CategoryOrderService`, `CustomCategory`.
- **Diät:** `DietChecker`, `currentUserProvider.dietPreferences`.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**

- Beliebig viele Listen; anlegen, umbenennen, löschen (Ersteller), verlassen (Mitglied), Mitglieder sehen und entfernen.
- Teilen per Code und per Link, Beitreten per Code; Deep Links `/list/:id` und `/invite/:id` inklusive Merken des Links bei abgemeldetem Nutzer (`app_router.dart:400-403`, `440-444`).
- Echtzeit-Abgleich geteilter Listen, Push an Mitglieder bei Hinzufügen, Löschen, Abhaken, Abschluss, Beitritt.
- Artikel mit Name, Menge, Einheit, Notiz, Kategorie, Preis (Betrag, Währung, Händler, Einheit, alter Preis, Zeitpunkt), Barcode, Diät-Warnung, "hinzugefügt von", Reihenfolge.
- Zusammenführen gleichnamiger offener Artikel nur bei gleicher Einheit (`item_repository.dart:127-165`), Groß-/Kleinschreibung egal, `%` und `_` maskiert.
- Automatische Kategorie mit sprachneutralen IDs (`'dairy'` usw.), Anzeige in aktueller Sprache, Rückfall `item.categoryId ?? item.category`, Rückfall auf Schlüsselwörter, wenn die KI ausfällt.
- Gruppierung nach Kategorie in eigener Reihenfolge, eigene Kategorien mit Farbe, Ziehen zwischen Kategorien und innerhalb.
- Abhaken, Bearbeiten, Löschen (mit Rückgängig neu einzuführen), Schnell-Hinzufügen mit offener Tastatur.
- Foto-, Kamera-, Datei- und PDF-Import mit Prüf-Sheet, Abbrechen während der Verarbeitung, typisierte Fehler, Kamera-Berechtigung, Löschen des Uploads (Privatsphäre).
- Empfehlungen aus dem eigenen Kaufverhalten (Häufigkeit, Nachkauf-Rhythmus, "oft auf dieser Liste").
- Einkauf abschließen: Verlauf, Markt-Erkennung (still, nur bei Unklarheit fragen), Kaufstatistik, Kosten-teilen-Angebot, Meilensteine.
- Bewertungs-Anfrage nach vollständig abgehakter Liste (gedrosselt).
- Widget-Synchronisierung (Artikel, Listenauswahl, häufige Artikel).
- Zuletzt geöffnete Liste pro Nutzer lokal (Basis für "Startseite = Liste von heute").
- Angebote in der Liste nur als abschaltbares Modul; die erlaubte Form laut Plan ("4 von 11 Artikeln diese Woche bei Lidl im Angebot ..."), nicht der Korb-Vergleich.

**Daten und Technik**

- Optimistische Mutationen mit Rollback, Generationszähler gegen veraltete Ladevorgänge, Zurückhalten von Realtime-Echos während Schreibvorgängen (`items_provider.dart:23-203`).
- Erstes Bild aus dem Speicher-Cache ohne Spinner (`items_provider.dart:43-55`, `lists_provider.dart:33-54`), Vorwärmen der Artikel aller Listen.
- Realtime-Kanal pro Liste nur, solange jemand zusieht (`items_provider.dart:444-451`).
- Reihenfolge als `order_index`, ungeordnete Artikel nach Erstellzeit, total sortiert in SQL (`item_repository.dart:42-53`).
- Gemini-Mindestabstand 1100 ms (Projektregel), solange Gemini genutzt wird.
- Dynamic Type darf nicht geklemmt werden; Erhöhter Kontrast / Reduzierte Transparenz schalten Glas ab (`add_item_composer.dart:135-137`, `attachment_sheet.dart:270-300`), Reduce Motion ersetzt die Morph-Animation durch Überblenden (`attachment_sheet.dart:137-139`).
- Native Glas-Verschmelzung von "+" und Eingabefeld (`LiquidGlassGroup`) als Baustein; nur die Höhenlogik muss neu.

**Sonderfälle**

- Artikel mit unbekannter eigener Kategorie fallen auf "Sonstiges" zurück.
- Artikel, die in eine andere Liste verschoben werden, verschwinden aus der aktuellen (`items_provider.dart:217-225`).
- Gelöschter Artikel, den ein anderes Mitglied schon entfernt hat, ist kein Fehler (`item_repository.dart:289`).
- Angebots-Produkt wird ohne KI-Parsing übernommen, damit Name und Größe nicht umgeschrieben werden (`list_detail_screen.dart:667-669`).
- Import-Zeilen mit geringer Sicherheit sichtbar, aber gekennzeichnet.
- Listenname vom Mitglied umbenannt: Kopf aktualisiert sich live (`list_detail_screen.dart:297-306`).
- Signiert-aus-Zustand: Listen-Provider liefert leere Liste und öffnet keinen Kanal (`lists_provider.dart:43-54`).
