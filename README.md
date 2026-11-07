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

Press ⌘R in Xcode. The app is ad-hoc signed, so macOS may ask you to grant Accessibility access again after a rebuild.

## Shortcuts

All shortcuts use ⌃⌥ (Control + Option) and run locally with no AI. Press ⌃⌥/ any time for this list in-app.

| Keys | Action |
|---|---|
| T | Retile all windows |
| ⇧ T | Retile only the active window (snap it back to its slot, leave the rest) |
| 1 / 2 / 3 | Dwindle / master / columns layout |
| L | Cycle layout |
| ← / → | Focus previous / next window |
| ⇧ ← / ⇧ → | Swap active window with its neighbour |
| Return | Promote active window to master |
| F | Float / unfloat active window (floated windows are never retiled) |
| M | Tile on the next monitor |
| = / − | Increase / decrease gap |
| / | Shortcuts help |
| Space | Command prompt (optional, uses d3) |

The same actions are in the menu-bar icon menu and the Dock icon menu.

## Command prompt

Exact phrases run locally: `retile`, `snap` (active window only), `dwindle`, `master`, `columns`, `float`, `promote`, `monitor`, `gap+`, `gap-`, `gap 12`.

Anything else is sent to d3 at `http://127.0.0.1:11434/v1/systemone`. The result runs only if its confidence is at least 50% and it is not the "unrelated" choice. Each request maps to a single command.

## Layouts

- **dwindle**: each window takes half of the remaining space, splitting along its longer side.
- **master**: one large window beside an evenly split stack.
- **columns**: equal side-by-side columns.

Minimized, fullscreen, and non-resizable windows are ignored. Floated windows are left where they are.

See [TREE.md](TREE.md) for the code layout.
