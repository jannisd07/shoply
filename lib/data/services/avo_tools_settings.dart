part of 'avo_assistant_service.dart';

// Settings, modules, the app and deletions (Kap. 5.7, 6).
extension AvoSettingTools on AvoAssistantService {
  Future<Map<String, Object?>> _toolUpdateSetting(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
    ({bool health, bool body}) consents,
  ) async {
    final key = args['key'] as String?;
    final value = args['value'];
    if (key == null) return {'error': 'key is required'};

    // Removing an allergy or a diet only ever happens from the person's tap
    // on its card (Kap. 6.5); the model's call shows the card, and without
    // the consent it learns nothing about what is stored.
    if (key == 'allergies_remove' || key == 'diet_remove') {
      final user = await ref.read(currentUserProvider.future);
      final gate = avoRemovalGate(
        key,
        value,
        key == 'diet_remove'
            ? user?.dietPreferences ?? const []
            : user?.allergies ?? const [],
        healthShared: consents.health,
      );
      payloads.add(gate.card);
      return gate.result;
    }

    final a8 = AvoSettingsBridge.isA8Key(key);
    final previous = a8 ? null : await _settingValue(ref, key);
    final bridge = AvoSettingsBridge(ref);
    final result = await bridge.update(key, value);
    if (!result.success) {
      payloads.add(AvoWidgetPayload.card(AvoSettingFailedCard(key)));
      return await _withPostcodeState(result.key, result.toJson());
    }
    final labelKey = result.labelKey;
    if (labelKey != null) {
      // A8 keys (Listen, Mitteilungen, Module …): the bridge knows the
      // values before and after; "Widerrufen" sets the old one again.
      final before = result.oldValue;
      final after = result.newValue;
      payloads.add(
        AvoWidgetPayload.record(
          AvoSettingRecord(
            tool: 'update_setting',
            key: key,
            value: after,
            previous: before,
            undo: before != null && before != after
                ? () => _undoBridgeSetting(ref, key, before, after)
                : null,
          ),
        ),
      );
      return await _withPostcodeState(result.key, result.toJson());
    }
    final now = await _settingValue(ref, key);
    final entry = value?.toString().trim() ?? '';
    final changed = now != previous;
    final listKey = key.endsWith('_add') || key.endsWith('_remove');
    payloads.add(
      AvoWidgetPayload.record(
        AvoSettingRecord(
          tool: 'update_setting',
          key: key,
          // Allergies and diet show the one entry that changed.
          value: listKey ? entry : (now ?? ''),
          previous: previous,
          undo: changed
              ? () => _undoSetting(ref, key, previous, entry, now)
              : null,
        ),
      ),
    );
    return await _withPostcodeState(result.key, result.toJson());
  }

  /// A postcode change answers with whether a postcode is stored now, read
  /// after the change (also after a refused one); the consent filter drops
  /// the postcode itself (contract).
  Future<Map<String, Object?>> _withPostcodeState(
    String key,
    Map<String, Object?> result,
  ) async {
    if (key != 'zip_code') return result;
    final zip = await UserLocationService.instance.getManualZipCode();
    return {...result, 'postcode_set': zip != null && zip.isNotEmpty};
  }

  /// A setting's current raw value (`dark`, `de`, `true`, a zip code; for
  /// allergies and diet the stored entries, joined), or null when unset.
  Future<String?> _settingValue(WidgetRef ref, String key) async {
    switch (key) {
      case 'theme_mode':
        return ref.read(themeModeProvider).name;
      case 'language':
        return ref.read(languageProvider.notifier).savedSetting;
      case 'zip_code':
        final zip = await UserLocationService.instance.getManualZipCode();
        return zip == null || zip.isEmpty ? null : zip;
    }
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return null;
    String? text(String? v) => v == null || v.trim().isEmpty ? null : v;
    return switch (key) {
      'notifications' => '${user.notificationEnabled}',
      'display_name' => text(user.displayName),
      'age' => user.age?.toString(),
      'gender' => text(user.gender),
      'height_cm' => user.height == null ? null : '${user.height!.round()}',
      'allergies_add' || 'allergies_remove' => text(user.allergies.join(', ')),
      'diet_add' || 'diet_remove' => text(user.dietPreferences.join(', ')),
      _ => null,
    };
  }

  /// "Widerrufen" on a card of an A8 setting: sets [before] again, but only
  /// while the setting still has the value Avo gave it ([after]).
  Future<AvoUndoResult> _undoBridgeSetting(
    WidgetRef ref,
    String key,
    String before,
    String after,
  ) async {
    try {
      final bridge = AvoSettingsBridge(ref);
      if (bridge.currentValue(key) != after) {
        return AvoUndoResult.changedSince;
      }
      final result = await bridge.update(key, before);
      return result.success ? AvoUndoResult.undone : AvoUndoResult.failed;
    } catch (e) {
      debugPrint('❌ [AVO] Setting not set back: ${e.runtimeType}');
      return AvoUndoResult.failed;
    }
  }

