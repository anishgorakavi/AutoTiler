# TREE

Native macOS app (menu bar and Dock) that tiles windows on one monitor Hyprland-style, only when told to via shortcuts, menus or natural-language commands scored by Ollama's d3 model.

Autotiler.xcodeproj/        Xcode project (app target, ad-hoc signed, no sandbox so the Accessibility API works).
Autotiler/                  Application sources.
  AutotilerApp.swift        Entry point: menu-bar item, Dock menu, Accessibility prompt, and the global shortcut table.
  Tiler.swift               Tiling state (layout, gap, window order, floating set, target monitor), command execution.
  TilingLayout.swift        Pure geometry for the dwindle, master and columns layouts.
  WindowServer.swift        Accessibility API and screen-coordinate wrapper: list, move, resize, focus windows.
  HotKeyCenter.swift        Registers global hotkeys through Carbon.
  CommandInterpreter.swift  Maps typed text to a command: exact phrases locally, anything else via d3's /v1/systemone endpoint.
  CommandPrompt.swift       Borderless, semi-transparent terminal-style panel opened by the command shortcut.
README.md                   Overview, shortcuts and how to run.
.gitignore                  Keeps Xcode user state and build output out of the repo.
