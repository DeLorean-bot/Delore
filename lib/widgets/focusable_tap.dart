import 'package:flclashx/common/common.dart';
import 'package:flutter/material.dart';

/// A tappable area reachable by a D-pad/remote (Android TV) and legible on
/// desktop, where mice hover but Flutter's default gesture detectors give no
/// visual feedback for it.
///
/// Bare `GestureDetector`s have no focus node and don't respond to
/// D-pad-center/Enter, so a TV remote can't reach them; they also don't
/// react to a mouse hovering without extra plumbing. This adds a focus ring,
/// a hover lift, and activates [onTap] on tap or Enter/Select alike.
class RouteXFocusableTap extends StatefulWidget {
  const RouteXFocusableTap({
    super.key,
    required this.onTap,
    required this.child,
    this.autofocus = false,
    this.borderRadius = 18,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool autofocus;
  final double borderRadius;

  @override
  State<RouteXFocusableTap> createState() => _RouteXFocusableTapState();
}

class _RouteXFocusableTapState extends State<RouteXFocusableTap> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus && enabled,
      onShowFocusHighlight: (value) {
        if (mounted && value != _focused) setState(() => _focused = value);
      },
      onShowHoverHighlight: (value) {
        if (mounted && value != _hovered) setState(() => _hovered = value);
      },
      mouseCursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      // No explicit Map<Type, Action<Intent>> annotation: `Action` is
      // ambiguous here (flclashx models also export an `Action` class).
      // Context inference from FocusableActionDetector.actions gives the
      // right type without naming it.
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      // Focus ring only — no scale-up. AnimatedScale painted outside the
      // layout bounds, so a full-width autofocused control (the connect
      // button on desktop) spilled past the window edges once 1.5% of its
      // width exceeded a 16px side padding.
      child: AnimatedContainer(
        duration: RouteXMotion.resolve(context, RouteXMotion.fast),
        curve: RouteXMotion.curve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius + 4),
          border: Border.all(
            color: _focused ? context.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        // Hover lifts the control rather than outlining it: a pointer
        // resting on glass should read as the material catching a little
        // more light, not as a box being drawn around it.
        child: AnimatedScale(
          scale: _hovered && enabled ? 1.015 : 1,
          duration: RouteXMotion.resolve(context, RouteXMotion.fast),
          curve: RouteXMotion.curve,
          child: AnimatedOpacity(
            opacity: _hovered && enabled ? 1 : 0.88,
            duration: RouteXMotion.resolve(context, RouteXMotion.fast),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
