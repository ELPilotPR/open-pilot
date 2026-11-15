import Foundation

/// Persistencia del perfil aprendido (UserDefaults, JSON) + control del modo
/// sueño. El perfil se inyecta en el system prompt siempre que exista; el toggle
/// `dreamEnabled` solo controla el DISPARO automático (el manual siempre funciona).
/// Todo local, sin backend. Hermano de MemoryStore (memoria por-turno).
enum ProfileStore {
    private static let profileKey = "userProfile"
    private static let enabledKey = "dreamEnabled"
    private static let thresholdKey = "dreamThreshold"
    private static let lastDreamKey = "dreamLastDate"
    private static let counterKey = "dreamNewMessages"

    /// Disparo automático del sueño (por defecto activo, umbral 20 mensajes).
    static var dreamEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Mensajes nuevos entre sueños automáticos.
    static var threshold: Int {
        get { UserDefaults.standard.object(forKey: thresholdKey) as? Int ?? 20 }
        set { UserDefaults.standard.set(max(1, newValue), forKey: thresholdKey) }
    }

    static var lastDream: Date? {
        get { UserDefaults.standard.object(forKey: lastDreamKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastDreamKey) }
    }

    /// Contador de mensajes nuevos desde el último sueño.
    static var newMessages: Int {
        get { UserDefaults.standard.integer(forKey: counterKey) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: counterKey) }
    }

    static var profile: UserProfile {
        get {
            guard let data = UserDefaults.standard.data(forKey: profileKey),
                  let p = try? JSONDecoder().decode(UserProfile.self, from: data) else { return .empty }
            return p
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: profileKey)
            }
        }
    }

    /// Guarda secciones nuevas como el perfil vigente (sella la fecha).
    static func save(sections: [UserProfile.Section]) {
        profile = UserProfile(sections: sections, updatedAt: Date())
        lastDream = Date()
        newMessages = 0
    }

    static func clear() {
        profile = .empty
        newMessages = 0
    }

    /// Fragmento de system prompt; vacío si no hay perfil aprendido.
    static var systemPrompt: String {
        DreamSupport.systemPromptFragment(profile)
    }
}