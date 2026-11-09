import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/subscription/paywall_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Paywall (Teil A, A9), full screen above the tab bar. Teil B opens it
/// through `ProGate.run`, or with `context.push(RoutePaths.proFor(id))`.
final List<RouteBase> paywallRoutes = [
  GoRoute(
    path: RoutePaths.pro,
    name: 'pro',
    builder: (context, state) =>
        PaywallScreen(feature: state.uri.queryParameters['feature']),
  ),
];
