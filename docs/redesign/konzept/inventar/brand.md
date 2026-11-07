# Inventar: Marke, Texte und Assets

Stand: 2026-11-07, Branch `main` (Commit `3e886d0`). Nur gelesen, kein Code geändert.
Zweck: Ist-Zustand von Name, Tonalität, Texten, Icon, Maskottchen und Web-Auftritt als Grundlage für das komplette Redesign.

Kurzfassung:
- Die App hat heute **drei Namen gleichzeitig**: "Avo" auf dem Home-Bildschirm, in Siri, auf der Landingpage `joinavo.app` und in der Pro-Erfolgsmeldung; "Shoply" im Willkommens-Screen, im Onboarding, in Mitteilungen, im Wissen des KI-Assistenten, in der Bundle-ID, im URL-Schema `shoply://` und in den Domains `shoplyai.app`/`shoply.app`; dazu drei Namen für das Abo ("AVO PREMIUM", "Avo Pro", "Shoply Premium", plus nacktes "Premium").
- Es gibt **drei Markenfarben**, die nichts miteinander zu tun haben: Terrakotta `#C0502A` in der App (Paper), Grün `#3E8E5A` auf der Landingpage, ein drittes Grün `rgb(0.3, 0.75, 0.4)` in den iOS-Widgets. Das App-Icon und das Maskottchen sind avocadogrün und gelb.
- Die Texte liegen sauber in einer Datei (1052 Schlüssel je Sprache, Deutsch und Englisch vollständig deckungsgleich), aber rund 150 Schlüssel sind tot, etwa 25 Schlüssel tragen Paper-Kicker, mehrere Texte bewerben Funktionen, die der Plan verworfen hat (Marktvergleich, "bei X günstiger"), und Tutorial, Widgets, Siri und einige Mitteilungen umgehen das System mit fest codiertem Deutsch oder Englisch.
- Das Maskottchen besteht aus vier 3D-gerenderten PNGs (ca. 450 x 550 px), von denen sich zwei kaum unterscheiden; das App-Icon ist dasselbe Rendering auf Weiß, ohne Dunkel- oder Tönungsvariante und ohne Liquid-Glass-Ebenen.
- Die Tonalität ist freundlich, per Du und knapp, kippt aber an vielen Stellen in Emoji-Werbesprache ("✅ … erfolgreich abgeschlossen!", "Stark! … 💪") und auf der Landingpage in unbelegte Superlative ("The #1 …", Bewertungszahlen).

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/core/localization/app_translations.dart` | Alle UI-Texte: eine Klasse `AppTranslations` mit `get(key, lang, params)` und zwei `const Map<String,String>` (`_en` Z. 17-1181, `_de` Z. 1183-2354). Je 1052 Schlüssel, keine Duplikate, beide Sprachen deckungsgleich (per Skript geprüft). Fallback: Deutsch fehlt → Englisch → roher Schlüssel | 2354 |
| `lib/core/localization/localization_helper.dart` | `context.tr(key, params:)`, liest `Localizations.localeOf(context)` | 11 |
| `lib/core/localization/app_localizations.dart` | `LocalizationsDelegate` (en, de), statisches `currentLanguageCode` für Code ohne Context, ein paar typisierte Getter (Altlast, laut Kommentar nicht mehr erweitern) | 81 |
| `lib/core/mascot/avo_mascot.dart` | `AvoMascot`-Widget (PNG je `AvoExpression`, optionale Sprechblase), Konstante `avoName = 'Avo'` | 129 |
| `assets/avo/avo_waving.png` | Maskottchen winkend (neutral, waving), 454 x 550 px, transparent | Bild |
| `assets/avo/avo_excited.png` | Maskottchen lächelnd, Arme unten (happy, excited), 449 x 555 px | Bild |
| `assets/avo/avo_thinking.png` | Maskottchen mit offenem Mund, staunend (confused, thinking), 435 x 574 px | Bild |
| `assets/avo/avo_celebrating.png` | Maskottchen mit Arm seitlich ausgestreckt (success, celebrating), 460 x 542 px. Dateirechte `-rw-------` (alle anderen 644) | Bild |
| `assets/legal/privacy_policy.html` | Gespeicherte Next.js-Seite "Privacy Policy" von shoplyai.app (Stand "November 2024"), wird in der App nirgends geladen | 1 (24 KB) |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | App-Icon in 15 PNG-Größen; 1024er ohne Alphakanal; `Contents.json` ohne `appearances` (keine Dunkel-/Tönungsvariante) | 15 Bilder |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/` | Launch-Bild: drei 1 x 1 px große PNGs (praktisch leer) | 3 Bilder |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Startbildschirm: `systemBackgroundColor` + leeres LaunchImage | 41 |
| `ios/Runner/Info.plist` | `CFBundleDisplayName`/`CFBundleName` = "Avo", URL-Schema `shoply`, Associated Domains, Berechtigungstexte (gemischt Deutsch/Englisch) | 120 |
| `ios/Runner/AppIntents.swift` | Siri/Kurzbefehle: Titel und Beschreibungen fest Deutsch, Phrasen mit `\(.applicationName)` (= "Avo"), Beschreibungen nennen "Shoply" | 445 |
| `ios/ShoppingListWidget/*.swift` | Widget-Namen und -Texte fest Deutsch, Akzent `Color(red: 0.3, green: 0.75, blue: 0.4)` | 1280 |
| `ios/ShoppingListWidget/Assets.xcassets/` | `AccentColor` und `WidgetBackground` leer (keine Farbe definiert), AppIcon-Set leer | - |
| `lib/core/constants/paper_colors.dart` | Paper-Palette (Creme, Tinte, Terrakotta, Salbei …) und `PaperTextStyles` (Georgia-Serif, Kicker 11 pt, Laufweite 2) | 66 |
| `lib/core/widgets/paper/paper_widgets.dart` | `PaperKicker` (Text in Großbuchstaben), Paper-Buttons, Unterstrich-Feld | 226 |
| `lib/core/constants/app_colors.dart` | App-Akzent `accent = 0xFFC0502A` (Terrakotta), Hell-Palette = Paper-Creme | 265 |
| `lib/core/constants/app_text_styles.dart` | Schrift "Satoshi", aber in `pubspec.yaml` ist kein `fonts:`-Abschnitt; fällt still auf die Systemschrift zurück | 80 |
| `lib/core/constants/legal_links.dart` | Datenschutz und Impressum auf `joinavo.app`, AGB, Anleitung und Support-Mail auf `shoplyai.app` | 11 |
| `lib/core/constants/app_config.dart` | Share-Domain `https://shoplyai.app` | 27 |
| `lib/data/services/avo_system_prompt.dart` | Persona des KI-Assistenten: "You are Avo, the friendly avocado mascot for the Shoply shopping list app", warm, knapp, gelegentlich Wortspiel | 122 |
| `lib/data/services/avo_app_knowledge.dart` | Faktenwissen, das Avo über die App ausgibt: `appName = 'Shoply'`, Preise in Dollar, Pro-Funktionsliste, Widget- und Siri-Anleitung mit "Shoply" | 106 |
| `lib/data/services/dynamic_tutorial_service.dart` | Texte der Avo-Einführungstour, fest Deutsch | 334 |
| `lib/presentation/widgets/tutorial/tutorial_overlay.dart` | Tour-Overlay mit Maskottchen, Titel "Willkommen"/"Geschafft" fest Deutsch | 724 |
| `lib/data/services/contextual_prompt_service.dart` | Kontext-Hinweise (Diät, Mitteilungen), fest Deutsch | 304 |
| `lib/data/models/list_activity.dart` | Aktivitätstexte geteilter Listen per `isGerman ? … : …` statt Übersetzungsdatei | 182 |
| `lib/presentation/screens/auth/welcome_screen.dart` | Erster Screen der Marke ("Willkommen bei Shoply") | 152 |
| `lib/presentation/screens/auth/name_prompt_screen.dart` | "Hey! Ich bin Avo 🥑" mit Maskottchen | 203 |
| `lib/presentation/screens/subscription/subscription_screen.dart` | Paywall ("AVO PREMIUM", Serif-Headline) | 511 |
| `lib/presentation/screens/lists/widgets/share_list_dialog.dart` | Teilen-Texte für Listen ("🛒 Name + shoplyai.app-Link", "Öffne Avo …") | 224 |
| `lib/data/services/recipe_service.dart` (Z. 420-449) | Push "New Rating!" (nur Englisch) und Rezept-Teilen-Text (nur Englisch, Emojis) | Ausschnitt |
| `pubspec.yaml` | `name: shoply`, `description: "… coupon finder …"`, Version `1.1.4+31`, Assets `assets/avo/`, `assets/legal/` mit falschem Kommentar (Z. 115) | - |
| `README.md` | Titel "Shoply / Avo", "Gemini für KI", Verweise auf CLAUDE.md und docs | 44 |
| `/Users/jannisdietrich/Apps/joinavo.app/src/lib/translations.ts` | Landingpage-Texte EN/DE ("Avo"), Next.js 16, Schriften Syne + Outfit, Akzent `#3E8E5A` | 813 |
| `/Users/jannisdietrich/Apps/joinavo.app/src/app/layout.tsx` | Meta-Titel "Avo - The Smartest Way to Shop for Groceries", "Free for iOS & Android" | 171 |
| `/Users/jannisdietrich/Apps/joinavo.app/src/app/{list,invite,author}/[id]/page.tsx` | Deep-Link-Brücken mit `shoply://`, App-Store-URL `apps.apple.com/app/shoply/id6743532834`, Play-Store-Link | je ca. 60 |

