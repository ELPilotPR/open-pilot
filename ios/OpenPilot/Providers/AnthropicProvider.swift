import Foundation

/// Cliente Anthropic (Messages API) con streaming, directo desde el iPhone.
final class AnthropicProvider: ChatProvider {

    private struct Event: Decodable {
        let type: String?
        struct Delta: Decodable { let text: String? }
        let delta: Delta?
        struct Usage: Decodable { let input_tokens: Int?; let output_tokens: Int? }
        let usage: Usage?
        struct Message: Decodable { let usage: Usage? }
        let message: Message?
    }

    func stream(turns: [ChatTurn], model: String, baseURL: String, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let base = trimBase(baseURL.isEmpty ? "https://api.anthropic.com" : baseURL)
                    guard let url = URL(string: base + "/v1/messages") else { throw ProviderError.badURL(base) }
                    var system = ""
                    var msgs: [[String: Any]] = []
                    for t in turns {
                        if t.role == "system" { system += t.content + "\n" }
                        else {
                            let role = t.role == "assistant" ? "assistant" : "user"
                            if t.images.isEmpty {
                                msgs.append(["role": role, "content": t.content])
                            } else {
                                var parts: [[String: Any]] = []
                                for img in t.images {
                                    parts.append(["type": "image",
                                                  "source": ["type": "base64", "media_type": "image/jpeg",
                                                             "data": img.base64EncodedString()]])
                                }
                                parts.append(["type": "text", "text": t.content])
                                msgs.append(["role": role, "content": parts])
                            }
                        }
                    }
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    var body: [String: Any] = ["model": model, "max_tokens": 2048, "stream": true, "messages": msgs]
                    if !system.isEmpty { body["system"] = system.trimmingCharacters(in: .whitespacesAndNewlines) }
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                        var errBody = ""
                        for try await line in bytes.lines { errBody += line; if errBody.count > 400 { break } }
                        throw ProviderError.http(http.statusCode, errBody)
                    }
                    var inTok = 0, outTok = 0
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard let data = payload.data(using: .utf8),
                              let ev = try? JSONDecoder().decode(Event.self, from: data) else { continue }
                        if ev.type == "message_start" { inTok = ev.message?.usage?.input_tokens ?? 0 }
                        if ev.type == "message_delta" { outTok = ev.usage?.output_tokens ?? outTok }
                        if ev.type == "content_block_delta", let t = ev.delta?.text, !t.isEmpty {
                            continuation.yield(.delta(t))
                        }
                        if ev.type == "message_stop" {
                            continuation.yield(.usage(promptTokens: inTok, completionTokens: outTok))
                            continuation.yield(.done); break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func models(baseURL: String, apiKey: String) async throws -> [String] {
        // Anthropic no expone /models público estable; devolvemos un catálogo conocido.
        return ["claude-sonnet-4-5", "claude-opus-4-1", "claude-haiku-4-5"]
    }
}