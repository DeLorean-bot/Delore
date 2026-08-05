# 008 — Gate real movement/layout animations behind reduced motion

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: MEDIUM (cluster of 5 sites)
- **Category**: Accessibility
- **Estimated scope**: 5 files, one small edit each

## Problem

Per the accessibility rule: *"Reduced motion means fewer and gentler
animations, not zero — keep transitions that aid comprehension, remove
position changes."* This plan only targets animations that move, resize,
or reposition content — **not** simple hover/opacity color fades, which
are correctly left alone under reduced motion and are out of scope here.
(Several other candidate sites — a hover-color `AnimatedContainer` in
`applications_workspace.dart`, a favorite-star opacity fade in
`proxies/card.dart`, a favicon fade in `domain_routing.dart` — were
considered and rejected for this plan on exactly that basis; two of them
still have a token-consistency gap, tracked separately in plan 009.)

Five confirmed sites with no `disableAnimations` check, each genuinely
repositioning or resizing content:

### Site A — `lib/widgets/list.dart:284` (Container Transform / OpenContainer)

```dart
// current
return OpenContainer(
  closedBuilder: (_, action) {
    ...
```

`OpenContainer` (`lib/widgets/open_container.dart`) is a vendored copy of
the `animations` package's Container Transform pattern — do not edit that
file. Its `transitionDuration` constructor parameter defaults to 300ms and
is fully controllable from the call site.

### Site B — `lib/views/config/general.dart:906-913` (advanced-fields expand)

```dart
// current
child: Padding(
  padding: const EdgeInsets.only(top: 8),
  child: AnimatedSize(
    duration: midDuration,
    curve: Curves.easeOutQuad,
    alignment: Alignment.topCenter,
    child: Column(
```

### Site C — `lib/widgets/scroll.dart:70-81` (`ScrollToEndBox`)

```dart
// current
void _handleTryToEnd() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final offset = globalState.cacheScrollPosition[widget.tag] ?? -1;
    if (offset < 0) {
      widget.controller.animateTo(
        duration: kThemeAnimationDuration,
        widget.controller.position.maxScrollExtent,
        curve: Curves.easeOut,
      );
    }
  });
}
```

### Site D — `lib/views/applications/applications_workspace.dart:489-494` (connection details expand)

```dart
// current
AnimatedCrossFade(
  duration: const Duration(milliseconds: 180),
  crossFadeState: _expanded
      ? CrossFadeState.showSecond
      : CrossFadeState.showFirst,
  firstChild: const SizedBox(width: double.infinity),
```

### Site E — `lib/widgets/side_sheet.dart:65-70` (`SideSheet.createAnimationController`)

```dart
// current
static AnimationController createAnimationController(TickerProvider vsync) => AnimationController(
    duration: _bottomSheetEnterDuration,
    reverseDuration: _bottomSheetExitDuration,
    debugLabel: 'SideSheet',
    vsync: vsync,
  );
```

This is a `static` factory with no `BuildContext` parameter, called only
once internally at `lib/widgets/side_sheet.dart:487` from inside
`_SideSheetState` (which does have a `context`) — but simplest is to check
reduced motion via the platform dispatcher directly, which needs no
`BuildContext` at all and is what `MediaQuery.disableAnimations` reads from
under the hood.

## Target

**Site A** — `lib/widgets/list.dart:284`:
```dart
return OpenContainer(
  transitionDuration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
      ? Duration.zero
      : const Duration(milliseconds: 300),
  closedBuilder: (_, action) {
    ...
```
(300ms matches `OpenContainer`'s own existing default, so behavior is
unchanged when motion is not reduced.)

**Site B** — `lib/views/config/general.dart`:
```dart
child: AnimatedSize(
  duration: RouteXMotion.resolve(context, midDuration),
  curve: Curves.easeOutQuad,
  alignment: Alignment.topCenter,
  child: Column(
```

