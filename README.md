# AutoTiler

A native macOS app that tiles windows on one monitor, Hyprland-style. It never rearranges anything on its own: windows are only tiled when you press a shortcut, use the menu-bar or Dock menu, or type a command.

Free-form commands ("give me more breathing room") are understood by Ollama's [d3](https://ollama.com/library/d3) decision model, which picks one option from a fixed list in a single pass. No text is generated, so it is cheap and fast. Exact phrases like `retile` or `gap 12` never touch the model.

## Requirements

- macOS 13 or later, Xcode
- Accessibility permission (the app asks on first launch)
- Optional, for free-form commands: [Ollama](https://ollama.com) with `ollama pull d3:2b`

## Run

```sh
open Autotiler.xcodeproj
```

Press ⌘R in Xcode. Run the geometry tests with the `AutotilerTests` scheme (⌘U). The app is ad-hoc signed, so macOS may ask you to grant Accessibility access again after a rebuild.

## Shortcuts

All shortcuts use ⌃⌥ (Control + Option). Press ⌃⌥/ any time for this list in-app.

**Smart retile** (uses d3 through local Ollama; falls back to the current layout with a beep if Ollama is unreachable)

| Keys | Action |
|---|---|
| T | d3 picks the best layout for the open apps, then retiles all windows |
| ⇧ T | d3 decides what the active window should do: snap into its tile, become master, or float |

**d3 agent** (uses d3; up to 4 windows)

| Keys | Action |
|---|---|
| A | d3 places every open window on the target monitor: one decision per window, each seeing what is already placed and only the spots still free |

By default you approve first. A table shows what d3 suggested for each open application:

```
d3 suggested    application open
top right       Xcode
left half       Safari
bottom right    Terminal
```

Turn the approval step off with "Ask Before Applying d3 Placements" in the menu-bar or Dock menu. With one window the spot is full screen; two get halves; three get a big left half and two right corners; four get quarters. Placed windows float, so a later retile won't undo the plan (⌃⌥F returns one to the layout). With more than 4 windows the agent declines and points you to ⌃⌥T.

**Manual retile** (no AI)

| Keys | Action |
|---|---|
| R | Retile all windows with the current layout |
| ⇧ R | Retile only the active window (snap it back to its slot, leave the rest) |
| 1 / 2 / 3 | Dwindle / master / columns layout |
| L | Cycle layout |

**Snap the active window to a half or third** (no AI; hold ⌃⌥⌘)

| Keys | Action |
|---|---|
| ← / → | Left / right half |
| ↑ / ↓ | Top / bottom half |
| 1 / 2 / 3 | Left / center / right third |

A snapped window floats, so retiling won't move it back. Press ⌃⌥F to return it to the layout. Halves and thirds use the same gap as the tiled layouts and are placed on whichever monitor the window is on. The command prompt understands the same positions ("left half", "right third", or "put this on the left side").

**Windows and layout** (no AI)

| Keys | Action |
|---|---|
| ← / → | Focus previous / next window |
| ⇧ ← / ⇧ → | Swap active window with its neighbour |
| Return | Promote active window to master |
| F | Float / unfloat active window (floated windows are never retiled) |
| M | Tile on the next monitor |
| = / − | Increase / decrease gap |
| / | Shortcuts help |
| Space | Command prompt (optional, uses d3) |

The same actions are in the menu-bar icon menu and the Dock icon menu. Only app names and the screen size are sent to d3, and only to your local Ollama.

## Command prompt

Exact phrases run locally: `agent` (or `arrange`), `left half`, `right half`, `top half`, `bottom half`, `left third`, `center third`, `right third`, `retile`, `snap` (active window only), `dwindle`, `master`, `columns`, `float`, `promote`, `monitor`, `gap+`, `gap-`, `gap 12`.

Anything else is sent to d3 at `http://127.0.0.1:11434/v1/systemone`. The result runs only if the chosen option's probability is at least 50% and it is not the "unrelated" choice. Each request maps to a single command.

## Layouts

- **dwindle**: each window takes half of the remaining space, splitting along its longer side.
- **master**: one large window beside an evenly split stack.
- **columns**: equal side-by-side columns.

Minimized, fullscreen, and non-resizable windows are ignored. Floated windows are left where they are.

See [TREE.md](TREE.md) for the code layout.
