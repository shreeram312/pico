import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private let popup = PopupController()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        // ⌥ Space. Hotkey customisation is on the roadmap; see Settings.
        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            self?.trigger()
        }
        if !SelectionService.isAccessibilityTrusted() {
            SelectionService.requestAccessibility()
        }
        if Keychain.apiKey() == nil {
            showSettings()
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Pico")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "Pico on selected text", action: #selector(menuTrigger), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Accessibility permission…", action: #selector(menuAccessibility), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pico", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func menuTrigger() {
        // The menu click moved focus to the menu bar; give it a moment to return to the target app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.trigger() }
    }

    @objc private func menuSettings() { showSettings() }

    @objc private func menuAccessibility() {
        SelectionService.requestAccessibility()
        SelectionService.openAccessibilitySettings()
    }

    // MARK: - Actions

    private func trigger() {
        Task { await popup.show() }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Pico Settings"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
