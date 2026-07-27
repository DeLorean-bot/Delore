import 'dart:ui';

import 'package:app_discovery/app_discovery.dart';
import 'package:flclashx/common/application_routing.dart';
import 'package:flclashx/common/premium_theme.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/models/models.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class ApplicationTrafficData {
  const ApplicationTrafficData({
    this.upload = 0,
    this.download = 0,
    this.connections = 0,
    this.items = const [],
  });

  final int upload;
  final int download;
  final int connections;
  final List<ApplicationConnectionData> items;
}

class ApplicationConnectionData {
  const ApplicationConnectionData({
    required this.host,
    required this.destinationIp,
    required this.destinationPort,
    required this.network,
    required this.chain,
    required this.upload,
    required this.download,
  });

  final String host;
  final String destinationIp;
  final String destinationPort;
  final String network;
  final List<String> chain;
  final int upload;
  final int download;

  String get destination => host.isNotEmpty ? host : destinationIp;
}

class ApplicationsScene extends StatefulWidget {
  const ApplicationsScene({
    super.key,
    required this.supported,
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.allApplicationsCount,
    required this.applications,
    required this.routes,
    required this.traffic,
    required this.onRefresh,
    required this.onQueryChanged,
    required this.onRouteChanged,
    required this.onBypass,
  });

  final bool supported;
  final bool loading;
  final bool refreshing;
  final Object? error;
  final int allApplicationsCount;
  final List<DiscoveredApplication> applications;
  final Map<String, ApplicationRouteEntry> routes;
  final Map<String, ApplicationTrafficData> traffic;
  final VoidCallback onRefresh;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function(
    DiscoveredApplication application,
    ApplicationRoute route,
  ) onRouteChanged;
  final VoidCallback onBypass;

  @override
  State<ApplicationsScene> createState() => _ApplicationsSceneState();
}

