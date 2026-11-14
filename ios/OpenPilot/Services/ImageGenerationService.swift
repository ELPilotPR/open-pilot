import Foundation
import UIKit

enum ImageGenError: LocalizedError {
    case badURL(String)
    case http(Int, String)
    case empty
    var errorDescription: String? {
        switch self {
        case .badURL(let s): return "URL inválida: \(s)"
        case .http(let c, let b): return "HTTP \(c): \(b.prefix(300))"
        case .empty: return "El proveedor no devolvió ninguna imagen."
        }
    }
}

/// Generacion de imagenes 100% cliente (sin backend). Dos rutas:
///  - OpenAI-compatible: POST {base}/images/generations (b64_json o url).
///  - DashScope/Qwen nativo: POST {root}/api/v1/services/aigc/multimodal-generation/generation
///    (el token plan de Qwen NO sirve imagenes en la ruta OpenAI; usa esta). Modelo wan2.7-image.
struct ImageGenerationService {
    static func generate(prompt: String, model: String, baseURL: String, apiKey: String,
                         size: String = "1024x1024") async throws -> Data {
        let base = trimBase(baseURL)
        if isDashScope(base) {
            return try await dashscope(prompt: prompt, model: model, base: base, apiKey: apiKey, size: size)
        }
        do {
            return try await openAI(prompt: prompt, model: model, base: base, apiKey: apiKey, size: size)
        } catch let ImageGenError.http(code, _) where code == 404 {
            // server OpenAI-compatible sin /images/generations -> probar ruta nativa DashScope
            return try await dashscope(prompt: prompt, model: model, base: base, apiKey: apiKey, size: size)
        }
    }

    /// Chequeo real y barato (GET /models): detecta si el proveedor ofrece modelos de imagen.
    /// DashScope siempre true (wan2.7-image nativo aunque /models no lo liste).
    static func probeImageSupport(baseURL: String, apiKey: String) async -> Bool {
        let base = trimBase(baseURL)
        if isDashScope(base) { return true }
        guard let url = URL(string: base + "/models") else { return false }
        var req = URLRequest(url: url)
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        req.timeoutInterval = 10
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]] else {
            let h = (URL(string: base)?.host ?? "").lowercased()
            return h.contains("openai.com")
        }
        let ids = arr.compactMap { ($0["id"] as? String)?.lowercased() }
        let patterns = ["dall-e", "gpt-image", "wanx", "wan2", "wan-", "flux",
                        "stable-diffusion", "sdxl", "sd3", "imagen", "cogview", "kolors", "playground"]
        return ids.contains { id in patterns.contains { id.contains($0) } }
    }

    // MARK: - OpenAI-compatible

    private static func openAI(prompt: String, model: String, base: String, apiKey: String,
                               size: String) async throws -> Data {
        guard let url = URL(string: base + "/images/generations") else { throw ImageGenError.badURL(base) }
        var body: [String: Any] = ["model": model, "prompt": prompt, "n": 1,
                                   "size": size, "response_format": "b64_json"]
        do {
            return try await postImages(url: url, body: body, apiKey: apiKey)
        } catch let ImageGenError.http(code, _) where code == 400 {
            // gpt-image-1 no acepta response_format -> reintentar sin el
            body.removeValue(forKey: "response_format")
            return try await postImages(url: url, body: body, apiKey: apiKey)
        }
    }

    private static func postImages(url: URL, body: [String: Any], apiKey: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw ImageGenError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]], let first = arr.first else {
            throw ImageGenError.empty
        }
        if let b64 = first["b64_json"] as? String, let d = Data(base64Encoded: b64) { return d }
        if let urlStr = first["url"] as? String, let u = URL(string: urlStr) {
            let (imgData, _) = try await URLSession.shared.data(from: u)
            return imgData
        }
        throw ImageGenError.empty
    }

    // MARK: - DashScope / Qwen nativo (token plan)

    private static func isDashScope(_ base: String) -> Bool {
        let h = (URL(string: base)?.host ?? base).lowercased()
        return h.contains("aliyuncs") || h.contains("dashscope")
    }

    /// scheme://host del baseURL configurado (quita /compatible-mode/v1, /v1, etc.)
    private static func hostRoot(_ base: String) -> String {
        if let u = URL(string: base), let s = u.scheme, let h = u.host { return "\(s)://\(h)" }
        return base
    }

    private static func dashscope(prompt: String, model: String, base: String, apiKey: String,
                                  size: String) async throws -> Data {
        // El plan de Qwen usa wan2.7-image; si viene un modelo OpenAI por defecto, mapearlo.
        var m = model
        let openAIDefaults = ["dall-e-3", "dall-e-2", "gpt-image-1"]
        if m.isEmpty || openAIDefaults.contains(m.lowercased()) { m = "wan2.7-image" }
        let dsSize = size.replacingOccurrences(of: "x", with: "*")   // DashScope usa W*H
        let root = hostRoot(base)
        guard let url = URL(string: root + "/api/v1/services/aigc/multimodal-generation/generation") else {
            throw ImageGenError.badURL(root)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        req.timeoutInterval = 90
        let body: [String: Any] = [
            "model": m,
            "input": ["messages": [["role": "user", "content": [["text": prompt]]]]],
            "parameters": ["size": dsSize]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw ImageGenError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageGenError.empty
        }
        if let code = obj["code"] as? String, !code.isEmpty {
            throw ImageGenError.http(200, "\(code): \(obj["message"] as? String ?? "")")
        }
        // output.choices[0].message.content[] -> {image: url} o {url: ...}
        if let output = obj["output"] as? [String: Any],
           let choices = output["choices"] as? [[String: Any]],
           let msg = choices.first?["message"] as? [String: Any],
           let items = msg["content"] as? [[String: Any]] {
            for item in items {
                let ref = (item["image"] as? String) ?? (item["url"] as? String)
                guard let ref, !ref.isEmpty else { continue }
                if ref.hasPrefix("data:"), let comma = ref.firstIndex(of: ","),
                   let d = Data(base64Encoded: String(ref[ref.index(after: comma)...])) {
                    return d
                }
                if let u = URL(string: ref) {
                    let (imgData, _) = try await URLSession.shared.data(from: u)   // URL OSS efimera -> descargar
                    return imgData
                }
            }
        }
        throw ImageGenError.empty
    }
}

/// Redimensiona/comprime una foto antes de mandarla como base64 (vision).
enum ImageUtils {
    static func compress(_ data: Data, maxDim: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let size = img.size
        let scale = min(1, maxDim / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
