import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/dashboard/dashboard.dart';
import 'package:flclashx/views/dashboard/dashboard_scene.dart'
    show DashboardChromeOverlay;
import 'package:flclashx/views/dashboard/widgets/hero_nav_bar.dart';
import 'package:flclashx/widgets/routex_jelly_selection.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => HomeBackScope(
        child: Consumer(
          builder: (_, ref, child) {
            final state = ref.watch(homeStateProvider);
            final viewMode = state.viewMode;
            final navigationItems = state.navigationItems;
            final pageLabel = state.pageLabel;
            final index = navigationItems.lastIndexWhere(
              (element) => element.label == pageLabel,
            );
            final currentIndex = index == -1 ? 0 : index;
            final navigationBar = CommonNavigationBar(
              viewMode: viewMode,
              navigationItems: navigationItems,
              currentIndex: currentIndex,
            );
            // Mobile bottom bar follows the dashboard style: the hero nav bar for
            // the new look, the classic Material NavigationBar for the old one.
            final newDashboard = ref.watch(newDashboardEnabledProvider);
            final bottomNavigationBar = viewMode == ViewMode.mobile
                ? (newDashboard ? const HeroNavBar() : navigationBar)
                : null;
            final sideNavigationBar =
                viewMode != ViewMode.mobile ? navigationBar : null;
            final isDashboard = pageLabel == PageLabel.dashboard;
            return CommonScaffold(
              key: globalState.homeScaffoldKey,
              // The Dashboard opens with its own heading, so the chrome
              // bar would just repeat the page name above it.
              showAppBar: !isDashboard,
              title: pageLabel == PageLabel.proxies
                  ? appLocalizations.locations
                  : Intl.message(pageLabel.name),
              sideNavigationBar: sideNavigationBar,
              body: isDashboard ? const DashboardView() : child!,
              bottomNavigationBar: bottomNavigationBar,
              dashboardChrome:
                  isDashboard ? const DashboardChromeOverlay() : null,
            );
          },
          child: const _HomePageView(),
        ),
      );
}

class _HomePageView extends ConsumerWidget {
  const _HomePageView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationItems = ref.watch(currentNavigationsStateProvider).value;
    final currentLabel = ref.watch(currentPageLabelProvider);
    final currentItem = navigationItems.firstWhere(
      (item) => item.label == currentLabel,
      orElse: () => navigationItems.first,
    );
    final duration = RouteXMotion.resolve(context, RouteXMotion.base);
    final currentView = currentLabel == PageLabel.dashboard
        ? const DashboardView()
        : currentItem.view;

    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: RouteXMotion.resolve(context, RouteXMotion.fast),
      switchInCurve: RouteXMotion.curve,
      switchOutCurve: RouteXMotion.curve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.012, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(currentLabel),
        child: currentView,
      ),
    );
  }
}

class CommonNavigationBar extends ConsumerWidget {
  const CommonNavigationBar({
    super.key,
    required this.viewMode,
    required this.navigationItems,
    required this.currentIndex,
  });

  final ViewMode viewMode;
  final List<NavigationItem> navigationItems;
  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewMode == ViewMode.mobile) {
      return NavigationBarTheme(
        data: _NavigationBarDefaultsM3(context),
        child: NavigationBar(
          destinations: navigationItems
              .map(
                (e) => NavigationDestination(
                  icon: e.icon,
                  label: Intl.message(e.label.name),
                ),
              )
              .toList(),
          onDestinationSelected: (index) {
            globalState.appController.toPage(navigationItems[index].label);
          },
          selectedIndex: currentIndex,
        ),
      );
    }
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return _PremiumSideNavigation(
      items: navigationItems,
      selectedIndex: currentIndex,
      expanded: showLabel,
      onSelected: (index) {
        globalState.appController.toPage(navigationItems[index].label);
      },
      onToggle: () {
        ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(showLabel: !state.showLabel),
            );
      },
    );
  }
}

class _PremiumSideNavigation extends ConsumerWidget {
  const _PremiumSideNavigation({
    required this.items,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
    required this.onToggle,
  });

  final List<NavigationItem> items;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = expanded ? 244.0 : 88.0;
    final isRunning = ref.watch(runTimeProvider) != null;
    final duration = RouteXMotion.resolve(
      context,
      RouteXMotion.navigation,
    );

