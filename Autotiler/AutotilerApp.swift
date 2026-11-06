import AppKit
import Carbon.HIToolbox

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let tiler = Tiler()
    private lazy var prompt = CommandPrompt(tiler: tiler)
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        setUpStatusItem()
        registerHotKeys()
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private func requestAccessibilityIfNeeded() {
        // The literal is kAXTrustedCheckOptionPrompt, which Swift 6 treats as unsafe shared state.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private func registerHotKeys() {
        let ctrlOpt = controlKey | optionKey
        let bindings: [(Int, Int, TilerCommand)] = [
            (kVK_ANSI_T, ctrlOpt, .retile),
            (kVK_ANSI_L, ctrlOpt, .cycleLayout),
            (kVK_ANSI_F, ctrlOpt, .toggleFloat),
            (kVK_Return, ctrlOpt, .promote),
            (kVK_ANSI_M, ctrlOpt, .nextMonitor),
            (kVK_ANSI_Equal, ctrlOpt, .adjustGap(Tiler.gapStep)),
            (kVK_ANSI_Minus, ctrlOpt, .adjustGap(-Tiler.gapStep)),
            (kVK_RightArrow, ctrlOpt, .focus(step: 1)),
            (kVK_LeftArrow, ctrlOpt, .focus(step: -1)),
            (kVK_RightArrow, ctrlOpt | shiftKey, .swap(step: 1)),
            (kVK_LeftArrow, ctrlOpt | shiftKey, .swap(step: -1)),
        ]
        for (key, modifiers, command) in bindings {
            HotKeyCenter.shared.register(keyCode: key, modifiers: modifiers) { [tiler] in tiler.perform(command) }
        }
        HotKeyCenter.shared.register(keyCode: kVK_Space, modifiers: ctrlOpt) { [prompt] in prompt.show() }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        return menu
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "Autotiler")
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        addItem(to: menu, "Retile Now  (⌃⌥T)") { $0.perform(.retile) }
        addItem(to: menu, "Command…  (⌃⌥Space)") { [weak self] _ in self?.prompt.show() }
        menu.addItem(.separator())

        let layoutMenu = NSMenu()
        for kind in LayoutKind.allCases {
            let item = addItem(to: layoutMenu, kind.rawValue.capitalized) { $0.perform(.setLayout(kind)) }
            item.state = kind == tiler.layout ? .on : .off
        }
        menu.addItem(withTitle: "Layout  (⌃⌥L)", action: nil, keyEquivalent: "").submenu = layoutMenu

        let monitorMenu = NSMenu()
        for screen in NSScreen.screens {
            let item = addItem(to: monitorMenu, screen.localizedName) { $0.setTargetScreen(screen) }
            item.state = screen == tiler.targetScreen ? .on : .off
        }
        menu.addItem(withTitle: "Monitor  (⌃⌥M)", action: nil, keyEquivalent: "").submenu = monitorMenu

        addItem(to: menu, "Gap: \(Int(tiler.gap)) px  (⌃⌥ + / −)") { _ in }.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Autotiler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, action: @escaping (Tiler) -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = { [tiler] in action(tiler) } as () -> Void
        menu.addItem(item)
        return item
    }

    @objc private func runMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? () -> Void)?()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
