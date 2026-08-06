import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/routex_jelly_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Bar height; the capsule radius and the pill radius both derive from it.
const _barHeight = 68.0;

/// The slot the selection lens fills: the bar minus its 4 px inner
/// padding, minus the lens's own 1 px inset.
const _pillHeight = _barHeight - 8 - 2;

class HeroNavBar extends ConsumerWidget {
  const HeroNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isMobileViewProvider)) return const SizedBox.shrink();
    final items = ref.watch(currentNavigationsStateProvider).value;
    if (items.length < 2) return const SizedBox.shrink();

    final current = ref.watch(currentPageLabelProvider);
    final detachedIndex =
        items.lastIndexWhere((item) => item.label == PageLabel.tools);
    final actualDetachedIndex =
        detachedIndex < 0 ? items.length - 1 : detachedIndex;
    final detached = items[actualDetachedIndex];
    final primaryItems = [
      for (var index = 0; index < items.length; index++)
        if (index != actualDetachedIndex) items[index],
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
        child: SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RouteXGlassSurface(
                  variant: RouteXGlassVariant.navigation,
                  radius: RouteXRadius.capsule(_barHeight),
                  capsule: true,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _JellyPrimaryTabs(
                      items: primaryItems,
                      current: current,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _barHeight,
                child: RouteXGlassSurface(
                  variant: RouteXGlassVariant.navigation,
                  radius: RouteXRadius.capsule(_barHeight),
                  capsule: true,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _DetachedLens(selected: detached.label == current),
                        _LiquidNavItem(
                          item: detached,
                          selected: detached.label == current,
                          iconOnly: true,
                        ),
                      ],
                    ),
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

/// The primary destinations with a spring-driven, jelly-deforming
/// selection lens.
class _JellyPrimaryTabs extends ConsumerWidget {
  const _JellyPrimaryTabs({
    required this.items,
    required this.current,
  });

  final List<NavigationItem> items;
  final PageLabel current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = items.indexWhere((item) => item.label == current);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : RouteXMotion.navigation;
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = constraints.maxWidth / items.length;

      void reorder(int oldIndex, int newIndex) {
        final reordered = [...items];
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        ref.read(navigationOrderProvider.notifier).reorderVisible(
              reordered.map((entry) => entry.label).toList(growable: false),
            );
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Hidden rather than left at index 0: without this, navigating to
          // the detached Tools/Settings slot left this lens parked under the
          // first primary tab (Главная), which then read as still selected.
          AnimatedOpacity(
            opacity: selectedIndex < 0 ? 0 : 1,
            duration: duration,
            curve: RouteXMotion.curve,
            child: RouteXSlidingSelection(
              index: (selectedIndex < 0 ? 0 : selectedIndex).toDouble(),
              extent: constraints.maxWidth / items.length,
              crossExtent: constraints.maxHeight,
              child: const _LiquidLens(),
            ),
          ),
          ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: reorder,
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Transform.scale(
                scale: 1 + (0.045 * animation.value),
                child: Material(
                  type: MaterialType.transparency,
                  child: RouteXGlassSurface(
                    variant: RouteXGlassVariant.control,
                    radius: 22,
                    child: child,
                  ),
                ),
              ),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final tab = SizedBox(
                width: itemWidth,
                child: _LiquidNavItem(
                  item: item,
                  selected: item.label == current,
                  draggableHint: true,
                ),
              );
              if (system.isDesktop) {
                return ReorderableDragStartListener(
                  key: ValueKey(item.label),
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: tab,
                  ),
                );
              }
              return ReorderableDelayedDragStartListener(
                key: ValueKey(item.label),
                index: index,
                child: tab,
              );
            },
          ),
        ],
      );
    });
  }
}

class _LiquidLens extends StatelessWidget {
  const _LiquidLens();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(1),
        child: RouteXSelectionGlass(
          radius: RouteXRadius.capsule(_pillHeight),
          capsule: true,
        ),
      );
}

class _DetachedLens extends StatelessWidget {
  const _DetachedLens({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : RouteXMotion.navigation;
    return AnimatedOpacity(
      opacity: selected ? 1 : 0,
      duration: duration,
      curve: RouteXMotion.curve,
      child: AnimatedScale(
        scale: selected ? 1 : 0.82,
        duration: duration,
        curve: RouteXMotion.curve,
        child: const _LiquidLens(),
      ),
    );
  }
}

class _LiquidNavItem extends StatefulWidget {
  const _LiquidNavItem({
    required this.item,
    required this.selected,
    this.iconOnly = false,
    this.draggableHint = false,
  });

  final NavigationItem item;
  final bool selected;
  final bool iconOnly;
  final bool draggableHint;

  @override
  State<_LiquidNavItem> createState() => _LiquidNavItemState();
}

class _LiquidNavItemState extends State<_LiquidNavItem> {
  bool _pressed = false;

  String get _label => widget.item.label == PageLabel.proxies
      ? appLocalizations.locations
      : Intl.message(widget.item.label.name);

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // iOS nav glyphs are white at rest, not grey: the muted treatment is
    // what made the bar look faded and cheap.
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.86);
    final selectedColor = context.colorScheme.onSurface;

    final tile = Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onHighlightChanged: (value) {
              if (_pressed != value) setState(() => _pressed = value);
            },
            onTap: () => globalState.appController.toPage(widget.item.label),
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.035),
            ),
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1,
              duration: reduceMotion ? Duration.zero : RouteXMotion.press,
              curve: RouteXMotion.curve,
              child: widget.iconOnly
                  ? Center(
                      child: Icon(
                        routeXNavigationIcon(widget.item.label),
                        size: 26,
                        color: widget.selected ? premiumMint : muted,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          routeXNavigationIcon(widget.item.label),
                          size: 25,
                          color: widget.selected ? premiumMint : muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                widget.selected ? premiumMint : selectedColor,
                            fontSize: 11.5,
                            height: 1.05,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            letterSpacing: -0.1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );

    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    return Semantics(
      selected: widget.selected,
      button: true,
      label: _label,
      hint: widget.draggableHint
          ? (isRussian
              ? 'Удерживайте и перетащите, чтобы изменить порядок'
              : 'Hold and drag to reorder')
          : null,
      // Only the icon-only slot gets a tooltip. The labelled tabs print
      // their name directly under the glyph, so a help tag repeating it
      // adds nothing — and it kept spawning an OverlayEntry every time
      // the pointer crossed the bar while switching tabs.
      child: widget.iconOnly
          ? Tooltip(
              message: _label,
              waitDuration: const Duration(milliseconds: 600),
              child: tile,
            )
          : tile,
    );
  }
}
