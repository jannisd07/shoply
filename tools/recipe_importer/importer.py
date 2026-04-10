"""
Wikibooks Cookbook → Shoply recipe importer.

Runs locally (not in the app). Pulls ~500 recipes from Wikibooks Cookbook
via the MediaWiki API, parses the HTML to extract ingredients, instructions,
and a primary image, mirrors the image into Supabase Storage, and inserts
the recipe into the `recipes` table.

Legal:
  • Wikibooks content is CC BY-SA 4.0 — commercial reuse is allowed with
    attribution and a link to the source page. Every imported recipe stores
    source_url + source_name = 'wikibooks', which the Flutter detail screen
    renders as a "Source: Wikibooks Cookbook · CC BY-SA 4.0" footer.
  • Wikimedia Commons images used here are all CC-licensed. Commons frowns
    on hotlinking from production apps, so we mirror them to our own bucket.

Usage:
    cd tools/recipe_importer
    python3 -m venv .venv && source .venv/bin/activate
    pip install -r requirements.txt
    cp .env.example .env   # then fill in credentials
    python importer.py

Run it multiple times safely — it skips recipes whose source_url already
exists in the DB.
"""

from __future__ import annotations

import html
import os
import re
import sys
import time
import uuid
from dataclasses import dataclass, field
from typing import Iterable, Iterator
from urllib.parse import quote, urljoin

import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from supabase import Client, create_client

# ══════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════

load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
STORAGE_BUCKET = os.environ.get("SUPABASE_STORAGE_BUCKET", "recipe-images")
TARGET_COUNT = int(os.environ.get("TARGET_RECIPE_COUNT", "500"))
RESUME_FROM_LETTER = os.environ.get("RESUME_FROM_LETTER", "A")
# Only process every Nth candidate page (for alphabet variety). 1 = all.
STEP = int(os.environ.get("IMPORTER_STEP", "1"))

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")
    sys.exit(1)

# Wikimedia API
WIKIBOOKS_API = "https://en.wikibooks.org/w/api.php"
# Rate limit: Wikimedia asks for <=1 req/s from bots and a descriptive UA.
REQUEST_DELAY_SEC = 0.35
USER_AGENT = (
    "ShoplyRecipeImporter/1.0 (+https://github.com/shoply; contact: imports@shoply.app)"
)

# Imported recipes carry this sentinel author_id. It's never displayed in the
# UI (the detail screen hides the author block when isImported is true) but
# the column is NOT NULL so we need a stable value.
IMPORTED_AUTHOR_ID = "00000000-0000-0000-0000-000000000000"
IMPORTED_AUTHOR_NAME = "Wikibooks"

# ══════════════════════════════════════════════════════════════════
# Label mapping — Wikibooks categories → Shoply labels
# ══════════════════════════════════════════════════════════════════
#
# Key is a lowercase substring that may appear in any Wikibooks category
# name for a page. Value is the normalized Shoply label we write into the
# `labels` array. Order matters only in that multiple hits are all added.

LABEL_RULES: list[tuple[str, str]] = [
    # Cuisines
    ("italian", "italian"),
    ("french", "french"),
    ("chinese", "chinese"),
    ("japanese", "japanese"),
    ("thai", "thai"),
    ("indian", "indian"),
    ("mexican", "mexican"),
    ("greek", "greek"),
    ("spanish", "spanish"),
    ("german", "german"),
    ("turkish", "turkish"),
    ("vietnamese", "vietnamese"),
    ("korean", "korean"),
    ("middle eastern", "middle-eastern"),
    ("mediterranean", "mediterranean"),
    ("american", "american"),
    ("british", "british"),
    ("caribbean", "caribbean"),
    ("african", "african"),
    # Meal types
    ("breakfast", "breakfast"),
    ("lunch", "lunch"),
    ("dinner", "dinner"),
    ("dessert", "dessert"),
    ("snack", "snack"),
    ("appetizer", "appetizer"),
    ("starter", "appetizer"),
    # Dish types
    ("cake", "cake"),
    ("cakes", "cake"),
    ("pasta", "pasta"),
    ("pizza", "pizza"),
    ("bread", "bread"),
    ("soup", "soup"),
    ("salad", "salad"),
    ("sandwich", "sandwich"),
    ("sauce", "sauce"),
    ("stew", "stew"),
    ("curry", "curry"),
    ("noodle", "noodles"),
    ("rice", "rice"),
    ("cookie", "cookies"),
    ("muffin", "muffin"),
    ("pie", "pie"),
    ("bake", "baking"),
    ("baking", "baking"),
    ("confection", "dessert"),
    ("drink", "drinks"),
    ("beverage", "drinks"),
    # Proteins
    ("chicken", "chicken"),
    ("beef", "beef"),
    ("pork", "pork"),
    ("lamb", "lamb"),
    ("fish", "fish"),
    ("seafood", "seafood"),
    ("egg", "eggs"),
    # Diets
    ("vegan", "vegan"),
    ("vegetarian", "vegetarian"),
    ("gluten-free", "gluten-free"),
    ("low-carb", "low-carb"),
    ("kosher", "kosher"),
    ("halal", "halal"),
]

