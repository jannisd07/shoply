// Compile smoke test: importing app.dart forces compilation of the entire
// app import graph, so `flutter test` acts as a fast full-compile check.
//
// The app widget is only constructed, not pumped: AvoApp.initState requires
// live services (Supabase, deep links) that don't exist in the test
// environment. If those get mockable, upgrade this to a real pumpWidget test.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/app.dart';

void main() {
  test('AvoApp constructs', () {
    const Widget app = AvoApp();
    expect(app, isA<AvoApp>());
  });
}
