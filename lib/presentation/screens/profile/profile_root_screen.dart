import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/profile_root_data.dart';
import 'package:shoply/presentation/screens/profile/profile_root_pages.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings_search_index.dart';
import 'package:shoply/presentation/screens/profile/settings_search_results.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

/// Space between the toolbar row and the large title (D2 X-Profil: toolbar
/// ends at 98, the title starts at 106), as on the settings pages.
const double _kTitleGap = AvoSpacing.s; // D2

/// D2 X-Profil: 12 below the title and between the first two groups.
const double _kGroupGap = AvoSpacing.m; // D2

/// Person row (Konzept 18 §3.2): at least 76 high, with Teil "Konto"'s
/// 64 pt [ProfilePhotoAvatar].
const double _kHeaderMinHeight = 76;
const double _kHeaderPadding = AvoSpacing.m;

/// Disclosure chevron of the person row, like the settings rows (D2 8 × 14
/// in `secondaryLabel` at 60 %).
const double _kChevronSize = 14; // D2
const double _kChevronAlpha = 0.6;

/// Pushes [location] in the current tab with the settings pages between the
/// root and it (`/settings/account/delete` pushes Konto, then Konto löschen),
/// so Back walks the whole path (Konzept 18 §3.5). Completes when the last
/// page is closed again.
Future<void> pushSettingsLocation(BuildContext context, String location) async {
  final router = GoRouter.of(context);
  final chain = settingsLocationChain(location);
  for (final parent in chain.take(chain.length - 1)) {
    await _pushApplied(router, parent);
  }
  await router.push<void>(chain.last);
}

/// The locations to push for [location]: its settings parents below the
/// first level, then [location] itself.
List<String> settingsLocationChain(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length < 3 || '/${segments.first}' != RoutePaths.settings) {
    return [location];
  }
  return [
    for (var i = 2; i < segments.length; i++) '/${segments.take(i).join('/')}',
    location,
  ];
}

/// Pushes [location] and waits until the router applied it (the redirect is
/// asynchronous), so the next push stacks on top of it.
Future<void> _pushApplied(GoRouter router, String location) {
  final applied = Completer<void>();
  void done() {
    if (!applied.isCompleted) applied.complete();
  }

  router.routerDelegate.addListener(done);
  unawaited(router.push<void>(location));
  return applied.future
      .timeout(const Duration(seconds: 1), onTimeout: () {})
      .whenComplete(() => router.routerDelegate.removeListener(done));
}

/// Root of the Profil tab, also at `/settings` (Konzept 18 §3, D2
/// X-Profil): large title, settings search, the person, Avo Pro and the
/// sections App, Module, Für dich, Allgemein, iPhone, Hilfe und
/// Rechtliches, Konto, with the version at the end.
///
/// Every value comes from the local state at once (no skeleton). Pages
/// open as pushes in this tab; values changed there are in the rows when
/// the person comes back. The search keeps its text while a hit is open.
class ProfileRootScreen extends ConsumerStatefulWidget {
  const ProfileRootScreen({super.key});

  @override
  ConsumerState<ProfileRootScreen> createState() => _ProfileRootScreenState();
}

