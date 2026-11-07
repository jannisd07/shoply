# Inventar: Listen-Nebenscreens und Angebote in der Liste

Stand: 07.11.2026, Branch `main` (3e886d0). Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf diesen Stand.

Vorbemerkung zum Umfang: Drei Dateien aus dem Auftrag gibt es nicht mehr.
- `lib/presentation/screens/lists/list_background_*.dart` und `widgets/background_selection_sheet.dart` wurden im Commit `e3ab902` ("split list detail screen…") gelöscht. Übrig sind nur Reste: `lib/core/constants/list_background_gradients.dart` (218 Zeilen, 15 Verläufe "Northern Lights" usw., nirgends mehr benutzt), `ListsNotifier.saveBackground` (`lists_provider.dart:177-190`, kein Aufrufer), `ListRepository.saveBackground` und die Felder `background_type/background_value/background_image_url` in `shopping_list_model.dart:21,41,74,98`. Listen-Hintergründe sind heute also unsichtbar, die Daten liegen aber noch in Supabase.
- `sharing_service.dart` existiert nicht. Teilen läuft über `widgets/share_list_dialog.dart` und `ListRepository.generateShareCode/joinListWithCode/joinListWithLink/getListMembers`. Diese Dateien sind deshalb mit aufgenommen.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/lists/list_settings_screen.dart` | Listeneinstellungen: Mitglieder, Verlassen, Löschen | 432 |
| `lib/presentation/screens/lists/category_order_screen.dart` | Kategorie-Reihenfolge per Drag, eigene Kategorien anlegen/bearbeiten/löschen (inkl. Formular-Sheet) | 536 |
| `lib/presentation/screens/lists/list_activities_screen.dart` | Aktivitätsverlauf einer Liste (Ziel von Push-Tipps) | 344 |
| `lib/presentation/screens/lists/widgets/share_list_dialog.dart` | Teilen-Dialog mit 6-stelligem Code, "Code" und "Link" | 224 |
| `lib/presentation/screens/lists/widgets/checkout_store_sheet.dart` | Sheet "In welchem Markt war das?" beim Einkaufsabschluss | 292 |
| `lib/presentation/screens/lists/widgets/offer_suggestions_bar.dart` | Live-Angebotsvorschläge über der Eingabeleiste beim Tippen, PLZ-Hinweis | 458 |
| `lib/presentation/screens/lists/widgets/list_price_summary_bar.dart` | Chip "X € günstigster Korb [Markt]" über der Eingabeleiste, Marktvergleich-Sheet, PLZ-Chip, `showManualZipDialog` | 551 |
| `lib/presentation/screens/lists/widgets/item_offer_sheet.dart` | `ItemOfferChip` unter dem Artikelnamen und Sheet "Aktuelles Angebot / Preis übernehmen" | 407 |
| `lib/presentation/screens/lists/widgets/zip_code_sheet.dart` | Sheet "Postleitzahl festlegen" | 158 |
| `lib/presentation/screens/lists/widgets/list_detail_menu.dart` | "…"-Menü der Liste (Umbenennen, Kategorie-Reihenfolge, Listeneinstellungen); Einstieg in zwei der Screens | 122 |
| `lib/presentation/providers/price_comparison_provider.dart` | Provider: PLZ, Koordinaten, Märkte in der Nähe, Angebotssuche, Korbvergleich, Startseiten-Highlight, persönliche Deals | 362 |
| `lib/data/services/offer_price_service.dart` | marktguru-Client (inoffiziell, Keys aus Webseite + fest eingebaute Ersatz-Keys), Cache, Drossel, Broad-Match | 343 |
| `lib/data/services/user_location_service.dart` | PLZ aus manuell > GPS-Cache > GPS, Fallback 10115, Koordinaten-Cache | 249 |
| `lib/data/services/store_locator_service.dart` | OpenStreetMap/Overpass: Supermärkte im Umkreis 8 km, Ketten-Normalisierung | 156 |
| `lib/data/services/checkout_store_resolver.dart` | Entscheidet aus Märkten in der Nähe: erkannt / mehrdeutig / unbekannt | 98 |
| `lib/data/services/list_activity_service.dart` | Aktivitäten lokal in SharedPreferences, Push bei Kategorie-Änderungen | 216 |
| `lib/data/services/deep_link_service.dart` | `shoply://` und `https://shoplyai.app/...`, Siri-Aktionslinks, Share-URL-Helfer | 261 |
| `lib/data/services/unread_service.dart` | "zuletzt gesehen" pro Liste in SharedPreferences | 52 |
| `lib/data/services/category_order_service.dart` | Reihenfolge und eigene Kategorien pro Liste, nur lokal | 117 |
| `lib/data/models/store_offer.dart` | `StoreOffer`, `StoreBasketResult`, `BasketComparison` (Ranking, bestStore, closestReasonableAlternative, cheapestOfferFor) | 395 |
| `lib/presentation/widgets/common/paper_settings.dart` | Geteilte Paper-Bausteine: `PaperSettingsAppBar`, `PaperCircleIconButton`, `PaperSectionHeader` (in 11 Dateien benutzt) | 165 |
| `lib/core/constants/list_background_gradients.dart` | Verwaister Rest der Hintergrund-Funktion | 218 |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Listeneinstellungen (`ListSettingsScreen`)
- **Datei:** `list_settings_screen.dart`
- **Einstieg:** Liste > "…"-Menü (`list_detail_menu.dart`, Eintrag `list_settings`, SF Symbol `gearshape`) > `MaterialPageRoute` (`list_detail_screen.dart:754-765`). Keine GoRouter-Route, kein Deep Link.
- **Hauptfrage:** Wer ist in dieser Liste, und will ich sie verlassen oder löschen?
- **Aufbau von oben nach unten:** `PaperSettingsAppBar` (runder Zurück-Button 34 pt, Serifentitel "Listeneinstellungen" 20 pt) > Listenname in Serif 15 pt grau > Kicker "MITGLIEDER" > Mitgliederzeilen (Avatar 36 pt rund, Name + "(Du)", Unterzeile "Ersteller" beim Owner, rechts Minus-Kreis zum Entfernen (nur für Ersteller, nicht beim Owner) oder Chevron) mit 0,5-pt-Trennlinien > Kicker "AKTIONEN" > eine Textzeile "Liste verlassen" (Nicht-Ersteller) oder "Liste löschen" (Ersteller) in Rot > Hinweis "Diese Aktion kann nicht rückgängig gemacht werden" (nur Ersteller).
- **Komponenten:** ListView mit 24 pt Seitenrand, `Image.network`-Avatare mit Initial-Fallback auf Creme-Fläche, `CupertinoAlertDialog` für alle drei Bestätigungen.
- **Zustände:** Laden = Vollbild-`CupertinoActivityIndicator` (Z. 229-230). Leer = nicht vorgesehen. Fehler beim Laden = stilles Leeren der Mitgliederliste (Z. 90-93). Fehler bei Aktionen = SnackBar "action_failed". Offline, Pro-gesperrt, Modul-aus: nicht vorhanden.
- **Aktionen und Gesten:** Tipp auf Mitglied öffnet `/author/:userId`, das Rezept-Autorenprofil (Z. 263-268). Minus-Kreis > Dialog > Mitglied entfernen (direktes `list_members.delete`, Z. 126-131). Verlassen > Dialog > `list_members.delete` für sich selbst, `context.go('/home')`. Löschen > Dialog > `listsNotifier.deleteList`, `context.go('/home')`. Haptik `selectionClick`, `mediumImpact`, `heavyImpact`.
- **Datenquellen:** `listRepositoryProvider.getListMembers` und `getListById` (wenn ownerId fehlt), `SupabaseService` direkt, `listsNotifierProvider`. Keine Echtzeit, kein Neuladen.
- **Texte:** `list_settings` "Listeneinstellungen", `members` "Mitglieder", `actions`, `creator` "Ersteller", `you`, `remove_member`, `remove_member_confirm` "{name} von dieser Liste entfernen?", `leave_list` "Liste verlassen", `leave_list_confirm`, `delete_list_question`, `delete_list_message`, `delete_list` "Liste löschen", `delete_list_hint`. Fest im Code: `'Unknown'` (Z. 69).
- **Fehlt fachlich:** Einladen, Umbenennen, Markt, Angebote ausblenden, Benachrichtigungen pro Liste, Besitz übertragen. Umbenennen liegt im "…"-Menü, Teilen im eigenen Share-Button.

