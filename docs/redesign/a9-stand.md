# A9 Pro und Paywall – Ergebnis (09.11.2026)

Owner-Entscheidung 09.11.2026: **Variante B „KI + Komfort“** aus [`pro-konzept.md`](pro-konzept.md). Pro = höhere
KI-Tageslimits (Server, `app_flags.ai_limits`, unverändert) + Kochmodus ab Schritt 2 + Avo-Vorschläge für den
Wochenplan + Statistiken im Verlauf. Liste, Teilen, Rezepte, Angebote, Verlauf und „auf die Liste“ bleiben frei.

## Ergebnis

- **`ProFeatures`** (`widgets/design/pro_gate.dart`): `gated = {cook_mode, plan_suggestions, stats}`, Katalog
  `ProFeatures.all` (`ProFeatureInfo`: id, Symbol, Titel, Satz, „Danach …“) für Paywall und Avo-Wissen,
  `ProFeatures.info(id)`, Konstanten `ProFeatures.cookMode/planSuggestions/stats/avoQuestions`,
  `ProGate.isLockedNow` (für Callbacks). `avo_questions` steht als Vorteil auf der Paywall, ist aber nicht gesperrt
  (das Tageslimit setzt der Server).
- **Neue Paywall** `screens/subscription/paywall_screen.dart` + `widgets/paywall_view.dart` (D2, Konzept 18 §8),
  ersetzt die Paper-Paywall (`subscription_screen.dart` gelöscht, `showSubscriptionSheet` hatte keine Aufrufer):
  `xmark` oben links, Titel „Avo Pro“, Vorteile (das auslösende Feature oben, hinterlegt, mit „Danach …“), Pläne als
  Auswahlgruppe (Jährlich vorausgewählt, „x % günstiger“ aus den Store-Preisen abgerundet, Monatsanteil abgerundet),
  Testphase (nur bei `trialEligible`), angeheftete Aktionsleiste (ab AX1 im Fluss) mit Fußnote und
  „Käufe wiederherstellen · Nutzungsbedingungen · Datenschutz“ (App Review 3.1.2, In-App-Browser als Push).
  Zustände: Preise laden („…“, Kauf aus), App Store nicht erreichbar, offline, Kauf läuft (`xmark`, Pläne, Links aus),
  Kauf fehlgeschlagen (ohne rohen StoreKit-Text), Ausstehend (Kaufen anfragen), Testphase genutzt, „Du hast Avo Pro“
  mit Status und „Abo verwalten“ (Apples Abo-Seite). Erfolg: Erfolgs-Haptik, `SuccessMoment` „Avo Pro ist aktiv.“,
  Paywall schließt mit `true`, `ProGate.run` setzt die Aktion fort. Wiederherstellen: Fortschritt am Link, Ergebnis
  als `AvoToast`.
- **Kochmodus:** öffnet für alle (Zutaten und Schritt 1 sind die echte Vorschau); „Weiter“ auf Schritt 1 trägt
  `ProBadge` und öffnet die Paywall; Wischen, Wurf und die Schritt-Übersicht kommen ebenfalls nicht an der Sperre
  vorbei (`_lockedAt` in `_goTo` und `_onPageChanged`). Nach dem Kauf geht es mit dem gewünschten Schritt weiter.
- Texte `translations/paywall.dart` neu (`pro_*`, DE/EN, `{pro}` = `AppBrand.proName`); alte `premium_*` raus.
- Tests: `test/screens/subscription/paywall_view_test.dart` (Prüfmatrix für 6 Zustände, Reihenfolge, Rückrufe,
  Preise), `pro_gate_test.dart` (Variante B, Texte je Feature), `cooking_mode_screen_test.dart` (Sperre ab Schritt 2,
  auch per Wischen).

## Braucht den Owner

- **Vor dem Start von Pro (Pflicht):** `activate_subscription` ist `SECURITY DEFINER` ohne `auth.uid()`-Prüfung und
  der Client setzt den Status selbst ohne Belegprüfung (`pro-konzept.md` §2.2–2.3). Mit echten Sperren lohnt sich
  das Ausnutzen jetzt. Braucht eine Edge Function mit Belegprüfung (E18-10) und ein `REVOKE` auf die RPC.
