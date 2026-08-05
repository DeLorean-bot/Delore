# 004 — Gate FadeScaleEnterBox for reduced motion and soften its entrance scale

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Accessibility / Physicality & origin
- **Estimated scope**: 1 file (`lib/widgets/fade_box.dart`)

## Problem

`FadeScaleEnterBox` drives the entrance animation for every `CommonCard`
constructed with `enterAnimated: true` (profile cards —
`lib/views/profiles/profiles.dart:422`). It starts unconditionally:

```dart
// lib/widgets/fade_box.dart:101-121 — current
class _FadeScaleEnterBoxState extends State<FadeScaleEnterBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: commonDuration,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.forward();
  }
```

No `disableAnimations` check anywhere in the file. Separately, the paired
transition widget scales in from an aggressive start point:

```dart
// lib/widgets/fade_box.dart:150-156 — current
static final Animatable<double> _fadeInTransition = CurveTween(
  curve: const Interval(0.0, 0.3),
);
static final Animatable<double> _scaleInTransition = Tween<double>(
  begin: 0.70,
  end: 1.00,
).chain(CurveTween(curve: Easing.legacyDecelerate));
```

`0.70` is a Material Motion "scale" pattern default, not this app's own
0.9–0.97 "materialize, don't pop" convention used elsewhere.

## Target

```dart
// target — lib/widgets/fade_box.dart:106-121
@override
void initState() {
  super.initState();
  final reduceMotion =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  _controller = AnimationController(
    vsync: this,
    duration: reduceMotion ? Duration.zero : commonDuration,
  );
  _animation = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ));
  _controller.forward();
}
```

```dart
// target — lib/widgets/fade_box.dart:153-156
static final Animatable<double> _scaleInTransition = Tween<double>(
  begin: 0.94,
  end: 1.00,
).chain(CurveTween(curve: Easing.legacyDecelerate));
```

`MediaQuery.maybeOf(context)` inside `initState` works here because
`_FadeScaleEnterBoxState` is a `State`, and `context` is available in
`initState` for a read-only lookup like this (it will not auto-rebuild on
later `MediaQuery` changes, which is an acceptable, pre-existing limitation
shared by every other one-shot `initState`-driven entrance in this
codebase — do not attempt to make it reactive as part of this plan).

## Repo conventions to follow

- `commonDuration` is `lib/common/constant.dart:33` (`Duration(milliseconds: 300)`) —
  keep using it; this plan does not migrate it to `RouteXMotion` (that's a
  separate, lower-priority token-consolidation concern — see plan 009).
- The reduced-motion check itself (`MediaQuery.maybeOf(context)?.disableAnimations ?? false`)
  is the same expression used throughout the app, e.g.
  `lib/widgets/routex_backdrop.dart:49` and
  `lib/views/dashboard/widgets/hero_nav_bar.dart:245-246`.

## Steps

1. In `lib/widgets/fade_box.dart`, edit `_FadeScaleEnterBoxState.initState`
   (lines 106-121) to compute `reduceMotion` and pass
   `reduceMotion ? Duration.zero : commonDuration` as the controller's
   `duration`, exactly as shown in Target.
2. Edit `FadeScaleEnterTransition._scaleInTransition` (lines 153-156),
   changing `begin: 0.70` to `begin: 0.94`.
3. Leave `_fadeInTransition` (lines 150-152) and `Easing.legacyDecelerate`
   untouched.

## Boundaries

- Do NOT touch `FadeBox`, `FadeThroughBox`, or `FadeScaleBox` (lines 5-87) —
  only `FadeScaleEnterBox`/`FadeScaleEnterTransition` (lines 89-166) are in
  scope.
- Do NOT migrate `commonDuration` to `RouteXMotion.base` here — that's
  plan 009's job, batched with every other similar site.
- If the cited line numbers/content have drifted since `b1c6223`, STOP and
  report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/fade_box.dart` — expect 0
  new errors.
- **Feel check**: open the Profiles view (grid populates with
  `enterAnimated: true` cards):
  - Cards visibly settle in from ~94% scale, not a noticeable "pop" — set
    DevTools playback to 10% and confirm the starting scale looks close to
    full size, not visibly small.
  - Toggle reduced motion and reload the Profiles view — cards should
    appear immediately at full opacity/scale, no animated build-in.
- **Done when**: `FadeScaleEnterBox` respects reduced motion and the
  entrance scale starts at 0.94 instead of 0.70.
