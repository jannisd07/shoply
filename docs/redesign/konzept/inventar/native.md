# Inventar: iOS-native Teile (Ist-Zustand)

Stand: 2026-11-07, Branch `main` (Commit 3e886d0). Nur gelesen, nichts geändert.
Umfang: Home-Screen-Widgets, Siri/App Intents, AppDelegate, Liquid-Glass-Plattformview, Info.plist und Entitlements, Mitteilungen (lokal und Push), App-Icon und Startbildschirm, dazu die Dart-Seite, die diese Teile füttert.

Wichtige Korrektur vorab: `ios/Runner/VoiceAssistantPlugin.swift` und `lib/data/services/voice_assistant_service.dart` gibt es nicht mehr. Beide wurden gelöscht (Commits 38ce871 und 46e004b). Die Verbesserungsliste (`docs/redesign/avo-verbesserungsliste.md`, Punkt 12, Zeile 287) nennt sie noch als Ist-Stand, das ist veraltet. Siri läuft heute nur über `ios/Runner/AppIntents.swift`. Einen Sprachmodus (Mikrofon, Spracherkennung, Sprachausgabe) gibt es nirgends, auch kein Paket dafür in `pubspec.yaml`.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `ios/ShoppingListWidget/ShoppingListWidget.swift` | Listen-Widget (klein, mittel, groß), Datenmodell, App-Group-Lesen, `ToggleItemIntent` (Abhaken im Widget), direkter Supabase-PATCH, `SelectListIntent` (Liste wählen), `@main WidgetBundle` mit allen drei Widgets | 748 |
| `ios/ShoppingListWidget/QuickAddWidget.swift` | Widget "Schnell hinzufügen" (klein, mittel): häufig gekaufte Artikel, ein Tipp fügt per direktem Supabase-POST hinzu | 321 |
| `ios/ShoppingListWidget/SavedRecipesWidget.swift` | Widget "Gespeicherte Rezepte" (klein, mittel, groß), nur Links in die App | 197 |
| `ios/ShoppingListWidget/ShoppingListWidgetControl.swift` | Leere Datei (nur Kommentar). Kein Control-Center-Steuerelement vorhanden | 14 |
| `ios/ShoppingListWidget/Info.plist` | Extension-Punkt `com.apple.widgetkit-extension` | 11 |
| `ios/ShoppingListWidget/Assets.xcassets` | `AccentColor`, `WidgetBackground`, `AppIcon`: alle drei leer (keine Farbwerte, keine Bilder) | – |
| `ios/ShoppingListWidgetExtension.entitlements` | App Groups `group.com.shoply.app` und `group.com.dominik.shoply` (zweite wird nirgends benutzt) | 11 |
| `ios/ShoppingListWidget/ShoppingListWidget.entitlements` | Laut CLAUDE.md verwaist, nicht im Xcode-Projekt; im Ordner nicht mehr vorhanden | – |
| `ios/Runner/AppDelegate.swift` | Plugin-Registrierung, Registrierung der Liquid-Glass-Views, MethodChannel `com.shoply.widget` (7 Methoden), Mitteilungs-Delegate, APNs/FCM | 308 |
| `ios/Runner/AppIntents.swift` | Siri/Kurzbefehle: 6 App Intents, 3 Entities, 3 Ergebnis-Snippets, `ShoplyAppShortcuts` (Siri-Sätze DE/EN) | 445 |
| `ios/Runner/LiquidGlassViewFactory.swift` | Plattformviews `shoply/liquid_glass` (eine Glasfläche) und `shoply/liquid_glass_group` (mehrere verschmelzende Flächen in `UIGlassContainerEffect`), Fallback `UIBlurEffect` vor iOS 26 | 253 |
| `ios/Runner/Info.plist` | Anzeigename "Avo", URL-Schemes, Berechtigungstexte, Hintergrundmodus Push, Ausrichtungen, Scene-Manifest | 120 |
| `ios/Runner/Runner.entitlements` / `RunnerDebug.entitlements` | Push (production/development), Sign in with Apple, App Groups, Keychain-Gruppe, Associated Domains `shoplyai.app` | je 26 |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset` | App-Icon in 15 festen Größen, keine Dunkel-/Getönt-Variante, kein Icon-Composer-Icon (`.icon`) | – |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset` + `Base.lproj/LaunchScreen.storyboard` | Startbildschirm: 1-px-Platzhalterbild auf `systemBackground` | 41 (Storyboard) |
| `ios/PrivacyInfo.xcprivacy` | Privacy Manifest: kein Tracking, 4 API-Gründe | 47 |
| `ios/Runner.xcodeproj/project.pbxproj` | Deployment Target App 15.6, Widget 17.0; Widget-Anzeigename `ShoppingListWidget` | – |
| `lib/data/services/widget_service.dart` | Dart-Seite des Widget-Kanals: Liste, verfügbare Listen, häufige Artikel, Rezepte, Zugangsdaten, Löschen | 230 |
| `lib/presentation/state/items_provider.dart` (ca. 130-155) | Schreibt Listendaten ins Widget bei jeder Änderung einer offenen Liste | – |
| `lib/presentation/state/lists_provider.dart` (ca. 83-118) | Schreibt verfügbare Listen und häufige Artikel | – |
| `lib/presentation/state/saved_recipes_provider.dart` (ca. 63-90) | Schreibt gespeicherte Rezepte | – |
| `lib/main.dart` (ca. 121-180) | Zugangsdaten bei jedem Token-Refresh ins Widget, Widget-Daten beim Abmelden löschen, Mitteilungs-Setup | – |
| `lib/data/services/deep_link_service.dart` | Verarbeitet `shoply://add-item`, `create-list`, `list/<id>`, `recipe/<id>`, `recipes/...` (Ziel der Widgets und Intents) | 261 |
| `lib/app.dart` (ca. 88-160) | Handler für Siri "Artikel hinzufügen" und "Liste erstellen" | – |
| `lib/presentation/widgets/common/liquid_glass_container.dart` | Dart-Wrapper `LiquidGlassContainer`, `AdaptiveGlass`, `LiquidGlassGroup` für die nativen Glas-Views | 239 |
| `lib/data/services/notification_service.dart` | Lokale Mitteilungen (`flutter_local_notifications`): sofort und geplant, Tipp-Weiterleitung | 254 |
| `lib/data/services/fcm_service.dart` | Firebase Messaging: Erlaubnis, Token in `users.fcm_token`, Vordergrund-Anzeige, Tipp-Weiterleitung | 249 |
| `lib/data/services/push_notification_service.dart` | Sendet Push an andere Nutzer über Edge Function `send-push-notification` | 152 |
| `lib/data/services/notification_preferences_service.dart` | Hauptschalter (Supabase `users.notification_enabled`) und 8 Kategorie-Schalter (nur lokal) | 164 |
| `lib/data/services/mascot_notification_service.dart` | Avo-Erinnerungen: "Nachkaufen" (9 Uhr), "Abendessen-Idee" (18 Uhr), Meilenstein-Texte | 360 |
| `lib/data/services/navigation_service.dart` | Ziel-Routing beim Tippen auf eine Mitteilung | 109 |
| `supabase/functions/send-push-notification/index.ts` | FCM-Versand, APNs-Payload (Ton, Badge 1, mutable-content), Berechtigungsprüfung | 286 |

