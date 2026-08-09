## v0.5.6

**A more deliberate Delore**

* Rebuilt the interface hierarchy around one clear primary action: Connect now leads the dashboard, while profile and live statistics stay available without competing for attention
* Unified the dark appearance around true black, white and restrained graphite; removed the remaining grey wash and coloured glass tints
* Refined both compact and expanded layouts so the same controls, spacing and visual hierarchy survive window resizing
* Standardized navigation, selectors, sheets and status surfaces around the same restrained Liquid Glass language

**Motion and navigation**

* Replaced fixed selection curves with an interruptible, critically damped navigation spring that continues from its current on-screen position
* Fixed the selection lens getting stuck after repeated navigation and corrected several animation lifecycle crashes
* Normalized navigation icons to one outlined family and removed redundant tooltips from already-labelled controls
* Navigation order remains customizable by drag and drop in both expanded and collapsed desktop modes
* Restored immediate press feedback and added clear progress feedback while Delore is connecting
* Respects Reduce Motion throughout the redesigned interface without removing useful state feedback

**Applications and browser routing**

* Simplified Applications to two distinct workspaces: native applications and live browser tabs; removed the duplicate Sites tab
* Reworked the Browser Bridge empty state into a compact setup flow with direct Chromium-family and Firefox actions
* Added one consistent monochrome loading and empty-state design to Applications, Browser, Active Connections and Connection Log
* Application details now expand with a single smooth size transition instead of overlapping cross-fades
* Windows executable icons are extracted on a worker isolate, keeping navigation and scrolling responsive while real icons arrive progressively

**Performance and stability**

* Heavy pages are warmed after the first frame and retained in memory, avoiding page construction on the first navigation click
* Hidden cached pages are kept strictly offstage, fixing the startup flash where several screens could briefly appear at once
* Preserved full-rate live Liquid Glass on the desktop dashboard while avoiding unnecessary rebuilds in navigation state
* Isolated cached pages with repaint and ticker boundaries so inactive screens do not animate or repaint in the background
* Fixed four unsafe MediaQuery lifecycle reads that could crash during navigation or window changes
* Pinned release builders to verified SDK revisions: stable Flutter 3.44.9 for standard targets and the last successful ARM snapshot for native Windows and Linux ARM64 builds

**Polish and fixes**

* Redesigned the dashboard profile switcher, its menu, the bottom statistics strip and add-profile sheet to use the shared black-glass system
* Fixed the profile switcher chevron pointing in the wrong direction when its menu opens upward
* Fixed compact connect-bar spacing and the bottom navigation keeping Home highlighted while Settings was open
* Localized Route Doctor and IP-address validation messages that previously remained in English
* Improved accessibility labels for icon-only and overflow controls

## v0.5.5

**Dashboard**

* The dashboard's stat cards, connect bar and profile switcher now use the sidebar's real refracting glass instead of a flat frosted card — desktop only, mobile keeps the cheaper look
* Fixed the connect bar losing its bottom-nav-aware padding when it moved to the chrome layer, which could sit it under the mobile navigation bar
* Added a visible edge to the stat cards, connect bar and profile switcher: the sidebar's glass is tuned nearly invisible against rich map detail, which read as a flat panel over the map's emptier stretches (e.g. under the connect bar)
* The compact stat row now fades at its trailing edge instead of clipping the last card flush against the window edge, so a card scrolled off-screen reads as "swipe for more" rather than missing

**Fixes**

* Fixed the Windows/macOS/Linux/Android build failing in CI: a reorderable-list API only available on newer Flutter than CI's pinned version had slipped in

## v0.5.4

**Interface and navigation**

* Reworked the shared dark interface around a neutral black, graphite and white Liquid Glass system, without the previous coloured tint
* Navigation glass now refracts the captured app backdrop on Windows, with restrained non-overshooting motion instead of jelly stretching
* The desktop sidebar keeps the same transparent material when expanded or collapsed; hover, pressed and selected states now follow the same capsule geometry
* Navigation items can be reordered by dragging in both the expanded and collapsed desktop sidebar and in the compact bottom bar; the chosen order is saved locally
* Updated the expanded and collapsed dashboard screenshots

**Interface fixes**

