import 'dart:async';
import 'dart:io';

import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _DoctorStatus { passed, warning, failed }

class _DoctorResult {
  const _DoctorResult({
    required this.title,
    required this.detail,
    required this.status,
  });

  final String title;
  final String detail;
  final _DoctorStatus status;
}

/// A user-facing health check. It intentionally reports actionable state
/// instead of dumping raw Clash logs or YAML at a non-technical user.
class RouteDoctorView extends ConsumerStatefulWidget {
  const RouteDoctorView({super.key});

  @override
  ConsumerState<RouteDoctorView> createState() => _RouteDoctorViewState();
}

class _RouteDoctorViewState extends ConsumerState<RouteDoctorView> {
  bool _running = false;
  List<_DoctorResult> _results = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results = const [];
    });

    final results = <_DoctorResult>[];
    final profileId = ref.read(currentProfileIdProvider);
    final profile = ref.read(profilesProvider).getProfile(profileId);

    if (profile == null) {
      results.add(const _DoctorResult(
        title: 'Active profile',
        detail: 'Select or add a subscription before connecting.',
        status: _DoctorStatus.failed,
      ));
    } else {
      final file = await profile.getFile();
      final hasData = await file.length() > 0;
      results.add(_DoctorResult(
        title: 'Active profile',
        detail: hasData
            ? '${profile.label ?? profile.id} is available.'
            : 'The selected profile file is empty. Update the subscription.',
        status: hasData ? _DoctorStatus.passed : _DoctorStatus.failed,
      ));
      if (hasData) {
        try {
          final message =
              await clashCore.validateConfig(await file.readAsString());
          results.add(_DoctorResult(
            title: 'Profile validation',
            detail: message.isEmpty
                ? 'Mihomo accepts the current configuration.'
                : message,
            status:
                message.isEmpty ? _DoctorStatus.passed : _DoctorStatus.failed,
          ));
        } catch (error) {
          results.add(_DoctorResult(
            title: 'Profile validation',
            detail: '$error',
            status: _DoctorStatus.failed,
          ));
        }
      }
    }

    final coreRunning = globalState.isStart;
    results.add(_DoctorResult(
      title: 'Mihomo core',
      detail: coreRunning
          ? 'The routing core is running.'
          : 'The routing core is stopped. Connect Delore to route traffic.',
      status: coreRunning ? _DoctorStatus.passed : _DoctorStatus.warning,
    ));

    if (coreRunning) {
      try {
        final connections = await clashCore
            .getConnections()
            .timeout(const Duration(seconds: 4));
        results.add(_DoctorResult(
          title: 'Core control channel',
          detail:
              'Responding normally · ${connections.length} active connections.',
          status: _DoctorStatus.passed,
        ));
      } catch (error) {
        results.add(_DoctorResult(
          title: 'Core control channel',
          detail: 'The app cannot reach the running core: $error',
          status: _DoctorStatus.failed,
        ));
      }
    }

    try {
      final addresses = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 5));
      results.add(_DoctorResult(
        title: 'DNS resolution',
        detail: addresses.isEmpty
            ? 'The resolver returned no addresses.'
            : 'DNS is responding · ${addresses.first.address}',
        status: addresses.isEmpty ? _DoctorStatus.failed : _DoctorStatus.passed,
      ));
    } catch (error) {
      results.add(_DoctorResult(
        title: 'DNS resolution',
        detail: 'Domain lookup failed: $error',
        status: _DoctorStatus.failed,
      ));
    }

    try {
      final response =
          await request.checkIp().timeout(const Duration(seconds: 12));
      final ipInfo = response.data;
      results.add(_DoctorResult(
        title: coreRunning ? 'Proxy exit' : 'Internet access',
        detail: ipInfo == null
            ? 'No test endpoint responded.'
            : '${ipInfo.ip} · ${ipInfo.countryCode.toUpperCase()}',
        status: ipInfo == null ? _DoctorStatus.failed : _DoctorStatus.passed,
      ));
    } catch (error) {
      results.add(_DoctorResult(
        title: coreRunning ? 'Proxy exit' : 'Internet access',
        detail: 'Connectivity check failed: $error',
        status: _DoctorStatus.failed,
      ));
    }

    if (!mounted) return;
    setState(() {
      _results = results;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failures = _results
        .where((result) => result.status == _DoctorStatus.failed)
        .length;
    final warnings = _results
        .where((result) => result.status == _DoctorStatus.warning)
        .length;
    final healthy = !_running && _results.isNotEmpty && failures == 0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          children: [
            RouteXGlassSurface(
              variant: RouteXGlassVariant.panel,
              radius: 28,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: RouteXMotion.base,
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_running
                                ? premiumBlue
                                : healthy
                                    ? premiumMint
                                    : premiumAmber)
                            .withValues(alpha: 0.14),
                      ),
                      child: _running
                          ? const Padding(
                              padding: EdgeInsets.all(17),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              healthy
                                  ? Icons.health_and_safety_rounded
                                  : Icons.troubleshoot_rounded,
                              color: healthy ? premiumMint : premiumAmber,
                            ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _running
                                ? 'Checking your route…'
                                : healthy
                                    ? 'Route looks healthy'
                                    : '$failures problems · $warnings warnings',
                            style: context.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Delore checks the profile, core, DNS and the real network exit.',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Run diagnostics again',
                      onPressed: _running ? null : _run,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final result in _results) ...[
              _ResultTile(result: result),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final _DoctorResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (result.status) {
      _DoctorStatus.passed => (Icons.check_circle_rounded, premiumMint),
      _DoctorStatus.warning => (Icons.info_rounded, premiumAmber),
      _DoctorStatus.failed => (Icons.error_rounded, Colors.redAccent),
    };
    return CommonCard(
      radius: 18,
      child: ListTile(
        minTileHeight: 76,
        leading: Icon(icon, color: color),
        title: Text(result.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(result.detail),
        ),
      ),
    );
  }
}