---

## 2. Screens, Sheets und Dialoge (native Oberflächen)

Native Teile haben keine App-Screens im üblichen Sinn. Hier sind alle Oberflächen erfasst, die der Nutzer außerhalb der Flutter-App sieht: Widgets, Siri-Dialoge und -Snippets, Mitteilungen, System-Dialoge, Icon und Startbild, dazu die Glasflächen in der App.

### 2.1 Widget "Einkaufsliste" (`ShoppingListWidget`)

- **Datei:** `ios/ShoppingListWidget/ShoppingListWidget.swift`
- **Einstieg:** Widget-Galerie, Name "Einkaufsliste", Beschreibung "Wähle eine Einkaufsliste und hake Produkte direkt ab." (Z. 733-734). Konfiguration über `SelectListIntent` ("Select Shopping List", englisch, Z. 290-296). Tipp auf freie Fläche öffnet `shoply://list/<id>` (Z. 692-696), das leitet über `/list/:listId` auf `/lists/:listId` um (`app_router.dart` Z. 357).
- **Hauptfrage:** Was muss ich noch kaufen?
- **Größen und Aufbau:**
  - **Klein** (Z. 415-483): Kopfzeile mit `cart.fill`, Listenname (12 pt fett), Zähler "abgehakt/gesamt" (10 pt, gerundet). Darunter bis zu 5 Artikel als Abhak-Zeilen ohne Menge, offene zuerst, dann abgehakte. Unten "+N mehr" (9 pt).
  - **Mittel** (Z. 487-581): Kopfzeile wie oben (14 pt), Zähler als Kapsel. Bis zu 8 Artikel in zwei Spalten, mit Menge "2x ". Unten "+N mehr" (10 pt).
  - **Groß** (Z. 585-684): Kopfzeile (17 pt), Zähler-Kapsel, 3 pt hoher grüner Fortschrittsbalken. Bis zu 14 Artikel (14 pt) mit Menge. Unten "+N weitere" (11 pt).
- **Komponenten:** `ItemRowView` (Z. 359-411): `Button(intent: ToggleItemIntent)` mit 20-pt-Kreis (leer: grauer Ring; abgehakt: grüner Kreis mit Häkchen), Name einzeilig, abgehakt durchgestrichen und blass.
- **Zustände:**
  - Leer (keine Artikel): Häkchen-Symbol und "Alles erledigt!", groß zusätzlich "Deine Liste ist leer" (Z. 444-458, 523-537, 640-657). Alle Artikel abgehakt zeigt dagegen die durchgestrichene Liste, nicht "Alles erledigt".
  - Platzhalter (Galerie): feste Beispielliste "Einkaufsliste" mit Milch, Brot, Eier, Butter, Tomaten, Käse (Z. 32-47).
  - Keine Daten / abgemeldet: Name "Shoply", leer (Z. 49-57). Alter Markenname.
  - Konfigurierte Liste nicht im Cache: zeigt stillschweigend die zuletzt in der App geöffnete Liste (Legacy-Schlüssel `widget_shopping_list`, Z. 96-113).
  - Laden, Fehler, offline, Pro gesperrt, Modul aus: nicht vorhanden. Das Widget liest nur den lokalen App-Group-Cache.
- **Aktionen:** Tipp auf Zeile hakt ab bzw. wieder auf (lokal im Cache, dann PATCH an Supabase im Hintergrund, Z. 148-251). Tipp daneben öffnet die Liste in der App.
- **Datenquellen:** App Group `group.com.shoply.app`, Schlüssel `widget_list_<id>`, `widget_shopping_list`, `widget_available_lists`, `widget_supabase_url/anon/token`. Geschrieben von `WidgetService.updateShoppingListWidget` aus `ItemsNotifier._updateWidget` (`items_provider.dart` Z. 133-155), also nur für Listen, die auf diesem Gerät in der App geöffnet wurden. Zeitleiste lädt alle 30 Minuten neu, aber nur aus dem Cache (Z. 336-342), nie aus dem Netz.
- **Sichtbare Texte:** "Einkaufsliste", "Alles erledigt!", "Deine Liste ist leer", "+N mehr", "+N weitere", "Shoply". Alles deutsch fest im Code, keine Lokalisierung.

### 2.2 Widget "Schnell hinzufügen" (`QuickAddWidget`)

- **Datei:** `ios/ShoppingListWidget/QuickAddWidget.swift`
- **Einstieg:** Widget-Galerie "Schnell hinzufügen", "Füge häufig gekaufte Artikel mit einem Tipp zu deiner Liste hinzu." (Z. 317-318). Nutzt denselben `SelectListIntent` zur Listenwahl; ohne Wahl die erste Liste.
- **Hauptfrage:** Was kaufe ich oft und will es schnell auf die Liste setzen?
- **Aufbau:** Kopfzeile `bolt.fill` + "Schnell hinzufügen" (12 pt fett). Darunter 3 (klein) bzw. 4 (mittel) Zeilen als getönte Rechtecke (Radius 10) mit Artikelname (13 pt) und grünem `plus.circle.fill` (Z. 219-248, 250-301). Kein Hinweis, in welche Liste hinzugefügt wird.
- **Zustände:** "Keine Liste ausgewählt" oder "Noch keine Vorschläge" mit `cart.badge.plus` (Z. 273-288). Kein Erfolgs-Feedback nach dem Tipp, kein Fehlerzustand, kein "schon auf der Liste".
- **Aktionen:** Tipp auf Zeile startet `QuickAddItemIntent` (Z. 43-72): POST an `shopping_items` mit Name, Menge, `category`/`category_id`, `added_by` (Z. 79-134), danach Eintrag in den Listen-Cache und Neuladen des Listen-Widgets.
- **Datenquellen:** `widget_recent_items` aus `ListsNotifier._updateWidgetRecentItems` (`lists_provider.dart` Z. 104-118, Quelle `item_purchase_stats` über `getFrequentItems(limit: 8)`), `widget_supabase_user_id`.
- **Größen:** klein, mittel.

