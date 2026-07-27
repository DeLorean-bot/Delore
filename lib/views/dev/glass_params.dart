import 'package:flclashx/common/premium_theme.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Every knob of a `LiquidGlassStyle`, flattened into one value object.
///
/// The playground edits this; [toStyle] turns it into the real library
/// style and [toDartSource] prints the exact constructor call, so a
/// tuned material can be pasted straight into a semantic token.
@immutable
class RouteXGlassParams {
  const RouteXGlassParams({
    this.cornerStyle = LiquidGlassCornerStyle.continuousRoundedRectangle,
    this.cornerRadius = 22,
    this.exactClip = false,
    this.borderWidth = 1,
    this.lightIntensity = 1,
    this.lightDirection = 0,
    this.lightMode = LiquidGlassLightMode.edge,
    this.opticalBorder = true,
    this.borderSaturation = 1,
    this.ambientIntensity = 1,
    this.borderSolidity = 0,
    this.lightSpread = 0.5,
    this.borderSoftness = 1,
    this.oneSideLightIntensity = 0,
    this.doubleSideLightIntensity = 0,
    this.tintBase = Colors.white,
    this.tintAlpha = 0.08,
    this.saturation = 1.05,
    this.blurSigma = 3,
    this.innerTransparent = false,
    this.opticalRefraction = true,
    this.refractionIndex = 1.5,
    this.refractionWidth = 24,
    this.depth = 0.7,
    this.distortion = 0.1,
    this.distortionWidth = 30,
    this.magnification = 1,
    this.chromaticAberration = 0,
    this.refractionMode = LiquidGlassRefractionMode.shapeRefraction,
    this.diagonalFlip = 0,
  });

  // ── shape ────────────────────────────────────────────────
  final LiquidGlassCornerStyle cornerStyle;
  final double cornerRadius;
  final bool exactClip;
  final double borderWidth;
  final double lightIntensity;
  final double lightDirection;
  final LiquidGlassLightMode lightMode;

  // ── border ───────────────────────────────────────────────
  final bool opticalBorder;
  final double borderSaturation;
  final double ambientIntensity;
  final double borderSolidity;
  final double lightSpread;
  final double borderSoftness;
  final double oneSideLightIntensity;
  final double doubleSideLightIntensity;

  // ── appearance ───────────────────────────────────────────
  final Color tintBase;
  final double tintAlpha;
  final double saturation;
  final double blurSigma;
  final bool innerTransparent;

  // ── refraction ───────────────────────────────────────────
  final bool opticalRefraction;
  final double refractionIndex;
  final double refractionWidth;
  final double depth;
  final double distortion;
  final double distortionWidth;
  final double magnification;
  final double chromaticAberration;
  final LiquidGlassRefractionMode refractionMode;
  final double diagonalFlip;

  /// The material from `D:\liquid_glass_easy-main\example` — the
  /// transparent panel the official showcase renders.
  static const officialPanel = RouteXGlassParams(
    cornerRadius: 36,
    borderWidth: 1.5,
    tintAlpha: 0.08,
    saturation: 1.05,
    blurSigma: 3,
    refractionIndex: 1.5,
    refractionWidth: 24,
    depth: 0.7,
  );

  /// The official navigation selection pill: no tint, no optical
  /// refraction — just a light standard distortion.
  static const officialNavPill = RouteXGlassParams(
    cornerRadius: 26,
    tintAlpha: 0,
    saturation: 1,
    blurSigma: 0,
    opticalRefraction: false,
    distortion: 0.05,
    distortionWidth: 10,
    chromaticAberration: 0,
  );

  /// The library's own tuned nav-bar rim, from
  /// `example/lib/nav_bar_tuning.dart` — thin, solid, saturated, lit
  /// from near the top. The reference RouteX's rim is now aligned to.
  static const officialNavGlass = RouteXGlassParams(
    cornerRadius: 30,
    exactClip: true,
    borderWidth: 0.8,
    lightIntensity: 1.1,
    lightDirection: 80,
    borderSaturation: 1.2,
    borderSolidity: 1,
    tintAlpha: 0.086,
    blurSigma: 3,
  );

