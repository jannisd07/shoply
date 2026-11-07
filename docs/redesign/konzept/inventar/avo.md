# Inventar: Avo-Assistent (Ist-Zustand, Stand 07.11.2026)

Grundlage für das Redesign. Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf den Stand von `main` (Commit 3e886d0).

Kurzfassung: Avo ist heute ein reiner Text-Chat im Vollbild (Route `/avo`) auf Gemini 2.0 Flash Lite mit 35 Tools. Es gibt zwei Einstiege (Orb neben der Tab-Leiste, Hinweisstreifen auf Home), keinen Sprachmodus, keine Kamera, keinen Verlauf über das Schließen hinaus. Die Oberfläche ist Paper-Stil (Georgia-Serife, Creme, Terrakotta, Salbei). Mehrere Tools und Texte widersprechen dem Plan (Markt-Preisvergleich, "günstigster Laden", Preise in Dollar, englische Rückfragen beim Löschen).

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/ai/avo_chat_screen.dart` | Chat-Screen: Zustand, Senden, Kontextaufbau, Callbacks der Karten, Layout | 436 |
| `lib/presentation/screens/ai/avo_chat_message.dart` | Datenklasse `ChatMessage` (nur im Speicher) | 18 |
| `lib/presentation/screens/ai/widgets/avo_chat_widgets.dart` | Leerer Zustand mit Chips, User-Blase, Eingabefeld (`AvoComposer`), Tipp-Punkte, Kopfzeile | 441 |
| `lib/presentation/screens/ai/widgets/avo_payload_cards.dart` | `AvoMessage` (Antwort ohne Blase) und 8 Ergebnis-Karten | 699 |
| `lib/data/services/avo_assistant_service.dart` | Gemini-Session, Function-Calling-Schleife, 35 Tool-Implementierungen, Kontext-String, Fehlertexte | 1998 |
| `lib/data/services/avo_tool_declarations.dart` | 35 `FunctionDeclaration`-Schemas | 567 |
| `lib/data/services/avo_system_prompt.dart` | System-Prompt (Persona, Tool-Regeln, Personalisierung) | 122 |
| `lib/data/services/avo_assistant_models.dart` | `AvoResponse`, `AvoExpressionType`, `AvoPayloadKind`, `AvoWidgetPayload`, `AvoContext` | 197 |
| `lib/data/services/avo_app_knowledge.dart` | Statische Wissensbasis für `get_app_info` (englisch, Preise in Dollar) | 106 |
| `lib/data/services/avo_settings_bridge.dart` | `update_setting`: 12 Einstellungen über Riverpod-Notifier ändern | 470 |
| `lib/data/services/avo_nudge_service.dart` | Nachkauf-Vorschläge aus Kaufrhythmus, Angebots-Nudges, Snooze, Cache | 673 |
| `lib/data/services/contextual_prompt_service.dart` | Einmal-Hinweise: Ernährungs-Dialog (Rezepte-Tab), Benachrichtigungs-Sheet (vor dem Teilen) | 304 |
| `lib/data/services/mascot_notification_service.dart` | Lokale Push-Hinweise "Avo": Nachkauf 9 Uhr, Abendessen-Ideen 18 Uhr | 360 |
| `lib/presentation/state/avo_nudge_provider.dart` | `restockSuggestionsProvider`, `offerNudgesProvider` | 87 |
| `lib/presentation/screens/home/widgets/avo_nudge_card.dart` | Home-Karte "Wahrscheinlich fast leer" / "Für dich im Angebot" | 392 |
| `lib/presentation/screens/home/widgets/calorie_recipe_nudge_card.dart` | Home-Karte "N kcal übrig" mit Maskottchen | 191 |
| `lib/core/mascot/avo_mascot.dart` | `AvoMascot`-Widget, 8 Ausdrücke auf 4 PNGs | 129 |
| `assets/avo/avo_{waving,excited,thinking,celebrating}.png` | Maskottchen, je ca. 450 x 550 px, ca. 230 KB | - |
| `lib/routes/app_router.dart:289-296` | Route `/avo` (`CupertinoPage`, außerhalb der Shell, ohne Tab-Leiste) | - |
| `lib/presentation/screens/main_scaffold.dart:332-338, 415-456` | Einstieg 1: `_AvoOrb` rechts neben der Tab-Pille | - |
| `lib/presentation/screens/home/home_screen.dart:270-320` | Einstieg 2: Hinweisstreifen "Avo: Fehlt was? Frag mich nach Rezepten." | - |
| `ios/Runner/AppIntents.swift` | Siri/Kurzbefehle (6 Intents), öffnen die App per `shoply://`; haben mit Avo nichts zu tun | 445 |

Nicht vorhanden, obwohl in der Aufgabe bzw. `CLAUDE.md` genannt:
- `lib/data/services/voice_assistant_service.dart` existiert nicht mehr (gelöscht in Commit 38ce871 "delete unused services"; nur noch in alten Worktrees unter `.claude/worktrees/`).
- `ios/Runner/VoiceAssistantPlugin.swift` existiert nicht (nur `android/.../VoiceAssistantPlugin.kt`). `CLAUDE.md` ist hier veraltet.
- Kein Paket für Spracherkennung oder Sprachausgabe in `pubspec.yaml` (kein `speech_to_text`, kein `flutter_tts`). Ein Sprachmodus existiert also nicht, auch nicht halb.

