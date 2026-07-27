import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/dashboard/dashboard.dart';
import 'package:flclashx/views/dashboard/widgets/hero_nav_bar.dart';
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
            return CommonScaffold(
              key: globalState.homeScaffoldKey,
              title: Intl.message(
                pageLabel.name,
              ),
              sideNavigationBar: sideNavigationBar,
              body: pageLabel == PageLabel.dashboard
                  ? const DashboardView()
                  : child!,
              bottomNavigationBar: bottomNavigationBar,
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
      switchOutCurve: Curves.easeIn,
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
            radius: 26,
            blur: 26,
            shadowOffset: const Offset(5, 8),
            ambientTint: true,
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    premiumMint.withValues(alpha: 0.92),
                    premiumBlue.withValues(alpha: 0.88),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Color(0xFF07110E),
                size: 21,
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

class _DesktopNavigationItems extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const itemExtent = 56.0;
    final duration = RouteXMotion.resolve(
      context,
      RouteXMotion.navigation,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SizedBox(
          height: itemExtent * items.length,
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: selectedIndex.toDouble()),
                duration: duration,
                curve: RouteXMotion.curve,
                child: RepaintBoundary(
                  child: _DesktopSelectionLens(expanded: expanded),
                ),
                builder: (context, position, child) => Transform.translate(
                  offset: Offset(0, itemExtent * position),
                  child: SizedBox(
                    height: itemExtent,
                    width: double.infinity,
                    child: child,
                  ),
                ),
              ),
              Column(
                children: [
                  for (var index = 0; index < items.length; index++)
                    SizedBox(
                      height: itemExtent,
                      child: _DesktopNavigationItem(
                        item: items[index],
                        selected: index == selectedIndex,
                        expanded: expanded,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
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
        child: const RouteXSelectionGlass(radius: 18),
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
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: _label,
        child: Tooltip(
          message: expanded ? '' : _label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
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
          ),
        ),
      );
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
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colorScheme.outlineVariant
                      .withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
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