* Fixed a dashboard animation lifecycle crash when leaving the home screen
* Fixed Applications, Sites, Browser and empty connection labels in English and Russian
* Renamed the proxy selection page to Locations and corrected the default application route label to Rules
* Reduced Liquid Glass capture work outside the dashboard and enabled region capture to keep the effect responsive on Windows

**Browser Bridge**

* Added a live Browser tab next to Apps and Sites, showing the real title, domain, favicon, browser and active state of every open tab
* Added one-click routing for a browser tab's domain through Direct, the default proxy group or a specific location
* Added bundled Manifest V3 extensions for Chrome, Edge, Opera, Brave, Vivaldi and Firefox
* Browser pairing is automatic: the extension receives a private token directly from Delore over a loopback-only local service; browser data is not sent to a cloud service

**Safer subscriptions**

* Subscription files are now validated, written to a temporary file and replaced atomically, so an interrupted update cannot leave a half-written profile
* Delore keeps the five latest working revisions of every profile
* Added "Restore previous version" to the profile menu; restoring also keeps the current version in history, so the rollback itself can be undone

**Everyday routing**

* Added persistent favorites for applications, sites and proxy servers
* Favorite applications and sites stay above the rest of their lists and remain independent from subscription YAML

**Route Doctor**

* Added a Route Doctor screen to Settings that checks the active profile, Mihomo validation, core control channel, DNS and the real network exit
* Application Settings now show how many values differ from defaults and can reset only those preferences without deleting profiles or routing rules

## v0.5.3

**Site routing**

* Added a "Sites" tab on the Applications page: pin a domain (e.g. `youtube.com`) to a specific location or Direct, independent of which app opens it — a site pin now takes priority over an app's own routing, so it can carve out an exception even inside an app that's already pinned elsewhere
* The Applications page is now Apps/Sites, matching the Active/Log switch on Connections
* Each pinned site shows its real favicon instead of a generic globe

**Fixes**

* Fixed Global mode sending traffic out unproxied instead of through a server: switching to Global only pointed the UI at the GLOBAL group, it never selected a node inside it, so the core fell back to its own default (DIRECT) — with the tunnel up that's a routing loop and the whole system loses internet. Global now picks up whatever node Rules mode was already using, or the first real entry in GLOBAL
* Fixed every in-app notification (add-site errors, undo toasts, "no proxy group available", etc.) rendering squeezed into a single-character-wide column — its width was computed against the full window, but it renders inside the page's own 1680px-clamped content area, so on a wide window the two numbers didn't agree and the box came out barely wider than the border
* Fixed notifications sometimes never disappearing on their own (most visibly deleting a pinned site) — the toast no longer leans on Flutter's own dismiss timer, which wasn't reliably arming, and now closes itself on a plain delay instead

## v0.5.2

**Home screen**

* The profile switcher and "add subscription" are back on the home screen — the map redesign left them in a branch that only renders when you have *no* profile, so with a profile there was no way to reach either without going to Profiles
* Fixed picking a profile from the switcher blanking the whole app: the menu popped the navigator, which took the page under it down too, leaving an empty window
* The profile name no longer eats the panel — it was set at headline size, and raw ids like `user_5675861882` filled the bar on their own
* The profile menu now lines up with the panel's edge and sits below it, instead of being centred on the name text
* Fixed the first row of "Add profile" (QR code) sitting clipped behind the sheet's title bar

*Correction to the v0.5.1 notes: they listed "Added a profile switcher on the home screen". That was wrong — the switcher had been unreachable since the dashboard was rebuilt around the map. It works as of this release.*

## v0.5.1

**Dashboard**

* Reworked the home screen around a live world map
* Added a traffic web — every app's destination becomes a node, threads are spun from your location out to each one, packets travel the threads
* Added app markers on the map: icon, process, destination host, country flag and live speed
* Added a live stats row: ping, speed, traffic and subscription
* Added a connect bar with the power control, uptime, server picker and connect/disconnect
* Ping is now measured for the active server instead of showing an empty value
* The map is now the backdrop of the whole app — sharp on the home screen, blurred behind every other page
* Removed the separate "Active apps" panel; the map markers cover it
* Removed the duplicated server card from the stats row

**Performance**

