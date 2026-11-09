import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';

/// Whether the person lets the members of a shared list see that they are
/// shopping ("Anderen zeigen, dass ich einkaufe", Einstellungen › Listen,
/// Konzept 18 K18-07; later `users.share_presence`). Default on.
///
/// The one gate for presence: while false this device reports no presence
/// for the person (the shopping-mode channel, the "Jemand kauft ein" push)
/// and no surface says "{Name} kauft gerade ein" about them. There is no
/// presence channel yet (`a5-stand.md`); whatever sends or shows presence
/// reads this first.
final sharePresenceProvider = Provider<bool>(
  (ref) => ref.watch(listPreferencesProvider.select((p) => p.sharePresence)),
);