### 2.2 Kategorie-Reihenfolge (`CategoryOrderScreen`)
- **Datei:** `category_order_screen.dart`
- **Einstieg:** "…"-Menü > "Kategoriereihenfolge" (`arrow.up.arrow.down`) > `MaterialPageRoute(fullscreenDialog: true)` (`list_detail_screen.dart:733-752`). Rückgabe `true` bei Änderungen löst Neugruppierung und `loadItems()` aus.
- **Hauptfrage:** In welcher Reihenfolge erscheinen die Kategorien in dieser Liste?
- **Aufbau:** `PaperSettingsAppBar` mit Zurück-Pfeil (obwohl als Vollbild-Dialog von unten geöffnet) und rundem Plus (34 pt) > Hinweis "Zum Sortieren ziehen" 13 pt > `ReorderableListView` aller 29 Systemkategorien plus eigener Kategorien: Farbpunkt 12 pt, Name 15 pt, bei eigenen ein Stift-Icon (16 pt), Drag-Griff (Material `drag_handle_rounded`), 0,5-pt-Trennlinien.
- **Kategorie-Formular (`_CategoryFormSheet`, Z. 362-536):** `showModalBottomSheet` mit `AdaptiveBlurView` (Glas-Sheet), eigener Griff 40x5, Titel 22 pt fett "Kategorie hinzufügen/bearbeiten", `AdaptiveTextField`, "Farbe wählen" (`Colors.grey[600]`), 16 Material-Farbkreise à 44 pt, Buttons `LiquidGlassFilledButton` "Hinzufügen"/"Speichern" und `LiquidGlassOutlinedButton` "Löschen".
- **Zustände:** Laden = Vollbild-Spinner (Z. 174-175). Kein Fehlerzustand. Leer nicht möglich.
- **Aktionen:** Lang drücken und ziehen (Haptik `mediumImpact`, Proxy skaliert auf 1,03), Plus > Formular, Stift > Formular, Löschen > `confirmDestructive` > Kategorie weg, betroffene Artikel serverseitig auf `other` (`category_order_service.dart:96-104`).
- **Datenquellen:** `CategoryOrderService` (SharedPreferences, nur dieses Gerät), `Categories` (Konstanten).
- **Texte:** `category_order`, `drag_to_reorder`, `add_category`, `edit_category`, `category_name`, `category_name_hint`, `select_color`, `delete_category`, `delete_category_confirm`, `add`, `save`, `delete`.

### 2.3 Listenaktivitäten (`ListActivitiesScreen`)
- **Datei:** `list_activities_screen.dart`
- **Einstieg:** nur per Route `/lists/:listId/activities` (`app_router.dart:310-321`), aufgerufen von `NavigationService.navigateToListActivities` beim Tipp auf eine Push mit `type` `list_activity` oder `category_change` (`navigation_service.dart:26-40, 76-80`). Kein sichtbarer Einstieg in der App.
- **Hauptfrage:** Was hat sich in dieser Liste geändert?
- **Aufbau:** `PaperSettingsAppBar` "Listenaktivitäten" mit rundem Mülleimer-Button (nur wenn Einträge) > Gruppen nach Datum ("Heute", "Gestern", Wochentag, Datum) mit Kopf 13 pt grau, Karte mit `BackdropFilter`-Blur und Rand, Zeilen: getöntes Quadrat 36 pt mit Emoji (z. B. "➕", "🛒"), Beschreibungstext 15 pt, Uhrzeit 12 pt.
- **Zustände:** Laden = Vollbild-Spinner. Leer = großes Material-Icon `history` 64 pt, "Keine Aktivitäten", "Aktivitäten werden hier angezeigt". Fehler = wie leer.
- **Aktionen:** Mülleimer > Material-`AlertDialog` mit rotem `TextButton` "Löschen" > lokal leeren.
- **Datenquellen:** `ListActivityService` (SharedPreferences `list_activities_<id>`, max. 100).
- **Texte:** `list_activities`, `no_activities`, `no_activities_desc`, `clear_activities`, `clear_activities_confirm`, `today`, `yesterday`. Beschreibungen hart im Modell `list_activity.dart` (Deutsch/Englisch per `isGerman`).
- **Faktisch tot:** `logActivity` wird nirgends aufgerufen (grep), `notifyCategoryChange` auch nicht. Der Screen ist immer leer.

### 2.4 Teilen-Dialog (`showShareListDialog`)
- **Datei:** `share_list_dialog.dart`
- **Einstieg:** `ListDetailShareButton` in der Kopfzeile der Liste (`list_detail_screen.dart:353-361`).
- **Hauptfrage:** Wie bekommt jemand anderes Zugriff auf diese Liste?
- **Ablauf:** Vor dem Dialog wird bei jedem Öffnen ein neuer Code erzeugt (`generateShareCode`, Netzwerk, ohne Ladeanzeige). Dann Material-`Dialog` (Radius 20, Creme-Papier `PaperColors.surface` hell): Titel 22 pt "share_code_title", Text 14 pt, Code 28 pt w800 Laufweite 6 mit Kopier-Icon (Tipp = Zwischenablage + SnackBar "Code kopiert"), "Tippen zum Kopieren", zwei Buttons nebeneinander à 52 pt: "Code" (teilt Text mit Code) und `PaperPrimaryButton` "Link" (teilt `🛒 Name\n\nhttps://shoplyai.app/list/<listId>`).
- **Zustände:** Fehler beim Code = SnackBar, kein Dialog. Kein Laden, kein Offline.
- **Datenquellen:** `listsNotifierProvider.generateShareCode` > `ListRepository` (`shopping_lists.share_code/share_link/is_shared`), `share_plus`.
- **Beitritt:** nur per Code auf der Startseite (`home_screen.dart:719`, `joinListWithCode`). `joinListWithLink` wird nie aufgerufen.

### 2.5 Markt beim Abschluss (`showCheckoutStoreSheet`)
- **Datei:** `checkout_store_sheet.dart`, Aufruf aus `shopping_trip_completion.dart:181-203`.
- **Einstieg:** Einkauf abschließen > Bestätigung > `_resolveCheckoutStore`: Koordinaten holen, Overpass-Abfrage, `CheckoutStoreResolver.resolve`. Nur bei "mehrdeutig" oder "unbekannt" erscheint das Sheet.
- **Hauptfrage:** In welchem Markt war dieser Einkauf?
- **Aufbau:** Eigenes Sheet mit fester Hintergrundfarbe, Radius 24, Griff 36x4 > Serifentitel 20 pt "In welchem Markt war das?" > Erklärtext 12,5 pt (zwei Varianten: mehrere Märkte / ohne Standortzugriff) > entweder Kandidatenliste (max. 280 pt hoch, Kacheln mit `storefront`-Icon, Name, Adresse 11,5 pt, Entfernung) + "Anderer Markt…" oder Textfeld "z. B. REWE, Lidl, Edeka" + 50-pt-Button "Speichern" > "Überspringen" 13 pt.
- **Zustände:** Kandidaten / manuell / Standort aus. Kein Ladezustand im Sheet; das Warten auf GPS und Overpass passiert vorher ohne Anzeige.
- **Ergebnis:** Name wird als `priceRetailer` an abgehakte Artikel ohne eigenen Händler im Verlauf geschrieben (`shopping_trip_completion.dart:84-92`). Erkannte Märkte liefern `displayName` aus OSM ("REWE City …"), nicht die Ketten-ID.
- **Texte:** `checkout_store_title`, `checkout_store_body`, `checkout_store_location_off_body` (erwähnt "REWE" und "Bananen"), `checkout_store_other`, `checkout_store_hint`, `checkout_store_skip`, `save`.

