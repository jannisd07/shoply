import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/theme/app_theme.dart';
import 'package:shoply/core/widgets/update_dialog.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/theme_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/widgets/tutorial/tutorial_overlay.dart';
import 'package:shoply/routes/app_router.dart';
import 'package:shoply/data/services/deep_link_service.dart';
import 'package:shoply/data/services/navigation_service.dart';

class AvoApp extends ConsumerStatefulWidget {
  const AvoApp({super.key});

  @override
  ConsumerState<AvoApp> createState() => _AvoAppState();
}

class _AvoAppState extends ConsumerState<AvoApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize deep link service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeepLinks();
    });

    _authSubscription = SupabaseService.instance.authStateChanges.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(routerProvider).go('/reset-password');
        });
        return;
      }

      if (data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshAccountScopedState();
        });
      }
    });
  }

  void _refreshAccountScopedState() {
    ref.invalidate(currentUserProvider);
    ref.invalidate(shoppingHistoryProvider);
    ref.invalidate(recentHistoryProvider);
    ref.invalidate(shoppingHistoryNotifierProvider);
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(subscriptionNotifierProvider);

    unawaited(SubscriptionService.instance.refreshStatusForCurrentUser());
  }

  /// Initialize deep link handling
  Future<void> _initializeDeepLinks() async {
    try {
      final router = ref.read(routerProvider);

      // Set router in NavigationService for notification handling
      NavigationService.instance.setRouter(router);

      await DeepLinkService.instance.initialize(router);

      // Process any pending deep link that opened the app
      DeepLinkService.instance.processPendingDeepLink();
    } catch (e) {
      debugPrint('⚠️ [APP] Failed to initialize deep links: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final languageCode = ref.watch(languageProvider);

    return AdaptiveApp.router(
      key: ValueKey('$themeMode-$languageCode'),
      title: 'Avo',
      materialLightTheme: AppTheme.lightTheme,
      materialDarkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showUpdateDialogIfNeeded(context);
        });
        return TutorialOverlay(child: child!);
      },
    );
  }
}
