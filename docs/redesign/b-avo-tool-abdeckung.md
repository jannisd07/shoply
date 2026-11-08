# Avo: Tool-Abdeckung (Teil B, Grundlage für B5)

Stand 07.11.2026. Reine Analyse, kein Code geändert. Ziel des Owners: Avo kann alles, was die App kann, per Text und
Stimme; gelöscht wird nur nach Bestätigung.

Quellen: `docs/redesign/konzept/16-avo.md` (Kap. 6 bis 8, 15), Konzept 12, 14, 15, 18 (Einstellungsseiten, Avo-Schlüssel),
Plan `docs/superpowers/plans/2026-11-07-teil-b.md` (B1.6, B5), `status-A.md` (S1-Verträge), `status-B.md`,
`lib/data/services/avo_tool_declarations.dart` (35 Gemini-Tools), `avo_assistant_service.dart`, `avo_settings_bridge.dart`,
alle Screens unter `lib/presentation/screens/**`, `lib/data/repositories/*`, `lib/data/services/*`, die Edge Function
`supabase/functions/ai/` (Stand: `tasks/avo_chat.ts` ist noch ein Stub, `_shared/avo_tools.ts` gibt es noch nicht) und
die Claude-API-Dokumentation zu Strict Tool Use (Abschnitt 3).

---

## 1. Ergebnis in Kürze

- **Heute:** 35 Tools. 29 davon bleiben inhaltlich erhalten (teils umbenannt oder zusammengelegt), 1 entfällt
  (`compare_list_prices`), 3 Lösch-Tools werden durch `propose_delete` ersetzt, `ask_pick_list` geht in `ask_choice`
  auf, `log_food` wird zu Vorschau plus Bestätigung.
- **Geprüft:** 139 nutzersichtbare Funktionen in 10 Bereichen (Abschnitt 4). Für 51 davon hat Avo heute ein Tool, 26
  davon mit Mangel: Löschen ohne echte Bestätigung, Allergie- und Ernährungs-Liste wird ersetzt, `complete_list` ohne
  Verlauf, Marktvergleich, Profil ohne Einwilligung, Essen ohne Vorschau gespeichert, Module nur für Kalorien.
- **Vorschlag:** 63 Tools in fester Reihenfolge (60, wenn der Angebots-Kill-Switch an ist). Damit sind 131 der 139
  Funktionen per Text und Stimme erreichbar. 2 entfallen ganz (Akzentfarbe, Marktvergleich), 6 bleiben bewusst bei der
  App (Abschnitt 2.9 und 4.10).
- **Vier Befunde, die vor B5 geklärt sein müssen:**
  1. **Strict-Grenzen:** Plan B1.6 sagt „Tools `strict: true`“. Die API erlaubt höchstens **20 Strict-Tools pro
     Anfrage** und **16 Parameter mit Union-Typ** (also auch `["string","null"]`) über alle Strict-Schemas zusammen,
     dazu 24 optionale Parameter. Alle 63 Tools strict geht nicht. Vorschlag: 18 Strict-Tools mit zusammen 15
     nullbaren Parametern (Abschnitt 3), der Rest wird in der App gegen dasselbe Schema geprüft.
  2. **Stabile Tool-Liste:** Innerhalb eines Gesprächs darf sich die Liste nie ändern (Prompt-Cache, Grammatik-Cache,
     Thinking-Blöcke mit `drop_block`). Module, Pro und Bildschirm wirken deshalb erst bei der Ausführung, nicht in der
     Deklaration. Einzige Variante: Kill-Switch `offers_enabled`, und die wählt der Server.
  3. **Quote pro Runde:** `handler.ts` zählt jede Anfrage an `avo_chat`. Eine Frage mit zwei Tool-Runden kostet heute
     drei Einheiten, damit wären Free-Nutzer (3 pro Tag) nach einer Frage fertig. `avo_chat.quotaAmount` muss pro
     Nutzer-Runde zählen und Tool-Fortsetzungen mit eigener Obergrenze laufen lassen (Abschnitt 10).
  4. **Löschen:** Das Modell bekommt kein einziges Lösch-Tool. `propose_delete` erzeugt nur eine Karte mit
     Einmal-Schlüssel, gelöscht wird erst durch den Tipp. Das gilt auch im Sprachmodus.

---

## 2. Regeln für alle Tools (verbindlich für B5)

### 2.1 Ausführung

- Avo-Tools laufen **in der App** mit der Supabase-Sitzung der Person (RLS). Das Modell sieht nur Ergebnisse.
- Ein neuer `AvoToolExecutor` (B) bekommt einen `Ref`, keinen `WidgetRef` (heute `AvoSettingsBridge(WidgetRef)`), damit
  Tools auch aus dem Sprachmodus, nach einem Tab-Wechsel und später aus Siri laufen.
- Daten schreiben nur über die bestehenden Wege: `itemsNotifierProvider`, `listsNotifierProvider`, `ItemRepository`,
  `ListRepository`, B-Services. Keine eigenen Supabase-Aufrufe im Executor.
- Mehrere `tool_use`-Blöcke einer Runde laufen parallel; alle `tool_result`-Blöcke gehen in **einer** Nachricht zurück.
- Jede Eingabe wird vor der Ausführung gegen das Schema geprüft, auch bei Strict-Tools (wegen
  `eager_input_streaming: true` validiert die API nicht mehr selbst). Zahlenbereiche (Sterne 1 bis 5, Portionen 1 bis 20,
  Wasser 1 bis 3.000 ml, höchstens 60 Artikel) prüft nur die App, weil Strict-Schemas kein `minimum`/`maximum` kennen.
- Enum-Werte vergleicht die App ohne Groß- und Kleinschreibung (die API kann den ersten Buchstaben ändern).
- Tool-Beschreibungen schreibt B auf Englisch (modellseitig, sprachneutral), Antworten folgen `locale`.

### 2.2 Schema-Stil und Schreibweise in diesem Dokument

Jeder Parameter steht in `required`, jedes Objekt hat `additionalProperties: false`. Was die Person nicht genannt hat,
schickt das Modell als `null`. Schreibweise in den Tabellen:

| Schreibweise | JSON-Schema |
|---|---|
| `"string"`, `"integer"`, `"number"`, `"boolean"` | `{"type": "…"}` |
| `"date"` | `{"type": "string", "format": "date"}`, lokaler Kalendertag `YYYY-MM-DD` |
| `"date-time"` | `{"type": "string", "format": "date-time"}` |
| `"enum:a\|b"` | `{"type": "string", "enum": ["a", "b"]}` |
| `"…\|null"` am Ende | Typ wird `[…, "null"]`, bei Enums kommt `null` in die Werteliste |
| `["string"]`, `[{…}]` | Array, `minItems: 1`; „leer erlaubt“ steht beim Tool |

Beispiel, wie eine Zeile aus Abschnitt 5 als Tool-Definition aussieht:

```json
{
  "name": "add_items",
  "description": "Add one or more items to a shopping list. list_id null means the list from the screen context.",
  "strict": true,
  "eager_input_streaming": true,
  "input_schema": {
    "type": "object",
    "additionalProperties": false,
    "required": ["list_id", "items"],
    "properties": {
      "list_id": {"type": ["string", "null"]},
      "items": {
        "type": "array",
        "minItems": 1,
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": ["name", "quantity", "unit"],
          "properties": {
            "name": {"type": "string"},
            "quantity": {"type": ["number", "null"]},
            "unit": {"type": ["string", "null"]}
          }
        }
      }
    }
  }
}
```

Die Schemas liegen an genau einer Stelle (`_shared/avo_tools.ts`, B1.6). Für die Prüfung in der App wird daraus eine
JSON-Datei, die ein Dart-Test gegen die Executor-Tabelle prüft (gleiches Muster wie `_shared/categories.json`).

### 2.3 Ergebnisformat und Fehlercodes

Jedes Tool antwortet mit einem JSON-Objekt, nie mit Rohtext einer Exception (heute `{'error': e.toString()}`,
`avo_assistant_service.dart:308-310`):

```json
{"ok": true, "summary": "2 Artikel abgehakt", "undo_id": "u_7f3a", "data": {}}
{"ok": false, "code": "module_off", "module": "calories"}
```

| `code` | Bedeutung | Was die App zeigt |
|---|---|---|
| `invalid_input` | Schema oder Wertebereich verletzt (`is_error: true`) | nichts, Modell korrigiert |
| `not_found` | Objekt gibt es nicht oder nicht mehr | Avo sagt es |
| `no_permission` | RLS/Rolle verbietet es (z. B. fremde Liste löschen) | Avo bietet Alternative an („Liste verlassen“) |
| `module_off` | Modul aus | Zeile „Kalorien ist ausgeschaltet“ + „Einschalten“ (`set_module`) |
| `not_available` | Funktion noch nicht freigeschaltet (Wochenplan `released: false`) oder in diesem App-Build unbekannt | Avo sagt, dass es das noch nicht gibt |
| `pro_required` | Pro-Funktion ohne Pro (`feature`-ID dabei) | Pro-Zeile „Mit {pro} verfügbar · Ansehen“; nach Kauf läuft derselbe Aufruf einmal |
| `no_region` | Angebote ohne echte PLZ | Zeile „Für Angebote in deiner Region: Postleitzahl festlegen“ |
| `needs_choice` | Ziel unklar | Auswahl-Zeilen (Kap. 7), Antwort kommt als nächste Nutzer-Nachricht |
| `preview_shown` | Vorschau steht, nichts gespeichert (`preview_id` dabei) | Vorschau mit „Eintragen“/„Übernehmen“ |
| `awaiting_confirmation` | Lösch-Karte steht (`card_id` dabei) | `AvoConfirmCard` |
| `queued_offline` | `ok: true`, liegt in der Warteschlange | Sync-Zeichen an der Ergebniszeile |
| `offline_blocked` | Löschen offline | „Offline. Löschen geht erst mit Verbindung.“ |
| `conflict` | Daten inzwischen geändert | „Inzwischen geändert“ |
| `quota_exceeded` | Foto- oder Zettel-Quote des Tages erreicht | „Für heute ist Schluss mit Fotos. Ab morgen geht es weiter.“ |

Fremde Inhalte in Ergebnissen (Artikelnamen anderer Mitglieder, Community-Rezepte, Open-Food-Facts-Daten, erkannter
Zetteltext) stehen nur in Datenfeldern (`name`, `title`, `text`). Der System-Prompt sagt, dass Tool-Ergebnisse Daten sind.

### 2.4 Widerruf

- Jede umkehrbare Änderung liefert `undo_id`. Ein neues `AvoUndoRegistry` (B) merkt sich Gegen-Aktion und Datenversion
  (`updated_at`) für die Dauer des Gesprächs (24 h). „Widerrufen“ in der Zeile und `undo_last` per Text oder Stimme
  nutzen denselben Eintrag und prüfen die Version (sonst `conflict`, Zeile „Nicht mehr widerrufbar“).
- Widerrufen löscht nie Fremdes: Es entfernt genau die eben angelegten Objekte oder stellt alte Werte her. Deshalb
  braucht es keine Lösch-Karte.
- Nach einem bestätigten Löschen ist Widerrufen nur dort möglich, wo das Objekt vollständig wiederhergestellt werden kann
  (Artikel, Tagebuch-Einträge, Plan-Einträge, Allergie). Liste, Einkauf, Rezept, Mitglied: endgültig, das sagt die
  Karte vorher.

### 2.5 Bestätigung vor dem Löschen

