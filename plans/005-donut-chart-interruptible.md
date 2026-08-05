# 005 — Stop the dashboard traffic donut snapping back on every update

- **Status**: TODO
- **Commit**: b1c6223
- **Severity**: HIGH
- **Category**: Interruptibility
- **Estimated scope**: 1 file (`lib/widgets/donut_chart.dart`)

## Problem

`DonutChart` powers the dashboard's live traffic-usage ring. Every time new
data arrives (which, on an active VPN connection, can be frequent), it
restarts its animation from absolute zero instead of retargeting from
wherever it currently is:

```dart
// lib/widgets/donut_chart.dart:62-69 — current
@override
void didUpdateWidget(DonutChart oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.data != widget.data) {
    _oldData = oldWidget.data;
    _animationController.forward(from: 0);
  }
}
```

`_oldData = oldWidget.data` sets the new tween's starting point to the
**previous update's target**, not to what's actually on screen right now.
If a new data change arrives before the previous animation finished (i.e.
`_animationController.value < 1`), the ring visibly jumps to
`oldWidget.data`'s position first, then eases on toward the new target —
a discontinuity, worse the more frequently data updates.

## Target

Capture the *actual currently-rendered* interpolated values as the new
baseline before restarting, instead of the stale previous target:

```dart
// target — lib/widgets/donut_chart.dart:47-69
class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<DonutChartData> _oldData;

  @override
  void initState() {
    super.initState();
    _oldData = widget.data;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  List<DonutChartData> _currentInterpolatedData(List<DonutChartData> newData) {
    if (_oldData.length != newData.length) return _oldData;
    return DonutChartPainter(
      _oldData,
      newData,
      _animationController.value,
    ).interpolatedData;
  }

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _oldData = _currentInterpolatedData(oldWidget.data);
      _animationController.forward(from: 0);
    }
  }
```

This reuses `DonutChartPainter.interpolatedData` (already a public getter
on the painter, currently only called from `paint`) to compute exactly what
the ring looks like *right now* — at the controller's current `value`,
interpolated between the old baseline and the previous target — and uses
that as the new starting baseline. When the previous animation had already
finished (`value == 1`), `interpolatedData` naturally evaluates to
`oldWidget.data` unchanged, so the fix is a strict improvement with no
behavior change in the already-settled case.

## Repo conventions to follow

- `DonutChartPainter.interpolatedData` already exists at
  `lib/widgets/donut_chart.dart:110-129` and is pure (depends only on its
  constructor args) — safe to instantiate a throwaway painter just to reuse
  this getter, no painting side effect occurs until `.paint()` is called.
- Keep `widget.duration` (defaults to `commonDuration`, `lib/common/constant.dart:33`)
  as-is — this plan is about interruptibility, not duration/token cleanup.

## Steps

1. In `lib/widgets/donut_chart.dart`, add the private helper method
   `_currentInterpolatedData` to `_DonutChartState` as shown in Target,
   placed after `initState` and before `didUpdateWidget`.
2. Change `didUpdateWidget`'s body from
   `_oldData = oldWidget.data;` to
   `_oldData = _currentInterpolatedData(oldWidget.data);`, keeping
   `_animationController.forward(from: 0);` unchanged immediately after.
3. Leave `DonutChartPainter` itself, `build`, and `dispose` untouched.

## Boundaries

- Do NOT change `DonutChartPainter.paint` or the log/exp transform helpers
  (`_logTransform`/`_expTransform`) — the fix only changes what baseline
  data feeds into the existing interpolation, not how interpolation itself
  works.
- Do NOT change the `commonDuration` default or add a `RouteXMotion`
  reference here — out of scope for this plan.
- If `didUpdateWidget`'s current body doesn't match the excerpt above
  (drift since `b1c6223`), STOP and report instead of improvising.

## Verification

- **Mechanical**: `flutter analyze lib/widgets/donut_chart.dart` — expect 0
  new errors.
- **Feel check**: on the dashboard, with an active connection generating
  traffic, watch the traffic-usage donut (or, more reliably, use the
  Flutter Inspector to throttle the widget's data-update rate to simulate
  rapid updates — or read `network_speed.dart`/wherever `DonutChart` is
  constructed to find the real update cadence and trigger several updates
  in quick succession, e.g. by toggling connect/disconnect a few times
  fast):
  - The ring never visibly jumps backward or sideways before continuing —
    it should look like one continuous ease toward wherever the latest
    target is, even if the target changes mid-animation.
  - A single isolated update (previous animation already finished) still
    animates exactly as before — no regression in the common case.
- **Done when**: rapid, overlapping data updates produce a single smooth
  retargeted animation with no visible snap-back.
