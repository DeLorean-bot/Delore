import 'dart:io';

extension NetworkInterfaceExt on NetworkInterface {
  bool get isWifi {
    final nameLowCase = name.toLowerCase();
    if (nameLowCase.contains('wlan') ||
        nameLowCase.contains('wi-fi') ||
        nameLowCase == 'en0' ||
        nameLowCase == 'eth0') {
      return true;
    }

    return false;
  }

  bool get includesIPv4 => addresses.any((addr) => addr.isIPv4);
}

extension InternetAddressExt on InternetAddress {
  bool get isIPv4 => type == InternetAddressType.IPv4;
}

/// Returns the real Windows uplink instead of a TUN/VPN adapter.
///
/// Leaving `interface-name` empty lets Windows route an outbound QUIC socket
/// back into another client's full-tunnel adapter. That client can then apply
/// its own UDP/443 policy to Delore (Koala's QUIC blocking rule is one real
/// example), while TCP-based proxies keep working and hide the conflict.
Future<String> detectWindowsPhysicalInterface() async {
  if (!Platform.isWindows) return '';

  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  const virtualMarkers = <String>[
    'tun',
    'tap',
    'wintun',
    'vpn',
    'clash',
    'mihomo',
    'wireguard',
    'tailscale',
    'zerotier',
    'radmin',
    'warp',
    'hyper-v',
    'vmware',
    'virtualbox',
    'vethernet',
  ];

  bool hasUsableIPv4(NetworkInterface interface) => interface.addresses.any(
        (address) =>
            address.type == InternetAddressType.IPv4 &&
            !address.isLoopback &&
            !address.address.startsWith('169.254.'),
      );

  final candidates = interfaces.where((interface) {
    final name = interface.name.toLowerCase();
    return hasUsableIPv4(interface) && !virtualMarkers.any(name.contains);
  }).toList()
    ..sort((a, b) {
      int score(NetworkInterface interface) {
        final name = interface.name.toLowerCase();
        if (name.contains('wi-fi') || name.contains('wifi')) return 0;
        if (name.contains('ethernet')) return 1;
        return 2;
      }

      return score(a).compareTo(score(b));
    });

  return candidates.isEmpty ? '' : candidates.first.name;
}