### 2.6 Live-Angebote beim Tippen (`OfferSuggestionsBar`)
- **Datei:** `offer_suggestions_bar.dart`, eingebaut in `list_detail_screen.dart:502-514` über dem `AddItemComposer`.
- **Einstieg:** Text in der Eingabeleiste mit mindestens 2 Zeichen, 300 ms entprellt (`list_detail_screen.dart:163-181`).
- **Hauptfrage:** Gibt es das, was ich gerade tippe, irgendwo im Angebot?
- **Aufbau:** Karte (Fläche, Rand, Schatten, Radius 18) > Kopf: Icon 12 pt, Kicker "ANGEBOTE IN DER NÄHE" 9,5 pt Versalien mit Laufweite 1,5, rechts optional "Spare bis zu X €" > Liste mit fester Zeilenhöhe 72 pt, sichtbar genau 3 Zeilen, Rest scrollt innen; Zeile: Produktbild 38 pt (Hotlink marktguru-CDN, Creme-Fallback), Produktname 13,5 pt, "Händler · Größe" 11 pt, optional "Ähnliches Produkt" 9,5 pt, optional "Angebot endet heute/in X Tagen" 10 pt orange; rechts "-X%"-Badge, Preis in Serif 15 pt, "statt X €" 10 pt, Grundpreis 9,5 pt, runder Plus-Button 26 pt > optional Fußzeile "Deutschlandweite Angebote — PLZ für lokale Preise festlegen".
- **Zustände:** Keine Angebote + keine echte PLZ = Hinweiskarte "Postleitzahl hinzufügen, um Angebote in der Nähe zu sehen". Keine Angebote mit PLZ = nichts. Laden = nichts (Karte springt später herein). Fehler = nichts.
- **Aktionen:** Tipp auf Zeile fügt Artikel mit Produktname, Preis, Händler hinzu (`_addItemFromOffer`, `list_detail_screen.dart:652-670`), Haptik `lightImpact` dann `mediumImpact`. Tipp auf PLZ-Hinweis öffnet `showZipCodeSheet`.
- **Datenquellen:** `userZipCodeProvider`, `offerSuggestionsProvider(query)`, `offerSearchAllProvider(query)`.
- **Texte:** `offers_nearby`, `cheapest_saves_up_to` "Spare bis zu {amount} €", `similar_product_match`, `offer_ends_today`, `offer_ends_in_days`, `instead_of_price` "statt {price} €", `offers_nationwide_set_zip`, `set_zip_code_prompt`.

### 2.7 Preis-Chip und Marktvergleich (`ListPriceSummaryBar`, `_StoreComparisonSheet`)
- **Datei:** `list_price_summary_bar.dart`, eingebaut in `list_detail_screen.dart:516-525`, nur wenn nicht getippt wird und keine Tastatur offen ist.
- **Hauptfrage (heute):** Wo ist meine Liste am günstigsten? Genau diese Frage ist laut Plan verworfen.
- **Chip-Aufbau:** Zeile mit Quittungs-Icon 15 pt, Text 12,5 pt in drei Varianten: (a) "**X €** günstigster Korb" + Markt-Pille ("Lidl") in Akzentfarbe, (b) "**X €** bekannt (k/n Artikel)" aus eigenen Preisen, (c) "Preise der Märkte in der Nähe vergleichen"; Chevron. Sonderfall Fallback-PLZ ohne Daten: `_ZipPromptChip` "PLZ eingeben, um Angebote in deiner Nähe zu sehen" mit Akzent-Pille "PLZ".
- **Sheet-Aufbau ("Marktvergleich"):** Griff > Serifentitel 20 pt > "Basierend auf {count} Artikeln…" + rechts "PLZ {zip}" mit Stift (öffnet PLZ-Sheet) > Rangliste aller Märkte: Platzierungskreis 26 pt (Platz 1 in Akzent), Name 14 pt, Entfernung, "{m}/{n} hier im Angebot · spart X €", Summe in Serif 16 pt > optional Karte "Näher dran: {store} hat eine Filiale {distance} entfernt — nur {extra} € mehr …" > Trennlinie > "Ganze Liste, geschätzt (k/n Artikel)" "≈ X €" > Fußnoten 10,5 pt: Auffüll-Erklärung, Broad-Match-Warnung (orange), "Nur Angebotspreise …".
- **Zustände:** Nichts bei fehlenden Daten; Sheet öffnet nicht, solange der Vergleich noch lädt (`_showComparisonSheet` returnt still, Z. 162-163). Kein Lade-, Fehler- oder Offline-Zustand.
- **Datenquellen:** `effectiveZipProvider`, `basketComparisonProvider(listId)`, `itemsNotifierProvider(listId)`, `nearbyStoresProvider` (Overpass), `UserLocationService.getManualZipCode`.
- **Texte:** `cheapest_basket` "günstigster Korb", `known_of_items`, `price_data_from_offers`, `enter_zip_prompt`, `store_comparison` "Marktvergleich", `matched_of_items`, `zip_code_label`, `items_on_offer_here`, `saves_amount`, `closer_option_title` "Näher dran", `closer_option_body`, `estimated_list_total`, `comparable_note`, `broad_match_items_note`, `offers_source_note`.

### 2.8 Angebots-Chip am Artikel und Angebots-Sheet (`ItemOfferChip`, `showItemOfferSheet`)
- **Datei:** `item_offer_sheet.dart`; Chip eingebaut in `list_item_tile.dart:343-350`, Angebot kommt aus `basketComparisonProvider` je Kategorie-Sektion (`list_category_section.dart:165-168, 220-222`).
- **Hauptfrage:** Ist dieser Artikel gerade irgendwo im Angebot, und will ich den Preis übernehmen?
- **Chip:** Icon 11 pt + Text 11,5 pt Akzentfarbe: "Spare X € bei {store}" (wenn eigener Preis höher, ab 0,10 €) oder "X € · {store}" (ohne eigenen Preis), ggf. "· Ähnliches Produkt". Erscheint erst, wenn der Korbvergleich fertig ist, und macht die Zeile eine Zeile höher.
- **Sheet:** Griff > Kicker "AKTUELLES ANGEBOT" 10 pt Versalien > Bild 56 pt + Produktname Serif 17 pt (2 Zeilen) + "Marke · Händler · Größe" 12 pt + ggf. orange Hinweis "Über die Kategorie gefunden…" > Preis Serif 26 pt, "statt X €", rechts "-X%"-Badge > Grundpreis > ggf. Akzent-Box "Spart X € gegenüber deinem gespeicherten Preis von Y €" > "Gültig bis {d.m.}" > Button 50 pt "Preis übernehmen" mit Spinner.
- **Aktion:** schreibt `price`, `price_currency`, `price_retailer`, `price_unit`, `price_updated_at`, `price_old_value` in den Artikel (`updateItem`). Fehler: rote SnackBar mit rohem `e.toString()`.
- **Zustände:** kein Laden (Daten liegen vor), Fehler als SnackBar.
- **Texte:** `save_at_store`, `similar_product_match`, `current_offer`, `similar_product_note`, `instead_of_price`, `swap_saves`, `valid_until_date`, `offer_ends_today`, `apply_offer_price` "Preis übernehmen", `error_adding`.