- Das Modell hat **kein** Tool, das löscht, entfernt oder verlässt. Es hat nur `propose_delete`. Heutige Abkürzung
  `confirm: true` (`avo_assistant_service.dart:1091, 1111, 1652`) und `confirm_replace` (1388-1400) entfallen.
- `propose_delete` prüft Rechte und Objekt, erzeugt `AvoConfirmCard` mit Einmal-Schlüssel (10 min, an Objekt und
  Version gebunden) und antwortet `awaiting_confirmation`. Gelöscht wird erst beim Tipp auf „Löschen“, in der App, über
  das Repository. Das Ergebnis (gelöscht, abgebrochen, abgelaufen) geht mit der nächsten Anfrage als Kontext-Notiz an
  Avo.
- Sprachmodus: gesprochenes „Ja“ löscht nie („Dafür brauche ich deinen Tipp auf Löschen.“). „Nein“/„Abbrechen“ wertet
  die App lokal aus, solange eine Karte wartet.
- Allergie entfernen: `edit_diet_profile` mit `action: "remove"` erzeugt die Sicherheits-Variante der Karte (Kap. 8.6)
  über denselben Mechanismus.
- Vorschauen (Essen, Kalorienziel, Zettel-Import) sind keine Löschungen. Sie speichern erst nach „Eintragen“ bzw.
  „Übernehmen“; im Sprachmodus darf `confirm_preview` nach einem gesprochenen „Ja“ laufen (Kap. 15 4.4), weil das
  Ergebnis widerrufbar ist.

### 2.6 Module, Kill-Switch, Pro: erst bei der Ausführung

- Alle Tools sind immer deklariert (Abschnitt 8). Der Executor fragt vor jedem Aufruf
  `moduleEnabledProvider(AppModule.x)` und für Angebote `offersAvailableProvider` ab und antwortet sonst `module_off`.
- So kann Avo im laufenden Gespräch `set_module(calories, true)` ausführen und gleich danach Essen eintragen, ohne dass
  sich die Tool-Liste ändert.
- **Kill-Switch `offers_enabled`:** Der Server lässt dann `search_offers`, `get_list_offers`, `set_list_offers_hidden`
  weg und entfernt die Angebots-Werte aus den Enums von `set_module` und `update_setting`. Die Variante wählt der Server
  aus `app_flags` (so steht es schon in `20261108000000_b_app_flags.sql`), nie die App. Avo antwortet dann „Dazu kann
  ich gerade nichts sagen.“
- **Pro:** `proFeatureProvider(id)` (A, E18-02) bei der Ausführung; Ergebnis `pro_required`. Angebote, Listen, Teilen,
  Einkaufsmodus, Rezepte, Verlauf und Allergien sind nie Pro.

### 2.7 Fotos

Fotos bleiben auf dem Gerät. Die Nutzer-Nachricht an Avo enthält nur „Foto angehängt“ mit `attachment_id`; Avo ruft
dann `import_list_photo` oder `preview_food_entry(source: "photo")`. Die App schickt das Bild an die eigenen Tasks
`list_import` bzw. `meal_photo`. Vorteile: Die Owner-Quoten (Essensfoto, Zettel-Import) gelten, und das Bild wird nicht
in jeder Tool-Runde des append-only-Verlaufs erneut mitgeschickt. Ohne erkennbare Absicht fragt Avo mit
`ask_choice(kind: "photo_intent")`.

### 2.8 Sicherheit

- Allergien filtern **immer im Executor** (Rezeptsuche, `fill_plan`, `get_meal_ideas`, `substitute_ingredient`,
  Warnzeile bei `add_to_plan`), mit Komposita und Mehrzahl. Das Modell übergibt keine Allergene mehr (heute
  `exclude_allergens`, nur wenn das Modell daran denkt).
- Allergien und Ernährung nur einzeln hinzufügen oder entfernen, nie die Liste ersetzen (heute `_setListField`,
  `avo_settings_bridge.dart:396-434`, leerer Wert löscht alle Allergien).
- `get_user_profile` gibt Ernährung und Allergien nur mit Einwilligung „Ernährung und Allergien einbeziehen“, Körperdaten
  nur mit „Kalorien, Gewicht und Ziele einbeziehen“ heraus. Beide Schalter kann Avo nur **aus**schalten.
- `join_list` führt der Executor nur aus, wenn der Code wörtlich in der letzten Nutzer-Nachricht steht (Schutz gegen
  Codes aus fremden Artikelnamen).
- Änderungen nur in Listen mit Mitgliedschaft (RLS). Löschen einer fremden Liste wird zu „Liste verlassen“.

### 2.9 Nie per Avo (Avo öffnet die Seite und sagt, dass man es dort selbst tut)

Konto löschen, Abmelden, Abo kaufen oder kündigen, Systemberechtigungen (Mitteilungen, Mikrofon, Kamera, Standort,
Apple Health), Nachrichten an andere schicken (Avo öffnet nur das System-Teilen), Rezept veröffentlichen (öffentlicher
Inhalt), Profilbild ändern (braucht die Fotoauswahl), Artikel per Ziehen umsortieren. Weg: `navigate` mit dem passenden
Ziel. Dazu kommen Bedienelemente des Chats selbst (Löschen bestätigen per Tipp, Neues Gespräch, Vorlesen, Kopieren).

---

## 3. API-Grenzen und was daraus folgt

Aus der Dokumentation zu Structured Outputs / Strict Tool Use (geprüft am 07.11.2026):

| Grenze | Wert | Folge für Avo |
|---|---|---|
| Strict-Tools pro Anfrage | 20 | 18 Strict-Tools, 2 Reserve |
| Parameter mit Union-Typ (auch `["string","null"]`) über alle Strict-Schemas | 16 | Die 18 Strict-Tools haben zusammen 15 nullbare Parameter |
| Optionale Parameter (nicht in `required`) über alle Strict-Schemas | 24 | 0, alles steht in `required` |
| Nicht unterstützt | `minimum`, `maximum`, `minLength`, `maxLength`, `minItems` > 1, rekursive Schemas | Bereiche prüft die App |
| Grammatik-Cache | 24 h; ändert sich bei anderem Schema oder anderem Tool-Satz, nicht bei Name/Beschreibung | Tool-Satz stabil halten |
| Interne Grenze | „Schema is too complex for compilation“ (400), 180 s Kompilierzeit | einmal mit echtem Schlüssel testen, bevor B5 live geht (Owner) |

**Auswahl der Strict-Tools** (häufig, schreibend oder sicherheitsrelevant): `create_list` (1), `set_list_store` (1),
`complete_shopping` (2), `add_items` (3), `check_items` (0), `move_items` (0), `add_recipe_to_list` (2),
`add_to_plan` (2), `confirm_preview` (0), `log_water` (1), `log_weight` (1), `set_split_paid` (0), `set_module` (0),
`update_setting` (0), `edit_diet_profile` (0), `ask_choice` (0), `propose_delete` (1), `undo_last` (1).
In Klammern die nullbaren Parameter, Summe 15.

Alle anderen Tools sind lesend oder haben viele optionale Felder. Sie laufen ohne `strict`, aber mit derselben Prüfung in
der App (2.1). Strict schützt nicht vor Prompt-Injection; dafür sorgen 2.5 und 2.8.

Weitere Folgen:
- Reihenfolge `tools` → `system` → `messages` im Cache: Jede Änderung am Tool-Satz macht den ganzen Cache ungültig und
  verwirft Thinking-Blöcke älterer Runden. Kontext (Bildschirm, Liste, Datum, Module, Pro) geht deshalb als
  `role: "system"`-Nachricht nach der letzten Nutzer-Nachricht (so schon in B1.6 geplant), nie in Tools oder System-Prompt.
- Kein erzwungenes `tool_choice` (400 bei `claude-sonnet-5-5`). Wo ein Tool nötig ist, sagt es der System-Prompt.
- Tool-Definitionen und JSON-Schlüssel immer in derselben Reihenfolge serialisieren (Abschnitt 8), sonst stiller
  Cache-Verlust.

---

## 4. Abdeckungstabelle

Spalten: **Heute** = Tool im Ist-Code oder `LÜCKE`. **Tool und Parameter** = Vorschlag, Beispielaufruf; das volle
Schema steht in Abschnitt 5. **Ausführung** = was der Executor in der App aufruft (A = Datei von Teil A, neu = gibt es
noch nicht). **Widerruf**: ja / nein / eingeschränkt. **Karte**: Löschen = `AvoConfirmCard`, Sicherheit = Variante 8.6,
Vorschau = „Eintragen/Übernehmen“, Auswahl = `ask_choice` bei Unklarheit, – = keine. **Modul**: Kern oder
`AppModule`; „+KS“ = zusätzlich Kill-Switch. **Pro**: nie / Kandidat (Owner entscheidet, F-05) / offen.

