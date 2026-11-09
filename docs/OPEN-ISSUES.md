# Offene Punkte für den Owner

Dinge, die Claude nicht selbst erledigen kann oder darf: Backend-Änderungen, Deploys, Secrets und
Produktentscheidungen. Erledigtes **löschen**, Neues oben in der passenden Gruppe eintragen.
Stand: 2026-11-08.

## 1. Dringend: Dinge, die gerade kaputt sind

- **Claude ist live (S3, 08.11.2026):** Secret gesetzt, alle sechs B-Migrationen angewendet, `ai` und
  `extract-shopping-list` deployt. Es bleiben zwei Schritte für den Owner:
  1. Den alten Gemini-Key in Google AI Studio widerrufen; er steckt in ausgelieferten Builds.
  2. In der Claude Console eine harte Monatsgrenze setzen.
- **Abo-RPCs: Sofortmaßnahme angewendet (08.11., `20261108003000_b_lock_subscription_rpcs`).** `anon` kann
  `activate_subscription`, `activate_trial`, `expire_subscriptions`, `get_recommended_items` und `is_premium_user`
  nicht mehr aufrufen; Abo und Testphase gehen nur noch fürs eigene Konto. **Offen bleibt:** Eine angemeldete Person
  kann sich weiter selbst ohne Beleg auf Pro setzen und bekommt damit die Pro-KI-Limits, bis die Belegprüfung unter 2.
  steht.
- **Firebase-Konfiguration auf Jannis' Mac (`~/Apps/shoply-neu`) ist veraltet.** Richtig ist das Projekt
  `shoply-92f28` (CLAUDE.md, Edge Function `send-push-notification`). Dort ist aber `lib/firebase_options.dart`
  ein Platzhalter und `ios/Runner/GoogleService-Info.plist` gehört zum alten Projekt `shoplyai-1554e`. Folge:
  Builds von diesem Mac laufen ohne Firebase, Analytics und Push (Log: `❌ [FIREBASE]`), und alte Tokens aus
  `shoplyai-1554e` scheitern mit `SENDER_ID_MISMATCH`. Beide Dateien vom anderen Mac holen (oder
  `flutterfire configure --project=shoply-92f28`), die verirrte `./GoogleService-Info.plist` im Repo-Wurzelordner
  löschen und `database/clear_invalid_fcm_tokens.sql` einmal ausführen.
- **Spalte `shopping_lists.order_index` fehlt** (Fehler 42703). Listen umsortieren schlägt immer fehl und springt
  zurück. Spalte anlegen (besser pro Mitglied: `list_members.order_index`) oder Umsortieren entfernen.
- **Edge Function `send-push-notification` deployen.** Code ist korrigiert, aber erst nach dem Deploy live:
  `supabase functions deploy send-push-notification` (Autorisierung ergänzt, keine Debug-Logs an den Aufrufer).

## 2. Sicherheit und Abos

- **Anmeldung mit Code (A7 Konto) im Supabase-Dashboard prüfen:** Mailvorlagen „Confirm signup“ und „Magic Link“
  enthalten `{{ .Token }}` (6 Ziffern); Mindestabstand zwischen zwei Codes 60 s; Gültigkeit 3600 s; Passwortregeln
  8 Zeichen, ein Großbuchstabe, eine Ziffer; Kontoverknüpfung bei bestätigter E-Mail (F-17-05). Die App nutzt dafür
  `SupabaseService.sendEmailCode`/`verifyEmailCode`.
- **Abo-Status ist vom Client schreibbar.** Server-seitige Belegprüfung bauen (Edge Function, die bei Apple prüft
  und `users.subscription_*` schreibt) und Client-Updates dieser Spalten per RLS/Column-Grant sperren.
- `activate_subscription` existiert in Produktion (geprüft 08.11.); `increment_recipe_view_count` ebenfalls.
- Weitere Hinweise des Supabase-Advisors (alt, nicht von Teil B): `update_expense_splits_updated_at` ohne festen
  `search_path`, `pg_trgm` im Schema `public`, Leaked-Password-Schutz aus.
- Wochenplan live zwischen Geräten: `meal_plan_entries` und `meal_plans` zur Publication `supabase_realtime`
  hinzufügen (bis dahin lädt die App beim Öffnen neu).

## 3. CI und Release

