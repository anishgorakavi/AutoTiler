import AppKit

/// Modal dialogs for the d3 agent: a table of its suggestions to approve, and plain error messages.
enum PlanApproval {
    typealias Row = (suggestion: String, app: String)

    static func confirm(_ rows: [Row]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Apply d3's placement?"
        alert.informativeText = "Each open window will be moved to the spot d3 suggested."
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let source = RowsSource(rows: rows)
        alert.accessoryView = source.makeTableView()
        NSApp.activate(ignoringOtherApps: true)
        return withExtendedLifetime(source) { alert.runModal() == .alertFirstButtonReturn }
    }

    static func inform(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Autotiler"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

/// Two-column read-only table: what d3 suggested, and the application it applies to.
private final class RowsSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private static let columns = [("suggestion", "d3 suggested"), ("app", "application open")]
    private static let rowHeight: CGFloat = 24
    private static let width: CGFloat = 380
    private static let chromeWidth: CGFloat = 22  // bezel, scroller and inter-column spacing
    private static let maxHeight: CGFloat = 220

    private let rows: [PlanApproval.Row]

    init(rows: [PlanApproval.Row]) {
        self.rows = rows
    }

    func makeTableView() -> NSScrollView {
        let table = NSTableView()
        table.dataSource = self
        table.delegate = self
        table.rowHeight = Self.rowHeight
        table.usesAlternatingRowBackgroundColors = true
        table.selectionHighlightStyle = .none
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        for (identifier, title) in Self.columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = (Self.width - Self.chromeWidth) / CGFloat(Self.columns.count)
            table.addTableColumn(column)
        }

        let height = min(CGFloat(rows.count + 1) * Self.rowHeight + 8, Self.maxHeight)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: Self.width, height: height))
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .bezelBorder
        return scroll
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let text = tableColumn?.identifier.rawValue == "suggestion" ? rows[row].suggestion : rows[row].app
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        return label
    }
}
