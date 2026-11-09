import 'package:flutter/cupertino.dart';

/// Hilfe (`/settings/help`, Konzept 18 §5.8).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class HelpSettingsScreen extends StatelessWidget {
  const HelpSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Help')));
}
