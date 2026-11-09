import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_icons.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_row.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_info_screen.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/app_destinations.dart';

// Kap. 5.5: offers, only with offers available, only the list's market,
// "laut Händler", "in deiner Region", "ca.". No market comparison, no basket
// total, no percentages, no retailer pictures.
const double _plusGlyph = 20; // D2

/// Whether offer cards may show at all: with the kill switch or the module
/// off they are not built (and ask nothing).
bool _offersShown(WidgetRef ref) => ref.watch(offersAvailableProvider);

/// The lines and the spoken sentence of one offer, as the offer detail
/// writes them.
({List<String> lines, String spoken}) _offerText(
  BuildContext context,
  StoreOffer offer,
) {
  final lang = avoLang(context);
  final pack = formatPack(offer, lang);
  final regular = offer.regularPrice;
  final ends = offerEndsLabel(offer, lang) ?? offerValidUntil(offer, lang);
  final lines = [
    [?pack, ?formatUnitPrice(offer, lang)].join(' · '),
    if (regular != null)
      context.tr('offer_was_price', params: {'price': formatEuro(regular, lang)}),
    if (offer.isBroadMatch) context.tr('offer_similar_product') else ?ends,
  ].where((l) => l.isNotEmpty).toList();
  final spoken = [
    offerProductTitle(offer),
    ?pack,
    if (regular != null)
      context.tr(
        'offer_was_price',
        params: {'price': spokenEuro(regular, lang)},
      ),
    context.tr(
      'offer_badge_a11y',
      params: {'price': spokenEuro(offer.price, lang)},
    ),
  ].join(', ');
  return (lines: lines, spoken: spoken);
}

/// `search_offers`: "Lidl, diese Woche", the offers with their pill and a
/// plus that puts the product on the list; a tap opens the offer.
class AvoOfferSearchSection extends ConsumerWidget {
  const AvoOfferSearchSection({super.key, required this.card});

  final AvoOfferSearchCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_offersShown(ref)) return const SizedBox.shrink();
    final symbol = Categories.getById(
      ref.watch(offerCategoryOfProvider)(card.query),
    ).icon;
    final listId = card.listId;
    return AvoResultSection(
      title: context.tr(
        'avo_offer_this_week',
        params: {'store': card.storeName},
      ),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.tag)),
      detailIndent: context.isAccessibilityText
          ? AvoSpacing.l
          : offerRowTextIndent,
      details: [
        for (final offer in card.offers)
          _OfferLine(
            offer: offer,
            symbol: symbol,
            name: card.query,
            listId: listId,
          ),
      ],
      footnote: context.tr(
        'avo_offer_footnote',
        params: {
          'zip': card.zip,
          'source': context.tr('offer_source_placeholder'),
        },
      ),
    );
  }
}

class _OfferLine extends StatelessWidget {
  const _OfferLine({
    required this.offer,
    required this.symbol,
    required this.name,
    required this.listId,
  });

  final StoreOffer offer;
  final IconData symbol;
  final String name;
  final String? listId;