### Aufbau von `app_translations.dart`

Abschnittskommentare (Englisch, Deutsch identisch gespiegelt): Common, Lists, Items, Foto-Import, Categories, Recipes, Rezepte-Bereich, Rezept-Erstellung (4 Schritte), Validierung, Entwurf, Kochmodus, Rezeptkategorien, Sharing, Home, What's New, **"Paper auth & onboarding"** (Z. 238-515, mit Abstand der größte Block; enthält inzwischen auch Nachkauf, Angebote, Avo-Chips, Ausgaben teilen, Preisvergleich, Paywall), "Screens cleanup" (Z. 516-585), AI Recommendations, Recipe of the Week, Recipe Details, Loading States, **"UI Elements"** (Z. 614-910, alphabetischer Sammelblock), Recipe Categories, Filter-Chips, Shopping History, Avo AI Chat, Subscription, Notification Settings, Calorie tracking, "Previously missing keys", Form validation.

Messwerte (per Skript und grep):
- 973 Aufrufe von `context.tr(` im Code. Nur 3 `Text('…')` mit festem Literal (alle `'Error: $e'` in `display_name_screen.dart:65,223,242`).
- Rund 216 Schlüssel tauchen nicht als Literal im Code auf. Davon werden rund 60 dynamisch zusammengesetzt (`diet_$id`, `meal_${…}`, `activity_${…}`, `goal_type_${…}`, `gender_$g`, `priority_${…}`, `weekday_adverb_$n`, `add_food_photo_confidence_${…}`). **Rund 150 Schlüssel sind tot**, z. B. der komplette alte Pro-Block `premium_feature_*` (Kochmodus, KI-Essensplanung, "Keine Werbung", Prioritäts-Support), `go_pro`, `unlock_with_pro`, `premium_feature_locked`, `subscribe_now`, `save_percent`, alle `sort_*`, `follow`/`following`, `weekly_challenge`, `metric`/`imperial`.
- 24 Schlüssel enden auf `_kicker` (Paper-Überzeilen), 2 Schlüssel tragen "paper" im Namen (`log_in_paper`, `welcome_back_paper`).
- 78 Geviertstriche "—" in den Texten, 8 Emojis je Sprache (🥑 ✅ 💪 🛒).
- Kein Plural-System: Einzahl wird über Extraschlüssel (`ratings_count_one`) oder "(s)" gelöst; Zahlen- und Währungsformat ist im Text fest (`'{price} €'`, `'\$2.99'`).

