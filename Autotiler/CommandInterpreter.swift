import Foundation

enum InterpreterError: LocalizedError {
    case modelUnavailable
    case notUnderstood(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable: return "Could not reach Ollama. Is it running with d3:2b pulled?"
        case .notUnderstood(let text): return "Not a tiling command: \(text)"
        }
    }
}

/// Turns typed text into a TilerCommand. Exact phrases are resolved locally for free;
/// anything else goes to d3, a decision model that scores a fixed list of choices in a
/// single forward pass, so no tokens are generated and the prompt stays tiny.
enum CommandInterpreter {
    private static let noMatchKey = "none"

    private struct Choice {
        let key: String
        let description: String
        let command: TilerCommand
    }

    private static let choices: [Choice] = [
        Choice(key: "layout_dwindle", description: "Dwindle layout: windows spiral, each one half of the remaining space", command: .setLayout(.dwindle)),
        Choice(key: "layout_master", description: "Master layout: one big window beside a stack of the others", command: .setLayout(.master)),
        Choice(key: "layout_columns", description: "Columns layout: equal side-by-side columns", command: .setLayout(.columns)),
        Choice(key: "gap_up", description: "Increase the spacing or gap between windows", command: .adjustGap(Tiler.gapStep)),
        Choice(key: "gap_down", description: "Decrease the spacing or gap between windows", command: .adjustGap(-Tiler.gapStep)),
        Choice(key: "retile", description: "Re-arrange, tidy or fix the windows", command: .smartRetile),
        Choice(key: "retile_active", description: "Snap only the active or focused window back into its tile", command: .retileActive),
        Choice(key: "toggle_float", description: "Float or unfloat the focused window", command: .toggleFloat),
        Choice(key: "promote", description: "Make the focused window the main, largest window", command: .promote),
        Choice(key: "next_monitor", description: "Tile on another monitor or display", command: .nextMonitor),
        Choice(key: "focus_next", description: "Focus the next window", command: .focus(step: 1)),
        Choice(key: "focus_previous", description: "Focus the previous window", command: .focus(step: -1)),
        Choice(key: noMatchKey, description: "The request is unrelated to arranging windows", command: .retile),
    ]

    private static let phrases: [String: TilerCommand] = [
        "retile": .retile, "tile": .retile, "snap": .retileActive, "retile window": .retileActive,
        "smart": .smartRetile, "smart retile": .smartRetile, "smart snap": .smartRetileActive,
        "dwindle": .setLayout(.dwindle), "master": .setLayout(.master), "columns": .setLayout(.columns),
        "float": .toggleFloat, "promote": .promote,
        "next monitor": .nextMonitor, "monitor": .nextMonitor,
        "gap+": .adjustGap(Tiler.gapStep), "gap-": .adjustGap(-Tiler.gapStep),
    ]

    static func interpret(_ text: String) async throws -> TilerCommand {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let command = phrases[normalized] { return command }
        if normalized.hasPrefix("gap "), let pixels = Double(normalized.dropFirst(4)) { return .setGap(CGFloat(pixels)) }
        return try await askModel(normalized)
    }

    private static func askModel(_ text: String) async throws -> TilerCommand {
        let answer = try await D3Client.choose(
            state: text,
            instructions: "Which window-tiling command does the request ask for?",
            criteria: Dictionary(uniqueKeysWithValues: choices.map { ($0.key, $0.description) }))
        guard answer.probability >= D3Client.minimumProbability, answer.choice != noMatchKey,
              let match = choices.first(where: { $0.key == answer.choice }) else {
            throw InterpreterError.notUnderstood(text)
        }
        return match.command
    }
}
