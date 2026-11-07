import 'package:flutter/widgets.dart';

/// "4 von 11 Artikeln diese Woche bei Lidl im Angebot" for a list
/// (contract 3.3).
///
/// Stub until P2: there is no summary data yet, so it renders nothing. With
/// content it stays empty while `offersVisibleForListProvider` is false,
/// without a real zip code or when nothing is on offer.
class ListOfferSummary extends StatelessWidget {
  const ListOfferSummary({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
