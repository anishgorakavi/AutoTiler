import AppKit

/// Plain reference window listing every shortcut. Nothing here uses the model.
final class HelpWindow {
    private static let padding: CGFloat = 24
    private static let keyColumnWidth = 7
    private var window: NSWindow?

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let label = NSTextField(labelWithAttributedString: content())
        label.frame.origin = NSPoint(x: Self.padding, y: Self.padding)
        let size = NSSize(width: label.frame.width + 2 * Self.padding, height: label.frame.height + 2 * Self.padding)

        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Autotiler Shortcuts"
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(label)
        return window
    }

    private func content() -> NSAttributedString {
        let body = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let heading = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        let text = NSMutableAttributedString()

        func add(_ string: String, font: NSFont, color: NSColor = .labelColor) {
            text.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
        }

        var currentSection = ""
        for shortcut in Shortcuts.all {
            if shortcut.section != currentSection {
                currentSection = shortcut.section
                if text.length > 0 { add("\n", font: body) }
                add(currentSection.uppercased() + "\n", font: heading, color: .secondaryLabelColor)
            }
            add(shortcut.label.padding(toLength: Self.keyColumnWidth + 4, withPad: " ", startingAt: 0), font: heading)
            add(shortcut.title + "\n", font: body)
        }
        add("\nAlso in the menu-bar icon menu and the Dock icon menu.\n", font: body, color: .secondaryLabelColor)
        add("Windows are never rearranged automatically: only a command above does it.\n", font: body, color: .secondaryLabelColor)
        add("Only smart retile and the prompt use d3 (local Ollama). Everything else runs with no AI.", font: body, color: .secondaryLabelColor)
        return text
    }
}
