import 'package:cached_network_image/cached_network_image.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/widgets/flag.dart';
import 'package:flclashx/widgets/icon.dart';
import 'package:flclashx/widgets/popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Windows' Segoe UI Emoji renders regional-indicator flag emoji as bare
/// two-letter text instead of a flag glyph, so a raw "🇨🇭 Switzerland" proxy
/// name shows as "CH Switzerland" in the system font — this strips the
/// leading flag/emoji so labels read as plain text instead.
String stripLocationFlagPrefix(String text) {
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
  while (start < runes.length &&
      (isEmojiRune(runes[start]) || isSpace(runes[start]))) {
    start++;
  }
  return String.fromCharCodes(runes.sublist(start))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// A "Proxy" / "Direct" segmented switch, shared by every visual routing
/// surface (per-app routing on the Applications page, per-site routing on
/// the Sites page): tapping the already-selected Proxy slot a second time
/// opens [LocationPickerPanel] instead of re-selecting it, so no extra
/// control needs to be squeezed into an already tight 44px bar.
class ProxyRouteControl extends StatelessWidget {
  const ProxyRouteControl({
    super.key,
    this.width = 300,
    required this.route,
    required this.routeTarget,
    required this.onChanged,
    required this.onPickLocation,
    this.defaultLabel = 'По умолчанию',
  });

  final ApplicationRoute route;
  final String? routeTarget;
  final ValueChanged<ApplicationRoute> onChanged;
  final ValueChanged<String> onPickLocation;
  final double width;
  final String defaultLabel;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLowest
              .withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CommonPopupBox(
                targetBuilder: (open) => Tooltip(
                  message: route != ApplicationRoute.direct
                      ? 'Нажмите ещё раз, чтобы выбрать локацию'
                      : '',
                  child: RouteOption(
                    label: routeTarget == null
                        ? 'Proxy'
                        : stripLocationFlagPrefix(routeTarget!),
                    selected: route != ApplicationRoute.direct,
                    color: premiumMint,
                    onPressed: () {
                      if (route != ApplicationRoute.direct) {
                        open(offset: const Offset(0, 8));
                      } else {
                        onChanged(ApplicationRoute.proxy);
                      }
                    },
                  ),
                ),
                popup: LocationPickerPanel(
                  currentTarget: routeTarget,
                  isDefault: route == ApplicationRoute.rule,
                  defaultLabel: defaultLabel,
                  onPicked: onPickLocation,
                  onClear: () => onChanged(ApplicationRoute.rule),
                ),
              ),
            ),
            Expanded(
              child: RouteOption(
                label: 'Direct',
                selected: route == ApplicationRoute.direct,
                color: premiumBlue,
                onPressed: () => onChanged(ApplicationRoute.direct),
              ),
            ),
          ],
        ),
      );
}

/// The location picker's popup body — opened from the Proxy slot of an
/// already-proxied entry. Two levels: each non-hidden proxy group the
/// active profile exposes as a header, and — because a Clash rule target
/// accepts a leaf server name exactly as well as a group name — every
/// member of that group listed underneath as its own selectable location.
/// A profile with one selector group and eight countries inside it shows
/// all eight, not just the one selector.
class LocationPickerPanel extends ConsumerWidget {
  const LocationPickerPanel({
    super.key,
    required this.currentTarget,
    required this.isDefault,
    required this.onPicked,
    required this.onClear,
    this.defaultLabel = 'По умолчанию',
  });

  final String? currentTarget;
  // True when there's currently no pinned location (plain "follow the
  // profile's rules" state) — highlights the default row instead.
  final bool isDefault;
  final ValueChanged<String> onPicked;
  final VoidCallback onClear;
  final String defaultLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref
        .watch(currentGroupsStateProvider)
        .value
        .where((group) => group.hidden != true)
        .toList(growable: false);

    void pick(String target) {
      Navigator.of(context).pop();
      onPicked(target);
    }

    void clear() {
      Navigator.of(context).pop();
      onClear();
    }

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
        child: RouteXGlassSurface(
          variant: RouteXGlassVariant.panel,
          radius: 16,
          expand: false,
          child: groups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Нет доступных локаций в этом профиле',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(6),
                  children: [
                    LocationOption(
                      label: defaultLabel,
                      subtitle: 'Следовать правилам профиля',
                      icon: '',
                      selected: isDefault,
                      onTap: clear,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(height: 1),
                    ),
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // The group itself, selectable as "let this group
                      // auto-pick" rather than pinning one member of it.
                      LocationOption(
                        label: stripLocationFlagPrefix(group.name),
                        subtitle: group.now,
                        icon: group.icon,
                        selected: group.name == currentTarget,
                        onTap: () => pick(group.name),
                      ),
                      for (final proxy in group.all)
                        LocationOption(
                          label: stripLocationFlagPrefix(proxy.name),
                          subtitle: null,
                          icon: '',
                          flagCode: flagToCountryCode(proxy.name),
                          indent: true,
                          selected: proxy.name == currentTarget,
                          onTap: () => pick(proxy.name),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class LocationOption extends StatelessWidget {
  const LocationOption({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.indent = false,
    this.flagCode,
  });

  final String label;
  final String? subtitle;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
  // Leaf proxies nested under a group header: pushed in and given a small
  // flag (or a plain dot when no flag could be parsed) instead of the
  // group's own icon, so the hierarchy reads at a glance.
  final bool indent;
  final String? flagCode;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(indent ? 22 : 8, 8, 8, 8),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: selected
                ? premiumMint.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              indent
                  ? LocationFlag(code: flagCode, selected: selected)
                  : CommonTargetIcon(src: icon, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? premiumMint
                            : context.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 16, color: premiumMint),
            ],
          ),
        ),
      );
}

class LocationFlag extends StatelessWidget {
  const LocationFlag({super.key, required this.code, required this.selected});

  final String? code;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    final cc = code?.trim().toLowerCase();
    Widget dot() => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? premiumMint
                : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        );
    if (cc == null || cc.length != 2) return dot();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: 'https://flagcdn.com/w40/$cc.png',
        width: size,
        height: size * 0.75,
        fit: BoxFit.cover,
        placeholder: (_, __) => SizedBox(width: size, height: size * 0.75),
        errorWidget: (_, __, ___) => dot(),
      ),
    );
  }
}

class RouteOption extends StatelessWidget {
  const RouteOption({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          backgroundColor:
              selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          foregroundColor:
              selected ? color : context.colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      );
}