---

## 2. Screens, Sheets und Dialoge

### 2.1 Avo-Chat (`AvoChatScreen`)

- **Datei:** `lib/presentation/screens/ai/avo_chat_screen.dart` mit `widgets/avo_chat_widgets.dart` und `widgets/avo_payload_cards.dart`
- **Route/Einstieg:** `/avo` (Name `avo-chat`), `context.push('/avo')` aus `_AvoOrb` (main_scaffold.dart:337) und aus dem Home-Hinweisstreifen (home_screen.dart:280). Kein Deep Link `shoply://avo`, kein Siri-Intent, kein Einstieg aus einer Liste oder einem Rezept heraus.
- **Hauptfrage:** "Was soll Avo für mich erledigen?"
- **Aufbau von oben nach unten:**
  1. Kopfzeile `AvoChatHeader` (avo_chat_widgets.dart:306-419): runder Zurück-Button (34 pt), Salbei-Kreis mit Maskottchen (38 pt), Titel "Avo" in Georgia 19, Untertitel "dein Einkaufs-Assistent" bzw. "denkt nach…" (11 pt), bei Abo eine Kapsel "Premium", bei offener Tastatur ein Button "Tastatur ausblenden", Button "+" für neuen Chat.
  2. Nachrichtenbereich: leer `AvoChatEmptyState`, sonst `ListView.builder` mit User-Blasen rechts, Avo-Antworten links ohne Blase (Georgia 15, `SelectableText`) und darunter Ergebnis-Karten; am Ende Tipp-Punkte, solange Avo arbeitet.
  3. Eingabefeld `AvoComposer` (avo_chat_widgets.dart:142-243): Kapsel mit Radius 30, Textfeld 2-4 Zeilen, darunter rechts runder Senden-Button (34 pt, terrakotta wenn Text vorhanden). Kein Mikrofon, keine Kamera, kein Anhang.
- **Komponenten:** `AvoMascot`, `_SuggestionPill`, `AvoUserBubble`, `AvoMessage`, `AvoTypingDots`, `_CircleIcon`; Karten siehe 2.2.
- **Zustände:**
  - Leer: Maskottchen winkend (64 pt), "Wie kann ich helfen?" (Georgia 24), 4 Chips: fest "Liste analysieren", "Rezept finden", dazu 2 zufällige aus 10 Vorschlägen; einer davon nach Onboarding-Priorität (z. B. `save_money` ergibt "Welcher Laden ist für meine Liste am günstigsten?").
  - Laden: nur Tipp-Punkte und Untertitel "denkt nach…"; keine Teilergebnisse, kein Streaming, keine Abbruchmöglichkeit.
  - Fehler: Avo antwortet mit festem englischem Text ("Something went wrong — could you try again?", "I've hit my thinking limit for now…", "I'm not ready yet…"), auch in deutscher Oberfläche (avo_assistant_service.dart:160, 213, 218). Kein Erneut-Senden-Button.
  - Offline: nicht behandelt; die Anfrage scheitert und landet im generischen Fehler.
  - Pro gesperrt: nicht vorhanden. `isSubscribedProvider` steuert nur die Kapsel "Premium" in der Kopfzeile. Avo ist für alle unbegrenzt nutzbar, obwohl `AvoAppKnowledge` "unlimited AI chat" als Premium-Vorteil nennt.
  - Modul aus: nicht vorhanden. Avo lässt sich nicht abschalten; beide Einstiege sind immer sichtbar.
  - Nicht initialisiert (leerer API-Schlüssel): jede Nachricht ergibt "I'm not ready yet".
- **Aktionen und Gesten:** Tippen außerhalb blendet Tastatur aus; Ziehen in der Liste blendet Tastatur aus; Chip tippen sendet sofort; Senden (leichte Haptik); "+" startet neuen Chat (mittlere Haptik, Service-Session wird zurückgesetzt); Zurück poppt oder geht nach `/home`; iOS-Wischgeste zurück über `CupertinoPage`. Text in Avo-Antworten ist markierbar.
- **Datenquellen:** `AvoAssistantService.instance` (Singleton), `listsNotifierProvider`, `itemsNotifierProvider(listId)` (nur gelesen, falls schon vorhanden), `OfflineCacheService.getCachedListItemsSync`, `itemRepositoryProvider`, `currentUserProvider` (Diät, Allergien, Name, App-Prioritäten), `languageProvider`, `isSubscribedProvider`.
- **Kontext pro Nachricht** (avo_chat_screen.dart:212-248, avo_assistant_service.dart:1899-1948): alle Listen (Name, ID, Anzahl), Artikel der ersten 3 Listen (je max. 20), Diät, Allergien, Name, Prioritäten. Wird nur gesendet, wenn er sich geändert hat. "Aktuelle Liste" ist immer die erste Liste, nicht die, aus der man kommt.
- **Wichtigste Texte (DE):** "Wie kann ich helfen?", "Frag Avo etwas...", "dein Einkaufs-Assistent", "denkt nach…", "Premium", Chips (z. B. "Zeig meine Einkaufslisten", "Füge Eier zu meiner Liste hinzu", "Teile meinen letzten Einkauf mit Freunden auf").

