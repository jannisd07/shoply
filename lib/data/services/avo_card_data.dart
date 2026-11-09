import 'dart:typed_data';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/data/services/offer_savings.dart';

// What Avo's answer cards of Kap. 5.2–5.7 and 7 show. The service fills
// them from what its tools did; the tab only draws them. Writes are
// [AvoRecord]s (with their way back), everything else [AvoCardData].

/// Takes a write back if the data is still as Avo left it.
typedef AvoUndo = Future<AvoUndoResult> Function();

// ---------------------------------------------------------------- records

/// Where items Avo put on a list in one go came from.
enum AvoItemsSource { recipe, history, plan, photo, restock }

/// A write Avo made that is not one of a list's own changes (those are
/// [AvoListChange]): the card's head names the object and what happened,
/// [undo] is "Widerrufen" (null when it cannot be taken back).
sealed class AvoRecord {
  const AvoRecord({required this.tool, this.undo});

  /// The tool (or card) that wrote it; a retry note names it.
  final String tool;
  final AvoUndo? undo;

  /// The list it wrote to, for the retry note; null for none.
  String? get noteListName => null;
}

/// Several items on one list at once (recipe, past trip, meal plan, photo):
/// "Wocheneinkauf / 9 Zutaten hinzugefügt · für 4 Portionen · 2 standen schon
/// drauf: Zwiebeln, Olivenöl".
final class AvoItemsRecord extends AvoRecord {
  const AvoItemsRecord({
    required super.tool,
    super.undo,
    required this.source,
    required this.listId,
    required this.listName,
    required this.added,
    this.alreadyOn = const [],
    this.recipeName,
    this.servings,
  });

  final AvoItemsSource source;
  final String listId;
  final String listName;

  /// Lines written (new rows and merged ones).
  final int added;

  /// Names that were on the list already and got their quantity raised.
  final List<String> alreadyOn;

  /// [AvoItemsSource.recipe]: the recipe and the servings it was scaled to.
  final String? recipeName;
  final int? servings;

  @override
  String? get noteListName => listName;
}

/// A recipe planned for a day, or moved to another (module Wochenplan).
final class AvoPlanRecord extends AvoRecord {
  const AvoPlanRecord({
    required super.tool,
    super.undo,
    required this.recipeName,
    required this.day,
    this.servings,
    this.moved = false,
  });

  final String recipeName;

  /// The day it is planned on now.
  final DateTime day;
  final int? servings;

  /// `move_in_plan`: "Verschoben auf Fr., 13. Nov.".
  final bool moved;
}

/// "Wasser / 250 ml eingetragen · heute 1,25 von 2 l".
final class AvoWaterRecord extends AvoRecord {
  const AvoWaterRecord({
    required super.tool,
    super.undo,
    required this.amountMl,
    required this.totalMl,
    required this.targetMl,
  });

  final int amountMl;
  final int totalMl;
  final int targetMl;
}

/// "Gewicht / 78,4 kg eingetragen · Sa., 7. Nov.".
final class AvoWeightRecord extends AvoRecord {
  const AvoWeightRecord({
    required super.tool,
    super.undo,
    required this.kg,
    required this.day,
  });

  final double kg;
  final DateTime day;
}

/// "Laufen / 30 Min eingetragen · ca. 310 kcal, geschätzt".
final class AvoWorkoutRecord extends AvoRecord {
  const AvoWorkoutRecord({
    required super.tool,
    super.undo,
    required this.type,
    required this.minutes,
    required this.kcal,
    required this.estimated,
  });

  final WorkoutType type;
  final int minutes;
  final int kcal;
  final bool estimated;
}

/// "Spaghetti Bolognese eingetragen / Mittagessen · 650 kcal · noch 640 kcal
/// übrig" after "Eintragen" on an estimate (Kap. 7.2).
final class AvoFoodRecord extends AvoRecord {
  const AvoFoodRecord({
    required super.tool,
    super.undo,
    required this.name,
    required this.meal,
    required this.kcal,
    this.leftKcal,
  });

  final String name;
  final MealType meal;
  final int kcal;

  /// Goal minus today's total after the entry (negative: over the goal);
  /// null without a goal.
  final int? leftKcal;
}

/// "Ziel übernommen: 1.800 kcal am Tag".
final class AvoGoalRecord extends AvoRecord {
  const AvoGoalRecord({
    required super.tool,
    super.undo,
    required this.kcal,
    this.previousKcal,
  });

  final int kcal;
  final int? previousKcal;
}

/// A setting Avo changed (`update_setting`), with the raw values so the card
/// can name them in the person's language and undo can set the old one.
final class AvoSettingRecord extends AvoRecord {
  const AvoSettingRecord({
    required super.tool,
    super.undo,
    required this.key,
    required this.value,
    this.previous,
  });

  /// The setting key (`theme_mode`, `allergies_add`, `zip_code`, …).
  final String key;

  /// The new value as stored (`dark`, `de`, `true`, an allergy, a zip code).
  final String value;

  /// The value before; null when there was none.
  final String? previous;
}