### Tonalität heute (App)

- Anrede: durchgehend Du (0 Treffer für "Sie " im deutschen Block), "Bitte" 26-mal, meist in Fehlermeldungen.
- Grundton: freundlich, knapp, alltagsnah ("Fehlt was? Frag mich nach Rezepten.", "Noch unsicher? Überspringen …"). Gute, ehrliche Stellen: `offers_source_note` ("Nur Angebotspreise …"), `similar_product_note`, `data_sources_body`, `checkout_store_body`.
- Paper-Ton im Onboarding: zweizeilige Serif-Headlines mit hartem Zeilenumbruch `\n` ("Einkaufen,\nschön sortiert.", "Mehr aus\njedem Einkauf.", "Dein Tag,\nin Kalorien.") plus Großbuchstaben-Kicker.
- Ausreißer in Werbesprache: "✅ {count} Artikel erfolgreich abgeschlossen!", "Stark! Du hast diese Woche … 💪", "Neuer Code gesendet!", "Willkommen bei Avo Pro!".
- Begriffe uneinheitlich: "Artikel" (43) neben "Produkte" (12) für dasselbe Ding; "Benachrichtigungen" (9) neben "Mitteilungen" (2, Apple-Begriff); "Laden" und "Markt" gemischt; "Premium" und "Pro" gemischt; "KI" mal als Verkaufsargument ("KI sortiert"), mal unsichtbar.
- Avo spricht in der ersten Person ("Hey! Ich bin Avo 🥑", Tour "Ich bin Avo, dein Einkaufshelfer!") und wird gleichzeitig in der dritten Person als Funktion beschrieben ("Avo liest deine Liste…", "Avo tauscht Zutaten").

### Tonalität heute (Landingpage joinavo.app)

- Englisch werblich, SEO-getrieben: "The #1 AI-powered grocery shopping list app", "Download the Best Grocery Shopping App", "Never miss a deal again".
- Erfundene oder widersprüchliche Zahlen: Statistik "95% categorization accuracy", "15 families using Avo", "5.0/5.0", gleichzeitig "#1". Im JSON-LD der gespeicherten Datenschutzseite (`assets/legal/privacy_policy.html`) steht `aggregateRating 4.8 / 50000`.
- Verspricht Dinge, die nicht existieren oder verworfen sind: "Free for iOS & Android" und Google-Play-Button (Android-IAP fehlt), "Price comparison", "Angebote & Preisverfolgung" als Premium-Feature, "optimized store routes", "Family profile support".
- Gestaltung: Creme-Hintergrund `#FAFAF7` und Creme-Skala, Grün-Akzent, Syne/Outfit, Custom Cursor, Parallax, Three.js. Hat mit der App optisch nichts gemein.

---

## 2. Screens, Sheets und Dialoge (Markenflächen)

Hier nur die Flächen, auf denen die Marke selbst auftritt. Die funktionalen Inhalte dieser Screens beschreiben die Inventare `shell.md`, `home.md`, `avo.md` usw.

### 2.1 App-Icon (Home-Bildschirm, App Store, Einstellungen, Spotlight)
- Datei: `ios/Runner/Assets.xcassets/AppIcon.appiconset/1024pt_1x_1024px.png` + 14 kleinere Größen.
- Hauptfrage: Welche App ist das?
- Aufbau: Weißer Grund, mittig das winkende 3D-Avocado-Maskottchen mit Beinen und Armen, ca. 70 % der Fläche, viel Weißraum.
- Zustände: nur eine Variante. Kein Dunkel-, kein getöntes, kein Liquid-Glass-Ebenen-Icon (iOS 18/26). Auf dunklem Home-Bildschirm bleibt ein weißes Quadrat.
- Texte: Name unter dem Icon "Avo".

### 2.2 Startbildschirm (Launch Screen)
- Datei: `ios/Runner/Base.lproj/LaunchScreen.storyboard`, Bild `LaunchImage` (1 x 1 px).
- Hauptfrage: keine, soll nur den ersten Screen vorwegnehmen.
- Aufbau: leere Fläche in `systemBackgroundColor` (weiß/schwarz). Danach springt die App in Paper-Creme (`PaperColors.paper`) auf Welcome oder in Schwarz/Creme auf Home: sichtbarer Farbsprung beim Start.

### 2.3 Willkommen (`WelcomeScreen`)
- Datei: `lib/presentation/screens/auth/welcome_screen.dart`, Route `/welcome` (`app_router.dart:120`), Einstieg nach Onboarding ohne Sitzung.
- Hauptfrage: Wie fange ich an?
- Aufbau von oben: Salbei-Fläche 190 pt hoch mit Kreis und Material-Icon `Icons.eco_outlined` (kein Maskottchen, kein Icon der Marke), Kicker "WILLKOMMEN BEI SHOPLY" in Terrakotta, Serif-Headline "Einkaufen,\nschön sortiert." (Georgia 28), Fließtext in `PaperColors.muted`, unten "Mit Apple fortfahren" (nur iOS), "Mit Google fortfahren", "Konto erstellen", "Schon ein Konto? Anmelden".
- Komponenten: `PaperKicker`, `PaperOutlineButton`, `PaperPrimaryButton`, `GoogleLogo`, Material `AlertDialog` für Fehler.
- Zustände: Fehler als Dialog "Hinweis"; kein Lade-Zustand während Social-Login sichtbar.
- Datenquellen: `signInWithSocialProvider` (`social_auth.dart`).
- Texte: `welcome_kicker`, `welcome_headline`, `welcome_sub` ("Geteilte Listen, Rezepte und ein Assistent, der mitdenkt — alles an einem ruhigen Ort.").

