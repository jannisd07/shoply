import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Greeting key for the hour of the day: morning until 11, day until 17,
/// evening after that.
String homeGreetingKey(DateTime now) {
  if (now.hour < 11) return 'greeting_morning';
  if (now.hour < 17) return 'greeting_day';
  return 'greeting_evening';
}

/// Top of Home (D2 "Für dich"): the date as a small upper-case line and the
/// greeting with the first name, 28/34 bold. No avatar (Konzept 01).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.firstName, this.now});

  /// First name, or null when the account has none.
  final String? firstName;

  /// Clock for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = now ?? DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat('EEEE, d. MMMM', locale).format(time);
    final greeting = context.tr(homeGreetingKey(time));
    final name = firstName?.trim();
    final title = name == null || name.isEmpty ? greeting : '$greeting, $name';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date.toUpperCase(),
            semanticsLabel: date,
            style: context.text(
              AvoTextStyle.caption2,
              color: colors.secondaryLabel,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AvoSpacing.xs),
          Semantics(
            header: true,
            child: Text(title, style: context.text(AvoTextStyle.title1)),
          ),
        ],
      ),
    );
  }
}
