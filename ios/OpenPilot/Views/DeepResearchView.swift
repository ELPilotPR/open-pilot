import SwiftUI

/// Deep research: el modelo planifica sub-consultas, la app busca fuentes en la
/// web y el modelo sintetiza un informe citado. Client-only, sin backend.
struct DeepResearchView: View {
    @StateObject var research: DeepResearch
    let provider: ProviderConfig?
    let model: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                questionBar
                Divider().overlay(OP.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !research.steps.isEmpty { stepsView }
                        if !research.sources.isEmpty { sourcesView }
                        if let err = research.error {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                        if !research.report.isEmpty {
                            MarkdownView(text: research.report)
                        } else if research.isRunning {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(phaseLabel).font(.callout).foregroundStyle(OP.textTertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .background(OP.canvas)
            .navigationTitle(T("Deep research", "Investigar a fondo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { research.cancel(); dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private var canRun: Bool {
        !research.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !research.isRunning && provider != nil
    }

    private var phaseLabel: String {
        switch research.phase {
        case .planning:     return T("Planning sub-queries…", "Planificando sub-consultas…")
        case .searching:    return T("Searching (\(research.currentStep + 1)/\(research.steps.count))…",
                                     "Buscando (\(research.currentStep + 1)/\(research.steps.count))…")
        case .synthesizing: return T("Writing the report…", "Redactando el informe…")
        default:            return T("Working…", "Trabajando…")
        }
    }

    private var questionBar: some View {
        VStack(spacing: 8) {
            TextField(T("What should I research?", "¿Qué investigo?"),
                      text: $research.question, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(OP.composerBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Button {
                if research.isRunning {
                    research.cancel()
                } else if let p = provider {
                    research.run(provider: p, model: model)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: research.isRunning ? "stop.fill" : "magnifyingglass")
                    Text(research.isRunning ? T("Stop", "Detener") : T("Research", "Investigar"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OP.sendFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(research.isRunning ? Color.red.opacity(0.8) : (canRun ? OP.sendBg : OP.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canRun && !research.isRunning)
        }
        .padding(16)
    }

    private var stepsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Plan", "Plan")).font(.caption.weight(.semibold)).foregroundStyle(OP.textSecondary)
            ForEach(Array(research.steps.enumerated()), id: \.element.id) { idx, step in
                HStack(spacing: 8) {
                    Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(step.isDone ? OP.accent : OP.textTertiary)
                    Text(step.query).font(.callout).foregroundStyle(OP.textPrimary)
                    Spacer()
                    if step.isDone {
                        Text("\(step.sourceCount)").font(.caption2).foregroundStyle(OP.textTertiary)
                    } else if idx == research.currentStep && research.phase == .searching {
                        ProgressView().controlSize(.mini)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("Sources (\(research.sources.count))", "Fuentes (\(research.sources.count))"))
                .font(.caption.weight(.semibold)).foregroundStyle(OP.textSecondary)
            ForEach(Array(research.sources.enumerated()), id: \.element.id) { idx, src in
                if let url = URL(string: src.url) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text("[\(idx + 1)]").font(.caption2).foregroundStyle(OP.textTertiary)
                            Text(src.title).font(.caption).foregroundStyle(OP.accent).lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
