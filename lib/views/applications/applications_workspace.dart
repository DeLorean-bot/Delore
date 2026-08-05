import 'package:app_discovery/app_discovery.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'applications_scene.dart';

class ApplicationsWorkspace extends StatefulWidget {
  const ApplicationsWorkspace({
    super.key,
    required this.supported,
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.allApplicationsCount,
    required this.applications,
    required this.routes,
    required this.traffic,
    required this.favorites,
    required this.onRefresh,
    required this.onQueryChanged,
    required this.onRouteChanged,
    required this.onPickLocation,
    required this.onToggleFavorite,
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
  final Set<String> favorites;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function(
    DiscoveredApplication application,
    ApplicationRoute route,
  ) onRouteChanged;
  // Routes an application through a specific proxy group/location instead
  // of the default one — the experimental per-app location picker.
  final Future<void> Function(
    DiscoveredApplication application,
    String target,
  ) onPickLocation;
  final Future<void> Function(DiscoveredApplication application)
      onToggleFavorite;
  final VoidCallback onBypass;

  @override
  State<ApplicationsWorkspace> createState() => _ApplicationsWorkspaceState();
}

enum _ProcessFilter { all, online }

class _ApplicationsWorkspaceState extends State<ApplicationsWorkspace> {
  _ProcessFilter _filter = _ProcessFilter.all;

  @override
  Widget build(BuildContext context) {
    final visibleApplications = _filter == _ProcessFilter.all
        ? widget.applications
        : widget.applications.where((application) {
            final key = application.executablePath.toLowerCase();
            return (widget.traffic[key]?.connections ?? 0) > 0;
          }).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(
            filter: _filter,
            applicationsCount: widget.applications.length,
            onFilterChanged: (value) => setState(() => _filter = value),
            onQueryChanged: widget.onQueryChanged,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _ProcessList(
              supported: widget.supported,
              loading: widget.loading,
              error: widget.error,
              applications: visibleApplications,
              routes: widget.routes,
              traffic: widget.traffic,
              favorites: widget.favorites,
              onRetry: widget.onRefresh,
              onRouteChanged: widget.onRouteChanged,
              onPickLocation: widget.onPickLocation,
              onToggleFavorite: widget.onToggleFavorite,
              onBypass: widget.onBypass,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filter,
    required this.applicationsCount,
    required this.onFilterChanged,
    required this.onQueryChanged,
  });

  final _ProcessFilter filter;
  final int applicationsCount;
  final ValueChanged<_ProcessFilter> onFilterChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final isRussian =
              Localizations.localeOf(context).languageCode == 'ru';
          final compact = constraints.maxWidth < 650;
          final search = SizedBox(
            height: 44,
            child: TextField(
              onChanged: onQueryChanged,
              style: const TextStyle(
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: isRussian
                    ? 'Поиск по названию, окну или файлу'
                    : 'Search name, window or executable',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          );
          final filters = Row(
            children: [
              _FilterButton(
                label: isRussian ? 'Все' : 'All',
                count: applicationsCount,
                selected: filter == _ProcessFilter.all,
                onPressed: () => onFilterChanged(_ProcessFilter.all),
              ),
              const SizedBox(width: 5),
              _FilterButton(
                label: isRussian ? 'В сети' : 'Online',
                selected: filter == _ProcessFilter.online,
                onPressed: () => onFilterChanged(_ProcessFilter.online),
              ),
            ],
          );
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerLow
                  .withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.52),
              ),
            ),
            child: compact
                ? Column(
                    children: [
                      search,
                      const SizedBox(height: 7),
                      filters,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 8),
                      SizedBox(width: 330, child: filters),
                    ],
                  ),
          );
        },
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: selected
              ? context.colorScheme.surfaceContainerHighest
              : Colors.transparent,
          foregroundColor: selected
              ? context.colorScheme.onSurface
              : context.colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          count == null ? label : '$label  $count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _ProcessList extends StatelessWidget {
  const _ProcessList({
    required this.supported,
    required this.loading,
    required this.error,
    required this.applications,
    required this.routes,
    required this.traffic,
    required this.favorites,
    required this.onRetry,
    required this.onRouteChanged,
    required this.onPickLocation,
    required this.onToggleFavorite,
    required this.onBypass,
  });

  final bool supported;
  final bool loading;
  final Object? error;
  final List<DiscoveredApplication> applications;
  final Map<String, ApplicationRouteEntry> routes;
  final Map<String, ApplicationTrafficData> traffic;
  final Set<String> favorites;
  final Future<void> Function() onRetry;
  final Future<void> Function(
    DiscoveredApplication application,
    ApplicationRoute route,
  ) onRouteChanged;
  final Future<void> Function(
    DiscoveredApplication application,
    String target,
  ) onPickLocation;
  final Future<void> Function(DiscoveredApplication application)
      onToggleFavorite;
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    if (!supported) {
      return const _StatusPanel(
        icon: Icons.desktop_windows_rounded,
        title: 'Application discovery is Windows-only',
      );
    }
    if (loading && applications.isEmpty) {
      return const _StatusPanel(
        loading: true,
        title: 'Scanning open applications',
      );
    }
    if (error != null && applications.isEmpty) {
      return _StatusPanel(
        icon: Icons.sync_problem_rounded,
        title: 'Application discovery paused',
        detail: '$error',
        action: onRetry,
      );
    }
    if (applications.isEmpty) {
      return const _StatusPanel(
        icon: Icons.search_off_rounded,
        title: 'No matching applications',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: applications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, index) {
        final application = applications[index];
        final key = application.executablePath.toLowerCase();
        return _ProcessRow(
          key: ValueKey(application.pid),
          application: application,
          route: routes[key]?.route ?? ApplicationRoute.rule,
          routeTarget: routes[key]?.target,
          traffic: traffic[key] ?? const ApplicationTrafficData(),
          favorite: favorites.contains(key),
          onRouteChanged: (route) => onRouteChanged(application, route),
          onPickLocation: (target) => onPickLocation(application, target),
          onToggleFavorite: () => onToggleFavorite(application),
          onBypass: onBypass,
        );
      },
    );
  }
}