class _ProfileRootScreenState extends ConsumerState<ProfileRootScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _visible = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the iOS Settings: the notification permission may differ.
    _lifecycle = AppLifecycleListener(onResume: _refreshProbes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _becameVisible());
    }
    _visible = visible;
  }

  void _becameVisible() {
    if (!mounted) return;
    ref.read(avoScreenContextProvider.notifier).state = const AvoScreenContext(
      screen: 'profile',
    );
  }

  /// The iOS permission may have changed (page, iOS Settings).
  void _refreshProbes() {
    if (!mounted) return;
    unawaited(ref.read(notificationPermissionProvider.notifier).refresh());
  }

  Future<void> _open(String location) async {
    await pushSettingsLocation(context, location);
    _refreshProbes();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(profileRootDataProvider);
    final pushed = ModalRoute.of(context)?.canPop ?? false;
    return ColoredBox(
      color: context.colors.background,
      child: Stack(
        children: [
          CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top:
                      GlassToolbar.topOffset(context) +
                      AvoSizes.toolbarButton +
                      _kTitleGap,
                  bottom: ShellInsets.bottom(context),
                ),
                sliver: SliverToBoxAdapter(
                  child: ProfileRootBody(
                    data: data,
                    query: _query,
                    searchController: _search,
                    onQueryChanged: (q) => setState(() => _query = q),
                    onOpen: _open,
                    onRetryProfile: () => ref.invalidate(currentUserProvider),
                    onOpenSystemSettings: () =>
                        ref.read(openSystemSettingsProvider)(),
                  ),
                ),
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
          if (pushed)
            Positioned(
              top: GlassToolbar.topOffset(context),
              left: 0,
              right: 0,
              child: GlassToolbar(
                leading: GlassIconButton(
                  icon: const AvoIcon(AvoIcons.chevronBack),
                  semanticLabel: context.tr('back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The scrolling content of the profile root, without the scroll view: data
/// in, callbacks out. While [query] has text the search hits replace
/// everything below the field.
class ProfileRootBody extends StatelessWidget {
  const ProfileRootBody({
    super.key,
    required this.data,
    required this.onOpen,
    this.query = '',
    this.searchController,
    this.onQueryChanged,
    this.onRetryProfile,
    this.onOpenSystemSettings,
  });

  final ProfileRootData data;
  final String query;
  final TextEditingController? searchController;
  final ValueChanged<String>? onQueryChanged;

  /// Opens a location in the tab (`/settings/diet`, `/pro`).
  final ValueChanged<String> onOpen;

  /// "Erneut versuchen" when the profile could not be loaded.
  final VoidCallback? onRetryProfile;

  /// "iOS-Einstellungen öffnen" in the empty search state.
  final VoidCallback? onOpenSystemSettings;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Semantics(
            header: true,
            child: Text(
              context.tr('common_tab_profile'),
              style: context.text(AvoTextStyle.largeTitle),
            ),
          ),
        ),
        if (data.offline)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.s),
            child: StatusRow(
              kind: StatusKind.offline,
              text: context.tr('prof_offline'),
            ),
          ),
        const SizedBox(height: _kGroupGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: AvoSearchField(
            controller: searchController,
            hint: context.tr('prof_search_hint'),
            onChanged: onQueryChanged,
          ),
        ),
        if (searching)
          SettingsSearchResults(
            query: query,
            hits: searchSettings(query, data.searchScope),
            killSwitch: data.killSwitch,
            onOpen: onOpen,
            onOpenSystemSettings: onOpenSystemSettings ?? () {},
          )
        else
          ..._sections(context),
      ],
    );
  }

  List<Widget> _sections(BuildContext context) {
    final tr = context.tr;
    final kill = data.killSwitch;

    bool shown(ProfilePage p) =>
        (!p.teilB || data.hasRoute(p.route)) &&
        (p.module == null || data.isOn(p.module!));

    Widget row(ProfilePageId id, {String? value}) {
      final page = profilePage(id);
      return NavRow(
        title: tr(page.titleKeyFor(killSwitch: kill)),
        value: value,
        leading: ProfileRowTile.page(page, killSwitch: kill),
        onTap: () => onOpen(page.route),
      );
    }

    List<Widget> rows(List<(ProfilePageId, String?)> items) => [
      for (final (id, value) in items)
        if (shown(profilePage(id))) row(id, value: value),
    ];

    final identity = data.identity;
    final version = data.version;

    Widget section(String headerKey, List<Widget> children) => InsetSection(
      header: tr(headerKey),
      separatorIndent: kProfileRowTextInset,
      children: children,
    );

    return [
      const SizedBox(height: _kGroupGap),
      InsetSection(
        children: [
          _PersonHeader(
            identity: identity,
            onTap: () => onOpen(RoutePaths.settingsProfile),
            onRetry: onRetryProfile,
          ),
        ],
      ),
      const SizedBox(height: _kGroupGap),
      InsetSection(
        children: [
          NavRow(
            title: tr('prof_pro'),
            subtitle: proSubtitle(tr, data.pro),
            leading: const ProfileRowTile(
              icon: ProfileIcons.pro,
              color: ProfileTileColors.pro,
            ),
            onTap: () => onOpen(RoutePaths.pro),
          ),
        ],
      ),
      section(
        'prof_section_app',
        rows([
          (ProfilePageId.modules, modulesValue(tr, data)),
          (ProfilePageId.offers, offersValue(tr, data)),
        ]),
      ),
      section(
        'prof_section_modules',
        rows([
          (ProfilePageId.health, null),
          (ProfilePageId.plan, null),
          (ProfilePageId.avo, null),
        ]),
      ),
      section(
        'prof_section_for_you',
        rows([
          (ProfilePageId.diet, dietValue(tr, data.dietIds, data.allergyCount)),
          (ProfilePageId.personal, null),
          (ProfilePageId.lists, null),
        ]),
      ),
      section(
        'prof_section_general',
        rows([
          (
            ProfilePageId.notifications,
            notificationsValue(tr, data.notifications),
          ),
          (ProfilePageId.appearance, appearanceValue(tr, data.themeMode)),
          (ProfilePageId.language, languageValue(tr, data.languageCode)),
        ]),
      ),
      section(
        'prof_section_iphone',
        rows([(ProfilePageId.siri, null), (ProfilePageId.widgets, null)]),
      ),
      section(
        'prof_section_help_legal',
        rows([(ProfilePageId.help, null), (ProfilePageId.legal, null)]),
      ),
      section(
        'prof_section_account',
        rows([
          (
            ProfilePageId.account,
            switch (identity.signInMethod) {
              final method? => signInMethodLabel(context, method),
              null => null,
            },
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AvoSpacing.xxxl,
          AvoSpacing.xxxl,
          AvoSpacing.xxxl,
          0,
        ),
        child: Text(
          version == null
              ? tr('prof_footer')
              : tr('prof_footer_version', params: {'version': version}),
          textAlign: TextAlign.center,
          style: context.text(
            AvoTextStyle.footnote,
            color: context.colors.secondaryLabel,
          ),
        ),
      ),
    ];
  }
}

/// The person row (Konzept 18 §3.2, §3.6): photo or initial, name and
/// e-mail, chevron; the whole row opens Profil bearbeiten. Without a name it
/// offers "Namen festlegen"; with nothing known "Profil nicht geladen" and
/// "Erneut versuchen". From AX1 on the avatar sits above the texts.
class _PersonHeader extends StatelessWidget {
  const _PersonHeader({
    required this.identity,
    required this.onTap,
    this.onRetry,
  });

  final ProfileIdentity identity;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final name = identity.name;
    final email = identity.email;

    if (identity.missing) {
      final retry = onRetry;
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kHeaderMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: _kHeaderPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('prof_not_loaded'),
                style: context.text(AvoTextStyle.title3),
              ),
              if (retry != null)
                AppButton.plain(
                  label: context.tr('common_try_again'),
                  onPressed: retry,
                ),
            ],
          ),
        ),
      );
    }

    final title = Text(
      name ?? context.tr('prof_set_name'),
      style: context.text(
        AvoTextStyle.title3,
        color: name == null ? colors.tint : colors.label,
      ),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        if (email != null)
          Text(
            breakableEmail(email),
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
      ],
    );
    final avatar = ProfilePhotoAvatar(
      name: name ?? '',
      photo: identity.localPhoto,
      url: identity.avatarUrl,
      syncing: identity.photoSyncing,
    );
    final chevron = AvoIcon(
      AvoIcons.chevronRight,
      size: _kChevronSize,
      color: colors.secondaryLabel.withValues(alpha: _kChevronAlpha),
    );
    final content = ax
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatar,
                    const SizedBox(height: AvoSpacing.s),
                    texts,
                  ],
                ),
              ),
              const SizedBox(width: AvoSpacing.m),
              chevron,
            ],
          )
        : Row(
            children: [
              avatar,
              const SizedBox(width: AvoSpacing.m),
              Expanded(child: texts),
              const SizedBox(width: AvoSpacing.m),
              chevron,
            ],
          );

    return Semantics(
      container: true,
      button: true,
      label: [name ?? context.tr('prof_set_name'), ?email].join(', '),
      hint: context.tr('prof_edit_profile'),
      onTap: onTap,
      child: ExcludeSemantics(
        child: _PressHighlight(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kHeaderMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: _kHeaderPadding,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The iOS row highlight: `fillStrong` the moment a finger touches, fading
/// out with a quick spring on release (like the settings rows).
class _PressHighlight extends StatefulWidget {
  const _PressHighlight({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressHighlight> createState() => _PressHighlightState();
}

class _PressHighlightState extends State<_PressHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlight = AnimationController.unbounded(
    vsync: this,
  );

  void _press() {
    _highlight
      ..stop()
      ..value = 1;
  }

  void _release() {
    _highlight.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _highlight.value,
        0,
        _highlight.velocity,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _highlight.value = 0;
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.fillStrong;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _highlight,
        builder: (context, child) => ColoredBox(
          color: fill.withValues(
            alpha: fill.a * _highlight.value.clamp(0.0, 1.0),
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