### 2.9 PLZ-Sheet (`showZipCodeSheet`)
- **Datei:** `zip_code_sheet.dart`
- **Einstiege:** `OfferSuggestionsBar` (zwei Stellen), `ListPriceSummaryBar` über `showManualZipDialog` (PLZ-Chip und PLZ-Zeile im Marktvergleich), `weekly_deals_screen.dart:132`.
- **Hauptfrage:** Für welche Region sollen Angebote gelten?
- **Aufbau:** Griff > Serifentitel "Postleitzahl festlegen" > Text "Wird verwendet, um aktuelle Angebote … Du kannst dies jederzeit in deinem Profil ändern." > Textfeld (Ziffern, max. 5, Autofokus) > Button 50 pt "Speichern" mit Spinner.
- **Zustände:** Speichern. Unter 4 Ziffern passiert beim Tippen auf Speichern nichts, ohne Rückmeldung (Z. 50). Kein Löschen, obwohl der Kommentar (Z. 10) "set (or clear)" verspricht.
- **Datenquellen:** `UserLocationService.setManualZipCode`, invalidiert nur `userZipCodeProvider`.

### 2.10 "…"-Menü der Liste (`ListDetailMenuButton`)
- **Datei:** `list_detail_menu.dart`. Auf iOS 26 natives Glas-Popup (`AdaptivePopupMenuButton.icon`, `ellipsis.circle`, 40 pt), sonst `CupertinoActionSheet`.
- **Einträge:** Liste umbenennen (`pencil`), Kategoriereihenfolge (`arrow.up.arrow.down`), Listeneinstellungen (`gearshape`).

### 2.11 Unsichtbare Dienste in diesem Bereich
- **Ungelesen (`UnreadService`):** `markAsRead` wird bei jedem Laden der Artikel (`items_provider.dart:187`), beim Öffnen der Liste (`list_detail_screen.dart:196`) und von Avo (`avo_assistant_service.dart:1884`) geschrieben. `isUnread` wird nirgends gelesen. Es gibt also keine Ungelesen-Anzeige.
- **Deep Links:** `https://shoplyai.app/list/<id>`, `/invite/<id>`, `shoply://list/<id>` landen alle per Router-Alias auf `/lists/:id` (`app_router.dart:354-365, 459-466`); ausgeloggt wird der Link gemerkt und nach dem Login fortgesetzt. Einen Beitritt löst keiner davon aus. Siri-Aktionslinks `shoply://add-item` und `shoply://create-list` laufen über Callbacks in `app.dart`.

---

## 3. Design-Probleme heute

### 3.1 Abweichungen von den Apple-Regeln
- **Glas auf Inhalt:** Aktivitätskarten liegen in `BackdropFilter`-Blur (`list_activities_screen.dart:156-187`). Das ist Glas auf Inhalt, kostet Leistung pro Karte und hat hier nichts zu verwischen.
- **Keine nativen Sheets:** Alle Sheets (`checkout_store_sheet.dart:66-88`, `list_price_summary_bar.dart:296-316`, `item_offer_sheet.dart:177-202`, `zip_code_sheet.dart:63-85`) sind eigene Container mit fester Farbe, Radius 24 und selbstgebautem Griff. Es gibt keine Detents, keine native Teilhöhe, keine Glas-Kante und keine konzentrischen Radien. Nur das Kategorie-Formular nutzt Glas (`category_order_screen.dart:403-406`), mit einem anderen Griff (40x5 statt 36x4). Drei verschiedene Sheet-Stile in einem Bereich.
- **Material statt iOS:** `AlertDialog` mit rotem `TextButton` (`list_activities_screen.dart:316-343`); Material-`Dialog` für Teilen (`share_list_dialog.dart:100-103`); `FilledButton` und `CircularProgressIndicator` (`item_offer_sheet.dart:376-401`, `zip_code_sheet.dart:133-141`); `TextButton` (`checkout_store_sheet.dart:184-190, 280-289`); `MaterialPageRoute` für Einstellungen und Kategorien (`list_detail_screen.dart:734-765`); Kategorie-Formular per `showModalBottomSheet` und `Colors.grey[600]` (`category_order_screen.dart:354-359, 454`).
- **Material Icons statt SF Symbols:** `Icons.chevron_right_rounded`, `edit_rounded`, `drag_handle_rounded`, `history`, `local_offer_outlined`, `storefront_outlined`, `receipt_long_outlined`, `near_me_outlined`, `copy_rounded`, `numbers_rounded`, `link_rounded`, `arrow_back_ios_new_rounded` (z. B. `list_settings_screen.dart:339`, `category_order_screen.dart:275, 283`, `list_activities_screen.dart:94`, `offer_suggestions_bar.dart:96`, `list_price_summary_bar.dart:119, 464`, `share_list_dialog.dart:163, 192`, `paper_settings.dart:37`). Nur das "…"-Menü nutzt SF Symbols.
- **Emoji-Icons in getönten Quadraten:** `list_activities_screen.dart:221-233` (Quadrat 36 pt, Tönung pro Typ, Emoji aus `list_activity.dart:128-158`). Dazu eine Regenbogenpalette pro Aktivitätstyp (`_getActivityColor`, Z. 266-295).
- **Touch-Ziele unter 44 pt:** Minus-Kreis zum Entfernen 20 pt ohne Polster (`list_settings_screen.dart:326-336`); `PaperCircleIconButton` 34 pt (`paper_settings.dart:77-78`), also Zurück, Plus, Mülleimer; Stift in der Kategorienzeile ca. 32 pt (`category_order_screen.dart:270-279`); Plus in der Angebotszeile 26 pt (`offer_suggestions_bar.dart:440-452`, zwar ist die ganze Zeile tippbar, aber das Signal ist winzig); PLZ-Zeile im Marktvergleich ca. 16 pt hoch (`list_price_summary_bar.dart:333-358`); "Überspringen" als kleiner `TextButton` 13 pt (`checkout_store_sheet.dart:183-191`).
- **Vollbild-Spinner statt sofortiger Inhalte:** `list_settings_screen.dart:229-230`, `category_order_screen.dart:174-175`, `list_activities_screen.dart:78-79`. Beim Teilen gibt es während der Code-Erzeugung gar keine Rückmeldung (`share_list_dialog.dart:20-33`).
- **Bestätigungsdialoge statt Rückgängig:** Mitglied entfernen und Aktivitäten leeren fragen per Dialog nach (`list_settings_screen.dart:104-123`, `list_activities_screen.dart:316-343`). Nach Apple-Agency reicht hier Rückgängig. Beim Löschen der Liste ist der Dialog richtig.
- **Haptik-Häufung:** jede Zeile, jedes Sheet und jeder Chip feuert `selectionClick`, auch reine Navigation (`list_settings_screen.dart:264`, `list_price_summary_bar.dart:106`, `item_offer_sheet.dart:43`, `paper_settings.dart:39`). Nach den Regeln gehört Haptik nur an bedeutsame Momente.
- **Feste Animationsdauern:** `AnimatedContainer(200 ms)` im Farbwähler (`category_order_screen.dart:467-468`), Drag-Skalierung über den Standard-Tween. Keine Federn, Reduce Motion wird in keiner Datei dieses Bereichs abgefragt.
- **VoiceOver:** Fast alle Bedienelemente sind `GestureDetector` ohne `Semantics`-Label oder Button-Rolle: Minus-Kreis (nur Icon), Mitgliederzeile, Chip, Angebotszeile, PLZ-Hinweis, Marktkachel, Code-Feld (`list_settings_screen.dart:262, 326`, `list_price_summary_bar.dart:104, 182`, `offer_suggestions_bar.dart:156, 208, 277`, `checkout_store_sheet.dart:211`, `share_list_dialog.dart:127`). Der Platzierungskreis "1/2/3" im Marktvergleich hat keine Bedeutung für Screenreader.
- **Wayfinding:** Die Kategorie-Reihenfolge fährt als Vollbild-Dialog von unten herein, zeigt aber einen Zurück-Pfeil statt "Fertig" (`paper_settings.dart:35-46`). Tippt man ein Listenmitglied an, landet man auf einer Rezept-Autorenseite (`list_settings_screen.dart:265-268`). Der Aktivitätsverlauf hat keinen Einstieg in der App. Listeneinstellungen und Teilen sind getrennt, obwohl beide "Wer hat Zugriff?" beantworten.
- **Farbe:** Akzentfarbe auf vielen Flächen gleichzeitig (Chip-Text, Markt-Pille, Platz-1-Kreis, Spar-Box, Plus-Kreise, Badges; `list_price_summary_bar.dart:119-150, 372`, `item_offer_sheet.dart:314-360`). Kategorie- und Aktivitätsfarben sind feste Material-Farben (`category_order_screen.dart:330-347`, `list_activities_screen.dart:266-295`) und passen sich nicht an Hell/Dunkel an.