class _ProcessRow extends StatefulWidget {
  const _ProcessRow({
    super.key,
    required this.application,
    required this.route,
    required this.routeTarget,
    required this.traffic,
    required this.favorite,
    required this.onRouteChanged,
    required this.onPickLocation,
    required this.onToggleFavorite,
    required this.onBypass,
  });

  final DiscoveredApplication application;
  final ApplicationRoute route;
  final String? routeTarget;
  final ApplicationTrafficData traffic;
  final bool favorite;
  final ValueChanged<ApplicationRoute> onRouteChanged;
  final ValueChanged<String> onPickLocation;
  final VoidCallback onToggleFavorite;
  final VoidCallback onBypass;

  @override
  State<_ProcessRow> createState() => _ProcessRowState();
}

class _ProcessRowState extends State<_ProcessRow> {
  bool _expanded = false;
  bool _hovered = false;

  Color get _routeColor => switch (widget.route) {
        ApplicationRoute.proxy => premiumMint,
        ApplicationRoute.direct => premiumBlue,
        ApplicationRoute.rule => premiumAmber,
      };

  @override
  Widget build(BuildContext context) {
    final online = widget.traffic.connections > 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow.withValues(
            alpha: _hovered ? 0.82 : 0.64,
          ),
          borderRadius: BorderRadius.circular(RouteXRadius.card),
          border: Border.all(
            color: _hovered
                ? context.colorScheme.outline.withValues(alpha: 0.65)
                : context.colorScheme.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(RouteXRadius.card),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 600;
                    final compact = constraints.maxWidth < 940;
                    final identity = _ProcessIdentity(
                      application: widget.application,
                      online: online,
                      connections: widget.traffic.connections,
                    );
                    final controls = ProxyRouteControl(
                      route: widget.route,
                      routeTarget: widget.routeTarget,
                      onChanged: widget.onRouteChanged,
                      onPickLocation: widget.onPickLocation,
                    );
                    final favoriteButton = IconButton(
                      tooltip: widget.favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: widget.onToggleFavorite,
                      icon: Icon(
                        widget.favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: widget.favorite ? premiumAmber : null,
                      ),
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: identity),
                              favoriteButton,
                              _ExpandButton(expanded: _expanded),
                            ],
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: ProxyRouteControl(
                                  width: double.infinity,
                                  route: widget.route,
                                  routeTarget: widget.routeTarget,
                                  onChanged: widget.onRouteChanged,
                                  onPickLocation: widget.onPickLocation,
                                ),
                              ),
                              const SizedBox(width: 3),
                              IconButton(
                                tooltip: 'Bypass TUN',
                                onPressed: widget.onBypass,
                                icon: const Icon(Icons.shield_outlined),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    if (compact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: identity),
                              favoriteButton,
                              _ExpandButton(expanded: _expanded),
                            ],
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              _TrafficLabel(traffic: widget.traffic),
                              const Spacer(),
                              controls,
                              IconButton(
                                tooltip: 'Bypass TUN',
                                onPressed: widget.onBypass,
                                icon: const Icon(Icons.shield_outlined),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: identity),
                        _TrafficLabel(traffic: widget.traffic),
                        const SizedBox(width: 20),
                        controls,
                        const SizedBox(width: 4),
                        favoriteButton,
                        IconButton(
                          tooltip: 'Bypass TUN',
                          onPressed: widget.onBypass,
                          icon: const Icon(Icons.shield_outlined),
                        ),
                        _ExpandButton(expanded: _expanded),
                      ],
                    );
                  },
                ),
              ),
            ),
            AnimatedCrossFade(
              duration:
                  RouteXMotion.resolve(context, const Duration(milliseconds: 180)),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _ConnectionDetails(
                application: widget.application,
                traffic: widget.traffic,
                routeColor: _routeColor,
                route: widget.route,
                routeTarget: widget.routeTarget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessIdentity extends StatelessWidget {
  const _ProcessIdentity({
    required this.application,
    required this.online,
    required this.connections,
  });

  final DiscoveredApplication application;
  final bool online;
  final int connections;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _ExecutableIcon(path: application.executablePath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        application.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OnlineBadge(
                      online: online,
                      connections: connections,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${p.basename(application.executablePath)}   PID ${application.pid}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                if (application.windowTitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    application.windowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

class _ExecutableIcon extends StatelessWidget {
  const _ExecutableIcon({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider?>(
        future: windowsExecutableIcon(path),
        builder: (_, snapshot) => Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.62),
            ),
          ),
          child: snapshot.data == null
              ? const Icon(Icons.window_rounded, size: 20)
              : Image(image: snapshot.data!, fit: BoxFit.contain),
        ),
      );
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.online, required this.connections});

  final bool online;
  final int connections;

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: online
            ? premiumMint.withValues(alpha: 0.1)
            : context.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        online
            ? '$connections ${isRussian ? 'в сети' : 'online'}'
            : (isRussian ? 'неактивно' : 'idle'),
        style: TextStyle(
          color: online ? premiumMint : context.colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _TrafficLabel extends StatelessWidget {
  const _TrafficLabel({required this.traffic});

  final ApplicationTrafficData traffic;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '↓ ${TrafficValue(value: traffic.download).show}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '↑ ${TrafficValue(value: traffic.upload).show}',
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 160),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 19,
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
}

class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({
    required this.application,
    required this.traffic,
    required this.routeColor,
    required this.route,
    required this.routeTarget,
  });

  final DiscoveredApplication application;
  final ApplicationTrafficData traffic;
  final Color routeColor;
  final ApplicationRoute route;
  final String? routeTarget;

  String get _routeName => switch (route) {
        ApplicationRoute.proxy =>
          routeTarget == null ? 'Proxy' : stripLocationFlagPrefix(routeTarget!),
        ApplicationRoute.direct => 'Direct',
        ApplicationRoute.rule => 'По умолчанию',
      };

  @override
  Widget build(BuildContext context) {
    final connections = traffic.items.take(5).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'ROUTE TRACE',
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${p.basename(application.executablePath)}  →  $_routeName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: routeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (connections.isEmpty)
            Text(
              'No active destinations',
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: connections
                  .map(
                    (connection) => _DestinationChip(
                      connection: connection,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _DestinationChip extends StatelessWidget {
  const _DestinationChip({required this.connection});

  final ApplicationConnectionData connection;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
              context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: premiumMint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '${connection.destination}:${connection.destinationPort}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    this.icon,
    this.detail,
    this.loading = false,
    this.action,
  });

  final String title;
  final IconData? icon;
  final String? detail;
  final bool loading;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color:
                context.colorScheme.surfaceContainerLow.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.52),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(strokeWidth: 2)
              else
                Icon(icon, size: 24),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: 7),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: action,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      );
}
