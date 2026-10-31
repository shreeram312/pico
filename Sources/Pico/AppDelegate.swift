import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var hotkeyObserver: AnyCancellable?
    private let popup = PopupController()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerHotkey(Settings.shared.hotkey)
        hotkeyObserver = Settings.shared.$hotkey
            .dropFirst()
            .sink { [weak self] preset in self?.registerHotkey(preset) }
        Log.app.notice("Pico launched; accessibility trusted: \(SelectionService.isAccessibilityTrusted())")
        // Until setup is complete, open Settings so a first launch always shows something
        // (menu bar icons can be hidden behind the notch).
        let provider = Settings.shared.provider
        if !SelectionService.isAccessibilityTrusted() || (provider.needsKey && !Keychain.hasAPIKey(for: provider)) {
            showSettings()
        }
        if !SelectionService.isAccessibilityTrusted() {
            SelectionService.requestAccessibility()
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

    private func registerHotkey(_ preset: Settings.HotkeyPreset) {
        hotKey = nil // unregister the previous one first
        hotKey = HotKey(keyCode: preset.keyCode, modifiers: preset.modifiers) { [weak self] in
            self?.trigger()
        }
        statusItem.menu?.item(at: 0)?.title = "Pico on selected text (\(preset.label))"
    }

    private func trigger() {
        Log.app.notice("Triggered")
        Task { await popup.show() }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
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
