"""
German Wikibooks Kochbuch → Shoply recipe importer.

Same approach as importer.py but targets de.wikibooks.org (Kochbuch).
License: CC BY-SA 4.0 — same as English Wikibooks.
"""

from __future__ import annotations

import html
import os
import re
import sys
import time
import uuid
from dataclasses import dataclass, field
from typing import Iterator
from urllib.parse import quote

import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
STORAGE_BUCKET = os.environ.get("SUPABASE_STORAGE_BUCKET", "recipe-images")
TARGET_COUNT = int(os.environ.get("TARGET_RECIPE_COUNT_DE", "100"))

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")
    sys.exit(1)

WIKIBOOKS_API = "https://de.wikibooks.org/w/api.php"
REQUEST_DELAY_SEC = 0.4
USER_AGENT = "ShoplyRecipeImporter/1.0 (+https://github.com/shoply; contact: imports@shoply.app)"

IMPORTED_AUTHOR_ID = "00000000-0000-0000-0000-000000000000"
IMPORTED_AUTHOR_NAME = "Wikibooks"

# German label mapping
LABEL_RULES: list[tuple[str, str]] = [
    ("italienisch", "italian"), ("italian", "italian"),
    ("französisch", "french"), ("french", "french"),
    ("chinesisch", "chinese"), ("japanisch", "japanese"),
    ("indisch", "indian"), ("mexikanisch", "mexican"),
    ("griechisch", "greek"), ("spanisch", "spanish"),
    ("türkisch", "turkish"), ("amerikanisch", "american"),
    ("asiatisch", "asian"), ("mediterran", "mediterranean"),
    ("österreichisch", "german"), ("bayerisch", "german"),
    ("deutsch", "german"), ("german", "german"),
    ("frühstück", "breakfast"), ("breakfast", "breakfast"),
    ("mittagessen", "lunch"), ("abendessen", "dinner"),
    ("dessert", "dessert"), ("nachtisch", "dessert"),
    ("snack", "snack"), ("vorspeise", "appetizer"),
    ("kuchen", "cake"), ("torte", "cake"), ("cake", "cake"),
    ("pasta", "pasta"), ("nudeln", "pasta"),
    ("pizza", "pizza"), ("brot", "bread"), ("bread", "bread"),
    ("suppe", "soup"), ("soup", "soup"),
    ("salat", "salad"), ("salad", "salad"),
    ("sandwich", "sandwich"), ("soße", "sauce"),
    ("eintopf", "stew"), ("stew", "stew"),
    ("curry", "curry"), ("reis", "rice"),
    ("kekse", "cookies"), ("plätzchen", "cookies"),
    ("muffin", "muffin"), ("pie", "pie"), ("tarte", "pie"),
    ("backen", "baking"), ("getränk", "drinks"), ("drink", "drinks"),
    ("hähnchen", "chicken"), ("huhn", "chicken"), ("chicken", "chicken"),
    ("rind", "beef"), ("beef", "beef"),
    ("schwein", "pork"), ("pork", "pork"),
    ("fisch", "fish"), ("fish", "fish"),
    ("meeresfrüchte", "seafood"),
    ("vegan", "vegan"), ("vegetarisch", "vegetarian"),
    ("glutenfrei", "gluten-free"),
]

NON_RECIPE_MARKERS = [
    "begriffsklärung", "weiterleitung", "zutaten", "kochgeschirr",
    "kochtechnik", "glossar", "maßeinheit", "grundlagen",
]

INGREDIENT_HEADINGS = {"zutaten", "ingredients", "zubehör"}
PROCEDURE_HEADINGS = {"zubereitung", "anleitung", "procedure", "instructions", "methode"}


@dataclass
class ParsedRecipe:
    title: str
    page_title: str
    source_url: str
    description: str
    ingredients: list[dict]
    instructions: list[str]
    labels: list[str] = field(default_factory=list)
    image_filename: str | None = None
    categories: list[str] = field(default_factory=list)


session = requests.Session()
session.headers.update({"User-Agent": USER_AGENT, "Accept-Encoding": "gzip"})


def wiki_get(params: dict) -> dict:
    params = {**params, "format": "json", "formatversion": "2"}
    resp = session.get(WIKIBOOKS_API, params=params, timeout=30)
    resp.raise_for_status()
    time.sleep(REQUEST_DELAY_SEC)
    return resp.json()


def iter_category_pages(category: str) -> Iterator[dict]:
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
    """Resolve a file name to a direct download URL via de.wikibooks or Commons."""
    for api in ["https://de.wikibooks.org/w/api.php", "https://commons.wikimedia.org/w/api.php"]:
        try:
            params = {
                "action": "query",
                "titles": f"File:{filename}",
                "prop": "imageinfo",
                "iiprop": "url|mime|size",
                "format": "json",
                "formatversion": "2",
            }
            resp = session.get(api, params=params, timeout=30)
            resp.raise_for_status()
            time.sleep(REQUEST_DELAY_SEC)
            data = resp.json()
            pages = data.get("query", {}).get("pages", [])
            for page in pages:
                infos = page.get("imageinfo") or []
                if infos:
                    info = infos[0]
                    url = info.get("url")
                    mime = info.get("mime", "")
                    if url and mime.startswith("image/") and "svg" not in mime:
                        return url
        except Exception:
            continue
    return None