### 2.4 Namensfrage (`NamePromptScreen`)
- Datei: `lib/presentation/screens/auth/name_prompt_screen.dart`, Route `/name-prompt?new=1` (`app_router.dart:145`), nach neuem Konto.
- Hauptfrage: Wie soll Avo mich nennen?
- Aufbau: Spacer, Maskottchen winkend 120 pt, graue Sprechblase "Hey! Ich bin Avo 🥑\nWie darf ich dich nennen?", Textfeld 20 pt, Button "Weiter", Link "Überspringen".
- Zustände: Laden im Button, Fehler als SnackBar `generic_error`.
- Aktionen: Speichern → `/home`, Überspringen → `/home`.
- Besonderheit: einziges Auth-Screen mit eigener Dunkel-Variante (`0xFF1C1C1E`), sonst Paper-Creme.

### 2.5 Einführungstour (`TutorialOverlay`)
- Dateien: `lib/presentation/widgets/tutorial/tutorial_overlay.dart`, Texte in `lib/data/services/dynamic_tutorial_service.dart:140-217`. Liegt global über der App (`app.dart:228`), Neustart über Einstellungen ("Tutorial neu starten").
- Hauptfrage: Wie funktioniert die App?
- Aufbau: Willkommens- und Abschlusskarte mit Maskottchen 140/120 pt, Titel "Willkommen"/"Geschafft", Text, Button "Weiter", beim Abschluss Zweitbutton "Ernährungspräferenzen angeben"; Zwischenschritte mit 64-pt-Maskottchen neben einer Karte und dem Hinweis "Tippe auf das markierte Element".
- Zustände: Schritte abhängig von `_hasLists`, `_listHasItems`, `_hasRecipes`.
- Texte: komplett fest Deutsch, auch für englische Nutzer.

### 2.6 Paywall (`SubscriptionScreen`)
- Datei: `lib/presentation/screens/subscription/subscription_screen.dart`, Einstieg aus Profil (`profile_screen.dart:28`) und Rezeptdetail (`recipe_detail_screen.dart:38`), als Vollbild.
- Hauptfrage: Lohnt sich Pro für mich?
- Aufbau: Schließen-X und "Käufe wiederherstellen" oben, Kicker "AVO PREMIUM" (11 pt, Laufweite 2, Akzentfarbe, Z. 120-127), Serif-Headline "Mehr aus\njedem Einkauf." (Z. 131-132), vier Häkchenzeilen (`premium_feat_lists`, `_avo`, `_deals`, `_stats`), zwei Preiskarten Jährlich (Badge "BESTE WAHL" in 9 pt Großbuchstaben, Z. 240 und 489) / Monatlich, Button "14 Tage gratis testen" (54 pt hoch), Fußnote "Danach {price}/Jahr · Kündigung in den iPhone-Einstellungen", Abo-Hinweis 11 pt.
- Zustände: Laden ("Lade Abo-Optionen..." + Erneut versuchen), Wiederherstellen-Erfolg/-Leer als SnackBar.
- Datenquellen: `subscriptionNotifierProvider`, Preise aus StoreKit (`yearly.price`, `monthly.price`).
- Fehlend: keine Links zu Nutzungsbedingungen (EULA) und Datenschutz auf der Paywall (`LegalLinks` wird in der Datei nicht verwendet).

### 2.7 Pro-Kennzeichnung und kontextuelle Hinweise
- `profile_screen.dart:400` Label "Premium", `:708` "Willkommen bei Avo Pro!", `:758` fester Text "14 Tage kostenlos, dann 2,99 €/Monat" (`premium_trial_line`, nicht aus StoreKit, auf Englisch "\$2.99").
- `avo_chat_widgets.dart:387` Label "Premium" im Avo-Chat.
- Avo-Antworten zu Pro kommen aus `avo_app_knowledge.dart:28-31` ("Shoply Premium unlocks: unlimited shared lists, advanced AI categorization, unlimited AI chat, full recipe collection, nutrition info, custom themes, priority sync") und weichen von der Paywall ab.

### 2.8 Widgets in der Widget-Galerie
- Dateien: `ios/ShoppingListWidget/QuickAddWidget.swift:317-318`, `SavedRecipesWidget.swift:193-194`, `ShoppingListWidget.swift`.
- Texte nur Deutsch: "Schnell hinzufügen", "Gespeicherte Rezepte", "Noch keine gespeicherten\nRezepte", "+N mehr", "N min".
- Marke: eigener Grünton `Color(red: 0.3, green: 0.75, blue: 0.4)`, Hintergrund fest `Color(white: 0.11)`/weiß, `AccentColor`/`WidgetBackground` im Asset-Katalog leer.

### 2.9 Siri und Kurzbefehle
- Datei: `ios/Runner/AppIntents.swift`.
- Phrasen nutzen `\(.applicationName)` und heißen damit "Füge Milch zu Avo hinzu" (Z. 376-417), Titel fest Deutsch, `IntentDescription`s nennen "Shoply" (Z. 90, 189, 220, 262, 318, 359).
- Avo selbst erklärt Nutzern dagegen "Hey Siri, add milk to my Shoply list" (`avo_app_knowledge.dart:56-57`), was nicht funktioniert.

