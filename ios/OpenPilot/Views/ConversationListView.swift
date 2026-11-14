import SwiftUI
import SwiftData

/// Sidebar: búsqueda, nuevo chat, historial agrupado por fecha
/// (Hoy / Ayer / Ultimos 7 dias / Anteriores) y settings abajo.
struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Binding var current: Conversation?
    @Binding var isOpen: Bool
    var onSettings: () -> Void
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    @State private var search = ""
    @State private var sharePayload: SharePayload?
    @State private var renamingConv: Conversation?
    @State private var renameText = ""
    @State private var showRename = false

    private var filtered: [Conversation] {
        guard !search.isEmpty else { return conversations }
        return conversations.filter { c in
            c.title.localizedCaseInsensitiveContains(search)
                || c.messages.contains { $0.text.localizedCaseInsensitiveContains(search) }
        }
    }

    private var sections: [(String, [Conversation])] {
        let cal = Calendar.current
        var hoy: [Conversation] = []
        var ayer: [Conversation] = []
        var semana: [Conversation] = []
        var antes: [Conversation] = []
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        for c in filtered {
            if cal.isDateInToday(c.createdAt) { hoy.append(c) }
            else if cal.isDateInYesterday(c.createdAt) { ayer.append(c) }
            else if c.createdAt >= weekAgo { semana.append(c) }
            else { antes.append(c) }
        }
        return [(T("Today", "Hoy"), hoy), (T("Yesterday", "Ayer"), ayer), (T("Last 7 days", "Últimos 7 días"), semana), (T("Earlier", "Anteriores"), antes)].filter { !$0.1.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(OP.textTertiary)
                TextField(T("Search", "Buscar"), text: $search).foregroundStyle(OP.textPrimary).tint(OP.accent)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(OP.textTertiary)
                    }
                }
            }
            .padding(10).background(OP.elevated).clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(12)

            Button { Haptic.light(); current = nil; close() } label: {
                Label(T("New chat", "Nuevo chat"), systemImage: "square.and.pencil")
                    .font(.body.weight(.medium))
                    .foregroundStyle(OP.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(OP.elevated.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 12).padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if filtered.isEmpty {
                        Text(search.isEmpty ? T("No conversations yet", "Aún no hay conversaciones") : T("No results", "Sin resultados"))
                            .font(.footnote).foregroundStyle(OP.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.top, 16)
                    }
                    ForEach(sections, id: \.0) { title, convs in
                        Text(title).font(.caption2.weight(.semibold)).foregroundStyle(OP.textTertiary)
                            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
                        ForEach(convs) { conv in
                            convRow(conv)
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
            }

            Spacer()
            Divider().overlay(OP.border)
            Button(action: onSettings) {
                Label(T("Settings", "Ajustes"), systemImage: "gearshape").foregroundStyle(OP.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
        }
        .background(OP.sidebar.ignoresSafeArea())
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.text])
        }
        .alert(T("Rename conversation", "Renombrar conversación"), isPresented: $showRename) {
            TextField(T("Title", "Título"), text: $renameText)
            Button(T("Cancel", "Cancelar"), role: .cancel) { renamingConv = nil }
            Button(T("Save", "Guardar")) { confirmRename() }
        }
    }

    private func convRow(_ conv: Conversation) -> some View {
        Button { Haptic.selection(); current = conv; close() } label: {
            Text(conv.title.isEmpty ? T("New chat", "Nueva conversación") : conv.title).lineLimit(1).font(.subheadline)
                .foregroundStyle(OP.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(current?.id == conv.id ? OP.elevated : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { share(conv) } label: {
                Label(T("Share", "Compartir"), systemImage: "square.and.arrow.up")
            }
            Button { startRename(conv) } label: {
                Label(T("Rename", "Renombrar"), systemImage: "pencil")
            }
            Button(role: .destructive) { delete(conv) } label: {
                Label(T("Delete", "Eliminar"), systemImage: "trash")
            }
        }
    }

    private func close() { withAnimation(.easeInOut(duration: 0.25)) { isOpen = false } }
    private func delete(_ c: Conversation) {
        context.delete(c); try? context.save()
        if current?.id == c.id { current = nil }
    }

    private func share(_ c: Conversation) {
        sharePayload = SharePayload(text: exportText(c))
        Haptic.light()
    }

    private func startRename(_ c: Conversation) {
        renamingConv = c
        renameText = c.title
        showRename = true
    }

    private func confirmRename() {
        if let c = renamingConv {
            c.title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
            try? context.save()
        }
        renamingConv = nil
    }

    /// Exporta la conversación como texto plano legible para compartir.
    private func exportText(_ c: Conversation) -> String {
        let title = c.title.isEmpty ? T("New chat", "Nueva conversación") : c.title
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var lines = [title, String(repeating: "─", count: 24), ""]
        for m in c.sortedMessages {
            let who = m.role == "user" ? T("You", "Tú") : T("Assistant", "Asistente")
            lines.append("\(who) · \(df.string(from: m.createdAt))")
            lines.append(m.text.isEmpty ? "—" : m.text)
            lines.append("")
        }
        lines.append(T("Shared from Open Pilot", "Compartido desde Open Pilot"))
        return lines.joined(separator: "\n")
    }
}

/// Payload identifiable para presentar el share sheet sin carreras de estado.
struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

/// Share sheet nativo (UIActivityViewController) para exportar conversaciones.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
