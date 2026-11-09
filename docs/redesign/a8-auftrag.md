# A8 Profil und Einstellungen – gemeinsamer Auftrag für die A8-Agenten (Teil A)

Stand 09.11.2026. Drei Teile laufen gleichzeitig: **„Wurzel“**, **„Seiten“**, **„Konto“**. Paywall und Pro-Flächen
(Konzept 18 Kap. 8 und 9) gehören zu A9 und sind **nicht** Teil von A8; die Pro-Zeile im Profil zeigt nur den Status
und führt auf `/pro`.

## Ort und harte Regeln (wie A7)

- Repo `/Users/jannisdietrich/Apps/shoply-neu` (Flutter-App „Avo“, Dart-Paket heißt noch `shoply`). Jeder Bash-Befehl
  beginnt mit `cd /Users/jannisdietrich/Apps/shoply-neu && …`.
- **Teil B und zwei weitere A8-Agenten arbeiten gleichzeitig.** Keine git-Befehle, die etwas ändern (kein add, commit,
  stash, checkout, switch, restore, reset, clean). Committen macht die Hauptsitzung.
- **Nur die Dateien deines Teils** (unten). Texte nur in deiner Textdatei; vorhandene Schlüssel anderer Dateien darfst
  du benutzen. Ein doppelter Schlüssel ist ein Compile-Fehler. **Neue Texte sagen „Avo“, nie „Shoply“.** Keine `\n`.
- **`dart format` nur auf deine eigenen Dateien**, nie auf Ordner, in denen fremde Dateien liegen.
- Prüfen nur auf deine Dateien: `dart analyze <deine Dateien>` (0 Errors, 0 Warnings, 0 Infos) und `flutter test
  --no-pub <eine Testdatei>`. **RAM und Platte sind knapp:** Tests nur dateiweise, vorher `pgrep -f flutter_tester |
  wc -l` prüfen; bei 2 oder mehr 60 s warten (Monitor/until-Schleife) und erneut prüfen. Lange Befehle mit `timeout
  600`. Keine Builds, keine Simulatoren, keine Worktrees, keine Gesamtsuite.
- **Keine Änderungen an Supabase** (keine Migration, kein SQL, keine Edge Function). Server-Bedarf als Entwurf in den
  Bericht.
- `bash docs/redesign/owner.sh <pfad>` zeigt, wem eine Datei gehört. B-Dateien nie ändern (z. B.
  `lib/data/services/avo_settings_bridge.dart`, `avo_app_knowledge.dart`, `supabase_service.dart`,
  `lib/routes/areas/offers_routes.dart` und die anderen B-Routen); Wünsche an B in den Bericht.

## Pflichtlektüre vor dem Schreiben

1. `CLAUDE.md` Abschnitt „Design System“ und die harte Regel: **keine Sheets, keine halbhohen Modals, keine Slider,
   Bearbeiten im Vollbild**; zentrierte Alerts (`showAvoConfirm`) und Pull-down-Menüs (`showAvoMenu`) sind erlaubt.
2. **Konzept `docs/redesign/konzept/18-profil-pro.md`**: Kap. 1 (Regeln), 2 (Beispieldaten), 10, 11, 12 für alle, dazu
   die Abschnitte deines Teils. Optik dort ist teils überholt; D2 gewinnt. Ist-Zustand:
   `docs/redesign/konzept/inventar/profile.md`.
3. D2-Vorlage (verbindlich für die Optik):
   `/private/tmp/claude-501/-Users-jannisdietrich-Apps-RoadTo1Billion-/76ad5c46-b5c2-4efd-a1ef-f81b6109f927/scratchpad/d2/project/X-Profil.dc.html`,
   dazu `D2-Komponenten.dc.html`.
4. **Navigationsmodell ist D2** (Owner 07.11.2026): Profil ist der fünfte Tab (Home, Listen, Avo, Rezepte, Profil), kein
   Avatar in den Titelzeilen. Die Profil-Wurzel ist die Tab-Wurzel `/profile`; `/settings` zeigt dieselbe Seite;
   Einstellungsseiten sind Pushes in diesem Tab (höchstens drei Ebenen).