### 2.2 Ergebnis-Karten im Chat (`avo_payload_cards.dart`)

| Karte | Auslöser (Tool) | Inhalt | Aktion |
|---|---|---|---|
| `_RecipeCards` (121-187) | `search_recipes`, `get_saved_recipes` | horizontal scrollende Karten 200 x 140 pt: Bild 80 pt, Name, Zeit "25m", Sternbewertung | Tippen öffnet `/recipes/:id` |
| `_ListItemsView` (193-272) | `get_list_contents` | Listenname, "N offen", nur offene Artikel (max. 10), Zähler "N abgehakt" | Tippen auf Zeile hakt ab (Repository direkt), Artikel verschwindet aus der Karte |
| `_ListOverview` (278-311) | `get_lists` | bis 5 Listen mit Anzahl und Pfeil | Tippen öffnet `/lists/:id` |
| `_HistoryView` (317-446) | `get_shopping_history` | bis 5 Einkäufe: Name, Datum "7/11/2026", bis 12 Artikel-Chips, Button "Alle N hinzufügen" | Chip fügt einen Artikel hinzu, Button alle; Ziel ist immer die erste Liste |
| `_PickListView` (452-494) | `ask_pick_list` | bis 3 Listen als Auswahl | Tippen fügt Artikel in diese Liste |
| `_NutritionCard` (500-582) | `get_recipe_nutrition` | Rezeptname, "pro Portion", kcal / Eiweiß / KH / Fett, Hinweis "Aus den Zutaten geschätzt" | keine |
| `_SettingChangeCard` (588-653) | `update_setting` | Haken oder Fehler-Icon, "{Einstellung} aktualisiert", "alt → neu" | keine, kein Rückgängig |
| `_AppInfoCard` (659-699) | `get_app_info` | Thema (englisches Stichwort, Akzentfarbe), Antworttext (englisch) | keine |

Nach Karten-Aktionen hängt der Screen eine lokale Avo-Nachricht an ("„Milch“ zu „Wocheneinkauf“ hinzugefügt.", "Artikel konnte nicht hinzugefügt werden. Versuch es nochmal!").

Keine Karten gibt es für: Angebote (`search_offers`, `get_personalized_deals`, `compare_list_prices`), Kalorienstatus, Essens-Eintrag, Wasser, Gewicht, Wochenrückblick, Challenges, Ersparnis, Kostenteilung, Nachkauf-Vorschläge, Löschen, Verschieben, Umbenennen, Liste anlegen. Diese Ergebnisse kommen nur als Fließtext.

Bestätigungen (Löschen, Ziel ersetzen) sind keine UI-Elemente, sondern eine Textfrage des Modells; der Nutzer muss "ja" tippen.

### 2.3 Avo-Einstiege

- **`_AvoOrb`** (main_scaffold.dart:415-456): runder Button 58 pt x Skalierung (Breite/300, also auf 402 pt ca. 78 pt), Farbe wie Tab-Pille, Lucide-Icon `messageCircle`, Schatten, `semanticLabel: 'Avo'`, leichte Haptik.
- **Home-Hinweisstreifen** (home_screen.dart:270-320): Box in fester Creme `0xFFEFE8DA`, Radius 6, Lucide/Material-Icon `eco_outlined` salbei, Text "Avo: Fehlt was? Frag mich nach Rezepten." (12 pt, einzeilig), rechts "Zeigen" in Terrakotta (11 pt).

### 2.4 Avo-Karten auf Home (Nudges)

- **`AvoNudgeCard`** (avo_nudge_card.dart): Maskottchen 22 pt, Kicker "WAHRSCHEINLICH FAST LEER" bzw. "FÜR DICH IM ANGEBOT" (Großbuchstaben, Laufweite 1.5), Zeilen mit Artikel, Rhythmus ("kaufst du etwa alle 5 Tage") und optional Angebotszeile ("Frische Vollmilch · −23 % · 0,99 € · Lidl"), Aktion "Hinzufügen" und Schließen-X (snoozt einen Kaufzyklus bzw. bis Angebotsende). Hinzufügen geht immer in die zuletzt geänderte Liste, Rückmeldung per SnackBar. Leer: Karte verschwindet.
- **`CalorieRecipeNudgeCard`**: Maskottchen 22 pt, Kicker "N KCAL ÜBRIG", Rezeptvorschläge.
- Reihenfolge der Home-Karten nach Onboarding-Prioritäten (`home_nudge_card_order.dart`).

### 2.5 Avo-Benachrichtigungen (`mascot_notification_service.dart`)

- Nachkauf-Erinnerung (ID 700001) am nächsten Morgen 9 Uhr, bei jedem App-Start neu geplant, nur wenn etwas fällig ist; mit Angebot, falls eins passt. Tippen öffnet nur die App (navigation_service.dart:89-91).
- Abendessen-Ideen (ID 700002) um 18 Uhr. Payload-Typ `avo_dinner_ideas` wird in `navigation_service.dart` nicht behandelt (fällt in `default`).
- Abschaltbar über Kategorie `avoNudges` in den Benachrichtigungs-Einstellungen.

### 2.6 Einmal-Hinweise (`contextual_prompt_service.dart`)

