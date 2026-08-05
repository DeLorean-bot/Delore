import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Apple's own critically-damped default for a moving/repositioning UI
/// element (damping 1.0, response 0.4s — see the "Move / reposition"
/// row in the apple-design skill's spring table), translated from the
/// response/damping-ratio model into Flutter's mass/stiffness/damping:
/// `angularFrequency = 2*pi/response`, `stiffness = mass*angularFrequency^2`,
/// `damping = 2*dampingRatio*sqrt(mass*stiffness)`. No bounce — a selection
/// lens settling into place isn't a momentum-driven gesture, so overshoot
/// would read as sloppy rather than physical.
const SpringDescription _kSelectionSpring = SpringDescription(
  mass: 1,
  stiffness: 246.74,
  damping: 31.42,
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
