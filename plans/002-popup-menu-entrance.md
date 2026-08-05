# 002 — Fix popup/context-menu entrance: wrong curve, no reduced-motion, too dramatic a scale

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Easing & duration / Accessibility / Physicality & origin
- **Estimated scope**: 1 file (`lib/widgets/popup.dart`)

## Problem

`CommonPopupRoute` is the shared transition for every context menu / popup
in the app (`CommonPopupBox`, `CommonPopupMenu`). Its entrance has three
separate problems in the same 40 lines:

```dart
// lib/widgets/popup.dart:33-78 — current
@override
Widget buildTransitions(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  const align = Alignment.topRight;
  final animationValue = CurvedAnimation(
    parent: animation,
    curve: Curves.easeIn,
  ).value;
  return SafeArea(
    child: ValueListenableBuilder(
      valueListenable: offsetNotifier,
      builder: (_, value, child) => Align(
          alignment: align,
          child: CustomSingleChildLayout(
            delegate: OverflowAwareLayoutDelegate(
              offset: value.translate(
                48,
                -8,
              ),
            ),
            child: child,
          ),
        ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Opacity(
            opacity: 0.1 + 0.9 * animationValue,
            child: Transform.scale(
              alignment: align,
              scale: 0.7 + 0.3 * animationValue,
              child: Transform.translate(
                offset: const Offset(0, -10) * (1 - animationValue),
                child: child,
              ),
            ),
          ),
        child: builder(
          context,
        ),
      ),
    ),
  );
}

@override
Duration get transitionDuration => const Duration(milliseconds: 150);
```

1. `Curves.easeIn` (line 39) starts slow — on an entrance, this delays the
   exact moment the user is watching for. Entrances should ease **out**.
2. No `disableAnimations`/reduced-motion check anywhere in the route.
3. `scale: 0.7 + 0.3 * animationValue` (line 62) scales in from 0.7, well
   below the 0.9–0.97 range that reads as "materializing" rather than
   "popping."

There's a fourth, subtler bug caused by #1: `animationValue` is computed
**once**, synchronously, at the top of `buildTransitions` by reading
`CurvedAnimation(...).value` directly instead of listening to it — meaning
the curve is sampled only at the instant `buildTransitions` runs, not on
every animation tick. This currently sort of accidentally works because
`AnimatedBuilder` still rebuilds on `animation`'s ticks and recomputes
`Transform.scale`'s `scale:` — but it drives the transform off the **raw
linear** `animation` value there, not `animationValue`. Read again closely:
`Opacity`'s `opacity:` uses the stale `animationValue` (computed once,
never updates after the first frame), while `Transform.scale`/`Transform.translate`
inside the same builder both use it too — meaning the fade and the
scale/translate are **not actually animating per-frame at all**; they are
frozen at whatever `animationValue` was on the very first build. Only
`AnimatedBuilder`'s rebuild-on-tick behavior gives the *appearance* of
motion via other means, but this needs to be fixed to genuinely animate.

## Target

```dart
// target
@override
Widget buildTransitions(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  const align = Alignment.topRight;
  final curved = CurvedAnimation(
    parent: animation,
    curve: RouteXMotion.curve,
  );
  return SafeArea(
    child: ValueListenableBuilder(
      valueListenable: offsetNotifier,
      builder: (_, value, child) => Align(
          alignment: align,
          child: CustomSingleChildLayout(
            delegate: OverflowAwareLayoutDelegate(
              offset: value.translate(
                48,
                -8,
              ),
            ),
            child: child,
          ),
        ),
      child: AnimatedBuilder(
        animation: curved,
        builder: (_, child) => Opacity(
            opacity: 0.1 + 0.9 * curved.value,
            child: Transform.scale(
              alignment: align,
              scale: 0.92 + 0.08 * curved.value,
              child: Transform.translate(
                offset: const Offset(0, -10) * (1 - curved.value),
                child: child,
              ),
            ),
          ),
        child: builder(
          context,
        ),
      ),
    ),
  );
}

@override
Duration get transitionDuration =>
    RouteXMotion.resolve(_lastContext, const Duration(milliseconds: 150));
```

