import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to track if user has seen the update dialog
final hasSeenUpdateProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final currentVersion = '1.1.0'; // Update this for each new version
  final lastSeenVersion = prefs.getString('last_seen_version') ?? '1.0.0';

  // Check if this is a new version
  if (currentVersion != lastSeenVersion) {
    return false; // Show update dialog
  }
  return true; // Don't show dialog
});

/// Update dialog for new features
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.celebration, color: AppColors.success),
          const SizedBox(width: 8),
          Text(localizations.appName),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                localizations.whatsNewTitle,
                style: AppTextStyles.h3.copyWith(color: AppColors.success),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),

            // Features List
            _buildFeatureItem(
              context,
              '🤖 Intelligente Produktkategorisierung',
              '29 Kategorien mit automatischer Erkennung von Tippfehlern',
            ),
            _buildFeatureItem(
              context,
              '🌍 Vollständige Lokalisierung',
              'Deutsch und Englisch mit automatischer Spracherkennung',
            ),
            _buildFeatureItem(
              context,
              '✨ Verbesserte Bedienung',
              'Einheiten-Auswahl, ganze Zahlen, automatische Großschreibung',
            ),
            _buildFeatureItem(
              context,
              '📱 Saubere Benutzeroberfläche',
              'Add-Button entfernt, optimierte Edit-Dialoge',
            ),

            const SizedBox(height: AppDimensions.spacingMedium),

            // Call to action
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.forInternalTesters,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Teste die Kategorisierung mit verschiedenen Produkten\n'
                    '• Überprüfe die Sprachumschaltung\n'
                    '• Teste die Einheiten-Auswahl beim Editieren\n'
                    '• Melde unerkannte Produkte',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Mark as seen
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_seen_version', '1.1.0');

            Navigator.of(context).pop();
          },
          child: Text(
            localizations.getStarted,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.success),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show update dialog if it's a new version
Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final currentVersion = '1.1.0';
  final lastSeenVersion = prefs.getString('last_seen_version') ?? '1.0.0';

  // Show dialog only for new versions
  if (currentVersion != lastSeenVersion) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if the context is still valid and has a Navigator
      if (context.mounted && Navigator.maybeOf(context) != null) {
        showDialog(
          context: context,
          barrierDismissible: false, // Must interact with dialog
          builder: (context) => const UpdateDialog(),
        );
      }
    });
  }
}
