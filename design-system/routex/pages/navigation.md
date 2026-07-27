# Bottom Navigation

## Composition

- One slim main glass capsule for primary destinations.
- One detached circular glass control for Settings/Tools.
- Height: 60 px including a 4 px internal inset.
- Gap between groups: 8 px.
- Horizontal page inset: 14 px.
- Main capsule and detached control share the same material recipe.

## Selection

- A single shared lens slides under primary items.
- Desktop sidebar: 56 px item step, 52 px lens, 18 px radius. Collapsed lens is
  a centered 56Ã—52 squircle with identical optical padding around the icon.
- Lens inset: 1 px inside the navigation content area.
- Lens uses a subtle white/blue tint, 0.8 px hairline, and a small neutral
  shadow. No neon halo.
- Selected icon uses the mint accent; selected label uses primary text.
- Press feedback scales content to `.96` for 120 ms.
- Navigation motion is 300 ms with curve `.16, 1, .3, 1`.
- With Reduce Motion enabled, selection changes immediately.

## Accessibility

- Each item remains at least 44 px high.
- Every item exposes semantic `button`, `selected`, and translated label.
- The detached icon-only item always has a tooltip.
- Labels use 9 px only in this compact navigation exception and must remain
  single-line; use 12 px or larger elsewhere.
