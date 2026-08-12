import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Pointer;
import 'dart:io' show Platform;

import 'package:animations/animations.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/theme.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/plugins/service.dart';
import 'package:flclashx/widgets/dialog.dart';
import 'package:flclashx/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'controller.dart';
import 'core_version.dart';
import 'models/models.dart';

typedef UpdateTasks = List<FutureOr Function()>;

class GlobalState {
  factory GlobalState() {
    _instance ??= GlobalState._internal();
    return _instance!;
  }

  GlobalState._internal();
  static GlobalState? _instance;
  Map<CacheTag, double> cacheScrollPosition = {};
  Map<CacheTag, FixedMap<String, double>> cacheHeightMap = {};
  Timer? timer;
  Timer? groupsUpdateTimer;
  late Config config;
  late AppState appState;
  bool isPre = true;
  String? coreSHA256;
  String? coreVersion;
  // Full release version baked in at build time via --dart-define=APP_VERSION
  // (the CI git tag, e.g. "0.4.1-pre.18", leading `v` stripped). Empty on local
  // builds, where [_uaVersion] falls back to the pubspec version + a `-pre` mark.
  String appVersionTag = "";
  late PackageInfo packageInfo;
  Function? updateCurrentDelayDebounce;
  late Measure measure;
  late CommonTheme theme;
  late Color accentColor;
  CorePalette? corePalette;
  DateTime? startTime;
  UpdateTasks tasks = [];
  Map<String, dynamic>? lastRuntimeConfig;
  // Effective external-controller endpoint after merging subscription value
  // over UI defaults. Empty string means disabled. Subscription value wins if
  // present, otherwise falls back to the UI toggle default.
  final effectiveExternalController = ValueNotifier<String>("");
  // The active profile's external-controller secret (rawConfig["secret"]), used to
  // build the zashboard backend URL. Empty when the profile sets none.
  final effectiveSecret = ValueNotifier<String>("");
  // The external-ui sub-path (e.g. "ui") the core serves the dashboard at; part of
  // the zashboard URL. Empty when the profile sets none.
  final effectiveExternalUi = ValueNotifier<String>("");
  // Effective values for fields that follow the overrideNetworkSettings gate
  // but don't round-trip through patchClashConfigProvider. UI reads these when
  // override is OFF so it shows what's actually applied (profile or fallback).
  final effectiveTcpConcurrent = ValueNotifier<bool>(false);
  final effectiveUnifiedDelay = ValueNotifier<bool>(false);
  final effectiveLogLevel = ValueNotifier<String>("info");
  final effectiveKeepAliveInterval = ValueNotifier<int>(30);
  // Custom per-group descriptions parsed from the profile YAML
  // (proxy-groups[*].description). Shown as the subtitle of a nested group
  // card instead of its type (Fallback/URLTest/Selector).
  final groupDescriptions = ValueNotifier<Map<String, String>>({});
  // Opt-in flag parsed from the GLOBAL proxy-group (`flclashx-override: true`).
  // Only when this is set do we apply the curated-GLOBAL behaviour (global mode
  // shows just GLOBAL, GLOBAL.all is curated, all groups are enumerated for rule
  // mode). Without it everything behaves exactly as before.
  final globalOverrideEnabled = ValueNotifier<bool>(false);
  // Curated member list for the GLOBAL group, parsed from the profile YAML
  // (the proxy-groups entry named GLOBAL). Populated only when the override flag
  // above is set; updateGroups then filters and reorders the core's GLOBAL group
  // to exactly these names, in this order.
  final globalGroupOrder = ValueNotifier<List<String>>([]);
  // All proxy-group names in profile-declaration order. Used only under the
  // GLOBAL override to order the service groups that getProxiesGroups appends
  // from the core's proxies map — that map's keys arrive alphabetically (Go's
  // json.Marshal sorts map keys), so without this the rule-mode group tabs would
  // sort alphabetically instead of following the config.
  final proxyGroupOrder = ValueNotifier<List<String>>([]);
  final navigatorKey = GlobalKey<NavigatorState>();
  AppController? _appController;
  GlobalKey<CommonScaffoldState> homeScaffoldKey = GlobalKey();
  bool isInit = false;

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  AppController get appController => _appController!;

