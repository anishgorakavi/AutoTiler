import AppKit
import ApplicationServices

/// A window reachable through the Accessibility API. Identity is the underlying AXUIElement.
struct ManagedWindow: Hashable {
    let element: AXUIElement

    static func == (lhs: ManagedWindow, rhs: ManagedWindow) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Thin wrapper over the Accessibility API and NSScreen geometry.
/// Accessibility coordinates have their origin at the top-left of the primary display, y growing downward.
enum WindowServer {
    private static let messagingTimeout: Float = 0.25

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func accessibilityFrame(of screen: NSScreen, excludingMenuBarAndDock: Bool) -> CGRect {
        let primaryHeight = NSScreen.screens[0].frame.height
        let rect = excludingMenuBarAndDock ? screen.visibleFrame : screen.frame
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Standard, resizable, non-minimized, non-fullscreen windows whose center lies on `screen`.
    static func tileableWindows(on screen: NSScreen) -> [ManagedWindow] {
        let screenFrame = accessibilityFrame(of: screen, excludingMenuBarAndDock: false)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: [ManagedWindow] = []

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != ownPID {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
            guard let windows: [AXUIElement] = attribute(appElement, kAXWindowsAttribute) else { continue }

            for element in windows where isTileable(element) {
                let window = ManagedWindow(element: element)
                guard let frame = frame(of: window), screenFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) else { continue }
                result.append(window)
            }
        }
        return result
    }

    static func focusedWindow() -> ManagedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        guard let element: AXUIElement = attribute(appElement, kAXFocusedWindowAttribute) else { return nil }
        return ManagedWindow(element: element)
    }

    static func appName(of window: ManagedWindow) -> String {
        var pid: pid_t = 0
        AXUIElementGetPid(window.element, &pid)
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "Unknown"
    }

    static func frame(of window: ManagedWindow) -> CGRect? {
        guard let positionValue: AXValue = attribute(window.element, kAXPositionAttribute),
              let sizeValue: AXValue = attribute(window.element, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func setFrame(_ frame: CGRect, of window: ManagedWindow) {
        var origin = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        // Size first so a shrinking window is not clamped by its old origin; again after moving
        // because some apps clamp the first resize against the screen edge.
        AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue)
    }

    static func focus(_ window: ManagedWindow) {
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        var pid: pid_t = 0
        AXUIElementGetPid(window.element, &pid)
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    private static func isTileable(_ element: AXUIElement) -> Bool {
        guard let role: String = attribute(element, kAXRoleAttribute), role == kAXWindowRole,
              let subrole: String = attribute(element, kAXSubroleAttribute), subrole == kAXStandardWindowSubrole,
              let minimized: Bool = attribute(element, kAXMinimizedAttribute), !minimized else { return false }
        if let fullScreen: Bool = attribute(element, "AXFullScreen"), fullScreen { return false }

        var resizable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &resizable)
        return resizable.boolValue
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