/// A module switched on or off (`set_module`), with "Widerrufen".
final class AvoModuleRecord extends AvoRecord {
  const AvoModuleRecord({
    required super.tool,
    super.undo,
    required this.module,
    required this.enabled,
    this.applyAfterAnswer,
  });

  final AppModule module;
  final bool enabled;

  /// Switching Avo itself off waits until the answer is done (the tab goes
  /// away with it): the conversation runs this once the answer finished.
  final Future<void> Function()? applyAfterAnswer;
}

/// One share of a split trip.
typedef AvoShare = ({String name, double amount, bool isYou});

/// "Einkauf vom 31. Okt. / Geteilt: Lena 21,40 € · du 21,40 €". There is no
/// way back yet (L9), so it has no undo.
final class AvoSplitRecord extends AvoRecord {
  const AvoSplitRecord({
    required super.tool,
    required this.tripDate,
    required this.shares,
  });

  final DateTime tripDate;
  final List<AvoShare> shares;
}

// ------------------------------------------------------------------ cards

/// What a read or a question of Avo shows (no write of its own).
sealed class AvoCardData {
  const AvoCardData();
}

/// `get_shopping_history`: the trips, newest first (empty: "Noch keine
/// Einkäufe gespeichert.").
final class AvoTripsCard extends AvoCardData {
  const AvoTripsCard(this.trips, {this.listId, this.listName});

  final List<ShoppingHistory> trips;

  /// Where "Alle wieder auf {Liste}" puts the newest trip.
  final String? listId;
  final String? listName;
}

/// One "Vielleicht auch" row of [AvoRestockCard].
typedef AvoRestockLine = ({
  String name,
  int everyDays,
  double? quantity,
  String? category,
});

/// `get_restock_suggestions`: "Vielleicht auch · Milch / kaufst du etwa alle
/// 6 Tage"; a tap on a row puts it on [listId].
final class AvoRestockCard extends AvoCardData {
  const AvoRestockCard(this.lines, {this.listId, this.listName});

  final List<AvoRestockLine> lines;
  final String? listId;
  final String? listName;
}

/// `search_recipes` / `get_saved_recipes`: up to three recipe rows.
final class AvoRecipesCard extends AvoCardData {
  const AvoRecipesCard(
    this.recipes, {
    this.saved = false,
    this.allergensHidden = false,
    this.query,
  });

  final List<Recipe> recipes;

  /// "Gemerkt" instead of "Rezepte".
  final bool saved;

  /// Recipes with the person's allergens were left out.
  final bool allergensHidden;

  /// For "Mehr Rezepte" (`/recipes?q=`).
  final String? query;
}

/// `get_recipe_nutrition`: four values per serving.
final class AvoRecipeNutritionCard extends AvoCardData {
  const AvoRecipeNutritionCard({
    required this.recipeName,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.estimated = false,
  });

  final String recipeName;
  final int? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final bool estimated;
}

/// One planned recipe.
typedef AvoPlanLine = ({
  String entryId,
  DateTime day,
  String? recipeId,
  String name,
  int servings,
  String? imageUrl,
  int? kcal,
});

/// `get_plan`: what is planned from [from] on.
final class AvoPlanCard extends AvoCardData {
  const AvoPlanCard({
    required this.from,
    required this.days,
    required this.lines,
  });

  final DateTime from;
  final int days;
  final List<AvoPlanLine> lines;
}

/// `add_to_plan` on a day that has a recipe: "Am Mittwoch steht schon
/// Linsencurry. · Dazulegen · Ersetzen". Nothing is planned until a tap.
final class AvoPlanTakenCard extends AvoCardData {
  const AvoPlanTakenCard({
    required this.day,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.plannedName,
    required this.plannedEntryIds,
  });

  final DateTime day;
  final String recipeId;
  final String recipeName;
  final int servings;

  /// What is planned on [day] already, and its entries (for "Ersetzen").
  final String plannedName;
  final List<String> plannedEntryIds;
}

/// `search_offers`: this week's offers at the list's market, in the
/// person's region.
final class AvoOfferSearchCard extends AvoCardData {
  const AvoOfferSearchCard({
    required this.storeName,
    required this.offers,
    required this.query,
    required this.zip,
    this.listId,
  });

  final String storeName;
  final List<StoreOffer> offers;

  /// What was searched ("Milch"): the name an added item gets.
  final String query;
  final String zip;
  final String? listId;
}

/// An offer question that needs something first: a real region ("Für
/// Angebote in deiner Region: Postleitzahl festlegen") or the list's market.
final class AvoOfferSetupCard extends AvoCardData {
  const AvoOfferSetupCard.region() : listId = null, listName = null;

  const AvoOfferSetupCard.store({required String this.listId, this.listName});

  /// Set for "{Liste} hat noch keinen Markt.".
  final String? listId;
  final String? listName;

  bool get needsRegion => listId == null;
}

/// `get_personalized_deals`: "4 von 11 Artikeln diese Woche bei Lidl im
/// Angebot / ca. 3,20 € gespart, in deiner Region", unfolding to the offers.
final class AvoDealsCard extends AvoCardData {
  const AvoDealsCard({
    required this.listId,
    required this.listName,
    required this.summary,
    required this.offers,
  });