# Categories/phrases that mean "this page is NOT a recipe" — skip it.
NON_RECIPE_MARKERS = [
    "disambiguation",
    "redirect",
    "ingredients",
    "cookbook equipment",
    "cookbook techniques",
    "cookbook terminology",
    "glossaries",
    "units of measure",
    "cookbook basics",
]

# A valid recipe page must have BOTH an ingredients list and a procedure list.
# These are the exact h2 ids Wikibooks uses (case-insensitive, with variants).
INGREDIENT_HEADINGS = {"ingredients", "special equipment"}
PROCEDURE_HEADINGS = {"procedure", "instructions", "directions", "method"}

# ══════════════════════════════════════════════════════════════════
# Data model
# ══════════════════════════════════════════════════════════════════

@dataclass
class ParsedRecipe:
    title: str
    page_title: str  # e.g. "Cookbook:Apple_Cake"
    source_url: str
    description: str
    ingredients: list[dict]   # [{name, amount, unit}]
    instructions: list[str]
    labels: list[str] = field(default_factory=list)
    image_filename: str | None = None  # Wikimedia image filename
    categories: list[str] = field(default_factory=list)


# ══════════════════════════════════════════════════════════════════
# Wikimedia API client
# ══════════════════════════════════════════════════════════════════

session = requests.Session()
session.headers.update({"User-Agent": USER_AGENT, "Accept-Encoding": "gzip"})


def wiki_get(params: dict) -> dict:
    """Call the MediaWiki API with rate limiting."""
    params = {**params, "format": "json", "formatversion": "2"}
    resp = session.get(WIKIBOOKS_API, params=params, timeout=30)
    resp.raise_for_status()
    time.sleep(REQUEST_DELAY_SEC)
    return resp.json()


def iter_category_pages(category: str) -> Iterator[dict]:
    """Yield every page in a Wikibooks category, paginating transparently."""
    cmcontinue = None
    while True:
        params = {
            "action": "query",
            "list": "categorymembers",
            "cmtitle": category,
            "cmtype": "page",
            "cmlimit": "500",
        }
        if cmcontinue:
            params["cmcontinue"] = cmcontinue
        data = wiki_get(params)
        for page in data.get("query", {}).get("categorymembers", []):
            yield page
        cont = data.get("continue")
        if not cont:
            break
        cmcontinue = cont.get("cmcontinue")


def fetch_page_parse(page_title: str) -> dict | None:
    """Fetch parsed HTML + categories + images for one page."""
    try:
        data = wiki_get({
            "action": "parse",
            "page": page_title,
            "prop": "text|categories|images",
            "redirects": "1",
        })
    except requests.HTTPError as e:
        print(f"  ! HTTP error on {page_title}: {e}")
        return None
    if "error" in data:
        return None
    return data.get("parse")


