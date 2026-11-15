import Foundation

/// Una imagen de la galería (generada o adjunta) con su contexto.
struct GalleryItem: Identifiable, Equatable {
    let id: UUID
    let data: Data
    let date: Date
    let title: String
}

/// Recoge todas las imágenes de las conversaciones (no temporales), más nuevas primero.
enum ImageGallerySupport {
    static func collect(from conversations: [Conversation]) -> [GalleryItem] {
        var items: [GalleryItem] = []
        for c in conversations where !c.isTemporary {
            for m in c.sortedMessages where !m.imageData.isEmpty {
                items.append(GalleryItem(id: m.id, data: m.imageData, date: m.createdAt, title: c.title))
            }
        }
        return items.sorted { $0.date > $1.date }
    }
}