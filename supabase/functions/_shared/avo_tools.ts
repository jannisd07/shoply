// Avo's tools for the `avo_chat` task (plan B1.6). Ported from the old
// lib/data/services/avo_tool_declarations.dart, with these changes:
// - No tool can delete. delete_item, delete_list and delete_food_log are gone;
//   propose_delete only asks the app to show a confirmation card, and only the
//   person's tap there deletes (Konzept 16, 15.3).
// - compare_list_prices is gone and search_offers has no "cheapest store"
//   (plan 8: no market comparison).
// - Declared now, so the list stays the same from the first request on (a
//   changed tools array breaks the prompt cache and the thinking blocks):
//   get_plan, add_to_plan, plan_to_list, move_in_plan (remove_from_plan is
//   propose_delete with target_type plan_entry), set_module, log_workout. The
//   app answers a tool it cannot run yet with an is_error tool_result
//   ("not available yet").
// - get_app_info only answers what the app knows at runtime (Pro price, trial
//   and contents from the App Store, the person's subscription); the static
//   app knowledge lives in the system prompt (avo_system.ts).
// - update_setting no longer replaces whole lists: allergies and diet are
//   added or removed one entry at a time; calorie tracking is set_module.
// - get_user_profile says whether a postcode is set, never the postcode: the
//   app runs the offer tools with the region itself.
// - show_settings_link only shows a row to Konto or Konto löschen (A8): the
//   account is never changed through Avo.
//
// The app runs every tool with the person's own session (RLS); this server
// never executes one. checkToolInput is the schema check the app relies on
// before it runs a call (eager input streaming turns off the API's own
// buffering and validation, see tool-use-concepts.md).
//
// strict: true is limited by the API to 20 tools, 16 union-typed parameters
// and 24 optional parameters per request (structured outputs, "schema
// complexity limits"); more is a 400. So the reading tools are not strict, and
// neither are two writing tools whose nullable fields would pass the union
// limit: log_food (the app may show its estimate first) and
// setup_nutrition_goal (the app asks before it replaces a goal). For those two
// only checkToolInput guards the input. Every tool is still closed
// (additionalProperties: false) with every property required; a parameter the
// model may leave out is nullable. Non-strict tools are not grammar-
// constrained, so checkToolInput treats a missing nullable field there as null.
//
// Tools variant: "no_offers" is only for the offers kill switch
// (app_flags.offers_enabled false, Konzept 12 §10.4): no offer or savings
// tools, no offers module in set_module. A module that is merely off keeps
// "full"; the app answers the offer tools with an is_error tool_result
// ("module off") and Avo offers to switch it on. The app picks the variant
// when a conversation starts and keeps it for that conversation. If the kill
// switch flips mid-conversation, the app keeps the variant and answers the
// offer tools with an is_error tool_result. With the kill switch on, the app
// also leaves offer prices and savings out of every other tool result.
//
// Contract for the app beyond the schemas:
// - propose_delete: the app looks the target up by target_id with the person's
//   rights, shows its own stored name on the confirmation card (never the
//   model's label) and answers with an is_error tool_result when the target
//   does not exist or its name does not match the label.
// - BODY_DATA_TOOLS need the "Kalorien, Gewicht und Ziele" consent
//   (context consent_body). Without it the app answers them with an is_error
//   tool_result ("not shared"), log_food/log_water/log_weight/log_workout
//   results carry no totals or goals, and get_user_profile leaves out age,
//   height, weight and goals. Without consent_health it leaves out allergies
//   and diet.

import type Anthropic from "@anthropic-ai/sdk";

export type ToolsVariant = "full" | "no_offers";
export const TOOLS_VARIANTS: readonly ToolsVariant[] = ["full", "no_offers"];

/** The tools the no_offers variant leaves out (Konzept 12 §10.4). */
export const OFFER_TOOLS: readonly string[] = ["search_offers", "get_personalized_deals", "get_savings_summary"];