- **Ernährungs-Dialog** (88-188): erscheint einmalig beim ersten Öffnen des Rezepte-Tabs, wenn keine Diät gesetzt ist (recipes_screen.dart:90). Titel "Ernährungspräferenzen", Text, Button "Zu den Einstellungen", X 28 pt. Hauptfrage: "Willst du deine Ernährung einstellen?"
- **Benachrichtigungs-Sheet** (194-304): vor dem ersten Teilen einer Liste. Glocke in Blau `0xFF60A5FA`, "Benachrichtigungen aktivieren?", "Aktivieren", "Nicht jetzt". Hauptfrage: "Darf die App dich bei Änderungen benachrichtigen?"
- Beide Texte fest auf Deutsch, nicht übersetzt.

### 2.7 Tools (35, `avo_tool_declarations.dart` und `_runTool` in `avo_assistant_service.dart:226-311`)

| Bereich | Tools | Bestätigung |
|---|---|---|
| Rezepte | `search_recipes`, `get_saved_recipes`, `get_recipe_nutrition` (schätzt per zweitem Gemini-Aufruf), `add_recipe_to_list` (mit Portionen und Angebotspreisen) | nein |
| Listen lesen | `get_lists`, `get_list_contents`, `get_shopping_history` | - |
| Listen ändern | `add_item_to_list`, `ask_pick_list`, `check_items`, `complete_list`, `add_history_items_to_list`, `update_item`, `move_items`, `create_list`, `rename_list` | nein |
| Löschen | `delete_item`, `delete_list` | ja, über `confirm`-Parameter (Modell muss zweimal aufrufen) |
| Einstellungen/Profil | `update_setting` (12 Schlüssel), `get_user_profile`, `get_app_info` | nein (auch nicht bei Allergien) |
| Kalorien | `setup_nutrition_goal` (Rückfrage beim Ersetzen), `get_nutrition_status`, `log_food` (schätzt per Gemini), `log_water`, `log_weight`, `delete_food_log` (Rückfrage), `get_weekly_nutrition_summary`, `get_challenge_status` | teils |
| Angebote/Sparen | `search_offers`, `compare_list_prices`, `get_personalized_deals`, `get_restock_suggestions`, `get_savings_summary` | - |
| Teilen | `split_trip_cost` (legt Splits in DB an) | nein |

`update_setting`-Schlüssel (avo_settings_bridge.dart:54-67): `theme_mode`, `accent_color`, `language`, `notifications`, `display_name`, `diet_preferences`, `allergies`, `age`, `gender`, `height`, `calorie_tracking`, `zip_code`.

Lücken gegenüber der App (Plan: "Avo kann alles"): kein Foto vom Essen, kein Barcode, kein Listenimport per Foto, kein Teilen/Einladen einer Liste, kein Wochenplan, keine Rezepte anlegen/bewerten/speichern, kein Einkaufsmodus starten, keine Modul-Schalter, kein Apple Health, keine Challenge starten (Tool sagt das selbst, 1733-1736), keine Widget- oder Benachrichtigungs-Unterkategorien.

---

## 3. Design-Probleme heute

### 3.1 Paper-Reste (Serife, Creme, Terrakotta, Kicker)
- Georgia-Serife für Titel "Avo" (avo_chat_widgets.dart:356-361), "Wie kann ich helfen?" (32-37), Platzhalter im Eingabefeld (192-195) und für jede Avo-Antwort (avo_payload_cards.dart:72-76).
- `PaperColors.surface/hairline/cream/ink/terracotta/sage/creamInk/faint/paper` in avo_chat_widgets.dart:77-81, 115-117, 129, 168-172, 194, 218-221, 228-231, 325, 343, 383, 390 und avo_payload_cards.dart:25, 28, 231, 381.
- Senden-Button terrakotta (avo_chat_widgets.dart:218), "Zeigen" terrakotta (home_screen.dart:312).
- Home-Hinweisstreifen mit fester Creme `0xFFEFE8DA` und Text `0xFF5A5346` (home_screen.dart:287, 304) ohne Dunkelmodus-Variante.
- Kicker in Großbuchstaben mit Laufweite 1.5 auf Avo-Nudge-Karten (avo_nudge_card.dart:55-68, calorie_recipe_nudge_card.dart:47-58); App-Info-Thema als Akzent-Kicker (avo_payload_cards.dart:676-683).
- Icons in getönten Flächen: Salbei-Kreis hinter Avo (avo_chat_widgets.dart:339-349), Glocke im getönten Kreis (contextual_prompt_service.dart:229-241).

