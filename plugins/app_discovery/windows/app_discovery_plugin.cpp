#include "app_discovery_plugin.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <algorithm>
#include <cwctype>
#include <set>
#include <string>
#include <vector>

namespace {

struct OpenApplication {
  DWORD pid;
  std::wstring name;
  std::wstring executable_path;
  std::wstring window_title;
};

std::string Utf8FromWide(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), size,
                      nullptr, nullptr);
  return result;
}

std::wstring ExecutableName(const std::wstring& path) {
  const auto slash = path.find_last_of(L"\\/");
  std::wstring name =
      slash == std::wstring::npos ? path : path.substr(slash + 1);
  const auto extension = name.find_last_of(L'.');
  if (extension != std::wstring::npos) name.resize(extension);
  return name;
}

BOOL CALLBACK EnumApplicationWindows(HWND window, LPARAM parameter) {
  auto* applications =
      reinterpret_cast<std::vector<OpenApplication>*>(parameter);

  if (!IsWindowVisible(window) || GetWindow(window, GW_OWNER) != nullptr) {
    return TRUE;
  }

  const int title_length = GetWindowTextLengthW(window);
  if (title_length <= 0) return TRUE;

  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  if (pid == 0 || pid == GetCurrentProcessId()) return TRUE;

  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) return TRUE;

  std::vector<wchar_t> path_buffer(32768);
  DWORD path_size = static_cast<DWORD>(path_buffer.size());
  const BOOL has_path = QueryFullProcessImageNameW(
      process, 0, path_buffer.data(), &path_size);
  CloseHandle(process);
  if (!has_path || path_size == 0) return TRUE;

  std::vector<wchar_t> title_buffer(title_length + 1);
  GetWindowTextW(window, title_buffer.data(),
                 static_cast<int>(title_buffer.size()));

  const std::wstring path(path_buffer.data(), path_size);
  applications->push_back(
      {pid, ExecutableName(path), path, std::wstring(title_buffer.data())});
  return TRUE;
}

flutter::EncodableList GetOpenApplications() {
  std::vector<OpenApplication> applications;
  EnumWindows(EnumApplicationWindows,
              reinterpret_cast<LPARAM>(&applications));

  std::sort(applications.begin(), applications.end(),
            [](const OpenApplication& left, const OpenApplication& right) {
              std::wstring a = left.name;
              std::wstring b = right.name;
              std::transform(a.begin(), a.end(), a.begin(),
                             [](wchar_t value) { return std::towlower(value); });
              std::transform(b.begin(), b.end(), b.begin(),
                             [](wchar_t value) { return std::towlower(value); });
              return a < b;
            });

  std::set<DWORD> seen_pids;
  flutter::EncodableList result;
  for (const auto& app : applications) {
    if (!seen_pids.insert(app.pid).second) continue;
    result.push_back(flutter::EncodableMap{
        {flutter::EncodableValue("pid"),
         flutter::EncodableValue(static_cast<int>(app.pid))},
        {flutter::EncodableValue("name"),
         flutter::EncodableValue(Utf8FromWide(app.name))},
        {flutter::EncodableValue("executablePath"),
         flutter::EncodableValue(Utf8FromWide(app.executable_path))},
        {flutter::EncodableValue("windowTitle"),
         flutter::EncodableValue(Utf8FromWide(app.window_title))},
    });
  }
  return result;
}

}  // namespace

void AppDiscoveryPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flclashx/app_discovery",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AppDiscoveryPlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

AppDiscoveryPlugin::AppDiscoveryPlugin() = default;
AppDiscoveryPlugin::~AppDiscoveryPlugin() = default;

void AppDiscoveryPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "getOpenApplications") {
    result->Success(flutter::EncodableValue(GetOpenApplications()));
    return;
  }
  result->NotImplemented();
}
