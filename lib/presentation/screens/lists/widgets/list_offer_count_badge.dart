import 'package:flutter/widgets.dart';

/// "2 Angebote" on the cover of a list card (contract `b_slots.dart`).
///
/// Shell until S4: renders nothing. With content it counts the open items
/// that are on offer at the list's market and stays empty while offers are
/// unavailable, hidden on [listId] or there are none.
class ListOfferCountBadge extends StatelessWidget {
  const ListOfferCountBadge({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
