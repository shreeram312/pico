import Carbon
import Foundation
import ServiceManagement

/// User preferences, backed by UserDefaults (API keys live in the Keychain instead).
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    static let languages = [
        "Hindi", "Marathi", "Tamil", "Telugu", "Kannada", "Malayalam", "Bengali", "Gujarati",
        "Punjabi", "Odia", "Assamese", "Urdu", "Nepali", "Konkani", "Maithili", "Sanskrit",
        "English", "Spanish", "French", "German", "Japanese", "Arabic",
    ]

    /// A fixed set of shortcuts to choose from (a full key recorder is on the roadmap).
    /// Raycast and Alfred both default to ⌥ Space, so Pico's default avoids it.
    enum HotkeyPreset: String, CaseIterable, Identifiable {
        case controlOptionSpace, optionSpace, commandShiftSpace, controlOptionP, commandShiftE
        var id: String { rawValue }

        var label: String {
            switch self {
            case .controlOptionSpace: return "⌃⌥ Space"
            case .optionSpace: return "⌥ Space"
            case .commandShiftSpace: return "⌘⇧ Space"
            case .controlOptionP: return "⌃⌥ P"
            case .commandShiftE: return "⌘⇧ E"
            }
        }

        var keyCode: UInt32 {
            switch self {
            case .controlOptionSpace, .optionSpace, .commandShiftSpace: return UInt32(kVK_Space)
            case .controlOptionP: return UInt32(kVK_ANSI_P)
            case .commandShiftE: return UInt32(kVK_ANSI_E)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .controlOptionSpace, .controlOptionP: return UInt32(controlKey | optionKey)
            case .optionSpace: return UInt32(optionKey)
            case .commandShiftSpace, .commandShiftE: return UInt32(cmdKey | shiftKey)
            }
        }
    }

    enum Script: String, CaseIterable, Identifiable {
        case native, roman
        var id: String { rawValue }
        var label: String {
            switch self {
            case .native: return "Native script (e.g. मराठी)"
            case .roman: return "Romanized (e.g. Marathi in English letters)"
            }
        }
    }

    @Published var language: String { didSet { defaults.set(language, forKey: "language") } }
    @Published var script: Script { didSet { defaults.set(script.rawValue, forKey: "script") } }
    @Published var provider: Provider { didSet { defaults.set(provider.rawValue, forKey: "provider") } }
    /// Chosen model per provider, so switching providers remembers each one's model.
    @Published private var modelByProvider: [String: String] { didSet { defaults.set(modelByProvider, forKey: "modelByProvider") } }
    /// Base URL for the custom provider, e.g. http://localhost:11434/v1 for Ollama.
    @Published var customBaseURL: String { didSet { defaults.set(customBaseURL, forKey: "customBaseURL") } }
    @Published var hotkey: HotkeyPreset { didSet { defaults.set(hotkey.rawValue, forKey: "hotkey") } }
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                // Not available when running from `swift run` (no app bundle); fine during development.
            }
        }
    }

    var model: String {
        get { modelByProvider[provider.rawValue] ?? provider.defaultModel }
        set { modelByProvider[provider.rawValue] = newValue.trimmingCharacters(in: .whitespaces) }
    }

    private let defaults = UserDefaults.standard

    private init() {
        language = defaults.string(forKey: "language") ?? "Hindi"
        script = Script(rawValue: defaults.string(forKey: "script") ?? "") ?? .native
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .anthropic
        modelByProvider = defaults.dictionary(forKey: "modelByProvider") as? [String: String] ?? [:]
        customBaseURL = defaults.string(forKey: "customBaseURL") ?? "http://localhost:11434/v1"
        hotkey = HotkeyPreset(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .controlOptionSpace
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// How the user's language should be written, for prompts.
    var languageDescription: String {
        switch script {
        case .native: return "\(language), written in its native script"
        case .roman: return "\(language), written in romanized form (English letters, the way people type it in chat)"
        }
    }
}
