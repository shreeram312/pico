import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        Form {
            Section("AI provider") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if settings.provider.needsKey {
                    APIKeyField(provider: settings.provider)
                        .id(settings.provider) // reset the field when switching providers
                } else {
                    TextField("Base URL", text: $settings.customBaseURL, prompt: Text("http://localhost:11434/v1"))
                    Text("Any OpenAI-compatible server: Ollama, LM Studio, vLLM, OpenRouter…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Model", text: modelBinding)
                        .font(.body.monospaced())
                    Menu("Presets") {
                        ForEach(settings.provider.models, id: \.id) { preset in
                            Button(preset.name) { settings.model = preset.id }
                        }
                    }
                    .fixedSize()
                }

                Text("Keys are stored only in your Mac's Keychain. Requests go directly to the provider; Pico has no server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("My language") {
                Picker("Language", selection: $settings.language) {
                    ForEach(Settings.languages, id: \.self) { Text($0) }
                }
                Picker("Write it as", selection: $settings.script) {
                    ForEach(Settings.Script.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text("Used by “To my language” and “Explain”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Picker("Shortcut", selection: $settings.hotkey) {
                    ForEach(Settings.HotkeyPreset.allCases) { Text($0.label).tag($0) }
                }
                Text("Raycast and Alfred use ⌥ Space by default; pick another one if Pico doesn't open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                HStack {
                    Text(SelectionService.isAccessibilityTrusted() ? "Accessibility: allowed" : "Accessibility: not allowed")
                    Spacer()
                    Button("Open System Settings") { SelectionService.openAccessibilitySettings() }
                }
                Text("Pico needs Accessibility access to read the text you select and to replace it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Custom actions") {
                Text("Add your own actions as JSON at:")
                    .font(.footnote)
                HStack {
                    Text(Actions.customActionsURL.path)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Spacer()
                    Button("Reveal") { revealCustomActions() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
    }

    private var modelBinding: Binding<String> {
        Binding(get: { settings.model }, set: { settings.model = $0 })
    }

    private func revealCustomActions() {
        let url = Actions.customActionsURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            let example = [Action(id: "whatsapp", title: "WhatsApp style", icon: "message",
                                  prompt: "Rewrite this as a friendly WhatsApp message in {{language}}, with one or two fitting emoji.")]
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try? encoder.encode(example).write(to: url)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

/// API key entry for one provider. Never reads the key itself (that can prompt for the keychain
/// password); only whether one exists.
private struct APIKeyField: View {
    let provider: Provider
    @State private var hasKey: Bool
    @State private var input = ""
    @State private var saved = false

    init(provider: Provider) {
        self.provider = provider
        _hasKey = State(initialValue: Keychain.hasAPIKey(for: provider))
    }

    var body: some View {
        SecureField("API key", text: $input, prompt: Text(hasKey ? "Key saved. Paste a new one to replace it." : "Paste your \(provider.name) API key"))
            .onSubmit(save)
        HStack {
            Button("Save") { save() }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            if saved {
                Text("Saved to Keychain").foregroundStyle(.secondary)
            } else if hasKey {
                Text("A key is saved").foregroundStyle(.secondary)
            }
            Spacer()
            if let url = provider.keyURL {
                Link("Get a key", destination: url)
            }
        }
    }

    private func save() {
        Keychain.setAPIKey(input, for: provider)
        hasKey = true
        input = ""
        saved = true
    }
}
