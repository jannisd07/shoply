part of 'avo_assistant_service.dart';

// Recipes and the meal plan (Kap. 5.3, 5.4).
extension AvoRecipeTools on AvoAssistantService {
  Future<Map<String, Object?>> _toolSearchRecipes(
    Map<String, Object?> args,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    final query = (args['query'] as String?) ?? '';
    final filters = AvoAssistantService._stringList(args['dietary_filters']);
    final max = ((args['max_results'] as num?)?.toInt() ?? 5).clamp(1, 10);

    var recipes = await RecipeService.instance.searchRecipes(query);

    // Apply dietary filters (recipes must have all specified labels).
    if (filters.isNotEmpty) {
      recipes = recipes
          .where(
            (r) => filters.every(
              (f) => r.labels.any((l) => l.toLowerCase() == f.toLowerCase()),
            ),
          )
          .toList();
    }

    // The person's saved allergies always leave recipes out (the server
    // promises it, whatever the model passes), plus any the model named.
    // Matched on the device; nothing of it goes to the model.
    final matcher = AllergenMatcher([
      ...?context?.allergies,
      ...AvoAssistantService._stringList(args['exclude_allergens']),
    ]);
    final before = recipes.length;
    if (matcher.allergies.isNotEmpty) {
      recipes = recipes
          .where(
            (r) => !matcher.anyIngredient(r.ingredients.map((i) => i.name)),
          )
          .toList();
    }
    final allergensHidden = recipes.length < before;

    final top = recipes.take(max).toList();
    payloads.add(
      AvoWidgetPayload.card(
        AvoRecipesCard(
          top,
          allergensHidden: allergensHidden,
          query: query.trim().isEmpty ? null : query.trim(),
        ),
      ),
    );
    return {
      'found': top.length,
      if (allergensHidden) 'left_out_for_allergies': true,
      'recipes': top
          .map(
            (r) => {
              'id': r.id,
              'name': r.name,
              'time_minutes': r.totalTimeMinutes,
              'rating': r.averageRating,
              'labels': r.labels,
              if (r.nutrition?.calories != null)
                'calories_per_serving': r.nutrition!.calories,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolSavedRecipes(
    List<AvoWidgetPayload> payloads,
  ) async {
    final saved = await RecipeService.instance.getSavedRecipes();
    final top = saved.take(10).toList();
    payloads.add(AvoWidgetPayload.card(AvoRecipesCard(top, saved: true)));
    return {
      'found': top.length,
      'recipes': top.map((r) => {'id': r.id, 'name': r.name}).toList(),
    };
  }

  /// Resolves a recipe by id (exact match against the full library) or,
  /// failing that, by a free-text name (first search result) — the shared
  /// lookup every recipe-scoped tool (nutrition, add-to-list) needs.
  /// [byId] looks an id up first (the meal plan's own lookup, with its
  /// cache); else the recipe service.
  Future<Recipe?> _resolveRecipe(
    String? id,
    String? name, {
    Future<Recipe?> Function(String id)? byId,
  }) async {
    if (id != null && id.isNotEmpty) {
      try {
        final found = byId == null
            ? await RecipeService.instance.getRecipeById(id)
            : await byId(id);
        if (found != null) return found;
      } catch (_) {
        // Not found (or a hallucinated id) — fall back to the name search.
      }
    }
    if (name != null && name.isNotEmpty) {
      final results = await RecipeService.instance.searchRecipes(name);
      if (results.isNotEmpty) return results.first;
    }
    return null;
  }

  Future<Map<String, Object?>> _toolRecipeNutrition(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final recipe = await _resolveRecipe(
      args['recipe_id'] as String?,
      args['recipe_name'] as String?,
    );

    if (recipe == null) {
      return {'error': 'Recipe not found'};
    }

    // Use existing nutrition if available; otherwise estimate from ingredients.
    final existing = recipe.nutrition;
    if (existing != null && existing.hasData) {
      payloads.add(
        AvoWidgetPayload.card(
          AvoRecipeNutritionCard(
            recipeName: recipe.name,
            kcal: existing.calories,
            proteinG: existing.proteinG,
            carbsG: existing.carbsG,
            fatG: existing.fatG,
          ),
        ),
      );
      return {
        'recipe': recipe.name,
        'servings': recipe.defaultServings,
        'calories': existing.calories,
        'source': 'stored',
      };
    }

    // Ask Gemini to ESTIMATE for us via a one-shot prompt that bypasses the tools.
    final estimate = await _estimateNutrition(recipe);
    if (estimate['calories'] != null) {
      payloads.add(
        AvoWidgetPayload.card(
          AvoRecipeNutritionCard(
            recipeName: recipe.name,
            kcal: estimate['calories'] as int?,
            proteinG: (estimate['protein_g'] as num?)?.toDouble(),
            carbsG: (estimate['carbs_g'] as num?)?.toDouble(),
            fatG: (estimate['fat_g'] as num?)?.toDouble(),
            estimated: true,
          ),
        ),
      );
    }
    return {
      'recipe': recipe.name,
      'servings': recipe.defaultServings,
      'source': 'estimated',
      ...estimate,
    };
  }

  /// Puts every ingredient of a recipe on a list in one batch, the way the
  /// recipe's own "Zutaten auf die Liste" does (`ItemRepository.addItems`,
  /// merged into open items of the same name and unit). The card names what
  /// was on the list already and offers "Widerrufen".
  Future<Map<String, Object?>> _toolAddRecipeToList(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final listId = args['list_id'] as String?;
    if (listId == null || listId.isEmpty) {
      return {
        'error': 'list_id is required — call get_lists first to resolve it',
      };
    }
    final recipe = await _resolveRecipe(
      args['recipe_id'] as String?,
      args['recipe_name'] as String?,
    );
    if (recipe == null) return {'error': 'Recipe not found'};
    if (recipe.ingredients.isEmpty) {
      return {'error': '"${recipe.name}" has no stored ingredients to add'};
    }

    final requestedServings = (args['servings'] as num?)?.toInt();
    final scale =
        requestedServings != null &&
        requestedServings > 0 &&
        requestedServings != recipe.defaultServings;
    final ingredients = scale
        ? recipe.ingredients
              .map(
                (i) => i.adjustForServings(
                  recipe.defaultServings,
                  requestedServings,
                ),
              )
              .toList()
        : recipe.ingredients;
    final servings = scale ? requestedServings : recipe.defaultServings;

    final record = await AvoAssistantService._changes(ref).addBatch(
      tool: 'add_recipe_to_list',
      source: AvoItemsSource.recipe,
      listId: listId,
      items: [
        for (final i in ingredients)
          NewItem(
            name: i.name,
            quantity: i.amount > 0 ? i.amount : 1,
            unit: i.unit.isEmpty ? null : i.unit,
          ),
      ],
      recipeName: recipe.name,
      servings: servings,
    );
    payloads.add(AvoWidgetPayload.record(record));
    await _afterBulkListChange(
      ref,
      listId,
      addedItemName: record.added > 0 ? recipe.name : null,
    );

    return {
      'recipe': recipe.name,
      'servings': servings,
      'list_id': listId,
      'added': record.added,
      'total_ingredients': ingredients.length,
      if (record.alreadyOn.isNotEmpty) 'already_on_list': record.alreadyOn,
    };
  }

  bool _planOn(WidgetRef ref) =>
      ref.read(moduleEnabledProvider(AppModule.mealPlan));

  Map<String, Object?> _planOff(WidgetRef ref) => {
    'not_available': true,
    'error': AvoAssistantService._t(ref, 'avo_plan_module_off'),
  };

  Map<String, Object?> _toolGetPlan(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) {
    if (!_planOn(ref)) return _planOff(ref);
    final now = DateTime.now();
    final from =
        AvoAssistantService._day(args['from']) ??
        DateTime(now.year, now.month, now.day);
    final days = ((args['days'] as num?)?.toInt() ?? 7).clamp(1, 14);
    final entries = [
      for (var i = 0; i < days; i++)
        ...ref.read(planEntriesForDayProvider(from.add(Duration(days: i)))),
    ];
    payloads.add(
      AvoWidgetPayload.card(
        AvoPlanCard(
          from: from,
          days: days,
          lines: [
            for (final e in entries)
              (
                entryId: e.id,
                day: e.planDate,
                recipeId: e.recipeId,
                name: e.snapshot.name,
                servings: e.servings,
                imageUrl: e.snapshot.imageUrl,
                kcal: e.snapshot.kcalPerServing,
              ),
          ],
        ),
      ),
    );
    return {
      'from': AvoAssistantService._ymd(from),
      'days': days,
      'entries': [
        for (final e in entries)
          {
            'entry_id': e.id,
            'date': AvoAssistantService._ymd(e.planDate),
            'recipe': e.snapshot.name,
            'servings': e.servings,
            if (e.snapshot.kcalPerServing != null)
              'kcal_per_serving': e.snapshot.kcalPerServing,
            'on_list': e.isSent,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _toolAddToPlan(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!_planOn(ref)) return _planOff(ref);
    final day = AvoAssistantService._day(args['date']);
    if (day == null) return {'error': 'date must be YYYY-MM-DD'};
    final recipe = await _resolveRecipe(
      args['recipe_id'] as String?,
      args['recipe_name'] as String?,
      byId: ref.read(mealPlanRecipeLookupProvider),
    );
    if (recipe == null) return {'error': 'Recipe not found'};
    final servings =
        (args['servings'] as num?)?.toInt() ??
        ref.read(mealPlanSettingsProvider).defaultServings;

    // A day with a recipe asks first: "Dazulegen" or "Ersetzen" (Kap. 5.4).
    final gate = avoPlanDayGate(
      day: day,
      recipeId: recipe.id,
      recipeName: recipe.name,
      servings: servings,
      planned: ref.read(planEntriesForDayProvider(day)),
    );
    if (gate != null) {
      payloads.add(gate.card);
      return gate.result;
    }
    final record = await planRecipeForAvo(
      ref,
      recipeId: recipe.id,
      recipe: recipe,
      day: day,
      servings: servings,
    );
    if (record == null) return {'error': 'Recipe not found'};
    payloads.add(AvoWidgetPayload.record(record));
    return {
      'success': true,
      'date': AvoAssistantService._ymd(day),
      'recipe': recipe.name,
      'servings': servings,
    };
  }

  /// Plans a recipe on [day] (after removing [replacing] when the person
  /// chose "Ersetzen") and answers with the card; "Widerrufen" takes both
  /// back.
  Future<AvoPlanRecord?> planRecipeForAvo(
    WidgetRef ref, {
    required String recipeId,
    Recipe? recipe,
    required DateTime day,
    required int servings,
    List<String> replacing = const [],
  }) async {
    final controller = ref.read(mealPlanControllerProvider);
    // What "Ersetzen" takes out, as it is now: if taking it out fails (also
    // half-way, after the plan changed on the device), these go back.
    final replaced = {
      for (final e in ref.read(planEntriesForDayProvider(day)))
        if (replacing.contains(e.id)) e.id: e,
    };
    // The new recipe first: if it cannot be planned, nothing is taken out.
    final added = await controller.addRecipeToPlan(
      recipeId,
      day,
      servings,
      recipe: recipe,
    );
    if (added == null) return null;
    MealPlanUndo? removed;
    if (replacing.isNotEmpty) {
      try {
        removed = await controller.removeEntries(replacing);
      } catch (e) {
        // "Ersetzen" did not go through: the day goes back to how it was,
        // the replaced recipes in and the new one out, in one step.
        await controller.undo(
          MealPlanUndo(entries: {...added.undo.entries, ...replaced}),
        );
        rethrow;
      }
    }
    return AvoPlanRecord(
      tool: 'add_to_plan',
      recipeName: added.entry.snapshot.name,
      day: day,
      servings: servings,
      undo: () async {
        try {
          // Only while the planned entry is as Avo left it and the replaced
          // ones are still gone.
          final now = ref.read(mealPlanSnapshotProvider).entries;
          final current = now[added.entry.id];
          if (current == null ||
              !AvoAssistantService._sameDay(current.planDate, day) ||
              current.servings != added.entry.servings ||
              replacing.any(now.containsKey)) {
            return AvoUndoResult.changedSince;
          }
          await controller.undo(added.undo);
          if (removed != null) await controller.undo(removed);
          return AvoUndoResult.undone;
        } catch (e) {
          debugPrint('❌ [AVO] Plan not taken back: $e');
          return AvoUndoResult.failed;
        }
      },
    );
  }

  Future<Map<String, Object?>> _toolMoveInPlan(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!_planOn(ref)) return _planOff(ref);
    final id = args['entry_id'] as String?;
    final day = AvoAssistantService._day(args['date']);
    if (id == null || day == null) {
      return {'error': 'entry_id and date are required'};
    }
    final entry = ref.read(mealPlanSnapshotProvider).entries[id];
    if (entry == null) return {'error': 'No plan entry with this id.'};
    final controller = ref.read(mealPlanControllerProvider);
    final undo = await controller.moveEntry(id, day);
    payloads.add(
      AvoWidgetPayload.record(
        AvoPlanRecord(
          tool: 'move_in_plan',
          recipeName: entry.snapshot.name,
          day: day,
          moved: true,
          undo: () async {
            try {
              final current = ref.read(mealPlanSnapshotProvider).entries[id];
              if (current == null ||
                  !AvoAssistantService._sameDay(current.planDate, day) ||
                  current.servings != entry.servings) {
                return AvoUndoResult.changedSince;
              }
              await controller.undo(undo);
              return AvoUndoResult.undone;
            } catch (e) {
              debugPrint('❌ [AVO] Plan move not taken back: $e');
              return AvoUndoResult.failed;
            }
          },
        ),
      ),
    );
    return {
      'success': true,
      'entry_id': id,
      'date': AvoAssistantService._ymd(day),
    };
  }

  Future<Map<String, Object?>> _toolPlanToList(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!_planOn(ref)) return _planOff(ref);
    final from = AvoAssistantService._day(args['from']);
    final listId = args['list_id'] as String?;
    if (from == null || listId == null) {
      return {'error': 'from and list_id are required'};
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final controller = ref.read(mealPlanControllerProvider);
    final result = await controller.sendToList(
      weekStart: planWeekStart(from),
      range: from.isAfter(today) || from == today
          ? PlanRange.fromToday
          : PlanRange.wholeWeek,
      listId: listId,
      noteFor: (names) => names.isEmpty ? null : names.join(', '),
    );
    if (result.addedCount > 0) {
      payloads.add(
        AvoWidgetPayload.record(
          AvoItemsRecord(
            tool: 'plan_to_list',
            source: AvoItemsSource.plan,
            listId: listId,
            listName: await AvoAssistantService._changes(ref).listName(listId),
            added: result.addedCount,
            undo: () async {
              try {
                await controller.undoSend(result);
                return AvoUndoResult.undone;
              } catch (e) {
                debugPrint('❌ [AVO] Plan send not taken back: $e');
                return AvoUndoResult.failed;
              }
            },
          ),
        ),
      );
    }
    return {
      'success': result.failedNames.isEmpty,
      'added': result.addedCount,
      if (result.failedNames.isNotEmpty) 'failed': result.failedNames,
    };
  }

  /// Nutrition per serving from the server task `nutrition_estimate`.
  Future<Map<String, Object?>> _estimateNutrition(Recipe recipe) async {
    final ingredients = recipe.ingredients
        .map((i) => '- ${i.amount} ${i.unit} ${i.name}'.trim())
        .join('\n');
    final estimate = await _askNutrition(
      '${recipe.name}\n$ingredients',
      servings: recipe.defaultServings,
    );
    return estimate ?? {'error': 'No estimate available'};
  }

  /// Nutrition of a free-text food ("1 Banane", "200 g Hähnchenbrust").
  Future<Map<String, Object?>?> _estimateFoodNutrition(String description) =>
      _askNutrition(description);

  Future<Map<String, Object?>?> _askNutrition(
    String text, {
    int? servings,
  }) async {
    try {
      final result = await ClaudeService.instance.run('nutrition_estimate', {
        'text': text,
        if (servings != null && servings > 0) 'servings': servings,
      }, timeout: const Duration(seconds: 15));
      final kcal = (result['kcal'] as num?)?.round();
      if (kcal == null) return null;
      return {
        'calories': kcal,
        'protein_g': (result['protein_g'] as num?)?.toDouble(),
        'carbs_g': (result['carbs_g'] as num?)?.toDouble(),
        'fat_g': (result['fat_g'] as num?)?.toDouble(),
        'estimated': true,
      };
    } on ClaudeException catch (e) {
      debugPrint('❌ [AVO] Nutrition estimate failed: ${e.code}');
      return null;
    }
  }
}
