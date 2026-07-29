import 'package:app_discovery/app_discovery.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    required this.onRefresh,
    required this.onQueryChanged,
    required this.onRouteChanged,
    required this.onPickLocation,
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
  final VoidCallback onBypass;

  @override
  State<ApplicationsWorkspace> createState() => _ApplicationsWorkspaceState();
}

enum _ProcessFilter { all, online }

class _ApplicationsWorkspaceState extends State<ApplicationsWorkspace> {
  _ProcessFilter _filter = _ProcessFilter.all;

  int get _onlineCount =>
      widget.traffic.values.where((traffic) => traffic.connections > 0).length;

  @override
  Widget build(BuildContext context) {
    final visibleApplications = _filter == _ProcessFilter.all
        ? widget.applications
        : widget.applications.where((application) {
            final key = application.executablePath.toLowerCase();
            return (widget.traffic[key]?.connections ?? 0) > 0;
          }).toList(growable: false);
    final routes = widget.routes.values;
    final proxyCount =
        routes.where((item) => item.route == ApplicationRoute.proxy).length;
    final directCount =
        routes.where((item) => item.route == ApplicationRoute.direct).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceHeader(
            openCount: widget.allApplicationsCount,
            onlineCount: _onlineCount,
            refreshing: widget.refreshing,
          ),
          const SizedBox(height: 18),
          _Toolbar(
            filter: _filter,
            applicationsCount: widget.applications.length,
            proxyCount: proxyCount,
            directCount: directCount,
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
              onRetry: widget.onRefresh,
              onRouteChanged: widget.onRouteChanged,
              onPickLocation: widget.onPickLocation,
              onBypass: widget.onBypass,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.openCount,
    required this.onlineCount,
    required this.refreshing,
  });