### 3.2 Abweichungen von den Apple-Regeln
- Zwei Einstiege statt einem (Plan 1): Orb (main_scaffold.dart:332-338) und Hinweisstreifen (home_screen.dart:279-280).
- Avo-Orb ist kein Glas, sondern eine Fläche mit hartem Schatten (main_scaffold.dart:434-443); Lucide statt SF Symbols (main_scaffold.dart:447). Material-Icons im Chat (`Icons.arrow_back_ios_new_rounded`, `Icons.add_rounded`, `Icons.keyboard_hide_rounded`, `Icons.arrow_upward_rounded`).
- Kopfzeile und Eingabefeld sind keine schwebende Glasebene; Inhalte scrollen nicht darunter, keine Scroll-Edge-Effekte. Die Kopfzeile ist ein fester Row-Block (avo_chat_screen.dart:373-394).
- Touch-Ziele unter 44 pt: Kopfzeilen-Buttons 34 pt (avo_chat_widgets.dart:434-437), Senden 34 pt (214-215), Chips ca. 34 pt hoch (75), Artikelzeilen in Karten ca. 36 pt (avo_payload_cards.dart:249), Verlaufs-Chips ca. 28 pt (372), "Hinzufügen" und X auf Nudge-Karte ca. 26-28 pt (avo_nudge_card.dart:364, 379), X im Ernährungs-Dialog 28 pt (contextual_prompt_service.dart:129-130).
- Bewegung mit festen Dauern und Kurven statt Federn: Scrollen 300 ms easeOut (avo_chat_screen.dart:147-151), Senden-Button 180 ms (avo_chat_widgets.dart:212-213), Untertitel 200 ms (363-364), Tipp-Punkte 1200 ms Endlosschleife (262-265).
- Kein Reduce Motion (Tipp-Punkte laufen immer), kein Reduce Transparency, kein erhöhter Kontrast.
- VoiceOver: keine `Semantics` im ganzen Ordner `screens/ai`; Kopfzeilen-Buttons, Senden, Chips, Abhak-Kreise ohne Label; Abhak-Kreis ist nie gefüllt (avo_payload_cards.dart:251-257).
- Haptik ohne Bedeutung: leichte Haptik bei jedem Senden und Zurück (avo_chat_screen.dart:173, 378), mittlere bei "Neuer Chat" (386); Abhaken im Chat mit leichter Haptik, Erfolg ohne Erfolgshaptik.
- Agency: Einstellungs-Karte ohne Rückgängig (avo_payload_cards.dart:588-653); Löschen ohne Rückgängig, nur Textfrage.
- Hartkodierte Farben statt Tokens: `0xFF1C1C1E`, `0xFF2C2C2E`, `0xFF5A5A5E`, `0xFF48484A` (avo_chat_widgets.dart:77-80, 168-171, 194, 220, 230, 325), `Colors.amber` (avo_payload_cards.dart:167), `Colors.red.shade400` (597), `0xFF60A5FA` (contextual_prompt_service.dart:233, 274).
- Avo-Antworten werden mit `PaperTextStyles.serif(15)` gesetzt, User-Text mit 14 pt: zwei verschiedene Schriften im selben Gespräch.
- "Premium"-Kapsel in der Kopfzeile (avo_chat_widgets.dart:379-395) ist reine Statusanzeige ohne Funktion und widerspricht dem Namen "Pro".
- Maskottchen in jeder Antwort fehlt, obwohl der Service einen Gesichtsausdruck berechnet (siehe 4).

### 3.3 Feste Maße, die bei großer Schrift oder 320 pt brechen
Die App begrenzt `textScaler` nirgends (grep ohne Treffer), Schrift wächst also mit Dynamic Type, die Kästen aber nicht:
- Rezeptkarten fest `SizedBox(height: 140)` und Breite 200, Bild 80 (avo_payload_cards.dart:131-152): bei großen Stufen überläuft der Text die Karte.
- Kopfzeile: 34-pt-Kreise, 38-pt-Avatar, Kapsel "Premium", Tastatur-Button und "+" in einer Zeile (avo_chat_widgets.dart:328-416); bei 320 pt und offener Tastatur bleibt für Titel kaum Platz.
- Listenname in `_ListItemsView` ohne `Expanded` vor `Spacer` (avo_payload_cards.dart:225-228): langer Name ergibt Overflow.
- Nährwert-Zeile mit 4 Spalten `spaceBetween`, Werte 18 pt fett (avo_payload_cards.dart:534-546): bei Bedienungshilfen-Größen Overflow.
- Senden-Button 34 x 34 mit 19-pt-Icon, fest (avo_chat_widgets.dart:214-226).
- User-Blase `maxWidth: size.width * 0.78` (avo_chat_widgets.dart:109-111) statt Layout-Constraints.
- Home-Hinweisstreifen einzeilig mit Ellipse (home_screen.dart:300-307): bei 320 pt oder großer Schrift ist der Satz abgeschnitten.
- Nudge-Zeilen alle `maxLines: 1` (avo_nudge_card.dart:327-353): Angebotszeile wird bei großer Schrift unlesbar abgeschnitten.
- Orb-Größe skaliert mit Bildschirmbreite statt Schrift (main_scaffold.dart:144-150, 432-433).
- Ernährungs-Dialog Breite `0.88 * Bildschirmbreite`, Buttons fest `height: 50` (contextual_prompt_service.dart:101, 158, 267).
- Abstände mit fixen Pixelwerten (`SizedBox(height: 2/14/28)`) statt `AppDimensions`.

---

## 4. Bugs, Risiken und Performance