5. Komponenten in `lib/presentation/widgets/design/` (nutzen statt Eigenbau): `InsetSection`, `SectionCaps`,
   Settings-Rows (`NavRow`, `ToggleRow`, `ValueRow` …), `AppFilterChip`/`ChipRow`, `AvoSearchField`, `ValueStepper`,
   `AppSegmentedControl`, `StatusRow`, `EmptyState`, `AvoToast`/`UndoToast`, `showAvoConfirm`, `showAvoMenu`,
   `GlassToolbar`/`GlassIconButton`, `ScrollEdgeFade`, `Avatar`, `ProBadge`, `AvoIcons` (seit 54a2ee5 auch envelope,
   eye, circle, checkmarkCircleFill, questionmarkCircle, lightbulb, personBadgePlus, storefront …). Tokens:
   `package:shoply/core/design/design.dart` (`colors.warning` gibt es). Rahmen für gepushte Seiten wie
   `ListSettingsScreen`/`ListActivitiesScreen` (A5). Prüfgerüst: `test/layout/layout_matrix.dart`.

## Gemeinsame Schnittstellen (auf main, Konstruktoren nicht ändern, nur optionale Parameter ergänzen)

- `RoutePaths.settingsProfile`, `settingsModules`, `settingsDiet`, `settingsPersonal`, `settingsLists`,
  `settingsNotifications`, `settingsAppearance`, `settingsLanguage`, `settingsHelp`, `settingsLegal`,
  `settingsLegalSources`, `settingsLegalDocument(id)`, `settingsAccount`, `settingsAccountDelete`.
- Platzhalter-Screens (Teil „Seiten“ bzw. „Konto“ füllt sie): in `lib/presentation/screens/profile/settings/`
  `ModulesSettingsScreen`, `DietSettingsScreen`, `PersonalSettingsScreen`, `ListsSettingsScreen`,
  `NotificationsSettingsScreen`, `AppearanceSettingsScreen`, `LanguageSettingsScreen`, `HelpSettingsScreen`,
  `LegalSettingsScreen`, `DataSourcesScreen`, `LegalDocumentScreen(document: LegalDocument)`; in
  `lib/presentation/screens/profile/account/` `ProfileEditScreen`, `AccountScreen`, `DeleteAccountScreen`. Alle mit
  `{this.highlightRowId}`.
- Suche: `SettingsSearchEntry` (`profile/settings_search_entry.dart`: `route`, `titleKey`, `pathKeys`, `keywordsKeys`,
  `rowId`, `icon`, `offersTerm`). Einträge der Seiten in `settings/settings_pages_search.dart`
  (`settingsPagesSearchEntries`, Teil „Seiten“), der Konto-Seiten in `account/account_search.dart`
  (`accountSearchEntries`, Teil „Konto“). Teil „Wurzel“ führt sie mit den Einträgen der Wurzel und B's Seiten zusammen.
  `rowId` heißt `<seite>.<zeile>` (z. B. `diet.allergies`, `notifications.restock`, `account.delete`).
- Hervorhebung: `RowHighlightScope(rowId:)` und `HighlightableRow(id:, child:)` in
  `widgets/design/row_highlight.dart`. Die Route setzt den Scope aus `?row=`, jede Seite wickelt ihre Zeilen in
  `HighlightableRow` mit genau den `rowId`s ihrer Sucheinträge.
- Onboarding (A7) für „Seiten“: `mergeDietAndAllergies` (`lib/data/services/onboarding_answers_service.dart`), der
  Ernährungs-Schritt `lib/presentation/screens/onboarding/steps/diet_step.dart` und `module_descriptors.dart`
  (`lib/core/modules/`) sind die Vorlage; gleiche Chips, gleiche Logik, keine zweite Allergie-Logik.
- Tipps: `TipService.instance.reset()` für „Tipps zurücksetzen“ (Hilfe).

## Teil „Wurzel“

