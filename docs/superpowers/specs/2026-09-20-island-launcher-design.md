# Island launcher — design spec

Date: 2026-09-20
Status: approved (pending implementation plan)

## Goal

Replace the wofi-based `$mod+d` app launcher (`$menu --show drun`) with a
native QuickShell launcher that appears as a "dynamic island" expanding
out of the clock pill at the top of the bar, instead of wofi's centered
window. This is the first surface of a longer-term dynamic-island idea;
only the drun replacement ships now.

## Non-goals

- Any other dynamic-island surface from the reference video (window
  previews, wallpaper picker, media widget, bottom dock). Only the drun
  replacement ships now; the pattern this establishes (`IpcHandler` +
  animated `PopupWindow` anchored to a bar module) can be reused later
  for those, but they are not designed here.
- Removing wofi or the `$menu` variable. `set $menu wofi` (sway/config:22)
  stays; only the `$mod+d` binding's target changes.
- A general-purpose fuzzy-finder library. The scorer is one small
  self-contained subsequence matcher.
- Multi-monitor "which output was focused" logic. Current hardware is
  single-monitor; the popup follows the same per-screen `Variants`
  pattern the rest of the bar already uses, targeting the primary
  screen's `Clock`.

## Scope

- New module: `quickshell/modules/LauncherPopup.qml`.
- New `IpcHandler` in `shell.qml` (target `"launcher"`, function
  `toggle()`).
- `sway/config:91`: `bindsym $mod+d exec $menu --show drun` becomes
  `bindsym $mod+d exec qs ipc call launcher toggle`.

## Trigger & lifecycle

An `IpcHandler` at the top level of `shell.qml` (sibling of the
`PanelWindow` `Variants`, registered once per shell instance — not
per-screen) exposes `toggle()`, flipping a shared `launcherOpen` bool
that `LauncherPopup` reads. Sway's `$mod+d` calls
`qs ipc call launcher toggle` in place of invoking wofi.

Closes on any of:
- Escape key, while the search field has focus.
- `$mod+d` again (same `toggle()` call).
- Click outside the popup's bounds.

Check how the existing popups (`CalendarPopup`/`BluetoothPopup`/
`NetworkPopup`) currently dismiss on outside click, if they do, and reuse
that mechanism; otherwise add a full-screen `MouseArea` behind the
popup's content at the `PopupWindow` level.

## Animation ("the morph")

`LauncherPopup` is its own `PopupWindow` (styled like `PopupPanel` but
not reusing it directly, since the animated sizing is bespoke):

- Collapsed geometry matches the `Clock` pill's current
  `implicitWidth`/`implicitHeight` and screen position exactly, so the
  instant it becomes visible it's pixel-identical to the clock
  underneath — no visible "pop" on open.
- `Behavior on implicitWidth` / `Behavior on implicitHeight` (a short
  `NumberAnimation`, roughly 150-200ms, `Easing.OutCubic` or similar)
  animates both dimensions to the expanded search+list size when
  `launcherOpen` becomes true, and back down to the clock's collapsed
  size when it becomes false. The popup only actually hides once the
  shrink animation finishes, so the collapse is visible rather than an
  instant cut.
- The real `Clock` pill stays rendered underneath at all times (it
  doesn't need to hide); the launcher popup's opaque background covers
  it while expanded, the same z-order precedent the other popups already
  use over bar content.

## App data & search

- Source: `Quickshell.DesktopEntries.applications` — native, no `.desktop`
  parsing or shelling out to wofi.
- Filter: typing into an auto-focused `TextInput` scores every
  application with a small subsequence-based fuzzy matcher (query
  characters must appear in order in the target string; consecutive
  matches and word-boundary matches score higher — same spirit as fzf,
  one local JS function, no new dependency), matched against `name`,
  `genericName`, and `keywords`. Non-matching entries are excluded; the
  rest sort by score descending. Empty query shows the full list.
- Rendering: a scrollable list of rows, each an
  `Quickshell.Widgets.IconImage` (source resolved from `entry.icon`) +
  `name` (bold) + `genericName` (dim subtext), matching the reference
  video's list style. One row is "highlighted" — Up/Down move it,
  defaulting to the first result; mouse hover also updates the highlight.
- Launch: Enter (highlighted entry) or a mouse click on a row calls
  `DesktopEntry.execute()`, then closes the popup via the same path as
  Escape.

## Testing

No automated test story for this repo's QML (matches the rest of the
quickshell migration). Verify manually: trigger via
`qs ipc call launcher toggle` directly first to confirm the popup and
animation work independent of Sway, then bind `$mod+d` and confirm the
real keybinding path — screenshotting the collapsed/expanded states and
exercising keyboard nav, mouse click launch, and all three close paths
live.

## Sway integration

`sway/config:91` changes from `bindsym $mod+d exec $menu --show drun` to
`bindsym $mod+d exec qs ipc call launcher toggle`. `$menu`
(`sway/config:22`) stays defined since nothing else in scope removes
wofi.
