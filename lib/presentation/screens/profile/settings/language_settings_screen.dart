import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';

/// Language names in their own language (Konzept 18 §5.7).
const Map<String, String> _kLanguageNames = {'de': 'Deutsch', 'en': 'English'};

/// The device language as the app would use it under "System".
final settingsDeviceLanguageProvider = Provider<String>((ref) {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return LanguageNotifier.supportedLanguages.contains(code) ? code : 'en';
});

/// Sprache (`/settings/language`, Konzept 18 §5.7): "System" (with the
/// language it resolves to), "Deutsch", "English". Acts at once through
/// [languageProvider] (device) and is written to `users.language`, so server
/// texts and a second device follow.
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  /// `system`, `de` or `en`: what is chosen (the provider only knows the
  /// resolved language).
  late String _choice = ref.read(languageProvider.notifier).savedSetting;
  bool _picked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readSaved());
  }

  /// The notifier reads the same key asynchronously; read it here as well,
  /// so the checkmark is right before the notifier is done.
  Future<void> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('language');
      final value = LanguageNotifier.supportedLanguages.contains(saved)
          ? saved!
          : 'system';
      if (mounted && !_picked && value != _choice) {
        setState(() => _choice = value);
      }
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Reading the language failed: $e');
    }
  }

  Future<void> _pick(String code) async {
    _picked = true;
    setState(() => _choice = code);
    await ref.read(languageProvider.notifier).setLanguage(code);
    final resolved = ref.read(languageProvider);
    try {
      await ref.read(profileSettingsBackendProvider).saveLanguage(resolved);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Saving the language to the account failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final device = ref.watch(settingsDeviceLanguageProvider);

    Widget row(String code, String title, {String? subtitle}) =>
        HighlightableRow(
          id: 'language.$code',
          child: ChoiceRow(
            title: title,
            subtitle: subtitle,
            selected: _choice == code,
            onTap: () => _pick(code),
          ),
        );

    return SettingsPage(
      title: context.tr('setp_language_title'),
      intro: context.tr('setp_language_intro'),
      highlightRowId: widget.highlightRowId,
      children: [
        InsetSection(
          footer: context.tr('setp_language_footer'),
          children: [
            row(
              'system',
              context.tr('setp_language_system'),
              subtitle: context.tr(
                'setp_language_system_sub',
                params: {'language': _kLanguageNames[device] ?? device},
              ),
            ),
            row('de', _kLanguageNames['de']!),
            row('en', _kLanguageNames['en']!),
          ],
        ),
      ],
    );
  }
}
