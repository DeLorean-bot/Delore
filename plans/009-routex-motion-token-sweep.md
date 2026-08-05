# 009 — Consolidate ad-hoc durations/curves/radii onto RouteXMotion/RouteXRadius

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: MEDIUM/LOW (cluster of 11 sites)
- **Category**: Cohesion & tokens
- **Estimated scope**: 9 files, one-line value swaps

## Problem

`RouteXMotion` (`lib/common/premium_theme.dart:15-26`:
`press`=120ms, `fast`=160ms, `base`=220ms, `navigation`=300ms,
`curve`=`Cubic(0.16, 1, 0.3, 1)`) and `RouteXRadius`
(`lib/common/premium_theme.dart:28-39`: `control`=12, `card`=16,
`overlay`=22, `navigation`=26) exist specifically so the whole app moves
and rounds with one vocabulary. Eleven sites across nine files still carry
independently hand-typed values — several numerically identical to an
existing token, meaning this is a pure reference swap with zero visual
change; a few are close-but-not-identical, meaning the swap is a small,
deliberate tightening.

Each site below is independent — apply them one at a time, in any order.

1. `lib/views/dashboard/widgets/hero_nav_bar.dart:289-292` — bottom nav tap
   feedback:
   ```dart
   duration: reduceMotion ? Duration.zero : RouteXMotion.press,
   curve: Curves.easeOut,
   ```
   → change `curve: Curves.easeOut` to `curve: RouteXMotion.curve`.

2. `lib/widgets/routex_jelly_selection.dart:29-33` — the sliding selection
   lens shared by the sidebar and bottom nav:
   ```dart
   return TweenAnimationBuilder<double>(
     tween: Tween<double>(begin: index, end: index),
     duration:
         reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
     curve: const Cubic(0.16, 1, 0.3, 1),
   ```
   → change `const Duration(milliseconds: 220)` to `RouteXMotion.base` and
   `const Cubic(0.16, 1, 0.3, 1)` to `RouteXMotion.curve`. Add
   `import 'package:flclashx/common/common.dart';` (or wherever
   `premium_theme.dart` is re-exported from — check this file's existing
   imports) if `RouteXMotion` isn't already reachable.

3. `lib/pages/home.dart:89` — the page-switch `AnimatedSwitcher`, the
   highest-frequency transition in the app:
   ```dart
   switchOutCurve: Curves.easeIn,
   ```
   → change to `switchOutCurve: RouteXMotion.curve,`. Read the surrounding
   `AnimatedSwitcher(` call (a few lines above line 89) first to check
   whether `switchInCurve` is set nearby and already correct — only change
   `switchOutCurve`.

4. `lib/widgets/scaffold.dart:945-951` — dashboard blur/dim crossfade on
   every dashboard enter/exit, currently:
   ```dart
   const Duration(milliseconds: 280),
   ```
   → change to `RouteXMotion.base` (220ms — closer to the original 280ms
   than `navigation`'s 300ms, and this is a frequent transition where the
   snappier token fits the "stays crisp" personality established
   elsewhere). Read the full statement around line 945-951 first — this is
   a positional argument, not a named one, so confirm what constructor/call
   it belongs to before editing.

5. `lib/views/applications/applications_scene.dart:297-300` — refresh-icon
   spin:
   ```dart
   icon: AnimatedRotation(
     turns: refreshing ? 1 : 0,
     duration: const Duration(milliseconds: 700),
   ```
   → change `700` to `RouteXMotion.navigation.inMilliseconds` (300) — i.e.
   `duration: RouteXMotion.navigation,`. This is a real reduction in spin
   speed (700ms → 300ms); if a full rotation reads oddly fast, the correct
   fallback is `RouteXMotion.navigation * 2` (600ms) with a comment
   explaining why — try the plain token first and feel-check.

6. `lib/manager/window_manager.dart:383` — window-control hover fill:
   ```dart
   duration: const Duration(milliseconds: 150),
   ```
   → change to `RouteXMotion.fast` (160ms — closest token; 10ms difference
   is imperceptible). Confirm `RouteXMotion` is reachable from this file's
   imports; add if missing.

7. `lib/views/proxies/card.dart:277-279` — favorite-star opacity fade:
   ```dart
   Widget build(BuildContext context) => AnimatedOpacity(
         duration: RouteXMotion.fast,
         opacity: _favorite ? 1 : (_loaded ? 0.48 : 0),
   ```
   → add `curve: RouteXMotion.curve,` (currently missing entirely, so this
   animates with the implicit-widget default `Curves.linear`).

8. `lib/views/applications/domain_routing.dart:442` — favicon fade-in:
   ```dart
   fadeInDuration: const Duration(milliseconds: 150),
   ```
   → change to `fadeInDuration: RouteXMotion.fast,`.