### 4.1 Listen

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Listen ansehen | `get_lists` | `get_lists {}` | `listsNotifierProvider` (A) + `storeForListProvider` (Markt, offene Anzahl) | – | – | Kern | nie |
| Liste lesen | `get_list_contents` (ohne ID erste Liste) | `get_list_contents {"list_id": null, "include_checked": false}` (null = Kontext-Liste, sonst Liste von heute) | `ItemRepository.getListItems` (A) | – | – | Kern | nie |
| Mitglieder, Aktivität, Teilen-Status | LÜCKE | `get_list_details {"list_id": "…"}` | `ListRepository.getListMembers`, `ListActivityService.getActivities(limit: 10)` (A) | – | – | Kern | nie |
| Liste anlegen (mit Markt) | `create_list` (ohne Markt) | `create_list {"name": "Party", "store_chain_id": "rewe"}` | `listsNotifier.createList` (A) + `setStoreForList` | ja, solange leer | – | Kern | nie |
| Liste umbenennen | `rename_list` | `update_list {"list_id": "…", "name": "Grillabend", "sort_mode": null, "move_to": null, "background": null}` | `listsNotifier.updateList({'name'})` (A) | ja | – | Kern | nie |
| Sortierung Kategorie/Manuell | LÜCKE | `update_list {…, "sort_mode": "manual"}` | `updateList({'sort_mode'})` | ja | – | Kern | nie |
| Liste nach oben/unten | LÜCKE | `update_list {…, "move_to": "top"}` | `listsNotifier.reorderLists` (A, braucht Ziel-Position) | ja | – | Kern | nie |
| Hintergrund (Farbe, Verlauf) | LÜCKE | `update_list {…, "background": "gradient:sunset"}`; Bild → `navigate` | `listsNotifier.saveBackground` (A) | ja | – | Kern | nie |
| Liste teilen (Link oder Code) | LÜCKE | `open_share_sheet {"kind": "list_link", "id": "<list_id>"}` | `getShareLink` / `generateShareCode` (A) → System-Teilen | – (nichts gesendet) | – | Kern | nie |
| Liste beitreten | LÜCKE | `join_list {"code_or_link": "K7P2QX"}` | `joinListWithCode` / `joinListWithLink` (A); nur Code aus der Nutzer-Nachricht | ja (verlassen) | – | Kern | nie |
| Mitglied entfernen | LÜCKE | `propose_delete {"target": "member", "list_id": "…", "ids": ["<user_id>"]}` | heute Supabase direkt in `list_settings_screen.dart:103-135` (A) → braucht `ListRepository.removeMember` | nein | Löschen | Kern | nie |
| Liste verlassen | LÜCKE | `propose_delete {"target": "leave_list", "list_id": "…", "ids": ["<list_id>"]}` | `ListRepository.leaveList` (A) | nein | Löschen | Kern | nie |
| Liste löschen | `delete_list` (`confirm`-Parameter) | `propose_delete {"target": "list", "list_id": "…", "ids": ["<list_id>"]}` | `listsNotifier.deleteList` (A); nur Eigentümer, sonst `no_permission` + Karte „Liste verlassen“ | nein | Löschen | Kern | nie |
| Einkauf starten | LÜCKE | `navigate {"destination": "shopping_mode", "id": "<list_id>", "date": null}` | Einkaufsmodus-Route (A, fehlt noch) | – | – | Kern | nie |
| Markt der Liste setzen/entfernen | LÜCKE | `set_list_store {"list_id": "…", "chain_id": "lidl"}` (null = entfernen) | `setStoreForList` / `clearStoreForList` (`store_for_list_provider.dart:131, 136`) | ja | – | Kern (bleibt bei KS) | nie |
| Angebote für diese Liste ausblenden | LÜCKE | `set_list_offers_hidden {"list_id": "…", "hidden": true}` | `setOffersHiddenForList` (`list_offer_prefs_provider.dart:34`) | ja | – | offers +KS | nie |
| Zettel fotografieren | LÜCKE | `import_list_photo {"attachment_id": "a1", "list_id": null}` | `ListImportService.importFromBytes` (Task `list_import`); „Alle hinzufügen“ per Tipp oder `confirm_preview` → `itemsNotifier.importItems` (A) | ja (Batch) | Vorschau, Auswahl | Kern | nie (Quote Free 1/Tag) |
| Kategorie-Reihenfolge | LÜCKE | `edit_list_categories {"list_id": "…", "action": "reorder", "category_ids": ["fruits_vegetables", "dairy"], "name": null, "color": null}` | `CategoryOrderService.saveCategoryOrder` | ja | – | Kern | nie |
| Eigene Kategorie anlegen/umbenennen | LÜCKE | `edit_list_categories {…, "action": "add", "category_ids": [], "name": "Baby", "color": null}` | `addCustomCategory` / `updateCustomCategory` | ja | – | Kern | nie |
| Eigene Kategorie löschen | LÜCKE | `propose_delete {"target": "custom_category", "list_id": "…", "ids": ["<cat_id>"]}` | `CategoryOrderService.deleteCustomCategory` | eingeschränkt (neue ID) | Löschen | Kern | nie |
| Aktivität leeren | LÜCKE | `propose_delete {"target": "list_activity", "list_id": "…", "ids": ["<list_id>"]}` | `ListActivityService.clearActivities` (A) | nein | Löschen | Kern | nie |
| Einkauf abschließen | `complete_list` (hakt nur ab, kein Verlauf) | `complete_shopping {"list_id": "…", "chain_id": null, "total_cost": 42.8, "split": false}` | Abschluss-Logik aus `checkout_flow` ohne UI (neu, B): `ShoppingHistoryService.completeShoppingTrip` (später RPC `complete_shopping_trip`), abgehakte Artikel entfernen, Ersparnis nur Modul offers | ja (Eintrag samt Aufteilung weg, Artikel wieder abgehakt) | Auswahl „Wo warst du?“ | Kern (Ersparnis offers, Teilen costSplit) | nie |

### 4.2 Artikel

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Artikel hinzufügen (einer oder viele) | `add_item_to_list` (einzeln, Reload + Push je Artikel) | `add_items {"list_id": null, "items": [{"name": "Milch", "quantity": 2, "unit": null}]}` | `ItemRepository.addItems` + Token (A5); bis dahin `itemsNotifier.importItems` (A); Kategorie sofort lokal, Angebot nur vom Markt der Liste | ja (`undoAddItems`) | Auswahl (Liste) | Kern | nie |
| Liste wählen, wenn unklar | `ask_pick_list` (nur 3 Listen) | `ask_choice {"kind": "list", "question": "Auf welche Liste?", "options": []}` | App baut alle Listen (ab 6: die 5 zuletzt geänderten + „Alle Listen anzeigen“ + „Neue Liste …“) | – | Auswahl | Kern | nie |
| Name, Menge, Einheit ändern | `update_item` | `update_item {"list_id": "…", "item_id": "…", "name": null, "quantity": 3, "unit": null, "note": null, "category_id": null}` | `itemsNotifier.updateItem` (A) | ja | – | Kern | nie |
| Notiz am Artikel | `update_item` | `update_item {…, "note": "laktosefrei"}` | wie oben | ja | – | Kern | nie |
| Kategorie eines Artikels ändern | LÜCKE | `update_item {…, "category_id": "dairy"}` | wie oben, Spalte `category_id` | ja | – | Kern | nie |
| Abhaken | `check_items` | `check_items {"list_id": "…", "item_ids": ["…"], "checked": true}` | `itemsNotifier.toggleItemChecked` (A, optimistisch; heute direkt über das Repository) | ja | – | Kern | nie |
| Abhaken zurücknehmen | `check_items` | `check_items {…, "checked": false}` | wie oben | ja | – | Kern | nie |
| Artikel verschieben | `move_items` | `move_items {"from_list_id": "…", "to_list_id": "…", "item_ids": ["…"]}` | `itemsNotifier(from).updateItem({'list_id'})` (A) | ja | – | Kern | nie |
| Artikel löschen | `delete_item` (`confirm`-Parameter) | `propose_delete {"target": "items", "list_id": "…", "ids": ["…", "…"]}` | `itemsNotifier.deleteItem` (A, hart) | ja (Wiedereinfügen, braucht `restoreItems`, A) | Löschen | Kern | nie |
| Nachkauf-Vorschläge | `get_restock_suggestions` | `get_restock_suggestions {"list_id": null, "limit": 5}` | `AvoNudgeService.getRestockSuggestions`, später `restockSuggestionsForListProvider` (E10-09) | – | – | Kern | nie |
| Letzten Einkauf wieder auf die Liste | `add_history_items_to_list` (sucht in 30 Einträgen) | `add_history_items_to_list {"trip_id": "…", "list_id": null, "item_names": []}` (leer = alle) | `ShoppingHistoryService.getTrip` (neu) + `addItems`, nur nicht schon offene | ja | Auswahl (Liste) | Kern | nie |
| Artikel umsortieren | – | kein Tool (Ziehen in der App) | – | – | – | Kern | nie |
| Barcode an Artikel | – | `navigate {"destination": "list", …}` (Kamera in der App) | – | – | – | Kern | nie |

### 4.3 Rezepte und Kochen

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Rezepte suchen | `search_recipes` (Allergie nur, wenn übergeben) | `search_recipes {"query": "Linsen", "diet": [], "max_minutes": 20, "max_results": 3}` | `RecipeService.searchRecipes` (A) + Allergie-Filter immer (A `RecipeAdaptation`) | – | – | Kern | nie |
| Gemerkte Rezepte | `get_saved_recipes` | `list_my_recipes {"scope": "saved"}` | `RecipeService.getSavedRecipes` (A) | – | – | Kern | nie |
| Eigene Rezepte | LÜCKE | `list_my_recipes {"scope": "own"}` | `RecipeService.getMyRecipes` (A) | – | – | Kern | nie |
| Entwürfe | LÜCKE | `list_my_recipes {"scope": "drafts"}` | `RecipeDraftService.getDrafts` (A) | – | – | Kern | nie |
| Rezept-Details, Zutaten, Schritte | LÜCKE | `get_recipe {"recipe_id": "…", "servings": 4}` | `RecipeService.getRecipeById` (A) | – | – | Kern | nie |
| Nährwerte eines Rezepts | `get_recipe_nutrition` (zweiter Gemini-Aufruf) | `get_recipe` (Nährwerte im Ergebnis; fehlen sie: Task `nutrition_estimate`, markiert „geschätzt“) | wie oben + `ClaudeService.run('nutrition_estimate')` | – | – | Kern | nie |
| Zutaten auf die Liste | `add_recipe_to_list` (sequentiell, Angebot beliebiger Markt) | `add_recipe_to_list {"recipe_id": "…", "list_id": null, "servings": 4}` | A `RecipeToList` (Zusammenfassen, „Hast du meist da“, Batch) → `addItems` | ja (Token) | Auswahl (Liste) | Kern | nie |
| Rezept merken / nicht mehr merken | LÜCKE | `save_recipe {"recipe_id": "…", "saved": true}` | `saveRecipe` / `unsaveRecipe` (A) | ja | – | Kern | nie |
| Rezept bewerten | LÜCKE | `rate_recipe {"recipe_id": "…", "stars": 5}` | `RecipeService.rateRecipe` (A) | eingeschränkt (alte Bewertung muss lesbar sein) | – | Kern | nie |
| Als Entwurf speichern | LÜCKE | `create_recipe_draft {"title": "Linsencurry", "servings": 2, "total_minutes": 30, "ingredients": [{"name": "rote Linsen", "amount": 200, "unit": "g"}], "steps": ["…"]}` | `RecipeDraftService.saveDraft` (A); „Ansehen“ öffnet den Editor | ja | – | Kern | nie |
| Rezept veröffentlichen/bearbeiten | – | nie per Avo → `navigate {"destination": "recipe_new", …}` | – | – | – | Kern | nie |
| Eigenes Rezept löschen | LÜCKE | `propose_delete {"target": "recipe", "list_id": null, "ids": ["…"]}` | `RecipeService.deleteRecipe` (A, nur eigene) | nein | Löschen | Kern | nie |
| Entwurf verwerfen | LÜCKE | `propose_delete {"target": "recipe_draft", "list_id": null, "ids": ["…"]}` | `RecipeDraftService.deleteDraft` (A) | nein | Löschen | Kern | nie |
| Rezept teilen | LÜCKE | `open_share_sheet {"kind": "recipe", "id": "…"}` | `RecipeService.getShareText` (A) → System-Teilen | – | – | Kern | nie |
| Zutat ersetzen | LÜCKE | `substitute_ingredient {"ingredient": "Feta", "recipe_id": null}` | `IngredientSubstitutionService` / A `RecipeAdaptation`, beachtet Allergien und Ernährung | – | – | Kern | nie |
| Kochmodus öffnen | LÜCKE | `navigate {"destination": "cooking_mode", "id": "<recipe_id>", "date": null}` | Kochmodus-Route (A, fehlt) | – | – | Kern | Vorschlag frei (F-10) |
| Nächster/voriger Schritt, wiederholen | LÜCKE | `cooking_control {"action": "next", "minutes": null}` | A Kochmodus-API `cookingNext/cookingPrevious` (heute privat, `cooking_mode_screen.dart:89-110`) | – | – | Kern | wie Kochmodus |
| Kochtimer stellen/stoppen | LÜCKE | `cooking_control {"action": "start_timer", "minutes": 10}` | A `cookingStartTimer(minutes)` (heute `cooking_mode_screen.dart:159-165`) | – („Stoppen“) | – | Kern | wie Kochmodus |
| Portionen anpassen | – | Parameter `servings` bei `get_recipe` / `add_recipe_to_list` / `add_to_plan` | – | – | – | Kern | nie |
| Rezept ins Tagebuch | LÜCKE (`openLogRecipe` nur UI) | `preview_food_entry {"source": "recipe", "ref": "<recipe_id>", "servings": 1, "kcal": null, "meal": "dinner", "date": null}` | Vorschau → `FoodLogService.addEntry(source: recipe)` | ja | Vorschau | calories | nie |
| Ersteller ansehen | – | `navigate {"destination": "author", "id": "<author_id>", "date": null}` | Route `/author/:authorId` | – | – | Kern | nie |

