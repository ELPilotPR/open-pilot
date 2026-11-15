import SwiftUI
import SwiftData

/// Búsqueda global: encuentra cualquier mensaje en todas las conversaciones y
/// salta a ella. Los resultados muestran un fragmento con la coincidencia.
struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    @State private var query = ""
    var onSelect: (Conversation) -> Void

    private var hits: [SearchHit] { ConversationSearch.search(query, in: conversations) }
    private var byID: [UUID: Conversation] {
        Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(T("Search all chats", "Buscar en todos los chats"),
                                           systemImage: "magnifyingglass",
                                           description: Text(T("Find any message across every conversation.",
                                                               "Encuentra cualquier mensaje en todas tus conversaciones.")))
                } else if hits.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(hits) { hit in
                        Button {
                            if let c = byID[hit.conversationID] { onSelect(c); dismiss() }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(hit.conversationTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(OP.textPrimary).lineLimit(1)
                                Text(hit.snippet)
                                    .font(.caption).foregroundStyle(OP.textSecondary).lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(T("Search", "Buscar"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: T("Search messages", "Buscar mensajes"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Close", "Cerrar")) { dismiss() }
                }
            }
        }
    }
}