Dateien: `lib/presentation/screens/profile/profile_screen.dart` (neu schreiben oder durch
`profile_root_screen.dart` ersetzen), `lib/presentation/screens/profile/settings_search*.dart` (außer
`settings_search_entry.dart`, nur ergänzen), `lib/routes/areas/profile_routes.dart`, `lib/routes/route_paths.dart` (nur
ergänzen), `lib/presentation/widgets/common/paper_settings.dart` (entfällt, wenn nichts mehr darauf zeigt),
Tests unter `test/screens/profile/` (außer `settings/` und `account/`). Texte:
`lib/core/localization/translations/profile_root.dart` (`profileRootEn/De`, Präfix `prof_`).

- Konzept §1, §3 (ganz), §6 (Einordnung der B-Seiten), §10.1/10.2, E18-11, E18-12, E18-14.
- Profil-Wurzel nach §3.2 und D2 `X-Profil`: Großtitel „Profil“, Suchfeld, Kopfzeile Person (Avatar 64, Name, E-Mail →
  `/settings/profile`), Pro-Zeile mit Status nach §3.4 (`subscriptionStatusProvider` o. ä.; Tippen `/pro`, das A9 baut),
  Sektionen App / Module / Für dich / Allgemein / iPhone / Hilfe und Rechtliches / Konto, Fuß mit Version aus
  `package_info`. Keine Zähler, keine Premium-Karte, keine Paper-Optik, kein roter Abmelden-Knopf.
- Werte rechts in den Zeilen live aus den Providern (Module „4 an“, Ernährung „Vegetarisch · 1 Allergie“, Mitteilungen
  „An“/„In iOS aus“, Darstellung, Sprache, Konto-Anmeldeweg).
- B-Seiten: Zeilen nur, wenn die Route existiert (`/settings/offers`, `/settings/health`, `/settings/plan`,
  `/settings/avo`; Siri/Widgets fehlen heute → Zeilen weglassen und im Bericht nennen); Modulseiten nur bei Modul an;
  Kill-Switch: „Märkte“ statt „Preise & Angebote“ (`offersRemoteEnabledProvider`/`offersAvailableProvider` aus
  b_slots).
- Suche (§3.5): lokal, beide Sprachen, sofort; Treffer mit Pfad; Push mit `?row=`; keine Treffer → `EmptyState` mit
  „iOS-Einstellungen öffnen“; Kill-Switch filtert `offersTerm`.
- Router: alle `/settings/...`-Routen aus E18-11 im Profil-Tab (Platzhalter-Screens einhängen, `?row=` →
  `RowHighlightScope`), `/diet-preferences` als Alias auf `/settings/diet`, `/profile` und `/settings` zeigen die Wurzel.
  B's Routenlisten (`offersSettingsRoutes` …) bleiben eingehängt.
- Avo-Schlüssel (Regel 3): welche Zeile welchen Schlüssel in `AvoSettingsBridge` braucht und welche Schlüssel auf
  unsichtbare Einstellungen zeigen, als Tabelle in den Bericht (Datei gehört B).

## Teil „Seiten“

Dateien: `lib/presentation/screens/profile/settings/**` (außer `settings_search_entry.dart`), neue Komponenten
`lib/presentation/widgets/design/picker_row.dart` (E18-04 `PickerRow`, `MenuValueRow`),
`lib/presentation/widgets/design/chip_section.dart` (E18-05), `lib/presentation/widgets/design/in_app_browser_page.dart`
(E18-08), Tests unter `test/screens/profile/settings/` und `test/presentation/widgets/design/` (nur deine neuen).
Texte: `lib/core/localization/translations/settings_pages.dart` (`settingsPagesEn/De`, Präfix `setp_`).

- Konzept §5.1–5.9, §10.2/10.3, §11.2–11.4, K18-05, K18-06, K18-07, E18-04, E18-05, E18-08.
- Die Platzhalter füllen (Konstruktoren bleiben). Module (Zeilen aus `moduleDescriptors`, `released: false` nie
  zeigen, wirkt sofort über `appModulesProvider`), Ernährung & Allergien (Allergien zuerst, Chips in `ChipSection`,
  „Rezepte automatisch anpassen“), Persönliche Daten (`PickerRow` statt Slider), Listen, Mitteilungen (Kategorien und
  Uhrzeiten, iOS-Erlaubnis am Ort), Darstellung, Sprache, Hilfe (mit „Tipps zurücksetzen“, Support-Mail, Fehler
  melden), Rechtliches mit Datenquellen und `LegalDocumentScreen` im In-App-Browser (K18-15).
