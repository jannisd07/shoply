# Inventar: Profil, Einstellungen und Abo (Ist-Zustand, Stand 2026-11-07)

Grundlage für das Redesign. Nur gelesen, kein Code geändert. Zeilenangaben beziehen sich auf den Stand von `main` (3e886d0).

Kurzfassung: Der vierte Tab (`/profile`) ist heute eine Paper-Einstellungsseite mit dem Titel „Einstellungen“: Profilkarte mit drei Zählern, Premium-Karte, drei Gruppen (Konto, Einstellungen, Support) und ein Abmelden-Button. Von dort führen acht Unterseiten per `Navigator.push` weiter, alle mit derselben Paper-Kopfzeile (Serifentitel, runder Zurück-Knopf, Terrakotta-Speichern-Pille). Die Paywall ist ein Vollbild-Screen mit Kicker, Serifen-Headline, vier Versprechen, zwei Preis-Karten und einem Ink-Button. Das Abo-System funktioniert technisch, aber: Es ist nur eine einzige Funktion gesperrt (Kochmodus), die Paywall verspricht vier andere Dinge, darunter Angebote (laut Plan verboten). Es gibt **keine Möglichkeit, das Konto zu löschen**, und **Allergien lassen sich nirgends in der Oberfläche eintragen**, obwohl Rezepte und Avo sie auswerten. Ein Achievements-Service existiert nicht.

---

## 1. Dateien

| Pfad | Rolle | Zeilen |
|---|---|---|
| `lib/presentation/screens/profile/profile_screen.dart` | Tab 4 (`/profile`): Profilkarte, Premium-Karte, Gruppen Konto / Einstellungen / Support, Abmelden, Datenquellen-Sheet | 811 |
| `lib/presentation/screens/profile/settings/display_name_screen.dart` | Profil bearbeiten: Profilbild (Galerie, Kamera, entfernen), Anzeigename | 364 |
| `lib/presentation/screens/profile/settings/personal_info_screen.dart` | Persönliche Daten: Alter, Größe (cm/ft), Geschlecht, PLZ für Angebote | 346 |
| `lib/presentation/screens/profile/settings/diet_preferences_screen.dart` | Ernährung (12 Diät-IDs, „keine Einschränkung“), Hülle um MultiSelect | 35 |
| `lib/presentation/screens/profile/settings/app_priorities_screen.dart` | „Was dir wichtig ist“ (5 Prioritäten, sortieren nur Startseiten-Karten), Hülle um MultiSelect | 30 |
| `lib/presentation/screens/profile/settings/widgets/multi_select_settings_screen.dart` | Generische Checklisten-Seite, schreibt eine String-Array-Spalte von `users` | 256 |
| `lib/presentation/screens/profile/settings/theme_customization_screen.dart` | Darstellung: Hell / Dunkel / System | 112 |
| `lib/presentation/screens/profile/settings/notifications_screen.dart` | Mitteilungen: Hauptschalter + 8 Kategorien in 4 Gruppen | 266 |
| `lib/presentation/screens/profile/settings/language_screen.dart` | Sprache: System / Deutsch / English | 125 |
| `lib/presentation/screens/profile/settings/help_support_screen.dart` | Hilfe: 4 FAQ (aufklappbar), Kontakt (Mail, Fehler melden, Bewerten), Ressourcen (Anleitung, Datenschutz, AGB), Version | 400 |
| `lib/presentation/widgets/common/paper_settings.dart` | Geteilte Paper-Bausteine: `PaperSettingsAppBar`, `PaperCircleIconButton`, `PaperSaveButton`, `PaperSectionHeader` (Kicker), `paperFieldDecoration` | 165 |
| `lib/presentation/screens/subscription/subscription_screen.dart` | Paywall `SubscriptionScreen` + `showSubscriptionSheet()` + `_PlanCard` | 511 |
| `lib/data/services/subscription_service.dart` | StoreKit über `in_app_purchase`, Produkt-IDs, Status-Stream, Kauf, Wiederherstellen, Konto-Abgleich über RPC `activate_subscription`, Cache in SharedPreferences | 497 |
| `lib/presentation/providers/subscription_provider.dart` | `subscriptionStatusProvider`, `isSubscribedProvider`, `subscriptionProductsProvider`, `subscriptionErrorProvider`, `subscriptionNotifierProvider` | 113 |
| `lib/data/services/theme_service.dart` | Liest/schreibt `user_preferences` (theme_mode, theme_variant, accent_color) | 101 |
| `lib/presentation/state/theme_provider.dart` | `themeModeProvider` (lokal zuerst, dann Konto), `accentColorProvider`, `userPreferencesProvider` | 142 |
| `lib/presentation/state/language_provider.dart` | `languageProvider` (nur SharedPreferences, kein Server-Sync) | 59 |
| `lib/presentation/state/calorie_tracking_provider.dart` | `calorieTrackingEnabledProvider` (Kalorien-Tab an/aus; lokal + `nutrition_goals`) | 57 |
| `lib/data/services/notification_preferences_service.dart` | Hauptschalter (`users.notification_enabled` + Cache + FCM-Token), Kategorien nur lokal | 164 |
| `lib/data/services/profile_picture_service.dart` | Upload/Löschen im Bucket `profile-pictures` (öffentliche URL), räumt altes Bild weg | 80 |
| `lib/core/constants/legal_links.dart` | Datenschutz, Impressum, AGB, Anleitung, Support-Mail | 11 |
| `lib/core/constants/diet_preferences.dart` | `kDietPreferenceIds` (12 IDs), geteilt mit Onboarding | 18 |
| `lib/core/constants/app_priorities.dart` | `kAppPriorities` (5 IDs mit Material-Icons), geteilt mit Onboarding | ca. 25 |
| `lib/data/models/user_model.dart` | `UserModel` (u. a. `age`, `height`, `heightUnit`, `gender`, `dietPreferences`, `allergies`, `appPriorities`, `notificationEnabled`, `language`, `theme`) | ca. 170 |
| `lib/data/models/user_preferences_model.dart` | `UserPreferencesModel` (themeMode, themeVariant, accentColor; `isAdvancedTheme` als vorgesehene Premium-Grenze, ungenutzt) | 145 |
| `lib/data/services/avo_settings_bridge.dart` | Avo kann 12 Einstellungen setzen (theme_mode, accent_color, language, notifications, display_name, diet_preferences, allergies, age, gender, height, calorie_tracking, zip_code) | – |
| `database/migrations/premium_subscription_system.sql` | Tabellen/RPCs für Abo (`activate_subscription`, `expire_subscriptions`) | – |
| Achievements | **Kein `achievements_service` vorhanden.** Nur Tabellen `achievement_definitions` / `user_achievements` in `database/migrations/new_recipe_features.sql:84-130`. Kein Dart-Code liest oder zeigt sie (`grep -ri achievement lib` = 0 Treffer). | – |
| Legal-Screens | **Kein Ordner `screens/legal/`.** Datenschutz, Impressum, AGB, Anleitung öffnen externe URLs im Browser. | – |

