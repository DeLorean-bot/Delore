import 'package:flclashx/models/clash_config.dart';

/// Builds the TUN section used by Mihomo without mixing two routing policies.
///
/// A profile-provided TUN block is preserved as one unit unless the user has
/// explicitly enabled Delore's network override. Delore always owns only the
/// effective on/off state. This mirrors the behaviour of standalone Mihomo
/// clients and prevents a profile's strict-route/auto-detection settings from
/// being combined with an unrelated device or DNS-hijack configuration.
Map<String, dynamic> buildRuntimeTun({
  required Object? providerTun,
  required Tun patchTun,
  required bool enable,
  required bool overrideProvider,
}) {
  final hasProviderTun = providerTun is Map;
  final result = hasProviderTun
      ? Map<String, dynamic>.from(providerTun)
      : <String, dynamic>{};
  result['enable'] = enable;

  if (overrideProvider || !hasProviderTun) {
    result
      ..['device'] = patchTun.device
      ..['dns-hijack'] = patchTun.dnsHijack
      ..['stack'] = patchTun.stack.name
      ..['route-address'] = patchTun.routeAddress
      ..['auto-route'] = patchTun.autoRoute;
  }
  return result;
}
