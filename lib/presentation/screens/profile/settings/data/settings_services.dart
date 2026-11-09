import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/presentation/screens/profile/profile_root_data.dart'
    show appVersionProvider;
import 'package:in_app_review/in_app_review.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/data/services/app_flags_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';

/// What the settings pages hand to the system: mail, Safari, the iOS
/// settings of the app, the App Store rating and the clipboard. Overridden
/// in tests.
abstract interface class SettingsExternalActions {
  /// Opens a new mail. False when no mail app can take it.
  Future<bool> openMail({
    required String to,
    required String subject,
    String? body,
  });

  /// Opens [url] in Safari (outside the app).
  Future<void> openUrl(Uri url);

  /// Opens the iOS settings of the app (permissions, language per app).
  Future<void> openAppSettings();

  /// Asks iOS for the rating dialog of the App Store.
  Future<void> requestReview();

  /// Copies [text] to the clipboard.
  Future<void> copy(String text);
}

/// The real system calls.
class DefaultSettingsExternalActions implements SettingsExternalActions {
  /// Creates the default actions.
  const DefaultSettingsExternalActions();

  @override
  Future<bool> openMail({
    required String to,
    required String subject,
    String? body,
  }) async {
    final query = <String, String>{'subject': subject, 'body': ?body};
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      // `queryParameters` would encode spaces as "+", which mail apps show.
      query: query.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&'),
    );
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Mail could not be opened: $e');
      return false;
    }
  }

  @override
  Future<void> openUrl(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Link could not be opened: $e');
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await permissions.openAppSettings();
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] iOS settings could not be opened: $e');
    }
  }

  @override
  Future<void> requestReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Rating could not be opened: $e');
    }
  }

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

/// The system calls of the settings pages.
final settingsExternalActionsProvider = Provider<SettingsExternalActions>(
  (ref) => const DefaultSettingsExternalActions(),
);

/// The app version as shown in the footer of Hilfe ("1.1.4 (31)"), read once
/// by the profile root; null while unknown.
final settingsAppVersionProvider = Provider<String?>(
  (ref) => ref.watch(appVersionProvider).valueOrNull,
);

/// What "Fehler melden" puts into the mail: the iOS version (the device
/// model needs `device_info_plus`, which the app does not have).
final settingsSystemVersionProvider = Provider<String>((ref) {
  try {
    return Platform.operatingSystemVersion;
  } catch (_) {
    return '';
  }
});

/// "Tipps zurücksetzen" (Konzept 18 §5.8): [TipService.reset].
final settingsTipsResetProvider = Provider<void Function()>(
  (ref) => TipService.instance.reset,
);

/// Where the legal pages and the guide are loaded from.
final settingsWebLoaderProvider = Provider<WebDocumentLoader>(
  (ref) => const HttpWebDocumentLoader(),
);

/// The offers kill switch is known to be on (Konzept 00 §15.3): "Preise &
/// Angebote" disappears without a hint, and so do offers terms.
final offersKillSwitchProvider = Provider<bool>((ref) {
  final flags = ref.watch(appFlagsProvider);
  return flags.isKnown && !flags.isEnabled(AppFlagKeys.offersEnabled);
});