### 2.10 Systemtexte: Berechtigungen, Mitteilungen, Teilen
- Berechtigungen (`Info.plist`): Standort Deutsch und mit "Avo" (Z. 6), Kamera, Fotos, Fotos sichern, Tracking Englisch und generisch "This app needs …" (Z. 60-66). Keine `InfoPlist.strings`-Lokalisierung. Kein Text für Mikrofon, Spracherkennung oder Health (für den geplanten Sprachmodus und Apple Health nötig).
- Lokale/Push-Mitteilungen: "🥑 Zeit nachzukaufen?", "🥑 Idee fürs Abendessen?", "🥑 Meilenstein: Das war dein {count}. Einkauf mit Shoply!", "Einkauf abgeschlossen!", Push "New Rating!" nur Englisch mit Sternen-Emojis (`recipe_service.dart:427-428`).
- Teilen: Liste per Link "🛒 {Name}\n\nhttps://shoplyai.app/list/{id}" (`share_list_dialog.dart:52`, fest), per Code "Tritt mit diesem Code bei … Öffne Avo und tippe auf „Liste beitreten“." (`share_list_join_code`), Betreff "Meine Avo-Einkaufsliste". Rezept: "🍳 Check out this recipe … ⏱ … ⭐ …" nur Englisch (`recipe_service.dart:441-447`).
- Zahlungserinnerung für geteilte Kosten: "Hi {name}! Kleine Erinnerung: du schuldest mir noch {amount} € … Danke! 🛒".

### 2.11 Avo-Persona (KI-Assistent)
- Dateien: `avo_system_prompt.dart:7-10`, `avo_app_knowledge.dart`, `avo_tool_declarations.dart:10,195,558`.
- Persona: "friendly avocado mascot for the Shoply shopping list app", warm, 1-2 Sätze, gelegentlich ein Essens-Wortspiel. UI-Untertitel im Chat: "dein Einkaufs-Assistent".
- Wissen nennt Dollarpreise, "Shoply" als App-Namen, App-Store-Pfad "Subscriptions → Shoply".

### 2.12 Rechtliches und Hilfe
- `help_support_screen.dart:70-114` und `profile_screen.dart:253-259` öffnen Datenschutz/Impressum auf `joinavo.app`, AGB und Anleitung auf `shoplyai.app`, Support-Mail `support@shoplyai.app`.
- Die gebündelte `assets/legal/privacy_policy.html` ist eine fremde Kopie mit "© 2024 Shoply", Google-Analytics-Tag, Twitter-Handles `@shoplyapp`, Canonical `shoply.app` und erfundener Bewertung; sie wird nicht angezeigt.

---

## 3. Design-Probleme heute

### 3.1 Name und Markenarchitektur
- `app_translations.dart:239` / `:1407` `welcome_kicker` "Willkommen bei Shoply" auf dem allerersten Screen, während das Icon "Avo" heißt.
- `app_translations.dart:268, 278, 364, 367` (DE `1436, 1446, 1532, 1535`): "Shoply" in Onboarding-Prioritäten, Einstellungshinweis, Meilenstein-Mitteilung, Mitteilungs-Hauptschalter.
- `avo_app_knowledge.dart:8, 28, 38, 41, 53-57, 67, 75`: Avo nennt die App "Shoply", "Shoply Premium", sagt "Widget: search 'Shoply'" und "Hey Siri, add milk to my Shoply list". Beides findet der Nutzer unter diesem Namen nicht.
- `avo_system_prompt.dart:7`: Persona-Satz mit "Shoply".
- `AppIntents.swift:90, 189, 220, 262, 318, 359`: Kurzbefehl-Beschreibungen mit "Shoply", Phrasen mit "Avo".
- Abo-Name vierfach: "AVO PREMIUM" (`:517`), "Avo Pro" (`:990, 994`), "Premium" (`:522`, `profile_screen.dart:400`, `avo_chat_widgets.dart:387`), "Shoply Premium" (`avo_app_knowledge.dart:28`). Hinweis: `avo-verbesserungsliste.md` Z. 21 nennt noch "SHOPLY PREMIUM" auf der Paywall; der Code sagt inzwischen "AVO PREMIUM".
- Technische Kennungen mit "shoply": Bundle-ID `com.dominik.shoply`, App Group `group.com.shoply.app`, URL-Schema `shoply://` (`Info.plist:34`), Domains `shoplyai.app` (Associated Domains, Share-Links, AGB, Support) und `joinavo.app` (Datenschutz, Impressum, Landingpage). App-Store-URL-Slug `shoply`. User-Agents `Shoply-App/1.0` (`open_food_facts_service.dart:25`) und `Shoply (com.dominik.shoply)` (`open_prices_service.dart:40`).
- `pubspec.yaml:2` Beschreibung "… coupon finder …" passt zu keinem Namen und keinem Plan.

### 3.2 Farbe und Bildsprache
- Drei Grüntöne plus Terrakotta: App-Akzent `#C0502A` (`app_colors.dart:69`, `paper_colors.dart:16`), Widgets `rgb(77,191,102)` (`QuickAddWidget.swift:226`, `SavedRecipesWidget.swift:84`, `ShoppingListWidget.swift:369`), Landingpage `#3E8E5A` (`globals.css:13`), Maskottchen/Icon Avocadogrün + Gelb + Kernbraun. Das Markensymbol (die Avocado) und die Akzentfarbe der App widersprechen sich.
- Paper-Reste in Markenflächen: Creme-Grund `PaperColors.paper #F7F3EC` (`welcome_screen.dart:42`, `name_prompt_screen.dart:77`), Terrakotta-Kicker (`welcome_screen.dart:79-82`, `subscription_screen.dart:120-127`), Georgia-Serif-Headlines (`welcome_screen.dart:86`, `subscription_screen.dart:132, 455`), 59 Aufrufe von `PaperTextStyles.serif` in 47 Dateien, 24 `_kicker`-Schlüssel in den Texten. Genau das, was die Anti-Slop-Regel verbietet (Kicker über Überschrift, Creme + Terrakotta).
- Zweizeilige Headlines mit festem `\n` (z. B. `:240, 252, 254, 258, 262, 266, 280, 309, 315, 321, 327, 503, 540`) brechen bei 320 pt Breite oder großer Schrift zusätzlich selbst um und ergeben dann drei bis vier unschöne Zeilen; in der Übersetzung sitzen sie an anderen Stellen ("Isst du\nbesonders?", `:1448`).
- Großbuchstaben per Code: `PaperKicker` macht `text.toUpperCase()` (`paper_widgets.dart:14`), Badge `best_choice` `.toUpperCase()` (`subscription_screen.dart:240`), "AVO PREMIUM" steht schon in Großbuchstaben in der Übersetzung (`:517`). VoiceOver liest Großbuchstaben teils buchstabiert.
- Welcome-Screen nutzt Material-Icon `Icons.eco_outlined` (`welcome_screen.dart:70-74`) und `Icons.apple` (`:102`) statt SF Symbols bzw. des offiziellen Sign-in-with-Apple-Buttons; die Marke (Avo) ist auf dem ersten Screen gar nicht zu sehen.
- Maskottchen-Stil (glänzendes 3D-Rendering mit Armen und Beinen) passt nicht zu SF-Symbol-Ikonografie; in 22-pt-Größe (`avo_nudge_card.dart:53`, `calorie_recipe_nudge_card.dart:45`) und 26 pt (`avo_chat_widgets.dart:347`) ist es nur noch ein grüner Fleck.
- App-Icon: Figur mit Gliedmaßen wirkt in 29/40/60 pt klein und unruhig; weißer Grund ohne Dunkel- und Tönungsvariante (`Contents.json` ohne `appearances`); kein Icon-Composer-Ebenenaufbau für Liquid Glass (iOS 26).
- Launch-Screen leer in Systemfarbe, danach Creme: sichtbarer Farbwechsel beim Start (`LaunchScreen.storyboard`, `LaunchImage` 1 x 1 px).