---

## 2. Screens, Sheets und Dialoge

### 2.1 Profil-Tab „Einstellungen“ (`ProfileScreen`)
- **Datei:** `profile_screen.dart`
- **Route/Einstieg:** Tab 4 der Shell (`/profile`, `app_router.dart:277`), Tab-Icon „user“ in der Pille; außerdem Avatar-Tipp auf der Startseite (`home_screen.dart:264`, `context.go('/profile')`).
- **Hauptfrage heute:** unklar, eine Mischung aus „Wer bin ich?“ und „Wo stelle ich etwas um?“. Titel sagt „Einstellungen“, der Tab ist das Profil.
- **Aufbau von oben nach unten:**
  1. Serifen-Titel „Einstellungen“ 30 pt (`:116-119`).
  2. Profilkarte (`:322-551`): Avatar 56 pt (Bild oder Initiale auf Creme), Name in Serif 19, darunter „Premium“ in Akzentfarbe ODER E-Mail, Chevron. Darunter Trennlinie und drei Zähler „Einkäufe / Listen / gespeichert“ (Serif 19 + 9,5-pt-Großbuchstaben-Label). Tipp öffnet `DisplayNameScreen`.
  3. Premium-Karte (`:675-790`): „Avo Premium“ + „14 Tage kostenlos, dann 2,99 €/Monat“ + Terrakotta-Pille „Testen“ → Paywall. Abonniert: „Avo Premium“ + „Willkommen bei Avo Pro!“ + Salbei-Haken.
  4. Kicker „KONTO“: Persönliche Daten, Ernährung & Allergien.
  5. Kicker „EINSTELLUNGEN“: Darstellung, Mitteilungen, Sprache (rechts „Deutsch“/„English“), Was dir wichtig ist, Kalorien-Tracking (Schalter, kein Chevron).
  6. Kicker „SUPPORT“: Hilfe & Support, Tutorial neu starten, Datenschutz (extern), Impressum (extern), Datenquellen (Sheet), App-Version „1.0.0“.
  7. Abmelden: umrandeter roter Button, 52 pt hoch (`:283-315`).
- **Komponenten:** eigene `_buildSettingsGroup` (Zeilen mit Material-Icon 17 pt, Text 14 pt, 1-pt-Trennlinie, `GestureDetector`), `_SettingsItemData`, `Switch.adaptive`, `CachedNetworkImage`.
- **Zustände:** Laden = graue Platzhalterbalken in der Profilkarte (`:472-514`); Fehler = „?“ + „Nutzer“ (`:515-547`); Zähler zeigen 0, solange die Provider laden. Offline: kein eigener Zustand (globales Offline-Banner der Shell). Pro gesperrt: nicht relevant. Modul aus: Kalorien-Schalter blendet den Kalorien-Tab aus.
- **Aktionen/Gesten:** Tipp auf Zeilen (Haptik `selectionClick` bei jeder Zeile, auch der nicht tippbaren Version), Schalter, Abmelden (Haptik medium, **ohne Rückfrage**), Tutorial neu starten (setzt `users.tutorial_completed=false`, springt nach `/home`, SnackBar).
- **Datenquellen:** `currentUserProvider`, `isSubscribedProvider`, `listsNotifierProvider`, `shoppingHistoryProvider`, `savedRecipesProvider`, `languageProvider`, `calorieTrackingEnabledProvider`, `DynamicTutorialService`, `SupabaseService.signOut`, `LegalLinks`.
- **Sichtbare Texte (DE):** „Einstellungen“, „Konto“, „Einstellungen“ (zweimal, siehe 3.6), „Support“, „Persönliche Daten“, „Ernährung & Allergien“, „Darstellung“, „Mitteilungen“, „Sprache“, „Kalorien-Tracking“, „Tutorial neu starten“, „Datenschutz“, „Impressum“, „Datenquellen“, „App-Version“, „Abmelden“, „Avo Premium“, „Testen“.

### 2.2 Sheet „Datenquellen“
- **Datei:** `profile_screen.dart:40-85`, `showModalBottomSheet`.
- **Einstieg:** Zeile „Datenquellen“.
- **Hauptfrage:** Woher kommen Preise, Märkte, Angebote?
- **Aufbau:** Griff, Serif-Titel 20, Fließtext 13 pt sekundär (`data_sources_body`: Open Prices/Open Food Facts ODbL, OpenStreetMap ODbL, marktguru, Hinweis „können veraltet sein“).
- **Pflicht:** ODbL-Namensnennung muss dauerhaft erreichbar bleiben (Kommentar `:261-265`). Inhaltlich gehört der Text zum Angebots-Modul (Teil B).

### 2.3 Profil bearbeiten (`DisplayNameScreen`)
- **Datei:** `display_name_screen.dart`
- **Einstieg:** Tipp auf Profilkarte, `CupertinoPageRoute` auf dem Branch-Navigator.
- **Hauptfrage:** Wie heiße ich und wie sehe ich aus?
- **Aufbau:** Kopfzeile „Profil“ + Speichern-Pille; Avatar 100 pt (`CircleAvatar` mit `NetworkImage`, Creme-Fläche, Serif-Initiale 34), „Profilbild ändern“; Kicker „WIE MÖCHTEST DU GENANNT WERDEN“, Hinweis „wird anderen angezeigt“, Textfeld.
- **Zustände:** Name lädt nachträglich, wenn der Nutzer noch nicht geladen ist (`:28-39`); Upload = Spinner im Avatar; Validierung leer / unter 2 Zeichen; Fehler = SnackBar mit roher Exception `'Error: $e'` (`:65`, `:223`, `:242`).
- **Aktionen:** Avatar-Tipp öffnet Dialog 2.4; Speichern → `authService.updateDisplayName`, `invalidate(currentUserProvider)`, zurück.
- **Daten:** `currentUserProvider`, `authServiceProvider`, `ProfilePictureService`, `image_picker` (max. 512 px).

