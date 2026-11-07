# Bericht (Hauptsitzung)

Datei: `<doku-ordner des systems>/idiotensicher-JJJJ-MM-TT.md` (ohne Doku-Ordner: `pruefungen/` daneben). Nur bestätigte Befunde stehen oben;
„unbestätigt“ und „kein Fehler“ stehen gesammelt am Ende. Fakten, keine Empfehlungen in Wertungsform: Lösungen
stehen als Optionen mit Aufwand.

```
# Idiotensicher-Test: <system>, <datum>

**Urteil:** idiotensicher ja/nein. P0: <n> · P1: <n> · P2: <n> · P3: <n>
**Stufe:** <Schnell|Normal|Gründlich> · **Umgebung:** <url> · **Agenten:** <rolle (modell)>, …

## Denkaufwand bis zum Ziel
| Persona | Ziel erreicht | Klicks | Pflichtfelder | Entscheidungen | Zögerstellen | erster Klick richtig |

## Befunde (bestätigt)
| ID | Schwere | Was der Kunde erlebt | Schritte | Beleg | Ursache (Datei:Zeile) | Optionen (Aufwand) |

## Abdeckung
| Kategorie | ok | Befund | entfällt | nicht getestet |
(A–J aus checkliste.md; je „nicht getestet“ eine Zeile mit Grund darunter)

## Unbestätigt oder kein Fehler
- <ID> – <Urteil des Prüfers, Grund>

## Was der Test nicht abdeckt
- echte Menschen, echte Geräte (iOS/Android), andere Browser, echte Mails/Zahlungen: <je getestet ja/nein>
```

**Urteil „idiotensicher: ja“ nur wenn:** 0 × P0, 0 × P1, alle Personas am Ziel, erster Klick überall richtig, und
in den Kategorien A, E, H, I und J kein „nicht getestet“ ohne „entfällt“-Grund.

Nach dem Bericht: in einem Satz sagen, welche Datei gepusht wurde. Bei Reparatur-Auftrag (SKILL.md Schritt 7):
dieselbe Tabelle mit Spalte „nach Fix“ (bestätigt behoben durch frischen Agenten: ja/nein).