  /// Whether [appController] is safe to dereference. Used to route tile/widget
  /// events to exactly one handler: the boot-safe [_MainTileListener] before the
  /// app is ready, and the UI's TileManager once it is.
  bool get isAppControllerReady => _appController != null;

  set appController(AppController appController) {
    _appController = appController;
    isInit = true;
  }

  Future<void> initApp(int version) async {
    coreSHA256 = const String.fromEnvironment("CORE_SHA256");
    final coreVersionEnv = const String.fromEnvironment("CORE_VERSION");
    coreVersion =
        coreVersionEnv.isEmpty ? kCoreVersionFromSource : coreVersionEnv;
    isPre = const String.fromEnvironment("APP_ENV") != 'stable';
    const appVersionEnv = String.fromEnvironment("APP_VERSION");
    final tag = appVersionEnv.trim();
    appVersionTag =
        (tag.startsWith("v") || tag.startsWith("V")) ? tag.substring(1) : tag;
    appState = AppState(
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
    );
    await _initDynamicColor();
    await init();
  }

  Future<void> _initDynamicColor() async {
    try {
      corePalette = await DynamicColorPlugin.getCorePalette();
      accentColor = await DynamicColorPlugin.getAccentColor() ??
          const Color(defaultPrimaryColor);
    } catch (_) {}
  }

