import Foundation

/// An AI provider the user can bring their own key for. Anthropic uses its native API; the others
/// all speak the OpenAI chat-completions format, including any local server (Ollama, LM Studio).
enum Provider: String, CaseIterable, Identifiable, Codable {
    case anthropic, openai, xai, gemini, custom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .xai: return "Grok (xAI)"
        case .gemini: return "Gemini"
        case .custom: return "Custom / local"
        }
    }

    /// Chat-completions endpoint for OpenAI-compatible providers; nil for Anthropic and Custom
    /// (Custom takes the base URL from Settings).
    var endpoint: URL? {
        switch self {
        case .anthropic, .custom: return nil
        case .openai: return URL(string: "https://api.openai.com/v1/chat/completions")
        case .xai: return URL(string: "https://api.x.ai/v1/chat/completions")
        case .gemini: return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        }
    }

    var keyURL: URL? {
        switch self {
        case .anthropic: return URL(string: "https://platform.claude.com/settings/keys")
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .xai: return URL(string: "https://console.x.ai")
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")
        case .custom: return nil
        }
    }

    var needsKey: Bool { self != .custom }

    /// Suggested models; the model field in Settings accepts any id.
    var models: [(id: String, name: String)] {
        switch self {
        case .anthropic:
            return [
                ("claude-opus-5-5", "Claude Opus 5.5 — best"),
                ("claude-sonnet-5-5", "Claude Sonnet 5.5 — fast"),
                ("claude-haiku-5-5", "Claude Haiku 5.5 — cheapest"),
            ]
        case .openai:
            return [
                ("gpt-6.1-sol", "GPT-6.1 Sol — balanced"),
                ("gpt-6-astra", "GPT-6 Astra — best"),
                ("gpt-6-luna", "GPT-6 Luna — cheapest"),
            ]
        case .xai:
            return [
                ("grok-4.7", "Grok 4.7 — best"),
                ("grok-4.3", "Grok 4.3 — cheaper"),
            ]
        case .gemini:
            return [
                ("gemini-3.8-flash", "Gemini 3.8 Flash — fast"),
                ("gemini-4-argon", "Gemini 4 Argon — best"),
                ("gemini-3.5-flash-lite", "Gemini 3.5 Flash-Lite — cheapest"),
            ]
        case .custom:
            return [("llama3.2", "e.g. llama3.2 (Ollama)")]
        }
    }

    var defaultModel: String { models[0].id }
}
