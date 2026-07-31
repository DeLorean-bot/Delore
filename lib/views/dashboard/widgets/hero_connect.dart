import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/profiles/add_profile.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
String _countryCodeToEmoji(String code) {
  if (code.length != 2) return '🌐';
  final upper = code.toUpperCase();
  final first = 0x1F1E6 - 0x41 + upper.codeUnitAt(0);
  final second = 0x1F1E6 - 0x41 + upper.codeUnitAt(1);
  return String.fromCharCodes([first, second]);
}

// Derive an ISO country code from the first regional-indicator flag emoji found
// in [text] (e.g. "🇳🇱 Amsterdam" -> "NL"). Returns null when there's no flag.
String? _flagToCountryCode(String text) {
  final runes = text.runes.toList();
  for (var i = 0; i < runes.length - 1; i++) {
    final a = runes[i];
    final b = runes[i + 1];
    if (a >= 0x1F1E6 && a <= 0x1F1FF && b >= 0x1F1E6 && b <= 0x1F1FF) {
      final c1 = a - 0x1F1E6 + 0x41;
      final c2 = b - 0x1F1E6 + 0x41;
      return String.fromCharCodes([c1, c2]);
    }
  }
  return null;
}

// Collect the distinct ISO country codes carried by the flag emoji in the names
// of every proxy in [group], descending a few levels into nested groups. Used to
// paint a faint backdrop of the group's flags behind the active one.
List<String> _collectGroupFlags(List<Group> groups, Group group) {
  final seen = <String>{};
  final codes = <String>[];
  void walk(Group g, int depth) {
    if (depth > 4) return;
    for (final proxy in g.all) {
      final code = _flagToCountryCode(proxy.name);
      if (code != null) {
        if (seen.add(code)) codes.add(code);
      } else {
        final sub = groups.getGroup(proxy.name);
        if (sub != null) walk(sub, depth + 1);
      }
    }
  }

  walk(group, 0);
  return codes;
}

// Strip only the *leading* emoji run from the name — typically the flag prefix
// (e.g. "🇳🇱 Amsterdam"), which we already render separately as the flag icon.
// Emoji that appear later in the name are kept intact.
String _stripLeadingEmoji(String text) {
  bool isEmojiRune(int r) {
    final isFlag = r >= 0x1F1E6 && r <= 0x1F1FF;
    final isModifier =
        r == 0x200D || r == 0xFE0F || (r >= 0x1F3FB && r <= 0x1F3FF);
    final isPictograph = (r >= 0x1F000 && r <= 0x1FAFF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x2190 && r <= 0x21FF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0x2300 && r <= 0x23FF);
    return isFlag || isModifier || isPictograph;
  }

  bool isSpace(int r) =>
      r == 0x20 || r == 0x09 || r == 0xA0 || r == 0x0A || r == 0x0D;

  final runes = text.runes.toList();
  var start = 0;
  // Consume the leading run of emoji (and any whitespace around it) so a flag
  // prefixed with or followed by spaces is still removed; stop at the first
  // real character and keep the remainder verbatim.
  while (start < runes.length &&
      (isEmojiRune(runes[start]) || isSpace(runes[start]))) {
    start++;
  }
  return String.fromCharCodes(runes.sublist(start))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(1)} ${units[i]}';
}

// Russian-aware plural form for "days" (mirrors MetainfoWidget's declension).
String _daysWord(int days) {
  if (days % 100 >= 11 && days % 100 <= 19) return appLocalizations.days;
  switch (days % 10) {
    case 1:
      return appLocalizations.day;
    case 2:
    case 3:
    case 4:
      return appLocalizations.daysGenitive;
    default:
      return appLocalizations.days;
  }
}

String? _decodeAnnounce(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final decoded = _decodeBase64(trimmed);
  if (decoded == null || decoded.trim().isEmpty) return null;
  return decoded.trim();
}

String? _decodeBase64(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var text = value.trim();
  if (text.startsWith('base64:')) text = text.substring(7).trim();
  if (text.isEmpty) return null;
  try {
    final normalized = base64.normalize(text);
    final decoded = utf8.decode(base64.decode(normalized)).trim();
    return decoded.isEmpty ? null : decoded;
  } catch (_) {
    return value.trim().isEmpty ? null : value.trim();
  }
}

// ----------------------------------------------------------------------------
// Focusable tap wrapper — makes a tappable area reachable by a D-pad/remote
// (Android TV). The hero board's controls were bare GestureDetectors, which
// have no focus node and don't respond to D-pad-center/Enter, so the TV remote
// couldn't focus or activate them. This adds a focus node, a primary-colour ring
// + subtle scale while focused, and activates onTap on both tap and Enter/Select.
// ----------------------------------------------------------------------------
// Promoted to widgets/focusable_tap.dart as RouteXFocusableTap once
// _RoutingModeToggle (lib/pages/home.dart) needed the same hover/focus
// wrapper — a private class can't cross files. Aliased locally so the many
// call sites in this file didn't all need renaming.
typedef _FocusableTap = RouteXFocusableTap;

