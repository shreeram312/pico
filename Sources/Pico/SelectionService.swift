import AppKit
import ApplicationServices
import Carbon

/// Reads and replaces the selected text in whatever app is frontmost.
///
/// Native apps expose the selection through the Accessibility API. Many Electron and web apps
/// don't, so we fall back to simulating ⌘C / ⌘V through the pasteboard and restoring it afterwards.
enum SelectionService {
    struct Selection {
        let text: String
        /// The focused element at capture time; replacement goes back to this element.
        let element: AXUIElement?
    }

    // MARK: Permission

    static func isAccessibilityTrusted() -> Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Read

    static func capture() async -> Selection {
        let trusted = isAccessibilityTrusted()
        let element = focusedElement()
        if let element, let text = selectedText(of: element), !text.isEmpty {
            Log.app.notice("Selection via Accessibility (\(text.count) chars)")
            return Selection(text: text, element: element)
        }
        let text = await copyViaKeyboard() ?? ""
        Log.app.notice("Selection via ⌘C fallback: \(text.count) chars; trusted: \(trusted); focused element: \(element != nil)")
        return Selection(text: text, element: element)
    }

    private static func focusedElement() -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func selectedText(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private static func copyViaKeyboard() async -> String? {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        let changeCount = pasteboard.changeCount

        postKey(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        // Electron apps can take a few hundred ms to service the copy; poll instead of a fixed wait.
        for _ in 0..<12 where pasteboard.changeCount == changeCount {
            try? await Task.sleep(for: .milliseconds(50))
        }

        guard pasteboard.changeCount != changeCount else { return nil }
        let copied = pasteboard.string(forType: .string)
        if let previous {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
        return copied
    }

    // MARK: Write

    static func replace(_ selection: Selection, with text: String) async {
        if let element = selection.element,
           AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
            return
        }
        await pasteViaKeyboard(text)
    }

    static func pasteViaKeyboard(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postKey(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        try? await Task.sleep(for: .milliseconds(250))

        if let previous {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }

    private static func postKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
