import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/routes/route_paths.dart';

/// A question handed to the Avo tab from inside the app, which Avo sends at
/// once (Home's "Frag Avo …"). It travels as the route's `extra`, which no
/// URL can carry: deep links (`shoply://avo?q=…`, `?prompt=`) only fill the
/// composer and never send (Kap. 1).
@immutable
class AvoAsk {
  AvoAsk(this.question) : id = _next++;

  static int _next = 0;

  final String question;

  /// Every hand-over is sent once, even the same question twice in a row.
  final int id;
}

/// Opens the Avo tab and sends [question] there exactly once. For in-app
/// entry points only; an empty question just opens the tab.
void openAvoWithQuestion(BuildContext context, String question) {
  final q = question.trim();
  if (q.isEmpty) {
    context.go(RoutePaths.avo);
    return;
  }
  context.go(RoutePaths.avo, extra: AvoAsk(q));
}
