-- Insert Sample Recipes - Proper Schema
-- Schema: id (uuid), name, description, image_url, prep/cook times, servings,
--         ingredients (jsonb), instructions (text[]), author_id (uuid),
--         author_name, labels (text[]), labels_meta (jsonb), language

-- Example 1: Spaghetti Carbonara
INSERT INTO recipes (id, name, description, image_url, prep_time_minutes, cook_time_minutes, default_servings, ingredients, instructions, author_id, author_name, labels, labels_meta, language) VALUES
(
  gen_random_uuid(),
  'Spaghetti Carbonara',
  'Classic Italian pasta with creamy egg-cheese sauce and crispy bacon.',
  'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800',
  10, 15, 4,
  '[{"name":"Spaghetti","amount":400,"unit":"g"},{"name":"Pancetta","amount":200,"unit":"g"},{"name":"Eggs","amount":4,"unit":"pcs"},{"name":"Parmesan","amount":100,"unit":"g"}]'::jsonb,
  ARRAY['Cook spaghetti al dente','Fry pancetta until crispy','Beat eggs with parmesan','Toss hot pasta with pancetta off heat','Add egg mixture quickly'],
  'a1b2c3d4-e5f6-4789-abcd-111111111111',
  'Chef Marco',
  ARRAY['italian','pasta','quick','dinner'],
  '[{"tag":"italian","confidence":1.0,"source":"manual"},{"tag":"quick","confidence":0.9,"source":"rule_based"}]'::jsonb,
  'en'
);

-- Example 2: Chicken Pad Thai
INSERT INTO recipes (id, name, description, image_url, prep_time_minutes, cook_time_minutes, default_servings, ingredients, instructions, author_id, author_name, labels, labels_meta, language) VALUES
(
  gen_random_uuid(),
  'Chicken Pad Thai',
  'Classic Thai stir-fried rice noodles with chicken, eggs, and peanuts.',
  'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=800',
  20, 15, 4,
  '[{"name":"Rice noodles","amount":250,"unit":"g"},{"name":"Chicken breast","amount":300,"unit":"g"},{"name":"Eggs","amount":2,"unit":"pcs"},{"name":"Peanuts","amount":50,"unit":"g"}]'::jsonb,
  ARRAY['Soak noodles 30 minutes','Stir-fry chicken','Scramble eggs','Combine with sauce','Top with peanuts'],
  'a1b2c3d4-e5f6-4789-abcd-333333333333',
  'Chef Suki',
  ARRAY['thai','asian','noodles','quick'],
  '[{"tag":"asian","confidence":1.0,"source":"manual"}]'::jsonb,
  'en'
);

-- Example 3: Greek Salad
INSERT INTO recipes (id, name, description, image_url, prep_time_minutes, cook_time_minutes, default_servings, ingredients, instructions, author_id, author_name, labels, labels_meta, language) VALUES
(
  gen_random_uuid(),
  'Greek Salad',
  'Fresh Mediterranean salad with feta and olives.',
  'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800',
  15, 0, 4,
  '[{"name":"Cucumber","amount":1,"unit":"pc"},{"name":"Tomatoes","amount":4,"unit":"pcs"},{"name":"Feta cheese","amount":200,"unit":"g"},{"name":"Olives","amount":100,"unit":"g"}]'::jsonb,
  ARRAY['Chop vegetables','Arrange on platter','Top with feta and olives','Drizzle olive oil'],
  'a1b2c3d4-e5f6-4789-abcd-bbbbbbbbbbbb',
  'Chef Nikos',
  ARRAY['greek','vegetarian','healthy','quick','salad'],
  '[{"tag":"vegetarian","confidence":1.0,"source":"rule_based"}]'::jsonb,
  'en'
);

-- TEMPLATE for more recipes:
-- INSERT INTO recipes (id, name, description, image_url, prep_time_minutes, cook_time_minutes, default_servings, ingredients, instructions, author_id, author_name, labels, labels_meta, language) VALUES
-- (
--   gen_random_uuid(),
--   'Recipe Name',
--   'Description',
--   'https://images.unsplash.com/photo-xxx?w=800',
--   PREP_MINUTES, COOK_MINUTES, SERVINGS,
--   '[{"name":"Ingredient","amount":100,"unit":"g"}]'::jsonb,
--   ARRAY['Step 1','Step 2','Step 3'],
--   'a1b2c3d4-e5f6-4789-abcd-111111111111',  -- author UUID
--   'Chef Name',
--   ARRAY['tag1','tag2','tag3'],
--   '[{"tag":"tag1","confidence":1.0,"source":"manual"}]'::jsonb,
--   'en'
-- );
