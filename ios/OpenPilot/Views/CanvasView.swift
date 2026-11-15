import SwiftUI

/// Panel de edición Canvas: documento a pantalla completa con editor, navegación
/// de versiones y una barra para pedir cambios al modelo. Se abre desde un bloque
/// de código o desde el botón de Canvas del chat.
struct CanvasView: View {
    @ObservedObject var doc: CanvasDocument
    let provider: ProviderConfig?
    let model: String
    @Environment(\.dismiss) private var dismiss
    @State private var instruction = ""
    @FocusState private var promptFocused: Bool
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if doc.versionTotal > 1 { versionBar }
                if previewable {
                    Picker("", selection: $showPreview) {
                        Text(T("Code", "Código")).tag(false)
                        Text(T("Preview", "Vista previa")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                }
                if showPreview && previewable {
                    CanvasWebView(html: CanvasPreview.htmlDocument(language: doc.language, source: doc.content))
                        .background(Color.white)
                } else {
                    TextEditor(text: $doc.content)
                        .font(.system(.body, design: doc.language.isEmpty ? .default : .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(OP.canvas)
                        .padding(.horizontal, 8)
                        .disabled(doc.isStreaming)
                }
                Divider().overlay(OP.border)
                promptBar
            }
            .background(OP.canvas)
            .onAppear { if doc.startInPreview { showPreview = true } }
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(T("Close", "Cerrar"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = doc.content
                        Haptic.success()
                    } label: { Image(systemName: "doc.on.doc") }
                        .accessibilityLabel(T("Copy", "Copiar"))
                }
            }
        }
    }

    private var versionBar: some View {
        HStack(spacing: 14) {
            Button { doc.switchVersion(doc.versionIndex - 1) } label: { Image(systemName: "chevron.left") }
                .disabled(doc.versionIndex == 0)
            Text("\(doc.versionIndex + 1)/\(doc.versionTotal)")
                .font(.caption.monospacedDigit()).foregroundStyle(OP.textSecondary)
            Button { doc.switchVersion(doc.versionIndex + 1) } label: { Image(systemName: "chevron.right") }
                .disabled(doc.versionIndex == doc.versionTotal - 1)
            Spacer()
            Text(T("Versions", "Versiones")).font(.caption2).foregroundStyle(OP.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(OP.elevated)
    }

    private var promptBar: some View {
        VStack(spacing: 6) {
            if !doc.statusText.isEmpty {
                Text(doc.statusText).font(.caption2).foregroundStyle(OP.textTertiary)
            }
            HStack(spacing: 10) {
                TextField(T("Ask for a change…", "Pide un cambio…"), text: $instruction, axis: .vertical)
                    .focused($promptFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(OP.composerBg)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(OP.border, lineWidth: 1))
                Button {
                    let instr = instruction
                    instruction = ""
                    if let p = provider { doc.applyEdit(instruction: instr, provider: p, model: model) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OP.sendFg)
                        .frame(width: 36, height: 36)
                        .background(canEdit ? OP.sendBg : OP.border)
                        .clipShape(Circle())
                }
                .disabled(!canEdit)
                .accessibilityLabel(T("Apply change", "Aplicar cambio"))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(OP.canvas)
    }

    private var previewable: Bool { CanvasPreview.isPreviewable(doc.language) }

    private var canEdit: Bool {
        provider != nil && !doc.isStreaming &&
        !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
