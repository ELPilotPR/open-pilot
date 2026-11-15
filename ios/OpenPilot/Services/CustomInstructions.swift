import Foundation

/// Instrucciones personalizadas persistentes: contexto sobre el usuario + cómo
/// quiere que responda el modelo. Se guardan solo en el dispositivo (UserDefaults)
/// y se anteponen al system prompt de cada conversación cuando están activadas.
/// Sin backend: nada de esto sale del iPhone salvo la petición directa al modelo.
enum CustomInstructions {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "customInstructionsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "customInstructionsEnabled") }
    }
    static var aboutYou: String {
        get { UserDefaults.standard.string(forKey: "customAboutYou") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customAboutYou") }
    }
    static var responsePrefs: String {
        get { UserDefaults.standard.string(forKey: "customResponsePrefs") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customResponsePrefs") }
    }

    /// Fragmento de system prompt; vacío si está desactivado o sin contenido.
    static var systemPrompt: String {
        guard enabled else { return "" }
        let about = aboutYou.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefs = responsePrefs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !about.isEmpty || !prefs.isEmpty else { return "" }
        var parts: [String] = []
        if !about.isEmpty { parts.append("Contexto sobre el usuario:\n\(about)") }
        if !prefs.isEmpty { parts.append("Cómo debe responder el modelo:\n\(prefs)") }
        return parts.joined(separator: "\n\n")
    }
}
