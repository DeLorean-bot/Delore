import 'dart:convert';

import 'package:flclashx/common/application_routing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DomainRouteEntry {
  const DomainRouteEntry({
    required this.domain,
    required this.route,
    this.target,
    this.favorite = false,
  });

  factory DomainRouteEntry.fromJson(Map<String, dynamic> json) =>
      DomainRouteEntry(
        domain: json['domain'] as String? ?? '',
        route: ApplicationRoute.values.firstWhere(
          (value) => value.name == json['route'],
          orElse: () => ApplicationRoute.proxy,
        ),
        target: json['target'] as String?,
        favorite: json['favorite'] as bool? ?? false,
      );

  final String domain;
  final ApplicationRoute route;
  final String? target;
  final bool favorite;

  // DOMAIN-SUFFIX matches the domain itself and every subdomain — what
  // someone typing "youtube.com" into a "route this site" box means, not
  // just that one exact host.
  String get clashRule {
    final escapedDomain = domain.replaceAll(',', r'\,');
    final ruleTarget =
        route == ApplicationRoute.direct ? 'DIRECT' : (target ?? 'DIRECT');
    return 'DOMAIN-SUFFIX,$escapedDomain,$ruleTarget';
  }

  Map<String, Object?> toJson() => {
        'domain': domain,
        'route': route.name,
        if (target != null) 'target': target,
        if (favorite) 'favorite': true,
      };
}

/// Persists per-site routing independently from profile YAML, namespaced by
/// profile — mirrors [ApplicationRoutingStore]. Order matters here (unlike
/// the app map): entries are injected ahead of the visual per-app rules, so
/// a site pin can carve an exception out of an app that's already pinned to
/// its own target (e.g. route Chrome through one location generally, but
/// send youtube.com out through another regardless of which app opened it).
class DomainRoutingStore {
  DomainRoutingStore._();

  static const _prefix = 'domain_routes_v1_';

  static String _key(String profileId) => '$_prefix$profileId';

  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
    final slash = value.indexOf('/');
    if (slash != -1) value = value.substring(0, slash);
    final colon = value.indexOf(':');
    if (colon != -1) value = value.substring(0, colon);
    return value.replaceFirst(RegExp(r'^www\.'), '');
  }

  /// Returns the most specific saved rule that covers [input]. A rule saved
  /// for example.com also covers www.example.com and music.example.com, just
  /// like the DOMAIN-SUFFIX rule sent to Mihomo.
  static DomainRouteEntry? find(
    Iterable<DomainRouteEntry> entries,
    String input,
  ) {
    final domain = normalize(input);
    final matches = entries.where(
      (entry) => domain == entry.domain || domain.endsWith('.${entry.domain}'),
    );
    if (matches.isEmpty) return null;
    return matches.reduce(
      (current, candidate) =>
          candidate.domain.length > current.domain.length ? candidate : current,
    );
  }

  static Future<List<DomainRouteEntry>> load(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return [
        for (final value in values)
          if (value is Map<String, dynamic>) DomainRouteEntry.fromJson(value),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(
    String profileId,
    List<DomainRouteEntry> entries,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(profileId),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  /// Adds or replaces the entry for [entry.domain] (case-insensitive), or
  /// removes it entirely when [entry.route] is [ApplicationRoute.rule].
  static Future<void> set(String profileId, DomainRouteEntry entry) async {
    final entries = await load(profileId);
    final domain = normalize(entry.domain);
    entries.removeWhere((existing) => existing.domain == domain);
    if (entry.route != ApplicationRoute.rule && domain.isNotEmpty) {
      entries.add(DomainRouteEntry(
        domain: domain,
        route: entry.route,
        target: entry.target,
        favorite: entry.favorite,
      ));
    }
    await _save(profileId, entries);
  }

  static Future<void> remove(String profileId, String domain) async {
    final entries = await load(profileId);
    entries.removeWhere((entry) => entry.domain == normalize(domain));
    await _save(profileId, entries);
  }

  static Future<List<String>> clashRules(String profileId) async {
    final entries = await load(profileId);
    return entries.map((entry) => entry.clashRule).toList(growable: false);
  }
}