### 3.3 Feste Größen, Dynamic Type, 320 pt
- `avo_mascot.dart:84-85, 94-95`: `width: size, height: size` quadratisch, Bilder sind hochkant (ca. 0,82:1) → Figur steht mit Leerraum links/rechts, wirkt kleiner als die Box.
- `avo_mascot.dart:108-123`: Sprechblase `maxWidth: size * 2.5`, Schrift fest 14 pt, harte Farben `0xFF2C2C2E`/`0xFFE5E5E5`, Rahmen 1 pt.
- `welcome_screen.dart:56` Hero fest 190 pt hoch, `:45` 26 pt Seitenrand, `:129` Link 13 pt.
- `name_prompt_screen.dart:80-118`: `Column` mit `Spacer` ohne Scroll; Maskottchen 120 pt, Sprechblase 18 pt, Feld 20 pt. Bei Tastatur + großer Schrift + iPhone SE oder 320 pt Breite läuft der Inhalt über (kein `SingleChildScrollView`).
- `subscription_screen.dart:123, 160, 345` 11 pt, `:489` 9 pt Badge, `:316` Button fest 54 pt hoch, `:448` 12 pt, `:464` 11 pt. Zwei Preiskarten nebeneinander (`:248`) bei 320 pt Breite und AX-Schrift zu eng.
- `paper_colors.dart:52` Kicker 11 pt mit Laufweite 2 (Apple: kleine Schrift braucht mehr, nicht feste Laufweite; Laufweite gehört zur Größe).
- `tutorial_overlay.dart:320, 479, 490, 510, 545, 583, 605, 616`: feste 11-22 pt, `Color(0xFF1A1A1A)` und `Color.fromRGBO(255,255,255,0.4)` (blasse Hilfstexte, Kontrast unter 4,5:1).
- Widgets: alle Schriften `.font(.system(size: …))` fest (z. B. `QuickAddWidget.swift:233, 265, 268, 282`), kein `.title`/`.body`-Stil, kein Dynamic Type.
- `app_text_styles.dart:5-6` Schrift "Satoshi" ohne Einbindung: im Code wird eine Markenschrift vorgetäuscht, real läuft die Systemschrift ohne die SF-Pro-Laufweitenregeln.

### 3.4 Texte und Tonalität
- Verworfene Konzepte noch als Text und Screen-Inhalt: `chip_cheapest_store` "Welcher Laden ist für meine Liste am günstigsten?" (`:406`/`:1575`, genutzt in `avo_chat_screen.dart:50`), `home_price_highlight_title` "{Liste} ist bei {A} {x} € günstiger als bei {B}" (`:498`/`:1667`, genutzt in `price_comparison_nudge_card.dart:24`), `cheapest_basket`, `store_comparison`, `closer_option_*`, `comparable_note`, `estimated_list_total` (genutzt in `list_price_summary_bar.dart:68, 318, 471, 508, 529`), `save_at_store` "Spare {x} € bei {Markt}" (`item_offer_sheet.dart:58`), `cheapest_saves_up_to`, `recipe_offers_save` "gegenüber Normalpreisen" (`recipe_offers_card.dart:66`).
- "statt"-Preise ohne "laut Händler": `instead_of_price` "statt {price} €" (`:1581`, genutzt in `weekly_deals_screen.dart:463`, `offer_suggestions_bar.dart:419`, `recipe_offers_card.dart:215`).
- Angebote als Pro-Versprechen: `premium_feat_deals` "Angebote deiner Märkte" (`:506`/`:1675`, `subscription_screen.dart:183`) widerspricht dem Plan (Angebote nie Pro).
- Drei verschiedene Pro-Funktionslisten: Paywall (Listen, Avo plant, Angebote, Statistiken), toter Altblock `premium_feature_*` (Kochmodus, Essensplanung, keine Werbung, Support, `:974-983`), Avo-Wissen (`avo_app_knowledge.dart:28-31`, u. a. "custom themes", "priority sync").
- Feste Preise im Text statt StoreKit: `premium_trial_line` "\$2.99/month" / "2,99 €/Monat" (`:969`/`:2138`, `profile_screen.dart:758`), `avo_app_knowledge.dart:14-15` in Dollar.
- Englische Ordinalzahl falsch: `milestone_trip_message` "your {count}th shopping trip" (`:364`) ergibt "1th", "2th", "3th", "22th".
- Mischsprache: Englisch `onb_goal_skip_hint` "… from the Kalorien tab" (`:313`).
- Unbeholfenes Deutsch: `onb_diet_title` "Isst du\nbesonders?" (`:1448`), `trip_completed_items` "✅ {count} Artikel erfolgreich abgeschlossen!" (`:1924`).
- Begriffe uneinheitlich (Artikel/Produkte, Benachrichtigungen/Mitteilungen, Laden/Markt, Premium/Pro), siehe Abschnitt 1.
- Rohe Fehler sichtbar: `error_generic` "Fehler: {error}", `error_adding`, `error_deleting`, `goal_setup_save_error` (10 Aufrufstellen mit Exception-Text), dazu `display_name_screen.dart:65, 223, 242` `'Error: $e'` unübersetzt.
- Entwickler-Text im Produkt: `apple_sign_in_simulator` "Bitte auf einem echten Gerät testen." (`:530`/`:1699`).
- Platzhalter-Texte für Halbfertiges: `calories_v0_title`, `calories_v0_card_sub` "… zählt noch nichts" (`:321-324`, genutzt `calories_screen.dart:43, 84`), obwohl Kalorien laut Plan vollwertig werden.
- FAQ-Texte beschreiben alte Wege: `faq_delete_history_answer` "Einstellungen > Einkaufsverlauf > Alles löschen" (`:714`/`:1883`), `faq_share_list_answer` "sende den Code".
- Emoji in Systemtexten und Mitteilungen (🥑 am Titelanfang, ✅, 💪, 🛒, 🍳, ⭐): wirkt nicht nach Apple-App, bei VoiceOver laut vorgelesen.

