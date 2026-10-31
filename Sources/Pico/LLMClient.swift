import Foundation

/// Streams the text of one completion for a system prompt + user message.
protocol LLMClient {
    func stream(system: String, user: String) -> AsyncThrowingStream<String, Error>
}

enum LLMError: LocalizedError {
    case noAPIKey(Provider)
    case badBaseURL
    case http(Int, String)
    case refused(String?)
    case stream(String)

    var errorDescription: String? {
        switch self {
        case let .noAPIKey(provider): return "Add your \(provider.name) API key in Settings."
        case .badBaseURL: return "Set a valid base URL for the custom provider in Settings."
        case .http(401, _), .http(403, _): return "Invalid API key. Check it in Settings."
        case .http(429, _): return "Rate limited. Try again in a moment."
        case let .http(status, message): return "API error \(status): \(message)"
        case let .refused(reason): return "The model declined this request." + (reason.map { " \($0)" } ?? "")
        case let .stream(message): return message
        }
    }
}

enum LLM {
    /// Builds the client for the provider chosen in Settings.
    @MainActor
    static func makeClient(settings: Settings) throws -> LLMClient {
        let provider = settings.provider
        let key = Keychain.apiKey(for: provider) ?? ""
        if provider.needsKey, key.isEmpty { throw LLMError.noAPIKey(provider) }

        switch provider {
        case .anthropic:
            return ClaudeClient(apiKey: key, model: settings.model)
        case .custom:
            guard let base = URL(string: settings.customBaseURL.trimmingCharacters(in: .whitespaces)),
                  base.scheme != nil
            else { throw LLMError.badBaseURL }
            let endpoint = base.appendingPathComponent("chat/completions")
            return OpenAICompatibleClient(endpoint: endpoint, apiKey: key, model: settings.model)
        default:
            return OpenAICompatibleClient(endpoint: provider.endpoint!, apiKey: key, model: settings.model)
        }
    }

    /// Reads `error.message` from a JSON error body, or returns the raw text.
    static func errorMessage(from raw: String) -> String {
        (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            .flatMap { $0["error"] as? [String: Any] }
            .flatMap { $0["message"] as? String } ?? raw
    }
}

/// OpenAI chat-completions streaming, as spoken by OpenAI, xAI, Gemini's compatibility endpoint,
/// Ollama, LM Studio and most other servers.
struct OpenAICompatibleClient: LLMClient {
    let endpoint: URL
    let apiKey: String
    let model: String

    func stream(system: String, user: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, user: user) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, user: String, onText: (String) -> Void) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.stream("No response") }
        if http.statusCode != 200 {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            throw LLMError.http(http.statusCode, LLM.errorMessage(from: raw))
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = line.dropFirst(6)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let event = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let error = event["error"] as? [String: Any] {
                throw LLMError.stream(error["message"] as? String ?? "Stream error")
            }
            guard let choice = (event["choices"] as? [[String: Any]])?.first else { continue }
            let delta = choice["delta"] as? [String: Any]
            if let refusal = delta?["refusal"] as? String, !refusal.isEmpty {
                throw LLMError.refused(refusal)
            }
            if let text = delta?["content"] as? String, !text.isEmpty {
                onText(text)
            }
        }
    }
}
