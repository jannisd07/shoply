import 'package:flutter/cupertino.dart';

/// Module (`/settings/modules`, Konzept 18 §5.1).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class ModulesSettingsScreen extends StatelessWidget {
  const ModulesSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Module')));
}
