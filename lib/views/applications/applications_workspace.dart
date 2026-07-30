import 'package:app_discovery/app_discovery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/process_icon.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'applications_scene.dart';

// Windows' Segoe UI Emoji renders regional-indicator flag emoji as bare
// two-letter text instead of a flag glyph, so a raw "🇨🇭 Switzerland" proxy
// name shows as "CH Switzerland" — these mirror hero_connect.dart's helpers
// to parse the ISO code out and render a real flag image instead.
String? _locationFlagCode(String text) {
  final runes = text.runes.toList();
  for (var i = 0; i < runes.length - 1; i++) {
    final a = runes[i];
    final b = runes[i + 1];
    if (a >= 0x1F1E6 && a <= 0x1F1FF && b >= 0x1F1E6 && b <= 0x1F1FF) {
      final c1 = a - 0x1F1E6 + 0x41;
      final c2 = b - 0x1F1E6 + 0x41;
      return String.fromCharCodes([c1, c2]);
    }
  }
  return null;
}

String _stripLocationFlagPrefix(String text) {
  bool isEmojiRune(int r) {
    final isFlag = r >= 0x1F1E6 && r <= 0x1F1FF;
    final isModifier =
        r == 0x200D || r == 0xFE0F || (r >= 0x1F3FB && r <= 0x1F3FF);
    final isPictograph = (r >= 0x1F000 && r <= 0x1FAFF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x2190 && r <= 0x21FF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0x2300 && r <= 0x23FF);
    return isFlag || isModifier || isPictograph;
  }

  bool isSpace(int r) =>
      r == 0x20 || r == 0x09 || r == 0xA0 || r == 0x0A || r == 0x0D;

  final runes = text.runes.toList();
  var start = 0;
  while (start < runes.length &&
      (isEmojiRune(runes[start]) || isSpace(runes[start]))) {
    start++;
  }
  return String.fromCharCodes(runes.sublist(start))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

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
                  message: route != ApplicationRoute.direct
                      ? 'Нажмите ещё раз, чтобы выбрать локацию'
                      : '',
                  child: _RouteOption(
                    label: routeTarget == null
                        ? 'Proxy'
                        : _stripLocationFlagPrefix(routeTarget!),
                    selected: route != ApplicationRoute.direct,
                    color: premiumMint,
                    onPressed: () {
                      if (route != ApplicationRoute.direct) {
                        open(offset: const Offset(0, 8));
                      } else {
                        onChanged(ApplicationRoute.proxy);
                      }
                    },
                  ),
                ),
                popup: _LocationPickerPanel(
                  currentTarget: routeTarget,
                  isDefault: route == ApplicationRoute.rule,
                  onPicked: onPickLocation,
                  onClear: () => onChanged(ApplicationRoute.rule),
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
          ],
        ),
      );
}

/// The per-app location picker's popup body — opened from the Proxy slot
/// of an already-proxied app. Two levels: each non-hidden proxy group the
/// active profile exposes as a header, and — because Clash's
/// PROCESS-PATH rule target accepts a leaf server name exactly as well
/// as a group name — every member of that group listed underneath as
/// its own selectable location. A profile with one selector group and
/// eight countries inside it shows all eight, not just the one selector.
class _LocationPickerPanel extends ConsumerWidget {
  const _LocationPickerPanel({
    required this.currentTarget,
    required this.isDefault,
    required this.onPicked,
    required this.onClear,
  });

  final String? currentTarget;
  // True when the app currently has no pinned location (plain "follow the
  // profile's rules" state) — highlights the "По умолчанию" row instead.
  final bool isDefault;
  final ValueChanged<String> onPicked;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref
        .watch(currentGroupsStateProvider)
        .value
        .where((group) => group.hidden != true)
        .toList(growable: false);

    void pick(String target) {
      Navigator.of(context).pop();
      onPicked(target);
    }

    void clear() {
      Navigator.of(context).pop();
      onClear();
    }

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
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
                    _LocationOption(
                      label: 'По умолчанию',
                      subtitle: 'Следовать правилам профиля',
                      icon: '',
                      selected: isDefault,
                      onTap: clear,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(height: 1),
                    ),
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // The group itself, selectable as "let this group
                      // auto-pick" rather than pinning one member of it.
                      _LocationOption(
                        label: _stripLocationFlagPrefix(group.name),
                        subtitle: group.now,
                        icon: group.icon,
                        selected: group.name == currentTarget,
                        onTap: () => pick(group.name),
                      ),
                      for (final proxy in group.all)
                        _LocationOption(
                          label: _stripLocationFlagPrefix(proxy.name),
                          subtitle: null,
                          icon: '',
                          flagCode: _locationFlagCode(proxy.name),
                          indent: true,
                          selected: proxy.name == currentTarget,
                          onTap: () => pick(proxy.name),
                        ),
                    ],
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
    this.indent = false,
    this.flagCode,
  });

  final String label;
  final String? subtitle;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
  // Leaf proxies nested under a group header: pushed in and given a small
  // flag (or a plain dot when no flag could be parsed) instead of the
  // group's own icon, so the hierarchy reads at a glance.
  final bool indent;
  final String? flagCode;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(indent ? 22 : 8, 8, 8, 8),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: selected
                ? premiumMint.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              indent
                  ? _LocationFlag(code: flagCode, selected: selected)
                  : CommonTargetIcon(src: icon, size: 24),
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

class _LocationFlag extends StatelessWidget {
  const _LocationFlag({required this.code, required this.selected});

  final String? code;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    final cc = code?.trim().toLowerCase();
    Widget dot() => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? premiumMint
                : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        );
    if (cc == null || cc.length != 2) return dot();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: 'https://flagcdn.com/w40/$cc.png',
        width: size,
        height: size * 0.75,
        fit: BoxFit.cover,
        placeholder: (_, __) => SizedBox(width: size, height: size * 0.75),
        errorWidget: (_, __, ___) => dot(),
      ),
    );
  }
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
        ApplicationRoute.proxy =>
          routeTarget == null ? 'Proxy' : _stripLocationFlagPrefix(routeTarget!),
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
