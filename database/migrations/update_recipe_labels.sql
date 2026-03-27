-- Migration: Update all recipes with auto-generated labels
-- Run this in your Supabase SQL Editor to add labels to all existing recipes

-- First, let's update recipes that have empty labels with smart categorization

-- Himbeerkuchen (Raspberry Cake) - dessert
UPDATE recipes SET labels = ARRAY['dessert', 'vegetarisch']::text[]
WHERE name ILIKE '%himbeerkuchen%' AND (labels IS NULL OR labels = '{}');

-- Recipes with common German/English keywords

-- Italian dishes
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['italienisch']::text[])
WHERE (name ILIKE '%pasta%' OR name ILIKE '%pizza%' OR name ILIKE '%risotto%' 
       OR name ILIKE '%lasagne%' OR name ILIKE '%spaghetti%' OR name ILIKE '%penne%'
       OR name ILIKE '%gnocchi%' OR name ILIKE '%ravioli%' OR name ILIKE '%bruschetta%'
       OR name ILIKE '%aglio%' OR name ILIKE '%pesto%' OR name ILIKE '%caprese%')
AND NOT 'italienisch' = ANY(COALESCE(labels, '{}'));

-- Asian dishes  
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['asiatisch']::text[])
WHERE (name ILIKE '%stir fry%' OR name ILIKE '%fried rice%' OR name ILIKE '%curry%'
       OR name ILIKE '%sushi%' OR name ILIKE '%ramen%' OR name ILIKE '%wok%'
       OR name ILIKE '%teriyaki%' OR name ILIKE '%pad thai%')
AND NOT 'asiatisch' = ANY(COALESCE(labels, '{}'));

-- Breakfast
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['frühstück']::text[])
WHERE (name ILIKE '%pancake%' OR name ILIKE '%omelette%' OR name ILIKE '%scrambled%'
       OR name ILIKE '%eggs%' OR name ILIKE '%toast%' OR name ILIKE '%oats%'
       OR name ILIKE '%smoothie%' OR name ILIKE '%granola%' OR name ILIKE '%breakfast%')
AND NOT 'frühstück' = ANY(COALESCE(labels, '{}'));

-- Desserts
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['dessert']::text[])
WHERE (name ILIKE '%cake%' OR name ILIKE '%kuchen%' OR name ILIKE '%cookie%'
       OR name ILIKE '%brownie%' OR name ILIKE '%ice cream%' OR name ILIKE '%pudding%'
       OR name ILIKE '%mousse%' OR name ILIKE '%chocolate%' OR name ILIKE '%torte%')
AND NOT 'dessert' = ANY(COALESCE(labels, '{}'));

-- Healthy
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['gesund']::text[])
WHERE (name ILIKE '%salad%' OR name ILIKE '%salat%' OR name ILIKE '%avocado%'
       OR name ILIKE '%quinoa%' OR name ILIKE '%smoothie%' OR name ILIKE '%healthy%'
       OR name ILIKE '%fruit%' OR name ILIKE '%greek%')
AND NOT 'gesund' = ANY(COALESCE(labels, '{}'));

-- Mexican
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['mexican']::text[])
WHERE (name ILIKE '%taco%' OR name ILIKE '%burrito%' OR name ILIKE '%quesadilla%'
       OR name ILIKE '%guacamole%' OR name ILIKE '%nachos%' OR name ILIKE '%enchilada%')
AND NOT 'mexican' = ANY(COALESCE(labels, '{}'));

-- Mediterranean
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['mediterranean']::text[])
WHERE (name ILIKE '%hummus%' OR name ILIKE '%falafel%' OR name ILIKE '%tzatziki%'
       OR name ILIKE '%greek%' OR name ILIKE '%pita%' OR name ILIKE '%mediterranean%')
AND NOT 'mediterranean' = ANY(COALESCE(labels, '{}'));

-- Soup
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['soup']::text[])
WHERE (name ILIKE '%soup%' OR name ILIKE '%suppe%' OR name ILIKE '%stew%'
       OR name ILIKE '%chowder%' OR name ILIKE '%broth%')
AND NOT 'soup' = ANY(COALESCE(labels, '{}'));

-- Comfort food
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['comfort-food']::text[])
WHERE (name ILIKE '%grilled cheese%' OR name ILIKE '%mac and cheese%' 
       OR name ILIKE '%schnitzel%' OR name ILIKE '%käsespätzle%'
       OR name ILIKE '%comfort%' OR name ILIKE '%casserole%')
AND NOT 'comfort-food' = ANY(COALESCE(labels, '{}'));

-- Quick recipes (under 30 min total time)
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['schnell']::text[])
WHERE (COALESCE(prep_time_minutes, 0) + COALESCE(cook_time_minutes, 0)) <= 30
AND (COALESCE(prep_time_minutes, 0) + COALESCE(cook_time_minutes, 0)) > 0
AND NOT 'schnell' = ANY(COALESCE(labels, '{}'));

-- Vegetarian (no meat keywords in name/description)
UPDATE recipes SET labels = array_cat(COALESCE(labels, '{}'), ARRAY['vegetarisch']::text[])
WHERE name NOT ILIKE ANY(ARRAY['%chicken%', '%beef%', '%pork%', '%meat%', '%steak%', 
                                '%hähnchen%', '%rind%', '%schwein%', '%fleisch%',
                                '%bacon%', '%ham%', '%turkey%', '%lamb%', '%duck%'])
AND description NOT ILIKE ANY(ARRAY['%chicken%', '%beef%', '%pork%', '%meat%', '%steak%',
                                     '%hähnchen%', '%rind%', '%schwein%', '%fleisch%'])
AND NOT 'vegetarisch' = ANY(COALESCE(labels, '{}'))
AND NOT 'vegan' = ANY(COALESCE(labels, '{}'));

-- Default: Any recipe still without labels gets comfort-food
UPDATE recipes SET labels = ARRAY['comfort-food']::text[]
WHERE labels IS NULL OR labels = '{}';

-- Remove duplicates from all label arrays
UPDATE recipes SET labels = (
  SELECT ARRAY(SELECT DISTINCT unnest(labels))
);

-- Show results
SELECT id, name, labels FROM recipes ORDER BY name;
