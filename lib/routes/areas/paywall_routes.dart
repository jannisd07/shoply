import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Paywall (Teil A), full screen above the tab bar. Teil B opens it with
/// `context.push('${RoutePaths.pro}?feature=<id>')`. The D2 paywall
/// ("Avo Pro") replaces the screen in A9; the path stays.
final List<RouteBase> paywallRoutes = [
  GoRoute(
    path: RoutePaths.pro,
    name: 'pro',
    builder: (context, state) => const SubscriptionScreen(),
  ),
];