### 3.2 Feste Größen, die bei großer Schrift oder 320 pt Breite brechen
In der App ist `textScaler` nirgends begrenzt (grep in `app.dart`, `main.dart`, `core/`). Alle Texte skalieren also mit Dynamic Type, die festen Container nicht.
- **Angebotszeile 72 pt fest** mit bis zu vier Textzeilen links und drei rechts (`offer_suggestions_bar.dart:19, 131-139, 280-282`). Schon ab etwa 120 % Textgröße läuft die Zeile über (RenderFlex overflow); der Kommentar Z. 16-18 rechnet ausdrücklich mit festen Pixelgrößen.
- **Buttons mit fester Höhe 50/52 pt:** `zip_code_sheet.dart:127`, `checkout_store_sheet.dart:162`, `item_offer_sheet.dart:376-378`, `share_list_dialog.dart:181`, `PaperPrimaryButton` 52 pt (`item_form_dialog.dart` um Z. 385). Bei Bedienungshilfe-Größen wird der Text abgeschnitten.
- **Teilen-Dialog bei 320 pt:** Material-`Dialog` hat 40 pt Außenrand je Seite, dazu 28 pt Innenrand. Es bleiben ca. 184 pt. Darin stehen der Code 28 pt mit Laufweite 6 plus Icon in einer `Row` ohne `Flexible` (`share_list_dialog.dart:150-165`) und zwei Buttons nebeneinander mit Icon und 16-pt-Text in `Row(mainAxisSize: min)` ohne `Flexible` (Z. 175-217). Bei großer Schrift oder Anzeigezoom läuft das über.
- **Sheets ohne Scroll:** `showItemOfferSheet` ohne `isScrollControlled` (`item_offer_sheet.dart:91-100`) und Marktvergleich ohne `isScrollControlled` (`list_price_summary_bar.dart:164-169`) begrenzen auf 9/16 der Bildschirmhöhe, der Inhalt ist eine nicht scrollbare `Column`. Der Marktvergleich listet alle gefundenen Ketten (bis zu 15 in `groceryRetailers`) plus Hinweiskarte und Fußnoten. Auf dem iPhone SE (667 pt hoch, also ca. 375 pt Sheet) läuft das schon bei Standardschrift mit 5 oder mehr Märkten über.
- **Checkout-Kandidaten fest 280 pt hoch** (`checkout_store_sheet.dart:107-108`); bei großer Schrift passen kaum zwei Kacheln, die Buttons darunter rutschen trotzdem aus dem Bild, weil die äußere `Column` nicht scrollt.
- **`PaperSettingsAppBar` fest 56 pt** mit Serifentitel 20 pt ohne `maxLines` (`paper_settings.dart:24, 49-54`). Lange Titel wie "Listeneinstellungen" oder "Kategoriereihenfolge" werden bei großer Schrift abgeschnitten. Es gibt keinen großen Titel (Large Title), der umbrechen darf.
- **Winzige feste Schriftgrößen** unterhalb der iOS-Mindestgröße (11 pt Caption 2): 9,5 pt (`offer_suggestions_bar.dart:104, 349-356, 434`), 10 pt (`offer_suggestions_bar.dart:369, 399, 426`, `item_offer_sheet.dart:206`, `paper_settings.dart:149`), 10,5 pt (`list_price_summary_bar.dart:143, 222, 531-545`, `item_offer_sheet.dart:274`). Auf Dynamic-Type-Stufen gemappt ist keine davon.
- **Einzeilige Kürzungen mit wichtigem Inhalt:** Chip-Text `maxLines: 1` mit Ellipse (`list_price_summary_bar.dart:57-59, 75-77`, `item_offer_sheet.dart:66-67`), PLZ-Hinweis `maxLines: 1` (`offer_suggestions_bar.dart:184-185`). Bei 320 pt Breite verschwindet genau der Markt- oder Betragsteil.
- **Avatar und Farbpunkte fest:** Avatar 36 pt, Farbpunkt 12 pt, Emoji-Quadrat 36 pt (`list_settings_screen.dart:275-277`, `category_order_screen.dart:246-248`, `list_activities_screen.dart:221-223`). Sie wachsen nicht mit, das Verhältnis zum Text kippt bei großen Stufen.

### 3.3 Paper-Reste (Kicker, Serifen, Creme/Terrakotta)
- **Versalien-Kicker:** `PaperSectionHeader` "MITGLIEDER", "AKTIONEN" (`paper_settings.dart:136-157`, benutzt in `list_settings_screen.dart:251, 356`); "ANGEBOTE IN DER NÄHE" (`offer_suggestions_bar.dart:103-110`); "AKTUELLES ANGEBOT" (`item_offer_sheet.dart:203-211`); Datumskopf mit Laufweite 0,5 (`list_activities_screen.dart:145-152`).
- **Serife Georgia (`PaperTextStyles.serif`):** App-Bar-Titel (`paper_settings.dart:50`), Listenname (`list_settings_screen.dart:244`), Avatar-Initial (`list_settings_screen.dart:396`), Sheet-Titel (`checkout_store_sheet.dart:91`, `list_price_summary_bar.dart:319`, `zip_code_sheet.dart:88`), Preise (`offer_suggestions_bar.dart:409`, `list_price_summary_bar.dart:448, 521`, `item_offer_sheet.dart:247, 294`).
- **Creme/Papier-Farben:** `PaperColors.cream`/`creamInk` als Avatar- und Bild-Fallback (`list_settings_screen.dart:392-398`, `offer_suggestions_bar.dart:305-311`, `item_offer_sheet.dart:227-233`) und als Fläche des Rundbuttons (`paper_settings.dart:81`); `PaperColors.surface` als Dialogfläche (`share_list_dialog.dart:102`); `PaperColors.paper` als Schrift auf Akzent (`offer_suggestions_bar.dart:450`, `list_price_summary_bar.dart:224, 380`, `item_offer_sheet.dart:383`, `zip_code_sheet.dart:139, 147`); `PaperColors.danger` (terrakottaartiges Rot `0xFFA33B2A`) statt System-Rot (`list_settings_screen.dart:333, 411`). `paper_settings.dart:89` nennt den Speichern-Button ausdrücklich "Terracotta pill".
- **Graue, blasse Fließtexte:** Erklärtexte und Hinweise in `textSecondary` oder `textTertiary` bei 10-12,5 pt (`checkout_store_sheet.dart:100`, `zip_code_sheet.dart:93`, `list_price_summary_bar.dart:529-546`, `category_order_screen.dart:183-188`). Nach der Anti-Slop-Regel gehört Fließtext in volle Textfarbe.
- **Harte Ränder und Haarlinien statt Tonstufen:** fast jede Karte hat `Border.all(AppColors.border)` (`offer_suggestions_bar.dart:79`, `list_price_summary_bar.dart:115, 193`, `checkout_store_sheet.dart:133, 219`, `zip_code_sheet.dart:100`, `list_activities_screen.dart:166-170`), dazu 0,5-pt-Trennlinien in jeder Liste.

