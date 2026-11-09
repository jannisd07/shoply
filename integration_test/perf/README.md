# Leistungsmessung (Teil A, Konzept 20 §5.1 und §7.7)

Nur auf einem echten iPhone (Ziel: iPhone 13 Pro, 120 Hz) im Profile-Modus. Zahlen aus Simulator oder Debug zählen nicht.

```bash
flutter drive --profile --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/s1_scroll_list_test.dart -d <iPhone>
# ebenso s2_check_series_test.dart und s5_recipes_tab_test.dart
```

Ergebnis: je Szenario `build/perf/<szenario>_<zeit>.json` mit Durchschnitt, 90. und 99. Perzentil und
schlechtestem Frame, getrennt nach Build (UI-Thread) und Raster, dazu das Urteil und die Rohwerte. Die Konsole zeigt
eine Zeile pro Szenario. Ergebnis mit Datum, Commit und Gerät in die Status-Datei eintragen (§7.7 Punkt 4).

| Nr. | Datei | Ablauf | Ziel | Grenze |
|---|---|---|---|---|
| S1 | `s1_scroll_list_test.dart` | `ListDetailScreen` „Wocheneinkauf“, 60 Artikel in 8 Kategorien mit Bild, 3 Würfe runter, 3 hoch | 90. Perzentil ≤ 8,3 ms | kein Frame > 16 ms |
| S2 | `s2_check_series_test.dart` | `ShoppingModeView`, 20 offene Artikel, alle 300 ms einer abgehakt (Wandern nach „Im Wagen“) | ≤ 8,3 ms | nie > 16 ms |
| S5 | `s5_recipes_tab_test.dart` | `RecipesScreen`, 24 Rezepte mit Fotos, alle Abschnitte, kalter Bild-Cache, 5 Würfe runter, 5 hoch | ≤ 8,3 ms | ≤ 16 ms |

Regression: schlechtester Frame über 16 ms oder 90. Perzentil über 8,3 ms in einem Szenario, das vorher darunter lag.

## Wie die Tests aufgebaut sind

- `perf_harness.dart`: Testdaten und Provider-Overrides, kein Supabase. Die Bilder liefert ein kleiner HTTP-Server
  auf 127.0.0.1 aus `assets/avo/`. Dadurch laufen der echte Bildweg (`CachedNetworkImage`, Dekodieren) und das
  Laden ohne Internet. Jeder Lauf bekommt neue Bild-URLs, der Cache ist also kalt.
- `watchPerformance` wartet vor dem Messen 2 s. Die Fotos im ersten sichtbaren Bereich sind deshalb meist schon
  geladen; erst beim Scrollen kommen neue dazu.
- Einige Slots von Teil B (Markt, Einkaufsverlauf) loggen Warnungen, weil Supabase fehlt. Sie fangen das selbst ab.

## Stand (A11, 09.11.2026)

- Noch keine Messung am Gerät. Ein Probelauf im Simulator (nur Ablauf, keine Zahlen): S2 grün; S1 brach mit einer
  Ausnahme beim Zeichnen ab, danach `_pendingFrame == null` in `postTest` (Ursache offen, beim ersten Gerätelauf die
  erste Ausnahme lesen); S5 lief noch nie.
- **Achtung:** `flutter test integration_test/...` mit gebootetem Simulator installiert die Test-App über die echte
  App; danach ist man in der App abgemeldet. Nur bewusst und nur am Gerät laufen lassen.
