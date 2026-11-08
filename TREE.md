# TREE

Native macOS app (menu bar and Dock) that tiles windows on one monitor Hyprland-style, only when told to via shortcuts, menus or natural-language commands scored by Ollama's d3 model.

Autotiler.xcodeproj/        Xcode project (app target, ad-hoc signed, no sandbox so the Accessibility API works).
Autotiler/                  Application sources.
  AutotilerApp.swift        Entry point: menu-bar item, Dock menu, Accessibility prompt, and hotkey registration.
  Tiler.swift               Tiling state (layout, gap, window order, floating set, target monitor), command execution.
  TilingLayout.swift        Pure geometry: the dwindle, master and columns layouts, and SnapRegion (halves and thirds for hand-placing one window).
  WindowServer.swift        Accessibility API and screen-coordinate wrapper: list, move, resize, focus windows.
  D3Client.swift            Single call into Ollama's d3 decision endpoint; returns the top choice and its probability.
  LayoutAdvisor.swift       The two d3 questions behind smart retile: best layout for the open apps, and snap/promote/float for the active window.
  Shortcuts.swift           The shortcut table: one list that drives both hotkey registration and the help window.
  HelpWindow.swift          Reference window listing every shortcut; no model involved.
  HotKeyCenter.swift        Registers global hotkeys through Carbon.
  CommandInterpreter.swift  Maps typed text to a command: exact phrases locally, anything else via D3Client.
  CommandPrompt.swift       Borderless, semi-transparent terminal-style panel opened by the command shortcut.
AutotilerTests/             XCTest target; compiles TilingLayout.swift directly, no app host needed.
  TilingLayoutTests.swift   Layout bounds/overlap and snap-region (half/third) geometry, including gap handling.
README.md                   Overview, shortcuts and how to run.
.gitignore                  Keeps Xcode user state and build output out of the repo.