---

## 4. Bugs, Risiken und Performance

### 4.1 Fachlich falsch oder vom Plan verworfen
- **"Günstigster Korb" und Marktrangliste sind verworfen, aber live.** `basketComparisonProvider` füllt fehlende Artikel mit dem billigsten Preis eines anderen Markts (`price_comparison_provider.dart:132-158`). Die Summe ist in keinem Markt bezahlbar. Chip "X € günstigster Korb" (`list_price_summary_bar.dart:56-73`), Rangliste mit Platz 1 (`list_price_summary_bar.dart:362-452`), "Näher dran … nur X € mehr" (`list_price_summary_bar.dart:453-497`, `store_offer.dart:308-354`) und das Startseiten-Highlight "X € günstiger bei …" (`price_comparison_provider.dart:196-285`) sind genau die verworfenen Muster.
- **"Bei X wäre es Y € günstiger"** steckt im Artikel-Chip "Spare X € bei {store}" (`item_offer_sheet.dart:57-61`), in "Spart X € gegenüber deinem gespeicherten Preis" (`item_offer_sheet.dart:340-361`) und in "Spare bis zu X €" (`offer_suggestions_bar.dart:60-70, 112-123`), wo gegen den teuersten anderen Treffer gerechnet wird.
- **Packungspreis statt Grundpreis im Korb:** `cheapestPerRetailer` sortiert zwar nach Grundpreis, wenn die Einheit gleich ist (`offer_price_service.dart:222-233`), summiert aber `o.price`. Die Menge auf der Liste wird im Korb ignoriert (`price_comparison_provider.dart:155-158`), in der "Ganze Liste, geschätzt"-Zeile aber mitgerechnet (`list_price_summary_bar.dart:272`). Zwei Zahlen im selben Sheet beruhen auf verschiedenen Regeln.
- **Ersparnis mit Fallback-PLZ 10115:** Vorschläge und "Spare bis zu" laufen auch mit Berliner Ersatz-PLZ (`offer_suggestions_bar.dart:40-43`). Die Recherche verlangt, dann keine Ersparnis zu behaupten.
- **"statt"-Preise und Rabatt-Prozent** werden per Regex aus dem Beschreibungstext gelesen und als eigenes "-X%"-Badge hervorgehoben (`store_offer.dart:117-140`, `offer_suggestions_bar.dart:385-404`, `item_offer_sheet.dart:314-330`). Laut Recherche nur als "laut Händler" zeigen, keine eigene Prozentrechnung.
- **Kein Markt pro Liste:** `ShoppingListModel` hat kein Markt-Feld; alle Angebotsflächen zeigen alle Ketten der PLZ.

### 4.2 Recht und Datenschutz
- **Fest eingebaute marktguru-Keys** (`offer_price_service.dart:26-29`) und Auslesen der Keys aus dem Seitenquelltext (`offer_price_service.dart:297-336`) mit vorgetäuschtem iPhone-User-Agent (Z. 264). Laut Recherche ein direkter AGB-Verstoß.
- **Kein Kill-Switch und kein Modulschalter:** grep nach `offersEnabled`, `dealsEnabled`, `kill switch`, `feature_flag` findet nichts. Angebote lassen sich weder vom Nutzer noch remote abschalten.
- **Hotlink auf Angebotsbilder** `mg2de.b-cdn.net` (`store_offer.dart:114-115`), gezeigt in `offer_suggestions_bar.dart:297` und `item_offer_sheet.dart:218`.
- **Jeder Tastendruck geht mit PLZ an marktguru:** Alles ab 2 Zeichen in der Eingabeleiste wird nach 300 ms als Suchanfrage gesendet (`list_detail_screen.dart:163-181`, `price_comparison_provider.dart:49-56`). Dazu werden die Namen der offenen Artikel (bis 25) beim Öffnen jeder Liste gesendet. Im Datenschutzkonzept muss das stehen.
- **Standortabfrage ohne Kontext:** `effectiveZipProvider` ruft `getZipInfo` mit `allowPermissionPrompt: true` (Standard, `user_location_service.dart:60-63`). Weil `ListPriceSummaryBar` das beim Öffnen jeder Liste beobachtet (`list_price_summary_bar.dart:33-34`), erscheint der iOS-Standortdialog beim ersten Öffnen einer Liste, ohne Erklärung. Beim Abschluss fragt `getCoordinates()` ebenfalls mit Prompt (`shopping_trip_completion.dart:184`).
- **Beliebige Pfade per Link:** `_parseCustomSchemePath` gibt bei unbekanntem Host `uri.path` ungeprüft an den Router (`deep_link_service.dart:223-228`). Jeder Screen ist von außen ansteuerbar.
- **Share-Code-Suche:** `joinListWithCode` liest `shopping_lists` per `share_code` als Nicht-Mitglied (`list_repository.dart:170-174`). Das setzt eine RLS-Ausnahme voraus; 6 Ziffern sind ratbar. Prüfen.