* Fixed mouse-wheel scrolling stalling on long lists (server list, connections, logs) — fast scrolls were restarting the animation on every tick
* Server groups no longer build every proxy card while collapsed — large subscriptions (200+ servers) open without the stall
* Fixed the map animation running about 300x slower than intended, which made every effect look frozen

**Fixes**

* App update checks pointed at the old upstream repository, so no Delore release was ever offered — fixed
* Fixed app markers never appearing on the map (country codes were compared in the wrong case)
* Fixed the connect bar collapsing into a narrow island instead of spanning the window
* Fixed the top stat cards being oversized and unevenly spaced
* Fixed page content sliding under the floating app bar — the Active/Log switch on Connections, the profile list, the server list, and the heading in every settings side panel
* Release notes on GitHub are now the hand-written changelog instead of a dump of every commit message

**Subscription links**

* Delore now claims the `clash://` and `clashmeta://` schemes on Windows — it only ever registered `clashx`, `flclash` and `flclashx`, so an "add subscription" link opened whichever other Clash client had taken `clash://`
* Added a `delore://` scheme on Windows, macOS and Android

**Naming**

* The Windows executable is now `Delore.exe` — it used to ship as `FlClashX.exe` with a window titled "RouteX", so Task Manager and Alt-Tab showed two old names
* Fixed the Linux `.deb` launcher doing nothing: the desktop entry pointed at `/opt/FlClashX/FlClashX` while the packaged binary was already named `Delore`
* The macOS bundle is now `Delore.app`
* Installer, MSIX display name, log files, VPN notification and the subscription page title all say Delore

**Interface**

* Sidebar order is now Home, Locations, Profiles, Applications, Connections, Settings
* The app bar's glass now visibly refracts and catches light
* Narrow windows scroll the stat cards and stack the connect bar instead of truncating labels

## v0.4.7

### Rebrand: Delore

- FlClashX is now **Delore** — new name, new logo and app icon on Windows, Android and Linux, updated Start Menu/desktop shortcuts.
- About page credits reorganized into three clear sections: real contributors, project credits (FlClash, mihomo, and the libraries this app is built on), and a separate section for AI development assistance.

### Design

- Locked the app to a true black liquid-glass look everywhere — removed accidental colour tints from accents and backgrounds.
- Redesigned the dashboard connect button: hover and press feedback, a proper on/off animation, and a pause icon instead of a stop square while connected.
- Per-app routing simplified: "Proxy" and "Rules" are now a single control; "Global" is reserved for the sidebar's actual Global mode switch.
- The per-app location picker now shows every individual server in a group, with country flags, instead of just the group name.
- Cleaned up the Applications and Profiles pages — removed redundant header text and stat blocks.
- Fixed the Connections page's Active/Log switch sitting too close to the top bar.
- Fixed a notification toast that could get stuck on screen after a route change.

### New feature

- Optional setting to update/download a subscription through the currently active proxy instead of always going direct (off by default).

### Android

- Fixed the app bar's glass blur looking soft on real phones, then fixed the performance hit that first fix introduced — the background is no longer re-captured more often than it needs to be, so scrolling stays smooth.

### Release builds

- Windows, macOS, Android and Linux builds are all back to building and publishing cleanly through CI.

## v0.4.0

### New home screen

- A new home screen look (enabled in theme settings or via a subscription header): service logo and name, a traffic & expiry card, an active-server panel with country flag, IP and ping, a large connect button and new bottom navigation.

- "Renew subscription" and "Buy more traffic" buttons — appear automatically when the plan is running out and the links are provided in the subscription headers.

- Rule/Global mode switch right on the home screen.

### Connections

- The page is fully reworked: "Active" and "Log" tabs in one place.

- Every connection shows the app icon, destination country flag, traffic and the proxy chain.

- Any connection can be closed individually; tapping the app icon filters by that app.

- zashboard button — the web control panel in one click.

### Android

- Noticeably lower background battery drain: the app no longer keeps the device awake, the notification was slimmed down, and background checks don't wake the phone while the screen is off.

- VPN reliability: autostart after reboot, Always-on VPN support, self-recovery after aggressive battery optimizers (MIUI, Samsung, etc.), reconnection on network change.

- Home screen widgets: a VPN toggle and a mode switcher.

- "Start" and "Stop" shortcuts on long-press of the app icon.

- Haptic feedback on the start/stop button.