  /// "Widerrufen" on a setting card: sets the old value again, but only
  /// while the setting still has the value Avo gave it.
  Future<AvoUndoResult> _undoSetting(
    WidgetRef ref,
    String key,
    String? previous,
    String entry,
    String? after,
  ) async {
    try {
      if (await _settingValue(ref, key) != after) {
        return AvoUndoResult.changedSince;
      }
      final bridge = AvoSettingsBridge(ref);
      final SettingChangeResult result;
      if (key == 'allergies_add') {
        result = await bridge.update('allergies_remove', entry);
      } else if (key == 'diet_add') {
        result = await bridge.update('diet_remove', entry);
      } else if (key == 'diet_remove') {
        result = await bridge.update('diet_add', entry);
      } else {
        result = await bridge.update(
          key,
          previous ?? (key == 'zip_code' ? '' : null),
        );
      }
      return result.success ? AvoUndoResult.undone : AvoUndoResult.failed;
    } catch (e) {
      debugPrint('❌ [AVO] Setting not set back: $e');
      return AvoUndoResult.failed;
    }
  }

  /// The tap on "Entfernen" of the allergy safety card: removes the one
  /// entry the card shows, with "Widerrufen" (adds it again).
  /// "Entfernen" on a removal card: removes the one entry the card shows
  /// (an allergy or a diet), with "Widerrufen" (adds it again).
  Future<AvoSettingRecord> removeEntryForAvo(
    WidgetRef ref,
    AvoRemovalCard card,
  ) async {
    final remove = card.diet ? 'diet_remove' : 'allergies_remove';
    final add = card.diet ? 'diet_add' : 'allergies_add';
    final update = ref.read(avoSettingUpdateProvider);
    final previous = await _settingValue(ref, remove);
    final result = await update(ref, remove, card.entry);
    if (!result.success) throw StateError(result.error ?? 'not removed');
    final after = await _settingValue(ref, remove);
    return AvoSettingRecord(
      tool: 'update_setting',
      key: remove,
      value: card.entry,
      previous: previous,
      undo: () async {
        try {
          if (await _settingValue(ref, remove) != after) {
            return AvoUndoResult.changedSince;
          }
          final back = await update(ref, add, card.entry);
          return back.success ? AvoUndoResult.undone : AvoUndoResult.failed;
        } catch (e) {
          debugPrint('❌ [AVO] Entry not added back: ${e.runtimeType}');
          return AvoUndoResult.failed;
        }
      },
    );
  }

  Future<Map<String, Object?>> _toolSetModule(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final module = AvoAssistantService._moduleFromId(args['module'] as String?);
    final enabled = args['enabled'] as bool?;
    if (module == null || enabled == null) {
      return {'error': 'module and enabled are required'};
    }
    if (!module.released) {
      return {
        'not_available': true,
        'error': AvoAssistantService._t(ref, 'avo_tool_not_available'),
      };
    }
    final modules = ref.read(appModulesProvider.notifier);
    final was = ref.read(moduleEnabledProvider(module));
    Future<AvoUndoResult> back() async {
      try {
        if (ref.read(moduleEnabledProvider(module)) != enabled) {
          return AvoUndoResult.changedSince;
        }
        await modules.setEnabled(module, was);
        return AvoUndoResult.undone;
      } catch (e) {
        debugPrint('❌ [AVO] Module not switched back: $e');
        return AvoUndoResult.failed;
      }
    }

    // Switching Avo off ends the tab: it happens once this answer is done,
    // never under it (Kap. 5.7).
    final avoOff = module == AppModule.avo && !enabled;
    if (!avoOff) await modules.setEnabled(module, enabled);
    payloads.add(
      AvoWidgetPayload.record(
        AvoModuleRecord(
          tool: 'set_module',
          module: module,
          enabled: enabled,
          undo: was == enabled || avoOff ? null : back,
          applyAfterAnswer: avoOff
              ? () => modules.setEnabled(module, false)
              : null,
        ),
      ),
    );
    return {'success': true, 'module': module.storageKey, 'enabled': enabled};
  }

  /// What the app knows at runtime; the static app knowledge is in the
  /// server's system prompt.
  Map<String, Object?> _toolAppInfo(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) {
    final subscription = SubscriptionService.instance;
    switch (args['topic']) {
      case 'my_subscription':
        payloads.add(
          AvoWidgetPayload.card(
            AvoAppInfoCard(isPro: subscription.isSubscribed),
          ),
        );
        return {
          'is_pro': subscription.isSubscribed,
          'plan_name': AppBrand.proName,
        };
      case 'pro_plan':
        payloads.add(
          AvoWidgetPayload.card(
            AvoAppInfoCard(isPro: subscription.isSubscribed),
          ),
        );
        return {
          'plan_name': AppBrand.proName,
          'offers_are_never_pro': true,
          'prices_from_app_store': [
            for (final p in subscription.products)
              {'title': p.title, 'price': p.price},
          ],
        };
      default:
        return {'error': 'topic must be pro_plan or my_subscription'};
    }
  }

