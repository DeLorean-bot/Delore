import 'package:flclashx/common/common.dart';
import 'package:flclashx/models/common.dart';
import 'package:flutter/material.dart';

class CommonPopupRoute<T> extends PopupRoute<T> {

  CommonPopupRoute({
    required this.barrierLabel,
    required this.builder,
    required this.offsetNotifier,
    required this.reduceMotion,
  });
  final WidgetBuilder builder;
  ValueNotifier<Offset> offsetNotifier;
  final bool reduceMotion;

  @override
  String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(
      context,
    );

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    const align = Alignment.topRight;
    final curved = CurvedAnimation(
      parent: animation,
      curve: RouteXMotion.curve,
    );
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: offsetNotifier,
        builder: (_, value, child) => Align(
            alignment: align,
            child: CustomSingleChildLayout(
              delegate: OverflowAwareLayoutDelegate(
                offset: value.translate(
                  48,
                  -8,
                ),
              ),
              child: child,
            ),
          ),
        child: AnimatedBuilder(
          animation: curved,
          builder: (_, child) => Opacity(
              opacity: 0.1 + 0.9 * curved.value,
              child: Transform.scale(
                alignment: align,
                scale: 0.92 + 0.08 * curved.value,
                child: Transform.translate(
                  offset: const Offset(0, -10) * (1 - curved.value),
                  child: child,
                ),
              ),
            ),
          child: builder(
            context,
          ),
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
}

class PopupController extends ValueNotifier<bool> {
  PopupController() : super(false);

  void open() {
    value = true;
  }

  void close() {
    value = false;
  }
}

typedef PopupOpen = Function({
  Offset offset,
});

class CommonPopupBox extends StatefulWidget {

  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    required this.popup,
  });
  final Widget Function(PopupOpen open) targetBuilder;
  final Widget popup;

  @override
  State<CommonPopupBox> createState() => _CommonPopupBoxState();
}

class _CommonPopupBoxState extends State<CommonPopupBox> {
  bool _isOpen = false;
  final _targetOffsetValueNotifier = ValueNotifier<Offset>(Offset.zero);
  Offset _offset = Offset.zero;

  void _open({Offset offset = Offset.zero}) {
    _offset = offset;
    _updateOffset();
    _isOpen = true;
    Navigator.of(context)
        .push(
      CommonPopupRoute(
        barrierLabel: utils.id,
        builder: (context) => widget.popup,
        offsetNotifier: _targetOffsetValueNotifier,
        reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      ),
    )
        .then((_) {
      _isOpen = false;
    });
  }

  void _updateOffset() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final viewPadding = MediaQuery.of(context).viewPadding;
    _targetOffsetValueNotifier.value = renderBox
        .localToGlobal(
          Offset.zero.translate(
            viewPadding.right,
            viewPadding.top,
          ),
        )
        .translate(
          _offset.dx,
          _offset.dy,
        );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isOpen) {
          _updateOffset();
        }
      });
      return widget.targetBuilder(_open);
    });
}

class OverflowAwareLayoutDelegate extends SingleChildLayoutDelegate {

  OverflowAwareLayoutDelegate({
    required this.offset,
  });
  final Offset offset;

  @override
  Size getSize(BoxConstraints constraints) => Size(constraints.maxWidth, constraints.maxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const safeOffset = Offset(16, 16);
    final x = (offset.dx - childSize.width).clamp(
      0.0,
      size.width - safeOffset.dx - childSize.width,
    );
    final y = (offset.dy).clamp(
      0.0,
      size.height - safeOffset.dy - childSize.height,
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant OverflowAwareLayoutDelegate oldDelegate) => oldDelegate.offset != offset;
}

class CommonPopupMenu extends StatelessWidget {

  const CommonPopupMenu({
    super.key,
    required this.items,
    this.minWidth = 200,
    this.minItemVerticalPadding = 16,
    this.fontSize = 15,
    this.onDismiss,
    this.trailingPadding = 64,
  });
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;
  final double fontSize;

  /// How to close this menu when an item is picked.
  ///
  /// Defaults to popping the navigator, which is correct only when the menu
  /// is shown as a route. Hosted in an [OverlayEntry] instead, that pop takes
  /// the *page underneath* with it — the app is left showing an empty window.
  /// Overlay callers must pass their own dismiss here.
  final VoidCallback? onDismiss;

  /// Space reserved to the right of each label. The 64 default leaves room
  /// for a trailing control; a plain list of names just reads as lopsided.
  final double trailingPadding;

  Widget _popupMenuItem(
    BuildContext context, {
    required PopupMenuItemData item,
    required int index,
  }) {
    final onPressed = item.onPressed;
    final disabled = onPressed == null;
    final color = disabled
        ? context.colorScheme.onSurface.opacity30
        : context.colorScheme.onSurface;
    return InkWell(
      onTap: onPressed != null
          ? () {
              (onDismiss ?? Navigator.of(context).pop)();
              onPressed();
            }
          : null,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minWidth,
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: trailingPadding,
          top: minItemVerticalPadding,
          bottom: minItemVerticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: fontSize + 4,
                color: color,
              ),
              const SizedBox(
                width: 16,
              ),
            ],
            Flexible(
              child: Text(
                item.label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
      child: IntrinsicWidth(
        child: Card(
          elevation: 12,
          color: context.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items.asMap().entries) ...[
                _popupMenuItem(
                  context,
                  item: item.value,
                  index: item.key,
                ),
                if (item.value != items.last)
                  const Divider(
                    height: 0,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
}
