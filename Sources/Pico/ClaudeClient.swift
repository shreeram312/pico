import Foundation

/// Streaming client for the Claude Messages API. Calls go straight from this Mac to
/// api.anthropic.com with the user's own key; there is no Pico server.
struct ClaudeClient: LLMClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

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
        guard let http = response as? HTTPURLResponse else { throw LLMError.stream("No response") }
        if http.statusCode != 200 {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            throw LLMError.http(http.statusCode, LLM.errorMessage(from: raw))
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
                    throw LLMError.refused(details?["explanation"] as? String)
                }
            case "error":
                let error = event["error"] as? [String: Any]
                throw LLMError.stream(error?["message"] as? String ?? "Stream error")
            default:
                break
            }
        }
    }
}