### 2.4 Dialog „Profilbild ändern“
- **Datei:** `display_name_screen.dart:73-155`, Material-`Dialog`.
- **Aufbau:** Serif-Titel, Zeilen „Aus Galerie wählen“, „Foto aufnehmen“, ggf. „Foto entfernen“ (systemRed), „Abbrechen“ rechts unten als Text.
- **Hinweis:** Auf iOS wäre das ein Action Sheet / Menü vom Avatar aus. „Foto entfernen“ wirkt sofort und endgültig (Storage-Datei wird gelöscht), ohne Rückgängig.

### 2.5 Persönliche Daten (`PersonalInfoScreen`)
- **Datei:** `personal_info_screen.dart`
- **Einstieg:** Zeile „Persönliche Daten“.
- **Hauptfrage:** Welche Körper- und Ortsdaten nutzt die App für mich?
- **Aufbau:** Kopfzeile, Speichern-Pille erscheint erst nach Änderung; Kicker ALTER + Feld (Suffix „Jahre“); Kicker GRÖSSE + Radio cm/FT + Feld; Kicker GESCHLECHT + 4 Zeilen (männlich, weiblich, divers, keine Angabe) mit Haken; Kicker POSTLEITZAHL (FÜR ANGEBOTE IN DER NÄHE) + Feld (5 Ziffern) + Hinweis; Fließtext „Hilf uns, dein Erlebnis zu personalisieren“.
- **Zustände:** Laden ohne Anzeige (Felder füllen sich nachträglich); Fehler beim Laden/Speichern = SnackBar „generic_error“; kein Hinweis auf ungespeicherte Änderungen beim Zurückgehen.
- **Daten:** `currentUserProvider` (age, height, heightUnit, gender) → `users`; PLZ über `UserLocationService` (nur SharedPreferences, `user_location_service.dart:106-119`), danach `invalidate(userZipCodeProvider)`.
- **Abhängigkeit:** PLZ gehört fachlich zum Angebots-Modul (Teil B, Seite „Preise & Angebote“). Alter/Größe/Geschlecht speisen Kalorien-Ziele (Teil B).

### 2.6 Ernährung (`DietPreferencesScreen`) und „Was dir wichtig ist“ (`AppPrioritiesScreen`)
- **Dateien:** `diet_preferences_screen.dart`, `app_priorities_screen.dart`, beide über `multi_select_settings_screen.dart`.
- **Einstieg:** Profil-Zeilen; Ernährung zusätzlich über GoRouter `/diet-preferences` (`app_router.dart:337`), aufgerufen aus dem Tutorial-Abschluss (`tutorial_overlay.dart:362-376` → `NavigationService.navigateToDietPreferences`).
- **Hauptfrage:** Was esse ich nicht? / Was ist mir an der App wichtig?
- **Aufbau:** Kopfzeile + Speichern-Pille (immer sichtbar); optional Hinweis; „N ausgewählt“; Kicker; Checkliste (Titel 15, Untertitel 13, Kreis-/Häkchen-Icon 21); bei Ernährung zusätzlich Kicker „SONSTIGES“ + „Keine Einschränkungen / Ich esse alles“.
- **Ernährungs-IDs:** vegetarian, vegan, gluten_free, dairy_free, pescatarian, keto, paleo, low_carb, halal, kosher, nut_free, low_sodium.
- **Prioritäten-IDs:** save_money, share_lists, eat_healthier, discover_recipes, stay_organized (nur Reihenfolge der Startseiten-Karten).
- **Zustände:** Laden unsichtbar (Haken erscheinen nachträglich); Speichern = Spinner in der Pille, Erfolg = zurück ohne Rückmeldung; Fehler = SnackBar.
- **Daten:** schreibt direkt `users.diet_preferences` bzw. `users.app_priorities` per Supabase-Update, `invalidate(currentUserProvider)`.
- **Lücke:** Die Profil-Zeile heißt „Ernährung & Allergien“, die Seite bearbeitet aber nur `diet_preferences`. `users.allergies` hat keine Oberfläche (siehe 4.2).

### 2.7 Darstellung (`ThemeCustomizationScreen`)
- **Datei:** `theme_customization_screen.dart`
- **Hauptfrage:** Hell, dunkel oder wie das System?
- **Aufbau:** Kicker THEMA, drei Zeilen mit Untertitel und Haken (Hell, Dunkel, System). Keine Vorschau, keine Akzentfarbe, keine App-Icon-Wahl.
- **Daten:** `themeModeProvider` (SharedPreferences + `user_preferences.theme_mode`). Standard ist **Hell** (`theme_provider.dart:33`), nicht System.

### 2.8 Mitteilungen (`NotificationsScreen`)
- **Datei:** `notifications_screen.dart`
- **Hauptfrage:** Wann darf die App mich stören?
- **Aufbau:** Hauptschalter „Alle Mitteilungen“ + Beschreibung; darunter (bei Aus 40 % Deckkraft, nicht bedienbar) Gruppen: AVO (Nachkauf-Erinnerungen), LISTEN (Artikel hinzugefügt, Einkauf erledigt, Einladungen), REZEPTE (Likes, Kommentare, neue Rezepte von Gefolgten), ALLGEMEIN (Wochenzusammenfassung).
- **Zustände:** Vollbild-Spinner beim Laden (`:88-89`), danach Hintergrund-Sync des Hauptschalters vom Server.
- **Aktionen:** Schalter; Hauptschalter und Avo-Kategorie stellen Avo-Erinnerungen neu (`MascotNotificationService.rearm*`).
- **Daten:** `NotificationPreferencesService` (Hauptschalter in `users.notification_enabled` + FCM-Token entfernen/anlegen; Kategorien nur lokal in SharedPreferences).
- **Fehlt:** Status der iOS-Berechtigung (Schalter können „an“ zeigen, obwohl iOS Mitteilungen verbietet), Link in die iOS-Einstellungen, Uhrzeiten für Erinnerungen.

