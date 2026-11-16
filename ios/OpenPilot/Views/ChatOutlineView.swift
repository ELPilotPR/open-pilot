import SwiftUI

/// Índice de la conversación: lista los turnos de usuario y salta al mensaje elegido.
struct ChatOutlineView: View {
    let entries: [OutlineEntry]
    let onJump: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(T("No turns yet", "Aún no hay turnos"),
                                           systemImage: "list.bullet",
                                           description: Text(T("Send a message to build the outline.",
                                                               "Envía un mensaje para crear el índice.")))
                } else {
                    List(entries) { e in
                        Button {
                            onJump(e.id)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(e.index)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(OP.textTertiary)
                                    .frame(width: 26, alignment: .leading)
                                Text(e.preview)
                                    .font(.subheadline)
                                    .foregroundStyle(OP.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(T("Outline", "Índice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Close", "Cerrar")) { dismiss() }
                }
            }
        }
    }
}