### 2.3 Widget "Gespeicherte Rezepte" (`SavedRecipesWidget`)

- **Datei:** `ios/ShoppingListWidget/SavedRecipesWidget.swift`
- **Einstieg:** Widget-Galerie "Gespeicherte Rezepte", "Deine gespeicherten Rezepte auf einen Blick — antippen zum Öffnen." (Z. 193-194). Statische Konfiguration, keine Auswahl.
- **Hauptfrage:** Was will ich kochen?
- **Aufbau:** Kopfzeile `bookmark.fill` + "Rezepte". Zeilen mit grünem `fork.knife.circle.fill`, Name, Kochzeit "25 min" (Z. 76-109). Klein 3, mittel 4, groß 8 Rezepte, darunter "+N mehr". Bilder und Bewertung werden mitgeliefert (`imageUrl`, `rating`), aber nicht angezeigt.
- **Zustände:** leer "Noch keine gespeicherten\nRezepte" (Z. 142-157); Platzhalter mit drei Beispielrezepten.
- **Aktionen:** `Link` auf `shoply://recipe/<id>` je Zeile (Z. 87).
- **Datenquelle:** `widget_saved_recipes` aus `saved_recipes_provider.dart` Z. 74-90.

### 2.4 Siri und Kurzbefehle (`AppIntents.swift`)

Alle Intents haben `openAppWhenRun = true`, öffnen also immer die App und übergeben per Deep Link an Flutter.

| Intent | Siri-Sätze (Z. 372-443) | Dialog / Snippet | Ziel |
|---|---|---|---|
| `AddItemToListIntent` (Z. 87-156) | "Füge {Artikel} zu Avo hinzu", "Trage {Artikel} in Avo ein", "Schreib {Artikel} auf Avo", "Add {item} to Avo" | Fragen "Welches Produkt möchtest du hinzufügen?", "Zu welcher Liste soll ich den Artikel hinzufügen?"; Antwort "{Artikel} wurde zu {Liste} hinzugefügt"; Snippet mit grünem 48-pt-Häkchen, "✓ Hinzugefügt", Artikel, "zu {Liste}" (Z. 159-183) | `shoply://add-item?name&list&quantity` → `app.dart` `_handleSiriAddItem` (Liste per Name suchen, sonst neu anlegen, Artikel hinzufügen, Liste öffnen) |
| `CreateListIntent` (Z. 186-214) | "Erstelle Avo Liste {Name}", "Neue Avo Liste {Name}", "Create Avo list {name}" | "Liste '{Name}' wird erstellt" bzw. "existiert bereits — ich öffne sie" | `shoply://create-list` |
| `ShowShoppingListsIntent` (Z. 217-230) | "Zeige meine Avo Listen", "Öffne Avo", "Open Avo", "Show my Avo lists" | "Öffne deine Einkaufslisten" | `shoply://lists` → `/home` |
| `SearchRecipesIntent` (Z. 259-287) | "Suche {Begriff} Rezepte in Avo" u. a. | "Suche nach {Begriff} Rezepten..."; Snippet mit orangem Lupen-Symbol, "🔍 Suche", "Rezepte werden gesucht..." | `shoply://recipes/search?q=` |
| `ShowSavedRecipesIntent` (Z. 315-334) | "Zeige gespeicherte Rezepte in Avo", "Meine Lieblingsrezepte in Avo" u. a. | Snippet mit rosa Herz, "❤️ Gespeicherte Rezepte", "Öffne deine Favoriten" | `shoply://recipes/saved` |
| `ShowRecipesIntent` (Z. 356-368) | "Zeige Rezepte in Avo" u. a. | "Öffne Rezepte" | `shoply://recipes` |

- **Entities:** `ItemNameEntity` (Vorschläge fest: Milch, Brot, Eier, Butter, Käse, Äpfel, Bananen, Tomaten, Kartoffeln; Z. 46-49), `ListNameEntity` (echte Listennamen aus der App Group plus Eintrag "➕ Neue Liste erstellen"; Z. 66-84), `RecipeQueryEntity` (feste Vorschläge Pasta, Salat, Suppe ...).
- **Hauptfrage je Intent:** eine Aktion ohne die App zu bedienen. Erfüllt wird sie heute nicht, weil jeder Intent die App öffnet.
- **Fehlend gegenüber Plan 10:** "Was steht auf meiner Liste?" (Liste vorlesen), Abhaken per Siri, Einkaufsmodus starten, Avo fragen, Essen/Wasser eintragen, Wochenplan.

### 2.5 Mitteilungen

Darstellung: System-Standard. Keine Kategorien mit Aktionen (`UNNotificationCategory`), keine Gruppierung (`threadIdentifier`), keine Bilder (Avo-Maskottchen), keine Notification Service Extension (obwohl `mutable-content: 1` gesendet wird), keine `interruptionLevel` (zum Beispiel time-sensitive für den Kochtimer). Titel ist bei Push oft der Listenname.

| Typ | Auslöser (Datei:Zeile) | Titel / Text (wie heute) | Sprache | Tipp führt zu |
|---|---|---|---|---|
| Artikel hinzugefügt (`list_update`) | `item_repository.dart` 363-372 | Titel = Listenname, "{Name} added "{Artikel}"" | nur Englisch, fest | Liste |
| Artikel abgehakt (`item_toggled`) | `item_repository.dart` 257-277 | "{Name} checked off "{Artikel}"" bzw. "unchecked" | nur Englisch | Liste (Default-Zweig) |
| Artikel gelöscht (`item_deleted`) | `item_repository.dart` 295-299 | "{Name} removed "{Artikel}"" | nur Englisch | Liste (Default-Zweig) |
| Neues Mitglied (`list_member_joined`) | `list_repository.dart` 216-225 | "New List Member!", "{Name} joined "{Liste}"" | nur Englisch | nichts (Schlüssel `list_id` statt `listId`) |
| Einkauf erledigt (`shopping_complete`) | `shopping_trip_completion.dart` 228-240 | "Einkauf erledigt!", "{Name} hat den Einkauf für „{Liste}" erledigt" | Sprache des Absenders | Liste (Default-Zweig) |
| Rezept bewertet (`recipe_rating`) | `recipe_service.dart` 425-436 | "New Rating!", "{Name} rated "{Rezept}" ⭐⭐⭐⭐ (4/5)" | nur Englisch, Emoji | Rezept |
| Kosten geteilt (`expense_split`) | `expense_split_service.dart` 179-197 | "💶 Share settled" / "💶 Share reopened", "{Name} marked your 3.20 € share ... as paid" | nur Englisch, Emoji | nichts |
| Avo Nachkaufen (lokal, 9 Uhr) | `mascot_notification_service.dart` 76-169 | "🥑 Zeit nachzukaufen?", "{Artikel} ist wahrscheinlich fast aufgebraucht – du kaufst es etwa alle {n} Tage." bzw. mit Angebot "– und gerade im Angebot bei {Markt} ({Preis} €)." | DE/EN | App öffnen (Startseite zeigt Karte) |
| Avo Abendessen-Idee (lokal, 18 Uhr) | `mascot_notification_service.dart` 180-250 | "🥑 Idee fürs Abendessen?", "Du hast heute noch etwa {kcal} kcal übrig – Avo hat ein passendes Rezept gefunden: {Rezept}." | DE/EN | nichts (Typ `avo_dinner_ideas` nicht im Router) |
| Kochtimer (lokal) | `cooking_mode_screen.dart` 171-176 | "Timer fertig!", "{Rezept} · Zeit ist um!" | DE/EN | nichts (keine Payload) |