**Site C** — `lib/widgets/scroll.dart`:
```dart
void _handleTryToEnd() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final offset = globalState.cacheScrollPosition[widget.tag] ?? -1;
    if (offset < 0) {
      widget.controller.animateTo(
        widget.controller.position.maxScrollExtent,
        duration: RouteXMotion.resolve(context, kThemeAnimationDuration),
        curve: Curves.easeOut,
      );
    }
  });
}
```
Note `context` must be available in this `State` at the call site — confirm
`_ScrollToEndBoxState` has access to `context` where `_handleTryToEnd` is
defined (it's a method on the `State` class, so `this.context` is valid).
Also note the reordering: `animateTo`'s positional `duration:` argument was
written after the positional `offset` argument in the original — preserve
the original argument order exactly, only wrapping the `duration` value
itself.

**Site D** — `lib/views/applications/applications_workspace.dart`:
```dart
AnimatedCrossFade(
  duration: RouteXMotion.resolve(context, const Duration(milliseconds: 180)),
  crossFadeState: _expanded
      ? CrossFadeState.showSecond
      : CrossFadeState.showFirst,
  firstChild: const SizedBox(width: double.infinity),
```

**Site E** — `lib/widgets/side_sheet.dart`:
```dart
static AnimationController createAnimationController(TickerProvider vsync) {
  final reduceMotion =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  return AnimationController(
    duration: reduceMotion ? Duration.zero : _bottomSheetEnterDuration,
    reverseDuration: reduceMotion ? Duration.zero : _bottomSheetExitDuration,
    debugLabel: 'SideSheet',
    vsync: vsync,
  );
}
```

## Repo conventions to follow

- `RouteXMotion.resolve(context, duration)` (`lib/common/premium_theme.dart`)
  is the sanctioned gate wherever a `BuildContext` is available — use it for
  Sites B, C, D.
- Site A doesn't have `RouteXMotion` imported in `list.dart` currently —
  either add the import and use `RouteXMotion.resolve`, or the inline
  `MediaQuery.maybeOf(context)?.disableAnimations ?? false` ternary shown
  above (both are used elsewhere in the codebase; prefer `RouteXMotion.resolve`
  for consistency if the import is cheap to add — check `list.dart`'s
  existing imports first).
- Site E has no `BuildContext` available at all (static method) — use
  `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`
  directly, which is the same underlying source `MediaQuery.disableAnimations`
  reads from, just without needing a widget tree lookup.

## Steps

1. Site A: edit `lib/widgets/list.dart:284`, add the `transitionDuration:`
   parameter to the `OpenContainer(` call as shown in Target. Confirm
   `context` is in scope at that point (it's inside `Widget build(BuildContext context)`,
   per the file's structure around line 278).
2. Site B: edit `lib/views/config/general.dart:909`, wrap `midDuration` in
   `RouteXMotion.resolve(context, ...)`. Confirm `RouteXMotion` is
   reachable from this file's existing imports (grep the file's import
   block; add the import if missing).
3. Site C: edit `lib/widgets/scroll.dart:74-78`, wrap `kThemeAnimationDuration`
   in `RouteXMotion.resolve(context, ...)` as shown, preserving the
   existing argument order.
4. Site D: edit `lib/views/applications/applications_workspace.dart:490`,
   wrap `const Duration(milliseconds: 180)` in `RouteXMotion.resolve(context, ...)`.
5. Site E: edit `lib/widgets/side_sheet.dart:65-70`, change the static
   factory to compute `reduceMotion` via `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`
   and zero both durations when true, as shown in Target.

## Boundaries

- Do NOT edit `lib/widgets/open_container.dart` itself (vendored Container
  Transform implementation) — Site A's fix is entirely at its one call site.
- Do NOT touch the hover-color `AnimatedContainer` in
  `applications_workspace.dart:360-361`, the favorite-star opacity fade in
  `proxies/card.dart:277-279`, or the favicon fade in
  `domain_routing.dart:442` — these are simple opacity/color transitions
  with no position change, correctly exempt from reduced-motion gating per
  the accessibility rule quoted in Problem. (Their duration/curve token
  consistency is tracked in plan 009, not here.)
- Do NOT touch `SideSheet`'s drag-to-dismiss gesture logic — only the
  `createAnimationController` factory.
- If any cited line's current content doesn't match what's quoted above
  (drift since `b1c6223`), skip that specific site, note it, and continue
  with the rest — these five sites are independent, a mismatch on one
  doesn't block the others.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/list.dart lib/views/config/general.dart lib/widgets/scroll.dart lib/views/applications/applications_workspace.dart lib/widgets/side_sheet.dart` — expect 0 new errors across all five.
- **Feel check** (repeat for each site, reduced motion OFF then ON):
  - Site A: open any `OpenDelegate`-backed list item (grep `OpenDelegate(` for a call site) on mobile width — container-transform should still animate normally with motion on, and open instantly with motion off.
  - Site B: open Settings > General/port config, expand the advanced fields — same check.
  - Site C: trigger a log/connections list update that scrolls to end (Logs or Connections view) — same check.
  - Site D: expand a connection's details row in Applications — same check.
  - Site E: open any side sheet (grep `SideSheet(` for a call site) — same check.
- **Done when**: all five sites animate normally with motion enabled and
  jump instantly (zero duration) with reduced motion on, with no other
  behavior change.