/** Tools that read calories, weight or goals; the app runs them only with consent_body. */
export const BODY_DATA_TOOLS: readonly string[] = [
  "get_nutrition_status",
  "get_weekly_nutrition_summary",
  "setup_nutrition_goal",
  "get_challenge_status",
];

const BODY_CONSENT = ' Needs "calories_weight_goals":"shared" in the app context; otherwise the app answers that ' +
  "the data is not shared.";

/** API limits for strict schemas in one request. */
export const STRICT_LIMITS = { tools: 20, unionParams: 16, optionalParams: 24 } as const;

export const DELETE_TARGET_TYPES = ["item", "list", "food_log", "plan_entry", "history_trip", "list_member"] as const;
export const MODULE_IDS = ["offers", "meal_plan", "calories", "avo", "cost_split"] as const;
export const MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"] as const;
export const SETTING_KEYS = [
  "theme_mode",
  "language",
  "notifications",
  "display_name",
  "age",
  "gender",
  "height_cm",
  "zip_code",
  "allergies_add",
  "allergies_remove",
  "diet_add",
  "diet_remove",
  "recipes_auto_adapt",
  "show_item_images",
  "suggestions_enabled",
  "start_list",
  "keep_screen_on",
  "share_presence",
  "notif_shopping_started",
  "notif_list_changes",
  "notif_shopping_completed",
  "notif_invitations",
  "notif_restock",
  "notif_cooking_timer",
  "notif_plan_reminder",
  "notif_dinner_ideas",
  "notif_cost_split_open",
  "notif_recipe_likes",
  "notif_recipe_comments",
  "notif_new_recipes",
  "notif_time_restock",
  "notif_time_dinner",
] as const;
export const APP_INFO_TOPICS = ["pro_plan", "my_subscription"] as const;
/** Pages of Settings where the person does what Avo never does (Kap. 16 5.7). */
export const SETTINGS_LINK_PAGES = ["account", "account_delete"] as const;

type Schema = Record<string, unknown>;

// ---------------------------------------------------------------------------
// Schema helpers (key order is fixed, so the JSON is byte-identical every time)

const text = (description: string): Schema => ({ type: "string", description });
const number = (description: string): Schema => ({ type: "number", description });
const integer = (description: string): Schema => ({ type: "integer", description });
const boolean = (description: string): Schema => ({ type: "boolean", description });
const date = (description: string): Schema => ({ type: "string", format: "date", description });
const texts = (description: string): Schema => ({ type: "array", items: { type: "string" }, description });
const choice = (values: readonly string[], description: string): Schema => ({
  type: "string",
  enum: [...values],
  description,
});

/** Nullable: the model passes null when the person did not say it. */
function orNull(inner: Schema, description: string): Schema {
  return { anyOf: [inner, { type: "null" }], description };
}

interface ToolSpec {
  name: string;
  description: string;
  strict: boolean;
  properties: Record<string, Schema>;
}

function deepFreeze<T>(value: T): T {
  if (typeof value === "object" && value !== null) {
    for (const inner of Object.values(value)) deepFreeze(inner);
    Object.freeze(value);
  }
  return value;
}

function tool(spec: ToolSpec): Anthropic.Beta.BetaTool {
  return deepFreeze({
    name: spec.name,
    description: spec.description,
    input_schema: {
      type: "object",
      properties: spec.properties,
      required: Object.keys(spec.properties),
      additionalProperties: false,
    },
    strict: spec.strict,
    eager_input_streaming: true,
  });
}

const LIST_ID = "List id from get_lists or from the app context.";

const MODULE_NAMES: Readonly<Record<typeof MODULE_IDS[number], string>> = {
  offers: "offers (Preise & Angebote)",
  meal_plan: "meal_plan (Wochenplan)",
  calories: "calories (Kalorien & Gesundheit)",
  avo: "avo",
  cost_split: "cost_split (Kosten teilen)",
};

