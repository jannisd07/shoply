import 'package:flutter/cupertino.dart';

/// Darstellung (`/settings/appearance`, Konzept 18 §5.6).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Appearance')));
}
