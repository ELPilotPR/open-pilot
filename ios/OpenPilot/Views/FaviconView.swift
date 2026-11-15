import SwiftUI

/// Icono de dominio con fallback a globo (patrón `SiteLogo` de chat-demo).
/// Carga asíncrona; mientras falla o no hay host, muestra un glifo neutro para
/// que la lista de fuentes nunca se vea rota.
struct FaviconView: View {
    let url: String
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let u = Favicon.url(for: url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fit)
                    default:
                        globe
                    }
                }
            } else {
                globe
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityHidden(true)
    }

    private var globe: some View {
        Image(systemName: "globe")
            .resizable().aspectRatio(contentMode: .fit)
            .foregroundStyle(OP.textTertiary)
    }
}
