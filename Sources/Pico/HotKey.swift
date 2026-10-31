import Carbon

/// A single global hotkey, registered with the Carbon hotkey API (still the simplest way to get a
/// system-wide shortcut without the Input Monitoring permission).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let callback: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().callback()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x5049_434F), id: 1) // "PICO"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            // Usually another app (Raycast, Alfred…) already owns this combination.
            Log.app.error("Could not register hotkey (keyCode \(keyCode), modifiers \(modifiers)): OSStatus \(status)")
        } else {
            Log.app.notice("Registered hotkey keyCode \(keyCode), modifiers \(modifiers)")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
