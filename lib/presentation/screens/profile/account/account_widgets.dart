import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/auth/steps/name_step.dart'
    show nameInitials;
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

/// The profile avatar (Konzept 18 §3.2, §4.2: 64 pt; the shared `Avatar`
/// stops at 32 pt, like in the A7 name step).
const double kProfileAvatarSize = 64;

/// Initials at 64 pt keep their size under Dynamic Type (A7 name step).
const double _kInitialsSize = 26;

/// The sync sign at the bottom corner of the avatar (Konzept 00 §12.7).
const double _kSyncBadge = 22;
const double _kSyncGlyph = 13;
const double _kSyncRing = 2;

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

/// The 64 pt profile photo: the new local photo, the stored one from the
/// disk cache, or the initials on `fillStrong`. While a change is on its way
/// the sync sign sits at the bottom corner. The photo fades over the
/// initials (`fadeReduced`). Decorative for VoiceOver; the caller names it.
class ProfilePhotoAvatar extends StatelessWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.name,
    this.photo,
    this.url,
    this.syncing = false,
  });

  /// For the initials.
  final String name;

  /// A photo that is not uploaded yet (wins over [url]).
  final Uint8List? photo;

  /// The stored photo.
  final String? url;

  /// Shows the sync sign.
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initials = nameInitials(name);
    final Widget fallback = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.fillStrong,
        shape: const CircleBorder(),
      ),
      child: Center(
        child: initials.isEmpty
            ? AvoIcon(
                AvoIcons.person,
                filled: true,
                size: _kInitialsSize + AvoSpacing.xs,
                color: colors.secondaryLabel,
              )
            : MediaQuery.withNoTextScaling(
                child: Text(
                  initials,
                  maxLines: 1,
                  style: context
                      .text(AvoTextStyle.title2, weight: FontWeight.w600)
                      .copyWith(fontSize: _kInitialsSize, height: 1.2),
                ),
              ),
      ),
    );
    final bytes = photo;
    final link = url;
    final fade = AvoMotion.fadeReduced;
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) =>
            sync || frame != null ? child : fallback,
        errorBuilder: (context, error, stack) => fallback,
      );
    } else if (link != null && link.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: link,
        fit: BoxFit.cover,
        fadeInDuration: fade,
        fadeOutDuration: Duration.zero,
        placeholder: (context, _) => fallback,
        errorWidget: (context, _, error) => fallback,
      );
    } else {
      image = fallback;
    }
    final circle = SizedBox.square(
      dimension: kProfileAvatarSize,
      child: ClipOval(
        // Every child fills the circle: a landscape photo with BoxFit.cover
        // in the switcher's loose Stack was only 64 x 48 pt.
        child: AnimatedSwitcher(
          duration: fade,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: image,
        ),
      ),
    );
    return ExcludeSemantics(
      child: syncing
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                PositionedDirectional(
                  end: -_kSyncRing,
                  bottom: -_kSyncRing,
                  child: SizedBox.square(
                    dimension: _kSyncBadge,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.surface,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: colors.background,
                            width: _kSyncRing,
                          ),
                        ),
                      ),
                      child: Center(
                        child: AvoIcon(
                          AvoIcons.sync,
                          size: _kSyncGlyph,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : circle,
    );
  }
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
