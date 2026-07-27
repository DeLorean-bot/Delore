# RouteX Product UX

## Product promise

The user should always be able to answer three questions without opening YAML:

1. Is routing active?
2. Where is this application or domain going?
3. How do I change it and safely undo the change?

## Evidence-led priorities

Requests across Hiddify, Clash Verge Rev, and FlClash repeatedly converge on:

1. Per-app, domain, and IP routing.
2. Reliable localhost and LAN bypass.
3. Autostart, auto-connect, and silent startup.
4. Kill switch with an explicit recovery path.
5. One-click deep-link and clipboard import.
6. Useful tray status, speed, and node switching.
7. Connection search, filtering, sorting, pause, and selective close.
8. Persistent custom rules that survive subscription updates.

RouteX should ship these in that order. Decorative controls must not appear
before the underlying behaviour is safe and testable.

## Ordinary-user features

### Route explanation

Every application, browser domain, and connection should expose a short
human-readable explanation:

- `Proxy · selected manually`
- `Direct · inherited from Gaming profile`
- `Rule · matched DOMAIN-SUFFIX,github.com`

Technical rule details stay behind an expandable `Details` action.

### Safe suggestions

RouteX may suggest a route after observing stable behaviour, but never changes
it silently:

- games with unstable latency → suggest the lowest-latency proxy;
- local launchers and update services → suggest Direct;
- a domain repeatedly changed by the user → suggest saving it permanently;
- conflicting application/domain choices → explain precedence before applying.

Suggestions are dismissible and limited to one per screen.

### Undo and history

Every routing change creates a short toast:

`Discord now uses Proxy` · `Undo`

The current application router implements the immediate Undo action. The future
History screen will group changes by session and restore one change or a profile
snapshot. Destructive bulk restores require confirmation.

### First-run setup

A three-step setup replaces an empty dashboard:

1. Add subscription/profile.
2. Enable TUN and run the system check.
3. Choose a starter preset: Balanced, Gaming, Work, or Streaming.

Each step explains why a permission is needed and offers a retry path.

### Command search

`Ctrl/Cmd + K` opens a compact command palette:

- find an application, process, domain, profile, or setting;
- run `Discord → Proxy`;
- toggle TUN;
- switch quick profile;
- open diagnostics.

Results use the same icons and labels as their destination screens.

### Calm notifications

Notify only when the user can act:

- core stopped unexpectedly;
- profile expired or failed to update;
- selected proxy became unavailable;
- a new application requested network access;
- a routing conflict needs a decision.

Routine connection events stay in the activity timeline, not as pop-ups.

### Browser domains

Browser integration should primarily show domains and activity, not expose
private page titles by default. The user explicitly opts into tab-title access.
Domain routing supports one-click Proxy/Direct/Rule and clearly shows whether an
application-level browser rule overrides it.

## Adaptive layout

### Compact

- Bottom navigation: up to four primary destinations plus detached Settings.
- Core status stays in the Home hero.
- Lists prioritize name, state, and one primary route control.
- Secondary traffic details expand inline.

### Full screen

- Floating collapsible glass sidebar.
- Shared moving selection lens; labels remain visible in expanded mode.
- Maximum content width prevents settings rows stretching across an ultrawide
  display.
- Applications may use the full content width for traffic and route columns.
- The sidebar shows routing status without requiring a visit to Home.

## Motion policy

- Home owns one slow 16-second ambient animation.
- Secondary pages blur and dim the scene in 280 ms.
- Navigation lens: 300 ms.
- State/control transition: 220 ms.
- Press feedback: 120 ms.
- Toast/sheet entrance: 220–300 ms; exit about 160 ms.
- List entrance animation is used only after an explicit refresh or first load,
  never on every filter keystroke.
- Reduce Motion removes ambient and spatial travel while retaining immediate
  opacity and contrast changes.
