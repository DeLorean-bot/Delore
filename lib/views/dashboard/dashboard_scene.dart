import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/dashboard/dashboard_flows.dart';
import 'package:flclashx/views/dashboard/widgets/hero_connect.dart'
    show HeroConnect, resolveActiveServerCountryCode;
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
class DashboardScene extends ConsumerWidget {
  const DashboardScene({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfile =
        ref.watch(startButtonSelectorStateProvider.select((s) => s.hasProfile));
    if (!hasProfile) return const HeroConnect();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              const _StatsStrip(),
              const SizedBox(height: 12),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          Expanded(child: SizedBox()),
                          SizedBox(width: 12),
                          SizedBox(width: 300, child: _ActiveAppsPanel()),
                        ],
                      )
                    // Narrow: the map needs the width more than the list
                    // does, so the list collapses to a short dock.
                    : const Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(height: 210, child: _ActiveAppsPanel()),
                      ),
              ),
              const SizedBox(height: 12),
              const _ConnectBar(),
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
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final profile = ref.watch(currentProfileProvider);
    final sub = profile?.subscriptionInfo;
    final isRunning = ref.watch(runTimeProvider.select((v) => v != null));
    final code = resolveActiveServerCountryCode(ref);
    final traffics = ref.watch(trafficsProvider);
    final live = traffics.length == 0 ? null : traffics[traffics.length - 1];

    final days = (sub != null && sub.expire > 0)
        ? DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000)
            .difference(DateTime.now())
            .inDays
            .clamp(0, 99999)
        : null;

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _StatCard(
              label: isRunning
                  ? (isRussian ? 'Подключено' : 'Connected')
                  : (isRussian ? 'Отключено' : 'Disconnected'),
              child: Row(
                children: [
                  if (code != null) ...[
                    _Flag(code: code, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      code == null
                          ? (isRussian ? 'Нет сервера' : 'No server')
                          : code.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _PingCard(isRussian: isRussian)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _StatCard(
              label: isRussian ? 'Скорость' : 'Speed',
              child: Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    _bytes(live?.down.value.toInt() ?? 0, perSecond: true),
                    style: _mono(context),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_upward_rounded, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    _bytes(live?.up.value.toInt() ?? 0, perSecond: true),
                    style: _mono(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: isRussian ? 'Трафик' : 'Traffic',
              child: Consumer(
                builder: (_, ref, __) {
                  final total = ref.watch(totalTrafficProvider);
                  return Text(
                    _bytes(
                      total.up.value.toInt() + total.down.value.toInt(),
                    ),
                    style: _mono(context, bold: true),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _StatCard(
              label: isRussian ? 'Подписка' : 'Subscription',
              child: Text(
                days == null
                    ? (isRussian ? 'Безлимит' : 'Unlimited')
                    : (isRussian
                        ? 'Осталось $days дн.'
                        : '$days days left'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _mono(BuildContext context, {bool bold = false}) =>
    context.textTheme.titleSmall?.copyWith(
      fontFamily: FontFamily.jetBrainsMono.value,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
    );

class _PingCard extends ConsumerWidget {
  const _PingCard({required this.isRussian});

  final bool isRussian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final delay = (name == null || name.isEmpty)
        ? null
        : ref.watch(getDelayProvider(proxyName: name, testUrl: testUrl));
    return _StatCard(
      label: isRussian ? 'Пинг' : 'Ping',
      child: Text(
        (delay == null || delay <= 0) ? '—' : '$delay ms',
        style: _mono(context, bold: true),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => RouteXGlassSurface(
        variant: RouteXGlassVariant.panel,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
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

// ---------------------------------------------------------------------------
// Active apps
// ---------------------------------------------------------------------------
class _ActiveAppsPanel extends StatefulWidget {
  const _ActiveAppsPanel();

  @override
  State<_ActiveAppsPanel> createState() => _ActiveAppsPanelState();
}

class _ActiveAppsPanelState extends State<_ActiveAppsPanel> {
  final _searchController = TextEditingController();
  final _scrollController = SmoothScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    dashboardFlows.addListener();
  }

  @override
  void dispose() {
    dashboardFlows.removeListener();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    return RouteXGlassSurface(
      variant: RouteXGlassVariant.panel,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRussian ? 'Активные приложения' : 'Active apps',
              style: context.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: context.textTheme.bodySmall,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  hintText: isRussian ? 'Поиск приложения' : 'Search app',
                  hintStyle: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<AppFlow>>(
                valueListenable: dashboardFlows.state,
                builder: (_, flows, __) {
                  final visible = _query.isEmpty
                      ? flows
                      : flows
                          .where((f) =>
                              f.process.toLowerCase().contains(_query) ||
                              f.host.toLowerCase().contains(_query))
                          .toList();
                  if (visible.isEmpty) {
                    return Center(
                      child: Text(
                        isRussian ? 'Нет активности' : 'No activity',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _AppRow(flow: visible[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    final name = flow.process.replaceAll(RegExp(r'\.exe$'), '');
    return Row(
      children: [
        _AppIcon(connectionId: flow.connectionId),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  if (flow.countryCode != null) ...[
                    _Flag(code: flow.countryCode!, size: 12),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      flow.viaProxy ? flow.host : '${flow.host} · direct',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '↓${_bytes(flow.downSpeed, perSecond: true)}',
              style: context.textTheme.labelSmall?.copyWith(
                fontFamily: FontFamily.jetBrainsMono.value,
              ),
            ),
            Text(
              '↑${_bytes(flow.upSpeed, perSecond: true)}',
              style: context.textTheme.labelSmall?.copyWith(
                fontFamily: FontFamily.jetBrainsMono.value,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.connectionId});

  final String connectionId;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: const Icon(Icons.apps_rounded, size: 15, color: Colors.white70),
    );
    if (!Platform.isWindows) return fallback;
    return SizedBox(
      width: 28,
      height: 28,
      child: FutureBuilder<ImageProvider?>(
        future: windowsProcessIcon(connectionId),
        builder: (context, snapshot) => snapshot.data == null
            ? fallback
            : ClipOval(child: Image(image: snapshot.data!, fit: BoxFit.cover)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom connect bar
// ---------------------------------------------------------------------------
class _ConnectBar extends ConsumerWidget {
  const _ConnectBar();

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    isRunning
                        ? utils.getTimeText(runTime)
                        : (isRussian
                            ? 'Нажмите, чтобы подключиться'
                            : 'Tap to connect'),
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
            RouteXFocusableTap(
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
                    Text(
                      code?.toUpperCase() ??
                          (isRussian ? 'Выбрать' : 'Choose'),
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
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
            const SizedBox(width: 10),
            RouteXFocusableTap(
              borderRadius: 14,
              onTap: isReady ? toggle : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