### 2.9 Sprache (`LanguageScreen`)
- **Datei:** `language_screen.dart`
- **Aufbau:** Beschreibung, Kicker SPRACHE, drei Zeilen (System mit Untertitel, Deutsch, English), Haken.
- **Daten:** `languageProvider` (nur lokal, `users.language` wird nicht geschrieben).

### 2.10 Hilfe & Support (`HelpSupportScreen`)
- **Datei:** `help_support_screen.dart`
- **Hauptfrage:** Wo bekomme ich Hilfe?
- **Aufbau:** Kicker FAQ + 4 aufklappbare Fragen (Liste erstellen, teilen, Auto-Kategorisierung, Verlauf löschen); Kicker KONTAKT: E-Mail-Support (mailto mit Betreff „Avo Support“), Fehler melden (Dialog nur mit Text, ohne Aktion), App bewerten (Vor-Dialog, dann StoreKit-Review); Kicker RESSOURCEN: Anleitung, Datenschutz, AGB (extern); Fußzeile „Avo  v1.0.0“ in Serif.
- **Dialoge:** `_showModal` (Material-Dialog, Serif-Titel, Text-Buttons).

### 2.11 Paywall (`SubscriptionScreen`)
- **Datei:** `subscription_screen.dart`
- **Einstieg:** `showSubscriptionSheet(context)` = `MaterialPageRoute(fullscreenDialog: true)` auf dem nächstgelegenen Navigator (`:504-511`). Aufrufer: Profil-Premium-Karte (`profile_screen.dart:739`), Kochmodus-Button für Nicht-Abonnenten (`recipe_detail_screen.dart:1026`). Keine weiteren Einstiege.
- **Hauptfrage:** Lohnt sich Pro für mich, und was kostet es?
- **Aufbau:** Kopfzeile mit X (links, 24-pt-Icon) und „Käufe wiederherstellen“ (rechts, 13 pt, tertiär); Kicker „AVO PREMIUM“ in Akzentfarbe; Serif-Headline 28 „Mehr aus jedem Einkauf.“; vier Haken-Zeilen („Unbegrenzt geteilte Listen“, „Avo plant Rezepte und Wochen“, „Angebote deiner Märkte“, „Einkaufs-Statistiken“); zwei Plan-Karten nebeneinander (Jährlich mit Badge „BESTE WAHL“ und Monatspreis, Monatlich mit „jederzeit kündbar“); Ink-Pille „14 Tage gratis testen“ 54 pt; Fußnote „Danach {Preis}/Jahr · Kündigung in den iPhone-Einstellungen“; AGB-Hinweis 11 pt.
- **Zustände:** Produkte laden/Fehler = Spinner + „Lade Abo-Optionen...“ + „Erneut versuchen“ (kein Fehlertext, `:143-146`, `:268-299`); Kauf läuft = Spinner im Button; Erfolg = schließt mit `pop(true)`; Abbruch = Spinner aus; Fehler = rote SnackBar mit StoreKit-/Exception-Text; Wiederherstellen = grüne bzw. orange SnackBar. Kein Zustand „bereits Pro“, kein Zustand „Testphase schon genutzt“.
- **Daten:** `subscriptionProductsProvider`, `subscriptionNotifierProvider`, `subscriptionErrorProvider`, `isSubscribedProvider`, `SubscriptionService.retryLoadProducts`.
- **Produkte:** `shoply_premium_monthly`, `shoply_premium_yearly` (`subscription_service.dart:8-15`). Preise kommen live aus StoreKit, außer in `premium_trial_line` (fest „2,99 €/Monat“).

### 2.12 Weitere Pro-Flächen außerhalb des Bereichs
- **Kochmodus-Sperre:** `recipe_detail_screen.dart:985-1040`. Einzige echte Pro-Sperre der App. Abonnenten: Button „Kochen starten“ öffnet `CookingModeScreen`; sonst gleicher Button mit Schloss, öffnet Paywall.
- **Pro-Abzeichen im Avo-Chat-Kopf:** `avo_chat_widgets.dart:379-391` (Paper-Pille „Premium“, nur Anzeige).
- **Profilkarte:** „Premium“ statt E-Mail (`profile_screen.dart:398-406`).
- `grep -rn "isPremium" lib` liefert **0 Treffer**. Die Prüfung heißt `isSubscribedProvider` bzw. `SubscriptionService.isSubscribed`.

---

## 3. Design-Probleme heute

### 3.1 Paper-Reste (Serifen, Kicker, Creme/Terrakotta)
- Serifen (`PaperTextStyles.serif`, Georgia): `profile_screen.dart:67, 118, 395, 559, 701, 751`; `display_name_screen.dart:96, 300`; `help_support_screen.dart:123, 261`; `subscription_screen.dart:132, 455`; `paper_settings.dart:50` (Titel jeder Unterseite).
- Großbuchstaben-Kicker mit Laufweite: `profile_screen.dart:580-593` (Gruppenköpfe 10 pt, letterSpacing 2), `:565-571` (Zähler-Labels 9,5 pt), `paper_settings.dart:136-156` (`PaperSectionHeader`, auf allen Unterseiten), `subscription_screen.dart:120-128` („AVO PREMIUM“), `:240` + `:486-492` (Badge „BESTE WAHL“ 9 pt), `personal_info_screen.dart:297` („CM“/„FT“).
- Creme/Terrakotta/Salbei/Ink: `profile_screen.dart:372` (Avatar Creme), `:680-683` (PaperColors.surface/hairline), `:721-727` (Salbei-Haken), `:773` (Terrakotta-Pille); `display_name_screen.dart:291, 304`; `paper_settings.dart:80` (Creme-Kreis-Button), `:118, 125` (paper-Text); `subscription_screen.dart:319-334` (Ink-Button); `avo_chat_widgets.dart:326, 382-389`. Globale Akzentfarbe ist Terrakotta (`app_colors.dart:69, 72`).
- Rote Abmelden-Umrandung mit Paper-Danger und hartem Hex für Dunkel (`profile_screen.dart:297-308`).