- Smoother UI: fixed jank on Pixel devices, 120 Hz support.

- Send a subscription from any phone to a TV via QR — the code is now readable by a regular QR scanner.

### Windows / macOS / Linux

- Core updates right from the app: check, download with progress and install without restarting the app — on Windows it works even for Program Files installs, with no UAC prompts.

- If the core crashes, the app restarts it and restores the connection automatically.

- The tray icon now follows the system theme.

- macOS: fixed system DNS issues.

- Linux: native .deb, .rpm and AppImage packages; new Windows ARM and Linux ARM builds.

### Core & network

- Core updated to mihomo 1.19.28 — switched from a fork to the original core.

- Fresh browser TLS fingerprints (client-fingerprint: firefox / safari).

- Faster startup, instant ping of the active server, more accurate delay testing through the core.

- Switching and updating a profile on a running VPN — without restarting the tunnel.

- Config editor: syntax highlighting, search and line numbers.

### For providers

- Automatic subscription migration to a new domain — no profile reinstall needed.

- More customization via subscription headers: logo, service name, theme, background, payment buttons and more — full list at https://flclashx.app

## v0.8.86

- Fix windows tun issues

- Optimize android get system dns

- Optimize more details

- Update changelog

## v0.8.85

- Support override script

- Support proxies search

- Support svg display

- Optimize config persistence

- Add some scenes auto close connections

- Update core

- Optimize more details

## v0.8.84

- Fix windows service verify issues

- Update changelog

## v0.8.83

- Add windows server mode start process verify

- Add linux deb dependencies

- Add backup recovery strategy select

- Support custom text scaling

- Optimize the display of different text scale

- Optimize windows setup experience

- Optimize startTun performance

- Optimize android tv experience

- Optimize default option

- Optimize computed text size

- Optimize hyperOS freeform window

- Add developer mode

- Update core

- Optimize more details

- Add issues template

- Update changelog

## v0.8.82

- Optimize android vpn performance

- Add custom primary color and color scheme

- Add linux nad windows arm release

- Optimize requests and logs page

- Fix map input page delete issues

- Update changelog

## v0.8.81

- Add rule override

- Update core

- Optimize more details

- Update changelog

## v0.8.80

- Optimize dashboard performance

- Fix some issues

- Fix unselected proxy group delay issues

- Fix asn url issues

- Update changelog

## v0.8.79

- Fix tab delay view issues

- Fix tray action issues

- Fix get profile redirect client ua issues

- Fix proxy card delay view issues

- Add Russian, Japanese adaptation

- Fix some issues

- Update changelog

## v0.8.78

- Fix list form input view issues

- Fix traffic view issues

- Update changelog

## v0.8.77

- Optimize performance

- Update core

- Optimize core stability

- Fix linux tun authority check error

- Fix some issues

- Fix scroll physics error

- Update changelog

## v0.8.75

- Add windows storage corruption detection

- Fix core crash caused by windows resource manager restart

- Optimize logs, requests, access to pages

- Fix macos bypass domain issues

- Update changelog

## v0.8.74

- Fix some issues

- Update changelog

## v0.8.73

- Update popup menu

- Add file editor

- Fix android service issues

- Optimize desktop background performance

- Optimize android main process performance

- Optimize delay test

- Optimize vpn protect

- Update changelog

## v0.8.72

- Update core

- Fix some issues

- Update changelog

## v0.8.71

- Remake dashboard

- Optimize theme

- Optimize more details

- Update flutter version

- Update changelog

## v0.8.70

- Support better window position memory

- Add windows arm64 and linux arm64 build script

- Optimize some details

## v0.8.69

- Remake desktop

- Optimize change proxy

- Optimize network check

- Fix fallback issues

- Optimize lots of details

- Update change.yaml

- Fix android tile issues

- Fix windows tray issues

- Support setting bypassDomain

- Update flutter version

- Fix android service issues

- Fix macos dock exit button issues

- Add route address setting

- Optimize provider view

- Update changelog

- Update CHANGELOG.md

## v0.8.67

- Add android shortcuts

- Fix init params issues

- Fix dynamic color issues

- Optimize navigator animate

- Optimize window init

- Optimize fab

- Optimize save

## v0.8.66

- Fix the collapse issues

