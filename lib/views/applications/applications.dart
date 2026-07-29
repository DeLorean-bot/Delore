import 'dart:async';
import 'dart:io';

import 'package:app_discovery/app_discovery.dart';
import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'applications_scene.dart';
import 'applications_workspace.dart';

class ApplicationsView extends ConsumerStatefulWidget {
  const ApplicationsView({super.key});

  @override
  ConsumerState<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends ConsumerState<ApplicationsView>
    with PageMixin, WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = false;
  bool _loading = true;
  bool _refreshing = false;
  String _query = '';
  Object? _error;
  List<DiscoveredApplication> _applications = const [];
  Map<String, ApplicationRouteEntry> _routes = const {};
  Map<String, _ApplicationTraffic> _traffic = const {};

  @override
  List<Widget> get actions => [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      isCurrentPageProvider(PageLabel.applications),
      (_, next) {
        _visible = next;
        _syncPolling();
        if (_visible) initPageState();
      },
      fireImmediately: true,
    );
  }

  void _syncPolling() {
    _timer?.cancel();
    _timer = null;
    if (_visible) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    if (!Platform.isWindows) {
      if (mounted) setState(() => _loading = false);
      _refreshing = false;
      return;
    }
    try {
      final applicationsFuture = AppDiscovery.getOpenApplications();
      final connectionsFuture = _loadConnections();
      final results = await Future.wait<Object>([
        applicationsFuture,
        connectionsFuture,
      ]);
      final applications = results[0] as List<DiscoveredApplication>;
      final connections = results[1] as List<Connection>;
      final profileId = ref.read(currentProfileIdProvider);
      final routes = profileId == null
          ? <String, ApplicationRouteEntry>{}
          : await ApplicationRoutingStore.load(profileId);
      final traffic = <String, _ApplicationTraffic>{};
      for (final connection in connections) {
        final executablePath = connectionProcessPaths[connection.id];
        if (executablePath == null || executablePath.isEmpty) continue;
        final key = executablePath.toLowerCase();
        final current = traffic[key] ?? const _ApplicationTraffic();
        traffic[key] = _ApplicationTraffic(
          upload: current.upload + (connection.upload?.toInt() ?? 0),
          download: current.download + (connection.download?.toInt() ?? 0),
          connections: current.connections + 1,
          items: [
            ...current.items,
            ApplicationConnectionData(
              host: connection.metadata.host,
              destinationIp: connection.metadata.destinationIP,
              destinationPort: connection.metadata.destinationPort,
              network: connection.metadata.network,
              chain: connection.chains,
              upload: connection.upload?.toInt() ?? 0,
              download: connection.download?.toInt() ?? 0,
            ),
          ],
        );
      }
      if (!mounted) return;
      setState(() {
        _applications = applications;
        _routes = routes;
        _traffic = traffic;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    } finally {
      _refreshing = false;
      if (mounted && _visible) {
        _timer = Timer(const Duration(seconds: 2), _refresh);
      }
    }
  }

  Future<List<Connection>> _loadConnections() async {
    try {
      return await clashCore.getConnections();
    } catch (_) {
      return const [];
    }
  }

  String? _defaultProxyTarget() {
    final groups = globalState.lastRuntimeConfig?['proxy-groups'];
    if (groups is! List) return null;
    final names = groups
        .whereType<Map>()
        .map((group) => group['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    for (final preferred in ['Proxy', 'PROXY', 'GLOBAL']) {
      for (final name in names) {
        if (name.toLowerCase() == preferred.toLowerCase()) return name;
      }
    }
    return names.firstOrNull;
  }

  /// Routes [application] through a specific location instead of the
  /// default proxy group — the per-app location picker's entry point.
  Future<void> _setLocation(
    DiscoveredApplication application,
    String target,
  ) =>
      _setRoute(application, ApplicationRoute.proxy, explicitTarget: target);

  Future<void> _setRoute(
    DiscoveredApplication application,
    ApplicationRoute route, {
    String? explicitTarget,
  }) async {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) {
      _message('Add or select a profile first');
      return;
    }
    String? target;
    if (route == ApplicationRoute.proxy) {
      target = explicitTarget ?? _defaultProxyTarget();
      if (target == null) {
        _message('No proxy group is available in the active profile');
        return;
      }
    } else if (route == ApplicationRoute.direct) {
      target = 'DIRECT';
    }

    final key = application.executablePath.toLowerCase();
    final previous = _routes[key];
    final entry = ApplicationRouteEntry(
      executablePath: application.executablePath,
      route: route,
      target: target,
    );
    setState(() {
      final routes = Map<String, ApplicationRouteEntry>.from(_routes);
      if (route == ApplicationRoute.rule) {
        routes.remove(key);
      } else {
        routes[key] = entry;
      }
      _routes = routes;
    });

    try {
      await ApplicationRoutingStore.set(profileId, entry);
      await globalState.appController.applyProfile();
      if (mounted) {
        final routeLabel = switch (route) {
          ApplicationRoute.proxy => 'Proxy',
          ApplicationRoute.direct => appLocalizations.direct,
          ApplicationRoute.rule => appLocalizations.rule,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${application.name} → $routeLabel'),
              action: SnackBarAction(
                label: appLocalizations.undo,
                onPressed: () {
                  unawaited(
                    _restoreRoute(
                      profileId: profileId,
                      application: application,
                      previous: previous,
                    ),
                  );
                },
              ),
            ),
          );
      }
    } catch (error) {
      final rollback = previous ??
          ApplicationRouteEntry(
            executablePath: application.executablePath,
            route: ApplicationRoute.rule,
          );
      await ApplicationRoutingStore.set(profileId, rollback);
      if (mounted) {
        setState(() {
          final routes = Map<String, ApplicationRouteEntry>.from(_routes);
          if (previous == null) {
            routes.remove(key);
          } else {
            routes[key] = previous;
          }
          _routes = routes;
        });
      }
      _message('Could not apply route: $error');
    }
  }

  Future<void> _restoreRoute({
    required String profileId,
    required DiscoveredApplication application,
    required ApplicationRouteEntry? previous,
  }) async {
    final key = application.executablePath.toLowerCase();
    final rollback = previous ??
        ApplicationRouteEntry(
          executablePath: application.executablePath,
          route: ApplicationRoute.rule,
        );
    try {
      await ApplicationRoutingStore.set(profileId, rollback);
      await globalState.appController.applyProfile();
      if (!mounted) return;
      setState(() {
        final routes = Map<String, ApplicationRouteEntry>.from(_routes);
        if (previous == null) {
          routes.remove(key);
        } else {
          routes[key] = previous;
        }
        _routes = routes;
      });
    } catch (error) {
      _message('Could not undo route: $error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPolling();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applications = _applications.where((application) {
      if (_query.isEmpty) return true;
      return application.name.toLowerCase().contains(_query) ||
          application.windowTitle.toLowerCase().contains(_query) ||
          application.executablePath.toLowerCase().contains(_query);
    }).toList(growable: false);
    return ApplicationsWorkspace(
      supported: Platform.isWindows,
      loading: _loading,
      refreshing: _refreshing,
      error: _error,
      allApplicationsCount: _applications.length,
      applications: applications,
      routes: _routes,
      traffic: {
        for (final entry in _traffic.entries)
          entry.key: ApplicationTrafficData(
            upload: entry.value.upload,
            download: entry.value.download,
            connections: entry.value.connections,
            items: entry.value.items,
          ),
      },
      onRefresh: _refresh,
      onQueryChanged: (value) {
        setState(() => _query = value.trim().toLowerCase());
      },
      onRouteChanged: _setRoute,
      onPickLocation: _setLocation,
      onBypass: () => _message(
        'True TUN bypass needs a Windows WFP split-tunnel layer. '
        'Use Direct for a Clash DIRECT rule.',
      ),
    );
  }
}

