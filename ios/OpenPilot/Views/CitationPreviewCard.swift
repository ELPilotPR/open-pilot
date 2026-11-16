import SwiftUI

/// Tarjeta de preview de una cita al tocarla: dominio, título, snippet/content
/// completo y botón para abrir en el navegador. On-device, sin backend.
struct CitationPreviewCard: View {
    let source: WebSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe").foregroundStyle(OP.accent)
                        Text(URL(string: source.url)?.host ?? source.url)
                            .font(.caption).foregroundStyle(OP.textSecondary)
                            .lineLimit(1)
                    }
                    Text(source.title.isEmpty ? source.url : source.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(OP.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    let body = source.content ?? source.snippet
                    if !body.isEmpty {
                        Text(body)
                            .font(.body)
                            .foregroundStyle(OP.textPrimary)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Label(T("Open in browser", "Abrir en el navegador"), systemImage: "safari")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(OP.accent)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(T("Source", "Fuente"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Done", "Hecho")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}