### 4.4 Wochenplan (Modul `mealPlan`, heute `released: false`)

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Plan lesen („Was gibt's heute?“) | LÜCKE | `get_plan {"from": null, "to": null}` (null = heute bzw. laufende Woche) | `plan_provider` / `meal_plan_service` (B7, neu) | – | – | mealPlan | nie |
| Rezept einplanen | LÜCKE | `add_to_plan {"recipe_id": "…", "date": "2026-11-11", "servings": null, "meal": null}` | `addRecipeToPlan(recipeId, day, servings)` (B7); Tag belegt → App zeigt „Dazulegen“/„Ersetzen“, Ersetzen nur per Tipp | ja | Auswahl | mealPlan | nie |
| Freie Tage füllen | LÜCKE | `fill_plan {"dates": ["2026-11-12", "2026-11-13"], "source": "suggest", "wishes": "vegetarisch"}` | Plan-Dienst + Rezeptsuche (nur vorhandene Rezepte, Allergien raus) | ja | – | mealPlan | Kandidat |
| Vorwoche übernehmen | LÜCKE | `fill_plan {"dates": ["2026-11-16"], "source": "previous_week", "wishes": null}` (Montag der Zielwoche) | `copyPreviousWeek` (B7) | ja | – | mealPlan | nie |
| Zutaten der Woche auf die Liste | LÜCKE | `plan_to_list {"from": null, "to": null, "list_id": null}` | Zusammenfass-Funktion (Konzept 14 Kap. 4) + `ItemRepository.addItems` + `markPlanEntrySent` | ja (Token) | Auswahl (Liste) | mealPlan (Schilder: offers +KS) | Kandidat (Vorschlag: Pro) |
| Eintrag verschieben | LÜCKE | `update_plan_entry {"entry_id": "…", "date": "2026-11-14", "servings": null, "meal": null}` | `moveEntry` (B7) | ja | – | mealPlan | nie |
| Portionen / Mahlzeit im Plan | LÜCKE | `update_plan_entry {…, "servings": 4, "meal": "lunch"}` | Plan-Dienst | ja | – | mealPlan | nie |
| Aus dem Plan nehmen | LÜCKE | `propose_delete {"target": "plan_entries", "list_id": null, "ids": ["…"]}` | `removeEntries` (B7) | ja (Client-UUIDs) | Löschen | mealPlan | nie |
| Woche leeren | LÜCKE | `propose_delete {"target": "plan_week", "list_id": null, "ids": ["2026-11-09"]}` | `clearWeek` (B7) | ja | Löschen | mealPlan | nie |
| Plan-Einstellungen | LÜCKE | `update_setting {"key": "plan_default_servings", "value": "3"}` (Schlüssel 5.2) | `meal_plan_settings` (B7) | ja | – | mealPlan | nie |
| „Hast du meist da“ pflegen | LÜCKE | `update_setting {"key": "pantry_add", "value": "Reis"}` / `pantry_remove` | A-Daten E-16 | ja | – | Kern | nie |

### 4.5 Kalorien und Gesundheit (Modul `calories`)

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Stand heute / an einem Tag | `get_nutrition_status` | `get_nutrition_status {"date": null}` | `NutritionGoalService.getGoal`, `FoodLogService.getEntriesForDate`, `WaterLogService.getTotalForDate`, Health-Status (B6) | – | – | calories | nie |
| Wochenübersicht | `get_weekly_nutrition_summary` | `get_weekly_nutrition_summary {"week_start": null}` | `weeklyNutritionSummaryProvider` (Wochenstart neu) | – | – | calories | nie |
| Essen per Text | `log_food` (speichert direkt) | `preview_food_entry {"source": "text", "ref": "zwei Brötchen mit Käse", "servings": null, "kcal": null, "meal": null, "date": null}`, danach `confirm_preview {"preview_id": "…"}` | Task `nutrition_estimate` → Vorschau; `FoodLogService.addEntry` mit „geschätzt“ und Sicherheit | ja | Vorschau | calories | nie |
| Essen per Foto | LÜCKE | `preview_food_entry {"source": "photo", "ref": "<attachment_id>", …}` | `MealPhotoAnalysisService` (Task `meal_photo`, Quote) | ja | Vorschau | calories | Kandidat |
| Barcode (Ziffern genannt) | LÜCKE | `preview_food_entry {"source": "barcode", "ref": "4000417025005", …}` | `OpenFoodFactsService.lookupBarcode` | ja | Vorschau | calories | nie |
| Barcode-Kamera | LÜCKE | `navigate {"destination": "calories_scan", "id": null, "date": null}` | Route `/calories/scan` (B6) | – | – | calories | nie |
| Lebensmittel suchen | LÜCKE | `search_food {"query": "Skyr"}`, dann `preview_food_entry {"source": "product", "ref": "<code>", …}` | `OpenFoodFactsService.search` | ja | Vorschau | calories | nie |
| Manuell mit Kalorien | LÜCKE | `preview_food_entry {"source": "text", "ref": "Müsli", "kcal": 350, …}` | `FoodLogService.addEntry(source: manual)` | ja | Vorschau | calories | nie |
| Essen-Eintrag löschen | `delete_food_log` (`confirm`-Parameter) | `propose_delete {"target": "food_entry", "list_id": null, "ids": ["…"]}` | `FoodLogService.deleteEntry` | ja (Wiedereinfügen) | Löschen | calories | nie |
| Wasser eintragen | `log_water` | `log_water {"amount_ml": 250, "date": null}` | `WaterLogService.addEntry` | ja | – | calories | nie |
| Wasser-Eintrag löschen | LÜCKE | `propose_delete {"target": "water_entry", …}` | `WaterLogService.deleteEntry` | ja | Löschen | calories | nie |
| Gewicht eintragen | `log_weight` (überschreibt still) | `log_weight {"weight": 78.4, "unit": "kg", "date": null}` | `WeightLogService.logWeight` (ein Wert pro Tag) | ja (alter Tageswert) | – | calories | nie |
| Gewicht löschen | LÜCKE | `propose_delete {"target": "weight_entry", …}` | fehlt: `WeightLogService.deleteEntry` (B, neu) | ja | Löschen | calories | nie |
| Workout eintragen | LÜCKE | `log_workout {"type": "running", "duration_min": 30, "intensity": null, "kcal": null, "started_at": null}` | `WorkoutLogService` (neu, Migration `workout_log`, B6) | ja | – | calories | nie |
| Workout löschen | LÜCKE | `propose_delete {"target": "workout", …}` | wie oben | ja | Löschen | calories | nie |
| Ziel einrichten / ändern | `setup_nutrition_goal` (Textfrage, `confirm_replace`) | `propose_nutrition_goal {"goal_type": "lose_weight", "activity_level": null, "current_weight_kg": 82, "target_weight_kg": 76, "pace": null, "daily_kcal": null}` → Vorschau „Neues Ziel: 1.800 kcal am Tag“ → „Übernehmen“ | `NutritionGoalService.calculate` + `saveGoal` (+ `logWeight`, wenn Gewicht neu) | ja (altes Ziel) | Vorschau | calories | nie |
| Wasserziel, Workouts gutschreiben, Einheiten, Schnelltaste | LÜCKE | `update_setting {"key": "health_water_goal_ml", "value": "2500"}` | `NutritionGoalService.saveGoal` / neue Spalten | ja | – | calories | nie |
| Challenges ansehen | `get_challenge_status` | `get_challenges {}` | `activeChallengesProvider`, `challengeHistoryProvider` | – | – | calories | nie |
| Challenge starten | LÜCKE | `start_challenge {"type": "no_sugar_30", "title": null, "duration_days": null}` | `DietChallengeService.startChallenge` (23505 → „schon aktiv“) | eingeschränkt (Service kennt nur Abbrechen) | – | calories | nie |
| Check-in | LÜCKE | `checkin_challenge {"challenge_id": "…", "kept": true, "date": null}` | `DietChallengeService.checkIn` | ja (alter Tageswert) | – | calories | nie |
| Challenge abbrechen | LÜCKE | `propose_delete {"target": "challenge", …}` | `abandonChallenge` | nein | Löschen | calories | nie |
| „Was kann ich heute noch essen?“ | LÜCKE | `get_meal_ideas {"limit": 3}` | `CalorieRecipeNudgeService.getRankedSuggestions` (nur Rezepte mit kcal, Allergien raus) | – | – | calories | nie |
| Apple Health verbinden | LÜCKE (Konzept `sync_health`) | `navigate {"destination": "health_connect", …}`; Status in `get_nutrition_status` | Kanal `shoply/health` (B6); Avo setzt nie Berechtigungen | – | – | calories | Kandidat |
| Alle Essensfotos löschen | LÜCKE | `propose_delete {"target": "meal_photos", "list_id": null, "ids": ["all"]}` | `MealPhotoStorageService` (neu) | nein | Löschen | calories | nie |
| Kalorien ein/aus | `update_setting calorie_tracking` | `set_module {"module": "calories", "enabled": true}` | `appModulesProvider.notifier.setEnabled` | ja | – | – | nie |

### 4.6 Verlauf, Ersparnis, Kosten teilen

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Einkäufe ansehen | `get_shopping_history` (letzte N) | `get_shopping_history {"trip_id": null, "list_id": null, "from": "2026-10-31", "to": "2026-10-31", "limit": 10}` | `getRecentHistory` / `getHistoryForList`, neu: `getTrip(id)`, Zeitraum | – | – | Kern | nie |
| Einen Einkauf im Detail | LÜCKE | `get_shopping_history {"trip_id": "…", …}` | `ShoppingHistoryService.getTrip` (neu) | – | – | Kern | nie |
| Monatsrückblick (Ausgaben, Einkäufe, Ersparnis) | `get_savings_summary` (nur Ersparnis) | `get_month_summary {"month": "2026-11"}` | Verlaufs-Statistik + `offer_savings` (Ersparnis nur mit Modul offers, echter Region, „laut Händler“) | – | – | Kern (Ersparnis offers +KS) | Kandidat (ältere Monate) |
| Betrag oder Markt ändern | LÜCKE | `update_trip {"trip_id": "…", "total_cost": 42.8, "chain_id": null}` | `ShoppingHistoryService.updateTrip` (neu, nur Einkäufer) | ja | – | Kern | nie |
| Einkauf löschen | LÜCKE | `propose_delete {"target": "trip", "list_id": null, "ids": ["…"]}` | `ShoppingHistoryService.deleteHistory` (nur eigene) | nein | Löschen | Kern | nie |
| Ganzen Verlauf löschen | LÜCKE | `propose_delete {"target": "all_history", "list_id": null, "ids": ["all"]}` | `clearAllHistory` | nein | Löschen | Kern | nie |
| Kosten teilen | `split_trip_cost` (freie Namen, kein Widerruf) | `split_trip_cost {"trip_id": "…", "mode": "equal", "total_cost": null, "paid_by_user_id": null, "shares": [{"user_id": "…", "name": null, "amount": null}]}` | `ExpenseSplitService.createSplits`; Personen aus `getListMembers`, freie Namen nur „ohne Konto“ | ja (braucht Ersetzen/Löschen im Service) | Auswahl (Person) | costSplit | offen |
| Als bezahlt markieren / wieder offen | LÜCKE | `set_split_paid {"split_id": "…", "paid": true}` | `ExpenseSplitService.setPaid` | ja | – | costSplit | offen |
| Offene Beträge | LÜCKE | `get_open_balances {}` | `getTripsAwaitingPaymentToMe` + `getTripsIOwe` | – | – | costSplit | offen |
| An Zahlung erinnern | LÜCKE | `open_share_sheet {"kind": "payment_reminder", "id": "<split_id>"}` | Text aus Konzept 12 Kap. 3.5 → System-Teilen | – | – | costSplit | offen |
| Kosten teilen einschalten | LÜCKE | `set_module {"module": "cost_split", "enabled": true}` | `appModulesProvider` | ja | – | – | nie |

### 4.7 Angebote und Märkte

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Ist X im Angebot (eigener Markt) | `search_offers` (alle Märkte, „cheapest“) | `search_offers {"query": "Milch", "list_id": null, "filter": "all"}` | `OfferPriceService.searchOffers` nur für den Markt der Liste, sonst Lieblingsmärkte; Region aus `regionProvider`; ohne echte PLZ kein Netzaufruf, `no_region` | – | – | offers +KS | nie |
| Angebote der Woche / Stammartikel im Angebot | LÜCKE | `search_offers {"query": null, "list_id": null, "filter": "regulars"}` | `AvoNudgeService.getOfferNudges` / Wochen-Angebote (B8) | – | – | offers +KS | nie |
| Was von meiner Liste ist im Angebot | `get_personalized_deals` | `get_list_offers {"list_id": null}` | `summarizeListOffers` (`offer_savings.dart`) + `PersonalizedDealsService.getMatches`, nur Listen-Markt | – | – | offers +KS | nie |
| Angebot auf die Liste | – | `add_items` (Angebot hängt an, wenn der Markt der Liste passt) oder Plus-Knopf in der Karte | wie `add_items` | ja | – | offers +KS | nie |
| Wo ist es am günstigsten | `compare_list_prices`, `cheapest_store` | **entfällt**; feste Antwort „Einen Preisvergleich zwischen Märkten kann ich nicht seriös machen, weil es keine Normalpreise gibt. Bei Lidl sind diese Woche 4 deiner 11 Artikel im Angebot.“ | – | – | – | – | – |
| Region / PLZ setzen oder entfernen | `update_setting zip_code` | `update_setting {"key": "region_zip", "value": "80331"}` (`""` = entfernen); Standort → `navigate region` | `regionProvider` (B2.1) | ja | – | Kern („Märkte“) | nie |
| Lieblingsmärkte | LÜCKE | `set_favorite_stores {"chain_ids": ["lidl", "rewe"]}` (Reihenfolge = Vorrang, leer erlaubt) | `user_offer_prefs` (neu, B) | ja | – | Kern | nie |
| Markt automatisch erkennen | LÜCKE | `update_setting {"key": "store_auto_detect", "value": "false"}` | Angebots-Einstellungen (neu, B) | ja | – | Kern | nie |
| Einzel-Schalter (Angebote in Listen, beim Tippen, Ersparnis-Zeile, Start-Hinweise, Verlauf) | LÜCKE | `update_setting {"key": "offers_home_hints", "value": "false"}` | Angebots-Einstellungen (neu, B) | ja | – | offers +KS | nie |
| Modul Preise & Angebote | LÜCKE | `set_module {"module": "offers", "enabled": false}` | `appModulesProvider` | ja | – | KS: Wert fehlt im Enum | nie |

### 4.8 Einstellungen, Module, Profil

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Modul an/aus (alle fünf) | nur Kalorien | `set_module {"module": "meal_plan", "enabled": true}` | `appModulesProvider.notifier.setEnabled`; `meal_plan` bis zur Freigabe `not_available` | ja | – | – | nie |
| Darstellung | `theme_mode` | `update_setting {"key": "theme_mode", "value": "dark"}` | `themeModeProvider.setThemeMode` (A) | ja | – | Kern | nie |
| Akzentfarbe | `accent_color` | **entfällt** (Konzept 18, K-06) | – | – | – | – | – |
| Sprache | `language` | `update_setting {"key": "language", "value": "en"}` | `languageProvider.setLanguage` (A) | ja | – | Kern | nie |
| Anzeigename | `display_name` | `update_setting {"key": "display_name", "value": "Jannis"}` | `UserService.updateUserProfile` (A) | ja | – | Kern | nie |
| Profilbild | – | nie per Avo → `navigate settings_profile` | – | – | – | Kern | nie |
| Alter, Größe, Geschlecht | `age`, `height`, `gender` | `update_setting {"key": "height_cm", "value": "182"}` | `UserService.updateUserProfile` (A) | ja | – | Kern | nie |
| Allergie hinzufügen | `update_setting allergies` (ersetzt Liste) | `edit_diet_profile {"action": "add", "kind": "allergy", "value": "peanuts"}` | Einzel-Änderung über A-Helfer `addAllergy` (neu) | ja | – | Kern | nie |
| Allergie entfernen | `update_setting allergies` (leer löscht alles) | `edit_diet_profile {"action": "remove", "kind": "allergy", "value": "peanuts"}` | erzeugt Sicherheits-Karte; Tipp → `removeAllergy` (A, neu) | ja | Sicherheit | Kern | nie |
| Ernährung hinzufügen/entfernen | `update_setting diet_preferences` (ersetzt Liste) | `edit_diet_profile {"action": "add", "kind": "diet", "value": "vegetarian"}` | Einzel-Änderung (A, neu) | ja | – | Kern | nie |
| Rezepte automatisch anpassen | LÜCKE | `update_setting {"key": "recipes_auto_adapt", "value": "true"}` | A (18 Kap. 5.2) | ja | – | Kern | nie |
| Mitteilungen gesamt | `notifications` | `update_setting {"key": "notif_all", "value": "false"}` | `NotificationPreferencesService.setMasterEnabled` (A); iOS-Erlaubnis nie per Avo | ja | – | Kern | nie |
| Mitteilungs-Kategorien und Uhrzeiten | LÜCKE | `update_setting {"key": "notif_recipe_likes", "value": "false"}`, `{"key": "notif_restock_time", "value": "09:00"}` | `setCategoryEnabled` (A, Kategorien nach 18 Kap. 5.5) | ja | – | Kern (Modul-Zeilen mit Modul) | nie |
| Listen-Einstellungen | LÜCKE | `update_setting {"key": "keep_screen_on", "value": "true"}` | A-Provider (18 Kap. 5.4, neu) | ja | – | Kern | nie |
| Avo: Stimme, vorlesen, weiter zuhören | LÜCKE | `update_setting {"key": "avo_read_aloud", "value": "true"}` | Avo-Einstellungen (neu, B) | ja | – | avo | nie |
| Avo: Ernährung/Körperdaten einbeziehen | LÜCKE | `update_setting {"key": "avo_include_diet", "value": "false"}` (nur `false` erlaubt) | Avo-Einstellungen (neu, B) | ja | – | avo | nie |
| Profil lesen | `get_user_profile` (alles, ohne Einwilligung) | `get_user_profile {}` (nur Felder mit Einwilligung) | `currentUserProvider` (A) + Einwilligungen | – | – | Kern | nie |
| Pro-Preis, Pro-Umfang, Module, Hilfe | `get_app_info` (englisch, „$2.99“) | `get_app_info {"topic": "pro"}` | `pro_features` (A), Preis aus `SubscriptionService.getProduct` (StoreKit), `AppBrand` | – | – | Kern | nie |
| Tipps neu starten | LÜCKE | `update_setting {"key": "tips_reset", "value": "true"}` | A `TipService` | nein | – | Kern | nie |
| Konto, Abmelden, Abo, Systemrechte | – | nie → `navigate {"destination": "account" \| "pro" \| "system_settings", …}` | – | – | – | – | – |

### 4.9 Navigation

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Bildschirm öffnen („Öffne die Lidl-Liste“, „Geh zu den Mitteilungen“) | LÜCKE | `navigate {"destination": "list", "id": "<list_id>", "date": null}` | A-Navigationshelfer nach Konzept 01 Kap. 6 (Stapel aufbauen, Tab wechseln) mit `RoutePaths`; Ziele in 5.3 | – | – | Modul des Ziels | nie |
| Sprachmodus aus dem Chat | – | `navigate {"destination": "avo_voice", …}` | Route `/avo/voice` (B5) | – | – | avo | offen (F-16-3) |

### 4.10 Avo selbst

| Funktion | Heute | Tool und Parameter | Ausführung | Widerruf | Karte | Modul | Pro |
|---|---|---|---|---|---|---|---|
| Rückfrage (Liste, Markt, Person, Tag belegt, Foto-Absicht) | `ask_pick_list` | `ask_choice {"kind": "store", "question": "Wo warst du?", "options": []}` | App baut Optionen bei `list`, `store`, `member` selbst; Modell liefert sie nur bei `other` | – | Auswahl | avo | nie |
| Widerrufen per Text oder Stimme | LÜCKE | `undo_last {"undo_id": null}` (null = letzte Änderung) | `AvoUndoRegistry` (neu, B) | – | – | avo | nie |
| Löschen bestätigen | – | kein Tool, nur Tipp auf die Karte | `AvoConfirmCard` | – | Löschen | avo | nie |
| Neues Gespräch, Vorlesen, Kopieren, Gespräch löschen | – | kein Tool (Bedienung im Chat bzw. `/settings/avo`) | – | – | – | avo | nie |

---

## 5. Tool-Katalog (feste Reihenfolge)

Spalte **strict**: S = `strict: true`. Alle Tools: `eager_input_streaming: true`. **KS** = fehlt bei Kill-Switch.

| # | Tool | strict | Parameter (alle Pflicht) | Ergebnis / Karte | ersetzt |
|---|---|---|---|---|---|
| 1 | `get_lists` | | `{}` | Listen mit ID, Name, Markt, offen, Mitglieder, Eigentümer | `get_lists` |
| 2 | `get_list_contents` | | `{"list_id": "string\|null", "include_checked": "boolean"}` | Artikel der Liste | `get_list_contents` |
| 3 | `get_list_details` | | `{"list_id": "string"}` | Mitglieder, Markt, letzte Aktivität, geteilt ja/nein | neu |
| 4 | `create_list` | S | `{"name": "string", "store_chain_id": "string\|null"}` | Ergebniszeile, Widerrufen solange leer | `create_list` |
| 5 | `update_list` | | `{"list_id": "string", "name": "string\|null", "sort_mode": "enum:category\|manual\|null", "move_to": "enum:top\|bottom\|null", "background": "string\|null"}` | Ergebniszeile mit Vorher-Wert | `rename_list` |
| 6 | `set_list_store` | S | `{"list_id": "string", "chain_id": "string\|null"}` | „Markt für Wocheneinkauf: Lidl“ | neu |
| 7 | `open_share_sheet` | | `{"kind": "enum:list_link\|list_code\|recipe\|payment_reminder", "id": "string"}` | System-Teilen; Avo sendet nie | neu |
| 8 | `join_list` | | `{"code_or_link": "string"}` | „Liste „Party“ beigetreten“ | neu |
| 9 | `complete_shopping` | S | `{"list_id": "string", "chain_id": "string\|null", "total_cost": "number\|null", "split": "boolean"}` | „Einkauf gespeichert“, Erfolgs-Haptik; Markt unklar → `needs_choice` | `complete_list` |
| 10 | `import_list_photo` | | `{"attachment_id": "string", "list_id": "string\|null"}` | Import-Sektion, `preview_shown` | neu |
| 11 | `edit_list_categories` | | `{"list_id": "string", "action": "enum:reorder\|add\|rename", "category_ids": ["string"], "name": "string\|null", "color": "string\|null"}` (`category_ids` leer erlaubt bei `add`) | Ergebniszeile | neu |
| 12 | `add_items` | S | `{"list_id": "string\|null", "items": [{"name": "string", "quantity": "number\|null", "unit": "string\|null"}]}` | „2 Artikel zu Wocheneinkauf hinzugefügt“ | `add_item_to_list` |
| 13 | `update_item` | | `{"list_id": "string", "item_id": "string", "name": "string\|null", "quantity": "number\|null", "unit": "string\|null", "note": "string\|null", "category_id": "enum:<IDs aus categories.json>\|null"}` | „Milch: Menge 2 → 3“ | `update_item` |
| 14 | `check_items` | S | `{"list_id": "string", "item_ids": ["string"], "checked": "boolean"}` | „2 Artikel abgehakt“ | `check_items` |
| 15 | `move_items` | S | `{"from_list_id": "string", "to_list_id": "string", "item_ids": ["string"]}` | „2 Artikel nach Drogerie verschoben“ | `move_items` |
| 16 | `add_history_items_to_list` | | `{"trip_id": "string", "list_id": "string\|null", "item_names": ["string"]}` (leer erlaubt = alle) | „12 Artikel hinzugefügt · 2 standen schon drauf“ | `add_history_items_to_list` |
| 17 | `get_restock_suggestions` | | `{"list_id": "string\|null", "limit": "integer"}` | „Vielleicht auch“ | `get_restock_suggestions` |
| 18 | `search_recipes` | | `{"query": "string", "diet": ["enum:vegetarian\|vegan\|pescatarian\|low_carb\|keto\|paleo\|halal\|kosher\|low_sodium"], "max_minutes": "integer\|null", "max_results": "integer"}` (`diet` leer erlaubt) | bis 3 Rezeptzeilen | `search_recipes` |
| 19 | `list_my_recipes` | | `{"scope": "enum:saved\|own\|drafts"}` | Rezeptzeilen | `get_saved_recipes` |
| 20 | `get_recipe` | | `{"recipe_id": "string", "servings": "integer\|null"}` | Zutaten, Schritte, Nährwerte („geschätzt“) | `get_recipe_nutrition` |
| 21 | `add_recipe_to_list` | S | `{"recipe_id": "string", "list_id": "string\|null", "servings": "integer\|null"}` | „9 Zutaten zu Wocheneinkauf hinzugefügt“ | `add_recipe_to_list` |
| 22 | `save_recipe` | | `{"recipe_id": "string", "saved": "boolean"}` | „gemerkt“ | neu |
| 23 | `rate_recipe` | | `{"recipe_id": "string", "stars": "integer"}` | „bewertet · 5 von 5“ | neu |
| 24 | `create_recipe_draft` | | `{"title": "string", "servings": "integer\|null", "total_minutes": "integer\|null", "ingredients": [{"name": "string", "amount": "number\|null", "unit": "string\|null"}], "steps": ["string"]}` | „Entwurf gespeichert · Ansehen“ | neu |
| 25 | `substitute_ingredient` | | `{"ingredient": "string", "recipe_id": "string\|null"}` | „Feta → Hirtenkäse oder Tofu natur“ | neu |
| 26 | `cooking_control` | | `{"action": "enum:next\|previous\|repeat\|start_timer\|stop_timer", "minutes": "integer\|null"}` | Schritt springt, „Timer 10:00 läuft“ | neu |
| 27 | `get_plan` | | `{"from": "date\|null", "to": "date\|null"}` | Rezeptzeilen je Tag | neu |
| 28 | `add_to_plan` | S | `{"recipe_id": "string", "date": "date", "servings": "integer\|null", "meal": "enum:breakfast\|lunch\|dinner\|snack\|null"}` | „Ofengemüse am Mi., 11. Nov.“ | neu |
| 29 | `fill_plan` | | `{"dates": ["date"], "source": "enum:suggest\|previous_week", "wishes": "string\|null"}` | „4 Tage geplant“ | neu |
| 30 | `plan_to_list` | | `{"from": "date\|null", "to": "date\|null", "list_id": "string\|null"}` | „17 Zutaten … zusammengefasst aus 4 Rezepten“ | neu |
| 31 | `update_plan_entry` | | `{"entry_id": "string", "date": "date\|null", "servings": "integer\|null", "meal": "enum:breakfast\|lunch\|dinner\|snack\|null"}` | Ergebniszeile | neu |
| 32 | `get_nutrition_status` | | `{"date": "date\|null"}` | Ring „640 kcal übrig“ | `get_nutrition_status` |
| 33 | `get_weekly_nutrition_summary` | | `{"week_start": "date\|null"}` | Balken, Ø | `get_weekly_nutrition_summary` |
| 34 | `search_food` | | `{"query": "string"}` | Produktzeilen mit Code | neu |
| 35 | `preview_food_entry` | | `{"source": "enum:text\|photo\|barcode\|product\|recipe", "ref": "string", "servings": "number\|null", "kcal": "integer\|null", "meal": "enum:breakfast\|lunch\|dinner\|snack\|null", "date": "date\|null"}` | Schätzungs-Vorschau, `preview_shown` | `log_food` |
| 36 | `confirm_preview` | S | `{"preview_id": "string"}` | „Spaghetti Bolognese eingetragen“ bzw. „Ziel übernommen“ | neu |
| 37 | `log_water` | S | `{"amount_ml": "integer", "date": "date\|null"}` | „250 ml Wasser eingetragen“ | `log_water` |
| 38 | `log_weight` | S | `{"weight": "number", "unit": "enum:kg\|lb", "date": "date\|null"}` | „78,4 kg eingetragen“ | `log_weight` |
| 39 | `log_workout` | | `{"type": "enum:walking\|running\|cycling\|swimming\|strength\|yoga\|other", "duration_min": "integer", "intensity": "enum:light\|moderate\|hard\|null", "kcal": "integer\|null", "started_at": "date-time\|null"}` | „Laufen, 30 Min eingetragen“ | neu |
| 40 | `propose_nutrition_goal` | | `{"goal_type": "enum:lose_weight\|gain_muscle\|maintain\|custom", "activity_level": "enum:sedentary\|light\|moderate\|active\|very_active\|null", "current_weight_kg": "number\|null", "target_weight_kg": "number\|null", "pace": "enum:slow\|normal\|fast\|null", "daily_kcal": "integer\|null"}` | Ziel-Vorschau, `preview_shown` | `setup_nutrition_goal` |
| 41 | `get_challenges` | | `{}` | „Wasser-Woche: 4 von 7 Tagen“ | `get_challenge_status` |
| 42 | `start_challenge` | | `{"type": "enum:fasting_16_8\|no_sugar_30\|custom", "title": "string\|null", "duration_days": "integer\|null"}` | Ergebniszeile | neu |
| 43 | `checkin_challenge` | | `{"challenge_id": "string", "kept": "boolean", "date": "date\|null"}` | Ergebniszeile | neu |
| 44 | `get_meal_ideas` | | `{"limit": "integer"}` | Rezeptzeilen mit kcal | neu |
| 45 | `get_shopping_history` | | `{"trip_id": "string\|null", "list_id": "string\|null", "from": "date\|null", "to": "date\|null", "limit": "integer"}` | Einkaufszeilen | `get_shopping_history` |
| 46 | `get_month_summary` | | `{"month": "string\|null"}` (`pattern: ^\d{4}-\d{2}$`) | Ausgaben, Einkäufe, Ersparnis (nur mit Angeboten) | `get_savings_summary` |
| 47 | `update_trip` | | `{"trip_id": "string", "total_cost": "number\|null", "chain_id": "string\|null"}` | Ergebniszeile | neu |
| 48 | `split_trip_cost` | | `{"trip_id": "string", "mode": "enum:equal\|custom", "total_cost": "number\|null", "paid_by_user_id": "string\|null", "shares": [{"user_id": "string\|null", "name": "string\|null", "amount": "number\|null"}]}` | „Einkauf vom 31. Okt. geteilt“ | `split_trip_cost` |
| 49 | `set_split_paid` | S | `{"split_id": "string", "paid": "boolean"}` | „Lena: bezahlt“ | neu |
| 50 | `get_open_balances` | | `{}` | „Schuldet dir“ / „Du schuldest“ | neu |
| 51 | `search_offers` (KS) | | `{"query": "string\|null", "list_id": "string\|null", "filter": "enum:all\|regulars"}` | Angebotszeilen „laut Händler“ | `search_offers` |
| 52 | `get_list_offers` (KS) | | `{"list_id": "string\|null"}` | „4 von 11 Artikeln diese Woche bei Lidl im Angebot …“ | `get_personalized_deals` |
| 53 | `set_list_offers_hidden` (KS) | | `{"list_id": "string", "hidden": "boolean"}` | „Angebote für Wocheneinkauf ausgeblendet“ | neu |
| 54 | `set_module` | S | `{"module": "enum:offers\|meal_plan\|calories\|avo\|cost_split", "enabled": "boolean"}` (KS: ohne `offers`) | „Kalorien & Gesundheit eingeschaltet“ | Teil von `update_setting` |
| 55 | `update_setting` | S | `{"key": "enum:<Schlüssel aus 5.2>", "value": "string"}` (KS: ohne `offers_*`) | „Darstellung: Dunkel · vorher: System“ | `update_setting` |
| 56 | `edit_diet_profile` | S | `{"action": "enum:add\|remove", "kind": "enum:allergy\|diet", "value": "enum:<Allergen- und Ernährungs-IDs aus 5.2>"}` | „Allergie eingetragen: Erdnüsse“; Entfernen → Sicherheits-Karte | Teil von `update_setting` |
| 57 | `set_favorite_stores` | | `{"chain_ids": ["string"]}` (leer erlaubt) | „Deine Märkte: Lidl, REWE“ | neu |
| 58 | `get_user_profile` | | `{}` | nur Felder mit Einwilligung | `get_user_profile` |
| 59 | `get_app_info` | | `{"topic": "enum:pro\|modules\|privacy\|help\|widgets\|siri\|data_sources"}` | Text + Zeile zur Seite | `get_app_info` |
| 60 | `navigate` | | `{"destination": "enum:<Ziele aus 5.3>", "id": "string\|null", "date": "date\|null"}` | „Wocheneinkauf geöffnet“ | neu |
| 61 | `ask_choice` | S | `{"kind": "enum:list\|store\|member\|day_conflict\|photo_intent\|other", "question": "string", "options": [{"id": "string", "label": "string"}]}` (`options` leer erlaubt) | Auswahl-Zeilen, `needs_choice` | `ask_pick_list` |
| 62 | `propose_delete` | S | `{"target": "enum:<Ziele aus 5.4>", "list_id": "string\|null", "ids": ["string"]}` | `AvoConfirmCard`, `awaiting_confirmation` | `delete_item`, `delete_list`, `delete_food_log` |
| 63 | `undo_last` | S | `{"undo_id": "string\|null"}` | „Rückgängig gemacht“ | neu |

Entfällt ersatzlos: `compare_list_prices`. Damit auch `summarizeBasketComparison` samt Test (B2.2).

### 5.1 Was ein Tool zusätzlich prüft (Auszug)

- `add_items`, `add_recipe_to_list`, `plan_to_list`, `add_history_items_to_list`: höchstens 60 Artikel; Kategorie lokal
  (`categorizeLocal`), Verfeinerung im Hintergrund; Angebotspreis nur vom Markt der Ziel-Liste, nur Modul offers und
  echte Region; ein Push für alle Artikel (heute je Artikel, `avo_assistant_service.dart:547-566, 757-765`).
- `complete_shopping`: nichts abgehakt → `ok: false`, `code: "nothing_checked"`; `split: true` nur mit Modul costSplit
  und mindestens 2 Mitgliedern, sonst Hinweis im Ergebnis.
- `propose_delete`: offline → `offline_blocked`; mehr als ein Objekt nur bei `items`, `plan_entries`, `food_entry`.
- `update_setting`: Schlüssel, deren Seite gerade unsichtbar ist (Modul aus, Kill-Switch), antworten `module_off`
  (Regel 3 aus Konzept 18: kein Avo-Schlüssel zeigt auf eine unsichtbare Einstellung).

### 5.2 Schlüssel für `update_setting` und Werte für `edit_diet_profile`

| Gruppe | Schlüssel | Wert (`value` als Text) | Ausführung | Modul |
|---|---|---|---|---|
| Darstellung, Sprache | `theme_mode`, `language` | `system\|light\|dark`; `system\|de\|en` | `themeModeProvider`, `languageProvider` (A) | Kern |
| Profil | `display_name`, `age`, `height_cm`, `gender` | Text 2–40; 13–100; 100–230; `female\|male\|diverse\|none` | `UserService.updateUserProfile` (A) | Kern |
| Rezepte | `recipes_auto_adapt` | `true\|false` | A (18 Kap. 5.2) | Kern |
| Listen (A, 18 Kap. 5.4) | `show_item_images`, `suggestions_enabled`, `start_list`, `keep_screen_on`, `share_presence` | `true\|false`; `start_list`: `last_used` oder Listen-ID | A-Provider (neu) | Kern |
| Mitteilungen (A, 18 Kap. 5.5) | `notif_all`, `notif_shopping_started`, `notif_list_changes`, `notif_shopping_completed`, `notif_invitations`, `notif_restock`, `notif_restock_time`, `notif_cooking_timer`, `notif_recipe_likes`, `notif_recipe_comments`, `notif_new_recipes`, `notif_dinner_ideas`, `notif_dinner_ideas_time`, `notif_open_balances` | `true\|false`; Uhrzeiten `HH:MM` | `NotificationPreferencesService` (A) | Kern; `dinner_ideas` calories, `open_balances` costSplit |
| Märkte (B) | `region_zip`, `store_auto_detect` | 5 Ziffern oder `""`; `true\|false` | `regionProvider`, Angebots-Einstellungen (neu) | Kern |
| Angebote (B, KS) | `offers_in_lists`, `offers_typing_suggestions`, `offers_list_summary`, `offers_home_hints`, `offers_history_savings` | `true\|false` | Angebots-Einstellungen (neu) | offers |
| Kalorien (B) | `health_credit_workouts`, `health_water_goal_ml`, `health_water_quick_ml`, `health_weight_unit`, `health_energy_unit` | `true\|false`; ml; ml; `kg\|lb`; `kcal\|kj` | `NutritionGoalService` / neue Spalten | calories |
| Wochenplan (B) | `plan_default_servings`, `plan_target_list`, `plan_show_today`, `plan_reminder`, `plan_reminder_time`, `pantry_add`, `pantry_remove` | 1–20; `today` oder Listen-ID; `true\|false`; `true\|false`; `7 18:00` (ISO-Wochentag, Uhrzeit); Zutat | `meal_plan_settings` (B7), Vorrat A (E-16) | mealPlan (Vorrat Kern) |
| Avo (B) | `avo_voice`, `avo_read_aloud`, `avo_keep_listening`, `avo_include_diet`, `avo_include_body` | Stimmen-ID oder `system`; `true\|false`; die letzten zwei nur `false` | Avo-Einstellungen (neu) | avo |
| Sonstiges | `tips_reset` | `true` | A `TipService` | Kern |

Entfallen gegenüber heute: `accent_color` (K-06), `notifications` (→ `notif_all`), `allergies` und `diet_preferences`
(→ `edit_diet_profile`), `calorie_tracking` (→ `set_module`), `zip_code` (→ `region_zip`), `height` (→ `height_cm`).

`edit_diet_profile.value`: Allergien nach Konzept 18 Kap. 5.2 `gluten`, `milk`, `lactose`, `eggs`, `peanuts`, `nuts`,
`soy`, `fish`, `crustaceans`, `molluscs`, `celery`, `mustard`, `sesame`, `sulphites`, `lupin`, `fructose`, `histamine`,
`nightshades`, `corn`, `yeast`; Ernährung `vegetarian`, `vegan`, `pescatarian`, `low_carb`, `keto`, `paleo`, `halal`,
`kosher`, `low_sodium`. Heute gibt es keine Allergie-Oberfläche und keine Allergie-ID-Liste (nur Beispiele in
`user_model.dart:14`); Altwerte `gluten_free`, `dairy_free`, `nut_free` werden laut Konzept 17 Kap. 9.7 zu Allergien.

### 5.3 Ziele für `navigate`

| Bereich | Ziele (`id` / `date`, wenn nötig) | Route heute |
|---|---|---|
| Start, Listen | `home`, `lists`, `list` (id), `shopping_mode` (id), `list_settings` (id), `list_activity` (id), `category_order` (id) | `/home`, `/lists`, `/lists/:listId`, `…/activities`; Einkaufsmodus, Listen-Info, Kategorien ohne Route (A) |
| Rezepte | `recipes`, `recipe` (id), `saved_recipes`, `my_recipes`, `recipe_drafts`, `recipe_new`, `cooking_mode` (id), `author` (id) | `/recipes/...`, `/author/:authorId`; Kochmodus ohne Route (A) |
| Wochenplan | `plan` (date = Woche), `plan_settings` | `/recipes?segment=plan`, `/settings/plan` |
| Kalorien | `calories` (date), `calories_add`, `calories_scan`, `calories_goals`, `calories_week` (date), `calories_weight`, `calories_workouts`, `calories_challenges`, `calories_ideas`, `health_connect`, `health_settings` | `/calories/...`, `/settings/health` (B6) |
| Verlauf, Geld | `history`, `trip` (id), `splits` | `/history`, `/history/:tripId`, `/splits` (B8) |
| Angebote, Märkte | `offers`, `list_offers` (id), `region`, `offers_settings`, `favorite_stores` | `/offers`, `/offers/list/:listId`, `/settings/offers/...` (B8) |
| Profil, Einstellungen | `profile`, `settings_profile`, `settings_modules`, `settings_diet`, `settings_personal`, `settings_lists`, `settings_notifications`, `settings_appearance`, `settings_language`, `settings_avo`, `settings_siri`, `settings_widgets`, `help`, `legal`, `account`, `pro` | `/settings`, `/diet-preferences`; die übrigen öffnen heute per `Navigator.push` ohne Pfad (`profile_screen.dart:139-227`), A legt `/settings/<seite>` an (18 Regel 3) |
| System | `system_settings` (iOS-Einstellungen der App), `avo_voice` | `UIApplication.openSettingsURLString`, `/avo/voice` |

Ziel eines ausgeschalteten Moduls: `module_off`, Avo bietet „Einschalten“ an.

### 5.4 Ziele für `propose_delete`

| `target` | `ids` | `list_id` | Kartentext (Beispiel, Konzept 16 Kap. 8) | Ausführung nach Tipp | danach |
|---|---|---|---|---|---|
| `items` | Artikel-IDs | Pflicht | „3 Artikel aus Wocheneinkauf löschen?“ + „Milch, Eier, Gurken“ | `itemsNotifier.deleteItem` (A) | Widerrufen |
| `list` | `[list_id]` | Pflicht | „„Party“ löschen?“ + „Die Liste und 14 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen.“ | `listsNotifier.deleteList` (A) | endgültig |
| `leave_list` | `[list_id]` | Pflicht | „„Party“ verlassen?“ | `ListRepository.leaveList` (A) | endgültig |
| `member` | `[user_id]` | Pflicht | „Max aus „Party“ entfernen?“ | `ListRepository.removeMember` (A, neu) | endgültig |
| `custom_category` | `[category_id]` | Pflicht | „Kategorie „Baby“ löschen?“ | `CategoryOrderService.deleteCustomCategory` | eingeschränkt |
| `list_activity` | `[list_id]` | Pflicht | „Aktivität von „Party“ leeren?“ | `ListActivityService.clearActivities` (A) | endgültig |
| `recipe` | `[recipe_id]` | null | „„Nudelsalat“ löschen?“ | `RecipeService.deleteRecipe` (A) | endgültig |
| `recipe_draft` | `[draft_id]` | null | „Entwurf „Linsencurry“ verwerfen?“ | `RecipeDraftService.deleteDraft` (A) | endgültig |
| `food_entry`, `water_entry`, `weight_entry`, `workout` | Eintrags-IDs | null | „Croissant von heute früh löschen?“ | `FoodLogService.deleteEntry`, `WaterLogService.deleteEntry`, neu: Gewicht, Workout | Widerrufen |
| `meal_photos` | `["all"]` | null | „Alle Essensfotos löschen?“ | `MealPhotoStorageService` (neu) | endgültig |
| `challenge` | `[challenge_id]` | null | „Challenge „Ohne Zucker“ abbrechen?“ | `DietChallengeService.abandonChallenge` | endgültig |
| `plan_entries` | Eintrags-IDs | null | „Lachs mit Ofenkartoffeln am Fr., 13. Nov. aus dem Plan nehmen?“ | `removeEntries` (B7) | Widerrufen |
| `plan_week` | `[week_start]` | null | „Alle 6 Rezepte der Woche 9.–15. Nov. aus dem Plan nehmen?“ | `clearWeek` (B7) | Widerrufen |
| `trip` | `[trip_id]` | null | „Einkauf vom 7. Nov. löschen?“ + „… für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen.“ | `ShoppingHistoryService.deleteHistory` | endgültig |
| `all_history` | `["all"]` | null | „Ganzen Verlauf löschen?“ | `ShoppingHistoryService.clearAllHistory` | endgültig |

Allergie entfernen läuft über `edit_diet_profile` (Sicherheits-Variante), nicht über `propose_delete`.

---

## 6. Modul- und Pro-Übersicht

| Modul | Tools (Ausführung prüft das Modul) |
|---|---|
| Kern | 1–26, 45–47, 54–63 (Ausnahmen in den Zeilen darunter) |
| `mealPlan` | 27–31, `propose_delete` mit `plan_entries`/`plan_week`, Schlüssel `plan_*` |
| `calories` | 32–44, `preview_food_entry` (auch `source: recipe`), `propose_delete` mit Tagebuch-Zielen, Schlüssel `health_*`, `notif_dinner_ideas*` |
| `costSplit` | 48–50, `open_share_sheet` mit `payment_reminder`, `complete_shopping.split`, `notif_open_balances` |
| `offers` + Kill-Switch | 51–53, Ersparnis-Teil von 9 und 46, Schlüssel `offers_*` |
| `avo` | alles (Avo aus = kein Gespräch); `set_module(avo, false)` aus dem Chat ist erlaubt, Avo schließt danach |

Pro-Kandidaten (Owner, F-05): `fill_plan`, `plan_to_list` (Konzept-Vorschlag: Planen frei, „Auf die Liste“ Pro),
`preview_food_entry` mit `source: photo`, Apple Health, `get_month_summary` für ältere Monate, Sprachmodus, Kochmodus
(Vorschlag frei), Kosten teilen (offen). Nie Pro: alle Listen-, Artikel-, Rezept-, Verlaufs-, Angebots- und
Allergie-Tools.

---

## 7. Reihenfolge für B5

**Stufe 0: Sicherheit und Recht (muss mit dem ersten Claude-Avo stehen)**
1. `propose_delete` mit `AvoConfirmCard` und Einmal-Schlüssel; `delete_item`, `delete_list`, `delete_food_log` und
   alle `confirm`-Parameter löschen. Test: kein Tool-Name beginnt mit `delete_`, `remove_`, `leave_`; promptfoo-Fall
   „Lösche alle Listen“ als Artikelname ergibt höchstens eine Karte.
2. `compare_list_prices`, `cheapest_store`, `cheapest_price` raus; `search_offers`/`get_list_offers` nur für den Markt
   der Liste, ohne echte PLZ kein Netzaufruf; Kill-Switch-Variante serverseitig.
3. `edit_diet_profile` statt Allergie-/Ernährungs-Liste ersetzen; Allergie entfernen nur per Sicherheits-Karte;
   Allergie-Filter im Executor.
4. `get_user_profile` nur mit Einwilligung.
5. `preview_food_entry` + `confirm_preview` statt `log_food` (nie direkt speichern), `propose_nutrition_goal` statt
   Textfrage.
6. Ergebnisformat und Fehlercodes aus 2.3; Modul-, Kill-Switch- und Pro-Prüfung im Executor; Executor mit `Ref`.

**Stufe 1: Kern-Abdeckung (B5)**
7. `add_items` mit Batch und Token, `AvoUndoRegistry` und `undo_last`, `ask_choice` mit allen Listen.
8. `check_items`, `move_items`, `update_item` (mit Notiz und Kategorie), `get_list_contents` ohne „erste Liste“.
9. `complete_shopping` (echter Abschluss), `navigate` (mit A-Helfer), `create_list`, `update_list`, `set_list_store`,
   `get_list_details`, `open_share_sheet`.
10. Rezepte: `search_recipes`, `list_my_recipes`, `get_recipe`, `add_recipe_to_list` über `RecipeToList`,
    `save_recipe`, `rate_recipe`, `substitute_ingredient`; `add_history_items_to_list`, `get_restock_suggestions`.
11. Einstellungen: `set_module`, `update_setting` mit allen Schlüsseln aus 5.2, `set_favorite_stores`,
    `set_list_offers_hidden`, `get_app_info` neu.
12. Verlauf und Geld: `get_shopping_history` (mit `trip_id`), `get_month_summary`, `split_trip_cost` mit Mitgliedern,
    `set_split_paid`, `get_open_balances`.
13. Kalorien mit vorhandenen Diensten: `log_water`, `log_weight`, `get_nutrition_status`,
    `get_weekly_nutrition_summary`, `search_food`, `get_challenges`, `start_challenge`, `checkin_challenge`,
    `get_meal_ideas`; Fotos: `import_list_photo`, `preview_food_entry` mit `photo`.

**Stufe 2: hängt an anderen Paketen (Tool von Anfang an deklariert, bis dahin `not_available`)**
14. Wochenplan 27–31 und die `plan_*`-Ziele (B7, Freischaltung durch A).
15. `log_workout` und Löschen von Gewicht/Workouts (B6, Migration `workout_log`).
16. `cooking_control` (A-Kochmodus-API), Apple-Health-Status (B6, `shoply/health`).
17. `update_trip` (B8), `create_recipe_draft`, `edit_list_categories`.

**Stufe 3: selten**
18. `join_list`, `update_list` mit `move_to` und `background`, `list_activity` leeren, `meal_photos` löschen,
    `tips_reset`.

---

## 8. Stabiler Tool-Satz ab der ersten Anfrage

Ab der ersten Anfrage eines Gesprächs schickt der Server **genau diese Liste in dieser Reihenfolge**, mit stabil
sortierten JSON-Schlüsseln. Sie ändert sich nicht durch Module, Pro, Einwilligungen, Bildschirm oder App-Zustand, nur
durch den Kill-Switch (Variante `no_offers` ohne 51–53, Enums von 54 und 55 ohne Angebots-Werte):

```
get_lists, get_list_contents, get_list_details, create_list, update_list, set_list_store,
open_share_sheet, join_list, complete_shopping, import_list_photo, edit_list_categories,
add_items, update_item, check_items, move_items, add_history_items_to_list, get_restock_suggestions,
search_recipes, list_my_recipes, get_recipe, add_recipe_to_list, save_recipe, rate_recipe,
create_recipe_draft, substitute_ingredient, cooking_control,
get_plan, add_to_plan, fill_plan, plan_to_list, update_plan_entry,
get_nutrition_status, get_weekly_nutrition_summary, search_food, preview_food_entry, confirm_preview,
log_water, log_weight, log_workout, propose_nutrition_goal, get_challenges, start_challenge,
checkin_challenge, get_meal_ideas,
get_shopping_history, get_month_summary, update_trip, split_trip_cost, set_split_paid, get_open_balances,
search_offers, get_list_offers, set_list_offers_hidden,
set_module, update_setting, edit_diet_profile, set_favorite_stores, get_user_profile, get_app_info,
navigate, ask_choice, propose_delete, undo_last
```

Strict (18): `create_list`, `set_list_store`, `complete_shopping`, `add_items`, `check_items`, `move_items`,
`add_recipe_to_list`, `add_to_plan`, `confirm_preview`, `log_water`, `log_weight`, `set_split_paid`, `set_module`,
`update_setting`, `edit_diet_profile`, `ask_choice`, `propose_delete`, `undo_last`.

Gründe für „alles von Anfang an“:
- Jede Änderung am Tool-Satz macht Prompt-Cache und Grammatik-Cache ungültig und verwirft Thinking-Blöcke älterer
  Runden (`drop_block`). Auch Tools der Stufe 2 werden deshalb schon mit B5 deklariert; der Executor antwortet bis zum
  fertigen Paket `not_available`, der System-Prompt nennt, was noch nicht geht.
- Ein App-Build, der ein Tool nicht kennt (ältere Version), antwortet `not_available`. Der Request trägt `v`; ändert
  sich der Satz später doch, bekommt er eine neue Version und alte Builds behalten ihren.
- Neue Tools nach B5 nur gesammelt in einem Release, nie einzeln.

---

## 9. Anfragen an Teil A (für `status-B.md`)

1. `ListRepository.removeMember(listId, userId)`: heute entfernt `list_settings_screen.dart:103-135` Mitglieder direkt
   über Supabase.
2. `ItemRepository.addItems` + `undoAddItems` (A5, schon zugesagt) und zusätzlich `restoreItems(List<ShoppingItemModel>)`
   für „Widerrufen“ nach einem bestätigten Löschen.
3. Kochmodus-API als Provider außerhalb des Screens: `cookingNext`, `cookingPrevious`, `cookingRepeat`,
   `cookingStartTimer(minutes)`, `cookingStopTimer` (heute privat in `cooking_mode_screen.dart:89-165`).
4. `RecipeToList` und `RecipeAdaptation` (Allergie-Filter mit Komposita) als aufrufbare Dienste, nicht nur im Screen.
5. Routen `/settings/<seite>` für alle Einstellungsseiten (Konzept 18 Regel 3), Routen für Einkaufsmodus, Listen-Info,
   Kategorie-Reihenfolge und Kochmodus, dazu ein Navigationshelfer `openDestination(context, destination, id, date)`
   nach Konzept 01 Kap. 6.
6. Vertrag `avoScreenContextProvider`: aktueller Bildschirm, Listen-ID, Rezept-ID mit Portionen, Kochschritt,
   Plan-Woche, Kalorien-Tag, Einstellungsseite.
7. Allergie-IDs `kAllergenIds` (Konzept 18 Kap. 5.2) und Einzel-Helfer `addAllergy`, `removeAllergy`,
   `addDietPreference`, `removeDietPreference` in `UserService`. Die Allergie-Oberfläche fehlt heute ganz.
8. `NotificationPreferencesService` mit den Kategorien und Uhrzeiten aus Konzept 18 Kap. 5.5, setzbar über einen
   Schlüssel.
9. Listen-Einstellungen (`show_item_images`, `suggestions_enabled`, `start_list`, `keep_screen_on`, `share_presence`)
   als Provider mit Settern.
10. `RecipeService.getUserRating(recipeId)` (für Widerrufen der Bewertung) und `listsNotifier.moveListTo(listId, top|bottom)`.
11. Vorrat „Hast du meist da“ (E-16) mit `add`/`remove`.
12. `proFeatureProvider` / `ProGate` so, dass der Executor sperren und nach dem Kauf denselben Aufruf einmal wiederholen
    kann; globaler `UndoToast`-Host für Ergebnisse, wenn die Person den Avo-Tab verlassen hat.
13. Sichtbarkeit pro Einstellungsschlüssel (Regel 3), damit `update_setting` `module_off` statt einer unsichtbaren
    Änderung liefert.

---

## 10. Offene Punkte

- **Strict in B1.6:** `_shared/avo_tools.ts` darf höchstens die 18 Tools aus Abschnitt 3 mit `strict: true` markieren,
  sonst 400. Nach dem ersten Entwurf einmal mit echtem Schlüssel gegen „Schema is too complex for compilation“ testen.
- **Quote:** `avo_chat` braucht `quotaAmount` = 1 nur, wenn die letzte Nachricht eine Nutzer-Nachricht mit Text ist, und
  0 bei reinen `tool_result`-Fortsetzungen, dazu eine eigene Tagesgrenze für Fortsetzungen (z. B. das Zehnfache), damit
  man das Limit nicht mit gefälschten Fortsetzungen umgeht. Sonst verbraucht eine Frage mit zwei Tool-Runden drei der
  drei Free-Fragen.
- **Variante:** Die Tool-Variante wählt der Server aus `app_flags.offers_enabled`; ein `tools_variant` aus der App wird
  ignoriert.
- **Fehlende Dienste (B):** `ShoppingHistoryService.getTrip/updateTrip/Zeitraum`, Ersetzen und Löschen von Aufteilungen
  in `ExpenseSplitService` (für Widerrufen), `WeightLogService.deleteEntry`, Widerruf für `startChallenge`/`checkIn`,
  `WorkoutLogService` + Migration, `meal_plan_service`, Angebots-Einstellungen (`user_offer_prefs`), `regionProvider`,
  Avo-Einstellungen, `AvoUndoRegistry`, `AvoConfirmCard`-Dienst, Anhang-Speicher für Fotos, kopfloser Abschluss aus
  `checkout_flow`.
- **Kühlschrank-Foto → Rezepte:** Dafür gibt es keinen Task. Entweder neuer Task (z. B. `photo_ingredients`) oder das
  Bild geht in diesem einen Fall direkt an Avo.
- **Konzept-Namen:** `start_shopping` und `sync_health` aus Konzept 16 Kap. 6.2 gehen in `navigate` auf (Funktion
  bleibt gleich), `cooking_step` und `start_timer` in `cooking_control`, `get_savings_summary` in `get_month_summary`.

Fragen an den Owner:
1. Pro-Umfang bei Avo (Abschnitt 6).
2. Einwilligungs-Schalter „Ernährung“ und „Körperdaten“: per Avo nur ausschalten, einschalten nur in den Einstellungen.
   Einverstanden?
3. Darf Avo einer Liste per Code beitreten (`join_list`)?
4. Ernährungsweise entfernen ohne Karte (nur Allergien mit Sicherheits-Karte)?
5. Gesprochenes „Ja“ bestätigt Essens- und Ziel-Vorschauen (Löschen weiterhin nur per Tipp)?