### 3.2 Abweichungen von Apple-Mustern
- Keine gruppierten, eingerückten Listen (iOS-Einstellungen-Muster); stattdessen nackte Zeilen mit 1-pt- bzw. 0,5-pt-Linien (`profile_screen.dart:664-668`, alle Unterseiten). Gruppen nur über Kicker getrennt.
- Material-Icons statt SF Symbols in allen Zeilen (`profile_screen.dart:137-273`, `app_priorities.dart:18-22`, `paper_settings.dart:37`, `subscription_screen.dart:88, 194`).
- Kein Large Title, der beim Scrollen in die Leiste wandert; Kopfzeile fest 56 pt mit Serif (`paper_settings.dart:24`). Kein Scroll-Edge-Effekt, Zurück-Knopf ist ein Creme-Kreis statt Glas-Button.
- `GestureDetector` statt Buttons: kein Druckzustand, keine Button-Semantik für VoiceOver (`profile_screen.dart:283, 329, 610`; alle Unterseiten; Paywall `:86, 93, 311`; `_PlanCard :423`).
- Material-Dialoge statt Action Sheet/Menü (`display_name_screen.dart:80-154`, `help_support_screen.dart:245-317`); Material-SnackBars mit Rot/Grün/Orange (`subscription_screen.dart:57, 383, 391`).
- Explizites Speichern in Einstellungen (Speichern-Pille) statt sofortiger Übernahme (`personal_info_screen.dart:134-139`, `multi_select_settings_screen.dart:135-139`, `display_name_screen.dart:264-268`). Uneinheitlich: Darstellung, Sprache, Mitteilungen speichern sofort.
- Paywall als `MaterialPageRoute(fullscreenDialog)` (`subscription_screen.dart:505-510`) statt iOS-Sheet; keine Links zu AGB/Datenschutz in der Paywall (App-Store-Richtlinie 3.1.2 verlangt sie), kein „Abo verwalten“.
- Zwei Schalter-Arten gemischt: `Switch.adaptive` (`profile_screen.dart:202`) und `CupertinoSwitch` (`notifications_screen.dart:250`).
- Feste Dauern statt Federn: `AnimatedOpacity 250 ms` (`notifications_screen.dart:116`), `AnimatedRotation/CrossFade 200 ms` (`help_support_screen.dart:368, 393`), `AnimatedContainer 180/200 ms` (`subscription_screen.dart:314, 429`). Kein Reduce-Motion-Zweig.
- Haptik bei jeder Zeile, auch bei der nicht tippbaren Versionszeile (`profile_screen.dart:611-613` mit `onTap: null` bei `:271-276`), Haptik `lightImpact` auf jedem Zurück (`paper_settings.dart:39`).
- Sichtbares Laden: Vollbild-Spinner Mitteilungen (`notifications_screen.dart:88-89`), Spinner Paywall-Preise (`subscription_screen.dart:273`), Skelett-Balken Profilkarte (`profile_screen.dart:472-514`).
- Wayfinding: Tab heißt Profil (Icon „user“), Seitentitel „Einstellungen“ (`profile_screen.dart:117`); im Deutschen heißt auch die zweite Gruppe „Einstellungen“ (`app_translations.dart:2033` und `:2035`). Zwei identische Überschriften auf einem Screen.
- Zähler „Einkäufe / Listen / gespeichert“ sind Vanity-Zahlen ohne Handlung (`profile_screen.dart:427-469`).
- Fließtext und Hinweise blassgrau statt voller Textfarbe (`personal_info_screen.dart:261-265`, `language_screen.dart:53-58`, `help_support_screen.dart:383-387`, `profile_screen.dart:73-79`).

### 3.3 Feste Größen, die bei großer Schrift oder 320 pt Breite brechen
Die App begrenzt Dynamic Type nicht (`grep textScaler lib` = 0 Treffer), Schrift wächst also voll mit. Feste Maße um Text herum brechen deshalb:
- `paper_settings.dart:24`: Kopfzeile fix 56 pt, Serif-Titel 20 pt ohne `maxLines` → Titel wird bei AX-Größen abgeschnitten; `PaperSaveButton` (`:104-130`) und Titel teilen sich die Zeile.
- `profile_screen.dart:293`: Abmelden-Button fix 52 pt hoch.
- `profile_screen.dart:447-451, 457-461`: senkrechte Trenner fix 30 pt; Zähler-Labels 9,5 pt mit `maxLines: 1` + Ellipse (`:565-574`), bei 320 pt Breite und großer Schrift werden „EINKÄUFE“/„GESPEICHERT“ abgeschnitten.
- `profile_screen.dart:367-369`: Avatar fix 56 pt, Name ohne `maxLines`/Ellipse in einer Zeile mit Chevron (`:393-396`): lange Namen umbrechen unkontrolliert.
- `profile_screen.dart:489-501`: Skelett-Balken fix 120/180 pt breit, bei 320 pt minus 2×24 Rand + Avatar sehr knapp.
- `profile_screen.dart:106-111`: Rand fest 24 pt (statt 16-20 pt bei 320 pt), unterer Abstand fest `120 + padding` statt `MainScaffold.getNavbarClearance` (die skaliert mit `navScale`). Ebenso `personal_info_screen.dart:148` und `display_name_screen.dart:278` (fest 100).
- `subscription_screen.dart:316`: CTA fix 54 pt hoch; `:230-264` zwei Plan-Karten nebeneinander: bei 320 pt Breite bleiben je ca. 126 pt; Preis in Serif 21 plus „29,99 €“ und Monatspreis-Zeile umbrechen bei großer Schrift; Badge mit `Positioned(top: -9)` (`:474-476`) überlappt den Kartenrand und kollidiert bei großer Schrift mit dem Label.
- `subscription_screen.dart:113`: Seitenrand 28 pt, bei 320 pt nur 264 pt Inhaltsbreite.
- Touch-Ziele unter 44 pt: X der Paywall 24 pt ohne Polster (`subscription_screen.dart:86-89`), „Käufe wiederherstellen“ 13-pt-Text ohne Polster (`:93-103`), Zurück-Kreis 34 pt (`paper_settings.dart:77-78`), Speichern-Pille ca. 28 pt hoch (`paper_settings.dart:110`), „Abbrechen“ im Profilbild-Dialog (`display_name_screen.dart:134-147`), cm/FT-Radios (`personal_info_screen.dart:276-305`), Einstellungszeilen ca. 43 pt (13 pt Polster + 14-pt-Text, `profile_screen.dart:617`).
- Feste Schriftgrößen überall (`fontSize: 9`–`30`) statt Text-Stilen des Systems; Dynamic Type wirkt nur über den Skalierungsfaktor, Hierarchie über Gewicht/Zeilenabstand fehlt.

