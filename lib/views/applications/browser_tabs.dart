import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/clash/clash.dart';
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
  StreamSubscription<BrowserBridgeStatus>? _statusSubscription;
  Timer? _clock;
  List<BrowserTabInfo> _tabs = const [];
  List<DomainRouteEntry> _routes = const [];
  BrowserBridgeStatus _bridgeStatus = browserBridge.status;
  Future<void> _applyQueue = Future.value();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = browserBridge.tabs;
    _subscription = browserBridge.stream.listen((tabs) {
      if (mounted) setState(() => _tabs = tabs);
    });
    _statusSubscription = browserBridge.statusStream.listen((status) {
      if (mounted) setState(() => _bridgeStatus = status);
    });
    _syncClock();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BrowserTabsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncClock();
    if (!oldWidget.active && widget.active) unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    _clock?.cancel();
    super.dispose();
  }

  void _syncClock() {
    _clock?.cancel();
    _clock = null;
    if (!widget.active) return;
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _bridgeStatus = browserBridge.status);
    });
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

  DomainRouteEntry? _routeFor(String domain) =>
      DomainRoutingStore.find(_routes, domain);

  Future<void> _setRoute(
    BrowserTabInfo tab,
    ApplicationRoute route, {
    String? explicitTarget,
  }) =>
      _setDomainRoute(
        tab.domain,
        route,
        explicitTarget: explicitTarget,
      );

  Future<void> _setDomainRoute(
    String rawDomain,
    ApplicationRoute route, {
    String? explicitTarget,
  }) async {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) {
      context.showSnackBar('Add or select a profile first');
      return;
    }
    final domain = DomainRoutingStore.normalize(rawDomain);
    final previous = _routeFor(domain);
    final storedDomain = previous?.domain ?? domain;
    if (route == ApplicationRoute.rule) {
      await DomainRoutingStore.remove(profileId, storedDomain);
      setState(() => _routes = _routes
          .where((entry) => entry.domain != storedDomain)
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
        domain: storedDomain,
        route: route,
        target: target,
        favorite: previous?.favorite ?? false,
      );
      await DomainRoutingStore.set(profileId, entry);
      setState(() {
        _routes = [
          for (final current in _routes)
            if (current.domain != storedDomain) current,
          entry,
        ];
      });
    }
    await _applyRoutes();
    if (mounted) {
      final running = ref.read(runTimeProvider) != null;
      context.showSnackBar(
        running
            ? '$storedDomain route updated for every browser tab'
            : '$storedDomain saved · connect Delore to activate routing',
      );
    }
  }

  Future<void> _applyRoutes() {
    final next = _applyQueue.then(
      (_) => _applyRoutesNow(),
      onError: (_) => _applyRoutesNow(),
    );
    _applyQueue = next;
    return next;
  }

  Future<void> _applyRoutesNow() async {
    await globalState.appController.applyProfile();
    // Chrome keeps HTTP/2 and QUIC sessions alive across refreshes. Without
    // closing them, an already open tab can continue through its previous
    // location even though the new domain rule is active in the core.
    await clashCore.closeConnections();
  }

  void _showConfiguredRoutes() {
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.68,
            child: _ConfiguredRoutesPanel(
              routes: _routes,
              onRouteChanged: (
                domain,
                route, {
                explicitTarget,
              }) async {
                await _setDomainRoute(
                  domain,
                  route,
                  explicitTarget: explicitTarget,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> _openExtensionFolder(String browser) async {
    final relative = p.join('assets', 'browser_extension', browser);
    final packaged = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      relative,
    );
    final directory = Directory(Directory(packaged).existsSync()
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
    final connected = _bridgeStatus.connected;
    final routingActive = ref.watch(
      runTimeProvider.select((runtime) => runtime != null),
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
            status: _bridgeStatus,
            onQueryChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            onOpenChromium: () => _openExtensionFolder('chromium'),
            onOpenFirefox: () => _openExtensionFolder('firefox'),
          ),
          if (!routingActive) ...[
            const SizedBox(height: 10),
            const _RoutingPausedBanner(),
          ],
          const SizedBox(height: 12),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final showSidePanel = constraints.maxWidth >= 1080;
            final tabsView = tabs.isEmpty
                ? connected && _query.isNotEmpty
                    ? const NullStatus(label: 'No tabs match your search')
                    : _BridgeEmptyState(
                        status: _bridgeStatus,
                        onRestart: () async => browserBridge.restart(),
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
                  );
            if (showSidePanel) {
              return Row(children: [
                Expanded(child: tabsView),
                const SizedBox(width: 12),
                SizedBox(
                  width: 330,
                  child: _ConfiguredRoutesPanel(
                    routes: _routes,
                    onRouteChanged: _setDomainRoute,
                  ),
                ),
              ]);
            }
            return Column(children: [
              if (_routes.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _showConfiguredRoutes,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text('Configured sites · ${_routes.length}'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Expanded(child: tabsView),
            ]);
          })),
        ],
      ),
    );
  }
}

class _RoutingPausedBanner extends StatelessWidget {
  const _RoutingPausedBanner();

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(children: [
        const Icon(Icons.pause_circle_outline_rounded, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            isRussian
                ? 'Маршрутизация приостановлена. Правила сохранены — подключите Delore, чтобы они начали работать.'
                : 'Routing is paused. Your rules are saved — connect Delore to activate them.',
            style: context.textTheme.bodySmall,
          ),
        ),
      ]),
    );
  }
}

