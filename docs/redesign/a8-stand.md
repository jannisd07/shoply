# A8 Profil und Einstellungen: Ergebnis und offene Punkte (09.11.2026)

Auftrag: [`a8-auftrag.md`](a8-auftrag.md). Schnittstellen `8f67ca8`, `28d2463`; die Teile siehe
`git log --grep "Profil\|Einstellung\|Konto"`. Server-Entwürfe: [`a8-server-entwurf.sql`](a8-server-entwurf.sql).
Paywall und Pro-Flächen (Konzept 18 Kap. 8, 9) gehören zu A9.

Im Simulator (iPhone 17, 09.11.2026) angesehen: Profil-Wurzel (oben bis Fuß mit Version), Suche mit Sprung und
Hervorhebung, Ernährung & Allergien, Profil bearbeiten, Konto. Behoben danach: Profilfoto im Querformat war oben und
unten abgeschnitten (`523b3fd`), Suche zeigte Treffer der anderen Sprache vor denen der App-Sprache (`cb09597`). Nicht
angesehen: Module, Persönliche Daten, Listen, Mitteilungen, Darstellung, Sprache, Hilfe, Rechtliches, Abmelden, Konto
löschen (nur in Tests).

## Was jetzt da ist

- **Profil-Wurzel** (`profile_root_screen.dart`, Tab „Profil“ und `/settings`): Großtitel, Suchfeld, Kopfzeile Person
  (Foto 64 pt, Name, E-Mail → Profil bearbeiten), Pro-Zeile mit Status → `/pro`, Sektionen App / Module / Für dich /
  Allgemein / iPhone / Hilfe und Rechtliches / Konto mit Live-Werten, Fuß „Avo · Version …“ (`package_info_plus`).
  Keine Zähler, keine Premium-Karte, keine Paper-Optik. Kill-Switch: „Märkte“ statt „Preise & Angebote“.
- **Suche**: lokal, Deutsch und Englisch gleichzeitig, Umlaute gefaltet; Treffer mit Pfad; Push mit `?row=`, die Zeile
  leuchtet einmal auf (`RowHighlightScope`/`HighlightableRow`). Einträge: Seiten 52, Konto 11, Wurzel, B-Seiten
  (vorläufig nur Seiteneinträge in `bSettingsPagesSearchEntries`).
- **Seiten**: Module, Ernährung & Allergien (Allergien zuerst, gleiche Chips und Logik wie im Onboarding), Persönliche
  Daten (Rad in der Zeile statt Slider, ohne PLZ), Listen, Mitteilungen (iOS-Erlaubnis am Ort, Uhrzeiten), Darstellung,
  Sprache (schreibt wieder `users.language`), Hilfe (Fragen, Support-Mail, Fehler melden, Bewerten, Tipps
  zurücksetzen), Rechtliches mit Datenquellen und Lizenzen. Neue Komponenten `PickerRow`/`MenuValueRow`,
  `ChipSection`, `InAppBrowserPage`, Seitenrahmen `SettingsPage`.
- **Konto**: Profil bearbeiten (Foto auswählen/aufnehmen/entfernen mit Widerrufen, Name ohne Speichern-Knopf), Konto
  (E-Mail und Passwort bei E-Mail-Konten), Abmelden (Rückfrage nur bei ungesendeten Änderungen, kontogebundene lokale
  Werte gelöscht, Darstellung und Sprache bleiben), Konto löschen (Zusammenfassung, Übergabe geteilter Listen, erneute
  Bestätigung, Alert) hinter `AccountDeletionService`.
- Alte Einstellungsseiten, `display_name_screen.dart`, `profile_screen.dart` und `paper_settings.dart` sind gelöscht.

## Braucht den Owner

- **Konto löschen funktioniert erst mit der Edge Function `delete-account`** (Entwurf in `a8-server-entwurf.sql`):
  Übergabe geteilter Listen, Löschen in einer Transaktion, Apple-Token widerrufen.
- Server-Entwürfe: `user_notification_prefs` (Mitteilungs-Kategorien und Uhrzeiten im Konto, heute nur auf dem
  Gerät), `users.share_presence`, `users.auto_adapt_recipes`, RPC `account_has_password()`, `users.email` per Trigger
  mitführen, Profilfotos privat mit signierten URLs, Auth-Vorlage „Change Email Address“ mit `{{ .Token }}`.