  /// Avo cannot delete: it asks for a card, and only the person's tap on it
  /// deletes ([confirmPendingDelete]). The card shows the app's own stored
  /// name, never the model's [label].
  Future<Map<String, Object?>> _toolProposeDelete(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final target = avoDeleteTargetFromJson(args['target_type'] as String?);
    final id = (args['target_id'] as String?)?.trim() ?? '';
    final label = (args['label'] as String?)?.trim() ?? '';
    if (target == null || id.isEmpty) {
      return {'error': 'target_type and target_id are required'};
    }
    final found = await _lookUpDeleteTarget(target, id, ref);
    if (found == null) {
      return {
        'error':
            'Nothing with this id exists for the person, or it cannot be deleted from Avo yet.',
      };
    }
    // A trip has no name of its own (the model calls it by its date).
    if (target != AvoDeleteTarget.historyTrip &&
        label.isNotEmpty &&
        !AvoAssistantService._sameName(found.name, label)) {
      return {
        'error':
            'This id belongs to "${found.name}", not "$label". Check the id first.',
      };
    }
    final pending = _pendingDeletes.propose(
      target: target,
      targetId: id,
      name: found.name,
      parentId: found.parentId,
      version: found.version,
      date: found.date,
    );
    payloads.add(AvoWidgetPayload.confirmDelete(pending));
    return {
      'shown': true,
      'note':
          'The app shows a confirmation card. Nothing is deleted until the person taps it.',
    };
  }

  /// The target as the person's own rights see it (RLS); null when it does
  /// not exist for them or Avo cannot delete that kind yet.
  Future<({String name, String? parentId, String? version, DateTime? date})?>
  _lookUpDeleteTarget(AvoDeleteTarget target, String id, WidgetRef ref) async {
    switch (target) {
      case AvoDeleteTarget.item:
        final row = await _supabase
            .from('shopping_items')
            .select('name, list_id, updated_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (
          name: row['name'] as String? ?? '',
          parentId: row['list_id'] as String?,
          version: row['updated_at']?.toString(),
          date: null,
        );
      case AvoDeleteTarget.list:
        final row = await _supabase
            .from('shopping_lists')
            .select('name, updated_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (
          name: row['name'] as String? ?? '',
          parentId: null,
          version: row['updated_at']?.toString(),
          date: null,
        );
      case AvoDeleteTarget.foodLog:
        final row = await _supabase
            .from('food_log_entries')
            .select('food_name')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (
          name: row['food_name'] as String? ?? '',
          parentId: null,
          version: null,
          date: null,
        );
      case AvoDeleteTarget.planEntry:
        if (!_planOn(ref)) return null;
        final entry = ref.read(mealPlanSnapshotProvider).entries[id];
        if (entry == null) return null;
        return (
          name: entry.snapshot.name,
          parentId: null,
          version: entry.updatedAt.toIso8601String(),
          date: entry.planDate,
        );
      case AvoDeleteTarget.historyTrip:
        final row = await _supabase
            .from('shopping_history')
            .select('list_name, completed_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (
          name: row['list_name'] as String? ?? '',
          parentId: null,
          version: null,
          date: DateTime.tryParse(
            row['completed_at']?.toString() ?? '',
          )?.toLocal(),
        );
      case AvoDeleteTarget.listMember:
        return null;
    }
  }

  /// Runs a deletion Avo proposed, from the tap on its card: only with the
  /// one-time [token], within 10 minutes and while the target is unchanged.
  /// A typed or spoken "ja" never gets here.
  Future<bool> confirmPendingDelete(String token, WidgetRef ref) async {
    final pending = _pendingDeletes.take(token);
    if (pending == null) return false;
    try {
      final current = await _lookUpDeleteTarget(
        pending.target,
        pending.targetId,
        ref,
      );
      if (current == null || current.version != pending.version) return false;
      switch (pending.target) {
        case AvoDeleteTarget.item:
          final listId = pending.parentId;
          if (listId == null) return false;
          await ref
              .read(itemsNotifierProvider(listId).notifier)
              .deleteItem(pending.targetId);
        case AvoDeleteTarget.list:
          await ref
              .read(listsNotifierProvider.notifier)
              .deleteList(pending.targetId);
        case AvoDeleteTarget.foodLog:
          await FoodLogService.instance.deleteEntryWithPhoto(pending.targetId);
          invalidateNutritionLog(ref);
        case AvoDeleteTarget.planEntry:
          await ref.read(mealPlanControllerProvider).removeEntries([
            pending.targetId,
          ]);
        case AvoDeleteTarget.historyTrip:
          await ShoppingHistoryService().deleteHistory(pending.targetId);
        case AvoDeleteTarget.listMember:
          return false;
      }
    } catch (_) {
      // Nothing was deleted (network): the card may try again.
      _pendingDeletes.restore(pending);
      rethrow;
    }
    return true;
  }
}
