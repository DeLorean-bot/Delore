import 'package:flclashx/manager/message_manager.dart';
import 'package:flclashx/widgets/scaffold.dart';
import 'package:flutter/material.dart';

extension BuildContextExtension on BuildContext {
  CommonScaffoldState? get commonScaffoldState => findAncestorStateOfType<CommonScaffoldState>();

  Future<void>? showNotifier(String text) => findAncestorStateOfType<MessageManagerState>()?.message(text);

  void showSnackBar(
    String message, {
    SnackBarAction? action,
  }) {
    // Used to size the SnackBar via `width:` rather than `margin:`. The old
    // margin math (`right: viewWidth - 316`) assumed the SnackBar lays out
    // against the full MediaQuery width, but CommonScaffold's body — which
    // is what a floating SnackBar actually renders against — is clamped to
    // `BoxConstraints(maxWidth: 1680)` on desktop (see scaffold.dart). At a
    // wide window that mismatch left a right-margin bigger than the box the
    // SnackBar actually had to fit in, squeezing it down to a near-zero
    // width where every word wrapped onto its own line. `width:` sets the
    // box directly and can't drift out of sync with wherever it's hosted.
    final width = viewWidth;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        action: action,
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        width: width < 600 ? null : 340,
        margin: width < 600
            ? const EdgeInsets.only(bottom: 16, right: 16, left: 16)
            : null,
      ),
    );
  }

  Size get appSize => MediaQuery.of(this).size;

  double get viewWidth => appSize.width;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  T? findLastStateOfType<T extends State>() {
    T? state;

    void visitor(Element element) {
      if (!element.mounted) {
        return;
      }
      if (element is StatefulElement) {
        if (element.state is T) {
          state = element.state as T;
        }
      }
      element.visitChildren(visitor);
    }

    visitor(this as Element);
    return state;
  }
}
