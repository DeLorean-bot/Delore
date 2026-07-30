## v0.4.7

- Grant the changelog job write permission on contents

- The repo's default GITHUB_TOKEN is read-only, so `git push` from the
- changelog job was rejected with 403 even after the branch-ref fix. The
- upload job already declares permissions: contents: write for the same
- reason (it publishes the release) — changelog needed the same override
- to push its CHANGELOG.md commit.

- Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

## v0.4.6

- Fix changelog job checking out a nonexistent main branch

- The changelog job's checkout step hardcoded refs/heads/main, but this
- repo only ever had master — the job failed at checkout every run
- (unrelated to any of the actual platform builds, which all pass now).

- Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

## v0.4.5

- Bump version to 0.4.5 to retrigger CI with the Windows fix

- Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

- Fix Windows build: EnableLoopback.exe was excluded by *.exe gitignore rule

- Found the real cmake error via the new -v flutter build flag: "file INSTALL
- cannot find windows/EnableLoopback.exe". The blanket *.exe rule in
- .gitignore had silently kept this prebuilt tool (installed directly by
- windows/CMakeLists.txt, not build output) out of every commit, so it only
- ever existed on machines that had it lying around locally. The previous
- commit's Defender/verbose changes were reasonable CI hardening but not
- the actual fix — this is.

- Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

## v0.4.4

- Fix Windows/macOS CI builds, Android app-bar blur resolution, and About page credits

