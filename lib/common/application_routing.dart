import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ApplicationRoute { rule, proxy, direct }

class ApplicationRouteEntry {
  const ApplicationRouteEntry({
    required this.executablePath,
    required this.route,
    this.target,
  });

  factory ApplicationRouteEntry.fromJson(Map<String, dynamic> json) =>
      ApplicationRouteEntry(
        executablePath: json['path'] as String? ?? '',
        route: ApplicationRoute.values.firstWhere(
          (value) => value.name == json['route'],
          orElse: () => ApplicationRoute.rule,
        ),
        target: json['target'] as String?,
      );

  final String executablePath;
  final ApplicationRoute route;
  final String? target;

  String get clashRule {
    final escapedPath = executablePath.replaceAll(',', r'\,');
    return 'PROCESS-PATH,$escapedPath,${target ?? 'DIRECT'}';
  }

  Map<String, Object?> toJson() => {
        'path': executablePath,
        'route': route.name,
        if (target != null) 'target': target,
      };
}

/// Persists the visual application's routing layer independently from profile
/// YAML. Rules are namespaced by profile and injected at runtime with highest
/// priority, so subscriptions can update without overwriting the user's choices.
class ApplicationRoutingStore {
  ApplicationRoutingStore._();

  static const _prefix = 'application_routes_v1_';

  static String _key(String profileId) => '$_prefix$profileId';

  static Future<Map<String, ApplicationRouteEntry>> load(
    String profileId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return {
        for (final value in values)
          if (value is Map<String, dynamic>)
            value['path'].toString().toLowerCase():
                ApplicationRouteEntry.fromJson(value),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> set(
    String profileId,
    ApplicationRouteEntry entry,
  ) async {
    final routes = await load(profileId);
    final key = entry.executablePath.toLowerCase();
    if (entry.route == ApplicationRoute.rule) {
      routes.remove(key);
    } else {
      routes[key] = entry;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(profileId),
      jsonEncode(routes.values.map((value) => value.toJson()).toList()),
    );
  }

  static Future<List<String>> clashRules(String profileId) async {
    final routes = await load(profileId);
    return routes.values
        .where((entry) => entry.route != ApplicationRoute.rule)
        .map((entry) => entry.clashRule)
        .toList(growable: false);
  }
}
