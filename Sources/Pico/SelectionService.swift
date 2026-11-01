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
        /// The app that owned the focus, so the paste fallback can bring it back to the front.
        let pid: pid_t?
        /// Where the selection was, so it can be restored before pasting if the app dropped it.
        let range: CFRange?
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
        let pid = element.flatMap(pid(of:))
        let range = element.flatMap(selectedRange(of:))
        if let element, let text = selectedText(of: element), !text.isEmpty {
            Log.app.notice("Selection via Accessibility (\(text.count) chars, pid \(pid ?? 0))")
            return Selection(text: text, element: element, pid: pid, range: range)
        }
        let text = await copyViaKeyboard() ?? ""
        Log.app.notice("Selection via ⌘C fallback: \(text.count) chars; trusted: \(trusted); focused element: \(element != nil)")
        return Selection(text: text, element: element, pid: pid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier, range: range)
    }

    private static func focusedElement() -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    private static func selectedText(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private static func wholeText(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private static func selectedRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }

    private static func select(_ range: CFRange, in element: AXUIElement) {
        var range = range
        if let value = AXValueCreate(.cfRange, &range) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        }
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
        if let element = selection.element {
            let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
            // Some apps (WhatsApp's Catalyst build, among others) report success without changing
            // anything, so trust the call only when the new text is actually in the field.
            if status == .success, wholeText(of: element)?.contains(text) == true {
                Log.app.notice("Replaced via Accessibility")
                return
            }
            Log.app.notice("Accessibility replace not applied (status \(status.rawValue)); pasting instead")
        }
        await pasteViaKeyboard(text, into: selection)
    }

    static func pasteViaKeyboard(_ text: String, into selection: Selection? = nil) async {
        // Make sure the keystroke lands in the app that had the selection, with the selection back
        // in place: opening the popup can make some apps drop it, and pasting would then insert.
        if let pid = selection?.pid, let app = NSRunningApplication(processIdentifier: pid), !app.isActive {
            app.activate()
            try? await Task.sleep(for: .milliseconds(150))
        }
        if let element = selection?.element, let range = selection?.range {
            select(range, in: element)
        }

        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postKey(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        Log.app.notice("Pasted via ⌘V into pid \(selection?.pid ?? 0)")
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
