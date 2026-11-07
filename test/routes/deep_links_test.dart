import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/routes/deep_links.dart';

void main() {
  String m(String link) => mapCustomSchemeLink(Uri.parse(link));

  test('shared content keeps working (unchanged from before A2)', () {
    expect(m('shoply://recipe/abc'), '/recipe/abc');
    expect(m('shoply://list/l1'), '/list/l1');
    expect(m('shoply://invite/l1'), '/invite/l1');
    expect(m('shoply://author/u9'), '/author/u9');
    expect(m('shoply://recipe'), '/home');
  });

  test('lists, one list with focus, shopping mode', () {
    expect(m('shoply://lists'), '/lists');
    expect(m('shoply://lists/l1?focus=add'), '/lists/l1?focus=add');
    expect(m('shoply://shopping?list=l1'), '/lists/l1/shopping');
    expect(m('shoply://shopping'), '/lists');
  });

  test('recipes: saved and search', () {
    expect(m('shoply://recipes/saved'), '/recipes/saved');
    expect(m('shoply://recipes/search?q=pasta'), '/recipes?q=pasta');
  });

  test('Teil B targets are no longer swallowed by Home', () {
    expect(m('shoply://plan?day=2026-11-11'), '/plan?day=2026-11-11');
    expect(m('shoply://calories/add'), '/calories/add');
    expect(m('shoply://calories/water?ml=250'), '/calories/water?ml=250');
    expect(m('shoply://avo'), '/avo');
    expect(m('shoply://avo?prompt=hallo'), '/avo?prompt=hallo');
    expect(m('shoply://avo/voice'), '/avo/voice');
    expect(m('shoply://settings/offers'), '/settings/offers');
    expect(m('shoply://pro'), '/pro');
    expect(m('shoply://history/t1'), '/history/t1');
  });

  test('action and unknown links land on Home', () {
    expect(m('shoply://add-item?name=Milch'), '/home');
    expect(m('shoply://create-list?name=Party'), '/home');
    expect(m('shoply://nonsense/1'), '/home');
  });
}
