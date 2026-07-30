<div align="center">

<img alt="Delore" src="assets/images/icon.png" width="132">

# Delore

### Route applications, not YAML files

[**Русский**](README.md)

[![Downloads](https://img.shields.io/github/downloads/DeLorean-bot/Delore/total?style=flat-square&logo=github&label=downloads)](https://github.com/DeLorean-bot/Delore/releases)
[![Latest release](https://img.shields.io/github/v/release/DeLorean-bot/Delore?style=flat-square&logo=github&label=release)](https://github.com/DeLorean-bot/Delore/releases/latest)
[![License](https://img.shields.io/badge/license-GPL--3.0-8b8b8b?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)
[![mihomo](https://img.shields.io/badge/core-mihomo-9b9b9b?style=flat-square)](https://github.com/MetaCubeX/mihomo)

An open-source, cross-platform client built on **FlClashX** and **mihomo**,<br>
with a dark interface and visual per-application traffic routing.

[Download](https://github.com/DeLorean-bot/Delore/releases/latest) ·
[Features](#features) ·
[Build](#build-from-source) ·
[Report an issue](https://github.com/DeLorean-bot/Delore/issues)

</div>

> [!WARNING]
> Delore is under active development. The core networking features are inherited from FlClashX, while the new interface and application routing are still evolving. Back up important profiles before updating.

## What is Delore?

Delore turns a traditional Clash client into a tool that is easier to understand. Instead of editing rules manually, you can open the list of running applications, inspect their network activity, and choose **Proxy**, **Direct**, or a specific location.

The project is based on [FlClashX](https://github.com/pluralplay/FlClashX), which extends [FlClash](https://github.com/chen08209/FlClash), and uses the [mihomo](https://github.com/MetaCubeX/mihomo) core. Delore keeps profiles, subscriptions, TUN, system proxy, rules, and providers compatible while building its own experience on top.

## Interface

### Home — expanded sidebar

<img alt="Delore dashboard with the expanded sidebar" src="snapshots/delore-dashboard-expanded.png">

<details>
<summary><strong>Home — compact sidebar</strong></summary>

<br>
<img alt="Delore dashboard with the collapsed sidebar" src="snapshots/delore-dashboard-collapsed.png">

</details>

### Applications and routes

<img alt="Per-application routing in Delore" src="snapshots/delore-applications.png">

## Features

| Feature | What it provides |
|---|---|
| **Application routing** | A live list of open Windows applications with real icons, PID, executable, window title, network activity, and Proxy/Direct controls |
| **Location per application** | Route an application through the general proxy or a specific group/location |
| **Focused dashboard** | Connection, profile, remaining traffic, expiration, and speed on one screen |
| **Dark design system** | Monochrome interface, glass surfaces, adaptive sidebar, and restrained motion |
| **Profiles and subscriptions** | Import from URL, QR code, or file; auto-update; update through the active proxy |
| **Operating modes** | TUN, system proxy, Rules, Global, and Direct |
| **Diagnostics** | Connections, logs, latency checks, traffic, and an embedded control panel |
| **Provider integrations** | Subscription headers, widgets, announcements, support links, and service branding |

> [!NOTE]
> Process discovery and per-application routing are currently available on Windows. The remaining client features work on supported platforms within the capabilities inherited from FlClashX.

## Download

Tagging a release automatically creates installers for the platforms that are actually supported.

| OS | Download |
|---|---|
| **Android** | [Universal APK](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-android-universal.apk) · [ARM64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-android-arm64-v8a.apk) · [ARMv7](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-android-armeabi-v7a.apk) · [x86_64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-android-x86_64.apk) |
| **Windows** | [Setup x64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-windows-amd64-setup.exe) · [Portable x64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-windows-amd64.zip) · [Setup ARM64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-windows-arm64-setup.exe) · [Portable ARM64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-windows-arm64.zip) |
| **macOS** | [Apple Silicon](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-macos-arm64.dmg) · [Intel](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-macos-amd64.dmg) |
| **Linux** | [AppImage x64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-linux-amd64.AppImage) · [DEB x64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-linux-amd64.deb) · [RPM x64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-linux-amd64.rpm) · [DEB ARM64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-linux-arm64.deb) · [RPM ARM64](https://github.com/DeLorean-bot/Delore/releases/latest/download/Delore-linux-arm64.rpm) |
| **iOS / iPadOS** | **Planned.** The current project tree has no iOS target yet, so a ready-to-install `.ipa` is not published |

If a direct link is not available yet, open the [complete releases page](https://github.com/DeLorean-bot/Delore/releases).

## Platform support

| Feature | Windows | Android | macOS | Linux | iOS |
|---|:---:|:---:|:---:|:---:|:---:|
| Profiles, subscriptions, and rules | ✅ | ✅ | ✅ | ✅ | 🚧 |
| TUN / VPN mode | ✅ | ✅ | ✅ | ✅ | 🚧 |
| System proxy | ✅ | — | ✅ | ✅ | — |
| Android TV and 120 Hz | — | ✅ | — | — | — |
| Native status bar | — | — | ✅ | — | — |
| Process discovery and app routing | ✅ | — | — | — | 🚧 |

## Quick start

1. Download the right package from the [latest release](https://github.com/DeLorean-bot/Delore/releases/latest).
2. Install Delore or unpack the portable build.
3. Add a subscription using a URL, QR code, or file.
4. Select a profile and start the connection.
5. On Windows, open **Applications** and assign Proxy or Direct to the programs you need.

## Build from source

You need Flutter 3.41.x, Dart 3.5 or newer, Git, and the toolchain for your target platform.

```bash
git clone https://github.com/DeLorean-bot/Delore.git
cd Delore
flutter pub get
```

Run locally:

```bash
flutter run
```

Example Windows release build:

```bash
flutter build windows --release
```

The complete release pipeline starts on tags such as `v0.4.3` and builds Android, Windows, macOS, and Linux with GitHub Actions.

## Subscription integration

Delore keeps technical compatibility with the existing FlClashX headers. Their names intentionally remain unchanged so existing provider panels continue to work.

<details>
<summary><strong>Main provider headers</strong></summary>

| Header | Purpose |
|---|---|
| `flclashx-widgets` | Dashboard widget order |
| `flclashx-view` | Dashboard layout |
| `flclashx-background` | Interface background |
| `flclashx-servicename` | Service name |
| `flclashx-servicelogo` | Service logo |
| `flclashx-override` | Remote override configuration |
| `flclashx-globalmode` | Available proxy modes |
| `flclashx-buyplan` | Subscription purchase link |
| `flclashx-buytraffic` | Traffic purchase link |

</details>

## Contributing

Bug reports, UX ideas, translations, and pull requests are welcome:

- [report a bug](https://github.com/DeLorean-bot/Delore/issues/new);
- [request a feature](https://github.com/DeLorean-bot/Delore/issues);
- run `flutter analyze` before submitting code.

Never publish private subscription URLs, keys, tokens, or configurations containing secrets in an issue.

## Credits

- [FlClashX](https://github.com/pluralplay/FlClashX) — the direct technical base;
- [FlClash](https://github.com/chen08209/FlClash) — the original cross-platform client;
- [mihomo](https://github.com/MetaCubeX/mihomo) — the networking core;
- [liquid_glass_easy](https://github.com/AhmeedGamil/liquid_glass_easy) — shader-driven glass materials.

## License

Delore is distributed under the [GNU General Public License v3.0](LICENSE). The history and attribution of upstream projects are preserved.
