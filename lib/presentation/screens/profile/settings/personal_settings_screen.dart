import 'package:flutter/cupertino.dart';

/// Persönliche Daten (`/settings/personal`, Konzept 18 §5.3).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class PersonalSettingsScreen extends StatelessWidget {
  const PersonalSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Personal')));
}
