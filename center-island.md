# Morphing center clock island (Quickshell + sway)

Spec for turning the centered clock pill in my top bar into a morphing
"island" that expands downward into a panel (calendar, media, notifications).
Written to be handed to Claude Code as the task brief.

## Context

- Compositor: sway (wlroots layer shell). Not Hyprland, so no `GlobalShortcut`,
  no `HyprlandFocusGrab`, no `hyprland-toplevel-export`.
- Shell: Quickshell, config in `~/.config/quickshell`.
- Existing bar: transparent full-width strip at the top with three floating
  pill segments:
  - left pill: workspace/indicator icons
  - center pill: clock, monospace, format `HH:mm:ss`
  - right: a small app pill, plus a status pill (volume, bluetooth, wifi)
- Only the center clock changes in this task. The left and right segments keep
  their current behaviour.

## Goal

The center pill is a single rectangle whose size, radius, and contents animate
between states. It must feel like one object reshaping, not a popup opening
under a bar widget.

States:

| state       | size (target) | content                             |
| ----------- | ------------- | ----------------------------------- |
| `collapsed` | ~110 x 26     | `HH:mm:ss` only (current look)      |
| `peek`      | ~240 x 26     | weekday, date, then time (hover)    |
| `calendar`  | ~360 x 400    | big clock header, month grid        |
| `media`     | ~360 x 220    | album art, title, artist, transport |

`peek` is hover only. `calendar` and `media` are click/keybind toggled, and
Tab cycles between them while open.

## Architecture

Use **two layer-shell windows**, not one.

1. `Bar.qml`: the existing thin window, anchored top/left/right,
   `exclusiveZone: barHeight`. Holds the left and right segments only.
2. `CenterIsland.qml`: a new **fullscreen** `PanelWindow`, anchored on all four
   edges, `exclusiveZone: 0`, `color: "transparent"`, `WlrLayer.Top`. Holds the
   island.

Reason: the island must be able to grow past the bar height without changing
the bar's exclusive zone (which would shove tiled windows around on every
open), and a fullscreen overlay gives a place to catch outside clicks.

### Input mask

The overlay window covers the screen, so it must not eat clicks while
collapsed:

```qml
PanelWindow {
    id: overlay
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    // collapsed/peek: only the pill itself is clickable.
    // open: whole screen is clickable so a click outside closes the island.
    mask: root.open ? null : pillRegion

    Region { id: pillRegion; item: island }
}
```

When `root.open` is true, a full-size `MouseArea` sitting _below_ the island in
z-order calls `root.close()` on click. This replaces the focus-grab behaviour
that Hyprland-based configs use.

### Keyboard

```qml
WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive
                                       : WlrKeyboardFocus.None
Keys.onEscapePressed: root.close()
Keys.onTabPressed: root.mode = root.mode === "calendar" ? "media" : "calendar"
```

Never hold exclusive focus while collapsed, it will steal typing from the
focused window.

## The morph itself

One `Rectangle`, positioned from the top edge, horizontally centered, so it
grows downward from the bar line.

```qml
Rectangle {
    id: island
    anchors.horizontalCenter: parent.horizontalCenter
    y: Config.barMargin

    implicitWidth:  root.geometry.w
    implicitHeight: root.geometry.h
    radius: root.open ? 20 : height / 2
    color: Theme.surface          // translucent dark, matches the other pills
    clip: true

    Behavior on implicitWidth  { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
    Behavior on implicitHeight { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
    Behavior on radius         { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
    Behavior on color          { ColorAnimation { duration: 300 } }
}
```

Rules that matter for the feel:

- **Target sizes are explicit per state**, taken from a lookup object. Do not
  bind `implicitWidth` to the content's `implicitWidth`, or the box will jitter
  while the content is swapping or while the media title changes.
- `clip: true` is required, otherwise the calendar grid spills out of the pill
  during the grow.
- Width and height animate with the **same** duration and easing so the corner
  travels in a straight line. If you want the "squash" feel instead, give width
  a 60ms head start over height on expand, and reverse it on collapse.
- `radius: height / 2` while collapsed keeps it a true pill at any height.

### Content swapping

```qml
Loader {
    id: content
    anchors.fill: parent
    sourceComponent: root.mode === "calendar" ? calendarView
                   : root.mode === "media"    ? mediaView
                   : clockView
    opacity: 0
    // fade out old content fast, fade new content in after the box has started moving
}
```

Sequence, expanding:

1. t=0: current content fades to 0 over 120ms, with `y` offset of -8.
2. t=0: geometry animation starts (400ms OutExpo).
3. t=150ms: new content loads, fades 0 to 1 over 200ms, `y` offset 8 to 0.

