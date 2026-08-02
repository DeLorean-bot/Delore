import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "Sites" tab: routes specific domains through a chosen location or
/// Direct regardless of which application opens them — e.g. youtube.com
/// through one server while everything else follows the app's own routing.
/// Per-tab-of-a-browser routing isn't reachable from a Clash core (a browser
/// is one process, one network stack — there's no per-tab signal at the
/// network layer), so this is the closest real equivalent: a site-level pin
/// that wins over app-level routing (see the priority note in state.dart).
class DomainRoutingBody extends ConsumerStatefulWidget {
  const DomainRoutingBody({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DomainRoutingBody> createState() => _DomainRoutingBodyState();
}

class _DomainRoutingBodyState extends ConsumerState<DomainRoutingBody> {
  final _scrollController = SmoothScrollController();
  final _inputController = TextEditingController();
  bool _loading = true;
  String? _profileId;
  List<DomainRouteEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(DomainRoutingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profileId = ref.read(currentProfileIdProvider);
    _profileId = profileId;
    if (profileId == null) {
      if (mounted)
        setState(() {
          _entries = const [];
          _loading = false;
        });
      return;
    }
    final entries = await DomainRoutingStore.load(profileId);
    if (!mounted || _profileId != profileId) return;
    setState(() {
      _entries = entries;
      _loading = false;
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

  Future<void> _addDomain() async {
    final raw = _inputController.text;
    final domain = DomainRoutingStore.normalize(raw);
    if (domain.isEmpty || !domain.contains('.')) {
      context.showSnackBar('Введите домен, например youtube.com');
      return;
    }
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) {
      context.showSnackBar('Сначала добавьте или выберите профиль');
      return;
    }
    if (_entries.any((entry) => entry.domain == domain)) {
      context.showSnackBar('Этот домен уже в списке');
      return;
    }
    final target = _defaultProxyTarget();
    final entry = DomainRouteEntry(
      domain: domain,
      route: target == null ? ApplicationRoute.direct : ApplicationRoute.proxy,
      target: target,
    );
    _inputController.clear();
    setState(() => _entries = [..._entries, entry]);
    await DomainRoutingStore.set(profileId, entry);
    await globalState.appController.applyProfile();
  }

  Future<void> _updateEntry(
    DomainRouteEntry previous,
    ApplicationRoute route, {
    String? explicitTarget,
  }) async {
    // A domain entry has no "follow the default rule" state of its own the
    // way an app does — it either has a pin or it doesn't exist. The picker's
    // "default" row always renders (it's the shared widget also used for
    // apps), so route it to the same removal path the trash button uses
    // rather than leave a phantom entry with route == rule in the list.
    if (route == ApplicationRoute.rule) {
      await _removeEntry(previous);
      return;
    }
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    String? target;
    if (route == ApplicationRoute.proxy) {
      target = explicitTarget ?? previous.target ?? _defaultProxyTarget();
      if (target == null) {
        context.showSnackBar('В этом профиле нет доступных локаций');
        return;
      }
    } else if (route == ApplicationRoute.direct) {
      target = 'DIRECT';
    }
    final entry = DomainRouteEntry(
      domain: previous.domain,
      route: route,
      target: target,
      favorite: previous.favorite,
    );
    setState(() {
      _entries = [
        for (final existing in _entries)
          if (existing.domain == previous.domain) entry else existing,
      ];
    });
    await DomainRoutingStore.set(profileId, entry);
    await globalState.appController.applyProfile();
  }

  Future<void> _toggleFavorite(DomainRouteEntry previous) async {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    final entry = DomainRouteEntry(
      domain: previous.domain,
      route: previous.route,
      target: previous.target,
      favorite: !previous.favorite,
    );
    setState(() {
      _entries = [
        for (final existing in _entries)
          if (existing.domain == previous.domain) entry else existing,
      ];
    });
    await DomainRoutingStore.set(profileId, entry);
  }

  Future<void> _removeEntry(DomainRouteEntry entry) async {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    setState(() {
      _entries = _entries.where((e) => e.domain != entry.domain).toList();
    });
    await DomainRoutingStore.remove(profileId, entry.domain);
    await globalState.appController.applyProfile();
    if (!mounted) return;
    context.showSnackBar(
      '${entry.domain} удалён',
      action: SnackBarAction(
        label: appLocalizations.undo,
        onPressed: () {
          unawaited(() async {
            setState(() => _entries = [..._entries, entry]);
            await DomainRoutingStore.set(profileId, entry);
            await globalState.appController.applyProfile();
          }());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    ref.listen(currentProfileIdProvider, (previous, next) {
      if (previous != next) unawaited(_load());
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AddDomainRow(
            controller: _inputController,
            onSubmit: _addDomain,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? NullStatus(
                        label: isRussian
                            ? 'Добавьте сайт, чтобы выбрать для него отдельный маршрут'
                            : 'Add a site to choose a separate route for it',
                      )
                    : CommonScrollBar(
                        controller: _scrollController,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final entries = [..._entries]..sort((a, b) {
                                if (a.favorite != b.favorite) {
                                  return a.favorite ? -1 : 1;
                                }
                                return a.domain.compareTo(b.domain);
                              });
                            final entry = entries[index];
                            return _DomainRow(
                              key: ValueKey(entry.domain),
                              entry: entry,
                              onRouteChanged: (route) =>
                                  _updateEntry(entry, route),
                              onPickLocation: (target) => _updateEntry(
                                entry,
                                ApplicationRoute.proxy,
                                explicitTarget: target,
                              ),
                              onRemove: () => _removeEntry(entry),
                              onToggleFavorite: () => _toggleFavorite(entry),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AddDomainRow extends StatelessWidget {
  const _AddDomainRow({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow.withValues(
          alpha: 0.68,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) => onSubmit(),
                decoration: const InputDecoration(
                  hintText: 'youtube.com',
                  prefixIcon: Icon(Icons.public_rounded, size: 18),
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(isRussian ? 'Добавить' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow({
    super.key,
    required this.entry,
    required this.onRouteChanged,
    required this.onPickLocation,
    required this.onRemove,
    required this.onToggleFavorite,
  });

  final DomainRouteEntry entry;
  final ValueChanged<ApplicationRoute> onRouteChanged;
  final ValueChanged<String> onPickLocation;
  final VoidCallback onRemove;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow.withValues(
            alpha: 0.64,
          ),
          borderRadius: BorderRadius.circular(RouteXRadius.card),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final identity = Row(
              children: [
                _DomainIcon(domain: entry.domain),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: entry.favorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    entry.favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: entry.favorite ? premiumAmber : null,
                  ),
                ),
                ProxyRouteControl(
                  width: narrow ? double.infinity : 260,
                  route: entry.route,
                  routeTarget: entry.target,
                  onChanged: onRouteChanged,
                  onPickLocation: onPickLocation,
                  defaultLabel: 'Удалить сайт',
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 11),
                  controls,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                controls,
              ],
            );
          },
        ),
      );
}

/// The site's real favicon, not a generic globe — pulled from DuckDuckGo's
/// icon service (icons.duckduckgo.com) rather than Google's equivalent,
/// since routing this from a VPN client's own "which sites did you pin"
/// list to Google specifically felt like the wrong default to reach for.
/// Falls back to the globe glyph while loading or if a domain has none.
class _DomainIcon extends StatelessWidget {
  const _DomainIcon({required this.domain});

  final String domain;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
        alignment: Alignment.center,
        child: CachedNetworkImage(
          imageUrl: 'https://icons.duckduckgo.com/ip3/$domain.ico',
          width: 26,
          height: 26,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const Icon(Icons.public_rounded, size: 20),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.public_rounded, size: 20),
        ),
      );
}
