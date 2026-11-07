# Shoply – Ideen und Plan

**Status:** ✅ entschieden · 🔍 erst prüfen · 💡 offen · 🟢 erledigt · ❌ verworfen

Zuletzt aktualisiert: 2026-11-07

---

## 1. Features beim ersten Start wählbar ✅
- Beim ersten Öffnen sieht man die Features und schaltet nur die ein, die man will; später in den Einstellungen änderbar.
- Kern: **Einkaufsliste + Rezepte**. Alles andere (Kalorien, Kosten teilen, Angebote, Avo …) ist ein Modul.
- Halbfertiges liegt hinter einem Schalter, unsichtbar bis es fertig ist.
- Avo bekommt **einen** Einstiegspunkt statt mehrerer.

## 2. Design aus einem Guss ✅
- **5 Beispiele als Bilder** (gleiche Screens, fünf Richtungen), wir wählen eins.
- Danach ein Abstands- und Schriftsystem für alles; Startseite = die Liste von heute.

## 3. Tempo – muss super sein ✅
- App-Start schnell: Dienste parallel oder erst bei Bedarf starten.
- Listen sofort da: lokaler Stand zuerst, Abgleich im Hintergrund.
- Flüssiges Scrollen und Abhaken ohne Ruckeln.

## 4. Kern-Ablauf ✅
- Hinzufügen: ein Eingabefeld, Vorschläge aus dem Verlauf, „2 Milch“ → Menge + Artikel, Kategorie im Hintergrund.
- Einkaufsmodus: große Häkchen, nach Gang sortiert, Bildschirm bleibt an.
- Geteilte Listen: sehen, wer gerade einkauft; Abgehaktes live.

## 5. Neue Dinge mit Nutzen ✅
- Wochenplan: Rezepte wählen, Portionen anpassen, ein Tipp → alles auf der Liste.
- ❌ Live Activity / Dynamic Island – nicht gewollt.

## 6. Repo aufräumen ✅
- Struktur reinbringen, toten Code und Altlasten raus, Code kürzen.
- Kurze Doku-Dateien statt der riesigen Status-Datei.
- Klären, ob die tägliche Claude-Routine weiterläuft.

## 7. Anthropic API statt Gemini ✅
- Alle KI-Funktionen (Kategorien, Avo, Rezepte, Essensfotos) laufen über Claude.
- Aufrufe über einen eigenen Server (Supabase Edge Function), der Schlüssel kommt nicht in die App.
- Kleines, schnelles Modell für Kategorien, starkes Modell für Avo und Fotos.

## 8. Artikelbilder, Preise, Angebote 🔍 (Research fertig, Entscheidung offen)
- **Artikelbilder – bauen:** eigene Illustrationen für Kategorien und häufige Artikel; echte Produktfotos von
  Open Food Facts nur bei erkanntem Produkt oder Barcode.
- **Angebote – behalten, aber sauber machen:** Lizenz/Partnerschaft anfragen (marktguru, sonst kaufDA oder Shopfully);
  bis dahin abschaltbar und nicht Teil von Premium.
- **„Günstigster Markt für den ganzen Einkauf“ – nicht bauen,** weil es dafür in Deutschland keine verlässlichen
  Daten gibt. Stattdessen: „4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region“,
  verglichen über den Kilo-/Literpreis.
- Neu prüfen, falls Deutschland Händler zur Veröffentlichung von Preisen verpflichtet.
- Details: [docs/research/Preise Angebote und Artikelbilder.md](research/Preise%20Angebote%20und%20Artikelbilder.md)

## 9. Kalorientracking – vollwertig ✅
- Mahlzeit per Foto (KI schätzt Kalorien und Makros), Barcode-Scanner, Lebensmittelsuche.
- Gewicht, Wasser, Workouts; Ziele, Verlauf, Wochenübersicht.
- Apple Health lesen und schreiben.
- Nur sichtbar, wenn eingeschaltet (siehe 1).

## 10. Siri ✅
- „Füg Milch zu Shoply hinzu“, „Was steht auf meiner Liste?“ und Ähnliches.

## 11. Widgets – richtig gut ✅
- Schnell und schön, abhaken direkt im Widget.

## 12. Avo – kann alles, mit Stimme ✅
- Voice-Modus: sprechen statt tippen, Avo antwortet mit Stimme.
- Kann alles in der App: Listen, Rezepte, Kalorien (Foto vom Essen → wird eingetragen), alle Einstellungen.
- Nur für die Person, die ihn bedient: alles läuft mit deren Login und Rechten; Löschen mit Rückfrage.

## Offen 💡
- Welche Design-Richtung?
- Welche Features sind beim ersten Start standardmäßig an?
- Partneranfrage für Angebote stellen?
