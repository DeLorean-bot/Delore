#ifndef FLUTTER_PLUGIN_APP_DISCOVERY_PLUGIN_H_
#define FLUTTER_PLUGIN_APP_DISCOVERY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

class AppDiscoveryPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AppDiscoveryPlugin();
  ~AppDiscoveryPlugin() override;

  AppDiscoveryPlugin(const AppDiscoveryPlugin&) = delete;
  AppDiscoveryPlugin& operator=(const AppDiscoveryPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif
