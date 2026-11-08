import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/routes/app_destinations.dart';

void main() {
  String? p(String id) => appDestinationPath(id);

  test('tabs and Teil B areas', () {
    expect(p(AppDestinations.home), '/home');
    expect(p(AppDestinations.lists), '/lists');
    expect(p(AppDestinations.avo), '/avo');
    expect(p(AppDestinations.recipes), '/recipes');
    expect(p(AppDestinations.profile), '/profile');
    expect(p(AppDestinations.plan), '/recipes?segment=plan');
    expect(p(AppDestinations.calories), '/calories');
    expect(p(AppDestinations.offers), '/offers');
    expect(p(AppDestinations.history), '/history');
  });

  test('destinations with an id', () {
    expect(p(AppDestinations.list('l1')), '/lists/l1');
    expect(p(AppDestinations.list('l1', focusAdd: true)), '/lists/l1?focus=add');
    expect(p(AppDestinations.shopping('l1')), '/lists/l1/shopping');
    expect(p(AppDestinations.recipe('r9')), '/recipes/r9');
    expect(p(AppDestinations.savedRecipes), '/recipes/saved');
    expect(p(AppDestinations.settings), '/settings');
    expect(p(AppDestinations.settingsPage('offers')), '/settings/offers');
    expect(p(AppDestinations.pro), '/pro');
    expect(p(AppDestinations.proFeature('cook_mode')), '/pro?feature=cook_mode');
  });

  test('paths and shoply links pass through', () {
    expect(p('/lists/l1'), '/lists/l1');
    expect(p('shoply://shopping?list=l1'), '/lists/l1/shopping');
    expect(p('shoply://avo/voice'), '/avo/voice');
  });

  test('unknown or incomplete ids', () {
    expect(p(''), isNull);
    expect(p('nonsense'), isNull);
    expect(p('list'), isNull);
    expect(p('list:'), isNull);
    expect(p('recipe'), isNull);
    expect(p('shopping'), isNull);
  });

  testWidgets('openAppDestination goes to tabs and pushes the paywall',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        for (final path in ['/home', '/lists/:id', '/pro'])
          GoRoute(
            path: path,
            builder: (context, state) {
              return Builder(
                builder: (context) => GestureDetector(
                  onTap: () {},
                  child: Text(state.uri.toString(),
                      textDirection: TextDirection.ltr),
                ),
              );
            },
          ),
      ],
    );
    await tester.pumpWidget(WidgetsApp.router(
      routerConfig: router,
      color: const Color(0xFF000000),
    ));
    final context = tester.element(find.text('/home'));

    expect(openAppDestination(context, 'nonsense'), isFalse);
    expect(openAppDestination(context, AppDestinations.list('l1')), isTrue);
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/lists/l1');

    final listContext = tester.element(find.text('/lists/l1'));
    expect(openAppDestination(listContext, AppDestinations.proFeature('x')),
        isTrue);
    await tester.pumpAndSettle();
    expect(find.text('/pro?feature=x'), findsOneWidget);
    // Pushed, not gone: closing the paywall returns to the list.
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/lists/l1');
  });
}