### Funktion
- **Chat-Verlauf und Modell-Gedächtnis laufen auseinander:** `_messages` lebt nur im State des Screens (avo_chat_screen.dart:91), die Gemini-Session im Singleton (avo_assistant_service.dart:66-70). Schließt man den Chat und öffnet ihn wieder, ist die Oberfläche leer, Avo erinnert sich aber an das alte Gespräch und schickt den Kontext nicht neu.
- **Rückfragen beim Löschen auf Englisch:** Die Fragen sind feste englische Strings (avo_assistant_service.dart:1098, 1117, 1392-1395, 1662), und der System-Prompt verlangt, sie "verbatim" zu stellen (avo_system_prompt.dart:62-65).
- **Bestätigung ist nicht erzwungen:** Das Modell kann `delete_item`/`delete_list` direkt mit `confirm: true` aufrufen (1091, 1111); die App prüft nicht, ob der Nutzer wirklich zugestimmt hat. Widerspricht "Löschen nur mit Rückfrage".
- **`complete_list` ist nicht derselbe Abschluss wie in der App:** hakt nur alle Artikel ab (715-729), legt aber keinen Verlaufs-Eintrag an und füttert die Kaufstatistik nicht (App-Weg: `shopping_trip_completion.dart:97` ruft `ShoppingHistoryService.completeShoppingTrip`). Dadurch fehlen Nachkauf-Vorschläge und Ersparnis für über Avo abgeschlossene Einkäufe.
- **Fehlertexte, Wissensbasis und Einstellungs-Karte englisch:** Service-Fehler (160, 213, 218), `AvoAppKnowledge` komplett englisch (avo_app_knowledge.dart:26-83), `displayName`/Werte der Einstellungs-Karte englisch ("Diet preferences", "Light", "on") (avo_settings_bridge.dart:93-461).
- **Falsche Fakten in `AvoAppKnowledge`:** Preise in Dollar ("$2.99 / month", avo_app_knowledge.dart:14-15), Premium-Vorteile, die es so nicht gibt (unbegrenzter Chat, Custom Themes, Priority Sync, 28-30), Name "Shoply".
- **Gesichtsausdruck ungenutzt:** `_inferExpression` (1961-1971) prüft nur englische Wörter ("added", "done") und das Ergebnis `avoExpression` wird nirgends angezeigt. Zwei parallele Enums `AvoExpressionType` und `AvoExpression`; Parameter `animate` in `AvoMascot` ohne Wirkung.
- **Ziel-Liste fest die erste:** Kontext `currentListId = lists.first` (avo_chat_screen.dart:241), Verlauf-Hinzufügen immer in `lists.first` (297), `get_list_contents` und `compare_list_prices` ohne ID nehmen die erste Liste (628, 850). Home-Nudge nimmt dagegen die zuletzt geänderte Liste (avo_nudge_card.dart:125-127): inkonsistent.
- **Listenauswahl nur 3 Listen** (avo_payload_cards.dart:468); ab der vierten Liste kann man über die Karte nicht hinzufügen, und es gibt keine Option "Neue Liste".
- **Listen-Karte zeigt max. 10 offene Artikel** ohne Hinweis auf weitere (avo_payload_cards.dart:233).
- **Typ-Casts können Tools abbrechen:** `args['max_results'] as int?` (321) und `args['limit'] as int?` (586) werfen, wenn das Modell eine Kommazahl liefert; dann kommt nur `{'error': ...}` zurück.
- **Function-Calling-Schleife max. 4 Runden** (179): danach kann eine leere Antwort ohne Text erscheinen.
- **Keine Markdown-Darstellung:** Antworten mit `**fett**` oder Listen erscheinen roh.
- **Datum im Verlauf** fest `d/m/yyyy` (avo_payload_cards.dart:338), Zeiteinheit "m" fest (164).
- **Restock-Hinweis widerspricht dem Code:** Tool-Text sagt "needs 3+ tracked purchases" (avo_assistant_service.dart:990-992), Schwelle ist 2 (avo_nudge_service.dart:153).
- **Benachrichtigung Abendessen-Ideen** wird beim Tippen nicht geroutet (navigation_service.dart:75-95 kennt `avo_dinner_ideas` nicht).
- **Senden während Avo antwortet** wird still ignoriert (avo_chat_screen.dart:171), der Button sieht trotzdem aktiv aus.

### Widerspruch zum Plan (verworfene Funktionen sind heute aktiv)
- `compare_list_prices` (Korbsumme pro Markt, "welcher Laden ist am günstigsten") (avo_tool_declarations.dart:223-240, avo_assistant_service.dart:842-924).
- `search_offers` liefert `cheapest_store`/`cheapest_price` und wird für "which store is cheapest" beworben (824-825, avo_tool_declarations.dart:208-213).
- System-Prompt: "which store is cheapest for my list", "how much would I save at X vs Y" (avo_system_prompt.dart:44-53) und "mention a cheaper store to a money-saver" (117-118).
- Chip "Welcher Laden ist für meine Liste am günstigsten?" (avo_chat_screen.dart:50, app_translations.dart:406/1575).
- Angebots-Nudge wechselt zu einem anderen Markt, wenn er mehr als 0,50 Euro billiger ist (avo_nudge_service.dart:536-542): widerspricht "nur Angebote des Markts dieser Liste".
- Keine Modul-Schalter und kein Kill-Switch für Angebote in den Avo-Tools (grep nach einem Offers-Flag ohne Treffer). Angebote können in Avo nicht "spurlos verschwinden".