  final int openCount;
  final int onlineCount;
  final bool refreshing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final isRussian =
              Localizations.localeOf(context).languageCode == 'ru';
          final compact = constraints.maxWidth < 620;
          final identity = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: context.colorScheme.outlineVariant
                        .withValues(alpha: 0.65),
                  ),
                ),
                child: const Icon(Icons.apps_rounded, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLocalizations.routeMode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          context.textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appLocalizations.applications,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final activity = refreshing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                )
              : const SizedBox();
          final stats = <Widget>[
            _HeaderStat(
              value: '$openCount',
              label: isRussian ? 'открыто' : 'open',
            ),
            const SizedBox(width: 8),
            _HeaderStat(
              value: '$onlineCount',
              label: isRussian ? 'в сети' : 'online',
              active: onlineCount > 0,
            ),
          ];
          if (compact) {
            return Column(
              children: [
                Row(children: [Expanded(child: identity), activity]),
                const SizedBox(height: 10),
                Row(children: stats),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              ...stats,
              const SizedBox(width: 10),
              activity,
            ],
          );
        },
      );
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.value,
    required this.label,
    this.active = false,
  });

  final String value;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Row(
          children: [
            if (active) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: premiumMint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filter,
    required this.applicationsCount,
    required this.proxyCount,
    required this.directCount,
    required this.onFilterChanged,
    required this.onQueryChanged,
  });

  final _ProcessFilter filter;
  final int applicationsCount;
  final int proxyCount;
  final int directCount;
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
              const Spacer(),
              _RouteSummary(
                color: premiumMint,
                label: 'Proxy',
                value: proxyCount,
              ),
              const SizedBox(width: 9),
              _RouteSummary(
                color: premiumBlue,
                label: 'Direct',
                value: directCount,
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

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: TextStyle(
              color: context.colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
    required this.onRetry,
    required this.onRouteChanged,
    required this.onPickLocation,
    required this.onBypass,
  });

  final bool supported;
  final bool loading;
  final Object? error;
  final List<DiscoveredApplication> applications;
  final Map<String, ApplicationRouteEntry> routes;
  final Map<String, ApplicationTrafficData> traffic;
  final Future<void> Function() onRetry;
  final Future<void> Function(
    DiscoveredApplication application,
    ApplicationRoute route,
  ) onRouteChanged;
  final Future<void> Function(
    DiscoveredApplication application,
    String target,
  ) onPickLocation;
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
          onRouteChanged: (route) => onRouteChanged(application, route),
          onPickLocation: (target) => onPickLocation(application, target),
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
    required this.onRouteChanged,
    required this.onPickLocation,
    required this.onBypass,
  });

  final DiscoveredApplication application;
  final ApplicationRoute route;
  final String? routeTarget;
  final ApplicationTrafficData traffic;
  final ValueChanged<ApplicationRoute> onRouteChanged;
  final ValueChanged<String> onPickLocation;
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
                    final controls = _RouteControl(
                      route: widget.route,
                      routeTarget: widget.routeTarget,
                      onChanged: widget.onRouteChanged,
                      onPickLocation: widget.onPickLocation,
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: identity),
                              _ExpandButton(expanded: _expanded),
                            ],
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: _RouteControl(
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
              duration: const Duration(milliseconds: 180),
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

class _RouteControl extends StatelessWidget {
  const _RouteControl({
    this.width = 300,
    required this.route,
    required this.routeTarget,
    required this.onChanged,
    required this.onPickLocation,
  });

  final ApplicationRoute route;
  final String? routeTarget;
  final ValueChanged<ApplicationRoute> onChanged;
  // Experimental: routes this one application through a specific proxy
  // group instead of whichever one is the default — e.g. a browser on
  // one location, a game on another. Tapping the already-selected Proxy
  // slot a second time opens the picker instead of re-selecting it, so
  // no extra control is squeezed into an already tight 44px bar.
  final ValueChanged<String> onPickLocation;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLowest
              .withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CommonPopupBox(
                targetBuilder: (open) => Tooltip(
                  message: route == ApplicationRoute.proxy
                      ? 'Нажмите ещё раз, чтобы выбрать локацию'
                      : '',
                  child: _RouteOption(
                    label: routeTarget ?? 'Proxy',
                    selected: route == ApplicationRoute.proxy,
                    color: premiumMint,
                    onPressed: () {
                      if (route == ApplicationRoute.proxy) {
                        open(offset: const Offset(0, 8));
                      } else {
                        onChanged(ApplicationRoute.proxy);
                      }
                    },
                  ),
                ),
                popup: _LocationPickerPanel(
                  currentTarget: routeTarget,
                  onPicked: onPickLocation,
                ),
              ),
            ),
            Expanded(
              child: _RouteOption(
                label: 'Direct',
                selected: route == ApplicationRoute.direct,
                color: premiumBlue,
                onPressed: () => onChanged(ApplicationRoute.direct),
              ),
            ),
            Expanded(
              child: _RouteOption(
                label: 'Rules',
                selected: route == ApplicationRoute.rule,
                color: premiumAmber,
                onPressed: () => onChanged(ApplicationRoute.rule),
              ),
            ),
          ],
        ),
      );
}

/// The per-app location picker's popup body — opened from the Proxy slot
/// of an already-proxied app. Lists every non-hidden proxy group the
/// active profile exposes (the same "locations" the Локации tab lets you
/// switch between), plus an Auto row that clears the explicit pick and
/// falls back to whatever the default proxy group resolves to.
class _LocationPickerPanel extends ConsumerWidget {
  const _LocationPickerPanel({
    required this.currentTarget,
    required this.onPicked,
  });

  final String? currentTarget;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref
        .watch(currentGroupsStateProvider)
        .value
        .where((group) => group.hidden != true)
        .toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 360),
        child: RouteXGlassSurface(
          variant: RouteXGlassVariant.panel,
          radius: 16,
          expand: false,
          child: groups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Нет доступных локаций в этом профиле',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(6),
                  children: [
                    for (final group in groups)
                      _LocationOption(
                        label: group.name,
                        subtitle: group.now,
                        icon: group.icon,
                        selected: group.name == currentTarget,
                        onTap: () {
                          Navigator.of(context).pop();
                          onPicked(group.name);
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: selected
                ? premiumMint.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              CommonTargetIcon(src: icon, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? premiumMint
                            : context.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 16, color: premiumMint),
            ],
          ),
        ),
      );
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          backgroundColor:
              selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          foregroundColor:
              selected ? color : context.colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
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
        ApplicationRoute.proxy => routeTarget ?? 'Proxy',
        ApplicationRoute.direct => 'Direct',
        ApplicationRoute.rule => 'Profile rules',
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