  Future<void> init() async {
    packageInfo = await PackageInfo.fromPlatform();
    config = await preferences.getConfig() ??
        const Config(
          themeProps: defaultThemeProps,
        );
    // The legacy updater was disabled by default and only opened a browser.
    // Enable the new background installer once for existing users, while still
    // respecting any choice they make in Settings afterwards.
    final sharedPreferences = await SharedPreferences.getInstance();
    const updaterMigrationKey = 'delore_app_updater_v2_migrated';
    if (sharedPreferences.getBool(updaterMigrationKey) != true) {
      config = config.copyWith(
        appSetting: config.appSetting.copyWith(autoCheckUpdate: true),
      );
      await preferences.saveConfig(config);
      await sharedPreferences.setBool(updaterMigrationKey, true);
    }
    await globalState.migrateOldData(config);
    await AppLocalizations.load(
      utils.getLocaleForString(config.appSetting.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
  }

  // Version shown in the User-Agent: the exact release tag when present,
  // otherwise the pubspec version with a `-pre` marker for non-stable builds.
  String get _uaVersion => appVersionTag.isNotEmpty
      ? appVersionTag
      : (isPre ? "${packageInfo.version}-pre" : packageInfo.version);

  String get ua =>
      config.patchClashConfig.globalUa ??
      packageInfo.ua(appVersion: _uaVersion, coreVersion: coreVersion);

  int _tasksEpoch = 0;

  Future<void> startUpdateTasks([UpdateTasks? tasks]) async {
    if (timer != null && timer!.isActive == true) return;
    if (tasks != null) {
      this.tasks = tasks;
    }
    final epoch = ++_tasksEpoch;
    await executorUpdateTask();
    // stopUpdateTasks() (or a restart) bumped the epoch while the executor was
    // in flight: don't reschedule, otherwise the poll loop resurrects itself and
    // keeps hammering a (possibly dead) remote forever after a stop.
    if (epoch != _tasksEpoch) return;
    timer = Timer(const Duration(seconds: 3), () {
      startUpdateTasks();
    });
  }

  Future<void> executorUpdateTask() async {
    for (final task in tasks) {
      // Isolate failures: one throwing task must not kill the whole loop (which
      // would silently freeze traffic/runtime counters while the tunnel is live).
      try {
        await task();
      } catch (e) {
        commonPrint.log('executorUpdateTask error: $e');
      }
    }
    timer = null;
  }

  void stopUpdateTasks() {
    // Always invalidate the in-flight cycle (the executor nulls `timer` mid-run,
    // so the old `timer == null` early-return let a stop slip through and the
    // loop rescheduled anyway).
    _tasksEpoch++;
    timer?.cancel();
    timer = null;
  }

  // Background proxy-group refresh (latency/now). Paused while the app is in the
  // background so it doesn't poll the core every 60s for a UI nobody is looking
  // at; resumed (with an immediate refresh) when the app comes back to front.
  void startGroupsUpdateTask() {
    if (groupsUpdateTimer != null && groupsUpdateTimer!.isActive) return;
    groupsUpdateTimer = Timer(const Duration(seconds: 60), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appController.updateGroupsDebounce();
        startGroupsUpdateTask();
      });
    });
  }

  void stopGroupsUpdateTask() {
    groupsUpdateTimer?.cancel();
    groupsUpdateTimer = null;
  }

  Future<bool> handleStart([UpdateTasks? tasks]) async {
    startTime ??= DateTime.now();
    await clashCore.startListener();
    final started = await service?.startVpn();
    // started == false → the Android remote bring-up failed (establish() returned
    // null / Core.startTun failed); the service emitted STOP and the tunnel is down.
    // null → desktop (service is null), which is success. Roll back the optimistic
    // state so the UI doesn't show a live tunnel that isn't there (it never self-heals).
    if (started == false) {
      startTime = null;
      await clashCore.stopListener();
      stopUpdateTasks();
      return false;
    }
    startUpdateTasks(tasks);
    return true;
  }

  /// Probes the native run time and syncs [startTime]. Returns false when the
  /// probe failed (state unknown) — [startTime] is left untouched in that case
  /// so callers don't mistake "couldn't reach the service" for "stopped".
  Future<bool> updateStartTime() async {
    final lib = clashLib;
    if (lib == null) return true;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        startTime = await lib.getRunTime();
        return true;
      } catch (e) {
        commonPrint.log('updateStartTime probe failed (#$attempt): $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future handleStop() async {
    startTime = null;
    await clashCore.stopListener();
    await service?.stopVpn();
    stopUpdateTasks();
  }

  Future<bool?> showMessage({
    String? title,
    required InlineSpan message,
    String? confirmText,
    bool cancelable = true,
  }) async =>
      showCommonDialog<bool>(
        child: Builder(
          builder: (context) => CommonDialog(
            title: title ?? appLocalizations.tip,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              )
            ],
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [message],
                  ),
                  style: const TextStyle(
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<T?> showCommonDialog<T>({
    required Widget child,
    bool dismissible = true,
  }) async =>
      showModal<T>(
        context: navigatorKey.currentState!.context,
        configuration: FadeScaleTransitionConfiguration(
          barrierColor: Colors.black38,
          barrierDismissible: dismissible,
        ),
        builder: (_) => child,
        filter: commonFilter,
      );

  Future<T?> safeRun<T>(
    FutureOr<T> Function() futureFunction, {
    String? title,
    bool silence = true,
  }) async {
    try {
      final res = await futureFunction();
      return res;
    } catch (e) {
      commonPrint.log("$e");
      if (silence) {
        showNotifier(e.toString());
      } else {
        showMessage(
          title: title ?? appLocalizations.tip,
          message: TextSpan(
            text: e.toString(),
          ),
        );
      }
      return null;
    }
  }

  void showNotifier(String text) {
    if (text.isEmpty) {
      return;
    }
    navigatorKey.currentContext?.showNotifier(text);
  }

  Future<void> openUrl(String url) async {
    final res = await showMessage(
      message: TextSpan(text: url),
      title: appLocalizations.externalLink,
      confirmText: appLocalizations.go,
    );
    if (res != true) {
      return;
    }
    launchUrl(Uri.parse(url));
  }

  Future<void> migrateOldData(Config config) async {
    final clashConfig = await preferences.getClashConfig();
    if (clashConfig != null) {
      config = config.copyWith(
        patchClashConfig: clashConfig,
      );
      preferences.clearClashConfig();
      preferences.saveConfig(config);
    }
  }

  CoreState getCoreState() {
    final currentProfile = config.currentProfile;
    return CoreState(
      vpnProps: config.vpnProps,
      onlyStatisticsProxy: false,
      currentProfileName: currentProfile?.label ?? currentProfile?.id ?? "",
      bypassDomain: config.networkProps.bypassDomain,
    );
  }

  Future<SetupParams> getSetupParams({
    required ClashConfig pathConfig,
  }) async {
    final clashConfig = await patchRawConfig(
      patchConfig: pathConfig,
    );
    lastRuntimeConfig = clashConfig;
    final params = SetupParams(
      config: clashConfig,
      selectedMap: config.currentProfile?.selectedMap ?? {},
      testUrl: config.appSetting.testUrl,
    );
    return params;
  }

  Future<ClashConfig> syncNetworkSettingsFromProvider(
      ClashConfig patchConfig) async {
    if (config.appSetting.overrideNetworkSettings) {
      return patchConfig; // User wants to override, keep current settings
    }

    final profile = config.currentProfile;
    if (profile == null) {
      return patchConfig;
    }

    try {
      final profileId = profile.id;
      final configMap = await getProfileConfig(profileId);
      final rawConfig = await handleEvaluate(configMap);

      final providerIpv6 = rawConfig['ipv6'] as bool? ?? patchConfig.ipv6;
      final providerAllowLan =
          rawConfig['allow-lan'] as bool? ?? patchConfig.allowLan;
      final providerMixedPort =
          rawConfig['mixed-port'] as int? ?? patchConfig.mixedPort;
      final providerFindProcessModeStr =
          rawConfig['find-process-mode'] as String?;
      final providerFindProcessMode = providerFindProcessModeStr != null
          ? FindProcessMode.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  providerFindProcessModeStr.toLowerCase(),
              orElse: () => patchConfig.findProcessMode,
            )
          : patchConfig.findProcessMode;

      final providerTunStackStr = rawConfig['tun']?['stack'] as String?;
      final providerTunStack = providerTunStackStr != null
          ? TunStack.values.firstWhere(
              (e) => e.name.toLowerCase() == providerTunStackStr.toLowerCase(),
              orElse: () => patchConfig.tun.stack,
            )
          : patchConfig.tun.stack;

      return patchConfig
          .copyWith(
            ipv6: providerIpv6,
            allowLan: providerAllowLan,
            mixedPort: providerMixedPort,
            findProcessMode: providerFindProcessMode,
          )
          .copyWith
          .tun(stack: providerTunStack);
    } catch (e) {
      commonPrint.log("Error syncing network settings from provider: $e");
      return patchConfig;
    }
  }

  Future<Map<String, dynamic>> patchRawConfig({
    required ClashConfig patchConfig,
  }) async {
    final profile = config.currentProfile;
    if (profile == null) {
      return {};
    }
    final profileId = profile.id;
    final configMap = await getProfileConfig(profileId);
    final rawConfig = await handleEvaluate(configMap);

    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(config.networkProps.routeMode),
    );
    // Custom "description" field on proxy-groups — extracted here because
    // mihomo's /proxies API doesn't forward arbitrary YAML keys.
    final parsedGroupDescriptions = <String, String>{};
    // Opt-in only: when the GLOBAL proxy-group (and only GLOBAL) carries
    // `flclashx-override: true`, its `proxies` list is the curated set/order we
    // show in global mode. Any other group's flag is ignored.
    final parsedGlobalOrder = <String>[];
    // Every proxy-group name in declaration order (see proxyGroupOrder).
    final parsedProxyGroupOrder = <String>[];
    var parsedGlobalOverride = false;
    final rawGroups = rawConfig["proxy-groups"];
    if (rawGroups is List) {
      for (final g in rawGroups) {
        if (g is! Map) continue;
        final name = g["name"];
        if (name is! String) continue;
        parsedProxyGroupOrder.add(name);
        final desc = g["description"];
        if (desc is String && desc.trim().isNotEmpty) {
          parsedGroupDescriptions[name] = desc.trim();
        }
        if (name == GroupName.GLOBAL.name) {
          final override = g["flclashx-override"];
          parsedGlobalOverride = override == true ||
              (override is String && override.trim().toLowerCase() == 'true');
          if (parsedGlobalOverride) {
            final proxies = g["proxies"];
            if (proxies is List) {
              for (final p in proxies) {
                if (p is String && p.trim().isNotEmpty) {
                  parsedGlobalOrder.add(p.trim());
                }
              }
            }
          }
        }
      }
    }
    groupDescriptions.value = parsedGroupDescriptions;
    globalGroupOrder.value = parsedGlobalOrder;
    proxyGroupOrder.value = parsedProxyGroupOrder;
    globalOverrideEnabled.value = parsedGlobalOverride;
    // external-controller: profile value always wins when present. The UI
    // toggle only acts as a fallback because the enum hardcodes 127.0.0.1:9090
    // and would otherwise silently override a subscription-provided endpoint
    // (e.g. :9091). The overrideNetworkSettings gate is intentionally ignored
    // here — users who set external-controller in their profile mean it.
    final providerExternalController =
        (rawConfig["external-controller"] as String?)?.trim() ?? "";
    final effectiveExternalControllerValue =
        providerExternalController.isNotEmpty
            ? providerExternalController
            : realPatchConfig.externalController.value;
    rawConfig["external-controller"] = effectiveExternalControllerValue;
    effectiveExternalController.value = effectiveExternalControllerValue;
    effectiveSecret.value = (rawConfig["secret"] as String?)?.trim() ?? "";
    // Always point the core at a local dir so it serves the dashboard at /ui/
    // on the same host:port as the controller (same origin, plain http — no
    // public instance, no mixed content). The app downloads zashboard into this
    // dir on demand (ensureZashboardUi). A profile may override external-ui.
    final providerUi = (rawConfig["external-ui"] as String?)?.trim() ?? "";
    final uiDir = providerUi.isNotEmpty
        ? providerUi
        : p.join(await appPath.homeDirPath, "zashboard");
    rawConfig["external-ui"] = uiDir;
    effectiveExternalUi.value = uiDir;
    // Keep Delore's own proxy sockets off another desktop VPN's TUN route.
    // This matters especially for UDP/QUIC protocols such as Hysteria2: a
    // concurrently running client may block UDP/443 while TCP nodes appear
    // healthy. The helper returns an empty string outside Windows or when no
    // safe physical uplink can be identified, preserving Mihomo's fallback.
    rawConfig["interface-name"] = await detectWindowsPhysicalInterface();
    // Mihomo deprecated the global fingerprint because it leaks one TLS
    // identity into unrelated transports. Koala deliberately omits it from
    // the generated runtime config; retaining it here makes Hysteria2/QUIC
    // fail on Windows in configurations where the same nodes work in Koala.
    // Per-proxy `client-fingerprint` values remain untouched.
    rawConfig.remove("global-client-fingerprint");
    if (rawConfig["external-ui-url"] == null ||
        rawConfig["external-ui-url"] == "") {
      rawConfig["external-ui-url"] = "";
    }
    // These follow the same overrideNetworkSettings gate as other fields:
    //   override ON  → UI value wins (always written)
    //   override OFF → profile value wins, UI is fallback only if missing
    // Effective values are exposed so the UI reflects what's actually applied
    // when override is OFF (otherwise widgets would still show stored UI prefs).
    final profileTcpConcurrent = rawConfig["tcp-concurrent"] as bool?;
    final profileUnifiedDelay = rawConfig["unified-delay"] as bool?;
    final profileLogLevel = rawConfig["log-level"] as String?;
    final profileKeepAlive =
        (rawConfig["keep-alive-interval"] as num?)?.toInt();
    final isOverride = config.appSetting.overrideNetworkSettings;
    final effTcpConcurrent = isOverride
        ? realPatchConfig.tcpConcurrent
        : (profileTcpConcurrent ?? realPatchConfig.tcpConcurrent);
    final effUnifiedDelay = isOverride
        ? realPatchConfig.unifiedDelay
        : (profileUnifiedDelay ?? realPatchConfig.unifiedDelay);
    final effLogLevel = isOverride
        ? realPatchConfig.logLevel.name
        : (profileLogLevel ?? realPatchConfig.logLevel.name);
    final effKeepAlive = isOverride
        ? realPatchConfig.keepAliveInterval
        : (profileKeepAlive ?? realPatchConfig.keepAliveInterval);
    rawConfig["tcp-concurrent"] = effTcpConcurrent;
    rawConfig["unified-delay"] = effUnifiedDelay;
    rawConfig["log-level"] = effLogLevel;
    rawConfig["keep-alive-interval"] = effKeepAlive;
    effectiveTcpConcurrent.value = effTcpConcurrent;
    effectiveUnifiedDelay.value = effUnifiedDelay;
    effectiveLogLevel.value = effLogLevel;
    effectiveKeepAliveInterval.value = effKeepAlive;
    rawConfig["port"] = 0;
    rawConfig["socks-port"] = 0;
    rawConfig["port"] = realPatchConfig.port;
    rawConfig["socks-port"] = realPatchConfig.socksPort;
    rawConfig["redir-port"] = realPatchConfig.redirPort;
    rawConfig["tproxy-port"] = realPatchConfig.tproxyPort;
    rawConfig["mode"] = realPatchConfig.mode.name;

    // Set network settings: use patchConfig if overriding, otherwise keep provider values
    if (config.appSetting.overrideNetworkSettings) {
      // User wants to override - use values from UI (always write)
      rawConfig["find-process-mode"] = realPatchConfig.findProcessMode.name;
      rawConfig["allow-lan"] = realPatchConfig.allowLan;
      rawConfig["ipv6"] = realPatchConfig.ipv6;
      rawConfig["mixed-port"] = realPatchConfig.mixedPort;
    } else {
      // Use provider values - only set if not already in rawConfig, use patchConfig values (which are synced from provider)
      if (rawConfig["find-process-mode"] == null) {
        rawConfig["find-process-mode"] = realPatchConfig.findProcessMode.name;
      }
      if (rawConfig["allow-lan"] == null) {
        rawConfig["allow-lan"] = realPatchConfig.allowLan;
      }
      if (rawConfig["ipv6"] == null) {
        rawConfig["ipv6"] = realPatchConfig.ipv6;
      }
      if (rawConfig["mixed-port"] == null) {
        rawConfig["mixed-port"] = realPatchConfig.mixedPort;
      }
    }

    // flclashx-androidsecure header: when set to "true" on Android, force
    // mixed-port = 0 so the HTTP/SOCKS inbound is disabled and traffic can
    // only leave through the VpnService/TUN. Applied as a final override
    // regardless of overrideNetworkSettings or UI-configured port, because
    // the header expresses an explicit policy from the subscription provider
    // that should not be overridable from the app side. No-op on other
    // platforms — desktop TUN gating is handled separately.
    if (Platform.isAndroid) {
      final secureHeader = profile.providerHeaders['flclashx-androidsecure']
          ?.trim()
          .toLowerCase();
      if (secureHeader == 'true') {
        rawConfig["mixed-port"] = 0;
      }
    }

    // Match Mihomo clients such as Koala: when the profile already supplies a
    // complete TUN section, preserve it as one coherent routing setup. Mixing
    // the profile's strict-route/auto-detect-interface with Delore's device,
    // DNS hijack and route list can produce a valid-looking configuration that
    // nevertheless drops DNS or selected destinations on Windows. The app
    // still owns the on/off switch; all other fields are replaced only when
    // the user explicitly enables network overrides or the profile has no TUN
    // section to preserve.
    rawConfig["tun"] = buildRuntimeTun(
      providerTun: rawConfig["tun"],
      patchTun: realPatchConfig.tun,
      enable: Platform.isAndroid ? true : realPatchConfig.tun.enable,
      overrideProvider: config.appSetting.overrideNetworkSettings,
    );
    rawConfig["geodata-loader"] = realPatchConfig.geodataLoader.name;
    if (rawConfig["sniffer"]?["sniff"] != null) {
      for (final value in (rawConfig["sniffer"]?["sniff"] as Map).values) {
        if (value["ports"] != null && value["ports"] is List) {
          value["ports"] =
              value["ports"]?.map((item) => item.toString()).toList() ?? [];
        }
      }
    }
    if (rawConfig["profile"] == null) {
      rawConfig["profile"] = {};
    }
    if (rawConfig["proxy-providers"] != null) {
      final proxyProviders = rawConfig["proxy-providers"] as Map;
      for (final key in proxyProviders.keys) {
        final proxyProvider = proxyProviders[key];
        if (proxyProvider["type"] != "http") {
          continue;
        }
        if (proxyProvider["url"] != null) {
          proxyProvider["path"] = await appPath.getProvidersFilePath(
            profile.id,
            "proxies",
            proxyProvider["url"],
          );
        }
      }
    }

    if (rawConfig["rule-providers"] != null) {
      final ruleProviders = rawConfig["rule-providers"] as Map;
      for (final key in ruleProviders.keys) {
        final ruleProvider = ruleProviders[key];
        if (ruleProvider["type"] != "http") {
          continue;
        }
        if (ruleProvider["url"] != null) {
          ruleProvider["path"] = await appPath.getProvidersFilePath(
            profile.id,
            "rules",
            ruleProvider["url"],
          );
        }
      }
    }

    rawConfig["profile"]["store-selected"] = false;

    final mergedGeoXUrl = <String, dynamic>{};
    final patchGeoX = realPatchConfig.geoXUrl.toJson();
    final profileGeoX = rawConfig["geox-url"];

    mergedGeoXUrl['geoip'] = patchGeoX['geoip'];
    mergedGeoXUrl['mmdb'] = patchGeoX['mmdb'];
    mergedGeoXUrl['asn'] = patchGeoX['asn'];
    mergedGeoXUrl['geosite'] = patchGeoX['geosite'];

    if (profileGeoX != null && profileGeoX is Map) {
      if (profileGeoX['geoip'] != null)
        mergedGeoXUrl['geoip'] = profileGeoX['geoip'];
      if (profileGeoX['mmdb'] != null)
        mergedGeoXUrl['mmdb'] = profileGeoX['mmdb'];
      if (profileGeoX['asn'] != null) mergedGeoXUrl['asn'] = profileGeoX['asn'];
      if (profileGeoX['geosite'] != null)
        mergedGeoXUrl['geosite'] = profileGeoX['geosite'];
    }

    rawConfig["geox-url"] = mergedGeoXUrl;
    rawConfig["global-ua"] = realPatchConfig.globalUa;
    if (rawConfig["hosts"] == null) {
      rawConfig["hosts"] = {};
    }
    for (final host in realPatchConfig.hosts.entries) {
      rawConfig["hosts"][host.key] = host.value.splitByMultipleSeparators;
    }
    if (rawConfig["dns"] == null) {
      rawConfig["dns"] = {};
    }
    final isEnableDns = rawConfig["dns"]["enable"] == true;
    final overrideDns = globalState.config.overrideDns;
    if (overrideDns || !isEnableDns) {
      final dns = switch (!isEnableDns) {
        true => realPatchConfig.dns.copyWith(
            nameserver: [...realPatchConfig.dns.nameserver, "system://"]),
        false => realPatchConfig.dns,
      };
      rawConfig["dns"] = dns.toJson();
      rawConfig["dns"]["nameserver-policy"] = {};
      for (final entry in dns.nameserverPolicy.entries) {
        rawConfig["dns"]["nameserver-policy"][entry.key] =
            entry.value.splitByMultipleSeparators;
      }
    }
    var rules = [];
    if (rawConfig["rules"] != null) {
      rules = rawConfig["rules"];
    }
    rawConfig.remove("rules");

    final overrideData = profile.overrideData;
    if (overrideData.enable && config.scriptProps.currentScript == null) {
      if (overrideData.rule.type == OverrideRuleType.override) {
        rules = overrideData.runningRule;
      } else {
        rules = [...overrideData.runningRule, ...rules];
      }
    }
    // Visual per-application routing always has the highest rule priority and
    // lives outside subscription YAML/override rules.
    final applicationRules =
        await ApplicationRoutingStore.clashRules(profile.id);
    if (applicationRules.isNotEmpty) {
      // PROCESS-PATH rules are inert when process discovery is disabled by a
      // provider profile. A visual route must never look applied while the core
      // is unable to resolve its process.
      rawConfig["find-process-mode"] = FindProcessMode.always.name;
    }
    // Visual per-site routing goes ahead of per-application routing: Clash
    // rules match top-to-bottom and stop at the first hit, so a DOMAIN-SUFFIX
    // pin for youtube.com has to be checked before a PROCESS-PATH catch-all
    // for the browser that opened it — otherwise the app rule matches every
    // destination from that process first and the site pin never fires.
    final domainRules = await DomainRoutingStore.clashRules(profile.id);
    final routingPlan = buildVisualRoutingPlan(
      requestedMode: realPatchConfig.mode.name,
      domainRules: domainRules,
      applicationRules: applicationRules,
      providerRules: List<dynamic>.from(rules),
    );
    // Native global mode never enters Mihomo's rule engine. When the user has
    // visual site/app exceptions, keep the UI in Global but run the core in
    // rule mode with MATCH,GLOBAL as the final fallback.
    rawConfig["mode"] = routingPlan.coreMode;
    rawConfig["rule"] = routingPlan.rules;
    return rawConfig;
  }

  Future<Map<String, dynamic>> getProfileConfig(String profileId) async {
    final configMap = await clashCore.getConfig(profileId);
    configMap["rules"] = configMap["rule"];
    configMap.remove("rule");
    return configMap;
  }

  Future<Map<String, dynamic>> handleEvaluate(
    Map<String, dynamic> config,
  ) async {
    final currentScript = globalState.config.scriptProps.currentScript;
    if (currentScript == null) {
      return config;
    }
    if (config["proxy-providers"] == null) {
      config["proxy-providers"] = {};
    }
    final configJs = json.encode(config);
    // Dispose the runtime every time: handleEvaluate runs on each applyProfile
    // (twice+ per apply), and a leaked QuickJS runtime grows native heap (RSS),
    // which makes aggressive OEMs kill the process sooner.
    final runtime = getJavascriptRuntime();
    try {
      final res = await runtime.evaluateAsync("""
        ${currentScript.content}
        main($configJs)
      """);
      if (res.isError) {
        throw res.stringResult;
      }
      final value = switch (res.rawResult is Pointer) {
        true => runtime.convertValue<Map<String, dynamic>>(res),
        false => Map<String, dynamic>.from(res.rawResult),
      };
      return value ?? config;
    } finally {
      runtime.dispose();
    }
  }
}

