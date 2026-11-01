import AppKit
import SwiftUI

/// Drives the popup: captures the selection, runs actions, replaces text.
@MainActor
final class PopupModel: ObservableObject {
    enum Phase { case needsPermission, noSelection, choosing, running, done }

    @Published var phase: Phase = .noSelection
    @Published var text = ""
    @Published var result = ""
    @Published var error: String?
    @Published var action: Action?

    var actions: [Action] { Actions.visible(for: text) }
    var onClose: () -> Void = {}

    private var selection: SelectionService.Selection?
    private var task: Task<Void, Never>?

    func load(_ selection: SelectionService.Selection) {
        task?.cancel()
        self.selection = selection
        text = selection.text
        result = ""
        error = nil
        action = nil
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = SelectionService.isAccessibilityTrusted() ? .noSelection : .needsPermission
        } else {
            phase = .choosing
        }
    }

    func openAccessibilitySettings() {
        SelectionService.openAccessibilitySettings()
        onClose()
    }

    func run(_ action: Action) {
        let client: LLMClient
        do {
            client = try LLM.makeClient(settings: Settings.shared)
        } catch {
            self.error = error.localizedDescription
            return
        }
        self.action = action
        result = ""
        error = nil
        phase = .running

        let message = Actions.userMessage(for: action, text: text, settings: Settings.shared)
        task?.cancel()
        task = Task {
            do {
                for try await chunk in client.stream(system: Actions.systemPrompt, user: message) {
                    result += chunk
                }
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                phase = .done
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
                phase = .done
            }
        }
    }

    func back() {
        task?.cancel()
        result = ""
        error = nil
        action = nil
        phase = .choosing
    }

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
        onClose()
    }

    func replace() {
        guard let selection, !result.isEmpty else { return }
        let result = result
        onClose()
        Task { await SelectionService.replace(selection, with: result) }
    }

    func cancel() {
        task?.cancel()
        onClose()
    }
}

/// A floating panel that never steals focus from the app the user is working in.
final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { (delegate as? PopupController)?.close() }
}

@MainActor
final class PopupController: NSObject, NSWindowDelegate {
    private let model = PopupModel()
    private lazy var panel: PopupPanel = {
        let panel = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: PopupView(model: model))
        return panel
    }()

    override init() {
        super.init()
        model.onClose = { [weak self] in self?.close() }
    }

    func show() async {
        if panel.isVisible {
            close()
            return
        }
        let selection = await SelectionService.capture()
        model.load(selection)
        position()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clicking back into the target app dismisses the popup, unless a result is waiting.
        if [.needsPermission, .noSelection, .choosing].contains(model.phase) { close() }
    }

    /// Place the panel just below the mouse pointer, kept inside the screen.
    private func position() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - 40, y: mouse.y - size.height - 12)
        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        if origin.y < visible.minY + 8 { origin.y = mouse.y + 12 }
        panel.setFrameOrigin(origin)
    }
}
