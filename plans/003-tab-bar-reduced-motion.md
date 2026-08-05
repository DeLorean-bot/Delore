# 003 — Respect reduced motion in the segmented tab control

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Accessibility
- **Estimated scope**: 1 file (`lib/widgets/tab.dart`)

## Problem

`CommonTabBar` (the segmented control switching Connections/Logs views,
among others) is a hand-ported, physically faithful recreation of Flutter's
own `CupertinoSlidingSegmentedControl` — the spring constants
(`SpringDescription(mass: 1, stiffness: 503.551, damping: 44.8799)`), the
`_kMinThumbScale = 0.95` press-scale, and the multi-controller architecture
(`thumbController`, `thumbScaleController`, `highlightPressScaleController`,
`separatorOpacityController`) all match Apple's own component precisely.

**This plan does not touch that physics** — it is deliberate and correct,
and matches this app's Apple-design goal better than any generic token
would. The one real gap: none of the four `AnimationController`s check
`disableAnimations` anywhere in the file, so a user with Reduce Motion on
gets the full spring/slide treatment regardless.

```dart
// lib/widgets/tab.dart:128-136 — current (thumb slide on selection change)
@override
void didUpdateWidget(CommonTabBar<T> oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (!isThumbDragging && highlighted != widget.groupValue) {
    thumbController.animateWith(_kThumbSpringAnimationSimulation);
    thumbAnimatable = null;
    highlighted = widget.groupValue;
  }
}
```

```dart
// lib/widgets/tab.dart:446-461 — current (per-segment press scale)
@override
void didUpdateWidget(_Segment<T> oldWidget) {
  super.didUpdateWidget(oldWidget);
  assert(oldWidget.key == widget.key);

  if (oldWidget.shouldScaleContent != widget.shouldScaleContent) {
    highlightPressScaleAnimation = highlightPressScaleController.drive(
      Tween<double>(
        begin: highlightPressScaleAnimation.value,
        end: widget.shouldScaleContent ? _kMinThumbScale : 1.0,
      ),
    );
    highlightPressScaleController
        .animateWith(_kThumbSpringAnimationSimulation);
  }
}
```

## Target

Reduced motion should mean the thumb (and press-scale) jump straight to
their end value instead of animating — matching the "fewer/gentler, not
zero" rule (the color/opacity feedback in `_Segment.build` stays as-is; only
the movement is skipped).

```dart
// target — lib/widgets/tab.dart:128-136
@override
void didUpdateWidget(CommonTabBar<T> oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (!isThumbDragging && highlighted != widget.groupValue) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      thumbController.value = 1;
    } else {
      thumbController.animateWith(_kThumbSpringAnimationSimulation);
    }
    thumbAnimatable = null;
    highlighted = widget.groupValue;
  }
}
```

```dart
// target — lib/widgets/tab.dart:446-461
@override
void didUpdateWidget(_Segment<T> oldWidget) {
  super.didUpdateWidget(oldWidget);
  assert(oldWidget.key == widget.key);

  if (oldWidget.shouldScaleContent != widget.shouldScaleContent) {
    final target = widget.shouldScaleContent ? _kMinThumbScale : 1.0;
    highlightPressScaleAnimation = highlightPressScaleController.drive(
      Tween<double>(
        begin: highlightPressScaleAnimation.value,
        end: target,
      ),
    );
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      highlightPressScaleController.value = 1;
    } else {
      highlightPressScaleController
          .animateWith(_kThumbSpringAnimationSimulation);
    }
  }
}
```

Note `thumbController.value = 1`/`highlightPressScaleController.value = 1`
jumps to the **end** of whatever `Tween` is currently driving that
controller (both controllers are driven 0→1 against a `Tween` that already
targets the new state) — check the current `thumbAnimatable`/
`highlightPressScaleAnimation` setup immediately above each `didUpdateWidget`
in the real file before assuming `.value = 1` is correct; if either
controller is instead driven backwards (1→0) in some code path, the reduced-
motion jump target must be `0` there, not `1`. Verify against the actual
`thumbAnimatable`/animation direction at the time you make this edit.