  // ── The shipped semantic variants ────────────────────────
  // These mirror `routeXGlassStyle` in common/premium_theme.dart
  // (dark theme). Load one, adjust, then Copy Dart back into the token.

  /// `RouteXGlassVariant.panel`.
  static const routexPanel = _routexBase;

  /// `RouteXGlassVariant.navigation`.
  static const routexNavigation = RouteXGlassParams(
    cornerRadius: 30,
    exactClip: true,
    borderWidth: 0.8,
    lightIntensity: 1.1,
    lightDirection: 80,
    borderSaturation: 1.2,
    borderSolidity: 1,
    tintAlpha: 0.094,
    blurSigma: 3,
  );

  /// `RouteXGlassVariant.selection`.
  static const routexSelection = RouteXGlassParams(
    cornerRadius: 25,
    exactClip: true,
    borderWidth: 0.8,
    lightIntensity: 1.1,
    lightDirection: 80,
    borderSaturation: 1.2,
    borderSolidity: 1,
    tintAlpha: 0.059,
    saturation: 1,
    blurSigma: 0,
    opticalRefraction: false,
    distortion: 0.05,
    distortionWidth: 10,
  );

  /// `RouteXGlassVariant.dialog`.
  static const routexDialog = RouteXGlassParams(
    exactClip: true,
    borderWidth: 1,
    lightIntensity: 1.1,
    lightDirection: 80,
    borderSaturation: 1.2,
    borderSolidity: 1,
    tintAlpha: 0.133,
    blurSigma: 6,
    refractionIndex: 1.45,
    refractionWidth: 26,
    depth: 0.5,
  );

  /// `RouteXGlassVariant.control`.
  static const routexControl = RouteXGlassParams(
    cornerRadius: 12,
    exactClip: true,
    borderWidth: 0.8,
    lightIntensity: 1.1,
    lightDirection: 80,
    borderSaturation: 1.2,
    borderSolidity: 1,
    tintAlpha: 0.086,
    blurSigma: 2,
    refractionWidth: 12,
    depth: 0.6,
  );

  static const presets = <String, RouteXGlassParams>{
    'Official panel': officialPanel,
    'Official nav pill': officialNavPill,
    'Official nav glass': officialNavGlass,
    'panel': routexPanel,
    'navigation': routexNavigation,
    'selection': routexSelection,
    'dialog': routexDialog,
    'control': routexControl,
  };

  static const _routexBase = RouteXGlassParams(
    exactClip: true,
    borderWidth: 0.8,
    lightIntensity: 1.1,
    lightDirection: 80,
    borderSaturation: 1.2,
    borderSolidity: 1,
    tintAlpha: 0.078,
    blurSigma: 3,
  );

  static const tintSwatches = <String, Color>{
    'white': Colors.white,
    'mint': premiumMint,
    'blue': premiumBlue,
    'black': Colors.black,
  };

  Color get tint => tintBase.withValues(alpha: tintAlpha);

  LiquidGlassBorderType get borderType => opticalBorder
      ? OpticalBorder(
          borderSaturation: borderSaturation,
          ambientIntensity: ambientIntensity,
          borderSolidity: borderSolidity,
          lightSpread: lightSpread,
        )
      : ClassicBorder(
          borderSoftness: borderSoftness,
          oneSideLightIntensity: oneSideLightIntensity,
          doubleSideLightIntensity: doubleSideLightIntensity,
        );

  LiquidGlassRefractionType get refractionType => opticalRefraction
      ? OpticalRefraction(
          refraction: refractionIndex,
          refractionWidth: refractionWidth,
          depth: depth,
        )
      : StandardRefraction(
          distortion: distortion,
          distortionWidth: distortionWidth,
        );

