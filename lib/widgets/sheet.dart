import 'dart:math' as math;
import 'dart:ui';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';

@immutable
class SheetProps {
  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool blur;
}

@immutable
class ExtendProps {
  const ExtendProps({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.blur = true,
  });
  final double? maxWidth;
  final double? maxHeight;
  final bool useSafeArea;
  final bool blur;
}

enum SheetType {
  page,
  bottomSheet,
  sideSheet,
  dialog,
}

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: props.isScrollControlled,
        backgroundColor: Colors.transparent,
        builder: (_) => BackdropFilter(
          filter: props.blur ? commonFilter : ImageFilter.blur(),
          child: SafeArea(
            child: builder(context, SheetType.bottomSheet),
          ),
        ),
        showDragHandle: false,
        useSafeArea: props.useSafeArea,
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        isScrollControlled: props.isScrollControlled,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur ? commonFilter : null,
        builder: (_) => builder(context, SheetType.sideSheet),
      ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required SheetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => BaseNavigator.push(
        context,
        builder(context, SheetType.page),
      ),
    false => showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.48),
        transitionDuration: RouteXMotion.resolve(
          context,
          const Duration(milliseconds: 220),
        ),
        pageBuilder: (dialogContext, _, __) {
          final size = MediaQuery.sizeOf(dialogContext);
          final width = math.min(props.maxWidth ?? 420, size.width - 48);
          final height = math.min(props.maxHeight ?? 720, size.height - 72);
          return SafeArea(
            child: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: RouteXGlassSurface(
                  variant: RouteXGlassVariant.navigation,
                  radius: 24,
                  tintAlphaFactor: 1,
                  blurFactor: 0.55,
                  shadowOffset: const Offset(0, 16),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xA6000000),
                    ),
                    child: builder(dialogContext, SheetType.dialog),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: RouteXMotion.curve),
            ),
            child: child,
          ),
        ),
      ),
  };
}

class AdaptiveSheetScaffold extends StatefulWidget {
  const AdaptiveSheetScaffold({
    super.key,
    required this.type,
    required this.body,
    required this.title,
    this.actions = const [],
    this.disableBackground = true,
  });
  final SheetType type;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final bool disableBackground;

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bottomSheet = widget.type == SheetType.bottomSheet;
    final sideSheet = widget.type == SheetType.sideSheet;
    final dialog = widget.type == SheetType.dialog;
    final backgroundColor = sideSheet
        ? colorScheme.surface.withValues(alpha: 0.92)
        : colorScheme.surface.withValues(alpha: 0.92);
    if (dialog) {
      return Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...widget.actions,
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.32),
            ),
            Expanded(child: widget.body),
          ],
        ),
      );
    }
    final appBar = AppBar(
      forceMaterialTransparency: bottomSheet ? true : false,
      automaticallyImplyLeading: bottomSheet
          ? false
          : widget.actions.isEmpty && sideSheet
              ? false
              : true,
      centerTitle: bottomSheet,
      backgroundColor: backgroundColor,
      title: Text(
        widget.title,
      ),
      actions: genActions([
        if (widget.actions.isEmpty && sideSheet) const CloseButton(),
        ...widget.actions,
      ]),
    );
    if (bottomSheet) {
      const handleSize = Size(32, 4);
      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                alignment: Alignment.center,
                height: handleSize.height,
                width: handleSize.width,
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(handleSize.height / 2),
                  ),
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            appBar,
            Flexible(
              flex: 1,
              child: widget.body,
            )
          ],
        ),
      );
    }
    return CommonScaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      // The floating glass bar is painted in a layer above the page, and
      // the page begins directly beneath it, so the first row of every
      // side sheet (settings sub-pages, profile and proxy sheets) sat in
      // the bar's blurred edge. This is the gap, applied once for all of
      // them rather than page by page.
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: widget.body,
      ),
      disableBackground: widget.disableBackground,
    );
  }
}