def fetch_commons_image_url(filename: str) -> str | None:
    """Resolve a Wikimedia image filename → direct download URL."""
    try:
        data = wiki_get({
            "action": "query",
            "titles": f"File:{filename}",
            "prop": "imageinfo",
            "iiprop": "url|mime|size",
        })
    except requests.HTTPError:
        return None
    pages = data.get("query", {}).get("pages", [])
    for page in pages:
        infos = page.get("imageinfo") or []
        if infos:
            info = infos[0]
            url = info.get("url")
            mime = info.get("mime", "")
            if url and mime.startswith("image/") and "svg" not in mime:
                return url
    return None


# ══════════════════════════════════════════════════════════════════
# HTML parsing
# ══════════════════════════════════════════════════════════════════

INGREDIENT_QUANTITY_RE = re.compile(
    r"""
    ^\s*
    (?P<amount>\d+(?:[./]\d+)?(?:\s*\d+/\d+)?)
    \s*
    (?P<unit>
        tablespoons?|tbsp|teaspoons?|tsp|cups?|cup|ounces?|oz|pounds?|lbs?|
        grams?|g|kilograms?|kg|milliliters?|ml|liters?|l|
        cloves?|pieces?|slices?|pinch(?:es)?|dash|cans?|packets?|sprigs?|
        handfuls?|bunch(?:es)?|heads?|stalks?|inch(?:es)?|sticks?|
        large|medium|small
    )?
    \s+
    (?P<name>.+?)
    \s*$
    """,
    re.VERBOSE | re.IGNORECASE,
)


def parse_ingredient_line(raw: str) -> dict | None:
    """Best-effort split of a free-form ingredient line into amount/unit/name."""
    text = re.sub(r"\s+", " ", raw).strip()
    if not text or len(text) > 200:
        return None
    m = INGREDIENT_QUANTITY_RE.match(text)
    if m and m.group("name"):
        amount_raw = m.group("amount") or "1"
        # Handle "1 1/2" → 1.5
        parts = amount_raw.split()
        amount = 0.0
        for p in parts:
            if "/" in p:
                num, den = p.split("/")
                amount += float(num) / float(den) if float(den) else 0
            else:
                try:
                    amount += float(p)
                except ValueError:
                    pass
        return {
            "name": m.group("name").strip(),
            "amount": round(amount, 2) if amount else 1.0,
            "unit": (m.group("unit") or "").strip(),
        }
    # Fallback: whole line as name.
    return {"name": text, "amount": 1.0, "unit": ""}


def clean_text(raw: str) -> str:
    """Collapse whitespace and unescape HTML entities."""
    text = html.unescape(raw)
    text = re.sub(r"\[\d+\]", "", text)  # [1] footnote markers
    text = re.sub(r"\s+", " ", text).strip()
    return text


def section_items(soup: BeautifulSoup, heading_ids: set[str], list_tag: str) -> list[str]:
    """
    Return the text of <li> elements in the list that follows any of the
    headings identified by `heading_ids`. Walks siblings after the heading
    container until it finds a <ul> or <ol>.
    """
    for h2 in soup.find_all("h2"):
        hid = (h2.get("id") or "").lower()
        if hid not in heading_ids:
            continue
        # The heading is usually wrapped: <div class="mw-heading"><h2>...</h2></div>
        container = h2.parent if h2.parent and "mw-heading" in (h2.parent.get("class") or []) else h2
        node = container.next_sibling
        while node is not None:
            if getattr(node, "name", None) == list_tag:
                return [clean_text(li.get_text(" ", strip=True)) for li in node.find_all("li", recursive=False)]
            # Stop at the next heading.
            if getattr(node, "name", None) == "h2":
                break
            node = node.next_sibling
    return []


def extract_description(soup: BeautifulSoup) -> str:
    """First meaningful <p> before the Ingredients heading."""
    for p in soup.find_all("p"):
        text = clean_text(p.get_text(" ", strip=True))
        if len(text) >= 30:
            return text[:500]
    return ""


def derive_labels(categories: list[str]) -> list[str]:
    labels: list[str] = []
    joined = " | ".join(c.lower() for c in categories)
    for needle, label in LABEL_RULES:
        if needle in joined and label not in labels:
            labels.append(label)
    return labels


