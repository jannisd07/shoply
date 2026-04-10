"""
Recipe DB audit + auto-fix script.
Checks: missing fields, images, duplicates, multi-label, language coverage.
Fixes:  deletes bad recipes, removes duplicates, trims to single label.
"""

import os, sys, json
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()
sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])

# ── Fetch all recipes ─────────────────────────────────────────────
print("Fetching all recipes …")
rows = []
page_size = 1000
offset = 0
while True:
    chunk = sb.table("recipes").select(
        "id,name,description,image_url,instructions,ingredients,labels,language,source_url"
    ).range(offset, offset + page_size - 1).execute()
    rows.extend(chunk.data or [])
    if len(chunk.data or []) < page_size:
        break
    offset += page_size

print(f"Total recipes fetched: {len(rows)}\n")

# ── Checks ────────────────────────────────────────────────────────
missing_name        = [r for r in rows if not (r.get("name") or "").strip()]
missing_image       = [r for r in rows if not (r.get("image_url") or "").strip()]
missing_desc        = [r for r in rows if not (r.get("description") or "").strip()]
missing_steps       = [r for r in rows if not r.get("instructions") or len(r["instructions"]) < 1]
missing_ingredients = [r for r in rows if not r.get("ingredients") or len(r["ingredients"]) < 1]

multi_label   = [r for r in rows if r.get("labels") and len(r["labels"]) > 1]
no_label      = [r for r in rows if not r.get("labels") or len(r["labels"]) == 0]

# Language
by_lang = {}
for r in rows:
    lang = r.get("language") or "unknown"
    by_lang[lang] = by_lang.get(lang, 0) + 1

# Duplicates by name (case-insensitive)
name_seen: dict[str, list] = {}
for r in rows:
    key = (r.get("name") or "").strip().lower()
    if key:
        name_seen.setdefault(key, []).append(r)
dup_by_name = {k: v for k, v in name_seen.items() if len(v) > 1}

# Duplicates by source_url
url_seen: dict[str, list] = {}
for r in rows:
    u = r.get("source_url")
    if u:
        url_seen.setdefault(u, []).append(r)
dup_by_url = {k: v for k, v in url_seen.items() if len(v) > 1}

# ── Report ────────────────────────────────────────────────────────
print("═" * 55)
print("AUDIT REPORT")
print("═" * 55)
print(f"  Total recipes     : {len(rows)}")
print(f"  Language breakdown: {dict(sorted(by_lang.items()))}")
print()
print(f"  Missing name      : {len(missing_name)}")
print(f"  Missing image     : {len(missing_image)}")
print(f"  Missing desc      : {len(missing_desc)}")
print(f"  Missing steps     : {len(missing_steps)}")
print(f"  Missing ingreds   : {len(missing_ingredients)}")
print()
print(f"  No label          : {len(no_label)}")
print(f"  Multiple labels   : {len(multi_label)}")
print()
print(f"  Duplicate names   : {len(dup_by_name)} groups")
print(f"  Duplicate URLs    : {len(dup_by_url)} groups")
print("═" * 55)

# ── Fixes ────────────────────────────────────────────────────────
deleted_ids = set()

# 1. Delete recipes missing critical fields
critical_bad = set()
for r in missing_name + missing_image + missing_steps + missing_ingredients:
    critical_bad.add(r["id"])

if critical_bad:
    ids = list(critical_bad)
    sb.table("recipes").delete().in_("id", ids).execute()
    deleted_ids.update(ids)
    print(f"\n🗑  Deleted {len(ids)} recipes with missing critical fields")
    for r in rows:
        if r["id"] in critical_bad:
            print(f"   - {r['name']!r} ({r['id']}) — lang={r.get('language')}")

# 2. Delete duplicates — keep newest (highest id lexicographically as UUID v4 proxy,
#    or keep the one with a non-null source_url; fallback: keep last in list)
def pick_keeper(dupes: list[dict]) -> str:
    """Return id of the record to KEEP (prefer one with image + source_url)."""
    scored = []
    for r in dupes:
        score = (
            bool(r.get("source_url")),
            bool(r.get("image_url")),
            bool(r.get("description")),
        )
        scored.append((score, r["id"], r))
    scored.sort(reverse=True)
    return scored[0][1]

