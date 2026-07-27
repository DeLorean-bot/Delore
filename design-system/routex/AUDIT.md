# RouteX UI/UX Audit

Audit baseline: 2026-07-27. Scope: current custom shell, Home, Applications,
profiles/proxies surfaces that remain inherited from FlClashX, and mobile bottom
navigation.

## P0 — system-level

- **Design tokens are not yet centralized.** Custom pages still contain repeated
  color, radius, shadow, and duration literals. Move them into the RouteX theme
  before the next large screen redesign.
- **Reduced motion is inconsistent.** The new bottom navigation respects it,
  but other animated surfaces must use the same policy.
- **Small type exists in dense custom areas.** Several captions fall around
  7–10 px. Raise normal content to 12 px and keep 9 px only for compact bottom
  navigation.
- **Some routing controls are below 44 px high.** Keep the compact visual shape
  but expand the invisible/outer hit area.
- **Glass lacks a single material recipe across the app.** Apply glass only to
  shell elevation planes and overlays; standard list/card content should use
  quiet opaque or lightly translucent surfaces.

## P1 — product coherence

- **Inherited FlClashX screens and RouteX screens speak different visual
  languages.** Profiles, proxies, settings, dialogs, and empty states need to be
  migrated to RouteX primitives rather than individually recolored.
- **Typography is too expressive in utility contexts.** Limit `Unbounded` to
  branding and page display titles; use regular/medium system text for controls.
- **Mixed Russian and English labels appear in the same workflow.** Finish the
  localization pass and keep route commands consistent across screens.
- **Some pages repeat the title in both shell and content.** Use one page title
  and spend the recovered space on status or primary actions.
- **Background grid, image, glow, and glass sometimes compete at once.** Keep a
  maximum of two depth cues on a screen.
- **Loading and empty states are inconsistent.** Define shared skeleton, empty,
  permission-denied, engine-off, and no-network patterns.

## P2 — interaction and desktop quality

- Add visible keyboard focus and predictable tab order to every route control.
- Add hover states on Windows without resizing or moving elements.
- Verify large text, 125–200% Windows scaling, light theme, high contrast, and
  narrow-window layouts.
- Add semantic descriptions to live traffic values so screen readers announce
  units and state rather than raw numbers.
- Remove or archive unused legacy visual implementations after their RouteX
  replacements are stable to prevent design regressions.

## Migration order

1. Centralize semantic RouteX tokens and shared glass/surface primitives.
2. Finish the global shell: navigation, page title, dialogs, sheets, toasts.
3. Normalize Applications list, route selector, search, favorites, and states.
4. Redesign Profiles and Proxies with the same primitives.
5. Redesign Settings and advanced engine screens.
6. Run accessibility, localization, scaling, and performance passes.

