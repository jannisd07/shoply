import 'package:flutter/cupertino.dart';

/// Listen (`/settings/lists`, Konzept 18 §5.4).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class ListsSettingsScreen extends StatelessWidget {
  const ListsSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Lists')));
}
