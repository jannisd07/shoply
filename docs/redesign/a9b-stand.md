# A9b Pro, Rest – Ergebnis (09.11.2026)

Folgt auf [`a9-stand.md`](a9-stand.md) (Owner-Variante B). Diese Sitzung: B8/B7/B6b nicht auf `main` (nur
`origin/feature/b7-plan`), Maskottchen F-17-11 laut Owner noch nicht entschieden, also A9b statt S5b oder A10.

## Ergebnis

- **Zoom-Übergang der Paywall** (Konzept 18 §8.2, §8.9): neue Komponente
  `widgets/design/zoom_page.dart` (`ZoomPage`, `ZoomPageRoute`, `ZoomOrigin`). Die Route `/pro` ist jetzt eine
  `ZoomPage`: Die Seite wächst aus dem auslösenden Element (Rechteck, Ecken von 20 auf 0, Inhalt blendet in der
  ersten Hälfte ein) und schrumpft beim Schließen dorthin zurück. Feder `AvoMotion.morph` (0,40 s, ohne Überschwingen)
  als Kurve über 560 ms. Ohne Ursprung (Deep Link, Avo) wächst sie aus der Mitte von 0,96 auf 1 mit Deckkraft.
  Zurück-Wischen vom linken Rand (20 pt) folgt dem Finger 1:1 und lässt die Seite zum Ursprung schrumpfen;
  loslassen über 30 % oder mit Schwung (> 500 pt/s) schließt, sonst federt sie zurück. Reduce Motion: Überblendung,
  Wischen geht weiter.
