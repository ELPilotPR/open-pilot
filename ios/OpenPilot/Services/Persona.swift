import Foundation

/// Una "persona" es un preset con nombre que antepone un system prompt al chat.
/// Las integradas vienen con la app; las personalizadas se guardan en el dispositivo.
struct Persona: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var symbol: String
    var prompt: String
    var isBuiltin: Bool
}

/// Registro de personas. Sin red: integradas + personalizadas en UserDefaults.
/// `defaults` es inyectable para poder testear sin tocar los ajustes reales.
enum PersonaStore {
    static var defaults = UserDefaults.standard
    static let customKey = "personas.custom"
    static let selectedKey = "personas.selected"

    /// Integradas (computed para que el idioma siga al ajuste en vivo).
    static var builtins: [Persona] {
        [
            Persona(id: "none", name: T("Default", "Por defecto"), symbol: "sparkles",
                    prompt: "", isBuiltin: true),
            Persona(id: "concise", name: T("Concise", "Conciso"), symbol: "bolt",
                    prompt: T("Be extremely concise. Answer directly with no preamble or filler.",
                              "Sé extremadamente conciso. Responde directo, sin preámbulos ni relleno."), isBuiltin: true),
            Persona(id: "teacher", name: T("Teacher", "Profesor"), symbol: "book",
                    prompt: T("Explain like a patient teacher: build intuition step by step, use a concrete example, and check understanding at the end.",
                              "Explica como un profesor paciente: construye la intuición paso a paso, usa un ejemplo concreto y comprueba al final que se entendió."), isBuiltin: true),
            Persona(id: "coder", name: T("Senior engineer", "Ingeniero senior"), symbol: "chevron.left.forwardslash.chevron.right",
                    prompt: T("Act as a senior software engineer. Give correct, idiomatic code with brief rationale, note edge cases, and prefer root-cause fixes over patches.",
                              "Actúa como ingeniero de software senior. Da código correcto e idiomático con una breve justificación, señala casos límite y prefiere arreglar la causa raíz."), isBuiltin: true),
            Persona(id: "translator", name: T("Translator", "Traductor"), symbol: "character.bubble",
                    prompt: T("You are a professional translator. Translate faithfully preserving tone and formatting; do not add commentary unless asked.",
                              "Eres traductor profesional. Traduce con fidelidad preservando tono y formato; no añadas comentarios salvo que se pidan."), isBuiltin: true),
            Persona(id: "writer", name: T("Writer", "Escritor"), symbol: "pencil.line",
                    prompt: T("You are a skilled writer. Produce clear, vivid prose with a strong voice; vary sentence rhythm and cut clichés.",
                              "Eres un escritor hábil. Produce prosa clara y vívida con voz propia; varía el ritmo de las frases y elimina clichés."), isBuiltin: true),
            Persona(id: "analyst", name: T("Analyst", "Analista"), symbol: "chart.xyaxis.line",
                    prompt: T("Act as a rigorous analyst. State assumptions, weigh evidence and trade-offs, and give a reasoned recommendation with confidence level.",
                              "Actúa como analista riguroso. Expón supuestos, sopesa evidencia y trade-offs, y da una recomendación razonada con nivel de confianza."), isBuiltin: true),
        ]
    }

    static var custom: [Persona] {
        get {
            guard let data = defaults.data(forKey: customKey),
                  let list = try? JSONDecoder().decode([Persona].self, from: data) else { return [] }
            return list
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: customKey)
        }
    }

    static var all: [Persona] { builtins + custom }

    static var selectedID: String {
        get { defaults.string(forKey: selectedKey) ?? "none" }
        set { defaults.set(newValue, forKey: selectedKey) }
    }

    static var selected: Persona? { all.first { $0.id == selectedID } }

    /// Prompt a anteponer al system prompt del chat (vacío si no hay persona).
    static var selectedPrompt: String { selected?.prompt ?? "" }

    static func add(_ p: Persona) {
        var c = custom
        c.append(p)
        custom = c
    }

    static func update(_ p: Persona) {
        var c = custom
        if let i = c.firstIndex(where: { $0.id == p.id }) {
            c[i] = p
            custom = c
        }
    }

    static func delete(id: String) {
        custom = custom.filter { $0.id != id }
        if selectedID == id { selectedID = "none" }
    }
}