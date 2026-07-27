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
class _JellyPrimaryTabs extends StatelessWidget {
  const _JellyPrimaryTabs({
    required this.items,
    required this.current,
  });

  final List<NavigationItem> items;
  final PageLabel current;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere((item) => item.label == current);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        clipBehavior: Clip.none,
        children: [
          RouteXJellySelection(
            index: (selectedIndex < 0 ? 0 : selectedIndex).toDouble(),
            extent: constraints.maxWidth / items.length,
            crossExtent: constraints.maxHeight,
            child: const _LiquidLens(),
          ),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _LiquidNavItem(
                    item: item,
                    selected: item.label == current,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiquidLens extends StatelessWidget {
  const _LiquidLens();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(1),
        child: RouteXSelectionGlass(
          radius: RouteXRadius.capsule(_pillHeight),
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
  });

  final NavigationItem item;
  final bool selected;
  final bool iconOnly;

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

    return Semantics(
      selected: widget.selected,
      button: true,
      label: _label,
      child: Tooltip(
        message: _label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
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
              curve: Curves.easeOut,
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
        ),
      ),
    );
  }
}
