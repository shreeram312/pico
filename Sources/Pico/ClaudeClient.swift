import Foundation

/// Minimal streaming client for the Claude Messages API. Calls go straight from this Mac to
/// api.anthropic.com with the user's own key; there is no Pico server.
struct ClaudeClient {
    enum ClaudeError: LocalizedError {
        case noAPIKey
        case http(Int, String)
        case refused(String?)
        case stream(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Add your Anthropic API key in Settings."
            case .http(401, _): return "Invalid API key. Check it in Settings."
            case .http(429, _): return "Rate limited. Try again in a moment."
            case let .http(status, message): return "API error \(status): \(message)"
            case let .refused(reason): return "The model declined this request." + (reason.map { " \($0)" } ?? "")
            case let .stream(message): return message
            }
        }
    }

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    let apiKey: String
    let model: String

    /// Streams the text of the response as it is generated.
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
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Lets the API retry on another model if a safety classifier declines the request.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "fallbacks": "default",
            // Short, mechanical text edits: keep thinking light so the popup feels instant.
            "output_config": ["effort": "low"],
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.stream("No response") }
        if http.statusCode != 200 {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            let message = (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? raw
            throw ClaudeError.http(http.statusCode, message)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: "),
                  let data = line.dropFirst(6).data(using: .utf8),
                  let event = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String
            else { continue }

            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    onText(text)
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["stop_reason"] as? String == "refusal" {
                    let details = delta["stop_details"] as? [String: Any]
                    throw ClaudeError.refused(details?["explanation"] as? String)
                }
            case "error":
                let error = event["error"] as? [String: Any]
                throw ClaudeError.stream(error?["message"] as? String ?? "Stream error")
            default:
                break
            }
        }
    }
}