- **Badge:** Server setzt immer `badge: 1` (`send-push-notification/index.ts` Z. 106). Entfernt wird es nur beim Öffnen einer Liste (`list_detail_screen.dart` Z. 199-200, Paket `flutter_app_badger`).
- **Vordergrund:** AppDelegate zeigt jede Mitteilung als Banner mit Ton (Z. 271-277); zusätzlich zeigt `FCMService._handleForegroundMessage` eine lokale Kopie (Z. 152-166).
- **Einstellungen:** Hauptschalter in Supabase, Kategorien `listActivity`, `shoppingCompleted`, `listInvitations`, `recipeLikes`, `recipeComments`, `newRecipes` (aus), `weeklySummary`, `avoNudges` (Z. 13-21), nur lokal in SharedPreferences.

### 2.6 System-Dialoge (Berechtigungen)

| Berechtigung | Wann gefragt | Text in Info.plist |
|---|---|---|
| Mitteilungen | Sofort beim App-Start, ohne Kontext (`AppDelegate.swift` Z. 50); zusätzlich `FCMService.initialize` (Z. 41) und `DarwinInitializationSettings` mit `request...: true` (`notification_service.dart` Z. 51-55) | System-Text |
| Standort | bei Angeboten/Supermarkt | "Avo nutzt deinen Standort, um Supermärkte und Angebote in deiner Nähe zu finden." (deutsch) |
| Kamera | Bild aufnehmen | "This app needs camera access to scan receipts and take photos." (englisch, nennt Kassenzettel) |
| Fotos lesen / sichern | Bild wählen / speichern | englisch, generisch |
| Tracking (ATT) | wird nie gefragt | "This app needs permission to track usage for analytics and personalization." (vorhanden, aber ungenutzt) |
| Mikrofon, Spracherkennung, Health | fehlen | – |

### 2.7 App-Icon und Startbildschirm

- **Icon:** 3D-Avocado-Maskottchen, winkend, auf weißem Grund (`AppIcon.appiconset/60pt_3x_180px.png`, 1024er ohne Alpha). Keine Varianten für dunkel, getönt oder klar (iOS 18/26), kein Ebenen-Icon für Liquid Glass.
- **Startbildschirm:** `LaunchScreen.storyboard` mit leerem 1-px-Bild auf `systemBackground`; danach übernimmt Flutter.
- **Widget-Extension:** eigener `AppIcon`-Satz leer, Anzeigename der Extension "ShoppingListWidget".

### 2.8 Liquid-Glass-Flächen in der App (native Bausteine)

- **`shoply/liquid_glass`** (`LiquidGlassView`, Z. 140-177): eine `UIGlassEffect`-Fläche (regular oder clear, optional Tönung, interaktiv standardmäßig an), Form über `cornerConfiguration` (fester Radius oder Kapsel). Vor iOS 26 `UIBlurEffect(.systemThinMaterial)` mit Clip.
- **`shoply/liquid_glass_group`** (`LiquidGlassGroupView`, Z. 186-253): mehrere Glasformen in einem `UIGlassContainerEffect`, die bei Annäherung verschmelzen (wie in Nachrichten).
- **Genutzt von:** `LiquidGlassContainer` in `attachment_sheet.dart` Z. 388; `LiquidGlassGroup` in `add_item_composer.dart` Z. 217 (Plus-Kreis und Eingabekapsel); `AdaptiveGlass` an 6 Stellen. Tab-Bar und weitere Glas-Elemente kommen aus dem Paket `adaptive_platform_ui` (8 Dateien), nicht aus dieser Factory.
- **Barrierefreiheit:** `AdaptiveGlass` schaltet bei `MediaQuery.highContrastOf` auf eine feste Fläche um (`liquid_glass_container.dart` Z. 145-170). "Transparenz reduzieren" wird von Flutter nicht abgefragt; das native `UIGlassEffect` reagiert selbst darauf.

---

## 3. Design-Probleme heute

### 3.1 Widgets gegen Apple-Regeln

