import AppKit

/// Borderless panels refuse key status by default, which would leave the text field unable to type.
private final class PromptPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Floating, semi-transparent, terminal-styled panel for typing a tiling command.
final class CommandPrompt: NSObject, NSTextFieldDelegate {
    private static let size = NSSize(width: 560, height: 84)
    private static let accent = NSColor(calibratedRed: 0.35, green: 0.9, blue: 0.5, alpha: 1)
    private static let inputFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    private let panel: PromptPanel
    private let field = NSTextField()
    private let status = NSTextField(labelWithString: "")
    private let tiler: Tiler

    init(tiler: Tiler) {
        self.tiler = tiler
        panel = PromptPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                            styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()

        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = makeContent()
    }

    func show() {
        tiler.pinFocus()
        field.stringValue = ""
        status.stringValue = ""
        position()
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

    private func makeContent() -> NSView {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        let caret = NSTextField(labelWithString: "›")
        caret.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        caret.textColor = Self.accent
        caret.setContentHuggingPriority(.required, for: .horizontal)

        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = Self.inputFont
        field.textColor = .white
        field.placeholderAttributedString = NSAttributedString(
            string: "retile · master · gap 12 · or describe what you want",
            attributes: [.font: Self.inputFont, .foregroundColor: NSColor.white.withAlphaComponent(0.35)])
        field.delegate = self

        status.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        status.textColor = NSColor.white.withAlphaComponent(0.55)
        status.lineBreakMode = .byTruncatingTail

        let inputRow = NSStackView(views: [caret, field])
        inputRow.orientation = .horizontal
        inputRow.alignment = .firstBaseline
        inputRow.spacing = 10

        let column = NSStackView(views: [inputRow, status])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(column)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -20),
            column.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            inputRow.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            status.trailingAnchor.constraint(equalTo: column.trailingAnchor),
        ])
        return background
    }

    /// Horizontally centered, in the upper third of the screen under the mouse.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.midX - Self.size.width / 2,
                                     y: area.maxY - area.height * 0.3 - Self.size.height / 2))
    }

    private func submit() {
        let text = field.stringValue
        guard !text.isEmpty else { return }
        status.textColor = NSColor.white.withAlphaComponent(0.55)
        status.stringValue = "thinking…"
        field.isEnabled = false
        Task { @MainActor in
            defer { field.isEnabled = true }
            do {
                let command = try await CommandInterpreter.interpret(text)
                dismiss()
                tiler.perform(command)
            } catch {
                status.textColor = NSColor.systemRed
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