def search_commons_food_image(recipe_name: str) -> tuple[str, str] | None:
    """
    Search Wikimedia Commons for a food photo matching the recipe name.
    Returns (filename, direct_url) or None.
    """
    # Try English translation hints for better Commons search
    search_term = recipe_name.replace("Kochbuch/", "").strip()
    try:
        params = {
            "action": "query",
            "list": "search",
            "srsearch": f"{search_term} food",
            "srnamespace": "6",  # File namespace
            "srlimit": "10",
            "format": "json",
            "formatversion": "2",
        }
        resp = session.get("https://commons.wikimedia.org/w/api.php", params=params, timeout=30)
        resp.raise_for_status()
        time.sleep(REQUEST_DELAY_SEC)
        data = resp.json()
        results = data.get("query", {}).get("search", [])
        for result in results:
            title = result.get("title", "")
            if not title.startswith("File:"):
                continue
            filename = title[5:]
            lower = filename.lower()
            if lower.endswith((".svg", ".gif", ".tif", ".tiff")):
                continue
            if any(bad in lower for bad in ["icon", "logo", "flag", "symbol", "arrow", "nuvola", "commons"]):
                continue
            url = fetch_commons_image_url(filename)
            if url:
                return filename, url
    except Exception:
        pass
    return None


INGREDIENT_QUANTITY_RE = re.compile(
    r"""
    ^\s*
    (?P<amount>\d+(?:[.,/]\d+)?(?:\s*\d+/\d+)?)
    \s*
    (?P<unit>
        esslöffel|el|teelöffel|tl|tasse[n]?|becher|gramm|g|kilogramm|kg|
        milliliter|ml|liter|l|stück|stk|scheibe[n]?|zehe[n]?|prise[n]?|
        bund|kopf|stängel|handvoll|dose[n]?|packung|päckchen|
        tablespoons?|tbsp|teaspoons?|tsp|cups?|ounces?|oz|pounds?|lbs?|
        grams?|kilograms?|milliliters?|liters?|cloves?|pieces?|slices?|
        pinch(?:es)?|cans?|packets?|large|medium|small
    )?
    \s+
    (?P<name>.+?)
    \s*$
    """,
    re.VERBOSE | re.IGNORECASE,
)


def parse_ingredient_line(raw: str) -> dict | None:
    text = re.sub(r"\s+", " ", raw).strip()
    if not text or len(text) > 200:
        return None
    m = INGREDIENT_QUANTITY_RE.match(text)
    if m and m.group("name"):
        amount_raw = m.group("amount") or "1"
        amount_raw = amount_raw.replace(",", ".")
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
    return {"name": text, "amount": 1.0, "unit": ""}


def clean_text(raw: str) -> str:
    text = html.unescape(raw)
    text = re.sub(r"\[\d+\]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def section_items(soup: BeautifulSoup, heading_ids: set[str], list_tag: str) -> list[str]:
    for h2 in soup.find_all("h2"):
        hid = (h2.get("id") or "").lower()
        if hid not in heading_ids:
            continue
        container = h2.parent if h2.parent and "mw-heading" in (h2.parent.get("class") or []) else h2
        node = container.next_sibling
        while node is not None:
            if getattr(node, "name", None) == list_tag:
                return [clean_text(li.get_text(" ", strip=True)) for li in node.find_all("li", recursive=False)]
            if getattr(node, "name", None) == "h2":
                break
            node = node.next_sibling
    return []


def extract_description(soup: BeautifulSoup) -> str:
    for p in soup.find_all("p"):
        text = clean_text(p.get_text(" ", strip=True))
        if len(text) >= 20:
            return text[:500]
    return ""


def derive_labels(categories: list[str]) -> list[str]:
    labels: list[str] = []
    joined = " | ".join(c.lower() for c in categories)
    for needle, label in LABEL_RULES:
        if needle in joined and label not in labels:
            labels.append(label)
    if not labels:
        labels.append("german")  # Default for de.wikibooks content
    return labels


def is_recipe_page(title: str, categories: list[str]) -> bool:
    # Pages from Kategorie:Kochbuch/ Alle Rezepte are always recipes;
    # just reject obvious non-recipe pages by title.
    if any(bad in title.lower() for bad in [
        "inhaltsverzeichnis", "hauptseite", "begriffsklärung",
        "rezeptkategorien", "kochzubehör", "zutaten",
    ]):
        return False
    return True


def parse_recipe(page_title: str, parse_result: dict) -> ParsedRecipe | None:
    html_text = parse_result.get("text", "")
    if isinstance(html_text, dict):
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

    # German pages use "Kochbuch/ Title" format (no colon namespace)
    title = re.sub(r"^Kochbuch/\s*", "", page_title).replace("_", " ").strip()

    if not is_recipe_page(page_title, categories):
        return None

    soup = BeautifulSoup(html_text, "html.parser")

    ingredient_lines = section_items(soup, {h.lower() for h in INGREDIENT_HEADINGS}, "ul")
    if not ingredient_lines:
        return None
    ingredients = [p for line in ingredient_lines if (p := parse_ingredient_line(line))]
    if len(ingredients) < 2:
        return None

    instructions = section_items(soup, {h.lower() for h in PROCEDURE_HEADINGS}, "ol")
    if not instructions:
        instructions = section_items(soup, {h.lower() for h in PROCEDURE_HEADINGS}, "ul")
    instructions = [step for step in instructions if len(step) > 5]
    if len(instructions) < 2:
        return None

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
    source_url = f"https://de.wikibooks.org/wiki/{quote(page_title.replace(' ', '_'))}"

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


def build_supabase() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def existing_source_urls(supabase: Client) -> set[str]:
    rows = supabase.table("recipes").select("source_url").not_.is_("source_url", "null").execute()
    urls = set()
    for row in rows.data or []:
        if row.get("source_url"):
            urls.add(row["source_url"])
    return urls


def upload_image_to_storage(supabase: Client, filename: str, image_url: str) -> str | None:
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
    content_type = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}[ext]

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
    return public.rstrip("?")