1. **Feste Schriftgrößen ohne Dynamic Type.** Überall `.font(.system(size: …))`: 9, 10, 11, 12, 13, 14, 17 pt (`ShoppingListWidget.swift` Z. 381, 395, 399, 429, 432, 438, 474, 503, 506, 513, 572, 605, 612, 674; `QuickAddWidget.swift` Z. 233, 238, 268, 282; `SavedRecipesWidget.swift` Z. 90, 94, 102, 133, 136, 151, 168). Keine Textstile (`.headline`, `.subheadline`, `.caption`). 9 und 10 pt liegen unter jeder sinnvollen Lesegrenze.
2. **Eigene Hintergrundfläche statt Container-Hintergrund.** `.containerBackground(.clear, for: .widget)` (Z. 728, `QuickAdd` Z. 312, `SavedRecipes` Z. 188) und zusätzlich `.background(bg)` mit fest Weiß bzw. `Color(white: 0.11)` im Inhalt (Z. 481, 579, 682; `QuickAdd` Z. 299; `SavedRecipes` Z. 175). Folgen: In getönter, klarer bzw. Glas-Darstellung (iOS 18/26) kann das System den Hintergrund nicht entfernen, es bleibt ein heller Block. Wahrscheinlich liegt die Fläche wegen der Standard-Inhaltsränder ab iOS 17 eingerückt im Widget, mit Hintergrundbild am Rand (auf Gerät prüfen). Dazu kommt `padding(12/14/16)` doppelt zu den Systemrändern.
3. **Keine Unterstützung für getönt, klar und Akzent.** Kein `widgetRenderingMode`, kein `.widgetAccentable()`, keine `widgetContentMargins`. Farben werden per `colorScheme` selbst gewählt (`isDark ? .white : .black`, Z. 366-369 u. a.) statt `.primary`/`.secondary`.
4. **Hart codiertes Grün als Akzent** `Color(red: 0.3, green: 0.75, blue: 0.4)` an fünf Stellen (Z. 369, 594; `QuickAdd` Z. 226; `SavedRecipes` Z. 84). Kein Asset, `AccentColor` und `WidgetBackground` sind leer.
5. **Kleine Tippziele.** Abhak-Zeile: 20-pt-Kreis plus 2 pt Abstand oben und unten (Z. 354-355, 407), also etwa 24 pt hohe Ziele. Mittel: 8 Ziele in zwei Spalten. Apple empfiehlt in Widgets wenige, klar getrennte Ziele.
6. **Großes Widget läuft über.** 14 Zeilen × ca. 24 pt + Kopf + Balken ≈ 380 pt (Z. 662). Ein großes Widget ist auf dem iPhone SE 338 pt hoch, auf 6,1"-Geräten ca. 354-382 pt, abzüglich Ränder. Die unteren Zeilen und "+N weitere" werden abgeschnitten.
7. **Abgehakte Zeilen springen.** Sortierung "offen, dann abgehakt" (Z. 460-462, 539-541, 659-661): Nach dem Tipp rutscht der Artikel unter den Finger des nächsten. Es gibt keine Animation (`.contentTransition`, `.invalidatableContent`) und kein Rückgängig.
8. **Kopfzeile mit generischem `cart.fill`** statt App-Marke; Zähler "3/11" ohne Bedeutung für VoiceOver. Es gibt nirgends `accessibilityLabel`.
9. **Rezept-Widget ohne Bilder,** obwohl `imageUrl` geliefert wird. Grüne Gabel-Kreise in jeder Zeile sind "Icons in Reihe" ohne Information.
10. **Quick-Add-Zeilen** sind Reihen identischer getönter Kärtchen (`QuickAdd` Z. 241-244), ohne Ziel-Liste und ohne Rückmeldung.
11. **Keine Familien für Sperrbildschirm, StandBy und Kontrollzentrum.** Nur `.systemSmall/.systemMedium/.systemLarge` (Z. 735, `QuickAdd` Z. 319, `SavedRecipes` Z. 195). `ShoppingListWidgetControl.swift` ist leer.
12. **Texte nicht lokalisiert:** Widget-Texte deutsch, Intent-Titel englisch ("Select Shopping List", "Toggle Shopping Item", "Shopping List", "Quick Add Item", Z. 256, 291, 301; `QuickAdd` Z. 44). Fallback-Name "Shoply" (Z. 51; `QuickAdd` Z. 212) passt nicht zum Anzeigenamen "Avo".

### 3.2 Siri-Snippets und Dialoge

13. **Emojis in Systemtexten:** "✓ Hinzugefügt" (`AppIntents.swift` Z. 170), "🔍 Suche" (Z. 299), "❤️ Gespeicherte Rezepte" (Z. 344), Listeneintrag "➕ Neue Liste erstellen" (Z. 76, 117, 131).
14. **Feste Symbolgröße 48 pt** und Systemfarben `.green`, `.orange`, `.pink` (Z. 167-168, 296-297, 341-342): jeder Snippet hat eine andere Farbe, keine gemeinsame Akzentfarbe.
15. **Snippet wiederholt den Dialog** und sagt "Rezepte werden gesucht..." (Z. 306), obwohl gleichzeitig die App öffnet. Es entsteht ein Lade-Eindruck ohne Inhalt.

### 3.3 Mitteilungen

16. **Emojis im Titel** "🥑 Zeit nachzukaufen?", "🥑 Idee fürs Abendessen?" (`app_translations.dart` Z. 1505, 1526), "💶 Share settled" (`expense_split_service.dart` Z. 180), Sterne-Emojis (`recipe_service.dart` Z. 431). Apple-Stil: klarer Titel, Absender ist das App-Icon.
17. **Englische feste Texte** in fünf Push-Arten (siehe 2.5), dazu "Someone" als Fallback-Name (`item_repository.dart` Z. 393, `list_repository.dart` Z. 214).
18. **Keine Gruppierung pro Liste** (`threadIdentifier`), keine Aktionen ("Abhaken", "Liste öffnen", "Antworten"), keine Zusammenfassung. Bei vielen Pushes im Einkauf entsteht ein unsortierter Stapel.

### 3.4 Liquid Glass

19. **Tönung nicht adaptiv:** `tint` wird als fester ARGB-Wert übergeben (`LiquidGlassViewFactory.swift` Z. 126-135, `liquid_glass_container.dart` Z. 67) und wechselt nicht mit Hell/Dunkel.
20. **`interactive` standardmäßig an** (Z. 150, 200) auch für nicht tippbare Flächen: Glas hellt unter dem Finger auf, ohne dass etwas passiert.
21. **Fallback-Glas (Android) mit Rand und Verlauf** (`liquid_glass_container.dart` Z. 86-113): ein selbstgebautes Milchglas, das nicht zum iOS-Glas passt; betrifft iOS nicht, aber jedes geteilte Layout.

### 3.5 App-Icon, Startbild, Berechtigungstexte

22. **Icon:** Detailreiche 3D-Figur auf Weiß. Bei 29 und 40 pt kaum erkennbar, im Dunkelmodus ein weißes Quadrat, getönt ein grauer Fleck. Kein Icon-Composer-Icon für iOS 26 Liquid Glass.
23. **Startbildschirm leer** (1-px-Bild): Der Übergang ins erste Flutter-Bild ist nicht gestaltet.
24. **Berechtigungstexte gemischt Deutsch/Englisch** und nicht lokalisiert (`Info.plist` Z. 6, 60, 62, 64, 66; keine `InfoPlist.strings`). Der Kameratext nennt "receipts", für Barcode und Essensfoto passt er nicht.

### 3.6 Paper-Reste

Im nativen Bereich gibt es keine: keine Serifen, kein Creme/Terrakotta, keine Kicker. Die Widgets nutzen SF Pro und Weiß/Fast-Schwarz. Problematisch ist eher, dass sie keinen eigenen Stil haben (siehe 3.1).

---

## 4. Bugs, Risiken und Performance

### 4.1 Widget-Datenfluss

