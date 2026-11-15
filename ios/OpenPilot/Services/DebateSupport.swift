import Foundation

/// Multi-round debate logic for the model comparator. Pure and unit-testable:
/// builds the rebuttal prompt each debater receives in rounds > 1, carrying the
/// other models' previous answers so they critique and refine each other.
/// No network, no backend — the iPhone talks to the providers directly.
enum DebateSupport {

    /// One opponent's previous-round answer.
    struct Opponent {
        let label: String
        let text: String
    }

    /// Formats opponents' previous answers into a labelled block. Empty answers
    /// are skipped so a failed debater doesn't pollute the rebuttal prompt.
    nonisolated static func opponentsBlock(_ opponents: [Opponent]) -> String {
        opponents
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "[\($0.label)]:\n\($0.text)" }
            .joined(separator: "\n\n")
    }

    /// The instruction for round `round` (> 1): critique the others, then improve.
    nonisolated static func rebuttalPrompt(original: String, round: Int, opponents: [Opponent]) -> String {
        let header = T(
            "This is round \(round) of a debate. The original question was:\n\(original)",
            "Esta es la ronda \(round) de un debate. La pregunta original era:\n\(original)")
        let block = opponentsBlock(opponents)
        if block.isEmpty {
            return header + "\n\n" + T("Give your best, refined answer.",
                                        "Da tu mejor respuesta refinada.")
        }
        let body = T(
            "The other models answered:\n\n\(block)\n\nCritique their answers: point out errors or gaps, then give your improved answer. Be specific and concise.",
            "Los otros modelos respondieron:\n\n\(block)\n\nCritica sus respuestas: señala errores o huecos y luego da tu respuesta mejorada. Sé específico y conciso.")
        return header + "\n\n" + body
    }

    /// Turns for a debater in round `round`. Round 1 is the plain shared prompt;
    /// later rounds are the rebuttal instruction with the opponents' last answers.
    nonisolated static func debateTurns(original: String, round: Int, opponents: [Opponent]) -> [ChatTurn] {
        if round <= 1 { return [ChatTurn(role: "user", content: original)] }
        return [ChatTurn(role: "user", content: rebuttalPrompt(original: original, round: round, opponents: opponents))]
    }
}