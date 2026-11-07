import 'package:flutter/widgets.dart';

/// The tabs of the D2 tab bar, in order (Teil A). Used by the area route
/// files to say in which tab a route opens. Until S2 the shell still has the
/// old tabs: routes for [lists] and [avo] then open full screen.
enum AppBranch { home, lists, avo, recipes, profile }

/// The app's root navigator. A route with
/// `parentNavigatorKey: rootNavigatorKey` opens full screen above the tab bar.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
