import 'package:flutter/cupertino.dart';

/// Profil bearbeiten (`/settings/profile`, Konzept 18 §4).
/// Placeholder until its A8 part fills it; the constructor is the contract
/// with the profile root and the router.
class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Profile')));
}
