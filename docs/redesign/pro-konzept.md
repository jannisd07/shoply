# Avo Pro: Ist-Stand und Varianten (A9, Teil A)

**Entschieden 09.11.2026: Variante B** (Umsetzung in `a9-stand.md`). Stand der Analyse 08.11.2026. Grundlage: Code-Analyse von `main` (Datei:Zeile unten). Entscheidung Free gegen Pro trifft der Owner;
bis dahin ist in `ProFeatures.gated` (`lib/presentation/widgets/design/pro_gate.dart`) nichts gesperrt.
Fest: **Angebote sind nie Pro** (Plan 8).

## 1. Ist-Stand

**Was die Paywall verspricht** (`subscription_screen.dart:181-184`, Texte `translations/paywall.dart:43-45`):
„Unbegrenzt geteilte Listen“, „Avo plant Rezepte und Wochen“, „Einkaufs-Statistiken“, „14 Tage gratis testen“ für
beide Pläne.

**Was wirklich gesperrt ist:** nur der **Kochmodus** (`recipe_detail_screen.dart:986-1060`, Paywall über
`showSubscriptionSheet`). Den verspricht die Paywall nicht. Alles Versprochene ist ungesperrt bzw. nicht gebaut:

| Versprechen | Wirklichkeit |
|---|---|
| Unbegrenzt geteilte Listen | kein Limit für Free (weder App noch DB) |
| Avo plant Rezepte und Wochen | Wochenplan noch nicht gebaut (`plan_routes.dart:11`), Avo-Chat ohne Limit (ruft Gemini direkt) |
| Einkaufs-Statistiken | Verlauf-Statistik ungesperrt, Home-Statistik noch Platzhalter (B) |
| Avos App-Wissen (`avo_app_knowledge.dart:28-30`) | verspricht zusätzlich KI-Kategorien, unbegrenzten Chat, alle Rezepte, Nährwerte, Themes, Sync; nichts davon gesperrt |

**Server:** Pro unterscheidet nur die KI-Tageslimits (`supabase/functions/ai/handler.ts:59-72`, Werte
`app_flags.ai_limits`, `20261108000000_b_app_flags.sql:61-64`):

| Aufgabe | Free/Tag | Pro/Tag |
|---|---|---|
| Avo-Chat | 3 | 60 |
| Essensfoto | 1 | 15 |
| Zettel-Import | 1 | 10 |
| Kategorien (Artikel) | 200 | 500 |
| Empfehlungen | 5 | 30 |
| Nährwert-Schätzung | 10 | 50 |

Bei erreichtem Limit zeigt die App heute nie die Paywall, sondern allgemeine Fehlertexte oder nichts
(`list_import_service.dart:216`, `food_entry_sheet.dart:103-112`, `ai_categorization_service.dart:247-249,376-404`).

## 2. Fakten, die unabhängig von der Entscheidung offen sind

1. **Testzeitraum widersprüchlich:** Paywall 14 Tage für beide Pläne; StoreKit Monat 1 Woche, Jahr kein Test
   (`ios/Runner/Configuration.storekit:39-45, 71`); DB setzt 14 Tage beim ersten Kauf
   (`database/migrations/20251110_smart_trial_detection.sql:32`). Was im App Store Connect eingestellt ist: offen.
2. **Kein Beleg-Check:** Der Client setzt `subscribed` selbst und meldet es per RPC; der Kaufbeleg wird nirgends
   geprüft (`subscription_service.dart:208-223, 376-409`). Das Ablaufdatum rechnet der Client (+30/+365 Tage).
3. **RPC `activate_subscription`** ist `SECURITY DEFINER` ohne `auth.uid()`-Prüfung; ein `REVOKE`/`GRANT` dazu steht
   nicht im Repo. Ob ein angemeldeter Nutzer damit Pro für sich (oder andere) setzen kann, hängt von den Rechten in der
   Live-DB ab: offen, prüfen.
4. **Keine Links zu Nutzungsbedingungen und Datenschutz auf der Paywall** (nur im Profil, `legal_links.dart:6-8`). Apple
   verlangt sie für Abos im Kaufablauf (App Review Guideline 3.1.2).
5. **Name uneinheitlich:** „Avo Premium“ (Paywall, Profil), „Avo Pro“ (`AppBrand.proName`, Erfolgstext), „Shoply
   Premium“ (StoreKit-Gruppe, Avo-Wissen). Owner-Entscheidung 07.11.2026: „Avo Pro“.
6. **Familienfreigabe** ist aus (`familyShareable: false`, beide Produkte). Laut Apple lässt sie sich für ein Abo
   einschalten, aber danach nicht mehr ausschalten (Quelle: App-Store-Connect-Hilfe „Family Sharing“; genauer Link
   offen).
7. `/pro?feature=` wird ignoriert (`paywall_routes.dart:12`): die Paywall zeigt immer dasselbe.
8. Preise fest im Code an zwei Stellen (`translations/profile.dart:48` „2,99 €/Monat“, `avo_app_knowledge.dart:14-18`
   in Dollar); die Paywall selbst liest sie live aus dem Store.

## 3. Varianten Free gegen Pro

Allen gemeinsam: Liste, Teilen, Rezepte, Angebote, Verlauf bleiben Free. Paywall erscheint nach dem ersten
Erfolgserlebnis (Konzept 10.3.3 Rang 9: nach dem ersten abgeschlossenen Einkauf oder ersten Wochenplan) und beim
Erreichen eines KI-Limits, statt eines Fehlertexts.

| | A: Pro = mehr KI | B: Pro = KI + Komfort | C: Pro = KI + Gesundheit |
|---|---|---|---|
| Pro enthält | höhere KI-Limits (Tabelle oben) | A + Kochmodus, Wochenplan-Vorschläge durch Avo, Auswertungen im Verlauf | A + Modul Kalorien & Gesundheit (Apple Health, Essensfoto, Barcode) |
| Free behält | alle Funktionen mit kleinen KI-Limits | wie A ohne die drei Komfort-Funktionen | alles außer Kalorien-Modul, kleine KI-Limits |
| Schon im Code | Limits serverseitig fertig (B) | Kochmodus-Sperre da; Wochenplan und Auswertungen noch nicht gebaut | Kalorien-Modul bei B in Arbeit |
| Aufwand A | Paywall-Texte, Limit-Hinweis → Paywall | dazu 3 `ProGate`-Stellen | dazu Modul-Sperre in Onboarding/Einstellungen |
| Vorteile | einfach erklärt, Kosten (KI) und Preis hängen zusammen | mehr sichtbarer Gegenwert auf der Paywall | klare Zielgruppe mit Zahlungsbereitschaft (Kalorien-Apps sind meist Abo) |
| Nachteile | Free-Limit 3 Avo-Fragen/Tag fällt früh auf | mehr Sperren, mehr Pflege; Wochenplan noch nicht fertig | Kalorien ist laut Owner ein Nischen-Modul (Standard: aus); Gesundheitsdaten nur für Zahlende |

Die Einzelwerte der Limits lassen sich ohne App-Update ändern (`app_flags.ai_limits`).