    return AnimatedContainer(
      duration: duration,
      curve: RouteXMotion.curve,
      width: width,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          // No underlay behind the glass: on Skia the lens draws an
          // opaque refracted sample of the captured background over its
          // whole rect, so anything painted beneath it in the tree is
          // both un-refracted and invisible. Detail the sidebar can
          // actually bend belongs in the backdrop — see RouteXBackdrop.
          child: RouteXGlassSurface(
            variant: RouteXGlassVariant.navigation,
            radius: 26,
            shadowOffset: const Offset(5, 8),
            // Width must not change the material. Using the shared navigation
            // tint here made the compact rail turn grey while the expanded one
            // stayed clear. The sidebar is transparent in both states; only its
            // geometry changes during collapse/expand.
            tintAlphaFactor: 0,
            blurFactor: 0.3,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  if (!Platform.isMacOS) _RouteXBrand(expanded: expanded),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _DesktopNavigationItems(
                      items: items,
                      selectedIndex: selectedIndex,
                      expanded: expanded,
                      onSelected: onSelected,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 8),
                    _RoutingStatus(isRunning: isRunning),
                  ],
                  const SizedBox(height: 8),
                  _RoutingModeToggle(expanded: expanded),
                  const SizedBox(height: 8),
                  _SidebarToggle(
                    expanded: expanded,
                    onPressed: onToggle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteXBrand extends StatelessWidget {
  const _RouteXBrand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _DesktopNavigationItems extends ConsumerWidget {
  const _DesktopNavigationItems({
    required this.items,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const itemExtent = 56.0;

    void reorder(int oldIndex, int newIndex) {
      final reordered = [...items];
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);
      ref.read(navigationOrderProvider.notifier).reorderVisible(
            reordered.map((entry) => entry.label).toList(growable: false),
          );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SizedBox(
          height: itemExtent * items.length,
          child: Stack(
            children: [
              RouteXSlidingSelection(
                index: selectedIndex.toDouble(),
                extent: itemExtent,
                crossExtent: constraints.maxWidth,
                axis: Axis.vertical,
                child: _DesktopSelectionLens(expanded: expanded),
              ),
              ReorderableListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: items.length,
                onReorder: reorder,
                proxyDecorator: (child, index, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => Transform.scale(
                    scale: 1 + (0.025 * animation.value),
                    child: Material(
                      type: MaterialType.transparency,
                      child: child,
                    ),
                  ),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final tile = SizedBox(
                    height: itemExtent,
                    child: _DesktopNavigationItem(
                      item: item,
                      selected: index == selectedIndex,
                      expanded: expanded,
                      onTap: () => onSelected(index),
                    ),
                  );
                  return ReorderableDragStartListener(
                    key: ValueKey(item.label),
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: tile,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSelectionLens extends StatelessWidget {
  const _DesktopSelectionLens({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 0 : 2,
          vertical: 2,
        ),
        child: const RouteXSelectionGlass(
          radius: RouteXRadius.navigation,
          capsule: true,
        ),
      );
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final NavigationItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  String get _label => item.label == PageLabel.proxies
      ? appLocalizations.locations
      : Intl.message(item.label.name);

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final tile = Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              overlayColor: WidgetStatePropertyAll(
                Colors.white.withValues(alpha: 0.035),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.06 : 1,
                      duration: RouteXMotion.resolve(
                        context,
                        RouteXMotion.base,
                      ),
                      curve: RouteXMotion.curve,
                      child: Icon(
                        routeXNavigationIcon(item.label),
                        size: 21,
                        color: selected
                            ? premiumMint
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: selected
                                ? context.colorScheme.onSurface
                                : context.colorScheme.onSurfaceVariant,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

    return Semantics(
      selected: selected,
      button: true,
      label: _label,
      hint: isRussian
          ? 'Перетащите, чтобы изменить порядок'
          : 'Drag to reorder',
      // Only the collapsed rail gets a tooltip. Expanded, the label is
      // already sitting right there in the row — a help tag that repeats
      // a visible label is noise, and Apple's guidance is that a tooltip
      // explains a control whose purpose isn't already obvious. It also
      // kept a live OverlayEntry churning on every pass of the cursor
      // across the nav during rapid switching, next to the overlay
      // ReorderableListView already runs for its drag proxy.
      child: expanded
          ? tile
          : Tooltip(
              message: _label,
              // Long enough that clicking through the nav quickly never
              // spawns one; a genuine "what is this icon?" hover still does.
              waitDuration: const Duration(milliseconds: 600),
              child: tile,
            ),
    );
  }
}

class _RoutingStatus extends StatelessWidget {
  const _RoutingStatus({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: '${appLocalizations.status}: '
            '${isRunning ? appLocalizations.running : appLocalizations.stopped}',
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHigh
                .withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.48),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isRunning ? premiumMint : Colors.white)
                      .withValues(alpha: isRunning ? 0.12 : 0.055),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRunning
                      ? Icons.shield_outlined
                      : Icons.pause_circle_outline_rounded,
                  size: 16,
                  color: isRunning
                      ? premiumMint
                      : context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLocalizations.status,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRunning
                          ? appLocalizations.running
                          : appLocalizations.stopped,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: isRunning
                            ? premiumMint
                            : context.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
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

/// Routing-mode switcher pinned above the collapse button — a persistent,
/// one-tap Rules/Global control instead of burying it behind a popup menu.
/// `Mode.direct` exists in the enum but has no seat here: it's a debug
/// escape hatch, not a mode a user picks from the sidebar.
class _RoutingModeToggle extends ConsumerWidget {
  const _RoutingModeToggle({required this.expanded});

  final bool expanded;

  static const _modes = [Mode.rule, Mode.global];

  IconData _icon(Mode mode) =>
      mode == Mode.rule ? Icons.rule_rounded : Icons.public_rounded;

  // appLocalizations.rule is "По правилам" — reads fine as a standalone
  // sentence elsewhere, but doesn't fit next to a second segment in a
  // 244px sidebar. A shorter label for this one tight spot only.
  String _label(BuildContext context, Mode mode) {
    if (mode == Mode.global) return appLocalizations.global;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    return isRussian ? 'Правила' : appLocalizations.rule;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final active = _modes.contains(mode) ? mode : Mode.rule;
    final duration = RouteXMotion.resolve(context, RouteXMotion.fast);

    if (!expanded) {
      // Two slots, not one that cycles: every other collapsed rail item
      // is its own icon for its own destination, and a single button
      // standing in for two modes broke that pattern — you couldn't see
      // the mode you'd land on without tapping first.
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color:
              context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.48),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            for (final mode in _modes)
              Tooltip(
                message: _label(context, mode),
                child: RouteXFocusableTap(
                  borderRadius: 11,
                  onTap: () => globalState.appController.changeMode(mode),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: RouteXMotion.curve,
                    width: 38,
                    height: 34,
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mode == active
                          ? premiumMint.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _icon(mode),
                      size: 16,
                      color: mode == active
                          ? premiumMint
                          : context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.48),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          for (final mode in _modes)
            Expanded(
              child: RouteXFocusableTap(
                borderRadius: 11,
                onTap: () => globalState.appController.changeMode(mode),
                child: AnimatedContainer(
                  duration: duration,
                  curve: RouteXMotion.curve,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mode == active
                        ? premiumMint.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icon(mode),
                        size: 15,
                        color: mode == active
                            ? premiumMint
                            : context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _label(context, mode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: mode == active
                                ? premiumMint
                                : context.colorScheme.onSurfaceVariant,
                            fontWeight: mode == active
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label =
        expanded ? appLocalizations.collapseAll : appLocalizations.expand;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                expanded
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: context.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(this.context)
      : super(
          height: 80.0,
          elevation: 3.0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme =>
      WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 24.0,
            color: states.contains(WidgetState.disabled)
                ? _colors.onSurfaceVariant.opacity38
                : states.contains(WidgetState.selected)
                    ? _colors.onSecondaryContainer
                    : _colors.onSurfaceVariant,
          ));

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => const StadiumBorder();

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle =>
      WidgetStateProperty.resolveWith((states) => _textTheme.labelMedium!.apply(
          overflow: TextOverflow.ellipsis,
          color: states.contains(WidgetState.disabled)
              ? _colors.onSurfaceVariant.opacity38
              : states.contains(WidgetState.selected)
                  ? _colors.onSurface
                  : _colors.onSurfaceVariant));
}

class HomeBackScope extends StatelessWidget {
  const HomeBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return CommonPopScope(
        onPop: () async {
          final canPop = Navigator.canPop(context);
          if (canPop) {
            Navigator.pop(context);
          } else {
            await globalState.appController.handleBackOrExit();
          }
          return false;
        },
        child: child,
      );
    }
    return child;
  }
}
