import 'dart:async';
import 'dart:math' as math;

import 'package:flclashx/common/premium_theme.dart';
import 'package:flclashx/widgets/routex_backdrop.dart';
import 'package:flutter/material.dart';

/// The backdrop variants a [RouteXBackdrop] can paint.
///
/// Two of them are product candidates ([current], [mesh]); the rest are
/// diagnostic scenes used to tell a shader problem apart from a
/// "nothing to refract" problem. On Skia a `LiquidGlassLens` refracts
/// whatever the ancestor `LiquidGlassView` captured — so a lens over
/// [flatBlack] is *supposed* to look like a flat translucent panel.
enum RouteXBackdropVariant {
  /// What RouteX ships today: near-black base plus two very soft
  /// mint/blue ambient orbs.
  current,

  /// Candidate for the real product backdrop: black base, a slow
  /// multi-blob mesh, a faint noise grain and a vignette.
  mesh,

  /// Diagnostic: a fine line grid. Straight lines make refraction
  /// displacement directly readable at the rim.
  grid,

  /// Diagnostic: saturated color bands, the stand-in for the official
  /// example's photo. Only for shader checks — never for the product.
  spectrum,

  /// Control case: a single flat black fill, no detail at all.
  flatBlack,
}

extension RouteXBackdropVariantLabel on RouteXBackdropVariant {
  String get label => switch (this) {
        RouteXBackdropVariant.current => 'Current',
        RouteXBackdropVariant.mesh => 'Mesh',
        RouteXBackdropVariant.grid => 'Grid',
        RouteXBackdropVariant.spectrum => 'Spectrum',
        RouteXBackdropVariant.flatBlack => 'Flat black',
      };

  /// Whether the variant is a shader-diagnostic scene rather than a
  /// candidate for the shipped product backdrop.
  bool get isDiagnostic => switch (this) {
        RouteXBackdropVariant.grid ||
        RouteXBackdropVariant.spectrum ||
        RouteXBackdropVariant.flatBlack =>
          true,
        RouteXBackdropVariant.current || RouteXBackdropVariant.mesh => false,
      };
}

/// Paints one [RouteXBackdropVariant], full-bleed.
///
/// Meant to be handed to `LiquidGlassView.backgroundWidget`: it is
/// opaque, it fills its constraints, and every animated variant honours
/// [animate] (which callers wire to Reduce Motion).
class RouteXBackdrop extends StatefulWidget {
  const RouteXBackdrop({
    super.key,
    required this.variant,
    this.animate = true,
    this.detail = 1,
  });

  final RouteXBackdropVariant variant;

  /// Whether the slow ambient motion runs. Pass `false` for Reduce
  /// Motion or for non-Dashboard screens that capture a single snapshot.
  final bool animate;

  /// Multiplies how pronounced the backdrop's detail is (`0`–`2`). The
  /// knob that answers "is the captured background too flat to refract?"
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

  @override
  void initState() {
    super.initState();
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
    final wantsMotion = widget.animate &&
        switch (widget.variant) {
          RouteXBackdropVariant.current || RouteXBackdropVariant.mesh => true,
          _ => false,
        };
    if (wantsMotion) {
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
            painter: switch (widget.variant) {
              RouteXBackdropVariant.current => _CurrentBackdropPainter(
                  phase: _controller.value,
                  dark: dark,
                  detail: widget.detail,
                ),
              RouteXBackdropVariant.mesh => _MeshBackdropPainter(
                  phase: _controller.value,
                  dark: dark,
                  detail: widget.detail,
                ),
              RouteXBackdropVariant.grid =>
                _GridBackdropPainter(dark: dark, detail: widget.detail),
              RouteXBackdropVariant.spectrum =>
                _SpectrumBackdropPainter(detail: widget.detail),
              RouteXBackdropVariant.flatBlack =>
                _FlatBackdropPainter(dark: dark),
            },
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

Color _baseColor({required bool dark}) =>
    dark ? const Color(0xFF07090D) : const Color(0xFFF2F6F7);

void _paintBase(Canvas canvas, Size size, {required bool dark}) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = _baseColor(dark: dark),
  );
}

class _FlatBackdropPainter extends CustomPainter {
  const _FlatBackdropPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) => _paintBase(canvas, size, dark: dark);