### 3.5 Lokalisierung außerhalb der Übersetzungsdatei
- Tour fest Deutsch: `dynamic_tutorial_service.dart:141-217`, `tutorial_overlay.dart:354, 357, 359, 614`.
- Kontext-Hinweise fest Deutsch: `contextual_prompt_service.dart:148, 254`.
- Empfehlungsgründe fest Deutsch: `ml_recommendation_service.dart:78, 112` ("Oft auf dieser Liste", "Ergänzt deine Liste").
- Aktivitäten per `isGerman`-Ternär: `list_activity.dart:47-122` (13 Stellen).
- Push "New Rating!" und Rezept-Teilen nur Englisch: `recipe_service.dart:427-428, 443-447`.
- Liste-per-Link-Teilen fest: `share_list_dialog.dart:52`.
- Widgets und Siri-Titel nur Deutsch (Swift), Berechtigungstexte gemischt (`Info.plist:6` Deutsch, `:60-66` Englisch), keine `.strings`/`.xcstrings`.

---

## 4. Bugs, Risiken und Performance-Probleme

- **Falsche Anleitungen durch Avo:** `avo_app_knowledge.dart:53-57` lässt Nutzer im Widget-Katalog nach "Shoply" suchen und "Hey Siri, add milk to my Shoply list" sagen. Der Home-Name ist "Avo", Siri-Phrasen nutzen `.applicationName` → beides schlägt fehl. `:38` "Subscriptions → Shoply" stimmt nur, wenn der App-Store-Name so heißt (nicht geprüft).
- **App-Review-Risiko Paywall:** keine Links zu Nutzungsbedingungen (EULA) und Datenschutz in `subscription_screen.dart` (Guideline 3.1.2 verlangt beides bei Abos). `LegalLinks.terms` zeigt auf `shoplyai.app/terms`, Datenschutz auf `joinavo.app/privacy`: zwei Domains, unklar, ob beide erreichbar sind.
- **Irreführende Werbeaussagen:** Landingpage `translations.ts` "The #1 …", "95% categorization accuracy", "5.0/5.0", "Free for iOS & Android"; gebündelte `privacy_policy.html` mit `aggregateRating 4.8 / 50000`. Wettbewerbsrechtlich (UWG) und für App Review riskant, widerspricht der Anti-Slop-Regel "keine erfundenen Zahlen".
- **Verworfene Preisvergleiche noch live im Text:** siehe 3.4; rechtliches Risiko laut Recherche (Vergleich mit nur Angebotspreisen, "statt"-Preise ohne Herkunft).
- **Ordinal-Bug** `milestone_trip_message` EN (`:364`).
- **Rohe Ausnahmen in der UI** (`error_generic` usw., `display_name_screen.dart:65, 223, 242`): zeigt Postgrest-/Netzwerk-Interna.
- **Fallback auf Schlüssel:** `AppTranslations.get` gibt bei fehlendem Schlüssel den Schlüssel selbst zurück (`app_translations.dart:5`). Der Abschnitt "Previously missing keys (shown as raw keys)" (`:1163`) zeigt, dass das schon passiert ist. Es gibt keinen Test, der Code-Schlüssel gegen die Tabelle prüft.
- **Zwei Sprachquellen:** `context.tr` liest `Localizations.localeOf`, Code ohne Context liest `AppLocalizations.currentLanguageCode` (statisch, Standard 'en'). Wird ein Text vor dem ersten `load()` gebaut (z. B. Mitteilungen im Hintergrund), ist er Englisch.
- **Toter Ballast:** rund 150 tote Schlüssel; `assets/legal/privacy_policy.html` (24 KB) wird mitgeliefert, aber nie geladen; `pubspec.yaml:115` Kommentar "Only referenced by the unused ListsScreen" ist falsch (Maskottchen wird in 6 Dateien benutzt).
- **Maskottchen-Assets:** nur eine Auflösung (ca. 450 px), bei 140 pt auf 3x-Geräten (420 px) knapp, darüber unscharf; keine `cacheWidth`, d. h. auch die 22-pt-Variante dekodiert das volle Bild (rund 1 MB RAM pro Bild). `avo_celebrating.png` hat Dateirechte 600. `excited` zeigt keinen Jubel, `celebrating` sieht fast aus wie `waving`; der Kommentar "thumbs up" (`avo_mascot.dart:27`) stimmt nicht. `animate`-Parameter wird ignoriert (`avo_mascot.dart:54`).
- **Berechtigungstexte:** generisch "This app needs …" (App Review lehnt vage Zwecke ab), Tracking-Text vorhanden (`NSUserTrackingUsageDescription`) ohne erkennbaren Grund im Plan; für Sprachmodus, Spracherkennung und Apple Health fehlen die Schlüssel ganz.
- **Widget-Assets leer:** `AccentColor`/`WidgetBackground` ohne Farbwerte, Widget-`AppIcon.appiconset` leer.

