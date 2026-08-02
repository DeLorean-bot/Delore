import 'package:flutter/material.dart';

/// Slides a fixed-shape glass selection between navigation slots.
///
/// This is deliberately deterministic rather than spring-driven: the lens
/// cannot overshoot, bounce, squash, stretch or carry velocity from a previous
/// navigation action. Its geometry stays unchanged on every frame.
class RouteXSlidingSelection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: index, end: index),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (context, value, child) => Transform.translate(
        offset:
            horizontal ? Offset(extent * value, 0) : Offset(0, extent * value),
        child: SizedBox(
          width: horizontal ? extent : crossExtent,
          height: horizontal ? crossExtent : extent,
          child: child,
        ),
      ),
      child: RepaintBoundary(child: child),
    );
  }
}
