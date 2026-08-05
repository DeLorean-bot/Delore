# 007 — Give RouteXFocusableTap a real press state (Connect button, location chip)

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Physicality & origin
- **Estimated scope**: 1 file (`lib/widgets/focusable_tap.dart`)

## Problem

`RouteXFocusableTap` wraps the dashboard's Connect/Disconnect button and
the location chip (among other controls). Its only interactive state is
`_hovered` (mouse-only) and `_focused` (keyboard/D-pad) — there is no
`_pressed` state at all:

```dart
// lib/widgets/focusable_tap.dart:30-93 — current
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
```

On a touch device (no mouse, so `_hovered` never becomes true), tapping the
Connect button or the location chip gives **zero** visual response until
the resulting state change (page navigation, connection status flip)
arrives.

The existing comment explains why the *outer* `AnimatedScale` (the one at
1.015, scaling the border+content together) was deliberately kept modest:
scaling a full-width control **up** pushed it past the window edge. That
constraint is specific to scaling **up**; a press-down scale (< 1) never
exceeds the control's own original footprint, so it doesn't carry the same
risk — but to stay safely clear of that documented issue entirely, the
press scale in this plan is applied to the innermost content layer only
(inside the opacity/border layers), never to the outer bordered container.

## Target

```dart
// target — lib/widgets/focusable_tap.dart:30-94
class _RouteXFocusableTapState extends State<RouteXFocusableTap> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

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
        child: AnimatedScale(
          scale: _hovered && enabled ? 1.015 : 1,
          duration: RouteXMotion.resolve(context, RouteXMotion.fast),
          curve: RouteXMotion.curve,
          child: AnimatedOpacity(
            opacity: _hovered && enabled ? 1 : 0.88,
            duration: RouteXMotion.resolve(context, RouteXMotion.fast),
            child: AnimatedScale(
              // Press-down only, never past the control's original
              // footprint — safe from the overflow issue noted above,
              // which was specific to scaling up.
              scale: _pressed && enabled ? 0.97 : 1,
              duration: RouteXMotion.resolve(context, RouteXMotion.press),
              curve: RouteXMotion.curve,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onTapDown: enabled ? (_) => _setPressed(true) : null,
                onTapUp: enabled ? (_) => _setPressed(false) : null,
                onTapCancel: enabled ? () => _setPressed(false) : null,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

## Repo conventions to follow

- `RouteXMotion.press` (120ms) is the token for press-feedback duration;
  `RouteXMotion.resolve(context, duration)` is the reduced-motion gate —
  both already used elsewhere in this exact file for the hover/focus
  states, so the new press `AnimatedScale` follows the file's own existing
  pattern precisely.

## Steps

1. In `lib/widgets/focusable_tap.dart`, add the `bool _pressed = false;`
   field and `_setPressed` helper to `_RouteXFocusableTapState`.
2. Wrap the existing `GestureDetector` in a new innermost `AnimatedScale`
   (scale `0.97` when pressed and enabled, `1` otherwise; duration
   `RouteXMotion.resolve(context, RouteXMotion.press)`; curve
   `RouteXMotion.curve`) as shown in Target — this new layer goes *inside*
   `AnimatedOpacity`, wrapping only the `GestureDetector`, not the border
   container or the hover-scale layer.
3. Add `onTapDown`/`onTapUp`/`onTapCancel` to the existing `GestureDetector`,
   each gated on `enabled` (matching the existing `mouseCursor:` ternary's
   `enabled` check style), calling `_setPressed(true)`/`_setPressed(false)`.
4. Leave `onTap: widget.onTap`, the focus ring container, and the hover
   scale/opacity layers completely unchanged.

## Boundaries

- Do NOT change the outer `AnimatedScale`'s hover value (`1.015`) or the
  `AnimatedContainer`'s border logic — those are documented, deliberate,
  and out of scope.
- Do NOT remove or alter the existing overflow-avoidance comment; if
  anything, its scoping note ("no scale-up") stays accurate since this
  plan only adds a scale-down layer.
- Do NOT add a dependency.
- If `lib/widgets/focusable_tap.dart`'s current content doesn't match the
  excerpt above (drift since `b1c6223`), STOP and report instead of
  improvising.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/focusable_tap.dart` —
  expect 0 new errors.
- **Feel check**: run the app on Windows in a narrow/mobile-width window
  (per this session's own compact-layout testing approach: resize below
  ~600px), find the Connect button and the location chip
  (`lib/views/dashboard/dashboard_scene.dart` — both are wrapped in
  `RouteXFocusableTap` per this file's doc comment), and:
  - Click-and-hold the Connect button — it should visibly compress
    slightly and hold that state until release, independent of hover.
  - Drag the pointer off the button while still held down (simulating a
    cancelled tap) — the button should recover to scale 1 without firing
    `onTap`.
  - On the desktop-width layout, confirm the button never visibly exceeds
    its original footprint or clips against the window edge at any point
    during a press (this directly re-verifies the overflow constraint from
    the code comment is still respected).
  - Toggle reduced motion and confirm the press-down still visually
    registers (jumps instantly to 0.97 and back) rather than disappearing
    entirely.
- **Done when**: both the Connect button and the location chip visibly
  respond to a plain tap/click-down, with no regression to the existing
  hover-lift or focus-ring behavior.
