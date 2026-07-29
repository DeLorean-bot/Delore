import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/fade_box.dart';
import 'package:flclashx/widgets/pop_scope.dart';
import 'package:flclashx/widgets/routex_backdrop.dart';
import 'package:flclashx/widgets/search_order_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'chip.dart';

class CommonScaffold extends ConsumerStatefulWidget {
  const CommonScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.sideNavigationBar,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.leading,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.appBarEditState,
    this.floatingActionButton,
    this.disableBackground = false,
    this.showAppBar = true,
  });

  CommonScaffold.open({
    Key? key,
    required Widget body,
    required String title,
    required Function onBack,
    required List<Widget> actions,
    bool disableBackground = false,
  }) : this(
          key: key,
          body: body,
          title: title,
          automaticallyImplyLeading: false,
          actions: actions,
          disableBackground: disableBackground,
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: () {
              onBack();
            },
          ),
        );
  final AppBar? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? sideNavigationBar;
  final Color? backgroundColor;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final AppBarEditState? appBarEditState;
  final FloatingActionButton? floatingActionButton;
  final bool disableBackground;

  /// Whether the floating glass app bar is drawn. A screen that opens
  /// with its own heading — the Dashboard — sets this false: a chrome bar
  /// repeating the page name above a card that names it again is noise,
  /// and it costs the top of the viewport.
  final bool showAppBar;

  @override
  ConsumerState<CommonScaffold> createState() => CommonScaffoldState();
}

/// Height of the floating glass app bar. Fixed, so the captured content
/// layer can reserve exactly the same space without measuring it.
///
/// Was 64 — a big glass slab with a shadow for what is a title and a row
/// of small icon buttons. Trimmed to read as a slim floating strip
/// instead of a heavy bar eating the top of the page.
const double _appBarHeight = 52;

class CommonScaffoldState extends ConsumerState<CommonScaffold> {
  late final ValueNotifier<AppBarState> _appBarState;
  final ValueNotifier<Widget?> _floatingActionButton = ValueNotifier(null);
  final ValueNotifier<List<String>> _keywordsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _loading = ValueNotifier(false);

  final _textController = TextEditingController();

  Function(List<String>)? _onKeywordsUpdate;

  Widget? get _sideNavigationBar => widget.sideNavigationBar;

  set actions(List<Widget> actions) {
    _appBarState.value = _appBarState.value.copyWith(actions: actions);
  }

  bool get _isSearch => _appBarState.value.searchState?.isSearch ?? false;

  bool get _isEdit => _appBarState.value.editState?.isEdit ?? false;

  set onKeywordsUpdate(Function(List<String>)? onKeywordsUpdate) {
    _onKeywordsUpdate = onKeywordsUpdate;
  }

  @override
  void initState() {
    super.initState();
    _appBarState = ValueNotifier(
      AppBarState(
        editState: widget.appBarEditState,
      ),
    );
  }

  void updateSearchState(
    AppBarSearchState? Function(AppBarSearchState? state) builder,
  ) {
    _appBarState.value = _appBarState.value.copyWith(
      searchState: builder(
        _appBarState.value.searchState,
      ),
    );
  }

  void updateEditState(
    AppBarEditState? Function(AppBarEditState? state) builder,
  ) {
    _appBarState.value = _appBarState.value.copyWith(
      editState: builder(
        _appBarState.value.editState,
      ),
    );
  }

  set floatingActionButton(Widget? floatingActionButton) {
    if (_floatingActionButton.value != floatingActionButton) {
      _floatingActionButton.value = floatingActionButton;
    }
  }

