import SwiftUI
import SwiftData

/// Ajustes de Spotlight: interruptor + indexado manual. Todo en el dispositivo.
struct SpotlightSettingsView: View {
    @AppStorage("spotlightEnabled") private var enabled = false
    @Query private var conversations: [Conversation]
    @State private var indexedCount: Int?

    var body: some View {
        Form {
            Section {
                Toggle(T("Index chats in Spotlight", "Indexar chats en Spotlight"), isOn: $enabled)
            } footer: {
                Text(T("Makes your chats searchable from the system search. Indexing happens on this device only.",
                       "Hace tus chats buscables desde la búsqueda del sistema. El indexado ocurre solo en este dispositivo."))
            }
            Section {
                Button { indexNow() } label: {
                    Label(T("Index all chats now", "Indexar todos ahora"), systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    SpotlightSupport.removeAll(); indexedCount = 0; Haptic.light()
                } label: {
                    Label(T("Remove from Spotlight", "Quitar de Spotlight"), systemImage: "trash")
                }
                if let n = indexedCount {
                    Text(T("\(n) chats indexed.", "\(n) chats indexados."))
                        .font(.caption).foregroundStyle(OP.textSecondary)
                }
            }
        }
        .navigationTitle(T("Spotlight", "Spotlight"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func indexNow() {
        let items = conversations.filter { !$0.isTemporary }
        SpotlightSupport.index(items)
        indexedCount = items.count; Haptic.light()
    }
}