class _ConfiguredRoutesPanel extends StatelessWidget {
  const _ConfiguredRoutesPanel({
    required this.routes,
    required this.onRouteChanged,
  });

  final List<DomainRouteEntry> routes;
  final Future<void> Function(
    String domain,
    ApplicationRoute route, {
    String? explicitTarget,
  }) onRouteChanged;

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final sorted = [...routes]..sort((a, b) => a.domain.compareTo(b.domain));
    return RouteXGlassSurface(
      variant: RouteXGlassVariant.panel,
      radius: 20,
      tintAlphaFactor: 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.route_rounded, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRussian ? 'Настроенные сайты' : 'Configured sites',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${routes.length}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              isRussian
                  ? 'Сохраняются по домену после обновления и перезапуска'
                  : 'Saved by domain and kept after refresh or restart',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                        isRussian
                            ? 'Выберите локацию для вкладки — её домен появится здесь'
                            : 'Pick a location for a tab to save its domain here',
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final entry = sorted[index];
                        return Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.language_rounded, size: 17),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    entry.domain,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove route',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => onRouteChanged(
                                    entry.domain,
                                    ApplicationRoute.rule,
                                  ),
                                  icon:
                                      const Icon(Icons.close_rounded, size: 17),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              ProxyRouteControl(
                                width: double.infinity,
                                route: entry.route,
                                routeTarget: entry.target,
                                onChanged: (route) => onRouteChanged(
                                  entry.domain,
                                  route,
                                ),
                                onPickLocation: (target) => onRouteChanged(
                                  entry.domain,
                                  ApplicationRoute.proxy,
                                  explicitTarget: target,
                                ),
                              ),
                            ],
                          ),
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

class _BridgeEmptyState extends StatelessWidget {
  const _BridgeEmptyState({
    required this.status,
    required this.onRestart,
    required this.onOpenChromium,
    required this.onOpenFirefox,
  });

  final BrowserBridgeStatus status;
  final Future<void> Function() onRestart;
  final VoidCallback onOpenChromium;
  final VoidCallback onOpenFirefox;

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final connected = status.connected;
    final hasError = status.error != null;
    final title = switch ((status.running, connected, hasError)) {
      (false, _, true) => isRussian
          ? 'Мост браузера не запустился'
          : 'Browser Bridge did not start',
      (_, _, true) => isRussian
          ? 'Расширение переподключается'
          : 'Reconnecting the extension',
      (_, true, _) => isRussian
          ? '${status.browser ?? 'Браузер'} подключён'
          : '${status.browser ?? 'Browser'} connected',
      (true, false, _) =>
        isRussian ? 'Ожидаем расширение' : 'Waiting for the extension',
      _ => isRussian ? 'Запускаем мост браузера' : 'Starting Browser Bridge',
    };
    final detail = switch ((status.running, connected, hasError)) {
      (false, _, true) => status.error!,
      (_, _, true) => isRussian
          ? 'Delore автоматически обновит pairing и повторит синхронизацию.'
          : 'Delore will refresh pairing and retry automatically.',
      (_, true, _) when status.reportedTabs == 0 => isRussian
          ? 'Расширение работает. В браузере пока нет открытых вкладок.'
          : 'The extension is working. There are no open tabs yet.',
      (_, true, _) when status.acceptedTabs == 0 => isRussian
          ? 'Открыты только служебные страницы. Обычные сайты появятся здесь автоматически.'
          : 'Only internal browser pages are open. Regular websites will appear automatically.',
      (_, true, _) => isRussian
          ? 'Вкладки синхронизированы. Выберите локацию — Delore применит правило сайта автоматически.'
          : 'Tabs are synced. Pick a location and Delore will apply the site rule automatically.',
      _ => isRussian
          ? 'Откройте установленное расширение один раз или нажмите «Синхронизировать». Delore сделает остальное.'
          : 'Open the installed extension once or press Sync. Delore handles the rest.',
    };
    return RouteXStatusState(
      icon: Icons.tab_rounded,
      title: title,
      detail: detail,
      loading: status.running && !connected && !hasError,
      actions: [
        if (!status.running)
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(isRussian ? 'Повторить' : 'Try again'),
          ),
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
    );
  }
}

class _BridgeHeader extends StatelessWidget {
  const _BridgeHeader({
    required this.status,
    required this.onQueryChanged,
    required this.onOpenChromium,
    required this.onOpenFirefox,
  });

  final BrowserBridgeStatus status;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenChromium;
  final VoidCallback onOpenFirefox;

  @override
  Widget build(BuildContext context) => RouteXGlassSurface(
        variant: RouteXGlassVariant.control,
        radius: 18,
        expand: false,
        tintAlphaFactor: 1,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 820;
            final statusView = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status.connected
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  color: status.connected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Text(
                  status.connected
                      ? '${status.browser ?? 'Browser'} · ${status.acceptedTabs} tabs'
                      : status.error ?? 'Waiting for extension',
                ),
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
                ? Column(
                    children: [statusView, const SizedBox(height: 8), search],
                  )
                : Row(children: [
                    statusView,
                    const SizedBox(width: 12),
                    Expanded(child: search),
                  ]);
          }),
        ),
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
