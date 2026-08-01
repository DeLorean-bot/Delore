import 'dart:async';
import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/dashboard/dashboard_flows.dart';
import 'package:flclashx/views/proxies/common.dart' show delayTest;
import 'package:flclashx/views/dashboard/widgets/hero_connect.dart'
    show HeroConnect, RouteXWorldMapBackdrop, resolveActiveServerCountryCode;
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The dashboard as a full-page scene: a strip of live stats across the top,
/// the world map showing through the middle (painted by CommonScaffold, one
/// layer below), the active-app list docked right, and the connect control
/// spanning the bottom.
class DashboardScene extends ConsumerStatefulWidget {
  const DashboardScene({super.key});

  @override
  ConsumerState<DashboardScene> createState() => _DashboardSceneState();
}

class _DashboardSceneState extends ConsumerState<DashboardScene> {
  /// The panel covers a slice of the map, and map markers can end up behind
  /// it, so it can be folded away.
  bool _showApps = true;

  @override
  Widget build(BuildContext context) {
    final hasProfile =
        ref.watch(startButtonSelectorStateProvider.select((s) => s.hasProfile));
    if (!hasProfile) return const HeroConnect();

    final mapCode = resolveActiveServerCountryCode(ref);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Stack(
          fit: StackFit.expand,
          children: [
            // The dashboard's own sharp copy. It lives in the page content
            // so the glass panels above can actually blur it, and so the
            // app markers share its coordinate space; every other page gets
            // the blurred copy from CommonScaffold instead.
            Positioned.fill(
              child: RouteXWorldMapBackdrop(activeCode: mapCode),
            ),
            Padding(
          padding: EdgeInsets.fromLTRB(wide ? 16 : 10, 8, wide ? 16 : 10, 12),
          child: Column(
            children: [
              _StatsStrip(compact: !wide),
              const SizedBox(height: 12),
              const Expanded(child: SizedBox()),
              const SizedBox(height: 12),
              _ConnectBar(compact: !wide),
            ],
          ),
            ),
          ],
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
          children: [
            const Icon(Icons.arrow_downward_rounded, size: 13),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                _bytes(live?.down.value.toInt() ?? 0, perSecond: true),
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
                _bytes(live?.up.value.toInt() ?? 0, perSecond: true),
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
            return Text(
              _bytes(total.up.value.toInt() + total.down.value.toInt()),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ];

    // Narrow windows can't fit five cards side by side without truncating
    // every label, so they scroll horizontally instead of shrinking into
    // unreadable stubs.
    if (compact) {
      return SizedBox(
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => SizedBox(width: 132, child: cards[i]),
        ),
      );
    }

    // Equal cells, centred as a group: uneven widths pinned to one edge
    // read as a ragged pile rather than a row of readouts.
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            SizedBox(width: 150, child: cards[i]),
          ],
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) => RouteXGlassSurface(
        variant: RouteXGlassVariant.panel,
        radius: compact ? 13 : 16,
        child: Padding(
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
                child: child,
              ),
            ],
          ),
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

class _ConnectBar extends ConsumerWidget {
  const _ConnectBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final state = ref.watch(startButtonSelectorStateProvider);
    final runTime = ref.watch(runTimeProvider);
    final isRunning = runTime != null;
    final isReady = state.isInit;
    final code = resolveActiveServerCountryCode(ref);

    void toggle() {
      if (!isReady) return;
      if (Platform.isAndroid) HapticFeedback.mediumImpact();
      globalState.appController.updateStatus(!isRunning);
    }

    return RouteXGlassSurface(
      variant: RouteXGlassVariant.panel,
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
            RouteXFocusableTap(
              borderRadius: 28,
              onTap: isReady ? toggle : null,
              child: AnimatedContainer(
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
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 26,
                  color: isRunning ? const Color(0xFF07110E) : premiumMint,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRunning
                        ? (isRussian ? 'Подключено' : 'Connected')
                        : (isRussian ? 'Отключено' : 'Disconnected'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    isRunning
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
            Flexible(
              flex: compact ? 1 : 0,
              child: RouteXFocusableTap(
              borderRadius: 14,
              onTap: () =>
                  globalState.appController.toPage(PageLabel.proxies),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (code != null) ...[
                      _Flag(code: code, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        code?.toUpperCase() ??
                            (isRussian ? 'Выбрать' : 'Choose'),
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
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: compact ? 1 : 0,
              child: RouteXFocusableTap(
                borderRadius: 14,
                onTap: isReady ? toggle : null,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    isRunning
                        ? (isRussian ? 'Отключить' : 'Disconnect')
                        : (isRussian ? 'Подключить' : 'Connect'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
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
