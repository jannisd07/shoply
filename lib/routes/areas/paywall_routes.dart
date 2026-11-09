import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/subscription/paywall_screen.dart';
import 'package:shoply/presentation/widgets/design/zoom_page.dart';
import 'package:shoply/routes/route_paths.dart';

/// Paywall (Teil A, A9), full screen above the tab bar. It grows out of the
/// element that opened it (`ZoomOrigin`, Konzept 18 §8.2). Teil B opens it
/// through `ProGate.run`, or with `ProGate.openPaywall`.
final List<RouteBase> paywallRoutes = [
  GoRoute(
    path: RoutePaths.pro,
    name: 'pro',
    pageBuilder: (context, state) => ZoomPage<Object?>(
      key: state.pageKey,
      name: state.name,
      origin: ZoomOrigin.take(),
      child: PaywallScreen(feature: state.uri.queryParameters['feature']),
    ),
  ),
];
