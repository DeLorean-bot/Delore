import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                  radius: RouteXRadius.navigation,
                  blur: 22,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _SlidingPrimaryTabs(
                      items: primaryItems,
                      current: current,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: RouteXGlassSurface(
                  radius: RouteXRadius.navigation,
                  blur: 22,
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

class _SlidingPrimaryTabs extends StatelessWidget {
  const _SlidingPrimaryTabs({
    required this.items,
    required this.current,
  });

  final List<NavigationItem> items;
  final PageLabel current;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere((item) => item.label == current);
    final targetIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / items.length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: targetIndex.toDouble()),
              duration: reduceMotion ? Duration.zero : RouteXMotion.navigation,
              curve: RouteXMotion.curve,
              child: const RepaintBoundary(child: _LiquidLens()),
              builder: (context, position, child) => Transform.translate(
                offset: Offset(segmentWidth * position, 0),
                child: SizedBox(
                  width: segmentWidth,
                  height: constraints.maxHeight,
                  child: child,
                ),
              ),
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
        );
      },
    );
  }
}

class _LiquidLens extends StatelessWidget {
  const _LiquidLens();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(1),
        child: RouteXSelectionGlass(radius: 22),
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
    final muted = context.colorScheme.onSurfaceVariant;
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
                        size: 22,
                        color: widget.selected ? premiumMint : muted,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          routeXNavigationIcon(widget.item.label),
                          size: 20,
                          color: widget.selected ? premiumMint : muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.selected ? selectedColor : muted,
                            fontSize: 9,
                            height: 1,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            letterSpacing: -0.2,
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
