import 'dart:async';
import 'dart:ui' as ui;

import 'package:flclashx/common/premium_theme.dart';
import 'package:flclashx/views/dev/glass_backdrops.dart';
import 'package:flclashx/views/dev/glass_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// An internal tuning screen for the RouteX glass material.
///
/// It renders the same specimens RouteX ships — panel, navigation
/// capsule, selection pill, dialog, control — over a switchable
/// backdrop, with every `LiquidGlassStyle` parameter on a live slider
/// and the official reference material rendered next to the tuned one.
///
/// Two things it is meant to settle:
///
///  * whether the material looks wrong or the *captured background* is
///    simply too flat to refract (switch the backdrop and watch);
///  * whether a nested lens on Skia picks up a local underlay that sits
///    in `LiquidGlassView.child` (toggle "local underlay" — it does not,
///    which is why `_SidebarUnderlay` cannot work as built).
///
/// Not part of the product: reached from Tools → Developer.
class GlassPlaygroundView extends StatefulWidget {
  const GlassPlaygroundView({super.key});

  @override
  State<GlassPlaygroundView> createState() => _GlassPlaygroundViewState();
}

class _GlassPlaygroundViewState extends State<GlassPlaygroundView> {
  RouteXGlassParams _params = RouteXGlassParams.routexSurface;
  RouteXBackdropVariant _backdrop = RouteXBackdropVariant.current;
  LiquidGlassRefreshRate _refreshRate = LiquidGlassRefreshRate.high;
  double _detail = 1;
  double _pixelRatio = 1;
  bool _animateBackdrop = true;
  bool _realTimeCapture = true;
  bool _useSync = true;
  bool _regionCapture = false;
  bool _compare = true;
  bool _localUnderlay = false;
  int _selectedTab = 1;

  void _update(RouteXGlassParams params) => setState(() => _params = params);