### 4.3 Bugs
- **Teilen macht alte Codes ungültig.** Jedes Öffnen des Teilen-Dialogs erzeugt einen neuen Code und überschreibt `share_code` (`share_list_dialog.dart:21-24`, `list_repository.dart:142-156`). Ein Code, der gestern per WhatsApp verschickt wurde, funktioniert nicht mehr, sobald irgendein Mitglied erneut auf Teilen tippt. Eine Kollisionsprüfung gibt es nicht.
- **Der geteilte Link lässt niemanden beitreten.** Er zeigt auf `https://shoplyai.app/list/<listId>` (`share_list_dialog.dart:52`), der Router macht daraus nur `/lists/:id` (`app_router.dart:459-466`). Nicht-Mitglieder sehen wegen RLS eine leere Liste. `joinListWithLink`, `DeepLinkService.getListInviteUrl` und `getListShareUrl` werden nie aufgerufen; der `code`-Parameter von `/invite` wird ignoriert.
- **PLZ-Änderung wirkt nicht überall.** `showZipCodeSheet` invalidiert nur `userZipCodeProvider` (`zip_code_sheet.dart:54`), ebenso `personal_info_screen.dart:90` und `avo_settings_bridge.dart:355`. `effectiveZipProvider` ist kein `autoDispose`-Provider (`price_comparison_provider.dart:23-25`) und behält den alten Wert, bis zufällig `showManualZipDialog` läuft (`list_price_summary_bar.dart:246`) oder die App neu startet. Wer die PLZ über den Hinweis in den Vorschlägen setzt, bekommt weiter Berliner Angebote.
- **Veraltete Koordinaten beim Abschluss.** `getCoordinates()` gibt bis zu 24 h alte Koordinaten aus dem Cache zurück (`user_location_service.dart:172-181`). `_resolveCheckoutStore` ruft ohne `forceRefresh` auf (`shopping_trip_completion.dart:184`). Der Resolver kann so einen Markt am Ort von heute Morgen "sicher erkennen" und still falsch speichern, genau den Fehler, den `checkout_store_resolver.dart:36-40` vermeiden will.
- **Falscher Hinweistext:** Fehlen die Koordinaten (Ortungsdienste aus, Zeitlimit, Fehler), meldet das Sheet trotzdem "Ohne Standortzugriff …" (`shopping_trip_completion.dart:185-186`).
- **Checkout-Ergebnis uneinheitlich:** gespeichert wird der OSM-Anzeigename (`checkout_store_resolver` > `store.displayName`, `shopping_trip_completion.dart:199`; im Sheet Z. 115-118 sind beide Zweige des Ternärs identisch). Für "nach zweimal demselben Markt vorschlagen" braucht es die Ketten-ID (`retailerUniqueName`).
- **Aktivitäten sind tot.** `logActivity` und `notifyCategoryChange` haben keinen Aufrufer. Pushes vom Typ `list_activity` öffnen einen garantiert leeren Screen. `notifyCategoryChange` liest außerdem `users.fcm_token` (`list_activity_service.dart:183-186`), laut CLAUDE.md liegen Tokens in `user_devices`. Die Speicherung ist rein lokal; geteilte Listen zeigen also nie die Änderungen anderer.
- **Ungelesen ist tot:** `UnreadService.isUnread` hat keinen Aufrufer; geschrieben wird trotzdem bei jedem Laden der Artikel.
- **Eigene Kategorien sind nur lokal** (`category_order_service.dart:10-13`), Artikel bekommen aber die eigene `category_id` serverseitig. Andere Mitglieder und das zweite Gerät kennen die Kategorie nicht. Löscht ein Mitglied "seine" Kategorie, setzt es Artikel aller Mitglieder auf `other` (`category_order_service.dart:96-101`).
- **Mitglied antippen öffnet das Rezept-Autorenprofil** (`list_settings_screen.dart:265-268`).
- **Fehlerbehandlung:** Laden der Mitglieder schlägt still fehl (leere Liste, `list_settings_screen.dart:90-93`); Angebot übernehmen zeigt `e.toString()` roh in der SnackBar (`item_offer_sheet.dart:154-161`); `'Unknown'` und `'Someone'` sind fest englisch (`list_settings_screen.dart:69`, `list_activity_service.dart:40-43`).
- **Zahlen- und Datumsformat:** Preise überall mit `toStringAsFixed(2)` und Punkt ("1.99 €") statt deutschem Komma (z. B. `offer_suggestions_bar.dart:116, 408, 421`, `list_price_summary_bar.dart:64, 82, 447, 520`, `item_offer_sheet.dart:59, 63, 293, 351`). Datum "d.m." fest deutsch, auch auf Englisch (`item_offer_sheet.dart:131`). `DateFormat.Hm()` ohne Locale (`list_activities_screen.dart:202`).
- **PLZ-Sheet:** Weniger als 4 Ziffern werden ohne Rückmeldung ignoriert (`zip_code_sheet.dart:50`), deutsche PLZ haben 5. Eine Möglichkeit, zur GPS-PLZ zurückzukehren, fehlt hier.
- **Ablauf "endet heute"** rechnet in 24-Stunden-Blöcken UTC statt Kalendertagen (`offer_suggestions_bar.dart:267-270`, `item_offer_sheet.dart:126-129`).
- **Vergleich-Sheet öffnet nicht**, solange der Korbvergleich lädt, ohne jede Rückmeldung (`list_price_summary_bar.dart:162-163`).

