import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var apiKey = Keychain.apiKey() ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("Anthropic API key") {
                SecureField("sk-ant-…", text: $apiKey)
                    .onSubmit(saveKey)
                HStack {
                    Button("Save") { saveKey() }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces) == (Keychain.apiKey() ?? ""))
                    if saved { Text("Saved to Keychain").foregroundStyle(.secondary) }
                    Spacer()
                    Link("Get a key", destination: URL(string: "https://platform.claude.com/settings/keys")!)
                }
                Text("Stored only in your Mac's Keychain. Requests go directly to Anthropic; Pico has no server.")
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

            Section("Model") {
                Picker("Model", selection: $settings.model) {
                    ForEach(Settings.models, id: \.id) { Text($0.name).tag($0.id) }
                }
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
        .frame(width: 480, height: 520)
    }

    private func saveKey() {
        Keychain.setAPIKey(apiKey)
        saved = true
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