1. **Abhaken im Widget geht verloren, wenn das Token abgelaufen ist.** Das Widget nutzt nur das zuletzt gespeicherte Access-Token (`ShoppingListWidget.swift` Z. 207-214), ohne Refresh-Token und ohne Warteschlange. Supabase-Tokens laufen nach etwa 1 h ab. Wurde die App länger nicht geöffnet, antwortet der PATCH mit 401. Fehler werden nur geloggt (Z. 244-249). Der lokale Cache zeigt "abgehakt", der Server nicht. Beim nächsten App-Start überschreibt `updateShoppingListWidget` den Cache und das Häkchen verschwindet. Gleiches gilt für Quick-Add (`QuickAddWidget.swift` Z. 80-89, 113-131).
2. **Netzwerk-Aufruf wird nicht abgewartet.** `toggleItemInDefaults` startet `Task { await syncToggleToSupabase }` (Z. 197-199), `perform()` kehrt sofort zurück (Z. 317-320). Das System darf die Extension danach beenden, und der PATCH erreicht den Server eventuell nie.
3. **Widget zeigt veraltete Daten.** Der Cache wird nur geschrieben, wenn die Liste in der App offen ist (`items_provider.dart` Z. 133-136). Änderungen anderer Mitglieder, Änderungen auf einem zweiten Gerät (gleicher Account auf zwei iPhones) und Listen, die auf diesem Gerät nie geöffnet wurden, erscheinen nicht. Die 30-Minuten-Zeitleiste liest nur den Cache (Z. 336-342). Pushes laden die Widgets nicht neu.
4. **Falsche Liste ohne Hinweis.** Fehlt der Cache der konfigurierten Liste, zeigt das Widget den Legacy-Schlüssel, also die zuletzt geöffnete andere Liste (Z. 104-113).
5. **Doppelte Artikel bei Quick-Add.** Keine Prüfung, ob der Artikel schon offen auf der Liste steht (Z. 100-111). Kein Kategorisieren über die KI: Kategorie kommt aus der Statistik oder fehlt.
6. **Menge Double/Int gemischt:** Quick-Add schreibt `quantity` als Double (Z. 103), Cache und Widget-Modell nutzen Int (`QuickAdd` Z. 148, `widget_service.dart` Z. 166, `items_provider.dart` Z. 146 `toInt()`). 0,5 kg wird im Widget zu 0 und dann ohne Menge gezeigt.
7. **Rezept-Widget klein: Zeilen-Links funktionieren nicht.** In `.systemSmall` ignoriert WidgetKit `Link`; die ganze Fläche ist ein Ziel, und ohne `widgetURL` öffnet sich nur die App (`SavedRecipesWidget.swift` Z. 87, 185-195).
8. **`updateAvailableLists` lädt nur das Listen-Widget neu** (`AppDelegate.swift` Z. 208-210), nicht Quick-Add. Umbenannte oder gelöschte Listen bleiben dort bis zur nächsten Zeitleiste.
9. **Kein Push an Mitglieder und kein `checked_by`** beim Abhaken im Widget (Z. 226-235). Das Verhalten weicht vom Abhaken in der App ab (Z. 267-276 in `item_repository.dart`), und "wer kauft gerade ein" (Plan 4) bekommt vom Widget keine Daten.
10. **Zugangsdaten im Klartext in App-Group-UserDefaults** (`AppDelegate.swift` Z. 221-234): Access-Token, Anon-Key, User-ID. Besser wäre ein gemeinsamer Keychain-Zugriff. Beim Abmelden werden sie gelöscht (Z. 162-181), das funktioniert.
11. **Zwei App Groups**, `group.com.dominik.shoply` wird nirgends benutzt (Entitlements). Das ist ein Signierungs- und Provisioning-Risiko ohne Nutzen.

### 4.2 Siri / App Intents

12. **Siri bestätigt, bevor etwas passiert ist.** "{Artikel} wurde zu {Liste} hinzugefügt" (`AppIntents.swift` Z. 151-154) kommt sofort. Das eigentliche Hinzufügen läuft danach asynchron in Flutter (`app.dart` Z. 110-129), Fehler werden nur geloggt. Kommt der Link, bevor der Handler gesetzt ist, wird er verworfen (`deep_link_service.dart` Z. 101-104).
13. **Jeder Intent öffnet die App** (`openAppWhenRun = true`, Z. 91, 190, 221, 263, 319, 360). Bei gesperrtem Gerät und über CarPlay oder AirPods ist "Füg Milch hinzu" ohne Entsperren nicht möglich. Plan 10 verlangt, dass es "auch bei gesperrtem Gerät soweit iOS das erlaubt" funktioniert.
14. **Freitext über Entities:** `ItemNameEntity` und `ListNameEntity` nutzen den Text als ID (Z. 28-84). Siri bietet feste Vorschläge an. Freie Artikel klappen nur über den Satz-Parameter. Gleich benannte Listen kollidieren, umbenannte Listen erzeugen neue.
15. **"Neue Liste erstellen" ist ein Emoji-Sentinel-String** (Z. 117-134). `requestValue` fragt erneut nach derselben Entity mit denselben Vorschlägen; einen neuen Namen kann man so kaum eingeben.
16. **`INIntentsSupported` = ["Intent"]** in `Info.plist` Z. 51-54: Rest aus dem alten SiriKit ohne Intents-Extension. Harmlos, aber verwirrend.

### 4.3 Mitteilungen

