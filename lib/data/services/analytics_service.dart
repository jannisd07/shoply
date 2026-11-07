import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Firebase Analytics (GA4) wrapper. Currently only tracks screen views via
/// [observer]; Firebase's automatic events cover the rest.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  FirebaseAnalyticsObserver? _firebaseObserver;

  /// Call after `Firebase.initializeApp`.
  Future<void> initialize() async {
    try {
      final analytics = FirebaseAnalytics.instance;
      _firebaseObserver = FirebaseAnalyticsObserver(analytics: analytics);
      await analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('✅ [ANALYTICS] Initialized');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] Initialization failed: $e');
    }
  }

  /// Navigator observer for screen tracking. The router is built before
  /// Firebase is initialized, so this observer forwards route changes to the
  /// Firebase observer only once [initialize] has run. Returns a new instance
  /// per call because an observer can only be attached to one navigator.
  NavigatorObserver? get observer => _DeferredAnalyticsObserver();
}

class _DeferredAnalyticsObserver extends NavigatorObserver {
  FirebaseAnalyticsObserver? get _target =>
      AnalyticsService.instance._firebaseObserver;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _target?.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _target?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _target?.didPop(route, previousRoute);
  }
}