- **Woher der Ursprung kommt:** `ProGate.run(…, origin:)` (neuer optionaler Parameter, bestehende Aufrufe bleiben
  gültig) und `ProGate.openPaywall(context, feature:, origin:)` nehmen das Element; ist der übergebene Kontext ein
  ganzer Screen (> 50 % der Fläche), nimmt `ZoomOrigin` den Punkt des letzten Tipps (44 × 44, nur echte Tipps, nicht
  das Ende eines Wischens, höchstens 0,5 s alt). Das gilt auch für jedes schlichte `context.push(RoutePaths.pro)` (Profil,
  Hilfe, B's Avo-Zeile): Die Paywall wächst dort aus dem Finger. `app.dart` startet das Tipp-Merken
  (`ZoomOrigin.ensureTracking()`). Kochmodus: die Paywall wächst aus „Weiter“ (`CookingBottomBar(nextKey:)`), auch
  wenn man über Schritt 1 hinaus wischt.
- **Preis-Cache** (§8.5, K18-10): `PaywallPriceCache` in `paywall_screen.dart` speichert die Preise der letzten
  StoreKit-Antwort (`pro_price_cache_v1`, je Sprache; eine andere Sprache gilt als kein Cache). Die Paywall zeigt
  sie sofort; bis StoreKit antwortet, ist die Hauptaktion mit gleicher Beschriftung deaktiviert
  (`PaywallData.pricesCached`). Der Schlüssel ist gerätegebunden (`account_local_data.dart`): Preise gehören zum App-
  Store-Land, nicht zum Konto.
- **Pro-Hinweis auf der Startseite** (§9.3, §11.11): `widgets/design/pro_hint_counter.dart` (`ProHintCounter`,
  `proHintCounterProvider`, `ProHintVisit`) und `screens/home/widgets/home_pro_hint.dart`. Nach dem ersten
  abgeschlossenen Einkauf (Liste oder Einkaufsmodus, `noteAha()`) steht beim nächsten Besuch der Startseite (nie beim App-Start) als
  letzte Sektion die Zeile „14 Tage Avo Pro gratis testen“ mit `ProBadge` statt Symbol und „Ansehen“ (Paywall wächst
  aus der Zeile). Regeln: nur bei bekanntem Pro-Status, ohne Pro, mit offener Testphase (`trialEligible`), wenn
  Home noch Platz für eine Hinweis-Zeile hat (K-38: höchstens 2 mit Spar-Hinweis, „Heute kochen“, Tipp), höchstens ein
  Pro-Hinweis pro Tag, derselbe höchstens einmal pro Woche, an seinem Tag bleibt er stehen (Paywall schließen lässt
  ihn stehen). Wischen nach links oder Kontextmenü „Nicht mehr zeigen“ gilt dauerhaft. Kontogebunden (`pro_hints_v1`
  wird beim Abmelden gelöscht). Entschieden wird einmal pro Besuch (wie `TipVisit`: neuer Besuch, wenn die Seite
  wieder sichtbar wird), nie während man liest.
- Unabhängiges Review vor dem Commit, alle Funde behoben: Zurück-Wischen nur auf der ruhenden Seite und Abbruch,
  wenn die Paywall unter dem Finger anders geschlossen wird; kein Sprung, wenn ein Öffnen vom Schließen unterbrochen
  wird; Pro-Hinweis nie beim ersten Besuch der Startseite (App-Start) und weg, sobald später geladene Zeilen den
  Platz brauchen; Wochenabstand in Kalendertagen (Sommerzeit); Tipp-Ursprung höchstens 0,5 s alt.
- Texte `pro_hint_trial`, `pro_hint_view`, `pro_hint_never` (DE/EN) in `translations/paywall.dart`.
- Tests: `test/presentation/widgets/design/zoom_page_test.dart` (Ursprung, Mitte, Wischen schließt/federt zurück,
  Reduce Motion), `pro_hint_counter_test.dart` (alle Taktregeln), `test/screens/home/home_pro_hint_test.dart`
  (Prüfmatrix, Texte, Wischen), `home_layout_test.dart` (Reihenfolge, Abstände), `paywall_view_test.dart` (Cache,
  `canBuy`).

- **Simulator** (iPhone 17, angemeldet, Debug-Build): Profil › Avo Pro öffnet die Paywall aus der Zeile, Preise aus
  der StoreKit-Testdatei; Zurück-Wischen vom Rand schrumpft sie zum Ursprung und schließt
  ([`abnahme/a9b/`](abnahme/a9b/)). Dunkel, hoher Kontrast und AX bis 3,1× deckt die Prüfmatrix der Paywall ab; im
  Simulator nur hell.

## Braucht den Owner

Unverändert aus `a9-stand.md` (Belegprüfung und `REVOKE` auf `activate_subscription` vor dem Start von Pro,
Testphase in App Store Connect einheitlich, Paywall-Foto). Nichts Neues.

## Von Teil B

1. **Erinnerung an Tag 12 der Testphase** (§8.7.6): braucht eine lokale Mitteilung über B's
   `notification_service.dart` (Plugin-Start und Tipp-Behandlung liegen dort). Wunsch: eine Funktion
   `scheduleProTrialReminder(DateTime trialEndsAt)` / `cancelProTrialReminder()`, Text „Deine {pro}-Testphase endet
   übermorgen. Danach {price} pro Jahr.“, Tipp öffnet `shoply://pro`. A ruft sie nach einem Kauf mit Testphase auf
   und setzt danach den Zeitleisten-Punkt „Erinnerung per Mitteilung“ wieder ein (bzw. „Hinweis in der App“ ohne
   Erlaubnis).
2. Wer die Paywall selbst öffnet (`avo_status_sections.dart`, `avo_setting_sections.dart`), kann
   `ProGate.openPaywall(context, feature:, origin: <Kontext der Zeile>)` nutzen; ohne Umstellung wächst sie aus dem
   Tipp, das reicht auch.
3. Offen aus `a9-stand.md` „Von Teil B“ 1–5 (Wochenplan, Verlauf, KI-Limit → Paywall, `AvoAppKnowledge`,
   Kalorien-Prüfungen).

## Offen bei A

- Testphasen-Berechtigung aus StoreKit (`isEligibleForIntroOffer`) statt aus der `users`-Zeile; „Zahlung
  fehlgeschlagen“ und Familienfreigabe im Status (mit E18-10, Server).
- Preise rollen beim Wechsel Cache → StoreKit nicht (`RollingNumber`), sie werden ersetzt.
- Die Hinweis-Zeile verschwindet nach „Nicht mehr zeigen“ ohne Einklapp-Animation.
- Während des Zooms hebt sich die Paywall nur durch ihre Form ab (gleicher Grund `bgGrouped` wie die meisten
  Seiten darunter); ein weicher Schatten oder Abdunkeln des Hintergrunds wäre eine Verbesserung (im Simulator
  ansehen).
- Simulator-Bilder der Paywall in dunkel und AX3.
- Ein zweiter Pro-Hinweis (z. B. Sektionsfuß im Wochenplan) nutzt denselben `ProHintCounter` mit eigener id.

## Bewusst abgewichen

- Der Zoom ist eine Federkurve über eine feste Routendauer (560 ms), keine freie Feder auf dem Routen-Controller:
  so bleiben `Navigator`, GoRouter und Pop-Ergebnis unverändert. Beim Zurück-Wischen läuft die Route linear mit dem
  Finger und federt mit `SpringSimulation` zurück.
- Ohne bekanntes Element wächst die Paywall aus dem Tipp-Punkt (44 pt), nicht aus der ganzen Zeile.
- Der Pro-Hinweis steht nur, solange die Testphase offen ist (der Text verspricht „gratis testen“); für Konten mit
  genutzter Testphase gibt es keinen Hinweis (schließt F18-04 mit ein).