Apply the same pattern to `_SegmentSeparatorState.didUpdateWidget`
(around `lib/widgets/tab.dart:544-...` — read the method in full before
editing, it wasn't fully quoted here) for `separatorOpacityController`.

## Repo conventions to follow

- Reduced motion check: `MediaQuery.maybeOf(context)?.disableAnimations ?? false`
  — used as-is (not through `RouteXMotion.resolve`, since that helper
  returns a `Duration` and these controllers are driven by
  `animateWith(SpringSimulation)`, which has no duration parameter to gate).
- Exemplar for the same "if reduced motion, jump to end value" shape:
  none currently in this codebase — this is a new but small pattern,
  consistent with `RouteXBackdrop`'s existing `_motionEnabled` gate
  (`lib/widgets/routex_backdrop.dart:49`), which stops animating entirely
  rather than partially.

## Steps

1. Read `lib/widgets/tab.dart` in full around lines 84-260 (`_CommonTabBarState`)
   and 427-560 (`_SegmentState`, `_SegmentSeparatorState`) to confirm the
   current shape of each `didUpdateWidget` matches what's quoted above —
   this file may have minor differences from the excerpts (they were
   condensed for this plan).
2. Apply the reduced-motion branch to `_CommonTabBarState.didUpdateWidget`
   (thumb position) as shown in Target.
3. Apply the same branch to `_SegmentState.didUpdateWidget` (press scale)
   as shown in Target.
4. Apply the same branch to `_SegmentSeparatorState.didUpdateWidget`
   (separator opacity) — mirror the pattern, jumping
   `separatorOpacityController.value` to whatever its target end-state is
   for the given `highlighted` transition.
5. Do NOT touch the initial `AnimationController` constructions (lines
   86-100, 435-443, 537-541) — only the `didUpdateWidget` re-trigger paths.

## Boundaries

- Do NOT change `_kThumbSpringAnimationSimulation`, `_kMinThumbScale`, or
  any of the named duration constants (`_kSpringAnimationDuration`,
  `_kOpacityAnimationDuration`, `_kHighlightAnimationDuration`) — these are
  a deliberate Cupertino-accurate port, not ad-hoc values to consolidate
  onto `RouteXMotion`.
- Do NOT touch `AnimatedOpacity`/`AnimatedDefaultTextStyle` in `_Segment.build`
  (lines 482-505) — those already animate via implicit widgets that are
  interruptible by construction; only the explicit `AnimationController`
  re-triggers need the reduced-motion branch.
- If the actual `didUpdateWidget` bodies differ meaningfully from what's
  quoted here (drift since `b1c6223`), STOP and report instead of
  improvising — getting the jump-to-value direction wrong (0 vs 1) would
  make the control silently stick in the wrong visual state under reduced
  motion, which is worse than the current behavior.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/tab.dart` — expect 0 new
  errors.
- **Feel check**: find a `CommonTabBar` call site (grep for `CommonTabBar<`
  — Connections/Logs view switcher is one) and, with reduced motion OFF,
  confirm the thumb still slides with its spring bounce exactly as before
  (no regression). Then toggle reduced motion ON and confirm:
  - Tapping a different segment jumps the thumb there instantly, no slide.
  - Pressing and holding a segment still shows *some* feedback (the opacity
    dip in `_Segment.build`), just without the scale animating in.
  - No segment gets stuck mid-transition or at the wrong scale/position
    after toggling reduced motion mid-interaction.
- **Done when**: all three controllers (`thumbController`,
  `highlightPressScaleController`, `separatorOpacityController`) skip their
  spring animation and jump to the correct end value when
  `disableAnimations` is true, with zero change to the non-reduced-motion
  feel.
