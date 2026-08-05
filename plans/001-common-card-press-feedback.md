# 001 — Give CommonCard an iOS-style press scale, not just Material ripple

- **Status**: REVERTED — caused a crash, see Postmortem
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Physicality & origin
- **Estimated scope**: 1 file (`lib/widgets/card.dart`)

## Postmortem (added after execution)

Applied as written, then reverted. Wrapping `OutlinedButton` in a new
`_PressScale` (`Listener` + `AnimatedScale`) StatefulWidget, nested inside
`FadeScaleEnterBox`'s `AnimatedBuilder(child: ...)`, caused a reproducible
crash on the Profiles page (`CommonCard(enterAnimated: true)`):
`'package:flutter/src/widgets/framework.dart': Failed assertion: line 2168
pos 12: '_elements.contains(element)': is not true.` Confirmed via
bisection — removing `_PressScale` (reverting to a plain `OutlinedButton`)
resolved it; every other plan (002–009) was unaffected. Root cause not
fully diagnosed (suspected: an extra nested implicit-animation widget
inside `FadeScaleEnterBox`'s `AnimatedBuilder`-cached `child` subtree
confusing element reuse), but the fix path here — a wrapping
`StatefulWidget` with its own `AnimatedScale` inserted between
`FadeScaleEnterBox` and `OutlinedButton` — is now known-bad and should not
be reattempted the same way. A future retry should add press feedback
without introducing a new implicit-animation State object in that specific
position — e.g. driving `OutlinedButton`'s existing `WidgetStateProperty`
mechanism instead of wrapping it in a second animated layer, and should be
tested specifically on the Profiles page (`enterAnimated: true`) before
being considered safe.

## Problem

`CommonCard` is the shared base for every proxy card and profile card — the
single most-tapped surface in the app. Its interactive surface is a plain
`OutlinedButton` whose only state feedback is a color/border swap through
`WidgetStateProperty`:

```dart
// lib/widgets/card.dart:180-201 — current
final card = OutlinedButton(
  onLongPress: null,
  clipBehavior: Clip.antiAlias,
  style: ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    shape: WidgetStatePropertyAll(
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
    iconColor: WidgetStatePropertyAll(context.colorScheme.primary),
    iconSize: WidgetStateProperty.all(20),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => getBackgroundColor(context, states),
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => getBorderSide(context, states),
    ),
  ),
  onPressed: onPressed,
  child: childWidget,
);
```

`OutlinedButton` does still paint Material's default ink ripple on press —
so it isn't literally silent — but a Material ripple is Android's motion
language, not the iOS-style scale-down press this app uses everywhere else
it has already been designed deliberately: the bottom nav's `_LiquidNavItem`
(`lib/views/dashboard/widgets/hero_nav_bar.dart:278-281`,
`AnimatedScale(scale: _pressed ? 0.96 : 1, ...)`), and
`RouteXFocusableTap`'s hover lift (`lib/widgets/focusable_tap.dart:77-80`).
Every card in the Proxies and Profiles lists is the one big interactive
surface still speaking a different material language.

## Target

Add a press-down scale (~0.97) driven by the button's own pressed state,
using the same duration/curve token every other pressable control in this
codebase already uses (`RouteXMotion.press` = 120ms,
`RouteXMotion.curve` = `Cubic(0.16, 1, 0.3, 1)`), gated for reduced motion.

```dart
// target
final card = _PressScale(
  child: OutlinedButton(
    onLongPress: null,
    clipBehavior: Clip.antiAlias,
    style: ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: WidgetStatePropertyAll(
        RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      iconColor: WidgetStatePropertyAll(context.colorScheme.primary),
      iconSize: WidgetStateProperty.all(20),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => getBackgroundColor(context, states),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => getBorderSide(context, states),
      ),
    ),
    onPressed: onPressed,
    child: childWidget,
  ),
);
```

Where `_PressScale` is a small private `StatefulWidget` added to the bottom
of `lib/widgets/card.dart`:

```dart
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: RouteXMotion.resolve(context, RouteXMotion.press),
          curve: RouteXMotion.curve,
          child: widget.child,
        ),
      );
}
```

`Listener` is used (not another `GestureDetector`) so it never competes with
`OutlinedButton`'s own tap/long-press gesture recognizers — it only observes
pointer events, it doesn't claim them.

## Repo conventions to follow

- Duration/curve tokens live in `lib/common/premium_theme.dart` as
  `RouteXMotion.press`/`RouteXMotion.curve`; `RouteXMotion.resolve(context, duration)`
  is the sanctioned reduced-motion gate (returns `Duration.zero` when
  `MediaQuery.maybeOf(context)?.disableAnimations ?? false`).
- Exemplar already using this exact pattern: `lib/views/dashboard/widgets/hero_nav_bar.dart:278-281`.
- `card.dart` already imports `flclashx/common/common.dart` (confirm
  `RouteXMotion`/`premiumMint` are exported from there, as they already are
  used elsewhere in this same file at lines 113, 125, 135, 140).

## Steps

1. In `lib/widgets/card.dart`, add the private `_PressScale` widget shown
   above at the end of the file (after the existing `CommonCard` class).
2. In `CommonCard.build`, wrap the existing `card` local variable (the
   `OutlinedButton`, currently returned/used at line 203-208) with
   `_PressScale(child: card)` before it's handed to the
   `switch (enterAnimated)` block. Concretely: rename the existing
   `OutlinedButton(...)` expression's assignment target if needed so the
   final line 180 becomes `final card = _PressScale(child: OutlinedButton(...));`
   with the `OutlinedButton(...)` body unchanged, still ending at the
   original line 201's closing `);`, now nested one level deeper.
3. Leave `getBorderSide`/`getBackgroundColor` and the `enterAnimated`
   fade-scale-in switch (lines 203-208) untouched — this plan only touches
   the press feedback.

## Boundaries

- Do NOT touch `getBorderSide`/`getBackgroundColor` color logic.
- Do NOT touch `FadeScaleEnterBox`/`FadeScaleEnterTransition` (that's plan 004).
- Do NOT add a dependency — `Listener` and `AnimatedScale` are both
  `package:flutter/material.dart`, already imported.
- If `OutlinedButton`'s pressed ripple looks like it now double-feeds with
  the new scale (both firing on press), that's expected and correct — Apple
  UI often layers a subtle scale under whatever base feedback a platform
  widget already gives; do not try to suppress the ripple as part of this plan.
- If the code at `lib/widgets/card.dart:180-201` doesn't match the excerpt
  above (drift since commit `b1c6223`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/card.dart` — expect 0 new
  errors/warnings (this file currently analyzes clean).
- **Feel check**: run the app, open Proxies or Profiles, press and hold a
  card:
  - The card visibly compresses ~3% under the pointer and springs back on
    release — subtle, not a bounce.
  - Rapidly tap several cards in a row — no card gets stuck mid-scale.
  - Toggle reduced motion (`MediaQuery` `disableAnimations` — on Windows,
    Settings > Ease of Access > "Show animations" off, or in a DevTools
    Flutter Inspector "Slow Animations" toggle set to check the gate path)
    and confirm the press scale becomes instant (no animated interpolation)
    but the button still visually registers the press via its existing
    ripple/color change.
  - In DevTools' Animations panel (if available) or by eye at normal speed,
    confirm the scale settles within ~120ms, matching every other press
    target in the app (nav bar, focusable_tap).
- **Done when**: every `CommonCard` (proxy cards, profile cards, list
  entries) visibly compresses on press-down and recovers on release, using
  `RouteXMotion.press`/`.curve`, gated by `RouteXMotion.resolve`.