// ----------------------------------------------------------------------------
// Hero
// ----------------------------------------------------------------------------
class HeroConnect extends ConsumerWidget {
  const HeroConnect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.hasProfile) return const _EmptyHero();

    final profile = ref.watch(currentProfileProvider);
    final runTime = ref.watch(runTimeProvider);
    final isRunning = runTime != null;
    final subscription = profile?.subscriptionInfo;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final headers = profile?.providerHeaders ?? const {};
    // Only a real provider-branded name earns a headline — falling back to
    // the app's own name here just repeats what the window title already
    // says, which is the exact "why is this written twice" complaint.
    final brandName = _decodeBase64(headers['flclashx-servicename']);
    final supportUrl = headers['support-url'];

    // Same resolution _LegacyHeroConnect used: the group named in the
    // `flclashx-serverinfo` header if the provider sends one, else the
    // first group with a real (non-DIRECT/REJECT) live selection. Only
    // needed here for its flag emoji, to plot the active dot on the map.
    final groups = ref.watch(currentGroupsStateProvider).value;
    var activeServerName = '';
    final serverInfoHeader = headers['flclashx-serverinfo'];
    if (serverInfoHeader != null && serverInfoHeader.isNotEmpty) {
      final groupName =
          _decodeBase64(serverInfoHeader) ?? serverInfoHeader.trim();
      final group = groups.getGroup(groupName);
      if (group != null) {
        activeServerName = groups.resolveToDisplayName(group.name);
      }
    }
    if (activeServerName.isEmpty) {
      for (final g in groups) {
        final now = g.realNow;
        if (now.isNotEmpty && now != 'DIRECT' && now != 'REJECT') {
          activeServerName = groups.resolveToDisplayName(g.name);
          break;
        }
      }
    }
    final activeCountryCode = _flagToCountryCode(activeServerName);

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SingleChildScrollView(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: RouteXMotion.curve,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - value)),
                child: child,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RouteXGlassSurface(
                expand: false,
                radius: 32,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 520 ? 22 : 32,
                    20,
                    constraints.maxWidth < 520 ? 22 : 32,
                    28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroUtilityRow(
                        brandName: brandName,
                        isUpdating: profile?.isUpdating ?? false,
                        onUpdate: profile == null
                            ? null
                            : () => globalState.appController
                                .updateProfile(profile),
                        onImport: () => _openImportSheet(context),
                        supportUrl: supportUrl,
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: _WorldMapBackdrop(
                            activeCode: activeCountryCode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ConnectCircle(
                        isReady: state.isInit,
                        isRunning: isRunning,
                      ),
                      if (subscription != null) ...[
                        const SizedBox(height: 22),
                        _RouteXSubscriptionSummary(
                          subscription: subscription,
                          isRussian: isRussian,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openImportSheet(BuildContext context) {
    unawaited(
      showExtend(
        globalState.navigatorKey.currentState!.context,
        builder: (_, type) => AdaptiveSheetScaffold(
          type: type,
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: "${appLocalizations.addProfile}",
        ),
      ),
    );
  }
}

/// Replaces the old logo + name header. A brand name from the provider (when
/// there is one) sits on the left; the rest of the row is small icon
/// utilities — refresh this subscription, import another, reach support —
/// instead of a second restatement of the app's own name.
class _HeroUtilityRow extends StatelessWidget {
  const _HeroUtilityRow({
    required this.brandName,
    required this.isUpdating,
    required this.onUpdate,
    required this.onImport,
    this.supportUrl,
  });

  final String? brandName;
  final bool isUpdating;
  final VoidCallback? onUpdate;
  final VoidCallback onImport;
  final String? supportUrl;

  @override
  Widget build(BuildContext context) {
    final hasSupport = supportUrl != null && supportUrl!.isNotEmpty;
    return Row(
      children: [
        Expanded(child: _ProfileSwitcher(brandName: brandName)),
        _HeroIconAction(
          icon: Icons.refresh_rounded,
          tooltip: appLocalizations.update,
          busy: isUpdating,
          onTap: onUpdate,
        ),
        const SizedBox(width: 6),
        _HeroIconAction(
          icon: Icons.add_rounded,
          tooltip: '${appLocalizations.addProfile}',
          onTap: onImport,
        ),
        if (hasSupport) ...[
          const SizedBox(width: 6),
          _HeroIconAction(
            icon: Icons.support_agent_rounded,
            tooltip: appLocalizations.support,
            onTap: () => globalState.openUrl(supportUrl!),
          ),
        ],
      ],
    );
  }
}

/// The provider brand name (when there is one) with a chevron, tapping into
/// a dropdown listing every saved profile — the same switch the Profiles
/// page does via [currentProfileIdProvider], just reachable without leaving
/// the dashboard. With a single profile there's nothing to switch to, so it
/// falls back to plain, non-interactive text exactly like before.
///
/// Deliberately not [CommonPopupBox]: that positions relative to the
/// screen's top-right corner (tuned for an icon sitting near it, like the
/// mode chip elsewhere in this file), so anchored to a left-aligned text
/// trigger it opened well off to the side instead of under it. This centers
/// directly below the trigger via [CompositedTransformFollower] and only
/// ever fades/scales in place from there — nothing jumps.
class _ProfileSwitcher extends ConsumerStatefulWidget {
  const _ProfileSwitcher({required this.brandName});

  final String? brandName;

  @override
  ConsumerState<_ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends ConsumerState<_ProfileSwitcher> {
  final _layerLink = LayerLink();
  final _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _open(List<Profile> profiles, String? currentId) {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerWidth = box?.size.width ?? 160;
    final duration = RouteXMotion.resolve(context, RouteXMotion.fast);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(_close),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: triggerWidth),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: duration,
                  curve: RouteXMotion.curve,
                  builder: (_, value, child) => Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * value,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                  child: CommonPopupMenu(
                    minWidth: triggerWidth,
                    items: [
                      for (final profile in profiles)
                        PopupMenuItemData(
                          icon: profile.id == currentId
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          label: profile.label ?? profile.id,
                          onPressed: profile.id == currentId
                              ? null
                              : () {
                                  setState(_close);
                                  ref
                                      .read(currentProfileIdProvider.notifier)
                                      .value = profile.id;
                                },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final selectorState = ref.watch(profilesSelectorStateProvider);
    final profiles = selectorState.profiles;
    final current = profiles
        .where((p) => p.id == selectorState.currentProfileId)
        .firstOrNull;
    final title = (widget.brandName != null && widget.brandName!.isNotEmpty)
        ? widget.brandName!
        : current?.label ?? current?.id ?? '';
    final textStyle = context.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    if (profiles.length <= 1) {
      return title.isEmpty
          ? const SizedBox.shrink()
          : Text(title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle);
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: _FocusableTap(
        key: _triggerKey,
        borderRadius: 12,
        onTap: () => setState(
          () => _overlayEntry == null
              ? _open(profiles, selectorState.currentProfileId)
              : _close(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconAction extends StatelessWidget {
  const _HeroIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: _FocusableTap(
          borderRadius: 18,
          onTap: busy ? null : onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: busy
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    icon,
                    size: 17,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      );
}

/// The actual connect control: one big circle that both shows the state and
/// is the tap target for it, replacing the old pair of a decorative status
/// badge plus a separate pill button below it — two elements for what is
/// one fact, and neither of them the clear "press this" the page needs.
///
/// Stopped-but-ready: a mint ring around a dark disc — an invitation, not
/// yet committed. Running: the disc fills solid mint with a soft glow, the
/// glyph switches to stop, and the live uptime/traffic sit under it. Not
/// ready (no active proxy group yet): flat and muted, no ring, disabled.
class _ConnectCircle extends ConsumerStatefulWidget {
  const _ConnectCircle({required this.isReady, required this.isRunning});

  final bool isReady;
  final bool isRunning;

  @override
  ConsumerState<_ConnectCircle> createState() => _ConnectCircleState();
}

class _ConnectCircleState extends ConsumerState<_ConnectCircle>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  // Fires once — a ring that expands out from the disc and fades — the
  // instant the connection actually toggles. Confirmation feedback for a
  // real state change, not an idle loop: it only ever plays on a genuine
  // on/off transition, never while just sitting there.
  late final AnimationController _burstController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void didUpdateWidget(covariant _ConnectCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRunning != widget.isRunning) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!reduceMotion) {
        unawaited(_burstController.forward(from: 0));
      }
    }
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (value != _hovered) setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (value != _pressed) setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (value != _focused) setState(() => _focused = value);
  }

  void _toggle() {
    if (Platform.isAndroid) {
      unawaited(HapticFeedback.mediumImpact());
    }
    unawaited(globalState.appController.updateStatus(!widget.isRunning));
  }

  @override
  Widget build(BuildContext context) {
    final runTime = ref.watch(runTimeProvider);
    final duration = RouteXMotion.resolve(context, RouteXMotion.base);
    final hoverDuration = RouteXMotion.resolve(context, RouteXMotion.fast);
    final colorScheme = context.colorScheme;
    final isReady = widget.isReady;
    final isRunning = widget.isRunning;

    final Color ring;
    final Color fill;
    final Color glyph;
    if (!isReady) {
      ring = Colors.transparent;
      fill = colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
      glyph = colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isRunning) {
      ring = Colors.transparent;
      fill = premiumMint;
      glyph = const Color(0xFF07110E);
    } else {
      ring = premiumMint.withValues(alpha: 0.55);
      fill = premiumMint.withValues(alpha: 0.08);
      glyph = premiumMint;
    }
    final borderColor = _focused ? colorScheme.primary : ring;

    // Hover lifts the disc and brightens its glow; a press eases it back
    // down slightly — the button reacts to the pointer instead of just
    // sitting there animating on its own. A single FocusableActionDetector
    // owns hover/focus/activation — no nested hover trackers fighting each
    // other (that was the flicker: two independent hover states each
    // driving their own scale on the same element).
    final hoverActive = isReady && _hovered;
    final scale = !isReady
        ? 1.0
        : _pressed
            ? 0.97
            : _hovered
                ? 1.07
                : 1.0;
    final glowAlpha = isRunning
        ? (hoverActive ? 0.48 : 0.32)
        : (hoverActive ? 0.22 : 0.0);
    final glowBlur = isRunning ? (hoverActive ? 44.0 : 36.0) : 28.0;

    return Column(
      children: [
        Focus(
          autofocus: isReady,
          onFocusChange: _setFocused,
          onKeyEvent: isReady
              ? (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.space)) {
                    _toggle();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              : null,
          // Plain MouseRegion, not FocusableActionDetector's hover
          // highlight — that one goes through Flutter's global
          // touch/mouse "highlight mode" tracking and could lag several
          // seconds behind the real cursor on exit. This reacts the
          // instant the pointer actually leaves.
          child: MouseRegion(
            onEnter: isReady ? (_) => _setHovered(true) : null,
            onExit: (_) => _setHovered(false),
            cursor:
                isReady ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: Listener(
              onPointerDown: isReady ? (_) => _setPressed(true) : null,
              onPointerUp: isReady ? (_) => _setPressed(false) : null,
              onPointerCancel: isReady ? (_) => _setPressed(false) : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isReady ? _toggle : null,
                child: AnimatedScale(
                  scale: scale,
                  duration: hoverDuration,
                  curve: RouteXMotion.curve,
                  child: SizedBox(
                    width: 124,
                    height: 124,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedBuilder(
                          animation: _burstController,
                          builder: (context, _) {
                            final t = _burstController.value;
                            if (t <= 0 || t >= 1) {
                              return const SizedBox.shrink();
                            }
                            return IgnorePointer(
                              child: Opacity(
                                opacity: (1 - t) * 0.5,
                                child: Transform.scale(
                                  scale: 1.0 + t * 0.5,
                                  child: Container(
                                    width: 124,
                                    height: 124,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: premiumMint,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        AnimatedContainer(
                          duration: duration,
                          curve: RouteXMotion.curve,
                          width: 124,
                          height: 124,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fill,
                            border:
                                Border.all(color: borderColor, width: 2.5),
                            boxShadow: glowAlpha <= 0
                                ? null
                                : [
                                    BoxShadow(
                                      color: premiumMint
                                          .withValues(alpha: glowAlpha),
                                      blurRadius: glowBlur,
                                      spreadRadius: 2,
                                    ),
                                  ],
                          ),
                          child: AnimatedSwitcher(
                            duration: duration,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                            child: Icon(
                              isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(isRunning),
                              size: 44,
                              color: glyph,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedDefaultTextStyle(
          duration: duration,
          style: context.textTheme.titleMedium!.copyWith(
            color: isRunning ? premiumMint : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          child: Text(
            isRunning ? appLocalizations.running : appLocalizations.stopped,
          ),
        ),
        // The uptime/traffic block used to just appear/disappear as the
        // Column's children changed — an instant pop, not a transition.
        // AnimatedSize eases the height change; AnimatedOpacity crossfades
        // the content inside it, so connecting/disconnecting reads as one
        // continuous motion instead of a layout jump.
        AnimatedSize(
          duration: duration,
          curve: RouteXMotion.curve,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: duration,
            curve: RouteXMotion.curve,
            opacity: (isRunning && runTime != null) ? 1 : 0,
            child: (isRunning && runTime != null)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        utils.getTimeText(runTime),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: FontFamily.jetBrainsMono.value,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const _LiveTrafficRow(),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _LiveTrafficRow extends ConsumerWidget {
  const _LiveTrafficRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffic = ref.watch(totalTrafficProvider);
    final style = context.textTheme.labelMedium?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      fontFamily: FontFamily.jetBrainsMono.value,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.arrow_upward_rounded,
          size: 13,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(traffic.up.show, style: style),
        const SizedBox(width: 12),
        Icon(
          Icons.arrow_downward_rounded,
          size: 13,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(traffic.down.show, style: style),
      ],
    );
  }
}

class _RouteXSubscriptionSummary extends StatelessWidget {
  const _RouteXSubscriptionSummary({
    required this.subscription,
    required this.isRussian,
  });

  final SubscriptionInfo subscription;
  final bool isRussian;

  @override
  Widget build(BuildContext context) {
    final used = subscription.upload + subscription.download;
    final remaining =
        subscription.total > 0 ? math.max(0, subscription.total - used) : 0;
    final progress = subscription.total > 0
        ? (used / subscription.total).clamp(0.0, 1.0)
        : 0.0;
    final days = subscription.expire > 0
        ? math.max(
            0,
            DateTime.fromMillisecondsSinceEpoch(subscription.expire * 1000)
                .difference(DateTime.now())
                .inDays,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.075),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _RouteXMetric(
                  label: isRussian ? 'Осталось трафика' : 'Traffic left',
                  value: subscription.total > 0
                      ? _formatBytes(remaining)
                      : (isRussian ? 'Безлимит' : 'Unlimited'),
                ),
              ),
              if (days != null) ...[
                Container(
                  width: 1,
                  height: 38,
                  color: Colors.white.withValues(alpha: 0.075),
                ),
                Expanded(
                  child: _RouteXMetric(
                    label: isRussian ? 'Осталось дней' : 'Days left',
                    value: '$days',
                  ),
                ),
              ],
            ],
          ),
          if (subscription.total > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 5,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: RouteXMotion.resolve(
                    context,
                    const Duration(milliseconds: 900),
                  ),
                  curve: RouteXMotion.curve,
                  builder: (context, value, _) => LinearProgressIndicator(
                    minHeight: 5,
                    value: value,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: const AlwaysStoppedAnimation(premiumMint),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// World map backdrop — a graticule, every location this app is known to
// reach as a faint dot, and one bright pulse arcing out to whichever one is
// currently active. Deliberately not real coastlines: a geographically
// accurate world map is a large, license-sensitive asset this app doesn't
// have, and a wrong-looking one would read far worse than an abstract one.
// A dotted graticule + node graph is its own honest visual language (the
// one most "global network" dashboards actually use) rather than a fake
// looking landmass.
// ----------------------------------------------------------------------------
class _WorldMapBackdrop extends StatefulWidget {
  const _WorldMapBackdrop({this.activeCode});

  final String? activeCode;

  @override
  State<_WorldMapBackdrop> createState() => _WorldMapBackdropState();
}

class _WorldMapBackdropState extends State<_WorldMapBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final activeLatLon = widget.activeCode == null
        ? null
        : countryCentroids[widget.activeCode!.toUpperCase()];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WorldMapPainter(
            t: reduceMotion ? 0 : _controller.value,
            activeLatLon: activeLatLon,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WorldMapPainter extends CustomPainter {
  _WorldMapPainter({required this.t, required this.activeLatLon});

  final double t;
  final Offset? activeLatLon;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var lat = -60; lat <= 60; lat += 30) {
      final y = projectLatLon(Offset(lat.toDouble(), 0), size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var lon = -150; lon <= 150; lon += 30) {
      final x = projectLatLon(Offset(0, lon.toDouble()), size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (final latLon in countryCentroids.values) {
      canvas.drawCircle(projectLatLon(latLon, size), 1.6, dotPaint);
    }

    if (activeLatLon == null) return;
    final target = projectLatLon(activeLatLon!, size);
    // The pulse departs from the bottom-centre of the panel — an abstract
    // "you", not a guess at the user's real location — and arcs up to the
    // active server. A quadratic control point above the midpoint gives the
    // arc a lift instead of a flat, mechanical straight line.
    final origin = Offset(size.width / 2, size.height + 20);
    final control = Offset(
      (origin.dx + target.dx) / 2,
      math.min(origin.dy, target.dy) - size.height * 0.35,
    );
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = premiumMint.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final metric = path.computeMetrics().first;
    final pulseT = (t * 3) % 1;
    final pulsePos = metric.getTangentForOffset(metric.length * pulseT);
    if (pulsePos != null) {
      canvas.drawCircle(
        pulsePos.position,
        2.6,
        Paint()..color = premiumMint.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        pulsePos.position,
        7,
        Paint()
          ..color = premiumMint.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawCircle(target, 4, Paint()..color = premiumMint);
    canvas.drawCircle(
      target,
      9,
      Paint()
        ..color = premiumMint.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.activeLatLon != activeLatLon;
}

class _RouteXMetric extends StatelessWidget {
  const _RouteXMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: FontFamily.jetBrainsMono.value,
            ),
          ),
        ],
      );
}

class _RouteXQuickAction extends StatelessWidget {
  const _RouteXQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _FocusableTap(
        borderRadius: 16,
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.075),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LegacyHeroConnect extends ConsumerWidget {
  const _LegacyHeroConnect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.hasProfile) return const _EmptyHero();

    final isReady = state.isInit;
    final profile = ref.watch(currentProfileProvider);
    final headers = profile?.providerHeaders ?? {};
    final serviceName =
        _decodeBase64(headers['flclashx-servicename']) ?? 'ROUTE//X';
    final logoUrl = _decodeBase64(headers['flclashx-servicelogo']);
    final announce = _decodeAnnounce(headers['announce']);
    final sub = profile?.subscriptionInfo;
    // Only show the traffic card when there's something to show — a data limit or an
    // expiry. Unlimited + no expiry => hide it entirely.
    final hasSub = sub != null && (sub.total > 0 || sub.expire > 0);

    // Buy/renew links carried by the profile. The buttons (under the traffic
    // card) only appear when the matching condition is met:
    //   buyplan    -> less than 3 days left (expired included), time-limited plans
    //   buytraffic -> less than 10% of the limit remaining, capped plans
    final buyPlanUrl = headers['flclashx-buyplan'];
    final buyTrafficUrl = headers['flclashx-buytraffic'];
    var showBuyPlan = false;
    var showBuyTraffic = false;
    if (sub != null) {
      if (buyPlanUrl != null && buyPlanUrl.isNotEmpty && sub.expire > 0) {
        showBuyPlan = DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000)
                .difference(DateTime.now()) <
            const Duration(days: 3);
      }
      if (buyTrafficUrl != null && buyTrafficUrl.isNotEmpty && sub.total > 0) {
        final used = sub.upload + sub.download;
        showBuyTraffic = (sub.total - used) < sub.total * 0.1;
      }
    }
    final showBuy = showBuyPlan || showBuyTraffic;

    final groups = ref.watch(currentGroupsStateProvider).value;
    var serverName = '';
    String? testUrl;
    Group? activeGroup;
    // Server label = the current pick of the proxy group named in the
    // `flclashx-serverinfo` header: its selected leaf host (the real location),
    // or the sub-group's own name when the pick is itself a group (see
    // resolveToDisplayName). Fall back to the first group with a live selection.
    final serverInfoHeader = headers['flclashx-serverinfo'];
    if (serverInfoHeader != null && serverInfoHeader.isNotEmpty) {
      final groupName =
          _decodeBase64(serverInfoHeader) ?? serverInfoHeader.trim();
      final group = groups.getGroup(groupName);
      if (group != null) {
        activeGroup = group;
        serverName = groups.resolveToDisplayName(group.name);
        testUrl = group.testUrl;
      }
    }
    if (serverName.isEmpty) {
      for (final g in groups) {
        final now = g.realNow;
        if (now.isNotEmpty && now != 'DIRECT' && now != 'REJECT') {
          activeGroup = g;
          serverName = groups.resolveToDisplayName(g.name);
          testUrl = g.testUrl;
          break;
        }
      }
    }
    final displayName = _stripLeadingEmoji(serverName);
    final nameCountryCode = _flagToCountryCode(serverName);
    final groupFlagCodes = activeGroup != null
        ? _collectGroupFlags(groups, activeGroup)
        : const <String>[];
    // Other locations in the group: their distinct flag countries (shown as stacked
    // flags behind the active one) plus a total count (the badge). Falls back to the
    // sibling-proxy count when node names carry no flag emoji.
    final activeUpper = nameCountryCode?.toUpperCase();
    final otherCodes =
        groupFlagCodes.where((c) => c.toUpperCase() != activeUpper).toList();
    final rawOther = otherCodes.isNotEmpty
        ? otherCodes.length
        : (activeGroup != null ? activeGroup.all.length - 1 : 0);
    final otherLocations = rawOther < 0 ? 0 : rawOther;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _Logo(logoUrl: logoUrl),
                const SizedBox(height: 16),
                Text(
                  serviceName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (announce != null && announce.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AnnounceBanner(text: announce),
                ],
                const SizedBox(height: 18),
                _HeroActionRow(
                  isUpdating: profile?.isUpdating ?? false,
                  onUpdate: profile == null
                      ? null
                      : () => globalState.appController.updateProfile(profile),
                  supportUrl: headers['support-url'],
                ),
                const SizedBox(height: 18),
                if (hasSub) ...[
                  _TrafficCard(sub: sub),
                  const SizedBox(height: 12),
                ],
                if (showBuy) ...[
                  _BuyButtons(
                    showBuyPlan: showBuyPlan,
                    showBuyTraffic: showBuyTraffic,
                    buyPlanUrl: buyPlanUrl,
                    buyTrafficUrl: buyTrafficUrl,
                  ),
                  const SizedBox(height: 12),
                ],
                _ServerPanel(
                  serverName: serverName,
                  displayName: displayName,
                  nameCountryCode: nameCountryCode,
                  testUrl: testUrl,
                  otherCodes: otherCodes,
                  otherLocations: otherLocations,
                ),
              ],
            ),
          ),
        ),
        // Pinned to the bottom of the hero, just above the nav bar.
        const SizedBox(height: 14),
        _ConnectButton(isReady: isReady),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Logo
// ----------------------------------------------------------------------------
class _Logo extends StatelessWidget {
  const _Logo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [premiumMint, premiumBlue],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: premiumMint.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.route_rounded,
        color: Color(0xFF07110E),
        size: 52,
      ),
    );
    if (logoUrl == null || logoUrl!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: logoUrl!.toLowerCase().endsWith('.svg')
          ? SvgPicture.network(logoUrl!,
              width: size, height: size, placeholderBuilder: (_) => fallback)
          : CachedNetworkImage(
              imageUrl: logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

// ----------------------------------------------------------------------------
// Traffic card (usage bar + amount + days left)
// ----------------------------------------------------------------------------
class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.sub});

  final SubscriptionInfo sub;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final used = (sub.upload + sub.download).toInt();
    final total = sub.total;
    final unlimited = total <= 0;
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final barColor = progress > 0.9
        ? Colors.red.shade400
        : progress > 0.7
            ? Colors.orange.shade400
            : colorScheme.primary;

    int? daysLeft;
    if (sub.expire > 0) {
      daysLeft = DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000)
          .difference(DateTime.now())
          .inDays;
      if (daysLeft < 0) daysLeft = 0;
    }

    final daysUrgent = daysLeft != null && daysLeft <= 3;
    final daysColor = daysUrgent ? Colors.red.shade400 : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unlimited
                      ? _formatBytes(used)
                      : '${_formatBytes(used)} / ${_formatBytes(total)}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: FontFamily.jetBrainsMono.value,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (daysLeft != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: daysColor.withValues(alpha: 0.14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_rounded, size: 14, color: daysColor),
                      const SizedBox(width: 5),
                      Text(
                        '${appLocalizations.remaining} $daysLeft ${_daysWord(daysLeft)}',
                        style: context.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: daysColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!unlimited) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                      height: 9, color: colorScheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: progress <= 0 ? 0.0 : progress,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [barColor.withValues(alpha: 0.7), barColor],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Buy / renew buttons (shown under the traffic card)
// ----------------------------------------------------------------------------
class _BuyButtons extends StatelessWidget {
  const _BuyButtons({
    required this.showBuyPlan,
    required this.showBuyTraffic,
    required this.buyPlanUrl,
    required this.buyTrafficUrl,
  });

  final bool showBuyPlan;
  final bool showBuyTraffic;
  final String? buyPlanUrl;
  final String? buyTrafficUrl;

  @override
  Widget build(BuildContext context) {
    final plan = _HeroBuyButton(
      icon: Icons.autorenew_rounded,
      label: 'Продлить подписку',
      filled: true,
      onTap: () => globalState.openUrl(buyPlanUrl!),
    );
    final traffic = _HeroBuyButton(
      icon: Icons.add_rounded,
      label: 'Докупить трафик',
      filled: false,
      onTap: () => globalState.openUrl(buyTrafficUrl!),
    );

    // Both triggers -> side by side, one each; a single trigger -> full width.
    if (showBuyPlan && showBuyTraffic) {
      return Row(
        children: [
          Expanded(child: plan),
          const SizedBox(width: 10),
          Expanded(child: traffic),
        ],
      );
    }
    if (showBuyPlan) return plan;
    if (showBuyTraffic) return traffic;
    return const SizedBox.shrink();
  }
}

class _HeroBuyButton extends StatelessWidget {
  const _HeroBuyButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bg = filled
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh.withValues(alpha: 0.6);
    final fg = filled ? colorScheme.onPrimary : colorScheme.primary;
    return _FocusableTap(
      borderRadius: 16,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: bg,
          border: filled
              ? null
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Server panel (flag / host / ip / ping) — tap to change server
// ----------------------------------------------------------------------------
class _ServerPanel extends ConsumerWidget {
  const _ServerPanel({
    required this.serverName,
    required this.displayName,
    required this.nameCountryCode,
    required this.testUrl,
    this.otherCodes = const [],
    this.otherLocations = 0,
  });

  final String serverName;
  final String displayName;
  final String? nameCountryCode;
  final String? testUrl;
  final List<String> otherCodes;
  final int otherLocations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    // select(!=null): the hero card only needs the connected/disconnected boolean,
    // so watching the raw runTime rebuilt the entire card (flags, traffic, server
    // panel, buy buttons, announce) every second. The elapsed-time text lives in
    // _ConnectButton, which intentionally keeps watching the value.
    final isConnected =
        ref.watch(runTimeProvider.select((value) => value != null));
    final delay = serverName.isNotEmpty
        ? ref.watch(getDelayProvider(proxyName: serverName, testUrl: testUrl))
        : null;

    return ValueListenableBuilder(
      valueListenable: detectionState.state,
      builder: (_, networkState, __) {
        final ipInfo = networkState.ipInfo;
        // Prefer the flag carried in the server name; fall back to the detected
        // exit-IP country, then a globe.
        final code = nameCountryCode ?? ipInfo?.countryCode ?? '';
        final flag = _countryCodeToEmoji(code);
        final title = displayName.isNotEmpty ? displayName : '—';

        return _FocusableTap(
          borderRadius: 18,
          onTap: () => globalState.appController.toPage(PageLabel.proxies),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                _FlagCircle(
                  countryCode: code,
                  fallbackEmoji: flag,
                  otherCodes: otherCodes,
                  stackCount: otherLocations,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // IP line: hidden while the tunnel is off. Once connected:
                      // the real IP when known; a spinner + "determining IP" while
                      // actively resolving; a muted dash if resolution finished
                      // without an IP (failed / timed out).
                      if (isConnected) ...[
                        const SizedBox(height: 3),
                        if (ipInfo != null)
                          Text(
                            ipInfo.ip,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: FontFamily.jetBrainsMono.value,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (networkState.isTesting ||
                            networkState.isLoading)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                appLocalizations.determiningIp,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            '—',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: FontFamily.jetBrainsMono.value,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Fixed width so the bars + ms text stay horizontally centred and
                // don't drift as the delay text width changes.
                SizedBox(
                  width: 46,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SignalBars(delay: delay),
                      if (delay != null && delay > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          '$delay ms',
                          textAlign: TextAlign.center,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: utils.getDelayColor(delay) ??
                                colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontFamily: FontFamily.jetBrainsMono.value,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Chevron: signals the panel is tappable (drill into the server list).
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Large circle filled with the country flag (cropped to a circle; falls back to the
// flag emoji / globe). When the group has other locations, a couple of neutral
// theme-coloured discs peek out from behind it as a tidy "stack" affordance.
class _FlagCircle extends StatelessWidget {
  const _FlagCircle({
    required this.countryCode,
    required this.fallbackEmoji,
    this.otherCodes = const [],
    this.stackCount = 0,
  });

  final String countryCode;
  final String fallbackEmoji;
  final List<String> otherCodes;
  final int stackCount;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final colorScheme = context.colorScheme;
    final cc = countryCode.trim().toLowerCase();

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHighest,
          ),
          alignment: Alignment.center,
          child: EmojiText(fallbackEmoji,
              style: const TextStyle(fontSize: size * 0.5)),
        );

    final active = cc.length != 2
        ? fallback()
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: 'https://flagcdn.com/w160/$cc.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: size,
                height: size,
                color: colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, __, ___) => fallback(),
            ),
          );

    // Up to two of the group's other-location flags peek straight up from behind the
    // active one — smaller, ringed in the surface colour, and progressively darkened
    // the further back they sit, so they read as a centred stack receding into depth.
    final backs = otherCodes.take(2).toList();
    Widget backFlag(int i, String code) {
      final s = size * (1 - 0.14 * i);
      return Transform.translate(
        offset: Offset(0, -10.0 * i),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surface, width: 1.5),
          ),
          child: ClipOval(
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://flagcdn.com/w80/${code.toLowerCase()}.png',
                  width: s,
                  height: s,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => SizedBox(width: s, height: s),
                  errorWidget: (_, __, ___) => Container(
                    width: s,
                    height: s,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                ),
                // Depth scrim: deeper cards are darker.
                Positioned.fill(
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.15 * i)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final badge = stackCount <= 0
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: colorScheme.primary,
              border: Border.all(color: colorScheme.surface, width: 1.5),
            ),
            child: Text(
              '+$stackCount',
              style: context.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontFamily: FontFamily.jetBrainsMono.value,
              ),
            ),
          );

    // The active flag with its peeking back-flags and corner badge, as one 52px unit.
    final unit = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (var i = backs.length; i >= 1; i--) backFlag(i, backs[i - 1]),
        active,
        if (badge != null) Positioned(right: -3, bottom: -3, child: badge),
      ],
    );

    // Reserve headroom matching how far the deepest back-flag sticks up (plus a little
    // for the badge), so the *whole* construction — not just the active flag — is
    // vertically centred in the row.
    final topPeek = backs.isEmpty
        ? 0.0
        : (10.0 * backs.length +
                size * (1 - 0.14 * backs.length) / 2 -
                size / 2 +
                2)
            .clamp(0.0, 40.0)
            .toDouble();
    final bottomPeek = badge != null ? 7.0 : 0.0;

    if (topPeek == 0 && bottomPeek == 0) {
      return SizedBox(width: size, height: size, child: unit);
    }
    return SizedBox(
      width: size,
      height: size + topPeek + bottomPeek,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              top: topPeek, left: 0, width: size, height: size, child: unit),
        ],
      ),
    );
  }
}

// Mobile-network-style signal bars representing ping quality.
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.delay});

  final int? delay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final dim = colorScheme.onSurfaceVariant.withValues(alpha: 0.25);

    final int level;
    final Color color;
    if (delay == null || delay == 0) {
      level = 0;
      color = dim;
    } else if (delay! < 0) {
      level = 0;
      color = Colors.red.shade400;
    } else {
      color = utils.getDelayColor(delay) ?? Colors.green;
      level = delay! < 150
          ? 4
          : delay! < 300
              ? 3
              : delay! < 600
                  ? 2
                  : 1;
    }

    const heights = [9.0, 13.0, 17.0, 21.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
          4,
          (i) => Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                child: Container(
                  width: 4,
                  height: heights[i],
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < level ? color : dim,
                  ),
                ),
              )),
    );
  }
}

// ----------------------------------------------------------------------------
// Connect button — shows the time counter while connected
// ----------------------------------------------------------------------------
class _ConnectButton extends ConsumerWidget {
  const _ConnectButton({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final runTime = ref.watch(runTimeProvider);
    final isStart = runTime != null;

    final Color bg;
    final Color fg;
    if (!isReady) {
      bg = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      fg = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (isStart) {
      bg = colorScheme.surfaceContainerHigh.withValues(alpha: 0.8);
      fg = colorScheme.primary;
    } else {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
    }

    const height = 56.0;
    final duration = RouteXMotion.resolve(context, RouteXMotion.base);

    return _FocusableTap(
      autofocus: true,
      borderRadius: height / 2,
      onTap: isReady
          ? () {
              if (Platform.isAndroid) {
                HapticFeedback.mediumImpact();
              }
              globalState.appController.updateStatus(!isStart);
            }
          : null,
      child: AnimatedContainer(
        duration: duration,
        curve: RouteXMotion.curve,
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: bg,
          border: isStart
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.4))
              : null,
        ),
        // The state change is the moment the product is about, so it gets
        // a real transition: the two states cross-fade and slide rather
        // than swapping a glyph.
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: RouteXMotion.curve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.28),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(isStart),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isStart ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: fg,
              ),
              const SizedBox(width: 10),
              Text(
                isStart ? appLocalizations.stop : appLocalizations.start,
                style: context.textTheme.titleSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (isStart) ...[
                const SizedBox(width: 12),
                Text(
                  utils.getTimeText(runTime),
                  style: context.textTheme.labelLarge?.copyWith(
                    color: fg.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    fontFamily: FontFamily.jetBrainsMono.value,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Empty state (no profile)
// ----------------------------------------------------------------------------
class _EmptyHero extends ConsumerWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Future<void> addProfile() async {
      final url = await globalState.showCommonDialog<String>(
        child: const URLFormDialog(),
      );
      if (url != null) {
        await globalState.appController.addProfileFormURL(url);
      }
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
        curve: RouteXMotion.curve,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: RouteXGlassSurface(
            expand: false,
            radius: 32,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(42, 38, 42, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: premiumMint.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: premiumMint.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: premiumMint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${appName.toUpperCase()}  ·  SMART ROUTING',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: premiumMint,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isRussian
                        ? 'Маршрутизация без YAML'
                        : 'Routing without YAML',
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRussian
                        ? 'Добавьте профиль — приложения, подключения и правила появятся здесь автоматически.'
                        : 'Add a profile and your applications, connections, and routes will appear here automatically.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _EmptyFeature(
                        icon: Icons.grid_view_rounded,
                        label: isRussian ? 'Все приложения' : 'All apps',
                      ),
                      _EmptyFeature(
                        icon: Icons.touch_app_outlined,
                        label: isRussian
                            ? 'Маршрут в один клик'
                            : 'One-click route',
                      ),
                      _EmptyFeature(
                        icon: Icons.code_off_rounded,
                        label: isRussian ? 'Никакого YAML' : 'No YAML',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _FocusableTap(
                    autofocus: true,
                    borderRadius: 18,
                    onTap: addProfile,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: premiumMint.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: premiumMint,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            appLocalizations.addProfile,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: premiumMint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeature extends StatelessWidget {
  const _EmptyFeature({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.075),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _AnnounceBanner extends StatelessWidget {
  const _AnnounceBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.secondaryContainer,
      ),
      // EmojiText (not Text): renders flag/emoji runs with the Twemoji font so
      // they show up — plain Text drops country flags entirely on Windows.
      child: EmojiText(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          height: 1.4,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Hero actions: refresh / support chips
// ----------------------------------------------------------------------------
class _HeroActionRow extends ConsumerWidget {
  const _HeroActionRow({
    required this.isUpdating,
    required this.onUpdate,
    this.supportUrl,
  });

  final bool isUpdating;
  final VoidCallback? onUpdate;
  final String? supportUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSupport = supportUrl != null && supportUrl!.isNotEmpty;
    final globalModeEnabled = ref.watch(globalModeEnabledProvider);
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.refresh_rounded,
            label: appLocalizations.update,
            busy: isUpdating,
            onTap: onUpdate,
          ),
        ),
        if (hasSupport) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _ActionChip(
              icon: Icons.support_agent_rounded,
              label: appLocalizations.support,
              onTap: () => globalState.openUrl(supportUrl!),
            ),
          ),
        ],
        if (globalModeEnabled) ...[
          const SizedBox(width: 10),
          const _ModeChip(),
        ],
      ],
    );
  }
}

// Outbound-mode chip (rule/global) — icon-only square in the action-chip visual
// language, pinned after the Support chip. The current mode is conveyed by the
// icon itself; tapping opens the same mode popup as on the proxies page. Only
// rendered when the global-mode setting is on (gated by the caller).
class _ModeChip extends ConsumerWidget {
  const _ModeChip();

  IconData _modeIcon(Mode mode) => switch (mode) {
        Mode.rule => Icons.rule,
        Mode.global => Icons.public,
        Mode.direct => Icons.flash_on,
      };

  String _modeLabel(Mode mode) => switch (mode) {
        Mode.rule => appLocalizations.rule,
        Mode.global => appLocalizations.global,
        Mode.direct => appLocalizations.direct,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    return CommonPopupBox(
      targetBuilder: (open) => Tooltip(
        message: _modeLabel(mode),
        child: _FocusableTap(
          borderRadius: 22,
          onTap: () => open(offset: const Offset(0, 20)),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Icon(_modeIcon(mode), size: 18, color: colorScheme.primary),
          ),
        ),
      ),
      popup: CommonPopupMenu(
        items: [
          for (final item in Mode.values.where((m) => m != Mode.direct))
            PopupMenuItemData(
              icon: _modeIcon(item),
              label: _modeLabel(item),
              onPressed: () {
                globalState.appController.changeMode(item);
              },
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return _FocusableTap(
      borderRadius: 22,
      onTap: busy ? null : onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: busy
                  ? CircularProgressIndicator(
                      strokeWidth: 2, color: colorScheme.primary)
                  : Icon(icon, size: 18, color: colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: context.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
