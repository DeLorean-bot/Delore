import 'dart:io';

import 'package:flutter/services.dart';

class DiscoveredApplication {
  const DiscoveredApplication({
    required this.pid,
    required this.name,
    required this.executablePath,
    required this.windowTitle,
  });

  factory DiscoveredApplication.fromMap(Map<Object?, Object?> value) =>
      DiscoveredApplication(
        pid: value['pid'] as int? ?? 0,
        name: value['name'] as String? ?? '',
        executablePath: value['executablePath'] as String? ?? '',
        windowTitle: value['windowTitle'] as String? ?? '',
      );

  final int pid;
  final String name;
  final String executablePath;
  final String windowTitle;
}

class AppDiscovery {
  AppDiscovery._();

  static const _channel = MethodChannel('flclashx/app_discovery');

  static Future<List<DiscoveredApplication>> getOpenApplications() async {
    if (!Platform.isWindows) return const [];
    final values =
        await _channel.invokeListMethod<Object?>('getOpenApplications');
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(DiscoveredApplication.fromMap)
        .where((app) => app.pid > 0 && app.name.isNotEmpty)
        .toList(growable: false);
  }
}
