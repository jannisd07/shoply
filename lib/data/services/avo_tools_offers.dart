part of 'avo_assistant_service.dart';

// Offers (Kap. 5.5): only with offers available, the list's market and a real region.
extension _AvoOfferTools on AvoAssistantService {
  /// Why an offer tool may not run now: the kill switch (no card, Avo
  /// says nothing about offers) or the module (the card offers to switch it
  /// on). Null when offers are available.
  Map<String, Object?>? _offersBlocked(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) {
    if (!ref.read(offersRemoteEnabledProvider)) {
      return {
        'not_available': true,
        'error': 'Offers are not available right now.',
      };
    }
    if (!ref.read(offersAvailableProvider)) {
      payloads.add(AvoWidgetPayload.moduleOff(AppModule.offers));
      return {
        'not_available': true,
        'error': 'The module Preise & Angebote is off.',
      };
    }
    return null;
  }

  /// The list an offer question is about: the call's, else the screen's,
  /// else the newest.
  ShoppingListModel? _offerList(
    WidgetRef ref,
    Map<String, Object?> args,
    AvoContext? context,
  ) {
    final id = args['list_id'] as String?;
    final lists = context?.lists ?? const <ShoppingListModel>[];
    if (id != null && id.isNotEmpty) {
      return lists.where((l) => l.id == id).firstOrNull;
    }
    return _targetList(ref, context);
  }

  /// Offers for one product at the market of the list in context (Kap. 12:
  /// only that market, never a comparison across markets, prices "laut
  /// Händler", "in deiner Region"). Without a region or a confirmed market
  /// the card asks for it instead of searching.
  Future<Map<String, Object?>> _toolSearchOffers(
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    final blocked = _offersBlocked(ref, payloads);
    if (blocked != null) return blocked;
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return {'error': 'query is required'};

    final region = ref.read(regionProvider);
    if (region == null) {
      payloads.add(AvoWidgetPayload.card(const AvoOfferSetupCard.region()));
      return {
        'found': 0,
        'note':
            'No region set. The app shows a card to set the postcode; '
            'or ask for it and set it via update_setting key "zip_code".',
      };
    }
    final list = _offerList(ref, args, context);
    if (list == null) return {'found': 0, 'note': 'The person has no list.'};
    if (!ref.read(offersVisibleForListProvider(list.id))) {
      return {
        'found': 0,
        'note':
            'Offers are not shown on this list (hidden by the person, or '
            'not loaded yet). Do not mention offers for it.',
      };
    }
    final store = ref.read(storeForListProvider(list.id));
    if (store == null) {
      payloads.add(
        AvoWidgetPayload.card(
          AvoOfferSetupCard.store(listId: list.id, listName: list.name),
        ),
      );
      return {
        'found': 0,
        'note':
            'The list has no confirmed market; the app shows a card to '
            'choose one. Never compare markets.',
      };
    }

    final offers = [
      for (final o in await OfferPriceService.instance.searchOffers(
        query,
        zipCode: region.zip,
        chainId: store.id,
      ))
        if (o.isValidNow) o,
    ];
    if (offers.isEmpty) {
      return {
        'found': 0,
        'store': store.name,
        'note':
            'No current offer for "$query" at ${store.name} in the '
            "person's region.",
      };
    }

    final top = offers.take(5).toList();
    payloads.add(
      AvoWidgetPayload.card(
        AvoOfferSearchCard(
          storeName: store.name,
          offers: top,
          query: query,
          zip: region.zip,
          listId: list.id,
        ),
      ),
    );
    return {
      'found': top.length,
      'store': store.name,
      'wording':
          'Say "bei ${store.name} im Angebot, in deiner Region" and '
          '"laut Händler" for any regular price. Never compare markets.',
      'offers': [
        for (final o in top)
          {
            'product': o.productName,
            'price': o.price,
            if (o.regularPrice != null)
              'regular_price_per_retailer': o.regularPrice,
            'unit': o.unitShortName,
          },
      ],
    };
  }