- Add fontFamily options

## v0.8.65

- Update core version

- Update flutter version

- Optimize ip check

- Optimize url-test

## v0.8.64

- Update release message

- Init auto gen changelog

- Fix windows tray issues

- Fix urltest issues

- Add auto changelog

- Fix windows admin auto launch issues

- Add android vpn options

- Support proxies icon configuration

- Optimize android immersion display

- Fix some issues

- Optimize ip detection

- Support android vpn ipv6 inbound switch

- Support log export

- Optimize more details

- Fix android system dns issues

- Optimize dns default option

- Fix some issues

- Update readme

## v0.8.60

- Fix build error2

- Fix build error

- Support desktop hotkey

- Support android ipv6 inbound

- Support android system dns

- fix some bugs

## v0.8.59

- Fix delete profile error

## v0.8.58

- Fix submit error 2

- Fix submit error

- Optimize DNS strategy

- Fix the problem that the tray is not displayed in some cases

- Optimize tray

- Update core

- Fix some error

## v0.8.57

- Fix tun update issues

- Add DNS override
- Fixed some bugs
- Optimize more detail

- Add Hosts override

## v0.8.56

- fix android tip error
- fix windows auto launch error

## v0.8.55

- Fix windows tray issues

- Optimize windows logic

- Optimize app logic

- Support windows administrator auto launch

- Support android close vpn

## v0.8.53

- Change flutter version

- Support profiles sort

- Support windows country flags display

- Optimize proxies page and profiles page columns

## v0.8.52

- Update flutter version

- Update version

- Update timeout time

- Update access control page

- Fix bug

## v0.8.51

- Optimize provider page

- Optimize delay test

- Support local backup and recovery

- Fix android tile service issues

## v0.8.49

- Fix linux core build error

- Add proxy-only traffic statistics

- Update core

- Optimize more details

- Merge pull request #140 from txyyh/main

- 添加自建 F-Droid 仓库相关 workflow
- Rename readme fingerprint

- Rename workflow deploy repo name

- Add download guide to README

- Add push release files to fdroid-repo

## v0.8.48

- Optimize proxies page

- Fix ua issues

- Optimize more details

## v0.8.47

- Fix windows build error

## v0.8.46

- Update app icon

- Fix desktop backup error

- Optimize request ua

- Change android icon

- Optimize dashboard

## v0.8.44

- Remove request validate certificate

- Sync core

## v0.8.43

- Fix windows error

## v0.8.42

- Fix setup.dart error

- Fix android system proxy not effective

- Add macos arm64

## v0.8.41

- Optimize proxies page

- Support mouse drag scroll

- Adjust desktop ui

- Revert "Fix android vpn issues"

- This reverts commit 891977408e6938e2acd74e9b9adb959c48c79988.

## v0.8.40

- Fix android vpn issues

- Fix android vpn issues

- Rollback partial modification

## v0.8.39

- Fix the problem that ui can't be synchronized when android vpn is occupied by an external

- Override default socksPort,port

## v0.8.38

- Fix fab issues

## v0.8.37

- Update version

- Fix the problem that vpn cannot be started in some cases

- Fix the problem that geodata url does not take effect

## v0.8.36

- Update ua

- Fix change outbound mode without check ip issues

- Separate android ui and vpn

- Fix url validate issues 2

- Add android hidden from the recent task

- Add geoip file

- Support modify geoData URL

## v0.8.35

- Fix url validate issues

- Fix check ip performance problem

- Optimize resources page

## v0.8.34

- Add ua selector

- Support modify test url

- Optimize android proxy

- Fix the error that async proxy provider could not selected the proxy

## v0.8.33

- Fix android proxy error

- Fix submit error

- Add windows tun

- Optimize android proxy

- Optimize change profile

- Update application ua

- Optimize delay test

## v0.8.32

- Fix android repeated request notification issues

## v0.8.31

- Fix memory overflow issues

## v0.8.30

- Optimize proxies expansion panel 2

- Fix android scan qrcode error

## v0.8.29

- Optimize proxies expansion panel

- Fix text error

## v0.8.28

- Optimize proxy

- Optimize delayed sorting performance

- Add expansion panel proxies page

- Support to adjust the proxy card size

- Support to adjust proxies columns number

- Fix autoRun show issues