  @override
  bool shouldRepaint(_FlatBackdropPainter old) => old.dark != dark;
}

/// The backdrop RouteX renders today — reproduced here so the playground
/// can compare it against the candidates under identical lens settings.
class _CurrentBackdropPainter extends CustomPainter {
  const _CurrentBackdropPainter({
    required this.phase,
    required this.dark,
    required this.detail,
  });

  final double phase;
  final bool dark;
  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size, dark: dark);
    final angle = phase * math.pi;
    final gain = detail.clamp(0.0, 2.0);
    routeXPaintOrb(
      canvas,
      size,
      center:
          Offset(0.11 + math.sin(angle) * 0.065, 0.16 + math.cos(angle) * 0.04),
      radiusFactor: 0.72,
      color: premiumMint.withValues(alpha: (dark ? 0.085 : 0.14) * gain),
    );
    routeXPaintOrb(
      canvas,
      size,
      center:
          Offset(0.92 - math.cos(angle) * 0.06, 0.82 - math.sin(angle) * 0.05),
      radiusFactor: 0.82,
      color: premiumBlue.withValues(alpha: (dark ? 0.095 : 0.14) * gain),
    );
  }

  @override
  bool shouldRepaint(_CurrentBackdropPainter old) =>
      old.phase != phase || old.dark != dark || old.detail != detail;
}

/// The shipped product backdrop, rendered over the base fill so the
/// playground tunes exactly what `RouteXBackdrop` paints in the app.
class _MeshBackdropPainter extends CustomPainter {
  const _MeshBackdropPainter({
    required this.phase,
    required this.dark,
    required this.detail,
  });

  final double phase;
  final bool dark;
  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size, dark: dark);
    RouteXMeshPainter(phase: phase, dark: dark, detail: detail)
        .paint(canvas, size);
  }

  @override
  bool shouldRepaint(_MeshBackdropPainter old) =>
      old.phase != phase || old.dark != dark || old.detail != detail;
}

/// Diagnostic grid: straight lines are the clearest read on how far the
/// rim displaces the background.
class _GridBackdropPainter extends CustomPainter {
  const _GridBackdropPainter({required this.dark, required this.detail});

  final bool dark;
  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size, dark: dark);
    final gain = detail.clamp(0.0, 2.0);
    const step = 28.0;
    final minor = Paint()
      ..strokeWidth = 1
      ..color =
          (dark ? Colors.white : Colors.black).withValues(alpha: 0.10 * gain);
    final major = Paint()
      ..strokeWidth = 1.4
      ..color = premiumMint.withValues(alpha: 0.42 * gain);
    var index = 0;
    for (var x = 0.0; x <= size.width; x += step, index++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 5 == 0 ? major : minor,
      );
    }
    index = 0;
    for (var y = 0.0; y <= size.height; y += step, index++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 5 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(_GridBackdropPainter old) =>
      old.dark != dark || old.detail != detail;
}

/// Diagnostic color bands — the code-only stand-in for the official
/// example's photograph. Saturated content is what makes the optical
/// rim, the chromatic aberration and the saturation dial visible.
class _SpectrumBackdropPainter extends CustomPainter {
  const _SpectrumBackdropPainter({required this.detail});

  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gain = detail.clamp(0.0, 2.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2A6B),
            Color(0xFF7B2FA8),
            Color(0xFFD8456B),
            Color(0xFFF0A03C),
            Color(0xFF29C39A),
          ],
        ).createShader(rect),
    );
    // Bright pinpoints: the highlights that make a lens read as glass.
    final random = math.Random(77);
    final paint = Paint();
    for (var i = 0; i < 26; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = 6 + random.nextDouble() * 26;
      paint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.75 * gain),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrumBackdropPainter old) => old.detail != detail;
}
