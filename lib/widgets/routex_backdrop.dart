import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The detail layer of the RouteX backdrop: a slow monochrome light field,
/// faint optical threads, grain and a vignette over the app's base gradient.
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
  late final AnimationController _controller;

  // Was `widget.active && !disableAnimations` — the backdrop drifted
  // continuously on the dashboard by design (orbs sliding, grid position
  // shifting). Fixing the per-line wave in the two paint functions above
  // stopped the *shape* distortion, but the orbs and the grid's own slow
  // slide are separate motion this doesn't touch, and it turns out any
  // visible motion in the backdrop reads as "the background is changing"
  // regardless of whether anything is warping. Backdrop is fully static now.
  bool get _motionEnabled => false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

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
              intensity: widget.active ? 1 : 0.22,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Paints the RouteX mesh: five soft monochrome highlights, a sparse optical
/// field, deterministic grain and a vignette. Shared with the developer glass
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
    // Monochrome only — white/grey specular highlights on black, like the
    // real iOS Liquid Glass material. No brand color (mint/blue/amber)
    // leaks into the backdrop; it stays reserved for actual UI accents
    // (selected pills, icons), never the page behind them.
    final blobs = <(Offset, double, Color, double)>[
      (
        Offset(0.08 + math.sin(angle) * 0.05, 0.10 + math.cos(angle) * 0.04),
        0.60,
        Colors.white,
        0.020,
      ),
      (
        Offset(0.94 - math.cos(angle) * 0.05, 0.80 - math.sin(angle) * 0.04),
        0.68,
        Colors.white,
        0.028,
      ),
      (
        Offset(0.70 + math.cos(angle * 1.3) * 0.06, 0.30),
        0.46,
        Colors.white,
        0.016,
      ),
      (
        Offset(0.16, 0.62 - math.sin(angle * 0.8) * 0.05),
        0.50,
        Colors.white,
        0.012,
      ),
      (
        Offset(0.46 + math.sin(angle * 0.6) * 0.08, 0.46),
        0.55,
        Colors.white,
        0.008,
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
    routeXPaintChromeRefractionField(
      canvas,
      size,
      phase: phase,
      strength: 0.075 * detail.clamp(0.0, 2.0),
    );
    // A black backdrop needs low-frequency detail for the lens to bend. These
    // threads are intentionally below normal reading contrast: outside glass
    // they register as texture, while the refracted edge displaces and curves
    // them enough to reveal the material. Keeping them monochrome avoids the
    // generic colourful "AI glassmorphism" look.
    routeXPaintOpticalThreads(
      canvas,
      size,
      phase: phase,
      strength: 0.048 * detail.clamp(0.0, 2.0) * math.max(intensity, 0.7),
    );
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

/// Sharp low-contrast detail placed behind navigation chrome. Refraction is a
/// displacement of existing pixels; an almost uniform black surface cannot
/// reveal that displacement. These lines live in the captured background (not
/// on the glass), so their visible curvature is produced by the lens shader.
void routeXPaintChromeRefractionField(
  Canvas canvas,
  Size size, {
  required double phase,
  required double strength,
}) {
  if (strength <= 0 || size.isEmpty) return;
  final desktop = size.width >= 720;
  final regions = desktop
      ? <Rect>[
          Rect.fromLTWH(0, 0, math.min(252, size.width), size.height),
          Rect.fromLTWH(248, 0, math.max(0, size.width - 248), 92),
          // The dashboard's connect bar lives down here — without this
          // region the desktop field only reached the sidebar and the app
          // bar (which the dashboard doesn't even show), leaving the
          // bottom of the screen an almost uniform black the connect
          // bar's lens had nothing to bend.
          Rect.fromLTWH(
            248,
            math.max(0, size.height - 130),
            math.max(0, size.width - 248),
            130,
          ),
        ]
      : <Rect>[
          Rect.fromLTWH(0, 38, size.width, 74),
          Rect.fromLTWH(0, math.max(0, size.height - 96), size.width, 96),
        ];
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..isAntiAlias = true;
  final drift = math.sin(phase * math.pi) * 5;

  for (final region in regions) {
    canvas.save();
    canvas.clipRect(region);
    paint.color = Colors.white.withValues(alpha: strength);
    // Straight lines, deliberately: the doc comment above says the shader
    // is what should visibly bend these, but this loop used to add its own
    // sine wave to every segment (`bend`) — pre-curved before any lens
    // touched it. Since the painted rect is wider than the actual rounded
    // card sitting over it (margins, corners), that wave was visible in the
    // plain map area around the card too, not just inside it, and read as
    // "the whole background is warping" instead of "the glass bends this."
    for (double x = region.left - 40; x <= region.right + 40; x += 44) {
      canvas.drawLine(
        Offset(x + drift, region.top - 12),
        Offset(x + drift, region.bottom + 12),
        paint,
      );
    }
    paint.color = Colors.white.withValues(alpha: strength * 0.52);
    for (double y = region.top; y <= region.bottom; y += 38) {
      canvas.drawLine(
        Offset(region.left, y + drift * 0.3),
        Offset(region.right, y - drift * 0.3),
        paint,
      );
    }
    canvas.restore();
  }
}

void routeXPaintOpticalThreads(
  Canvas canvas,
  Size size, {
  required double phase,
  required double strength,
}) {
  if (strength <= 0 || size.isEmpty) return;
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: strength)
    ..strokeWidth = 0.65
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final shift = math.sin(phase * math.pi) * 9;
  const spacing = 76.0;

  // Straight lines, same reasoning as routeXPaintChromeRefractionField: this
  // painted layer sits under the dashboard's own map, which is not fully
  // opaque everywhere (open ocean lets it show through) — a per-point wave
  // baked into the paint itself was visibly, continuously rippling across
  // the whole scene, glass or no glass, which reads as the background
  // itself warping rather than glass bending something behind it. The
  // whole grid still drifts a little as one piece (`shift`); individual
  // lines don't independently wave anymore.
  for (double y = -spacing; y < size.height + spacing; y += spacing) {
    canvas.drawLine(
      Offset(0, y + shift),
      Offset(size.width, y + shift),
      paint,
    );
  }

  paint.color = Colors.white.withValues(alpha: strength * 0.58);
  for (double x = 38; x < size.width; x += spacing * 1.45) {
    canvas.drawLine(
      Offset(x - shift * 0.35, 0),
      Offset(x - shift * 0.35, size.height),
      paint,
    );
  }
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
