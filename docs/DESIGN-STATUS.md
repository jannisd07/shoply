# Design-Status

Stand: 2026-11-07. Grundlage für den Redesign. Kurz gesagt: Die App mischt drei Designsprachen, und ein Teil des
Themes wirkt auf iOS gar nicht. Daher kommt das Gefühl "zusammengestückelt, KI-generiert".

## Feste Regel: Keine Slider

Vom Owner am 2026-11-07 festgelegt, gilt ohne Ausnahme (auch in Mockups):

- **Nie Panels, die hereingleiten**: keine Bottom-Sheets, keine halbhohen Modals, keine Drawer.
- **Bearbeiten (vor allem "Artikel bearbeiten") ist immer ein eigener Vollbild-Screen** mit Zurück-Button
  (`context.push`) oder passiert direkt an Ort und Stelle.
- **Keine Schieberegler.** Stattdessen Stepper, Segmented Control, Picker oder Zahlenfeld.
- Erlaubt bleiben zentrierte Bestätigungsdialoge und Kontext-/Pull-down-Menüs.

Stand im Code (2026-11-07), beim Redesign umbauen:

| Art | Dateien |
|---|---|
| Hereingleitende Panels (17 Aufrufe) | `lists/widgets/`: `zip_code_sheet`, `checkout_store_sheet`, `list_detail_menu`, `list_price_summary_bar`, `import_review_sheet`, `item_offer_sheet` · `lists/category_order_screen` · `home/weekly_deals_screen` · `recipes/recipe_detail_screen`, `recipes/cooking_mode_screen`, `recipes/widgets/select_list_bottom_sheet` · `history/widgets/split_cost_sheet` · `calories/widgets/log_recipe_sheet`, `food_entry_sheet` · `profile/profile_screen` · `core/widgets/design_system.dart` · `data/services/contextual_prompt_service.dart` |
| Schieberegler | `calories/goal_setup_screen.dart`, `onboarding/widgets/onboarding_goal_page.dart` |

## Gewählte Richtung: D2 "Glas"

Der Owner hat am 2026-11-07 die Richtung **D2 · Glas** gewählt: iOS 26 Liquid Glass, hell, echte Fotos.
Mockups: Design-Leinwand "Shoply Redesign", Seite "D2 · Glas" (Home, Liste, Rezepte, Artikel bearbeiten als
Vollbild, Komponenten-Blatt mit Tokens). Die Komponenten-Seite ist die Vorlage für die Flutter-Umsetzung.

## Die drei Stile im Code

| Stil | Merkmale | Wo |
|---|---|---|
| **Paper** (Juli 2026) | warmes Papier-Beige, Serif (Georgia) über `PaperTextStyles`, Terrakotta `#C0502A`, Haarlinien | Profil, Einstellungen, Avo-Chat (teilweise), Listen-Detail (teilweise), Home-Streifen |
| **Liquid Glass** | `AdaptiveGlass`, native Glas-Views, iOS-Blau | Navbar, Rezept-Buttons, Kategorie-Reihenfolge, `liquid_glass_button.dart` |
| **Altes Material / dunkles iOS** | `design_system.dart`, `AppColors`, harte Hex-Werte `0xFF1C1C1E` | Kalorien-Modul komplett, Auth/Onboarding, Leerzustände (`empty_state.dart`) |

## Strukturelle Ursachen

- **Auf iOS wird `AppTheme` ignoriert.** `AdaptiveApp.router` baut eine `CupertinoApp`, die nur `primaryColor`
  übernimmt. Die 400 Zeilen Material-Theme greifen dort nicht. Deshalb setzen die Screens Farben und Schriften
  einzeln von Hand, und genau dabei entsteht der Wildwuchs.
- **Zwei Farbpaletten mit doppelten Werten**: `AppColors` und `PaperColors`. Screens wählen zufällig. `PaperColors`
  ist nur hell, also brechen solche Stellen im Dark Mode.
- **Die Schrift "Satoshi"** steht in `AppTextStyles` überall, ist aber nie eingebunden. iOS fällt still auf die
  Systemschrift zurück.
- Datenservices enthalten UI: `contextual_prompt_service.dart` (Widgets mit harten Farben, nur Deutsch),
  `dynamic_tutorial_service.dart` (Tutorial-Texte nur Deutsch).
- CLAUDE.md beschreibt noch "dark-first, AppColors, liquid glass", die App selbst ist inzwischen eher Paper.

## Screens mit dem größten Mix

1. Rezepte-Tab und Rezept-Detail: vier Stile. Für die Scroll-Performance sind die Glas-Karten jetzt schon durch
   undurchsichtige Flächen ersetzt.
2. Listen-Detail: Paper, Glas und Standard-iOS gemischt.
3. Home: Paper-Streifen mit harten Hellwerten, im Dark Mode kaputt.
4. Kalorien: komplett alter Stil.
5. Auth, Onboarding, Passwort-Reset: eigener, nur heller Stil.

## Vorschlag für den Redesign

1. **Ein** Token-Set (Farben hell/dunkel, Typo-Skala, Abstände 4/8/12/16/24/32, Radien) in `lib/core/theme/`, das
   auch auf iOS wirkt: über `CupertinoThemeData` und ein `InheritedWidget`/`ThemeExtension`, nicht über `AppTheme`.
2. Entscheiden: Paper **oder** iOS-native mit Liquid Glass. Nicht beides.
3. Geteilte Bausteine (Karte, Listenzeile, Section-Header, Button, Leerzustand, Sheet) einmal bauen und alle
   Screens darauf umstellen. Danach `PaperColors`/`design_system.dart`/`liquid_glass_button.dart` löschen.
4. Skills dafür: `apple-design`, `design-taste-frontend`, `ui-ux-pro-max` (siehe CLAUDE.md).
