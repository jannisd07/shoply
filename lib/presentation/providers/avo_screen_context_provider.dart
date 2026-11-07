import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the person was before opening Avo (Kap. 16, Tabelle 5.2). Teil A's
/// screens set it; Avo starts with that list instead of the first one.
@immutable
class AvoScreenContext {
  const AvoScreenContext({required this.screen, this.listId, this.listName});

  /// Screen id, e.g. `home`, `list`, `shopping`, `recipe`, `profile`.
  final String screen;
  final String? listId;
  final String? listName;

  @override
  bool operator ==(Object other) =>
      other is AvoScreenContext &&
      other.screen == screen &&
      other.listId == listId &&
      other.listName == listName;

  @override
  int get hashCode => Object.hash(screen, listId, listName);
}

/// The context Avo reads when a question is sent (contract
/// `prompt-b-vorrang.md`, Stufe 3). Null means "no particular screen".
final avoScreenContextProvider = StateProvider<AvoScreenContext?>(
  (ref) => null,
);
