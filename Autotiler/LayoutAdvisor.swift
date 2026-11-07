import CoreGraphics

enum ActiveWindowRole {
    case snap
    case promote
    case float
}

/// Asks d3 the two judgement calls behind "smart" retiling. Only app names and the screen size are sent.
enum LayoutAdvisor {
    private static let maxNames = 12

    static func bestLayout(appNames: [String], screenSize: CGSize) async throws -> LayoutKind? {
        let shape = screenSize.width >= screenSize.height ? "landscape" : "portrait"
        let state = "Monitor \(Int(screenSize.width))x\(Int(screenSize.height)) \(shape). \(appNames.count) windows: "
            + appNames.prefix(maxNames).joined(separator: ", ") + "."
        let answer = try await D3Client.choose(
            state: state,
            instructions: "Which tiling layout suits these windows best?",
            criteria: [
                LayoutKind.dwindle.rawValue: "Several windows of similar importance, tiled evenly in a spiral",
                LayoutKind.master.rawValue: "One main window such as an editor, browser or document, with a few supporting windows",
                LayoutKind.columns.rawValue: "Many similar windows, such as terminals, side by side",
            ])
        guard answer.probability >= D3Client.minimumProbability else { return nil }
        return LayoutKind(rawValue: answer.choice)
    }

    static func role(ofActive appName: String, others: [String]) async throws -> ActiveWindowRole? {
        let state = "Active window: \(appName). Other windows: "
            + (others.isEmpty ? "none" : others.prefix(maxNames).joined(separator: ", ")) + "."
        let answer = try await D3Client.choose(
            state: state,
            instructions: "What should happen to the active window?",
            criteria: [
                "snap": "A normal app window that belongs in the tiled layout",
                "promote": "The main working window that deserves the biggest tile",
                "float": "A small utility app or dialog, such as Calculator, Preview or System Settings, that should float on top instead of being tiled",
            ])
        guard answer.probability >= D3Client.minimumProbability else { return nil }
        switch answer.choice {
        case "snap": return .snap
        case "promote": return .promote
        case "float": return .float
        default: return nil
        }
    }
}
