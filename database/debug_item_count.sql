-- Debug script to check shopping list item counts
-- Run this in Supabase SQL Editor to identify any discrepancies

-- 1. Get all shopping lists with their item counts from the database
SELECT 
    sl.id,
    sl.name,
    sl.owner_id,
    COUNT(si.id) as actual_item_count
FROM shopping_lists sl
LEFT JOIN shopping_items si ON si.list_id = sl.id
GROUP BY sl.id, sl.name, sl.owner_id
ORDER BY sl.name;

-- 2. Check for any orphaned items (items without a valid list)
SELECT 
    si.id,
    si.list_id,
    si.name,
    sl.name as list_name
FROM shopping_items si
LEFT JOIN shopping_lists sl ON sl.id = si.list_id
WHERE sl.id IS NULL;

-- 3. Check for duplicate items (same name in same list)
SELECT 
    list_id,
    name,
    COUNT(*) as duplicate_count
FROM shopping_items
GROUP BY list_id, name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 4. Get detailed item breakdown per list
SELECT 
    sl.name as list_name,
    sl.id as list_id,
    si.name as item_name,
    si.is_checked,
    si.created_at
FROM shopping_lists sl
LEFT JOIN shopping_items si ON si.list_id = sl.id
ORDER BY sl.name, si.created_at DESC;
