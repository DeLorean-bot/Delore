import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// The nav pill's squash/stretch tuning, taken from the library's own
/// on-device-tuned nav-bar defaults (`LiquidGlassNavPillStyle.jelly`).
const routeXNavJelly = LiquidGlassJellyConfig(
  style: LiquidGlassJellyStyle.squashStretch,
  stiffness: 260,
  damping: 13,
  maxVelocity: 6,
  velocityClamp: 60,
  stretchWidth: 17.1,
  squashHeight: 9.8,
  anchorBias: -1,
  recoilScale: 3,
  directionTau: 0.42,
);

/// Travel spring for the selection lens — the library's nav defaults
/// (`travelStiffness` / `travelDamping`). Damping sits below the
/// critical value (≈ 33), so the lens settles with a faint overshoot.
const routeXNavTravelSpring = SpringDescription(
  mass: 1,
  stiffness: 280,
  damping: 31.4,
);

/// Carries a selection lens between navigation slots on a spring, and
/// deforms it with the library's jelly physics while it travels.
///
/// Deliberately not `LiquidGlassBottomNavBar`: on Skia that component's
/// selection is a flat colour fill unless the whole page is handed to
/// its own capture pipeline (`buildGlassPillBar(body: …)`), which costs
/// a second full-screen capture every frame. Driving RouteX's own
/// refracting lens with `LiquidGlassJelly` keeps the pill bending the
/// backdrop and still gets the official physics — the jelly deforms by
/// *resizing* its child, so the lens re-refracts at the deformed size
/// rather than stretching pixels.
class RouteXJellySelection extends StatefulWidget {
  const RouteXJellySelection({
    super.key,
    required this.index,
    required this.extent,
    required this.crossExtent,
    required this.child,
    this.axis = Axis.horizontal,
    this.config = routeXNavJelly,
  });

  /// The selected slot. Fractional values are honoured, so a caller can
  /// drive it from anything continuous.
  final double index;

  /// Slot size along [axis] — one index step in logical pixels.
  final double extent;

  /// Size across [axis].
  final double crossExtent;

  /// The direction the selection travels in.
  final Axis axis;

  final LiquidGlassJellyConfig config;

  /// The lens carried between slots.
  final Widget child;

  @override
  State<RouteXJellySelection> createState() => _RouteXJellySelectionState();
}

class _RouteXJellySelectionState extends State<RouteXJellySelection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController.unbounded(
    vsync: this,
    value: widget.index,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didUpdateWidget(covariant RouteXJellySelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _travelTo(widget.index);
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  /// Re-launches the spring from wherever the lens is *right now*,
  /// carrying its current velocity — so selecting again mid-flight bends
  /// the travel instead of restarting it.
  void _travelTo(double target) {
    if (_reduceMotion) {
      _travel
        ..stop()
        ..value = target;
      return;
    }
    unawaited(
      _travel.animateWith(
        SpringSimulation(
          routeXNavTravelSpring,
          _travel.value,
          target,
          _travel.velocity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return AnimatedBuilder(
      animation: _travel,
      builder: (context, child) {
        final travelled = widget.extent * _travel.value;
        return Transform.translate(
          offset: horizontal ? Offset(travelled, 0) : Offset(0, travelled),
          child: LiquidGlassJelly(
            value: _travel.value,
            width: horizontal ? widget.extent : widget.crossExtent,
            height: horizontal ? widget.crossExtent : widget.extent,
            axis: widget.axis,
            config: widget.config,
            child: child!,
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}
