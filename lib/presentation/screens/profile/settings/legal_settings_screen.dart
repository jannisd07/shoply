import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/routes/route_paths.dart';

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

  /// Title key of the document (`setp_legal_privacy`).
  String get titleKey => 'setp_legal_$id';

  /// The web page; null for the licenses, which the app lists itself.
  String? get url => switch (this) {
    LegalDocument.privacy => LegalLinks.privacy,
    LegalDocument.imprint => LegalLinks.imprint,
    LegalDocument.terms => LegalLinks.terms,
    LegalDocument.licenses => null,
  };
}

/// Rechtliches (`/settings/legal`, Konzept 18 §5.9): Datenschutz, Impressum
/// and Nutzungsbedingungen open in the in-app browser (K18-15), Datenquellen
/// is its own page, Lizenzen lists the open-source licenses in the Avo
/// style.
class LegalSettingsScreen extends StatelessWidget {
  const LegalSettingsScreen({super.key, this.highlightRowId});

  final String? highlightRowId;

  @override
  Widget build(BuildContext context) {
    Widget doc(LegalDocument d) => HighlightableRow(
      id: 'legal.${d.id}',
      child: NavRow(
        title: context.tr(d.titleKey),
        onTap: () => openSettingsLocation(
          context,
          RoutePaths.settingsLegalDocument(d.id),
          (_) => LegalDocumentScreen(document: d),
        ),
      ),
    );

    return SettingsPage(
      title: context.tr('setp_legal_title'),
      highlightRowId: highlightRowId,
      children: [
        InsetSection(
          children: [
            doc(LegalDocument.privacy),
            doc(LegalDocument.imprint),
            doc(LegalDocument.terms),
            HighlightableRow(
              id: 'legal.sources',
              child: NavRow(
                title: context.tr('setp_legal_sources'),
                onTap: () => openSettingsLocation(
                  context,
                  RoutePaths.settingsLegalSources,
                  (_) => const DataSourcesScreen(),
                ),
              ),
            ),
            doc(LegalDocument.licenses),
          ],
        ),
      ],
    );
  }
}

/// One data source of [DataSourcesScreen].
class _Source {
  const _Source(this.id, this.url);

  /// Key part: `setp_sources_<id>_title` and `setp_sources_<id>_body`.
  final String id;
  final String url;
}

/// Datenquellen (`/settings/legal/sources`, Konzept 18 §5.9): one section
/// per source with its licence and a link (the ODbL attribution has to stay
/// reachable). The offers source only while the offers module is on and the
/// kill switch is off. Local, works offline.
class DataSourcesScreen extends ConsumerWidget {
  const DataSourcesScreen({super.key, this.highlightRowId});

  final String? highlightRowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers =
        ref.watch(moduleEnabledProvider(AppModule.offers)) &&
        !ref.watch(offersKillSwitchProvider);
    final sources = [
      const _Source('products', 'https://world.openfoodfacts.org'),
      const _Source('prices', 'https://prices.openfoodfacts.org'),
      const _Source('stores', 'https://www.openstreetmap.org/copyright'),
      if (offers) const _Source('offers', 'https://www.marktguru.de'),
    ];
    final actions = ref.read(settingsExternalActionsProvider);

    return SettingsPage(
      title: context.tr('setp_sources_title'),
      highlightRowId: highlightRowId,
      backLabel: context.tr('setp_legal_title'),
      showOffline: false,
      children: [
        for (final s in sources)
          InsetSection(
            header: context.tr('setp_sources_${s.id}_title'),
            showSeparators: false,
            children: [
              HighlightableRow(
                id: 'sources.${s.id}',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AvoSpacing.l,
                    AvoSpacing.m,
                    AvoSpacing.l,
                    AvoSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('setp_sources_${s.id}_body'),
                        style: context.text(AvoTextStyle.body),
                      ),
                      AppButton.plain(
                        label: Uri.parse(s.url).host,
                        onPressed: () => actions.openUrl(Uri.parse(s.url)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// One legal text (`/settings/legal/<id>`, E18-08): the web page in the
/// in-app browser with "In Safari öffnen", or for [LegalDocument.licenses]
/// the open-source licenses of the app.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = document.url;
    if (url == null) return const LicensesScreen();
    return InAppBrowserPage(
      title: context.tr(document.titleKey),
      url: Uri.parse(url),
      loader: ref.watch(settingsWebLoaderProvider),
      onOpenExternally: ref.read(settingsExternalActionsProvider).openUrl,
      backLabel: context.tr('setp_legal_title'),
    );
  }
}

/// The licenses of one package.
@immutable
class PackageLicenses {
  /// Creates the entry.
  const PackageLicenses(this.package, this.paragraphs);

  final String package;

  /// The license texts, paragraph by paragraph.
  final List<String> paragraphs;
}

/// Every package with its license texts, sorted by name (from
/// [LicenseRegistry]). Overridden in tests.
final settingsLicensesProvider = FutureProvider<List<PackageLicenses>>((
  ref,
) async {
  final byPackage = <String, List<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = [
      for (final p in entry.paragraphs)
        if (p.text.trim().isNotEmpty) p.text.trim(),
    ];
    for (final package in entry.packages) {
      (byPackage[package] ??= []).addAll([...text, '']);
    }
  }
  final names = byPackage.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [
    for (final n in names)
      PackageLicenses(n, [
        for (final p in byPackage[n]!)
          if (p.isNotEmpty) p,
      ]),
  ];
});

/// Lizenzen (Konzept 18 §5.9): the open-source packages as rows; each opens
/// its license text. Replaces Flutter's license page.
class LicensesScreen extends ConsumerWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenses = ref.watch(settingsLicensesProvider);
    final List<Widget> children;
    if (licenses.hasValue) {
      final all = licenses.value!;
      children = [
        InsetSection(
          footer: context.tr(
            'setp_licenses_footer',
            params: {'n': '${all.length}'},
          ),
          children: [
            for (final p in all)
              NavRow(
                title: p.package,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => _LicenseTextScreen(licenses: p),
                  ),
                ),
              ),
          ],
        ),
      ];
    } else if (licenses.hasError) {
      children = [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: EmptyState(
            title: context.tr('setp_licenses_error'),
            actionLabel: context.tr('retry'),
            onAction: () => ref.invalidate(settingsLicensesProvider),
          ),
        ),
      ];
    } else {
      children = const [
        Padding(
          padding: EdgeInsets.only(top: AvoSpacing.xxxl),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    return SettingsPage(
      title: context.tr('setp_legal_licenses'),
      backLabel: context.tr('setp_legal_title'),
      showOffline: false,
      children: children,
    );
  }
}

class _LicenseTextScreen extends StatelessWidget {
  const _LicenseTextScreen({required this.licenses});

  final PackageLicenses licenses;

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: licenses.package,
      backLabel: context.tr('setp_legal_licenses'),
      showOffline: false,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in licenses.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: AvoSpacing.m),
                  child: Text(
                    p,
                    style: context.text(
                      AvoTextStyle.footnote,
                      color: context.colors.label,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
