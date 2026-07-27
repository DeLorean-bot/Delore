import 'package:flclashx/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

const premiumMint = Color(0xFF62E6C5);
const premiumBlue = Color(0xFF7D9DFF);
const premiumAmber = Color(0xFFFFB45C);

abstract final class RouteXMotion {
  static const press = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 220);
  static const navigation = Duration(milliseconds: 300);
  static const curve = Cubic(0.16, 1, 0.3, 1);

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false
          ? Duration.zero
          : duration;
}

abstract final class RouteXRadius {
  static const control = 12.0;
  static const card = 16.0;
  static const overlay = 22.0;
  static const navigation = 26.0;

  /// A true capsule: pass half the surface's shorter side. Floating
  /// navigation reads as a capsule on iOS, and the library's own nav bar
  /// derives `height / 2` for the same reason — anything less makes a
  /// short, wide bar look like a rounded rectangle straining to be one.
  static double capsule(double shorterSide) => shorterSide / 2;
}

/// The exact silhouette of a RouteX glass surface — the same
/// Apple capsule-style curve the shader draws, so a drop shadow (or any
/// decoration) placed behind a lens lines up with it in the corners
/// instead of showing a circular corner under a continuous one.
class RouteXGlassBorder extends OutlinedBorder {
  const RouteXGlassBorder({required this.radius, super.side = BorderSide.none});

  final double radius;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      liquidGlassContinuousRoundedRectPath(rect.size, radius)
          .shift(rect.topLeft);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  /// Nothing to stroke: the lens draws its own optical rim.
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  RouteXGlassBorder copyWith({BorderSide? side, double? radius}) =>
      RouteXGlassBorder(
        radius: radius ?? this.radius,
        side: side ?? this.side,
      );

  @override
  ShapeBorder scale(double t) => RouteXGlassBorder(
        radius: radius * t,
        side: side.scale(t),
      );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  bool operator ==(Object other) =>
      other is RouteXGlassBorder &&
      other.radius == radius &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, side);
}

IconData routeXNavigationIcon(PageLabel label) => switch (label) {
      PageLabel.dashboard => Icons.home_outlined,
      PageLabel.applications => Icons.grid_view_rounded,
      PageLabel.proxies => Icons.language_rounded,
      PageLabel.profiles => Icons.person_outline_rounded,
      PageLabel.connections => Icons.swap_horiz_rounded,
      PageLabel.requests => Icons.rule_folder_outlined,
      PageLabel.resources => Icons.storage_outlined,
      PageLabel.logs => Icons.receipt_long_outlined,
      PageLabel.tools => Icons.tune_rounded,
    };

/// The elevation planes RouteX renders in glass.
///
/// One material vocabulary, five roles. They share the radius scale, the
/// tint family and the optical border; what differs is how much they may
/// bend and hide what is behind them — a dialog carries dense text and
/// must stay readable, a selection pill is 52 px wide and cannot afford a
/// 24 px refraction band on each side.
enum RouteXGlassVariant {
  /// Sidebar, app bar, bottom bar. Floats over content, so slightly
  /// denser than a panel.
  navigation,

  /// The moving pill inside a navigation surface. Matches the official
  /// example: no tint to speak of, no blur, a light standard distortion.
  selection,

  /// Cards and sheets on the content plane. The reference material.
  panel,

  /// Modals. The most opaque of the five: legibility beats effect.
  dialog,

  /// Buttons and small controls. Narrow refraction band so the bevels
  /// of opposite rims do not meet inside a 44 px target.
  control,
}

extension RouteXGlassVariantDefaults on RouteXGlassVariant {
  /// The radius this variant renders at when a call site doesn't pin one.
  double get defaultRadius => switch (this) {
        RouteXGlassVariant.navigation => RouteXRadius.navigation,
        RouteXGlassVariant.selection => 18,
        RouteXGlassVariant.panel => RouteXRadius.overlay,
        RouteXGlassVariant.dialog => RouteXRadius.overlay,
        RouteXGlassVariant.control => RouteXRadius.control,
      };
}