17. **Push-Flut beim Einkaufen.** Jedes Abhaken sendet einen Push an alle Mitglieder (`item_repository.dart` Z. 266-276). 20 Artikel ergeben 20 Mitteilungen, jede mit Ton und Badge.
18. **Kategorie-Schalter greifen bei Push nicht.** Die Schalter liegen nur lokal (`notification_preferences_service.dart` Z. 62-84) und werden nur im Vordergrund geprüft (`fcm_service.dart` Z. 158-164). Bei geschlossener App zeigt iOS jeden Push. Typen wie `item_toggled`, `item_deleted`, `list_member_joined`, `expense_split` und `shopping_complete` sind gar keiner Kategorie zugeordnet (`fcm_service.dart` Z. 170-191; `shopping_complete` schon, aber der Server filtert nicht).
19. **Wahrscheinlich doppelte Banner im Vordergrund:** AppDelegate gibt `[.banner, .sound, .badge]` zurück (Z. 271-277), und `_handleForegroundMessage` zeigt zusätzlich eine lokale Mitteilung (`fcm_service.dart` Z. 155-165). Auf Gerät prüfen.
20. **Tippen auf Mitteilung kommt eventuell nicht bei Flutter an.** `userNotificationCenter(_:didReceive:)` wird überschrieben, ohne `super` aufzurufen (`AppDelegate.swift` Z. 280-286). Die Plugins `flutter_local_notifications` und `firebase_messaging` bekommen den Tipp dann je nach Delegate-Reihenfolge nicht. Ebenso `willPresent` (Z. 271-277). Auf Gerät prüfen.
21. **Ziel-Routing lückenhaft** (`navigation_service.dart` Z. 67-96): `list_member_joined` sendet `list_id`, der Router liest `listId` → kein Ziel. `avo_dinner_ideas`, `expense_split` und der Kochtimer führen nirgendwohin.
22. **Nur das letzte Gerät bekommt Push.** Das Token liegt in einer einzigen Spalte `users.fcm_token` (`fcm_service.dart` Z. 120-143, `push_notification_service.dart` Z. 26-29). CLAUDE.md nennt eine Tabelle `user_devices`, der Code nutzt sie nicht. Beim selben Account auf zwei iPhones verliert eines die Pushes.
23. **Badge immer 1**, wird nicht hochgezählt und nur beim Öffnen einer Liste gelöscht (`index.ts` Z. 106; `list_detail_screen.dart` Z. 199-200). `flutter_app_badger` wird nicht mehr gepflegt.
24. **Erlaubnis dreifach und sofort beim Start** (`AppDelegate.swift` Z. 50, `fcm_service.dart` Z. 41, `notification_service.dart` Z. 51-55), noch vor dem Onboarding. Das widerspricht der Verbesserungsliste ("Mitteilungen nur mit klarem Nutzen erfragen") und senkt die Zustimmungsrate.
25. **Avo-Erinnerung nennt Angebote auch bei abgeschaltetem Modul?** `rearmRestockReminder` holt Angebote über `AvoNudgeService.getOfferNudges()` (`mascot_notification_service.dart` Z. 120-131), ohne hier den Modul- oder Kill-Switch zu prüfen. Ob `AvoNudgeService` das intern tut, gehört zum Bereich Angebote und ist dort zu prüfen.
26. **Token im Log:** FCM-Token und APNs-Gerätetoken werden ausgegeben (`AppDelegate.swift` Z. 266, 293).

### 4.4 Liquid Glass und Leistung

27. **Glasformen folgen Größenänderungen nicht.** `LiquidGlassGroupView` legt die Formen nur im `init` an (`LiquidGlassViewFactory.swift` Z. 221-236, `layoutShapes` nur dort). Flutter übergibt `creationParams` nur einmal beim Erzeugen (`liquid_glass_container.dart` Z. 225-234, kein `key`, kein Kanal; `messenger` ungenutzt). Wächst die Eingabekapsel (`add_item_composer.dart` Z. 207-235, `_height` nach dem Frame gemessen) durch Mehrzeiligkeit, große Schrift oder Drehen, bleibt das Glas in der alten Größe. Das ist ein möglicher Mitverursacher des bekannten Fehlers "Text in der Eingabeleiste halb abgeschnitten" (Verbesserungsliste Z. 48-52). Der Rest liegt im Bereich Listen.
28. **Kapsel vor iOS 26 wird eckig.** Im Fallback wird der Radius aus `view.bounds` beim Erzeugen berechnet (Z. 118-122). Platformviews entstehen meist mit Rahmen 0, also Radius 0. Das betrifft iOS 15.6-18 (App-Deployment-Target 15.6).
29. **Kosten von Platformviews:** Jede `UiKitView` erzwingt Hybrid Composition mit zusätzlichen Ebenen. Glas über scrollendem Flutter-Inhalt kann auf dem iPhone 13 Pro ruckeln. Das Konzept sollte Glas auf wenige feste Elemente begrenzen (Tab-Bar, Eingabe, schwebender Button).
30. **Ausrichtung:** Das iPhone erlaubt Querformat (`Info.plist` Z. 98-103). Glasformen und Widgets-Daten sind darauf nicht ausgelegt, siehe Punkt 27.

### 4.5 Sonstiges