final globalState = GlobalState();

class DetectionState {
  factory DetectionState() {
    _instance ??= DetectionState._internal();
    return _instance!;
  }

  DetectionState._internal();
  static DetectionState? _instance;
  bool? _preIsStart;
  Timer? _setTimeoutTimer;
  CancelToken? cancelToken;
  DateTime? _lastManualCheck;

  final state = ValueNotifier<NetworkDetectionState>(
    const NetworkDetectionState(
      isTesting: false,
      isLoading: true,
      ipInfo: null,
    ),
  );

  void startCheck() {
    debouncer.call(
      FunctionTag.checkIp,
      _checkIp,
      duration: const Duration(
        milliseconds: 1200,
      ),
    );
  }

  bool forceCheck() {
    if (_lastManualCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastManualCheck!);
      if (timeSinceLastCheck.inSeconds < 15) {
        return false;
      }
    }
    _lastManualCheck = DateTime.now();
    _checkIp();
    return true;
  }

  /// Drop any stale exit-IP immediately (e.g. the instant the tunnel starts) so the
  /// UI shows the "determining" state right away instead of flashing the previous IP
  /// during the ~1.2s debounce before the next [_checkIp] runs.
  void markChecking() {
    _clearSetTimeoutTimer();
    state.value = state.value.copyWith(
      isLoading: true,
      isTesting: false,
      ipInfo: null,
    );
  }

  Future<void> _checkIp() async {
    final appState = globalState.appState;
    final isInit = appState.isInit;
    if (!isInit) return;
    final isStart = appState.runTime != null;
    if (_preIsStart == false &&
        _preIsStart == isStart &&
        state.value.ipInfo != null) {
      return;
    }
    final justStarted = _preIsStart == false && isStart;
    _clearSetTimeoutTimer();
    state.value = state.value.copyWith(
      isLoading: true,
      ipInfo: null,
    );
    _preIsStart = isStart;
    if (cancelToken != null) {
      cancelToken!.cancel();
      cancelToken = null;
    }
    if (justStarted) {
      await Future.delayed(const Duration(milliseconds: 2000));
    }
    cancelToken = CancelToken();
    state.value = state.value.copyWith(
      isTesting: true,
    );
    final res = await request.checkIp(cancelToken: cancelToken);
    if (res.isError) {
      state.value = state.value.copyWith(
        isLoading: true,
        ipInfo: null,
      );
      return;
    }
    final ipInfo = res.data;
    state.value = state.value.copyWith(
      isTesting: false,
    );
    if (ipInfo != null) {
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: ipInfo,
      );
      return;
    }
    _clearSetTimeoutTimer();
    _setTimeoutTimer = Timer(const Duration(milliseconds: 300), () {
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: null,
      );
    });
  }

  void _clearSetTimeoutTimer() {
    if (_setTimeoutTimer != null) {
      _setTimeoutTimer?.cancel();
      _setTimeoutTimer = null;
    }
  }
}

final detectionState = DetectionState();
