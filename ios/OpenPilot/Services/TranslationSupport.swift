import Foundation

/// Idioma destino de traducción.
struct TranslationLanguage: Identifiable, Equatable {
    let code: String
    let name: String
    var id: String { code }
}

/// Soporte de traducción: catálogo de idiomas y construcción del prompt. La
/// traducción la hace el provider del usuario (cliente directo, sin backend).
enum TranslationSupport {
    static let languages: [TranslationLanguage] = [
        .init(code: "es", name: "Spanish"),
        .init(code: "en", name: "English"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "it", name: "Italian"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "zh", name: "Chinese"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "ru", name: "Russian"),
        .init(code: "hi", name: "Hindi"),
    ]

    /// Por defecto traduce al idioma "opuesto" al del dispositivo.
    static func defaultTarget(deviceLanguage: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        deviceLanguage.hasPrefix("es") ? "en" : "es"
    }

    static func name(for code: String) -> String {
        languages.first { $0.code == code }?.name ?? code
    }

    static func prompt(text: String, targetCode: String) -> String {
        "Translate the following text into \(name(for: targetCode)). "
        + "Output ONLY the translation, with no notes or quotes; preserve formatting and line breaks.\n\n"
        + text
    }
}