- - CI: disable Windows Defender real-time scanning on windows runners and
-   add -v to flutter build windows, since the previous failures only ever
-   showed MSBuild's generic exit-code wrapper, never the actual
-   cmake_install.cmake error (root cause not conclusively identified;
-   Defender file-locking during the INSTALL step is the standard culprit
-   for this failure signature on GitHub-hosted Windows runners, and the
-   same build succeeds locally on this machine).
- - setup.dart: create-dmg now checks for a real codesigning identity via
-   `security find-identity` and passes --no-code-sign when none exists,
-   instead of hard-failing (macOS CI app itself already built fine; only
-   the unsigned DMG step was crashing).
- - scaffold.dart: LiquidGlassView's capture pixelRatio was clamped to 2.0
-   across every platform. Real Android phones commonly report 2.6-4.0,
-   so the app bar's live glass capture was upscaled from an
-   under-resolved source specifically on mobile. Desktop keeps the 2.0
-   cap; Android/iOS now go up to 4.0.
- - about.dart: split the old mixed Contributors list into three sections
-   — Contributors (real commit authors from this repo's own git history),
-   Credits (FlClash/FlClashX/mihomo and the libraries this app is built
-   on), and a separate Development assistance block for the AI tools used
-   during development, so they aren't presented as GitHub contributors.

- Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

## v0.4.3

- Enable AGP builtin-Kotlin/newDsl migrator flags for local Android SDK build

- Flutter's Gradle migrator added these automatically the first time this
- machine built the app after the Android SDK was installed locally.

- Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

- Rebrand FlClashX as Delore and publish project

- Fix the blur-bleed ghosting, an app-bar overflow, and a missing space

- Three real bugs from live feedback, verified fixed on the running build.

- 1. Any glass bar's content sat flush against the app bar's bottom edge
-    with zero gap. A Gaussian blur samples a region wider than its own
-    bounds to blur pixels at its own edge — sigma 12 (navigation) bleeds
-    roughly 2-3x that past the edge — so the first line of page content
-    was dragged up into the bar and read as ghosted, doubled text on
-    every page (Прокси, Профили, Приложения, and any AdaptiveSheetScaffold
-    dialog). Confirmed via the Flutter SDK's own Scaffold source
-    (_BodyBuilder) that extendBodyBehindAppBar already injects the app
-    bar's real height into the body's MediaQuery.padding.top — the layout
-    was correct, there was just no breathing room for the blur to fall
-    off in. SafeArea now takes `minimum: EdgeInsets.only(top: 18)` on top
-    of Scaffold's own inset.

- 2. A second, separate cause of the same symptom: AdaptiveSheetScaffold
-    passes its own AppBar (default 56px) into CommonScaffold's `appBar:`
-    slot. The previous "trim the app bar" pass sized the glass card to a
-    flat 52px regardless of what it was asked to wrap, so any
-    caller-supplied AppBar taller than that overflowed onto the content
-    below it. The card height is now `widget.appBar?.preferredSize.height`
-    when supplied, falling back to our own tuned 52px only when it's null.

- 3. "ДобавитьПрофиль", no space — string concatenation
-    ("${appLocalizations.add}${appLocalizations.profile}") instead of the
-    existing combined `addProfile` localization key, copied from
-    profiles.dart into two new call sites this session. All three now use
-    the proper key.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Switch dark-mode glass tint from white frost to black smoke

- Every dark-mode tint was a white overlay at low alpha — a light haze
- laid over the refracted content. That reads as grey wash no matter how
- low the alpha goes, because white-over-dark always lightens toward
- grey; it never reads as the rich near-black iOS dark glass is. The fix
- is the opposite overlay colour, not a different alpha: a black tint
- smokes/darkens what it refracts instead of frosting it, so the surface
- itself stays dark and the rim light is the only bright thing on it —
- which is what actually reads as glass rather than frost.

- navigation 0x24FFFFFF -> 0x40000000, panel 0x14 -> 0x30000000,
- dialog 0x22 -> 0x50000000, control 0x16 -> 0x38000000. selection keeps
- a (reduced) white lift — it's the one surface meant to look brighter
- than its surroundings, so a black tint there would make the selected
- pill recede instead of stand out. Light theme untouched.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Turn the connect control into one circle, split the collapsed mode toggle, trim the app bar

- Three follow-ups from live feedback on the previous pass.

- _HeroStatusBadge (decorative) and _ConnectButton (the pill, action) were
- still two separate elements standing for one fact — the redesign that
- was asked for landed as a resize, not a different design. Replaced both
- with _ConnectCircle: one 124px circle that is both the state readout and
- the tap target — a mint ring around a dark disc when stopped-and-ready,
- solid glowing mint with a stop glyph when running, flat and muted when
- not ready. Running state now also shows the live uptime and, new,
- live upload/download via the already-existing totalTrafficProvider
- (previously only wired into the dead _LegacyHeroConnect).

- The collapsed sidebar's Rules/Global control was a single icon that
- cycled between two modes on tap — you couldn't see which mode you'd land
- on without tapping first, and every other collapsed rail icon is its own
- destination, not a shared cycling slot. Now two stacked icon slots, one
- per mode, matching that pattern.

- _appBarHeight 64 -> 52: a glass card with a shadow, sized for a title and
- a couple of icon buttons, read as an oversized slab eating the top of
- every non-Dashboard page. The inner Material AppBar needed an explicit
- toolbarHeight (it defaults to 56, which no longer fit).

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Redesign the connect card, fix the churning-content blur, add a mode toggle

- Dashboard dedup, second pass (desktop layout). Section 19's compact-mode
- dedup only covered HeroConnect; the wide layout repeated running/stopped
- three times too (window title, a heading pill, a "Ядро" line). Dropped
- the pill and the line, kept the shield icon's tint as the one visual echo.

- HeroConnect header row: it showed "RouteX" as the profile's own branded
- name whenever the subscription carried no flclashx-servicename header —
- literally restating the app's own name, already in the window title.
- Replaced with a row of small icon actions instead: refresh this
- subscription (existing updateProfile), import another (the same
- AddProfileView sheet Profiles' own + button opens), and support (opens
- providerHeaders['support-url'] when present) — all previously wired only
- into the dead _LegacyHeroConnect. The tiny running/stopped chip is now a
- 72px glowing badge, the actual focal point instead of an afterthought.

- The floating app bar's blur was tuned (commit 6c93476) against a static
- capture. Once real content entered the capture, a page like Logs
- appending dense multi-line errors every few milliseconds, seen through a
- 5%-tint/16px-blur bar, reads as unintelligible smeared mush — reported
- as "a giant broken banner." Tint raised (0x0D -> 0x24) so there is less
- churn to blur away, blur eased (16 -> 12) since a denser tint needs less
- of it. The loading indicator pinned to the app bar's bottom edge was also
- the stock full-width square-cornered Material bar poking its corners out
- past the glass bar's own rounded edge; now a slim inset rounded mint
- strip.

- New: RouteXFocusableTap, promoted from hero_connect.dart's private
- _FocusableTap (needed in home.dart too; a private class can't cross
- files) to widgets/focusable_tap.dart, exported from widgets/widgets.dart.
- hero_connect.dart keeps a local `typedef _FocusableTap = RouteXFocusableTap`
- so its many call sites didn't need renaming.

- New: a persistent Rules/Global routing-mode switch pinned above the
- sidebar's collapse button — segmented control when expanded, a single
- tap-to-cycle icon when collapsed. Reuses changeMode/patchClashConfigProvider,
- the same calls the existing (dead-code-only) _ModeChip already made.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Make refraction renderer-aware, and investigate forcing Impeller

- Investigated whether Impeller can be forced on for a full liquid-glass
- material (lenses on content-plane cards too, no capture, no feedback-loop
- risk). It genuinely works on this machine — a Profile build launched with
- FLUTTER_ENGINE_SWITCHES confirms "Using the Impeller rendering backend
- (OpenGL)" — but the Release embedder (Flutter 3.44.8, Windows) ignores
- engine switches from both environment variables and argv by design; the
- env vars do reach the process (confirmed via Platform.environment) yet
- the renderer stays Skia regardless. There is no supported C++ API in
- this cpp_client_wrapper version to set switches directly either
- (FlutterDesktopEngineProperties has no such field). Forcing Impeller in
- a shipped build would require a custom-built flutter_windows.dll, which
- is out of scope here. Profile builds do work, but default to exposing a
- local Dart VM service diagnostic port, which is not something to ship on
- a proxy/VPN client.

- routeXGlassStyle's `refracts` now checks
- ImageFilter.isShaderFilterSupported at runtime: on Impeller (should a
- custom engine ever ship one) every variant refracts and content-plane
- lenses become safe; on Skia (every real release build today) only the
- chrome refracts, exactly as before. main.dart logs which path is active
- on startup instead of leaving it to be inferred from symptoms.

- Fix the blur properly: live capture, and no lens inside the capture

- Two faults, one behind the other.

- The capture was taken once per screen (realTimeCapture was tied to the
- Dashboard). While the capture held a static mesh that was free; now that
- it holds the page, the refraction was showing the first frame of a list
- still being scrolled while the blur — a separate BackdropFilterLayer —
- stayed live. Two sources drifting apart is what made the blur look
- broken. The capture is live on every screen now.

- That exposed the real fault: a lens *inside* the capture feeds back. It
- samples the ancestor view's capture and paints its output into the very
- image it will sample next frame, compounding until the surface burns out
- to a flat colour — the Dashboard card went solid green. Since the page
- moved into the capture, every content-plane surface is inside it.

- So only the chrome may refract. RouteXGlassVariant now says which
- variants do: navigation and selection, which live above the capture.
- panel, dialog and control render as frosted cards — a real backdrop blur
- plus tint and a hairline, which composites normally and cannot feed
- back. This is the rule the design system already stated: glass belongs
- on shell and elevation planes, not on the content plane.

- Also on the Dashboard: hover now lifts a control instead of doing
- nothing; the status chip and the Applications/Locations buttons are gone
- (the title bar already states the state and the bottom bar already goes
- to both destinations); and the connect button has a label, a stop state
- and a real transition between them rather than swapping a glyph.

- Let the page run under the bars

- The page was still being pushed clear of the chrome: the ghost nav sits
- in the Scaffold's bottomNavigationBar slot, so the body stopped above it
- and the only thing under the glass was backdrop — which defeats having
- moved the page into the capture at all. extendBody and
- extendBodyBehindAppBar let the body go edge to edge while the ghosts
- keep reporting their size through MediaQuery, so scrollables can still
- pad for them.

- Restore the blur, and the selection animation between pages

- Two regressions, both mine, both found by looking at the running app.

- The blur was gone. Clip.antiAliasWithSaveLayer — added to smooth the
- edge — isolates its subtree into a layer, and the lens's blur is a
- BackdropFilterLayer, which samples what sits behind it *within* that
- layer. Inside a fresh save layer there is nothing behind it, so the blur
- had nothing to work on. Forcing the boundary's antialiasing that way
- costs the material itself, which is a bad trade; the wrapper is gone.
- The circular corners stay — those helped and cost nothing.

- The selection pill stopped animating between pages. The chrome Stack
- adds the app bar conditionally, so switching between the Dashboard
- (no bar) and any other page changed its children from [nav] to
- [bar, nav]. With no keys the Stack matches children by index and type,
- and both are Positioned — so the bar's element was handed to the app bar
- and the bar was rebuilt from scratch, taking the spring's
- AnimationController with it. Both slots are keyed now.

- Also updates the handoff: sections 6, 8, 9.3, 10 and 11 described the
- state before this session and in places contradicted the code. They are
- flagged as historical, and a new section 19 records what is actually
- true, why the official nav bar was passed over, the four attempts at the
- rim and which one was the real cause, and what is left in priority order.

- Drop the chrome bar on the Dashboard

- The Dashboard showed a glass bar reading "Главная" directly above a card
- headed "RouteX" — the page named twice, with an empty bar spending the
- top of the viewport to do it. CommonScaffold takes a showAppBar flag
- (the content layer's top inset follows it, so the split layers stay in
- agreement) and the Dashboard opts out.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- One analytic curve everywhere, composited through a save layer

- Smoothing was applied to capsules only; every other rounding still used
- the traced continuous corner, which is a 40-segment polyline — faceted
- by construction — and the shader drew a squircle SDF inside a circular
- clip, so silhouette and refraction parted company at the corners.

- Every surface now uses a plain circular corner: the one shape where the
- shader, the clip and the shadow are the same analytic curve, so the edge
- resolves instead of tearing. The squircle is the nicer curve, but it
- cannot be drawn cleanly on this renderer, and smoothness matters more.
- Clip.antiAliasWithSaveLayer now wraps every glass surface rather than
- just capsules, so each boundary is antialiased once through a composited
- layer instead of per draw operation.

- RouteXGlassBorder is gone with the traced path it existed to build.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Composite capsules through a save layer so the curve is antialiased

- The edge kept reading as ragged after the rim was taken off entirely,
- which meant the complaint was never about the border styling: it was
- aliasing. Skia antialiases a rounded clip per draw operation, and the
- per-op result on a curve is visibly stepped — the long-standing reason a
- clipped Flutter surface looks jagged.

- Clip.antiAliasWithSaveLayer composites the surface first and antialiases
- the boundary once. It is applied where the silhouette is unambiguous —
- capsules, whose stadium outline matches a circular clip exactly. On a
- continuous corner an outer circular clip would crop the corner's belly,
- so those keep the lens's own clip. Costs one save layer per capsule.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Take the rim off entirely instead of turning it down

- Previous attempts thinned the outline and it kept reading as an outline,
- because the wrong term was being reduced. ambientIntensity is
- angle-independent: any non-zero value draws a ring around the whole
- shape regardless of where the light is. 0.35 was still a ring.

- ambientIntensity goes to 0 and lightSpread to 0.06, leaving only a
- highlight where the light actually lands. borderWidth drops to
- 0.3-0.5 across the variants: in optical mode the shader's band is
- borderWidth * 2 + 2 logical pixels, so the previous 0.8 was a 3.6 px
- stroke. lightIntensity 1 -> 0.9.

- The edge is now carried by the blur and the refraction, as it is on iOS.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Stop capsules from tracing a faceted outline

- The compact bottom bar's edge read as ragged. clipQuality: exact traces
- the continuous corner as a 40-segment polyline while the shader draws it
- analytically; on the tight curvature of a capsule the two disagree
- enough to show as faceting.

- At a full capsule the continuous shape degenerates to a stadium, which a
- plain circular clip reproduces exactly and smoothly. Surfaces that are
- true capsules — the compact bar, the detached Tools button, both
- selection pills — now declare it and take that path, and their shadow
- uses StadiumBorder instead of the traced path for the same reason.
- Everything with a real corner keeps the exact clip, where the traced
- path is the accurate one.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Frost the bars now that real content passes under them

- With the page in the capture, refraction alone dragged legible list text
- along the rim — a smear rather than a material. Navigation blur goes
- from 3 to 16 and panels from 3 to 10, which is what turns the passing
- content into the frosted wash the iOS reference shows. The low value was
- only ever defensible while the bars were refracting an empty mesh.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Put the page into the capture so the glass has the UI to bend

- This is the reason RouteX never looked like the iOS reference. On Skia a
- LiquidGlassLens samples exactly one thing: its ancestor
- LiquidGlassView's backgroundWidget. The page lived in `child`, painted
- over the capture and never sampled — so the bars were refracting a
- decorative mesh while the actual interface slid past untouched, and no
- amount of tuning could have fixed it. In the Telegram reference the
- chat list is what bends around the capsule.

- CommonScaffold now splits into two layers:

- - backgroundWidget: the backdrop plus the page. This is what gets
-   captured, so content passing under the app bar and the bottom bar is
-   what the glass refracts.
- - child: the glass chrome alone — app bar, side navigation, bottom bar.

- Both are laid out by the same rules, so the content is inset exactly
- where the chrome sits: the app bar's height is a constant the content
- layer reserves, and the bottom bar and side navigation are reproduced in
- the content layer as ghosts (laid out and animated at full size, never
- painted). The chrome layer is a Stack of positioned bars and nothing
- else, so taps in the empty middle fall through to the page beneath.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Match the rim and the nav metrics to the iOS reference

- From a Telegram-for-iPhone bottom bar supplied as reference:

- - The rim there is a highlight where the light hits — bright at the
-   top-left, gone by the far side — not a line around the shape. Ours
-   wrapped the whole perimeter, which is a drawn border by another name.
-   lightSpread 0.5 -> 0.12 and ambientIntensity 1 -> 0.35; the ambient
-   term is precisely the angle-independent ring.
- - The bar is see-through enough to read what slides under it. The
-   navigation tint drops from alpha 0.094 to 0.05; milkiness is what
-   makes glass look painted on.
- - The selection is a lift in brightness, not an outlined chip: more
-   fill, thinner rim.
- - Glyphs and labels were far too small. Icons 20 -> 25/26, labels
-   9 -> 11.5, and unselected labels are white rather than grey, as on
-   iOS. Bar height 60 -> 68 to fit them.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Take the neon rim back off, and give the glass something to bend

- The previous commit adopted the library's solid saturated rim on the
- premise that the backdrop now carried detail. It does not: the mesh was
- faint enough to be invisible and the vignette ate what was left, so
- every panel ended up outlined in a hard cyan line drawn on top of flat
- black. The handoff's warning about borderSolidity was right.

- - The rim is translucent again (solidity 0, saturation 1, intensity 1)
-   and stays thin at 0.8. Thin plus translucent reads as a bevel; the old
-   1.0-1.2 read as a stroke whether it was faint or not.
- - The mesh blobs are roughly twice as present and spread across the
-   frame instead of hugging two corners, so a panel in the middle of the
-   screen has something under it. The vignette drops from 0.4 to 0.16 —
-   it was darkening exactly the edges where the navigation sits.
- - The capture runs at the display's pixel ratio instead of a fixed 1.0,
-   which on a 125% / 150% Windows desktop was below native and upscaled.

- Kept from the previous commit: the exact clip, the shadow built from the
- shader's own path, light from near the top, and the capsule radii.
- The library's tuned nav glass survives as a playground preset for
- comparison, not as a token.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Align the glass rim with the library's tuned reference

- The edges read as soft and approximate rather than like glass. Comparing
- the tokens against example/lib/nav_bar_tuning.dart, RouteX had diverged
- on every term of the rim:

- - clipQuality was the default circular ClipRRect while the shader draws
-   a continuous (Apple capsule-style) corner, so the silhouette and the
-   refraction disagreed exactly at the corners. Now exact.
- - the drop shadow was a circular rounded rectangle behind a
-   continuous-corner lens, so a differently-curved shadow peeked out at
-   each corner. New RouteXGlassBorder builds the shadow from the same
-   path the shader draws.
- - the rim was thick (1.0-1.2) and fully translucent (borderSolidity 0);
-   the reference is thin (0.8) and solid (1), saturated 1.2, at
-   lightIntensity 1.1. Solidity 1 is safe now that the backdrop carries
-   detail — on the flat black it replaced, that is what would have turned
-   into a plastic outline.
- - light came from the right (lightDirection 0) instead of near the top
-   (80), so nothing read as a bevel.

- Floating navigation is a capsule again: the compact bar and its detached
- Tools button derive their radius from the bar height, as the library's
- own nav bar does, instead of sitting at 26 on a 60 px bar.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Put the navigation selection on spring travel with jelly deformation

- Etap 5 of ROUTEX_DEVELOPER_HANDOFF_RU.md, with one deliberate
- deviation from the plan.

- The plan called for adopting LiquidGlassBottomNavBar. Reading the
- component: on Skia its selection is a flat colour fill in every tier
- except the glass-refracting morph pill, and that tier needs the whole
- page handed to its own capture pipeline (buildGlassPillBar(body: ...)) —
- the library states outright that a bodyless capture comes back black on
- Skia. That would mean a second full-screen capture per frame and a
- restructure of CommonScaffold's compact branch, in exchange for losing
- the refracting selection lens RouteX already has.

- So the physics were adopted instead of the component. New
- widgets/routex_jelly_selection.dart drives RouteX's own
- RouteXSelectionGlass with the library's LiquidGlassJelly (which deforms
- by resizing, so the lens re-refracts at the deformed dimensions) plus a
- SpringSimulation for travel, using the library's own on-device-tuned nav
- constants. Tapping mid-flight re-launches the spring from the current
- position and velocity, so the travel bends instead of restarting.
- Reduce Motion snaps to the target with no ticker.

