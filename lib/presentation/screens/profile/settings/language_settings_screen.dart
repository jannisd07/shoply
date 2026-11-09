import 'package:flutter/cupertino.dart';

/// Sprache (`/settings/language`, Konzept 18 §5.7).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Language')));
}
