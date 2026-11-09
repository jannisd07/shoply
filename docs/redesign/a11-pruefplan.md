# A11 Qualität für alle A-Screens – Prüfplan und Auftrag (09.11.2026)

Quellen: prompt §5 A11 und §9, `konzept/20-qualitaet.md` (§5 Budget, §6 Matrix, §7 Verfahren), „Offen bei A“ in
`ab1-stand.md`, `ab2-stand.md`, `a12-stand.md`. Zuerst erledigt: status-B 17 (1) (`004b3fd`), 17 A-D1 stand schon.

## 1. Screens und was sie prüft

| Bereich | Screens (A) | Prüfmatrix heute | Lücke |
|---|---|---|---|
| Home | `HomeScreen` + Teile | Teile (`home_widgets_test`) | Screen als Ganzes |
| Listen | Liste, Einkaufsmodus, Alle Listen, Listen-Info, Editoren | Teile + `ShoppingModeView` | `ShoppingModeScreen` (Hülle) |
| Rezepte | Tab, Suche, Detail, Kochmodus, Editor, Bibliothek | Teile | `RecipesScreen`, `AllRecipesScreen`, `CategoryRecipesScreen`, `RecipeDraftsScreen`, Hüllen von Meine/Gespeichert/Ersteller/Autor |
| Onboarding, Login | Schritte, Passwort, Zurücksetzen | `auth_layout_test` | `EmailCodePage` |
| Profil, Einstellungen | Profil, alle A-Einstellungsseiten | je Seite | – |
| Paywall | `SubscriptionScreen` | – | kommt mit A9 (Paper, Owner entscheidet Free/Pro) |

Zustände je Screen (prompt §9): leer, lädt (lokaler Stand sofort), Fehler, offline, Modul aus, Pro gesperrt; nur die,
die der Screen hat. Matrix: `layoutMatrix` (320–440 pt, ×1,0–×3,1, fett, dunkel, Kontrast), keine Überläufe.

## 2. Prüfungen

1. **Prüfmatrix-Lücken schließen** (Tabelle oben), je Screen ein Test mit `layoutMatrix` und den Zuständen.
2. **Design-Regeln automatisch** (`konzept/20` §7.8): `tool/design_check.sh` für A-Dateien (Farben, Schriftgrößen,
   Dauern, Icons, Haptik, Sheets/Slider). Funde in A-Dateien beheben.
3. **Barrierefreiheit im Code:** Touch-Ziele ≥ 44 pt, VoiceOver-Label für jeden Knopf ohne Text, Reduce Motion
   (`context.reduceMotion`), Reduce Transparency/Kontrast (Glas deckend). Stichprobe über die Matrix-Tests
   (`meetsGuideline(androidTapTargetGuideline/iOSTapTargetGuideline, labeledTapTargetGuideline)`).
4. **Simulator-Stichproben** (iPhone 17, hell und dunkel, eine Runde AX3): Home, Liste mit Vorschlags-Panel,
   Listen-Info, Einkaufsmodus, Rezepte-Tab mit Tipp, Rezeptdetail mit Angeboten, Profil, Einstellungen. Screenshots
   nach `docs/redesign/abnahme/a11/`.
5. **Leistung:** Messung geht nur auf einem echten iPhone im Profile-Modus (§7.7, nie im Simulator). A legt die
   Messtests `integration_test/perf/` (S1 Liste scrollen, S2 Abhaken in Serie, S5 Rezepte-Tab) mit Testdaten ohne
   Server an; laufen lassen macht der Owner am Gerät.
6. **Flows** (`idiotensicher-testen`): Hinzufügen und Teilen im Simulator. Onboarding braucht Abmelden (nur mit Ja
   des Owners), Paywall wartet auf A9.

## 3. Agenten (höchstens 3, im gemeinsamen Ordner, committen nie)

Regeln für alle: nur die genannten Dateien anlegen oder ändern; Tests dateiweise (`flutter test --no-pub <datei>`),
vorher `pgrep -x flutter_tester | wc -l`, bei 2 oder mehr warten; `dart format` nur auf eigene Dateien; nie `git add`,
`stash`, `checkout`, `reset`, `restore`, `clean`. Vorbild für Tests: `test/screens/recipes/recipes_library_layout_test.dart`,
`test/screens/home/home_widgets_test.dart`, Gerüst `test/layout/layout_matrix.dart`. Provider mit
`ProviderScope(overrides:)` füttern, kein Supabase. Findet ein Test einen echten Fehler im Screen, darf der Agent ihn
in der A-Datei des Screens beheben (`bash docs/redesign/owner.sh <pfad>` muss `A` sagen); sonst melden.

- **Teil R (Rezepte):** neue Datei `test/screens/recipes/recipes_screens_matrix_test.dart` für `RecipesScreen`,
  `AllRecipesScreen`, `CategoryRecipesScreen`, `RecipeDraftsScreen` und die Hüllen `MyRecipesScreen`,
  `SavedRecipesScreen`, `CreatorsScreen`, `RecipeAuthorPage` (Zustände: Inhalt, leer, lädt, Fehler, offline).
- **Teil H (Home, Einkaufsmodus, Login):** neue Dateien `test/screens/home/home_screen_matrix_test.dart`,
  `test/screens/lists/shopping_mode_screen_matrix_test.dart`, `test/screens/auth/email_code_page_matrix_test.dart`.
- **Teil P (Leistung):** `integration_test/perf/` mit `perf_harness.dart` (Testdaten: 60 Artikel in 8 Kategorien,
  20 im Einkaufsmodus, Rezepte-Tab mit Bildern aus `assets/`), `s1_scroll_list_test.dart`,
  `s2_check_series_test.dart`, `s5_recipes_tab_test.dart` mit `IntegrationTestWidgetsFlutterBinding.watchPerformance`,
  `test_driver/perf_driver.dart` (schreibt die Zusammenfassung als JSON), `integration_test/perf/README.md` (Befehl,
  Grenzen aus §5.1). `integration_test` als `dev_dependency` (sdk: flutter) **nicht** selbst in `pubspec.yaml`
  eintragen, das macht A vorher als Mini-Commit. Prüfen mit `dart analyze integration_test test_driver`; laufen
  lassen geht nur am Gerät.

Bericht je Agent (letzte Antwort, höchstens 25 Zeilen): angelegte/geänderte Dateien, Ergebnis der Tests (Zahl
bestanden), behobene Fehler mit Datei und einem Satz, Offenes.
