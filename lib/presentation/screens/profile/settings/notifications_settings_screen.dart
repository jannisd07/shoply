import 'package:flutter/cupertino.dart';

/// Mitteilungen (`/settings/notifications`, Konzept 18 §5.5).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Notifications')));
}
