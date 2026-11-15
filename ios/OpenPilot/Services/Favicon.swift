import Foundation

/// Favicons de fuentes web sin key ni backend propio. Adaptado del patrón
/// `SiteLogo` de deepseek-ai/chat-demo: icono del dominio con fallback a un
/// glifo genérico cuando no carga. Usa el servicio público de favicons (PNG,
/// compatible con AsyncImage); el `size` pide el lado en píxeles.
enum Favicon {
    /// URL del icono del dominio de `urlString`, o nil si no hay host válido.
    /// Normaliza el host (minúsculas, sin `www.`) para maximizar aciertos.
    static func url(for urlString: String, size: Int = 64) -> URL? {
        guard let host = URL(string: urlString)?.host, !host.isEmpty else { return nil }
        let clean = host.lowercased()
        let bare = clean.hasPrefix("www.") ? String(clean.dropFirst(4)) : clean
        var c = URLComponents()
        c.scheme = "https"
        c.host = "www.google.com"
        c.path = "/s2/favicons"
        c.queryItems = [
            URLQueryItem(name: "domain", value: bare),
            URLQueryItem(name: "sz", value: String(max(16, min(256, size)))),
        ]
        return c.url
    }
}
