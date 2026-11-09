import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

/// Konzept 00 §12.20: unavailable controls at 40 %.
const double kAccountDisabledOpacity = 0.4;

/// Symbols in the read-only rows of Konto löschen, next to 17 pt text.
const double kAccountInfoIconSize = 20;

/// Body size at the default text size, the reference for scaling the symbol.
const double _kBodyAtLarge = 17;

/// Minimum row height (D2 X-Profil `.row`).
const double _kRowMinHeight = 52; // D2

/// "Apple", "Google" or "E-Mail".
String signInMethodLabel(BuildContext context, SignInMethod method) =>
    context.tr(switch (method) {
      SignInMethod.apple => 'acct_method_apple',
      SignInMethod.google => 'acct_method_google',
      SignInMethod.email => 'acct_method_email',
    });

/// [email] with break chances after "@" and "." (Konzept 18 §3.8: it wraps
/// there at large text, never with an ellipsis).
String breakableEmail(String email) =>
    email.replaceAll('@', '@​').replaceAll('.', '.​');

/// Pushes [path] in the current tab, or [fallback] where no router exists
/// (tests, isolated screens).
Future<T?> pushAccountPage<T>(
  BuildContext context,
  String path,
  WidgetBuilder fallback,
) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<T>(path);
  return Navigator.of(context).push<T>(CupertinoPageRoute(builder: fallback));
}

/// The image of the profile avatar: the new local photo (wins), the stored
/// one from the disk cache, or null for the initials. Pass it to
/// `Avatar(size: AvatarSize.xl, image: …)`.
ImageProvider? profileAvatarImage({Uint8List? photo, String? url}) {
  if (photo != null) return MemoryImage(photo);
  if (url != null && url.isNotEmpty) return CachedNetworkImageProvider(url);
  return null;
}

/// A centred destructive row ("Abmelden", "Konto löschen") that can show a
/// small activity indicator at the end while the action runs (Konzept 18
/// §7.2: the label and the width stay). Disabled rows are dimmed to 40 %.
class AccountDestructiveRow extends StatelessWidget {
  const AccountDestructiveRow({
    super.key,
    required this.title,
    required this.onTap,
    this.working = false,
    this.workingLabel,
    this.enabled = true,
  });

  final String title;
  final VoidCallback onTap;
  final bool working;

  /// VoiceOver value while [working] ("Wird abgemeldet").
  final String? workingLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !working;
    Widget row = DestructiveRow(title: title, onTap: active ? onTap : () {});
    if (working) {
      row = Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          IgnorePointer(child: row),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: AvoSpacing.l),
            child: CupertinoActivityIndicator(),
          ),
        ],
      );
    } else if (!enabled) {
      row = IgnorePointer(
        child: Opacity(opacity: kAccountDisabledOpacity, child: row),
      );
    }
    if (active) return row;
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: title,
      value: working ? workingLabel : null,
      liveRegion: working ? true : null,
      excludeSemantics: true,
      child: row,
    );
  }
}

/// A read-only row with a symbol and a sentence (Konto löschen, "Was
/// gelöscht wird"): `ValueRow` has no symbol. Same padding and minimum
/// height as the settings rows; the text wraps.
class AccountInfoRow extends StatelessWidget {
  const AccountInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
    this.trailing,
  });

  final AvoIconData icon;
  final String text;
  final Color? iconColor;

  /// Below the text (a button such as "Abo verwalten").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = context.typography.lineHeightOf(AvoTextStyle.body);
    final size =
        kAccountInfoIconSize *
        context.typography.sizeOf(AvoTextStyle.body) /
        _kBodyAtLarge;
    final end = trailing;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                height: line,
                width: size,
                child: Center(
                  child: AvoIcon(
                    icon,
                    size: size,
                    color: iconColor ?? colors.secondaryLabel,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AvoSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: context.text(AvoTextStyle.body)),
                  if (end != null) ...[
                    const SizedBox(height: AvoSpacing.s),
                    end,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
