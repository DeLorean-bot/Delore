# 006 — Make EffectGestureDetector respond to normal taps, not just long-press

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Purpose & frequency / Performance / Cohesion & tokens
- **Estimated scope**: 1 file (`lib/widgets/effect.dart`)

## Problem

`EffectGestureDetector` is a generic press-feedback wrapper used across
roughly ten call sites. Its entire purpose is tactile feedback on press —
but it only reacts to long-press, never a normal tap:

```dart
// lib/widgets/effect.dart:21-59 — current
class _EffectGestureDetectorState extends State<EffectGestureDetector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
      scale: _scale,
      duration: kThemeAnimationDuration,
      curve: Curves.easeOut,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        onLongPressStart: (_) {
          setState(() {
            _scale = 0.95;
          });
        },
        onTap: widget.onTap,
        onLongPressEnd: (_) {
          setState(() {
            _scale = 1;
          });
        },
        child: widget.child,
      ),
    );
}
```

Three separate problems in the same widget:
1. `onTap` (the common case, used far more than `onLongPress`) never
   touches `_scale` — a plain tap gives zero visual feedback.
2. `_controller` is constructed and disposed but never `.forward()`/
   `.reverse()`/listened to anywhere — a wasted `Ticker` on every instance.
3. `kThemeAnimationDuration`/`Curves.easeOut` are Material framework
   defaults, not this app's own `RouteXMotion.press`/`RouteXMotion.curve`
   tokens used for identical press-scale feedback elsewhere (e.g.
   `hero_nav_bar.dart`'s `_LiquidNavItem`).

Same file also has a smaller, unrelated but trivial-to-batch fix:

```dart
// lib/widgets/effect.dart:82-92 — current
_animationController = AnimationController(
  duration: const Duration(milliseconds: 200),
  vsync: this,
);
_iconTurns = _animationController.drive(
  Tween<double>(begin: 0.0, end: 0.5),
);
```

`CommonExpandIcon`'s rotation drives a bare `Tween` with no `CurvedAnimation`
at all — it turns linearly, and its duration doesn't reuse `RouteXMotion.fast`
(160ms, closest existing token to 200ms).

## Target

```dart
// target — lib/widgets/effect.dart:21-58
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
```

Note the `SingleTickerProviderStateMixin`, `_controller` field, and
`initState`/`dispose` overrides are removed entirely — `AnimatedScale`
already manages its own internal animation; the unused `_controller` was
dead weight, not a second layer of control.

```dart
// target — lib/widgets/effect.dart:82-92
_animationController = AnimationController(
  duration: RouteXMotion.fast,
  vsync: this,
);
_iconTurns = _animationController.drive(
  CurveTween(curve: RouteXMotion.curve).chain(
    Tween<double>(begin: 0.0, end: 0.5),
  ),
);
```

## Repo conventions to follow

- `RouteXMotion.press`, `RouteXMotion.fast`, `RouteXMotion.curve`, and
  `RouteXMotion.resolve(context, duration)` all live in
  `lib/common/premium_theme.dart`.
- Exemplar for a tap-driven press scale using this exact token set:
  `lib/views/dashboard/widgets/hero_nav_bar.dart:278-281`.
- `Tween.chain(CurveTween(...))` ordering: the curve should wrap the tween
  (`CurveTween(...).chain(Tween(...))` reads as "apply curve, then map
  through tween" in Flutter's `Animatable.chain` — verify against another
  existing `.chain(CurveTween(` call in this codebase, e.g.
  `fade_box.dart:156`, before finalizing which order you write).

## Steps

1. In `lib/widgets/effect.dart`, replace
   `_EffectGestureDetectorState`'s entire body (lines 21-59) with the
   Target version: drop `with SingleTickerProviderStateMixin`, the
   `_controller` field, `initState`, and `dispose`; add the `_setPressed`
   helper; wire `onTapDown`/`onTapUp`/`onTapCancel` alongside the existing
   `onLongPressStart`/`onLongPressEnd` (also add `onLongPressCancel` for
   symmetry, currently missing); change `AnimatedScale`'s `duration`/`curve`
   to the `RouteXMotion` tokens.
2. In `_CommonExpandIconState.initState` (lines 79-92), change the
   controller's `duration` to `RouteXMotion.fast` and wrap the `Tween` in a
   `CurveTween(curve: RouteXMotion.curve)` as shown in Target — double-check
   the `.chain(...)` argument order against `fade_box.dart:156`'s existing
   usage so the curve is applied correctly (verify by feel-check below, not
   just by reading).
3. Confirm `lib/widgets/effect.dart`'s imports still resolve —
   `RouteXMotion` needs `flclashx/common/common.dart` (or wherever
   `premium_theme.dart` is re-exported from); this file currently imports
   only `dart:ui` and `package:flutter/material.dart` (lines 1-3), so add
   the missing import.

## Boundaries

- Do NOT touch `proxyDecorator` (lines 119-134) — its `Curves.easeInOut`
  drag-lift scale is a separate, already-reasonable pattern not in scope
  here (see plan 009 if it needs token consolidation later).
- Do NOT add a dependency.
- If the current file content doesn't match what's quoted above (drift
  since `b1c6223`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/effect.dart` — expect 0 new
  errors. Also run `flutter analyze` more broadly if any call site of
  `EffectGestureDetector` breaks from the constructor/API staying the same
  (it should — only internal state changed, not the public API).
- **Feel check**: find any `EffectGestureDetector(` call site (grep the
  repo) and tap it normally (not long-press):
  - The wrapped content now visibly compresses ~5% on tap-down and
    recovers on release, matching the existing long-press behavior.
  - Long-press still works exactly as before (no regression).
  - Rapidly tap several times — no stuck scale, no exception from
    `setState` after unmount (drag off the widget mid-press to trigger
    `onTapCancel` and confirm it recovers too).
  - For `CommonExpandIcon` (grep call sites), expand/collapse and confirm
    the chevron rotation now eases rather than rotating at a constant rate.
- **Done when**: `EffectGestureDetector` gives scale feedback on ordinary
  taps, the dead `AnimationController` is removed, and both animations in
  this file use `RouteXMotion` tokens.
