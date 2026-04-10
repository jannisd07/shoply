import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_preferences_screen.dart';

/// Service for showing one-time contextual prompts at the right moment.
class ContextualPromptService {
  static final ContextualPromptService instance = ContextualPromptService._();
  ContextualPromptService._();

  static const String _keyDietPromptShown = 'ctx_diet_prompt_shown_v1';
  static const String _keyNotifPromptShown = 'ctx_notif_prompt_shown_v1';

  // ── Diet Preferences ─────────────────────────────────────────────

  /// Returns true if we should show the diet preferences prompt.
  /// Shown once, the first time the user opens the Recipes tab.
  Future<bool> shouldShowDietPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyDietPromptShown) == true) return false;

    // Only show if user has no diet preferences yet
    final user = SupabaseService.instance.currentUser;
    if (user == null) return false;
    try {
      final response = await SupabaseService.instance
          .from('users')
          .select('diet_preferences')
          .eq('id', user.id)
          .maybeSingle();
      final prefs2 = (response?['diet_preferences'] as List?)?.cast<String>() ?? [];
      return prefs2.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> markDietPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDietPromptShown, true);
  }

  /// Show the diet preferences dialog.
  Future<void> showDietPrompt(BuildContext context) async {
    await markDietPromptShown();
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _DietPromptDialog(),
    );
  }

  // ── Notification Permission ──────────────────────────────────────

  /// Returns true if we should ask for notification permission on list share.
  Future<bool> shouldShowNotifPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifPromptShown) != true;
  }

  Future<void> markNotifPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifPromptShown, true);
  }

  /// Show a friendly notification permission prompt before sharing.
  Future<void> showNotifPrompt(BuildContext context) async {
    await markNotifPromptShown();
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _NotifPromptSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Diet Preferences Dialog
// ═══════════════════════════════════════════════════════════════════════

class _DietPromptDialog extends StatelessWidget {
  const _DietPromptDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with X button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Ernährungspräferenzen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF3F3F3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 13,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Passe deine Rezeptvorschläge an. Lege in den Einstellungen fest, ob du z.B. vegetarisch oder glutenfrei isst.',
                style: TextStyle(
                  fontSize: 15,
                  color: textColor.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const DietPreferencesScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Zu den Einstellungen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Notification Permission Prompt Sheet
// ═══════════════════════════════════════════════════════════════════════

class _NotifPromptSheet extends StatelessWidget {
  const _NotifPromptSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Bell icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.bell_fill,
              color: Color(0xFF60A5FA),
              size: 26,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Benachrichtigungen aktivieren?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Erfahre wenn jemand Artikel hinzufügt\noder die Liste aktualisiert.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: textColor.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Enable button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                await NotificationService.instance.requestPermissions();
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF60A5FA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Aktivieren',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Skip button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Nicht jetzt',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.4),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
