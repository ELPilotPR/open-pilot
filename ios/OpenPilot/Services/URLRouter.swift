import Foundation

/// Acción que pide un deep link `openpilot://…`.
enum URLAction: Equatable {
    case ask(String)
    case newChat
    case voice
}

/// URLs de retorno del estándar x-callback-url.
struct CallbackURLs: Equatable {
    var success: String?
    var error: String?
    var cancel: String?
}

/// Parser puro de deep links y constructor de URLs de retorno. Sin UI ni red,
/// testeable de forma determinista.
///
/// Formas admitidas:
///   openpilot://ask?text=Hola            (también q= / prompt=)
///   openpilot://newchat
///   openpilot://voice
///   openpilot://x-callback-url/ask?text=Hola&x-success=app://ok&x-error=app://fail
enum URLRouter {
    static let scheme = "openpilot"

    static func parse(_ url: URL) -> (action: URLAction, callbacks: CallbackURLs)? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = comps?.queryItems ?? []
        func q(_ names: [String]) -> String? {
            for n in names {
                if let v = items.first(where: { $0.name.lowercased() == n })?.value, !v.isEmpty { return v }
            }
            return nil
        }
        let callbacks = CallbackURLs(success: q(["x-success"]), error: q(["x-error"]), cancel: q(["x-cancel"]))
        var command = (url.host ?? "").lowercased()
        if command == "x-callback-url" {
            command = url.pathComponents.dropFirst().first?.lowercased() ?? ""
        }
        switch command {
        case "ask":
            guard let text = q(["text", "q", "prompt"]) else { return nil }
            return (.ask(text), callbacks)
        case "newchat", "new":
            return (.newChat, callbacks)
        case "voice":
            return (.voice, callbacks)
        default:
            return nil
        }
    }

    /// Añade un parámetro a una URL de retorno conservando los existentes.
    static func callback(_ base: String, param: String, value: String) -> URL? {
        guard var comps = URLComponents(string: base), comps.scheme != nil else { return nil }
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: param, value: value))
        comps.queryItems = items
        return comps.url
    }
}

/// Enruta un deep link escribiendo los mismos flags de UserDefaults que usan las
/// intents de Siri/Shortcuts, para que RootView/ChatView los consuman al activarse.
enum DeepLinkSupport {
    static let askTextFlag = "deeplink.askText"
    static let xSuccessKey = "deeplink.xsuccess"
    static let xErrorKey = "deeplink.xerror"

    @discardableResult
    static func route(_ url: URL, defaults: UserDefaults = .standard) -> Bool {
        guard let (action, cb) = URLRouter.parse(url) else { return false }
        switch action {
        case .ask(let text):
            defaults.set(text, forKey: askTextFlag)
            if let s = cb.success { defaults.set(s, forKey: xSuccessKey) }
            if let e = cb.error { defaults.set(e, forKey: xErrorKey) }
        case .newChat:
            defaults.set(true, forKey: IntentSupport.newChatFlag)
        case .voice:
            defaults.set(true, forKey: IntentSupport.voiceFlag)
        }
        return true
    }
}