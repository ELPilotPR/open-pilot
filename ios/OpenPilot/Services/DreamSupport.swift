import Foundation

/// "Modo sueño" (sleep-time compute / dreaming): en segundo plano el modelo
/// revisa conversaciones pasadas y destila un PERFIL estructurado del usuario
/// (quién es, gustos, proyectos, estilo) que se inyecta en cada system prompt.
/// A diferencia de la memoria por-turno (MemoryStore, lista plana de hechos),
/// esto consolida TODO el historial en un perfil limpio y evoluciona con el uso.
/// 100% en el dispositivo, sin backend: usa los providers que el usuario configure.
/// Este enum es la lógica pura (parseo/prompts/disparo), unit-testeable sin red.

/// Perfil aprendido del usuario, por secciones.
struct UserProfile: Codable, Equatable {
    struct Section: Codable, Equatable {
        let title: String
        var items: [String]
    }
    var sections: [Section]
    var updatedAt: Date

    static let empty = UserProfile(sections: [], updatedAt: Date(timeIntervalSince1970: 0))
    var isEmpty: Bool { sections.allSatisfy { $0.items.isEmpty } }
    var totalItems: Int { sections.reduce(0) { $0 + $1.items.count } }
}

enum DreamSupport {
    /// Tope de items por sección para que el perfil no infle el contexto.
    static let maxItemsPerSection = 12
    /// Secciones que pedimos al modelo (en el idioma del usuario).
    static let sectionTitles = ["Quién es", "Gustos y preferencias", "Proyectos y trabajo", "Estilo de respuesta"]

    /// Parsea la salida del modelo con formato "## Título" + líneas "- item".
    /// Ignora líneas vacías y secciones sin items; recorta al tope por sección.
    nonisolated static func parseProfile(_ text: String) -> [UserProfile.Section] {
        var sections: [UserProfile.Section] = []
        var currentTitle: String?
        var currentItems: [String] = []

        func flush() {
            if let t = currentTitle, !currentItems.isEmpty {
                sections.append(UserProfile.Section(title: t, items: Array(currentItems.prefix(maxItemsPerSection))))
            }
            currentItems = []
        }

        for raw in text.split(whereSeparator: { $0.isNewline }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("## ") || line.hasPrefix("# ") {
                flush()
                currentTitle = String(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                continue
            }
            guard currentTitle != nil else { continue }
            var item = line
            for prefix in ["- ", "* ", "• "] {
                if item.hasPrefix(prefix) { item = String(item.dropFirst(prefix.count)); break }
            }
            item = item.trimmingCharacters(in: .whitespaces)
            if !item.isEmpty { currentItems.append(item) }
        }
        flush()
        return sections
    }

    /// Prompt de consolidación: fusiona el perfil existente con el transcript
    /// reciente, deduplica, resuelve contradicciones (gana lo más reciente) y
    /// mantiene el perfil conciso. Pide el formato exacto que parseProfile lee.
    nonisolated static func consolidationPrompt(existing: UserProfile, transcript: String) -> String {
        let existingText = existing.isEmpty ? "(perfil vacío)" : renderSections(existing.sections)
        let titles = sectionTitles.map { "## \($0)" }.joined(separator: "\n")
        return """
        Eres el "modo sueño" de un asistente personal. Revisa las conversaciones recientes del usuario y ACTUALIZA su perfil aprendido para personalizar futuras respuestas. Fusiona con el perfil existente, elimina duplicados, resuelve contradicciones (prefiere lo más reciente) y descarta datos pasajeros o triviales. Sé conciso: hechos específicos y duraderos, en el idioma del usuario.

        Devuelve SOLO el perfil con este formato exacto (una sección por título, items con "- ", máximo \(maxItemsPerSection) por sección). Si una sección no tiene nada, omítela:
        \(titles)

        PERFIL EXISTENTE:
        \(existingText)

        CONVERSACIONES RECIENTES:
        \(transcript)
        """
    }

    /// Render de secciones a texto "## Título\n- item".
    nonisolated static func renderSections(_ sections: [UserProfile.Section]) -> String {
        sections.map { sec in
            "## \(sec.title)\n" + sec.items.map { "- \($0)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    /// Fragmento de system prompt con el perfil; vacío si no hay perfil.
    nonisolated static func systemPromptFragment(_ profile: UserProfile) -> String {
        guard !profile.isEmpty else { return "" }
        return "Perfil aprendido del usuario (personaliza tus respuestas en consecuencia):\n" + renderSections(profile.sections)
    }

    /// Disparo del sueño: solo si está activo y hay suficientes mensajes nuevos
    /// desde el último sueño (evita quemar tokens en corridas sin novedad).
    nonisolated static func shouldDream(enabled: Bool, newMessages: Int, threshold: Int) -> Bool {
        enabled && newMessages >= max(1, threshold)
    }

    /// Transcript compacto de mensajes recientes (rol + texto), recortado a un
    /// presupuesto de caracteres para no exceder el contexto del modelo.
    nonisolated static func transcript(_ messages: [(role: String, text: String)], maxChars: Int = 6000) -> String {
        var lines: [String] = []
        var used = 0
        for m in messages {
            let t = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            let who = m.role == "user" ? "Usuario" : "Asistente"
            let line = "\(who): \(t.prefix(400))"
            if used + line.count > maxChars { break }
            lines.append(line)
            used += line.count + 1
        }
        return lines.joined(separator: "\n")
    }
}