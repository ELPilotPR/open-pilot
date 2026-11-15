import Foundation

/// Runs the same prompt against several models/providers at once and keeps a
/// column of streaming output per model, so responses can be compared side by
/// side. Everything talks directly to the configured providers — no backend.
@MainActor
final class ModelCompare: ObservableObject {

    struct Column: Identifiable {
        let id = UUID()
        var providerID: String
        var model: String
        var label: String
        var text: String = ""
        var reasoning: String = ""
        var isStreaming = false
        var error: String?
        var completionTokens = 0
    }

    @Published var columns: [Column]
    @Published var prompt: String = ""
    @Published var isRunning = false

    init(columns: [Column], prompt: String = "") {
        self.columns = columns
        self.prompt = prompt
    }

    /// The turns sent to every model: just the shared user prompt.
    nonisolated static func turns(for prompt: String) -> [ChatTurn] {
        [ChatTurn(role: "user", content: prompt)]
    }

    /// Folds one streaming event into a column. Pure, so it is unit-testable
    /// without any network.
    nonisolated static func apply(_ event: ChatEvent, to column: inout Column) {
        switch event {
        case .delta(let d):        column.text += d
        case .reasoning(let r):    column.reasoning += r
        case .usage(_, let c):     column.completionTokens = c
        case .done:                column.isStreaming = false
        }
    }

    /// Picks two sensible default columns: A = preferred provider/model, B = the
    /// first different model (same provider if it has another model, otherwise a
    /// different provider). Returns one column when there is nothing to compare.
    nonisolated static func defaultColumns(providers: [ProviderConfig], preferred: ProviderConfig?, model: String) -> [Column] {
        guard let a = preferred ?? providers.first else { return [] }
        let aModel = model.isEmpty ? (a.models.first ?? "") : model
        let colA = Column(providerID: a.id, model: aModel, label: a.name)
        if let other = a.models.first(where: { $0 != aModel }) {
            return [colA, Column(providerID: a.id, model: other, label: a.name)]
        }
        if let b = providers.first(where: { $0.id != a.id }) {
            return [colA, Column(providerID: b.id, model: b.models.first ?? "", label: b.name)]
        }
        return [colA]
    }

    /// Streams every column concurrently. Each child task hops to the main actor,
    /// so column mutations are serialised and safe.
    func run(providers: [ProviderConfig]) {
        let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty, !isRunning, !columns.isEmpty else { return }
        isRunning = true
        for i in columns.indices {
            columns[i].text = ""
            columns[i].reasoning = ""
            columns[i].error = nil
            columns[i].completionTokens = 0
            columns[i].isStreaming = true
        }
        let turns = Self.turns(for: p)
        let snapshot = columns
        Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                for (idx, col) in snapshot.enumerated() {
                    group.addTask { @MainActor in
                        guard let prov = providers.first(where: { $0.id == col.providerID }) else {
                            self.columns[idx].error = T("Provider unavailable", "Proveedor no disponible")
                            self.columns[idx].isStreaming = false
                            return
                        }
                        let client = ProviderFactory.make(kind: prov.kind)
                        let base = prov.baseURL, key = prov.apiKey, model = col.model
                        do {
                            for try await ev in client.stream(turns: turns, model: model, baseURL: base, apiKey: key) {
                                Self.apply(ev, to: &self.columns[idx])
                            }
                        } catch {
                            self.columns[idx].error = error.localizedDescription
                        }
                        self.columns[idx].isStreaming = false
                    }
                }
            }
            self.isRunning = false
        }
    }
}