- Fix Android 10 issues

- Optimize ip show

## v0.8.26

- Add intranet IP display

- Add connections page

- Add search in connections, requests

- Add keyword search in connections, requests, logs

- Add basic viewing editing capabilities

- Optimize update profile

## v0.8.25

- Update version

- Fix the problem of excessive memory usage in traffic usage.

- Add lightBlue theme color

- Fix start unable to update profile issues

- Fix flashback caused by process

## v0.8.23

- Add build version

- Optimize quick start

- Update system default option

## v0.8.22

- Update build.yml

- Fix android vpn close issues

- Add requests page

- Fix checkUpdate dark mode style error

- Fix quickStart error open app

- Add memory proxies tab index

- Support hidden group

- Optimize logs

- Fix externalController hot load error

## v0.8.21

- Add tcp concurrent switch

- Add system proxy switch

- Add geodata loader switch

- Add external controller switch

- Add auto gc on trim memory

- Fix android notification error

## v0.8.20

- Fix ipv6 error

- Fix android udp direct error

- Add ipv6 switch

- Add access all selected button

- Remove android low version splash

## v0.8.19

- Update version

- Add allowBypass

- Fix Android only pick .text file issues

## v0.8.18

- Fix search issues

## v0.8.17

- Fix LoadBalance, Relay load error

- Fix build.yml4

- Fix build.yml3

- Fix build.yml2

- Fix build.yml

- Add search function at access control

- Fix the issues with the profile add button to cover the edit button

- Adapt LoadBalance and Relay

- Add arm

- Fix android notification icon error

## v0.8.16

- Add one-click update all profiles
- Add expire show

## v0.8.15

- Temp remove tun mode

- Remove macos in workflow

- Change go version

## v0.8.14

- Update Version

- Fix tun unable to open

## v0.8.13

- Optimize delay test2

- Optimize delay test

- Add check ip

- add check ip request

## v0.8.12

- Fix the problem that the download of remote resources failed after GeodataMode was turned on, which caused the
  application to flash back.

- Fix edit profile error

- Fix quickStart change proxy error

- Fix core version

## v0.8.10

- Fix core version

## v0.8.9

- Update file_picker

- Add resources page

- Optimize more detail

- Add access selected sorted

- Fix notification duplicate creation issue

- Fix AccessControl click issue

## v0.8.7

- Fix Workflow

- Fix Linux unable to open

- Update README.md 3

- Create LICENSE
- Update README.md 2

- Update README.md

- Optimize workFlow

## v0.8.6

- optimize checkUpdate

## v0.8.5

- Fix submit error

## v0.8.4

- add WebDAV

- add Auto check updates

- Optimize more details

- optimize delayTest

## v0.8.2

- upgrade flutter version

## v0.8.1

- Update kernel
- Add import profile via QR code image

## v0.8.0

- Add compatibility mode and adapt clash scheme.

## v0.7.14

- update Version

- Reconstruction application proxy logic

## v0.7.13

- Fix Tab destroy error

## v0.7.12

- Optimize repeat healthcheck

## v0.7.11

- Optimize Direct mode ui

## v0.7.10

- Optimize Healthcheck

- Remove proxies position animation, improve performance
- Add Telegram Link

- Update healthcheck policy

- New Check URLTest

- Fix the problem of invalid auto-selection

## v0.7.8

- New Async UpdateConfig

- add changeProfileDebounce

- Update Workflow

- Fix ChangeProfile block

- Fix Release Message Error

## v0.7.7

- Update Selector 2

## v0.7.6

- Update Version

- Fix Proxies Select Error

## v0.7.5

- Fix the problem that the proxy group is empty in global mode.

- Fix the problem that the proxy group is empty in global mode.

## v0.7.4

- Add ProxyProvider2

## v0.7.3

- Add ProxyProvider

- Update Version

- Update ProxyGroup Sort

- Fix Android quickStart VpnService some problems

## v0.7.1

- Update version

- Set Android notification low importance

- Fix the issue that VpnService can't be closed correctly in special cases

- Fix the problem that TileService is not destroyed correctly in some cases

- Adjust tab animation defaults

- Add Telegram in README_zh_CN.md

- Add Telegram

## v0.7.0

- update mobile_scanner

- Initial commit