all_dup_groups = list(dup_by_name.values()) + list(dup_by_url.values())
dup_delete_ids = []
for group in all_dup_groups:
    live = [r for r in group if r["id"] not in deleted_ids]
    if len(live) < 2:
        continue
    keeper = pick_keeper(live)
    for r in live:
        if r["id"] != keeper and r["id"] not in deleted_ids:
            dup_delete_ids.append(r["id"])
            deleted_ids.add(r["id"])

if dup_delete_ids:
    sb.table("recipes").delete().in_("id", dup_delete_ids).execute()
    print(f"\n🗑  Deleted {len(dup_delete_ids)} duplicate recipes")

# 3. Trim multi-label recipes to first label only
trim_count = 0
for r in multi_label:
    if r["id"] in deleted_ids:
        continue
    first_label = r["labels"][0]
    sb.table("recipes").update({"labels": [first_label]}).eq("id", r["id"]).execute()
    trim_count += 1
if trim_count:
    print(f"\n✂️  Trimmed labels to single category on {trim_count} recipes")

# 4. Assign fallback label to no-label recipes (based on name keywords)
KEYWORD_LABEL = [
    ("soup","soup"),("suppe","soup"),("salad","salad"),("salat","salad"),
    ("cake","cake"),("torte","cake"),("kuchen","cake"),("bread","bread"),
    ("brot","bread"),("pasta","pasta"),("nudel","pasta"),("pizza","pizza"),
    ("curry","curry"),("sandwich","sandwich"),("burger","sandwich"),
    ("cookie","cookies"),("muffin","muffin"),("pie","pie"),("tart","pie"),
    ("smoothie","drinks"),("tea","drinks"),("beer","drinks"),("juice","drinks"),
    ("pudding","dessert"),("dessert","dessert"),("ice ","dessert"),
    ("porridge","breakfast"),("breakfast","breakfast"),
    ("sauce","sauce"),("ketchup","sauce"),("marinade","sauce"),
    ("chicken","chicken"),("beef","beef"),("steak","beef"),
    ("pork","pork"),("fish","fish"),("fisch","fish"),
    ("vegan","vegan"),("vegetarian","vegetarian"),
    ("stew","stew"),("eintopf","stew"),("rice","rice"),("reis","rice"),
    ("nigerian","african"),("african","african"),
]

assign_count = 0
for r in no_label:
    if r["id"] in deleted_ids:
        continue
    name_lower = (r.get("name") or "").lower()
    assigned = None
    for kw, lbl in KEYWORD_LABEL:
        if kw in name_lower:
            assigned = lbl
            break
    if not assigned:
        assigned = "other"
    sb.table("recipes").update({"labels": [assigned]}).eq("id", r["id"]).execute()
    assign_count += 1
if assign_count:
    print(f"\n🏷  Assigned single label to {assign_count} unlabelled recipes")

# ── Final stats ───────────────────────────────────────────────────
print("\nFetching final counts …")
final = sb.table("recipes").select("id,language,labels").execute().data or []
final_lang = {}
label_dist = {}
multi_after = 0
no_label_after = 0
for r in final:
    lang = r.get("language") or "unknown"
    final_lang[lang] = final_lang.get(lang, 0) + 1
    lbls = r.get("labels") or []
    if len(lbls) > 1:
        multi_after += 1
    if len(lbls) == 0:
        no_label_after += 1
    for l in lbls:
        label_dist[l] = label_dist.get(l, 0) + 1

print()
print("═" * 55)
print("FINAL STATS")
print("═" * 55)
print(f"  Total             : {len(final)}")
print(f"  Language breakdown: {dict(sorted(final_lang.items()))}")
print(f"  Multi-label left  : {multi_after}")
print(f"  No-label left     : {no_label_after}")
print()
print("  Label distribution:")
for lbl, cnt in sorted(label_dist.items(), key=lambda x: -x[1]):
    print(f"    {lbl:<20s} {cnt}")
print("═" * 55)

en_ok = final_lang.get("en", 0) >= 100
de_ok = final_lang.get("de", 0) >= 100
print(f"\n  ✅ EN ≥ 100: {'YES' if en_ok else 'NO — ' + str(final_lang.get('en',0))}")
print(f"  {'✅' if de_ok else '❌'} DE ≥ 100: {'YES' if de_ok else 'NO — ' + str(final_lang.get('de',0))}")