/// The rim, shared by every variant.
///
/// **Thin and translucent.** The library's tuned nav bar uses
/// `borderSolidity: 1` with `borderSaturation: 1.2`, but it does so over
/// the example's photographic background: there the rim samples real
/// colour from behind the glass. Over RouteX's near-black backdrop the
/// same values collapse into a hard, saturated line drawn *on* the
/// panel — a neon outline, which is the single loudest tell that a dark
/// UI was not designed by hand. Thin plus translucent gives a bevel that
/// is felt rather than seen.
///
/// The thickness matters as much as the solidity: at 1.0–1.2 the rim was
/// wide enough to read as a stroke no matter how faint it was.
const _routeXOpticalRim = OpticalBorder(
  borderSaturation: 1,
  ambientIntensity: 1,
  borderSolidity: 0,
  lightSpread: 0.5,
);

/// Where the rim highlight falls, in degrees (`90` = straight down from
/// the top). The library's tuned nav bar uses `80`; light from above is
/// what makes an edge read as a physical bevel.
const _routeXLightDirection = 80.0;

/// Builds the glass material for [variant].
///
/// This is the only place a `LiquidGlassStyle` is constructed in RouteX:
/// tuned in the developer Glass Playground, then written down here as a
/// semantic token. Constant across all five: the rim above,
/// `clipQuality: exact` (the shader draws a continuous corner, so the
/// cheap circular clip leaves the silhouette and the refraction
/// disagreeing exactly at the corners), `chromaticAberration: 0` and
/// `magnification: 1`.
LiquidGlassStyle routeXGlassStyle(
  BuildContext context,
  RouteXGlassVariant variant, {
  double? radius,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  // Light theme needs a denser fill: the same alpha over a bright
  // backdrop reads as no material at all.
  final (Color tint, double blur, double borderWidth) = switch (variant) {
    RouteXGlassVariant.navigation => (
        dark ? const Color(0x18FFFFFF) : const Color(0x33FFFFFF),
        3.0,
        0.8,
      ),
    RouteXGlassVariant.selection => (
        dark ? const Color(0x0FFFFFFF) : const Color(0x2AFFFFFF),
        0.0,
        0.8,
      ),
    RouteXGlassVariant.panel => (
        dark ? const Color(0x14FFFFFF) : const Color(0x2EFFFFFF),
        3.0,
        0.8,
      ),
    RouteXGlassVariant.dialog => (
        dark ? const Color(0x22FFFFFF) : const Color(0x3DFFFFFF),
        6.0,
        1.0,
      ),
    RouteXGlassVariant.control => (
        dark ? const Color(0x16FFFFFF) : const Color(0x30FFFFFF),
        2.0,
        0.8,
      ),
  };
  final refraction = switch (variant) {
    // The official navigation pill: standard distortion, not optical.
    RouteXGlassVariant.selection => const LiquidGlassRefraction(
        magnification: 1,
        chromaticAberration: 0,
        refractionType: StandardRefraction(
          distortion: 0.05,
          distortionWidth: 10,
        ),
      ),
    RouteXGlassVariant.navigation => const LiquidGlassRefraction(
        magnification: 1,
        chromaticAberration: 0,
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: 28,
          depth: 0.7,
        ),
      ),
    // Less displacement: text sits directly on this surface.
    RouteXGlassVariant.dialog => const LiquidGlassRefraction(
        magnification: 1,
        chromaticAberration: 0,
        refractionType: OpticalRefraction(
          refraction: 1.45,
          refractionWidth: 26,
          depth: 0.5,
        ),
      ),
    RouteXGlassVariant.control => const LiquidGlassRefraction(
        magnification: 1,
        chromaticAberration: 0,
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: 12,
          depth: 0.6,
        ),
      ),
    RouteXGlassVariant.panel => const LiquidGlassRefraction(
        magnification: 1,
        chromaticAberration: 0,
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: 24,
          depth: 0.7,
        ),
      ),
  };
  return LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: radius ?? variant.defaultRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: borderWidth,
      lightIntensity: 1,
      lightDirection: _routeXLightDirection,
      borderType: _routeXOpticalRim,
    ),
    appearance: LiquidGlassAppearance(
      saturation: variant == RouteXGlassVariant.selection ? 1 : 1.05,
      blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
      color: tint,
    ),
    refraction: refraction,
  );
}

