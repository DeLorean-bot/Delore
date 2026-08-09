import 'dart:async';
import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/dashboard/widgets/hero_connect.dart'
    show
        DashboardUtilityBar,
        EmptyHero,
        RouteXWorldMapBackdrop,
        resolveActiveServerCountryCode;
import 'package:flclashx/views/proxies/common.dart' show delayTest;
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// The real refracting lens (`navigation`) costs a live BackdropFilter sample
// per surface, on top of the LiquidGlassView capture itself — fine to spend
// on desktop's spare GPU headroom, not what an already-reported-laggy phone
// needs five more of at once. Mobile keeps the cheaper frosted `panel` look
// these widgets always had; only desktop gets the sidebar's actual glass.
RouteXGlassVariant get _dashboardChromeVariant =>
    system.isMobile ? RouteXGlassVariant.panel : RouteXGlassVariant.navigation;

String _bytes(int value, {bool perSecond = false}) {
  final suffix = perSecond ? '/s' : '';
  if (value <= 0) return '0 B$suffix';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = value.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}$suffix';
}

/// The dashboard's content-plane scene: just the world map, full-bleed,
/// always — including with no profile, so the empty-state welcome card
/// (painted separately, see [DashboardChromeOverlay]) has the same map
/// backdrop behind it as every other dashboard surface. A lens in this
/// content plane sits inside the very image its own `LiquidGlassView`
/// capture samples (see the "split that makes the glass real" note in
/// `scaffold.dart`), so the best a `RouteXGlassSurface` here could ever
/// render as is a frosted, non-refracting card, never the sidebar's actual
/// bent-light look — which is why nothing glass lives in this widget at all.
class DashboardScene extends ConsumerWidget {
  const DashboardScene({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapCode = resolveActiveServerCountryCode(ref);
    return RouteXWorldMapBackdrop(activeCode: mapCode);
  }
}

/// Dashboard-only chrome: the stat strip, profile switcher and connect bar,
/// laid out in the same box `DashboardScene`'s map fills — see
/// `CommonScaffold.dashboardChrome`'s doc for why they moved here. With no
/// profile, shows the welcome/import-a-profile card instead — same chrome
/// placement, same reasoning: it's a `RouteXGlassSurface` too, and it gets
/// to actually refract only up here.
class DashboardChromeOverlay extends ConsumerWidget {
  const DashboardChromeOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfile =
        ref.watch(startButtonSelectorStateProvider.select((s) => s.hasProfile));
    if (!hasProfile) return const EmptyHero();

    // Bottom-anchored actions are the right call on mobile — thumb reach
    // favors the bottom of the screen, and every other primary action in
    // this app already lives down there (HeroNavBar). Desktop is the
    // opposite: people drag windows around, so the bottom edge is the
    // least reliable place to find something. But Apple's own layout
    // guidance is specifically about *critical* controls — "avoid placing
    // controls or critical information at the bottom of a window" — not
    // a blanket ban on anything living down there. Connect is the one
    // thing this screen exists for, so only Connect moves to lead the
    // column on desktop; the utility bar and stat strip are supporting
    // detail, not critical, and stacking all three as glass surfaces at
    // the top just crowds the map and dilutes which one is actually the
    // primary action (the same "use sparingly" point the material system
    // already makes about its own glass). They trail at the bottom
    // instead, leaving Connect alone up top and the map clear in between.
    final anchorTop = !system.isMobile;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final compact = !wide;

        final utilityBar = const Align(
          alignment: Alignment.centerLeft,
          child: DashboardUtilityBar(),
        );
        final statsStrip = _StatsStrip(compact: compact);
        final connectBar = _ConnectBar(compact: compact);

