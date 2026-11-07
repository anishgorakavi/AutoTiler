import AppKit

enum TilerCommand: Equatable {
    case retile
    case retileActive
    case smartRetile
    case smartRetileActive
    case setLayout(LayoutKind)
    case cycleLayout
    case setGap(CGFloat)
    case adjustGap(CGFloat)
    case nextMonitor
    case toggleFloat
    case promote
    case swap(step: Int)
    case focus(step: Int)
}

/// Owns the tiling state (layout, gap, window order, floating set, target monitor) and applies it.
/// Windows are only arranged in response to an explicit command; nothing re-tiles on its own.
final class Tiler {
    static let gapRange: ClosedRange<CGFloat> = 0...64
    static let gapStep: CGFloat = 4

    private(set) var layout: LayoutKind = .dwindle
    private(set) var gap: CGFloat = 8

    private var order: [ManagedWindow] = []
    private var floating: Set<ManagedWindow> = []
    private var pinnedFocus: ManagedWindow?

    private static let monitorDefaultsKey = "targetDisplayID"

    var targetScreen: NSScreen {
        let stored = UserDefaults.standard.object(forKey: Self.monitorDefaultsKey) as? UInt32
        return NSScreen.screens.first { WindowServer.displayID(of: $0) == stored } ?? NSScreen.screens[0]
    }

    func setTargetScreen(_ screen: NSScreen) {
        guard let id = WindowServer.displayID(of: screen) else { return }
        UserDefaults.standard.set(id, forKey: Self.monitorDefaultsKey)
        retile()
    }

    /// Remember the focused window before our own prompt steals focus, so commands act on the right one.
    func pinFocus() {
        pinnedFocus = WindowServer.focusedWindow()
    }

    func perform(_ command: TilerCommand) {
        defer { pinnedFocus = nil }
        switch command {
        case .retile: break
        case .retileActive:
            syncOrder()
            guard let window = pinnedFocus ?? WindowServer.focusedWindow(),
                  let slot = slots().first(where: { $0.window == window }) else { return }
            place(slot.window, at: slot.frame)
            return
        case .smartRetile:
            syncOrder()
            smartRetile(appNames: tiledWindows().map(WindowServer.appName))
            return
        case .smartRetileActive:
            syncOrder()
            guard let window = pinnedFocus ?? WindowServer.focusedWindow() else { return }
            smartRetileActive(window)
            return
        case .setLayout(let kind): layout = kind
        case .cycleLayout:
            let all = LayoutKind.allCases
            layout = all[(all.firstIndex(of: layout)! + 1) % all.count]
        case .setGap(let value): gap = min(max(value, Self.gapRange.lowerBound), Self.gapRange.upperBound)
        case .adjustGap(let delta): gap = min(max(gap + delta, Self.gapRange.lowerBound), Self.gapRange.upperBound)
        case .nextMonitor:
            let screens = NSScreen.screens
            let current = screens.firstIndex(of: targetScreen) ?? 0
            setTargetScreen(screens[(current + 1) % screens.count])
            return
        case .toggleFloat:
            guard let window = pinnedFocus ?? WindowServer.focusedWindow() else { return }
            if !floating.insert(window).inserted { floating.remove(window) }
        case .promote:
            syncOrder()
            guard let window = pinnedFocus ?? WindowServer.focusedWindow(), let index = order.firstIndex(of: window) else { return }
            order.insert(order.remove(at: index), at: 0)
        case .swap(let step):
            syncOrder()
            let tiled = tiledWindows()
            guard let window = pinnedFocus ?? WindowServer.focusedWindow(), let index = tiled.firstIndex(of: window), tiled.count > 1,
                  let a = order.firstIndex(of: window), let b = order.firstIndex(of: tiled[(index + step + tiled.count) % tiled.count]) else { return }
            order.swapAt(a, b)
        case .focus(let step):
            syncOrder()
            let tiled = tiledWindows()
            guard let window = pinnedFocus ?? WindowServer.focusedWindow(), let index = tiled.firstIndex(of: window), tiled.count > 1 else { return }
            WindowServer.focus(tiled[(index + step + tiled.count) % tiled.count])
            return
        }
        retile()
    }

    /// d3 picks the layout that suits the open apps; the geometry is still computed locally.
    private func smartRetile(appNames: [String]) {
        let screenSize = targetScreen.frame.size
        Task { @MainActor in
            do {
                if let kind = try await LayoutAdvisor.bestLayout(appNames: appNames, screenSize: screenSize) { layout = kind }
            } catch {
                NSSound.beep()  // d3 unreachable: still retile with the current layout
            }
            retile()
        }
    }

    /// d3 decides whether the active window snaps into its tile, becomes the master, or floats.
    private func smartRetileActive(_ window: ManagedWindow) {
        let others = tiledWindows().filter { $0 != window }.map(WindowServer.appName)
        Task { @MainActor in
            let role: ActiveWindowRole?
            do {
                role = try await LayoutAdvisor.role(ofActive: WindowServer.appName(of: window), others: others)
            } catch {
                NSSound.beep()
                role = nil
            }
            switch role ?? .snap {
            case .snap:
                if let slot = slots().first(where: { $0.window == window }) { place(slot.window, at: slot.frame) }
            case .promote:
                if let index = order.firstIndex(of: window) { order.insert(order.remove(at: index), at: 0) }
                retile()
            case .float:
                floating.insert(window)
                retile()
            }
        }
    }

    func retile() {
        guard AXIsProcessTrusted() else { return }
        syncOrder()
        for slot in slots() { place(slot.window, at: slot.frame) }
    }

    /// The frame each tiled window should occupy under the current layout and gap.
    private func slots() -> [(window: ManagedWindow, frame: CGRect)] {
        let tiled = tiledWindows()
        let area = WindowServer.accessibilityFrame(of: targetScreen, excludingMenuBarAndDock: true)
        let frames = TilingLayout.frames(count: tiled.count, in: area, kind: layout, gap: gap)
        return Array(zip(tiled, frames)).map { (window: $0, frame: $1) }
    }

    private func place(_ window: ManagedWindow, at target: CGRect) {
        if let current = WindowServer.frame(of: window), current.isApproximatelyEqual(to: target) { return }
        WindowServer.setFrame(target.integral, of: window)
    }

    /// Keeps existing windows in place and appends new ones, so a closing window does not reshuffle the rest.
    private func syncOrder() {
        let present = WindowServer.tileableWindows(on: targetScreen)
        let presentSet = Set(present)
        order = order.filter(presentSet.contains) + present.filter { !order.contains($0) }
        floating.formIntersection(presentSet)
    }

    private func tiledWindows() -> [ManagedWindow] {
        order.filter { !floating.contains($0) }
    }
}

private extension CGRect {
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}