`transitionDuration` is a getter with no `BuildContext` parameter available
from the framework, so `RouteXMotion.resolve` (which needs a `context`)
can't be called directly there — see Steps below for how this route already
has a context available at the point it's pushed, and the correct place to
apply the gate.

## Repo conventions to follow

- `RouteXMotion.curve` and `RouteXMotion.resolve(context, duration)` live in
  `lib/common/premium_theme.dart`.
- Exemplar for gating a `PopupRoute`/`PageRoute`'s duration via the pushing
  context (not the route's own `buildTransitions` context, which arrives
  after the route is already committed to animate): none in this codebase
  yet for a `PopupRoute` specifically, but `CommonDesktopRoute`
  (`lib/common/navigator.dart:73-77`) shows the same "duration is a fixed
  getter, no `BuildContext` at that point" shape — this route is a
  deliberate faithful port of Cupertino's iOS transition and is
  intentionally out of scope for this plan (do not modify
  `navigator.dart`).

## Steps

1. In `lib/widgets/popup.dart`, add a nullable field to `CommonPopupRoute`:
   `BuildContext? _reduceMotionContext;` is unnecessary — instead, capture
   the reduced-motion flag once, at construction time, from the context
   that pushes the route (`_CommonPopupBoxState._open`, around line 120,
   which already has `context` in scope). Add a `required this.reduceMotion`
   constructor parameter to `CommonPopupRoute`:
   ```dart
   CommonPopupRoute({
     required this.barrierLabel,
     required this.builder,
     required this.offsetNotifier,
     required this.reduceMotion,
   });
   final bool reduceMotion;
   ```
2. In `_CommonPopupBoxState._open` (`lib/widgets/popup.dart:116-131`), pass
   `reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false`
   when constructing `CommonPopupRoute`.
3. Change `transitionDuration` (line 77-78) to:
   ```dart
   @override
   Duration get transitionDuration =>
       reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
   ```
4. In `buildTransitions` (lines 33-75): replace the `animationValue` local
   with a `curved` `CurvedAnimation` (curve: `RouteXMotion.curve` instead of
   `Curves.easeIn`), pass it as the `animation:` argument to the inner
   `AnimatedBuilder` (instead of the raw `animation`), and read
   `curved.value` inside the builder instead of the old frozen
   `animationValue`. Change the scale range from `0.7 + 0.3 * ...` to
   `0.92 + 0.08 * ...`.
5. Confirm `CommonPopupMenu` and any other caller of `CommonPopupRoute`
   still compile — the only call site should be `_CommonPopupBoxState._open`,
   already updated in step 2.

## Boundaries

- Do NOT touch `CommonPopupMenu`'s item styling, `OverflowAwareLayoutDelegate`,
  or `_updateOffset`.
- Do NOT touch `lib/common/navigator.dart` — its transitions are a
  deliberate Cupertino-faithful port and out of scope.
- Do NOT add a dependency.
- If `lib/widgets/popup.dart:33-78` or `_CommonPopupBoxState._open` don't
  match the excerpts above (drift since `b1c6223`), STOP and report instead
  of improvising.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/popup.dart` — expect 0 new
  errors.
- **Feel check**: open any context menu / popup in the app (e.g. the
  profile switcher's overflow menu, or any `CommonPopupBox` call site —
  grep for `CommonPopupBox(` to find one):
  - The menu now grows in with a quick, confident settle (ease-out feel),
    not a hesitant slow start.
  - It visibly appears near-full-size almost immediately rather than
    popping from a small dot — set DevTools playback to 10% and confirm the
    scale starts around 92%, not 70%.
  - Toggle reduced motion and confirm the popup appears instantly (no
    animated scale/fade) but is still fully legible immediately (no
    stuck-at-0.1-opacity frame).
  - Open/close the same menu rapidly several times — no visual glitch or
    frozen mid-transition frame (this also confirms the `animationValue`
    per-frame bug from the Problem section is actually fixed, not just
    coincidentally still working).
- **Done when**: the popup entrance uses `RouteXMotion.curve`, starts scale
  at 0.92, and is instant under reduced motion.