def insert_recipe(supabase: Client, recipe: ParsedRecipe, image_url: str) -> bool:
    row = {
        "name": recipe.title,
        "description": recipe.description or f"Ein klassisches {recipe.title} Rezept.",
        "image_url": image_url,
        "prep_time_minutes": 15,
        "cook_time_minutes": 30,
        "default_servings": 4,
        "ingredients": recipe.ingredients,
        "instructions": recipe.instructions,
        "author_id": IMPORTED_AUTHOR_ID,
        "author_name": IMPORTED_AUTHOR_NAME,
        "labels": recipe.labels,
        "language": "de",
        "source_url": recipe.source_url,
        "source_name": "wikibooks",
    }
    try:
        supabase.table("recipes").insert(row).execute()
        return True
    except Exception as e:
        print(f"  ! insert failed: {e}")
        return False


def main() -> int:
    print(f"→ Target: {TARGET_COUNT} German recipes from de.wikibooks.org Kochbuch")
    print(f"→ Supabase: {SUPABASE_URL}")
    print()

    supabase = build_supabase()
    already = existing_source_urls(supabase)

    # Count existing German recipes
    result = supabase.table("recipes").select("id", count="exact").eq("language", "de").execute()
    existing_de = result.count or 0
    need = max(0, TARGET_COUNT - existing_de)
    print(f"→ Existing German recipes: {existing_de}, need {need} more\n")
    if need == 0:
        print("Already have enough German recipes.")
        return 0

    imported = 0
    scanned = 0
    rejected = 0

    categories_to_try = [
        "Kategorie:Kochbuch/ Alle Rezepte",
        "Kategorie:Kochbuch/ Backen",
        "Kategorie:Kochbuch/ Kuchen",
        "Kategorie:Kochbuch/ Rezepte nach Art",
        "Kategorie:Kochbuch/ Rezepte nach Land",
    ]

    all_pages: list[dict] = []
    seen_titles: set[str] = set()
    for cat in categories_to_try:
        print(f"→ Fetching {cat} …")
        for page in iter_category_pages(cat):
            if page["title"] not in seen_titles:
                seen_titles.add(page["title"])
                all_pages.append(page)
    print(f"  found {len(all_pages)} total pages\n")

    for page in all_pages:
        if imported >= need:
            break

        scanned += 1
        page_title = page["title"]

        print(f"[{imported:3d}/{need}] {page_title}")

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

        image_filename = recipe.image_filename
        image_url = None

        if image_filename:
            image_url = fetch_commons_image_url(image_filename)

        if not image_url:
            # Fallback: search Commons for a matching food photo
            result = search_commons_food_image(recipe.title)
            if result:
                image_filename, image_url = result
                print(f"  ~ using Commons search image: {image_filename}")

        if not image_url:
            rejected += 1
            print("  - skip: no image found")
            continue

        mirrored_url = upload_image_to_storage(supabase, image_filename, image_url)
        if not mirrored_url:
            rejected += 1
            continue

        if insert_recipe(supabase, recipe, mirrored_url):
            imported += 1
            already.add(recipe.source_url)
            print(f"  ✓ imported — labels: {', '.join(recipe.labels) or '(none)'}")
        else:
            rejected += 1

    print()
    print("═" * 60)
    print(f"Done. Imported {imported} new German recipes (scanned {scanned}, rejected {rejected}).")
    return 0 if imported > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