function setModuleTool(variant: ToolsVariant): Anthropic.Beta.BetaTool {
  const modules = MODULE_IDS.filter((id) => variant === "full" || id !== "offers");
  return tool({
    name: "set_module",
    description: "Switch an app module on or off when the person asks for it; the app shows Undo. Modules: " +
      `${modules.map((id) => MODULE_NAMES[id]).join(", ")}.`,
    strict: true,
    properties: {
      module: choice(modules, "Which module."),
      enabled: boolean("true to switch it on, false to switch it off."),
    },
  });
}

// ---------------------------------------------------------------------------
// The tools, in a fixed order

const ALL_TOOLS: readonly Anthropic.Beta.BetaTool[] = Object.freeze([
  // Lists and items
  tool({
    name: "get_lists",
    description: "Show the person's shopping lists with id, name, market, number of open items and whether a list " +
      "is shared. Call it when you need a list id the app context does not give, or when the person asks about " +
      "their lists.",
    strict: false,
    properties: {},
  }),
  tool({
    name: "get_list_contents",
    description: "Show the items on one shopping list, with their ids. Call it before you change, check off, move " +
      "or propose deleting items whose ids you don't have yet.",
    strict: false,
    properties: { list_id: orNull({ type: "string" }, "List id; null for the list in the app context.") },
  }),
  tool({
    name: "add_item_to_list",
    description: "Add one item to a shopping list right away; the app shows Undo next to it. For several items, " +
      "call this once per item in the same turn. If the person did not say which list and the app context names " +
      "none while they have several lists, use ask_pick_list instead.",
    strict: true,
    properties: {
      list_id: text(LIST_ID),
      name: text('Item name as people write it on a list, without the amount, e.g. "Milch".'),
      quantity: orNull({ type: "number" }, "Amount the person said, e.g. 2 or 0.5; null if none."),
      unit: orNull({ type: "string" }, "Unit such as g, kg, ml, l or Stück; null if none."),
    },
  }),
  tool({
    name: "ask_pick_list",
    description: "Show the person a choice of their lists for an item, when it is unclear which list they mean. " +
      "The app adds the item to the list they tap.",
    strict: false,
    properties: {
      name: text("Item name."),
      quantity: orNull({ type: "number" }, "Amount; null if none."),
      unit: orNull({ type: "string" }, "Unit; null if none."),
    },
  }),
  tool({
    name: "check_items",
    description: "Check off items on a list, or uncheck them again. Get the item ids from get_list_contents.",
    strict: true,
    properties: {
      list_id: text(LIST_ID),
      item_ids: texts("Ids of the items to change."),
      checked: boolean("true to check off, false to uncheck."),
    },
  }),
  tool({
    name: "update_item",
    description: "Change an item: rename it or change its amount, unit or note. Pass null for every field that " +
      "stays the same. Get the item id from get_list_contents.",
    strict: true,
    properties: {
      list_id: text(LIST_ID),
      item_id: text("Item id from get_list_contents."),
      new_name: orNull({ type: "string" }, "New name; null to keep it."),
      quantity: orNull({ type: "number" }, "New amount; null to keep it."),
      unit: orNull({ type: "string" }, "New unit, or an empty string to remove it; null to keep it."),
      notes: orNull({ type: "string" }, "New note, or an empty string to remove it; null to keep it."),
    },
  }),
  tool({
    name: "move_items",
    description: "Move items from one list to another. They keep their checked state, category and price.",
    strict: true,
    properties: {
      from_list_id: text("List the items are on now."),
      to_list_id: text("List to move them to."),
      item_ids: texts("Ids of the items to move."),
    },
  }),
  tool({
    name: "create_list",
    description: "Create a new, empty shopping list and get its id, so items can be added to it right away.",
    strict: true,
    properties: { name: text("Name of the new list.") },
  }),
  tool({
    name: "rename_list",
    description: "Rename a shopping list.",
    strict: true,
    properties: { list_id: text(LIST_ID), new_name: text("The new name.") },
  }),
  tool({
    name: "complete_list",
    description: "Finish shopping for a list the way the app's finish button does: the trip goes into the " +
      "history and the checked items leave the list. Call it when the person says they are done shopping. The app " +
      "may ask them which market they were at.",
    strict: true,
    properties: { list_id: text(LIST_ID) },
  }),

  // History and restocking
  tool({
    name: "get_shopping_history",
    description: "Show the person's recent finished shopping trips with id, date, market and items.",
    strict: false,
    properties: { limit: orNull({ type: "integer" }, "How many trips, 1 to 30; null for 5.") },
  }),
  tool({
    name: "add_history_items_to_list",
    description: "Put items from a past shopping trip back on a list. Get the trip id from get_shopping_history.",
    strict: true,
    properties: {
      history_id: text("Trip id from get_shopping_history."),
      list_id: text(LIST_ID),
      item_names: texts("Names of the items to add; an empty array adds every item of the trip."),
    },
  }),
  tool({
    name: "get_restock_suggestions",
    description: "Items the person probably needs again soon, from how often they bought them before. Items on " +
      "an open list are left out. Call it for questions like what they might need or regularly buy.",
    strict: false,
    properties: { limit: orNull({ type: "integer" }, "How many suggestions, 1 to 10; null for 5.") },
  }),
  tool({
    name: "split_trip_cost",
    description: "Split the cost of a finished shopping trip equally between the person and others (module Kosten " +
      "teilen). Find the trip with get_shopping_history first. If the trip has no total yet, ask for it.",
    strict: true,
    properties: {
      history_id: text("Trip id from get_shopping_history."),
      participant_names: texts("Names of the other people, without the person themselves."),
      total_cost: orNull({ type: "number" }, "Total in euros if the trip has none yet; otherwise null."),
    },
  }),

  // Recipes
  tool({
    name: "search_recipes",
    description: "Search the recipe library and show matching recipes. The app always leaves out recipes with " +
      "the person's saved allergens, whatever you pass; still pass the allergens from the app context.",
    strict: false,
    properties: {
      query: text("Ingredients, dish, cuisine or meal type."),
      dietary_filters: orNull(
        { type: "array", items: { type: "string" } },
        "Tags recipes must have, e.g. vegan, vegetarisch, glutenfrei; null for none.",
      ),
      exclude_allergens: orNull(
        { type: "array", items: { type: "string" } },
        "Allergens to leave out, e.g. Erdnüsse; null for none.",
      ),
      max_results: orNull({ type: "integer" }, "How many recipes, 1 to 10; null for 5."),
    },
  }),
  tool({
    name: "get_saved_recipes",
    description: "Show the recipes the person saved.",
    strict: false,
    properties: {},
  }),
  tool({
    name: "get_recipe_nutrition",
    description: "Calories and macros per serving of a recipe, stored or estimated from its ingredients (then " +
      "marked as estimated). Pass the recipe id, or its name if you have no id.",
    strict: false,
    properties: {
      recipe_id: orNull({ type: "string" }, "Recipe id from search_recipes or get_saved_recipes; null if unknown."),
      recipe_name: orNull({ type: "string" }, "Recipe name; null when recipe_id is given."),
    },
  }),
  tool({
    name: "add_recipe_to_list",
    description: "Put all ingredients of a recipe on a shopping list in one go, optionally for another number of " +
      "servings. Ingredients already on the list are merged.",
    strict: true,
    properties: {
      list_id: text(LIST_ID),
      recipe_id: orNull({ type: "string" }, "Recipe id; null if unknown."),
      recipe_name: orNull({ type: "string" }, "Recipe name; null when recipe_id is given."),
      servings: orNull({ type: "integer" }, "Servings to scale to; null for the recipe's own servings."),
    },
  }),

  // Meal plan (module Wochenplan)
  tool({
    name: "get_plan",
    description: "Show the meal plan (module Wochenplan): which recipes are planned on which days, with entry " +
      "ids. Call it for questions like what is planned today or this week.",
    strict: false,
    properties: {
      from: orNull({ type: "string", format: "date" }, "First day, YYYY-MM-DD; null for today."),
      days: orNull({ type: "integer" }, "How many days, 1 to 14; null for 7."),
    },
  }),
  tool({
    name: "add_to_plan",
    description: "Plan a recipe for a day (module Wochenplan). If the day already has a recipe, the app asks " +
      "whether to add it or replace the planned one.",
    strict: true,
    properties: {
      date: date("Day, YYYY-MM-DD."),
      recipe_id: orNull({ type: "string" }, "Recipe id; null if unknown."),
      recipe_name: orNull({ type: "string" }, "Recipe name; null when recipe_id is given."),
      servings: orNull({ type: "integer" }, "Servings; null for the recipe's own servings."),
    },
  }),
  tool({
    name: "move_in_plan",
    description: "Move a planned recipe to another day (module Wochenplan). Get the entry id from get_plan.",
    strict: true,
    properties: { entry_id: text("Plan entry id from get_plan."), date: date("New day, YYYY-MM-DD.") },
  }),
  tool({
    name: "plan_to_list",
    description: "Put the ingredients of every recipe planned between two days on a shopping list, merged into " +
      "one line per ingredient (module Wochenplan).",
    strict: true,
    properties: {
      from: date("First day, YYYY-MM-DD."),
      to: date("Last day, YYYY-MM-DD."),
      list_id: text(LIST_ID),
    },
  }),

  // Calories and health (module Kalorien & Gesundheit)
  tool({
    name: "get_nutrition_status",
    description: "Today's calories, protein, carbs and fat eaten and left against the person's goal, water, and " +
      "today's food diary entries with ids. Call it for what is left today or what they ate." + BODY_CONSENT,
    strict: false,
    properties: {},
  }),
  tool({
    name: "log_food",
    description: "Put something the person ate into today's food diary. Pass calories and macros only if the " +
      "person said them; otherwise null, and the app estimates them and marks the entry as estimated. The app may " +
      "show the estimate to the person first; the result says whether the entry was saved.",
    strict: false,
    properties: {
      food_name: text('What was eaten, e.g. "Spaghetti Bolognese".'),
      portion: orNull({ type: "string" }, 'Amount as the person said it, e.g. "200 g" or "ein Teller"; null.'),
      meal_type: orNull({ type: "string", enum: [...MEAL_TYPES] }, "Meal; null to go by the time of day."),
      calories: orNull({ type: "integer" }, "kcal only if the person said it; otherwise null."),
      protein_g: orNull({ type: "number" }, "Protein in g only if the person said it; otherwise null."),
      carbs_g: orNull({ type: "number" }, "Carbohydrates in g only if the person said it; otherwise null."),
      fat_g: orNull({ type: "number" }, "Fat in g only if the person said it; otherwise null."),
    },
  }),
  tool({
    name: "log_water",
    description: "Log drinking water. A glass is about 250 ml, a small bottle 500 ml, a large bottle 1000 ml.",
    strict: true,
    properties: { amount_ml: integer("Amount in ml; 250 if the person said no amount.") },
  }),
  tool({
    name: "log_weight",
    description: "Log the person's body weight for today; it replaces an earlier entry from today.",
    strict: true,
    properties: { weight_kg: number("Weight in kg.") },
  }),
  tool({
    name: "log_workout",
    description: "Log a workout or other exercise for today (module Kalorien & Gesundheit).",
    strict: true,
    properties: {
      activity: text('What the person did, e.g. "Joggen" or "Krafttraining".'),
      duration_min: integer("Duration in minutes."),
      calories: orNull({ type: "integer" }, "kcal burned only if the person said it; otherwise null."),
    },
  }),
  tool({
    name: "get_weekly_nutrition_summary",
    description: "A 7-day recap: average calories and macros against the goal, days logged, days within the " +
      "calorie goal, water, streak, cooked meals and weight change. Call it for how their week went." + BODY_CONSENT,
    strict: false,
    properties: {},
  }),
  tool({
    name: "setup_nutrition_goal",
    description: "Set up or replace the person's calorie and macro goal in conversation. Pass what is already " +
      "known (get_user_profile and the chat), null for the rest; the result lists missing fields to ask about. " +
      "If a goal exists, the result asks for confirmation first; pass confirm_replace true only after a clear yes." +
      BODY_CONSENT,
    strict: false,
    properties: {
      goal_type: orNull(
        { type: "string", enum: ["lose_weight", "gain_muscle", "maintain", "custom"] },
        "Goal; null if unknown.",
      ),
      activity_level: orNull(
        { type: "string", enum: ["sedentary", "light", "moderate", "active", "very_active"] },
        "Activity level; null if unknown.",
      ),
      age: orNull({ type: "integer" }, "Age in years; null if unknown."),
      gender: orNull({ type: "string", enum: ["male", "female"] }, "For the BMR formula; null if unknown."),
      height_cm: orNull({ type: "number" }, "Height in cm; null if unknown."),
      current_weight_kg: orNull({ type: "number" }, "Current weight in kg; null if unknown."),
      target_weight_kg: orNull({ type: "number" }, "Target weight in kg, only to lose or gain; otherwise null."),
      timeline_weeks: orNull({ type: "integer" }, "Weeks to reach the target; null for 12."),
      confirm_replace: orNull({ type: "boolean" }, "true only after the person agreed to replace their goal."),
    },
  }),
  tool({
    name: "get_challenge_status",
    description: "Status of the person's active diet challenges (16:8 fasting, 30 days without sugar): streak, " +
      "today's check-in, adherence, days left. Read-only; starting or ending a challenge happens in the app." +
      BODY_CONSENT,
    strict: false,
    properties: {},
  }),

  // Offers (module Preise & Angebote; left out in the no_offers variant)
  tool({
    name: "search_offers",
    description: "Look up this week's offers for one product at one market, in the person's area: the market " +
      "of the list, or a market the person named. Offers only, no regular shelf prices; say so if nothing is " +
      "found. Never use it to compare markets.",
    strict: false,
    properties: {
      query: text('Product, e.g. "Milch".'),
      store: orNull({ type: "string" }, 'Market the person named, e.g. "Lidl"; null for the market of the list.'),
      list_id: orNull({ type: "string" }, "List whose market to use; null for the list in the app context."),
    },
  }),
  tool({
    name: "get_personalized_deals",
    description: "This week's offers at the market of a list for items that are on that list, in the person's " +
      'area. The result starts with a summary sentence the app wrote, e.g. "4 von 11 Artikeln diese Woche bei ' +
      'Lidl im Angebot, ca. 3,20 € gespart, in deiner Region"; the app has already rounded the amount and left it ' +
      "out under 0,50 €. Repeat that sentence as it is and never add up savings yourself. Each offer carries the " +
      "store's own was-price only where the store gives one. Call it for what is on offer from their list.",
    strict: false,
    properties: {
      list_id: orNull({ type: "string" }, "List; null for the list in the app context."),
      limit: orNull({ type: "integer" }, "How many offers, 1 to 10; null for 5."),
    },
  }),
  tool({
    name: "get_savings_summary",
    description: "What the person saved by buying items on offer, according to the stores: this month, last " +
      "month and overall, only from items where the offer and the regular price were known. It matches the " +
      "history screen; the app has already rounded the amounts, so repeat them as they are.",
    strict: false,
    properties: {},
  }),

  // Settings, modules and the app
  tool({
    name: "get_user_profile",
    description: "The person's profile and settings: name, language, theme, notifications, whether a postcode " +
      'is set, and which modules are on. Allergies and diet are included only with "diet_and_allergies":"shared" ' +
      'in the app context; age, height, weight and goals only with "calories_weight_goals":"shared". Call it ' +
      "before guiding them through settings.",
    strict: false,
    properties: {},
  }),
  tool({
    name: "update_setting",
    description: "Change one setting right away; the app shows Undo. Keys: theme_mode (light, dark, system), " +
      "language (de, en, system), notifications (true, false: all notifications), display_name, " +
      "age, gender, height_cm, zip_code (5-digit postcode; an empty string removes it). allergies_add, " +
      "allergies_remove, diet_add and diet_remove change exactly one entry; the app asks the person to confirm " +
      "before an allergy is removed. true or false: recipes_auto_adapt (recipes swap what does not fit the diet), " +
      "show_item_images, suggestions_enabled (suggestions at the end of a list), keep_screen_on (while " +
      "shopping), share_presence (others see that the person is shopping), and the single notifications " +
      "notif_shopping_started, notif_list_changes, notif_shopping_completed, notif_invitations, notif_restock, " +
      "notif_cooking_timer, notif_plan_reminder, notif_dinner_ideas, notif_cost_split_open, notif_recipe_likes, " +
      "notif_recipe_comments, notif_new_recipes. notif_time_restock and notif_time_dinner take a time like 18:30. " +
      "start_list takes a list name, or last for the list used last.",
    strict: true,
    properties: {
      key: choice(SETTING_KEYS, "Which setting."),
      value: text('New value as text; for the _add and _remove keys a single entry, e.g. "Erdnüsse".'),
    },
  }),
  setModuleTool("full"),
  tool({
    name: "get_app_info",
    description: "Facts only the app knows right now. pro_plan: price, trial and contents of Avo Pro from the " +
      "App Store and the app. my_subscription: whether the person has Avo Pro. Call it before you name any price " +
      "or Pro feature.",
    strict: false,
    properties: { topic: choice(APP_INFO_TOPICS, "What to look up.") },
  }),
  tool({
    name: "show_settings_link",
    description: "Show a row that opens the page of Settings where the person does something themselves that you " +
      "never do. account: signing out, email, password. account_delete: deleting the account. Call it when they " +
      "ask for one of these, then say in one sentence that they do it there. Nothing changes until they act on " +
      "that page.",
    strict: false,
    properties: { page: choice(SETTINGS_LINK_PAGES, "Which page.") },
  }),

  // Deleting
  tool({
    name: "propose_delete",
    description: "Ask the user to confirm a deletion in the app; you cannot delete anything yourself. Call it " +
      "when the person asks to delete or remove an item, a list, a food diary entry, a meal plan entry, a past " +
      "shopping trip or a list member, once per thing. The app shows a confirmation card and only the person's " +
      "tap on Delete deletes. The result only says that the card is shown; nothing is deleted yet.",
    strict: true,
    properties: {
      target_type: choice(DELETE_TARGET_TYPES, "What kind of thing."),
      target_id: text("Its id, from the tool that listed it."),
      label: text(
        'The name you believe it has, e.g. "Party" or "Milch". The app shows its own stored name for target_id ' +
          "on the card, not this label; if the target does not exist or its name does not match, the result is " +
          "an error.",
      ),
    },
  }),
]);

