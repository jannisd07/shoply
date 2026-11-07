# Offene Punkte für den Owner

Dinge, die Claude nicht selbst erledigen kann oder darf: Backend-Änderungen, Deploys, Secrets und
Produktentscheidungen. Erledigtes **löschen**, Neues oben in der passenden Gruppe eintragen.
Stand: 2026-11-07 (aus dem Repo-Aufräumen).

## 1. Dringend: Dinge, die gerade kaputt sind

- **Firebase-Konfiguration auf Jannis' Mac (`~/Apps/shoply-neu`) ist veraltet.** Richtig ist das Projekt
  `shoply-92f28` (CLAUDE.md, Edge Function `send-push-notification`). Dort ist aber `lib/firebase_options.dart`
  ein Platzhalter und `ios/Runner/GoogleService-Info.plist` gehört zum alten Projekt `shoplyai-1554e`. Folge:
  Builds von diesem Mac laufen ohne Firebase, Analytics und Push (Log: `❌ [FIREBASE]`), und alte Tokens aus
  `shoplyai-1554e` scheitern mit `SENDER_ID_MISMATCH`. Beide Dateien vom anderen Mac holen (oder
  `flutterfire configure --project=shoply-92f28`), die verirrte `./GoogleService-Info.plist` im Repo-Wurzelordner
  löschen und `database/clear_invalid_fcm_tokens.sql` einmal ausführen.
- **Spalte `shopping_lists.order_index` fehlt** (Fehler 42703). Listen umsortieren schlägt immer fehl und springt
  zurück. Spalte anlegen (besser pro Mitglied: `list_members.order_index`) oder Umsortieren entfernen.
- **Edge Functions deployen.** Code ist korrigiert, aber erst nach dem Deploy live:
  `supabase functions deploy send-push-notification` und `supabase functions deploy extract-shopping-list`
  (Autorisierung ergänzt, keine Debug-Logs mehr an den Aufrufer, Besitzprüfung vor dem Löschen).

## 2. Sicherheit und Abos

- **Abo-Status ist vom Client schreibbar.** Server-seitige Belegprüfung bauen (Edge Function, die bei Apple prüft
  und `users.subscription_*` schreibt) und Client-Updates dieser Spalten per RLS/Column-Grant sperren.
- Prüfen, dass die RPCs `activate_subscription` und `increment_recipe_view_count` in Produktion existieren. Die
  Client-Fallbacks dafür sind entfernt.

## 3. CI und Release

- **TestFlight-Secrets** im GitHub-Repo anlegen: `ENV_DART_BASE64`, `FIREBASE_OPTIONS_DART_BASE64`,
  `GOOGLE_SERVICE_INFO_PLIST_BASE64`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY` (Inhalt der `.p8`, Rolle Admin). Die alten `IOS_CERTIFICATE_*`-Secrets werden nicht
  mehr gebraucht. Danach den Workflow manuell starten.
- Supabase: `supabase db dump --schema-only` als Basis nach `supabase/migrations/` committen und einen
  pg_cron-Plan für `expire-subscriptions` in `supabase/config.toml` festhalten. Nach dem Pull auf jedem Mac
  einmal `supabase link` (`supabase/.temp/` ist jetzt ignoriert).

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
