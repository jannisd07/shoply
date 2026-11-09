import 'package:flutter/cupertino.dart';

/// Ernährung & Allergien (`/settings/diet`, alias `/diet-preferences`, Konzept 18 §5.2).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class DietSettingsScreen extends StatelessWidget {
  const DietSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Diet')));
}
