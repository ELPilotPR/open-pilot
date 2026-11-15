import Foundation
#if canImport(llama)
import llama
#endif

/// Proveedor offline real: ejecuta un modelo GGUF en el dispositivo con llama.cpp
/// a traves de su API C estable (llama.h, sin C++ interop). Sin backend, sin API key.
/// El modelo debe descargarse antes desde Ajustes -> Local Models. `model` es el
/// nombre del archivo .gguf.
struct GGUFProvider: ChatProvider {
    func stream(turns: [ChatTurn], model: String, baseURL: String, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let flag = GGUFStopFlag()
            let thread = Thread {
                #if canImport(llama)
                let filename = model.isEmpty ? (GGUFSupport.catalog.first?.filename ?? "") : model
                guard LocalModelStore.isDownloaded(filename) else {
                    continuation.finish(throwing: ProviderError.transport(
                        "Model not downloaded. Get it in Settings -> Local Models (GGUF)."))
                    return
                }
                do {
                    try GGUFEngine.generate(turns: turns,
                                            fileURL: LocalModelStore.url(for: filename),
                                            isCancelled: { flag.value },
                                            onEvent: { continuation.yield($0) })
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ProviderError.transport(error.localizedDescription))
                }
                #else
                continuation.finish(throwing: ProviderError.transport("GGUF runtime not available in this build."))
                #endif
            }
            thread.stackSize = 8 * 1024 * 1024
            thread.qualityOfService = .userInitiated
            thread.start()
            continuation.onTermination = { _ in flag.set() }
        }
    }

    func models(baseURL: String, apiKey: String) async throws -> [String] {
        let local = LocalModelStore.downloaded()
        return local.isEmpty ? GGUFSupport.catalog.map { $0.filename } : local
    }
}

/// Bandera de cancelacion thread-safe para el hilo de inferencia.
final class GGUFStopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _v = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return _v }
    func set() { lock.lock(); _v = true; lock.unlock() }
}

#if canImport(llama)
/// Motor de inferencia GGUF sobre la API C de llama.cpp (b8851).
enum GGUFEngine {
    static func generate(turns: [ChatTurn],
                         fileURL: URL,
                         isCancelled: () -> Bool,
                         onEvent: (ChatEvent) -> Void) throws {
        llama_backend_init()
        defer { llama_backend_free() }

        var mp = llama_model_default_params()
        mp.n_gpu_layers = 0   // CPU: seguro en simulador y device (Metal requiere device real)
        guard let model = llama_model_load_from_file(fileURL.path, mp) else {
            throw ProviderError.transport("Could not load GGUF model: \(fileURL.lastPathComponent)")
        }
        defer { llama_model_free(model) }
        guard let vocab = llama_model_get_vocab(model) else {
            throw ProviderError.transport("Model has no vocabulary.")
        }

        var cp = llama_context_default_params()
        cp.n_ctx = 4096
        cp.n_batch = 4096
        guard let ctx = llama_init_from_model(model, cp) else {
            throw ProviderError.transport("Could not create inference context (out of memory?).")
        }
        defer { llama_free(ctx) }

        // 1) Formatear el chat con la plantilla del modelo (fallback chatml).
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        var msgs: [llama_chat_message] = turns.map { t in
            let r = strdup(t.role)!; let c = strdup(t.content)!
            cStrings.append(r); cStrings.append(c)
            return llama_chat_message(role: r, content: c)
        }
        defer { cStrings.forEach { free($0) } }
        guard !msgs.isEmpty else { throw ProviderError.transport("Empty conversation.") }

        var usedTmpl: String? = nil
        var n = llama_chat_apply_template(nil, &msgs, msgs.count, true, nil, 0)
        if n < 0 {
            usedTmpl = "chatml"
            n = usedTmpl!.withCString { llama_chat_apply_template($0, &msgs, msgs.count, true, nil, 0) }
        }
        guard n > 0 else { throw ProviderError.transport("Could not apply a chat template to this model.") }
        var buf = [CChar](repeating: 0, count: Int(n) + 1)
        let written: Int32
        if let t = usedTmpl {
            written = t.withCString { llama_chat_apply_template($0, &msgs, msgs.count, true, &buf, Int32(buf.count)) }
        } else {
            written = llama_chat_apply_template(nil, &msgs, msgs.count, true, &buf, Int32(buf.count))
        }
        guard written > 0 else { throw ProviderError.transport("Chat template formatting failed.") }
        let promptText = String(decoding: buf.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)

        // 2) Tokenizar el prompt.
        var cap = Int32(promptText.utf8.count) + 32
        var tokens = [llama_token](repeating: 0, count: Int(cap))
        var nPrompt = promptText.withCString { llama_tokenize(vocab, $0, Int32(strlen($0)), &tokens, cap, true, true) }
        if nPrompt < 0 {
            cap = -nPrompt
            tokens = [llama_token](repeating: 0, count: Int(cap))
            nPrompt = promptText.withCString { llama_tokenize(vocab, $0, Int32(strlen($0)), &tokens, cap, true, true) }
        }
        guard nPrompt > 0 else { throw ProviderError.transport("Tokenization failed.") }
        guard Int(nPrompt) < Int(cp.n_ctx) - 16 else {
            throw ProviderError.transport("Conversation too long for the 4096-token context.")
        }

        // 3) Cadena de muestreo.
        let smpl = llama_sampler_chain_init(llama_sampler_chain_default_params())
        defer { llama_sampler_free(smpl) }
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        // 4) Prefill.
        if llama_decode(ctx, llama_batch_get_one(&tokens, nPrompt)) != 0 {
            throw ProviderError.transport("Prompt processing failed.")
        }

        // 5) Generacion token a token.
        var generated = 0
        let maxNew = 1024
        var pieceBuf = [CChar](repeating: 0, count: 512)
        var newToken: llama_token = 0
        while generated < maxNew {
            if isCancelled() { break }
            let id = llama_sampler_sample(smpl, ctx, -1)
            if llama_vocab_is_eog(vocab, id) { break }
            let np = llama_token_to_piece(vocab, id, &pieceBuf, Int32(pieceBuf.count), 0, false)
            if np > 0 {
                let piece = String(decoding: pieceBuf.prefix(Int(np)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                if !piece.isEmpty { onEvent(.delta(piece)) }
            }
            generated += 1
            newToken = id
            if llama_decode(ctx, llama_batch_get_one(&newToken, 1)) != 0 { break }
        }
        onEvent(.usage(promptTokens: Int(nPrompt), completionTokens: generated))
    }
}
#endif
