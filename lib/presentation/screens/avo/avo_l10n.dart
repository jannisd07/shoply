import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/localization_helper.dart';

/// [key] with `{n}` = [n], or its `_one` variant for exactly one ("1 item",
/// not "1 items").
String avoTrCount(
  BuildContext context,
  String key,
  int n, [
  Map<String, String> params = const {},
]) => context.tr(n == 1 ? '${key}_one' : key, params: {'n': '$n', ...params});
