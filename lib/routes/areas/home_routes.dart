import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/home/home_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Routes of the Home tab branch (Teil A).
final List<RouteBase> homeBranchRoutes = [
  GoRoute(
    path: RoutePaths.home,
    name: 'home',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
  ),
];
