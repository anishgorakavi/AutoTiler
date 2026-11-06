import Carbon.HIToolbox

/// Global hotkeys via Carbon's RegisterEventHotKey, which needs no extra permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    fileprivate var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private static let signature: OSType = 0x4154_494C  // 'ATIL'

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            HotKeyCenter.shared.handlers[id.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// `modifiers` uses Carbon flags (controlKey, optionKey, shiftKey, cmdKey).
    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers),
                                         EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            handlers[id] = handler
        } else {
            NSLog("Autotiler: could not register hotkey (key code %d, status %d)", keyCode, status)
        }
    }
}
