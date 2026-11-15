import SwiftUI
import SwiftData

/// Carpetas inteligentes: reglas dinámicas sobre las conversaciones (recientes,
/// código, imágenes, largos, fijados, sin etiquetar). Sin store extra.
struct SmartFoldersView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    var onSelect: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(SmartFolder.allCases) { folder in
                    let items = SmartFolder.conversations(in: folder, from: conversations)
                    NavigationLink {
                        List(items, id: \.id) { c in
                            Button { onSelect(c); dismiss() } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title.isEmpty ? T("New chat", "Nuevo chat") : c.title)
                                        .foregroundStyle(OP.textPrimary)
                                    Text(c.createdAt, style: .date).font(.caption).foregroundStyle(OP.textSecondary)
                                }
                            }
                        }
                        .navigationTitle(label(folder))
                    } label: {
                        HStack {
                            Image(systemName: folder.icon).foregroundStyle(OP.accent).frame(width: 24)
                            Text(label(folder)).foregroundStyle(OP.textPrimary)
                            Spacer()
                            Text("\(items.count)").foregroundStyle(OP.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle(T("Smart folders", "Carpetas inteligentes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } } }
        }
    }

    private func label(_ f: SmartFolder) -> String {
        switch f {
        case .recent: return T("Recent", "Recientes")
        case .code: return T("Code", "Código")
        case .images: return T("Images", "Imágenes")
        case .long: return T("Long chats", "Chats largos")
        case .pinned: return T("Pinned", "Fijados")
        case .untagged: return T("Untagged", "Sin etiquetar")
        }
    }
}