import SwiftUI

/// Gestión de la memoria automática: activar/desactivar, ver los hechos
/// recordados, añadir uno a mano y borrar (individual o todo). Local, sin red.
struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = MemoryStore.enabled
    @State private var entries: [String] = MemoryStore.entries
    @State private var newFact = ""

    var body: some View {
        List {
            Section {
                Toggle(T("Enable memory", "Activar memoria"), isOn: $enabled)
            } footer: {
                Text(T("Open Pilot remembers durable facts about you across chats and uses them to personalize answers. Stored only on this iPhone.",
                       "Open Pilot recuerda hechos duraderos sobre ti entre chats y los usa para personalizar respuestas. Se guarda solo en este iPhone."))
            }

            Section {
                HStack {
                    TextField(T("Add a fact…", "Añadir un hecho…"), text: $newFact)
                        .onSubmit { add() }
                    Button { add() } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(newFact.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if entries.isEmpty {
                    Text(T("No memories yet", "Aún no hay recuerdos")).foregroundStyle(OP.textTertiary)
                } else {
                    ForEach(entries.indices, id: \.self) { i in
                        Text(entries[i]).foregroundStyle(OP.textPrimary)
                    }
                    .onDelete { idx in
                        for i in idx.sorted(by: >) { MemoryStore.remove(at: i) }
                        entries = MemoryStore.entries
                    }
                }
            } header: { Text(T("Memories", "Recuerdos")) }

            Section {
                Button(role: .destructive) { MemoryStore.clear(); entries = [] } label: {
                    Label(T("Clear all", "Borrar todo"), systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle(T("Memory", "Memoria"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button(T("Done", "Listo")) { dismiss() } }
        }
        .onChange(of: enabled) { _, v in MemoryStore.enabled = v }
        .onAppear { entries = MemoryStore.entries; enabled = MemoryStore.enabled }
    }

    private func add() {
        let t = newFact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        MemoryStore.add([t]); entries = MemoryStore.entries; newFact = ""
    }
}
