# Inventar: Navigation, Shell und heutiges Designsystem

Stand: 2026-11-07, Branch `main` (Commit `3e886d0`). Nur gelesen, kein Code geändert.
Zweck: Ist-Zustand als Grundlage für das komplette Redesign (Apple-Stil, iOS 26/27, Liquid Glass).

Kurzfassung in fünf Sätzen:
- Die Shell ist eine selbstgebaute, massive "Tinten-Pille" (Paper-Design "D1") mit 3 bis 4 Icon-Tabs ohne sichtbare Beschriftung und einem abgesetzten runden Avo-Knopf. Kein Liquid Glass, keine Federn, keine Beschriftungen, keine VoiceOver-Tab-Semantik.
- Auf iOS wird das Material-Theme `AppTheme` gar nicht angewendet: `AdaptiveApp` baut dort eine `CupertinoApp` und übernimmt nur die Primärfarbe. `app_theme.dart` ist auf dem iPhone praktisch toter Code; jede Fläche färbt sich selbst.
- Es gibt drei konkurrierende Designsysteme (Paper, `design_system.dart`, `AppColors/AppDimensions/AppTextStyles`) und drei Icon-Sets (Material, Cupertino, Lucide), dazu rund 220 hart codierte Farben und rund 590 feste Schriftgrößen.
- Hell und Dunkel sind zwei verschiedene Designsprachen: Hell = Paper (Creme, Tinte, Terrakotta, Georgia-Serifen, Großbuchstaben-Kicker), Dunkel = iOS-Schwarz/Grau, Rezepte im Dunkelmodus zusätzlich grünstichig. Standard ist "Hell", nicht "System".
- Die Tab-Navigation hat echte Bugs (Slide durch leere oder versteckte Seiten, Sprung bei Unterbrechung, uneinheitliche Sichtbarkeit der Tab-Leiste) und Avo hat heute zwei Einstiegspunkte statt einem.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/app.dart` | Root-Widget `AvoApp`: `AdaptiveApp.router`, Theme-Modus, Sprache, Statusleisten-Stil, Siri-Handler, Deep-Link-Init, Auth-Wechsel, globaler `ScaffoldMessenger` und `TutorialOverlay` | 233 |
| `lib/routes/app_router.dart` | GoRouter: alle Top-Level-Routen, `StatefulShellRoute` mit 4 Branches, Auth-/Onboarding-Redirect, Deep-Link-Umschreibung, gemerkter Listen-Link | 466 |
| `lib/presentation/screens/main_scaffold.dart` | Shell: `SlidingTabsContainer` (horizontaler Slide zwischen Tabs), `MainScaffold` (Tinten-Pille, Avo-Orb, Offline-Banner, Verlauf hinter der Leiste), statische Abstands-Helfer `getNavbarClearance` usw. | 518 |
| `lib/core/theme/app_theme.dart` | Material-3-`ThemeData` hell/dunkel (AppBar, Card, Input, Buttons, BottomNav, Dialog, BottomSheet, Seitenübergänge). Auf iOS nicht wirksam (siehe 4.1) | 408 |
| `lib/core/constants/app_colors.dart` | Farbpalette: Dunkel = iOS-Grautöne, Hell = Paper-Töne, Akzent Terrakotta, Rezept-Sonderpalette, Kontext-Helfer `AppColors.surface(context)` usw., Legacy-Aliase | 265 |
| `lib/core/constants/paper_colors.dart` | `PaperColors` (17 feste Farben, nicht adaptiv) und `PaperTextStyles` (Georgia-Serif, Kicker 11 pt mit Laufweite 2, Body) | 66 |
| `lib/core/constants/app_text_styles.dart` | 8 Textstile (h2, h3, h4, bodyLarge/Medium/Small, caption, label), Schrift "Satoshi" (nicht eingebunden) | 80 |
| `lib/core/constants/app_dimensions.dart` | Abstände, Radien (Karte 28, Button 24, Sheet 36, Modal 32), Buttonhöhe 48 | 37 |
| `lib/core/constants/categories.dart` | 10 Einkaufskategorien mit ID, DE/EN-Namen, Material-Farbe, Material-Icon, Schlagwortlisten; Diät-Ausschlusslisten; Einheiten | 235 |
| `lib/core/constants/recipe_categories.dart` | Rezeptkategorien mit Emoji-Icon und bunter Farbe | 127 |
| `lib/core/constants/list_background_gradients.dart` | 15 bunte Listen-Verläufe ("Northern Lights" usw.). Von keiner Datei importiert, toter Code | 218 |
| `lib/core/constants/app_priorities.dart` | 5 Onboarding-Prioritäten (sparen, teilen, gesünder, Rezepte, organisiert) mit Material-Icons | 23 |
| `lib/core/constants/diet_preferences.dart` | 12 Diät-IDs | 18 |
| `lib/core/constants/legal_links.dart` | Datenschutz, Impressum (joinavo.app), AGB, Anleitung, Support-Mail (shoplyai.app) | 11 |
| `lib/core/constants/app_config.dart` | Share-Link-Domain `shoplyai.app/join/<code>` | 27 |
| `lib/core/widgets/design_system.dart` | Zweites Designsystem: `AppRadius`, `AppCard`, `AppButton`, `AppOutlineButton`, `AppTextField`, `AppSectionHeader`, `AppListTile`, `showAppBottomSheet`, `AppChip`, `AppEmptyState` | 691 |
| `lib/core/widgets/paper/paper_widgets.dart` | Paper-Bausteine für Auth/Onboarding: `PaperKicker`, `PaperPrimaryButton`, `PaperOutlineButton`, `PaperUnderlineField`, `PaperOrDivider` | 226 |
| `lib/presentation/widgets/common/paper_settings.dart` | Paper-Bausteine für Einstellungs-Unterseiten: `PaperSettingsAppBar` (Serif-Titel), `PaperCircleIconButton`, `PaperSaveButton`, `PaperSectionHeader` (Kicker), `paperFieldDecoration` | 165 |
| `lib/presentation/widgets/common/liquid_glass_container.dart` | `LiquidGlassContainer` (natives `UIGlassEffect` per Platform View, Android-Fallback Blur), `AdaptiveGlass` (Fallback bei hohem Kontrast), `LiquidGlassGroup` (verschmelzende Glasformen) | 239 |
| `lib/presentation/widgets/common/liquid_glass_button.dart` | `LiquidGlassFilledButton`, `LiquidGlassOutlinedButton` (Flutter-`BackdropFilter`, kein echtes Glas) | 181 |
| `lib/presentation/widgets/common/confirm_dialog.dart` | `confirmDestructive()` über nativen `AdaptiveAlertDialog` mit SF Symbol `trash.fill` | 36 |
| `lib/presentation/widgets/common/empty_state.dart` | `EmptyState` (80-pt-Icon, Titel, Untertitel, Button) | 64 |
| `lib/presentation/widgets/common/loading_indicator.dart` | `LoadingIndicator` (Cupertino-Spinner plus Text) | 28 |
| `ios/Runner/LiquidGlassViewFactory.swift` | Native Platform Views `shoply/liquid_glass` und `shoply/liquid_glass_group` (`UIGlassEffect`, `UIGlassContainerEffect`, `cornerConfiguration`; vor iOS 26 `systemThinMaterial`) | 253 |
| `ios/Runner/AppDelegate.swift` (Z. 24-37) | Registriert beide Glas-Factories | - |
| `pubspec.yaml` | UI-relevant: `cupertino_icons`, `lucide_icons_flutter ^3.1.15`, `adaptive_platform_ui ^0.1.99` (gelockt 0.1.100), `go_router ^13` (gelockt 13.2.5), `wakelock_plus`, `cached_network_image`. Keine Schriften eingebunden. Assets: `assets/avo/` (4 Maskottchen-PNGs), `assets/legal/` | 117 |
| Mitbetroffen, außerhalb des engeren Umfangs | `lib/data/services/navigation_service.dart` (Notification-Routing, 109), `lib/data/services/deep_link_service.dart` (261), `lib/data/services/dynamic_tutorial_service.dart` (334), `lib/presentation/widgets/tutorial/tutorial_overlay.dart` (724), `lib/data/services/connectivity_service.dart` (65), `lib/presentation/state/theme_provider.dart` (142), `lib/presentation/state/calorie_tracking_provider.dart` (57), `lib/main.dart` (175) | - |

Nutzung über die App (grep über `lib/`, Stand heute):

| Muster | Treffer | Dateien |
|---|---|---|
| `PaperColors.` | 218 | 39 |
| `PaperTextStyles.serif` (Georgia) | 59 | 34 |
| `PaperKicker(` / `PaperSectionHeader(` | 10 / 19 | 9 / 9 |
| `PaperSettingsAppBar(` | 11 | 11 |
| `toUpperCase()` | 40 | 32 |
| `letterSpacing: 1.x/2` (Kicker-Laufweite) | 23 | 19 |
| `Color(0x...)` hart codiert | 220 | 40 |
| `fontSize:` fest | 593 | 98 |
| `Icons.` (Material) / `CupertinoIcons.` / `LucideIcons.` | ca. 365 / 39 / 5 | 89 / 10 / 1 |
| `HapticFeedback.` | 118 | 53 |
| `Duration(milliseconds` (feste Dauern) | 57 | 34 |
| Federn (`SpringDescription`/`SpringSimulation`) | 0 | 0 |
| `CircularProgressIndicator` (Material-Spinner) / `CupertinoActivityIndicator` | 18 / 42 | 12 / 30 |
| Skeleton/Shimmer | 0 | 0 |
| `SnackBar(` | 131 | - |
| `Semantics(` | 2 | - |
| `AppBar(` / `CupertinoSliverNavigationBar` (Large Title) | 33 / 0 | - |
| `MaterialPageRoute`/`CupertinoPageRoute` (Screens ohne Route) | 24 | 10 |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Tab-Shell (`MainScaffold`)
- Datei: `lib/presentation/screens/main_scaffold.dart:132-350`; eingebunden über `StatefulShellRoute` in `lib/routes/app_router.dart:153-287`.
- Route/Einstieg: alles unter `/home`, `/recipes/...`, `/calories`, `/profile`.
- Hauptfrage: "Welchen Bereich der App will ich gerade?"
- Aufbau von oben nach unten (ein `Stack`):
  1. Aktiver Branch-Navigator (`widget.navigationShell`), alle vier Branches bleiben gemountet (`SlidingTabsContainer`).
  2. Offline-Banner, schwebend oben (`top: safeTop + 8`, Z. 225-232).
  3. Weicher Verlauf von transparent zur Seitenfarbe hinter der Leiste (Höhe `navBottom + pillH + 24k`, Z. 237-260). Nur ohne Tastatur.
  4. Tab-Leiste unten (nur ohne Tastatur, Z. 262-345): eine Zeile aus Pille (flex) + 10k Abstand + Avo-Orb (58k).
- Komponenten:
  - Pille: massive Fläche `PaperColors.ink` (#201D18) hell bzw. `#16181D` dunkel, Kapselform, Schatten 22 % Tinte, Blur 18, y 8 (Z. 277-292).
  - Tabs `_NavIcon` (Z. 352-411): Lucide-Icons `list`, `book`, `flame` (nur bei Kalorien an), `user`. Sitz 46k x 58k, aktiver Sitz als 12-%-Creme-Kreis, inaktive Icons 42 % Deckkraft, Icon 21k. Keine sichtbaren Beschriftungen, nur `semanticLabel`.
  - Avo-Orb `_AvoOrb` (Z. 413-456): runder Knopf 58k, gleiche Farbe und Schatten wie die Pille, Icon `LucideIcons.messageCircle`, öffnet `/avo` per `push`.
  - Skalierung: alle Maße mal `k = min(Breite, 480) / 300` (Z. 142-147). Ergebnis Pillenhöhe: 320 pt -> 61,9; 375 pt -> 72,5; 393 pt -> 76; 402 pt -> 77,7; iPad (480) -> 92,8 pt.
- Zustände:
  - Kalorien-Modul aus: Tab fehlt; steht man gerade darauf, springt die Shell nach dem Frame auf Home (Z. 204-210).
  - Tastatur offen: Leiste und Verlauf verschwinden ohne Animation (Z. 193, 237, 262).
  - Offline: Banner gleitet von oben ein (Z. 458-517).
  - Leer/Laden/Fehler/Pro gesperrt: in der Shell nicht vorhanden; jeder Tab regelt das selbst.
- Aktionen und Gesten: Tippen auf Tab -> `goBranch` mit `HapticFeedback.lightImpact` (Z. 173-189); erneutes Tippen auf aktiven Tab -> `goBranch(initialLocation: true)` (zurück zur Wurzel, ohne Scroll-nach-oben). Tippen auf Orb -> `/avo` mit Haptik. Kein Wischen zwischen Tabs, kein Langdruck, kein Kontextmenü.
- Datenquellen: `isOfflineProvider` (`connectivity_service.dart:62`), `calorieTrackingEnabledProvider` (`calorie_tracking_provider.dart:16`), `DynamicTutorialService.instance` (Tab-Keys `homeTabKey`, `recipesTabKey` für das Tutorial; `onRouteChanged`).
- Sichtbare Texte: keine sichtbaren Labels. Semantik-Labels hart codiert Deutsch: "Listen", "Rezepte", "Kalorien", "Profil", "Avo"; Banner "Offline".

### 2.2 Tab-Wechsel-Container (`SlidingTabsContainer`)
- Datei: `main_scaffold.dart:26-120`; als `navigatorContainerBuilder` in `app_router.dart:156-160`.
- Hauptfrage: keine eigene (Übergang).
- Verhalten: alle Branch-Navigatoren liegen nebeneinander in einem `Stack`; Tab-Wechsel schiebt horizontal mit `AnimationController` 320 ms und `Curves.easeOutCubic` (Z. 51-55, 85). Während der Animation werden alle Branches zwischen Start und Ziel sichtbar geschaltet und gemalt (Z. 101-102). Nicht sichtbare Tabs: `Offstage`, `TickerMode` aus.
- Branch-Indizes fest: 0 Home, 1 Rezepte, 2 Kalorien, 3 Profil (Z. 17-20). Der Kalorien-Branch existiert immer, auch wenn sein Tab ausgeblendet ist.

### 2.3 Offline-Banner (`_OfflineBanner`)
- Datei: `main_scaffold.dart:458-517`.
- Hauptfrage: "Bin ich offline?"
- Aufbau: zentrierte Kapsel, Icon `Icons.cloud_off_rounded` 16 pt, Text "Offline" 13 pt w500. Hell: `PaperColors.surface` 98 % mit Haarlinie; dunkel: `#111827` 92 % (Tailwind-Grau, nicht iOS).
- Zustände: sichtbar/unsichtbar (Slide -1,6 plus Ausblenden, 320/220 ms). `IgnorePointer`, also nicht antippbar, kein Hinweis, was offline geht.
- Datenquelle: `isOfflineProvider` (fällt bei Laden/Fehler auf "online" zurück, kein Aufblitzen).

### 2.4 Router, Redirects und Routenkarte
- Datei: `lib/routes/app_router.dart`.
- Startort: `/home` mit Session, sonst `/onboarding` (Z. 107).
- Top-Level-Routen (ohne Tab-Leiste): `/onboarding`, `/welcome`, `/login`, `/signup`, `/reset-password`, `/name-prompt` (nur mit `?new=1`), `/avo` (CupertinoPage), `/lists/:listId` (CupertinoPage, `?name=`), `/lists/:listId/activities`, `/author/:authorId`, `/diet-preferences`, `/recipe/:recipeId` (öffentlich, Deep Link), `/list/:listId` und `/invite/:listId` (Aliase auf `/lists/:id`).
- Branch-Routen (mit Tab-Leiste): `/home`; `/recipes` (`?q=`), `/recipes/add` (extra `draftId`, `recipeId`), `/recipes/drafts`, `/recipes/saved`, `/recipes/my`, `/recipes/creators`, `/recipes/popular`, `/recipes/all`, `/recipes/category/:categoryId`, `/recipes/:recipeId` (extra `Recipe`); `/calories`; `/profile`.
- Ohne Route, per `Navigator.push` im jeweiligen Branch-Navigator (Tab-Leiste bleibt sichtbar, nicht verlinkbar): Profil-Unterseiten (`profile_screen.dart:139-332`: AppPriorities, DietPreferences, DisplayName, PersonalInfo, Language, Notifications, ThemeCustomization, HelpSupport, ShoppingHistory, Subscription), Home-Unterseiten (`home_screen.dart:509, 583`: WeeklyDeals, ShoppingHistory), Kalorien-Unterseiten (`calories_screen.dart:123-339`: GoalSetup, WeightTracking, WeeklySummary, WhatCanIEat, Challenges), Paywall (`subscription_screen.dart:505`), ListSettings und CategoryOrder (`list_detail_screen.dart:734, 755`). Nur CookingMode wird auf den Root-Navigator gelegt (`recipe_detail_screen.dart:994`).
- Redirect-Logik (Z. 367-455):
  - `shoply://<host>/<id>` mit host in recipe/list/invite/author -> `/<host>/<id>`, sonst `/home`.
  - Öffentlich: onboarding, welcome, login, signup, reset-password, `/recipe/...`.
  - Ausgeloggt und `/list/` oder `/invite/` -> Link merken, nach Login beim ersten Erreichen von `/home` fortsetzen (Z. 399-403, 440-445).
  - Onboarding nicht fertig und ausgeloggt -> `/onboarding` (Deep Links zu Rezepten und Auth-Unterseiten erlaubt).
  - Onboarding fertig, ausgeloggt, auf `/onboarding` -> `/welcome`.
  - Eingeloggt auf `/welcome` oder `/onboarding` -> `/home`. Login/Signup leiten selbst weiter (OTP-Race vermeiden).
  - Onboarding-Flag aus SharedPreferences, gemerkt sobald true (Z. 63-65, 405).
  - `GoRouterRefreshStream` reagiert nur auf initialSession, signedIn, signedOut, passwordRecovery (Z. 74-96).
- Fehlerseite: keine (`errorBuilder` fehlt).
- Analytics: `_LazyAnalyticsObserver` (Z. 43-61), nur iOS/Android.

### 2.5 App-Rahmen (`AvoApp`)
- Datei: `lib/app.dart`.
- Aufbau: `AdaptiveApp.router` (iOS -> `CupertinoApp.router`) mit `key: ValueKey('$themeMode-$languageCode')` (Z. 187-188), Titel "Avo", Lokalisierung DE/EN, `builder` setzt Statusleisten-Stil deklarativ und zusätzlich imperativ per `SystemChrome` (Z. 202-223) und legt `ScaffoldMessenger` + `TutorialOverlay` um alles (Z. 226-229).
- Aktionen ohne UI: Siri "Artikel zu Liste" und "Liste anlegen" (Z. 111-145; Liste per Namen gefunden, sonst neu angelegt, dann per `push` geöffnet); Passwort-Wiederherstellung -> `/reset-password`; bei Kontowechsel Provider invalidieren (Z. 77-86); bei App-Resume Avo-Erinnerungen neu planen.
- Datenquellen: `routerProvider`, `themeModeProvider`, `languageProvider`, `userListsProvider`, `listsNotifierProvider`, `itemsNotifierProvider`, `currentUserProvider`, Historien- und Abo-Provider, `DeepLinkService`, `NavigationService`, `MascotNotificationService`, `SubscriptionService`.

### 2.6 Tutorial-Overlay (global)
- Dateien: `lib/presentation/widgets/tutorial/tutorial_overlay.dart`, `lib/data/services/dynamic_tutorial_service.dart`.
- Einstieg: liegt in `app.dart:228` über jeder Seite; aktiv, wenn `users.tutorial_completed` false ist.
- Hauptfrage: "Wie benutze ich die App?"
- Aufbau: abgedunkelter Hintergrund (65 %, Willkommen 85 %) mit ausgestanztem Ziel, pulsierender Ring, Tap-Blocker, schwebende oder Vollbild-Karte (`rgba(28,28,30,0.92)`, weißer Button), Überspringen-Knopf, Fortschrittspunkte.
- Schritte: welcome, openShoppingList, showListItems, showInputField, navigateToRecipes (Ziel = Rezepte-Tab), showRecipes, showCreateRecipe, tutorialComplete.
- Texte: hart codiert Deutsch, z. B. "Los geht's", "Verstanden", "Weiter", "Loslegen", "Hier kannst du eigene Rezepte erstellen und teilen." (`dynamic_tutorial_service.dart:143, 166, 206, 218`).
- Abhängigkeit: GlobalKeys in Shell und Screens (`homeTabKey`, `recipesTabKey`, `firstListCardKey`, `addItemInputKey`, `addRecipeButtonKey` ...).

### 2.7 Deep Links und Notification-Routing
- `DeepLinkService` (`deep_link_service.dart`): Universal Links `https://shoplyai.app/{recipe|list|author|invite}/<id>`, Schema `shoply://`: `recipe/<id>`, `list/<id>`, `lists`, `recipes/saved`, `recipes/search?q=`, `author/<id>`, `addItem` (Google Assistant -> `/home`), Aktions-Links `add-item?name=&list=&quantity=` und `create-list?name=` (Siri/Shortcuts). Navigiert mit `go` (ersetzt den Stapel). Doppelte Zustellung innerhalb 2 s wird verworfen.
- `NavigationService` (`navigation_service.dart:67-97`): Push-Typen `list_activity`, `category_change` -> Aktivitäten; `list_update`, `list_invitation` -> Liste; `recipe_rating/like/comment` -> Rezept; `avo_restock` -> nur App öffnen; unbekannt -> Liste, falls `listId`. Navigiert mit `push`.

### 2.8 Destruktiv-Bestätigung (`confirmDestructive`)
- Datei: `lib/presentation/widgets/common/confirm_dialog.dart`. Genutzt in Home, Kategorie-Reihenfolge, Einkaufshistorie.
- Hauptfrage: "Wirklich löschen?"
- Aufbau: nativer iOS-26-Alert (`AdaptiveAlertDialog`), SF Symbol `trash.fill` rot, Abbrechen + destruktive Aktion. Gibt true nur bei Bestätigung zurück. Erfüllt bereits die Apple-Regel.

### 2.9 Bottom-Sheet-Helfer (`showAppBottomSheet`)
- Datei: `design_system.dart:497-539`, 3 Aufrufer.
- Aufbau: Material-`showModalBottomSheet`, eigener Griff 36 x 4, Fläche `AppColors.surface`, Radius 24 oben. Kein Glas, keine Teilhöhen-Detents, kein natives Sheet.

### 2.10 Leer- und Ladezustände
- `EmptyState` (`empty_state.dart`, nur in `list_detail_screen.dart`): 80-pt-Icon in Tertiärfarbe, Titel `AppTextStyles.h2` (28 pt), Untertitel, `ElevatedButton.icon` mit `Icons.add`.
- `AppEmptyState` (`design_system.dart:612-691`, 3 Dateien): Icon in 80-pt-Kreis, Titel 20 pt fett, Button fest 200 pt breit.
- `LoadingIndicator` (`loading_indicator.dart`, nur Listen-Detail): Cupertino-Spinner + Text.

### 2.11 Einstellungs-Rahmen (Paper)
- `PaperSettingsAppBar` (`paper_settings.dart:10-58`) ist der Kopf aller 11 Einstellungs- und Listen-Unterseiten: Material-`AppBar` fest 56 pt, runder Creme-Zurück-Knopf 34 x 34 mit `arrow_back_ios_new_rounded`, Titel Georgia 20 pt, optional `PaperSaveButton` (Terrakotta-Pille 13 pt). Abschnittsköpfe als 10-pt-Großbuchstaben-Kicker (`PaperSectionHeader`).

---

## 3. Design-Probleme heute

### 3.1 Abweichungen von den Apple-Regeln
- Tab-Leiste ist kein Liquid Glass, sondern eine opake Tinten-Fläche mit Schlagschatten: `main_scaffold.dart:277-292`, Orb `:431-444`. Inhalte scrollen nicht sichtbar darunter; statt Scroll-Edge-Effekt ein selbstgemalter Verlauf in Seitenfarbe (`:237-260`), der bei abweichenden Hintergründen (z. B. Rezepte dunkel `AppColors.recipeDarkBg` #0A120A) als Band sichtbar wird.
- Keine Tab-Beschriftungen, nur Icons mit 42 % Deckkraft für inaktiv (`:396-403`). Apple-Tab-Leisten zeigen Icon und Label; der aktive Zustand nur über Kreis und Deckkraft ist bei erhöhtem Kontrast schwach.
- Tab-Wechsel animiert den Inhalt seitlich (`:26-120`). Apple-Tab-Leisten wechseln Inhalte ohne Seiten-Slide. Feste Dauer 320 ms mit `easeOutCubic` statt Feder (`:53, :85`); Aktiv-Kreis 180 ms `easeOut` (`:384-385`).
- Haptik bei jedem Tab-Wechsel und jedem Zurück-Tippen (`main_scaffold.dart:178, :336`; `paper_settings.dart:39`). Apple-Regel: Haptik nur bei bedeutsamen Momenten. App-weit 118 Haptik-Aufrufe in 53 Dateien.
- Größe der Leiste skaliert mit der Bildschirmbreite, nicht mit Inhalt oder Dynamic Type (`:142-150`): 77,7 pt hoch auf 402 pt, 92,8 pt auf dem iPad; die native Tab-Leiste ist deutlich flacher. Icons wachsen mit der Breite, nicht mit der Textgröße; kein Large-Content-Viewer bei Bedienungshilfen-Größen.
- VoiceOver: Tabs und Orb sind nackte `GestureDetector` ohne `Semantics(button: true, selected: ...)` (`:375-377`, `:428-430`); VoiceOver sagt weder "Tab" noch "ausgewählt" noch "1 von 4". App-weit nur 2 `Semantics(`-Aufrufe.
- Avo hat zwei Einstiegspunkte: Orb (`main_scaffold.dart:332-339`) und der Hinweisstreifen auf Home (`home_screen.dart:280`). Plan fordert genau einen.
- Uneinheitliche Sichtbarkeit der Tab-Leiste: Liste öffnen blendet sie aus (Top-Level-Route, `app_router.dart:297`), Rezeptdetail und Rezept-Erstellung zeigen sie (Branch-Routen, `:176-256`), Kochmodus blendet sie aus (Root-Navigator), Einstellungs-Unterseiten zeigen sie (Branch-`Navigator.push`). Apple-Muster: Drilldowns behalten die Leiste, modale Vollbild-Flows (Erstellen, Kochmodus) nicht, konsistent.
- Navigation ohne Large Titles: 0 `CupertinoSliverNavigationBar`, 33 Material-`AppBar`. Zurück-Knopf als Creme-Kreis 34 pt statt System-Zurück mit Titel (`paper_settings.dart:35-47, 77-78`).
- Rückmeldungen über Material-Snackbars (131 `SnackBar(`), auf iOS nur dank nachgerüstetem `ScaffoldMessenger` (`app.dart:224-228`). Kein iOS-Muster.
- Material-Spinner `CircularProgressIndicator` in 12 Dateien; keine Skeletons. Widerspricht "nie sichtbares Laden".
- Theme-Standard ist "Hell" statt "System" (`theme_provider.dart:32-33`); iOS-Dunkelmodus wird ohne Zutun ignoriert.
- `AdaptiveGlass` behandelt "Transparenz reduzieren" über `MediaQuery.highContrastOf` (`liquid_glass_container.dart:149`); das ist "Kontrast erhöhen", nicht "Transparenz reduzieren". Flutter liefert Reduce Transparency nicht, dafür braucht es einen nativen Kanal (oder man überlässt es dem nativen `UIGlassEffect`, der das selbst macht).
- Reduce Motion wird in der Shell nicht beachtet: Slide (`main_scaffold.dart:51-66`), Banner-Slide (`:467-470`), Tutorial-Puls (`tutorial_overlay.dart:34-41`). Nur Composer und Attachment-Sheet prüfen `disableAnimationsOf`.
- Drei Icon-Sets gemischt: Lucide in der Tab-Leiste (`main_scaffold.dart:4, 297-325, 447`), Material im Offline-Banner (`:493`) und fast überall sonst (ca. 365), Cupertino (39). SF Symbols nur in nativen Alerts (`confirm_dialog.dart:19`). Rezeptkategorien mit Emojis als Icons (`recipe_categories.dart:24-...`).
- Icons in getönten Quadraten (Anti-Slop): `AppListTile` 44-pt-Quadrat mit Akzent-Icon (`design_system.dart:444-455`), `AppEmptyState` Icon im Kreis (`:644-656`).
- Regenbogenfarben: 10 Einkaufskategorien mit Material-Grundfarben (`categories.dart:35-134`), Rezeptkategorien bunt (`recipe_categories.dart`), 15 Neon-Verläufe (`list_background_gradients.dart`, ungenutzt).
- Akzent Terrakotta überall (Buttons, Fokusrahmen, Cursor, Speichern-Pille, Rezepte, "info"): `app_colors.dart:69-84, 103-126`. Die Benennung `accentBlue = accent` (`:264`) ist irreführend.
- Gradient-Glanz und farbiger Schatten auf Buttons (`liquid_glass_button.dart:61-79`), weißer Rand 30 %: wirkt wie iOS 7, nicht wie Liquid Glass; jeder Button mit eigenem `BackdropFilter` (`:52-53, :149-150`), obwohl er auf opaken Flächen liegt.

### 3.2 Feste Höhen, Breiten und Schriftgrößen (brechen bei großer Schrift oder 320 pt)
- `PaperPrimaryButton` fest 54 pt hoch (`paper_widgets.dart:35`), `PaperOutlineButton` fest 50 pt (`:85`): Label wird bei Bedienungshilfen-Größen abgeschnitten (Primär-Label ohne `Flexible`/Ellipse).
- `AppButton` fest 40/52/56 pt (`design_system.dart:135-139, 147-149`), `AppOutlineButton` fest 52 pt (`:213`), Button-Zeile ohne `Flexible` -> Überlauf bei langem Text oder großer Schrift. `AppEmptyState`-Button fest 200 pt breit (`:683`).
- `PaperSettingsAppBar` fest 56 pt (`paper_settings.dart:24`) mit 20-pt-Serif-Titel: wächst nicht mit Dynamic Type.
- `PaperCircleIconButton` 34 x 34 pt (`paper_settings.dart:77-78`) und `PaperSaveButton` ca. 29 pt hoch (13 pt Text + 2 x 7 Padding, `:110-127`): unter 44 pt Touch-Ziel.
- `PaperSectionHeader` 10 pt (`paper_settings.dart:149`), `PaperKicker` 11 pt (`paper_colors.dart:52`), Feldlabel 12 pt (`paper_widgets.dart:159`), Fehlertext 12 pt (`:196`): unter Apples Minimum bzw. kaum lesbar.
- Tab-Leiste bei 320 pt (Anzeigezoom): Pille ca. 209 pt Innenbreite für 4 Sitze à 49 pt plus Orb 62 pt -- passt knapp; mit sichtbaren Labels oder einem 5. Tab nicht mehr. Bei Bedienungshilfen-Größen wächst nichts mit.
- Offline-Banner Text fest 13 pt mit Laufweite 0,2 (`main_scaffold.dart:503-505`).
- Abstände unten hart codiert statt aus der Shell: `recipes_screen.dart:539` und `profile_screen.dart:110` je `120 + padding.bottom`; 9 andere Screens nutzen `MainScaffold.getNavbarClearance` (`main_scaffold.dart:153-156`). Zwei Wahrheiten für den gleichen Abstand.
- `AppTextStyles` sind alle feste Größen mit fester Laufweite (`app_text_styles.dart:10-74`), z. B. `bodyLarge` 17 pt mit -0,4; keine Bindung an Dynamic-Type-Stile (Large Title, Title 1-3, Headline, Body, Callout, Subheadline, Footnote, Caption). App-weit 593 feste `fontSize`.
- Gemeldeter Bug (Listen-Eingabeleiste halb abgeschnitten auf iPhone 13 Pro) gehört zum Listen-Inventar; Ursache dort laut Verbesserungsliste feste 17 pt plus 9 pt Padding in `add_item_composer.dart`.

### 3.3 Paper-Reste (Kicker, Serifen, Creme/Terrakotta)
- Gesamte helle Palette ist Paper: `app_colors.dart:38-84` (Hintergrund #F7F3EC, Fläche #FFFDF8, Eingabe #EFE8DA, Tinte #201D18, Grau #8A8274, Akzent Terrakotta #C0502A, Erfolg Salbei #5F7D52).
- `PaperColors` (17 feste, nicht adaptive Farben) in 39 Dateien, 218 Stellen; laut Kommentar absichtlich "in beiden Modi hell" für Auth/Onboarding (`paper_colors.dart:3-5`), d. h. Login/Onboarding ignorieren den Dunkelmodus.
- Georgia-Serif (`paper_colors.dart:32-48`) 59-mal in 34 Dateien, u. a. Einstellungs-Titel (`paper_settings.dart:50`), Home, Profil (6-mal), Onboarding, Avo-Chat.
- Großbuchstaben-Kicker mit Laufweite 1,4-2: `PaperKicker` (9 Dateien: Login, Signup, Welcome, OTP, Onboarding und drei Onboarding-Seiten), `PaperSectionHeader` (9 Dateien), dazu handgebaut z. B. `home_screen.dart:355, 536`, `subscription_screen.dart:124, 490`, `profile_screen.dart:569, 589`, `calories_screen.dart:77`, `recipes_home_widgets.dart:37, 170`, `list_category_section.dart:204`, `shopping_history_screen.dart:143, 292`, `weekly_deals_screen.dart:277`, `offer_suggestions_bar.dart:106`, `item_offer_sheet.dart:207`, `split_cost_sheet.dart:246, 348`, `avo_nudge_card.dart:65`, `personal_flyer_card.dart:149`, `calorie_recipe_nudge_card.dart:56`, `onboarding_screen.dart:527`.
- Tinten-Pille mit Creme-Icons (`main_scaffold.dart:212, 391, 401`), Hintergrund `PaperColors.paper` (`:219, :250-253`), Schatten in Tintenfarbe #201D18 (`:285-287, :439`).
- Unterstreichungsfelder und Terrakotta-Cursor (`paper_widgets.dart:121-202`), Creme-Kreisknöpfe (`paper_settings.dart:80`), Terrakotta-Speichern-Pille (`:112`).
- Home-Hinweisstreifen mit fester Creme `Color(0xFFEFE8DA)` ohne Dunkel-Variante (`home_screen.dart:286`).

### 3.4 Zerfaserte Token-Systeme
- Drei Radien-Systeme: `AppDimensions` (Karte 28, Button 24, Eingabe 24, Sheet 36, Modal 32; `app_dimensions.dart:14-18`), `AppRadius` (Karte 20, Button 16, Eingabe 16, Sheet 24, Dialog 24; `design_system.dart:13-44`, nur in der eigenen Datei genutzt), dazu lose Werte 14 (`paper_settings.dart:162`, `liquid_glass_button.dart:51`), 6 (`home_screen.dart:287`). Keine konzentrische Ableitung von den Geräteecken.
- Schrift "Satoshi" ist in `app_text_styles.dart:5-6` und `app_theme.dart:31, 227` gesetzt, aber nicht in `pubspec.yaml` eingebunden (kein `fonts:`-Block). Auf iOS fällt alles auf die Systemschrift zurück; die von Hand gesetzten Laufweiten (-0,4, -0,3 ...) sind für Satoshi gedacht, nicht für SF Pro und nicht größenabhängig.
- `AppTextStyles` wird nur in 6 Dateien genutzt, `AppDimensions` in 13, `AppColors` in 85, `PaperColors` in 39, `design_system.dart` in 13 (fast nur Kalorien), `paper_widgets.dart` in 8 (Auth/Onboarding), `paper_settings.dart` in 10 (Einstellungen). Jede Feature-Gruppe hat ihr eigenes System.
- Dunkelmodus nutzt eine eigene, grünstichige Rezept-Palette (`app_colors.dart:115-139`) und Tailwind-Grau im Offline-Banner (`main_scaffold.dart:479`) sowie `#16181D` für die Pille (`:212`).

---

## 4. Bugs, Risiken und Performance-Probleme

### 4.1 Theme wird auf iOS nicht angewendet (hoch)
- `app.dart:187-191` übergibt `materialLightTheme`/`materialDarkTheme` an `AdaptiveApp.router`. Auf iOS baut das Paket eine `CupertinoApp` und nutzt davon nur `colorScheme.primary` (`adaptive_platform_ui-0.1.100/lib/src/widgets/adaptive_app.dart:256-268, 310-322`). `Theme.of(context)` liefert dann Flutters `CupertinoBasedMaterialThemeData` (`ColorScheme.fromSeed(Terrakotta)`), nicht `AppTheme`.
- Folge: `scaffoldBackgroundColor`, `appBarTheme` (inklusive `systemOverlayStyle`), `cardTheme`, `inputDecorationTheme`, Button-Themes, `dialogTheme`, `bottomSheetTheme`, `pageTransitionsTheme`, `fontFamily` aus `app_theme.dart` sind auf dem iPhone wirkungslos. Erklärt, warum fast jeder Screen Farben selbst setzt und warum `app.dart:203-223` die Statusleiste imperativ erzwingen muss. Material-Standardwidgets ohne explizite Farben bekommen seed-generierte Töne.
- Für das Redesign: Theme-Quelle muss so eingebunden werden, dass sie auf iOS wirklich greift (z. B. `Theme`-Wrapper im `builder` oder eigenes Token-Inherited-Widget).

### 4.2 Tab-Slide läuft durch leere oder ausgeblendete Seiten (mittel)
- `SlidingTabsContainer` rechnet mit Branch-Indizes, nicht mit sichtbaren Tab-Positionen (`main_scaffold.dart:86-87, 95`). Bei ausgeschaltetem Kalorien-Modul gleitet Rezepte -> Profil durch Branch 2. Nie besuchte Branches sind in go_router 13.2.5 `SizedBox.shrink()` (`go_router-13.2.5/lib/src/route.dart:1384`): man sieht kurz eine leere Seite. Home -> Profil schiebt über drei Bildschirmbreiten.
- Unterbrechung springt: bei einem neuen Tab-Tipp mitten in der Animation wird `_from = _to` gesetzt (`:61-66`), nicht die aktuelle Position. Sichtbarer Sprung; Apple-Regel "Start vom aktuellen Wert" verletzt.
- Während des Slides werden alle Zwischen-Branches gelayoutet und gemalt (`:101-102`): bis zu vier schwere Screens in einem Frame-Fenster von 320 ms -> Ruckelrisiko auf iPhone 13 Pro.

### 4.3 Gesamter App-Baum wird bei Theme- oder Sprachwechsel neu aufgebaut (mittel)
- `key: ValueKey('$themeMode-$languageCode')` (`app.dart:188`) remountet beim Wechsel alles: Scrollpositionen, Formulareingaben, Branch-Stapel und Tab-Zustände gehen verloren.
- `ThemeModeNotifier` startet mit `ThemeMode.light` und lädt asynchron erst lokal, dann vom Server (`theme_provider.dart:33-56`): wer Dunkel gewählt hat, sieht beim Start erst Hell, dann einen kompletten Remount, gegebenenfalls ein zweites Mal nach dem Server-Abgleich. Sichtbares Flackern beim Start.

### 4.4 Akzentfarbe ohne Wirkung (niedrig, aber sichtbar)
- `accentColorProvider` (Standard iOS-Blau, `theme_provider.dart:24, 94`) wird in kein Theme eingespeist; einziger Schreiber ist Avo (`avo_settings_bridge.dart:251-252`). Avo meldet "Akzentfarbe geändert", die App ändert sich nicht.

### 4.5 Router
- Kein `errorBuilder`: unbekannte Pfade (z. B. `shoply:///irgendwas`, `deep_link_service.dart:225-227` gibt `uri.path` ungeprüft weiter) zeigen die Standard-Fehlerseite von go_router.
- Nur Listen-Links werden über den Login hinweg gemerkt (`app_router.dart:399-403`); `/author/<id>` und andere private Links gehen bei ausgeloggtem Start verloren.
- Deep Links navigieren mit `go` (`deep_link_service.dart:84`) und ersetzen den Stapel, Notifications mit `push` (`navigation_service.dart:38, 51, 62`). Uneinheitliches Zurück-Verhalten.
- Englische Fallback-Titel in deutscher UI: "Shopping List" (`app_router.dart:303, 316`; `navigation_service.dart:33, 49`), "Shared List" (`app_router.dart:463`).
- 24 Screens ohne Route (`Navigator.push`, siehe 2.4): nicht per Deep Link, Widget, Siri, Notification oder Avo erreichbar, z. B. die Paywall und alle Einstellungen. Ob erneutes Tippen auf den aktiven Tab diese imperativ gepushten Seiten zuverlässig schließt, ist ungeprüft (go_router entfernt seitenlose Routen nur unter bestimmten Bedingungen).

### 4.6 Shell-Details
- Kalorien-Fallback nach Frame (`main_scaffold.dart:204-210`): ein Frame lang ist der ausgeblendete Branch noch aktiv; der Slide geht dann von Index 2 nach 0.
- Leiste verschwindet beim Tastatur-Öffnen hart ohne Animation (`:193, 237, 262`).
- Offline-Banner liegt ohne Platzreservierung über Titeln und Statuszeilen der Screens (`:225-232`).
- Tab-Labels und "Offline" hart codiert Deutsch (`:298-325, 501`); in Englisch falsche VoiceOver-Ansage. Tutorial-Texte ebenfalls hart Deutsch (`dynamic_tutorial_service.dart:143-218`).
- `SystemChrome.setSystemUIOverlayStyle` per `addPostFrameCallback` in jedem `builder`-Durchlauf (`app.dart:221-223`), also bei jeder MediaQuery-Änderung (z. B. Tastatur) erneut.
- Statusleisten-Stil wird global aus dem Theme abgeleitet; Paper-Auth-Screens sind immer hell, bei dunklem System-Theme wird die Statusleiste dort weiß auf Creme (Risiko, prüfen).

### 4.7 Liquid-Glass-Bausteine
- Jede Glasfläche ist eine eigene `UiKitView` (`liquid_glass_container.dart:60-72`). Platform Views zwingen Flutter auf iOS zu Composition-Overhead; viele davon pro Screen (Rezepte: 2, Rezeptdetail: 3) kosten Frames beim Scrollen.
- `LiquidGlassGroup` übergibt Formen nur als `creationParams` (`:226-236`); die native Seite legt sie einmal beim Erzeugen an (`LiquidGlassViewFactory.swift:221-236, 239-248`) und hat keinen Methodenkanal für Updates. Wenn sich Größe oder Position ändern (Textlänge, Dynamic Type, Rotation), bleibt das Glas stehen, solange sich der Widget-Key nicht ändert.
- Vor iOS 26: Kapselradius wird aus `view.bounds` beim Erzeugen berechnet (`LiquidGlassViewFactory.swift:118-121`), zu dem Zeitpunkt ist die Größe oft 0 -> eckige statt runde Form auf iOS 18/25.
- `LiquidGlassFilledButton`/`OutlinedButton` (`liquid_glass_button.dart`) sind kein Glas, sondern `BackdropFilter` mit Verlauf; dunkel und hell gleich farbig (`Colors.red`, `AppColors.lightAccent`, `:43`); nutzen das veraltete `withOpacity` (Analyzer-Infos).

### 4.8 Toter oder irreführender Code
- `list_background_gradients.dart` (218 Zeilen) wird nirgends importiert, obwohl `ShoppingListModel.backgroundType` standardmäßig `'gradient'` ist (`shopping_list_model.dart:41`).
- `pubspec.yaml:115`: Kommentar "assets/avo nur von der ungenutzten ListsScreen referenziert" ist falsch; `lib/core/mascot/avo_mascot.dart` nutzt die Bilder.
- CLAUDE.md spricht von 29 Kategorien; `categories.dart` hat 10.
- Rechtliche Links auf zwei Domains (`legal_links.dart:6-10`: joinavo.app und shoplyai.app); Share-/Universal-Link-Domain shoplyai.app (`app_config.dart:3`, `deep_link_service.dart:13`). Für ein Rebranding auf "Avo" relevant.

---

## 5. Abhängigkeiten zu anderen Bereichen

- Alle Tab-Wurzeln (Home, Rezepte, Kalorien, Profil) leben in der Shell; ihre unteren Abstände hängen an `MainScaffold.getNavbarClearance` (9 Dateien: Notifications, Language, HelpSupport, MultiSelectSettings, WhatCanIEat, GoalSetup, WeeklySummary, WeightTracking) oder an hart codierten `120 + safeArea` (Rezepte, Profil). Neue Leistenhöhe -> alle diese Stellen.
- Kalorien-Modul: `calorieTrackingEnabledProvider` steuert den Tab; der Branch-Index 2 ist fest. Ein Modul-System (Plan 1) muss Tabs dynamisch machen; heute ist nur Kalorien schaltbar.
- Avo: Orb in der Shell und Hinweisstreifen in `home_screen.dart:280`; Route `/avo` außerhalb der Shell; `AvoSettingsBridge` kann Theme und Akzentfarbe setzen (`avo_settings_bridge.dart`).
- Listen: `/lists/:id` liegt außerhalb der Shell; Siri (`app.dart:111-162`), Deep Links, Notifications und das Tutorial (`firstListCardKey`, `addItemInputKey`, `listItemsAreaKey`) öffnen oder markieren Listen. `add_item_composer.dart` und `attachment_sheet.dart` nutzen `LiquidGlassGroup`/`LiquidGlassContainer`.
- Rezepte: `recipes_screen.dart:281, 297` und `recipe_detail_screen.dart:184, 321, 353` nutzen `AdaptiveGlass`; `recipe_categories.dart` speist Rezept-Home, Suche, Personalisierung; Tutorial-Keys `recipesTabKey`, `recipesAreaKey`, `addRecipeButtonKey`.
- Auth/Onboarding: komplett auf `paper_widgets.dart` + `PaperColors` (8 Dateien); Redirect-Logik im Router hängt an `hasCompletedOnboarding()` aus `onboarding_screen.dart`.
- Einstellungen und Listen-Unterseiten: komplett auf `paper_settings.dart` (10 Dateien).
- Kalorien: fast der einzige Nutzer von `design_system.dart` (10 von 13 Dateien).
- Native Alerts/Menüs über `adaptive_platform_ui`: `confirm_dialog.dart`, `home_screen.dart:641-768` (Eingabe-Alerts, Hinweise), `shopping_trip_completion.dart:35-62`, `list_detail_menu.dart:88-108` (`AdaptivePopupMenuButton` ab iOS 26), `list_detail_parts.dart:69-127` (`AdaptiveButton`), `category_order_screen.dart:403-440` (`AdaptiveBlurView`, `AdaptiveTextField`), `recipe_detail_screen.dart:520` (`AdaptiveSwitch`).
- Lokalisierung: `lib/core/localization/app_translations.dart` (2354 Zeilen) enthält auch Paper-Kicker-Schlüssel (`sign_in_kicker`, `signup_kicker`, `onb_*_kicker`, `avo_hint_home`); Shell- und Tutorial-Strings sind nicht darin.
- Theme-Daten: `theme_provider.dart` liest/schreibt `user_preferences` in Supabase (Theme-Modus, Akzentfarbe) und SharedPreferences.
- Kategorien: `categories.dart` wird von Kategorisierung (`gemini_categorization_service.dart`), Kategorie-Reihenfolge (`category_order_service.dart`), ML-Empfehlungen, Diät-Prüfung (`diet_checker.dart`), Artikel-Formular und Listen-Abschnitten genutzt. Farben und Icons dort sind Teil des Designs, die IDs Teil der Daten.
- Analytics: Screen-Tracking über den Router-Observer; Routennamen (`name:`) sind die Screen-Namen in Firebase.
- Widgets/Siri: iOS-App-Intents rufen `shoply://add-item` und `shoply://create-list` auf; Widget-Deep-Links laufen über `DeepLinkService`.

---

## 6. Was ein Redesign unbedingt erhalten muss

Funktionen
- Tab-Zustände bleiben erhalten (eigener Navigator pro Tab, kein Neuaufbau beim Wechsel); erneutes Tippen auf den aktiven Tab führt zur Wurzel (zusätzlich: nach oben scrollen).
- Kalorien-Tab nur bei eingeschaltetem Modul; Rücksprung, wenn der aktive Tab ausgeblendet wird. Muss zu einem allgemeinen Modul-Mechanismus werden (Plan 1), mit stabilen Routen auch bei ausgeblendeten Modulen.
- Genau ein Avo-Einstieg, Avo als Vollbild außerhalb der Tabs erreichbar (`/avo`).
- Offline-Hinweis (heute Banner) mit korrekter Startbelegung und ohne Aufblitzen.
- Tab-Leiste weicht der Tastatur.
- Native destruktive Bestätigung nur bei endgültigem Löschen (`confirmDestructive`).
- Globaler Rahmen für Rückmeldungen (heute `ScaffoldMessenger`, auf iOS Pflicht, sonst Absturz bei `showSnackBar`).
- Statusleisten-Stil passend zu Hell/Dunkel auf jedem Screen.
- Tutorial-Ziele (GlobalKeys) oder ein gleichwertiger Ersatz im neuen Onboarding.

Routen und Links (alle Pfade sind extern verlinkt und dürfen nicht brechen)
- `/home`, `/recipes` (`?q=`), `/recipes/add` (`draftId`, `recipeId`), `/recipes/drafts|saved|my|creators|popular|all`, `/recipes/category/:categoryId`, `/recipes/:recipeId`, `/calories`, `/profile`, `/avo`, `/lists/:listId` (`?name=`), `/lists/:listId/activities`, `/author/:authorId`, `/diet-preferences`, `/recipe/:recipeId` (öffentlich), `/list/:listId`, `/invite/:listId`, `/onboarding`, `/welcome`, `/login`, `/signup`, `/reset-password`, `/name-prompt?new=1`.
- Schema `shoply://` mit Hosts recipe, list, lists, recipes (saved, search?q=), author, invite, addItem, add-item, create-list; Universal Links `https://shoplyai.app/{recipe|list|author|invite}/<id>`; Share-Links `https://shoplyai.app/join/<CODE>`.
- Notification-Typen: list_activity, category_change, list_update, list_invitation, recipe_rating, recipe_like, recipe_comment (auch altes Feld `recipe_id`), avo_restock.
- Duplikat-Schutz für Deep Links (2 s) und einmalige Behandlung des Kaltstart-Links.

Sonderfälle im Redirect
- Ausgeloggt geöffneter Listen-/Einladungslink wird nach dem Login fortgesetzt.
- Login/Signup leiten selbst weiter (OTP-Race), der Router darf sie nicht zwangsweise umleiten.
- `/name-prompt` nur mit `?new=1`.
- Passwort-Wiederherstellung über Auth-Event öffnet `/reset-password`.
- Kontowechsel invalidiert kontobezogene Provider und den Abo-Status; Theme- und Kalorien-Einstellung werden pro Konto neu vom Server geladen.
- Siri: "Artikel zu Liste" findet die Liste namensunabhängig von Groß-/Kleinschreibung oder legt sie an und öffnet sie per `push`.

Daten und Einstellungen
- Theme-Modus lokal (SharedPreferences `theme_mode`) plus Supabase `user_preferences`; die in dieser Sitzung getroffene Wahl gewinnt gegen den Server.
- `calorie_tracking_enabled` lokal plus `nutrition_goals.calorie_tracking_enabled`.
- `users.tutorial_completed`.
- Kategorie-IDs (`fruits_vegetables`, `bakery`, `meat_fish`, `dairy` ...) und ihre Reihenfolge (Laufweg im Markt); Diät-IDs; Prioritäten-IDs; Rezeptkategorie-IDs (müssen zu `recipe_filter.dart` und `recipe_service.dart` passen).
- Listen-Hintergründe (`background_type` color/gradient/image) existieren in Daten und Modell, auch wenn die Verläufe heute nicht gerendert werden: Entscheidung nötig, nicht stillschweigend verlieren.
- Native Glas-Infrastruktur (`shoply/liquid_glass`, `shoply/liquid_glass_group` inkl. Verschmelzen über `UIGlassContainerEffect`) ist wiederverwendbar und funktioniert; sie sollte für Tab-Leiste, Toolbars und Eingabe-Accessory weitergenutzt und um Updates per Methodenkanal ergänzt werden.
- Analytics-Screen-Namen (Routennamen) möglichst stabil halten oder bewusst migrieren.
- Hochformat-Sperre auf dem iPhone (`main.dart:32-35`).