- Alte Screens in `settings/` (`app_priorities_screen`, `diet_preferences_screen`, `help_support_screen`,
  `language_screen`, `notifications_screen`, `personal_info_screen`, `theme_customization_screen`,
  `widgets/multi_select_settings_screen`) **nicht löschen**, solange etwas darauf zeigt; im Bericht nennen, was entfallen
  kann (Ausnahme: `display_name_screen.dart` gehört Teil „Konto“).
- Sucheinträge aller Seiten und Zeilen in `settingsPagesSearchEntries`; jede Zeile in `HighlightableRow`.
- Was Server oder B braucht (`user_notification_prefs`, `users.share_presence`, `users.language`, Avo-Schlüssel), als
  Entwurf bzw. Signatur in den Bericht.

## Teil „Konto“

Dateien: `lib/presentation/screens/profile/account/**`, `lib/presentation/screens/profile/settings/display_name_screen.dart`
(entfällt nach `ProfileEditScreen`), Tests unter `test/screens/profile/account/`. Texte:
`lib/core/localization/translations/settings_account.dart` (`settingsAccountEn/De`, Präfix `acct_`).

- Konzept §4 (Profil bearbeiten: Avatar mit Menü Foto auswählen/aufnehmen/entfernen mit Widerrufen, Name übernimmt bei
  Return und beim Verlassen, 2–40 Zeichen, E-Mail nur lesbar), §7.1 (Konto, Anmeldeweg, Passwort festlegen/ändern über
  die A7-Bausteine `ResetPasswordScreen`/`authGatewayProvider`), §7.2 (Abmelden: Alert nur bei ungesendeten Änderungen;
  löscht kontogebundene lokale Werte, Darstellung und Sprache bleiben, K18-09), §7.3 (Konto löschen: erneute Anmeldung,
  Zusammenfassung aus echten Zahlen, Übergabe geteilter Listen, Alert am Ende), §11.5, §11.9, §11.10.
- Konto löschen braucht die Edge Function `delete-account` (E18-09), die es nicht gibt: Oberfläche komplett bauen, den
  Aufruf hinter einer Schnittstelle (`AccountDeletionService` o. ä.) mit Fake im Test; Entwurf der Funktion (Ablauf,
  Tabellen, Transaktion, Apple-Token widerrufen) in den Bericht.
- Foto: vorhandenen Upload-Weg nutzen (Bucket `profile-pictures`); signierte URLs (E18-13) als Server-Wunsch.
- Sucheinträge in `accountSearchEntries`; Zeilen in `HighlightableRow`.

## Qualität (alle)

- Jeder neue Screen/jede neue Komponente mit Test: `layoutMatrix` (Breiten 320–440, Schrift bis 3,1×, fett, dunkel,
  Kontrast) und Verhaltenstests. Supabase/Provider im Test über `ProviderScope(overrides:)` und Fakes.
- Zustände nach §3.6: lokaler Stand sofort (kein Skelett, keine springenden Zahlen), offline `StatusRow`, Fehler mit
  „Erneut versuchen“, Modul aus, Kill-Switch.
- Einstellungen wirken sofort (Regel 2), kein Speichern-Knopf; Endgültiges mit Alert, Umkehrbares mit Widerrufen (Regel
  8); keine Haptik bei Zeilen (§3.7). VoiceOver, 44-pt-Ziele, Reduce Motion, Dunkelmodus, DE/EN kurz und konkret.

## Bericht (deine letzte Antwort)

1. Geänderte/neue/gelöschte Dateien. 2. Was jetzt wie aussieht und funktioniert (kurz). 3. Letzte Zeile von
`flutter test` (je Datei) und `dart analyze`. 4. Abweichungen von D2/Konzept mit Grund; nötige Änderungen an fremden
Dateien (genau, mit Signatur); Server-Entwürfe; offene Punkte; alte Dateien, die entfallen können.