### Sicherheit und Verantwortung
- **API-Schlüssel in der App:** `Env.geminiApiKey` direkt im Client (avo_assistant_service.dart:92, 450, 1819). Plan: Aufrufe über Supabase Edge Function, Claude statt Gemini.
- **Allergien nur weich beachtet:** `search_recipes` filtert nur, wenn das Modell `exclude_allergens` übergibt (321); das Profil wird nicht erzwungen. Abgleich per Teilstring (336-338) verfehlt deutsche Komposita und Plural ("Nüsse" findet "Haselnuss" nicht). Sicherheitsrelevant.
- **Allergien und Diät per Chat ohne Rückfrage überschreibbar:** `_setListField` ersetzt die ganze Liste (avo_settings_bridge.dart:396-434). "Füge Nüsse hinzu" kann alle anderen Allergien löschen, ohne Rückgängig.
- **Gesundheitsdaten an Drittanbieter:** Allergien, Diät, Name, Gewicht und Ziele gehen bei jeder Kontextänderung an Gemini; in der Oberfläche gibt es keinen Hinweis darauf.
- **`split_trip_cost`** schreibt Kostenaufteilungen ohne Rückfrage in die DB (1067-1073).
- **Kein Nutzungslimit:** jeder Nutzer kann unbegrenzt Anfragen auslösen (Kosten, Missbrauch).

### Performance
- Keine Streaming-Antwort; bis zu 5 sequentielle Modellaufrufe pro Nachricht (179-190), jeder schickt die komplette History (bis 10 Nutzer-Runden).
- `add_recipe_to_list` fügt Zutaten einzeln und nacheinander ein (547-566); `add_history_items_to_list` nutzt `ItemsNotifier.addItem` pro Artikel (757-765) und löst damit pro Artikel Reload und Push aus (genau das, was 540-542 an anderer Stelle vermeidet).
- Chat-Batch "Alle hinzufügen" schreibt sequentiell (avo_chat_screen.dart:305-314).
- `_resolveRecipe`, `split_trip_cost`, `add_history_items_to_list` laden bis zu 30 Verlaufs-Einträge, um einen per ID zu finden (743, 1023).
- Nährwert-Schätzungen erzeugen bei jedem Aufruf ein neues `GenerativeModel` (448, 1817).
- `Image.network` in Rezeptkarten ohne Cache und ohne `cacheWidth` (avo_payload_cards.dart:150).
- Maskottchen-PNGs (ca. 450 x 550 px) werden für 22-38 pt ohne `cacheWidth` dekodiert (avo_mascot.dart:80-86).
- `_buildContext` lädt bei kaltem Cache die Artikel von 3 Listen, bevor die Nachricht überhaupt rausgeht (avo_chat_screen.dart:217-235): sichtbare Verzögerung vor den Tipp-Punkten nicht, aber vor der Antwort.
- Initialisierung erst in `initState` des Chats (126-134): die erste Nachricht kann "I'm not ready yet" bekommen, wenn sie vor Ende der Initialisierung gesendet wird.

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Listen:** `listsNotifierProvider`, `itemsNotifierProvider(listId)` (nicht autoDispose, damit Avo ihn ausleihen kann, items_provider.dart:438), `itemRepositoryProvider`, `ListRepository`, `ItemRepository`, `UnreadService`, `OfflineCacheService`. Route `/lists/:id?name=` aus Karten.
- **Rezepte:** `RecipeService` (Suche, gespeicherte, per ID), `Ingredient.adjustForServings`, `RecipeOfferService`; Route `/recipes/:id`. `ContextualPromptService` wird vom Rezepte-Tab aufgerufen.
- **Kalorien:** `calorieTrackingEnabledProvider`, `nutritionGoalProvider`, `weeklyNutritionSummaryProvider`, `invalidateNutritionLog`, `FoodLogService`, `WaterLogService`, `WeightLogService`, `NutritionGoalService`, `NutritionGoalCalculator`, `activeChallengesProvider`.
- **Angebote/Sparen:** `OfferPriceService`, `UserLocationService` (PLZ), `basketComparisonProvider`, `personalizedDealsProvider`, `userZipCodeProvider` (alle aus `price_comparison_provider.dart`), `totalSavingsOf`/`tripsInMonth`.
- **Verlauf/Teilen:** `ShoppingHistoryService`, `ExpenseSplitService`, `PurchaseTrackingService` (`item_purchase_stats`).
- **Profil/Einstellungen:** `currentUserProvider`, `UserService.updateUserProfile`, `themeModeProvider`, `accentColorProvider`, `languageProvider`, `NotificationPreferencesService`, `MascotNotificationService` (Rearm nach Einstellungsänderung). Benachrichtigungs-Einstellungen zeigen "Avo-Erinnerungen" (`notifications_screen.dart:127-136`).
- **Abo:** `isSubscribedProvider` (nur Anzeige).
- **Onboarding:** `appPriorities` steuern Chips, System-Kontext und Reihenfolge der Home-Karten.
- **Navigation:** `MainScaffold` (Orb, `navScale`), `app_router.dart`, `navigation_service.dart` (Benachrichtigungs-Typen), `DeepLinkService` (Siri-Aktionen laufen an Avo vorbei über `app.dart:96-143`).
- **Gemeinsam genutzte Widgets/Stile:** `AvoMascot` (auch in `name_prompt_screen.dart:86`, `tutorial_overlay.dart:344, 426`, beiden Home-Nudge-Karten), `NudgeCardShell`, `PaperColors`/`PaperTextStyles`, `AppColors`.
- **Strings:** `app_translations.dart` (EN ab ca. Zeile 330, DE ab ca. 1500): `how_can_i_help`, `ask_avo_anything`, `your_shopping_assistant`, `thinking_label`, `chip_*` (12 Schlüssel), `avo_*` (ca. 20 Schlüssel, 557-575 / 1726-1744), `avo_hint_home`, `show_label`, `restock_*`, `offer_nudge_*`, `calorie_nudge_title`, `premium_label`. Nicht übersetzt: Service-Fehler, Tool-Rückfragen, `AvoAppKnowledge`, Settings-Bridge-Labels, `ContextualPromptService`.
- **Tests:** `buildSuggestionChipKeys`, `summarizeBasketComparison`, `summarizePersonalizedDeals`, `summarizeWeeklyNutrition`, `summarizeChallengeStatus`, `summarizeLifetimeSavings`, `dominantWeekday`, `habitStrength`, `suggestionPriority`, `offerMatchesItem`, `pickOffer` sind `@visibleForTesting` und vermutlich getestet; beim Umbau mitziehen.
- **Doku:** `docs/redesign/chatgpt-redesign-prompt.md` Abschnitt 3 beschreibt "Eingabe per Text, Kamera oder Mikrofon" für den Chat; im Code gibt es nur Text.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**
- Alle Aktionen der 35 Tools, außer den verworfenen (Korbsumme pro Markt, "günstigster Laden"). Insbesondere: Rezept-Zutaten mit Portionsanpassung auf eine Liste, Artikel bearbeiten und zwischen Listen verschieben, Liste anlegen und umbenennen, Verlauf erneut hinzufügen (einzeln und alle), Kostenteilung, Kalorienziel im Gespräch einrichten (max. zwei Fragen pro Nachricht, vorbefüllt aus dem Profil), Essen/Wasser/Gewicht eintragen mit Schätzung und Hinweis "geschätzt", Wochenrückblick, Challenge-Stand, Ersparnis (Monat und gesamt), Einstellungen per Sprache ändern, PLZ setzen.
- Ergebnis-Karten mit direkter Aktion (abhaken, hinzufügen, öffnen) statt reinem Text; Listenauswahl, wenn das Ziel unklar ist.
- Rückfrage vor jedem endgültigen Löschen (Artikel, Liste, Essens-Eintrag) und vor dem Ersetzen eines Kalorienziels.
- Proaktive Hinweise aus echten Daten: Nachkauf nach Kaufrhythmus inkl. Wochentag-Muster, Snooze pro Kaufzyklus, Benachrichtigung nur, wenn die App seit gestern nicht offen war; abschaltbar.
- Personalisierung über Onboarding-Prioritäten, ohne sie dem Nutzer vorzulesen.
- Persönlicher Leerzustand mit Vorschlägen, die man antippen kann.

