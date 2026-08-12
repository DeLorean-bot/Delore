import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/state.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
    ProxyCardType.oneline => 16 + measure.bodyMediumHeight + 4,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final state = appController.getProxyCardState(proxy.name);
  final url = state.testUrl.getSafeValue(
    appController.getRealTestUrl(testUrl),
  );
  if (state.proxyName.isEmpty) {
    return;
  }
  appController.setDelay(
    Delay(
      url: url,
      name: state.proxyName,
      value: 0,
    ),
  );
  try {
    appController.setDelay(
      await clashCore.getDelay(
        url,
        state.proxyName,
      ),
    );
  } catch (_) {
    appController.setDelay(
      Delay(
        url: url,
        name: state.proxyName,
        value: -1,
      ),
    );
  }
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final appController = globalState.appController;
  final proxyNames = proxies.map((proxy) => proxy.name).toSet().toList();

  // Keep this comfortably below the core semaphore (50). Starting every node
  // in a large subscription at once causes packet loss and false timeouts for
  // QUIC/TLS-heavy transports such as Hysteria2, XHTTP and Reality/ML-KEM.
  // Futures must be created inside the loop: creating them before `batch()`
  // starts every test immediately and makes the batching ineffective.
  for (final batchProxyNames in proxyNames.batch(16)) {
    await Future.wait(batchProxyNames.map((proxyName) async {
      final state = appController.getProxyCardState(proxyName);
      final url = state.testUrl.getSafeValue(
        appController.getRealTestUrl(testUrl),
      );
      final name = state.proxyName;
      if (name.isEmpty) {
        return;
      }
      appController.setDelay(
        Delay(
          url: url,
          name: name,
          value: 0,
        ),
      );
      try {
        appController.setDelay(
          await clashCore.getDelay(
            url,
            name,
          ),
        );
      } catch (_) {
        appController.setDelay(
          Delay(
            url: url,
            name: name,
            value: -1,
          ),
        );
      }
    }));
  }
  appController.addSortNum();
}