---

## 4. Bugs, Risiken und Performance

### 4.1 Kein Konto löschen (App-Store-Pflicht)
- `grep -rni "delete.*account\|konto löschen" lib` = 0 Treffer. Apple verlangt seit 2022 (Richtlinie 5.1.1(v)) eine In-App-Kontolöschung, wenn man ein Konto anlegen kann. Fehlt komplett, inklusive Hinweis zum laufenden Abo.

### 4.2 Allergien ohne Oberfläche (Sicherheitsrisiko)
- Profil-Zeile „Ernährung & Allergien“ (`profile_screen.dart:146`) öffnet `DietPreferencesScreen`, die nur `diet_preferences` schreibt (`diet_preferences_screen.dart:16`).
- `users.allergies` wird gelesen von Rezepten (`recipe_user_diet.dart:9-13`, `recipes_home_widgets.dart:482`), Kalorien-Rezeptvorschlägen und Avo (`avo_assistant_service.dart:1249`), geschrieben aber nur über Avo (`avo_settings_bridge.dart:107-112`) und ggf. Onboarding.
- Avo-Wissen schickt Nutzer an die falsche Stelle (`avo_app_knowledge.dart:72`: „Profile → Settings → Dietary Preferences“).
- `nut_free` steckt als Diät-ID in der Ernährungsliste (`diet_preferences.dart:15`), echte Allergien (Nüsse, Laktose, Gluten) sind getrennt modelliert (`AllergyType`). Apple-Prinzip Responsibility verletzt.

### 4.3 Pro-Versprechen und Realität widersprechen sich
- Gesperrt ist nur der Kochmodus (`recipe_detail_screen.dart:986`).
- Paywall verspricht unbegrenzt geteilte Listen, Avo-Planung, **Angebote**, Statistiken (`app_translations.dart:504-507` / `:1673-1676`). Nichts davon ist gesperrt; Angebote als Pro sind laut Plan verboten.
- `AvoAppKnowledge` verspricht anderes: KI-Kategorisierung, unbegrenzter Chat, volle Rezeptsammlung, Nährwerte, eigene Themes, Priority Sync (`avo_app_knowledge.dart:28-30`), und „Profile → Premium“ als Pfad (`:34`).
- Ungenutzte Altschlüssel `premium_feature_*` (Kochmodus, KI-Essensplanung, keine Werbung, Priority Support, `app_translations.dart:974-983`).
- Name uneinheitlich: „Avo Premium“ (`profile_screen.dart:700, 750`, hart codiert), Label „Premium“, Erfolgsmeldung „Willkommen bei Avo Pro!“ (`app_translations.dart:990/2159`), Produkt-IDs `shoply_premium_*`.
- „14 Tage gratis testen“ wird immer gezeigt (`subscription_screen.dart:330`), auch wenn die Testphase schon genutzt wurde (keine Prüfung der Introductory-Offer-Berechtigung). `premium_trial_line` mit festem Preis „2,99 €“ bzw. „$2.99“ (`app_translations.dart:969/2138`) statt StoreKit-Preis: falsch in anderen Ländern.

### 4.4 Abo-Sicherheit (Umsatzrisiko)
- RPC `activate_subscription` ist laut Migration `SECURITY DEFINER` ohne `auth.uid()`-Prüfung und nimmt `user_uuid` und Ablaufdatum vom Client (`database/migrations/premium_subscription_system.sql:82-120`). Jeder angemeldete Client könnte sich (oder andere) Pro geben. Live-Datenbank prüfen, Migration könnte überholt sein.
- Keine Server-Belegprüfung: Ablauf wird im Client geraten (`subscription_service.dart:421-424`, 30 bzw. 365 Tage ab jetzt). Wiederherstellen behandelt auch abgelaufene Abos als neu gekauft (`:182-184`, Kommentar `:276-278`) und schenkt damit eine volle neue Laufzeit.
- Schlägt die RPC fehl, bleibt der lokale Status `subscribed` und wird mit geratenem Ablauf gecacht (`:211-222`, `:404-408`).
- Cache-Schlüssel `subscription_status` ist nicht an den Nutzer gebunden (`:56-57`); nach Kontowechsel gilt kurz der alte Status, bis `refreshStatusForCurrentUser` (`app.dart:85`) durch ist.
- Wiederherstellen wartet fest 2 s (`:290`) und rät dann.

### 4.5 Paywall-Ablauf
- Produkte laden fehlgeschlagen = ewig „Lade Abo-Optionen...“ (Fehler wird zu leerer Liste, `subscription_screen.dart:63-67`); kein erklärender Text, CTA bleibt ausgegraut.
- Fehlermeldungen roh an den Nutzer: `'Failed to load products: $e'`, `'Purchase failed: $e'` (`subscription_service.dart:163, 270`), englisch, in roter SnackBar (`subscription_screen.dart:53-61`).
- Paywall wird auf dem Branch-Navigator geöffnet (`Navigator.of(context)`, `:505`). Die Shell legt Tab-Pille und Avo-Orb per `Stack` über alles im Branch (`main_scaffold.dart:220-300`): Tab-Leiste und Avo-Orb liegen über der Paywall und über allen Einstellungs-Unterseiten; Tab-Wechsel bei offener Paywall möglich.
- X bleibt während Kauf/Wiederherstellen aktiv; `_isLoading` deckt Wiederherstellen und Kauf gemeinsam ab.

