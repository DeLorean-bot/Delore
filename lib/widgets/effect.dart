import 'dart:ui';

import 'package:flclashx/common/common.dart';
import 'package:flutter/material.dart';

class EffectGestureDetector extends StatefulWidget {

  const EffectGestureDetector({
    super.key,
    required this.child,
    this.onLongPress,
    this.onTap,
  });
  final Widget child;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onTap;

  @override
  State<EffectGestureDetector> createState() => _EffectGestureDetectorState();
}

class _EffectGestureDetectorState extends State<EffectGestureDetector> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    if (_scale != (pressed ? 0.95 : 1)) {
      setState(() => _scale = pressed ? 0.95 : 1);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
      scale: _scale,
      duration: RouteXMotion.resolve(context, RouteXMotion.press),
      curve: RouteXMotion.curve,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        onLongPressStart: (_) => _setPressed(true),
        onLongPressEnd: (_) => _setPressed(false),
        onLongPressCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: widget.child,
      ),
    );
}

class CommonExpandIcon extends StatefulWidget {

  const CommonExpandIcon({
    super.key,
    this.expand = false,
  });
  final bool expand;

  @override
  State<CommonExpandIcon> createState() => _CommonExpandIconState();
}

class _CommonExpandIconState extends State<CommonExpandIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: RouteXMotion.fast,
      vsync: this,
    );
    _iconTurns = _animationController.drive(
      CurveTween(curve: RouteXMotion.curve).chain(
        Tween<double>(begin: 0.0, end: 0.5),
      ),
    );
    if (widget.expand) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CommonExpandIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expand != widget.expand) {
      if (widget.expand) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _animationController.view,
      builder: (_, child) => RotationTransition(
          turns: _iconTurns,
          child: child,
        ),
      child: const Icon(
        Icons.expand_more,
      ),
    );
}

Widget proxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) => AnimatedBuilder(
    animation: animation,
    builder: (_, child) {
      final animValue = Curves.easeInOut.transform(animation.value);
      final scale = lerpDouble(1, 1.02, animValue)!;
      return Transform.scale(
        scale: scale,
        child: child,
      );
    },
    child: child,
  );
