import Foundation

/// Cliente OpenAI-compatible con streaming SSE, directo desde el iPhone.
/// Sirve para el server local de casa, Ollama, llama.cpp, LM Studio, vLLM,
/// OpenAI, OpenRouter, Together… cualquier cosa que hable POST /chat/completions.
final class OpenAICompatibleProvider: ChatProvider {

    fileprivate struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
                let reasoning_content: String?
            }
            let delta: Delta?
            let finish_reason: String?
        }
        let choices: [Choice]?
        struct Usage: Decodable {
            let prompt_tokens: Int?
            let completion_tokens: Int?
            let total_tokens: Int?
        }
        let usage: Usage?
    }

    private struct ModelsResponse: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]?
    }

    func stream(turns: [ChatTurn], model: String, baseURL: String, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let base = trimBase(baseURL)
            guard let url = URL(string: base + "/chat/completions") else {
                continuation.finish(throwing: ProviderError.badURL(base))
                return
            }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
            let body: [String: Any] = [
                "model": model,
                "stream": true,
                "stream_options": ["include_usage": true],
                "messages": turns.map { turn -> [String: Any] in
                    if turn.images.isEmpty {
                        return ["role": turn.role, "content": turn.content]
                    }
                    var parts: [[String: Any]] = [["type": "text", "text": turn.content]]
                    for img in turn.images {
                        parts.append(["type": "image_url",
                                      "image_url": ["url": "data:image/jpeg;base64,\(img.base64EncodedString())"]])
                    }
                    return ["role": turn.role, "content": parts]
                }
            ]
            do {
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let delegate = SSEDelegate(continuation: continuation)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: req)
            delegate.task = task
            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
            task.resume()
        }
    }

    func models(baseURL: String, apiKey: String) async throws -> [String] {
        let base = trimBase(baseURL)
        guard let url = URL(string: base + "/models") else { throw ProviderError.badURL(base) }
        var req = URLRequest(url: url)
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw ProviderError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return (decoded.data ?? []).map { $0.id }
    }
}

/// Delegate que recibe los bytes del SSE y los convierte en ChatEvent.
/// Patrón fiable tanto en la app iOS como en herramientas CLI.
private final class SSEDelegate: NSObject, URLSessionDataDelegate {
    private let continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    private var buffer = Data()
    private var statusCode = 200
    private var finished = false
    weak var task: URLSessionDataTask?

    init(continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse { statusCode = http.statusCode }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        if statusCode != 200 { return }   // acumula el cuerpo de error hasta completar
        let newline = Data([0x0A])
        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let line = String(data: lineData, encoding: .utf8) { handle(line) }
            if finished { return }
        }
    }

    private func handle(_ line: String) {
        guard line.hasPrefix("data:") else { return }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
            continuation.yield(.done)
            finish()
            return
        }
        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(OpenAICompatibleProvider.Chunk.self, from: data) else { return }
        if let u = chunk.usage {
            continuation.yield(.usage(promptTokens: u.prompt_tokens ?? 0, completionTokens: u.completion_tokens ?? 0))
        }
        guard let choice = chunk.choices?.first else { return }
        if let r = choice.delta?.reasoning_content, !r.isEmpty {
            continuation.yield(.reasoning(r))
        }
        if let c = choice.delta?.content, !c.isEmpty {
            continuation.yield(.delta(c))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if statusCode != 200 {
            let body = String(data: buffer, encoding: .utf8) ?? ""
            continuation.finish(throwing: ProviderError.http(statusCode, body))
            finished = true
            return
        }
        if let error = error {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                finish()
            } else {
                continuation.finish(throwing: ProviderError.transport(error.localizedDescription))
                finished = true
            }
            return
        }
        if !buffer.isEmpty, let rest = String(data: buffer, encoding: .utf8) {
            handle(rest)
        }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        continuation.finish()
    }
}