### 4.6 Einstellungen ohne Wirkung oder ohne Abgleich
- Akzentfarbe: `accentColorProvider` wird nirgends für die Darstellung gelesen; `AppColors.accentColor` liefert fest Terrakotta (`app_colors.dart:87-91`). Avo „ändert“ die Akzentfarbe (`avo_settings_bridge.dart:229-252`) ohne sichtbare Wirkung. `ThemeService` legt Standard `#2196F3` an (`theme_service.dart:44`), der Provider `#007AFF` (`theme_provider.dart:94`), das Model `#2196F3` (`user_preferences_model.dart:107`).
- `themeVariant` (true_black, high_contrast, warm, cool) und `isAdvancedTheme` als Premium-Grenze sind Altlast ohne UI (`user_preferences_model.dart:110-130`).
- Theme-Standard Hell statt System (`theme_provider.dart:33`). Theme liegt doppelt: `user_preferences.theme_mode` und `users.theme`.
- Sprache nur lokal (`language_provider.dart:42-54`), `users.language` bleibt veraltet; Zweitgerät startet in Systemsprache.
- Mitteilungs-Kategorien nur lokal pro Gerät (`notification_preferences_service.dart:79-84`); Remote-Pushes (Listen-Aktivität, Einladungen) achten nur auf den Hauptschalter (FCM-Token), nicht auf Kategorien. Kein Abgleich mit der iOS-Berechtigung.
- PLZ nur lokal (`user_location_service.dart:106-119`).
- Nach dem Abmelden bleiben gerätelokale Einstellungen (Kalorien-Schalter, Kategorien, PLZ, Theme, Sprache) für das nächste Konto stehen; `main.dart:136-165` räumt nur Kategorie-Cache, Offline-Cache, Erinnerungen und Widget-Daten.

### 4.7 Weitere Fehler
- Version hart „1.0.0“ (`profile_screen.dart:274`, `help_support_screen.dart:122`), tatsächlich `1.1.4+31` (`pubspec.yaml:5`).
- Rechtslinks auf zwei Domains (`joinavo.app` für Datenschutz/Impressum, `shoplyai.app` für AGB/Anleitung/Support-Mail, `legal_links.dart:6-10`), obwohl der Kommentar Einheitlichkeit verspricht.
- `canLaunchUrl` false = stilles Nichts (`profile_screen.dart:89`, `help_support_screen.dart:197, 204`), z. B. ohne Mail-App.
- Abmelden ohne Rückfrage und ohne Fehlerbehandlung (`profile_screen.dart:284-289`).
- Rohe Exceptions in SnackBars (`display_name_screen.dart:65, 223, 242`).
- Größe: Einheitenwechsel löscht den Wert statt umzurechnen (`personal_info_screen.dart:281`); „ft“ als Dezimalzahl („5.7“) ist mehrdeutig (Fuß/Zoll).
- Ungespeicherte Änderungen gehen beim Zurück ohne Hinweis verloren (Persönliche Daten, Profil, Ernährung, Prioritäten).
- „Fehler melden“ zeigt nur einen Text ohne Aktion (`help_support_screen.dart:209-215`). „Bewerten“ zeigt einen eigenen Vor-Dialog vor dem System-Review und markiert als bewertet, auch wenn iOS nichts anzeigt (`:217-231`).
- Profilbilder liegen in einem Bucket mit öffentlicher URL (`profile_picture_service.dart:30`): Bild ist ohne Anmeldung abrufbar.
- `DisplayNameScreen` nutzt `NetworkImage` ohne Cache (`display_name_screen.dart:293`), das Profil `CachedNetworkImage`: Bild lädt beim Öffnen sichtbar neu.
- Einstellungs-Unterseiten per `Navigator.push`, nicht über GoRouter: keine Deep Links (Avo, Siri, Mitteilungen können nicht direkt auf „Mitteilungen“ oder „Abo“ springen), außer `/diet-preferences`, und diese Route liegt außerhalb der Shell (anderer Navigator als der Profil-Weg).

### 4.8 Performance
- Profil-Tab lädt für einen Zähler die komplette Einkaufshistorie (`shoppingHistoryProvider`, `profile_screen.dart:429-430`, `shopping_history_provider.dart:12-19`), dazu Listen und gespeicherte Rezepte. Bei langer Historie teuer und sichtbar (Zähler springen von 0).
- `ref.watch(isSubscribedProvider)` innerhalb der Profilkarten-Closure und erneut in `_buildProBanner` (`profile_screen.dart:398, 677`): ganzer Screen baut bei Statuswechsel neu (gering).
- Mitteilungen: 9 einzelne `SharedPreferences.getInstance()`-Aufrufe nacheinander vor dem ersten Bild (`notifications_screen.dart:33-37`), dann Server-Sync.

---

## 5. Abhängigkeiten zu anderen Bereichen

