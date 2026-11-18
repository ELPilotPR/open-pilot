import SwiftUI

/// Side-by-side model comparison: one shared prompt, one streaming column per
/// model. Each column can be re-pointed at any configured provider/model, and
/// carries its own evidence (time-to-first-token, total time, tok/s, tokens).
/// Add/remove columns to compare N models; crown the winner. No backend.
struct CompareView: View {
    @StateObject var compare: ModelCompare
    let providers: [ProviderConfig]
    @Environment(\.dismiss) private var dismiss
    @State private var presets: [ModelCompare.Preset] = ModelCompare.loadPresets()
    @State private var showSavePreset = false
    @State private var presetName = ""

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
                ToolbarItem(placement: .primaryAction) { presetsMenu }
            }
            .alert(T("Save preset", "Guardar preset"), isPresented: $showSavePreset) {
                TextField(T("Name", "Nombre"), text: $presetName)
                Button(T("Save", "Guardar")) { saveCurrentPreset() }
                Button(T("Cancel", "Cancelar"), role: .cancel) { }
            } message: {
                Text(T("Names this matchup so you can reload it later.", "Nombra este enfrentamiento para recargarlo luego."))
            }
        }
    }

    private var presetsMenu: some View {
        Menu {
            if presets.isEmpty {
                Text(T("No saved presets", "Sin presets guardados"))
            } else {
                ForEach(presets) { p in
                    Button { loadPreset(p) } label: { Label(p.name, systemImage: "rectangle.split.2x2") }
                }
                Divider()
                Menu(T("Delete preset", "Borrar preset")) {
                    ForEach(presets) { p in
                        Button(role: .destructive) { deletePreset(p) } label: { Text(p.name) }
                    }
                }
                Divider()
            }
            Button { presetName = ""; showSavePreset = true } label: {
                Label(T("Save current…", "Guardar actual…"), systemImage: "plus")
            }
            .disabled(compare.columns.isEmpty)
        } label: {
            Image(systemName: "bookmark")
        }
        .accessibilityLabel(T("Presets", "Presets"))
    }

    private func loadPreset(_ p: ModelCompare.Preset) {
        guard !compare.isRunning else { return }
        compare.columns = ModelCompare.columns(from: p)
        Haptic.selection()
    }

    private func saveCurrentPreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !compare.columns.isEmpty else { return }
        let preset = ModelCompare.makePreset(name: name, columns: compare.columns)
        presets = ModelCompare.upsert(preset, into: presets)
        ModelCompare.savePresets(presets)
        Haptic.light()
    }

    private func deletePreset(_ p: ModelCompare.Preset) {
        presets = ModelCompare.remove(id: p.id, from: presets)
        ModelCompare.savePresets(presets)
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
            HStack {
                Text(T("Rounds", "Rondas")).font(.caption).foregroundStyle(OP.textSecondary)
                Spacer()
                Picker("", selection: $compare.debateRounds) {
                    ForEach(1...4, id: \.self) { n in
                        Text(n == 1 ? T("Compare", "Comparar") : "\(n) · " + T("Debate", "Debate")).tag(n)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if compare.debateRounds > 1 && compare.isRunning {
                Text(T("Round \(compare.round) of \(compare.debateRounds)", "Ronda \(compare.round) de \(compare.debateRounds)"))
                    .font(.caption2.weight(.semibold)).foregroundStyle(.orange)
            }
            Button { compare.run(providers: providers) } label: {
                HStack(spacing: 6) {
                    Image(systemName: compare.debateRounds > 1 ? "bubble.left.and.bubble.right" : "rectangle.split.2x2")
                    Text(compare.isRunning ? T("Running…", "Ejecutando…") : (compare.debateRounds > 1 ? T("Debate", "Debatir") : T("Compare", "Comparar")))
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
                addCard
            }
            .padding(16)
        }
    }

    private var addCard: some View {
        Button { compare.addColumn(providers: providers) } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text(T("Add model", "Añadir modelo")).font(.caption.weight(.medium))
            }
            .foregroundStyle(OP.textSecondary)
            .frame(width: 130, height: 180)
            .background(OP.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(OP.border))
        }
        .disabled(compare.isRunning)
        .accessibilityLabel(T("Add model", "Añadir modelo"))
    }

    private func columnCard(_ col: Binding<ModelCompare.Column>) -> some View {
        let c = col.wrappedValue
        let myIndex = compare.columns.firstIndex(where: { $0.id == c.id })
        let fastTTFT = ModelCompare.fastestTTFT(compare.columns)
        let fastTPS = ModelCompare.fastestTPS(compare.columns)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                header(col)
                Spacer(minLength: 0)
                Button { compare.pickWinner(id: c.id) } label: {
                    Image(systemName: c.isWinner ? "crown.fill" : "crown")
                        .font(.system(size: 13))
                        .foregroundStyle(c.isWinner ? .yellow : OP.textTertiary)
                }
                .accessibilityLabel(T("Pick winner", "Elegir ganador"))
                if compare.columns.count > 1 {
                    Button { compare.removeColumn(id: c.id) } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(OP.textTertiary)
                    }
                    .accessibilityLabel(T("Remove column", "Quitar columna"))
                }
            }
            metricsRow(c, isFastestTTFT: myIndex == fastTTFT, isFastestTPS: myIndex == fastTPS)
            if let err = c.error {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if c.text.isEmpty {
                        Text(c.isStreaming ? T("Thinking…", "Pensando…") : T("Waiting…", "Esperando…"))
                            .font(.callout).foregroundStyle(OP.textTertiary)
                    } else {
                        MarkdownView(text: c.text)
                    }
                    if c.isStreaming {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !c.reasoning.isEmpty {
                DisclosureGroup(T("Reasoning", "Razonamiento")) {
                    Text(c.reasoning)
                        .font(.caption)
                        .foregroundStyle(OP.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
            let priorRounds = c.isStreaming ? c.history : Array(c.history.dropLast())
            if !priorRounds.isEmpty {
                DisclosureGroup(T("Previous rounds", "Rondas anteriores")) {
                    ForEach(Array(priorRounds.enumerated()), id: \.offset) { i, txt in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Round \(i + 1)", "Ronda \(i + 1)")).font(.caption2.bold()).foregroundStyle(OP.textSecondary)
                            MarkdownView(text: txt)
                        }
                    }
                }
                .font(.caption)
            }
        }
        .frame(width: 300, alignment: .topLeading)
        .padding(12)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(c.isWinner ? Color.yellow : OP.border, lineWidth: c.isWinner ? 2 : 1))
    }

    /// Per-column evidence: time-to-first-token, total time, average tok/s and
    /// prompt/completion token counts. The fastest column gets a green badge.
    private func metricsRow(_ c: ModelCompare.Column, isFastestTTFT: Bool, isFastestTPS: Bool) -> some View {
        let tps = ModelCompare.avgTPS(tokens: c.completionTokens, elapsed: c.elapsed) ?? c.liveTPS
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                if let t = c.ttft {
                    metricChip("bolt.fill", String(format: "%.2fs", t), highlight: isFastestTTFT)
                }
                if let e = c.elapsed {
                    metricChip("clock", String(format: "%.1fs", e), highlight: false)
                }
                if let s = tps {
                    metricChip("speedometer", LiveSpeed.label(s), highlight: isFastestTPS)
                }
            }
            if c.promptTokens > 0 || c.completionTokens > 0 {
                Text("↑ \(TokenFormat.short(c.promptTokens))  ·  ↓ \(TokenFormat.short(c.completionTokens)) tok")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(OP.textTertiary)
            }
        }
    }

    private func metricChip(_ icon: String, _ value: String, highlight: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(value).font(.caption2.monospacedDigit().weight(.semibold))
        }
        .foregroundStyle(highlight ? Color.green : Color.orange)
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
