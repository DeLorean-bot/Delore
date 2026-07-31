import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/widgets/scroll.dart';
import 'package:flutter/material.dart';

class BaseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        if (system.isDesktop) PointerDeviceKind.mouse,
        PointerDeviceKind.unknown,
      };

  // The platform default on Windows/Linux/Android is plain
  // ClampingScrollPhysics — a hard, instant stop at each end with no
  // settle. NextClampingScrollPhysics (below) was already written and
  // proven out in the logs and requests views; applying it as the app's
  // actual default physics is what makes every list — proxies, settings,
  // applications, connections — decelerate with a soft spring instead of
  // just stopping, instead of only those two screens having it.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const NextClampingScrollPhysics();
    }
  }
}

class HiddenBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class ShowBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => CommonAutoHiddenScrollBar(
      controller: details.controller,
      child: child,
    );
}

class NextClampingScrollPhysics extends ClampingScrollPhysics {
  const NextClampingScrollPhysics({super.parent});

  @override
  NextClampingScrollPhysics applyTo(ScrollPhysics? ancestor) => NextClampingScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }
      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }
      assert(end != null);
      return ScrollSpringSimulation(
        spring,
        end!,
        end,
        min(0.0, velocity),
        tolerance: tolerance,
      );
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
  }
}

// Flutter's own mouse-wheel handling (ScrollPositionWithSingleContext.
// pointerScroll) calls forcePixels on every tick — an instant jump, not an
// animation. There's no ScrollBehavior/ScrollPhysics hook for this (it's
// hardcoded on ScrollPosition), so the only way to change it is a custom
// ScrollPosition, the same pattern ReverseScrollPosition below already
// uses for a different purpose. Wire a SmoothScrollController into a
// list's `controller:` to make its wheel scroll ease instead of step —
// chained ticks retarget the in-flight animation rather than queuing, so
// fast scrolling still feels continuous rather than laggy.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
}

class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }
    final targetPixels = min(
      max(pixels + delta, minScrollExtent),
      maxScrollExtent,
    );
    if (targetPixels == pixels) return;
    unawaited(animateTo(
      targetPixels,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    ));
  }
}

class ReverseScrollController extends ScrollController {
  ReverseScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => ReverseScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
}

class ReverseScrollPosition extends ScrollPositionWithSingleContext {
  ReverseScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _isInit = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (!_isInit) {
      correctPixels(maxScrollExtent);
      _isInit = true;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