  @override
  Widget build(BuildContext context) {
    final text = _offerText(context, offer);
    final listId = this.listId;
    void open() => context.push(
      offerDetailLocation(
        offer.id,
        listId: listId,
        mode: listId == null ? null : OfferDetailMode.add,
        name: name,
      ),
    );
    final row = OfferRow(
      title: offerProductTitle(offer),
      lines: text.lines,
      price: formatEuro(offer.price, avoLang(context)),
      uncertain: offer.isBroadMatch,
      symbol: symbol,
      semanticLabel: text.spoken,
      onTap: open,
    );
    if (listId == null) return row;
    final add = context.tr('avo_offer_add', params: {'item': name});
    return Row(
      children: [
        Expanded(child: row),
        Semantics(
          button: true,
          label: add,
          excludeSemantics: true,
          onTap: () => addOfferToList(
            context,
            listId: listId,
            name: name,
            offer: offer,
          ),
          child: PressableScale(
            onPressed: () => addOfferToList(
              context,
              listId: listId,
              name: name,
              offer: offer,
            ),
            child: SizedBox.square(
              dimension: AvoSizes.hitTarget,
              child: Center(
                child: AvoIcon(
                  AvoIcons.plus,
                  size: _plusGlyph,
                  color: context.colors.tint,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AvoSpacing.s),
      ],
    );
  }
}

/// No real region ("Für Angebote in deiner Region: Postleitzahl
/// festlegen") or the list has no market ("Wocheneinkauf hat noch keinen
/// Markt. · Markt wählen").
class AvoOfferSetupSection extends ConsumerWidget {
  const AvoOfferSetupSection({super.key, required this.card});

  final AvoOfferSetupCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_offersShown(ref)) return const SizedBox.shrink();
    if (card.needsRegion) {
      void open() => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => const PersonalInfoScreen()),
      );
      return AvoResultSection(
        title: context.tr('avo_offer_set_zip'),
        leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.location)),
        onOpen: open,
      );
    }
    final listId = card.listId!;
    void choose() => context.push(storePickerLocation(listId: listId));
    return AvoResultSection(
      title: context.tr(
        'avo_offer_no_store',
        params: {'list': card.listName ?? ''},
      ),
      leading: const AvoSymbolTile(icon: AvoIcon(OfferIcons.storefront)),
      onOpen: choose,
      actions: [
        AvoCardAction(label: context.tr('offer_store_choose'), onPressed: choose),
      ],
    );
  }
}

/// `get_personalized_deals`: the summary sentence of the list in the
/// mandatory wording; a tap on the head unfolds the offers.
class AvoDealsSection extends ConsumerWidget {
  const AvoDealsSection({super.key, required this.card});

  final AvoDealsCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_offersShown(ref)) return const SizedBox.shrink();
    final text = offerSummaryText(card.summary, avoLang(context));
    void open() =>
        openAppDestination(context, AppDestinations.list(card.listId));
    final lang = avoLang(context);
    return AvoResultSection(
      title: text.head,
      subtitle: text.detail,
      semanticLabel: text.sentence,
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.tag)),
      maxCollapsed: 0,
      detailIndent: AvoSpacing.l,
      details: [
        for (final d in card.offers)
          OfferRow(
            title: d.item,
            lines: [offerProductTitle(d.offer), ..._offerText(context, d.offer).lines],
            price: formatEuro(d.offer.price, lang),
            uncertain: d.offer.isBroadMatch,
            semanticLabel: '${d.item}, ${_offerText(context, d.offer).spoken}',
            onTap: () => context.push(
              offerDetailLocation(d.offer.id, listId: card.listId, name: d.item),
            ),
          ),
      ],
      onOpen: open,
      actions: [AvoCardAction(label: context.tr('avo_view'), onPressed: open)],
    );
  }
}

/// `get_savings_summary`: "November: ca. 12,40 € durch Angebote gespart /
/// laut Händler · 6 Einkäufe"; nothing recorded: "Für November ist keine
/// Ersparnis erfasst.". No figure joy for money (Kap. 5.2).
class AvoSavingsSection extends ConsumerWidget {
  const AvoSavingsSection({super.key, required this.card});

  final AvoSavingsCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_offersShown(ref)) return const SizedBox.shrink();
    final month = avoMonth(context, card.month);
    final cents = card.savedCents;
    void open() => openAppDestination(context, AppDestinations.history);
    final amount = cents == null ? null : formatEuroCents(cents, avoLang(context));
    return AvoResultSection(
      title: amount == null
          ? context.tr('avo_savings_none', params: {'month': month})
          : context.tr(
              'avo_savings_title',
              params: {'month': month, 'amount': amount},
            ),
      subtitle: amount == null
          ? null
          : avoTrCount(context, 'avo_savings_sub', card.trips),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.tag)),
      onOpen: open,
      actions: [AvoCardAction(label: context.tr('avo_view'), onPressed: open)],
    );
  }
}
