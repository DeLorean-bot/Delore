import 'package:flclashx/manager/message_manager.dart';
import 'package:flclashx/widgets/scaffold.dart';
import 'package:flutter/material.dart';

// Flutter only arms a SnackBar's own auto-dismiss timer from inside
// ScaffoldMessengerState.build() (see the framework's scaffold.dart), gated
// on that build actually running with its ModalRoute current. In this app
// that gate reliably failed to reopen for at least one call site (the
// Applications page's route-change toast, worked around by hand there with
// exactly this generation-counter trick before it was pulled up here) and
// the same stuck-forever symptom reproduces from pages with no special
// polling of their own, so the cause isn't fully pinned down — but the
// practical fix is the same either way: don't lean on the framework's timer
// at all, drive dismissal from here instead. A generation counter (not a
// per-call Timer) so a newer message's own dismiss can't be pre-empted by
// an older one's delayed callback firing after the fact.
int _snackBarGeneration = 0;

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
    final messenger = ScaffoldMessenger.of(this);
    // A caller that fires another message before the last one's duration
    // elapsed (e.g. delete → undo-toast right after an add/remove error)
    // used to queue behind it instead of replacing it — Flutter only starts
    // a new SnackBar's dismiss timer once the previous one has fully played
    // its exit animation, so a couple of quick actions in a row could leave
    // a stale message sitting on screen looking permanently stuck. Clearing
    // immediately (not hideCurrentSnackBar's animated exit, which is itself
    // a message this one would have to wait behind) makes "latest message
    // wins" the actual behavior instead of a first-in-first-out queue.
    messenger.removeCurrentSnackBar();
    const duration = Duration(milliseconds: 1500);
    messenger.showSnackBar(
      SnackBar(
        action: action,
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        width: width < 600 ? null : 340,
        margin: width < 600
            ? const EdgeInsets.only(bottom: 16, right: 16, left: 16)
            : null,
      ),
    );
    final generation = ++_snackBarGeneration;
    Future.delayed(duration + const Duration(milliseconds: 100), () {
      if (generation != _snackBarGeneration) return;
      messenger.removeCurrentSnackBar();
    });
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