  /// Builds the library style. [radius] overrides [cornerRadius] so one
  /// tuned material can be shown at every RouteX radius token.
  LiquidGlassStyle toStyle({double? radius}) => LiquidGlassStyle(
        shape: LiquidGlassShape(
          cornerStyle: cornerStyle,
          cornerRadius: radius ?? cornerRadius,
          clipQuality: exactClip
              ? LiquidGlassClipQuality.exact
              : LiquidGlassClipQuality.roundedRectangle,
          borderWidth: borderWidth,
          lightIntensity: lightIntensity,
          lightDirection: lightDirection,
          lightMode: lightMode,
          borderType: borderType,
        ),
        appearance: LiquidGlassAppearance(
          saturation: saturation,
          blur: LiquidGlassBlur(sigmaX: blurSigma, sigmaY: blurSigma),
          color: tint,
          enableInnerRadiusTransparent: innerTransparent,
        ),
        refraction: LiquidGlassRefraction(
          magnification: magnification,
          chromaticAberration: chromaticAberration,
          refractionMode: refractionMode,
          refractionType: refractionType,
          diagonalFlip: diagonalFlip,
        ),
      );

  RouteXGlassParams copyWith({
    LiquidGlassCornerStyle? cornerStyle,
    double? cornerRadius,
    bool? exactClip,
    double? borderWidth,
    double? lightIntensity,
    double? lightDirection,
    LiquidGlassLightMode? lightMode,
    bool? opticalBorder,
    double? borderSaturation,
    double? ambientIntensity,
    double? borderSolidity,
    double? lightSpread,
    double? borderSoftness,
    double? oneSideLightIntensity,
    double? doubleSideLightIntensity,
    Color? tintBase,
    double? tintAlpha,
    double? saturation,
    double? blurSigma,
    bool? innerTransparent,
    bool? opticalRefraction,
    double? refractionIndex,
    double? refractionWidth,
    double? depth,
    double? distortion,
    double? distortionWidth,
    double? magnification,
    double? chromaticAberration,
    LiquidGlassRefractionMode? refractionMode,
    double? diagonalFlip,
  }) =>
      RouteXGlassParams(
        cornerStyle: cornerStyle ?? this.cornerStyle,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        exactClip: exactClip ?? this.exactClip,
        borderWidth: borderWidth ?? this.borderWidth,
        lightIntensity: lightIntensity ?? this.lightIntensity,
        lightDirection: lightDirection ?? this.lightDirection,
        lightMode: lightMode ?? this.lightMode,
        opticalBorder: opticalBorder ?? this.opticalBorder,
        borderSaturation: borderSaturation ?? this.borderSaturation,
        ambientIntensity: ambientIntensity ?? this.ambientIntensity,
        borderSolidity: borderSolidity ?? this.borderSolidity,
        lightSpread: lightSpread ?? this.lightSpread,
        borderSoftness: borderSoftness ?? this.borderSoftness,
        oneSideLightIntensity:
            oneSideLightIntensity ?? this.oneSideLightIntensity,
        doubleSideLightIntensity:
            doubleSideLightIntensity ?? this.doubleSideLightIntensity,
        tintBase: tintBase ?? this.tintBase,
        tintAlpha: tintAlpha ?? this.tintAlpha,
        saturation: saturation ?? this.saturation,
        blurSigma: blurSigma ?? this.blurSigma,
        innerTransparent: innerTransparent ?? this.innerTransparent,
        opticalRefraction: opticalRefraction ?? this.opticalRefraction,
        refractionIndex: refractionIndex ?? this.refractionIndex,
        refractionWidth: refractionWidth ?? this.refractionWidth,
        depth: depth ?? this.depth,
        distortion: distortion ?? this.distortion,
        distortionWidth: distortionWidth ?? this.distortionWidth,
        magnification: magnification ?? this.magnification,
        chromaticAberration: chromaticAberration ?? this.chromaticAberration,
        refractionMode: refractionMode ?? this.refractionMode,
        diagonalFlip: diagonalFlip ?? this.diagonalFlip,
      );

