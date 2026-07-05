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
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/navigation_service.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

class AvoApp extends ConsumerStatefulWidget {
  const AvoApp({super.key});

  @override
  ConsumerState<AvoApp> createState() => _AvoAppState();
}

class _AvoAppState extends ConsumerState<AvoApp> with WidgetsBindingObserver {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize deep link service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeepLinks();
      // Push Avo's scheduled restock reminder a day ahead: while the app is
      // being used, the in-app card is the surface — the notification should
      // only fire when the app has NOT been opened since yesterday.
      unawaited(MascotNotificationService.instance.rearmRestockReminder());
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

      DeepLinkService.instance.onAddItemRequested = _handleSiriAddItem;
      DeepLinkService.instance.onCreateListRequested = _handleSiriCreateList;

      await DeepLinkService.instance.initialize(router);

      // Process any pending deep link that opened the app
      DeepLinkService.instance.processPendingDeepLink();
    } catch (e) {
      debugPrint('⚠️ [APP] Failed to initialize deep links: $e');
    }
  }

  /// "Add {item} to {list}" via Siri/Shortcuts (`AddItemToListIntent` in
  /// AppIntents.swift). [listName] comes from Siri's own suggestion list or
  /// free text, so it may not match a real list's casing/name exactly —
  /// reuse the list on an exact case-insensitive match, otherwise create a
  /// new one with that name (matches what the Siri dialog told the user
  /// would happen).
  Future<void> _handleSiriAddItem(
    String itemName,
    String listName,
    double? quantity,
  ) async {
    try {
      final lists = await ref.read(userListsProvider.future);
      final target = _findListByName(lists, listName) ??
          await ref.read(listsNotifierProvider.notifier).createList(listName);

      await ref
          .read(itemsNotifierProvider(target.id).notifier)
          .addItem(name: itemName, quantity: quantity ?? 1.0);

      ref.read(routerProvider).go(
            Uri(path: '/list/${target.id}', queryParameters: {'name': target.name})
                .toString(),
          );
      debugPrint('✅ [SIRI] Added "$itemName" to "${target.name}"');
    } catch (e) {
      debugPrint('❌ [SIRI] Failed to add "$itemName" to "$listName": $e');
    }
  }

  /// "Create list {name}" via Siri/Shortcuts (`CreateListIntent`). Reuses an
  /// existing list with the same name instead of creating a duplicate.
  Future<void> _handleSiriCreateList(String listName) async {
    try {
      final lists = await ref.read(userListsProvider.future);
      final target = _findListByName(lists, listName) ??
          await ref.read(listsNotifierProvider.notifier).createList(listName);

      ref.read(routerProvider).go(
            Uri(path: '/list/${target.id}', queryParameters: {'name': target.name})
                .toString(),
          );
      debugPrint('✅ [SIRI] Opened list "${target.name}"');
    } catch (e) {
      debugPrint('❌ [SIRI] Failed to create list "$listName": $e');
    }
  }

  ShoppingListModel? _findListByName(List<ShoppingListModel> lists, String name) {
    for (final list in lists) {
      if (list.name.toLowerCase() == name.toLowerCase()) return list;
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-arm on every return to the app (throttled inside the service).
      unawaited(MascotNotificationService.instance.rearmRestockReminder());
    }
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