- Eine Domain für Datenschutz, Impressum, Nutzungsbedingungen (heute `joinavo.app` und `shoplyai.app`, F18-06).
- Daten exportieren in der App oder per Support-Mail (F18-07).
- Pro-Zeile vollständig (Datum, Zahlung fehlgeschlagen, Familienfreigabe, Testphase genutzt) erst mit A9 und
  `verify-subscription` (E18-10).

## Von Teil B (angefragt)

- Routen `/settings/health`, `/settings/plan`, `/settings/avo`, `/settings/siri`, `/settings/widgets` (die Profilzeilen
  erscheinen von selbst, sobald die Route registriert ist und das Modul an ist).
- Eigene Suchliste statt `bSettingsPagesSearchEntries` (mit `module`, `offersTerm`, `killSwitchTitleKey`), und
  `RowHighlightScope(rowId: state.uri.queryParameters['row'])` in den Settings-Routen von B.
- `AvoSettingsBridge`: Schlüssel `module_<id>`, `recipes_auto_adapt`, `show_item_images`, `suggestions_enabled`,
  `start_list`, `keep_screen_on`, `share_presence`, Mitteilungs-Kategorien und -Uhrzeiten (über
  `notificationSettingsProvider`); `accent_color` streichen (K-06).
- `MascotNotificationService`: Uhrzeiten aus `setp_notif_time_restock`/`setp_notif_time_dinner` lesen (heute fest 9 und
  18 Uhr).
- `b_slots`: `pendingChangesCountProvider`, `openSplitBalancesCountProvider`; Abo: `subscriptionRenewsOnProvider`,
  `subscriptionFamilySharedProvider`; `SupabaseService.requestEmailChange`/`verifyEmailChange`; B's Zwischenspeicher
  (PLZ, Lieblingsmärkte, Avo-Gespräch) bei `signedOut` leeren; Avo-Ergebniszeile „Konto löschen“ →
  `/settings/account/delete`.

## Offen bei A

- Die neuen Listen-Schalter wirken erst, wenn sie gelesen werden: Liste `listPreferencesProvider.showItemImages` und
  `.suggestions`, Einkaufsmodus `.keepScreenOn`; Rezepte `recipeDietProfileProvider` liest `recipeAutoAdaptProvider`.
- `NotificationPreferencesService`: Kategorien `shoppingStarted`, `cookingTimer`, `planReminder`, `dinnerIdeas`,
  `costSplitOpen` durchsetzen (heute nur gespeichert).
- `theme_provider.dart`: Standard `ThemeMode.system` (K-32), heute hell.
- Komponenten: `NavRow(valueLeading:)` für das Warndreieck vor „In iOS aus“, `AvatarSize.xl` mit Foto (ersetzt
  `ProfilePhotoAvatar` und den Kreis im Name-Schritt), `AppButton.destructiveFilled` und eine graue `fill`-Variante,
  `AvoIcons` photo, camera, checklist, history, personCircle, flame, sync (heute in `account_icons.dart`),
  `PasswordRuleRow` öffentlich bzw. `ResetPasswordScreen(signOutOnCancel:)`, Willkommen mit `?notice=account_deleted`,
  `TipService.clearForSignOut()`.
- `InAppBrowserPage` zeigt Rechtstexte als lesbaren Text (kein `webview_flutter`).
- `/diet-preferences` zeigt die Seite im Vollbild über dem aufrufenden Tab statt auf `/settings/diet` umzuleiten.
- Aufräumen: `AuthService.updateDisplayName`/`authServiceProvider` (auth_provider.dart) ungenutzt; Texte von A8 in
  `profile.dart`/`settings.dart` zusammenführen, alte Schlüssel der gelöschten Seiten entfernen.

## Bewusst abgewichen

- Optik nach D2 `X-Profil`: farbige Kacheln (30 pt), Sektionstitel in Großbuchstaben, Titelabstand wie D2; Avatar
  64 pt (D2 52); unter dem Namen die E-Mail statt Zähler; Module als eine Zeile mit Wert statt Schalter im Profil.
- Hilfe-Fragen und -Antworten sind eigene Formulierungen (zur Durchsicht).
- Foto wird automatisch mittig quadratisch zugeschnitten (`image_picker` kann es nicht).