def is_recipe_page(title: str, categories: list[str]) -> bool:
    lowered = [c.lower() for c in categories]
    # Must have at least one "Recipes" category.
    if not any("recipes" in c for c in lowered):
        return False
    # Reject pages flagged as non-recipe content.
    for marker in NON_RECIPE_MARKERS:
        if any(marker in c for c in lowered):
            if marker == "ingredients" and any("recipes" in c for c in lowered):
                # pages that are both "Recipes" and "Ingredients" categories
                # are fine (they're usually dishes named after their star ingredient).
                continue
            return False
    # Reject stub-y titles like "Cookbook:Table of contents".
    if any(bad in title.lower() for bad in ["table of contents", "main page", "disambiguation"]):
        return False
    return True


def parse_recipe(page_title: str, parse_result: dict) -> ParsedRecipe | None:
    """Turn a MediaWiki parse result into a ParsedRecipe, or None if invalid."""
    html_text = parse_result.get("text", "")
    if isinstance(html_text, dict):  # formatversion=1 legacy shape
        html_text = html_text.get("*", "")
    if not html_text:
        return None

    categories_raw = parse_result.get("categories", []) or []
    categories = []
    for cat in categories_raw:
        if isinstance(cat, dict):
            name = cat.get("category") or cat.get("*") or ""
        else:
            name = str(cat)
        if name:
            categories.append(name.replace("_", " "))

    title = page_title.split(":", 1)[-1].replace("_", " ").strip()

    if not is_recipe_page(page_title, categories):
        return None

    soup = BeautifulSoup(html_text, "html.parser")

    ingredient_lines = section_items(soup, {h.lower() for h in INGREDIENT_HEADINGS}, "ul")
    if not ingredient_lines:
        # Some pages use unordered list directly under "Ingredients" sub-headings too
        return None
    ingredients = [p for line in ingredient_lines if (p := parse_ingredient_line(line))]
    if len(ingredients) < 2:
        return None

    instructions = section_items(soup, {h.lower() for h in PROCEDURE_HEADINGS}, "ol")
    if not instructions:
        # Some pages use <ul> for procedure too.
        instructions = section_items(soup, {h.lower() for h in PROCEDURE_HEADINGS}, "ul")
    instructions = [step for step in instructions if len(step) > 5]
    if len(instructions) < 2:
        return None

    # Image: pick first non-icon image.
    images = parse_result.get("images", []) or []
    image_filename = None
    for fname in images:
        lower = fname.lower()
        if lower.endswith((".svg", ".gif")):
            continue
        if any(bad in lower for bad in ["icon", "logo", "flag", "symbol", "arrow", "dots", "commons"]):
            continue
        image_filename = fname
        break

    description = extract_description(soup)
    labels = derive_labels(categories)

    source_url = f"https://en.wikibooks.org/wiki/{quote(page_title.replace(' ', '_'))}"

    return ParsedRecipe(
        title=title,
        page_title=page_title,
        source_url=source_url,
        description=description,
        ingredients=ingredients,
        instructions=instructions,
        labels=labels,
        image_filename=image_filename,
        categories=categories,
    )


# ══════════════════════════════════════════════════════════════════
# Supabase sink
# ══════════════════════════════════════════════════════════════════

def build_supabase() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def existing_source_urls(supabase: Client) -> set[str]:
    """Fetch source_urls already in the DB so we can dedupe on re-runs."""
    rows = supabase.table("recipes").select("source_url").not_.is_("source_url", "null").execute()
    urls = set()
    for row in rows.data or []:
        if row.get("source_url"):
            urls.add(row["source_url"])
    return urls


def upload_image_to_storage(supabase: Client, filename: str, image_url: str) -> str | None:
    """Download from Wikimedia and upload to our Supabase Storage bucket."""
    try:
        resp = session.get(image_url, timeout=60)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"  ! image download failed: {e}")
        return None

    ext = os.path.splitext(filename)[1].lower() or ".jpg"
    if ext not in (".jpg", ".jpeg", ".png", ".webp"):
        ext = ".jpg"
    safe_name = f"wikibooks/{uuid.uuid4().hex}{ext}"
    content_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }[ext]

    try:
        supabase.storage.from_(STORAGE_BUCKET).upload(
            path=safe_name,
            file=resp.content,
            file_options={"content-type": content_type, "upsert": "false"},
        )
    except Exception as e:
        print(f"  ! storage upload failed: {e}")
        return None

    public = supabase.storage.from_(STORAGE_BUCKET).get_public_url(safe_name)
    return public.rstrip("?")  # strip trailing ?, which some SDKs append