9. `lib/widgets/super_grid.dart:122,127,142,640` — drag-reorder grid
   transforms:
   ```dart
   // line 122 and 142 and 640, each independently:
   duration: commonDuration,
   // line 127:
   duration: const Duration(milliseconds: 120),
   ```
   → change every `commonDuration` reference among these four (300ms) to
   `RouteXMotion.navigation` (also 300ms — a pure reference swap, no visual
   change). Change the `120`ms shake-controller duration at line 127 to
   `RouteXMotion.press` (also 120ms — same reasoning). **Do not** touch the
   shake `Curves.easeInOut` at line 136, or the shake's `repeat(reverse: true)`
   call at line 425 — the jiggle-mode wiggle (grid items shaking to
   indicate they're reorderable, iOS-springboard-style) is a deliberate,
   distinct motion signature and its curve is not a candidate for the
   general-purpose `RouteXMotion.curve`.

10. `lib/widgets/animate_grid.dart:14-15` — grid entrance/reflow defaults:
    ```dart
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    ```
    → change to `this.duration = RouteXMotion.navigation,` and
    `this.curve = RouteXMotion.curve,`. Add the `RouteXMotion` import to
    this file (currently only imports `package:flutter/material.dart`).

11. Radius normalization — two sites, each a `BorderRadius.circular(N)` not
    on the `RouteXRadius` scale (control=12, card=16, overlay=22,
    navigation=26):
    - `lib/widgets/card.dart:87` — `CommonCard`'s default parameter
      `this.radius = 18` → change to `this.radius = RouteXRadius.card` (16).
    - `lib/widgets/card.dart:252` — `SettingsBlock`'s inner `Card`'s
      `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), ...)`
      → change `20` to `RouteXRadius.overlay` (22 — the closer of the two
      neighboring scale values to the original 20, minimizing visual change).

## Target

Each numbered item above already states its exact before/after — this
section is intentionally folded into Problem since every site is a small,
independent one-line value swap rather than a structural change worth
re-stating separately.

## Repo conventions to follow

- `RouteXMotion`/`RouteXRadius` both live in `lib/common/premium_theme.dart`
  and are re-exported through `flclashx/common/common.dart` (confirm the
  exact export path from an already-working import in a file that uses
  `RouteXMotion` today, e.g. `lib/views/dashboard/widgets/hero_nav_bar.dart:1`).
- Exemplar for the whole sweep's spirit: `lib/views/proxies/card.dart:278`
  already does this correctly for `duration`, just not `curve` — item 7
  above is the smallest, safest site to start with.

## Steps

Apply items 1 through 11 above in `lib/views/dashboard/widgets/hero_nav_bar.dart`,
`lib/widgets/routex_jelly_selection.dart`, `lib/pages/home.dart`,
`lib/widgets/scaffold.dart`, `lib/views/applications/applications_scene.dart`,
`lib/manager/window_manager.dart`, `lib/views/proxies/card.dart`,
`lib/views/applications/domain_routing.dart`, `lib/widgets/super_grid.dart`,
`lib/widgets/animate_grid.dart`, and `lib/widgets/card.dart` (two sites)
respectively — one file at a time, re-reading each cited line immediately
before editing it to confirm it still matches the excerpt.

## Boundaries

- Do NOT touch `_kThumbSpringAnimationSimulation`/spring constants anywhere
  (`tab.dart`, already covered by plan 003) — not in scope here regardless
  of what any earlier audit pass may have suggested.
- Do NOT touch `super_grid.dart`'s shake curve/repeat behavior (see item 9)
  — only its two duration constants.
- Do NOT touch `lib/common/navigator.dart` — its Cupertino-derived curves
  are deliberate and out of scope for the whole design-system effort, not
  just this plan.
- Each of the 11 items is independent. If any cited snippet doesn't match
  current content (drift since `b1c6223`), skip only that item, note it,
  and continue with the rest.

## Verification

- **Mechanical**: `flutter analyze` on the full list of touched files —
  expect 0 new errors.
- **Feel check**: spot-check a sample rather than all eleven exhaustively:
  - Item 3 (home.dart): navigate between any two bottom-nav destinations —
    the page crossfade should feel like a confident settle, not a slow
    creep-in.
  - Item 5 (applications_scene.dart): tap the Applications refresh icon —
    confirm the spin duration still reads as "in progress," not
    uncomfortably fast or jittery, at 300ms.
  - Item 9 (super_grid.dart): enter drag-reorder mode on whatever grid uses
    `SuperGrid` (grep `SuperGrid(` for the call site) — confirm the jiggle
    still looks and feels exactly the same as before this plan (this is
    the one item where "no perceptible change" is the correct outcome,
    since 120ms/300ms were swapped for numerically identical tokens).
  - Items 11 (card.dart radii): visually compare a proxy/profile card and
    a Settings block card before/after — corners should look marginally
    tighter/looser, not obviously broken or mismatched against nearby
    unrelated corners.
- **Done when**: all eleven sites reference `RouteXMotion`/`RouteXRadius`
  tokens instead of independent literals, with no perceptible feel
  regression at any site.