**Daten und Regeln**
- Kontrakt `AvoWidgetPayload`/`AvoPayloadKind` als Trennung zwischen Tool-Ergebnis und Darstellung (gut erweiterbar für neue Karten: Angebote, Kalorien, Wochenplan).
- Session-Wechsel bei Kontowechsel (avo_assistant_service.dart:105-111), damit keine Listen oder Allergien zwischen Konten durchsickern.
- History-Kürzung nur an Nutzer-Runden, damit Function-Call-Paare zusammenbleiben (130-146); Reset bei abgebrochenem Tool-Aufruf (205-208).
- Kontext nur bei Änderung senden; offene Listen nicht unnötig per Realtime abonnieren (avo_chat_screen.dart:208-236).
- Bulk-Änderungen mit einem Push und einem "gelesen"-Vermerk statt pro Artikel (`_afterBulkListChange`, 1878-1895).
- Strenge Validierung bei Kalorienzielen und Einstellungen (Wertebereiche, erlaubte Enums), damit erfundene Werte nicht gespeichert werden.
- Angebots-Abgleich über den Kopf deutscher Komposita (`offerMatchesItem`), Rabatt nur, wenn der Händler einen "statt"-Preis nennt (keine erfundenen Rabatte), Angebot nur bei echtem Standort.
- Offer-Cache 6 h und max. 6 Abfragen pro Berechnung.
- Kalorien-Tools prüfen den Kalorien-Schalter und bieten das Einschalten nur nach Zustimmung an.
- Verschieben zwischen Listen bleibt durch RLS auf eigene Listen beschränkt.

**Sonderfälle**
- Keine Listen, kein Verlauf, keine PLZ, Kalorien aus, kein Ziel, kein Rezept gefunden, Rezept ohne Zutaten, Kontingent erschöpft (429), nicht angemeldet.
- Avo im Gespräch geteilter Listen: Abhaken und Hinzufügen erscheinen bei anderen Mitgliedern live.
- Zweisprachigkeit: Avo antwortet in der Sprache des Nutzers; Kategorien bleiben sprachneutrale IDs.
- Benachrichtigungs-Kategorie "Avo-Erinnerungen" in den Einstellungen.
- Maskottchen in vier Stimmungen (winkend, begeistert, nachdenkend, feiernd) als erkennbare Avocado, auch wenn es sparsamer eingesetzt wird.