  /// This week's offers at the list's market for the list's open items,
  /// with the app's own summary sentence first (Kap. 12 rule 3: "4 von 11
  /// Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in
  /// deiner Region"), so a chat answer and the list never disagree.
  Future<Map<String, Object?>> _toolGetPersonalizedDeals(
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    final blocked = _offersBlocked(ref, payloads);
    if (blocked != null) return blocked;
    final region = ref.read(regionProvider);
    if (region == null) {
      payloads.add(AvoWidgetPayload.card(const AvoOfferSetupCard.region()));
      return {
        'found': 0,
        'note': 'No region set; the app shows a card to set it.',
      };
    }
    final list = _offerList(ref, args, context);
    if (list == null) return {'found': 0, 'note': 'The person has no list.'};
    if (!ref.read(offersVisibleForListProvider(list.id))) {
      return {
        'found': 0,
        'note':
            'Offers are not shown on this list (hidden by the person, or '
            'not loaded yet). Do not mention offers for it.',
      };
    }
    final store = ref.read(storeForListProvider(list.id));
    if (store == null) {
      payloads.add(
        AvoWidgetPayload.card(
          AvoOfferSetupCard.store(listId: list.id, listName: list.name),
        ),
      );
      return {'found': 0, 'note': 'The list has no confirmed market yet.'};
    }

    final items = await ItemRepository.instance.getListItems(list.id);
    final open = [
      for (final i in items)
        if (!i.isChecked) i,
    ];
    if (open.isEmpty) {
      return {'found': 0, 'note': 'The list has no open items.'};
    }
    final snapshot = await ref
        .read(listOfferSyncProvider)
        .sync(
          listId: list.id,
          chainId: store.id,
          zip: region.zip,
          itemNames: [for (final i in open) i.name],
        );
    final prefs = ref.read(offerDisplayPrefsProvider);
    final now = ref.read(offerClockProvider)();
    final byItem = <String, StoreOffer>{
      for (final item in open)
        if (snapshot.offerFor(item.name) case final offer?)
          if (offer.isValidNow &&
              !(prefs?.isDeclined(item.id, offer.id, now) ?? false))
            item.id: offer,
    };
    final summary = summarizeListOffers(
      chainId: store.id,
      openItems: open,
      offersByItemId: byItem,
      realRegion: true,
    );
    if (summary == null) {
      return {
        'found': 0,
        'note':
            'Nothing on ${list.name} is on offer at ${store.name} this '
            'week in the person\'s region.',
      };
    }
    final limit = ((args['limit'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final deals = [
      for (final item in open)
        if (byItem[item.id] case final offer?) (item: item.name, offer: offer),
    ];
    payloads.add(
      AvoWidgetPayload.card(
        AvoDealsCard(
          listId: list.id,
          listName: list.name,
          summary: summary,
          offers: deals,
        ),
      ),
    );
    return {
      'summary': formatOfferSummary(summary, ref.read(languageProvider)),
      'found': deals.length,
      'deals': [
        for (final d in deals.take(limit))
          {
            'item': d.item,
            'product': d.offer.productName,
            'price': d.offer.price,
            if (d.offer.regularPrice != null)
              'regular_price_per_retailer': d.offer.regularPrice,
            if (d.offer.isBroadMatch) 'similar_product': true,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _toolSavingsSummary(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final blocked = _offersBlocked(ref, payloads);
    if (blocked != null) return blocked;
    final history = await ShoppingHistoryService().getShoppingHistory();
    final now = DateTime.now();
    // Savings figures only with a real region (Kap. 12 rule 4).
    final realRegion = ref.read(regionProvider) != null;
    final result = AvoAssistantService.summarizeSavings(
      history,
      now,
      realRegion: realRegion,
    );
    // Without a real region there is no figure, and no claim that nothing
    // was saved either: the card asks for the postcode.
    payloads.add(
      AvoWidgetPayload.card(
        realRegion
            ? AvoSavingsCard(
                month: DateTime(now.year, now.month),
                trips: result['month_trips'] as int,
                savedCents: result['month_saved_cents'] as int?,
              )
            : const AvoOfferSetupCard.region(),
      ),
    );
    return result;
  }
}
