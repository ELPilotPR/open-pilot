import SwiftUI

/// Side-by-side model comparison: one shared prompt, one streaming column per
/// model. Each column can be re-pointed at any configured provider/model.
struct CompareView: View {
    @StateObject var compare: ModelCompare
    let providers: [ProviderConfig]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                promptBar
                Divider().overlay(OP.border)
                columnsView
            }
            .background(OP.canvas)
            .navigationTitle(T("Compare models", "Comparar modelos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private var canRun: Bool {
        !compare.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !compare.isRunning && !compare.columns.isEmpty
    }

    private var promptBar: some View {
        VStack(spacing: 8) {
            TextField(T("Ask every model the same thing…", "Pregunta lo mismo a todos los modelos…"),
                      text: $compare.prompt, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(OP.composerBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Button { compare.run(providers: providers) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.split.2x2")
                    Text(compare.isRunning ? T("Running…", "Ejecutando…") : T("Compare", "Comparar"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OP.sendFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(canRun ? OP.sendBg : OP.border)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canRun)
        }
        .padding(16)
    }

    private var columnsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach($compare.columns) { $col in
                    columnCard($col)
                }
            }
            .padding(16)
        }
    }

    private func columnCard(_ col: Binding<ModelCompare.Column>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header(col)
            if let err = col.wrappedValue.error {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if col.wrappedValue.text.isEmpty {
                        Text(col.wrappedValue.isStreaming ? T("Thinking…", "Pensando…") : T("Waiting…", "Esperando…"))
                            .font(.callout).foregroundStyle(OP.textTertiary)
                    } else {
                        MarkdownView(text: col.wrappedValue.text)
                    }
                    if col.wrappedValue.isStreaming {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if col.wrappedValue.completionTokens > 0 {
                Text("≈ \(col.wrappedValue.completionTokens) tokens")
                    .font(.caption2).foregroundStyle(OP.textTertiary)
            }
        }
        .frame(width: 300, alignment: .topLeading)
        .padding(12)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(OP.border, lineWidth: 1))
    }

    private func header(_ col: Binding<ModelCompare.Column>) -> some View {
        Menu {
            ForEach(providers) { p in
                ForEach(p.models.isEmpty ? [""] : p.models, id: \.self) { m in
                    Button("\(p.name) · \(m)") {
                        col.wrappedValue.providerID = p.id
                        col.wrappedValue.model = m
                        col.wrappedValue.label = p.name
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(col.wrappedValue.label).font(.caption.weight(.semibold)).foregroundStyle(OP.textPrimary)
                Text(col.wrappedValue.model).font(.caption2).foregroundStyle(OP.textSecondary).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8)).foregroundStyle(OP.textTertiary)
            }
        }
    }
}