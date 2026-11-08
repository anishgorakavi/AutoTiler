import Foundation

/// Decides a screen spot for every open window by asking d3 one window at a time.
/// Each step sees what is already placed and is offered only the spots still free, so d3
/// cannot double-book a spot; the last window takes the last spot without a model call.
enum WindowAgent {
    static let maxWindows = 4

    enum Error: LocalizedError {
        case tooManyWindows(Int)

        var errorDescription: String? {
            switch self {
            case .tooManyWindows(let count):
                return "The d3 agent places up to \(maxWindows) windows at a time and \(count) are open. Minimize some, or use ⌃⌥T."
            }
        }
    }

    /// Picks one key from `options` (key, description) for the given situation.
    typealias Chooser = (_ state: String, _ options: [(key: String, description: String)]) async throws -> String

    /// The spots available for a given number of windows.
    static func slots(forCount count: Int) -> [SnapRegion] {
        switch count {
        case 1: return [.maximized]
        case 2: return [.leftHalf, .rightHalf]
        case 3: return [.leftHalf, .topRight, .bottomRight]
        case 4: return [.topLeft, .topRight, .bottomLeft, .bottomRight]
        default: return []
        }
    }

    /// Returns one spot per entry of `appNames`, in the same order.
    static func plan(appNames: [String], choose: Chooser = askD3) async throws -> [SnapRegion] {
        guard appNames.count <= maxWindows else { throw Error.tooManyWindows(appNames.count) }

        var free = slots(forCount: appNames.count)
        let hasMainSlot = Set(free.map(size(of:))).count > 1
        var placed: [(app: String, spot: SnapRegion)] = []

        for (index, app) in appNames.enumerated() {
            var spot = free[0]
            if free.count > 1 {
                let state = "Window \(index + 1) of \(appNames.count): \(app). "
                    + "Still to place: \(appNames.dropFirst(index + 1).joined(separator: ", ")). "
                    + "Already placed: " + (placed.isEmpty ? "nothing" : placed.map { "\($0.app) at \($0.spot.displayName)" }.joined(separator: ", ")) + "."
                let options = free.map { (key: $0.rawValue, description: describe($0, withHints: hasMainSlot)) }
                let key = try await choose(state, options)
                // A key outside the offered spots can only come from a misbehaving model; fall back to the first free spot.
                spot = free.first { $0.rawValue == key } ?? free[0]
            }
            placed.append((app, spot))
            free.removeAll { $0 == spot }
        }
        return placed.map(\.spot)
    }

    private static func askD3(state: String, options: [(key: String, description: String)]) async throws -> String {
        try await D3Client.choose(
            state: state,
            instructions: "Which spot on the screen suits this window best?",
            criteria: Dictionary(uniqueKeysWithValues: options.map { ($0.key, $0.description) })).choice
    }

    private enum SpotSize { case large, small }

    private static func size(of spot: SnapRegion) -> SpotSize {
        switch spot {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return .small
        default: return .large
        }
    }

    /// With mixed sizes (three windows) tell d3 which spot is the big one; otherwise the position name is all there is to say.
    private static func describe(_ spot: SnapRegion, withHints: Bool) -> String {
        let name = spot.displayName.prefix(1).uppercased() + spot.displayName.dropFirst()
        guard withHints else { return name + " of the screen" }
        switch size(of: spot) {
        case .large: return name + ": the main app, such as an editor, browser or document"
        case .small: return name + " corner: a supporting app, such as chat, notes, music or a terminal"
        }
    }
}
