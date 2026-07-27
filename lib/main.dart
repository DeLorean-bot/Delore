import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/plugins/app.dart';
import 'package:flclashx/plugins/tile.dart';
import 'package:flclashx/plugins/vpn.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'models/core.dart' as core_models show Action;
import 'models/models.dart';
import 'pages/editor_window.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // desktop_multi_window re-launches this binary for each sub-window with
  // ['multi_window', <id>, <jsonArgs>]. On macOS we use one for the roomy
  // config editor — boot only it, none of the normal app (core/state/UI).
  if (args.isNotEmpty && args.first == 'multi_window') {
    await runEditorSubWindow(args);
    return;
  }

  if (Platform.isWindows || Platform.isLinux) {
    DartPluginRegistrant.ensureInitialized();
  }

  final version = await system.version;
  await clashCore.preload();
  await globalState.initApp(version);
  await android?.init();
  await window?.init(version);

  if (Platform.isAndroid) {
    // Accessing the singletons wires up method channel handlers.
    vpn;
    _wireAndroidTileListener();
    unawaited(
      clashLib?.setCrashlytics(globalState.config.appSetting.crashlytics),
    );
  }

  HttpOverrides.global = FlClashHttpOverrides();
  runApp(const ProviderScope(
    child: Application(),
  ));
}

/// Handles start/stop/mode intents coming from the quick-settings tile or the
/// home-screen widget. Runs entirely in the main Flutter isolate now that the
/// `:remote` process hosts the Go core and the foreground service.
void _wireAndroidTileListener() {
  tile?.addListener(_MainTileListener());
  // Signal readiness so Kotlin can replay a pending START/STOP/CHANGE that
  // was queued while the Flutter engine was still booting (e.g. cold-start
  // from Always-on or a widget tap with no running UI).
  unawaited(tile?.signalServiceReady());
}

/// Boot-safe tile/widget handler. The UI's TileManager is ALSO registered as a
/// listener, and both fire for every native tile event — which previously ran
/// every start/stop twice. To run exactly one handler, this listener defers to
/// TileManager once the app is ready (it updates the UI run-state via
/// updateStatus), and only handles events itself during the cold-start window
/// before appController exists (TileManager.updateStatus would NPE there).
class _MainTileListener with TileListener {
  @override
  void onStart() {
    if (globalState.isAppControllerReady) return;
    unawaited(_handleStart());
  }

  @override
  void onStop() {
    if (globalState.isAppControllerReady) return;
    unawaited(_handleStop());
  }

  @override
  void onChangeMode(String mode) {
    if (globalState.isAppControllerReady) return;
    unawaited(_handleChangeMode(mode));
  }
}

Future<void> _handleStart() async {
  try {
    unawaited(app?.tip(appLocalizations.startVpn));

    final profileId = globalState.config.currentProfileId;
    if (profileId == null) {
      unawaited(app?.tip("No profile selected"));
      return;
    }

    // Wait for _initCore to finish — it runs in addPostFrameCallback
    // concurrently with this handler. Starting VPN before core is ready
    // causes concurrent Go map access → SIGABRT.
    for (var i = 0; i < 30; i++) {
      if (await clashCore.isInit) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final profile = globalState.config.currentProfile;
    final title = _buildNotificationTitle(profile);
    unawaited(clashLib?.updateNotificationParams(title: title));

    final rt = await clashLib?.startVpn() ?? 0;
    if (rt == 0) {
      commonPrint.log("Tile start: startVpn returned 0");
      unawaited(app?.tip("VPN start failed"));
      return;
    }

    await clashCore.startListener();
  } catch (e, stackTrace) {
    commonPrint.log("Tile onStart error: $e\n$stackTrace");
    unawaited(app?.tip("Start error: $e"));
  }
}

String _buildNotificationTitle(Profile? profile) {
  if (profile == null) return 'FlClashX';
  final profileName = profile.label ?? profile.id;

  String serviceName = '';
  final svc = profile.providerHeaders['flclashx-servicename'];
  if (svc != null && svc.isNotEmpty) {
    try {
      final normalized = base64.normalize(svc);
      serviceName = utf8.decode(base64.decode(normalized)).trim();
    } catch (_) {
      serviceName = svc.trim();
    }
  }

  return serviceName.isNotEmpty ? serviceName : profileName;
}

Future<void> _handleStop() async {
  try {
    unawaited(app?.tip(appLocalizations.stopVpn));
    // Cold-start window: appController doesn't exist yet, so go straight to the
    // native stop primitive (stopListener + stopVpn). Routing through
    // appController.updateStatus(false) NPEs on the null appController and the
    // stop is silently swallowed by the catch — i.e. a headless VPN can't be
    // stopped from the tile until Flutter finishes init. UI run-state reconciles
    // on the later resume/sync.
    await globalState.handleStop();
  } catch (e) {
    commonPrint.log("Tile onStop error: $e");
  }
}

Future<void> _handleChangeMode(String mode) async {
  try {
    final modeEnum = Mode.values.byName(mode);
    final patched = globalState.config.patchClashConfig.copyWith(
      mode: modeEnum,
    );
    globalState.config = globalState.config.copyWith(
      patchClashConfig: patched,
    );
    await preferences.saveConfig(globalState.config);

    final updateParamsMap = UpdateParams(
      tun: patched.tun.getRealTun(globalState.config.networkProps.routeMode),
      allowLan: patched.allowLan,
      findProcessMode: patched.findProcessMode,
      mode: modeEnum,
      logLevel: patched.logLevel,
      ipv6: patched.ipv6,
      tcpConcurrent: patched.tcpConcurrent,
      externalController: patched.externalController,
      unifiedDelay: patched.unifiedDelay,
      mixedPort: patched.mixedPort,
    ).toJson();

    final effective = globalState.effectiveExternalController.value;
    if (effective.isNotEmpty) {
      updateParamsMap['external-controller'] = effective;
    }

    final actionJson = json.encode(
      core_models.Action(
        id: "${ActionMethod.updateConfig.name}#${utils.id}",
        method: ActionMethod.updateConfig,
        data: json.encode(updateParamsMap),
      ),
    );
    unawaited(clashLib?.sendMessage(actionJson));
    unawaited(tile?.updateMode(mode));
  } catch (e) {
    commonPrint.log("Tile onChangeMode error: $e");
  }
}
