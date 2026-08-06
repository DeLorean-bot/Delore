import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Apple's own spring for a sliding selection thumb — the exact constants
/// `CupertinoSlidingSegmentedControl` ships, already ported into this
/// codebase at `tab.dart`'s `_kThumbSpringAnimationSimulation`. Critically
/// damped (ratio 1.0, so no overshoot) with a response of ~0.28s.
///
/// A slower spring was tried first, using the apple-design skill's
/// "Move / reposition" row (response 0.4s). That row is for repositioning
/// a large object like a PiP window; on a small selection lens its long
/// asymptotic tail read as lag, and because this lens is a live glass
/// surface, every extra frame of tail is another frame of BackdropFilter.
/// Apple's own value for *this specific interaction* is the right one.
const SpringDescription _kSelectionSpring = SpringDescription(
  mass: 1,
  stiffness: 503.551,
  damping: 44.8799,
);

/// Slides a fixed-shape glass selection between navigation slots.
///
/// Spring-driven, not duration/curve-driven: a plain `TweenAnimationBuilder`
/// re-eases from scratch on every retarget, so two navigation taps close
/// together each restart the same curve and never actually carry the
/// motion already in flight — the opposite of Apple's own interruptibility
/// principle ("always animate from the current on-screen value, and let a
/// new target retarget the existing motion rather than replacing it").
/// This keeps the controller's live velocity across a retarget, so a second
/// tap mid-slide continues from exactly where the lens already is, at the
/// speed it's already moving, instead of snapping back to a standing start.
class RouteXSlidingSelection extends StatefulWidget {
  const RouteXSlidingSelection({
    super.key,
    required this.index,
    required this.extent,
    required this.crossExtent,
    required this.child,
    this.axis = Axis.horizontal,
  });

  final double index;
  final double extent;
  final double crossExtent;
  final Axis axis;
  final Widget child;

  @override
  State<RouteXSlidingSelection> createState() =>
      _RouteXSlidingSelectionState();
}

class _RouteXSlidingSelectionState extends State<RouteXSlidingSelection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // `value` here is a slot index (0, 1, 2, ...), not a 0-1 progress —
    // AnimationController's default bounds are [0, 1], which silently
    // clamped every index past the second slot and left the lens stuck
    // in place for any tab beyond it.
    _controller = AnimationController(
      vsync: this,
      value: widget.index,
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
    );
  }

  @override
  void didUpdateWidget(covariant RouteXSlidingSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      // Not `MediaQuery.maybeOf(context)` here: that registers an
      // InheritedWidget dependency, and this widget's build() never
      // re-declares one on every pass (it doesn't need MediaQuery for
      // anything else), so the one-off read from didUpdateWidget left
      // the framework's dependency bookkeeping inconsistent — it
      // surfaced as a `_dependents.isEmpty` / ancestor-chain assertion
      // crash on rapid tab switches. This reads the same signal with no
      // BuildContext involved at all.
      final reduceMotion = WidgetsBinding
          .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
      if (reduceMotion) {
        _controller.value = widget.index;
      } else {
        // `SpringSimulation` takes the controller's own current value and
        // velocity as its start state, so a tap that lands mid-slide
        // retargets the motion already happening instead of restarting it.
        _controller.animateWith(
          SpringSimulation(
            _kSelectionSpring,
            _controller.value,
            widget.index,
            _controller.velocity,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: horizontal
            ? Offset(widget.extent * _controller.value, 0)
            : Offset(0, widget.extent * _controller.value),
        child: SizedBox(
          width: horizontal ? widget.extent : widget.crossExtent,
          height: horizontal ? widget.crossExtent : widget.extent,
          child: child,
        ),
      ),
      child: RepaintBoundary(child: widget.child),
    );
  }
}