class _ApplicationsSceneState extends State<ApplicationsScene> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.traffic.values
        .where((traffic) => traffic.connections > 0)
        .length;
    final proxy = widget.routes.values
        .where((route) => route.route == ApplicationRoute.proxy)
        .length;
    final direct = widget.routes.values
        .where((route) => route.route == ApplicationRoute.direct)
        .length;
    final rules = (widget.allApplicationsCount - proxy - direct).clamp(
      0,
      widget.allApplicationsCount,
    );

    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF070A0F),
              Color(0xFF0C1119),
              Color(0xFF080C12),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -130,
              right: -90,
              child: _GlowOrb(color: Color(0xFF52E0C1), size: 340),
            ),
            const Positioned(
              bottom: -190,
              left: 20,
              child: _GlowOrb(color: Color(0xFF537BF2), size: 410),
            ),
            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    applications: widget.allApplicationsCount,
                    online: online,
                    refreshing: widget.refreshing,
                    onRefresh: widget.onRefresh,
                  ),
                  const SizedBox(height: 18),
                  _SearchPanel(
                    controller: _searchController,
                    resultCount: widget.applications.length,
                    onChanged: widget.onQueryChanged,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final overview = _RoutingOverview(
                          proxy: proxy,
                          direct: direct,
                          rules: rules,
                          horizontal: !wide,
                        );
                        final content = _ApplicationsContent(
                          supported: widget.supported,
                          loading: widget.loading,
                          error: widget.error,
                          applications: widget.applications,
                          routes: widget.routes,
                          traffic: widget.traffic,
                          onRetry: widget.onRefresh,
                          onRouteChanged: widget.onRouteChanged,
                          onBypass: widget.onBypass,
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 236, child: overview),
                              const SizedBox(width: 16),
                              Expanded(child: content),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(height: 102, child: overview),
                            const SizedBox(height: 12),
                            Expanded(child: content),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.applications,
    required this.online,
    required this.refreshing,
    required this.onRefresh,
  });

  final int applications;
  final int online;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF68E7C9), Color(0xFF467CEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF57D7C0).withValues(alpha: 0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Color(0xFF07100F),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE ROUTING',
                  style: TextStyle(
                    color: Color(0xFF62E6C5),
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Active applications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF5F7F8),
                    fontFamily: 'Unbounded',
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.9,
                  ),
                ),
              ],
            ),
          ),
          _HeaderStat(value: '$applications', label: 'OPEN'),
          const SizedBox(width: 8),
          _HeaderStat(
            value: '$online',
            label: 'ONLINE',
            accent: const Color(0xFF62E6C5),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: refreshing ? null : onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xB31A222D),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            icon: AnimatedRotation(
              turns: refreshing ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFFB5BFCA),
                size: 20,
              ),
            ),
          ),
        ],
      );
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.value,
    required this.label,
    this.accent = const Color(0xFFE5E9ED),
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xB3121821),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontFamily: 'Unbounded',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF657184),
                fontFamily: 'JetBrainsMono',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.resultCount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int resultCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _GlassPanel(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF7D899A),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(
                  color: Color(0xFFF2F5F7),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search apps, windows, executables...',
                  hintStyle: TextStyle(
                    color: Color(0xFF647082),
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF8995A6),
                  size: 19,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1D2531),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$resultCount FOUND',
                style: const TextStyle(
                  color: Color(0xFF8D99A9),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RoutingOverview extends StatelessWidget {
  const _RoutingOverview({
    required this.proxy,
    required this.direct,
    required this.rules,
    required this.horizontal,
  });

  final int proxy;
  final int direct;
  final int rules;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'PROXY',
        subtitle: 'Encrypted route',
        count: proxy,
        icon: Icons.shield_outlined,
        color: const Color(0xFF62E6C5),
      ),
      _MetricData(
        label: 'DIRECT',
        subtitle: 'Native network',
        count: direct,
        icon: Icons.near_me_outlined,
        color: const Color(0xFF7D9DFF),
      ),
      _MetricData(
        label: 'RULES',
        subtitle: 'Profile logic',
        count: rules,
        icon: Icons.alt_route_rounded,
        color: const Color(0xFFFFB45C),
      ),
    ];
    return _GlassPanel(
      radius: 22,
      padding: EdgeInsets.all(horizontal ? 9 : 14),
      child: horizontal
          ? Row(
              children: [
                for (final metric in metrics)
                  Expanded(child: _Metric(metric: metric, compact: true)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Text(
                    'ROUTING MAP',
                    style: TextStyle(
                      color: Color(0xFF778395),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                for (final metric in metrics) ...[
                  Expanded(child: _Metric(metric: metric)),
                  if (metric != metrics.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0x7A0A0E14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.055),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF62E6C5),
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changes apply instantly to Mihomo',
                          style: TextStyle(
                            color: Color(0xFF8692A2),
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.metric, this.compact = false});

  final _MetricData metric;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 0),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              metric.color.withValues(alpha: 0.12),
              metric.color.withValues(alpha: 0.025),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: metric.color.withValues(alpha: 0.17)),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 30 : 38,
              height: compact ? 30 : 38,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(metric.icon, color: metric.color, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: TextStyle(
                      color: metric.color,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    Text(
                      metric.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687587),
                        fontFamily: 'JetBrainsMono',
                        fontSize: 8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${metric.count}',
              style: TextStyle(
                color: metric.color,
                fontFamily: 'Unbounded',
                fontSize: compact ? 13 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _ApplicationsContent extends StatelessWidget {
  const _ApplicationsContent({
    required this.supported,
    required this.loading,
    required this.error,
    required this.applications,
    required this.routes,
    required this.traffic,
    required this.onRetry,
    required this.onRouteChanged,
    required this.onBypass,
  });

  final bool supported;
  final bool loading;
  final Object? error;
  final List<DiscoveredApplication> applications;
  final Map<String, ApplicationRouteEntry> routes;
  final Map<String, ApplicationTrafficData> traffic;
  final VoidCallback onRetry;
  final Future<void> Function(
    DiscoveredApplication application,
    ApplicationRoute route,
  ) onRouteChanged;
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    if (!supported) {
      return const _EmptyState(
        icon: Icons.desktop_windows_rounded,
        title: 'Windows only — for now',
        subtitle: 'Native application discovery currently runs on Windows.',
      );
    }
    if (loading && applications.isEmpty) {
      return const _EmptyState(
        loading: true,
        title: 'Scanning your desktop',
        subtitle: 'Matching open windows with live network connections.',
      );
    }
    if (error != null && applications.isEmpty) {
      return _EmptyState(
        icon: Icons.sync_problem_rounded,
        title: 'Discovery paused',
        subtitle: '$error',
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }
    if (applications.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing matched',
        subtitle: 'Try another app name, window title, or executable.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 190,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: applications.length,
          itemBuilder: (_, index) {
            final application = applications[index];
            final key = application.executablePath.toLowerCase();
            return _PremiumApplicationCard(
              key: ValueKey(application.pid),
              application: application,
              route: routes[key]?.route ?? ApplicationRoute.rule,
              routeTarget: routes[key]?.target,
              traffic: traffic[key] ?? const ApplicationTrafficData(),
              onRouteChanged: (route) => onRouteChanged(application, route),
              onBypass: onBypass,
            );
          },
        );
      },
    );
  }
}

class _PremiumApplicationCard extends StatefulWidget {
  const _PremiumApplicationCard({
    super.key,
    required this.application,
    required this.route,
    required this.routeTarget,
    required this.traffic,
    required this.onRouteChanged,
    required this.onBypass,
  });

  final DiscoveredApplication application;
  final ApplicationRoute route;
  final String? routeTarget;
  final ApplicationTrafficData traffic;
  final ValueChanged<ApplicationRoute> onRouteChanged;
  final VoidCallback onBypass;

  @override
  State<_PremiumApplicationCard> createState() =>
      _PremiumApplicationCardState();
}

class _PremiumApplicationCardState extends State<_PremiumApplicationCard> {
  bool _hovered = false;

  Future<void> _showDetails() => showDialog<void>(
        context: context,
        barrierColor: const Color(0xB3070A0F),
        builder: (_) => _ApplicationDetailsDialog(
          application: widget.application,
          route: widget.route,
          routeTarget: widget.routeTarget,
          traffic: widget.traffic,
          onRouteChanged: widget.onRouteChanged,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final online = widget.traffic.connections > 0;
    final accent = switch (widget.route) {
      ApplicationRoute.proxy => const Color(0xFF62E6C5),
      ApplicationRoute.direct => const Color(0xFF7D9DFF),
      ApplicationRoute.rule => const Color(0xFFFFB45C),
    };
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _showDetails,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xC9141A23),
              const Color(0xE61A222E),
              _hovered ? 1 : 0,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.36)
                  : Colors.white.withValues(alpha: 0.075),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.38 : 0.22),
                blurRadius: _hovered ? 30 : 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              children: [
                Positioned(
                  top: -44,
                  right: -34,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.17),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ApplicationIcon(
                            path: widget.application.executablePath,
                            accent: accent,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.application.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFF4F7F8),
                                    fontFamily: 'Unbounded',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.application.windowTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF788596),
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _NetworkStatus(online: online),
                              const SizedBox(height: 5),
                              Text(
                                online
                                    ? '${widget.traffic.connections} streams ›'
                                    : 'open details ›',
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.78),
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _InfoChip(label: 'PID ${widget.application.pid}'),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _InfoChip(
                              label: p.basename(
                                widget.application.executablePath,
                              ),
                            ),
                          ),
                          if (online) ...[
                            const SizedBox(width: 6),
                            _InfoChip(
                              label:
                                  '↓ ${TrafficValue(value: widget.traffic.download).show}',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xA30A0E14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _RouteButton(
                                label: widget.routeTarget ?? 'Proxy',
                                icon: Icons.shield_outlined,
                                color: const Color(0xFF62E6C5),
                                selected:
                                    widget.route == ApplicationRoute.proxy,
                                onPressed: () => widget.onRouteChanged(
                                  ApplicationRoute.proxy,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _RouteButton(
                                label: 'Direct',
                                icon: Icons.near_me_outlined,
                                color: const Color(0xFF7D9DFF),
                                selected:
                                    widget.route == ApplicationRoute.direct,
                                onPressed: () => widget.onRouteChanged(
                                  ApplicationRoute.direct,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _RouteButton(
                                label: 'Rules',
                                icon: Icons.alt_route_rounded,
                                color: const Color(0xFFFFB45C),
                                selected: widget.route == ApplicationRoute.rule,
                                onPressed: () => widget.onRouteChanged(
                                  ApplicationRoute.rule,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Bypass TUN',
                              onPressed: widget.onBypass,
                              icon: const Icon(
                                Icons.block_flipped,
                                color: Color(0xFF687485),
                                size: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _ApplicationDetailsDialog extends StatelessWidget {
  const _ApplicationDetailsDialog({
    required this.application,
    required this.route,
    required this.routeTarget,
    required this.traffic,
    required this.onRouteChanged,
  });

  final DiscoveredApplication application;
  final ApplicationRoute route;
  final String? routeTarget;
  final ApplicationTrafficData traffic;
  final ValueChanged<ApplicationRoute> onRouteChanged;

  Color get _accent => switch (route) {
        ApplicationRoute.proxy => const Color(0xFF62E6C5),
        ApplicationRoute.direct => const Color(0xFF7D9DFF),
        ApplicationRoute.rule => const Color(0xFFFFB45C),
      };

  String get _routeName => switch (route) {
        ApplicationRoute.proxy => routeTarget ?? 'Proxy',
        ApplicationRoute.direct => 'Direct',
        ApplicationRoute.rule => 'Rules',
      };

  @override
  Widget build(BuildContext context) {
    final connections = traffic.items.take(12).toList(growable: false);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: RouteXGlassSurface(
          radius: 28,
          blur: 18,
          ambientTint: true,
          shadowOffset: const Offset(0, 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
                child: Row(
                  children: [
                    _ApplicationIcon(
                      path: application.executablePath,
                      accent: _accent,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF4F7F8),
                              fontFamily: 'Unbounded',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${traffic.connections} live connections  •  PID ${application.pid}',
                            style: const TextStyle(
                              color: Color(0xFF7F8C9D),
                              fontFamily: 'JetBrainsMono',
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF8D99A8),
                      ),
                    ),
                  ],
                ),
              ),
              _RouteExplanation(
                routeName: _routeName,
                accent: _accent,
                connection: connections.firstOrNull,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                child: Row(
                  children: [
                    const Text(
                      'LIVE DESTINATIONS',
                      style: TextStyle(
                        color: Color(0xFF8491A1),
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '↓ ${TrafficValue(value: traffic.download).show}   ↑ ${TrafficValue(value: traffic.upload).show}',
                      style: const TextStyle(
                        color: Color(0xFF718092),
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: connections.isEmpty
                    ? const Center(
                        child: Text(
                          'No active network destinations',
                          style: TextStyle(
                            color: Color(0xFF718092),
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                        itemCount: connections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, index) => _ConnectionTile(
                          connection: connections[index],
                          accent: _accent,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xB3080C12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RouteButton(
                          label: routeTarget ?? 'Proxy',
                          icon: Icons.shield_outlined,
                          color: const Color(0xFF62E6C5),
                          selected: route == ApplicationRoute.proxy,
                          onPressed: () => onRouteChanged(
                            ApplicationRoute.proxy,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _RouteButton(
                          label: 'Direct',
                          icon: Icons.near_me_outlined,
                          color: const Color(0xFF7D9DFF),
                          selected: route == ApplicationRoute.direct,
                          onPressed: () => onRouteChanged(
                            ApplicationRoute.direct,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _RouteButton(
                          label: 'Rules',
                          icon: Icons.alt_route_rounded,
                          color: const Color(0xFFFFB45C),
                          selected: route == ApplicationRoute.rule,
                          onPressed: () => onRouteChanged(
                            ApplicationRoute.rule,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteExplanation extends StatelessWidget {
  const _RouteExplanation({
    required this.routeName,
    required this.accent,
    required this.connection,
  });

  final String routeName;
  final Color accent;
  final ApplicationConnectionData? connection;

  @override
  Widget build(BuildContext context) {
    final destination = connection?.destination ?? 'waiting for traffic';
    final chain = connection?.chain.reversed.join('  →  ') ?? routeName;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.13),
            accent.withValues(alpha: 0.035),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, color: accent, size: 17),
              const SizedBox(width: 8),
              const Text(
                'WHY THIS ROUTE',
                style: TextStyle(
                  color: Color(0xFFC7D0D9),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${applicationLabel(connection)}  →  $destination  →  $chain',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String applicationLabel(ApplicationConnectionData? connection) =>
      connection == null ? 'Application' : connection.network.toUpperCase();
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.connection, required this.accent});

  final ApplicationConnectionData connection;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE1E7EB),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${connection.network.toUpperCase()} :${connection.destinationPort}  •  ${connection.destinationIp}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF687789),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '↓ ${TrafficValue(value: connection.download).show}',
              style: const TextStyle(
                color: Color(0xFF8290A1),
                fontFamily: 'JetBrainsMono',
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
}

class _ApplicationIcon extends StatelessWidget {
  const _ApplicationIcon({required this.path, required this.accent});

  final String path;
  final Color accent;

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider?>(
        future: windowsExecutableIcon(path),
        builder: (_, snapshot) {
          final icon = snapshot.data;
          return Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.17),
                  const Color(0xFF151C26),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: icon == null
                ? Icon(Icons.apps_rounded, color: accent, size: 22)
                : Image(image: icon, gaplessPlayback: true),
          );
        },
      );
}

class _NetworkStatus extends StatelessWidget {
  const _NetworkStatus({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF62E6C5) : const Color(0xFF697587);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: online
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            online ? 'LIVE' : 'IDLE',
            style: TextStyle(
              color: color,
              fontFamily: 'JetBrainsMono',
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x87101720),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF778496),
            fontFamily: 'JetBrainsMono',
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9),
          hoverColor: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? color : const Color(0xFF697587),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? color : const Color(0xFF697587),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.padding,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => RouteXGlassSurface(
        radius: radius,
        blur: 16,
        expand: false,
        shadowOffset: const Offset(0, 14),
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 0.7;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.icon,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: Color(0xFF62E6C5),
                    strokeWidth: 2.5,
                  ),
                )
              else
                Icon(
                  icon ?? Icons.apps_rounded,
                  color: const Color(0xFF62E6C5),
                  size: 36,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF1F4F6),
                  fontFamily: 'Unbounded',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF748194),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}