def insert_recipe(supabase: Client, recipe: ParsedRecipe, image_url: str) -> bool:
    row = {
        "name": recipe.title,
        "description": recipe.description or f"A classic {recipe.title} recipe.",
        "image_url": image_url,
        "prep_time_minutes": 15,
        "cook_time_minutes": 20,
        "default_servings": 4,
        "ingredients": recipe.ingredients,
        "instructions": recipe.instructions,
        "author_id": IMPORTED_AUTHOR_ID,
        "author_name": IMPORTED_AUTHOR_NAME,
        "labels": recipe.labels,
        "language": "en",
        "source_url": recipe.source_url,
        "source_name": "wikibooks",
    }
    try:
        supabase.table("recipes").insert(row).execute()
        return True
    except Exception as e:
        print(f"  ! insert failed: {e}")
        return False


# ══════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════

def main() -> int:
    print(f"→ Target: {TARGET_COUNT} recipes from Wikibooks Cookbook")
    print(f"→ Supabase: {SUPABASE_URL}")
    print(f"→ Storage bucket: {STORAGE_BUCKET}")
    print()

    supabase = build_supabase()
    already = existing_source_urls(supabase)
    if already:
        print(f"→ {len(already)} recipes already imported (will skip)\n")

    imported = 0
    scanned = 0
    rejected = 0
    candidate_pos = 0  # Counts valid-namespace pages after resume letter, used for STEP
    label_counts: dict[str, int] = {}

    # Phase 1: pull the full list of candidate page titles.
    print("→ Fetching recipe index from Category:Recipes …")
    page_list = list(iter_category_pages("Category:Recipes"))
    print(f"  found {len(page_list)} total pages\n")

    for page in page_list:
        if imported >= TARGET_COUNT:
            break

        scanned += 1
        page_title = page["title"]
        if page.get("ns") != 102:  # Cookbook namespace
            rejected += 1
            continue

        # Skip pages alphabetically before the resume letter.
        short_title = page_title.split(":", 1)[-1]
        if short_title < RESUME_FROM_LETTER:
            continue

        # Apply step: only process every Nth candidate.
        candidate_pos += 1
        if STEP > 1 and (candidate_pos % STEP) != 1:
            continue

        # Shuffle the category so we hit diverse cuisines early.
        print(f"[{imported:3d}/{TARGET_COUNT}] {page_title}")

        parsed_data = fetch_page_parse(page_title)
        if not parsed_data:
            rejected += 1
            print("  - skip: parse failed")
            continue

        recipe = parse_recipe(page_title, parsed_data)
        if not recipe:
            rejected += 1
            print("  - skip: not a valid recipe page")
            continue

        if recipe.source_url in already:
            print("  - skip: already imported")
            continue

        if not recipe.image_filename:
            rejected += 1
            print("  - skip: no image")
            continue

        image_url = fetch_commons_image_url(recipe.image_filename)
        if not image_url:
            rejected += 1
            print("  - skip: image lookup failed")
            continue

        mirrored_url = upload_image_to_storage(supabase, recipe.image_filename, image_url)
        if not mirrored_url:
            rejected += 1
            continue

        if insert_recipe(supabase, recipe, mirrored_url):
            imported += 1
            already.add(recipe.source_url)
            for lab in recipe.labels:
                label_counts[lab] = label_counts.get(lab, 0) + 1
            print(f"  ✓ imported — labels: {', '.join(recipe.labels) or '(none)'}")
        else:
            rejected += 1

    print()
    print("═" * 60)
    print(f"Done. Imported {imported} new recipes (scanned {scanned}, rejected {rejected}).")
    print()
    print("Label distribution:")
    for label, count in sorted(label_counts.items(), key=lambda x: -x[1]):
        print(f"  {label:20s} {count}")

    return 0 if imported > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