- **TestFlight-Secrets** im GitHub-Repo anlegen: `ENV_DART_BASE64`, `FIREBASE_OPTIONS_DART_BASE64`,
  `GOOGLE_SERVICE_INFO_PLIST_BASE64`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY` (Inhalt der `.p8`, Rolle Admin). Die alten `IOS_CERTIFICATE_*`-Secrets werden nicht
  mehr gebraucht. Danach den Workflow manuell starten.
- Supabase: `supabase db dump --schema-only` als Basis nach `supabase/migrations/` committen und einen
  pg_cron-Plan für `expire-subscriptions` in `supabase/config.toml` festhalten. Nach dem Pull auf jedem Mac
  einmal `supabase link` (`supabase/.temp/` ist jetzt ignoriert).
- **Kalorien: auf dem Gerät prüfen (B6 W3b).** Die eigene Foto-Kamera (`ios/Runner/NativeChannels/MealCameraChannel.swift`,
  neu im Xcode-Projekt) ist nur gegen das iOS-SDK typgeprüft, nicht gebaut. Beim nächsten Build bitte: Foto aufnehmen
  (Blitz, Auslöser, „Aus Fotos“), Fotoauswahl aus „Essen eintragen“, Barcode scannen bis zur Menge, VoiceOver auf der
  Kamera.

## 4. Produktentscheidungen

| Thema | Optionen |
|---|---|
| Eigene Kategorien und Kategorie-Reihenfolge | Bisher nur auf dem eigenen Gerät. Für alle Listenmitglieder teilen (Supabase-Tabelle) oder so lassen? |
| Listen-Aktivitätsverlauf | Nur lokal, und es schreibt nichts mehr hinein. In eine Tabelle `list_activities` verschieben oder Feature (Screen, Route, Push-Typ) entfernen? |
| Akzentfarbe | `accentColorProvider` wirkt nirgends. Ins Theme einbauen oder samt Avo-Tool "Akzentfarbe ändern" entfernen? |
| Zuletzt geöffnete Liste beim Start öffnen | Wird jetzt pro Nutzer lokal gespeichert, aber nicht mehr automatisch geöffnet. Gewünscht? |
| Listen-Hintergründe | Menüpunkt entfernt, weil Hintergründe nie angezeigt wurden. Im Redesign wieder einbauen? |
| Teilen per Link | Der Link fügt Empfänger keiner Liste hinzu. Eine Route `/join/:code` bauen oder Link-Teilen entfernen? |
| Push-Erlaubnis | Wird beim ersten Start gefragt. Lieber im Onboarding oder beim ersten Teilen fragen? |
| "Verlauf löschen" | Soll das auch die Kaufstatistik (Grundlage der Empfehlungen) löschen? |
| Mehrere Geräte | Nur das zuletzt benutzte Gerät bekommt Pushes (`users.fcm_token`). Auf `user_devices` umstellen? |
| Rechtliche Links | Datenschutz/Impressum auf joinavo.app, AGB/Support noch shoplyai.app (`core/constants/legal_links.dart`). Hat joinavo.app AGB? |
| Versionsanzeige | Profil/Hilfe zeigen fest "1.0.0". `package_info_plus` direkt einbinden (ist schon transitiv da)? |
| `macos/`, `web/` | Behalten? `web/` enthält die Deep-Link-Seite und die AASA-Datei. |
| Eigener Markt pro Liste | „Markt wählen“ bietet „„Bio Kaiser“ als eigenen Markt verwenden“ nur ohne Liste an: `list_store_assignments_b.chain_id` nimmt nur Ketten-IDs. Für eigene Märkte eine Spalte (z. B. `custom_name`) per Migration ergänzen? |
| Angebots-Einstellungen pro Konto | Die fünf Schalter aus „Preise & Angebote“, Lieblingsmärkte, „Markt automatisch erkennen“, „Diese Woche ausblenden“, „Nicht dieses Angebot“, „Nicht interessiert“ und ausgeblendete Listen liegen pro Konto, aber nur auf diesem Gerät (ein zweites Gerät kennt sie nicht). Migration `user_offer_prefs` (angebote.md Owner-Frage 14) freigeben? |
| Region pro Gerät statt pro Konto | Postleitzahl, Ort, „Standort verwenden“ und „Region entfernen“ gelten für das Gerät (`offers_zip_manual`, `offers_zip_code_v2`, `offers_region_removed_v1`), nicht für das Konto: Ein zweites Konto auf dem Gerät nutzt die Region des ersten, und „Region entfernen“ wirkt für beide. Die Spec sieht das Konto vor (angebote.md S11, „Speicherort Konto (L4)“). Mit `user_offer_prefs` ins Konto verschieben? |
| PLZ-Tabelle (Ort zur Postleitzahl) | Ohne Tabelle zeigt „Region“ für eine getippte PLZ nur „PLZ 79098“ (den Ort gibt es nur über den Standort), und „Diese Postleitzahl kennen wir nicht.“ prüft nur Zone 00 und 99999. Quelle und Lizenz einer offenen PLZ-Liste wählen (angebote.md Owner-Frage 11, Lücke L10)? |
| Angebote für Listen ohne Markt | Laut Spec zeigen Listen ohne festen Markt die Angebote der Lieblingsmärkte in deren Reihenfolge (K12-03, Owner-Frage 7). Die Daten dafür (Abgleich über mehrere Märkte pro Artikel) sind noch nicht gebaut: solche Listen zeigen keine Angebote, und „Lieblingsmärkte“ sagt deshalb nur „Diese Märkte stehen oben, wenn du für eine Liste einen Markt wählst.“ Als Nächstes bauen? |
| Standort-Abfrage | Text in `Info.plist` (`NSLocationWhenInUseUsageDescription`) wie in angebote.md Owner-Frage 10 setzen: „Avo nutzt deinen Standort, um deine Postleitzahl für Angebote zu finden und den Markt vorzuschlagen, in dem du gerade bist.“ |
| Essensfotos und Anthropic | S3/S4/S5 sagen „Das Foto wird nur für die Schätzung verwendet und privat gespeichert.“ Passt das zur Aufbewahrung bei der Claude-API (kalorien.md §7.3)? Sonst den Satz anpassen lassen. |
| „Alle Essensfotos löschen“ | Fotos eines gelöschten Eintrags werden jetzt gelöscht. Ein Knopf für alle Essensfotos kommt erst mit S23 (Einstellungen „Kalorien & Gesundheit“); bis dahin verspricht kein Text diese Einstellung. |
| Avo: Menge der Essens-Schätzung | Bis B6's Mengen-Eingabe (Vollbild) da ist, nur ganze Portionen (Stepper 1–10) in der Karte. So lassen oder auf B6 warten? |
| Avo: Rezept auf die Liste ohne Angebotspreise | Avo hängt beim Rezept auf die Liste keine Angebotspreise mehr an (vorher eine Suche über alle Märkte, Plan 8). Bestätigen? |
| Avo schaltet sich selbst aus | „Schalte Avo aus“ wirkt nach dem Ende der Antwort, danach Toast „Avo ausgeschaltet · Widerrufen“. So gewollt? |
| Avo: Kosten teilen ohne Widerrufen | „Teilen“ auf Avos Vorschau ersetzt eine frühere Aufteilung (die Karte sagt, wessen „bezahlt“ zurückgesetzt wird; der Zahler des Einkaufs bleibt); zurück geht es noch nicht. Rückweg bauen (`ExpenseSplitService` stellt alte Anteile wieder her) oder so lassen? |
| Fotoauswahl als System-Blatt | „Foto auswählen“ zeigt Apples Fotoauswahl (PHPicker) als Blatt, das von unten hereinfährt; die Kamera kommt bildschirmfüllend, ebenfalls von unten. Beides steuert iOS (image_picker), A's Zettel-Import macht es genauso. Hinnehmen oder die Vollbild-Kamera aus B6 (Kalorien, jetzt auf main) auch für Avo nutzen? |

## 5. Bekannte Restarbeiten im Code (kann Claude machen)

- `RecipeService.getRecipes()` lädt die ganze Rezepttabelle mit allen Bewertungen (jetzt nur noch einmal statt
  3–4×). Für echtes Paging braucht es eine View oder Spalten `average_rating`/`rating_count`.
- Fünf Kategorie-Systeme (ProductCategory, ProductClassifierService, SmartCategorizationService, Scanner,
  CategoryDetector) zu einem zusammenführen. Ändert das gespeicherte Format, deshalb eigenes Projekt.
- `key: ValueKey('$themeMode-$languageCode')` in `app.dart` entfernen, wenn ein Test auf dem Gerät zeigt, dass
  Hell/Dunkel und DE/EN trotzdem live wechseln (dann bleibt der Tab-Zustand erhalten).
- 19 alte `AppLocalizations`-Getter in `list_detail_screen.dart`/`home_screen.dart` auf `context.tr` umstellen.
- Auf einem echten Gerät testen: Kochmodus-Timer-Benachrichtigung, Rezept-Push-Tap (Zurück über Tabs hinweg),
  Startzeit, Listen-Zähler auf Home.
