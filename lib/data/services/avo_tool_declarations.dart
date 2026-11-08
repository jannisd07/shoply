import 'package:google_generative_ai/google_generative_ai.dart';

/// Function declarations (tool schemas) Gemini can call in the Avo chat.
/// Each name is dispatched in `AvoAssistantService._runTool`.
List<Tool> buildAvoTools() => [
  Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'search_recipes',
        'Search the Shoply recipe library and display matching recipes as cards. '
            'Pass dietary_filters (e.g. ["vegan", "gluten-free"]) and/or '
            'exclude_allergens (e.g. ["nuts", "eggs"]) based on the user profile.',
        Schema.object(
          properties: {
            'query': Schema.string(
              description: 'Search terms — ingredients, cuisine, or meal type',
            ),
            'dietary_filters': Schema.array(
              description:
                  'Dietary tags that recipes MUST match (vegan, vegetarian, keto, etc.)',
              items: Schema.string(),
            ),
            'exclude_allergens': Schema.array(
              description:
                  'Allergen ingredients to avoid (e.g. nuts, gluten, dairy)',
              items: Schema.string(),
            ),
            'max_results': Schema.integer(
              description: 'Maximum recipes to return (default 5)',
            ),
          },
          requiredProperties: ['query'],
        ),
      ),
      FunctionDeclaration(
        'get_saved_recipes',
        'Display the user\'s bookmarked recipes as cards.',
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'get_recipe_nutrition',
        'Return calories and macros for a recipe. If the recipe already '
            'stores nutrition, returns it directly; otherwise ESTIMATES from ingredients. '
            'Pass either recipe_id or a free-text recipe_name.',
        Schema.object(
          properties: {
            'recipe_id': Schema.string(
              description: 'Recipe ID from search_recipes',
            ),
            'recipe_name': Schema.string(
              description: 'Recipe name to look up by name',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        'add_recipe_to_list',
        'Add every ingredient of a recipe to a shopping list in one go — e.g. '
            '"add ingredients for carbonara to Friday\'s list". Resolve the recipe '
            'via recipe_id (from search_recipes/get_saved_recipes) or recipe_name, '
            'and list_id via get_lists (match by the list name the user mentioned, '
            'or ask which list if it is unclear). Optionally scale the recipe to a '
            'different serving count than its default. Automatically attaches '
            'current offer prices to any matched ingredient — if the response '
            'includes added_with_offer_price, mention how many items are on offer.',
        Schema.object(
          properties: {
            'recipe_id': Schema.string(
              description: 'Recipe ID from search_recipes/get_saved_recipes',
            ),
            'recipe_name': Schema.string(
              description: 'Recipe name to look up by name',
            ),
            'list_id': Schema.string(
              description: 'Target list ID, from get_lists',
            ),
            'servings': Schema.integer(
              description:
                  'Scale ingredient amounts to this many servings — '
                  'omit to use the recipe\'s own default servings',
            ),
          },
          requiredProperties: ['list_id'],
        ),
      ),
      FunctionDeclaration(
        'get_shopping_history',
        'Display recent shopping history cards. Each card has "Add all" and per-item add buttons.',
        Schema.object(
          properties: {
            'limit': Schema.integer(
              description: 'Max history entries (default 5)',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        'get_lists',
        'Display all of the user\'s shopping lists as cards.',
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'get_list_contents',
        'Display items inside a specific shopping list. Omit list_id to use the first list.',
        Schema.object(
          properties: {'list_id': Schema.string(description: 'ID of the list')},
        ),
      ),
      FunctionDeclaration(
        'add_item_to_list',
        'Add a single item to a shopping list.',
        Schema.object(
          properties: {
            'list_id': Schema.string(description: 'Target list ID'),
            'name': Schema.string(description: 'Item name'),
            'quantity': Schema.number(description: 'Quantity (default 1)'),
            'unit': Schema.string(description: 'Unit (g, ml, pcs, etc.)'),
          },
          requiredProperties: ['list_id', 'name'],
        ),
      ),
      FunctionDeclaration(
        'ask_pick_list',
        'Show a picker so the user can choose which list to add an item to. '
            'Use this when the user said "add X" but has multiple lists.',
        Schema.object(
          properties: {
            'name': Schema.string(description: 'Item name'),
            'quantity': Schema.number(description: 'Quantity (default 1)'),
            'unit': Schema.string(description: 'Unit'),
          },
          requiredProperties: ['name'],
        ),
      ),
      FunctionDeclaration(
        'check_items',
        'Mark one or many items as checked (or unchecked) in a list.',
        Schema.object(
          properties: {
            'list_id': Schema.string(),
            'item_ids': Schema.array(items: Schema.string()),
            'checked': Schema.boolean(
              description: 'True to check, false to uncheck',
            ),
          },
          requiredProperties: ['list_id', 'item_ids'],
        ),
      ),
      FunctionDeclaration(
        'complete_list',
        'Mark every unchecked item in a list as checked — "finish shopping" for that list.',
        Schema.object(
          properties: {'list_id': Schema.string()},
          requiredProperties: ['list_id'],
        ),
      ),
      FunctionDeclaration(
        'add_history_items_to_list',
        'Add items from a past shopping history entry into a target list. '
            'If item_names is omitted, adds ALL items from the history entry.',
        Schema.object(
          properties: {
            'history_id': Schema.string(
              description: 'Shopping history entry ID',
            ),
            'list_id': Schema.string(description: 'Target list ID'),
            'item_names': Schema.array(
              description: 'Specific item names to add; omit for all',
              items: Schema.string(),
            ),
          },
          requiredProperties: ['history_id', 'list_id'],
        ),
      ),
      FunctionDeclaration(
        'update_setting',
        'Change any user setting. Supported keys: theme_mode (light/dark/system), '
            'accent_color (hex), language (en/de/system), notifications (true/false), '
            'display_name, diet_preferences (array), allergies (array), age, gender, '
            'height, calorie_tracking (true/false — shows/hides the calorie tab), '
            'zip_code (4-5 digit PLZ for local offer search; empty clears it).',
        Schema.object(
          properties: {
            'key': Schema.string(description: 'Setting key'),
            'value': Schema.string(
              description:
                  'New value as a string. For arrays, pass comma-separated values.',
            ),
          },
          requiredProperties: ['key', 'value'],
        ),
      ),
      FunctionDeclaration(
        'get_app_info',
        'Look up factual information about Shoply itself (pricing, premium, '
            'features, how-tos, privacy). ALWAYS use this instead of guessing.',
        Schema.object(
          properties: {
            'topic': Schema.string(
              description:
                  'Topic keyword, e.g. "premium", "pricing", "share", "recipes", "widgets"',
            ),
          },
          requiredProperties: ['topic'],
        ),
      ),
      FunctionDeclaration(
        'search_offers',
        'Search LIVE current supermarket offers (Angebote) for a product near the '
            'user, sorted cheapest first, across German grocery chains. Use this for '
            '"how much does X cost", "find X on offer", or "which store is cheapest '
            'for X". Only covers active promotional offers, not regular shelf prices — '
            'say so if nothing is found.',
        Schema.object(
          properties: {
            'query': Schema.string(
              description: 'Product to search for, e.g. "milk"',
            ),
          },
          requiredProperties: ['query'],
        ),
      ),
      FunctionDeclaration(
        'get_personalized_deals',
        'Show LIVE current supermarket offers (Angebote) that match items already '
            'sitting on the user\'s shopping lists — e.g. "what deals do I have?" or '
            '"anything on offer for my list?". Different from search_offers (looks up '
            'ONE named product) '
            'Requires the user\'s zip code (PLZ).',
        Schema.object(
          properties: {
            'limit': Schema.integer(
              description: 'Max deals to return (default 5)',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        'split_trip_cost',
        'Split a completed shopping trip\'s cost between the current user and named '
            'participants (equal split). ALWAYS call get_shopping_history first to '
            'resolve history_id from a hint like "yesterday\'s Lidl trip". If the trip '
            'has no known total_cost yet, you must ask the user for it and pass it.',
        Schema.object(
          properties: {
            'history_id': Schema.string(
              description: 'Shopping history entry ID to split',
            ),
            'participant_names': Schema.array(
              description:
                  'Names of the other people to split with (not including the current user)',
              items: Schema.string(),
            ),
            'total_cost': Schema.number(
              description: 'Total trip cost in EUR, only if not already known',
            ),
          },
          requiredProperties: ['history_id', 'participant_names'],
        ),
      ),
      FunctionDeclaration(
        'get_restock_suggestions',
        'Items the user is probably running low on, based on their own '
            'purchase rhythm (how often they historically re-buy each item). '
            'Excludes items already on an open list. Use when the user asks '
            'what they might need, what to buy, or restock ideas.',
        Schema.object(
          properties: {
            'limit': Schema.integer(
              description: 'Max suggestions to return (default 5)',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        'delete_item',
        'Delete an item from a shopping list. SAFETY: call this WITHOUT confirm '
            'first — it returns a confirmation question instead of deleting. Only '
            'call again with confirm=true after the user explicitly agrees.',
        Schema.object(
          properties: {
            'list_id': Schema.string(),
            'item_id': Schema.string(),
            'item_name': Schema.string(
              description: 'Item name, for the confirmation question',
            ),
            'confirm': Schema.boolean(
              description: 'Set true only after the user said yes',
            ),
          },
          requiredProperties: ['list_id', 'item_id', 'item_name'],
        ),
      ),
      FunctionDeclaration(
        'delete_list',
        'Permanently delete a whole shopping list. SAFETY: call this WITHOUT '
            'confirm first — it returns a confirmation question instead of deleting. '
            'Only call again with confirm=true after the user explicitly agrees.',
        Schema.object(
          properties: {
            'list_id': Schema.string(),
            'list_name': Schema.string(
              description: 'List name, for the confirmation question',
            ),
            'confirm': Schema.boolean(
              description: 'Set true only after the user said yes',
            ),
          },
          requiredProperties: ['list_id', 'list_name'],
        ),
      ),
      FunctionDeclaration(
        'update_item',
        'Edit an existing shopping list item: rename it and/or change its '
            'quantity, unit, or note. Pass ONLY the fields that should change. '
            'Get item_id from get_list_contents first.',
        Schema.object(
          properties: {
            'list_id': Schema.string(description: 'List the item is on'),
            'item_id': Schema.string(
              description: 'Item ID from get_list_contents',
            ),
            'new_name': Schema.string(
              description: 'New item name — only when renaming',
            ),
            'quantity': Schema.number(
              description: 'New quantity — only when changing it',
            ),
            'unit': Schema.string(
              description:
                  'New unit (g, ml, pcs, …) — only when changing it. '
                  'Pass an empty string to clear the unit.',
            ),
            'notes': Schema.string(
              description:
                  'New note — only when changing it. Pass an empty '
                  'string to remove the note.',
            ),
          },
          requiredProperties: ['list_id', 'item_id'],
        ),
      ),
      FunctionDeclaration(
        'move_items',
        'Move one or more items from one shopping list to another. Items keep '
            'their checked state, category, and price. Get item_ids from '
            'get_list_contents and the destination list_id from get_lists.',
        Schema.object(
          properties: {
            'from_list_id': Schema.string(
              description: 'List the items are on now',
            ),
            'to_list_id': Schema.string(description: 'Destination list ID'),
            'item_ids': Schema.array(items: Schema.string()),
          },
          requiredProperties: ['from_list_id', 'to_list_id', 'item_ids'],
        ),
      ),
      FunctionDeclaration(
        'create_list',
        'Create a new, empty shopping list. Returns its list_id so items can '
            'be added to it right away with add_item_to_list.',
        Schema.object(
          properties: {
            'name': Schema.string(description: 'Name of the new list'),
          },
          requiredProperties: ['name'],
        ),
      ),
      FunctionDeclaration(
        'rename_list',
        'Rename an existing shopping list.',
        Schema.object(
          properties: {
            'list_id': Schema.string(),
            'new_name': Schema.string(description: 'The new list name'),
          },
          requiredProperties: ['list_id', 'new_name'],
        ),
      ),
      FunctionDeclaration(
        'get_user_profile',
        'Read the user\'s current profile and settings: name, age, gender, '
            'height, diet preferences, allergies, language, theme, notifications, '
            'calorie tracking on/off, zip code, and the calorie goal summary if one '
            'is configured. Call this BEFORE guiding the user through settings or '
            'goal setup, so you never re-ask something already known.',
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'setup_nutrition_goal',
        'Set up (or replace) the user\'s calorie/macro goal — the same '
            'questionnaire as the goal-setup screen, done conversationally. Pass '
            'whatever is already known (from get_user_profile and the chat); the '
            'tool prefills the rest from the profile and returns missing fields '
            'to ask about. It calculates daily calorie + macro targets and saves '
            'them. If a configured goal already exists, it returns a confirmation '
            'question first — only pass confirm_replace=true after the user '
            'clearly agrees.',
        Schema.object(
          properties: {
            'goal_type': Schema.string(
              description: 'One of: lose_weight, gain_muscle, maintain, custom',
            ),
            'activity_level': Schema.string(
              description:
                  'One of: sedentary, light, moderate, active, very_active',
            ),
            'age': Schema.integer(description: 'Age in years'),
            'gender': Schema.string(
              description: 'male or female (used for the BMR formula)',
            ),
            'height_cm': Schema.number(description: 'Height in cm'),
            'current_weight_kg': Schema.number(
              description: 'Current weight in kg',
            ),
            'target_weight_kg': Schema.number(
              description:
                  'Target weight in kg — only for lose_weight/gain_muscle',
            ),
            'timeline_weeks': Schema.integer(
              description:
                  'Weeks to reach the target (default 12) — only for lose_weight/gain_muscle',
            ),
            'confirm_replace': Schema.boolean(
              description:
                  'Set true only after the user agreed to replace their existing goal',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        'get_nutrition_status',
        'Today\'s calorie tracking status: calories/protein/carbs/fat consumed '
            'and remaining vs. the user\'s targets, water intake, and every food '
            'diary entry logged today (with entry ids). Use for "how many calories '
            'do I have left", "what did I eat today", or before suggesting meals '
            'that fit the remaining budget.',
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'log_food',
        'Log a food the user ate into today\'s food diary. Only pass '
            'calories/protein_g/carbs_g/fat_g if the user explicitly stated them; '
            'when omitted, the tool AI-estimates nutrition from food_name + portion '
            'and reports estimated=true.',
        Schema.object(
          properties: {
            'food_name': Schema.string(
              description:
                  'What was eaten, e.g. "banana", "Spaghetti Bolognese"',
            ),
            'portion': Schema.string(
              description:
                  'Amount as the user said it, e.g. "200 g", "1 slice", "a large bowl"',
            ),
            'meal_type': Schema.string(
              description:
                  'One of: breakfast, lunch, dinner, snack. Omit to infer from the time of day.',
            ),
            'calories': Schema.integer(
              description: 'ONLY if the user stated the calories',
            ),
            'protein_g': Schema.number(
              description: 'ONLY if the user stated it',
            ),
            'carbs_g': Schema.number(description: 'ONLY if the user stated it'),
            'fat_g': Schema.number(description: 'ONLY if the user stated it'),
          },
          requiredProperties: ['food_name'],
        ),
      ),
      FunctionDeclaration(
        'log_water',
        'Log drinking water. A glass is ~250 ml, a small bottle 500 ml, a large '
            'bottle 1000 ml.',
        Schema.object(
          properties: {
            'amount_ml': Schema.integer(
              description: 'Amount in ml (default 250)',
            ),
          },
        ),
      ),
      FunctionDeclaration(
        'log_weight',
        'Log the user\'s current body weight for today (overwrites today\'s '
            'earlier entry if any). Use when the user tells you what they weigh.',
        Schema.object(
          properties: {
            'weight_kg': Schema.number(description: 'Weight in kilograms'),
          },
          requiredProperties: ['weight_kg'],
        ),
      ),
      FunctionDeclaration(
        'delete_food_log',
        'Delete one entry from today\'s food diary. SAFETY: call WITHOUT confirm '
            'first — it returns a confirmation question instead of deleting. Only '
            'call again with confirm=true after the user explicitly agrees. Get the '
            'entry_id from get_nutrition_status.',
        Schema.object(
          properties: {
            'entry_id': Schema.string(
              description: 'Diary entry id from get_nutrition_status',
            ),
            'food_name': Schema.string(
              description: 'Food name, for the confirmation question',
            ),
            'confirm': Schema.boolean(
              description: 'Set true only after the user said yes',
            ),
          },
          requiredProperties: ['entry_id', 'food_name'],
        ),
      ),
      FunctionDeclaration(
        'get_weekly_nutrition_summary',
        'A 7-day nutrition recap: average calories/protein/carbs/fat vs. targets, '
            'days logged, days within calorie budget, water, logging streak, cooked '
            'meals (incl. high-protein ones), and weight change if two weigh-ins '
            'exist this week. Use for "how was my week?" or a nutrition check-in.',
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'get_challenge_status',
        'Status of the user\'s active diet challenge(s) (16:8 intermittent fasting, '
            '30-day no sugar): current streak, whether they checked in today, '
            'adherence rate, and days remaining for fixed-length challenges. Use for '
            '"how\'s my fasting streak?" or "am I still on track with no sugar?". '
            'This tool is read-only — it cannot start, check in to, or end a '
            'challenge; that only happens in the app\'s Challenges screen.',
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'get_savings_summary',
        'The user\'s total savings (in EUR) from buying items at a live '
            'offer/deal price instead of the regular shelf price, both lifetime and '
            'for the current calendar month (with a comparison to last month). Use '
            'for "how much have I saved?", "has Shoply saved me money?", or "how '
            'much did I save this month?". Only counts items where both the paid '
            'price and the offer\'s regular price were known at the time. This '
            'mirrors the Shopping History screen exactly, so your answer and that '
            'screen always agree.',
        Schema.object(properties: {}),
      ),
    ],
  ),
];