31. **Ungenutzte Tracking-Erlaubnis:** `NSUserTrackingUsageDescription` ohne ATT-Aufruf, während `PrivacyInfo.xcprivacy` "kein Tracking" meldet. Das ist ein Risiko in der App-Prüfung.
32. **Fehlende Berechtigungen für geplante Funktionen:** Mikrofon (`NSMicrophoneUsageDescription`), Spracherkennung (`NSSpeechRecognitionUsageDescription`), HealthKit (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` und Entitlement `com.apple.developer.healthkit`), Kamera-Text für Barcode/Essensfoto.

---

## 5. Abhängigkeiten zu anderen Bereichen

- **Listen (lists-core / lists-more):** `ItemsNotifier._commit` → `_updateWidget` (`items_provider.dart` Z. 126-155) speist das Listen-Widget. `ListsNotifier` speist verfügbare Listen und Quick-Add-Vorschläge (`lists_provider.dart` Z. 83-118, `TrackingService.getFrequentItems`). Abhaken im Widget schreibt direkt `shopping_items.is_checked/checked_at`, an Repository und Realtime vorbei. `add_item_composer.dart` hängt an `LiquidGlassGroup`. `item_repository.dart` und `shopping_trip_completion.dart` senden Pushes. `list_detail_screen.dart` löscht das Badge.
- **Rezepte:** `saved_recipes_provider.dart` speist das Rezept-Widget. `recipe_service.dart` sendet Bewertungs-Pushes. `cooking_mode_screen.dart` plant den Timer und nutzt `wakelock_plus`. Deep Links `shoply://recipe/<id>`, `recipes/saved`, `recipes/search?q=` landen in `RecipesScreen`.
- **Avo:** `mascot_notification_service.dart` nutzt `AvoNudgeService` (Nachkaufen, Angebote) und `CalorieRecipeNudgeService`. Der Avo-Chat kann den Mitteilungs-Hauptschalter setzen (`AvoSettingsBridge` → `applyMasterChangedRemotely`). Siri und der Avo-Sprachmodus müssen zusammen entworfen werden (gleiche Intents, ein Einstieg).
- **Kalorien:** Abendessen-Erinnerung (`FoodLogService`, Kalorienrest). Künftige Widgets für Kalorien/Wasser und Health-Anbindung brauchen neue Berechtigungen und neue App-Group-Schlüssel.
- **Angebote:** Restock-Text mit Markt und Preis (`restock_notification_body_offer`). Der Standorttext in `Info.plist` nennt Angebote. Ein Angebots-Widget hängt an Modul, Kill-Switch und Lizenz.
- **Kosten teilen:** `expense_split_service.dart` sendet Pushes.
- **Profil / Einstellungen:** Mitteilungs-Einstellungen (Schlüssel `notif_*` in SharedPreferences, `users.notification_enabled`). Künftig Modul-Schalter, die Widgets und Intents ein- und ausblenden müssen.
- **Shell / Navigation:** `app_router.dart` (`/list/:listId` → `/lists/:listId`, Z. 357; `shoply://`-Umwandlung im globalen `redirect`), `deep_link_service.dart`, `navigation_service.dart`, `app.dart` (Siri-Handler). Tab-Bar-Glas kommt aus `adaptive_platform_ui`.
- **Auth / Onboarding:** `main.dart` Z. 121-180 (Zugangsdaten ins Widget bei jedem Token-Refresh, Widget-Daten und Erinnerungen beim Abmelden löschen, FCM-Token beim Anmelden). Der Zeitpunkt der Mitteilungs-Erlaubnis muss ins neue Onboarding wandern.
- **Backend:** Edge Function `send-push-notification` (Payload, Badge, Berechtigung `canNotify`), Spalte `users.fcm_token`, Tabelle `item_purchase_stats`, RLS auf `shopping_items` (direkte REST-Aufrufe aus dem Widget).
- **Strings:** Widget- und Intent-Texte stehen in Swift, nicht in `app_translations.dart`. Push-Texte stehen teils in `app_translations.dart`, teils fest im Dart-Code. Der Name (Avo/Shoply) kommt in Siri-Sätzen über `.applicationName`, sonst fest im Code.
- **Geteilte Swift-Dateien:** `kAppGroupId`, `loadAvailableLists`, `SelectListIntent`, `ShoppingListEntity` sind in `ShoppingListWidget.swift` definiert und werden von `QuickAddWidget.swift` mitbenutzt. `AppIntents.swift` (Runner-Target) liest dieselben App-Group-Schlüssel über eigene Konstanten (`kShoplyAppGroupId`, Z. 13-24). Zwei Targets kennen also dieselben Schlüssel doppelt.

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**
- Abhaken direkt im Widget (interaktiver `Button(intent:)`, iOS 17+), auch ohne App-Start (Plan 11).
- Liste pro Widget wählbar (`SelectListIntent`), Widgets in klein, mittel und groß.
- Quick-Add aus häufig gekauften Artikeln mit einem Tipp, mit Kategorie-ID für richtige Einsortierung.
- Gespeicherte Rezepte als Widget mit Sprung ins Rezept.
- Siri-Sätze für Artikel hinzufügen, Liste erstellen, Listen zeigen, Rezepte suchen, gespeicherte Rezepte, Rezepte. Phrasen auf Deutsch und Englisch. Listen-Vorschläge aus den echten Listen.
- Deep Links: `shoply://list/<id>`, `recipe/<id>`, `add-item`, `create-list`, `lists`, `recipes`, `recipes/saved`, `recipes/search?q=`, `author/<id>`, `invite/<id>`, Universal Links `shoplyai.app`. Die Duplikat-Sperre (2 s) gehört dazu.
- Native Liquid-Glass-Bausteine (einzelne Fläche und verschmelzende Gruppe) mit Fallback vor iOS 26 und fester Fläche bei erhöhtem Kontrast.
- Mitteilungen: Hauptschalter (Account-weit, auch über Avo setzbar), Kategorie-Schalter, Avo-Nachkauf-Erinnerung um 9 Uhr, die bei jedem Öffnen neu geplant wird und nur feuert, wenn die App einen Tag nicht offen war. Dazu Abendessen-Idee, Kochtimer, Push an Listenmitglieder (hinzugefügt, Einkauf erledigt, neues Mitglied), Bewertung, Kosten teilen.
- Tipp auf Mitteilung führt zum passenden Ort (Liste, Liste/Aktivitäten, Rezept).

**Daten und Schlüssel**
- App Group `group.com.shoply.app` und die Schlüssel `widget_list_<id>`, `widget_available_lists`, `widget_recent_items`, `widget_saved_recipes`, `widget_supabase_url/anon/token/user_id`. Beim Umbau migrieren oder sauber ablösen, nicht stillschweigend ändern.
- MethodChannel `com.shoply.widget` mit den Methoden `updateShoppingListWidget`, `updateSavedRecipesWidget`, `clearWidget`, `refreshAllWidgets`, `updateAvailableLists`, `updateSupabaseCredentials`, `updateRecentItems`.
- Widget-Kinds `ShoppingListWidget`, `QuickAddWidget`, `SavedRecipesWidget`. Bei Umbenennung verschwinden bereits platzierte Widgets vom Home-Screen der Nutzer.
- Bundle-ID `com.dominik.shoply`, Widget-ID `com.dominik.shoply.ShoppingListWidget`, URL-Scheme `shoply` (dazu das Google-Sign-in-Scheme), Associated Domains, Sign in with Apple, Push-Entitlement.
- Push-Payload-Typen und Schlüssel (`type`, `listId`, `recipeId`, ältere `recipe_id`), weil ältere App-Versionen noch im Umlauf sind.

**Sonderfälle**
- Abmelden löscht alle `widget_*`-Schlüssel und lädt alle Widgets neu (`AppDelegate.swift` Z. 162-181, `main.dart` Z. 169). Kein Datenrest des alten Accounts.
- Zugangsdaten bei jedem Token-Refresh neu an das Widget (`main.dart` Z. 131-135).
- Hauptschalter aus entfernt das FCM-Token, damit auch Push bei geschlossener App aufhört. Beim Anmelden wird erst der Schalter synchronisiert, dann das Token gespeichert.
- Siri "Artikel zu Liste X": vorhandene Liste ohne Groß-/Kleinschreibung finden, sonst anlegen. "Liste erstellen" legt keine Duplikate an.
- Avo-Erinnerungen re-armen gedrosselt (15 min) und nur mit echten Daten. Abendessen-Idee beachtet Ernährung und Allergien (fail-open, weil nur einengend).
- `UIViewControllerBasedStatusBarAppearance = true` (sonst falsche Statusleistenfarbe unter UIScene, Kommentar in `Info.plist` Z. 111-118).
- Plattformview-Registrierung über den Registrar statt `window.rootViewController` (UIScene, `AppDelegate.swift` Z. 21-39, 69-73).
- `CADisableMinimumFrameDurationOnPhone = true` (120 Hz auf ProMotion).
- Fail-open im Widget: Ein fehlgeschlagener Netzaufruf darf das Widget nie leer machen. Künftig aber mit sichtbarem Zustand und Wiederholung.

**Für das Konzept bereits entschieden (nicht entwerfen):** Live Activity und Dynamic Island (Plan 5). Angebots-Widget, Angebots-Mitteilungen und Angebots-Text in der Nachkauf-Erinnerung nur mit Modul an, Remote-Kill-Switch und Lizenz. Bei abgeschaltetem Modul verschwinden sie ohne Spur.