        // Past ~1100 there's enough clear space for the utility bar to
        // share the stat strip's own row instead of taking its own —
        // keeps the secondary cluster as small a footprint as possible
        // wherever there's room for it, on both anchor directions.
        final mergeUtilityIntoStats = constraints.maxWidth >= 1100;
        final secondaryCluster = mergeUtilityIntoStats
            ? [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 320,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DashboardUtilityBar(),
                        ),
                      ),
                      const Spacer(),
                      statsStrip,
                    ],
                  ),
                ),
              ]
            : [
                utilityBar,
                const SizedBox(height: 8),
                statsStrip,
              ];

        return Padding(
          padding: EdgeInsets.fromLTRB(wide ? 16 : 10, 8, wide ? 16 : 10, 12),
          child: Column(
            children: anchorTop
                ? [
                    connectBar,
                    const Expanded(child: SizedBox()),
                    const SizedBox(height: 12),
                    ...secondaryCluster,
                  ]
                : [
                    ...secondaryCluster,
                    const SizedBox(height: 12),
                    const Expanded(child: SizedBox()),
                    const SizedBox(height: 12),
                    connectBar,
                  ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Top stats
// ---------------------------------------------------------------------------
class _StatsStrip extends ConsumerWidget {
  const _StatsStrip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final profile = ref.watch(currentProfileProvider);
    final sub = profile?.subscriptionInfo;
    final traffics = ref.watch(trafficsProvider);
    final live = traffics.length == 0 ? null : traffics[traffics.length - 1];
    // Ping/speed/traffic all read as zero/empty when nothing is connected —
    // full-weight cards of blank numbers compete with Subscription, the one
    // card that's actually meaningful right now. Dim the three that aren't,
    // rather than showing every card as equally important regardless of
    // whether it currently means anything.
    final isRunning = ref.watch(runTimeProvider) != null;
    final down = _bytes(live?.down.value.toInt() ?? 0, perSecond: true);
    final up = _bytes(live?.up.value.toInt() ?? 0, perSecond: true);

    final days = (sub != null && sub.expire > 0)
        ? DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000)
            .difference(DateTime.now())
            .inDays
            .clamp(0, 99999)
        : null;

    final cards = <Widget>[
      _PingCard(isRussian: isRussian, compact: compact),
      _StatCard(
        compact: compact,
        label: isRussian ? 'Скорость' : 'Speed',
        child: Row(
          key: ValueKey('$down|$up'),
          children: [
            const Icon(Icons.arrow_downward_rounded, size: 13),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                down,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(context, compact: compact),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_upward_rounded, size: 13),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                up,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(context, compact: compact),
              ),
            ),
          ],
        ),
      ),
      _StatCard(
        compact: compact,
        label: isRussian ? 'Трафик' : 'Traffic',
        child: Consumer(
          builder: (_, ref, __) {
            final total = ref.watch(totalTrafficProvider);
            final value =
                _bytes(total.up.value.toInt() + total.down.value.toInt());
            return Text(
              value,
              key: ValueKey(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mono(context, bold: true, compact: compact),
            );
          },
        ),
      ),
      _StatCard(
        compact: compact,
        label: isRussian ? 'Подписка' : 'Subscription',
        child: Text(
          days == null
              ? (isRussian ? 'Безлимит' : 'Unlimited')
              : (isRussian ? '$days дн.' : '$days days'),
          key: ValueKey(days),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ];

    // Narrow windows can't fit five cards side by side without truncating
    // every label, so they scroll horizontally instead of shrinking into
    // unreadable stubs. At most widths that leaves the last card cut clean
    // by the window edge, with nothing to say the row keeps going — it
    // read as a card missing, not a card to scroll to. The edge fade is
    // the same "there's more" cue iOS uses for horizontally scrolling
    // chip rows; it fades in on the left too even though nothing's hidden
    // there yet, which is the standard tradeoff for not tracking scroll
    // position just to draw a fixed-height row of stat cards.
    if (compact) {
      return SizedBox(
        height: 62,
        child: RouteXGlassSurface(
          variant: _dashboardChromeVariant,
          tintAlphaFactor: 1,
          blurFactor: system.isMobile ? 1 : 0.3,
          radius: 18,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.05, 0.92, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: cards.length,
              separatorBuilder: (_, __) => VerticalDivider(
                width: 1,
                indent: 12,
                endIndent: 12,
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
              itemBuilder: (_, i) => SizedBox(
                width: 132,
                child: _emphasized(context, i, isRunning, cards[i]),
              ),
            ),
          ),
        ),
      );
    }

    // Centred in the page's own box — the same box the map and the connect
    // bar sit in, so all three share a centre line, and the row glides with
    // the sidebar's own animation when it opens or closes.
    //
    // Centring on the whole window instead needs the row's offset from the
    // window edge, which it cannot know: it is inset by the sidebar, the
    // page padding *and* the scaffold's max-width clamp. Measuring that
    // after layout and correcting with a transform did centre it, but the
    // correction lands a frame late, so the cards jumped into place instead
    // of moving with the sidebar.
    const cardWidths = [82.0, 176.0, 104.0, 130.0];
    return SizedBox(
      height: 56,
      child: RouteXGlassSurface(
        variant: _dashboardChromeVariant,
        tintAlphaFactor: 1,
        blurFactor: system.isMobile ? 1 : 0.3,
        radius: 18,
        expand: false,
        capsule: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  indent: 11,
                  endIndent: 11,
                  color: context.colorScheme.outlineVariant
                      .withValues(alpha: 0.42),
                ),
              SizedBox(
                width: cardWidths[i],
                child: _emphasized(context, i, isRunning, cards[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ping/Speed/Traffic (indices 0-2) read as empty noise while nothing's
/// connected; Subscription (index 3) stays relevant regardless. Dims the
/// former instead of giving every card equal weight no matter what it's
/// currently saying.
Widget _emphasized(
        BuildContext context, int index, bool isRunning, Widget card) =>
    AnimatedOpacity(
      duration: RouteXMotion.resolve(context, RouteXMotion.base),
      curve: RouteXMotion.curve,
      opacity: (index < 3 && !isRunning) ? 0.55 : 1,
      child: card,
    );

TextStyle? _mono(BuildContext context,
        {bool bold = false, bool compact = false}) =>
    context.textTheme.bodySmall?.copyWith(
      fontFamily: FontFamily.jetBrainsMono.value,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
    );

/// Ping for the active server.
///
/// [getDelayProvider] only reads the shared delay cache — it never measures
/// anything — so with no proxy-list visit this card sat on "—" forever.
/// It now kicks off a measurement for the selected proxy and refreshes it
/// periodically.
class _PingCard extends ConsumerStatefulWidget {
  const _PingCard({required this.isRussian, required this.compact});

  final bool isRussian;
  final bool compact;

  @override
  ConsumerState<_PingCard> createState() => _PingCardState();
}

class _PingCardState extends ConsumerState<_PingCard> {
  Timer? _timer;
  String? _lastTested;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _measure());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ({String name, String? testUrl, Proxy? proxy})? _activeProxy() {
    final groups = ref.read(currentGroupsStateProvider).value;
    for (final g in groups) {
      final now = g.realNow;
      if (now.isEmpty || now == 'DIRECT' || now == 'REJECT') continue;
      final name = groups.resolveToDisplayName(g.name);
      final proxy = g.all.where((p) => p.name == now).firstOrNull ??
          g.all.where((p) => p.name == name).firstOrNull;
      return (name: name, testUrl: g.testUrl, proxy: proxy);
    }
    return null;
  }

  Future<void> _measure() async {
    if (!mounted) return;
    if (ref.read(runTimeProvider) == null) return;
    final active = _activeProxy();
    final proxy = active?.proxy;
    if (active == null || proxy == null) return;
    _lastTested = active.name;
    await delayTest([proxy], active.testUrl);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    String? name;
    String? testUrl;
    for (final g in groups) {
      final now = g.realNow;
      if (now.isNotEmpty && now != 'DIRECT' && now != 'REJECT') {
        name = groups.resolveToDisplayName(g.name);
        testUrl = g.testUrl;
        break;
      }
    }
    // A server switch should re-measure rather than show the old number.
    if (name != null && name != _lastTested) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
    final delay = (name == null || name.isEmpty)
        ? null
        : ref.watch(getDelayProvider(proxyName: name, testUrl: testUrl));
    return _StatCard(
      compact: widget.compact,
      label: widget.isRussian ? 'Пинг' : 'Ping',
      child: Text(
        (delay == null || delay <= 0) ? '—' : '$delay ms',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mono(context, bold: true, compact: widget.compact),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.child,
    this.compact = false,
  });

  final String label;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 6 : 7,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            DefaultTextStyle.merge(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: AnimatedSwitcher(
                duration: RouteXMotion.resolve(context, RouteXMotion.fast),
                switchInCurve: RouteXMotion.curve,
                switchOutCurve: RouteXMotion.curve,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: child,
              ),
            ),
          ],
        ),
      );
}

class _Flag extends StatelessWidget {
  const _Flag({required this.code, this.size = 18});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: EmojiText(
          countryCodeToEmoji(code),
          style: TextStyle(fontSize: size * 0.85),
        ),
      );
}

class _ConnectBar extends ConsumerStatefulWidget {
  const _ConnectBar({required this.compact});

  final bool compact;

  @override
  ConsumerState<_ConnectBar> createState() => _ConnectBarState();
}

class _ConnectBarState extends ConsumerState<_ConnectBar> {
  // The actual bring-up (globalState.handleStart) is a real await — on some
  // platforms a VPN-consent prompt alone can take tens of seconds — and
  // nothing on screen said so: the button just sat there between tap and
  // the status flipping. Apple's own rule is blunt about this exact gap —
  // "confirm meaningful actions, expose ongoing status" — so this tracks
  // its own pending flag independent of the provider state.
  bool _pending = false;

  Future<void> _toggle(bool isRunning) async {
    if (_pending) return;
    if (Platform.isAndroid) HapticFeedback.mediumImpact();
    setState(() => _pending = true);
    try {
      await globalState.appController.updateStatus(!isRunning);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final state = ref.watch(startButtonSelectorStateProvider);
    final runTime = ref.watch(runTimeProvider);
    final isRunning = runTime != null;
    final isReady = state.isInit && !_pending;
    final code = resolveActiveServerCountryCode(ref);

    return RouteXGlassSurface(
      // 1:1 with the sidebar (_PremiumSideNavigation in home.dart).
      variant: _dashboardChromeVariant,
      tintAlphaFactor: 1,
      blurFactor: system.isMobile ? 1 : 0.3,
      radius: 22,
      // Sits directly in a Column, so it must size to its content — the
      // default expand:true asks for infinite height here and the bar
      // silently fails to lay out.
      expand: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 12,
        ),
        child: Flex(
          // Compact windows can't fit power + status + server + button on
          // one line without every label collapsing to a couple of glyphs,
          // so they stack into two rows instead.
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment:
              compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          // Vertical stacking wraps to content; the horizontal bar must
          // span the page, otherwise it shrinks to a narrow island.
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Flexible(
              fit: compact ? FlexFit.loose : FlexFit.tight,
              child: Row(
                children: [
                  // Status indicator, not a second control: the labelled button
                  // at the other end of the bar already toggles the connection,
                  // and having both do it read as two connect buttons.
                  AnimatedContainer(
                    duration: RouteXMotion.resolve(context, RouteXMotion.base),
                    curve: RouteXMotion.curve,
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning
                          ? premiumMint
                          : premiumMint.withValues(alpha: 0.10),
                      border: Border.all(
                        color: isRunning
                            ? Colors.transparent
                            : premiumMint.withValues(alpha: 0.55),
                        width: 2,
                      ),
                      boxShadow: isRunning
                          ? [
                              BoxShadow(
                                color: premiumMint.withValues(alpha: 0.32),
                                blurRadius: 28,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    // The only control on this bar that says "something is
                    // happening" between tap and the tunnel actually coming
                    // up/down — before this the circle just sat there for
                    // however long handleStart's await took.
                    child: AnimatedSwitcher(
                      duration:
                          RouteXMotion.resolve(context, RouteXMotion.fast),
                      switchInCurve: RouteXMotion.curve,
                      switchOutCurve: RouteXMotion.curve,
                      child: _pending
                          ? SizedBox(
                              key: const ValueKey('pending'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: isRunning
                                    ? const Color(0xFF09090A)
                                    : premiumMint,
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              key: const ValueKey('power'),
                              size: 26,
                              color: isRunning
                                  ? const Color(0xFF09090A)
                                  : premiumMint,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration:
                              RouteXMotion.resolve(context, RouteXMotion.fast),
                          switchInCurve: RouteXMotion.curve,
                          switchOutCurve: RouteXMotion.curve,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            _pending
                                ? (isRussian ? 'Подключение…' : 'Connecting…')
                                : isRunning
                                    ? (isRussian ? 'Подключено' : 'Connected')
                                    : (isRussian
                                        ? 'Отключено'
                                        : 'Disconnected'),
                            key: ValueKey(_pending ? 'pending' : isRunning),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          _pending
                              ? ''
                              : isRunning
                                  ? utils.getTimeText(runTime)
                                  : (isRussian
                                      ? 'Нажмите, чтобы подключиться'
                                      : 'Tap to connect'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                            fontFamily: isRunning
                                ? FontFamily.jetBrainsMono.value
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (compact) const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Flexible(flex: 1) on both sides used to leave a gap: its
                // fit is loose, so a child narrower than its 50% share (the
                // location chip almost always is) just sits at its own
                // smaller size and leaves the rest of that share as blank
                // space — the button never actually reached the bar's right
                // edge. Expanded forces the chip to fill whatever's left
                // after the button's own natural size, which is what a
                // full-width row of two unevenly-sized controls needs.
                compact
                    ? Expanded(
                        child: _LocationChip(
                        code: code,
                        isRussian: isRussian,
                      ))
                    : _LocationChip(code: code, isRussian: isRussian),
                const SizedBox(width: 10),
                RouteXFocusableTap(
                  borderRadius: 14,
                  onTap: isReady ? () => _toggle(isRunning) : null,
                  // The one primary action in this bar — everything else
                  // here (location chip, the status circle at rest) stays
                  // neutral glass so this is the only thing carrying
                  // background-colour emphasis, the way a single filled
                  // "Done"-style button reads as *the* action in a group
                  // of otherwise-equal controls, not one option among many.
                  child: AnimatedContainer(
                    duration: RouteXMotion.resolve(context, RouteXMotion.base),
                    curve: RouteXMotion.curve,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: premiumMint,
                    ),
                    child: AnimatedSwitcher(
                      duration:
                          RouteXMotion.resolve(context, RouteXMotion.fast),
                      switchInCurve: RouteXMotion.curve,
                      switchOutCurve: RouteXMotion.curve,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        isRunning
                            ? (isRussian ? 'Отключить' : 'Disconnect')
                            : (isRussian ? 'Подключить' : 'Connect'),
                        key: ValueKey(isRunning),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF09090A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The server-location pill in the connect bar. Extracted so the compact
/// layout can wrap it in `Expanded` (fills whatever's left of the row after
/// the connect button's own size) while the wide layout keeps it sized to
/// its own content, right-aligned next to the button.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.code, required this.isRussian});

  final String? code;
  final bool isRussian;

  @override
  Widget build(BuildContext context) => RouteXFocusableTap(
        borderRadius: 14,
        onTap: () => globalState.appController.toPage(PageLabel.proxies),
        // This control already lives on the Connect glass plane. A quiet
        // vibrancy fill keeps it legible without stacking another lens.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.colorScheme.onSurface.withValues(alpha: 0.10),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (code != null) ...[
                  _Flag(code: code!, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    code?.toUpperCase() ?? (isRussian ? 'Выбрать' : 'Choose'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
}