  Widget _buildSearchingAppBarTheme(Widget child) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: colorScheme.brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
          iconTheme: theme.primaryIconTheme.copyWith(color: Colors.grey),
          titleTextStyle: theme.textTheme.titleLarge,
          toolbarTextStyle: theme.textTheme.bodyMedium,
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: theme.inputDecorationTheme.hintStyle,
          border: InputBorder.none,
        ),
      ),
      child: child,
    );
  }

  Future<T?> loadingRun<T>(
    Future<T> Function() futureFunction, {
    String? title,
  }) async {
    _loading.value = true;
    try {
      final res = await futureFunction();
      _loading.value = false;
      return res;
    } catch (e) {
      await globalState.showMessage(
        title: title ?? appLocalizations.tip,
        message: TextSpan(
          text: e.toString(),
        ),
      );
      _loading.value = false;
      return null;
    }
  }

  void _handleClearInput() {
    _textController.text = "";

    if (_appBarState.value.searchState != null) {
      _appBarState.value.searchState!.onSearch("");
    }
  }

  void _handleClear() {
    if (_textController.text.isNotEmpty) {
      _handleClearInput();
      return;
    }
    updateSearchState(
      (state) => state?.copyWith(
        isSearch: false,
      ),
    );
  }

  void _handleExitSearching() {
    _handleClearInput();
    updateSearchState(
      (state) => state?.copyWith(
        isSearch: false,
      ),
    );
  }

  @override
  void dispose() {
    _appBarState.dispose();
    _textController.dispose();
    _floatingActionButton.dispose();
    _keywordsNotifier.dispose();
    _loading.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommonScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _appBarState.value = const AppBarState();
      _floatingActionButton.value = null;
      _textController.text = "";
      _keywordsNotifier.value = [];
      _onKeywordsUpdate = null;
    } else if (oldWidget.appBarEditState != widget.appBarEditState) {
      _appBarState.value = _appBarState.value.copyWith(
        editState: widget.appBarEditState,
      );
    }
  }

  void addKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)..add(keyword);
    _keywordsNotifier.value = keywords;
  }

  void _deleteKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (!isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)
      ..remove(keyword);
    _keywordsNotifier.value = keywords;
  }

  Widget? _buildLeading() {
    if (_isEdit) {
      return IconButton(
        onPressed: _appBarState.value.editState?.onExit,
        icon: const Icon(Icons.close),
      );
    }
    return _isSearch
        ? IconButton(
            onPressed: _handleExitSearching,
            icon: const Icon(Icons.arrow_back),
          )
        : widget.leading;
  }

  Widget _buildTitle(AppBarSearchState? startState) => _isSearch
      ? TextField(
          autofocus: true,
          controller: _textController,
          style: context.textTheme.titleLarge,
          onChanged: (value) {
            if (startState != null) {
              startState.onSearch(value);
            }
          },
          decoration: InputDecoration(
            hintText: appLocalizations.search,
          ),
        )
      : Text(
          !_isEdit
              ? widget.title!
              : appLocalizations.selectedCountTitle(
                  "${_appBarState.value.editState?.editCount ?? 0}",
                ),
        );

  List<Widget> _buildActions(
    AppBarSearchState? searchState,
    List<Widget> actions,
  ) {
    if (_isSearch) {
      return genActions([
        IconButton(
          onPressed: _handleClear,
          icon: const Icon(Icons.close),
        ),
      ]);
    }

    final hasSearch = searchState != null;
    final searchButton = IconButton(
      onPressed: () {
        updateSearchState(
          (state) => state?.copyWith(
            isSearch: true,
          ),
        );
      },
      icon: const Icon(Icons.search),
    );

    if (!hasSearch) {
      return genActions([
        ...actions,
      ]);
    }

    // For Proxies page we want search at the end; for others keep default
    // Check for explicit marker widget in actions to control search placement
    final shouldPutSearchAtEnd = actions.any((w) => w is SearchOrderMarker);

    if (shouldPutSearchAtEnd) {
      return genActions([
        ...actions,
        searchButton,
      ]);
    }

    return genActions([
      searchButton,
      ...actions,
    ]);
  }

  Widget _buildAppBarWrap(Widget child) {
    final appBar = _isSearch ? _buildSearchingAppBarTheme(child) : child;
    if (_isEdit || _isSearch) {
      return SystemBackBlock(
        child: CommonPopScope(
          onPop: () {
            if (_isEdit || _isSearch) {
              _handleExitSearching();
              _appBarState.value.editState?.onExit();
              return false;
            }
            return true;
          },
          child: appBar,
        ),
      );
    }
    return appBar;
  }

  PreferredSizeWidget _buildAppBar() => PreferredSize(
        preferredSize: const Size.fromHeight(_appBarHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 2),
          child: RouteXGlassSurface(
            variant: RouteXGlassVariant.navigation,
            radius: 18,
            shadowOffset: const Offset(0, 4),
            child: Theme(
              data: Theme.of(context).copyWith(
                appBarTheme: AppBarTheme(
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        Theme.of(context).brightness == Brightness.dark
                            ? Brightness.light
                            : Brightness.dark,
                    systemNavigationBarIconBrightness:
                        Theme.of(context).brightness == Brightness.dark
                            ? Brightness.light
                            : Brightness.dark,
                    systemNavigationBarColor: widget.bottomNavigationBar != null
                        ? context.colorScheme.surfaceContainer
                        : context.colorScheme.surface,
                    systemNavigationBarDividerColor: Colors.transparent,
                  ),
                ),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  widget.appBar ??
                      ValueListenableBuilder<AppBarState>(
                        valueListenable: _appBarState,
                        builder: (_, state, __) => _buildAppBarWrap(
                          AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            surfaceTintColor: Colors.transparent,
                            // Material's default toolbarHeight (56) no
                            // longer fits inside the trimmed glass card;
                            // match the space _appBarHeight's padding
                            // actually leaves it.
                            toolbarHeight: _appBarHeight - 7,
                            centerTitle: widget.centerTitle ?? false,
                            automaticallyImplyLeading:
                                widget.automaticallyImplyLeading,
                            leading: _buildLeading(),
                            title: _buildTitle(state.searchState),
                            actions: _buildActions(
                              state.searchState,
                              state.actions.isNotEmpty
                                  ? state.actions
                                  : widget.actions ?? [],
                            ),
                          ),
                        ),
                      ),
                  // A slim inset mint strip, not the stock full-width
                  // square-cornered Material bar: that one's hard corners
                  // poked out past the glass bar's own rounded edge, which
                  // read as a broken stripe slapped onto a soft card.
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 22,
                      right: 22,
                      bottom: 9,
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: _loading,
                      builder: (_, value, __) => AnimatedOpacity(
                        opacity: value ? 1 : 0,
                        duration: RouteXMotion.resolve(
                          context,
                          RouteXMotion.fast,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            height: 2.5,
                            child: value
                                ? const LinearProgressIndicator(
                                    minHeight: 2.5,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation(
                                      premiumMint,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildPremiumBackdrop() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = context.colorScheme.surfaceContainerLowest;
    final topColor = dark ? const Color(0xFF0A1017) : const Color(0xFFF3FAFA);
    final bottomColor =
        dark ? const Color(0xFF070A10) : const Color(0xFFF5F7FC);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                topColor,
                background,
                bottomColor,
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.92, -0.86),
                radius: 0.92,
                colors: [
                  premiumMint.withValues(alpha: dark ? 0.075 : 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.72, -1.05),
                radius: 0.8,
                colors: [
                  premiumBlue.withValues(alpha: dark ? 0.09 : 0.13),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.38, 1.15),
                radius: 1,
                colors: [
                  premiumBlue.withValues(alpha: dark ? 0.035 : 0.055),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(String? backgroundUrl) {
    if (backgroundUrl == null || backgroundUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: backgroundUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildOverlay(BuildContext context, int? opacity) {
    // Dimming overlay over the background image. `opacity` (1-100, from the optional
    // `,<opacity>` suffix of flclashx-background) = how visible the image should be:
    // higher opacity → lower overlay alpha → more visible image. Unset → keep the
    // original hardcoded look (image ~10% visible).
    final double topAlpha;
    final double bottomAlpha;
    if (opacity == null) {
      topAlpha = 0.92;
      bottomAlpha = 0.88;
    } else {
      final base = (1 - opacity / 100).clamp(0.0, 1.0);
      topAlpha = base;
      bottomAlpha = (base - 0.04).clamp(0.0, 1.0);
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.colorScheme.surface.withValues(alpha: topAlpha),
            context.colorScheme.surface.withValues(alpha: bottomAlpha),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.appBar != null || widget.title != null,
      'CommonScaffold requires either appBar or title.',
    );
    final backgroundUrl =
        widget.disableBackground ? null : ref.watch(backgroundUrlProvider);
    final viewMode = ref.watch(viewModeProvider);
    final isDashboard =
        ref.watch(currentPageLabelProvider) == PageLabel.dashboard;
    final pageBody = viewMode == ViewMode.desktop
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1680),
              child: widget.body,
            ),
          )
        : widget.body;

    // No backdrop here on purpose: the scene below is the single copy,
    // and it is what the glass refracts. Painting it again above the
    // capture would hide the scene, double the full-screen paint cost
    // and leave the lenses bending a background nobody sees.
    final body = Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder(
                valueListenable: _keywordsNotifier,
                builder: (_, keywords, __) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onKeywordsUpdate?.call(keywords);
                  });
                  if (keywords.isEmpty) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Wrap(
                      runSpacing: 8,
                      spacing: 8,
                      children: [
                        for (final keyword in keywords)
                          CommonChip(
                            label: keyword,
                            type: ChipType.delete,
                            onPressed: () {
                              _deleteKeyword(keyword);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: pageBody,
              ),
            ],
          ),
        ),
      ],
    );

    // ── The split that makes the glass real ──────────────────
    //
    // On Skia a LiquidGlassLens can only refract what its ancestor
    // LiquidGlassView captured — its `backgroundWidget`. Anything in
    // `child` is painted over the capture and is never sampled. With the
    // page in `child`, the bars were bending a decorative mesh while the
    // actual interface slid past untouched, which is why the material
    // read as a translucent panel rather than glass.
    //
    // So the page goes into the capture and only the glass chrome stays
    // above it. Both layers are laid out by the same rules — a fixed
    // 64 px app bar at the top, the bottom bar at the bottom, the side
    // navigation on the left — so the content is inset exactly where the
    // chrome sits. The chrome's slots in the content layer are ghosts:
    // laid out at full size, never painted.
    final navGhost = widget.bottomNavigationBar == null
        ? null
        : Visibility(
            visible: false,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: widget.bottomNavigationBar!,
          );

    final contentScaffold = Scaffold(
      // The page runs edge to edge, under both bars, and the ghosts only
      // report their size through MediaQuery so scrollables can pad for
      // them. Without this the Scaffold pushes the page clear of the
      // bars and there is nothing under the glass but backdrop — the
      // whole point of putting the page in the capture.
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: widget.showAppBar
          ? const PreferredSize(
              preferredSize: Size.fromHeight(_appBarHeight),
              child: SizedBox.shrink(),
            )
          : null,
      body: body,
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.floatingActionButton ??
          ValueListenableBuilder<Widget?>(
            valueListenable: _floatingActionButton,
            builder: (_, value, __) => IntrinsicWidth(
              child: IntrinsicHeight(
                child: FadeScaleBox(
                  child: value ?? const SizedBox(),
                ),
              ),
            ),
          ),
      bottomNavigationBar: navGhost,
    );

    final contentLayer = _sideNavigationBar != null
        ? Row(
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainState: true,
                maintainAnimation: true,
                child: _sideNavigationBar!,
              ),
              Expanded(child: contentScaffold),
            ],
          )
        : contentScaffold;

    // Chrome only. A Stack hit-tests its children and nothing else, so
    // taps in the empty middle fall through to the page in the capture.
    final chromeColumn = Stack(
      fit: StackFit.expand,
      children: [
        if (widget.showAppBar)
          Positioned(
            // Keyed: without it the Stack matches children by index and
            // type, so toggling the app bar hands the bar's element to
            // the app bar and rebuilds the bar from scratch — taking the
            // selection spring's controller with it, which is why the
            // pill stopped animating between pages.
            key: const ValueKey('routex-app-bar'),
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: _appBarHeight,
              child: _buildAppBar(),
            ),
          ),
        if (widget.bottomNavigationBar != null)
          Positioned(
            key: const ValueKey('routex-bottom-nav'),
            left: 0,
            right: 0,
            bottom: 0,
            child: widget.bottomNavigationBar!,
          ),
      ],
    );

    final chromeLayer = _sideNavigationBar != null
        ? Row(
            children: [
              _sideNavigationBar!,
              Expanded(child: chromeColumn),
            ],
          )
        : chromeColumn;

    final scene = _RouteXSceneTransition(
      active: isDashboard,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPremiumBackdrop(),
          RouteXBackdrop(active: isDashboard),
          if (backgroundUrl != null) ...[
            _buildBackground(backgroundUrl),
            _buildOverlay(
              context,
              widget.disableBackground
                  ? null
                  : ref.watch(backgroundOpacityProvider),
            ),
          ],
        ],
      ),
    );

    return LiquidGlassView(
      backgroundWidget: Stack(
        fit: StackFit.expand,
        children: [
          scene,
          contentLayer,
        ],
      ),
      // Capture at the display's own density. A fixed `1` is *below*
      // native on any scaled Windows desktop (125% / 150%), so the
      // refracted background was being upscaled — the glass looked like
      // it was rendered at the wrong resolution because it was.
      pixelRatio: MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0),
      // Live, on every screen. Once the page moved into the capture this
      // stopped being an optimisation: a single snapshot means the
      // refraction shows the first frame of a list you are still
      // scrolling, while the blur — a separate BackdropFilterLayer — stays
      // live. The two sources drift apart and the glass looks broken.
      realTimeCapture:
          !(MediaQuery.maybeOf(context)?.disableAnimations ?? false),
      refreshRate: LiquidGlassRefreshRate.high,
      useSync: true,
      child: chromeLayer,
    );
  }
}

class _RouteXSceneTransition extends StatelessWidget {
  const _RouteXSceneTransition({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: active ? 0 : 1),
      duration: RouteXMotion.resolve(
        context,
        const Duration(milliseconds: 280),
      ),
      curve: RouteXMotion.curve,
      builder: (context, progress, _) => Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 4 * progress,
              sigmaY: 4 * progress,
            ),
            child: child,
          ),
          IgnorePointer(
            child: ColoredBox(
              color: (dark ? const Color(0xFF050608) : Colors.white)
                  .withValues(alpha: (dark ? 0.08 : 0.1) * progress),
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> genActions(List<Widget> actions, {double? space}) => <Widget>[
      ...actions.separated(
        SizedBox(
          width: space ?? 4,
        ),
      ),
      const SizedBox(
        width: 8,
      )
    ];
