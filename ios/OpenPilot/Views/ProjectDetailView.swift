import SwiftUI
import SwiftData

/// Detalle de un proyecto: nombre, icono, instrucciones propias y los chats
/// que contiene. Permite crear un chat dentro del proyecto o abrir uno existente.
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @Binding var current: Conversation?
    @Binding var sidebarOpen: Bool
    @Query(sort: \Conversation.createdAt, order: .reverse) private var allConversations: [Conversation]
    @Query private var providers: [ProviderConfig]
    @State private var showDelete = false

    private var chats: [Conversation] { allConversations.filter { $0.projectID == project.id } }
    private let symbols = ["folder", "book", "briefcase", "chevron.left.forwardslash.chevron.right",
                           "paintbrush", "chart.bar", "globe", "lightbulb", "heart", "star"]

    var body: some View {
        List {
            Section {
                TextField(T("Project name", "Nombre del proyecto"), text: $project.name)
                Picker(T("Icon", "Icono"), selection: $project.symbol) {
                    ForEach(symbols, id: \.self) { s in
                        Label(s, systemImage: s).tag(s)
                    }
                }
            } header: { Text(T("Project", "Proyecto")) }

            Section {
                TextEditor(text: $project.instructions)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
            } header: {
                Text(T("Instructions", "Instrucciones"))
            } footer: {
                Text(T("Applied to every chat in this project.", "Se aplican a todos los chats de este proyecto."))
            }

            Section {
                Button { newChat() } label: {
                    Label(T("New chat in project", "Nuevo chat en el proyecto"), systemImage: "square.and.pencil")
                }
                if chats.isEmpty {
                    Text(T("No chats yet", "Aún no hay chats")).foregroundStyle(OP.textTertiary)
                } else {
                    ForEach(chats) { c in
                        Button { open(c) } label: {
                            Text(c.title.isEmpty ? T("New chat", "Nueva conversación") : c.title)
                                .foregroundStyle(OP.textPrimary).lineLimit(1)
                        }
                    }
                }
            } header: { Text(T("Chats", "Chats")) }

            Section {
                Button(role: .destructive) { showDelete = true } label: {
                    Label(T("Delete project", "Eliminar proyecto"), systemImage: "trash")
                }
            } footer: {
                Text(T("Chats are kept, just unassigned.", "Los chats se conservan, solo se desasignan."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle(project.name.isEmpty ? T("Project", "Proyecto") : project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(T("Done", "Listo")) { try? context.save(); dismiss() }
            }
        }
        .alert(T("Delete project?", "¿Eliminar proyecto?"), isPresented: $showDelete) {
            Button(T("Delete", "Eliminar"), role: .destructive) { deleteProject() }
            Button(T("Cancel", "Cancelar"), role: .cancel) {}
        } message: {
            Text(T("The chats inside are kept, just unassigned.", "Los chats de dentro se conservan, solo se desasignan."))
        }
        .onDisappear { try? context.save() }
    }

    private func newChat() {
        let pid = providers.first?.id ?? "casa"
        let model = providers.first?.models.first ?? ""
        let c = Conversation(providerID: pid, model: model)
        c.projectID = project.id
        context.insert(c); try? context.save()
        current = c; sidebarOpen = false; dismiss()
    }

    private func open(_ c: Conversation) {
        current = c; sidebarOpen = false; dismiss()
    }

    private func deleteProject() {
        for c in chats { c.projectID = nil }
        context.delete(project); try? context.save()
        dismiss()
    }
}