  final String listId;
  final String listName;
  final OfferSummary summary;

  /// The item names with their offer.
  final List<({String item, StoreOffer offer})> offers;
}

/// `get_savings_summary`: "November: ca. 12,40 € durch Angebote gespart /
/// laut Händler · 6 Einkäufe".
final class AvoSavingsCard extends AvoCardData {
  const AvoSavingsCard({
    required this.month,
    required this.trips,
    this.savedCents,
  });

  final DateTime month;
  final int trips;

  /// Rounded to 10 ct; null below 0,50 € or without a real region.
  final int? savedCents;
}

/// `get_nutrition_status`: "640 kcal übrig / 1.360 von 2.000 kcal heute".
final class AvoNutritionStatusCard extends AvoCardData {
  const AvoNutritionStatusCard({required this.consumedKcal, this.goalKcal});

  final int consumedKcal;
  final int? goalKcal;
}

/// `get_weekly_nutrition_summary`: the last seven days as bars.
final class AvoWeekCard extends AvoCardData {
  const AvoWeekCard({
    required this.days,
    required this.kcalByDay,
    required this.averageKcal,
    this.goalKcal,
  });

  final List<DateTime> days;
  final Map<DateTime, int> kcalByDay;
  final int averageKcal;
  final int? goalKcal;
}

/// One active challenge.
typedef AvoChallengeLine = ({
  ChallengeType type,
  String? title,
  int day,
  int? totalDays,
  bool checkedInToday,
});

/// `get_challenge_status`.
final class AvoChallengesCard extends AvoCardData {
  const AvoChallengesCard(this.challenges);

  final List<AvoChallengeLine> challenges;
}

/// Avo's estimate of a meal (`log_food` or a meal photo, Kap. 7.2): never
/// saved until "Eintragen".
final class AvoEstimateCard extends AvoCardData {
  const AvoEstimateCard({
    required this.name,
    required this.kcal,
    required this.meal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.confidence,
    this.estimated = true,
    this.portion,
    this.grams,
    this.photo,
    this.allergens = const [],
  });

  final String name;
  final int kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  /// `high`, `medium` or `low` (photo), null for a text estimate.
  final String? confidence;

  /// False when the person said the numbers.
  final bool estimated;

  /// The meal by the time of day, changeable on the card.
  final MealType meal;

  /// As the person said it ("ein Teller"), or Avo's grams.
  final String? portion;
  final int? grams;

  /// The meal photo (stays on the device until "Eintragen" uploads it).
  final Uint8List? photo;

  /// The person's allergies the meal probably contains.
  final List<String> allergens;
}

/// `setup_nutrition_goal` when a goal exists: "Neues Ziel: 1.800 kcal am Tag
/// / bisher 2.000"; only "Übernehmen" saves [goal].
final class AvoGoalPreviewCard extends AvoCardData {
  const AvoGoalPreviewCard({required this.goal, this.previous});

  final NutritionGoal goal;
  final NutritionGoal? previous;
}

/// `update_setting` with `allergies_remove`: the safety confirm card (Kap.
/// 6.5); only "Entfernen" removes [allergen].
final class AvoAllergyCard extends AvoCardData {
  const AvoAllergyCard(this.allergen);

  /// The allergy as the person stored it.
  final String allergen;
}

/// `update_setting` that did not work.
final class AvoSettingFailedCard extends AvoCardData {
  const AvoSettingFailedCard(this.key);

  final String key;
}

/// `get_app_info`: a row to the Pro page.
final class AvoAppInfoCard extends AvoCardData {
  const AvoAppInfoCard({required this.isPro});

  final bool isPro;
}

/// "Was soll ich mit dem Foto machen?" (Kap. 7.1).
final class AvoPhotoChoiceCard extends AvoCardData {
  const AvoPhotoChoiceCard({required this.caloriesOn});

  /// "Als Essen eintragen" only with the module on.
  final bool caloriesOn;
}

/// A photographed shopping note (Kap. 7.3): the items to choose from, what
/// could not be read, and where they go.
final class AvoListImportCard extends AvoCardData {
  const AvoListImportCard({
    required this.items,
    this.unreadable = const [],
    this.listId,
  });

  final List<ExtractedListItem> items;
  final List<String> unreadable;

  /// The list from the context; null asks "Auf welche Liste?".
  final String? listId;
}

/// A photo Avo could not use (Kap. 7.4): the code of
/// `MealPhotoException`/`ListImportException`.
final class AvoPhotoErrorCard extends AvoCardData {
  const AvoPhotoErrorCard({required this.code, required this.meal});

  final String code;

  /// A meal photo (else a shopping note).
  final bool meal;
}

/// The meal of the day at [time] (Kap. 7.2: "Mahlzeit nach Uhrzeit").
MealType avoMealAt(DateTime time) {
  final hour = time.hour;
  if (hour < 11) return MealType.breakfast;
  if (hour < 15) return MealType.lunch;
  if (hour >= 17 && hour < 22) return MealType.dinner;
  return MealType.snack;
}