- **Testphase:** App zeigt 14 Tage (DB `activate_trial`); StoreKit-Datei hat Monat 1 Woche, Jahr keine. In App Store
  Connect einheitlich einstellen (`pro-konzept.md` §2.1).
- **Paywall-Foto** (Konzept 18 §8.3, F-07): kein kuratiertes Essensfoto in `assets/`; die Paywall startet ohne Foto
  mit dem Titel. Ein Foto (16:10, z. B. Ofengemüse mit Feta) liefern, dann baut A es ein.
- Familienfreigabe bleibt aus (nicht umkehrbar, `pro-konzept.md` §2.6).

## Von Teil B

Wünsche an B (auch per Nachricht):

1. **Wochenplan (B7):** Pro ist „Avo schlägt die Woche vor“, nicht „auf die Liste“. Die Aktion, mit der Avo den Plan
   füllt, läuft über `ProGate.run(context, ref, feature: ProFeatures.planSuggestions, action: …)` mit
   `ProBadge`; „N Zutaten auf Wocheneinkauf“ (`meal_plan` in `wochenplan.md` 3.2) bleibt frei, ohne Badge.
2. **Verlauf (B8):** „Statistiken“ sind Pro (`ProFeatures.stats`): laufender Monat frei, frühere Monate und
   Ausgaben-Auswertung über `ProGate.run` (wie `verlauf-kosten.md` Zeile 742). „Kosten teilen“ bleibt frei.
3. **KI-Limit → Paywall** statt Fehlertext: Essensfoto, Zettel-Import, Kategorien/Empfehlungen (`pro-konzept.md`
   §1 letzte Zeile) öffnen bei erreichtem Limit `/pro?feature=avo_questions` bzw. zeigen die Pro-Zeile wie der
   Avo-Tab.
4. **`AvoAppKnowledge`** (B's Datei, prompt §5 A9.3): Pro-Inhalt aus `ProFeatures.all` lesen (Titel/Satz über
   `AppTranslations`), Preise nicht fest im Text; „KI-Kategorien, alle Rezepte, Nährwerte, Themes, Sync“ sind
   **nicht** Pro und müssen raus. Name immer „Avo Pro“.
5. Die Kalorien-Screens prüfen `isSubscribedProvider` direkt (`calories_estimate_screen.dart:519`,
   `calorie_add_photo.dart:33`); Kalorien sind in Variante B nicht Pro, nur das Essensfoto-Limit unterscheidet sich.

## Offen bei A

- Zoom-Übergang aus dem auslösenden Element (`springMorph`, §8.2): die Route nutzt den normalen Push.
- Erinnerung an Tag 12 der Testphase (§8.7.6) ist nicht geplant; deshalb fehlt der Punkt „Erinnerung per Mitteilung“
  in der Zeitleiste (die Zusage muss einlösbar sein).
- Testphasen-Berechtigung aus StoreKit (`isEligibleForIntroOffer`) statt aus der `users`-Zeile; Preis-Cache für die
  erste Öffnung; „Zahlung fehlgeschlagen“ und Familienfreigabe im Status (kommen mit E18-10).
- Kontextueller Pro-Hinweis auf der Startseite nach dem ersten Einkauf (§9.3, §11.11, `ProHintCounter`).
- Simulator-Abnahme der Paywall (Kauf nur mit StoreKit-Testdatei bzw. Sandbox).

## Bewusst abgewichen

- `pro_features` als Konstante im Code statt Supabase-Tabelle (§9.6): keine Migration ohne Owner; die Werte ändern
  sich mit der Owner-Entscheidung, nicht täglich.
- Paywall ohne Foto (siehe oben), Testphase fest 14 Tage (DB-Regel), Kochmodus-Eingang nicht mehr gesperrt (§9.2:
  gesperrt ist genau eine Aktion, „Weiter“ ab Schritt 1).
