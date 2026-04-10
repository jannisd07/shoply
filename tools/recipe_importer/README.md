# Recipe importer

One-shot Python script that pulls recipes from **Wikibooks Cookbook** (CC BY-SA
licensed, commercial use allowed with attribution) into the Shoply `recipes`
table. Runs locally against your Supabase project.

## What it does

1. Walks every page under `Category:Recipes` on Wikibooks via the MediaWiki API.
2. For each page, fetches the parsed HTML and extracts title, description,
   ingredients, instructions, categories, and the primary image.
3. Filters out non-recipe pages (techniques, ingredient guides, stubs) and
   recipes that lack both an `<h2 id="Ingredients">` list and a
   `<h2 id="Procedure">` list.
4. Maps Wikibooks categories → Shoply labels (`italian`, `pasta`, `cake`,
   `indian`, `vegan`, etc.).
5. Mirrors the image from Wikimedia Commons into a public Supabase Storage
   bucket so the app doesn't hotlink Commons in production.
6. Inserts the recipe into `recipes` with `source_url` pointing back to the
   original Wikibooks page and `source_name = 'wikibooks'`. The Flutter detail
   screen renders this as a "Source: Wikibooks Cookbook · CC BY-SA 4.0" footer.

Idempotent — re-running it skips recipes whose `source_url` already exists.

## Prereqs

1. **Run the SQL migration** first so the `source_url` and `source_name`
   columns exist:

   ```bash
   # In Supabase Dashboard → SQL editor, run:
   database/migrations/add_recipe_source_url.sql
   ```

2. **Create a public Supabase Storage bucket** called `recipe-images`
   (Storage → New bucket → Public). This is where mirrored images land.

3. **Grab your service role key** from Supabase Dashboard → Project Settings →
   API → `service_role` (secret). This has full DB access — don't commit it.

## Install & run

```bash
cd tools/recipe_importer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# Edit .env and fill in SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY

python importer.py
```

Expect ~20-40 minutes for 500 recipes (rate-limited to ~3 req/s against the
Wikimedia API, with two roundtrips per recipe: parse page + fetch image URL).

## Tuning

All knobs live in environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `TARGET_RECIPE_COUNT` | `500` | Stop after importing this many |
| `SUPABASE_STORAGE_BUCKET` | `recipe-images` | Bucket to mirror images into |

The label mapping lives in `LABEL_RULES` inside `importer.py` — add your own
rules if you want richer tagging.

## Legal

Wikibooks content is [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
Attribution is satisfied by the "Source: Wikibooks Cookbook" footer that the
Flutter detail screen renders whenever a recipe has `source_url` + `source_name`.
Don't strip that footer — it's the license condition.

ShareAlike only kicks in if you *modify* the recipe content itself. Adding
your own metadata (labels, difficulty, saved state) is fine; editing the
ingredients or instructions and redistributing them would require releasing
the modified recipes under CC BY-SA too.
