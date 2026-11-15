import Foundation

/// Planificador puro de deep research: parsea sub-consultas, dedup fuentes y
/// construye los turnos de síntesis. Todo testeable sin red.
enum DeepResearchPlanner {
    /// Parsea sub-consultas de una lista numerada/con viñetas que devuelve el modelo.
    /// Quita prefijos "1.", "1)", "-", "*", "•"; descarta encabezados y vacías; tope `max`.
    static func parseQueries(_ text: String, max: Int = 4) -> [String] {
        var out: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if let r = line.range(of: #"^(\d+[.)]|[-*•])\s+"#, options: .regularExpression) {
                line = String(line[r.upperBound...])
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasSuffix(":") && line.count < 40 { continue }
            out.append(line)
            if out.count >= max { break }
        }
        return out
    }

    static func planPrompt(question: String, max: Int) -> String {
        """
        Divide la siguiente pregunta en como máximo \(max) sub-consultas de búsqueda web \
        independientes y concretas (en el idioma de la pregunta). Devuelve SOLO una lista \
        numerada, una sub-consulta por línea, sin explicaciones ni encabezados.
        Pregunta: \(question)
        """
    }

    /// Dedup por URL (case-insensitive) conservando el orden; tope de fuentes.
    static func dedupSources(_ sources: [WebSource], limit: Int) -> [WebSource] {
        var seen = Set<String>()
        var out: [WebSource] = []
        for s in sources {
            let key = s.url.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(s)
            if out.count >= limit { break }
        }
        return out
    }

    /// Merge round-robin de varias listas de fuentes (adaptado de dsh
    /// `mergeSearchResults`): intercala por rango — el top de cada sub-consulta
    /// antes que el segundo de cualquiera — con dedup por URL case-insensitive y
    /// tope `limit`. Reparte la diversidad entre consultas en vez de agotar una.
    static func roundRobinMerge(_ lists: [[WebSource]], limit: Int) -> [WebSource] {
        var seen = Set<String>()
        var out: [WebSource] = []
        let maxRank = lists.map { $0.count }.max() ?? 0
        for rank in 0..<maxRank {
            for list in lists {
                guard rank < list.count else { continue }
                let s = list[rank]
                let key = s.url.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(s)
                if out.count >= limit { return out }
            }
        }
        return out
    }

    /// Concatena los deltas de un stream (puro, testeable).
    static func reduce(_ events: [ChatEvent]) -> String {
        events.reduce(into: "") { acc, ev in
            if case .delta(let d) = ev { acc += d }
        }
    }

    /// Contexto de síntesis: informe detallado con citas (distinto del browse conciso).
    static func synthesisContext(question: String, sources: [WebSource]) -> String {
        var s = """
        Eres un investigador. Con las fuentes de abajo, redacta un informe detallado y bien \
        estructurado que responda la pregunta. Usa encabezados, viñetas y citas [1], [2] en \
        línea donde aportes un dato. No inventes datos ni URLs; si algo no está en las fuentes, \
        dilo. Cierra con una sección "Fuentes" que liste las URLs usadas.
        Pregunta: \(question)

        \(WebSearchService.trustNotice)
        Fuentes:
        """
        for (i, src) in sources.enumerated() {
            let body = (src.content?.isEmpty == false) ? src.content! : src.snippet
            s += "\n\n[\(i + 1)] \(src.title)\nURL: \(src.url)\n\(body)"
        }
        return s
    }

    /// Turnos para la síntesis final: system con fuentes + user con la pregunta.
    static func synthesisTurns(question: String, sources: [WebSource]) -> [ChatTurn] {
        [
            ChatTurn(role: "system", content: synthesisContext(question: question, sources: sources)),
            ChatTurn(role: "user", content: question)
        ]
    }
}

/// Deep research agéntico: el modelo planifica sub-consultas, la app busca y enriquece
/// fuentes en la web (sin backend) y el modelo sintetiza un informe citado. Client-only.
@MainActor
final class DeepResearch: ObservableObject {
    enum Phase { case idle, planning, searching, synthesizing, done, error }

    struct Step: Identifiable {
        let id = UUID()
        var query: String
        var isDone = false
        var sourceCount = 0
    }

    @Published var question = ""
    @Published var phase: Phase = .idle
    @Published var steps: [Step] = []
    @Published var currentStep = 0
    @Published var sources: [WebSource] = []
    @Published var report = ""
    @Published var isRunning = false
    @Published var error: String?

    private var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
        if phase != .done { phase = .idle }
    }

    func run(provider: ProviderConfig, model: String, maxSteps: Int = 4) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isRunning else { return }
        isRunning = true
        error = nil
        report = ""
        sources = []
        steps = []
        currentStep = 0
        phase = .planning
        let kind = provider.kind, base = provider.baseURL, key = provider.apiKey
        let m = model.isEmpty ? (provider.models.first ?? "") : model
        let client = ProviderFactory.make(kind: kind)
        task = Task { @MainActor in
            do {
                let planText = try await self.complete(client: client,
                    turns: [ChatTurn(role: "user", content: DeepResearchPlanner.planPrompt(question: q, max: maxSteps))],
                    model: m, baseURL: base, apiKey: key)
                if Task.isCancelled { self.isRunning = false; return }
                let parsed = DeepResearchPlanner.parseQueries(planText, max: maxSteps)
                let queries = parsed.isEmpty ? [q] : parsed
                self.steps = queries.map { Step(query: $0) }
                self.phase = .searching
                var perQuery: [[WebSource]] = []
                for i in queries.indices {
                    if Task.isCancelled { break }
                    self.currentStep = i
                    let found = await WebSearchService.enriched(query: queries[i], limit: 4)
                    perQuery.append(found)
                    self.steps[i].sourceCount = found.count
                    self.steps[i].isDone = true
                    self.sources = DeepResearchPlanner.roundRobinMerge(perQuery, limit: 12)
                }
                let gathered = DeepResearchPlanner.roundRobinMerge(perQuery, limit: 12)
                if Task.isCancelled { self.isRunning = false; return }
                self.phase = .synthesizing
                let turns = DeepResearchPlanner.synthesisTurns(question: q, sources: gathered)
                for try await ev in client.stream(turns: turns, model: m, baseURL: base, apiKey: key) {
                    if Task.isCancelled { break }
                    if case .delta(let d) = ev { self.report += d }
                }
                self.phase = Task.isCancelled ? .idle : .done
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    self.phase = .error
                }
            }
            self.isRunning = false
        }
    }

    /// Drena un stream a texto plano (para la fase de planificación).
    private func complete(client: ChatProvider, turns: [ChatTurn], model: String,
                          baseURL: String, apiKey: String) async throws -> String {
        var out = ""
        for try await ev in client.stream(turns: turns, model: model, baseURL: baseURL, apiKey: apiKey) {
            if case .delta(let d) = ev { out += d }
        }
        return out
    }
}
