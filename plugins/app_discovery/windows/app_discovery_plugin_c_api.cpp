#include "include/app_discovery/app_discovery_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "app_discovery_plugin.h"

void AppDiscoveryPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  AppDiscoveryPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