  /// The `LiquidGlassStyle(...)` constructor call for these values,
  /// ready to paste into a semantic token.
  String toDartSource() {
    final buffer = StringBuffer()
      ..writeln('const LiquidGlassStyle(')
      ..writeln('  shape: LiquidGlassShape.${_cornerConstructor()}(')
      ..writeln('    cornerRadius: ${_num(cornerRadius)},');
    if (exactClip) {
      buffer.writeln('    clipQuality: LiquidGlassClipQuality.exact,');
    }
    buffer.writeln('    borderWidth: ${_num(borderWidth)},');
    if (lightIntensity != 1) {
      buffer.writeln('    lightIntensity: ${_num(lightIntensity)},');
    }
    if (lightDirection != 0) {
      buffer.writeln('    lightDirection: ${_num(lightDirection)},');
    }
    if (lightMode != LiquidGlassLightMode.edge) {
      buffer.writeln('    lightMode: LiquidGlassLightMode.${lightMode.name},');
    }
    if (opticalBorder) {
      buffer
        ..writeln('    borderType: OpticalBorder(')
        ..writeln('      borderSaturation: ${_num(borderSaturation)},')
        ..writeln('      ambientIntensity: ${_num(ambientIntensity)},')
        ..writeln('      borderSolidity: ${_num(borderSolidity)},')
        ..writeln('      lightSpread: ${_num(lightSpread)},')
        ..writeln('    ),');
    } else {
      buffer
        ..writeln('    borderType: ClassicBorder(')
        ..writeln('      borderSoftness: ${_num(borderSoftness)},')
        ..writeln(
            '      oneSideLightIntensity: ${_num(oneSideLightIntensity)},')
        ..writeln(
          '      doubleSideLightIntensity: ${_num(doubleSideLightIntensity)},',
        )
        ..writeln('    ),');
    }
    buffer
      ..writeln('  ),')
      ..writeln('  appearance: LiquidGlassAppearance(')
      ..writeln('    color: $_tintLiteral,')
      ..writeln('    saturation: ${_num(saturation)},');
    if (blurSigma > 0) {
      buffer.writeln(
        '    blur: LiquidGlassBlur('
        'sigmaX: ${_num(blurSigma)}, sigmaY: ${_num(blurSigma)}),',
      );
    }
    if (innerTransparent) {
      buffer.writeln('    enableInnerRadiusTransparent: true,');
    }
    buffer
      ..writeln('  ),')
      ..writeln('  refraction: LiquidGlassRefraction(')
      ..writeln('    magnification: ${_num(magnification)},')
      ..writeln('    chromaticAberration: ${_num(chromaticAberration)},');
    if (refractionMode != LiquidGlassRefractionMode.shapeRefraction) {
      buffer.writeln(
        '    refractionMode: LiquidGlassRefractionMode.${refractionMode.name},',
      );
    }
    if (diagonalFlip != 0) {
      buffer.writeln('    diagonalFlip: ${_num(diagonalFlip)},');
    }
    if (opticalRefraction) {
      buffer
        ..writeln('    refractionType: OpticalRefraction(')
        ..writeln('      refraction: ${_num(refractionIndex)},')
        ..writeln('      refractionWidth: ${_num(refractionWidth)},')
        ..writeln('      depth: ${_num(depth)},')
        ..writeln('    ),');
    } else {
      buffer
        ..writeln('    refractionType: StandardRefraction(')
        ..writeln('      distortion: ${_num(distortion)},')
        ..writeln('      distortionWidth: ${_num(distortionWidth)},')
        ..writeln('    ),');
    }
    buffer
      ..writeln('  ),')
      ..writeln(')');
    return buffer.toString();
  }

  String _cornerConstructor() => switch (cornerStyle) {
        LiquidGlassCornerStyle.continuousRoundedRectangle =>
          'continuousRoundedRectangle',
        LiquidGlassCornerStyle.squircle => 'squircle',
        LiquidGlassCornerStyle.roundedRectangle => 'roundedRectangle',
      };

  String get _tintLiteral {
    final hex = tint.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'Color(0x$hex)';
  }

  static String _num(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}
