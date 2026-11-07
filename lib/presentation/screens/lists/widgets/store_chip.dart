import 'package:flutter/widgets.dart';

/// The market of a list in the list header, shopping mode and list info
/// (contract `b_slots.dart`, Kap. 12, E-13). Core, not part of the offers
/// module: the market also sorts the list in store.
///
/// Shell until S4: renders nothing. Then "● Lidl ⌄" with the market menu,
/// "Lidl?" for a suggestion and "Markt wählen" without one, VoiceOver
/// "Markt: Lidl, ändern".
class StoreChip extends StatelessWidget {
  const StoreChip({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