| Was | Wo noch genutzt | Folge fürs Redesign |
|---|---|---|
| `paper_settings.dart` (`PaperSettingsAppBar`, `PaperSectionHeader`, `paperFieldDecoration`, `PaperSaveButton`) | `lists/list_settings_screen.dart`, `lists/category_order_screen.dart`, `lists/list_activities_screen.dart` | Ersatz-Komponente (gruppierte Liste, Kopfzeile) muss für Listen-Einstellungen mitgedacht werden; erst entfernen, wenn alle Nutzer umgestellt sind |
| `MultiSelectSettingsScreen`, `kDietPreferenceIds`, `kAppPriorities` | Onboarding (`onboarding_answers_service.dart`), Tutorial-Abschluss (`tutorial_overlay.dart:362-376`), Startseiten-Kartenreihenfolge (`home_nudge_card_order.dart`) | Gleiche Taxonomie in Onboarding und Profil behalten |
| `currentUserProvider` / `UserModel` | Fast überall (Startseite-Gruß, Rezepte, Avo, Kalorien) | Felder `allergies`, `dietPreferences`, `appPriorities`, `age`, `height`, `gender` nicht umbenennen |
| `isSubscribedProvider`, `showSubscriptionSheet` | Rezeptdetail (Kochmodus), Avo-Chat-Kopf | Neue Paywall muss dieselbe Einstiegsfunktion (oder einen Ersatz mit Kontext-Parameter) anbieten |
| `calorieTrackingEnabledProvider` | `main_scaffold.dart` (Kalorien-Tab), Onboarding, Avo-Bridge | Wird künftig Teil des Modulsystems (Plan: Module beim ersten Start wählen, in Einstellungen umschalten) |
| `NotificationPreferencesService`, `MascotNotificationService` | `NotificationService.showNotification`, `main.dart` Auth-Listener, FCM, Avo-Bridge | Kategorien müssen weiter durchgesetzt werden; neue Kategorien (Wochenplan, Kalorien, Angebote) kommen aus Teil B |
| `UserLocationService` / PLZ, `userZipCodeProvider` | Angebote, Preisvergleich, Startseite (Teil B) | PLZ wandert auf die Seite „Preise & Angebote“ (Teil B laut `arbeitsteilung.md`) |
| Datenquellen-Text (`data_sources_body`) | Angebote/Preise (Teil B) | Muss bei abgeschaltetem Angebots-Modul angepasst oder ausgeblendet werden, ODbL-Hinweis bleibt, solange Open-Prices-Daten gezeigt werden |
| `AvoSettingsBridge` (12 Einstellungsschlüssel), `AvoAppKnowledge` | Avo-Chat (Teil B) | Jede neue Einstellung braucht einen Bridge-Schlüssel; Wissenstexte (Pro, Pfade) müssen zum neuen Konzept passen |
| `themeModeProvider`, `languageProvider` | `app.dart` (MaterialApp), Avo-Bridge | Weiter zentral |
| `DynamicTutorialService.restartTutorial` | Tutorial-Overlay der Startseite | Tutorial wird durch neues Onboarding ersetzt (Teil A, Konzept 17) |
| `LegalLinks` | Profil, Hilfe, künftig Paywall und Onboarding | Eine Domain festlegen |
| Strings `app_translations.dart` (EN ca. Zeile 270-1000, DE ca. 1440-2170) | – | Doppelte/alte Schlüssel (`premium_feature_*`, `premium_kicker`, zweimal „Einstellungen“) aufräumen |
| `MainScaffold` (Tab-Pille, Avo-Orb, `getNavbarClearance`) | Alle Tabs | Neue Tab-Bar muss sich bei Unterseiten/Paywall korrekt verhalten |
| Supabase: `users` (Profil, Abo, `notification_enabled`), `user_preferences`, `subscription_transactions`, Bucket `profile-pictures`, RPC `activate_subscription`, Edge Function `expire-subscriptions` | Backend | Kontolöschung braucht Edge Function/RPC (Teil B oder Teil A klären) |

---

## 6. Was ein Redesign unbedingt erhalten muss

**Funktionen**
- Profil: Anzeigename (2+ Zeichen, für geteilte Listen sichtbar), Profilbild aus Galerie/Kamera, Profilbild entfernen, altes Bild wird im Storage aufgeräumt.
- Persönliche Daten: Alter, Größe mit Einheit cm/ft, Geschlecht inkl. „keine Angabe“ (Grundlage Kalorienziele).
- Ernährung: alle 12 Diät-IDs, „Keine Einschränkungen“ = leere Auswahl. Dazu **neu** eine echte Allergien-Auswahl auf `users.allergies` (Pflicht aus 4.2).
- Prioritäten (sortieren Startseiten-Karten, sperren nichts).
- Darstellung Hell/Dunkel/System (Standard künftig System), synchron über `user_preferences`.
- Sprache System/Deutsch/English.
- Mitteilungen: Hauptschalter (kontoweit, entfernt FCM-Token), acht Kategorien mit ihren Standardwerten (`newRecipes` standardmäßig aus), Avo-Erinnerungen neu planen bei Änderung.
- Kalorien-Tracking an/aus (künftig Modulschalter).
- Hilfe: FAQ, Support-Mail, Bewertung über StoreKit, Anleitung, Datenschutz, Impressum, AGB.
- Datenquellen-Hinweis (ODbL Open Prices/Open Food Facts, OpenStreetMap, marktguru) dauerhaft erreichbar.
- Tutorial/Einführung erneut ansehen (in neuer Form).
- Abmelden mit Aufräumen (Widget-Daten, Offline-Cache, Erinnerungen, Kategorie-Cache).
- Paywall: Monats- und Jahresabo mit live-Preisen aus StoreKit, Monatspreis-Umrechnung des Jahresabos, 14 Tage Test, Käufe wiederherstellen, Rückgabewert `true` bei Erfolg (Aufrufer reagieren darauf), Status über `isSubscribedProvider`.
- Pro-Kennzeichnung im Profil und an gesperrten Funktionen; Kochmodus-Sperre (bis der Owner Pro neu festlegt).

**Daten und Sonderfälle**
- Konto ist Quelle der Wahrheit für Pro (`users.subscription_status`/`subscription_expires_at`), kein stilles Restore beim Start (Kommentar `subscription_service.dart:86-90`), Kauf-Ausgang kommt asynchron über den Status-Stream, Abbruch muss den Spinner beenden.
- Hauptschalter für Mitteilungen ist kontoweit und auch per Avo setzbar; beim Anmelden zuerst vom Server holen, dann FCM-Token speichern.
- Kalorien-Schalter: lokal schnell, Server (`nutrition_goals.calorie_tracking_enabled`) gewinnt nach Anmeldung.
- Theme: lokale Wahl dieser Sitzung darf nicht vom Server-Wert überschrieben werden (`theme_provider.dart:37-56`).
- Alle 12 Avo-Bridge-Schlüssel müssen auf eine sichtbare Einstellung zeigen (heute tun das `accent_color` und `allergies` nicht).
- Zweisprachige Texte (DE/EN) für alles.

**Neu nötig (nicht vorhanden, aber Pflicht)**
- Konto löschen in der App, mit Hinweis, dass ein laufendes Abo über Apple gekündigt wird, und Link „Abos verwalten“.
- In der Paywall: Links zu AGB (EULA) und Datenschutz, korrekte Testphasen-Aussage je nach Berechtigung.
- Pro-Flächen, die für jedes Feature funktionieren (Paywall mit Kontext „du wolltest X“, Pro-Abzeichen, kontextueller Hinweis), weil der Owner erst später festlegt, was Pro wird; Angebote nie als Pro.
