import 'package:flutter/cupertino.dart';

/// Konto löschen (`/settings/account/delete`, Konzept 18 §7.3).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Delete')));
}
