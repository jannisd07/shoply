import 'package:flutter/cupertino.dart';

/// The legal documents (`/settings/legal/<id>`, Konzept 18 §5.9, E18-11).
enum LegalDocument {
  privacy('privacy'),
  imprint('imprint'),
  terms('terms'),
  licenses('licenses');

  const LegalDocument(this.id);

  final String id;

  static LegalDocument? fromId(String? id) {
    for (final d in values) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// Rechtliches (`/settings/legal`, Konzept 18 §5.9). Placeholder until its
/// A8 part fills it; the constructors here are the contract with the profile
/// root and the router.
class LegalSettingsScreen extends StatelessWidget {
  const LegalSettingsScreen({super.key, this.highlightRowId});

  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Legal')));
}

/// Datenquellen (`/settings/legal/sources`, Konzept 18 §5.9).
class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key, this.highlightRowId});

  final String? highlightRowId;

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('Sources')));
}

/// One legal text in the in-app browser (`/settings/legal/<id>`, E18-08).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) =>
      CupertinoPageScaffold(child: Center(child: Text(document.id)));
}