/// A glass plane: one lens in the [variant]'s material, with the drop
/// shadow that separates it from the backdrop.
class RouteXGlassSurface extends StatelessWidget {
  const RouteXGlassSurface({
    super.key,
    required this.child,
    this.variant = RouteXGlassVariant.panel,
    this.radius,
    this.shadowOffset = const Offset(0, 8),
    this.expand = true,
  });

  final Widget child;
  final RouteXGlassVariant variant;

  /// Overrides the variant's own radius. Prefer the RouteX radius scale.
  final double? radius;
  final Offset shadowOffset;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = radius ?? variant.defaultRadius;
    return DecoratedBox(
      // The shadow follows the shader's own silhouette, not a circular
      // rounded rectangle — otherwise a differently-curved shadow peeks
      // out at each corner and the edge reads as misaligned.
      decoration: ShapeDecoration(
        shape: RouteXGlassBorder(radius: effectiveRadius),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.1),
            blurRadius: 20,
            spreadRadius: -4,
            offset: shadowOffset,
          ),
        ],
      ),
      child: LiquidGlassLens(
        style: routeXGlassStyle(context, variant, radius: effectiveRadius),
        child: expand ? SizedBox.expand(child: child) : child,
      ),
    );
  }
}

/// The moving pill inside a navigation surface.
class RouteXSelectionGlass extends StatelessWidget {
  const RouteXSelectionGlass({
    super.key,
    required this.radius,
    this.child,
  });

  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LiquidGlassLens(
        style: routeXGlassStyle(
          context,
          RouteXGlassVariant.selection,
          radius: radius,
        ),
        child: child,
      );
}

ThemeData buildPremiumTheme({
  required Brightness brightness,
  required Color seed,
  bool pureBlack = false,
  PageTransitionsTheme? pageTransitionsTheme,
}) {
  final dark = brightness == Brightness.dark;
  final background = dark
      ? (pureBlack ? const Color(0xFF040507) : const Color(0xFF080B10))
      : const Color(0xFFF2F6F7);
  final surface = dark ? const Color(0xFF0C1016) : const Color(0xFFF9FBFC);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    primary: premiumMint,
    secondary: premiumBlue,
    surface: surface,
  ).copyWith(
    surfaceContainerLowest:
        dark ? const Color(0xFF080B10) : const Color(0xFFFFFFFF),
    surfaceContainerLow:
        dark ? const Color(0xFF0E131A) : const Color(0xFFF3F7F8),
    surfaceContainer: dark ? const Color(0xFF141A22) : const Color(0xFFEDF3F4),
    surfaceContainerHigh:
        dark ? const Color(0xFF19212B) : const Color(0xFFE5EDEF),
    surfaceContainerHighest:
        dark ? const Color(0xFF222C37) : const Color(0xFFDCE7E9),
    outline: dark ? const Color(0xFF4C5866) : const Color(0xFF9AABAF),
    outlineVariant: dark ? const Color(0xFF2A3541) : const Color(0xFFC8D5D8),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Segoe UI Variable',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    pageTransitionsTheme: pageTransitionsTheme,
  );
  final display = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    textTheme: display.copyWith(
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: display.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface.withValues(alpha: dark ? 0.78 : 0.88),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RouteXRadius.card),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: 0.075)
              : scheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: dark ? const Color(0xF5101720) : const Color(0xF5F8FBFC),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RouteXRadius.overlay),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: dark ? const Color(0xF5101720) : const Color(0xF5F8FBFC),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RouteXRadius.overlay),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.55),
      thickness: 0.7,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      selectedColor: scheme.primary,
      selectedTileColor: scheme.primary.withValues(alpha: 0.09),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.68),
      selectedColor: scheme.primary.withValues(alpha: 0.17),
      side: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary.withValues(alpha: 0.65)
            : scheme.surfaceContainerHighest,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF07110E)
            : scheme.onSurfaceVariant,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 72,
      backgroundColor: scheme.surfaceContainerLowest.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? scheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: const Color(0xFF07110E),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(44, 42),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: const Color(0xFF07110E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: dark ? const Color(0xF5232E39) : const Color(0xF5E1EBED),
      contentTextStyle: TextStyle(color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: premiumMint,
      linearTrackColor: Color(0x263D4A55),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xF526313D) : const Color(0xF5DCE7E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      textStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 12,
      ),
    ),
  );
}
