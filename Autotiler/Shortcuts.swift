import Carbon.HIToolbox

enum ShortcutAction {
    case command(TilerCommand)
    case prompt
    case help
}

struct Shortcut {
    let section: String
    let key: String
    let keyCode: Int
    let modifiers: Int
    let title: String
    let action: ShortcutAction

    /// Human-readable chord, e.g. "⌃⌥⇧T".
    var label: String {
        (modifiers & controlKey != 0 ? "⌃" : "") + (modifiers & optionKey != 0 ? "⌥" : "")
            + (modifiers & shiftKey != 0 ? "⇧" : "") + key
    }
}

/// Single source of truth: the same table registers the global hotkeys and renders the help window.
enum Shortcuts {
    private static let base = controlKey | optionKey
    private static let withShift = controlKey | optionKey | shiftKey

    static let all: [Shortcut] = [
        Shortcut(section: "Smart retile (d3)", key: "T", keyCode: kVK_ANSI_T, modifiers: base, title: "d3 picks the best layout, retile all windows", action: .command(.smartRetile)),
        Shortcut(section: "Smart retile (d3)", key: "T", keyCode: kVK_ANSI_T, modifiers: withShift, title: "d3 decides: snap, promote or float the active window", action: .command(.smartRetileActive)),
        Shortcut(section: "Manual retile", key: "R", keyCode: kVK_ANSI_R, modifiers: base, title: "Retile all windows, current layout", action: .command(.retile)),
        Shortcut(section: "Manual retile", key: "R", keyCode: kVK_ANSI_R, modifiers: withShift, title: "Retile only the active window", action: .command(.retileActive)),
        Shortcut(section: "Manual retile", key: "1", keyCode: kVK_ANSI_1, modifiers: base, title: "Dwindle layout", action: .command(.setLayout(.dwindle))),
        Shortcut(section: "Manual retile", key: "2", keyCode: kVK_ANSI_2, modifiers: base, title: "Master layout", action: .command(.setLayout(.master))),
        Shortcut(section: "Manual retile", key: "3", keyCode: kVK_ANSI_3, modifiers: base, title: "Columns layout", action: .command(.setLayout(.columns))),
        Shortcut(section: "Manual retile", key: "L", keyCode: kVK_ANSI_L, modifiers: base, title: "Cycle layout", action: .command(.cycleLayout)),
        Shortcut(section: "Windows", key: "←", keyCode: kVK_LeftArrow, modifiers: base, title: "Focus previous window", action: .command(.focus(step: -1))),
        Shortcut(section: "Windows", key: "→", keyCode: kVK_RightArrow, modifiers: base, title: "Focus next window", action: .command(.focus(step: 1))),
        Shortcut(section: "Windows", key: "←", keyCode: kVK_LeftArrow, modifiers: withShift, title: "Swap with previous window", action: .command(.swap(step: -1))),
        Shortcut(section: "Windows", key: "→", keyCode: kVK_RightArrow, modifiers: withShift, title: "Swap with next window", action: .command(.swap(step: 1))),
        Shortcut(section: "Windows", key: "↩", keyCode: kVK_Return, modifiers: base, title: "Promote active window to master", action: .command(.promote)),
        Shortcut(section: "Windows", key: "F", keyCode: kVK_ANSI_F, modifiers: base, title: "Float / unfloat active window", action: .command(.toggleFloat)),
        Shortcut(section: "Layout", key: "=", keyCode: kVK_ANSI_Equal, modifiers: base, title: "Increase gap", action: .command(.adjustGap(Tiler.gapStep))),
        Shortcut(section: "Layout", key: "-", keyCode: kVK_ANSI_Minus, modifiers: base, title: "Decrease gap", action: .command(.adjustGap(-Tiler.gapStep))),
        Shortcut(section: "Layout", key: "M", keyCode: kVK_ANSI_M, modifiers: base, title: "Tile on the next monitor", action: .command(.nextMonitor)),
        Shortcut(section: "Other", key: "/", keyCode: kVK_ANSI_Slash, modifiers: base, title: "This help", action: .help),
        Shortcut(section: "Other", key: "Space", keyCode: kVK_Space, modifiers: base, title: "Command prompt (optional, d3 model)", action: .prompt),
    ]
}
