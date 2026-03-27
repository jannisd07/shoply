import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final Future<String> _policyTextFuture;

  static final Uri _privacyPolicyUrl = Uri.parse('https://shoplyai.app/privacy');
  static final Uri _dsarUrl =
      Uri.parse('https://app.termly.io/dsar/65529e78-4b1a-4651-8152-3922b069c959');

  @override
  void initState() {
    super.initState();
    _policyTextFuture = _loadPolicyText();
  }

  Future<String> _loadPolicyText() async {
    final String rawHtml =
        await rootBundle.loadString('assets/legal/privacy_policy.html');
    final document = html_parser.parse(rawHtml);

    for (final element in document.querySelectorAll('script, style, noscript')) {
      element.remove();
    }

    final String text =
        (document.querySelector('main') ?? document.body)?.text ?? '';

    return text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'\n\s+'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  Future<void> _openPolicy() async {
    await launchUrl(_privacyPolicyUrl, mode: LaunchMode.inAppBrowserView);
  }

  Future<void> _openDsar() async {
    await launchUrl(_dsarUrl, mode: LaunchMode.inAppBrowserView);
  }

  Future<void> _sendEmail() async {
    final Uri mailto = Uri.parse('mailto:info@shoplyai.app');
    await launchUrl(mailto);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Last updated March 25, 2026',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Full policy text is embedded offline in the app and shown below.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: FutureBuilder<String>(
                future: _policyTextFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }

                  if (snapshot.hasError ||
                      snapshot.data == null ||
                      snapshot.data!.isEmpty) {
                    return Text(
                      'Could not load the embedded policy text. You can still open the online version below.',
                      style: TextStyle(color: scheme.error),
                    );
                  }

                  return SelectableText(
                    snapshot.data!,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open full policy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'View the complete Privacy Policy text and legal sections in app browser.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openPolicy,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Privacy Policy'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your rights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Request access, updates, or deletion of your data through our DSAR form.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openDsar,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Open Data Request Form'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('info@shoplyai.app'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Postal contact: Birkenweg 1, 89198 Westerstetten, Baden-Wurttemberg, Germany',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
