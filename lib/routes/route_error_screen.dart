import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/routes/route_paths.dart';

/// Shown for a link that leads nowhere (old link, deleted content, a Teil-B
/// route switched off remotely). Calm, no error code, one way out.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AvoSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.tr('common_route_error_title'),
                    textAlign: TextAlign.center,
                    style: context.text(AvoTextStyle.title3),
                  ),
                ),
                const SizedBox(height: AvoSpacing.s),
                Text(
                  context.tr('common_route_error_body'),
                  textAlign: TextAlign.center,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: AvoSpacing.l),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(RoutePaths.home),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AvoSizes.hitTarget,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          context.tr('common_route_error_action'),
                          style: context.text(
                            AvoTextStyle.body,
                            color: colors.tint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
