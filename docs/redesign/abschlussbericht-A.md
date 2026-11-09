# Abschlussbericht Teil A (Stand 09.11.2026, S5)

Für den Owner: was Teil A gebaut hat, was offen ist und welche Entscheidungen noch bei dir liegen. Einzelheiten stehen
in `status-A.md` (Meilensteine mit Commits) und den `aN-stand.md` der Pakete.

## Gebaut

| Bereich | Ergebnis | Unterlagen |
|---|---|---|
| Fundament (S1, S2) | D2-Tokens (`core/design`), rund 45 Komponenten in `widgets/design/` mit Tests und Galerie (`/debug/components`), Tab-Bar Home/Listen/Avo/Rezepte/Profil, Router mit Modul-Wächtern und Deep Links | `status-A.md`, `design-quelle.md` |
| Eingabeleiste (A3) | Bug deiner Mutter: der Text in „Artikel hinzufügen“ wird bei keiner Breite (320–440 pt) und keiner Textgröße bis 3,1× mehr abgeschnitten (40 Testfälle) | `test/screens/lists/add_item_composer_test.dart` |
| Home (A4) | „Für dich“ mit Listen, Tipp, Angeboten von B | `status-A.md` |
| Listen (A5) | Liste, Artikel als Vollbild, Einkaufsmodus, Übersicht, Teilen, Listen-Info, „Vielleicht auch“ | `a5-stand.md` |
| Rezepte (A6) | Tab, Suche, Kategorien, Bibliothek, Detail mit Allergie-Hinweis und Anpassung, Zutaten auf die Liste, Kochmodus, Editor | `a6-stand.md` |
| Onboarding, Login, Tipps (A7) | Ablauf mit Wiederaufnahme, Apple/Google/E-Mail-Code, Passwort, Tipp-Zeilen statt Tutorial | `a7-stand.md` |
| Profil und Einstellungen (A8) | Profil mit Suche, neun Einstellungsseiten, Profil bearbeiten, Konto, Abmelden, Konto löschen (ohne Server) | `a8-stand.md` |
| Anfragen von B (AB1, AB2, A11, A11b) | alle bis status-B Nr. 18, Wochenplan-Wünsche A-P1–A-P4, A-K10 | `status-A.md` „Anfragen von B“ |
| Aufräumen (A12) | 13 tote Dateien, 543 ungenutzte Texte, Paper-Reste bis auf die Paywall, `feature-ideen.md` | `a12-stand.md` |
| Qualität (A11, A11b) | Prüfmatrix für alle A-Screens außer Paywall, `tool/design_check.sh A` ohne Funde, Messtests, Simulator-Rundgang hell/dunkel/AX3, Flows Hinzufügen und Teilen | `a11-stand.md`, `a11b-stand.md` |
| Gegenprüfung von B (S6) | B's fertige Screens geprüft, 10 Wünsche an B | `s6-stand.md` |
| Bereiche fertig (S5) | Diät-Filter prüfen Zutaten (deine Entscheidung), `SwipeActions` mit nur einer offenen Zeile und Schließen beim Scrollen, „Vielleicht auch“ mit gestricheltem Plus-Kreis, Galerie vollständig | `s5-stand.md` |

## Prüfung gegen „Fertig, wenn“ (prompt §11)

| Punkt | Stand |
|---|---|
| A1 bis A12 erledigt, Meilensteine in `status-A.md` | **ja, bis auf A10** (Maskottchen wartet auf dich); A9 erledigt am 09.11.2026 (`a9-stand.md`) |
| Alle A-Screens wie im Konzept, Prüfmatrix grün | **ja**, die Paywall seit A9 eingeschlossen; Matrix-Tests laufen in CI |
| Bug der Mutter nachweislich behoben | **im Test ja** (40 Fälle); die Geräte-Abnahme am iPhone 13 Pro mit „Größerer Text“ und AX3 steht aus (nur du) |
| Kein Paper-Rest in A-Dateien | **ja** (die Paper-Paywall ist mit A9 gelöscht) |
| Anfragen von B erledigt, S6 abgeschlossen | **ja für alles auf `main`**; B8 mit S5b gegengeprüft und dessen Wünsche umgesetzt (`s5b-stand.md`); offen ist die Gegenprüfung von B6b/B7, sobald B sie auf `main` bringt |
| Abschlussbericht | diese Datei |

## Offen bei A

- Gegenprüfung von Wochenplan (B7) und Kalorien-Woche/Gewicht/Challenges (B6b), wenn sie auf `main` sind (B8 ist mit
  S5b erledigt).
- Präsenz im Einkaufsmodus (es gibt noch keinen Präsenz-Kanal), Ziehen aus der Menü-Vorschau, `ListCard` blendet das
  Cover ab AX1 nicht aus, `ReorderableInsetSection` im Simulator ansehen, Kalender-Menü,
  `NutritionRow`, Charts mit Ziellinie, `InlineCalendar`, einklappbare `InsetSection` (Wünsche aus B's Konzepten,
  noch ohne Anfrage).

## Entscheidungen, die bei dir liegen

1. **Pro (A9):** entschieden (Variante B) und gebaut. Vor dem Start offen bei dir: Belegprüfung und
   `activate_subscription` absichern, Testphase in App Store Connect, Paywall-Foto (`a9-stand.md`).
2. **Maskottchen und App-Icon (A10):** neue Grafiken und das finale Motiv (F-17-11).
3. **Server-Entwürfe freigeben:** [`a7-server-entwurf.sql`](a7-server-entwurf.sql) (Onboarding-RPC, Backfill; sonst
   `kOnboardingRedesignCutoff` auf den Release-Tag), [`a8-server-entwurf.sql`](a8-server-entwurf.sql) (Konto löschen
   über `delete-account`, Mitteilungen im Konto, `share_presence`, Profilfotos privat).
4. **Deploy von `ai`** (OPEN-ISSUES 2.): ohne ihn antwortet Avo nicht (S6 Fund 1).
5. Eine Domain für Rechtstexte (F18-06), Daten exportieren (F18-07), KI-Einwilligung im Onboarding (F-17-03,
   F-17-12), Ideen aus [`feature-ideen.md`](feature-ideen.md) §5.
6. Routine `claude/daily` pausieren.
7. **Am Gerät (nur du):** Messung am iPhone 13 Pro (`integration_test/perf/README.md`), Abnahme nach Konzept 20 §7.6
   (VoiceOver-Runde, AX3 mit Anzeigezoom, Flugmodus im Einkaufsmodus), Rezept „Dillsenfsoße“ in den Daten von
   „vegan“ befreien.
8. TestFlight und App Store, wenn A und B ruhen.