  Future<void> _copySource() async {
    await Clipboard.setData(ClipboardData(text: _params.toDartSource()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LiquidGlassStyle скопирован в буфер')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1040;
    final preview = _PreviewStage(
      params: _params,
      backdrop: _backdrop,
      detail: _detail,
      animate: _animateBackdrop,
      pixelRatio: _pixelRatio,
      realTimeCapture: _realTimeCapture,
      refreshRate: _refreshRate,
      useSync: _useSync,
      regionCapture: _regionCapture,
      compare: _compare,
      localUnderlay: _localUnderlay,
      selectedTab: _selectedTab,
      onSelectTab: (index) => setState(() => _selectedTab = index),
    );
    final controls = _buildControls(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RouteX Glass Playground'),
        actions: [
          TextButton.icon(
            onPressed: () => _update(RouteXGlassParams.routexSurface),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => unawaited(_copySource()),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy Dart'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: preview),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: controls),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 420, child: preview),
                const Divider(height: 1),
                Expanded(child: controls),
              ],
            ),
    );
  }

  Widget _buildControls(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          _Diagnostics(pixelRatio: _pixelRatio),
          const SizedBox(height: 16),
          _Section(
            title: 'Presets',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in RouteXGlassParams.presets.entries)
                    ActionChip(
                      label: Text(entry.key),
                      onPressed: () => _update(entry.value),
                    ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Сцена',
            children: [
              _ChoiceRow<RouteXBackdropVariant>(
                label: 'backdrop',
                values: RouteXBackdropVariant.values,
                value: _backdrop,
                labelOf: (variant) => variant.label,
                onChanged: (variant) => setState(() => _backdrop = variant),
              ),
              _SliderRow(
                label: 'detail',
                value: _detail,
                min: 0,
                max: 2,
                digits: 2,
                onChanged: (value) => setState(() => _detail = value),
              ),
              _SwitchRow(
                label: 'animate backdrop',
                value: _animateBackdrop,
                onChanged: (value) => setState(() => _animateBackdrop = value),
              ),
              _SwitchRow(
                label: 'compare with reference',
                value: _compare,
                onChanged: (value) => setState(() => _compare = value),
              ),
              _SwitchRow(
                label: 'local underlay (в child)',
                value: _localUnderlay,
                onChanged: (value) => setState(() => _localUnderlay = value),
              ),
            ],
          ),
          _Section(
            title: 'LiquidGlassView',
            children: [
              _SliderRow(
                label: 'pixelRatio',
                value: _pixelRatio,
                min: 0.25,
                max: 2,
                digits: 2,
                onChanged: (value) => setState(() => _pixelRatio = value),
              ),
              _ChoiceRow<LiquidGlassRefreshRate>(
                label: 'refreshRate',
                values: LiquidGlassRefreshRate.values,
                value: _refreshRate,
                labelOf: (rate) => rate.name,
                onChanged: (rate) => setState(() => _refreshRate = rate),
              ),
              _SwitchRow(
                label: 'realTimeCapture',
                value: _realTimeCapture,
                onChanged: (value) => setState(() => _realTimeCapture = value),
              ),
              _SwitchRow(
                label: 'useSync',
                value: _useSync,
                onChanged: (value) => setState(() => _useSync = value),
              ),
              _SwitchRow(
                label: 'regionCapture',
                value: _regionCapture,
                onChanged: (value) => setState(() => _regionCapture = value),
              ),
            ],
          ),
          _Section(
            title: 'Shape',
            children: [
              _ChoiceRow<LiquidGlassCornerStyle>(
                label: 'cornerStyle',
                values: LiquidGlassCornerStyle.values,
                value: _params.cornerStyle,
                labelOf: (style) => switch (style) {
                  LiquidGlassCornerStyle.continuousRoundedRectangle =>
                    'continuous',
                  LiquidGlassCornerStyle.squircle => 'squircle',
                  LiquidGlassCornerStyle.roundedRectangle => 'rounded',
                },
                onChanged: (style) =>
                    _update(_params.copyWith(cornerStyle: style)),
              ),
              _SliderRow(
                label: 'cornerRadius (свободная панель)',
                value: _params.cornerRadius,
                min: 0,
                max: 60,
                digits: 1,
                onChanged: (value) =>
                    _update(_params.copyWith(cornerRadius: value)),
              ),
              _SliderRow(
                label: 'borderWidth',
                value: _params.borderWidth,
                min: 0,
                max: 6,
                digits: 2,
                onChanged: (value) =>
                    _update(_params.copyWith(borderWidth: value)),
              ),
              _SliderRow(
                label: 'lightIntensity',
                value: _params.lightIntensity,
                min: 0,
                max: 3,
                digits: 2,
                onChanged: (value) =>
                    _update(_params.copyWith(lightIntensity: value)),
              ),
              _SliderRow(
                label: 'lightDirection',
                value: _params.lightDirection,
                min: 0,
                max: 360,
                digits: 0,
                onChanged: (value) =>
                    _update(_params.copyWith(lightDirection: value)),
              ),
              _ChoiceRow<LiquidGlassLightMode>(
                label: 'lightMode',
                values: LiquidGlassLightMode.values,
                value: _params.lightMode,
                labelOf: (mode) => mode.name,
                onChanged: (mode) => _update(_params.copyWith(lightMode: mode)),
              ),
              _SwitchRow(
                label: 'exact clip',
                value: _params.exactClip,
                onChanged: (value) =>
                    _update(_params.copyWith(exactClip: value)),
              ),
            ],
          ),
          _Section(
            title: 'Border',
            children: [
              _SwitchRow(
                label: 'optical border',
                value: _params.opticalBorder,
                onChanged: (value) =>
                    _update(_params.copyWith(opticalBorder: value)),
              ),
              if (_params.opticalBorder) ...[
                _SliderRow(
                  label: 'borderSaturation',
                  value: _params.borderSaturation,
                  min: 0,
                  max: 3,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(borderSaturation: value)),
                ),
                _SliderRow(
                  label: 'ambientIntensity',
                  value: _params.ambientIntensity,
                  min: 0,
                  max: 5,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(ambientIntensity: value)),
                ),
                _SliderRow(
                  label: 'borderSolidity',
                  value: _params.borderSolidity,
                  min: 0,
                  max: 1,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(borderSolidity: value)),
                ),
                _SliderRow(
                  label: 'lightSpread',
                  value: _params.lightSpread,
                  min: 0,
                  max: 1,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(lightSpread: value)),
                ),
              ] else ...[
                _SliderRow(
                  label: 'borderSoftness',
                  value: _params.borderSoftness,
                  min: 0,
                  max: 5,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(borderSoftness: value)),
                ),
                _SliderRow(
                  label: 'oneSideLightIntensity',
                  value: _params.oneSideLightIntensity,
                  min: 0,
                  max: 2,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(oneSideLightIntensity: value)),
                ),
                _SliderRow(
                  label: 'doubleSideLightIntensity',
                  value: _params.doubleSideLightIntensity,
                  min: 0,
                  max: 2,
                  digits: 2,
                  onChanged: (value) => _update(
                    _params.copyWith(doubleSideLightIntensity: value),
                  ),
                ),
              ],
            ],
          ),
          _Section(
            title: 'Appearance',
            children: [
              _ChoiceRow<Color>(
                label: 'tint',
                values: RouteXGlassParams.tintSwatches.values.toList(),
                value: _params.tintBase,
                labelOf: (color) => RouteXGlassParams.tintSwatches.entries
                    .firstWhere((entry) => entry.value == color)
                    .key,
                onChanged: (color) =>
                    _update(_params.copyWith(tintBase: color)),
              ),
              _SliderRow(
                label: 'tint alpha',
                value: _params.tintAlpha,
                min: 0,
                max: 0.5,
                digits: 3,
                onChanged: (value) =>
                    _update(_params.copyWith(tintAlpha: value)),
              ),
              _SliderRow(
                label: 'saturation',
                value: _params.saturation,
                min: 0,
                max: 2,
                digits: 2,
                onChanged: (value) =>
                    _update(_params.copyWith(saturation: value)),
              ),
              _SliderRow(
                label: 'blur sigma',
                value: _params.blurSigma,
                min: 0,
                max: 20,
                digits: 2,
                onChanged: (value) =>
                    _update(_params.copyWith(blurSigma: value)),
              ),
              _SwitchRow(
                label: 'enableInnerRadiusTransparent',
                value: _params.innerTransparent,
                onChanged: (value) =>
                    _update(_params.copyWith(innerTransparent: value)),
              ),
            ],
          ),
          _Section(
            title: 'Refraction',
            children: [
              _SwitchRow(
                label: 'optical refraction',
                value: _params.opticalRefraction,
                onChanged: (value) =>
                    _update(_params.copyWith(opticalRefraction: value)),
              ),
              if (_params.opticalRefraction) ...[
                _SliderRow(
                  label: 'refraction (индекс)',
                  value: _params.refractionIndex,
                  min: 1,
                  max: 2.5,
                  digits: 2,
                  onChanged: (value) =>
                      _update(_params.copyWith(refractionIndex: value)),
                ),
                _SliderRow(
                  label: 'refractionWidth',
                  value: _params.refractionWidth,
                  min: 1,
                  max: 80,
                  digits: 1,
                  onChanged: (value) =>
                      _update(_params.copyWith(refractionWidth: value)),
                ),
                _SliderRow(
                  label: 'depth',
                  value: _params.depth,
                  min: 0,
                  max: 1,
                  digits: 2,
                  onChanged: (value) => _update(_params.copyWith(depth: value)),
                ),
              ] else ...[
                _SliderRow(
                  label: 'distortion',
                  value: _params.distortion,
                  min: 0,
                  max: 1,
                  digits: 3,
                  onChanged: (value) =>
                      _update(_params.copyWith(distortion: value)),
                ),
                _SliderRow(
                  label: 'distortionWidth',
                  value: _params.distortionWidth,
                  min: 1,
                  max: 80,
                  digits: 1,
                  onChanged: (value) =>
                      _update(_params.copyWith(distortionWidth: value)),
                ),
              ],
              _SliderRow(
                label: 'magnification',
                value: _params.magnification,
                min: 0.5,
                max: 2,
                digits: 2,
                onChanged: (value) =>
                    _update(_params.copyWith(magnification: value)),
              ),
              _SliderRow(
                label: 'chromaticAberration',
                value: _params.chromaticAberration,
                min: 0,
                max: 0.05,
                digits: 4,
                onChanged: (value) =>
                    _update(_params.copyWith(chromaticAberration: value)),
              ),
              _ChoiceRow<LiquidGlassRefractionMode>(
                label: 'refractionMode',
                values: LiquidGlassRefractionMode.values,
                value: _params.refractionMode,
                labelOf: (mode) =>
                    mode == LiquidGlassRefractionMode.shapeRefraction
                        ? 'shape'
                        : 'radial',
                onChanged: (mode) =>
                    _update(_params.copyWith(refractionMode: mode)),
              ),
              _SliderRow(
                label: 'diagonalFlip',
                value: _params.diagonalFlip,
                min: 0,
                max: 1,
                digits: 2,
                onChanged: (value) =>
                    _update(_params.copyWith(diagonalFlip: value)),
              ),
            ],
          ),
          _Section(
            title: 'Dart',
            children: [
              SelectableText(
                _params.toDartSource(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      );
}

/// The refracting half of the screen: one `LiquidGlassView` whose
/// captured background is the selected backdrop, with the RouteX
/// specimens placed in its `child`.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({
    required this.params,
    required this.backdrop,
    required this.detail,
    required this.animate,
    required this.pixelRatio,
    required this.realTimeCapture,
    required this.refreshRate,
    required this.useSync,
    required this.regionCapture,
    required this.compare,
    required this.localUnderlay,
    required this.selectedTab,
    required this.onSelectTab,
  });

  final RouteXGlassParams params;
  final RouteXBackdropVariant backdrop;
  final double detail;
  final bool animate;
  final double pixelRatio;
  final bool realTimeCapture;
  final LiquidGlassRefreshRate refreshRate;
  final bool useSync;
  final bool regionCapture;
  final bool compare;
  final bool localUnderlay;
  final int selectedTab;
  final ValueChanged<int> onSelectTab;

  static const _reference = RouteXGlassParams.officialPanel;

  @override
  Widget build(BuildContext context) => LiquidGlassView(
        backgroundWidget: RouteXBackdrop(
          variant: backdrop,
          animate: animate,
          detail: detail,
        ),
        pixelRatio: pixelRatio,
        realTimeCapture: realTimeCapture,
        refreshRate: refreshRate,
        useSync: useSync,
        regionCapture: regionCapture,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (localUnderlay) const _LocalUnderlay(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 24,
                          runSpacing: 24,
                          children: [
                            _PanelSpecimen(
                              params: params,
                              caption: 'tuned',
                            ),
                            if (compare)
                              const _PanelSpecimen(
                                params: _reference,
                                caption: 'official reference',
                              ),
                            _ControlsSpecimen(params: params),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _NavSpecimen(
                    params: params,
                    selected: selectedTab,
                    onSelect: onSelectTab,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// A saturated block placed in `LiquidGlassView.child`, directly behind
/// the specimens. On Skia it is **not** part of the capture, so the
/// lenses above it keep refracting the backdrop instead — the exact
/// failure mode `_SidebarUnderlay` runs into today.
class _LocalUnderlay extends StatelessWidget {
  const _LocalUnderlay();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  premiumMint.withValues(alpha: 0.55),
                  premiumBlue.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PanelSpecimen extends StatelessWidget {
  const _PanelSpecimen({required this.params, required this.caption});

  final RouteXGlassParams params;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          height: 190,
          child: LiquidGlassLens(
            style: params.toStyle(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Panel',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'Читаемость текста поверх материала — такой же '
                    'критерий, как и сам эффект.',
                    style: theme.textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: premiumMint,
                      ),
                      const SizedBox(width: 8),
                      Text('124 ms', style: theme.textTheme.labelLarge),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(caption, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Dialog surface, circular control and a selection pill at the RouteX
/// radius tokens, so one tuned material can be judged at every size it
/// actually ships at.
class _ControlsSpecimen extends StatelessWidget {
  const _ControlsSpecimen({required this.params});

  final RouteXGlassParams params;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          height: 190,
          child: Column(
            children: [
              Expanded(
                child: LiquidGlassLens(
                  style: params.toStyle(radius: RouteXRadius.overlay),
                  child: Center(
                    child: Text('dialog', style: theme.textTheme.bodyMedium),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: LiquidGlassLens(
                        style: params.toStyle(radius: 28),
                        child: const Icon(Icons.tune_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiquidGlassLens(
                        style: params.toStyle(radius: RouteXRadius.control),
                        child: Center(
                          child: Text(
                            'control',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('dialog / control', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// The compact navigation capsule with a nested selection lens — the
/// arrangement that behaves differently on Skia than on Impeller.
class _NavSpecimen extends StatelessWidget {
  const _NavSpecimen({
    required this.params,
    required this.selected,
    required this.onSelect,
  });

  final RouteXGlassParams params;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _icons = <IconData>[
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.language_rounded,
    Icons.swap_horiz_rounded,
  ];

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 360,
          height: 68,
          child: LiquidGlassLens(
            style: params.toStyle(radius: RouteXRadius.navigation),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var index = 0; index < _icons.length; index++)
                  SizedBox(
                    width: 64,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => onSelect(index),
                      child: index == selected
                          ? LiquidGlassLens(
                              style: params.toStyle(radius: 20),
                              child: Icon(
                                _icons[index],
                                size: 20,
                                color: premiumMint,
                              ),
                            )
                          : Icon(_icons[index], size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.pixelRatio});

  final double pixelRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impeller = ui.ImageFilter.isShaderFilterSupported;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RouteXRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            impeller
                ? 'shader backdrop: supported (Impeller path)'
                : 'shader backdrop: unsupported (Skia capture path)',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'device pixel ratio ${devicePixelRatio.toStringAsFixed(2)} · '
            'capture ${pixelRatio.toStringAsFixed(2)}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.digits,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int digits;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Text(
              value.toStringAsFixed(digits),
              style: theme.textTheme.labelMedium?.copyWith(
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (raw) {
              final factor = _pow10(digits);
              onChanged((raw * factor).roundToDouble() / factor);
            },
          ),
        ),
      ],
    );
  }
}

/// Slider steps are quantized so the generated Dart carries clean
/// numbers instead of float noise.
double _pow10(int digits) {
  var result = 1.0;
  for (var i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T value;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in values)
                  ChoiceChip(
                    label: Text(labelOf(item)),
                    selected: item == value,
                    onSelected: (_) => onChanged(item),
                  ),
              ],
            ),
          ],
        ),
      );
}