- Both navigation surfaces now share it: the compact bar (horizontal) and
- the desktop sidebar (vertical), replacing two hand-rolled
- TweenAnimationBuilders.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Split the glass material into five semantic variants

- Etap 4 of ROUTEX_DEVELOPER_HANDOFF_RU.md. RouteXGlassSurface took a raw
- `blur` sigma and an `ambientTint` flag per call site, so eleven surfaces
- each described their own material and no two navigation surfaces agreed.

- routeXGlassStyle(context, variant) is now the single place a
- LiquidGlassStyle is built, over RouteXGlassVariant: navigation,
- selection, panel, dialog, control. They share the radius scale, the tint
- family and the optical border; what differs is how much each may bend
- and obscure what is behind it:

- - dialog is the most opaque and displaces least — it carries dense text;
- - control and selection use a narrow refraction band (12 / 10 px), so
-   the bevels of opposite rims do not meet inside a 44 px target;
- - selection matches the official nav pill: standard distortion, no blur;
- - borderSolidity stays 0 everywhere — a light-driven solid rim reads as
-   plastic against a dark backdrop.

- Call sites now name a role instead of a blur radius. The developer
- playground ships the five variants as presets, so a tuned material can
- be copied straight back into the token.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Fix the captured-background architecture

- Etap 3 of ROUTEX_DEVELOPER_HANDOFF_RU.md. The backdrop was painted
- twice: once in LiquidGlassView.backgroundWidget (the capture) and again
- in the scaffold body, which sits in LiquidGlassView.child — i.e. on top
- of the capture. The child copy is opaque, so the scene was never
- actually visible; the lenses refracted a background nobody saw, at the
- cost of a second full-screen paint per frame. It also hid the user's
- custom background image, which is only ever added to the scene.

