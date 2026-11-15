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
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @State private var search = ""
    @State private var sharePayload: SharePayload?
    @State private var renamingConv: Conversation?
    @State private var renameText = ""
    @State private var showRename = false
    @State private var deletingConv: Conversation?
    @State private var showDeleteConfirm = false
    @State private var showArchived = false
    @State private var selectedProject: Project?
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @AppStorage("selectedModel") private var selectedModel = "swift-iq3_s"

    private var filtered: [Conversation] {
        let base = conversations.filter { !$0.isTemporary }
        guard !search.isEmpty else { return base }
        return base.filter { c in
            c.title.localizedCaseInsensitiveContains(search)
                || c.messages.contains { $0.text.localizedCaseInsensitiveContains(search) }
        }
    }

    private var active: [Conversation] { filtered.filter { !$0.isArchived } }
    private var archivedList: [Conversation] { filtered.filter { $0.isArchived } }
    private var pinned: [Conversation] { active.filter { $0.isPinned } }

    private var sections: [(String, [Conversation])] {
        let cal = Calendar.current
        var hoy: [Conversation] = []
        var ayer: [Conversation] = []
        var semana: [Conversation] = []
        var antes: [Conversation] = []
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        for c in active where !c.isPinned {
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

            Button { Haptic.light(); startTemporary() } label: {
                Label(T("Temporary chat", "Chat temporal"), systemImage: "moon")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(OP.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 12).padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if showArchived {
                        sectionHeader(T("Archived", "Archivadas"))
                        if archivedList.isEmpty {
                            emptyNote(T("No archived chats", "No hay chats archivados"))
                        }
                        ForEach(archivedList) { conv in convRow(conv) }
                    } else {
                        sectionHeader(T("Projects", "Proyectos"))
                        ForEach(projects) { p in projectRow(p) }
                        Button { newProject() } label: {
                            Label(T("New project", "Nuevo proyecto"), systemImage: "plus")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(OP.accent)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)

                        if active.isEmpty {
                            emptyNote(search.isEmpty ? T("No conversations yet", "Aún no hay conversaciones") : T("No results", "Sin resultados"))
                        }
                        if !pinned.isEmpty {
                            sectionHeader(T("Pinned", "Fijadas"))
                            ForEach(pinned) { conv in convRow(conv) }
                        }
                        ForEach(sections, id: \.0) { title, convs in
                            sectionHeader(title)
                            ForEach(convs) { conv in convRow(conv) }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
            }

            Button { Haptic.light(); withAnimation(.easeInOut(duration: 0.2)) { showArchived.toggle() } } label: {
                Label(showArchived ? T("Back to chats", "Volver a los chats")
                                   : T("Archived", "Archivadas") + (archivedList.isEmpty ? "" : " (\(archivedList.count))"),
                      systemImage: showArchived ? "chevron.left" : "archivebox")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(OP.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 8)
            }
            .buttonStyle(.plain)

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
        .alert(T("Delete chat?", "¿Eliminar conversación?"), isPresented: $showDeleteConfirm, presenting: deletingConv) { c in
            Button(T("Delete", "Eliminar"), role: .destructive) { delete(c) }
            Button(T("Cancel", "Cancelar"), role: .cancel) { deletingConv = nil }
        } message: { _ in
            Text(T("This conversation will be permanently deleted.", "Esta conversación se eliminará permanentemente."))
        }
        .alert(T("Rename conversation", "Renombrar conversación"), isPresented: $showRename) {
            TextField(T("Title", "Título"), text: $renameText)
            Button(T("Cancel", "Cancelar"), role: .cancel) { renamingConv = nil }
            Button(T("Save", "Guardar")) { confirmRename() }
        }
        .sheet(item: $selectedProject) { p in
            NavigationStack { ProjectDetailView(project: p, current: $current, sidebarOpen: $isOpen) }
        }
    }

    private func convRow(_ conv: Conversation) -> some View {
        Button { Haptic.selection(); current = conv; close() } label: {
            HStack(spacing: 6) {
                if conv.isPinned {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(OP.textTertiary)
                }
                Text(conv.title.isEmpty ? T("New chat", "Nueva conversación") : conv.title)
                    .lineLimit(1).font(.subheadline).foregroundStyle(OP.textPrimary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(current?.id == conv.id ? OP.elevated : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { togglePin(conv) } label: {
                Label(conv.isPinned ? T("Unpin", "Desfijar") : T("Pin", "Fijar"),
                      systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            Menu {
                Button { moveTo(conv, nil) } label: { Label(T("No project", "Sin proyecto"), systemImage: "folder") }
                ForEach(projects) { p in
                    Button { moveTo(conv, p.id) } label: {
                        Label(p.name.isEmpty ? T("Project", "Proyecto") : p.name, systemImage: p.symbol)
                    }
                }
            } label: {
                Label(T("Move to project", "Mover a proyecto"), systemImage: "folder")
            }
            Button { toggleArchive(conv) } label: {
                Label(conv.isArchived ? T("Unarchive", "Desarchivar") : T("Archive", "Archivar"),
                      systemImage: "archivebox")
            }
            Button { share(conv) } label: {
                Label(T("Share", "Compartir"), systemImage: "square.and.arrow.up")
            }
            Button { startRename(conv) } label: {
                Label(T("Rename", "Renombrar"), systemImage: "pencil")
            }
            Button(role: .destructive) { deletingConv = conv; showDeleteConfirm = true } label: {
                Label(T("Delete", "Eliminar"), systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.caption2.weight(.semibold)).foregroundStyle(OP.textTertiary)
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(OP.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.top, 16)
    }

    private func togglePin(_ c: Conversation) {
        c.isPinned.toggle()
        if c.isPinned { c.isArchived = false }
        try? context.save(); Haptic.light()
    }

    private func toggleArchive(_ c: Conversation) {
        c.isArchived.toggle()
        if c.isArchived { c.isPinned = false }
        try? context.save(); Haptic.light()
        if c.isArchived && current?.id == c.id { current = nil }
    }

    private func projectRow(_ p: Project) -> some View {
        let count = conversations.filter { $0.projectID == p.id && !$0.isArchived }.count
        return Button {
            selectedProject = p
        } label: {
            HStack(spacing: 10) {
                Image(systemName: p.symbol).font(.footnote).foregroundStyle(OP.accent).frame(width: 18)
                Text(p.name.isEmpty ? T("Project", "Proyecto") : p.name)
                    .font(.callout).foregroundStyle(OP.textPrimary).lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.caption2).foregroundStyle(OP.textTertiary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func newProject() {
        let p = Project(name: T("New project", "Nuevo proyecto"))
        context.insert(p); try? context.save()
        selectedProject = p
        Haptic.selection()
    }

    private func moveTo(_ c: Conversation, _ pid: UUID?) {
        c.projectID = pid
        try? context.save()
        Haptic.selection()
    }

    private func close() { withAnimation(.easeInOut(duration: 0.25)) { isOpen = false } }

    /// Crea un chat temporal (sin memoria ni historial) y lo abre.
    private func startTemporary() {
        let c = Conversation(providerID: selectedProviderID, model: selectedModel)
        c.isTemporary = true
        context.insert(c); try? context.save()
        current = c
        close()
    }
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
