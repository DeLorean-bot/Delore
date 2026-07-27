# RouteX Design System

> Source of truth for every new or redesigned RouteX screen.
> A matching file in `pages/` may refine these rules but must not contradict
> accessibility, motion, contrast, or interaction requirements.

## Direction

**Modern Dark Cinema + Controlled Liquid Glass.**

RouteX is a precise network utility, not a neon dashboard. The interface should
feel close to modern iOS: calm, layered, responsive, and tactile. Glass is used
to communicate elevation and separation. It is not a decoration applied to
every card.

## Foundation

### Color

| Token | Dark value | Use |
|---|---:|---|
| Canvas | `#050506` | Main background; avoid pure OLED black smear |
| Surface | `#0A0A0C` | Standard opaque surface |
| Elevated | `rgba(255,255,255,.045)` | Cards and grouped controls |
| Glass | `rgba(20,22,27,.78)` | Navigation and floating overlays only |
| Hairline | `rgba(255,255,255,.09)` | 0.8–1 px borders |
| Text primary | `#EDEDEF` | Primary labels and values |
| Text secondary | `#8A8F98` | Supporting labels |
| Accent | `#62E6C5` | Active state and connected status |
| Link/focus | `#6EA8FF` | Links and visible keyboard focus |
| Danger | `#FF646F` | Destructive/error state |
| Warning | `#F1B956` | Degraded/warning state |

Accent glow is reserved for active connection state and should stay under 12%
opacity. Text and icons must not rely on glow for contrast.

### Typography

- Use the platform/system face for controls and body copy where possible.
- `Unbounded` is branding/display only, never long labels or settings rows.
- `JetBrains Mono` is for technical values: addresses, speeds, ports, IDs.
- Default UI weights: 400/500. Active labels: 600 maximum.
- Minimum normal UI text: 12 px. Captions below 11 px require a specific
  density justification and must scale with accessibility text settings.

### Spacing and shape

- Spacing scale: `4, 8, 12, 16, 24, 32`.
- Standard card radius: 14–16.
- Floating controls: 18–22.
- Navigation capsule: 26 maximum.
- Minimum interactive target: 44×44 logical pixels.
- Borders are hairlines; avoid multiple nested outlines.

## Liquid Glass

- Blur: 16–18 px for bottom navigation; 12–16 px for popovers.
- Use one glass layer per elevation plane.
- Always include a translucent fill and hairline border; blur alone is not a
  readable surface.
- Primary floating glass may use a cursor-driven radial refraction highlight.
  It responds only while the pointer is over the surface and returns to its
  resting top-left highlight on exit; never run it as a decorative loop.
- Shadows: one soft black shadow, typically blur 16–20 and y-offset 6–8.
- Avoid large colored halos, thick white rims, and stacked gradients.
- Content underneath glass must remain legible when transparency is disabled.

## Motion

| Token | Duration | Use |
|---|---:|---|
| Press | 120 ms | scale to `.96–.98` |
| Fast | 160 ms | opacity/icon response |
| Base | 220 ms | row/control state |
| Navigation | 300 ms | shared sliding selection lens |

- Default spatial curve: `cubic-bezier(.16, 1, .3, 1)`.
- Animate transform and opacity when possible.
- A selected navigation lens must move as one shared object, not cross-fade as
  unrelated per-item pills.
- Desktop navigation uses a 56 px vertical rhythm. The active lens is 52 px
  high; in collapsed mode it remains a centered square squircle instead of
  shrinking into a narrow pill.
- Never animate continuously without a live state to communicate.
- Respect Reduce Motion/disabled animations: remove spatial travel, preserve
  immediate state and contrast changes.

## Interaction

- Navigation has at most five items with icon and label; secondary actions may
  occupy a separate glass circle when the grouping is meaningful.
- Hover, pressed, selected, focus, loading, disabled, success, and error states
  must be designed explicitly.
- All icon-only actions require a tooltip and semantic label.
- Keyboard focus must be visible on Windows.
- Never shift layout on hover or selection.
- Loading preserves layout; use skeletons for content and progress indicators
  for explicit actions.

## Content

- Use one interface language per screen.
- Prefer short nouns and verbs: `Proxy`, `Direct`, `Rule`, `Bypass`.
- Hide YAML and engine terminology from primary flows; expose it only in
  advanced details.
- Avoid duplicate page titles between the global shell and page content.

## Flutter implementation

- Use semantic theme tokens rather than inline arbitrary colors.
- `RouteXGlassSurface` is the single shell-level glass primitive and is backed
  by `liquid_glass_easy`; do not recreate local `BackdropFilter` glass cards.
- On Windows/Skia, provide lenses through one viewport-sized
  `LiquidGlassView`. Capture the animated dashboard at medium refresh rate and
  reduced pixel ratio; keep shader blur at or below 6 to avoid divergent Skia
  cost and overly milky surfaces.
- Use `LayoutBuilder` for responsive composition.
- Use `Semantics`, tooltips, and 44 px hit targets.
- Respect `MediaQuery.disableAnimations`.
- Isolate moving glass/lens layers with `RepaintBoundary`.
- Profile blur-heavy screens; glass is a shell primitive, not a list-row style.
- Dispose explicit animation controllers and avoid controllers for simple
  implicit state transitions.
