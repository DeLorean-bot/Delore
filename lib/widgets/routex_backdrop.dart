import 'dart:async';
import 'dart:math' as math;

import 'package:flclashx/common/premium_theme.dart';
import 'package:flutter/material.dart';

/// The detail layer of the RouteX backdrop: a slow multi-blob mesh, a
/// faint grain and a vignette, painted over the app's base gradient.
///
/// This belongs in `LiquidGlassView.backgroundWidget` and **only**
/// there. On Skia a lens refracts the captured background, so anything
/// the glass is supposed to bend has to live in the capture; a copy of
/// the same backdrop inside `LiquidGlassView.child` would paint over
/// the capture, cost a second full-screen pass and never be refracted.
///
/// It paints no base fill of its own — the base gradient stays with the
/// scaffold, so the light theme and the user's background image keep
/// working unchanged.
class RouteXBackdrop extends StatefulWidget {
  const RouteXBackdrop({
    super.key,
    required this.active,
    this.detail = 1,
  });

  /// Whether this is the Dashboard: full intensity and slow motion.
  /// Content screens get a calmer, dimmer version and no animation.
  final bool active;

  /// Multiplies how pronounced the mesh, grain and vignette are.
  /// Refraction needs something to bend — at `0` the glass degrades to a
  /// plain translucent panel no matter how the material is tuned.
  final double detail;

  @override
  State<RouteXBackdrop> createState() => _RouteXBackdropState();
}

class _RouteXBackdropState extends State<RouteXBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  bool get _motionEnabled =>
      widget.active &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant RouteXBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (_motionEnabled) {
      if (!_controller.isAnimating) {
        unawaited(_controller.repeat(reverse: true));
      }
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: RouteXMeshPainter(
              phase: _controller.value,
              dark: dark,
              detail: widget.detail,
              intensity: widget.active ? 1 : 0.34,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Paints the RouteX mesh: five very soft mint/blue/amber blobs, a
/// deterministic grain and a vignette. Shared with the developer glass
/// playground so the tuned backdrop and the shipped one cannot drift.
class RouteXMeshPainter extends CustomPainter {
  const RouteXMeshPainter({
    required this.phase,
    required this.dark,
    required this.detail,
    this.intensity = 1,
  });

  /// Animation phase in `0..1`.
  final double phase;
  final bool dark;
  final double detail;

  /// Scales the whole layer — used to calm the backdrop down on content
  /// screens without changing its composition.
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = phase * math.pi;
    final gain = detail.clamp(0.0, 2.0) * intensity * (dark ? 1 : 1.4);
    // Spread across the frame, not only into the corners: a panel in the
    // middle of the screen has to have something under it, or its glass
    // has nothing to bend and degrades to a flat translucent rectangle.
    final blobs = <(Offset, double, Color, double)>[
      (
        Offset(0.08 + math.sin(angle) * 0.05, 0.10 + math.cos(angle) * 0.04),
        0.68,
        premiumMint,
        0.20,
      ),
      (
        Offset(0.94 - math.cos(angle) * 0.05, 0.80 - math.sin(angle) * 0.04),
        0.76,
        premiumBlue,
        0.22,
      ),
      (
        Offset(0.70 + math.cos(angle * 1.3) * 0.06, 0.30),
        0.52,
        premiumBlue,
        0.12,
      ),
      (
        Offset(0.16, 0.62 - math.sin(angle * 0.8) * 0.05),
        0.56,
        premiumMint,
        0.13,
      ),
      (
        Offset(0.46 + math.sin(angle * 0.6) * 0.08, 0.46),
        0.62,
        premiumAmber,
        0.06,
      ),
    ];
    for (final (center, radiusFactor, color, alpha) in blobs) {
      routeXPaintOrb(
        canvas,
        size,
        center: center,
        radiusFactor: radiusFactor,
        color: color.withValues(alpha: alpha * gain),
      );
    }
    routeXPaintGrain(
      canvas,
      size,
      strength: 0.055 * detail.clamp(0.0, 2.0) * intensity,
    );
    routeXPaintVignette(canvas, size, dark: dark, strength: intensity);
  }

  @override
  bool shouldRepaint(RouteXMeshPainter old) =>
      old.phase != phase ||
      old.dark != dark ||
      old.detail != detail ||
      old.intensity != intensity;
}

/// Draws one very soft radial blob. [center] is in unit coordinates,
/// [radiusFactor] is relative to the shorter side.
void routeXPaintOrb(
  Canvas canvas,
  Size size, {
  required Offset center,
  required double radiusFactor,
  required Color color,
}) {
  final origin = Offset(center.dx * size.width, center.dy * size.height);
  final radius = math.min(size.width, size.height) * radiusFactor;
  if (radius <= 0 || color.a == 0) {
    return;
  }
  final paint = Paint()
    ..shader = RadialGradient(
      stops: const [0, 0.42, 1],
      colors: [
        color,
        color.withValues(alpha: color.a * 0.42),
        color.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: origin, radius: radius));
  canvas.drawCircle(origin, radius, paint);
}

/// A deterministic dot grain. Seeded, so it is identical on every frame
/// and never shimmers between captures.
void routeXPaintGrain(
  Canvas canvas,
  Size size, {
  required double strength,
}) {
  if (strength <= 0) {
    return;
  }
  final random = math.Random(2607);
  final paint = Paint();
  final count = (size.width * size.height / 900).clamp(200, 4000).toInt();
  for (var i = 0; i < count; i++) {
    final dx = random.nextDouble() * size.width;
    final dy = random.nextDouble() * size.height;
    final alpha = random.nextDouble() * strength;
    paint.color = (random.nextBool() ? Colors.white : Colors.black).withValues(
      alpha: alpha,
    );
    canvas.drawRect(Rect.fromLTWH(dx, dy, 1.4, 1.4), paint);
  }
}

void routeXPaintVignette(
  Canvas canvas,
  Size size, {
  required bool dark,
  double strength = 1,
}) {
  final rect = Offset.zero & size;
  // Light: the vignette used to eat the mesh at exactly the edges where
  // the navigation surfaces sit, leaving them over flat black.
  final alpha = (dark ? 0.16 : 0.06) * strength;
  if (alpha <= 0) {
    return;
  }
  final paint = Paint()
    ..shader = RadialGradient(
      radius: 0.86,
      stops: const [0.55, 1],
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: alpha),
      ],
    ).createShader(rect);
  canvas.drawRect(rect, paint);
}
