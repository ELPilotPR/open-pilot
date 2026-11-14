import Foundation

/// Estilo de longitud de las respuestas (control global en Settings). Conciso por
/// defecto: respuesta directa, sin informes largos.
enum ResponseStyle: String, CaseIterable, Identifiable {
    case conciso, normal, detallado
    var id: String { rawValue }

    var label: String {
        switch self {
        case .conciso: return "Conciso"
        case .normal: return "Normal"
        case .detallado: return "Detallado"
        }
    }

    var systemPrompt: String {
        switch self {
        case .conciso:
            return """
            Responde de forma concisa y directa. Empieza con la respuesta \
            en 1-3 frases, sin rodeos ni repetir la pregunta. Si hay datos, usa una lista \
            corta o una tabla pequeña; negrita para lo clave. Evita párrafos largos, \
            salvedades extensas y secciones de relleno. Si usas fuentes, cita [n] en línea.
            """
        case .normal:
            return """
            Responde claro y bien estructurado, con la longitud justa para cubrir la \
            pregunta. Empieza con lo importante. Usa negrita, listas o tablas cuando \
            ayuden a leer. Cita [n] en línea si usas fuentes.
            """
        case .detallado:
            return """
            Responde a fondo, con detalle y buena estructura, cubriendo matices y \
            contexto. Usa encabezados, listas y tablas para organizar. Cita [n] en \
            línea si usas fuentes.
            """
        }
    }

    static var current: ResponseStyle {
        ResponseStyle(rawValue: UserDefaults.standard.string(forKey: "responseStyle") ?? "conciso") ?? .conciso
    }
}
