import Foundation

/// Carpeta inteligente: regla dinámica sobre las conversaciones (sin store
/// extra). Se evalúa en memoria; no persiste nada nuevo.
enum SmartFolder: String, CaseIterable, Identifiable {
    case recent, code, images, long, pinned, untagged
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recent: return "clock"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .images: return "photo.on.rectangle"
        case .long: return "text.alignleft"
        case .pinned: return "pin"
        case .untagged: return "tag.slash"
        }
    }

    func matches(_ c: Conversation) -> Bool {
        if c.isTemporary { return false }
        switch self {
        case .recent:
            return c.createdAt > Date().addingTimeInterval(-7 * 24 * 3600)
        case .code:
            return c.tags.contains("code") || c.messages.contains { $0.text.contains("```") }
        case .images:
            return c.messages.contains { !$0.imageData.isEmpty }
        case .long:
            return c.messages.count >= 20
        case .pinned:
            return c.isPinned
        case .untagged:
            return c.tags.isEmpty && !c.messages.isEmpty
        }
    }

    static func conversations(in folder: SmartFolder, from all: [Conversation]) -> [Conversation] {
        all.filter { folder.matches($0) }.sorted { $0.createdAt > $1.createdAt }
    }
}