import 'dart:async';

import 'package:flclashx/clash/clash.dart';
import 'package:flutter/foundation.dart';

/// One app's live network flow, aggregated across all of its connections.
@immutable
class AppFlow {
  const AppFlow({
    required this.process,
    required this.connectionId,
    required this.host,
    required this.countryCode,
    required this.upload,
    required this.download,
    required this.upSpeed,
    required this.downSpeed,
    required this.viaProxy,
  });

  /// Process name as mihomo reports it, e.g. "chrome.exe".
  final String process;

  /// Any one of this app's connection ids — enough to look its icon up.
  final String connectionId;

  /// The most representative destination host for the app right now.
  final String host;

  /// ISO country of the destination, once geoip resolves it.
  final String? countryCode;

  /// Cumulative bytes on the app's current connections.
  final int upload;
  final int download;

  /// Bytes/sec, from the delta between polls.
  final int upSpeed;
  final int downSpeed;

  /// False when every chain is DIRECT — i.e. the app bypasses the proxy.
  final bool viaProxy;
}

/// Polls the core for live connections and groups them per app, so the
/// dashboard's map and its "active apps" panel read the same snapshot
/// instead of each running its own poll loop.
///
/// Mirrors `detectionState`: a plain ValueNotifier singleton rather than a
/// generated Riverpod provider, matching how this codebase already exposes
/// polled core state.
class DashboardFlows {
  final ValueNotifier<List<AppFlow>> state = ValueNotifier(const []);

  Timer? _timer;
  int _listeners = 0;
  final Map<String, String> _ipCountryCache = {};
  Map<String, ({int up, int down})> _previous = {};
  DateTime _previousAt = DateTime.now();

  /// Ref-counted so several widgets can depend on the feed without any one
  /// of them tearing it down for the others when it unmounts.
  void addListener() {
    _listeners++;
    if (_listeners == 1) unawaited(_poll());
  }

  void removeListener() {
    _listeners--;
    if (_listeners <= 0) {
      _listeners = 0;
      _timer?.cancel();
      _timer = null;
      state.value = const [];
      _previous = {};
    }
  }

  Future<void> _poll() async {
    if (_listeners <= 0) return;
    try {
      final connections = await clashCore.getConnections();
      final grouped =
          <String, ({String id, int up, int down, String ip, String host, bool proxy})>{};
      for (final c in connections) {
        final process = c.metadata.process;
        if (process.isEmpty) continue;
        final prev = grouped[process];
        final viaProxy = c.chains
            .any((chain) => chain != 'DIRECT' && chain != 'REJECT');
        grouped[process] = (
          id: prev?.id ?? c.id,
          up: (prev?.up ?? 0) + (c.upload?.toInt() ?? 0),
          down: (prev?.down ?? 0) + (c.download?.toInt() ?? 0),
          ip: (prev?.ip.isNotEmpty ?? false) ? prev!.ip : c.metadata.destinationIP,
          host: (prev?.host.isNotEmpty ?? false)
              ? prev!.host
              : (c.metadata.host.isNotEmpty
                  ? c.metadata.host
                  : c.metadata.destinationIP),
          proxy: (prev?.proxy ?? false) || viaProxy,
        );
      }

      final now = DateTime.now();
      final elapsed = now.difference(_previousAt).inMilliseconds / 1000.0;
      final flows = <AppFlow>[];
      for (final entry in grouped.entries) {
        final ip = entry.value.ip;
        var code = _ipCountryCache[ip];
        if (code == null && ip.isNotEmpty) {
          final info = await clashCore.getCountryCode(ip);
          code = info?.countryCode ?? '';
          _ipCountryCache[ip] = code;
        }
        final was = _previous[entry.key];
        // Only positive deltas: a connection closing shrinks the app's
        // cumulative total, which would otherwise read as negative speed.
        final upDelta = was == null ? 0 : (entry.value.up - was.up);
        final downDelta = was == null ? 0 : (entry.value.down - was.down);
        flows.add(AppFlow(
          process: entry.key,
          connectionId: entry.value.id,
          host: entry.value.host,
          // Normalised here: the flag helpers uppercase internally, so a
          // lowercase code from geoip still renders a flag — but every
          // lookup keyed by country code (the map's centroid table) would
          // silently miss.
          countryCode:
              (code != null && code.length == 2) ? code.toUpperCase() : null,
          upload: entry.value.up,
          download: entry.value.down,
          upSpeed: (elapsed > 0 && upDelta > 0) ? (upDelta / elapsed).round() : 0,
          downSpeed:
              (elapsed > 0 && downDelta > 0) ? (downDelta / elapsed).round() : 0,
          viaProxy: entry.value.proxy,
        ));
      }
      flows.sort(
        (a, b) => (b.downSpeed + b.upSpeed).compareTo(a.downSpeed + a.upSpeed),
      );
      _previous = {
        for (final e in grouped.entries) e.key: (up: e.value.up, down: e.value.down),
      };
      _previousAt = now;
      if (_listeners > 0) state.value = flows;
    } catch (_) {
      // Best-effort: keep the last good snapshot rather than blanking a live
      // panel because one poll failed.
    }
    if (_listeners > 0) {
      _timer = Timer(const Duration(seconds: 2), _poll);
    }
  }
}

final dashboardFlows = DashboardFlows();
