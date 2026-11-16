import Foundation

/// "Continuar" una respuesta truncada: la instrucción para el modelo y una
/// heurística conservadora de truncamiento (fence de código sin cerrar o final
/// abrupto). El botón se ofrece en la última respuesta; la heurística lo resalta.
enum ContinueSupport {
    static let instruction = T("Continue your previous answer exactly where you left off. Do not repeat what you already wrote; do not start over.",
                               "Continúa tu respuesta anterior exactamente donde te quedaste. No repitas lo ya escrito; no empieces de nuevo.")

    /// Un fence ``` sin cerrar delata código truncado; terminar en coma/dos puntos/
    /// paréntesis o corchete abierto delata una frase cortada a mitad.
    static func looksTruncated(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let fences = t.components(separatedBy: "```").count - 1
        if fences % 2 == 1 { return true }
        if let last = t.last, ",;:([{".contains(last) { return true }
        return false
    }
}