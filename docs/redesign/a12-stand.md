# A12 Aufräumen und Analysen – Ergebnis (09.11.2026)

Quellen: prompt §5 A12, „Offen bei A“/„Aufräumen“ in `a7-stand.md`, `a8-stand.md`, `ab1-stand.md`, `ab2-stand.md`.
Commit: `git log --grep A12`. Keine neuen Anfragen von B seit AB2 (status-B endet bei Nr. 16, erledigt).
`dart analyze lib test` und die Gesamtsuite in einer sauberen Kopie von `origin/main`; kein Simulator nötig (nur
Löschungen und ein Farbtoken).

## Ergebnis

**Tote Dateien gelöscht** (von nichts importiert, alle A):
`core/widgets/paper/paper_widgets.dart`, `core/constants/app_text_styles.dart` (Satoshi-Reste),
`core/constants/app_priorities.dart`, `core/utils/validators.dart`, `data/models/recipe_filter.dart`,
`data/models/product_category.dart`, `widgets/common/empty_state.dart` (alt; der D2-`EmptyState` liegt in
`widgets/design/`), `widgets/common/liquid_glass_button.dart`, `widgets/common/loading_indicator.dart`,
`widgets/recommendations/` (`ml_recommendations_section.dart`, `recommendation_card.dart`),
`providers/ml_recommendations_provider.dart`, `screens/recipes/widgets/recipe_state_views.dart`.
`screens/admin/recipe_batch_labeling_screen.dart` gab es schon nicht mehr.

**Tote Symbole:** `AuthService`/`authServiceProvider` (`updateDisplayName`), `NavigationService.navigateToDietPreferences`,
`@Deprecated unsentChangesProvider` und `countUnsentChanges` (durch B's `pendingChangesCountProvider` ersetzt, Tests
dazu entfernt), `StarRatingWidget`/`CompactStarRating` (nur `RecipeRatingRow` bleibt, ohne `AppColors`).

**Texte:** 543 ungenutzte Schlüssel (je Deutsch und Englisch) aus A's Bereichsdateien entfernt: common 138,
recipes 117, lists 81, settings 59, auth 57, onboarding 30, home 21, profile 16, paywall 12, lists_shopping 2,
lists_overview 1. Darunter alle alten `onb_sorted_*` … `onb_goal_*`, `onb_illus_*`, die Schlüssel der gelöschten
Login-Screens, `restart_tutorial`/`tutorial_restarted`. Methode: Schlüssel gilt als benutzt, wenn er irgendwo in
`lib/` oder `test/` als String steht oder ein dynamisches Präfix (`'diet_$id'` usw.) passt; Varianten `_one`, `_you`,
`_sub` von benutzten Schlüsseln blieben stehen. B's Textdateien sind unberührt.

**Paper-Reste in A-Dateien:** nur noch die Paywall `subscription_screen.dart` (kommt mit A9).
`shopping_trip_completion.dart` nimmt `context.colors.tint` statt `AppColors.success`. `nudge_card.dart` wird nur noch
von B's toten Home-Karten importiert (siehe unten).

**Analyse:** [`feature-ideen.md`](feature-ideen.md): tägliche Nutzung, Alleinstellung, Vergleich mit Bring!, Listonic,
AnyList, Apple Erinnerungen, marktguru, kaufDA, REWE, Lidl Plus, Yazio; 22 Ideen mit Nutzen, Aufwand, Free/Pro;
Top 5 und Fragen an den Owner. Preise der Wettbewerber teils unsicher (mit „(?)“ markiert).

**`claude/daily`:** Owner am 09.11.2026: pausieren. Der Zweig hat keine eigenen Commits (alles in `main`). Abschalten
der Routine selbst macht der Owner (OPEN-ISSUES §3).

**Nachtfehler aus status-B 15** (`list_settings_screen_test.dart` „all changes: sections per day“): schon behoben,
der Test nutzt eine feste Uhr (`listChangesClockProvider`, 8.11. 15 Uhr).

**Doku:** `ARCHITECTURE.md` (kein `TutorialOverlay`, kein `widgets/paper`, Claude statt Gemini, Widget-Ordner),
`DESIGN-STATUS.md` (Stand-Hinweis A12, Tutorial-/Prompt-Service-Zeile entfernt).

## Braucht den Owner

- Routine `claude/daily` im Routine-Menü pausieren.
- Entscheidungen aus `feature-ideen.md` §5.

## Von Teil B (gewünscht)

- Tote B-Dateien löschen (nirgends importiert): `screens/home/widgets/avo_nudge_card.dart`,
  `price_comparison_nudge_card.dart`, `pending_splits_banner.dart`, `calorie_recipe_nudge_card.dart`,
  `personal_flyer_card.dart`, `split_trip_nudge_card.dart`. Danach löscht A `nudge_card.dart`.
- `data/services/ml_recommendation_service.dart` hat keinen Nutzer mehr (nur `test/ml_recommendation_test.dart`);
  löschen oder an Home/Vorschläge hängen. Dann kann auch `data/models/recommendation_item.dart` (A) weg.
- `AppColors`, `PaperColors`, `AppDimensions`, `design_system.dart` hängen nur noch an B-Dateien: Kalorien
  (`challenges`, `weekly_summary`, `weight_tracking`, `what_can_i_eat`, `macro_bar`, `weight_chart`), Verlauf
  (`checkout_flow`, `shopping_history_screen`, `split_cost_sheet`), `checkout_store_sheet`. Sobald die auf D2 sind,
  löscht A die Shims.

## Offen bei A

- Paywall auf D2 (A9), dann `paper_colors.dart` raus.
- Aus AB2 weiter offen: Rezeptdetail beachtet „Rezepte automatisch anpassen“ nicht, Präsenz im Einkaufsmodus und
  `sharePresenceProvider`, `ItemRow`-Vorschlagsvariante, `ListCard`-Cover ab AX1; aus AB1: A-K10, Galerie-Einträge,
  `SwipeActions`-Reste, Kalender-Menü, `AmountField`, `NutritionRow`, Charts mit Ziellinie, `InlineCalendar`,
  einklappbare `InsetSection`. Gehört in A11 bzw. eigene Pakete.

## Bewusst abgewichen

- Nicht entfernt: `ShoppingListModel.backgroundGradient` (`@Deprecated`, liest noch die DB-Spalte alter Listen).
- Die Texte von A7/A8 wurden nicht in weniger Dateien zusammengeführt; Löschen war wichtiger und risikoärmer.