class _ApplicationTraffic {
  const _ApplicationTraffic({
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

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
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
  final _ApplicationTraffic traffic;
  final ValueChanged<ApplicationRoute> onRouteChanged;
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ApplicationIcon(path: application.executablePath),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          application.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _NetworkStatus(online: traffic.connections > 0),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    application.windowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoChip(label: 'PID ${application.pid}'),
                      _InfoChip(label: p.basename(application.executablePath)),
                      if (traffic.connections > 0) ...[
                        _InfoChip(
                          label:
                              '↓ ${TrafficValue(value: traffic.download).show}',
                        ),
                        _InfoChip(
                          label:
                              '↑ ${TrafficValue(value: traffic.upload).show}',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RouteButton(
                        label: routeTarget ?? 'Proxy',
                        selected: route == ApplicationRoute.proxy,
                        onPressed: () => onRouteChanged(ApplicationRoute.proxy),
                      ),
                      _RouteButton(
                        label: 'Direct',
                        selected: route == ApplicationRoute.direct,
                        onPressed: () =>
                            onRouteChanged(ApplicationRoute.direct),
                      ),
                      _RouteButton(
                        label: 'Rule',
                        selected: route == ApplicationRoute.rule,
                        onPressed: () => onRouteChanged(ApplicationRoute.rule),
                      ),
                      _RouteButton(
                        label: 'Bypass',
                        selected: false,
                        onPressed: onBypass,
                      ),
                    ],
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

class _ApplicationIcon extends StatelessWidget {
  const _ApplicationIcon({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: windowsExecutableIcon(path),
      builder: (_, snapshot) {
        final icon = snapshot.data;
        return Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: icon == null
              ? Icon(
                  Icons.apps_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                )
              : Image(image: icon, gaplessPlayback: true),
        );
      },
    );
  }
}

class _NetworkStatus extends StatelessWidget {
  const _NetworkStatus({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.green : context.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          online ? 'Online' : 'Idle',
          style: context.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: context.textTheme.labelSmall),
    );
  }
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label),
          )
        : FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label),
          );
  }
}