### 4.4 Performance und sichtbares Laden
- **Netzlawine beim Öffnen einer Liste:** `basketComparisonProvider` startet für bis zu 25 offene Artikel je eine Suche, mit Broad-Match-Fallback bis zu 50 Anfragen, gedrosselt auf 250 ms Abstand (`price_comparison_provider.dart:100-119`, `offer_price_service.dart:61, 113-126`). Ohne Cache dauert das 6-12 s; davor kommen gegebenenfalls GPS (bis 10 s) und das Laden der Keys (bis 12 s).
- **Layout springt:** Artikel-Chips erscheinen erst nach dem Korbvergleich und machen jede betroffene Zeile höher (`list_category_section.dart:165-168, 220-222`, `list_item_tile.dart:343-350`). Der Preis-Chip über der Eingabe wechselt zwischen nichts, PLZ-Chip, "bekannt" und "günstigster Korb" und ändert die Höhe der unteren Leiste, die `list_detail_screen.dart` per `_syncBottomBarHeight` nachmisst (Z. 496-500). Die Vorschlagskarte springt beim Tippen herein und heraus.
- **Neuberechnung bei jedem Abhaken:** Der Schlüssel des Korbvergleichs sind die offenen Namen (`price_comparison_provider.dart:100-103`). Jedes Abhaken und Hinzufügen löst eine neue Berechnung aus und baut alle Sektionen neu, die den Provider beobachten. Die Suchergebnisse sind gecacht, der Rebuild nicht.
- **Checkout wartet unsichtbar:** Vor dem Sheet laufen GPS und Overpass mit 18 s Zeitlimit pro Endpunkt, zwei Endpunkte (`store_locator_service.dart:57-61`). Im schlechtesten Fall vergehen über 30 s ohne Anzeige. Für den Abschluss reicht ein Radius von 250 m, abgefragt werden 8 km (`store_locator_service.dart:29`).
- **Overpass fragt nur `node` ab** (`store_locator_service.dart:53-55`). Viele Supermärkte sind in OSM als Gebäude (`way`) erfasst und fehlen. Das führt zu mehr Rückfragen und fehlenden Entfernungen.
- **Unbegrenzte Caches:** `_searchCache` in `offer_price_service.dart:53` und `_cache` in `store_locator_service.dart:32` wachsen ohne Obergrenze; jede getippte Zeichenfolge wird ein Eintrag.
- **`BackdropFilter` pro Datumsgruppe** im Aktivitätsverlauf (`list_activities_screen.dart:158`).
- **Bilder ohne Cache:** `Image.network` für Avatare und Angebotsbilder (`list_settings_screen.dart:281`, `offer_suggestions_bar.dart:297`, `item_offer_sheet.dart:218`), kein Platzhalter beim Laden, nur Fehler-Fallback.

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Listen-Detail (`list_detail_screen.dart`):** Einstieg für Einstellungen, Kategorien, Teilen; unterer Stapel aus `OfferSuggestionsBar` / `ListPriceSummaryBar` / `AddItemComposer` mit Höhenmessung; `_offerQuery`-Entprellung; `_addItemFromOffer`; `_markAsRead`; `_loadCustomCategories`. Wer die Eingabeleiste umbaut, muss diese Flächen mitnehmen.
- **Listenzeilen und Sektionen:** `list_category_section.dart` beobachtet `basketComparisonProvider` je Sektion; `list_item_tile.dart` zeigt `ItemOfferChip` und öffnet `showItemOfferSheet`.
- **Einkaufsabschluss:** `shopping_trip_completion.dart` nutzt `UserLocationService`, `StoreLocatorService`, `CheckoutStoreResolver`, `showCheckoutStoreSheet`; schreibt `priceRetailer` in `ShoppingHistoryService`.
- **Startseite:** `home_screen.dart:502` (`personalizedDealsProvider`), `price_comparison_nudge_card.dart` (`homePriceHighlightProvider`, verworfenes Muster), `home_screen.dart:719` (Beitritt per Code), `home_price_comparison_cache_service.dart`.
- **Wochenangebote:** `weekly_deals_screen.dart` nutzt `userZipCodeProvider`, `showZipCodeSheet`, `offerSearchAllProvider`, `personalizedDealsProvider`.
- **Rezepte:** `recipe_offers_provider.dart:36` nutzt `effectiveZipProvider`.
- **Avo:** `avo_assistant_service.dart:838-946` nutzt `basketComparisonProvider` und `personalizedDealsProvider` (Tools für Angebote und Korbvergleich), `:1884` `UnreadService`; `avo_settings_bridge.dart:355` setzt die PLZ.
- **Profil:** `personal_info_screen.dart:86-91` setzt die manuelle PLZ.
- **Router und Benachrichtigungen:** `app_router.dart` (`/lists/:id/activities`, `/list/:id`, `/invite/:id`, ausstehender Link nach Login), `navigation_service.dart`, `fcm_service.dart:197`, `notification_service.dart:89`, `app.dart` (DeepLinkService-Callbacks für Siri).
- **Daten:** `list_repository.dart` (Mitglieder, Code, Beitritt, Hintergrund), `lists_provider.dart`, `items_provider.dart` (`updateItem` mit Preisfeldern, `markAsRead`), Modelle `store_offer.dart`, `nearby_store.dart`, `list_activity.dart`, `custom_category.dart`, `shopping_list_model.dart`, `shopping_item_model.dart` (`price`, `priceRetailer`, `priceUnit`, `pricingQuantity`, `hasPrice`), Supabase-Tabellen `shopping_lists` (`share_code`, `share_link`, `is_shared`, Hintergrundfelder), `list_members`, `users`, `shopping_items`.
- **Geteilte UI-Bausteine:** `paper_settings.dart` (in 11 Dateien, auch Profil-Unterseiten), `PaperPrimaryButton` aus `item_form_dialog.dart` (auch Login, Signup, Welcome, OTP, Onboarding), `paper_colors.dart`, `liquid_glass_button.dart`, `confirm_dialog.dart`, `adaptive_platform_ui` (`AdaptiveBlurView`, `AdaptiveTextField`, `AdaptivePopupMenuButton`).
- **Strings:** alle Texte in `lib/core/localization/app_translations.dart` (Englisch ab ca. Z. 400-900, Deutsch ab ca. Z. 1570-2350), plus `share_code_title`/`share_code_message` über `app_localizations.dart:60-61`. Aktivitätsbeschreibungen fest in `list_activity.dart`.
- **Paywall:** `premium_feat_deals` bewirbt Angebote als Pro (laut Verbesserungsliste 6a); muss mit dem Angebotsmodul zusammen geändert werden.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Mitglieder und Teilen**
- Mitgliederliste mit Owner zuerst, Kennzeichnung "Du" und "Ersteller", Avatar mit Initial-Fallback.
- Owner kann Mitglieder entfernen, Mitglieder können verlassen, Owner kann die Liste löschen (mit Bestätigung, da endgültig). Nach Verlassen oder Löschen zurück zur Startseite und Listen neu laden.
- Teilen per 6-stelligem Code (Kopieren, über das iOS-Teilen-Menü senden) und Beitritt per Code auf der Startseite. Der Link-Weg muss im neuen Konzept echt beitreten lassen (Einladung mit Code), statt nur die Listen-ID zu verschicken.
- Ausgeloggt geöffnete Listen- und Einladungslinks werden gemerkt und nach dem Login fortgesetzt (`app_router.dart`).
- Siri-Aktionslinks `shoply://add-item?name&list&quantity` und `shoply://create-list?name`, Deduplizierung doppelt gelieferter Links (2 s).

**Kategorien**
- Reihenfolge pro Liste per Drag, eigene Kategorien mit Name und Farbe anlegen, bearbeiten, löschen. Beim Löschen wandern Artikel nach `other`. Nach Änderungen gruppiert die Liste neu.
- Sonderfall: eigene Kategorien sind heute nur lokal. Das Konzept muss entscheiden, ob Reihenfolge und eigene Kategorien pro Person oder pro Liste (geteilt) gelten.

**Angebote (als abschaltbares Modul, standardmäßig an, mit Remote-Kill-Switch)**
- Live-Vorschläge beim Tippen, eine Zeile pro Händler zuerst, alle Treffer erreichbar; Tipp fügt den Artikel mit Preis, Händler und Einheit hinzu.
- Angebot an einem Listenartikel anzeigen und "Preis übernehmen" (schreibt `price`, `price_currency`, `price_retailer`, `price_unit`, `price_updated_at`, `price_old_value`).
- Kennzeichnung "Ähnliches Produkt" bei Broad-Match und die Warnung, es vor dem Hinzufügen zu prüfen. Die Logik "Komposita nicht kürzen, lieber kein Treffer als ein falscher" (`offer_price_service.dart:183-208`) bleibt.
- Gültigkeit ("endet heute", "gültig bis"), Grundpreis pro kg/l, "statt"-Preis nur als Händlerangabe.
- Hinweis "Nur Angebotspreise, keine Normalpreise".
- Statt Korbsumme und Rangliste: "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region", verglichen über den Grundpreis; mit Fallback-PLZ keine Ersparnis.
- Regionswahl: GPS > manuelle PLZ > Fallback 10115 nur für "deutschlandweit" ohne Sparbehauptung; PLZ setzen und wieder löschen können; nur deutsche Placemarks akzeptieren.
- Händlerliste der Lebensmittelketten (`groceryRetailers`) und Filter auf Lebensmittel und aktuell gültige Angebote.
- Neu laut Plan: Markt pro Liste (Listenname, Markt-Chip mit Name und Markenfarbe, gelernt aus Abschlüssen, Standort nur als Frage), Schnellschalter "Angebote für diese Liste ausblenden", Bereich "Preise & Angebote" in den Einstellungen.

**Markt beim Abschluss**
- Stilles Erkennen nur bei eindeutiger Lage (innerhalb 80 m, Abstand zur nächsten anderen Kette mindestens 50 m, gleiche Kette nebeneinander ist kein Konflikt), sonst Auswahl aus Märkten im Umkreis von 250 m, sonst manuell, Überspringen immer möglich, der Einkauf wird immer gespeichert.
- Erklärung, was fehlender Standortzugriff kostet, einmal und ohne Drängeln.
- Der erkannte Markt wird künftig als Ketten-ID gespeichert, damit "Markt pro Liste" daraus lernen kann.

**Verlauf, Ungelesen, Hintergründe**
- Der Aktivitätsverlauf existiert als Route und Push-Ziel, ist aber leer. Das Konzept muss entscheiden: als serverseitiger Verlauf für geteilte Listen neu bauen (passt zu "wer kauft gerade ein, Abgehaktes live") oder streichen und Pushes direkt in die Liste führen.
- Ungelesen-Zeitstempel pro Liste existiert; die Anzeige fehlt. Entscheiden, ob geteilte Listen einen Ungelesen-Punkt bekommen.
- Listen-Hintergründe: Daten in Supabase vorhanden, UI gelöscht, 15 Verläufe als verwaiste Konstante. Entweder bewusst streichen (Migration, Konstante und `saveBackground` entfernen) oder im neuen Design als dezente Listenfarbe wieder aufnehmen. Bestehende Werte dürfen beim Umbau nicht zu Fehlern führen.
