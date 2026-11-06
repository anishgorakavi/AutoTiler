import AppKit

/// Small floating panel (Spotlight-style) for typing a tiling command.
final class CommandPrompt: NSObject, NSTextFieldDelegate {
    private let panel: NSPanel
    private let field = NSTextField()
    private let status = NSTextField(labelWithString: "")
    private let tiler: Tiler

    init(tiler: Tiler) {
        self.tiler = tiler
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 74),
                        styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()

        panel.title = "Autotiler"
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false

        field.placeholderString = "retile · master · gap 12 · or describe what you want"
        field.delegate = self
        field.frame = NSRect(x: 16, y: 34, width: 408, height: 24)
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 11)
        status.frame = NSRect(x: 16, y: 10, width: 408, height: 16)
        panel.contentView?.addSubview(field)
        panel.contentView?.addSubview(status)
    }

    func show() {
        tiler.pinFocus()
        field.stringValue = ""
        status.stringValue = ""
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            submit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            dismiss()
            return true
        default:
            return false
        }
    }

    private func submit() {
        let text = field.stringValue
        guard !text.isEmpty else { return }
        status.stringValue = "Thinking…"
        field.isEnabled = false
        Task { @MainActor in
            defer { field.isEnabled = true }
            do {
                let command = try await CommandInterpreter.interpret(text)
                dismiss()
                tiler.perform(command)
            } catch {
                status.stringValue = error.localizedDescription
                panel.makeFirstResponder(field)
            }
        }
    }

    private func dismiss() {
        panel.orderOut(nil)
        NSApp.hide(nil)  // hands focus back to the previously active app
    }
}
