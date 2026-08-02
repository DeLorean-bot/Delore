import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/services/browser_bridge_service.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class BrowserTabsBody extends ConsumerStatefulWidget {
  const BrowserTabsBody({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<BrowserTabsBody> createState() => _BrowserTabsBodyState();
}

class _BrowserTabsBodyState extends ConsumerState<BrowserTabsBody> {
  StreamSubscription<List<BrowserTabInfo>>? _subscription;
  List<BrowserTabInfo> _tabs = const [];
  List<DomainRouteEntry> _routes = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = browserBridge.tabs;
    _subscription = browserBridge.stream.listen((tabs) {
      if (mounted) setState(() => _tabs = tabs);
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BrowserTabsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) unawaited(_load());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final profileId = ref.read(currentProfileIdProvider);
    final routes = profileId == null
        ? <DomainRouteEntry>[]
        : await DomainRoutingStore.load(profileId);
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _tabs = browserBridge.tabs;
    });
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

  DomainRouteEntry? _routeFor(String domain) {
    for (final route in _routes) {
      if (route.domain == domain) return route;
    }
    return null;
  }

  Future<void> _setRoute(
    BrowserTabInfo tab,
    ApplicationRoute route, {
    String? explicitTarget,
  }) async {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) {
      context.showSnackBar('Add or select a profile first');
      return;
    }
    final previous = _routeFor(tab.domain);
    if (route == ApplicationRoute.rule) {
      await DomainRoutingStore.remove(profileId, tab.domain);
      setState(() => _routes = _routes
          .where((entry) => entry.domain != tab.domain)
          .toList(growable: false));
    } else {
      final target = route == ApplicationRoute.direct
          ? 'DIRECT'
          : explicitTarget ?? previous?.target ?? _defaultProxyTarget();
      if (target == null) {
        context
            .showSnackBar('No proxy group is available in the active profile');
        return;
      }
      final entry = DomainRouteEntry(
        domain: tab.domain,
        route: route,
        target: target,
        favorite: previous?.favorite ?? false,
      );
      await DomainRoutingStore.set(profileId, entry);
      setState(() {
        _routes = [
          for (final current in _routes)
            if (current.domain != tab.domain) current,
          entry,
        ];
      });
    }
    await globalState.appController.applyProfile();
    if (mounted) {
      context.showSnackBar('${tab.domain} route updated for every browser tab');
    }
  }

  Future<void> _openExtensionFolder(String browser) async {
    final relative = p.join('assets', 'browser_extension', browser);
    final packaged = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      relative,
    );
    final directory = Directory(await Directory(packaged).exists()
        ? packaged
        : p.join(Directory.current.path, relative));
    if (Platform.isWindows) {
      await Process.run('explorer', [directory.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [directory.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [directory.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentProfileIdProvider, (previous, next) {
      if (previous != next) unawaited(_load());
    });
    final now = DateTime.now();
    final connected = _tabs.any(
      (tab) => now.difference(tab.lastSeen) < const Duration(seconds: 50),
    );
    final tabs = _tabs.where((tab) {
      if (_query.isEmpty) return true;
      return tab.title.toLowerCase().contains(_query) ||
          tab.domain.toLowerCase().contains(_query) ||
          tab.browser.toLowerCase().contains(_query);
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      child: Column(
        children: [
          _BridgeHeader(
            connected: connected,
            onQueryChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            onOpenChromium: () => _openExtensionFolder('chromium'),
            onOpenFirefox: () => _openExtensionFolder('firefox'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: tabs.isEmpty
                ? connected
                    ? const NullStatus(
                        label: 'No tabs match the current search',
                      )
                    : _SetupGuide(
                        onOpenChromium: () => _openExtensionFolder('chromium'),
                        onOpenFirefox: () => _openExtensionFolder('firefox'),
                      )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      final tab = tabs[index];
                      final entry = _routeFor(tab.domain);
                      return _BrowserTabRow(
                        key: ValueKey(tab.id),
                        tab: tab,
                        route: entry?.route ?? ApplicationRoute.rule,
                        routeTarget: entry?.target,
                        onRouteChanged: (route) => _setRoute(tab, route),
                        onPickLocation: (target) => _setRoute(
                          tab,
                          ApplicationRoute.proxy,
                          explicitTarget: target,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SetupGuide extends StatelessWidget {
  const _SetupGuide({
    required this.onOpenChromium,
    required this.onOpenFirefox,
  });

  final VoidCallback onOpenChromium;
  final VoidCallback onOpenFirefox;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: RouteXGlassSurface(
            variant: RouteXGlassVariant.panel,
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tab_rounded, size: 26),
                      SizedBox(width: 12),
                      Text(
                        'Connect your browser',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SetupStep(
                    number: '1',
                    text: 'Install Delore Browser Bridge for your browser.',
                  ),
                  const _SetupStep(
                    number: '2',
                    text:
                        'For a local Chromium install, open the extensions page, enable Developer mode and choose Load unpacked.',
                  ),
                  const _SetupStep(
                    number: '3',
                    text:
                        'Keep Delore open. Pairing and tab sync happen automatically.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: onOpenChromium,
                        icon: const Icon(Icons.language_rounded, size: 18),
                        label: const Text('Chrome / Edge / Opera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenFirefox,
                        icon: const Icon(Icons.public_rounded, size: 18),
                        label: const Text('Firefox'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: premiumMint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(number),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _BridgeHeader extends StatelessWidget {
  const _BridgeHeader({
    required this.connected,
    required this.onQueryChanged,
    required this.onOpenChromium,
    required this.onOpenFirefox,
  });

  final bool connected;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenChromium;
  final VoidCallback onOpenFirefox;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colorScheme.outlineVariant),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 820;
          final status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected ? Icons.link_rounded : Icons.link_off_rounded,
                color: connected ? premiumMint : premiumAmber,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(connected ? 'Browser connected' : 'Extension not connected'),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Open extension folder',
                onSelected: (value) =>
                    value == 'firefox' ? onOpenFirefox() : onOpenChromium(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'chromium',
                    child: Text('Chrome / Edge / Opera'),
                  ),
                  PopupMenuItem(value: 'firefox', child: Text('Firefox')),
                ],
                icon: const Icon(Icons.extension_rounded, size: 19),
              ),
            ],
          );
          final search = SizedBox(
            height: 42,
            child: TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                hintText: 'Search tabs or domains',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          );
          return narrow
              ? Column(children: [status, const SizedBox(height: 8), search])
              : Row(children: [
                  status,
                  const SizedBox(width: 12),
                  Expanded(child: search),
                ]);
        }),
      );
}

class _BrowserTabRow extends StatelessWidget {
  const _BrowserTabRow({
    super.key,
    required this.tab,
    required this.route,
    required this.routeTarget,
    required this.onRouteChanged,
    required this.onPickLocation,
  });

  final BrowserTabInfo tab;
  final ApplicationRoute route;
  final String? routeTarget;
  final ValueChanged<ApplicationRoute> onRouteChanged;
  final ValueChanged<String> onPickLocation;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color:
              context.colorScheme.surfaceContainerLow.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(RouteXRadius.card),
          border: Border.all(color: context.colorScheme.outlineVariant),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 680;
          final identity = Row(
            children: [
              _TabIcon(tab: tab),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (tab.active) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: premiumMint,
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        child: Text(
                          tab.title.isEmpty ? tab.domain : tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      '${tab.domain} · ${tab.browser}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final controls = ProxyRouteControl(
            width: narrow ? double.infinity : 270,
            route: route,
            routeTarget: routeTarget,
            onChanged: onRouteChanged,
            onPickLocation: onPickLocation,
          );
          return narrow
              ? Column(
                  children: [identity, const SizedBox(height: 10), controls])
              : Row(children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  controls,
                ]);
        }),
      );
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.tab});

  final BrowserTabInfo tab;

  @override
  Widget build(BuildContext context) {
    final fallback = 'https://icons.duckduckgo.com/ip3/${tab.domain}.ico';
    final source =
        tab.faviconUrl.startsWith('http') ? tab.faviconUrl : fallback;
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CachedNetworkImage(
        imageUrl: source,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Icon(Icons.tab_rounded, size: 20),
      ),
    );
  }
}