- - The backdrop is now painted once, in the scene. The scaffold body
-   starts at its SafeArea content.
- - New widgets/routex_backdrop.dart: the RouteX mesh (five soft
-   mint/blue/amber blobs, a seeded grain, a vignette) that gives the
-   capture something to refract, dimmed on content screens and stopped
-   under Reduce Motion. It paints no base fill, so the base gradient,
-   the light theme and the background image are untouched.
- - The developer playground now renders that same painter for its "mesh"
-   variant, so what is tuned there is what ships.
- - Dropped _SidebarUnderlay. On the Skia path the lens draws an opaque
-   refracted sample over its whole rect (honorBackdropAlpha is false), so
-   a layer beneath it in the tree is not merely un-refracted, it is
-   invisible — it only cost an ImageFilter.blur every selection frame.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- Add RouteX Glass Playground (dev-only tuning screen)

- Etap 2 of ROUTEX_DEVELOPER_HANDOFF_RU.md: an internal screen that puts
- every LiquidGlassStyle parameter on a live slider instead of tuning
- RouteXGlassSurface blind.

- - glass_params.dart: the full style parameter surface as one value
-   object, plus presets (official panel / official nav pill / current
-   RouteX surface / selection) and Dart source generation for pasting a
-   tuned material into a semantic token.
- - glass_backdrops.dart: five capture backdrops — the current RouteX one,
-   a candidate mesh backdrop with grain and vignette, and three
-   diagnostic scenes (grid, spectrum, flat black) that separate "the
-   material is wrong" from "there is nothing to refract".
- - glass_playground.dart: the screen. Renders panel / dialog / control /
-   nav capsule with a nested selection lens, optionally side by side with
-   the official reference material, over a switchable backdrop with the
-   LiquidGlassView capture settings exposed too. A "local underlay"
-   toggle demonstrates that a coloured block inside LiquidGlassView.child
-   is not part of the Skia capture.

- Reached from Tools -> Developer.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

- RouteX baseline before liquid glass rewrite

- Snapshot of the current FlClashX-dev working tree before the Liquid Glass
- pipeline rework described in ROUTEX_DEVELOPER_HANDOFF_RU.md.

- Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

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