Collapsing is the mirror, and the geometry animation can be slightly faster
(300ms) so it does not feel sluggish.

### Clock continuity (important)

The time label must not blink out and back. Keep **one** clock `Text` that
lives outside the `Loader`, anchored to the island, and animate its properties
between states instead of destroying it:

- collapsed: `font.pixelSize: 13`, centered in the pill
- open: `font.pixelSize: 34`, top-left area of the panel header

Use `Behavior on font.pixelSize`, `Behavior on x`, `Behavior on y`, or a
`ParallelAnimation` driven by state change. The rest of the panel fades in
around it. This single detail is what makes it read as a morph.

Clock source:

```qml
SystemClock { id: clock; precision: SystemClock.Seconds }
// Qt.formatDateTime(clock.date, "HH:mm:ss")
```

Drop to `SystemClock.Minutes` if the seconds display is ever removed, seconds
precision wakes the process every second.

## Triggers

Quickshell IPC, bound in the sway config:

```qml
IpcHandler {
    target: "island"
    function toggle(mode: string): void { root.toggle(mode) }
    function close(): void { root.close() }
}
```

```
# ~/.config/sway/config
bindsym $mod+c exec qs ipc call island toggle calendar
bindsym $mod+m exec qs ipc call island toggle media
```

Mouse:

- `HoverHandler` on the island: collapsed to `peek` on enter, back on exit,
  with a 150ms debounce so brushing past does not flicker it.
- Left click: toggle `calendar`.
- Right click or middle click: toggle `media`.
- Scroll while collapsed: nothing (leave it free for a future volume gesture).

Calling `toggle` with the mode already open closes the island.

## Content requirements

**calendar view**

- Header: the shared big clock, plus full date underneath (`dddd, d MMMM yyyy`).
- Month grid, current day highlighted with `Theme.accent`, other-month days
  dimmed. Left/right arrows or `Left`/`Right` keys change month, `Home` returns
  to today.
- Pure QML, no external calendar process.

**media view**

- Quickshell `Mpris` service, `Mpris.players` with a selected active player.
- Album art from `trackArtUrl` (fall back to a placeholder when empty or when
  the URL is a remote http URL that fails to load).
- Title, artist, seek bar bound to `position` and `length`, transport buttons
  guarded by `canGoPrevious` / `canPlay` / `canGoNext`.
- Hide the view and fall back to `calendar` when no player is present.

## Theming

- All colors come from a `Theme.qml` singleton, no literals in components.
- Surface color should match the other pills exactly, including alpha, so the
  three segments look like one family.
- If matugen is already generating a palette, read it with
  `FileView { watchChanges: true }` and give every `Theme` color a
  `Behavior { ColorAnimation { duration: 300 } }` so a wallpaper change
  cross-fades the island too.

## sway specifics

- No compositor-level blur on layer surfaces in stock sway. The island is a
  flat translucent rounded rect. If SwayFX is in use, add:
  `layer_effects "quickshell:island" blur enable; shadows enable`
  and set the layer namespace on the window accordingly.
- Workspace and window data, if the island ever needs it, comes from the
  `Quickshell.I3` module (sway IPC), not `Quickshell.Hyprland`.
- Do not use `HyprlandFocusGrab`, the mask plus click catcher above is the
  replacement.

## File layout

```
~/.config/quickshell/
  shell.qml                     # loads Bar and CenterIsland per screen
  modules/bar/Bar.qml           # existing, unchanged
  modules/island/CenterIsland.qml   # overlay window, state machine, mask, IPC
  modules/island/ClockLabel.qml     # the persistent morphing clock text
  modules/island/CalendarView.qml
  modules/island/MediaView.qml
  config/Theme.qml              # singleton
  config/Config.qml             # singleton: sizes, durations, easings
```

Every size and duration named in this document goes in `Config.qml`, not
inline, so the feel can be tuned without touching component code.

## Multi-monitor

`shell.qml` instantiates the overlay per screen with `Variants` over
`Quickshell.screens`. Only the island on the focused screen responds to the IPC
toggle. Track the focused output through the I3 module and compare against
`screen.name`.

## Acceptance checklist

- [ ] Collapsed island is visually identical to the current center pill.
- [ ] Clicking through empty screen area while collapsed reaches the window
      below (verify with a maximized terminal under the bar).
- [ ] Expanding does not resize or move any tiled window.
- [ ] The time digits never disappear or restart during a transition.
- [ ] Escape and an outside click both close it, and focus returns to the
      previously focused window.
- [ ] No exclusive keyboard focus while collapsed.
- [ ] Opening and closing 20 times leaves no leaked `Loader` items and no
      growth in process memory.
- [ ] Works on a fractionally scaled output without blurry text.
