import 'package:flutter/cupertino.dart';

/// Konto (`/settings/account`, Konzept 18 §7.1).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Account')));
}