---

## 5. Abhängigkeiten zu anderen Bereichen

- `app_translations.dart` ist die gemeinsame Datei aller Bereiche (973 Aufrufstellen). Beide Macs werden sie gleichzeitig ändern: Konfliktschwerpunkt. Abschnitte sind nicht nach Feature getrennt (Sammelblöcke "Paper auth & onboarding" und "UI Elements").
- `AvoMascot` wird genutzt von Home (`avo_nudge_card.dart`, `calorie_recipe_nudge_card.dart`), Avo-Chat (`avo_chat_screen.dart`, `avo_chat_message.dart`, `avo_chat_widgets.dart`), Auth (`name_prompt_screen.dart`), Tour (`tutorial_overlay.dart`) und als Enum in `avo_assistant_models.dart`/`avo_assistant_service.dart`.
- Paper-Bausteine (`paper_colors.dart`, `paper_widgets.dart`, `paper_settings.dart`) hängen in 47 Dateien (Auth, Onboarding, Listen, Home, Rezepte, Profil, Verlauf, Avo, Paywall). Siehe `shell.md`.
- `AppColors.accent` (Terrakotta) ist zugleich Paywall-Akzent, Rezept-Akzent und `info`-Farbe.
- Name/Kennungen: Bundle-ID, App Group (`group.com.shoply.app`, geteilt mit Widgets und App Intents), URL-Schema `shoply://` (Deep Links, Siri, Widgets, Landingpage-Brücken), Associated Domains `shoplyai.app`, Share-Links (`app_config.dart`, `deep_link_service.dart:13`, `recipe_service.dart:443`, `share_list_dialog.dart:52`), Firebase-Projekt `shoplyai-1554e`, Supabase. Ein Umbenennen der sichtbaren Marke darf diese Kennungen nicht brechen.
- Avo-KI: `avo_system_prompt.dart`, `avo_app_knowledge.dart`, `avo_tool_declarations.dart` enthalten Markenname, Preise und Pro-Umfang; müssen mit Paywall und Plan synchron sein (Plan: alle KI künftig über Claude, README sagt noch Gemini).
- Widgets und Siri (`ios/ShoppingListWidget/`, `AppIntents.swift`) haben eigene Texte und Farben außerhalb von Flutter.
- Landingpage `joinavo.app`: Datenschutz und Impressum der App liegen dort (`legal_links.dart`), Deep-Link-Brücken leiten auf `shoply://` und App-Store-ID `6743532834`.
- Inventare mit Überschneidung: `shell.md` (Designsystem, Farben, Schriften), `avo.md` (Chat, Persona), `home.md` (Nudges, Preis-Highlight), `lists-more.md` (Angebote, Teilen), `calories.md` (v0-Texte, Ziele).

---

## 6. Was ein Redesign unbedingt erhalten muss

- **Zweisprachigkeit Deutsch/Englisch** mit identischem Schlüsselsatz, Systemsprache als Standard, manuelle Umschaltung in den Einstellungen und durch Avo (`update_setting`). Parameter-Platzhalter (`{count}`, `{price}`, `{store}` …) und die dynamischen Schlüsselfamilien (`diet_*`, `meal_*`, `activity_*`, `goal_type_*`, `gender_*`, `priority_*`, `weekday_adverb_*`).
- **Sprachneutrale Kategorie-IDs** (z. B. `dairy`), damit geteilte Listen zwischen deutsch- und englischsprachigen Nutzern funktionieren.
- **Du-Anrede und der knappe, ehrliche Ton** der guten Stellen (Datenquellen, "Nur Angebotspreise", "kurz prüfen lohnt sich"), Quellenangaben für Open Prices (ODbL), OpenStreetMap und marktguru (`data_sources_body`).
- **Avo als Figur und Name des Assistenten** (Persona warm, kurz, Rückfrage vor Löschen) und die vier Ausdrucks-Zustände als Konzept (begrüßen, nachdenken, freuen, Erfolg), auch wenn die Bilder neu gezeichnet werden.
- **Alle technischen Kennungen unverändert:** Bundle-ID `com.dominik.shoply`, App Group `group.com.shoply.app`, URL-Schema `shoply://`, Associated Domains `shoplyai.app`, Firebase-Projekt, Supabase-Tabellen. Bestehende geteilte Links (`shoplyai.app/list/…`, `/recipe/…`, `/invite/…`, `/join/<code>`) müssen weiter öffnen.
- **Siri-Phrasen über `.applicationName`**, damit ein späterer Namenswechsel automatisch greift; alle Kurzbefehle (hinzufügen, Liste erstellen, Listen zeigen, Rezepte suchen, gespeicherte Rezepte, Rezepte öffnen).
- **Preise immer aus StoreKit** (Paywall tut das heute schon), 14-Tage-Test, Kündigungshinweis, "Käufe wiederherstellen".
- **Rechtliche Links** (Datenschutz, Impressum, AGB, Support-Mail) aus Profil/Hilfe, ergänzt um die Paywall.
- **Spar- und Angebotstexte** als abschaltbarer Bereich, mit "laut Händler" und Regionshinweis statt Vergleich; Kill-Switch muss alle zugehörigen Texte mit ausblenden können.
- **Sonderfälle in Texten:** Einzahl/Mehrzahl (Bewertungen, Artikel), Simulator-Fall für Sign in with Apple (intern halten, nicht dem Nutzer zeigen), Hinweise bei fehlender Standortfreigabe, Code-Teilen als Alternative zum Link.