const NO_OFFERS_SET_MODULE = setModuleTool("no_offers");

const BY_VARIANT: Readonly<Record<ToolsVariant, readonly Anthropic.Beta.BetaTool[]>> = Object.freeze({
  full: ALL_TOOLS,
  no_offers: Object.freeze(
    ALL_TOOLS.filter((t) => !OFFER_TOOLS.includes(t.name)).map((t) =>
      t.name === "set_module" ? NO_OFFERS_SET_MODULE : t
    ),
  ),
});

/** The tools of a variant, same objects in the same order on every call. */
export function avoTools(variant: ToolsVariant): Anthropic.Beta.BetaTool[] {
  return [...BY_VARIANT[variant]];
}

// ---------------------------------------------------------------------------
// Input check

export type ToolInputCheck =
  | { ok: true; input: Record<string, unknown> }
  | { ok: false; error: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function allowsNull(schema: Schema): boolean {
  return schema.type === "null" || (Array.isArray(schema.anyOf) && schema.anyOf.some((s) => allowsNull(s as Schema)));
}

function isDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

class InputError extends Error {}

/** Returns the value as checked, with missing nullable fields filled in when `lenient`. */
function checked(schema: Schema, value: unknown, path: string, lenient: boolean): unknown {
  if (Array.isArray(schema.anyOf)) {
    for (const branch of schema.anyOf as Schema[]) {
      try {
        return checked(branch, value, path, lenient);
      } catch (err) {
        if (!(err instanceof InputError)) throw err;
      }
    }
    throw new InputError(`${path}: unexpected value`);
  }
  switch (schema.type) {
    case "null":
      if (value !== null) throw new InputError(`${path}: expected null`);
      return value;
    case "string":
      if (typeof value !== "string") throw new InputError(`${path}: expected a string`);
      if (Array.isArray(schema.enum) && !schema.enum.includes(value)) {
        throw new InputError(`${path}: expected one of ${(schema.enum as string[]).join(", ")}`);
      }
      if (schema.format === "date" && !isDate(value)) throw new InputError(`${path}: expected a date YYYY-MM-DD`);
      return value;
    case "number":
      if (typeof value !== "number" || !Number.isFinite(value)) throw new InputError(`${path}: expected a number`);
      return value;
    case "integer":
      if (typeof value !== "number" || !Number.isInteger(value)) throw new InputError(`${path}: expected an integer`);
      return value;
    case "boolean":
      if (typeof value !== "boolean") throw new InputError(`${path}: expected true or false`);
      return value;
    case "array":
      if (!Array.isArray(value)) throw new InputError(`${path}: expected an array`);
      return value.map((entry, i) => checked(schema.items as Schema, entry, `${path}[${i}]`, lenient));
    case "object": {
      if (!isRecord(value)) throw new InputError(`${path}: expected an object`);
      const properties = (schema.properties ?? {}) as Record<string, Schema>;
      const unknown = Object.keys(value).filter((key) => !Object.hasOwn(properties, key));
      if (unknown.length > 0) {
        const allowed = Object.keys(properties).join(", ") || "none";
        throw new InputError(`${path}: unknown field ${unknown.join(", ")} (allowed: ${allowed})`);
      }
      const out: Record<string, unknown> = {};
      for (const [key, inner] of Object.entries(properties)) {
        if (!Object.hasOwn(value, key)) {
          if (lenient && allowsNull(inner)) {
            out[key] = null;
            continue;
          }
          throw new InputError(`${path}.${key}: required`);
        }
        out[key] = checked(inner, value[key], `${path}.${key}`, lenient);
      }
      return out;
    }
    default:
      throw new InputError(`${path}: unsupported schema`);
  }
}

/**
 * Checks a tool call against its schema in the given variant. The error text
 * is meant for an is_error tool_result, so the model can correct the call.
 */
export function checkToolInput(name: string, input: unknown, variant: ToolsVariant): ToolInputCheck {
  const tools = BY_VARIANT[variant];
  const found = tools.find((t) => t.name === name);
  if (!found) {
    const near = tools.find((t) => t.name.toLowerCase() === name.toLowerCase());
    return { ok: false, error: near ? `unknown tool ${name}; did you mean ${near.name}?` : `unknown tool ${name}` };
  }
  try {
    const value = checked(found.input_schema as Schema, input, "input", found.strict !== true);
    return { ok: true, input: value as Record<string, unknown> };
  } catch (err) {
    if (err instanceof InputError) return { ok: false, error: `${name}: ${err.message}` };
    throw err;
  }
}
