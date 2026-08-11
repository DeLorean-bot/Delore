import 'package:flclashx/common/runtime_config_patch.dart';
import 'package:flclashx/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves the provider TUN policy when override is disabled', () {
    final runtime = buildRuntimeTun(
      providerTun: {
        'enable': false,
        'stack': 'mixed',
        'strict-route': true,
        'auto-detect-interface': true,
        'dns-hijack': ['any:53', 'tcp://any:53'],
      },
      patchTun: const Tun(
        device: 'Delore',
        dnsHijack: ['any:53'],
        autoRoute: true,
      ),
      enable: true,
      overrideProvider: false,
    );

    expect(runtime['enable'], isTrue);
    expect(runtime['strict-route'], isTrue);
    expect(runtime['auto-detect-interface'], isTrue);
    expect(runtime['dns-hijack'], ['any:53', 'tcp://any:53']);
    expect(runtime.containsKey('device'), isFalse);
  });

  test('uses Delore TUN values only for an explicit override', () {
    final runtime = buildRuntimeTun(
      providerTun: {
        'strict-route': true,
        'dns-hijack': ['tcp://any:53'],
      },
      patchTun: const Tun(
        device: 'Delore',
        dnsHijack: ['any:53'],
        autoRoute: true,
      ),
      enable: true,
      overrideProvider: true,
    );

    expect(runtime['device'], 'Delore');
    expect(runtime['dns-hijack'], ['any:53']);
    expect(runtime['auto-route'], isTrue);
    expect(runtime['strict-route'], isTrue);
  });
}
