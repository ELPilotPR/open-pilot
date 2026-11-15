import Foundation

/// Ajustes de fallback entre providers (UserDefaults, sin backend).
enum FallbackSettings {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "fallbackEnabled") }
    static var ids: [String] {
        get { UserDefaults.standard.stringArray(forKey: "fallbackProviderIDs") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "fallbackProviderIDs") }
    }
}

/// Lógica pura de la cadena de respaldo y de qué errores merecen reintento.
enum ProviderFallback {
    /// primary primero, luego los fallbacks (sin duplicar ni repetir el primary).
    static func chain(primaryID: String, fallbackIDs: [String]) -> [String] {
        var result = [primaryID]
        for id in fallbackIDs where id != primaryID && !result.contains(id) { result.append(id) }
        return result
    }

    /// Siguiente provider en la cadena tras el que falló (nil si no hay más).
    static func next(after currentID: String, in chain: [String]) -> String? {
        guard let i = chain.firstIndex(of: currentID), i + 1 < chain.count else { return nil }
        return chain[i + 1]
    }

    /// Códigos HTTP transitorios que merecen reintento (no 400/401/403/404).
    static func isRetryable(statusCode: Int) -> Bool {
        [408, 429, 500, 502, 503, 504].contains(statusCode)
    }

    /// Errores de red/transitorios que merecen reintento.
    static func isRetryable(_ error: Error) -> Bool {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost,
                 .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        let msg = error.localizedDescription.lowercased()
        return ["500", "502", "503", "504", "429", "timeout", "timed out"]
            .contains { msg.contains($0) }
    }
}